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
Program test_phase15;
// Phase 15 verification tests — exercises all fixed code paths
// and validates the 24-bit true color pixel buffer implementation.

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

Procedure TestPixelFormats;
// Item 5: indexed default, Item 6: format switching
Begin
  WriteLn;
  WriteLn('--- Pixel Format Switching ---');

  Check('Default format is INDEXED8',
    RIP.GetPixelFormat = RIP_PIXFMT_INDEXED8);

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  Check('Switch to RGB24',
    RIP.GetPixelFormat = RIP_PIXFMT_RGB24);

  RIP.SetPixelFormat(RIP_PIXFMT_RGB32);
  Check('Switch to RGB32',
    RIP.GetPixelFormat = RIP_PIXFMT_RGB32);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  Check('Switch back to INDEXED8',
    RIP.GetPixelFormat = RIP_PIXFMT_INDEXED8);

  // Out of range clamps
  RIP.SetPixelFormat(99);
  Check('Out-of-range clamps to RGB32',
    RIP.GetPixelFormat = RIP_PIXFMT_RGB32);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestDrawPixelIndexed;
// Item 4: DrawPixel/GetPixel, Item 8: primitives in indexed mode
Var
  RGB : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- DrawPixel (Indexed Mode) ---');

  RIP.ClearScreen;
  RIP.PutPixel(100, 100, 14);
  Check('PutPixel indexed: GetPixel reads back',
    RIP.GetPixel(100, 100) = 14);

  RGB := RIP.GetPixelRGB(100, 100);
  Check('GetPixelRGB reads EGA yellow R',
    RGB.R = EGA_RGB[14].R);
  Check('GetPixelRGB reads EGA yellow G',
    RGB.G = EGA_RGB[14].G);
  Check('GetPixelRGB reads EGA yellow B',
    RGB.B = EGA_RGB[14].B);
End;

Procedure TestDrawPixelRGB;
// Item 1,2,3,4: RGB buffer, TrueColor, TRIPRGB type, DrawPixel RGB
Var
  RGB, Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- DrawPixel (RGB24 Mode) ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  RGB.R := 128; RGB.G := 64; RGB.B := 200;
  RIP.PutPixel(200, 150, RGB);
  Got := RIP.GetPixelRGB(200, 150);

  Check('PutPixel RGB24: R round-trip', Got.R = 128);
  Check('PutPixel RGB24: G round-trip', Got.G = 64);
  Check('PutPixel RGB24: B round-trip', Got.B = 200);

  // Indexed pixel in RGB mode should promote via palette
  RIP.PutPixel(201, 150, 10);  // bright green
  Got := RIP.GetPixelRGB(201, 150);
  Check('Indexed pixel promoted to RGB in RGB24 mode',
    (Got.R = EGA_RGB[10].R) and (Got.G = EGA_RGB[10].G));

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestDrawPixelRGB32;
// Item 2: 32-bit TrueColor
Var
  RGB, Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- DrawPixel (RGB32 Mode) ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB32);
  RIP.ClearScreen;

  RGB.R := 255; RGB.G := 0; RGB.B := 127;
  RIP.PutPixel(300, 200, RGB);
  Got := RIP.GetPixelRGB(300, 200);

  Check('PutPixel RGB32: R round-trip', Got.R = 255);
  Check('PutPixel RGB32: G round-trip', Got.G = 0);
  Check('PutPixel RGB32: B round-trip', Got.B = 127);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestColorRGBAccessors;
// Item 3: TRIPRGB type used by color accessors
Var
  RGB, Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- SetColorRGB / SetFillColorRGB ---');

  RGB.R := 100; RGB.G := 150; RGB.B := 200;
  RIP.SetColorRGB(RGB);
  Got := RIP.GetColorRGB;
  Check('SetColorRGB/GetColorRGB round-trip',
    (Got.R = 100) and (Got.G = 150) and (Got.B = 200));

  RGB.R := 50; RGB.G := 75; RGB.B := 25;
  RIP.SetFillColorRGB(RGB);
  Got := RIP.GetFillColorRGB;
  Check('SetFillColorRGB/GetFillColorRGB round-trip',
    (Got.R = 50) and (Got.G = 75) and (Got.B = 25));
End;

Procedure TestConvertPixelFormat;
// Item 6: convert framebuffer content on switch
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- ConvertPixelFormat ---');

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearScreen;
  RIP.PutPixel(50, 50, 12);  // bright red

  // Convert to RGB24 — pixel should preserve color
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  Got := RIP.GetPixelRGB(50, 50);
  Check('Indexed->RGB24 conversion preserves color',
    (Got.R = EGA_RGB[12].R) and (Got.G = EGA_RGB[12].G) and (Got.B = EGA_RGB[12].B));

  // Convert back to indexed
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  Check('RGB24->Indexed conversion preserves nearest color',
    RIP.GetPixel(50, 50) = 12);
End;

Procedure TestWriteModes;
// Item 9: AND/OR/NOT write modes
Var
  V : Byte;
Begin
  WriteLn;
  WriteLn('--- Write Modes (AND/OR/NOT) ---');

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearScreen;

  // OR mode
  RIP.PutPixel(10, 10, 3);  // 0011
  RIP.SetWriteMode(RIP_OR_PUT);
  RIP.PutPixel(10, 10, 12); // 1100
  RIP.SetWriteMode(RIP_COPY_PUT);
  V := RIP.GetPixel(10, 10);
  Check('OR write mode: 3 OR 12 = 15', V = 15);

  // AND mode
  RIP.PutPixel(11, 10, 15); // 1111
  RIP.SetWriteMode(RIP_AND_PUT);
  RIP.PutPixel(11, 10, 5);  // 0101
  RIP.SetWriteMode(RIP_COPY_PUT);
  V := RIP.GetPixel(11, 10);
  Check('AND write mode: 15 AND 5 = 5', V = 5);

  // AND mode with Color=7 — should be no-op
  RIP.PutPixel(12, 10, 14); // 1110
  RIP.SetWriteMode(RIP_AND_PUT);
  RIP.PutPixel(12, 10, 7);  // no-op guard
  RIP.SetWriteMode(RIP_COPY_PUT);
  V := RIP.GetPixel(12, 10);
  Check('AND write mode Color=7 is no-op: pixel unchanged (14)', V = 14);

  // NOT mode
  RIP.PutPixel(13, 10, 0);
  RIP.SetWriteMode(RIP_NOT_PUT);
  RIP.PutPixel(13, 10, 5);  // NOT 5 = 250 AND $FF = $FA, but indexed is low nibble
  RIP.SetWriteMode(RIP_COPY_PUT);
  V := RIP.GetPixel(13, 10);
  Check('NOT write mode: NOT 5 = $FA', V = $FA);
End;

Procedure TestFloodFillRGBSync;
// Bug fix: FloodFill now routes through DrawPixel
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- FloodFill RGB Sync ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Draw a box outline in color 15
  RIP.SetColor(15);
  RIP.Rectangle(10, 10, 20, 20);

  // Flood fill inside with color 14
  RIP.SetFillStyle(1, 14);  // solid, yellow
  RIP.FloodFill(15, 15, 15); // border=15

  Got := RIP.GetPixelRGB(15, 15);
  Check('FloodFill RGB sync: filled pixel has EGA yellow R',
    Got.R = EGA_RGB[14].R);
  Check('FloodFill RGB sync: filled pixel has EGA yellow G',
    Got.G = EGA_RGB[14].G);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestInvertRegionRGBSync;
// Bug fix: InvertRegion now routes through DrawPixel
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- InvertRegion RGB Sync ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Put a known pixel
  RIP.PutPixel(30, 30, 0);   // black (0)
  RIP.InvertRegion(30, 30, 30, 30); // XOR $0F -> 15 (white)

  Got := RIP.GetPixelRGB(30, 30);
  Check('InvertRegion RGB sync: inverted pixel has EGA white R',
    Got.R = EGA_RGB[15].R);
  Check('InvertRegion RGB sync: inverted pixel has EGA white G',
    Got.G = EGA_RGB[15].G);
  Check('InvertRegion RGB sync: inverted pixel has EGA white B',
    Got.B = EGA_RGB[15].B);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestScrollRGBSync;
// Bug fix: Scroll routines now copy all three buffers
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- Scroll RGB Sync ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Place a pixel and scroll it up
  RIP.PutPixel(50, 60, 9);  // bright blue
  RIP.ScrollUp(40, 50, 60, 70, 5, 0);
  // Pixel at (50,60) should now be at (50,55)
  Got := RIP.GetPixelRGB(50, 55);
  Check('ScrollUp RGB sync: scrolled pixel R',
    Got.R = EGA_RGB[9].R);
  Check('ScrollUp RGB sync: scrolled pixel B',
    Got.B = EGA_RGB[9].B);

  // ScrollDn test
  RIP.ClearScreen;
  RIP.PutPixel(50, 50, 11); // bright cyan
  RIP.ScrollDn(40, 40, 60, 60, 3, 0);
  Got := RIP.GetPixelRGB(50, 53);
  Check('ScrollDn RGB sync: scrolled pixel R',
    Got.R = EGA_RGB[11].R);

  // ScrollLt test
  RIP.ClearScreen;
  RIP.PutPixel(55, 50, 13); // bright magenta
  RIP.ScrollLt(40, 40, 60, 60, 5, 0);
  Got := RIP.GetPixelRGB(50, 50);
  Check('ScrollLt RGB sync: scrolled pixel R',
    Got.R = EGA_RGB[13].R);

  // ScrollRt test
  RIP.ClearScreen;
  RIP.PutPixel(50, 50, 10); // bright green
  RIP.ScrollRt(40, 40, 60, 60, 5, 0);
  Got := RIP.GetPixelRGB(55, 50);
  Check('ScrollRt RGB sync: scrolled pixel G',
    Got.G = EGA_RGB[10].G);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestLineAARGBSync;
// Bug fix: LineAA now routes through DrawPixel
Var
  Got  : TRIPRgb;
  X    : SmallInt;
  Found: Boolean;
Begin
  WriteLn;
  WriteLn('--- LineAA RGB Sync ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  RIP.LineAA(100, 100, 200, 100, 14);  // horizontal yellow AA line

  // At least one pixel along the line should be yellow in RGB
  Found := False;
  For X := 100 to 200 Do Begin
    Got := RIP.GetPixelRGB(X, 100);
    If (Got.R = EGA_RGB[14].R) and (Got.G = EGA_RGB[14].G) Then Begin
      Found := True;
      Break;
    End;
  End;
  Check('LineAA RGB sync: at least one pixel is EGA yellow', Found);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestSaveBMP;
// Item 7: SaveBMP uses CanvasWidth/Height, native 24-bit
Var
  OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- SaveBMP ---');

  // Indexed mode
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.ClearScreen;
  RIP.PutPixel(0, 0, 15);
  OK := RIP.SaveBMP('/tmp/test_p15_indexed.bmp');
  Check('SaveBMP indexed mode succeeds', OK);

  // RGB24 mode
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.PutPixel(0, 0, 15);
  OK := RIP.SaveBMP('/tmp/test_p15_rgb24.bmp');
  Check('SaveBMP RGB24 mode succeeds', OK);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestClearScreenRGB;
// Verify ClearScreen zeros all three buffers
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- ClearScreen RGB ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.PutPixel(0, 0, 15);
  RIP.ClearScreen;
  Got := RIP.GetPixelRGB(0, 0);
  Check('ClearScreen zeros RGB buffer', (Got.R = 0) and (Got.G = 0) and (Got.B = 0));

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestClearViewportRGB;
// Verify ClearViewport zeros RGB within viewport
Var
  Got : TRIPRgb;
Begin
  WriteLn;
  WriteLn('--- ClearViewport RGB ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.SetViewPort(10, 10, 50, 50, True);
  RIP.PutPixel(20, 20, 14);
  RIP.ClearViewport;
  Got := RIP.GetPixelRGB(20, 20);
  Check('ClearViewport zeros RGB in viewport',
    (Got.R = 0) and (Got.G = 0) and (Got.B = 0));

  // Reset viewport
  RIP.SetViewPort(0, 0, RIP.GetCanvasWidth - 1, RIP.GetCanvasHeight - 1, True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestPrimitivesRGBSync;
// Item 8: all drawing primitives route through DrawPixel
Var
  Got   : TRIPRgb;
  Found : Boolean;
  X, Y  : SmallInt;
Begin
  WriteLn;
  WriteLn('--- Primitives RGB Sync ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;

  // Line
  RIP.SetColor(12); // bright red
  RIP.Line(0, 0, 50, 0);
  Got := RIP.GetPixelRGB(25, 0);
  Check('Line RGB sync', Got.R = EGA_RGB[12].R);

  // Rectangle
  RIP.ClearScreen;
  RIP.SetColor(10); // bright green
  RIP.Rectangle(5, 5, 30, 30);
  Got := RIP.GetPixelRGB(5, 15);
  Check('Rectangle RGB sync', Got.G = EGA_RGB[10].G);

  // Bar (filled rect)
  RIP.ClearScreen;
  RIP.SetFillStyle(1, 11); // solid, bright cyan
  RIP.Bar(10, 10, 40, 40);
  Got := RIP.GetPixelRGB(25, 25);
  Check('Bar RGB sync', Got.B = EGA_RGB[11].B);

  // Circle
  RIP.ClearScreen;
  RIP.SetColor(13); // bright magenta
  RIP.Circle(100, 100, 20);
  // Find any non-black pixel on the circle
  Found := False;
  For X := 80 to 120 Do Begin
    Got := RIP.GetPixelRGB(X, 100);
    If Got.R = EGA_RGB[13].R Then Begin
      Found := True;
      Break;
    End;
  End;
  Check('Circle RGB sync', Found);

  // FillEllipse
  RIP.ClearScreen;
  RIP.SetFillStyle(1, 9); // solid, bright blue
  RIP.FillEllipse(150, 150, 15, 10);
  Got := RIP.GetPixelRGB(150, 150);
  Check('FillEllipse RGB sync', Got.B = EGA_RGB[9].B);

  // Text
  RIP.ClearScreen;
  RIP.SetColor(15); // white
  RIP.OutTextXY(0, 0, 'A');
  // Check that at least one pixel of the letter is white in RGB
  Found := False;
  For Y := 0 to 7 Do
    For X := 0 to 7 Do Begin
      Got := RIP.GetPixelRGB(X, Y);
      If (Got.R = 255) and (Got.G = 255) and (Got.B = 255) Then Begin
        Found := True;
        Break;
      End;
    End;
  Check('Text RGB sync', Found);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 15: True Color Pixel Buffer — Verification Tests ===');

  RIP := TRIPEngine.Create;

  TestPixelFormats;
  TestDrawPixelIndexed;
  TestDrawPixelRGB;
  TestDrawPixelRGB32;
  TestColorRGBAccessors;
  TestConvertPixelFormat;
  TestWriteModes;
  TestFloodFillRGBSync;
  TestInvertRegionRGBSync;
  TestScrollRGBSync;
  TestLineAARGBSync;
  TestSaveBMP;
  TestClearScreenRGB;
  TestClearViewportRGB;
  TestPrimitivesRGBSync;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
