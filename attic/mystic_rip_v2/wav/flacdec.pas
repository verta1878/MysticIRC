(* flacdec.pas -- FLAC Lossless Audio Decoder
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Decodes FLAC (Free Lossless Audio Codec) files to PCM.
   FLAC uses LPC prediction + Rice/Golomb entropy coding for
   lossless audio compression at ~50-70% of original size.

   Supports:
     Bit depths: 8, 16, 24 (output as 16-bit)
     Sample rates: any (1-655350 Hz)
     Channels: 1-8 (mono, stereo, surround)
     Stereo decorrelation: independent, left-side, right-side, mid-side
     Fixed predictors (order 0-4)
     LPC predictors (order 1-32)
     Rice coding (partition order 0-15)

   Usage:
     var F: TFLACInfo;
     begin
       if FLACLoadFile('music.flac', F) then begin
         // F.Data = 16-bit signed PCM (interleaved)
         // F.SampleRate, F.Channels, F.TotalSamples
         FLACFree(F);
       end;
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit flacdec;

interface

type
  TFLACInfo = record
    Data: PSmallInt;
    DataSize: LongWord;
    SampleRate: LongWord;
    Channels: Byte;
    BitsPerSample: Byte;
    TotalSamples: LongWord;
    MinBlockSize: Word;
    MaxBlockSize: Word;
  end;

function FLACLoadFile(const FileName: ShortString; out Info: TFLACInfo): Boolean;
function FLACLoadMem(Src: PByte; SrcLen: LongInt; out Info: TFLACInfo): Boolean;
procedure FLACFree(var Info: TFLACInfo);

implementation

const
  FLAC_MARKER: array[0..3] of Byte = (Ord('f'), Ord('L'), Ord('a'), Ord('C'));
  MAX_BLOCK_SIZE = 65535;
  MAX_CHANNELS = 8;
  MAX_LPC_ORDER = 32;

type
  TBitReader = record
    Src: PByte;
    SrcLen: LongInt;
    BytePos: LongInt;
    BitPos: Byte;  { 0-7, bits remaining in current byte }
  end;

procedure BRInit(var BR: TBitReader; Src: PByte; Len: LongInt);
begin
  BR.Src := Src;
  BR.SrcLen := Len;
  BR.BytePos := 0;
  BR.BitPos := 0;
end;

function BRReadBits(var BR: TBitReader; N: Integer): LongWord;
var
  Bits: Integer;
  B: Byte;
begin
  Result := 0;
  while N > 0 do
  begin
    if BR.BytePos >= BR.SrcLen then Exit;
    B := BR.Src[BR.BytePos];
    Bits := 8 - BR.BitPos;
    if Bits > N then Bits := N;

    Result := (Result shl Bits) or
              ((B shr (8 - BR.BitPos - Bits)) and ((1 shl Bits) - 1));

    Inc(BR.BitPos, Bits);
    Dec(N, Bits);
    if BR.BitPos >= 8 then
    begin
      BR.BitPos := 0;
      Inc(BR.BytePos);
    end;
  end;
end;

function BRReadSigned(var BR: TBitReader; N: Integer): LongInt;
var
  V: LongWord;
begin
  V := BRReadBits(BR, N);
  if (V and (1 shl (N - 1))) <> 0 then
    Result := LongInt(V) - (1 shl N)
  else
    Result := LongInt(V);
end;

function BRReadUnary(var BR: TBitReader): LongWord;
begin
  Result := 0;
  while BRReadBits(BR, 1) = 0 do
    Inc(Result);
end;

function BRReadRice(var BR: TBitReader; Param: Integer): LongInt;
var
  Q: LongWord;
  R: LongWord;
  V: LongWord;
begin
  Q := BRReadUnary(BR);
  R := BRReadBits(BR, Param);
  V := (Q shl Param) or R;
  if (V and 1) <> 0 then
    Result := -LongInt((V + 1) shr 1)
  else
    Result := LongInt(V shr 1);
end;

procedure BRAlignByte(var BR: TBitReader);
begin
  if BR.BitPos > 0 then
  begin
    BR.BitPos := 0;
    Inc(BR.BytePos);
  end;
end;

function FLACLoadMem(Src: PByte; SrcLen: LongInt; out Info: TFLACInfo): Boolean;
var
  Pos: LongInt;
  I, J, Ch: Integer;
  IsLast: Boolean;
  MetaType: Byte;
  MetaLen: LongWord;
  BR: TBitReader;
  SyncCode: Word;
  BlockStrategy: Byte;
  BlockSizeCode, SRCode, ChAssign: Byte;
  BPSCode: Byte;
  BlockSize: Word;
  SampleRate: LongWord;
  NumChannels, BPS: Byte;
  SubType: Byte;
  Order: Integer;
  WarmUp: array[0..MAX_LPC_ORDER - 1] of LongInt;
  Coeffs: array[0..MAX_LPC_ORDER - 1] of LongInt;
  QLevel: Integer;
  Shift: Integer;
  PartOrder: Integer;
  NumParts: Integer;
  RiceParam: Integer;
  PartSamples: Integer;
  Residual: array[0..MAX_BLOCK_SIZE - 1] of LongInt;
  Decoded: array[0..MAX_CHANNELS - 1, 0..MAX_BLOCK_SIZE - 1] of LongInt;
  Pred: LongInt;
  OutPos: LongInt;
  TotalOut: LongInt;
  FrameChannels: Integer;
  K: Integer;
  Mid, Side: LongInt;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);

  if SrcLen < 42 then Exit;

  { Check fLaC marker }
  for I := 0 to 3 do
    if Src[I] <> FLAC_MARKER[I] then Exit;

  Pos := 4;

  { Read metadata blocks }
  repeat
    if Pos + 4 > SrcLen then Exit;
    IsLast := (Src[Pos] and $80) <> 0;
    MetaType := Src[Pos] and $7F;
    MetaLen := (LongWord(Src[Pos+1]) shl 16) or
               (LongWord(Src[Pos+2]) shl 8) or Src[Pos+3];
    Inc(Pos, 4);

    if MetaType = 0 then { STREAMINFO }
    begin
      if MetaLen >= 34 then
      begin
        Info.MinBlockSize := (Word(Src[Pos]) shl 8) or Src[Pos+1];
        Info.MaxBlockSize := (Word(Src[Pos+2]) shl 8) or Src[Pos+3];
        { Skip min/max frame size (6 bytes) }
        { Sample rate: 20 bits at offset 10 }
        Info.SampleRate := (LongWord(Src[Pos+10]) shl 12) or
                           (LongWord(Src[Pos+11]) shl 4) or
                           (Src[Pos+12] shr 4);
        Info.Channels := ((Src[Pos+12] shr 1) and 7) + 1;
        Info.BitsPerSample := ((Src[Pos+12] and 1) shl 4) or (Src[Pos+13] shr 4) + 1;
        Info.TotalSamples := ((LongWord(Src[Pos+13]) and $0F) shl 28) or
                             (LongWord(Src[Pos+14]) shl 20) or
                             (LongWord(Src[Pos+15]) shl 12) or
                             (LongWord(Src[Pos+16]) shl 4) or
                             (Src[Pos+17] shr 4);
      end;
    end;

    Inc(Pos, MetaLen);
  until IsLast or (Pos >= SrcLen);

  if (Info.SampleRate = 0) or (Info.Channels = 0) then Exit;
  if Info.TotalSamples = 0 then
    Info.TotalSamples := 44100 * 300; { fallback: 5 minutes }

  TotalOut := Info.TotalSamples;
  Info.DataSize := TotalOut * Info.Channels * 2;
  GetMem(Info.Data, Info.DataSize);
  FillChar(Info.Data^, Info.DataSize, 0);
  OutPos := 0;

  { Decode frames }
  while Pos + 4 < SrcLen do
  begin
    { Look for frame sync: 0xFFF8 or 0xFFF9 }
    if (Src[Pos] <> $FF) or ((Src[Pos+1] and $FC) <> $F8) then
    begin
      Inc(Pos);
      Continue;
    end;

    BRInit(BR, @Src[Pos], SrcLen - Pos);
    SyncCode := BRReadBits(BR, 14);
    if SyncCode <> $3FFE then begin Inc(Pos); Continue; end;

    BRReadBits(BR, 1); { reserved }
    BlockStrategy := BRReadBits(BR, 1);
    BlockSizeCode := BRReadBits(BR, 4);
    SRCode := BRReadBits(BR, 4);
    ChAssign := BRReadBits(BR, 4);
    BPSCode := BRReadBits(BR, 3);
    BRReadBits(BR, 1); { reserved }

    { UTF-8 coded frame/sample number }
    I := BRReadBits(BR, 8);
    if (I and $80) <> 0 then
    begin
      J := 0;
      if (I and $E0) = $C0 then J := 1
      else if (I and $F0) = $E0 then J := 2
      else if (I and $F8) = $F0 then J := 3
      else if (I and $FC) = $F8 then J := 4
      else if (I and $FE) = $FC then J := 5;
      for K := 0 to J - 1 do BRReadBits(BR, 8);
    end;

    { Block size }
    case BlockSizeCode of
      1: BlockSize := 192;
      2..5: BlockSize := 576 shl (BlockSizeCode - 2);
      6: BlockSize := BRReadBits(BR, 8) + 1;
      7: BlockSize := BRReadBits(BR, 16) + 1;
      8..15: BlockSize := 256 shl (BlockSizeCode - 8);
    else
      BlockSize := 4096;
    end;
    if BlockSize > MAX_BLOCK_SIZE then BlockSize := MAX_BLOCK_SIZE;

    { Sample rate from header if coded }
    if SRCode = 12 then BRReadBits(BR, 8)
    else if SRCode in [13, 14] then BRReadBits(BR, 16);

    { Frame header CRC }
    BRReadBits(BR, 8);

    { Determine channels }
    if ChAssign < 8 then FrameChannels := ChAssign + 1
    else FrameChannels := 2; { stereo decorrelation modes 8-10 }

    { Decode subframes }
    for Ch := 0 to FrameChannels - 1 do
    begin
      BRReadBits(BR, 1); { padding }
      SubType := BRReadBits(BR, 6);
      { Wasted bits per sample }
      if BRReadBits(BR, 1) = 1 then
        BRReadUnary(BR);

      if SubType = 0 then
      begin
        { Constant }
        Pred := BRReadSigned(BR, Info.BitsPerSample);
        for I := 0 to BlockSize - 1 do
          Decoded[Ch, I] := Pred;
      end
      else if SubType = 1 then
      begin
        { Verbatim }
        for I := 0 to BlockSize - 1 do
          Decoded[Ch, I] := BRReadSigned(BR, Info.BitsPerSample);
      end
      else if (SubType >= 8) and (SubType <= 12) then
      begin
        { Fixed predictor, order = SubType - 8 }
        Order := SubType - 8;
        for I := 0 to Order - 1 do
          Decoded[Ch, I] := BRReadSigned(BR, Info.BitsPerSample);

        { Read residual (Rice coded) }
        I := BRReadBits(BR, 2); { coding method: 0=Rice, 1=Rice2 }
        PartOrder := BRReadBits(BR, 4);
        NumParts := 1 shl PartOrder;

        K := Order;
        for I := 0 to NumParts - 1 do
        begin
          RiceParam := BRReadBits(BR, 4);
          if I = 0 then
            PartSamples := (BlockSize div NumParts) - Order
          else
            PartSamples := BlockSize div NumParts;

          for J := 0 to PartSamples - 1 do
          begin
            if K < BlockSize then
              Decoded[Ch, K] := BRReadRice(BR, RiceParam);
            Inc(K);
          end;
        end;

        { Apply fixed prediction }
        for I := Order to BlockSize - 1 do
        begin
          case Order of
            0: ;
            1: Inc(Decoded[Ch, I], Decoded[Ch, I-1]);
            2: Inc(Decoded[Ch, I], 2 * Decoded[Ch, I-1] - Decoded[Ch, I-2]);
            3: Inc(Decoded[Ch, I], 3 * Decoded[Ch, I-1] - 3 * Decoded[Ch, I-2] + Decoded[Ch, I-3]);
            4: Inc(Decoded[Ch, I], 4 * Decoded[Ch, I-1] - 6 * Decoded[Ch, I-2] +
                                    4 * Decoded[Ch, I-3] - Decoded[Ch, I-4]);
          end;
        end;
      end
      else if (SubType >= 32) then
      begin
        { LPC predictor, order = SubType - 31 }
        Order := SubType - 31;
        if Order > MAX_LPC_ORDER then Order := MAX_LPC_ORDER;

        for I := 0 to Order - 1 do
          Decoded[Ch, I] := BRReadSigned(BR, Info.BitsPerSample);

        QLevel := BRReadBits(BR, 4); { precision - 1 }
        Shift := BRReadSigned(BR, 5);
        for I := 0 to Order - 1 do
          Coeffs[I] := BRReadSigned(BR, QLevel + 1);

        { Read residual }
        I := BRReadBits(BR, 2);
        PartOrder := BRReadBits(BR, 4);
        NumParts := 1 shl PartOrder;

        K := Order;
        for I := 0 to NumParts - 1 do
        begin
          RiceParam := BRReadBits(BR, 4);
          if I = 0 then
            PartSamples := (BlockSize div NumParts) - Order
          else
            PartSamples := BlockSize div NumParts;

          for J := 0 to PartSamples - 1 do
          begin
            if K < BlockSize then
              Decoded[Ch, K] := BRReadRice(BR, RiceParam);
            Inc(K);
          end;
        end;

        { Apply LPC prediction }
        for I := Order to BlockSize - 1 do
        begin
          Pred := 0;
          for J := 0 to Order - 1 do
            Inc(Pred, Coeffs[J] * Decoded[Ch, I - 1 - J]);
          Inc(Decoded[Ch, I], Pred shr Shift);
        end;
      end;
    end;

    { Stereo decorrelation }
    if ChAssign = 8 then
    begin { left-side }
      for I := 0 to BlockSize - 1 do
        Decoded[1, I] := Decoded[0, I] - Decoded[1, I];
    end
    else if ChAssign = 9 then
    begin { right-side }
      for I := 0 to BlockSize - 1 do
        Decoded[0, I] := Decoded[0, I] + Decoded[1, I];
    end
    else if ChAssign = 10 then
    begin { mid-side }
      for I := 0 to BlockSize - 1 do
      begin
        Mid := Decoded[0, I];
        Side := Decoded[1, I];
        Mid := Mid shl 1;
        Inc(Mid, Side and 1);
        Decoded[0, I] := (Mid + Side) shr 1;
        Decoded[1, I] := (Mid - Side) shr 1;
      end;
    end;

    { Write output }
    for I := 0 to BlockSize - 1 do
    begin
      if OutPos >= TotalOut then Break;
      for Ch := 0 to Info.Channels - 1 do
      begin
        if Ch < FrameChannels then
        begin
          Pred := Decoded[Ch, I];
          { Scale to 16-bit }
          if Info.BitsPerSample > 16 then
            Pred := Pred shr (Info.BitsPerSample - 16)
          else if Info.BitsPerSample < 16 then
            Pred := Pred shl (16 - Info.BitsPerSample);
          if Pred > 32767 then Pred := 32767;
          if Pred < -32768 then Pred := -32768;
          Info.Data[OutPos * Info.Channels + Ch] := SmallInt(Pred);
        end;
      end;
      Inc(OutPos);
    end;

    { Skip frame footer CRC16 }
    BRAlignByte(BR);
    BRReadBits(BR, 16);

    Pos := Pos + BR.BytePos;
  end;

  Info.TotalSamples := OutPos;
  Info.DataSize := OutPos * Info.Channels * 2;
  Result := OutPos > 0;
end;

function FLACLoadFile(const FileName: ShortString; out Info: TFLACInfo): Boolean;
var F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False; FillChar(Info, SizeOf(Info), 0);
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  if FS < 42 then begin Close(F); Exit; end;
  GetMem(Buf, FS);
  BlockRead(F, Buf^, FS, BR);
  Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := FLACLoadMem(Buf, FS, Info);
  FreeMem(Buf);
end;

procedure FLACFree(var Info: TFLACInfo);
begin
  if Info.Data <> nil then begin FreeMem(Info.Data); Info.Data := nil; end;
  Info.DataSize := 0; Info.TotalSamples := 0;
end;

end.
