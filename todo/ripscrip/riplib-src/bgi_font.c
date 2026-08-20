/*
 * bgi_font.c — Borland BGI stroke font renderer for RIPlib
 *
 * Parses and renders BGI .CHR vector fonts. Each character is a series
 * of move-to (opcode 2) and line-to (opcode 3) commands, terminated
 * by opcode 0 (end of character).
 *
 * Stroke encoding (2 bytes per point):
 *   byte0[7]   = opcode bit 1
 *   byte0[6:0] = X coordinate (signed 7-bit, -64 to +63)
 *   byte1[7]   = opcode bit 0
 *   byte1[6:0] = Y coordinate (signed 7-bit, -64 to +63)
 *   opcode: 0b00 = end of char
 *           0b10 = move to (pen up)
 *           0b11 = line to (pen down)
 *
 * Coordinates are relative to character origin. The renderer scales
 * by multiplying by the RIPscrip charsize (1-10) and draws lines
 * using draw_line() from the unified drawing engine.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License. See LICENSE.
 */

#include "bgi_font.h"
#include "drawing.h"
#include <limits.h>
#include <stddef.h>  /* size_t — not portably pulled in by the above (glibc/clang) */

/* Sign-extend a 7-bit value to int16_t */
static int16_t sign7(uint8_t v) {
    if (v & 0x40) return (int16_t)(v | 0xFF80);  /* negative */
    return (int16_t)(v & 0x3F);
}

static uint16_t read_u16le(const uint8_t *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

bool bgi_font_parse(bgi_font_t *font, const uint8_t *data, int size) {
    if (size < 50) return false;

    /* BGI CHR binary format (bgi2c.py strips the text header, keeping
     * the binary section from after \x1A\x80 in the original .CHR file).
     *
     * The binary data has a metadata prefix, then a '+' (0x2B) marker
     * followed immediately by the font definition:
     *
     *   +0:    '+' (0x2B)
     *   +1,+2: num_chars (LE word, typically 223 = 0x20-0xFE)
     *   +3:    undefined (0x00)
     *   +4:    first_char (ASCII code of first character)
     *   +5,+6: stroke_offset from '+' (LE word, offset to stroke data)
     *   +7:    scan_flag
     *   +8:    org_to_top (signed byte, distance from origin to cap height)
     *   +9:    org_to_baseline (signed byte)
     *   +10:   org_to_bottom (signed byte, descender depth)
     *
     * Then (TABLE ORDER IS CRITICAL — see docs/spec §8.4; reversing the
     * two tables re-introduces DLL bug §DEAD.2, which silently broke every
     * stroke font.  The parse code below matches the order documented here):
     *   +11 .. +15:                     reserved (5 bytes)
     *   +16 .. +16+2*nchars-1:          stroke offset table (2 bytes LE/char)
     *   +16+2*nchars .. +16+3*nchars-1: width table (1 byte per char)
     *   +stroke_offset ..:              stroke data (2 bytes per point)
     */

    /* Scan for '+' marker (0x2B) in the binary prefix.
     * Validate: num_chars in range, first_char == 0x20, stroke_offset > 0.
     * Start search past the metadata prefix (~30 bytes) to avoid false matches. */
    int p = -1;
    for (int i = 20; i < size - 16 && i < 256; i++) {
        if (data[i] == 0x2B) {
            uint16_t nc = data[i + 1] | (data[i + 2] << 8);
            uint8_t fc = data[i + 4];
            uint16_t so = data[i + 5] | (data[i + 6] << 8);
            if (nc >= 32 && nc <= 255 && fc < 0x21 && so > 0 && so < size) {
                p = i;
                break;
            }
        }
    }
    if (p < 0) return false;

    /* Parse the 16-byte font header at '+' */
    font->num_chars  = (uint16_t)(data[p + 1] | (data[p + 2] << 8));
    font->first_char = data[p + 4];

    uint16_t stroke_off = data[p + 5] | (data[p + 6] << 8);

    font->top      = (int8_t)data[p + 8];
    font->baseline = (int8_t)data[p + 9];
    font->bottom   = (int8_t)data[p + 10];
    /* +11 through +15: reserved (5 bytes) */

    /* Stroke offset table: 2 bytes LE per character, starting at '+' + 16 */
    int off_start = p + 16;
    if (off_start + font->num_chars * 2 > size) return false;
    font->offsets = &data[off_start];

    /* Width table: 1 byte per character, after stroke offset table */
    int wid_start = off_start + font->num_chars * 2;
    if (wid_start + font->num_chars > size) return false;
    font->widths = &data[wid_start];

    /* Stroke data: at '+' + stroke_data_offset */
    int strk_start = p + stroke_off;
    if (strk_start >= size) return false;
    font->strokes = &data[strk_start];

    font->data = data;
    font->data_size = size;

    return true;
}

/* Render one character, returns X advance.
 *
 * italic_shear: 0 = no italic; otherwise the per-stroke X is offset by
 * (dy / italic_shear) pixels — a positive shear factor produces glyphs
 * that lean right (top displaced toward +X).  4 is ~25% slope, which is
 * a typical italic angle. */
static int16_t render_char(const bgi_font_t *font,
                            int16_t ox, int16_t oy,
                            uint8_t ch, uint8_t scale,
                            uint8_t color, uint8_t direction,
                            int italic_shear) {
    if (ch < font->first_char) return 0;
    int idx = ch - font->first_char;
    if (idx >= font->num_chars) return 0;

    /* Get stroke data offset for this character */
    uint16_t soff = read_u16le(font->offsets + idx * 2);

    /* Bounds-check soff before forming the pointer.  font->strokes is
     * already known to live inside font->data (validated in bgi_font_parse).
     * If a malformed/adversarial font supplies an offset that points outside
     * the buffer, font->strokes + soff would form an out-of-bounds pointer —
     * undefined behaviour in C even before any dereference.  Cap it here
     * and skip the glyph if the offset is unusable.  Per audit C-007. */
    size_t stroke_byte_pos =
        (size_t)(font->strokes - font->data) + (size_t)soff;
    if (stroke_byte_pos + 1 >= (size_t)font->data_size) return 0;

    const uint8_t *sp = font->strokes + soff;
    const uint8_t *end = font->data + font->data_size;

    int16_t px = ox, py = oy;  /* pen position */
    int16_t prev_x = ox, prev_y = oy;

    draw_set_color(color);

    while (sp + 1 < end) {
        uint8_t b0 = *sp++;
        uint8_t b1 = *sp++;

        uint8_t opcode = ((b0 >> 6) & 2) | ((b1 >> 7) & 1);
        int16_t sx = sign7(b0 & 0x7F);
        int16_t sy = sign7(b1 & 0x7F);

        /* Scale coordinates */
        int16_t dx = sx * scale;
        int16_t dy = sy * scale;

        /* Italic: shear X proportional to Y so the top of the glyph
         * (positive sy in BGI stroke space) leans toward +X. */
        if (italic_shear > 0)
            dx = (int16_t)(dx + dy / italic_shear);

        if (opcode == 0) {
            /* End of character */
            break;
        } else if (opcode == 2) {
            /* Move to (pen up) */
            if (direction == 0) {
                px = ox + dx;
                py = oy - dy;  /* BGI Y is inverted */
            } else if (direction == 3) {
                /* dir=3: CW glyph rotation.  Readable tilting head right. */
                px = ox + dy;
                py = oy + dx;
            } else {
                /* dir=1 (BGI VERT_DIR) and dir=2 both use the CCW glyph
                 * rotation; they differ only in which way the string
                 * advances (see bgi_font_draw_string).  Readable tilting
                 * head left. */
                px = ox - dy;
                py = oy - dx;
            }
            prev_x = px;
            prev_y = py;
        } else if (opcode == 3) {
            /* Line to (pen down) */
            int16_t nx, ny;
            if (direction == 0) {
                nx = ox + dx;
                ny = oy - dy;
            } else if (direction == 3) {
                nx = ox + dy;
                ny = oy + dx;
            } else {
                nx = ox - dy;
                ny = oy - dx;
            }
            draw_line(prev_x, prev_y, nx, ny);
            prev_x = nx;
            prev_y = ny;
            px = nx;
            py = ny;
        }
    }

    /* Return character advance width */
    return font->widths[idx] * scale;
}

/* Inter-character spacing, as a percentage of the glyph's natural advance.
 *
 * '|y' RIP_EXTENDED_FONT_STYLE carries this field and the driver enforces it
 * non-zero.  RIPlib decoded it and then had nowhere to put it: every text
 * path used the glyph's own width, so a stream asking for condensed or
 * expanded text got neither.
 *
 * Module-scoped rather than a parameter, matching draw_set_color() and the
 * other renderer state, so no public signature changes.  100 is normal. */
static uint16_t bgi_char_spacing_pct = 100;

void bgi_font_set_char_spacing(uint16_t pct) {
    if (pct == 0) pct = 100;          /* the driver rejects zero outright */
    if (pct > 1000) pct = 1000;       /* keep the advance arithmetic sane */
    bgi_char_spacing_pct = pct;
}

/* Apply the spacing percentage to one glyph's advance.  Guarded so a
 * condensed setting can never produce a zero or negative advance, which
 * would stack every glyph on the same column. */
static int16_t bgi_space_adv(int16_t w) {
    int32_t v;
    if (bgi_char_spacing_pct == 100) return w;
    v = ((int32_t)w * bgi_char_spacing_pct) / 100;
    if (w > 0 && v < 1) v = 1;
    return (int16_t)v;
}

int16_t bgi_font_draw_string(const bgi_font_t *font,
                              int16_t x, int16_t y,
                              const char *str, int len,
                              uint8_t scale, uint8_t color,
                              uint8_t direction) {
    if (!font || !font->strokes || scale == 0) return 0;
    if (scale > 10) scale = 10;

    int16_t advance = 0;
    for (int i = 0; i < len; i++) {
        int16_t w = render_char(font, x, y, (uint8_t)str[i],
                                 scale, color, direction, 0);
        w = bgi_space_adv(w);
        if (direction == 0) {
            x += w;
        } else if (direction == 1) {
            /* dir=1 is BGI VERT_DIR, restored 2026-08-12 (X3).  The 1.54
             * specification states it explicitly: "Vertical text is drawn
             * with the base-line to the right, and is read from bottom to
             * the top."  RIPlib had redefined 1 as top-to-bottom, so
             * content authored against either side read upside-down on the
             * other.  The corrected top-to-bottom rendering did not go
             * away -- it moved to dir=3. */
            y -= w;
        } else {
            /* dir=2 (CCW) and dir=3 (CW) both advance downward. */
            y += w;
        }
        advance += w;
    }
    return advance;
}

int16_t bgi_font_draw_string_ex(const bgi_font_t *font,
                                 int16_t x, int16_t y,
                                 const char *str, int len,
                                 uint8_t scale, uint8_t color,
                                 uint8_t direction, uint8_t attrib) {
    if (!font || !font->strokes || scale == 0) return 0;
    if (scale > 10) scale = 10;
    if (attrib == 0) {
        /* No attributes — fast path */
        return bgi_font_draw_string(font, x, y, str, len,
                                     scale, color, direction);
    }

    int16_t start_x = x, start_y = y;
    int16_t advance = 0;

    /* Shadow: draw entire string offset in dark color first */
    if (attrib & BGI_ATTR_SHADOW) {
        int16_t shx = (direction == 0) ? 1 : 0;
        int16_t shy = 1;
        /* Use a dark version of the color (shift right for dimming) */
        uint8_t shadow_col = (color >> 1) & 0x6D;  /* halve RGB332 channels */
        bgi_font_draw_string(font, x + shx, y + shy, str, len,
                              scale, shadow_col, direction);
    }

    /* Bold: draw string, then draw again offset +1px right */
    if (attrib & BGI_ATTR_BOLD) {
        bgi_font_draw_string(font, x + 1, y, str, len,
                              scale, color, direction);
    }

    /* Main string draw — italic handled by per-stroke X shear inside
     * render_char (real glyph slanting, not a constant translation). */
    if (attrib & BGI_ATTR_ITALIC) {
        for (int i = 0; i < len; i++) {
            int16_t w = render_char(font, x, y,
                                     (uint8_t)str[i], scale, color, direction,
                                     /* italic shear: dx += dy/4 ≈ 25° slant */ 4);
            w = bgi_space_adv(w);
            if (direction == 0)      x += w;
            else if (direction == 1) y -= w;   /* BGI VERT_DIR: bottom-to-top */
            else                     y += w;
            advance += w;
        }
    } else {
        advance = bgi_font_draw_string(font, x, y, str, len,
                                        scale, color, direction);
        if (direction == 0)      x = start_x + advance;
        else if (direction == 1) y = start_y - advance;  /* bottom-to-top */
        else                     y = start_y + advance;
    }

    /* Underline: horizontal line at baseline */
    if (attrib & BGI_ATTR_UNDERLINE) {
        int16_t ul_y = start_y + 2;  /* 2px below baseline */
        draw_set_color(color);
        if (direction == 0) {
            draw_line(start_x, ul_y, start_x + advance, ul_y);
        } else if (direction == 1) {
            /* dir=1 runs BOTTOM-TO-TOP, so the bar extends upward from the
             * origin.  Using start_y + advance here (as every vertical
             * direction did before the 2026-08-12 X3 change) would draw the
             * underline on the opposite side of the string from the glyphs. */
            draw_line(start_x - 2, start_y, start_x - 2, start_y - advance);
        } else {
            /* dir=2 / dir=3 run top-to-bottom. */
            draw_line(start_x - 2, start_y, start_x - 2, start_y + advance);
        }
    }

    return advance;
}

int16_t bgi_font_string_width(const bgi_font_t *font,
                               const char *str, int len,
                               uint8_t scale) {
    if (!font || !font->widths || scale == 0) return 0;

    int total = 0;
    for (int i = 0; i < len; i++) {
        uint8_t ch = (uint8_t)str[i];
        if (ch < font->first_char) continue;
        int idx = ch - font->first_char;
        if (idx >= font->num_chars) continue;
        total += font->widths[idx] * scale;
    }
    if (total > INT16_MAX)
        return INT16_MAX;
    return (int16_t)total;
}
