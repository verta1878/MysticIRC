# ADR-0002 — Spec/code drift reconciliation (pass v2): triage fix-vs-document

**Status**: accepted
**Date**: 2026-05-30
**Candidate**: C-012
**Reversibility**: easy
**Classification path**: full
**Workflow version**: 2026-05.2
**Search tags / keywords**: spec-conformance, dll-deviations, drift, text-escapes, mouse, define, button, bgi-font, scalable-text, icon-lookup, documentation, reverse-engineered-protocol
**Decision-level qualities**:
- **Continuity value**: high — establishes *how* this reverse-engineered protocol resolves doc-vs-code divergence for all future audits, not just these 11 items
- **Knowledge capture**: strong — per-item disposition recorded; the three ground-truth unknowns (U-024/025/026) that gate the "document" set are enumerated

## Context

The 2026-05-30 Opus-4.8 re-audit surfaced ~11 undocumented spec-vs-code
divergences (candidate C-012). None breaks a well-formed mainstream RIPscrip
stream, but each is silent drift, which **HR-001** prohibits ("spec deviations
must be documented in `docs/spec/11-dll-deviations.md`; the implementation must
either match the spec or record the deviation"). HR-001 explicitly offers two
remedies — fix the code, or document the deviation — without saying which to
use when. This decision sets that policy and applies it item-by-item.

Confirmed against current code: `unescape_text` (`src/ripscrip.c:729`) recognizes
`\\ \| \!` (its own comment says so) versus spec §1.6/§7.1's `\\ \| \^ \n`;
`docs/spec/11-dll-deviations.md` already exists with a clean per-entry
`Spec / RIPlib / Why` format (D.1 documents the analogous MegaNum-lowercase
deviation), so a documentation home is established.

## Alternatives considered

1. **A — Document everything in `11-dll-deviations.md`, change no code.**
   Zero code risk, fast, fully honest record. Why not: leaves genuine RIPlib
   *bugs* in place — notably the `bgi_font.c:58-61` comment that contradicts
   both the code and §8.4 (which calls that table ordering "CRITICAL" and a
   historical DLL failure mode), plus the stray text-escape set. HR-001's
   first remedy (fix) is never used even where it's clearly right. Dominated
   by B on correctness/maintainability.

2. **B — Triage: fix the code where it diverges from *both* spec and likely
   DLL; document where the code matches DLL behavior and the spec doc is the
   incomplete side (chosen).** Each item handled on its merits.

3. **C — One PR per item.** Maximal granularity / clean history. Why not:
   ~11 commits for a defunct protocol's edge cases is ceremony out of
   proportion; most "document" items are one-line spec edits that don't merit
   isolated PRs. Dominated by B (same outcome, more overhead).

## Decision

Adopt **variant B**. The governing principle: for a reverse-engineered, defunct
protocol (TeleGrafix is gone), **ground truth is observed RIPterm/`RIPSCRIP.DLL`
behavior**, which the historical v1.54 DOC / v2.0 PRN only approximate. Therefore:

- where the code matches (or plausibly matches) DLL behavior and the spec doc is
  a simplification → **the doc is the side to correct** (record the deviation);
- where the code diverges from **both** the spec and likely DLL → **the code is
  the bug** (fix it).

**FIX IN CODE** (code is wrong vs spec, no DLL-faithfulness reason to keep it):

| Item | Location | Action |
|------|----------|--------|
| Text escapes | `ripscrip.c:729` `unescape_text` | add `\^` and `\n` (newline); keep `\!` as a documented RIPlib extension. **Behavior change → regression test required.** |
| `S` RIP_FILL_STYLE pattern | `ripscrip.c` ~2155 | clamp to spec range 0-12. Render-neutral (`bgi_fill_to_card` already defaults >12→COPY/0); only the stored value used by state-stack / `$`-introspection changes. |
| BGI font table-order comment | `bgi_font.c:58-61` | correct to match the code + §8.4 (stroke-offset table first at `+16`; 16-byte header). **Comment only, zero behavior change.** |
| `1B` button 1-segment case | `ripscrip.c:1420-1504` | reuse the single label segment as the host command per §3.4; fix the header comment's reversed `host<>label` order. **Small behavior addition → test.** |

**DOCUMENT AS DEVIATION** (code likely matches DLL; spec doc is the incomplete
side; **no DLL ground truth available** to safely change working code — see Open
questions). Add `11-dll-deviations.md` entries for:

- `1M` mouse `res:4` field — spec §3.2 lists 11 fixed chars, code consumes 17
  (`ripscrip.c:1381`). **Gated by U-024.**
- `1D` DEFINE `flags:3 res:2` prelude + `?prompt?default` grammar — spec §3.18
  shows bare `name=value` (`ripscrip.c:1953`). **Gated by U-025.**
- Undocumented-but-implemented commands: `1V`/`1X`/`1R`, Level-0 backtick
  RIP_COMPOSITE_ICON, `(`/`)` group + `!` comment markers. **Gated by U-026.**
- 8×8 bitmap font described in §8.1 but never implemented (always 8×16).
- `26` SCALABLE_TEXT scale capped `&0x07` vs the "scalable beyond 1-10" promise.
- `22` SET_WINDOW paints fixed chrome colors the spec doesn't define.
- Icon-lookup order: code = cache→BMP→ICN vs spec §9.2 BMP→ICN→cache (deliberate:
  runtime cache supersedes flash; document the rationale).

The Level-3 `'9'`-vs-`'3'` prefix mismatch remains tracked under C-010 (not
re-litigated here).

## Why this won

HR-001 offers fix-OR-document; B is the faithful application — each item gets the
remedy that fits. The decisive axes from the full scorecard:

| Axis | A | B | C |
|---|---|---|---|
| Correctness (of code) | concern (bugs remain) | OK | OK |
| Complexity | OK | OK | concern (11 PRs) |
| Maintainability | concern (bgi_font trap stays) | OK (code+spec aligned) | OK |
| Verification effort | OK | concern (3 new tests) | concern |
| Risk | OK | OK (bounded) | OK |
| Reversibility | easy | easy | easy |

Non-dominated set was **{A, B}**; B wins on **Correctness + Maintainability**
under the project's own anti-silent-drift rule. C dominated by B.

**Falsification searches that did not disconfirm:** (a) could adding `\n`→newline
break real streams? — spec says `\n` *is* a newline, so the current pass-through
is itself the non-conformance; a consumer relying on the old behavior relies on a
bug. (b) is the `S` clamp render-safe? — `bgi_fill_to_card` already maps >12 to
the default, so clamping the stored value changes no rendering. (c) are the
"document" items genuinely missing DLL ground truth? — yes; U-024/025/026 are
open and answerable only by DLL disassembly or wire captures, so changing the
working code would be guessing.

## Trade-offs accepted

- The "document" set leaves code that may diverge from a *future-recovered* DLL
  truth. Mitigated: U-024/025/026 are logged so any item can flip to fix-in-code
  if a capture/disassembly arrives.
- The fix set adds a text-rendering behavior change (escapes) — must ship with a
  regression test, not blind.
- This ADR is a **plan**; the edits are a follow-up hands-on session. The
  candidate's Validation status stays `pending` until those land + tests pass.

## Verification plan

- **Properties to hold**: `\^`→`^`, `\n`→newline, `\!`→`!` still work; `S`
  pattern >12 stored as a value ≤12; `1B` single-segment button registers a
  clickable host region; documented items — spec text now matches code (review).
- **Hard-to-reach states**: text containing a trailing lone `\`; `1B` with 0/1/2
  separators.
- **Validation mix**: unit tests for the 4 code fixes; inspection review for the
  7 doc entries; existing CI (3 OS × 2 build + sanitizers + coverage + ARM).
- **Success means**: builds-confidence (rendering changes) + proves-correctness
  (doc-matches-code by inspection).

## Rollback path

Each of the 4 code edits is small and independently revertible; the doc entries
have no code impact. Revert the relevant commit(s); no schema or ABI change.

## Consequences

- `11-dll-deviations.md` grows ~7 entries; `ripscrip.c` text-escape + fill-style
  behavior changes (tested); `bgi_font.c` comment corrected.
- Sets the precedent for this repo: **DLL behavior is ground truth; docs are
  corrected to match unless the code diverges from both spec and DLL.** Future
  audits cite this ADR for the disposition rule.
- Extends the C-010 "spec conformance" theme.

## Open questions

- **U-024** *(open)*: `1M` reserved field — did the DLL consume 11 chars (spec)
  or 17 (code)? Decides whether that item stays documented or flips to fix.
- **U-025** *(open)*: `1D` DEFINE wire grammar — `flags:3 res:2` prelude (code)
  or bare `name=value` (spec §3.18)?
- **U-026** *(open)*: are `1V`/`1X`/`1R` + backtick/group/comment markers RIPlib
  extensions or recovered DLL commands? Decides "extension" vs "DLL command"
  framing in the deviation entries.

## Amendments

*(none yet)*
