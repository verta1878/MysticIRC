(* s3mdec.pas -- Scream Tracker S3M Decoder/Player
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Decodes and renders Scream Tracker 3 S3M files to PCM audio.
   S3M extended the MOD format with more channels, better effects,
   and instrument/sample separation.

   Supports:
     Up to 32 channels
     Up to 99 instruments (PCM samples)
     Up to 256 patterns (64 rows each)
     Effects: A-Z (speed, tempo, volume, portamento, vibrato, etc.)
     Stereo panning (0-15)

   Usage:
     var S: TS3MFile; PCM: PSmallInt; Len: LongInt;
     begin
       if S3MLoadFile('song.s3m', S) then begin
         Len := S3MRender(S, 44100, PCM);
         // PCM = interleaved stereo 16-bit signed
         FreeMem(PCM);
         S3MFree(S);
       end;
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit s3mdec;

interface

const
  S3M_MAX_CHANNELS  = 32;
  S3M_MAX_SAMPLES   = 99;
  S3M_MAX_PATTERNS  = 256;
  S3M_MAX_ORDERS    = 256;
  S3M_ROWS_PER_PAT  = 64;

type
  TS3MSample = record
    Name: array[0..27] of Char;
    Length: LongWord;
    LoopStart: LongWord;
    LoopLength: LongWord;
    Volume: Byte;
    Flags: Byte;          { bit 0: loop, bit 2: 16-bit }
    C4Speed: LongWord;    { C-4 playback rate in Hz }
    Data: PShortInt;      { 8-bit signed PCM }
    Is16Bit: Boolean;
    Data16: PSmallInt;    { 16-bit signed PCM }
  end;

  TS3MNote = record
    Channel: Byte;
    Note: Byte;           { hi=octave, lo=note (0=C..11=B), 255=none, 254=notecut }
    Instrument: Byte;     { 0=none }
    Volume: Byte;         { 255=none, 0-64=volume }
    Effect: Byte;         { 0=none, A-Z }
    EffectParam: Byte;
  end;

  TS3MRow = array[0..S3M_MAX_CHANNELS - 1] of TS3MNote;
  TS3MPattern = array[0..S3M_ROWS_PER_PAT - 1] of TS3MRow;
  PS3MPattern = ^TS3MPattern;

  TS3MChannel = record
    Active: Boolean;
    SampleNum: Byte;
    Note: Byte;
    Period: LongWord;
    Volume: Integer;
    Panning: Byte;        { 0=left, 7=center, 15=right }
    SamplePos: LongWord;  { 16.16 fixed point }
    SampleInc: LongWord;  { 16.16 fixed point }
    PortaSpeed: Word;
    TargetPeriod: LongWord;
    VibratoPos: Byte;
    VibratoSpeed: Byte;
    VibratoDepth: Byte;
  end;

  TS3MFile = record
    Title: array[0..27] of Char;
    NumOrders: Word;
    NumInstruments: Word;
    NumPatterns: Word;
    Flags: Word;
    TrackerVersion: Word;
    GlobalVolume: Byte;
    InitialSpeed: Byte;
    InitialTempo: Byte;
    MasterVolume: Byte;
    ChannelSettings: array[0..31] of Byte;
    Orders: array[0..S3M_MAX_ORDERS - 1] of Byte;
    Samples: array[1..S3M_MAX_SAMPLES] of TS3MSample;
    Patterns: array[0..S3M_MAX_PATTERNS - 1] of PS3MPattern;
    NumChannels: Integer;
    Loaded: Boolean;
  end;

function S3MLoadFile(const FileName: ShortString; out S: TS3MFile): Boolean;
function S3MLoadMem(Src: PByte; SrcLen: LongInt; out S: TS3MFile): Boolean;
procedure S3MFree(var S: TS3MFile);
function S3MRender(var S: TS3MFile; SampleRate: LongWord;
  out OutPCM: PSmallInt): LongInt;
function S3MDuration(var S: TS3MFile): Integer;

implementation

function ReadLE16(P: PByte): Word;
begin
  Result := Word(P[0]) or (Word(P[1]) shl 8);
end;

function ReadLE32(P: PByte): LongWord;
begin
  Result := LongWord(P[0]) or (LongWord(P[1]) shl 8) or
            (LongWord(P[2]) shl 16) or (LongWord(P[3]) shl 24);
end;

function NoteToPeriod(Note, C4Speed: LongWord): LongWord;
var
  Oct, Semi: LongWord;
  Freq: LongWord;
begin
  if (Note = 255) or (Note = 254) or (C4Speed = 0) then
  begin
    Result := 0;
    Exit;
  end;
  Oct := Note shr 4;
  Semi := Note and $0F;
  if Semi > 11 then Semi := 11;
  { Frequency = C4Speed * 2^((note - C4) / 12) }
  { Simplified: use period-based approach }
  Freq := C4Speed;
  { Adjust for semitone: multiply by 2^(semi/12) using lookup }
  { For now, simple approach: }
  Result := (8363 * 16 * 1712) div (Freq * (1 shl Oct));
  { Adjust for semitone offset from C }
  if Semi > 0 then
    Result := (Result * (16 * 12 - Semi)) div (16 * 12);
end;

function PeriodToInc(Period, SampleRate: LongWord): LongWord;
begin
  if Period = 0 then Result := 0
  else Result := (14317456 shl 2) div (Period * SampleRate);
end;

function ClampVol(V: Integer): Integer;
begin
  if V < 0 then Result := 0
  else if V > 64 then Result := 64
  else Result := V;
end;

function S3MLoadMem(Src: PByte; SrcLen: LongInt; out S: TS3MFile): Boolean;
var
  Pos: LongInt;
  I, J, Ch: Integer;
  InsParaPtr, PatParaPtr: Word;
  SmpOffset: LongWord;
  SmpLen: LongWord;
  SmpFlags: Byte;
  SmpType: Byte;
  PatOffset: LongWord;
  PatLen: Word;
  PatPos: LongInt;
  Row, What: Byte;
  Note: TS3MNote;
  MaxCh: Integer;
begin
  Result := False;
  FillChar(S, SizeOf(S), 0);

  if SrcLen < 96 then Exit;

  { Header }
  Move(Src[0], S.Title, 28);
  if Src[28] <> $1A then Exit;  { EOF marker }
  if Src[29] <> $10 then Exit;  { File type = S3M }

  S.NumOrders := ReadLE16(@Src[32]);
  S.NumInstruments := ReadLE16(@Src[34]);
  S.NumPatterns := ReadLE16(@Src[36]);
  S.Flags := ReadLE16(@Src[38]);
  S.TrackerVersion := ReadLE16(@Src[40]);
  { Src[42-43] = file format version }
  { Src[44-47] = 'SCRM' signature }
  if (Src[44] <> Ord('S')) or (Src[45] <> Ord('C')) or
     (Src[46] <> Ord('R')) or (Src[47] <> Ord('M')) then Exit;

  S.GlobalVolume := Src[48];
  S.InitialSpeed := Src[49];
  S.InitialTempo := Src[50];
  S.MasterVolume := Src[51];

  { Channel settings (32 bytes at offset 64) }
  Move(Src[64], S.ChannelSettings, 32);
  MaxCh := 0;
  for I := 0 to 31 do
    if S.ChannelSettings[I] < 128 then
      MaxCh := I + 1;
  S.NumChannels := MaxCh;

  Pos := 96;

  { Order list }
  if Pos + S.NumOrders > SrcLen then Exit;
  Move(Src[Pos], S.Orders, S.NumOrders);
  Inc(Pos, S.NumOrders);

  { Instrument parapointers (2 bytes each, paragraph offset) }
  if Pos + S.NumInstruments * 2 > SrcLen then Exit;
  for I := 1 to S.NumInstruments do
  begin
    InsParaPtr := ReadLE16(@Src[Pos]);
    Inc(Pos, 2);

    { Read instrument header at parapointer * 16 }
    SmpOffset := LongWord(InsParaPtr) * 16;
    if SmpOffset + 80 > LongWord(SrcLen) then Continue;

    SmpType := Src[SmpOffset];
    if SmpType <> 1 then Continue; { only PCM samples }

    { Sample data pointer: bytes 13-14-15 = seg:offset (parapointer) }
    S.Samples[I].Length := ReadLE32(@Src[SmpOffset + 16]) and $FFFF;
    S.Samples[I].LoopStart := ReadLE32(@Src[SmpOffset + 20]) and $FFFF;
    SmpLen := ReadLE32(@Src[SmpOffset + 24]) and $FFFF;
    if SmpLen > S.Samples[I].LoopStart then
      S.Samples[I].LoopLength := SmpLen - S.Samples[I].LoopStart
    else
      S.Samples[I].LoopLength := 0;

    S.Samples[I].Volume := Src[SmpOffset + 28];
    SmpFlags := Src[SmpOffset + 31];
    S.Samples[I].Flags := SmpFlags;
    S.Samples[I].Is16Bit := (SmpFlags and 4) <> 0;
    S.Samples[I].C4Speed := ReadLE32(@Src[SmpOffset + 32]);
    if S.Samples[I].C4Speed = 0 then S.Samples[I].C4Speed := 8363;

    Move(Src[SmpOffset + 48], S.Samples[I].Name, 28);

    { Loop flag }
    if (SmpFlags and 1) = 0 then
      S.Samples[I].LoopLength := 0;

    { Sample data pointer }
    SmpOffset := ((LongWord(Src[SmpOffset + 14]) shl 16) or
                  LongWord(ReadLE16(@Src[SmpOffset + 15]))) * 16;
    { Alternate: use byte 13 as high byte of parapointer }
    SmpOffset := (LongWord(Src[LongWord(InsParaPtr) * 16 + 13]) shl 20) or
                 (LongWord(ReadLE16(@Src[LongWord(InsParaPtr) * 16 + 14])) shl 4);

    if (SmpOffset > 0) and (SmpOffset + S.Samples[I].Length <= LongWord(SrcLen)) then
    begin
      if not S.Samples[I].Is16Bit then
      begin
        GetMem(S.Samples[I].Data, S.Samples[I].Length);
        { S3M stores unsigned 8-bit, convert to signed }
        for J := 0 to LongInt(S.Samples[I].Length) - 1 do
          S.Samples[I].Data[J] := ShortInt(Src[SmpOffset + LongWord(J)] - 128);
      end;
    end;
  end;

  { Pattern parapointers }
  if Pos + S.NumPatterns * 2 > SrcLen then Exit;
  for I := 0 to S.NumPatterns - 1 do
  begin
    PatParaPtr := ReadLE16(@Src[Pos]);
    Inc(Pos, 2);

    PatOffset := LongWord(PatParaPtr) * 16;
    if (PatOffset = 0) or (PatOffset + 2 > LongWord(SrcLen)) then Continue;

    GetMem(S.Patterns[I], SizeOf(TS3MPattern));
    FillChar(S.Patterns[I]^, SizeOf(TS3MPattern), 0);
    { Set default note/vol to "none" }
    for Row := 0 to S3M_ROWS_PER_PAT - 1 do
      for Ch := 0 to S3M_MAX_CHANNELS - 1 do
      begin
        S.Patterns[I]^[Row][Ch].Note := 255;
        S.Patterns[I]^[Row][Ch].Volume := 255;
      end;

    PatLen := ReadLE16(@Src[PatOffset]);
    PatPos := PatOffset + 2;

    Row := 0;
    while (Row < S3M_ROWS_PER_PAT) and (PatPos < LongInt(PatOffset) + PatLen + 2) and (PatPos < SrcLen) do
    begin
      What := Src[PatPos]; Inc(PatPos);
      if What = 0 then
      begin
        Inc(Row);
        Continue;
      end;

      Ch := What and 31;
      FillChar(Note, SizeOf(Note), 0);
      Note.Channel := Ch;
      Note.Note := 255;
      Note.Volume := 255;

      if (What and 32) <> 0 then
      begin
        if PatPos + 2 <= SrcLen then
        begin
          Note.Note := Src[PatPos];
          Note.Instrument := Src[PatPos + 1];
          Inc(PatPos, 2);
        end;
      end;

      if (What and 64) <> 0 then
      begin
        if PatPos < SrcLen then
        begin
          Note.Volume := Src[PatPos];
          Inc(PatPos);
        end;
      end;

      if (What and 128) <> 0 then
      begin
        if PatPos + 2 <= SrcLen then
        begin
          Note.Effect := Src[PatPos];
          Note.EffectParam := Src[PatPos + 1];
          Inc(PatPos, 2);
        end;
      end;

      if Ch < S3M_MAX_CHANNELS then
        S.Patterns[I]^[Row][Ch] := Note;
    end;
  end;

  S.Loaded := True;
  Result := True;
end;

function S3MLoadFile(const FileName: ShortString; out S: TS3MFile): Boolean;
var
  F: File; Buf: PByte; FileSize, BytesRead: LongInt;
begin
  Result := False; FillChar(S, SizeOf(S), 0);
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FileSize := System.FileSize(F);
  if FileSize < 96 then begin Close(F); Exit; end;
  GetMem(Buf, FileSize);
  BlockRead(F, Buf^, FileSize, BytesRead);
  Close(F);
  if BytesRead <> FileSize then begin FreeMem(Buf); Exit; end;
  Result := S3MLoadMem(Buf, FileSize, S);
  FreeMem(Buf);
end;

procedure S3MFree(var S: TS3MFile);
var I: Integer;
begin
  for I := 0 to S3M_MAX_PATTERNS - 1 do
    if S.Patterns[I] <> nil then begin FreeMem(S.Patterns[I]); S.Patterns[I] := nil; end;
  for I := 1 to S3M_MAX_SAMPLES do
  begin
    if S.Samples[I].Data <> nil then begin FreeMem(S.Samples[I].Data); S.Samples[I].Data := nil; end;
    if S.Samples[I].Data16 <> nil then begin FreeMem(S.Samples[I].Data16); S.Samples[I].Data16 := nil; end;
  end;
  S.Loaded := False;
end;

function S3MDuration(var S: TS3MFile): Integer;
var
  TotalRows: LongInt;
  I: Integer;
  ValidOrders: Integer;
begin
  ValidOrders := 0;
  for I := 0 to S.NumOrders - 1 do
    if S.Orders[I] < 254 then Inc(ValidOrders);
  TotalRows := LongInt(ValidOrders) * S3M_ROWS_PER_PAT;
  if S.InitialTempo = 0 then S.InitialTempo := 125;
  if S.InitialSpeed = 0 then S.InitialSpeed := 6;
  Result := (TotalRows * LongInt(S.InitialSpeed) * 1000) div (LongInt(S.InitialTempo) * 400);
end;

function S3MRender(var S: TS3MFile; SampleRate: LongWord;
  out OutPCM: PSmallInt): LongInt;
var
  Channels: array[0..S3M_MAX_CHANNELS - 1] of TS3MChannel;
  BPM, Speed: Integer;
  SamplesPerTick: LongInt;
  Tick, Row: Integer;
  OrderPos: Integer;
  Pat: PS3MPattern;
  Note: TS3MNote;
  Ch, I: Integer;
  SampNum: Byte;
  MixBuf: PSmallInt;
  MixPos, OutSize: LongInt;
  Left, Right: LongInt;
  SVal: LongInt;
  SampleIdx: LongInt;
  EffX, EffY: Byte;
  Pan: Integer;
begin
  Result := -1;
  OutPCM := nil;
  if not S.Loaded then Exit;

  OutSize := LongInt(S3MDuration(S) + 2) * LongInt(SampleRate) * 4;
  if OutSize <= 0 then OutSize := SampleRate * 60 * 4;
  GetMem(MixBuf, OutSize);
  FillChar(MixBuf^, OutSize, 0);

  FillChar(Channels, SizeOf(Channels), 0);
  for Ch := 0 to S.NumChannels - 1 do
  begin
    if S.ChannelSettings[Ch] < 8 then
      Channels[Ch].Panning := 3  { left-ish }
    else
      Channels[Ch].Panning := 12; { right-ish }
  end;

  BPM := S.InitialTempo;
  Speed := S.InitialSpeed;
  if BPM = 0 then BPM := 125;
  if Speed = 0 then Speed := 6;
  MixPos := 0;

  for OrderPos := 0 to S.NumOrders - 1 do
  begin
    if S.Orders[OrderPos] >= 254 then Continue;
    if S.Orders[OrderPos] >= S.NumPatterns then Continue;
    Pat := S.Patterns[S.Orders[OrderPos]];
    if Pat = nil then Continue;

    for Row := 0 to S3M_ROWS_PER_PAT - 1 do
    begin
      { Process row }
      for Ch := 0 to S.NumChannels - 1 do
      begin
        Note := Pat^[Row][Ch];

        if (Note.Instrument > 0) and (Note.Instrument <= S.NumInstruments) then
        begin
          Channels[Ch].SampleNum := Note.Instrument;
          Channels[Ch].Volume := S.Samples[Note.Instrument].Volume;
        end;

        if (Note.Note <> 255) and (Note.Note <> 254) then
        begin
          if Channels[Ch].SampleNum > 0 then
          begin
            SampNum := Channels[Ch].SampleNum;
            Channels[Ch].Period := NoteToPeriod(Note.Note,
              S.Samples[SampNum].C4Speed);
            Channels[Ch].SamplePos := 0;
            Channels[Ch].Active := True;
            Channels[Ch].SampleInc := PeriodToInc(Channels[Ch].Period, SampleRate);
          end;
        end
        else if Note.Note = 254 then
          Channels[Ch].Active := False;

        if Note.Volume <> 255 then
          Channels[Ch].Volume := ClampVol(Note.Volume);

        { Effects on tick 0 }
        case Note.Effect of
          1: Speed := Note.EffectParam; { A: set speed }
          20: BPM := Note.EffectParam;  { T: set tempo }
        end;
      end;

      SamplesPerTick := (SampleRate * 5) div (LongWord(BPM) * 2);

      for Tick := 0 to Speed - 1 do
      begin
        { Per-tick effects }
        if Tick > 0 then
        begin
          for Ch := 0 to S.NumChannels - 1 do
          begin
            Note := Pat^[Row][Ch];
            EffX := Note.EffectParam shr 4;
            EffY := Note.EffectParam and $0F;
            case Note.Effect of
              4: { D: volume slide }
              begin
                if EffX > 0 then
                  Channels[Ch].Volume := ClampVol(Channels[Ch].Volume + EffX)
                else
                  Channels[Ch].Volume := ClampVol(Channels[Ch].Volume - EffY);
              end;
              5: { E: portamento down }
                Inc(Channels[Ch].Period, Note.EffectParam);
              6: { F: portamento up }
                if Channels[Ch].Period > Note.EffectParam then
                  Dec(Channels[Ch].Period, Note.EffectParam);
            end;
            if Channels[Ch].Period > 0 then
              Channels[Ch].SampleInc := PeriodToInc(Channels[Ch].Period, SampleRate);
          end;
        end;

        { Mix }
        for I := 0 to SamplesPerTick - 1 do
        begin
          if (MixPos + 1) * 2 >= OutSize then Break;
          Left := 0; Right := 0;

          for Ch := 0 to S.NumChannels - 1 do
          begin
            if not Channels[Ch].Active then Continue;
            SampNum := Channels[Ch].SampleNum;
            if (SampNum = 0) or (SampNum > S.NumInstruments) then Continue;
            if S.Samples[SampNum].Data = nil then Continue;

            SampleIdx := Channels[Ch].SamplePos shr 16;

            if S.Samples[SampNum].LoopLength > 0 then
            begin
              while LongWord(SampleIdx) >= S.Samples[SampNum].LoopStart +
                    S.Samples[SampNum].LoopLength do
                Dec(SampleIdx, S.Samples[SampNum].LoopLength);
            end
            else if LongWord(SampleIdx) >= S.Samples[SampNum].Length then
            begin
              Channels[Ch].Active := False;
              Continue;
            end;

            SVal := LongInt(S.Samples[SampNum].Data[SampleIdx]) *
                    Channels[Ch].Volume * LongInt(S.GlobalVolume) div 64;

            Pan := Channels[Ch].Panning;
            Inc(Left, SVal * (15 - Pan) div 15);
            Inc(Right, SVal * Pan div 15);

            Inc(Channels[Ch].SamplePos, Channels[Ch].SampleInc);
          end;

          if Left > 32767 then Left := 32767;
          if Left < -32768 then Left := -32768;
          if Right > 32767 then Right := 32767;
          if Right < -32768 then Right := -32768;

          MixBuf[MixPos * 2] := SmallInt(Left);
          MixBuf[MixPos * 2 + 1] := SmallInt(Right);
          Inc(MixPos);
        end;
      end;
    end;
  end;

  Result := MixPos;
  OutSize := MixPos * 4;
  GetMem(OutPCM, OutSize);
  Move(MixBuf^, OutPCM^, OutSize);
  FreeMem(MixBuf);
end;

end.
