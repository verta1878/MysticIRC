(* pbmdec.pas -- Netpbm PBM/PGM/PPM Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Decodes PBM (P1/P4), PGM (P2/P5), PPM (P3/P6) to RGB.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit pbmdec;

interface

function PBMDecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
function PBMDecodeMem(Src: PByte; SrcLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;

implementation

procedure SkipWS(Src: PByte; SrcLen: LongInt; var Pos: LongInt);
begin
  while Pos < SrcLen do
  begin
    if Src[Pos] = Ord('#') then
      while (Pos < SrcLen) and (Src[Pos] <> 10) do Inc(Pos);
    if (Src[Pos] <= 32) then Inc(Pos) else Exit;
  end;
end;

function ReadInt(Src: PByte; SrcLen: LongInt; var Pos: LongInt): LongInt;
begin
  Result := 0;
  SkipWS(Src, SrcLen, Pos);
  while (Pos < SrcLen) and (Src[Pos] >= Ord('0')) and (Src[Pos] <= Ord('9')) do
  begin
    Result := Result * 10 + (Src[Pos] - Ord('0'));
    Inc(Pos);
  end;
end;

function PBMDecodeMem(Src: PByte; SrcLen: LongInt;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
var
  Pos: LongInt;
  Magic: Word;
  MaxVal: LongInt;
  X, Y: LongInt;
  Off: LongInt;
  V, R, G, B: Integer;
  ByteVal, BitIdx: Byte;
begin
  Result := False; Pixels := nil; Width := 0; Height := 0;
  if SrcLen < 3 then Exit;
  if Src[0] <> Ord('P') then Exit;

  Magic := Src[1] - Ord('0'); { 1-6 }
  if not (Magic in [1..6]) then Exit;

  Pos := 2;
  Width := ReadInt(Src, SrcLen, Pos);
  Height := ReadInt(Src, SrcLen, Pos);

  if (Width <= 0) or (Height <= 0) then Exit;

  MaxVal := 255;
  if Magic in [2, 3, 5, 6] then
    MaxVal := ReadInt(Src, SrcLen, Pos);
  if MaxVal = 0 then MaxVal := 255;

  { Skip single whitespace after header }
  if (Pos < SrcLen) and (Src[Pos] <= 32) then Inc(Pos);

  GetMem(Pixels, Width * Height * 3);
  FillChar(Pixels^, Width * Height * 3, 0);

  case Magic of
    1: { P1: ASCII PBM }
      for Y := 0 to Height - 1 do
        for X := 0 to Width - 1 do
        begin
          V := ReadInt(Src, SrcLen, Pos);
          Off := (Y * Width + X) * 3;
          if V = 0 then begin Pixels[Off]:=255; Pixels[Off+1]:=255; Pixels[Off+2]:=255; end;
        end;

    2: { P2: ASCII PGM }
      for Y := 0 to Height - 1 do
        for X := 0 to Width - 1 do
        begin
          V := (ReadInt(Src, SrcLen, Pos) * 255) div MaxVal;
          Off := (Y * Width + X) * 3;
          Pixels[Off] := V; Pixels[Off+1] := V; Pixels[Off+2] := V;
        end;

    3: { P3: ASCII PPM }
      for Y := 0 to Height - 1 do
        for X := 0 to Width - 1 do
        begin
          R := (ReadInt(Src, SrcLen, Pos) * 255) div MaxVal;
          G := (ReadInt(Src, SrcLen, Pos) * 255) div MaxVal;
          B := (ReadInt(Src, SrcLen, Pos) * 255) div MaxVal;
          Off := (Y * Width + X) * 3;
          Pixels[Off] := R; Pixels[Off+1] := G; Pixels[Off+2] := B;
        end;

    4: { P4: Binary PBM }
      for Y := 0 to Height - 1 do
      begin
        BitIdx := 0; ByteVal := 0;
        for X := 0 to Width - 1 do
        begin
          if BitIdx = 0 then begin if Pos < SrcLen then ByteVal := Src[Pos]; Inc(Pos); end;
          Off := (Y * Width + X) * 3;
          if (ByteVal and ($80 shr BitIdx)) = 0 then
          begin Pixels[Off]:=255; Pixels[Off+1]:=255; Pixels[Off+2]:=255; end;
          Inc(BitIdx); if BitIdx >= 8 then BitIdx := 0;
        end;
      end;

    5: { P5: Binary PGM }
      for Y := 0 to Height - 1 do
        for X := 0 to Width - 1 do
        begin
          if Pos >= SrcLen then Break;
          V := (Src[Pos] * 255) div MaxVal; Inc(Pos);
          Off := (Y * Width + X) * 3;
          Pixels[Off] := V; Pixels[Off+1] := V; Pixels[Off+2] := V;
        end;

    6: { P6: Binary PPM }
      for Y := 0 to Height - 1 do
        for X := 0 to Width - 1 do
        begin
          if Pos + 2 >= SrcLen then Break;
          Off := (Y * Width + X) * 3;
          Pixels[Off] := (Src[Pos] * 255) div MaxVal;
          Pixels[Off+1] := (Src[Pos+1] * 255) div MaxVal;
          Pixels[Off+2] := (Src[Pos+2] * 255) div MaxVal;
          Inc(Pos, 3);
        end;
  end;

  Result := True;
end;

function PBMDecodeFile(const FileName: ShortString;
  out Pixels: PByte; out Width, Height: LongInt): Boolean;
var F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False; Pixels := nil;
  Assign(F, FileName); {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  GetMem(Buf, FS); BlockRead(F, Buf^, FS, BR); Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := PBMDecodeMem(Buf, FS, Pixels, Width, Height);
  FreeMem(Buf);
end;

end.
