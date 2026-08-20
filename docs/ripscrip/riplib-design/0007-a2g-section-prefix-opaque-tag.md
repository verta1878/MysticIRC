# ADR-0007 — `§A2G` is an opaque revision tag, not a consumer reference

**Status**: Accepted
**Date**: 2026-08-12
**Candidate**: C-018 (bbs-land alignment)
**Search tags / keywords**: platform-independence, branding, section-numbering, A2G, constraint-amendment, external-citations

---

## Context

RIPlib's protocol extensions are numbered `§A2G.1` through `§A2G.13`. The
prefix derives from **A2GSPU**, the firmware RIPlib was extracted from — a
consumer name.

The platform-independence constraint (`design/decisions.md`) is binding and
enumerates the only acceptable places for consumer-specific names:

> The only acceptable places for those names are: `README.md` Origins /
> Reference target paragraphs, and `cmake/arm-none-eabi.cmake`.

A section prefix in the specification is neither. So `§A2G` is, on a literal
reading, out of compliance — 36 occurrences across `docs/spec/` and `README.md`.

Two facts constrain the response:

1. **The prefix is externally cited.** bbs-land/remote-imaging-protocol
   documents RIPlib's extensions in two published trees named `3.1-riplib`
   and `3.2-riplib`, and cites `§A2G.N` roughly twenty times across their
   version tables, conflict register and per-section pages.
2. **The prefix carries no information.** `A2G` expands to nothing for any
   reader who has not been told what it stands for. Neither bbs-land's pages
   nor RIPlib's own spec expand it. The wire identifiers (`RIPSCRIP031001`,
   `RIPSCRIP032001`) carry no branding at all.

## Decision

**Declare `§A2G` an opaque revision tag** — a label with no expansion — and
amend the platform-independence constraint to say so explicitly.

The constraint gains one documented exception. `§A2G` is not to be expanded to
"A2GSPU" anywhere in the specification, README, or commit messages; where it
was expanded (`README.md`'s feature paragraph), the expansion has been removed
and the tag kept.

Future extension sections continue to use `§A2G.N` for continuity. A new,
unrelated extension family would get a neutral prefix.

## Alternatives considered

**Rename to `§RL.N` with an alias table.** Genuinely neutral, and the
"correct" answer if the prefix were being chosen today. Rejected because it
invalidates roughly twenty citations in an actively maintained external
repository — including its conflict register, which is the document this whole
alignment programme is answering — plus RIPlib's own `docs/spec/06`, `06a`,
README and CHANGELOG. The cost is real interoperability friction; the benefit
is cosmetic, because the string being removed already means nothing to a
reader.

**Leave it undocumented.** Rejected. The constraint is binding and the prefix
plainly violates a literal reading. Leaving that unresolved is exactly the
silent-drift failure mode the spec-is-first-class rule exists to prevent, and
it would leave the branding lint passing by an exemption nobody had agreed to.

## Consequences

- The constraint is amended **with** an ADR and a chronological log row, rather
  than in place. That matters independently: code-review finding 6 on `3e05ecb`
  was precisely an inline amendment of this constraint with no log entry, and
  repeating that here while fixing it would have been incoherent.
- `scripts/check-branding.sh` continues to allow `A2G` (it does not match the
  forbidden pattern, which targets `A2GSPU`, `A2FUSION`, `ProDOS` and the
  card's `Processor "B"/"V"` role labels). That allowance is now backed by a
  decision rather than an accident of the regex.
- External citations keep working. bbs-land's trees need no change.
- Anyone reading `§A2G` learns nothing about a consumer, which was the
  constraint's actual purpose.

## Reversibility

**Easy.** Renaming later costs a mechanical find-and-replace plus a note to
bbs-land. Nothing depends on the string's content.
