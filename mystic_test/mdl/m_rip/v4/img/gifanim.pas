(* gifanim.pas -- Animated GIF Frame-by-Frame Playback
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Plays animated GIFs frame-by-frame with timing control.
   Manages frame disposal, transparency, and delay timing.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit gifanim;

interface

const
  GIFA_MAX_FRAMES = 256;

type
  TGIFDisposal = (gdNone, gdLeave, gdBackground, gdPrevious);

  TGIFAnimFrame = record
    Pixels: PByte;         { RGB, 3 bytes/pixel }
    Left, Top: Word;
    Width, Height: Word;
    DelayMS: Word;
    Disposal: TGIFDisposal;
    Transparent: Boolean;
    TransColor: Byte;
  end;

  TGIFFrameCallback = procedure(Canvas: PByte; Width, Height: Word;
    FrameNum: Integer; DelayMS: Word; UserData: Pointer);

  TGIFAnimPlayer = record
    Canvas: PByte;          { composited output, W*H*3 }
    Background: PByte;      { saved background for disposal }
    Width, Height: Word;
    Frames: array[0..GIFA_MAX_FRAMES - 1] of TGIFAnimFrame;
    NumFrames: Integer;
    CurrentFrame: Integer;
    LoopCount: Integer;     { 0 = infinite }
    CurrentLoop: Integer;
    Playing: Boolean;
    OnFrame: TGIFFrameCallback;
    UserData: Pointer;
    ElapsedMS: LongWord;
    FrameTimeMS: LongWord;
  end;

procedure GIFAnimInit(var P: TGIFAnimPlayer; Width, Height: Word;
  FrameCB: TGIFFrameCallback; UserData: Pointer);
function GIFAnimAddFrame(var P: TGIFAnimPlayer;
  Pixels: PByte; Left, Top, W, H: Word;
  DelayMS: Word; Disposal: TGIFDisposal): Integer;
procedure GIFAnimPlay(var P: TGIFAnimPlayer);
procedure GIFAnimStop(var P: TGIFAnimPlayer);
{ Call with elapsed milliseconds since last tick }
procedure GIFAnimTick(var P: TGIFAnimPlayer; DeltaMS: LongWord);
{ Render specific frame to canvas }
procedure GIFAnimRenderFrame(var P: TGIFAnimPlayer; FrameNum: Integer);
{ Get current canvas }
function GIFAnimGetCanvas(var P: TGIFAnimPlayer): PByte;
procedure GIFAnimFree(var P: TGIFAnimPlayer);

implementation

procedure GIFAnimInit(var P: TGIFAnimPlayer; Width, Height: Word;
  FrameCB: TGIFFrameCallback; UserData: Pointer);
var
  BufSize: LongWord;
begin
  FillChar(P, SizeOf(P), 0);
  P.Width := Width; P.Height := Height;
  P.OnFrame := FrameCB; P.UserData := UserData;
  BufSize := LongWord(Width) * Height * 3;
  GetMem(P.Canvas, BufSize); FillChar(P.Canvas^, BufSize, 0);
  GetMem(P.Background, BufSize); FillChar(P.Background^, BufSize, 0);
end;

function GIFAnimAddFrame(var P: TGIFAnimPlayer;
  Pixels: PByte; Left, Top, W, H: Word;
  DelayMS: Word; Disposal: TGIFDisposal): Integer;
var
  Size: LongWord;
begin
  Result := -1;
  if P.NumFrames >= GIFA_MAX_FRAMES then Exit;
  Result := P.NumFrames;
  P.Frames[Result].Left := Left; P.Frames[Result].Top := Top;
  P.Frames[Result].Width := W; P.Frames[Result].Height := H;
  P.Frames[Result].DelayMS := DelayMS;
  if DelayMS = 0 then P.Frames[Result].DelayMS := 100;
  P.Frames[Result].Disposal := Disposal;
  Size := LongWord(W) * H * 3;
  GetMem(P.Frames[Result].Pixels, Size);
  Move(Pixels^, P.Frames[Result].Pixels^, Size);
  Inc(P.NumFrames);
end;

procedure GIFAnimRenderFrame(var P: TGIFAnimPlayer; FrameNum: Integer);
var
  Fr: ^TGIFAnimFrame;
  X, Y: Integer;
  SrcOff, DstOff: LongInt;
  BufSize: LongWord;
begin
  if (FrameNum < 0) or (FrameNum >= P.NumFrames) then Exit;
  Fr := @P.Frames[FrameNum];

  { Handle disposal of previous frame }
  if FrameNum > 0 then
  begin
    case P.Frames[FrameNum - 1].Disposal of
      gdBackground:
      begin
        BufSize := LongWord(P.Width) * P.Height * 3;
        FillChar(P.Canvas^, BufSize, 0);
      end;
      gdPrevious:
      begin
        BufSize := LongWord(P.Width) * P.Height * 3;
        Move(P.Background^, P.Canvas^, BufSize);
      end;
    end;
  end;

  { Save background before rendering }
  if Fr^.Disposal = gdPrevious then
  begin
    BufSize := LongWord(P.Width) * P.Height * 3;
    Move(P.Canvas^, P.Background^, BufSize);
  end;

  { Composite frame onto canvas }
  for Y := 0 to Fr^.Height - 1 do
  begin
    if Fr^.Top + Y >= P.Height then Break;
    for X := 0 to Fr^.Width - 1 do
    begin
      if Fr^.Left + X >= P.Width then Break;
      SrcOff := (LongInt(Y) * Fr^.Width + X) * 3;
      DstOff := (LongInt(Fr^.Top + Y) * P.Width + Fr^.Left + X) * 3;
      P.Canvas[DstOff] := Fr^.Pixels[SrcOff];
      P.Canvas[DstOff + 1] := Fr^.Pixels[SrcOff + 1];
      P.Canvas[DstOff + 2] := Fr^.Pixels[SrcOff + 2];
    end;
  end;

  P.CurrentFrame := FrameNum;
end;

procedure GIFAnimPlay(var P: TGIFAnimPlayer);
begin
  P.Playing := True;
  P.CurrentFrame := 0;
  P.CurrentLoop := 0;
  P.ElapsedMS := 0;
  P.FrameTimeMS := 0;
  GIFAnimRenderFrame(P, 0);
  if Assigned(P.OnFrame) then
    P.OnFrame(P.Canvas, P.Width, P.Height, 0,
      P.Frames[0].DelayMS, P.UserData);
end;

procedure GIFAnimStop(var P: TGIFAnimPlayer);
begin P.Playing := False; end;

procedure GIFAnimTick(var P: TGIFAnimPlayer; DeltaMS: LongWord);
var
  NextFrame: Integer;
begin
  if not P.Playing then Exit;
  if P.NumFrames = 0 then Exit;

  Inc(P.FrameTimeMS, DeltaMS);

  if P.FrameTimeMS >= P.Frames[P.CurrentFrame].DelayMS then
  begin
    P.FrameTimeMS := 0;
    NextFrame := P.CurrentFrame + 1;

    if NextFrame >= P.NumFrames then
    begin
      Inc(P.CurrentLoop);
      if (P.LoopCount > 0) and (P.CurrentLoop >= P.LoopCount) then
      begin
        P.Playing := False;
        Exit;
      end;
      NextFrame := 0;
    end;

    GIFAnimRenderFrame(P, NextFrame);
    if Assigned(P.OnFrame) then
      P.OnFrame(P.Canvas, P.Width, P.Height, NextFrame,
        P.Frames[NextFrame].DelayMS, P.UserData);
  end;
end;

function GIFAnimGetCanvas(var P: TGIFAnimPlayer): PByte;
begin Result := P.Canvas; end;

procedure GIFAnimFree(var P: TGIFAnimPlayer);
var I: Integer;
begin
  for I := 0 to GIFA_MAX_FRAMES - 1 do
    if P.Frames[I].Pixels <> nil then
    begin FreeMem(P.Frames[I].Pixels); P.Frames[I].Pixels := nil; end;
  if P.Canvas <> nil then begin FreeMem(P.Canvas); P.Canvas := nil; end;
  if P.Background <> nil then begin FreeMem(P.Background); P.Background := nil; end;
  P.NumFrames := 0;
end;

end.
