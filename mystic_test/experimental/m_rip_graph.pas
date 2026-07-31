// ====================================================================
// m_rip_graph.pas — MDL RIPscrip Graphics Layer (Experimental)
// ====================================================================
//
// Copyright (C) 1997-2013 James Coyle
// IRC Fork (C) 2025-2026 verta1878, sysop/0, evga, kiddo, wrench
// GPLv3
//
// CREDITS:
//   Arc, PieSlice, FilledPolygon, Bezier — ported from evga's ripdraw.pas
//   CHR vector font loader — ported from evga/wrench's ripscr.pas
//   (mystic_rip/v1/ripscr.pas — original Mystic RIP v1.54 engine)
//   ripdraw.pas primitives ported from RIPtermJS by Carl Gorringe
//   OOP wrapper and multi-backend architecture — kiddo
//
// ====================================================================
// PURPOSE:
//   Abstracted RIPscrip graphics backend for Mystic BBS.
//   Provides BGI-compatible drawing operations that output to:
//     - Memory buffer (all platforms, for BMP export / text-mode render)
//     - FPC Graph unit (DOS go32v2, live 640x350/640x480 VGA/VESA)
//     - Win32 GDI window (future)
//     - SDL2 surface (future, via mystic_sdl/)
//
// ====================================================================
// ARCHITECTURE:
//   This is the SHARED GRAPHICS LAYER. Everything that draws RIP
//   goes through this unit:
//
//     RIP command parser (rip1exec.pas / v2 / v3 / v4)
//       → m_rip_graph.pas (THIS UNIT — drawing operations)
//         → TRIPGraphBackend (output target)
//           → TRIPBackendBuffer  (memory pixel buffer)
//           → TRIPBackendGraph   (FPC Graph unit, DOS live)
//           → TRIPBackendWindow  (Win32/SDL2 window, future)
//
//   The RIP parser calls RIPGraph_Line, RIPGraph_Ellipse, etc.
//   This unit dispatches to the active backend.
//
// ====================================================================
// WHY BGI:
//   The RIP spec IS BGI. TeleGrafix built RIPscrip directly on top
//   of Borland's BGI library in 1992. Every RIP drawing command maps
//   1:1 to a BGI function call. FPC's Graph unit implements the same
//   BGI API. This unit preserves that 1:1 mapping.
//
//   RIP command  →  This unit      →  BGI equivalent
//   !|1L x y x y    RIPGraph_Line     Graph.Line(x1,y1,x2,y2)
//   !|1R x y x y    RIPGraph_Rect     Graph.Rectangle(x1,y1,x2,y2)
//   !|1c color       RIPGraph_SetColor Graph.SetColor(color)
//   !|1S style clr  RIPGraph_SetFill  Graph.SetFillStyle(style,clr)
//   !|1O cx cy r    RIPGraph_Circle   Graph.Circle(cx,cy,r)
//
// ====================================================================
// DEPENDENCIES:
//   - None for buffer backend (pure Pascal, no external libs)
//   - FPC Graph unit for DOS backend (in fpc264irc go32v2 target)
//   - Win32 API for future window backend
//   - SDL2 for future cross-platform backend
//
// ====================================================================
// CREDITS:
//   evga     — fpc264irc compiler, original ripviewer rendering
//   kiddo    — RIP command parser, BGI font rendering, chg2rip
//   sysop/0  — architecture decisions, DOS target
//   verta1878 — project lead, testing
//   wrench   — RIPtermJS reference analysis
//
// ====================================================================

{$MODE DELPHI}
{$H-}

Unit m_rip_graph;

Interface

Const
  // ================================================================
  // Canvas dimensions — standard RIP is 640x350 (EGA)
  // Can be overridden for VGA (640x480) or custom sizes
  // ================================================================
  RIP_DEFAULT_W = 640;
  RIP_DEFAULT_H = 350;
  RIP_MAX_W     = 1024;
  RIP_MAX_H     = 768;

  // CHR vector font limits
  RIP_MAX_CHR_CHARS  = 256;
  RIP_MAX_STROKES    = 9216;  // largest: GOTH = 8625 strokes

  // ================================================================
  // EGA 16-color palette — THE standard RIP palette
  // Index 0-15 maps to BGI colors, ANSI SGR, and EGA hardware.
  // Format: $00BBGGRR (little-endian RGB for BMP output)
  // ================================================================
  EGA_PALETTE : Array[0..15] Of LongWord = (
    $000000,   // 0  Black
    $AA0000,   // 1  Blue        (EGA: dark blue)
    $00AA00,   // 2  Green       (EGA: dark green)
    $AAAA00,   // 3  Cyan        (EGA: dark cyan)
    $0000AA,   // 4  Red         (EGA: dark red)
    $AA00AA,   // 5  Magenta     (EGA: dark magenta)
    $0055AA,   // 6  Brown       (EGA: brown/dark yellow)
    $AAAAAA,   // 7  Light Gray
    $555555,   // 8  Dark Gray
    $FF5555,   // 9  Light Blue
    $55FF55,   // 10 Light Green
    $FFFF55,   // 11 Light Cyan
    $5555FF,   // 12 Light Red
    $FF55FF,   // 13 Light Magenta
    $55FFFF,   // 14 Yellow
    $FFFFFF    // 15 White
  );

  // ================================================================
  // Fill styles — BGI compatible
  // ================================================================
  FILL_EMPTY    = 0;   // Background color fill
  FILL_SOLID    = 1;   // Solid fill
  FILL_LINE     = 2;   // Line fill ---
  FILL_LTSLASH  = 3;   // Light slash ///
  FILL_SLASH    = 4;   // Slash ///
  FILL_BKSLASH  = 5;   // Backslash \\\
  FILL_LTBKSLASH= 6;   // Light backslash \\\
  FILL_HATCH    = 7;   // Hatch +++
  FILL_XHATCH   = 8;   // Cross hatch XXX
  FILL_INTERLEAVE= 9;  // Interleave
  FILL_WIDEDOT  = 10;  // Wide dot
  FILL_CLOSEDOT = 11;  // Close dot
  FILL_USER     = 12;  // User-defined pattern

  // ================================================================
  // Line styles — BGI compatible
  // ================================================================
  LINE_SOLID    = 0;
  LINE_DOTTED   = 1;
  LINE_CENTER   = 2;
  LINE_DASHED   = 3;
  LINE_USER     = 4;

  // ================================================================
  // Write modes — BGI compatible
  // ================================================================
  WRITE_COPY    = 0;   // Overwrite
  WRITE_XOR     = 1;   // XOR with existing

  // ================================================================
  // Font numbers — BGI compatible
  // ================================================================
  FONT_DEFAULT  = 0;   // 8x8 bitmap
  FONT_TRIPLEX  = 1;
  FONT_SMALL    = 2;
  FONT_SANSSERIF= 3;
  FONT_GOTHIC   = 4;
  FONT_SCRIPT   = 5;
  FONT_SIMPLEX  = 6;
  FONT_TRIPLEX_S= 7;
  FONT_COMPLEX  = 8;
  FONT_EUROPEAN = 9;
  FONT_BOLD     = 10;

  // ================================================================
  // Backend types
  // ================================================================
  BACKEND_BUFFER = 0;  // Memory buffer (BMP export, all platforms)
  BACKEND_GRAPH  = 1;  // FPC Graph unit (DOS live display)
  BACKEND_WINDOW = 2;  // Win32/SDL2 window (future)

Type
  // ================================================================
  // Pixel buffer — the software framebuffer
  // 4-bit indexed color (0-15), one byte per pixel for speed.
  // 640x350 = 224,000 bytes. Fits in conventional DOS memory.
  // For XMS swapping, each page is exactly this size.
  // ================================================================
  PRIPPixelBuf = ^TRIPPixelBuf;
  TRIPPixelBuf = Array[0..RIP_MAX_W - 1, 0..RIP_MAX_H - 1] Of Byte;

  // ================================================================
  // CHR vector font — Borland BGI stroke font format
  // Ported from mystic_rip/v1/ripscr.pas TRIPCHRFont
  // 10 font slots (TRIP, SANS, GOTH, LITT, etc.)
  // ================================================================
  TRIPStroke = Record
    Op : Byte;      // 0=end of char, 1=move (pen up), 2=draw (pen down)
    X  : SmallInt;
    Y  : SmallInt;
  End;

  TRIPCHRFont = Record
    Loaded     : Boolean;
    Name       : String[4];
    FirstChar  : Byte;
    NumChars   : Word;
    OrgToCap   : SmallInt;   // top of capital letters
    OrgToBase  : SmallInt;   // baseline
    OrgToDec   : SmallInt;   // descender
    Widths     : Array[0..RIP_MAX_CHR_CHARS-1] Of Byte;
    Offsets    : Array[0..RIP_MAX_CHR_CHARS-1] Of Word;
    Strokes    : Array[0..RIP_MAX_STROKES-1] Of TRIPStroke;
    NumStrokes : Word;
  End;
  PRIPCHRFont = ^TRIPCHRFont;

  // ================================================================
  // Mouse region — clickable button area
  // ================================================================
  TRIPMouseRegion = Record
    Active   : Boolean;
    X1, Y1   : Word;
    X2, Y2   : Word;
    Hotkey   : Char;
    Flags    : Byte;
    Label_   : String[80];
  End;

  // ================================================================
  // Canvas state — BGI-compatible drawing context
  //
  // This is the HEART of the RIP rendering system.
  // Every drawing operation reads from this state.
  // RIP commands modify this state before drawing.
  // ================================================================
  TRIPCanvas = Record
    // Pixel storage
    Pixels     : PRIPPixelBuf;
    Width      : Word;
    Height     : Word;

    // Drawing state (BGI equivalent)
    FGColor    : Byte;       // Current drawing color (0-15)
    BGColor    : Byte;       // Background color (0-15)
    FillColor  : Byte;       // Fill color (0-15)
    FillStyle  : Byte;       // Fill pattern (FILL_xxx)
    LineStyle  : Byte;       // Line pattern (LINE_xxx)
    LineThick  : Word;       // Line thickness (1 or 3)
    WriteMode  : Byte;       // WRITE_COPY or WRITE_XOR

    // Cursor position
    CurX, CurY: Integer;

    // Viewport (clipping rectangle)
    ViewX1, ViewY1 : Integer;
    ViewX2, ViewY2 : Integer;

    // Text state
    FontNum    : Byte;       // BGI font index (FONT_xxx)
    FontDir    : Byte;       // 0=horizontal, 1=vertical
    FontSize   : Byte;       // Character magnification (1-10)

    // Palette (modifiable per session)
    Palette    : Array[0..15] Of LongWord;

    // Mouse regions (RIP buttons)
    MouseRegions : Array[0..63] Of TRIPMouseRegion;
    MouseCount   : Byte;
  End;

  // ================================================================
  // Backend type — where pixels actually go
  // ================================================================
  TRIPBackendType = (rbBuffer, rbGraph, rbWindow);

  // ================================================================
  // The main graphics object
  //
  // USAGE:
  //   Var G: TRIPGraphics;
  //   G := TRIPGraphics.Create(640, 350, rbBuffer);
  //   G.SetColor(14);
  //   G.Line(0, 0, 639, 349);
  //   G.SaveBMP('output.bmp');
  //   G.Free;
  //
  // FOR DOS LIVE DISPLAY:
  //   G := TRIPGraphics.Create(640, 350, rbGraph);
  //   // Now drawing goes directly to VGA screen
  //
  // ================================================================
  TRIPGraphics = Class
  Private
    FBackend    : TRIPBackendType;
    FGraphReady : Boolean;

    // Bresenham line (internal)
    Procedure DrawLineBresenham(X1, Y1, X2, Y2: Integer);

    // Ellipse helper (internal)
    Procedure DrawEllipsePoints(CX, CY, X, Y: Integer; Fill: Boolean);

    // Scanline fill (internal)
    Procedure ScanlineFill(CX, CY, XRad, YRad, StAngle, EndAngle: Integer);

  Public
    Canvas   : TRIPCanvas;
    CHRFonts : Array[1..10] Of PRIPCHRFont;  // BGI vector font slots

    // ============================================================
    // Lifecycle
    // ============================================================
    Constructor Create(W, H: Word; Backend: TRIPBackendType);
    Destructor  Destroy; Override;
    Procedure   Reset;

    // ============================================================
    // Pixel operations — the foundation
    // ============================================================
    Procedure PutPixel(X, Y: Integer; Color: Byte);
    Function  GetPixel(X, Y: Integer): Byte;

    // ============================================================
    // State management — BGI compatible
    // RIP commands call these to set drawing parameters
    // before issuing draw calls.
    // ============================================================
    Procedure SetColor(Color: Byte);         // !|1c
    Procedure SetBGColor(Color: Byte);
    Procedure SetFillStyle(Style, Color: Byte); // !|1S
    Procedure SetLineStyle(Style: Byte; Thick: Word); // !|1=
    Procedure SetWriteMode(Mode: Byte);      // !|1W
    Procedure SetFont(Font, Dir, Size: Byte); // !|1Y (partial)
    Procedure SetPalette(Index: Byte; R, G, B: Byte); // !|1Q
    Procedure SetViewport(X1, Y1, X2, Y2: Integer); // !|1w
    Procedure MoveTo(X, Y: Integer);         // !|1m

    // ============================================================
    // Drawing primitives — BGI compatible
    // Each maps 1:1 to a RIP command and BGI function.
    // ============================================================
    Procedure Line(X1, Y1, X2, Y2: Integer);         // !|1L
    Procedure Rectangle(X1, Y1, X2, Y2: Integer);    // !|1R
    Procedure FilledRect(X1, Y1, X2, Y2: Integer);   // !|1r (bar)
    Procedure Circle(CX, CY, Radius: Integer);       // !|1O
    Procedure Ellipse(CX, CY, XRad, YRad: Integer);  // !|1o (outline)
    Procedure FilledEllipse(CX, CY, XRad, YRad: Integer); // !|1O (filled)
    Procedure Arc(CX, CY, StAngle, EndAngle, Rad: Integer); // !|1A
    Procedure PieSlice(CX, CY, StAngle, EndAngle, Rad: Integer); // !|1I
    Procedure FloodFill(X, Y: Integer; Border: Byte); // !|1F
    Procedure Bezier(NumSeg: Integer; Var Pts: Array Of Integer); // !|1Z
    Procedure Polygon(NPts: Integer; Var Pts: Array Of Integer); // !|1P
    Procedure FilledPolygon(NPts: Integer; Var Pts: Array Of Integer); // !|1p

    // ============================================================
    // Text output — BGI font rendering
    // ============================================================
    Procedure OutText(X, Y: Integer; S: String);      // !|1T
    Procedure OutTextDefault(X, Y: Integer; S: String); // 8x8 bitmap font
    Function  LoadCHR(AFontNum: Byte; FileName: String): Boolean; // load .CHR
    Procedure DrawTextCHR(X, Y: SmallInt; S: String; AFont, ASize: Byte); // render CHR

    // ============================================================
    // Canvas operations
    // ============================================================
    Procedure ClearViewport;                 // !|1e
    Procedure ClearScreen;                   // !|1*
    Procedure ResetWindows;                  // !|1K (erasewindow+viewport reset)

    // ============================================================
    // Mouse regions — RIP buttons
    // ============================================================
    Procedure DefineRegion(X1, Y1, X2, Y2: Word;
                          Hotkey: Char; Flags: Byte;
                          Label_: String);           // !|1B
    Procedure ClearRegions;                          // !|1b
    Function  HitTest(MX, MY: Word): Integer;        // returns region index or -1

    // ============================================================
    // Output — export the canvas
    // ============================================================
    Procedure SaveBMP(FileName: String);
    Procedure CopyToGraph;   // Buffer → Graph unit (DOS screen update)

    // ============================================================
    // Graph unit control (DOS only)
    // ============================================================
    Procedure InitGraphMode;   // Open 640x350 or 640x480
    Procedure CloseGraphMode;  // Return to text mode
  End;

// ====================================================================
// API Documentation — Quick Reference
// ====================================================================
//
// INITIALIZATION:
//   G := TRIPGraphics.Create(640, 350, rbBuffer);  // memory only
//   G := TRIPGraphics.Create(640, 350, rbGraph);   // DOS live display
//   G.Reset;                                        // clear + reset state
//   G.Free;                                         // cleanup
//
// STATE:
//   G.SetColor(14);                     // drawing color = yellow
//   G.SetFillStyle(FILL_SOLID, 1);      // fill = solid blue
//   G.SetLineStyle(LINE_DASHED, 1);     // dashed lines
//   G.SetViewport(10, 10, 630, 340);    // clip rectangle
//   G.MoveTo(100, 100);                 // cursor position
//
// DRAWING:
//   G.Line(0, 0, 639, 349);            // line
//   G.Rectangle(10, 10, 100, 50);       // outline rect
//   G.FilledRect(10, 10, 100, 50);      // filled rect
//   G.Circle(320, 175, 50);             // circle
//   G.Ellipse(320, 175, 80, 40);        // ellipse outline
//   G.FilledEllipse(320, 175, 80, 40);  // filled ellipse
//   G.Arc(320, 175, 0, 180, 50);        // arc
//   G.PieSlice(320, 175, 0, 90, 50);    // pie slice
//   G.FloodFill(320, 175, 15);          // flood fill
//   G.OutText(10, 10, 'Hello');          // text output
//
// BUTTONS:
//   G.DefineRegion(10, 10, 100, 30, 'L', 0, 'Login');
//   Idx := G.HitTest(MouseX, MouseY);   // -1 = miss
//   If Idx >= 0 Then HandleButton(G.Canvas.MouseRegions[Idx]);
//
// OUTPUT:
//   G.SaveBMP('screen.bmp');            // export to BMP file
//   G.CopyToGraph;                      // push buffer to DOS screen
//
// ====================================================================

Implementation

Uses
  Math,
  {$IFDEF GO32V2}
  Graph,
  {$ENDIF}
  m_Strings;

// ====================================================================
// Constructor — allocate canvas and set defaults
// ====================================================================

Constructor TRIPGraphics.Create(W, H: Word; Backend: TRIPBackendType);
Begin
  Inherited Create;

  FBackend    := Backend;
  FGraphReady := False;

  Canvas.Width  := W;
  Canvas.Height := H;
  Canvas.MouseCount := 0;

  // Allocate pixel buffer (always, even for Graph backend —
  // we use it as a backing store for saves/restores)
  New(Canvas.Pixels);

  Reset;

  // If Graph backend requested, init graphics mode
  {$IFDEF GO32V2}
  If FBackend = rbGraph Then InitGraphMode;
  {$ENDIF}
End;

// ====================================================================
// Destructor — free resources, close graphics mode
// ====================================================================

Destructor TRIPGraphics.Destroy;
Var I: Integer;
Begin
  {$IFDEF GO32V2}
  If FGraphReady Then CloseGraphMode;
  {$ENDIF}

  If Canvas.Pixels <> Nil Then Dispose(Canvas.Pixels);

  { Free loaded CHR fonts }
  For I := 1 to 10 Do
    If CHRFonts[I] <> Nil Then Dispose(CHRFonts[I]);

  Inherited Destroy;
End;

// ====================================================================
// Reset — clear canvas and restore default BGI state
// ====================================================================

Procedure TRIPGraphics.Reset;
Begin
  FillChar(Canvas.Pixels^, SizeOf(TRIPPixelBuf), 0);

  Canvas.FGColor   := 15;   // White
  Canvas.BGColor   := 0;    // Black
  Canvas.FillColor := 0;
  Canvas.FillStyle := FILL_SOLID;
  Canvas.LineStyle := LINE_SOLID;
  Canvas.LineThick := 1;
  Canvas.WriteMode := WRITE_COPY;
  Canvas.CurX      := 0;
  Canvas.CurY      := 0;
  Canvas.ViewX1    := 0;
  Canvas.ViewY1    := 0;
  Canvas.ViewX2    := Canvas.Width - 1;
  Canvas.ViewY2    := Canvas.Height - 1;
  Canvas.FontNum   := FONT_DEFAULT;
  Canvas.FontDir   := 0;
  Canvas.FontSize  := 1;
  Canvas.MouseCount := 0;

  Move(EGA_PALETTE, Canvas.Palette, SizeOf(EGA_PALETTE));

  { Init CHR font slots to nil }
  CHRFonts[1] := Nil; CHRFonts[2] := Nil; CHRFonts[3] := Nil;
  CHRFonts[4] := Nil; CHRFonts[5] := Nil; CHRFonts[6] := Nil;
  CHRFonts[7] := Nil; CHRFonts[8] := Nil; CHRFonts[9] := Nil;
  CHRFonts[10] := Nil;
End;

// ====================================================================
// PutPixel — the foundation of all drawing
//
// Every drawing primitive eventually calls this.
// Clips to viewport. Respects write mode (COPY/XOR).
// Outputs to buffer and optionally to Graph unit.
// ====================================================================

Procedure TRIPGraphics.PutPixel(X, Y: Integer; Color: Byte);
Begin
  // Viewport clipping
  If (X < Canvas.ViewX1) Or (X > Canvas.ViewX2) Or
     (Y < Canvas.ViewY1) Or (Y > Canvas.ViewY2) Then Exit;

  // Bounds check
  If (X < 0) Or (X >= Canvas.Width) Or
     (Y < 0) Or (Y >= Canvas.Height) Then Exit;

  // Write mode
  If Canvas.WriteMode = WRITE_XOR Then
    Canvas.Pixels^[X, Y] := Canvas.Pixels^[X, Y] Xor (Color And 15)
  Else
    Canvas.Pixels^[X, Y] := Color And 15;

  // If Graph backend is active, also draw to screen
  {$IFDEF GO32V2}
  If FGraphReady Then
    Graph.PutPixel(X, Y, Color And 15);
  {$ENDIF}
End;

Function TRIPGraphics.GetPixel(X, Y: Integer): Byte;
Begin
  If (X >= 0) And (X < Canvas.Width) And
     (Y >= 0) And (Y < Canvas.Height) Then
    Result := Canvas.Pixels^[X, Y]
  Else
    Result := 0;
End;

// ====================================================================
// State management
// ====================================================================

Procedure TRIPGraphics.SetColor(Color: Byte);
Begin
  Canvas.FGColor := Color And 15;
  {$IFDEF GO32V2}
  If FGraphReady Then Graph.SetColor(Canvas.FGColor);
  {$ENDIF}
End;

Procedure TRIPGraphics.SetBGColor(Color: Byte);
Begin Canvas.BGColor := Color And 15; End;

Procedure TRIPGraphics.SetFillStyle(Style, Color: Byte);
Begin
  Canvas.FillStyle := Style;
  Canvas.FillColor := Color And 15;
  {$IFDEF GO32V2}
  If FGraphReady Then Graph.SetFillStyle(Style, Color And 15);
  {$ENDIF}
End;

Procedure TRIPGraphics.SetLineStyle(Style: Byte; Thick: Word);
Begin
  Canvas.LineStyle := Style;
  Canvas.LineThick := Thick;
  {$IFDEF GO32V2}
  If FGraphReady Then Graph.SetLineStyle(Style, 0, Thick);
  {$ENDIF}
End;

Procedure TRIPGraphics.SetWriteMode(Mode: Byte);
Begin
  Canvas.WriteMode := Mode;
  {$IFDEF GO32V2}
  If FGraphReady Then Graph.SetWriteMode(Mode);
  {$ENDIF}
End;

Procedure TRIPGraphics.SetFont(Font, Dir, Size: Byte);
Begin
  Canvas.FontNum := Font;
  Canvas.FontDir := Dir;
  Canvas.FontSize := Size;
End;

Procedure TRIPGraphics.SetPalette(Index: Byte; R, G, B: Byte);
Begin
  If Index <= 15 Then
    Canvas.Palette[Index] := LongWord(B) Shl 16 + LongWord(G) Shl 8 + R;
End;

Procedure TRIPGraphics.SetViewport(X1, Y1, X2, Y2: Integer);
Begin
  Canvas.ViewX1 := X1;
  Canvas.ViewY1 := Y1;
  Canvas.ViewX2 := X2;
  Canvas.ViewY2 := Y2;
  {$IFDEF GO32V2}
  If FGraphReady Then Graph.SetViewPort(X1, Y1, X2, Y2, True);
  {$ENDIF}
End;

Procedure TRIPGraphics.MoveTo(X, Y: Integer);
Begin
  Canvas.CurX := X;
  Canvas.CurY := Y;
End;

// ====================================================================
// Bresenham line — integer-only, no floating point
// ====================================================================

Procedure TRIPGraphics.DrawLineBresenham(X1, Y1, X2, Y2: Integer);
{ Phase 2: Now uses Canvas.LineStyle dash patterns and Canvas.LineThick }
Const
  DashPatterns : Array[0..4] Of Word = (
    $FFFF, $CCCC, $FC78, $F8F8, $FFFF
  );
Var
  DX, DY, SX, SY, Err, E2: Integer;
  Pattern: Word;
  BitPos, T: Integer;
Begin
  DX := Abs(X2 - X1);
  DY := Abs(Y2 - Y1);
  If X1 < X2 Then SX := 1 Else SX := -1;
  If Y1 < Y2 Then SY := 1 Else SY := -1;
  Err := DX - DY;
  BitPos := 0;

  If Canvas.LineStyle <= 4 Then
    Pattern := DashPatterns[Canvas.LineStyle]
  Else
    Pattern := $FFFF;

  While True Do Begin
    If (Pattern Shr (15 - (BitPos And 15))) And 1 = 1 Then Begin
      If Canvas.LineThick <= 1 Then
        PutPixel(X1, Y1, Canvas.FGColor)
      Else Begin
        For T := -(Canvas.LineThick Div 2) to (Canvas.LineThick Div 2) Do Begin
          If DX >= DY Then
            PutPixel(X1, Y1 + T, Canvas.FGColor)
          Else
            PutPixel(X1 + T, Y1, Canvas.FGColor);
        End;
      End;
    End;
    Inc(BitPos);
    If (X1 = X2) And (Y1 = Y2) Then Break;
    E2 := 2 * Err;
    If E2 > -DY Then Begin Dec(Err, DY); Inc(X1, SX); End;
    If E2 < DX Then Begin Inc(Err, DX); Inc(Y1, SY); End;
  End;
End;

// ====================================================================
// Drawing primitives
// ====================================================================

Procedure TRIPGraphics.Line(X1, Y1, X2, Y2: Integer);
Begin
  DrawLineBresenham(X1, Y1, X2, Y2);
  Canvas.CurX := X2;
  Canvas.CurY := Y2;
End;

Procedure TRIPGraphics.Rectangle(X1, Y1, X2, Y2: Integer);
Begin
  Line(X1, Y1, X2, Y1);
  Line(X2, Y1, X2, Y2);
  Line(X2, Y2, X1, Y2);
  Line(X1, Y2, X1, Y1);
End;

Procedure TRIPGraphics.FilledRect(X1, Y1, X2, Y2: Integer);
Var Y, X: Integer;
Begin
  For Y := Y1 to Y2 Do
    For X := X1 to X2 Do
      PutPixel(X, Y, Canvas.FillColor);
End;

Procedure TRIPGraphics.DrawEllipsePoints(CX, CY, X, Y: Integer; Fill: Boolean);
Begin
  If Fill Then Begin
    DrawLineBresenham(CX - X, CY + Y, CX + X, CY + Y);
    DrawLineBresenham(CX - X, CY - Y, CX + X, CY - Y);
  End Else Begin
    PutPixel(CX + X, CY + Y, Canvas.FGColor);
    PutPixel(CX - X, CY + Y, Canvas.FGColor);
    PutPixel(CX + X, CY - Y, Canvas.FGColor);
    PutPixel(CX - X, CY - Y, Canvas.FGColor);
  End;
End;

Procedure TRIPGraphics.Circle(CX, CY, Radius: Integer);
Begin Ellipse(CX, CY, Radius, Radius); End;

Procedure TRIPGraphics.Ellipse(CX, CY, XRad, YRad: Integer);
Var
  X, Y: Integer;
  XR2, YR2: LongInt;
  PX, PY, D1, D2: LongInt;
Begin
  X := 0; Y := YRad;
  XR2 := LongInt(XRad) * XRad;
  YR2 := LongInt(YRad) * YRad;
  PX := 0; PY := 2 * XR2 * Y;
  D1 := YR2 - XR2 * YRad + (XR2 Div 4);

  While PX < PY Do Begin
    DrawEllipsePoints(CX, CY, X, Y, False);
    Inc(X); Inc(PX, 2 * YR2);
    If D1 < 0 Then Inc(D1, YR2 + PX)
    Else Begin Dec(Y); Dec(PY, 2 * XR2); Inc(D1, YR2 + PX - PY); End;
  End;

  D2 := YR2 * LongInt(X * 2 + 1) * LongInt(X * 2 + 1) Div 4 +
        XR2 * LongInt(Y - 1) * LongInt(Y - 1) - XR2 * YR2;

  While Y >= 0 Do Begin
    DrawEllipsePoints(CX, CY, X, Y, False);
    Dec(Y); Dec(PY, 2 * XR2);
    If D2 > 0 Then Inc(D2, XR2 - PY)
    Else Begin Inc(X); Inc(PX, 2 * YR2); Inc(D2, XR2 - PY + PX); End;
  End;
End;

Procedure TRIPGraphics.FilledEllipse(CX, CY, XRad, YRad: Integer);
Var
  X, Y: Integer;
  XR2, YR2: LongInt;
  PX, PY, D1, D2: LongInt;
Begin
  X := 0; Y := YRad;
  XR2 := LongInt(XRad) * XRad;
  YR2 := LongInt(YRad) * YRad;
  PX := 0; PY := 2 * XR2 * Y;
  D1 := YR2 - XR2 * YRad + (XR2 Div 4);

  While PX < PY Do Begin
    DrawEllipsePoints(CX, CY, X, Y, True);
    Inc(X); Inc(PX, 2 * YR2);
    If D1 < 0 Then Inc(D1, YR2 + PX)
    Else Begin Dec(Y); Dec(PY, 2 * XR2); Inc(D1, YR2 + PX - PY); End;
  End;

  D2 := YR2 * LongInt(X * 2 + 1) * LongInt(X * 2 + 1) Div 4 +
        XR2 * LongInt(Y - 1) * LongInt(Y - 1) - XR2 * YR2;

  While Y >= 0 Do Begin
    DrawEllipsePoints(CX, CY, X, Y, True);
    Dec(Y); Dec(PY, 2 * XR2);
    If D2 > 0 Then Inc(D2, XR2 - PY)
    Else Begin Inc(X); Inc(PX, 2 * YR2); Inc(D2, XR2 - PY + PX); End;
  End;
End;

Procedure TRIPGraphics.Arc(CX, CY, StAngle, EndAngle, Rad: Integer);
{ Ported from ripdraw.pas DrawArcLines — proven pixel-perfect.
  Draws arc by stepping 1-degree increments, connecting with lines.
  Uses current FColor for drawing. Rad used for both X and Y radius. }
Var
  N, X1, Y1, X2, Y2: Integer;
  R: Double;
  EA: Integer;
Begin
  If StAngle = EndAngle Then Exit;
  EA := EndAngle;
  If StAngle > EA Then Inc(EA, 360);
  R := StAngle * Pi / 180.0;
  X1 := CX + Floor(Rad * Cos(R));
  Y1 := CY - Floor(Rad * Sin(R));
  For N := StAngle + 1 to EA Do Begin
    R := N * Pi / 180.0;
    X2 := CX + Floor(Rad * Cos(R));
    Y2 := CY - Floor(Rad * Sin(R));
    Line(X1, Y1, X2, Y2);
    X1 := X2; Y1 := Y2;
  End;
End;

Procedure TRIPGraphics.PieSlice(CX, CY, StAngle, EndAngle, Rad: Integer);
{ Ported from ripdraw.pas DrawSector — proven pixel-perfect.
  Draws arc, radial lines from center to arc endpoints, flood fills interior. }
Var
  R, HalfAngle: Double;
  X1, Y1, X2, Y2, FX, FY: Integer;
  SA, EA, EA2: Integer;
  OldFill: Byte;
Begin
  If StAngle = EndAngle Then Begin PutPixel(CX, CY, Canvas.FGColor); Exit; End;
  If Rad < 1 Then Rad := 1;
  SA := StAngle; EA := EndAngle;
  If SA > EA Then Begin X1 := SA; SA := EA; EA := X1; End;
  { Draw the arc outline }
  Arc(CX, CY, SA, EA, Rad);
  { Draw radial lines from center to arc endpoints }
  EA2 := EA Mod 360;
  R := SA * Pi / 180.0;
  X1 := CX + Floor(Rad * Cos(R));
  Y1 := CY - Floor(Rad * Sin(R));
  R := EA2 * Pi / 180.0;
  X2 := CX + Floor(Rad * Cos(R));
  Y2 := CY - Floor(Rad * Sin(R));
  Line(CX, CY, X1, Y1);
  Line(CX, CY, X2, Y2);
  { Flood fill at midpoint of sector }
  HalfAngle := (EA - SA) / 2.0 + SA;
  R := HalfAngle * Pi / 180.0;
  FX := Round(Rad * Cos(R) / 2.0 + CX);
  FY := Round(Rad * (-Sin(R)) / 2.0 + CY);
  OldFill := Canvas.FillColor;
  Canvas.FillColor := Canvas.FGColor;
  FloodFill(FX, FY, Canvas.FGColor);
  Canvas.FillColor := OldFill;
End;

Procedure TRIPGraphics.ScanlineFill(CX, CY, XRad, YRad, StAngle, EndAngle: Integer);
Begin
  { Sector fill handled by PieSlice via FloodFill.
    Polygon fill handled by FilledPolygon via scanline algorithm. }
End;

Procedure TRIPGraphics.FloodFill(X, Y: Integer; Border: Byte);
Var
  Stack  : Array[0..16383] Of Record SX, SY: Integer; End;
  SP     : Integer;
  OldCol : Byte;
Begin
  If (X < 0) Or (X >= Canvas.Width) Or (Y < 0) Or (Y >= Canvas.Height) Then Exit;

  OldCol := GetPixel(X, Y);
  If OldCol = Canvas.FillColor Then Exit;
  If OldCol = Border Then Exit;

  SP := 0;
  Stack[SP].SX := X;
  Stack[SP].SY := Y;
  Inc(SP);

  While SP > 0 Do Begin
    Dec(SP);
    X := Stack[SP].SX;
    Y := Stack[SP].SY;

    If (X < 0) Or (X >= Canvas.Width) Or (Y < 0) Or (Y >= Canvas.Height) Then Continue;
    If GetPixel(X, Y) <> OldCol Then Continue;

    PutPixel(X, Y, Canvas.FillColor);

    If SP < 16380 Then Begin
      Stack[SP].SX := X + 1; Stack[SP].SY := Y; Inc(SP);
      Stack[SP].SX := X - 1; Stack[SP].SY := Y; Inc(SP);
      Stack[SP].SX := X; Stack[SP].SY := Y + 1; Inc(SP);
      Stack[SP].SX := X; Stack[SP].SY := Y - 1; Inc(SP);
    End;
  End;
End;

Procedure TRIPGraphics.Bezier(NumSeg: Integer; Var Pts: Array Of Integer);
{ Ported from ripdraw.pas DrawBezier — proven pixel-perfect.
  Cubic Bezier curve: 4 control points (8 integers), NumSeg line segments. }
Var
  I: Integer;
  T, T2, T3, MT, MT2, MT3: Double;
  PX, PY, LX, LY: Integer;
Begin
  If NumSeg < 2 Then NumSeg := 20;
  LX := Pts[0]; LY := Pts[1];
  For I := 1 to NumSeg Do Begin
    T := I / NumSeg; MT := 1.0 - T;
    T2 := T * T; T3 := T2 * T;
    MT2 := MT * MT; MT3 := MT2 * MT;
    PX := Round(MT3*Pts[0] + 3*T*MT2*Pts[2] + 3*T2*MT*Pts[4] + T3*Pts[6]);
    PY := Round(MT3*Pts[1] + 3*T*MT2*Pts[3] + 3*T2*MT*Pts[5] + T3*Pts[7]);
    Line(LX, LY, PX, PY);
    LX := PX; LY := PY;
  End;
End;

Procedure TRIPGraphics.Polygon(NPts: Integer; Var Pts: Array Of Integer);
Var I: Integer;
Begin
  For I := 0 to NPts - 2 Do
    Line(Pts[I*2], Pts[I*2+1], Pts[I*2+2], Pts[I*2+3]);
  Line(Pts[(NPts-1)*2], Pts[(NPts-1)*2+1], Pts[0], Pts[1]);
End;

Procedure TRIPGraphics.FilledPolygon(NPts: Integer; Var Pts: Array Of Integer);
{ Ported from ripdraw.pas FillPolyScanline — proven pixel-perfect.
  Scanline fill algorithm: for each Y, find edge intersections,
  sort them, fill between pairs. }
Var
  Y, I, J, X, NodeCount: Integer;
  TX1, TY1, TX2, TY2: Integer;
  XVal, Tmp: Double;
  XNodes: Array[0..511] Of Double;
  X0, X1: Integer;
Begin
  { Draw outline first }
  Polygon(NPts, Pts);
  { Scanline fill }
  For Y := 0 to Canvas.Height - 1 Do Begin
    NodeCount := 0;
    J := NPts - 1;
    For I := 0 to NPts - 1 Do Begin
      TX1 := Pts[J * 2]; TY1 := Pts[J * 2 + 1];
      TX2 := Pts[I * 2]; TY2 := Pts[I * 2 + 1];
      If ((TY2 <= Y) And (TY1 > Y)) Or ((TY1 <= Y) And (TY2 > Y)) Then Begin
        If TY1 = TY2 Then XVal := TX2
        Else XVal := (Y - TY2) / (TY1 - TY2) * (TX1 - TX2) + TX2;
        If NodeCount < 512 Then Begin
          XNodes[NodeCount] := XVal; Inc(NodeCount);
        End;
      End;
      J := I;
    End;
    If NodeCount = 0 Then Continue;
    For I := 0 to NodeCount - 2 Do
      For J := I + 1 to NodeCount - 1 Do
        If XNodes[J] < XNodes[I] Then Begin
          Tmp := XNodes[I]; XNodes[I] := XNodes[J]; XNodes[J] := Tmp;
        End;
    I := 0;
    While I < NodeCount - 1 Do Begin
      X0 := Ceil(XNodes[I]); X1 := Floor(XNodes[I + 1]);
      For X := X0 to X1 Do PutPixel(X, Y, Canvas.FillColor);
      Inc(I, 2);
    End;
  End;
End;

// ====================================================================
// Text output — 8x8 default bitmap font
// ====================================================================

{$I rip_font8x8.inc}

Procedure TRIPGraphics.OutTextDefault(X, Y: Integer; S: String);
Var
  I, Row, Col: Integer;
  Ch: Byte;
  FontByte: Byte;
Begin
  For I := 1 to Length(S) Do Begin
    Ch := Ord(S[I]);
    For Row := 0 to 7 Do Begin
      FontByte := Font8x8[Ch * 8 + Row];
      For Col := 0 to 7 Do
        If (FontByte And ($80 Shr Col)) <> 0 Then
          PutPixel(X + (I - 1) * 8 + Col, Y + Row, Canvas.FGColor);
    End;
  End;
End;

Procedure TRIPGraphics.OutText(X, Y: Integer; S: String);
Begin
  { Use CHR vector font if loaded, else bitmap 8x8 }
  If (Canvas.FontNum >= 1) And (Canvas.FontNum <= 10) And
     (CHRFonts[Canvas.FontNum] <> Nil) And
     (CHRFonts[Canvas.FontNum]^.Loaded) Then
    DrawTextCHR(X, Y, S, Canvas.FontNum, Canvas.FontSize)
  Else
    OutTextDefault(X, Y, S);
End;

Function TRIPGraphics.LoadCHR(AFontNum: Byte; FileName: String): Boolean;
{ Load a Borland BGI .CHR stroked font file.
  Ported from mystic_rip/v1/ripscr.pas TRIPEngine.LoadCHR — g00r00's code.
  Format: ASCII header ending with 0x1A, then binary prefix header,
  then stroke data starting with '+' (0x2B) signature. }
Type
  TLoadBuf = Array[0..32767] Of Byte;
  PLoadBuf = ^TLoadBuf;
Var
  F        : File;
  Data     : PLoadBuf;
  FileLen  : LongInt;
  I, Pos   : Integer;
  PlusOff  : Integer;
  OtStart  : Integer;
  WtStart  : Integer;
  SkStart  : Integer;
  NC       : Word;
  FC       : Byte;
  B1, B2   : Byte;
  SX, SY   : SmallInt;
  Op       : Byte;
Begin
  Result := False;
  If (AFontNum < 1) Or (AFontNum > 10) Then Exit;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  New(Data);
  FileLen := FileSize(F);
  If FileLen > SizeOf(Data^) Then FileLen := SizeOf(Data^);
  BlockRead(F, Data^, FileLen);
  Close(F);

  { Find '+' signature (0x2B) — marks start of stroke data header }
  PlusOff := -1;
  For I := 80 to FileLen - 20 Do
    If Data^[I] = $2B Then Begin
      NC := Data^[I+1] Or (Data^[I+2] Shl 8);
      FC := Data^[I+4];
      If (NC >= 32) And (NC <= 256) And (FC >= 32) And (FC <= 127) Then Begin
        PlusOff := I;
        Break;
      End;
    End;

  If PlusOff < 0 Then Begin Dispose(Data); Exit; End;

  { Allocate font }
  If CHRFonts[AFontNum] <> Nil Then Dispose(CHRFonts[AFontNum]);
  New(CHRFonts[AFontNum]);

  With CHRFonts[AFontNum]^ Do Begin
    Loaded    := True;
    NumChars  := NC;
    FirstChar := FC;
    OrgToCap  := SmallInt(Data^[PlusOff + 8]);
    OrgToBase := SmallInt(Data^[PlusOff + 9]);
    OrgToDec  := SmallInt(Data^[PlusOff + 10]);
    Name      := '    ';

    { Offset table: NumChars * 2 bytes starting at PlusOff + 16 }
    OtStart := PlusOff + 16;
    For I := 0 to NumChars - 1 Do
      If I < RIP_MAX_CHR_CHARS Then
        Offsets[I] := Data^[OtStart + I*2] Or (Data^[OtStart + I*2 + 1] Shl 8);

    { Width table: NumChars bytes after offset table }
    WtStart := OtStart + NumChars * 2;
    For I := 0 to NumChars - 1 Do
      If I < RIP_MAX_CHR_CHARS Then
        Widths[I] := Data^[WtStart + I];

    { Stroke data starts after width table }
    SkStart := WtStart + NumChars;
    NumStrokes := 0;

    For I := 0 to NumChars - 1 Do Begin
      If I >= RIP_MAX_CHR_CHARS Then Break;
      Offsets[I] := NumStrokes;
      Pos := SkStart + (Data^[OtStart + I*2] Or (Data^[OtStart + I*2 + 1] Shl 8));

      Repeat
        If (Pos + 1 >= FileLen) Or (NumStrokes >= RIP_MAX_STROKES) Then Break;
        B1 := Data^[Pos];
        B2 := Data^[Pos + 1];
        SX := B1 And $7F;
        SY := B2 And $7F;
        If SX >= 64 Then SX := SX - 128;
        If SY >= 64 Then SY := SY - 128;

        If (B1 And $80 = 0) And (B2 And $80 = 0) Then
          Op := 0   { end of character }
        Else If (B2 And $80 = 0) Then
          Op := 1   { move to (pen up) }
        Else
          Op := 2;  { draw to (pen down) }

        Strokes[NumStrokes].Op := Op;
        Strokes[NumStrokes].X  := SX;
        Strokes[NumStrokes].Y  := SY;
        Inc(NumStrokes);
        Inc(Pos, 2);
      Until Op = 0;
    End;
  End;

  Dispose(Data);
  Result := True;
End;

Procedure TRIPGraphics.DrawTextCHR(X, Y: SmallInt; S: String; AFont, ASize: Byte);
{ Render text using a loaded CHR vector font.
  Ported from mystic_rip/v1/ripscr.pas TRIPEngine.DrawTextCHR. }
Var
  I, J       : Integer;
  CharIdx    : Integer;
  CX         : SmallInt;
  PenX, PenY : SmallInt;
  Scale      : SmallInt;
  StrokeOff  : Word;
Begin
  If (AFont < 1) Or (AFont > 10) Then Exit;
  If CHRFonts[AFont] = Nil Then Exit;
  If Not CHRFonts[AFont]^.Loaded Then Exit;

  If ASize = 0 Then ASize := 1;
  Scale := ASize;
  CX := X;

  With CHRFonts[AFont]^ Do Begin
    For I := 1 to Length(S) Do Begin
      CharIdx := Ord(S[I]) - FirstChar;
      If (CharIdx < 0) Or (CharIdx >= NumChars) Then Begin
        Inc(CX, 8 * Scale);
        Continue;
      End;

      StrokeOff := Offsets[CharIdx];
      PenX := CX;
      PenY := Y;

      J := StrokeOff;
      While J < NumStrokes Do Begin
        Case Strokes[J].Op Of
          0 : Break;  { end of character }
          1 : Begin    { move to }
                PenX := CX + Strokes[J].X * Scale;
                PenY := Y  - Strokes[J].Y * Scale;
              End;
          2 : Begin    { draw to }
                Line(PenX, PenY,
                     CX + Strokes[J].X * Scale,
                     Y  - Strokes[J].Y * Scale);
                PenX := CX + Strokes[J].X * Scale;
                PenY := Y  - Strokes[J].Y * Scale;
              End;
        End;
        Inc(J);
      End;

      Inc(CX, Widths[CharIdx] * Scale);
    End;
  End;

  Canvas.CurX := CX;
  Canvas.CurY := Y;
End;

// ====================================================================
// Canvas operations
// ====================================================================

Procedure TRIPGraphics.ClearViewport;
Var X, Y: Integer;
Begin
  For Y := Canvas.ViewY1 to Canvas.ViewY2 Do
    For X := Canvas.ViewX1 to Canvas.ViewX2 Do
      PutPixel(X, Y, Canvas.BGColor);
End;

Procedure TRIPGraphics.ClearScreen;
Begin
  FillChar(Canvas.Pixels^, SizeOf(TRIPPixelBuf), Canvas.BGColor);
  {$IFDEF GO32V2}
  If FGraphReady Then Graph.ClearDevice;
  {$ENDIF}
End;

Procedure TRIPGraphics.ResetWindows;
Begin
  Canvas.ViewX1 := 0; Canvas.ViewY1 := 0;
  Canvas.ViewX2 := Canvas.Width - 1;
  Canvas.ViewY2 := Canvas.Height - 1;
  ClearScreen;
End;

// ====================================================================
// Mouse regions — RIP buttons
// ====================================================================

Procedure TRIPGraphics.DefineRegion(X1, Y1, X2, Y2: Word;
                                    Hotkey: Char; Flags: Byte;
                                    Label_: String);
Begin
  If Canvas.MouseCount > 63 Then Exit;
  With Canvas.MouseRegions[Canvas.MouseCount] Do Begin
    Active := True;
    Self.Canvas.MouseRegions[Canvas.MouseCount].X1 := X1;
    Self.Canvas.MouseRegions[Canvas.MouseCount].Y1 := Y1;
    Self.Canvas.MouseRegions[Canvas.MouseCount].X2 := X2;
    Self.Canvas.MouseRegions[Canvas.MouseCount].Y2 := Y2;
    Self.Canvas.MouseRegions[Canvas.MouseCount].Hotkey := Hotkey;
    Self.Canvas.MouseRegions[Canvas.MouseCount].Flags := Flags;
    Self.Canvas.MouseRegions[Canvas.MouseCount].Label_ := Label_;
  End;
  Inc(Canvas.MouseCount);
End;

Procedure TRIPGraphics.ClearRegions;
Var I: Integer;
Begin
  For I := 0 to 63 Do Canvas.MouseRegions[I].Active := False;
  Canvas.MouseCount := 0;
End;

Function TRIPGraphics.HitTest(MX, MY: Word): Integer;
Var I: Integer;
Begin
  Result := -1;
  For I := Canvas.MouseCount - 1 DownTo 0 Do
    If Canvas.MouseRegions[I].Active Then
      If (MX >= Canvas.MouseRegions[I].X1) And (MX <= Canvas.MouseRegions[I].X2) And
         (MY >= Canvas.MouseRegions[I].Y1) And (MY <= Canvas.MouseRegions[I].Y2) Then Begin
        Result := I;
        Exit;
      End;
End;

// ====================================================================
// BMP export — same format as ripbmp.pas
// ====================================================================

Procedure TRIPGraphics.SaveBMP(FileName: String);
Var
  F: File;
  X, Y: Integer;
  Row: Array[0..2047] Of Byte;
  Pad, RowSize: Integer;
  FileSize, DataOfs: LongInt;
  W: Word;
  DW: LongWord;
Begin
  RowSize := ((Canvas.Width * 3 + 3) Div 4) * 4;
  Pad := RowSize - Canvas.Width * 3;
  DataOfs := 54;
  FileSize := DataOfs + LongInt(RowSize) * Canvas.Height;

  Assign(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  // BMP header
  BlockWrite(F, 'BM', 2);
  BlockWrite(F, FileSize, 4);
  DW := 0; BlockWrite(F, DW, 4);
  BlockWrite(F, DataOfs, 4);

  // DIB header
  DW := 40; BlockWrite(F, DW, 4);
  DW := Canvas.Width; BlockWrite(F, DW, 4);
  DW := Canvas.Height; BlockWrite(F, DW, 4);
  W := 1; BlockWrite(F, W, 2);
  W := 24; BlockWrite(F, W, 2);
  DW := 0; BlockWrite(F, DW, 4);
  DW := 0; BlockWrite(F, DW, 4);
  DW := 0; BlockWrite(F, DW, 4);
  DW := 0; BlockWrite(F, DW, 4);
  DW := 0; BlockWrite(F, DW, 4);
  DW := 0; BlockWrite(F, DW, 4);

  // Pixel data — bottom-up BGR
  For Y := Canvas.Height - 1 DownTo 0 Do Begin
    For X := 0 to Canvas.Width - 1 Do Begin
      DW := Canvas.Palette[Canvas.Pixels^[X, Y]];
      Row[X * 3]     := (DW Shr 16) And $FF;  // B
      Row[X * 3 + 1] := (DW Shr 8) And $FF;   // G
      Row[X * 3 + 2] := DW And $FF;            // R
    End;
    BlockWrite(F, Row, Canvas.Width * 3);
    If Pad > 0 Then Begin DW := 0; BlockWrite(F, DW, Pad); End;
  End;

  Close(F);
End;

// ====================================================================
// Graph unit interface (DOS only)
// ====================================================================

Procedure TRIPGraphics.InitGraphMode;
{$IFDEF GO32V2}
Var
  GD, GM: Integer;
Begin
  GD := EGA;          // or VGA for 640x480
  GM := EGAHi;        // 640x350x16
  InitGraph(GD, GM, '');
  If GraphResult <> GrOk Then Begin
    // Fallback to VGA
    GD := VGA; GM := VGAHi;
    InitGraph(GD, GM, '');
  End;
  FGraphReady := GraphResult = GrOk;
End;
{$ELSE}
Begin
  FGraphReady := False;
End;
{$ENDIF}

Procedure TRIPGraphics.CloseGraphMode;
Begin
  {$IFDEF GO32V2}
  If FGraphReady Then Graph.CloseGraph;
  {$ENDIF}
  FGraphReady := False;
End;

Procedure TRIPGraphics.CopyToGraph;
{$IFDEF GO32V2}
Var X, Y: Integer;
Begin
  If Not FGraphReady Then Exit;
  For Y := 0 to Canvas.Height - 1 Do
    For X := 0 to Canvas.Width - 1 Do
      Graph.PutPixel(X, Y, Canvas.Pixels^[X, Y]);
End;
{$ELSE}
Begin
End;
{$ENDIF}

End.
