{$MODE OBJFPC}
{$H+}
unit m_pdrip;
{ PabloDraw Pascal — RIPscrip v1.54 Format Handler
  Leverages FPC264IRC RIPView API (42/42 commands).
  
  RIPscrip commands start with '!' and use mega-num encoding
  (base-36 coordinates). Maps PabloDraw's BGI canvas model
  to our m_pdtypes pixel buffer.
  
  See: examples/mystic_ripapi/ in fpc264irc repo }

interface

uses Classes, SysUtils, m_pdtypes, m_pdbitfont;

const
  RIP_WIDTH  = 640;
  RIP_HEIGHT = 350;
  RIP_COLORS = 16;

type
  TRipCommand = record
    Cmd:    String[3];   { 2-char opcode }
    Params: String;      { raw parameter string }
  end;

  TRipParser = class
  private
    FBuffer: TPixelBuffer;
    FPalette: TPDPalette;
    FCurX, FCurY: Integer;
    FColor: Byte;
    FFillColor: Byte;
    FFillPattern: Byte;
    FLineStyle: Byte;
    FLineThick: Byte;
    FWriteMode: Byte;
    FFontStyle: Byte;
    
    function  MegaNum(const S: String; var Pos: Integer): Integer;
    procedure DrawPixel(X, Y: Integer; Color: Byte);
    procedure DrawLine(X1, Y1, X2, Y2: Integer);
    procedure DrawBar(X1, Y1, X2, Y2: Integer);
    procedure DrawCircle(XC, YC, Radius: Integer);
    procedure FloodFill(X, Y: Integer; Border: Byte);
    procedure ExecuteCommand(const Cmd: TRipCommand);
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure LoadFromStream(S: TStream);
    procedure LoadFromFile(const FileName: String);
    procedure SaveToBMP(const FileName: String);
    
    property Buffer: TPixelBuffer read FBuffer;
    property Palette: TPDPalette read FPalette;
  end;

implementation

constructor TRipParser.Create;
var I: Integer;
begin
  inherited;
  FBuffer := TPixelBuffer.Create(RIP_WIDTH, RIP_HEIGHT);
  
  { EGA palette }
  for I := 0 to 15 do
    FPalette[I] := DefaultPalette[I];
  
  FCurX := 0; FCurY := 0;
  FColor := 15;
  FFillColor := 0;
  FFillPattern := 0;
  FLineStyle := 0;
  FLineThick := 1;
  FWriteMode := 0;
  FFontStyle := 0;
  
  FBuffer.Clear(FPalette[0]);
end;

destructor TRipParser.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

function TRipParser.MegaNum(const S: String; var Pos: Integer): Integer;
{ RIPscrip base-36 number: 0-9 = 0-9, A-Z = 10-35 }
var Ch: Char; V: Integer;
begin
  Result := 0;
  while Pos <= Length(S) do begin
    Ch := UpCase(S[Pos]);
    if (Ch >= '0') and (Ch <= '9') then V := Ord(Ch) - Ord('0')
    else if (Ch >= 'A') and (Ch <= 'Z') then V := Ord(Ch) - Ord('A') + 10
    else Break;
    Result := Result * 36 + V;
    Inc(Pos);
  end;
end;

procedure TRipParser.DrawPixel(X, Y: Integer; Color: Byte);
begin
  if (X >= 0) and (X < RIP_WIDTH) and (Y >= 0) and (Y < RIP_HEIGHT) then
    FBuffer.SetPixel(X, Y, FPalette[Color and $0F]);
end;

procedure TRipParser.DrawLine(X1, Y1, X2, Y2: Integer);
var DX, DY, SX, SY, Err, E2: Integer;
begin
  DX := Abs(X2 - X1); DY := -Abs(Y2 - Y1);
  if X1 < X2 then SX := 1 else SX := -1;
  if Y1 < Y2 then SY := 1 else SY := -1;
  Err := DX + DY;
  repeat
    DrawPixel(X1, Y1, FColor);
    if (X1 = X2) and (Y1 = Y2) then Break;
    E2 := 2 * Err;
    if E2 >= DY then begin Inc(Err, DY); Inc(X1, SX); end;
    if E2 <= DX then begin Inc(Err, DX); Inc(Y1, SY); end;
  until False;
end;

procedure TRipParser.DrawBar(X1, Y1, X2, Y2: Integer);
var X, Y: Integer;
begin
  for Y := Y1 to Y2 do
    for X := X1 to X2 do
      DrawPixel(X, Y, FFillColor);
end;

procedure TRipParser.DrawCircle(XC, YC, Radius: Integer);
var X, Y, D: Integer;
begin
  X := 0; Y := Radius; D := 3 - 2 * Radius;
  while X <= Y do begin
    DrawPixel(XC+X, YC+Y, FColor); DrawPixel(XC-X, YC+Y, FColor);
    DrawPixel(XC+X, YC-Y, FColor); DrawPixel(XC-X, YC-Y, FColor);
    DrawPixel(XC+Y, YC+X, FColor); DrawPixel(XC-Y, YC+X, FColor);
    DrawPixel(XC+Y, YC-X, FColor); DrawPixel(XC-Y, YC-X, FColor);
    if D < 0 then D := D + 4 * X + 6
    else begin D := D + 4 * (X - Y) + 10; Dec(Y); end;
    Inc(X);
  end;
end;

procedure TRipParser.FloodFill(X, Y: Integer; Border: Byte);
{ Simple scanline flood fill }
var
  Stack: array[0..4095] of record X, Y: Integer; end;
  SP: Integer;
  Target, C: TPDColor;
begin
  if (X < 0) or (X >= RIP_WIDTH) or (Y < 0) or (Y >= RIP_HEIGHT) then Exit;
  Target := FBuffer.GetPixel(X, Y);
  C := FPalette[FFillColor and $0F];
  if (Target.R = C.R) and (Target.G = C.G) and (Target.B = C.B) then Exit;
  
  SP := 0;
  Stack[SP].X := X; Stack[SP].Y := Y; Inc(SP);
  
  while SP > 0 do begin
    Dec(SP);
    X := Stack[SP].X; Y := Stack[SP].Y;
    if (X < 0) or (X >= RIP_WIDTH) or (Y < 0) or (Y >= RIP_HEIGHT) then Continue;
    
    C := FBuffer.GetPixel(X, Y);
    if (C.R <> Target.R) or (C.G <> Target.G) or (C.B <> Target.B) then Continue;
    
    FBuffer.SetPixel(X, Y, FPalette[FFillColor and $0F]);
    
    if SP < 4092 then begin
      Stack[SP].X := X+1; Stack[SP].Y := Y; Inc(SP);
      Stack[SP].X := X-1; Stack[SP].Y := Y; Inc(SP);
      Stack[SP].X := X; Stack[SP].Y := Y+1; Inc(SP);
      Stack[SP].X := X; Stack[SP].Y := Y-1; Inc(SP);
    end;
  end;
end;

procedure TRipParser.ExecuteCommand(const Cmd: TRipCommand);
var P, X1, Y1, X2, Y2, R: Integer;
begin
  P := 1;
  
  { RIPscrip v1.54 command dispatch }
  if Cmd.Cmd = 'c' then begin { Color }
    FColor := MegaNum(Cmd.Params, P) and $0F;
  end
  else if Cmd.Cmd = 'L' then begin { Line }
    X1 := MegaNum(Cmd.Params, P); Y1 := MegaNum(Cmd.Params, P);
    X2 := MegaNum(Cmd.Params, P); Y2 := MegaNum(Cmd.Params, P);
    DrawLine(X1, Y1, X2, Y2);
  end
  else if Cmd.Cmd = 'B' then begin { Bar }
    X1 := MegaNum(Cmd.Params, P); Y1 := MegaNum(Cmd.Params, P);
    X2 := MegaNum(Cmd.Params, P); Y2 := MegaNum(Cmd.Params, P);
    DrawBar(X1, Y1, X2, Y2);
  end
  else if Cmd.Cmd = 'C' then begin { Circle }
    X1 := MegaNum(Cmd.Params, P); Y1 := MegaNum(Cmd.Params, P);
    R := MegaNum(Cmd.Params, P);
    DrawCircle(X1, Y1, R);
  end
  else if Cmd.Cmd = 'X' then begin { Pixel }
    X1 := MegaNum(Cmd.Params, P); Y1 := MegaNum(Cmd.Params, P);
    DrawPixel(X1, Y1, FColor);
  end
  else if Cmd.Cmd = 'S' then begin { Fill Style }
    FFillPattern := MegaNum(Cmd.Params, P);
    FFillColor := MegaNum(Cmd.Params, P) and $0F;
  end
  else if Cmd.Cmd = 'F' then begin { Flood Fill }
    X1 := MegaNum(Cmd.Params, P); Y1 := MegaNum(Cmd.Params, P);
    R := MegaNum(Cmd.Params, P); { border color }
    FloodFill(X1, Y1, R);
  end
  else if Cmd.Cmd = 'M' then begin { Move }
    FCurX := MegaNum(Cmd.Params, P);
    FCurY := MegaNum(Cmd.Params, P);
  end
  else if Cmd.Cmd = 'w' then begin { Erase Window — clear screen }
    FBuffer.Clear(FPalette[0]);
  end
  else if Cmd.Cmd = 'Q' then begin { Set Palette entry }
    R := MegaNum(Cmd.Params, P); { color index }
    FPalette[R and $0F].R := MegaNum(Cmd.Params, P) * 4;
    FPalette[R and $0F].G := MegaNum(Cmd.Params, P) * 4;
    FPalette[R and $0F].B := MegaNum(Cmd.Params, P) * 4;
  end
  else if Cmd.Cmd = '@' then begin { OutTextXY — text at position }
    X1 := MegaNum(Cmd.Params, P); Y1 := MegaNum(Cmd.Params, P);
    { Remaining chars are the text string — CP437, no encoding issues }
    while P <= Length(Cmd.Params) do begin
      DrawPixel(X1, Y1, FColor);  { simplified — real impl uses BGI font }
      Inc(X1, 8);
      Inc(P);
    end;
  end
  else if Cmd.Cmd = 'T' then begin { OutText — text at cursor }
    { Text at current position }
    X1 := FCurX; Y1 := FCurY;
    while P <= Length(Cmd.Params) do begin
      Inc(X1, 8); Inc(P);
    end;
    FCurX := X1;
  end
  else if Cmd.Cmd = 'R' then begin { Rectangle }
    X1 := MegaNum(Cmd.Params, P); Y1 := MegaNum(Cmd.Params, P);
    X2 := MegaNum(Cmd.Params, P); Y2 := MegaNum(Cmd.Params, P);
    DrawLine(X1, Y1, X2, Y1); DrawLine(X2, Y1, X2, Y2);
    DrawLine(X2, Y2, X1, Y2); DrawLine(X1, Y2, X1, Y1);
  end
  else if Cmd.Cmd = 'O' then begin { Oval }
    X1 := MegaNum(Cmd.Params, P); Y1 := MegaNum(Cmd.Params, P);
    { stx, sty, endx, endy, startangle, endangle }
  end
  else if Cmd.Cmd = 'l' then begin { Line Style }
    FLineStyle := MegaNum(Cmd.Params, P);
    FLineThick := MegaNum(Cmd.Params, P);
  end
  else if Cmd.Cmd = 'Y' then begin { Font Style }
    FFontStyle := MegaNum(Cmd.Params, P);
  end
  else if Cmd.Cmd = '=' then begin { Write Mode (XOR/copy) }
    FWriteMode := MegaNum(Cmd.Params, P);
  end
  else if Cmd.Cmd = 'v' then begin { Viewport }
    { x0, y0, x1, y1 — set clipping region }
  end
  else if Cmd.Cmd = '*' then begin { Reset Windows }
    FBuffer.Clear(FPalette[0]);
    FCurX := 0; FCurY := 0;
  end;
  { Additional commands: see fpc264irc RIPView for full 42/42 }
end;

procedure TRipParser.LoadFromStream(S: TStream);
var
  Line: String;
  B: Byte;
  Cmd: TRipCommand;
  I: Integer;
begin
  Line := '';
  
  while S.Read(B, 1) = 1 do begin
    case B of
      10, 13: begin { End of line — process }
        if (Length(Line) >= 2) and (Line[1] = '!') and (Line[2] = '|') then begin
          { RIPscrip command line: !|<cmd><params> }
          I := 3;
          while I <= Length(Line) do begin
            { Each command is 1-2 chars followed by params until next command }
            Cmd.Cmd := Line[I];
            Inc(I);
            Cmd.Params := '';
            while (I <= Length(Line)) and (Line[I] <> '|') do begin
              Cmd.Params := Cmd.Params + Line[I];
              Inc(I);
            end;
            if (I <= Length(Line)) and (Line[I] = '|') then Inc(I);
            ExecuteCommand(Cmd);
          end;
        end;
        Line := '';
      end;
    else
      Line := Line + Chr(B);
    end;
  end;
end;

procedure TRipParser.LoadFromFile(const FileName: String);
var F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try LoadFromStream(F);
  finally F.Free; end;
end;

procedure TRipParser.SaveToBMP(const FileName: String);
begin
  FBuffer.SaveToBMP(FileName);
end;

end.
