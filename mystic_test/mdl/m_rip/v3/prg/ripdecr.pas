(* ripdecr.pas -- RIPscript Stream Decoder (Incremental)
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Incremental RIPscript command parser for real-time BBS streaming.
   Feeds bytes one at a time; emits complete parsed commands as they
   arrive. Designed for telnet streams where data arrives in chunks.

   Supports:
     RIPscrip v1.54 command detection (! | prefix)
     MegaNum parameter decoding (base-36)
     Command boundaries (| terminator or next ! |)
     ANSI passthrough (non-RIP data forwarded separately)
     State machine: handles partial commands across chunk boundaries
     File loading (processes entire .RIP file)

   Usage:
     var Parser: TRIPStreamParser;
     begin
       RIPStreamInit(Parser, @MyCommandHandler, @MyTextHandler);
       // Feed bytes as they arrive from telnet:
       RIPStreamFeed(Parser, @TelnetBuf, BytesReceived);
       // Or load a file:
       RIPStreamLoadFile(Parser, 'scene.rip');
       RIPStreamDone(Parser);
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit ripdecr;

interface

const
  RIP_MAX_PARAMS = 32;
  RIP_MAX_CMD_LEN = 4096;
  RIP_MAX_TEXT = 255;

type
  { Parsed RIP command }
  TRIPCommand = record
    Level: Byte;           { 0 = Level 0, 1 = Level 1 }
    CommandChar: Char;     { single-char command code }
    ParamStr: ShortString; { raw parameter string (MegaNum encoded) }
    Params: array[0..RIP_MAX_PARAMS - 1] of LongInt; { decoded parameters }
    ParamCount: Integer;
    TextParam: ShortString; { text parameter (for OutText, DefineVar, etc.) }
    HasText: Boolean;
    RawLine: ShortString;  { original command line }
  end;

  { Callback types }
  TRIPCommandCallback = procedure(var Cmd: TRIPCommand; UserData: Pointer);
  TRIPTextCallback = procedure(const Text: ShortString; UserData: Pointer);

  { Parser state }
  TRIPParserState = (
    rpsNormal,      { outside RIP command, passing ANSI text }
    rpsGotBang,     { received '!' — might be start of RIP }
    rpsGotBar,      { received '!|' — inside RIP command }
    rpsLevel1,      { received '!|1' — Level 1 command prefix }
    rpsInCommand,   { accumulating command characters }
    rpsInText       { accumulating text parameter after command }
  );

  TRIPStreamParser = record
    State: TRIPParserState;
    CmdBuf: array[0..RIP_MAX_CMD_LEN - 1] of Char;
    CmdLen: Integer;
    TextBuf: ShortString;
    TextLen: Integer;
    Level: Byte;
    CommandChar: Char;
    OnCommand: TRIPCommandCallback;
    OnText: TRIPTextCallback;
    UserData: Pointer;
    { Stats }
    CommandCount: LongWord;
    TextBytes: LongWord;
    ErrorCount: LongWord;
  end;

{ Initialize parser }
procedure RIPStreamInit(var P: TRIPStreamParser;
  CmdCallback: TRIPCommandCallback;
  TextCallback: TRIPTextCallback;
  UserData: Pointer);

{ Feed raw bytes to parser (from telnet, file read, etc.) }
procedure RIPStreamFeed(var P: TRIPStreamParser; Data: PByte; Len: LongInt);

{ Feed a single byte }
procedure RIPStreamFeedByte(var P: TRIPStreamParser; B: Byte);

{ Load and process entire .RIP file }
function RIPStreamLoadFile(var P: TRIPStreamParser;
  const FileName: ShortString): Boolean;

{ Reset parser state (between scenes) }
procedure RIPStreamReset(var P: TRIPStreamParser);

{ Cleanup }
procedure RIPStreamDone(var P: TRIPStreamParser);

{ Decode a MegaNum value from RIP parameter string.
  MegaNum is base-36: 0-9 = 0-9, A-Z = 10-35.
  Returns decoded value. Advances Pos. }
function RIPDecodeMegaNum(const S: ShortString; var Pos: Integer;
  NumChars: Integer): LongInt;

{ Decode all MegaNum parameters from a command string }
function RIPDecodeParams(const ParamStr: ShortString;
  var Params: array of LongInt; CharsPerParam: Integer): Integer;

{ Parse a complete RIP command line into TRIPCommand }
procedure RIPParseCommandLine(const Line: ShortString; out Cmd: TRIPCommand);

implementation

function MegaDigit(C: Char): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'A'..'Z': Result := Ord(C) - Ord('A') + 10;
    'a'..'z': Result := Ord(C) - Ord('a') + 10;
  else
    Result := 0;
  end;
end;

function RIPDecodeMegaNum(const S: ShortString; var Pos: Integer;
  NumChars: Integer): LongInt;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to NumChars - 1 do
  begin
    if Pos > Length(S) then Exit;
    Result := Result * 36 + MegaDigit(S[Pos]);
    Inc(Pos);
  end;
end;

function RIPDecodeParams(const ParamStr: ShortString;
  var Params: array of LongInt; CharsPerParam: Integer): Integer;
var
  Pos, MaxParams: Integer;
begin
  Result := 0;
  Pos := 1;
  MaxParams := High(Params) + 1;
  while (Pos <= Length(ParamStr)) and (Result < MaxParams) do
  begin
    Params[Result] := RIPDecodeMegaNum(ParamStr, Pos, CharsPerParam);
    Inc(Result);
  end;
end;

procedure RIPParseCommandLine(const Line: ShortString; out Cmd: TRIPCommand);
var
  Pos: Integer;
  I: Integer;
  ParamStart: Integer;
  InText: Boolean;
begin
  FillChar(Cmd, SizeOf(Cmd), 0);
  Cmd.RawLine := Line;

  if Length(Line) < 1 then Exit;

  Pos := 1;

  { Check for Level 1 prefix }
  if (Length(Line) >= 2) and (Line[1] = '1') then
  begin
    Cmd.Level := 1;
    Inc(Pos);
  end;

  if Pos > Length(Line) then Exit;

  { Command character }
  Cmd.CommandChar := Line[Pos];
  Inc(Pos);

  { Remaining is parameters + possible text }
  if Pos <= Length(Line) then
  begin
    { Find text delimiter — for some commands, text follows after fixed params }
    { Commands with text: @ (OutTextXY), T (OutText), $ (DefineTextVar),
      1D (DefineVar), 1W (WriteIcon) }
    Cmd.ParamStr := '';
    ParamStart := Pos;

    { Most commands use 2-char MegaNum params }
    { Determine param count by command type }
    case Cmd.CommandChar of
      'c', 'e', 'E', '*': { 0 params }
        Cmd.ParamStr := '';
      'w', 'v', 'R', 'B', 'G', 'C': { 4-8 params, 2 chars each }
      begin
        Cmd.ParamStr := Copy(Line, Pos, Length(Line) - Pos + 1);
        Cmd.ParamCount := RIPDecodeParams(Cmd.ParamStr, Cmd.Params, 2);
      end;
      '@': { OutTextXY: x(2) y(2) then text }
      begin
        if Length(Line) >= Pos + 3 then
        begin
          Cmd.ParamStr := Copy(Line, Pos, 4);
          Cmd.ParamCount := RIPDecodeParams(Cmd.ParamStr, Cmd.Params, 2);
          if Pos + 4 <= Length(Line) then
          begin
            Cmd.TextParam := Copy(Line, Pos + 4, Length(Line) - Pos - 3);
            Cmd.HasText := True;
          end;
        end;
      end;
      'T': { OutText: just text }
      begin
        Cmd.TextParam := Copy(Line, Pos, Length(Line) - Pos + 1);
        Cmd.HasText := True;
      end;
      '$': { DefineTextVar: varnum(2) text }
      begin
        if Length(Line) >= Pos + 1 then
        begin
          Cmd.ParamStr := Copy(Line, Pos, 2);
          Cmd.ParamCount := RIPDecodeParams(Cmd.ParamStr, Cmd.Params, 2);
          if Pos + 2 <= Length(Line) then
          begin
            Cmd.TextParam := Copy(Line, Pos + 2, Length(Line) - Pos - 1);
            Cmd.HasText := True;
          end;
        end;
      end;
    else
      { Default: try 2-char MegaNum decode }
      Cmd.ParamStr := Copy(Line, Pos, Length(Line) - Pos + 1);
      Cmd.ParamCount := RIPDecodeParams(Cmd.ParamStr, Cmd.Params, 2);
    end;
  end;
end;

procedure FlushText(var P: TRIPStreamParser);
begin
  if P.TextLen > 0 then
  begin
    SetLength(P.TextBuf, P.TextLen);
    if Assigned(P.OnText) then
      P.OnText(P.TextBuf, P.UserData);
    Inc(P.TextBytes, P.TextLen);
    P.TextLen := 0;
  end;
end;

procedure EmitCommand(var P: TRIPStreamParser);
var
  Line: ShortString;
  Cmd: TRIPCommand;
  Len: Integer;
begin
  if P.CmdLen <= 0 then Exit;

  { Build command string from buffer }
  Len := P.CmdLen;
  if Len > 255 then Len := 255;
  SetLength(Line, Len);
  Move(P.CmdBuf[0], Line[1], Len);

  { Remove trailing | if present }
  if (Length(Line) > 0) and (Line[Length(Line)] = '|') then
    SetLength(Line, Length(Line) - 1);

  { Parse the command }
  RIPParseCommandLine(Line, Cmd);

  { Fire callback }
  if Assigned(P.OnCommand) then
    P.OnCommand(Cmd, P.UserData);

  Inc(P.CommandCount);
  P.CmdLen := 0;
end;

procedure RIPStreamInit(var P: TRIPStreamParser;
  CmdCallback: TRIPCommandCallback;
  TextCallback: TRIPTextCallback;
  UserData: Pointer);
begin
  FillChar(P, SizeOf(P), 0);
  P.OnCommand := CmdCallback;
  P.OnText := TextCallback;
  P.UserData := UserData;
  P.State := rpsNormal;
end;

procedure RIPStreamFeedByte(var P: TRIPStreamParser; B: Byte);
var
  C: Char;
begin
  C := Chr(B);

  case P.State of
    rpsNormal:
    begin
      if C = '!' then
        P.State := rpsGotBang
      else
      begin
        { Accumulate ANSI/text }
        if P.TextLen < 255 then
        begin
          Inc(P.TextLen);
          P.TextBuf[P.TextLen] := C;
        end
        else
        begin
          FlushText(P);
          P.TextLen := 1;
          P.TextBuf[1] := C;
        end;
      end;
    end;

    rpsGotBang:
    begin
      if C = '|' then
      begin
        { RIP command starting — flush any pending text }
        FlushText(P);
        P.State := rpsInCommand;
        P.CmdLen := 0;
        P.Level := 0;
      end
      else
      begin
        { False alarm — '!' was just text }
        if P.TextLen < 254 then
        begin
          Inc(P.TextLen);
          P.TextBuf[P.TextLen] := '!';
          Inc(P.TextLen);
          P.TextBuf[P.TextLen] := C;
        end;
        P.State := rpsNormal;
      end;
    end;

    rpsInCommand:
    begin
      if C = '|' then
      begin
        { End of command — check for next command or end }
        EmitCommand(P);
        P.State := rpsNormal;
      end
      else if (C = '!') and (P.CmdLen > 0) then
      begin
        { Possible new command starting — emit current first }
        EmitCommand(P);
        P.State := rpsGotBang;
      end
      else if (C = #13) or (C = #10) then
      begin
        { Line break ends RIP command }
        if P.CmdLen > 0 then
          EmitCommand(P);
        P.State := rpsNormal;
      end
      else
      begin
        { Accumulate command characters }
        if P.CmdLen < RIP_MAX_CMD_LEN then
        begin
          P.CmdBuf[P.CmdLen] := C;
          Inc(P.CmdLen);
        end;
      end;
    end;
  end;
end;

procedure RIPStreamFeed(var P: TRIPStreamParser; Data: PByte; Len: LongInt);
var
  I: LongInt;
begin
  for I := 0 to Len - 1 do
    RIPStreamFeedByte(P, Data[I]);
end;

function RIPStreamLoadFile(var P: TRIPStreamParser;
  const FileName: ShortString): Boolean;
var
  F: File;
  Buf: array[0..4095] of Byte;
  BytesRead: LongInt;
begin
  Result := False;
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;

  repeat
    BlockRead(F, Buf, SizeOf(Buf), BytesRead);
    if BytesRead > 0 then
      RIPStreamFeed(P, @Buf[0], BytesRead);
  until BytesRead = 0;

  { Flush any remaining command }
  if P.CmdLen > 0 then EmitCommand(P);
  FlushText(P);

  Close(F);
  Result := True;
end;

procedure RIPStreamReset(var P: TRIPStreamParser);
begin
  P.State := rpsNormal;
  P.CmdLen := 0;
  P.TextLen := 0;
end;

procedure RIPStreamDone(var P: TRIPStreamParser);
begin
  { Flush remaining }
  if P.CmdLen > 0 then EmitCommand(P);
  FlushText(P);
  P.State := rpsNormal;
end;

end.
