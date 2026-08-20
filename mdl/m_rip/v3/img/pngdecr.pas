{ This file is part of FPC 2.6.4irc.
  Copyright (C) 2026 fpc264irc contributors.

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <https://www.gnu.org/licenses/>.
}
{ PNG Decoder — Raw File I/O (short string mode compatible)
  Decodes PNG to 24-bit RGB pixel buffer.
  Supports 8-bit palette, 8/16-bit RGB, 8-bit grayscale.
  Uses paszlib for Deflate decompression.

  Usage:
    var Pixels: PByte; W, H: Integer;
    begin
      if PNGLoadFileRaw('image.png', Pixels, W, H) then
      begin
        // Pixels = W*H*3 bytes RGB
        FreeMem(Pixels);
      end;
    end;
}
unit pngdecr;

{$H-}
{$mode objfpc}

interface

function PNGLoadFileRaw(const FileName: string;
  out Pixels: PByte; out Width, Height: Integer): Boolean;
function PNGLoadMemRaw(InBuf: PByte; InSize: LongWord;
  out Pixels: PByte; out Width, Height: Integer): Boolean;

{ RGBA variants — preserve alpha channel (4 bytes per pixel) }
function PNGLoadFileRGBA(const FileName: string;
  out Pixels: PByte; out Width, Height: Integer;
  out HasAlpha: Boolean): Boolean;
function PNGLoadMemRGBA(InBuf: PByte; InSize: LongWord;
  out Pixels: PByte; out Width, Height: Integer;
  out HasAlpha: Boolean): Boolean;

function IsPNGFile(const FileName: string): Boolean;

implementation

uses
  zbase, zinflate;

type
  TPNGChunk = record
    Length: LongWord;
    ChunkType: array[0..3] of Char;
    DataOffset: LongWord;
    CRC: LongWord;
  end;

function SwapBE32(V: LongWord): LongWord;
begin
  Result := ((V and $FF) shl 24) or ((V and $FF00) shl 8) or
            ((V and $FF0000) shr 8) or ((V and $FF000000) shr 24);
end;

function PaethPredictor(A, B, C: Integer): Byte;
var
  P, PA, PB, PC: Integer;
begin
  P := A + B - C;
  PA := Abs(P - A);
  PB := Abs(P - B);
  PC := Abs(P - C);
  if (PA <= PB) and (PA <= PC) then Result := Byte(A)
  else if PB <= PC then Result := Byte(B)
  else Result := Byte(C);
end;

procedure UnfilterRow(FilterType: Byte; CurRow, PrevRow: PByte;
  BytesPerPixel, RowBytes: Integer);
var
  I: Integer;
  A, B, C: Byte;
begin
  case FilterType of
    0: ; // None
    1: // Sub
      for I := BytesPerPixel to RowBytes - 1 do
        CurRow[I] := Byte(CurRow[I] + CurRow[I - BytesPerPixel]);
    2: // Up
      if PrevRow <> nil then
        for I := 0 to RowBytes - 1 do
          CurRow[I] := Byte(CurRow[I] + PrevRow[I]);
    3: // Average
      for I := 0 to RowBytes - 1 do
      begin
        if I >= BytesPerPixel then A := CurRow[I - BytesPerPixel] else A := 0;
        if PrevRow <> nil then B := PrevRow[I] else B := 0;
        CurRow[I] := Byte(CurRow[I] + (A + B) div 2);
      end;
    4: // Paeth
      for I := 0 to RowBytes - 1 do
      begin
        if I >= BytesPerPixel then A := CurRow[I - BytesPerPixel] else A := 0;
        if PrevRow <> nil then B := PrevRow[I] else B := 0;
        if (PrevRow <> nil) and (I >= BytesPerPixel) then
          C := PrevRow[I - BytesPerPixel]
        else C := 0;
        CurRow[I] := Byte(CurRow[I] + PaethPredictor(A, B, C));
      end;
  end;
end;

function PNGLoadMemRaw(InBuf: PByte; InSize: LongWord;
  out Pixels: PByte; out Width, Height: Integer): Boolean;
var
  Pos: LongWord;
  ChunkLen: LongWord;
  ChunkType: array[0..3] of Char;
  // IHDR fields
  BitDepth, ColorType, Compression, Filter, Interlace: Byte;
  // Palette
  Palette: array[0..255, 0..2] of Byte;
  HasPalette: Boolean;
  // Compressed data accumulator
  CompData: PByte;
  CompSize, CompCap: LongWord;
  // Decompressed data
  RawData: PByte;
  RawSize: LongWord;
  // Row processing
  BytesPerPixel, RowBytes: Integer;
  Row, PrevRow, TempRow: PByte;
  X, Y: Integer;
  FilterByte: Byte;
  DestSize: LongWord;
  Ret: Integer;
  ZStr: z_stream;
begin
  Result := False;
  Pixels := nil;
  Width := 0;
  Height := 0;
  CompData := nil;
  RawData := nil;
  HasPalette := False;

  if (InBuf = nil) or (InSize < 33) then Exit;

  // Check PNG signature
  if (InBuf[0] <> $89) or (InBuf[1] <> $50) or (InBuf[2] <> $4E) or
     (InBuf[3] <> $47) or (InBuf[4] <> $0D) or (InBuf[5] <> $0A) or
     (InBuf[6] <> $1A) or (InBuf[7] <> $0A) then Exit;

  Pos := 8;
  CompSize := 0;
  CompCap := 65536;
  GetMem(CompData, CompCap);

  try
    while Pos + 8 <= InSize do
    begin
      ChunkLen := SwapBE32(PLongWord(@InBuf[Pos])^);
      Move(InBuf[Pos + 4], ChunkType, 4);
      Inc(Pos, 8);

      if ChunkType = 'IHDR' then
      begin
        if ChunkLen < 13 then Exit;
        Width := SwapBE32(PLongWord(@InBuf[Pos])^);
        Height := SwapBE32(PLongWord(@InBuf[Pos + 4])^);
        BitDepth := InBuf[Pos + 8];
        ColorType := InBuf[Pos + 9];
        Compression := InBuf[Pos + 10];
        Filter := InBuf[Pos + 11];
        Interlace := InBuf[Pos + 12];
      end
      else if ChunkType = 'PLTE' then
      begin
        HasPalette := True;
        Move(InBuf[Pos], Palette, ChunkLen);
      end
      else if ChunkType = 'IDAT' then
      begin
        // Accumulate compressed data
        if CompSize + ChunkLen > CompCap then
        begin
          while CompCap < CompSize + ChunkLen do
            CompCap := CompCap * 2;
          ReallocMem(CompData, CompCap);
        end;
        Move(InBuf[Pos], CompData[CompSize], ChunkLen);
        Inc(CompSize, ChunkLen);
      end
      else if ChunkType = 'IEND' then
        Break;

      Inc(Pos, ChunkLen + 4); // +4 for CRC
    end;

    if (Width = 0) or (Height = 0) or (CompSize = 0) then Exit;

    // Calculate row size
    case ColorType of
      0: BytesPerPixel := 1;  // Grayscale
      2: BytesPerPixel := 3;  // RGB
      3: BytesPerPixel := 1;  // Palette
      4: BytesPerPixel := 2;  // Grayscale + Alpha
      6: BytesPerPixel := 4;  // RGBA
    else
      Exit;
    end;

    if BitDepth = 16 then
      BytesPerPixel := BytesPerPixel * 2;

    RowBytes := Width * BytesPerPixel;
    RawSize := (RowBytes + 1) * LongWord(Height); // +1 for filter byte per row

    // Decompress with zlib (z_stream API)
    GetMem(RawData, RawSize);
    DestSize := RawSize;

    FillChar(ZStr, SizeOf(ZStr), 0);
    ZStr.next_in := CompData;
    ZStr.avail_in := CompSize;
    ZStr.next_out := RawData;
    ZStr.avail_out := DestSize;
    Ret := inflateInit(ZStr);
    if Ret <> Z_OK then begin FreeMem(RawData); RawData := nil; Exit; end;
    Ret := inflate(ZStr, Z_FINISH);
    inflateEnd(ZStr);
    if (Ret <> Z_STREAM_END) and (Ret <> Z_OK) then
    begin
      FreeMem(RawData);
      RawData := nil;
      Exit;
    end;

    // Allocate output (always 24-bit RGB)
    GetMem(Pixels, Width * Height * 3);

    // Unfilter and convert to RGB
    PrevRow := nil;
    GetMem(TempRow, RowBytes);
    try
      for Y := 0 to Height - 1 do
      begin
        FilterByte := RawData[Y * (RowBytes + 1)];
        Row := @RawData[Y * (RowBytes + 1) + 1];

        // Copy to temp for unfiltering
        Move(Row^, TempRow^, RowBytes);
        UnfilterRow(FilterByte, TempRow, PrevRow, BytesPerPixel, RowBytes);
        Move(TempRow^, Row^, RowBytes);

        // Convert to RGB
        for X := 0 to Width - 1 do
        begin
          case ColorType of
            0: begin // Grayscale
                 Pixels[(Y * Width + X) * 3] := Row[X];
                 Pixels[(Y * Width + X) * 3 + 1] := Row[X];
                 Pixels[(Y * Width + X) * 3 + 2] := Row[X];
               end;
            2: begin // RGB
                 Pixels[(Y * Width + X) * 3] := Row[X * 3];
                 Pixels[(Y * Width + X) * 3 + 1] := Row[X * 3 + 1];
                 Pixels[(Y * Width + X) * 3 + 2] := Row[X * 3 + 2];
               end;
            3: begin // Palette
                 Pixels[(Y * Width + X) * 3] := Palette[Row[X], 0];
                 Pixels[(Y * Width + X) * 3 + 1] := Palette[Row[X], 1];
                 Pixels[(Y * Width + X) * 3 + 2] := Palette[Row[X], 2];
               end;
            4: begin // Grayscale + Alpha (ignore alpha)
                 Pixels[(Y * Width + X) * 3] := Row[X * 2];
                 Pixels[(Y * Width + X) * 3 + 1] := Row[X * 2];
                 Pixels[(Y * Width + X) * 3 + 2] := Row[X * 2];
               end;
            6: begin // RGBA (ignore alpha)
                 Pixels[(Y * Width + X) * 3] := Row[X * 4];
                 Pixels[(Y * Width + X) * 3 + 1] := Row[X * 4 + 1];
                 Pixels[(Y * Width + X) * 3 + 2] := Row[X * 4 + 2];
               end;
          end;
        end;

        PrevRow := Row;
      end;
    finally
      FreeMem(TempRow);
    end;

    Result := True;

  finally
    if CompData <> nil then FreeMem(CompData);
    if RawData <> nil then FreeMem(RawData);
    if not Result and (Pixels <> nil) then
    begin
      FreeMem(Pixels);
      Pixels := nil;
    end;
  end;
end;

function PNGLoadFileRaw(const FileName: string;
  out Pixels: PByte; out Width, Height: Integer): Boolean;
var
  F: File;
  Buf: PByte;
  Size, BytesRead: LongWord;
begin
  Result := False;
  Pixels := nil; Width := 0; Height := 0;
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}
  Size := FileSize(F);
  if Size < 33 then begin Close(F); Exit; end;
  GetMem(Buf, Size);
  BlockRead(F, Buf^, Size, BytesRead);
  Close(F);
  if BytesRead = Size then
    Result := PNGLoadMemRaw(Buf, Size, Pixels, Width, Height);
  FreeMem(Buf);
end;

function IsPNGFile(const FileName: string): Boolean;
var
  F: File;
  Sig: array[0..3] of Byte;
  BytesRead: LongWord;
begin
  Result := False;
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}
  BlockRead(F, Sig, 4, BytesRead);
  Close(F);
  Result := (BytesRead = 4) and (Sig[0] = $89) and (Sig[1] = $50)
            and (Sig[2] = $4E) and (Sig[3] = $47);
end;


function PNGLoadMemRGBA(InBuf: PByte; InSize: LongWord;
  out Pixels: PByte; out Width, Height: Integer;
  out HasAlpha: Boolean): Boolean;
var
  Pos: LongWord;
  ChunkLen: LongWord;
  ChunkType: array[0..3] of Char;
  BitDepth, ColorType, Compression, Filter, Interlace: Byte;
  Palette: array[0..255, 0..2] of Byte;
  PaletteAlpha: array[0..255] of Byte;
  HasPalette, HasTRNS: Boolean;
  CompData: PByte;
  CompSize, CompCap: LongWord;
  RawData: PByte;
  RawSize, DestSize: LongWord;
  BytesPerPixel, RowBytes: Integer;
  Row, PrevRow, TempRow: PByte;
  X, Y: Integer;
  FilterByte: Byte;
  Ret: Integer;
  ZStr: z_stream;
  OutBPP: Integer; // output bytes per pixel (3 or 4)
  Idx: Byte;
begin
  Result := False;
  Pixels := nil;
  Width := 0;
  Height := 0;
  HasAlpha := False;
  CompData := nil;
  RawData := nil;
  HasPalette := False;
  HasTRNS := False;
  FillChar(PaletteAlpha, SizeOf(PaletteAlpha), 255); // default opaque

  if (InBuf = nil) or (InSize < 33) then Exit;
  if (InBuf[0] <> $89) or (InBuf[1] <> $50) or (InBuf[2] <> $4E) or
     (InBuf[3] <> $47) then Exit;

  Pos := 8;
  CompSize := 0;
  CompCap := 65536;
  GetMem(CompData, CompCap);

  try
    while Pos + 8 <= InSize do
    begin
      ChunkLen := SwapBE32(PLongWord(@InBuf[Pos])^);
      Move(InBuf[Pos + 4], ChunkType, 4);
      Inc(Pos, 8);

      if ChunkType = 'IHDR' then
      begin
        if ChunkLen < 13 then Exit;
        Width := SwapBE32(PLongWord(@InBuf[Pos])^);
        Height := SwapBE32(PLongWord(@InBuf[Pos + 4])^);
        BitDepth := InBuf[Pos + 8];
        ColorType := InBuf[Pos + 9];
      end
      else if ChunkType = 'PLTE' then
      begin
        HasPalette := True;
        Move(InBuf[Pos], Palette, ChunkLen);
      end
      else if ChunkType = 'tRNS' then
      begin
        HasTRNS := True;
        if ChunkLen <= 256 then
          Move(InBuf[Pos], PaletteAlpha, ChunkLen);
      end
      else if ChunkType = 'IDAT' then
      begin
        if CompSize + ChunkLen > CompCap then
        begin
          while CompCap < CompSize + ChunkLen do CompCap := CompCap * 2;
          ReallocMem(CompData, CompCap);
        end;
        Move(InBuf[Pos], CompData[CompSize], ChunkLen);
        Inc(CompSize, ChunkLen);
      end
      else if ChunkType = 'IEND' then
        Break;

      Inc(Pos, ChunkLen + 4);
    end;

    if (Width = 0) or (Height = 0) or (CompSize = 0) then Exit;

    // Determine if output has alpha
    HasAlpha := (ColorType = 4) or (ColorType = 6) or HasTRNS;
    if HasAlpha then OutBPP := 4 else OutBPP := 3;

    case ColorType of
      0: BytesPerPixel := 1;
      2: BytesPerPixel := 3;
      3: BytesPerPixel := 1;
      4: BytesPerPixel := 2;
      6: BytesPerPixel := 4;
    else Exit;
    end;
    if BitDepth = 16 then BytesPerPixel := BytesPerPixel * 2;

    RowBytes := Width * BytesPerPixel;
    RawSize := (RowBytes + 1) * LongWord(Height);

    GetMem(RawData, RawSize);
    DestSize := RawSize;

    FillChar(ZStr, SizeOf(ZStr), 0);
    ZStr.next_in := CompData;
    ZStr.avail_in := CompSize;
    ZStr.next_out := RawData;
    ZStr.avail_out := DestSize;
    Ret := inflateInit(ZStr);
    if Ret <> Z_OK then begin FreeMem(RawData); RawData := nil; Exit; end;
    Ret := inflate(ZStr, Z_FINISH);
    inflateEnd(ZStr);
    if (Ret <> Z_STREAM_END) and (Ret <> Z_OK) then
    begin
      FreeMem(RawData); RawData := nil; Exit;
    end;

    GetMem(Pixels, Width * Height * OutBPP);
    PrevRow := nil;
    GetMem(TempRow, RowBytes);

    try
      for Y := 0 to Height - 1 do
      begin
        FilterByte := RawData[Y * (RowBytes + 1)];
        Row := @RawData[Y * (RowBytes + 1) + 1];
        Move(Row^, TempRow^, RowBytes);
        UnfilterRow(FilterByte, TempRow, PrevRow, BytesPerPixel, RowBytes);
        Move(TempRow^, Row^, RowBytes);

        for X := 0 to Width - 1 do
        begin
          case ColorType of
            0: begin // Grayscale
                 Pixels[(Y * Width + X) * OutBPP] := Row[X];
                 Pixels[(Y * Width + X) * OutBPP + 1] := Row[X];
                 Pixels[(Y * Width + X) * OutBPP + 2] := Row[X];
                 if HasAlpha then Pixels[(Y * Width + X) * OutBPP + 3] := 255;
               end;
            2: begin // RGB
                 Pixels[(Y * Width + X) * OutBPP] := Row[X * 3];
                 Pixels[(Y * Width + X) * OutBPP + 1] := Row[X * 3 + 1];
                 Pixels[(Y * Width + X) * OutBPP + 2] := Row[X * 3 + 2];
                 if HasAlpha then Pixels[(Y * Width + X) * OutBPP + 3] := 255;
               end;
            3: begin // Palette
                 Idx := Row[X];
                 Pixels[(Y * Width + X) * OutBPP] := Palette[Idx, 0];
                 Pixels[(Y * Width + X) * OutBPP + 1] := Palette[Idx, 1];
                 Pixels[(Y * Width + X) * OutBPP + 2] := Palette[Idx, 2];
                 if HasAlpha then Pixels[(Y * Width + X) * OutBPP + 3] := PaletteAlpha[Idx];
               end;
            4: begin // Grayscale + Alpha
                 Pixels[(Y * Width + X) * OutBPP] := Row[X * 2];
                 Pixels[(Y * Width + X) * OutBPP + 1] := Row[X * 2];
                 Pixels[(Y * Width + X) * OutBPP + 2] := Row[X * 2];
                 Pixels[(Y * Width + X) * OutBPP + 3] := Row[X * 2 + 1];
               end;
            6: begin // RGBA
                 Pixels[(Y * Width + X) * OutBPP] := Row[X * 4];
                 Pixels[(Y * Width + X) * OutBPP + 1] := Row[X * 4 + 1];
                 Pixels[(Y * Width + X) * OutBPP + 2] := Row[X * 4 + 2];
                 Pixels[(Y * Width + X) * OutBPP + 3] := Row[X * 4 + 3];
               end;
          end;
        end;
        PrevRow := Row;
      end;
    finally
      FreeMem(TempRow);
    end;

    Result := True;
  finally
    if CompData <> nil then FreeMem(CompData);
    if RawData <> nil then FreeMem(RawData);
    if not Result and (Pixels <> nil) then
    begin
      FreeMem(Pixels); Pixels := nil;
    end;
  end;
end;

function PNGLoadFileRGBA(const FileName: string;
  out Pixels: PByte; out Width, Height: Integer;
  out HasAlpha: Boolean): Boolean;
var
  F: File;
  Buf: PByte;
  Size, BytesRead: LongWord;
begin
  Result := False;
  Pixels := nil; Width := 0; Height := 0; HasAlpha := False;
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}
  Size := FileSize(F);
  if Size < 33 then begin Close(F); Exit; end;
  GetMem(Buf, Size);
  BlockRead(F, Buf^, Size, BytesRead);
  Close(F);
  if BytesRead = Size then
    Result := PNGLoadMemRGBA(Buf, Size, Pixels, Width, Height, HasAlpha);
  FreeMem(Buf);
end;

end.
