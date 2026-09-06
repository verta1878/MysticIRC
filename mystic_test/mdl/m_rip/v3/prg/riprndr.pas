(* riprndr.pas -- RIP Scene Progressive Renderer
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Integrates R1-R5 + Phase 23 into a unified progressive renderer.
   Processes RIP commands and renders to a pixel buffer with
   callback after each command for real-time display updates.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit riprndr;

interface

uses ripdecr;

type
  TRIPRenderCallback = procedure(Pixels: PByte; Width, Height: Word;
    CmdNum: Integer; DirtyX, DirtyY, DirtyW, DirtyH: Word;
    UserData: Pointer);

  TRIPRenderer = record
    Width, Height: Word;
    Pixels: PByte;            { RGB framebuffer }
    CurrentColor: Byte;
    CurrentX, CurrentY: Word;
    Parser: TRIPStreamParser;
    OnRender: TRIPRenderCallback;
    UserData: Pointer;
    CmdCount: LongWord;
    Palette: array[0..15, 0..2] of Byte;
  end;

procedure RIPRenderInit(var R: TRIPRenderer; Width, Height: Word;
  RenderCB: TRIPRenderCallback; UserData: Pointer);
procedure RIPRenderFeed(var R: TRIPRenderer; Data: PByte; Len: LongInt);
function RIPRenderLoadFile(var R: TRIPRenderer;
  const FileName: ShortString): Boolean;
procedure RIPRenderClear(var R: TRIPRenderer);
function RIPRenderGetPixels(var R: TRIPRenderer): PByte;
procedure RIPRenderFree(var R: TRIPRenderer);

implementation

{ Default EGA palette }
const
  EGAPal: array[0..15, 0..2] of Byte = (
    (0,0,0), (0,0,170), (0,170,0), (0,170,170),
    (170,0,0), (170,0,170), (170,85,0), (170,170,170),
    (85,85,85), (85,85,255), (85,255,85), (85,255,255),
    (255,85,85), (255,85,255), (255,255,85), (255,255,255)
  );

procedure SetPixel(var R: TRIPRenderer; X, Y: Word; ColorIdx: Byte);
var
  Off: LongInt;
begin
  if (X >= R.Width) or (Y >= R.Height) then Exit;
  Off := (LongInt(Y) * R.Width + X) * 3;
  R.Pixels[Off] := R.Palette[ColorIdx and 15, 0];
  R.Pixels[Off + 1] := R.Palette[ColorIdx and 15, 1];
  R.Pixels[Off + 2] := R.Palette[ColorIdx and 15, 2];
end;

procedure DrawLine(var R: TRIPRenderer; X1, Y1, X2, Y2: SmallInt; Color: Byte);
var
  DX, DY, Steps, I: Integer;
  XF, YF, XI, YI: Integer;
begin
  DX := Abs(X2 - X1); DY := Abs(Y2 - Y1);
  if DX > DY then Steps := DX else Steps := DY;
  if Steps = 0 then begin SetPixel(R, X1, Y1, Color); Exit; end;
  XI := ((X2 - X1) shl 8) div Steps;
  YI := ((Y2 - Y1) shl 8) div Steps;
  XF := X1 shl 8; YF := Y1 shl 8;
  for I := 0 to Steps do
  begin
    SetPixel(R, XF shr 8, YF shr 8, Color);
    Inc(XF, XI); Inc(YF, YI);
  end;
end;

procedure DrawBar(var R: TRIPRenderer; X1, Y1, X2, Y2: SmallInt; Color: Byte);
var X, Y: SmallInt;
begin
  if X1 > X2 then begin X := X1; X1 := X2; X2 := X; end;
  if Y1 > Y2 then begin Y := Y1; Y1 := Y2; Y2 := Y; end;
  for Y := Y1 to Y2 do
    for X := X1 to X2 do
      SetPixel(R, X, Y, Color);
end;

procedure HandleCommand(var Cmd: TRIPCommand; UserData: Pointer);
var
  R: ^TRIPRenderer;
  DX, DY, DW, DH: Word;
begin
  R := UserData;
  Inc(R^.CmdCount);
  DX := 0; DY := 0; DW := R^.Width; DH := R^.Height;

  case Cmd.CommandChar of
    'c': { set color }
      if Cmd.ParamCount >= 1 then
        R^.CurrentColor := Cmd.Params[0] and 15;
    'X': { pixel }
      if Cmd.ParamCount >= 2 then
      begin
        SetPixel(R^, Cmd.Params[0], Cmd.Params[1], R^.CurrentColor);
        DX := Cmd.Params[0]; DY := Cmd.Params[1]; DW := 1; DH := 1;
      end;
    'L': { line }
      if Cmd.ParamCount >= 4 then
      begin
        DrawLine(R^, Cmd.Params[0], Cmd.Params[1],
          Cmd.Params[2], Cmd.Params[3], R^.CurrentColor);
        DX := Cmd.Params[0]; DY := Cmd.Params[1];
      end;
    'R': { rectangle }
      if Cmd.ParamCount >= 4 then
      begin
        DrawLine(R^, Cmd.Params[0], Cmd.Params[1], Cmd.Params[2], Cmd.Params[1], R^.CurrentColor);
        DrawLine(R^, Cmd.Params[2], Cmd.Params[1], Cmd.Params[2], Cmd.Params[3], R^.CurrentColor);
        DrawLine(R^, Cmd.Params[2], Cmd.Params[3], Cmd.Params[0], Cmd.Params[3], R^.CurrentColor);
        DrawLine(R^, Cmd.Params[0], Cmd.Params[3], Cmd.Params[0], Cmd.Params[1], R^.CurrentColor);
      end;
    'B': { bar (filled rectangle) }
      if Cmd.ParamCount >= 4 then
        DrawBar(R^, Cmd.Params[0], Cmd.Params[1],
          Cmd.Params[2], Cmd.Params[3], R^.CurrentColor);
    'e': { clear screen }
      FillChar(R^.Pixels^, LongWord(R^.Width) * R^.Height * 3, 0);
  end;

  if Assigned(R^.OnRender) then
    R^.OnRender(R^.Pixels, R^.Width, R^.Height,
      R^.CmdCount, DX, DY, DW, DH, R^.UserData);
end;

procedure HandleText(const Text: ShortString; UserData: Pointer);
begin
  { ANSI text passthrough — would feed to terminal emulator }
end;

procedure RIPRenderInit(var R: TRIPRenderer; Width, Height: Word;
  RenderCB: TRIPRenderCallback; UserData: Pointer);
begin
  FillChar(R, SizeOf(R), 0);
  R.Width := Width; R.Height := Height;
  R.OnRender := RenderCB; R.UserData := UserData;
  GetMem(R.Pixels, LongWord(Width) * Height * 3);
  FillChar(R.Pixels^, LongWord(Width) * Height * 3, 0);
  Move(EGAPal, R.Palette, SizeOf(EGAPal));
  RIPStreamInit(R.Parser, @HandleCommand, @HandleText, @R);
end;

procedure RIPRenderFeed(var R: TRIPRenderer; Data: PByte; Len: LongInt);
begin
  RIPStreamFeed(R.Parser, Data, Len);
end;

function RIPRenderLoadFile(var R: TRIPRenderer;
  const FileName: ShortString): Boolean;
begin
  Result := RIPStreamLoadFile(R.Parser, FileName);
end;

procedure RIPRenderClear(var R: TRIPRenderer);
begin
  FillChar(R.Pixels^, LongWord(R.Width) * R.Height * 3, 0);
  R.CmdCount := 0;
  RIPStreamReset(R.Parser);
end;

function RIPRenderGetPixels(var R: TRIPRenderer): PByte;
begin Result := R.Pixels; end;

procedure RIPRenderFree(var R: TRIPRenderer);
begin
  RIPStreamDone(R.Parser);
  if R.Pixels <> nil then begin FreeMem(R.Pixels); R.Pixels := nil; end;
end;

end.
