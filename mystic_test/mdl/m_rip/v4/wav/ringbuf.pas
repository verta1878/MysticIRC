(* ringbuf.pas -- Audio Ring Buffer
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Lock-free ring buffer for producer/consumer audio streaming.
   Integrates with dosplay.pas double-buffer DMA on DOS.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit ringbuf;

interface

const
  RING_DEFAULT_SIZE = 16384;

type
  TRingBuffer = record
    Buffer: PByte;
    Size: LongWord;
    ReadPos: LongWord;
    WritePos: LongWord;
    Count: LongWord;    { bytes available to read }
  end;

{ Initialize ring buffer }
procedure RingInit(var R: TRingBuffer; Size: LongWord);

{ Free ring buffer }
procedure RingFree(var R: TRingBuffer);

{ Reset to empty }
procedure RingReset(var R: TRingBuffer);

{ Write data into ring buffer. Returns bytes actually written. }
function RingWrite(var R: TRingBuffer; Data: PByte; Len: LongInt): LongInt;

{ Read data from ring buffer. Returns bytes actually read. }
function RingRead(var R: TRingBuffer; Data: PByte; Len: LongInt): LongInt;

{ Peek without consuming }
function RingPeek(var R: TRingBuffer; Data: PByte; Len: LongInt): LongInt;

{ Skip bytes without reading }
procedure RingSkip(var R: TRingBuffer; Len: LongInt);

{ Available to read }
function RingAvailable(var R: TRingBuffer): LongWord;

{ Available to write }
function RingFreeSpace(var R: TRingBuffer): LongWord;

{ Is empty/full }
function RingEmpty(var R: TRingBuffer): Boolean;
function RingFull(var R: TRingBuffer): Boolean;

{ Fill with silence (8-bit unsigned = 128, 16-bit signed = 0) }
procedure RingFillSilence(var R: TRingBuffer; Len: LongInt; Is16Bit: Boolean);

implementation

procedure RingInit(var R: TRingBuffer; Size: LongWord);
begin
  FillChar(R, SizeOf(R), 0);
  if Size = 0 then Size := RING_DEFAULT_SIZE;
  R.Size := Size;
  GetMem(R.Buffer, Size);
  FillChar(R.Buffer^, Size, 0);
end;

procedure RingFree(var R: TRingBuffer);
begin
  if R.Buffer <> nil then begin FreeMem(R.Buffer); R.Buffer := nil; end;
  R.Size := 0;
  R.Count := 0;
end;

procedure RingReset(var R: TRingBuffer);
begin
  R.ReadPos := 0;
  R.WritePos := 0;
  R.Count := 0;
end;

function RingWrite(var R: TRingBuffer; Data: PByte; Len: LongInt): LongInt;
var
  Free: LongWord;
  I: LongInt;
begin
  Free := R.Size - R.Count;
  if LongWord(Len) > Free then Len := Free;
  Result := Len;

  for I := 0 to Len - 1 do
  begin
    R.Buffer[R.WritePos] := Data[I];
    R.WritePos := (R.WritePos + 1) mod R.Size;
  end;
  Inc(R.Count, Len);
end;

function RingRead(var R: TRingBuffer; Data: PByte; Len: LongInt): LongInt;
var
  I: LongInt;
begin
  if LongWord(Len) > R.Count then Len := R.Count;
  Result := Len;

  for I := 0 to Len - 1 do
  begin
    Data[I] := R.Buffer[R.ReadPos];
    R.ReadPos := (R.ReadPos + 1) mod R.Size;
  end;
  Dec(R.Count, Len);
end;

function RingPeek(var R: TRingBuffer; Data: PByte; Len: LongInt): LongInt;
var
  I: LongInt;
  Pos: LongWord;
begin
  if LongWord(Len) > R.Count then Len := R.Count;
  Result := Len;
  Pos := R.ReadPos;
  for I := 0 to Len - 1 do
  begin
    Data[I] := R.Buffer[Pos];
    Pos := (Pos + 1) mod R.Size;
  end;
end;

procedure RingSkip(var R: TRingBuffer; Len: LongInt);
begin
  if LongWord(Len) > R.Count then Len := R.Count;
  R.ReadPos := (R.ReadPos + LongWord(Len)) mod R.Size;
  Dec(R.Count, Len);
end;

function RingAvailable(var R: TRingBuffer): LongWord;
begin Result := R.Count; end;

function RingFreeSpace(var R: TRingBuffer): LongWord;
begin Result := R.Size - R.Count; end;

function RingEmpty(var R: TRingBuffer): Boolean;
begin Result := R.Count = 0; end;

function RingFull(var R: TRingBuffer): Boolean;
begin Result := R.Count >= R.Size; end;

procedure RingFillSilence(var R: TRingBuffer; Len: LongInt; Is16Bit: Boolean);
var
  Free: LongWord;
  I: LongInt;
  SilVal: Byte;
begin
  Free := R.Size - R.Count;
  if LongWord(Len) > Free then Len := Free;
  if Is16Bit then SilVal := 0 else SilVal := 128;
  for I := 0 to Len - 1 do
  begin
    R.Buffer[R.WritePos] := SilVal;
    R.WritePos := (R.WritePos + 1) mod R.Size;
  end;
  Inc(R.Count, Len);
end;

end.
