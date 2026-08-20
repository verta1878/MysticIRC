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
program test_ans2rip;
{$MODE OBJFPC}{$H+}
{ Test the ans2rip converter — verify ANSI input produces valid RIPscrip output. }
uses SysUtils;
var pass, fail: Integer;
procedure Check(c: Boolean; const nm: string);
begin if c then begin Inc(pass); WriteLn('  PASS: ', nm); end
      else begin Inc(fail); WriteLn('  FAIL: ', nm); end; end;

function FileContains(const FName, Search: string): Boolean;
var f: Text; line: string;
begin
  Result := False;
  Assign(f, FName); Reset(f);
  while not EOF(f) do begin
    ReadLn(f, line);
    if Pos(Search, line) > 0 then begin Result := True; Break; end;
  end;
  Close(f);
end;

function FileLineCount(const FName: string): Integer;
var f: Text; line: string;
begin
  Result := 0;
  Assign(f, FName); Reset(f);
  while not EOF(f) do begin ReadLn(f, line); Inc(Result); end;
  Close(f);
end;

var
  ansFile, ripFile: Text;
begin
  pass := 0; fail := 0;

  WriteLn('== ans2rip: create test .ans files and convert ==');

  { Test 1: simple text }
  Assign(ansFile, 'test1.ans'); Rewrite(ansFile);
  WriteLn(ansFile, 'Hello World');
  Close(ansFile);
  ExecuteProcess('./ans2rip', ['test1.ans', 'test1.rip']);
  Check(FileExists('test1.rip'), 'test1.rip created');
  Check(FileContains('test1.rip', '!|*'), 'starts with RIP reset');
  Check(FileContains('test1.rip', '!|@'), 'contains text command');
  Check(FileContains('test1.rip', 'H'), 'contains letter H from Hello');

  { Test 2: ANSI color codes }
  Assign(ansFile, 'test2.ans'); Rewrite(ansFile);
  Write(ansFile, #27'[1;31mRed Bold'#27'[0m Normal');
  Close(ansFile);
  ExecuteProcess('./ans2rip', ['test2.ans', 'test2.rip']);
  Check(FileExists('test2.rip'), 'test2.rip created');
  Check(FileContains('test2.rip', '!|c'), 'contains color command');
  Check(FileContains('test2.rip', '!|c09'), 'bright red = color 9 (1+8 bold)');

  { Test 3: cursor positioning }
  Assign(ansFile, 'test3.ans'); Rewrite(ansFile);
  Write(ansFile, #27'[5;10HX');
  Close(ansFile);
  ExecuteProcess('./ans2rip', ['test3.ans', 'test3.rip']);
  Check(FileExists('test3.rip'), 'test3.rip created');
  Check(FileContains('test3.rip', '!|@'), 'contains positioned text');

  { Test 4: clear screen }
  Assign(ansFile, 'test4.ans'); Rewrite(ansFile);
  Write(ansFile, #27'[2JHello');
  Close(ansFile);
  ExecuteProcess('./ans2rip', ['test4.ans', 'test4.rip']);
  Check(FileExists('test4.rip'), 'test4.rip created');
  Check(FileLineCount('test4.rip') >= 2, 'has reset + content');

  { Test 5: empty file }
  Assign(ansFile, 'test5.ans'); Rewrite(ansFile);
  Close(ansFile);
  ExecuteProcess('./ans2rip', ['test5.ans', 'test5.rip']);
  Check(FileExists('test5.rip'), 'test5.rip created from empty .ans');
  Check(FileContains('test5.rip', '!|*'), 'empty file still has RIP reset');

  { Test 6: multiple colors }
  Assign(ansFile, 'test6.ans'); Rewrite(ansFile);
  Write(ansFile, #27'[32mGreen'#27'[34mBlue'#27'[33mYellow');
  Close(ansFile);
  ExecuteProcess('./ans2rip', ['test6.ans', 'test6.rip']);
  Check(FileExists('test6.rip'), 'test6.rip created');
  Check(FileContains('test6.rip', '!|c02'), 'green = color 2');
  Check(FileContains('test6.rip', '!|c04'), 'blue = color 4');
  Check(FileContains('test6.rip', '!|c03'), 'yellow(brown) = color 3');

  { cleanup }
  DeleteFile('test1.ans'); DeleteFile('test1.rip');
  DeleteFile('test2.ans'); DeleteFile('test2.rip');
  DeleteFile('test3.ans'); DeleteFile('test3.rip');
  DeleteFile('test4.ans'); DeleteFile('test4.rip');
  DeleteFile('test5.ans'); DeleteFile('test5.rip');
  DeleteFile('test6.ans'); DeleteFile('test6.rip');

  WriteLn;
  WriteLn('RESULT: ', pass, ' passed, ', fail, ' failed');
  if fail = 0 then WriteLn('ANS2RIP CONVERTER - VERIFIED');
end.
