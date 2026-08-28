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
program test_rip_files;
{$MODE OBJFPC}{$H+}
{ Test that all default .RIP files are valid RIPscrip format and contain
  the required elements for a working Mystic BBS theme. }
uses SysUtils;
var pass, fail, total: Integer;
procedure Check(c: Boolean; const nm: string);
begin if c then begin Inc(pass); WriteLn('  PASS: ', nm); end
      else begin Inc(fail); WriteLn('  FAIL: ', nm); end; end;

function FileContains(const FName, Search: string): Boolean;
var f: Text; line: string;
begin
  Result := False;
  {$I-} Assign(f, FName); Reset(f); {$I+}
  if IOResult <> 0 then Exit;
  while not EOF(f) do begin
    ReadLn(f, line);
    if Pos(Search, line) > 0 then begin Result := True; Break; end;
  end;
  Close(f);
end;

function IsValidRIP(const FName: string): Boolean;
var f: Text; line: string; hasRIP: Boolean;
begin
  Result := False; hasRIP := False;
  {$I-} Assign(f, FName); Reset(f); {$I+}
  if IOResult <> 0 then Exit;
  while not EOF(f) do begin
    ReadLn(f, line);
    if (Length(line) >= 2) and (line[1] = '!') and (line[2] = '|') then
      hasRIP := True;
  end;
  Close(f);
  Result := hasRIP;
end;

function FileSize2(const FName: string): LongInt;
var f: File;
begin
  {$I-} Assign(f, FName); Reset(f, 1); {$I+}
  if IOResult <> 0 then begin Result := 0; Exit; end;
  Result := FileSize(f);
  Close(f);
end;

var
  sr: TSearchRec;
  ripDir, fname: string;
begin
  pass := 0; fail := 0; total := 0;

  WriteLn('== text/*.rip display files ==');
  ripDir := 'text/';
  if FindFirst(ripDir + '*.rip', faAnyFile, sr) = 0 then begin
    repeat
      fname := ripDir + sr.Name;
      Inc(total);
      Check(IsValidRIP(fname), sr.Name + ' is valid RIPscrip');
      Check(FileContains(fname, '!|*'), sr.Name + ' has reset command');
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  Check(total >= 30, 'at least 30 display .rip files (' + IntToStr(total) + ' found)');

  WriteLn;
  WriteLn('== menus/*.rip menu files ==');
  total := 0;
  ripDir := 'menus/';
  if FindFirst(ripDir + '*.rip', faAnyFile, sr) = 0 then begin
    repeat
      fname := ripDir + sr.Name;
      Inc(total);
      Check(IsValidRIP(fname), sr.Name + ' is valid RIPscrip');
      Check(FileContains(fname, '!|1U'), sr.Name + ' has buttons');
      Check(FileContains(fname, '!|1M'), sr.Name + ' has mouse regions');
      Check(FileContains(fname, '!|1K'), sr.Name + ' kills old regions');
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  Check(total >= 5, 'at least 5 menu .rip files (' + IntToStr(total) + ' found)');

  WriteLn;
  WriteLn('== text/icons/*.icn icon files ==');
  total := 0;
  ripDir := 'text/icons/';
  if FindFirst(ripDir + '*.icn', faAnyFile, sr) = 0 then begin
    repeat
      Inc(total);
      Check(FileSize2(ripDir + sr.Name) = 292, sr.Name + ' is 292 bytes (24x24 EGA)');
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  Check(total >= 8, 'at least 8 icon files (' + IntToStr(total) + ' found)');

  WriteLn;
  WriteLn('== text/fonts/*.CHR font files ==');
  total := 0;
  ripDir := 'text/fonts/';
  if FindFirst(ripDir + '*.CHR', faAnyFile, sr) = 0 then begin
    repeat
      Inc(total);
      Check(FileSize2(ripDir + sr.Name) > 1000, sr.Name + ' is valid font (>' + IntToStr(FileSize2(ripDir + sr.Name)) + ' bytes)');
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  Check(total = 10, '10 font files (' + IntToStr(total) + ' found)');

  WriteLn;
  WriteLn('RESULT: ', pass, ' passed, ', fail, ' failed');
  if fail = 0 then WriteLn('ALL RIP FILES - VERIFIED');
end.
