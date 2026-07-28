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
    procedure PutPixelRaw(X, Y: Integer; Color: Byte);
    function  GetPixelRaw(X, Y: Integer): Byte;
    procedure HLine(X1, X2, Y: Integer; Color: Byte);
    procedure VLine(X, Y1, Y2: Integer; Color: Byte);
  public
    constructor Create;
    procedure Clear(Color: Byte);
    
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
    
    { State }
    procedure SetColor(Color: Byte);
    procedure SetFillStyle(Style, Color: Byte);
    procedure SetLineStyle(Style: Byte);
    
    { Export }
    procedure SaveBMP(const FileName: String);
    
    { Render to text buffer for FV display }
    procedure RenderToText(var Buf; BufW, BufH: Integer);
    
    property ForeColor: Byte read FFGColor write FFGColor;
    property BackColor: Byte read FBGColor write FBGColor;
    property FillColor: Byte read FFillColor;
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

implementation

uses SysUtils, Classes;

constructor TRIPCanvas.Create;
begin
  inherited;
  Clear(0);
  FFGColor := 15;
  FBGColor := 0;
  FFillColor := 0;
  FFillStyle := 1;
  FLineStyle := 0;
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
begin
  PutPixelRaw(X, Y, Color);
end;

function TRIPCanvas.GetPixel(X, Y: Integer): Byte;
begin
  Result := GetPixelRaw(X, Y);
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

procedure TRIPCanvas.Line(X1, Y1, X2, Y2: Integer);
var DX, DY, SX, SY, Err, E2: Integer;
begin
  { Bresenham's line algorithm }
  DX := Abs(X2 - X1);
  DY := Abs(Y2 - Y1);
  if X1 < X2 then SX := 1 else SX := -1;
  if Y1 < Y2 then SY := 1 else SY := -1;
  Err := DX - DY;
  
  while True do begin
    PutPixelRaw(X1, Y1, FFGColor);
    if (X1 = X2) and (Y1 = Y2) then Break;
    E2 := 2 * Err;
    if E2 > -DY then begin Dec(Err, DY); Inc(X1, SX); end;
    if E2 < DX then begin Inc(Err, DX); Inc(Y1, SY); end;
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
var Y, T: Integer; C: Byte;
begin
  if Y1 > Y2 then begin T := Y1; Y1 := Y2; Y2 := T; end;
  if FFillStyle = 0 then C := FBGColor
  else C := FFillColor;
  for Y := Y1 to Y2 do HLine(X1, X2, Y, C);
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
var
  Stack: array[0..8191] of record X, Y: Integer; end;
  SP, OldColor: Integer;
begin
  if (X < 0) or (X >= RIP_WIDTH) or (Y < 0) or (Y >= RIP_HEIGHT) then Exit;
  OldColor := GetPixelRaw(X, Y);
  if OldColor = FFillColor then Exit;
  if OldColor = Border then Exit;
  
  SP := 0;
  Stack[SP].X := X; Stack[SP].Y := Y; Inc(SP);
  
  while SP > 0 do begin
    Dec(SP);
    X := Stack[SP].X; Y := Stack[SP].Y;
    if (X < 0) or (X >= RIP_WIDTH) or (Y < 0) or (Y >= RIP_HEIGHT) then Continue;
    if GetPixelRaw(X, Y) <> OldColor then Continue;
    
    PutPixelRaw(X, Y, FFillColor);
    
    if SP < 8188 then begin
      Stack[SP].X := X + 1; Stack[SP].Y := Y; Inc(SP);
      Stack[SP].X := X - 1; Stack[SP].Y := Y; Inc(SP);
      Stack[SP].X := X; Stack[SP].Y := Y + 1; Inc(SP);
      Stack[SP].X := X; Stack[SP].Y := Y - 1; Inc(SP);
    end;
  end;
end;

procedure TRIPCanvas.OutTextXY(X, Y: Integer; const Text: String);
var I, PX, PY, Bit: Integer; Ch: Byte;
  { Simple 8x8 font — just render block chars for now }
begin
  for I := 1 to Length(Text) do begin
    Ch := Ord(Text[I]);
    { Simple: draw each character as an 8-pixel-wide block }
    { Full font rendering would use pdbitfont CP437 data }
    for PY := 0 to 7 do
      for PX := 0 to 7 do
        if (Ch > 32) then
          PutPixelRaw(X + (I - 1) * 8 + PX, Y + PY, FFGColor);
  end;
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
      Pal[I].R := EGAPalette[I].R;
      Pal[I].G := EGAPalette[I].G;
      Pal[I].B := EGAPalette[I].B;
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
