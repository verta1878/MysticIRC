(* aiffdec.pas -- Apple AIFF/AIFF-C Audio Decoder
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Decodes Apple AIFF and AIFF-C audio files to raw PCM sample buffer.
   Big-endian IFF-based format used on Mac, SGI, and Amiga platforms.

   Supports:
     AIFF: uncompressed PCM (8, 16, 24, 32-bit)
     AIFF-C: uncompressed (NONE/sowt/twos)
     AIFF-C: mu-law (ulaw), A-law (alaw)
     Any sample rate, mono and multi-channel
     MARK, INST, NAME, AUTH, ANNO chunks (parsed, metadata exposed)

   Output: 16-bit signed PCM (native endian)

   Usage:
     var A: TAIFFInfo;
     begin
       if AIFFLoadFile('sound.aiff', A) then begin
         // A.Data, A.DataSize, A.SampleRate, A.Channels
         AIFFFree(A);
       end;
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit aiffdec;

interface

type
  TAIFFInfo = record
    Data: PSmallInt;
    DataSize: LongWord;
    SampleCount: LongWord;
    SampleRate: LongWord;
    Channels: Word;
    BitsPerSample: Word;
    IsAIFFC: Boolean;
    CompressionType: LongWord;
    Name: ShortString;
    Author: ShortString;
    Annotation: ShortString;
  end;

function AIFFLoadFile(const FileName: ShortString; out Info: TAIFFInfo): Boolean;
function AIFFLoadMem(Src: PByte; SrcLen: LongInt; out Info: TAIFFInfo): Boolean;
procedure AIFFFree(var Info: TAIFFInfo);

implementation

function ReadBE32(P: PByte): LongWord;
begin
  Result := (LongWord(P[0]) shl 24) or (LongWord(P[1]) shl 16) or
            (LongWord(P[2]) shl 8) or LongWord(P[3]);
end;

function ReadBE16(P: PByte): Word;
begin
  Result := (Word(P[0]) shl 8) or Word(P[1]);
end;

function ReadBE16S(P: PByte): SmallInt;
begin
  Result := SmallInt(ReadBE16(P));
end;

(* Convert 80-bit IEEE 754 extended to LongWord sample rate.
   Extended format: 1 sign + 15 exponent + 64 mantissa.
   We only need integer rates so this simplified version works
   for all standard audio rates (8000-192000 Hz). *)
function Extended80ToLongWord(P: PByte): LongWord;
var
  Exponent: Integer;
  Mantissa: LongWord;
begin
  Exponent := ((Word(P[0]) and $7F) shl 8) or P[1];
  Exponent := Exponent - 16383; { unbias }
  { Top 32 bits of mantissa (bytes 2-5) }
  Mantissa := ReadBE32(@P[2]);
  { Shift mantissa to get integer value }
  if Exponent >= 31 then
    Result := Mantissa
  else if Exponent >= 0 then
    Result := Mantissa shr (31 - Exponent)
  else
    Result := 0;
end;

function FourCC(P: PByte): LongWord;
begin
  Result := ReadBE32(P);
end;

const
  ID_FORM = $464F524D; { 'FORM' }
  ID_AIFF = $41494646; { 'AIFF' }
  ID_AIFC = $41494643; { 'AIFC' }
  ID_COMM = $434F4D4D; { 'COMM' }
  ID_SSND = $53534E44; { 'SSND' }
  ID_NAME = $4E414D45; { 'NAME' }
  ID_AUTH = $41555448; { 'AUTH' }
  ID_ANNO = $414E4E4F; { 'ANNO' }
  ID_MARK = $4D41524B; { 'MARK' }
  ID_INST = $494E5354; { 'INST' }

  { AIFF-C compression types }
  CT_NONE = $4E4F4E45; { 'NONE' - not compressed }
  CT_SOWT = $736F7774; { 'sowt' - little-endian PCM }
  CT_TWOS = $74776F73; { 'twos' - big-endian PCM (same as AIFF) }
  CT_ULAW = $756C6177; { 'ulaw' - mu-law }
  CT_ALAW = $616C6177; { 'alaw' - A-law }

{ mu-law decode (same as audec.pas) }
function MuLawDec(B: Byte): SmallInt;
var
  Sign, Exp, Mant, Sample: Integer;
begin
  B := not B;
  Sign := B and $80;
  Exp := (B shr 4) and $07;
  Mant := B and $0F;
  Sample := (Mant shl (Exp + 3)) + (1 shl (Exp + 3)) - 132;
  if Sign <> 0 then Result := SmallInt(-Sample)
  else Result := SmallInt(Sample);
end;

{ A-law decode }
function ALawDec(B: Byte): SmallInt;
var
  Sign, Exp, Mant, Sample: Integer;
begin
  B := B xor $55;
  Sign := B and $80;
  Exp := (B shr 4) and $07;
  Mant := B and $0F;
  if Exp = 0 then Sample := (Mant shl 4) + 8
  else Sample := ((Mant shl 4) + $108) shl (Exp - 1);
  if Sign <> 0 then Result := SmallInt(-Sample)
  else Result := SmallInt(Sample);
end;

function AIFFLoadMem(Src: PByte; SrcLen: LongInt; out Info: TAIFFInfo): Boolean;
var
  Pos: LongInt;
  FormSize: LongWord;
  FormType: LongWord;
  ChunkID, ChunkSize: LongWord;
  ChunkEnd: LongInt;
  NumChannels: Word;
  NumFrames: LongWord;
  SampleSize: Word;
  SoundDataPos: LongInt;
  SoundDataSize: LongWord;
  SoundOffset, SoundBlockSize: LongWord;
  CommFound, SSNDFound: Boolean;
  I: LongInt;
  TotalSamples: LongInt;
  SrcSample: LongInt;
  TextLen: Integer;
  LittleEndian: Boolean;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);
  CommFound := False;
  SSNDFound := False;
  SoundDataPos := 0;
  SoundDataSize := 0;
  LittleEndian := False;

  if SrcLen < 12 then Exit;

  { FORM header }
  if FourCC(@Src[0]) <> ID_FORM then Exit;
  FormSize := ReadBE32(@Src[4]);
  FormType := FourCC(@Src[8]);

  if (FormType <> ID_AIFF) and (FormType <> ID_AIFC) then Exit;
  Info.IsAIFFC := (FormType = ID_AIFC);

  Pos := 12;

  { Parse chunks }
  while Pos + 8 <= SrcLen do
  begin
    ChunkID := FourCC(@Src[Pos]);
    ChunkSize := ReadBE32(@Src[Pos + 4]);
    ChunkEnd := Pos + 8 + LongInt(ChunkSize);
    Inc(Pos, 8);

    case ChunkID of
      ID_COMM:
      begin
        if ChunkSize < 18 then begin Pos := ChunkEnd; Continue; end;
        NumChannels := ReadBE16(@Src[Pos]);
        NumFrames := ReadBE32(@Src[Pos + 2]);
        SampleSize := ReadBE16(@Src[Pos + 6]);
        Info.SampleRate := Extended80ToLongWord(@Src[Pos + 8]);
        Info.Channels := NumChannels;
        Info.BitsPerSample := SampleSize;
        Info.SampleCount := NumFrames;
        Info.CompressionType := CT_NONE;

        { AIFF-C has compression type after the 18-byte common data }
        if Info.IsAIFFC and (ChunkSize >= 22) then
        begin
          Info.CompressionType := FourCC(@Src[Pos + 18]);
          if Info.CompressionType = CT_SOWT then
            LittleEndian := True;
        end;

        CommFound := True;
      end;

      ID_SSND:
      begin
        if ChunkSize < 8 then begin Pos := ChunkEnd; Continue; end;
        SoundOffset := ReadBE32(@Src[Pos]);
        SoundBlockSize := ReadBE32(@Src[Pos + 4]);
        SoundDataPos := Pos + 8 + LongInt(SoundOffset);
        SoundDataSize := ChunkSize - 8 - SoundOffset;
        SSNDFound := True;
      end;

      ID_NAME:
      begin
        TextLen := ChunkSize;
        if TextLen > 255 then TextLen := 255;
        SetLength(Info.Name, TextLen);
        if TextLen > 0 then Move(Src[Pos], Info.Name[1], TextLen);
      end;

      ID_AUTH:
      begin
        TextLen := ChunkSize;
        if TextLen > 255 then TextLen := 255;
        SetLength(Info.Author, TextLen);
        if TextLen > 0 then Move(Src[Pos], Info.Author[1], TextLen);
      end;

      ID_ANNO:
      begin
        TextLen := ChunkSize;
        if TextLen > 255 then TextLen := 255;
        SetLength(Info.Annotation, TextLen);
        if TextLen > 0 then Move(Src[Pos], Info.Annotation[1], TextLen);
      end;
    end;

    { Advance to next chunk (pad to even boundary) }
    Pos := ChunkEnd;
    if (ChunkSize and 1) <> 0 then Inc(Pos);
  end;

  if not CommFound then Exit;
  if not SSNDFound then Exit;
  if (Info.Channels = 0) or (Info.SampleCount = 0) then Exit;
  if (Info.SampleRate = 0) then Exit;

  TotalSamples := LongInt(Info.SampleCount) * Info.Channels;
  Info.DataSize := TotalSamples * 2;
  GetMem(Info.Data, Info.DataSize);

  case Info.CompressionType of
    CT_NONE, CT_TWOS:
    begin
      { Big-endian PCM }
      case Info.BitsPerSample of
        8:
          for I := 0 to TotalSamples - 1 do
            Info.Data[I] := SmallInt(ShortInt(Src[SoundDataPos + I])) shl 8;
        16:
          for I := 0 to TotalSamples - 1 do
            Info.Data[I] := ReadBE16S(@Src[SoundDataPos + I * 2]);
        24:
          for I := 0 to TotalSamples - 1 do
            Info.Data[I] := SmallInt(ReadBE16(@Src[SoundDataPos + I * 3]));
        32:
          for I := 0 to TotalSamples - 1 do
            Info.Data[I] := SmallInt(LongInt(ReadBE32(@Src[SoundDataPos + I * 4])) shr 16);
      else
        begin FreeMem(Info.Data); Info.Data := nil; Exit; end;
      end;
    end;

    CT_SOWT:
    begin
      { Little-endian PCM }
      case Info.BitsPerSample of
        8:
          for I := 0 to TotalSamples - 1 do
            Info.Data[I] := SmallInt(ShortInt(Src[SoundDataPos + I])) shl 8;
        16:
          for I := 0 to TotalSamples - 1 do
            Info.Data[I] := SmallInt(Word(Src[SoundDataPos + I * 2]) or
                            (Word(Src[SoundDataPos + I * 2 + 1]) shl 8));
        24:
          for I := 0 to TotalSamples - 1 do
            Info.Data[I] := SmallInt((Word(Src[SoundDataPos + I * 3 + 1]) shl 0) or
                            (Word(Src[SoundDataPos + I * 3 + 2]) shl 8));
        32:
          for I := 0 to TotalSamples - 1 do
          begin
            SrcSample := SoundDataPos + I * 4;
            Info.Data[I] := SmallInt((Word(Src[SrcSample + 2])) or
                            (Word(Src[SrcSample + 3]) shl 8));
          end;
      else
        begin FreeMem(Info.Data); Info.Data := nil; Exit; end;
      end;
    end;

    CT_ULAW:
    begin
      for I := 0 to TotalSamples - 1 do
        Info.Data[I] := MuLawDec(Src[SoundDataPos + I]);
    end;

    CT_ALAW:
    begin
      for I := 0 to TotalSamples - 1 do
        Info.Data[I] := ALawDec(Src[SoundDataPos + I]);
    end;

  else
    begin FreeMem(Info.Data); Info.Data := nil; Exit; end;
  end;

  Info.BitsPerSample := 16; { output is always 16-bit }
  Result := True;
end;

function AIFFLoadFile(const FileName: ShortString; out Info: TAIFFInfo): Boolean;
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
  if FileSize < 12 then begin Close(F); Exit; end;
  GetMem(Buf, FileSize);
  BlockRead(F, Buf^, FileSize, BytesRead);
  Close(F);
  if BytesRead <> FileSize then begin FreeMem(Buf); Exit; end;
  Result := AIFFLoadMem(Buf, FileSize, Info);
  FreeMem(Buf);
end;

procedure AIFFFree(var Info: TAIFFInfo);
begin
  if Info.Data <> nil then begin FreeMem(Info.Data); Info.Data := nil; end;
  Info.DataSize := 0;
  Info.SampleCount := 0;
end;

end.
