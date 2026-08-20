# RIPscrip 3.0 - Language Reference (reconstructed record)

**RIPscrip 3.0** - the third-generation Remote Imaging Protocol scripting language (TeleGrafix Communications, Inc., 1996-1997), as shipped in **RIPtel Visual Telnet 3.1** (RIPscrip driver 3.0.7), the only client that ever shipped it. Chapter numbers align with the [2.0 reference](../../2.0/ripscrip/README.md) the generation evolved from, with the 3.x-era changes flattened into their proper sections and sections unique to this generation marked; the official [3.0 Technical White Paper](../text/RIPScrip-3.x-technical-whitepaper.txt) (December 1996, by Jeff Reeder - prose only, the sole TeleGrafix document for the generation) is preserved separately as a faithful conversion.

_Content-creator reference for the 3.x generation - entirely a reconstruction with per-claim evidence tags; binary layouts and parser edge cases live in the companion [technical specifications](../techspecs/README.md), shared terminology in the [glossary](../../glossary.md)._

**Self-contained for creators:** unlike the delta-based techspecs, each version's `ripscrip/` docs stand alone - a creator working against 3.x reads only these pages. Material carried forward from the prior generation is merged in (the reconstructed 3.x sources are often sparser than their 2.0 counterparts), with "as in 2.0" references pointing at the [v2.0 reference](../../2.0/ripscrip/README.md); deeper 1.54 lineage resolves through the [v1.54 reference](../../1.54/ripscrip/README.md).

## Evidence legend

TeleGrafix never published a RIPscrip 3.x language reference, so this edition is an **editorial reconstruction**: every section and command entry carries an evidence tag naming its sources.

| Tag | Meaning |
| --- | --- |
| `2.00a4` | Documented in the RIPscrip 2.00 alpha 4 specification, which 3.x inherits (merged here from the [v2.0 reference](../../2.0/ripscrip/README.md)) |
| `WP` | Stated in the official [3.0 Technical White Paper](../text/RIPScrip-3.x-technical-whitepaper.txt) |
| `HLP` | Recovered from the RIPtel 3.1 help files / RIPSCRIP.DLL string table |
| `corpus (FILE)` | Observed in the RIPtel 3.1 demo scripts (116 authentic TeleGrafix RIPscrip 3.0 files) |
| `SyncTERM (ripper.c:N)` | Behavior of SyncTERM's open-source RIP 3.0 implementation |
| _(hypothesis)_ | Editorial inference - plausible but unconfirmed |

Underlying research (full data, byte layouts, opcode census): [script census](../../3.0/research/riptel-script-census.md) · [help-file extraction](../../3.0/research/riptel-help-extraction.md) · [binary formats](../../3.0/research/riptel-binary-formats.md)

## Contents

- **1. Fundamentals**
  - **[1.0 Introduction](1.0-introduction.md)** - the 3.x generation, reconstruction status and evidence model, engine lineage from 2.0
  - **[1.1 Protocol & Command Hierarchy](1.1-protocol-and-command-hierarchy.md)** - syntax, levels, auto-sensing (`RIPSCRIP03000…`)
  - **[1.2 Math & Coordinates](1.2-math-and-coordinates.md)** - MegaNums, UltraNums, field widths, world coordinates, resolution-independence goals vs shipped reality
  - **[1.3 World View & Virtual Canvas](1.3-world-view-virtual-canvas.md)** - ports and world coordinates as carried into 3.x (concept level; mechanics in chapter 7)
  - **[1.4 Terminal & ANSI View](1.4-terminal-ansi-view.md)** - text windows (up to 36 defined, one active), grids, ANSI routing
- **2. Drawing**
  - **[2.0 Color Modes & Palettes](2.0-color-modes-and-palettes.md)** - the color system as shipped in RIPtel
  - **[2.1 Lines](2.1-lines.md)** - pixel, line, polyline; line patterns and thickness
  - **[2.2 Curves](2.2-curves.md)** - circle, oval, arc, oval arc, bezier, plus the 3.x skewed-oval family from the script census
  - **[2.3 Shapes & Fills](2.3-shapes-and-fills.md)** - rectangle, bar, polygon and filled variants; fill patterns; RIP_FILL, marked **[deprecated](../techspecs/2.0-fill-defects-delta.md)** - missing from the RIPSCRIP.HLP inventory and the RIPtel corpus, yet still a live codepath in RIPSCRIP.DLL 3.0.7, with SyncTERM's legacy behavior noted as a compatibility divergence
- **3. Text**
  - **[3.0 Text Output & Fonts](3.0-text-output-and-fonts.md)** - graphics text, outline fonts (eight RFF families)
  - **[3.1 Column Text System](3.1-column-text-system.md)** _(new in this generation)_ - the column-based text layout system discovered in the RIPtel corpus
- **4. Media & interactive objects**
  - **[4.0 Icons & Bitmaps](4.0-icons-and-bitmaps.md)** - BMP icons and hot states as carried forward; legacy `.ICN` conversion behavior
  - **[4.1 JPEG Images](4.1-jpeg-images.md)** - image placement and scaling as carried forward, including GrayPEG notes
  - **[4.2 Mouse Fields & Pointer](4.2-mouse-fields-and-pointer.md)** - mouse fields, pointer control, the added hover modes
  - **[4.3 Buttons](4.3-buttons.md)** - button styles and behavior as carried into RIPtel
  - **[4.4 Tone & Sound Generation](4.4-tone-and-sound-generation.md)** - waveform-style speaker sounds as carried forward (`$BEEP$`, `$BLIP$`, `$T$` tone sequences, `$MUSIC$`)
  - **[4.5 Audio Files (WAV)](4.5-audio-files.md)** - WAV playback as carried forward; distinct from tone generation (4.4) and from the local-playback trigger mechanism (5.3)
- **5. Host interaction & dynamics**
  - **[5.0 Host Commands](5.0-host-commands.md)** - host-bound text, control characters, what goes where
  - **[5.1 Text Variables](5.1-text-variables.md)** - the full variable system including persistence (the key/value store abstraction)
  - **[5.2 Templates & Conditionals](5.2-templates-and-conditionals.md)** _(extended in this generation)_ - templates plus the `<<IF>>` conditional macro layer
  - **[5.3 Local File Playback](5.3-local-playback.md)** - the playback-prefix mechanism spanning media types (`$>file.rip$`, `$(file.JPG$`, `$)FILE.WAV$`), with worked examples per prefix and a comparison against the dedicated chapter-4 commands (command-stream vs host-command/macro-layer invocation)
  - **[5.4 Pop-Up Lists](5.4-popup-lists.md)** - host-defined selection lists, with worked examples of definition and response flow
  - **[5.5 File Transfer & Queries](5.5-file-transfer-and-queries.md)** - file query and delete, block-mode transfer, capability negotiation
- **6. Authoring & files**
  - **[6.0 Writing 3.x .RIP Files](6.0-writing-rip-files.md)** - authoring conventions of the RIPtel corpus, including the script containers `.RIP`/`.FN`/`.COL`
  - **[6.1 Content File Roles](6.1-content-file-roles.md)** - the 3.x content file family and how hosts deliver it
  - **[6.2 Asset Delivery & Storage](6.2-asset-delivery-and-storage.md)** - asset download triggering and storage as carried into RIPtel: file query/delete, block-mode transfer, the per-connection (bookmark) host directory vs the default icon directory, connection-directory-first lookup; downloads go to the connection's directory when specified
- **7. Ports, tables & backup areas**
  - **[7.0 Drawing Ports](7.0-drawing-ports.md)** - port creation, switching, state; multi-port composition
  - **[7.1 Data Tables](7.1-data-tables.md)** - table definition, cells, host/terminal data exchange
  - **[7.2 Data Backup Areas](7.2-data-backup-areas.md)** - off-screen save/restore areas
- **9. Reference** _(pinned at 9 across all versions)_
  - **[9.0 Command Reference](9.0-command-reference.md)** - the reconstructed ~90-command inventory with evidence tags, including known-but-unimplemented descriptors
  - **[9.1 Text Variable Reference](9.1-text-variable-reference.md)** - every variable with format, category and availability
  - **[9.2 Version Identification Reference](9.2-versions.md)** - all known 3.0 identification strings (`RIPSCRIP03000` from the HLP quote, `RIPSCRIP030001` from SyncTERM) with provenance, plus the `$RIPVER$` documentation oddity
  - **[9.3 Host Command & Control Character Reference](9.3-host-command-reference.md)** - consolidated terminal→host reference: control characters, host-bound responses, host-side ANSI control
