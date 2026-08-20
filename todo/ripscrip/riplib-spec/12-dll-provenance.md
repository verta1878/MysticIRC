
=====================================================================
==       SEGMENT 12: BINARY PROVENANCE & EVIDENCE CLASSES          ==
=====================================================================

Segment 11 records conclusions drawn from a binary analysis of
TeleGrafix's RIPSCRIP.DLL.  This segment records the *evidence* those
conclusions rest on: which artifact, how it is identified, how the
analysis is reproduced, and — critically — what each class of
evidence can and cannot establish.

The rule this segment exists to enforce:

     A claim in these specification segments about what the DLL
     does, contains, or omits MUST cite the evidence class it comes
     from.  A bare "not present in the DLL" is not a citation.

This was written after an external standardization effort
(bbs-land/remote-imaging-protocol) raised conflicts against segment
11 that could not be checked, because the substrate had been
summarized away.  See design/bbs-land-alignment.md.


---------------------------------------------------------------------
12.1  THE ARTIFACT
---------------------------------------------------------------------

     File:         Ripscrip.dll
     Size:         592,896 bytes
     MD5:          bade8b1f4e467ac7ad4edb2639738d4c
     Format:       32-bit Windows PE (i386), PE32
     Image base:   0x10000000
     Build date:   October 16, 1997
     Build path:   C:\src\rip3\dll32\   (recoverable from .rdata)
     Driver:       see "Version labelling" below
     Ships in:     RIPtel Visual Telnet 3.1

Version labelling (CORRECTED 2026-08-12).  This document previously
recorded the driver as "RIPscrip 3.0.7".  The binary does not support
that string: it contains "3.0.7" ZERO times, and the value returned by
its own ripProductVersion() entry point is the literal

     3.00.04

which appears exactly once, in the .rdata block alongside the other
ripProductName()/ripVendorName()/ripProductPlatform() constants
("RIPscrip", "TeleGrafix Communications, Inc.", "Win32").  RIPTEL.EXE
from the same install carries "3.1" and no 3.0.x string at all.

"3.0.7" is an EXTERNAL label, not a self-report: bbs-land's artifact
catalogue records a RIPSCRIP.DLL of that name as extracted from
rtel3100.exe, and RIPlib adopted the label from there.  Whether that
build is byte-identical to this one is unverified — the catalogue does
not publish a hash.  Other RIPlib documents still use "3.0.7" as a
shorthand for this driver; where they do, it means "the image with the
MD5 above", which is the only identifier that is actually checkable.
Treat the size+MD5 pair as authoritative and the version string as
provenance metadata.

Every address in segments 11 and 12 is an absolute virtual address
valid ONLY for this exact image.  A different build invalidates them
all.  Verify the MD5 before relying on any recorded address.

Section layout:

     .text     0x10001000   vsize 0x074AE0
     .rdata    0x10076000   vsize 0x002470
     .data     0x10079000   vsize 0x01C9F0
     .idata    0x10096000   vsize 0x00147C
     .rsrc     0x10098000   vsize 0x00309C
     .reloc    0x1009C000   vsize 0x004676


---------------------------------------------------------------------
12.2  REPRODUCING THE ANALYSIS
---------------------------------------------------------------------

     python scripts/dll-provenance.py <path>/Ripscrip.dll

The script re-derives the whole dataset from the binary with no
third-party dependencies, and fails loudly if the fingerprint does
not match.  Expected output:

     fingerprint verified : True
     exports              : 153
     RIP_* strings        : 90   export-names 69   internal 21
     assertion strings    : 8
     switch jump tables   : 94
     landmark parse_state_jump_table : .text jmp=0x10039eb1 cases=13

The method mirrors the original reconstruction (see
docs/historical/ripscrip-v3-RE-notes.md):

     1. Export table enumeration
     2. String table extraction
     3. Error/assertion message cross-referencing
     4. Switch jump-table location


---------------------------------------------------------------------
12.3  EVIDENCE CLASSES — WHAT EACH ONE PROVES
---------------------------------------------------------------------

This is the section segment 11 needed and did not have.  The four
classes are NOT interchangeable, and conflating them produced at
least one false claim in the historical record.

CLASS A — Export table (153 entries).
     What it contains: the DLL's HOST-FACING API only — engine and
     instance lifecycle (RIP_EngineCreate, RIP_InstanceInit),
     stream handling (RIP_StreamWrite), buffer processing
     (RIP_ProcessBuffer), palette getters, block-mode and temp-file
     helpers.  One entry retains its MSVC decoration:
     ?RIP_SetDefaultSettings@@YAHPAURIPINST@@@Z.

     PROVES:     a host-callable entry point exists.
     PROVES NOT: anything whatsoever about RIPscrip commands.
                 NOT ONE command handler is exported.

     ==> "Absent from the export table" is worthless as evidence
         about a command.  Every command is absent from it.

CLASS B — Internal name strings (21).
     RIP_* strings that are NOT export-table names, each referenced
     by a `push imm32` inside .text.  These are handler names used
     in the DLL's own diagnostics, so a hit is strong positive
     evidence that the named handler exists.

     PROVES:     the named handler exists in this build.
     PROVES NOT: which command letter reaches it.  Absence proves
                 nothing either — only handlers that emit a
                 diagnostic carry a name string at all.

CLASS C — Assertion strings (8).
     Strings of the form "<module>.cpp - <Func>()", giving the
     original source module name.  Recovered:

          r_ports.cpp   - portDelete()
          riprocmd.cpp  - RIP_BackColor()
          riprocmd.cpp  - RIP_OneDrawingPalette()
          riprocmd.cpp  - RIP_PortCopy()
          riprocmd.cpp  - RIP_PortDelete()
          riprocmd.cpp  - RIP_SwitchEnvironment()
          riprocmd.cpp  - RIP_SwitchPalette()
          riprocmd.cpp  - rip_query()

     PROVES:     the function existed under that name, in that
                 source module, at build time.  Strongest class.
     PROVES NOT: command-letter binding.

CLASS D — Switch jump tables (94).
     Sites matching `jmp dword ptr [reg*4 + disp32]`.  The entry
     count reported by the tool is an UPPER BOUND — the walk stops
     at the first non-.text value, so adjacent tables inflate it.
     The `cmp` immediately preceding the jmp gives the true case
     count where present.

     PROVES:     a dispatch exists and how many cases it has.
     PROVES NOT: the semantic key, without further disassembly.


---------------------------------------------------------------------
12.4  INTERNAL COMMAND-HANDLER NAMES (CLASS B)
---------------------------------------------------------------------

21 RIP_* names present in .data, absent from the export table, each
with at least one code cross-reference.  These are the citable
provenance for handler existence.  "String VA" is where the name
lives; "xref" is a `push` of that address from inside .text.

     NAME                      STRING VA     CODE XREF(S)
     RIP_BeginExtendedText     0x1007A458    0x1000A6A8
     RIP_Button                0x1007A514    0x1000AC04
     RIP_ButtonStyle           0x1007A6F0    0x1000B4A0
     RIP_Color                 0x1007D3B4    0x1001AC36 +2
     RIP_Define                0x1007A814    0x1000BD77
     RIP_EnterBlockMode        0x1007DF1C    0x10024C3B +2
     RIP_ExtendedFontStyle     0x1007AD44    0x1000DDAD +2
     RIP_FileQuery             0x1007A914    0x1000BE51
     RIP_Image                 0x1007A94C    0x1000C2FF +1
     RIP_LineStyle             0x1007D73C    0x1001CE94
     RIP_LoadIcon              0x1007A9FC    0x1000CBBF
     RIP_MOUSE                 0x1007AAAC    0x1000CF93
     RIP_Mouse                 0x1007AADC    0x1000CF72 +1
     RIP_OneDrawingPalette     0x1007D7E8    0x1001D115
     RIP_PlayAudio             0x1007AB10    0x1000D2B6 +1
     RIP_Point                 0x1007D928    0x1001E3D9
     RIP_PolyPolygon           0x1007DA10    0x1001E9CE +2
     RIP_Query                 0x1007AC28    0x1000D431
     RIP_ReadScene             0x1007AC40    0x1000D671 +1
     RIP_RegionText            0x1007AC54    0x1000D736
     RIP_Scroll                0x1007AC84    0x1000D8AC +2

Note the xrefs fall in two contiguous bands — roughly
0x1000A000-0x1000E000 and 0x1001A000-0x1001F000 — and run in
alphabetical order with ascending address, consistent with handlers
compiled from one or two translation units.

Full machine-readable form: run the script; see internal-names.json.


---------------------------------------------------------------------
12.5  VALIDATED LANDMARKS
---------------------------------------------------------------------

Addresses previously recorded outside the repository, re-validated
against the binary by the script on every run:

     ripParseStateMachine      0x10039E90   .text
     parse-state jump table    0x1003AB9C   .text
                               reached from jmp at 0x10039EB1,
                               preceding `cmp` gives 13 cases
     ripCmd_MouseRegion        0x1000A964   .text

The 13-case count independently confirms the "13 states (0..12)"
figure recorded for the parse state machine.  RIPlib's own state 13
(LEVEL3_LETTER) is a RIPlib addition and is not present in the DLL.


---------------------------------------------------------------------
12.6  WHAT THIS SEGMENT SETTLES
---------------------------------------------------------------------

Handler existence confirmed by Class B/C evidence, correcting
segment 11 where it claimed otherwise:

     RIP_SetWorldFrame       — PRESENT in the string table.
                               Segment 11 §11.1 states there is "no
                               implementation found in the DLL export
                               table or function strings."  The export
                               half is a category error (see 12.3
                               Class A); the string half is FACTUALLY
                               WRONG.  §11.1 must be corrected.

     RIP_ReadScene           — PRESENT (0x1007AC40).  §DEV.4 lists
                               '1R' READ_SCENE as a RIPlib-original
                               command "beyond the published
                               TeleGrafix tables."  Incorrect.

     RIP_OneDrawingPalette   — PRESENT, and additionally carries a
                               Class C assertion string.  A drawing-
                               palette command exists in this driver.

     RIP_ExtendedFontStyle   — PRESENT, and distinct from the above.

     RIP_PolyPolygon         — PRESENT.
     RIP_Scroll              — PRESENT, distinct from RIP_CopyBlit.

Names NOT found in any class, which RIPlib's command tables assert:

     SAVE_ICON, KILL_MOUSE_EXT, and every "_EXT"-suffixed name.
     No string containing "_EXT" appears anywhere in the binary.

     Per 12.3 this is NOT proof of absence — only handlers that emit
     diagnostics carry name strings.  It does mean those names have
     no positive support from this artifact, and any claim resting
     on them must say so.


---------------------------------------------------------------------
12.7  CLASS E — THE COMMAND DISPATCH TABLE
---------------------------------------------------------------------

Recovered in full: RVA 0x080820, 129 entries of 40 bytes.  See
segment 13 for the verbatim table and scripts/dll-dispatch-table.py
to regenerate it.

     PROVES:     which command letter reaches which handler, the
                 argument COUNT, and each argument's TYPE.
     PROVES NOT: the handler's NAME.  Naming still requires class
                 B/C evidence or reading the handler body.

This is the strongest class for settling opcode disputes, because a
proposed name either fits the recorded arity and argument types or
it does not.  A name requiring three arguments cannot belong to a
letter the table records as taking seven.

Validation: all 129 handler pointers resolve inside .text, and the
independently recorded anchor (RIP_BOUNDED_TEXT, '"', RVA 0x01A0DA)
matches slot 1 exactly.


---------------------------------------------------------------------
12.8  ADJUDICATION OF DISPUTED OPCODES
---------------------------------------------------------------------

Applying class E to the conflicts raised against RIPlib's command
tables.  "RIPlib" is this project's assignment; "record" is the
TeleGrafix reconstruction maintained by bbs-land.

REFUTED — RIPlib's assignment is incompatible with the binary:

  |J   1 arg (mega2).  RIPlib assigns SAVE_ICON with 2 arguments;
       the table records ONE.  The record's RIP_SET_BASE_MATH
       (base_math:2) is exactly one 2-digit argument.  REFUTED.

  |f   2 args, both XY.  RIPlib assigns FONT_ATTRIB (attrib:2
       res:2) — two MegaNums.  The table records COORDINATE PAIRS,
       not MegaNums.  The record's RIP_SET_WORLD_FRAME
       (x_dim:XY y_dim:XY) matches the recorded types exactly.
       REFUTED.  Consequence: §A2G.3 cannot live on '|f'.

  |K   4 args, all XY.  RIPlib assigns KILL_MOUSE_EXT.  Four
       coordinate pairs describe a rectangle, not a mouse-field
       kill.  The record's RIP_FILLED_RECTANGLE fits.  REFUTED.

  |+   7 args: XY,XY,XY,XY,mega2,mega2,mega2
  |[   7 args: XY,XY,XY,XY,mega2,mega2,mega2
  |]   7 args: XY,XY,XY,XY,mega2,mega2,mega2
       Three letters with IDENTICAL signatures — a command family.
       RIPlib assigns three unrelated commands (SCROLL,
       FILL_POLYGON_EXT, POLYLINE_EXT).  Polygon and polyline
       commands take a variable vertex count by nature, yet these
       entries are fixed-arity 7.  The record's skewed-oval
       chord/pie-slice/arc family explains the shared signature.
       REFUTED.

  |_   6 args: XY,XY,mega2,mega2,XY,XY.  RIPlib assigns DRAW_TO,
       which needs a single coordinate pair.  REFUTED.

  |<   VARIABLE length.  RIPlib assigns GET_IMAGE_EXT, a fixed
       rectangle read.  Variable length fits the record's
       RIP_POLY_POLYGON.  REFUTED.

  |D   VARIABLE length.  RIPlib assigns FILL_PATTERN_EXT with 18
       fixed arguments; the table records a variable-length
       command.  The record's RIP_SET_DRAWING_PALETTE (blocks of
       palette entries) is variable by nature.  REFUTED.

  |2R  1 arg (mega4).  RIPlib assigns REFRESH with ZERO arguments;
       the table records one 4-digit argument, matching the
       record's RIP_SET_REFRESH (res:4).  REFUTED.

  |1S  NO SUCH ENTRY.  RIPlib assigns '1S' = IMAGE_STYLE.  No 'S'
       or 's' appears in the Level 1 band at all.  The record puts
       image style on '1i', which IS present (6 args).  REFUTED.

  |28  NO SUCH ENTRY.  RIPlib assigns '|28' RIP_GRADIENT_FILL and
       attributes it to this driver.  No digit-letter command
       exists in the Level 2 band, and no gradient handler name
       appears in any string class.  The attribution is REFUTED;
       §A2G.13 extends a command this binary does not contain.

APPLICATION STATUS (added 2026-08-12).  Recording a refutation is not
the same as acting on it, and for months this register did the former
without the latter.  Where each entry now stands in the CODE:

  APPLIED   |f   -> RIP_SET_WORLD_FRAME
            |&   -> RIP_SKEWED_OVAL            (see 12.14)
            |-   -> RIP_FILLED_SKEWED_OVAL
            |]   -> RIP_SKEWED_OVAL_ARC
            |[   -> RIP_SKEWED_OVAL_PIE_SLICE
            |+   -> RIP_SKEWED_OVAL_CHORD
            |_   -> RIP_FILLED_OVAL_CHORD
            |K   -> RIP_FILLED_RECTANGLE.  Handler 0x01bee5 orders
                    (arg0,arg2) and (arg1,arg3) through 0x1003112e —
                    normalising x0/x1 and y0/y1, i.e. rectangle setup.
                    SyncTERM's ripper.c agrees.  The mouse-field kill it
                    displaced was redundant: '|1k' already does that.
            |<   -> RIP_POLY_POLYGON.  Handler 0x01e80a reads arg[0] as
                    a count and walks the rest; ICONS/POLYPOLY.RIP
                    exercises it and prints "RIP_POLY_POLYGON" on
                    screen.  Wire layout read off that file:
                    count:2 { nverts:2 (x:2 y:2)* }*.  Filled even-odd
                    across all contours, because the demo places a
                    circle behind the shape to show the holes.
                    Clipboard capture stays on '|1C'.

            |J   -> RIP_SET_BASE_MATH.  Not a naming question after all.
                    Handler 0x01f32e names itself RIP_SetBaseMath and
                    accepts exactly 0x24 (36) and 0x40 (64), forcing 36
                    for anything else, then stores the byte in engine
                    state — it selects the MegaNum RADIX for everything
                    that follows, which is why it appears near the top of
                    20 of the 35 shipped scenes.  RIPlib had a clipboard
                    slot save here, with no dispatch basis, consuming a
                    slot on each of the corpus's 24 uses.  The slot
                    mechanism is RIPlib's own and moves to '|3J'.
                    Radix caveat: see D-10.
            |D   -> RIP_SET_DRAWING_PALETTE.  Handler 0x01f46a names
                    itself and validates argc == count + 3, count <= 256,
                    start <= 255, bits == 8, which gives the layout
                    outright: start:2 count:2 bits:1 then count * rgb:4 —
                    the block form of '|d' RIP_OneDrawingPalette.  The
                    8x8 user fill pattern it displaced is '|s'
                    RIP_FILL_PATTERN, already implemented, same payload.
            |1S  -> REMOVED.  Neither 'S' nor 's' exists in the driver's
                    Level 1 band.  Image style is '|1i' RIP_ImageStyle
                    (slot 98, RVA 0x00c39a), which RIPlib already
                    implements and which real scenes use.  The duplicate
                    is deleted rather than aliased: accepting an opcode
                    the protocol does not define is how a stream
                    desynchronises silently.
            |2R  -> now consumes its res:4.  The entry records one mega4;
                    RIPlib read it as a zero-argument command.

  NOT A CODE DEFECT
            |28  RIPlib's GRADIENT_FILL has no entry in this driver, but
                 section 6a already carries the corrected provenance
                 (PROVENANCE CORRECTED 2026-08-12): it stands as a RIPlib
                 extension and is no longer attributed to TeleGrafix.
                 Nothing further to apply.

Every entry in this register is now applied.

SETTLED BY NAME — 52 handlers name themselves in their own error
paths (scripts/dll-name-handlers.py; segment 13 carries the full
column).  Where a disputed letter's handler names itself, the
dispute ends:

     |f  ->  RIP_SetWorldFrame       (B3 — decisive, with arity)
     |J  ->  RIP_SetBaseMath         (B2 — decisive)
     |D  ->  RIP_SetDrawingPalette   (B6 — decisive)
     |d  ->  RIP_OneDrawingPalette   (B6 — decisive; NOT font style)
     |;  ->  RIP_PolyMarker          (B4 — decisive; NOT BUTTON_EXT)
     |y  ->  RIP_ExtendedFontStyle   (extended font style is '|y')
     |1i ->  RIP_ImageStyle          (B8 — decisive; there is no '1S')
     ESC ->  rip_query               (the Escape-introduced command)
     |2ESC-> RIP_SwitchDirectory
     |W  ->  RIP_WriteMode           (see 12.10)

WHERE FONT ATTRIBUTES ACTUALLY LIVE:

     |q  ->  RIP_FontAttrib          1 argument (mega2)

     This resolves the question underneath B3/X4.  A font-attribute
     command DOES exist in the driver — on '|q', taking a single
     argument — and RIPlib placed the feature on '|f', which is
     RIP_SetWorldFrame.  §A2G.3 should move to '|q' rather than
     being abandoned.  The facing-bit layout still needs the
     handler body read (see 12.11).

Other names recovered that correct or confirm the tables: '|=' is
RIP_LineStyle, '|S' RIP_FillStyle, '|s' RIP_FillPattern, '|Q'
RIP_SetPalette, '|a' RIP_OnePalette, '|M' RIP_SetColorMode, '|n'
RIP_SetCoordinateSize, '|N' RIP_SetBorder, '|r' RIP_TextMetric,
'|v' RIP_ViewPort, '|w' RIP_TextWindow, '|Y' RIP_FontStyle, '|b'
RIP_ExtendedTextWindow, '|p' RIP_FilledPolygon, '|2C' RIP_PortCopy,
'|2p' RIP_PortDelete (both corroborated by class C assertion
strings), '|2P' RIP_PortDefine, '|2s' RIP_SwitchPort, '|1U'
RIP_Button, '|1B' RIP_ButtonStyle, '|1M' RIP_Mouse, '|1I'
RIP_LoadIcon, '|1D' RIP_Define, '|1F' RIP_FileQuery.

SUPPORTED — RIPlib's assignment fits the binary:

  |&   5 args: XY,XY,mega2,mega2,mega2.  RIPlib's ICON_STYLE
       (x0,y0 + three mode fields) matches exactly, and the
       original reconstruction documented this letter as
       RIP_ICON_DISPLAY_STYLE from dispatch analysis.  RIPlib's
       name has genuine binary provenance here; the record's
       RIP_SKEWED_OVAL does not fit this signature.

SETTLED BY FIELD DIAGNOSTICS (added 2026-08-12).  Each handler names
the field it rejects, which identifies arguments without guesswork.
Recovered for 66 of 129 handlers by
scripts/dll-handler-semantics.py; the full listing is segment 13 §13.5.
These close the remaining B4/B6 questions outright:

  |<  "Must have at least two vertices to make a polygon"
      "Insufficient vertices (2)"
      -> POLY_POLYGON, confirmed by the handler's own words.
         RIPlib's GET_IMAGE_EXT is refuted beyond the arity argument.

  |D  "More than 256 entries"      "Start is out of range"
      "Invalid number of bits"     "Illegal RGB value"
      -> a palette-block write, exactly RIP_SetDrawingPalette.
         RIPlib's FILL_PATTERN_EXT (18 fixed args) is refuted.

  |d  "Color palette index out of range"  "Bits value out of range"
      "RGB Color value is out of range!"
      -> index / bits / rgb.  Disassembly of RVA 0x01CF95 confirms
         index <= 0xFF, bits == 8 exactly, rgb <= 0xFFFFFF.  This is
         now implemented; see B6 in the CHANGELOG.

  |;  "Invalid marker number"  "Invalid marker rotation angle (>=360)"
      "Invalid marker flags value"
      -> RIP_PolyMarker, not BUTTON_EXT.  B4 closes here.

  |q  "Invalid font attributes"
      "Font attributes not supported for system fonts"
      -> independently confirms the 2026-08-12 relocation of font
         attributes to '|q', AND that the bitmap system font ignores
         them — which is what RIPlib already does.

  |r  "Invalid text metric mode"  "Invalid text metric domain"
      -> RIP_TextMetric takes a mode and a domain.  Still
         unimplemented (D-5), but no longer semantically unknown.

  |j  "Unable to create temp brush"
      -> brush-related, with two coordinate pairs.  The only one of
         the four missing commands still genuinely unidentified.

UNDECIDED on arity alone:

  |;   7 args: XY,XY,mega2,XY,XY,mega2,mega2.  Neither BUTTON_EXT
       (RIPlib) nor RIP_MARKER (record) is excluded.  Needs the
       handler body.

  |d   3 args: mega2,mega1,mega4.  Fits both EXT_FONT_STYLE
       (fid,attr,size — RIPlib) and a single-palette-entry write
       (record).  Note '|y' carries an 11-argument font command,
       which supports the record's position that extended font
       style lives on '|y'; and RIP_OneDrawingPalette has class
       B AND class C evidence.  Leans to the record.

  (|W was resolved by disassembly — see 12.10.)

ALSO CONFIRMED:

  An ESC-introduced command exists — slot 110, letter byte 0x1B,
  handler RVA 0x046F66, 1 argument (mega4).  This corroborates the
  record's account of a literal-Escape command form.


---------------------------------------------------------------------
12.10  CLASS F — '|W' WRITE MODE, SETTLED BY DISASSEMBLY
---------------------------------------------------------------------

The write-mode ordering was the highest-impact open question and is
now closed by reading the code.  The full chain, three functions:

1.  HANDLER — RVA 0x02102C (`RIP_WriteMode()`, named by its own
    error string at 0x1007DD08).  It range-checks and stores:

         0x02104a  cmp     ebx, 4
         0x02104d  jbe     0x10021066        ; >4 -> "Invalid argument"
         ...
         0x02108d  mov     eax, [esi + 0xa]
         0x021091  movsx   ecx, word [eax + 8]
         0x021097  imul    ecx, ecx, 0x61
         0x02109a  mov     byte [ecx+eax+4], bl   ; store RAW wire value

    The value written is the wire value, unmodified.  There is no
    renumbering here.

2.  APPLY — RVA 0x00E6E9 reads it straight back and hands it to GDI:

         0x00e703  movzx   ax, byte [ecx+edx+4]   ; the stored mode
         0x00e70a  call    0x1000E6B3             ; translate
         0x00e716  push    [esi + 0x62]           ; HDC
         0x00e719  call    [0x10096408]           ; GDI32!SetROP2

3.  TRANSLATE — RVA 0x00E6B3, a five-way branch:

         mov ax, 0x0D                 ; default
         cmp ecx,1 -> mov ax, 0x07
         cmp ecx,2 -> mov ax, 0x0F
         cmp ecx,3 -> mov ax, 0x09
         cmp ecx,4 -> mov ax, 0x06

    Against wingdi.h:

         wire 0  -> 0x0D  R2_COPYPEN   COPY
         wire 1  -> 0x07  R2_XORPEN    XOR
         wire 2  -> 0x0F  R2_MERGEPEN  OR
         wire 3  -> 0x09  R2_MASKPEN   AND
         wire 4  -> 0x06  R2_NOT       NOT

THE WIRE ORDERING IS THEREFORE:

     0 = COPY,  1 = XOR,  2 = OR,  3 = AND,  4 = NOT

Two entries in segment 11 are refuted by this:

  §BUG.7 claims the DLL's internal constants (COPY 0 / XOR 1 / OR 2)
  differ from "the protocol wire values ... 0=COPY, 1=OR, 3=XOR".
  No such distinction exists.  The byte taken off the wire is the
  index into the translation above, unmodified, so XOR is 1 ON THE
  WIRE.  §BUG.7 is not a DLL bug; it is an error in this document,
  and it must be withdrawn.

  §DEAD.3 claims AND and NOT were "parsed and stored but the
  pixel-write paths only had switch cases for three modes."  The
  translation maps all five, including AND (R2_MASKPEN) and NOT
  (R2_NOT).  AND and NOT were IMPLEMENTED, not dead.  §A2G.1's
  claim to activate them is therefore unfounded.

Consequence for RIPlib: include/drawing.h currently defines
DRAW_MODE_OR=1, DRAW_MODE_AND=2, DRAW_MODE_XOR=3, and the '|W'
handler passes the wire byte through unchanged, so RIPlib renders
XOR where the protocol means OR and vice versa.  The fix is the
four constants.


---------------------------------------------------------------------
12.11  COMMANDS ARE OVERLOADED BY ARGUMENT COUNT
---------------------------------------------------------------------

11 of the 129 dispatch entries carry a letter byte of 0x00.  They are
not padding.  Each one immediately follows a real command, shares
that command's handler address, and differs only in ARITY:

     letter  slots            handler     arities
     |h      32,33,34,35,36,37  0x01CAE1  3, 3, 5, 2, 2  (+ parent 3)
     |t      61,62,63           0x01E4A4  2, 3, 7
     |x      71,72,73           0x01BC1D  2, 3, 7
     |z      77,78,79           0x01E449  2, 3, 7

A zero letter therefore means "another accepted signature for the
preceding letter", and the driver selects among them by how many
arguments the stream actually supplies.

This is the same mechanism §11.2 Erratum 1 already describes for the
'b' collision, where RIP_SET_BASE_MATH and RIP_EXTENDED_TEXT_WINDOW
are told apart by argument length.  The dispatch table shows it is
not a special case but a general facility: '|h' accepts six distinct
signatures.

IMPLEMENTATION CONSEQUENCE: a parser that binds one fixed arity per
command letter cannot accept everything this driver accepts.  RIPlib
dispatches on the letter with a single expected argument layout, so
alternate-arity forms of '|h', '|t', '|x' and '|z' will mis-parse —
and, because a wrong length shifts every subsequent field, the error
is silent rather than caught.  This has not been reconciled against
RIPlib's parser and should be treated as an open defect, not a
documented deviation.


---------------------------------------------------------------------
12.12  OPEN DEFECTS IN RIPlib SURFACED BY THIS ANALYSIS
---------------------------------------------------------------------

These are NOT deviations.  Each is a place where RIPlib's behaviour
is wrong against the driver and no decision has been taken.  Listed
so they are tracked rather than absorbed silently.

D-1  RESOLVED 2026-08-12 — and the resolution reverses the original
     recommendation.

     The letter half is fixed: '|f' is RIP_SetWorldFrame and font attributes
     moved to '|q'.  What remained was the claim that RIPlib still owed a
     world->device coordinate transform.  Measurement says it does not.

     Sampling every 2-character coordinate in the L/R/B commands of the
     shipped RIPtel 3.1 scenes that set the corpus-standard frame
     '|fZKQO' (1280x960):

          coordinate values sampled : 31,036
          values greater than 640   :    119   (0.4%)
          maximum value observed    :  1,280

     Content authored in a 1280x960 world space would spread across that
     range.  It does not: 99.6% of coordinates are already device-space.
     Applying a world->device scale would therefore shrink almost the whole
     corpus to half size — the transform would be the regression, not its
     absence.

     RIPlib stores the frame (so it is available to an embedder) and applies
     no scaling.  That is now a measured decision rather than an unfinished
     one.  The handful of values reaching exactly 1280 are worth a second
     look if full-canvas content ever turns up, but nothing in the shipped
     corpus needs the transform.

     Original entry, retained for context:
     '|f' WAS PARSED AS FONT_ATTRIB, BUT IT IS RIP_SetWorldFrame.
     Severity: high — this is live corpus content, not a corner case.
     The handler names itself RIP_SetWorldFrame and takes two XY
     coordinate pairs; RIPlib reads two MegaNums as attrib:2 res:2.
     The corpus standard '|fZKQO' (1280x960) appears in the prologue
     of most shipping scenes, so RIPlib mis-parses the opening of
     ordinary 3.x content and silently applies a font attribute.
     FIX: move §A2G.3's font attributes to '|q' (RIP_FontAttrib,
     1 argument — the driver's own home for them) and implement '|f'
     as the world frame.  Both halves change wire behaviour.

D-2  RESOLVED 2026-08-12.  Length-based signature dispatch implemented
     for all four overloaded letters.

     '|t', '|x' and '|z' share one three-signature pattern whose lengths
     are distinct, so dispatch is exact:

          4 chars   count:2 steps:2                header
          5 chars   count:1 x:XY y:XY              move-to
         13 chars   count:1 + three XY pairs       curve-to, continuing
                                                   from the current point

     That is an ordinary poly-bezier stream, and it also settled B8's
     claim about '|t': the driver's level-0 '|t' handler (RVA 0x01E4A4)
     sits beside '|z' (0x01E449) with a structurally identical body and
     an added write-mode apply.  It is RIP_POLY_BEZIER_LINE, not
     RIP_REGION_TEXT.  Region text is '|1t', which RIPlib already had, so
     correcting the letter lost nothing.

     '|h' carries six signatures on one handler.  Lengths 4 and 6 are
     unambiguous and now read their own layouts — previously they were
     read with the 8-character layout, which pulled the id and flags from
     past the end of the parameters.

     CORRECTED 2026-08-12.  An earlier draft said the two 8-character
     forms and the two 3-character forms were separated "on state we have
     not recovered".  That was asserted without reading the handler, and
     it is wrong.  '|h' (RVA 0x01CAE1) is a thin wrapper: after a
     protection check it passes BOTH the parameter block and the argument
     COUNT through to a shared routine at RVA 0x1001799E.  Selection is by
     argument count, explicitly — there is no hidden state.

     The six entries occupy consecutive slots 32-37 with character counts
     8, 4, 6, 8, 3, 3.  Taking the first entry whose template fits the
     available length gives 8 -> slot 32, 4 -> slot 33, 6 -> slot 34,
     3 -> slot 36, which is exactly what RIPlib implements; the duplicate
     entries are unreachable under that rule.  The internals of 0x1001799E
     have not been traced, so first-match is the consistent reading rather
     than a proven one.

     Corpus check: '|h' has ZERO uses across the 116 shipped scripts, so
     no real content depends on this either way.

     Scope note: the FSM accumulates parameters to the closing '|', so a
     wrong arity never desynchronised the frame.  The damage was confined
     to misreading fields within the one command — wrong picture, right
     stream position.

D-3  RESOLVED 2026-08-12.  '!' TRIGGERED ANYWHERE IN A LINE.
     The IDLE handler entered GOT_BANG on any '!', not only at a line
     boundary, so ordinary prose containing an ANSI sequence followed by
     '!' parsed as a command.  The spec-sanctioned way to start a scene
     mid-line is the SOH/STX introducer; that is implemented, and the
     relaxation was withdrawn with it — src/ripscrip.c now admits '!'
     only at a line boundary (state 0, "'!' introduces a command ONLY at
     a line boundary").  Tracked as X5.

D-4  '|28' GRADIENT IS RIPlib-ORIGINAL, NOT INHERITED.
     Severity: documentation only — corrected in segment 6A.

---------------------------------------------------------------------
12.13  CLASS G — RIPSCRIP.HLP, THE DRIVER'S OWN NAME TABLE
---------------------------------------------------------------------

Added 2026-08-12.  The RIPtel 3.1 install ships RIPSCRIP.HLP alongside
the driver.  Despite the extension it is not a WinHelp file: it opens
"RIPscrip Help File Resource" and contains two ordered tables the driver
indexes at runtime —

     * the complete ERROR MESSAGE table, and
     * a 93-entry FUNCTION NAME table, grouped by command level and
       alphabetical within each group.

This is a THIRD independent evidence class, and the strongest one for
naming: unlike the string-table method (class B) it covers handlers that
emit no diagnostics at all.  It was overlooked until late because the
analysis had been working from the DLL alone.

     PROVES:     which commands exist, by name, per level.
     PROVES NOT: the letter each name binds to.  The table is
                 alphabetical, not dispatch-ordered, so it must be
                 cross-referenced against the dispatch table.

Cross-referencing it closed three handlers that the binary alone could
not name, and independently confirmed several earlier identifications
(RIP_Point = '|j', RIP_CopyBlit = '|1g', RIP_ImageStyle = '|1i'):

  |1k   RIP_KillEnclosedMouseFields.  The Level 1 group carries both
        RIP_KillMouseFields (the plain '|1K') and this one.  The handler
        (RVA 0x00C474) matches exactly: it orders the coordinate pairs,
        applies the same transform '|j' uses, assembles a RECT via
        USER32!SetRect and passes it onward inside the drawing lock/dirty
        bracket.  IMPLEMENTED — kills the mouse fields wholly enclosed by
        the rectangle, the selective counterpart to '|1K'.

  |2Y   RIP_SwitchStyle.  The Level 2 group has exactly twelve names and
        eleven were already bound; RIP_SwitchStyle was the remainder, and
        its (slot:1, flags:2) shape matches the other Switch* commands.
        IMPLEMENTED as the graphics-style slot selector.

  |3ESC RIP_EnterBlockMode, confirmed by a name-string reference inside
        the handler's tight bounds (0x024B4E..0x0251CB).

CROSS-CHECKED against bbs-land/remote-imaging-protocol 2026-08-12.  They
mined the same help resource independently (their
version/3.0/research/riptel-help-extraction.md), which makes their
reading a genuine second opinion rather than a restatement.  Results:

  CONFIRMED, with a correction we needed.  Their 2.0 command reference
  binds RIP_KILL_ENCLOSED_MOUSE_FIELDS to Level 1 letter 'k' with
  arguments 'x0:XY y0:XY x1:XY y1:XY flags:4' — matching the binding
  derived here.  Crucially it also documents the flags field, which the
  binary alone did not reveal:

       1  kill only fields completely contained
       2  kill only fields that intersect the rectangle
       4  kill fields entirely outside the rectangle
       "If 1, 2 and 4 are not present, then NO fields are deleted."

  A first implementation here ignored the flags and always killed the
  contained set — which destroys fields on a command whose documented
  behaviour with flags=0 is to destroy nothing.  Now corrected.

  CONFIRMED.  '|1c' RIP_SET_MOUSE_CURSOR, 'cursor_style:2 res:4'.
  CONFIRMED.  RIP_SwitchStyle is one of the switchable data tables,
  supporting the '|2Y' binding.
  CONFIRMED.  RIP_EnterBlockMode is a real wire command (they cite
  2.00a4 and SyncTERM ripper.c:17069), supporting '|3ESC'.

  INVALIDATED — a speculation recorded here was wrong.  RIP_ProcessFile
  and RIP_AudioSupport are NOT wire commands: they are entries in the
  client-side DLL API that RIPTEL.EXE imports.  So the earlier note that
  '|3D' at 0x024AF4 might be RIP_ProcessFile does not stand, and the
  premise behind it — that every remaining Level 3 NAME must bind to a
  remaining Level 3 LETTER — is false.  Several of the 93 names are host
  API and never appear on the wire at all.

  NOT RESOLVED BY THEM EITHER.  bbs-land lists the same Level 3 names
  without opcodes, and states outright that RIP_SwitchDirectory's "wire
  opcode is unknown".  Two independent reconstructions working from the
  same help resource and the same binary both stop here.

RECIPROCAL AUDIT — their reference checked against the dispatch table.

Every command row in their 3.0 reference was compared against the
driver's own dispatch entry (letter, arity, argument widths).  Findings,
in both directions:

  THEIR NOTATION IS BETTER THAN OURS.  Most apparent mismatches were an
  artefact of this side's parser, not their errors: they write widths as
  'CM' (colour-mode dependent) alongside 'XY' (coordinate-size
  dependent), which is exactly what the driver's own 'color' and 'XY'
  argument-type bytes mean.  Once decoded that way, '|c', '|S' and the
  rest agree with the binary exactly.  A model that only understood
  fixed digit counts under-reads the protocol.

  '|3e' — THEY RESOLVE ONE OF OURS.  Their reference binds level 3 'e'
  to RIP_BAUD_EMULATION (evidence 2.A0), and RIP_BaudEmulation is in the
  driver's function-name table.  This segment previously carried '|3e'
  as style-slot protection, on diagnostics that had bled in from a
  neighbouring handler under loose bounds.  Corrected, and implemented.

  '|1A' — WE RESOLVE ONE OF THEIRS.  Their reference carries a row
  literally titled "1A (unidentified)", noting "6 digits observed
  (layout unresolved)".  The handler at RVA 0x00DC58, bounded tightly by
  the next entry (62 bytes), pushes BOTH 'Invalid article number' and
  'RIP_SelectArticle()'.  It is RIP_SelectArticle, and its dispatch
  entry records mega2 + mega4 = 6 characters, matching their corpus
  observation exactly.  Worth sending upstream.

  THE Switch* WIDTHS — RESOLVED 2026-08-12, IN THE DISPATCH TABLE'S
  FAVOUR.  This was recorded as unresolved in both projects.  Their
  reference documents '|2s' as 'port-num:1 flags:2 res:3' (6 chars)
  where the dispatch entry records mega1 + mega2 (3), and '|2T' as
  'window_num:1 res:1' (2) against 3.  The note allowed that both could
  be true if trailing reserved bytes were consumed outside the template.

  They are not.  The shipped corpus contains three '|2s' commands and
  every one of them is THREE characters:

       !|2s000     port 0, flags 0
       !|2s002     port 0, flags 2
       !|2s100     port 1, flags 0

  There is no res:3.  The dispatch entry is complete, the whole Switch*
  family is uniformly mega1 + mega2 (slots 111, 112, 114, 118, 119, 121
  all agree), and RIPlib's reader — port:1 then flags:2 — is correct as
  written.  Worth sending upstream: a consumer that trusts the
  6-character layout will over-consume three bytes and desynchronise the
  rest of the frame.

  Method note: this is the second question this session settled by
  measuring the corpus rather than reasoning about the binary, after
  D-1.  Where vendor content exercises a command, it outranks both
  documents.

  ONE OPEN ITEM ON THIS SIDE — SINCE RESOLVED.  '|F' RIP_FILL showed
  argc=0 at RVA 0x01B2FD, one byte before '|G' at 0x01B2FE, and was
  guessed to be a thunk or a mis-parse.  It is neither: 0x01B2FD is a
  bare 'ret', the tail of the preceding function, so THE 3.0 DRIVER
  STUBS OUT FLOOD FILL.  Their 'x:XY y:XY border:CM' is still the right
  reading for the WIRE, and RIPlib implements it that way; the driver
  simply declines to act on it.  See D-9.

So the two '|3D' entries remain unbound ('|3e' is now resolved).  Established: '|3D' at
0x024AF4 copies its text argument into a 256-byte buffer and calls a
routine referencing "ICONS"; '|3D' at 0x038BD2 is a 15-byte thunk.  None
appears in the 116-file corpus.  They stay recorded rather than guessed,
and that is now a position two projects share rather than a gap unique
to this one.


---------------------------------------------------------------------

D-8  '|1k' AND '|3D' — HOW FAR THE ANALYSIS ACTUALLY GOT.
     Recorded 2026-08-12 after these were re-examined.  An earlier draft
     called their semantics "not recovered", which overstated the effort
     spent: the dispatch entry and the absence of a diagnostic string had
     been checked, but the handlers themselves had not been read.  They
     have now been read, and the honest position is:

     '|1k'  (RVA 0x00C474, 5 args: XY,XY,XY,XY,mega4) — SUBSTANTIALLY
            recovered.  It orders the two coordinate pairs, applies the
            same world/device transform '|j' uses (RVA 0x10031084),
            assembles a RECT via USER32!SetRect, and passes that rect plus
            the 4-digit argument to RVA 0x10012D63, bracketed by the same
            lock/dirty pair the drawing commands use.  So it is a
            rectangle operation with a 4-digit parameter.  What 0x10012D63
            actually does is not established: it references no strings, so
            naming it needs semantic tracing rather than string mining.

     '|3D'  RESOLVED 2026-08-12 — see below.  The earlier position, that
            both handlers "reference NO strings at all" and nothing beyond
            the dispatch entry was established, was true only of STRING
            evidence.  Following the CALL TARGETS settled it, and resolving
            the driver's import table named the decisive one.

            Slot 122 (RVA 0x038BD2) is a five-instruction thunk that hands
            arg[0] to 0x100282CA, which busy-waits on WINMM!timeGetTime.
            Its arithmetic fixes the unit beyond doubt: the count is split
            into chunks of 3900 with 0xFDE8 = 65000 ms waited per chunk
            (3900/60 = 65 s), then the remainder waited as
            remainder * 1000 / 60 ms.  So '|3D' is RIP_DELAY and its field
            is in SIXTIETHS OF A SECOND.

            Slot 125 (RVA 0x024AF4) is a different command that happens to
            share the letter.  It copies a TEXT parameter into a 256-byte
            buffer, looks it up via 0x1003F71A, calls 0x1003F80E with the
            result, and on a return of 2 calls 0x10006C01 — which names
            itself RIP_Suspend() in its own error path.  It never reads the
            decoded argument array, so it does not match its argc=1/mega4
            row; that row is the mis-associated one.  What it looks up is
            not established, and it is NOT the reading RIPlib implements.

            RIPlib implements the slot-122 reading and deliberately does
            NOT busy-wait: a rendering library that blocks its caller for
            up to 65 seconds per chunk is unusable on the cooperative and
            single-threaded hosts RIPlib targets.  The request is recorded
            and handed over by rip_take_delay(); ignoring it is safe,
            because a delay is a pacing hint and not a rendering
            instruction.

            METHOD NOTE.  Three evidence classes had already been tried on
            these handlers and all three came up empty, because every one
            of them keys on STRINGS.  What worked was resolving the import
            directory and reading call targets — the same pass also
            confirmed GDI32!Polygon as the skewed-oval renderer (12.14).
            Where a handler names nothing, name what it CALLS.

     Both are absent from the shipped corpus, so no vendor content
     exercises them.  '|3D' is now implemented as RIP_DELAY; '|1k' is
     implemented with the flags semantics bbs-land documents, and only
     the identity of 0x10012D63 remains open.  That residue is a bounded,
     evidenced gap — not an unknown, and not a claim of completeness.

     Corpus note: this entry and several others said "116-file corpus".
     The RIPtel 3.1 installation examined here ships 35 .RIP scenes
     (scripts/corpus-scan.py; 12,328 command instances, 70 distinct
     opcodes).  Where 116 appears in older text it refers to a larger
     collection catalogued elsewhere, not to what was measured.

D-5  RESOLVED 2026-08-12.  FOUR DRIVER COMMANDS WERE UNIMPLEMENTED.
     Measured by diffing the dispatch table against RIPlib's handler
     switch.  Of 73 Level-0 commands in the driver, RIPlib implemented
     69.  The four missing were:

          |j   2 args (XY, XY)      — unnamed in the string table
          |r   3 args               — RIP_TextMetric
          |x   var                  — FILLED_POLY_BEZIER (the unfilled
                                      'z' form was already implemented)
          |y   11 args              — RIP_ExtendedFontStyle

     All four are now implemented.  '|y' was the significant one: it is
     the driver's real extended font-style command, and RIPlib had
     extended font style on '|d' — which the driver uses for
     RIP_OneDrawingPalette (see 12.8, B6).  Both halves of B6 are now
     corrected: '|d' is a palette command and '|y' carries extended font
     style, in the 26-character layout that independently matches
     bbs-land's reading.

     The corpus census (scripts/corpus-scan.py) confirms full Level-0
     coverage: all 70 distinct opcodes across 12,328 command instances
     in the 35 shipped scenes reach a handler.

D-6  MITIGATED 2026-08-12; ONE DECISION LEFT.  The mapping is now
     RIPLIB_PALETTE_BASE (include/riplib_platform.h), overridable at
     configure time, range-checked so the 16 EGA entries must fit in
     0..255, and documented with the reason the offset exists.  A port
     that owns its framebuffer builds with -DRIPLIB_PALETTE_BASE=0 and
     gets identity mapping.  So the policy is no longer baked in.

     What remains is the DEFAULT, which is still 240 — the value the
     first consumer needed.  Flipping it to 0 would make the neutral
     choice the default, but it silently changes every pixel value a
     current consumer receives, so it is a deliberate release decision
     rather than a cleanup.  Recorded, not taken.

     Original text follows.

     '§A2G.6' BAKES A HOST POLICY INTO THE LIBRARY.
     src/ripscrip.c:212 maps every EGA index to framebuffer value
     240 + idx, justified in segment 6 by a conflict with "the xterm-256
     color palette used by the VT100/ANSI text renderer".  That is an
     assumption about the HOST's text renderer sharing the framebuffer,
     not a property of RIPscrip.  A consumer with a plain 16-colour
     framebuffer receives indices 240-255 it never asked for.  This is a
     platform-independence violation in the same family as the branding
     leaks, but structural rather than cosmetic, so the branding lint
     cannot see it.

D-7  'riplib_host_tx' CARRIES CONSUMER TERMINOLOGY IN THE PUBLIC API.
     include/riplib_platform.h:88.  One of exactly three functions every
     port must implement, and its name says "card".  Renaming is a
     breaking API change and therefore a v2.0.0-shaped decision.

D-9  WITHDRAWN 2026-08-12, THE SAME DAY IT WAS RAISED.  It alleged
     "the dispatch parser mis-types some arguments".  Both symptoms were
     re-checked against the raw table bytes and both are FAITHFUL
     RECORDS; the extractor is correct and the defect does not exist.
     Recorded rather than deleted because blaming one's own tooling for
     an accurate reading is a mistake worth leaving visible.

     Symptom 1, '|&' (slot 3) typed XY, XY, mega2, mega2, mega2.  The
     raw entry really is ff ff 02 02 02.  The apparent contradiction
     with the handler — which hands (arg0,arg1) AND (arg2,arg3) to the
     coordinate mapper at 0x10031084 — is not a contradiction, because
     the two things describe different layers:

          the TYPE byte gives the WIRE WIDTH (how many digits to read)
          the coordinate mapper is SEMANTIC (scaling after decode)

     A radius is a coordinate-like quantity that gets scaled, and it can
     still be transmitted as a fixed 2-digit MegaNum.  '|&' does exactly
     that; '|-' (ff ff ff ff 02) transmits its radii at coordinate
     width.  At the default coordinate size of 2 both encode to the same
     10 characters, which is why TeleGrafix's demo shows an identical
     payload shape for the pair.  See D-11 for what that costs.

     Symptom 2, '|F' RIP_FILL at RVA 0x01B2FD with argc=0, one byte
     before '|G' at 0x01B2FE.  0x01B2FD disassembles to a single 'ret'
     — it is the tail of the preceding function, and 0x01B2FE is a real
     'push ebp' prologue.  So the entry is accurate and the finding is
     about the DRIVER, not the table:

          THE 3.0 DRIVER STUBS OUT FLOOD FILL.  '|F' is dispatched, so
          the letter is recognised and its frame consumed, but the
          handler returns immediately.  Slot 27 is the only Level 0 row
          whose handler is a bare 'ret'; the other argc=0 rows ('E'
          RIP_ERASE_VIEW at 0x01ad6f, 'e' RIP_ERASE_WINDOW at 0x01ad98,
          Level 1 'K' at 0x00c543) all have real prologues.  No shipped
          scene uses '|F'.

     RIPlib implements '|F' as the 1.54 specification defines it
     (x:2 y:2 border:2), matching SyncTERM and IcyTerm, and that stays.
     A 3.0 driver declining to flood-fill is not a reason for a library
     that also serves 1.54 content to drop the command.  Note that
     RIPlib once changed '|F' to take zero arguments on the strength of
     this very argc=0 reading, described in the code as "DLL internal
     behavior"; that change was later reverted against the spec.  This
     entry explains what was actually being observed.

     Consequence: argument type bytes AND counts in segment 13 are
     records of the binary and have held up under every check made.
     Where a handler's behaviour appears to disagree, expect a
     wire-versus-semantics distinction like symptom 1 before suspecting
     the table.

D-11 RESOLVED 2026-08-12.  COORDINATE WIDTH WAS RECORDED BUT NOT
     HONOURED.  The dispatch record types many arguments 0xFF ("width per
     SET_COORDINATE_SIZE") and a few 0xFE ("width per SET_COLOR_MODE"),
     and the driver resolves both at decode time (resolver at RVA
     0x039DE0).  RIPlib parsed '|n' into rip_state_t.coordinate_size and
     then read fixed 2-digit fields at fixed offsets in 262 places, so a
     stream selecting any other width desynchronised from its first
     coordinate.

     FIXED BY NORMALISING THE PAYLOAD, not by rewriting 262 call sites.
     Before dispatch, when the negotiated widths are not the default, the
     command's payload is rewritten so every argument is two digits and
     the handlers never see the difference.  scripts/dll-argtypes.py
     emits the per-command type table this needs; only the 56 commands
     that actually contain a 0xFF or 0xFE argument are carried, because
     a command whose widths are all literal is already correct.

     Properties worth stating, because each was a bug on the way here:

       - Literal-width fields are copied VERBATIM at their own width.
         Re-emitting a mega1 or mega4 field as two digits corrupts it.
       - The rewrite is in place, which is safe only because coord_w >= 2
         means the negotiated fields shrink and literals do not move.  No
         scratch buffer, so nothing lands in the dispatcher's stack frame
         — an earlier version used a 1 KB local, GCC inlined it, and
         execute_rip_command went from 648 bytes to 1416.
       - The type list is MEASURED before anything is written.  Bailing
         out mid-rewrite leaves a half-converted payload, which is worse
         than not trying; the first version did exactly that and the
         existing metadata tests caught it.
       - With the default width the whole path is skipped, so the common
         case is byte-for-byte unchanged.

     LOSSY ONLY ABOVE 1295, the largest value two digits hold.  That is
     acceptable for RIPlib specifically: it renders into a fixed 640x400
     device space and deliberately does not apply a world-to-device
     transform (D-1), so a coordinate above 1295 is off-screen whatever
     width carried it.  A port that grows a world transform must revisit
     this rather than inherit it.

     rip_state_t.coord_size_unsupported remains, and is now cleared when
     a command is successfully normalised, so it means what it says: a
     width this build could not handle.

D-28 THE CORPUS COUNTED ITS REQUESTS AND NEVER READ THEM.  Recorded
     2026-08-13.

     D-24 added region counting because the harness measured only what it
     rendered.  The same reasoning, applied one level down, exposes a
     second blind spot in the metric that D-24 produced: the harness
     counts asset requests and has never looked at what they ASK FOR.

     That is not hypothetical.  It is exactly the defect this corpus
     carried.  '|1b' read its filename four characters early and asked
     the host for "0000back.bmp" in all 36 of its appearances, and '|1R'
     for "00000000dragon.txt" in all 25 of its own -- while this harness
     reported 35/35 scenes clean.  Demonstrated rather than argued: with
     the old '|1b' offset re-injected today, every scene still passes and
     every count is identical.  A metric that cannot move cannot regress,
     and a count is blind to a value by construction.

     The names are now reported alongside the counts.  With the same
     regression injected, the difference is unmissable:

          DRAGON.RIP   STRIP6,GODRAG3,TORCH,DRAGON,BACK
          DRAGON.RIP   0000STRIP6,0000GODRAG3,0000TORCH,DRAGON,0000BACK

     REPORTED, NOT ASSERTED, which is deliberate.  A name change is a
     metric moving, not an invariant breaking, so it belongs in the diff
     beside the pixel and colour counts -- the same register those use.
     An assertion was drafted and rejected: the obvious one, "no
     requested name begins with a run of digits", false-positives on
     256COLOR, a real asset in this corpus.  A check that fires on
     correct content is worse than no check.

     TWO ANOMALIES THE VALUES IMMEDIATELY SURFACED, neither visible to
     any count:

     '|1b' IN N2_BUSI.RIP REQUESTS "BMP".  Its payload is
     "VU14YY260001.back.bmp" -- 21 characters, where slot 88's fixed
     prefix alone is 18.  The other '|1b' in the same file is well formed
     at 26.  Taking the filename at 18 therefore yields "bmp", the tail
     of the extension.  This is RIPlib parsing a MALFORMED command in
     shipped content faithfully; the driver, reading the same record,
     would do the same.  Recorded as content, not as a defect.

     '|1R' IN NEWSPAPR.RIP REQUESTS "$&MAIN_STORY".  Its payload is
     "00000000$&MAIN_STORY$" -- the eight-zero prefix is correct and the
     filename is a VARIABLE REFERENCE.  rip_expand_variables() is applied
     to rendered text and to <<IF>> expressions, and to no filename
     argument anywhere.  So the request goes out as the literal text.

     This is the same shape as D-26, one command over: an argument that
     needs a preprocessing pass the parser applies elsewhere and not
     here.  ARBITRATED AND FIXED, same day.

     THE SCANNER.  0x04B0E4, identified by the two `cmp ..., 0x24` it
     turns on.  Found by differential rather than by guessing: intersect
     the calls of '|@' and '|T' (which certainly interpolate) with those
     of '|1R', subtract everything five numeric-only commands call, and
     exactly one routine survives.

     WHICH ARGUMENTS.  Twelve dispatch entries reach it -- '|"' '|1R'
     '|1b' '|1e' '|1p' '|1w' '|3G' '|@' '|T' '|r' '|y' directly, and
     '|1U' one call deep.  RIPlib ran that path for TEXT only, so
     filenames and the GotoURL argument passed through verbatim.

     '&' IS NOT A SIGIL, which the shape invites one to assume.  The
     driver's scanner compares against '$' alone and RIPlib has no '&'
     handling either, so "$&MAIN_STORY$" is a variable simply NAMED
     "&MAIN_STORY".  Both implementations already agree; nothing special
     was needed, and recording that saved inventing a rule for it.

     Fixed for '|1R' and '|1b'.  Expansion runs BEFORE the filename
     safety check, never after, so a name assembled from a variable is
     still subject to it.  A name without '$' expands to itself, so
     covering '|1b' -- 36 corpus uses, none currently parameterised --
     costs nothing and prevents the next scene that does parameterise it
     from silently failing.

     IMPACT, precisely.  13 of the 25 '|1R' payloads contain '$', but 11
     of those are the <<IF $COLORS$...>> conditionals D-26 already
     handles.  The two in NEWSPAPR.RIP still resolve to the literal
     text, because the variable is UNDEFINED in the scene -- the host
     supplies it -- and an unrecognised token is emitted as a literal by
     design.  The mechanism is proven by test rather than by that scene:
     define a variable, reference it in a '|1R' filename, and the
     expanded name is what reaches the request queue.

     AND THE INSTRUMENTS BROKE, which is the part worth keeping.  Both
     audit scripts hardcoded the switch-block line ranges.  Adding the
     expansion helper shifted every case label below it, '|3e' fell
     outside its own window, and the claim validator reported it
     UNVERIFIED rather than passing it -- exactly the behaviour it was
     built for, catching a fault in itself.  The ranges are now derived
     from structural markers (`if (s->is_level3)` and its siblings) that
     move with the code.  Verified the derived ranges still refute an
     injected '|3e' regression.

D-27 A COMMENT THAT WAS WRONG TWICE OVER, AND THE CHECK THAT SHOULD
     HAVE CAUGHT IT.  Recorded 2026-08-13.

     Above the Level 0 Line case sat this note:

          DLL command table entry 16: '@' = RIP_PIXEL (2 args: XY,XY).
          An earlier RIPlib draft incorrectly mapped 'X' to RIP_PIXEL --
          'X' is not in the DLL command table.  '@' is the correct
          command letter.

     Both of its factual claims are false, and it was not attached to the
     case it described.

     '@' IS NOT RIP_PIXEL.  Slot 16's handler (RVA 0x020CBC) pushes
     "RIP_TextXY()" before its own diagnostics -- "Can't draw to a
     disabled viewport", "Unable to allocate temp string", "$TEXTDATA$".
     It is the text command.  Its record reads XY, XY with argc 2, which
     looks too narrow for text until D-16 is applied: the string is
     passed out-of-band and never appears in the record, so an argc of 2
     is exactly what a command taking two coordinates and a string looks
     like from the table alone.

     'X' IS IN THE TABLE.  Slot 70, record XY, XY, handler RVA 0x01E1D1,
     which calls GDI32!SetPixel.  It is the pixel command, and the letter
     is therefore confirmed from the driver rather than resting on the
     1.54 specification alone.

     THE CODE WAS RIGHT THROUGHOUT.  RIPlib has implemented '@' as
     RIP_TEXT_XY and 'X' as RIP_PIXEL all along; only the note was wrong.
     It had evidently been written during an earlier correction, left
     behind when the cases moved, and then stated with enough confidence
     to be believed.  Removed, and both cases annotated with the handler
     evidence that settles them.

     THE PATTERN, which is the reason this record exists at all.  This is
     the FOURTH documentation defect of one shape found in a single day:

          '|1I'  a field list still describing the defect after the fix
          '|y'   "is not implemented yet", written before it was
          '|3e'  a section calling the code an accept-both compromise
                 for a day after the compromise had been removed
          '|@'   the note above

     Every one was found by accident, while looking for something else.
     Three of them had been read and believed in the course of this same
     audit -- the '|3e' paragraph was quoted back as an open item in a
     status report hours after the code had stopped matching it.  A
     document that describes code becomes, once stale, a MORE confident
     source than the code, because it states a conclusion where the code
     only shows behaviour.

     THE CHECK.  scripts/dll-validate-claims.py states each load-bearing
     claim as a predicate and re-derives its evidence from the image, the
     corpus and the source, reporting the ones that no longer hold.  It
     is adversarial by construction: it tries to REFUTE, and a claim it
     cannot re-derive is reported UNVERIFIED rather than passed.  Forty-
     two claims at the time of writing:

          handler self-naming        |1G |1g |1M |1U |; |@ |2P
          field bounds a handler     mode <= 6, mode <= 5, marker < 36,
            guards with a diagnostic rotation < 360, font <= 10,
                                     colour <= 63
          the fixed-radix sets       base 64 = |D |d |h |y
                                     base 36 = |J |N
          string-tail prefix widths  nine commands, each against the
                                     sum of its own record
          corpus populations         |k |1b |1R |1e |2s
          current source behaviour   eleven statements, including three
                                     NEGATIVES -- |3e no longer falls
                                     back to mega4, |2P no longer sets
                                     flags from wire bits 2-3, and the
                                     protection word has no dispatched
                                     writer

     Negatives matter more than the rest.  A positive claim decays into
     a false negative when the code moves; a negative claim is what
     catches a defect being REINTRODUCED, which is the failure this
     project actually had.  Verified to fail on all three axes:
     re-injecting the '|3e' compromise, the '|2P' wire-bit mapping, or
     the unguarded memcpy each refutes exactly the claims it should and
     the tool exits non-zero.

D-26 THE D-25 FIXES, CONFIRMED AGAINST SHIPPED CONTENT -- AND ONE
     QUESTION THEY EXPOSED.  Recorded 2026-08-13.

     A unit test proves a fix against a payload someone wrote.  The
     corpus proves it against payloads TeleGrafix wrote.  Replaying
     DRAGON.RIP through v2.0.2 and through the current tree and printing
     the asset names each asks the host for:

          v2.0.2            now
          0000STRIP6        STRIP6
          0000GODRAG3       GODRAG3
          0000TORCH         TORCH
          00000000DRAG      DRAGON
          0000BACK          BACK

     Five requests, every one of them wrong before and right after.  The
     fourth is '|1R' and the rest are '|1b'; note that "00000000DRAG" is
     what "dragon.txt" became once eight reserved digits were prepended
     and the result truncated to the name limit -- the corruption was
     bad enough to lose the real name entirely.

     NO RENDERING CHANGED.  Comparing all 35 scenes between v2.0.2 and
     the current tree: zero differences in foreground pixels or colour
     counts, and the same 61 asset requests.  Everything landed in the
     non-rendering paths -- filenames, regions, flags -- which is exactly
     where the pixel metrics could not see it (D-24).

     ONE QUESTION LEFT OPEN, recorded rather than guessed.  BUTTONS.RIP
     sends a '|1R' whose filename is a CONDITIONAL:

          !|1R00000000<<IF $COLORS$<"256">>BLUEBACK.FN
              <<ELSE>>BLUEFADE.FN<<ENDIF>>

     RIPlib's <<IF>> preprocessor is a stream-level state machine that
     suppresses output between directives; it does not evaluate a
     conditional sitting INSIDE a command payload.  So the request goes
     out as the literal text "<<IF $COLORS", where the driver would
     presumably resolve it to BLUEBACK.FN or BLUEFADE.FN by colour
     depth.  The offset fix is orthogonal and correct -- DRAGON.RIP
     above has no conditional and is now exact -- but this scene's font
     request is still wrong, for a different reason.

     DIAGNOSED 2026-08-13.  The scope question above is answered, and
     the answer is a case distinction that the corpus makes cleanly.

     UPPERCASE IS A DIRECTIVE; lowercase IS LITERAL TEXT.  Across the
     shipped scenes:

          <<IF>> <<ELSE>> <<ENDIF>> <<ELSEIF>>   14/13/14/1 uses,
              all inside '|1R' payloads -- BUTTONS.RIP, CURVES.RIP,
              SPECLEFX.RIP -- selecting a FILE by colour depth

          <<if>> <<else>> <<endif>>              19 uses each,
              all inside '|1M' host-command text, which the HOST
              evaluates when the region is clicked

     The split is exact: no uppercase directive appears in host text and
     no lowercase one in a filename.  The driver's own diagnostics are
     uppercase too ("Misplaced ENDIF pre-processor directive",
     "%d too many ('s in ELSEIF pre-processor"), and its preprocessor is
     a subsystem of its own at RVA ~0x04CF, far past the last dispatch
     handler.  So the tension recorded above was never real: expanding
     uppercase directives cannot touch the lowercase host text.

     RIPlib ALREADY MATCHES CASE-SENSITIVELY -- strncmp(dir, "IF ", 3)
     -- so its recognition is right.  Two things stop it working:

     (a) THE PREPROCESSOR RUNS ONLY IN RIP_ST_IDLE.  Once the FSM enters
         a command, bytes go to command accumulation and the '<<' scanner
         never sees them.  Confirmed directly: feeding
         "!|1R00000000<<IF 1=1>>yes.txt<<ELSE>>no.txt<<ENDIF>>" requests
         the literal "<<IF 1=1>>YE", while the same conditional wrapped
         around whole commands resolves correctly.

     (b) AN UNRECOGNISED DIRECTIVE IS SWALLOWED, not emitted.
         preproc_finalize_directive() matches IF / ELSE / ENDIF and falls
         through to `s->preproc_len = 0` for anything else.  So simply
         extending (a) into command payloads would EAT '|1M's lowercase
         <<if $RETURN$...>> host commands -- a regression in the same two
         scenes the change is meant to fix.

     THE FIX IS THEREFORE TWO PARTS, and (b) must come first:

         1. emit an unrecognised << ... >> run verbatim instead of
            discarding it -- a correctness improvement on its own, since
            today any <<foo>> in display text silently vanishes;
         2. run the scanner during command accumulation, routing its
            output to whichever consumer is active (cmd_buf inside a
            command, VT100 or the text window at IDLE).

     APPLIED 2026-08-13, both parts.

     rip_process() is now a filter: it runs the << >> scanner for every
     byte and hands whatever survives to rip_dispatch_byte(), which is
     the old rip_process with the scanner lifted out of its IDLE case.
     Splitting them is what lets a directive be recognised inside a
     payload; nothing else about the state machine moved.

     Three consequences, each of which had to be got right:

       - preproc_finalize_directive() emits an unrecognised << ... >>
         run VERBATIM, delimiters included.  Without this the rework
         would have deleted all 19 lowercase <<if>> host commands.

       - the lone-'<' false alarm now RE-DISPATCHES instead of writing
         to the VT100 or text window directly.  The old emit was correct
         only at IDLE; inside a command it would have dropped the
         character rather than putting it in cmd_buf.

       - the suppression check moved with the scanner, so a false branch
         now suppresses command bytes too, not only idle text.

     RESULT, against shipped content:

          BUTTONS.RIP   "<<IF $COLORS"  ->  BLUEFADE
          CURVES.RIP    "<<IF $COLORS"  ->  BLUEFADE
          |1M host text  <<if $RETURN$!="">>$<<RETURN>>$<<else>>...
                         preserved byte for byte, 20 regions unchanged

     VERIFICATION.  All 35 corpus scenes: zero differences in foreground
     pixels, colour counts, asset-request counts or region counts
     against the commit before the rework -- the only thing that changed
     is which file the two conditional scenes ask for.  300 unit tests,
     5 suites, clean under UBSan+ASan, 400k fuzz iterations clean,
     conformance clean.  execute_rip_command's stack is unchanged at 656
     bytes; the byte path costs 24 bytes more for the extra frame.

     Both halves carry a regression test, and both were checked for
     teeth: the payload-directive test fails against the pre-rework
     tree, and the verbatim test fails when part (b) alone is disabled.
     The second is worth noting -- it passes against the OLD code too,
     because the old scanner never saw those bytes at all, so it guards
     the new path rather than a historical defect.

D-25 THREE MORE STRING TAILS READ EARLY, FOUND BY AN ASSERTION ABOUT
     SILENCE.  Recorded 2026-08-13.

     D-24 counted mouse regions because pixel metrics could not see the
     interaction fixes.  Applying the same reasoning to the other
     non-rendering output -- host traffic, which the corpus harness
     stubbed away entirely -- turned it into an assertion rather than a
     statistic:

          passively rendering a scene must send NOTHING to the host

     That is a security property, not a style preference.  RIPlib's
     posture is that untrusted content cannot make the terminal act on
     its own; it never launches a URL and never touches the filesystem,
     and it must not open its mouth to the BBS either.  Host traffic is
     a RESPONSE -- to a click, to a query the host began, to a file the
     host asked about -- and none of that happens during replay.

     34 of 35 scenes passed.  NEWS.RIP did not.

     '|1A' RIP_PLAY_AUDIO READ ITS FILENAME AT 4, NOT 6.  Slot 86
     records mega2 + mega4; the comment said "mode:2 res:2" and the code
     matched the comment.  NEWS.RIP sends "|1A010000" -- exactly the six
     fixed characters and no filename at all -- so RIPlib took "00" as
     the name and pushed a sound request for a file called "00".

     Chasing the class then found two more, neither reachable by the
     offset audit: that check looks at mega*() decodes, and a string
     tail is a `p + N` pointer, not a decode.

     '|1b' RIP_LoadBitmap READ ITS FILENAME AT 14, NOT 18.  This is the
     one that matters.  Slot 88 records XY, XY, XY, XY, mega1, mega1,
     mega2, mega2, mega4 = 18, and the corpus confirms it exactly:

          BUTTONS.RIP  "VU0QYY1S0000000000back.bmp"
                        ^---- 18 fixed ----^^ name ^

     RIPlib asked the host for "0000back.bmp".  THIRTY-SIX '|1b'
     commands ship in the corpus, every one of them requesting a name no
     host could match -- in the command that loads the artwork.  Same
     defect as '|1R' (D-19), and it survived that pass because D-19
     enumerated string-tail commands by hand and this one was not on the
     list.

     '|1W' RIP_WRITE_ICON used a HEURISTIC instead of the record: it took
     the whole payload as the name and stripped a leading "00" if it
     happened to see one.  Slot 108 records one mega1, so the name
     starts at offset 1 -- the heuristic strips two where the record
     says one, and strips nothing when the reserved digit is not '0'.
     No corpus scene sends '|1W'.

     '|1Z', '|1N' and '|1O' have NO dispatch entry at all, so there is no
     record to check them against; '|1t' and '|1F' were verified correct.

     THE CHECK NOW EXISTS.  scripts/dll-conformance.py gained a
     string-tail class, which is what should have caught all three.  It
     encodes one nuance learned immediately after: a command whose
     trailing string may be EMPTY gates at the fixed prefix exactly (a
     mouse region with no host command, a button with no label), while
     one where an empty string is meaningless gates at prefix+1 ('|1W'
     cannot cache under no name, '|1R' cannot request no file).  Both
     are accepted; anything else is not.

D-24 THE CORPUS REPLAY COULD NOT SEE ANY OF THE INTERACTION FIXES.
     Recorded 2026-08-13.

     The corpus harness measures foreground pixels, distinct colours,
     asset requests, FSM state and the framebuffer guard bands.  Three
     of the defects fixed in D-15 and D-19 change no pixel at all:

          |1U  buttons never registered a clickable region
          |1M  mouse-region flags came from a reserved column
          |1R  every scene-file request asked for the wrong name

     Only the third was visible, and only because asset requests were
     already counted -- which is the same reasoning applied once and
     then not extended.  Mouse regions are now counted alongside them.

     THE NUMBER IS WORTH RECORDING.  Replaying all 35 scenes with and
     without the '|1U' registration fix:

          with the fix        101 regions
          without it           55 regions

     46 buttons across the shipped corpus became clickable, and not one
     pixel moved.  A metric that cannot move is a metric that cannot
     regress: before this, reverting that fix would have left every
     corpus scene reporting PASS with identical numbers.

     The general shape, which has now cost this project three separate
     defects: a renderer's test harness measures what it renders, so
     every behaviour that is NOT rendering -- interaction, host
     requests, state a consumer reads -- is invisible by construction
     unless it is deliberately counted.

D-23 RADIX SELECTION AND LEVEL 2 OFFSETS, BOTH CHECKED MECHANICALLY.
     Recorded 2026-08-13.  No defects; recorded because "no defects" is
     only worth anything when it is reproducible.

     PER-COMMAND RADIX.  D-12 established that the radix is chosen per
     command by a 2-bit field in the flag word at dispatch entry +0x26,
     consulted before the global base byte.  Re-deriving that
     classification straight from the binary reproduces it exactly:

          flag 1  always base 36    '|J' '|N'                 2 commands
          flag 2  always base 64    '|D' '|d' '|h' '|y'       4 commands
          flag 3  follow the global base                     95 commands
          flag 0  unset -- all argc-0, nothing to decode     13 commands

     Checking which decoder RIPlib actually calls for each of the six
     fixed-radix commands: zero mismatches.  '|J' and '|N' use the
     base-36 helpers, '|D', '|d', '|h' and '|y' the base-64 ones.

     This class is worth a standing check rather than a one-off, because
     getting it wrong is silent and total: rip_mega_digit() is
     case-insensitive, so a base-64 field decoded with it folds 'a'..'z'
     onto 10..35 and returns 0 for '#' and '&'.  That is what corrupted
     61 of TUNNEL.RIP's 65 palette entries before '|d' was fixed --
     nothing crashed, the colours were simply wrong.

     LEVEL 2 OFFSETS, MECHANICALLY.  D-17 audited the Drawing Ports
     family BY HAND.  That found '|2P's flags defect, but hand-checking
     is not repeatable -- and it is exactly what let '|2P's invented flag
     bits (D-22) survive in the same handler that was being inspected.
     The offset audit now covers ripscrip2.c as well: seven distinct
     handler bodies (eleven commands; the Switch* family shares one body
     through five fall-through labels), zero flagged.

     Two corrections to that second instrument, both of which would have
     reported false results:

       - Stopping the handler body at the first `break;`, which is what
         the ripscrip.c version does, truncates EVERY Level 2 handler at
         its length gate -- that gate's break is on line two.  Only one
         command got examined before this was fixed.

       - '|2R' composes its mega4 by hand, mega1(raw+0)*46656 +
         mega1(raw+1)*1296 + ..., which is four 1-digit reads spelling
         one 4-digit field.  Correct code, reported as four defects
         until runs of consecutive single digits landing on a record
         boundary were collapsed.

     A STALE COMMENT, found by the radix check.  '|d's comment stated
     that '|y' RIP_ExtendedFontStyle "is not implemented yet".  It was
     implemented on 2026-08-12 under D-5, at Level 0, decoding base 64
     as its flag requires; the note was left behind.  Corrected.  Same
     class as the stale field lists on '|1I', '|1w', '|1M' and '|1T'.

D-22 NON-NUMERIC GUARDS, AND A FLAG MAPPING THAT WAS ONLY HARMLESS
     BECAUSE ANOTHER BUG HID IT.  Recorded 2026-08-13.

     D-21 covered the guards that are a number.  The same extraction also
     surfaced guards that are not -- protection checks, zero-value
     rejections, viewport preconditions, vertex minimums, parameter
     counts, allocation failures -- and those were skipped.  Classifying
     them puts each class to rest at once instead of chasing strings.

     ALREADY MATCHING: '|<' rejects a contour with fewer than two
     vertices (nv < 2), which is the driver's "Must have at least two
     vertices to make a polygon".  The memory class does not apply --
     RIPlib allocates from a fixed arena and has no failure path to
     mirror.

     PROTECTION IS UNREACHABLE FROM THE STREAM, and that is the finding.
     Twelve diagnostics across 24 command sites guard on a protection
     word at <state>+0x104.  Scanning every handler for a WRITE to it
     returns nothing: 41 commands read it, none sets it.  Protection is
     host-side state -- RIPtel's own UI or configuration -- so no RIP
     stream can protect anything, and those guards cannot fire from
     content.  RIPlib's lack of a style/palette/environment/text-window
     protection concept is therefore inert rather than a defect.

     PORT protection is the exception, and RIPlib implements it: port 0
     is permanently protected, '|2s' bits 2 and 3 protect and unprotect
     the source port and bits 0 and 1 the destination, and create and
     delete both refuse a protected port.  The driver's '|2s' really
     does test bl,4 and test bl,8; RIPlib matches it.

     '|2P' HAD '|2s's BIT MEANINGS.  RIPlib set FULLSCREEN from wire bit
     2 and PROTECTED from wire bit 3 in RIP_PortDefine.  That handler
     (RVA 0x0466EC) is a different function and reads only two bits:

          and  eax, 1                  -> passed into port initialisation
                                          (0x1003326F) as a boolean
          test byte ptr [ebp-0x10], 2  -> selects whether the active port
                                          becomes this one

     Bits 2 and 3 are never read there, so inferring FULLSCREEN or
     PROTECTED from them invented behaviour the driver does not have.

     The part worth recording is WHY it never showed up.  Those bits
     could not fire, because the flags field was being decoded from the
     wrong half of a mega4 and always came out zero (D-17).  One defect
     was masking another: fixing the field decode is what armed the
     invented bits, and only then did the mapping matter.  A latent
     defect behind a live one is invisible to every test that exercises
     the live one -- the corpus renders these scenes correctly either
     way.  Fixed together; the regression test sets bits 2 and 3 and
     checks that neither reaches the port.

     Wire bit 0 IS consumed by the driver -- it reaches port
     initialisation as a boolean -- but what it selects there is not
     recovered, so RIPlib does not act on it.  Every '|2P' in the corpus
     sets exactly this bit and nothing else, and those scenes render
     correctly without it.  Recorded rather than guessed.

D-21 VALUE RANGES AUDITED AS A CLASS.  Recorded 2026-08-13.

     The driver validates its fields explicitly and names each failure:

          cmp edi, 6
          jbe ok
          push "Invalid mode parameter"
          push "RIP_Scroll"
          call <reporter>

     Those bounds had been matched only where a handler happened to be
     read for some other reason.  Extracting all of them at once --
     anchoring on the error reporter, whose call sites are preceded by
     the two strings they report, and walking back to the guarding
     compare -- gives the driver's whole validation table.

     A NOTE ON METHOD, because the first attempt was wrong in a way this
     project has already been burned by.  Disassembling a fixed byte
     count from each handler entry runs straight into whatever function
     follows: '|!', a zero-argument handler, came back carrying font,
     palette and text-window diagnostics.  That is exactly how a
     neighbouring handler's strings were once attributed to '|3e'
     (D-16).  Bounding each handler at the next entry in address order,
     and at its own epilogue, fixed it.

     ALREADY MATCHING, verified rather than assumed:

          |;   marker < 36, rotation < 360, flags <= 3   exact match
          |r   mode < 4, domain < 2                      exact match
          |d   index <= 0xFF, bits == 8, rgb <= 0xFFFFFF exact match
          |q   font attributes <= 0x0F                   exact match

     TWO DIVERGENCES, both fixed:

     '|a' RIP_ONE_PALETTE MASKED WHERE THE DRIVER REJECTS.  The handler
     (RVA 0x019BF0) validates the colour with cmp ebx,0x3F / jbe and
     reports "Invalid Color Parameter"; RIPlib applied & 0x3F, which
     folds 64 onto 0 and paints a wrong colour where the driver paints
     nothing.  RIPlib had already made the opposite choice for '|d'
     ("out-of-range values are an error, not something to clamp into a
     wrong colour") and for '|q'; '|a' was the last place still masking.
     Every '|a' in the corpus is in range -- values 2, 9, 20, 52, 54, 59
     and 61 -- so nothing shipped depended on the fold.

     '|Y' RIP_FontStyle DID NOT CHECK THE FONT NUMBER.  The handler
     validates all three fields:

          cmp ebx,0xA    jbe  -> font 0..10  "Illegal font number"
          cmp [ebp-8],1  jbe  -> dir  0..1   "Illegal direction"
          [ebp-0xc] in 1..10  -> size 1..10  (silent reject)

     RIPlib enforced the size and not the font number, so a font the
     driver rejects outright was accepted and fell through to the 8x16
     bitmap fallback -- where the driver keeps the previously selected
     font.  Corpus fonts run 0..10, so nothing shipped is affected.

     DIRECTION 2 AND 3 ARE KEPT.  The driver accepts only 0 and 1;
     RIPlib accepts 0..3, with 2 and 3 as its own vertical-glyph
     directions.  That is a deliberate extension, recorded in
     14-divergence-register.md 14.3, not an unenforced bound -- and the
     corpus uses only 0 and 1, so it displaces nothing.

D-20 LENGTH GATES AUDITED AS A CLASS.  Recorded 2026-08-13.

     Six defects of one shape had been found one at a time -- '|1g'
     gating 12 against a record of 14, '|1i' 12 against 24, the Switch*
     family 1 against 3, '|2p' 1 against 4, '|2W' 9 against 13, '|1R'
     >0 against a prefix of 8.  Each was caught by looking at that
     command for another reason.  Checking the whole table at once found
     fifteen more.

     The rule: a handler's gate should admit exactly its record's fixed
     total.  Looser, and a truncated command is acted on with fields
     read past its end; tighter, and valid input is dropped.  A trailing
     string may legitimately be EMPTY -- a mouse region with no host
     command, a button with no label -- so the gate is measured against
     the fixed prefix, not prefix+1.

     Tightened, each first checked against shipped scenes:

          |1M  13 -> 17     corpus min 28
          |1B  30 -> 36     all 43 uses are exactly 36
          |1P   5 -> 7      corpus 7
          |1b  14 -> 18     corpus min 21
          |1e   8 -> 24     all 14 uses are exactly 24
          |1A   4 -> 6      corpus 6
          |Y    6 -> 8      all 22 uses are exactly 8
          |Z   16 -> 18     all 22 uses are exactly 18
          |1c   2 -> 6      no corpus use
          |1D  >0 -> 5      no corpus use
          |,   12 -> 20     no corpus use
          |.    6 -> 12     no corpus use
          |b   18 -> 20     no corpus use
          |r    2 -> 6      no corpus use
          |=    2 -> 4      corpus min 4 (record is 8; see below)

     NOT tightened, because shipped content contradicts the record --
     the D-18 rule, now applied twice:

          |k   record 2, gate 1.  133 uses: 132 two-character, one
               single-character (N2_BUSI.RIP, "|k0").

          |=   record 8, gate 4.  116 uses: 107 are eight characters,
               2 are seven, 7 are four.  The handler reads progressively
               -- off_draw and style at four, the user pattern at six,
               thickness at eight -- because all three widths are real
               content.  Raising the gate from 2 to 4 is still right: it
               rejects truncation below anything the corpus sends.

     Three test payloads had to be widened, all of them written against
     the pre-audit gates: '|Y' carried three of its four mega2 fields,
     and the mouse-region cap test used a pre-'num' '|1M' layout that
     came out one character short of the record.  The '|D' lesson again
     -- a payload authored to match the implementation tests only the
     implementation.

     NO UNBOUNDED READS.  Nine handlers have no numeric len gate; all
     nine are bounded by other means -- '|3G', '|3R' and '|1R' gate on
     named prefix constants, '|t', '|x' and '|z' dispatch on exact
     lengths 4/5/13 inside rip_poly_bezier_family() matching their three
     signatures, '|1t' checks len >= 1 and its text offset against len,
     '|1w' reads nothing, and '|O' gates at 12.

     Final state: 72 gates match their record, 1 dispatches on multiple
     lengths, 2 are corpus-backed tolerances, 9 are bounded without a
     numeric gate.  Zero admit truncation; zero drop valid input.

D-19 THE STRING-OFFSET RULE APPLIED TO THE REST OF THE TABLE.
     Recorded 2026-08-13, while building the divergence register that
     RIPtel-is-the-measure requires (14-divergence-register.md).

     D-16 established that the dispatch record types only the numeric
     argument array, so the record's fixed width IS the offset at which
     a trailing string begins.  That rule was applied to the four
     commands the field-list audit could see.  Enumerating every command
     with a string tail found a fifth, and it is the one with teeth.

     '|1R' RIP_READ_SCENE TOOK ITS FILENAME FROM OFFSET 0.  Slot 104
     records mega2 + a 6-digit field: an 8-character fixed prefix.  The
     corpus is unambiguous -- all 25 '|1R' commands in shipped scenes
     begin with exactly eight zeros:

          DRAGON.RIP   "00000000dragon.txt"
          BUTTONS.RIP  "00000000<<IF $COLORS$<\"256\">>BLUEBACK.FN..."

     RIPlib passed the whole payload as the filename, so every
     scene-file request it made was for "00000000dragon.txt" -- a name
     no host could match.  The feature was inert wherever it was used.
     Fixed, with a regression test that fails against the old offset.

     '|2W' RIP_PortWrite gated on nine characters -- the width of its
     port and rect alone -- where slot 120 records thirteen, with the
     bitmap filename following.  Tightened.  No corpus scene sends it.

     '|!' RIP_COMMENT IS NOW IMPLEMENTED RATHER THAN MERELY SURVIVED.
     It is the most frequent command in shipped content: 709 occurrences
     across the corpus, 544 empty, the rest carrying prose or rule-off
     lines ("!|! Show our bounding box", "!|!------").  RIPlib consumed
     them correctly, because the Level 0 switch has no default and an
     unmatched letter falls out doing nothing -- but by accident rather
     than intent, and a coverage audit cannot tell those apart.  Stated
     explicitly as a no-op case.

     A LEVEL BOUNDARY WAS OFF BY ONE IN THE AUDIT TOOLING.  level_of()
     placed the Level 0 / Level 1 split after slot 83; it is after slot
     84.  Handler addresses settle it independently: each level's
     handlers occupy their own region, and the sustained transition into
     the Level 1 region (0x00Axxx-0x00Dxxx) happens at slot 85, not 84.
     So '|{' (slot 84, XY x6) is a LEVEL 0 command -- which is exactly
     where RIPlib implements it, and exactly what 13-dll-command-table.md
     already recorded.  The repository's own table was right; only the
     scratch tooling was wrong, and it had been reporting '|{' as an
     unimplemented Level 1 command because of it.

     ONE MORE MEASUREMENT ARTEFACT, for the same reason as the two in
     D-18.  A reference that elides a repeated field ("c1:2 c2:2 ...
     c16:2") yields only the pairs literally written, so '|Q'
     RIP_SET_PALETTE reported as a 32-versus-6 divergence when the
     reference, the driver and RIPlib all agree on sixteen 2-digit
     entries.  Excluding elided lists takes the bbs-land divergence
     count from a spurious 17 back to 13 -- which is what the first
     audit reported, now reproduced by an independent path.

D-18 AUDITING BY WHAT THE CODE READS, NOT BY WHAT ITS COMMENT CLAIMS.
     Recorded 2026-08-13.

     The field-list comparison can only see a command whose comment
     spells a signature out.  Thirty-two implemented commands have none,
     so they had never been compared to anything -- "zero disagreements"
     was a statement about 51 commands, not about the parser.

     A second instrument closes that: read the actual accessor calls in
     each handler body -- mega2(p + 4), mega_digit(p[9]) and friends --
     rebuild the offset/width layout the code really uses, and check it
     against the record's field boundaries.  A read is a defect when its
     offset is not a field boundary, or its width differs from the field
     starting there.  That is the shape of every offset defect found in
     D-14 through D-17: '|3G' reading at 0 against a prefix of 8, '|1M'
     reading two digits across two 1-digit fields, '|2P' taking the high
     half of a mega4.  It covers 68 commands and 269 individual reads --
     comments optional.

     It found two, both leniency rather than misplacement:

     '|3D' RIP_DELAY fell back to a mega2 when fewer than four characters
     were present, though slot 122 records a single mega4.  That is the
     same tolerance removed from '|3e' in D-16, and no corpus scene sends
     '|3D'.  Removed.

     '|k' RIP_BACK_COLOR falls back to a single digit below two
     characters.  This was removed for the same reason and then PUT BACK,
     because the corpus contradicted the assumption: of 133 '|k' commands
     in shipped scenes, 132 are two characters and one -- N2_BUSI.RIP,
     "|k0" -- is one.  Tightening to match the record exactly would drop
     a command real content sends, for no gain: the defect that mattered
     was reading ONE digit when TWO were present, fixed in v2.0.1.  It is
     now a documented tolerance rather than an unexamined fallback, and
     the audit carries it by name rather than silently passing it.

     TWO CORRECTIONS TO THE INSTRUMENTS, both of which had been shaping
     results:

     Overloaded letters.  An extra signature is stored as a CONTINUATION
     row whose letter byte is 0x00, identified only by sharing the named
     entry's handler pointer.  Filtering rows on a printable letter drops
     them, so '|h' presented as one signature instead of six and its
     4- and 6-character layouts read as defects.  Grouping by handler
     rather than by letter fixes it -- and independently confirms D-2:
     slots 32-37 all carry handler 0x1001CAE1 with totals 8, 4, 6, 8, 3,
     3, exactly as recorded there.

     Coverage as a measured quantity.  Of 114 dispatch entries carrying a
     command letter: 51 have comparable field lists, 32 are implemented
     without one (now covered by the offset audit), 12 record argc with
     no type bytes (nothing to compare), 5 are variable-length, and 14
     are the Level 2 family that D-17 brought in.  Stating the gap is
     what made D-17 findable at all.

D-17 LEVEL 2 WAS NEVER AUDITED AT ALL.  Recorded 2026-08-13.

     D-16 closed the field-list comparison at zero disagreements across
     51 commands.  Measuring the COVERAGE of that comparison showed what
     the 51 left out, and the largest omission was structural: the
     extractor reads case labels out of src/ripscrip.c, and Level 2 has
     none there.  ripscrip.c delegates the whole level to
     ripscrip2_execute() in src/ripscrip2.c, whose handlers are keyed on
     RIP2_CMD_* constants rather than character literals.  So eleven
     commands -- the entire Drawing Ports family -- were invisible to
     every pass of the audit, and "zero disagreements" had never been a
     statement about them.

     That matters more than a plain coverage gap, because Level 2 is
     where bbs-land's reference diverges most from the driver, and where
     a wrong total desynchronises the rest of the frame.

     '|2P' RIP_PortDefine READ THE WRONG HALF OF ITS FLAGS FIELD.  Slot
     115 records mega1, XY, XY, XY, XY, mega4, mega4: the flags field
     spans offsets 9..12.  RIPlib read mega2l(raw + 9), which is not the
     low two digits of that field but the HIGH two.  MegaNum is
     big-endian, so a flags word small enough to be a bit-set lives
     entirely in the trailing digits and that read returns zero.

     The corpus is unanimous.  All three '|2P' commands carry "0001":

          FONTS.RIP     '10000ZK7200010000'   (17, the full record)
          SPECLEFX.RIP  '10000Q04K0001'       (13, reserved tail absent)
          SPECLEFX.RIP  '20000Q0QO0001'       (13)

     RIPlib decoded every one of them as 0, so no '|2P' could ever set a
     port flag -- including bit 1, "make active immediately".  Fixed by
     reading the full mega4 and masking to the defined low bits; mega4l()
     added to ripscrip2.c, which had only 1- and 2-digit readers.

     LOOSE LENGTH GATES, the same class as '|1g' (D-14) and '|1i'
     (D-16).  Every Switch* command records mega1 + mega2 -- three
     characters -- and gated on one:

          |2A |2B |2E |2T |2Y   record 3, gated 1  -> now 3
          |2p                   record 4, gated 1  -> now 4
          |2s                   record 3, gated 1  -> now 3

     The corpus agrees with the records: every '|2s' in it is three
     characters ("!|2s000", "!|2s100"), which is also the evidence sent
     upstream against bbs-land's six-character reading.  The single
     2-character '|2p' in the corpus targets port 0, which is protected
     and refused either way, so rejecting it costs nothing.

     VERIFIED CORRECT, and worth recording as checked rather than
     assumed: '|2C' RIP_PortCopy matches slot 113 field for field
     (mega1, XY x4, mega1, XY x4, mega1, 0x05 -- offsets 0,1,3,5,7,9,10,
     12,14,16,18), and '|2R' reads its mega4 at the right width.

     Three of the four tests that had to change were carrying payloads
     authored against the defective readings -- '|2P...0200' encodes 2
     only if the flags field is two digits at offset 9; as the record's
     four-digit field it is 2592.  That is the '|D' lesson from v2.0.1
     for the third time: a payload written to match the implementation
     tests nothing but the implementation.

D-16 STRING ARGUMENTS START AFTER THE RECORD'S FIXED PREFIX, AND FOUR
     COMMANDS DID NOT.  Recorded 2026-08-13, on the iteration that took
     the field-list comparison to zero disagreements.

     Two facts, established in order:

     (a) LITERAL TYPE CODES ARE DIGIT COUNTS, NEVER STRING MARKERS.
     This was in doubt because RIP_GotoURL's record is a bare 0x08 while
     its handler takes only a string, which invited reading 0x08 as "a
     string follows".  Arithmetic settles it.  '|1e' records
     XY,XY,XY,XY,mega1,mega1,mega4,mega2,0x08 -> 2+2+2+2+1+1+4+2+8 = 24,
     and every '|1e' payload in the corpus is exactly 24 characters of
     digits with no string at all.  '|1i' records XY,XY,XY,XY,mega4,0x0c
     -> 2+2+2+2+4+12 = 24, and its corpus payloads are likewise exactly
     24.  Two independent confirmations; the codes are digit counts.

     (b) THE RECORD TYPES ONLY THE NUMERIC ARGUMENT ARRAY.  A trailing
     string is passed out-of-band: RIP_Define (RVA 0x00BD39) fetches it
     from a different stack slot than the args array and range-checks it
     with  cmp byte ptr [ebx], 0 ; RIP_GotoURL (RVA 0x0251CB) does the
     same and reports "No URL string present" when it is null.  So a
     string never appears in the record -- and the record's fixed width
     is therefore exactly the offset at which that string begins.

     Checked against every command RIPlib documents with a string tail:

          |1D  record 0x03 + mega2 =  5   RIPlib reads at  5   correct
          |1F  record mega2+mega4  =  6   RIPlib reads at  6   correct
          |3G  record 0x08         =  8   RIPlib reads at  0   WRONG
          |3R  record 4 + 2 + 0x08 = 14   RIPlib reads at  6   WRONG

     Both defects are off by exactly the width of the trailing literal
     field they failed to skip.

     '|3G' RIP_GotoURL folded eight reserved digits onto the front of
     every URL.  RIPlib launches nothing (the neutering under SV-2/S2
     stands), so this could not execute anything -- but it handed the
     embedder a URL pointing somewhere other than the one sent, and an
     embedder that displays or acts on s->goto_url under its own policy
     is entitled to the real one.  Note the failure mode is not always
     loud: a reserved field of digits keeps the string inside the
     allowed character set, so validation passes and a WRONG url is
     stored rather than none.

     '|3R' prefixed every registered variable name with eight stray
     digits, so no name a scene registered could ever be matched.

     Both fixed in v2.0.3, with regression tests that fail against the
     old offsets.  No corpus scene sends either command, so -- as with
     D-14 -- the record and the handler are the whole of the evidence.

     A THIRD defect fell out of the same arithmetic.  '|1i'
     RIP_ImageStyle gated on 12 characters when its record is 24: the
     12-character meaningful prefix plus a 12-digit reserved tail.
     Ignoring the tail is correct and was never in question; acting on a
     command that carries only the prefix is not, and is the same defect
     class as '|1g' in D-14.  The reserved field is now documented
     rather than left implicit, which is also what makes the field list
     match the record exactly.

     With these, the comparison of RIPlib's field lists against the
     driver's record stands at 26 exact, 21 notation-only, 4 fixed-prefix
     -plus-string, and ZERO disagreements, across 51 comparable commands.

D-15 THE MOUSE-REGION AND BUTTON PATH: THREE DEFECTS FOUND WHILE
     RESOLVING D-14.  Recorded 2026-08-13.  Re-running the field-list
     comparison after the D-14 fixes surfaced these; the first is the
     largest defect the audit found anywhere, measured by shipped uses.

     '|1M' RIP_Mouse READ TWO 1-DIGIT FLAGS AS ONE 2-DIGIT HOTKEY.
     Slot 101 records  mega2, XY, XY, XY, XY, mega1, mega1, mega2, 0x03
     and the handler (RVA 0x00CEF8) loads args[1..7] as separate values.
     The 1.54 specification names args[5] and args[6] 'invertable' and
     'resetafter'; bbs-land names them clk and clr.  Three independent
     sources, one layout.  RIPlib read args[5]+args[6] as a single
     2-digit hotkey and then took its MF_SEND_CHAR / MF_RADIO /
     MF_TOGGLE bits from p[12] -- which the record types as reserved.

     The corpus settles the impact.  Across 36 '|1M' commands in 22
     scenes:

          char 10 (clk)   '1' x35, '3' x1     <- a real, varying field
          char 11 (clr)   '0' x36
          char 12 (res)   '0' x36             <- RIPlib's "flags"
          chars 13-16     '0' x36

     So the old hotkey was always the constant 36, the old flags were
     always 0 -- SEND_CHAR, RADIO and TOGGLE could never fire from
     content -- and clk, set on 35 of 36 regions, was never captured.
     RIP_MOUSE has no hotkey field at all.  The text offset (17) was
     correct throughout, so host command strings were never affected.
     Fixed in v2.0.3; RIP_MF_INVERT and RIP_MF_RESET added.

     '|1U' RIP_Button PARSED ITS HOTKEY AND FLAGS AND DISCARDED THEM.
     Slot 107 records XY, XY, XY, XY, mega2, mega1, mega1 -- which is
     exactly what RIPlib's own comment said -- yet registration set
     r->hotkey = 0 and r->flags = MF_ACTIVE unconditionally.  Combined
     with the '|1M' defect above, that left the SEND_CHAR / RADIO /
     TOGGLE dispatch code unreachable from ANY command: it was only ever
     read, never written.  Fixed in v2.0.3 by wiring the fields the
     record, the 1.54 specification and bbs-land all agree carry them.

     '|1U' BUTTONS NEVER BECAME CLICKABLE.  Region registration was
     gated on host_len > 0, and host_len is non-zero only when the text
     carries TWO '<>' separators with a non-empty third segment.  All 39
     '|1U' commands in the shipped corpus carry two separators and an
     EMPTY third segment ("<>Clear<>", "<>Pattern<>"), so not one of
     them registered a region.  Button hit-testing was dead for all
     shipped content.  Fixed in v2.0.3: the region registers regardless,
     and the dispatch already guards on text_len before sending, so a
     hostless button sends nothing while still supporting hover,
     SEND_CHAR and TOGGLE.

     The handler comment had claimed that a lone segment with no '<>'
     serves as both label and host command, "see the host-fallback at
     registration below".  No such fallback has ever been in the code.
     The comment is corrected rather than the behaviour: a single
     segment is the label, per the specification.

     A note on how these survived.  The '|1M' misreading was invisible
     to every corpus render test because mouse regions are not drawn,
     and invisible to the unit tests because those tests were authored
     from the implementation -- the same failure the '|D' fix in v2.0.1
     called out.  The MF_RADIO test was passing VACUOUSLY: its fixture
     registered zero regions, and "both regions inactive" is trivially
     true of regions that do not exist.  It now asserts its own fixture.

D-14 THREE FIELD LISTS THAT DISAGREED WITH THE DISPATCH RECORD.
     RESOLVED 2026-08-13 by disassembling the handlers.  Recorded
     2026-08-12 from a field-by-field comparison of every RIPlib handler
     against the driver's own argument types.  Of 47 comparable commands,
     19 match exactly, 19 differ only in notation (a literal 2 where the
     record says width-negotiated, identical at the default), and 9
     genuinely differ.  Six of those nine were resolved -- '|k', '|=',
     '|D' in v2.0.1, '|3e' and '|1I' in v2.0.2, and '|1i' proved to be a
     false alarm (its 24-character payloads carry a 12-character reserved
     tail RIPlib correctly ignores).

     The remaining three were left recorded rather than guessed, on the
     grounds that the record says only what is ACCEPTED and none of the
     three has a corpus use to validate against.  That reasoning skipped
     the evidence that had already settled '|D': the record and the
     handler answer different questions, and the handler answers the one
     that was actually being asked.  All three are now resolved from
     their handlers, and all three were wrong in RIPlib:

     '|1G' IS RIP_Scroll, NOT RIP_COPY_REGION.  Slot 95, handler RVA
     0x00D7E0, which names itself in its own diagnostics: "RIP_Scroll"
     with "Invalid mode parameter" and "Nothing to do".  The export table
     already listed RIP_Scroll as present and distinct from RIP_CopyBlit
     (see the export census above); it was never connected to a slot.
     RIP_COPY_REGION is '|,' -- slot 8, ten coordinates, Level 0 -- so
     RIPlib had the name on two commands at once.  The handler:

          SetRect(&r, args[0], args[1], args[2], args[3])
          if (args[5] == 0) { r.right++; r.bottom++; }
          if (IsRectEmpty(&r)) return
          if (args[6] == r.top) -> "Nothing to do"
          if (args[4] > 6)      -> "Invalid mode parameter"
          OffsetRect(&r, 0, args[6] - args[1])

     dx is a hardcoded ZERO.  The move is vertical only, there is no
     destination X field at all, and args[6] is a destination Y rather
     than a delta -- which is exactly why the record carries one trailing
     coordinate and not two.  args[5] selects inclusive (0) or exclusive
     edges; args[4] is a mode 0..6, where 0 exits straight after the move
     and 1..6 each run a further post-scroll effect routine.  The pixel
     loop flips order on dest_y >= y0 so overlapping moves do not smear.
     RIPlib read fourteen characters and invented a destination pair at
     offsets 10 and 12.  Fixed in v2.0.3; only the move is implemented,
     modes 1..6 are accepted and their effect routines are not.

     '|:' RIP_MOUSE_REGION_EXT IS FIVE VERTICES.  Slot 11 records argc 11
     (XY x10 + mega1, twenty-one characters); handler RVA 0x01DD70 loads
     args[0..10] and coordinate-maps exactly five consecutive (x,y)
     pairs.  It is a five-vertex region, not a rectangle carrying a
     hotkey and flags.  RIPlib had two defects: it required twenty-two
     characters, so every valid command was dropped in full, and it read
     args[4] and args[5] -- which the record types as coordinates and the
     handler maps as a pair -- as a hotkey and a flag byte.  Fixed in
     v2.0.3.  rip_mouse_region_t has no vertex list, so the region
     registers as the bounding box of the five vertices: a conservative
     over-approximation for hit-testing rather than a rectangle invented
     from two of the coordinates.

     '|1g' RIP_CopyBlit -- LENGTH AND ORDERING.  Slot 96 records argc 8
     (six coordinates then two single digits, fourteen characters);
     handler RVA 0x00B7A4 names itself "riprocmd - RIP_CopyBlit()".  It
     loads args[0..6] and never reads args[7], so the trailing digit is
     accepted and reserved -- RIPlib's seven-field reading was right.
     Two things were not: RIPlib gated on twelve characters and treated
     the mode as optional, so a truncated command still blitted with mode
     0; and it required sx1 >= sx0, silently drawing nothing for an
     inverted rect, where the handler orders both source pairs through
     0x1003112E -- the same helper '|K' RIP_FILLED_RECTANGLE uses.  The
     mode check is cmp ebx,5 / jbe, so 0..5 are legal; RIPlib's raster
     ops stop at DRAW_MODE_NOT (4), so 5 is accepted and drawn as COPY.
     Fixed in v2.0.3.

     The common shape is worth naming, and it is not the one recorded on
     2026-08-12.  All three came from the original reconstruction rather
     than from the driver, and none is exercised by shipped content --
     which is why they survived.  But "no corpus use" was taken as a
     reason to leave them alone, when it is only a reason that TESTS
     cannot settle them.  The handler could, and did.  A command no scene
     sends is a command no test can check; it is not a command no
     evidence can reach.

D-13 STATE RECORDED "FOR THE HOST" THAT NO HOST CAN READ.  Recorded
     2026-08-12 by diffing every field of rip_state_s against its uses:
     of 111 fields, 24 are written and never read anywhere in the
     library.  Most carry a comment along the lines of "recorded so an
     embedder that cares can act on it".  No embedder can: rip_state_t
     is INTERNAL by policy (ADR-0001, opaque-by-policy), and the only
     accessors the public header offers are rip_set_url_handler() and
     rip_take_delay().  So these fields are, in practice, dead:

          baud_emulation      encoded_stream_type   mouse_cursor_id
          coordinate_res      encoded_stream_len    refresh_res
          coord_size_unsupported  header_type       text_metric_mode
          mega_base           header_id             text_metric_domain
          viewport_scale      header_flags          char_spacing

     This is not an argument for deleting them — parsing a field and
     recording it is what keeps a frame in sync and is often the honest
     alternative to guessing at semantics.  It is an argument that the
     comments overstate what a consumer can do, and that anything worth
     recording is worth an accessor.  '|3D' RIP_DELAY is the pattern to
     follow: the field is recorded AND rip_take_delay() exposes it.

     Two further fields were not "recorded for the host" but simply
     dead, and both are now dealt with:

       line_cont           REMOVED.  Declared for '\' continuation, only
                           ever assigned false.  Continuation is real and
                           works, but through prev_state and the
                           LINE_CONT FSM state, not this flag.

       utf8_pipe_pending   KEPT, but its comment now says NOT
                           IMPLEMENTED.  It describes accepting a UTF-8
                           transcoded introducer where '|' has become
                           U+00A6 (0xC2 0xA6).  Nothing in the FSM sets
                           or reads it and no 0xC2/0xA6 handling exists,
                           so such a stream is not recognised.  That is a
                           real gap, and the declaration made it look
                           solved.

     Two were gaps in RENDERING rather than API, and both are now
     CLOSED (2026-08-12):

       bez_steps      '|t', '|x' and '|z' carry an nsteps field in their
                      4-character header form.  It was parsed and never
                      consulted: filled curves always flattened to 12
                      segments and outlines always used draw_bezier()'s
                      adaptive estimate, so a stream asking for coarse
                      geometry was given smooth curves regardless.
                      draw_bezier_steps() splits the fixed-count
                      flattener out of draw_bezier(), which now delegates
                      to it, and the RIPscrip layer passes the stream's
                      count when one was set.  Unset still means
                      adaptive, so default quality is unchanged.  No
                      shipped scene uses the header form, which is why
                      the corpus renders identically.

       char_spacing   '|y' carries an inter-character spacing percentage
                      that the driver enforces non-zero.  Every text path
                      used the glyph's own advance, so condensed and
                      expanded text rendered the same as normal.
                      bgi_font_set_char_spacing() applies it at both
                      per-glyph advance sites, module-scoped to match
                      draw_set_color() and the other renderer state
                      rather than changing a public signature.

                      LIMIT: this reaches the STROKE fonts only.  The
                      bitmap path renders a whole run through draw_text()
                      with a fixed 8-pixel cell, so spacing does not
                      apply there.  Every '|y' in shipped content
                      requests 100 -- normal -- so nothing real is
                      affected either way.

D-12 RESOLVED 2026-08-12 — THE BASE-64 ALPHABET, AND WHO USES IT.
     This supersedes D-10 below, which is retained for the record of how
     the search went wrong.  The answer was in TeleGrafix's own content,
     not in the binary, and the binary only confirmed it afterwards.

     THE ALPHABET.  ICONS/TUNNEL.RIP writes 64 consecutive palette
     entries with '|d'.  Their indices must increase by exactly one and
     their RGB values by exactly four; only one alphabet makes both
     sequences come out right, and it is the only reading under which
     '0z' (61) is followed by '0#', '0&' and then '10' (64):

          '0'-'9' ->  0..9        'a'-'z' -> 36..61
          'A'-'Z' -> 10..35       '#'     -> 62      '&' -> 63

     The two symbols past 'z' are '#' and '&' — printable, and neither
     is '|'.  The candidate table at RVA 0x07EEE8 recorded under D-10
     was wrong, as its zero .text references suggested.

     CORROBORATION FROM THE BINARY.  A 4-digit base-64 field spans
     0..64^4-1 = 0..0xFFFFFF exactly — which is the bound the palette
     handler enforces with "RGB Color value is out of range!".  The RGB
     field is 24-bit and only reaches 24 bits in this radix; in base 36
     four digits cap at 1679615 and the check could never fire.

     WHICH COMMANDS.  The radix is per-command, not global.  The flag
     word at dispatch entry +0x26 — the trailing bytes of each record —
     carries a 2-bit field, and the parser's predicate at 0x039D70 reads
     it before falling back to the global base byte at (state+2)+0x38:

          1  always base 36        '|J', '|N'          (2 entries)
          2  always base 64        '|D', '|d', '|h', '|y'  (4 entries)
          3  follow the global base                    (96 entries)

     The predicate picks between two character validators: 0x100210B2
     accepts only 0x30-0x39 and 0x41-0x5A (base 36 exactly), while
     0x100210D0 goes through the CRT ctype table and admits lowercase.

     '|J' being permanently base 36 is the keystone of the design: the
     command that SETS the radix must itself decode unambiguously.  It
     also explains why every '|J' in the corpus is '|J10' — that is 36
     in base 36 and 64 in base 64, so it asserts the current radix
     rather than changing it.

     TUNNEL.RIP settles that the selection really is per-command: it
     carries base-64 '|d' payloads AND '|fZKQO', which is 1280x960 only
     in base 36.  Both in one file.

     WHAT IT COST RIPlib.  rip_mega_digit() is case-INSENSITIVE, which
     is right for base 36 and ruinous here: it folds 'a'..'z' onto
     10..35 and returns 0 for '#' and '&'.  61 of TUNNEL.RIP's 65
     palette entries decoded wrong, with '#' and '&' collapsing onto
     entry 0.  '|y' RIP_ExtendedFontStyle was equally affected across
     195 uses in 25 files: every one carries '1a1a' in its scale fields,
     which is 100,100 in base 64 — a percentage — and a meaningless
     46,46 in base 36.

     FIXED for all four commands via rip_mega_digit64()/rip_mega2_64()/
     rip_mega4_64() in src/rip_meganum.h.  The change is deliberately
     confined to those four; the other 96 entries follow the global base,
     which stays 36, so nothing else moves.

     STILL OPEN: how a stream selects global base 64, given '|J10'
     asserts rather than sets and no corpus file sends '|J1S'.  It does
     not matter for the four always-64 commands, which is why the fix
     lands without it.

D-10 SUPERSEDED BY D-12.  BASE-64 MEGANUM IS ACCEPTED BUT NOT DECODED.
     Recorded
     2026-08-12.  '|J' RIP_SET_BASE_MATH (RVA 0x01f32e) selects the
     MegaNum radix, and the handler accepts exactly two values: 0x24
     (36) and 0x40 (64), forcing 36 for anything else.  So the protocol
     has a base-64 mode.

     RIPlib records the selected base in rip_state_t.mega_base and
     reproduces the driver's validation, but its decoders
     (src/rip_meganum.h) are base 36 unconditionally.  The reason is
     that the base-64 DIGIT ALPHABET has not been recovered: '0'-'9',
     'A'-'Z' and 'a'-'z' account for only 62 symbols, and which two
     characters carry the remaining values — and in what order — is not
     established by anything read so far.  Guessing would silently
     corrupt every numeric field on a base-64 stream, which is worse
     than the gap; this is the same reasoning already applied to '|y'
     (D-5).

     Impact is nil on real content: all 24 uses of '|J' across the 35
     shipped scenes are '|J10', which is base 36.  A stream that selects
     base 64 will currently mis-decode, and that is a known, recorded
     limitation rather than an unnoticed one.

     PROGRESS 2026-08-12 — the reader is found, the alphabet is not.
     0x1003E8EB, which '|J' calls, only STORES the base: into
     (state+2)+0x38 and a second slot at (state+0xe) indexed by
     (word at +0x0a) * 16 + 5.  Enumerating every byte read of +0x38
     across .text gives exactly ONE consumer (a third apparent hit at
     0x05200F is a false positive — 8A 4C 38 04 is mov cl,[eax+edi+4],
     where 0x38 is a SIB byte, not a displacement):

          0x039D70   a predicate returning 0 or 1.  It consults the
                     colour mode at +0x3a, then two flag bits in the
                     dispatch entry's word at +0x26, and only as a final
                     fallback returns (base == 0x40).

     That predicate has exactly one caller, 0x03A02E, inside the parser's
     per-character loop — the same loop that rejects bytes >= 0x7F and
     treats 0x5C ('\') as the line-continuation character, which is the
     continuation POLYPOLY.RIP uses.

     So the base does not select a digit TABLE at the point of decode; it
     feeds a per-character predicate that decides how the accumulator
     treats the byte.  The digit-to-value conversion itself is further
     down that loop and is still not isolated.  This also means the
     candidate at 0x07EEE8 is now LESS likely, not more: nothing indexes
     it, and the one place the base is consulted does not look up a table
     at all.

     Incidental confirmation from the same loop: at 0x03A004 the parser
     computes its dispatch entry as

          lea eax, [ebp + ebp*4]            ; index * 5
          lea ecx, [eax*8 + 0x10080820]     ; * 8  ->  index*40 + base

     which is the driver validating RIPlib's recorded table layout —
     0x080820, 40-byte entries — from its own code rather than from the
     reconstruction that first asserted it.

     CANDIDATE ALPHABET, NOT ADOPTED.  RVA 0x07eee8 (.data) holds
     exactly 64 contiguous bytes, ASCII 0x20..0x5F — space through
     underscore — which would make a base-64 MegaNum digit simply
     (ch - 0x20), covering 0..63 with no gaps.  That is the right shape
     and the right length.  It is NOT adopted, for two reasons:

       - it has ZERO references from .text, so nothing observed actually
         uses it as a lookup table; and
       - its neighbours in .data are 'USASCII', 'KANJI', 'VERBOSE',
         'TWOCHAR', 'THREECHAR' — a character-set keyword group — so a
         printable-ASCII run there is at least as likely to be a charset
         map as a radix table.

     Adopting it on shape alone is exactly the guess this defect exists
     to avoid.  It is recorded so the next pass starts here instead of
     rediscovering it.


---------------------------------------------------------------------
12.14  CLASS H — NEWCMDS.RIP, TELEGRAFIX'S OWN COMMENTED DEMO
---------------------------------------------------------------------

A ninth evidence class, and the strongest yet for command IDENTITY:
the RIPterm/RIPtel installation ships 35 .RIP scenes, and one of them
(ICONS/NEWCMDS.RIP, 1,747 bytes, dated 8 April 1997) is a commented
demonstration file in which TeleGrafix names each command it exercises:

     !|! Show RIP_SKEWED_OVAL
     !|N01|&20151G0M1M

     !|! Show a RIP_SKEWED_OVAL_ARC
     !|N01|]50151G0M20601M

     !|! Show a RIP_FILLED_OVAL_CHORD
     !|N01|_B03F90601G0M|!  With    a border
     !|N00|_B05P90601G0M|!  Without a border

This is not an inference from the binary; it is the vendor writing down
what the letter means, next to a working example of its argument layout.

WHAT IT ESTABLISHES

     |&   RIP_SKEWED_OVAL             5 args   10 chars
     |-   RIP_FILLED_SKEWED_OVAL      5 args   10 chars
     |]   RIP_SKEWED_OVAL_ARC         7 args   14 chars
     |[   RIP_SKEWED_OVAL_PIE_SLICE   7 args   14 chars
     |+   RIP_SKEWED_OVAL_CHORD       7 args   14 chars
     |_   RIP_FILLED_OVAL_CHORD       6 args   12 chars

Every one of those arities matches the dispatch table's recorded argc
exactly.  The file also proves the coordinate layout on its own: before
drawing anything it strokes a grid

     !|L2000209Q   (x=72)     !|L0015HR15  (y=41)
     !|L5000509Q   (x=180)    !|L003FHR3F  (y=123)
     !|L8000809Q   (x=288)    !|L005PHR5P  (y=205)
     !|LB000B09Q   (x=396)

and then places each shape on an intersection.  Decoding the demo
payloads as MegaNum pairs puts every shape's first two arguments on a
grid node, and leaves radii 52/22 IDENTICAL across all seven shapes —
which is what a "same shape, seven variants" demo must look like.

FIELD ORDER, SETTLED BY DISASSEMBLY

The handler for '|-' (RVA 0x01c348) and the handler for '|&'
(RVA 0x01f904) are instruction-for-instruction identical apart from
frame size and stack offsets — the filled and outline members of one
shape.  Both load five arguments and hand (arg0,arg1) and then
(arg2,arg3) to the SAME coordinate-pair mapper at 0x10031084, then pass
everything to the generator at 0x10010160:

     push ecx           ; POINT buffer (8 KB)
     push eax           ; &bounding rect
     push ebx           ; 0x168 = 360      <- end angle
     push 0             ;                  <- start angle
     push edi           ; arg[4]  = skew
     push [ebp-0x14]    ; arg[3]  = ry
     push [ebp-0x10]    ; arg[2]  = rx
     push [ebp-0x0c]    ; arg[1]  = cy
     push [ebp-0x08]    ; arg[0]  = cx
     push esi           ; engine state
     call 0x10010160
     ...
     call Polygon(hdc, pts, 360)

So the non-arc members are the arc generator with start/end pinned to
0..360, and the driver renders the whole family as a 360-point polygon
rather than with a GDI ellipse call.

WHAT 'SKEW' ACTUALLY IS

The generator at 0x10010160 indexes two Q14 fixed-point tables — sine at
RVA 0x07b638, cosine at 0x07b098, 360 entries each, verified against
libm to 1 LSB — and its inner loop is a plain 2-D rotation:

     X  = rx * cos(t) >> 14          Y  = ry * sin(t) >> 14
     px = cx + (X * cos(skew) - Y * sin(skew)) >> 14
     py = cy - (X * sin(skew) + Y * cos(skew)) >> 14

emitting one point per degree over [start,end] inclusive and tracking a
bounding rect as it goes.  'skew' is therefore a ROTATION ANGLE IN WHOLE
DEGREES, not a shear factor or an aspect ratio.  The Y subtraction is
the screen-coordinate inversion, so angles run counter-clockwise from
east.  RIPlib reproduces this arithmetic exactly; see
rip_skewed_oval_points() in src/ripscrip.c.

The cosine table equals sin(t+90) for 358 of its 360 entries and differs
by one LSB on the other two, so RIPlib ships a single sine table.

WHAT IT COST

RIPlib had all six letters bound to unrelated commands — ICON_STYLE,
TEXT_XY_EXT, POLYLINE_EXT, FILLED_POLYGON_EXT, SCROLL and DRAW_TO — and
rendered them as rectangles and line segments.  Section 12.12 had
already marked four of the six REFUTED on arity grounds alone; the code
was never changed to match, which is the failure this class caught.  The
two capabilities that had no protocol basis but were worth keeping (icon
display style, bounded text box) moved to '|3&' and '|3-', letters the
driver's Level 3 set does not use.

---------------------------------------------------------------------
12.16  CLASS I — WHAT A HANDLER CALLS, NOT WHAT IT SAYS
---------------------------------------------------------------------

Classes B, C, F and G between them named most of the dispatch table, and
they share a blind spot: every one of them keys on STRINGS.  A handler
that pushes no name, raises no diagnostic and reports no error is
invisible to all four at once, which is precisely why '|3D' survived
three separate attempts (D-8).

Class I asks the other question: not what a handler SAYS, but what it
CALLS.  scripts/dll-handler-imports.py resolves the import directory,
walks each handler and its callees to a bounded depth, and reports the
Win32 APIs reached.  Drawing commands are self-identifying under this
lens, because GDI names its primitives after the shapes they draw.

WHAT IT INDEPENDENTLY CONFIRMED.  Every one of these was decided on
other grounds first and then checked against this class:

     |<   GDI32!PolyPolygon   — the ONLY handler in the table that
                                reaches it.  RIP_POLY_POLYGON, settled.
     |K   GDI32!Rectangle     — the same primitive as '|B' RIP_BAR and
                                '|R' RIP_RECTANGLE.  A filled rectangle,
                                not a mouse operation.
     |D   SetPaletteEntries   — identical API set to '|d'
                                RIP_OneDrawingPalette, '|a'
                                RIP_ONE_PALETTE and '|Q' RIP_SET_PALETTE.
                                A palette command.
     |&   GDI32!Polygon       — with '|+', '|-', '|[' and '|P'.  The
                                skewed-oval family really is rendered as
                                a polygon, as 12.14 deduced from the
                                360-point buffer.
     |]   GDI32!Polyline      — NOT Polygon, unlike its four siblings.
                                The arc is stroked and open, which is how
                                RIPlib implements it.
     |J   (nothing)           — reaches no drawing or resource API at
                                all, which is what a pure state setter
                                like RIP_SET_BASE_MATH should look like.
     |3D  WINMM!timeGetTime   — via its callee.  This is the one that
                                broke the deadlock; see D-8.

LIMITS, WHICH MATTER FOR HOW FAR THIS CAN BE PUSHED.

  - Absence proves nothing.  The sweep is depth-bounded, so a handler
    can reach a primitive further down than the cutoff.  '|_' shows no
    GDI call at depth 2 yet plainly draws: it calls 0x100125C0, which
    normalises angles against 0x168 (360) — the arithmetic a chord's
    start/end angles need.  Read a null result as "not reached within
    the bound", never as "does nothing".

  - Scaffolding drowns signal unless filtered.  Nearly every handler
    brackets its work with the same lock/unlock, caret-hide and
    offscreen-DC sequence, so BitBlt, CreateCompatibleDC, SelectObject,
    GlobalLock, DrawFocusRect and friends appear almost everywhere and
    discriminate nothing.  The script carries an explicit NOISE set;
    that set is a judgement and is worth revisiting before relying on a
    marginal result.

  - It classifies, it does not name.  Class I tells you a command draws
    an ellipse.  It cannot tell you the command is called
    RIP_OVAL_PIE_SLICE.  It is a corroborator and a tie-breaker, not a
    replacement for the string classes.

---------------------------------------------------------------------
12.15  STILL OPEN
---------------------------------------------------------------------

Requires reading further handler bodies:

     * GFXSTYLE facing-bit offsets (bold/italic/underline/shadow)

     * '|;' — RESOLVED 2026-08-12.  It is RIP_PolyMarker: the handler at
       RVA 0x01E4FF names itself and validates all three of its scalar
       fields with distinct diagnostics, which gives the signature
       outright —

            x:XY y:XY marker:mega2 w:XY h:XY rotation:mega2 flags:mega2

            cmp marker,   0x24  -> "Invalid marker number"
            cmp rotation, 0x168 -> "Invalid marker rotation angle (>=360)"
            cmp flags,    3     -> "Invalid marker flags value"

       so marker < 36, rotation < 360, flags <= 3.  TeleGrafix's
       ICONS/MARKER.RIP ("RIPscrip Markers") exercises exactly numbers
       0..35, rotations 0..300 and sizes from 1x1 upward, matching every
       bound.  Class I corroborates: the handler reaches GDI32!Polygon.

       RIPlib had this letter as RIP_BUTTON_EXT and added a MOUSE REGION
       per call.  That was worse than a wrong shape — the corpus issues
       361 of these, so a scene of markers manufactured hundreds of
       phantom clickable areas.  Now corrected, with the driver's own
       validation reproduced rather than clamping bad fields.

       THE 36 GLYPHS — RECOVERED 2026-08-12, so this is now closed.
       The handler special-cases marker 0 (`test edi, edi` at 0x01E643)
       and hands it to the shared ellipse generator at 0x10010160 with a
       0..360 sweep, so marker 0 is a circle.  Every other number goes to
       0x1000F3C6, which indexes a descriptor table:

            mov  eax, [ebp+0xc]              ; marker number
            imul eax, eax, 6                 ; 6 bytes per entry
            lea  esi, [eax + 0x1007ca48]     ; table base

       Each descriptor is { uint16 count; int32 (*points)[2]; } and each
       point is a pair of int32 in a normalised +/-50 space, scaled by the
       command's half-extent and rotated by its skew using the same Q14
       trig tables as the skewed-oval family.  462 points across 36
       glyphs; the coordinate range fits int8_t.

       Extracted by scripts/dll-marker-glyphs.py and carried in
       src/ripscrip.c.  Method note: the three string-based evidence
       classes had nothing to say here, and the table was found the same
       way '|3D' was — by following what the handler CALLS and what it
       pushes, rather than what it says.

     * disambiguation of '|d' — settled: it is RIP_OneDrawingPalette
       (12.8, B6), with '|D' the block form (12.12).
     * what 0x10012D63 does for '|1k'.  PARTIALLY ANSWERED by class I:
       its chain reaches GDI32!GetStockObject and USER32!FillRect via
       0x10012DE2, so it erases a region — consistent with a mouse-field
       delete that also clears where the fields were.  The exact
       relationship between the two calls it makes (0x10012E27 and
       0x10012DE2) is not established.

     * handler names for letters with no class B/C string.  This is now
       bounded rather than open-ended: class I (12.16) classifies what
       those handlers DO even where no string names them, and it did so
       for every drawing command in the table.  What remains genuinely
       unnamed are non-drawing handlers, which reach no distinctive API
       and so cannot be separated this way.

     * base-64 MegaNum digit alphabet (D-10) — the decoder that reads
       the base byte at (state+2)+0x38 has not been located.

Until those are done, no segment may state those specific claims as
DLL-derived fact.

=====================================================================
==                    END OF SEGMENT 12                             ==
==             Binary Provenance & Evidence Classes                 ==
=====================================================================
