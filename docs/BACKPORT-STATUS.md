# RIP Engine Backport Status — ALL ENGINES

## Fix Matrix

| Fix | ripviewer | v1 | v2 | v3 | v4 | mterm |
|-----|-----------|----|----|----|----|-------|
| JS Bresenham (den/num) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Bezier Floor()+endpoint | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| FloodFill scanline+visited | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Fill pattern bgcolor | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Bar fill patterns | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Line dash patterns | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Button bevel OUTSIDE | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| SUNKEN flag (bit 15) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CHISEL flag (bit 3) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| TextWindow 222211 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CHR font Y-offset | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 8x8 font (JS-matched) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| EraseView (viewport) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Viewport in FloodFill | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| | separator | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| |! comment handler | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Printer drivers | N/A | N/A | ✅ | ✅ | ✅ | N/A |

ALL 9 engines at parity. No backports remaining.

## Engine Locations
1. examples/ripviewer/ — standalone pixel-tested viewer
2. mystic_rip/v1/ripscr.pas — TRIPEngine v1
3. mystic_rip/v2/rip2api.pas — TRIPEngine v2 + 256-color
4. mystic_rip/v3/rip3api.pas — TRIPEngine v3 + RGB24/32
5. mystic_rip/v4/rip4api.pas — TRIPEngine v4 + printers
6. mystic_rip/rip_surface.pas — TRipSurface canvas split
7. mystic_test/rip_graph.pas — older engine
8. mystic_test/experimental/m_rip_graph.pas — MDL experimental
9. examples/mterm/mtrip.pas+mtripgfx.pas — terminal client
