/*
 * rip_variables.h — RIPlib variable-expansion engine + user-var storage.
 *
 * This module owns:
 *   - The $VAR$ text-expansion engine (rip_expand_variables) covering
 *     built-in variables ($DATE$, $TIME$, $RAND$, $RIPVER$, layout
 *     variables, color-name aliases, sound tokens, …) and the user-
 *     defined slot lookups ($APP0$..$APP9$ + 16 named slots).
 *   - The <<IF expr>> expression evaluator (rip_eval_if_expr) that
 *     the preprocessor calls back into.
 *   - User variable storage primitives that the rest of the parser
 *     uses when handling the |1d (DEFINE) family of commands.
 *
 * Extracted from src/ripscrip.c as step 2 of audit candidate C-002
 * (decompose ripscrip.c monolith).  Functions still take a
 * rip_state_t* so the existing struct layout and the test suite stay
 * unchanged; a future iteration (gated on C-003) can encapsulate
 * the user-var arrays into a sub-struct once rip_state_t is opaque.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#pragma once

#include <stdbool.h>
#include "ripscrip.h"

/* Validate and copy a user-supplied variable name into `out`.  Strips
 * surrounding `$` delimiters and ASCII whitespace; rejects names that
 * contain non-identifier characters.  Returns false on rejection. */
bool rip_var_name_copy(const char *name, int len, char *out, int out_cap);

/* Find a user-defined variable by name.  Returns its index in
 * s->user_var_values, or -1 if not found.  Does NOT look up the
 * $APP0$..$APP9$ slots — those are accessed directly via app_vars[]. */
int rip_user_var_find(const rip_state_t *s, const char *name, int len);

/* Create or overwrite a user-defined variable.  Names matching the
 * $APP0$..$APP9$ pattern are routed to the app_vars[] array.  Returns
 * false on table-full or invalid-name. */
bool rip_user_var_set(rip_state_t *s,
                      const char *name, int name_len,
                      const char *value, int value_len);

/* Begin a $QUERY$ round-trip: push a CMD_QUERY_PROMPT token to the
 * host's TX FIFO and stash the target variable name so a subsequent
 * rip_query_response_byte() sequence can commit the response.
 * Returns false if a query is already pending or arguments are
 * invalid. */
bool rip_query_prompt_begin(rip_state_t *s,
                            const char *vname, int vlen);

/* Expand $VAR$ references in `in` and write the result to `out`.
 * Returns the number of bytes written (always NUL-terminated, not
 * counted in the return value).  Unrecognised $XYZ$ tokens are
 * emitted as literals. */
int rip_expand_variables(rip_state_t *s,
                         const char *in, int in_len,
                         char *out, int max_out);

/* Evaluate a single <<IF expr>> expression.  The expression is
 * variable-expanded first, then parsed for the canonical operators
 * (`!=`, `>=`, `<=`, `=`, `>`, `<`) or treated as a boolean (non-
 * empty and not literal "0"). */
bool rip_eval_if_expr(rip_state_t *s, const char *expr);
