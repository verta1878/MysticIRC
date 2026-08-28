#!/bin/sh
# Build the mystic_rip RIPscrip graphics example.
# Usage: ./build-rip.sh [win32]
# Pure FPC RTL + the runtime-loading sdl_bind from ../mystic_sdl (SDL2 is
# never linked; rip_render needs no SDL at all, rip_view degrades gracefully
# without it).
FPC=${FPC:-ppc386}
mkdir -p out bin
find . -name '*.ppu' -delete 2>/dev/null
find . -name '*.o'   -delete 2>/dev/null
# -B rebuilds units from source into OUR out/, and -FU/-FE are ABSOLUTE:
# with a relative -FU, FPC 2.6.2 records a relative object path in the
# .ppu, fails to find it at link time (out/out/...), and silently falls
# back to the unit SOURCE dir's out/ - which can hold a sibling build's
# object for the WRONG target.  Absolute paths make the link exact.
HERE=$(cd "$(dirname "$0")" && pwd)
OPTS="-B -Mobjfpc -O2 -Fu../mystic_sdl -FU$HERE/out -FE$HERE/bin"
if [ "$1" = "win32" ]; then
  echo "Building mystic_rip for Win32..."
  $FPC -Twin32 $OPTS rip_render.pas && \
  $FPC -Twin32 $OPTS rip_view.pas
else
  echo "Building mystic_rip for Linux..."
  $FPC -Tlinux $OPTS rip_render.pas && \
  $FPC -Tlinux $OPTS rip_view.pas
fi
echo "Done.  Executables in bin/  (rip_render is fully headless; rip_view"
echo "needs SDL2 + a display, and reports gracefully when absent)"
