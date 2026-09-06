{$MODE DELPHI}
program test_chrfont;
uses SysUtils, mripchr;

var
  Font: TCHRFont;
  I: Integer;
  FontPath: String;

procedure DummyLine(X1, Y1, X2, Y2: Integer);
begin
  { just count — real drawing in mtripgfx }
end;

begin
  if ParamCount = 0 then begin
    WriteLn('Usage: test_chrfont <fontfile.CHR>');
    WriteLn('Example: test_chrfont ../../examples/ripart/fonts/TRIP.CHR');
    Halt(1);
  end;

  FontPath := ParamStr(1);
  WriteLn('Loading: ', FontPath);

  if LoadCHRFont(FontPath, Font) then begin
    WriteLn('  Name: ', Font.FontName);
    WriteLn('  Header: ', Font.HeaderText);
    WriteLn('  Version: ', Font.Version);
    WriteLn('  First char: ', Font.FirstChar, ' (', Chr(Font.FirstChar), ')');
    WriteLn('  Last char: ', Font.LastChar, ' (', Chr(Font.LastChar), ')');
    WriteLn('  Org to cap: ', Font.OrgToCap);
    WriteLn('  Org to base: ', Font.OrgToBase);
    WriteLn('  Org to bot: ', Font.OrgToBot);
    WriteLn('  Total strokes: ', Font.StrokeCount);
    WriteLn('');

    { Show first 10 defined chars }
    WriteLn('  Char widths (first 10):');
    for I := Font.FirstChar to Font.FirstChar + 9 do begin
      if I <= Font.LastChar then
        WriteLn('    ', Chr(I), ' (', I, '): width=', Font.CharDefs[I].Width,
                ' strokes=', Font.CharDefs[I].NumStrokes);
    end;

    WriteLn('');
    WriteLn('  Text width test:');
    WriteLn('    "Hello" at size 1: ', CHRTextWidth(Font, 'Hello', 1), ' px');
    WriteLn('    "Hello" at size 2: ', CHRTextWidth(Font, 'Hello', 2), ' px');
    WriteLn('    Height at size 1: ', CHRTextHeight(Font, 1), ' px');
    WriteLn('');
    WriteLn('PASS');
  end else begin
    WriteLn('FAIL: Could not load font');
    Halt(1);
  end;
end.
