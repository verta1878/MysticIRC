# RIPscrip 3.1 (RIPlib §A2G.1-7) - Technical Specifications

_Implementation-level additions only - parser behavior, rasterization, and framebuffer/palette integration. Language-visible changes are in the companion [language additions](../ripscrip/README.md); see the [tree README](../README.md) for standing, provenance and the alignment caveats._

**These pages are deltas.** Formats and rendering behavior are documented in the earliest version where they appear ([CONTRIBUTING.md](../../../CONTRIBUTING.md#technical-specifications-techspecs)), so the underlying material lives in the [1.54 techspecs](../../1.54/techspecs/README.md) (stream parsing, MegaNum, pattern fill, stroke fonts) and the [2.0](../../2.0/techspecs/README.md) / [3.0](../../3.0/techspecs/README.md) trees. Only what §A2G.1-7 changes is recorded here.

Two of the three pages document things RIPlib presents as protocol extensions but which are, on inspection, rendering-quality and host-integration work: they change how output looks, not what the wire carries. That is worth stating plainly, because it is the clearest structural difference between the two documentation efforts - RIPlib's specification describes one implementation, so implementation choices and protocol definition sit side by side in it.

**Baseline conflicts are elsewhere.** Where the two projects disagree about RIPscrip 3.0 itself rather than about an extension - the escape set, the alternate command introducers, the fill-pattern mapping - the item is in [3.0-riplib/techspecs/](../../3.0-riplib/techspecs/README.md), and these pages point there.

## Source tags

| Tag | Meaning |
| --- | --- |
| `A2G.n` | Stated in RIPlib's v3.1 extension segment, `docs/spec/06-v31-extensions.md` |
| `spec (seg-N §M)` | Stated elsewhere in RIPlib's specification segments |
| `riplib (path:N)` | Observed in the RIPlib source tree at `~/src/rip-tools/riplib/` |
| ⚠ **Divergence** | Conflicts with the record reconstructed in this repository |

## Contents

- **1. Parsing & wire protocol**
  - **[1.0 Stream Parsing Delta](1.0-stream-parsing-delta.md)** - the relaxed `!` command-trigger rule after ANSI CSI terminators, the `\!` escape, and how both compare with the SOH/STX introducer the specification already provides
- **2. Rendering semantics**
  - **[2.0 Fill Patterns & FPU Rendering](2.0-fill-patterns-and-rendering.md)** _(§A2G.4, §A2G.5)_ - the built-in 8×8 pattern table and its wire mapping, and the floating-point replacements for Bezier subdivision, trigonometry and pie fill
  - **[2.1 Palette Index Mapping](2.1-palette-index-mapping.md)** _(§A2G.6)_ - relocating the EGA 16-color palette to framebuffer indices 240-255 so RIPscrip graphics and xterm-256 text share one indexed framebuffer

## Primary sources

- `~/src/rip-tools/riplib/docs/spec/` - segments 01 (wire format), 02 (Level 0 drawing), 10 (appendices) and 11 (DLL deviations) carry the v3.1 annotations; `06-v31-extensions.md` is the extension segment itself
- `~/src/rip-tools/riplib/src/drawing.c` and `src/ripscrip.c` - the implementation the segments describe
- Reconciled against riplib `main` @ `3e05ecb` (2026-06-30); refresh per [reference/rip-tools.md](../../../reference/rip-tools.md#riplib-is-a-moving-target---pull-main-regularly) before editing
