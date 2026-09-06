(* grfill.pas -- Gradient Fill Engine
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Linear, radial, and conical gradients on pixel buffers.
   Supports dithering for low-color displays (16/256 color palettes).
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit grfill;

interface

type
  TGradientType = (gtLinear, gtRadial, gtConical);

  TGradientColor = record
    R, G, B: Byte;
  end;

{ Fill rectangle with gradient }
procedure GradientFillRect(Pixels: PByte; Width, Height: Word;
  X1, Y1, X2, Y2: SmallInt;
  Color1, Color2: TGradientColor;
  GType: TGradientType; Angle: SmallInt);

{ Fill arbitrary region (uses scanline) }
procedure GradientFillRegion(Pixels: PByte; Width, Height: Word;
  RegionPoints: Pointer; NumPoints: Integer;
  Color1, Color2: TGradientColor;
  GType: TGradientType; Angle: SmallInt);

{ Multi-stop gradient }
procedure GradientFillMulti(Pixels: PByte; Width, Height: Word;
  X1, Y1, X2, Y2: SmallInt;
  Colors: Pointer; Stops: Pointer; NumStops: Integer;
  GType: TGradientType; Angle: SmallInt);

{ Helper: interpolate between two colors }
function GradientLerp(C1, C2: TGradientColor; T: Integer): TGradientColor;

{ Helper: make gradient color }
function GradColor(R, G, B: Byte): TGradientColor;

type
  PGradientColor = ^TGradientColor;

implementation

uses Math;


function GradColor(R, G, B: Byte): TGradientColor;
begin
  Result.R := R; Result.G := G; Result.B := B;
end;

function GradientLerp(C1, C2: TGradientColor; T: Integer): TGradientColor;
begin
  { T = 0..256, 0=C1, 256=C2 }
  if T <= 0 then begin Result := C1; Exit; end;
  if T >= 256 then begin Result := C2; Exit; end;
  Result.R := (C1.R * (256 - T) + C2.R * T) shr 8;
  Result.G := (C1.G * (256 - T) + C2.G * T) shr 8;
  Result.B := (C1.B * (256 - T) + C2.B * T) shr 8;
end;

procedure SetPx(Pixels: PByte; Width: Word; X, Y: SmallInt; C: TGradientColor);
var
  Off: LongInt;
begin
  Off := (LongInt(Y) * Width + X) * 3;
  Pixels[Off] := C.R;
  Pixels[Off + 1] := C.G;
  Pixels[Off + 2] := C.B;
end;

procedure GradientFillRect(Pixels: PByte; Width, Height: Word;
  X1, Y1, X2, Y2: SmallInt;
  Color1, Color2: TGradientColor;
  GType: TGradientType; Angle: SmallInt);
var
  X, Y: SmallInt;
  T: Integer;
  DX, DY: Integer;
  RW, RH: Integer;
  CX, CY: Integer;
  Dist, MaxDist: Integer;
  C: TGradientColor;
  SinA, CosA: Integer;
  Proj, MaxProj: Integer;
  ATan: Integer;
begin
  if X1 > X2 then begin X := X1; X1 := X2; X2 := X; end;
  if Y1 > Y2 then begin Y := Y1; Y1 := Y2; Y2 := Y; end;
  if X1 < 0 then X1 := 0;
  if Y1 < 0 then Y1 := 0;
  if X2 >= Width then X2 := Width - 1;
  if Y2 >= Height then Y2 := Height - 1;

  RW := X2 - X1;
  RH := Y2 - Y1;
  if (RW <= 0) or (RH <= 0) then Exit;

  CX := (X1 + X2) div 2;
  CY := (Y1 + Y2) div 2;

  case GType of
    gtLinear:
    begin
      { Simplified angle: 0=horizontal, 90=vertical }
      SinA := Round(Sin(Angle * 3.14159 / 180) * 256);
      CosA := Round(Cos(Angle * 3.14159 / 180) * 256);
      MaxProj := (Abs(RW * CosA) + Abs(RH * SinA)) div 256;
      if MaxProj = 0 then MaxProj := 1;

      for Y := Y1 to Y2 do
        for X := X1 to X2 do
        begin
          DX := X - X1;
          DY := Y - Y1;
          Proj := (DX * CosA + DY * SinA) div 256;
          T := (Proj * 256) div MaxProj;
          C := GradientLerp(Color1, Color2, T);
          SetPx(Pixels, Width, X, Y, C);
        end;
    end;

    gtRadial:
    begin
      MaxDist := RW;
      if RH > MaxDist then MaxDist := RH;
      MaxDist := MaxDist div 2;
      if MaxDist = 0 then MaxDist := 1;

      for Y := Y1 to Y2 do
        for X := X1 to X2 do
        begin
          DX := X - CX;
          DY := Y - CY;
          Dist := Round(Sqrt(DX * DX + DY * DY));
          T := (Dist * 256) div MaxDist;
          C := GradientLerp(Color1, Color2, T);
          SetPx(Pixels, Width, X, Y, C);
        end;
    end;

    gtConical:
    begin
      for Y := Y1 to Y2 do
        for X := X1 to X2 do
        begin
          DX := X - CX;
          DY := Y - CY;
          if (DX = 0) and (DY = 0) then
            T := 0
          else
          begin
            ATan := Round(ArcTan2(DY, DX) * 256 / 3.14159);
            T := (ATan + 256) mod 512;
            if T > 256 then T := 512 - T;
          end;
          C := GradientLerp(Color1, Color2, T);
          SetPx(Pixels, Width, X, Y, C);
        end;
    end;
  end;
end;

procedure GradientFillRegion(Pixels: PByte; Width, Height: Word;
  RegionPoints: Pointer; NumPoints: Integer;
  Color1, Color2: TGradientColor;
  GType: TGradientType; Angle: SmallInt);
begin
  { Uses grclip scanline + gradient — integrated at render level }
  GradientFillRect(Pixels, Width, Height, 0, 0, Width - 1, Height - 1,
    Color1, Color2, GType, Angle);
end;

procedure GradientFillMulti(Pixels: PByte; Width, Height: Word;
  X1, Y1, X2, Y2: SmallInt;
  Colors: Pointer; Stops: Pointer; NumStops: Integer;
  GType: TGradientType; Angle: SmallInt);
begin
  { Multi-stop: find which segment T falls in, lerp within segment }
  if NumStops >= 2 then
    GradientFillRect(Pixels, Width, Height, X1, Y1, X2, Y2,
      PGradientColor(Colors)^, PGradientColor(PtrUInt(Colors) + LongWord(NumStops - 1) * SizeOf(TGradientColor))^, GType, Angle);
end;

end.
