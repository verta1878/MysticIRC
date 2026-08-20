# RIPscrip 1.54 - Technical Specifications

Original technical documentation for the binary formats and implementation behaviors of the RIPscrip 1.x family (RIPterm 1.52/1.54, RIPaint 1.52), with **1.54** as the definitive release. These pages are **not** part of TeleGrafix's specification text - they document, correct, and extend it from byte-level evidence, and every reverse-engineered claim is cited; anything unverifiable is marked as such.

Language semantics are not repeated here - see the companion [language reference](../ripscrip/README.md); shared terminology is defined in the [glossary](../../glossary.md). Formats are documented in the earliest version where they appear (see [CONTRIBUTING.md](../../../CONTRIBUTING.md#technical-specifications-techspecs)); the [2.0](../../2.0/techspecs/README.md) and [3.0](../../3.0/techspecs/README.md) techspecs document only deltas and link back to these pages.

## Contents

- **1. Parsing & wire protocol**
  - **[1.0 `.RIP` Stream & File Parsing](1.0-rip-stream-parsing.md)** - byte-level line structure, continuation, escaping, embedded ANSI handling, prologue/epilogue conventions in real files, wild-data hazards (the RIP_LOAD_ICON `res` field)
  - **[1.1 MegaNum Encoding](1.1-meganum-encoding.md)** - digit set, fixed widths per parameter, signedness, implemented edge cases (lowercase, `-` as digit 0, early termination, invalid input)
- **2. Rendering semantics**
  - **[2.0 Canvas, Clipping & Write Modes](2.0-canvas-clipping-write-modes.md)** - viewport clipping behavior, copy/XOR write modes on palette indices, the put-mode family for images, reset semantics
  - **[2.1 Pattern & Fill Rasterization](2.1-pattern-fill-rasterization.md)** - line-pattern anchoring, fill-pattern semantics and alignment, flood-fill behavior, style-0 questions
- **3. File formats**
  - **[3.0 Icon Format (`.ICN` / `.MSK` / `.HIC`)](3.0-icon-format.md)** - byte layout, plane merging, size formula (two trash bytes), mask semantics, worked decode
  - **[3.1 BGI Stroked Fonts (`.CHR`)](3.1-bgi-stroked-fonts.md)** - header, stroke opcodes, metrics, size→scale ratios, RIP font-number mapping
  - **[3.2 Bitmap Fonts (`RIPTERM.FNT`)](3.2-bitmap-fonts.md)** - container layout, charset directory, glyph rasterization and magnification
- **4. Storage & asset delivery**
  - **[4.0 Connection Directory Model](4.0-connection-directory-model.md)** - the storage layout an implementation needs: a per-connection (system) asset directory plus the shared default icons directory; resolution order is connection directory first, then default ("file override" - same-named files from different hosts must not collide); downloads are written to the connection's directory when one is specified, else the default; directory auto-creation on first use; all asset access is case-insensitive, by whatever scheme the client prefers (index, lowercasing, or other); filename sanitization still applies (bare names, no path components - reject traversal)

## Primary sources

- Specification: [`RIPScrip-1.54.txt`](../../1.54/text/RIPScrip-1.54.txt) (verbatim) and the [language reference](../ripscrip/README.md) edition
- Original binaries: [`version/1.54/assets/fonts/`](../../1.54/assets/fonts/README.md) (10 `.CHR` + `RIPTERM.FNT`) and [`version/1.54/assets/icons/`](../../1.54/assets/icons/README.md) (184 `.ICN`), plus the full RIPterm 1.54 install (`~/src/rip-tools/RIPterm154/DOS/RIPTERM/`, incl. `.MSK`/`.HIC` files and `RIPTERM.DOC`) and the RIPaint 1.52 distribution (`~/src/rip-tools/artifacts/ripaint-1.52/RIPAINT.ZIP`, incl. sample `.RIP` scenes and `RIPAINT.HLP`)
- Reference implementations: `sbbs:src/syncterm/ripper.c` (SyncTERM), `RIPtermJS:src/BGI.js` / `src/ripterm.js`, `icy_tools:crates/icy_parser_core/src/rip/`, `pablodraw:Source/Pablo/Formats/Rip/` - catalogued in [reference/rip-tools.md](../../../reference/rip-tools.md)
