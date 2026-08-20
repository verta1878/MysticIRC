# Historical RIPscrip Protocol Documents

These are the original TeleGrafix Communications protocol documents
preserved for historical reference. They are NOT part of the v3.1
specification — see `docs/spec/` for the current complete reference.

## Files

| Document | Version | Year | Description |
|----------|---------|------|-------------|
| `RIPSCRIP_v154.DOC` | v1.54 | 1993 | Original specification. Defines Level 0 + Level 1 commands, MegaNum encoding, frame format. Binary .DOC format. |
| `RIPSCRIP_v2A4.PRN` | v2.0 Rev 2.A4 | ~1995-96 | Extended specification. Defines Drawing Ports, extended commands, coordinate systems, data tables. Plain text. |
| `ripscrip-v3-RE-notes.md` | v3.0 | 2026 | **Restored 2026-08-12.** The reverse-engineering record for RIPscrip 3.0, derived from binary analysis of RIPSCRIP.DLL 3.0.7. Retired in commit `5a76df8` on the assumption that `docs/spec/11-dll-deviations.md` superseded it; that roll-up proved lossy, replacing sourced findings with unsourced summaries, so several segment-11 claims became uncheckable. This document is the **substrate** those segments cite. |

## Copyright

The v1.54 and v2.0 documents are Copyright (c) 1993-1997
TeleGrafix Communications, Inc. Preserved here for historical
reference and interoperability purposes.

The v3.0 RE notes are original analysis work, Copyright (c) 2026
SimVU (Brad Hawthorne).

## Current Specification

For the complete, authoritative protocol reference covering all
versions (v1.54 through v3.1), see:

    docs/spec/01-wire-format.md      through
    docs/spec/13-dll-command-table.md

The specification is standalone for *implementation* — a compliant
client can be built from `docs/spec/` alone. It is not standalone for
*verification*: segments 11, 12 and 13 make claims about a specific
binary, and those claims are grounded in the RE notes above plus the
artifact itself. Regenerate the binary-derived data with:

    python scripts/dll-provenance.py    <path>/Ripscrip.dll
    python scripts/dll-dispatch-table.py <path>/Ripscrip.dll

Both scripts verify the artifact fingerprint (MD5
`bade8b1f4e467ac7ad4edb2639738d4c`, 592,896 bytes) before reporting,
because every address recorded in those segments is valid only for
that exact image.
