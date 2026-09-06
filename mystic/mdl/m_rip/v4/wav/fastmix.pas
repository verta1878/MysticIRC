(* fastmix.pas -- ASM-Optimized Audio Mixing
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   i386 ASM fast paths for sample mixing, volume scaling,
   and stereo panning. Falls back to Pascal on other CPUs.
   Critical for MOD/S3M/XM playback on 486/Pentium.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit fastmix;

interface

{ Mix src into dst buffer (signed 16-bit, add with clamp) }
procedure FastMixAdd(Dst, Src: PSmallInt; Count: LongInt);

{ Scale buffer by volume (0-255) in place }
procedure FastVolScale(Buf: PSmallInt; Count: LongInt; Volume: Integer);

{ Stereo pan: split mono into left/right with panning (0=left, 128=center, 255=right) }
procedure FastStereoPan(Mono: PSmallInt; Left, Right: PSmallInt;
  Count: LongInt; Pan: Integer);

{ Interleave two mono buffers into stereo }
procedure FastInterleave(Left, Right: PSmallInt; Stereo: PSmallInt; Count: LongInt);

{ Convert unsigned 8-bit to signed 16-bit }
procedure FastU8toS16(Src: PByte; Dst: PSmallInt; Count: LongInt);

{ Clamp 32-bit to 16-bit }
procedure FastClamp32to16(Src: PLongInt; Dst: PSmallInt; Count: LongInt);

implementation

{$IFDEF CPUI386}
procedure FastMixAdd(Dst, Src: PSmallInt; Count: LongInt); assembler; nostackframe;
asm
  { eax = Dst, edx = Src, ecx = Count }
  push esi
  push edi
  mov edi, eax        { edi = Dst }
  mov esi, edx        { esi = Src }
  { ecx already = Count }
  test ecx, ecx
  jle @done
@loop:
  movsx eax, word [esi]    { load src sample, sign-extend to 32 }
  movsx edx, word [edi]    { load dst sample }
  add eax, edx             { mix }
  { clamp to -32768..32767 }
  cmp eax, 32767
  jle @nohi
  mov eax, 32767
  jmp @store
@nohi:
  cmp eax, -32768
  jge @store
  mov eax, -32768
@store:
  mov [edi], ax
  add esi, 2
  add edi, 2
  dec ecx
  jnz @loop
@done:
  pop edi
  pop esi
end;

procedure FastVolScale(Buf: PSmallInt; Count: LongInt; Volume: Integer); assembler; nostackframe;
asm
  { eax = Buf, edx = Count, ecx = Volume }
  push esi
  mov esi, eax        { esi = Buf }
  mov eax, ecx        { eax = Volume }
  mov ecx, edx        { ecx = Count }
  test ecx, ecx
  jle @done
@loop:
  movsx edx, word [esi]    { load sample }
  imul edx, eax            { sample * volume }
  sar edx, 8               { /256 }
  { clamp }
  cmp edx, 32767
  jle @nohi
  mov edx, 32767
  jmp @store
@nohi:
  cmp edx, -32768
  jge @store
  mov edx, -32768
@store:
  mov [esi], dx
  add esi, 2
  dec ecx
  jnz @loop
@done:
  pop esi
end;
{$ELSE}
{ Pascal fallbacks }
procedure FastMixAdd(Dst, Src: PSmallInt; Count: LongInt);
var
  I: LongInt;
  V: LongInt;
begin
  for I := 0 to Count - 1 do
  begin
    V := LongInt(Dst[I]) + LongInt(Src[I]);
    if V > 32767 then V := 32767;
    if V < -32768 then V := -32768;
    Dst[I] := SmallInt(V);
  end;
end;

procedure FastVolScale(Buf: PSmallInt; Count: LongInt; Volume: Integer);
var
  I: LongInt;
  V: LongInt;
begin
  for I := 0 to Count - 1 do
  begin
    V := (LongInt(Buf[I]) * Volume) div 256;
    if V > 32767 then V := 32767;
    if V < -32768 then V := -32768;
    Buf[I] := SmallInt(V);
  end;
end;
{$ENDIF}

procedure FastStereoPan(Mono: PSmallInt; Left, Right: PSmallInt;
  Count: LongInt; Pan: Integer);
var
  I: LongInt;
  S: LongInt;
  LV, RV: Integer;
begin
  LV := 255 - Pan;
  RV := Pan;
  for I := 0 to Count - 1 do
  begin
    S := Mono[I];
    Left[I] := SmallInt((S * LV) div 255);
    Right[I] := SmallInt((S * RV) div 255);
  end;
end;

procedure FastInterleave(Left, Right: PSmallInt; Stereo: PSmallInt; Count: LongInt);
var
  I: LongInt;
begin
  for I := 0 to Count - 1 do
  begin
    Stereo[I * 2] := Left[I];
    Stereo[I * 2 + 1] := Right[I];
  end;
end;

procedure FastU8toS16(Src: PByte; Dst: PSmallInt; Count: LongInt);
var
  I: LongInt;
begin
  for I := 0 to Count - 1 do
    Dst[I] := SmallInt((Integer(Src[I]) - 128) shl 8);
end;

procedure FastClamp32to16(Src: PLongInt; Dst: PSmallInt; Count: LongInt);
var
  I: LongInt;
  V: LongInt;
begin
  for I := 0 to Count - 1 do
  begin
    V := Src[I];
    if V > 32767 then V := 32767;
    if V < -32768 then V := -32768;
    Dst[I] := SmallInt(V);
  end;
end;

end.
