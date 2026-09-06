(* mpgvbuf.pas -- MPEG Video Frame Buffer
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   YCbCr frame storage and YUV→RGB conversion.
   Manages reference frames for I/P/B prediction.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit mpgvbuf;

interface

const
  MPG_MAX_WIDTH = 1920;
  MPG_MAX_HEIGHT = 1088;

type
  TMPGPlane = record
    Data: PByte;
    Width, Height: Word;
    Stride: Word;
  end;

  TMPGFrame = record
    Y, Cb, Cr: TMPGPlane;    { YCbCr 4:2:0 }
    RGB: PByte;               { Converted RGB (3 bytes/pixel) }
    Width, Height: Word;
    PTS: Int64;
    FrameType: Byte;          { 1=I, 2=P, 3=B }
    Allocated: Boolean;
  end;

  TMPGFramePool = record
    Current: TMPGFrame;
    Forward_: TMPGFrame;      { forward reference for P/B }
    Backward: TMPGFrame;      { backward reference for B }
    Display: TMPGFrame;       { frame ready for display }
  end;

{ Allocate frame buffers }
procedure MPGFrameAlloc(var F: TMPGFrame; W, H: Word);
procedure MPGFrameFree(var F: TMPGFrame);

{ Initialize frame pool }
procedure MPGPoolInit(var Pool: TMPGFramePool; W, H: Word);
procedure MPGPoolFree(var Pool: TMPGFramePool);

{ Convert YCbCr 4:2:0 to RGB }
procedure MPGYUVtoRGB(var F: TMPGFrame);

{ Fast YUV to RGB for a single pixel }
procedure YUVPixelToRGB(Y, Cb, Cr: Integer; out R, G, B: Byte);

{ Copy frame }
procedure MPGFrameCopy(var Dst, Src: TMPGFrame);

{ Clear frame to black }
procedure MPGFrameClear(var F: TMPGFrame);

{ Swap frames (pointer swap, no copy) }
procedure MPGFrameSwap(var A, B: TMPGFrame);

implementation

procedure YUVPixelToRGB(Y, Cb, Cr: Integer; out R, G, B: Byte);
var
  RV, GV, BV: Integer;
begin
  { ITU-R BT.601 conversion:
    R = Y + 1.402 * (Cr - 128)
    G = Y - 0.344 * (Cb - 128) - 0.714 * (Cr - 128)
    B = Y + 1.772 * (Cb - 128)
    Using fixed point (x256): }
  Dec(Cb, 128);
  Dec(Cr, 128);

  RV := Y + ((359 * Cr) shr 8);
  GV := Y - ((88 * Cb + 183 * Cr) shr 8);
  BV := Y + ((454 * Cb) shr 8);

  if RV < 0 then RV := 0 else if RV > 255 then RV := 255;
  if GV < 0 then GV := 0 else if GV > 255 then GV := 255;
  if BV < 0 then BV := 0 else if BV > 255 then BV := 255;

  R := RV; G := GV; B := BV;
end;

procedure AllocPlane(var P: TMPGPlane; W, H: Word);
begin
  P.Width := W;
  P.Height := H;
  P.Stride := (W + 15) and $FFF0;  { align to 16 }
  GetMem(P.Data, LongInt(P.Stride) * H);
  FillChar(P.Data^, LongInt(P.Stride) * H, 0);
end;

procedure FreePlane(var P: TMPGPlane);
begin
  if P.Data <> nil then begin FreeMem(P.Data); P.Data := nil; end;
end;

procedure MPGFrameAlloc(var F: TMPGFrame; W, H: Word);
begin
  FillChar(F, SizeOf(F), 0);
  F.Width := W;
  F.Height := H;
  AllocPlane(F.Y, W, H);
  AllocPlane(F.Cb, W div 2, H div 2);
  AllocPlane(F.Cr, W div 2, H div 2);
  GetMem(F.RGB, LongInt(W) * H * 3);
  FillChar(F.RGB^, LongInt(W) * H * 3, 0);
  F.Allocated := True;
end;

procedure MPGFrameFree(var F: TMPGFrame);
begin
  FreePlane(F.Y);
  FreePlane(F.Cb);
  FreePlane(F.Cr);
  if F.RGB <> nil then begin FreeMem(F.RGB); F.RGB := nil; end;
  F.Allocated := False;
end;

procedure MPGPoolInit(var Pool: TMPGFramePool; W, H: Word);
begin
  FillChar(Pool, SizeOf(Pool), 0);
  MPGFrameAlloc(Pool.Current, W, H);
  MPGFrameAlloc(Pool.Forward_, W, H);
  MPGFrameAlloc(Pool.Backward, W, H);
  MPGFrameAlloc(Pool.Display, W, H);
end;

procedure MPGPoolFree(var Pool: TMPGFramePool);
begin
  MPGFrameFree(Pool.Current);
  MPGFrameFree(Pool.Forward_);
  MPGFrameFree(Pool.Backward);
  MPGFrameFree(Pool.Display);
end;

procedure MPGYUVtoRGB(var F: TMPGFrame);
var
  X, Y: Integer;
  YVal, CbVal, CrVal: Integer;
  R, G, B: Byte;
  Off: LongInt;
  CX, CY: Integer;
begin
  if F.RGB = nil then Exit;

  for Y := 0 to F.Height - 1 do
  begin
    CY := Y div 2;
    for X := 0 to F.Width - 1 do
    begin
      CX := X div 2;

      YVal := F.Y.Data[Y * F.Y.Stride + X];
      CbVal := F.Cb.Data[CY * F.Cb.Stride + CX];
      CrVal := F.Cr.Data[CY * F.Cr.Stride + CX];

      YUVPixelToRGB(YVal, CbVal, CrVal, R, G, B);

      Off := (LongInt(Y) * F.Width + X) * 3;
      F.RGB[Off] := R;
      F.RGB[Off + 1] := G;
      F.RGB[Off + 2] := B;
    end;
  end;
end;

procedure MPGFrameCopy(var Dst, Src: TMPGFrame);
begin
  if not Src.Allocated or not Dst.Allocated then Exit;
  Move(Src.Y.Data^, Dst.Y.Data^, LongInt(Src.Y.Stride) * Src.Y.Height);
  Move(Src.Cb.Data^, Dst.Cb.Data^, LongInt(Src.Cb.Stride) * Src.Cb.Height);
  Move(Src.Cr.Data^, Dst.Cr.Data^, LongInt(Src.Cr.Stride) * Src.Cr.Height);
  Dst.PTS := Src.PTS;
  Dst.FrameType := Src.FrameType;
end;

procedure MPGFrameClear(var F: TMPGFrame);
begin
  if F.Y.Data <> nil then FillChar(F.Y.Data^, LongInt(F.Y.Stride) * F.Y.Height, 16);
  if F.Cb.Data <> nil then FillChar(F.Cb.Data^, LongInt(F.Cb.Stride) * F.Cb.Height, 128);
  if F.Cr.Data <> nil then FillChar(F.Cr.Data^, LongInt(F.Cr.Stride) * F.Cr.Height, 128);
end;

procedure MPGFrameSwap(var A, B: TMPGFrame);
var
  Tmp: TMPGFrame;
begin
  Tmp := A; A := B; B := Tmp;
end;

end.
