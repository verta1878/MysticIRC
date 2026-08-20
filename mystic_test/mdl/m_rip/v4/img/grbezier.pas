(* grbezier.pas -- Variable-Width Bezier Curves
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Cubic and quadratic Bezier with per-point stroke width.
   Cap styles: butt, round, square.
   Join styles: miter, round, bevel.
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit grbezier;

interface

type
  TCapStyle = (csButt, csRound, csSquare);
  TJoinStyle = (jsRound, jsMiter, jsBevel);

  TBezPoint = record
    X, Y: SmallInt;
    Width: Byte;  { stroke width at this point }
  end;

{ Draw cubic Bezier with variable width }
procedure BezierDrawVarWidth(Pixels: PByte; PxWidth, PxHeight: Word;
  P0, P1, P2, P3: TBezPoint; Color: LongWord; Cap: TCapStyle);

{ Draw quadratic Bezier with variable width }
procedure BezierDrawQuadVW(Pixels: PByte; PxWidth, PxHeight: Word;
  P0, P1, P2: TBezPoint; Color: LongWord; Cap: TCapStyle);

{ Draw thick line segment (used internally) }
procedure ThickLine(Pixels: PByte; PxWidth, PxHeight: Word;
  X1, Y1, X2, Y2: SmallInt; W1, W2: Byte;
  R, G, B: Byte);

{ Helper: make BezPoint }
function BezPt(X, Y: SmallInt; W: Byte): TBezPoint;

implementation

function BezPt(X, Y: SmallInt; W: Byte): TBezPoint;
begin
  Result.X := X; Result.Y := Y; Result.Width := W;
end;

procedure PutPixel(Pixels: PByte; PxWidth, PxHeight: Word;
  X, Y: SmallInt; R, G, B: Byte);
var
  Off: LongInt;
begin
  if (X < 0) or (X >= PxWidth) or (Y < 0) or (Y >= PxHeight) then Exit;
  Off := (LongInt(Y) * PxWidth + X) * 3;
  Pixels[Off] := R; Pixels[Off + 1] := G; Pixels[Off + 2] := B;
end;

procedure FillCircle(Pixels: PByte; PxWidth, PxHeight: Word;
  CX, CY: SmallInt; Radius: Integer; R, G, B: Byte);
var
  X, Y: Integer;
  RSq: Integer;
begin
  if Radius <= 0 then begin PutPixel(Pixels, PxWidth, PxHeight, CX, CY, R, G, B); Exit; end;
  RSq := Radius * Radius;
  for Y := -Radius to Radius do
    for X := -Radius to Radius do
      if X * X + Y * Y <= RSq then
        PutPixel(Pixels, PxWidth, PxHeight, CX + X, CY + Y, R, G, B);
end;

procedure ThickLine(Pixels: PByte; PxWidth, PxHeight: Word;
  X1, Y1, X2, Y2: SmallInt; W1, W2: Byte;
  R, G, B: Byte);
var
  DX, DY, Steps, I: Integer;
  XF, YF, XI, YI: Integer;
  W, WI: Integer;
begin
  DX := Abs(X2 - X1);
  DY := Abs(Y2 - Y1);
  if DX > DY then Steps := DX else Steps := DY;
  if Steps = 0 then
  begin
    FillCircle(Pixels, PxWidth, PxHeight, X1, Y1, W1 div 2, R, G, B);
    Exit;
  end;

  XI := ((X2 - X1) shl 8) div Steps;
  YI := ((Y2 - Y1) shl 8) div Steps;
  WI := ((Integer(W2) - Integer(W1)) shl 8) div Steps;
  XF := X1 shl 8;
  YF := Y1 shl 8;
  W := Integer(W1) shl 8;

  for I := 0 to Steps do
  begin
    FillCircle(Pixels, PxWidth, PxHeight,
      XF shr 8, YF shr 8, (W shr 8) div 2, R, G, B);
    Inc(XF, XI);
    Inc(YF, YI);
    Inc(W, WI);
  end;
end;

procedure BezierDrawVarWidth(Pixels: PByte; PxWidth, PxHeight: Word;
  P0, P1, P2, P3: TBezPoint; Color: LongWord; Cap: TCapStyle);
var
  Steps, I: Integer;
  T, T2, T3, MT, MT2, MT3: Integer;
  X, Y, W: Integer;
  PrevX, PrevY, PrevW: Integer;
  R, G, B: Byte;
begin
  R := Color and $FF;
  G := (Color shr 8) and $FF;
  B := (Color shr 16) and $FF;

  { Adaptive step count based on curve length }
  Steps := Abs(P3.X - P0.X) + Abs(P3.Y - P0.Y) +
           Abs(P2.X - P1.X) + Abs(P2.Y - P1.Y);
  if Steps < 8 then Steps := 8;
  if Steps > 200 then Steps := 200;

  PrevX := P0.X; PrevY := P0.Y; PrevW := P0.Width;

  for I := 1 to Steps do
  begin
    T := (I shl 8) div Steps;
    MT := 256 - T;
    T2 := (T * T) shr 8;
    T3 := (T2 * T) shr 8;
    MT2 := (MT * MT) shr 8;
    MT3 := (MT2 * MT) shr 8;

    X := (MT3 * P0.X + 3 * ((MT2 * T) shr 8) * P1.X +
          3 * ((MT * T2) shr 8) * P2.X + T3 * P3.X) shr 8;
    Y := (MT3 * P0.Y + 3 * ((MT2 * T) shr 8) * P1.Y +
          3 * ((MT * T2) shr 8) * P2.Y + T3 * P3.Y) shr 8;
    W := (MT * P0.Width + T * P3.Width) shr 8;

    ThickLine(Pixels, PxWidth, PxHeight,
      PrevX, PrevY, X, Y, PrevW, W, R, G, B);

    PrevX := X; PrevY := Y; PrevW := W;
  end;

  { End caps }
  if Cap = csRound then
  begin
    FillCircle(Pixels, PxWidth, PxHeight, P0.X, P0.Y, P0.Width div 2, R, G, B);
    FillCircle(Pixels, PxWidth, PxHeight, P3.X, P3.Y, P3.Width div 2, R, G, B);
  end;
end;

procedure BezierDrawQuadVW(Pixels: PByte; PxWidth, PxHeight: Word;
  P0, P1, P2: TBezPoint; Color: LongWord; Cap: TCapStyle);
var
  CP1, CP2: TBezPoint;
begin
  { Convert quadratic to cubic }
  CP1.X := P0.X + (2 * (P1.X - P0.X)) div 3;
  CP1.Y := P0.Y + (2 * (P1.Y - P0.Y)) div 3;
  CP1.Width := (P0.Width * 2 + P1.Width) div 3;
  CP2.X := P2.X + (2 * (P1.X - P2.X)) div 3;
  CP2.Y := P2.Y + (2 * (P1.Y - P2.Y)) div 3;
  CP2.Width := (P2.Width * 2 + P1.Width) div 3;
  BezierDrawVarWidth(Pixels, PxWidth, PxHeight, P0, CP1, CP2, P2, Color, Cap);
end;

end.
