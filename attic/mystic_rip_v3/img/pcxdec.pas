(* pcxdec.pas -- ZSoft PCX Image Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Decodes PCX files to 24-bit RGB. Supports 1/2/4/8-bit per plane,
   1-4 planes, RLE decompression, 256-color VGA palette.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit pcxdec;

interface

function PCXDecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
function PCXDecodeMem(Src: PByte; SrcLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;

implementation

function PCXDecodeMem(Src: PByte; SrcLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
var
  Manufacturer, Version, Encoding, BPPlane: Byte;
  XMin, YMin, XMax, YMax: Word;
  NPlanes: Byte;
  BytesPerLine: Word;
  Palette16: array[0..15, 0..2] of Byte;
  Palette256: array[0..255, 0..2] of Byte;
  Has256Pal: Boolean;
  SrcPos: LongInt;
  ScanBuf: PByte;
  ScanSize: LongInt;
  X, Y, Plane, I: LongInt;
  RunLen: Integer;
  RunVal: Byte;
  BufPos: LongInt;
  PalIdx: Byte;
  Off: LongInt;
  BitShift: Integer;
begin
  Result := False; Pixels := nil; Width := 0; Height := 0;
  if SrcLen < 128 then Exit;

  Manufacturer := Src[0];
  if Manufacturer <> 10 then Exit;
  Version := Src[1];
  Encoding := Src[2];
  BPPlane := Src[3];
  XMin := Src[4] or (Word(Src[5]) shl 8);
  YMin := Src[6] or (Word(Src[7]) shl 8);
  XMax := Src[8] or (Word(Src[9]) shl 8);
  YMax := Src[10] or (Word(Src[11]) shl 8);
  NPlanes := Src[65];
  BytesPerLine := Src[66] or (Word(Src[67]) shl 8);

  Width := XMax - XMin + 1;
  Height := YMax - YMin + 1;
  if (Width <= 0) or (Height <= 0) then Exit;

  { 16-color palette from header }
  Move(Src[16], Palette16, 48);

  { 256-color palette at end of file }
  Has256Pal := False;
  if (BPPlane = 8) and (NPlanes = 1) and (SrcLen > 769) then
  begin
    if Src[SrcLen - 769] = 12 then
    begin
      Has256Pal := True;
      Move(Src[SrcLen - 768], Palette256, 768);
    end;
  end;

  GetMem(Pixels, Width * Height * 3);
  FillChar(Pixels^, Width * Height * 3, 0);

  { Decode RLE scanlines }
  ScanSize := BytesPerLine * NPlanes;
  GetMem(ScanBuf, ScanSize);
  SrcPos := 128;

  for Y := 0 to Height - 1 do
  begin
    FillChar(ScanBuf^, ScanSize, 0);
    BufPos := 0;

    while (BufPos < ScanSize) and (SrcPos < SrcLen) do
    begin
      RunVal := Src[SrcPos]; Inc(SrcPos);
      if (Encoding = 1) and (RunVal >= $C0) then
      begin
        RunLen := RunVal and $3F;
        if SrcPos < SrcLen then begin RunVal := Src[SrcPos]; Inc(SrcPos); end;
        for I := 0 to RunLen - 1 do
        begin
          if BufPos < ScanSize then begin ScanBuf[BufPos] := RunVal; Inc(BufPos); end;
        end;
      end
      else
      begin
        ScanBuf[BufPos] := RunVal; Inc(BufPos);
      end;
    end;

    { Convert scanline to RGB }
    if (BPPlane = 8) and (NPlanes = 1) then
    begin
      { 256-color }
      for X := 0 to Width - 1 do
      begin
        PalIdx := ScanBuf[X];
        Off := (Y * Width + X) * 3;
        if Has256Pal then
        begin
          Pixels[Off] := Palette256[PalIdx, 0];
          Pixels[Off+1] := Palette256[PalIdx, 1];
          Pixels[Off+2] := Palette256[PalIdx, 2];
        end
        else
        begin
          Pixels[Off] := Palette16[PalIdx and 15, 0];
          Pixels[Off+1] := Palette16[PalIdx and 15, 1];
          Pixels[Off+2] := Palette16[PalIdx and 15, 2];
        end;
      end;
    end
    else if (BPPlane = 8) and (NPlanes = 3) then
    begin
      { 24-bit RGB }
      for X := 0 to Width - 1 do
      begin
        Off := (Y * Width + X) * 3;
        Pixels[Off] := ScanBuf[X];
        Pixels[Off+1] := ScanBuf[BytesPerLine + X];
        Pixels[Off+2] := ScanBuf[BytesPerLine * 2 + X];
      end;
    end
    else if (BPPlane = 1) and (NPlanes <= 4) then
    begin
      { 2/4/16-color planar }
      for X := 0 to Width - 1 do
      begin
        PalIdx := 0;
        for Plane := 0 to NPlanes - 1 do
        begin
          BitShift := 7 - (X and 7);
          if (ScanBuf[Plane * BytesPerLine + X div 8] shr BitShift) and 1 <> 0 then
            PalIdx := PalIdx or (1 shl Plane);
        end;
        Off := (Y * Width + X) * 3;
        Pixels[Off] := Palette16[PalIdx, 0];
        Pixels[Off+1] := Palette16[PalIdx, 1];
        Pixels[Off+2] := Palette16[PalIdx, 2];
      end;
    end;
  end;

  FreeMem(ScanBuf);
  Result := True;
end;

function PCXDecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
var F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False; Pixels := nil;
  Assign(F, FileName); {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  GetMem(Buf, FS); BlockRead(F, Buf^, FS, BR); Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := PCXDecodeMem(Buf, FS, Pixels, Width, Height);
  FreeMem(Buf);
end;

end.
