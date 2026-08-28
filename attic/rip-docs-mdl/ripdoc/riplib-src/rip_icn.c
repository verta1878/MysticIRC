/*
 * rip_icn.c — BGI putimage (.ICN) format parser for RIPlib
 *
 * ICN file layout (BGI getimage/putimage format):
 *   Bytes 0-1: (width - 1)  as uint16_t LE
 *   Bytes 2-3: (height - 1) as uint16_t LE
 *   Bytes 4-5: unused (reserved/row_bytes, ignored)
 *   Bytes 6+:  pixel data, 4 EGA bitplanes interleaved per row
 *
 * Each row stores 4 planes sequentially:
 *   plane 0 (blue):  ceil(width/8) bytes
 *   plane 1 (green): ceil(width/8) bytes
 *   plane 2 (red):   ceil(width/8) bytes
 *   plane 3 (intensity): ceil(width/8) bytes
 *
 * Each pixel's EGA index = (intensity<<3)|(red<<2)|(green<<1)|blue
 * mapped to palette indices 0-15.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License. See LICENSE.
 */

#include "rip_icn.h"
#include <stddef.h>  /* size_t */

bool rip_icn_measure(const uint8_t *data, int size,
                     uint16_t *out_w, uint16_t *out_h) {
    if (!data || !out_w || !out_h || size < 6) return false;

    uint32_t w_raw = (uint32_t)data[0] | ((uint32_t)data[1] << 8);
    uint32_t h_raw = (uint32_t)data[2] | ((uint32_t)data[3] << 8);
    uint16_t w = (uint16_t)(w_raw + 1u);
    uint16_t h = (uint16_t)(h_raw + 1u);
    /* bytes 4-5 ignored */

    if (w == 0 || h == 0 || w > 640 || h > 400) return false;

    size_t row_bytes = ((size_t)w + 7u) / 8u;
    size_t row_stride = row_bytes * 4u; /* 4 planes per row */
    size_t expected = 6u + row_stride * (size_t)h;
    if ((size_t)size < expected) return false;

    *out_w = w;
    *out_h = h;
    return true;
}

bool rip_icn_parse(const uint8_t *data, int size,
                   uint8_t *out_pixels,
                   uint16_t *out_w, uint16_t *out_h) {
    uint16_t w;
    uint16_t h;
    if (!out_pixels || !rip_icn_measure(data, size, &w, &h))
        return false;

    *out_w = w;
    *out_h = h;

    const uint8_t *src = data + 6;

    for (int y = 0; y < h; y++) {
        size_t row_bytes = ((size_t)w + 7u) / 8u;
        size_t row_stride = row_bytes * 4u;
        const uint8_t *row = src + (size_t)y * row_stride;
        const uint8_t *p0 = row;                        /* blue */
        const uint8_t *p1 = row + row_bytes;            /* green */
        const uint8_t *p2 = row + row_bytes * 2u;       /* red */
        const uint8_t *p3 = row + row_bytes * 3u;       /* intensity */
        uint8_t *dst = out_pixels + (size_t)y * (size_t)w;

        for (int x = 0; x < w; x++) {
            int byte_idx = x >> 3;
            int bit_mask = 0x80 >> (x & 7);
            uint8_t b = (p0[byte_idx] & bit_mask) ? 1 : 0;
            uint8_t g = (p1[byte_idx] & bit_mask) ? 1 : 0;
            uint8_t r = (p2[byte_idx] & bit_mask) ? 1 : 0;
            uint8_t i = (p3[byte_idx] & bit_mask) ? 1 : 0;
            dst[x] = (i << 3) | (r << 2) | (g << 1) | b;
        }
    }

    return true;
}
