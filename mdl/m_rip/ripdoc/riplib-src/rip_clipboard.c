/*
 * rip_clipboard.c — RIPlib clipboard + raster blit operations.
 *
 * Implements the API declared in rip_clipboard.h.  See that header
 * for module scope and extraction rationale (audit C-002 step 6).
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#include "rip_clipboard.h"
#include "rip_internal.h"
#include "drawing.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

bool rip_clipboard_alloc(rip_state_t *s) {
    if (!s)
        return false;
    if (!s->clipboard.data) {
        s->clipboard.data = (uint8_t *)psram_arena_alloc(&s->psram_arena,
                                                         RIP_CLIPBOARD_MAX);
    }
    return s->clipboard.data != NULL;
}

bool rip_clipboard_store_pixels(rip_state_t *s,
                                       const uint8_t *pixels,
                                       uint16_t width,
                                       uint16_t height) {
    size_t bytes;

    if (!s || !pixels || width == 0 || height == 0)
        return false;

    bytes = (size_t)width * (size_t)height;
    if (bytes == 0 || bytes > RIP_CLIPBOARD_MAX)
        return false;
    if (!rip_clipboard_alloc(s))
        return false;

    memmove(s->clipboard.data, pixels, bytes);
    s->clipboard.width = (int16_t)width;
    s->clipboard.height = (int16_t)height;
    s->clipboard.valid = true;
    return true;
}

bool rip_clipboard_capture(rip_state_t *s,
                                  int16_t x, int16_t y,
                                  int16_t width, int16_t height) {
    size_t bytes;

    if (!s || width <= 0 || height <= 0)
        return false;

    bytes = (size_t)(uint16_t)width * (size_t)(uint16_t)height;
    if (bytes == 0 || bytes > RIP_CLIPBOARD_MAX)
        return false;
    if (!rip_clipboard_alloc(s))
        return false;

    draw_save_region(x, y, width, height, s->clipboard.data);
    s->clipboard.width = width;
    s->clipboard.height = height;
    s->clipboard.valid = true;
    return true;
}

bool rip_cache_clipboard_as_icon(rip_state_t *s,
                                        const char *name,
                                        int name_len,
                                        rip_icon_t *out_icon) {
    size_t bytes;
    uint8_t *pixels;

    if (!s || !s->clipboard.valid || !s->clipboard.data ||
        !rip_filename_is_safe(name, name_len))
        return false;

    bytes = (size_t)(uint16_t)s->clipboard.width *
            (size_t)(uint16_t)s->clipboard.height;
    if (bytes == 0 || bytes > RIP_CLIPBOARD_MAX)
        return false;

    pixels = (uint8_t *)psram_arena_alloc(&s->psram_arena, (uint32_t)bytes);
    if (!pixels)
        return false;

    memcpy(pixels, s->clipboard.data, bytes);
    if (!rip_icon_cache_pixels_replace(&s->icon_state, name, name_len, pixels,
                                       (uint16_t)s->clipboard.width,
                                       (uint16_t)s->clipboard.height))
        return false;

    if (out_icon) {
        out_icon->pixels = pixels;
        out_icon->width = (uint16_t)s->clipboard.width;
        out_icon->height = (uint16_t)s->clipboard.height;
    }
    return true;
}

bool rip_save_clipboard_slot(rip_state_t *s, uint16_t slot) {
    size_t bytes;
    uint8_t *pixels;
    char slot_name[RIP_ICON_NAME_MAX + 1];

    if (!s || slot >= RIP_ICON_SLOT_MAX ||
        !s->clipboard.valid || !s->clipboard.data)
        return false;

    bytes = (size_t)(uint16_t)s->clipboard.width *
            (size_t)(uint16_t)s->clipboard.height;
    if (bytes == 0 || bytes > RIP_CLIPBOARD_MAX)
        return false;

    pixels = (uint8_t *)psram_arena_alloc(&s->psram_arena, (uint32_t)bytes);
    if (!pixels)
        return false;
    memcpy(pixels, s->clipboard.data, bytes);

    s->icon_slots[slot].pixels = pixels;
    s->icon_slots[slot].width = (uint16_t)s->clipboard.width;
    s->icon_slots[slot].height = (uint16_t)s->clipboard.height;
    s->icon_slot_valid[slot] = true;

    snprintf(slot_name, sizeof(slot_name), "SLOT%02u", (unsigned)slot);
    (void)rip_icon_cache_pixels_replace(&s->icon_state, slot_name,
                                        (int)strlen(slot_name),
                                        pixels,
                                        (uint16_t)s->clipboard.width,
                                        (uint16_t)s->clipboard.height);
    return true;
}

void rip_blit_pixels(rip_state_t *s,
                            int16_t dx, int16_t dy,
                            const uint8_t *pixels,
                            uint16_t src_w, uint16_t src_h,
                            int16_t dst_w, int16_t dst_h,
                            uint8_t write_mode) {
    uint8_t old_color;

    if (!pixels || src_w == 0 || src_h == 0 || dst_w <= 0 || dst_h <= 0)
        return;
    if (write_mode > DRAW_MODE_NOT)
        write_mode = DRAW_MODE_COPY;

    old_color = draw_get_color();
    draw_set_write_mode(write_mode);

    if (dst_w == (int16_t)src_w && dst_h == (int16_t)src_h) {
        draw_restore_region(dx, dy, dst_w, dst_h, pixels);
    } else {
        for (int16_t yy = 0; yy < dst_h; yy++) {
            uint16_t sy = (uint16_t)(((uint32_t)(uint16_t)yy * src_h) /
                                     (uint16_t)dst_h);
            for (int16_t xx = 0; xx < dst_w; xx++) {
                uint16_t sx = (uint16_t)(((uint32_t)(uint16_t)xx * src_w) /
                                         (uint16_t)dst_w);
                draw_set_color(pixels[(size_t)sy * src_w + sx]);
                draw_pixel((int16_t)(dx + xx), (int16_t)(dy + yy));
            }
        }
    }

    draw_set_write_mode(s ? s->write_mode : DRAW_MODE_COPY);
    draw_set_color(old_color);
}

void rip_blit_pixels_tiled(rip_state_t *s,
                                  int16_t x0, int16_t y0,
                                  int16_t x1, int16_t y1,
                                  const uint8_t *pixels,
                                  uint16_t src_w, uint16_t src_h,
                                  uint8_t write_mode) {
    draw_clip_state_t saved_clip;

    if (!pixels || src_w == 0 || src_h == 0 || x1 < x0 || y1 < y0)
        return;

    draw_save_clip(&saved_clip);
    draw_set_clip(x0, y0, x1, y1);
    for (int16_t y = y0; y <= y1; y = (int16_t)(y + src_h)) {
        for (int16_t x = x0; x <= x1; x = (int16_t)(x + src_w)) {
            rip_blit_pixels(s, x, y, pixels, src_w, src_h,
                            (int16_t)src_w, (int16_t)src_h, write_mode);
            if (src_w == 0)
                break;
        }
        if (src_h == 0)
            break;
    }
    draw_restore_clip(&saved_clip);
}

void rip_draw_icon_pixels(rip_state_t *s,
                                 int16_t x, int16_t y,
                                 const uint8_t *pixels,
                                 uint16_t src_w, uint16_t src_h,
                                 int16_t requested_w,
                                 int16_t requested_h,
                                 uint8_t write_mode) {
    bool has_box;
    int16_t bx0;
    int16_t by0;
    int16_t bx1;
    int16_t by1;
    int16_t dst_w;
    int16_t dst_h;
    uint8_t mode;

    if (!s || !pixels || src_w == 0 || src_h == 0)
        return;

    has_box = (requested_w > 0 && requested_h > 0);
    if (has_box) {
        bx0 = x;
        by0 = y;
        bx1 = (int16_t)(x + requested_w - 1);
        by1 = (int16_t)(y + requested_h - 1);
    } else if (s->icon_style_active) {
        bx0 = s->icon_style_x0;
        by0 = s->icon_style_y0;
        bx1 = s->icon_style_x1;
        by1 = s->icon_style_y1;
    } else {
        rip_blit_pixels(s, x, y, pixels, src_w, src_h,
                        (int16_t)src_w, (int16_t)src_h, write_mode);
        return;
    }

    if (bx0 > bx1) { int16_t t = bx0; bx0 = bx1; bx1 = t; }
    if (by0 > by1) { int16_t t = by0; by0 = by1; by1 = t; }
    dst_w = (int16_t)(bx1 - bx0 + 1);
    dst_h = (int16_t)(by1 - by0 + 1);
    if (dst_w <= 0 || dst_h <= 0)
        return;

    mode = s->icon_style_active ? (uint8_t)(s->icon_style_style & 0x03u)
                                : (uint8_t)(s->image_style & 0x03u);

    if (mode == 1) {
        rip_blit_pixels_tiled(s, bx0, by0, bx1, by1, pixels, src_w, src_h,
                              write_mode);
        return;
    }

    if (mode == 2) {
        dst_w = (int16_t)src_w;
        dst_h = (int16_t)src_h;
        if ((s->icon_style_align & 0x03u) == 2u) {
            bx0 = (int16_t)(bx1 - dst_w + 1);
            by0 = (int16_t)(by1 - dst_h + 1);
        } else {
            bx0 = (int16_t)(bx0 + ((bx1 - bx0 + 1) - dst_w) / 2);
            by0 = (int16_t)(by0 + ((by1 - by0 + 1) - dst_h) / 2);
        }
    } else if (mode == 3) {
        int32_t w_fit = (int32_t)(bx1 - bx0 + 1);
        int32_t h_fit = ((int32_t)w_fit * src_h) / src_w;
        if (h_fit > (int32_t)(by1 - by0 + 1)) {
            h_fit = (int32_t)(by1 - by0 + 1);
            w_fit = ((int32_t)h_fit * src_w) / src_h;
        }
        if (w_fit <= 0) w_fit = 1;
        if (h_fit <= 0) h_fit = 1;
        dst_w = (int16_t)w_fit;
        dst_h = (int16_t)h_fit;
        bx0 = (int16_t)(bx0 + ((bx1 - bx0 + 1) - dst_w) / 2);
        by0 = (int16_t)(by0 + ((by1 - by0 + 1) - dst_h) / 2);
    }

    rip_blit_pixels(s, bx0, by0, pixels, src_w, src_h, dst_w, dst_h,
                    write_mode);
}

void rip_copy_screen_region_scaled(rip_state_t *s,
                                          int16_t sx, int16_t sy,
                                          int16_t sw, int16_t sh,
                                          int16_t dx, int16_t dy,
                                          int16_t dw, int16_t dh,
                                          uint8_t write_mode) {
    size_t bytes;
    uint8_t *scratch;

    if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0)
        return;
    if (write_mode > DRAW_MODE_NOT)
        write_mode = DRAW_MODE_COPY;

    if (sw == dw && sh == dh && write_mode == DRAW_MODE_COPY) {
        draw_copy_rect(sx, sy, dx, dy, sw, sh);
        return;
    }

    bytes = (size_t)(uint16_t)sw * (size_t)(uint16_t)sh;
    if (bytes == 0)
        return;
    if (bytes > RIP_CLIPBOARD_MAX)   /* cap oversized transient, matching the clipboard paths (C-014) */
        return;

    scratch = (uint8_t *)malloc(bytes);
    if (!scratch)
        return;
    draw_save_region(sx, sy, sw, sh, scratch);
    rip_blit_pixels(s, dx, dy, scratch, (uint16_t)sw, (uint16_t)sh,
                    dw, dh, write_mode);
    free(scratch);
}
