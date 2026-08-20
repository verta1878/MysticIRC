
=====================================================================
==       SEGMENT 2: LEVEL 0 DRAWING COMMANDS                       ==
=====================================================================

Level 0 commands handle all core drawing operations. They have no
level prefix — the command letter immediately follows the '|'
delimiter.

Each command entry follows this format:

     Function:     Human-readable name
     Command:      |<letter>
     Arguments:    Parameter list with MegaNum widths
     Format:       !|<letter><params>|
     Example:      Wire bytes with decoded values
     Attributes:   Which drawing state affects this command

Drawing state attributes:
     [DC] Uses draw color (g_color)
     [FC] Uses fill color (g_fill_color)
     [FP] Uses fill pattern (g_fill_pattern)
     [WM] Uses write mode (COPY/OR/AND/XOR/NOT)
     [LP] Uses line pattern (dash style)
     [LT] Uses line thickness
     [CL] Clipped to current viewport


---------------------------------------------------------------------
2.1  RIP_COLOR — Set Draw Color
---------------------------------------------------------------------

     Function:     Set Draw Color
     Command:      |c
     Arguments:    color:2
     Format:       !|c<color>|
     Example:      !|c0F|          color=15 (EGA white)

Sets the active drawing color used by all subsequent outline and
line drawing commands. The color parameter is an EGA palette index
(0-15), mapped to framebuffer values via s->palette[color].

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     color       2       0-15    EGA color index

EGA default palette:

     Index   Name            RGB565
     -----   -----------     ------
     0       Black           0x0000
     1       Blue            0x0015
     2       Green           0x0540
     3       Cyan            0x0555
     4       Red             0xA800
     5       Magenta         0xA815
     6       Brown           0xAAA0
     7       Light Gray      0xAD55
     8       Dark Gray       0x52AA
     9       Light Blue      0x52BF
     10      Light Green     0x57EA
     11      Light Cyan      0x57FF
     12      Light Red       0xFAAA
     13      Light Magenta   0xFABF
     14      Yellow          0xFFEA
     15      White           0xFFFF


---------------------------------------------------------------------
2.2  RIP_BACK_COLOR — Set Background Color
---------------------------------------------------------------------

     Function:     Set Background Color
     Command:      |k
     Arguments:    color:CM
     Format:       !|k<color>|
     Example:      !|k00|          color=0 (black)

Sets the background color used by erase commands (|e, |E, |*)
and text background fill.

The field is a COLOUR, so its width follows SET_COLOR_MODE and is two
digits at the default mode - dispatch slot 60 types it 0xFE, not a
literal 1.  RIPlib nonetheless accepts a single digit as well: of 133
'|k' commands in the corpus 132 send two, and N2_BUSI.RIP sends one.
That tolerance is deliberate and is registered in
14-divergence-register.md; two digits is the format to emit.

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     color       CM      0-15    EGA color index (2 digits by default)


---------------------------------------------------------------------
2.3  RIP_WRITE_MODE — Set Write Mode
---------------------------------------------------------------------

     Function:     Set Write Mode
     Command:      |W
     Arguments:    mode:2
     Format:       !|W<mode>|
     Example:      !|W00|          mode=0 (COPY)

Sets the pixel compositing mode for all drawing operations.

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     mode        2       0-4     Write mode

     Mode   Name    Operation          GDI raster op
     ----   ----    ---------          -------------
     0      COPY    dst = src          R2_COPYPEN  (0x0D)
     1      XOR     dst = dst ^ src    R2_XORPEN   (0x07)
     2      OR      dst = dst | src    R2_MERGEPEN (0x0F)
     3      AND     dst = dst & src    R2_MASKPEN  (0x09)
     4      NOT     dst = ~dst         R2_NOT      (0x06)

     CORRECTED 2026-08-12.  This table previously read 1=OR, 2=AND,
     3=XOR and described AND and NOT as v3.1 extensions.  Both
     claims were wrong.

     The ordering is established by disassembly of RIPSCRIP.DLL
     3.0.7: the '|W' handler (RVA 0x02102C) stores the wire byte
     unmodified, and the apply path passes it to a five-way
     translation (RVA 0x00E6B3) that calls GDI SetROP2 with the
     raster ops shown above.  The wire value IS the index, so there
     is no internal-vs-wire distinction of the kind the previous
     note asserted.  See docs/spec/12-dll-provenance.md §12.10.

     AND and NOT are not RIPlib extensions.  Both have been
     documented modes since v2.00 Alpha 1, and the translation
     above shows the shipping driver rendered them.  §DEAD.3's
     "parsed but never rendered" claim is corrected accordingly.

     Attributes: [WM] sets the mode used by all subsequent commands.


---------------------------------------------------------------------
2.4  RIP_FILL_STYLE — Set Fill Pattern and Color
---------------------------------------------------------------------

     Function:     Set Fill Pattern and Color
     Command:      |S
     Arguments:    pattern:2 color:2
     Format:       !|S<pattern><color>|
     Example:      !|S0100|        pattern=1 (solid), color=0 (black)

Sets the fill pattern and fill color used by filled shapes
(BAR, FILLED_OVAL, PIE_SLICE, FLOOD_FILL, etc.).

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     pattern     2       0-12    BGI fill pattern ID
     color       2       0-15    EGA fill color index

BGI fill patterns:

     ID   Name            Description
     --   -----------     ----------------------------------
     0    EMPTY_FILL      No fill (background only)
     1    SOLID_FILL      Solid fill
     2    LINE_FILL       Horizontal lines (---)
     3    LTSLASH_FILL    Light forward slash (///)
     4    SLASH_FILL      Forward slash (///)
     5    BKSLASH_FILL    Backslash (\\\)
     6    LTBKSLASH_FILL  Light backslash (\\\)
     7    HATCH_FILL      Light cross-hatch (+++)
     8    XHATCH_FILL     Heavy cross-hatch (XXX)
     9    INTERLEAVE_FILL Interleaved checker
     10   WIDE_DOT_FILL   Widely-spaced dots
     11   CLOSE_DOT_FILL  Closely-spaced dots
     12   USER_FILL       User-defined 8×8 pattern (see |s)

     Attributes: [FC] [FP] sets fill state for subsequent fills.


---------------------------------------------------------------------
2.5  RIP_FILL_PATTERN — Set Custom 8×8 Fill Pattern
---------------------------------------------------------------------

     Function:     Set Custom Fill Pattern
     Command:      |s
     Arguments:    pat[0]:2 pat[1]:2 ... pat[7]:2 color:2
     Format:       !|s<p0><p1><p2><p3><p4><p5><p6><p7><color>|
     Example:      !|s2S1E2S1E2S1E2S1E0F|   (checker, white)

Sets a user-defined 8×8 fill pattern. Each of the 8 pattern
bytes defines one row of the pattern (MSB = leftmost pixel).
The fill style is automatically set to USER_FILL (12).

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     pat[0-7]    2 each  0-255   8 rows of 8×8 pattern bitmap
     color       2       0-15    EGA fill color index

     Attributes: [FC] [FP] sets custom pattern + color.


---------------------------------------------------------------------
2.6  RIP_LINE_STYLE — Set Line Style
---------------------------------------------------------------------

     Function:     Set Line Style
     Command:      |=
     Arguments:    off_draw:1 style:1 user_pattern:4 thickness:2
     Format:       !|=<off_draw><style><user_pat><thick>|
     Example:      !|=00000001|    solid, no user pat, thickness=1

     Parameter   Width   Range    Description
     ---------   -----   ------   -----------
     off_draw    1       0-1      Reserved leading digit
     style       1       0-4      Predefined line style
     user_pat    4       0-65535  16-bit user dash pattern
     thickness   2       1-10     Line thickness in pixels

     Note: dispatch slot 14 types this as FOUR fields - mega1, mega1,
     mega4, mega2 - not the three that the 1.54 spec's "style:2"
     implies.  The total is eight characters either way, so the wire
     bytes are identical and only the split differs; the four-field
     reading is the one the driver and RIPlib both use.  RIPlib also
     accepts short forms, reading progressively: of 116 '|=' commands
     in the corpus 107 send eight characters, two send seven and seven
     send four.

     Note: thickness is Y-scaled (EGA 350→400) when used via
     RIPscrip protocol. The DLL applies ripScaleCoordY(thick).

Predefined line styles:

     ID   Name      Pattern byte
     --   -------   ------------
     0    SOLID     0xFF
     1    DOTTED    0x33
     2    CENTER    0xE7
     3    DASHED    0x1F
     4    USER      (from user_pattern parameter)

     Attributes: [LP] [LT] sets line state for subsequent lines.


---------------------------------------------------------------------
2.7  RIP_FONT_STYLE — Set Font Style
---------------------------------------------------------------------

     Function:     Set Font Style
     Command:      |Y
     Arguments:    font:2 dir:2 size:2 [flags:2]
     Format:       !|Y<font><dir><size>[<flags>]|
     Example:      !|Y010001|       Triplex, horiz, size 1

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     font        2       0-10    Font ID (see table below)
     dir         2       0-2     Text direction
     size        2       1-10    Character scale factor
     flags       2       0-63    Justification (optional, v3.0+)

Font IDs:

     ID   Name            Source
     --   -----------     --------
     0    Default         8×8 or 8×16 bitmap (CP437)
     1    Triplex         TRIP.CHR
     2    Small           LITT.CHR
     3    Sans-Serif      SANS.CHR
     4    Gothic          GOTH.CHR
     5    Script          SCRI.CHR
     6    Simplex         SIMP.CHR
     7    Triplex Script  TSCR.CHR
     8    Complex         LCOM.CHR
     9    European        EURO.CHR
     10   Bold            BOLD.CHR

Text directions:

     ID   Name    Rendering                              Version
     --   ----    ---------                              -------
     0    HORIZ   Left to right (standard)               v1.54
     1    CW      Top to bottom, clockwise rotation      v3.1 *
     2    CCW     Top to bottom, counter-clockwise        v3.1

     * v3.1 CORRECTION: The original v1.54 spec defines direction 1
       as "bottom to top" which renders English text backwards on
       screen. v3.1 corrects this to top-to-bottom (readable).
       No known BBS uses direction 1. See §A2G.7.

Justification flags (bits in flags parameter, v3.0+):

     Bit   Value   Horizontal
     ---   -----   ----------
     1     0x02    Center
     2     0x04    Right
     (default)     Left

     Bit   Value   Vertical
     ---   -----   --------
     4     0x10    Center
     5     0x20    Top
     6     0x40    Baseline
     (default)     Bottom

     Attributes: Sets font state for subsequent text commands.


---------------------------------------------------------------------
2.8  RIP_MOVE — Move Drawing Cursor
---------------------------------------------------------------------

     Function:     Move Drawing Cursor
     Command:      |m
     Arguments:    x:2 y:2
     Format:       !|m<x><y>|
     Example:      !|m2S1E|        x=100, y=50

Moves the drawing cursor to (x, y) without drawing. The y
coordinate is in EGA space (0-349) and is Y-scaled to the
card's framebuffer height.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x           2       0-639     X position (not scaled)
     y           2       0-349     Y position (EGA, scaled)


---------------------------------------------------------------------
2.9  RIP_LINE — Draw Line
---------------------------------------------------------------------

     Function:     Draw Line
     Command:      |L
     Arguments:    x0:2 y0:2 x1:2 y1:2
     Format:       !|L<x0><y0><x1><y1>|
     Example:      !|L002S5K46|    (0,100)→(200,150)

Draws a line from (x0,y0) to (x1,y1) using the Bresenham
algorithm with the current draw color, line pattern, and
line thickness.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x0          2       0-639     Start X
     y0          2       0-349     Start Y (EGA, scaled)
     x1          2       0-639     End X
     y1          2       0-349     End Y (EGA, scaled)

     Attributes: [DC] [WM] [LP] [LT] [CL]


---------------------------------------------------------------------
2.10  RIP_RECTANGLE — Draw Rectangle Outline
---------------------------------------------------------------------

     Function:     Draw Rectangle (outline)
     Command:      |R
     Arguments:    x0:2 y0:2 x1:2 y1:2
     Format:       !|R<x0><y0><x1><y1>|
     Example:      !|R0A0F0U16|    (10,15) to (30,42)

Draws a rectangular outline. Coordinates define the top-left
and bottom-right corners.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x0          2       0-639     Left X
     y0          2       0-349     Top Y (EGA, scale_y)
     x1          2       0-639     Right X
     y1          2       0-349     Bottom Y (EGA, scale_y1)

     Note: y0 uses scale_y (floor), y1 uses scale_y1 (ceiling)
     to ensure adjacent rectangles touch without gaps.

     Attributes: [DC] [WM] [LP] [CL]


---------------------------------------------------------------------
2.11  RIP_BAR — Draw Filled Rectangle
---------------------------------------------------------------------

     Function:     Draw Filled Rectangle (bar)
     Command:      |B
     Arguments:    x0:2 y0:2 x1:2 y1:2
     Format:       !|B<x0><y0><x1><y1>|
     Example:      !|B0A0F0U16|    filled (10,15) to (30,42)

Draws a filled rectangle using the current fill color and fill
pattern. No outline is drawn — use RIP_RECTANGLE for the outline.

     Attributes: [FC] [FP] [WM] [CL]


---------------------------------------------------------------------
2.12  RIP_CIRCLE — Draw Circle
---------------------------------------------------------------------

     Function:     Draw Circle (outline)
     Command:      |C
     Arguments:    cx:2 cy:2 radius:2
     Format:       !|C<cx><cy><r>|
     Example:      !|C8W4Q1E|      center (320,170), r=50

Draws a circle outline using the midpoint circle algorithm.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     cx          2       0-639     Center X
     cy          2       0-349     Center Y (EGA, scale_y)
     radius      2       1-350     Radius (EGA, scale_y)

     Note: radius is Y-scaled. This matches the DLL behavior
     (ripScaleCoordY applied to radius). On a 640×400 display,
     a protocol radius of 100 renders as 114 pixels.

     Attributes: [DC] [WM] [CL]


---------------------------------------------------------------------
2.13  RIP_FILLED_CIRCLE — Draw Filled Circle
---------------------------------------------------------------------

     Function:     Draw Filled Circle
     Command:      |G     (Extended, not in v1.54 Level 0)
     Arguments:    cx:2 cy:2 radius:2
     Format:       !|G<cx><cy><r>|

Draws a filled circle. If fill pattern is non-empty, fills with
fill color first, then draws outline in draw color.

     Attributes: [DC] [FC] [FP] [WM] [CL]


---------------------------------------------------------------------
2.14  RIP_OVAL — Draw Elliptical Arc
---------------------------------------------------------------------

     Function:     Draw Elliptical Arc (outline)
     Command:      |O
     Arguments:    cx:2 cy:2 start_angle:2 end_angle:2 rx:2 ry:2
     Format:       !|O<cx><cy><sa><ea><rx><ry>|

Draws an elliptical arc from start_angle to end_angle.
Angles are in degrees (0-359), measured counter-clockwise
from the 3 o'clock position (standard math convention).

     Parameter    Width   Range     Description
     ---------    -----   -------   -----------
     cx           2       0-639     Center X
     cy           2       0-349     Center Y (scale_y)
     start_angle  2       0-359     Start angle (degrees)
     end_angle    2       0-359     End angle (degrees)
     rx           2       1-639     X radius (not scaled)
     ry           2       1-349     Y radius (scale_y)

     Note: rx is NOT scaled (X identity: 640/640=1). ry IS scaled
     (EGA 350→400). This produces correct aspect ratios.

     Attributes: [DC] [WM] [CL]


---------------------------------------------------------------------
2.15  RIP_FILLED_OVAL — Draw Filled Ellipse
---------------------------------------------------------------------

     Function:     Draw Filled Ellipse
     Command:      |o     (lowercase)
     Arguments:    cx:2 cy:2 rx:2 ry:2
     Format:       !|o<cx><cy><rx><ry>|

Draws a filled ellipse (full 360°). If fill pattern is non-empty,
fills with fill color, then draws outline in draw color.

     Attributes: [DC] [FC] [FP] [WM] [CL]


---------------------------------------------------------------------
2.16  RIP_ARC — Draw Circular Arc
---------------------------------------------------------------------

     Function:     Draw Circular Arc
     Command:      |A
     Arguments:    cx:2 cy:2 start_angle:2 end_angle:2 radius:2
     Format:       !|A<cx><cy><sa><ea><r>|

Draws a circular arc. Radius is Y-scaled.

     Attributes: [DC] [WM] [CL]


---------------------------------------------------------------------
2.17  RIP_OVAL_ARC — Draw Elliptical Arc
---------------------------------------------------------------------

     Function:     Draw Elliptical Arc (with separate radii)
     Command:      |V
     Arguments:    cx:2 cy:2 start_angle:2 end_angle:2 rx:2 ry:2
     Format:       !|V<cx><cy><sa><ea><rx><ry>|

Same as RIP_OVAL but with an explicit command letter for clarity
in extended command sets. ry is Y-scaled, rx is not.

     Attributes: [DC] [WM] [CL]


---------------------------------------------------------------------
2.18  RIP_PIE_SLICE — Draw Pie Sector
---------------------------------------------------------------------

     Function:     Draw Pie Slice
     Command:      |I
     Arguments:    cx:2 cy:2 start_angle:2 end_angle:2 radius:2
     Format:       !|I<cx><cy><sa><ea><r>|

Draws a pie sector (arc + two radial lines from center to arc
endpoints). If fill pattern is non-empty, fills the sector with
fill color using scanline-based angle+distance testing (FPU),
then draws outline in draw color.

     v3.1 NOTE: The fill algorithm uses per-pixel atan2f angle
     testing instead of flood fill. This eliminates the pixel-gap
     leak bug present in implementations that use flood fill on
     the arc+radii boundary.

     Attributes: [DC] [FC] [FP] [WM] [CL]


---------------------------------------------------------------------
2.19  RIP_OVAL_PIE_SLICE — Draw Elliptical Pie Sector
---------------------------------------------------------------------

     Function:     Draw Elliptical Pie Slice
     Command:      |i     (lowercase)
     Arguments:    cx:2 cy:2 start_angle:2 end_angle:2 rx:2 ry:2
     Format:       !|i<cx><cy><sa><ea><rx><ry>|

Elliptical pie sector. ry is Y-scaled, rx is not.

     Attributes: [DC] [FC] [FP] [WM] [CL]


---------------------------------------------------------------------
2.20  RIP_BEZIER — Draw Cubic Bezier Curve
---------------------------------------------------------------------

     Function:     Draw Cubic Bezier Curve
     Command:      |Z
     Arguments:    x0:2 y0:2 x1:2 y1:2 x2:2 y2:2 x3:2 y3:2 steps:2
     Format:       !|Z<x0><y0><x1><y1><x2><y2><x3><y3><steps>|

Draws a cubic Bezier curve through four control points.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x0,y0       2,2     coords    Start point (on curve)
     x1,y1       2,2     coords    Control point 1
     x2,y2       2,2     coords    Control point 2
     x3,y3       2,2     coords    End point (on curve)
     steps       2       4-64      Subdivision steps (ignored*)

     * v3.1: The steps parameter is accepted for compatibility but
       ignored. RIPlib uses FPU parametric evaluation with adaptive
       step count based on control polygon length (4-64 steps auto).
       This produces smoother curves than fixed-step integer
       subdivision used by the original DLL.

     All Y coordinates are EGA-scaled (scale_y).

     Attributes: [DC] [WM] [CL]


---------------------------------------------------------------------
2.21  RIP_POLYGON — Draw Polygon Outline
---------------------------------------------------------------------

     Function:     Draw Polygon (outline)
     Command:      |P
     Arguments:    npts:2 x0:2 y0:2 x1:2 y1:2 ... xN:2 yN:2
     Format:       !|P<npts><x0><y0><x1><y1>...|

Draws a closed polygon outline through npts vertices.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     npts        2       3-128     Number of vertices
     x[i],y[i]   2,2     coords    Vertex coordinates

     All Y coordinates are EGA-scaled.
     Attributes: [DC] [WM] [LP] [CL]


---------------------------------------------------------------------
2.22  RIP_FILL_POLYGON — Draw Filled Polygon
---------------------------------------------------------------------

     Function:     Draw Filled Polygon
     Command:      |p     (lowercase)
     Arguments:    npts:2 x0:2 y0:2 ... xN:2 yN:2
     Format:       !|p<npts><x0><y0>...|

Draws a filled polygon using scanline fill, then draws outline.

     Attributes: [DC] [FC] [FP] [WM] [CL]


---------------------------------------------------------------------
2.23  RIP_POLYLINE — Draw Polyline (Open Path)
---------------------------------------------------------------------

     Function:     Draw Polyline
     Command:      |l     (lowercase L)
     Arguments:    npts:2 x0:2 y0:2 ... xN:2 yN:2
     Format:       !|l<npts><x0><y0>...|

Draws connected line segments through npts vertices. Unlike
polygon, the path is NOT closed (no line from last to first).

     Attributes: [DC] [WM] [LP] [LT] [CL]


---------------------------------------------------------------------
2.24  RIP_FLOOD_FILL — Flood Fill
---------------------------------------------------------------------

     Function:     Flood Fill
     Command:      |F
     Arguments:    x:2 y:2 border:2
     Format:       !|F<x><y><border>|
     Example:      !|F2S1E07|      fill at (100,50), border=7

Flood fills from seed point (x,y), stopping at pixels matching
the border color. Uses the current fill color and fill pattern.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x           2       0-639     Seed X
     y           2       0-349     Seed Y (scale_y)
     border      2       0-15      Border color index

Fill behavior:
     1. If seed pixel == border color → no fill (return)
     2. If seed pixel == fill color → no fill (return)
     3. Scanline expansion from seed, bounded by border color
     4. If fill pattern is active, applies pattern in second pass

     v3.1: Patterned flood fill uses a two-pass algorithm —
     solid fill first (for boundary tracking), then pattern
     application over the filled region. Pattern-OFF pixels are
     replaced with g_fill_color (background).

     Attributes: [FC] [FP] [WM] [CL]


---------------------------------------------------------------------
2.25  RIP_TEXT — Draw Text at Current Position
---------------------------------------------------------------------

     Function:     Draw Text
     Command:      |T
     Arguments:    text (free-form to frame end)
     Format:       !|T<text>|
     Example:      !|THello World|

Draws text at the current drawing cursor position (draw_x,
draw_y) using the current font, size, direction, and draw color.
Advances the cursor by the text width.

Text undergoes two processing steps:
     1. Backslash unescape (\\, \|, \^, \n)
     2. Variable expansion ($RAND$, $DATE$, etc.)

If font ID > 0 and the corresponding BGI stroke font is loaded,
text is rendered with the stroke font engine. Otherwise, the
bitmap CP437 font is used.

v3.1: If font_attrib is non-zero, text is rendered with
bgi_font_draw_string_ex() which applies bold, italic, underline,
and/or shadow effects to stroke font glyphs.

     Attributes: [DC] [WM] [CL] + font state


---------------------------------------------------------------------
2.26  RIP_TEXT_XY — Draw Text at Position
---------------------------------------------------------------------

     Function:     Draw Text at Coordinates
     Command:      |@
     Arguments:    x:2 y:2 text
     Format:       !|@<x><y><text>|
     Example:      !|@2S1EHello|   text at (100,50)

Sets draw cursor to (x,y) then draws text. Equivalent to
|m followed by |T but in a single command.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x           2       0-639     Text X position
     y           2       0-349     Text Y position (scale_y)
     text        var     ASCII     Text string to render

     Attributes: [DC] [WM] [CL] + font state


---------------------------------------------------------------------
2.27  RIP_PIXEL — Draw Single Pixel
---------------------------------------------------------------------

     Function:     Draw Pixel
     Command:      |X
     Arguments:    x:2 y:2
     Format:       !|X<x><y>|

Draws a single pixel at (x,y) in the current draw color.

     Attributes: [DC] [WM] [CL]


---------------------------------------------------------------------
2.28  RIP_GOTOXY — Move Text Cursor
---------------------------------------------------------------------

     Function:     Move Text Cursor (character grid position)
     Command:      |g
     Arguments:    col:2 row:2
     Format:       !|g<col><row>|

Moves the text cursor to character grid position (col, row).
Coordinates are in character cells, not pixels.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     col         2       0-79      Column (0-based)
     row         2       0-24      Row (0-based)


---------------------------------------------------------------------
2.29  RIP_HOME — Home Cursor
---------------------------------------------------------------------

     Function:     Home Cursor
     Command:      |H
     Arguments:    (none)
     Format:       !|H|

Moves the drawing cursor to (0, 0).


---------------------------------------------------------------------
2.30  RIP_ERASE_WINDOW — Erase Text Window
---------------------------------------------------------------------

     Function:     Erase Text Window
     Command:      |e
     Arguments:    (none)
     Format:       !|e|

Clears the text window to the background color.


---------------------------------------------------------------------
2.31  RIP_ERASE_VIEW — Erase Graphics Viewport
---------------------------------------------------------------------

     Function:     Erase Graphics Viewport
     Command:      |E
     Arguments:    (none)
     Format:       !|E|

Clears the current graphics viewport to the background color
and resets the drawing cursor to the viewport origin.


---------------------------------------------------------------------
2.32  RIP_ERASE_EOL — Erase to End of Line
---------------------------------------------------------------------

     Function:     Erase to End of Line
     Command:      |>
     Arguments:    (none)
     Format:       !|>|

Erases from the text cursor to the end of the current line
in the text window, using the background color.


---------------------------------------------------------------------
2.33  RIP_VIEWPORT — Set Graphics Viewport
---------------------------------------------------------------------

     Function:     Set Graphics Viewport
     Command:      |v
     Arguments:    x0:2 y0:2 x1:2 y1:2
     Format:       !|v<x0><y0><x1><y1>|

Sets the graphics clipping region. All drawing is clipped to
this rectangle. Coordinates are in EGA space; y0 uses scale_y
(floor), y1 uses scale_y1 (ceiling).

     v3.1 NOTE: Coordinates are normalized if reversed (x0>x1
     or y0>y1). This matches DLL behavior (sub_03112E).

     Attributes: Sets [CL] region for all subsequent drawing.


---------------------------------------------------------------------
2.34  RIP_TEXT_WINDOW — Set Text Window
---------------------------------------------------------------------

     Function:     Set Text Window
     Command:      |w
     Arguments:    x0:2 y0:2 x1:2 y1:2 wrap:1 font_size:1
     Format:       !|w<x0><y0><x1><y1><wrap><fsize>|

Defines the text window region in pixel coordinates.

     Parameter    Width   Range     Description
     ---------    -----   -------   -----------
     x0,y0        2,2    coords    Top-left corner
     x1,y1        2,2    coords    Bottom-right corner
     wrap          1     0-1       Word wrap enable
     font_size     1     1-4       Text font size


---------------------------------------------------------------------
2.35  RIP_SET_PALETTE — Set Full EGA Palette
---------------------------------------------------------------------

     Function:     Set 16-Color Palette
     Command:      |Q     (Level 0, not Level 1)
     Arguments:    c[0]:2 c[1]:2 ... c[15]:2
     Format:       !|Q<c0><c1>...<c15>|

Sets all 16 EGA palette entries. Each value is an EGA 64-color
index (0-63), converted to RGB565 via the EGA 6-bit color model.

     v3.1 FIX: Palette writes target hardware indices 240-255
     (not 0-15). EGA colors are mapped to framebuffer values
     240+i to avoid conflicting with the xterm-256 palette at
     indices 0-239 when coexisting with VT100 rendering.

EGA 64-color format (6-bit):

     Bit 5: Red secondary   (2/3 intensity)
     Bit 4: Green secondary
     Bit 3: Blue secondary
     Bit 2: Red primary     (full intensity)
     Bit 1: Green primary
     Bit 0: Blue primary

     Channel = (primary_bit << 1) | secondary_bit
     Gives 4 levels per channel: 0x00, 0x55, 0xAA, 0xFF


---------------------------------------------------------------------
2.36  RIP_ONE_PALETTE — Set Single Palette Entry
---------------------------------------------------------------------

     Function:     Set One Palette Entry
     Command:      |a
     Arguments:    index:2 color:2
     Format:       !|a<index><color>|

Sets a single EGA palette entry. Index 0-15, color is EGA
64-color value. Writes to hardware palette index 240+index.


---------------------------------------------------------------------
2.37  RIP_RESET_WINDOWS — Full State Reset
---------------------------------------------------------------------

     Function:     Full State Reset
     Command:      |*
     Arguments:    (none)
     Format:       !|*|

Resets ALL drawing state to defaults:
     - Draw color → 15 (white)
     - Fill color → 15 (white)
     - Fill pattern → 1 (solid)
     - Back color → 0 (black)
     - Write mode → 0 (COPY)
     - Line style → solid, thickness 1
     - Font → 0 (bitmap), direction 0, size 1
     - Viewport → full screen (0,0)-(639,349)
     - Palette → EGA defaults at indices 240-255
     - Mouse regions → all cleared
     - Text window → full screen

Clears screen to background color and homes cursor.


---------------------------------------------------------------------
2.38  RIP_NO_MORE — End of Scene
---------------------------------------------------------------------

     Function:     End of RIPscrip Scene
     Command:      |#
     Arguments:    (none)
     Format:       !|#|

Signals end of the current RIPscrip scene. The client should
stop expecting additional RIPscrip commands until a new '!'
trigger. Used by BBSes to mark "this screen is complete."


---------------------------------------------------------------------
2.39  RIP_PUSH_STATE — Push Drawing State (§A2G)
---------------------------------------------------------------------

     Function:     Push drawing state to stack
     Command:      |^
     Arguments:    (none)
     Format:       !|^|

Saves the current drawing prelude (colors, fill/line/write state,
font fields, draw cursor, viewport rect) onto a bounded LIFO stack
(8 frames).  Overflow is silently dropped.  See §A2G.8 for the
full list of captured fields and the lifecycle (cleared by |*).


---------------------------------------------------------------------
2.40  RIP_POP_STATE — Pop Drawing State (§A2G)
---------------------------------------------------------------------

     Function:     Restore drawing state from stack
     Command:      |~
     Arguments:    (none)
     Format:       !|~|

Pops the most recent |^ frame back into the active state and
immediately re-applies the draw layer (color, write mode, clip).
Pop on an empty stack is a no-op.  See §A2G.8.


=====================================================================
==                    END OF SEGMENT 2                              ==
==           Level 0 Drawing Commands                               ==
=====================================================================

Next: Segment 3 — Level 1 Interactive Commands
