/*
 * drawing.h — Unified rendering primitives for RIPlib
 *
 * ALL framebuffer pixel operations go through this module.  This is the
 * single source of truth for: pixel writes, lines, rectangles, circles,
 * ellipses, arcs, flood fill, Bezier curves, text overlay, region
 * copy/save/restore, and clipping.
 *
 * The rendering pipeline hierarchy (per consumer):
 *   Protocol parsers (ripscrip*.c) → draw_*() → framebuffer
 *   Host-specific renderers        → framebuffer (direct, when their
 *                                    pixel formats don't map to draw_*)
 *
 * Consumers with specialized pixel formats (NTSC artifacts, scanline
 * control bytes, character-ROM tile renderers) may write the framebuffer
 * directly; everything that's a generic 2-D vector or raster operation
 * should go through draw_*() so write modes, fill patterns, and clipping
 * stay consistent.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>

/* ── Dirty-row callback ──────────────────────────────────────────── *
 * Optional hook: called by every draw_* function that modifies pixels,
 * with the Y range [y_min, y_max] of affected rows (inclusive).
 * Set to NULL (default) to disable tracking — drawing.c is still
 * usable standalone without a compositor. */
typedef void (*draw_dirty_callback_t)(int16_t y_min, int16_t y_max);
void draw_set_dirty_callback(draw_dirty_callback_t cb);

/* Mark the entire framebuffer dirty without writing pixels.
 * Used by the $REFRESH$ text variable (ripInvalidateAll equivalent). */
void draw_mark_all_dirty(void);

/* ── Initialization ──────────────────────────────────────────────── *
 * Contract: pitch >= width, and pitch * height must not exceed INT_MAX —
 * the renderer indexes the framebuffer with int arithmetic on the hot
 * paths, so a larger surface would overflow.  The shipped 640×400 target
 * is far within this bound; protocol coordinates are capped at ~1480. */
void draw_init(uint8_t *framebuf, uint16_t pitch, uint16_t width, uint16_t height);

/* ── Clip save/restore ───────────────────────────────────────────── *
 * Used by the compositor to bracket VT100 scroll/clear operations so
 * that a RIPscrip viewport clip does not restrict full-screen scrolls. */
typedef struct {
    int16_t x0, y0, x1, y1;
} draw_clip_state_t;

void draw_save_clip(draw_clip_state_t *state);
void draw_restore_clip(const draw_clip_state_t *state);

/* ── State ───────────────────────────────────────────────────────── */
void    draw_set_color(uint8_t color);
uint8_t draw_get_color(void);
void    draw_set_pos(int16_t x, int16_t y);
int16_t draw_get_pos_x(void);
int16_t draw_get_pos_y(void);
void    draw_set_clip(int16_t x0, int16_t y0, int16_t x1, int16_t y1);
void    draw_reset_clip(void);
uint8_t *draw_get_fb(void);
int16_t draw_get_clip_x0(void);
int16_t draw_get_clip_y0(void);
int16_t draw_get_clip_x1(void);
int16_t draw_get_clip_y1(void);
void    draw_set_line_style(uint16_t pattern, uint8_t thickness);
void    draw_set_fill_style(uint8_t pattern_id, uint8_t fill_color);
void    draw_set_user_fill_pattern(const uint8_t *pattern);
void    draw_set_arc_radius(int16_t radius);
void    draw_set_write_mode(uint8_t mode);

/* Write modes for draw_set_write_mode()
 * Values are the RIPscrip wire values (0=COPY, 1=XOR, 2=OR, 3=AND, 4=NOT)
 * so ripscrip.c can pass protocol values directly.
 *
 * Corrected 2026-08-12.  These previously read OR=1, AND=2, XOR=3 on the
 * strength of docs/spec/11-dll-deviations.md §BUG.7, which asserted a
 * wire ordering with no citation.  Disassembly of RIPSCRIP.DLL 3.0.7
 * disproves it: the '|W' handler (RVA 0x02102C) stores the wire byte
 * unmodified, and the apply path feeds it to a translation at RVA
 * 0x00E6B3 that calls GDI SetROP2 with
 *     0 -> R2_COPYPEN  1 -> R2_XORPEN  2 -> R2_MERGEPEN
 *     3 -> R2_MASKPEN  4 -> R2_NOT
 * so XOR is 1 on the wire.  This also matches the 1.54 specification,
 * the 2.00a4 table, Borland BGI, and §DEAD.3.  §BUG.7 is withdrawn;
 * see docs/spec/12-dll-provenance.md §12.10 for the full chain. */
#define DRAW_MODE_COPY  0
#define DRAW_MODE_XOR   1
#define DRAW_MODE_OR    2
#define DRAW_MODE_AND   3
#define DRAW_MODE_NOT   4

/* ── Pixel + axis-aligned primitives ─────────────────────────────── */
void draw_pixel(int16_t x, int16_t y);
void draw_hline(int16_t x, int16_t y, int16_t len);
void draw_vline(int16_t x, int16_t y, int16_t len);
void draw_fill_screen(uint8_t color);

/* Pixel write with auto-advance cursor (for streaming pixel data).
 * Writes one pixel at current position, advances X, wraps at edges. */
void draw_write_pixel(uint8_t color);

/* ── Shapes ──────────────────────────────────────────────────────── */
void draw_line(int16_t x0, int16_t y0, int16_t x1, int16_t y1);
void draw_rect(int16_t x, int16_t y, int16_t w, int16_t h, bool fill);
void draw_rounded_rect(int16_t x, int16_t y, int16_t w, int16_t h,
                        int16_t r, bool fill);
void draw_circle(int16_t cx, int16_t cy, int16_t r, bool fill);
void draw_ellipse(int16_t cx, int16_t cy, int16_t rx, int16_t ry, bool fill);
void draw_arc(int16_t cx, int16_t cy, int16_t r, int16_t start_deg, int16_t end_deg);
void draw_flood_fill(int16_t x, int16_t y, uint8_t border_color);
void draw_bezier(int16_t x0, int16_t y0, int16_t x1, int16_t y1,
                 int16_t x2, int16_t y2, int16_t x3, int16_t y3);
/* Same, but with the segment count fixed by the caller rather than
 * estimated.  RIPscrip's bezier commands carry an `nsteps` field; this is
 * how it is honoured.  Clamped to 2..64. */
void draw_bezier_steps(int16_t x0, int16_t y0, int16_t x1, int16_t y1,
                       int16_t x2, int16_t y2, int16_t x3, int16_t y3,
                       int steps);
void draw_polyline(const int16_t *points, int n);
void draw_polygon(const int16_t *points, int n, bool fill);
void draw_pie(int16_t cx, int16_t cy, int16_t r,
              int16_t start_deg, int16_t end_deg, bool fill);
void draw_elliptical_arc(int16_t cx, int16_t cy, int16_t rx, int16_t ry,
                          int16_t start_deg, int16_t end_deg);
void draw_elliptical_pie(int16_t cx, int16_t cy, int16_t rx, int16_t ry,
                          int16_t start_deg, int16_t end_deg, bool fill);
void draw_thick_line(int16_t x0, int16_t y0, int16_t x1, int16_t y1);

/* ── Raster / region operations ──────────────────────────────────── *
 * Buffer contract: `dest` / `src` point to exactly w*h bytes with row
 * stride = w.  The screen rect [x,y,w,h] is clipped to the framebuffer,
 * but the caller buffer is always indexed at the full, unclipped w*h —
 * size it to w*h, not to the clipped extent. */
void    draw_copy_rect(int16_t sx, int16_t sy, int16_t dx, int16_t dy,
                       int16_t w, int16_t h);
void    draw_save_region(int16_t x, int16_t y, int16_t w, int16_t h,
                         uint8_t *dest);
void    draw_restore_region(int16_t x, int16_t y, int16_t w, int16_t h,
                            const uint8_t *src);
uint8_t draw_get_pixel(int16_t x, int16_t y);

/* ── Text overlay ────────────────────────────────────────────────── *
 * Render a string at pixel coordinates using a bitmap font.
 * font: pointer to glyph bitmap data (8 bytes/glyph for 8-high,
 *        16 bytes/glyph for 16-high). NULL = use character_rom.
 *        CONTRACT: the buffer must hold at least 256 * font_height
 *        bytes (one full 256-glyph table) — glyphs are indexed as
 *        font[(uint8_t)ch * font_height + row], so any byte 0x00-0xFF
 *        in `str` may be looked up.
 * font_height: glyph height in pixels. RIPlib ships 8 and 16; a caller
 *        passing another height must size `font` to 256 * font_height.
 * fg, bg: palette indices. bg=0xFF means transparent background. */
void draw_text(int16_t x, int16_t y, const char *str, int len,
               const uint8_t *font, uint8_t font_height,
               uint8_t fg, uint8_t bg);
