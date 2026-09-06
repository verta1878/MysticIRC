(* tgadec.pas -- Targa TGA Image Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Decodes TGA files to RGB or RGBA. Uncompressed + RLE.
   8-bit (palette/gray), 16-bit (5551), 24-bit, 32-bit.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit tgadec;

interface

function TGADecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt;
  out HasAlpha: Boolean): Boolean;
function TGADecodeMem(Src: PByte; SrcLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt;
  out HasAlpha: Boolean): Boolean;

implementation

function TGADecodeMem(Src: PByte; SrcLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt;
  out HasAlpha: Boolean): Boolean;
var
  IDLen, CMapType, ImageType: Byte;
  CMapStart, CMapLen: Word;
  CMapBPP: Byte;
  BPP: Byte;
  Descriptor: Byte;
  TopDown: Boolean;
  Palette: array[0..255, 0..3] of Byte;
  Pos: LongInt;
  OutBPP: Integer;
  X, Y, Row: LongInt;
  I, PalIdx: Integer;
  RLECount: Integer;
  RLEPacket: Boolean;
  PixBuf: array[0..3] of Byte;
  Off: LongInt;
  V16: Word;
begin
  Result := False; Pixels := nil; Width := 0; Height := 0; HasAlpha := False;
  if SrcLen < 18 then Exit;

  IDLen := Src[0]; CMapType := Src[1]; ImageType := Src[2];
  CMapStart := Src[3] or (Word(Src[4]) shl 8);
  CMapLen := Src[5] or (Word(Src[6]) shl 8);
  CMapBPP := Src[7];
  Width := Src[12] or (LongInt(Src[13]) shl 8);
  Height := Src[14] or (LongInt(Src[15]) shl 8);
  BPP := Src[16];
  Descriptor := Src[17];
  TopDown := (Descriptor and $20) <> 0;

  if (Width <= 0) or (Height <= 0) then Exit;
  if not (ImageType in [1, 2, 3, 9, 10, 11]) then Exit;

  HasAlpha := (BPP = 32);
  if HasAlpha then OutBPP := 4 else OutBPP := 3;

  Pos := 18 + IDLen;

  { Read palette }
  if CMapType = 1 then
  begin
    for I := 0 to CMapLen - 1 do
    begin
      if Pos >= SrcLen then Break;
      case CMapBPP of
        24: begin Palette[I,0]:=Src[Pos+2]; Palette[I,1]:=Src[Pos+1]; Palette[I,2]:=Src[Pos]; Palette[I,3]:=255; Inc(Pos,3); end;
        32: begin Palette[I,0]:=Src[Pos+2]; Palette[I,1]:=Src[Pos+1]; Palette[I,2]:=Src[Pos]; Palette[I,3]:=Src[Pos+3]; Inc(Pos,4); end;
        15,16: begin V16:=Src[Pos] or (Word(Src[Pos+1]) shl 8);
          Palette[I,0]:=((V16 shr 10) and $1F) shl 3; Palette[I,1]:=((V16 shr 5) and $1F) shl 3;
          Palette[I,2]:=(V16 and $1F) shl 3; Palette[I,3]:=255; Inc(Pos,2); end;
      end;
    end;
  end;

  GetMem(Pixels, Width * Height * OutBPP);
  FillChar(Pixels^, Width * Height * OutBPP, 0);

  { Decode pixels }
  X := 0; Y := 0;
  while (Y < Height) and (Pos < SrcLen) do
  begin
    if ImageType >= 9 then
    begin { RLE }
      if Pos >= SrcLen then Break;
      RLEPacket := (Src[Pos] and $80) <> 0;
      RLECount := (Src[Pos] and $7F) + 1;
      Inc(Pos);

      if RLEPacket then
      begin
        { Read one pixel, repeat }
        FillChar(PixBuf, 4, 0);
        case BPP of
          8: PixBuf[0] := Src[Pos];
          16: begin V16:=Src[Pos] or (Word(Src[Pos+1]) shl 8);
            PixBuf[0]:=((V16 shr 10) and $1F) shl 3; PixBuf[1]:=((V16 shr 5) and $1F) shl 3; PixBuf[2]:=(V16 and $1F) shl 3; end;
          24: begin PixBuf[0]:=Src[Pos+2]; PixBuf[1]:=Src[Pos+1]; PixBuf[2]:=Src[Pos]; end;
          32: begin PixBuf[0]:=Src[Pos+2]; PixBuf[1]:=Src[Pos+1]; PixBuf[2]:=Src[Pos]; PixBuf[3]:=Src[Pos+3]; end;
        end;
        Inc(Pos, BPP div 8);

        for I := 0 to RLECount - 1 do
        begin
          if TopDown then Row := Y else Row := Height - 1 - Y;
          Off := (Row * Width + X) * OutBPP;
          if (ImageType and 7) in [1] then { palette }
          begin
            PalIdx := PixBuf[0];
            Pixels[Off]:=Palette[PalIdx,0]; Pixels[Off+1]:=Palette[PalIdx,1]; Pixels[Off+2]:=Palette[PalIdx,2];
          end
          else if (ImageType and 7) = 3 then { grayscale }
          begin Pixels[Off]:=PixBuf[0]; Pixels[Off+1]:=PixBuf[0]; Pixels[Off+2]:=PixBuf[0]; end
          else
          begin Pixels[Off]:=PixBuf[0]; Pixels[Off+1]:=PixBuf[1]; Pixels[Off+2]:=PixBuf[2]; end;
          if HasAlpha then Pixels[Off+3] := PixBuf[3];
          Inc(X); if X >= Width then begin X := 0; Inc(Y); end;
        end;
      end
      else
      begin
        { Raw pixels }
        for I := 0 to RLECount - 1 do
        begin
          if Pos >= SrcLen then Break;
          if TopDown then Row := Y else Row := Height - 1 - Y;
          Off := (Row * Width + X) * OutBPP;
          case BPP of
            8: begin PalIdx:=Src[Pos];
              if (ImageType and 7)=3 then begin Pixels[Off]:=PalIdx; Pixels[Off+1]:=PalIdx; Pixels[Off+2]:=PalIdx; end
              else begin Pixels[Off]:=Palette[PalIdx,0]; Pixels[Off+1]:=Palette[PalIdx,1]; Pixels[Off+2]:=Palette[PalIdx,2]; end;
              Inc(Pos); end;
            16: begin V16:=Src[Pos] or (Word(Src[Pos+1]) shl 8);
              Pixels[Off]:=((V16 shr 10) and $1F) shl 3; Pixels[Off+1]:=((V16 shr 5) and $1F) shl 3; Pixels[Off+2]:=(V16 and $1F) shl 3;
              Inc(Pos,2); end;
            24: begin Pixels[Off]:=Src[Pos+2]; Pixels[Off+1]:=Src[Pos+1]; Pixels[Off+2]:=Src[Pos]; Inc(Pos,3); end;
            32: begin Pixels[Off]:=Src[Pos+2]; Pixels[Off+1]:=Src[Pos+1]; Pixels[Off+2]:=Src[Pos]; Pixels[Off+3]:=Src[Pos+3]; Inc(Pos,4); end;
          end;
          Inc(X); if X >= Width then begin X := 0; Inc(Y); end;
        end;
      end;
    end
    else
    begin { Uncompressed }
      if TopDown then Row := Y else Row := Height - 1 - Y;
      Off := (Row * Width + X) * OutBPP;
      case BPP of
        8: begin PalIdx:=Src[Pos];
          if ImageType=3 then begin Pixels[Off]:=PalIdx; Pixels[Off+1]:=PalIdx; Pixels[Off+2]:=PalIdx; end
          else begin Pixels[Off]:=Palette[PalIdx,0]; Pixels[Off+1]:=Palette[PalIdx,1]; Pixels[Off+2]:=Palette[PalIdx,2]; end;
          Inc(Pos); end;
        16: begin V16:=Src[Pos] or (Word(Src[Pos+1]) shl 8);
          Pixels[Off]:=((V16 shr 10) and $1F) shl 3; Pixels[Off+1]:=((V16 shr 5) and $1F) shl 3; Pixels[Off+2]:=(V16 and $1F) shl 3;
          Inc(Pos,2); end;
        24: begin Pixels[Off]:=Src[Pos+2]; Pixels[Off+1]:=Src[Pos+1]; Pixels[Off+2]:=Src[Pos]; Inc(Pos,3); end;
        32: begin Pixels[Off]:=Src[Pos+2]; Pixels[Off+1]:=Src[Pos+1]; Pixels[Off+2]:=Src[Pos]; Pixels[Off+3]:=Src[Pos+3]; Inc(Pos,4); end;
      end;
      Inc(X); if X >= Width then begin X := 0; Inc(Y); end;
    end;
  end;
  Result := True;
end;

function TGADecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt; out HasAlpha: Boolean): Boolean;
var F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False; Pixels := nil;
  Assign(F, FileName); {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  GetMem(Buf, FS); BlockRead(F, Buf^, FS, BR); Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := TGADecodeMem(Buf, FS, Pixels, Width, Height, HasAlpha);
  FreeMem(Buf);
end;

end.
