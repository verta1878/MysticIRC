Unit RIP_Graph;

// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================
//
// RIP_Graph: BGI-compatible software graphics engine for RIPscrip
//
// Provides a 640x350x16 virtual framebuffer with Borland BGI-compatible
// drawing primitives. All RIPscrip drawing commands map directly to
// this API. No hardware dependency — everything is software-rendered
// into an in-memory pixel array.
//
// Based on the Borland Graphics Interface (BGI) API with additions
// for RIPscrip-specific features (text windows, mouse regions, icons).
//
// Resolution: 640 x 350 (EGA standard, as per RIPscrip spec)
// Colors: 16 (EGA palette, remappable)
// Font: 8x8 bitmap default + BGI stroked vector fonts (.CHR)
//
// ====================================================================

{$I M_OPS.PAS}

Interface

Const
  { Screen dimensions — RIPscrip native resolution }
  RIP_MaxX = 639;
  RIP_MaxY = 1279;
  RIP_Width = 640;
  RIP_Height = 1280;

  { Colors }
  RIP_Black        = 0;
  RIP_Blue         = 1;
  RIP_Green        = 2;
  RIP_Cyan         = 3;
  RIP_Red          = 4;
  RIP_Magenta      = 5;
  RIP_Brown        = 6;
  RIP_LightGray    = 7;
  RIP_DarkGray     = 8;
  RIP_LightBlue    = 9;
  RIP_LightGreen   = 10;
  RIP_LightCyan    = 11;
  RIP_LightRed     = 12;
  RIP_LightMagenta = 13;
  RIP_Yellow       = 14;
  RIP_White        = 15;

  { Write modes }
  RIP_CopyPut = 0;
  RIP_XORPut  = 1;

  { Line styles }
  RIP_SolidLn    = 0;
  RIP_DottedLn   = 1;
  RIP_CenterLn   = 2;
  RIP_DashedLn   = 3;
  RIP_UserBitLn  = 4;

  { Line thickness }
  RIP_NormWidth  = 1;
  RIP_ThickWidth = 3;

  { Fill styles }
  RIP_EmptyFill      = 0;
  RIP_SolidFill      = 1;
  RIP_LineFill       = 2;
  RIP_LtSlashFill    = 3;
  RIP_SlashFill      = 4;
  RIP_BkSlashFill    = 5;
  RIP_LtBkSlashFill  = 6;
  RIP_HatchFill      = 7;
  RIP_XHatchFill     = 8;
  RIP_InterleaveFill = 9;
  RIP_WideDotFill    = 10;
  RIP_CloseDotFill   = 11;
  RIP_UserFill       = 12;

  { Font constants }
  RIP_DefaultFont = 0;
  RIP_TriplexFont = 1;
  RIP_SmallFont   = 2;
  RIP_SansSerifFont = 3;
  RIP_GothicFont  = 4;

  { Text direction }
  RIP_HorizDir = 0;
  RIP_VertDir  = 1;

  { PutImage modes }
  RIP_NormalPut = 0;
  RIP_CopyPut2  = 0;
  RIP_XORPut2   = 1;
  RIP_OrPut    = 2;
  RIP_AndPut   = 3;
  RIP_NotPut   = 4;

  { Maximum mouse regions }
  RIP_MaxMouse = 128;

  { Maximum clipboard images }
  RIP_MaxClipboard = 16;

Type
  { Viewport record }
  TRIPViewPort = Record
    X1, Y1, X2, Y2 : SmallInt;
    Clip            : Boolean;
  End;

  { Text window record }
  TRIPTextWindow = Record
    X1, Y1, X2, Y2 : SmallInt;
    Wrap            : Boolean;
    FontSize        : Byte;
    CurX, CurY     : SmallInt;
  End;

  { Fill pattern }
  TRIPFillPattern = Array[1..8] of Byte;

  { Mouse region }
  TRIPMouseRegion = Record
    Active          : Boolean;
    X1, Y1, X2, Y2 : SmallInt;
    HostCmd         : String[80];
    Invertable      : Boolean;
  End;

  { Clipboard image }
  TRIPClipboard = Record
    Active     : Boolean;
    Width      : SmallInt;
    Height     : SmallInt;
    Data       : Pointer;   { pixel data, Width * Height bytes }
  End;

  { BGI stroked font header }
  TRIPFontHeader = Record
    Loaded  : Boolean;
    Name    : String[80];
    // Additional fields filled when font is loaded
  End;

  { The graphics engine }
  TRIPGraphEngine = Class
  Private
    { Framebuffer — 640x350 pixels, 4 bits each, stored as bytes }
    FrameBuf     : Array[0..RIP_MaxY, 0..RIP_MaxX] of Byte;

    { State }
    FColor       : Byte;           { current drawing color }
    FBkColor     : Byte;           { background color }
    FWriteMode   : Byte;           { copy or XOR }
    FCurX, FCurY : SmallInt;       { current position (MoveTo) }
    FViewPort    : TRIPViewPort;   { graphics viewport }
    FTextWindow  : TRIPTextWindow; { text output window }
    FLineStyle   : Byte;           { line drawing style }
    FLinePattern : Word;           { user-defined line pattern }
    FLineThick   : Byte;           { line thickness }
    FFillStyle   : Byte;           { fill pattern index }
    FFillColor   : Byte;           { fill color }
    FFillPattern : TRIPFillPattern; { custom fill pattern }
    FFontNum     : Byte;           { current font }
    FFontDir     : Byte;           { text direction }
    FFontSize    : Byte;           { text magnification }
    FPalette     : Array[0..15] of Byte; { EGA palette mapping }

    { Mouse regions }
    FMouseRegions : Array[1..RIP_MaxMouse] of TRIPMouseRegion;
    FMouseCount   : Integer;

    { Clipboard }
    FClipboard    : Array[0..RIP_MaxClipboard-1] of TRIPClipboard;

    { Internal drawing helpers }
    Procedure RawPixel     (X, Y: SmallInt; Color: Byte);
    Function  GetRawPixel  (X, Y: SmallInt) : Byte;
    Procedure HLine        (X1, X2, Y: SmallInt; Color: Byte);
    Procedure VLine        (X, Y1, Y2: SmallInt; Color: Byte);
    Function  ClipX        (X: SmallInt) : SmallInt;
    Function  ClipY        (Y: SmallInt) : SmallInt;
    Function  InViewPort   (X, Y: SmallInt) : Boolean;
    Procedure PatternLine  (X1, Y, X2: SmallInt; Color: Byte; Row: Byte);

  Public
    Constructor Create;
    Destructor  Destroy; Override;

    { Initialization }
    Procedure InitGraph;
    Procedure CloseGraph;
    Procedure ClearDevice;

    { Pixel operations }
    Procedure PutPixel      (X, Y: SmallInt; Color: Byte);
    Function  GetPixel      (X, Y: SmallInt) : Byte;

    { Line drawing }
    Procedure Line          (X1, Y1, X2, Y2: SmallInt);
    Procedure LineTo        (X, Y: SmallInt);
    Procedure LineRel       (DX, DY: SmallInt);
    Procedure MoveTo        (X, Y: SmallInt);
    Procedure MoveRel       (DX, DY: SmallInt);

    { Shape drawing }
    Procedure Rectangle     (X1, Y1, X2, Y2: SmallInt);
    Procedure Bar           (X1, Y1, X2, Y2: SmallInt);
    Procedure Bar3D         (X1, Y1, X2, Y2: SmallInt; Depth: Word; Top: Boolean);
    Procedure Circle        (X, Y, Radius: SmallInt);
    Procedure Ellipse       (X, Y, StAngle, EndAngle, XRadius, YRadius: SmallInt);
    Procedure FillEllipse   (X, Y, XRadius, YRadius: SmallInt);
    Procedure Arc           (X, Y, StAngle, EndAngle, Radius: SmallInt);
    Procedure PieSlice      (X, Y, StAngle, EndAngle, Radius: SmallInt);
    Procedure Sector        (X, Y, StAngle, EndAngle, XRadius, YRadius: SmallInt);

    { Bezier (RIPscrip addition, not in BGI) }
    Procedure Bezier        (X1,Y1,X2,Y2,X3,Y3,X4,Y4: SmallInt; Segments: SmallInt);

    { Polygon }
    Procedure DrawPoly      (NumPoints: Word; Var PolyPoints);
    Procedure FillPoly      (NumPoints: Word; Var PolyPoints);

    { Flood fill }
    Procedure FloodFill     (X, Y: SmallInt; Border: Byte);

    { Text output }
    Procedure OutText       (S: String);
    Procedure OutTextXY     (X, Y: SmallInt; S: String);

    { Image operations }
    Function  ImageSize     (X1, Y1, X2, Y2: SmallInt) : LongInt;
    Procedure GetImage      (X1, Y1, X2, Y2: SmallInt; Var BitMap);
    Procedure PutImage      (X, Y: SmallInt; Var BitMap; BitBlt: Word);

    { Clipboard (RIPscrip addition) }
    Procedure ClipGet       (Index: Byte; X1, Y1, X2, Y2: SmallInt);
    Procedure ClipPut       (Index: Byte; X, Y: SmallInt; Mode: Byte);
    Procedure ClipFree      (Index: Byte);

    { State setters }
    Procedure SetColor      (Color: Byte);
    Procedure SetBkColor    (Color: Byte);
    Procedure SetWriteMode  (Mode: Byte);
    Procedure SetLineStyle  (LineStyle: Byte; Pattern: Word; Thickness: Byte);
    Procedure SetFillStyle  (Pattern: Byte; Color: Byte);
    Procedure SetFillPattern (Var Pattern: TRIPFillPattern; Color: Byte);
    Procedure SetTextStyle  (Font, Direction: Byte; CharSize: Byte);
    Procedure SetViewPort   (X1, Y1, X2, Y2: SmallInt; Clip: Boolean);
    Procedure SetPalette    (ColorNum, Color: Byte);
    Procedure SetAllPalette (Var Palette);

    { State getters }
    Function  GetColor      : Byte;
    Function  GetBkColor    : Byte;
    Function  GetMaxX       : SmallInt;
    Function  GetMaxY       : SmallInt;
    Function  GetX          : SmallInt;
    Function  GetY          : SmallInt;
    Procedure GetViewSettings (Var VP: TRIPViewPort);

    { Text window (RIPscrip addition) }
    Procedure SetTextWindow (X1, Y1, X2, Y2: SmallInt; Wrap: Boolean; Size: Byte);
    Procedure TextGotoXY    (X, Y: SmallInt);
    Procedure TextHome;
    Procedure EraseWindow;
    Procedure EraseEOL;
    Procedure EraseView;
    Procedure ResetWindows;

    { Mouse regions (RIPscrip addition) }
    Procedure AddMouseRegion  (X1, Y1, X2, Y2: SmallInt; HostCmd: String; Inv: Boolean);
    Procedure KillMouseFields;
    Function  CheckMouse      (X, Y: SmallInt) : Integer;

    { Framebuffer access }
    Function  GetFramePtr   : Pointer;
    Procedure GetScanLine   (Y: SmallInt; Var Buf);
  End;

Implementation

// ====================================================================
// Constructor / Destructor
// ====================================================================

Constructor TRIPGraphEngine.Create;
Begin
  Inherited Create;
  InitGraph;
End;

Destructor TRIPGraphEngine.Destroy;
Var
  I : Integer;
Begin
  For I := 0 to RIP_MaxClipboard - 1 Do
    ClipFree(I);
  Inherited Destroy;
End;

// ====================================================================
// Initialization
// ====================================================================

Procedure TRIPGraphEngine.InitGraph;
Var
  I : Integer;
Begin
  FColor      := RIP_White;
  FBkColor    := RIP_Black;
  FWriteMode  := RIP_CopyPut;
  FCurX       := 0;
  FCurY       := 0;
  FLineStyle  := RIP_SolidLn;
  FLinePattern := $FFFF;
  FLineThick  := RIP_NormWidth;
  FFillStyle  := RIP_SolidFill;
  FFillColor  := RIP_White;
  FFontNum    := RIP_DefaultFont;
  FFontDir    := RIP_HorizDir;
  FFontSize   := 1;

  For I := 0 to 15 Do
    FPalette[I] := I;

  FViewPort.X1   := 0;
  FViewPort.Y1   := 0;
  FViewPort.X2   := RIP_MaxX;
  FViewPort.Y2   := RIP_MaxY;
  FViewPort.Clip  := True;

  FTextWindow.X1 := 0;
  FTextWindow.Y1 := 0;
  FTextWindow.X2 := 79;
  FTextWindow.Y2 := 42;
  FTextWindow.Wrap := True;
  FTextWindow.FontSize := 8;
  FTextWindow.CurX := 0;
  FTextWindow.CurY := 0;

  FMouseCount := 0;

  For I := 0 to RIP_MaxClipboard - 1 Do Begin
    FClipboard[I].Active := False;
    FClipboard[I].Data   := Nil;
  End;

  ClearDevice;
End;

Procedure TRIPGraphEngine.CloseGraph;
Begin
  { nothing to release — framebuffer is static }
End;

Procedure TRIPGraphEngine.ClearDevice;
Begin
  FillChar(FrameBuf, SizeOf(FrameBuf), FBkColor);
  FCurX := 0;
  FCurY := 0;
End;

// ====================================================================
// Internal helpers
// ====================================================================

Function TRIPGraphEngine.ClipX (X: SmallInt) : SmallInt;
Begin
  If X < FViewPort.X1 Then Result := FViewPort.X1
  Else If X > FViewPort.X2 Then Result := FViewPort.X2
  Else Result := X;
End;

Function TRIPGraphEngine.ClipY (Y: SmallInt) : SmallInt;
Begin
  If Y < FViewPort.Y1 Then Result := FViewPort.Y1
  Else If Y > FViewPort.Y2 Then Result := FViewPort.Y2
  Else Result := Y;
End;

Function TRIPGraphEngine.InViewPort (X, Y: SmallInt) : Boolean;
Begin
  Result := (X >= FViewPort.X1) and (X <= FViewPort.X2) and
            (Y >= FViewPort.Y1) and (Y <= FViewPort.Y2);
End;

Procedure TRIPGraphEngine.RawPixel (X, Y: SmallInt; Color: Byte);
Begin
  If (X < 0) or (X > RIP_MaxX) or (Y < 0) or (Y > RIP_MaxY) Then Exit;
  If FViewPort.Clip and Not InViewPort(X, Y) Then Exit;

  Case FWriteMode of
    RIP_CopyPut : FrameBuf[Y, X] := Color;
    RIP_XORPut  : FrameBuf[Y, X] := FrameBuf[Y, X] XOR Color;
  End;
End;

Function TRIPGraphEngine.GetRawPixel (X, Y: SmallInt) : Byte;
Begin
  If (X < 0) or (X > RIP_MaxX) or (Y < 0) or (Y > RIP_MaxY) Then
    Result := 0
  Else
    Result := FrameBuf[Y, X];
End;

Procedure TRIPGraphEngine.HLine (X1, X2, Y: SmallInt; Color: Byte);
Var
  X, Tmp : SmallInt;
Begin
  If X1 > X2 Then Begin Tmp := X1; X1 := X2; X2 := Tmp; End;
  For X := X1 to X2 Do
    RawPixel(X, Y, Color);
End;

Procedure TRIPGraphEngine.VLine (X, Y1, Y2: SmallInt; Color: Byte);
Var
  Y, Tmp : SmallInt;
Begin
  If Y1 > Y2 Then Begin Tmp := Y1; Y1 := Y2; Y2 := Tmp; End;
  For Y := Y1 to Y2 Do
    RawPixel(X, Y, Color);
End;

Procedure TRIPGraphEngine.PatternLine (X1, Y, X2: SmallInt; Color: Byte; Row: Byte);
Var
  X, Tmp  : SmallInt;
  Pattern : Byte;
Begin
  If X1 > X2 Then Begin Tmp := X1; X1 := X2; X2 := Tmp; End;

  Case FFillStyle of
    RIP_EmptyFill : Exit;
    RIP_SolidFill : Begin HLine(X1, X2, Y, Color); Exit; End;
    RIP_UserFill  : Pattern := FFillPattern[Row];
  Else
    Pattern := $FF;  // TODO: predefined patterns
  End;

  For X := X1 to X2 Do
    If (Pattern SHR (7 - (X MOD 8))) AND 1 = 1 Then
      RawPixel(X, Y, Color);
End;

// ====================================================================
// Pixel operations
// ====================================================================

Procedure TRIPGraphEngine.PutPixel (X, Y: SmallInt; Color: Byte);
Begin
  RawPixel(X, Y, Color);
End;

Function TRIPGraphEngine.GetPixel (X, Y: SmallInt) : Byte;
Begin
  Result := GetRawPixel(X, Y);
End;

// ====================================================================
// Line drawing — Bresenham's algorithm
// ====================================================================

Procedure TRIPGraphEngine.Line (X1, Y1, X2, Y2: SmallInt);
Var
  DX, DY, SX, SY, Err, E2 : SmallInt;
Begin
  DX := Abs(X2 - X1);
  DY := Abs(Y2 - Y1);
  If X1 < X2 Then SX := 1 Else SX := -1;
  If Y1 < Y2 Then SY := 1 Else SY := -1;
  Err := DX - DY;

  While True Do Begin
    RawPixel(X1, Y1, FColor);

    If (X1 = X2) and (Y1 = Y2) Then Break;

    E2 := 2 * Err;
    If E2 > -DY Then Begin Dec(Err, DY); Inc(X1, SX); End;
    If E2 < DX  Then Begin Inc(Err, DX); Inc(Y1, SY); End;
  End;

  FCurX := X2;
  FCurY := Y2;
End;

Procedure TRIPGraphEngine.LineTo (X, Y: SmallInt);
Begin
  Line(FCurX, FCurY, X, Y);
End;

Procedure TRIPGraphEngine.LineRel (DX, DY: SmallInt);
Begin
  Line(FCurX, FCurY, FCurX + DX, FCurY + DY);
End;

Procedure TRIPGraphEngine.MoveTo (X, Y: SmallInt);
Begin
  FCurX := X;
  FCurY := Y;
End;

Procedure TRIPGraphEngine.MoveRel (DX, DY: SmallInt);
Begin
  Inc(FCurX, DX);
  Inc(FCurY, DY);
End;

// ====================================================================
// Shapes
// ====================================================================

Procedure TRIPGraphEngine.Rectangle (X1, Y1, X2, Y2: SmallInt);
Begin
  Line(X1, Y1, X2, Y1);
  Line(X2, Y1, X2, Y2);
  Line(X2, Y2, X1, Y2);
  Line(X1, Y2, X1, Y1);
End;

Procedure TRIPGraphEngine.Bar (X1, Y1, X2, Y2: SmallInt);
Var
  Y, Tmp : SmallInt;
Begin
  If Y1 > Y2 Then Begin Tmp := Y1; Y1 := Y2; Y2 := Tmp; End;
  For Y := Y1 to Y2 Do
    PatternLine(X1, Y, X2, FFillColor, (Y MOD 8) + 1);
End;

Procedure TRIPGraphEngine.Bar3D (X1, Y1, X2, Y2: SmallInt; Depth: Word; Top: Boolean);
Begin
  Bar(X1, Y1, X2, Y2);
  Rectangle(X1, Y1, X2, Y2);
  // 3D depth lines
  If Depth > 0 Then Begin
    Line(X2, Y1, X2 + Depth, Y1 - Depth);
    Line(X2 + Depth, Y1 - Depth, X2 + Depth, Y2 - Depth);
    Line(X2 + Depth, Y2 - Depth, X2, Y2);
    If Top Then
      Line(X1, Y1, X1 + Depth, Y1 - Depth);
  End;
End;

Procedure TRIPGraphEngine.Circle (X, Y, Radius: SmallInt);
Begin
  Ellipse(X, Y, 0, 360, Radius, Radius);
End;

Procedure TRIPGraphEngine.Ellipse (X, Y, StAngle, EndAngle, XRadius, YRadius: SmallInt);
Var
  A     : Integer;
  PX, PY : SmallInt;
  Rad   : Real;
Begin
  If StAngle = EndAngle Then Exit;
  If EndAngle = 0 Then EndAngle := 360;

  For A := StAngle to EndAngle Do Begin
    Rad := A * Pi / 180;
    PX := X + Round(XRadius * Cos(Rad));
    PY := Y - Round(YRadius * Sin(Rad));
    RawPixel(PX, PY, FColor);
  End;
End;

Procedure TRIPGraphEngine.FillEllipse (X, Y, XRadius, YRadius: SmallInt);
Var
  YY, XW : SmallInt;
  Ratio  : Real;
Begin
  If YRadius = 0 Then Exit;

  For YY := -YRadius to YRadius Do Begin
    Ratio := Sqrt(1.0 - (YY * YY) / (YRadius * YRadius));
    XW := Round(XRadius * Ratio);
    PatternLine(X - XW, Y + YY, X + XW, FFillColor, ((Y + YY) MOD 8) + 1);
  End;

  Ellipse(X, Y, 0, 360, XRadius, YRadius);
End;

Procedure TRIPGraphEngine.Arc (X, Y, StAngle, EndAngle, Radius: SmallInt);
Begin
  Ellipse(X, Y, StAngle, EndAngle, Radius, Radius);
End;

Procedure TRIPGraphEngine.PieSlice (X, Y, StAngle, EndAngle, Radius: SmallInt);
Begin
  Sector(X, Y, StAngle, EndAngle, Radius, Radius);
End;

Procedure TRIPGraphEngine.Sector (X, Y, StAngle, EndAngle, XRadius, YRadius: SmallInt);
Var
  Rad : Real;
  EX, EY : SmallInt;
Begin
  { Draw the arc }
  Ellipse(X, Y, StAngle, EndAngle, XRadius, YRadius);

  { Draw lines from center to arc endpoints }
  Rad := StAngle * Pi / 180;
  EX := X + Round(XRadius * Cos(Rad));
  EY := Y - Round(YRadius * Sin(Rad));
  Line(X, Y, EX, EY);

  Rad := EndAngle * Pi / 180;
  EX := X + Round(XRadius * Cos(Rad));
  EY := Y - Round(YRadius * Sin(Rad));
  Line(X, Y, EX, EY);
End;

// ====================================================================
// Bezier curve — RIPscrip addition (not in BGI)
// ====================================================================

Procedure TRIPGraphEngine.Bezier (X1,Y1,X2,Y2,X3,Y3,X4,Y4: SmallInt; Segments: SmallInt);
Var
  I       : SmallInt;
  T, T2, T3, MT, MT2, MT3 : Real;
  PX, PY, LX, LY : SmallInt;
Begin
  If Segments < 2 Then Segments := 20;

  LX := X1;
  LY := Y1;

  For I := 1 to Segments Do Begin
    T   := I / Segments;
    MT  := 1.0 - T;
    T2  := T * T;
    T3  := T2 * T;
    MT2 := MT * MT;
    MT3 := MT2 * MT;

    PX := Round(MT3 * X1 + 3 * MT2 * T * X2 + 3 * MT * T2 * X3 + T3 * X4);
    PY := Round(MT3 * Y1 + 3 * MT2 * T * Y2 + 3 * MT * T2 * Y3 + T3 * Y4);

    Line(LX, LY, PX, PY);
    LX := PX;
    LY := PY;
  End;
End;

// ====================================================================
// Polygon
// ====================================================================

Type
  TPointArray = Array[1..1024] of Record X, Y : SmallInt; End;

Procedure TRIPGraphEngine.DrawPoly (NumPoints: Word; Var PolyPoints);
Var
  Pts : TPointArray Absolute PolyPoints;
  I   : Word;
Begin
  For I := 1 to NumPoints - 1 Do
    Line(Pts[I].X, Pts[I].Y, Pts[I+1].X, Pts[I+1].Y);
End;

Procedure TRIPGraphEngine.FillPoly (NumPoints: Word; Var PolyPoints);
Var
  Pts : TPointArray Absolute PolyPoints;
Begin
  { Outline only for now — scanline fill is complex }
  DrawPoly(NumPoints, PolyPoints);
  { Close the polygon }
  If NumPoints >= 3 Then
    Line(Pts[NumPoints].X, Pts[NumPoints].Y, Pts[1].X, Pts[1].Y);
End;

// ====================================================================
// Flood fill — simple scanline seed fill
// ====================================================================

Procedure TRIPGraphEngine.FloodFill (X, Y: SmallInt; Border: Byte);

  Procedure Fill (FX, FY: SmallInt);
  Begin
    If (FX < 0) or (FX > RIP_MaxX) or (FY < 0) or (FY > RIP_MaxY) Then Exit;
    If FrameBuf[FY, FX] = Border Then Exit;
    If FrameBuf[FY, FX] = FColor Then Exit;

    FrameBuf[FY, FX] := FColor;

    Fill(FX + 1, FY);
    Fill(FX - 1, FY);
    Fill(FX, FY + 1);
    Fill(FX, FY - 1);
  End;

Begin
  If (X < 0) or (X > RIP_MaxX) or (Y < 0) or (Y > RIP_MaxY) Then Exit;
  Fill(X, Y);
End;

// ====================================================================
// Text output — 8x8 bitmap font (default)
// ====================================================================

Procedure TRIPGraphEngine.OutText (S: String);
Begin
  OutTextXY(FCurX, FCurY, S);
End;

Procedure TRIPGraphEngine.OutTextXY (X, Y: SmallInt; S: String);
Var
  I : Integer;
Begin
  { Placeholder — draws colored rectangles per character position.
    Full implementation needs the 8x8 bitmap font data and .CHR
    stroked font loader. }
  For I := 1 to Length(S) Do Begin
    // 8x8 character cell
    RawPixel(X + (I-1) * 8, Y, FColor);
    RawPixel(X + (I-1) * 8 + 7, Y + 7, FColor);
  End;

  If FFontDir = RIP_HorizDir Then
    FCurX := X + Length(S) * 8 * FFontSize
  Else
    FCurY := Y + Length(S) * 8 * FFontSize;
End;

// ====================================================================
// Image operations
// ====================================================================

Function TRIPGraphEngine.ImageSize (X1, Y1, X2, Y2: SmallInt) : LongInt;
Begin
  Result := (Abs(X2 - X1) + 1) * (Abs(Y2 - Y1) + 1) + 4;
End;

Procedure TRIPGraphEngine.GetImage (X1, Y1, X2, Y2: SmallInt; Var BitMap);
Var
  Buf : Array[0..0] of Byte Absolute BitMap;
  X, Y, Idx, W, H : SmallInt;
Begin
  { Store width and height in first 4 bytes }
  W := X2 - X1 + 1;
  H := Y2 - Y1 + 1;
  Buf[0] := Byte(W);
  Buf[1] := Byte(W SHR 8);
  Buf[2] := Byte(H);
  Buf[3] := Byte(H SHR 8);

  Idx := 4;
  For Y := Y1 to Y2 Do
    For X := X1 to X2 Do Begin
      Buf[Idx] := GetRawPixel(X, Y);
      Inc(Idx);
    End;
End;

Procedure TRIPGraphEngine.PutImage (X, Y: SmallInt; Var BitMap; BitBlt: Word);
Var
  Buf : Array[0..0] of Byte Absolute BitMap;
  W, H, PX, PY, Idx : SmallInt;
  Color : Byte;
Begin
  W := SmallInt(Buf[0]) + SmallInt(Buf[1]) * 256;
  H := SmallInt(Buf[2]) + SmallInt(Buf[3]) * 256;

  Idx := 4;
  For PY := 0 to H - 1 Do
    For PX := 0 to W - 1 Do Begin
      Color := Buf[Idx];
      Inc(Idx);

      Case BitBlt of
        0 : RawPixel(X + PX, Y + PY, Color);                          { Copy }
        1 : RawPixel(X + PX, Y + PY, GetRawPixel(X+PX, Y+PY) XOR Color); { XOR }
        2 : RawPixel(X + PX, Y + PY, GetRawPixel(X+PX, Y+PY) OR Color);  { OR }
        3 : RawPixel(X + PX, Y + PY, GetRawPixel(X+PX, Y+PY) AND Color); { AND }
        4 : RawPixel(X + PX, Y + PY, NOT Color AND $0F);              { NOT }
      End;
    End;
End;

// ====================================================================
// Clipboard (RIPscrip addition)
// ====================================================================

Procedure TRIPGraphEngine.ClipGet (Index: Byte; X1, Y1, X2, Y2: SmallInt);
Var
  W, H : SmallInt;
  Size : LongInt;
Begin
  If Index >= RIP_MaxClipboard Then Exit;

  ClipFree(Index);

  W := Abs(X2 - X1) + 1;
  H := Abs(Y2 - Y1) + 1;
  Size := W * H + 4;

  GetMem(FClipboard[Index].Data, Size);
  FClipboard[Index].Width  := W;
  FClipboard[Index].Height := H;
  FClipboard[Index].Active := True;

  GetImage(X1, Y1, X2, Y2, FClipboard[Index].Data^);
End;

Procedure TRIPGraphEngine.ClipPut (Index: Byte; X, Y: SmallInt; Mode: Byte);
Begin
  If Index >= RIP_MaxClipboard Then Exit;
  If Not FClipboard[Index].Active Then Exit;

  PutImage(X, Y, FClipboard[Index].Data^, Mode);
End;

Procedure TRIPGraphEngine.ClipFree (Index: Byte);
Begin
  If Index >= RIP_MaxClipboard Then Exit;
  If FClipboard[Index].Data <> Nil Then Begin
    FreeMem(FClipboard[Index].Data);
    FClipboard[Index].Data := Nil;
  End;
  FClipboard[Index].Active := False;
End;

// ====================================================================
// State setters
// ====================================================================

Procedure TRIPGraphEngine.SetColor (Color: Byte);
Begin FColor := Color AND $0F; End;

Procedure TRIPGraphEngine.SetBkColor (Color: Byte);
Begin FBkColor := Color AND $0F; End;

Procedure TRIPGraphEngine.SetWriteMode (Mode: Byte);
Begin FWriteMode := Mode; End;

Procedure TRIPGraphEngine.SetLineStyle (LineStyle: Byte; Pattern: Word; Thickness: Byte);
Begin
  FLineStyle  := LineStyle;
  FLinePattern := Pattern;
  FLineThick  := Thickness;
End;

Procedure TRIPGraphEngine.SetFillStyle (Pattern: Byte; Color: Byte);
Begin
  FFillStyle := Pattern;
  FFillColor := Color AND $0F;
End;

Procedure TRIPGraphEngine.SetFillPattern (Var Pattern: TRIPFillPattern; Color: Byte);
Begin
  FFillPattern := Pattern;
  FFillStyle   := RIP_UserFill;
  FFillColor   := Color AND $0F;
End;

Procedure TRIPGraphEngine.SetTextStyle (Font, Direction: Byte; CharSize: Byte);
Begin
  FFontNum := Font;
  FFontDir := Direction;
  FFontSize := CharSize;
  If FFontSize = 0 Then FFontSize := 1;
End;

Procedure TRIPGraphEngine.SetViewPort (X1, Y1, X2, Y2: SmallInt; Clip: Boolean);
Begin
  FViewPort.X1   := X1;
  FViewPort.Y1   := Y1;
  FViewPort.X2   := X2;
  FViewPort.Y2   := Y2;
  FViewPort.Clip  := Clip;
End;

Procedure TRIPGraphEngine.SetPalette (ColorNum, Color: Byte);
Begin
  If ColorNum <= 15 Then
    FPalette[ColorNum] := Color;
End;

Procedure TRIPGraphEngine.SetAllPalette (Var Palette);
Var
  Pal : Array[0..15] of Byte Absolute Palette;
  I   : Integer;
Begin
  For I := 0 to 15 Do
    FPalette[I] := Pal[I];
End;

// ====================================================================
// State getters
// ====================================================================

Function TRIPGraphEngine.GetColor : Byte;
Begin Result := FColor; End;

Function TRIPGraphEngine.GetBkColor : Byte;
Begin Result := FBkColor; End;

Function TRIPGraphEngine.GetMaxX : SmallInt;
Begin Result := RIP_MaxX; End;

Function TRIPGraphEngine.GetMaxY : SmallInt;
Begin Result := RIP_MaxY; End;

Function TRIPGraphEngine.GetX : SmallInt;
Begin Result := FCurX; End;

Function TRIPGraphEngine.GetY : SmallInt;
Begin Result := FCurY; End;

Procedure TRIPGraphEngine.GetViewSettings (Var VP: TRIPViewPort);
Begin
  VP := FViewPort;
End;

// ====================================================================
// Text window (RIPscrip addition)
// ====================================================================

Procedure TRIPGraphEngine.SetTextWindow (X1, Y1, X2, Y2: SmallInt; Wrap: Boolean; Size: Byte);
Begin
  FTextWindow.X1   := X1;
  FTextWindow.Y1   := Y1;
  FTextWindow.X2   := X2;
  FTextWindow.Y2   := Y2;
  FTextWindow.Wrap  := Wrap;
  FTextWindow.FontSize := Size;
  FTextWindow.CurX := 0;
  FTextWindow.CurY := 0;
End;

Procedure TRIPGraphEngine.TextGotoXY (X, Y: SmallInt);
Begin
  FTextWindow.CurX := X;
  FTextWindow.CurY := Y;
End;

Procedure TRIPGraphEngine.TextHome;
Begin
  FTextWindow.CurX := 0;
  FTextWindow.CurY := 0;
End;

Procedure TRIPGraphEngine.EraseWindow;
Var
  Y : SmallInt;
Begin
  For Y := FTextWindow.Y1 * 8 to FTextWindow.Y2 * 8 + 7 Do
    HLine(FTextWindow.X1 * 8, FTextWindow.X2 * 8 + 7, Y, FBkColor);
  TextHome;
End;

Procedure TRIPGraphEngine.EraseEOL;
Var
  Y, PX : SmallInt;
Begin
  PX := (FTextWindow.X1 + FTextWindow.CurX) * 8;
  For Y := (FTextWindow.Y1 + FTextWindow.CurY) * 8 to
           (FTextWindow.Y1 + FTextWindow.CurY) * 8 + 7 Do
    HLine(PX, FTextWindow.X2 * 8 + 7, Y, FBkColor);
End;

Procedure TRIPGraphEngine.EraseView;
Var
  Y : SmallInt;
Begin
  For Y := FViewPort.Y1 to FViewPort.Y2 Do
    HLine(FViewPort.X1, FViewPort.X2, Y, FBkColor);
End;

Procedure TRIPGraphEngine.ResetWindows;
Begin
  SetViewPort(0, 0, RIP_MaxX, RIP_MaxY, True);
  SetTextWindow(0, 0, 79, 42, True, 8);
  TextHome;
End;

// ====================================================================
// Mouse regions (RIPscrip addition)
// ====================================================================

Procedure TRIPGraphEngine.AddMouseRegion (X1, Y1, X2, Y2: SmallInt; HostCmd: String; Inv: Boolean);
Begin
  If FMouseCount >= RIP_MaxMouse Then Exit;

  Inc(FMouseCount);
  FMouseRegions[FMouseCount].Active     := True;
  FMouseRegions[FMouseCount].X1         := X1;
  FMouseRegions[FMouseCount].Y1         := Y1;
  FMouseRegions[FMouseCount].X2         := X2;
  FMouseRegions[FMouseCount].Y2         := Y2;
  FMouseRegions[FMouseCount].HostCmd    := HostCmd;
  FMouseRegions[FMouseCount].Invertable := Inv;
End;

Procedure TRIPGraphEngine.KillMouseFields;
Var
  I : Integer;
Begin
  For I := 1 to RIP_MaxMouse Do
    FMouseRegions[I].Active := False;
  FMouseCount := 0;
End;

Function TRIPGraphEngine.CheckMouse (X, Y: SmallInt) : Integer;
Var
  I : Integer;
Begin
  Result := 0;
  For I := FMouseCount DownTo 1 Do
    If FMouseRegions[I].Active Then
      If (X >= FMouseRegions[I].X1) and (X <= FMouseRegions[I].X2) and
         (Y >= FMouseRegions[I].Y1) and (Y <= FMouseRegions[I].Y2) Then Begin
        Result := I;
        Exit;
      End;
End;

// ====================================================================
// Framebuffer access
// ====================================================================

Function TRIPGraphEngine.GetFramePtr : Pointer;
Begin
  Result := @FrameBuf;
End;

Procedure TRIPGraphEngine.GetScanLine (Y: SmallInt; Var Buf);
Var
  Row : Array[0..RIP_MaxX] of Byte Absolute Buf;
Begin
  If (Y >= 0) and (Y <= RIP_MaxY) Then
    Move(FrameBuf[Y], Row, RIP_Width);
End;

// ====================================================================
// A7: Print API backport — works with v1/v2/v3 framebuffers
// Called by RIP PRINT command or sysop screen print hotkey
//
// Usage:
//   Engine.PrintScreen(pdBMP, 'screen.bmp', 300);  // BMP file
//   Engine.PrintScreen(pdPCL, 'LPT1', 300);        // HP LaserJet
//   Engine.PrintScreen(pdEscP, 'LPT1', 180);       // Epson dot-matrix
//   Engine.PrintScreen(pdPostScript, 'out.ps', 300); // PostScript file
//
// The framebuffer is palette-indexed (EGA 16-color). The print API
// handles palette lookup, DPI scaling, and dithering internally.
// ====================================================================
{
Procedure TRIPGraphEngine.PrintScreen (Driver: TPrnDriver;
                                        Device: String; DPI: Word);
Var
  Cfg  : TPrnConfig;
  Page : TPrnPage;
Begin
  PrnInitConfig(Cfg, Driver, DPI);
  Cfg.DeviceName := Device;
  PrnCalcArea(Cfg);
  PrnCreatePage(Cfg, Page);
  PrnRenderFrame(Page, @FrameBuf, RIP_Width, RIP_Height);
  PrnDitherPage(Page, pdFloydSteinberg);

  If PrnPrintPage(Cfg, Page) Then
    // success
  Else
    // print failed — device not available or write error
    ;

  PrnFreePage(Page);
End;
}

End.
