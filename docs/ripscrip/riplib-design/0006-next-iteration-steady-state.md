# ADR-0006 — Next iteration: reconcile ledger, declare steady-state

**Status**: accepted
**Date**: 2026-05-31
**Candidate**: C-017
**Reversibility**: easy
**Classification path**: lite
**Workflow version**: 2026-05.2
**Search tags / keywords**: steady-state, iteration, backlog, ledger-hygiene, demand-driven, no-make-work, next-steps
**Decision-level qualities**:
- **Continuity value**: high — gives the repeated "iterate / proceed / resume" loop a documented terminus, so a future session does not manufacture churn on a shipped, demand-gated library.
- **Knowledge capture**: adequate — variants, the Pareto frontier, and the falsification walk of the open-unknowns backlog are recorded.

## Context

Asked "next steps to iterate" immediately after RIPlib v1.3.0 shipped
(`HEAD = origin/main = 39d7cee`, CI green per-job, two clean multi-agent
audits this session). A primitive read of `design/decisions.md` plus
on-disk verification shows the candidate backlog is effectively cleared:

- **Committed / complete**: C-001, C-002, C-003 (variant C), C-004
  (variant A′, shipped v1.3.0), C-012, C-013, C-014, C-015, C-016.
- **Executed but status-stale** (the `2026-05-25 | iterate-all-candidates`
  log line executed them; the Live-candidates *status* column was never
  flipped from `alive`): **C-005, C-006, C-007, C-008, C-009, C-010,
  C-011**. Their concrete artifacts all exist on disk (verified:
  `include/riplib_version.h`, `cmake/riplibConfig.cmake.in`,
  `tests/fuzz_parser.c`, `scripts/sync-to-a2gspu.sh`,
  `docs/spec/06a-v32-extensions.md`).
- **Parked on absent consumer demand**: C-003-B (full opacification,
  ADR-0005), C-004-A (full `g_rip_state` removal, ADR-0004).

So "next steps to iterate" is a genuine prioritization decision: with the
backlog clear, what is the correct *next* move — and is there one at all?

## Alternatives considered

1. **A — Reconcile the ledger + declare steady-state (chosen).** Flip the
   seven stale `alive` statuses to reflect reality; add a Workflow note
   recording that active iteration is complete and remaining work is
   either demand-gated (the two parked items) or out-of-repo (A2GSPU
   sync). No product-code change. Honest, reversible, zero-risk; ends the
   open-ended "iterate" loop with a recorded terminus.

2. **B — Quality micro-pack from the open unknowns ("v1.3.1").** Mine the
   19 open empirical questions for small first-party improvements. Why
   not: the highest-cited item, U-016 ("`rip_query_response_byte` lacks a
   length cap"), is **already false** — the code guards with
   `if (s->query_response_len < (int)sizeof(s->query_response) - 1)`. The
   remainder need external data (real BBS wire captures: U-004, U-005,
   U-014) or are out-of-repo (U-002/U-007/U-021). What's left is make-work
   churn on a shipped, audited library with no consumer asking — the exact
   sunk-cost/preemptive-optimization trap the project's own
   `demand-driven-allocation` rule warns against. Dominated by A.

3. **C — Sync A2GSPU's vendored `libriplib/` to v1.3.0.** The standing
   offered external next-step; real value (keeps the one known consumer
   current). Why not *now*: it touches a *different* repository, needs
   explicit user go-ahead, and per project memory is "A2GSPU's problem,
   tracked on its side." Recorded as the one genuinely-available external
   next-step, to be taken **on user go-ahead** — not folded into this
   decision.

4. **D — Resume a parked breaking change (C-003-B or C-004-A).** Why not:
   both parks have explicit resume conditions tied to consumer demand
   (C-004-A: a concrete multi-session embedder reports the constraint as a
   blocker; C-003-B: a consumer direct-accesses fields *or* a binary-
   distribution path appears). Neither has fired. Re-opening now would
   re-litigate a deliberate park and ship a breaking change nobody asked
   for. Rejected.

## Decision

Adopt **variant A**. Treat RIPlib as having reached a **steady state**:
v1.3.0 is shipped, CI-green, and audited; the design backlog is cleared.

1. In `design/decisions.md`, update the seven stale Live-candidate rows
   (C-005..C-011) from `alive` to an executed/committed status that
   matches the `2026-05-25 | iterate-all-candidates` log line and the
   on-disk artifacts.
2. Add a Workflow note recording the steady-state: active iteration is
   complete; the *only* remaining moves are (i) the two demand-gated
   parked items (resume only when their conditions fire), (ii) the
   out-of-repo A2GSPU v1.3.0 sync (on user go-ahead), and (iii) the
   user-owned GitHub Release page publish for v1.3.0.
3. No product-code change; no version bump.

## Why this won

Decisive axes (full Lite scorecard: Correctness, Complexity,
Reversibility, Risk — Maintainability/Verification-effort uniform-OK
across A/B since both are doc-or-small): **Risk** and **Complexity**. A is
the only variant that is simultaneously honest about the real state,
risk-free (docs only — no chance of regressing a shipped library), and
terminating (it stops the open-ended iterate loop instead of feeding it).
The falsification walk of all 19 open unknowns found no high-value,
low-risk, in-repo, demand-free work item — confirming A reflects reality
rather than avoiding effort. C is real but gated; B/D are make-work and
park-violation respectively.

## Trade-offs accepted

- **Declares "done" on a project that could always have more features.**
  If a real consumer need appears tomorrow, this decision is trivially
  re-opened (it's a doc state, `easy` reversibility). The risk of
  *under*-building here is far smaller than the demonstrated risk of
  churning a shipped lib.
- **Leaves 19 unknowns open.** That is correct: they are open *questions*,
  not open *work* — several are unanswerable without external data, and
  recording them as open is the honest state.

## Rollback path

Trivial: this is a documentation state change. If a consumer need or new
evidence arrives, re-open the relevant candidate (Appendix D re-entry /
park-resume) and run a fresh /decide. No code to revert.

## Consequences

- The "iterate / proceed / resume" loop now has a recorded terminus; a
  future session reading the ledger sees steady-state, not a pile of
  `alive` rows inviting make-work.
- The three legitimate forward moves (A2GSPU sync, parked-item resume on
  demand, Release-page publish) are explicitly enumerated, so "what's
  next?" has a primitive-checkable answer.

## Verification plan

- **Properties to hold**: the ledger's Live-candidate statuses match the
  decisions-log history and on-disk artifacts; no product code changed
  (CI stays green at the same code as 39d7cee).
- **Validation mix**: manual ledger review + `git diff --stat` confirming
  only `design/` files changed.
- **Success means**: builds-confidence (a bookkeeping-accuracy change, not
  a behavioural one).

## Open questions

- The 19 open empirical questions in `knowledge.md` remain open by design;
  none blocks steady-state. They are revisited only if a resume condition
  or new external data arrives.

## Amendments

*(none yet)*
