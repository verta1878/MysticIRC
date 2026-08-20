
=====================================================================
==       SEGMENT 5: LEVEL 2 DRAWING PORT SYSTEM                   ==
=====================================================================

Level 2 commands manage the Drawing Port system introduced in
RIPscrip v2.0. Ports provide independent drawing contexts with
separate viewport, color, fill, font, and line state. They are
prefixed with '2' after the '|' delimiter.

     Format: !|2<cmd><parameters>|

The port system enables multi-region rendering: a BBS can create
separate drawing areas (e.g., a menu bar, content area, and status
bar), switch between them, and copy pixels between port viewports.

On the original DLL, each port had its own GDI Device Context and
off-screen bitmap.  In RIPlib, all ports share a single framebuffer
with per-port state save/restore and clip-region management.


---------------------------------------------------------------------
5.1  PORT ARCHITECTURE
---------------------------------------------------------------------

The port system provides up to 36 drawing port slots (0-35).

     Port 0:   Permanent full-screen port. Cannot be deleted.
               Always exists. Protected by default.

     Ports 1-35: User-created ports with arbitrary viewport
                 rectangles. Created on demand, explicitly
                 deleted, or auto-created on switch.

Each port stores:

     Field          Type     Default    Description
     ----------     ------   -------    --------------------------
     allocated      bool     false      Port slot in use
     flags          uint8    0x00       Protection + fullscreen
     vp_x0,y0      int16    0,0        Viewport top-left (card px)
     vp_x1,y1      int16    639,399    Viewport bottom-right
     origin_x,y    int16    0,0        Coordinate origin offset
     draw_x,y      int16    0,0        Drawing cursor position
     draw_color     uint8    15         Current draw color (white)
     fill_color     uint8    15         Current fill color
     fill_pattern   uint8    1          Fill pattern (solid)
     back_color     uint8    0          Background color (black)
     write_mode     uint8    0          Write mode (COPY)
     line_style     uint8    0          Line dash pattern (solid)
     line_thick     uint8    1          Line thickness
     font_id        uint8    0          Font ID (bitmap)
     font_size      uint8    1          Font scale
     font_dir       uint8    0          Text direction (horiz)
     font_hjust     uint8    0          Horizontal justification
     font_vjust     uint8    0          Vertical justification
     alpha          uint8    35         Opacity (v3.1: 0-35)
     comp_mode      uint8    0          Compositing mode (v3.1)
     zorder         uint8    0          Z-order layer (v3.1)

Port flags:

     Bit   Value   Name                Description
     ---   -----   ----------------    -------------------------
     0     0x01    PORT_PROTECTED      Cannot be redefined/deleted
     1     0x02    PORT_FULLSCREEN     Viewport = full screen

Special port index values:

     Value    Name             Meaning
     ------   ---------------  ---------------------------
     0xFF     PORT_IDX_CURRENT Use the current active port
     0xFE     PORT_IDX_ALL     All ports (bulk operation)
     0xFD     PORT_IDX_FIRST   First available unprotected


---------------------------------------------------------------------
5.2  RIP_DEFINE_PORT — Create or Redefine Port
---------------------------------------------------------------------

     Function:     Define Drawing Port
     Command:      |2P
     Arguments:    port:1 x0:XY y0:XY x1:XY y1:XY [flags:4] [res:4]
     Format:       !|2P<port><x0><y0><x1><y1>[<flags>][<res>]|
     Example:      !|2P10A000K0U|   port 1, (10,0)-(20,30)

Creates a new port or redefines an existing one. Port 0 cannot
be redefined. Protected ports reject redefinition.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     port        1       1-35      Port slot number
     x0,y0       XY,XY   coords    Viewport top-left (EGA)
     x1,y1       XY,XY   coords    Viewport bottom-right (EGA)
     flags       4       0-15      Optional creation flags

     Note: the flags field is a full mega4 read at offset 9, not a
     mega2 - dispatch slot 111 records mega1, XY, XY, XY, XY, mega4,
     mega4.  RIPlib reads the first of those two mega4s and ignores
     the second, so it consumes 13 of the record's 17 characters.
     Only bits 1..3 exist; bits 2 and 3 of an earlier RIPlib reading
     were invented and have been removed.

Creation flags:

     Bit   Value   Effect
     ---   -----   ------
     1     0x02    Make active immediately after creation
     2     0x04    Set PORT_FULLSCREEN flag
     3     0x08    Set PORT_PROTECTED flag

Viewport coordinates are Y-scaled (EGA 350→card 400):
     vp_y0 = scale_y(y0)       (floor)
     vp_y1 = scale_y1(y1)      (ceiling)

On creation, all drawing state is initialized to defaults
(white color, solid fill, bitmap font, COPY mode).


---------------------------------------------------------------------
5.3  RIP_DELETE_PORT — Delete Port
---------------------------------------------------------------------

     Function:     Delete Drawing Port
     Command:      |2p     (lowercase)
     Arguments:    port:1 res:1 res:2
     Format:       !|2p<port><res><res>|

Deletes a port and frees its slot. Port 0 cannot be deleted.
Protected ports reject deletion unless force-deleted.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     port        1       0-35      Port slot (or special index)
     res         1       0         Reserved
     res         2       0         Reserved

     Note: dispatch slot 116 records mega1 + mega1 + mega2, so the
     payload is FOUR characters, not one.  RIPlib gates on that
     length; it reads the port index and ignores both reserved
     fields.

Special values:

     0xFE (PORT_IDX_ALL):     Delete all non-protected ports
     0xFF (PORT_IDX_CURRENT): Delete the active port

When the active port is deleted, the system falls back to port 0.


---------------------------------------------------------------------
5.4  RIP_SWITCH_PORT — Switch Active Port
---------------------------------------------------------------------

     Function:     Switch Active Drawing Port
     Command:      |2s
     Arguments:    port:1 switch_flags:2
     Format:       !|2s<port><flags>|
     Example:      !|2s000|        switch to port 0, no flag action

     The second field is a FLAGS word, not a reserved pair, and every
     Switch* command carries it -- '|2A' '|2B' '|2E' '|2T' '|2Y' as
     well as '|2s'.  Four bits are acted on:

          bit   effect
          ---   -------------------------------------------
          2     protect the slot being LEFT
          3     unprotect the slot being LEFT
          0     protect the slot being ENTERED
          1     unprotect the slot being ENTERED

     RIPlib honours these for ports only; for the other five families
     the flags are ignored.  See 14-divergence-register.md 14.3.6.

     All three '|2s' commands in the shipped corpus are exactly three
     characters -- "000", "002", "100" -- so the field is not
     optional in practice either.

Switches the active drawing port. Saves the current port's
state and loads the target port's state.

     Parameter      Width   Range   Description
     -----------    -----   -----   -----------
     port           1       0-35    Target port (or special)
     switch_flags   2       0-15    Optional protection control

Switch flags:

     Bit   Value   Effect
     ---   -----   ------
     0     0x01    Protect destination port after switch
     1     0x02    Unprotect destination port after switch
     2     0x04    Protect source port before switch
     3     0x08    Unprotect source port before switch

Switch process:
     1. Apply source protection flags (if specified)
     2. Save current port's drawing state (12 fields)
     3. Auto-create target port if not allocated (full-screen)
     4. Apply destination protection flags (if specified)
     5. Set active port to target
     6. Load target port's drawing state
     7. Apply target's viewport as hardware clip rectangle

If port == PORT_IDX_CURRENT (0xFF), the current port's state
is reloaded (useful for re-applying viewport after changes).


---------------------------------------------------------------------
5.5  RIP_PORT_COPY — Copy Between Ports
---------------------------------------------------------------------

     Function:     Copy Pixels Between Port Viewports
     Command:      |2C
     Arguments:    src:1 sx0:XY sy0:XY sx1:XY sy1:XY
                   dst:1 dx0:XY dy0:XY dx1:XY dy1:XY [wmode:1] [res:5]
     Format:       !|2C<src><sx0><sy0><sx1><sy1><dst><dx0><dy0><dx1><dy1>[<wm>][<res>]|

Copies a rectangular region from one port's viewport to another.

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     src         1       0-35    Source port
     sx0-sy1     XY×4    coords  Source rectangle (EGA)
     dst         1       0-35    Destination port
     dx0-dy1     XY×4    coords  Destination rectangle (EGA)
     wmode       1       0-4     Write mode (optional, default 0)
     res         5       0       Reserved (optional)

     Note: dispatch slot 113 records TWELVE fields totalling 24
     characters - the eleven above plus a five-character reserved
     tail this table previously omitted.  RIPlib gates on 18, reads
     the nineteenth as the write mode when present, and ignores the
     reserved tail.

Special cases:
     - All-zero source rect: use entire source viewport
     - All-zero dest rect: use upper-left of dest viewport

Source and destination may be the same port (intra-port copy).
Y coordinates are scaled. On embedded, uses draw_copy_rect
since all ports share one framebuffer. On DLL, used BitBlt
between independent GDI DCs.


---------------------------------------------------------------------
5.6  RIP_PORT_FLAGS — Set Extended Port Attributes
---------------------------------------------------------------------

     Function:     Set Port Flags (v3.1 Extension)
     Command:      |2F
     Arguments:    port:1 [alpha:1] [comp_mode:2] [zorder:2]
     Format:       !|2F<port>[<alpha>][<comp>][<z>]|

Sets extended attributes on a port: opacity, compositing mode,
and z-order for layered rendering.

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     port        1       0-35    Target port
     alpha       1       0-35    Opacity (0=transparent, 35=opaque)
     comp_mode   2       0-3     Compositing mode (0=COPY)
     zorder      2       0-255   Z-order for compositor layering

     v3.1 EXTENSION: These attributes are RIPlib additions not
     present in any DLL version. They enable windowed desktop
     compositing where ports represent overlapping windows with
     transparency and z-ordering.


---------------------------------------------------------------------
5.7  RIP_SET_VGA_PALETTE — Set VGA Palette Entry
---------------------------------------------------------------------

     Function:     Set VGA 256-Color Palette Entry
     Command:      |20     (that is: '2' + '0')
     Arguments:    index:2 red:2 green:2 blue:2
     Format:       !|20<idx><r><g><b>|
     Example:      !|200A3F3F00|    index 10, R=255, G=255, B=0

Sets a single entry in the 256-color VGA palette. RGB values
are 0-255 (full 8-bit per channel).

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     index       2       0-255   Palette entry index
     red         2       0-255   Red channel (8-bit)
     green       2       0-255   Green channel (8-bit)
     blue        2       0-255   Blue channel (8-bit)

Internally converts to RGB332 for the local palette and
RGB565 for the hardware palette:

     rgb332 = (R>>5)<<5 | (G>>5)<<2 | (B>>6)
     rgb565 = (R>>3)<<11 | (G>>2)<<5 | (B>>3)


---------------------------------------------------------------------
5.8  RIP_GRADIENT_FILL — Gradient Fill
---------------------------------------------------------------------

     Function:     Gradient Rectangle Fill
     Command:      |28
     Arguments:    x:2 y:2 w:2 h:2 color1:2 color2:2 vertical:2
     Format:       !|28<x><y><w><h><c1><c2><vert>|

Fills a rectangle with a linear gradient between two colors.

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     x,y         2,2     coords  Top-left corner
     w,h         2,2     size    Width and height
     color1      2       0-255   Start color (palette index)
     color2      2       0-255   End color (palette index)
     vertical    2       0-1     0=horizontal, 1=vertical

Gradient interpolation is per-scanline (horizontal) or
per-column (vertical), linearly blending RGB332 channels
between color1 and color2.


---------------------------------------------------------------------
5.9  RIP_SCALABLE_TEXT — Scalable Text
---------------------------------------------------------------------

     Function:     Scalable Text
     Command:      |26
     Arguments:    scale:2 rotation:2
     Format:       !|26<scale><rotation>|

Sets the active text scale and rotation for subsequent text commands.

     scale     Integer magnification, clamped to 1-10 (the BGI stroke
               renderer's supported range; the same range the |Y
               RIP_FONT_STYLE size field uses). Projected onto the
               BGI font_size. Out-of-range values fall back to 1.
     rotation  Degrees, snapped to the nearest 90° quadrant:
               0°→horizontal, 90°→vertical CW, 270°→vertical CCW.
               180° has no stroke-renderer mapping and falls back to
               horizontal.

NOTE: earlier draft spec text described scaling "beyond the standard
1-10 range." RIPlib's stroke renderer tops out at scale 10, so the
implementation clamps there rather than honouring larger values. This
is the renderer's true ceiling, documented in `11-dll-deviations.md`
§DEV.3.


---------------------------------------------------------------------
5.10  RIP_SET_WINDOW — Define Window Region
---------------------------------------------------------------------

     Function:     Define Window Region
     Command:      |22
     Arguments:    x:2 y:2 w:2 h:2
     Format:       !|22<x><y><w><h>|

Defines a window region with border and title bar.
Renders a basic window frame at the specified position.


---------------------------------------------------------------------
5.11  RIP_SCROLLBAR — Scrollbar Widget
---------------------------------------------------------------------

     Function:     Draw Scrollbar
     Command:      |23
     Arguments:    x:2 y:2 w:2 h:2 min:2 max:2 pos:2 page:2
     Format:       !|23<x><y><w><h><min><max><pos><page>|

Draws a scrollbar widget with track, thumb, and border.

     Parameter   Width   Range   Description
     ---------   -----   -----   -----------
     x,y         2,2     coords  Scrollbar position
     w,h         2,2     size    Track dimensions
     min         2       0-max   Minimum value
     max         2       min+    Maximum value
     pos         2       min-max Current position
     page        2       1-range Page size (thumb proportion)


---------------------------------------------------------------------
5.12  RIP_MENU — Menu Bar Widget
---------------------------------------------------------------------

     Function:     Draw Menu Bar
     Command:      |24
     Arguments:    y:2 h:2 bg_color:2 (additional params vary)
     Format:       !|24<y><h><bg>...|

Draws a horizontal menu bar at the specified Y position.


---------------------------------------------------------------------
5.13  RIP_DIALOG — Dialog Box Widget
---------------------------------------------------------------------

     Function:     Draw Dialog Box
     Command:      |25
     Arguments:    x:2 y:2 w:2 h:2 title_color:2 bg_color:2
     Format:       !|25<x><y><w><h><tc><bg>|

Draws a dialog box with shadow, title bar, and background fill.


---------------------------------------------------------------------
5.14  RIP_REFRESH — Host-Triggered Refresh
---------------------------------------------------------------------

     Function:     Trigger Screen Refresh
     Command:      |2R
     Arguments:    res:4
     Format:       !|2R<res>|

Forces the client to refresh the entire screen. Marks all
scanlines dirty for the DMA engine to re-transfer.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     res         4       0         Reserved

     Note: dispatch slot 117 records one mega4, so this is NOT a
     zero-argument command - RIPlib used to treat it as one, which
     left four characters in the stream.  The field is consumed so
     the frame stays in sync and recorded for capability queries;
     the driver does not otherwise act on it.


---------------------------------------------------------------------
5.15  RIP_CHORD — Chord Drawing
---------------------------------------------------------------------

     Function:     Draw Chord (arc with straight closing line)
     Command:      |2c     (lowercase)
     Arguments:    (same as arc parameters)
     Format:       !|2c...|

Draws an arc with a straight line connecting the endpoints
(chord), rather than radial lines to center (pie).


=====================================================================
==                    END OF SEGMENT 5                              ==
==           Level 2 Drawing Port System                            ==
=====================================================================

Next: Segment 6 — v3.1 Extensions (§A2G)
