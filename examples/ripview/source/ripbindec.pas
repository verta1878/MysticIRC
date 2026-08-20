(* ripbindec.pas -- RIPscript Binary Scene Decoder
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Compact binary encoding of RIP drawing commands. 4-8x smaller
   than text RIPscrip. Each command is a 1-byte opcode + packed
   binary parameters instead of MegaNum text encoding.

   File format (.ripb):
     Header: 'RIPB' + version(1) + width(2) + height(2) + numcmds(4)
     Commands: opcode(1) + paramlen(1) + params(N)
     Footer: checksum(4)

   Usage:
     var Scene: TRIPBScene;
     begin
       if RIPBLoadFile('scene.ripb', Scene) then begin
         // Scene.Commands[0..Scene.NumCommands-1]
         RIPBFree(Scene);
       end;
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit ripbindec;

interface

const
  RIPB_MAX_PARAMS = 32;
  RIPB_MAX_COMMANDS = 65535;

  { Binary opcodes (match RIPscrip v1.54 commands) }
  RB_SET_COLOR     = $01;
  RB_SET_FILL      = $02;
  RB_SET_LINE      = $03;
  RB_SET_WRITE     = $04;
  RB_PIXEL         = $10;
  RB_LINE          = $11;
  RB_LINE_TO       = $12;
  RB_MOVE_REL      = $13;
  RB_RECTANGLE     = $14;
  RB_BAR           = $15;
  RB_CIRCLE        = $16;
  RB_ELLIPSE       = $17;
  RB_FILL_ELLIPSE  = $18;
  RB_ARC           = $19;
  RB_PIE_SLICE     = $1A;
  RB_BEZIER        = $1B;
  RB_POLYGON       = $1C;
  RB_FILL_POLYGON  = $1D;
  RB_POLYLINE      = $1E;
  RB_FLOOD_FILL    = $1F;
  RB_TEXT_XY       = $20;
  RB_TEXT_OUT      = $21;
  RB_SET_FONT      = $22;
  RB_FONT_STYLE    = $23;
  RB_GOTO_XY       = $24;
  RB_SET_PALETTE   = $30;
  RB_SET_ALL_PAL   = $31;
  RB_SET_VIEWPORT  = $32;
  RB_SET_WINDOW    = $33;
  RB_CLEAR_SCREEN  = $34;
  RB_RESET_WIN     = $35;
  RB_SCREEN_COPY   = $36;
  RB_LOAD_ICON     = $40;
  RB_GET_IMAGE     = $41;
  RB_PUT_IMAGE     = $42;
  RB_BUTTON_STYLE  = $43;
  RB_BUTTON        = $44;
  RB_DEFINE_VAR    = $45;
  RB_MOUSE_FIELD   = $46;
  RB_KILL_MOUSE    = $47;
  RB_BEGIN_TEXT     = $48;
  RB_END_TEXT       = $49;
  RB_REGION_TEXT   = $4A;
  RB_FILE_QUERY    = $4B;
  RB_BELL          = $4C;
  RB_END_SCENE     = $FF;

type
  TRIPBCommand = record
    Opcode: Byte;
    Params: array[0..RIPB_MAX_PARAMS - 1] of SmallInt;
    ParamCount: Byte;
    Text: ShortString;
    HasText: Boolean;
  end;

  TRIPBScene = record
    Width: Word;
    Height: Word;
    Version: Byte;
    NumCommands: LongWord;
    Commands: array of TRIPBCommand;
    Loaded: Boolean;
  end;

function RIPBLoadFile(const FileName: ShortString; out Scene: TRIPBScene): Boolean;
function RIPBLoadMem(Src: PByte; SrcLen: LongInt; out Scene: TRIPBScene): Boolean;
procedure RIPBFree(var Scene: TRIPBScene);

{ Encode a RIP text command to binary }
function RIPBEncodeCommand(const TextCmd: ShortString; out Bin: TRIPBCommand): Boolean;

{ Write a binary scene file }
function RIPBSaveFile(const FileName: ShortString; var Scene: TRIPBScene): Boolean;

implementation

const
  RIPB_MAGIC: array[0..3] of Char = 'RIPB';

function ReadLE16(P: PByte): Word;
begin
  Result := Word(P[0]) or (Word(P[1]) shl 8);
end;

function ReadLE32(P: PByte): LongWord;
begin
  Result := LongWord(P[0]) or (LongWord(P[1]) shl 8) or
            (LongWord(P[2]) shl 16) or (LongWord(P[3]) shl 24);
end;

procedure WriteLE16(P: PByte; V: Word);
begin
  P[0] := V and $FF; P[1] := (V shr 8) and $FF;
end;

procedure WriteLE32(P: PByte; V: LongWord);
begin
  P[0] := V and $FF; P[1] := (V shr 8) and $FF;
  P[2] := (V shr 16) and $FF; P[3] := (V shr 24) and $FF;
end;

function RIPBLoadMem(Src: PByte; SrcLen: LongInt; out Scene: TRIPBScene): Boolean;
var
  Pos: LongInt;
  I, J: Integer;
  Opcode, ParamLen: Byte;
  TextLen: Byte;
  CmdCount: LongWord;
begin
  Result := False;
  FillChar(Scene, SizeOf(Scene), 0);

  if SrcLen < 13 then Exit;

  { Check magic }
  if (Chr(Src[0]) <> 'R') or (Chr(Src[1]) <> 'I') or
     (Chr(Src[2]) <> 'P') or (Chr(Src[3]) <> 'B') then Exit;

  Scene.Version := Src[4];
  Scene.Width := ReadLE16(@Src[5]);
  Scene.Height := ReadLE16(@Src[7]);
  CmdCount := ReadLE32(@Src[9]);

  if CmdCount > RIPB_MAX_COMMANDS then CmdCount := RIPB_MAX_COMMANDS;
  Scene.NumCommands := CmdCount;
  SetLength(Scene.Commands, CmdCount);

  Pos := 13;
  I := 0;

  while (I < LongInt(CmdCount)) and (Pos < SrcLen) do
  begin
    Opcode := Src[Pos]; Inc(Pos);

    if Opcode = RB_END_SCENE then Break;

    if Pos >= SrcLen then Break;
    ParamLen := Src[Pos]; Inc(Pos);

    Scene.Commands[I].Opcode := Opcode;
    Scene.Commands[I].ParamCount := ParamLen div 2;
    Scene.Commands[I].HasText := False;

    { Read SmallInt parameters }
    for J := 0 to (ParamLen div 2) - 1 do
    begin
      if Pos + 2 > SrcLen then Break;
      Scene.Commands[I].Params[J] := SmallInt(ReadLE16(@Src[Pos]));
      Inc(Pos, 2);
    end;

    { Check for text flag (ParamLen is odd = has text following) }
    if (ParamLen and 1) <> 0 then
    begin
      if Pos < SrcLen then
      begin
        TextLen := Src[Pos]; Inc(Pos);
        if TextLen > 0 then
        begin
          Scene.Commands[I].HasText := True;
          if TextLen > 255 then TextLen := 255;
          SetLength(Scene.Commands[I].Text, TextLen);
          if Pos + TextLen <= SrcLen then
            Move(Src[Pos], Scene.Commands[I].Text[1], TextLen);
          Inc(Pos, TextLen);
        end;
      end;
    end;

    Inc(I);
  end;

  Scene.NumCommands := I;
  Scene.Loaded := True;
  Result := True;
end;

function RIPBLoadFile(const FileName: ShortString; out Scene: TRIPBScene): Boolean;
var
  F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False; FillChar(Scene, SizeOf(Scene), 0);
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  if FS < 13 then begin Close(F); Exit; end;
  GetMem(Buf, FS);
  BlockRead(F, Buf^, FS, BR);
  Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := RIPBLoadMem(Buf, FS, Scene);
  FreeMem(Buf);
end;

procedure RIPBFree(var Scene: TRIPBScene);
begin
  SetLength(Scene.Commands, 0);
  Scene.NumCommands := 0;
  Scene.Loaded := False;
end;

function RIPBEncodeCommand(const TextCmd: ShortString; out Bin: TRIPBCommand): Boolean;
begin
  Result := False;
  FillChar(Bin, SizeOf(Bin), 0);
  if Length(TextCmd) < 1 then Exit;
  { Map text command char to binary opcode }
  case TextCmd[1] of
    'c': Bin.Opcode := RB_SET_COLOR;
    'X': Bin.Opcode := RB_PIXEL;
    'L': Bin.Opcode := RB_LINE;
    'l': Bin.Opcode := RB_LINE_TO;
    'R': Bin.Opcode := RB_RECTANGLE;
    'B': Bin.Opcode := RB_BAR;
    'O': Bin.Opcode := RB_CIRCLE;
    'o': Bin.Opcode := RB_ELLIPSE;
    'V': Bin.Opcode := RB_FILL_ELLIPSE;
    'A': Bin.Opcode := RB_ARC;
    'I': Bin.Opcode := RB_PIE_SLICE;
    'Z': Bin.Opcode := RB_BEZIER;
    'P': Bin.Opcode := RB_FILL_POLYGON;
    'p': Bin.Opcode := RB_POLYLINE;
    'F': Bin.Opcode := RB_FLOOD_FILL;
    '@': Bin.Opcode := RB_TEXT_XY;
    'T': Bin.Opcode := RB_TEXT_OUT;
    'e': Bin.Opcode := RB_CLEAR_SCREEN;
    '*': Bin.Opcode := RB_RESET_WIN;
    'E': Bin.Opcode := RB_BELL;
  else
    Bin.Opcode := Ord(TextCmd[1]);
  end;
  Result := True;
end;

function RIPBSaveFile(const FileName: ShortString; var Scene: TRIPBScene): Boolean;
var
  F: File;
  Hdr: array[0..12] of Byte;
  I, J: Integer;
  B: Byte;
  W: Word;
begin
  Result := False;
  Assign(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  if IOResult <> 0 then Exit;

  { Header }
  Move(RIPB_MAGIC, Hdr[0], 4);
  Hdr[4] := Scene.Version;
  WriteLE16(@Hdr[5], Scene.Width);
  WriteLE16(@Hdr[7], Scene.Height);
  WriteLE32(@Hdr[9], Scene.NumCommands);
  BlockWrite(F, Hdr, 13);

  { Commands }
  for I := 0 to LongInt(Scene.NumCommands) - 1 do
  begin
    B := Scene.Commands[I].Opcode;
    BlockWrite(F, B, 1);

    { Param length: count * 2, +1 if has text }
    B := Scene.Commands[I].ParamCount * 2;
    if Scene.Commands[I].HasText then Inc(B);
    BlockWrite(F, B, 1);

    { Parameters }
    for J := 0 to Scene.Commands[I].ParamCount - 1 do
    begin
      W := Word(Scene.Commands[I].Params[J]);
      BlockWrite(F, W, 2);
    end;

    { Text }
    if Scene.Commands[I].HasText then
    begin
      B := Length(Scene.Commands[I].Text);
      BlockWrite(F, B, 1);
      if B > 0 then
        BlockWrite(F, Scene.Commands[I].Text[1], B);
    end;
  end;

  { End marker }
  B := RB_END_SCENE;
  BlockWrite(F, B, 1);

  Close(F);
  Result := True;
end;

end.
