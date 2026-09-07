#!/usr/bin/env bash
# ============================================================
#  Mystic 1.11IRC — Linux build (i386 or x86_64)
#
#  Usage:
#    ./build-linux.sh              i386 stable (default)
#    ./build-linux.sh x64          x86_64 stable
#    ./build-linux.sh test         i386 test (mystic_test/)
#    ./build-linux.sh x64 test     x86_64 test
#    ./build-linux.sh x64 mutil    x86_64 single target
# ============================================================
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"

ARCH="i386"
BRANCH="stable"
TARGETS=()
for arg in "$@"; do
  case "$arg" in
    x64|X64|x86_64) ARCH="x86_64" ;;
    test|TEST)      BRANCH="test" ;;
    *) TARGETS+=("$arg") ;;
  esac
done

if [ "$BRANCH" = "test" ]; then
  SRCDIR="mystic_test"
  MDLDIR="mystic_test/mdl"
else
  SRCDIR="mystic"
  MDLDIR="mystic/mdl"
fi

if [ "$ARCH" = "x86_64" ]; then
  FPC="${FPC:-../fpc264irc/bin/ppcx64}"
  FPCROOT="${FPCROOT:-../fpc264irc}"
  XTOOLS="$FPCROOT/bin/tools/x86_64-linux"
  XUNITS="$FPCROOT/bin/units/x86_64-linux"
  LIBDIR="/usr/lib/x86_64-linux-gnu"
  LINKFLAGS=(-k--no-as-needed -k-ldl -k-lc)
else
  FPC="${FPC:-../fpc264irc/bin/ppc386}"
  FPCROOT="${FPCROOT:-../fpc264irc}"
  XTOOLS="$FPCROOT/bin/tools/i386-linux"
  XUNITS="$FPCROOT/bin/units/i386-linux"
  LIBDIR="/usr/lib/i386-linux-gnu"
  LINKFLAGS=(-k--no-as-needed -k-ldl -k-lc)
fi

BIN="$ROOT/out-linux/bin"; UNITS="$ROOT/out-linux/units"
mkdir -p "$BIN" "$UNITS"

FPCOPTS=(-Tlinux -Mdelphi
         -Fu"$MDLDIR" -Fu"$MDLDIR/m_serial" -Fu"$SRCDIR"
         -Fi"$MDLDIR" -Fi"$MDLDIR/m_serial" -Fi"$SRCDIR"
         -Fo"$MDLDIR"
         -FU"$UNITS" -FE"$BIN" -Fl"$LIBDIR"
         -FD"$XTOOLS" -Fu"$XUNITS" "${LINKFLAGS[@]}")
MARCOPTS=(-Tlinux -Mobjfpc
          -Fu"$MDLDIR" -Fu"$MDLDIR/m_serial" -Fu"$SRCDIR"
          -Fi"$MDLDIR" -Fi"$MDLDIR/m_serial" -Fi"$SRCDIR"
          -FU"$UNITS" -FE"$BIN" -Fl"$LIBDIR"
          -FD"$XTOOLS" -Fu"$XUNITS" "${LINKFLAGS[@]}")
PASS=0; FAIL=0

# ============================================================
# Pre-flight: check for multilib (i386 only)
# ============================================================
check_multilib() {
    [ "$ARCH" = "x86_64" ] && return 0
    if ! find /usr/lib/i386-linux-gnu /usr/lib32 /lib/i386-linux-gnu \
             -name "libc.so*" 2>/dev/null | grep -q .; then
        echo "ERROR: 32-bit libc not found. Install libc6-dev:i386"
        echo "  sudo dpkg --add-architecture i386 && sudo apt install libc6-dev:i386"
        exit 1
    fi
}
check_multilib

build () {
    local t="$1" mode="${2:-delphi}"
    local src="$SRCDIR/${t}.pas" log="out-linux/${t}.build.log"
    [ ! -f "$src" ] && { echo "  SKIP  $t (not found)"; return; }
    if [ "$mode" = "objfpc" ]; then
        "$FPC" "${MARCOPTS[@]}" "$src" >"$log" 2>&1
    else
        "$FPC" "${FPCOPTS[@]}" "$src" >"$log" 2>&1
    fi
    if [ $? -eq 0 ]; then
        echo "  OK    $t  -> out-linux/bin/$t"
        PASS=$((PASS+1))
    else
        err=$(grep "Fatal:" "$log" | head -1)
        echo "  FAIL  $t  ($err)"
        FAIL=$((FAIL+1))
    fi
}

echo "Mystic BBS Linux build — $ARCH $BRANCH ($(date))"
echo "Compiler: $FPC"
echo "Source:   $SRCDIR/"
echo ""

chmod +x "$XTOOLS"/* "$FPC" 2>/dev/null

ALL=(mystic mis mutil mplc mide mbbsutil fidopoll nodespy
     qwkpoll mystpack install install_make maketheme 109to110 mystfoss)
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=("${ALL[@]}" marc)

for t in "${TARGETS[@]}"; do
    if [ "$t" = "marc" ]; then
        build marc objfpc
    else
        build "$t"
    fi
done

echo ""
echo "Passed: $PASS  Failed: $FAIL"
[ $FAIL -eq 0 ] && echo "ALL LINUX BUILDS PASSED"
