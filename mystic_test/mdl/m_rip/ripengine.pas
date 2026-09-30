{$MODE DELPHI}
{$H-}
Unit RIPEngine;
{
  RIPView Engine - Canvas, palette, pixels, global state.
  Shared across all RIPscrip versions.

  This is the core state for evga's rendering engine. Every drawing
  primitive reads from and writes to the global Canvas record. The
  pixel buffer is a 2D array indexed by [X, Y] with 4-bit color
  indices (0-15) mapped through the EGA palette.

  CANVAS DIMENSIONS:
    RIP v1.54 uses EGA 640x350 (mode 10h). The canvas MUST be 640x350.
    DO NOT change RIP_HEIGHT to anything other than 350 for v1.54.

    BUG HISTORY (Session 6, Test Run 8):
      RIP_HEIGHT was set to 1280. This made the BMP output 640x1280
      instead of 640x350. When compared against 640x350 reference PNGs,
      98.9% of pixels were "wrong" because rows 350-1279 (all black)
      existed in our output but not in the reference. The dragon in
      DRAGON01 was actually rendering correctly in rows 0-349 but the
      file was 3.66x too tall. Every test file was affected.
      Visual diff images from sysop/0 made this immediately obvious.

  PALETTE FORMAT:
    Stored as $BBGGRR LongWords (Blue in high byte, Red in low byte).
    This is NOT standard RGB - it's reversed for BMP compatibility.
    EGA palette index 1 (Blue)  = $AA0000 (BB=$AA, GG=$00, RR=$00)
    EGA palette index 4 (Red)   = $0000AA (BB=$00, GG=$00, RR=$AA)
    The 8-bit BMP writer extracts: Shr 16 = Blue, Shr 8 = Green, And $FF = Red.

  PUTPIXEL:
    Foundation of all drawing. Clips to viewport bounds (ViewX1..ViewX2,
    ViewY1..ViewY2). All primitives in ripdraw.pas ultimately call this.
    Color is masked to 4 bits (And 15) to prevent buffer overflow.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
  RIPscrip engine ported from RIPtermJS by Carl Gorringe
}

Interface

Const
  VERSION    = '1.0.0';

  { Canvas dimensions - EGA 640x350 for RIP v1.54.
    DO NOT change to 1280 or any other value.
    See BUG HISTORY above for what happens when this is wrong. }
  RIP_WIDTH  = 640;
  RIP_HEIGHT = 350;

  { EGA 16-color palette in $BBGGRR format.
    VERIFIED against RIPtermJS BGI.js ega_palette (RGBA format).
    JS: [R, G, B, A] -> our $BBGGRR = (B shl 16) or (G shl 8) or R.

    BUG FIX (Session 6 Run 18): Indices 3(cyan) and 6(brown) were
    swapped. Index 9-14 had wrong values. Entire palette rebuilt
    from JS RGBA values.

    Index 0 = Black, 1 = Blue, 2 = Green, 3 = Cyan,
    4 = Red, 5 = Magenta, 6 = Brown, 7 = Light Gray,
    8 = Dark Gray, 9 = Light Blue, 10 = Light Green, 11 = Light Cyan,
    12 = Light Red, 13 = Light Magenta, 14 = Yellow, 15 = White. }
  EGA_PALETTE : Array[0..15] Of LongWord = (
    $000000,   {  0 Black:         R=00  G=00  B=00  }
    $AA0000,   {  1 Blue:          R=00  G=00  B=AA  }
    $00AA00,   {  2 Green:         R=00  G=AA  B=00  }
    $AAAA00,   {  3 Cyan:          R=00  G=AA  B=AA  }
    $0000AA,   {  4 Red:           R=AA  G=00  B=00  }
    $AA00AA,   {  5 Magenta:       R=AA  G=00  B=AA  }
    $0055AA,   {  6 Brown:         R=AA  G=55  B=00  }
    $AAAAAA,   {  7 Light Gray:    R=AA  G=AA  B=AA  }
    $555555,   {  8 Dark Gray:     R=55  G=55  B=55  }
    $FF5555,   {  9 Light Blue:    R=55  G=55  B=FF  }
    $55FF55,   { 10 Light Green:   R=55  G=FF  B=55  }
    $FFFF55,   { 11 Light Cyan:    R=55  G=FF  B=FF  }
    $5555FF,   { 12 Light Red:     R=FF  G=55  B=55  }
    $FF55FF,   { 13 Light Magenta: R=FF  G=55  B=FF  }
    $55FFFF,   { 14 Yellow:        R=FF  G=FF  B=55  }
    $FFFFFF    { 15 White:         R=FF  G=FF  B=FF  }
  );

Type
  { Pixel buffer - one byte per pixel, 4-bit color index (0-15).
    Indexed as [X, Y] where X = 0..639, Y = 0..349.
    Total size: 640 * 350 = 224,000 bytes.
    FillChar with 0 clears to black (palette index 0). }
  TPixelBuffer = Array[0..RIP_WIDTH-1, 0..RIP_HEIGHT-1] Of Byte;

  { Fill pattern - 8x8 bitmap for user-defined fill }
  TFillPattern = Array[0..7] Of Byte;

  { Text window state - bottom portion of RIP screen for text I/O }
  TTextWindow = Record
    X0, Y0, X1, Y1 : Integer;  { pixel bounds }
    FontW, FontH   : Integer;  { char cell size in pixels }
    Cols, Rows     : Integer;  { text grid dimensions }
    CurCol, CurRow : Integer;  { cursor position (0-based) }
    Attr           : Byte;     { current SGR→EGA text attribute }
    Wrap           : Boolean;  { line wrap enabled }
    Active         : Boolean;  { text window is open }
  End;

  { BGI canvas state - matches Borland Graphics Interface conventions.
    All drawing primitives read FG/FillColor/LineStyle from here.
    Viewport clips all PutPixel calls to ViewX1..ViewX2, ViewY1..ViewY2.
    Palette can be modified per-session by rcSetPalette/rcOnePalette. }
  TBGICanvas = Record
    Pixels     : ^TPixelBuffer;  { pixel buffer (heap allocated)          }
    FG         : Byte;           { foreground color index (0-15)          }
    BG         : Byte;           { background color index (0-15)          }
    FillColor  : Byte;           { flood fill color (0-15)                }
    FillStyle  : Byte;           { fill pattern (0=empty, 1=solid, etc)   }
    FillPat    : TFillPattern;   { user-defined fill pattern              }
    LineStyle  : Byte;           { line dash pattern (0=solid, 1=dotted)  }
    LinePattern: Word;           { 16-bit line pattern for user style     }
    LineThick  : Integer;        { line thickness in pixels (1 or 3)      }
    WriteMode  : Byte;           { 0=COPY (overwrite), 1=XOR             }
    CurX, CurY: Integer;        { current cursor position (text output)  }
    ViewX1, ViewY1: Integer;     { viewport top-left (clip region)        }
    ViewX2, ViewY2: Integer;     { viewport bottom-right (clip region)    }
    ViewClip   : Boolean;        { viewport clipping enabled              }
    Palette    : Array[0..15] Of LongWord; { current session palette      }
    FontNum    : Byte;           { current font (0=default 8x16 bitmap)   }
    FontDir    : Byte;           { text direction (0=horiz, 1=vert)       }
    FontSize   : Byte;           { text size multiplier                   }
    TextJustH  : Byte;           { horizontal justify (0=left,1=ctr,2=rt) }
    TextJustV  : Byte;           { vertical justify (0=bottom,1=ctr,2=top)}
    TextWin    : TTextWindow;    { RIP text window state                  }
    InGraphics : Boolean;        { true when graphics mode is active      }
  End;

Var
  Canvas    : TBGICanvas;        { global canvas state - all units use this }
  DebugMode : Boolean = False;   { print command names during rendering     }
  BaudRate  : LongInt = 0;       { simulated baud rate (0 = no delay)       }
  BaudDelay : LongInt = 0;       { microseconds per byte at current baud    }

Procedure InitCanvas;
Procedure PutPixel(X, Y: Integer; Color: Byte);
Function GetPixel(X, Y: Integer): Byte;

{ Color/attribute state }
Procedure SetColor(Color: Byte);
Function  GetColor: Byte;
Procedure SetBkColor(Color: Byte);
Function  GetBkColor: Byte;

{ Cursor movement }
Procedure MoveTo(X, Y: Integer);
Procedure MoveRel(DX, DY: Integer);
Function  GetX: Integer;
Function  GetY: Integer;

{ Fill state }
Procedure SetFillStyle(Style: Word; Color: Byte);
Procedure SetFillPattern(Var Pattern: TFillPattern; Color: Byte);
Procedure GetFillSettings(Var Style: Byte; Var Color: Byte);

{ Line state }
Procedure SetLineStyle(Style: Byte; Pattern: Word; Thick: Integer);
Procedure GetLineSettings(Var Style: Byte; Var Pattern: Word; Var Thick: Integer);

{ Write mode }
Procedure SetWriteMode(Mode: Byte);
Function  GetWriteMode: Byte;

{ Text }
Procedure SetTextJustify(Horiz, Vert: Byte);

{ Viewport }
Procedure SetViewPort(X0, Y0, X1, Y1: Integer; Clip: Boolean);
Procedure GetViewPort(Var X0, Y0, X1, Y1: Integer);
Procedure ResetViewPort;
Function  ClipX(X: Integer): Integer;
Function  ClipY(Y: Integer): Integer;
Function  InView(X, Y: Integer): Boolean;
Procedure CopyRegion(SrcX, SrcY, W, H, DstX, DstY: Integer);

{ Viewport stack — nested viewports, matched to RIPterm RIPVIEW.C }
Procedure ViewPortPush;
Procedure ViewPortPop;
Function  ViewPortDepth: Integer;

{ Line clipping — Cohen-Sutherland, matched to RIPterm rip_clip_line }
Function  ClipLine(Var X1, Y1, X2, Y2: Integer): Boolean;

{ Coordinate transforms — RIP↔screen for VGA scaling }
Procedure RIPToScreen(RX, RY: Integer; Var SX, SY: Integer);
Procedure ScreenToRIP(SX, SY: Integer; Var RX, RY: Integer);

{ Full state reset }
Procedure ResetRIPState;

{ Text window — bottom of RIP screen for text I/O }
Procedure SetTextWindow(X0, Y0, X1, Y1: Integer; FontH: Byte);
Procedure ResetTextWin;
Procedure TextWinPutChar(Ch: Byte);
Procedure TextWinWrite(Const S: String);
Procedure TextWinScroll(Direction: Integer);
Procedure ProcessTextAnsi(Const S: String);

{ System font info }
Function  GetSysFontW: Integer;
Function  GetSysFontH: Integer;
Function  GetSysCols: Integer;
Function  GetSysRows: Integer;

{ Graphics mode }
Procedure EnterGraphics;
Procedure ExitGraphics;

Const
  { Default system font dimensions }
  SYS_FONT_W = 8;
  SYS_FONT_H = 8;

  { SGR color → EGA attribute mapping }
  TW_SGR_TO_EGA : Array[0..7] Of Byte = (0, 4, 2, 6, 1, 5, 3, 7);

Implementation

Procedure InitCanvas;
Begin
  New(Canvas.Pixels);
  FillChar(Canvas.Pixels^, SizeOf(TPixelBuffer), 0);
  Canvas.FG := 15;
  Canvas.BG := 0;
  Canvas.FillColor := 0;
  Canvas.FillStyle := 1;
  FillChar(Canvas.FillPat, SizeOf(TFillPattern), $FF);
  Canvas.LineStyle := 0;
  Canvas.LinePattern := $FFFF;
  Canvas.LineThick := 1;
  Canvas.WriteMode := 0;
  Canvas.CurX := 0;
  Canvas.CurY := 0;
  Canvas.ViewX1 := 0;
  Canvas.ViewY1 := 0;
  Canvas.ViewX2 := RIP_WIDTH - 1;
  Canvas.ViewY2 := RIP_HEIGHT - 1;
  Canvas.ViewClip := True;
  Canvas.FontNum := 0;
  Canvas.FontDir := 0;
  Canvas.FontSize := 1;
  Canvas.TextJustH := 0;
  Canvas.TextJustV := 0;
  Canvas.InGraphics := False;
  Move(EGA_PALETTE, Canvas.Palette, SizeOf(EGA_PALETTE));
  { Text window defaults }
  Canvas.TextWin.Active := False;
  Canvas.TextWin.X0 := 0;
  Canvas.TextWin.Y0 := RIP_HEIGHT - (4 * SYS_FONT_H);
  Canvas.TextWin.X1 := RIP_WIDTH - 1;
  Canvas.TextWin.Y1 := RIP_HEIGHT - 1;
  Canvas.TextWin.FontW := SYS_FONT_W;
  Canvas.TextWin.FontH := SYS_FONT_H;
  Canvas.TextWin.Cols := RIP_WIDTH Div SYS_FONT_W;
  Canvas.TextWin.Rows := 4;
  Canvas.TextWin.CurCol := 0;
  Canvas.TextWin.CurRow := 0;
  Canvas.TextWin.Attr := 7;
  Canvas.TextWin.Wrap := True;
End;

Procedure PutPixel(X, Y: Integer; Color: Byte);
Var AX, AY: Integer;
Begin
  AX := X + Canvas.ViewX1;
  AY := Y + Canvas.ViewY1;
  If (AX >= Canvas.ViewX1) And (AX <= Canvas.ViewX2) And
     (AY >= Canvas.ViewY1) And (AY <= Canvas.ViewY2) Then
    Canvas.Pixels^[AX, AY] := Color And 15;
End;

Function GetPixel(X, Y: Integer): Byte;
Var AX, AY: Integer;
Begin
  AX := X + Canvas.ViewX1;
  AY := Y + Canvas.ViewY1;
  If (AX >= 0) And (AX < RIP_WIDTH) And (AY >= 0) And (AY < RIP_HEIGHT) Then
    Result := Canvas.Pixels^[AX, AY]
  Else
    Result := 0;
End;

{ ---- Color/attribute state ---- }

Procedure SetColor(Color: Byte);
Begin Canvas.FG := Color And 15; End;

Function GetColor: Byte;
Begin Result := Canvas.FG; End;

Procedure SetBkColor(Color: Byte);
Begin Canvas.BG := Color And 15; End;

Function GetBkColor: Byte;
Begin Result := Canvas.BG; End;

{ ---- Cursor movement ---- }

Procedure MoveTo(X, Y: Integer);
Begin Canvas.CurX := X; Canvas.CurY := Y; End;

Procedure MoveRel(DX, DY: Integer);
Begin Inc(Canvas.CurX, DX); Inc(Canvas.CurY, DY); End;

Function GetX: Integer;
Begin Result := Canvas.CurX; End;

Function GetY: Integer;
Begin Result := Canvas.CurY; End;

{ ---- Fill state ---- }

Procedure SetFillStyle(Style: Word; Color: Byte);
Begin
  Canvas.FillStyle := Style And $FF;
  Canvas.FillColor := Color And 15;
End;

Procedure SetFillPattern(Var Pattern: TFillPattern; Color: Byte);
Begin
  Move(Pattern, Canvas.FillPat, SizeOf(TFillPattern));
  Canvas.FillColor := Color And 15;
  Canvas.FillStyle := 12; { user-defined }
End;

Procedure GetFillSettings(Var Style: Byte; Var Color: Byte);
Begin
  Style := Canvas.FillStyle;
  Color := Canvas.FillColor;
End;

{ ---- Line state ---- }

Procedure SetLineStyle(Style: Byte; Pattern: Word; Thick: Integer);
Begin
  Canvas.LineStyle := Style;
  Canvas.LinePattern := Pattern;
  Canvas.LineThick := Thick;
End;

Procedure GetLineSettings(Var Style: Byte; Var Pattern: Word; Var Thick: Integer);
Begin
  Style := Canvas.LineStyle;
  Pattern := Canvas.LinePattern;
  Thick := Canvas.LineThick;
End;

{ ---- Write mode ---- }

Procedure SetWriteMode(Mode: Byte);
Begin Canvas.WriteMode := Mode; End;

Function GetWriteMode: Byte;
Begin Result := Canvas.WriteMode; End;

{ ---- Text ---- }

Procedure SetTextJustify(Horiz, Vert: Byte);
Begin
  Canvas.TextJustH := Horiz;
  Canvas.TextJustV := Vert;
End;

{ ---- Viewport ---- }

Procedure SetViewPort(X0, Y0, X1, Y1: Integer; Clip: Boolean);
Begin
  If X0 < 0 Then X0 := 0;
  If Y0 < 0 Then Y0 := 0;
  If X1 >= RIP_WIDTH Then X1 := RIP_WIDTH - 1;
  If Y1 >= RIP_HEIGHT Then Y1 := RIP_HEIGHT - 1;
  Canvas.ViewX1 := X0;
  Canvas.ViewY1 := Y0;
  Canvas.ViewX2 := X1;
  Canvas.ViewY2 := Y1;
  Canvas.ViewClip := Clip;
  Canvas.CurX := 0;
  Canvas.CurY := 0;
End;

Procedure GetViewPort(Var X0, Y0, X1, Y1: Integer);
Begin
  X0 := Canvas.ViewX1; Y0 := Canvas.ViewY1;
  X1 := Canvas.ViewX2; Y1 := Canvas.ViewY2;
End;

Procedure ResetViewPort;
Begin
  SetViewPort(0, 0, RIP_WIDTH - 1, RIP_HEIGHT - 1, True);
End;

Function ClipX(X: Integer): Integer;
Begin
  If X < Canvas.ViewX1 Then Result := Canvas.ViewX1
  Else If X > Canvas.ViewX2 Then Result := Canvas.ViewX2
  Else Result := X;
End;

Function ClipY(Y: Integer): Integer;
Begin
  If Y < Canvas.ViewY1 Then Result := Canvas.ViewY1
  Else If Y > Canvas.ViewY2 Then Result := Canvas.ViewY2
  Else Result := Y;
End;

Function InView(X, Y: Integer): Boolean;
Begin
  Result := (X >= Canvas.ViewX1) And (X <= Canvas.ViewX2) And
            (Y >= Canvas.ViewY1) And (Y <= Canvas.ViewY2);
End;

Procedure CopyRegion(SrcX, SrcY, W, H, DstX, DstY: Integer);
Var X, Y: Integer;
Begin
  For Y := 0 To H - 1 Do
    For X := 0 To W - 1 Do
      If InView(SrcX + X, SrcY + Y) And InView(DstX + X, DstY + Y) Then
        Canvas.Pixels^[DstX + X, DstY + Y] := Canvas.Pixels^[SrcX + X, SrcY + Y];
End;

{ ---- Viewport stack — 8 levels, matched to RIPterm RIPVIEW.C ---- }

Const
  MAX_VP_STACK = 8;

Type
  TVPEntry = Record
    X1, Y1, X2, Y2: Integer;
    Clip: Boolean;
  End;

Var
  VPStack: Array[0..MAX_VP_STACK - 1] Of TVPEntry;
  VPSP: Integer = 0;

Procedure ViewPortPush;
Begin
  If VPSP >= MAX_VP_STACK Then Exit;
  VPStack[VPSP].X1 := Canvas.ViewX1;
  VPStack[VPSP].Y1 := Canvas.ViewY1;
  VPStack[VPSP].X2 := Canvas.ViewX2;
  VPStack[VPSP].Y2 := Canvas.ViewY2;
  VPStack[VPSP].Clip := Canvas.ViewClip;
  Inc(VPSP);
End;

Procedure ViewPortPop;
Begin
  If VPSP <= 0 Then Exit;
  Dec(VPSP);
  SetViewPort(VPStack[VPSP].X1, VPStack[VPSP].Y1,
              VPStack[VPSP].X2, VPStack[VPSP].Y2,
              VPStack[VPSP].Clip);
End;

Function ViewPortDepth: Integer;
Begin
  Result := VPSP;
End;

{ ---- Cohen-Sutherland line clipping — matched to RIPterm rip_clip_line ---- }

Function ClipLine(Var X1, Y1, X2, Y2: Integer): Boolean;
Const
  INSIDE = 0; LEFT = 1; RIGHT = 2; BOTTOM = 4; TOP = 8;

  Function ComputeCode(X, Y: Integer): Integer;
  Begin
    Result := INSIDE;
    If X < Canvas.ViewX1 Then Result := Result Or LEFT
    Else If X > Canvas.ViewX2 Then Result := Result Or RIGHT;
    If Y < Canvas.ViewY1 Then Result := Result Or TOP
    Else If Y > Canvas.ViewY2 Then Result := Result Or BOTTOM;
  End;

Var
  Code1, Code2, CodeOut: Integer;
  X, Y: Integer;
Begin
  Code1 := ComputeCode(X1, Y1);
  Code2 := ComputeCode(X2, Y2);
  Result := False;

  While True Do Begin
    If (Code1 Or Code2) = 0 Then Begin
      Result := True; Exit; { Both inside }
    End;
    If (Code1 And Code2) <> 0 Then Exit; { Both outside same edge }

    If Code1 <> 0 Then CodeOut := Code1
    Else CodeOut := Code2;

    If (CodeOut And TOP) <> 0 Then Begin
      X := X1 + LongInt(X2 - X1) * (Canvas.ViewY1 - Y1) Div (Y2 - Y1);
      Y := Canvas.ViewY1;
    End Else If (CodeOut And BOTTOM) <> 0 Then Begin
      X := X1 + LongInt(X2 - X1) * (Canvas.ViewY2 - Y1) Div (Y2 - Y1);
      Y := Canvas.ViewY2;
    End Else If (CodeOut And RIGHT) <> 0 Then Begin
      Y := Y1 + LongInt(Y2 - Y1) * (Canvas.ViewX2 - X1) Div (X2 - X1);
      X := Canvas.ViewX2;
    End Else Begin
      Y := Y1 + LongInt(Y2 - Y1) * (Canvas.ViewX1 - X1) Div (X2 - X1);
      X := Canvas.ViewX1;
    End;

    If CodeOut = Code1 Then Begin
      X1 := X; Y1 := Y;
      Code1 := ComputeCode(X1, Y1);
    End Else Begin
      X2 := X; Y2 := Y;
      Code2 := ComputeCode(X2, Y2);
    End;
  End;
End;

{ ---- Coordinate transforms — RIP↔screen ---- }

Procedure RIPToScreen(RX, RY: Integer; Var SX, SY: Integer);
{ Transform RIP 640x350 coordinates to screen coordinates.
  Currently 1:1 (EGA mode). When VGA 640x480 is added, scales Y. }
Begin
  SX := RX;
  SY := RY;
  { VGA scaling would be: SY := LongInt(RY) * 480 Div 350; }
End;

Procedure ScreenToRIP(SX, SY: Integer; Var RX, RY: Integer);
Begin
  RX := SX;
  RY := SY;
  { VGA scaling would be: RY := LongInt(SY) * 350 Div 480; }
End;

{ ---- Full state reset — matched to RIPterm rip_reset_state ---- }

Procedure ResetRIPState;
Begin
  VPSP := 0;
  ResetViewPort;
  SetColor(15);
  SetBkColor(0);
  SetFillStyle(1, 15);
  SetLineStyle(0, $FFFF, 1);
  SetWriteMode(0);
  SetTextJustify(0, 0);
  Canvas.FontNum := 0;
  Canvas.FontDir := 0;
  Canvas.FontSize := 1;
  Move(EGA_PALETTE, Canvas.Palette, SizeOf(EGA_PALETTE));
  FillChar(Canvas.Pixels^, SizeOf(TPixelBuffer), 0);
  ResetTextWin;
End;

Procedure SetTextWindow(X0, Y0, X1, Y1: Integer; FontH: Byte);
Begin
  Canvas.TextWin.X0 := X0;
  Canvas.TextWin.Y0 := Y0;
  Canvas.TextWin.X1 := X1;
  Canvas.TextWin.Y1 := Y1;
  If FontH = 0 Then FontH := SYS_FONT_H;
  Canvas.TextWin.FontH := FontH;
  Canvas.TextWin.FontW := SYS_FONT_W;
  Canvas.TextWin.Cols := (X1 - X0 + 1) Div Canvas.TextWin.FontW;
  Canvas.TextWin.Rows := (Y1 - Y0 + 1) Div Canvas.TextWin.FontH;
  Canvas.TextWin.CurCol := 0;
  Canvas.TextWin.CurRow := 0;
  Canvas.TextWin.Attr := 7;
  Canvas.TextWin.Active := True;
End;

Procedure ResetTextWin;
Begin
  Canvas.TextWin.Active := False;
  Canvas.TextWin.CurCol := 0;
  Canvas.TextWin.CurRow := 0;
  Canvas.TextWin.Attr := 7;
End;

Procedure TextWinScroll(Direction: Integer);
{ Scroll text window pixels up (Direction>0) or down (Direction<0) }
Var X, Y, SrcY, LineH: Integer;
Begin
  If Not Canvas.TextWin.Active Then Exit;
  LineH := Canvas.TextWin.FontH;
  If Direction > 0 Then Begin
    { Scroll up — copy rows up by LineH pixels }
    For Y := Canvas.TextWin.Y0 To Canvas.TextWin.Y1 - LineH Do
      For X := Canvas.TextWin.X0 To Canvas.TextWin.X1 Do Begin
        SrcY := Y + LineH;
        If SrcY <= Canvas.TextWin.Y1 Then
          Canvas.Pixels^[X, Y] := Canvas.Pixels^[X, SrcY];
      End;
    { Clear bottom line }
    For Y := Canvas.TextWin.Y1 - LineH + 1 To Canvas.TextWin.Y1 Do
      For X := Canvas.TextWin.X0 To Canvas.TextWin.X1 Do
        Canvas.Pixels^[X, Y] := Canvas.BG;
  End;
End;

Procedure TextWinPutChar(Ch: Byte);
{ Place one character in text window at current cursor, advance cursor }
Begin
  If Not Canvas.TextWin.Active Then Exit;
  Case Ch Of
    13: Canvas.TextWin.CurCol := 0;
    10: Begin
      Inc(Canvas.TextWin.CurRow);
      If Canvas.TextWin.CurRow >= Canvas.TextWin.Rows Then Begin
        TextWinScroll(1);
        Canvas.TextWin.CurRow := Canvas.TextWin.Rows - 1;
      End;
    End;
    8: If Canvas.TextWin.CurCol > 0 Then Dec(Canvas.TextWin.CurCol);
  Else
    { TODO: render glyph pixel-by-pixel using system font bitmap }
    Inc(Canvas.TextWin.CurCol);
    If Canvas.TextWin.CurCol >= Canvas.TextWin.Cols Then Begin
      If Canvas.TextWin.Wrap Then Begin
        Canvas.TextWin.CurCol := 0;
        Inc(Canvas.TextWin.CurRow);
        If Canvas.TextWin.CurRow >= Canvas.TextWin.Rows Then Begin
          TextWinScroll(1);
          Canvas.TextWin.CurRow := Canvas.TextWin.Rows - 1;
        End;
      End Else
        Canvas.TextWin.CurCol := Canvas.TextWin.Cols - 1;
    End;
  End;
End;

Procedure TextWinWrite(Const S: String);
Var I: Integer;
Begin
  For I := 1 To Length(S) Do
    TextWinPutChar(Ord(S[I]));
End;

Procedure ProcessTextAnsi(Const S: String);
{ Process ANSI escape sequences in text window.
  Handles SGR (color) via TW_SGR_TO_EGA mapping.
  Non-ESC bytes go through TextWinPutChar. }
Var
  I, N: Integer;
  State: Byte; { 0=normal, 1=ESC, 2=CSI }
  Params: String;
  Code: Integer;
  ParamVal: Integer;
Begin
  If Not Canvas.TextWin.Active Then Exit;
  State := 0;
  Params := '';
  For I := 1 To Length(S) Do Begin
    Case State Of
      0: If S[I] = #27 Then State := 1
         Else TextWinPutChar(Ord(S[I]));
      1: If S[I] = '[' Then Begin State := 2; Params := ''; End
         Else State := 0;
      2: If (S[I] >= '0') And (S[I] <= ';') Then
           Params := Params + S[I]
         Else Begin
           { Execute CSI command }
           If S[I] = 'm' Then Begin { SGR }
             { Parse semicolon-separated params }
             Params := Params + ';';
             While Length(Params) > 0 Do Begin
               N := System.Pos(';', Params);
               If N = 0 Then Break;
               Val(Copy(Params, 1, N - 1), ParamVal, Code);
               If Code <> 0 Then ParamVal := 0;
               Delete(Params, 1, N);
               Case ParamVal Of
                 0: Canvas.TextWin.Attr := 7;
                 1: Canvas.TextWin.Attr := Canvas.TextWin.Attr Or $08;
                 5: Canvas.TextWin.Attr := Canvas.TextWin.Attr Or $80;
                 30..37: Canvas.TextWin.Attr := (Canvas.TextWin.Attr And $F8) Or TW_SGR_TO_EGA[ParamVal - 30];
                 40..47: Canvas.TextWin.Attr := (Canvas.TextWin.Attr And $8F) Or (TW_SGR_TO_EGA[ParamVal - 40] Shl 4);
               End;
             End;
           End;
           State := 0;
         End;
    End;
  End;
End;

{ ---- System font info ---- }

Function GetSysFontW: Integer;
Begin Result := SYS_FONT_W; End;

Function GetSysFontH: Integer;
Begin Result := SYS_FONT_H; End;

Function GetSysCols: Integer;
Begin Result := RIP_WIDTH Div SYS_FONT_W; End;

Function GetSysRows: Integer;
Begin Result := RIP_HEIGHT Div SYS_FONT_H; End;

{ ---- Graphics mode ---- }

Procedure EnterGraphics;
Begin
  Canvas.InGraphics := True;
  ResetViewPort;
End;

Procedure ExitGraphics;
Begin
  Canvas.InGraphics := False;
End;

End.
