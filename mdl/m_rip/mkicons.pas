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
program mkicons;
{ Generates .ICN icon files for Mystic BBS RIPscrip menus.
  .ICN format is the BGI GetImage/PutImage binary format:
    2 bytes: width - 1 (little-endian Word)
    2 bytes: height - 1 (little-endian Word)
    remaining: pixel data in EGA planar format (4 bitplanes)

  For EGA 16-color, each scanline has 4 bitplanes, each (width+7) div 8 bytes.
  Pixel color = bit from each plane combined.

  These are 24x24 pixel icons — small, clean, period-correct for RIPscrip. }

{$MODE OBJFPC}{$H+}

uses SysUtils;

const
  ICON_W = 24;
  ICON_H = 24;
  PLANES = 4;
  ROW_BYTES = (ICON_W + 7) div 8;  // 3 bytes per plane per row

type
  TIconBitmap = array[0..ICON_H-1, 0..ICON_W-1] of Byte;  // color per pixel

procedure SaveICN(const FileName: String; const Bmp: TIconBitmap);
var
  f: File;
  w, h: Word;
  row, col, plane, byteIdx, bitIdx: Integer;
  planeByte: Byte;
  rowData: array[0..PLANES*ROW_BYTES-1] of Byte;
begin
  Assign(f, FileName);
  Rewrite(f, 1);
  w := ICON_W - 1;
  h := ICON_H - 1;
  BlockWrite(f, w, 2);
  BlockWrite(f, h, 2);
  for row := 0 to ICON_H - 1 do
  begin
    FillChar(rowData, SizeOf(rowData), 0);
    for plane := 0 to PLANES - 1 do
      for col := 0 to ICON_W - 1 do
      begin
        byteIdx := plane * ROW_BYTES + (col div 8);
        bitIdx := 7 - (col mod 8);
        if (Bmp[row, col] and (1 shl plane)) <> 0 then
          rowData[byteIdx] := rowData[byteIdx] or (1 shl bitIdx);
      end;
    BlockWrite(f, rowData, PLANES * ROW_BYTES);
  end;
  Close(f);
end;

procedure ClearBmp(var Bmp: TIconBitmap; Color: Byte);
var r, c: Integer;
begin
  for r := 0 to ICON_H-1 do
    for c := 0 to ICON_W-1 do
      Bmp[r, c] := Color;
end;

procedure DrawBoxBmp(var Bmp: TIconBitmap; X1, Y1, X2, Y2, Color: Byte);
var r, c: Integer;
begin
  for c := X1 to X2 do begin Bmp[Y1, c] := Color; Bmp[Y2, c] := Color; end;
  for r := Y1 to Y2 do begin Bmp[r, X1] := Color; Bmp[r, X2] := Color; end;
end;

procedure FillBoxBmp(var Bmp: TIconBitmap; X1, Y1, X2, Y2, Color: Byte);
var r, c: Integer;
begin
  for r := Y1 to Y2 do
    for c := X1 to X2 do
      Bmp[r, c] := Color;
end;

procedure DrawLineBmp(var Bmp: TIconBitmap; X1, Y1, X2, Y2: Integer; Color: Byte);
var dx, dy, sx, sy, err, e2: Integer;
begin
  dx := Abs(X2 - X1); dy := -Abs(Y2 - Y1);
  if X1 < X2 then sx := 1 else sx := -1;
  if Y1 < Y2 then sy := 1 else sy := -1;
  err := dx + dy;
  while True do begin
    if (X1 >= 0) and (X1 < ICON_W) and (Y1 >= 0) and (Y1 < ICON_H) then
      Bmp[Y1, X1] := Color;
    if (X1 = X2) and (Y1 = Y2) then Break;
    e2 := 2 * err;
    if e2 >= dy then begin Inc(err, dy); Inc(X1, sx); end;
    if e2 <= dx then begin Inc(err, dx); Inc(Y1, sy); end;
  end;
end;

var
  bmp: TIconBitmap;
  r, c: Integer;
begin
  WriteLn('mkicons — generating RIPscrip icons for Mystic BBS');

  { MAIL icon — envelope shape }
  ClearBmp(bmp, 1);  // blue background
  FillBoxBmp(bmp, 3, 6, 20, 17, 15);  // white envelope body
  DrawBoxBmp(bmp, 3, 6, 20, 17, 0);   // black border
  DrawLineBmp(bmp, 3, 6, 11, 12, 0);   // left flap
  DrawLineBmp(bmp, 20, 6, 12, 12, 0);  // right flap
  SaveICN('text/icons/mail.icn', bmp);
  WriteLn('  mail.icn (envelope)');

  { FILES icon — folder shape }
  ClearBmp(bmp, 1);
  FillBoxBmp(bmp, 3, 5, 10, 7, 14);   // folder tab
  FillBoxBmp(bmp, 2, 7, 21, 19, 14);  // folder body
  DrawBoxBmp(bmp, 2, 7, 21, 19, 0);   // border
  DrawBoxBmp(bmp, 3, 5, 10, 7, 0);    // tab border
  SaveICN('text/icons/files.icn', bmp);
  WriteLn('  files.icn (folder)');

  { CHAT icon — speech bubble }
  ClearBmp(bmp, 1);
  FillBoxBmp(bmp, 3, 3, 20, 14, 15);  // bubble body
  DrawBoxBmp(bmp, 3, 3, 20, 14, 0);   // border
  FillBoxBmp(bmp, 7, 15, 10, 18, 15); // tail
  DrawLineBmp(bmp, 7, 14, 7, 18, 0);  // tail left
  DrawLineBmp(bmp, 7, 18, 10, 14, 0); // tail bottom
  // dots inside bubble
  bmp[8, 8] := 0; bmp[8, 12] := 0; bmp[8, 16] := 0;
  SaveICN('text/icons/chat.icn', bmp);
  WriteLn('  chat.icn (speech bubble)');

  { DOOR icon — door with handle }
  ClearBmp(bmp, 1);
  FillBoxBmp(bmp, 5, 2, 18, 21, 6);   // brown door
  DrawBoxBmp(bmp, 5, 2, 18, 21, 0);   // border
  DrawBoxBmp(bmp, 7, 4, 16, 10, 0);   // upper panel
  DrawBoxBmp(bmp, 7, 12, 16, 19, 0);  // lower panel
  FillBoxBmp(bmp, 15, 12, 17, 14, 14); // handle
  SaveICN('text/icons/door.icn', bmp);
  WriteLn('  door.icn (door)');

  { QUIT icon — exit arrow }
  ClearBmp(bmp, 1);
  FillBoxBmp(bmp, 2, 4, 12, 19, 7);   // box
  DrawBoxBmp(bmp, 2, 4, 12, 19, 0);   // border
  FillBoxBmp(bmp, 12, 9, 21, 14, 4);  // arrow body (red)
  // arrow head
  DrawLineBmp(bmp, 18, 6, 22, 11, 4);
  DrawLineBmp(bmp, 22, 11, 18, 17, 4);
  DrawLineBmp(bmp, 18, 6, 18, 17, 4);
  SaveICN('text/icons/quit.icn', bmp);
  WriteLn('  quit.icn (exit arrow)');

  { LOGO icon — star/diamond }
  ClearBmp(bmp, 1);
  // diamond shape
  for r := 0 to 11 do
    for c := (11 - r) to (12 + r) do
      if (c >= 0) and (c < ICON_W) and (r >= 0) then
        bmp[r, c] := 14;
  for r := 12 to 23 do
    for c := (r - 12) to (35 - r) do
      if (c >= 0) and (c < ICON_W) and (r < ICON_H) then
        bmp[r, c] := 14;
  SaveICN('text/icons/logo.icn', bmp);
  WriteLn('  logo.icn (diamond)');

  { WHO icon — person silhouette }
  ClearBmp(bmp, 1);
  FillBoxBmp(bmp, 9, 3, 14, 8, 15);    // head
  DrawBoxBmp(bmp, 9, 3, 14, 8, 0);
  FillBoxBmp(bmp, 7, 9, 16, 12, 15);   // shoulders
  FillBoxBmp(bmp, 5, 12, 18, 21, 15);  // body
  DrawBoxBmp(bmp, 5, 12, 18, 21, 0);
  SaveICN('text/icons/who.icn', bmp);
  WriteLn('  who.icn (person)');

  { SYSINFO icon — info circle }
  ClearBmp(bmp, 1);
  // circle (rough)
  for r := 0 to ICON_H-1 do
    for c := 0 to ICON_W-1 do
      if Sqr(c - 11) + Sqr(r - 11) <= 100 then
        bmp[r, c] := 3;  // cyan circle
  // 'i' letter
  FillBoxBmp(bmp, 10, 6, 13, 8, 15);   // dot
  FillBoxBmp(bmp, 10, 10, 13, 17, 15); // stem
  SaveICN('text/icons/sysinfo.icn', bmp);
  WriteLn('  sysinfo.icn (info circle)');

  WriteLn('Done: 8 icons generated.');
end.
