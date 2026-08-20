
=====================================================================
==       SEGMENT 4: EXTENDED COMMANDS (v2.0+)                      ==
=====================================================================

Extended commands were added in RIPscrip v2.0 and later versions.
They use Level 0 routing (no prefix) with command letters not
used in the original v1.54 specification.

These commands provide: rounded rectangles, scroll operations,
poly-Bezier curves, bounded text, extended polygon/polyline
operations, draw-to, animation frames, extended mouse regions,
extended buttons, extended text windows, extended font styles,
font attributes, icon operations, and coordinate/color modes.


---------------------------------------------------------------------
4.1  RIP_FILLED_CIRCLE — Filled Circle
---------------------------------------------------------------------

     Function:     Draw Filled Circle
     Command:      |G
     Arguments:    cx:2 cy:2 radius:2
     Format:       !|G<cx><cy><r>|

Draws a filled circle. If fill pattern is non-empty, fills with
fill color first, then draws outline in draw color. Radius is
Y-scaled (EGA 350→400).

     Attributes: [DC] [FC] [FP] [WM] [CL]


---------------------------------------------------------------------
4.2  RIP_ROUNDED_RECT — Rounded Rectangle Outline
---------------------------------------------------------------------

     Function:     Draw Rounded Rectangle (outline)
     Command:      |U
     Arguments:    x0:2 y0:2 x1:2 y1:2 radius:2
     Format:       !|U<x0><y0><x1><y1><r>|
     Example:      !|U0A0F3K2A08|   (10,15)-(128,42) r=8

Draws a rectangle with rounded corners. Corner arcs are rendered
using the midpoint circle algorithm. Radius is clamped to half
the smaller dimension.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x0,y0       2,2     coords    Top-left corner
     x1,y1       2,2     coords    Bottom-right corner
     radius      2       1-100     Corner radius (scale_y)

     v3.1: Previously stubbed as plain rectangle. Now renders
     native rounded corners using quarter-arc + straight edge
     algorithm. Essential for polished button/dialog rendering
     and QuickDraw II FrameRRect parity.

     Attributes: [DC] [WM] [LP] [CL]


---------------------------------------------------------------------
4.3  RIP_FILLED_ROUNDED_RECT — Filled Rounded Rectangle
---------------------------------------------------------------------

     Function:     Draw Filled Rounded Rectangle
     Command:      |u     (lowercase)
     Arguments:    x0:2 y0:2 x1:2 y1:2 radius:2
     Format:       !|u<x0><y0><x1><y1><r>|

Draws a filled rounded rectangle. If fill pattern is non-empty,
fills with fill color, then draws outline in draw color.

     Attributes: [DC] [FC] [FP] [WM] [CL]


---------------------------------------------------------------------
4.4  RIP_SKEWED_OVAL_CHORD — Rotated Elliptical Chord
---------------------------------------------------------------------

     Function:     Skewed Oval Chord
     Command:      |+
     Arguments:    cx:2 cy:2 rx:2 ry:2 start:2 end:2 skew:2
     Format:       !|+<cx><cy><rx><ry><start><end><skew>|

CORRECTED.  This letter was documented as RIP_SCROLL.  The dispatch
record gives argc 7 with types XY,XY,XY,XY,mega2,mega2,mega2, and
TeleGrafix's own commented demo ICONS/NEWCMDS.RIP labels it
"RIP_SKEWED_OVAL_CHORD".

The six skewed-oval commands below share one geometry generator.  Angles
run counter-clockwise from east; `skew` rotates the whole ellipse and is a
whole number of degrees, not a shear factor or an aspect ratio.  A sweep
whose end angle is less than its start wraps through 0.  Origin: the
driver walks the outline one point per degree and hands the run to a
polygon fill, so these are polygons, not GDI ellipses.  See
docs/spec/12-dll-provenance.md section 12.14.

Draws the arc from `start` to `end` and closes it with a straight line
between the endpoints, filling the enclosed area.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     cx,cy       2,2     coords    Centre of the ellipse
     rx,ry       2,2     coords    Radii, before rotation
     start,end   2,2     0-359     Sweep, counter-clockwise from east
     skew        2       0-359     Rotation of the whole ellipse


---------------------------------------------------------------------
4.5  RIP_COPY_REGION_EXT — Extended Copy Region
---------------------------------------------------------------------

     Function:     Extended Copy Region
     Command:      |,
     Arguments:    sx0:2 sy0:2 sx1:2 sy1:2 dx:2 dy:2
                   dx1:2 dy1:2 res:2 res:2
     Format:       !|,<sx0><sy0><sx1><sy1><dx><dy><dx1><dy1><r><r>|

Extended version of copy region with separate source and
destination rectangles. If the destination rectangle is present
and differs in size, RIPlib scales the source region into it.


---------------------------------------------------------------------
4.6  RIP_FILLED_SKEWED_OVAL — Filled Rotated Ellipse
---------------------------------------------------------------------

     Function:     Filled Skewed Oval
     Command:      |-
     Arguments:    cx:2 cy:2 rx:2 ry:2 skew:2
     Format:       !|-<cx><cy><rx><ry><skew>|

CORRECTED.  This letter was documented as RIP_TEXT_XY_EXT.  Its handler
is instruction-for-instruction identical to '|&' apart from frame size --
the filled and outline members of one shape -- and NEWCMDS.RIP labels it
"RIP_FILLED_SKEWED_OVAL".

Draws the full ellipse (a 0..360 sweep of the shared generator) filled
with the current fill state, honouring '|N' for the border.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     cx,cy       2,2     coords    Centre of the ellipse
     rx,ry       2,2     coords    Radii, before rotation
     skew        2       0-359     Rotation, whole degrees

The bounded-text capability this section used to describe is not lost:
RIPlib keeps it on '|3-' as a library extension.


---------------------------------------------------------------------
4.7  RIP_POLY_BEZIER — Multi-Segment Bezier
---------------------------------------------------------------------

     Function:     Draw Multi-Segment Bezier Curve
     Command:      |z     (lowercase)
     Arguments:    nsegs:2 nsteps:2 [x0:2 y0:2 x1:2 y1:2
                   x2:2 y2:2 x3:2 y3:2] × nsegs
     Format:       !|z<nsegs><nsteps><points...>|

Draws multiple connected cubic Bezier curve segments.
Each segment uses 4 control points (8 coordinates).

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     nsegs       2       1-16      Number of Bezier segments
     nsteps      2       4-64      Steps per segment (ignored*)
     points      8/seg   coords    4 control points per segment

     * v3.1: nsteps is accepted for compatibility but RIPlib
       uses FPU adaptive step count per segment.


---------------------------------------------------------------------
4.8  RIP_BOUNDED_TEXT — Text with Bounding Box
---------------------------------------------------------------------

     Function:     Bounded Text
     Command:      |"
     Arguments:    x0:2 y0:2 x1:2 y1:2 flags:2 text
     Format:       !|"<x0><y0><x1><y1><flags><text>|

Draws text within a bounding rectangle with justification
and optional clipping. Similar to TEXT_XY_EXT but with
additional formatting control.


---------------------------------------------------------------------
4.9  RIP_SKEWED_OVAL_PIE_SLICE — Rotated Elliptical Pie Slice
---------------------------------------------------------------------

     Function:     Skewed Oval Pie Slice
     Command:      |[
     Arguments:    cx:2 cy:2 rx:2 ry:2 start:2 end:2 skew:2
     Format:       !|[<cx><cy><rx><ry><start><end><skew>|

CORRECTED from RIP_FILLED_POLYGON_EXT.  A polygon command takes a
variable vertex count by nature, yet this entry is fixed-arity 7 with the
same signature as '|+' and '|]' -- three letters, one family.

Draws the arc from `start` to `end` and closes it through the CENTRE,
filling the wedge.  Fields are as section 4.4.


---------------------------------------------------------------------
4.10  RIP_SKEWED_OVAL_ARC — Rotated Elliptical Arc
---------------------------------------------------------------------

     Function:     Skewed Oval Arc
     Command:      |]
     Arguments:    cx:2 cy:2 rx:2 ry:2 start:2 end:2 skew:2
     Format:       !|]<cx><cy><rx><ry><start><end><skew>|

CORRECTED from RIP_POLYLINE_EXT.  This is the OPEN member of the family:
the run is stroked and never filled, and the driver reaches
GDI32!Polyline here where its four siblings reach GDI32!Polygon.

Fields are as section 4.4.


---------------------------------------------------------------------
4.11  RIP_FILLED_OVAL_CHORD — Filled Elliptical Chord
---------------------------------------------------------------------

     Function:     Filled Oval Chord
     Command:      |_
     Arguments:    cx:2 cy:2 start:2 end:2 rx:2 ry:2
     Format:       !|_<cx><cy><start><end><rx><ry>|

CORRECTED from RIP_DRAW_TO, which needs a single coordinate pair against
this entry's six arguments.

NOTE THE FIELD ORDER: the angles sit in the MIDDLE here, matching '|V'
RIP_OVAL_ARC rather than the four skewed members above.  The dispatch
types confirm it -- XY,XY,mega2,mega2,XY,XY -- and this is not a skewed
variant, so there is no skew field.

TeleGrafix's demo issues this one with start=324 end=216, a sweep that
wraps through 0.  A decoder that rejects end < start draws nothing.


---------------------------------------------------------------------
4.12  RIP_ANIMATION_FRAME — Animation Frame
---------------------------------------------------------------------

     Function:     Animation Frame
     Command:      |{
     Arguments:    x0:2 y0:2 x1:2 y1:2 x2:2 y2:2
     Format:       !|{<x0><y0><x1><y1><x2><y2>|

Defines an animation frame with source, destination, and
timing coordinates. Used for simple sprite-like animations.

     v3.1 STATUS: Embedded fallback. RIPlib renders the frame
     geometry immediately; timer-based sprite playback remains a
     host/client responsibility.


---------------------------------------------------------------------
4.13  RIP_FILLED_RECTANGLE — Filled Rectangle
---------------------------------------------------------------------

     Function:     Filled Rectangle
     Command:      |K
     Arguments:    x0:2 y0:2 x1:2 y1:2
     Format:       !|K<x0><y0><x1><y1>|

CORRECTED from RIP_KILL_MOUSE_EXT.  Four coordinate pairs describe a
rectangle, not a mouse operation; the handler orders (x0,x1) and (y0,y1)
through the driver's pair-ordering helper, which is rectangle setup, and
it reaches GDI32!Rectangle -- the same primitive as '|B' RIP_BAR and
'|R' RIP_RECTANGLE.  SyncTERM binds 'K' the same way.

Fills with the current fill state and honours '|N' for the border.

The mouse-field kill this section used to describe is '|1k'
RIP_KILL_ENCLOSED_MOUSE_FIELDS, which is a separate and real command.


---------------------------------------------------------------------
4.14  RIP_MOUSE_REGION_EXT — Extended Mouse Region
---------------------------------------------------------------------

     Function:     Extended Mouse Region
     Command:      |:
     Arguments:    x0:XY y0:XY x1:XY y1:XY x2:XY y2:XY
                   x3:XY y3:XY x4:XY y4:XY flags:1
     Format:       !|:<x0><y0><x1><y1><x2><y2><x3><y3><x4><y4><flags>|

CORRECTED.  This was documented as a rectangle carrying a 2-digit
hotkey and a 2-digit flags field, twenty-two characters in all.

Slot 11 records XY×10 followed by a single mega1 — twenty-one
characters — and the handler (RVA 0x01DD70) loads all eleven
arguments and coordinate-maps exactly five consecutive (x,y)
pairs.  This is a five-vertex region, not a rectangle: the fields
previously read as hotkey and flags are the third vertex.

RIPlib registers the bounding box of the five vertices as the
hit-area.  The polygon itself is not retained, so hit-testing is a
conservative over-approximation.  See D-14.


---------------------------------------------------------------------
4.15  RIP_POLY_MARKER — Draw a Marker Glyph
---------------------------------------------------------------------

     Function:     Poly Marker
     Command:      |;
     Arguments:    x:2 y:2 marker:2 w:2 h:2 rotation:2 flags:2
     Format:       !|;<x><y><marker><w><h><rotation><flags>|

CORRECTED from RIP_BUTTON_EXT.  The handler names itself
RIP_PolyMarker() and validates every scalar field with its own
diagnostic, which gives the signature outright:

     marker   < 36     "Invalid marker number"
     rotation < 360    "Invalid marker rotation angle (>=360)"
     flags    <= 3     "Invalid marker flags value"

TeleGrafix's ICONS/MARKER.RIP -- titled "RIPscrip Markers" on screen --
exercises exactly numbers 0..35, rotations 0..300 and sizes from 1x1
upward, matching every bound.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x,y         2,2     coords    Marker centre
     marker      2       0-35      Which of 36 glyph designs
     w,h         2,2     coords    Marker size
     rotation    2       0-359     Rotation, whole degrees
     flags       2       0-3       Presentation flags

THE 36 GLYPHS.  Marker 0 is a CIRCLE: the driver dispatches it to the same
ellipse generator the skewed-oval family uses, with a full 0..360 sweep.
Markers 1-35 are polygon outlines held in a descriptor table --
{ uint16 count; int32 (*points)[2]; } at RVA 0x07ca48, 6 bytes per entry --
whose coordinates live in a normalised +/-50 space that the handler scales
by the marker's half-width and half-height and rotates by its skew.

RIPlib carries all 36 outlines, extracted by
scripts/dll-marker-glyphs.py.  The set runs from simple shapes (1 is a
plus, 6 and 20 are triangles of different sizes) through to stars of
increasing point count (28 through 34), 462 points in total.


---------------------------------------------------------------------
4.16  RIP_EXT_TEXT_WINDOW — Extended Text Window
---------------------------------------------------------------------

     Function:     Extended Text Window
     Command:      |b
     Arguments:    x0:XY y0:XY x1:XY y1:XY width:2 height:2
                   font:1 flags:4 res:3
     Format:       !|b<x0><y0><x1><y1><width><height><font><flags><res>|
     Example:      !|b00000A0A0F0F00000000|

Extended text window with cell metrics, font and formatting control.

CORRECTED 2026-08-15.  This table read args[4] and args[5] as
FOREGROUND and BACKGROUND COLOURS and args[7] as a font SIZE.  They are
a cell WIDTH, a cell HEIGHT and the FLAGS word.  Slot 20 names itself
RIP_ExtendedTextWindow() in five diagnostics and validates four fields:

     args[7] > 0x3FF        "Flags value is out of range"
     args[6] >= 5           "Font number is out of range"
       (unless flags bit 3 is set)
     args[4] == 0           "Zero width value is not allowed"
     args[5] == 0           "Zero height value is not allowed"

then queries text-window protection.  A colour index does not produce
"Zero width value is not allowed" -- that one string unpicked three
fields at once.  The parser was corrected first; this table lagged it by
two commits, which is the drift 14.4 exists to catch.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x0,y0       XY,XY   coords    Window top-left
     x1,y1       XY,XY   coords    Window bottom-right
     width       2       1-1295    Cell width; zero is refused
     height      2       1-1295    Cell height; zero is refused
     font        1       0-4       Font ID (0-35 when flags bit 3 set)
     flags       4       0-1023    Formatting flags; above 0x3FF refused
     res         3       0         Reserved

---------------------------------------------------------------------
4.17  RIP_ONE_DRAWING_PALETTE — Set One Palette Entry
---------------------------------------------------------------------

     Function:     One Drawing Palette
     Command:      |d                        (BASE 64 -- see 1.5.1)
     Arguments:    index:2 bits:1 rgb:4
     Format:       !|d<index><bits><rgb>|

CORRECTED.  This section documented '|d' as RIP_EXT_FONT_STYLE.  It is a
palette command: the handler names itself RIP_OneDrawingPalette() and
validates all three fields with distinct diagnostics --

     index <= 255       "Color palette index out of range"
     bits  == 8         "Bits value out of range"
     rgb   <= 0xFFFFFF  "RGB Color value is out of range!"

Extended font style is '|y' RIP_EXT_FONT_STYLE, section 4.17a.

     Parameter   Width   Range        Description
     ---------   -----   ----------   ------------------------------
     index       2       0-255        Palette entry to write
     bits        1       8 exactly    Bits per channel
     rgb         4       0-0xFFFFFF   24-bit colour, 0xRRGGBB

The rgb bound is why this command is base 64: a 4-digit base-64 field
spans exactly 0..0xFFFFFF, while base 36 caps at 1679615 and the
handler's own range check could never fire.  '|D' (section 4.26) is the
block form.


---------------------------------------------------------------------
4.17a  RIP_EXT_FONT_STYLE — Extended Font Style
---------------------------------------------------------------------

     Function:     Extended Font Style
     Command:      |y                        (BASE 64 -- see 1.5.1)
     Arguments:    11 fields, 26 characters total
     Widths:       1,1,4,2,2,2,2,2,2,2,6
     Format:       !|y<26 chars>|

The driver's real extended font-style command.  Field widths come from
the dispatch record and total 26 characters, which independently matches
the "26-digit layout" recovered from FONTS.RIP by the bbs-land
reconstruction.

Fields identified from the handler's validation branches:

     Field   Offset  Description
     -----   ------  --------------------------------------------
     arg5    10      String rotation:    0 / 90 / 180 / 270
     arg6    12      Character rotation: same set
     arg8    16      Character spacing, per cent; must be non-zero

The driver compares rotations against 0/900/1800/2700 -- tenths of a
degree -- after scaling the 2-digit wire field by 10.

The remaining fields are parsed at their correct widths but not
interpreted; their meanings have not been recovered, and assigning them
would be a guess.

Base 64 shows plainly in real content: every '|y' in TeleGrafix's
shipped scenes carries "1a1a" in its two scale fields, which is 100,100
in base 64 -- a percentage -- and a meaningless 46,46 in base 36.


---------------------------------------------------------------------
4.18  RIP_FONT_ATTRIB — Font Attribute Flags
---------------------------------------------------------------------

     Function:     Set Font Attributes
     Command:      |q
     Arguments:    attrib:2
     Format:       !|q<attrib>|
     Example:      !|q01|          bold only

     LETTER CORRECTED 2026-08-12.  This command was documented on
     '|f' with a reserved second field.  '|f' is RIP_SetWorldFrame
     in the shipping driver; font attributes are slot 55, '|q',
     taking a single argument which the driver range-checks <= 0x0F.
     See docs/spec/12-dll-provenance.md D-1.

Sets font rendering attributes for subsequent text commands.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     attrib      2       0-15      Attribute bitmask
     reserved    2       0         Reserved

Attribute bits:

     Bit   Value   Name        Rendering Effect
     ---   -----   --------    --------------------------------
     0     0x01    BOLD        Draw strokes twice, +1px offset
     1     0x02    ITALIC      Shear X by top*scale/5 (FPU)
     2     0x04    UNDERLINE   Baseline line after string
     3     0x08    SHADOW      Dark offset copy behind string

     v3.1: All four attributes are now rendered. Previously
     parsed but not applied in any known implementation.
     Bold uses double-stroke, italic uses FPU shear, underline
     draws at baseline+2, shadow uses dimmed RGB332 color.


---------------------------------------------------------------------
4.19  RIP_HEADER — Scene Header
---------------------------------------------------------------------

     Function:     Scene Header
     Command:      |h                        (BASE 64 -- see 1.5.1)
     Arguments:    type:2 id:4 flags:2
     Format:       !|h<type><id><flags>|

Defines metadata for the current RIPscrip scene (type,
identifier, and behavioral flags).

The driver accepts several signatures for this letter and selects among
them by how many characters the stream supplies; RIPlib takes the first
match by length.  No scene in TeleGrafix's shipped content uses '|h', so
the base-64 marking follows the dispatch record rather than observed
content.


---------------------------------------------------------------------
4.20  RIP_SET_COORDINATE_SIZE — Set Coordinate Size
---------------------------------------------------------------------

     Function:     Set Coordinate Size
     Command:      |n
     Arguments:    byte_size:1 res:3
     Format:       !|n<byte_size><res>|

Sets the encoded byte width for every argument the dispatch record types
as a coordinate.  The driver resolves that width at decode time:

     literal count   use it as-is (1, 2 or 4 digits)
     coordinate      use this command's byte_size
     colour          use the width from '|M' SET_COLOR_MODE

RIPlib honours this.  Its handlers read fixed 2-digit fields, so rather
than make 262 decode sites width-aware, a payload arriving under any
other negotiated width is rewritten to 2-digit fields before dispatch.
Literal-width arguments are copied at their own width; only the ones the
dispatch record types as coordinate or colour are converted.

The conversion saturates at 1295, the largest value two digits hold.
That is a real bound but not a practical one here: RIPlib renders into a
fixed 640x400 device space without a world-to-device transform, so a
coordinate above 1295 is off-screen whatever width carried it.

All 24 uses of '|n' in TeleGrafix's shipped content request 2, the
default, in which case the rewrite is skipped entirely.  See
docs/spec/12-dll-provenance.md D-11.


---------------------------------------------------------------------
4.21  RIP_SET_COLOR_MODE — Set Color Mode
---------------------------------------------------------------------

     Function:     Set Color Depth Mode
     Command:      |M
     Arguments:    mode:1 depth:1
     Format:       !|M<mode><depth>|

Sets the color mode (EGA 16-color, VGA 256-color, etc.).
RIPlib records palette-vs-direct-RGB mode for `$COLORMODE$`; the
embedded drawing surface remains palette-indexed.


---------------------------------------------------------------------
4.22  RIP_SET_BORDER — Filled Object Border Control
---------------------------------------------------------------------

     Function:     Enable/disable borders on filled objects
     Command:      |N
     Arguments:    borders:2
     Format:       !|N<borders>|

Controls whether filled objects draw an outline in the current
draw color after filling. `00` disables borders; nonzero enables
them. Borders are drawn with write mode COPY, matching the v2.A3
spec. RIP_BAR remains borderless.

     Note: this is dispatch slot 48, which records one mega2 and
     whose handler names itself RIP_SetBorder.  Its handler address
     (0x00dcf1) sits among the LEVEL 1 handlers rather than with the
     other level-0 ones, which is a quirk of code placement, not of
     the protocol - the slot number, the recovered name and the
     argument type all place it at level 0.  Do not confuse it with
     RIPlib's level-1 '|1N' RIP_SET_ICON_DIR, which shares the letter
     but has no dispatch entry at all.


---------------------------------------------------------------------
4.23  RIP_SKEWED_OVAL — Rotated Ellipse Outline
---------------------------------------------------------------------

     Function:     Skewed Oval
     Command:      |&
     Arguments:    cx:2 cy:2 rx:2 ry:2 skew:2
     Format:       !|&<cx><cy><rx><ry><skew>|

CORRECTED from RIP_ICON_STYLE.  NEWCMDS.RIP labels this letter
"RIP_SKEWED_OVAL", and its handler is identical to '|-' apart from frame
size -- the outline member of that pair.  Fields are as section 4.6.

The icon display style this section used to describe is not lost: RIPlib
keeps it on '|3&' as a library extension.


---------------------------------------------------------------------
4.24  RIP_STAMP_ICON — Stamp Icon at Position
---------------------------------------------------------------------

     Function:     Stamp Icon
     Command:      |.
     Arguments:    slot:2 x:2 y:2 w:2 h:2 flags:2
     Format:       !|.<slot><x><y><w><h><flags>|

Stamps a previously saved icon slot at the given position
with optional scaling and flags.


---------------------------------------------------------------------
4.25  RIP_SET_BASE_MATH — Select the MegaNum Radix
---------------------------------------------------------------------

     Function:     Set Base Math
     Command:      |J
     Arguments:    base:2
     Format:       !|J<base>|

CORRECTED from RIP_SAVE_ICON.  The handler names itself
RIP_SetBaseMath() and accepts exactly two values -- 36 and 64 -- forcing
36 for anything else, then stores the byte in engine state.  It selects
the MegaNum radix for everything that follows, which is why it appears
near the top of most real scenes.

This command is itself ALWAYS decoded in base 36, so its argument can
never be ambiguous.  A consequence: '|J10' is 36 in base 36 and 64 in
base 64, so it ASSERTS the current radix rather than changing it.  Every
'|J' in TeleGrafix's shipped content is '|J10'.  See section 1.5.1.

The icon-slot save this section used to describe is a RIPlib mechanism
with no dispatch entry; it moves to '|3J'.


---------------------------------------------------------------------
4.26  RIP_SET_DRAWING_PALETTE — Write a Block of Palette Entries
---------------------------------------------------------------------

     Function:     Set Drawing Palette
     Command:      |D                        (BASE 64 -- see 1.5.1)
     Arguments:    start:2 count:2 bits:1 then count * rgb:4
     Format:       !|D<start><count><bits><rgb>...<rgb>|

CORRECTED from RIP_FILL_PATTERN_EXT.  The handler names itself
RIP_SetDrawingPalette() and its validation chain gives the layout
outright:

     argc == count + 3   "Invalid number of parameters"
     count <= 256        "More than 256 entries"
     start <= 255        "Start is out of range"
     bits  == 8          "Invalid number of bits"

This is the block form of '|d' RIP_ONE_DRAWING_PALETTE.  Both are always
base 64: a 4-digit base-64 field spans exactly 0..0xFFFFFF, which is the
range the handler enforces on each RGB value.

The 8x8 user fill pattern this section used to describe is '|s'
RIP_FILL_PATTERN, with an identical payload.


---------------------------------------------------------------------
4.27  RIP_POLY_POLYGON — Multi-Contour Polygon
---------------------------------------------------------------------

     Function:     Poly Polygon
     Command:      |<
     Arguments:    count:2 then per contour  nverts:2 (x:2 y:2)*
     Format:       !|<<count><nverts><x><y>...<nverts><x><y>...|

CORRECTED from RIP_GET_IMAGE_EXT, a fixed rectangle read, against a
variable-length entry.  The handler's own diagnostics are "Must have at
least two vertices to make a polygon" and "Insufficient vertices (2)",
and it is the only handler in the table that reaches GDI32!PolyPolygon.
TeleGrafix's ICONS/POLYPOLY.RIP exercises it and prints
"RIP_POLY_POLYGON" on screen.

THE INTERIOR IS EVEN-ODD ACROSS ALL CONTOURS TOGETHER, so overlapping
contours cut holes.  That is the point of the command: the demo draws a
circle behind the shape and comments "so you can see the transparency
aspect".  Filling each contour independently paints the holes solid and
loses exactly the effect being demonstrated.

Clipboard capture is unaffected -- that is '|1C' RIP_GET_IMAGE.


=====================================================================
==                    END OF SEGMENT 4                              ==
==           Extended Commands (v2.0+)                              ==
=====================================================================

Next: Segment 5 — Level 2 Drawing Port System
