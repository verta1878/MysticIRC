# v4 Engine Backport Status

Fixes backported from ripviewer to mystic_rip/v4/rip4api.pas:

## DONE (7 fixes)
- [x] JS-matched Bresenham line algorithm (den/num/numadd)
- [x] TextWindow params 222211 (wrap/size are 1 digit not 2)
- [x] Bezier Floor() rounding + explicit endpoint
- [x] FloodFill scanline with visited buffer (replaces 4-dir push)
- [x] DrawFillPixel — draws BGCOLOR for pattern gaps
- [x] Button bevel draws OUTSIDE coords (was inside)
- [x] Button SUNKEN (bit 15) and CHISEL (bit 3) flags

## ALREADY CORRECT IN V4
- [x] Command parser | separator (v4 already handles bare |)
- [x] Oval parameter count (already reads 6 params)
- [x] GetImage/PutImage (already implemented)
- [x] Icon loading (.ICN format with mask support)
- [x] CHR vector font loading
- [x] Fill patterns (FillPats array)
- [x] RGB pixel mode (v4 supports both indexed and RGB)
- [x] Printer drivers (prt/ directory: BMP, ESC/P, PCL, PostScript, raw)
