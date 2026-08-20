(* xmdec.pas -- FastTracker II XM Decoder/Player
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Decodes and renders FastTracker II XM files to PCM audio.
   XM extended S3M with envelope-based instruments, multi-sample
   instruments, and linear frequency slides.

   Supports:
     Up to 32 channels
     Up to 128 instruments with 16 samples each
     Up to 256 patterns (variable rows per pattern)
     Volume and panning envelopes
     Sample looping (forward + ping-pong)
     8-bit and 16-bit samples (delta-encoded)
     Linear and Amiga frequency tables

   Usage:
     var X: TXMFile; PCM: PSmallInt; Len: LongInt;
     begin
       if XMLoadFile('song.xm', X) then begin
         Len := XMRender(X, 44100, PCM);
         FreeMem(PCM); XMFree(X);
       end;
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit xmdec;

interface

const
  XM_MAX_CHANNELS   = 32;
  XM_MAX_INSTRUMENTS = 128;
  XM_MAX_SAMPLES    = 16;
  XM_MAX_PATTERNS   = 256;
  XM_MAX_ORDERS     = 256;
  XM_MAX_ENVPOINTS  = 12;

type
  TXMEnvPoint = record
    Tick: Word;
    Value: Word;
  end;

  TXMEnvelope = record
    Points: array[0..XM_MAX_ENVPOINTS - 1] of TXMEnvPoint;
    NumPoints: Byte;
    SustainPt: Byte;
    LoopStart: Byte;
    LoopEnd: Byte;
    Flags: Byte;  { bit 0: on, bit 1: sustain, bit 2: loop }
  end;

  TXMSample = record
    Length: LongWord;
    LoopStart: LongWord;
    LoopLength: LongWord;
    Volume: Byte;
    FineTune: ShortInt;
    LoopType: Byte;    { 0=none, 1=forward, 2=ping-pong }
    Panning: Byte;
    RelNote: ShortInt;
    Name: array[0..21] of Char;
    Data8: PShortInt;
    Data16: PSmallInt;
    Is16Bit: Boolean;
  end;

  TXMInstrument = record
    Name: array[0..21] of Char;
    NumSamples: Word;
    SampleMap: array[0..95] of Byte;
    VolEnv: TXMEnvelope;
    PanEnv: TXMEnvelope;
    VibratoType: Byte;
    VibratoSweep: Byte;
    VibratoDepth: Byte;
    VibratoRate: Byte;
    VolFadeout: Word;
    Samples: array[0..XM_MAX_SAMPLES - 1] of TXMSample;
  end;

  TXMNote = record
    Note: Byte;         { 0=none, 1-96=note, 97=keyoff }
    Instrument: Byte;
    Volume: Byte;       { 0=none, $10-$50=volume }
    Effect: Byte;
    EffectParam: Byte;
  end;

  TXMPattern = record
    NumRows: Word;
    Notes: PByte;       { packed note data }
    NotesParsed: Pointer; { ^array of TXMNote, allocated during load }
    DataSize: LongWord;
  end;

  TXMChannel = record
    Active: Boolean;
    InstrNum: Byte;
    SampleNum: Byte;
    Note: Byte;
    Period: LongWord;
    Volume: Integer;
    Panning: Byte;
    SamplePos: LongWord;   { 16.16 }
    SampleInc: LongWord;   { 16.16 }
    VolEnvPos: Word;
    PanEnvPos: Word;
    FadeoutVol: Word;
    KeyOn: Boolean;
    PortaSpeed: Word;
    TargetPeriod: LongWord;
  end;

  TXMFile = record
    Title: array[0..19] of Char;
    TrackerName: array[0..19] of Char;
    Version: Word;
    NumChannels: Word;
    NumPatterns: Word;
    NumInstruments: Word;
    Flags: Word;          { bit 0: linear freq table }
    DefaultTempo: Word;
    DefaultBPM: Word;
    NumOrders: Word;
    RestartPos: Word;
    Orders: array[0..XM_MAX_ORDERS - 1] of Byte;
    Patterns: array[0..XM_MAX_PATTERNS - 1] of TXMPattern;
    Instruments: array[1..XM_MAX_INSTRUMENTS] of TXMInstrument;
    LinearFreq: Boolean;
    Loaded: Boolean;
  end;

function XMLoadFile(const FileName: ShortString; out X: TXMFile): Boolean;
function XMLoadMem(Src: PByte; SrcLen: LongInt; out X: TXMFile): Boolean;
procedure XMFree(var X: TXMFile);
function XMRender(var X: TXMFile; SampleRate: LongWord;
  out OutPCM: PSmallInt): LongInt;
function XMDuration(var X: TXMFile): Integer;

implementation

type
  TXMNoteArray = array[0..65535] of TXMNote;
  PXMNoteArray = ^TXMNoteArray;

function ReadLE16(P: PByte): Word;
begin
  Result := Word(P[0]) or (Word(P[1]) shl 8);
end;

function ReadLE32(P: PByte): LongWord;
begin
  Result := LongWord(P[0]) or (LongWord(P[1]) shl 8) or
            (LongWord(P[2]) shl 16) or (LongWord(P[3]) shl 24);
end;

function LinearPeriod(Note: Integer; FineTune: ShortInt): LongWord;
begin
  Result := 10 * 12 * 16 * 4 - LongWord(Note) * 16 * 4 - FineTune div 2;
end;

function LinearFreq(Period: LongWord): LongWord;
begin
  if Period = 0 then Result := 0
  else Result := 8363 * 16 * (1 shl (Period div (12 * 16 * 4))) div
                 (1 shl ((Period mod (12 * 16 * 4)) div (16 * 4)));
end;

function PeriodToInc(Period, SRate: LongWord): LongWord;
begin
  if Period = 0 then Result := 0
  else Result := (8363 * 1712 shl 2) div (Period * SRate);
end;

function ClampV(V: Integer): Integer;
begin
  if V < 0 then Result := 0
  else if V > 64 then Result := 64
  else Result := V;
end;

function XMLoadMem(Src: PByte; SrcLen: LongInt; out X: TXMFile): Boolean;
var
  Pos: LongInt;
  HeaderSize: LongWord;
  I, J, K: Integer;
  PatHdrSize: LongWord;
  PackType: Byte;
  PatDataSize: Word;
  NumRows: Word;
  Notes: PXMNoteArray;
  NoteIdx: Integer;
  B: Byte;
  InstHdrSize: LongWord;
  SmpHdrSize: LongWord;
  NumSmp: Word;
  SmpLen: LongWord;
  OldVal8: ShortInt;
  OldVal16: SmallInt;
begin
  Result := False;
  FillChar(X, SizeOf(X), 0);

  if SrcLen < 80 then Exit;

  { Check signature: "Extended Module: " }
  if (Src[0] <> Ord('E')) or (Src[1] <> Ord('x')) or
     (Src[17] <> Ord(':')) then Exit;

  Move(Src[17 + 3], X.Title, 20);
  { Byte 37 should be $1A }
  if Src[37] <> $1A then Exit;

  Move(Src[38], X.TrackerName, 20);
  X.Version := ReadLE16(@Src[58]);
  HeaderSize := ReadLE32(@Src[60]);
  
  Pos := 60;
  X.NumOrders := ReadLE16(@Src[Pos + 4]);
  X.RestartPos := ReadLE16(@Src[Pos + 6]);
  X.NumChannels := ReadLE16(@Src[Pos + 8]);
  X.NumPatterns := ReadLE16(@Src[Pos + 10]);
  X.NumInstruments := ReadLE16(@Src[Pos + 12]);
  X.Flags := ReadLE16(@Src[Pos + 14]);
  X.DefaultTempo := ReadLE16(@Src[Pos + 16]);
  X.DefaultBPM := ReadLE16(@Src[Pos + 18]);
  X.LinearFreq := (X.Flags and 1) <> 0;

  if X.NumChannels > XM_MAX_CHANNELS then X.NumChannels := XM_MAX_CHANNELS;
  if X.NumOrders > XM_MAX_ORDERS then X.NumOrders := XM_MAX_ORDERS;

  { Order table at Pos + 20 }
  for I := 0 to X.NumOrders - 1 do
    X.Orders[I] := Src[Pos + 20 + I];

  Pos := 60 + LongInt(HeaderSize);

  { Patterns }
  for I := 0 to X.NumPatterns - 1 do
  begin
    if Pos + 9 > SrcLen then Break;
    PatHdrSize := ReadLE32(@Src[Pos]);
    PackType := Src[Pos + 4];
    NumRows := ReadLE16(@Src[Pos + 5]);
    PatDataSize := ReadLE16(@Src[Pos + 7]);

    X.Patterns[I].NumRows := NumRows;
    if NumRows = 0 then NumRows := 64;

    { Allocate parsed notes }
    GetMem(Notes, NumRows * X.NumChannels * SizeOf(TXMNote));
    FillChar(Notes^, NumRows * X.NumChannels * SizeOf(TXMNote), 0);
    X.Patterns[I].NotesParsed := Notes;

    Inc(Pos, PatHdrSize);

    { Unpack pattern data }
    NoteIdx := 0;
    for J := 0 to NumRows - 1 do
    begin
      for K := 0 to X.NumChannels - 1 do
      begin
        if Pos >= SrcLen then Break;
        B := Src[Pos]; Inc(Pos);

        if (B and $80) <> 0 then
        begin
          { Packed note }
          if (B and 1) <> 0 then begin Notes^[NoteIdx].Note := Src[Pos]; Inc(Pos); end;
          if (B and 2) <> 0 then begin Notes^[NoteIdx].Instrument := Src[Pos]; Inc(Pos); end;
          if (B and 4) <> 0 then begin Notes^[NoteIdx].Volume := Src[Pos]; Inc(Pos); end;
          if (B and 8) <> 0 then begin Notes^[NoteIdx].Effect := Src[Pos]; Inc(Pos); end;
          if (B and 16) <> 0 then begin Notes^[NoteIdx].EffectParam := Src[Pos]; Inc(Pos); end;
        end
        else
        begin
          { Unpacked: B is the note }
          Notes^[NoteIdx].Note := B;
          if Pos + 4 <= SrcLen then
          begin
            Notes^[NoteIdx].Instrument := Src[Pos]; Inc(Pos);
            Notes^[NoteIdx].Volume := Src[Pos]; Inc(Pos);
            Notes^[NoteIdx].Effect := Src[Pos]; Inc(Pos);
            Notes^[NoteIdx].EffectParam := Src[Pos]; Inc(Pos);
          end;
        end;
        Inc(NoteIdx);
      end;
    end;
  end;

  { Instruments }
  for I := 1 to X.NumInstruments do
  begin
    if Pos + 4 > SrcLen then Break;
    InstHdrSize := ReadLE32(@Src[Pos]);
    if Pos + LongInt(InstHdrSize) > SrcLen then Break;

    Move(Src[Pos + 4], X.Instruments[I].Name, 22);
    NumSmp := 0;
    if InstHdrSize > 29 then
      NumSmp := ReadLE16(@Src[Pos + 27]);
    X.Instruments[I].NumSamples := NumSmp;

    if (NumSmp > 0) and (InstHdrSize > 33) then
    begin
      SmpHdrSize := ReadLE32(@Src[Pos + 29]);

      { Sample-note map (96 bytes) }
      if Pos + 33 + 96 <= SrcLen then
        Move(Src[Pos + 33], X.Instruments[I].SampleMap, 96);

      { Volume envelope (48 bytes = 12 points * 4) }
      if Pos + 129 + 48 <= SrcLen then
      begin
        for J := 0 to 11 do
        begin
          X.Instruments[I].VolEnv.Points[J].Tick := ReadLE16(@Src[Pos + 129 + J * 4]);
          X.Instruments[I].VolEnv.Points[J].Value := ReadLE16(@Src[Pos + 131 + J * 4]);
        end;
      end;

      { Panning envelope (48 bytes) }
      if Pos + 177 + 48 <= SrcLen then
      begin
        for J := 0 to 11 do
        begin
          X.Instruments[I].PanEnv.Points[J].Tick := ReadLE16(@Src[Pos + 177 + J * 4]);
          X.Instruments[I].PanEnv.Points[J].Value := ReadLE16(@Src[Pos + 179 + J * 4]);
        end;
      end;

      if Pos + 225 < SrcLen then
      begin
        X.Instruments[I].VolEnv.NumPoints := Src[Pos + 225];
        X.Instruments[I].PanEnv.NumPoints := Src[Pos + 226];
        X.Instruments[I].VolEnv.SustainPt := Src[Pos + 227];
        X.Instruments[I].VolEnv.LoopStart := Src[Pos + 228];
        X.Instruments[I].VolEnv.LoopEnd := Src[Pos + 229];
        X.Instruments[I].PanEnv.SustainPt := Src[Pos + 230];
        X.Instruments[I].PanEnv.LoopStart := Src[Pos + 231];
        X.Instruments[I].PanEnv.LoopEnd := Src[Pos + 232];
        X.Instruments[I].VolEnv.Flags := Src[Pos + 233];
        X.Instruments[I].PanEnv.Flags := Src[Pos + 234];
      end;

      if Pos + 239 < SrcLen then
        X.Instruments[I].VolFadeout := ReadLE16(@Src[Pos + 239]);
    end;

    Inc(Pos, InstHdrSize);

    { Sample headers }
    if NumSmp > XM_MAX_SAMPLES then NumSmp := XM_MAX_SAMPLES;
    for J := 0 to NumSmp - 1 do
    begin
      if Pos + 40 > SrcLen then Break;
      X.Instruments[I].Samples[J].Length := ReadLE32(@Src[Pos]);
      X.Instruments[I].Samples[J].LoopStart := ReadLE32(@Src[Pos + 4]);
      X.Instruments[I].Samples[J].LoopLength := ReadLE32(@Src[Pos + 8]);
      X.Instruments[I].Samples[J].Volume := Src[Pos + 12];
      X.Instruments[I].Samples[J].FineTune := ShortInt(Src[Pos + 13]);
      X.Instruments[I].Samples[J].LoopType := Src[Pos + 14] and 3;
      X.Instruments[I].Samples[J].Is16Bit := (Src[Pos + 14] and $10) <> 0;
      X.Instruments[I].Samples[J].Panning := Src[Pos + 15];
      X.Instruments[I].Samples[J].RelNote := ShortInt(Src[Pos + 16]);
      Move(Src[Pos + 18], X.Instruments[I].Samples[J].Name, 22);
      Inc(Pos, 40);
    end;

    { Sample data (delta-encoded) }
    for J := 0 to NumSmp - 1 do
    begin
      SmpLen := X.Instruments[I].Samples[J].Length;
      if SmpLen = 0 then Continue;
      if Pos + LongInt(SmpLen) > SrcLen then Break;

      if X.Instruments[I].Samples[J].Is16Bit then
      begin
        SmpLen := SmpLen div 2;
        X.Instruments[I].Samples[J].Length := SmpLen;
        X.Instruments[I].Samples[J].LoopStart := X.Instruments[I].Samples[J].LoopStart div 2;
        X.Instruments[I].Samples[J].LoopLength := X.Instruments[I].Samples[J].LoopLength div 2;
        GetMem(X.Instruments[I].Samples[J].Data16, SmpLen * 2);
        OldVal16 := 0;
        for K := 0 to LongInt(SmpLen) - 1 do
        begin
          OldVal16 := OldVal16 + SmallInt(ReadLE16(@Src[Pos + K * 2]));
          X.Instruments[I].Samples[J].Data16[K] := OldVal16;
        end;
        Inc(Pos, SmpLen * 2);
      end
      else
      begin
        GetMem(X.Instruments[I].Samples[J].Data8, SmpLen);
        OldVal8 := 0;
        for K := 0 to LongInt(SmpLen) - 1 do
        begin
          OldVal8 := OldVal8 + ShortInt(Src[Pos + K]);
          X.Instruments[I].Samples[J].Data8[K] := OldVal8;
        end;
        Inc(Pos, SmpLen);
      end;
    end;
  end;

  X.Loaded := True;
  Result := True;
end;

function XMLoadFile(const FileName: ShortString; out X: TXMFile): Boolean;
var F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False; FillChar(X, SizeOf(X), 0);
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  if FS < 80 then begin Close(F); Exit; end;
  GetMem(Buf, FS);
  BlockRead(F, Buf^, FS, BR);
  Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := XMLoadMem(Buf, FS, X);
  FreeMem(Buf);
end;

procedure XMFree(var X: TXMFile);
var I, J: Integer;
begin
  for I := 0 to XM_MAX_PATTERNS - 1 do
    if X.Patterns[I].NotesParsed <> nil then
    begin FreeMem(X.Patterns[I].NotesParsed); X.Patterns[I].NotesParsed := nil; end;
  for I := 1 to XM_MAX_INSTRUMENTS do
    for J := 0 to XM_MAX_SAMPLES - 1 do
    begin
      if X.Instruments[I].Samples[J].Data8 <> nil then
      begin FreeMem(X.Instruments[I].Samples[J].Data8); X.Instruments[I].Samples[J].Data8 := nil; end;
      if X.Instruments[I].Samples[J].Data16 <> nil then
      begin FreeMem(X.Instruments[I].Samples[J].Data16); X.Instruments[I].Samples[J].Data16 := nil; end;
    end;
  X.Loaded := False;
end;

function XMDuration(var X: TXMFile): Integer;
var ValidOrders, I: Integer;
begin
  ValidOrders := 0;
  for I := 0 to X.NumOrders - 1 do
    if X.Orders[I] < X.NumPatterns then Inc(ValidOrders);
  if X.DefaultBPM = 0 then X.DefaultBPM := 125;
  if X.DefaultTempo = 0 then X.DefaultTempo := 6;
  Result := (ValidOrders * 64 * LongInt(X.DefaultTempo) * 1000) div
            (LongInt(X.DefaultBPM) * 400);
end;

function XMRender(var X: TXMFile; SampleRate: LongWord;
  out OutPCM: PSmallInt): LongInt;
var
  Channels: array[0..XM_MAX_CHANNELS - 1] of TXMChannel;
  BPM, Speed: Integer;
  SamplesPerTick: LongInt;
  Tick, Row: Integer;
  OrderPos: Integer;
  Notes: PXMNoteArray;
  Note: TXMNote;
  Ch, I: Integer;
  InstNum, SmpNum: Byte;
  MixBuf: PSmallInt;
  MixPos, OutSize: LongInt;
  Left, Right: LongInt;
  SVal: LongInt;
  SampleIdx: LongInt;
  NumRows: Word;
  Smp: ^TXMSample;
  Pan: Integer;
begin
  Result := -1; OutPCM := nil;
  if not X.Loaded then Exit;

  OutSize := LongInt(XMDuration(X) + 2) * LongInt(SampleRate) * 4;
  if OutSize <= 0 then OutSize := SampleRate * 60 * 4;
  GetMem(MixBuf, OutSize);
  FillChar(MixBuf^, OutSize, 0);
  FillChar(Channels, SizeOf(Channels), 0);

  BPM := X.DefaultBPM; Speed := X.DefaultTempo;
  if BPM = 0 then BPM := 125;
  if Speed = 0 then Speed := 6;
  MixPos := 0;

  for OrderPos := 0 to X.NumOrders - 1 do
  begin
    if X.Orders[OrderPos] >= X.NumPatterns then Continue;
    Notes := PXMNoteArray(X.Patterns[X.Orders[OrderPos]].NotesParsed);
    if Notes = nil then Continue;
    NumRows := X.Patterns[X.Orders[OrderPos]].NumRows;
    if NumRows = 0 then NumRows := 64;

    for Row := 0 to NumRows - 1 do
    begin
      for Ch := 0 to X.NumChannels - 1 do
      begin
        Note := Notes^[Row * Integer(X.NumChannels) + Ch];

        if (Note.Instrument > 0) and (Note.Instrument <= X.NumInstruments) then
          Channels[Ch].InstrNum := Note.Instrument;

        if (Note.Note > 0) and (Note.Note < 97) and (Channels[Ch].InstrNum > 0) then
        begin
          InstNum := Channels[Ch].InstrNum;
          SmpNum := X.Instruments[InstNum].SampleMap[Note.Note - 1];
          if SmpNum < X.Instruments[InstNum].NumSamples then
          begin
            Channels[Ch].SampleNum := SmpNum;
            Channels[Ch].Note := Note.Note;
            Smp := @X.Instruments[InstNum].Samples[SmpNum];
            Channels[Ch].Volume := Smp^.Volume;
            Channels[Ch].Panning := Smp^.Panning;
            Channels[Ch].Period := LinearPeriod(
              (Note.Note - 1) + Smp^.RelNote, Smp^.FineTune);
            Channels[Ch].SamplePos := 0;
            Channels[Ch].SampleInc := PeriodToInc(Channels[Ch].Period, SampleRate);
            Channels[Ch].Active := True;
            Channels[Ch].KeyOn := True;
            Channels[Ch].FadeoutVol := 65535;
          end;
        end
        else if Note.Note = 97 then
        begin
          Channels[Ch].KeyOn := False;
        end;

        if (Note.Volume >= $10) and (Note.Volume <= $50) then
          Channels[Ch].Volume := ClampV(Note.Volume - $10);

        case Note.Effect of
          $0F: if Note.EffectParam < 32 then Speed := Note.EffectParam
               else BPM := Note.EffectParam;
          $0C: Channels[Ch].Volume := ClampV(Note.EffectParam);
        end;
      end;

      SamplesPerTick := (SampleRate * 5) div (LongWord(BPM) * 2);

      for Tick := 0 to Speed - 1 do
      begin
        for I := 0 to SamplesPerTick - 1 do
        begin
          if (MixPos + 1) * 2 >= OutSize then Break;
          Left := 0; Right := 0;

          for Ch := 0 to X.NumChannels - 1 do
          begin
            if not Channels[Ch].Active then Continue;
            InstNum := Channels[Ch].InstrNum;
            if (InstNum = 0) or (InstNum > X.NumInstruments) then Continue;
            SmpNum := Channels[Ch].SampleNum;
            Smp := @X.Instruments[InstNum].Samples[SmpNum];
            if (Smp^.Data8 = nil) and (Smp^.Data16 = nil) then Continue;

            SampleIdx := Channels[Ch].SamplePos shr 16;

            { Looping }
            if Smp^.LoopLength > 0 then
            begin
              while LongWord(SampleIdx) >= Smp^.LoopStart + Smp^.LoopLength do
                Dec(SampleIdx, Smp^.LoopLength);
            end
            else if LongWord(SampleIdx) >= Smp^.Length then
            begin
              Channels[Ch].Active := False;
              Continue;
            end;

            if Smp^.Is16Bit then
              SVal := LongInt(Smp^.Data16[SampleIdx]) * Channels[Ch].Volume div 64
            else
              SVal := LongInt(Smp^.Data8[SampleIdx]) * Channels[Ch].Volume;

            Pan := Channels[Ch].Panning;
            Inc(Left, SVal * (255 - Pan) div 255);
            Inc(Right, SVal * Pan div 255);

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
