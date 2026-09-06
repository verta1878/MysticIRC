#!/bin/sh
# Build the mystic_modem dialup/serial add-on.
# Usage: ./build-modem.sh          (builds wfcdemo for linux i386)
#        ./build-modem.sh win32    (cross note: needs FPC win32 with serial.ppu)
#
# The module depends on Mystic's mdl/ units (m_IniReader, m_FileIO) and on
# FPC's standard cross-platform Serial unit.

FPC=${FPC:-ppc386}
MDL=../mdl
OUT=out
BIN=bin
mkdir -p "$OUT" "$BIN"

# clean stale artifacts
find . -name '*.ppu' -delete 2>/dev/null
find . -name '*.o'   -delete 2>/dev/null

if [ "$1" = "win32" ]; then
  echo "Building mystic_modem for Win32..."
  # On a full FPC 2.6.2 Windows install, the Serial unit ships in the RTL.
  $FPC -Twin32 -Mobjfpc -O2 -Fu"$MDL" -Fi"$MDL" -FU"$OUT" -FE"$BIN" wfcdemo.pas
  $FPC -Twin32 -Mobjfpc -O2 -Fu"$MDL" -Fi"$MDL" -FU"$OUT" -FE"$BIN" modemcfg.pas
else
  echo "Building mystic_modem for Linux (i386)..."
  $FPC -Tlinux -Mobjfpc -O2 -Fu"$MDL" -Fi"$MDL" -FU"$OUT" -FE"$BIN" wfcdemo.pas
  $FPC -Tlinux -Mobjfpc -O2 -Fu"$MDL" -Fi"$MDL" -FU"$OUT" -FE"$BIN" modemcfg.pas
fi

echo "Done.  Executable in $BIN/"
