{ This file is part of FPC 2.6.4irc.
  Copyright (C) 2026 fpc264irc contributors.

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <https://www.gnu.org/licenses/>.
}
{ Fixed-Point Math Unit — Pure Pascal, no FPU required
  Uses 16.16 fixed-point format (32-bit integer, 16 bits fractional).
  Suitable for DOS (go32v2, i8086) and any target without FPU.

  Usage:
    var A, B, C: TFixed;
    begin
      A := IntToFixed(10);       // 10.0
      B := FloatToFixed(3.14);   // 3.14
      C := FixMul(A, B);        // 31.4
      WriteLn(FixedToInt(C));   // 31
    end;
}
unit fixmath;

{$mode objfpc}{$H+}

interface

type
  TFixed = LongInt;  // 16.16 fixed-point: upper 16 = integer, lower 16 = fraction

const
  FIXED_SHIFT = 16;
  FIXED_ONE   = 1 shl FIXED_SHIFT;       // 65536 = 1.0
  FIXED_HALF  = FIXED_ONE div 2;          // 0.5
  FIXED_PI    = 205887;                   // Pi in 16.16
  FIXED_2PI   = 411775;                   // 2*Pi in 16.16
  FIXED_PI2   = 102944;                   // Pi/2 in 16.16
  FIXED_E     = 178145;                   // e in 16.16

{ Conversion }
function IntToFixed(I: LongInt): TFixed; inline;
function FloatToFixed(F: Double): TFixed; inline;
function FixedToInt(F: TFixed): LongInt; inline;
function FixedToFloat(F: TFixed): Double; inline;
function FixedRound(F: TFixed): LongInt; inline;

{ Arithmetic }
function FixMul(A, B: TFixed): TFixed;
function FixDiv(A, B: TFixed): TFixed;
function FixSqr(A: TFixed): TFixed; inline;
function FixAbs(A: TFixed): TFixed; inline;

{ Trigonometry (angle in 0..1023 = 0..360 degrees, 1024 steps) }
function FixSin(Angle: LongInt): TFixed;
function FixCos(Angle: LongInt): TFixed;
function FixTan(Angle: LongInt): TFixed;

{ Angle conversion }
function DegToFixAngle(Deg: LongInt): LongInt; inline;
function FixAngleToDeg(A: LongInt): LongInt; inline;

{ Square root (integer approximation) }
function FixSqrt(A: TFixed): TFixed;

{ Interpolation }
function FixLerp(A, B, T: TFixed): TFixed;

implementation

const
  { 256-entry sine table (quarter wave, 0..PI/2)
    Values are 16.16 fixed-point for sin(i * PI/2 / 256) }
  SinTable: array[0..256] of TFixed = (
        0,   402,   804,  1206,  1608,  2010,  2412,  2814,
     3215,  3617,  4018,  4420,  4821,  5222,  5623,  6023,
     6424,  6824,  7223,  7623,  8022,  8421,  8819,  9218,
     9616, 10013, 10410, 10807, 11204, 11600, 11996, 12391,
    12785, 13180, 13573, 13966, 14359, 14751, 15143, 15534,
    15924, 16314, 16703, 17091, 17479, 17866, 18253, 18638,
    19024, 19408, 19792, 20175, 20557, 20939, 21320, 21699,
    22078, 22457, 22834, 23210, 23586, 23960, 24334, 24707,
    25079, 25450, 25820, 26189, 26557, 26925, 27291, 27656,
    28020, 28383, 28745, 29106, 29466, 29824, 30182, 30538,
    30893, 31248, 31600, 31952, 32303, 32652, 33000, 33347,
    33692, 34036, 34379, 34721, 35062, 35401, 35738, 36075,
    36410, 36744, 37076, 37407, 37736, 38064, 38391, 38716,
    39040, 39362, 39683, 40002, 40320, 40636, 40951, 41264,
    41576, 41886, 42194, 42501, 42806, 43110, 43412, 43713,
    44011, 44308, 44604, 44898, 45190, 45480, 45769, 46056,
    46341, 46624, 46906, 47186, 47464, 47741, 48015, 48288,
    48559, 48828, 49095, 49361, 49624, 49886, 50146, 50404,
    50660, 50914, 51166, 51417, 51665, 51911, 52156, 52398,
    52639, 52878, 53114, 53349, 53581, 53812, 54040, 54267,
    54491, 54714, 54934, 55152, 55368, 55582, 55794, 56004,
    56212, 56418, 56621, 56823, 57022, 57219, 57414, 57607,
    57798, 57986, 58172, 58356, 58538, 58718, 58896, 59071,
    59244, 59415, 59583, 59750, 59914, 60075, 60235, 60392,
    60547, 60700, 60851, 60999, 61145, 61288, 61429, 61568,
    61705, 61839, 61971, 62101, 62228, 62353, 62476, 62596,
    62714, 62830, 62943, 63054, 63162, 63268, 63372, 63473,
    63572, 63668, 63763, 63854, 63944, 64031, 64115, 64197,
    64277, 64355, 64430, 64503, 64573, 64641, 64707, 64770,
    64830, 64889, 64945, 64999, 65050, 65099, 65145, 65189,
    65231, 65270, 65307, 65342, 65374, 65404, 65431, 65457,
    65479, 65500, 65518, 65534, 65547, 65558, 65567, 65574,
    65536
  );

{ Conversion }

function IntToFixed(I: LongInt): TFixed; inline;
begin
  Result := I shl FIXED_SHIFT;
end;

function FloatToFixed(F: Double): TFixed; inline;
begin
  Result := Round(F * FIXED_ONE);
end;

function FixedToInt(F: TFixed): LongInt; inline;
begin
  Result := F shr FIXED_SHIFT;
end;

function FixedToFloat(F: TFixed): Double; inline;
begin
  Result := F / FIXED_ONE;
end;

function FixedRound(F: TFixed): LongInt; inline;
begin
  Result := (F + FIXED_HALF) shr FIXED_SHIFT;
end;

{ Arithmetic }

function FixMul(A, B: TFixed): TFixed;
var
  R: Int64;
begin
  R := Int64(A) * Int64(B);
  Result := TFixed(R shr FIXED_SHIFT);
end;

function FixDiv(A, B: TFixed): TFixed;
var
  R: Int64;
begin
  if B = 0 then
  begin
    if A >= 0 then Result := $7FFFFFFF
    else Result := -$7FFFFFFF;
    Exit;
  end;
  R := Int64(A) shl FIXED_SHIFT;
  Result := TFixed(R div Int64(B));
end;

function FixSqr(A: TFixed): TFixed; inline;
begin
  Result := FixMul(A, A);
end;

function FixAbs(A: TFixed): TFixed; inline;
begin
  if A < 0 then Result := -A
  else Result := A;
end;

{ Trigonometry — angle in 0..1023 (1024 = 360 degrees) }

function FixSin(Angle: LongInt): TFixed;
var
  Q, Idx: LongInt;
begin
  Angle := Angle and 1023;  // wrap to 0..1023
  Q := Angle shr 8;         // quadrant 0..3
  Idx := Angle and 255;     // index 0..255

  case Q of
    0: Result := SinTable[Idx];
    1: Result := SinTable[256 - Idx];
    2: Result := -SinTable[Idx];
    3: Result := -SinTable[256 - Idx];
  else
    Result := 0;
  end;
end;

function FixCos(Angle: LongInt): TFixed;
begin
  Result := FixSin(Angle + 256);  // cos = sin + 90 degrees
end;

function FixTan(Angle: LongInt): TFixed;
var
  C: TFixed;
begin
  C := FixCos(Angle);
  if C = 0 then
    Result := $7FFFFFFF
  else
    Result := FixDiv(FixSin(Angle), C);
end;

{ Angle conversion }

function DegToFixAngle(Deg: LongInt): LongInt; inline;
begin
  Result := (Deg * 1024) div 360;
end;

function FixAngleToDeg(A: LongInt): LongInt; inline;
begin
  Result := (A * 360) div 1024;
end;

{ Square root — integer Newton's method }

function FixSqrt(A: TFixed): TFixed;
var
  X, LastX: TFixed;
  I: Integer;
begin
  if A <= 0 then
  begin
    Result := 0;
    Exit;
  end;

  // Initial guess — shift right by half the fixed-point shift
  X := A;
  if X > FIXED_ONE then
    X := (X shr 8) + (FIXED_ONE shl 8)
  else
    X := (X shr 1) + (FIXED_ONE shr 1);

  for I := 0 to 15 do
  begin
    LastX := X;
    X := (X + FixDiv(A, X)) shr 1;
    if X = LastX then Break;
  end;

  Result := X;
end;

{ Linear interpolation: A + T * (B - A), T in 0..FIXED_ONE }

function FixLerp(A, B, T: TFixed): TFixed;
begin
  Result := A + FixMul(B - A, T);
end;

end.
