# mystic_sdl — optional SDL2 full-screen DOS-session front-end for Mystic A38

An **optional, separate** front-end that renders a full-screen **DOS text
session** (80x25, CP437, colour) in an **SDL2** window — the same toolkit
g00r00 uses for the NetRunner terminal.  It gives the dialup/modem and BinkP
Waiting-For-Caller screens (and, in future, a live session) a real graphical
DOS-style window instead of relying on the host console.

This is a **"future if they pick it"** option: nothing in the core or the other
add-ons depends on it.  A sysop who wants the graphical DOS look enables this;
everyone else keeps the plain console screens.

## Why SDL2

A terminal/DOS emulator needs pixel-accurate CP437 font rendering, colour
attributes, and its own window — exactly what SDL2 provides and what a text
console cannot.  (For a plain status screen the console is fine; this module is
for the full DOS-session look.)  SDL2 is cross-platform: Windows, Linux, macOS.

## Design

- `sdl_bind.pas`   — a minimal SDL2 binding, RUNTIME-loaded (SDL2.dll /
                     libSDL2-2.0.so.0 / libSDL2.dylib), so this builds with no
                     SDL present and simply reports "unavailable" if missing —
                     the same drop-in-the-library model as Hunspell / cryptlib.
- `sdl_dosscreen.pas` — TDosScreen: an 80x25 CP437 text cell grid (char +
                     attribute per cell) rendered to an SDL window using an
                     embedded 8x16 VGA font.  WriteXY / colour / clear, plus a
                     LoadAnsi that feeds a .ANS/CP437 stream into the grid.
- `sdl_demo.pas`  — opens the window and renders the modem/BinkP WFC into it.

The runtime SDL2 binding (`sdl_bind.pas`) is also used by the **RIPscrip
graphics example** in `mystic_rip/` (its viewer builds with
`-Fu../mystic_sdl`); `sdl_bind` carries the mouse-button event constant and
coordinate-decode helpers for it.

## Cross-platform / Darwin

SDL2 runs on Windows, Linux and macOS.  The library is loaded at runtime by its
platform name, so the same source targets all three.  As elsewhere in this fork,
the Darwin build is maintained by code review (the build container cannot link
Darwin); it links on a real Mac with the SDL2 framework/dylib present.

## Size / bundling

The SDL2 runtime is ~1.9 MB per platform.  As with the other libraries, it is
loaded at runtime and NOT bundled in the repo — the sysop drops the SDL2 library
in place, exactly as NetRunner does.

## Status

Binding + DOS screen render verified headless (SDL dummy driver) in the build
container.  Real display use is a sysop-side test.

Note for Linux GUI testing: FPC 2.6.2-built i386 binaries crash inside
*modern distro* SDL builds (16-byte i386 stack-alignment ABI mismatch);
Windows SDL2.dll and period-appropriate Linux SDL builds are unaffected.
