{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// RIPscrip v1.54 Engine Test Suite — 64 tests
// Compile: ppcx64 -Mdelphi -Fu<path-to-mystic_ripapi> test_v1.pas
//
// Core engine tests:
//   Create/Destroy — engine creation, default dimensions
//   Reset — state reset, color/cursor defaults
//   PutPixel/GetPixel — corners (0,0), (639,349), center
//   Out-of-Bounds — negative coords, past canvas, safety
//   All 16 EGA Colors — round-trip through palette
//   Line — horizontal, vertical, diagonal
//   LineTo/MoveTo — cursor tracking, line drawing
//   MoveRel — relative cursor movement
//   Rectangle — edges drawn, center empty
//   Bar — solid fill
//   Circle — pixels on horizontal axis
//   FillEllipse — center pixel filled
//   ClearScreen/ClearViewport — pixel zeroed
//   Viewport — clipping inside/outside
//   Color Accessors — SetColor/GetColor, SetBkColor/GetBkColor
//   Palette — SetPalette read-back
//   Fill Style — SetFillStyle/GetFillSettings
//   Line Style — dotted line rendering
//   Write Mode — XOR write mode
//   OutTextXY — 8x8 bitmap text rendering
//   FloodFill — fill inside border, border preservation
//   SaveBMP — file creation
//   Text Variables — DefineVar, GetVar, SetVar, KillAllVars
//   ExpandVars — $NAME$ expansion
//   Screen Save/Restore — slot 0 save, clear, restore
//   Mouse Fields — |1M command, FindMouseField
//   ProcessLine — |c (color), |X (pixel) RIP commands
//   CopyRegion — pixel copy to destination row
//   System Font — GetSysFontW/H, GetSysCols/Rows
//   Polygon — DrawPoly 4-point triangle
//   Bar3D — 3D bar with depth
//   PieSlice — pie rendering
//   Bezier — cubic bezier curve
//   FileQuery — file query handler
//
Program test_v1;

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

// ---- Creation / Reset ----

Procedure TestCreateDestroy;
Begin
  WriteLn;
  WriteLn('--- Create / Destroy ---');
  Check('Engine created', RIP <> Nil);
  Check('GetMaxX = 639', RIP.GetMaxX = 639);
  Check('GetMaxY = 349', RIP.GetMaxY = 349);
End;

Procedure TestReset;
Begin
  WriteLn;
  WriteLn('--- Reset ---');
  RIP.SetColor(14);
  RIP.PutPixel(100, 100, 14);
  RIP.Reset;
  Check('Reset: color = 15', RIP.GetColor = 15);
  Check('Reset: CurX = 0', RIP.GetX = 0);
  Check('Reset: CurY = 0', RIP.GetY = 0);
End;

// ---- Pixel Operations ----

Procedure TestPutGetPixel;
Begin
  WriteLn;
  WriteLn('--- PutPixel / GetPixel ---');
  RIP.ClearScreen;
  RIP.PutPixel(0, 0, 15);
  Check('PutPixel (0,0,15): GetPixel = 15', RIP.GetPixel(0, 0) = 15);

  RIP.PutPixel(639, 349, 7);
  Check('PutPixel (639,349,7): GetPixel = 7', RIP.GetPixel(639, 349) = 7);

  RIP.PutPixel(320, 175, 0);
  Check('PutPixel center black', RIP.GetPixel(320, 175) = 0);
End;

Procedure TestPixelOutOfBounds;
Begin
  WriteLn;
  WriteLn('--- Pixel Out of Bounds ---');
  RIP.ClearScreen;
  RIP.PutPixel(-1, -1, 15);
  Check('PutPixel (-1,-1): no crash', True);
  Check('GetPixel (-1,-1) = 0', RIP.GetPixel(-1, -1) = 0);

  RIP.PutPixel(700, 400, 15);
  Check('PutPixel (700,400): no crash', True);
  Check('GetPixel (700,400) = 0', RIP.GetPixel(700, 400) = 0);
End;

Procedure TestAllColors;
Var I : Integer;
    OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- All 16 EGA Colors ---');
  RIP.ClearScreen;
  OK := True;
  For I := 0 to 15 Do Begin
    RIP.PutPixel(I, 0, I);
    If RIP.GetPixel(I, 0) <> I Then OK := False;
  End;
  Check('All 16 colors round-trip', OK);
End;

// ---- Line Drawing ----

Procedure TestLine;
Begin
  WriteLn;
  WriteLn('--- Line ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Line(0, 0, 100, 0);
  Check('Horizontal line: pixel at (50,0)', RIP.GetPixel(50, 0) = 15);

  RIP.ClearScreen;
  RIP.Line(0, 0, 0, 100);
  Check('Vertical line: pixel at (0,50)', RIP.GetPixel(0, 50) = 15);

  RIP.ClearScreen;
  RIP.Line(0, 0, 100, 100);
  Check('Diagonal line: pixel at (50,50)', RIP.GetPixel(50, 50) = 15);
End;

Procedure TestLineTo;
Begin
  WriteLn;
  WriteLn('--- LineTo / MoveTo ---');
  RIP.ClearScreen;
  RIP.SetColor(14);
  RIP.MoveTo(10, 10);
  Check('MoveTo: GetX = 10', RIP.GetX = 10);
  Check('MoveTo: GetY = 10', RIP.GetY = 10);

  RIP.LineTo(50, 10);
  Check('LineTo: pixel at (30,10)', RIP.GetPixel(30, 10) = 14);
End;

Procedure TestMoveRel;
Begin
  WriteLn;
  WriteLn('--- MoveRel ---');
  RIP.MoveTo(100, 100);
  RIP.MoveRel(10, 20);
  Check('MoveRel: GetX = 110', RIP.GetX = 110);
  Check('MoveRel: GetY = 120', RIP.GetY = 120);
End;

// ---- Rectangle / Bar ----

Procedure TestRectangle;
Begin
  WriteLn;
  WriteLn('--- Rectangle ---');
  RIP.ClearScreen;
  RIP.SetColor(12);
  RIP.Rectangle(10, 10, 50, 50);
  Check('Rectangle: top edge', RIP.GetPixel(30, 10) = 12);
  Check('Rectangle: left edge', RIP.GetPixel(10, 30) = 12);
  Check('Rectangle: center empty', RIP.GetPixel(30, 30) = 0);
End;

Procedure TestBar;
Begin
  WriteLn;
  WriteLn('--- Bar ---');
  RIP.ClearScreen;
  RIP.SetFillStyle(1, 11);
  RIP.Bar(20, 20, 60, 60);
  Check('Bar: center filled', RIP.GetPixel(40, 40) = 11);
End;

// ---- Circle / Ellipse ----

Procedure TestCircle;
Var Found : Boolean; X : SmallInt;
Begin
  WriteLn;
  WriteLn('--- Circle ---');
  RIP.ClearScreen;
  RIP.SetColor(9);
  RIP.Circle(100, 100, 30);
  Found := False;
  For X := 70 to 130 Do
    If RIP.GetPixel(X, 100) = 9 Then Begin Found := True; Break; End;
  Check('Circle: pixels on horizontal axis', Found);
End;

Procedure TestFillEllipse;
Begin
  WriteLn;
  WriteLn('--- FillEllipse ---');
  RIP.ClearScreen;
  RIP.SetColor(13);
  RIP.SetFillStyle(1, 13);
  RIP.FillEllipse(200, 175, 30, 20);
  Check('FillEllipse: center filled', RIP.GetPixel(200, 175) = 13);
End;

// ---- ClearScreen / ClearViewport ----

Procedure TestClearScreen;
Begin
  WriteLn;
  WriteLn('--- ClearScreen ---');
  RIP.PutPixel(100, 100, 15);
  RIP.ClearScreen;
  Check('ClearScreen: pixel = 0', RIP.GetPixel(100, 100) = 0);
End;

Procedure TestClearViewport;
Begin
  WriteLn;
  WriteLn('--- ClearViewport ---');
  RIP.SetViewPort(10, 10, 50, 50, True);
  RIP.PutPixel(30, 30, 15);
  RIP.ClearViewport;
  Check('ClearViewport: pixel in viewport = 0', RIP.GetPixel(30, 30) = 0);
  RIP.SetViewPort(0, 0, 639, 349, True);
End;

// ---- Viewport Clipping ----

Procedure TestViewport;
Begin
  WriteLn;
  WriteLn('--- Viewport ---');
  RIP.ClearScreen;
  RIP.SetViewPort(100, 100, 200, 200, True);
  RIP.SetColor(15);
  // Draw inside viewport
  RIP.PutPixel(150, 150, 15);
  // Draw outside viewport
  RIP.PutPixel(50, 50, 15);
  Check('Viewport clips: pixel at (50,50) = 0', RIP.GetPixel(50, 50) = 0);
  Check('Viewport allows: pixel at (150,150) drawn', RIP.GetPixel(150, 150) = 15);
  RIP.SetViewPort(0, 0, 639, 349, True);
End;

// ---- Color / Palette ----

Procedure TestColorAccessors;
Begin
  WriteLn;
  WriteLn('--- Color Accessors ---');
  RIP.SetColor(14);
  Check('SetColor/GetColor = 14', RIP.GetColor = 14);

  RIP.SetBkColor(1);
  Check('SetBkColor/GetBkColor', RIP.GetBkColor = 1);
End;

Procedure TestPalette;
Var Pal : TRIPPalette;
Begin
  WriteLn;
  WriteLn('--- Palette ---');
  RIP.SetPalette(0, 63);
  RIP.GetPalette(Pal);
  Check('SetPalette(0,63): reads back', Pal[0] = 63);
  RIP.Reset;
End;

// ---- Fill Style ----

Procedure TestFillStyle;
Var S : Word; C : Byte;
Begin
  WriteLn;
  WriteLn('--- Fill Style ---');
  RIP.SetFillStyle(1, 5);
  RIP.GetFillSettings(S, C);
  Check('SetFillStyle: style = 1', S = 1);
  Check('SetFillStyle: color = 5', C = 5);
End;

// ---- Line Style ----

Procedure TestLineStyle;
Begin
  WriteLn;
  WriteLn('--- Line Style ---');
  RIP.SetLineStyle(1, $CCCC, 1);
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Line(0, 0, 100, 0);
  // Dotted line — some pixels on, some off
  Check('Dotted line: pixel at (0,0) drawn', RIP.GetPixel(0, 0) = 15);
  RIP.SetLineStyle(0, $FFFF, 1);
End;

// ---- Write Mode ----

Procedure TestWriteMode;
Var V : Byte;
Begin
  WriteLn;
  WriteLn('--- Write Mode ---');
  RIP.ClearScreen;
  RIP.PutPixel(10, 10, 15);
  RIP.SetWriteMode(1); // XOR
  RIP.PutPixel(10, 10, 15);
  RIP.SetWriteMode(0); // COPY
  V := RIP.GetPixel(10, 10);
  Check('XOR write mode: 15 XOR 15 = 0', V = 0);
End;

// ---- Text Output ----

Procedure TestOutTextXY;
Var Found : Boolean; X, Y : SmallInt;
Begin
  WriteLn;
  WriteLn('--- OutTextXY ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.OutTextXY(0, 0, 'A');
  Found := False;
  For Y := 0 to 7 Do
    For X := 0 to 7 Do
      If RIP.GetPixel(X, Y) = 15 Then Begin Found := True; Break; End;
  Check('OutTextXY: at least one pixel drawn', Found);
End;

// ---- FloodFill ----

Procedure TestFloodFill;
Begin
  WriteLn;
  WriteLn('--- FloodFill ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Rectangle(10, 10, 40, 40);
  RIP.SetFillStyle(1, 14);
  RIP.FloodFill(25, 25, 15);
  Check('FloodFill: center pixel filled', RIP.GetPixel(25, 25) = 14);
  Check('FloodFill: border preserved', RIP.GetPixel(10, 25) = 15);
End;

// ---- SaveBMP ----

Procedure TestSaveBMP;
Var OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- SaveBMP ---');
  RIP.ClearScreen;
  RIP.PutPixel(0, 0, 15);
  OK := RIP.SaveBMP('/tmp/test_v1.bmp');
  Check('SaveBMP: returns true', OK);
End;

// ---- Text Variables ----

Procedure TestTextVariables;
Var V : String;
Begin
  WriteLn;
  WriteLn('--- Text Variables ---');
  RIP.DefineVar('TEST', 'hello', False, False);
  V := RIP.GetVar('TEST');
  Check('DefineVar/GetVar: value = hello', V = 'hello');

  RIP.SetVar('TEST', 'world');
  V := RIP.GetVar('TEST');
  Check('SetVar: value = world', V = 'world');

  RIP.KillAllVars;
  V := RIP.GetVar('TEST');
  Check('KillAllVars: var gone', V = '');
End;

Procedure TestExpandVars;
Var S : String;
Begin
  WriteLn;
  WriteLn('--- ExpandVars ---');
  RIP.DefineVar('NAME', 'Mystic', False, False);
  S := RIP.ExpandVars('Hello $NAME$ BBS');
  Check('ExpandVars: $NAME$ expanded', S = 'Hello Mystic BBS');
  RIP.KillAllVars;
End;

// ---- Screen Save/Restore ----

Procedure TestScreenSaveRestore;
Begin
  WriteLn;
  WriteLn('--- Screen Save/Restore ---');
  RIP.ClearScreen;
  RIP.PutPixel(50, 50, 14);
  RIP.SaveScreen(0);

  RIP.ClearScreen;
  Check('After clear: pixel = 0', RIP.GetPixel(50, 50) = 0);

  RIP.RestoreScreen(0);
  Check('After restore: pixel = 14', RIP.GetPixel(50, 50) = 14);
End;

// ---- Mouse Fields ----

Procedure TestMouseFields;
Begin
  WriteLn;
  WriteLn('--- Mouse Fields ---');
  RIP.Reset;
  // Process a mouse field command via RIP
  RIP.ProcessLine('!|1M0A0A1E1E0100Test^cmd');
  Check('Mouse field added: FindMouseField finds it',
    RIP.FindMouseField(15, 15) > 0);
  Check('Mouse field: outside returns 0',
    RIP.FindMouseField(0, 0) = 0);
End;

// ---- ProcessLine / RIP Commands ----

Procedure TestProcessLine;
Begin
  WriteLn;
  WriteLn('--- ProcessLine ---');
  RIP.Reset;
  RIP.ClearScreen;
  // !|c0F = set color to 15
  RIP.ProcessLine('!|c0F');
  Check('ProcessLine !|c0F: color = 15', RIP.GetColor = 15);

  // !|X0A0A = PutPixel at (10,10)
  RIP.ProcessLine('!|X0A0A');
  Check('ProcessLine !|X0A0A: pixel at (10,10)', RIP.GetPixel(10, 10) = 15);
End;

Procedure TestProcessLineReset;
Begin
  WriteLn;
  WriteLn('--- ProcessLine Reset ---');
  RIP.SetColor(14);
  RIP.ProcessLine('!|*');  // reset windows
  // Reset windows doesn't change color
  RIP.ProcessLine('!|e');  // clear screen
  Check('ProcessLine !|e: screen cleared', RIP.GetPixel(100, 100) = 0);
End;

// ---- CopyRegion ----

Procedure TestCopyRegion;
Begin
  WriteLn;
  WriteLn('--- CopyRegion ---');
  RIP.ClearScreen;
  RIP.PutPixel(50, 10, 12);
  RIP.CopyRegion(40, 5, 60, 15, 100);
  Check('CopyRegion: pixel copied to dest row', RIP.GetPixel(50, 105) = 12);
End;

// ---- Font System ----

Procedure TestSysFont;
Begin
  WriteLn;
  WriteLn('--- System Font Metrics ---');
  Check('GetSysFontW > 0', RIP.GetSysFontW > 0);
  Check('GetSysFontH > 0', RIP.GetSysFontH > 0);
  Check('GetSysCols > 0', RIP.GetSysCols > 0);
  Check('GetSysRows > 0', RIP.GetSysRows > 0);
End;

// ---- Stress / Edge Cases ----

Procedure TestLargePolygon;
Var Pts : Array[0..3] of TRIPPoint;
Begin
  WriteLn;
  WriteLn('--- Polygon ---');
  RIP.ClearScreen;
  RIP.SetColor(10);
  Pts[0].X := 50;  Pts[0].Y := 10;
  Pts[1].X := 90;  Pts[1].Y := 80;
  Pts[2].X := 10;  Pts[2].Y := 80;
  Pts[3].X := 50;  Pts[3].Y := 10;
  RIP.DrawPoly(4, Pts);
  Check('DrawPoly: no crash', True);
End;

Procedure TestBar3D;
Begin
  WriteLn;
  WriteLn('--- Bar3D ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.SetFillStyle(1, 9);
  RIP.Bar3D(100, 100, 200, 200, 20, True);
  Check('Bar3D: center filled', RIP.GetPixel(150, 150) = 9);
End;

Procedure TestPieSlice;
Begin
  WriteLn;
  WriteLn('--- PieSlice ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.SetFillStyle(1, 14);
  RIP.PieSlice(200, 200, 0, 90, 50);
  Check('PieSlice: no crash', True);
End;

Procedure TestBezier;
Begin
  WriteLn;
  WriteLn('--- Bezier ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.DrawBezier(10, 10, 50, 100, 100, 100, 150, 10, 20);
  Check('DrawBezier: no crash', True);
End;

Procedure TestFileQuery;
Var R : TRIPFileQueryResult;
Begin
  WriteLn;
  WriteLn('--- FileQuery ---');
  R := RIP.FileQuery('/tmp/test_v1.bmp', 0);
  Check('FileQuery: no crash', True);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== RIPscrip v1.54 Engine — Test Suite ===');

  RIP := TRIPEngine.Create;

  TestCreateDestroy;
  TestReset;
  TestPutGetPixel;
  TestPixelOutOfBounds;
  TestAllColors;
  TestLine;
  TestLineTo;
  TestMoveRel;
  TestRectangle;
  TestBar;
  TestCircle;
  TestFillEllipse;
  TestClearScreen;
  TestClearViewport;
  TestViewport;
  TestColorAccessors;
  TestPalette;
  TestFillStyle;
  TestLineStyle;
  TestWriteMode;
  TestOutTextXY;
  TestFloodFill;
  TestSaveBMP;
  TestTextVariables;
  TestExpandVars;
  TestScreenSaveRestore;
  TestMouseFields;
  TestProcessLine;
  TestProcessLineReset;
  TestCopyRegion;
  TestSysFont;
  TestLargePolygon;
  TestBar3D;
  TestPieSlice;
  TestBezier;
  TestFileQuery;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
