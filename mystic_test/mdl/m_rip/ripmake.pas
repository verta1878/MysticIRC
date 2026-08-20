//
// This file is part of the Mystic BBS IRC Fork.
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
program ripmake;
{ ===========================================================================
  ripmake — simple RIPscrip scene file generator
  ---------------------------------------------------------------------------
  Creates .RIP files from a simple text description format. This is the
  "sysop's RIP editor" — describe what you want, get a .RIP file.

  Input format (one command per line):
    CLEAR                          reset screen
    COLOR <0-15>                   set drawing color
    LINE <x1> <y1> <x2> <y2>      draw a line
    RECT <x1> <y1> <x2> <y2>      draw a rectangle
    BAR <x1> <y1> <x2> <y2>       filled rectangle
    CIRCLE <x> <y> <r>            draw a circle
    TEXT <x> <y> <string>          draw text at position
    FILL <x> <y> <border>         flood fill
    BUTTON <x1> <y1> <x2> <y2> <label> <hostcmd>
    ICON <x> <y> <filename>       load and display an icon
    INCLUDE <filename>             include another .RIP scene
    # comment                     ignored

  Base-36 encoding is handled automatically — the sysop types decimal
  coordinates and ripmake converts to RIPscrip format.

  Usage: ripmake input.txt output.rip

  RIPscrip protocol (c) TeleGrafix Communications, Inc.
  ripmake is GPLv3.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

uses SysUtils;

function ToB36(V: Integer; Digits: Integer): String;
const B36 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
var i: Integer;
begin
  Result := '';
  for i := 1 to Digits do
  begin
    Result := B36[(V mod 36) + 1] + Result;
    V := V div 36;
  end;
end;

procedure ProcessLine(const Line: String; var OutF: Text);
var
  Parts: array[0..9] of String;
  Cmd: String;
  N, i, p: Integer;
  S: String;
begin
  if (Length(Line) = 0) or (Line[1] = '#') then Exit;

  { split line into parts }
  N := 0;
  S := Line + ' ';
  p := 1;
  while (p <= Length(S)) and (N <= 9) do
  begin
    while (p <= Length(S)) and (S[p] = ' ') do Inc(p);
    if p > Length(S) then Break;
    i := p;
    if N = 9 then
    begin
      { last part gets the rest of the line }
      Parts[N] := Trim(Copy(S, i, Length(S) - i));
      Inc(N);
      Break;
    end;
    while (p <= Length(S)) and (S[p] <> ' ') do Inc(p);
    Parts[N] := Copy(S, i, p - i);
    Inc(N);
  end;

  if N = 0 then Exit;
  Cmd := UpperCase(Parts[0]);

  if Cmd = 'CLEAR' then
    WriteLn(OutF, '!|*')
  else if (Cmd = 'COLOR') and (N >= 2) then
    WriteLn(OutF, '!|c' + ToB36(StrToIntDef(Parts[1], 7), 2))
  else if (Cmd = 'LINE') and (N >= 5) then
    WriteLn(OutF, '!|L' + ToB36(StrToIntDef(Parts[1], 0), 2) +
            ToB36(StrToIntDef(Parts[2], 0), 2) +
            ToB36(StrToIntDef(Parts[3], 0), 2) +
            ToB36(StrToIntDef(Parts[4], 0), 2))
  else if (Cmd = 'RECT') and (N >= 5) then
    WriteLn(OutF, '!|R' + ToB36(StrToIntDef(Parts[1], 0), 2) +
            ToB36(StrToIntDef(Parts[2], 0), 2) +
            ToB36(StrToIntDef(Parts[3], 0), 2) +
            ToB36(StrToIntDef(Parts[4], 0), 2))
  else if (Cmd = 'BAR') and (N >= 5) then
    WriteLn(OutF, '!|B' + ToB36(StrToIntDef(Parts[1], 0), 2) +
            ToB36(StrToIntDef(Parts[2], 0), 2) +
            ToB36(StrToIntDef(Parts[3], 0), 2) +
            ToB36(StrToIntDef(Parts[4], 0), 2))
  else if (Cmd = 'CIRCLE') and (N >= 4) then
    WriteLn(OutF, '!|C' + ToB36(StrToIntDef(Parts[1], 0), 2) +
            ToB36(StrToIntDef(Parts[2], 0), 2) +
            ToB36(StrToIntDef(Parts[3], 0), 2))
  else if (Cmd = 'TEXT') and (N >= 4) then
    WriteLn(OutF, '!|@' + ToB36(StrToIntDef(Parts[1], 0), 2) +
            ToB36(StrToIntDef(Parts[2], 0), 2) +
            Parts[3])
  else if (Cmd = 'FILL') and (N >= 4) then
    WriteLn(OutF, '!|F' + ToB36(StrToIntDef(Parts[1], 0), 2) +
            ToB36(StrToIntDef(Parts[2], 0), 2) +
            ToB36(StrToIntDef(Parts[3], 0), 2))
  else if (Cmd = 'BUTTON') and (N >= 7) then
    WriteLn(OutF, '!|1U' + ToB36(StrToIntDef(Parts[1], 0), 2) +
            ToB36(StrToIntDef(Parts[2], 0), 2) +
            ToB36(StrToIntDef(Parts[3], 0), 2) +
            ToB36(StrToIntDef(Parts[4], 0), 2) +
            '000' + '<>' + Parts[5] + '<>' + Parts[6])
  else if (Cmd = 'ICON') and (N >= 4) then
    WriteLn(OutF, '!|1I' + ToB36(StrToIntDef(Parts[1], 0), 2) +
            ToB36(StrToIntDef(Parts[2], 0), 2) +
            '0000' + Parts[3])
  else if (Cmd = 'INCLUDE') and (N >= 2) then
    WriteLn(OutF, '!|1R000000' + Parts[1])
  else
    WriteLn('Warning: unknown command: ', Cmd);
end;

var
  InF, OutF: Text;
  Line: String;
begin
  if ParamCount < 2 then
  begin
    WriteLn('ripmake — RIPscrip scene file generator');
    WriteLn('Usage: ripmake input.txt output.rip');
    WriteLn;
    WriteLn('Input format (one command per line):');
    WriteLn('  CLEAR                              reset screen');
    WriteLn('  COLOR <0-15>                       set drawing color');
    WriteLn('  LINE <x1> <y1> <x2> <y2>          draw a line');
    WriteLn('  RECT <x1> <y1> <x2> <y2>          draw a rectangle');
    WriteLn('  BAR <x1> <y1> <x2> <y2>           filled rectangle');
    WriteLn('  CIRCLE <x> <y> <radius>            draw a circle');
    WriteLn('  TEXT <x> <y> <string>              draw text');
    WriteLn('  FILL <x> <y> <border_color>        flood fill');
    WriteLn('  BUTTON <x1> <y1> <x2> <y2> <label> <hostcmd>');
    WriteLn('  ICON <x> <y> <filename>            load icon');
    WriteLn('  INCLUDE <filename>                  include scene');
    WriteLn('  # comment                          ignored');
    Halt(0);
  end;

  Assign(InF, ParamStr(1));
  {$I-} Reset(InF); {$I+}
  if IOResult <> 0 then
  begin
    WriteLn('Error: cannot open ', ParamStr(1));
    Halt(1);
  end;

  Assign(OutF, ParamStr(2));
  Rewrite(OutF);

  while not EOF(InF) do
  begin
    ReadLn(InF, Line);
    ProcessLine(Trim(Line), OutF);
  end;

  Close(InF);
  Close(OutF);
  WriteLn('Created: ', ParamStr(2));
end.
