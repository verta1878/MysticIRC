{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  GPLv3 — clean-room reimplementation with Peter Rocca's permission.
  =========================================================================== }

unit OL_ANSI;
{ ===========================================================================
  OpenOLMS — ANSI console output for DOS doors
  ---------------------------------------------------------------------------
  Pure ANSI escape sequence output. No FV, no framework. Works over
  a COM port (remote BBS caller) or local console.

  The BBS has already set up the COM port and told us via the drop file
  whether the user supports ANSI. We write escape sequences and the
  terminal (or local Crt unit) renders them.

  This is how every classic DOS door works: ANSI art, escape codes,
  direct character output. The underground way.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

const
  { ANSI color codes }
  acBlack   = 0;  acRed      = 1;  acGreen   = 2;  acYellow  = 3;
  acBlue    = 4;  acMagenta  = 5;  acCyan    = 6;  acWhite   = 7;
  acBright  = 8;  { add to foreground for bright/bold }

  ESC = #27;

{ Basic output }
procedure ANSIWrite(const S: String);
procedure ANSIWriteLn(const S: String);

{ Color control }
procedure ANSIColor(FG, BG: Byte);
procedure ANSIBold;
procedure ANSIReset;

{ Cursor control }
procedure ANSICls;
procedure ANSIGotoXY(X, Y: Integer);
procedure ANSICursorUp(N: Integer);
procedure ANSICursorDown(N: Integer);

{ Box drawing (single-line) }
procedure ANSIBox(X1, Y1, X2, Y2: Integer; FG, BG: Byte);
procedure ANSIHLine(X, Y, Len: Integer; Ch: Char);

{ Formatted output }
procedure ANSIHeader(const Title: String);
procedure ANSIMenuItem(Key: Char; const Description: String);
procedure ANSIStatusBar(const Text: String);
procedure ANSIPrompt(const Text: String);
procedure ANSIError(const Text: String);
procedure ANSIInfo(const Text: String);

{ Input }
function ANSIReadKey: Char;
function ANSIReadLn(MaxLen: Integer): String;
function ANSIYesNo(const Prompt: String; Default: Boolean): Boolean;

{ Pause }
procedure ANSIPause;

implementation

{ no Crt on go32v2 cross — use raw console I/O }

procedure ANSIWrite(const S: String);
begin
  Write(S);
end;

procedure ANSIWriteLn(const S: String);
begin
  WriteLn(S);
end;

procedure ANSIColor(FG, BG: Byte);
var
  Bold: Boolean;
  ActualFG: Byte;
begin
  Bold := (FG and acBright) <> 0;
  ActualFG := FG and $07;
  if Bold then
    Write(ESC, '[1;3', ActualFG, ';4', BG, 'm')
  else
    Write(ESC, '[0;3', ActualFG, ';4', BG, 'm');
end;

procedure ANSIBold;
begin
  Write(ESC, '[1m');
end;

procedure ANSIReset;
begin
  Write(ESC, '[0m');
end;

procedure ANSICls;
begin
  Write(ESC, '[2J', ESC, '[1;1H');
end;

procedure ANSIGotoXY(X, Y: Integer);
begin
  Write(ESC, '[', Y, ';', X, 'H');
end;

procedure ANSICursorUp(N: Integer);
begin
  if N > 0 then Write(ESC, '[', N, 'A');
end;

procedure ANSICursorDown(N: Integer);
begin
  if N > 0 then Write(ESC, '[', N, 'B');
end;

procedure ANSIBox(X1, Y1, X2, Y2: Integer; FG, BG: Byte);
var Y: Integer;
begin
  ANSIColor(FG, BG);
  ANSIGotoXY(X1, Y1);
  Write(#218); ANSIHLine(X1 + 1, Y1, X2 - X1 - 1, #196); Write(#191);
  for Y := Y1 + 1 to Y2 - 1 do
  begin
    ANSIGotoXY(X1, Y);
    Write(#179);
    ANSIGotoXY(X2, Y);
    Write(#179);
  end;
  ANSIGotoXY(X1, Y2);
  Write(#192); ANSIHLine(X1 + 1, Y2, X2 - X1 - 1, #196); Write(#217);
end;

procedure ANSIHLine(X, Y, Len: Integer; Ch: Char);
var I: Integer;
begin
  ANSIGotoXY(X, Y);
  for I := 1 to Len do Write(Ch);
end;

procedure ANSIHeader(const Title: String);
begin
  ANSIColor(acCyan or acBright, acBlack);
  ANSIWriteLn(#213 + StringOfChar(#205, 60) + #184);
  ANSIWrite(#179 + ' ');
  ANSIColor(acWhite or acBright, acBlack);
  ANSIWrite(Title);
  ANSIColor(acCyan or acBright, acBlack);
  ANSIWriteLn(StringOfChar(' ', 60 - Length(Title) - 1) + #179);
  ANSIWriteLn(#212 + StringOfChar(#205, 60) + #190);
  ANSIReset;
end;

procedure ANSIMenuItem(Key: Char; const Description: String);
begin
  ANSIColor(acYellow or acBright, acBlack);
  ANSIWrite('  [');
  ANSIColor(acWhite or acBright, acBlack);
  ANSIWrite(Key);
  ANSIColor(acYellow or acBright, acBlack);
  ANSIWrite('] ');
  ANSIColor(acCyan, acBlack);
  ANSIWriteLn(Description);
  ANSIReset;
end;

procedure ANSIStatusBar(const Text: String);
begin
  ANSIGotoXY(1, 24);
  ANSIColor(acWhite, acBlue);
  ANSIWrite(Text + StringOfChar(' ', 80 - Length(Text)));
  ANSIReset;
end;

procedure ANSIPrompt(const Text: String);
begin
  ANSIColor(acGreen or acBright, acBlack);
  ANSIWrite(Text);
  ANSIReset;
end;

procedure ANSIError(const Text: String);
begin
  ANSIColor(acRed or acBright, acBlack);
  ANSIWriteLn('ERROR: ' + Text);
  ANSIReset;
end;

procedure ANSIInfo(const Text: String);
begin
  ANSIColor(acCyan, acBlack);
  ANSIWriteLn(Text);
  ANSIReset;
end;

function ANSIReadKey: Char;
begin
  { ReadKey replacement for non-Crt builds }
  Result := Chr(0);
  if not EOF(Input) then Read(Result);
end;

function ANSIReadLn(MaxLen: Integer): String;
var S: String;
begin
  ReadLn(S);
  if Length(S) > MaxLen then
    SetLength(S, MaxLen);
  Result := S;
end;

function ANSIYesNo(const Prompt: String; Default: Boolean): Boolean;
var Ch: Char;
begin
  ANSIPrompt(Prompt);
  if Default then
    ANSIWrite(' [Y/n] ')
  else
    ANSIWrite(' [y/N] ');
  Ch := UpCase(ANSIReadKey);
  WriteLn(Ch);
  if Ch = 'Y' then Result := True
  else if Ch = 'N' then Result := False
  else Result := Default;
end;

procedure ANSIPause;
begin
  ANSIColor(acWhite, acBlack);
  ANSIWrite('Press any key to continue...');
  ANSIReset;
  ANSIReadKey;
  WriteLn;
end;

end.
