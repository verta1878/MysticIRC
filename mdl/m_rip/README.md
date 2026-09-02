# mdl/m_rip — RIPscrip Engine Library

Engine units for RIPscrip rendering. Part of MDL.

## Engine Versions

| Dir | What |
|-----|------|
| v1/ | RIPscrip v1.54 (DOS i8086 real-mode) |
| v2/ | RIPscrip v2.0 (DOS go32v2 / DPMI) |
| v3/ | RIPscrip v3.0 (modern platforms) |
| v4/ | RIPscrip v4.0 (full stack, 1995 multimedia PC) |

## Support Units

| File | What |
|------|------|
| rip_canvas.pas | Canvas abstraction (TRipCanvas base class) |
| rip_surface.pas | Software raster backend (TRipSurface, 640x350 pixel buffer) |
| rip_render.pas | BMP batch renderer |
| rip_term.pas | Terminal integration (TTermRip stream interpreter) |
| rip_window.pas | SDL2 viewport presenter |
| mripchr.pas | CHR stroked font parser |
| mripui.pas | MRP widget renderer (boxes, windows, buttons, frames) |
| tchr.pas | CHR font data types |
| tui.pas | TUI widget types |
| rip_font8x8.inc | IBM VGA 8x8 bitmap font (256 chars, all 18 copies verified) |


## Rendering Stack

Single rendering stack: ripscr.pas engine renders through rip_surface.pas pixel buffer.

**Procedural stack** (ripview path):
  Direct pixel buffer access. 225/225 RIP art files pass.

**OOP stack** (mystic/mterm path):
  `rip_term.pas` → `rip_canvas.pas` → `rip_surface.pas`
  Class-based with TRipRGB pixels. ICN loading, TextWindow wired.

## Session 9 Additions (2026-08-28)

- TextWindow + ANSI processing folded into v1/ripscr.pas from reconstructed source.
  Backend-agnostic via callback function pointers (TWGetPixel, TWSetPixel,
  TWFillRect, TWDrawChar). Both stacks wire their own adapters.
- Command parsing and execution integrated into v1/ripscr.pas.
  shared mdl/m_rip/. Both ripview and mterm compile against this location.
- OOP stack: TextWindow state wired, RGB adapter callbacks, ICN LoadIcon
  implemented (was stub).

## Remaining Port Work (from JVIEW reconstruction)

| Unit | What | Status |
|------|------|--------|
| ripres.pas | .RES resource container reader (JVIEW font bundles) | TODO |
| ripplay.pas | Slideshow/playback manager (playlist, pause, timed advance) | TODO |

## Tools

Standalone programs are in mystic_ripview/tools/.
Full documentation in todo/ripscrip/M_RIP-README.md.

## VIPER Refactor (Planned)

Codename VIPER — V1 Integration of Proper Engine Rendering. Replaces the
homebrew pixel buffer display path with mdl's m_output system extended with
a graphics pixel buffer mode. No ptcgraph, no X11 dependency. Pre-VIPER
code archived in `attic/rip_v1_homebrew/`. See `todo/VIPER.md` for full plan.
