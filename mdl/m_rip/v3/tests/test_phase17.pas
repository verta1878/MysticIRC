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
Program test_phase17;
// Phase 17: Image Format Support — stress tests

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

// ---- BlitRGB Tests ----

Procedure TestBlitRGBBasic;
// Create a 2x2 RGB buffer and blit it
Var
  Buf : Array[0..11] of Byte;  // 2x2 * 3 bytes = 12
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- BlitRGB Basic ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Pixel (0,0) = red
  Buf[0] := 255; Buf[1] := 0; Buf[2] := 0;
  // Pixel (1,0) = green
  Buf[3] := 0; Buf[4] := 255; Buf[5] := 0;
  // Pixel (0,1) = blue
  Buf[6] := 0; Buf[7] := 0; Buf[8] := 255;
  // Pixel (1,1) = white
  Buf[9] := 255; Buf[10] := 255; Buf[11] := 255;

  RIP.BlitRGB(@Buf[0], 2, 2, 100, 100);

  Got := RIP.GetPixelRGB(100, 100);
  Check('BlitRGB (0,0) red', (Got.R = 255) and (Got.G = 0) and (Got.B = 0));

  Got := RIP.GetPixelRGB(101, 100);
  Check('BlitRGB (1,0) green', (Got.R = 0) and (Got.G = 255) and (Got.B = 0));

  Got := RIP.GetPixelRGB(100, 101);
  Check('BlitRGB (0,1) blue', (Got.R = 0) and (Got.G = 0) and (Got.B = 255));

  Got := RIP.GetPixelRGB(101, 101);
  Check('BlitRGB (1,1) white', (Got.R = 255) and (Got.G = 255) and (Got.B = 255));

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestBlitRGBClipping;
// Blit at canvas edge — should clip, not crash
Var
  Buf : Array[0..29] of Byte;  // 10x1 * 3 = 30
  I   : Integer;
Begin
  WriteLn;
  WriteLn('--- BlitRGB Clipping ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  For I := 0 to 29 Do Buf[I] := 255;

  // Blit at right edge — partially off screen
  RIP.BlitRGB(@Buf[0], 10, 1, 635, 0);
  Check('BlitRGB right edge: no crash', True);

  // Blit at bottom edge
  RIP.BlitRGB(@Buf[0], 1, 10, 0, 345);
  Check('BlitRGB bottom edge: no crash', True);

  // Blit entirely off screen
  RIP.BlitRGB(@Buf[0], 10, 1, 700, 0);
  Check('BlitRGB off screen right: no crash', True);

  RIP.BlitRGB(@Buf[0], 10, 1, -20, 0);
  Check('BlitRGB off screen left: no crash', True);

  RIP.BlitRGB(@Buf[0], 1, 10, 0, -20);
  Check('BlitRGB off screen top: no crash', True);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestBlitRGBZeroSize;
// Zero width/height should not crash
Begin
  WriteLn;
  WriteLn('--- BlitRGB Zero Size ---');

  RIP.BlitRGB(Nil, 0, 0, 0, 0);
  Check('BlitRGB nil/0x0: no crash', True);

  RIP.BlitRGB(Nil, 0, 10, 0, 0);
  Check('BlitRGB 0 width: no crash', True);

  RIP.BlitRGB(Nil, 10, 0, 0, 0);
  Check('BlitRGB 0 height: no crash', True);
End;

// ---- BlitRGBScaled Tests ----

Procedure TestBlitRGBScaledUpscale;
// Scale a 1x1 pixel to 10x10
Var
  Buf : Array[0..2] of Byte;
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- BlitRGBScaled Upscale ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  Buf[0] := 200; Buf[1] := 100; Buf[2] := 50;
  RIP.BlitRGBScaled(@Buf[0], 1, 1, 50, 50, 10, 10);

  Got := RIP.GetPixelRGB(55, 55);
  Check('Upscale 1x1->10x10: center pixel R', Got.R = 200);
  Check('Upscale 1x1->10x10: center pixel G', Got.G = 100);
  Check('Upscale 1x1->10x10: center pixel B', Got.B = 50);

  Got := RIP.GetPixelRGB(50, 50);
  Check('Upscale 1x1->10x10: corner pixel', Got.R = 200);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestBlitRGBScaledDownscale;
// Scale a 4x4 to 2x2
Var
  Buf : Array[0..47] of Byte;  // 4x4 * 3 = 48
  Got : TRIPRgb;
  I   : Integer;
Begin
  WriteLn;
  WriteLn('--- BlitRGBScaled Downscale ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Fill all red
  For I := 0 to 15 Do Begin
    Buf[I * 3]     := 180;
    Buf[I * 3 + 1] := 0;
    Buf[I * 3 + 2] := 0;
  End;

  RIP.BlitRGBScaled(@Buf[0], 4, 4, 200, 200, 2, 2);

  Got := RIP.GetPixelRGB(200, 200);
  Check('Downscale 4x4->2x2: pixel is red', Got.R = 180);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestBlitRGBScaledZero;
// Zero dest size
Begin
  WriteLn;
  WriteLn('--- BlitRGBScaled Zero Dest ---');

  RIP.BlitRGBScaled(Nil, 1, 1, 0, 0, 0, 0);
  Check('BlitRGBScaled 0x0 dest: no crash', True);

  RIP.BlitRGBScaled(Nil, 1, 1, 0, 0, -5, -5);
  Check('BlitRGBScaled negative dest: no crash', True);
End;

// ---- BlitRGBAlpha Tests ----

Procedure TestBlitRGBAlphaOpaque;
// Alpha = $FF everywhere — should be identical to BlitRGB
Var
  Buf   : Array[0..5] of Byte;   // 2x1 * 3 = 6
  Alpha : Array[0..1] of Byte;   // 2x1
  Got   : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- BlitRGBAlpha Opaque ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  Buf[0] := 100; Buf[1] := 200; Buf[2] := 50;
  Buf[3] := 50;  Buf[4] := 100; Buf[5] := 200;
  Alpha[0] := $FF;
  Alpha[1] := $FF;

  RIP.BlitRGBAlpha(@Buf[0], 2, 1, 300, 300, @Alpha[0]);

  Got := RIP.GetPixelRGB(300, 300);
  Check('Alpha $FF: pixel 0 R=100', Got.R = 100);
  Check('Alpha $FF: pixel 0 G=200', Got.G = 200);

  Got := RIP.GetPixelRGB(301, 300);
  Check('Alpha $FF: pixel 1 B=200', Got.B = 200);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestBlitRGBAlphaTransparent;
// Alpha = 0 everywhere — background should show through
Var
  Buf   : Array[0..2] of Byte;
  Alpha : Array[0..0] of Byte;
  BG    : TRIPRgb;
  Got   : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- BlitRGBAlpha Transparent ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Set background pixel
  BG.R := 50; BG.G := 100; BG.B := 150;
  RIP.PutPixel(200, 200, BG);

  // Blit with alpha=0
  Buf[0] := 255; Buf[1] := 255; Buf[2] := 255;
  Alpha[0] := 0;

  RIP.BlitRGBAlpha(@Buf[0], 1, 1, 200, 200, @Alpha[0]);

  Got := RIP.GetPixelRGB(200, 200);
  Check('Alpha 0: background preserved R', Got.R = 50);
  Check('Alpha 0: background preserved G', Got.G = 100);
  Check('Alpha 0: background preserved B', Got.B = 150);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestBlitRGBAlphaHalf;
// Alpha = 128 — should blend 50/50
Var
  Buf   : Array[0..2] of Byte;
  Alpha : Array[0..0] of Byte;
  BG    : TRIPRgb;
  Got   : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- BlitRGBAlpha 50% Blend ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Background = black (0,0,0)
  // Foreground = white (255,255,255) at alpha=128
  Buf[0] := 254; Buf[1] := 254; Buf[2] := 254;
  Alpha[0] := 128;

  RIP.BlitRGBAlpha(@Buf[0], 1, 1, 10, 10, @Alpha[0]);

  Got := RIP.GetPixelRGB(10, 10);
  // Should be approximately 127
  Check('Alpha 128: blended R ~ 127', (Got.R >= 120) and (Got.R <= 135));
  Check('Alpha 128: blended G ~ 127', (Got.G >= 120) and (Got.G <= 135));

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

// ---- BlitIndexed Tests ----

Procedure TestBlitIndexedBasic;
// Blit indexed pixels with palette
Var
  Buf : Array[0..3] of Byte;  // 2x2
  Pal : Array[0..767] of Byte; // 256 * 3
  I   : Integer;
  Got : Byte;
Begin
  WriteLn;
  WriteLn('--- BlitIndexed Basic ---');

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearScreen;

  // Set up a simple palette — index 1 = some color
  FillChar(Pal, SizeOf(Pal), 0);
  Pal[3] := 255; Pal[4] := 0; Pal[5] := 0;  // index 1 = red

  Buf[0] := 1; Buf[1] := 0; Buf[2] := 0; Buf[3] := 1;

  RIP.BlitIndexed(@Buf[0], 2, 2, 150, 150, @Pal[0], -1);

  // In indexed mode, BlitIndexed should write the palette-mapped color
  // Check that pixels were drawn
  Check('BlitIndexed: pixels drawn (no crash)', True);
End;

Procedure TestBlitIndexedTransparent;
// TransIdx should skip those pixels
Var
  Buf : Array[0..3] of Byte;
  Pal : Array[0..767] of Byte;
Begin
  WriteLn;
  WriteLn('--- BlitIndexed Transparent ---');

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearScreen;

  FillChar(Pal, SizeOf(Pal), 0);
  Buf[0] := 0; Buf[1] := 1; Buf[2] := 0; Buf[3] := 1;

  // Set background
  RIP.PutPixel(160, 160, 15);
  RIP.PutPixel(161, 160, 15);

  // Blit with TransIdx=0 — index 0 should be transparent
  RIP.BlitIndexed(@Buf[0], 2, 2, 160, 160, @Pal[0], 0);

  Check('BlitIndexed transparent: bg preserved at (160,160)',
    RIP.GetPixel(160, 160) = 15);
End;

// ---- TRIPImageBuffer Tests ----

Procedure TestImageBufferBlitFree;
Var
  Img : TRIPImageBuffer;
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- TRIPImageBuffer Blit/Free ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Create a 3x3 image buffer manually
  Img.Width  := 3;
  Img.Height := 3;
  Img.Alpha  := Nil;
  GetMem(Img.Pixels, 3 * 3 * 3);
  FillChar(Img.Pixels^, 27, 0);
  // Center pixel (1,1) = offset (1*3 + 1) * 3 = 12
  PByte(PtrInt(Img.Pixels) + 12)^ := 255;  // R
  PByte(PtrInt(Img.Pixels) + 13)^ := 255;  // G
  PByte(PtrInt(Img.Pixels) + 14)^ := 0;    // B

  RIP.BlitImage(Img, 300, 300);
  Got := RIP.GetPixelRGB(301, 301);
  Check('BlitImage: center pixel R=255', Got.R = 255);
  Check('BlitImage: center pixel G=255', Got.G = 255);

  RIP.FreeImage(Img);
  Check('FreeImage: Pixels=nil', Img.Pixels = Nil);
  Check('FreeImage: Width=0', Img.Width = 0);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestImageBufferNil;
// Free/Blit with nil — should not crash
Var
  Img : TRIPImageBuffer;
Begin
  WriteLn;
  WriteLn('--- TRIPImageBuffer Nil Safety ---');

  Img.Pixels := Nil;
  Img.Alpha  := Nil;
  Img.Width  := 0;
  Img.Height := 0;

  RIP.BlitImage(Img, 0, 0);
  Check('BlitImage nil: no crash', True);

  RIP.BlitImageScaled(Img, 0, 0, 100, 100);
  Check('BlitImageScaled nil: no crash', True);

  RIP.BlitImageAlpha(Img, 0, 0);
  Check('BlitImageAlpha nil: no crash', True);

  RIP.FreeImage(Img);
  Check('FreeImage nil: no crash', True);
End;

// ---- LoadImage with nonexistent files ----

Procedure TestLoadNonexistent;
Var
  OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- LoadImage Nonexistent Files ---');

  OK := RIP.LoadJPEG('/tmp/nonexistent.jpg', 0, 0);
  Check('LoadJPEG nonexistent: returns false', Not OK);

  OK := RIP.LoadGIF('/tmp/nonexistent.gif', 0, 0);
  Check('LoadGIF nonexistent: returns false', Not OK);

  OK := RIP.LoadPNG('/tmp/nonexistent.png', 0, 0);
  Check('LoadPNG nonexistent: returns false', Not OK);

  OK := RIP.LoadImage('/tmp/nonexistent.xyz', 0, 0);
  Check('LoadImage nonexistent: returns false', Not OK);

  OK := RIP.LoadImageScaled('/tmp/nonexistent.jpg', 0, 0, 100, 100);
  Check('LoadImageScaled nonexistent: returns false', Not OK);

  OK := RIP.LoadGIFFrame('/tmp/nonexistent.gif', 0, 0, 0);
  Check('LoadGIFFrame nonexistent: returns false', Not OK);
End;

// ---- Combined: World + RGB + Blit ----

Procedure TestBlitWithWorldCoords;
Var
  Buf : Array[0..2] of Byte;
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- BlitRGB with World Coords Active ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);

  // BlitRGB uses pixel coords directly (not world coords)
  Buf[0] := 128; Buf[1] := 64; Buf[2] := 32;
  RIP.BlitRGB(@Buf[0], 1, 1, 320, 175);

  Got := RIP.GetPixelRGB(320, 175);
  Check('BlitRGB with world active: pixel written', Got.R = 128);

  RIP.ClearWorldCoords;
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestBlitRGBAllModes;
// BlitRGB in all three pixel format modes
Var
  Buf : Array[0..2] of Byte;
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- BlitRGB in All Pixel Formats ---');

  Buf[0] := 200; Buf[1] := 150; Buf[2] := 100;

  // Indexed mode
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearScreen;
  RIP.BlitRGB(@Buf[0], 1, 1, 50, 50);
  Check('BlitRGB in INDEXED8: no crash', True);

  // RGB24
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.BlitRGB(@Buf[0], 1, 1, 50, 50);
  Got := RIP.GetPixelRGB(50, 50);
  Check('BlitRGB in RGB24: R=200', Got.R = 200);

  // RGB32
  RIP.SetPixelFormat(RIP_PIXFMT_RGB32);
  RIP.ClearScreen;
  RIP.BlitRGB(@Buf[0], 1, 1, 50, 50);
  Got := RIP.GetPixelRGB(50, 50);
  Check('BlitRGB in RGB32: R=200', Got.R = 200);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

// ---- BlitRGBMask Tests ----

Procedure TestBlitRGBMaskBasic;
// Mask=1 draws, Mask=0 skips
Var
  Buf  : Array[0..8] of Byte;   // 3x1 * 3 = 9
  Mask : Array[0..2] of Byte;   // 3x1
  BG   : TRIPRgb;
  Got  : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- BlitRGBMask Basic ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Set background
  BG.R := 50; BG.G := 50; BG.B := 50;
  RIP.PutPixel(100, 100, BG);
  RIP.PutPixel(101, 100, BG);
  RIP.PutPixel(102, 100, BG);

  // Pixel 0 = red, Pixel 1 = green, Pixel 2 = blue
  Buf[0] := 255; Buf[1] := 0;   Buf[2] := 0;
  Buf[3] := 0;   Buf[4] := 255; Buf[5] := 0;
  Buf[6] := 0;   Buf[7] := 0;   Buf[8] := 255;

  // Mask: draw, skip, draw
  Mask[0] := 1;
  Mask[1] := 0;
  Mask[2] := 1;

  RIP.BlitRGBMask(@Buf[0], 3, 1, 100, 100, @Mask[0]);

  Got := RIP.GetPixelRGB(100, 100);
  Check('Mask=1: pixel 0 drawn (red)', Got.R = 255);

  Got := RIP.GetPixelRGB(101, 100);
  Check('Mask=0: pixel 1 skipped (bg preserved)', Got.R = 50);

  Got := RIP.GetPixelRGB(102, 100);
  Check('Mask=1: pixel 2 drawn (blue)', Got.B = 255);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestBlitRGBMaskAllOpaque;
// All mask=1 — should be identical to BlitRGB
Var
  Buf  : Array[0..5] of Byte;
  Mask : Array[0..1] of Byte;
  Got  : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- BlitRGBMask All Opaque ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  Buf[0] := 111; Buf[1] := 222; Buf[2] := 33;
  Buf[3] := 44;  Buf[4] := 55;  Buf[5] := 166;
  Mask[0] := 1; Mask[1] := 1;

  RIP.BlitRGBMask(@Buf[0], 2, 1, 200, 200, @Mask[0]);

  Got := RIP.GetPixelRGB(200, 200);
  Check('All opaque: pixel 0 R', Got.R = 111);
  Got := RIP.GetPixelRGB(201, 200);
  Check('All opaque: pixel 1 B', Got.B = 166);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestBlitRGBMaskAllTransparent;
// All mask=0 — nothing should be drawn
Var
  Buf  : Array[0..2] of Byte;
  Mask : Array[0..0] of Byte;
  Got  : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- BlitRGBMask All Transparent ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  Buf[0] := 255; Buf[1] := 255; Buf[2] := 255;
  Mask[0] := 0;

  RIP.BlitRGBMask(@Buf[0], 1, 1, 150, 150, @Mask[0]);

  Got := RIP.GetPixelRGB(150, 150);
  Check('All transparent: pixel stays black', (Got.R = 0) and (Got.G = 0) and (Got.B = 0));

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestBlitRGBMaskNil;
// Nil mask or src — should not crash
Begin
  WriteLn;
  WriteLn('--- BlitRGBMask Nil Safety ---');

  RIP.BlitRGBMask(Nil, 10, 10, 0, 0, Nil);
  Check('BlitRGBMask nil src+mask: no crash', True);
End;

// ---- RGBAToMask Tests ----

Procedure TestRGBAToMaskBasic;
Var
  RGBA : Array[0..15] of Byte;  // 4 pixels * 4 bytes
  Mask : Array[0..3] of Byte;
Begin
  WriteLn;
  WriteLn('--- RGBAToMask Basic ---');

  // Pixel 0: alpha=255 (opaque)
  RGBA[0] := 255; RGBA[1] := 0; RGBA[2] := 0; RGBA[3] := 255;
  // Pixel 1: alpha=0 (transparent)
  RGBA[4] := 0; RGBA[5] := 255; RGBA[6] := 0; RGBA[7] := 0;
  // Pixel 2: alpha=200 (opaque, > 128)
  RGBA[8] := 0; RGBA[9] := 0; RGBA[10] := 255; RGBA[11] := 200;
  // Pixel 3: alpha=100 (transparent, <= 128)
  RGBA[12] := 255; RGBA[13] := 255; RGBA[14] := 255; RGBA[15] := 100;

  FillChar(Mask, SizeOf(Mask), 99);  // fill with junk to verify overwrite
  RIP.RGBAToMask(@RGBA[0], 4, 1, @Mask[0], 128);

  Check('RGBAToMask: alpha=255 -> mask=1', Mask[0] = 1);
  Check('RGBAToMask: alpha=0 -> mask=0', Mask[1] = 0);
  Check('RGBAToMask: alpha=200 -> mask=1', Mask[2] = 1);
  Check('RGBAToMask: alpha=100 -> mask=0', Mask[3] = 0);
End;

Procedure TestRGBAToMaskThreshold;
// Different threshold values
Var
  RGBA : Array[0..3] of Byte;
  Mask : Array[0..0] of Byte;
Begin
  WriteLn;
  WriteLn('--- RGBAToMask Threshold ---');

  RGBA[0] := 0; RGBA[1] := 0; RGBA[2] := 0; RGBA[3] := 50;

  RIP.RGBAToMask(@RGBA[0], 1, 1, @Mask[0], 128);
  Check('Threshold 128, alpha=50: transparent', Mask[0] = 0);

  RIP.RGBAToMask(@RGBA[0], 1, 1, @Mask[0], 30);
  Check('Threshold 30, alpha=50: opaque', Mask[0] = 1);

  RIP.RGBAToMask(@RGBA[0], 1, 1, @Mask[0], 0);
  Check('Threshold 0, alpha=50: opaque', Mask[0] = 1);
End;

Procedure TestRGBAToMaskNil;
Begin
  WriteLn;
  WriteLn('--- RGBAToMask Nil Safety ---');

  RIP.RGBAToMask(Nil, 10, 10, Nil, 128);
  Check('RGBAToMask nil: no crash', True);
End;

// ---- JPEG Streaming Tests ----

Procedure TestJPEGStreamInit;
Begin
  WriteLn;
  WriteLn('--- JPEG Stream Init/Done ---');

  RIP.JPEGStreamInit;
  Check('JPEGStreamInit: not complete yet', Not RIP.JPEGStreamComplete);

  RIP.JPEGStreamDone;
  Check('JPEGStreamDone: complete after done', RIP.JPEGStreamComplete);
End;

Procedure TestJPEGStreamNilFeed;
Var
  OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- JPEG Stream Nil Feed ---');

  RIP.JPEGStreamInit;

  OK := RIP.JPEGStreamFeed(Nil, 0, 0, 0);
  Check('Feed nil/0: returns false', Not OK);

  OK := RIP.JPEGStreamFeed(Nil, 100, 0, 0);
  Check('Feed nil/100: returns false', Not OK);

  RIP.JPEGStreamDone;
End;

Procedure TestJPEGStreamDoneWithoutInit;
Begin
  WriteLn;
  WriteLn('--- JPEG Stream Done Without Init ---');

  RIP.JPEGStreamDone;
  Check('JPEGStreamDone without init: no crash', True);
  Check('Complete without init: true', RIP.JPEGStreamComplete);
End;

Procedure TestJPEGStreamDoubleInit;
Begin
  WriteLn;
  WriteLn('--- JPEG Stream Double Init ---');

  RIP.JPEGStreamInit;
  RIP.JPEGStreamInit;  // should not leak
  Check('Double init: no crash', True);

  RIP.JPEGStreamDone;
  Check('Done after double init: no crash', True);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 17: Image Format Support — STRESS TESTS ===');

  RIP := TRIPEngine.Create;

  TestBlitRGBBasic;
  TestBlitRGBClipping;
  TestBlitRGBZeroSize;
  TestBlitRGBScaledUpscale;
  TestBlitRGBScaledDownscale;
  TestBlitRGBScaledZero;
  TestBlitRGBAlphaOpaque;
  TestBlitRGBAlphaTransparent;
  TestBlitRGBAlphaHalf;
  TestBlitIndexedBasic;
  TestBlitIndexedTransparent;
  TestImageBufferBlitFree;
  TestImageBufferNil;
  TestLoadNonexistent;
  TestBlitWithWorldCoords;
  TestBlitRGBAllModes;
  TestBlitRGBMaskBasic;
  TestBlitRGBMaskAllOpaque;
  TestBlitRGBMaskAllTransparent;
  TestBlitRGBMaskNil;
  TestRGBAToMaskBasic;
  TestRGBAToMaskThreshold;
  TestRGBAToMaskNil;
  TestJPEGStreamInit;
  TestJPEGStreamNilFeed;
  TestJPEGStreamDoneWithoutInit;
  TestJPEGStreamDoubleInit;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
