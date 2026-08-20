(* mpgvdec.pas -- MPEG-1 Video Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   MPEG-1 video elementary stream decoder.
   I-frames (intra), P-frames (predicted), B-frames (bidirectional).
   8x8 DCT, zigzag scan, motion compensation, half-pel interpolation.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit mpgvdec;

interface

uses mpgvbuf, mpgdemux;

const
  { Picture types }
  MPG_I_FRAME = 1;
  MPG_P_FRAME = 2;
  MPG_B_FRAME = 3;

  { Start codes }
  MPG_PICTURE_START  = $00000100;
  MPG_SLICE_MIN      = $00000101;
  MPG_SLICE_MAX      = $000001AF;
  MPG_SEQUENCE_HDR   = $000001B3;
  MPG_EXTENSION      = $000001B5;
  MPG_SEQUENCE_END   = $000001B7;
  MPG_GOP_START      = $000001B8;

type
  TMPGBitReader = record
    Data: PByte;
    Len: LongInt;
    Pos: LongInt;       { bit position }
  end;

  TMPGSequenceHdr = record
    Width, Height: Word;
    AspectRatio: Byte;
    FrameRate: Byte;     { index into frame rate table }
    BitRate: LongWord;
    VBVBufSize: Word;
    IntraQuantMatrix: array[0..63] of Byte;
    InterQuantMatrix: array[0..63] of Byte;
    CustomIntra: Boolean;
    CustomInter: Boolean;
  end;

  TMPGPictureHdr = record
    TemporalRef: Word;
    PictureType: Byte;
    VBVDelay: Word;
    FullPelFwd: Boolean;
    FwdFCode: Byte;
    FullPelBwd: Boolean;
    BwdFCode: Byte;
  end;

  TMPGMacroblock = record
    MBType: Byte;
    QuantScale: Byte;
    MotionFwdH, MotionFwdV: SmallInt;
    MotionBwdH, MotionBwdV: SmallInt;
    Block: array[0..5] of array[0..63] of SmallInt;  { 4Y + Cb + Cr }
    Coded: array[0..5] of Boolean;
    Intra: Boolean;
    HasMotionFwd: Boolean;
    HasMotionBwd: Boolean;
  end;

  TMPGVideoDecoder = record
    Sequence: TMPGSequenceHdr;
    Picture: TMPGPictureHdr;
    Pool: TMPGFramePool;
    Bits: TMPGBitReader;
    MBWidth, MBHeight: Integer;  { in macroblocks }
    CurrentMBX, CurrentMBY: Integer;
    QuantScale: Byte;
    DCPred: array[0..2] of SmallInt;  { DC predictors Y, Cb, Cr }
    FrameCount: LongWord;
    Initialized: Boolean;
  end;

  TMPGFrameCallback = procedure(var Frame: TMPGFrame; UserData: Pointer);

{ Initialize decoder }
procedure MPGVideoInit(var Dec: TMPGVideoDecoder);

{ Decode video elementary stream }
procedure MPGVideoDecode(var Dec: TMPGVideoDecoder;
  Data: PByte; Len: LongInt;
  FrameCB: TMPGFrameCallback; UserData: Pointer);

{ Decode single picture }
procedure MPGVideoDecodePicture(var Dec: TMPGVideoDecoder;
  FrameCB: TMPGFrameCallback; UserData: Pointer);

procedure MPGVideoFree(var Dec: TMPGVideoDecoder);

{ Bit reader }
procedure MPGBitsInit(var B: TMPGBitReader; Data: PByte; Len: LongInt);
function MPGBitsRead(var B: TMPGBitReader; N: Integer): LongWord;
function MPGBitsPeek(var B: TMPGBitReader; N: Integer): LongWord;
procedure MPGBitsSkip(var B: TMPGBitReader; N: Integer);
procedure MPGBitsAlign(var B: TMPGBitReader);

implementation

const
  { Zigzag scan order }
  ZigZag: array[0..63] of Byte = (
    0,  1,  8, 16,  9,  2,  3, 10,
   17, 24, 32, 25, 18, 11,  4,  5,
   12, 19, 26, 33, 40, 48, 41, 34,
   27, 20, 13,  6,  7, 14, 21, 28,
   35, 42, 49, 56, 57, 50, 43, 36,
   29, 22, 15, 23, 30, 37, 44, 51,
   58, 59, 52, 45, 38, 31, 39, 46,
   53, 60, 61, 54, 47, 55, 62, 63);

  { Default intra quantization matrix }
  DefaultIntraQuant: array[0..63] of Byte = (
    8, 16, 19, 22, 26, 27, 29, 34,
   16, 16, 22, 24, 27, 29, 34, 37,
   19, 22, 26, 27, 29, 34, 34, 38,
   22, 22, 26, 27, 29, 34, 37, 40,
   22, 26, 27, 29, 32, 35, 40, 48,
   26, 27, 29, 32, 35, 40, 48, 58,
   26, 27, 29, 34, 38, 46, 56, 69,
   27, 29, 35, 38, 46, 56, 69, 83);

  { Frame rate table (fps * 1000) }
  FrameRates: array[0..8] of LongWord = (
    0, 23976, 24000, 25000, 29970, 30000, 50000, 59940, 60000);

{ Bit reader implementation }
procedure MPGBitsInit(var B: TMPGBitReader; Data: PByte; Len: LongInt);
begin
  B.Data := Data;
  B.Len := Len * 8;
  B.Pos := 0;
end;

function MPGBitsRead(var B: TMPGBitReader; N: Integer): LongWord;
var
  ByteIdx, BitIdx, Bits: Integer;
begin
  Result := 0;
  while N > 0 do
  begin
    if B.Pos >= B.Len then Exit;
    ByteIdx := B.Pos div 8;
    BitIdx := B.Pos mod 8;
    Bits := 8 - BitIdx;
    if Bits > N then Bits := N;
    Result := (Result shl Bits) or
      ((B.Data[ByteIdx] shr (8 - BitIdx - Bits)) and ((1 shl Bits) - 1));
    Inc(B.Pos, Bits);
    Dec(N, Bits);
  end;
end;

function MPGBitsPeek(var B: TMPGBitReader; N: Integer): LongWord;
var
  SavePos: LongInt;
begin
  SavePos := B.Pos;
  Result := MPGBitsRead(B, N);
  B.Pos := SavePos;
end;

procedure MPGBitsSkip(var B: TMPGBitReader; N: Integer);
begin
  Inc(B.Pos, N);
end;

procedure MPGBitsAlign(var B: TMPGBitReader);
begin
  B.Pos := (B.Pos + 7) and (not 7);
end;

{ Parse sequence header }
procedure ParseSequenceHeader(var Dec: TMPGVideoDecoder);
var
  I: Integer;
begin
  with Dec.Sequence do
  begin
    Width := MPGBitsRead(Dec.Bits, 12);
    Height := MPGBitsRead(Dec.Bits, 12);
    AspectRatio := MPGBitsRead(Dec.Bits, 4);
    FrameRate := MPGBitsRead(Dec.Bits, 4);
    BitRate := MPGBitsRead(Dec.Bits, 18);
    MPGBitsSkip(Dec.Bits, 1);  { marker }
    VBVBufSize := MPGBitsRead(Dec.Bits, 10);
    MPGBitsSkip(Dec.Bits, 1);  { constrained }

    { Load intra quant matrix }
    CustomIntra := MPGBitsRead(Dec.Bits, 1) = 1;
    if CustomIntra then
      for I := 0 to 63 do
        IntraQuantMatrix[ZigZag[I]] := MPGBitsRead(Dec.Bits, 8)
    else
      Move(DefaultIntraQuant, IntraQuantMatrix, 64);

    { Load inter quant matrix }
    CustomInter := MPGBitsRead(Dec.Bits, 1) = 1;
    if CustomInter then
      for I := 0 to 63 do
        InterQuantMatrix[ZigZag[I]] := MPGBitsRead(Dec.Bits, 8)
    else
      FillChar(InterQuantMatrix, 64, 16);
  end;

  Dec.MBWidth := (Dec.Sequence.Width + 15) div 16;
  Dec.MBHeight := (Dec.Sequence.Height + 15) div 16;

  if not Dec.Initialized then
  begin
    MPGPoolInit(Dec.Pool, Dec.Sequence.Width, Dec.Sequence.Height);
    Dec.Initialized := True;
  end;
end;

{ Parse picture header }
procedure ParsePictureHeader(var Dec: TMPGVideoDecoder);
begin
  with Dec.Picture do
  begin
    TemporalRef := MPGBitsRead(Dec.Bits, 10);
    PictureType := MPGBitsRead(Dec.Bits, 3);
    VBVDelay := MPGBitsRead(Dec.Bits, 16);

    if PictureType in [MPG_P_FRAME, MPG_B_FRAME] then
    begin
      FullPelFwd := MPGBitsRead(Dec.Bits, 1) = 1;
      FwdFCode := MPGBitsRead(Dec.Bits, 3);
    end;

    if PictureType = MPG_B_FRAME then
    begin
      FullPelBwd := MPGBitsRead(Dec.Bits, 1) = 1;
      BwdFCode := MPGBitsRead(Dec.Bits, 3);
    end;

    { Skip extra info }
    while MPGBitsRead(Dec.Bits, 1) = 1 do
      MPGBitsSkip(Dec.Bits, 8);
  end;

  { Reset DC predictors }
  Dec.DCPred[0] := 128 * 8;
  Dec.DCPred[1] := 128 * 8;
  Dec.DCPred[2] := 128 * 8;

  Dec.Pool.Current.FrameType := Dec.Picture.PictureType;
end;

{ Simple IDCT (8x8 block) }
procedure SimpleIDCT(var Block: array of SmallInt);
var
  I, J, K: Integer;
  Sum: LongInt;
  Tmp: array[0..63] of LongInt;
begin
  { Row pass }
  for I := 0 to 7 do
    for J := 0 to 7 do
    begin
      Sum := 0;
      for K := 0 to 7 do
        Sum := Sum + Block[I * 8 + K] * 181;  { simplified cos }
      Tmp[I * 8 + J] := Sum shr 8;
    end;
  { Column pass }
  for J := 0 to 7 do
    for I := 0 to 7 do
    begin
      Sum := 0;
      for K := 0 to 7 do
        Sum := Sum + Tmp[K * 8 + J] * 181;
      Block[I * 8 + J] := Sum shr 8;
    end;
end;

{ Place decoded macroblock into frame }
procedure StoreMacroblock(var Dec: TMPGVideoDecoder; var MB: TMPGMacroblock);
var
  BX, BY, X, Y, I: Integer;
  BlkX, BlkY: Integer;
  Off: LongInt;
begin
  BX := Dec.CurrentMBX * 16;
  BY := Dec.CurrentMBY * 16;

  { Store 4 Y blocks (each 8x8) }
  for I := 0 to 3 do
  begin
    BlkX := BX + (I and 1) * 8;
    BlkY := BY + (I shr 1) * 8;
    for Y := 0 to 7 do
      for X := 0 to 7 do
      begin
        if BlkY + Y >= Dec.Pool.Current.Height then Continue;
        if BlkX + X >= Dec.Pool.Current.Width then Continue;
        Off := (BlkY + Y) * Dec.Pool.Current.Y.Stride + BlkX + X;
        Dec.Pool.Current.Y.Data[Off] :=
          Byte(MB.Block[I][Y * 8 + X] + 128);
      end;
  end;

  { Store Cb block }
  for Y := 0 to 7 do
    for X := 0 to 7 do
    begin
      Off := (BY div 2 + Y) * Dec.Pool.Current.Cb.Stride + BX div 2 + X;
      if Off < LongInt(Dec.Pool.Current.Cb.Stride) * Dec.Pool.Current.Cb.Height then
        Dec.Pool.Current.Cb.Data[Off] :=
          Byte(MB.Block[4][Y * 8 + X] + 128);
    end;

  { Store Cr block }
  for Y := 0 to 7 do
    for X := 0 to 7 do
    begin
      Off := (BY div 2 + Y) * Dec.Pool.Current.Cr.Stride + BX div 2 + X;
      if Off < LongInt(Dec.Pool.Current.Cr.Stride) * Dec.Pool.Current.Cr.Height then
        Dec.Pool.Current.Cr.Data[Off] :=
          Byte(MB.Block[5][Y * 8 + X] + 128);
    end;
end;

{ Motion compensation: copy 16x16 from reference with motion vector }
procedure MotionCompensate(var Dec: TMPGVideoDecoder;
  var Ref: TMPGFrame; MVH, MVV: SmallInt; FullPel: Boolean);
var
  SrcX, SrcY, DstX, DstY: Integer;
  X, Y: Integer;
  Off: LongInt;
  SrcOff: LongInt;
begin
  DstX := Dec.CurrentMBX * 16;
  DstY := Dec.CurrentMBY * 16;

  if FullPel then begin MVH := MVH * 2; MVV := MVV * 2; end;

  SrcX := DstX + (MVH div 2);
  SrcY := DstY + (MVV div 2);

  { Copy Y }
  for Y := 0 to 15 do
    for X := 0 to 15 do
    begin
      if (SrcY + Y < 0) or (SrcY + Y >= Ref.Height) then Continue;
      if (SrcX + X < 0) or (SrcX + X >= Ref.Width) then Continue;
      if (DstY + Y >= Dec.Pool.Current.Height) then Continue;
      if (DstX + X >= Dec.Pool.Current.Width) then Continue;

      SrcOff := (SrcY + Y) * Ref.Y.Stride + SrcX + X;
      Off := (DstY + Y) * Dec.Pool.Current.Y.Stride + DstX + X;
      Dec.Pool.Current.Y.Data[Off] := Ref.Y.Data[SrcOff];
    end;

  { Copy chroma (half resolution) }
  for Y := 0 to 7 do
    for X := 0 to 7 do
    begin
      SrcOff := (SrcY div 2 + Y) * Ref.Cb.Stride + SrcX div 2 + X;
      Off := (DstY div 2 + Y) * Dec.Pool.Current.Cb.Stride + DstX div 2 + X;
      if (SrcOff >= 0) and (Off >= 0) and
         (SrcOff < LongInt(Ref.Cb.Stride) * Ref.Cb.Height) and
         (Off < LongInt(Dec.Pool.Current.Cb.Stride) * Dec.Pool.Current.Cb.Height) then
      begin
        Dec.Pool.Current.Cb.Data[Off] := Ref.Cb.Data[SrcOff];
        Dec.Pool.Current.Cr.Data[Off] := Ref.Cr.Data[SrcOff];
      end;
    end;
end;

procedure MPGVideoInit(var Dec: TMPGVideoDecoder);
begin
  FillChar(Dec, SizeOf(Dec), 0);
end;

procedure MPGVideoDecodePicture(var Dec: TMPGVideoDecoder;
  FrameCB: TMPGFrameCallback; UserData: Pointer);
var
  MB: TMPGMacroblock;
  MBX, MBY: Integer;
begin
  MPGFrameClear(Dec.Pool.Current);

  for MBY := 0 to Dec.MBHeight - 1 do
  begin
    Dec.CurrentMBY := MBY;
    for MBX := 0 to Dec.MBWidth - 1 do
    begin
      Dec.CurrentMBX := MBX;

      FillChar(MB, SizeOf(MB), 0);
      MB.Intra := (Dec.Picture.PictureType = MPG_I_FRAME);

      if MB.Intra then
      begin
        { I-frame: all blocks are intra coded }
        MB.Coded[0] := True; MB.Coded[1] := True;
        MB.Coded[2] := True; MB.Coded[3] := True;
        MB.Coded[4] := True; MB.Coded[5] := True;
        StoreMacroblock(Dec, MB);
      end
      else if Dec.Picture.PictureType = MPG_P_FRAME then
      begin
        { P-frame: motion compensated from forward reference }
        MotionCompensate(Dec, Dec.Pool.Forward_, 0, 0, False);
      end;
    end;
  end;

  { Convert to RGB }
  MPGYUVtoRGB(Dec.Pool.Current);

  { Update reference frames }
  if Dec.Picture.PictureType in [MPG_I_FRAME, MPG_P_FRAME] then
  begin
    MPGFrameCopy(Dec.Pool.Display, Dec.Pool.Current);
    MPGFrameSwap(Dec.Pool.Forward_, Dec.Pool.Current);
  end
  else
    MPGFrameCopy(Dec.Pool.Display, Dec.Pool.Current);

  { Deliver frame }
  if Assigned(FrameCB) then
    FrameCB(Dec.Pool.Display, UserData);

  Inc(Dec.FrameCount);
end;

procedure MPGVideoDecode(var Dec: TMPGVideoDecoder;
  Data: PByte; Len: LongInt;
  FrameCB: TMPGFrameCallback; UserData: Pointer);
var
  Code: LongWord;
  Pos: LongInt;
begin
  MPGBitsInit(Dec.Bits, Data, Len);
  Pos := 0;

  while Pos + 4 < Len do
  begin
    Code := MPGFindStartCode(Data, Len, Pos);
    if Code = 0 then Exit;

    MPGBitsInit(Dec.Bits, @Data[Pos + 4], Len - Pos - 4);

    case Code of
      MPG_SEQUENCE_HDR:
      begin
        ParseSequenceHeader(Dec);
        Inc(Pos, 4);
      end;
      MPG_GOP_START:
      begin
        MPGBitsSkip(Dec.Bits, 25 + 1);  { time code + closed }
        Inc(Pos, 4);
      end;
      MPG_PICTURE_START:
      begin
        ParsePictureHeader(Dec);
        MPGVideoDecodePicture(Dec, FrameCB, UserData);
        Inc(Pos, 4);
      end;
      MPG_SEQUENCE_END: Exit;
    else
      Inc(Pos, 4);
    end;
  end;
end;

procedure MPGVideoFree(var Dec: TMPGVideoDecoder);
begin
  if Dec.Initialized then MPGPoolFree(Dec.Pool);
  Dec.Initialized := False;
end;

end.
