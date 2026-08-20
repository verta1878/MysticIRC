# ripdraw.pas — RIP Drawing Primitives Reference

## Overview

`ripdraw.pas` is the shared drawing primitive library for the RIPscrip
rendering engine. All RIPscrip commands ultimately call these primitives
to put pixels on the 640×350 EGA canvas.

Ported from RIPtermJS BGI.js (Carl Gorringe) to Pascal by evga.
Pixel-perfect match to the JavaScript reference implementation.

## Unit Dependencies

```
ripview.pas (main)
  └── rip1exec.pas (command dispatch)
        └── ripdraw.pas (drawing primitives)  ← this file
              └── ripengine.pas (canvas/palette/state)
```

## Drawing Primitives

### DrawLine(X1, Y1, X2, Y2)

Bresenham line algorithm using the JS BGI.js den/num/numadd formulation.

**CRITICAL:** Must use this specific Bresenham variant, NOT standard
`err = dx - dy`. The two algorithms produce different pixel positions on
diagonal lines. Bezier curve endpoints at junctions get 1-pixel gaps with
standard Bresenham, causing flood fill to leak through.

Bug history: DRAGON01.RIP flood fill leak — Session 6, traced to
Bresenham variant mismatch.

### DrawBezier(Points, Count)

Cubic bezier curve renderer. Uses `Floor()` rounding to match
`Math.floor()` in the JavaScript reference.

Explicit endpoint drawing ensures the last point is always plotted,
preventing gap-at-junction bugs.

### DrawArcLines(CX, CY, StartAngle, EndAngle, Radius)

Arc drawing by 1-degree stepping with trigonometric calculation.
Uses `Floor()` for trig results to match JS behavior.

### DrawEllipse(CX, CY, XRadius, YRadius)

Bresenham midpoint ellipse algorithm. Steps from `X = -XRadius` to match
the JavaScript reference's pixel ordering.

### FloodFill(X, Y, BorderColor)

Scanline flood fill with heap-allocated visited buffer.

**Visited buffer:** Bit-per-pixel (not byte-per-pixel) to save memory.
640×350 = 224,000 pixels → 28,000 bytes as bitmask.

**Stack limits:** Must match RIPterm 1.54's behavior. SyncTERM's overhaul
confirmed that flood fill seed ordering and stack depth affect which pixels
get filled on complex art. Pixel-perfect means matching RIPterm's bugs.

**Viewport-aware:** GetPixel clips to viewport bounds. Fill does not
leak outside the current viewport.

### FillRect(X1, Y1, X2, Y2)

Rectangle fill using `PutFillPixel` for pattern-aware rendering.

### FillEllipse(CX, CY, XRadius, YRadius)

Midpoint ellipse algorithm with horizontal scanline fill between
left and right edges of each row.

### PutFillPixel(X, Y, Color)

**Pattern-aware pixel drawing.** Checks the current 8×8 fill pattern
bitmap before drawing. If the pattern bit is 0, draws background color
instead. This is how BGI fill patterns work.

13 BGI fill patterns supported:
0. Empty (all background)
1. Solid (all foreground)
2. Line (horizontal lines)
3. Light slash (///)
4. Slash (thick ///)
5. Backslash (thick \\\)
6. Light backslash (\\\)
7. Hatch (grid)
8. Crosshatch (X pattern)
9. Interleave (checkerboard)
10. Wide dot (sparse dots)
11. Close dot (dense dots)
12. User-defined (custom 8×8 pattern)

## Canvas Model

All drawing goes through `PutPixel(X, Y, Color)` in `ripengine.pas`:

- Clips to viewport bounds (ViewX1..ViewX2, ViewY1..ViewY2)
- Color masked to 4 bits (0-15 EGA palette index)
- Writes to `Canvas.Pixels[X, Y]` byte array

Canvas is 640×350, EGA 16-color. Palette is modifiable via
`SetPalette` / `SetOnePalette` commands.

## 16-bit DOS Considerations

Current buffer: `array[0..639, 0..349] of Byte` = 224,000 bytes.
Exceeds 64KB single-segment limit on real-mode DOS.

For MT-10 (DOS i8086), needs row-pointer approach:
- 350 pointers × 640 bytes per row
- No single allocation over 64KB
- FloodFill visited buffer: bitmask (28KB, fits in one segment)
- Reference: riplib C99 implementation uses this approach

Not blocking — MT-10 deferred until fpc264irc complete.

## Line Styles

Line drawing respects the current line style set by `|=` (RIP_LINE_STYLE):

| Style | Pattern | Name |
|-------|---------|------|
| 0 | $FFFF | Solid |
| 1 | $CCCC | Dotted |
| 2 | $FC78 | Center |
| 3 | $F8F8 | Dashed |
| 4 | User | User-defined 16-bit pattern |

Line thickness stored in state but NOT yet applied to drawing
(accuracy issue — MT-18).

## Write Modes

Write mode set by `|W` (RIP_WRITE_MODE):

| Mode | Name | Operation |
|------|------|-----------|
| 0 | COPY_PUT | pixel = color |
| 1 | XOR_PUT | pixel = pixel XOR color |
| 2 | OR_PUT | pixel = pixel OR color |
| 3 | AND_PUT | pixel = pixel AND color |
| 4 | NOT_PUT | pixel = NOT color |

Write mode stored in state but NOT yet applied to PutPixel
(accuracy issue — MT-18).

## Test Coverage

125 RIP files tested across 3 runs:
- 100 files from 16colo.rs artpacks (ACiD, fire, mist, etc.)
- 15 ripviewer test files
- 10 ripviewer bug regression files

All 125 render without crash. Visual pixel comparison vs
RIPterm/SyncTERM still needed.

## Credits

- Carl Gorringe — RIPtermJS BGI.js (original JavaScript)
- evga — Pascal port, FPC 2.6.4irc
- kiddo — bug fixes, stub completion, SDL_mixer integration
- SyncTERM / Deuce — pixel-perfect accuracy reference
- riplib / BradHawthorne — 16-bit memory layout reference

## License

GPLv3
