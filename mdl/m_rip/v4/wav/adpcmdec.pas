(* adpcmdec.pas -- IMA/MS ADPCM Decoder
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Decodes IMA ADPCM and MS ADPCM compressed audio to 16-bit signed PCM.
   These are the two most common ADPCM variants found in WAV files,
   VOC files, and game audio.

   Supports:
     IMA ADPCM (DVI ADPCM) - 4:1 compression, WAV format tag 0x0011
     MS ADPCM - WAV format tag 0x0002
     Mono and stereo
     Any sample rate

   Usage:
     var PCM: PSmallInt; SampleCount: LongInt;
     begin
       SampleCount := IMADecode(ADPCMData, ADPCMSize, 1, PCM);
       // PCM = 16-bit signed samples
       FreeMem(PCM);
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit adpcmdec;

interface

type
  { IMA ADPCM channel state }
  TIMAState = record
    Predictor: SmallInt;
    StepIndex: Integer;
  end;

  { MS ADPCM channel state }
  TMSADPCMState = record
    Coeff1: SmallInt;
    Coeff2: SmallInt;
    Delta: SmallInt;
    Sample1: SmallInt;
    Sample2: SmallInt;
  end;

{ Decode IMA ADPCM buffer to 16-bit signed PCM.
  Channels: 1=mono, 2=stereo.
  BlockAlign: bytes per ADPCM block (from WAV header, typically 256-2048).
  Returns number of output samples per channel, or -1 on error.
  OutPCM allocated via GetMem, caller must FreeMem. }
function IMADecode(Src: PByte; SrcLen: LongInt;
  Channels: Word; BlockAlign: Word;
  out OutPCM: PSmallInt; out OutSamples: LongInt): Boolean;

{ Decode a single IMA ADPCM nibble (4 bits) }
function IMADecodeNibble(var State: TIMAState; Nibble: Byte): SmallInt;

{ Decode MS ADPCM buffer to 16-bit signed PCM.
  Channels: 1=mono, 2=stereo.
  BlockAlign: bytes per ADPCM block (from WAV header).
  NumCoefficients + Coefficients from WAV fmt chunk.
  Returns True on success. }
function MSDecode(Src: PByte; SrcLen: LongInt;
  Channels: Word; BlockAlign: Word;
  SamplesPerBlock: Word;
  NumCoeff: Word; Coeffs: PSmallInt;
  out OutPCM: PSmallInt; out OutSamples: LongInt): Boolean;

{ Decode a single MS ADPCM nibble }
function MSDecodeNibble(var State: TMSADPCMState; Nibble: Byte): SmallInt;

{ Initialize IMA state }
procedure IMAInitState(var State: TIMAState);

{ Utility: clamp SmallInt range }
function ClampS16(V: LongInt): SmallInt;

implementation

const
  { IMA ADPCM step size table (89 entries) }
  IMAStepTable: array[0..88] of SmallInt = (
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
  );

  { IMA ADPCM index adjustment table }
  IMAIndexTable: array[0..15] of ShortInt = (
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8
  );

  { MS ADPCM adaptation table }
  MSAdaptTable: array[0..15] of SmallInt = (
    230, 230, 230, 230, 307, 409, 512, 614,
    768, 614, 512, 409, 307, 230, 230, 230
  );

  { Default MS ADPCM coefficients (7 standard pairs) }
  MSDefaultCoeffs: array[0..13] of SmallInt = (
    256, 0,
    512, -256,
    0, 0,
    192, 64,
    240, 0,
    460, -208,
    392, -232
  );

function ClampS16(V: LongInt): SmallInt;
begin
  if V < -32768 then Result := -32768
  else if V > 32767 then Result := 32767
  else Result := SmallInt(V);
end;

procedure IMAInitState(var State: TIMAState);
begin
  State.Predictor := 0;
  State.StepIndex := 0;
end;

function IMADecodeNibble(var State: TIMAState; Nibble: Byte): SmallInt;
var
  Step: SmallInt;
  Diff: LongInt;
  Sign: Boolean;
begin
  Step := IMAStepTable[State.StepIndex];
  Sign := (Nibble and 8) <> 0;

  Diff := 0;
  if (Nibble and 4) <> 0 then Inc(Diff, Step);
  if (Nibble and 2) <> 0 then Inc(Diff, Step shr 1);
  if (Nibble and 1) <> 0 then Inc(Diff, Step shr 2);
  Inc(Diff, Step shr 3);

  if Sign then
    State.Predictor := ClampS16(LongInt(State.Predictor) - Diff)
  else
    State.Predictor := ClampS16(LongInt(State.Predictor) + Diff);

  State.StepIndex := State.StepIndex + IMAIndexTable[Nibble and $0F];
  if State.StepIndex < 0 then State.StepIndex := 0;
  if State.StepIndex > 88 then State.StepIndex := 88;

  Result := State.Predictor;
end;

function IMADecode(Src: PByte; SrcLen: LongInt;
  Channels: Word; BlockAlign: Word;
  out OutPCM: PSmallInt; out OutSamples: LongInt): Boolean;
var
  SrcPos: LongInt;
  DstPos: LongInt;
  State: array[0..1] of TIMAState;
  BlocksCount: LongInt;
  SamplesPerBlock: LongInt;
  TotalSamples: LongInt;
  DataBytes: LongInt;
  Ch: Integer;
  I: LongInt;
  B: Byte;
  Nibble: Byte;
begin
  Result := False;
  OutPCM := nil;
  OutSamples := 0;

  if (Channels < 1) or (Channels > 2) then Exit;
  if BlockAlign < 4 * Channels then Exit;
  if SrcLen < BlockAlign then Exit;

  { Calculate samples per block }
  DataBytes := BlockAlign - (4 * Channels);
  if Channels = 1 then
    SamplesPerBlock := 1 + DataBytes * 2
  else
    SamplesPerBlock := 1 + (DataBytes div Channels) * 2;

  BlocksCount := SrcLen div BlockAlign;
  TotalSamples := BlocksCount * SamplesPerBlock;

  GetMem(OutPCM, TotalSamples * Channels * SizeOf(SmallInt));
  OutSamples := TotalSamples;

  SrcPos := 0;
  DstPos := 0;

  while SrcPos + BlockAlign <= SrcLen do
  begin
    { Read block header: predictor (2 bytes) + step index (1 byte) + reserved (1 byte) per channel }
    for Ch := 0 to Channels - 1 do
    begin
      State[Ch].Predictor := SmallInt(Src[SrcPos] or (Word(Src[SrcPos + 1]) shl 8));
      State[Ch].StepIndex := Src[SrcPos + 2];
      if State[Ch].StepIndex > 88 then State[Ch].StepIndex := 88;
      Inc(SrcPos, 4);

      { First sample is the predictor value }
      if Channels = 1 then
      begin
        OutPCM[DstPos] := State[Ch].Predictor;
        Inc(DstPos);
      end
      else
      begin
        OutPCM[DstPos + Ch] := State[Ch].Predictor;
      end;
    end;

    if Channels = 2 then
      Inc(DstPos, 2);

    { Decode data nibbles }
    if Channels = 1 then
    begin
      for I := 0 to DataBytes - 1 do
      begin
        if SrcPos >= SrcLen then Break;
        B := Src[SrcPos]; Inc(SrcPos);

        { Low nibble first, then high }
        OutPCM[DstPos] := IMADecodeNibble(State[0], B and $0F);
        Inc(DstPos);
        OutPCM[DstPos] := IMADecodeNibble(State[0], (B shr 4) and $0F);
        Inc(DstPos);
      end;
    end
    else
    begin
      { Stereo: interleaved in 8-sample chunks per channel }
      I := 0;
      while I < DataBytes do
      begin
        { 4 bytes = 8 nibbles for channel 0 }
        for Ch := 0 to Channels - 1 do
        begin
          for B := 0 to 3 do
          begin
            if SrcPos >= SrcLen then Break;
            Nibble := Src[SrcPos]; Inc(SrcPos); Inc(I);
            OutPCM[DstPos] := IMADecodeNibble(State[Ch], Nibble and $0F);
            Inc(DstPos, Channels);
            OutPCM[DstPos] := IMADecodeNibble(State[Ch], (Nibble shr 4) and $0F);
            Inc(DstPos, Channels);
          end;
        end;
      end;
    end;
  end;

  Result := True;
end;

function MSDecodeNibble(var State: TMSADPCMState; Nibble: Byte): SmallInt;
var
  Signed: ShortInt;
  Predictor: LongInt;
begin
  { Convert unsigned nibble to signed (-8..7) }
  if Nibble >= 8 then
    Signed := ShortInt(Nibble) - 16
  else
    Signed := Nibble;

  { Compute predicted sample }
  Predictor := (LongInt(State.Sample1) * LongInt(State.Coeff1) +
                LongInt(State.Sample2) * LongInt(State.Coeff2)) div 256;
  Predictor := Predictor + LongInt(Signed) * LongInt(State.Delta);

  Result := ClampS16(Predictor);

  { Update history }
  State.Sample2 := State.Sample1;
  State.Sample1 := Result;

  { Adapt step size }
  State.Delta := SmallInt((LongInt(MSAdaptTable[Nibble and $0F]) *
                   LongInt(State.Delta)) div 256);
  if State.Delta < 16 then State.Delta := 16;
end;

function MSDecode(Src: PByte; SrcLen: LongInt;
  Channels: Word; BlockAlign: Word;
  SamplesPerBlock: Word;
  NumCoeff: Word; Coeffs: PSmallInt;
  out OutPCM: PSmallInt; out OutSamples: LongInt): Boolean;
var
  SrcPos: LongInt;
  DstPos: LongInt;
  State: array[0..1] of TMSADPCMState;
  BlocksCount: LongInt;
  TotalSamples: LongInt;
  CoeffIdx: Byte;
  Ch: Integer;
  I: LongInt;
  B: Byte;
  UseCoeffs: PSmallInt;
begin
  Result := False;
  OutPCM := nil;
  OutSamples := 0;

  if (Channels < 1) or (Channels > 2) then Exit;
  if BlockAlign < 7 * Channels then Exit;
  if SrcLen < BlockAlign then Exit;

  { Use provided coefficients or defaults }
  if (NumCoeff > 0) and (Coeffs <> nil) then
    UseCoeffs := Coeffs
  else
  begin
    UseCoeffs := @MSDefaultCoeffs[0];
    NumCoeff := 7;
  end;

  BlocksCount := SrcLen div BlockAlign;
  TotalSamples := BlocksCount * LongInt(SamplesPerBlock);

  GetMem(OutPCM, TotalSamples * Channels * SizeOf(SmallInt));
  OutSamples := TotalSamples;

  SrcPos := 0;
  DstPos := 0;

  while SrcPos + BlockAlign <= SrcLen do
  begin
    { Read block preamble }
    for Ch := 0 to Channels - 1 do
    begin
      CoeffIdx := Src[SrcPos]; Inc(SrcPos);
      if CoeffIdx >= NumCoeff then CoeffIdx := 0;
      State[Ch].Coeff1 := PSmallInt(PtrUInt(UseCoeffs) + CoeffIdx * 4)^;
      State[Ch].Coeff2 := PSmallInt(PtrUInt(UseCoeffs) + CoeffIdx * 4 + 2)^;
    end;

    for Ch := 0 to Channels - 1 do
    begin
      State[Ch].Delta := SmallInt(Src[SrcPos] or (Word(Src[SrcPos + 1]) shl 8));
      Inc(SrcPos, 2);
    end;

    for Ch := 0 to Channels - 1 do
    begin
      State[Ch].Sample1 := SmallInt(Src[SrcPos] or (Word(Src[SrcPos + 1]) shl 8));
      Inc(SrcPos, 2);
    end;

    for Ch := 0 to Channels - 1 do
    begin
      State[Ch].Sample2 := SmallInt(Src[SrcPos] or (Word(Src[SrcPos + 1]) shl 8));
      Inc(SrcPos, 2);
    end;

    { Output first two samples (from header, in reverse order) }
    if Channels = 1 then
    begin
      OutPCM[DstPos] := State[0].Sample2; Inc(DstPos);
      OutPCM[DstPos] := State[0].Sample1; Inc(DstPos);
    end
    else
    begin
      OutPCM[DstPos] := State[0].Sample2;
      OutPCM[DstPos + 1] := State[1].Sample2;
      Inc(DstPos, 2);
      OutPCM[DstPos] := State[0].Sample1;
      OutPCM[DstPos + 1] := State[1].Sample1;
      Inc(DstPos, 2);
    end;

    { Decode remaining samples from nibble pairs }
    I := 2; { already output 2 samples }
    while I < SamplesPerBlock do
    begin
      if SrcPos >= SrcLen then Break;
      B := Src[SrcPos]; Inc(SrcPos);

      if Channels = 1 then
      begin
        OutPCM[DstPos] := MSDecodeNibble(State[0], (B shr 4) and $0F);
        Inc(DstPos); Inc(I);
        if I < SamplesPerBlock then
        begin
          OutPCM[DstPos] := MSDecodeNibble(State[0], B and $0F);
          Inc(DstPos); Inc(I);
        end;
      end
      else
      begin
        { Stereo: high nibble = left, low nibble = right }
        OutPCM[DstPos] := MSDecodeNibble(State[0], (B shr 4) and $0F);
        OutPCM[DstPos + 1] := MSDecodeNibble(State[1], B and $0F);
        Inc(DstPos, 2); Inc(I);
      end;
    end;
  end;

  Result := True;
end;

end.
