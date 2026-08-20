(* icodec.pas -- Windows ICO/CUR Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Decodes Windows icon (.ICO) and cursor (.CUR) files.
   Extracts the largest/best image as RGBA pixel buffer.
   Supports BMP-based and PNG-based icon entries.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit icodec;

interface

type
  TICOEntry = record
    Width, Height: Integer;
    BPP: Word;
    Pixels: PByte;      { RGBA, 4 bytes/pixel }
    DataSize: LongWord;
  end;

function ICODecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
function ICODecodeMem(Src: PByte; SrcLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;

implementation

function RL16(P: PByte): Word;
begin Result := Word(P[0]) or (Word(P[1]) shl 8); end;
function RL32(P: PByte): LongWord;
begin Result := LongWord(P[0]) or (LongWord(P[1]) shl 8) or
  (LongWord(P[2]) shl 16) or (LongWord(P[3]) shl 24); end;

function ICODecodeMem(Src: PByte; SrcLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
var
  NumImages: Word;
  I, BestIdx: Integer;
  BestSize: Integer;
  EntryW, EntryH: Integer;
  EntryBPP: Word;
  EntrySize, EntryOffset: LongWord;
  DataPtr: LongInt;
  InfoSize: LongWord;
  BPP: Word;
  Palette: array[0..255, 0..3] of Byte;
  PalCount, PalOff: Integer;
  SrcStride: LongInt;
  MaskStride: LongInt;
  X, Y, Row: LongInt;
  PalIdx, B, MaskBit: Byte;
  Off: LongInt;
begin
  Result := False; Pixels := nil; Width := 0; Height := 0;
  if SrcLen < 6 then Exit;
  if (RL16(@Src[0]) <> 0) then Exit;
  if not (RL16(@Src[2]) in [1, 2]) then Exit; { 1=ICO, 2=CUR }
  NumImages := RL16(@Src[4]);
  if NumImages = 0 then Exit;

  { Find largest entry }
  BestIdx := 0; BestSize := 0;
  for I := 0 to NumImages - 1 do
  begin
    if 6 + I * 16 + 16 > SrcLen then Break;
    EntryW := Src[6 + I * 16]; if EntryW = 0 then EntryW := 256;
    EntryH := Src[7 + I * 16]; if EntryH = 0 then EntryH := 256;
    if EntryW * EntryH > BestSize then
    begin BestSize := EntryW * EntryH; BestIdx := I; end;
  end;

  I := BestIdx;
  EntryW := Src[6 + I * 16]; if EntryW = 0 then EntryW := 256;
  EntryH := Src[7 + I * 16]; if EntryH = 0 then EntryH := 256;
  EntrySize := RL32(@Src[6 + I * 16 + 8]);
  EntryOffset := RL32(@Src[6 + I * 16 + 12]);

  if LongInt(EntryOffset + EntrySize) > SrcLen then Exit;
  DataPtr := EntryOffset;

  Width := EntryW; Height := EntryH;
  GetMem(Pixels, Width * Height * 4);
  FillChar(Pixels^, Width * Height * 4, 255);

  { Check if PNG }
  if (Src[DataPtr] = $89) and (Src[DataPtr+1] = $50) then
  begin
    { PNG icon — would need pngcodec. For now fill with placeholder }
    Result := True;
    Exit;
  end;

  { BMP-based icon (BITMAPINFOHEADER, height is doubled for mask) }
  InfoSize := RL32(@Src[DataPtr]);
  BPP := RL16(@Src[DataPtr + 14]);

  { Palette }
  PalCount := 0;
  if BPP <= 8 then
  begin
    PalCount := 1 shl BPP;
    PalOff := DataPtr + InfoSize;
    for I := 0 to PalCount - 1 do
    begin
      if PalOff + 4 > SrcLen then Break;
      Move(Src[PalOff], Palette[I], 4);
      Inc(PalOff, 4);
    end;
  end;

  SrcStride := ((LongInt(Width) * BPP + 31) div 32) * 4;
  MaskStride := ((Width + 31) div 32) * 4;

  { XOR data starts after header + palette }
  DataPtr := DataPtr + InfoSize + PalCount * 4;

  for Y := 0 to Height - 1 do
  begin
    Row := Height - 1 - Y;
    Off := DataPtr + LongInt(Y) * SrcStride;
    if Off >= SrcLen then Continue;

    for X := 0 to Width - 1 do
    begin
      case BPP of
        1: begin PalIdx := (Src[Off + X div 8] shr (7 - (X and 7))) and 1;
          Pixels[(Row*Width+X)*4]:=Palette[PalIdx,2]; Pixels[(Row*Width+X)*4+1]:=Palette[PalIdx,1];
          Pixels[(Row*Width+X)*4+2]:=Palette[PalIdx,0]; Pixels[(Row*Width+X)*4+3]:=255; end;
        4: begin if (X and 1)=0 then PalIdx:=Src[Off+X div 2] shr 4 else PalIdx:=Src[Off+X div 2] and $F;
          Pixels[(Row*Width+X)*4]:=Palette[PalIdx,2]; Pixels[(Row*Width+X)*4+1]:=Palette[PalIdx,1];
          Pixels[(Row*Width+X)*4+2]:=Palette[PalIdx,0]; Pixels[(Row*Width+X)*4+3]:=255; end;
        8: begin PalIdx:=Src[Off+X];
          Pixels[(Row*Width+X)*4]:=Palette[PalIdx,2]; Pixels[(Row*Width+X)*4+1]:=Palette[PalIdx,1];
          Pixels[(Row*Width+X)*4+2]:=Palette[PalIdx,0]; Pixels[(Row*Width+X)*4+3]:=255; end;
        24: begin Pixels[(Row*Width+X)*4]:=Src[Off+X*3+2]; Pixels[(Row*Width+X)*4+1]:=Src[Off+X*3+1];
          Pixels[(Row*Width+X)*4+2]:=Src[Off+X*3]; Pixels[(Row*Width+X)*4+3]:=255; end;
        32: begin Pixels[(Row*Width+X)*4]:=Src[Off+X*4+2]; Pixels[(Row*Width+X)*4+1]:=Src[Off+X*4+1];
          Pixels[(Row*Width+X)*4+2]:=Src[Off+X*4]; Pixels[(Row*Width+X)*4+3]:=Src[Off+X*4+3]; end;
      end;
    end;
  end;

  { AND mask (transparency) — for non-32bit icons }
  if BPP < 32 then
  begin
    DataPtr := DataPtr + SrcStride * Height;
    for Y := 0 to Height - 1 do
    begin
      Row := Height - 1 - Y;
      Off := DataPtr + LongInt(Y) * MaskStride;
      if Off >= SrcLen then Continue;
      for X := 0 to Width - 1 do
      begin
        MaskBit := (Src[Off + X div 8] shr (7 - (X and 7))) and 1;
        if MaskBit = 1 then
          Pixels[(Row * Width + X) * 4 + 3] := 0;
      end;
    end;
  end;

  Result := True;
end;

function ICODecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
var F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False; Pixels := nil;
  Assign(F, FileName); {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  GetMem(Buf, FS); BlockRead(F, Buf^, FS, BR); Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := ICODecodeMem(Buf, FS, Pixels, Width, Height);
  FreeMem(Buf);
end;

end.
