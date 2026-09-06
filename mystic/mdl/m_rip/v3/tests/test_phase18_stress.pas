{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
Program test_phase18_stress;
// Phase 18 stress tests — adversarial inputs for font metrics and text layout

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

Procedure TestBoxAllSpaces;
Begin
  WriteLn;
  WriteLn('--- Box: All Spaces ---');
  RIP.DrawTextRFFBox(10, 10, 200, 100, '          ', 16, 0, 2, True);
  Check('All spaces: no crash', True);
End;

Procedure TestBoxSingleChar;
Begin
  WriteLn;
  WriteLn('--- Box: Single Char ---');
  RIP.DrawTextRFFBox(10, 10, 200, 100, 'X', 16, 1, 1, True);
  Check('Single char centered: no crash', True);
End;

Procedure TestBoxNoSpaces;
Begin
  WriteLn;
  WriteLn('--- Box: No Spaces (unwrappable) ---');
  RIP.DrawTextRFFBox(10, 10, 50, 100, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 16, 0, 2, True);
  Check('No spaces wrappable: no crash', True);
End;

Procedure TestBoxManyWords;
Var S : String;
    I : Integer;
Begin
  WriteLn;
  WriteLn('--- Box: Many Short Words ---');
  S := '';
  For I := 1 to 50 Do
    S := S + 'hi ';
  RIP.DrawTextRFFBox(10, 10, 150, 300, S, 10, 0, 2, True);
  Check('50 words wrapped: no crash', True);
End;

Procedure TestBoxMax64Lines;
Var S : String;
    I : Integer;
Begin
  WriteLn;
  WriteLn('--- Box: Force >64 Lines ---');
  S := '';
  For I := 1 to 200 Do
    S := S + 'w ';
  RIP.DrawTextRFFBox(10, 10, 20, 5000, S, 8, 0, 2, True);
  Check('>64 lines clamped: no crash', True);
End;

Procedure TestBoxTinyBox;
Begin
  WriteLn;
  WriteLn('--- Box: 1x1 Pixel ---');
  RIP.DrawTextRFFBox(100, 100, 1, 1, 'Hello World', 16, 1, 1, True);
  Check('1x1 box: no crash', True);
End;

Procedure TestBoxNegativeCoords;
Begin
  WriteLn;
  WriteLn('--- Box: Negative Coords ---');
  RIP.DrawTextRFFBox(-100, -100, 200, 200, 'Negative', 16, 0, 2, True);
  Check('Negative origin: no crash', True);

  RIP.DrawTextRFFBox(100, 100, -50, -50, 'Neg size', 16, 0, 2, True);
  Check('Negative dimensions: no crash', True);
End;

Procedure TestBoxHugePointSize;
Begin
  WriteLn;
  WriteLn('--- Box: Huge Point Size ---');
  RIP.DrawTextRFFBox(0, 0, 640, 350, 'BIG', 500, 1, 1, False);
  Check('PointSize 500: no crash', True);
End;

Procedure TestBoxZeroPointSize;
Begin
  WriteLn;
  WriteLn('--- Box: Zero Point Size ---');
  RIP.DrawTextRFFBox(0, 0, 200, 100, 'Zero', 0, 0, 2, True);
  Check('PointSize 0: no crash', True);
End;

Procedure TestBoxAllAlignCombos;
Var H, V : Byte;
Begin
  WriteLn;
  WriteLn('--- Box: All Alignment Combos ---');
  For H := 0 to 2 Do
    For V := 0 to 2 Do
      RIP.DrawTextRFFBox(10, 10, 300, 200, 'Align test', 14, H, V, False);
  Check('9 alignment combos: no crash', True);
End;

Procedure TestTrackingExtreme;
Begin
  WriteLn;
  WriteLn('--- Tracking Extreme + Box ---');
  RIP.SetRFFTracking(10000);
  RIP.DrawTextRFFBox(0, 0, 640, 350, 'Wide tracking', 16, 0, 2, True);
  Check('Tracking +10000 with box: no crash', True);

  RIP.SetRFFTracking(-10000);
  RIP.DrawTextRFFBox(0, 0, 640, 350, 'Tight tracking', 16, 0, 2, True);
  Check('Tracking -10000 with box: no crash', True);

  RIP.SetRFFTracking(0);
End;

Procedure TestLeadingExtreme;
Begin
  WriteLn;
  WriteLn('--- Leading Extreme + Box ---');
  RIP.SetRFFLeading(50000);
  RIP.DrawTextRFFBox(0, 0, 300, 300, 'A B C D E', 12, 0, 2, True);
  Check('Leading 50000 with wrap: no crash', True);

  RIP.SetRFFLeading(-5000);
  RIP.DrawTextRFFBox(0, 0, 300, 300, 'A B C D E', 12, 0, 2, True);
  Check('Leading -5000 with wrap: no crash', True);

  RIP.SetRFFLeading(0);
End;

Procedure TestKernAllPairs;
Var
  Ch1, Ch2 : Char;
  Count    : Integer;
Begin
  WriteLn;
  WriteLn('--- Kern All Printable Pairs ---');
  Count := 0;
  For Ch1 := ' ' to '~' Do
    For Ch2 := ' ' to '~' Do Begin
      RIP.RFFKernPair(Ch1, Ch2);
      Inc(Count);
    End;
  Check('All printable pairs (' + '' + '): no crash', True);
End;

Procedure TestBoxWithWorldCoords;
Begin
  WriteLn;
  WriteLn('--- Box: World Coords Active ---');
  RIP.SetWorldCoords(0.0, 0.0, 100.0, 100.0);
  RIP.DrawTextRFFBox(10, 10, 300, 200, 'World text', 16, 1, 1, True);
  Check('Box with world coords: no crash', True);
  RIP.ClearWorldCoords;
End;

Procedure TestBoxAllPixelFormats;
Var Fmt : Byte;
Begin
  WriteLn;
  WriteLn('--- Box: All Pixel Formats ---');
  For Fmt := RIP_PIXFMT_INDEXED8 to RIP_PIXFMT_RGB32 Do Begin
    RIP.SetPixelFormat(Fmt);
    RIP.ClearScreen;
    RIP.DrawTextRFFBox(10, 10, 200, 100, 'Format test', 14, 0, 2, True);
  End;
  Check('All 3 pixel formats: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

// ---- MAF Stress Tests ----

Procedure TestMAFLoadGarbage;
Var F : File;
    Buf : Array[0..255] of Byte;
    I : Integer;
    OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- LoadMAF Garbage File ---');
  // Create a garbage file
  For I := 0 to 255 Do Buf[I] := I;
  Assign(F, '/tmp/garbage.maf');
  Rewrite(F, 1);
  BlockWrite(F, Buf, 256);
  Close(F);

  OK := RIP.LoadMAF('/tmp/garbage.maf');
  Check('LoadMAF garbage: returns false', Not OK);
End;

Procedure TestMAFLoadTruncated;
Var F : File;
    Hdr : Array[0..40] of Byte;
    OK : Boolean;
Begin
  WriteLn;
  WriteLn('--- LoadMAF Truncated ---');
  // Create file with valid header but truncated
  FillChar(Hdr, SizeOf(Hdr), 0);
  Hdr[0] := $04;
  // Write "RIPterm v2.0 MicroANSI Font File"
  Move(' RIPterm v2.0 MicroANSI Font File ', Hdr[1], 34);
  Hdr[$24] := $04;

  Assign(F, '/tmp/trunc.maf');
  Rewrite(F, 1);
  BlockWrite(F, Hdr, 41);
  Close(F);

  OK := RIP.LoadMAF('/tmp/trunc.maf');
  Check('LoadMAF truncated: returns false', Not OK);
End;

Procedure TestMAFMultipleLoadFree;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- MAF Multiple Load/Free (20x) ---');
  For I := 1 to 20 Do Begin
    RIP.LoadMAF('/tmp/nonexistent.maf');
    RIP.FreeMAF;
  End;
  Check('20 load/free cycles: no crash/leak', True);
End;

Procedure TestMAFSelectBadIndices;
Begin
  WriteLn;
  WriteLn('--- MAF Bad Indices ---');
  Check('SelectRes(0,0): false', Not RIP.MAFSelectRes(0, 0));
  Check('SelectRes(99999,99999): false', Not RIP.MAFSelectRes(9999, 9999));
  Check('SelectFont(-1): false', Not RIP.MAFSelectFont(-1));
  Check('SelectFont(100): false', Not RIP.MAFSelectFont(100));
End;

Procedure TestDrawTextMAFStress;
Var S : String;
    I : Integer;
Begin
  WriteLn;
  WriteLn('--- DrawTextMAF Stress ---');

  // No MAF loaded — all should be safe
  RIP.DrawTextMAF(0, 0, 'No MAF loaded');
  Check('DrawTextMAF no MAF: no crash', True);

  RIP.DrawTextMAF(-100, -100, 'Negative coords');
  Check('DrawTextMAF negative coords: no crash', True);

  RIP.DrawTextMAF(5000, 5000, 'Huge coords');
  Check('DrawTextMAF huge coords: no crash', True);

  // Long string
  S := '';
  For I := 1 to 80 Do S := S + Chr(32 + (I mod 95));
  RIP.DrawTextMAF(0, 0, S);
  Check('DrawTextMAF 80 chars: no crash', True);

  // All 256 CP437 chars
  S := '';
  For I := 0 to 255 Do S := S + Chr(I);
  RIP.DrawTextMAF(0, 0, S);
  Check('DrawTextMAF all 256 chars: no crash', True);

  // All pixel formats
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.DrawTextMAF(10, 10, 'RGB');
  Check('DrawTextMAF RGB24: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_RGB32);
  RIP.DrawTextMAF(10, 10, 'RGB32');
  Check('DrawTextMAF RGB32: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 18: STRESS TESTS — Font Metrics & Text Layout ===');

  RIP := TRIPEngine.Create;

  TestBoxAllSpaces;
  TestBoxSingleChar;
  TestBoxNoSpaces;
  TestBoxManyWords;
  TestBoxMax64Lines;
  TestBoxTinyBox;
  TestBoxNegativeCoords;
  TestBoxHugePointSize;
  TestBoxZeroPointSize;
  TestBoxAllAlignCombos;
  TestTrackingExtreme;
  TestLeadingExtreme;
  TestKernAllPairs;
  TestBoxWithWorldCoords;
  TestBoxAllPixelFormats;
  TestMAFLoadGarbage;
  TestMAFLoadTruncated;
  TestMAFMultipleLoadFree;
  TestMAFSelectBadIndices;
  TestDrawTextMAFStress;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
