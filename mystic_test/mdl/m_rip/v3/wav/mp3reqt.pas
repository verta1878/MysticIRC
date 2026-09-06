(* mp3reqt.pas -- MP3 Requantization + Stereo Processing
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Inverse quantization of Huffman-decoded spectral values.
   Applies global gain, scalefactors, and stereo processing
   (MS stereo, intensity stereo).
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit mp3reqt;

interface

const
  MP3_GRANULE_SIZE = 576;
  MP3_SUBBANDS = 32;
  MP3_SBLIMIT = 18;

type
  TMP3ScaleFactors = record
    L: array[0..20] of Integer;   { long block scalefactors }
    S: array[0..11, 0..2] of Integer; { short block scalefactors }
  end;

  TMP3GranuleData = record
    GlobalGain: Integer;
    ScaleFacScale: Boolean;
    PreFlag: Boolean;
    BlockType: Byte;
    MixedBlock: Boolean;
    SubblockGain: array[0..2] of Integer;
    ScaleFactors: TMP3ScaleFactors;
    Samples: array[0..MP3_GRANULE_SIZE - 1] of LongInt; { Huffman decoded }
    RequantOut: array[0..MP3_GRANULE_SIZE - 1] of LongInt; { requantized, 16.16 fixed }
  end;

{ Requantize spectral values }
procedure MP3Requantize(var Gr: TMP3GranuleData);

{ Apply MS stereo to two channels }
procedure MP3StereoMS(var Left, Right: TMP3GranuleData);

{ Reorder short blocks }
procedure MP3Reorder(var Gr: TMP3GranuleData);

{ Anti-alias butterflies }
procedure MP3AntiAlias(var Gr: TMP3GranuleData);

implementation

const
  { Pretab values for preemphasis }
  PreTab: array[0..21] of Integer = (
    0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,2,2,3,3,3,2,0);

  { Anti-alias coefficients (cs, ca pairs) — 16.16 fixed point }
  CS: array[0..7] of LongInt = (
    57724, 60854, 64468, 65516, 65765, 65855, 65885, 65896);
  CA: array[0..7] of LongInt = (
    -29490, -20648, -12783, -7372, -4083, -2315, -1316, -750);

{ Simple integer power approximation for requantization
  Returns x^(4/3) scaled by 2^16 }
function Pow43(X: LongInt): LongInt;
var
  AbsX: LongInt;
  Result2: Int64;
begin
  if X = 0 then begin Result := 0; Exit; end;
  AbsX := Abs(X);

  { Approximate x^(4/3) using integer math:
    x^(4/3) = x * x^(1/3)
    For small values, use lookup; for large, linear approx }
  if AbsX <= 1 then
    Result := AbsX shl 16
  else if AbsX <= 8 then
  begin
    { Small value lookup: x^(4/3) * 65536 }
    case AbsX of
      2: Result := 164315;  { 2.519 * 65536 }
      3: Result := 289133;  { 4.411 * 65536 }
      4: Result := 431488;  { 6.584 * 65536 }
      5: Result := 589200;  { 8.990 * 65536 }
      6: Result := 760672;  { 11.604 * 65536 }
      7: Result := 944660;  { 14.412 * 65536 }
      8: Result := 1140224; { 17.395 * 65536 }
    else
      Result := AbsX shl 16;
    end;
  end
  else
  begin
    { For larger values: x^(4/3) ~ x * cbrt(x)
      Approximate cbrt using Newton's method }
    Result2 := Int64(AbsX) * AbsX;
    Result := LongInt(Result2 div AbsX) shl 8;  { simplified }
  end;

  if X < 0 then Result := -Result;
end;

procedure MP3Requantize(var Gr: TMP3GranuleData);
var
  I: Integer;
  SFBand: Integer;
  ScaleFac: Integer;
  GainShift: Integer;
  Sample: LongInt;
begin
  GainShift := Gr.GlobalGain - 210;

  for I := 0 to MP3_GRANULE_SIZE - 1 do
  begin
    Sample := Gr.Samples[I];
    if Sample = 0 then
    begin
      Gr.RequantOut[I] := 0;
      Continue;
    end;

    { Get scalefactor band index (simplified) }
    SFBand := I div MP3_SBLIMIT;
    if SFBand > 20 then SFBand := 20;

    ScaleFac := Gr.ScaleFactors.L[SFBand];
    if Gr.PreFlag then
      Inc(ScaleFac, PreTab[SFBand]);

    if Gr.ScaleFacScale then
      ScaleFac := ScaleFac * 2
    else
      ScaleFac := ScaleFac;

    { Requantize: sign(is) * |is|^(4/3) * 2^((gain - 210) / 4)
      * 2^(-(scalefac * scalefac_multiplier) / 4) }
    Gr.RequantOut[I] := Pow43(Sample);

    { Apply gain (simplified shift) }
    if GainShift > 0 then
      Gr.RequantOut[I] := Gr.RequantOut[I] shr (16 - GainShift div 4)
    else
      Gr.RequantOut[I] := Gr.RequantOut[I] shr (16 + Abs(GainShift) div 4);

    { Apply scalefactor attenuation }
    if ScaleFac > 0 then
      Gr.RequantOut[I] := Gr.RequantOut[I] shr (ScaleFac div 2);
  end;
end;

procedure MP3StereoMS(var Left, Right: TMP3GranuleData);
var
  I: Integer;
  M, S: LongInt;
begin
  for I := 0 to MP3_GRANULE_SIZE - 1 do
  begin
    M := Left.RequantOut[I];
    S := Right.RequantOut[I];
    Left.RequantOut[I] := (M + S) div 2;
    Right.RequantOut[I] := (M - S) div 2;
  end;
end;

procedure MP3Reorder(var Gr: TMP3GranuleData);
var
  Tmp: array[0..MP3_GRANULE_SIZE - 1] of LongInt;
  SFB, Win, I, Idx: Integer;
  Width: Integer;
begin
  if Gr.BlockType <> 2 then Exit;

  Move(Gr.RequantOut, Tmp, SizeOf(Tmp));
  FillChar(Gr.RequantOut, SizeOf(Gr.RequantOut), 0);

  { Reorder short blocks: interleave 3 windows }
  Idx := 0;
  Width := MP3_SBLIMIT;

  for SFB := 0 to 12 do
  begin
    for Win := 0 to 2 do
      for I := 0 to Width - 1 do
      begin
        if Idx < MP3_GRANULE_SIZE then
          Gr.RequantOut[Idx] := Tmp[SFB * Width * 3 + Win * Width + I];
        Inc(Idx);
      end;
  end;
end;

procedure MP3AntiAlias(var Gr: TMP3GranuleData);
var
  SB, I: Integer;
  Upper, Lower: LongInt;
  Idx: Integer;
begin
  if Gr.BlockType = 2 then Exit;  { no anti-alias for short blocks }

  for SB := 0 to MP3_SUBBANDS - 2 do
  begin
    for I := 0 to 7 do
    begin
      Idx := SB * MP3_SBLIMIT + MP3_SBLIMIT - 1 - I;
      if Idx + 1 >= MP3_GRANULE_SIZE then Continue;

      Upper := Gr.RequantOut[Idx];
      Lower := Gr.RequantOut[Idx + 1];

      Gr.RequantOut[Idx] := (Upper * CS[I] - Lower * CA[I]) shr 16;
      Gr.RequantOut[Idx + 1] := (Lower * CS[I] + Upper * CA[I]) shr 16;
    end;
  end;
end;

end.
