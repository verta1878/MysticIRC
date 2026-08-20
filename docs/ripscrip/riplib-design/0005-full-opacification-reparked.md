# ADR-0005 — Full `rip_state_t` opacification (C-003 variant B) — PARKED

**Status**: parked
**Date**: 2026-05-31
**Candidate**: C-003-B (the future-major successor named in ADR-0001)
**Classification path**: full
**Workflow version**: 2026-05.2
**Search tags / keywords**: parked, rip_state_t, opaque, opacification, internal-header, abi, encapsulation, vendored-source, static-lib, premature-opacification

## Context

ADR-0001 committed C-003 **variant C** (opaque-by-policy: the struct
stays publicly visible with a prominent INTERNAL policy comment) and
explicitly named **variant B** (full opacification — public header gets
only `typedef struct rip_state rip_state_t;`, the definition moves to a
private `src/rip_state_internal.h`, and the ~211 white-box test sites +
the four internal modules opt in via `#include "rip_state_internal.h"`)
as *"the future candidate when consumer signal warrants the ABI break."*

This ADR is the explicit re-evaluation of whether to **promote C → B
now**, requested as part of resuming the parked design items after the
v1.2.2 release. The conclusion is to **re-park B** with a sharper,
measurable resume condition and an explicit promote-to-kill clause —
not to kill it (the analysis below is worth preserving) and not to
promote it (the justification does not exist today).

## Alternatives considered (current state of analysis)

1. **Promote to B now.** Forward-typedef in the public header; struct
   definition to `src/rip_state_internal.h`; test + internal modules
   opt in. Breaking for any external consumer doing direct field
   access. Major version (2.0.0). Why not now: see *Why parked*.

2. **Re-park (chosen action).** Keep variant C (shipped, working);
   defer B; sharpen the resume condition so a future-self can evaluate
   it without reloading context.

3. **Staged header split (non-breaking prep).** Move the struct
   definition into `src/rip_state_internal.h` *now*, but have the
   public header still `#include` it (so the struct stays transitively
   visible = no break), while internal modules switch to including the
   internal header directly. The eventual B becomes a one-line change
   (drop the `#include` from the public header). Why not now: it churns
   the `#include` lines of the test suite + four modules and introduces
   a new header purely to prepare for a break that may never be
   scheduled (variant 4 could win), for zero functional gain today —
   exactly the demand-driven-allocation anti-pattern. The prep is
   mechanical and just as cheap to do *when* B is actually scheduled.
   Recorded as the first implementation step **if/when** B resumes, not
   as work to do speculatively.

4. **Permanent opaque-by-policy (inversion — kill the B obligation).**
   Adopt variant C as the *terminal* state: declare `rip_state_t`
   permanently opaque-by-policy (zlib-style "fields are read-only by
   convention"), discharging ADR-0001's standing "phase-2 obligation"
   debt. Rationale: see the distribution-model insight in *Why parked*.
   Not chosen *yet* because it forecloses B prematurely while U-021 is
   unanswered — but it is the leading candidate the promote-to-kill
   clause points to, and may well be the honest long-term answer.

## Why parked (not killed)

Variant B is real, well-analysed, and the conventional long-term end
state for a C library (SQLite, libgit2). It is parked rather than
promoted because **the information and the demand that would justify the
break do not exist today**, and parked rather than killed because that
information may yet arrive.

Three forces, all pointing at "defer":

1. **No ABI-distribution scenario in play (the decisive new insight).**
   C-005 committed RIPlib's distribution model as **vendored source +
   STATIC library** (T-003 forced `add_library(... STATIC ...)`; there
   is no `.so`/`.dll` shipping path). Every consumer recompiles from
   source against the matching header. Opacification's headline
   benefit — a stable *binary* ABI across versions so prebuilt
   binaries keep linking — therefore **does not apply**. B's residual
   benefit collapses to *source-level encapsulation discipline*
   (stopping consumers from coding against internal fields), which
   variant C's policy comment + the recompile-from-source reality
   already largely deliver. Captured as HR-004 in `knowledge.md`.

2. **U-021 is unanswered and gates the break.** Whether A2GSPU's
   vendored integration (`platform_a2gspu.c` + glue) directly accesses
   `rip_state_t` fields cannot be determined from this environment. If
   it does, B is a coordinated cross-repo migration, not a local edit.
   Promoting B before answering U-021 would be flying blind into a
   breaking change.

3. **Just-shipped-stable + premature-opacification regret.** v1.2.2
   shipped 2026-05-30 (CI green, two clean multi-agent audits). The
   prior-art register's libnotify/libgudev entries document multiple
   breaking API rounds when opacification lands before the accessor
   set / access patterns are understood (U-022 also open). The staged
   C→B sequence ADR-0001 chose exists precisely to avoid this; jumping
   to B now would spend the staging for nothing.

## Resume condition (measurable)

Promote C-003-B from parked to live, and re-run the loop at Phase 1,
when **either**:

- **(a)** A2GSPU's (or any external consumer's) source is inspected and
  found to access `rip_state_t` fields directly **and** that coupling
  is causing real friction (a field rename/removal broke them, or they
  request a stable internal layout) — i.e., U-021 resolves "yes,
  problematically"; **or**
- **(b)** RIPlib gains a **binary-distribution** path (a published
  prebuilt `libriplib.a`/shared lib that consumers link *without*
  recompiling from the matching header — C-005 variant C territory),
  which would reintroduce a real ABI-stability requirement that
  opacification serves.

Either condition is evaluable by a future-self without this context:
(a) is "go read the consumer's source / check the issue tracker," (b)
is "did we start shipping binaries?"

## What would warrant promoting to Kill

If, at the **next annual review of ADR-0001's deprecation promise** (or
sooner), **both** of the following hold, convert this park to a Kill by
writing a Kill ADR that supersedes both this ADR and ADR-0001's
"phase-2 obligation," and formally adopt **variant 4 (permanent
opaque-by-policy)**:

- RIPlib's distribution remains source-vendored / static-only (resume
  condition (b) has not fired), **and**
- No consumer has reported the field exposure as a problem (resume
  condition (a) has not fired) for a full review cycle.

In that world, opacification buys discipline that variant C already
provides and an ABI guarantee that no one needs — the honest move is to
make opaque-by-policy the terminal decision and stop carrying the
"future major will opacify" promise as open debt. This clause exists so
the park cannot linger indefinitely as false-advertised future work.

## Open questions

- **U-021** *(open)* — does A2GSPU access `rip_state_t` fields
  directly? Gates resume condition (a) and the cost of B if promoted.
  Answerable only by inspecting the consumer's source tree.
- **U-022** *(open)* — are there legitimate consumer patterns
  (debugging, serialisation, hot-path) that need *permanent* direct
  field access? If yes, B's accessor set must cover them (pushing
  toward variant A's accessor API) or B must keep the internal-header
  escape hatch; if no, B can be strict. Should be answered before any
  promotion.
- **U-020** *(answered, carried for context)* — 211 direct field-access
  sites in `tests/test_ripscrip.c`; B leaves them unchanged via the
  internal-header opt-in, so test churn is *not* a blocker for B (it
  is for variant A).
