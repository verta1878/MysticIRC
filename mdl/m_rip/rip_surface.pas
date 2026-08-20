// ====================================================================
// mystic_rip : optional RIPscrip graphics example for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// rip_surface - TRipSurface: a software raster backend for the
// TRipCanvas seam (rip_canvas.pas).  Pure Pascal, NO SDL, NO
// BGI: it draws RIP primitives into an in-memory 640x350 RGB buffer
// (the BGI framebuffer model) - Bresenham lines, midpoint ellipses,
// flood fill, an 8x8 font - so output is deterministic and pixel-
// faithful to the original EGA canvas.  A presenter (rip_window.pas
// via sdl_bind today; LCL/BGI later) just displays this buffer.
//
// SaveBMP renders a .RIP to an image with no display at all, which is
// how the container verifies the pipeline headlessly (same idea as
// TDosScreen's PPM export).
//
// Derived from ripterm_client_v0 (RipFrameBuffer.pas), the
// maintainer's clean-room RIP client engine.
// ====================================================================

Unit rip_Surface;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  SysUtils,
  Classes,
  Math,
  rip_Canvas;

Type
  TRipSurface = Class(TRipCanvas)
  Private
    FW, FH     : Integer;
    FPix       : Array of TRipRGB;         // FW*FH, row-major
    FDraw      : TRipColor;
    FFill      : TRipColor;
    FBg        : TRipColor;
    FWriteMode : Integer;
    FCurX      : Integer;
    FCurY      : Integer;
    FRegions   : Array of TRipMouseRegion;
    FLineStyle : Integer;
    FLineThick : Integer;
    FFillStyle : Integer;
    FFillPat   : Array[0..7] of Byte;
    FFontNum   : Integer;
    FFontDir   : Integer;
    FFontSize  : Integer;
    FViewX0    : Integer;
    FViewY0    : Integer;
    FViewX1    : Integer;
    FViewY1    : Integer;
    FTextX0    : Integer;
    FTextY0    : Integer;
    FTextX1    : Integer;
    FTextY1    : Integer;
    FTextCurX  : Integer;
    FTextCurY  : Integer;
    FClipboard : Array of TRipRGB;
    FClipW     : Integer;
    FClipH     : Integer;
    FInText    : Boolean;

    Procedure PutPixel (X, Y: Integer; Const C: TRipRGB); Inline;
    Function  GetPixel (X, Y: Integer) : TRipRGB; Inline;
    Procedure RawLine (X0, Y0, X1, Y1: Integer; Const C: TRipRGB);
    Procedure RawEllipse (Cx, Cy, Rx, Ry: Integer; Const C: TRipRGB; Filled: Boolean);
    Procedure DrawChar (X, Y: Integer; Ch: Char; Const C: TRipRGB);
  Public
    Constructor Create (AW: Integer = RIP_WIDTH; AH: Integer = RIP_HEIGHT);

    Procedure SaveBMP (Const FileName: String);

    Function  Width : Integer;
    Function  Height : Integer;
    Function  RegionCount : Integer;
    Function  Region (Idx: Integer) : TRipMouseRegion;
    Function  RawPixel (X, Y: Integer) : TRipRGB;   // for presenters to read

    // ---- TRipCanvas ----
    Procedure Clear; Override;
    Procedure Present; Override;
    Procedure SetDrawColor (C: TRipColor); Override;
    Procedure SetFillColor (C: TRipColor); Override;
    Procedure SetWriteMode (M: Integer); Override;
    Procedure SetLineStyle (Style, Thickness: Integer); Override;
    Procedure MoveTo (X, Y: Integer); Override;
    Procedure LineTo (X, Y: Integer); Override;
    Procedure Pixel (X, Y: Integer; C: TRipColor); Override;
    Procedure Line (X0, Y0, X1, Y1: Integer); Override;
    Procedure Rectangle (X0, Y0, X1, Y1: Integer); Override;
    Procedure Bar (X0, Y0, X1, Y1: Integer); Override;
    Procedure Circle (X, Y, Radius: Integer); Override;
    Procedure Oval (X, Y, XRad, YRad: Integer); Override;
    Procedure FilledOval (X, Y, XRad, YRad: Integer); Override;
    Procedure FloodFill (X, Y: Integer; Border: TRipColor); Override;
    Procedure WriteText (X, Y: Integer; Const S: AnsiString); Override;
    Procedure AddMouseRegion (Const R: TRipMouseRegion); Override;
    Procedure KillMouseRegions; Override;
    // Phase 2+3 additions
    Procedure Arc (X, Y, StAngle, EndAngle, Radius: Integer); Override;
    Procedure OvalArc (X, Y, StAngle, EndAngle, XRad, YRad: Integer); Override;
    Procedure PieSlice (X, Y, StAngle, EndAngle, Radius: Integer); Override;
    Procedure OvalPieSlice (X, Y, StAngle, EndAngle, XRad, YRad: Integer); Override;
    Procedure Bezier (X1, Y1, X2, Y2, X3, Y3, X4, Y4, Count: Integer); Override;
    Procedure Polygon (Var Points; NumPoints: Integer); Override;
    Procedure FillPolygon (Var Points; NumPoints: Integer); Override;
    Procedure Polyline (Var Points; NumPoints: Integer); Override;
    Procedure SetFillStyle (Pattern: Integer; Color: TRipColor); Override;
    Procedure SetFillPattern (Var Pattern; Color: TRipColor); Override;
    Procedure SetFontStyle (Font, Direction, Size: Integer); Override;
    Procedure SetPalette (Var Pal); Override;
    Procedure SetOnePalette (Color, EGA64: Integer); Override;
    Procedure SetViewPort (X0, Y0, X1, Y1: Integer; Clip: Boolean); Override;
    Procedure TextWindow (X0, Y0, X1, Y1, Wrap: Integer); Override;
    Procedure ResetWindows; Override;
    Procedure GotoXY (X, Y: Integer); Override;
    Procedure Home; Override;
    Procedure EraseEOL; Override;
    Procedure EraseWindow; Override;
    Procedure EraseView; Override;
    Procedure GetImage (X0, Y0, X1, Y1: Integer); Override;
    Procedure PutImage (X, Y, Mode: Integer); Override;
    Procedure WriteIcon (FileName: AnsiString); Override;
    Procedure LoadIcon (X, Y: Integer; FileName: AnsiString); Override;
    Procedure SetButtonStyle (Var Params); Override;
    Procedure DrawButton (X0, Y0, X1, Y1: Integer; Const Params: AnsiString); Override;
    Procedure BeginText (X, Y, W, H: Integer); Override;
    Procedure RegionText (Justify: Integer; Const S: AnsiString); Override;
    Procedure EndText; Override;
  End;

Implementation

{$I font8x8.inc}   // FONT8X8: array[32..127, 0..7] of Byte

Constructor TRipSurface.Create (AW, AH: Integer);
Begin
  Inherited Create;

  FW := AW;
  FH := AH;

  SetLength (FPix, FW * FH);

  FDraw      := 15;
  FFill      := 0;
  FBg        := 0;
  FWriteMode := RIP_WM_COPY;
  FCurX      := 0;
  FCurY      := 0;

  Clear;
End;

Function TRipSurface.Width : Integer;
Begin
  Result := FW;
End;

Function TRipSurface.Height : Integer;
Begin
  Result := FH;
End;

Function TRipSurface.RawPixel (X, Y: Integer) : TRipRGB;
Begin
  If (X >= 0) And (X < FW) And (Y >= 0) And (Y < FH) Then
    Result := FPix[Y * FW + X]
  Else Begin
    Result.R := 0;
    Result.G := 0;
    Result.B := 0;
  End;
End;

Procedure TRipSurface.PutPixel (X, Y: Integer; Const C: TRipRGB);
Var
  Idx : Integer;
  D   : TRipRGB;
Begin
  If (X < 0) Or (X >= FW) Or (Y < 0) Or (Y >= FH) Then Exit;

  Idx := Y * FW + X;

  If FWriteMode = RIP_WM_XOR Then Begin
    D := FPix[Idx];

    D.R := D.R Xor C.R;
    D.G := D.G Xor C.G;
    D.B := D.B Xor C.B;

    FPix[Idx] := D;
  End Else
    FPix[Idx] := C;
End;

Function TRipSurface.GetPixel (X, Y: Integer) : TRipRGB;
Begin
  Result := RawPixel(X, Y);
End;

Procedure TRipSurface.Clear;
Var
  I : Integer;
Begin
  For I := 0 to High(FPix) Do
    FPix[I] := RIP_EGA_PALETTE[FBg];
End;

Procedure TRipSurface.Present;
Begin
  // software buffer: no-op (a presenter reads RawPixel and displays)
End;

Procedure TRipSurface.SetDrawColor (C: TRipColor);
Begin
  // RIP_COLOR sets the drawing color.  Most RIP content sets one color
  // with 'c' and then draws filled shapes (Bar/FilledOval) expecting
  // that color, so track it as the fill color too.  RIP_FILL_STYLE
  // ('S', Phase 2) can override the fill later.
  FDraw := C And 15;
  FFill := C And 15;
End;

Procedure TRipSurface.SetFillColor (C: TRipColor);
Begin
  FFill := C And 15;
End;

Procedure TRipSurface.SetWriteMode (M: Integer);
Begin
  FWriteMode := M;
End;

Procedure TRipSurface.SetLineStyle (Style, Thickness: Integer);
Begin
  // line patterns/thickness: Phase 2
End;

Procedure TRipSurface.MoveTo (X, Y: Integer);
Begin
  FCurX := X;
  FCurY := Y;
End;

Procedure TRipSurface.LineTo (X, Y: Integer);
Begin
  RawLine (FCurX, FCurY, X, Y, RIP_EGA_PALETTE[FDraw]);

  FCurX := X;
  FCurY := Y;
End;

Procedure TRipSurface.Pixel (X, Y: Integer; C: TRipColor);
Begin
  // BGI PutPixel draws in the CURRENT color; the seam's C parameter is
  // reserved (the parser passes a placeholder).  Kept for seam parity.
  PutPixel (X, Y, RIP_EGA_PALETTE[FDraw]);
End;

// Bresenham line
Procedure TRipSurface.RawLine (X0, Y0, X1, Y1: Integer; Const C: TRipRGB);
{ JS-matched Bresenham (den/num/numadd) — backport from ripviewer. }
Var
  DX, DY, XI1, XI2, YI1, YI2: Integer;
  Den, Num, NumAdd, NumPixels: Integer;
  X, Y, I: Integer;
Begin
  DX := Abs(X1 - X0); DY := Abs(Y1 - Y0);
  If X1 >= X0 Then Begin XI1 := 1; XI2 := 1; End
  Else Begin XI1 := -1; XI2 := -1; End;
  If Y1 >= Y0 Then Begin YI1 := 1; YI2 := 1; End
  Else Begin YI1 := -1; YI2 := -1; End;
  If DX >= DY Then Begin
    XI1 := 0; YI2 := 0;
    Den := DX; Num := DX Shr 1; NumAdd := DY; NumPixels := DX;
  End Else Begin
    XI2 := 0; YI1 := 0;
    Den := DY; Num := DY Shr 1; NumAdd := DX; NumPixels := DY;
  End;
  X := X0; Y := Y0;
  For I := 0 to NumPixels Do Begin
    PutPixel(X, Y, C);
    Inc(Num, NumAdd);
    If Num >= Den Then Begin Dec(Num, Den); Inc(X, XI1); Inc(Y, YI1); End;
    Inc(X, XI2); Inc(Y, YI2);
  End;
End;

Procedure TRipSurface.Line (X0, Y0, X1, Y1: Integer);
Begin
  RawLine (X0, Y0, X1, Y1, RIP_EGA_PALETTE[FDraw]);
End;

Procedure TRipSurface.Rectangle (X0, Y0, X1, Y1: Integer);
Begin
  RawLine (X0, Y0, X1, Y0, RIP_EGA_PALETTE[FDraw]);
  RawLine (X1, Y0, X1, Y1, RIP_EGA_PALETTE[FDraw]);
  RawLine (X1, Y1, X0, Y1, RIP_EGA_PALETTE[FDraw]);
  RawLine (X0, Y1, X0, Y0, RIP_EGA_PALETTE[FDraw]);
End;

Procedure TRipSurface.Bar (X0, Y0, X1, Y1: Integer);
Var
  YY, T : Integer;
Begin
  If Y0 > Y1 Then Begin
    T  := Y0;
    Y0 := Y1;
    Y1 := T;
  End;

  For YY := Y0 to Y1 Do
    RawLine (X0, YY, X1, YY, RIP_EGA_PALETTE[FFill]);
End;

// midpoint ellipse; Filled -> horizontal spans
Procedure TRipSurface.RawEllipse (Cx, Cy, Rx, Ry: Integer; Const C: TRipRGB; Filled: Boolean);
Var
  X, Y           : Integer;
  D1, D2, DX, DY : Int64;

  Procedure Plot4 (PX, PY: Integer);
  Begin
    If Filled Then Begin
      RawLine (Cx - PX, Cy + PY, Cx + PX, Cy + PY, C);
      RawLine (Cx - PX, Cy - PY, Cx + PX, Cy - PY, C);
    End Else Begin
      PutPixel (Cx + PX, Cy + PY, C);
      PutPixel (Cx - PX, Cy + PY, C);
      PutPixel (Cx + PX, Cy - PY, C);
      PutPixel (Cx - PX, Cy - PY, C);
    End;
  End;

Begin
  If (Rx <= 0) Or (Ry <= 0) Then Exit;

  X := 0;
  Y := Ry;

  D1 := Int64(Ry) * Ry - Int64(Rx) * Rx * Ry + (Int64(Rx) * Rx) Div 4;
  DX := 2 * Int64(Ry) * Ry * X;
  DY := 2 * Int64(Rx) * Rx * Y;

  While DX < DY Do Begin
    Plot4 (X, Y);
    Inc (X);

    If D1 < 0 Then Begin
      DX := DX + 2 * Int64(Ry) * Ry;
      D1 := D1 + DX + Int64(Ry) * Ry;
    End Else Begin
      Dec (Y);
      DX := DX + 2 * Int64(Ry) * Ry;
      DY := DY - 2 * Int64(Rx) * Rx;
      D1 := D1 + DX - DY + Int64(Ry) * Ry;
    End;
  End;

  D2 := Round(Int64(Ry) * Ry * (X + 0.5) * (X + 0.5) +
        Int64(Rx) * Rx * (Y - 1) * (Y - 1) -
        Int64(Rx) * Rx * Int64(Ry) * Ry);

  While Y >= 0 Do Begin
    Plot4 (X, Y);
    Dec (Y);

    If D2 > 0 Then Begin
      DY := DY - 2 * Int64(Rx) * Rx;
      D2 := D2 + Int64(Rx) * Rx - DY;
    End Else Begin
      Inc (X);
      DX := DX + 2 * Int64(Ry) * Ry;
      DY := DY - 2 * Int64(Rx) * Rx;
      D2 := D2 + DX - DY + Int64(Rx) * Rx;
    End;
  End;
End;

Procedure TRipSurface.Circle (X, Y, Radius: Integer);
Begin
  RawEllipse (X, Y, Radius, Radius, RIP_EGA_PALETTE[FDraw], False);
End;

Procedure TRipSurface.Oval (X, Y, XRad, YRad: Integer);
Begin
  RawEllipse (X, Y, XRad, YRad, RIP_EGA_PALETTE[FDraw], False);
End;

Procedure TRipSurface.FilledOval (X, Y, XRad, YRad: Integer);
Begin
  RawEllipse (X, Y, XRad, YRad, RIP_EGA_PALETTE[FFill], True);
End;

// flood fill to a border color (explicit stack, no recursion)
Procedure TRipSurface.FloodFill (X, Y: Integer; Border: TRipColor);
{ Scanline flood fill with visited buffer — backport from ripviewer. }
Type
  TPt = Record PX, PY: Integer; End;
  TVisArr = Array[0..639, 0..349] Of Boolean;
  PVisArr = ^TVisArr;
Var
  Stack: Array[0..65535] Of TPt;
  Visited: PVisArr;
  SP, X1, X2, SX: Integer;
  SpanUp, SpanDn: Boolean;
  Bord, FillC, BgC: TRipRGB;

  Function Same(Const A, B: TRipRGB): Boolean; Inline;
  Begin Result := (A.R = B.R) And (A.G = B.G) And (A.B = B.B); End;

Begin
  If (X < 0) Or (X >= FW) Or (Y < 0) Or (Y >= FH) Then Exit;
  Bord  := RIP_EGA_PALETTE[Border And 15];
  FillC := RIP_EGA_PALETTE[FFill];
  BgC   := RIP_EGA_PALETTE[FBG];
  If Same(GetPixel(X, Y), Bord) Then Exit;

  New(Visited);
  FillChar(Visited^, SizeOf(TVisArr), 0);

  SP := 0;
  Stack[SP].PX := X; Stack[SP].PY := Y; Inc(SP);

  While SP > 0 Do Begin
    Dec(SP); X := Stack[SP].PX; Y := Stack[SP].PY;
    X1 := X;
    While (X1 >= 0) And (Not Same(GetPixel(X1, Y), Bord)) Do Dec(X1);
    Inc(X1);
    X2 := X + 1;
    While (X2 < FW) And (Not Same(GetPixel(X2, Y), Bord)) Do Inc(X2);
    Dec(X2);

    SpanUp := False; SpanDn := False;
    For SX := X1 to X2 Do Begin
      { Draw fill pixel with pattern bgcolor support }
      If FFillStyle <= 1 Then
        PutPixel(SX, Y, FillC)
      Else If FFillStyle <= 12 Then Begin
        If (FFillPat[Y And 7] Shr (7 - (SX And 7))) And 1 = 1 Then
          PutPixel(SX, Y, FillC)
        Else
          PutPixel(SX, Y, BgC);
      End;
      Visited^[SX, Y] := True;

      If (SX <= 0) Or (SX >= FW - 1) Then Continue;
      If (Not SpanUp) And (Y > 0) And
         (Not Same(GetPixel(SX, Y-1), Bord)) And (Not Visited^[SX, Y-1]) Then Begin
        If SP < 65535 Then Begin Stack[SP].PX := SX; Stack[SP].PY := Y-1; Inc(SP); End;
        SpanUp := True;
      End Else If SpanUp And (Y > 0) And Same(GetPixel(SX, Y-1), Bord) Then
        SpanUp := False;
      If (Not SpanDn) And (Y < FH-1) And
         (Not Same(GetPixel(SX, Y+1), Bord)) And (Not Visited^[SX, Y+1]) Then Begin
        If SP < 65535 Then Begin Stack[SP].PX := SX; Stack[SP].PY := Y+1; Inc(SP); End;
        SpanDn := True;
      End Else If SpanDn And (Y < FH-1) And Same(GetPixel(SX, Y+1), Bord) Then
        SpanDn := False;
    End;
  End;
  Dispose(Visited);
End;
Procedure TRipSurface.DrawChar (X, Y: Integer; Ch: Char; Const C: TRipRGB);
Var
  Row, Col : Integer;
  Bits     : Byte;
  O        : Integer;
Begin
  O := Ord(Ch);

  If (O < 32) Or (O > 127) Then
    O := Ord('?');

  For Row := 0 to 7 Do Begin
    Bits := FONT8X8[O][Row];

    For Col := 0 to 7 Do
      If (Bits And (128 Shr Col)) <> 0 Then
        PutPixel (X + Col, Y + Row, C);
  End;
End;

Procedure TRipSurface.WriteText (X, Y: Integer; Const S: AnsiString);
Var
  I, CX : Integer;
Begin
  CX := X;

  For I := 1 to Length(S) Do Begin
    DrawChar (CX, Y, S[I], RIP_EGA_PALETTE[FDraw]);
    Inc (CX, 8);
  End;
End;

Procedure TRipSurface.AddMouseRegion (Const R: TRipMouseRegion);
Begin
  SetLength (FRegions, Length(FRegions) + 1);
  FRegions[High(FRegions)] := R;
End;

Procedure TRipSurface.KillMouseRegions;
Begin
  SetLength (FRegions, 0);
End;

Function TRipSurface.RegionCount : Integer;
Begin
  Result := Length(FRegions);
End;

Function TRipSurface.Region (Idx: Integer) : TRipMouseRegion;
Begin
  Result := FRegions[Idx];
End;

// ---- Phase 3 implementations ----

Procedure TRipSurface.Arc (X, Y, StAngle, EndAngle, Radius: Integer);
Var A: Integer; Rad: Double; PX, PY: Integer;
Begin
  For A := StAngle to EndAngle Do Begin
    Rad := A * Pi / 180;
    PX := X + Round(Radius * Cos(Rad));
    PY := Y - Round(Radius * Sin(Rad));
    PutPixel(PX, PY, RIP_EGA_PALETTE[FDraw]);
  End;
End;

Procedure TRipSurface.OvalArc (X, Y, StAngle, EndAngle, XRad, YRad: Integer);
Var A: Integer; Rad: Double; PX, PY: Integer;
Begin
  For A := StAngle to EndAngle Do Begin
    Rad := A * Pi / 180;
    PX := X + Round(XRad * Cos(Rad));
    PY := Y - Round(YRad * Sin(Rad));
    PutPixel(PX, PY, RIP_EGA_PALETTE[FDraw]);
  End;
End;

Procedure TRipSurface.PieSlice (X, Y, StAngle, EndAngle, Radius: Integer);
Var A: Integer; Rad: Double; PX, PY: Integer;
Begin
  For A := StAngle to EndAngle Do Begin
    Rad := A * Pi / 180;
    PX := X + Round(Radius * Cos(Rad));
    PY := Y - Round(Radius * Sin(Rad));
    RawLine(X, Y, PX, PY, RIP_EGA_PALETTE[FFill]);
  End;
End;

Procedure TRipSurface.OvalPieSlice (X, Y, StAngle, EndAngle, XRad, YRad: Integer);
Var A: Integer; Rad: Double; PX, PY: Integer;
Begin
  For A := StAngle to EndAngle Do Begin
    Rad := A * Pi / 180;
    PX := X + Round(XRad * Cos(Rad));
    PY := Y - Round(YRad * Sin(Rad));
    RawLine(X, Y, PX, PY, RIP_EGA_PALETTE[FFill]);
  End;
End;

Procedure TRipSurface.Bezier (X1, Y1, X2, Y2, X3, Y3, X4, Y4, Count: Integer);
{ Bezier matched to JS: Floor() not Round(), explicit endpoint. Backport. }
Var T, T1, Step: Double; PX, PY, LX, LY: Integer;
Begin
  If Count < 2 Then Count := 20;
  LX := X1; LY := Y1;
  Step := 1.0 / Count;
  T := Step;
  While T < 1.0 Do Begin
    T1 := 1.0 - T;
    PX := Floor(T1*T1*T1*X1 + 3*T*T1*T1*X2 + 3*T*T*T1*X3 + T*T*T*X4);
    PY := Floor(T1*T1*T1*Y1 + 3*T*T1*T1*Y2 + 3*T*T*T1*Y3 + T*T*T*Y4);
    RawLine(LX, LY, PX, PY, RIP_EGA_PALETTE[FDraw]);
    LX := PX; LY := PY;
    T := T + Step;
  End;
  RawLine(LX, LY, X4, Y4, RIP_EGA_PALETTE[FDraw]);
End;

Procedure TRipSurface.Polygon (Var Points; NumPoints: Integer);
Type TPtArr = Array[0..999] of Record X, Y: Integer; End;
Var I: Integer;
Begin
  For I := 0 to NumPoints - 2 Do
    RawLine(TPtArr(Points)[I].X, TPtArr(Points)[I].Y,
            TPtArr(Points)[I+1].X, TPtArr(Points)[I+1].Y, RIP_EGA_PALETTE[FDraw]);
  If NumPoints > 2 Then
    RawLine(TPtArr(Points)[NumPoints-1].X, TPtArr(Points)[NumPoints-1].Y,
            TPtArr(Points)[0].X, TPtArr(Points)[0].Y, RIP_EGA_PALETTE[FDraw]);
End;

Procedure TRipSurface.FillPolygon (Var Points; NumPoints: Integer);
Begin
  Polygon(Points, NumPoints); { outline only for now }
End;

Procedure TRipSurface.Polyline (Var Points; NumPoints: Integer);
Type TPtArr = Array[0..999] of Record X, Y: Integer; End;
Var I: Integer;
Begin
  For I := 0 to NumPoints - 2 Do
    RawLine(TPtArr(Points)[I].X, TPtArr(Points)[I].Y,
            TPtArr(Points)[I+1].X, TPtArr(Points)[I+1].Y, RIP_EGA_PALETTE[FDraw]);
End;

Procedure TRipSurface.SetFillStyle (Pattern: Integer; Color: TRipColor);
Begin FFillStyle := Pattern; FFill := Color And 15; End;

Procedure TRipSurface.SetFillPattern (Var Pattern; Color: TRipColor);
Begin Move(Pattern, FFillPat, 8); FFill := Color And 15; End;

Procedure TRipSurface.SetFontStyle (Font, Direction, Size: Integer);
Begin FFontNum := Font; FFontDir := Direction; FFontSize := Size; End;

Procedure TRipSurface.SetPalette (Var Pal);
Begin { palette remapping - stub for now } End;

Procedure TRipSurface.SetOnePalette (Color, EGA64: Integer);
Begin { single palette entry - stub for now } End;

Procedure TRipSurface.SetViewPort (X0, Y0, X1, Y1: Integer; Clip: Boolean);
Begin FViewX0:=X0; FViewY0:=Y0; FViewX1:=X1; FViewY1:=Y1; End;

Procedure TRipSurface.TextWindow (X0, Y0, X1, Y1, Wrap: Integer);
Begin FTextX0:=X0; FTextY0:=Y0; FTextX1:=X1; FTextY1:=Y1; FTextCurX:=X0; FTextCurY:=Y0; End;

Procedure TRipSurface.ResetWindows;
Begin
  FViewX0:=0; FViewY0:=0; FViewX1:=FW-1; FViewY1:=FH-1;
  FTextX0:=0; FTextY0:=0; FTextX1:=FW-1; FTextY1:=FH-1;
  FTextCurX:=0; FTextCurY:=0;
  FDraw:=15; FFill:=0; FBg:=0; FWriteMode:=RIP_WM_COPY;
  KillMouseRegions;
  Clear;
End;

Procedure TRipSurface.GotoXY (X, Y: Integer);
Begin FTextCurX := X; FTextCurY := Y; End;

Procedure TRipSurface.Home;
Begin FTextCurX := FTextX0; FTextCurY := FTextY0; End;

Procedure TRipSurface.EraseEOL;
Begin Bar(FTextCurX, FTextCurY, FTextX1, FTextCurY + 7); End;

Procedure TRipSurface.EraseWindow;
Begin Bar(FTextX0, FTextY0, FTextX1, FTextY1); End;

Procedure TRipSurface.EraseView;
Begin Bar(FViewX0, FViewY0, FViewX1, FViewY1); End;

Procedure TRipSurface.GetImage (X0, Y0, X1, Y1: Integer);
Var X, Y: Integer;
Begin
  FClipW := X1 - X0 + 1; FClipH := Y1 - Y0 + 1;
  SetLength(FClipboard, FClipW * FClipH);
  For Y := Y0 to Y1 Do
    For X := X0 to X1 Do
      FClipboard[(Y-Y0)*FClipW + (X-X0)] := GetPixel(X, Y);
End;

Procedure TRipSurface.PutImage (X, Y, Mode: Integer);
Var PX, PY: Integer;
Begin
  If Length(FClipboard) = 0 Then Exit;
  For PY := 0 to FClipH - 1 Do
    For PX := 0 to FClipW - 1 Do
      PutPixel(X + PX, Y + PY, FClipboard[PY * FClipW + PX]);
End;

Procedure TRipSurface.WriteIcon (FileName: AnsiString);
Begin { write current clipboard to .ICN file - stub } End;

Procedure TRipSurface.LoadIcon (X, Y: Integer; FileName: AnsiString);
Begin { load .ICN file and blit at X,Y - stub } End;

Procedure TRipSurface.SetButtonStyle (Var Params);
Begin { button style parameters - stub } End;

Procedure TRipSurface.DrawButton (X0, Y0, X1, Y1: Integer; Const Params: AnsiString);
Begin
  Rectangle(X0, Y0, X1, Y1);
  RawLine(X0, Y0, X1, Y0, RIP_EGA_PALETTE[15]);
  RawLine(X0, Y0, X0, Y1, RIP_EGA_PALETTE[15]);
  RawLine(X1, Y0, X1, Y1, RIP_EGA_PALETTE[8]);
  RawLine(X0, Y1, X1, Y1, RIP_EGA_PALETTE[8]);
End;

Procedure TRipSurface.BeginText (X, Y, W, H: Integer);
Begin FTextX0:=X; FTextY0:=Y; FTextX1:=X+W; FTextY1:=Y+H; FTextCurX:=X; FTextCurY:=Y; FInText:=True; End;

Procedure TRipSurface.RegionText (Justify: Integer; Const S: AnsiString);
Begin WriteText(FTextCurX, FTextCurY, S); Inc(FTextCurY, 8); End;

Procedure TRipSurface.EndText;
Begin FInText := False; End;

// 24-bit BMP writer - renders the surface to an image with no display
Procedure TRipSurface.SaveBMP (Const FileName: String);
Var
  F        : TFileStream;
  RowSize  : Integer;
  Pad      : Integer;
  X, Y, I  : Integer;
  Hdr      : Array[0..53] of Byte;
  FileSize : LongWord;
  PX       : TRipRGB;
  B        : Byte;

  Procedure PutLE32 (Off: Integer; V: LongWord);
  Begin
    Hdr[Off]     := V And $FF;
    Hdr[Off + 1] := (V Shr 8) And $FF;
    Hdr[Off + 2] := (V Shr 16) And $FF;
    Hdr[Off + 3] := (V Shr 24) And $FF;
  End;

  Procedure PutLE16 (Off: Integer; V: Word);
  Begin
    Hdr[Off]     := V And $FF;
    Hdr[Off + 1] := (V Shr 8) And $FF;
  End;

Begin
  RowSize  := FW * 3;
  Pad      := (4 - (RowSize Mod 4)) Mod 4;
  FileSize := 54 + LongWord(RowSize + Pad) * LongWord(FH);

  FillChar (Hdr, SizeOf(Hdr), 0);

  Hdr[0] := Ord('B');
  Hdr[1] := Ord('M');

  PutLE32 (2, FileSize);
  PutLE32 (10, 54);
  PutLE32 (14, 40);
  PutLE32 (18, FW);
  PutLE32 (22, FH);
  PutLE16 (26, 1);
  PutLE16 (28, 24);

  F := TFileStream.Create(FileName, fmCreate);
  Try
    F.WriteBuffer (Hdr, 54);

    For Y := FH - 1 DownTo 0 Do Begin   // BMP is bottom-up
      For X := 0 to FW - 1 Do Begin
        PX := FPix[Y * FW + X];

        B := PX.B; F.WriteBuffer (B, 1);
        B := PX.G; F.WriteBuffer (B, 1);
        B := PX.R; F.WriteBuffer (B, 1);
      End;

      B := 0;

      For I := 1 to Pad Do
        F.WriteBuffer (B, 1);
    End;
  Finally
    F.Free;
  End;
End;

End.
