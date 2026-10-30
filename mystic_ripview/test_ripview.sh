#!/bin/bash
# test_ripview.sh — ripview regression test
# Compile ripview.pas → check PASS/FAIL
# Usage: ./test_ripview.sh [path-to-fpc]

set -e

FPC="${1:-fpc}"
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$DIR/source"
SRC="$SRC_DIR/ripview.pas"
V1_DIR="$SRC_DIR/v1"

echo "=== ripview regression test ==="
echo "Compiler: $FPC"
echo "Source:   $SRC"
echo ""

if [ ! -f "$SRC" ]; then
    echo "FAIL: ripview.pas not found in $SRC_DIR"
    exit 1
fi

# Compile with unit search paths
echo "--- Compiling ripview.pas ---"
if $FPC -Mdelphi -gl -Fu"$SRC_DIR" -Fu"$V1_DIR" "$SRC" 2>&1 | tee /tmp/ripview_build.log; then
    # Check for warnings
    if grep -q "Warning:" /tmp/ripview_build.log; then
        echo ""
        echo "WARN: compiled with warnings"
        echo "RESULT: WARN"
        exit 1
    fi
    echo ""
    echo "RESULT: PASS — ripview compiles clean"
    exit 0
else
    echo ""
    echo "RESULT: FAIL — ripview did not compile"
    exit 1
fi
