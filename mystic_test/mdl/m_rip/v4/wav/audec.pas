(* audec.pas -- Sun/NeXT AU (SND) Audio Decoder
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Decodes Sun AU (.au/.snd) audio files to raw PCM sample buffer.
   Big-endian format used on Sun, NeXT, and Java platforms.

   Supports:
     Encoding 1: 8-bit mu-law (decoded to 16-bit signed PCM)
     Encoding 2: 8-bit linear PCM
     Encoding 3: 16-bit linear PCM
     Encoding 4: 24-bit linear PCM (downsampled to 16-bit)
     Encoding 5: 32-bit linear PCM (downsampled to 16-bit)
     Encoding 27: 8-bit A-law (decoded to 16-bit signed PCM)
     Any sample rate, mono and multi-channel

   Usage:
     var A: TAUInfo;
     begin
       if AULoadFile('sound.au', A) then begin
         // A.Data = 16-bit signed PCM (native endian)
         // A.DataSize, A.SampleRate, A.Channels
         AUFree(A);
       end;
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit audec;

interface

type
  TAUInfo = record
    Data: PSmallInt;
    DataSize: LongWord;    { bytes }
    SampleCount: LongWord; { samples per channel }
    SampleRate: LongWord;
    Channels: LongWord;
    BitsPerSample: Word;   { always 16 in output }
    Encoding: LongWord;    { original encoding }
    HasAnnotation: Boolean;
    Annotation: ShortString;
  end;

function AULoadFile(const FileName: ShortString; out Info: TAUInfo): Boolean;
function AULoadMem(Src: PByte; SrcLen: LongInt; out Info: TAUInfo): Boolean;
procedure AUFree(var Info: TAUInfo);

{ Decode single mu-law byte to 16-bit signed }
function MuLawDecode(B: Byte): SmallInt;

{ Decode single A-law byte to 16-bit signed }
function ALawDecode(B: Byte): SmallInt;

implementation

const
  AU_MAGIC = $2E736E64; { '.snd' big-endian }

  { AU encoding types }
  AU_MULAW_8    = 1;
  AU_LINEAR_8   = 2;
  AU_LINEAR_16  = 3;
  AU_LINEAR_24  = 4;
  AU_LINEAR_32  = 5;
  AU_ALAW_8     = 27;

function MuLawDecode(B: Byte): SmallInt;
var
  Sign, Exponent, Mantissa: Integer;
  Sample: Integer;
begin
  B := not B;
  Sign := B and $80;
  Exponent := (B shr 4) and $07;
  Mantissa := B and $0F;
  Sample := (Mantissa shl (Exponent + 3)) + (1 shl (Exponent + 3)) - 132;
  if Sign <> 0 then
    Result := SmallInt(-Sample)
  else
    Result := SmallInt(Sample);
end;

function ALawDecode(B: Byte): SmallInt;
var
  Sign, Exponent, Mantissa: Integer;
  Sample: Integer;
begin
  B := B xor $55;
  Sign := B and $80;
  Exponent := (B shr 4) and $07;
  Mantissa := B and $0F;
  if Exponent = 0 then
    Sample := (Mantissa shl 4) + 8
  else
    Sample := ((Mantissa shl 4) + $108) shl (Exponent - 1);
  if Sign <> 0 then
    Result := SmallInt(-Sample)
  else
    Result := SmallInt(Sample);
end;

function ReadBE32(P: PByte): LongWord;
begin
  Result := (LongWord(P[0]) shl 24) or (LongWord(P[1]) shl 16) or
            (LongWord(P[2]) shl 8) or LongWord(P[3]);
end;

function ReadBE16(P: PByte): Word;
begin
  Result := (Word(P[0]) shl 8) or Word(P[1]);
end;

function AULoadMem(Src: PByte; SrcLen: LongInt; out Info: TAUInfo): Boolean;
var
  Magic, DataOffset, DataSize, Encoding, SampleRate, Channels: LongWord;
  SrcPos: LongInt;
  I, J: LongInt;
  OutSamples: LongInt;
  AnnLen: Integer;
  Sample32: LongInt;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);

  if SrcLen < 24 then Exit;

  { Parse header (all big-endian) }
  Magic := ReadBE32(@Src[0]);
  if Magic <> AU_MAGIC then Exit;

  DataOffset := ReadBE32(@Src[4]);
  DataSize := ReadBE32(@Src[8]);
  Encoding := ReadBE32(@Src[12]);
  SampleRate := ReadBE32(@Src[16]);
  Channels := ReadBE32(@Src[20]);

  if (SampleRate = 0) or (Channels = 0) then Exit;
  if DataOffset < 24 then DataOffset := 24;
  if LongInt(DataOffset) > SrcLen then Exit;

  { Read annotation if present (between header and data) }
  if DataOffset > 24 then
  begin
    AnnLen := DataOffset - 24;
    if AnnLen > 255 then AnnLen := 255;
    Info.HasAnnotation := True;
    SetLength(Info.Annotation, AnnLen);
    Move(Src[24], Info.Annotation[1], AnnLen);
    while (Length(Info.Annotation) > 0) and
          (Info.Annotation[Length(Info.Annotation)] = #0) do
      SetLength(Info.Annotation, Length(Info.Annotation) - 1);
  end;

  Info.Encoding := Encoding;
  Info.SampleRate := SampleRate;
  Info.Channels := Channels;
  Info.BitsPerSample := 16; { output always 16-bit }

  { Actual data size }
  if DataSize = $FFFFFFFF then
    DataSize := SrcLen - DataOffset
  else if LongInt(DataOffset + DataSize) > SrcLen then
    DataSize := SrcLen - DataOffset;

  SrcPos := DataOffset;

  case Encoding of
    AU_MULAW_8:
    begin
      OutSamples := DataSize;
      Info.SampleCount := OutSamples div Channels;
      Info.DataSize := OutSamples * 2;
      GetMem(Info.Data, Info.DataSize);
      for I := 0 to OutSamples - 1 do
        Info.Data[I] := MuLawDecode(Src[SrcPos + I]);
    end;

    AU_ALAW_8:
    begin
      OutSamples := DataSize;
      Info.SampleCount := OutSamples div Channels;
      Info.DataSize := OutSamples * 2;
      GetMem(Info.Data, Info.DataSize);
      for I := 0 to OutSamples - 1 do
        Info.Data[I] := ALawDecode(Src[SrcPos + I]);
    end;

    AU_LINEAR_8:
    begin
      OutSamples := DataSize;
      Info.SampleCount := OutSamples div Channels;
      Info.DataSize := OutSamples * 2;
      GetMem(Info.Data, Info.DataSize);
      { 8-bit signed -> 16-bit signed }
      for I := 0 to OutSamples - 1 do
        Info.Data[I] := SmallInt(ShortInt(Src[SrcPos + I])) shl 8;
    end;

    AU_LINEAR_16:
    begin
      OutSamples := DataSize div 2;
      Info.SampleCount := OutSamples div Channels;
      Info.DataSize := OutSamples * 2;
      GetMem(Info.Data, Info.DataSize);
      { Big-endian 16-bit -> native endian }
      for I := 0 to OutSamples - 1 do
        Info.Data[I] := SmallInt(ReadBE16(@Src[SrcPos + I * 2]));
    end;

    AU_LINEAR_24:
    begin
      OutSamples := DataSize div 3;
      Info.SampleCount := OutSamples div Channels;
      Info.DataSize := OutSamples * 2;
      GetMem(Info.Data, Info.DataSize);
      { 24-bit big-endian -> 16-bit (take top 16 bits) }
      for I := 0 to OutSamples - 1 do
      begin
        J := SrcPos + I * 3;
        Info.Data[I] := SmallInt((Word(Src[J]) shl 8) or Word(Src[J + 1]));
      end;
    end;

    AU_LINEAR_32:
    begin
      OutSamples := DataSize div 4;
      Info.SampleCount := OutSamples div Channels;
      Info.DataSize := OutSamples * 2;
      GetMem(Info.Data, Info.DataSize);
      { 32-bit big-endian -> 16-bit (take top 16 bits) }
      for I := 0 to OutSamples - 1 do
      begin
        Sample32 := LongInt(ReadBE32(@Src[SrcPos + I * 4]));
        Info.Data[I] := SmallInt(Sample32 shr 16);
      end;
    end;

  else
    Exit; { Unsupported encoding }
  end;

  Result := True;
end;

function AULoadFile(const FileName: ShortString; out Info: TAUInfo): Boolean;
var
  F: File;
  Buf: PByte;
  FileSize, BytesRead: LongInt;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FileSize := System.FileSize(F);
  if FileSize < 24 then begin Close(F); Exit; end;
  GetMem(Buf, FileSize);
  BlockRead(F, Buf^, FileSize, BytesRead);
  Close(F);
  if BytesRead <> FileSize then begin FreeMem(Buf); Exit; end;
  Result := AULoadMem(Buf, FileSize, Info);
  FreeMem(Buf);
end;

procedure AUFree(var Info: TAUInfo);
begin
  if Info.Data <> nil then begin FreeMem(Info.Data); Info.Data := nil; end;
  Info.DataSize := 0;
  Info.SampleCount := 0;
end;

end.
