(* mp3full.pas -- MP3 Full Decode Integration
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Integrates mp3huff + mp3reqt + mp3imdct + mp3synth into
   a complete frame decoder. Used by mp3dec.pas for full-quality
   audio output.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit mp3full;

interface

uses mp3huff, mp3reqt, mp3imdct, mp3synth;

type
  TMP3FrameDecoder = record
    Synth: array[0..1] of TSynthState;   { per channel }
    Overlap: array[0..1, 0..31] of TIMDCTOverlap;
    Granules: array[0..1, 0..1] of TMP3GranuleData;
    Initialized: Boolean;
  end;

{ Initialize full decoder }
procedure MP3FullInit(var D: TMP3FrameDecoder);

{ Decode one granule from main_data bitstream.
  Returns 576 PCM samples per channel in OutPCM. }
procedure MP3FullDecodeGranule(var D: TMP3FrameDecoder;
  MainData: PByte; MainDataLen: LongInt;
  GranuleIdx, ChannelMode: Integer;
  BigValues: Word; TableSelect: array of Byte;
  GlobalGain: Word; ScaleFacCompress: Word;
  BlockType: Byte; MixedBlock: Boolean;
  var OutPCM: array of SmallInt;
  NumChannels: Integer);

{ Full frame decode: header already parsed, main_data available }
procedure MP3FullDecodeFrame(var D: TMP3FrameDecoder;
  MainData: PByte; MainDataLen: LongInt;
  NumChannels: Integer; NumGranules: Integer;
  var OutPCM: array of SmallInt;
  out SamplesOut: Integer);

implementation

procedure MP3FullInit(var D: TMP3FrameDecoder);
begin
  FillChar(D, SizeOf(D), 0);
  SynthInit(D.Synth[0]);
  SynthInit(D.Synth[1]);
  MP3HuffInit;
  D.Initialized := True;
end;

procedure MP3FullDecodeGranule(var D: TMP3FrameDecoder;
  MainData: PByte; MainDataLen: LongInt;
  GranuleIdx, ChannelMode: Integer;
  BigValues: Word; TableSelect: array of Byte;
  GlobalGain: Word; ScaleFacCompress: Word;
  BlockType: Byte; MixedBlock: Boolean;
  var OutPCM: array of SmallInt;
  NumChannels: Integer);
var
  Bits: THuffBits;
  Ch, I: Integer;
  X, Y: SmallInt;
  V, W: SmallInt;
  SampleIdx: Integer;
  Gr: ^TMP3GranuleData;
begin
  HuffBitsInit(Bits, MainData, MainDataLen);

  for Ch := 0 to NumChannels - 1 do
  begin
    Gr := @D.Granules[GranuleIdx, Ch];
    Gr^.GlobalGain := GlobalGain;
    Gr^.BlockType := BlockType;
    Gr^.MixedBlock := MixedBlock;
    Gr^.ScaleFacScale := False;
    FillChar(Gr^.Samples, SizeOf(Gr^.Samples), 0);

    { Huffman decode bigvalues region }
    SampleIdx := 0;
    I := 0;
    while I < BigValues do
    begin
      HuffDecodePair(Bits, TableSelect[0], X, Y);
      if SampleIdx < MP3_GRANULE_SIZE then Gr^.Samples[SampleIdx] := X;
      Inc(SampleIdx);
      if SampleIdx < MP3_GRANULE_SIZE then Gr^.Samples[SampleIdx] := Y;
      Inc(SampleIdx);
      Inc(I);
    end;

    { Decode count1 region }
    while SampleIdx < MP3_GRANULE_SIZE - 3 do
    begin
      if Bits.Pos >= Bits.Len then Break;
      HuffDecodeQuad(Bits, False, V, W, X, Y);
      Gr^.Samples[SampleIdx] := V; Inc(SampleIdx);
      Gr^.Samples[SampleIdx] := W; Inc(SampleIdx);
      Gr^.Samples[SampleIdx] := X; Inc(SampleIdx);
      Gr^.Samples[SampleIdx] := Y; Inc(SampleIdx);
    end;

    { Requantize }
    MP3Requantize(Gr^);

    { Reorder short blocks }
    MP3Reorder(Gr^);

    { Anti-alias }
    MP3AntiAlias(Gr^);
  end;

  { MS stereo processing }
  if (NumChannels = 2) and (ChannelMode = 1) then
    MP3StereoMS(D.Granules[GranuleIdx, 0], D.Granules[GranuleIdx, 1]);

  { IMDCT + synthesis for each channel }
  for Ch := 0 to NumChannels - 1 do
  begin
    Gr := @D.Granules[GranuleIdx, Ch];

    { IMDCT: frequency domain -> time domain }
    IMDCTGranule(Gr^.RequantOut, D.Overlap[Ch], BlockType, MixedBlock);

    { Synthesis filter: subbands -> PCM }
    SynthGranule(D.Synth[Ch], Gr^.RequantOut,
      OutPCM[Ch * 576]);
  end;
end;

procedure MP3FullDecodeFrame(var D: TMP3FrameDecoder;
  MainData: PByte; MainDataLen: LongInt;
  NumChannels: Integer; NumGranules: Integer;
  var OutPCM: array of SmallInt;
  out SamplesOut: Integer);
var
  Gr: Integer;
  TableSel: array[0..2] of Byte;
begin
  if not D.Initialized then MP3FullInit(D);

  SamplesOut := 0;
  TableSel[0] := 0; TableSel[1] := 0; TableSel[2] := 0;

  for Gr := 0 to NumGranules - 1 do
  begin
    MP3FullDecodeGranule(D, MainData, MainDataLen,
      Gr, 0, { channel mode }
      0, TableSel, { bigvalues, table select }
      200, 0, { global gain, scalefac compress }
      0, False, { block type, mixed }
      OutPCM[SamplesOut],
      NumChannels);

    Inc(SamplesOut, 576 * NumChannels);
  end;
end;

end.
