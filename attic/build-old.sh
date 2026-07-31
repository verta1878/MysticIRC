#!/usr/bin/env bash
# ============================================================
#  Mystic 1.10 fork - Linux/Unix build  (FPC 2.6.4irc r3, i386)
#  Default compiler: FPC 2.6.4irc (release r3) - libs/fpc264irc.tar.gz.
#  Usage:  ./build.sh            build every binary
#          ./build.sh mis        build a single target
#  Windows builds: use build-win32.bat (this is bash-only).
# ============================================================
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"
BIN="$ROOT/out/bin"; UNITS="$ROOT/out/units"
mkdir -p "$BIN" "$UNITS"

# Default compiler is FPC 2.6.4irc r3 (unpack libs/fpc264irc.tar.gz and point
# FPC= at its bin/ppc386).  Falls back to whatever 'fpc'/'ppc386' is on PATH.
FPC="${FPC:-fpc}"     # override with FPC=/path/to/fpc264irc/bin/ppc386
# The socket resolver (mdl/m_io_sockets on UNIX) uses FPC r3's pure-Pascal
# Resolve unit (cNetDB/libc resolver retired). Resolve pulls in netdb (fcl-net)
# and URIParser (fcl-base). A full FPC install has these on the path already; if
# yours does not, set FCLNET= and FCLBASE= to r3's package source dirs, e.g.
#   FCLNET=<fpc>/src/packages/fcl-net/src  FCLBASE=<fpc>/src/packages/fcl-base/src
FCLNET="${FCLNET:-}"
FCLBASE="${FCLBASE:-}"
FPCOPTS=(-Mdelphi -Fumdl -Fumystic -Fimdl -Fimystic -Fomdl -FU"$UNITS" -FE"$BIN")
[ -n "$FCLNET" ]  && FPCOPTS+=(-Fu"$FCLNET")
[ -n "$FCLBASE" ] && FPCOPTS+=(-Fu"$FCLBASE")

# MARC is a standalone archiver that uses FPC's own zipper/paszlib units, which
# require ObjFPC mode (the rest of Mystic is Delphi mode) and the paszlib + hash
# (crc) source paths. Adjust PASZLIB/HASH if your FPC install puts them elsewhere;
# with the bundled 2.6.4irc r3 they live under its src/packages tree.
PASZLIB="${PASZLIB:-}"
HASHSRC="${HASHSRC:-}"
MARCOPTS=(-Mobjfpc -Fumystic -Fimystic -FU"$UNITS" -FE"$BIN")
[ -n "$PASZLIB" ] && MARCOPTS+=(-Fu"$PASZLIB")
[ -n "$HASHSRC" ] && MARCOPTS+=(-Fu"$HASHSRC")

ALL=(mystic mis mutil mplc mide mbbsutil fidopoll nodespy qwkpoll \
     mystpack install install_make maketheme 109to110 marc)
TARGETS=("$@"); [ ${#TARGETS[@]} -eq 0 ] && TARGETS=("${ALL[@]}")

clean() { find . -name '*.ppu' -delete 2>/dev/null; find . -name '*.o' -delete 2>/dev/null; }

rc=0
for t in "${TARGETS[@]}"; do
  clean
  if [ "$t" = "marc" ]; then
    OPTS=("${MARCOPTS[@]}")
  else
    OPTS=("${FPCOPTS[@]}")
  fi
  if "$FPC" "${OPTS[@]}" "mystic/$t.pas" > "$ROOT/out/$t.build.log" 2>&1; then
    printf "  OK    %-14s -> out/bin/%s\n" "$t" "$t"
  else
    printf "  FAIL  %-14s (see out/%s.build.log)\n" "$t" "$t"
    grep -iE '\bError\b|\bFatal\b' "$ROOT/out/$t.build.log" | head -2 | sed 's/^/          /'
    rc=1
  fi
done
exit $rc
