{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
Program test_phase17_stress;
// Phase 17 stress tests — try to break JPEG streaming and image APIs

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

// ---- JPEG Streaming Adversarial ----

Procedure TestStreamGarbageData;
// Feed random garbage — should not crash or produce image
Var
  Junk : Array[0..255] of Byte;
  I    : Integer;
  OK   : Boolean;
Begin
  WriteLn;
  WriteLn('--- Stream: Garbage Data ---');

  For I := 0 to 255 Do Junk[I] := I;

  RIP.JPEGStreamInit;
  OK := RIP.JPEGStreamFeed(@Junk[0], 256, 0, 0);
  Check('Garbage feed: returns false (no image)', Not OK);
  Check('Garbage feed: not complete', Not RIP.JPEGStreamComplete);
  RIP.JPEGStreamDone;
End;

Procedure TestStreamTinyChunks;
// Feed 1 byte at a time — should not crash
Var
  Junk : Array[0..99] of Byte;
  I    : Integer;
Begin
  WriteLn;
  WriteLn('--- Stream: 1-Byte Chunks ---');

  For I := 0 to 99 Do Junk[I] := I mod 256;

  RIP.JPEGStreamInit;
  For I := 0 to 99 Do
    RIP.JPEGStreamFeed(@Junk[I], 1, 0, 0);
  Check('100 x 1-byte feeds: no crash', True);
  RIP.JPEGStreamDone;
End;

Procedure TestStreamFeedAfterDone;
// Feed after Done — should return false, not crash
Var
  Junk : Array[0..3] of Byte;
  OK   : Boolean;
Begin
  WriteLn;
  WriteLn('--- Stream: Feed After Done ---');

  Junk[0] := $FF; Junk[1] := $D8; Junk[2] := $FF; Junk[3] := $D9;

  RIP.JPEGStreamInit;
  RIP.JPEGStreamDone;

  OK := RIP.JPEGStreamFeed(@Junk[0], 4, 0, 0);
  Check('Feed after done: returns false', Not OK);
  Check('Feed after done: no crash', True);
End;

Procedure TestStreamFeedWithoutInit;
// Feed without Init — should return false
Var
  Junk : Array[0..3] of Byte;
  OK   : Boolean;
Begin
  WriteLn;
  WriteLn('--- Stream: Feed Without Init ---');

  Junk[0] := $FF; Junk[1] := $D8;

  OK := RIP.JPEGStreamFeed(@Junk[0], 2, 0, 0);
  Check('Feed without init: returns false', Not OK);
End;

Procedure TestStreamMultipleSessions;
// Multiple init/done cycles
Var
  I : Integer;
Begin
  WriteLn;
  WriteLn('--- Stream: Multiple Sessions (50 cycles) ---');

  For I := 1 to 50 Do Begin
    RIP.JPEGStreamInit;
    RIP.JPEGStreamDone;
  End;
  Check('50 init/done cycles: no crash/leak', True);
End;

Procedure TestStreamLargeChunk;
// Feed a large buffer
Var
  Buf : PByte;
  OK  : Boolean;
Begin
  WriteLn;
  WriteLn('--- Stream: Large Chunk (64KB) ---');

  GetMem(Buf, 65536);
  FillChar(Buf^, 65536, $AA);

  RIP.JPEGStreamInit;
  OK := RIP.JPEGStreamFeed(Buf, 65536, 0, 0);
  Check('64KB garbage feed: no crash', True);
  RIP.JPEGStreamDone;

  FreeMem(Buf);
End;

Procedure TestStreamJPEGHeaders;
// Feed just SOI marker (FF D8) then EOI (FF D9)
Var
  Buf : Array[0..3] of Byte;
Begin
  WriteLn;
  WriteLn('--- Stream: SOI + EOI Only ---');

  Buf[0] := $FF; Buf[1] := $D8;  // SOI
  Buf[2] := $FF; Buf[3] := $D9;  // EOI

  RIP.JPEGStreamInit;
  RIP.JPEGStreamFeed(@Buf[0], 2, 0, 0);  // SOI
  Check('SOI only: not complete', Not RIP.JPEGStreamComplete);

  RIP.JPEGStreamFeed(@Buf[2], 2, 0, 0);  // EOI
  // May or may not be complete depending on decoder behavior
  Check('SOI+EOI: no crash', True);
  RIP.JPEGStreamDone;
End;

Procedure TestStreamOutOfBoundsCoords;
// Feed to negative/huge coordinates
Var
  Junk : Array[0..11] of Byte;
  I    : Integer;
Begin
  WriteLn;
  WriteLn('--- Stream: Out-of-Bounds Coords ---');

  For I := 0 to 11 Do Junk[I] := 128;

  RIP.JPEGStreamInit;
  RIP.JPEGStreamFeed(@Junk[0], 12, -100, -100);
  Check('Feed at (-100,-100): no crash', True);

  RIP.JPEGStreamFeed(@Junk[0], 12, 9999, 9999);
  Check('Feed at (9999,9999): no crash', True);
  RIP.JPEGStreamDone;
End;

Procedure TestStreamWithRGBMode;
// Streaming in RGB24 mode
Begin
  WriteLn;
  WriteLn('--- Stream: RGB24 Mode ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.JPEGStreamInit;
  RIP.JPEGStreamDone;
  Check('Stream init/done in RGB24: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestStreamWithWorldCoords;
// Streaming with world coords active
Begin
  WriteLn;
  WriteLn('--- Stream: World Coords Active ---');

  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.JPEGStreamInit;
  RIP.JPEGStreamDone;
  Check('Stream init/done with world: no crash', True);
  RIP.ClearWorldCoords;
End;

// ---- BlitRGBMask Adversarial ----

Procedure TestBlitRGBMaskLarge;
// Large mask blit
Var
  Buf, Mask : PByte;
  Got       : TRIPRgb;
  W, H, I   : Integer;
Begin
  WriteLn;
  WriteLn('--- BlitRGBMask Large (100x100) ---');

  W := 100; H := 100;
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  GetMem(Buf, W * H * 3);
  GetMem(Mask, W * H);
  FillChar(Buf^, W * H * 3, 0);
  FillChar(Mask^, W * H, 1);  // all opaque

  // Set center pixel to red
  Buf[50 * W * 3 + 50 * 3]     := 255;
  Buf[50 * W * 3 + 50 * 3 + 1] := 0;
  Buf[50 * W * 3 + 50 * 3 + 2] := 0;

  // Make a checkerboard mask
  For I := 0 to W * H - 1 Do
    Mask[I] := I mod 2;

  RIP.BlitRGBMask(Buf, W, H, 100, 100, Mask);
  Check('Large mask blit: no crash', True);

  FreeMem(Buf);
  FreeMem(Mask);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

// ---- RGBAToMask Edge Cases ----

Procedure TestRGBAToMaskAllOpaque;
Var
  RGBA : Array[0..15] of Byte;
  Mask : Array[0..3] of Byte;
  I    : Integer;
  OK   : Boolean;
Begin
  WriteLn;
  WriteLn('--- RGBAToMask All Opaque ---');

  For I := 0 to 3 Do Begin
    RGBA[I * 4]     := 255;
    RGBA[I * 4 + 1] := 255;
    RGBA[I * 4 + 2] := 255;
    RGBA[I * 4 + 3] := 255;  // full alpha
  End;

  RIP.RGBAToMask(@RGBA[0], 4, 1, @Mask[0], 128);

  OK := True;
  For I := 0 to 3 Do
    If Mask[I] <> 1 Then OK := False;
  Check('All alpha=255: all mask=1', OK);
End;

Procedure TestRGBAToMaskAllTransparent;
Var
  RGBA : Array[0..15] of Byte;
  Mask : Array[0..3] of Byte;
  I    : Integer;
  OK   : Boolean;
Begin
  WriteLn;
  WriteLn('--- RGBAToMask All Transparent ---');

  For I := 0 to 3 Do Begin
    RGBA[I * 4]     := 255;
    RGBA[I * 4 + 1] := 255;
    RGBA[I * 4 + 2] := 255;
    RGBA[I * 4 + 3] := 0;  // zero alpha
  End;

  RIP.RGBAToMask(@RGBA[0], 4, 1, @Mask[0], 128);

  OK := True;
  For I := 0 to 3 Do
    If Mask[I] <> 0 Then OK := False;
  Check('All alpha=0: all mask=0', OK);
End;

Procedure TestRGBAToMaskBoundary;
// Alpha exactly at threshold
Var
  RGBA : Array[0..7] of Byte;
  Mask : Array[0..1] of Byte;
Begin
  WriteLn;
  WriteLn('--- RGBAToMask Boundary ---');

  // Pixel 0: alpha = 128 (== threshold, should be transparent since > not >=)
  RGBA[0] := 0; RGBA[1] := 0; RGBA[2] := 0; RGBA[3] := 128;
  // Pixel 1: alpha = 129 (> threshold, opaque)
  RGBA[4] := 0; RGBA[5] := 0; RGBA[6] := 0; RGBA[7] := 129;

  RIP.RGBAToMask(@RGBA[0], 2, 1, @Mask[0], 128);

  Check('Alpha=128 at threshold=128: transparent (mask=0)', Mask[0] = 0);
  Check('Alpha=129 at threshold=128: opaque (mask=1)', Mask[1] = 1);
End;

// ---- Combined Stress ----

Procedure TestAllFormatsAllBlits;
// Every blit method in every pixel format
Var
  Buf   : Array[0..2] of Byte;
  Mask  : Array[0..0] of Byte;
  Alpha : Array[0..0] of Byte;
  Fmt   : Byte;
Begin
  WriteLn;
  WriteLn('--- All Blits x All Formats ---');

  Buf[0] := 128; Buf[1] := 64; Buf[2] := 32;
  Mask[0] := 1;
  Alpha[0] := 200;

  For Fmt := RIP_PIXFMT_INDEXED8 to RIP_PIXFMT_RGB32 Do Begin
    RIP.SetPixelFormat(Fmt);
    RIP.ClearScreen;
    RIP.BlitRGB(@Buf[0], 1, 1, 10, 10);
    RIP.BlitRGBScaled(@Buf[0], 1, 1, 20, 20, 5, 5);
    RIP.BlitRGBAlpha(@Buf[0], 1, 1, 30, 30, @Alpha[0]);
    RIP.BlitRGBMask(@Buf[0], 1, 1, 40, 40, @Mask[0]);
  End;
  Check('All blits x all formats: no crash', True);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 17: STRESS TESTS — Try to Break Streaming & Images ===');

  RIP := TRIPEngine.Create;

  TestStreamGarbageData;
  TestStreamTinyChunks;
  TestStreamFeedAfterDone;
  TestStreamFeedWithoutInit;
  TestStreamMultipleSessions;
  TestStreamLargeChunk;
  TestStreamJPEGHeaders;
  TestStreamOutOfBoundsCoords;
  TestStreamWithRGBMode;
  TestStreamWithWorldCoords;
  TestBlitRGBMaskLarge;
  TestRGBAToMaskAllOpaque;
  TestRGBAToMaskAllTransparent;
  TestRGBAToMaskBoundary;
  TestAllFormatsAllBlits;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
