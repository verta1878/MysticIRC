{$MODE DELPHI}
{$H-}
Unit RIPBMP;
{
  RIPView BMP Output - write canvas to BMP file.

  TWO MODES controlled by the BMP_8BIT define (-dBMP_8BIT on command line):

    BMP_8BIT defined:
      8-bit indexed color with 16-entry palette (672KB for 640x350)
      Matches reference PNGs. Used for Phase 3 pixel comparison.
      RIP v1.54 is 16-color EGA - 8-bit is the correct format.

    BMP_8BIT not defined (default):
      24-bit uncompressed RGB (2.4MB for 640x350)
      Full color for future RIP v2/v3 browser and high-color work.

  PALETTE FORMAT:
    Our EGA palette stores colors as $BBGGRR LongWords.
    8-bit BMP palette entries are 4 bytes: Blue, Green, Red, Reserved.
    24-bit BMP pixels are 3 bytes: Blue, Green, Red (BGR).

  BUG FIX (Session 6):
    Original 24-bit writer had Red and Blue bytes SWAPPED (RGB not BGR).
    Fixed: both writers now output correct BGR byte order.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses RIPEngine;

Procedure WriteBMP(const FileName: String);

Implementation

{$IFDEF BMP_8BIT}
{ ====================================================================
  8-BIT INDEXED BMP WRITER
  ====================================================================
  Palette: 16 EGA colors stored as 4-byte BGRA entries (256 total,
  but only 16 used - rest are black). Each pixel is one byte (0-15).
  Row padding to 4-byte boundary. Matches reference PNG format.

  File structure:
    14 bytes  BMP header
    40 bytes  DIB header (BITMAPINFOHEADER)
    1024 bytes palette (256 entries x 4 bytes BGRA)
    pixel data (1 byte per pixel, padded rows, bottom-up)
  ==================================================================== }
Procedure WriteBMP(const FileName: String);
Var
  F : File;
  X, Y, I : Integer;
  Row     : Array[0..1023] Of Byte;   { one scanline: up to 1024 pixels }
  Pad     : Array[0..3] Of Byte;      { zero bytes for row padding      }
  Hdr     : Array[0..53] Of Byte;     { BMP + DIB header (54 bytes)     }
  PalBuf  : Array[0..1023] Of Byte;   { 256 palette entries x 4 bytes   }
  PadSize : Integer;                   { bytes to pad each row           }
  FileSize, DataOffset, DataSize: LongInt;
  W, H    : LongInt;
  Color   : LongWord;
Begin
  W := RIP_WIDTH;
  H := RIP_HEIGHT;

  { Row padding - each row must be a multiple of 4 bytes.
    At 1 byte/pixel, 640 mod 4 = 0, so PadSize = 0 for standard RIP. }
  PadSize := (4 - (W Mod 4)) Mod 4;

  { Pixel data follows header (54) + palette (256 * 4 = 1024) }
  DataOffset := 54 + 1024;
  DataSize := (W + PadSize) * H;
  FileSize := DataOffset + DataSize;
  FillChar(Pad, SizeOf(Pad), 0);

  Assign(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  { ================================================================
    BMP + DIB Header (54 bytes)
    Bits per pixel = 8, compression = 0 (BI_RGB)
    ================================================================ }
  FillChar(Hdr, 54, 0);
  Hdr[0] := Ord('B'); Hdr[1] := Ord('M');   { BMP signature }
  Move(FileSize, Hdr[2], 4);                 { total file size }
  Move(DataOffset, Hdr[10], 4);              { offset to pixel data }
  Hdr[14] := 40;                             { DIB header size }
  Move(W, Hdr[18], 4);                       { width }
  Move(H, Hdr[22], 4);                       { height (positive = bottom-up) }
  Hdr[26] := 1;                              { color planes }
  Hdr[28] := 8;                              { bits per pixel - 8-bit indexed }
  Move(DataSize, Hdr[34], 4);                { image data size }
  I := 256;                                  { colors used }
  Move(I, Hdr[46], 4);                       { biClrUsed }
  Move(I, Hdr[50], 4);                       { biClrImportant }
  BlockWrite(F, Hdr, 54);

  { ================================================================
    Color Palette (1024 bytes = 256 entries x 4 bytes)
    Each entry: Blue, Green, Red, Reserved (BGRA)
    Only 16 EGA colors used, rest are black (zeroed).

    Our palette stores $BBGGRR:
      Color And $FF         = Red
      (Color Shr 8) And $FF = Green
      (Color Shr 16) And $FF = Blue

    BMP palette byte order: Blue, Green, Red, 0
    ================================================================ }
  FillChar(PalBuf, SizeOf(PalBuf), 0);
  For I := 0 to 15 Do Begin
    Color := Canvas.Palette[I];
    PalBuf[I * 4]     := (Color Shr 16) And $FF;  { Blue }
    PalBuf[I * 4 + 1] := (Color Shr 8) And $FF;   { Green }
    PalBuf[I * 4 + 2] := Color And $FF;            { Red }
    PalBuf[I * 4 + 3] := 0;                        { Reserved }
  End;
  BlockWrite(F, PalBuf, 1024);

  { ================================================================
    Pixel Data - bottom-up, 1 byte per pixel (palette index 0-15)
    ================================================================ }
  For Y := H - 1 DownTo 0 Do Begin
    For X := 0 To W - 1 Do
      Row[X] := Canvas.Pixels^[X, Y] And 15;  { clamp to 0-15 }
    BlockWrite(F, Row, W);
    If PadSize > 0 Then BlockWrite(F, Pad, PadSize);
  End;

  Close(F);
End;

{$ELSE}
{ ====================================================================
  24-BIT UNCOMPRESSED BMP WRITER (default)
  ====================================================================
  Full color, no palette table. Each pixel = 3 bytes BGR.
  Used for future RIP v2/v3 browser and high-color rendering.

  File structure:
    14 bytes  BMP header
    40 bytes  DIB header
    pixel data (3 bytes per pixel BGR, padded rows, bottom-up)
  ==================================================================== }
Procedure WriteBMP(const FileName: String);
Var
  F : File;
  X, Y : Integer;
  Row  : Array[0..RIP_WIDTH-1, 0..2] Of Byte;  { one scanline BGR triples }
  Pad  : Array[0..3] Of Byte;
  Hdr  : Array[0..53] Of Byte;
  PadSize : Integer;
  FileSize, DataOffset, DataSize: LongInt;
  W, H : LongInt;
  Color: LongWord;
Begin
  W := RIP_WIDTH;
  H := RIP_HEIGHT;

  { Row padding - 640 * 3 = 1920, 1920 mod 4 = 0, PadSize = 0 }
  PadSize := (4 - ((W * 3) Mod 4)) Mod 4;
  DataSize := (W * 3 + PadSize) * H;
  DataOffset := 54;
  FileSize := DataOffset + DataSize;
  FillChar(Pad, SizeOf(Pad), 0);

  Assign(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  { BMP + DIB Header - 24-bit, no palette }
  FillChar(Hdr, 54, 0);
  Hdr[0] := Ord('B'); Hdr[1] := Ord('M');
  Move(FileSize, Hdr[2], 4);
  Move(DataOffset, Hdr[10], 4);
  Hdr[14] := 40;
  Move(W, Hdr[18], 4);
  Move(H, Hdr[22], 4);
  Hdr[26] := 1;
  Hdr[28] := 24;                              { 24-bit - full color }
  Move(DataSize, Hdr[34], 4);
  BlockWrite(F, Hdr, 54);

  { Pixel Data - bottom-up, BGR byte order.
    Palette format $BBGGRR: Shr 16 = Blue, Shr 8 = Green, And $FF = Red }
  For Y := H - 1 DownTo 0 Do Begin
    For X := 0 To W - 1 Do Begin
      Color := Canvas.Palette[Canvas.Pixels^[X, Y]];
      Row[X, 0] := (Color SHR 16) And $FF;  { Blue }
      Row[X, 1] := (Color SHR 8) And $FF;   { Green }
      Row[X, 2] := Color And $FF;            { Red }
    End;
    BlockWrite(F, Row, W * 3);
    If PadSize > 0 Then BlockWrite(F, Pad, PadSize);
  End;

  Close(F);
End;
{$ENDIF}

End.
