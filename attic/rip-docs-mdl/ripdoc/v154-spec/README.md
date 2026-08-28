# RIPscrip 1.54 - Language Reference

**"Remote Imaging Protocol" - Revision 1.54** (July 19th, 1993), TeleGrafix Communications, Inc. - the widely deployed classic standard, fully documented by TeleGrafix's published specification and implemented by RIPterm 1.54. The verbatim source document is preserved as [`RIPScrip-1.54.txt`](../../1.54/text/RIPScrip-1.54.txt); this edition reorganizes it and, where the spec is wrong or silent, corrects it in clearly-marked editor's notes.

_Content-creator reference; binary layouts and parser edge cases live in the companion [technical specifications](../techspecs/README.md), shared terminology in the [glossary](../../glossary.md)._

## Contents

- **1. Fundamentals**
  - **[1.0 Introduction](1.0-introduction.md)** - what RIPscrip is, design goals, capabilities, product and naming context
  - **[1.1 Protocol & Command Hierarchy](1.1-protocol-and-command-hierarchy.md)** - the `!|` line form, `|` delimiter, command levels 0/1, escaping (`\|`, `\\`), line continuation, auto-sensing overview
  - **[1.2 Math & Coordinates](1.2-math-and-coordinates.md)** - MegaNum base-36 numbers with worked encode/decode, field widths, the fixed 640×350 EGA coordinate space, aspect considerations
  - **[1.3 World View & Virtual Canvas](1.3-world-view-virtual-canvas.md)** - the graphics window as the drawing surface, viewport definition and clipping, reset semantics
  - **[1.4 Terminal & ANSI View](1.4-terminal-ansi-view.md)** - the text window, ANSI/text routing and coexistence with graphics, the hidden text window
- **2. Drawing**
  - **[2.0 Colors & Attributes](2.0-colors-and-attributes.md)** - the 16-color EGA palette, color selection, background/foreground attributes, write modes
  - **[2.1 Lines](2.1-lines.md)** - pixel, line, polyline; line patterns and thickness
  - **[2.2 Curves](2.2-curves.md)** - circle, oval, arc, oval arc, bezier
  - **[2.3 Shapes & Fills](2.3-shapes-and-fills.md)** - rectangle, bar, polygon and filled variants; fill patterns (stock and user-defined); flood fill (documented here only - removed from the language in later generations)
- **3. Text** _(own chapter - sparse in 1.54, but text and font structures grow substantially in later generations)_
  - **[3.0 Text Output & Fonts](3.0-text-output-and-fonts.md)** - graphics-window text, font styles 0-10 (bitmap and stroked), sizes, directions
  - **[3.1 Text Regions](3.1-text-regions.md)** - defining and using text regions within the graphics window
- **4. Media & interactive objects** _(no audio **files** in 1.54 - file-based audio begins in the 2.x generation; speaker tone generation exists here)_
  - **[4.0 Images & Icons](4.0-images-and-icons.md)** - clipboard copy/paste (scissors), loading and stamping icon files, masks and hot icons as content roles
  - **[4.1 Mouse Fields](4.1-mouse-fields.md)** - clickable regions, host-command emission, invert/reset behavior
  - **[4.2 Buttons](4.2-buttons.md)** - button styles, faces (plain/icon/clipboard), groups, hot icons
  - **[4.3 Tone & Sound Generation](4.3-tone-and-sound-generation.md)** - waveform-style speaker sounds via the Active Text Variables (`$BEEP$`, `$BLIP$`, `$MUSIC$`, …), each a defined frequency/delay sequence a host can trigger
- **5. Host interaction & dynamics**
  - **[5.0 Host Commands & Control Characters](5.0-host-commands.md)** - what the terminal sends back, control-character handling
  - **[5.1 Text Variables](5.1-text-variables.md)** - `$NAME$` substitution, built-in variables, creation and querying
  - **[5.2 Host Command Templates](5.2-host-command-templates.md)** - parameterized host command definition and invocation
  - **[5.3 Local File Playback](5.3-local-playback.md)** - playing local `.RIP` files on host command (`$>file.rip$`) with worked examples of the host-command flow; the mechanism chapter that the media commands in chapter 4 cross-reference
  - **[5.4 Pop-Up Lists](5.4-popup-lists.md)** - host-defined selection lists
  - **[5.5 Queries & Advanced Commands](5.5-queries-and-advanced-commands.md)** - file queries, terminal state queries, remaining level-1 miscellany
- **6. Authoring & files**
  - **[6.0 Writing .RIP Files](6.0-writing-rip-files.md)** - authoring-level file conventions: line length, continuation, mixing ANSI and text, prologue conventions, CP437
  - **[6.1 Content File Roles](6.1-content-file-roles.md)** - what `.ICN`/`.MSK`/`.HIC` files are for and how hosts deliver them
  - **[6.2 Asset Delivery & Storage](6.2-asset-delivery-and-storage.md)** - how a host gets assets onto the terminal: RIP_FILE_QUERY staleness check, then RIP_ENTER_BLOCK_MODE download; where files land - the system connection's directory when one is configured for the host (downloads go there), else the default `ICONS\`; lookup order is connection directory first, then the default ("file override")
- **9. Reference** _(pinned at 9 across all versions)_
  - **[9.0 Command Reference](9.0-command-reference.md)** - every command: level, code, arguments and field widths, one-line purpose, section cross-reference
  - **[9.1 Text Variable Reference](9.1-text-variable-reference.md)** - every text variable with format and availability
  - **[9.2 Version Identification Reference](9.2-versions.md)** - all known 1.5x identification strings (auto-sense replies and `$RIPVER$`), with provenance
  - **[9.3 Host Command & Control Character Reference](9.3-host-command-reference.md)** - consolidated terminal→host reference: control characters and host-bound sequences
