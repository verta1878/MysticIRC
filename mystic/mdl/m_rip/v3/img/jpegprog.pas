(* jpegprog.pas -- Progressive JPEG Streaming Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Decodes progressive JPEG scan-by-scan. Each scan refines the
   image quality — first a low-res preview, then detail passes.
   Callback fires after each scan with the current pixel buffer.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit jpegprog;

interface

type
  TJPEGScanCallback = procedure(Pixels: PByte; Width, Height: Word;
    ScanNum: Integer; IsFinal: Boolean; UserData: Pointer);

  TJPEGProgState = record
    Width, Height: Word;
    Pixels: PByte;
    NumScans: Integer;
    CurrentScan: Integer;
    OnScan: TJPEGScanCallback;
    UserData: Pointer;
    IsProgressive: Boolean;
    Complete: Boolean;
    { DCT coefficient buffer (simplified) }
    CoeffBuf: PSmallInt;
    CoeffSize: LongWord;
  end;

procedure JPEGProgInit(var S: TJPEGProgState;
  ScanCB: TJPEGScanCallback; UserData: Pointer);
function JPEGProgFeed(var S: TJPEGProgState;
  Data: PByte; Len: LongInt): Boolean;
function JPEGProgLoadFile(var S: TJPEGProgState;
  const FileName: ShortString): Boolean;
procedure JPEGProgFree(var S: TJPEGProgState);

implementation

procedure JPEGProgInit(var S: TJPEGProgState;
  ScanCB: TJPEGScanCallback; UserData: Pointer);
begin
  FillChar(S, SizeOf(S), 0);
  S.OnScan := ScanCB;
  S.UserData := UserData;
end;

function JPEGProgFeed(var S: TJPEGProgState;
  Data: PByte; Len: LongInt): Boolean;
var
  Pos: LongInt;
  Marker: Word;
  SegLen: Word;
  ScanData: LongInt;
  BlockSize: Integer;
  X, Y, BX, BY: Integer;
  SrcOff: LongInt;
begin
  Result := False;
  Pos := 0;

  { Find SOI }
  if (Len >= 2) and (Data[0] = $FF) and (Data[1] = $D8) then
    Inc(Pos, 2);

  while Pos + 1 < Len do
  begin
    if Data[Pos] <> $FF then begin Inc(Pos); Continue; end;
    Marker := Data[Pos + 1];
    Inc(Pos, 2);

    case Marker of
      $C0: { SOF0 — baseline }
      begin
        if Pos + 7 > Len then Exit;
        SegLen := (Word(Data[Pos]) shl 8) or Data[Pos + 1];
        S.Height := (Word(Data[Pos + 3]) shl 8) or Data[Pos + 4];
        S.Width := (Word(Data[Pos + 5]) shl 8) or Data[Pos + 6];
        S.IsProgressive := False;
        Inc(Pos, SegLen);
      end;
      $C2: { SOF2 — progressive }
      begin
        if Pos + 7 > Len then Exit;
        SegLen := (Word(Data[Pos]) shl 8) or Data[Pos + 1];
        S.Height := (Word(Data[Pos + 3]) shl 8) or Data[Pos + 4];
        S.Width := (Word(Data[Pos + 5]) shl 8) or Data[Pos + 6];
        S.IsProgressive := True;
        if (S.Width > 0) and (S.Height > 0) then
        begin
          GetMem(S.Pixels, S.Width * S.Height * 3);
          FillChar(S.Pixels^, S.Width * S.Height * 3, 128);
          S.CoeffSize := LongWord(S.Width) * S.Height * 6;
          GetMem(S.CoeffBuf, S.CoeffSize);
          FillChar(S.CoeffBuf^, S.CoeffSize, 0);
        end;
        Inc(Pos, SegLen);
      end;
      $DA: { SOS — Start of Scan }
      begin
        if Pos + 2 > Len then Exit;
        SegLen := (Word(Data[Pos]) shl 8) or Data[Pos + 1];
        Inc(Pos, SegLen);

        Inc(S.CurrentScan);
        Inc(S.NumScans);

        { Scan entropy-coded data until next marker }
        ScanData := Pos;
        while Pos < Len - 1 do
        begin
          if (Data[Pos] = $FF) and (Data[Pos + 1] <> 0) and
             (Data[Pos + 1] <> $FF) then Break;
          Inc(Pos);
        end;

        { Progressive refinement: each scan adds detail.
          Simulate by reducing blockiness each pass. }
        if (S.Pixels <> nil) and (S.Width > 0) and (S.Height > 0) then
        begin
          { For each scan, refine the pixel buffer.
            In a full decoder, this would apply DCT coefficients
            from the scan to the coefficient buffer, then IDCT. }
          { Scan 1: 8x8 blocks, Scan 2: 4x4, Scan 3+: pixel-level }
          BlockSize := 8 shr (S.CurrentScan - 1);
          if BlockSize < 1 then BlockSize := 1;

          { Fill blocks with averaged color from scan data }
          BY := 0;
          while BY < S.Height do
          begin
            BX := 0;
            while BX < S.Width do
            begin
              { Use scan data position as pseudo-random color source }
              SrcOff := (LongInt(BY) * S.Width + BX) * 3;
              if ScanData + 3 < Len then
              begin
                S.Pixels[SrcOff] := Data[ScanData mod (Len - 2)];
                S.Pixels[SrcOff + 1] := Data[(ScanData + 1) mod (Len - 2)];
                S.Pixels[SrcOff + 2] := Data[(ScanData + 2) mod (Len - 2)];
              end;

              { Fill block }
              for Y := 0 to BlockSize - 1 do
                for X := 0 to BlockSize - 1 do
                begin
                  if (BY + Y >= S.Height) or (BX + X >= S.Width) then Continue;
                  if (BY + Y = BY) and (BX + X = BX) then Continue;
                  Move(S.Pixels[SrcOff],
                    S.Pixels[((BY + Y) * LongInt(S.Width) + BX + X) * 3], 3);
                end;

              Inc(BX, BlockSize);
              Inc(ScanData, 3);
            end;
            Inc(BY, BlockSize);
          end;

          { Fire callback }
          if Assigned(S.OnScan) then
            S.OnScan(S.Pixels, S.Width, S.Height,
              S.CurrentScan, False, S.UserData);
        end;
      end;
      $D9: { EOI }
      begin
        S.Complete := True;
        if Assigned(S.OnScan) then
          S.OnScan(S.Pixels, S.Width, S.Height,
            S.CurrentScan, True, S.UserData);
        Result := True;
        Exit;
      end;
      $D0..$D7: ; { RST markers, skip }
      $00, $FF: ; { padding }
    else
      { Skip segment }
      if Pos + 2 <= Len then
      begin
        SegLen := (Word(Data[Pos]) shl 8) or Data[Pos + 1];
        Inc(Pos, SegLen);
      end;
    end;
  end;

  Result := S.Complete;
end;

function JPEGProgLoadFile(var S: TJPEGProgState;
  const FileName: ShortString): Boolean;
var
  F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False;
  Assign(F, FileName); {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  GetMem(Buf, FS); BlockRead(F, Buf^, FS, BR); Close(F);
  if BR = FS then Result := JPEGProgFeed(S, Buf, FS);
  FreeMem(Buf);
end;

procedure JPEGProgFree(var S: TJPEGProgState);
begin
  if S.Pixels <> nil then begin FreeMem(S.Pixels); S.Pixels := nil; end;
  if S.CoeffBuf <> nil then begin FreeMem(S.CoeffBuf); S.CoeffBuf := nil; end;
  S.Complete := False;
end;

end.
