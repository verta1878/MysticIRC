#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"
BIN="$ROOT/out-linux/bin"; UNITS="$ROOT/out-linux/units"
mkdir -p "$BIN" "$UNITS"
FPC="${FPC:-../fpc264irc-clean/bin/ppc386}"
FPCROOT="${FPCROOT:-../fpc264irc-clean}"
XTOOLS="$FPCROOT/bin/tools/i386-linux"
XUNITS="$FPCROOT/bin/units/i386-linux"
FPCOPTS=(-Tlinux -Mdelphi -Fumdl -Fumystic -Fimdl -Fimystic -Fomdl
         -FU"$UNITS" -FE"$BIN" -Fl/usr/lib/i386-linux-gnu
         -FD"$XTOOLS" -Fu"$XUNITS")
MARCOPTS=(-Tlinux -Mobjfpc -Fumystic -Fimystic
          -FU"$UNITS" -FE"$BIN" -Fl/usr/lib/i386-linux-gnu
          -FD"$XTOOLS" -Fu"$XUNITS")
PASS=0; FAIL=0

# ============================================================
# Pre-flight: check for i386 multilib (required for linking)
# ============================================================
check_multilib() {
    local missing=""
    # glibc 2.34 (2021) merged libpthread and libdl into libc, so probing for
    # libpthread.so/libdl.so rejects every current distro. libc.so alone is the
    # meaningful test for the i386 development libraries.
    for lib in libc.so; do
        if ! find /usr/lib/i386-linux-gnu /usr/lib32 /lib/i386-linux-gnu              -name "$lib" 2>/dev/null | grep -q .; then
            missing="$missing $lib"
        fi
    done
    if [ -n "$missing" ]; then
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║  ERROR: 32-bit libraries not found                      ║"
        echo "║                                                         ║"
        echo "║  Missing:$missing"
        echo "║                                                         ║"
        echo "║  This build produces i386 (32-bit) Linux binaries.      ║"
        echo "║  Your system needs the i386 multilib packages:          ║"
        echo "║                                                         ║"
        echo "║  Debian/Ubuntu:                                         ║"
        echo "║    sudo dpkg --add-architecture i386                    ║"
        echo "║    sudo apt-get update                                  ║"
        echo "║    sudo apt-get install libc6-dev:i386                  ║"
        echo "║                                                         ║"
        echo "║  Fedora/RHEL:                                           ║"
        echo "║    sudo dnf install glibc-devel.i686                    ║"
        echo "║                                                         ║"
        echo "║  Arch:                                                  ║"
        echo "║    sudo pacman -S lib32-glibc                           ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        exit 1
    fi
}
check_multilib

build () {
    local t="$1" mode="${2:-delphi}"
    local src="mystic/${t}.pas" log="out-linux/${t}.build.log"
    # A missing source is a failure, not a skip: the target list below is
    # fixed, so a silent skip would let the whole build "pass" having produced
    # nothing.
    [ ! -f "$src" ] && { echo "  FAIL  $t (source not found)"; FAIL=$((FAIL+1)); return; }
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
echo "Mystic BBS Linux build ($(date))"
echo "Compiler: $FPC"
echo ""
chmod +x "$XTOOLS"/* "$FPC" 2>/dev/null
for t in mystic mis mutil mplc mide mbbsutil fidopoll nodespy \
         qwkpoll mystpack install install_make maketheme 109to110; do
    build "$t"
done
build marc objfpc
echo ""
echo "Passed: $PASS  Failed: $FAIL"
[ $FAIL -eq 0 ] && echo "ALL LINUX BUILDS PASSED"
