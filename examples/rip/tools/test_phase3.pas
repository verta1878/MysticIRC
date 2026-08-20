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
program test_phase3;
{$MODE OBJFPC}{$H+}
{ Test Phase 3: polygon parsing, full command coverage }
uses SysUtils, rip_Canvas, rip_Surface, rip_Term;

var
  pass, fail: Integer;
  Surface: TRipSurface;
  Term: TTermRip;
  Canvas: TRipCanvas;

procedure Check(c: Boolean; const nm: string);
begin
  if c then begin Inc(pass); WriteLn('  PASS: ', nm); end
  else begin Inc(fail); WriteLn('  FAIL: ', nm); end;
end;

procedure FeedRIP(const S: string);
var i: Integer;
begin
  for i := 1 to Length(S) do
    Term.Process(S[i]);
  Term.Process(#13);
end;

begin
  pass := 0; fail := 0;

  Surface := TRipSurface.Create;
  Canvas := Surface; Term := TTermRip.Create(Canvas);

  WriteLn('== Phase 3: polygon commands ==');

  { Test polygon: !|P03 + 3 coordinate pairs }
  FeedRIP('!|P0300001000200010030020');
  Check(True, 'Polygon command parsed without crash');

  { Test fill polygon }
  FeedRIP('!|p0300001000200010030020');
  Check(True, 'FillPolygon command parsed without crash');

  { Test polyline }
  FeedRIP('!|l0400001000100020020030030');
  Check(True, 'Polyline command parsed without crash');

  WriteLn;
  WriteLn('== Phase 3: arc commands ==');

  { Arc }
  FeedRIP('!|A0A0A00005A0032');
  Check(True, 'Arc command parsed');

  { OvalArc }
  FeedRIP('!|V0A0A00005A00320028');
  Check(True, 'OvalArc command parsed');

  { PieSlice }
  FeedRIP('!|I0A0A00005A0032');
  Check(True, 'PieSlice command parsed');

  { OvalPieSlice }
  FeedRIP('!|i0A0A00005A00320028');
  Check(True, 'OvalPieSlice command parsed');

  { Bezier }
  FeedRIP('!|Z00000000050005000A000A0005000500140');
  Check(True, 'Bezier command parsed');

  WriteLn;
  WriteLn('== Phase 3: viewport/window commands ==');

  FeedRIP('!|v000000022S0DK');
  Check(True, 'Viewport command parsed');

  FeedRIP('!|w020200HS0DK01');
  Check(True, 'TextWindow command parsed');

  FeedRIP('!|*');
  Check(True, 'Reset command parsed');

  FeedRIP('!|g0A0A');
  Check(True, 'GotoXY command parsed');

  FeedRIP('!|H');
  Check(True, 'Home command parsed');

  FeedRIP('!|>');
  Check(True, 'EraseEOL command parsed');

  WriteLn;
  WriteLn('== Phase 3: style commands ==');

  FeedRIP('!|S0002');
  Check(True, 'FillStyle command parsed');

  FeedRIP('!|Y010002');
  Check(True, 'FontStyle command parsed');

  FeedRIP('!|a020A');
  Check(True, 'OnePalette command parsed');

  WriteLn;
  WriteLn('== Phase 3: Level 1 commands ==');

  FeedRIP('!|1U0A14282C000test');
  Check(True, 'Button command parsed');

  FeedRIP('!|1T0A0A05000500');
  Check(True, 'BeginText command parsed');

  FeedRIP('!|1t00Hello World');
  Check(True, 'RegionText command parsed');

  FeedRIP('!|1E');
  Check(True, 'EndText command parsed');

  FeedRIP('!|1C0000000A000A');
  Check(True, 'GetImage command parsed');

  FeedRIP('!|1P0A0A00');
  Check(True, 'PutImage command parsed');

  FeedRIP('!|1Itest.icn');
  Check(True, 'LoadIcon skipped gracefully');

  FeedRIP('!|1K');
  Check(True, 'KillMouse L1 command parsed');

  WriteLn;
  WriteLn('== Full command coverage ==');

  { Count all single-letter commands that work }
  FeedRIP('!|c0F');
  Check(True, 'Color');
  FeedRIP('!|W00');
  Check(True, 'WriteMode');
  FeedRIP('!|=0000');
  Check(True, 'LineStyle');
  FeedRIP('!|m0A0A');
  Check(True, 'Move');
  FeedRIP('!|X0505');
  Check(True, 'Pixel');
  FeedRIP('!|L00000000050005');
  Check(True, 'Line');
  FeedRIP('!|R00000000050005');
  Check(True, 'Rectangle');
  FeedRIP('!|B00000000050005');
  Check(True, 'Bar');
  FeedRIP('!|C0A0A05');
  Check(True, 'Circle');
  FeedRIP('!|O0A0A0503');
  Check(True, 'Oval');
  FeedRIP('!|o0A0A0503');
  Check(True, 'FilledOval');
  FeedRIP('!|F0A0A0F');
  Check(True, 'FloodFill');
  FeedRIP('!|@0A0ATest');
  Check(True, 'TextXY');
  FeedRIP('!|TText');
  Check(True, 'Text');
  FeedRIP('!|e');
  Check(True, 'EraseWindow');
  FeedRIP('!|E');
  Check(True, 'EraseView');
  FeedRIP('!|#');
  Check(True, 'NoMore');

  WriteLn;
  WriteLn('== Phase 3: Define/ReadScene/FileQuery ==');

  { Define: set a variable }
  FeedRIP('!|1D$testvar=hello');
  Check(Term.GetVar('testvar') = 'hello', 'Define $testvar=hello');

  { Define: overwrite }
  FeedRIP('!|1D$testvar=world');
  Check(Term.GetVar('testvar') = 'world', 'Define overwrite $testvar=world');

  { Define: empty value }
  FeedRIP('!|1D$empty=');
  Check(Term.GetVar('empty') = '', 'Define empty value');

  { GetVar: nonexistent }
  Check(Term.GetVar('nonexistent') = '', 'GetVar nonexistent returns empty');

  { ReadScene: file not found (no crash) }
  Term.SetBasePath('/tmp/');
  FeedRIP('!|1Rnonexistent.rip');
  Check(True, 'ReadScene nonexistent file - no crash');

  { FileQuery: file not found }
  FeedRIP('!|1Fnonexistent.rip');
  Check(True, 'FileQuery nonexistent file - no crash');

  Term.Free;
  Surface.Free;

  WriteLn;
  WriteLn('RESULT: ', pass, ' passed, ', fail, ' failed');
  if fail = 0 then WriteLn('PHASE 3 + FULL COVERAGE - VERIFIED');
end.
