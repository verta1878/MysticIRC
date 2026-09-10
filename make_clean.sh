#!/usr/bin/env bash
# ============================================================
#  Mystic 1.10 A38irc-A63 — Clean all build output
# ============================================================
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"

echo "Cleaning all build output..."

# Output directories (compiled binaries)
rm -rf out-linux out-win32 out-dos out-os2 out-freebsd out-darwin release

# Compiled units and objects
find . -name '*.ppu' -not -path "*/fpc264irc/*" -delete 2>/dev/null
find . -name '*.o' -not -path "*/fpc264irc/*" -delete 2>/dev/null
find . -name '*.a' -not -path "*/fpc264irc/*" -not -path "*/libs/*" -delete 2>/dev/null
find . -name '*.or' -delete 2>/dev/null
find . -name '*.res' -not -path "*/fpc264irc/*" -delete 2>/dev/null

# Linked executables (Linux — no extension)
for bin in mystic mis mutil mplc mide mbbsutil fidopoll nodespy \
           qwkpoll mystpack install install_make maketheme 109to110 marc; do
    rm -f "$bin" 2>/dev/null
done

# Linked executables (Win32/DOS)
rm -f *.exe 2>/dev/null

# Linked executables (OS/2 EMX)
rm -f *.out 2>/dev/null

# Compiled MPL bytecode
find . -name '*.mpx' -delete 2>/dev/null

# Linker artifacts
rm -f link.res ppas.sh ppas.bat 2>/dev/null

# Build logs
find . -name '*.build.log' -delete 2>/dev/null

echo "Clean."
