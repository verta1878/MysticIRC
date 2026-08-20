(* ripchnge.pas -- RIPscript Delta/Diff Patch Decoder
   Copyright (C) 2026 fpc264irc contributors.
   License: GPLv3

   Dirty rectangle tracking and delta patch encoding for efficient
   scene updates. After the initial full frame, only changed regions
   are transmitted as rectangular patches.

   Patch format: [X:2][Y:2][W:2][H:2][RLE pixel data]
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit ripchnge;

interface

const
  RIPD_MAX_PATCHES = 256;

type
  TRIPDirtyRect = record
    X, Y, W, H: Word;
  end;

  TRIPPatch = record
    X, Y, W, H: Word;
    Data: PByte;         { RGB, 3 bytes/pixel }
    DataSize: LongWord;
    Compressed: PByte;   { RLE compressed }
    CompSize: LongWord;
  end;

  TRIPDelta = record
    Width, Height: Word;
    PrevFrame: PByte;     { previous frame RGB buffer }
    CurrFrame: PByte;     { current frame RGB buffer }
    Patches: array[0..RIPD_MAX_PATCHES - 1] of TRIPPatch;
    NumPatches: Integer;
    DirtyRects: array[0..RIPD_MAX_PATCHES - 1] of TRIPDirtyRect;
    NumDirty: Integer;
  end;

{ Initialize delta tracker }
procedure RIPDeltaInit(var D: TRIPDelta; Width, Height: Word);

{ Mark a rectangle as dirty }
procedure RIPDeltaMarkDirty(var D: TRIPDelta; X, Y, W, H: Word);

{ Compare frames and auto-detect dirty regions }
procedure RIPDeltaCompare(var D: TRIPDelta; Threshold: Byte);

{ Generate patches from dirty regions }
procedure RIPDeltaGenPatches(var D: TRIPDelta);

{ Apply patches to a frame buffer }
procedure RIPDeltaApplyPatches(var D: TRIPDelta; DstPixels: PByte);

{ Swap current to previous (prepare for next frame) }
procedure RIPDeltaSwapFrames(var D: TRIPDelta);

{ Set current frame data }
procedure RIPDeltaSetFrame(var D: TRIPDelta; Pixels: PByte);

{ Save patches to file }
function RIPDeltaSavePatches(const FileName: ShortString;
  var D: TRIPDelta): Boolean;

{ Load patches from file }
function RIPDeltaLoadPatches(const FileName: ShortString;
  var D: TRIPDelta): Boolean;

{ Load from memory }
function RIPDeltaLoadPatchesMem(Src: PByte; SrcLen: LongInt;
  var D: TRIPDelta): Boolean;

procedure RIPDeltaFree(var D: TRIPDelta);
procedure RIPDeltaClearPatches(var D: TRIPDelta);

implementation

procedure RIPDeltaInit(var D: TRIPDelta; Width, Height: Word);
var
  BufSize: LongWord;
begin
  FillChar(D, SizeOf(D), 0);
  D.Width := Width;
  D.Height := Height;
  BufSize := LongWord(Width) * Height * 3;
  GetMem(D.PrevFrame, BufSize);
  GetMem(D.CurrFrame, BufSize);
  FillChar(D.PrevFrame^, BufSize, 0);
  FillChar(D.CurrFrame^, BufSize, 0);
end;

procedure RIPDeltaMarkDirty(var D: TRIPDelta; X, Y, W, H: Word);
begin
  if D.NumDirty >= RIPD_MAX_PATCHES then Exit;
  D.DirtyRects[D.NumDirty].X := X;
  D.DirtyRects[D.NumDirty].Y := Y;
  D.DirtyRects[D.NumDirty].W := W;
  D.DirtyRects[D.NumDirty].H := H;
  Inc(D.NumDirty);
end;

procedure RIPDeltaCompare(var D: TRIPDelta; Threshold: Byte);
var
  X, Y: Integer;
  Offset: LongInt;
  Diff: Integer;
  MinX, MinY, MaxX, MaxY: Integer;
  Found: Boolean;
begin
  D.NumDirty := 0;
  MinX := D.Width; MinY := D.Height;
  MaxX := 0; MaxY := 0;
  Found := False;

  { Scan for differences in 8x8 blocks }
  Y := 0;
  while Y < D.Height do
  begin
    X := 0;
    while X < D.Width do
    begin
      Offset := (LongInt(Y) * D.Width + X) * 3;
      Diff := Abs(Integer(D.CurrFrame[Offset]) - Integer(D.PrevFrame[Offset])) +
              Abs(Integer(D.CurrFrame[Offset+1]) - Integer(D.PrevFrame[Offset+1])) +
              Abs(Integer(D.CurrFrame[Offset+2]) - Integer(D.PrevFrame[Offset+2]));

      if Diff > Threshold then
      begin
        if X < MinX then MinX := X;
        if Y < MinY then MinY := Y;
        if X > MaxX then MaxX := X;
        if Y > MaxY then MaxY := Y;
        Found := True;
      end;

      Inc(X, 4); { sample every 4 pixels for speed }
    end;
    Inc(Y, 4);
  end;

  if Found then
  begin
    { Expand to cover full changed area with margin }
    if MinX > 0 then Dec(MinX, 4);
    if MinY > 0 then Dec(MinY, 4);
    Inc(MaxX, 8); Inc(MaxY, 8);
    if MaxX >= D.Width then MaxX := D.Width - 1;
    if MaxY >= D.Height then MaxY := D.Height - 1;

    RIPDeltaMarkDirty(D, MinX, MinY, MaxX - MinX + 1, MaxY - MinY + 1);
  end;
end;

procedure RIPDeltaGenPatches(var D: TRIPDelta);
var
  I, X, Y: Integer;
  R: ^TRIPDirtyRect;
  P: ^TRIPPatch;
  SrcOff, DstOff: LongInt;
begin
  RIPDeltaClearPatches(D);

  for I := 0 to D.NumDirty - 1 do
  begin
    if D.NumPatches >= RIPD_MAX_PATCHES then Break;
    R := @D.DirtyRects[I];
    P := @D.Patches[D.NumPatches];

    P^.X := R^.X; P^.Y := R^.Y;
    P^.W := R^.W; P^.H := R^.H;

    { Clip to frame }
    if P^.X + P^.W > D.Width then P^.W := D.Width - P^.X;
    if P^.Y + P^.H > D.Height then P^.H := D.Height - P^.Y;
    if (P^.W = 0) or (P^.H = 0) then Continue;

    P^.DataSize := LongWord(P^.W) * P^.H * 3;
    GetMem(P^.Data, P^.DataSize);

    { Extract patch pixels from current frame }
    for Y := 0 to P^.H - 1 do
    begin
      SrcOff := (LongInt(P^.Y + Y) * D.Width + P^.X) * 3;
      DstOff := LongInt(Y) * P^.W * 3;
      Move(D.CurrFrame[SrcOff], P^.Data[DstOff], P^.W * 3);
    end;

    Inc(D.NumPatches);
  end;
end;

procedure RIPDeltaApplyPatches(var D: TRIPDelta; DstPixels: PByte);
var
  I, Y: Integer;
  P: ^TRIPPatch;
  SrcOff, DstOff: LongInt;
begin
  for I := 0 to D.NumPatches - 1 do
  begin
    P := @D.Patches[I];
    if P^.Data = nil then Continue;
    for Y := 0 to P^.H - 1 do
    begin
      if P^.Y + Y >= D.Height then Break;
      SrcOff := LongInt(Y) * P^.W * 3;
      DstOff := (LongInt(P^.Y + Y) * D.Width + P^.X) * 3;
      Move(P^.Data[SrcOff], DstPixels[DstOff], P^.W * 3);
    end;
  end;
end;

procedure RIPDeltaSwapFrames(var D: TRIPDelta);
var
  Tmp: PByte;
begin
  Tmp := D.PrevFrame;
  D.PrevFrame := D.CurrFrame;
  D.CurrFrame := Tmp;
  D.NumDirty := 0;
end;

procedure RIPDeltaSetFrame(var D: TRIPDelta; Pixels: PByte);
begin
  Move(Pixels^, D.CurrFrame^, LongWord(D.Width) * D.Height * 3);
end;

function RIPDeltaSavePatches(const FileName: ShortString;
  var D: TRIPDelta): Boolean;
var
  F: File; Hdr: array[0..7] of Byte; I: Integer; PHdr: array[0..7] of Byte;
begin
  Result := False;
  Assign(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  Hdr[0] := Ord('R'); Hdr[1] := Ord('I'); Hdr[2] := Ord('P'); Hdr[3] := Ord('D');
  Hdr[4] := Lo(Word(D.NumPatches)); Hdr[5] := Hi(Word(D.NumPatches));
  Hdr[6] := Lo(D.Width); Hdr[7] := Hi(D.Width);
  BlockWrite(F, Hdr, 8);
  for I := 0 to D.NumPatches - 1 do
  begin
    PHdr[0] := Lo(D.Patches[I].X); PHdr[1] := Hi(D.Patches[I].X);
    PHdr[2] := Lo(D.Patches[I].Y); PHdr[3] := Hi(D.Patches[I].Y);
    PHdr[4] := Lo(D.Patches[I].W); PHdr[5] := Hi(D.Patches[I].W);
    PHdr[6] := Lo(D.Patches[I].H); PHdr[7] := Hi(D.Patches[I].H);
    BlockWrite(F, PHdr, 8);
    if D.Patches[I].DataSize > 0 then
      BlockWrite(F, D.Patches[I].Data^, D.Patches[I].DataSize);
  end;
  Close(F); Result := True;
end;

function RIPDeltaLoadPatchesMem(Src: PByte; SrcLen: LongInt;
  var D: TRIPDelta): Boolean;
var
  Pos: LongInt; I: Integer; NP: Word;
begin
  Result := False;
  RIPDeltaClearPatches(D);
  if SrcLen < 8 then Exit;
  if (Chr(Src[0]) <> 'R') or (Chr(Src[3]) <> 'D') then Exit;
  NP := Src[4] or (Word(Src[5]) shl 8);
  Pos := 8;
  for I := 0 to NP - 1 do
  begin
    if Pos + 8 > SrcLen then Break;
    D.Patches[I].X := Src[Pos] or (Word(Src[Pos+1]) shl 8); Inc(Pos, 2);
    D.Patches[I].Y := Src[Pos] or (Word(Src[Pos+1]) shl 8); Inc(Pos, 2);
    D.Patches[I].W := Src[Pos] or (Word(Src[Pos+1]) shl 8); Inc(Pos, 2);
    D.Patches[I].H := Src[Pos] or (Word(Src[Pos+1]) shl 8); Inc(Pos, 2);
    D.Patches[I].DataSize := LongWord(D.Patches[I].W) * D.Patches[I].H * 3;
    if Pos + LongInt(D.Patches[I].DataSize) > SrcLen then Break;
    GetMem(D.Patches[I].Data, D.Patches[I].DataSize);
    Move(Src[Pos], D.Patches[I].Data^, D.Patches[I].DataSize);
    Inc(Pos, D.Patches[I].DataSize);
    Inc(D.NumPatches);
  end;
  Result := D.NumPatches > 0;
end;

function RIPDeltaLoadPatches(const FileName: ShortString;
  var D: TRIPDelta): Boolean;
var F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False;
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  GetMem(Buf, FS);
  BlockRead(F, Buf^, FS, BR);
  Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := RIPDeltaLoadPatchesMem(Buf, FS, D);
  FreeMem(Buf);
end;

procedure RIPDeltaClearPatches(var D: TRIPDelta);
var I: Integer;
begin
  for I := 0 to RIPD_MAX_PATCHES - 1 do
  begin
    if D.Patches[I].Data <> nil then begin FreeMem(D.Patches[I].Data); D.Patches[I].Data := nil; end;
    if D.Patches[I].Compressed <> nil then begin FreeMem(D.Patches[I].Compressed); D.Patches[I].Compressed := nil; end;
  end;
  D.NumPatches := 0;
end;

procedure RIPDeltaFree(var D: TRIPDelta);
begin
  RIPDeltaClearPatches(D);
  if D.PrevFrame <> nil then begin FreeMem(D.PrevFrame); D.PrevFrame := nil; end;
  if D.CurrFrame <> nil then begin FreeMem(D.CurrFrame); D.CurrFrame := nil; end;
  D.NumDirty := 0;
end;

end.
