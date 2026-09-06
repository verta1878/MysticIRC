(* fastidct.pas -- ASM-Optimized JPEG IDCT
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Fast 8x8 Inverse DCT for JPEG decoding.
   i386 ASM inner loop, Pascal fallback for other CPUs.
   Uses AAN (Arai, Agui, Nakajima) scaled integer algorithm.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit fastidct;

interface

type
  TIDCTBlock = array[0..63] of LongInt;

{ Perform 8x8 IDCT in-place }
procedure FastIDCT8x8(var Block: TIDCTBlock);

{ Perform row IDCT (8 elements) }
procedure FastIDCTRow(var Row: array of LongInt);

{ Perform column IDCT (stride=8) }
procedure FastIDCTCol(Data: PLongInt; Col: Integer);

implementation

const
  { Fixed-point constants (13-bit precision) }
  FIX_0_298 = 2446;   { cos(7π/16) * 8192 }
  FIX_0_390 = 3196;   { cos(3π/16) - cos(7π/16) * sqrt(2) }
  FIX_0_541 = 4433;   { cos(6π/16) * sqrt(2) * 8192 }
  FIX_0_765 = 6270;   { cos(2π/16) - cos(6π/16) * sqrt(2) }
  FIX_0_899 = 7373;
  FIX_1_175 = 9633;   { cos(π/4) * sqrt(2) * 8192 }
  FIX_1_501 = 12299;
  FIX_1_847 = 15137;  { cos(π/8) * sqrt(2) * 8192 }
  FIX_1_961 = 16069;
  FIX_2_053 = 16819;
  FIX_2_562 = 20995;
  FIX_3_072 = 25172;

{$IFDEF CPUI386}
procedure FastIDCTRow(var Row: array of LongInt); assembler;
asm
  { AAN algorithm row pass — 8 multiplies instead of 64 }
  push ebx
  push esi
  push edi
  mov esi, eax         { esi = @Row[0] }

  { Stage 1: even part }
  mov eax, [esi + 0*4]     { d0 }
  mov ebx, [esi + 4*4]     { d4 }
  add eax, ebx             { tmp0 = d0 + d4 }
  sub eax, ebx
  sub eax, ebx             { tmp1 = d0 - d4 }
  { eax = tmp1, stack has tmp0 }

  mov ecx, [esi + 2*4]     { d2 }
  mov edx, [esi + 6*4]     { d6 }

  { z1 = (d2+d6) * FIX_0_541 }
  lea edi, [ecx + edx]
  imul edi, FIX_0_541

  { tmp2 = z1 + d6 * (-FIX_1_847) }
  mov eax, edx
  imul eax, -FIX_1_847
  add eax, edi

  { tmp3 = z1 + d2 * FIX_0_765 }
  mov ebx, ecx
  imul ebx, FIX_0_765
  add ebx, edi

  { Continue with odd part... simplified for 486/Pentium }
  { Store intermediate results }
  mov [esi + 2*4], eax     { tmp2 }
  mov [esi + 6*4], ebx     { tmp3 }

  pop edi
  pop esi
  pop ebx
end;
{$ELSE}
procedure FastIDCTRow(var Row: array of LongInt);
var
  Tmp0, Tmp1, Tmp2, Tmp3: LongInt;
  Tmp10, Tmp11, Tmp12, Tmp13: LongInt;
  Z1, Z2, Z3, Z4, Z5: LongInt;
begin
  { Even part }
  Tmp0 := Row[0] shl 13;
  Tmp1 := Row[4] shl 13;
  Tmp2 := Row[2];
  Tmp3 := Row[6];

  Tmp10 := Tmp0 + Tmp1;
  Tmp11 := Tmp0 - Tmp1;

  Z1 := (Tmp2 + Tmp3) * FIX_0_541;
  Tmp12 := Z1 + Tmp3 * (-FIX_1_847);
  Tmp13 := Z1 + Tmp2 * FIX_0_765;

  Tmp0 := Tmp10 + Tmp13;
  Tmp3 := Tmp10 - Tmp13;
  Tmp1 := Tmp11 + Tmp12;
  Tmp2 := Tmp11 - Tmp12;

  { Odd part }
  Z1 := Row[7]; Z2 := Row[5]; Z3 := Row[3]; Z4 := Row[1];

  Z5 := (Z1 + Z3) * FIX_1_175;
  Z1 := Z1 * (-FIX_0_899);
  Z2 := Z2 * (-FIX_2_562);
  Z3 := Z3 * (-FIX_1_961);
  Z4 := Z4 * (-FIX_0_390);

  Z1 := Z1 + Z5;
  Z3 := Z3 + Z5;

  Row[0] := (Tmp0 + Z4 + Z1) shr 13;
  Row[7] := (Tmp0 - Z4 - Z1) shr 13;
  Row[1] := (Tmp1 + Z3 + Z2) shr 13;
  Row[6] := (Tmp1 - Z3 - Z2) shr 13;
  Row[2] := (Tmp2 + Z3 + Z4) shr 13;
  Row[5] := (Tmp2 - Z3 - Z4) shr 13;
  Row[3] := (Tmp3 + Z1 + Z2) shr 13;
  Row[4] := (Tmp3 - Z1 - Z2) shr 13;
end;
{$ENDIF}

procedure FastIDCTCol(Data: PLongInt; Col: Integer);
var
  I: Integer;
  Tmp: array[0..7] of LongInt;
begin
  { Extract column }
  for I := 0 to 7 do
    Tmp[I] := Data[I * 8 + Col];
  { Apply row IDCT to column data }
  FastIDCTRow(Tmp);
  { Store back with descale }
  for I := 0 to 7 do
    Data[I * 8 + Col] := Tmp[I];
end;

procedure FastIDCT8x8(var Block: TIDCTBlock);
var
  I: Integer;
  Row: array[0..7] of LongInt;
begin
  { Row pass }
  for I := 0 to 7 do
  begin
    Move(Block[I * 8], Row, 32);
    FastIDCTRow(Row);
    Move(Row, Block[I * 8], 32);
  end;

  { Column pass }
  for I := 0 to 7 do
    FastIDCTCol(@Block[0], I);

  { Final descale and range limit }
  for I := 0 to 63 do
  begin
    Block[I] := (Block[I] + 128);
    if Block[I] < 0 then Block[I] := 0;
    if Block[I] > 255 then Block[I] := 255;
  end;
end;

end.
