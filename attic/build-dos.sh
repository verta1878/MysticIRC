#!/usr/bin/env bash
# ============================================================
#  Mystic 1.10 fork - DOS build  (FPC 2.6.4irc r3.1, i386-go32v2)
#  Usage:  ./build-dos.sh            build every buildable target
#          ./build-dos.sh maketheme  build a single target
#
#  Cross-compiles for 32-bit protected-mode DOS (go32v2 / DPMI) from a Linux
#  host, using the self-contained toolchain in libs/dos-toolchain.zip (FPC
#  cross compiler + go32v2 RTL + a binutils that reads FPC's COFF output.
#  FPC 2.6.4irc r3.1 bundles a go32v2 toolchain that handles this (bin/tools/i386-go32v2/).)
#  NOTE: 32-bit only. Output needs a 386+ and a DPMI host (CWSDPMI). This is NOT
#  a 16-bit real-mode (i8086) build - FPC 2.6.x has no i8086 target.
#
#  STATUS: 10/14 build.  The 7 non-networked utilities + mide + mbbsutil +
#  mystic (the BBS server) compile and link.  The networked utilities
#  (mis/fidopoll/nodespy/qwkpoll) additionally need Watt-32 (libwatt.a) on the
#  link path - set WATT32LIB=/path/to/watt/lib and the build adds -lwatt.
#  See docs/DOS-SOCKETS.md.
#
#  Env:
#    DOSTC=/path/to/dos-toolchain-262   unpacked libs/dos-toolchain.zip
#                                       (auto-unpacked to a temp dir if unset)
#    WATT32LIB=/path/to/libwatt-dir     dir containing libwatt.a (enables the
#                                       networked programs)
# ============================================================
set -u
cd "$(dirname "$0")"
ROOT="$(pwd)"

BIN="$ROOT/out/bin-dos"
mkdir -p "$BIN"

# --- locate / unpack the DOS toolchain ---
DOSTC="${DOSTC:-}"
if [ -z "$DOSTC" ]; then
  DOSTC="$(mktemp -d)/dos-toolchain-262"
  echo "Unpacking libs/dos-toolchain.zip ..."
  ( cd "$(dirname "$DOSTC")" && unzip -q "$ROOT/libs/dos-toolchain.zip" )
fi
[ -x "$DOSTC/bin/ppcross386" ] || { echo "no ppcross386 in $DOSTC/bin"; exit 1; }
export PATH="$DOSTC/bin:$PATH"
U="$DOSTC/units/go32v2"

# --- optional Watt-32 for the networked programs ---
WATTOPT=""
if [ -n "${WATT32LIB:-}" ] && [ -f "$WATT32LIB/libwatt.a" ]; then
  WATTOPT="-Fl$WATT32LIB -k-lwatt"
  echo "Watt-32: linking against $WATT32LIB/libwatt.a"
else
  echo "Watt-32: not supplied (set WATT32LIB=...); networked programs will not link"
fi

# non-networked (always build) + networked (need Watt-32)
NONNET="maketheme mplc mutil mystpack install install_make 109to110 mide mbbsutil mystic"
NET="mis fidopoll nodespy qwkpoll"
TARGETS="$*"; [ -z "$TARGETS" ] && TARGETS="$NONNET $NET"

clean() { find . -name '*.ppu' -delete 2>/dev/null; find . -name '*.o' -not -path './libs/*' -delete 2>/dev/null; }

rc=0
for t in $TARGETS; do
  clean
  # shellcheck disable=SC2086
  if ppcross386 -Tgo32v2 -XPi386-go32v2- -Mdelphi -Fumdl -Fumystic -Fimdl \
       -Fimystic -Fomdl -Fu"$U" $WATTOPT -FE"$BIN" "mystic/$t.pas" \
       > "$ROOT/out/$t.dos.log" 2>&1; then
    printf "  OK    %-14s -> out/bin-dos/%s.exe\n" "$t" "$t"
  else
    printf "  FAIL  %-14s (see out/%s.dos.log)\n" "$t" "$t"
    grep -iE '\bError\b|\bFatal\b|undefined reference' "$ROOT/out/$t.dos.log" | head -2 | sed 's/^/          /'
    rc=1
  fi
done
clean
exit $rc
