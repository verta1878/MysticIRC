{$MODE OBJFPC}{$H+}
unit mtripgfx;
{ mterm RIP Graphics Engine — BGI-compatible pixel rendering
  Draws into a 640x350 pixel buffer. Renders to FV TUI via
  half-block characters or exports to BMP.
  
  GPLv3 — FPC264IRC Contributors }

interface

const
  RIP_WIDTH  = 640;
  RIP_HEIGHT = 350;

type
  TRGBColor = record R, G, B: Byte; end;

  TRIPCanvas = class
  private
    FPixels: array[0..RIP_HEIGHT - 1, 0..RIP_WIDTH - 1] of Byte; { EGA palette index 0-15 }
    FFGColor: Byte;
    FBGColor: Byte;
    FFillColor: Byte;
    FFillStyle: Byte; { 0=empty, 1=solid, 2+=patterns }
    FLineStyle: Byte;
    FFontNum: Byte;    { 0=bitmap, 1-10=CHR vector fonts }
    FFontDir: Byte;    { 0=horizontal, 1=vertical }
    FFontSize: Byte;   { char size / scale index }
    FViewX1, FViewY1, FViewX2, FViewY2: Integer; { viewport }
    { ButtonStyle — set by |1B, used by |1U }
    FBtnValid: Boolean;
    FBtnWid, FBtnHgt: Integer;
    FBtnOrient: Byte;
    FBtnFlags: Word;
    FBtnBevSize: Byte;
    FBtnDFore, FBtnBright, FBtnDark, FBtnSurface, FBtnCorner: Byte;
    FCurX, FCurY: Integer; { current position for text }
    FPalette: array[0..15] of TRGBColor; { live palette, modifiable by |a and |Q }
    procedure HLine(X1, X2, Y: Integer; Color: Byte);
    procedure VLine(X, Y1, Y2: Integer; Color: Byte);
    procedure DrawBitmapChar(Value: Byte; X0, Y0: Integer);
    procedure DrawCHRChar(FontIdx: Byte; Value: Byte; X0, Y0: Integer);
  public
    constructor Create;
    procedure Clear(Color: Byte);
    procedure PutPixelRaw(X, Y: Integer; Color: Byte);
    function  GetPixelRaw(X, Y: Integer): Byte;
    
    { BGI primitives }
    procedure PutPixel(X, Y: Integer; Color: Byte);
    function  GetPixel(X, Y: Integer): Byte;
    procedure Line(X1, Y1, X2, Y2: Integer);
    procedure Rectangle(X1, Y1, X2, Y2: Integer);
    procedure Bar(X1, Y1, X2, Y2: Integer);
    procedure Circle(CX, CY, Radius: Integer);
    procedure Ellipse(CX, CY, RX, RY: Integer);
    procedure FilledEllipse(CX, CY, RX, RY: Integer);
    procedure Arc(CX, CY, StartAngle, EndAngle, Radius: Integer);
    procedure FloodFill(X, Y: Integer; Border: Byte);
    procedure OutTextXY(X, Y: Integer; const Text: String);
    procedure SetTextStyle(Font, Direction, CharSize: Integer);
    function  TextWidth(const Text: String): Integer;
    function  TextHeight: Integer;
    
    { State }
    procedure SetColor(Color: Byte);
    procedure SetFillStyle(Style, Color: Byte);
    procedure SetLineStyle(Style: Byte);
    procedure SetPaletteEntry(Index: Byte; R2, G2, B2: Byte);
    procedure SetViewport(X1, Y1, X2, Y2: Integer);
    procedure EraseView;
    
    { Font loading }
    function LoadCHRFont(FontNum: Byte): Boolean;
    
    { Export }
    procedure SaveBMP(const FileName: String);
    
    { Render to text buffer for FV display }
    procedure RenderToText(var Buf; BufW, BufH: Integer);
    
    property ForeColor: Byte read FFGColor write FFGColor;
    property BackColor: Byte read FBGColor write FBGColor;
    property FillColor: Byte read FFillColor;
    property CurX: Integer read FCurX write FCurX;
    property CurY: Integer read FCurY write FCurY;
    property ViewX1: Integer read FViewX1;
    property ViewY1: Integer read FViewY1;
    property ViewX2: Integer read FViewX2;
    property ViewY2: Integer read FViewY2;
    property BtnValid: Boolean read FBtnValid write FBtnValid;
    property BtnWid: Integer read FBtnWid write FBtnWid;
    property BtnHgt: Integer read FBtnHgt write FBtnHgt;
    property BtnOrient: Byte read FBtnOrient write FBtnOrient;
    property BtnFlags: Word read FBtnFlags write FBtnFlags;
    property BtnBevSize: Byte read FBtnBevSize write FBtnBevSize;
    property BtnDFore: Byte read FBtnDFore write FBtnDFore;
    property BtnBright: Byte read FBtnBright write FBtnBright;
    property BtnDark: Byte read FBtnDark write FBtnDark;
    property BtnSurface: Byte read FBtnSurface write FBtnSurface;
    property BtnCorner: Byte read FBtnCorner write FBtnCorner;
    property Pixels[X, Y: Integer]: Byte read GetPixelRaw write PutPixelRaw;
  end;

const
  { EGA 16-color palette (same as CGA/VGA default) }
  EGAPalette: array[0..15] of TRGBColor = (
    (R: $00; G: $00; B: $00),  { 0  Black }
    (R: $00; G: $00; B: $AA),  { 1  Blue }
    (R: $00; G: $AA; B: $00),  { 2  Green }
    (R: $00; G: $AA; B: $AA),  { 3  Cyan }
    (R: $AA; G: $00; B: $00),  { 4  Red }
    (R: $AA; G: $00; B: $AA),  { 5  Magenta }
    (R: $AA; G: $55; B: $00),  { 6  Brown }
    (R: $AA; G: $AA; B: $AA),  { 7  Light Gray }
    (R: $55; G: $55; B: $55),  { 8  Dark Gray }
    (R: $55; G: $55; B: $FF),  { 9  Light Blue }
    (R: $55; G: $FF; B: $55),  { 10 Light Green }
    (R: $55; G: $FF; B: $FF),  { 11 Light Cyan }
    (R: $FF; G: $55; B: $55),  { 12 Light Red }
    (R: $FF; G: $55; B: $FF),  { 13 Light Magenta }
    (R: $FF; G: $FF; B: $55),  { 14 Yellow }
    (R: $FF; G: $FF; B: $FF)   { 15 White }
  );

  { BGI fill patterns — 13 standard 8x8 bit patterns }
  FillPatterns: array[0..12, 0..7] of Byte = (
    ($00,$00,$00,$00,$00,$00,$00,$00),  { 0  EMPTY }
    ($FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF),  { 1  SOLID }
    ($FF,$FF,$FF,$FF,$00,$00,$00,$00),  { 2  LINE }
    ($01,$02,$04,$08,$10,$20,$40,$80),  { 3  LTSLASH }
    ($03,$06,$0C,$18,$30,$60,$C0,$81),  { 4  SLASH }
    ($C0,$60,$30,$18,$0C,$06,$03,$81),  { 5  BKSLASH }
    ($80,$40,$20,$10,$08,$04,$02,$01),  { 6  LTBKSLASH }
    ($FF,$00,$FF,$00,$FF,$00,$FF,$00),  { 7  HATCH }
    ($55,$AA,$55,$AA,$55,$AA,$55,$AA),  { 8  XHATCH }
    ($CC,$33,$CC,$33,$CC,$33,$CC,$33),  { 9  INTERLEAVE }
    ($80,$00,$08,$00,$80,$00,$08,$00),  { 10 WIDE_DOT }
    ($88,$00,$22,$00,$88,$00,$22,$00),  { 11 CLOSE_DOT }
    ($FF,$00,$00,$00,$FF,$00,$00,$00)   { 12 USER }
  );

implementation

uses SysUtils, Classes, Math;

const
  CHR_MAX_CHARS   = 256;
  CHR_MAX_STROKES = 16384;

  CHRFontNames: array[1..10] of String[8] = (
    'TRIP','LITT','SANS','GOTH','SCRI',
    'SIMP','TSCR','LCOM','EURO','BOLD'
  );

  FontScales: array[0..10] of Double = (
    1.0, 0.6, 0.667, 0.75, 1.0, 1.333, 1.667, 2.0, 2.5, 3.0, 4.0
  );

type
  TCHRStroke = record Op: Byte; X, Y: SmallInt; end;
  TCHRFont = record
    Loaded: Boolean;
    FirstChar: Byte;
    NumChars: Word;
    OrgToCap, OrgToBase, OrgToDec: SmallInt;
    Widths: array[0..CHR_MAX_CHARS-1] of Byte;
    Offsets: array[0..CHR_MAX_CHARS-1] of Word;
    Strokes: array[0..CHR_MAX_STROKES-1] of TCHRStroke;
    NumStrokes: Word;
  end;
  PCHRFont = ^TCHRFont;

var
  CHRFonts: array[1..10] of PCHRFont;
  FontsInit: Boolean = False;
  FontPath: String = 'fonts' + DirectorySeparator;

{$I rip_font8x8.inc}

constructor TRIPCanvas.Create;
var I: Integer;
begin
  inherited;
  Clear(0);
  FFGColor := 15;
  FBGColor := 0;
  FFillColor := 0;
  FFillStyle := 1;
  FLineStyle := 0;
  FFontNum := 0;
  FFontDir := 0;
  FFontSize := 1;
  FCurX := 0;
  FCurY := 0;
  FViewX1 := 0; FViewY1 := 0;
  FViewX2 := RIP_WIDTH - 1; FViewY2 := RIP_HEIGHT - 1;
  { Init palette from EGA defaults }
  for I := 0 to 15 do begin
    FPalette[I].R := EGAPalette[I].R;
    FPalette[I].G := EGAPalette[I].G;
    FPalette[I].B := EGAPalette[I].B;
  end;
  FViewX2 := RIP_WIDTH - 1; FViewY2 := RIP_HEIGHT - 1;
  if not FontsInit then begin
    for I := 1 to 10 do CHRFonts[I] := nil;
    FontsInit := True;
  end;
end;

procedure TRIPCanvas.Clear(Color: Byte);
begin
  FillChar(FPixels, SizeOf(FPixels), Color);
end;

procedure TRIPCanvas.PutPixelRaw(X, Y: Integer; Color: Byte);
begin
  if (X >= 0) and (X < RIP_WIDTH) and (Y >= 0) and (Y < RIP_HEIGHT) then
    FPixels[Y, X] := Color;
end;

function TRIPCanvas.GetPixelRaw(X, Y: Integer): Byte;
begin
  if (X >= 0) and (X < RIP_WIDTH) and (Y >= 0) and (Y < RIP_HEIGHT) then
    Result := FPixels[Y, X]
  else
    Result := 0;
end;

procedure TRIPCanvas.PutPixel(X, Y: Integer; Color: Byte);
{ Apply viewport offset — matches JS _putpixel behavior }
begin
  PutPixelRaw(X + FViewX1, Y + FViewY1, Color);
end;

function TRIPCanvas.GetPixel(X, Y: Integer): Byte;
{ Apply viewport offset — matches JS getpixel behavior }
begin
  Result := GetPixelRaw(X + FViewX1, Y + FViewY1);
end;

procedure TRIPCanvas.SetViewport(X1, Y1, X2, Y2: Integer);
begin
  FViewX1 := X1; FViewY1 := Y1;
  FViewX2 := X2; FViewY2 := Y2;
end;

procedure TRIPCanvas.EraseView;
{ Erase viewport area — uses absolute coords directly }
var X, Y: Integer;
begin
  for Y := FViewY1 to FViewY2 do
    for X := FViewX1 to FViewX2 do
      if (X >= 0) and (X < RIP_WIDTH) and (Y >= 0) and (Y < RIP_HEIGHT) then
        FPixels[Y, X] := 0;
end;

procedure TRIPCanvas.HLine(X1, X2, Y: Integer; Color: Byte);
var X, T: Integer;
begin
  if X1 > X2 then begin T := X1; X1 := X2; X2 := T; end;
  for X := X1 to X2 do PutPixelRaw(X, Y, Color);
end;

procedure TRIPCanvas.VLine(X, Y1, Y2: Integer; Color: Byte);
var Y, T: Integer;
begin
  if Y1 > Y2 then begin T := Y1; Y1 := Y2; Y2 := T; end;
  for Y := Y1 to Y2 do PutPixelRaw(X, Y, Color);
end;

procedure TRIPCanvas.SetColor(Color: Byte);
begin FFGColor := Color; end;

procedure TRIPCanvas.SetFillStyle(Style, Color: Byte);
begin FFillStyle := Style; FFillColor := Color; end;

procedure TRIPCanvas.SetLineStyle(Style: Byte);
begin FLineStyle := Style; end;

procedure TRIPCanvas.SetPaletteEntry(Index: Byte; R2, G2, B2: Byte);
{ R2/G2/B2 are 2-bit values (0-3). Convert to 8-bit: 0→0, 1→$55, 2→$AA, 3→$FF }
const LUT: array[0..3] of Byte = ($00, $55, $AA, $FF);
begin
  if Index > 15 then Exit;
  FPalette[Index].R := LUT[R2 and 3];
  FPalette[Index].G := LUT[G2 and 3];
  FPalette[Index].B := LUT[B2 and 3];
end;

procedure TRIPCanvas.Line(X1, Y1, X2, Y2: Integer);
{ JS-matched Bresenham (den/num/numadd) with line dash patterns. }
var
  DX, DY, XI1, XI2, YI1, YI2: Integer;
  Den, Num, NumAdd, NumPixels: Integer;
  X, Y, C, AX, AY: Integer;
  Pat: Word;
begin
  case FLineStyle of
    1: Pat := $CCCC; { dotted }
    2: Pat := $FC78; { center }
    3: Pat := $F8F8; { dashed }
  else
    Pat := $FFFF;    { solid }
  end;

  DX := Abs(X2 - X1); DY := Abs(Y2 - Y1);
  if X2 >= X1 then begin XI1 := 1; XI2 := 1; end
  else begin XI1 := -1; XI2 := -1; end;
  if Y2 >= Y1 then begin YI1 := 1; YI2 := 1; end
  else begin YI1 := -1; YI2 := -1; end;
  if DX >= DY then begin
    XI1 := 0; YI2 := 0;
    Den := DX; Num := DX shr 1; NumAdd := DY; NumPixels := DX;
  end else begin
    XI2 := 0; YI1 := 0;
    Den := DY; Num := DY shr 1; NumAdd := DX; NumPixels := DY;
  end;
  X := X1; Y := Y1;
  for C := 0 to NumPixels do begin
    if (Pat shr (C and 15)) and 1 = 1 then begin
      AX := X + FViewX1; AY := Y + FViewY1;
      if (AX >= 0) and (AX < RIP_WIDTH) and (AY >= 0) and (AY < RIP_HEIGHT) then
        FPixels[AY, AX] := FFGColor;
    end;
    Inc(Num, NumAdd);
    if Num >= Den then begin Dec(Num, Den); Inc(X, XI1); Inc(Y, YI1); end;
    Inc(X, XI2); Inc(Y, YI2);
  end;
end;

procedure TRIPCanvas.Rectangle(X1, Y1, X2, Y2: Integer);
begin
  HLine(X1, X2, Y1, FFGColor);
  HLine(X1, X2, Y2, FFGColor);
  VLine(X1, Y1, Y2, FFGColor);
  VLine(X2, Y1, Y2, FFGColor);
end;

procedure TRIPCanvas.Bar(X1, Y1, X2, Y2: Integer);
{ Fill rectangle with current fill pattern. Draws BG for pattern gaps. }
var X, Y, T, AX, AY: Integer; PatRow: Byte;
begin
  if Y1 > Y2 then begin T := Y1; Y1 := Y2; Y2 := T; end;
  if X1 > X2 then begin T := X1; X1 := X2; X2 := T; end;
  for Y := Y1 to Y2 do
    for X := X1 to X2 do begin
      AX := X + FViewX1; AY := Y + FViewY1;
      if (AX >= 0) and (AX < RIP_WIDTH) and (AY >= 0) and (AY < RIP_HEIGHT) then begin
        if FFillStyle = 0 then
          FPixels[AY, AX] := FBGColor
        else if FFillStyle = 1 then
          FPixels[AY, AX] := FFillColor
        else if FFillStyle <= 12 then begin
          PatRow := FillPatterns[FFillStyle, AY and 7];
          if (PatRow shr (7 - (AX and 7))) and 1 = 1 then
            FPixels[AY, AX] := FFillColor
          else
            FPixels[AY, AX] := FBGColor;
        end;
      end;
    end;
end;

procedure TRIPCanvas.Circle(CX, CY, Radius: Integer);
var X, Y, D: Integer;
begin
  { Midpoint circle algorithm }
  X := 0; Y := Radius; D := 1 - Radius;
  while X <= Y do begin
    PutPixelRaw(CX + X, CY + Y, FFGColor);
    PutPixelRaw(CX - X, CY + Y, FFGColor);
    PutPixelRaw(CX + X, CY - Y, FFGColor);
    PutPixelRaw(CX - X, CY - Y, FFGColor);
    PutPixelRaw(CX + Y, CY + X, FFGColor);
    PutPixelRaw(CX - Y, CY + X, FFGColor);
    PutPixelRaw(CX + Y, CY - X, FFGColor);
    PutPixelRaw(CX - Y, CY - X, FFGColor);
    Inc(X);
    if D < 0 then D := D + 2 * X + 1
    else begin Dec(Y); D := D + 2 * (X - Y) + 1; end;
  end;
end;

procedure TRIPCanvas.Ellipse(CX, CY, RX, RY: Integer);
var X, Y: Integer; RX2, RY2: Int64; PX, PY, P: Int64;
begin
  if (RX = 0) or (RY = 0) then Exit;
  RX2 := Int64(RX) * RX; RY2 := Int64(RY) * RY;
  X := 0; Y := RY;
  PX := 0; PY := 2 * RX2 * Y;
  
  PutPixelRaw(CX, CY + Y, FFGColor);
  PutPixelRaw(CX, CY - Y, FFGColor);
  
  P := RY2 - RX2 * RY + RX2 div 4;
  while PX < PY do begin
    Inc(X); PX := PX + 2 * RY2;
    if P < 0 then P := P + RY2 + PX
    else begin Dec(Y); PY := PY - 2 * RX2; P := P + RY2 + PX - PY; end;
    PutPixelRaw(CX + X, CY + Y, FFGColor);
    PutPixelRaw(CX - X, CY + Y, FFGColor);
    PutPixelRaw(CX + X, CY - Y, FFGColor);
    PutPixelRaw(CX - X, CY - Y, FFGColor);
  end;
  
  P := RY2 * (Int64(X) * X + X) + RX2 * (Int64(Y - 1) * (Y - 1)) - RX2 * RY2;
  while Y > 0 do begin
    Dec(Y); PY := PY - 2 * RX2;
    if P > 0 then P := P + RX2 - PY
    else begin Inc(X); PX := PX + 2 * RY2; P := P + RX2 - PY + PX; end;
    PutPixelRaw(CX + X, CY + Y, FFGColor);
    PutPixelRaw(CX - X, CY + Y, FFGColor);
    PutPixelRaw(CX + X, CY - Y, FFGColor);
    PutPixelRaw(CX - X, CY - Y, FFGColor);
  end;
end;

procedure TRIPCanvas.FilledEllipse(CX, CY, RX, RY: Integer);
var Y: Integer; X2: Integer; RX2, RY2: Int64;
begin
  if (RX = 0) or (RY = 0) then Exit;
  RX2 := Int64(RX) * RX; RY2 := Int64(RY) * RY;
  for Y := -RY to RY do begin
    X2 := Round(RX * Sqrt(1.0 - (Int64(Y) * Y) / RY2));
    HLine(CX - X2, CX + X2, CY + Y, FFillColor);
  end;
end;

procedure TRIPCanvas.Arc(CX, CY, StartAngle, EndAngle, Radius: Integer);
var A: Integer; X, Y: Integer;
begin
  A := StartAngle;
  while A <= EndAngle do begin
    X := CX + Round(Radius * Cos(A * Pi / 180));
    Y := CY - Round(Radius * Sin(A * Pi / 180));
    PutPixelRaw(X, Y, FFGColor);
    Inc(A);
  end;
end;

procedure TRIPCanvas.FloodFill(X, Y: Integer; Border: Byte);
{ Scanline flood fill — viewport-relative coordinates.
  Reads via viewport-offset (GetPixel), writes at absolute position.
  Visited buffer uses viewport-relative coords. }
type
  TPt = record PX, PY: Integer; end;
  TVisArr = array[0..639, 0..349] of Boolean;
  PVisArr = ^TVisArr;
var
  Stack: array[0..65535] of TPt;
  Visited: PVisArr;
  SP, X1, X2, SX, AX, AY: Integer;
  SpanUp, SpanDn: Boolean;
  VW, VH: Integer;
  PatRow: Byte;
begin
  VW := FViewX2 - FViewX1 + 1;
  VH := FViewY2 - FViewY1 + 1;
  if (X < 0) or (X >= VW) or (Y < 0) or (Y >= VH) then Exit;

  { Read seed pixel at viewport-offset position }
  AX := X + FViewX1; AY := Y + FViewY1;
  if (AX < 0) or (AX >= RIP_WIDTH) or (AY < 0) or (AY >= RIP_HEIGHT) then Exit;
  if FPixels[AY, AX] = Border then Exit;

  New(Visited);
  FillChar(Visited^, SizeOf(TVisArr), 0);

  SP := 0;
  Stack[SP].PX := X; Stack[SP].PY := Y; Inc(SP);

  while SP > 0 do begin
    Dec(SP); X := Stack[SP].PX; Y := Stack[SP].PY;

    { Scan left }
    X1 := X;
    while (X1 >= 0) do begin
      AX := X1 + FViewX1; AY := Y + FViewY1;
      if (AX < 0) or (AX >= RIP_WIDTH) or (AY < 0) or (AY >= RIP_HEIGHT) then Break;
      if FPixels[AY, AX] = Border then Break;
      Dec(X1);
    end;
    Inc(X1);

    { Scan right }
    X2 := X + 1;
    while (X2 < VW) do begin
      AX := X2 + FViewX1; AY := Y + FViewY1;
      if (AX < 0) or (AX >= RIP_WIDTH) or (AY < 0) or (AY >= RIP_HEIGHT) then Break;
      if FPixels[AY, AX] = Border then Break;
      Inc(X2);
    end;
    Dec(X2);

    SpanUp := False; SpanDn := False;
    AY := Y + FViewY1;
    for SX := X1 to X2 do begin
      AX := SX + FViewX1;
      { Draw fill pixel with pattern + bgcolor }
      if (AX >= 0) and (AX < RIP_WIDTH) and (AY >= 0) and (AY < RIP_HEIGHT) then begin
        if FFillStyle <= 1 then
          FPixels[AY, AX] := FFillColor
        else if FFillStyle <= 12 then begin
          PatRow := FillPatterns[FFillStyle, AY and 7];
          if (PatRow shr (7 - (AX and 7))) and 1 = 1 then
            FPixels[AY, AX] := FFillColor
          else
            FPixels[AY, AX] := FBGColor;
        end;
      end;
      Visited^[SX, Y] := True;

      if (SX <= 0) or (SX >= VW - 1) then Continue;

      { Check row above }
      if (not SpanUp) and (Y > 0) then begin
        AX := SX + FViewX1;
        if (AX >= 0) and (AX < RIP_WIDTH) and (AY-1 >= 0) then
          if (FPixels[AY-1, AX] <> Border) and (not Visited^[SX, Y-1]) then begin
            if SP < 65535 then begin Stack[SP].PX := SX; Stack[SP].PY := Y-1; Inc(SP); end;
            SpanUp := True;
          end;
      end else if SpanUp and (Y > 0) then begin
        AX := SX + FViewX1;
        if (AX >= 0) and (AX < RIP_WIDTH) and (AY-1 >= 0) then
          if FPixels[AY-1, AX] = Border then SpanUp := False;
      end;

      { Check row below }
      if (not SpanDn) and (Y < VH-1) then begin
        AX := SX + FViewX1;
        if (AX >= 0) and (AX < RIP_WIDTH) and (AY+1 < RIP_HEIGHT) then
          if (FPixels[AY+1, AX] <> Border) and (not Visited^[SX, Y+1]) then begin
            if SP < 65535 then begin Stack[SP].PX := SX; Stack[SP].PY := Y+1; Inc(SP); end;
            SpanDn := True;
          end;
      end else if SpanDn and (Y < VH-1) then begin
        AX := SX + FViewX1;
        if (AX >= 0) and (AX < RIP_WIDTH) and (AY+1 < RIP_HEIGHT) then
          if FPixels[AY+1, AX] = Border then SpanDn := False;
      end;
    end;
  end;
  Dispose(Visited);
end;

{ === Font System — backported from ripviewer === }

procedure TRIPCanvas.DrawBitmapChar(Value: Byte; X0, Y0: Integer);
var Scale, X, Y: Integer; ScanLine: Byte;
begin
  Scale := FFontSize;
  if Scale < 1 then Scale := 1;
  for Y := 0 to 7 do begin
    ScanLine := Font8x8[Value * 8 + Y];
    for X := 0 to 7 do begin
      if (ScanLine and $80) <> 0 then begin
        if Scale > 1 then begin
          if FFontDir = 0 then
            Bar(X0 + X*Scale, Y0 + Y*Scale, X0 + X*Scale + Scale-1, Y0 + Y*Scale + Scale-1)
          else
            Bar(X0 + Y*Scale, Y0 - X*Scale, X0 + Y*Scale + Scale-1, Y0 - X*Scale + Scale-1);
        end else begin
          if FFontDir = 0 then PutPixelRaw(X0+X, Y0+Y, FFGColor)
          else PutPixelRaw(X0+Y, Y0-X, FFGColor);
        end;
      end;
      ScanLine := ScanLine shl 1;
    end;
  end;
  if FFontDir = 0 then FCurX := X0 + 8 * Scale
  else FCurY := Y0 - 8 * Scale;
end;

procedure TRIPCanvas.DrawCHRChar(FontIdx: Byte; Value: Byte; X0, Y0: Integer);
var
  CharIdx, DX, DY, PenX, PenY, DestX, DestY, J: Integer;
  ActualScale: Double;
  StrokeOff: Word;
begin
  if (FontIdx < 1) or (FontIdx > 10) then Exit;
  if CHRFonts[FontIdx] = nil then Exit;
  if not CHRFonts[FontIdx]^.Loaded then Exit;
  if FFontSize <= 10 then ActualScale := FontScales[FFontSize]
  else ActualScale := 1.0;
  with CHRFonts[FontIdx]^ do begin
    CharIdx := Value - FirstChar;
    if (CharIdx < 0) or (CharIdx >= NumChars) then Exit;
    StrokeOff := Offsets[CharIdx];
    PenX := X0; PenY := Y0;
    J := StrokeOff;
    while J < NumStrokes do begin
      DX := Trunc(Strokes[J].X * ActualScale);
      DY := Trunc(Strokes[J].Y * ActualScale);
      if FFontDir = 0 then begin
        DestX := X0 + DX; DestY := Y0 - DY;
      end else begin
        DestX := X0 - DY; DestY := Y0 - DX;
      end;
      case Strokes[J].Op of
        0: Break;
        1: begin PenX := DestX; PenY := DestY; end;
        2: begin Line(PenX, PenY, DestX, DestY); PenX := DestX; PenY := DestY; end;
      end;
      Inc(J);
    end;
    if FFontDir = 0 then begin
      FCurX := X0 + Trunc(Widths[CharIdx] * ActualScale);
      FCurY := Y0;
    end else begin
      FCurX := X0;
      FCurY := Y0 + Trunc(Widths[CharIdx] * ActualScale);
    end;
  end;
end;

function TRIPCanvas.LoadCHRFont(FontNum: Byte): Boolean;
type TLoadBuf = array[0..32767] of Byte; PLoadBuf = ^TLoadBuf;
var
  F: File; Data: PLoadBuf; FileLen: LongInt;
  I, FPos, PathIdx, PlusOff, OtStart, WtStart: Integer;
  NC: Word; FC, B1, B2, Op: Byte;
  SX, SY: SmallInt; FileName: String;
begin
  Result := False;
  if (FontNum < 1) or (FontNum > 10) then Exit;
  if (CHRFonts[FontNum] <> nil) and CHRFonts[FontNum]^.Loaded then begin
    Result := True; Exit;
  end;
  FileName := '';
  for PathIdx := 0 to 2 do begin
    case PathIdx of
      0: FileName := FontPath + CHRFontNames[FontNum] + '.CHR';
      1: FileName := '..' + DirectorySeparator + FontPath + CHRFontNames[FontNum] + '.CHR';
      2: FileName := CHRFontNames[FontNum] + '.CHR';
    end;
    if FileExists(FileName) then Break;
    FileName := '';
  end;
  if FileName = '' then Exit;
  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  New(Data);
  FileLen := FileSize(F);
  if FileLen > SizeOf(Data^) then FileLen := SizeOf(Data^);
  BlockRead(F, Data^, FileLen);
  Close(F);
  PlusOff := -1;
  for I := 80 to FileLen - 20 do
    if Data^[I] = $2B then begin
      NC := Data^[I+1] or (Data^[I+2] shl 8);
      FC := Data^[I+4];
      if (NC >= 32) and (NC <= 256) and (FC >= 32) and (FC <= 127) then begin
        PlusOff := I; Break;
      end;
    end;
  if PlusOff < 0 then begin Dispose(Data); Exit; end;
  if CHRFonts[FontNum] <> nil then Dispose(CHRFonts[FontNum]);
  New(CHRFonts[FontNum]);
  with CHRFonts[FontNum]^ do begin
    Loaded := True; NumChars := NC; FirstChar := FC;
    OrgToCap := SmallInt(Data^[PlusOff + 8]);
    OrgToBase := SmallInt(Data^[PlusOff + 9]);
    OrgToDec := SmallInt(Data^[PlusOff + 10]);
    OtStart := PlusOff + 16;
    for I := 0 to NumChars - 1 do
      if I < CHR_MAX_CHARS then
        Offsets[I] := Data^[OtStart + I*2] or (Data^[OtStart + I*2 + 1] shl 8);
    WtStart := OtStart + NumChars * 2;
    for I := 0 to NumChars - 1 do
      if I < CHR_MAX_CHARS then
        Widths[I] := Data^[WtStart + I];
    NumStrokes := 0;
    for I := 0 to NumChars - 1 do begin
      if I >= CHR_MAX_CHARS then Break;
      Offsets[I] := NumStrokes;
      FPos := WtStart + NumChars +
              (Data^[OtStart + I*2] or (Data^[OtStart + I*2 + 1] shl 8));
      repeat
        if (FPos + 1 >= FileLen) or (NumStrokes >= CHR_MAX_STROKES) then Break;
        B1 := Data^[FPos]; B2 := Data^[FPos + 1];
        if (B1 and $40) <> 0 then SX := -((-B1) and $3F) else SX := B1 and $3F;
        if (B2 and $40) <> 0 then SY := -((-B2) and $3F) else SY := B2 and $3F;
        if (B1 and $80 = 0) and (B2 and $80 = 0) then Op := 0
        else if (B2 and $80 = 0) then Op := 1 else Op := 2;
        Strokes[NumStrokes].Op := Op;
        Strokes[NumStrokes].X := SX;
        Strokes[NumStrokes].Y := SY;
        Inc(NumStrokes);
        Inc(FPos, 2);
      until Op = 0;
    end;
  end;
  Dispose(Data);
  Result := True;
end;

procedure TRIPCanvas.OutTextXY(X, Y: Integer; const Text: String);
var I: Integer; ActualScale: Double; YOffset: Integer;
begin
  FCurX := X; FCurY := Y;
  if (FFontNum >= 1) and (FFontNum <= 10) then begin
    if LoadCHRFont(FFontNum) then begin
      if FFontSize <= 10 then ActualScale := FontScales[FFontSize]
      else ActualScale := 1.0;
      if (CHRFonts[FFontNum] <> nil) and CHRFonts[FFontNum]^.Loaded then begin
        YOffset := Trunc(CHRFonts[FFontNum]^.OrgToCap * ActualScale) + 2;
        if FFontDir = 0 then FCurY := Y + YOffset
        else FCurX := X + YOffset;
      end;
      for I := 1 to Length(Text) do
        DrawCHRChar(FFontNum, Ord(Text[I]), FCurX, FCurY);
      Exit;
    end;
  end;
  for I := 1 to Length(Text) do
    DrawBitmapChar(Ord(Text[I]), FCurX, FCurY);
end;

procedure TRIPCanvas.SetTextStyle(Font, Direction, CharSize: Integer);
begin
  FFontNum := Font and 255;
  FFontDir := Direction and 1;
  FFontSize := CharSize;
  if FFontSize < 1 then FFontSize := 1;
end;

function TRIPCanvas.TextWidth(const Text: String): Integer;
var I, C, W: Integer; ActualScale: Double;
begin
  if (FFontNum >= 1) and (FFontNum <= 10) and
     (CHRFonts[FFontNum] <> nil) and CHRFonts[FFontNum]^.Loaded then begin
    if FFontSize <= 10 then ActualScale := FontScales[FFontSize]
    else ActualScale := 1.0;
    W := 0;
    with CHRFonts[FFontNum]^ do
      for I := 1 to Length(Text) do begin
        C := Ord(Text[I]) - FirstChar;
        if (C >= 0) and (C < NumChars) then W := W + Widths[C];
      end;
    Result := Trunc(W * ActualScale);
  end else
    Result := Length(Text) * FFontSize * 8;
end;

function TRIPCanvas.TextHeight: Integer;
var ActualScale: Double;
begin
  if (FFontNum >= 1) and (FFontNum <= 10) and
     (CHRFonts[FFontNum] <> nil) and CHRFonts[FFontNum]^.Loaded then begin
    if FFontSize <= 10 then ActualScale := FontScales[FFontSize]
    else ActualScale := 1.0;
    Result := Trunc(CHRFonts[FFontNum]^.OrgToCap * ActualScale);
  end else
    Result := FFontSize * 8;
end;

procedure TRIPCanvas.RenderToText(var Buf; BufW, BufH: Integer);
{ Render 640x350 pixel buffer to text cells using half-block characters.
  Each text cell = 8x14 pixels (80x25 = 640x350). 
  Uses upper/lower half blocks for 2-color-per-cell resolution. }
type
  TTextCell = record Ch: Char; Attr: Byte; end;
  PTextBuf = ^TTextBufArr;
  TTextBufArr = array[0..0] of TTextCell;
var
  TX, TY, PX, PY: Integer;
  TopColor, BotColor: Byte;
  TopCount, BotCount: array[0..15] of Integer;
  MaxTop, MaxBot: Integer;
  P: PTextBuf;
begin
  P := @Buf;
  for TY := 0 to BufH - 1 do begin
    for TX := 0 to BufW - 1 do begin
      { Sample top half (7 pixel rows) and bottom half (7 pixel rows) }
      FillChar(TopCount, SizeOf(TopCount), 0);
      FillChar(BotCount, SizeOf(BotCount), 0);
      
      for PY := 0 to 6 do
        for PX := 0 to 7 do
          Inc(TopCount[GetPixelRaw(TX * 8 + PX, TY * 14 + PY)]);
      
      for PY := 7 to 13 do
        for PX := 0 to 7 do
          Inc(BotCount[GetPixelRaw(TX * 8 + PX, TY * 14 + PY)]);
      
      { Find dominant color in each half }
      TopColor := 0; MaxTop := 0;
      BotColor := 0; MaxBot := 0;
      for PX := 0 to 15 do begin
        if TopCount[PX] > MaxTop then begin MaxTop := TopCount[PX]; TopColor := PX; end;
        if BotCount[PX] > MaxBot then begin MaxBot := BotCount[PX]; BotColor := PX; end;
      end;
      
      { Choose character and attribute }
      if TopColor = BotColor then begin
        P^[TY * BufW + TX].Ch := ' ';
        P^[TY * BufW + TX].Attr := (TopColor shl 4);
      end else begin
        P^[TY * BufW + TX].Ch := Chr($DF); { ▀ upper half block }
        P^[TY * BufW + TX].Attr := (BotColor shl 4) or TopColor;
      end;
    end;
  end;
end;

procedure TRIPCanvas.SaveBMP(const FileName: String);
var
  F: TFileStream;
  BmpHdr: packed record
    BM: Word; FileSize: LongWord; Reserved: LongWord;
    DataOfs: LongWord; HdrSize: LongWord;
    Width, Height: LongInt; Planes, BPP: Word;
    Compress, ImgSize: LongWord;
    XPPM, YPPM: LongInt; Colors, ImportantColors: LongWord;
  end;
  Pal: array[0..15] of packed record B, G, R, A: Byte; end;
  Row: array[0..319] of Byte; { 640 pixels / 2 = 320 bytes (4bpp) }
  X, Y, I: Integer;
begin
  F := TFileStream.Create(FileName, fmCreate);
  try
    { BMP header — 4bpp (16 color) }
    FillChar(BmpHdr, SizeOf(BmpHdr), 0);
    BmpHdr.BM := $4D42;
    BmpHdr.DataOfs := 14 + 40 + 64; { header + info + palette }
    BmpHdr.HdrSize := 40;
    BmpHdr.Width := RIP_WIDTH;
    BmpHdr.Height := RIP_HEIGHT;
    BmpHdr.Planes := 1;
    BmpHdr.BPP := 4;
    BmpHdr.ImgSize := RIP_HEIGHT * 320;
    BmpHdr.FileSize := BmpHdr.DataOfs + BmpHdr.ImgSize;
    F.Write(BmpHdr, SizeOf(BmpHdr));
    
    { Palette }
    for I := 0 to 15 do begin
      Pal[I].R := FPalette[I].R;
      Pal[I].G := FPalette[I].G;
      Pal[I].B := FPalette[I].B;
      Pal[I].A := 0;
    end;
    F.Write(Pal, 64);
    
    { Pixel data — bottom-up, 4bpp packed }
    for Y := RIP_HEIGHT - 1 downto 0 do begin
      for X := 0 to 319 do
        Row[X] := (FPixels[Y, X * 2] shl 4) or (FPixels[Y, X * 2 + 1] and $0F);
      F.Write(Row, 320);
    end;
  finally
    F.Free;
  end;
end;

end.
