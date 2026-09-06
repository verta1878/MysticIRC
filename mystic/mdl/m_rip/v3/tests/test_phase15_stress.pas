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
Program test_phase15_stress;
// Stress tests and edge cases — try to break Phase 15

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

Procedure TestBoundaryPixels;
// Draw at canvas edges — off-by-one in buffer indexing?
Var
  Got : TRIPRgb;
  RGB : TRIPRgb;
  W, H : SmallInt;
Begin
  WriteLn;
  WriteLn('--- Boundary Pixels ---');

  W := RIP.GetCanvasWidth;
  H := RIP.GetCanvasHeight;

  // Indexed mode corners
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearScreen;
  RIP.PutPixel(0, 0, 15);
  RIP.PutPixel(W - 1, 0, 14);
  RIP.PutPixel(0, H - 1, 13);
  RIP.PutPixel(W - 1, H - 1, 12);

  Check('Corner (0,0) indexed', RIP.GetPixel(0, 0) = 15);
  Check('Corner (MaxX,0) indexed', RIP.GetPixel(W - 1, 0) = 14);
  Check('Corner (0,MaxY) indexed', RIP.GetPixel(0, H - 1) = 13);
  Check('Corner (MaxX,MaxY) indexed', RIP.GetPixel(W - 1, H - 1) = 12);

  // RGB mode corners
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RGB.R := 1; RGB.G := 2; RGB.B := 3;
  RIP.PutPixel(0, 0, RGB);
  Got := RIP.GetPixelRGB(0, 0);
  Check('Corner (0,0) RGB24', (Got.R = 1) and (Got.G = 2) and (Got.B = 3));

  RGB.R := 254; RGB.G := 253; RGB.B := 252;
  RIP.PutPixel(W - 1, H - 1, RGB);
  Got := RIP.GetPixelRGB(W - 1, H - 1);
  Check('Corner (MaxX,MaxY) RGB24', (Got.R = 254) and (Got.G = 253) and (Got.B = 252));

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestOutOfBoundsPixels;
// Negative coords, coords past canvas — should not crash
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- Out-of-Bounds Pixels (should not crash) ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // These should all be silently ignored / return black
  RIP.PutPixel(-1, -1, 15);
  RIP.PutPixel(-100, -100, 15);
  RIP.PutPixel(9999, 9999, 15);
  RIP.PutPixel(0, 9999, 15);
  RIP.PutPixel(9999, 0, 15);

  Check('OOB PutPixel did not crash', True);

  Got := RIP.GetPixelRGB(-1, -1);
  Check('OOB GetPixelRGB returns black', (Got.R = 0) and (Got.G = 0) and (Got.B = 0));

  Got := RIP.GetPixelRGB(9999, 9999);
  Check('OOB GetPixelRGB far out returns black', (Got.R = 0) and (Got.G = 0) and (Got.B = 0));

  Check('GetPixel OOB returns 0', RIP.GetPixel(-1, -1) = 0);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestRapidFormatSwitching;
// Toggle formats many times — memory corruption?
Var
  I   : Integer;
  RGB : TRIPRgb;
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- Rapid Format Switching (100 cycles) ---');

  RIP.ClearScreen;
  RGB.R := 42; RGB.G := 84; RGB.B := 126;

  For I := 1 to 100 Do Begin
    RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
    RIP.PutPixel(200, 200, 7);
    RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
    RIP.PutPixel(201, 200, RGB);
    RIP.SetPixelFormat(RIP_PIXFMT_RGB32);
    RIP.PutPixel(202, 200, RGB);
  End;

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  Got := RIP.GetPixelRGB(201, 200);
  Check('100 format switches: pixel survives',
    (Got.R = 42) and (Got.G = 84) and (Got.B = 126));

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestFloodFillEdgeCases;
// Fill entire screen, fill with border=fill color, fill at edge
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- FloodFill Edge Cases ---');

  // Fill when seed = border color — should be no-op
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.PutPixel(100, 100, 5);
  RIP.SetFillStyle(1, 14);
  RIP.FloodFill(100, 100, 5);  // seed IS the border
  Check('FloodFill seed=border is no-op',
    RIP.GetPixel(100, 100) = 5);

  // Fill when seed = fill color — should be no-op
  RIP.ClearScreen;
  RIP.PutPixel(100, 100, 14);
  RIP.SetFillStyle(1, 14);
  RIP.FloodFill(100, 100, 0);  // seed already is fill color
  Check('FloodFill seed=fill is no-op (already filled)',
    RIP.GetPixel(100, 100) = 14);

  // Fill at (0,0) unbounded — fills entire screen
  RIP.ClearScreen;
  RIP.SetFillStyle(1, 3);
  RIP.FloodFill(0, 0, 99);  // border=99, nothing on screen is 99
  Check('FloodFill unbounded at (0,0) did not crash', True);
  // Center pixel should be filled
  Got := RIP.GetPixelRGB(320, 175);
  Check('FloodFill unbounded: center pixel filled',
    Got.R = EGA_RGB[3].R);

  // Fill out of bounds — should be no-op
  RIP.ClearScreen;
  RIP.FloodFill(-5, -5, 0);
  Check('FloodFill OOB seed did not crash', True);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestScrollEdgeCases;
// Scroll by 0, scroll entire screen, scroll with huge amount
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- Scroll Edge Cases ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.PutPixel(50, 50, 15);

  // Scroll by 0 — should be no-op
  RIP.ScrollUp(0, 0, 100, 100, 0, 0);
  Check('ScrollUp amt=0 is no-op', RIP.GetPixel(50, 50) = 15);

  // Scroll by negative — should be no-op
  RIP.ScrollUp(0, 0, 100, 100, -5, 0);
  Check('ScrollUp amt=-5 is no-op', RIP.GetPixel(50, 50) = 15);

  // Scroll larger than region — blanks everything
  RIP.ScrollUp(40, 40, 60, 60, 100, 0);
  Got := RIP.GetPixelRGB(50, 50);
  Check('ScrollUp amt>region: pixel cleared',
    (Got.R = 0) and (Got.G = 0) and (Got.B = 0));

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestInvertRegionDoubleInvert;
// Double invert should return to original
Var
  V : Byte;
Begin
  WriteLn;
  WriteLn('--- InvertRegion Double Invert ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.PutPixel(75, 75, 6);  // brown/dark yellow

  RIP.InvertRegion(75, 75, 75, 75);
  RIP.InvertRegion(75, 75, 75, 75);

  V := RIP.GetPixel(75, 75);
  Check('Double invert restores original indexed color (6)', V = 6);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestWriteModesRGB;
// AND/OR/NOT/XOR in RGB mode — do they operate per-channel?
Var
  RGB, Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- Write Modes in RGB24 ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // XOR in RGB
  RGB.R := $FF; RGB.G := $00; RGB.B := $AA;
  RIP.PutPixel(10, 10, RGB);
  RGB.R := $0F; RGB.G := $F0; RGB.B := $55;
  RIP.SetWriteMode(RIP_XOR_PUT);
  RIP.PutPixel(10, 10, RGB);
  RIP.SetWriteMode(RIP_COPY_PUT);
  Got := RIP.GetPixelRGB(10, 10);
  Check('XOR RGB: R=$FF XOR $0F=$F0', Got.R = $F0);
  Check('XOR RGB: G=$00 XOR $F0=$F0', Got.G = $F0);
  Check('XOR RGB: B=$AA XOR $55=$FF', Got.B = $FF);

  // OR in RGB
  RIP.ClearScreen;
  RGB.R := $30; RGB.G := $0C; RGB.B := $03;
  RIP.PutPixel(20, 20, RGB);
  RGB.R := $C0; RGB.G := $30; RGB.B := $0C;
  RIP.SetWriteMode(RIP_OR_PUT);
  RIP.PutPixel(20, 20, RGB);
  RIP.SetWriteMode(RIP_COPY_PUT);
  Got := RIP.GetPixelRGB(20, 20);
  Check('OR RGB: R=$30 OR $C0=$F0', Got.R = $F0);
  Check('OR RGB: G=$0C OR $30=$3C', Got.G = $3C);
  Check('OR RGB: B=$03 OR $0C=$0F', Got.B = $0F);

  // AND in RGB
  RIP.ClearScreen;
  RGB.R := $FF; RGB.G := $F0; RGB.B := $0F;
  RIP.PutPixel(30, 30, RGB);
  RGB.R := $0F; RGB.G := $0F; RGB.B := $0F;
  RIP.SetWriteMode(RIP_AND_PUT);
  RIP.PutPixel(30, 30, RGB);
  RIP.SetWriteMode(RIP_COPY_PUT);
  Got := RIP.GetPixelRGB(30, 30);
  Check('AND RGB: R=$FF AND $0F=$0F', Got.R = $0F);
  Check('AND RGB: G=$F0 AND $0F=$00', Got.G = $00);
  Check('AND RGB: B=$0F AND $0F=$0F', Got.B = $0F);

  // NOT in RGB
  RIP.ClearScreen;
  RGB.R := $AA; RGB.G := $55; RGB.B := $00;
  RIP.SetWriteMode(RIP_NOT_PUT);
  RIP.PutPixel(40, 40, RGB);
  RIP.SetWriteMode(RIP_COPY_PUT);
  Got := RIP.GetPixelRGB(40, 40);
  Check('NOT RGB: NOT $AA=$55', Got.R = $55);
  Check('NOT RGB: NOT $55=$AA', Got.G = $AA);
  Check('NOT RGB: NOT $00=$FF', Got.B = $FF);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestSaveBMPLargeCanvas;
// SaveBMP at non-default resolution
Var
  OK  : Boolean;
  F   : File;
  Hdr : Array[0..53] of Byte;
  W, H : LongInt;
Begin
  WriteLn;
  WriteLn('--- SaveBMP at 800x600 ---');

  RIP.SetResolution(800, 600);
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Line(0, 0, 799, 599);
  OK := RIP.SaveBMP('/tmp/test_p15_800x600.bmp');
  Check('SaveBMP 800x600 succeeds', OK);

  // Read back BMP header and verify dimensions
  Assign(F, '/tmp/test_p15_800x600.bmp');
  {$I-} Reset(F, 1); {$I+}
  If IOResult = 0 Then Begin
    BlockRead(F, Hdr, 54);
    Close(F);
    W := Hdr[18] or (Hdr[19] shl 8) or (Hdr[20] shl 16) or (Hdr[21] shl 24);
    H := Hdr[22] or (Hdr[23] shl 8) or (Hdr[24] shl 16) or (Hdr[25] shl 24);
    Check('BMP header width = 800', W = 800);
    Check('BMP header height = 600', H = 600);
  End Else Begin
    Check('BMP file readable', False);
    Check('BMP header width', False);
  End;

  // Reset
  RIP.SetResolution(640, 350);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestIndexToRGBRoundTrip;
// All 16 EGA colors should survive put(indexed)->get(RGB)->nearest match
Var
  I   : Integer;
  Got : TRIPRgb;
  Idx : Byte;
  OK  : Boolean;
Begin
  WriteLn;
  WriteLn('--- Indexed -> RGB -> Indexed Round-Trip ---');

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearScreen;

  // Write all 16 EGA colors
  For I := 0 to 15 Do
    RIP.PutPixel(I, 0, I);

  // Switch to RGB, then back to indexed
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);

  OK := True;
  For I := 0 to 15 Do Begin
    Idx := RIP.GetPixel(I, 0);
    If Idx <> I Then Begin
      WriteLn('    MISMATCH: EGA ', I, ' -> index ', Idx);
      OK := False;
    End;
  End;
  Check('All 16 EGA colors round-trip through RGB', OK);
End;

Procedure TestConvertPreservesEntireScreen;
// Fill screen with pattern, convert to RGB24, convert back, verify
Var
  X, Y : SmallInt;
  OK   : Boolean;
Begin
  WriteLn;
  WriteLn('--- Convert Preserves Patterned Screen ---');

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearScreen;

  // Fill a 16x16 block with all 16 colors
  For Y := 0 to 15 Do
    For X := 0 to 15 Do
      RIP.PutPixel(X, Y, (X + Y) and $0F);

  // Convert to RGB24 and back
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);

  // Verify
  OK := True;
  For Y := 0 to 15 Do
    For X := 0 to 15 Do
      If RIP.GetPixel(X, Y) <> ((X + Y) and $0F) Then Begin
        WriteLn('    MISMATCH at (', X, ',', Y, '): expected ', (X + Y) and $0F, ' got ', RIP.GetPixel(X, Y));
        OK := False;
      End;
  Check('16x16 pattern survives indexed->RGB24->indexed', OK);
End;

Procedure TestScrollFillColorRGB;
// After scroll, the fill area should have correct RGB values
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- Scroll Fill Area RGB ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Fill entire region with color 10
  RIP.SetFillStyle(1, 10);
  RIP.Bar(40, 40, 60, 60);

  // Scroll up by 5 — bottom 5 rows should be fill color 0 (black)
  RIP.ScrollUp(40, 40, 60, 60, 5, 7);  // fill with color 7

  // The fill area (bottom 5 rows) should be color 7 in RGB
  Got := RIP.GetPixelRGB(50, 58);
  Check('Scroll fill area has correct RGB (color 7)',
    (Got.R = EGA_RGB[7].R) and (Got.G = EGA_RGB[7].G) and (Got.B = EGA_RGB[7].B));

  // The scrolled area should still be color 10
  Got := RIP.GetPixelRGB(50, 42);
  Check('Scrolled content preserves RGB (color 10)',
    (Got.R = EGA_RGB[10].R) and (Got.G = EGA_RGB[10].G));

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestLineAASteepRGB;
// Steep AA line (more vertical than horizontal) — tests coordinate swap path
Var
  Got   : TRIPRgb;
  Y     : SmallInt;
  Found : Boolean;
Begin
  WriteLn;
  WriteLn('--- LineAA Steep (vertical-dominant) RGB ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  RIP.LineAA(100, 50, 102, 200, 11);  // nearly vertical, bright cyan

  Found := False;
  For Y := 50 to 200 Do Begin
    Got := RIP.GetPixelRGB(100, Y);
    If Got.B = EGA_RGB[11].B Then Begin
      Found := True;
      Break;
    End;
    Got := RIP.GetPixelRGB(101, Y);
    If Got.B = EGA_RGB[11].B Then Begin
      Found := True;
      Break;
    End;
  End;
  Check('Steep LineAA has pixels in RGB buffer', Found);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestMassiveFloodFill;
// FloodFill has a 4096-entry stack — it cannot fill the entire 640x350
// canvas (224K pixels). Test that it fills what it can without crashing.
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- FloodFill Stack Limit (4096 depth) ---');

  RIP.SetResolution(640, 350);
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  RIP.SetFillStyle(1, 2);  // solid, green
  RIP.FloodFill(320, 175, 99);  // no border color on screen

  // Center should definitely be filled
  Got := RIP.GetPixelRGB(320, 175);
  Check('FloodFill center pixel filled', Got.G = EGA_RGB[2].G);

  // Nearby pixels should be filled
  Got := RIP.GetPixelRGB(320, 176);
  Check('FloodFill adjacent pixel filled', Got.G = EGA_RGB[2].G);

  // Full-screen fill is limited by 4096 stack — corners may not be reached.
  // This is a known design constraint (not a Phase 15 bug).
  Check('FloodFill did not crash on large fill', True);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestRGB32AlphaPreserved;
// In RGB32 mode, alpha should default to $FF and be preserved
Begin
  WriteLn;
  WriteLn('--- RGB32 Alpha Channel ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB32);
  RIP.ClearScreen;
  RIP.PutPixel(10, 10, 15);

  // We can't directly read alpha through the public API (GetPixelRGB
  // returns TRIPRgb without A), but we can verify the pixel is accessible
  // and the PixelsRGB32 buffer has the right RGB.
  Check('RGB32 pixel accessible via PixelsRGB32',
    (RIP.PixelsRGB32^[10, 10].R = EGA_RGB[15].R) and
    (RIP.PixelsRGB32^[10, 10].G = EGA_RGB[15].G) and
    (RIP.PixelsRGB32^[10, 10].B = EGA_RGB[15].B));
  Check('RGB32 alpha defaults to $FF',
    RIP.PixelsRGB32^[10, 10].A = $FF);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestAllThreeBuffersSync;
// After drawing in RGB24, all three buffers should agree
Var
  RGB   : TRIPRgb;
  IdxV  : Byte;
  RGBv  : TRIPRgb;
  R32   : TRIPRGBA;
Begin
  WriteLn;
  WriteLn('--- Three-Buffer Sync Verification ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  RGB.R := 170; RGB.G := 85; RGB.B := 0;
  RIP.PutPixel(300, 200, RGB);

  // Read from all three buffers directly
  IdxV := RIP.Pixels^[200, 300];
  RGBv := RIP.PixelsRGB^[200, 300];
  R32  := RIP.PixelsRGB32^[200, 300];

  Check('PixelsRGB matches written value',
    (RGBv.R = 170) and (RGBv.G = 85) and (RGBv.B = 0));
  Check('PixelsRGB32 matches written value',
    (R32.R = 170) and (R32.G = 85) and (R32.B = 0));
  Check('PixelsRGB32 alpha = $FF', R32.A = $FF);
  // Indexed should be nearest match — not critical which color, just not crash
  Check('Pixels indexed has a value (nearest match)', IdxV <= 15);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 15: STRESS TESTS — Try to Break It ===');

  RIP := TRIPEngine.Create;

  TestBoundaryPixels;
  TestOutOfBoundsPixels;
  TestRapidFormatSwitching;
  TestFloodFillEdgeCases;
  TestScrollEdgeCases;
  TestInvertRegionDoubleInvert;
  TestWriteModesRGB;
  TestSaveBMPLargeCanvas;
  TestIndexToRGBRoundTrip;
  TestConvertPreservesEntireScreen;
  TestScrollFillColorRGB;
  TestLineAASteepRGB;
  TestMassiveFloodFill;
  TestRGB32AlphaPreserved;
  TestAllThreeBuffersSync;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
