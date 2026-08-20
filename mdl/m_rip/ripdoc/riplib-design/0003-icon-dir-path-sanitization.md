# ADR-0003 — `1N` SET_ICON_DIR: validate path at ingest + document consumer contract

**Status**: accepted
**Date**: 2026-05-30
**Candidate**: C-013
**Reversibility**: easy
**Classification path**: lite
**Workflow version**: 2026-05.2
**Search tags / keywords**: code-safety, path-traversal, icon-dir, defense-in-depth, ingest-validation, platform-independence
**Decision-level qualities**:
- **Continuity value**: medium — closes an ingest-validation inconsistency and records the consumer trust-boundary contract
- **Knowledge capture**: adequate — variants + the `rip_filename_is_safe`-reuse pitfall recorded

## Context

The `1N` handler (`src/ripscrip.c:1729-1744`) copies the wire-supplied
icon-directory path into `s->icon_dir[64]` with correct length-clamping but
**no** `..`/control-character validation. It is inert *inside* RIPlib — a
repo-wide grep confirms nothing reads `icon_dir` to open a file — but the public
header invites "consumers that have a real filesystem [to] honor the path," so
the unsanitized value crosses a trust boundary the moment it is stored and is a
latent path-traversal handed downstream.

RIPlib already validates icon *names* at ingest via `rip_filename_is_safe`
(LOAD_ICON / WRITE_ICON / clipboard-as-icon), so leaving `icon_dir` unchecked is
an inconsistency in the project's own posture, not a deliberate design.

## Alternatives considered

1. **A — Validate at ingest only.** Reject `..`/control chars when storing
   `icon_dir`. Consistent with existing name validation; defense-in-depth. Why
   not alone: omits the durable contract note for consumers.
2. **B — Document only.** Leave `icon_dir` raw; add a header warning that
   consumers MUST sanitize before any `open()`. Why not: relies on every
   consumer reading the warning; preserves the latent traversal; inconsistent
   with the existing ingest validation. Dominated by C.
3. **C — Both: validate at ingest + document the contract (chosen).**

## Decision

Adopt **variant C**:

1. **Validate at ingest.** When storing `icon_dir`, apply a *directory-aware*
   safety check: **allow `/` separators** (it is a directory path) but reject
   `..` sequences, control characters, and embedded NUL; on failure leave
   `icon_dir` empty/unchanged. **Do NOT reuse `rip_filename_is_safe`** — it
   rejects `/` (correct for single filenames, wrong for a directory path); this
   needs an inline guard or a new `rip_dirpath_is_safe` helper.
2. **Document the contract** in the public header: the stored path is
   conservatively filtered, but consumers must still treat it as untrusted
   before any filesystem use.
The `1N` handler is otherwise tidy — it copies `p+2`..end length-clamped and
NUL-terminates, nothing more. (An earlier garbled tool-read had suggested dead
cruft — `mega2(p)`/`dpath` leftovers — but a clean re-read disproved it. No
cleanup is needed beyond adding the validation guard; this correction is itself a
small example of why findings get re-read against source before acting.)

## Why this won

Mirrors the project's existing ingest-validation posture and the C-003 pattern of
pairing a code/posture change with a documented contract. On the Lite scorecard
the non-dominated set was **{A, C}**; C is A plus one header sentence at near-zero
extra cost and strictly more knowledge capture, so it dominates A on
maintainability without losing on any other axis. B is dominated (keeps the
latent traversal).

Platform-independence is respected: `..`/control filtering is platform-neutral
string hygiene, not a platform reference.

**Falsification:** confirmed nothing in RIPlib opens `icon_dir`, so adding
validation cannot break any in-library behavior (worst case: a pathological path
is dropped, which is the safe failure mode); confirmed `rip_filename_is_safe`
rejects `/` and would wrongly reject every legitimate directory path if reused —
which is why a directory-aware check is specified. No disconfirming evidence.

## Trade-offs accepted

- RIPlib makes a minimal policy call about path syntax it doesn't itself consume;
  a pathological-but-technically-safe path containing `..` is rejected
  (acceptable conservative-gate behavior).
- This ADR is a plan; the edit + test are a follow-up session (Validation status
  `pending`).

## Verification plan

- **Properties**: `!|1N../../etc|` → `icon_dir` empty; `!|1Nicons/sub|` → stored
  intact; control char / NUL in path → rejected.
- **Validation mix**: 2-3 unit tests in `test_ripscrip.c`; existing CI.
- **Success means**: proves-correctness (the traversal vectors are rejected).

## Rollback path

Revert the single `1N`-handler edit and the one header sentence. No ABI/schema
change.

## Consequences

- Closes the ingest-validation inconsistency. (The `1N` handler is otherwise
  clean — no cruft cleanup needed; an earlier garbled read had wrongly implied
  some.)
- If a `rip_dirpath_is_safe` helper is added, it lands in `src/rip_internal.h`
  alongside `rip_filename_is_safe`.

## Open questions

*(none new)*

## Amendments

*(none yet)*
