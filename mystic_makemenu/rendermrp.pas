{ rendermrp.pas — Render MRP menu to BMP image
  Pixel-perfect rendering of .mrp menus using mripui widgets.
  No display needed — outputs a 640x350 8-bit BMP.

  Usage:
    rendermrp main.mrp main.bmp     Render menu to BMP
    rendermrp -demo demo.bmp        Render built-in demo menu
    rendermrp -?                    Help

  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Part of Mystic BBS, MAKEMENU, MAKETEXT.
  Credits: verta1878, sysop/0, bob, evga, kiddo, wrench,
           hexadecimal, byte, DotMatrix. }
{$MODE DELPHI}
program rendermrp;

uses
  SysUtils, mripui;

const
  VERSION   = '0.1.0';
  SCR_W     = 640;
  SCR_H     = 350;

  { EGA 16-color palette — RGB values }
  EGA_PAL: Array[0..15, 0..2] of Byte = (
    (  0,   0,   0),   { 0  Black }
    (  0,   0, 170),   { 1  Blue }
    (  0, 170,   0),   { 2  Green }
    (  0, 170, 170),   { 3  Cyan }
    (170,   0,   0),   { 4  Red }
    (170,   0, 170),   { 5  Magenta }
    (170,  85,   0),   { 6  Brown }
    (170, 170, 170),   { 7  LightGray }
    ( 85,  85,  85),   { 8  DarkGray }
    ( 85,  85, 255),   { 9  LightBlue }
    ( 85, 255,  85),   { 10 LightGreen }
    ( 85, 255, 255),   { 11 LightCyan }
    (255,  85,  85),   { 12 LightRed }
    (255,  85, 255),   { 13 LightMagenta }
    (255, 255,  85),   { 14 Yellow }
    (255, 255, 255)    { 15 White }
  );

var
  Canvas: Array[0..SCR_H-1, 0..SCR_W-1] of Byte;
  CurColor: Byte;
  FillColor: Byte;
  FillStyle: Byte;

{ ================================================================
  Canvas drawing primitives
  ================================================================ }

procedure CanvasClear(Color: Byte);
var
  Y, X: Integer;
begin
  for Y := 0 to SCR_H-1 do
    for X := 0 to SCR_W-1 do
      Canvas[Y, X] := Color;
end;

procedure CanvasPixel(X, Y: Integer);
begin
  if (X >= 0) and (X < SCR_W) and (Y >= 0) and (Y < SCR_H) then
    Canvas[Y, X] := CurColor;
end;

procedure CanvasHLine(X1, X2, Y: Integer);
var
  X, T: Integer;
begin
  if (Y < 0) or (Y >= SCR_H) then Exit;
  if X1 > X2 then begin T := X1; X1 := X2; X2 := T; end;
  if X1 < 0 then X1 := 0;
  if X2 >= SCR_W then X2 := SCR_W - 1;
  for X := X1 to X2 do
    Canvas[Y, X] := CurColor;
end;

procedure CanvasLine(X1, Y1, X2, Y2: Integer);
var
  DX, DY, SX, SY, Err, E2: Integer;
begin
  DX := Abs(X2 - X1);
  DY := Abs(Y2 - Y1);
  if X1 < X2 then SX := 1 else SX := -1;
  if Y1 < Y2 then SY := 1 else SY := -1;
  Err := DX - DY;

  while True do begin
    if (X1 >= 0) and (X1 < SCR_W) and (Y1 >= 0) and (Y1 < SCR_H) then
      Canvas[Y1, X1] := CurColor;
    if (X1 = X2) and (Y1 = Y2) then Break;
    E2 := 2 * Err;
    if E2 > -DY then begin Dec(Err, DY); Inc(X1, SX); end;
    if E2 < DX then begin Inc(Err, DX); Inc(Y1, SY); end;
  end;
end;

procedure CanvasRect(X1, Y1, X2, Y2: Integer);
begin
  CanvasLine(X1, Y1, X2, Y1);
  CanvasLine(X2, Y1, X2, Y2);
  CanvasLine(X2, Y2, X1, Y2);
  CanvasLine(X1, Y2, X1, Y1);
end;

procedure CanvasBar(X1, Y1, X2, Y2: Integer);
var
  Y, X, T: Integer;
begin
  if X1 > X2 then begin T := X1; X1 := X2; X2 := T; end;
  if Y1 > Y2 then begin T := Y1; Y1 := Y2; Y2 := T; end;
  if X1 < 0 then X1 := 0;
  if Y1 < 0 then Y1 := 0;
  if X2 >= SCR_W then X2 := SCR_W - 1;
  if Y2 >= SCR_H then Y2 := SCR_H - 1;
  for Y := Y1 to Y2 do
    for X := X1 to X2 do
      Canvas[Y, X] := FillColor;
end;

{ ================================================================
  MRP Widget callbacks
  ================================================================ }

procedure CBSetColor(Color: Integer);
begin
  CurColor := Color and 15;
end;

procedure CBSetFillStyle(Style, Color: Integer);
begin
  FillStyle := Style;
  FillColor := Color and 15;
end;

procedure CBSetFillPat(Style, Color, Flag: Integer);
begin
  FillStyle := Style;
  FillColor := Color and 15;
end;

procedure CBDrawBar(X1, Y1, X2, Y2: Integer);
begin
  CanvasBar(X1, Y1, X2, Y2);
end;

procedure CBDrawRect(X1, Y1, X2, Y2: Integer);
begin
  CanvasRect(X1, Y1, X2, Y2);
end;

procedure CBDrawLine(X1, Y1, X2, Y2: Integer);
begin
  CanvasLine(X1, Y1, X2, Y2);
end;

procedure CBDrawPixel(X, Y: Integer);
begin
  CanvasPixel(X, Y);
end;

procedure CBFloodFill(X, Y, Border: Integer);
begin
  { Simple flood not needed for widget rendering }
end;

{ ================================================================
  8x8 bitmap font renderer (CP437)
  ================================================================ }

{$I ../mdl/m_rip/rip_font8x8.inc}

procedure DrawText(X, Y: Integer; const S: String; Color: Byte);
var
  I, Row, Col: Integer;
  Ch: Byte;
  Bits: Byte;
  OldColor: Byte;
begin
  OldColor := CurColor;
  CurColor := Color;
  for I := 1 to Length(S) do begin
    Ch := Ord(S[I]);
    for Row := 0 to 7 do begin
      Bits := Font8x8[Ch * 8 + Row];
      for Col := 0 to 7 do
        if (Bits and (128 shr Col)) <> 0 then begin
          if (X + (I-1)*8 + Col >= 0) and (X + (I-1)*8 + Col < SCR_W) and
             (Y + Row >= 0) and (Y + Row < SCR_H) then
            Canvas[Y + Row, X + (I-1)*8 + Col] := CurColor;
        end;
    end;
  end;
  CurColor := OldColor;
end;

{ ================================================================
  BMP writer (8-bit indexed, EGA palette)
  ================================================================ }

procedure WriteBMP(const FileName: String);
var
  F: File;
  X, Y, I: Integer;
  Row: Array[0..1023] of Byte;
  Hdr: Array[0..53] of Byte;
  PalBuf: Array[0..1023] of Byte;
  FileSize, DataOffset, DataSize: LongInt;
  W, H: LongInt;
begin
  W := SCR_W;
  H := SCR_H;
  DataOffset := 54 + 1024;
  DataSize := W * H;
  FileSize := DataOffset + DataSize;

  Assign(F, FileName);
  {$I-} ReWrite(F, 1); {$I+}
  if IOResult <> 0 then begin
    WriteLn('ERROR: Cannot create ', FileName);
    Exit;
  end;

  { BMP header }
  FillChar(Hdr, 54, 0);
  Hdr[0] := Ord('B'); Hdr[1] := Ord('M');
  Move(FileSize, Hdr[2], 4);
  Move(DataOffset, Hdr[10], 4);
  Hdr[14] := 40;
  Move(W, Hdr[18], 4);
  Move(H, Hdr[22], 4);
  Hdr[26] := 1;
  Hdr[28] := 8;
  Move(DataSize, Hdr[34], 4);
  I := 256; Move(I, Hdr[46], 4); Move(I, Hdr[50], 4);
  BlockWrite(F, Hdr, 54);

  { Palette — 256 entries x 4 bytes BGRA }
  FillChar(PalBuf, 1024, 0);
  for I := 0 to 15 do begin
    PalBuf[I*4 + 0] := EGA_PAL[I, 2]; { Blue }
    PalBuf[I*4 + 1] := EGA_PAL[I, 1]; { Green }
    PalBuf[I*4 + 2] := EGA_PAL[I, 0]; { Red }
    PalBuf[I*4 + 3] := 0;
  end;
  BlockWrite(F, PalBuf, 1024);

  { Pixel data — bottom-up }
  for Y := SCR_H-1 downto 0 do begin
    for X := 0 to SCR_W-1 do
      Row[X] := Canvas[Y, X];
    BlockWrite(F, Row, SCR_W);
  end;

  Close(F);
end;

{ ================================================================
  Demo menu renderer
  ================================================================ }

procedure RenderDemo;
var
  CB: TWizDrawCallbacks;
begin
  CB.SetColor     := @CBSetColor;
  CB.SetFillStyle := @CBSetFillStyle;
  CB.SetFillPat   := @CBSetFillPat;
  CB.DrawBar      := @CBDrawBar;
  CB.DrawRect     := @CBDrawRect;
  CB.DrawLine     := @CBDrawLine;
  CB.DrawPixel    := @CBDrawPixel;
  CB.FloodFill    := @CBFloodFill;

  FillColor := 1;
  CanvasBar(0, 0, SCR_W-1, SCR_H-1);

  FillColor := 1;
  CanvasBar(0, 0, SCR_W-1, 12);
  DrawText(200, 2, 'MYSTIC BBS MAKEMENU v0.1.0', 11);

  FillColor := 7;
  CanvasBar(0, SCR_H-12, SCR_W-1, SCR_H-1);
  DrawText(8, SCR_H-10, '/I-Insert  /D-Delete  /C-Copy  /P-Paste  ENTER-Select  ESC-Exit', 0);

  CurColor := 15;
  CanvasRect(56, 40, 584, 260);
  FillColor := 1;
  CanvasBar(57, 41, 583, 259);

  DrawText(260, 28, ' Themes ', 14);

  FillColor := 3;
  CanvasBar(58, 42, 582, 52);
  DrawText(64, 44, 'File Name             Description', 0);

  CurColor := 7;
  CanvasLine(58, 54, 582, 54);

  FillColor := 9;
  CanvasBar(58, 56, 582, 66);
  DrawText(64, 58, 'default               Default', 14);

  DrawText(64, 70, 'ripart                RIP Graphics Theme', 7);

  CurColor := 7;
  CanvasLine(58, 240, 582, 240);

  DrawText(120, 246, '/I-Insert /D-Delete /C-Copy /P-Paste', 11);

  FillColor := 0;
  CanvasBar(585, 44, 590, 260);
  CanvasBar(60, 261, 590, 265);

  DrawText(528, SCR_H-10, 'the crew 4free', 8);
end;

procedure ShowHelp;
begin
  WriteLn('rendermrp v', VERSION, ' — Render MRP menu to BMP');
  WriteLn('');
  WriteLn('Usage:');
  WriteLn('  rendermrp -demo output.bmp    Render demo menu');
  WriteLn('  rendermrp menu.mrp output.bmp Render .mrp file (TODO)');
  WriteLn('  rendermrp -?                  This help');
  WriteLn('');
  WriteLn('Output: 640x350 8-bit BMP with EGA palette');
  WriteLn('Widget concept inspired by JMedia v2.0');
end;

var
  OutFile: String;
begin
  if (ParamCount = 0) or (ParamStr(1) = '-?') or (ParamStr(1) = '-h') then begin
    ShowHelp;
    Halt(0);
  end;

  if ParamStr(1) = '-demo' then begin
    if ParamCount >= 2 then
      OutFile := ParamStr(2)
    else
      OutFile := 'demo.bmp';

    CanvasClear(0);
    RenderDemo;
    WriteBMP(OutFile);
    WriteLn('Rendered: ', OutFile, ' (', SCR_W, 'x', SCR_H, ' 8-bit EGA)');
  end else begin
    WriteLn('TODO: .mrp file rendering');
    WriteLn('Use -demo for now');
  end;
end.
