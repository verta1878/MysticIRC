# MAF (MicroANSI Font) Format — Reverse Engineering Notes

## Source: RIPterm v2.0 / RIPtel v3.1 (TeleGrafix, 1997)
## File: RIPscrip.maf (270,945 bytes)
## Purpose: Bitmap character font for ANSI text window rendering

---

## Overview

The MAF file is a **multi-resolution bitmap font container** used by
RIPterm/RIPtel to render text in the ANSI text window at different
screen resolutions. Unlike RFF vector fonts (used for graphics drawing),
MAF provides fixed-size bitmap glyphs for the terminal text display.

The file header identifies itself as: `RIPterm v2.0 MicroANSI Font File`

Note: Although the format is labeled "v2.0", the analyzed file
(RIPscrip.maf) ships with RIPtel v3.1 (Windows).

## File Header (0x00-0x29)

```
Offset  Size   Content
0x00    1      Start marker (0x04 = EOT)
0x01    33     ASCII: " RIPterm v2.0 MicroANSI Font File "
0x24    1      End marker (0x04 = EOT)
0x25    2      Line break (0x0A 0x0D)
0x27    2      End of text (0x00 0x1A = NUL + EOF marker)
```

The 0x1A byte is a DOS end-of-file marker, preventing `TYPE` from
dumping binary data if someone tries to view the file as text.

## Resolution Table

After the header, the file contains multiple resolution entries.
Each entry provides bitmap font data for a specific screen mode.

### Known Resolutions

| Resolution | Description | Notes |
|-----------|-------------|-------|
| 640x480 | VGA standard | Primary resolution |
| 800x600 | VGA extended | SVGA |
| 1024x768 | VGA extended | SVGA |
| Small 640x480 | Compact variant | Smaller cell size |
| 799x599 | Off-by-one | Client area (scrollbar?) |
| 1023x767 | Off-by-one | Client area (scrollbar?) |

### Resolution Entry Structure (Tentative)

Each resolution block appears to contain:

```
Offset  Size   Content
0       2      Screen width (word, e.g., 640, 800, 1024)
2       2      Screen height (word, e.g., 480, 600, 768)
4       20     Font offsets (5 DWORDs - offsets to font bitmaps)
24      32     Resolution name (null-terminated ASCII, zero-padded)
```

Example offsets from 640x480 entry:
```
Font 0: offset 0x01A4 (420)
Font 1: offset 0x0CCB (3275)
Font 2: offset 0x17F2 (6130)
Font 3: offset 0x2B11 (11025)
Font 4: offset 0x3E30 (15920)
```

The 5 fonts per resolution likely correspond to different text modes
or character cell sizes (e.g., 8x8, 8x14, 8x16, 8x11, etc.)

## Bitmap Font Data

Each font within a resolution entry is a standard bitmap font:
256 characters x N bytes per character, where N = character height.

Common bitmap font heights:
- 8 pixels: 256 x 8 = 2048 bytes
- 11 pixels: 256 x 11 = 2816 bytes
- 14 pixels: 256 x 14 = 3584 bytes
- 16 pixels: 256 x 16 = 4096 bytes

Each character is 8 pixels wide (1 byte per scanline), stored as
a column of N bytes from top to bottom. Bit 7 = leftmost pixel.

The string "8x11" appears in the file, suggesting at least one
font uses an 8x11 character cell.

## Embedded Glyph Verification

Starting around offset 0x190, recognizable CP437 bitmap patterns
appear. For example, the byte sequence for box-drawing characters
(0xB0-0xDF) and the standard VGA font glyphs are visible in the
raw hex dump, confirming these are standard 256-character bitmap
fonts compatible with IBM PC Code Page 437.

## Relationship to Other Files

- **RFF fonts** (.rff): Scalable vector fonts for graphics drawing
  commands. Rendered via MoveToEx/LineTo with CreatePen.
- **MAF fonts** (.maf): Fixed bitmap fonts for the ANSI text window.
  Rendered as pixel bitmaps at the configured resolution.
- **CHR fonts** (.chr): BGI stroke fonts from v1.54, also vector
  but simpler than RFF.

## What's Needed to Complete

- Confirm exact resolution entry structure (field sizes and order)
- Verify font count per resolution (5 assumed from offset count)
- Confirm character cell dimensions for each sub-font
- Test rendering against RIPterm text window output
- Determine if the "off-by-one" resolutions (799x599, 1023x767)
  are client area sizes with scrollbar compensation

## Notes

- The file is 270,945 bytes - large enough for 6 resolutions
  x 5 fonts x ~4000 bytes average = ~120KB of bitmap data,
  plus overhead and padding
