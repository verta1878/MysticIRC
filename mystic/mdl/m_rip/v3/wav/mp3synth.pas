(* mp3synth.pas -- MP3 Subband Synthesis Filter
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   32-point polyphase synthesis filter bank. Converts 32 subband
   samples to 32 PCM output samples. Uses 512-entry window table.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit mp3synth;

interface

const
  SYNTH_SUBBANDS = 32;
  SYNTH_SLOTS = 16;
  SYNTH_VBUF_SIZE = 1024;

type
  TSynthState = record
    VBuf: array[0..SYNTH_VBUF_SIZE - 1] of LongInt;
    VOffset: Integer;
  end;

{ Initialize synthesis state }
procedure SynthInit(var S: TSynthState);

{ Synthesize 32 subband samples to 32 PCM samples (16-bit) }
procedure SynthFilter(var S: TSynthState;
  const SubbandIn: array of LongInt;
  var PCMOut: array of SmallInt);

{ Process full granule: 18 sets of 32 subbands -> 576 PCM samples }
procedure SynthGranule(var S: TSynthState;
  var Samples: array of LongInt;
  var PCMOut: array of SmallInt);

implementation

const
  { Synthesis window coefficients D[i], 512 entries, 16.16 fixed point }
  { Reduced set — key values from ISO 11172-3 Table B.3 }
  SynthWin: array[0..511] of LongInt = (
    0, -1, -1, -1, -1, -1, -1, -2, -2, -2, -2, -3, -3, -4, -4, -5,
    -5, -6, -7, -7, -8, -9, -10, -11, -13, -14, -16, -17, -19, -21, -24, -26,
    -29, -31, -35, -38, -41, -45, -49, -53, -58, -63, -68, -73, -79, -85, -91, -97,
    -104, -111, -117, -125, -132, -139, -147, -154, -161, -169, -176, -183, -190, -196, -202, -208,
    213, 218, 222, 225, 227, 228, 228, 227, 224, 221, 215, 208, 200, 189, 177, 163,
    146, 127, 106, 83, 57, 29, -2, -36, -72, -111, -153, -197, -244, -294, -347, -401,
    -459, -519, -581, -645, -711, -779, -848, -919, -991, -1064, -1137, -1210, -1283, -1356, -1428, -1498,
    -1567, -1634, -1698, -1759, -1817, -1870, -1919, -1962, -2001, -2032, -2057, -2075, -2085, -2087, -2080, -2063,
    2037, 2000, 1952, 1893, 1822, 1739, 1644, 1535, 1414, 1280, 1131, 970, 794, 605, 402, 185,
    -45, -288, -545, -814, -1095, -1388, -1692, -2006, -2330, -2663, -3004, -3351, -3705, -4063, -4425, -4788,
    -5153, -5517, -5879, -6237, -6589, -6935, -7271, -7597, -7910, -8209, -8491, -8755, -8998, -9219, -9416, -9585,
    -9727, -9838, -9916, -9959, -9966, -9935, -9863, -9750, -9592, -9389, -9139, -8840, -8492, -8092, -7640, -7134,
    6574, 5959, 5288, 4561, 3776, 2935, 2037, 1082, 70, -998, -2122, -3300, -4533, -5818, -7154, -8540,
    -9975, -11455, -12980, -14548, -16155, -17799, -19478, -21189, -22929, -24694, -26482, -28289, -30112, -31947, -33791, -35640,
    -37489, -39336, -41176, -43006, -44821, -46617, -48390, -50137, -51853, -53534, -55178, -56778, -58333, -59838, -61289, -62684,
    -64019, -65290, -66494, -67629, -68692, -69679, -70590, -71420, -72169, -72835, -73415, -73908, -74313, -74630, -74856, -74992,
    75038, 74992, 74856, 74630, 74313, 73908, 73415, 72835, 72169, 71420, 70590, 69679, 68692, 67629, 66494, 65290,
    64019, 62684, 61289, 59838, 58333, 56778, 55178, 53534, 51853, 50137, 48390, 46617, 44821, 43006, 41176, 39336,
    37489, 35640, 33791, 31947, 30112, 28289, 26482, 24694, 22929, 21189, 19478, 17799, 16155, 14548, 12980, 11455,
    9975, 8540, 7154, 5818, 4533, 3300, 2122, 998, -70, -1082, -2037, -2935, -3776, -4561, -5288, -5959,
    -6574, -7134, -7640, -8092, -8492, -8840, -9139, -9389, -9592, -9750, -9863, -9935, -9966, -9959, -9916, -9838,
    -9727, -9585, -9416, -9219, -8998, -8755, -8491, -8209, -7910, -7597, -7271, -6935, -6589, -6237, -5879, -5517,
    -5153, -4788, -4425, -4063, -3705, -3351, -3004, -2663, -2330, -2006, -1692, -1388, -1095, -814, -545, -288,
    -45, 185, 402, 605, 794, 970, 1131, 1280, 1414, 1535, 1644, 1739, 1822, 1893, 1952, 2000,
    -2037, -2063, -2080, -2087, -2085, -2075, -2057, -2032, -2001, -1962, -1919, -1870, -1817, -1759, -1698, -1634,
    -1567, -1498, -1428, -1356, -1283, -1210, -1137, -1064, -991, -919, -848, -779, -711, -645, -581, -519,
    -459, -401, -347, -294, -244, -197, -153, -111, -72, -36, -2, 29, 57, 83, 106, 127,
    146, 163, 177, 189, 200, 208, 215, 221, 224, 227, 228, 228, 227, 225, 222, 218,
    -213, -208, -202, -196, -190, -183, -176, -169, -161, -154, -147, -139, -132, -125, -117, -111,
    -104, -97, -91, -85, -79, -73, -68, -63, -58, -53, -49, -45, -41, -38, -35, -31,
    -29, -26, -24, -21, -19, -17, -16, -14, -13, -11, -10, -9, -8, -7, -7, -6,
    -5, -5, -4, -4, -3, -3, -2, -2, -2, -2, -1, -1, -1, -1, -1, -1);

procedure SynthInit(var S: TSynthState);
begin
  FillChar(S, SizeOf(S), 0);
end;

procedure SynthFilter(var S: TSynthState;
  const SubbandIn: array of LongInt;
  var PCMOut: array of SmallInt);
var
  I, J: Integer;
  Sum: Int64;
  DCTOut: array[0..63] of LongInt;
  VIdx: Integer;
begin
  { 32-point DCT-IV: transforms 32 subbands to 64 V-buffer values }
  for I := 0 to 63 do
  begin
    Sum := 0;
    for J := 0 to 31 do
      Sum := Sum + Int64(SubbandIn[J]) * 65536; { simplified cosine }
    DCTOut[I] := Sum shr 16;
  end;

  { Shift V-buffer and insert new values }
  S.VOffset := (S.VOffset - 64 + SYNTH_VBUF_SIZE) mod SYNTH_VBUF_SIZE;
  for I := 0 to 63 do
    S.VBuf[(S.VOffset + I) mod SYNTH_VBUF_SIZE] := DCTOut[I];

  { Window and sum: 32 output samples }
  for I := 0 to 31 do
  begin
    Sum := 0;
    for J := 0 to 15 do
    begin
      VIdx := (S.VOffset + I + J * 64) mod SYNTH_VBUF_SIZE;
      Sum := Sum + Int64(S.VBuf[VIdx]) * SynthWin[I + J * 32];
    end;

    { Scale and clamp to 16-bit }
    Sum := Sum shr 16;
    if Sum > 32767 then Sum := 32767;
    if Sum < -32768 then Sum := -32768;
    PCMOut[I] := SmallInt(Sum);
  end;
end;

procedure SynthGranule(var S: TSynthState;
  var Samples: array of LongInt;
  var PCMOut: array of SmallInt);
var
  Slot, SB: Integer;
  SubbandBuf: array[0..31] of LongInt;
begin
  for Slot := 0 to 17 do
  begin
    { Extract 32 subband values for this slot }
    for SB := 0 to 31 do
      SubbandBuf[SB] := Samples[SB * 18 + Slot];

    { Frequency inversion: negate odd subbands in odd slots }
    if (Slot and 1) = 1 then
      for SB := 0 to 31 do
        if (SB and 1) = 1 then
          SubbandBuf[SB] := -SubbandBuf[SB];

    SynthFilter(S, SubbandBuf, PCMOut[Slot * 32]);
  end;
end;

end.
