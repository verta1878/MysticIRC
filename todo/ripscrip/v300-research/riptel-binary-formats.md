# RIPtel 3.1 (TeleGrafix, 1997) - Binary Format Triage

Source tree: `/home/tracker1/src/rip-tools/artifacts/RIPtel/` All offsets little-endian unless noted. Confidence: H=high, M=medium, L=low.

---

## 1. `.RFF` outline fonts (FONTS/*.RFF, 8 files) - **Atech Software "FastFont" scalable outline format** [H]

**Identification.** Not TrueType, not OTTO, not BGI, not Windows FNT. Every file ends with the trailer string `COPR:\0Copyright 1991, Atech Software, Carlsbad CA` (e.g. COBB.RFF 0xF4DA). Uninitialized-buffer garbage inside the headers leaks the strings `COBB.FF1`, `DIXON.FF1`, `bordlg AllType`, `s:\ rip f` - **.FF1 is Atech's FastFont extension** and **AllType** was Atech's font-conversion product. Conclusion: TeleGrafix licensed Atech's scalable font engine ("ATF" in `atf.cfg` = Atech FastFont / AllType Font) and shipped Atech FastFont files renamed `.RFF` ("RIPscrip FastFont"). BRUSH.RFF even contains leaked PostScript tokens (`DC3 put`, `dup 20`) - likely residue of AllType converting Type 1 sources.

**Files/sizes:** BRUSH 87155, COBB 62725, DEFAULT 31596, DIXON 42071, EUREKA 70789, MARIN 56526, OAKLAND 64213, SYMBOL 43601. No shared magic bytes at offset 0 - the first u32 is a per-file offset (see below). Reliable signature instead: bytes `10 00 02 02 2E 00 36 00 02 04 98 44` at offset 0x10, and `26 54` ("&T") at 0x34.

**Header layout hypothesis (offsets verified across all 8 files):**

| Offset | Type | Value / meaning |
| --- | --- | --- |
| 0x00 | u32 | Offset of trailer section (kerning/copyright). COBB: 0xF4C1; BRUSH: 0x1544D - both verified to land on the trailer record. |
| 0x04 | 12 bytes | zero (reserved) |
| 0x10 | u16 | 0x0010 (16) - constant; version or header size |
| 0x12 | u8,u8 | 02 02 - constant |
| 0x14 | u16 | 0x002E (46) - **style-record size** |
| 0x16 | u16 | 0x0036 (54) - **offset of first style record** |
| 0x18 | u8,u8 | 02 04 - constant |
| 0x1A | u16 | 0x4498 - constant format signature/version |
| 0x1C | u16 | per-font metric (max advance width?): DEFAULT/DIXON/MARIN/OAKLAND 250, COBB 274, BRUSH 305, SYMBOL 328, EUREKA 358 |
| 0x1E | u16 | per-font metric (ascender / bbox ymax): 500-1184 range |
| 0x20 | s16 | negative per-font metric (descender / bbox ymin): -750..-1110 |
| 0x22 | s16 | small negative per-font metric (bbox xmin?): -32..-159 |
| 0x24 | u16 | 0x00E0 (224) - **glyph count** = chars 0x20-0xFF |
| 0x26 | u16 | 0x0020 (32) - **first character code** |
| 0x28 | u16 | 1 - constant |
| 0x2A | u16 | 0x000A (10) - **number of style variants** (matches 10 records) |
| 0x2C | u16 | 0x03E8 (1000) - **units per em** (PostScript-style em square) |
| 0x2E | u16×3 | 01 00, 00 00, 01 00 - constants |
| 0x34 | u16 | 0x5426 = ASCII "&T" - sentinel ending the fixed header |

**Style-variant table @0x36:** 10 records × 46 bytes. Record layout:

- +0 u16: font handle/ID (engine-assigned, differs per file: COBB 0x3E5.., EUREKA 0x24..; not meaningful across files)
- +2 u8: **style flags bitfield** - 0x00 normal, 0x01 Thin, 0x02 Condensed, 0x04 Wide, 0x08 Extended; +0x10 = Hollow modifier (Ho=0x10, HT=0x11, HC=0x12, HW=0x14, HE=0x18)
- +3 u8: **horizontal scale percent** - 0x64=100 (normal/hollow), 0x55=85 (Th), 0x4B=75 (Cn), 0x7D=125 (Wd), 0x96=150 (Ex)
- +4 8 bytes: `00 0F 05 F8 1E 14 00 00` constant (engine parameters, possibly hollow-outline stroke widths)
- +12: NUL-terminated style name ("Cobb", "Cobb Th", … "Cobb HE"), field padded to record end - padding is **uninitialized memory** (source of the leaked .FF1/AllType/PostScript strings), so parsers must stop at the first NUL.

So each RFF exposes 10 logical fonts: base + Th/Cn/Wd/Ex + hollow versions of all five. This matches RIPscrip 3.0's scalable-font style axes.

**After the style table** (≈0x202): a second per-font metrics block echoing the header values (0x212 area repeats e8 03 / 98 44 / bbox values), then glyph loca/metrics and outline (stroke/curve) data - not yet decoded.

**Trailer section (at u32@0x00):** record `u16 tag(=1), u16 byteLength, u16 0x00FF, u16 0x012C(=300), u16 pairCount`, then pairCount × {char1 u8, char2 u8, s16 delta} - a **kerning pair table**. BRUSH: 7 pairs FL -61, GL -76, PL -76, ZA -45, gb -91, gd -51, gh -96 (units of 1/1000 em). COBB: 1 dummy pair "||" delta 0. A 5-byte separator `B7 BC BA AB BE` delimits sections; the final section is `COPR:\0<copyright text>` to EOF.

**Open questions:** exact glyph outline opcode encoding; meaning of constants 0x4498 and the 8-byte style parameter block; whether 0x012C (300) in the trailer is a nominal design ppem.

### Related: `FONTS/atf.cfg` (4470 bytes) - ATF engine font catalog/cache [H]

**Binary, not a text config.** Layout: 8 file entries (each = filename string `BRUSH.RFF`… + a verbatim copy of that file's 0x00-0x35 header, including the "&T" sentinel), followed by all 80 style-variant records (8 fonts × 10 styles, same 46-byte record format as in the RFF files, same uninitialized-garbage padding). It is the pre-scanned registry the ATF rasterizer uses to map style names → file + handle without opening every RFF at startup. Safe to regenerate; machine-written by RIPTEL.

### Related: `FONTS/RIPscrip.maf` (270945 bytes) - "RIPterm v2.0 MicroANSI Font File" [H]

Magic: `04 20 "RIPterm v2.0 MicroANSI Font File " 04 0A 0D 00 1A` (offset 0). Then u16 count = 6, u32 = 0x3C (first-record offset region). Six 64-byte resolution records starting 0x38: `u16 width, u16 height, u32 offset[5], char name[40]` - "640x480 VGA" (640×480), "800x600 - VGA", "1024x768 - VGA", "Small 640x480" (639×479), "799x599", "1023x767". Each of the 5 offsets points to a bitmap font record: `u16 cellW, u16 cellH, char name[...]` + raw 8-bit glyph bitmaps for the full 256-char set (first record "8x11" at 0x1A4; classic CP437 smiley glyph bitmap visible at 0x1D6). This is the fixed-cell "MicroANSI" terminal font set (5 sizes per resolution) - the RIP 3.0 text-mode/ANSI emulation fonts.

> **Correction (2026-08-08):** the record dimensions above are wrong. The resolution-directory records are **60 bytes** - `u16 width, u16 height, u32 fontOffset[5], char name[36]` - starting at **0x3C** (the u32 at 0x2A is the directory offset, which happens to be 0x3C in this file). Verified: 0x3C + 6 × 60 = 0x1A4, exactly the first font subrecord's offset, while a 64-byte/`name[40]` stride misparses record 1 onward (width 25,660, ASCII garbage in the offsets). The font subrecords are a **50-byte header** (`u16 cellW, u16 cellH, char name[30], u16 lastChar = 0x00FF, u16 bytesPerGlyph, byte[12]` reserved) followed by **255 glyphs** for chars 0x01-0xFF (char 0x00 not stored; the smiley at 0x1D6 is char 0x01 at 0x1A4 + 50), each font ending at exactly `offset + 50 + 255 × bytesPerGlyph` = the next offset or EOF. Full layout and the 2.x comparison: [`../techspecs/3.3-microansi-maf-delta.md`](../techspecs/3.3-microansi-maf-delta.md).

---

## 2. `.CHR` fonts (FONTS/*.CHR, 10 files) - **standard Borland BGI stroked fonts** [H]

All 10 begin `50 4B 08 08` + `BGI Stroked Font V1.1 - <date>\r\nCopyright (c) 1987,1988 Borland International\r\n\x1A\x80\x00` followed by the 4-char internal font name. Names and build dates:

| File     | Internal name | BGI build date |
| -------- | ------------- | -------------- |
| BOLD.CHR | BOLD          | Jun 5, 1989    |
| EURO.CHR | EURO          | May 17, 1989   |
| GOTH.CHR | GOTH          | Jun 5, 1989    |
| LCOM.CHR | LCOM          | Feb 11, 1994   |
| LITT.CHR | LITT          | Jun 12, 1993   |
| SANS.CHR | SANS          | Jun 5, 1989    |
| SCRI.CHR | SCRI          | Jun 5, 1989    |
| SIMP.CHR | SIMP          | Jun 5, 1989    |
| TRIP.CHR | TRIP          | Jun 5, 1989    |
| TSCR.CHR | TSCR          | Aug 3, 1989    |

Exactly the RIPscrip 1.54-era vector font set (BOLD EURO GOTH LCOM LITT SANS SCRI SIMP TRIP TSCR), all file dates Oct 25 1996. LCOM/LITT have later BGI toolkit dates (1993/94) - rebuilt with a newer Borland font editor, but the format is unchanged. Nothing new to document beyond the known BGI .CHR spec.

---

## 3. `.BMH` files (ICONS/, 5 files) - **standard Windows BMPs; "H" = highlight-state variant of same-named .BMP** [H]

Files: BUTTON, CHECKBOX, RADIO, RADIOBUT, RADIONEW (.BMH). Each is a perfectly valid Windows 3.x BMP, and each has a same-named .BMP sibling with **identical file size, identical dimensions/bit depth/palette, identical timestamps** - `cmp` shows differences confined to the pixel-data area only (e.g. BUTTON pair: first diff at byte 119, bits offset is 118; CHECKBOX pair: first diff at 1142, bits offset 1078). Pixel deltas run in the light direction (BUTTON.BMH has 0xFF/white nibbles where BUTTON.BMP has 0x88 grey; RADIO.BMH black/white where RADIO.BMP is grey 0x77). Interpretation: **.BMH = "BitMap Highlight" - the pre-rendered highlighted/pressed image RIPTEL swaps in for BMP-skinned UI controls (buttons, checkboxes, radio buttons) on hover/click.** The extension is the only thing distinguishing it; the format is plain BMP. Pairs (all in ICONS/): 22×17×4bpp BUTTON, 17×17×8bpp CHECKBOX, 15×11×4 RADIO, 25×17×4 RADIOBUT, 15×15×8 RADIONEW.

---

## 4. `.COL` files (ICONS/DEMO-01.COL, DEMO-02.COL, FONTTEXT.COL) - **NOT palettes: RIPscrip 3.0 "column" scene scripts** [H]

Plain ASCII RIPscrip command streams (CR line endings, `!|` prefixed commands, `#|#|#` terminator) - the same on-the-wire syntax as .RIP files. The name matches the "column system" described in FONTSTOR.TXT ("A powerful column system is available for displaying formatted text"): a .COL is the reusable page template that flows an external text file through text columns with pagination. Notable 3.0 syntax captured (documentation gold):

- `!|1e<coords><flags>...` - define a text column/flow region (DEMO-01 defines three: `1e4L3D919K01…`, `1e9L4SDF6811…`, `1eDP4SHI5V21…`).
- `!|1R00000000$overflow(N,cur)$` - READ/render the current overflow buffer N into the defined columns. Target may also be a literal filename (`!|1R...dragon.txt` elsewhere).
- `$overflow(N,page)$`, `$overflow(N,prev,setverbose)$`, `$overflow(N,next,setverbose)$`, `$overflow(N,cur)$` - template functions for pagination state ("Page $overflow(1,page)$" page counters; prev/next buttons re-invoke the same .COL: `ID=6:$overflow(1,prev,setverbose)$$>demo-01.col$`).
- `<<if $RETURN$!="">>$<<RETURN>>$<<else>>$NULL$<<endif>>` - inline conditional template language inside mouse-region (`1M`) definitions.
- `!|y...Marin` / `...dixon` / `...cobb` - scalable-font select naming the RFF fonts directly.
- Other 3.0 commands present: `1K`, `!|=`, `J10`, `n2000`, `M08`, `fZKQO`, `N00`, `K<9-mega>`, `S0101`/`S0166`, `c0B`, `@<coords>text`, `1E` (end?), `1\x1b5000$MCURSOR(4)$` (ESC-class command setting mouse cursor shape), `2C...|!` (copy screen region to port, per inline comment in FONTTEXT.COL).
- Comment convention seen: `!|!` used as no-op/comment lines; `|!` inline.

So `.COL` = "column layout" scripts; `>file.col` in a button template loads them exactly like a .RIP scene.

---

## 5. `RIPSCRIP.RES` (root, 10490 bytes) - **TeleGrafix "RIPterm v2.0 Resource File" container** [M-H]

Not a Win16 resource. Magic at 0: `04 20 "RIPterm v2.0 Resource File " 04 0A 0D 00 1A` - same magic convention as RIPscrip.maf (`\x04␠<description>␠\x04\n\r\x00\x1A`), followed by u16 count = 6 and a mostly-zero directory. Contents observed: a ~112-byte high-entropy blob at 0x66 (registration key / scrambled data?), then VGA DAC palettes (6-bit 0x00-0x3F RGB triplets: the standard 16-color EGA palette, a 16-step greyscale ramp, and a 256-color RGB cube) starting ~0xD5, at least one embedded BMP (`BM` visible in strings), and - bizarrely - a trailing **C source text fragment**: `unsigned char resource_tvopt.rsc[] = { 0xC4, 0x20, ... };` (a hex dump of a "tvopt.rsc" resource containing UTF-16 "MS Sans Serif"), i.e. TeleGrafix shipped a build artifact where a developer's generated C array was appended/left in the file. Dated Nov 13 1996 - a RIPterm 2.x-era leftover carried into RIPtel. Open question: directory entry format (the count=6 suggests 6 sections but the directory bytes are zeroed).

---

## 6. ICONS/ extension sweep - nothing new [H]

Full census (234 files): BMP 102, FN 48, RIP 35, JPG 7, DEF 7, RET 6, MSE 5, BMH 5, TXT 4, MNU 4, EXT 4, ENT 4, COL 3. No extensionless files, no other extensions. Root dir extras not previously examined: `RIPSCRIP.DB` (400 bytes, binary), `riptel.pho` (phone book), `MESSAGES.HLP`/`RIPSCRIP.HLP`/`RIPTEL.HLP`, `Files/` subdir, and `RIPTEL.EXE` (PE32 GUI, i386 - notable: 32-bit Windows binary, likely packed since strings yield almost nothing). FONTS/ extras: `atf.cfg` and `RIPscrip.maf` (both documented above).

---

## 7. Story `.TXT` files (DRAGON, STORY01, STORY02, FONTSTOR) - **plain prose, no markup** [H]

All four are pure ASCII paragraphs with CR (`\r`) line endings - no `!|` commands, no template `$...$` codes, no formatting markup at all. (Content: DRAGON = Jim Thompson/Boardwatch preface; STORY01/02 = TeleGrafix RIPscrip-3 press releases; FONTSTOR = description of the two font systems and the column system.) Therefore in RIP 3.0 **`!|1R <target>` (READ) treats a .txt target as raw text to be flowed/word-wrapped into the previously defined text columns (`1e` regions), with automatic pagination into numbered overflow buffers** queried via `$overflow(n,page|cur|next|prev)$`. `1R` does not parse RIPscrip from .txt targets; layout comes entirely from the .COL/.RIP scene that issues the command. Bare-CR line endings imply CR is the paragraph/line-break convention the flow engine expects.
