#!/usr/bin/env bash
# ============================================================
#  make_all_releases.sh - build every platform's release directory.
#
#  Usage:  ./make_all_releases.sh [full|upgrade|both] [out-dir]
#          mode = both (default) | full | upgrade
#
#  Produces, under <out-dir> (default "release"), one directory per target:
#     release/lnx/  mysticlnxfull.zip  mysticlnxupd.zip   (Linux i386 ELF)
#     release/win/  mysticwinfull.zip  mysticwinupd.zip   (Windows PE32)
#     release/mac/  mysticmacfull.zip  mysticmacupd.zip   (macOS i386 Mach-O)
#     release/os2/  mysticos2full.zip  mysticos2upd.zip   (OS/2 LX)
#     release/dos/  mysticdosfull.zip  mysticdosupd.zip   (DOS go32v2)
#
#  Compiled binaries land in (all gitignored):
#     Linux out/bin   Win32 out/bin-win   macOS out_darwin/bin
#     OS/2  out/bin-os2   DOS out/bin-dos
#
#  Per-target requirements (each target is INDEPENDENT - a target whose
#  toolchain is missing is skipped with a note; the others still build):
#     Linux : ppc386 (native FPC 2.6.2) - always available on the build host
#     Win32 : ppc386 + i386-win32 RTL (WIN32RTL=)
#     macOS : SDK=/path/to/MacOSX10.6.sdk + the ld64 bundle (libs/)
#     OS/2  : emx toolchain on PATH (from libs/fpc264irc.tar.gz bin/tools/i386-emx;
#             see fpc264irc/patches/os2-cross/)
#     DOS   : the bundled cross toolchain in libs/dos-toolchain.zip (auto-
#             unpacked by build-dos.sh). DOS builds 10/14; the networked
#             utilities (mis/fidopoll/nodespy/qwkpoll) additionally need
#             Watt-32 (WATT32LIB=/dir/with/libwatt.a) - see docs/DOS-SOCKETS.md.
#
#  Env knobs:
#     FPC=ppc386                     native compiler
#     WIN32RTL=<dir>                 i386-win32 RTL units
#     SDK=<MacOSX10.6.sdk>           enables macOS
#     OS2UNITS=<dir>                 OS/2 RTL units (if not default)
#     DOSTC=<dos-toolchain-262 dir>  pre-unpacked DOS toolchain (optional)
#     WATT32LIB=<dir>                libwatt.a dir (enables DOS networked progs)
# ============================================================
set -u
cd "$(dirname "$0")"
MODE="${1:-both}"; OUT="${2:-release}"
FPC="${FPC:-ppc386}"
W="${WIN32RTL:-$HOME/fpc262/fpc-2.6.2/rtl/units/i386-win32}"

case "$MODE" in full|upgrade|both) ;; *) echo "mode = full|upgrade|both"; exit 1;; esac

echo "=== building all releases (mode=$MODE) into $OUT/ ==="

# track what actually produced a release
DONE=""
SKIP=""

# ---------- Linux ----------
echo "--- Linux ---"
if FPC="$FPC" bash build.sh >/dev/null 2>&1 && [ -f out/bin/mystic ]; then
  ./make_release.sh lnx out/bin "$MODE" "$OUT" && DONE="$DONE lnx"
else
  SKIP="$SKIP lnx"; echo "  Linux build failed"
fi

# ---------- Win32 ----------
echo "--- Win32 ---"
if [ -d "$W" ]; then
  mkdir -p out/bin-win
  for t in mystic mis mutil mplc mide mbbsutil fidopoll nodespy qwkpoll \
           mystpack install install_make maketheme 109to110; do
    "$FPC" -Twin32 -Mdelphi -Fumdl -Fumystic -Fimdl -Fimystic -Fomdl \
      -Fu"$W" -FEout/bin-win "mystic/$t.pas" >/dev/null 2>&1
  done
  if [ -f out/bin-win/mystic.exe ]; then
    ./make_release.sh win out/bin-win "$MODE" "$OUT" && DONE="$DONE win"
  else SKIP="$SKIP win"; echo "  Win32 build produced no binaries"; fi
else
  SKIP="$SKIP win"; echo "  Win32 skipped (WIN32RTL not found: $W)"
fi

# ---------- macOS ----------
echo "--- macOS ---"
if [ -n "${SDK:-}" ]; then
  if SDK="$SDK" bash build-darwin.sh >/dev/null 2>&1 && [ -f out_darwin/bin/mystic ]; then
    ./make_release.sh mac out_darwin/bin "$MODE" "$OUT" && DONE="$DONE mac"
  else SKIP="$SKIP mac"; echo "  macOS build failed"; fi
else
  SKIP="$SKIP mac"; echo "  macOS skipped (set SDK=/path/to/MacOSX10.6.sdk)"
fi

# ---------- OS/2 ----------
echo "--- OS/2 ---"
if LINK=1 OS2UNITS="${OS2UNITS:-}" bash build-os2.sh >/dev/null 2>&1 && [ -f out/bin-os2/mystic.exe ]; then
  ./make_release.sh os2 out/bin-os2 "$MODE" "$OUT" && DONE="$DONE os2"
else
  SKIP="$SKIP os2"; echo "  OS/2 link failed (emx toolchain on PATH? see fpc264irc/patches/os2-cross/)"
fi

# ---------- DOS ----------
echo "--- DOS ---"
# build-dos.sh auto-unpacks libs/dos-toolchain.zip; WATT32LIB (if set) enables
# the networked utilities. DOS ships whatever built (10/14 without Watt-32).
if DOSTC="${DOSTC:-}" WATT32LIB="${WATT32LIB:-}" bash build-dos.sh >/dev/null 2>&1; then :; fi
if [ -f out/bin-dos/mystic.exe ]; then
  n=$(ls out/bin-dos/*.exe 2>/dev/null | wc -l)
  echo "  DOS built $n/14 (networked utils need WATT32LIB=; see docs/DOS-SOCKETS.md)"
  ./make_release.sh dos out/bin-dos "$MODE" "$OUT" && DONE="$DONE dos"
else
  SKIP="$SKIP dos"; echo "  DOS build produced no binaries (toolchain in libs/dos-toolchain.zip?)"
fi

echo ""
echo "=== summary ==="
echo "  released:$DONE"
[ -n "$SKIP" ] && echo "  skipped :$SKIP"
echo ""
echo "=== $OUT/ tree ==="
find "$OUT" -name '*.zip' | sort | sed 's|^|  |'
