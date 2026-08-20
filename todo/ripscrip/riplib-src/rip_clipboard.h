/*
 * rip_clipboard.h — RIPlib clipboard + raster blit operations.
 *
 * Despite the name, this module owns more than just the RIPscrip
 * GET_IMAGE / PUT_IMAGE clipboard.  It groups the related raster ops
 * that share write-mode, scaling, and tiling logic:
 *
 *   - The clipboard itself (capture/store/cache-as-icon/save-to-slot)
 *   - Pixel blit (point, scaled, tiled)
 *   - Icon-style-aware draw (honours stretch / tile / center /
 *     proportional fit per the active 1S / & state)
 *   - Screen-to-screen copy with optional scaling
 *
 * Extracted from src/ripscrip.c as step 6 of audit candidate C-002
 * (decompose ripscrip.c monolith).  Functions take rip_state_t* and
 * operate on existing fields so the rip_state_t layout stays unchanged.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>
#include "ripscrip.h"
#include "rip_icons.h"

/* ── Clipboard ──────────────────────────────────────────────────── */

/* Allocate the clipboard backing buffer if not already done.  Returns
 * true if the buffer is ready to use (newly allocated OR already
 * present), false on arena exhaustion. */
bool rip_clipboard_alloc(rip_state_t *s);

/* Copy `width`x`height` pixels into the clipboard (treating clipboard
 * as a generic 8bpp source).  Allocates the clipboard if needed. */
bool rip_clipboard_store_pixels(rip_state_t *s,
                                const uint8_t *pixels,
                                uint16_t width,
                                uint16_t height);

/* Capture a rectangle of the framebuffer into the clipboard. */
bool rip_clipboard_capture(rip_state_t *s,
                           int16_t x, int16_t y,
                           int16_t width, int16_t height);

/* Save the current clipboard contents as a named icon in the runtime
 * cache.  If `out_icon` is non-NULL, also fills it with the cached
 * descriptor. */
bool rip_cache_clipboard_as_icon(rip_state_t *s,
                                 const char *name, int name_len,
                                 rip_icon_t *out_icon);

/* Save the current clipboard contents into a numbered icon slot
 * (RIPscrip v2 SAVE_ICON). */
bool rip_save_clipboard_slot(rip_state_t *s, uint16_t slot);

/* ── Blit primitives ────────────────────────────────────────────── */

/* Draw an 8bpp source rectangle into the framebuffer with the given
 * write mode.  Scales (src_w x src_h) to (dst_w x dst_h) via nearest-
 * neighbour when the dimensions differ. */
void rip_blit_pixels(rip_state_t *s,
                     int16_t dx, int16_t dy,
                     const uint8_t *pixels,
                     uint16_t src_w, uint16_t src_h,
                     int16_t dst_w, int16_t dst_h,
                     uint8_t write_mode);

/* Tile a small source rectangle across the [x0,y0..x1,y1] region. */
void rip_blit_pixels_tiled(rip_state_t *s,
                           int16_t x0, int16_t y0,
                           int16_t x1, int16_t y1,
                           const uint8_t *pixels,
                           uint16_t src_w, uint16_t src_h,
                           uint8_t write_mode);

/* Draw an icon honouring the active 1S / & ICON_STYLE mode (0=stretch,
 * 1=tile, 2=center, 3=proportional fit). */
void rip_draw_icon_pixels(rip_state_t *s,
                          int16_t x, int16_t y,
                          const uint8_t *pixels,
                          uint16_t src_w, uint16_t src_h,
                          int16_t requested_w, int16_t requested_h,
                          uint8_t write_mode);

/* Copy a screen rectangle to another location with optional scaling
 * and write-mode application.  Used by L0_COPY_REGION + L1_COPY_REGION. */
void rip_copy_screen_region_scaled(rip_state_t *s,
                                   int16_t sx, int16_t sy,
                                   int16_t sw, int16_t sh,
                                   int16_t dx, int16_t dy,
                                   int16_t dw, int16_t dh,
                                   uint8_t write_mode);
