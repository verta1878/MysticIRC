(* pngcodec.pas -- Standalone Pure Pascal PNG Decoder
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   PNG Decoder -- Pure Pascal, depends only on paszlib for inflate.
   Decodes PNG files to 24-bit RGB or 32-bit RGBA pixel buffer.

   Supports:
     Color types: Grayscale (0), RGB (2), Palette (3),
       Grayscale+Alpha (4), RGBA (6)
     Bit depths: 1, 2, 4, 8, 16 (16-bit downsampled to 8)
     All 5 filter types (None, Sub, Up, Average, Paeth)
     Transparency (tRNS chunk)

   Usage:
     var Pixels: PByte; W, H: LongInt; Alpha: Boolean;
     begin
       if PNGDecodeFile('image.png', Pixels, W, H, Alpha) then begin
         // Pixels = W*H*(3 or 4) bytes RGB or RGBA
         FreeMem(Pixels);
       end;
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}

{$R-}
{$Q-}

unit pngcodec;

interface

function PNGDecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt;
  out HasAlpha: Boolean): Boolean;

function PNGDecodeMem(Data: PByte; DataLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt;
  out HasAlpha: Boolean): Boolean;

implementation

uses
  zbase, paszlib;

const
  PNG_SIG: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);

function PaethPredictor(A, B, C: Integer): Byte;
var
  P, PA, PB, PC: Integer;
begin
  P := A + B - C;
  PA := Abs(P - A);
  PB := Abs(P - B);
  PC := Abs(P - C);
  if (PA <= PB) and (PA <= PC) then
    Result := A
  else if PB <= PC then
    Result := B
  else
    Result := C;
end;

function DoInflate(Src: PByte; SrcLen: LongInt;
  Dst: PByte; DstLen: LongInt): LongInt;
var
  ZS: TZStream;
  Ret: Integer;
begin
  Result := -1;
  FillChar(ZS, SizeOf(ZS), 0);
  ZS.next_in := PByte(Src);
  ZS.avail_in := SrcLen;
  ZS.next_out := PByte(Dst);
  ZS.avail_out := DstLen;

  Ret := inflateInit(ZS);
  if Ret <> Z_OK then Exit;

  Ret := inflate(ZS, Z_FINISH);
  inflateEnd(ZS);

  if (Ret = Z_STREAM_END) or (Ret = Z_OK) then
    Result := ZS.total_out
  else
    Result := -1;
end;

function PNGDecodeMem(Data: PByte; DataLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt;
  out HasAlpha: Boolean): Boolean;
var
  Pos: LongInt;
  ChunkLen: LongWord;
  ChunkType: LongWord;
  BitDepth, ColorType: Byte;
  Palette: array[0..255, 0..2] of Byte;
  PalCount: Integer;
  TransPal: array[0..255] of Byte;
  HasTransPal: Boolean;
  TransCount: Integer;
  CompData: PByte;
  CompLen, CompCap: LongInt;
  RawData: PByte;
  RawLen: LongInt;
  BPP: Integer;
  Stride: LongInt;
  FilterByte: Byte;
  X, Y: LongInt;
  RP, PP: LongInt;
  PrevByte, UpByte, UpLeftByte: Byte;
  CurByte: Byte;
  I: LongInt;
  OutBPP: Integer;
  PalIdx: Byte;
  Gray: Byte;
  SamplesPerByte: Integer;
  BitShift: Integer;
  BitMask: Byte;
  PrevBPP: Integer;

  function ReadDWord: LongWord;
  begin
    if Pos + 4 > DataLen then begin Result := 0; Exit; end;
    Result := (LongWord(Data[Pos]) shl 24) or
              (LongWord(Data[Pos+1]) shl 16) or
              (LongWord(Data[Pos+2]) shl 8) or
              LongWord(Data[Pos+3]);
    Inc(Pos, 4);
  end;

begin
  Result := False;
  Pixels := nil;
  Width := 0; Height := 0;
  HasAlpha := False;
  PalCount := 0;
  HasTransPal := False;
  TransCount := 0;
  CompData := nil;
  CompLen := 0; CompCap := 0;
  RawData := nil;
  FillChar(TransPal, SizeOf(TransPal), 255);

  if DataLen < 8 then Exit;
  for I := 0 to 7 do
    if Data[I] <> PNG_SIG[I] then Exit;
  Pos := 8;

  BitDepth := 8;
  ColorType := 2;

  while Pos + 8 <= DataLen do
  begin
    ChunkLen := ReadDWord;
    ChunkType := ReadDWord;

    if ChunkType = $49484452 then
    begin
      if ChunkLen < 13 then Exit;
      Width := ReadDWord;
      Height := ReadDWord;
      BitDepth := Data[Pos]; Inc(Pos);
      ColorType := Data[Pos]; Inc(Pos);
      Inc(Pos, ChunkLen - 10 + 4);
    end
    else if ChunkType = $504C5445 then
    begin
      PalCount := ChunkLen div 3;
      if PalCount > 256 then PalCount := 256;
      for I := 0 to PalCount - 1 do
      begin
        Palette[I, 0] := Data[Pos]; Inc(Pos);
        Palette[I, 1] := Data[Pos]; Inc(Pos);
        Palette[I, 2] := Data[Pos]; Inc(Pos);
      end;
      Inc(Pos, ChunkLen - PalCount * 3 + 4);
    end
    else if ChunkType = $74524E53 then
    begin
      HasTransPal := True;
      TransCount := ChunkLen;
      if TransCount > 256 then TransCount := 256;
      for I := 0 to TransCount - 1 do
      begin
        TransPal[I] := Data[Pos]; Inc(Pos);
      end;
      Inc(Pos, ChunkLen - TransCount + 4);
    end
    else if ChunkType = $49444154 then
    begin
      if CompLen + LongInt(ChunkLen) > CompCap then
      begin
        CompCap := (CompLen + LongInt(ChunkLen)) * 2 + 1024;
        ReallocMem(CompData, CompCap);
      end;
      Move(Data[Pos], CompData[CompLen], ChunkLen);
      Inc(CompLen, ChunkLen);
      Inc(Pos, ChunkLen + 4);
    end
    else if ChunkType = $49454E44 then
      Break
    else
      Inc(Pos, ChunkLen + 4);
  end;

  if (Width <= 0) or (Height <= 0) or (CompData = nil) or (CompLen < 2) then
  begin
    FreeMem(CompData);
    Exit;
  end;

  case ColorType of
    0: BPP := 1;
    2: BPP := 3;
    3: BPP := 1;
    4: BPP := 2;
    6: BPP := 4;
  else
    FreeMem(CompData); Exit;
  end;
  if BitDepth = 16 then BPP := BPP * 2;
  PrevBPP := BPP;
  if (BitDepth < 8) then PrevBPP := 1;

  if BitDepth >= 8 then
    Stride := 1 + Width * BPP
  else begin
    SamplesPerByte := 8 div BitDepth;
    Stride := 1 + (Width + SamplesPerByte - 1) div SamplesPerByte;
  end;

  RawLen := Stride * Height;
  GetMem(RawData, RawLen);
  FillChar(RawData^, RawLen, 0);

  I := DoInflate(CompData, CompLen, RawData, RawLen);
  FreeMem(CompData);
  if I < 0 then begin FreeMem(RawData); Exit; end;

  HasAlpha := (ColorType = 4) or (ColorType = 6) or
              (HasTransPal and (ColorType = 3));
  if HasAlpha then OutBPP := 4 else OutBPP := 3;

  GetMem(Pixels, Width * Height * OutBPP);
  FillChar(Pixels^, Width * Height * OutBPP, 0);

  RP := 0;
  PP := 0;

  for Y := 0 to Height - 1 do
  begin
    FilterByte := RawData[RP];
    Inc(RP);

    for X := 0 to (Stride - 2) do
    begin
      CurByte := RawData[RP + X];
      if X >= PrevBPP then
        PrevByte := RawData[RP + X - PrevBPP]
      else
        PrevByte := 0;
      if Y > 0 then
        UpByte := RawData[RP + X - Stride]
      else
        UpByte := 0;
      if (Y > 0) and (X >= PrevBPP) then
        UpLeftByte := RawData[RP + X - PrevBPP - Stride]
      else
        UpLeftByte := 0;

      case FilterByte of
        0: ;
        1: CurByte := Byte(CurByte + PrevByte);
        2: CurByte := Byte(CurByte + UpByte);
        3: CurByte := Byte(CurByte + (Integer(PrevByte) + Integer(UpByte)) div 2);
        4: CurByte := Byte(CurByte + PaethPredictor(PrevByte, UpByte, UpLeftByte));
      end;
      RawData[RP + X] := CurByte;
    end;

    for X := 0 to Width - 1 do
    begin
      case ColorType of
        0: begin
          if BitDepth = 8 then Gray := RawData[RP + X]
          else if BitDepth = 16 then Gray := RawData[RP + X * 2]
          else begin
            SamplesPerByte := 8 div BitDepth;
            BitMask := (1 shl BitDepth) - 1;
            BitShift := (SamplesPerByte - 1 - (X mod SamplesPerByte)) * BitDepth;
            Gray := (RawData[RP + X div SamplesPerByte] shr BitShift) and BitMask;
            Gray := Gray * (255 div ((1 shl BitDepth) - 1));
          end;
          Pixels[PP] := Gray; Pixels[PP+1] := Gray; Pixels[PP+2] := Gray;
          if HasAlpha then Pixels[PP+3] := 255;
        end;
        2: begin
          if BitDepth = 8 then begin
            Pixels[PP] := RawData[RP + X*3];
            Pixels[PP+1] := RawData[RP + X*3+1];
            Pixels[PP+2] := RawData[RP + X*3+2];
          end else begin
            Pixels[PP] := RawData[RP + X*6];
            Pixels[PP+1] := RawData[RP + X*6+2];
            Pixels[PP+2] := RawData[RP + X*6+4];
          end;
          if HasAlpha then Pixels[PP+3] := 255;
        end;
        3: begin
          if BitDepth = 8 then PalIdx := RawData[RP + X]
          else begin
            SamplesPerByte := 8 div BitDepth;
            BitMask := (1 shl BitDepth) - 1;
            BitShift := (SamplesPerByte - 1 - (X mod SamplesPerByte)) * BitDepth;
            PalIdx := (RawData[RP + X div SamplesPerByte] shr BitShift) and BitMask;
          end;
          if PalIdx < PalCount then begin
            Pixels[PP] := Palette[PalIdx, 0];
            Pixels[PP+1] := Palette[PalIdx, 1];
            Pixels[PP+2] := Palette[PalIdx, 2];
          end;
          if HasAlpha then begin
            if PalIdx < TransCount then Pixels[PP+3] := TransPal[PalIdx]
            else Pixels[PP+3] := 255;
          end;
        end;
        4: begin
          if BitDepth = 8 then begin
            Gray := RawData[RP + X*2];
            Pixels[PP] := Gray; Pixels[PP+1] := Gray; Pixels[PP+2] := Gray;
            Pixels[PP+3] := RawData[RP + X*2+1];
          end else begin
            Gray := RawData[RP + X*4];
            Pixels[PP] := Gray; Pixels[PP+1] := Gray; Pixels[PP+2] := Gray;
            Pixels[PP+3] := RawData[RP + X*4+2];
          end;
        end;
        6: begin
          if BitDepth = 8 then begin
            Pixels[PP] := RawData[RP + X*4];
            Pixels[PP+1] := RawData[RP + X*4+1];
            Pixels[PP+2] := RawData[RP + X*4+2];
            Pixels[PP+3] := RawData[RP + X*4+3];
          end else begin
            Pixels[PP] := RawData[RP + X*8];
            Pixels[PP+1] := RawData[RP + X*8+2];
            Pixels[PP+2] := RawData[RP + X*8+4];
            Pixels[PP+3] := RawData[RP + X*8+6];
          end;
        end;
      end;
      Inc(PP, OutBPP);
    end;
    Inc(RP, Stride - 1);
  end;

  FreeMem(RawData);
  Result := True;
end;

function PNGDecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt;
  out HasAlpha: Boolean): Boolean;
var
  F: File;
  Data: PByte;
  FileSize, BytesRead: LongInt;
begin
  Result := False; Pixels := nil;
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FileSize := System.FileSize(F);
  if FileSize < 8 then begin Close(F); Exit; end;
  GetMem(Data, FileSize);
  BlockRead(F, Data^, FileSize, BytesRead);
  Close(F);
  if BytesRead <> FileSize then begin FreeMem(Data); Exit; end;
  Result := PNGDecodeMem(Data, FileSize, Pixels, Width, Height, HasAlpha);
  FreeMem(Data);
end;

end.
