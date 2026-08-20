(* vocdec.pas -- Creative Voice File (VOC) Decoder
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Creative Voice File (.VOC) decoder - Sound Blaster native format.
   Decodes VOC files to raw PCM sample buffer.

   Supports:
     Block type 0x01: Sound data (8-bit unsigned PCM)
     Block type 0x02: Sound data continuation
     Block type 0x03: Silence
     Block type 0x04: Marker
     Block type 0x05: ASCII text
     Block type 0x06: Repeat loop start
     Block type 0x07: Repeat loop end
     Block type 0x08: Extended info (stereo, high sample rates)
     Block type 0x09: Sound data (new format - 8/16-bit, mono/stereo)
     Codec 0x00: 8-bit unsigned PCM
     Codec 0x04: 16-bit signed PCM
     Codec 0x01-0x03: ADPCM 4/2.6/2-bit (detected, not decoded)

   Usage:
     var V: TVOCInfo;
     begin
       if VOCLoadFile('sound.voc', V) then begin
         // V.Data = raw PCM, V.DataSize = byte count
         // V.SampleRate, V.BitsPerSample, V.Channels
         VOCFree(V);
       end;
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit vocdec;

interface

type
  TVOCInfo = record
    Data: PByte;
    DataSize: LongWord;
    SampleRate: LongWord;
    BitsPerSample: Word;
    Channels: Word;
    MajorVer: Byte;
    MinorVer: Byte;
    HasText: Boolean;
    Text: ShortString;
  end;

function VOCLoadFile(const FileName: ShortString; out Info: TVOCInfo): Boolean;
function VOCLoadMem(Src: PByte; SrcLen: LongInt; out Info: TVOCInfo): Boolean;
procedure VOCFree(var Info: TVOCInfo);

{ Convert VOC sample rate from time constant }
function VOCTimeConstToRate(TC: Byte; Channels: Word): LongWord;

implementation

const
  VOC_MAGIC = 'Creative Voice File';
  VOC_MAGIC_LEN = 19;
  VOC_EOF_MARKER = $1A;

  { Block types }
  BLK_TERMINATOR  = $00;
  BLK_SOUND_DATA  = $01;
  BLK_SOUND_CONT  = $02;
  BLK_SILENCE     = $03;
  BLK_MARKER      = $04;
  BLK_TEXT        = $05;
  BLK_REPEAT      = $06;
  BLK_REPEAT_END  = $07;
  BLK_EXTENDED    = $08;
  BLK_SOUND_NEW   = $09;

  { Codecs }
  CODEC_PCM_U8     = $00;
  CODEC_ADPCM_4BIT = $01;
  CODEC_ADPCM_26   = $02;
  CODEC_ADPCM_2BIT = $03;
  CODEC_PCM_S16    = $04;

function VOCTimeConstToRate(TC: Byte; Channels: Word): LongWord;
begin
  if Channels < 1 then Channels := 1;
  Result := 1000000 div (256 - LongWord(TC));
  if Channels = 2 then
    Result := Result div 2;
end;

function VOCLoadMem(Src: PByte; SrcLen: LongInt; out Info: TVOCInfo): Boolean;
var
  Pos: LongInt;
  I: Integer;
  BlockType: Byte;
  BlockLen: LongWord;
  TimeConst: Byte;
  Codec: Byte;
  ExtSampleRate: Word;
  ExtCodec: Byte;
  ExtChannels: Byte;
  UseExtended: Boolean;
  NewRate: LongWord;
  NewBits: Word;
  NewChans: Word;
  SilSamples: Word;
  SilTC: Byte;
  RepeatCount: Word;
  RepeatPos: LongInt;
  RepeatRemaining: Integer;
  DataChunk: PByte;
  DataChunkSize: LongWord;
  NewBuf: PByte;
  TextLen: Integer;

  function ReadByte: Byte;
  begin
    if Pos < SrcLen then begin Result := Src[Pos]; Inc(Pos); end
    else Result := 0;
  end;

  function ReadWord: Word;
  begin
    Result := ReadByte or (Word(ReadByte) shl 8);
  end;

  function ReadDWord: LongWord;
  begin
    Result := ReadByte or (LongWord(ReadByte) shl 8) or
              (LongWord(ReadByte) shl 16) or (LongWord(ReadByte) shl 24);
  end;

  procedure AppendData(P: PByte; Len: LongWord);
  begin
    if Len = 0 then Exit;
    ReallocMem(Info.Data, Info.DataSize + Len);
    Move(P^, Info.Data[Info.DataSize], Len);
    Inc(Info.DataSize, Len);
  end;

  procedure AppendSilence(Samples: LongWord);
  var
    SilBuf: PByte;
    SilSize: LongWord;
    J: LongWord;
  begin
    SilSize := Samples * (Info.BitsPerSample div 8) * Info.Channels;
    GetMem(SilBuf, SilSize);
    if Info.BitsPerSample = 8 then
      FillChar(SilBuf^, SilSize, 128)  { 8-bit unsigned silence = 128 }
    else
      FillChar(SilBuf^, SilSize, 0);   { 16-bit signed silence = 0 }
    AppendData(SilBuf, SilSize);
    FreeMem(SilBuf);
  end;

begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);
  Info.Data := nil;
  Info.BitsPerSample := 8;
  Info.Channels := 1;
  Info.SampleRate := 8000;
  UseExtended := False;

  { Check minimum size: 19 (magic) + 1 (EOF) + 2 (offset) + 2 (version) + 2 (check) = 26 }
  if SrcLen < 26 then Exit;

  { Verify magic string }
  for I := 0 to VOC_MAGIC_LEN - 1 do
    if Chr(Src[I]) <> VOC_MAGIC[I + 1] then Exit;

  if Src[VOC_MAGIC_LEN] <> VOC_EOF_MARKER then Exit;

  { Read header }
  Pos := 20; { skip magic + EOF marker }
  I := ReadWord; { data offset from start of file }
  Info.MinorVer := ReadByte;
  Info.MajorVer := ReadByte;
  ReadWord; { version check value }

  { Jump to data offset }
  Pos := I;

  RepeatCount := 0;
  RepeatPos := 0;
  RepeatRemaining := -1;

  { Parse blocks }
  while Pos < SrcLen do
  begin
    BlockType := ReadByte;

    if BlockType = BLK_TERMINATOR then
    begin
      { Check repeat }
      if RepeatRemaining > 0 then
      begin
        Dec(RepeatRemaining);
        Pos := RepeatPos;
        Continue;
      end
      else if RepeatRemaining = 0 then
        Break  { repeat exhausted }
      else
        Break; { no repeat, done }
    end;

    { Read 3-byte block length }
    BlockLen := ReadByte or (LongWord(ReadByte) shl 8) or (LongWord(ReadByte) shl 16);

    case BlockType of
      BLK_SOUND_DATA:
      begin
        if BlockLen < 2 then begin Inc(Pos, BlockLen); Continue; end;
        TimeConst := ReadByte;
        Codec := ReadByte;

        if UseExtended then
          UseExtended := False  { extended block already set rate/channels }
        else
        begin
          Info.SampleRate := VOCTimeConstToRate(TimeConst, 1);
          Info.Channels := 1;
        end;

        case Codec of
          CODEC_PCM_U8:
          begin
            Info.BitsPerSample := 8;
            AppendData(@Src[Pos], BlockLen - 2);
          end;
          CODEC_PCM_S16:
          begin
            Info.BitsPerSample := 16;
            AppendData(@Src[Pos], BlockLen - 2);
          end;
        else
          { ADPCM codecs - skip for now, copy raw }
          AppendData(@Src[Pos], BlockLen - 2);
        end;
        Inc(Pos, BlockLen - 2);
      end;

      BLK_SOUND_CONT:
      begin
        { Continuation of previous sound data }
        AppendData(@Src[Pos], BlockLen);
        Inc(Pos, BlockLen);
      end;

      BLK_SILENCE:
      begin
        if BlockLen >= 3 then
        begin
          SilSamples := ReadWord;
          SilTC := ReadByte;
          Info.SampleRate := VOCTimeConstToRate(SilTC, Info.Channels);
          AppendSilence(SilSamples + 1);
          Inc(Pos, BlockLen - 3);
        end
        else
          Inc(Pos, BlockLen);
      end;

      BLK_MARKER:
      begin
        Inc(Pos, BlockLen); { skip marker ID }
      end;

      BLK_TEXT:
      begin
        if BlockLen > 0 then
        begin
          Info.HasText := True;
          TextLen := BlockLen;
          if TextLen > 255 then TextLen := 255;
          SetLength(Info.Text, TextLen);
          for I := 1 to TextLen do
          begin
            if Pos < SrcLen then
            begin
              Info.Text[I] := Chr(Src[Pos]);
              Inc(Pos);
            end;
          end;
          { Strip trailing null }
          while (Length(Info.Text) > 0) and (Info.Text[Length(Info.Text)] = #0) do
            SetLength(Info.Text, Length(Info.Text) - 1);
          Inc(Pos, LongInt(BlockLen) - TextLen);
        end;
      end;

      BLK_REPEAT:
      begin
        if BlockLen >= 2 then
        begin
          RepeatCount := ReadWord;
          RepeatPos := Pos + LongInt(BlockLen) - 2;
          if RepeatCount = $FFFF then
            RepeatRemaining := -2  { infinite loop - we'll cap at 1 }
          else
            RepeatRemaining := RepeatCount;
          Inc(Pos, BlockLen - 2);
        end
        else
          Inc(Pos, BlockLen);
      end;

      BLK_REPEAT_END:
      begin
        if RepeatRemaining > 0 then
        begin
          Dec(RepeatRemaining);
          Pos := RepeatPos;
        end
        else if RepeatRemaining = -2 then
        begin
          { Infinite loop - play once then stop }
          RepeatRemaining := -1;
        end
        else
          Inc(Pos, BlockLen);
      end;

      BLK_EXTENDED:
      begin
        if BlockLen >= 4 then
        begin
          ExtSampleRate := ReadWord;
          ExtCodec := ReadByte;
          ExtChannels := ReadByte + 1;
          Info.SampleRate := 256000000 div (ExtChannels * (65536 - LongWord(ExtSampleRate)));
          Info.Channels := ExtChannels;
          UseExtended := True;
          Inc(Pos, BlockLen - 4);
        end
        else
          Inc(Pos, BlockLen);
      end;

      BLK_SOUND_NEW:
      begin
        if BlockLen >= 12 then
        begin
          NewRate := ReadDWord;
          NewBits := ReadByte;
          NewChans := ReadByte;
          Codec := ReadWord; { 16-bit codec ID }
          ReadDWord; { reserved }
          Info.SampleRate := NewRate;
          Info.BitsPerSample := NewBits;
          Info.Channels := NewChans;
          AppendData(@Src[Pos], BlockLen - 12);
          Inc(Pos, BlockLen - 12);
        end
        else
          Inc(Pos, BlockLen);
      end;

    else
      { Unknown block - skip }
      Inc(Pos, BlockLen);
    end;
  end;

  Result := (Info.Data <> nil) and (Info.DataSize > 0);
end;

function VOCLoadFile(const FileName: ShortString; out Info: TVOCInfo): Boolean;
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
  if FileSize < 26 then begin Close(F); Exit; end;

  GetMem(Buf, FileSize);
  BlockRead(F, Buf^, FileSize, BytesRead);
  Close(F);

  if BytesRead <> FileSize then begin FreeMem(Buf); Exit; end;

  Result := VOCLoadMem(Buf, FileSize, Info);
  FreeMem(Buf);
end;

procedure VOCFree(var Info: TVOCInfo);
begin
  if Info.Data <> nil then
  begin
    FreeMem(Info.Data);
    Info.Data := nil;
  end;
  Info.DataSize := 0;
end;

end.
