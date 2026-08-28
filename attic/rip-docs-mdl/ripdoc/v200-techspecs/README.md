# RIPscrip 2.00 - Technical Specifications

Original byte-level documentation of the binary file formats and implementation details of the RIPscrip 2.x product family - RIPterm Professional 2.0 through the final **RIPterm 2.30** release, which is treated throughout as the definitive reference. These are original techspecs, not spec conversions: every reverse-engineered claim cites the ALPHA 4 specification section, a recovered document, or an artifact path with observed bytes, and details that could not be verified are marked as such. Note that none of the open-source RIP reference implementations (SyncTERM `ripper.c`, icy_tools, RIPtermJS, PabloDraw) parses the 2.x binary containers documented here - they implement the 1.54 wire language - so these pages are currently the only implementer documentation for these formats.

Chapter numbers align with the [v1.54 techspecs](../../1.54/techspecs/README.md); per the earliest-version rule (see [CONTRIBUTING.md](../../../CONTRIBUTING.md#technical-specifications-techspecs)) these pages are **deltas** - formats already documented for 1.54 are referenced, not repeated, and the [3.0 techspecs](../../3.0/techspecs/README.md) in turn document only their deltas against these pages. Language semantics live in the companion [language reference](../ripscrip/README.md); shared terminology is defined in the [glossary](../../glossary.md).

## Contents

- **1. Parsing & wire protocol**
  - **[1.0 2.x Stream Conventions (delta from 1.54)](1.0-stream-conventions-delta.md)** - the SOH-prefixed `\x01|*` reset opener, prologue/epilogue conventions of the shipped 2.x script corpus, line-length and continuation realities, multi-level command parsing notes
- **2. Rendering semantics**
  - **[2.0 Canvas Tiers, Palette & RGB Rendering](2.0-canvas-palette-rgb.md)** - logical resolution and color tiers, the 256-entry palette and 6-bit DAC value scaling, direct-RGB mode rendering
  - **[2.1 Fill Defects in the Shipping Implementation](2.1-fill-defects.md)** - three defects in TeleGrafix's own fill code: pie and chord fills leaking through boundary gaps, the patterned flood brush that was never applied, and the 1.5x seed-stack drop. What to implement instead, and what it means for content targeting era clients
- **3. File formats**
  - **[3.0 Icons (.BMP / .BMM / .BMH)](3.0-icon-formats.md)** - the BMP-family delta from 1.54 icons: full-BMP reality vs the spec's bare DIB, writer conventions, hot and mask roles
  - **[3.1 JPEG Images (.JPG)](3.1-jpeg-images.md)** - the baseline JFIF profile of shipped content, decoder envelope, scaling/aspect/palette rendering semantics
  - **[3.2 FastFont Outline Fonts (.FF1 / .RFF)](3.2-fastfont-fonts.md)** - both generations of the Atech FastFont format: header, style and kerning layouts, ATF.CFG, and the decoded glyph-outline encoding (offset/width tables, opcode stream, contour closure) needed to rasterize the fonts in software
  - **[3.3 MicroANSI Terminal Fonts (RIPTERM.FNT / .MAF)](3.3-microansi-fonts.md)** - container layout, resolution directory, glyph records
  - **[3.4 Audio (.WAV)](3.4-audio.md)** - the WAVE (PCM) interchange format, RIFF layout, playback semantics
  - **[3.5 UI Resources (.FNT / .IMG)](3.5-ui-resources.md)** - the client's per-resolution system fonts and planar widget images (host-invisible; preserved formats)
- **4. Storage & asset delivery** _(delta from v1.54)_
  - **[4.0 Connection Directory Model (delta)](4.0-connection-directory-model-delta.md)** - the 1.54 model extended to the whole 2.x media family: the default directory now houses `.JPG`/`.WAV`/`.RIP` alongside icons (there was never a separate audio directory); block mode's extension table routes each downloaded type to its proper directory; the manual-dial "System Directory" prompt is the per-connection directory for unlisted hosts

## Primary sources

- The RIPterm 2.30 distribution (`~/src/rip-tools/artifacts/ripterm-2.30/extracted/`, incl. the full `RIPTERM.DOC` manual) and the installed RIPterm Professional 2.0 (`~/src/rip-tools/RIPTerm2.0/extracted/`)
- The byte-exact asset archives under [`version/2.0/assets/`](../../2.0/assets/fonts/README.md)
- Specification: [`RIPScrip-2.0-alpha-4.txt`](../../2.0/text/RIPScrip-2.0-alpha-4.txt) (verbatim) and the [language reference](../ripscrip/README.md) edition
- The RIPtel 3.1 install, for cross-checking the formats the 3.x engine inherited
