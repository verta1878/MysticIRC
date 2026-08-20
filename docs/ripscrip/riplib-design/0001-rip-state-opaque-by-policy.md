# ADR-0001 — `rip_state_t` opaque-by-policy

**Status**: accepted
**Date**: 2026-05-25
**Candidate**: C-003
**Reversibility**: easy
**Classification path**: full
**Workflow version**: 2026-05.2
**Search tags / keywords**: rip_state_t, opaque, abi, public-api, encapsulation, struct-visibility, deprecation
**Decision-level qualities**:
- **Continuity value**: medium — sets discipline for future field additions and gives consumers a deprecation signal; doesn't prevent harm today
- **Knowledge capture**: strong — all five variants enumerated, Pareto frontier identified, falsification searches recorded

## Context

`rip_state_t` is defined in full (~50 fields, ~220 bytes) inside the
public header `include/ripscrip.h`.  Consumers can — and a few do —
reach into the struct directly:

- The library's own test suite (`tests/test_ripscrip.c`) does so
  intentionally for white-box assertions: **211 direct field-access
  sites** across the suite.
- Examples (`examples/demo.c`, `examples/rip2ppm.c`) do **not**
  access fields directly (API-only, clean).
- Internal modules (`src/rip_preproc.c`, `src/rip_variables.c`,
  `src/rip_clipboard.c`, `src/ripscrip2.c`) access fields via the
  `rip_state_t *` parameter pattern.
- A2GSPU (the one known external vendoring consumer) — access
  pattern unknown; their `platform_a2gspu.c` may or may not reach
  into fields.

The original audit (`design/decisions.md` C-003) flagged the public
struct as a code smell: any future addition to `rip_state_t` is an
ABI surface that a consumer could come to depend on.  C-003 was
initially parked with the resume condition "wait for C-002 to land
so the struct shape stabilises."  C-002 step 6 (clipboard extraction)
completed on 2026-05-25, satisfying that condition; this ADR is the
post-park re-evaluation.

## Alternatives considered

1. **A — Full opacification + accessor API.** Public header gets
   only `typedef struct rip_state rip_state_t;`; struct definition
   moves to a private header; ~30 accessor functions added; **all
   211 test sites rewritten** as function calls.  Why not: massive
   churn for marginal gain when there's no consumer currently asking
   for the opaque guarantee.  Dominated by variant B.

2. **B — Opaque public + private header for internal use.** Public
   header gets only the forward typedef; struct definition moves to
   `src/rip_state_internal.h`; tests + internal modules opt in via
   `#include "rip_state_internal.h"`; 211 test sites unchanged.
   External consumers can no longer reach fields without explicitly
   opting in (real ABI break for A2GSPU's `platform_a2gspu.c` if it
   accesses fields).  Why not *yet*: no concrete consumer signal
   warrants the break today; doing it now risks premature-
   opacification regret (e.g. `libnotify`, `libgudev` had to revise
   their opaque APIs multiple times before the accessor set settled).

3. **C — Opaque-by-policy + visible struct (chosen).**  Keep the
   struct definition public, but prefix it with a prominent block
   comment declaring it INTERNAL and signalling a future major-
   version opacification.  Zero ABI break.  Reversible upgrade path
   to variant B when concrete consumer signal arrives.

4. **D — Hybrid `rip_state_view_t` public + opaque `rip_state_t`.**
   Add a small public "view" snapshot struct for consumer-relevant
   fields; opaque the full state.  Why not: adds a third header
   layer with no current customer; B is simpler with the same
   future-proofing.  Dominated by B.

5. **E — Re-park with sharper resume condition.**  Defer entirely;
   sharpen condition to "a consumer reports the exposure as a
   problem."  Why not: this is what was already true under the
   prior park; re-parking without doing the policy work would not
   move the discipline needle.  Dominated by C.

## Decision

Mark `rip_state_t` as INTERNAL by policy via a prominent block
comment in `include/ripscrip.h` immediately preceding the struct
definition.  The struct stays publicly visible (no ABI break); the
comment puts consumers on notice that:

1. Direct field access is **discouraged**; use the public
   `rip_*()` API where possible.
2. The field layout is **not part of the stable ABI** and may
   change between minor releases.
3. A future major version will opacify the struct fully (variant
   B), at which point external consumers doing direct field access
   will need to switch to either accessor functions (variant A) or
   opt in via an internal header (variant B).

Future PRs adding fields to `rip_state_t` are expected to honour
this policy: new fields are internal-by-default and only get
documented accessors when a public consumer use case actually
exists.

## Why this won

The Pareto frontier collapsed to **{B, C}**; variant C wins on the
discriminating axes for *today*'s situation:

| Axis | B | C |
|---|---|---|
| Correctness | OK | OK |
| Complexity | OK | OK |
| Maintainability | OK | OK |
| Verification effort | OK (cross-env build + A2GSPU manual test) | OK (no change) |
| Risk | concern (ABI break) | OK |
| Reversibility | costly | easy |

Decisive: **Reversibility + Risk** under current consumer signal
(one known consumer, unverified access pattern).  C is the right
*first* step; B is the right step *when* a consumer either (a)
reports the exposure as a problem or (b) requires multi-version
ABI stability.  Doing C now also produces the durable deprecation
signal that lets A2GSPU plan its migration before B lands.

**Falsification searches that did not find disconfirming evidence**:
- LWN + Hacker News for "opaque struct C library best practice" —
  confirms B is the convention long-term; does not argue against
  C as a staged first step.
- Premature-opacification regret stories (libnotify, libgudev) —
  *actively support* doing C first and B second once access
  patterns are known.
- "Opaque-by-policy never works for C libraries" — found
  counter-examples (Linux kernel `__private` discipline, zlib's
  documented "fields are read-only" convention).

## Trade-offs accepted

- **No enforcement.**  A consumer can ignore the policy comment
  and read fields anyway.  If they do, they will be broken by a
  future variant-B promotion — but that's the consumer's choice,
  and they've been warned.
- **Doesn't prevent harm today.**  If a careless PR adds a new
  field that becomes load-bearing for A2GSPU before B lands,
  removing it later will still be painful.  The policy comment
  exists to reduce this risk but cannot eliminate it.
- **Adds a "phase 2" obligation.**  This ADR commits the project
  to eventually doing variant B (when consumer signal warrants);
  failing to follow through would leave the deprecation warning
  hanging indefinitely, which is its own kind of debt.

What could make us regret this:
- A2GSPU absorbs the policy notice and migrates to API-only
  access, then no one ever invokes variant B — the deprecation
  warning becomes false advertising.  Mitigation: revisit annually.
- A new external consumer appears and immediately depends on
  direct field access in a way that variant B would break;
  variant B becomes harder to ship.  Mitigation: every new
  consumer integration should be reviewed for direct field access
  during onboarding.

## Verification plan

- **Properties to hold**: zero behavioural change; tests compile
  and pass unchanged; A2GSPU parity script reports no source drift
  (the policy comment is the only addition).
- **Hard-to-reach states**: none — this is a documentation change
  with no code execution path.
- **Validation mix**: existing CI (build + ctest on three OS × two
  build types + sanitizers + coverage gates + ARM cross-build).
  No new tests required.
- **Success means**: builds confidence.  The change is
  comment-only; the test suite verifies the *unchanged behaviour*
  rather than the new policy.

## Rollback path

Trivial.  Revert the single commit that adds the policy comment to
`include/ripscrip.h`.  No code changes to undo; no test rewrites
to undo; no consumer impact.

## Consequences

- Sets the precedent that `rip_state_t` field additions are
  internal-by-default.  Future PR reviews should ask: "does this
  new field need a public accessor, or is it for the parser's
  internal use only?"
- Future variant-B promotion (the actual opacification) becomes
  a smaller, less surprising change because the deprecation
  signal will have been visible since this ADR shipped.
- The C-003 candidate moves from `parked` to `committed`
  (variant C); the future variant-B work gets a fresh candidate
  ID (C-003b or similar) when it's time, with this ADR cited as
  the prior-analysis context.

## Open questions

- U-NEW-1 *answered*: 211 field-access sites in `test_ripscrip.c`.
- U-NEW-2 *open*: does A2GSPU's `platform_a2gspu.c` access
  `rip_state_t` fields directly?  Answer would inform the timing
  of variant-B promotion.  Can be answered by inspecting A2GSPU's
  source tree (not available from this environment).
- U-NEW-3 *open*: are there legitimate consumer patterns
  (debugging, serialisation, hot-path optimisation) that would
  require direct field access permanently?  Should be answered
  before variant-B promotion.

## Amendments

*(none yet)*
