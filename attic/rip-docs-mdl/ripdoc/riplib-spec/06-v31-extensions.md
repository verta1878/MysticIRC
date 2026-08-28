
=====================================================================
==       SEGMENT 6: v3.1 EXTENSIONS (§A2G.1 - §A2G.7)              ==
=====================================================================

The §A2G extensions are additions to the RIPscrip protocol that go
beyond what TeleGrafix shipped in RIPSCRIP.DLL v3.0.7 (October 1997).
All extensions are backward-compatible — they use existing command
fields, previously unused parameter ranges, new command letters not
in the v3.0 table, or new $VARIABLE$ names.  A v3.0 client receiving
v3.1 traffic sees the additions as either no-ops or as literal text.

Protocol versioning:

     RIPSCRIP031001    v3.1 — §A2G.1 through §A2G.7
                              (AND/NOT, vertical text, font attrs,
                               native fills, FPU, palette offset, CCW)

v3.2 additions (§A2G.8 - §A2G.13) are documented in the companion
file `06a-v32-extensions.md`.  A client advertises its supported
revision via $RIPVER$ and via the ESC[! probe response (see §1.7).
The wire ID encodes the major, minor, and sub-version each as a
2-digit field.

All extensions are documented with a §A2G section number for
cross-referencing.


---------------------------------------------------------------------
§A2G.1  EXTENDED WRITE MODES — AND and NOT
---------------------------------------------------------------------

WITHDRAWN AS A PROTOCOL EXTENSION — 2026-08-12.

This section claimed AND and NOT as v3.1 additions, on a write-mode
ordering that has since been disproved.  Both claims fail:

  ORDERING.  The wire values are 0=COPY, 1=XOR, 2=OR, 3=AND, 4=NOT,
  established by disassembly (docs/spec/12-dll-provenance.md §12.10).
  There is no "DLL internal vs wire" distinction — the '|W' handler
  stores the wire byte unmodified and the apply path translates it
  straight to a GDI raster op.  The note that previously appeared
  here asserted the opposite with no citation; it came from §BUG.7,
  which is now withdrawn.

  NOVELTY.  AND and NOT are not new.  Both have been documented
  modes since v2.00 Alpha 1, and the driver's translation maps
  wire 3 -> R2_MASKPEN and wire 4 -> R2_NOT, so the shipping
  implementation rendered them.  They were never dead code.

What §A2G.1 actually contributed is a completeness fix to RIPlib's
own renderer — implementing all five modes in every pixel-write
path.  That is a library-level improvement, not a language
extension, and it is no longer counted as one.

The five modes, for reference:

     Mode 0: COPY   (dst = src)
     Mode 1: XOR    (dst = dst ^ src)
     Mode 2: OR     (dst = dst | src)
     Mode 3: AND    (dst = dst & src)
     Mode 4: NOT    (dst = ~dst)

AND mode performs a bitwise AND between the source color and
the existing destination pixel. This is useful for masking
operations — AND with a color that has only certain channel
bits set will preserve only those channels.

     Example: White pixel (0xFF) AND Red (0xE0) = Red (0xE0)
              Keeps only the red channel bits.

NOT mode performs a bitwise inversion of the destination pixel,
ignoring the source color entirely. The draw color parameter
is accepted but not used — the destination is simply inverted.

     Example: NOT on white (0xFF) = black (0x00)
              NOT on red (0xE0) = cyan-ish (0x1F)
              NOT twice = original (self-inverse)

These modes apply to all drawing operations: lines, rectangles,
circles, fills, text, copy operations, etc.

     Wire format: !|W02|    (set AND mode)
                  !|W04|    (set NOT mode)


---------------------------------------------------------------------
§A2G.2  VERTICAL TEXT DIRECTION CORRECTION
---------------------------------------------------------------------

The Borland BGI v1.54 specification defines VERT_DIR (direction=1)
as "bottom to top" — the first character of the string is placed
at the origin (bottom), and subsequent characters advance upward
(decreasing Y).

This renders English text backwards on screen. Reading top-to-
bottom, "HELLO" appears as "OLLEH". No known BBS sends vertical
text commands, so this behavior was never observed in practice.

REVISED 2026-08-12 (X3).  v3.1 originally REDEFINED direction 1 to
render top-to-bottom.  That made content authored against either
side read upside-down on the other, for no gain: the 1.54 wording
is a statement of intent, not a defect report, and bottom-to-top is
the conventional orientation for a rotated axis label.

Direction 1 has been restored to its documented meaning, and the
corrected top-to-bottom rendering moved to a NEW value, 3:

     Direction 0: Horizontal, left to right (unchanged)
     Direction 1: Vertical, BOTTOM TO TOP, CCW glyphs  (BGI VERT_DIR,
                  as the 1.54 specification defines it)
     Direction 2: Vertical, top to bottom, CCW glyph rotation
     Direction 3: Vertical, top to bottom, CW  glyph rotation
                  (this is what direction 1 did before the revision)

Note for '|26' SCALABLE_TEXT: a 90-degree rotation maps to direction
3, not 1 — mapping it to 1 would now run the text upward.

For direction 1 (CW), characters are readable when tilting
the head clockwise (right ear toward shoulder). This matches
the English book spine convention (US/UK).

For direction 2 (CCW), characters are readable when tilting
the head counter-clockwise (left ear toward shoulder). This
matches the French book spine convention.

Both vertical directions advance the cursor downward (Y += width).
The glyph rotation determines which way the reader tilts their
head to read the text.

Glyph coordinate transforms:

     Direction 0 (horizontal):
          screen_x = origin_x + stroke_dx
          screen_y = origin_y - stroke_dy    (BGI Y inverted)

     Direction 1 (CW, tilt head right):
          screen_x = origin_x + stroke_dy
          screen_y = origin_y + stroke_dx    (screen-CW rotation)

     Direction 2 (CCW, tilt head left):
          screen_x = origin_x - stroke_dy
          screen_y = origin_y - stroke_dx    (screen-CCW rotation)

     Wire format: !|Y010200|    (Triplex, dir=2 CCW, size 1)


---------------------------------------------------------------------
§A2G.3  FONT ATTRIBUTE RENDERING
---------------------------------------------------------------------

The RIP_FONT_ATTRIB command (|q) was present in v3.0 but the DLL
never applied the attribute bits to the rendered output. The bits
were parsed and stored but had no visual effect.

LETTER CORRECTED 2026-08-12: this section previously placed the
command on '|f'.  The driver's '|f' is RIP_SetWorldFrame; font
attributes are on '|q'.  §A2G.3 therefore MOVES rather than being
withdrawn — the feature is real, the letter was wrong.

v3.1 implements all four attribute effects for BGI stroke fonts:

     Bit 0 (0x01) — BOLD:
          Each stroke segment is drawn twice: once at the normal
          position, once offset 1 pixel to the right. This
          thickens the glyph without changing its metrics.

     Bit 1 (0x02) — ITALIC:
          The X coordinate of each stroke point is sheared by
          a factor proportional to the Y position:

               shear = font.top * scale / 5

          The entire glyph origin is offset by this shear amount,
          creating a rightward lean at the top of the character.
          Uses FPU for the shear calculation.

     Bit 2 (0x04) — UNDERLINE:
          After the string is rendered, a horizontal line is drawn
          at baseline + 2 pixels, spanning the full string width.
          For vertical text, a vertical underline bar is drawn
          2 pixels left of the string origin.

     Bit 3 (0x08) — SHADOW:
          The entire string is rendered twice: first in a dimmed
          shadow color offset (1, 1) pixels from the origin, then
          in the normal color at the origin. The shadow color is
          computed by halving each RGB332 channel:

               shadow_color = (color >> 1) & 0x6D

Attributes are cumulative — bold+italic+underline is valid.
Attributes only affect BGI stroke fonts (font IDs 1-10). The
bitmap font (ID 0) ignores attributes.

     Wire format: !|q03|      (bold + italic)
                  !|q07|      (bold + italic + underline)


---------------------------------------------------------------------
§A2G.4  NATIVE FILL PATTERNS
---------------------------------------------------------------------

The original BGI defined 13 fill patterns (0-12), but most
implementations only provided 8 built-in patterns and
approximated patterns 9-11 using the closest available match.

QUALIFIED 2026-08-12.  This section previously claimed v3.1
"provides all 13 patterns natively".  That overstates what the
implementation does, on two counts:

  COUNT.  src/drawing.c declares eleven 8x8 bitmaps plus one
  user-defined slot, not thirteen.

  COLLAPSE.  The wire-to-bitmap mapping in rip_bgi_fill_to_card()
  still resolves four BGI styles to approximations, and two of
  them collapse onto a single bitmap:

       BGI 3  LTSLASH    -> light diagonal   (approximation)
       BGI 5  BKSLASH    -> diagonal back  \
       BGI 6  LTBKSLASH  -> diagonal back  /  same bitmap
       BGI 8  XHATCH     -> 50% checker      (approximation)

  So the 9/10/11 approximations §DEAD.6 set out to remove were
  fixed, but the 5/6 collapse was relocated into the mapping layer
  rather than eliminated.

Separately, "correct per Borland BGI" is not the same standard as
"correct per RIPscrip": the RIPscrip specification prints eight
byte values per pattern and RIPterm implemented those, including
the well-known wrong Light Backslash bytes A5 D2 69 B4 5A 2D 96 4B.
Byte-exact fidelity matters when a fill tiles against era artwork.
RIPlib's independently chosen bitmaps are a defensible choice, but
they are a CHOICE and are recorded as one here.

The eleven built-in patterns:

     ID   Name              Pattern (8×8 hex)
     --   ---------------   ---------------------------------
     0    SOLID             FF FF FF FF FF FF FF FF
     1    CHECKER           AA 55 AA 55 AA 55 AA 55
     2    DIAGONAL_BACK     88 44 22 11 88 44 22 11
     3    DIAGONAL_FWD      11 22 44 88 11 22 44 88
     4    HORIZONTAL        FF 00 FF 00 FF 00 FF 00
     5    VERTICAL          AA AA AA AA AA AA AA AA
     6    CROSS_HATCH       FF AA FF AA FF AA FF AA
     7    LIGHT_DIAGONAL    80 40 20 10 08 04 02 01
     8    INTERLEAVE        CC 33 CC 33 CC 33 CC 33
     9    WIDE_DOT          80 00 08 00 80 00 08 00
     10   CLOSE_DOT         AA 00 AA 00 AA 00 AA 00
     11   USER_PATTERN      (set via |s command)

Previous implementations mapped:
     Pattern 9 → checker (approximate)
     Pattern 10 → light diagonal (approximate)
     Pattern 11 → checker (approximate)

v3.1 provides the correct patterns for all three, matching
the Borland BGI specification exactly.


---------------------------------------------------------------------
§A2G.5  FPU-ACCELERATED RENDERING
---------------------------------------------------------------------

v3.1 uses single-precision floating-point hardware (FPU) for
operations where integer arithmetic introduces visible errors:

BEZIER CURVES (draw_bezier):
     Replaced: Recursive integer De Casteljau subdivision with
               >>1 shift rounding at each of 8 recursion levels.
     With:     FPU parametric cubic evaluation:
                    B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
               Adaptive step count based on control polygon length
               (4-64 steps). No rounding accumulation.

TRIGONOMETRY (arcs, pies, elliptical arcs):
     Replaced: 91-entry integer sine lookup table with
               linear interpolation (±1° accuracy).
     With:     sinf(), cosf(), atan2f(), sqrtf()
               (<0.01° accuracy, 1-2 cycle per call on Cortex-M33).

PIE FILL (draw_pie, draw_elliptical_pie):
     Replaced: Flood fill on arc+radii boundary (leaked through
               pixel gaps between arc and radial line endpoints).
     With:     Per-pixel angle+distance test using atan2f:
               For each pixel in the bounding box, compute angle
               from center and check if within the sector range
               AND within the radius. Eliminates all fill leaks.

COORDINATE SCALING:
     The scale_y function (y * 8 / 7) uses integer arithmetic
     which is exact for this specific ratio. FPU is not needed
     here — the integer result matches the float result exactly.

These improvements are transparent to the protocol — the same
wire commands produce smoother, more accurate output.


---------------------------------------------------------------------
§A2G.6  PALETTE INDEX CORRECTION
---------------------------------------------------------------------

The RIP_SET_PALETTE (|Q) and RIP_ONE_PALETTE (|a) commands in
early implementations wrote to hardware palette indices 0-15.
This conflicted with the xterm-256 color palette used by the
VT100/ANSI text renderer, which occupies indices 0-239.

v3.1 maps EGA colors to palette indices 240-255:

     EGA color 0  → framebuffer value 240
     EGA color 1  → framebuffer value 241
     ...
     EGA color 15 → framebuffer value 255

Drawing commands use s->palette[color] to convert EGA indices
to framebuffer values. The hardware palette at indices 240-255
stores the RGB565 color values.

This enables RIPscrip and VT100 to coexist on the same
framebuffer without palette conflicts:

     Indices 0-239:   xterm-256 colors (VT100/ANSI text)
     Indices 240-255: EGA 16-color palette (RIPscrip graphics)

Palette save/restore functions (rip_save_palette,
rip_apply_palette) snapshot and restore indices 240-255 when
switching between protocols.


---------------------------------------------------------------------
§A2G.7  EXTENDED TEXT DIRECTION (CCW)
---------------------------------------------------------------------

The RIP_FONT_STYLE (|Y) command's direction field is extended
from two values to three:

     dir=0: Horizontal, left to right          (v1.54)
     dir=1: Vertical CW, top to bottom         (v3.1 corrected)
     dir=2: Vertical CCW, top to bottom         (v3.1 new)

See §A2G.2 for the full description of the direction correction
and the glyph rotation coordinate transforms.

The direction field is a 2-digit MegaNum (range 0-1295), so
values 0-2 are a small subset of the available range. Values
3-35 are reserved for future use (e.g., arbitrary angle
rotation with FPU, if needed).

     Wire format: !|Y010200|    (Triplex, dir=2, size 1)

Direction validation:
     dir > 2 → command rejected (no state change)
     dir 0-3 → stored in s->font_dir


=====================================================================
==                    END OF SEGMENT 6                              ==
==              v3.1 Extensions (§A2G.1 - §A2G.7)                   ==
=====================================================================

Next: Segment 6A — v3.2 Extensions (`06a-v32-extensions.md`)
