# Mystic BBS IRC Fork — RIPscrip v1.54 Engine Whitepaper

## Overview

The IRC fork's RIPscrip engine is a single-unit implementation (`v1/ripscr.pas`)
that renders all 53 RIPscrip v1.54 commands to a software pixel buffer
(`rip_surface.pas`). It replaces the multi-unit architecture of the original
binary with one `TRIPEngine` class containing all parsing, execution, text
window management, icon handling, mouse fields, and fill pattern logic.

## Architecture Decisions

### Single-unit engine vs multi-unit split

The original binary splits RIP handling across 11 units (RIPCMD, RIPPARSE,
RIPDISP, RIPMOUSE, RIPICON, RIPPARAM, RIPFONT, RIPRES, RIPRSRC, RIPRESUT,
MEGANUM). The IRC fork consolidates everything into `TRIPEngine` in
`v1/ripscr.pas`. Reasons:

- **No circular deps.** A single class with methods can't create circular unit
  references.
- **Single state owner.** All engine state (cursor, colors, fill patterns,
  mouse fields, clipboard) lives on one object. No global vars, no module-level
  `SurfRef` pointers.
- **Easier to test.** Create a `TRIPEngine`, feed it bytes, read pixels.

### Software pixel buffer vs BGI Graph unit

The original uses `uses Graph` (Turbo Pascal BGI) for all drawing — Line,
Circle, Bar, SetColor, etc. The IRC fork uses `rip_surface.pas`, a 640×350
byte array where each byte is an EGA palette index (0–15). Drawing primitives
(Bresenham lines, midpoint ellipses, scanline fills) operate directly on this
buffer.

Reasons:
- **Headless rendering.** ripview renders RIP files to BMP without a display.
- **Cross-platform.** Same code runs on Linux (native), DOS (GO32V2 via
  fpc264irc), and potentially anywhere FPC compiles.
- **BMP export.** `SaveBMP` writes the pixel buffer directly to a 24-bit BMP
  using the EGA palette for color lookup.

### Fill patterns

`DrawFillPixel` uses `BGColor` for empty fill (`FillStyle=0`), not hardcoded
black (0). This matches the RIPtermJS reference implementation. The predefined
pattern table (`FillPats`) is indexed 2–11 (10 hatching patterns); boundary
check uses `<= 11`.

`DrawLine` swaps endpoints when `Y1 < Y0` to ensure consistent subpixel
positioning on diagonals. Without this swap, Bezier curves rendered via
sequential `DrawLine` calls leave gap leaks at curve inflection points where
the sweep direction reverses. This was verified against RIPtermJS `_line()`.

### MegaNum

Both implementations decode base-36 numbers (0–9, A–Z). The IRC fork uses
positional in-place parsing: `MegaNum(S, Pos, Digits)` advances `Pos` through
the string while reading exactly `Digits` characters. The original uses
`DecodeMegaNum(S)` which decodes the entire string. Same math, different API —
ours avoids temporary string allocations during command parsing.

### TextWindow + ANSI

Text window state (cursor position, colors, font size, bold/blink) lives
directly on `TRIPEngine` as fields (`TextWinCurCol`, `TextWinCurRow`,
`TextWinFG`, `TextWinBG`, etc.). The `ProcessTextAnsi` method handles ANSI CSI
escape sequences within the text window:

- **SGR (m):** Colors use SGR→EGA mapping table. Bold sets high bit. Reverse
  swaps FG/BG.
- **Cursor (H/f/A/B/C/D):** Absolute and relative positioning.
- **Erase (J/K):** Clear display or clear to end of line.

Text window scroll (`TextWinScroll`) copies pixel rows directly in the buffer —
no `Graph.GetImage`/`PutImage`. Five font sizes supported (8×8, 7×8, 8×14,
7×14, 16×14) via `TW_FontWidths`/`TW_FontHeights` tables.

`TextWinWrite` detects `ESC[` sequences inline while outputting text, routing
them to `ProcessTextAnsi` without breaking the character stream.

### Mouse fields

Flat array of 20 `TRIPMouseField` records, matching Mystic BBS data layout.
The original binary uses 10 tables × 20 regions. The v1.54 RIPscrip spec
uses a single table — multi-table is a viewer extension, not protocol.

### Icon format

ICN load/save works directly on the pixel buffer. Format: 2-byte LE width,
2-byte LE height, then `width × height` bytes (EGA palette indices). HIC
(high-color ICN) format is documented from binary reconstruction but not yet
implemented.

### Command IDs

All 53 command IDs verified against `RIPPARAM.PAS` `IdentifyCommand`, which
was reconstructed from binary data segment offsets `0x11560–0x1160f`. Our
`ParseLevel0`/`ParseLevel1`/`ParseLevel9` case statements match.

## API Reference

### Types

```pascal
TRIPEngine        — Main engine class. Create, feed bytes, read pixels.
TRipSurface       — 640×350 pixel buffer with drawing primitives.
TRipCanvas        — Abstract base class for rendering backends.
TRipRGB           — Record: R, G, B: Byte
TRipColor         — Byte (EGA palette index 0–15)
TRIPMouseField    — Record: X0, Y0, X1, Y1, HostCmd, Text, Style fields
TRIPFillPattern   — Array[0..7] of Byte (8×8 fill pattern)
TRIPButtonStyle   — Record: bevel colors, surface, label placement
```

### Constructor / Destructor

```pascal
Constructor TRIPEngine.Create;    — Allocates pixel buffer, inits all state
Destructor  TRIPEngine.Destroy;   — Frees pixel buffer and clipboard
```

### Entry Points

```pascal
Procedure ProcessRIP(Const Line: String);  — Parse one RIP command line
Procedure ProcessByte(B: Byte);            — Feed one byte (stream mode)
```

### Drawing Primitives

```pascal
Procedure DrawPixel(X, Y: SmallInt; Color: Byte);
Procedure DrawLine(X0, Y0, X1, Y1: SmallInt);
Procedure DrawRect(X0, Y0, X1, Y1: SmallInt);
Procedure DrawBar(X0, Y0, X1, Y1: SmallInt);
Procedure DrawCircle(XC, YC, Radius: SmallInt);
Procedure DrawOval(XC, YC, XR, YR: SmallInt);
Procedure DrawFilledOval(XC, YC, XR, YR: SmallInt);
Procedure DrawArc(XC, YC, StartAng, EndAng, Radius: SmallInt);
Procedure DrawOvalArc(XC, YC, StartAng, EndAng, XR, YR: SmallInt);
Procedure DrawPieSlice(XC, YC, StartAng, EndAng, Radius: SmallInt);
Procedure DrawOvalPie(XC, YC, StartAng, EndAng, XR, YR: SmallInt);
Procedure DrawPolygon(var Points: Array of TRIPPoint; Count: Integer);
Procedure DrawBezier(X1, Y1, X2, Y2, X3, Y3, X4, Y4, Steps: SmallInt);
Procedure FloodFill(X, Y: SmallInt; Border: Byte);
```

### State

```pascal
Procedure SetDrawColor(Color: Byte);
Procedure SetFillColor(Color: Byte);
Procedure SetFillStyle(Style: Word; Color: Byte);
Procedure SetFillPattern(var Pattern: TRIPFillPattern; Color: Byte);
Procedure SetWriteMode(Mode: Integer);
Procedure SetLineStyle(Style, Pattern, Thickness: Word);
Procedure SetFontStyle(Font, Direction: Word; Size: Word);
Procedure SetTextJustify(Horiz, Vert: Word);
```

### Text Window

```pascal
Procedure SetTextWindow(X0, Y0, X1, Y1: SmallInt; Size: Byte);
Procedure ResetTextWin;
Procedure TextWinPutChar(Ch: Byte);
Procedure TextWinWrite(const S: String);
Procedure TextWinScroll(Direction: Integer);
Procedure ProcessTextAnsi(const S: String);
```

### Viewport

```pascal
Procedure SetViewPort(X0, Y0, X1, Y1: SmallInt; Clip: Boolean);
Procedure GetViewPort(var X0, Y0, X1, Y1: SmallInt);
```

### Mouse Fields

```pascal
Function  AddMouseField(X0, Y0, X1, Y1: SmallInt; HostCmd, Text: String): Integer;
Procedure KillMouseField(Index: Integer);
Procedure KillAllMouseFields;
Function  FindMouseField(X, Y: SmallInt): Integer;
Function  GetMouseCount: Integer;
Function  GetMouseField(Index: Integer): TRIPMouseField;
```

### Icons

```pascal
Function  LoadIcon(FileName: String; X, Y: SmallInt; Mode: Byte): Boolean;
Function  SaveIcon(FileName: String; X0, Y0, X1, Y1: SmallInt): Boolean;
```

### Clipboard

```pascal
Procedure WriteClipboardICN(FileName: String);
```

### Output

```pascal
Procedure SaveBMP(const FileName: String);  — on TRipSurface
Function  GetMaxX: SmallInt;
Function  GetMaxY: SmallInt;
```

### Stats

```pascal
StatLines, StatRects, StatBars, StatCircles, StatPixels,
StatTexts, StatTotalCmds: LongInt;
```

## Compiler

FPC 2.6.4 IRC fork (`fpc264irc`). Build flags: `-Mdelphi`. ShortStrings
(`{$H-}`) used throughout the engine to avoid AnsiString stack issues in
FPC 2.6.4. No Turbo Pascal overlays (`{$O+,F+}`), no CRT unit, no DOS unit.

## Platform Targets

- **Linux** (native, 64-bit) — primary development and test platform
- **DOS / GO32V2** — via fpc264irc cross-compiler, runs in DOSBox
- ptcgraph for DOS VGA framebuffer, NOT Linux X11

## Font

IBM VGA 8×8 from ROM dump (`rip_font8x8.inc`). 256 characters, 2048 bytes.
Verified correct across all 18 copies in the repository. Key verification:
char 219 (█) = all `$FF`, char 65 (A) = `$30,$78,$CC,$CC,$FC,$CC,$CC,$00`.

## VIPER Refactor (Planned)

### V1 Integration of Proper Engine Rendering

The homebrew pixel buffer engine (Bresenham lines, midpoint circles, scanline
fills) is archived in `attic/rip_v1_homebrew/`. VIPER replaces the display
path with mdl's m_output system extended with a pixel framebuffer mode.

**What stays:** The 640×350 pixel buffer, MegaNum parser, command dispatch,
TextWindow + ANSI, mouse fields, icon handling, CHR fonts.

**What changes:** Display goes through m_output instead of direct pixel buffer
manipulation. m_output gets a graphics mode (pixel-addressable framebuffer)
alongside its existing text mode (80×50 char cells). Output drivers
(m_output_linux, m_output_windows, m_output_dos) each render the pixel buffer
to their native display.

**What goes away:** m_output_graph.pas (ptcgraph/X11 dependency), the
{$IFDEF USEGRAPH} build path, rip_surface.pas as a standalone rendering
backend (absorbed into m_output's pixel buffer mode).

**Why not BGI/ptcgraph:** ptcgraph requires X11 on Linux. We need headless
rendering (ripview) and cross-platform display without X11. mdl's m_output
already abstracts platform differences — extending it is cleaner than
introducing a new dependency.

### Conflict Resolution Rules

When merging reconstructed source code or porting between versions:

1. **mdl types are authoritative** — record layouts match mystic's binary data files
2. **No module-level globals** for engine state — all state on class instances
3. **All new code uses {$MODE DELPHI}, {$H-}** — ShortStrings, Delphi syntax
4. **Platform code uses ifdefs** for Linux, Windows, and DOS/GO32V2
5. **Test against real RIP art** — pixel accuracy against known viewers decides which implementation to keep
6. **Dependency graph checked** before adding uses clauses — no circular deps
7. **Name prefixes** — RIP_ for engine, OUT_ for display, TW_ for text window
