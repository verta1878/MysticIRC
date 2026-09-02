// ====================================================================
// mystic_rip : optional RIPscrip graphics example for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//

Unit rip_Canvas;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

// ====================================================================
// rip_canvas - TRipCanvas: the graphics render-target seam for RIPscrip.
//
// TTermAnsi renders to TOutput, a text-cell model.  RIP is graphics
// (vector primitives, pixels), so TTermRip cannot render to the text
// TOutput: it renders to THIS abstract class instead.  Backends
// implement it - the SDL2 software surface today (mystic_sdl/
// rip_surface.pas), BGI on 16-bit DOS or Lazarus/LCL later - without
// changing a line of RIP parsing logic.  This is the same pattern as
// TOutput's platform classes, one level up.
//
// Derived from the ripterm_client_v0 engine (IRipCanvas seam), the
// maintainer's clean-room RIP client, relicensed into this GPL tree.
// An abstract class is used instead of a COM interface so lifetime is
// plain Create/Free like everything else in MDL (no reference counts).
//
// REFERENCE CONTRACT (documentation, not code we call):
// RIPscrip 1.x assumes a Borland-BGI EGA canvas: 640 x 350 px, 16
// colors, non-square pixels.  Any backend must reproduce these facts
// to match original RIP output.  EGA 640x350 pixels are NOT square:
// to look right on a modern square-pixel display a backend either
// letterboxes or scales Y by ~1.37 (480/350).
// ====================================================================

Interface

Const
  RIP_WIDTH  = 640;    // BGI EGA hi-res width
  RIP_HEIGHT = 350;    // BGI EGA hi-res height

  // BGI write modes
  RIP_WM_COPY = 0;     // normal
  RIP_WM_XOR  = 1;     // RIP "write mode" 1 = XOR

Type
  TRipColor = 0..15;   // the 16 EGA colors, as RIP/BGI color indices

  TRipRGB = Record
    R, G, B : Byte;
  End;

Const
  // EGA default palette - the reference RGB for each RIP color index.
  // Any backend MUST map index -> this RGB to match original output.
  RIP_EGA_PALETTE : Array[0..15] of TRipRGB = (
    (R:$00; G:$00; B:$00),   // 0  black
    (R:$00; G:$00; B:$AA),   // 1  blue
    (R:$00; G:$AA; B:$00),   // 2  green
    (R:$00; G:$AA; B:$AA),   // 3  cyan
    (R:$AA; G:$00; B:$00),   // 4  red
    (R:$AA; G:$00; B:$AA),   // 5  magenta
    (R:$AA; G:$55; B:$00),   // 6  brown
    (R:$AA; G:$AA; B:$AA),   // 7  light gray
    (R:$55; G:$55; B:$55),   // 8  dark gray
    (R:$55; G:$55; B:$FF),   // 9  light blue
    (R:$55; G:$FF; B:$55),   // 10 light green
    (R:$55; G:$FF; B:$FF),   // 11 light cyan
    (R:$FF; G:$55; B:$55),   // 12 light red
    (R:$FF; G:$55; B:$FF),   // 13 light magenta
    (R:$FF; G:$FF; B:$55),   // 14 yellow
    (R:$FF; G:$FF; B:$FF)    // 15 white
  );

Type
  // A RIP mouse "hot region": a rectangle that, when clicked, sends
  // Text to the host as if typed (RIPscrip command 'M').
  TRipMouseRegion = Record
    X0, Y0     : Integer;
    X1, Y1     : Integer;
    Invert     : Boolean;      // <clk>: invert region while pressed
    ResetAfter : Boolean;      // <clr>: reset RIP state after click
    Text       : AnsiString;   // string sent to the host on click
  End;

  // The render-target abstraction.  All coordinates are RIP/BGI
  // 640x350 logical coordinates.  Pure abstract: backends override
  // everything; lifetime is ordinary Create/Free.
  TRipCanvas = Class
  Public
    // frame / lifecycle
    Procedure Clear; Virtual; Abstract;                       // erase to background
    Procedure Present; Virtual; Abstract;                     // flush frame to screen
    // state
    Procedure SetDrawColor (C: TRipColor); Virtual; Abstract; // RIP 'c'
    Procedure SetFillColor (C: TRipColor); Virtual; Abstract;
    Procedure SetWriteMode (M: Integer); Virtual; Abstract;   // RIP 'W'
    Procedure SetLineStyle (Style, Thickness: Integer); Virtual; Abstract; // RIP '='
    // primitives
    Procedure MoveTo (X, Y: Integer); Virtual; Abstract;      // RIP 'm'
    Procedure LineTo (X, Y: Integer); Virtual; Abstract;
    Procedure Pixel (X, Y: Integer; C: TRipColor); Virtual; Abstract;     // RIP 'X'
    Procedure Line (X0, Y0, X1, Y1: Integer); Virtual; Abstract;          // RIP 'L'
    Procedure Rectangle (X0, Y0, X1, Y1: Integer); Virtual; Abstract;     // RIP 'R'
    Procedure Bar (X0, Y0, X1, Y1: Integer); Virtual; Abstract;           // RIP 'B'
    Procedure Circle (X, Y, Radius: Integer); Virtual; Abstract;          // RIP 'C'
    Procedure Oval (X, Y, XRad, YRad: Integer); Virtual; Abstract;        // RIP 'O'
    Procedure FilledOval (X, Y, XRad, YRad: Integer); Virtual; Abstract;  // RIP 'o'
    Procedure FloodFill (X, Y: Integer; Border: TRipColor); Virtual; Abstract; // RIP 'F'
    Procedure WriteText (X, Y: Integer; Const S: AnsiString); Virtual; Abstract; // RIP '@'/'T'
    // arcs and curves
    Procedure Arc (X, Y, StAngle, EndAngle, Radius: Integer); Virtual; Abstract;
    Procedure OvalArc (X, Y, StAngle, EndAngle, XRad, YRad: Integer); Virtual; Abstract;
    Procedure PieSlice (X, Y, StAngle, EndAngle, Radius: Integer); Virtual; Abstract;
    Procedure OvalPieSlice (X, Y, StAngle, EndAngle, XRad, YRad: Integer); Virtual; Abstract;
    Procedure Bezier (X1, Y1, X2, Y2, X3, Y3, X4, Y4, Count: Integer); Virtual; Abstract;
    // polygons
    Procedure Polygon (Var Points; NumPoints: Integer); Virtual; Abstract;
    Procedure FillPolygon (Var Points; NumPoints: Integer); Virtual; Abstract;
    Procedure Polyline (Var Points; NumPoints: Integer); Virtual; Abstract;
    // style
    Procedure SetFillStyle (Pattern: Integer; Color: TRipColor); Virtual; Abstract;
    Procedure SetFillPattern (Var Pattern; Color: TRipColor); Virtual; Abstract;
    Procedure SetFontStyle (Font, Direction, Size: Integer); Virtual; Abstract;
    Procedure SetPalette (Var Pal); Virtual; Abstract;
    Procedure SetOnePalette (Color, EGA64: Integer); Virtual; Abstract;
    // viewport and windows
    Procedure SetViewPort (X0, Y0, X1, Y1: Integer; Clip: Boolean); Virtual; Abstract;
    Procedure TextWindow (X0, Y0, X1, Y1, Wrap: Integer); Virtual; Abstract;
    Procedure ResetWindows; Virtual; Abstract;
    Procedure GotoXY (X, Y: Integer); Virtual; Abstract;
    Procedure Home; Virtual; Abstract;
    Procedure EraseEOL; Virtual; Abstract;
    Procedure EraseWindow; Virtual; Abstract;
    Procedure EraseView; Virtual; Abstract;
    // clipboard and icons
    Procedure GetImage (X0, Y0, X1, Y1: Integer); Virtual; Abstract;
    Procedure PutImage (X, Y, Mode: Integer); Virtual; Abstract;
    Procedure WriteIcon (FileName: AnsiString); Virtual; Abstract;
    Procedure LoadIcon (X, Y: Integer; FileName: AnsiString); Virtual; Abstract;
    // buttons
    Procedure SetButtonStyle (Var Params); Virtual; Abstract;
    Procedure DrawButton (X0, Y0, X1, Y1: Integer; Const Params: AnsiString); Virtual; Abstract;
    // text blocks
    Procedure BeginText (X, Y, W, H: Integer); Virtual; Abstract;
    Procedure RegionText (Justify: Integer; Const S: AnsiString); Virtual; Abstract;
    Procedure EndText; Virtual; Abstract;
    // input regions
    Procedure AddMouseRegion (Const R: TRipMouseRegion); Virtual; Abstract;  // RIP 'M'
    Procedure KillMouseRegions; Virtual; Abstract;                           // RIP 'K'
  End;

Implementation

End.
