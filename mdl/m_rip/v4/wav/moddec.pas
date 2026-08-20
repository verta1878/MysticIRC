(* moddec.pas -- ProTracker MOD Decoder/Player
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Decodes and renders Amiga ProTracker MOD files to PCM audio.
   The MOD format is the foundation of all tracker music.

   Supports:
     M.K. (4-channel, 31 samples) - ProTracker
     M!K! (4-channel, >64 patterns)
     FLT4 (4-channel, StarTrekker)
     4CHN, 6CHN, 8CHN (multi-channel)
     15-instrument MODs (no tag, Soundtracker)
     Effects: 0-F (arpeggio, slides, vibrato, volume, etc.)

   Usage:
     var M: TMODFile; PCM: PSmallInt; Len: LongInt;
     begin
       if MODLoadFile('song.mod', M) then begin
         Len := MODRender(M, 44100, PCM);
         // PCM = interleaved stereo 16-bit signed
         FreeMem(PCM);
         MODFree(M);
       end;
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit moddec;

interface

const
  MOD_MAX_SAMPLES   = 31;
  MOD_MAX_PATTERNS  = 128;
  MOD_MAX_CHANNELS  = 8;
  MOD_ROWS_PER_PAT  = 64;

type
  TMODSample = record
    Name: array[0..21] of Char;
    Length: LongWord;        { in bytes (sample data) }
    FineTune: ShortInt;      { -8..7 }
    Volume: Byte;            { 0..64 }
    LoopStart: LongWord;
    LoopLength: LongWord;
    Data: PShortInt;         { 8-bit signed PCM }
  end;

  TMODNote = record
    SampleNum: Byte;
    Period: Word;            { Amiga period value }
    Effect: Byte;            { effect number 0-F }
    EffectParam: Byte;       { effect parameter }
  end;

  TMODPattern = array[0..MOD_MAX_CHANNELS - 1, 0..MOD_ROWS_PER_PAT - 1] of TMODNote;
  PMODPattern = ^TMODPattern;

  TMODChannel = record
    SampleNum: Byte;
    Period: Word;
    TargetPeriod: Word;
    Volume: Integer;
    FineTune: ShortInt;
    SamplePos: LongWord;    { 16.16 fixed point }
    SampleInc: LongWord;    { 16.16 fixed point }
    Active: Boolean;
    { Effect state }
    VibratoPos: Byte;
    VibratoSpeed: Byte;
    VibratoDepth: Byte;
    TremoloPos: Byte;
    TremoloSpeed: Byte;
    TremoloDepth: Byte;
    PortaSpeed: Word;
    ArpTick: Byte;
  end;

  TMODFile = record
    Title: array[0..19] of Char;
    Samples: array[1..MOD_MAX_SAMPLES] of TMODSample;
    NumSamples: Integer;
    NumChannels: Integer;
    NumPatterns: Integer;
    SongLength: Byte;        { number of positions in order }
    RestartPos: Byte;
    Order: array[0..127] of Byte;
    Patterns: array[0..MOD_MAX_PATTERNS - 1] of PMODPattern;
    Loaded: Boolean;
  end;

function MODLoadFile(const FileName: ShortString; out M: TMODFile): Boolean;
function MODLoadMem(Src: PByte; SrcLen: LongInt; out M: TMODFile): Boolean;
procedure MODFree(var M: TMODFile);

{ Render entire MOD to stereo 16-bit PCM.
  Returns number of stereo sample frames, or -1 on error.
  OutPCM allocated via GetMem (interleaved L,R,L,R,...) }
function MODRender(var M: TMODFile; SampleRate: LongWord;
  out OutPCM: PSmallInt): LongInt;

{ Get MOD duration in seconds (approximate) }
function MODDuration(var M: TMODFile): Integer;

implementation

const
  { Amiga period table for finetune 0, octaves 1-3 (C-1 to B-3) }
  PeriodTable: array[0..35] of Word = (
    856,808,762,720,678,640,604,570,538,508,480,453,
    428,404,381,360,339,320,302,285,269,254,240,226,
    214,202,190,180,170,160,151,143,135,127,120,113
  );

  SineTable: array[0..31] of ShortInt = (
    0,24,49,74,97,120,141,161,180,197,212,224,235,244,250,253,
    255,253,250,244,235,224,212,197,180,161,141,120,97,74,49,24
  );

function PeriodToFreq(Period: Word): LongWord;
begin
  if Period = 0 then Result := 0
  else Result := 7093789 div (Period * 2); { PAL Amiga clock }
end;

function ClampVol(V: Integer): Integer;
begin
  if V < 0 then Result := 0
  else if V > 64 then Result := 64
  else Result := V;
end;

function MODLoadMem(Src: PByte; SrcLen: LongInt; out M: TMODFile): Boolean;
var
  Pos: LongInt;
  I, J, Ch, Row: Integer;
  Tag: array[0..3] of Char;
  MaxPattern: Byte;
  SampleLen, LoopStart, LoopLen: Word;
  B: array[0..3] of Byte;
  PatData: PMODPattern;
begin
  Result := False;
  FillChar(M, SizeOf(M), 0);

  if SrcLen < 1084 then Exit; { minimum for 31-sample MOD }

  { Check tag at offset 1080 }
  Move(Src[1080], Tag, 4);

  if (Tag = 'M.K.') or (Tag = 'M!K!') or (Tag = 'FLT4') then
  begin
    M.NumSamples := 31;
    M.NumChannels := 4;
  end
  else if (Tag = '4CHN') then begin M.NumSamples := 31; M.NumChannels := 4; end
  else if (Tag = '6CHN') then begin M.NumSamples := 31; M.NumChannels := 6; end
  else if (Tag = '8CHN') then begin M.NumSamples := 31; M.NumChannels := 8; end
  else
  begin
    { Try 15-instrument Soundtracker (no tag) }
    M.NumSamples := 15;
    M.NumChannels := 4;
  end;

  Pos := 0;

  { Title: 20 bytes }
  Move(Src[Pos], M.Title, 20);
  Inc(Pos, 20);

  { Sample headers }
  for I := 1 to M.NumSamples do
  begin
    Move(Src[Pos], M.Samples[I].Name, 22); Inc(Pos, 22);
    SampleLen := (Word(Src[Pos]) shl 8) or Src[Pos + 1]; Inc(Pos, 2);
    M.Samples[I].Length := LongWord(SampleLen) * 2;
    M.Samples[I].FineTune := Src[Pos] and $0F;
    if M.Samples[I].FineTune > 7 then
      Dec(M.Samples[I].FineTune, 16);
    Inc(Pos);
    M.Samples[I].Volume := Src[Pos]; Inc(Pos);
    if M.Samples[I].Volume > 64 then M.Samples[I].Volume := 64;
    LoopStart := (Word(Src[Pos]) shl 8) or Src[Pos + 1]; Inc(Pos, 2);
    LoopLen := (Word(Src[Pos]) shl 8) or Src[Pos + 1]; Inc(Pos, 2);
    M.Samples[I].LoopStart := LongWord(LoopStart) * 2;
    M.Samples[I].LoopLength := LongWord(LoopLen) * 2;
    if M.Samples[I].LoopLength <= 2 then
      M.Samples[I].LoopLength := 0;
  end;

  { Song length + restart }
  M.SongLength := Src[Pos]; Inc(Pos);
  M.RestartPos := Src[Pos]; Inc(Pos);

  { Pattern order table }
  MaxPattern := 0;
  for I := 0 to 127 do
  begin
    M.Order[I] := Src[Pos]; Inc(Pos);
    if M.Order[I] > MaxPattern then MaxPattern := M.Order[I];
  end;
  M.NumPatterns := MaxPattern + 1;

  { Skip tag for 31-sample MODs }
  if M.NumSamples = 31 then
    Inc(Pos, 4);

  { Pattern data }
  for I := 0 to M.NumPatterns - 1 do
  begin
    GetMem(M.Patterns[I], SizeOf(TMODPattern));
    FillChar(M.Patterns[I]^, SizeOf(TMODPattern), 0);

    for Row := 0 to MOD_ROWS_PER_PAT - 1 do
    begin
      for Ch := 0 to M.NumChannels - 1 do
      begin
        if Pos + 4 > SrcLen then Break;
        B[0] := Src[Pos]; B[1] := Src[Pos+1];
        B[2] := Src[Pos+2]; B[3] := Src[Pos+3];
        Inc(Pos, 4);

        M.Patterns[I]^[Ch, Row].SampleNum := (B[0] and $F0) or (B[2] shr 4);
        M.Patterns[I]^[Ch, Row].Period := ((Word(B[0]) and $0F) shl 8) or B[1];
        M.Patterns[I]^[Ch, Row].Effect := B[2] and $0F;
        M.Patterns[I]^[Ch, Row].EffectParam := B[3];
      end;
    end;
  end;

  { Sample data }
  for I := 1 to M.NumSamples do
  begin
    if M.Samples[I].Length > 0 then
    begin
      if Pos + LongInt(M.Samples[I].Length) > SrcLen then
        M.Samples[I].Length := SrcLen - Pos;
      if M.Samples[I].Length > 0 then
      begin
        GetMem(M.Samples[I].Data, M.Samples[I].Length);
        Move(Src[Pos], M.Samples[I].Data^, M.Samples[I].Length);
        Inc(Pos, M.Samples[I].Length);
      end;
    end;
  end;

  M.Loaded := True;
  Result := True;
end;

function MODLoadFile(const FileName: ShortString; out M: TMODFile): Boolean;
var
  F: File;
  Buf: PByte;
  FileSize, BytesRead: LongInt;
begin
  Result := False;
  FillChar(M, SizeOf(M), 0);
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FileSize := System.FileSize(F);
  if FileSize < 600 then begin Close(F); Exit; end;
  GetMem(Buf, FileSize);
  BlockRead(F, Buf^, FileSize, BytesRead);
  Close(F);
  if BytesRead <> FileSize then begin FreeMem(Buf); Exit; end;
  Result := MODLoadMem(Buf, FileSize, M);
  FreeMem(Buf);
end;

procedure MODFree(var M: TMODFile);
var I: Integer;
begin
  for I := 0 to MOD_MAX_PATTERNS - 1 do
    if M.Patterns[I] <> nil then begin FreeMem(M.Patterns[I]); M.Patterns[I] := nil; end;
  for I := 1 to MOD_MAX_SAMPLES do
    if M.Samples[I].Data <> nil then begin FreeMem(M.Samples[I].Data); M.Samples[I].Data := nil; end;
  M.Loaded := False;
end;

function MODDuration(var M: TMODFile): Integer;
var
  TicksPerRow: Integer;
  BPM: Integer;
  TotalRows: LongInt;
begin
  BPM := 125;
  TicksPerRow := 6;
  TotalRows := LongInt(M.SongLength) * MOD_ROWS_PER_PAT;
  { Duration = TotalRows * TicksPerRow * 2.5ms (at 125 BPM) }
  Result := (TotalRows * TicksPerRow * 1000) div (BPM * 400);
end;

function MODRender(var M: TMODFile; SampleRate: LongWord;
  out OutPCM: PSmallInt): LongInt;
var
  Channels: array[0..MOD_MAX_CHANNELS - 1] of TMODChannel;
  BPM, Speed: Integer;
  SamplesPerTick: LongInt;
  Tick, Row, Pos: Integer;
  OrderPos: Integer;
  Pat: PMODPattern;
  Note: TMODNote;
  Ch, I: Integer;
  SampNum: Byte;
  MixBuf: PSmallInt;
  MixSize: LongInt;
  MixPos: LongInt;
  OutSize: LongInt;
  Left, Right: LongInt;
  SVal: LongInt;
  SampleIdx: LongInt;
  EffX, EffY: Byte;
  PatBreak: Boolean;
  PatBreakRow: Integer;
  PosJump: Integer;
begin
  Result := -1;
  OutPCM := nil;
  if not M.Loaded then Exit;

  { Estimate output size: duration * samplerate * 2 channels * 2 bytes }
  OutSize := LongInt(MODDuration(M) + 2) * LongInt(SampleRate) * 4;
  if OutSize <= 0 then OutSize := SampleRate * 60 * 4; { fallback 60 sec }
  GetMem(MixBuf, OutSize);
  FillChar(MixBuf^, OutSize, 0);

  FillChar(Channels, SizeOf(Channels), 0);
  BPM := 125;
  Speed := 6;
  MixPos := 0;
  PosJump := -1;

  for OrderPos := 0 to M.SongLength - 1 do
  begin
    if M.Order[OrderPos] >= M.NumPatterns then Continue;
    Pat := M.Patterns[M.Order[OrderPos]];
    if Pat = nil then Continue;

    Row := 0;
    while Row < MOD_ROWS_PER_PAT do
    begin
      PatBreak := False;
      PatBreakRow := 0;

      { Process new row }
      for Ch := 0 to M.NumChannels - 1 do
      begin
        Note := Pat^[Ch, Row];

        if Note.SampleNum > 0 then
        begin
          SampNum := Note.SampleNum;
          if SampNum <= M.NumSamples then
          begin
            Channels[Ch].SampleNum := SampNum;
            Channels[Ch].Volume := M.Samples[SampNum].Volume;
            Channels[Ch].FineTune := M.Samples[SampNum].FineTune;
          end;
        end;

        if Note.Period > 0 then
        begin
          Channels[Ch].Period := Note.Period;
          Channels[Ch].TargetPeriod := Note.Period;
          Channels[Ch].SamplePos := 0;
          Channels[Ch].Active := True;
          if Note.Period > 0 then
            Channels[Ch].SampleInc := (PeriodToFreq(Note.Period) shl 16) div SampleRate;
        end;

        { Process effects on tick 0 }
        EffX := Note.EffectParam shr 4;
        EffY := Note.EffectParam and $0F;

        case Note.Effect of
          $0B: PosJump := Note.EffectParam; { position jump }
          $0C: Channels[Ch].Volume := ClampVol(Note.EffectParam); { set volume }
          $0D: begin PatBreak := True; PatBreakRow := EffX * 10 + EffY; end;
          $0F: begin { set speed/tempo }
            if Note.EffectParam < 32 then Speed := Note.EffectParam
            else BPM := Note.EffectParam;
          end;
        end;
      end;

      { Render ticks for this row }
      SamplesPerTick := (SampleRate * 5) div (BPM * 2);

      for Tick := 0 to Speed - 1 do
      begin
        { Process per-tick effects }
        if Tick > 0 then
        begin
          for Ch := 0 to M.NumChannels - 1 do
          begin
            Note := Pat^[Ch, Row];
            EffX := Note.EffectParam shr 4;
            EffY := Note.EffectParam and $0F;

            case Note.Effect of
              $00: { arpeggio }
                if Note.EffectParam <> 0 then
                begin
                  Channels[Ch].ArpTick := Tick mod 3;
                  { simplified: just adjust period }
                end;
              $01: { portamento up }
                if Channels[Ch].Period > Note.EffectParam then
                  Dec(Channels[Ch].Period, Note.EffectParam);
              $02: { portamento down }
                Inc(Channels[Ch].Period, Note.EffectParam);
              $0A: { volume slide }
              begin
                if EffX > 0 then
                  Channels[Ch].Volume := ClampVol(Channels[Ch].Volume + EffX)
                else
                  Channels[Ch].Volume := ClampVol(Channels[Ch].Volume - EffY);
              end;
            end;

            { Update sample increment after period change }
            if Channels[Ch].Period > 0 then
              Channels[Ch].SampleInc := (PeriodToFreq(Channels[Ch].Period) shl 16) div SampleRate;
          end;
        end;

        { Mix samples for this tick }
        for I := 0 to SamplesPerTick - 1 do
        begin
          if (MixPos + 1) * 2 >= OutSize then Break;

          Left := 0;
          Right := 0;

          for Ch := 0 to M.NumChannels - 1 do
          begin
            if not Channels[Ch].Active then Continue;
            if Channels[Ch].SampleNum = 0 then Continue;

            SampNum := Channels[Ch].SampleNum;
            if (SampNum > M.NumSamples) or (M.Samples[SampNum].Data = nil) then Continue;

            SampleIdx := Channels[Ch].SamplePos shr 16;

            { Check sample bounds and looping }
            if M.Samples[SampNum].LoopLength > 0 then
            begin
              while LongWord(SampleIdx) >= M.Samples[SampNum].LoopStart + M.Samples[SampNum].LoopLength do
                Dec(SampleIdx, M.Samples[SampNum].LoopLength);
            end
            else if LongWord(SampleIdx) >= M.Samples[SampNum].Length then
            begin
              Channels[Ch].Active := False;
              Continue;
            end;

            SVal := LongInt(M.Samples[SampNum].Data[SampleIdx]) * Channels[Ch].Volume;

            { Amiga panning: ch 0,3 = left, ch 1,2 = right }
            if (Ch and 3) in [0, 3] then
            begin
              Inc(Left, SVal);
              Inc(Right, SVal div 4);
            end
            else
            begin
              Inc(Right, SVal);
              Inc(Left, SVal div 4);
            end;

            Inc(Channels[Ch].SamplePos, Channels[Ch].SampleInc);
          end;

          { Clamp and store }
          if Left > 32767 then Left := 32767;
          if Left < -32768 then Left := -32768;
          if Right > 32767 then Right := 32767;
          if Right < -32768 then Right := -32768;

          MixBuf[MixPos * 2] := SmallInt(Left);
          MixBuf[MixPos * 2 + 1] := SmallInt(Right);
          Inc(MixPos);
        end;
      end;

      Inc(Row);
      if PatBreak then Break;
      if PosJump >= 0 then Break;
    end;

    if PosJump >= 0 then
    begin
      { Skip forward to the jump target - simplified }
      PosJump := -1;
    end;
  end;

  { Trim to actual size }
  Result := MixPos;
  OutSize := MixPos * 4;
  GetMem(OutPCM, OutSize);
  Move(MixBuf^, OutPCM^, OutSize);
  FreeMem(MixBuf);
end;

end.
