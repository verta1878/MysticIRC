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
Program test_phase16_scene;
// Stress tests for Phase 16 scene file and cursor query features

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

Procedure TestSceneRoundTripNegativeCoords;
// World with negative coords should survive save/load
Var
  F    : Text;
  Line : String;
  Found: Boolean;
Begin
  WriteLn;
  WriteLn('--- Scene Round-Trip: Negative Coords ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(-500.0, -250.0, 500.0, 250.0);
  RIP.SaveScene('/tmp/test_p16_neg.rip');

  RIP.ClearWorldCoords;
  RIP.LoadScene('/tmp/test_p16_neg.rip');
  Check('Negative coords restored: world enabled', RIP.IsWorldEnabled);
  Check('Negative coords: MapX(0) ~ 319', Abs(RIP.MapX(0.0) - 319) <= 1);
  Check('Negative coords: MapX(-500) = 0', RIP.MapX(-500.0) = 0);

  RIP.ClearWorldCoords;
End;

Procedure TestSceneRoundTripAspect;
// Aspect flag should survive save/load
Begin
  WriteLn;
  WriteLn('--- Scene Round-Trip: Aspect Flag ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.SetWorldAspect(True);
  RIP.SaveScene('/tmp/test_p16_aspect.rip');

  RIP.ClearWorldCoords;
  RIP.SetWorldAspect(False);
  RIP.LoadScene('/tmp/test_p16_aspect.rip');
  Check('Aspect flag restored after load', RIP.GetWorldAspect);

  RIP.ClearWorldCoords;
End;

Procedure TestSceneRoundTripTinyCoords;
// Very small floating point coords
Begin
  WriteLn;
  WriteLn('--- Scene Round-Trip: Tiny Coords ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 0.001, 0.001);
  RIP.SaveScene('/tmp/test_p16_tiny.rip');

  RIP.ClearWorldCoords;
  RIP.LoadScene('/tmp/test_p16_tiny.rip');
  Check('Tiny coords restored: world enabled', RIP.IsWorldEnabled);
  Check('Tiny coords: MapX(0.001) = 639', RIP.MapX(0.001) = 639);

  RIP.ClearWorldCoords;
End;

Procedure TestSceneRoundTripHugeCoords;
// Enormous coords
Begin
  WriteLn;
  WriteLn('--- Scene Round-Trip: Huge Coords ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(-1e6, -1e6, 1e6, 1e6);
  RIP.SaveScene('/tmp/test_p16_huge.rip');

  RIP.ClearWorldCoords;
  RIP.LoadScene('/tmp/test_p16_huge.rip');
  Check('Huge coords restored: world enabled', RIP.IsWorldEnabled);
  Check('Huge coords: MapX(0) ~ 319', Abs(RIP.MapX(0.0) - 319) <= 1);

  RIP.ClearWorldCoords;
End;

Procedure TestScenePixelsPreserved;
// After save/load with world coords, pixels should be present
Var
  V : Byte;
Begin
  WriteLn;
  WriteLn('--- Scene Pixels Preserved with World Coords ---');

  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 639.0, 349.0);
  RIP.SetColor(14);
  RIP.WPutPixel(100.0, 50.0, 14);
  RIP.SaveScene('/tmp/test_p16_pixels.rip');

  RIP.ClearScreen;
  RIP.ClearWorldCoords;
  RIP.LoadScene('/tmp/test_p16_pixels.rip');

  V := RIP.GetPixel(100, 50);
  Check('Pixel preserved after save/load', V = 14);

  RIP.ClearWorldCoords;
End;

Procedure TestCursorQueryMultipleTimes;
// Multiple cursor queries should not crash or accumulate
Begin
  WriteLn;
  WriteLn('--- Multiple Cursor Queries ---');

  RIP.ProcessLine('!|1q');
  RIP.ProcessLine('!|1q');
  RIP.ProcessLine('!|1q');
  RIP.ProcessLine('!|1q');
  RIP.ProcessLine('!|1q');
  Check('5 cursor queries: no crash', True);
  Check('Still detected', RIP.IsTextAreaDetected);
End;

Procedure TestCursorQueryAfterReset;
// Reset should clear text area detection
Begin
  WriteLn;
  WriteLn('--- Cursor Query After Reset ---');

  RIP.ProcessLine('!|1q');
  Check('Detected before reset', RIP.IsTextAreaDetected);

  RIP.Reset;
  Check('Not detected after reset', Not RIP.IsTextAreaDetected);
End;

Procedure TestCursorQueryWithCustomTextWindow;
// Various text window sizes
Begin
  WriteLn;
  WriteLn('--- Cursor Query With Custom Windows ---');

  // 1x1 window
  RIP.SetTextWindow(0, 0, 0, 0, 0);
  RIP.ProcessLine('!|1q');
  Check('1x1 window: W=1', RIP.GetTextAreaW = 1);
  Check('1x1 window: H=1', RIP.GetTextAreaH = 1);

  // Max window
  RIP.SetTextWindow(0, 0, 79, 42, 0);
  RIP.ProcessLine('!|1q');
  Check('80x43 window: W=80', RIP.GetTextAreaW = 80);
  Check('80x43 window: H=43', RIP.GetTextAreaH = 43);

  // Offset window
  RIP.SetTextWindow(10, 5, 49, 24, 0);
  RIP.ProcessLine('!|1q');
  Check('Offset window: W=40', RIP.GetTextAreaW = 40);
  Check('Offset window: H=20', RIP.GetTextAreaH = 20);
End;

Procedure TestMalformedWorldCommand;
// Bad |1z commands should not crash
Begin
  WriteLn;
  WriteLn('--- Malformed |1z Commands ---');

  RIP.ClearWorldCoords;

  // Empty
  RIP.ProcessLine('!|1z');
  Check('Empty |1z: world stays disabled', Not RIP.IsWorldEnabled);

  // Just one number
  RIP.ProcessLine('!|1z50');
  Check('Partial |1z (one number): no crash', True);

  // Two numbers
  RIP.ProcessLine('!|1z10:20');
  Check('Partial |1z (two numbers): no crash', True);

  // Three numbers
  RIP.ProcessLine('!|1z10:20:30');
  Check('Partial |1z (three numbers): no crash', True);

  // Non-numeric
  RIP.ProcessLine('!|1zabc:def:ghi:jkl');
  Check('Non-numeric |1z: no crash', True);

  // Extra colons
  RIP.ProcessLine('!|1z0:0:100:100:::');
  Check('Extra colons: no crash', True);

  // Valid after malformed — should still work
  RIP.ProcessLine('!|1z0.0:0.0:100.0:100.0');
  Check('Valid |1z after malformed: world enabled', RIP.IsWorldEnabled);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldCoordsWithAllWriteModes;
// World coord drawing with each write mode
Var
  V : Byte;
Begin
  WriteLn;
  WriteLn('--- World Coords + Write Modes ---');

  RIP.SetWorldCoords(0.0, 0.0, 639.0, 349.0);
  RIP.ClearScreen;

  // COPY
  RIP.SetWriteMode(RIP_COPY_PUT);
  RIP.WPutPixel(10.0, 10.0, 15);
  Check('World COPY: pixel = 15', RIP.GetPixel(10, 10) = 15);

  // XOR
  RIP.SetWriteMode(RIP_XOR_PUT);
  RIP.WPutPixel(10.0, 10.0, 15);
  RIP.SetWriteMode(RIP_COPY_PUT);
  Check('World XOR: 15 XOR 15 = 0', RIP.GetPixel(10, 10) = 0);

  // OR
  RIP.WPutPixel(20.0, 20.0, 3);
  RIP.SetWriteMode(RIP_OR_PUT);
  RIP.WPutPixel(20.0, 20.0, 12);
  RIP.SetWriteMode(RIP_COPY_PUT);
  Check('World OR: 3 OR 12 = 15', RIP.GetPixel(20, 20) = 15);

  // AND
  RIP.WPutPixel(30.0, 30.0, 15);
  RIP.SetWriteMode(RIP_AND_PUT);
  RIP.WPutPixel(30.0, 30.0, 5);
  RIP.SetWriteMode(RIP_COPY_PUT);
  Check('World AND: 15 AND 5 = 5', RIP.GetPixel(30, 30) = 5);

  // AND Color=7 guard
  RIP.WPutPixel(40.0, 40.0, 14);
  RIP.SetWriteMode(RIP_AND_PUT);
  RIP.WPutPixel(40.0, 40.0, 7);
  RIP.SetWriteMode(RIP_COPY_PUT);
  Check('World AND Color=7: no-op guard', RIP.GetPixel(40, 40) = 14);

  RIP.ClearWorldCoords;
End;

Procedure TestWorldCoordsRGBSceneRoundTrip;
// World coords + RGB mode + scene save/load
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- World + RGB + Scene Round-Trip ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.SetColor(11);
  RIP.WLine(0.0, 0.0, 100.0, 100.0);

  // Verify pixel exists in RGB
  Got := RIP.GetPixelRGB(319, 174);
  Check('World+RGB line: center pixel drawn', Got.G > 0);

  // Save — note SaveScene writes pixel-by-pixel from indexed buffer
  RIP.SaveScene('/tmp/test_p16_rgb_world.rip');
  Check('SaveScene in RGB+World: no crash', True);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearWorldCoords;
End;

Procedure TestSceneSaveLoadMultiple;
// Save and load multiple times
Var
  I : Integer;
Begin
  WriteLn;
  WriteLn('--- Multiple Save/Load Cycles ---');

  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.WPutPixel(50.0, 50.0, 15);

  For I := 1 to 10 Do Begin
    RIP.SaveScene('/tmp/test_p16_multi.rip');
    RIP.ClearScreen;
    RIP.ClearWorldCoords;
    RIP.LoadScene('/tmp/test_p16_multi.rip');
  End;

  Check('10 save/load cycles: world still enabled', RIP.IsWorldEnabled);
  Check('10 save/load cycles: pixel preserved',
    RIP.GetPixel(RIP.MapX(50.0), RIP.MapY(50.0)) = 15);

  RIP.ClearWorldCoords;
End;

Procedure TestCursorQueryCombinedWithWorld;
// Both features active simultaneously
Begin
  WriteLn;
  WriteLn('--- Cursor Query + World Coords Together ---');

  RIP.SetWorldCoords(0.0, 0.0, 999.0, 999.0);
  RIP.ProcessLine('!|1q');

  Check('Both active: world enabled', RIP.IsWorldEnabled);
  Check('Both active: text area detected', RIP.IsTextAreaDetected);
  Check('Both active: MapX(500) ~ 319', Abs(RIP.MapX(500.0) - 319) <= 1);

  RIP.ClearWorldCoords;
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 16: SCENE & CURSOR STRESS TESTS ===');

  RIP := TRIPEngine.Create;

  TestSceneRoundTripNegativeCoords;
  TestSceneRoundTripAspect;
  TestSceneRoundTripTinyCoords;
  TestSceneRoundTripHugeCoords;
  TestScenePixelsPreserved;
  TestCursorQueryMultipleTimes;
  TestCursorQueryAfterReset;
  TestCursorQueryWithCustomTextWindow;
  TestMalformedWorldCommand;
  TestWorldCoordsWithAllWriteModes;
  TestWorldCoordsRGBSceneRoundTrip;
  TestSceneSaveLoadMultiple;
  TestCursorQueryCombinedWithWorld;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
