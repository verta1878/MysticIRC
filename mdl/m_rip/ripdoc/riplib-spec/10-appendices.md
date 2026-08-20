
=====================================================================
==       SEGMENT 10: APPENDICES                                    ==
=====================================================================


---------------------------------------------------------------------
A.1  COMMAND QUICK-REFERENCE TABLE
---------------------------------------------------------------------

All commands sorted by level and command letter.

     AUTHORITY NOTE (2026-08-12).  Where this table disagrees with
     docs/spec/13-dll-command-table.md, THAT table wins: it is the
     shipping driver's own dispatch table read out of the binary,
     with each command's real arity and argument types.  Several
     rows below were corrected against it; rows still marked
     "(unverified)" have not been reconciled and should not be
     relied on for interoperability.

LEVEL 0 — Core Drawing (no prefix):

     Cmd  Name                   Args  Format
     ---  --------------------   ----  ---------------------------
     c    COLOR                  2     !|c<color>|
     k    BACK_COLOR             1     !|k<color>|
     W    WRITE_MODE             2     !|W<mode>|
     S    FILL_STYLE             4     !|S<pat><color>|
     s    FILL_PATTERN           18    !|s<p0>..<p7><color>|
     =    LINE_STYLE             8     !|=<style><upat><thick>|
     Y    FONT_STYLE             6+    !|Y<font><dir><size>[<flags>]|
     m    MOVE                   4     !|m<x><y>|
     g    GOTOXY                 4     !|g<col><row>|
     H    HOME                   0     !|H|
     *    RESET_WINDOWS          0     !|*|
     e    ERASE_WINDOW           0     !|e|
     E    ERASE_VIEW             0     !|E|
     >    ERASE_EOL              0     !|>|
     v    VIEWPORT               8     !|v<x0><y0><x1><y1>|
     w    TEXT_WINDOW             10    !|w<x0><y0><x1><y1><wr><fs>|
     Q    SET_PALETTE             32    !|Q<c0>..<c15>|
     a    ONE_PALETTE             4     !|a<idx><color>|
     L    LINE                   8     !|L<x0><y0><x1><y1>|
     R    RECTANGLE              8     !|R<x0><y0><x1><y1>|
     B    BAR                    8     !|B<x0><y0><x1><y1>|
     C    CIRCLE                 6     !|C<cx><cy><r>|
     O    OVAL                   12    !|O<cx><cy><sa><ea><rx><ry>|
     o    FILLED_OVAL            8     !|o<cx><cy><rx><ry>|
     A    ARC                    10    !|A<cx><cy><sa><ea><r>|
     V    OVAL_ARC               12    !|V<cx><cy><sa><ea><rx><ry>|
     I    PIE_SLICE              10    !|I<cx><cy><sa><ea><r>|
     i    OVAL_PIE_SLICE         12    !|i<cx><cy><sa><ea><rx><ry>|
     Z    BEZIER                 18    !|Z<x0><y0>..<x3><y3><steps>|
     P    POLYGON                var   !|P<n><x0><y0>..|
     p    FILL_POLYGON           var   !|p<n><x0><y0>..|
     l    POLYLINE               var   !|l<n><x0><y0>..|
     F    FLOOD_FILL             6     !|F<x><y><border>|
     T    TEXT                   var   !|T<text>|
     @    TEXT_XY                var   !|@<x><y><text>|
     X    PIXEL                  4     !|X<x><y>|
     #    NO_MORE                0     !|#|

LEVEL 0 — Extended Commands (v2.0+):

     Cmd  Name                   Args  Format
     ---  --------------------   ----  ---------------------------
     G    FILLED_CIRCLE          6     !|G<cx><cy><r>|
     U    ROUNDED_RECT           10    !|U<x0><y0><x1><y1><r>|
     u    FILLED_ROUNDED_RECT    10    !|u<x0><y0><x1><y1><r>|
     +    SKEWED_OVAL_CHORD      14    !|+<cx><cy><rx><ry><st><end><skew>|  (was SCROLL)
     ,    COPY_REGION            20    !|,<sx0>..<dy1><r><r>|
     -    FILLED_SKEWED_OVAL     10    !|-<cx><cy><rx><ry><skew>|  (was TEXT_XY_EXT)
     x    FILLED_POLY_BEZIER     var   !|x<nsegs><nsteps><pts..>|
     z    POLY_BEZIER            var   !|z<nsegs><nsteps><pts..>|
     "    BOUNDED_TEXT           var   !|"<x0><y0><x1><y1><fl><text>|
     [    SKEWED_OVAL_PIE_SLICE  14    !|[<cx><cy><rx><ry><st><end><skew>|
     ]    SKEWED_OVAL_ARC        14    !|]<cx><cy><rx><ry><st><end><skew>|
     _    FILLED_OVAL_CHORD      12    !|_<cx><cy><st><end><rx><ry>|  (was DRAW_TO)
     {    ANIMATION_FRAME        12    !|{<x0><y0><x1><y1><x2><y2>|
     K    FILLED_RECTANGLE       8     !|K<x0><y0><x1><y1>|  (was KILL_MOUSE_EXT)
     :    MOUSE_REGION_EXT       21    !|:<x0><y0>..<x4><y4><fl>|  (five vertices)
     ;    POLY_MARKER            14    !|;<x><y><num><x2><y2><rot><fl>|  (was BUTTON_EXT)
     b    EXT_TEXT_WINDOW        var   !|b<x0><y0>..<flags>|
     d    ONE_DRAWING_PALETTE    7     !|d<index><bits><rgb>|  (BASE 64; was EXT_FONT_STYLE)
     f    SET_WORLD_FRAME        4     !|f<x_dim><y_dim>|
     j    POINT                  4     !|j<x><y>|
     r    TEXT_METRIC            6     !|r<mode><domain><res>|
     y    EXT_FONT_STYLE         26    !|y<26 chars>|          (BASE 64)
     h    HEADER                 8     !|h<type><id><flags>|   (BASE 64)
     q    FONT_ATTRIB            2     !|q<attrib>|
     n    SET_COORD_SIZE         4     !|n<byte_size><res>|
     M    SET_COLOR_MODE         2     !|M<mode><depth>|
     N    SET_BORDER             2     !|N<borders>|
     &    SKEWED_OVAL            10    !|&<cx><cy><rx><ry><skew>|  (was ICON_STYLE)
     .    STAMP_ICON             12    !|.<slot><x><y><w><h><fl>|
     J    SET_BASE_MATH          2     !|J<base>|      (was SAVE_ICON)
     D    SET_DRAWING_PALETTE    var   !|D<start><count><bits><rgb..>|  (BASE 64; was FILL_PATTERN_EXT)
     <    POLY_POLYGON         var     (variable-length; was GET_IMAGE_EXT)
     t    POLY_BEZIER_LINE       var   !|t<nsegs><nsteps><pts..>|  (was REGION_TEXT, B8)
     `    COMPOSITE_ICON         var   !|`<n><pairs..><mode>|
     !    COMMENT                var   !|!<text>|   (consumed, no output)
     ( )  GROUP_BEGIN / _END     0     !|(|  !|)|  (no-op markers)

     (The backtick COMPOSITE_ICON, the '!' comment marker and the
      '('/')' group markers are all PRESENT in RIPSCRIP.DLL 3.0.7 —
      they are documented commands, not RIPlib extensions.  See
      11-dll-deviations.md §DEV.4, corrected 2026-08-12.)

LEVEL 1 — Interactive (prefix '1'):

     Cmd  Name                   Args  Format
     ---  --------------------   ----  ---------------------------
     K    KILL_MOUSE             0     !|1K|
     M    MOUSE_REGION           var   !|1M<x0><y0>..<text>|
     B    BUTTON_STYLE           30    !|1B<wid><hgt>..<res>|
     U    BUTTON                 var   !|1U<x0><y0>..<text>|
     C    GET_IMAGE              9     !|1C<x0><y0><x1><y1><r>|
     P    PUT_IMAGE              6     !|1P<x><y><mode>|
     T    BEGIN_TEXT             10    !|1T<x0><y0><x1><y1><r>|
     t    REGION_TEXT            var   !|1t<justify><text>|
     E    END_TEXT               0     !|1E|
     G    SCROLL                 12    !|1G<x0><y0><x1><y1><md><ex><dy>|  (was COPY_REGION)
     I    LOAD_ICON              var   !|1I<x><y>..<filename>|
     W    WRITE_ICON             var   !|1W...|
     A    PLAY_AUDIO             var   !|1A<filename>|
     Z    PLAY_MIDI              var   !|1Z<filename>|
     i    IMAGE_STYLE            6     !|1i<x0><y0><x1><y1><fl>|  (was 1S)
     g    COPY_BLIT              14    !|1g<sx0><sy0><sx1><sy1><dx><dy><md><r>|
     N    SET_ICON_DIR           var   !|1N<path>|
     F    FILE_QUERY             var   !|1F<mode><res><filename>|
     D    DEFINE_VARIABLE        var   !|1D<name>=<value>|
     O    FONT_LOAD              var   !|1O<filename>|
     Q    QUERY_EXT              var   !|1Q<flags><res><varname>|
     V    SET_VIEWPORT_EXT       9     !|1V<x0><y0><x1><y1><scale>|
     X    CLIPBOARD_OP           var   !|1X<op>[<params>]|
     R    READ_SCENE             var   !|1R<filename>|

     (1R is PRESENT in the driver as RIP_ReadScene and is NOT a
      RIPlib extension.  Only 1V and 1X are RIPlib-original — see
      11-dll-deviations.md §DEV.4, corrected 2026-08-12. 1V sets the viewport
      and stores a scale field; 1X is a compound clipboard op
      [0=clear 1=flipH 2=flipV 3=rot180 4=invert 5=capture 6=paste];
      1R queues a scene-file request to the host.)

LEVEL 2 — Drawing Ports (prefix '2'):

     Cmd  Name                   Args  Format
     ---  --------------------   ----  ---------------------------
     P    DEFINE_PORT            var   !|2P<port><x0><y0>..[<fl>]|
     p    DELETE_PORT            1     !|2p<port>|
     s    SWITCH_PORT            var   !|2s<port>[<flags>]|
     C    PORT_COPY              var   !|2C<src><sx0>..<wm>|
     F    PORT_FLAGS             var   !|2F<port>[<a>][<cm>][<z>]|
     0    SET_VGA_PALETTE        8     !|20<idx><r><g><b>|
     8    GRADIENT_FILL          14    !|28<x><y><w><h><c1><c2><v>|
     6    SCALABLE_TEXT          var   !|26...|
     2    SET_WINDOW             8     !|22<x><y><w><h>|
     3    SCROLLBAR              16    !|23<x><y>..<page>|
     4    MENU                   var   !|24<y><h><bg>...|
     5    DIALOG                 12    !|25<x><y><w><h><tc><bg>|
     R    REFRESH                0     !|2R|
     c    CHORD                  var   !|2c...|


---------------------------------------------------------------------
A.2  EGA 16-COLOR DEFAULT PALETTE
---------------------------------------------------------------------

     Index   Name            R      G      B      RGB565
     -----   -----------     ----   ----   ----   ------
     0       Black           0x00   0x00   0x00   0x0000
     1       Blue            0x00   0x00   0xAA   0x0015
     2       Green           0x00   0xAA   0x00   0x0540
     3       Cyan            0x00   0xAA   0xAA   0x0555
     4       Red             0xAA   0x00   0x00   0xA800
     5       Magenta         0xAA   0x00   0xAA   0xA815
     6       Brown           0xAA   0xAA   0x00   0xAAA0
     7       Light Gray      0xAA   0xAA   0xAA   0xAD55
     8       Dark Gray       0x55   0x55   0x55   0x52AA
     9       Light Blue      0x55   0x55   0xFF   0x52BF
     10      Light Green     0x55   0xFF   0x55   0x57EA
     11      Light Cyan      0x55   0xFF   0xFF   0x57FF
     12      Light Red       0xFF   0x55   0x55   0xFAAA
     13      Light Magenta   0xFF   0x55   0xFF   0xFABF
     14      Yellow          0xFF   0xFF   0x55   0xFFEA
     15      White           0xFF   0xFF   0xFF   0xFFFF

Hardware palette mapping (v3.1):
     EGA index N → framebuffer value 240 + N
     Hardware palette[240+N] = RGB565 value from table above


---------------------------------------------------------------------
A.3  EGA 64-COLOR PALETTE ENCODING
---------------------------------------------------------------------

The RIP_SET_PALETTE command uses EGA 64-color indices (0-63).
Each index encodes a 6-bit color with 2 bits per channel:

     Bit layout: r'g'b'RGB
          Bit 5: Red secondary    (2/3 intensity)
          Bit 4: Green secondary
          Bit 3: Blue secondary
          Bit 2: Red primary      (full intensity)
          Bit 1: Green primary
          Bit 0: Blue primary

     Channel = (primary_bit << 1) | secondary_bit
     4 levels: 0x00, 0x55, 0xAA, 0xFF

Conversion to RGB565:

     uint16_t ega64_to_rgb565(uint8_t ega) {
          uint8_t R = ((ega >> 2) & 1) << 1 | ((ega >> 5) & 1);
          uint8_t G = ((ega >> 1) & 1) << 1 | ((ega >> 4) & 1);
          uint8_t B = ((ega >> 0) & 1) << 1 | ((ega >> 3) & 1);
          static const uint8_t lut[4] = {0x00, 0x55, 0xAA, 0xFF};
          uint8_t r8 = lut[R], g8 = lut[G], b8 = lut[B];
          return ((uint16_t)(r8 >> 3) << 11) |
                 ((uint16_t)(g8 >> 2) << 5)  |
                 ((uint16_t)(b8 >> 3));
     }


---------------------------------------------------------------------
A.4  COORDINATE SCALING REFERENCE
---------------------------------------------------------------------

RIPscrip protocol coordinates use the EGA pixel grid (640×350).
The implementation framebuffer may have a different height.

Standard mapping for 640×400 framebuffer:

     scale_y(y)  = (y * 8) / 7           floor (top edges)
     scale_y1(y) = (y * 8 + 6) / 7       ceiling (bottom edges)

The ceiling variant (scale_y1) ensures adjacent rectangles
touch without gaps at their shared edges.

     EGA Y    Card Y (floor)   Card Y (ceil)
     -----    --------------   -------------
     0        0                0
     50       57               58
     100      114              115
     175      200              200
     200      228              229
     250      285              286
     300      342              343
     349      398              399

X coordinates are NOT scaled (640/640 = identity transform).

Radius scaling:
     Circle, arc, and pie radii are Y-scaled using scale_y().
     Ellipse Y-radius is Y-scaled; X-radius is NOT scaled.
     This matches DLL behavior (ripScaleCoordY applied to radii).


---------------------------------------------------------------------
A.5  SESSION LIFECYCLE
---------------------------------------------------------------------

RIPscrip sessions have three lifecycle states:

     rip_init_first() — Boot-time initialization
          Called once at firmware startup.
          Allocates PSRAM arena.
          Parses all 10 BGI stroke fonts from flash.
          Sets EGA default palette at indices 240-255.
          Initializes port 0 (full-screen, protected).
          Seeds $RAND$ LCG from RTC timestamp.

     rip_activate() — Protocol switch-in
          Called when switching TO the RIPscrip protocol
          from another protocol (e.g., VT100).
          Restores saved EGA palette (rip_apply_palette).
          Restores drawing state from rip_state_t.
          Does NOT re-parse fonts (already loaded).

     rip_session_reset() — Disconnect cleanup
          Called when the BBS connection ends.
          Saves current palette (rip_save_palette).
          Clears mouse regions.
          Resets PSRAM arena (frees all cached icons).
          Clears icon file request queue.
          Resets all drawing state to defaults.
          Does NOT free or re-parse fonts.

State diagram:

     BOOT ──→ rip_init_first() ──→ IDLE
                                      │
                    ┌─────────────────┘
                    ↓
     BBS connects → rip_activate() ──→ ACTIVE
                                         │
                    ┌────────────────────┘
                    ↓
     BBS disconnects → rip_session_reset() ──→ IDLE
                                                 │
                    ┌───────────────────────────┘
                    ↓
     New BBS connects → rip_activate() ──→ ACTIVE ...


---------------------------------------------------------------------
A.6  WRITE MODE REFERENCE
---------------------------------------------------------------------

     Mode   Name   Operation         Pixel Result
     ----   ----   ---------         --------------------------------
     0      COPY   dst = src         Source replaces destination
     1      OR     dst = dst | src   Bits are added (brightens)
     2      AND    dst = dst & src   Only common bits kept (masks)
     3      XOR    dst = dst ^ src   Bits toggled (invertible)
     4      NOT    dst = ~dst        Destination inverted (src ignored)

     XOR and NOT are self-inverse:
          XOR twice = original
          NOT twice = original


---------------------------------------------------------------------
A.7  FILL PATTERN REFERENCE
---------------------------------------------------------------------

     ID   Name              Hex Rows (8×8 bitmap, MSB=left)
     --   ---------------   --------------------------------
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
     11   USER_PATTERN      (custom, set via |s command)
     12   EMPTY_FILL        (no fill — background only)

Pattern bit interpretation:
     1 = foreground pixel (draw color)
     0 = background pixel (back color)

Pattern tiling: pattern row = y & 7, pattern bit = 0x80 >> (x & 7)


---------------------------------------------------------------------
A.8  VERSION HISTORY
---------------------------------------------------------------------

     Version   Date          Author
     -------   -----------   ---------
     v1.54     July 1993     TeleGrafix Communications
     v2.0      ~1995-1996    TeleGrafix Communications
     v3.0      Oct 1997      TeleGrafix Communications (DLL only)
     v3.1      March 2026    SimVU (Brad Hawthorne) / RIPlib

v1.54: Original specification. 35 Level 0 + 17 Level 1 commands.
       MegaNum encoding, EGA 640×350, 16-color palette, BGI fonts.

v2.0:  Drawing Ports (36 slots), extended commands (rounded rect,
       scroll, poly-bezier, bounded text, widgets), VGA 256-color
       palette, extended text windows and font styles.

v3.0:  DLL-based implementation (RIPSCRIP.DLL, 592KB PE32).
       Added font justification, gradient fill, scalable text,
       menu/dialog/scrollbar widgets, host refresh, chord drawing.
       Never formally published as a specification.

v3.1:  RIPlib extensions. AND+NOT write modes, CCW text,
       corrected vertical direction, font attribute rendering,
       13 native fill patterns, FPU curves/trig, scanline pie fill,
       patterned flood fill, palette index correction (240-255),
       port alpha/compositing/zorder. Backward-compatible with
       all prior versions.


=====================================================================
==                    END OF SEGMENT 10                             ==
==                       Appendices                                 ==
=====================================================================


=====================================================================
==                                                                  ==
==     RIPscrip Graphics Protocol Specification v3.1                ==
==     Complete — 10 Segments                                       ==
==                                                                  ==
==     (c) 1993-1997 TeleGrafix Communications, Inc.                ==
==     (c) 2026 SimVU (Brad Hawthorne) — v3.1 Extensions            ==
==                                                                  ==
==     RIPlib: https://github.com/BradHawthorne/riplib              ==
==                                                                  ==
=====================================================================
