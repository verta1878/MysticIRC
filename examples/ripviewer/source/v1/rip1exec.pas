{$MODE DELPHI}
{$H-}
Unit RIP1Exec;
{
  RIPscrip v1.54 Command Executor - 42-command dispatcher.
  Version-specific: v1.54 only.

  Dispatches parsed RIP commands to drawing primitives in ripdraw.pas.
  Handles both !| (first command) and | (subsequent) on multi-command lines.

  Ported from RIPtermJS ripterm.js by Carl Gorringe.
  PARAMETER AUDIT (verified against RIPtermJS parseRIPargs2 format strings):
    w  TextWindow   222211 = 10 chars (was 12, FIXED Run 16)
    1C GetImage     22221  =  9 chars (was 10, FIXED Run 16)
    1P PutImage     2221   =  7 chars (was  8, FIXED Run 16)
    All other commands verified correct.

  FEATURES:
    - EGA64toRGB conversion for palette commands
    - Button renderer with ButtonStyle (14 params, bevel/colors)
    - Fill debug output in debug mode
    - TRIPButtonStyle persistent state

  BUG HISTORY (Session 6):
    Run 7:  | command separator fix (parser only accepted !|)
    Run 9:  EGA64toRGB palette conversion
    Run 10: Button renderer stub
    Run 11: Full ButtonStyle parser + styled buttons
    Run 16: TextWindow/GetImage/PutImage parameter lengths fixed

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}
Interface

Uses SysUtils,
  {$IFDEF EXPERIMENTAL_RIP}
  RIP_Compat,
  {$ELSE}
  RIPEngine, RIPDraw, RIPText,
  {$ENDIF}
  RIP1Parse;

Procedure ExecuteRIP(const Line: String);

Implementation

Type
  { Button style record — stores parameters from rcButtonStyle (!|1B).
    Persists between calls: 1B sets the style, subsequent 1U buttons use it.
    Colors are EGA palette indices (0-15).
    Matched to RIPtermJS parseRIPargs2 format '22242222222222'. }
  TRIPButtonStyle = Record
    Wid       : Integer;  { button width override (0 = use coords)    }
    Hgt       : Integer;  { button height override (0 = use coords)   }
    Orient    : Integer;  { text orientation (0=left, 1=center, 2=right) }
    Flags     : Integer;  { 16-bit flags (4 mega digits)              }
    BevSize   : Integer;  { bevel thickness in pixels                 }
    DFore     : Byte;     { default text foreground color              }
    DBack     : Byte;     { default text background color              }
    Bright    : Byte;     { bevel highlight color (top/left edge)      }
    Dark      : Byte;     { bevel shadow color (bottom/right edge)     }
    Surface   : Byte;     { button surface fill color                  }
    GrpNo     : Integer;  { radio button group number                  }
    Flags2    : Integer;  { additional flags                            }
    UlineCol  : Byte;     { underline color for hotkey                  }
    CornerCol : Byte;     { corner pixel color                         }
    Valid     : Boolean;  { True if 1B has been received                }
  End;

Var
  BtnStyle : TRIPButtonStyle;  { current button style, set by rcButtonStyle }

  { Captured image buffer for GetImage/PutImage.
    Stores pixel region as width, height, and pixel data.
    Only one capture at a time (RIPscrip v1.54 spec). }
  CapturedImage : Record
    Valid  : Boolean;
    X0, Y0 : Integer;
    Width  : Integer;
    Height : Integer;
    Data   : Array[0..1023, 0..767] Of Byte;  { max capture region }
  End;

Const
  { EGA 2-bit component to 8-bit intensity lookup.
    EGA 64-color uses 2 bits per component (0-3).
    0=off, 1=dim(0x55), 2=bright(0xAA), 3=full(0xFF) }
  EGA2to8 : Array[0..3] Of Byte = ($00, $55, $AA, $FF);

{ Convert EGA 6-bit color value (0-63) to $BBGGRR LongWord.
  EGA bits: rgbRGB where r/g/b = dim, R/G/B = bright.
  Red   = (bit5 shl 1) or bit2 → 2-bit component
  Green = (bit4 shl 1) or bit1 → 2-bit component
  Blue  = (bit3 shl 1) or bit0 → 2-bit component
  Result stored as $BBGGRR to match our palette format. }
Function EGA64toRGB(Val: Integer): LongWord;
{ Convert EGA 6-bit color (0-63) to $BBGGRR.
  Bits are RGBrgb: R=bit5(WRONG), actually bits are:
    bit5=R(bright), bit4=G(bright), bit3=B(bright)
    bit2=r(dim),    bit1=g(dim),    bit0=b(dim)
  Component = (dim shl 1) or bright -> 0,1,2,3
  BUG FIX: Had bits backwards (rgbRGB). Swap Shr 5/2, 4/1, 3/0.
  C_WELL went from 99.7% to much better after this fix. }
Var RR, GG, BB: Byte;
Begin
  Val := Val And 63;
  RR := EGA2to8[((Val Shr 2) And 1) Shl 1 Or ((Val Shr 5) And 1)];
  GG := EGA2to8[((Val Shr 1) And 1) Shl 1 Or ((Val Shr 4) And 1)];
  BB := EGA2to8[(Val And 1) Shl 1 Or ((Val Shr 3) And 1)];
  Result := LongWord(BB) Shl 16 Or LongWord(GG) Shl 8 Or LongWord(RR);
End;

Procedure ExecuteRIP(const Line: String);
Var
  Pos  : Integer;
  Cmd  : TRIPCommand;
  X1, Y1, X2, Y2, R, C, I: Integer;
  NPts : Integer;
  BezPts  : Array[0..7] Of Integer;
  PolyPts : Array[0..1023] Of Integer;
  CmdPos  : Integer;
  DbgStr  : String;
  { Icon loading variables }
  IconFile : File;
  IconBuf  : Array[0..65535] Of Byte;
  IconSize : LongInt;
  IconW, IconH, IconBW, IconOfs: Integer;
  BP0, BP1, BP2, BP3: Byte;
Begin
  Pos := 1;
  While Pos <= Length(Line) Do Begin
    { RIPscrip commands start with !| (first on line) or just | (subsequent).
      ParseRIPCommand accepts both formats.
      BUG FIX: Previously only accepted !| which skipped all subsequent
      commands on multi-command lines. DRAGON01 went from 99.9% diff
      to rendering correctly after this fix. }
    If (Line[Pos] <> '!') And (Line[Pos] <> '|') Then Begin
      Inc(Pos);
      Continue;
    End;
    
    { Save command position for debug }
    CmdPos := Pos;
    
    Cmd := ParseRIPCommand(Line, Pos);
    
    Case Cmd Of
      rcPixel: If Pos + 3 <= Length(Line) Then Begin
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        PutPixel(X1, Y1, Canvas.FG);
        Inc(Pos, 4);
      End;
      
      rcLine: If Pos + 7 <= Length(Line) Then Begin
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        X2 := DecodeMega2(Line, Pos + 4);
        Y2 := DecodeMega2(Line, Pos + 6);
        DrawLine(X1, Y1, X2, Y2, Canvas.FG);
        Inc(Pos, 8);
      End;
      
      rcRectangle: If Pos + 7 <= Length(Line) Then Begin
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        X2 := DecodeMega2(Line, Pos + 4);
        Y2 := DecodeMega2(Line, Pos + 6);
        DrawRect(X1, Y1, X2, Y2, Canvas.FG);
        Inc(Pos, 8);
      End;
      
      rcBar: If Pos + 7 <= Length(Line) Then Begin
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        X2 := DecodeMega2(Line, Pos + 4);
        Y2 := DecodeMega2(Line, Pos + 6);
        FillRect(X1, Y1, X2, Y2, Canvas.FillColor);
        Inc(Pos, 8);
      End;
      
      rcCircle: If Pos + 5 <= Length(Line) Then Begin
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        R  := DecodeMega2(Line, Pos + 4);
        DrawCircle(X1, Y1, R, Canvas.FG);
        Inc(Pos, 6);
      End;
      
      rcColor: If Pos + 1 <= Length(Line) Then Begin
        Canvas.FG := DecodeMega2(Line, Pos) And 15;
        Canvas.BG := 0;
        Inc(Pos, 2);
      End;
      
      rcFillStyle: If Pos + 3 <= Length(Line) Then Begin
        Canvas.FillStyle := DecodeMega2(Line, Pos);
        Canvas.FillColor := DecodeMega2(Line, Pos + 2) And 15;
        Inc(Pos, 4);
      End;
      
      rcEraseWindow: Begin
        FillChar(Canvas.Pixels^, SizeOf(TPixelBuffer), 0);
      End;
      
      rcResetWindows: Begin
        Canvas.ViewX1 := 0;
        Canvas.ViewY1 := 0;
        Canvas.ViewX2 := RIP_WIDTH - 1;
        Canvas.ViewY2 := RIP_HEIGHT - 1;
        Canvas.CurX := 0;
        Canvas.CurY := 0;
      End;
      
      rcHome: Begin
        Canvas.CurX := 0;
        Canvas.CurY := 0;
      End;
      
      rcGotoXY: If Pos + 3 <= Length(Line) Then Begin
        Canvas.CurX := DecodeMega2(Line, Pos);
        Canvas.CurY := DecodeMega2(Line, Pos + 2);
        Inc(Pos, 4);
      End;
      
      rcOnePalette: If Pos + 5 <= Length(Line) Then Begin
        { !|a CCVV — set palette index CC to EGA 6-bit value VV }
        C := DecodeMega2(Line, Pos);      { palette index 0-15 }
        R := DecodeMega2(Line, Pos + 2);  { EGA 6-bit color 0-63 }
        If (C >= 0) And (C <= 15) Then
          Canvas.Palette[C] := EGA64toRGB(R);
        Inc(Pos, 4);
      End;
      
      { Text commands — ported from RIPtermJS ripterm.js }
      rcOutTextXY: If Pos + 3 <= Length(Line) Then Begin
        { !|@ XY TEXT — text until next | or end of line.
          BUG FIX: Was reading to end of line, consuming subsequent
          commands as text. SHADOW.RIP showed garbled command data
          after "Shadow" label. Now stops at next | delimiter. }
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        Inc(Pos, 4);
        { Read text until next | or end of line }
        DbgStr := '';
        While (Pos <= Length(Line)) And (Line[Pos] <> '|') And
              (Line[Pos] <> #13) And (Line[Pos] <> #10) Do Begin
          DbgStr := DbgStr + Line[Pos];
          Inc(Pos);
        End;
        OutTextXY(X1, Y1, DbgStr);
      End;
      
      rcOutText: Begin
        { !|T text — text at cursor until next | or end of line.
          BUG FIX: Was reading to end of line, same issue as OutTextXY. }
        DbgStr := '';
        While (Pos <= Length(Line)) And (Line[Pos] <> '|') And
              (Line[Pos] <> #13) And (Line[Pos] <> #10) Do Begin
          DbgStr := DbgStr + Line[Pos];
          Inc(Pos);
        End;
        OutText(DbgStr);
      End;
      
      rcFontStyle: If Pos + 7 <= Length(Line) Then Begin
        { !|Y FONT DIR SIZE RES — 4x 2-digit mega }
        X1 := DecodeMega2(Line, Pos);     { font }
        Y1 := DecodeMega2(Line, Pos + 2); { direction }
        X2 := DecodeMega2(Line, Pos + 4); { charsize }
        { Pos+6 = reserved, ignored }
        SetTextStyle(X1, Y1, X2);
        Inc(Pos, 8);
      End;
      
      { === Drawing commands ported from RIPtermJS === }
      
      rcOval: If Pos + 11 <= Length(Line) Then Begin
        { !|O CX CY ST_ANG E_ANG RADX RADY — ellipse outline.
          Same format as V (OvalArc): 222222 = 12 chars.
          BUG FIX: Was reading only 4 params (8 chars), missing angles.
          The start/end angles were being interpreted as radii. }
        X1 := DecodeMega2(Line, Pos);      { cx }
        Y1 := DecodeMega2(Line, Pos + 2);  { cy }
        { skip start/end angle for full ellipse }
        X2 := DecodeMega2(Line, Pos + 8);  { x_rad }
        Y2 := DecodeMega2(Line, Pos + 10); { y_rad }
        DrawEllipse(X1, Y1, X2, Y2, Canvas.FG);
        Inc(Pos, 12);
      End;
      
      rcFilledOval: If Pos + 7 <= Length(Line) Then Begin
        { !|o CX CY XR YR — filled ellipse }
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        X2 := DecodeMega2(Line, Pos + 4);
        Y2 := DecodeMega2(Line, Pos + 6);
        FillEllipse(X1, Y1, X2, Y2, Canvas.FillColor);
        DrawEllipse(X1, Y1, X2, Y2, Canvas.FG);
        Inc(Pos, 8);
      End;
      
      rcArc: If Pos + 9 <= Length(Line) Then Begin
        { !|A CX CY SA EA R — arc (5x 2-digit mega) }
        X1 := DecodeMega2(Line, Pos);      { cx }
        Y1 := DecodeMega2(Line, Pos + 2);  { cy }
        X2 := DecodeMega2(Line, Pos + 4);  { start_ang }
        Y2 := DecodeMega2(Line, Pos + 6);  { end_ang }
        R  := DecodeMega2(Line, Pos + 8);  { radius }
        { Arc uses aspect ratio — yradius adjusted like JS }
        DrawArcLines(X1, Y1, X2, Y2, R, R, Canvas.FG);
        Inc(Pos, 10);
      End;
      
      rcOvalArc: If Pos + 11 <= Length(Line) Then Begin
        { !|V CX CY SA EA XR YR — elliptical arc (6x 2-digit mega) }
        X1 := DecodeMega2(Line, Pos);       { cx }
        Y1 := DecodeMega2(Line, Pos + 2);   { cy }
        C  := DecodeMega2(Line, Pos + 4);   { start_ang }
        R  := DecodeMega2(Line, Pos + 6);   { end_ang }
        X2 := DecodeMega2(Line, Pos + 8);   { x_rad }
        Y2 := DecodeMega2(Line, Pos + 10);  { y_rad }
        DrawArcLines(X1, Y1, C, R, X2, Y2, Canvas.FG);
        Inc(Pos, 12);
      End;
      
      rcPieSlice: If Pos + 9 <= Length(Line) Then Begin
        { !|I CX CY SA EA R — pie slice }
        X1 := DecodeMega2(Line, Pos);      { cx }
        Y1 := DecodeMega2(Line, Pos + 2);  { cy }
        X2 := DecodeMega2(Line, Pos + 4);  { start_ang }
        Y2 := DecodeMega2(Line, Pos + 6);  { end_ang }
        R  := DecodeMega2(Line, Pos + 8);  { radius }
        DrawSector(X1, Y1, X2, Y2, R, R, Canvas.FG, Canvas.FillColor);
        Inc(Pos, 10);
      End;
      
      rcOvalPieSlice: If Pos + 11 <= Length(Line) Then Begin
        { !|i CX CY SA EA XR YR — oval pie }
        X1 := DecodeMega2(Line, Pos);       { cx }
        Y1 := DecodeMega2(Line, Pos + 2);   { cy }
        C  := DecodeMega2(Line, Pos + 4);   { start_ang }
        R  := DecodeMega2(Line, Pos + 6);   { end_ang }
        X2 := DecodeMega2(Line, Pos + 8);   { x_rad }
        Y2 := DecodeMega2(Line, Pos + 10);  { y_rad }
        DrawSector(X1, Y1, C, R, X2, Y2, Canvas.FG, Canvas.FillColor);
        Inc(Pos, 12);
      End;
      
      rcBezier: If Pos + 17 <= Length(Line) Then Begin
        { !|Z X0Y0 X1Y1 X2Y2 X3Y3 CNT — 9x 2-digit mega }
        BezPts[0] := DecodeMega2(Line, Pos);
        BezPts[1] := DecodeMega2(Line, Pos + 2);
        BezPts[2] := DecodeMega2(Line, Pos + 4);
        BezPts[3] := DecodeMega2(Line, Pos + 6);
        BezPts[4] := DecodeMega2(Line, Pos + 8);
        BezPts[5] := DecodeMega2(Line, Pos + 10);
        BezPts[6] := DecodeMega2(Line, Pos + 12);
        BezPts[7] := DecodeMega2(Line, Pos + 14);
        R := DecodeMega2(Line, Pos + 16);
        DrawBezier(R, BezPts, Canvas.FG);
        Inc(Pos, 18);
      End;
      
      rcPolygon: If Pos + 1 <= Length(Line) Then Begin
        { !|P NN X0Y0 X1Y1... — npoints then pairs }
        NPts := DecodeMega2(Line, Pos);
        Inc(Pos, 2);
        If (NPts >= 2) And (NPts <= 512) And (Pos + NPts * 4 - 1 <= Length(Line)) Then Begin
          For I := 0 to NPts - 1 Do Begin
            PolyPts[I * 2]     := DecodeMega2(Line, Pos + I * 4);
            PolyPts[I * 2 + 1] := DecodeMega2(Line, Pos + I * 4 + 2);
          End;
          { Draw outline }
          For I := 0 to NPts - 2 Do
            DrawLine(PolyPts[I*2], PolyPts[I*2+1], PolyPts[(I+1)*2], PolyPts[(I+1)*2+1], Canvas.FG);
          DrawLine(PolyPts[(NPts-1)*2], PolyPts[(NPts-1)*2+1], PolyPts[0], PolyPts[1], Canvas.FG);
          Inc(Pos, NPts * 4);
        End;
      End;
      
      rcFilledPolygon: If Pos + 1 <= Length(Line) Then Begin
        { !|p — filled polygon with scanline fill }
        NPts := DecodeMega2(Line, Pos);
        Inc(Pos, 2);
        If (NPts >= 2) And (NPts <= 512) And (Pos + NPts * 4 - 1 <= Length(Line)) Then Begin
          For I := 0 to NPts - 1 Do Begin
            PolyPts[I * 2]     := DecodeMega2(Line, Pos + I * 4);
            PolyPts[I * 2 + 1] := DecodeMega2(Line, Pos + I * 4 + 2);
          End;
          { Scanline fill }
          FillPolyScanline(NPts, PolyPts, Canvas.FillColor);
          { Outline }
          For I := 0 to NPts - 2 Do
            DrawLine(PolyPts[I*2], PolyPts[I*2+1], PolyPts[(I+1)*2], PolyPts[(I+1)*2+1], Canvas.FG);
          DrawLine(PolyPts[(NPts-1)*2], PolyPts[(NPts-1)*2+1], PolyPts[0], PolyPts[1], Canvas.FG);
          Inc(Pos, NPts * 4);
        End;
      End;
      
      rcPolyLine: If Pos + 1 <= Length(Line) Then Begin
        { !|l — polyline (no closing segment) }
        NPts := DecodeMega2(Line, Pos);
        Inc(Pos, 2);
        If (NPts >= 2) And (NPts <= 512) And (Pos + NPts * 4 - 1 <= Length(Line)) Then Begin
          For I := 0 to NPts - 1 Do Begin
            PolyPts[I * 2]     := DecodeMega2(Line, Pos + I * 4);
            PolyPts[I * 2 + 1] := DecodeMega2(Line, Pos + I * 4 + 2);
          End;
          For I := 0 to NPts - 2 Do
            DrawLine(PolyPts[I*2], PolyPts[I*2+1], PolyPts[(I+1)*2], PolyPts[(I+1)*2+1], Canvas.FG);
          Inc(Pos, NPts * 4);
        End;
      End;
      
      rcFill: If Pos + 5 <= Length(Line) Then Begin
        { !|F X Y BORDER — flood fill }
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        C  := DecodeMega2(Line, Pos + 4) And 15;
        If DebugMode Then
          WriteLn('  FILL: (', X1, ',', Y1, ') border=', C,
                  ' fillColor=', Canvas.FillColor,
                  ' fillStyle=', Canvas.FillStyle,
                  ' pixel@seed=', Canvas.Pixels^[X1, Y1]);
        FloodFill(X1, Y1, C);
        Inc(Pos, 6);
      End;
      
      rcFillPattern: If Pos + 17 <= Length(Line) Then Begin
        { !|s C1..C8 COLOR — 9x 2-digit mega (user fill pattern) }
        { Store pattern bytes — TODO: use in fill operations }
        Canvas.FillColor := DecodeMega2(Line, Pos + 16) And 15;
        Canvas.FillStyle := 12; { USER_FILL }
        Inc(Pos, 18);
      End;
      
      rcLineStyle: If Pos + 7 <= Length(Line) Then Begin
        { !|= STYLE PATTERN THICK — fmt 242 }
        Canvas.LineStyle := DecodeMega2(Line, Pos);
        { skip 4-digit pattern }
        Canvas.LineThick := DecodeMega2(Line, Pos + 6);
        Inc(Pos, 8);
      End;
      
      rcWriteMode: If Pos + 1 <= Length(Line) Then Begin
        { !|W MODE — write mode (0=copy, 1=xor) }
        Canvas.WriteMode := DecodeMega2(Line, Pos);
        Inc(Pos, 2);
      End;
      
      rcEraseView: Begin
        { !|e — erase current viewport to black.
          Uses absolute canvas coordinates directly, not PutPixel,
          because PutPixel adds viewport offset. }
        For Y1 := Canvas.ViewY1 to Canvas.ViewY2 Do
          For X1 := Canvas.ViewX1 to Canvas.ViewX2 Do
            If (X1 >= 0) And (X1 < RIP_WIDTH) And (Y1 >= 0) And (Y1 < RIP_HEIGHT) Then
              Canvas.Pixels^[X1, Y1] := 0;
      End;
      
      rcEraseEOL: Begin
        { !|> — erase to end of line (text cursor) }
        { Simplified: clear from CurX to right edge at CurY row }
        For X1 := Canvas.CurX to Canvas.ViewX2 Do
          For Y1 := Canvas.CurY to Canvas.CurY + 15 Do
            PutPixel(X1, Y1, 0);
      End;
      
      rcTextWindow: If Pos + 9 <= Length(Line) Then Begin
        { !|w X0Y0 X1Y1 WRAP SIZE — 4x2-digit + 2x1-digit = 10 chars
          BUG FIX: Was Inc(Pos, 12) which ate 2 chars from the next
          command. This caused |c08 after |w to be skipped, leaving
          FG=15 (white) and drawing all outlines in white instead of
          dark gray. DRAGON01's bezier outlines were wrong color. }
        Inc(Pos, 10);
      End;
      
      rcViewPort: If Pos + 7 <= Length(Line) Then Begin
        { !|v X0 Y0 X1 Y1 — set graphics viewport }
        Canvas.ViewX1 := DecodeMega2(Line, Pos);
        Canvas.ViewY1 := DecodeMega2(Line, Pos + 2);
        Canvas.ViewX2 := DecodeMega2(Line, Pos + 4);
        Canvas.ViewY2 := DecodeMega2(Line, Pos + 6);
        Inc(Pos, 8);
      End;
      
      rcGetImage: If Pos + 8 <= Length(Line) Then Begin
        { !|1C X0Y0 X1Y1 RES — capture pixel region to buffer.
          Copies rectangle (X0,Y0)-(X1,Y1) from canvas to CapturedImage.
          Used with rcPutImage to duplicate regions (v_VIEW test). }
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        X2 := DecodeMega2(Line, Pos + 4);
        Y2 := DecodeMega2(Line, Pos + 6);
        CapturedImage.Valid := True;
        CapturedImage.X0 := X1;
        CapturedImage.Y0 := Y1;
        CapturedImage.Width := X2 - X1 + 1;
        CapturedImage.Height := Y2 - Y1 + 1;
        If CapturedImage.Width > 1024 Then CapturedImage.Width := 1024;
        If CapturedImage.Height > 768 Then CapturedImage.Height := 768;
        For R := 0 to CapturedImage.Height - 1 Do
          For C := 0 to CapturedImage.Width - 1 Do
            If (X1+C >= 0) And (X1+C < RIP_WIDTH) And (Y1+R >= 0) And (Y1+R < RIP_HEIGHT) Then
              CapturedImage.Data[C, R] := Canvas.Pixels^[X1+C, Y1+R];
        Inc(Pos, 9);
      End;
      
      rcPutImage: If Pos + 6 <= Length(Line) Then Begin
        { !|1P X Y MODE RES — paste captured region at (X,Y).
          MODE: 0=COPY, 1=XOR, 2=OR, 3=AND, 4=NOT.
          Pastes CapturedImage to canvas at the specified position. }
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        C := DecodeMega2(Line, Pos + 4);  { write mode }
        If CapturedImage.Valid Then Begin
          For R := 0 to CapturedImage.Height - 1 Do
            For I := 0 to CapturedImage.Width - 1 Do
              If (X1+I >= 0) And (X1+I < RIP_WIDTH) And (Y1+R >= 0) And (Y1+R < RIP_HEIGHT) Then
                Case C Of
                  0: Canvas.Pixels^[X1+I, Y1+R] := CapturedImage.Data[I, R];
                  1: Canvas.Pixels^[X1+I, Y1+R] := Canvas.Pixels^[X1+I, Y1+R] Xor CapturedImage.Data[I, R];
                Else
                  Canvas.Pixels^[X1+I, Y1+R] := CapturedImage.Data[I, R];
                End;
        End;
        Inc(Pos, 7);
      End;
      
      rcLoadIcon: If Pos + 8 <= Length(Line) Then Begin
        { !|1I X Y MODE CLIP RES FILENAME — load and display .ICN icon.
          Format: 22212* = X(2), Y(2), MODE(2), CLIP(1), RES(2), FILENAME(*).
          ICN file format: 4-byte header (width-1, height-1 as LE uint16),
          then 4 EGA bit-planes per scanline.
          BUG FIX: Was a stub that skipped to EOL. }
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        C := DecodeMega2(Line, Pos + 4);   { write mode }
        R := Ord(Line[Pos + 6]);            { clip flag (1 char) }
        Inc(Pos, 9);                        { skip X+Y+MODE+CLIP+RES }
        { Extract filename — rest of line or until | }
        DbgStr := '';
        While (Pos <= Length(Line)) And (Line[Pos] <> '|') And (Line[Pos] <> #13) Do Begin
          DbgStr := DbgStr + Line[Pos];
          Inc(Pos);
        End;
        { Load and draw the icon }
        If Length(DbgStr) > 0 Then Begin
          { Try multiple paths for .ICN files }
          If FileExists('icons' + DirectorySeparator + DbgStr) Then
            DbgStr := 'icons' + DirectorySeparator + DbgStr
          Else If FileExists('..' + DirectorySeparator + 'icons' + DirectorySeparator + DbgStr) Then
            DbgStr := '..' + DirectorySeparator + 'icons' + DirectorySeparator + DbgStr;
          If FileExists(DbgStr) Then Begin
            { Read ICN file }
            Assign(IconFile, DbgStr);
            {$I-} System.Reset(IconFile, 1); {$I+}
            If IOResult = 0 Then Begin
              IconSize := FileSize(IconFile);
              If IconSize <= SizeOf(IconBuf) Then Begin
                BlockRead(IconFile, IconBuf, IconSize);
                Close(IconFile);
                { Parse header: width-1, height-1 as LE uint16 }
                IconW := (IconBuf[1] Shl 8 Or IconBuf[0]) + 1;
                IconH := (IconBuf[3] Shl 8 Or IconBuf[2]) + 1;
                If (IconW > 0) And (IconW <= 640) And (IconH > 0) And (IconH <= 350) Then Begin
                  { Decode 4 bit-planes per scanline }
                  IconBW := (IconW + 7) Div 8;  { bytes per plane per row }
                  For Y2 := 0 to IconH - 1 Do Begin
                    IconOfs := 4 + Y2 * IconBW * 4;  { offset in file }
                    For X2 := 0 to IconBW - 1 Do Begin
                      { Read 4 bit-plane bytes for this 8-pixel column }
                      If IconOfs + X2 + IconBW * 3 < IconSize Then Begin
                        BP3 := IconBuf[IconOfs + X2];
                        BP2 := IconBuf[IconOfs + X2 + IconBW];
                        BP1 := IconBuf[IconOfs + X2 + IconBW * 2];
                        BP0 := IconBuf[IconOfs + X2 + IconBW * 3];
                        { Decode 8 pixels from the 4 planes }
                        For I := 7 DownTo 0 Do Begin
                          NPts := ((BP3 And 1) Shl 3) Or ((BP2 And 1) Shl 2) Or
                                  ((BP1 And 1) Shl 1) Or (BP0 And 1);
                          BP3 := BP3 Shr 1; BP2 := BP2 Shr 1;
                          BP1 := BP1 Shr 1; BP0 := BP0 Shr 1;
                          If X2 * 8 + I < IconW Then
                            PutPixel(X1 + X2 * 8 + I, Y1 + Y2, NPts And 15);
                        End;
                      End;
                    End;
                  End;
                End;
              End Else
                Close(IconFile);
            End;
          End;
        End;
      End;
      
      rcMouse: If Pos + 15 <= Length(Line) Then Begin
        { !|1M NUM X0 Y0 X1 Y1 CLK CLR RES TEXT — mouse region (stub, skip to EOL) }
        Pos := Length(Line) + 1;
      End;
      
      rcKillMouseFields: Begin
        { !|1K — kill mouse fields (no-op in viewer) }
      End;
      
      rcButton: If Pos + 13 <= Length(Line) Then Begin
        { !|1U X0Y0 X1Y1 HOTKEY FLAGS RES TEXT
          Draws a beveled button using current ButtonStyle colors.
          If no ButtonStyle received yet, uses defaults (gray/white/dark).
          Text format: ICONFILE<>LABEL TEXT<>HOST COMMAND
          
          Bevel structure (outside in):
            Corner pixels (CornerCol) at the 4 corners
            Bright color on top and left edges (3D highlight)
            Dark color on bottom and right edges (3D shadow)
            Surface color fills the interior
            Text drawn centered in DFore color
          
          BUG FIX (Session 6): Was a stub that drew nothing.
          DRAGON01's "Continue" button now renders with correct colors. }
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        X2 := DecodeMega2(Line, Pos + 4);
        Y2 := DecodeMega2(Line, Pos + 6);
        Inc(Pos, 14); { skip coords(8) + hotkey(2) + flags(2) + res(2) }
        { Extract label text: format is ICON<>LABEL<>HOSTCMD }
        DbgStr := Copy(Line, Pos, Length(Line) - Pos + 1);
        I := System.Pos('<>', DbgStr);
        If I > 0 Then Begin
          Delete(DbgStr, 1, I + 1);
          I := System.Pos('<>', DbgStr);
          If I > 0 Then DbgStr := Copy(DbgStr, 1, I - 1);
        End;
        { Use ButtonStyle colors if set, else defaults }
        C := Canvas.FillColor;
        Canvas.FillStyle := 1; { solid fill for button surface }
        If BtnStyle.Valid Then Begin
          { Apply style override for width/height if specified }
          If (BtnStyle.Wid > 0) And (BtnStyle.Hgt > 0) Then Begin
            X2 := X1 + BtnStyle.Wid;
            Y2 := Y1 + BtnStyle.Hgt;
          End;
          { Surface fill }
          Canvas.FillColor := BtnStyle.Surface;
          FillRect(X1, Y1, X2, Y2, BtnStyle.Surface);
          { Bevel — draws OUTSIDE the button coords matching JS.
            JS: drawBeveledBox(left-bev, top-bev+1, right+bev, bot+bev, ...) }
          If (BtnStyle.Flags And 512) <> 0 Then Begin
            For I := 1 to BtnStyle.BevSize Do Begin
              { Bright edges (top/left) }
              DrawLine(X1 - I, Y1 - I + 1, X2 + I, Y1 - I + 1, BtnStyle.Bright);
              DrawLine(X1 - I, Y1 - I + 1, X1 - I, Y2 + I, BtnStyle.Bright);
              { Dark edges (bottom/right) }
              DrawLine(X1 - I, Y2 + I, X2 + I, Y2 + I, BtnStyle.Dark);
              DrawLine(X2 + I, Y1 - I + 1, X2 + I, Y2 + I, BtnStyle.Dark);
            End;
            { Corner pixels }
            PutPixel(X1 - BtnStyle.BevSize, Y1 - BtnStyle.BevSize + 1, BtnStyle.CornerCol);
            PutPixel(X2 + BtnStyle.BevSize, Y1 - BtnStyle.BevSize + 1, BtnStyle.CornerCol);
            PutPixel(X1 - BtnStyle.BevSize, Y2 + BtnStyle.BevSize, BtnStyle.CornerCol);
            PutPixel(X2 + BtnStyle.BevSize, Y2 + BtnStyle.BevSize, BtnStyle.CornerCol);
          End;
          { Text positioned based on Orient:
            0=above button, 1=left, 2=center(inside), 3=right, 4=below }
          If Length(DbgStr) > 0 Then Begin
            Canvas.FG := BtnStyle.DFore;
            Case BtnStyle.Orient Of
              0: { Above }
                OutTextXY(X1 + ((X2 - X1 - TextWidth(DbgStr)) Div 2),
                          Y1 - TextHeight - 2, DbgStr);
              1: { Left }
                OutTextXY(X1 - TextWidth(DbgStr) - 4,
                          Y1 + ((Y2 - Y1 - TextHeight) Div 2), DbgStr);
              3: { Right }
                OutTextXY(X2 + 4,
                          Y1 + ((Y2 - Y1 - TextHeight) Div 2), DbgStr);
              4: { Below }
                OutTextXY(X1 + ((X2 - X1 - TextWidth(DbgStr)) Div 2),
                          Y2 + 2, DbgStr);
            Else { 2 = Center (default) }
              OutTextXY(X1 + ((X2 - X1 - TextWidth(DbgStr)) Div 2),
                        Y1 + ((Y2 - Y1 - TextHeight) Div 2), DbgStr);
            End;
          End;
        End Else Begin
          { No style — use defaults (gray/white/darkgray) }
          Canvas.FillColor := 7;
          FillRect(X1, Y1, X2, Y2, 7);
          DrawLine(X1, Y1, X2, Y1, 15);
          DrawLine(X1, Y1, X1, Y2, 15);
          DrawLine(X1, Y2, X2, Y2, 8);
          DrawLine(X2, Y1, X2, Y2, 8);
          If Length(DbgStr) > 0 Then
            OutTextXY(X1 + ((X2 - X1 - TextWidth(DbgStr)) Div 2),
                      Y1 + ((Y2 - Y1 - TextHeight) Div 2), DbgStr);
        End;
        Canvas.FillColor := C;
        Pos := Length(Line) + 1; { consumed rest of line }
      End;
      
      rcButtonStyle: If Pos + 29 <= Length(Line) Then Begin
        { !|1B — parse format '22242222222222' (30 chars total).
          Sets button style for all subsequent rcButton (1U) calls.
          Colors are EGA palette indices (0-15). }
        BtnStyle.Wid       := DecodeMega2(Line, Pos);      Inc(Pos, 2);
        BtnStyle.Hgt       := DecodeMega2(Line, Pos);      Inc(Pos, 2);
        BtnStyle.Orient    := DecodeMega2(Line, Pos);      Inc(Pos, 2);
        { Flags is 4 mega digits (not 2) — 16-bit value }
        BtnStyle.Flags     := DecodeMega2(Line, Pos) * 1296 + DecodeMega2(Line, Pos + 2);
                                                            Inc(Pos, 4);
        BtnStyle.BevSize   := DecodeMega2(Line, Pos);      Inc(Pos, 2);
        BtnStyle.DFore     := DecodeMega2(Line, Pos) And 15; Inc(Pos, 2);
        BtnStyle.DBack     := DecodeMega2(Line, Pos) And 15; Inc(Pos, 2);
        BtnStyle.Bright    := DecodeMega2(Line, Pos) And 15; Inc(Pos, 2);
        BtnStyle.Dark      := DecodeMega2(Line, Pos) And 15; Inc(Pos, 2);
        BtnStyle.Surface   := DecodeMega2(Line, Pos) And 15; Inc(Pos, 2);
        BtnStyle.GrpNo     := DecodeMega2(Line, Pos);      Inc(Pos, 2);
        BtnStyle.Flags2    := DecodeMega2(Line, Pos);      Inc(Pos, 2);
        BtnStyle.UlineCol  := DecodeMega2(Line, Pos) And 15; Inc(Pos, 2);
        BtnStyle.CornerCol := DecodeMega2(Line, Pos) And 15; Inc(Pos, 2);
        BtnStyle.Valid     := True;
      End;
      
      rcSetPalette: If Pos + 31 <= Length(Line) Then Begin
        { !|Q 16x 2-digit mega — set all 16 palette entries.
          Each value is EGA 6-bit color (0-63), convert to $BBGGRR }
        For I := 0 to 15 Do Begin
          C := DecodeMega2(Line, Pos + I * 2);
          Canvas.Palette[I] := EGA64toRGB(C);
        End;
        Inc(Pos, 32);
      End;
      
      rcComment: Begin
        { |! = text/comment — skip to next | delimiter, NOT end of line.
          BUG FIX: Was mapped to rcNoMore which skipped to EOL.
          C_WELL has |S0907|!FD76708 where the fill after the
          comment was lost. Now skips only the comment text. }
        While (Pos <= Length(Line)) And (Line[Pos] <> '|') And
              (Line[Pos] <> #13) And (Line[Pos] <> #10) Do
          Inc(Pos);
      End;
      rcNoMore: Begin
        { !|# — end of RIP, stop processing }
        Pos := Length(Line) + 1;
      End;
    Else
      { Skip unknown command — advance past parameters }
      Inc(Pos);
    End;
    
    { Debug: print command from original line }
    If DebugMode And (Cmd <> rcUnknown) Then Begin
      DbgStr := Copy(Line, CmdPos, Pos - CmdPos + 2);
      If Length(DbgStr) > 60 Then
        DbgStr := Copy(DbgStr, 1, 57) + '...';
      WriteLn('  ', DbgStr);
    End;
    
    { Baud emulation: delay based on bytes consumed }
    If (BaudDelay > 0) And (Cmd <> rcUnknown) Then Begin
      { Sleep for (bytes * BaudDelay) microseconds }
      { FPC Sleep is in milliseconds, minimum 1ms }
      I := (Pos - CmdPos) * BaudDelay Div 1000;
      If I > 0 Then Sleep(I);
    End;
  End;
End;

End.
