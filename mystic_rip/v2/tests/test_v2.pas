{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// RIPscrip v2.0 Engine Test Suite — 67 tests
// Compile: ppcx64 -Mdelphi -Fu<path-to-mystic_ripapi2> -Fu<path>/img -Fu<path>/pasjpeg test_v2.pas
//
// Tests v1.54 inherited core:
//   Create/Reset, Pixels (corners, OOB), Lines (H/V/diagonal),
//   Shapes (Rectangle, Bar, FillEllipse), Text Variables,
//   Screen Save/Restore, Write Mode (XOR), FloodFill, SaveBMP,
//   ProcessLine (|c, |X)
//
// Tests v2.0 features:
//   Resolution (SetResolution, GetCanvasWidth/Height),
//   Protocol Version, Scrolling (Up/Dn/Lt/Rt),
//   256-color Palette (PalFade, PalRotate),
//   Anti-Aliased Line (LineAA), Sprites (Get/Put),
//   Animation (FrameRate, FadeIn/Out),
//   File Formats (LoadJPG, LoadRFF, LoadBMH, LoadPAL),
//   Mouse Fields (|1M, |1b extended button),
//   v2.0 Commands (|J, |n, |M, |k, |K),
//   CopyRegion, System Font metrics
//
Program test_v2;

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

// ==== Inherited v1.54 Core ====

Procedure TestCreateReset;
Begin
  WriteLn;
  WriteLn('--- Create / Reset ---');
  Check('Engine created', RIP <> Nil);
  Check('GetMaxX = 639', RIP.GetMaxX = 639);
  Check('GetMaxY = 349', RIP.GetMaxY = 349);
  RIP.SetColor(14);
  RIP.Reset;
  Check('Reset: color = 15', RIP.GetColor = 15);
  Check('Reset: CurX = 0', RIP.GetX = 0);
End;

Procedure TestPixels;
Begin
  WriteLn;
  WriteLn('--- Pixels ---');
  RIP.ClearScreen;
  RIP.PutPixel(0, 0, 15);
  Check('PutPixel (0,0,15)', RIP.GetPixel(0, 0) = 15);
  RIP.PutPixel(639, 349, 7);
  Check('PutPixel (639,349,7)', RIP.GetPixel(639, 349) = 7);
  RIP.PutPixel(-1, -1, 15);
  Check('OOB pixel: no crash', True);
  Check('OOB pixel: returns 0', RIP.GetPixel(-1, -1) = 0);
End;

Procedure TestLines;
Begin
  WriteLn;
  WriteLn('--- Lines ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Line(0, 0, 100, 0);
  Check('Horizontal line', RIP.GetPixel(50, 0) = 15);
  RIP.ClearScreen;
  RIP.Line(0, 0, 0, 100);
  Check('Vertical line', RIP.GetPixel(0, 50) = 15);
  RIP.ClearScreen;
  RIP.Line(0, 0, 100, 100);
  Check('Diagonal line', RIP.GetPixel(50, 50) = 15);
End;

Procedure TestShapes;
Begin
  WriteLn;
  WriteLn('--- Shapes ---');
  RIP.ClearScreen;
  RIP.SetColor(12);
  RIP.Rectangle(10, 10, 50, 50);
  Check('Rectangle: top edge', RIP.GetPixel(30, 10) = 12);
  Check('Rectangle: center empty', RIP.GetPixel(30, 30) = 0);

  RIP.ClearScreen;
  RIP.SetFillStyle(1, 11);
  RIP.Bar(20, 20, 60, 60);
  Check('Bar: center filled', RIP.GetPixel(40, 40) = 11);

  RIP.ClearScreen;
  RIP.SetColor(13);
  RIP.SetFillStyle(1, 13);
  RIP.FillEllipse(200, 175, 30, 20);
  Check('FillEllipse: center', RIP.GetPixel(200, 175) = 13);
End;

Procedure TestTextVars;
Begin
  WriteLn;
  WriteLn('--- Text Variables ---');
  RIP.DefineVar('TEST', 'hello', False, False);
  Check('DefineVar/GetVar', RIP.GetVar('TEST') = 'hello');
  RIP.SetVar('TEST', 'world');
  Check('SetVar', RIP.GetVar('TEST') = 'world');
  Check('ExpandVars', RIP.ExpandVars('$TEST$') = 'world');
  RIP.KillAllVars;
  Check('KillAllVars', RIP.GetVar('TEST') = '');
End;

Procedure TestScreenSave;
Begin
  WriteLn;
  WriteLn('--- Screen Save/Restore ---');
  RIP.ClearScreen;
  RIP.PutPixel(50, 50, 14);
  RIP.SaveScreen(0);
  RIP.ClearScreen;
  Check('Cleared', RIP.GetPixel(50, 50) = 0);
  RIP.RestoreScreen(0);
  Check('Restored', RIP.GetPixel(50, 50) = 14);
End;

Procedure TestWriteMode;
Begin
  WriteLn;
  WriteLn('--- Write Mode ---');
  RIP.ClearScreen;
  RIP.PutPixel(10, 10, 15);
  RIP.SetWriteMode(1);
  RIP.PutPixel(10, 10, 15);
  RIP.SetWriteMode(0);
  Check('XOR: 15 XOR 15 = 0', RIP.GetPixel(10, 10) = 0);
End;

Procedure TestFloodFill;
Begin
  WriteLn;
  WriteLn('--- FloodFill ---');
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.Rectangle(10, 10, 40, 40);
  RIP.SetFillStyle(1, 14);
  RIP.FloodFill(25, 25, 15);
  Check('Center filled', RIP.GetPixel(25, 25) = 14);
  Check('Border preserved', RIP.GetPixel(10, 25) = 15);
End;

Procedure TestSaveBMP;
Begin
  WriteLn;
  WriteLn('--- SaveBMP ---');
  RIP.ClearScreen;
  RIP.PutPixel(0, 0, 15);
  Check('SaveBMP', RIP.SaveBMP('/tmp/test_v2.bmp'));
End;

Procedure TestProcessLine;
Begin
  WriteLn;
  WriteLn('--- ProcessLine ---');
  RIP.Reset;
  RIP.ClearScreen;
  RIP.ProcessLine('!|c0F');
  Check('!|c0F: color=15', RIP.GetColor = 15);
  RIP.ProcessLine('!|X0A0A');
  Check('!|X0A0A: pixel at (10,10)', RIP.GetPixel(10, 10) = 15);
End;

// ==== v2.0 Specific Features ====

Procedure TestResolution;
Begin
  WriteLn;
  WriteLn('--- v2.0 Resolution ---');
  RIP.SetResolution(800, 600);
  Check('SetResolution 800x600: width', RIP.GetCanvasWidth = 800);
  Check('SetResolution 800x600: height', RIP.GetCanvasHeight = 600);
  Check('GetMaxX = 799', RIP.GetMaxX = 799);
  Check('GetMaxY = 599', RIP.GetMaxY = 599);

  // Draw at new resolution
  RIP.ClearScreen;
  RIP.PutPixel(799, 599, 15);
  Check('Pixel at (799,599)', RIP.GetPixel(799, 599) = 15);

  RIP.SetResolution(640, 350);
End;

Procedure TestProtoVersion;
Begin
  WriteLn;
  WriteLn('--- v2.0 Protocol Version ---');
  Check('GetProtoVersion defined', RIP.GetProtoVersion >= 0);
End;

Procedure TestScrolling;
Begin
  WriteLn;
  WriteLn('--- v2.0 Scrolling ---');
  RIP.ClearScreen;
  RIP.PutPixel(50, 60, 14);
  RIP.ScrollUp(40, 50, 60, 70, 5, 0);
  Check('ScrollUp: pixel moved to (50,55)', RIP.GetPixel(50, 55) = 14);

  RIP.ClearScreen;
  RIP.PutPixel(50, 50, 11);
  RIP.ScrollDn(40, 40, 60, 60, 3, 0);
  Check('ScrollDn: pixel moved to (50,53)', RIP.GetPixel(50, 53) = 11);

  RIP.ClearScreen;
  RIP.PutPixel(55, 50, 13);
  RIP.ScrollLt(40, 40, 60, 60, 5, 0);
  Check('ScrollLt: pixel moved to (50,50)', RIP.GetPixel(50, 50) = 13);

  RIP.ClearScreen;
  RIP.PutPixel(50, 50, 10);
  RIP.ScrollRt(40, 40, 60, 60, 5, 0);
  Check('ScrollRt: pixel moved to (55,50)', RIP.GetPixel(55, 50) = 10);
End;

Procedure TestPalette256;
Begin
  WriteLn;
  WriteLn('--- v2.0 Palette ---');
  RIP.SetPalette(0, 63);
  RIP.SetPalette(200, 42);
  Check('SetPalette(200,42): no crash', True);

  RIP.PalFade(0, 15, 50);
  Check('PalFade: no crash', True);

  RIP.PalRotate(0, 15, 1);
  Check('PalRotate: no crash', True);
End;

Procedure TestLineAA;
Begin
  WriteLn;
  WriteLn('--- v2.0 Anti-Aliased Line ---');
  RIP.ClearScreen;
  RIP.LineAA(0, 0, 100, 50, 15);
  Check('LineAA: no crash', True);
  // Some pixel should be drawn along the line
  Check('LineAA: pixel at (50,25)', RIP.GetPixel(50, 25) = 15);
End;

Procedure TestSprites;
Var
  Sprite : Array[0..101] of Byte;
  Bkgnd  : Array[0..101] of Byte;
Begin
  WriteLn;
  WriteLn('--- v2.0 Sprites ---');
  RIP.ClearScreen;
  RIP.PutPixel(100, 100, 15);
  RIP.SpriteGet(98, 98, 5, 5, Sprite, Bkgnd);
  Check('SpriteGet: no crash', True);

  RIP.ClearScreen;
  RIP.SpritePut(200, 200, Sprite, 0);
  Check('SpritePut: no crash', True);
End;

Procedure TestAnimation;
Begin
  WriteLn;
  WriteLn('--- v2.0 Animation ---');
  RIP.SetFrameRate(30);
  Check('SetFrameRate(30)', RIP.GetFrameRate = 30);

  RIP.FadeIn(10);
  Check('FadeIn: no crash', True);

  RIP.FadeOut(10);
  Check('FadeOut: no crash', True);
End;

Procedure TestLoadJPG;
Var OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- v2.0 LoadJPG ---');
  OK := RIP.LoadJPG('/tmp/nonexistent.jpg', 0, 0);
  Check('LoadJPG nonexistent: returns false', Not OK);
End;

Procedure TestLoadRFF;
Var OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- v2.0 LoadRFF ---');
  OK := RIP.LoadRFF(1, '/tmp/nonexistent.rff');
  Check('LoadRFF nonexistent: returns false', Not OK);

  OK := RIP.LoadRFF(0, '/tmp/test.rff');
  Check('LoadRFF bad slot 0: returns false', Not OK);

  OK := RIP.LoadRFF(11, '/tmp/test.rff');
  Check('LoadRFF bad slot 11: returns false', Not OK);
End;

Procedure TestLoadBMH;
Var OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- v2.0 LoadBMH ---');
  OK := RIP.LoadBMH('/tmp/nonexistent.bmh', 0, 0);
  Check('LoadBMH nonexistent: returns false', Not OK);
End;

Procedure TestLoadPAL;
Var OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- v2.0 LoadPAL ---');
  OK := RIP.LoadPAL('/tmp/nonexistent.pal');
  Check('LoadPAL nonexistent: returns false', Not OK);
End;

Procedure TestMouseFields;
Begin
  WriteLn;
  WriteLn('--- Mouse Fields ---');
  RIP.Reset;
  RIP.ProcessLine('!|1M0A0A1E1E0100Test^cmd');
  Check('Mouse field added', RIP.FindMouseField(15, 15) > 0);
  Check('Outside returns 0', RIP.FindMouseField(0, 0) = 0);
End;

Procedure TestExtendedButton;
Begin
  WriteLn;
  WriteLn('--- v2.0 Extended Button (|1b) ---');
  RIP.Reset;
  RIP.ProcessLine('!|1b0A0A3232');
  Check('Extended button: mouse field created',
    RIP.FindMouseField(15, 15) > 0);
End;

Procedure TestV2Commands;
Begin
  WriteLn;
  WriteLn('--- v2.0 RIP Commands ---');
  RIP.Reset;

  // |J nn — protocol version
  RIP.ProcessLine('!|J10');
  Check('|J protocol version: no crash', True);

  // |n nnnn — set resolution
  RIP.ProcessLine('!|n2000');
  Check('|n set resolution: no crash', True);

  // |M nn — color mode
  RIP.ProcessLine('!|M08');
  Check('|M color mode: no crash', True);

  // |k nn — pen width
  RIP.ProcessLine('!|k02');
  Check('|k pen width: no crash', True);

  // |K nnnnnnnn — clear region
  RIP.ProcessLine('!|K0A0A3232');
  Check('|K clear region: no crash', True);

  RIP.SetResolution(640, 350);
End;

Procedure TestCopyRegion;
Begin
  WriteLn;
  WriteLn('--- CopyRegion ---');
  RIP.ClearScreen;
  RIP.PutPixel(50, 10, 12);
  RIP.CopyRegion(40, 5, 60, 15, 100);
  Check('Pixel copied to dest row', RIP.GetPixel(50, 105) = 12);
End;

Procedure TestSysFont;
Begin
  WriteLn;
  WriteLn('--- System Font ---');
  Check('GetSysFontW > 0', RIP.GetSysFontW > 0);
  Check('GetSysFontH > 0', RIP.GetSysFontH > 0);
  Check('GetSysCols > 0', RIP.GetSysCols > 0);
  Check('GetSysRows > 0', RIP.GetSysRows > 0);
End;

Procedure TestWAVStreaming;
Var Buf : Array[0..255] of Byte;
Begin
  WriteLn;
  WriteLn('--- WAV Streaming ---');
  Check('StreamInit 8kHz mono', RIP.WAVStreamInit(8000, 8, 1));
  Check('IsPlaying after init', RIP.WAVStreamIsPlaying);
  FillChar(Buf, 256, 128);
  RIP.WAVStreamFeed(@Buf, 256);
  Check('Feed 256 bytes: no crash', True);
  RIP.WAVStreamFeed(@Buf, 256);
  Check('Feed again: no crash', True);
  RIP.WAVStreamStop;
  Check('Stop: not playing', Not RIP.WAVStreamIsPlaying);
  Check('StreamInit 44100 stereo 16', RIP.WAVStreamInit(44100, 16, 2));
  RIP.WAVStreamStop;
  Check('StreamInit 0 Hz: false', Not RIP.WAVStreamInit(0, 8, 1));
  Check('StreamInit 99kHz: false', Not RIP.WAVStreamInit(99000, 8, 1));
  Check('StreamInit 4-bit: false', Not RIP.WAVStreamInit(8000, 4, 1));
  Check('StreamInit 3-chan: false', Not RIP.WAVStreamInit(8000, 8, 3));
  RIP.WAVStreamFeed(@Buf, 256);
  Check('Feed when stopped: no crash', True);
  RIP.WAVStreamFeed(Nil, 0);
  Check('Feed nil: no crash', True);
  RIP.WAVStreamStop;
  Check('Double stop: no crash', True);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== RIPscrip v2.0 Engine — Test Suite ===');

  RIP := TRIPEngine.Create;

  // v1.54 inherited
  TestCreateReset;
  TestPixels;
  TestLines;
  TestShapes;
  TestTextVars;
  TestScreenSave;
  TestWriteMode;
  TestFloodFill;
  TestSaveBMP;
  TestProcessLine;

  // v2.0 specific
  TestResolution;
  TestProtoVersion;
  TestScrolling;
  TestPalette256;
  TestLineAA;
  TestSprites;
  TestAnimation;
  TestLoadJPG;
  TestLoadRFF;
  TestLoadBMH;
  TestLoadPAL;
  TestMouseFields;
  TestExtendedButton;
  TestV2Commands;
  TestCopyRegion;
  TestSysFont;
  TestWAVStreaming;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
