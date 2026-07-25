{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// RIPscrip v1.54 Engine Stress Tests — 33 tests
// Compile: ppcx64 -Mdelphi -Fu<path-to-mystic_ripapi> test_v1_stress.pas
//
// Edge cases and adversarial inputs:
//   Full screen pixel fill (640x350, all 16 colors),
//   Rapid ClearScreen (100 cycles),
//   Zero-length line (single pixel),
//   Degenerate rectangle (1x1, inverted coords),
//   Zero radius circle,
//   Negative coordinates (Line, Rect, Circle, FloodFill),
//   Huge coordinates (30000+),
//   All 12 fill styles,
//   Screen save all 10 slots + bad slot 255,
//   40 text variables, ExpandVars edge cases (unknown var, empty, $$),
//   Full screen FloodFill (stack-limited),
//   Malformed RIP commands (empty, truncated, unknown),
//   SaveBMP twice (overwrite),
//   100-point polygon,
//   1000 rapid color changes + draws
//
Program test_v1_stress;

Uses ripscr;

Var
  RIP    : TRIPEngine;
  Pass   : Integer;
  Fail   : Integer;
  Total  : Integer;

Procedure Check (Name: String; Cond: Boolean);
Begin
  Inc(Total);
  If Cond Then Begin
    Inc(Pass);
    WriteLn('  PASS  ', Name);
  End Else Begin
    Inc(Fail);
    WriteLn('  FAIL  ', Name);
  End;
End;

Procedure TestMassivePixelFill;
Var X, Y : SmallInt;
    OK   : Boolean;
Begin
  WriteLn;
  WriteLn('--- Massive Pixel Fill (640x350) ---');
  RIP.ClearScreen;
  For Y := 0 to 349 Do
    For X := 0 to 639 Do
      RIP.PutPixel(X, Y, (X + Y) mod 16);
  OK := RIP.GetPixel(320, 175) = ((320 + 175) mod 16);
  Check('Full screen fill: center pixel correct', OK);
End;

Procedure TestRapidClearScreen;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- Rapid ClearScreen (100x) ---');
  For I := 1 to 100 Do Begin
    RIP.PutPixel(100, 100, 15);
    RIP.ClearScreen;
  End;
  Check('100 clears: no crash', True);
  Check('Screen is clear', RIP.GetPixel(100, 100) = 0);
End;

Procedure TestZeroLengthLine;
Begin
  WriteLn;
  WriteLn('--- Zero-Length Line ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Line(50, 50, 50, 50);
  Check('Zero-length line: single pixel', RIP.GetPixel(50, 50) = 15);
End;

Procedure TestDegenerateRectangle;
Begin
  WriteLn;
  WriteLn('--- Degenerate Rectangle ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Rectangle(100, 100, 100, 100);  // 1x1
  Check('1x1 rectangle: no crash', True);

  RIP.Rectangle(200, 200, 100, 100);  // inverted
  Check('Inverted rectangle: no crash', True);
End;

Procedure TestZeroRadiusCircle;
Begin
  WriteLn;
  WriteLn('--- Zero Radius Circle ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Circle(100, 100, 0);
  Check('Zero radius circle: no crash', True);
End;

Procedure TestNegativeCoords;
Begin
  WriteLn;
  WriteLn('--- Negative Coordinates ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Line(-100, -100, -50, -50);
  Check('Line at negative coords: no crash', True);

  RIP.Rectangle(-10, -10, 10, 10);
  Check('Rectangle spanning negative: no crash', True);

  RIP.Circle(-50, -50, 30);
  Check('Circle at negative center: no crash', True);

  RIP.FloodFill(-5, -5, 0);
  Check('FloodFill at negative: no crash', True);
End;

Procedure TestHugeCoords;
Begin
  WriteLn;
  WriteLn('--- Huge Coordinates ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Line(0, 0, 30000, 30000);
  Check('Line to (30000,30000): no crash', True);

  RIP.Circle(30000, 30000, 100);
  Check('Circle at (30000,30000): no crash', True);

  RIP.MoveTo(30000, 30000);
  Check('MoveTo(30000,30000): no crash', True);
End;

Procedure TestAllFillStyles;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- All Fill Styles ---');
  For I := 0 to 11 Do Begin
    RIP.SetFillStyle(I, 15);
    RIP.Bar(10, 10, 50, 50);
  End;
  Check('All 12 fill styles: no crash', True);
End;

Procedure TestScreenSaveAllSlots;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- Screen Save All 10 Slots ---');
  For I := 0 to 9 Do Begin
    RIP.PutPixel(I, 0, I);
    RIP.SaveScreen(I);
  End;
  For I := 0 to 9 Do
    RIP.RestoreScreen(I);
  Check('Save/restore all 10 slots: no crash', True);
End;

Procedure TestScreenSaveBadSlot;
Begin
  WriteLn;
  WriteLn('--- Screen Save Bad Slot ---');
  RIP.SaveScreen(255);
  Check('SaveScreen(255): no crash', True);
  RIP.RestoreScreen(255);
  Check('RestoreScreen(255): no crash', True);
End;

Procedure TestManyTextVariables;
Var
  I  : Integer;
  S  : String;
  OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- Many Text Variables ---');
  RIP.KillAllVars;
  For I := 1 to 40 Do Begin
    S := 'V';
    If I < 10 Then S := S + '0';
    Str(I, S);
    S := 'VAR' + S;
    RIP.DefineVar(S, S, False, False);
  End;
  OK := RIP.GetVar('VAR1') = 'VAR1';
  Check('40 variables: first accessible', OK);
  RIP.KillAllVars;
End;

Procedure TestExpandVarsNested;
Var S : String;
Begin
  WriteLn;
  WriteLn('--- ExpandVars Edge Cases ---');
  RIP.KillAllVars;

  // No vars defined — $UNKNOWN$ should stay as-is or empty
  S := RIP.ExpandVars('Hello $UNKNOWN$ World');
  Check('Unknown var: no crash', True);

  // Empty string
  S := RIP.ExpandVars('');
  Check('Empty string: no crash', True);

  // Just dollar signs
  S := RIP.ExpandVars('$$$$');
  Check('Dollar signs: no crash', True);
End;

Procedure TestFloodFillEntireScreen;
Begin
  WriteLn;
  WriteLn('--- FloodFill Entire Screen ---');
  RIP.ClearScreen;
  RIP.SetFillStyle(1, 5);
  RIP.FloodFill(320, 175, 99);
  // Stack-limited — may not fill entire screen but should not crash
  Check('Full screen flood: no crash', True);
End;

Procedure TestProcessLineMalformed;
Begin
  WriteLn;
  WriteLn('--- Malformed RIP Commands ---');
  RIP.ProcessLine('');
  Check('Empty line: no crash', True);

  RIP.ProcessLine('!|');
  Check('Just !|: no crash', True);

  RIP.ProcessLine('!|ZZZZZZZZZZZZ');
  Check('Unknown command: no crash', True);

  RIP.ProcessLine('random text without RIP marker');
  Check('Non-RIP text: no crash', True);

  RIP.ProcessLine('!|c');  // color with no params
  Check('Color no params: no crash', True);

  RIP.ProcessLine('!|L');  // line with no params
  Check('Line no params: no crash', True);
End;

Procedure TestSaveBMPTwice;
Var OK1, OK2 : Boolean;
Begin
  WriteLn;
  WriteLn('--- SaveBMP Twice ---');
  RIP.ClearScreen;
  RIP.PutPixel(0, 0, 15);
  OK1 := RIP.SaveBMP('/tmp/test_v1_stress1.bmp');
  OK2 := RIP.SaveBMP('/tmp/test_v1_stress2.bmp');
  Check('SaveBMP first: ok', OK1);
  Check('SaveBMP second (overwrite): ok', OK2);
End;

Procedure TestPolyLineStress;
Var Pts : Array[0..99] of TRIPPoint;
    I   : Integer;
Begin
  WriteLn;
  WriteLn('--- PolyLine 100 Points ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  For I := 0 to 99 Do Begin
    Pts[I].X := (I * 6) mod 640;
    Pts[I].Y := (I * 3) mod 350;
  End;
  RIP.DrawPoly(100, Pts);
  Check('100-point polygon: no crash', True);
End;

Procedure TestRapidColorChange;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- Rapid Color Changes (1000x) ---');
  For I := 1 to 1000 Do Begin
    RIP.SetColor(I mod 16);
    RIP.PutPixel(I mod 640, I mod 350, I mod 16);
  End;
  Check('1000 color changes + draws: no crash', True);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== RIPscrip v1.54 — STRESS TESTS ===');

  RIP := TRIPEngine.Create;

  TestMassivePixelFill;
  TestRapidClearScreen;
  TestZeroLengthLine;
  TestDegenerateRectangle;
  TestZeroRadiusCircle;
  TestNegativeCoords;
  TestHugeCoords;
  TestAllFillStyles;
  TestScreenSaveAllSlots;
  TestScreenSaveBadSlot;
  TestManyTextVariables;
  TestExpandVarsNested;
  TestFloodFillEntireScreen;
  TestProcessLineMalformed;
  TestSaveBMPTwice;
  TestPolyLineStress;
  TestRapidColorChange;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
