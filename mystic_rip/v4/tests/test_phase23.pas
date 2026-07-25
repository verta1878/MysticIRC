{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// Phase 23: Advanced Graphics — tests and stress tests
//
Program test_phase23;

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

// ==== Gradients ====

Procedure TestGradientLinear;
Begin
  WriteLn;
  WriteLn('--- Gradient Linear ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.GradientRect(10, 10, 200, 100, 255, 0, 0, 0, 0, 255, 0);
  Check('Linear gradient: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestGradientRadial;
Begin
  WriteLn;
  WriteLn('--- Gradient Radial ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.GradientRect(50, 50, 300, 200, 255, 255, 0, 0, 128, 0, 1);
  Check('Radial gradient: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestGradientConical;
Begin
  WriteLn;
  WriteLn('--- Gradient Conical ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.GradientRect(100, 50, 400, 250, 0, 255, 0, 255, 0, 255, 2);
  Check('Conical gradient: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestGradientEdge;
Begin
  WriteLn;
  WriteLn('--- Gradient Edge Cases ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.GradientRect(0, 0, 0, 0, 255, 0, 0, 0, 0, 255, 0);
  Check('Zero-size gradient: no crash', True);
  RIP.GradientRect(-50, -50, 700, 400, 0, 0, 0, 255, 255, 255, 0);
  Check('Oversized gradient: no crash', True);
  RIP.GradientRect(100, 100, 50, 50, 0, 0, 0, 0, 0, 0, 99);
  Check('Invalid type (99): no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

// ==== Shadows and Glow ====

Procedure TestDropShadow;
Begin
  WriteLn;
  WriteLn('--- Drop Shadow ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.DropShadow(100, 100, 200, 50, 4, 4, 3, 0, 0, 0, 128);
  Check('Drop shadow: no crash', True);
  RIP.DropShadow(0, 0, 640, 350, 0, 0, 0, 0, 0, 0, 0);
  Check('Full-screen shadow: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestOuterGlow;
Begin
  WriteLn;
  WriteLn('--- Outer Glow ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.OuterGlow(100, 100, 200, 50, 5, 255, 255, 0, 200);
  Check('Outer glow: no crash', True);
  RIP.OuterGlow(0, 0, 10, 10, 0, 0, 0, 0, 0);
  Check('Zero-radius glow: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

// ==== Bezier ====

Procedure TestBezierVarWidth;
Begin
  WriteLn;
  WriteLn('--- Bezier Variable Width ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.BezierVarWidth(50, 175, 1,  200, 50, 4,  400, 300, 8,  600, 175, 2,
                     255, 128, 0);
  Check('Var-width bezier: no crash', True);

  // Thin bezier
  RIP.BezierVarWidth(10, 10, 1, 100, 10, 1, 200, 10, 1, 300, 10, 1, 255, 255, 255);
  Check('1px thin bezier: no crash', True);

  // Zero width
  RIP.BezierVarWidth(10, 10, 0, 100, 10, 0, 200, 10, 0, 300, 10, 0, 128, 128, 128);
  Check('Zero-width bezier: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

// ==== Texture Mapping ====

Procedure TestTextureQuad;
Var TexBuf : Array[0..191] of Byte;  // 8x8 RGB = 192 bytes
    I : Integer;
Begin
  WriteLn;
  WriteLn('--- Texture Quad ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Create simple 8x8 checkerboard texture
  For I := 0 to 63 Do Begin
    If ((I DIV 8) + (I MOD 8)) MOD 2 = 0 Then Begin
      TexBuf[I*3]   := 255;
      TexBuf[I*3+1] := 0;
      TexBuf[I*3+2] := 0;
    End Else Begin
      TexBuf[I*3]   := 0;
      TexBuf[I*3+1] := 0;
      TexBuf[I*3+2] := 255;
    End;
  End;

  RIP.TextureQuad(100, 100, 300, 100, 300, 250, 100, 250, @TexBuf, 8, 8);
  Check('Texture quad: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

// ==== Alpha Compositing ====

Procedure TestCompositAlpha;
Var SrcBuf : PByte;
    BufSize : LongInt;
Begin
  WriteLn;
  WriteLn('--- Composit Alpha ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // FXAlphaBlend requires same size as canvas
  BufSize := LongInt(640) * 350 * 3;
  GetMem(SrcBuf, BufSize);
  FillChar(SrcBuf^, BufSize, 200);

  RIP.CompositAlpha(SrcBuf, 640, 350, 0, 0, 128);
  Check('Alpha composit 50%: no crash', True);
  RIP.CompositAlpha(SrcBuf, 640, 350, 0, 0, 0);
  Check('Alpha 0 (transparent): no crash', True);
  RIP.CompositAlpha(SrcBuf, 640, 350, 0, 0, 255);
  Check('Alpha 255 (opaque): no crash', True);

  FreeMem(SrcBuf, BufSize);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

// ==== Clipping ====

Procedure TestClipRect;
Begin
  WriteLn;
  WriteLn('--- Clip Rectangle ---');
  RIP.ClipBegin;
  RIP.ClipAddRect(100, 100, 300, 250);
  RIP.ClipEnd;
  Check('Clip rect: no crash', True);
  RIP.ClipReset;
  Check('Clip reset: no crash', True);
End;

Procedure TestClipCircle;
Begin
  WriteLn;
  WriteLn('--- Clip Circle ---');
  RIP.ClipBegin;
  RIP.ClipAddCircle(320, 175, 100);
  RIP.ClipEnd;
  Check('Clip circle: no crash', True);
  RIP.ClipReset;
End;

Procedure TestClipPolygon;
Begin
  WriteLn;
  WriteLn('--- Clip Polygon ---');
  RIP.ClipBegin;
  RIP.ClipAddPoint(100, 50);
  RIP.ClipAddPoint(300, 50);
  RIP.ClipAddPoint(400, 200);
  RIP.ClipAddPoint(200, 300);
  RIP.ClipAddPoint(50, 200);
  RIP.ClipEnd;
  Check('Clip polygon (5 points): no crash', True);
  RIP.ClipReset;
End;

Procedure TestClipMultiple;
Begin
  WriteLn;
  WriteLn('--- Clip Multiple Ops ---');
  RIP.ClipBegin;
  RIP.ClipAddRect(50, 50, 200, 200);
  RIP.ClipEnd;
  RIP.ClipReset;
  RIP.ClipBegin;
  RIP.ClipAddCircle(320, 175, 50);
  RIP.ClipEnd;
  RIP.ClipReset;
  RIP.ClipBegin;
  RIP.ClipAddPoint(10, 10);
  RIP.ClipAddPoint(100, 10);
  RIP.ClipAddPoint(50, 100);
  RIP.ClipEnd;
  RIP.ClipReset;
  Check('3 clip cycles: no crash', True);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 23: Advanced Graphics — TESTS ===');

  RIP := TRIPEngine.Create;

  TestGradientLinear;
  TestGradientRadial;
  TestGradientConical;
  TestGradientEdge;
  TestDropShadow;
  TestOuterGlow;
  TestBezierVarWidth;
  TestTextureQuad;
  TestCompositAlpha;
  TestClipRect;
  TestClipCircle;
  TestClipPolygon;
  TestClipMultiple;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
