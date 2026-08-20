# design/

What is here, and what deliberately is not.

## Published

- **`adr/`** — Architecture Decision Records. These are the reasoning a
  consumer or reviewer needs, not internal bookkeeping: ADR-0001 explains
  why `rip_state_t` is opaque by policy, ADR-0003 why a wire-supplied icon
  path is filtered before it is stored. Public headers cite them.
- **`syntax-audit.md`** — the audit of every command against the driver's
  own dispatch record. `CHANGELOG.md` cites it as the evidence for the
  2.0.x argument-layout fixes, so it belongs with the claims it supports.
- **`bbs-land-issue-2-correction.md`** — a correction to an issue this
  project filed upstream. Public the moment it is sent.

## Not published

Three files are the project's internal working record and are kept on
local disk only (`.gitignore`):

    design/decisions.md          candidate/decision ledger, session traces
    design/knowledge.md          uncertainty register, heuristic rules
    design/bbs-land-alignment.md the reconciliation phase plan

They are working notes rather than deliverables — session-by-session
narration, abandoned approaches, tool-use lessons — and they carry
incidental local machine layout. Publishing them would add noise, not
evidence.

**So references to them will not resolve here, and that is expected.**
Prose in the spec, the headers and the ADRs cites identifiers from those
ledgers — `C-003`, `C-004`, `HR-005`, `U-023` and similar. Those are
traceability markers, kept because the reasoning they point at is real
and because silently deleting a citation is worse than leaving one a
reader cannot follow. Nothing in the published tree depends on reading
them: every claim about the driver is re-derivable from the binary with
the scripts in `scripts/`, which is the point of
`docs/spec/14-divergence-register.md` §14.1.

If you need the reasoning behind a specific decision ID and it is not in
an ADR, ask — it is not secret, just unpublished.

## Note on history

These files were tracked until 2026-08-14 and remain in the repository's
git history. Untracking stops publishing *future* versions; it does not
remove past ones. Nothing in them is sensitive — no credentials, no
third-party material — which is why the history was left intact rather
than rewritten.
