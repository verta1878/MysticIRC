
## Session 6 — July 24-25, 2026

### ripviewer v1.0.0 — Full RIPtermJS Command Parity

**42/42 RIPscrip commands implemented** — all ported from RIPtermJS BGI.js.

#### Bugs Fixed
- **rcResetWindows (`!|#`) erased canvas** — was wiping pixel buffer right
  before BMP output. Fixed to reset viewport/cursor only (matching JS).
- **8×8 font instead of 8×16** — chg2rip outputs VGA 8×16 coordinates.
  Added vgafont.inc (8×16 CP437 ROM) and switched to MSB-first bit order.
- **EGA palette order vs CGA/ANSI order** — palette had indices 1=blue/4=red
  (EGA order) but chg2rip outputs SGR indices 1=red/4=blue (CGA order).
  Reordered palette constant to match chg2rip output.
- **Duplicate rcGotoXY handler** — removed.
- **'o' mapped to rcMove instead of rcFilledOval** — fixed parser.
- **rcMove orphan in enum** — removed ('m' = rcGotoXY is the move command).
- **Canvas height 350 too small** — increased to 1280 for multi-page ANSI
  (80 rows × 16px = 1280px).

#### Pixel-Perfect Verification
- **100.0% pixel match** (819,200 pixels, 0 mismatches) between ans2png
  reference and ripviewer output on sd-fluph test ANSI.

#### Drawing Primitives Added (ported from BGI.js)
- `DrawEllipse` — Bresenham ellipse outline
- `FillEllipse` — Bresenham filled ellipse with scanline
- `DrawArcLines` — trig-based arc with angle clipping (degree-by-degree)
- `DrawSector` — pie slice: arc + wedge lines + floodfill interior
- `FloodFill` — scanline stack-based flood fill
- `DrawBezier` — cubic Bezier curve (Bernstein polynomial)
- `FillPolyScanline` — scanline polygon fill (alienryderflex algorithm)
- `DrawRect` — rectangle outline via DrawLine

#### Command Handlers Added (26 new, 16 existing = 42 total)
Drawing: Oval, FilledOval, Arc, OvalArc, PieSlice, OvalPieSlice,
  Bezier, Polygon, FilledPolygon, PolyLine, Fill (FloodFill)
Style: FillPattern, LineStyle, WriteMode
Window: EraseView, EraseEOL, TextWindow, Viewport
Image: GetImage, PutImage, LoadIcon (stubs — skip args correctly)
Mouse: Mouse, KillMouseFields, Button, ButtonStyle (stubs)
Palette: SetPalette (all 16 entries)

#### Multi-char Command Parser
Expanded '1' prefix handler for: 1K, 1C, 1P, 1I, 1M, 1U, 1B commands.

#### Files Changed
- `mystic_rip/ripviewer/source/ripview.pas` — 599→1107 lines
- `mystic_rip/ripviewer/source/rip_font8x16.inc` — NEW (VGA 8×16 CP437 font)

#### Build Status
- ripviewer: 1107 lines, compiles clean (0 errors, 0 warnings)
- chg2rip: compiles clean
- All BBS binaries: compile clean

### ripviewer CLI Features

**File picker** — pass a directory to get an interactive numbered list:
  `ripview /path/to/rips/` → pick by number
  `ripview -l /path/to/rips/` → list only, no render

**Baud rate emulation** — `-b RATE` throttles rendering at simulated bps.
  Uses RIPtermJS formula: bytes/sec = baud/10 (8N1).
  Sleep per byte = 10000000/baud microseconds.
  Example: `-b 2400` renders 44KB file in ~183 seconds (real modem time).
  Supported: 300 1200 2400 4800 9600 14400 19200 28800 38400 57600 115200.

**Debug mode** — `-d` prints each command as it executes:
  `[42] !|B0D0FN0O0FZ` (line number + raw command)
  `  !|B0D0FN0O0FZ` (parsed command echo)
  Shows timing stats at end: lines, commands, milliseconds.

**Combo** — all flags work together: `ripview -d -b 9600 scene.rip out.bmp`

**Files:** ripview.pas 1330 lines, compiles clean, 100% pixel match preserved.

### ripviewer Free Vision GUI

**Compile:** `fpc -Mdelphi -dFREEVISION -Fu<fv-path> ripview.pas -oripviewgui`

Single source file, two targets:
- `ripview` — CLI mode (default, no defines needed)
- `ripviewgui` — Free Vision TUI (`-dFREEVISION`)

**GUI features (Free Vision TUI):**
- Menu bar: File (Open/Render/Stop/Quit), Baud, Debug
- File > Open: FV TFileDialog with *.rip filter
- Baud menu: Full Speed, 300-115200 bps
- Debug > Toggle: enable/disable command logging
- Debug > Clear: clear log
- Status line: file name, baud rate, debug state, command count
- F3=Open, F5=Debug, F9=Render, Alt-X=Quit

**1602 lines, both modes compile clean, 100% pixel match.**

### Modular Split

ripview.pas split into 7 units (1656 total lines):

**Shared (all versions):**
- `ripengine.pas` (87 lines) — canvas, palette, PutPixel, globals
- `ripdraw.pas` (286 lines) — line, rect, circle, ellipse, arc, bezier, floodfill, polygon
- `riptext.pas` (91 lines) — VGA 8x16 font, DrawBitmapChar, OutTextXY
- `ripbmp.pas` (70 lines) — BMP file output

**v1.54-specific (in v1/ subdirectory):**
- `v1/rip1parse.pas` (137 lines) — mega decoder, TRIPCommand enum, parser
- `v1/rip1exec.pas` (426 lines) — 42-command Case dispatcher

**Main program:**
- `ripview.pas` (559 lines) — CLI + FV GUI, file picker, baud, debug

Build: `fpc -Mdelphi -Fuv1 ripview.pas`

v2/v3/v4 can add their own `v2/rip2parse.pas`, `v2/rip2exec.pas` etc.
while sharing the engine, drawing, text, and BMP units.
