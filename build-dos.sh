#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"
BIN="$ROOT/out-dos/bin"; UNITS="$ROOT/out-dos/units"
mkdir -p "$BIN" "$UNITS"
FPC="${FPC:-../fpc264irc-clean/bin/ppc386}"
FPCROOT="${FPCROOT:-../fpc264irc-clean}"
XTOOLS="$FPCROOT/bin/tools/i386-go32v2"
XUNITS="$FPCROOT/bin/units/i386-go32v2"
FPCOPTS=(-Tgo32v2 -Mdelphi -Fumdl -Fumystic -Fimdl -Fimystic -Fomdl
         -FU"$UNITS" -FE"$BIN"
         -XPi386-go32v2- -FD"$XTOOLS" -Fu"$XUNITS")
MARCOPTS=(-Tgo32v2 -Mobjfpc -Fumystic -Fimystic
          -FU"$UNITS" -FE"$BIN"
          -XPi386-go32v2- -FD"$XTOOLS" -Fu"$XUNITS")
PASS=0; FAIL=0

# ============================================================
# Pre-flight: check for cross-tools
# ============================================================
check_tools() {
    if [ ! -d "$XTOOLS" ]; then
        echo "ERROR: DOS cross-tools not found at $XTOOLS"
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
    local src="mystic/${t}.pas" log="out-dos/${t}.build.log"
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
echo "Mystic BBS DOS (go32v2) cross-build ($(date))"
echo ""
chmod +x "$XTOOLS"/* "$FPC" 2>/dev/null
for t in mystic mplc maketheme mbbsutil mystpack install install_make 109to110; do
    build "$t"
done
build marc objfpc
echo ""
echo "Passed: $PASS  Failed: $FAIL"
