{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
Program test_phase18;
// Phase 18: Scalable Font Rendering — stress tests

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

Procedure TestLoadRFFNonexistent;
Var OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- LoadRFF Nonexistent ---');

  OK := RIP.LoadRFF(1, '/tmp/nonexistent.rff');
  Check('LoadRFF nonexistent: returns false', Not OK);
End;

Procedure TestLoadRFFBadSlot;
Var OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- LoadRFF Bad Slot ---');

  OK := RIP.LoadRFF(0, '/tmp/test.rff');
  Check('LoadRFF slot 0: returns false', Not OK);

  OK := RIP.LoadRFF(9, '/tmp/test.rff');
  Check('LoadRFF slot 9: returns false', Not OK);

  OK := RIP.LoadRFF(255, '/tmp/test.rff');
  Check('LoadRFF slot 255: returns false', Not OK);
End;

Procedure TestFreeRFFEmpty;
Begin
  WriteLn;
  WriteLn('--- FreeRFF Empty Slots ---');

  RIP.FreeRFF(1);
  Check('FreeRFF empty slot 1: no crash', True);

  RIP.FreeRFF(0);
  Check('FreeRFF slot 0: no crash', True);

  RIP.FreeRFF(255);
  Check('FreeRFF slot 255: no crash', True);
End;

Procedure TestSetRFFFontNoFont;
Begin
  WriteLn;
  WriteLn('--- SetRFFFont No Font Loaded ---');

  RIP.SetRFFFont(1);
  Check('SetRFFFont slot 1 (empty): no crash', True);

  // DrawTextRFF should gracefully exit with no font
  RIP.DrawTextRFF(100, 100, 'Hello', 16, 0);
  Check('DrawTextRFF no font: no crash', True);
End;

Procedure TestSetRFFFaceRange;
Begin
  WriteLn;
  WriteLn('--- SetRFFFace Range ---');

  RIP.SetRFFFace(0);
  Check('Face 0 (Regular): OK', RIP.GetRFFFace = 0);

  RIP.SetRFFFace(9);
  Check('Face 9 (HollowExtra): OK', RIP.GetRFFFace = 9);

  RIP.SetRFFFace(10);
  Check('Face 10 (out of range): clamps to 0', RIP.GetRFFFace = 0);

  RIP.SetRFFFace(255);
  Check('Face 255: clamps to 0', RIP.GetRFFFace = 0);
End;

Procedure TestRFFTextWidthNoFont;
Var W : Integer;
Begin
  WriteLn;
  WriteLn('--- RFFTextWidth No Font ---');

  RIP.SetRFFFont(1);  // empty slot
  W := RIP.RFFTextWidth('Hello');
  Check('RFFTextWidth no font: returns 0', W = 0);
End;

Procedure TestDrawTextRFFEmptyString;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFF Empty String ---');

  RIP.DrawTextRFF(0, 0, '', 16, 0);
  Check('DrawTextRFF empty string: no crash', True);
End;

Procedure TestDrawTextRFFZeroPointSize;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFF Zero/Negative Point Size ---');

  RIP.DrawTextRFF(0, 0, 'X', 0, 0);
  Check('DrawTextRFF pointsize=0: no crash (defaults to 16)', True);

  RIP.DrawTextRFF(0, 0, 'X', -5, 0);
  Check('DrawTextRFF pointsize=-5: no crash', True);
End;

Procedure TestDrawTextRFFAllRotations;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFF All Rotations ---');

  RIP.ClearScreen;
  RIP.DrawTextRFF(100, 100, 'Test', 16, 0);
  Check('Rotation 0: no crash', True);

  RIP.DrawTextRFF(100, 100, 'Test', 16, 90);
  Check('Rotation 90: no crash', True);

  RIP.DrawTextRFF(100, 100, 'Test', 16, 180);
  Check('Rotation 180: no crash', True);

  RIP.DrawTextRFF(100, 100, 'Test', 16, 270);
  Check('Rotation 270: no crash', True);

  // Non-standard rotation
  RIP.DrawTextRFF(100, 100, 'Test', 16, 45);
  Check('Rotation 45 (non-standard): no crash', True);
End;

Procedure TestDrawTextRFFLargePointSize;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFF Large Point Size ---');

  RIP.ClearScreen;
  RIP.DrawTextRFF(0, 0, 'X', 500, 0);
  Check('PointSize 500: no crash', True);

  RIP.DrawTextRFF(0, 0, 'X', 10000, 0);
  Check('PointSize 10000: no crash', True);
End;

Procedure TestDrawTextRFFOutOfBounds;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFF Out of Bounds ---');

  RIP.DrawTextRFF(-500, -500, 'Hello World', 24, 0);
  Check('DrawTextRFF at (-500,-500): no crash', True);

  RIP.DrawTextRFF(5000, 5000, 'Hello World', 24, 0);
  Check('DrawTextRFF at (5000,5000): no crash', True);
End;

Procedure TestDrawTextRFFWithRGBMode;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFF RGB Mode ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.SetColor(14);
  RIP.DrawTextRFF(50, 50, 'RGB Test', 20, 0);
  Check('DrawTextRFF in RGB24: no crash', True);

  RIP.SetPixelFormat(RIP_PIXFMT_RGB32);
  RIP.DrawTextRFF(50, 100, 'RGB32 Test', 20, 0);
  Check('DrawTextRFF in RGB32: no crash', True);

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestDrawTextRFFWithWorldCoords;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFF World Coords ---');

  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.DrawTextRFF(50, 50, 'World', 16, 0);
  Check('DrawTextRFF with world coords: no crash', True);
  RIP.ClearWorldCoords;
End;

Procedure TestOutTextXYRFFDispatch;
// When RFF font is active, OutTextXY should dispatch to DrawTextRFF
Begin
  WriteLn;
  WriteLn('--- OutTextXY RFF Dispatch ---');

  // No RFF loaded — should fall back to bitmap
  RIP.SetRFFFont(0);
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.OutTextXY(10, 10, 'Bitmap');
  Check('OutTextXY with RFF=0: uses bitmap (no crash)', True);

  // Set RFF font to an empty slot — should still not crash
  RIP.SetRFFFont(1);
  RIP.OutTextXY(10, 30, 'Empty RFF');
  Check('OutTextXY with empty RFF slot: no crash', True);

  RIP.SetRFFFont(0);
End;

Procedure TestMultipleLoadFree;
// Load and free same slot multiple times
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- Multiple Load/Free Cycles ---');

  For I := 1 to 20 Do Begin
    RIP.LoadRFF(1, '/tmp/nonexistent.rff');
    RIP.FreeRFF(1);
  End;
  Check('20 load/free cycles (nonexistent): no crash/leak', True);
End;

Procedure TestAllSlotsUsed;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- All 8 Slots ---');

  For I := 1 to 8 Do
    RIP.LoadRFF(I, '/tmp/nonexistent.rff');
  Check('Load all 8 slots: no crash', True);

  For I := 1 to 8 Do
    RIP.FreeRFF(I);
  Check('Free all 8 slots: no crash', True);
End;

Procedure TestLongString;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFF Long String ---');

  RIP.DrawTextRFF(0, 0, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz', 12, 0);
  Check('62-char string: no crash', True);
End;

// ---- Font Metrics Tests ----

Procedure TestTracking;
Var W1, W2 : Integer;
Begin
  WriteLn;
  WriteLn('--- Tracking ---');

  RIP.SetRFFTracking(0);
  Check('Default tracking = 0', RIP.GetRFFTracking = 0);

  RIP.SetRFFTracking(500);
  Check('SetRFFTracking(500)', RIP.GetRFFTracking = 500);

  RIP.SetRFFTracking(-200);
  Check('SetRFFTracking(-200)', RIP.GetRFFTracking = -200);

  // Tracking affects DrawTextRFF without crash
  RIP.SetRFFTracking(1000);
  RIP.DrawTextRFF(0, 0, 'Test', 16, 0);
  Check('DrawTextRFF with tracking=1000: no crash', True);

  RIP.SetRFFTracking(-5000);
  RIP.DrawTextRFF(0, 0, 'Test', 16, 0);
  Check('DrawTextRFF with tracking=-5000: no crash', True);

  RIP.SetRFFTracking(0);
End;

Procedure TestLeading;
Begin
  WriteLn;
  WriteLn('--- Leading ---');

  RIP.SetRFFLeading(0);
  Check('Default leading = 0', RIP.GetRFFLeading = 0);

  RIP.SetRFFLeading(1000);
  Check('SetRFFLeading(1000)', RIP.GetRFFLeading = 1000);

  RIP.SetRFFLeading(-500);
  Check('SetRFFLeading(-500)', RIP.GetRFFLeading = -500);

  RIP.SetRFFLeading(0);
End;

Procedure TestKernPair;
Var K : SmallInt;
Begin
  WriteLn;
  WriteLn('--- Kerning ---');

  K := RIP.RFFKernPair('A', 'V');
  Check('KernPair A+V: negative (tighten)', K < 0);

  K := RIP.RFFKernPair('T', 'o');
  Check('KernPair T+o: negative', K < 0);

  K := RIP.RFFKernPair('X', 'X');
  Check('KernPair X+X: zero (no special pair)', K = 0);

  K := RIP.RFFKernPair('a', 'b');
  Check('KernPair a+b: zero', K = 0);

  K := RIP.RFFKernPair('V', '.');
  Check('KernPair V+period: negative', K < 0);

  K := RIP.RFFKernPair('Y', ',');
  Check('KernPair Y+comma: negative', K < 0);
End;

Procedure TestTextHeight;
Var H : Integer;
Begin
  WriteLn;
  WriteLn('--- Text/Line Height ---');

  H := RIP.RFFTextHeight;
  Check('RFFTextHeight >= 0 (no font = 0)', H >= 0);

  H := RIP.RFFLineHeight;
  Check('RFFLineHeight >= 0', H >= 0);

  // With leading
  RIP.SetRFFLeading(500);
  H := RIP.RFFLineHeight;
  Check('LineHeight with leading: >= TextHeight', H >= RIP.RFFTextHeight);
  RIP.SetRFFLeading(0);
End;

Procedure TestMetricsWithNoFont;
Begin
  WriteLn;
  WriteLn('--- Metrics With No Font ---');

  RIP.SetRFFFont(0);
  Check('TextWidth no font: 0', RIP.RFFTextWidth('Hello') = 0);
  Check('TextHeight no font: 0', RIP.RFFTextHeight = 0);
  Check('LineHeight no font: 0', RIP.RFFLineHeight = 0);
End;

// ---- Text Layout Tests ----

Procedure TestDrawTextRFFBoxNoFont;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFFBox No Font ---');

  RIP.SetRFFFont(0);
  RIP.DrawTextRFFBox(10, 10, 200, 100, 'Hello World', 16, 0, 2, True);
  Check('DrawTextRFFBox no font: no crash', True);
End;

Procedure TestDrawTextRFFBoxEmpty;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFFBox Empty ---');

  RIP.DrawTextRFFBox(10, 10, 200, 100, '', 16, 0, 2, True);
  Check('DrawTextRFFBox empty string: no crash', True);
End;

Procedure TestDrawTextRFFBoxAlignments;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFFBox Alignments ---');

  RIP.ClearScreen;

  // Left/Top
  RIP.DrawTextRFFBox(10, 10, 300, 200, 'Left Top', 16, 0, 2, False);
  Check('Left/Top: no crash', True);

  // Center/Center
  RIP.DrawTextRFFBox(10, 10, 300, 200, 'Center', 16, 1, 1, False);
  Check('Center/Center: no crash', True);

  // Right/Bottom
  RIP.DrawTextRFFBox(10, 10, 300, 200, 'Right Bottom', 16, 2, 0, False);
  Check('Right/Bottom: no crash', True);
End;

Procedure TestDrawTextRFFBoxWordWrap;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFFBox Word Wrap ---');

  RIP.ClearScreen;
  RIP.DrawTextRFFBox(10, 10, 100, 300,
    'The quick brown fox jumps over the lazy dog', 12, 0, 2, True);
  Check('Word wrap long text: no crash', True);

  // Single word longer than box
  RIP.DrawTextRFFBox(10, 10, 20, 100,
    'Supercalifragilisticexpialidocious', 12, 0, 2, True);
  Check('Word longer than box: no crash', True);
End;

Procedure TestDrawTextRFFBoxNoWrap;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFFBox No Wrap ---');

  RIP.ClearScreen;
  RIP.DrawTextRFFBox(10, 10, 100, 50, 'This text overflows the box', 16, 0, 2, False);
  Check('No wrap overflow: no crash', True);
End;

Procedure TestDrawTextRFFBoxZeroSize;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFFBox Zero/Negative Size ---');

  RIP.DrawTextRFFBox(10, 10, 0, 0, 'Test', 16, 0, 2, True);
  Check('Zero box size: no crash', True);

  RIP.DrawTextRFFBox(10, 10, -50, -50, 'Test', 16, 0, 2, True);
  Check('Negative box size: no crash', True);
End;

Procedure TestDrawTextRFFBoxRGBMode;
Begin
  WriteLn;
  WriteLn('--- DrawTextRFFBox RGB Mode ---');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.DrawTextRFFBox(10, 10, 300, 200, 'RGB text layout', 20, 1, 1, False);
  Check('DrawTextRFFBox in RGB24: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

// ---- CP437 / UTF-8 Tests ----

Procedure TestUTF8ToCP437;
Begin
  WriteLn;
  WriteLn('--- UTF8ToCP437 ---');

  // ASCII passes through
  Check('A -> 65', RIP.UTF8ToCP437(65) = 65);
  Check('space -> 32', RIP.UTF8ToCP437(32) = 32);
  Check('0 -> 0', RIP.UTF8ToCP437(0) = 0);
  Check('127 -> 127', RIP.UTF8ToCP437(127) = 127);

  // International chars
  Check('U+00C7 (Ç) -> 128', RIP.UTF8ToCP437($00C7) = 128);
  Check('U+00FC (ü) -> 129', RIP.UTF8ToCP437($00FC) = 129);
  Check('U+00E9 (é) -> 130', RIP.UTF8ToCP437($00E9) = 130);
  Check('U+00F1 (ñ) -> 164', RIP.UTF8ToCP437($00F1) = 164);

  // Box drawing
  Check('U+2502 (│) -> 179', RIP.UTF8ToCP437($2502) = 179);
  Check('U+2550 (═) -> 205', RIP.UTF8ToCP437($2550) = 205);
  Check('U+2588 (█) -> 219', RIP.UTF8ToCP437($2588) = 219);

  // Math/Greek
  Check('U+03C0 (π) -> 227', RIP.UTF8ToCP437($03C0) = 227);
  Check('U+221E (∞) -> 236', RIP.UTF8ToCP437($221E) = 236);
  Check('U+00B0 (°) -> 248', RIP.UTF8ToCP437($00B0) = 248);

  // Control code glyphs
  Check('U+263A (☺) -> 1', RIP.UTF8ToCP437($263A) = 1);
  Check('U+2665 (♥) -> 3', RIP.UTF8ToCP437($2665) = 3);
  Check('U+266A (♪) -> 13', RIP.UTF8ToCP437($266A) = 13);

  // Unmapped -> ?
  Check('U+4E2D (中) -> ?', RIP.UTF8ToCP437($4E2D) = Ord('?'));
End;

Procedure TestMapStringCP437;
Var S : String;
Begin
  WriteLn;
  WriteLn('--- MapStringCP437 ---');

  // Pure ASCII
  S := RIP.MapStringCP437('Hello');
  Check('ASCII passthrough', S = 'Hello');

  // Empty string
  S := RIP.MapStringCP437('');
  Check('Empty string', S = '');

  // Raw high byte (not valid UTF-8 lead) -> ?
  S := RIP.MapStringCP437(Chr(128));
  Check('Raw byte 128 (invalid UTF-8): becomes ?', S = '?');

  // Invalid UTF-8
  S := RIP.MapStringCP437(Chr($FF) + Chr($FE));
  Check('Invalid UTF-8: becomes ?', S = '??');

  // Truncated sequence
  S := RIP.MapStringCP437(Chr($C3));
  Check('Truncated 2-byte: becomes ?', S = '?');
End;

// ---- MAF Bitmap Font Tests ----

Procedure TestMAFLoadNonexistent;
Var OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- LoadMAF Nonexistent ---');
  OK := RIP.LoadMAF('/tmp/nonexistent.maf');
  Check('LoadMAF nonexistent: returns false', Not OK);
End;

Procedure TestMAFFreeEmpty;
Begin
  WriteLn;
  WriteLn('--- FreeMAF Empty ---');
  RIP.FreeMAF;
  Check('FreeMAF when not loaded: no crash', True);
  RIP.FreeMAF;
  Check('FreeMAF twice: no crash', True);
End;

Procedure TestMAFSelectResNoLoad;
Begin
  WriteLn;
  WriteLn('--- MAFSelectRes No Load ---');
  Check('MAFSelectRes no MAF: false', Not RIP.MAFSelectRes(640, 480));
End;

Procedure TestMAFSelectFontNoLoad;
Begin
  WriteLn;
  WriteLn('--- MAFSelectFont No Load ---');
  Check('MAFSelectFont no MAF: false', Not RIP.MAFSelectFont(0));
End;

Procedure TestMAFGetFontHNoLoad;
Begin
  WriteLn;
  WriteLn('--- MAFGetFontH No Load ---');
  Check('MAFGetFontH no MAF: 0', RIP.MAFGetFontH = 0);
End;

Procedure TestMAFIsLoaded;
Begin
  WriteLn;
  WriteLn('--- MAFIsLoaded ---');
  Check('MAFIsLoaded no MAF: false', Not RIP.MAFIsLoaded);
End;

Procedure TestDrawTextMAFNoFont;
Begin
  WriteLn;
  WriteLn('--- DrawTextMAF No Font ---');
  RIP.DrawTextMAF(10, 10, 'Hello');
  Check('DrawTextMAF no MAF loaded: no crash', True);
End;

Procedure TestDrawTextMAFEmpty;
Begin
  WriteLn;
  WriteLn('--- DrawTextMAF Empty ---');
  RIP.DrawTextMAF(10, 10, '');
  Check('DrawTextMAF empty string: no crash', True);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 18: Scalable Font Rendering — STRESS TESTS ===');

  RIP := TRIPEngine.Create;

  TestLoadRFFNonexistent;
  TestLoadRFFBadSlot;
  TestFreeRFFEmpty;
  TestSetRFFFontNoFont;
  TestSetRFFFaceRange;
  TestRFFTextWidthNoFont;
  TestDrawTextRFFEmptyString;
  TestDrawTextRFFZeroPointSize;
  TestDrawTextRFFAllRotations;
  TestDrawTextRFFLargePointSize;
  TestDrawTextRFFOutOfBounds;
  TestDrawTextRFFWithRGBMode;
  TestDrawTextRFFWithWorldCoords;
  TestOutTextXYRFFDispatch;
  TestMultipleLoadFree;
  TestAllSlotsUsed;
  TestLongString;
  TestTracking;
  TestLeading;
  TestKernPair;
  TestTextHeight;
  TestMetricsWithNoFont;
  TestDrawTextRFFBoxNoFont;
  TestDrawTextRFFBoxEmpty;
  TestDrawTextRFFBoxAlignments;
  TestDrawTextRFFBoxWordWrap;
  TestDrawTextRFFBoxNoWrap;
  TestDrawTextRFFBoxZeroSize;
  TestDrawTextRFFBoxRGBMode;
  TestUTF8ToCP437;
  TestMapStringCP437;
  TestMAFLoadNonexistent;
  TestMAFFreeEmpty;
  TestMAFSelectResNoLoad;
  TestMAFSelectFontNoLoad;
  TestMAFGetFontHNoLoad;
  TestMAFIsLoaded;
  TestDrawTextMAFNoFont;
  TestDrawTextMAFEmpty;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
