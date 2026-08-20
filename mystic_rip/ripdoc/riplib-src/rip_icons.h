/*
 * rip_icons.h — RIPscrip icon loader for RIPlib
 *
 * Two-tier icon lookup:
 *   1. Statically-embedded icons (rip_icons_data.c, built from the
 *      RIPtel BMP set; live in flash on embedded targets)
 *   2. Runtime cache (populated via the BMP parser from file transfer
 *      data; backed by the psram_arena which is malloc()-backed on
 *      desktop targets and PSRAM-backed on embedded)
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "riplib_platform.h"

#define RIP_ICON_CACHE_MAX   64
#define RIP_ICON_NAME_MAX    12
#define RIP_FILE_REQUEST_MAX 16
#define RIP_FILE_NAME_MAX    12

/* Icon descriptor returned by lookup */
typedef struct {
    const uint8_t *pixels;   /* 8bpp top-down pixel data */
    uint16_t       width;
    uint16_t       height;
} rip_icon_t;

typedef struct {
    char     name[RIP_ICON_NAME_MAX + 1];
    uint8_t *pixels;
    uint16_t width;
    uint16_t height;
} rip_icon_cache_entry_t;

typedef struct {
    psram_arena_t *arena;
    rip_icon_cache_entry_t cache[RIP_ICON_CACHE_MAX];
    int cache_count;
    char request_queue[RIP_FILE_REQUEST_MAX][RIP_FILE_NAME_MAX + 1];
    int  request_lengths[RIP_FILE_REQUEST_MAX];
    int  request_head;
    int  request_tail;
    int  request_count;
} rip_icon_state_t;

/* Bind the PSRAM arena used for runtime icon pixel allocations.
 * Must be called before rip_icon_cache_bmp() or rip_icon_cache_pixels()
 * will succeed. Also resets the runtime cache (flash icons are unaffected). */
void rip_icon_set_arena(rip_icon_state_t *state, psram_arena_t *arena);

/* Look up an icon by filename (uppercase, no extension).
 * Checks PSRAM runtime cache first, then flash-embedded tables.
 * Returns true + fills out icon descriptor, or false if not found. */
bool rip_icon_lookup(const rip_icon_state_t *state,
                     const char *name, int name_len, rip_icon_t *out);

/* Parse a BMP from memory and cache in PSRAM.
 * Supports 4bpp and 8bpp uncompressed BMPs.
 * name is the filename key for cache lookup.
 * Returns true on success. */
bool rip_icon_cache_bmp(rip_icon_state_t *state,
                        const char *name, int name_len,
                        const uint8_t *bmp_data, int bmp_size);

/* Parse a BMP and cache/replace the runtime entry.  Used for file uploads,
 * where a newer transfer of the same icon name should win. */
bool rip_icon_cache_bmp_replace(rip_icon_state_t *state,
                                const char *name, int name_len,
                                const uint8_t *bmp_data, int bmp_size);

/* Cache pre-parsed pixel data directly (from ICN parser or other sources).
 * pixels must be PSRAM-allocated (not freed by cache). */
bool rip_icon_cache_pixels(rip_icon_state_t *state,
                           const char *name, int name_len,
                           uint8_t *pixels, uint16_t w, uint16_t h);

/* Cache or replace pre-parsed pixel data.  Used by write-style protocol
 * commands where a later save to the same name must supersede earlier data. */
bool rip_icon_cache_pixels_replace(rip_icon_state_t *state,
                                   const char *name, int name_len,
                                   uint8_t *pixels, uint16_t w, uint16_t h);

bool rip_icon_cache_has_runtime(const rip_icon_state_t *state,
                                const char *name, int name_len);

/* Runtime cache stats */
int rip_icon_cache_count(const rip_icon_state_t *state);

/* ── File request queue (for icons not in flash or cache) ────────── *
 * When LOAD_ICON can't find an icon, it queues the filename here.
 * The host-side terminal app polls this queue and initiates file
 * transfer from the BBS. Once received, the host calls
 * rip_icon_cache_bmp() to populate the PSRAM cache, then re-issues
 * the LOAD_ICON command.
 *
 * This is a stub interface — the host polling and file transfer
 * protocol are implemented by the host application (out of scope). */

/* Queue a file request. Returns true if queued, false if full. */
bool rip_icon_request_file(rip_icon_state_t *state,
                           const char *name, int name_len);

/* Check if there are pending file requests. */
int rip_icon_pending_requests(const rip_icon_state_t *state);

/* Read and dequeue one pending request. Returns name length, 0 if empty. */
int rip_icon_dequeue_request(rip_icon_state_t *state,
                             char *name_out, int max_len);

/* Clear the entire pending request queue.
 * Called from rip_session_reset() on BBS disconnect so that icon
 * requests from a previous session are not replayed to the next BBS. */
void rip_icon_clear_requests(rip_icon_state_t *state);
