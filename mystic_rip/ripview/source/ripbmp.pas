{$MODE DELPHI}
{$H-}
Unit RIPBMP;
{
  RIPView BMP Output — write canvas to 24-bit BMP file.
  Shared across all RIPscrip versions.

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses RIPEngine;

Procedure WriteBMP(const FileName: String);

Implementation

Procedure WriteBMP(const FileName: String);
Var
  F : File;
  X, Y : Integer;
  Row  : Array[0..RIP_WIDTH-1, 0..2] Of Byte;
  Pad  : Array[0..3] Of Byte;
  Hdr  : Array[0..53] Of Byte;
  PadSize : Integer;
  FileSize, DataOffset, DataSize: LongInt;
  W, H : LongInt;
  Color: LongWord;
Begin
  W := RIP_WIDTH;
  H := RIP_HEIGHT;
  PadSize := (4 - ((W * 3) Mod 4)) Mod 4;
  DataSize := (W * 3 + PadSize) * H;
  DataOffset := 54;
  FileSize := DataOffset + DataSize;
  FillChar(Pad, SizeOf(Pad), 0);

  Assign(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  FillChar(Hdr, 54, 0);
  Hdr[0] := Ord('B'); Hdr[1] := Ord('M');
  Move(FileSize, Hdr[2], 4);
  Move(DataOffset, Hdr[10], 4);
  Hdr[14] := 40;
  Move(W, Hdr[18], 4);
  Move(H, Hdr[22], 4);
  Hdr[26] := 1;
  Hdr[28] := 24;
  Move(DataSize, Hdr[34], 4);
  BlockWrite(F, Hdr, 54);

  For Y := H - 1 DownTo 0 Do Begin
    For X := 0 To W - 1 Do Begin
      Color := Canvas.Palette[Canvas.Pixels^[X, Y]];
      Row[X, 0] := Color And $FF;
      Row[X, 1] := (Color SHR 8) And $FF;
      Row[X, 2] := (Color SHR 16) And $FF;
    End;
    BlockWrite(F, Row, W * 3);
    If PadSize > 0 Then BlockWrite(F, Pad, PadSize);
  End;

  Close(F);
End;

End.
