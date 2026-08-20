/*
 * rip_preproc.h — RIPlib preprocessor suppression state machine
 *
 * Handles the <<IF>> / <<ELSE>> / <<ENDIF>> nesting logic that drives
 * the parser's `preproc_suppress` flag.  This module owns the LIFO
 * stack of branch states (parent_suppress, branch_active, branch_taken)
 * and the depth+overflow counters.  It does NOT own:
 *   - the byte-level FSM that recognises <<…>> delimiters
 *     (that stays in ripscrip.c at the parser entry point);
 *   - the <<IF expr>> expression evaluator (caller pre-evaluates,
 *     passes the result as a bool);
 *   - the <<DEBUG msg>> emission (caller handles directly via
 *     riplib_host_tx because that's a host-callback concern).
 *
 * This is an INTERNAL header (not under include/).  It exists to peel
 * the preprocessor logic off `src/ripscrip.c` as the first step toward
 * the broader subsystem decomposition tracked as audit candidate
 * C-002.  For now the functions still operate on `rip_state_t` so
 * the struct layout and the test suite stay unchanged; a future
 * iteration can encapsulate the preproc fields into their own
 * sub-struct once C-003 (opacify rip_state_t) lands.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#pragma once

#include <stdbool.h>
#include "ripscrip.h"   /* rip_state_t, RIP_PREPROC_MAX_DEPTH */

/* Zero all preproc_* fields of a freshly-initialised session. */
void rip_preproc_init(rip_state_t *s);

/* Push a new <<IF>> frame.  `eval_result` is the caller-evaluated
 * truth value of the IF expression.  Honours the depth cap and the
 * saturating overflow counter; a push that would exceed the cap is
 * silently turned into an overflow tick and the suppress flag is
 * raised.  Safe to call when an outer IF has already set suppress. */
void rip_preproc_push_if(rip_state_t *s, bool eval_result);

/* Switch the current frame's active branch (true ↔ false). */
void rip_preproc_handle_else(rip_state_t *s);

/* Pop the top frame.  Decrements the overflow counter first if it's
 * non-zero (so deep IFs unwind cleanly past the overflow boundary). */
void rip_preproc_handle_endif(rip_state_t *s);

/* Convenience accessor.  Equivalent to reading s->preproc_suppress;
 * kept as a function so future encapsulation of the preproc state
 * doesn't break callers. */
bool rip_preproc_is_suppressing(const rip_state_t *s);
