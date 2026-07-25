{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// RIPscrip v2.0 Engine Stress Tests — 35 tests
// Compile: ppcx64 -Mdelphi -Fu<path-to-mystic_ripapi2> -Fu<path>/img -Fu<path>/pasjpeg test_v2_stress.pas
//
// Edge cases and adversarial inputs:
//   Rapid resolution switching (5 changes),
//   Scroll edge cases (amt=0, negative, oversized),
//   PalFade extremes (0%, 100%, -50%, 200%),
//   LineAA edge cases (zero-length, OOB),
//   LoadAnimFrame nonexistent, FrameRate extremes,
//   Malformed v2.0 commands (11 commands with no params),
//   SaveBMP at non-default resolution,
//   Full screen pixel fill (640x350),
//   Negative coordinates (Line, Rect, Circle, FloodFill),
//   1000 rapid color changes, 10 LoadRFF cycles,
//   20 extended buttons stress
//
Program test_v2_stress;

Uses rip2api;

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

Procedure TestResolutionSwitching;
Begin
  WriteLn;
  WriteLn('--- Rapid Resolution Switching ---');
  RIP.SetResolution(800, 600);
  RIP.PutPixel(799, 599, 15);
  RIP.SetResolution(640, 350);
  RIP.SetResolution(1024, 768);
  RIP.PutPixel(1023, 767, 14);
  RIP.SetResolution(320, 200);
  RIP.SetResolution(640, 350);
  Check('5 resolution switches: no crash', True);
End;

Procedure TestScrollEdgeCases;
Begin
  WriteLn;
  WriteLn('--- Scroll Edge Cases ---');
  RIP.ClearScreen;
  RIP.PutPixel(50, 50, 15);
  RIP.ScrollUp(0, 0, 100, 100, 0, 0);
  Check('ScrollUp amt=0: no-op', RIP.GetPixel(50, 50) = 15);
  RIP.ScrollUp(0, 0, 100, 100, -5, 0);
  Check('ScrollUp amt=-5: no-op', RIP.GetPixel(50, 50) = 15);
  RIP.ScrollUp(0, 0, 100, 100, 200, 0);
  Check('ScrollUp amt>region: no crash', True);
End;

Procedure TestPalFadeExtremes;
Begin
  WriteLn;
  WriteLn('--- PalFade Extremes ---');
  RIP.PalFade(0, 255, 0);
  Check('PalFade 0%: no crash', True);
  RIP.PalFade(0, 255, 100);
  Check('PalFade 100%: no crash', True);
  RIP.PalFade(0, 255, -50);
  Check('PalFade -50%: no crash', True);
  RIP.PalFade(0, 255, 200);
  Check('PalFade 200%: no crash', True);
End;

Procedure TestLineAAEdge;
Begin
  WriteLn;
  WriteLn('--- LineAA Edge Cases ---');
  RIP.ClearScreen;
  RIP.LineAA(0, 0, 0, 0, 15);
  Check('LineAA zero-length: no crash', True);
  RIP.LineAA(-100, -100, 700, 400, 15);
  Check('LineAA across entire canvas + OOB: no crash', True);
End;

Procedure TestAnimFrameNonexistent;
Var OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- LoadAnimFrame Nonexistent ---');
  OK := RIP.LoadAnimFrame('/tmp/NOFILE', 1, 0, 0);
  Check('LoadAnimFrame nonexistent: returns false', Not OK);
End;

Procedure TestFrameRate;
Begin
  WriteLn;
  WriteLn('--- Frame Rate ---');
  RIP.SetFrameRate(0);
  Check('FPS 0: no crash', True);
  RIP.SetFrameRate(60);
  Check('FPS 60', RIP.GetFrameRate = 60);
  RIP.SetFrameRate(-1);
  Check('FPS -1: no crash', True);
  RIP.SetFrameRate(1000);
  Check('FPS 1000: no crash', True);
End;

Procedure TestMalformedV2Commands;
Begin
  WriteLn;
  WriteLn('--- Malformed v2.0 Commands ---');
  RIP.ProcessLine('!|J');
  Check('|J no params: no crash', True);
  RIP.ProcessLine('!|n');
  Check('|n no params: no crash', True);
  RIP.ProcessLine('!|M');
  Check('|M no params: no crash', True);
  RIP.ProcessLine('!|k');
  Check('|k no params: no crash', True);
  RIP.ProcessLine('!|K');
  Check('|K no params: no crash', True);
  RIP.ProcessLine('!|f');
  Check('|f no params: no crash', True);
  RIP.ProcessLine('!|y');
  Check('|y no params: no crash', True);
  RIP.ProcessLine('!|x');
  Check('|x no params: no crash', True);
  RIP.ProcessLine('!|1b');
  Check('|1b no params: no crash', True);
  RIP.ProcessLine('!|1i');
  Check('|1i no params: no crash', True);
  RIP.ProcessLine('!|1p');
  Check('|1p no params: no crash', True);
End;

Procedure TestSaveBMPAtDifferentResolutions;
Var OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- SaveBMP at Different Resolutions ---');
  RIP.SetResolution(800, 600);
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Line(0, 0, 799, 599);
  OK := RIP.SaveBMP('/tmp/test_v2_800x600.bmp');
  Check('SaveBMP 800x600', OK);
  RIP.SetResolution(640, 350);
End;

Procedure TestMassivePixelFill;
Var X, Y : SmallInt;
Begin
  WriteLn;
  WriteLn('--- Full Screen Fill ---');
  RIP.ClearScreen;
  For Y := 0 to 349 Do
    For X := 0 to 639 Do
      RIP.PutPixel(X, Y, (X + Y) mod 16);
  Check('Full fill: center correct', RIP.GetPixel(320, 175) = ((320 + 175) mod 16));
End;

Procedure TestNegativeCoords;
Begin
  WriteLn;
  WriteLn('--- Negative Coordinates ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Line(-100, -100, -50, -50);
  Check('Line negative: no crash', True);
  RIP.Rectangle(-10, -10, 10, 10);
  Check('Rect spanning negative: no crash', True);
  RIP.Circle(-50, -50, 30);
  Check('Circle negative center: no crash', True);
  RIP.FloodFill(-5, -5, 0);
  Check('FloodFill negative: no crash', True);
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
  Check('1000 draws: no crash', True);
End;

Procedure TestLoadRFFMultiple;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- LoadRFF Multiple Cycles ---');
  For I := 1 to 10 Do
    RIP.LoadRFF(1, '/tmp/nonexistent.rff');
  Check('10 LoadRFF cycles (nonexistent): no crash', True);
End;

Procedure TestExtendedButtonStress;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- Extended Button Stress ---');
  RIP.Reset;
  For I := 1 to 20 Do
    RIP.ProcessLine('!|1b0A0A3232');
  Check('20 extended buttons: no crash', True);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== RIPscrip v2.0 — STRESS TESTS ===');

  RIP := TRIPEngine.Create;

  TestResolutionSwitching;
  TestScrollEdgeCases;
  TestPalFadeExtremes;
  TestLineAAEdge;
  TestAnimFrameNonexistent;
  TestFrameRate;
  TestMalformedV2Commands;
  TestSaveBMPAtDifferentResolutions;
  TestMassivePixelFill;
  TestNegativeCoords;
  TestRapidColorChange;
  TestLoadRFFMultiple;
  TestExtendedButtonStress;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
