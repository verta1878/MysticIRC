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
{ GIF Decoder — Raw File I/O (short string mode compatible)
  Decodes GIF87a/GIF89a to pixel buffer with palette.
  Supports single frame + animation frames.
  LZW decompression built-in — no external units.

  Usage:
    var GIF: TGIFImage;
    begin
      if GIFLoadFileRaw('image.gif', GIF) then
      begin
        // GIF.Pixels = Width*Height bytes (palette indices)
        // GIF.Palette = 256 RGB entries
        // GIF.FrameCount for animation
        GIFFreeRaw(GIF);
      end;
    end;
}
unit gifdecr;

{$H-}
{$mode objfpc}

interface

const
  MAX_GIF_FRAMES = 256;

type
  TGIFRGBEntry = packed record
    R, G, B: Byte;
  end;

  TGIFFrame = record
    Pixels: PByte;        // palette-indexed pixels
    Left, Top: Word;      // frame offset
    Width, Height: Word;  // frame dimensions
    DelayMS: Word;        // delay in milliseconds
    Transparent: Boolean;
    TransIndex: Byte;     // transparent palette index
    Disposal: Byte;       // disposal method (0-3)
  end;

  TGIFImage = record
    Width, Height: Word;              // logical screen size
    Palette: array[0..255] of TGIFRGBEntry;  // global palette
    PaletteSize: Integer;
    BGColor: Byte;
    Pixels: PByte;                    // first frame, full canvas
    Frames: array[0..MAX_GIF_FRAMES-1] of TGIFFrame;
    FrameCount: Integer;
    Valid: Boolean;
  end;

function GIFLoadFileRaw(const FileName: string; out GIF: TGIFImage): Boolean;
function GIFLoadMemRaw(InBuf: PByte; InSize: LongWord; out GIF: TGIFImage): Boolean;
procedure GIFFreeRaw(var GIF: TGIFImage);
function IsGIFFile(const FileName: string): Boolean;

{ Convert palette-indexed frame to 24-bit RGB }
procedure GIFFrameToRGB(const GIF: TGIFImage; FrameIdx: Integer;
  OutBuf: PByte);

implementation

const
  LZW_MAX_CODES = 4096;

type
  TLZWEntry = record
    Prefix: SmallInt;
    Suffix: Byte;
  end;

  TLZWTable = array[0..LZW_MAX_CODES-1] of TLZWEntry;

var
  LZWBitBuf: LongWord;
  LZWBitCount: Integer;
  LZWBlockPos: LongWord;
  LZWBlockSize: Byte;
  LZWDataBuf: PByte;
  LZWDataSize: LongWord;
  LZWDataPos: LongWord;

function LZWReadByte: Integer;
begin
  if LZWBlockPos >= LZWBlockSize then
  begin
    // Read next sub-block
    if LZWDataPos >= LZWDataSize then begin Result := -1; Exit; end;
    LZWBlockSize := LZWDataBuf[LZWDataPos];
    Inc(LZWDataPos);
    LZWBlockPos := 0;
    if LZWBlockSize = 0 then begin Result := -1; Exit; end;
  end;
  if LZWDataPos >= LZWDataSize then begin Result := -1; Exit; end;
  Result := LZWDataBuf[LZWDataPos];
  Inc(LZWDataPos);
  Inc(LZWBlockPos);
end;

function LZWReadCode(CodeSize: Integer): Integer;
var
  B: Integer;
begin
  while LZWBitCount < CodeSize do
  begin
    B := LZWReadByte;
    if B < 0 then begin Result := -1; Exit; end;
    LZWBitBuf := LZWBitBuf or (LongWord(B) shl LZWBitCount);
    Inc(LZWBitCount, 8);
  end;
  Result := LZWBitBuf and ((1 shl CodeSize) - 1);
  LZWBitBuf := LZWBitBuf shr CodeSize;
  Dec(LZWBitCount, CodeSize);
end;

function LZWDecode(DataBuf: PByte; DataPos, DataSize: LongWord;
  MinCodeSize: Byte; OutBuf: PByte; OutSize: LongWord): LongWord;
var
  Table: ^TLZWTable;
  ClearCode, EOICode: Integer;
  CodeSize, NextCode, MaxCode: Integer;
  OldCode, Code, InCode: Integer;
  Stack: array[0..LZW_MAX_CODES-1] of Byte;
  StackPtr: Integer;
  OutPos: LongWord;
  I: Integer;
begin
  Result := 0;
  New(Table);
  try
    ClearCode := 1 shl MinCodeSize;
    EOICode := ClearCode + 1;

    // Init LZW reader state
    LZWBitBuf := 0;
    LZWBitCount := 0;
    LZWBlockPos := 0;
    LZWBlockSize := 0;
    LZWDataBuf := DataBuf;
    LZWDataSize := DataSize;
    LZWDataPos := DataPos;

    // Init table
    CodeSize := MinCodeSize + 1;
    NextCode := EOICode + 1;
    MaxCode := 1 shl CodeSize;
    for I := 0 to ClearCode - 1 do
    begin
      Table^[I].Prefix := -1;
      Table^[I].Suffix := Byte(I);
    end;

    OldCode := -1;
    OutPos := 0;

    while OutPos < OutSize do
    begin
      Code := LZWReadCode(CodeSize);
      if (Code < 0) or (Code = EOICode) then Break;

      if Code = ClearCode then
      begin
        CodeSize := MinCodeSize + 1;
        NextCode := EOICode + 1;
        MaxCode := 1 shl CodeSize;
        OldCode := -1;
        Continue;
      end;

      InCode := Code;

      // Build output string on stack
      StackPtr := 0;
      if Code >= NextCode then
      begin
        if OldCode < 0 then Break;
        Stack[StackPtr] := Table^[OldCode].Suffix;
        Inc(StackPtr);
        Code := OldCode;
      end;

      while (Code >= ClearCode) and (StackPtr < LZW_MAX_CODES) do
      begin
        Stack[StackPtr] := Table^[Code].Suffix;
        Inc(StackPtr);
        Code := Table^[Code].Prefix;
        if Code < 0 then Break;
      end;
      if Code < 0 then Break;

      Stack[StackPtr] := Table^[Code].Suffix;
      Inc(StackPtr);

      // Output in reverse
      for I := StackPtr - 1 downto 0 do
      begin
        if OutPos >= OutSize then Break;
        OutBuf[OutPos] := Stack[I];
        Inc(OutPos);
      end;

      // Add to table
      if (OldCode >= 0) and (NextCode < LZW_MAX_CODES) then
      begin
        Table^[NextCode].Prefix := SmallInt(OldCode);
        Table^[NextCode].Suffix := Table^[Code].Suffix;
        Inc(NextCode);
        if (NextCode >= MaxCode) and (CodeSize < 12) then
        begin
          Inc(CodeSize);
          MaxCode := 1 shl CodeSize;
        end;
      end;

      OldCode := InCode;
    end;

    Result := OutPos;
  finally
    Dispose(Table);
  end;
end;

function GIFLoadMemRaw(InBuf: PByte; InSize: LongWord; out GIF: TGIFImage): Boolean;
var
  Pos: LongWord;
  Sig: array[0..5] of Char;
  Flags, BGColor, Aspect: Byte;
  GlobalPalSize: Integer;
  I: Integer;
  HasGlobalPal: Boolean;
  // Extension vars
  ExtLabel, BlockSize: Byte;
  // Image descriptor
  ImgLeft, ImgTop, ImgWidth, ImgHeight: Word;
  ImgFlags, MinCodeSize: Byte;
  HasLocalPal: Boolean;
  LocalPalSize: Integer;
  Interlaced: Boolean;
  // Frame vars
  FramePixels: PByte;
  PixelCount: LongWord;
  // GCE vars
  GCEDelay: Word;
  GCETransparent: Boolean;
  GCETransIndex: Byte;
  GCEDisposal: Byte;
begin
  Result := False;
  FillChar(GIF, SizeOf(GIF), 0);

  if (InBuf = nil) or (InSize < 13) then Exit;

  // Header
  Move(InBuf[0], Sig, 6);
  if (Sig <> 'GIF87a') and (Sig <> 'GIF89a') then Exit;

  // Logical screen descriptor
  Move(InBuf[6], GIF.Width, 2);
  Move(InBuf[8], GIF.Height, 2);
  Flags := InBuf[10];
  BGColor := InBuf[11];
  Aspect := InBuf[12];
  GIF.BGColor := BGColor;

  HasGlobalPal := (Flags and $80) <> 0;
  GlobalPalSize := 1 shl ((Flags and $07) + 1);
  GIF.PaletteSize := GlobalPalSize;
  Pos := 13;

  // Global palette
  if HasGlobalPal then
  begin
    for I := 0 to GlobalPalSize - 1 do
    begin
      if Pos + 2 >= InSize then Exit;
      GIF.Palette[I].R := InBuf[Pos];
      GIF.Palette[I].G := InBuf[Pos + 1];
      GIF.Palette[I].B := InBuf[Pos + 2];
      Inc(Pos, 3);
    end;
  end;

  // Allocate canvas
  PixelCount := LongWord(GIF.Width) * GIF.Height;
  GetMem(GIF.Pixels, PixelCount);
  FillChar(GIF.Pixels^, PixelCount, BGColor);

  GCEDelay := 0;
  GCETransparent := False;
  GCETransIndex := 0;
  GCEDisposal := 0;

  // Parse blocks
  while Pos < InSize do
  begin
    case InBuf[Pos] of
      $21: begin // Extension
             Inc(Pos);
             if Pos >= InSize then Break;
             ExtLabel := InBuf[Pos];
             Inc(Pos);

             if ExtLabel = $F9 then
             begin
               // Graphic Control Extension
               if Pos >= InSize then Break;
               BlockSize := InBuf[Pos]; Inc(Pos);
               if (BlockSize >= 4) and (Pos + 4 <= InSize) then
               begin
                 GCEDisposal := (InBuf[Pos] shr 2) and $07;
                 GCETransparent := (InBuf[Pos] and $01) <> 0;
                 Move(InBuf[Pos + 1], GCEDelay, 2);
                 GCETransIndex := InBuf[Pos + 3];
                 Inc(Pos, BlockSize);
               end;
               // Skip block terminator
               if (Pos < InSize) and (InBuf[Pos] = 0) then Inc(Pos);
             end
             else
             begin
               // Skip other extensions
               while Pos < InSize do
               begin
                 BlockSize := InBuf[Pos]; Inc(Pos);
                 if BlockSize = 0 then Break;
                 Inc(Pos, BlockSize);
               end;
             end;
           end;

      $2C: begin // Image descriptor
             Inc(Pos);
             if Pos + 9 > InSize then Break;
             Move(InBuf[Pos], ImgLeft, 2);
             Move(InBuf[Pos + 2], ImgTop, 2);
             Move(InBuf[Pos + 4], ImgWidth, 2);
             Move(InBuf[Pos + 6], ImgHeight, 2);
             ImgFlags := InBuf[Pos + 8];
             Inc(Pos, 9);

             HasLocalPal := (ImgFlags and $80) <> 0;
             Interlaced := (ImgFlags and $40) <> 0;
             LocalPalSize := 1 shl ((ImgFlags and $07) + 1);

             // Local palette (skip for now — use global)
             if HasLocalPal then
               Inc(Pos, LocalPalSize * 3);

             // LZW minimum code size
             if Pos >= InSize then Break;
             MinCodeSize := InBuf[Pos];
             Inc(Pos);

             // Decode LZW data
             PixelCount := LongWord(ImgWidth) * ImgHeight;
             GetMem(FramePixels, PixelCount);
             FillChar(FramePixels^, PixelCount, 0);

             LZWDecode(InBuf, Pos, InSize, MinCodeSize,
                       FramePixels, PixelCount);

             // Skip LZW sub-blocks
             while Pos < InSize do
             begin
               BlockSize := InBuf[Pos]; Inc(Pos);
               if BlockSize = 0 then Break;
               Inc(Pos, BlockSize);
             end;

             // Store frame
             if GIF.FrameCount < MAX_GIF_FRAMES then
             begin
               with GIF.Frames[GIF.FrameCount] do
               begin
                 Pixels := FramePixels;
                 Left := ImgLeft;
                 Top := ImgTop;
                 Width := ImgWidth;
                 Height := ImgHeight;
                 DelayMS := GCEDelay * 10;
                 Transparent := GCETransparent;
                 TransIndex := GCETransIndex;
                 Disposal := GCEDisposal;
               end;
               Inc(GIF.FrameCount);
             end
             else
               FreeMem(FramePixels);

             // Composite first frame onto canvas
             if GIF.FrameCount = 1 then
             begin
               for I := 0 to Integer(ImgHeight) - 1 do
               begin
                 if (ImgTop + I) < GIF.Height then
                   Move(FramePixels[I * ImgWidth],
                        GIF.Pixels[(ImgTop + I) * GIF.Width + ImgLeft],
                        ImgWidth);
               end;
             end;

             // Reset GCE
             GCEDelay := 0;
             GCETransparent := False;
             GCETransIndex := 0;
             GCEDisposal := 0;
           end;

      $3B: Break; // Trailer

    else
      Inc(Pos);
    end;
  end;

  GIF.Valid := GIF.FrameCount > 0;
  Result := GIF.Valid;
end;

function GIFLoadFileRaw(const FileName: string; out GIF: TGIFImage): Boolean;
var
  F: File;
  Buf: PByte;
  Size, BytesRead: LongWord;
begin
  Result := False;
  FillChar(GIF, SizeOf(GIF), 0);
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}
  Size := FileSize(F);
  if Size < 13 then begin Close(F); Exit; end;
  GetMem(Buf, Size);
  BlockRead(F, Buf^, Size, BytesRead);
  Close(F);
  if BytesRead = Size then
    Result := GIFLoadMemRaw(Buf, Size, GIF);
  FreeMem(Buf);
end;

procedure GIFFreeRaw(var GIF: TGIFImage);
var I: Integer;
begin
  if GIF.Pixels <> nil then begin FreeMem(GIF.Pixels); GIF.Pixels := nil; end;
  for I := 0 to GIF.FrameCount - 1 do
    if GIF.Frames[I].Pixels <> nil then
      FreeMem(GIF.Frames[I].Pixels);
  GIF.FrameCount := 0;
  GIF.Valid := False;
end;

function IsGIFFile(const FileName: string): Boolean;
var
  F: File;
  Sig: array[0..2] of Char;
  BytesRead: LongWord;
begin
  Result := False;
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}
  BlockRead(F, Sig, 3, BytesRead);
  Close(F);
  Result := (BytesRead = 3) and (Sig = 'GIF');
end;

procedure GIFFrameToRGB(const GIF: TGIFImage; FrameIdx: Integer;
  OutBuf: PByte);
var
  I: Integer;
  Idx: Byte;
  Frame: TGIFFrame;
  PixCount: LongWord;
begin
  if (FrameIdx < 0) or (FrameIdx >= GIF.FrameCount) then Exit;
  Frame := GIF.Frames[FrameIdx];
  PixCount := LongWord(Frame.Width) * Frame.Height;
  for I := 0 to Integer(PixCount) - 1 do
  begin
    Idx := Frame.Pixels[I];
    OutBuf[I * 3] := GIF.Palette[Idx].R;
    OutBuf[I * 3 + 1] := GIF.Palette[Idx].G;
    OutBuf[I * 3 + 2] := GIF.Palette[Idx].B;
  end;
end;

end.
