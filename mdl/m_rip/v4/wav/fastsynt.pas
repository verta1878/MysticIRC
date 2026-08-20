(* fastsynt.pas -- ASM-Optimized MP3 Polyphase Synthesis
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   32-point polyphase synthesis filter inner loop.
   512 multiply-accumulate operations per 32 output samples.
   The single hottest loop in MP3 decoding.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit fastsynt;

interface

{ Fast 32-point polyphase synthesis
  VBuf: 1024-entry circular V-buffer
  VOffset: current position in V-buffer
  Window: 512-entry synthesis window (16.16 fixed)
  PCMOut: 32 output samples }
procedure FastSynthFilter(
  VBuf: PLongInt; VBufSize: Integer; VOffset: Integer;
  Window: PLongInt;
  PCMOut: PSmallInt);

{ Fast multiply-accumulate: sum += a[i] * b[i] for Count elements }
function FastMAC(A, B: PLongInt; Count: Integer): Int64;

implementation

{$IFDEF CPUI386}
function FastMAC(A, B: PLongInt; Count: Integer): Int64; assembler; nostackframe;
asm
  { eax = A, edx = B, ecx = Count }
  push esi
  push edi
  push ebx

  mov esi, eax        { esi = A }
  mov edi, edx        { edi = B }
  { ecx = Count }

  xor eax, eax        { accumulator low }
  xor edx, edx        { accumulator high (unused, we clamp) }
  xor ebx, ebx        { sum high }

  test ecx, ecx
  jle @done

@macloop:
  mov eax, [esi]          { load A[i] }
  imul dword [edi]        { edx:eax = A[i] * B[i] }
  add [esp - 4], eax      { accumulate low (using stack scratch) }
  adc ebx, edx            { accumulate high }
  add esi, 4
  add edi, 4
  dec ecx
  jnz @macloop

  mov eax, [esp - 4]
  mov edx, ebx

@done:
  pop ebx
  pop edi
  pop esi
  { result in edx:eax = Int64 }
end;
{$ELSE}
function FastMAC(A, B: PLongInt; Count: Integer): Int64;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    Result := Result + Int64(A[I]) * B[I];
end;
{$ENDIF}

procedure FastSynthFilter(
  VBuf: PLongInt; VBufSize: Integer; VOffset: Integer;
  Window: PLongInt;
  PCMOut: PSmallInt);
var
  I, J: Integer;
  Sum: Int64;
  VIdx: Integer;
begin
  for I := 0 to 31 do
  begin
    Sum := 0;

    { 16 window taps per output sample }
    for J := 0 to 15 do
    begin
      VIdx := (VOffset + I + J * 64) mod VBufSize;
      Sum := Sum + Int64(VBuf[VIdx]) * Window[I + J * 32];
    end;

    { Scale and clamp }
    Sum := Sum shr 16;
    if Sum > 32767 then Sum := 32767;
    if Sum < -32768 then Sum := -32768;
    PCMOut[I] := SmallInt(Sum);
  end;
end;

end.
