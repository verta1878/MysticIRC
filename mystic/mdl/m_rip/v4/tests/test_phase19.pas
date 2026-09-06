{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// Phase 19: Polygon and Geometry — stress tests
// Tests 4096-vertex polygons, overflow clamping, edge cases
//
Program test_phase19;

Uses rip4api;

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

Procedure TestMaxPolyConst;
Begin
  WriteLn;
  WriteLn('--- RIP_MAX_POLY = 4096 ---');
  Check('RIP_MAX_POLY = 4096', RIP_MAX_POLY = 4096);
End;

Procedure TestPolygon4096;
Var
  Pts : Array[0..4095] of TRIPPoint;
  I   : Integer;
  Angle : Real;
Begin
  WriteLn;
  WriteLn('--- DrawPoly 4096 Vertices ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  For I := 0 to 4095 Do Begin
    Angle := (I / 4096) * 2 * 3.14159265;
    Pts[I].X := 320 + Trunc(150 * Cos(Angle));
    Pts[I].Y := 175 + Trunc(100 * Sin(Angle));
  End;
  RIP.DrawPoly(4096, Pts);
  Check('4096-vertex polygon: no crash', True);
  Check('4096-vertex polygon: pixel on circle', RIP.GetPixel(470, 175) = 15);
End;

Procedure TestFillPoly4096;
Var
  Pts : Array[0..4095] of TRIPPoint;
  I   : Integer;
  Angle : Real;
Begin
  WriteLn;
  WriteLn('--- FillPoly 4096 Vertices ---');
  RIP.ClearScreen;
  RIP.SetColor(14);
  RIP.SetFillStyle(1, 14);
  For I := 0 to 4095 Do Begin
    Angle := (I / 4096) * 2 * 3.14159265;
    Pts[I].X := 320 + Trunc(100 * Cos(Angle));
    Pts[I].Y := 175 + Trunc(80 * Sin(Angle));
  End;
  RIP.FillPoly(4096, Pts);
  Check('4096-vertex filled polygon: no crash', True);
  Check('4096-vertex filled: center filled', RIP.GetPixel(320, 175) = 14);
End;

Procedure TestPolygonOverflow;
Var
  Pts : Array[0..4095] of TRIPPoint;
  I   : Integer;
Begin
  WriteLn;
  WriteLn('--- Polygon Overflow (count > 4096) ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  For I := 0 to 4095 Do Begin
    Pts[I].X := I mod 640;
    Pts[I].Y := I mod 350;
  End;
  RIP.DrawPoly(10000, Pts);
  Check('DrawPoly count=10000 clamped: no crash', True);

  RIP.FillPoly(10000, Pts);
  Check('FillPoly count=10000 clamped: no crash', True);
End;

Procedure TestPolygonEdgeCases;
Var
  Pts : Array[0..3] of TRIPPoint;
Begin
  WriteLn;
  WriteLn('--- Polygon Edge Cases ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  Pts[0].X := 10; Pts[0].Y := 10;
  Pts[1].X := 50; Pts[1].Y := 10;
  Pts[2].X := 50; Pts[2].Y := 50;
  Pts[3].X := 10; Pts[3].Y := 50;

  RIP.DrawPoly(0, Pts);
  Check('0 points: no crash', True);

  RIP.DrawPoly(1, Pts);
  Check('1 point: no crash', True);

  RIP.DrawPoly(2, Pts);
  Check('2 points: no crash', True);

  RIP.DrawPoly(-5, Pts);
  Check('Negative count: no crash', True);

  RIP.FillPoly(0, Pts);
  Check('FillPoly 0 points: no crash', True);

  RIP.FillPoly(1, Pts);
  Check('FillPoly 1 point: no crash', True);

  RIP.FillPoly(-5, Pts);
  Check('FillPoly negative: no crash', True);
End;

Procedure TestPolygonAllPixelFormats;
Var
  Pts : Array[0..3] of TRIPPoint;
  Fmt : Byte;
Begin
  WriteLn;
  WriteLn('--- Polygon All Pixel Formats ---');
  Pts[0].X := 50;  Pts[0].Y := 50;
  Pts[1].X := 100; Pts[1].Y := 50;
  Pts[2].X := 100; Pts[2].Y := 100;
  Pts[3].X := 50;  Pts[3].Y := 100;

  For Fmt := RIP_PIXFMT_INDEXED8 to RIP_PIXFMT_RGB32 Do Begin
    RIP.SetPixelFormat(Fmt);
    RIP.ClearScreen;
    RIP.SetColor(15);
    RIP.DrawPoly(4, Pts);
    RIP.FillPoly(4, Pts);
  End;
  Check('All 3 pixel formats: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestPolygonNegativeCoords;
Var
  Pts : Array[0..3] of TRIPPoint;
Begin
  WriteLn;
  WriteLn('--- Polygon Negative Coordinates ---');
  Pts[0].X := -50;  Pts[0].Y := -50;
  Pts[1].X := 50;   Pts[1].Y := -50;
  Pts[2].X := 50;   Pts[2].Y := 50;
  Pts[3].X := -50;  Pts[3].Y := 50;

  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.DrawPoly(4, Pts);
  Check('Negative coords polygon: no crash', True);

  RIP.FillPoly(4, Pts);
  Check('Negative coords fill: no crash', True);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 19: Polygon and Geometry — STRESS TESTS ===');

  RIP := TRIPEngine.Create;

  TestMaxPolyConst;
  TestPolygon4096;
  TestFillPoly4096;
  TestPolygonOverflow;
  TestPolygonEdgeCases;
  TestPolygonAllPixelFormats;
  TestPolygonNegativeCoords;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
