# v1 Engine Backport Status

Fixes backported from ripviewer to mystic_rip/v1/ripscr.pas:

## DONE (8 fixes)
- [x] Command parser | separator (bare | for subsequent commands)
- [x] JS-matched Bresenham line algorithm (den/num/numadd)
- [x] TextWindow params 222211 (wrap/size are 1 digit not 2)
- [x] Bezier Floor() rounding + explicit endpoint
- [x] FloodFill scanline with visited buffer (replaces 4-dir push)
- [x] DrawFillPixel — draws BGCOLOR for pattern gaps
- [x] Button bevel draws OUTSIDE coords (was inside)
- [x] Button SUNKEN (bit 15) and CHISEL (bit 3) flags

## ALREADY CORRECT IN V1
- [x] Oval parameter count (already reads 6 params)
- [x] GetImage/PutImage (already implemented)
- [x] Icon loading (.ICN format with mask support)
- [x] CHR vector font loading
- [x] Fill patterns (FillPats array)
- [x] EGA palette (stores indices, conversion elsewhere)

## NOT APPLICABLE TO V1
- Canvas height (v1 uses dynamic sizing)
- BMP output format (v1 renders to screen, not BMP)
- Viewport coordinate offset (v1 has different viewport model)
- 8x8 font (v1 has multi-mode font system: 8x8, 8x14, etc)
