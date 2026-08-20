/*
 * rip_icn.h — BGI putimage (.ICN) format parser for RIPlib
 *
 * RIPscrip's native icon format: 6-byte header + 4 EGA bitplanes
 * interleaved by row.  Converts to 8bpp palette indices (0-15).
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>

/* Parse an ICN (BGI putimage) file from memory.
 * Deinterleaves 4 EGA bitplanes to 8bpp palette indices (0-15).
 * out_pixels must have space for width * height bytes.
 * Returns true on success. */
bool rip_icn_measure(const uint8_t *data, int size,
                     uint16_t *out_w, uint16_t *out_h);

bool rip_icn_parse(const uint8_t *data, int size,
                   uint8_t *out_pixels,
                   uint16_t *out_w, uint16_t *out_h);
