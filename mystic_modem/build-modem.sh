#!/bin/sh
# Build the mystic_modem dialup/serial add-on.
# Usage: ./build-modem.sh              (linux, default)
#        ./build-modem.sh win32        (Win32 cross-compile)
#        ./build-modem.sh dos          (DOS go32v2 cross-compile)
#        ./build-modem.sh os2          (OS/2 cross-compile)
#
# Requires FPC 2.6.4irc in PATH or set FPC=path/to/compiler

FPC=${FPC:-ppc386}
HERE=$(cd "$(dirname "$0")" && pwd)
MDL="$HERE/../mystic/mdl"
MSERIAL="$MDL/m_serial"
MYSTIC="$HERE/../mystic"
OUT="$HERE/out"
BIN="$HERE/bin"
mkdir -p "$OUT" "$BIN"

find "$HERE" -name '*.ppu' -delete 2>/dev/null
find "$HERE" -name '*.o'   -delete 2>/dev/null

COMMON="-B -Mobjfpc -O2 -Fu$MDL -Fu$MSERIAL -Fu$MYSTIC -Fi$MDL -Fi$MSERIAL -Fi$MYSTIC -Fu$HERE -Fi$HERE -FU$OUT -FE$BIN"

case "$1" in
  win32)  echo "Building for Win32...";  T="-Twin32" ;;
  dos)    echo "Building for DOS...";    T="-Tgo32v2 -s" ;;
  os2)    echo "Building for OS/2...";   T="-Tos2 -s" ;;
  darwin) echo "Building for Darwin..."; T="-Tdarwin" ;;
  *)      echo "Building for Linux...";  T="-Tlinux" ;;
esac

PASS=0; FAIL=0
for src in modemcfg.pas wfcdemo.pas squish_example.pas; do
  [ -f "$HERE/$src" ] || continue
  name=$(basename "$src" .pas)
  if $FPC $T $COMMON "$HERE/$src" > "$OUT/$name.build.log" 2>&1; then
    echo "  OK    $name"
    PASS=$((PASS+1))
  else
    echo "  FAIL  $name"
    grep -iE 'Error|Fatal' "$OUT/$name.build.log" | head -2 | sed 's/^/    /'
    FAIL=$((FAIL+1))
  fi
done

echo "Done. $PASS built, $FAIL failed. Binaries in $BIN/"
