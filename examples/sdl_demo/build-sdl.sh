#!/bin/sh
# Build the mystic_sdl SDL2 DOS-session front-end.
# Usage: ./build-sdl.sh [win32]
# Runtime-loads SDL2 (SDL2.dll / libSDL2-2.0.so.0 / libSDL2.dylib); nothing is
# linked at compile time, so this builds with no SDL present.
FPC=${FPC:-ppc386}
mkdir -p out bin
find . -name '*.ppu' -delete 2>/dev/null
find . -name '*.o'   -delete 2>/dev/null
if [ "$1" = "win32" ]; then
  echo "Building mystic_sdl for Win32..."
  $FPC -Twin32 -Mobjfpc -O2 -FUout -FEbin sdl_demo.pas
else
  echo "Building mystic_sdl for Linux..."
  $FPC -Tlinux -Mobjfpc -O2 -FUout -FEbin sdl_demo.pas
fi
echo "Done.  Executable in bin/  (needs SDL2 + VGA8X16.FNT at runtime)"
