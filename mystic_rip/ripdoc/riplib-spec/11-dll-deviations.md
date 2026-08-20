
=====================================================================
==       SEGMENT 11: DLL DEVIATIONS, ERRATA & KNOWN BUGS           ==
=====================================================================

This segment documents deviations between the published v2.A4
specification and the production RIPSCRIP.DLL v3.0.7 (October
1997), specification errata discovered during binary analysis,
and known DLL bugs that implementers should avoid replicating.

This information was derived from systematic disassembly of
RIPSCRIP.DLL (592,896 bytes, 32-bit Windows PE, i386).


---------------------------------------------------------------------
11.1  DROPPED COMMANDS (v2.A4 → v3.0 DLL)
---------------------------------------------------------------------

The following commands were defined in the v2.A4 specification
but are NOT present in the production v3.0 DLL. Do not implement.

RIP_SCROLLER (v2.A1, §1.4.4):
     Intended as a standardized scrollbar widget. Completely absent
     from the DLL — no function string containing "scroller" found.
     The command "RIP_Scroll" (screen region scroll, |+) IS present
     but is a different command. Use RIP_BUTTON with graphics for
     scrollbar UI if needed.

RIP_FILLED_RECTANGLE (v2.A2, §3.4.1.20):
     Intended to add write mode support to filled rectangles (v1.54
     RIP_BAR did not support write modes). Not present as a named
     function in the DLL. The existing RIP_BAR command gained write
     mode support in practice, making this redundant.

RIP_WORLD_FRAME (v2.A0):
     World coordinate frame transformation system. References exist
     in the v2.A4 spec text but no implementation found in the DLL
     export table or function strings. The coordinate system remains
     the simple EGA 640×350 model with scale_y mapping.


---------------------------------------------------------------------
11.2  v2.A4 SPECIFICATION ERRATA
---------------------------------------------------------------------

Erratum 1 — Command letter 'b' collision:
     RIP_SET_BASE_MATH (§3.4.1.46, added v2.A0) and
     RIP_EXTENDED_TEXT_WINDOW (§3.4.1.12, added v2.A4) both use
     command letter 'b' at Level 0. The DLL disambiguates by
     argument length:
          RIP_SET_BASE_MATH: exactly 2 characters after 'b'
          RIP_EXTENDED_TEXT_WINDOW: 15+ characters after 'b'
     Implementations that parse by command letter alone will
     misinterpret one or both.

Erratum 2 — RIP_FILLED_POLY_BEZIER command letter:
     §3.4.1.19 header states "Command: x" but the Format line
     reads "!|z" (the unfilled RIP_POLY_BEZIER letter). Copy-paste
     error in the specification.
          Correct: RIP_POLY_BEZIER        = 'z' (unfilled)
                   RIP_FILLED_POLY_BEZIER = 'x' (filled)

Erratum 3 — RIP_DELETE_PORT command letter:
     §3.4.3.2 header states "Command: p" but the Format line reads
     "!|2s" (the RIP_SWITCH_PORT letter). The TOC lists these as
     separate commands.
          Correct: RIP_DELETE_PORT  = !|2p (Level 2, 'p')
                   RIP_SWITCH_PORT  = !|2s (Level 2, 's')


---------------------------------------------------------------------
11.3  v3.0 DLL KNOWN BUGS
---------------------------------------------------------------------

Implementers should be aware of these defects to avoid replicating
them. RIPlib v3.1 corrects all of these.

§BUG.1 — Memory allocator masks out-of-memory:
     ripHeapAllocPtr (86 call sites) unconditionally returns 1
     (success) even when allocation fails and the output pointer
     is NULL. Callers checking only the return value never detect
     OOM. The actual indicator is whether *ppOut is non-NULL.
     v3.1 FIX: Return NULL on failure, callers check pointer.

§BUG.2 — Buffer overflow discards entire input queue:
     When the RIP staging buffer exceeds RIP_BUF_MAX (5000 bytes),
     ALL pending input is discarded and the fill pointer reset to
     zero. Any partial command straddling the boundary is lost.
     v3.1 FIX: Discard only the current incomplete command.

§BUG.3 — Histogram counter overflow inversion:
     In RipDib_AccumHistogram (adaptive palette quantization), the
     16-bit histogram counter DECREMENTS on overflow instead of
     saturating at 0xFFFF. Extremely common colors wrap downward,
     potentially excluded from the quantized palette.
     v3.1 FIX: Saturate at max value, do not wrap.

§BUG.4 — Zmodem ZRPOS handler is a stub:
     During Zmodem file send, the ZRPOS response handler (receiver
     requesting retransmission from offset) is unimplemented:
          if (ret == ZRPOS) { /* TODO: handle re-seek */ }
     Bad blocks are not retransmitted, potentially delivering
     corrupted files.
     v3.1 FIX: Implement ZRPOS seek + retransmit.

§BUG.5 — VGA DAC precision loss:
     The palette pipeline converts all RGB values from 8-bit to
     6-bit (VGA DAC format) via right-shift by 2 before passing to
     GDI. This loses the bottom 2 bits of every color channel,
     even when the display supports 8-bit precision.
     v3.1 FIX: Use full 8-bit RGB → RGB565 conversion directly.

§BUG.6 — Pie fill leak through pixel gaps:
     draw_pie used flood fill on the arc+radii boundary. Sub-pixel
     gaps between the arc and radial line endpoints caused the fill
     to leak out and flood the entire screen.
     v3.1 FIX: Scanline-based per-pixel angle+distance test using
     FPU atan2f. Zero leak potential.

§BUG.7 — WITHDRAWN 2026-08-12. NOT A DLL BUG.
     This entry claimed the DLL's internal constants (0=COPY,
     1=XOR, 2=OR) differed from "the protocol wire values ...
     0=COPY, 1=OR, 3=XOR", and RIPlib renumbered its write modes
     accordingly.  The claim carried no citation, skipped value 2,
     and is disproved by the code.

     Disassembly (see §12.10) shows the '|W' handler at RVA
     0x02102C stores the wire byte UNMODIFIED, and the apply path
     feeds that same byte to a five-way translation at RVA
     0x00E6B3 which calls GDI SetROP2:

          wire 0 -> R2_COPYPEN   COPY
          wire 1 -> R2_XORPEN    XOR
          wire 2 -> R2_MERGEPEN  OR
          wire 3 -> R2_MASKPEN   AND
          wire 4 -> R2_NOT       NOT

     There is no internal-vs-wire distinction.  The correct wire
     ordering is 0=COPY, 1=XOR, 2=OR, 3=AND, 4=NOT, which agrees
     with the 1.54 specification, the 2.00a4 table, Borland BGI,
     and §DEAD.3's own reading.

     ACTION REQUIRED: include/drawing.h defines DRAW_MODE_OR=1,
     DRAW_MODE_AND=2, DRAW_MODE_XOR=3 and the handler passes the
     wire byte straight through, so RIPlib currently renders XOR
     where the protocol means OR and vice versa.  Correct the four
     constants; the compositing switch is symbolic and follows.

§BUG.8 — Bottom-to-top vertical text:
     BGI VERT_DIR rendered text bottom-to-top, producing backwards-
     reading text on screen. See §A2G.2 for the correction.

§BUG.9 — BGI font parser assumed '+' at byte 0:
     The CHR parser only checked byte 0 for the '+' marker. In
     bgi2c-generated headers, '+' is at ~byte 38. All 10 BGI
     stroke fonts silently failed to load, falling back to bitmap.
     v3.1 FIX: Scan for '+' with validation (see §8.4).


---------------------------------------------------------------------
11.4  REDESIGNED COMMANDS
---------------------------------------------------------------------

The following commands exist in both the v2.A4 spec and the v3.0
DLL but with different parameter formats or behavior:

RIP_BUTTON (Level 1, 'U'):
     v2.A4 spec describes separate RIP_MOUSE_REGION and RIP_BUTTON
     commands. In the DLL, the internal function ripCmd_MouseRegion
     handles both — the command letter 'U' creates the button
     visuals AND registers the mouse region in one call.

Drawing Port coordinate system:
     v2.A4 describes world-frame coordinates with origin offsets.
     The DLL uses simple viewport rectangles with EGA→card scaling.
     No world-frame transformation is implemented.

Palette slot switching:
     v2.A4 describes 36 palette slots with save/restore flags.
     The DLL implements this but with slightly different flag
     semantics (flag 0x01 = save primary, 0x02 = restore primary,
     0x04 = save alternate, 0x08 = restore alternate).


---------------------------------------------------------------------
11.5  RESURRECTED DEAD CODE (v3.1)
---------------------------------------------------------------------

The following features existed as code in the DLL (parsed, stored)
but never produced visible output. They were effectively dead code.
v3.1 activates them with working implementations.

§DEAD.1 — Font attribute rendering (|f command):
     The DLL parsed font_attrib bits (bold, italic, underline,
     shadow) from the RIP_FONT_ATTRIB command and stored them
     in the GFXSTYLE structure. However, the BGI stroke font
     renderer never read or applied these bits. All text rendered
     identically regardless of attribute settings.
     v3.1: All four attributes are now rendered. Bold uses
     double-stroke offset, italic uses FPU shear, underline
     draws at baseline, shadow draws dimmed offset copy.

§DEAD.2 — BGI stroke font loading:
     The DLL loaded CHR font files into memory and parsed their
     headers. However, the CHR binary parser had bugs in table
     ordering (width table and stroke offset table were often
     reversed in third-party implementations) and '+' marker
     detection (assumed byte 0, but bgi2c-generated data has
     '+' at ~byte 38). In practice, fonts silently failed to
     load and all text fell back to the bitmap font.
     v3.1: Complete parser rewrite — scans for '+' with
     validation, correct 16-byte header, offsets-before-widths
     table order. All 10 BGI fonts load and render correctly.

§DEAD.3 — CORRECTED 2026-08-12. AND AND NOT WERE NOT DEAD.
     This entry claimed the DLL "only implemented COPY (0), XOR
     (1), and OR (2) internally", with AND and NOT parsed but
     never rendered.  Disassembly disproves it: the translation at
     RVA 0x00E6B3 maps all five wire values to GDI raster ops,
     including 3 -> R2_MASKPEN (AND) and 4 -> R2_NOT (NOT).  Both
     were live in the shipping driver.

     The one part of this entry that stands is its ordering —
     COPY 0, XOR 1, OR 2 — which is confirmed and is the basis for
     withdrawing §BUG.7 above.

     CONSEQUENCE: §A2G.1 presents AND and NOT as v3.1 additions
     that "activate" dead code.  They were neither new to the
     language nor dead in the implementation.  §A2G.1 should be
     restated as what it actually is — a completeness fix for
     RIPlib's own renderer — and dropped as a protocol extension.

§DEAD.4 — Vertical text direction:
     The DLL accepted direction=1 in font style commands and
     stored the value, but the rendering produced backwards
     text (bottom-to-top) that was unreadable in English.
     The feature was documented but functionally broken — no
     BBS used it because the output was unusable.
     v3.1: Corrected to top-to-bottom with proper screen-CW
     glyph rotation. Added direction=2 (CCW) as a new option.

§DEAD.5 — Drawing Port alpha and compositing flags:
     The DLL's port structure had fields for opacity, compositing
     mode, and z-order, but these were never read by the rendering
     pipeline. Ports were always rendered at full opacity with
     simple overwrite compositing.
     v3.1: Port flags command (|2F) sets alpha, comp_mode, and
     zorder per-port. These feed into the windowed compositor
     for layered desktop rendering.

§DEAD.6 — Fill patterns 9-11 (INTERLEAVE, WIDE_DOT, CLOSE_DOT):
     The BGI specification defines 13 fill patterns (0-12), but
     most implementations only provided 8 built-in patterns.
     Patterns 9-11 were mapped to approximate alternatives
     (checker, light diagonal) rather than their correct bitmaps.
     v3.1: All three patterns implemented with their correct
     8×8 bitmaps per the Borland BGI specification.

§DEAD.7 — Patterned flood fill:
     The DLL's flood fill command accepted a fill pattern setting
     but the flood fill algorithm always filled with a solid color.
     The GDI brush for patterned fill was created but never applied
     to the ExtFloodFill call in the border-color codepath.
     v3.1: Two-pass algorithm — solid fill first (for boundary
     tracking), then pattern application over the filled region.

§DEAD.8 — Text justification rendering:
     The DLL parsed horizontal and vertical justification flags
     from the font style command and stored them in GFXSTYLE.
     However, the text rendering paths did not read these fields
     — all text rendered left-aligned at the draw cursor position.
     v3.1: Justification applied via string width measurement
     and cursor offset before rendering. Center, right, top,
     bottom, and baseline justification all functional.


---------------------------------------------------------------------
11.6  RIPlib DELIBERATE DEVIATIONS (2026-05-30 re-audit, C-012)
---------------------------------------------------------------------

This section records places where RIPlib's behaviour DELIBERATELY
differs from the published spec text, with the rationale.  Per the
charter of this document, every entry here is a *decision*: either the
deviation improves the library and is kept, or the spec text is the
incomplete side and has been corrected to match the code.  Items that
were merely unfinished code were FIXED rather than enshrined here, and
items that were genuinely open questions were moved to
`design/knowledge.md` (they are not "deviations" until a decision is
made).  The 2026-05-30 re-audit disposition of each candidate finding:

  FIXED IN CODE (were bugs, not deviations — not listed below):
    • text escapes `\^` / `\n` added to `unescape_text` (spec §1.6/§7.1)
    • RIP_FILL_STYLE ('S') pattern clamped to spec range 0-12
    • the misleading BGI font-table-order comment in `bgi_font.c`
    • '1U' single-segment button now reuses the label as host command
    • '26' SCALABLE_TEXT scale: was bit-masked `& 0x07` (which silently
      corrupted valid scales — e.g. 10 became 2); now clamped to the
      renderer's true 1-10 range, matching the '|Y' size field.  See
      §DEV.3.

  CORRECTED IN THE SPEC (code was right, spec text was incomplete —
  the spec files were edited, so they no longer disagree; recorded
  here only as a pointer):
    • icon lookup order — see §DEV.2 (spec §9.2 updated)
    • undocumented commands 1V/1X/1R + backtick/comment/group — see
      §DEV.4 (spec §A.1 command tables updated)
    • '26' scale arguments and range — spec §5.9 updated

  MOVED TO design/knowledge.md (open questions, NOT decisions — they
  do not belong in a deviations register until resolved):
    • '1M' reserved-field width (11 vs 17 chars) → U-024
    • '1D' DEFINE argument grammar (bare name=value vs flags prelude)
      → U-025
    Both await DLL/RIPterm ground truth (a disassembly or a real wire
    capture).  Until then the code keeps its current behaviour but the
    project has NOT decided it is correct, so it is tracked as an
    unknown rather than asserted as a deviation.

The genuine, decided deviations follow.

§DEV.1 — Text escape set is a strict superset of the spec:
     Spec §1.6 / §7.1 define escapes `\\ \| \^ \n`.  RIPlib's
     `unescape_text` implements all four AND additionally accepts
     `\!` as a literal '!'.  Rationale: '!' is the command-frame
     lead-in, so a literal '!' in text would otherwise be ambiguous;
     `\!` lets a stream emit one unambiguously.  This is a deliberate,
     backward-compatible extension (a strict superset — every
     spec-conformant stream still behaves identically).  KEPT.

§DEV.2 — Icon lookup checks the runtime cache first:
     The implementation resolves an icon name in the order
     cache → flash-BMP → flash-ICN, so a runtime-cached or
     clipboard-written icon supersedes a same-named bundled flash
     asset for the session.  Rationale: lets a stream override a
     built-in icon without a name collision; the cache is per-session
     and cleared on reset, so flash defaults always return for a new
     session.  This is a deliberate capability improvement.  KEPT.
     Spec §9.2 has been updated to document this order (it previously
     listed flash-first), so spec and code now agree.

§DEV.3 — Text scale clamped to the renderer's 1-10 range:
     Earlier draft spec text (§5.9) advertised scalable text "beyond
     the standard 1-10 range."  RIPlib's BGI stroke renderer
     (`bgi_font.c`) caps integer scale at 10; the '26' SCALABLE_TEXT
     and '|Y' RIP_FONT_STYLE handlers both clamp to 1-10 accordingly.
     Rationale: 10 is the renderer's real ceiling — honouring larger
     values would require a different glyph pipeline.  This is a
     truthful limit, not silent truncation: the previous `& 0x07`
     bit-mask (which mangled scales 8-10) was a bug and has been fixed
     to a proper clamp.  Spec §5.9 has been corrected to state the
     1-10 range.  KEPT (as a documented renderer limit).

§DEV.4 — CORRECTED 2026-08-12.  Most of these are NOT RIPlib-original.
     This entry listed six commands as "RIPlib extensions beyond the
     published TeleGrafix tables".  The DLL dispatch table (segment 13)
     settles the open provenance question U-026, and four of the six
     are present in the shipping driver:

        |1R  PRESENT  handler RVA 0x00D64D, 2 args.  The handler
                      names itself RIP_ReadScene.  A documented
                      command since 1.54, not an extension.
        |!   PRESENT  handler RVA 0x01AD36, 0 args (RIP_COMMENT).
        |(   PRESENT  handler RVA 0x01CA84, 0 args (group begin).
        |)   PRESENT  handler RVA 0x01CA85, 0 args (group end).
        |`   PRESENT  handler RVA 0x01D963, 11 args.  The backtick
                      composite-icon command is in the driver.

     Only two survive as genuine RIPlib originals — neither letter
     appears anywhere in the Level 1 dispatch band:

        |1V  ABSENT   SET_VIEWPORT_EXT — RIPlib-original.
        |1X  ABSENT   CLIPBOARD_OP     — RIPlib-original.

     U-026 is therefore CLOSED.  The deviation register loses four
     entries at zero behavioural cost; behaviour matched in every
     case, only the standing was wrong.  §A.1 should describe the
     four as documented commands rather than RIPlib extensions.

§DEV.5 — RIP_SET_WINDOW ('22') draws fixed window chrome:
     Spec §5.10 defines '22' arguments as `x:2 y:2 w:2 h:2` with no
     visual specification.  RIPlib paints a 1-pixel light-gray (palette
     7) outline plus a 14-pixel blue (palette 1) title bar inside it.
     Rationale: the command is named "Define Window Region" and a
     visible frame+titlebar is the useful default for a windowing
     widget on a single-framebuffer target; the spec leaves the
     appearance implementation-defined, so this is a concrete choice
     within the spec's latitude rather than a contradiction of it.
     KEPT (deliberate default chrome).

§DEV.6 — RIP_TEXT_WINDOW ('w'): a FULL-SCREEN window defers to the host
     text path, only a SMALLER window activates RIPlib's text renderer:
     The 'w' handler sets s->tw_active true only when the requested rect
     is smaller than the full 640x350 EGA screen; a full-screen window
     (0,0,639,349) leaves tw_active = false.  Consequence: a sub-screen
     text window routes subsequent plain text through rip_tw_putchar ->
     draw_text (honouring wrap and font size), while a full-screen window
     lets text fall through to the host VT100/ANSI passthrough
     (comp_passthrough_vt100), which is the normal terminal flow.
     Rationale: "full-screen window == terminal default" — a stream that
     wraps the whole screen is treated as ordinary terminal output, not
     as a graphics-mode text box.  NOTE: the two routes are NOT the same
     renderer; in a build with no host compositor (the standalone
     library, where comp_passthrough_vt100 is a no-op stub) a full-screen
     'w' window followed by text produces no visible glyphs.  This is an
     intentional heuristic, but it is ambiguous for a stream that expects
     graphics-mode rendering of a full-screen text window — documented
     here so the routing is not mistaken for a bug.  KEPT (intentional
     heuristic; the misleading in-code comment that claimed "both paths
     route to the same renderer" was corrected).

=====================================================================
==                    END OF SEGMENT 11                             ==
==           DLL Deviations, Errata & Known Bugs                   ==
=====================================================================
