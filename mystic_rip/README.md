# Mystic RIP — Utilities & Engines

## Standalone Utilities

### ans2rip.pas (618 lines)
ANSI art to RIPscrip converter. Reads .ANS files with CP437 characters
and color attributes, renders each character glyph pixel by pixel using
the 8x16 VGA font, then emits RIPscrip |B (Bar) commands to reproduce
the image. Handles run-length merging of adjacent same-color bars to
minimize output size. Supports up to 80 rows (RIP 2-digit MegaNum limit).

```bash
fpc -Mdelphi ans2rip.pas && ./ans2rip input.ans output.rip
```

### ans2png.pas (394 lines)
ANSI art to BMP renderer. Reads .ANS files and renders them to a
Windows BMP image using the 8x16 VGA font and standard EGA 16-color
palette. No RIP conversion — direct pixel rendering.

```bash
fpc -Mdelphi ans2png.pas && ./ans2png input.ans output.bmp
```

### ripmake.pas (190 lines)
RIP file generator — creates simple RIP files programmatically.
Useful for testing the RIP engines with known-good command sequences.

### test_rip_files.pas (131 lines)
Batch RIP test harness. Loads all .RIP files from a directory, renders
each through the engine, saves BMPs, and reports success/failure.

### rip_sample.pas (76 lines)
Minimal example showing how to use the RIP engine API. Creates a
simple scene (lines, circles, fills, text) and saves to BMP.

## Support Units

### rip_canvas.pas (157 lines)
Thin canvas abstraction over TRipSurface. Provides a simplified
drawing API for utilities that don't need the full v1-v4 engine.

### rip_render.pas (119 lines)
RIP-to-BMP batch renderer. Wraps the engine with file I/O for
command-line rendering workflows.

### rip_surface.pas (775 lines)
TRipSurface — canvas/surface split from the v4 engine. Provides
pixel buffer, drawing primitives, and BMP export independent of
the command parser. Used by rip_canvas, rip_render, rip_window.

### rip_term.pas (599 lines)
Terminal-side RIP integration. Bridges between the terminal emulator's
data stream and the RIP command parser. Handles RIP detection (!|),
mode switching, and screen buffer management.

### rip_window.pas (192 lines)
RIP viewport/window manager. Handles the split between text window
and graphics viewport as defined by the |w and |v commands.

## Engines (in subdirectories)

| Engine | Location | Lines | Features |
|--------|----------|-------|----------|
| v1 | v1/ripscr.pas | 4,123 | Base RIPscrip 1.54 |
| v2 | v2/rip2api.pas | 5,331 | + 256-color + printers |
| v3 | v3/rip3api.pas | 8,308 | + RGB24/32 + printers |
| v4 | v4/rip4api.pas | 8,578 | + native printers |

## v3/v4 Utility Programs

| Utility | Lines | Purpose |
|---------|-------|---------|
| ripbind.pas | 338 | Binary scene decoder |
| ripchnge.pas | 324 | Delta/diff patch decoder |
| ripdecr.pas | 444 | Stream decoder (incremental) |
| riplayr.pas | 290 | Layer-based scene decoder |
| riprndr.pas | 186 | Progressive renderer |
| riptile.pas | 366 | Tile-based scene decoder |

## v4 Image Decoders

| Decoder | Lines | Format |
|---------|-------|--------|
| bmpdec.pas | 186 | Windows BMP/DIB |
| gifdecr.pas | 510 | GIF (animated) |
| jpgdecr.pas | 308 | JPEG |
| pngcodec.pas | 393 | PNG |
| pcxdec.pas | 179 | ZSoft PCX |
| tgadec.pas | 185 | Targa TGA |
| pbmdec.pas | 162 | Netpbm PBM/PGM/PPM |
| icodec.pas | 182 | Windows ICO/CUR |
| flidec.pas | 481 | FLI/FLC animation |

## Build

All utilities compile with Free Pascal 3.2.2+ or fpc264irc:

```bash
cd mystic_rip
fpc -Mdelphi -Fu. -Fuv1 -Fu../mdl -Fi../mdl ans2rip.pas
fpc -Mdelphi -Fu. -Fuv1 -Fu../mdl -Fi../mdl ans2png.pas
```

## Code Audit (2026-08-08)

- All utilities compile with zero errors
- rip_surface.pas: added missing Math unit (Floor)
- ans2rip.pas: restored RS2 variable after cleanup
- ans2png.pas: removed 3 unused variables
- ripdraw.pas: removed unused variable I
- riptext.pas: removed unused variables R, C
