#!/bin/bash
# test_mterm.sh — mterm regression test
# Compile mterm.pas → check PASS/FAIL
# Usage: ./test_mterm.sh [path-to-fpc]

set -e

FPC="${1:-fpc}"
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/mterm.pas"

echo "=== mterm regression test ==="
echo "Compiler: $FPC"
echo "Source:   $SRC"
echo ""

if [ ! -f "$SRC" ]; then
    echo "FAIL: mterm.pas not found in $DIR"
    exit 1
fi

# Compile
echo "--- Compiling mterm.pas ---"
if $FPC -Mobjfpc -gl "$SRC" 2>&1 | tee /tmp/mterm_build.log; then
    # Check for warnings
    if grep -q "Warning:" /tmp/mterm_build.log; then
        echo ""
        echo "WARN: compiled with warnings"
        echo "RESULT: WARN"
        exit 1
    fi
    echo ""
    echo "RESULT: PASS — mterm compiles clean"
    exit 0
else
    echo ""
    echo "RESULT: FAIL — mterm did not compile"
    exit 1
fi
