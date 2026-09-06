# RFF Font Format 

## Source: RIPaint 2.0 / RIPterm 2.0 (TeleGrafix, 1997)
## Files: COBB.RFF, DEFAULT.RFF, DIXON.RFF, MARIN.RFF, SYMBOL.RFF
## Registry: ATF.CFG (Active TeleGrafix Font config)

## Format Version: 2.2

## Header (0x00-0x0F)
- 0x00 [word]: Data size (file size - overhead)
- 0x02-0x0F: Reserved (zeros)

## Font Descriptor (0x10-0x41)
- 0x10 [word]: Header size (always 16)
- 0x12 [byte]: Major version (2)
- 0x13 [byte]: Minor version (2)
- 0x14 [word]: First char code (e.g., 46 = '.')
- 0x16 [word]: Last char code (e.g., 54 = '6')
- 0x18 [word]: Unknown (1026 common)
- 0x1A [word]: Design units (17560 = 0x4498, common to all fonts)
- 0x1C [sword]: Ascent (positive, in design units)
- 0x1E [sword]: Max width (in design units)
- 0x20 [sword]: Descent (negative, in design units)
- 0x22-0x41: Additional metrics

## Font Name (0x42+)
- Null-terminated ASCII string (e.g., "Cobb", "DEFAULT")

## Face Table (after name, 10 faces per font, ~46 bytes each)
Each RFF contains 10 variant faces:
1. Regular
2. Thin (Th)
3. Condensed (Cn)
4. Wide (Wd)
5. Extra/Bold (Ex)
6. Hollow/Outline (Ho)
7. Hollow Thin (HT)
8. Hollow Condensed (HC)
9. Hollow Wide (HW)
10. Hollow Extra (HE)

## Glyph Data
After the face table. Appears to be relative vector stroke commands
(signed bytes for pen movement, similar to BGI CHR format but more
compact). Bytes like 03, FB (-5), 00, suggest relative coordinate
deltas.

## Stroke Rendering — RIPTEL.EXE GDI Import Analysis

RIPTEL.EXE's PE import table confirms RFF strokes are rendered using
exactly three Windows GDI functions:

- **MoveToEx()** — pen up, reposition without drawing
- **LineTo()** — pen down, draw straight line to new position
- **CreatePen()** — set line style and width

**No curves.** No Bezier, no Arc, no BeginPath/EndPath/StrokePath.
RFF is pure polyline data: sequences of MoveTo + LineTo calls only.

### Pen Support via CreatePen()

The face table's FaceID bitmask controls pen parameters:
- Thin (FaceID=2): narrower CreatePen width
- Extra/Bold (FaceID=16): wider CreatePen width
- Hollow faces (FaceID bit 4 set): outline-only rendering

CreatePen() is called per-face to set the stroke width before
rendering glyph strokes. The pen width scales with the requested
font size relative to the 17560 design units per em.

### Stroke Command Encoding — Partially Decoded

The stroke data is a byte stream where bytes 0x00-0x03 appear as
**inline command markers** between coordinate pairs:

| Byte | Count in '.' glyph | Likely meaning |
|------|-------------------|----------------|
| 0x00 | 49 | Continue / path separator |
| 0x01 | 20 | Sub-path start (MoveTo) |
| 0x02 | 46 | Line segment (LineTo) |
| 0x03 | 8 | Close sub-path / curve hint |

The stream format appears to be: `[dx] [dy] [cmd] [dx] [dy] [cmd] ...`
where each triplet is a signed byte delta-X, signed byte delta-Y,
then a command byte telling the renderer what to do at the NEXT point.

**RIPAINT.EXE confirms** this is an opcode-based system:
- String "Stroke pen is too large" = pen width validation
- String "The Vector Sector" = internal name for the font engine
- Bezier support exists in RIPAINT's drawing tools (TBPOLYBZ,
  TBPOLYGN, TBPOLYLN) but the RFF rendering path uses only
  MoveToEx + LineTo

### What's Needed to Complete

- Render known characters in RIPterm at high zoom
- Screenshot and count individual line segments
- Compare segment endpoints with decoded (dx,dy) coordinates
- The mismatches reveal exact cmd byte semantics

## ATF.CFG Structure
- 0x00 [dword]: Unknown (checksum?)
- 0x04 [word]: Font count (50 = 5 fonts * 10 faces)
- 0x08+: Font entries, each containing:
  - Null-terminated filename (e.g., "COBB.RFF")
  - Font descriptor copy (same as RFF header 0x10+)

## Available Fonts
| File | Size | Name | Chars |
|------|------|------|-------|
| COBB.RFF | 62KB | Cobb | . / 0-6 (9 chars, 10 faces) |
| DEFAULT.RFF | 31KB | DEFAULT | . / 0-6 (9 chars) |
| DIXON.RFF | 42KB | Dixon | . / 0-6 (9 chars) |
| MARIN.RFF | 56KB | Marin | . / 0-6 (9 chars) |
| SYMBOL.RFF | 43KB | Symbol | . / 0-6 (9 chars) |

## Notes
- Glyph stroke decoder implemented in rip2api.pas LoadRFF — pen encoding: (0,0) = pen lift, first pair = move, rest = draw. Renders via DrawTextCHR.
