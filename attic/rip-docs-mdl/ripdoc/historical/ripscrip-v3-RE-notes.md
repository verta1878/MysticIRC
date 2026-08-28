

             ------------------------------------------
              RIPscrip Graphics Protocol Specification
                    "Remote Imaging Protocol"

             Version 3.0 — Reconstructed Supplement

                    Copyright (c) 1993-1997
                TeleGrafix Communications, Inc.
                      All Rights Reserved

                     Driver Build:  3.0.7
                     Protocol ID:   RIPSCRIP030001

                        March 2026
             ------------------------------------------




NOTE (2026-08-12): This document was removed from the repository in
commit 5a76df8 ("Roll RE deviations/errata/bugs into v3.1 spec") and
restored after that roll-up was found to be lossy -- it had replaced
sourced findings with unsourced summaries, and several segment-11
claims could not be checked without it.  It is the SUBSTRATE for
segments 11, 12 and 13; those segments summarise, this one cites.

Consumer-specific sections (gap analysis and extension mapping for a
particular downstream firmware) were extracted per the project's
"extract, don't delete" rule and live outside the public tree.  The
TeleGrafix reverse-engineering record below is unchanged.


=====================================================================
==                           INTRODUCTION                          ==
=====================================================================

This document is a supplement to the published RIPscrip v1.54
Protocol Specification (TeleGrafix Communications, July 1993) and
the RIPscrip v2.00 Protocol Specification (TeleGrafix Communications,
Revision 2.A4, approximately 1995-1996).  It catalogs the complete
feature surface of the RIPscrip v3.0 rendering driver as shipped in
the production release of RIPtel Visual Telnet(tm) v3.1 (October
1997).

The v3.0 protocol was never formally published as a standalone
specification document.  This reconstruction was performed through
systematic binary analysis of the production driver DLL:

     File:         RIPSCRIP.DLL  (592,896 bytes)
     Format:       32-bit Windows PE (i386)
     Build Date:   October 16, 1997
     Build Path:   C:\src\rip3\dll32\
     Method:       Export table enumeration (153 exports)
                   String table extraction (180+ function names)
                   Error message cross-referencing
                   Disassembly of selected entry points

Every command, subsystem, callback, and data structure documented
herein has been verified against concrete evidence in the binary
and cross-referenced against the v2.0 specification (Revision 2.A4,
26,713 lines) and the RIPtermJS reference implementation.

This document follows the formatting conventions established in the
v1.54 and v2.00 specifications, including the command reference
layout (Function, Level, Command, Arguments, Format, Example, and
the Uses Draw Color / Uses Line Pattern / etc. attribute table).


HOW TO USE THIS DOCUMENT
-------------------------

This is a SUPPLEMENT to the published specifications, not a
standalone reference.  It should be read alongside:

     1.  "RIPscrip Graphics Protocol Specification, Revision 1.54"
         (TeleGrafix Communications, July 1993)
         — Defines the v1.54 command set (Level 0 and Level 1),
           MegaNum encoding, frame format, ANSI auto-sensing, and
           all original drawing, text, palette, mouse, button,
           and icon commands.

     2.  "RIPscrip Graphics Protocol Specification, Revision 2.A4"
         (TeleGrafix Communications, approximately 1995-1996)
         — Defines the v2.0 command set including Drawing Ports,
           Data Tables (port/palette/style/button/text window/
           environment tables), coordinate systems, world frames,
           base-math variations, color palettes, extended fonts,
           rounded rectangles, poly-Bezier curves, groups, headers,
           and all Level 2 switch/port commands.

     3.  THIS DOCUMENT (v3.0 Reconstructed Supplement)
         — Documents v3.0-specific features not in the v2.A4 spec:
           multimedia (audio, web URLs, encoded streams), the
           complete host callback interface (60+ callbacks), the
           RAF archive format, image format support (JPEG, GIF),
           the MicroANSI font system, the 5-type font architecture,
           source module map, DLL architecture, and three spec
           errata discovered during analysis.
         — Resolves all v2.A4 command parameters against the
           production DLL binary, confirming command letters and
           parameter formats.
         — Provides a gap analysis for hardware implementers.

For BBS implementers:  If your goal is to make a BBS that speaks
full v3.0 RIPscrip to RIPtel, you need all three documents.  The
v1.54 spec gives you the foundation (95% of what BBSes actually
use).  The v2.A4 spec gives you ports, extended fonts, and the
environment system.  This supplement gives you the v3.0 callback
contract, multimedia commands, and the three errata you must work
around.

For terminal implementers:  This supplement's callback interface
section tells you exactly what the DLL expects from a host
application.  If you are embedding the DLL, implement these
callbacks.  If you are writing your own renderer (as this project does), the command reference sections tell you what each
command does and what parameters it takes.


NOTE:  The original TeleGrafix developers (Jeff and Mark Hayton)
have publicly stated their intent to release the complete RIPscrip
source code (RIPaint, RIPterm, RIPtel, and the driver DLL) under
an open-source license via the TeleGrafix GitHub organization.
This announcement was made in the "RIPScrip Art Resurrection"
community on Facebook in June 2025.  When the source is released,
this reconstructed supplement should be validated against the actual
code and updated accordingly.

For more information on the original TeleGrafix products, contact:

     TeleGrafix Communications, Inc.  (historical)
     111 Weems Lane, Suite 308
     Winchester, VA  22601-3600

     VOICE: (540) 678-4050
     WWW:   http://www.telegrafix.com




=====================================================================
==                    REVISION HISTORY NOTATION                    ==
=====================================================================

This document uses the same revision notation established in the      > v3.0
v1.54 specification.  Sections specific to v3.0 features are marked   > v3.0
with "> v3.0" in the right margin.  Sections that describe features   > v3.0
present in v2.0 but not in v1.54 are marked with "> v2.0".           > v3.0

Where a feature's exact version of introduction cannot be determined   > v3.0
from the binary alone (i.e., it could be v2.0 or v3.0), it is        > v3.0
marked as "> v2.0+" to indicate uncertainty.                          > v3.0

The v2.00 specification went through multiple alpha revisions:        > v3.0

     Revision 2.A0   Initial v2.0 draft                              > v3.0
     Revision 2.A1   Drawing ports, data tables                      > v3.0
     Revision 2.A2   Coordinate systems, viewports                   > v3.0
     Revision 2.A3   Port commands, rounded rect, palette switch      > v3.0
     Revision 2.A4   Environment system, protection model             > v3.0

The v3.0 driver (RIPSCRIP030001) incorporates all v2.Ax features      > v3.0
plus additional multimedia, web integration, and font system          > v3.0
extensions documented in this supplement.                             > v3.0




=====================================================================
==                       DRIVER ARCHITECTURE                       ==
=====================================================================

The v3.0 RIPscrip driver implements a multi-instance rendering        > v3.0
engine with strict object lifecycle management.  This architecture    > v3.0
differs substantially from the v1.54 model, which assumed a single   > v3.0
rendering context per application.  The v3.0 model supports          > v3.0
multiple simultaneous RIPscrip sessions (e.g., multiple telnet       > v3.0
connections in a tabbed terminal), each with independent state.       > v3.0

The object hierarchy is as follows:                                   > v3.0

     RIP_EngineCreate()                                               > v3.0
       Creates the global engine object.  There is exactly one        > v3.0
       engine per process.  The engine owns shared resources:         > v3.0
       font data, default palette tables, the BGI stroke font        > v3.0
       cache, and the MicroANSI font file (RIPSCRIP.MAF).            > v3.0
                                                                      > v3.0
     RIP_EngineInit()                                                 > v3.0
       Initializes all engine subsystems.  Must be called exactly     > v3.0
       once after RIP_EngineCreate() and before any instance          > v3.0
       operations.                                                    > v3.0
                                                                      > v3.0
     RIP_InstanceCreate()                                             > v3.0
       Creates a per-connection session instance.  Each instance      > v3.0
       owns its own drawing state, port table, color palette,         > v3.0
       mouse field table, text window table, button style table,      > v3.0
       and environment table.  Instances are independent: drawing     > v3.0
       operations in one instance do not affect any other.            > v3.0
                                                                      > v3.0
     RIP_InstanceInit()  /  RIP_InstanceInitEx()                      > v3.0
       Initializes instance state.  The "Ex" variant accepts          > v3.0
       extended initialization parameters.                            > v3.0
                                                                      > v3.0
     RIP_StreamCreate()                                               > v3.0
       Creates a data stream parser attached to an instance.          > v3.0
       The stream is the actual byte-by-byte RIPscrip command         > v3.0
       processor.  Multiple streams may exist per instance (e.g.,     > v3.0
       one for the network connection, one for local .RIP file        > v3.0
       playback).                                                     > v3.0
                                                                      > v3.0
     RIP_ProcessBuffer(instance, data, length)                        > v3.0
       The primary entry point for feeding raw data to the parser.    > v3.0
       Processes 'length' bytes from 'data' through the RIPscrip     > v3.0
       command interpreter.  Text that is not part of a RIPscrip     > v3.0
       command is routed to the ANSI/VT-102 terminal emulator.       > v3.0
                                                                      > v3.0
     RIP_ProcessFile(instance, filename)                              > v3.0
       Loads and processes an entire .RIP file.  Equivalent to        > v3.0
       reading the file into a buffer and calling                     > v3.0
       RIP_ProcessBuffer() on the contents.                           > v3.0
                                                                      > v3.0
     RIP_PlaybackLocalRIPFile(instance, filename)                     > v3.0
       Plays back a locally stored .RIP file with timing delays       > v3.0
       to simulate real-time transmission.                            > v3.0

The driver validates all object handles using a magic number           > v3.0
(0x9DF3, observed at the beginning of every instance struct).  If     > v3.0
an invalid handle is passed to any API function, the driver           > v3.0
displays a MessageBox error and returns a failure code.  This         > v3.0
magic-number validation is performed via the helper functions:        > v3.0

     RIP_ObjectIsEngine(handle)                                       > v3.0
     RIP_ObjectIsInstance(handle)                                     > v3.0
     RIP_ObjectIsStream(handle)                                       > v3.0


Source Modules
--------------

The following source file paths were recovered from embedded error     > v3.0
strings in the production DLL.  They reveal the internal code          > v3.0
organization of the v3.0 driver:                                      > v3.0

     Module                          Responsibility                   > v3.0
     ────────────────────────────    ─────────────────────────────    > v3.0
     riprocmd.cpp                    Main RIPscrip command dispatch.  > v3.0
                                     Contains handlers for:           > v3.0
                                       RIP_BackColor()                > v3.0
                                       RIP_OneDrawingPalette()        > v3.0
                                       RIP_PortCopy()                 > v3.0
                                       RIP_PortDelete()               > v3.0
                                       RIP_SwitchEnvironment()        > v3.0
                                       RIP_SwitchPalette()            > v3.0
                                       rip_query()                    > v3.0
                                                                      > v3.0
     r_ports.cpp                     Port management and lifecycle.   > v3.0
                                     Port definition, deletion,       > v3.0
                                     protection, and coordinate       > v3.0
                                     mapping.                         > v3.0
                                                                      > v3.0
     r_prtcpy.cpp                    Port copy and compositing.       > v3.0
                                     Handles rectangle scaling and    > v3.0
                                     viewport clipping during         > v3.0
                                     inter-port transfers.            > v3.0
                                                                      > v3.0
     Images\DibShow.cpp              DIB (Device-Independent Bitmap)  > v3.0
                                     rendering engine.  Supports      > v3.0
                                     mask bitmaps, 24-bit merge,      > v3.0
                                     palette activation, stretch.     > v3.0
                                                                      > v3.0
     FileMgmt\UnRAF.cpp              RAF archive decompression.       > v3.0
                                                                      > v3.0
     ripraf\Rafbloat.cpp             RAF bloat/padding handler.       > v3.0
     ripraf\Rafhdr.cpp               RAF header parser.               > v3.0
     ripraf\Rafndxck.cpp             RAF index integrity checker.     > v3.0
     ripraf\Rafndxrd.cpp             RAF index reader/navigator.      > v3.0
     ripraf\Rafopen.cpp              RAF archive file opener.         > v3.0
                                                                      > v3.0
     telegrfx\Diblib\Dibfread.cpp    DIB file reader (BMP format).   > v3.0





=====================================================================
==              DRAWING PORTS - THE v2.0 RENDERING MODEL            ==
=====================================================================

The most significant architectural change between RIPscrip v1.54      > v2.0
and v2.0 is the introduction of "Drawing Ports."  In v1.54, all      > v2.0
graphical operations occurred on a single, shared screen surface.     > v2.0
There was one viewport, one palette, one set of drawing attributes,   > v2.0
and one mouse field table.  This single-surface model was adequate    > v2.0
for simple BBS menu screens, but it severely limited the ability to   > v2.0
create complex, multi-pane user interfaces.                           > v2.0

In v2.0, the rendering surface is no longer monolithic.  Instead,     > v2.0
the driver manages a table of independent "Drawing Ports," each of    > v2.0
which has its own coordinate space, viewport, palette assignment,     > v2.0
and clipping region.  This is conceptually identical to the           > v2.0
"GrafPort" abstraction used in Apple's QuickDraw, or the "Device      > v2.0
Context" (DC) concept in the Windows GDI.  The key difference is      > v2.0
that RIPscrip ports are lightweight and designed for low-bandwidth    > v2.0
transmission -- the host defines ports with simple RIPscrip           > v2.0
commands, not through a heavyweight API.                              > v2.0


What Is a Port?                                                       > v2.0
---------------                                                       > v2.0

A port is a rectangular region of the screen (or an offscreen         > v2.0
buffer) with the following properties:                                > v2.0

     1.  A defined rectangle on the screen (x0, y0, x1, y1).         > v2.0
     2.  Its own coordinate system.  The upper-left corner of the     > v2.0
         port is always (0, 0) in the port's local coordinates,      > v2.0
         regardless of where the port appears on the screen.          > v2.0
     3.  A viewport (clipping region) within the port.  By default,  > v2.0
         the viewport is the full size of the port.  It can be        > v2.0
         narrowed to create a "window within a window" effect.        > v2.0
     4.  An association with a color palette slot.                    > v2.0
     5.  An association with a graphical style slot (line style,      > v2.0
         fill pattern, write mode, font, etc.).                       > v2.0
     6.  A protection flag.  When a port is protected, it cannot      > v2.0
         be redefined or deleted by subsequent RIPscrip commands.     > v2.0
         This allows BBS system operators to lock down the system     > v2.0
         chrome (title bars, status bars, menu frames) while          > v2.0
         allowing user content to render in unprotected ports.        > v2.0

The v3.0 driver confirms the following port-related functions          > v3.0
through exported API names and internal error strings:                > v3.0


Port Functions                                                        > v3.0
--------------                                                        > v3.0

     RIP_PortDefine()                                                 > v2.0
     ────────────────────────────────────────────────────────────     > v2.0
     Define a new drawing port.  Creates an entry in the Drawing      > v2.0
     Port Table.  The host specifies the screen coordinates, the      > v2.0
     initial viewport rectangle, and optional flags (protection,      > v2.0
     offscreen vs. onscreen).  Offscreen ports ("Clipboard Ports")    > v2.0
     are not visible on the display but can be used as intermediate   > v2.0
     buffers for compositing operations.                              > v2.0

     Error strings observed:                                          > v3.0
       "Port Initialization Failed!"                                  > v3.0
       "Insufficient memory for graphics ports"                       > v3.0
       "Insufficient memory for port Bitmap structure"                > v3.0
       "Port number is out of Range!"                                 > v3.0


     RIP_PortCopy()                                                   > v2.0
     ────────────────────────────────────────────────────────────     > v2.0
     Copy a rectangular region of graphics data from one port to      > v2.0
     another.  This is the primary compositing operation.  The        > v2.0
     source and destination rectangles do not need to be the same     > v2.0
     size -- if they differ, scaling is performed.  Both the source   > v2.0
     and destination rectangles are clipped to their respective       > v2.0
     port viewports.                                                  > v2.0

     Source file: r_prtcpy.cpp                                        > v3.0
     Also referenced: riprocmd.cpp                                    > v3.0

     Error strings observed:                                          > v3.0
       "Source rectangle is invalid!"                                 > v3.0
       "Destination rectangle is invalid!"                            > v3.0
       "The source entry isn't in use - can't perform the copy"       > v3.0


     RIP_PortWrite()                                                  > v2.0
     ────────────────────────────────────────────────────────────     > v2.0
     Direct data write to a specific port.  This allows the host      > v2.0
     to target rendering operations at a particular port without      > v2.0
     using RIP_SwitchPort() to change the global active port.         > v2.0
     Useful for "fire and forget" operations on background ports      > v2.0
     (e.g., updating a status bar while the main content port         > v2.0
     remains active).                                                 > v2.0


     RIP_SwitchPort()                                                 > v2.0
     ────────────────────────────────────────────────────────────     > v2.0
     Switch the active drawing port.  All subsequent graphical        > v2.0
     operations (lines, circles, fills, text, etc.) will render       > v2.0
     into the newly selected port until another RIP_SwitchPort()      > v2.0
     is issued.  The coordinate system immediately changes to the     > v2.0
     selected port's local coordinates.                               > v2.0


     portDelete()                                                     > v3.0
     ────────────────────────────────────────────────────────────     > v3.0
     Delete a port and free its resources.  Referenced in error       > v3.0
     strings: "riprocmd.cpp - RIP_PortDelete()"                      > v3.0

     Error strings observed:                                          > v3.0
       "Port can't be modified - it's protected!"                     > v3.0
       "Protected port can't be redefined!"                           > v3.0
       "Can't alter protection status of port - it doesn't exist"     > v3.0
       "Invalid port number"                                          > v3.0
       "Port parameter is out of range!"                              > v3.0


Port Protection                                                       > v2.0
---------------                                                       > v2.0

The protection model is a critical feature for BBS system design.     > v2.0
When a sysop creates a menu screen, certain regions (the title bar,   > v2.0
navigation buttons, system status area) must not be overwritten by    > v2.0
user-generated content or downloadable RIPscrip scenes.  By marking   > v2.0
these ports as "protected," the sysop guarantees that only the        > v2.0
host system software can modify them.  Any attempt to redefine,       > v2.0
delete, or write to a protected port will fail with an error.         > v2.0

The protection concept extends beyond ports to all v2.0 data          > v2.0
tables.  The following objects support protection:                     > v2.0

     Drawing Ports           "Port can't be modified - it's           > v2.0
                              protected!"                             > v2.0
     Color Palettes          "Can't modify current color palette -    > v2.0
                              its protected!"                         > v2.0
     Graphical Styles        "Can't modify current graphics style -   > v2.0
                              its protected!"                         > v2.0
     Text Windows            "Can't modify text window - its          > v2.0
                              protected"                              > v2.0
     Button Styles           "Can't modify button style - it's        > v2.0
                              protected"                              > v2.0
     Environments            "Can't modify current environment -      > v2.0
                              its protected!"                         > v2.0
     Color Tables             "Can't reset a color table that is      > v2.0
                              protected"                              > v2.0
                              "Can't alter the protection status of   > v2.0
                              color table 0"                          > v2.0



=====================================================================
==                      COORDINATE SYSTEM                          ==
=====================================================================

In RIPscrip v1.54, the coordinate system was hardcoded to the EGA     > v2.0
display resolution of 640 x 350 pixels.  All coordinates in every     > v2.0
RIPscrip command were expressed in this fixed coordinate space.        > v2.0
This was adequate when all RIPscrip terminals were running on EGA     > v2.0
or VGA displays in EGA-compatible mode, but it became a limitation    > v2.0
as terminals moved to higher resolutions and non-PC platforms.         > v2.0

RIPscrip v2.0 introduces a fully configurable coordinate system       > v2.0
that decouples the logical drawing space from the physical display    > v2.0
resolution.  This is accomplished through three new commands:         > v2.0


RIP_SET_COORDINATE_SIZE                                               > v2.0
---------------------------------------------------------------------
         Function:  Set the logical coordinate space dimensions
            Level:  0
          Command:  n
        Arguments:  byte_size:1, reserved:3
           Format:  !|n <byte_size> <reserved>
          Example:  !|n2000
  Uses Draw Color:  NO
Uses Line Pattern:  NO
  Uses Line Thick:  NO
  Uses Fill Color:  NO
Uses Fill Pattern:  NO
  Uses Write Mode:  NO
  Uses Font Sizes:  NO
    Uses Viewport:  NO

The byte_size parameter (1-digit MegaNum, range 2-5) sets the          > v2.0
number of MegaNum digits used for all subsequent X and Y coordinate   > v2.0
parameters.  The default is 2 (values 0-1295).  Setting byte_size     > v2.0
to 4 allows coordinates up to 1,679,615, enabling virtual             > v2.0
coordinate spaces far larger than the physical display.  Invalid      > v2.0
values are clamped to 2.  The reserved field (3 digits) must be       > v2.0
set to "000".                                                         > v2.0

This eliminates the v1.54 hardcoded 640 x 350 coordinate space.       > v2.0
A RIPscrip scene can use any logical coordinate range and the          > v2.0
driver maps it to the physical display resolution automatically.      > v2.0


RIP_SET_WORLD_FRAME                                                   > v2.0
---------------------------------------------------------------------
         Function:  Set world coordinate transform (pan/zoom)
            Level:  0
          Command:  [not in v2.0 TOC — v3.0 addition]
        Arguments:  [unknown — DLL strings: "WORLD", "WORLDW",
                     "WORLDH" suggest x_origin, y_origin, width,
                     height as XY-width parameters]
  Uses Viewport:   NO

This command defines a "world frame" -- an arbitrary rectangular       > v2.0
region of a logical coordinate space that is mapped onto the          > v2.0
current viewport.  This is functionally equivalent to a 2D camera:    > v2.0
the world frame defines what portion of the logical world is          > v2.0
visible, and the viewport defines where it appears on screen.         > v2.0

By changing the world frame parameters, the host can implement        > v2.0
panning (shifting the visible region) and zooming (scaling the        > v2.0
visible region up or down) without reissuing any drawing commands.    > v2.0
This is particularly useful for map displays, CAD-like viewers,       > v2.0
and scrollable content areas.                                         > v2.0


RIP_SET_BASE_MATH                                                     > v2.0
---------------------------------------------------------------------
         Function:  Set numerical parameter encoding format
            Level:  0
          Command:  b
        Arguments:  base_math:2
           Format:  !|b <base_math>
          Example:  !|b1S

This command switches the base encoding used for all subsequent       > v2.0
numeric parameters.  The base_math parameter is ALWAYS encoded in     > v2.0
base-36 MegaNum format regardless of the current setting:             > v2.0

     Value "10" (MegaNum for 36) = Base-36 MegaNums (default)        > v2.0
     Value "1S" (MegaNum for 64) = Base-64 UltraNums                 > v2.0

UltraNums use characters 0-9, A-Z, a-z, and two additional            > v2.0
symbols, providing ~77% more numeric range per digit than              > v2.0
MegaNums.  This is particularly useful for coordinate parameters      > v2.0
and color values where 2-digit MegaNum range (0-1295) is              > v2.0
insufficient.                                                         > v2.0

NOTE:  Command letter 'b' is shared with RIP_EXTENDED_TEXT_WINDOW     > v2.0
(added in v2.A4).  The parser disambiguates by argument length:       > v2.0
RIP_SET_BASE_MATH always has exactly 2 characters after 'b';          > v2.0
RIP_EXTENDED_TEXT_WINDOW has many more.                                > v2.0



=====================================================================
==                         COLOR SYSTEM                            ==
=====================================================================

RIPscrip v1.54 supported a 16-color palette derived from the EGA      > v2.0
color model.  The 16 colors were mapped to a 64-color "master         > v2.0
palette" via the RIP_SET_PALETTE and RIP_ONE_PALETTE commands.         > v2.0
This was sufficient for EGA-class displays but inadequate for VGA      > v2.0
(256 colors) and SVGA (16-bit/24-bit color) displays.                 > v2.0

The v2.0/v3.0 driver substantially extends the color system:          > v2.0


RIP_SET_COLOR_MODE                                                    > v2.0
---------------------------------------------------------------------
         Function:  Set color depth and palette mode
            Level:  0
          Command:  M
        Arguments:  mode:1, bits:1
           Format:  !|M <mode> <bits>
          Example:  !|M18
  Uses Viewport:   NO

The mode parameter (1-digit MegaNum) selects the color model:          > v2.0

     Mode 0:  Color Mapping mode (default).  Color parameters are     > v2.0
              palette indices mapped through the color table.          > v2.0
     Mode 1:  Direct RGB mode.  Color parameters become 4-digit       > v2.0
              UltraNums encoding R/G/B values directly, regardless    > v2.0
              of the global base-math setting.                        > v2.0

The bits parameter (1-digit MegaNum) specifies the number of bits     > v2.0
per R/G/B component in Direct RGB mode (ignored in mapping mode).     > v2.0
A value of 8 gives 24-bit color (16.7 million colors).               > v2.0

The v2.0 specification (Section 2.7) discusses color palettes and      > v2.0
hardware in detail, including a "Drawing Palette" concept and          > v2.0
"Palette Mapping and Direct RGB Mode."  The Direct RGB mode allows     > v2.0
RIPscrip commands to specify colors as actual RGB values rather        > v2.0
than palette indices.                                                  > v2.0

Error strings observed:                                               > v3.0
  "RGB Color value is out of range!"                                  > v3.0
  "Invalid Color Value!"                                              > v3.0
  "Invalid Color Value"                                               > v3.0
  "Invalid Drawing Color"                                             > v3.0
  "Specified color is out of color range"                             > v3.0
  "Color palette index out of range"                                  > v3.0


RIP_BACK_COLOR                                                        > v2.0
---------------------------------------------------------------------
         Function:  Set the background drawing color
            Level:  0
          Command:  [identified from v2.0 spec TOC entry 3.4.1.2]
        Arguments:  color:2
           Format:  !|<cmd> <color>
  Uses Draw Color:  N/A (this command SETS the background color)
Uses Line Pattern:  NO
  Uses Line Thick:  NO
  Uses Fill Color:  NO
Uses Fill Pattern:  NO
  Uses Write Mode:  NO
  Uses Font Sizes:  NO
    Uses Viewport:  NO

In v1.54, only a single "drawing color" existed (set via               > v2.0
RIP_COLOR).  All primitives drew in this color.  The background        > v2.0
was implicitly color 0 (black) or the fill color for filled           > v2.0
shapes.                                                                > v2.0

In v2.0, a separate background drawing color is introduced.  This     > v2.0
affects text rendering (character background), erased regions, and     > v2.0
any operation that requires a "secondary" color.  The background      > v2.0
color is independent of the fill color set by RIP_FILL_STYLE.         > v2.0


Dual Palette System                                                   > v2.0
--------------------                                                  > v2.0

The v2.0/v3.0 driver introduces a "Drawing Palette" that is           > v2.0
separate from the display palette:                                    > v2.0

     RIP_OneDrawingPalette()                                          > v2.0
       Set a single entry in the drawing palette.                     > v2.0
       Source: riprocmd.cpp                                           > v3.0

     RIP_SetDrawingPalette()                                          > v2.0
       Set the entire drawing palette at once.                        > v2.0

The drawing palette controls how color indices specified in            > v2.0
RIPscrip drawing commands are mapped to actual display colors.         > v2.0
This two-stage color pipeline (drawing palette → display palette →     > v2.0
hardware) allows the host to perform color remapping without           > v2.0
redrawing any content.  For example, a BBS could implement a "dark    > v2.0
mode" by remapping the drawing palette's bright colors to darker      > v2.0
equivalents, instantly changing the appearance of the entire           > v2.0
screen without retransmitting any RIPscrip commands.                  > v2.0

Palette Protection:                                                   > v2.0
  "Can't modify current color palette - its protected!"               > v2.0
  "Can't reset a color table that is protected"                       > v2.0
  "Can't alter the protection status of color table 0"               > v2.0

The last error is notable: color table 0 (the default/system          > v2.0
palette) has permanent protection and cannot be altered.  This        > v2.0
ensures that the base 16-color EGA palette is always available as     > v2.0
a fallback.                                                           > v2.0


Color system initialization:                                          > v3.0
  ripInitColorSystem()  —  Internal function that initializes all     > v3.0
  color tables, loads default palettes, and configures the display    > v3.0
  hardware for the current color mode.                                > v3.0





=====================================================================
==                          FONT SYSTEM                            ==
=====================================================================

The v1.54 font system was limited to a single category: Borland       > v2.0
BGI (Borland Graphics Interface) stroke fonts.  These are vector      > v2.0
outline fonts rendered by decomposing each glyph into a series of     > v2.0
line segments.  The v1.54 specification defined 11 font slots          > v2.0
(fonts 0 through 10), where font 0 was the default 8x8 bitmapped     > v2.0
system font and fonts 1 through 10 were BGI stroke fonts loaded       > v2.0
from .CHR files.                                                      > v2.0

The v2.0/v3.0 driver dramatically expands the font system to          > v2.0
support five distinct font types, each with its own rendering         > v2.0
pipeline.  The expanded system is managed through the following       > v2.0
functions:                                                            > v2.0


     RIP_FontStyle()                                                  > v1.54
     ────────────────────────────────────────────────────────────
     The original v1.54 font selection command.  Selects one of
     the 11 BGI font slots and sets the font direction (horizontal
     or vertical) and size multiplier.  This command remains fully
     supported in v2.0/v3.0 for backward compatibility.

     Arguments:  font:2, direction:2, size:2, reserved:2
     Format:     !|Y <font> <direction> <size> <reserved>

     Font 0 selects the default 8x8 bitmapped font.  Fonts 1-10
     select BGI stroke fonts.  See the v1.54 specification for
     the complete font table.


     RIP_ExtendedFontStyle()                                          > v2.0
     ────────────────────────────────────────────────────────────     > v2.0
     The v2.0 extended font selection command.  Provides access to    > v2.0
     all five font types supported by the driver, with additional     > v2.0
     parameters for font attributes (bold, italic, underline,         > v2.0
     shadow) and precise sizing.                                      > v2.0

     The v2.0 specification (Section 3.4.1.11) documents this         > v2.0
     command across three full pages, indicating it is one of the     > v2.0
     most complex commands in the v2.0 protocol.                      > v2.0

     Error strings observed:                                          > v3.0
       "Font attributes not supported for system fonts"               > v3.0
       "Invalid font attributes"                                      > v3.0
       "Cannot get font information for RIPscrip font"               > v3.0
       "Font number is out of range"                                  > v3.0
       "Illegal font number"                                          > v3.0
       "Font size cannot be 0"                                        > v3.0
       "Illegal font size"                                            > v3.0
       "Invalid Font Direction Parameter"                             > v3.0
       "Invalid Font Number"                                          > v3.0
       "Invalid Font Size Parameter"                                  > v3.0


     RIP_FontAttrib()                                                 > v2.0
     ────────────────────────────────────────────────────────────     > v2.0
     Set font rendering attributes independently of font              > v2.0
     selection.  This allows the host to toggle bold, italic,         > v2.0
     underline, or shadow rendering without reissuing the full        > v2.0
     RIP_ExtendedFontStyle() command.                                 > v2.0

     Error strings observed:                                          > v3.0
       "Font attributes not supported for system fonts"               > v3.0
       "Invalid font attributes"                                      > v3.0

     NOTE:  Font attributes (bold, italic, etc.) are only supported   > v3.0
     for RFF raster fonts and TrueType system fonts.  BGI stroke      > v3.0
     fonts do not support attributes -- they render only in their     > v3.0
     native weight and style.  Attempting to set attributes on a      > v3.0
     stroke font will produce the "not supported" error.              > v3.0


     RIP_TextMetric()                                                 > v2.0+
     ────────────────────────────────────────────────────────────     > v2.0+
     Query the metrics (dimensions) of the currently selected font    > v2.0+
     at the current size.  Returns width, height, ascent, and         > v2.0+
     descent information.  This is essential for proportional fonts   > v2.0+
     where the host must compute text layout before rendering.        > v2.0+

     Error strings observed:                                          > v3.0
       "RIP_GetFontDimensions() Error"                                > v3.0
       "Invalid text metric domain"                                   > v3.0
       "Invalid text metric mode"                                     > v3.0
       "Height of font is zero"                                       > v3.0
       "Width of font is zero"                                        > v3.0


Font Types                                                            > v2.0
----------                                                            > v2.0

The v3.0 driver supports five distinct font rendering pipelines.      > v3.0
Evidence for each type is drawn from the string table, error          > v3.0
messages, and the font files distributed with RIPtel 3.1.             > v3.0


TYPE 1:  BGI Stroke Fonts (.CHR files)                                > v1.54
----------------------------------------------

These are the original v1.54 font type.  Each glyph is defined as     > v1.54
a series of vector strokes (line segments).  The font data begins     > v1.54
with the header "PK..BGI Stroked Font V1.1" followed by character     > v1.54
width tables and stroke data.                                         > v1.54

The following .CHR files are distributed with RIPtel 3.1:             > v3.0

     File            Font Name            Size (bytes)               > v3.0
     ────────────    ─────────────────    ────────────               > v3.0
     BOLD.CHR        Bold                 14,670                     > v3.0
     EURO.CHR        European              8,439                     > v3.0
     GOTH.CHR        Gothic               18,063                     > v3.0
     LCOM.CHR        Complex              12,079                     > v3.0
     LITT.CHR        Small                 5,151                     > v3.0
     SANS.CHR        Sans Serif           13,596                     > v3.0
     SCRI.CHR        Script               10,987                     > v3.0
     SIMP.CHR        Simplex               8,437                     > v3.0
     TRIP.CHR        Triplex              16,677                     > v3.0
     TSCR.CHR        Triplex Script       17,355                     > v3.0
     DEFAULT.CHR     Default              [referenced in strings]    > v3.0
                                          ─────────────
                                          Total: ~125 KB             > v3.0

The font search path is set by the host application via the           > v3.0
ripSetFontDir callback.  The driver constructs the full path as       > v3.0
"%s\FONTS\%s" (observed format string in the DLL).                    > v3.0

Error strings observed:                                               > v3.0
  "Can't find BGI data for BGI font %s"                              > v3.0
  "Can't find BGI stroke data"                                       > v3.0
  "Can't find all of the BGI font files"                             > v3.0
  "Unknown BGI font buffer size"                                     > v3.0
  "Insufficient memory for BGI font system"                          > v3.0
  "Stroke pen is too large"                                          > v3.0
  "Vector Font Error!"                                                > v3.0
  "Failed to load vector font"                                       > v3.0

Internal function:  bgiSetFontStyle(hRip, ...)                        > v3.0

Rendering:  Each glyph's stroke data is decomposed into a series      > v1.54
of line segments drawn with the current drawing color.  The font      > v1.54
size parameter scales the strokes proportionally.  Direction 0        > v1.54
draws horizontally (left to right); direction 1 draws vertically      > v1.54
(bottom to top).                                                      > v1.54

Internal function for extended rendering:                             > v3.0
  ripPlaceVectorFontStringExtended()                                  > v3.0
This function adds support for scaling, rotation, and kerning         > v3.0
adjustments beyond the basic v1.54 size multiplier.                   > v3.0


TYPE 2:  RFF Raster Fonts (.RFF files)                                > v2.0
----------------------------------------------                       > v2.0

A new font format introduced in v2.0.  RFF (RIPscrip Font File)      > v2.0
is a proprietary TeleGrafix bitmap font format.  Unlike BGI stroke    > v2.0
fonts which are vector-based, RFF fonts are pre-rendered bitmap       > v2.0
glyphs at specific sizes.  This provides higher visual quality         > v2.0
for body text at the cost of fixed sizing (or integer scaling).       > v2.0

The following .RFF files are distributed with RIPtel 3.1:             > v3.0

     File            Font Name            Size (bytes)               > v3.0
     ────────────    ─────────────────    ────────────               > v3.0
     BRUSH.RFF       Brush (handwritten)  87,155                     > v3.0
     COBB.RFF        Cobb (serif)         62,725                     > v3.0
     DEFAULT.RFF     Default (sans)       31,596                     > v3.0
     DIXON.RFF       Dixon (display)      42,071                     > v3.0
     EUREKA.RFF      Eureka (decorative)  70,789                     > v3.0
     MARIN.RFF       Marin (modern)       56,526                     > v3.0
     OAKLAND.RFF     Oakland (geometric)  64,213                     > v3.0
     SYMBOL.RFF      Symbol (special)     43,601                     > v3.0
                                          ─────────────
                                          Total: ~459 KB             > v3.0

The RFF format is proprietary and its internal structure could         > v3.0
not be fully reconstructed from string analysis alone.  When the      > v3.0
TeleGrafix source code is released, the RFF parser should be          > v3.0
documented in detail.                                                 > v3.0

RFF fonts support the RIP_FontAttrib() attributes (bold, italic,      > v2.0
underline, shadow) that BGI stroke fonts do not.                      > v2.0


TYPE 3:  MicroANSI Fonts (RIPSCRIP.MAF)                              > v2.0
----------------------------------------------                       > v2.0

The MicroANSI Font system is a container format that stores           > v2.0
multiple bitmap font faces in a single file.  The file header         > v2.0
identifies itself as:                                                 > v2.0

     "RIPterm v2.0 MicroANSI Font File"                              > v2.0

These fonts are specifically designed for rendering ANSI terminal     > v2.0
text within RIPscrip sessions.  The ANSI text window uses             > v2.0
MicroANSI fonts for character rendering, providing higher quality     > v2.0
than the default 8x8 system font for text-heavy displays.            > v2.0

Error strings observed:                                               > v3.0
  "ANSI font isn't complete in file RIPSCRIP.MAF"                    > v3.0
  "Can't find designated font in file RIPSCRIP.MAF"                  > v3.0
  "Can't find font frame in file RIPSCRIP.MAF"                      > v3.0
  "Can't open read font header from file RIPSCRIP.MAF"              > v3.0
  "Can't read font bitmap data from file RIPSCRIP.MAF"              > v3.0
  "Can't read font frame from file RIPSCRIP.MAF"                    > v3.0
  "Can't read font from file RIPSCRIP.MAF"                          > v3.0
  "Font file RIPSCRIP.MAF is blank"                                  > v3.0
  "Insufficient memory for MicroANSI font entry in file              > v3.0
   RIPSCRIP.MAF"                                                      > v3.0
  "Invalid ANSI font cell size in file RIPSCRIP.MAF"                > v3.0
  "Invalid font file RIPSCRIP.MAF"                                   > v3.0
  "MicroANSI font failure"                                           > v3.0
  "Unable to Set MicroANSI font bits"                                > v3.0
  "ANSI Font has not been initialized"                               > v3.0
  "Can't load ANSI font"                                             > v3.0

From these error strings we can infer the MAF internal structure:     > v3.0

     1.  A file header identifying the format and version.            > v3.0
     2.  One or more "font frame" entries, each containing:           > v3.0
         a.  A font cell size (width × height in pixels).            > v3.0
         b.  Bitmap data for all glyphs at that cell size.           > v3.0
     3.  A directory/index structure for locating specific fonts.     > v3.0

The MAF file is loaded once at engine initialization and cached        > v3.0
in memory for the duration of the session.                            > v3.0

Related callbacks:                                                    > v3.0
  ripCacheAnsiFonts   — Controls whether ANSI fonts are pre-cached   > v3.0
  ripDefaultAnsiFont  — Selects the default ANSI font variant        > v3.0


TYPE 4:  System TrueType Fonts (RIPSCRIP.TTF)                        > v2.0
----------------------------------------------                       > v2.0

The v2.0 specification mentions support for "high quality outline     > v2.0
fonts like TrueType(tm)" (Section 1.4.4, Revision 2.A1).  The       > v2.0
v3.0 driver confirms this via Windows API imports:                    > v2.0

     CreateFontA       — Windows GDI font creation                   > v3.0

And the error string:                                                 > v3.0
  "Cannot load RIPscrip true-type font RIPSCRIP.TTF"                > v3.0

The driver attempts to load a TrueType font file named                > v3.0
RIPSCRIP.TTF from the font directory.  This file is NOT distributed   > v3.0
with the RIPtel 3.1 freeware release, suggesting it was either       > v3.0
part of a commercial/registered version or was planned but not        > v3.0
completed.                                                            > v3.0

NOTE:  This font type is inherently platform-specific (it relies      > v3.0
on the Windows font rasterizer).  For cross-platform implementations  > v3.0
in a portable software renderer, the TrueType path should be replaced     > v3.0
with a bitmap equivalent or a lightweight rasterizer.                 > v3.0

Additional error strings related to outline font support:             > v3.0
  "Can't initialize outline font engine"                             > v3.0
  "Cannot initialize outline font engine"                            > v3.0
  "Can't make master list of outline fonts"                          > v3.0
  "Couldnt install outline fonts"                                    > v3.0
  "Couldnt load specified font"                                      > v3.0
  "No outline font files found"                                      > v3.0
  "No outline font object to initialize"                             > v3.0
  "Insufficient memory for outline font engine"                      > v3.0


TYPE 5:  ANSI Font Cache                                              > v3.0
----------------------------------------------                       > v3.0

An internal optimization, not directly selectable by RIPscrip         > v3.0
commands.  The driver pre-rasterizes system fonts (TrueType or        > v3.0
MicroANSI) into a bitmap cache for fast rendering of ANSI terminal   > v3.0
text.  This avoids the overhead of calling the Windows font           > v3.0
rasterizer for every character.                                       > v3.0

Error strings observed:                                               > v3.0
  "Insufficient memory for ANSI font cache"                          > v3.0
  "Insufficient memory to create font cache region"                  > v3.0
  "Can't create font cache device context"                           > v3.0
  "Font Cache Error!"                                                > v3.0

The cache is managed transparently by the driver.  Host               > v3.0
applications control caching behavior through the                     > v3.0
ripCacheAnsiFonts callback.                                           > v3.0


Unified Font Dispatcher                                               > v3.0
-----------------------                                               > v3.0

All five font types are accessed through a unified internal           > v3.0
dispatcher function:                                                  > v3.0

     ripRenderFont()                                                  > v3.0

This function examines the currently selected font type and            > v3.0
routes the rendering request to the appropriate pipeline:             > v3.0

     Font 0          →  8x8 bitmap system font (direct blit)         > v3.0
     Fonts 1-10      →  BGI stroke font renderer                     > v3.0
     Extended BGI     →  ripPlaceVectorFontStringExtended()           > v3.0
     RFF raster       →  bitmap blit with optional scaling            > v3.0
     MicroANSI        →  cached bitmap blit                          > v3.0
     TrueType         →  Windows GDI CreateFontA path                > v3.0

Additional font-related errors (general):                             > v3.0
  "Error Getting Font Information"                                   > v3.0
  "Error Realizing Font - 1"                                         > v3.0
  "Error Realizing Font - 2"                                         > v3.0
  "Error allocating font structure"                                  > v3.0
  "Error allocating fontDir memory."                                 > v3.0
  "Error in reading font file"                                       > v3.0
  "Invalid font file"                                                > v3.0
  "Invalid font type"                                                > v3.0
  "Invalid font typeface"                                            > v3.0
  "No font files were found - check your font path"                 > v3.0
  "Not enough memory for Font"                                       > v3.0
  "Too Many Fonts"                                                    > v3.0
  "Unable to allocate memory for font files"                         > v3.0
  "Unable to create Font Bitmap"                                     > v3.0
  "Unable to create Font Brush"                                      > v3.0
  "Unable to create Font Shadow Brush"                               > v3.0
  "Unable to find font files"                                        > v3.0
  "Unable to get font files"                                         > v3.0
  "Unable to load/find fonts"                                        > v3.0
  "Unable to read font file information"                             > v3.0
  "Cannot created bounded text with old-style system fonts"          > v3.0
  "Font already locked"                                              > v3.0
  "Font not locked"                                                  > v3.0
  "Cannot lock font"                                                  > v3.0

The "locked" / "not locked" pattern suggests a reference-counting     > v3.0
or mutex scheme for font resources that are shared across multiple    > v3.0
instances.                                                            > v3.0



=====================================================================
==              LEVEL 0 NEW COMMANDS (v2.0/v3.0)                   ==
=====================================================================

The following Level 0 commands are present in the v3.0 driver but     > v2.0
do not appear in the v1.54 specification.  They are listed in the     > v2.0
v2.0 specification's table of contents (Revision 2.A4) and are       > v2.0
confirmed in the driver's string table.                               > v2.0

Where possible, the standard command reference format from the        > v2.0
v1.54 specification is used.  Parameter formats were resolved by      > v2.0
cross-referencing the v2.0 specification (Revision 2.A4, 26,713      > v2.0
lines) and the RIPtermJS JavaScript reference implementation.         > v2.0


---------------------------------------------------------------------
RIP_COMMENT                                                           > v2.0
---------------------------------------------------------------------
         Function:  Embed a non-rendered comment in the data stream
            Level:  0
          Command:  !
        Arguments:  text (free-form string to next | or end of line)
           Format:  !|! <comment text>
          Example:  !|!This is a comment

This command allows the host to embed human-readable comments          > v2.0
in a RIPscrip data stream.  Everything from the '!' to the next       > v2.0
'|' delimiter (or end of line) is consumed by the parser but          > v2.0
produces no visual output.  Can be line-continued with backslash.     > v2.0


---------------------------------------------------------------------
RIP_FILLED_CIRCLE                                                     > v2.0
---------------------------------------------------------------------
         Function:  Draw a filled circle
            Level:  0
          Command:  G
        Arguments:  x_center:XY, y_center:XY, radius:XY
           Format:  !|G <x_center> <y_center> <radius>
          Example:  !|G1E180M
  Uses Draw Color:  NO
Uses Fill Pattern:  YES
  Uses Fill Color:  YES
  Uses Write Mode:  YES                                               > v2.0
    Uses Viewport:  YES

In v1.54, there was no direct command to draw a filled circle.        > v2.0
A circle could only be drawn as an outline (RIP_CIRCLE), and          > v2.0
filling required a separate RIP_FILL (flood fill) command after       > v2.0
the circle was drawn.  This was inefficient and prone to fill          > v2.0
leaks at tangent points.  v2.0 adds this as a direct primitive.       > v2.0


---------------------------------------------------------------------
RIP_FILLED_RECTANGLE                                                  > v2.0
---------------------------------------------------------------------
         Function:  Draw a filled rectangle with optional border
            Level:  0
          Command:  [from v2.0 TOC entry 3.4.1.20]
        Arguments:  x0:2, y0:2, x1:2, y1:2

This is an alias for RIP_BAR (v1.54 command 'B') with extended         > v2.0
write mode support.  In v1.54, RIP_BAR did not honor the write        > v2.0
mode (it always used COPY).  In v2.0, all filled primitives           > v2.0
respect the current write mode, including XOR.                        > v2.0


---------------------------------------------------------------------
RIP_ROUNDED_RECT                                                      > v2.0
---------------------------------------------------------------------
         Function:  Draw a rounded rectangle (outline)
            Level:  0
          Command:  U
        Arguments:  x0:XY, y0:XY, x1:XY, y1:XY, radius:2
           Format:  !|U <x0> <y0> <x1> <y1> <radius>
          Example:  !|U00010A0E09
  Uses Draw Color:  YES
Uses Line Pattern:  YES
  Uses Line Thick:  YES
  Uses Write Mode:  YES
    Uses Viewport:  YES

Draws a rectangle with quarter-circle rounded corners.  The            > v2.0
radius parameter specifies the corner arc radius in pixels.  This     > v2.0
command was added in Revision 2.A3.                                   > v2.0


---------------------------------------------------------------------
RIP_FILLED_ROUNDED_RECT                                               > v2.0
---------------------------------------------------------------------
         Function:  Draw a filled rounded rectangle
            Level:  0
          Command:  u
        Arguments:  x0:XY, y0:XY, x1:XY, y1:XY, radius:2
           Format:  !|u <x0> <y0> <x1> <y1> <radius>
          Example:  !|u00010A0E09
  Uses Fill Color:  YES
Uses Fill Pattern:  YES
  Uses Write Mode:  YES
    Uses Viewport:  YES

The filled variant of RIP_ROUNDED_RECT.  Added in Revision 2.A3.     > v2.0


---------------------------------------------------------------------
RIP_POLY_BEZIER                                                       > v2.0
---------------------------------------------------------------------
         Function:  Draw a poly-Bezier curve (multiple connected
                    cubic Bezier segments)
            Level:  0
          Command:  z
        Arguments:  num:2, count:2, x_base:XY, y_base:XY,
                    then per-block: type:1 + coordinates
           Format:  !|z <num> <count> <x_base> <y_base>
                       <type> <x1> <y1> ...
          Example:  (see v2.0 spec §3.4.1.41)
  Uses Draw Color:  YES
Uses Line Pattern:  YES
  Uses Line Thick:  YES
  Uses Write Mode:  YES
    Uses Viewport:  YES

This extends the v1.54 RIP_BEZIER command (which drew a single        > v2.0
cubic Bezier from four control points) to support a connected          > v2.0
sequence of Bezier segments.  Each segment shares its end point       > v2.0
with the start point of the next, creating a smooth piecewise          > v2.0
curve.  This is the standard representation used in PostScript        > v2.0
and TrueType font outlines.                                          > v2.0


---------------------------------------------------------------------
RIP_POLY_BEZIER_LINE                                                  > v2.0
---------------------------------------------------------------------
         Function:  Draw connected Bezier segments with line
                    segments between them (open-ended)
            Level:  0
          Command:  t
        Arguments:  (identical structure to RIP_POLY_BEZIER)
           Format:  !|t <num> <count> <x_base> <y_base> ...

A variant of RIP_POLY_BEZIER where the segments alternate between     > v2.0
cubic Bezier curves and straight line segments.  This enables         > v2.0
complex outlines with both curved and straight edges in a single      > v2.0
command.                                                              > v2.0


---------------------------------------------------------------------
RIP_FILLED_POLY_BEZIER                                                > v2.0
---------------------------------------------------------------------
         Function:  Draw a filled region bounded by poly-Bezier
                    curves
            Level:  0
          Command:  x
        Arguments:  (identical structure to RIP_POLY_BEZIER)
           Format:  !|x <num> <count> <x_base> <y_base> ...
     NOTE: v2.0 spec header says "Command: x" but Format line         > v2.0
     says "!|z" — this is a spec copy-paste error.  The unfilled      > v2.0
     version uses 'z'; the filled version uses 'x'.                   > v2.0
  Uses Fill Color:  YES
Uses Fill Pattern:  YES
  Uses Write Mode:  YES
    Uses Viewport:  YES

The filled variant of RIP_POLY_BEZIER.  The curve path is              > v2.0
automatically closed (the last point connects to the first) and       > v2.0
the interior is filled with the current fill color and pattern.       > v2.0


---------------------------------------------------------------------
RIP_GROUP_BEGIN  /  RIP_GROUP_END                                     > v2.0
---------------------------------------------------------------------
         Function:  Group multiple drawing commands as a single
                    logical object
            Level:  0
          Command:  (  and  )
        Arguments:  none
           Format:  !|(  ...drawing commands...  !|)

These commands bracket a sequence of drawing operations and            > v2.0
mark them as a single logical group.  The exact purpose is not        > v2.0
fully determined from the binary, but likely uses include:            > v2.0

     1.  Enabling batch undo (delete the entire group as one           > v2.0
         operation in RIPaint).                                       > v2.0
     2.  Applying a transformation (scale, rotate, translate) to      > v2.0
         all commands in the group simultaneously.                    > v2.0
     3.  Deferring screen updates until RIP_GROUP_END is received,    > v2.0
         reducing flicker for complex multi-command drawings.         > v2.0


---------------------------------------------------------------------
RIP_HEADER                                                            > v2.0
---------------------------------------------------------------------
         Function:  Identify the RIPscrip version and perform
                    scene-level reset operations
            Level:  0
          Command:  h
        Arguments:  revision:2, flags:4, reserved:2
           Format:  !|h <revision> <flags> <reserved>
          Example:  !|h010A0100

The RIP_HEADER command was introduced in Revision 2.A1 as a more      > v2.0
sophisticated alternative to RIP_RESET_WINDOWS.  It serves two        > v2.0
purposes:                                                             > v2.0

The revision parameter (2-digit MegaNum):                             > v2.0
     00 = RIPscrip v1.54 compatibility mode                          > v2.0
     01 = RIPscrip v2.0                                              > v2.0

The flags parameter (4-digit MegaNum) is a bitmask that controls      > v2.0
which subsystems are reset at scene start.  Flags (OR together):      > v2.0
     1       Use MegaNums (base-36)                                   > v2.0
     2       Use UltraNums (base-64) — recommended                   > v2.0
     4       Auto-set world coordinate frame — recommended            > v2.0
     8       Set WCF to 640×350 (backward compat with v1.54)         > v2.0
     16      Hard reset (clears everything incl. protected)           > v2.0
     32      Soft reset (= RIP_RESET_WINDOWS) — recommended          > v2.0
     64      Clear port data table                                    > v2.0
     128     Clear resident queries                                   > v2.0
     256     Clear mouse/button definitions                           > v2.0
     512     Clear all data save slots                                > v2.0
     1024    Clear all base save areas                                > v2.0
     2048    Clear/stop sound                                         > v2.0
     4096    Clear screen to background color                         > v2.0
     8192    Reset all viewports to full port size                    > v2.0
     16384   Clear all text window table entries                      > v2.0
     32768   Clear all graphical style entries                        > v2.0
     65536   Clear all button style entries                           > v2.0
     131072  Reset all palette entries to defaults                    > v2.0
     262144  Erase all existing viewports                             > v2.0
     524288  Erase all existing text windows                          > v2.0
     1048576 Disable user input until RIP_NO_MORE — recommended      > v2.0


---------------------------------------------------------------------
RIP_NO_MORE                                                           > v2.0
---------------------------------------------------------------------
         Function:  Signal end of RIPscrip data in the stream
            Level:  0
          Command:  [from v2.0 TOC entry 3.4.1.31]
        Arguments:  none

This command informs the driver that no further RIPscrip commands      > v2.0
will appear in the current data stream.  The driver may use this      > v2.0
as a hint to flush rendering buffers, finalize compositing, or        > v2.0
switch to pure ANSI terminal mode for the remainder of the            > v2.0
connection.                                                           > v2.0


---------------------------------------------------------------------
RIP_SET_BORDER                                                        > v2.0
---------------------------------------------------------------------
         Function:  Enable/disable borders on filled primitives
            Level:  0
          Command:  N
        Arguments:  borders:2
           Format:  !|N <borders>
          Example:  !|N01

The borders parameter (2-digit MegaNum):                              > v2.0
     00 = Borders disabled (filled shapes have no outline)            > v2.0
     01 = Borders enabled (filled shapes draw an outline in           > v2.0
          the current drawing color/line style)                       > v2.0

Default after reset: borders enabled (v1.54 backward compat).        > v2.0

Affects: RIP_FILLED_RECTANGLE, RIP_FILLED_CIRCLE,                    > v2.0
RIP_FILLED_OVAL, RIP_PIE_SLICE, RIP_OVAL_PIE_SLICE,                  > v2.0
RIP_FILLED_POLYGON, RIP_FILLED_POLY_BEZIER,                          > v2.0
RIP_FILLED_ROUNDED_RECT.                                              > v2.0



=====================================================================
==              LEVEL 1 NEW COMMANDS (v2.0/v3.0)                   ==
=====================================================================

The v2.0 specification substantially expands the Level 1 command       > v2.0
set.  These commands manage the "Data Tables" that are the core        > v2.0
of the v2.0 rendering model: ports, palettes, graphical styles,       > v2.0
button styles, text windows, and environments.  The "Switch"           > v2.0
commands allow the host to rapidly change the active rendering        > v2.0
context without retransmitting the full configuration.                > v2.0


---------------------------------------------------------------------
RIP_DEFINE_PORT                                                       > v2.0
---------------------------------------------------------------------
         Function:  Define a new entry in the Drawing Port Table
            Level:  2
          Command:  P
        Arguments:  port_num:1, x0:XY, y0:XY, x1:XY, y1:XY,
                    flags:4, reserved:4
           Format:  !|2P <port_num> <x0> <y0> <x1> <y1>
                        <flags> <reserved>
          Example:  !|2P300002F2F00010000

Port_num (1-digit MegaNum): 1-35 (0 = screen, cannot redefine).       > v2.0
Flags (4-digit MegaNum, OR of):                                       > v2.0
     1 = Clipboard (offscreen) port                                   > v2.0
     2 = Make active immediately                                      > v2.0
     4 = Deactivate viewport on create                                > v2.0
     8 = Protect immediately                                          > v2.0
Reserved: 4 digits, set to "0000".                                    > v2.0


---------------------------------------------------------------------
RIP_DELETE_PORT                                                       > v2.0
---------------------------------------------------------------------
         Function:  Remove a port from the Drawing Port Table
            Level:  2
          Command:  p
        Arguments:  port_num:1, dest_port:1, reserved:2
           Format:  !|2p <port_num> <dest_port> <reserved>

Error strings:                                                        > v3.0
  "r_ports.cpp - portDelete()"                                       > v3.0
  "riprocmd.cpp - RIP_PortDelete()"                                  > v3.0
  "Port can't be modified - it's protected!"                         > v3.0


---------------------------------------------------------------------
RIP_PORT_COPY                                                         > v2.0
---------------------------------------------------------------------
         Function:  Copy graphics between ports (compositing)
            Level:  2
          Command:  C
        Arguments:  src_port:1, sx0:XY, sy0:XY, sx1:XY, sy1:XY,
                    dst_port:1, dx0:XY, dy0:XY, dx1:XY, dy1:XY,
                    write_mode:1, reserved:5
           Format:  !|2C <src_port> <sx0> <sy0> <sx1> <sy1>
                        <dst_port> <dx0> <dy0> <dx1> <dy1>
                        <write_mode> <reserved>

Source/dest coords of all zeros = use entire viewport.  If             > v2.0
dx1,dy1 = 0, no scaling (verbatim copy to dx0,dy0).                  > v2.0
Write mode (1-digit): 0=COPY, 1=XOR, 2=OR, 3=AND, 4=NOT.            > v2.0


---------------------------------------------------------------------
RIP_PORT_WRITE                                                        > v2.0
---------------------------------------------------------------------
         Function:  Write bitmap/icon data to a specific port
            Level:  2
          Command:  W
        Arguments:  port_num:1, x0:XY, y0:XY, x1:XY, y1:XY,
                    reserved:4, filename
           Format:  !|2W <port_num> <x0> <y0> <x1> <y1>
                        <reserved> <filename>

All coords zero = use entire viewport; x1,y1=0 = lower-right.        > v2.0


---------------------------------------------------------------------
RIP_SWITCH_PORT                                                       > v2.0
---------------------------------------------------------------------
         Function:  Switch the active drawing port
            Level:  2
          Command:  s
        Arguments:  port_num:1, flags:2, reserved:3
           Format:  !|2s <port_num> <flags> <reserved>

Port_num (1-digit MegaNum): 0-35.                                    > v2.0
Flags (2-digit MegaNum, OR of):                                       > v2.0
     1 = Protect destination port                                     > v2.0
     2 = Unprotect destination port                                   > v2.0
     4 = Protect source (current) port                                > v2.0
     8 = Unprotect source (current) port                              > v2.0


---------------------------------------------------------------------
RIP_SWITCH_TEXT_WINDOW                                                > v2.0
---------------------------------------------------------------------
         Function:  Switch the active text window
            Level:  2
          Command:  T
        Arguments:  window_num:1, reserved:1
           Format:  !|2T <window_num> <reserved>
          Example:  !|2T30

Window_num (1-digit MegaNum): 0-35 text window slots.                > v2.0


---------------------------------------------------------------------
RIP_SWITCH_PALETTE                                                    > v2.0
---------------------------------------------------------------------
         Function:  Switch the active color palette
            Level:  2
          Command:  A
        Arguments:  palette_num:2
           Format:  !|2A <palette_num>
          Example:  !|2A04

Palette_num (2-digit MegaNum): 0-35 palette slots.                   > v2.0


---------------------------------------------------------------------
RIP_SWITCH_STYLE                                                      > v2.0
---------------------------------------------------------------------
         Function:  Switch the active graphical style
            Level:  2
          Command:  Y
        Arguments:  style_num:1, reserved:1
           Format:  !|2Y <style_num> <reserved>
          Example:  !|2YG0

Style_num (1-digit MegaNum): 0-35 graphical style slots.             > v2.0
Switches draw color, back color, fill, line, font, write mode,       > v2.0
color mode, XY position, and image mode all at once.                  > v2.0


---------------------------------------------------------------------
RIP_SWITCH_BUTTON_STYLE                                               > v2.0
---------------------------------------------------------------------
         Function:  Switch the active button style template
            Level:  2
          Command:  B
        Arguments:  bstyle_num:2
           Format:  !|2B <bstyle_num>
          Example:  !|2B04

Bstyle_num (2-digit MegaNum): 0-35 button style slots.               > v2.0


---------------------------------------------------------------------
RIP_SWITCH_ENVIRONMENT                                                > v2.0
---------------------------------------------------------------------
         Function:  Switch the entire rendering environment
            Level:  2
          Command:  E
        Arguments:  env_num:2
           Format:  !|2E <env_num>
          Example:  !|2E04

An "environment" is a saved bundle of ALL rendering state:            > v2.0
the active port, palette, graphical style, button style, text          > v2.0
window configuration, and mouse field set.  Switching the             > v2.0
environment switches all of these simultaneously, enabling the        > v2.0
host to implement "scenes" or "pages" that can be swapped in and      > v2.0
out with a single command.                                            > v2.0

Source: riprocmd.cpp                                                  > v3.0

Error strings:                                                        > v3.0
  "Can't modify current environment - its protected!"                > v3.0
  "riprocmd.cpp - RIP_SwitchEnvironment()"                           > v3.0



=====================================================================
==                    TEXT VARIABLE SYSTEM                          ==
=====================================================================

RIPscrip v2.0 introduces a text variable system that enables          > v2.0
dynamic content substitution within RIPscrip command streams.          > v2.0
Variables are named tokens of the form $VARIABLENAME$ that are        > v2.0
expanded at parse time.  This allows BBS hosts to personalize         > v2.0
RIPscrip scenes without generating custom command streams for          > v2.0
each user.                                                            > v2.0


Variable Management Functions:                                        > v2.0

     RIP_DefineTextVariable                                           > v2.0
       Define or redefine a named text variable.                      > v2.0

     RIP_DeleteTextVariable                                           > v2.0
       Remove a text variable from the table.                         > v2.0

     RIP_RegisterTextVariable                                         > v2.0
       Register a system-provided (built-in) text variable.           > v2.0

     RIP_TextVariableContents                                         > v2.0
       Query the current value of a text variable.                    > v2.0

     RIP_ProcessReplacements                                          > v2.0
       Expand all $VARIABLE$ references in a command string.          > v2.0


Built-in Variables:                                                   > v2.0

The following system variables were identified from the DLL:          > v3.0

     $RAND$        Random number generator.  Replaced with a          > v2.0
                   random numeric value each time it is expanded.     > v2.0

     $RIPVER$      RIPscrip version (e.g., "RIPSCRIP030001").        > v1.54

Article Navigation:                                                   > v3.0

The text variable system includes an article/content navigation       > v3.0
subsystem, evidenced by:                                              > v3.0

     tvarProcOVERFLOW()                                               > v3.0
     tvarProcOVERFLOW(article,NEXT)                                   > v3.0
     tvarProcOVERFLOW(article,NEXT,SETVERBOSE)                        > v3.0
     tvarProcOVERFLOW(article,PREV)                                   > v3.0
     tvarProcOVERFLOW(article,PREV,SETVERBOSE)                        > v3.0

This appears to implement a paginated content system where             > v3.0
text overflow (content exceeding the current text window) triggers    > v3.0
navigation to the next or previous article/page.  The SETVERBOSE      > v3.0
flag may control whether navigation messages are displayed to the     > v3.0
user.                                                                 > v3.0

Undocumented Built-in Variables (Binary Discovery):                   > v3.0

The following 13 built-in text variables were discovered through        > v3.0
binary analysis of the DLL's ripTextVarEngine registration at           > v3.0
RVA 0x026218.  None appear in any published specification.              > v3.0

  Sound Effects:                                                       > v3.0
     $BLIP$        Short beep/click sound effect                       > v3.0
     $PHASER$      Phaser sound effect (beyond documented $BEEP$)      > v3.0

  Mode Control:                                                        > v3.0
     $COFF$        Turn cursor off (no visible caret)                  > v3.0
     $COPY$        Switch to COPY write mode (alternative to !|S)      > v3.0
     $MKILL$       Clear all mouse fields (alternative to !|1K)        > v3.0
     $DWAYON$      Enable Doorway mode (raw keyboard pass-through)     > v3.0
     $DWAYOFF$     Disable Doorway mode                                > v3.0
     $HKEYON$      Enable hotkey processing                            > v3.0
     $HKEYOFF$     Disable hotkey processing                           > v3.0

  Data / Query:                                                        > v3.0
     $WOYM$        ISO week-of-year (Monday start) date calculation    > v3.0
     $COMPAT$      Compatibility mode flag                             > v3.0

  Host Integration:                                                    > v3.0
     $GOTOURL$     Launch system web browser with specified URL.       > v3.0
                   Usage: $GOTOURL(http://example.com)$                > v3.0
                   Calls ShellExecuteA on Windows.                     > v3.0

  File Operations:                                                     > v3.0
     $FILEDEL$     Delete a file on the client machine.                > v3.0
                   Usage: $FILEDEL(filename)$                          > v3.0
                   Calls DeleteFileA on Windows.                       > v3.0

                   *** SECURITY WARNING ***                            > v3.0
                   This variable enables a remote BBS to delete        > v3.0
                   arbitrary files on the connected client's machine   > v3.0
                   by embedding $FILEDEL(path)$ in a RIPscrip scene.   > v3.0
                   Implementations SHOULD either:                      > v3.0
                     (a) refuse to implement this variable, or         > v3.0
                     (b) prompt the user for confirmation, or          > v3.0
                     (c) restrict deletion to a sandboxed directory.   > v3.0
                   The original RIPtel DLL implements it without       > v3.0
                   any user confirmation or sandboxing.                > v3.0


Error strings:                                                        > v3.0
  "Can't process text variable \"%s\""                               > v3.0
  "Can't register text variable - invalid variable name"             > v3.0
  "Text Variable Syntax Error"                                       > v3.0
  "Invalid text variable definition format"                          > v3.0
  "Invalid text variable format"                                     > v3.0
  "Invalid variable name"                                            > v3.0
  "Insufficient memory for text variable name"                       > v3.0
  "Insufficient memory for text variable object"                     > v3.0
  "Insufficient memory for text variable return buffer"              > v3.0
  "Insufficient memory to compact text variable table"               > v3.0
  "Insufficient memory to expand text variable table"                > v3.0


RIP_TextVariableContents Copy-Paste Bug (Binary Discovery):           > v3.0

The exported function RIP_TextVariableContents() displays the          > v3.0
error title "RIP_DeleteTextVariable() Error" instead of its own       > v3.0
function name when it detects an invalid instance handle.  This       > v3.0
is a copy-paste bug in the shipped RIPSCRIP.DLL v3.0.7 binary —      > v3.0
the error-handling block was copied from RIP_DeleteTextVariable()     > v3.0
without updating the title string.



=====================================================================
==                      MULTIMEDIA (v3.0)                          ==
=====================================================================

The v3.0 driver adds multimedia capabilities that were not present    > v3.0
in v1.54 or the published v2.0 specification drafts.  These are       > v3.0
likely the primary differentiators of the v3.0 revision.              > v3.0


Audio Playback                                                        > v3.0
--------------                                                        > v3.0

     RIP_PlayAudio                                                    > v3.0
       Play an audio file.  The .WAV format is confirmed via the      > v3.0
       ".wav" string in the DLL.  Other formats (MIDI, MOD) may      > v3.0
       also be supported but were not confirmed.                      > v3.0

     RIP_AudioTerminate                                               > v3.0
       Stop audio playback immediately.                               > v3.0

     ripAlarmsAndMusic                                                > v3.0
       Callback controlling whether alarm sounds and background       > v3.0
       music are enabled.  This corresponds to a user preference      > v3.0
       setting in RIPtel.                                             > v3.0

     ripAudioStatus                                                   > v3.0
       Callback querying the current audio system status              > v3.0
       (playing, stopped, error).                                     > v3.0

The audio system was explicitly noted as incomplete in the v2.0       > v2.0
specification: "Formal sound file and music file formats have not     > v2.0
been established yet for RIPscrip 2.0.  They will be shortly."        > v2.0
(Revision 2.A1).  The v3.0 driver appears to have resolved this      > v3.0
with at least basic .WAV file playback support.                       > v3.0


Web Integration                                                       > v3.0
---------------                                                       > v3.0

     RIP_GotoURL()                                                    > v3.0
       Launch the default web browser with a specified URL.  This     > v3.0
       reflects the 1997 era when Internet connectivity was            > v3.0
       displacing dial-up BBS access.  RIPtel attempted to bridge     > v3.0
       the two worlds by allowing RIPscrip scenes to contain          > v3.0
       clickable web links.                                           > v3.0

     Error strings:                                                   > v3.0
       "Invalid URL character found"                                  > v3.0
       "Invalid Web URL"                                              > v3.0
       "Can't jump to a Web URL"                                     > v3.0

     Related callbacks:                                               > v3.0
       ripWebBrowser     — path to external browser application       > v3.0
       ripBrowserAvail   — whether a browser is available             > v3.0


Encoded Data Streams                                                  > v3.0
--------------------                                                  > v3.0

     RIP_BeginEncodedStream()                                         > v3.0
       Start an inline binary data stream within the RIPscrip text    > v3.0
       stream.  This allows the host to transmit binary data           > v3.0
       (images, audio, compressed resources) without switching to     > v3.0
       a separate file transfer protocol.  The data is likely         > v3.0
       UU-encoded or base64-encoded to remain within the 7-bit        > v3.0
       ASCII constraint of RIPscrip.                                  > v3.0

     This feature was first described in Revision 2.A1:               > v2.0
     "Added the ability to embed raw UU-Encoded data blocks inside    > v2.0
     RIPscrip encoded files.  This allows you to transmit bitmaps,   > v2.0
     sound files, and other raw generic binary data over 7-bit        > v2.0
     ASCII text connections."                                         > v2.0


File Transfer                                                         > v3.0
-------------                                                         > v3.0

     RIP_EnterBlockMode                                               > v3.0
       Enter block-mode file transfer.  This suspends the RIPscrip   > v3.0
       parser and activates a binary file transfer protocol            > v3.0
       (Zmodem, etc.) to transfer files between host and terminal.    > v3.0

     Related exports:                                                 > v3.0
       RIP_GetBlockModeFilename                                       > v3.0
       RIP_GetBlockModeTransferType                                   > v3.0
       ripTransferFile (callback)                                     > v3.0



=====================================================================
==                    IMAGE FORMAT SUPPORT                         ==
=====================================================================

The v3.0 driver includes built-in decoders for multiple image          > v3.0
formats, enabling RIPscrip scenes to display photographic and          > v3.0
raster content alongside vector graphics.                             > v3.0


BMP (Windows Bitmap)                                                  > v2.0
     Internal function: ReadBitmapFile()                              > v3.0
     Supported: standard Windows BMP with palette                     > v3.0
     Fallback: "BROKEIMG.BMP" displayed on decode failure             > v3.0
     Errors: "ReadBitmapFile(): Error locking packed DIB memory"      > v3.0
             "ReadBitmapFile(): Error reading BITMAPFILEHEADER"       > v3.0
             "ReadBitmapFile(): Error reading BMP file"               > v3.0
             "Can't read bitmap file"                                 > v3.0
             "Error reading bitmap data"                              > v3.0

JPEG                                                                  > v3.0
     The driver includes a complete JPEG decoder (likely derived      > v3.0
     from the Independent JPEG Group's libjpeg).  Evidence:           > v3.0
     - Huffman table handling                                         > v3.0
     - DCT-based decoding                                            > v3.0
     - Progressive scan support                                      > v3.0
     - APP0 (JFIF) and APP14 (Adobe) marker parsing                  > v3.0
     - Color space conversion (Adobe transform codes)                > v3.0
     Errors: "Corrupt JPEG data: bad Huffman code"                   > v3.0
             "Corrupt JPEG data: premature end of data segment"      > v3.0
             "Invalid JPEG file structure: SOS before SOF"           > v3.0
             "Insufficient memory for JPEG decoder object"           > v3.0

ICN (RIPscrip Icon Format)                                            > v1.54
     The original v1.54 icon format, used for button graphics         > v1.54
     and small inline images.  These are the .ICN files in the        > v1.54
     ICONS directory.                                                 > v1.54

DIB (Device-Independent Bitmap)                                       > v3.0
     A sophisticated internal bitmap compositing system:              > v3.0
     Source: Images\DibShow.cpp, telegrfx\Diblib\Dibfread.cpp        > v3.0
     Features: mask bitmaps (transparency), 24-bit color merge,       > v3.0
               palette activation, stretch/scale operations,          > v3.0
               composite image assembly.                              > v3.0
     Errors: "dibMerge: Can't handle 24-bit bitmaps with a palette"  > v3.0
             "dibMerge: Unknown bits per pixel value"                 > v3.0
             "dibCreateMask: Unknown BMP color format"                > v3.0
             "dibActivatePalette: show_bmp_file: Can't get palette    > v3.0
              colors"                                                 > v3.0

GIF (Interlaced)                                                      > v3.0
     Confirmed by developer statement (Mark Hayton, Facebook          > v3.0
     June 2025): "a hand optimized interlaced GIF decoder."          > v3.0
     No GIF-specific strings found in the DLL, suggesting the        > v3.0
     decoder may have been compiled without debug strings or          > v3.0
     resides in a separate module.                                    > v3.0



=====================================================================
==                    RAF ARCHIVE FORMAT                            ==
=====================================================================

RAF (RIPscrip Archive Format) is a compressed container format        > v2.0+
used to bundle multiple resource files (icons, fonts, scene files)    > v2.0+
into a single archive for efficient transmission.  The archive        > v2.0+
uses ZLIB compression (confirmed by ZLIB error strings in the DLL).   > v2.0+

The RAF subsystem is implemented across five source modules:          > v3.0

     UnRAF.cpp       Decompression engine (main entry point)          > v3.0
     Rafbloat.cpp    Bloat/padding handler (possibly alignment)       > v3.0
     Rafhdr.cpp      Archive header parser                            > v3.0
     Rafndxck.cpp    Index integrity checker                          > v3.0
     Rafndxrd.cpp    Index reader/navigator                           > v3.0
     Rafopen.cpp     Archive file open/close                          > v3.0

Error strings reveal the archive structure:                           > v3.0

     "Header of archive file \"%s\" not available"                   > v3.0
     "Can't find location in archive file \"%s\""                    > v3.0
     "Can't locate index %lu in archive file \"%s\""                 > v3.0
     "Can't locate header in file \"%s\""                            > v3.0
     "Can't open file \"%s\" for reading"                            > v3.0
     "File \"%s\" fails CRC test.  Archive corrupted"                > v3.0
     "Index corrupt at offset %lu in file \"%s\""                    > v3.0
     "Archive Error E%03u: %s"                                       > v3.0

From these we can infer the RAF format:                               > v3.0

     1.  A file header identifying the archive format and version.    > v3.0
     2.  An index table at a known offset, mapping filenames to       > v3.0
         compressed data offsets and sizes.                           > v3.0
     3.  Individual entries compressed with ZLIB (deflate).           > v3.0
     4.  CRC integrity checking per entry.                            > v3.0
     5.  Offset-based random access via the index table.              > v3.0

The RAF format serves the same purpose as a .ZIP file but with        > v3.0
a simpler structure optimized for sequential and random access        > v3.0
patterns typical of BBS icon loading.                                 > v3.0

The archive header magic is "SQSH" (0x53515348), confirmed by           > v3.0
binary analysis of the rafValidateHeader function.  The 22-byte          > v3.0
header structure:                                                        > v3.0
                                                                         > v3.0
     Offset  Size  Field                                                 > v3.0
     ──────  ────  ──────────────────────                                > v3.0
     0-3     4     Magic ("SQSH")                                        > v3.0
     4-5     2     Entry count                                           > v3.0
     6-9     4     Index region byte size                                > v3.0
     10-21   12    Reserved/flags                                        > v3.0
                                                                         > v3.0
The RAF error system includes a 46-entry built-in error string           > v3.0
table.  Error codes 0x01-0x2D map to human-readable messages;           > v3.0
codes above 0x2D produce "Unknown error".                               > v3.0



=====================================================================
==                  HOST CALLBACK INTERFACE                        ==
=====================================================================

The RIPscrip driver does not directly access hardware, network         > v3.0
connections, or the filesystem.  Instead, it communicates with the    > v3.0
host application (e.g., RIPtel) through an extensive callback         > v3.0
table.  The host registers callback functions via ripSetCallback()    > v3.0
and ripCallbackInit().  The driver invokes these callbacks when it    > v3.0
needs to perform I/O, query settings, or display UI feedback.         > v3.0

This callback architecture is what makes the RIPscrip driver          > v3.0
portable: the same DLL can be embedded in a telnet client, a BBS      > v3.0
door, a web applet, or any other host application that implements     > v3.0
the callback interface.                                               > v3.0

The complete callback interface, reconstructed from the DLL's          > v3.0
string table, is as follows:                                          > v3.0


COMMUNICATIONS                                                        > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripCommReadChar             Read one byte from the connection.        > v3.0
ripCommWriteChar            Write one byte to the connection.         > v3.0
ripCommBaudRate             Query the connection speed (bps).         > v3.0
ripCommFlowControl          Query/set flow control mode.              > v3.0
ripCommOutputBufferEmpty    Test if the TX buffer has drained.        > v3.0
ripCommSensitiveReceive     Enable priority receive mode              > v3.0
                            (reduces latency for time-critical        > v3.0
                            data like mouse coordinates).             > v3.0

DISPLAY                                                               > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripGetDisplayRect           Query the display dimensions.             > v3.0
ripInvalidateRect           Notify that a screen region needs         > v3.0
                            repainting (dirty rectangle).             > v3.0
ripBackgroundPalette        Query/set the background palette.         > v3.0

SCROLLBACK                                                            > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripScrollbackAddChar        Add a character to the scrollback         > v3.0
                            history buffer.                           > v3.0
ripScrollbackBackspace      Process a backspace in the scrollback.    > v3.0
ripScrollbackBeginOfLine    Signal the start of a new line in         > v3.0
                            the scrollback buffer.                    > v3.0

INPUT                                                                 > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripMousePresent             Query whether a mouse is available.       > v3.0
ripMouseEntryExit           Notify mouse enter/leave events.          > v3.0
ripCursorAvail              Query cursor availability.                > v3.0
ripHotkeyStatus             Query/set hotkey processing mode.         > v3.0
ripUseExtKeyboard           Enable extended keyboard mode.            > v3.0

FILE SYSTEM                                                           > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripHostDirectory            Query/set the host working directory.     > v3.0
ripSearchPath               Query the file search path.               > v3.0
ripTransferFile             Initiate a file transfer (upload or       > v3.0
                            download) using the host's transfer       > v3.0
                            protocol (Zmodem, etc.).                  > v3.0
ripDataSecurity             Query the security level for file         > v3.0
                            operations (restrict access to            > v3.0
                            sensitive directories).                   > v3.0

TERMINAL EMULATION                                                    > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripAnsiEmulation            Query/set ANSI emulation mode.            > v3.0
ripRIPscripEmulation        Query/set RIPscrip emulation mode.        > v3.0
ripVT102Emulation           Query/set VT-102 emulation mode.          > v3.0
ripDoorwayStatus            Query/set Doorway mode (keyboard          > v3.0
                            pass-through for remote applications).    > v3.0

APPLICATION INTEGRATION                                               > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripProductName              Return the host application name.         > v3.0
ripProductPlatform          Return the platform identifier.           > v3.0
ripProductVersion           Return the host version string.           > v3.0
ripVendorName               Return the vendor name.                   > v3.0
ripSerialNumber             Return the serial number.                 > v3.0
ripRegistration             Return the registration status.           > v3.0
ripExternalAppRun           Launch an external application.           > v3.0
ripExternalAppSupported     Query whether external apps are           > v3.0
                            supported on this platform.               > v3.0
ripWebBrowser               Return the path to the default web        > v3.0
                            browser executable.                       > v3.0
ripBrowserAvail             Query whether a web browser is            > v3.0
                            available.                                > v3.0

UI FEEDBACK                                                           > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripProgressMeterInit        Initialize a progress bar.                > v3.0
ripProgressMeterUpdate      Update the progress value.                > v3.0
ripProgressMeterRedraw      Redraw the progress bar.                  > v3.0
ripProgressMeterUnInit      Close the progress bar.                   > v3.0
ripStatbarIdle              Set the status bar idle text.             > v3.0
ripStatbarStatus            Update the status bar text.               > v3.0
ripIdleFunction             Idle processing hook (called during       > v3.0
                            long operations to keep the host          > v3.0
                            application responsive).                  > v3.0
ripPopupMissingFiles        Display a dialog listing files that       > v3.0
                            could not be found.                       > v3.0

CONFIGURATION                                                         > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripAddCrLf                  Auto CR/LF insertion mode.                > v3.0
ripWordWrap                 Word wrap mode for text output.           > v3.0
ripCharPacing               Inter-character delay (ms).               > v3.0
ripLinePacing               Inter-line delay (ms).                    > v3.0
ripBeepsAndBells            Enable/disable audible beeps.             > v3.0
ripBackspaceSendsDel        Backspace key sends DEL (0x7F).           > v3.0
ripDestructiveBackspace     Backspace erases the character.           > v3.0
ripTabStatus                Tab key handling mode.                    > v3.0
ripHalfDuplex               Half-duplex (local echo) mode.            > v3.0
ripQuickPhotos              Quick photo display mode (reduced         > v3.0
                            quality for faster rendering).            > v3.0
ripCaptureANSI              Enable ANSI text capture to file.         > v3.0
ripCaptureRIPscrip          Enable RIPscrip capture to file.          > v3.0
ripIconConvertStatus        Icon format conversion status.            > v3.0

DEBUGGING                                                             > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripSetDebugLevel            Set the debug trace verbosity.            > v3.0
ripTracerStatus             Query the tracer/debugger status.         > v3.0
ripErrorSetLevel            Set the error reporting threshold.        > v3.0
ripErrorShow                Display an error message to the user.     > v3.0
ripLogWriteChar             Write a character to the debug log.       > v3.0

FONT & ICON PATHS                                                     > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripSetFontDir               Set the font search directory.            > v3.0
ripSetIconDir               Set the icon search directory.            > v3.0
ripSetWorkingDir            Set the general working directory.        > v3.0

CONTENT RETRIEVAL                                                     > v3.0
──────────────────────────────────────────────────────────────        > v3.0
ripSetRetrieveFn            Set the general file retrieval callback   > v3.0
                            (for downloading missing icons/fonts).    > v3.0
ripSetRetrieveJPEGDataFn    Set the JPEG-specific retrieval           > v3.0
                            callback (for inline image loading).      > v3.0



=====================================================================
==                 MEGANUM VALIDATION NOTE                         ==
=====================================================================

The error string "Invalid MegaNum" confirms that the v3.0 driver      > v3.0
validates MegaNum (base-36) digit encoding at parse time.              > v3.0
Implementations should reject non-alphanumeric characters in           > v3.0
MegaNum fields and skip the malformed command rather than              > v3.0
silently treating invalid digits as zero.                             > v3.0



=====================================================================
==          DEVIATIONS: v2.A4 SPEC vs. RIPtel v3.0 PRODUCTION     ==
=====================================================================

The following section documents cases where the production v3.0       > v3.0
driver (RIPSCRIP.DLL as shipped in RIPtel 3.1, October 1997)         > v3.0
deviates from the published v2.A4 specification.  These deviations   > v3.0
fall into four categories: commands that were dropped, commands       > v3.0
that were redesigned, commands that were merged into other            > v3.0
commands, and commands that were internalized (removed from the       > v3.0
public DLL export table but still functional via the RIPscrip wire   > v3.0
protocol).                                                            > v3.0

BBS implementers should pay careful attention to this section.        > v3.0
Implementing a command exactly as the v2.A4 spec describes it may    > v3.0
result in behavior that RIPtel does not support or handles            > v3.0
differently than expected.                                            > v3.0


DROPPED COMMANDS (do not implement)                                   > v3.0
---------------------------------------------------------------------

RIP_SCROLLER  (v2.A1, §1.4.4)                                        > v3.0

     The v2.A1 revision notes state: "Added a new command for the    > v3.0
     creation and manipulation of scroller-type user interface        > v3.0
     objects."  This command was intended to provide a standardized   > v3.0
     scrollbar widget for RIPscrip scenes.                           > v3.0

     STATUS:  Completely absent from the production v3.0 DLL.         > v3.0
     No function string containing "scroller" (case-insensitive)      > v3.0
     was found.  The related command "RIP_Scroll" IS present, but    > v3.0
     this is a different command (screen region scroll, not a UI      > v3.0
     scrollbar widget).                                               > v3.0

     RECOMMENDATION:  Do not implement RIP_SCROLLER.  RIPtel         > v3.0
     will not recognize it.  If scrollbar functionality is needed,   > v3.0
     implement it using RIP_BUTTON with appropriate graphics.        > v3.0


RIP_FILLED_RECTANGLE  (v2.A2, §3.4.1.20)                             > v3.0

     The v2.A2 revision added RIP_FILLED_RECTANGLE as a distinct     > v3.0
     command separate from the v1.54 RIP_BAR ('B').  The purpose     > v3.0
     was to add write mode support (XOR, OR, AND, NOT) to filled     > v3.0
     rectangles, which RIP_BAR in v1.54 did not support.             > v3.0

     STATUS:  Not present as a named function in the v3.0 DLL.       > v3.0
     The DLL contains the Windows GDI call "FillRect" but no          > v3.0
     "RIP_FilledRectangle" or equivalent.                            > v3.0

     WHAT HAPPENED:  Rather than adding a new command, TeleGrafix    > v3.0
     extended the existing RIP_BAR command to support write modes.   > v3.0
     In v3.0, RIP_BAR ('B') now honors the current write mode         > v3.0
     set by RIP_WRITE_MODE, making the separate FILLED_RECTANGLE     > v3.0
     command redundant.                                               > v3.0

     RECOMMENDATION:  Use RIP_BAR ('B') for all filled rectangles.   > v3.0
     It supports write modes in v2.0+ as described in the v2.A1      > v3.0
     revision notes (§1.4.4): "XOR applies to all primitives."       > v3.0


REDESIGNED COMMANDS (interface changed)                               > v3.0
---------------------------------------------------------------------

RIP_SET_REFRESH  (v2.A1, §3.4.3.5, Level 2, Command 'R')            > v3.0

     The v2.A1 revision added RIP_SET_REFRESH as a Level 2           > v3.0
     RIPscrip wire command (!|2R) that allowed the BBS host to       > v3.0
     define a refresh sequence.  When the user requested a screen    > v3.0
     refresh, the terminal would transmit this stored sequence       > v3.0
     back to the host.                                                > v3.0

     STATUS:  The wire command format "!|2R" is NOT confirmed in      > v3.0
     the v3.0 DLL string table.  However, the refresh mechanism      > v3.0
     itself IS present, redesigned as a host API:                     > v3.0

          RIP_RefreshAvailable     Query if refresh is possible       > v3.0
          RIP_RefreshSend          Trigger a refresh                  > v3.0
          refreshAssignCommand()   Internal: assign refresh seq       > v3.0

     Additionally, the text variables $REFRESH$ and $NOREFRESH$       > v3.0
     are present, matching the v2.A1 spec's description of text      > v3.0
     variable overrides for the refresh system.                       > v3.0

     WHAT HAPPENED:  The refresh mechanism was moved from a           > v3.0
     RIPscrip wire command to a DLL API function.  The BBS does      > v3.0
     not send "!|2R" over the wire.  Instead, the host application   > v3.0
     (RIPtel) handles refresh internally via the API.  The BBS        > v3.0
     can still use $REFRESH$ / $NOREFRESH$ text variables within     > v3.0
     RIPscrip command parameters.                                     > v3.0

     RECOMMENDATION:  BBS implementations should NOT send "!|2R"      > v3.0
     as a wire command.  Use $REFRESH$ and $NOREFRESH$ text          > v3.0
     variables instead.                                               > v3.0


MERGED COMMANDS (absorbed into existing commands)                     > v3.0
---------------------------------------------------------------------

RIP_SWITCH_VIEWPORT  (v2.A3)                                          > v3.0

     The v2.A3 revision notes state: "RIP_SWITCH_VIEWPORT had its    > v3.0
     command character changed" — indicating it existed as a          > v3.0
     separate command for switching the active viewport independently > v3.0
     of the active port.                                              > v3.0

     STATUS:  Not present in the v3.0 DLL.  The DLL contains          > v3.0
     "RIP_ViewPort()" (the original v1.54 viewport definition        > v3.0
     command) but no "RIP_SwitchViewport" or equivalent.              > v3.0

     WHAT HAPPENED:  In the v2.0 port system, each port contains     > v3.0
     its own viewport.  Switching the active port (via                > v3.0
     RIP_SWITCH_PORT, "!|2s") implicitly switches the viewport       > v3.0
     to the destination port's viewport.  A separate viewport         > v3.0
     switch command became redundant once the port system was         > v3.0
     fully developed.  The original RIP_VIEWPORT command ('v')        > v3.0
     still works to redefine the viewport within the current port.   > v3.0

     RECOMMENDATION:  Do not implement a separate SWITCH_VIEWPORT    > v3.0
     command.  Use RIP_SWITCH_PORT ("!|2s") to switch contexts,      > v3.0
     and RIP_VIEWPORT ('v') to adjust the viewport within a port.    > v3.0


INTERNALIZED COMMANDS (work via wire but not DLL API)                 > v3.0
---------------------------------------------------------------------

The following commands are defined in the v2.A4 specification as      > v3.0
both RIPscrip wire protocol commands AND DLL API exports.  In the    > v3.0
production v3.0 DLL, they are implemented as internal functions       > v3.0
(confirmed via error strings and source file references) but are     > v3.0
NOT present in the DLL export table as named "RIP_" API functions.   > v3.0

This means:                                                           > v3.0
  - BBS → RIPtel via wire protocol:  WORKS.  The parser processes    > v3.0
    the "!|2" command and dispatches to the internal handler.         > v3.0
  - Host app calling DLL API:  NOT AVAILABLE.  The host cannot       > v3.0
    call these functions programmatically through the DLL.            > v3.0

For BBS implementers, this distinction does not matter — the wire     > v3.0
commands work correctly.  For DLL embedders, these functions must     > v3.0
be invoked via RIP_ProcessBuffer() with the appropriate RIPscrip     > v3.0
command bytes rather than direct API calls.                           > v3.0


RIP_SWITCH_STYLE  (v2.A0, §3.4.3.11, Level 2, Command 'Y')          > v3.0

     v2.A4 spec:     Exported as RIP_SwitchStyle                     > v3.0
     v3.0 DLL:       Internal "styleSwitch()" only                   > v3.0
     Wire command:   !|2Y<style_num><reserved>  — FUNCTIONAL         > v3.0

     The graphical style switching mechanism exists and works          > v3.0
     when RIPtel receives "!|2Y" from a BBS.  It is simply not       > v3.0
     exposed as a named DLL export.                                   > v3.0


RIP_SWITCH_ENVIRONMENT  (v2.A4, §3.4.3.7, Level 2, Command 'E')     > v3.0

     v2.A4 spec:     Exported as RIP_SwitchEnvironment               > v3.0
     v3.0 DLL:       "riprocmd.cpp - RIP_SwitchEnvironment()"        > v3.0
                      referenced in error strings; internal only.     > v3.0
     Wire command:   !|2E<env_num>  — FUNCTIONAL                     > v3.0

     The environment switching mechanism is confirmed to exist         > v3.0
     via extensive error strings:                                     > v3.0
       "Can't modify current environment - its protected!"            > v3.0
       "Cannot protect environment slot #0"                           > v3.0
       "Current environment is protected - cannot delete"             > v3.0
       "Illegal environment slot number"                              > v3.0
       "environmentDelete()"                                          > v3.0
       "environmentInUse()"                                           > v3.0
       "environmentInit()"                                            > v3.0
       "environmentProtect()"                                         > v3.0


RIP_SWITCH_PALETTE  (v2.A3, §3.4.3.8, Level 2, Command 'A')         > v3.0

     v2.A4 spec:     Exported as RIP_SwitchPalette                   > v3.0
     v3.0 DLL:       "riprocmd.cpp - RIP_SwitchPalette()"            > v3.0
                      referenced in error strings; internal only.     > v3.0
     Wire command:   !|2A<palette_num>  — FUNCTIONAL                  > v3.0


ADDITIONAL INTERNAL HANDLERS (not in v2.A4 spec)                      > v3.0
---------------------------------------------------------------------

The following internal functions were found in the DLL that appear     > v3.0
to support the "Switch" command family but are not documented in      > v3.0
the v2.A4 specification:                                              > v3.0

     textWindowSwitch()   Internal handler for !|2T (confirmed       > v3.0
                          — matches RIP_SWITCH_TEXT_WINDOW spec)      > v3.0

     RIP_SwitchDirectory()  Switch the working directory.  This      > v3.0
                          command is NOT in the v2.A4 specification.  > v3.0
                          It may allow the BBS to redirect the        > v3.0
                          terminal's icon/font search path at         > v3.0
                          runtime.  v3.0-only addition.               > v3.0


SUMMARY TABLE                                                         > v3.0
---------------------------------------------------------------------

     v2.A4 Command            v3.0 Status           BBS Action
     ─────────────────────    ─────────────────────  ─────────────
     RIP_SCROLLER             DROPPED                Do not use
     RIP_FILLED_RECTANGLE     MERGED into RIP_BAR    Use 'B' instead
     RIP_SET_REFRESH           REDESIGNED to API     Use $REFRESH$
     RIP_SWITCH_VIEWPORT      MERGED into SWITCH_    Use !|2s
                               PORT
     RIP_SWITCH_STYLE         INTERNALIZED           !|2Y works
     RIP_SWITCH_ENVIRONMENT   INTERNALIZED           !|2E works
     RIP_SWITCH_PALETTE       INTERNALIZED           !|2A works



=====================================================================
==                    v2.A4 SPECIFICATION ERRATA                   ==
=====================================================================

The following inconsistencies were discovered in the published         > v3.0
v2.A4 specification by cross-referencing against the production       > v3.0
v3.0 DLL binary.  BBS and terminal implementers should apply          > v3.0
these corrections when working from the v2.A4 document.               > v3.0


Erratum 1:  Command letter 'b' collision                              > v3.0
----------------------------------------------                        > v3.0

RIP_SET_BASE_MATH (§3.4.1.46, added in v2.A0) and                    > v3.0
RIP_EXTENDED_TEXT_WINDOW (§3.4.1.12, added in v2.A4) both use        > v3.0
command letter 'b' at Level 0.  The parser must disambiguate          > v3.0
by argument length:                                                    > v3.0

     RIP_SET_BASE_MATH has exactly 2 characters after 'b'.           > v3.0
     RIP_EXTENDED_TEXT_WINDOW has 15+ characters after 'b'.           > v3.0

The production DLL handles this correctly.  Implementations that      > v3.0
parse by command letter alone will misinterpret one or both.          > v3.0


Erratum 2:  RIP_FILLED_POLY_BEZIER command letter                    > v3.0
----------------------------------------------                        > v3.0

§3.4.1.19 header states "Command: x" but the Format line reads        > v3.0
"!|z" (which is the unfilled RIP_POLY_BEZIER command letter).         > v3.0
This is a copy-paste error in the specification.                      > v3.0

     Correct:  RIP_POLY_BEZIER         = 'z' (unfilled)              > v3.0
               RIP_FILLED_POLY_BEZIER  = 'x' (filled)                > v3.0


Erratum 3:  RIP_DELETE_PORT command letter                            > v3.0
----------------------------------------------                        > v3.0

§3.4.3.2 header states "Command: p" but the Format line reads         > v3.0
"!|2s" (which is the RIP_SWITCH_PORT command letter).  The TOC        > v3.0
lists these as separate commands at separate page numbers.            > v3.0

     Correct:  RIP_DELETE_PORT  = !|2p  (Level 2, letter 'p')        > v3.0
               RIP_SWITCH_PORT  = !|2s  (Level 2, letter 's')        > v3.0



=====================================================================
==        v3.0 DRIVER IMPLEMENTATION BUGS (Binary Discovery)        ==
=====================================================================

The following bugs were discovered in the production RIPSCRIP.DLL       > v3.0
v3.0.7 binary.  Implementers should be aware of these to avoid         > v3.0
replicating the same defects.                                          > v3.0


§BUG.1  Memory Allocator Silently Masks Out-of-Memory                  > v3.0
---------------------------------------------------------

ripHeapAllocPtr (86 call sites) unconditionally returns 1              > v3.0
(success) even when the allocation fails and the output pointer        > v3.0
is NULL.  Callers that check only the return value will never          > v3.0
detect OOM.  The actual success indicator is whether the output        > v3.0
pointer (*ppOut) is non-NULL — an undocumented convention.             > v3.0

Recommendation: Portable implementations should return 0 on           > v3.0
allocation failure and check the return value, not the pointer.        > v3.0


§BUG.2  Buffer Overflow Discards Entire Input Queue                    > v3.0
---------------------------------------------------------

When the RIP staging buffer exceeds RIP_BUF_MAX (5000 bytes),          > v3.0
both ParseRIP (host side) and ParseRIPFrame (DLL side) discard         > v3.0
ALL pending input and reset the fill pointer to zero:                  > v3.0

     if (g_ripBufLen >= RIP_BUF_MAX) {                                > v3.0
         BufFlushN(hInBuf, remaining);                                > v3.0
         g_ripBufLen = 0;                                             > v3.0
     }                                                                > v3.0

This means any partial RIPscrip command straddling the 5000-byte       > v3.0
boundary is silently lost.  The parser re-syncs on the next            > v3.0
valid !| sequence, potentially causing garbled rendering.  The         > v3.0
error string "RIPscrip Buffer Overflow - 0" confirms the case         > v3.0
was known but not gracefully handled.                                  > v3.0

Recommendation: Discard only the current incomplete command,           > v3.0
not the entire buffer.  Or use a circular buffer with command          > v3.0
boundary tracking.                                                     > v3.0


§BUG.3  Histogram Counter Overflow Inversion                           > v3.0
---------------------------------------------------------

In RipDib_AccumHistogram (adaptive palette quantization), the          > v3.0
16-bit pixel-colour histogram counter DECREMENTS on overflow           > v3.0
instead of saturating at 0xFFFF.  This causes extremely common         > v3.0
colours to wrap their count downward, making them appear rarer         > v3.0
than they are — potentially excluding the dominant colour from         > v3.0
the quantized palette.                                                 > v3.0

Recommendation: Saturate at 0xFFFF (clamp, do not wrap).              > v3.0


§BUG.4  Zmodem ZRPOS Re-Seek Handler is a TODO Stub                   > v3.0
---------------------------------------------------------

During Zmodem file send, the ZRPOS response handler                    > v3.0
(receiver requesting retransmission from a specific offset)            > v3.0
is unimplemented:                                                      > v3.0

     if (ret == ZRPOS) { /* TODO: handle re-seek */ }                 > v3.0

Without ZRPOS handling, a Zmodem send continues from the               > v3.0
current position after a bad block, potentially delivering             > v3.0
a corrupted file without either side detecting it.                     > v3.0

Recommendation: Implement ZRPOS by seeking the file to the            > v3.0
requested offset and retransmitting from that point.                   > v3.0


§BUG.5  VGA DAC Precision Loss on Windows                             > v3.0
---------------------------------------------------------

The palette pipeline converts all RGB values from 8-bit to             > v3.0
6-bit (VGA DAC format) via right-shift by 2 before passing             > v3.0
them to SetPaletteEntries.  This permanently discards 2 bits           > v3.0
per channel — colours are quantized to multiples of 4.                 > v3.0

This was correct for DOS-era direct VGA register access but            > v3.0
incorrect for Windows GDI, which accepts full 8-bit values.            > v3.0
The v3.0 DLL (shipped 1997, Windows-only) continued using              > v3.0
VGA DAC math, permanently reducing colour fidelity on a                > v3.0
platform that supported full 8-bit channels.                           > v3.0

A typical RGB565 palette (16-bit, 5+6+5 bits)                  > v3.0
preserves higher precision than the original driver.                   > v3.0


§BUG.6  Per-Entry GDI Palette Updates (Performance)                    > v3.0
---------------------------------------------------------

RIP_OneDrawingPalette calls GDI32!SetPaletteEntries for each           > v3.0
individual palette entry change (at the !|a command).  In scenes       > v3.0
that set many palette entries, this results in a GDI round-trip        > v3.0
per command rather than batching all changes into a single call.       > v3.0

Recommendation: Batch palette changes and apply them in a              > v3.0
single update (as a direct-palette implementation does              > v3.0
memory writes with no system call overhead).                           > v3.0


=====================================================================
==         UNDOCUMENTED COMMANDS (Binary-Only Discovery)            ==
=====================================================================

The following commands were discovered through full disassembly of       > v3.0
the RIPSCRIP.DLL command dispatch table (129 entries at RVA 0x080820,   > v3.0
40 bytes per entry).  These commands are NOT documented in the v1.54,   > v3.0
v2.A4, or any previously known specification.  Their existence was      > v3.0
confirmed by:                                                           > v3.0
  1. Presence in the binary dispatch table with valid handler pointers   > v3.0
  2. Disassembly of handler code showing functional implementations     > v3.0
  3. For RIP_BOUNDED_TEXT: a working example in BOUNDS.RIP              > v3.0


---------------------------------------------------------------------
RIP_BOUNDED_TEXT                                                        > v3.0
---------------------------------------------------------------------
         Function:  Render text within a bounded rectangle with
                    automatic word-wrapping and clipping
            Level:  0
          Command:  " (double quote, 0x22)
        Arguments:  x0:XY, y0:XY, x1:XY, y1:XY, flags:2, text
           Format:  !|" <x0> <y0> <x1> <y1> <flags> <text>
          Example:  !|"2020A03000This is just another
                    (from BOUNDS.RIP distributed with RIPtel 3.1)

The bounding box (x0,y0)-(x1,y1) defines the rectangle within which     > v3.0
text is rendered.  The driver automatically word-wraps text to fit       > v3.0
the rectangle width.  The flags parameter (2-digit MegaNum) controls    > v3.0
rendering options (value 00 = default).                                  > v3.0

The text content follows the flags field and extends to the next '|'     > v3.0
delimiter or end of line — identical to the text tail format used by     > v3.0
RIP_TEXT ('T').                                                          > v3.0

Handler address:  RVA 0x01A0DA                                          > v3.0

Error strings observed:                                                  > v3.0
  "Cannot created bounded text with old-style system fonts"              > v3.0
  "Width of bounding box is zero - cannot draw text"                     > v3.0
  "Unable to allocate temp string"                                       > v3.0

The handler also references the text variable $TEXTDATA$, suggesting    > v3.0
that the text content can come from the text variable system as well     > v3.0
as inline in the command stream.                                         > v3.0

NOTE:  This command only works with RFF raster fonts, MicroANSI          > v3.0
fonts, or TrueType fonts.  The 8x8 bitmap system font (font 0) is      > v3.0
explicitly rejected with the "old-style system fonts" error.             > v3.0

Working example in BOUNDS.RIP:                                           > v3.0
  !|c0F                      ; Set draw color to white                   > v3.0
  !|y0000010P000000001a1a... ; Set extended font (Marin)                 > v3.0
  !|R2020A030                ; Draw bounding rectangle outline           > v3.0
  !|"2020A03000This is ...   ; Render bounded text inside it             > v3.0


---------------------------------------------------------------------
RIP_ICON_DISPLAY_STYLE                                                  > v3.0
---------------------------------------------------------------------
         Function:  Set icon/image compositing display mode
            Level:  0
          Command:  & (ampersand, 0x26)
        Arguments:  x0:XY, y0:XY, mode1:2, mode2:2, mode3:2
           Format:  !|& <x0> <y0> <mode1> <mode2> <mode3>

Controls how subsequent icon/bitmap display operations composite        > v3.0
images onto the screen.  The three mode parameters likely encode:       > v3.0
  mode1:  Display mode (copy/XOR/transparent/etc.)                      > v3.0
  mode2:  Scaling/stretch mode                                           > v3.0
  mode3:  Alignment/anchor mode                                          > v3.0

Handler address:  RVA 0x01F904 (8,232-byte stack frame)                  > v3.0
The large stack frame indicates complex image processing logic.          > v3.0


---------------------------------------------------------------------
RIP_FILLED_POLYGON_EXT  /  RIP_POLYLINE_EXT                            > v3.0
---------------------------------------------------------------------
         Function:  Extended polygon/polyline with rendering controls
            Level:  0
         Commands:  [ (0x5B, filled)  and  ] (0x5D, outline)
        Arguments:  x0:XY, y0:XY, x1:XY, y1:XY,
                    mode:2, param1:2, param2:2
           Format:  !|[ <x0> <y0> <x1> <y1> <mode> <p1> <p2>
                    !|] <x0> <y0> <x1> <y1> <mode> <p1> <p2>

Extended versions of RIP_FILLED_POLYGON ('p') and RIP_POLYLINE ('l')    > v3.0
that add write mode, edge style, and additional rendering parameters.   > v3.0
The '[' variant calls GDI Polygon (filled); ']' calls Polyline.        > v3.0

Handler addresses:  RVA 0x01FEE1 ([) and 0x01FAC7 (])                   > v3.0
Both have 8,244-byte stack frames and identical call patterns.           > v3.0


---------------------------------------------------------------------
RIP_DRAW_TO                                                             > v3.0
---------------------------------------------------------------------
         Function:  Draw-to with rendering mode control
            Level:  0
          Command:  _ (underscore, 0x5F)
        Arguments:  x0:XY, y0:XY, mode:2, param:2, x1:XY, y1:XY
           Format:  !|_ <x0> <y0> <mode> <param> <x1> <y1>

Combines cursor movement with optional line drawing and mode             > v3.0
selection.  An enhanced version of the combined MOVE+LINE operation.     > v3.0

Handler address:  RVA 0x01BB18                                           > v3.0


---------------------------------------------------------------------
RIP_COMPOSITE_ICON                                                      > v3.0
---------------------------------------------------------------------
         Function:  Multi-region icon/screen compositing
            Level:  0
          Command:  ` (backtick, 0x60)
        Arguments:  XY x10, mode:1
                    (10 XY coordinates = 5 source/dest rectangle pairs,
                     plus a 1-digit compositing mode)
           Format:  !|` <coords x10> <mode>

A sophisticated compositing command that blends/overlays up to 5         > v3.0
screen regions simultaneously.  The 10 XY coordinates define source     > v3.0
and destination rectangles for a batch blit operation.  The mode         > v3.0
digit selects the raster operation (COPY/XOR/OR/AND/NOT).               > v3.0

Handler address:  RVA 0x01D963 (2,972-byte stack frame)                  > v3.0

This command may be the mechanism behind the WIPE*.FN transition         > v3.0
effect files distributed with RIPtel 3.1, which define screen            > v3.0
wipe animations using port copy operations.                              > v3.0


---------------------------------------------------------------------
RIP_ANIMATION_FRAME                                                     > v3.0
---------------------------------------------------------------------
         Function:  Animation frame / complex polygon with both
                    fill and outline in a single command
            Level:  0
          Command:  { (left brace, 0x7B)
        Arguments:  XY x6  (3 coordinate pairs)
           Format:  !|{ <x0> <y0> <x1> <y1> <x2> <y2>

Draws a complex polygon with BOTH filled interior AND separate           > v3.0
outline in a single command.  The handler calls both GDI Polygon         > v3.0
and Polyline.  This eliminates the two-command sequence previously       > v3.0
required (draw filled polygon, then draw outline separately).            > v3.0

Handler address:  RVA 0x01B89B (2,960-byte stack frame)                  > v3.0

The '{' / '}' brace pair may define animation frame begin/end            > v3.0
boundaries, analogous to how '(' / ')' define drawing groups.           > v3.0


---------------------------------------------------------------------
Control Escape (0x1B)                                                   > v3.0
---------------------------------------------------------------------
         Function:  Terminal control escape sequences
            Level:  1 and 2 (three handlers)
          Command:  ESC (0x1B, the ASCII escape character)
        Arguments:  Varies by level:
                    Level 1:  3 args (1-digit, 1-digit, 2-digit)
                    Level 2a: 1 arg  (4-digit MegaNum)
                    Level 2b: 5 args (1,1,2,2,2-digit)

Internal driver commands using the ESC control character as the          > v3.0
command letter.  These likely manage terminal mode switching,             > v3.0
ANSI passthrough control, and port-specific terminal state.              > v3.0
Having three handlers at different levels suggests graduated              > v3.0
control from session-level (L1) to port-level (L2).                     > v3.0

Handler addresses:                                                       > v3.0
  Level 1 (entry 85):  RVA 0x00D3DA                                      > v3.0
  Level 2 (entry 110): RVA 0x046F66                                      > v3.0
  Level 2 (entry 124): RVA 0x024B4E                                      > v3.0



=====================================================================
==               COMPLETE BINARY COMMAND TABLE                      ==
=====================================================================

The following table represents the COMPLETE set of commands                > v3.0
implemented in RIPSCRIP.DLL v3.0.7, as extracted from the binary          > v3.0
dispatch table at RVA 0x080820 (129 entries, 40 bytes each).              > v3.0

Entry format:  [+0] index, [+1..4] handler pointer, [+15] command         > v3.0
letter, [+16..19] argument count (signed), [+20+] argument types.         > v3.0

Argument type codes:                                                      > v3.0
  0xFF = XY coordinate pair (variable width per SET_COORDINATE_SIZE)      > v3.0
  0xFE = Color value (variable width per SET_COLOR_MODE)                  > v3.0
  0x01 = 1-digit MegaNum (0-35)                                          > v3.0
  0x02 = 2-digit MegaNum (0-1295)                                        > v3.0
  0x04 = 4-digit MegaNum (0-1,679,615)                                   > v3.0
  Negative count = variable-length command                                > v3.0

Total implemented commands:  80 (Level 0) + 25 (Level 1) + 19 (Level 2)  > v3.0
                           + 5 (Level 3) = 129                            > v3.0



=====================================================================
==               RIPSCRIP PRE-PROCESSOR (Binary Discovery)          ==
=====================================================================

The ANSI/VT-102 terminal emulator in RIPSCRIP.DLL contains a
conditional compilation pre-processor, embedded in the escape
sequence handler at RVA 0x1004C244.  This subsystem was never
documented in any published specification.

Pre-processor tokens use <<...>> delimiters within the RIPscrip
data stream:

  Token               Purpose
  ---------------------------------------------------------------
  <<IF expr>>         Begin conditional block
  <<ELSEIF expr>>     Alternate conditional
  <<ELSE>>            Default branch
  <<ENDIF>>           End conditional block
  <<DEFINE name>>     Define a text variable

Expression syntax supports:

  Operators:  AND, OR, NOT, XOR
  Comparisons: = (string equality)
  Variables:  $VARIABLE_NAME$ (text variable expansion)
  Literals:   Quoted strings "value"

Example (from binary string table):

     <<IF $TGMENU_WIPES$="1">>
       $>wipe<<rand(24,2,4)>>.fn$
     <<ELSE>>
       $NULL$
     <<ENDIF>>

The implementation uses a nesting stack (16 levels deep, tracked
at ebp-0x6C as a DWORD array) and an ELSEIF pending table
(ebp-0x2B0).  The stack frame is 0xCB0 bytes — one of the
largest in the DLL.

This feature enables BBS scenes to conditionally emit different
RIPscrip command sequences based on terminal capabilities,
user preferences, or runtime state — without requiring the BBS
server to evaluate the conditions.


=====================================================================
==           INTERNAL DATA STRUCTURES (Binary Discovery)            ==
=====================================================================

The following struct definitions were reconstructed from field
access patterns in the disassembled RIPSCRIP.DLL binary.  These
are internal to the driver and were never published.  They are
documented here for implementors porting the rendering engine.

§S.1  RIPENGINE — Global Engine Singleton
------------------------------------------

Created by RIP_EngineCreate().  One per process.
Total size: 804 bytes.  Validation magic: 0x3FC9 at offset +0x00.

  Offset  Size  Type      Field             Notes
  ------  ----  --------  ----------------  ---------------------------
  +0x000  2     WORD      magic             0x3FC9 validation tag
  +0x002  4     HANDLE    hResFile          RIPSCRIP.RES resource file
  +0x00E  4     DWORD     nInstances        Active instance count
  +0x012  4     HWND      hWnd              Owner window handle
  +0x016  256   char[]    szDllPath         DLL install directory
  +0x116  256   char[]    szWorkPath        Temp path buffer
  +0x216  256   BYTE[]    defaultPalette    Default 16-color EGA palette
  +0x31A  2     WORD      maxBGIFontSize    Largest .CHR file size
  +0x31C  4     DWORD     dwInitParam       Host init parameter
  +0x320  4     DWORD     pUserData         Application-defined data


§S.2  RIPINST — Per-Session Instance Handle
---------------------------------------------

Created by RIP_InstanceCreate().  One per telnet session.
Total size: 128 bytes (handle block).  Magic: 0x9DF3 at +0x00.

  Offset  Size  Type      Field             Notes
  ------  ----  --------  ----------------  ---------------------------
  +0x00   2     WORD      magic             0x9DF3 validation tag
  +0x02   4     HANDLE    hResFile          Resource file (from engine)
  +0x06   4     PTR       pCallbackEntry    → CALLBACK_ENTRY (8 bytes)
  +0x0A   2     WORD      currentFontIndex  Active font slot (0xFFFF=none)
  +0x0E   4     PTR       pTextWindow       Current text window object
  +0x1A   2     WORD      screenWidth       Display width pixels
  +0x1C   2     WORD      screenHeight      Display height pixels
  +0x1E   4     PTR       pGraphicsState    Primary graphics state
  +0x22   4     PTR       pTextState        → TEXTSTATE
  +0x2C   4     PTR       pFontTable        Font table (0x61-byte entries)
  +0x32   4     PTR       pEventQueue       Event queue
  +0x36   4     PTR       pFileXfer         → FILETRANSFERSTATE
  +0x3A   4     PTR       pPenState         → PENSTATE (GDI)
  +0x40   1     BYTE      fontSizeFlag      Font size selection flag
  +0x46   4     PTR       pPaletteData      → PALETTEDATA
  +0x4E   4     PTR       pIconList         Icon/bitmap list
  +0x52   4     PTR       pCursorState      Cursor/caret state
  +0x5E   4     DWORD     isInitialized     1 after InitEx, 0 after UnInit
  +0x62   4     HDC       hDC               Rendering device context [PLATFORM]
  +0x66   4     HWND      hWnd              Session window handle [PLATFORM]
  +0x6A   4     HDC       hDCScreen         Screen DC [PLATFORM]
  +0x6E   4     DWORD     instanceNo        Instance number
  +0x72   4     PTR       pEngine           → RIPENGINE back-pointer
  +0x76   4     DWORD     busyFlag          Nonzero = processing
  +0x7A   2     WORD      sessionNumber     From INI, max 999
  +0x7C   4     DWORD     pUserData         Application-defined data

Fields marked [PLATFORM] are Windows-specific (HDC, HWND) and must
be replaced with platform-appropriate equivalents in portable
implementations (e.g., framebuffer pointer + dimensions).


§S.3  CALLBACK_ENTRY — Host Callback Indirection
--------------------------------------------------

8-byte structure at RIPINST+0x06.  Provides the indirection
between the engine and the host application's callback table.

  Offset  Size  Type      Field
  ------  ----  --------  ----------------
  +0x00   4     PTR       pState       → RIPSTATE (804 bytes)
  +0x04   4     PTR       callbacks    → FARPROC[75] (300 bytes)


§S.4  RIPSTATE — Full Instance Rendering State
------------------------------------------------

804 bytes.  Allocated by ripCallbackInit().  Contains all
per-session configuration flags and directory paths.

  Offset  Size  Type      Field             Default
  ------  ----  --------  ----------------  --------
  +0x180  128   char[]    szIconDir         "ICONS"
  +0x200  128   char[]    szFontDir         "FONTS"
  +0x300  1     BYTE      bRIPscripEmul     1
  +0x301  1     BYTE      bAnsiEmulation    1
  +0x302  1     BYTE      bVT102Emulation   1
  +0x303  1     BYTE      bBeepsAndBells    1
  +0x304  1     BYTE      bDefaultFontSize  2
  +0x308  1     BYTE      bDataSecurity     1
  +0x30A  1     BYTE      bBackspaceDel     1
  +0x30B  1     BYTE      bDestructiveBksp  1
  +0x30C  1     BYTE      bWordWrap         1
  +0x311  1     BYTE      bMousePresent     1
  +0x314  1     BYTE      bCursorAvail      1
  +0x315  1     BYTE      bUseExtKeyboard   1
  +0x317  1     BYTE      bExtAppSupported  1
  +0x31D  2     WORD      wScrollbackSizeK  40
  +0x31F  1     BYTE      bHalfDuplex       1
  +0x320  1     BYTE      bAddCrLf          0
  +0x322  1     BYTE      bCaptureANSI      0


§S.5  GFXSTYLE — Per-Port Drawing Attributes
----------------------------------------------

97 bytes (stride 0x61) per port.  36 entries in port table.
This is the complete drawing attribute set for each Drawing Port.

  Offset  Size  Type      Field             Default    Set By
  ------  ----  --------  ----------------  --------   ------
  +0x00   2     WORD      drawColor         0x0F       !|c
  +0x02   2     WORD      backColor         0x00       !|k
  +0x04   1     BYTE      lineStyle         0 (solid)  !|=
  +0x05   1     BYTE      lineThickness     1 (1px)    !|=
  +0x06   2     WORD      fillPattern       4 (solid)  !|s
  +0x08   1     BYTE      writeMode         0 (COPY)   !|S
  +0x09   1     BYTE      fontNumber        0 (8x8)    !|Y
  +0x0A   2     WORD      currentSlot       (cache)    internal
  +0x18   1     BYTE      fontSize          0          !|Y
  +0x1A   2     WORD      fillColor         0x0F       !|s
  +0x1C   1     BYTE      borderEnabled     0 (off)    !|N
  +0x1D   1     BYTE      colorMode         1          !|M
  +0x20   1     BYTE      fontDirection     0 (horiz)  !|Y
  +0x21   1     BYTE      fontSizeMult      0          !|Y
  +0x24   1     BYTE      fontHasMetrics    0/1        internal
  +0x26   1     BYTE      escActive         bit 0      ANSI
  +0x53   1     BYTE      fontAttribs       0          !|f

Font attribute bitmask (fontAttribs, set by !|f command):
  Bit 0 (0x01) — Bold
  Bit 1 (0x02) — Italic
  Bit 2 (0x04) — Underline
  Bit 3 (0x08) — Shadow


§S.6  TEXTSTATE — Viewport Geometry
-------------------------------------

Pointed to by RIPINST+0x22.

  Offset  Size  Type      Field
  ------  ----  --------  ----------------
  +0x00   4     PTR       portTableBase
  +0x08   2     WORD      activePortIndex
  +0x14   4     DWORD     screenWidthPx      default 639
  +0x18   4     DWORD     screenHeightPx     default 349
  +0x32   4     DWORD     viewLeft
  +0x36   4     DWORD     viewTop
  +0x3A   4     DWORD     viewRight
  +0x3E   4     DWORD     viewBottom
  +0x46   2     WORD      resolutionMode     0-4

NOTE: screenHeightPx defaults to 349 (EGA 640×350).  This
confirms that the native coordinate system is 640×350 even
in the v3.0 driver, regardless of the actual display resolution.


§S.7  PORT_ENTRY — Per-Port Record
------------------------------------

120 bytes (stride 0x78) per port.  36 slots (0-35).

  Offset  Size  Type      Field
  ------  ----  --------  ----------------
  +0x17   1     BYTE      flags (bit 0=protected, bit 1=fullscreen)
  +0x5C   2     WORD      cursorX
  +0x60   2     WORD      cursorY


§S.8  TEXT_WINDOW_ENTRY — Per-Window Record
---------------------------------------------

241 bytes (stride 0xF1) per text window.  36 slots.

  Offset  Size  Type      Field
  ------  ----  --------  ----------------
  +0x26   1     BYTE      flags (bit 0=escActive)
  +0x2A   1     BYTE      cursorCol
  +0x2B   1     BYTE      cursorRow
  +0x2E   2     WORD      attribute (bits 3:0=fg, 7:4=bg, 10:8=fontVariant)


=====================================================================
==           PROPRIETARY FILE FORMATS (Additional)                  ==
=====================================================================

Two additional proprietary file formats were identified but not
previously documented.

§F.1  RIPSCRIP.RES — Resource Archive
---------------------------------------

Size: 10,490 bytes.  Located in the DLL install directory.
Contains named resource entries used by the engine at startup.

File envelope: 0x04 + "TGRES" + 0x04 0x0A 0x0D 0x00 0x1A
(standard TeleGrafix file header).

Known entries:
  - "PALETTE" — default 16-color EGA palette (48 bytes: 16×RGB)
  - Additional entries referenced by sub_0647AB in RIP_EngineInit

The resource file is opened during RIP_EngineInit and its handle
stored at RIPINST+0x02 / RIPENGINE+0x02.


§F.2  RIPSCRIP.DB — Text Variable Database
--------------------------------------------

Size: 400 bytes.  Located in the DLL install directory.
Persists text variable definitions ($VARIABLE$) across sessions.

This is a simple key-value store used by the text variable
system (rip_textvars.c).  Variables defined via <<DEFINE>> or
RIP_DefineTextVariable() can be persisted here.


=====================================================================
==              IMPLEMENTATION NOTES (Binary Discovery)             ==
=====================================================================

§I.1  ripClipRect Is a NOP
----------------------------

The function ripClipRect at RVA 0x10034489 consists of a single
RET instruction.  It is called 74 times throughout the DLL as
"clip rectangle to display bounds."

This means the DLL performs NO software clipping — all clipping
is delegated to the GDI layer (Windows handles it via the DC
clip region).  Portable implementations MUST provide their own
clip rectangle enforcement since they lack GDI.

The drawing.c implementation in the the reference renderer card firmware handles
this via g_clip_x0/y0/x1/y1 in every draw primitive.


§I.2  VGA DAC Palette Conversion
----------------------------------

The function dibActivatePalette performs 8-bit RGB values to
6-bit VGA DAC register conversion via right-shift by 2:

     DAC_red   = RGB_red   >> 2
     DAC_green = RGB_green >> 2
     DAC_blue  = RGB_blue  >> 2

This confirms the color pipeline was designed for real VGA
hardware palette registers (6 bits per channel, 262,144 colors).
The the reference renderer card uses RGB565 (16-bit, 65,536 colors per entry)
which provides higher color fidelity than the original VGA DAC.


§I.3  Platform Dependencies in RIPSCRIP.DLL
---------------------------------------------

For portable implementations, the following Windows-specific
dependencies must be abstracted:

  Rendering (replace with framebuffer ops):
    - HDC / CreateCompatibleDC / SelectObject / BitBlt
    - CreateSolidBrush / CreatePen / DeleteObject
    - SetPixel / GetPixel / LineTo / MoveToEx
    - Rectangle / Ellipse / Polygon / Polyline / Chord
    - PatBlt / FillRect / FrameRect
    - CreateDIBSection / SetBitmapBits
    - SelectPalette / RealizePalette

  File I/O (replace with platform file API):
    - CreateFileA / ReadFile / WriteFile / CloseHandle
    - GetPrivateProfileStringA / GetPrivateProfileIntA
    - FindFirstFileA / FindNextFileA
    - GetTempPathA / GetTempFileNameA

  Memory (replace with platform allocator):
    - GlobalAlloc / GlobalFree / GlobalLock / GlobalUnlock
    - HeapAlloc / HeapFree (via CRT malloc/free)

  Window System (replace with event system):
    - SendMessageA / PostMessageA
    - GetDC / ReleaseDC
    - SetTimer / KillTimer
    - InvalidateRect / UpdateWindow

The 75-slot callback system (see HOST CALLBACK INTERFACE section)
already provides the primary abstraction layer.  Most platform
dependencies are concentrated in:
  - RIPINST fields +0x62 (hDC), +0x66 (hWnd), +0x6A (hDCScreen)
  - PALETTEDATA fields +0x82D (hPalette), +0x839 (hPaletteAlt)
  - PENSTATE (GDI pen handle at +0x08)

A portable implementation replaces these with:
  - Framebuffer pointer + pitch + dimensions
  - Palette array (16 or 256 entries, RGB565 or RGB888)
  - Software line/circle/fill primitives (as in drawing.c)


             ------------------------------------------
              End of RIPscrip v3.0 Reconstructed Supplement
             ------------------------------------------

                TeleGrafix Communications, Inc.
                   111 Weems Lane, Suite 308
                   Winchester, VA  22601-3600

          Voice: (540) 678-4050    WWW: http://www.telegrafix.com

             ------------------------------------------
     Reconstructed from binary analysis by the reference renderer project,
     March 2026.  Original software Copyright (c) 1993-1997
     TeleGrafix Communications, Inc.  All Rights Reserved.
             ------------------------------------------
