#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"
BIN="$ROOT/out-os2/bin"; UNITS="$ROOT/out-os2/units"
mkdir -p "$BIN" "$UNITS"
FPC="${FPC:-../fpc264irc-clean/bin/ppc386}"
FPCROOT="${FPCROOT:-../fpc264irc-clean}"
XTOOLS="$FPCROOT/bin/tools/i386-emx"
XUNITS="$FPCROOT/bin/units/i386-os2"
FPCOPTS=(-Temx -Mdelphi -Fumdl -Fumystic -Fimdl -Fimystic -Fomdl
         -FU"$UNITS" -FE"$BIN"
         -XPi386-emx- -FD"$XTOOLS" -Fu"$XUNITS")
MARCOPTS=(-Temx -Mobjfpc -Fumystic -Fimystic
          -FU"$UNITS" -FE"$BIN"
          -XPi386-emx- -FD"$XTOOLS" -Fu"$XUNITS")
PASS=0; FAIL=0

# ============================================================
# Pre-flight: check for cross-tools
# ============================================================
check_tools() {
    if [ ! -d "$XTOOLS" ]; then
        echo "ERROR: OS2 cross-tools not found at $XTOOLS"
        echo "Install fpc264irc: https://github.com/verta1878/fpc264irc"
        exit 1
    fi
    if [ ! -f "$FPC" ]; then
        echo "ERROR: Compiler not found at $FPC"
        echo "Clone fpc264irc as sibling: git clone https://github.com/verta1878/fpc264irc"
        exit 1
    fi
}
check_tools

build () {
    local t="$1" mode="${2:-delphi}"
    local src="mystic/${t}.pas" log="out-os2/${t}.build.log"
    [ ! -f "$src" ] && { echo "  SKIP  $t (not found)"; return; }
    if [ "$mode" = "objfpc" ]; then
        "$FPC" "${MARCOPTS[@]}" "$src" >"$log" 2>&1
    else
        "$FPC" "${FPCOPTS[@]}" "$src" >"$log" 2>&1
    fi
    if [ $? -eq 0 ]; then
        echo "  OK    $t"
        PASS=$((PASS+1))
    else
        err=$(grep "Fatal:" "$log" | head -1)
        echo "  FAIL  $t  ($err)"
        FAIL=$((FAIL+1))
    fi
}
echo "Mystic BBS OS/2 (EMX) cross-build ($(date))"
echo ""
chmod +x "$XTOOLS"/* "$FPC" 2>/dev/null
for t in mystic mis mutil mplc mide mbbsutil fidopoll nodespy \
         qwkpoll mystpack install install_make maketheme 109to110; do
    build "$t"
done
build marc objfpc
echo ""
echo "Passed: $PASS  Failed: $FAIL"
