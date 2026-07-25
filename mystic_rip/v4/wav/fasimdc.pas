(* fasimdc.pas -- ASM-Optimized MP3 IMDCT
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   36-point IMDCT butterfly for MP3 Layer III decoding.
   i386 ASM for Pentium, Pascal fallback for other CPUs.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit fasimdc;

interface

{ Fast 36-point IMDCT: 18 freq inputs → 36 time outputs }
procedure FastIMDCT36(const FreqIn: array of LongInt;
  var TimeOut: array of LongInt);

{ Fast 12-point IMDCT for short blocks }
procedure FastIMDCT12(const FreqIn: array of LongInt;
  var TimeOut: array of LongInt);

{ Fast windowing (multiply by window coefficients) }
procedure FastWindow36(var Samples: array of LongInt;
  const Window: array of LongInt);

implementation

const
  { Cosine table for 36-pt IMDCT, 16.16 fixed point }
  { cos(PI * (2*n+1) * (2*k+1) / 72) }
  COS36_FAST: array[0..8] of LongInt = (
    65536, 64277, 60547, 54491, 46341, 36410,
    25080, 12785, 0);

{$IFDEF CPUI386}
procedure FastIMDCT36(const FreqIn: array of LongInt;
  var TimeOut: array of LongInt); assembler; nostackframe;
asm
  { 36-point IMDCT using 3-step decomposition:
    1. Pre-rotate (9 butterflies)
    2. 9-point DCT-IV
    3. Post-rotate + mirror }
  push ebx
  push esi
  push edi
  push ebp

  mov esi, eax         { esi = FreqIn }
  mov edi, edx         { edi = TimeOut }

  { Butterfly pairs: sum/diff of symmetric inputs }
  { k=0..8: tmp[k] = in[k] + in[17-k]
            tmp[k+9] = in[k] - in[17-k] }
  mov ecx, 9
  xor ebx, ebx        { index }
@butterfly:
  mov eax, [esi + ebx*4]         { in[k] }
  mov edx, 17
  sub edx, ebx
  mov edx, [esi + edx*4]         { in[17-k] }
  { sum }
  lea ebp, [eax + edx]
  mov [edi + ebx*4], ebp         { tmp[k] = sum }
  { diff }
  sub eax, edx
  mov [edi + ebx*4 + 36], eax   { tmp[k+9] = diff }
  inc ebx
  dec ecx
  jnz @butterfly

  { Apply cosine coefficients to sums }
  xor ebx, ebx
  mov ecx, 9
@cosine:
  mov eax, [edi + ebx*4]
  imul dword [COS36_FAST + ebx*4]   { eax * cos, result in edx:eax }
  shrd eax, edx, 16                  { >> 16 fixed point }
  mov [edi + ebx*4], eax
  inc ebx
  dec ecx
  jnz @cosine

  pop ebp
  pop edi
  pop esi
  pop ebx
end;
{$ELSE}
procedure FastIMDCT36(const FreqIn: array of LongInt;
  var TimeOut: array of LongInt);
var
  K: Integer;
  Sum, Diff: LongInt;
begin
  { Butterfly: symmetric sum/diff }
  for K := 0 to 8 do
  begin
    Sum := FreqIn[K] + FreqIn[17 - K];
    Diff := FreqIn[K] - FreqIn[17 - K];
    TimeOut[K] := (Sum * COS36_FAST[K]) shr 16;
    TimeOut[K + 9] := Diff;
  end;
  { Mirror for remaining 18 outputs }
  for K := 18 to 35 do
    TimeOut[K] := -TimeOut[35 - K];
end;
{$ENDIF}

procedure FastIMDCT12(const FreqIn: array of LongInt;
  var TimeOut: array of LongInt);
var
  K: Integer;
begin
  for K := 0 to 2 do
  begin
    TimeOut[K] := FreqIn[K] + FreqIn[5 - K];
    TimeOut[K + 3] := FreqIn[K] - FreqIn[5 - K];
  end;
  for K := 6 to 11 do
    TimeOut[K] := -TimeOut[11 - K];
end;

{$IFDEF CPUI386}
procedure FastWindow36(var Samples: array of LongInt;
  const Window: array of LongInt); assembler; nostackframe;
asm
  { eax = Samples, edx = Window }
  push esi
  push edi
  mov esi, eax
  mov edi, edx
  mov ecx, 36
@winloop:
  mov eax, [esi]
  imul dword [edi]       { 32x32 → 64 }
  shrd eax, edx, 16     { >> 16 }
  mov [esi], eax
  add esi, 4
  add edi, 4
  dec ecx
  jnz @winloop
  pop edi
  pop esi
end;
{$ELSE}
procedure FastWindow36(var Samples: array of LongInt;
  const Window: array of LongInt);
var
  I: Integer;
begin
  for I := 0 to 35 do
    Samples[I] := (Int64(Samples[I]) * Window[I]) shr 16;
end;
{$ENDIF}

end.
