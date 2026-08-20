/*
 * rip_preproc.c — RIPlib preprocessor suppression state machine
 *
 * Implementation of the rip_preproc_*() entry points declared in
 * rip_preproc.h.  Extracted from src/ripscrip.c as the first step
 * of audit candidate C-002 (decompose ripscrip.c monolith).  The
 * functions still take a `rip_state_t *` and operate on the existing
 * preproc_* fields so the rip_state_t layout and the existing
 * regression tests do not change.
 *
 * The byte-level <<…>> recognition FSM remains in ripscrip.c
 * (it's wired into the main parser entry point and shares state with
 * other parser concerns).  Once C-003 opacifies rip_state_t the
 * preproc fields will be moved into a dedicated rip_preproc_state_t
 * sub-struct and this file's API can shed the rip_state_t parameter.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#include "rip_preproc.h"

#include <stdint.h>
#include <string.h>

void rip_preproc_init(rip_state_t *s) {
    if (!s) return;
    s->preproc_state = 0;
    s->preproc_len = 0;
    s->preproc_suppress = false;
    s->preproc_depth = 0;
    s->preproc_overflow = 0;
    memset(s->preproc_parent_suppress, 0, sizeof(s->preproc_parent_suppress));
    memset(s->preproc_branch_active, 0, sizeof(s->preproc_branch_active));
    memset(s->preproc_branch_taken, 0, sizeof(s->preproc_branch_taken));
}

/* Recompute the suppress flag from the top stack frame.  Local to
 * this module — exposed as a static helper used by push/else/endif. */
static void preproc_restore_suppress(rip_state_t *s) {
    uint8_t idx;

    if (!s) return;
    if (s->preproc_overflow > 0) {
        s->preproc_suppress = true;
        return;
    }
    if (s->preproc_depth == 0) {
        s->preproc_suppress = false;
        return;
    }

    idx = (uint8_t)(s->preproc_depth - 1);
    s->preproc_suppress = s->preproc_parent_suppress[idx] ||
                          !s->preproc_branch_active[idx];
}

void rip_preproc_push_if(rip_state_t *s, bool eval_result) {
    bool parent_suppress;
    bool branch_active;
    uint8_t idx;

    if (!s) return;

    if (s->preproc_overflow > 0) {
        /* Saturating increment — see uint16_t widening comment in
         * include/ripscrip.h.  UINT16_MAX nested IFs is well past
         * any conceivable adversarial input; stopping at the ceiling
         * means the counter can never wrap and re-enable a suppressed
         * branch. */
        if (s->preproc_overflow < UINT16_MAX) s->preproc_overflow++;
        s->preproc_suppress = true;
        return;
    }

    if (s->preproc_depth >= RIP_PREPROC_MAX_DEPTH) {
        s->preproc_overflow = 1;
        s->preproc_suppress = true;
        return;
    }

    parent_suppress = s->preproc_suppress;
    branch_active = parent_suppress ? false : eval_result;

    idx = s->preproc_depth++;
    s->preproc_parent_suppress[idx] = parent_suppress;
    s->preproc_branch_active[idx] = branch_active;
    s->preproc_branch_taken[idx] = branch_active;
    s->preproc_suppress = parent_suppress || !branch_active;
}

void rip_preproc_handle_else(rip_state_t *s) {
    uint8_t idx;

    if (!s) return;
    if (s->preproc_depth == 0) return;

    if (s->preproc_overflow > 0) {
        s->preproc_suppress = true;
        return;
    }

    idx = (uint8_t)(s->preproc_depth - 1);
    if (s->preproc_parent_suppress[idx]) {
        s->preproc_branch_active[idx] = false;
    } else if (s->preproc_branch_taken[idx]) {
        s->preproc_branch_active[idx] = false;
    } else {
        s->preproc_branch_active[idx] = true;
        s->preproc_branch_taken[idx] = true;
    }
    s->preproc_suppress = s->preproc_parent_suppress[idx] ||
                          !s->preproc_branch_active[idx];
}

void rip_preproc_handle_endif(rip_state_t *s) {
    if (!s) return;

    if (s->preproc_overflow > 0) {
        s->preproc_overflow--;
        preproc_restore_suppress(s);
        return;
    }
    if (s->preproc_depth == 0) return;

    s->preproc_depth--;
    preproc_restore_suppress(s);
}

bool rip_preproc_is_suppressing(const rip_state_t *s) {
    return s && s->preproc_suppress;
}
