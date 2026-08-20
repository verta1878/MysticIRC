# RIPscrip 3.2 (RIPlib §A2G.8-13) - Language Additions

_Language-visible additions only - what a content creator writing for a `RIPSCRIP032001` terminal can do that a `RIPSCRIP031001` terminal cannot. Everything else is unchanged from [3.1-riplib](../../3.1-riplib/ripscrip/README.md) and, beneath it, the [3.0 reference](../../3.0/ripscrip/README.md); shared terminology is in the [glossary](../../glossary.md)._

These pages are **deltas, not a self-contained reference.** Read [3.0](../../3.0/ripscrip/README.md) for the language, [3.1-riplib](../../3.1-riplib/ripscrip/README.md) for the preceding extension layer, then these for what v3.2 adds. See the [tree README](../README.md) for standing, provenance and the compatibility analysis.

## Source tags

| Tag | Meaning |
| --- | --- |
| `A2G.n` | Stated in RIPlib's v3.2 extension segment, `docs/spec/06a-v32-extensions.md` |
| `spec (seg-N §M)` | Stated elsewhere in RIPlib's specification segments |
| `riplib (path:N)` | Observed in the RIPlib source tree at `~/src/rip-tools/riplib/` |
| ⚠ **Divergence** | Conflicts with the record reconstructed in this repository |

Section numbers follow this repository's chapter scheme (`2.x` drawing, `5.x` host interaction, `9.x` reference), **not** RIPlib's segment numbering; each page names the §A2G section it covers.

## Contents

- **2. Drawing**
  - **[2.0 Drawing State Stack](2.0-state-stack.md)** _(§A2G.8)_ - `|^` pushes and `|~` pops a bounded LIFO snapshot of colors, line/fill/write state, font state, cursor and viewport
  - **[2.1 Radial Gradient](2.1-radial-gradient.md)** _(§A2G.13)_ - a third mode value for the gradient command, and where that command stands in the TeleGrafix record
- **5. Host interaction**
  - **[5.0 `<<DEBUG>>` Directive](5.0-debug-directive.md)** _(§A2G.12)_ - a development log line emitted to the host, joining the 3.x `<<IF>>` / `<<NAME>>` macro layer
- **9. Reference**
  - **[9.0 Additions Reference](9.0-additions-reference.md)** - every v3.2 command, directive and parameter value in one table, each classified
  - **[9.1 Text Variables](9.1-text-variables.md)** _(§A2G.9, §A2G.10, §A2G.11)_ - the twenty-nine new variable names, each checked against the ~120-entry canonical 3.x inventory
