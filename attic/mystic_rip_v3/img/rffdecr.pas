{ This file is part of FPC 2.6.4irc.
  Copyright (C) 2026 fpc264irc contributors.

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <https://www.gnu.org/licenses/>.
}
{ RFF Font Decoder — Raw File I/O (short string mode compatible)
  Reads TeleGrafix RFF v2.2 scalable vector font files.
  Header, face table, width table, and stroke offset parsing complete.
  Stroke rendering: TODO — signed byte pair deltas confirmed,
  pen up/down command encoding needs RIPterm comparison.

  File structure:
    0x00-0x0F: File header (data size)
    0x10-0x41: Font descriptor (version, char range, metrics)
    0x42+:     10 face entries (46 bytes each)
    After faces: Per-char advance widths (word per char, full charset)
    After widths: Per-char stroke offsets (dword per char)
    After offsets: Stroke data (signed byte pairs: dx, dy)
}
unit rffdecr;

{$H-}
{$mode objfpc}

interface

const
  RFF_MAX_FACES = 10;
  RFF_MAX_CHARS = 256;
  RFF_FACE_SIZE = 46;

type
  TRFFFaceType = (
    rffRegular,       // 0
    rffThin,          // 1 (Th)
    rffCondensed,     // 2 (Cn)
    rffWide,          // 3 (Wd)
    rffExtra,         // 4 (Ex)
    rffHollow,        // 5 (Ho)
    rffHollowThin,    // 6 (HT)
    rffHollowCond,    // 7 (HC)
    rffHollowWide,    // 8 (HW)
    rffHollowExtra    // 9 (HE)
  );

  TRFFFace = record
    Name: string[31];
    FaceID: Byte;       // byte [36]: 1,2,4,8,16,17,18,20,24,18
    Param1: SmallInt;   // byte [37]: face-specific metric
  end;

  TRFFStrokePoint = record
    DX, DY: ShortInt;   // signed byte deltas
  end;

  TRFFGlyph = record
    AdvanceWidth: SmallInt;   // character advance width in design units
    StrokeOffset: LongWord;  // offset into stroke data
    StrokeLength: LongWord;  // bytes of stroke data
    StrokeData: PByte;       // pointer into loaded file data
  end;

  TRFFFont = record
    // Header
    DataSize: Word;
    Version: Byte;         // major (2)
    MinorVersion: Byte;    // minor (2)
    FirstChar: Word;       // first character code (e.g., 46)
    LastChar: Word;        // last character code (e.g., 54)
    DesignUnits: Word;     // design units per em (17560)
    Ascent: SmallInt;      // positive, design units
    MaxWidth: SmallInt;    // max character width
    Descent: SmallInt;     // negative, design units
    FontName: string[31];

    // Face table
    FaceCount: Integer;
    Faces: array[0..RFF_MAX_FACES-1] of TRFFFace;

    // Per-char data (for current face)
    CharCount: Integer;
    Glyphs: array[0..RFF_MAX_CHARS-1] of TRFFGlyph;

    // Full width table (all chars in font, may exceed FirstChar..LastChar)
    WidthTableSize: Integer;
    Widths: array[0..RFF_MAX_CHARS-1] of SmallInt;

    // Raw file data (for stroke access)
    RawData: PByte;
    RawSize: LongWord;

    Valid: Boolean;
  end;

{ Load RFF font from file }
function RFFLoadFileRaw(const FileName: string; out Font: TRFFFont): Boolean;

{ Load RFF from memory }
function RFFLoadMemRaw(InBuf: PByte; InSize: LongWord; out Font: TRFFFont): Boolean;

{ Free RFF font }
procedure RFFFreeRaw(var Font: TRFFFont);

{ Get glyph advance width }
function RFFGlyphWidth(const Font: TRFFFont; CharCode: Word): SmallInt;

{ Get stroke data for a glyph (returns pointer + length) }
function RFFGetStrokes(const Font: TRFFFont; CharCode: Word;
  out Data: PByte; out Len: LongWord): Boolean;

{ Check if file is RFF }
function IsRFFFile(const FileName: string): Boolean;

{ TODO: Render glyph strokes to pixel buffer
  Stroke format: signed byte pairs (dx, dy) confirmed.
  Pen up/down command encoding needs RIPterm comparison.
  Possible command markers:
    - Byte value 0x7F (127) or 0x80 (-128) as pen up/down
    - Or: odd-length sequences (single byte = command)
    - Or: first byte of glyph = pen-up move to start position
  Needs real RIPterm output comparison to confirm. }

implementation

function RFFLoadMemRaw(InBuf: PByte; InSize: LongWord; out Font: TRFFFont): Boolean;
var
  Pos: LongWord;
  I, NameLen: Integer;
  FaceStart: LongWord;
  WidthStart, OffsetStart, StrokeBase: LongWord;
  NumGlyphs: Integer;
  PropByte: Byte;
begin
  Result := False;
  FillChar(Font, SizeOf(Font), 0);

  if (InBuf = nil) or (InSize < $42) then Exit;

  // Keep raw data for stroke access
  Font.RawSize := InSize;
  GetMem(Font.RawData, InSize);
  Move(InBuf^, Font.RawData^, InSize);

  // File header
  Font.DataSize := PWord(@InBuf[0])^;

  // Font descriptor
  Font.Version := InBuf[$12];
  Font.MinorVersion := InBuf[$13];
  Font.FirstChar := PWord(@InBuf[$14])^;
  Font.LastChar := PWord(@InBuf[$16])^;
  Font.DesignUnits := PWord(@InBuf[$1A])^;
  Font.Ascent := PSmallInt(@InBuf[$1C])^;
  Font.MaxWidth := PSmallInt(@InBuf[$1E])^;
  Font.Descent := PSmallInt(@InBuf[$20])^;

  // Font name (null-terminated at 0x42)
  Pos := $42;
  NameLen := 0;
  while (Pos < InSize) and (InBuf[Pos] <> 0) and (NameLen < 31) do
  begin
    Font.FontName[NameLen + 1] := Chr(InBuf[Pos]);
    Inc(NameLen);
    Inc(Pos);
  end;
  Font.FontName[0] := Chr(NameLen);
  Inc(Pos); // skip null

  // Face table: 10 faces at 46-byte intervals starting at 0x42
  FaceStart := $42;
  Font.FaceCount := RFF_MAX_FACES;
  for I := 0 to RFF_MAX_FACES - 1 do
  begin
    Pos := FaceStart + LongWord(I) * RFF_FACE_SIZE;
    if Pos + RFF_FACE_SIZE > InSize then
    begin
      Font.FaceCount := I;
      Break;
    end;

    // Read face name
    NameLen := 0;
    while (NameLen < 31) and (Pos + LongWord(NameLen) < InSize) and
          (InBuf[Pos + LongWord(NameLen)] <> 0) do
    begin
      Font.Faces[I].Name[NameLen + 1] := Chr(InBuf[Pos + LongWord(NameLen)]);
      Inc(NameLen);
    end;
    Font.Faces[I].Name[0] := Chr(NameLen);

    // Face metrics at fixed offsets within 46-byte entry
    if Pos + 37 < InSize then
    begin
      Font.Faces[I].FaceID := InBuf[Pos + 36];
      Font.Faces[I].Param1 := ShortInt(InBuf[Pos + 37]);
    end;
  end;

  // After face table: per-char advance widths
  WidthStart := FaceStart + LongWord(Font.FaceCount) * RFF_FACE_SIZE;
  Pos := WidthStart;

  // Read widths until values stop looking like widths (>2000 or <0 for extended range)
  Font.WidthTableSize := 0;
  while (Pos + 1 < InSize) and (Font.WidthTableSize < RFF_MAX_CHARS) do
  begin
    Font.Widths[Font.WidthTableSize] := PSmallInt(@Font.RawData[Pos])^;
    // Stop if we hit implausible values (negative or > design units)
    if (Font.Widths[Font.WidthTableSize] < 0) or
       (Font.Widths[Font.WidthTableSize] > Font.DesignUnits) then
    begin
      // Check if this is start of offset table (dword with zero high word)
      if (Pos + 3 < InSize) and (Font.RawData[Pos + 2] = 0) and (Font.RawData[Pos + 3] = 0) then
        Break;
    end;
    Inc(Font.WidthTableSize);
    Inc(Pos, 2);
  end;

  // Per-char stroke offsets (DWORD per char, for chars FirstChar..LastChar)
  OffsetStart := Pos;
  NumGlyphs := Font.LastChar - Font.FirstChar + 1;
  Font.CharCount := NumGlyphs;

  // Read DWORD offset table
  StrokeBase := OffsetStart + LongWord(NumGlyphs) * 4;
  for I := 0 to NumGlyphs - 1 do
  begin
    if OffsetStart + LongWord(I) * 4 + 3 < InSize then
    begin
      Font.Glyphs[I].StrokeOffset := PLongWord(@Font.RawData[OffsetStart + LongWord(I) * 4])^;

      // Calculate stroke length from next offset
      if I < NumGlyphs - 1 then
      begin
        Font.Glyphs[I].StrokeLength :=
          PLongWord(@Font.RawData[OffsetStart + LongWord(I + 1) * 4])^ -
          Font.Glyphs[I].StrokeOffset;
      end
      else
      begin
        // Last char: stroke goes to end of file (or sentinel)
        Font.Glyphs[I].StrokeLength := InSize - (StrokeBase + Font.Glyphs[I].StrokeOffset);
      end;

      // Set stroke data pointer
      if StrokeBase + Font.Glyphs[I].StrokeOffset < InSize then
        Font.Glyphs[I].StrokeData := @Font.RawData[StrokeBase + Font.Glyphs[I].StrokeOffset]
      else
        Font.Glyphs[I].StrokeData := nil;

      // Set advance width from width table
      if (Font.FirstChar + I - 32) < Font.WidthTableSize then
        Font.Glyphs[I].AdvanceWidth := Font.Widths[Font.FirstChar + I - 32]
      else
        Font.Glyphs[I].AdvanceWidth := Font.MaxWidth;
    end;
  end;

  Font.Valid := True;
  Result := True;
end;

function RFFLoadFileRaw(const FileName: string; out Font: TRFFFont): Boolean;
var
  F: File;
  Buf: PByte;
  Size, BytesRead: LongWord;
begin
  Result := False;
  FillChar(Font, SizeOf(Font), 0);
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}
  Size := FileSize(F);
  if Size < $42 then begin Close(F); Exit; end;
  GetMem(Buf, Size);
  BlockRead(F, Buf^, Size, BytesRead);
  Close(F);
  if BytesRead = Size then
    Result := RFFLoadMemRaw(Buf, Size, Font);
  FreeMem(Buf);
end;

procedure RFFFreeRaw(var Font: TRFFFont);
begin
  if Font.RawData <> nil then
  begin
    FreeMem(Font.RawData);
    Font.RawData := nil;
  end;
  Font.Valid := False;
end;

function RFFGlyphWidth(const Font: TRFFFont; CharCode: Word): SmallInt;
var
  Idx: Integer;
begin
  Result := Font.MaxWidth;
  if not Font.Valid then Exit;
  if (CharCode >= Font.FirstChar) and (CharCode <= Font.LastChar) then
  begin
    Idx := CharCode - Font.FirstChar;
    Result := Font.Glyphs[Idx].AdvanceWidth;
  end
  else if (CharCode >= 32) and (CharCode - 32 < Font.WidthTableSize) then
    Result := Font.Widths[CharCode - 32];
end;

function RFFGetStrokes(const Font: TRFFFont; CharCode: Word;
  out Data: PByte; out Len: LongWord): Boolean;
var
  Idx: Integer;
begin
  Result := False;
  Data := nil;
  Len := 0;
  if not Font.Valid then Exit;
  if (CharCode < Font.FirstChar) or (CharCode > Font.LastChar) then Exit;
  Idx := CharCode - Font.FirstChar;
  Data := Font.Glyphs[Idx].StrokeData;
  Len := Font.Glyphs[Idx].StrokeLength;
  Result := (Data <> nil) and (Len > 0);
end;

function IsRFFFile(const FileName: string): Boolean;
var
  F: File;
  Buf: array[0..1] of Byte;
  BytesRead: LongWord;
  Size: LongWord;
begin
  Result := False;
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}
  Size := FileSize(F);
  if Size < $42 then begin Close(F); Exit; end;
  // Check version bytes at 0x12-0x13:
  Seek(F, $12);
  BlockRead(F, Buf, 2, BytesRead);
  Close(F);
  Result := (BytesRead = 2) and (Buf[0] = 2) and (Buf[1] = 2); // v2.2
end;

end.
