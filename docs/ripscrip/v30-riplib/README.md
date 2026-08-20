# RIPscrip 3.0 - RIPlib baseline comparison (implementation level)

_Conflicts between [RIPlib](https://github.com/BradHawthorne/riplib)'s account of RIPscrip 3.0 and the record here, at the implementation level: parsing rules and rasterization behavior that no wire syntax expresses. Language-level conflicts are in the companion [language pages](../ripscrip/README.md)._

These are deltas against the [1.54](../../1.54/techspecs/README.md), [2.0](../../2.0/techspecs/README.md) and [3.0](../../3.0/techspecs/README.md) techspecs, which hold the material both projects are describing. See the [tree README](../README.md) for how each side's evidence should be weighed, and the same disposition legend used on the language pages (**callable** · **open** · **compatible**).

## Contents

- **1. Parsing & wire protocol**
  - **[1.0 Stream Parsing & Escapes](1.0-stream-parsing-and-escapes.md)** - which backslash escapes the specification actually defines and which are extensions, and the alternate `SOH`/`STX` command introducers
- **2. Rendering semantics**
  - **[2.0 Fill Pattern Mapping](2.0-fill-pattern-mapping.md)** - wire pattern IDs to built-in patterns, the semantics of pattern `00`, and the pattern bitmaps themselves

## Not in scope here

- **RIPlib's own rendering extensions** - the complete pattern set (§A2G.4), floating-point curves and pie fill (§A2G.5), and the palette index relocation (§A2G.6) are documented with the revision that introduced them, in [3.1-riplib/techspecs/](../../3.1-riplib/techspecs/README.md)
- **Defects RIPlib found and fixed correctly** - the pie/chord flood-fill leak and the never-applied patterned-flood brush are real defects in the TeleGrafix implementation, and have been folded into this repository's own techspecs rather than recorded as conflicts: see [2.0 fill defects](../../2.0/techspecs/2.1-fill-defects.md) and the [3.0 delta](../../3.0/techspecs/2.0-fill-defects-delta.md)
