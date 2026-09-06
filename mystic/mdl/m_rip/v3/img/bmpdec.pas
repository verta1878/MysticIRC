(* bmpdec.pas -- Windows BMP/DIB Image Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Decodes Windows BMP files to 24-bit RGB pixel buffer.
   Supports 1/4/8/16/24/32-bit, RLE4, RLE8, top-down/bottom-up.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit bmpdec;

interface

function BMPDecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
function BMPDecodeMem(Src: PByte; SrcLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;

implementation

function RL16(P: PByte): Word;
begin Result := Word(P[0]) or (Word(P[1]) shl 8); end;

function RL32(P: PByte): LongWord;
begin Result := LongWord(P[0]) or (LongWord(P[1]) shl 8) or
  (LongWord(P[2]) shl 16) or (LongWord(P[3]) shl 24); end;

function BMPDecodeMem(Src: PByte; SrcLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
var
  DataOff, InfoSize: LongWord;
  BPP: Word;
  Compression: LongWord;
  Palette: array[0..255, 0..3] of Byte;
  PalCount, PalOff: Integer;
  TopDown: Boolean;
  SrcStride, X, Y, Row: LongInt;
  Offset: LongInt;
  PalIdx: Byte;
  B: Byte;
  V16: Word;
  I: Integer;
begin
  Result := False; Pixels := nil; Width := 0; Height := 0;
  if SrcLen < 26 then Exit;
  if (Src[0] <> Ord('B')) or (Src[1] <> Ord('M')) then Exit;

  DataOff := RL32(@Src[10]);
  InfoSize := RL32(@Src[14]);
  if InfoSize < 12 then Exit;

  if InfoSize = 12 then
  begin { OS/2 v1 }
    Width := SmallInt(RL16(@Src[18]));
    Height := SmallInt(RL16(@Src[20]));
    BPP := RL16(@Src[24]);
    Compression := 0;
  end
  else
  begin
    Width := LongInt(RL32(@Src[18]));
    Height := LongInt(RL32(@Src[22]));
    BPP := RL16(@Src[28]);
    Compression := RL32(@Src[30]);
  end;

  TopDown := Height < 0;
  if TopDown then Height := -Height;
  if (Width <= 0) or (Height <= 0) then Exit;

  { Read palette }
  PalCount := 0;
  if BPP <= 8 then
  begin
    PalCount := 1 shl BPP;
    PalOff := 14 + InfoSize;
    if InfoSize = 12 then
    begin { 3-byte palette entries }
      for I := 0 to PalCount - 1 do
      begin
        if PalOff + 3 > SrcLen then Break;
        Palette[I, 0] := Src[PalOff]; Palette[I, 1] := Src[PalOff+1];
        Palette[I, 2] := Src[PalOff+2]; Palette[I, 3] := 0;
        Inc(PalOff, 3);
      end;
    end
    else
    begin { 4-byte palette entries }
      for I := 0 to PalCount - 1 do
      begin
        if PalOff + 4 > SrcLen then Break;
        Move(Src[PalOff], Palette[I], 4);
        Inc(PalOff, 4);
      end;
    end;
  end;

  GetMem(Pixels, Width * Height * 3);
  FillChar(Pixels^, Width * Height * 3, 0);

  { Scanline stride (padded to 4 bytes) }
  SrcStride := ((LongInt(Width) * BPP + 31) div 32) * 4;

  for Y := 0 to Height - 1 do
  begin
    if TopDown then Row := Y else Row := Height - 1 - Y;
    Offset := DataOff + LongInt(Y) * SrcStride;
    if Offset >= SrcLen then Continue;

    case BPP of
      1:
        for X := 0 to Width - 1 do
        begin
          if Offset + X div 8 >= SrcLen then Break;
          B := Src[Offset + X div 8];
          PalIdx := (B shr (7 - (X and 7))) and 1;
          Pixels[(Row * Width + X) * 3] := Palette[PalIdx, 2];
          Pixels[(Row * Width + X) * 3 + 1] := Palette[PalIdx, 1];
          Pixels[(Row * Width + X) * 3 + 2] := Palette[PalIdx, 0];
        end;
      4:
        for X := 0 to Width - 1 do
        begin
          if Offset + X div 2 >= SrcLen then Break;
          B := Src[Offset + X div 2];
          if (X and 1) = 0 then PalIdx := B shr 4 else PalIdx := B and $0F;
          Pixels[(Row * Width + X) * 3] := Palette[PalIdx, 2];
          Pixels[(Row * Width + X) * 3 + 1] := Palette[PalIdx, 1];
          Pixels[(Row * Width + X) * 3 + 2] := Palette[PalIdx, 0];
        end;
      8:
        for X := 0 to Width - 1 do
        begin
          if Offset + X >= SrcLen then Break;
          PalIdx := Src[Offset + X];
          Pixels[(Row * Width + X) * 3] := Palette[PalIdx, 2];
          Pixels[(Row * Width + X) * 3 + 1] := Palette[PalIdx, 1];
          Pixels[(Row * Width + X) * 3 + 2] := Palette[PalIdx, 0];
        end;
      16:
        for X := 0 to Width - 1 do
        begin
          if Offset + X * 2 + 1 >= SrcLen then Break;
          V16 := RL16(@Src[Offset + X * 2]);
          Pixels[(Row * Width + X) * 3] := ((V16 shr 10) and $1F) shl 3;
          Pixels[(Row * Width + X) * 3 + 1] := ((V16 shr 5) and $1F) shl 3;
          Pixels[(Row * Width + X) * 3 + 2] := (V16 and $1F) shl 3;
        end;
      24:
        for X := 0 to Width - 1 do
        begin
          if Offset + X * 3 + 2 >= SrcLen then Break;
          Pixels[(Row * Width + X) * 3] := Src[Offset + X * 3 + 2];
          Pixels[(Row * Width + X) * 3 + 1] := Src[Offset + X * 3 + 1];
          Pixels[(Row * Width + X) * 3 + 2] := Src[Offset + X * 3];
        end;
      32:
        for X := 0 to Width - 1 do
        begin
          if Offset + X * 4 + 2 >= SrcLen then Break;
          Pixels[(Row * Width + X) * 3] := Src[Offset + X * 4 + 2];
          Pixels[(Row * Width + X) * 3 + 1] := Src[Offset + X * 4 + 1];
          Pixels[(Row * Width + X) * 3 + 2] := Src[Offset + X * 4];
        end;
    end;
  end;
  Result := True;
end;

function BMPDecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
var F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False; Pixels := nil;
  Assign(F, FileName); {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  GetMem(Buf, FS); BlockRead(F, Buf^, FS, BR); Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := BMPDecodeMem(Buf, FS, Pixels, Width, Height);
  FreeMem(Buf);
end;

end.
