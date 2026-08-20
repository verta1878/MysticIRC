# RIPscrip 2.00 - Language Reference

**Source specification: "RIPscrip Graphics Protocol Language Technical Reference", Version 2.00 - Revision ALPHA 4** (proposed enhancements), December 13th, 1994, TeleGrafix Communications, Inc. - the last published 2.x document, preserved verbatim as [`RIPScrip-2.0-alpha-4.txt`](../../2.0/text/RIPScrip-2.0-alpha-4.txt). The definitive implementation is **RIPterm 2.30**, the final 2.x release. The record for this generation is **partially unknown**: the shipping engine moved beyond the draft and no further specification was ever published, so parts of what follows come from reconstruction against shipped binaries and content. Where engine and draft diverge, these pages document the engine; the draft's reading and the evidence behind every correction are recorded in [Errata](errata.md).

Content-creator documentation for the 2.x generation. Chapter numbers align with [v1.54](../../1.54/ripscrip/README.md) where the concept exists; chapter 7 is new to this generation. Binary layouts and parser edge cases live in the companion [technical specifications](../techspecs/README.md); shared terminology is defined in the [glossary](../../glossary.md).

**Self-contained for creators:** unlike the techspecs (which stay delta-based and cross-reference other version directories), each version's `ripscrip/` docs stand alone - a creator working against 2.x reads only these pages. Material carried forward from the prior generation is merged in, with "as in 1.54" references pointing at the [v1.54 reference](../../1.54/ripscrip/README.md) for lineage.

## Contents

- **1. Fundamentals**
  - **[1.0 Introduction](1.0-introduction.md)** - the 2.x redesign, the specification's own introduction and licensing terms, revision history
  - **[1.1 Protocol & Command Hierarchy](1.1-protocol-and-command-hierarchy.md)** - the expanded multi-level command set, syntax, escaping, auto-sensing (`RIPSCRIP020000`), protocol-level commands (RIP_HEADER, RIP_NO_MORE, comments, groups)
  - **[1.2 Math & Coordinates](1.2-math-and-coordinates.md)** - MegaNums, UltraNums and Base Math with by-hand encode/decode, field widths, world-coordinate math, coordinate conversions
  - **[1.3 World View & Virtual Canvas](1.3-world-view-virtual-canvas.md)** - world coordinates as the logical drawing space, viewports mapping onto the screen, the port model at concept level (full port mechanics in chapter 7)
  - **[1.4 Terminal & ANSI View](1.4-terminal-ansi-view.md)** - text windows (standard and extended), ANSI routing, text grids
- **2. Drawing**
  - **[2.0 Color Modes & Palettes](2.0-color-modes-and-palettes.md)** - 16-color, 256-color and direct-RGB modes; the 256-entry palette; palette commands; write modes
  - **[2.1 Lines](2.1-lines.md)** - pixel, line, polyline; line patterns and thickness as they extend the 1.54 model
  - **[2.2 Curves](2.2-curves.md)** - circle, oval, arc, oval arc, bezier, poly-bezier
  - **[2.3 Shapes & Fills](2.3-shapes-and-fills.md)** - rectangle, bar, polygon and filled variants; fill patterns; borders; RIP_FILL, marked **[deprecated](../techspecs/2.1-fill-defects.md)**, with the filled-object replacements
- **3. Text**
  - **[3.0 Text Output & Fonts](3.0-text-output-and-fonts.md)** - graphics text, stroked fonts, the extended (outline) font style, font directions, text regions as carried forward
- **4. Media & interactive objects**
  - **[4.0 Icons & Bitmaps](4.0-icons-and-bitmaps.md)** - BMP icons, masks and hot bitmaps as content roles; clipboard operations; block moves
  - **[4.1 JPEG Images](4.1-jpeg-images.md)** - RIP_IMAGE / RIP_IMAGE_STYLE, the image area, scaling and aspect flags
  - **[4.2 Mouse Fields & Pointer](4.2-mouse-fields-and-pointer.md)** - mouse fields, pointer control
  - **[4.3 Buttons](4.3-buttons.md)** - button styles and behavior as extended in 2.x (world-coordinate placement, hot bitmaps, style slots)
  - **[4.4 Tone & Sound Generation](4.4-tone-and-sound-generation.md)** - waveform-style speaker sounds carried from 1.54 and extended: parameterized `$BEEP(freq,ms)$`/`$BLIP$`, the chainable `$T$` tone variable for continuous multi-frequency sequences, canned `$MUSIC(count)$`
  - **[4.5 Audio Files (WAV)](4.5-audio-files.md)** - background WAV playback via RIP_PLAY_AUDIO, `$OFF$` stop, reset interaction, capability negotiation; distinct from tone generation (4.4) and from the local-playback trigger mechanism (5.3)
- **5. Host interaction & dynamics**
  - **[5.0 Host Commands](5.0-host-commands.md)** - host-bound text, control characters, what goes where, the refresh sequence
  - **[5.1 Text Variables](5.1-text-variables.md)** - the expanded variable system: general, date/time, sound (pointer to 4.4), mouse, window, ports, terminal, reset, environment, clipboard, screen, tables
  - **[5.2 Templates](5.2-templates.md)** - host command templates
  - **[5.3 Local File Playback](5.3-local-playback.md)** - the playback-prefix mechanism spanning media types: `$>file.rip$` (scripts), `$<file.BMP$` (bitmaps), `$(file.JPG$` (images), `$)FILE.WAV$` (audio), with worked examples per prefix and the command-stream vs host-command-layer comparison
  - **[5.4 Pop-Up Lists](5.4-popup-lists.md)** - host-defined selection lists, with a worked example of definition and response flow
  - **[5.5 File Transfer & Queries](5.5-file-transfer-and-queries.md)** - file query, block-mode transfer, UU-encoded blocks, timing commands, capability negotiation (`$IFS$`, `$TERMINFO()$`)
- **6. Authoring & files**
  - **[6.0 Writing 2.x .RIP Files](6.0-writing-rip-files.md)** - authoring conventions as they changed from 1.54 (SOH reset opener, prologues and epilogues in the shipped corpus)
  - **[6.1 Content File Roles](6.1-content-file-roles.md)** - what `.BMP`/`.BMM`/`.BMH`/`.JPG`/`.WAV` files are for and how hosts deliver them
  - **[6.2 Asset Delivery & Storage](6.2-asset-delivery-and-storage.md)** - RIP_FILE_QUERY plus block-mode transfer with its extension routing table; downloads go to the system connection's directory when configured (RIPterm 2.30 also prompts for a "System Directory" on one-off manual dials), else the default `ICONS\`, which in this generation houses `.JPG`/`.WAV`/`.RIP` alongside icons; lookup remains connection-directory-first, then default
- **7. Ports, tables & backup areas** _(new in this generation)_
  - **[7.0 Drawing Ports](7.0-drawing-ports.md)** - port creation, switching, state; multi-port composition
  - **[7.1 Data Tables](7.1-data-tables.md)** - table definition, cells, host/terminal data exchange
  - **[7.2 Data Backup Areas](7.2-data-backup-areas.md)** - off-screen save/restore areas
- **9. Reference** _(pinned at 9 across all versions)_
  - **[9.0 Command Reference](9.0-command-reference.md)** - every command across levels 0-9: level, code, arguments and field widths, spec revision introduced
  - **[9.1 Text Variable Reference](9.1-text-variable-reference.md)** - every variable with format, category and availability
  - **[9.2 Version Identification Reference](9.2-versions.md)** - all known 2.x identification strings (`RIPSCRIP020000` across every shipping engine) with per-binary provenance
  - **[9.3 Host Command & Control Character Reference](9.3-host-command-reference.md)** - consolidated terminal→host reference: control characters, host-bound responses, host-side ANSI control
- **[Errata](errata.md)** - where the ALPHA 4 draft and the shipping RIPterm engine disagree, the evidence, and how each chapter above resolves it
