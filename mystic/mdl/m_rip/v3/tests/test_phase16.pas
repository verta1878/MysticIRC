{$H-}
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
Program test_phase16;
// Phase 16: World Coordinate System — verification tests

Uses rip3api;

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

Procedure TestWorldDefaults;
Begin
  WriteLn;
  WriteLn('--- World Coordinate Defaults ---');

  Check('World disabled by default', Not RIP.IsWorldEnabled);
  Check('Aspect preserve off by default', Not RIP.GetWorldAspect);
End;

Procedure TestSetWorldCoords;
Begin
  WriteLn;
  WriteLn('--- SetWorldCoords / ClearWorldCoords ---');

  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  Check('World enabled after SetWorldCoords', RIP.IsWorldEnabled);

  RIP.ClearWorldCoords;
  Check('World disabled after ClearWorldCoords', Not RIP.IsWorldEnabled);
End;

Procedure TestBasicMapping;
// World (0..100, 0..100) mapped to default 640x350 viewport
Begin
  WriteLn;
  WriteLn('--- Basic Coordinate Mapping ---');

  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);

  // (0,0) should map to viewport origin (0,0)
  Check('MapX(0) = 0', RIP.MapX(0.0) = 0);
  Check('MapY(0) = 0', RIP.MapY(0.0) = 0);

  // (100,100) should map to (639,349)
  Check('MapX(100) = 639', RIP.MapX(100.0) = 639);
  Check('MapY(100) = 349', RIP.MapY(100.0) = 349);

  // (50,50) should map to center
  Check('MapX(50) = 319', RIP.MapX(50.0) = 319);
  Check('MapY(50) = 174', RIP.MapY(50.0) = 174);

  RIP.ClearWorldCoords;
End;

Procedure TestUnmap;
// Reverse mapping: pixel to world
Var
  WX, WY : Real;
Begin
  WriteLn;
  WriteLn('--- Reverse Mapping (Unmap) ---');

  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);

  WX := RIP.UnmapX(0);
  Check('UnmapX(0) ~ 0.0', Abs(WX) < 0.5);

  WX := RIP.UnmapX(639);
  Check('UnmapX(639) ~ 100.0', Abs(WX - 100.0) < 0.5);

  WY := RIP.UnmapY(174);
  Check('UnmapY(174) ~ 49-50', (WY > 48.0) and (WY < 51.0));

  RIP.ClearWorldCoords;
End;

Procedure TestWorldPixelDraw;
// Draw a pixel using world coordinates and verify it lands correctly
Var
  PX, PY : SmallInt;
Begin
  WriteLn;
  WriteLn('--- WPutPixel ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 639.0, 349.0);

  // 1:1 mapping — world coords = pixel coords
  RIP.WPutPixel(100.0, 50.0, 14);
  Check('WPutPixel 1:1: pixel at (100,50)', RIP.GetPixel(100, 50) = 14);

  // 10x scale — world (0..64, 0..35) maps to (0..639, 0..349)
  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 64.0, 35.0);
  RIP.WPutPixel(32.0, 17.5, 12);
  PX := RIP.MapX(32.0);
  PY := RIP.MapY(17.5);
  Check('WPutPixel 10x: pixel at mapped location',
    RIP.GetPixel(PX, PY) = 12);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldLine;
Begin
  WriteLn;
  WriteLn('--- WLine ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 1.0, 1.0);
  RIP.SetColor(15);

  // Diagonal line across entire screen
  RIP.WLine(0.0, 0.0, 1.0, 1.0);

  // Origin and endpoint should have pixels
  Check('WLine: pixel at (0,0)', RIP.GetPixel(0, 0) = 15);
  Check('WLine: pixel at (639,349)', RIP.GetPixel(639, 349) = 15);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldRectangle;
Begin
  WriteLn;
  WriteLn('--- WRectangle ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.SetColor(10);

  RIP.WRectangle(10.0, 10.0, 90.0, 90.0);

  // Check corners of the rectangle are drawn
  Check('WRectangle: top-left pixel',
    RIP.GetPixel(RIP.MapX(10.0), RIP.MapY(10.0)) = 10);
  Check('WRectangle: top-right pixel',
    RIP.GetPixel(RIP.MapX(90.0), RIP.MapY(10.0)) = 10);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldBar;
Begin
  WriteLn;
  WriteLn('--- WBar ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.SetFillStyle(1, 13);  // solid, bright magenta

  RIP.WBar(25.0, 25.0, 75.0, 75.0);

  // Center of bar should be filled
  Check('WBar: center pixel filled',
    RIP.GetPixel(RIP.MapX(50.0), RIP.MapY(50.0)) = 13);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldCircle;
Var
  CX, CY, PR : SmallInt;
  Found       : Boolean;
  X           : SmallInt;
Begin
  WriteLn;
  WriteLn('--- WCircle ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.SetColor(9);

  RIP.WCircle(50.0, 50.0, 20.0);

  CX := RIP.MapX(50.0);
  CY := RIP.MapY(50.0);
  // Radius maps via X scale
  PR := Abs(Trunc(20.0 * (639) / 100.0));

  // Check for pixel at the top of the circle (CY - PR)
  Found := False;
  For X := CX - 5 to CX + 5 Do
    If (X >= 0) and (X <= 639) and (CY - PR >= 0) Then
      If RIP.GetPixel(X, CY - PR) = 9 Then Begin
        Found := True;
        Break;
      End;
  Check('WCircle: pixel near top of circle', Found);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldText;
Var
  Found : Boolean;
  X, Y  : SmallInt;
Begin
  WriteLn;
  WriteLn('--- WOutTextXY ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 639.0, 349.0);
  RIP.SetColor(15);

  RIP.WOutTextXY(100.0, 100.0, 'A');

  // At least one white pixel near (100,100)
  Found := False;
  For Y := 100 to 108 Do
    For X := 100 to 108 Do
      If RIP.GetPixel(X, Y) = 15 Then Begin
        Found := True;
        Break;
      End;
  Check('WOutTextXY: text rendered at world position', Found);

  RIP.ClearWorldCoords;
End;

Procedure TestAspectPreserve;
// With aspect on, a square world should map to a square on screen
Var
  PX1, PY1, PX2, PY2 : SmallInt;
  PixW, PixH : SmallInt;
Begin
  WriteLn;
  WriteLn('--- Aspect Ratio Preservation ---');

  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.SetWorldAspect(True);

  PX1 := RIP.MapX(0.0);
  PY1 := RIP.MapY(0.0);
  PX2 := RIP.MapX(100.0);
  PY2 := RIP.MapY(100.0);
  PixW := PX2 - PX1;
  PixH := PY2 - PY1;

  // With aspect preserve, pixel width and height should be equal
  // (the smaller dimension constrains both)
  Check('Aspect preserve: pixel W = pixel H', PixW = PixH);

  RIP.SetWorldAspect(False);
  RIP.ClearWorldCoords;
End;

Procedure TestNegativeWorldCoords;
// World coords can be negative
Begin
  WriteLn;
  WriteLn('--- Negative World Coordinates ---');

  RIP.SetWorldCoords(-50.0, -50.0, 50.0, 50.0);

  Check('MapX(-50) = 0', RIP.MapX(-50.0) = 0);
  Check('MapX(0) ~ 319', Abs(RIP.MapX(0.0) - 319) <= 1);
  Check('MapX(50) = 639', RIP.MapX(50.0) = 639);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldDisabledPassthrough;
// When world coords disabled, W* methods should use coords as pixels
Begin
  WriteLn;
  WriteLn('--- World Disabled Passthrough ---');

  RIP.ClearWorldCoords;
  RIP.ClearScreen;

  RIP.WPutPixel(200.0, 100.0, 11);
  Check('World disabled: WPutPixel acts as PutPixel',
    RIP.GetPixel(200, 100) = 11);

  Check('World disabled: MapX passthrough', RIP.MapX(42.0) = 42);
  Check('World disabled: MapY passthrough', RIP.MapY(99.0) = 99);
End;

Procedure TestViewportMapping;
// World coords should map to the current viewport, not full canvas
Begin
  WriteLn;
  WriteLn('--- Viewport-Relative Mapping ---');

  RIP.SetViewPort(100, 50, 500, 300, True);
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);

  Check('MapX(0) = viewport left (100)', RIP.MapX(0.0) = 100);
  Check('MapY(0) = viewport top (50)', RIP.MapY(0.0) = 50);
  Check('MapX(100) = viewport right (500)', RIP.MapX(100.0) = 500);
  Check('MapY(100) = viewport bottom (300)', RIP.MapY(100.0) = 300);

  RIP.SetViewPort(0, 0, 639, 349, True);
  RIP.ClearWorldCoords;
End;

Procedure TestLargeCoordinates;
// ANSI cursor query support: coordinates up to 999,999
Begin
  WriteLn;
  WriteLn('--- Large Coordinates (999999) ---');

  RIP.SetWorldCoords(0.0, 0.0, 999999.0, 999999.0);

  // Should not overflow — clamped to SmallInt range
  Check('MapX(999999) does not crash', RIP.MapX(999999.0) = 639);
  Check('MapX(500000) ~ 319', Abs(RIP.MapX(500000.0) - 319) <= 1);
  Check('MapY(0) = 0', RIP.MapY(0.0) = 0);

  RIP.ClearWorldCoords;
End;

Procedure TestSceneWorldCoords;
Var
  F    : Text;
  Line : String;
  Found: Boolean;
Begin
  WriteLn;
  WriteLn('--- Scene File World Coordinates ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(-10.0, -10.0, 10.0, 10.0);
  RIP.SetColor(15);
  RIP.WPutPixel(0.0, 0.0, 15);
  RIP.SaveScene('/tmp/test_p16_world.rip');

  Assign(F, '/tmp/test_p16_world.rip');
  {$I-} System.Reset(F); {$I+}
  Found := False;
  If IOResult = 0 Then Begin
    While Not Eof(F) Do Begin
      ReadLn(F, Line);
      If Pos('|1z', Line) > 0 Then Begin
        Found := True;
        Break;
      End;
    End;
    Close(F);
  End;
  Check('SaveScene emits |1z world coord command', Found);

  RIP.ClearWorldCoords;
  RIP.LoadScene('/tmp/test_p16_world.rip');
  Check('LoadScene restores world coords', RIP.IsWorldEnabled);

  RIP.ClearWorldCoords;
End;

Procedure TestSceneNoWorldCoords;
Var
  F    : Text;
  Line : String;
  Found: Boolean;
Begin
  WriteLn;
  WriteLn('--- Scene File Without World Coordinates ---');

  RIP.ClearWorldCoords;
  RIP.ClearScreen;
  RIP.PutPixel(100, 100, 14);
  RIP.SaveScene('/tmp/test_p16_noworld.rip');

  Assign(F, '/tmp/test_p16_noworld.rip');
  {$I-} System.Reset(F); {$I+}
  Found := False;
  If IOResult = 0 Then Begin
    While Not Eof(F) Do Begin
      ReadLn(F, Line);
      If Pos('|1z', Line) > 0 Then Begin
        Found := True;
        Break;
      End;
    End;
    Close(F);
  End;
  Check('SaveScene without world: no |1z command', Not Found);
End;

Procedure TestCursorQuery;
Begin
  WriteLn;
  WriteLn('--- Cursor Position Query ---');

  Check('TextArea not detected initially', Not RIP.IsTextAreaDetected);
  RIP.ProcessLine('!|1q');
  Check('TextArea detected after |1q', RIP.IsTextAreaDetected);
  Check('TextAreaW = 80 (default)', RIP.GetTextAreaW = 80);
  Check('TextAreaH = 43 (default)', RIP.GetTextAreaH = 43);

  RIP.SetTextWindow(0, 0, 39, 24, 0);
  RIP.ProcessLine('!|1q');
  Check('TextAreaW = 40 after resize', RIP.GetTextAreaW = 40);
  Check('TextAreaH = 25 after resize', RIP.GetTextAreaH = 25);
End;

Procedure TestWorldCoordsViaRIPCommand;
Begin
  WriteLn;
  WriteLn('--- World Coords via RIP Command ---');

  RIP.ClearWorldCoords;
  RIP.ProcessLine('!|1z0.0:0.0:100.0:100.0');
  Check('|1z enables world coords', RIP.IsWorldEnabled);
  Check('|1z MapX(50) ~ 319', Abs(RIP.MapX(50.0) - 319) <= 1);

  RIP.ProcessLine('!|1z0.0:0.0:100.0:100.0:A');
  Check('|1z with :A enables aspect', RIP.GetWorldAspect);

  RIP.ProcessLine('!|1z0:0:0:0');
  Check('|1z 0:0:0:0 clears world', Not RIP.IsWorldEnabled);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 16: World Coordinate System — Verification Tests ===');

  RIP := TRIPEngine.Create;

  TestWorldDefaults;
  TestSetWorldCoords;
  TestBasicMapping;
  TestUnmap;
  TestWorldPixelDraw;
  TestWorldLine;
  TestWorldRectangle;
  TestWorldBar;
  TestWorldCircle;
  TestWorldText;
  TestAspectPreserve;
  TestNegativeWorldCoords;
  TestWorldDisabledPassthrough;
  TestViewportMapping;
  TestLargeCoordinates;
  TestSceneWorldCoords;
  TestSceneNoWorldCoords;
  TestCursorQuery;
  TestWorldCoordsViaRIPCommand;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
