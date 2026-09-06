{$MODE DELPHI}
{$H-}
Program BMPCompare;
{
  BMP Pixel Comparator — Phase 3 verification tool

  Compares two BMP files byte by byte. Both files must be the
  same size (same dimensions, same bit depth). Returns:
    Exit code 0 = PASS (identical)
    Exit code 1 = FAIL (different)
    Exit code 2 = ERROR (can't open file, wrong args)

  WHY THIS EXISTS:
    We have two RIP rendering engines (ripdraw and m_rip_graph).
    Both render the same .rip file to BMP. If the BMPs are
    byte-identical, the engines produce the same pixels.
    No ImageMagick needed — pure Pascal, no dependencies.

  USAGE:
    bmpcompare file1.bmp file2.bmp

  IMPORTANT:
    Both BMPs must be the same format (same bit depth, same
    dimensions). If Engine A writes 24-bit and Engine B writes
    8-bit, the files will be different sizes and this tool will
    report a size mismatch — that's NOT a rendering bug, it's
    a format mismatch. Fix the BMP writers to match first.

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Var
  F1, F2  : File;     { two BMP files to compare               }
  B1, B2  : Byte;     { one byte from each file                 }
  Pos     : LongInt;  { current byte position                   }
  Diff    : LongInt;  { count of bytes that differ              }
  Size1   : LongInt;  { file size of first BMP                  }
  Size2   : LongInt;  { file size of second BMP                 }
  Read1   : LongInt;  { bytes actually read from file 1         }
  Read2   : LongInt;  { bytes actually read from file 2         }

Begin
  { ================================================================
    Argument check — need exactly 2 file paths
    ================================================================ }
  If ParamCount < 2 Then Begin
    WriteLn('BMP Pixel Comparator — Phase 3 verification tool');
    WriteLn('Usage: bmpcompare file1.bmp file2.bmp');
    WriteLn;
    WriteLn('Compares two BMP files byte by byte.');
    WriteLn('Exit 0 = identical, 1 = different, 2 = error.');
    Halt(2);
  End;

  { ================================================================
    Open both files in binary mode (record size = 1 byte)
    ================================================================ }
  Assign(F1, ParamStr(1));
  {$I-} Reset(F1, 1); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('ERROR: Cannot open: ', ParamStr(1));
    Halt(2);
  End;

  Assign(F2, ParamStr(2));
  {$I-} Reset(F2, 1); {$I+}
  If IOResult <> 0 Then Begin
    Close(F1);
    WriteLn('ERROR: Cannot open: ', ParamStr(2));
    Halt(2);
  End;

  { ================================================================
    Size check — different sizes means different format or dimensions.
    This catches the 24-bit vs 8-bit BMP mismatch that sysop/0 found
    in the first test run (Engine A = 2.4MB, Engine B = 672KB).
    ================================================================ }
  Size1 := FileSize(F1);
  Size2 := FileSize(F2);

  If Size1 <> Size2 Then Begin
    WriteLn('FAIL — size mismatch: ', Size1, ' vs ', Size2, ' bytes');
    WriteLn('       This usually means different BMP bit depths.');
    WriteLn('       Both engines must output the same format.');
    Close(F1); Close(F2);
    Halt(1);
  End;

  { ================================================================
    Byte-by-byte comparison
    Walk both files simultaneously, count differing bytes.
    This compares EVERYTHING — header + pixel data. If only the
    header differs, the count will be small (< 54 bytes). If
    pixels differ, the count will be large.
    ================================================================ }
  Diff := 0;
  Pos := 0;

  While Pos < Size1 Do Begin
    BlockRead(F1, B1, 1, Read1);
    BlockRead(F2, B2, 1, Read2);
    If (Read1 = 0) Or (Read2 = 0) Then Break;  { unexpected EOF }
    If B1 <> B2 Then Inc(Diff);
    Inc(Pos);
  End;

  Close(F1);
  Close(F2);

  { ================================================================
    Report results
    ================================================================ }
  If Diff = 0 Then Begin
    WriteLn('PASS — pixel-perfect match (', Size1, ' bytes)');
    Halt(0);
  End Else Begin
    WriteLn('FAIL — ', Diff, ' bytes differ out of ', Size1);
    Halt(1);
  End;
End.
