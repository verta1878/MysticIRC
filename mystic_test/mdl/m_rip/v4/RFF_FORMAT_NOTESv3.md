# RFF Font Format — Reverse Engineering Notes

## Source: RIPaint 2.0 / RIPterm 2.0 (TeleGrafix, 1997)
## Files: BRUSH.RFF, COBB.RFF, DEFAULT.RFF, DIXON.RFF, EUREKA.RFF, MARIN.RFF, OAKLAND.RFF, SYMBOL.RFF
## Registry: ATF.CFG (Active TeleGrafix Font config)
## Format Version: 2.2
## Decoder: rffdecraw.pas (GPLv3, part of fpc264irc)

---

## File Structure Overview

```
Offset    Size     Content
──────────────────────────────────────
0x00      2        Data size (file size - overhead)
0x02      14       Reserved (zeros)
0x10      50       Font descriptor (version, char range, metrics)
0x42      460      Face table (10 faces × 46 bytes)
varies    varies   Per-char advance widths (word per char, full charset)
varies    varies   Per-char stroke offsets (dword per char, FirstChar..LastChar)
varies    rest     Stroke data (signed byte pairs)
```

## Header (0x00-0x0F)

* 0x00 [word]: Data size (file size - overhead)
* 0x02-0x0F: Reserved (zeros)

## Font Descriptor (0x10-0x41)

* 0x10 [word]: Header size (always 16)
* 0x12 [byte]: Major version (2)
* 0x13 [byte]: Minor version (2)
* 0x14 [word]: First char code (e.g., 46 = '.')
* 0x16 [word]: Last char code (e.g., 54 = '6')
* 0x18 [word]: Unknown (1026 common)
* 0x1A [word]: Design units per em (17560 = 0x4498, common to all fonts)
* 0x1C [sword]: Ascent (positive, in design units)
* 0x1E [sword]: Max width (in design units)
* 0x20 [sword]: Descent (negative, in design units)
* 0x22-0x41: Additional metrics (purpose TBD)

## Font Name (0x42+)

* Null-terminated ASCII string (e.g., "Cobb", "DEFAULT", "Dixon")
* Part of Face 0 (Regular) entry

## Face Table (0x42+, 10 faces × 46 bytes each)

Each RFF contains 10 variant faces at fixed 46-byte intervals:

| Index | Suffix | Face Type | FaceID byte |
|-------|--------|-----------|-------------|
| 0 | (none) | Regular | 1 |
| 1 | Th | Thin | 2 |
| 2 | Cn | Condensed | 4 |
| 3 | Wd | Wide | 8 |
| 4 | Ex | Extra/Bold | 16 |
| 5 | Ho | Hollow/Outline | 17 |
| 6 | HT | Hollow Thin | 18 |
| 7 | HC | Hollow Condensed | 20 |
| 8 | HW | Hollow Wide | 24 |
| 9 | HE | Hollow Extra | 18 |

### Face Entry Layout (46 bytes)

```
Offset  Size  Content
 0      ~20   Face name (null-terminated, zero-padded)
20      9     Reserved (zeros)
29      1     Unknown (always 1)
30      3     Reserved
33      1     Unknown (always 16 = 0x10)
34      2     Per-face metric (word, varies: 988-996)
36      1     FaceID (bitmask: 1,2,4,8,16,17,18,20,24)
37      1     Per-face parameter (signed, face-specific metric)
38      2     Reserved
40      2     Per-face metric
42      2     Per-face metric
44      2     Reserved
```

## Per-Character Advance Widths

Immediately after face table (offset = 0x42 + 10×46 = 0x20E).
Array of signed words (SmallInt), one per character.
Covers full charset (typically 96-234 entries, chars 32-265).

Example (DIXON.RFF):
```
[.] = 277   [/] = 277   [0] = 354   [1] = 555
[2] = 555   [3] = 888   [4] = 666   [5] = 221
[6] = 332
```

Values are in design units (17560 = 1 em). Width 555 ≈ 3.2% of em.

## Per-Character Stroke Offsets

After the width table. Array of DWORDs, one per glyph
(FirstChar..LastChar only). Values are byte offsets relative
to the start of the stroke data section.

Example (DIXON.RFF, 9 chars):
```
[.] = 2228   [/] = 2555   [0] = 2879   [1] = 2967
[2] = 3123   [3] = 3279   [4] = 3492   [5] = 3589
[6] = 3677
```

Stroke length = next offset - current offset.
Last char length = end of file - last offset.

## Stroke Data (CONFIRMED: signed byte pairs)

After the offset table. Each glyph's strokes are a sequence of
signed byte pairs representing coordinate deltas (dx, dy).

```
Example (DIXON.RFF, char '.'):
  dx=+102 dy=  -3  → move/draw to (+102, -3)
  dx= +72 dy=  +0  → continue to (+174, -3)
  dx=  +1 dy=  +0  → continue to (+175, -3)
  dx= +59 dy=  +0  → continue to (+234, -3)
  dx= +40 dy=  -3  → continue to (+274, -6)
  dx= +61 dy=  +3  → continue to (+335, -3)
  ...
```

### Stroke Command Encoding — TODO

The pen up/down (move vs draw) command encoding has NOT been
fully decoded. Possible interpretations:

1. **Special byte values as commands**
   * 0x7F (+127) or 0x80 (-128) may signal pen up/down
   * 0x00 0x00 may signal end of sub-path or glyph
   * Values 0x7FFF in word context = sentinel

2. **First pair = pen-up move to start position**
   * Subsequent pairs are all pen-down (draw)
   * 0x00 0x00 = lift pen, next pair = move to new position

3. **BGI-like encoding with modified opcodes**
   * High bit of dx byte = pen state
   * Remaining 7 bits = signed delta
   * Similar to CHR format but with byte-sized deltas

### What's Needed to Complete

* Render known characters in RIPterm
* Screenshot the output at high zoom
* Compare pixel coordinates with decoded stroke paths
* Identify which byte patterns correspond to pen lifts

## ATF.CFG Structure

Font registry file used by RIPaint/RIPterm.

* 0x00 [dword]: Unknown (checksum or magic?)
* 0x04 [word]: Font count (50 = 5 fonts × 10 faces)
* 0x08+: Font entries, each containing:
  * Null-terminated filename (e.g., "COBB.RFF")
  * Font descriptor copy (mirrors RFF header 0x10+ structure)

## Available Fonts

| File | Size | Name | Chars | Source |
|------|------|------|-------|--------|
| BRUSH.RFF | — | Brush | TBD | RIPtel v3.1 |
| COBB.RFF | 62KB | Cobb | . / 0-6 (9 chars, 10 faces) | RIPaint 2.0 |
| DEFAULT.RFF | 31KB | DEFAULT | . / 0-6 (9 chars) | RIPaint 2.0 |
| DIXON.RFF | 42KB | Dixon | . / 0-6 (9 chars) | RIPaint 2.0 |
| EUREKA.RFF | — | Eureka | TBD | RIPtel v3.1 |
| MARIN.RFF | 56KB | Marin | . / 0-6 (9 chars) | RIPaint 2.0 |
| OAKLAND.RFF | — | Oakland | TBD | RIPtel v3.1 |
| SYMBOL.RFF | 43KB | Symbol | . / 0-6 (9 chars) | RIPaint 2.0 |

## File Size Math

```
DEFAULT.RFF: 31596 bytes total
  Header:        66 bytes (0x00-0x41)
  Face table:   460 bytes (10 × 46)
  Glyph data: 31070 bytes (widths + offsets + strokes)
  Per glyph avg: 345 bytes (31070 / 90 glyphs across 10 faces)
  Per glyph:     ~170 signed byte pairs (coordinate points)
```

## Notes

* Parser implemented in rffdecraw.pas (GPLv3, FPC 2.6.4irc)

