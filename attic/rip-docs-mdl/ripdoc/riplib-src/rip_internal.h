/*
 * rip_internal.h — Internal cross-module utilities for RIPlib.
 *
 * Not under include/ because it is NOT public API: it is the seam
 * between src/ripscrip.c and the subsystems being peeled off it as
 * part of audit candidate C-002 (decompose ripscrip.c monolith).
 *
 * Keep this header narrow.  Two kinds of content belong here:
 *   1. Small `static inline` helpers used in more than one .c file
 *      under src/ (e.g. rip_strnlen).
 *   2. Forward declarations for functions that live in one .c file
 *      and are called from another (e.g. rip_reset_windows_state,
 *      which lives in ripscrip.c and is called from rip_variables.c
 *      to implement the $RESET$ text variable).
 *
 * Anything that's a full subsystem boundary should be its own header
 * (rip_preproc.h, rip_variables.h, …), not piled in here.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#pragma once

#include <stddef.h>
#include "ripscrip.h"

/* Bounded strlen — like POSIX strnlen but defined here so the library
 * doesn't depend on _POSIX_C_SOURCE or platform-specific availability.
 * Returns 0 on NULL input (defensive, used inside expansion paths that
 * may legitimately see uninitialised optional fields). */
static inline size_t rip_strnlen(const char *s, size_t max_len) {
    size_t n = 0;
    if (!s) return 0;
    while (n < max_len && s[n] != '\0') n++;
    return n;
}

/* Reject filenames containing path separators, control characters, or
 * the ".." parent-directory marker.  Conservative gate used by every
 * codepath that turns a wire-supplied filename into an icon-cache key,
 * file-upload destination, or LOAD_ICON dispatch target. */
#include <stdbool.h>
static inline bool rip_filename_is_safe(const char *name, int len) {
    if (!name || len <= 0)
        return false;
    for (int i = 0; i < len; i++) {
        unsigned char c = (unsigned char)name[i];
        if (c < 0x20u || c == 0x7Fu) return false;
        if (c == '/' || c == '\\' || c == ':') return false;
        if (c == '.' && i + 1 < len && name[i + 1] == '.') return false;
    }
    return true;
}

/* Like rip_filename_is_safe but for a *directory* path: permits '/'
 * separators (a path may name subdirectories) while still rejecting the
 * ".." parent-directory marker, control characters, NUL, backslash, and
 * the drive-letter / ADS colon.  Used to sanitise the wire-supplied
 * RIP_SET_ICON_DIR ('1N') path before it is stored.  Conservative gate —
 * a consumer that actually opens the path must still treat it as
 * untrusted (see the icon_dir field comment in ripscrip.h). */
static inline bool rip_dirpath_is_safe(const char *path, int len) {
    if (!path || len <= 0)
        return false;
    for (int i = 0; i < len; i++) {
        unsigned char c = (unsigned char)path[i];
        if (c < 0x20u || c == 0x7Fu) return false;
        if (c == '\\' || c == ':') return false;
        if (c == '.' && i + 1 < len && path[i + 1] == '.') return false;
    }
    return true;
}

/* Defined in ripscrip.c; called from rip_variables.c to implement the
 * $RESET$ text variable.  Non-static so the variable module can reach
 * it without pulling the whole FSM along. */
void rip_reset_windows_state(rip_state_t *s, comp_context_t *c);
