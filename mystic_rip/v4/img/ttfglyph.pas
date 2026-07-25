(* ttfglyph.pas -- TrueType/OpenType Glyph Loader
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Minimal TTF parser — loads glyph outlines and rasterizes
   to bitmap for use with u8render.pas. Reads 'cmap', 'glyf',
   'head', 'hhea', 'hmtx', 'loca', 'maxp' tables.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit ttfglyph;

interface

uses u8render;

const
  TTF_MAX_CONTOURS = 64;
  TTF_MAX_POINTS = 1024;

type
  TTTFPoint = record
    X, Y: SmallInt;
    OnCurve: Boolean;
  end;

  TTTFGlyph = record
    Points: array[0..TTF_MAX_POINTS - 1] of TTTFPoint;
    NumPoints: Integer;
    ContourEnds: array[0..TTF_MAX_CONTOURS - 1] of Word;
    NumContours: Integer;
    XMin, YMin, XMax, YMax: SmallInt;
    AdvanceWidth: Word;
  end;

  TTTFFont = record
    Data: PByte;
    DataLen: LongInt;
    NumGlyphs: Word;
    UnitsPerEm: Word;
    IndexToLocFmt: Word;  { 0=short, 1=long }
    { Table offsets }
    CmapOff: LongWord;
    GlyfOff: LongWord;
    LocaOff: LongWord;
    HeadOff: LongWord;
    HheaOff: LongWord;
    HmtxOff: LongWord;
    MaxpOff: LongWord;
    NumHMetrics: Word;
    Loaded: Boolean;
  end;

{ Load TTF file into memory }
function TTFLoadFile(const FileName: ShortString; out Font: TTTFFont): Boolean;
function TTFLoadMem(Src: PByte; SrcLen: LongInt; out Font: TTTFFont): Boolean;

{ Map Unicode codepoint to glyph index }
function TTFMapChar(var Font: TTTFFont; CodePoint: LongWord): Word;

{ Load glyph outline }
function TTFLoadGlyph(var Font: TTTFFont; GlyphIndex: Word;
  out Glyph: TTTFGlyph): Boolean;

{ Rasterize glyph to bitmap at given pixel size }
procedure TTFRasterize(var Glyph: TTTFGlyph; UnitsPerEm: Word;
  PixelSize: Integer; out Bitmap: TGlyphBitmap);

{ Load TTF glyphs into a BitmapFont for rendering }
function TTFToBitmapFont(var Font: TTTFFont; PixelSize: Integer;
  out BmpFont: TBitmapFont; FirstCP, LastCP: LongWord): Boolean;

procedure TTFFree(var Font: TTTFFont);

implementation

function RB16(P: PByte): Word;
begin Result := (Word(P[0]) shl 8) or P[1]; end;

function RB32(P: PByte): LongWord;
begin Result := (LongWord(P[0]) shl 24) or (LongWord(P[1]) shl 16) or
  (LongWord(P[2]) shl 8) or P[3]; end;

function RBS16(P: PByte): SmallInt;
begin Result := SmallInt(RB16(P)); end;

function TTFLoadMem(Src: PByte; SrcLen: LongInt; out Font: TTTFFont): Boolean;
var
  NumTables, I: Integer;
  Tag: LongWord;
  Offset, Len: LongWord;
begin
  Result := False;
  FillChar(Font, SizeOf(Font), 0);

  if SrcLen < 12 then Exit;

  { Keep reference to data }
  GetMem(Font.Data, SrcLen);
  Move(Src^, Font.Data^, SrcLen);
  Font.DataLen := SrcLen;

  { Offset table }
  NumTables := RB16(@Font.Data[4]);

  { Parse table directory }
  for I := 0 to NumTables - 1 do
  begin
    if 12 + I * 16 + 16 > SrcLen then Break;
    Tag := RB32(@Font.Data[12 + I * 16]);
    Offset := RB32(@Font.Data[12 + I * 16 + 8]);
    Len := RB32(@Font.Data[12 + I * 16 + 12]);

    case Tag of
      $636D6170: Font.CmapOff := Offset; { 'cmap' }
      $676C7966: Font.GlyfOff := Offset; { 'glyf' }
      $68656164: Font.HeadOff := Offset; { 'head' }
      $68686561: Font.HheaOff := Offset; { 'hhea' }
      $686D7478: Font.HmtxOff := Offset; { 'hmtx' }
      $6C6F6361: Font.LocaOff := Offset; { 'loca' }
      $6D617870: Font.MaxpOff := Offset; { 'maxp' }
    end;
  end;

  { Read head table }
  if Font.HeadOff > 0 then
  begin
    Font.UnitsPerEm := RB16(@Font.Data[Font.HeadOff + 18]);
    Font.IndexToLocFmt := RB16(@Font.Data[Font.HeadOff + 50]);
  end;

  { Read maxp table }
  if Font.MaxpOff > 0 then
    Font.NumGlyphs := RB16(@Font.Data[Font.MaxpOff + 4]);

  { Read hhea table }
  if Font.HheaOff > 0 then
    Font.NumHMetrics := RB16(@Font.Data[Font.HheaOff + 34]);

  Font.Loaded := (Font.CmapOff > 0) and (Font.GlyfOff > 0) and
                 (Font.LocaOff > 0) and (Font.NumGlyphs > 0);
  Result := Font.Loaded;
end;

function TTFLoadFile(const FileName: ShortString; out Font: TTTFFont): Boolean;
var F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False; FillChar(Font, SizeOf(Font), 0);
  Assign(F, FileName); {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  GetMem(Buf, FS); BlockRead(F, Buf^, FS, BR); Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := TTFLoadMem(Buf, FS, Font);
  FreeMem(Buf);
end;

function TTFMapChar(var Font: TTTFFont; CodePoint: LongWord): Word;
var
  CmapPos: LongWord;
  NumSubTables, I: Integer;
  PlatID, EncID: Word;
  SubOff: LongWord;
  Fmt: Word;
  SegCount, J: Integer;
  EndCode, StartCode, IDDelta, IDRangeOff: Word;
  SegOff: LongWord;
begin
  Result := 0;
  if not Font.Loaded then Exit;

  CmapPos := Font.CmapOff;
  NumSubTables := RB16(@Font.Data[CmapPos + 2]);

  { Find Unicode subtable (platform 0 or 3) }
  for I := 0 to NumSubTables - 1 do
  begin
    PlatID := RB16(@Font.Data[CmapPos + 4 + I * 8]);
    EncID := RB16(@Font.Data[CmapPos + 6 + I * 8]);
    SubOff := RB32(@Font.Data[CmapPos + 8 + I * 8]);

    if (PlatID in [0, 3]) then
    begin
      Fmt := RB16(@Font.Data[CmapPos + SubOff]);

      if Fmt = 4 then
      begin
        { Format 4: Segment mapping }
        SegCount := RB16(@Font.Data[CmapPos + SubOff + 6]) div 2;
        SegOff := CmapPos + SubOff + 14;

        for J := 0 to SegCount - 1 do
        begin
          EndCode := RB16(@Font.Data[SegOff + J * 2]);
          StartCode := RB16(@Font.Data[SegOff + (SegCount + 1) * 2 + J * 2]);
          IDDelta := RB16(@Font.Data[SegOff + (SegCount + 1) * 4 + J * 2]);

          if (CodePoint >= StartCode) and (CodePoint <= EndCode) then
          begin
            Result := (CodePoint + IDDelta) and $FFFF;
            Exit;
          end;
        end;
      end;

      if Result > 0 then Exit;
    end;
  end;
end;

function TTFLoadGlyph(var Font: TTTFFont; GlyphIndex: Word;
  out Glyph: TTTFGlyph): Boolean;
var
  GlyphOff: LongWord;
  Pos: LongWord;
  NumContours: SmallInt;
  I: Integer;
  Flags, Repeat_: Byte;
  XCoord, YCoord: SmallInt;
  PtIdx: Integer;
begin
  Result := False;
  FillChar(Glyph, SizeOf(Glyph), 0);
  if not Font.Loaded then Exit;
  if GlyphIndex >= Font.NumGlyphs then Exit;

  { Get glyph offset from loca table }
  if Font.IndexToLocFmt = 0 then
    GlyphOff := Word(RB16(@Font.Data[Font.LocaOff + GlyphIndex * 2])) * 2
  else
    GlyphOff := RB32(@Font.Data[Font.LocaOff + GlyphIndex * 4]);

  Pos := Font.GlyfOff + GlyphOff;
  if Pos + 10 > LongWord(Font.DataLen) then Exit;

  NumContours := RBS16(@Font.Data[Pos]);
  Glyph.XMin := RBS16(@Font.Data[Pos + 2]);
  Glyph.YMin := RBS16(@Font.Data[Pos + 4]);
  Glyph.XMax := RBS16(@Font.Data[Pos + 6]);
  Glyph.YMax := RBS16(@Font.Data[Pos + 8]);
  Inc(Pos, 10);

  if NumContours < 0 then Exit; { compound glyph — skip for now }
  if NumContours > TTF_MAX_CONTOURS then NumContours := TTF_MAX_CONTOURS;
  Glyph.NumContours := NumContours;

  { Read contour endpoints }
  for I := 0 to NumContours - 1 do
  begin
    Glyph.ContourEnds[I] := RB16(@Font.Data[Pos]);
    Inc(Pos, 2);
  end;

  if NumContours > 0 then
    Glyph.NumPoints := Glyph.ContourEnds[NumContours - 1] + 1
  else
    Glyph.NumPoints := 0;

  if Glyph.NumPoints > TTF_MAX_POINTS then
    Glyph.NumPoints := TTF_MAX_POINTS;

  { Skip instructions }
  I := RB16(@Font.Data[Pos]); Inc(Pos, 2 + I);

  { Read flags }
  PtIdx := 0;
  while PtIdx < Glyph.NumPoints do
  begin
    if Pos >= LongWord(Font.DataLen) then Break;
    Flags := Font.Data[Pos]; Inc(Pos);
    Glyph.Points[PtIdx].OnCurve := (Flags and 1) <> 0;
    Inc(PtIdx);

    if (Flags and 8) <> 0 then
    begin
      if Pos >= LongWord(Font.DataLen) then Break;
      Repeat_ := Font.Data[Pos]; Inc(Pos);
      for I := 0 to Repeat_ - 1 do
      begin
        if PtIdx >= Glyph.NumPoints then Break;
        Glyph.Points[PtIdx].OnCurve := (Flags and 1) <> 0;
        Inc(PtIdx);
      end;
    end;
  end;

  { Read X coordinates (simplified — delta decoding) }
  XCoord := 0;
  for I := 0 to Glyph.NumPoints - 1 do
  begin
    if Pos >= LongWord(Font.DataLen) then Break;
    { Simplified: read as short delta }
    XCoord := XCoord + ShortInt(Font.Data[Pos]); Inc(Pos);
    Glyph.Points[I].X := XCoord;
  end;

  { Read Y coordinates }
  YCoord := 0;
  for I := 0 to Glyph.NumPoints - 1 do
  begin
    if Pos >= LongWord(Font.DataLen) then Break;
    YCoord := YCoord + ShortInt(Font.Data[Pos]); Inc(Pos);
    Glyph.Points[I].Y := YCoord;
  end;

  { Advance width from hmtx }
  if (Font.HmtxOff > 0) and (GlyphIndex < Font.NumHMetrics) then
    Glyph.AdvanceWidth := RB16(@Font.Data[Font.HmtxOff + GlyphIndex * 4]);

  Result := True;
end;

procedure TTFRasterize(var Glyph: TTTFGlyph; UnitsPerEm: Word;
  PixelSize: Integer; out Bitmap: TGlyphBitmap);
var
  Scale: Integer; { 16.16 fixed }
  I, X, Y: Integer;
  PX, PY: Integer;
  GW, GH: Integer;
begin
  FillChar(Bitmap, SizeOf(Bitmap), 0);
  if UnitsPerEm = 0 then UnitsPerEm := 1000;

  Scale := (PixelSize shl 16) div UnitsPerEm;
  GW := ((Glyph.XMax - Glyph.XMin) * Scale) shr 16;
  GH := ((Glyph.YMax - Glyph.YMin) * Scale) shr 16;
  if GW > 32 then GW := 32;
  if GH > 32 then GH := 32;
  if GW < 1 then GW := 1;
  if GH < 1 then GH := 1;

  Bitmap.Width := GW;
  Bitmap.Height := GH;
  Bitmap.CodePoint := 0;

  { Simple point rasterization — marks pixels where outline points fall }
  for I := 0 to Glyph.NumPoints - 1 do
  begin
    PX := ((Glyph.Points[I].X - Glyph.XMin) * Scale) shr 16;
    PY := GH - 1 - (((Glyph.Points[I].Y - Glyph.YMin) * Scale) shr 16);
    if (PX >= 0) and (PX < GW) and (PY >= 0) and (PY < GH) then
      Bitmap.Data[PY] := Bitmap.Data[PY] or ($80 shr (PX and 7));
  end;
end;

function TTFToBitmapFont(var Font: TTTFFont; PixelSize: Integer;
  out BmpFont: TBitmapFont; FirstCP, LastCP: LongWord): Boolean;
var
  CP: LongWord;
  GIdx: Word;
  Glyph: TTTFGlyph;
  Bitmap: TGlyphBitmap;
begin
  Result := False;
  FillChar(BmpFont, SizeOf(BmpFont), 0);
  BmpFont.CellWidth := PixelSize;
  BmpFont.CellHeight := PixelSize;
  BmpFont.Name := 'TTF';

  for CP := FirstCP to LastCP do
  begin
    if BmpFont.NumGlyphs >= UTF8R_MAX_GLYPHS then Break;
    GIdx := TTFMapChar(Font, CP);
    if GIdx = 0 then Continue;

    if TTFLoadGlyph(Font, GIdx, Glyph) then
    begin
      TTFRasterize(Glyph, Font.UnitsPerEm, PixelSize, Bitmap);
      Bitmap.CodePoint := CP;
      BmpFont.Glyphs[BmpFont.NumGlyphs] := Bitmap;
      Inc(BmpFont.NumGlyphs);
    end;
  end;

  Result := BmpFont.NumGlyphs > 0;
end;

procedure TTFFree(var Font: TTTFFont);
begin
  if Font.Data <> nil then begin FreeMem(Font.Data); Font.Data := nil; end;
  Font.Loaded := False;
end;

end.
