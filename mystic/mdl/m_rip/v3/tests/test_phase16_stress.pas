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
Program test_phase16_stress;
// Stress tests and edge cases — try to break Phase 16

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

Procedure TestZeroSizeWorld;
Begin
  WriteLn;
  WriteLn('--- Zero-Size World (divide by zero guard) ---');

  RIP.SetWorldCoords(50.0, 50.0, 50.0, 50.0);
  RIP.MapX(50.0);
  RIP.MapY(50.0);
  Check('Zero-size world: survived', True);

  RIP.SetWorldCoords(100.0, 0.0, 100.0, 100.0);
  RIP.MapX(100.0);
  RIP.MapY(50.0);
  Check('Zero-width world: survived', True);

  RIP.SetWorldCoords(0.0, 75.0, 100.0, 75.0);
  RIP.MapX(50.0);
  RIP.MapY(75.0);
  Check('Zero-height world: survived', True);

  RIP.ClearWorldCoords;
End;

Procedure TestInvertedWorld;
Begin
  WriteLn;
  WriteLn('--- Inverted World Coordinates ---');

  RIP.SetWorldCoords(100.0, 0.0, 0.0, 100.0);
  Check('Inverted X: MapX(100) = 0', RIP.MapX(100.0) = 0);
  Check('Inverted X: MapX(0) = 639', RIP.MapX(0.0) = 639);

  RIP.SetWorldCoords(0.0, 100.0, 100.0, 0.0);
  Check('Inverted Y: MapY(100) = 0', RIP.MapY(100.0) = 0);
  Check('Inverted Y: MapY(0) = 349', RIP.MapY(0.0) = 349);

  RIP.SetWorldCoords(100.0, 100.0, 0.0, 0.0);
  Check('Both inverted: MapX(0) = 639', RIP.MapX(0.0) = 639);
  Check('Both inverted: MapY(0) = 349', RIP.MapY(0.0) = 349);

  RIP.ClearWorldCoords;
End;

Procedure TestExtremeWorldRange;
Begin
  WriteLn;
  WriteLn('--- Extreme World Ranges ---');

  RIP.SetWorldCoords(-1e6, -1e6, 1e6, 1e6);
  Check('Huge range: MapX(0) ~ 319', Abs(RIP.MapX(0.0) - 319) <= 1);
  Check('Huge range: MapY(0) ~ 174', Abs(RIP.MapY(0.0) - 174) <= 1);
  Check('Huge range: MapX(-1e6) = 0', RIP.MapX(-1e6) = 0);

  RIP.SetWorldCoords(0.0, 0.0, 0.001, 0.001);
  Check('Tiny range: MapX(0) = 0', RIP.MapX(0.0) = 0);
  Check('Tiny range: MapX(0.001) = 639', RIP.MapX(0.001) = 639);
  Check('Tiny range: MapX(0.0005) ~ 319', Abs(RIP.MapX(0.0005) - 319) <= 1);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldOutOfBounds;
Var
  PX : SmallInt;
Begin
  WriteLn;
  WriteLn('--- World Coords Outside Range ---');

  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);

  PX := RIP.MapX(-10000.0);
  Check('MapX(-10000) clamped negative', PX < 0);

  PX := RIP.MapX(10000.0);
  Check('MapX(10000) clamped large', PX > 639);

  RIP.ClearScreen;
  RIP.WPutPixel(-50.0, -50.0, 15);
  RIP.WPutPixel(200.0, 200.0, 15);
  Check('WPutPixel outside range did not crash', True);

  RIP.WLine(-100.0, -100.0, 200.0, 200.0);
  Check('WLine outside range did not crash', True);

  RIP.WRectangle(-10.0, -10.0, 110.0, 110.0);
  Check('WRectangle outside range did not crash', True);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldWithResolutionChange;
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- World Coords + Resolution Change ---');

  RIP.SetResolution(800, 600);
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);

  Check('MapX(100) = 799 at 800x600', RIP.MapX(100.0) = 799);
  Check('MapY(100) = 599 at 800x600', RIP.MapY(100.0) = 599);
  Check('MapX(50) ~ 399 at 800x600', Abs(RIP.MapX(50.0) - 399) <= 1);

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.WPutPixel(50.0, 50.0, 14);
  Got := RIP.GetPixelRGB(RIP.MapX(50.0), RIP.MapY(50.0));
  Check('WPutPixel at 800x600: yellow', Got.G = EGA_RGB[14].G);

  RIP.SetResolution(640, 350);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearWorldCoords;
End;

Procedure TestAspectWithNonSquareCanvas;
Var
  PX0, PX1, PY0, PY1, PixW, PixH : SmallInt;
  ScaleX, ScaleY : Real;
Begin
  WriteLn;
  WriteLn('--- Aspect Preserve Non-Square Canvas ---');

  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.SetWorldAspect(True);

  PX0 := RIP.MapX(0.0);
  PX1 := RIP.MapX(100.0);
  PY0 := RIP.MapY(0.0);
  PY1 := RIP.MapY(100.0);
  PixW := PX1 - PX0;
  PixH := PY1 - PY0;

  Check('Aspect square world: pixel W = pixel H', PixW = PixH);
  Check('Aspect square world: Y uses full height', PixH = 349);
  Check('Aspect square world: X is centered', PX0 > 0);

  // Wide world
  RIP.SetWorldCoords(0.0, 0.0, 200.0, 100.0);
  PX0 := RIP.MapX(0.0);
  PX1 := RIP.MapX(200.0);
  PY0 := RIP.MapY(0.0);
  PY1 := RIP.MapY(100.0);
  PixW := PX1 - PX0;
  PixH := PY1 - PY0;
  ScaleX := PixW / 200.0;
  ScaleY := PixH / 100.0;
  Check('Aspect wide: scale per unit X ~ Y', Abs(ScaleX - ScaleY) < 0.5);

  RIP.SetWorldAspect(False);
  RIP.ClearWorldCoords;
End;

Procedure TestRapidWorldSwitching;
Var
  I : Integer;
Begin
  WriteLn;
  WriteLn('--- Rapid World On/Off (200 cycles) ---');

  RIP.ClearScreen;
  For I := 1 to 200 Do Begin
    RIP.SetWorldCoords(0.0, 0.0, 1.0 * I, 1.0 * I);
    RIP.WPutPixel(1.0 * I / 2.0, 1.0 * I / 2.0, I mod 16);
    RIP.ClearWorldCoords;
    RIP.PutPixel(320, 175, I mod 16);
  End;
  Check('200 world on/off cycles survived', True);
End;

Procedure TestWorldFloodFill;
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- WFloodFill ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.SetColor(15);
  RIP.WRectangle(40.0, 40.0, 60.0, 60.0);
  RIP.SetFillStyle(1, 14);
  RIP.WFloodFill(50.0, 50.0, 15);

  Got := RIP.GetPixelRGB(RIP.MapX(50.0), RIP.MapY(50.0));
  Check('WFloodFill: center pixel filled', Got.G = EGA_RGB[14].G);

  RIP.ClearWorldCoords;
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestWorldBezier;
Var
  Found : Boolean;
  X     : SmallInt;
Begin
  WriteLn;
  WriteLn('--- WDrawBezier ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.SetColor(11);
  RIP.WDrawBezier(0.0, 50.0, 33.0, 0.0, 66.0, 100.0, 100.0, 50.0, 30);

  Found := False;
  For X := 200 to 400 Do
    If RIP.GetPixel(X, RIP.MapY(50.0)) = 11 Then Begin
      Found := True;
      Break;
    End;
  Check('WDrawBezier: pixels along curve', Found);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldEllipse;
Var
  Found : Boolean;
  X     : SmallInt;
  CX, CY : SmallInt;
Begin
  WriteLn;
  WriteLn('--- WEllipse / WFillEllipse ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.SetColor(12);
  RIP.WEllipse(50.0, 50.0, 0, 360, 30.0, 15.0);

  CX := RIP.MapX(50.0);
  CY := RIP.MapY(50.0);

  Found := False;
  For X := CX to CX + 250 Do
    If (X >= 0) and (X <= 639) Then
      If RIP.GetPixel(X, CY) = 12 Then Begin
        Found := True;
        Break;
      End;
  Check('WEllipse: pixels on right edge', Found);

  RIP.ClearScreen;
  RIP.SetColor(9);
  RIP.WFillEllipse(50.0, 50.0, 20.0, 10.0);
  Check('WFillEllipse: center pixel filled', RIP.GetPixel(CX, CY) = 9);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldMoveLineTo;
Begin
  WriteLn;
  WriteLn('--- WMoveTo / WLineTo ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 639.0, 349.0);
  RIP.SetColor(15);
  RIP.WMoveTo(100.0, 100.0);
  RIP.WLineTo(200.0, 100.0);
  RIP.WLineTo(200.0, 200.0);

  Check('WLineTo: pixel at (150,100)', RIP.GetPixel(150, 100) = 15);
  Check('WLineTo: pixel at (200,150)', RIP.GetPixel(200, 150) = 15);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldPutPixelRGB;
Var
  Got : TRIPRgb;
  RGB : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- WPutPixelRGB ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 639.0, 349.0);

  RGB.R := 128; RGB.G := 64; RGB.B := 32;
  RIP.WPutPixelRGB(300.0, 200.0, RGB);

  Got := RIP.GetPixelRGB(300, 200);
  Check('WPutPixelRGB: R', Got.R = 128);
  Check('WPutPixelRGB: G', Got.G = 64);
  Check('WPutPixelRGB: B', Got.B = 32);

  RIP.ClearWorldCoords;
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestUnmapRoundTrip;
Var
  WX, WY    : Real;
  PX, PY    : SmallInt;
  WX2, WY2  : Real;
Begin
  WriteLn;
  WriteLn('--- Map/Unmap Round-Trip ---');

  RIP.SetWorldCoords(-100.0, -200.0, 300.0, 500.0);

  WX := 42.7;
  WY := 123.4;
  PX := RIP.MapX(WX);
  PY := RIP.MapY(WY);
  WX2 := RIP.UnmapX(PX);
  WY2 := RIP.UnmapY(PY);

  Check('Round-trip X within 2 units', Abs(WX2 - WX) < 2.0);
  Check('Round-trip Y within 2 units', Abs(WY2 - WY) < 2.0);

  RIP.ClearWorldCoords;
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 16: STRESS TESTS — Try to Break It ===');

  RIP := TRIPEngine.Create;

  TestZeroSizeWorld;
  TestInvertedWorld;
  TestExtremeWorldRange;
  TestWorldOutOfBounds;
  TestWorldWithResolutionChange;
  TestAspectWithNonSquareCanvas;
  TestRapidWorldSwitching;
  TestWorldFloodFill;
  TestWorldBezier;
  TestWorldEllipse;
  TestWorldMoveLineTo;
  TestWorldPutPixelRGB;
  TestUnmapRoundTrip;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
