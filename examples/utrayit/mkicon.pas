{$MODE OBJFPC}{$H+}
Program MkIcon;
{
  MkIcon — Generate .ICO files for console applications.
  Pure Pascal, no external dependencies.

  Usage: mkicon <output.ico> [style]
    style: dos    Green >_ prompt on black (default)
           mystic Blue M on blue background
           custom <r> <g> <b>  Custom color on black

  Copyright (C) 2025-2026 IRC Fork: verta1878, sysop/0, evga, kiddo, wrench
  GPLv3
}

Uses SysUtils;

Type
  TPixel = Record R, G, B, A: Byte; End;

Const
  ICON_SIZE = 32;

Var
  Pixels: Array[0..ICON_SIZE-1, 0..ICON_SIZE-1] of TPixel;

Procedure SetPixel(X, Y: Integer; R, G, B: Byte);
Begin
  If (X >= 0) And (X < ICON_SIZE) And (Y >= 0) And (Y < ICON_SIZE) Then Begin
    Pixels[Y, X].R := R;
    Pixels[Y, X].G := G;
    Pixels[Y, X].B := B;
    Pixels[Y, X].A := 255;
  End;
End;

Procedure FillRect(X1, Y1, X2, Y2: Integer; R, G, B: Byte);
Var X, Y: Integer;
Begin
  For Y := Y1 to Y2 Do
    For X := X1 to X2 Do
      SetPixel(X, Y, R, G, B);
End;

Procedure DrawDOS;
{ Green >_ prompt on black background }
Var M: Integer;
Begin
  FillRect(0, 0, 31, 31, 0, 0, 0);       { black background }
  FillRect(0, 0, 31, 0, 0, 170, 0);      { green border top }
  FillRect(0, 31, 31, 31, 0, 170, 0);    { green border bottom }
  FillRect(0, 0, 0, 31, 0, 170, 0);      { green border left }
  FillRect(31, 0, 31, 31, 0, 170, 0);    { green border right }

  M := 4;
  { > character }
  FillRect(M, 10, M+1, 11, 0, 255, 0);
  FillRect(M+2, 12, M+3, 13, 0, 255, 0);
  FillRect(M+4, 14, M+5, 15, 0, 255, 0);
  FillRect(M+4, 16, M+5, 17, 0, 255, 0);
  FillRect(M+2, 18, M+3, 19, 0, 255, 0);
  FillRect(M, 20, M+1, 21, 0, 255, 0);

  { _ cursor }
  FillRect(M+8, 20, M+16, 21, 0, 255, 0);
End;

Procedure DrawMystic;
{ White M on blue background }
Begin
  FillRect(0, 0, 31, 31, 0, 0, 170);     { blue background }
  FillRect(0, 0, 31, 0, 85, 85, 255);    { light blue border }
  FillRect(0, 31, 31, 31, 85, 85, 255);
  FillRect(0, 0, 0, 31, 85, 85, 255);
  FillRect(31, 0, 31, 31, 85, 85, 255);

  { M character }
  FillRect(4, 8, 7, 24, 255, 255, 255);   { left stroke }
  FillRect(24, 8, 27, 24, 255, 255, 255); { right stroke }
  { left diagonal }
  FillRect(8, 9, 9, 10, 255, 255, 255);
  FillRect(10, 11, 11, 12, 255, 255, 255);
  FillRect(12, 13, 13, 14, 255, 255, 255);
  FillRect(14, 15, 15, 16, 255, 255, 255);
  { right diagonal }
  FillRect(22, 9, 23, 10, 255, 255, 255);
  FillRect(20, 11, 21, 12, 255, 255, 255);
  FillRect(18, 13, 19, 14, 255, 255, 255);
  FillRect(16, 15, 17, 16, 255, 255, 255);
End;

Procedure WriteICO(const FileName: String);
Var
  F: File;
  X, Y: Integer;
  ImgSize, Offset: LongInt;
  B: Byte;
Begin
  { ICO format: header (6) + entry (16) + BMP DIB (40) + pixels + mask }
  ImgSize := 40 + (ICON_SIZE * ICON_SIZE * 4) + (ICON_SIZE * 4); { DIB + BGRA + AND mask }
  Offset := 6 + 16;

  Assign(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('ERROR: Cannot create ', FileName);
    Halt(1);
  End;

  { ICO header: reserved(2) + type(2) + count(2) }
  B := 0; BlockWrite(F, B, 1); BlockWrite(F, B, 1);   { reserved = 0 }
  B := 1; BlockWrite(F, B, 1); B := 0; BlockWrite(F, B, 1); { type = 1 (ICO) }
  B := 1; BlockWrite(F, B, 1); B := 0; BlockWrite(F, B, 1); { count = 1 }

  { ICO directory entry (16 bytes) }
  B := ICON_SIZE; BlockWrite(F, B, 1);  { width }
  B := ICON_SIZE; BlockWrite(F, B, 1);  { height }
  B := 0; BlockWrite(F, B, 1);          { color count (0 = true color) }
  B := 0; BlockWrite(F, B, 1);          { reserved }
  B := 1; BlockWrite(F, B, 1); B := 0; BlockWrite(F, B, 1); { planes = 1 }
  B := 32; BlockWrite(F, B, 1); B := 0; BlockWrite(F, B, 1); { bpp = 32 }
  BlockWrite(F, ImgSize, 4);            { image size }
  BlockWrite(F, Offset, 4);             { offset to image }

  { BMP BITMAPINFOHEADER (40 bytes) }
  ImgSize := 40;
  BlockWrite(F, ImgSize, 4);            { header size = 40 }
  ImgSize := ICON_SIZE;
  BlockWrite(F, ImgSize, 4);            { width }
  ImgSize := ICON_SIZE * 2;             { height * 2 (XOR + AND) }
  BlockWrite(F, ImgSize, 4);
  B := 1; BlockWrite(F, B, 1); B := 0; BlockWrite(F, B, 1); { planes = 1 }
  B := 32; BlockWrite(F, B, 1); B := 0; BlockWrite(F, B, 1); { bpp = 32 }
  ImgSize := 0;
  BlockWrite(F, ImgSize, 4);            { compression = 0 }
  BlockWrite(F, ImgSize, 4);            { image size (can be 0) }
  BlockWrite(F, ImgSize, 4);            { X ppm }
  BlockWrite(F, ImgSize, 4);            { Y ppm }
  BlockWrite(F, ImgSize, 4);            { colors used }
  BlockWrite(F, ImgSize, 4);            { important colors }

  { Pixel data — BGRA, bottom-up }
  For Y := ICON_SIZE - 1 DownTo 0 Do
    For X := 0 to ICON_SIZE - 1 Do Begin
      BlockWrite(F, Pixels[Y, X].B, 1);
      BlockWrite(F, Pixels[Y, X].G, 1);
      BlockWrite(F, Pixels[Y, X].R, 1);
      BlockWrite(F, Pixels[Y, X].A, 1);
    End;

  { AND mask — all zeros (fully opaque since we use alpha) }
  B := 0;
  For Y := 0 to ICON_SIZE - 1 Do
    For X := 0 to 3 Do  { 32 pixels / 8 = 4 bytes per row }
      BlockWrite(F, B, 1);

  Close(F);
End;

Var
  OutFile, Style: String;
Begin
  WriteLn('MkIcon — Icon Generator for Console Apps');
  WriteLn('Copyright (C) 2025-2026 IRC Fork. GPLv3');
  WriteLn;

  If ParamCount < 1 Then Begin
    WriteLn('Usage: mkicon <output.ico> [style]');
    WriteLn;
    WriteLn('Styles:');
    WriteLn('  dos     Green >_ prompt on black (default)');
    WriteLn('  mystic  White M on blue');
    Halt(1);
  End;

  OutFile := ParamStr(1);
  If ParamCount >= 2 Then Style := LowerCase(ParamStr(2)) Else Style := 'dos';

  FillChar(Pixels, SizeOf(Pixels), 0);

  If Style = 'mystic' Then DrawMystic
  Else DrawDOS;

  WriteICO(OutFile);
  WriteLn('Created: ', OutFile, ' (', ICON_SIZE, 'x', ICON_SIZE, ' 32-bit, style: ', Style, ')');
End.
