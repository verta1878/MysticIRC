(* spranim.pas -- Sprite Animation Frame Streaming
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Manages sprite sheets and frame-based animation for the RIP
   renderer. Supports horizontal/vertical strip sheets, variable
   frame sizes, and playback timing.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit spranim;

interface

const
  SPR_MAX_FRAMES = 128;
  SPR_MAX_ANIMS = 16;

type
  TSpriteFrame = record
    X, Y: Word;           { source rect in sheet }
    Width, Height: Word;
    OriginX, OriginY: SmallInt; { hotspot offset }
  end;

  TSpriteAnim = record
    Name: ShortString;
    StartFrame: Word;
    EndFrame: Word;
    DelayMS: Word;
    Loop: Boolean;
  end;

  TSpriteSheet = record
    Pixels: PByte;         { full sheet RGB }
    SheetW, SheetH: Word;
    Frames: array[0..SPR_MAX_FRAMES - 1] of TSpriteFrame;
    NumFrames: Integer;
    Anims: array[0..SPR_MAX_ANIMS - 1] of TSpriteAnim;
    NumAnims: Integer;
  end;

  TSpritePlayer = record
    Sheet: ^TSpriteSheet;
    CurrentAnim: Integer;
    CurrentFrame: Integer;
    ElapsedMS: LongWord;
    Playing: Boolean;
  end;

{ Create sprite sheet from image }
procedure SpriteSheetInit(var S: TSpriteSheet;
  Pixels: PByte; SheetW, SheetH: Word);

{ Auto-slice into uniform grid }
procedure SpriteSheetSlice(var S: TSpriteSheet;
  FrameW, FrameH: Word; Cols, Rows: Integer);

{ Add a named animation }
function SpriteAnimAdd(var S: TSpriteSheet;
  const Name: ShortString;
  StartFrame, EndFrame: Word;
  DelayMS: Word; Loop: Boolean): Integer;

{ Player }
procedure SpritePlayerInit(var P: TSpritePlayer; var Sheet: TSpriteSheet);
procedure SpritePlayerPlay(var P: TSpritePlayer; AnimIdx: Integer);
procedure SpritePlayerTick(var P: TSpritePlayer; DeltaMS: LongWord);
function SpritePlayerFrame(var P: TSpritePlayer): Integer;

{ Blit current frame to destination buffer }
procedure SpritePlayerDraw(var P: TSpritePlayer;
  DstPixels: PByte; DstW, DstH: Word;
  DstX, DstY: SmallInt);

procedure SpriteSheetFree(var S: TSpriteSheet);

implementation

procedure SpriteSheetInit(var S: TSpriteSheet;
  Pixels: PByte; SheetW, SheetH: Word);
var
  Size: LongWord;
begin
  FillChar(S, SizeOf(S), 0);
  S.SheetW := SheetW; S.SheetH := SheetH;
  Size := LongWord(SheetW) * SheetH * 3;
  GetMem(S.Pixels, Size);
  Move(Pixels^, S.Pixels^, Size);
end;

procedure SpriteSheetSlice(var S: TSpriteSheet;
  FrameW, FrameH: Word; Cols, Rows: Integer);
var
  C, R: Integer;
begin
  S.NumFrames := 0;
  for R := 0 to Rows - 1 do
    for C := 0 to Cols - 1 do
    begin
      if S.NumFrames >= SPR_MAX_FRAMES then Exit;
      S.Frames[S.NumFrames].X := C * FrameW;
      S.Frames[S.NumFrames].Y := R * FrameH;
      S.Frames[S.NumFrames].Width := FrameW;
      S.Frames[S.NumFrames].Height := FrameH;
      S.Frames[S.NumFrames].OriginX := FrameW div 2;
      S.Frames[S.NumFrames].OriginY := FrameH div 2;
      Inc(S.NumFrames);
    end;
end;

function SpriteAnimAdd(var S: TSpriteSheet;
  const Name: ShortString;
  StartFrame, EndFrame: Word;
  DelayMS: Word; Loop: Boolean): Integer;
begin
  Result := -1;
  if S.NumAnims >= SPR_MAX_ANIMS then Exit;
  Result := S.NumAnims;
  S.Anims[Result].Name := Name;
  S.Anims[Result].StartFrame := StartFrame;
  S.Anims[Result].EndFrame := EndFrame;
  S.Anims[Result].DelayMS := DelayMS;
  S.Anims[Result].Loop := Loop;
  Inc(S.NumAnims);
end;

procedure SpritePlayerInit(var P: TSpritePlayer; var Sheet: TSpriteSheet);
begin
  FillChar(P, SizeOf(P), 0);
  P.Sheet := @Sheet;
end;

procedure SpritePlayerPlay(var P: TSpritePlayer; AnimIdx: Integer);
begin
  P.CurrentAnim := AnimIdx;
  P.CurrentFrame := P.Sheet^.Anims[AnimIdx].StartFrame;
  P.ElapsedMS := 0;
  P.Playing := True;
end;

procedure SpritePlayerTick(var P: TSpritePlayer; DeltaMS: LongWord);
var
  A: ^TSpriteAnim;
begin
  if not P.Playing then Exit;
  if (P.CurrentAnim < 0) or (P.CurrentAnim >= P.Sheet^.NumAnims) then Exit;
  A := @P.Sheet^.Anims[P.CurrentAnim];

  Inc(P.ElapsedMS, DeltaMS);
  if P.ElapsedMS >= A^.DelayMS then
  begin
    P.ElapsedMS := 0;
    Inc(P.CurrentFrame);
    if P.CurrentFrame > A^.EndFrame then
    begin
      if A^.Loop then
        P.CurrentFrame := A^.StartFrame
      else
      begin
        P.CurrentFrame := A^.EndFrame;
        P.Playing := False;
      end;
    end;
  end;
end;

function SpritePlayerFrame(var P: TSpritePlayer): Integer;
begin Result := P.CurrentFrame; end;

procedure SpritePlayerDraw(var P: TSpritePlayer;
  DstPixels: PByte; DstW, DstH: Word;
  DstX, DstY: SmallInt);
var
  Fr: ^TSpriteFrame;
  X, Y: Integer;
  SrcOff, DstOff: LongInt;
  DrawX, DrawY: SmallInt;
begin
  if (P.CurrentFrame < 0) or (P.CurrentFrame >= P.Sheet^.NumFrames) then Exit;
  Fr := @P.Sheet^.Frames[P.CurrentFrame];

  DrawX := DstX - Fr^.OriginX;
  DrawY := DstY - Fr^.OriginY;

  for Y := 0 to Fr^.Height - 1 do
  begin
    if DrawY + Y < 0 then Continue;
    if DrawY + Y >= DstH then Break;
    for X := 0 to Fr^.Width - 1 do
    begin
      if DrawX + X < 0 then Continue;
      if DrawX + X >= DstW then Break;
      SrcOff := (LongInt(Fr^.Y + Y) * P.Sheet^.SheetW + Fr^.X + X) * 3;
      DstOff := (LongInt(DrawY + Y) * DstW + DrawX + X) * 3;
      DstPixels[DstOff] := P.Sheet^.Pixels[SrcOff];
      DstPixels[DstOff + 1] := P.Sheet^.Pixels[SrcOff + 1];
      DstPixels[DstOff + 2] := P.Sheet^.Pixels[SrcOff + 2];
    end;
  end;
end;

procedure SpriteSheetFree(var S: TSpriteSheet);
begin
  if S.Pixels <> nil then begin FreeMem(S.Pixels); S.Pixels := nil; end;
  S.NumFrames := 0; S.NumAnims := 0;
end;

end.
