# Errata

[◀ Prev: 9.3 Host Command & Control Character Reference](9.3-host-command-reference.md) · [Contents](README.md)

Where the ALPHA 4 draft and the shipping RIPterm engine disagree, what the evidence is, and how each chapter above resolves it - the historical record behind every correction applied to this edition. The chapter pages state implementation truth without qualification; this page is where the qualification lives.

## Spec status: the ALPHA 4 draft vs the shipping engine

The 2.00 ALPHA 4 draft (December 13th 1994) is the last published 2.x specification - TeleGrafix never issued a final 2.0 document. Three shipping clients exist: RIPterm Professional 2.0 (January 1995), 2.20.01, and RIPterm 2.30 (binaries dated October 1997, despite 236 carried-forward support files from the 1995-11 vintage). All three implement the language substantially as drafted, but diverge from it in specific, documented places, and this reference's chapter pages document the engine, not the draft, at every point of divergence. The entries below are grouped by chapter; each names the draft's text, the shipped or corrected reality and its evidence, and the reference page section that already reflects it.

## 1.1 Protocol & Command Hierarchy

### Auto-sense response is fixed at `RIPSCRIP020000`

**What the draft says:** the `ESC[!` auto-sense query returns `RIPSCRIPxxyyvs`, where `xx`/`yy` are the major/minor version and `v`/`s` are vendor and sub-version codes - a formula, not a fixed string (draft lines 3840-3841).

**What shipped:** every shipping 2.x-generation RIPterm binary - Professional 2.0, 2.20.01, and 2.30 - carries the identical literal auto-sense response `RIPSCRIP020000`: version 02.00 with the vendor and sub-version digits zeroed, byte-verified by `strings` across all three recovered `RIPTERM.EXE` installs (see the provenance table in [CONTRIBUTING.md](../../../CONTRIBUTING.md)). The reported language level never advanced past 2.00.00 through the end of the RIPterm line in October 1997, even as the product versions moved 2.0 -> 2.20 -> 2.30; RIPterm 2.30's own documentation states it "supports the RIPscrip 2.0 language fully" (RIPTERM.FAQ v1.7).

**How the reference page renders it:** [1.1's ANSI Sequences (Auto-Sensing) section](1.1-protocol-and-command-hierarchy.md#ansi-sequences-auto-sensing) keeps the draft's general formula (it is still how a client should be written) and the vendor-code table is correct for whatever a future vendor might report; the fixed shipped value is the empirical constant every existing client actually sends. The full per-binary breakdown lives at [9.2 Version Identification Reference](9.2-versions.md#known-2x-generation-identification-strings).

## 1.2 Math & Coordinates

### RIP_SET_BASE_MATH and RIP_EXTENDED_TEXT_WINDOW: the level-0 `b` collision

**What the draft says:** level-0 command `b` is assigned to RIP_SET_BASE_MATH (draft line 7246, `Command: b`) and, separately, to [RIP_EXTENDED_TEXT_WINDOW](1.4-terminal-ansi-view.md#rip_extended_text_window) - an unresolved collision the draft never notices.

**What shipped:** the shipping engine resolved the collision by moving RIP_SET_BASE_MATH to level-0 **`J`**, leaving `b` for the extended text window. This is confirmed by the RIPtel demo corpus, where `J10` opens 90 of 116 TeleGrafix-authored scripts, annotated in TeleGrafix's own comments as "Set base math to MegaNums (base 36)". See the [3.x entry](../../3.0/ripscrip/1.2-math-and-coordinates.md#rip_set_base_math) for the same resolution documented against the later corpus.

**How the reference page renders it:** [1.2's RIP_SET_BASE_MATH entry](1.2-math-and-coordinates.md#rip_set_base_math) still prints the draft's command table, Format and Example using `b` - see "Body fixes required" below; this is one of the two places this edition has not yet caught up with its own corrected fact.

## 1.3 World View & Virtual Canvas

### RIP_SET_DRAWING_FRAME never existed

**What the draft says:** the v2.A0 revision-history paragraph, reproduced in [1.3's RIP_VIEWPORT discussion](1.3-world-view-virtual-canvas.md#rip_viewport), instructs authors to "use the RIP_SET_DRAWING_FRAME command after setting the viewport" to change the Drawing Frame resolution.

**What's correct:** no such command was ever specified. It does not appear anywhere in the ALPHA 4 draft's command reference, revision-controlled or otherwise - it was dropped before ALPHA 4 without a corresponding removal note. In practice the viewport's 1:1 world-coordinate mapping, already described in the same paragraph, is the only drawing-frame behavior that is actually defined; there is no mechanism to change it.

**How the reference page renders it:** the RIP_VIEWPORT section keeps the draft's paragraph verbatim (it is otherwise accurate and the 1:1 mapping explanation is load-bearing), but the dangling command reference needs a caveat sentence - see "Body fixes required" below.

## 1.4 Terminal & ANSI View

### RIP_SET_BASE_MATH and RIP_EXTENDED_TEXT_WINDOW: the level-0 `b` collision (cross-reference)

Same collision as the [1.2 entry above](#rip_set_base_math-and-rip_extended_text_window-the-level-0-b-collision): the draft assigns `b` to both commands; the shipping engine kept `b` for [RIP_EXTENDED_TEXT_WINDOW](1.4-terminal-ansi-view.md#rip_extended_text_window) and moved RIP_SET_BASE_MATH to `J`. Unlike 1.2, this page's own Command/Format/Example already show the correct, shipped value (`b`) for this command - no body fix is needed here.

### Text windows and terminal emulation: an unfinished placeholder

**What the draft says:** section 1.4's "Text Windows and Terminal Emulation Protocols" is a bare stub: `[BEGIN REWORD] Discuss text windows and terminal emulations here [END REWORD]`. TeleGrafix never wrote this section.

**What's correct:** text windows do support ANSI and VT-102 screen control in the shipping engine; the terminal-emulation baseline that fills this gap is documented separately, from the shipped clients rather than the draft, at the [ANSI/VT support reference](../../baseline/techspecs/ansi-vt-support.md).

**How the reference page renders it:** [1.4 preserves the placeholder verbatim](1.4-terminal-ansi-view.md#text-windows-and-terminal-emulation-protocols) - it is unfinished draft material, not a factual claim to correct - immediately followed by a pointer to the real baseline document. See also the closing section below on unfinished draft material.

## 2.0 Color Modes & Palettes

### RIP_SET_DRAWING_PALETTE argument order

**What the draft says:** the Format line reads `!|D <num> <bits> <start> ...` (draft line 7466, carrying change bar `v2.A2`).

**What's correct:** the draft's own Arguments row - revised later, at `v2.A3` - reads `num:2 start:2 bits:1`, and both the draft's own Example and the shipped-era `FADEIN.RIP` parse only in that Arguments order: `FADEIN.RIP` opens `!|D` `40` `00` `8` followed by exactly 1,024 digits, i.e. 256 four-digit colors starting at entry 0 with 8 bits per color component. Parsed in the Format line's order, `<bits>` would read as zero, which is nonsensical.

**How the reference page renders it:** [2.0's RIP_SET_DRAWING_PALETTE entry](2.0-color-modes-and-palettes.md#rip_set_drawing_palette) already prints the corrected order (`<num> <start> <bits>`) in its Command table, Format and Example - no body fix needed.

### Write Mode scope: 1.54 vs 2.x

**What 1.54 did:** RIPscrip 1.54 offered only COPY (`00`) and XOR (`01`) write modes, and its own per-command attribute matrix already applied them to lines, rectangles, polygons, filled polygons, poly-lines, beziers and graphics text - but marked circles, ovals, arcs, oval-arcs, pie slices, bars, pixels and flood fills `Uses Write Mode: NO` (per-command lines in `RIPScrip-1.54.txt`; see [Canvas, Clipping & Write Modes](../../1.54/techspecs/2.0-canvas-clipping-write-modes.md#write-modes-rip_write_mode)).

**What 2.x does:** the 2.x draft adds OR, AND and NOT modes and turns the write-mode matrix on for every level-0 drawing primitive - a genuine functional expansion, not a correction of an error.

**How the reference page renders it:** [2.0's Scope and color effects section](2.0-color-modes-and-palettes.md#scope-and-color-effects) already states the 2.x scope correctly ("all line drawing operations... any fill-based operations... level-0 drawing primitives... fonts"); this entry is comparative history for context, not a body-fact gap.

## 2.2 Curves

### RIP_POLY_BEZIER_LINE: command `t`, not `z`

**What the draft says:** the Format line reads `!|z <num> <count> <x_base> <y_base> ...` (draft line 7102) - a copy-paste from [RIP_POLY_BEZIER](2.2-curves.md#rip_poly_bezier), whose command character genuinely is `z`.

**What's correct:** the draft's own Command line (line 7098, two lines above the Format line it contradicts) already reads `Command: t`. This reference's [command index](9.0-command-reference.md) and SyncTERM (`ripper.c`, `case 't'`, line 14721) agree: the wire opcode is `t`.

**How the reference page renders it:** [2.2's RIP_POLY_BEZIER_LINE entry](2.2-curves.md#rip_poly_bezier_line) already prints `t` throughout its Command table, Format and Example - no body fix needed.

## 2.3 Shapes & Fills

### RIP_FILLED_POLY_BEZIER: command `x`, not `z`

**What the draft says:** both the Format and Example lines read `!|z` (draft lines 5601 and 5604) - the same RIP_POLY_BEZIER copy-paste as the 2.2 entry above; the draft's Example is a bare, argument-less `!|z` stub.

**What's correct:** the draft's own Command line (line 5597) already reads `Command: x`. This reference's [command index](9.0-command-reference.md) and SyncTERM (`ripper.c`, `case 'x'`, line 14866) agree: the wire opcode is `x`.

**How the reference page renders it:** [2.3's RIP_FILLED_POLY_BEZIER entry](2.3-shapes-and-fills.md#rip_filled_poly_bezier) already prints `x` throughout its Command table, Format and Example - no body fix needed.

### RIP_FILL: declared removed, but still implemented

**What the draft says:** RIP_FILL (flood fill) "has been removed from the RIPscrip language. Due to the numerous issues trying to make it work reliably at all resolutions, it was decided that this command could not be implemented without compromising the integrity of the scene... having a reliable fill operation cannot be achieved under multiple resolutions and platforms" - the draft's own stated rationale for removal, carrying change bar `v2.A2`.

**What's correct, and its evidence:** flood fill was heavily used in the 1.5x era - 3,787 `!|F` commands across 78 of the 118 scripts in the RIPtermJS 1.5x corpus - so artists did not avoid it, but it was never dependable. The underlying BGI fill queues its seeds on a fixed-capacity stack (492 entries as RIPterm builds it) and silently drops seeds once that fills; SyncTERM reproduces the behavior deliberately, in a function it names `broken_flood_fill` (`sbbs:src/syncterm/ripper.c`, seed-stack notes at `BFF_MAX_SEEDS`), and still executes the 1.54 flood fill for legacy scenes at `case 'F'`, line 13593. This is one of three independent defects in TeleGrafix's fill code, documented with the corrections in [2.1 Fill Defects](../techspecs/2.1-fill-defects.md). Do not read the zero `!|F` counts across the 2.x (73 files) and 3.x (35 files) shipped corpora as evidence of unreliability by themselves - the command was formally removed from the 2.x language, so zero uses is the expected outcome regardless of how the 1.5x-era clients behaved. What a 2.x client does on receiving a stray `!|F` from an old script is not documented in the draft or the shipped manuals and has not been determined from a 2.x binary - but the **3.0** driver still carries a live flood-fill command (`RIPSCRIP.DLL` 3.0.7 disassembly, RIPlib `§DEAD.7`), so removal from the language did not mean removal from the code, and the same is plausible for 2.x.

**How the reference page renders it:** [2.3's RIP_FILL entry](2.3-shapes-and-fills.md#rip_fill) documents the command as **deprecated, not absent** - it carries the 1.54 argument list and semantics (never restated for 2.x), quotes the draft's removal rationale, and points at the fill defects and the filled-object replacements. The page previously presented it as removed outright; that followed the draft rather than the shipped engine, which is the opposite of this edition's convention.

## 3.0 Text Output & Fonts

### RIP_EXTENDED_FONT_STYLE: the shipped argument layout

**What the draft says:** a 13-character fixed layout - `direction:3 size:2 style:2 h_align:1 v_align:1 reserved:4`, then the font name - with predefined font names COURIER, HELV, TIMESROM, OLDENGL, SANSSERF (draft, section 3.4.1.11, line ~4823 for the Example `!|y0P01203000000courier`).

**What shipped:** RIPterm Professional 2.0 (January 1995) already drove `y` with a different, **26-fixed-character block** followed by the font name - its bundled demo script SHADOW.RIP issues `!|y00000X02020000001a1a000000marin`, the same layout later observed throughout the RIPtel corpus. TeleGrafix's own field-layout crib survives as a comment in the 3.x corpus's FONTS.RIP (line 114): `!|!sfFFFFZZOOSSCCBBCCWWRRRRRR`, decoding as `s`(1) `f`(1), a 4-digit flags field, 2-digit size, 2-digit orientation, five more 2-digit fields (string rotation, character rotation, spacing, a second character-rotation-related field, shadow), and a 6-character reserved tail - matching the 26-character count. The predefined font names never shipped either: RIPterm 2.0's outline fonts were the Atech FastFont families COBB, DEFAULT, DIXON, MARIN and SYMBOL, distributed as `.FF1` files (see the [2.x-generation font assets](../assets/fonts/README.md)); by 3.x these ship as `.RFF` "RIPscrip FastFont" files with three additional families. The full field-by-field reconstruction, with corpus evidence, is documented at the [3.x entry](../../3.0/ripscrip/3.0-text-output-and-fonts.md#the-shipped-3x-wire-layout).

**How the reference page renders it:** [3.0's RIP_EXTENDED_FONT_STYLE entry](3.0-text-output-and-fonts.md#rip_extended_font_style) still prints the draft's 13-character Arguments, Format and Example, and the draft's predefined font names - see "Body fixes required" below; this is the third of the three places this edition has not yet caught up with its own corrected fact.

## 4.1 JPEG Images

### The "flag 4 or 8" deletion cross-reference is stale

**What the draft says, and where it survives:** [4.1's RIP_IMAGE_STYLE section](4.1-jpeg-images.md#rip_image_style) still carries the sentence "however they will be deleted if flag 4 or 8 are active - see below", inherited unchanged from the draft's `v2.A0` change bar (draft lines 9323-9326) - a pre-ALPHA-1 flag numbering.

**What's correct:** in the flag table immediately below that sentence, delete-when-complete is **flag 2** (added `v2.A1`), while flag 4 (`v2.A3`) suppresses the background clear and flag 8 (`v2.A4`) commits the palette - neither of which deletes anything. The cross-reference was never updated when the flag numbers were revised in later alpha revisions.

**How the reference page renders it:** the flag table itself is correct and current; only the prose cross-reference sentence above it is stale and self-contradicts the table three lines later - see "Body fixes required" below.

### GIF was drafted, never shipped

**What the draft says:** the v2.A4 revision history (reproduced in [1.0's Revision 2.A4 section](1.0-introduction.md)) announces "RIPscrip 2.0 now supports GIF (Graphics Interchange Format) files in addition to JPEG files", and [4.1's flag 8 description](4.1-jpeg-images.md#rip_image_style) still says flag 8 is "typically only of use when using the image style with GIF files".

**What shipped:** no GIF support ever shipped. RIPterm 2.30's `RIPTERM.EXE` contains an abundant JPEG decoder - 11 `jpeg` strings, including `Not a JPEG file (SOI 1)` and `Shutting down JPEG system` - and not one GIF string, verified with `strings -n 1` (the default 4-character minimum would hide the 3-character `GIF` token) and by a raw search for the four-byte `GIF8` file signature; both return nothing. JPEG is the only image format the shipped 2.x engine decodes.

**How the reference page renders it:** this fact is already stated plainly elsewhere in the tree - [6.1 Content File Roles](6.1-content-file-roles.md) says outright "no shipped 2.x-generation client decodes it" for `.GIF`, and the [JPEG techspec](../techspecs/3.1-jpeg-images.md) and [connection directory model techspec](../techspecs/4.0-connection-directory-model-delta.md) both confirm it independently. 4.1's own page is the odd one out - see "Body fixes required" below for a lighter-weight fix than the other items in that list, since the fact is already well corroborated in the same tree.

## 4.5 Audio Files (WAV)

### RIP_PLAY_AUDIO shipped as specified

**What shipped:** RIP_PLAY_AUDIO is not a divergence - it shipped. RIPterm Professional 2.0 (January 1995) implemented digitized `.WAV` playback via HMI "Sound Operating System" drivers, with an Audio Setup screen supporting 19 sound boards and a `-A` command-line switch to disable digitized audio (RIPTERM.DOC section 4.3, section 2.3).

**How the reference page renders it:** [4.5's RIP_PLAY_AUDIO entry](4.5-audio-files.md#rip_play_audio) already documents the command as a normal, working part of the language, matching this history; this entry exists to record the corroborating evidence, not to flag a discrepancy. See the [2.x-generation audio assets](../assets/audio/README.md).

## 5.5 File Transfer & Queries

### RIP_FILE_DELETE was announced, never specified

**What the draft says:** the v2.A3 revision history (reproduced in [1.0's Revision 2.A3 section](1.0-introduction.md)) announces "Added the RIP_FILE_DELETE command to remove unneeded JPEG or WAVE files off the user's hard disk so that they don't clutter things up when they're no longer needed."

**What's correct:** the capability is real and shipped - as a **text variable, not a command**. No command entry for RIP*FILE_DELETE exists anywhere in the ALPHA 4 draft's command reference, and the name appears in no shipping binary. The function arrives one revision later as [`$FILEDEL(file,...)$`](5.1-text-variables.md#filedel) *(v2.A4)\_, and that form is implemented: the literal `FILEDEL` is present in `RIPTERM.EXE` for all three shipping engines (Professional 2.0, v2.20.01, 2.30), and RIPtel 3.1's `RIPSCRIP.HLP` carries the handler symbol `tvarProcFILEDEL` - the `tvarProc` prefix marking it a text-variable processor rather than a command dispatch.

The draft's own behavior confirms the reading: the two sibling commands announced in the same v2.A3 list, RIP_ROUNDED_RECT and RIP_FILLED_ROUNDED_RECT, each recur 5 and 6 times in the draft because they received full command entries. RIP_FILE_DELETE occurs exactly once - the announcement itself. The command form was announced and then superseded by the variable, not merely left undocumented.

**How the reference page renders it:** [5.5](5.5-file-transfer-and-queries.md#rip_file_query) documents the commands that exist and points at `$FILEDEL$` for deletion; the [9.0 command index](9.0-command-reference.md) records the announced-but-unspecified command so a reader searching for it finds the answer rather than silence. Hosts targeting any 2.x client should use `$FILEDEL$`.

## 7.0 Drawing Ports

### RIP_DELETE_PORT: command `2p`, not `2s`

**What the draft says:** the Format and Example lines both read `!|2s <port_num> <dest_port> <res>` / `!|2s500000` (draft lines 10473-10474) - the switch-port opcode, copied from the immediately preceding RIP_SWITCH_PORT entry.

**What's correct:** the draft's own Command line for this entry already reads `Command: p`. The RIPtel corpus confirms it in practice (`!|2p` in `NEWPORT.FN` and `MAKEPORT.FN`), and `RIPSCRIP.HLP` names the function `RIP_PortDelete` with the message "Can't delete graphics port #0". The wire opcode is `2p`.

**How the reference page renders it:** [7.0's RIP_DELETE_PORT entry](7.0-drawing-ports.md#rip_delete_port) already prints the corrected `!|2p` throughout its Format and Example - no body fix needed. The [3.x entry](../../3.0/ripscrip/7.0-drawing-ports.md#rip_delete_port) documents the same correction against the later corpus.

## Unfinished draft material preserved as-is

Not every gap in the draft is a divergence to correct - some material was simply never finished, and this edition preserves it verbatim rather than inventing a resolution:

- **Text windows and terminal emulation** ([1.4](1.4-terminal-ansi-view.md#text-windows-and-terminal-emulation-protocols)) - the entire subsection is the placeholder `[BEGIN REWORD] Discuss text windows and terminal emulations here [END REWORD]`. See the 1.4 entry above for where the real information now lives.
- **Chisel effect resolution independence** ([4.3](4.3-buttons.md#chisel-effect-insets)) - `[BEGIN REWORD] <<< Think about resolution independence of chisel indent. >>> <<< Talk about bevel sizes too, along with recesses. >>> [END REWORD]`.
- **RIP_BUTTON scaling** ([4.3](4.3-buttons.md#rip_button)) - `[BEGIN REWORD] <<< Discuss resolution independence & scaling of the above >>> [END REWORD]`.

---

[◀ Prev: 9.3 Host Command & Control Character Reference](9.3-host-command-reference.md) · [Contents](README.md)
