
=====================================================================
==       SEGMENT 8: FONT SPECIFICATION                             ==
=====================================================================

RIPscrip supports two classes of fonts: bitmap fonts (fixed-width
raster glyphs) and BGI stroke fonts (scalable vector glyphs stored
in Borland CHR binary format). This segment documents both.


---------------------------------------------------------------------
8.1  BITMAP FONTS
---------------------------------------------------------------------

Font ID 0 selects the bitmap font. Two bitmap glyph tables exist in
the CP437 source data:

     Font         Size    Encoding     Characters
     ----------   -----   ----------   ----------
     CP437 8×8    8×8     1 bit/pixel  256 (0x00-0xFF)
     CP437 8×16   8×16    1 bit/pixel  256 (0x00-0xFF)

IMPLEMENTATION NOTE (RIPlib): the protocol parser renders bitmap text
with the 8×16 face exclusively — every command-driven text path uses
`cp437_8x16`. The 8×8 table ships in the font set and is available to
direct `draw_text()` callers (the `examples/demo.c` program uses it),
but no RIPscrip command selects it: the `font_size` field scales the
BGI *stroke* fonts, not the bitmap face, and the original DLL likewise
rejected the 8×8 bitmap for metrics-dependent text. An 8×16-only bitmap
face is therefore the intended behaviour, not a missing feature.

CP437 is the IBM PC code page 437 character set, which includes
ASCII printable characters (0x20-0x7E), accented letters
(0x80-0xA5), box-drawing characters (0xB0-0xDF), and Greek/math
symbols (0xE0-0xFE).

Glyph data layout:

     8×8 font:   ch * 8 + row  → 1 byte per row, 8 rows per glyph
                 Total: 256 × 8 = 2,048 bytes

     8×16 font:  ch * 16 + row → 1 byte per row, 16 rows per glyph
                 Total: 256 × 16 = 4,096 bytes

Bit ordering:

     8×8:    LSB-first (bit 0 = leftmost pixel)
             Bit 0 = leftmost pixel, Bit 7 = rightmost pixel
             NOTE: CP437 source data is MSB-first. RIPlib reverses
             bits at init time for draw_text compatibility.

     8×16:   MSB-first (standard PC convention)
             Bit 7 = leftmost pixel, Bit 0 = rightmost pixel

Rendering:

     draw_text(x, y, str, len, font_data, font_height, fg, bg)

     fg:  Foreground color (palette index for "on" pixels)
     bg:  Background color (palette index for "off" pixels)
          0xFF = transparent background (skip "off" pixels)

     Character advance: 8 pixels per character (fixed-width)


---------------------------------------------------------------------
8.2  BGI STROKE FONTS — OVERVIEW
---------------------------------------------------------------------

Font IDs 1-10 select BGI stroke fonts. These are scalable vector
fonts stored in Borland CHR binary format, originally shipped with
Turbo C/C++ and Turbo Pascal (1987-1994).

     ID   Name              File        Characters   Top
     --   ---------------   ---------   ----------   ---
     1    Triplex           TRIP.CHR    223          24
     2    Small             LITT.CHR    223          7
     3    Sans-Serif        SANS.CHR    254          25
     4    Gothic            GOTH.CHR    223          25
     5    Script            SCRI.CHR    223          25
     6    Simplex           SIMP.CHR    223          28
     7    Triplex Script    TSCR.CHR    223          24
     8    Complex           LCOM.CHR    223          28
     9    European          EURO.CHR    223          45
     10   Bold              BOLD.CHR    224          53

Character ranges:
     Most fonts: 223 characters, first_char=0x20 (space) to 0xFE
     SANS.CHR:   254 characters, first_char=0x01 to 0xFE
     BOLD.CHR:   224 characters, first_char=0x20 to 0xFF

The "Top" metric is the distance from the baseline to the top of
capital letters, in unscaled font units. Multiply by the scale
factor (1-10) for the rendered height in pixels.


---------------------------------------------------------------------
8.3  CHR BINARY FORMAT
---------------------------------------------------------------------

The CHR file format consists of a text header (copyright notice)
followed by binary font data. The bgi2c.py tool strips the text
header and outputs the binary section as a C array.

Original CHR file layout:

     Offset   Content
     ------   -------
     0x00     Text header: "PK\x08\x08BGI Stroked Font..."
              Copyright text ending with 0x1A (Ctrl-Z)
     var      0x80 byte (binary section marker)
     var+1    Binary prefix: font name, version, metadata
     0x80     '+' marker (0x2B) — start of font data
     0x81+    Font data section (see §8.4)

After bgi2c.py processing (text header stripped):

     Offset   Content
     ------   -------
     0x00     Binary prefix metadata
     ~0x26    '+' marker (0x2B)
     ~0x27+   Font data section

The '+' marker position varies slightly between fonts (typically
byte 37-39 in the stripped data). The parser must SCAN for 0x2B
rather than assuming a fixed offset.


---------------------------------------------------------------------
8.4  FONT DATA SECTION (after '+' marker)
---------------------------------------------------------------------

All offsets below are relative to the '+' marker position.

     Offset   Size    Field
     ------   -----   ---------------------------
     +1       2       num_chars (LE word)
     +3       1       undefined (0x00)
     +4       1       first_char (ASCII code)
     +5       2       stroke_data_offset from '+' (LE word)
     +7       1       scan_flag (normally 0)
     +8       1       org_to_top (signed byte)
     +9       1       org_to_baseline (signed byte)
     +10      1       org_to_bottom (signed byte)
     +11      5       reserved (zeros)

     +16      nc×2    Stroke offset table (LE words)
     +16+nc×2 nc×1    Width table (unsigned bytes)
     +stroke_data_offset  Stroke data

TABLE ORDER IS CRITICAL: The stroke offset table comes FIRST,
then the width table. Many implementations (including early
versions of this library) had these reversed, producing garbled
glyph rendering.

The stroke_data_offset field gives the byte offset from '+' to
the start of the stroke data. It equals 16 + 3×num_chars
(header + offsets table + width table).

'+' marker validation:
     When scanning for 0x2B, validate that:
     - num_chars is in range 32-255
     - first_char is <= 0x20
     - stroke_data_offset is > 0 and < data_size
     This prevents false matches on 0x2B bytes in the metadata.


---------------------------------------------------------------------
8.5  STROKE OFFSET TABLE
---------------------------------------------------------------------

     Location: '+' + 16
     Size:     num_chars × 2 bytes
     Format:   Little-endian 16-bit unsigned integers

Each entry gives the byte offset within the stroke data section
where that character's stroke commands begin. Offsets are relative
to the start of the stroke data (NOT relative to '+').

     character_strokes = stroke_data + offsets[char - first_char]

Characters with offset 0 typically have no visible strokes
(e.g., the space character).


---------------------------------------------------------------------
8.6  WIDTH TABLE
---------------------------------------------------------------------

     Location: '+' + 16 + num_chars × 2
     Size:     num_chars × 1 byte
     Format:   Unsigned 8-bit integers

Each entry gives the advance width of the character in unscaled
font units. Multiply by the scale factor for pixel advance.

     pixel_advance = widths[char - first_char] × scale

The width determines character spacing — it is the distance
the cursor advances after drawing the character, regardless of
the actual glyph bounding box.


---------------------------------------------------------------------
8.7  STROKE DATA ENCODING
---------------------------------------------------------------------

     Location: '+' + stroke_data_offset
     Format:   2 bytes per stroke point

Each stroke point is encoded as two bytes:

     Byte 0:  bit 7 = opcode_hi
              bits 6-0 = X coordinate (7-bit signed, -64 to +63)

     Byte 1:  bit 7 = opcode_lo
              bits 6-0 = Y coordinate (7-bit signed, -64 to +63)

Opcode (2 bits, combining bit 7 of both bytes):

     opcode_hi  opcode_lo  Value  Meaning
     ---------  ---------  -----  -------
     0          0          0      End of character
     0          1          1      (unused)
     1          0          2      Move to (pen up)
     1          1          3      Line to (pen down)

Signed 7-bit extraction:

     int16_t sign7(uint8_t v) {
         return (v & 0x40) ? (int16_t)(v | 0xFF80) : (int16_t)v;
     }

     x = sign7(byte0 & 0x7F)
     y = sign7(byte1 & 0x7F)

Coordinate system:
     X: positive = right, negative = left
     Y: positive = UP (BGI convention, inverted from screen)
     Origin: character baseline, left edge

Rendering a character:

     1. Look up stroke offset: offsets[ch - first_char]
     2. Set pen to character origin (ox, oy)
     3. Read 2-byte stroke points until opcode == 0:
          a. Extract opcode, x, y
          b. Scale: dx = x × scale, dy = y × scale
          c. If opcode == 2 (move): update pen position
          d. If opcode == 3 (line): draw_line from prev to new
     4. Return widths[ch - first_char] × scale as advance

Direction transforms (applied to scaled dx, dy):

     Direction 0 (horizontal):
          screen_x = ox + dx
          screen_y = oy - dy        (Y inverted)

     Direction 1 (CW, v3.1):
          screen_x = ox + dy
          screen_y = oy + dx        (screen-CW rotation)

     Direction 2 (CCW, v3.1):
          screen_x = ox - dy
          screen_y = oy - dx        (screen-CCW rotation)


---------------------------------------------------------------------
8.8  FONT METRICS
---------------------------------------------------------------------

Each parsed font provides three vertical metrics:

     Metric      Sign     Description
     ---------   ------   ----------------------------------
     top         positive Distance from origin to cap height
     baseline    zero     Origin line (reference point)
     bottom      negative Distance from origin to descender

These are in unscaled font units. Multiply by scale for pixels.

     Total glyph height = (top - bottom) × scale
     Cap height = top × scale
     Descender depth = (-bottom) × scale

Example (Triplex font, scale 2):
     top = 24, baseline = 0, bottom = -7
     Cap height = 24 × 2 = 48 pixels
     Descender = 7 × 2 = 14 pixels
     Total height = 31 × 2 = 62 pixels


---------------------------------------------------------------------
8.9  FONT ATTRIBUTES (v3.1)
---------------------------------------------------------------------

BGI stroke fonts support four rendering attributes set via the
RIP_FONT_ATTRIB command (|q). See §A2G.3 for full details.

     BOLD (0x01):      Double-stroke, +1px right offset
     ITALIC (0x02):    X shear by top×scale/5
     UNDERLINE (0x04): Baseline line after string
     SHADOW (0x08):    Dimmed copy at (+1,+1) offset

Attributes are applied by bgi_font_draw_string_ex() and only
affect stroke fonts (IDs 1-10). The bitmap font ignores attributes.


---------------------------------------------------------------------
8.10  FONT JUSTIFICATION
---------------------------------------------------------------------

Text justification is set via the flags parameter of
RIP_FONT_STYLE (|Y). See §2.7 for flag bit definitions.

Horizontal justification:
     LEFT (default): text starts at draw position
     CENTER:         text centered on draw position
     RIGHT:          text ends at draw position

Vertical justification:
     BOTTOM (default): text above draw position
     CENTER:           text centered on draw position
     TOP:              text below draw position
     BASELINE:         text at draw position (no offset)

Justification is applied by measuring the string width
(bgi_font_string_width) and offsetting the draw position
before rendering. The measurement uses the width table
without rendering any strokes.


=====================================================================
==                    END OF SEGMENT 8                              ==
==           Font Specification                                     ==
=====================================================================

Next: Segment 9 — Icon & File Pipeline
