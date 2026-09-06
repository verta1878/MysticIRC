{$MODE DELPHI}
program test_ui;
uses SysUtils, mripui;

var
  CB: TWizDrawCallbacks;
  DrawCount: Integer;

procedure TestSetColor(Color: Integer);
begin WriteLn('  SetColor(', Color, ')'); Inc(DrawCount); end;

procedure TestSetFillStyle(Style, Color: Integer);
begin WriteLn('  SetFillStyle(', Style, ', ', Color, ')'); Inc(DrawCount); end;

procedure TestSetFillPat(Style, Color, Flag: Integer);
begin WriteLn('  SetFillPat(', Style, ', ', Color, ', ', Flag, ')'); Inc(DrawCount); end;

procedure TestBar(X1, Y1, X2, Y2: Integer);
begin WriteLn('  Bar(', X1, ',', Y1, ',', X2, ',', Y2, ')'); Inc(DrawCount); end;

procedure TestRect(X1, Y1, X2, Y2: Integer);
begin WriteLn('  Rect(', X1, ',', Y1, ',', X2, ',', Y2, ')'); Inc(DrawCount); end;

procedure TestLine(X1, Y1, X2, Y2: Integer);
begin WriteLn('  Line(', X1, ',', Y1, ',', X2, ',', Y2, ')'); Inc(DrawCount); end;

procedure TestPixel(X, Y: Integer);
begin WriteLn('  Pixel(', X, ',', Y, ')'); Inc(DrawCount); end;

procedure TestFlood(X, Y, Border: Integer);
begin WriteLn('  FloodFill(', X, ',', Y, ', border=', Border, ')'); Inc(DrawCount); end;

procedure TestWidget(const Name: String; X, Y, X2, Y2: Integer);
begin
  DrawCount := 0;
  WriteLn('--- ', Name, ' (', X, ',', Y, ',', X2, ',', Y2, ') ---');
  if RenderWidget(Name, X, Y, X2, Y2, CB) then
    WriteLn('  Draw calls: ', DrawCount, ' PASS')
  else
    WriteLn('  UNKNOWN WIDGET — FAIL');
  WriteLn('');
end;

begin
  CB.SetColor     := @TestSetColor;
  CB.SetFillStyle := @TestSetFillStyle;
  CB.SetFillPat   := @TestSetFillPat;
  CB.DrawBar      := @TestBar;
  CB.DrawRect     := @TestRect;
  CB.DrawLine     := @TestLine;
  CB.DrawPixel    := @TestPixel;
  CB.FloodFill    := @TestFlood;

  WriteLn('=== MRP Built-in Widget Test ===');
  WriteLn('');

  TestWidget('Box', 10, 10, 200, 150);
  TestWidget('Window', 50, 30, 400, 300);
  TestWidget('Frame', 20, 20, 120, 80);
  TestWidget('Dialog', 100, 50, 500, 250);
  TestWidget('ButtonUp', 10, 10, 80, 30);
  TestWidget('ButtonDown', 10, 10, 80, 30);

  WriteLn('=== ALL PASS ===');
end.
