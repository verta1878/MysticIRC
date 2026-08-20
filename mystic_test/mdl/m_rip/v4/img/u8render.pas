(* u8render.pas -- UTF-8 Text Renderer
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Renders UTF-8 text to pixel buffers using bitmap glyph data.
   Supports CP437 built-in font (8x8, 8x14, 8x16) and external
   glyph sources. For RIPscript scenes on modern terminals.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit u8render;

interface

uses cp437u8;

const
  UTF8R_MAX_GLYPHS = 512;

type
  TGlyphBitmap = record
    Width, Height: Byte;
    Data: array[0..31] of Byte;  { bitmap rows, MSB-first }
    CodePoint: LongWord;
  end;

  TBitmapFont = record
    Glyphs: array[0..UTF8R_MAX_GLYPHS - 1] of TGlyphBitmap;
    NumGlyphs: Integer;
    CellWidth, CellHeight: Byte;
    Name: ShortString;
  end;

  TTextColor = record
    R, G, B: Byte;
  end;

{ Initialize font with built-in CP437 8x8 glyphs }
procedure UTF8FontInitCP437(var F: TBitmapFont);

{ Add a glyph to font }
function UTF8FontAddGlyph(var F: TBitmapFont;
  CodePoint: LongWord; Width, Height: Byte;
  const Data: array of Byte): Integer;

{ Find glyph index for codepoint (-1 if not found) }
function UTF8FontFindGlyph(var F: TBitmapFont; CodePoint: LongWord): Integer;

{ Render a single glyph to pixel buffer }
procedure UTF8RenderGlyph(var F: TBitmapFont;
  Pixels: PByte; PxWidth, PxHeight: Word;
  X, Y: SmallInt; GlyphIdx: Integer;
  FG, BG: TTextColor; Transparent: Boolean);

{ Render UTF-8 string to pixel buffer }
procedure UTF8RenderText(var F: TBitmapFont;
  Pixels: PByte; PxWidth, PxHeight: Word;
  X, Y: SmallInt; const Text: ShortString;
  FG, BG: TTextColor; Transparent: Boolean);

{ Render CP437 string (auto-converts to UTF-8 internally) }
procedure UTF8RenderCP437(var F: TBitmapFont;
  Pixels: PByte; PxWidth, PxHeight: Word;
  X, Y: SmallInt; const Text: ShortString;
  FG, BG: TTextColor; Transparent: Boolean);

{ Measure text width in pixels }
function UTF8TextWidth(var F: TBitmapFont; const Text: ShortString): Integer;

{ Helper }
function TextColor(R, G, B: Byte): TTextColor;

implementation

function TextColor(R, G, B: Byte): TTextColor;
begin
  Result.R := R; Result.G := G; Result.B := B;
end;

procedure UTF8FontInitCP437(var F: TBitmapFont);
var
  I: Integer;
begin
  FillChar(F, SizeOf(F), 0);
  F.CellWidth := 8;
  F.CellHeight := 8;
  F.Name := 'CP437-8x8';

  { Create 256 glyphs for CP437 codepoints.
    Glyph bitmaps would normally come from a BIOS ROM dump
    or a .fnt file. Here we create placeholder glyphs. }
  for I := 0 to 255 do
  begin
    F.Glyphs[I].Width := 8;
    F.Glyphs[I].Height := 8;
    F.Glyphs[I].CodePoint := CP437Map[I];
    FillChar(F.Glyphs[I].Data, 8, 0);

    { Basic visible indicator for printable chars }
    if (I >= 32) and (I <= 126) then
    begin
      F.Glyphs[I].Data[0] := $7E;
      F.Glyphs[I].Data[1] := $81;
      F.Glyphs[I].Data[2] := $81;
      F.Glyphs[I].Data[3] := $81;
      F.Glyphs[I].Data[4] := $81;
      F.Glyphs[I].Data[5] := $81;
      F.Glyphs[I].Data[6] := $81;
      F.Glyphs[I].Data[7] := $7E;
    end;

    { Full block }
    if I = $DB then FillChar(F.Glyphs[I].Data, 8, $FF);
    { Upper half block }
    if I = $DF then begin
      F.Glyphs[I].Data[0] := $FF; F.Glyphs[I].Data[1] := $FF;
      F.Glyphs[I].Data[2] := $FF; F.Glyphs[I].Data[3] := $FF;
    end;
    { Lower half block }
    if I = $DC then begin
      F.Glyphs[I].Data[4] := $FF; F.Glyphs[I].Data[5] := $FF;
      F.Glyphs[I].Data[6] := $FF; F.Glyphs[I].Data[7] := $FF;
    end;
    { Shade blocks }
    if I = $B0 then begin { light }
      F.Glyphs[I].Data[0] := $AA; F.Glyphs[I].Data[1] := $00;
      F.Glyphs[I].Data[2] := $AA; F.Glyphs[I].Data[3] := $00;
      F.Glyphs[I].Data[4] := $AA; F.Glyphs[I].Data[5] := $00;
      F.Glyphs[I].Data[6] := $AA; F.Glyphs[I].Data[7] := $00;
    end;
    if I = $B1 then begin { medium }
      F.Glyphs[I].Data[0] := $AA; F.Glyphs[I].Data[1] := $55;
      F.Glyphs[I].Data[2] := $AA; F.Glyphs[I].Data[3] := $55;
      F.Glyphs[I].Data[4] := $AA; F.Glyphs[I].Data[5] := $55;
      F.Glyphs[I].Data[6] := $AA; F.Glyphs[I].Data[7] := $55;
    end;
    if I = $B2 then begin { dark }
      F.Glyphs[I].Data[0] := $55; F.Glyphs[I].Data[1] := $FF;
      F.Glyphs[I].Data[2] := $55; F.Glyphs[I].Data[3] := $FF;
      F.Glyphs[I].Data[4] := $55; F.Glyphs[I].Data[5] := $FF;
      F.Glyphs[I].Data[6] := $55; F.Glyphs[I].Data[7] := $FF;
    end;
  end;

  F.NumGlyphs := 256;
end;

function UTF8FontAddGlyph(var F: TBitmapFont;
  CodePoint: LongWord; Width, Height: Byte;
  const Data: array of Byte): Integer;
var
  I: Integer;
begin
  Result := -1;
  if F.NumGlyphs >= UTF8R_MAX_GLYPHS then Exit;
  Result := F.NumGlyphs;
  F.Glyphs[Result].CodePoint := CodePoint;
  F.Glyphs[Result].Width := Width;
  F.Glyphs[Result].Height := Height;
  FillChar(F.Glyphs[Result].Data, SizeOf(F.Glyphs[Result].Data), 0);
  for I := 0 to High(Data) do
    if I < 32 then F.Glyphs[Result].Data[I] := Data[I];
  Inc(F.NumGlyphs);
end;

function UTF8FontFindGlyph(var F: TBitmapFont; CodePoint: LongWord): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to F.NumGlyphs - 1 do
    if F.Glyphs[I].CodePoint = CodePoint then
    begin Result := I; Exit; end;
end;

procedure UTF8RenderGlyph(var F: TBitmapFont;
  Pixels: PByte; PxWidth, PxHeight: Word;
  X, Y: SmallInt; GlyphIdx: Integer;
  FG, BG: TTextColor; Transparent: Boolean);
var
  GX, GY: Integer;
  Off: LongInt;
  Bit: Boolean;
  G: ^TGlyphBitmap;
begin
  if (GlyphIdx < 0) or (GlyphIdx >= F.NumGlyphs) then Exit;
  G := @F.Glyphs[GlyphIdx];

  for GY := 0 to G^.Height - 1 do
  begin
    if Y + GY < 0 then Continue;
    if Y + GY >= PxHeight then Break;
    for GX := 0 to G^.Width - 1 do
    begin
      if X + GX < 0 then Continue;
      if X + GX >= PxWidth then Continue;

      Bit := (G^.Data[GY] and ($80 shr GX)) <> 0;
      Off := (LongInt(Y + GY) * PxWidth + X + GX) * 3;

      if Bit then
      begin
        Pixels[Off] := FG.R;
        Pixels[Off + 1] := FG.G;
        Pixels[Off + 2] := FG.B;
      end
      else if not Transparent then
      begin
        Pixels[Off] := BG.R;
        Pixels[Off + 1] := BG.G;
        Pixels[Off + 2] := BG.B;
      end;
    end;
  end;
end;

procedure UTF8RenderText(var F: TBitmapFont;
  Pixels: PByte; PxWidth, PxHeight: Word;
  X, Y: SmallInt; const Text: ShortString;
  FG, BG: TTextColor; Transparent: Boolean);
var
  Pos: Integer;
  CP: LongWord;
  GIdx: Integer;
  CurX: SmallInt;
begin
  Pos := 1;
  CurX := X;
  while Pos <= Length(Text) do
  begin
    CP := UTF8ToUnicode(Text, Pos);
    GIdx := UTF8FontFindGlyph(F, CP);
    if GIdx >= 0 then
      UTF8RenderGlyph(F, Pixels, PxWidth, PxHeight,
        CurX, Y, GIdx, FG, BG, Transparent);
    Inc(CurX, F.CellWidth);
  end;
end;

procedure UTF8RenderCP437(var F: TBitmapFont;
  Pixels: PByte; PxWidth, PxHeight: Word;
  X, Y: SmallInt; const Text: ShortString;
  FG, BG: TTextColor; Transparent: Boolean);
var
  I: Integer;
  CP: LongWord;
  GIdx: Integer;
  CurX: SmallInt;
begin
  CurX := X;
  for I := 1 to Length(Text) do
  begin
    CP := CP437Map[Ord(Text[I])];
    GIdx := UTF8FontFindGlyph(F, CP);
    if GIdx >= 0 then
      UTF8RenderGlyph(F, Pixels, PxWidth, PxHeight,
        CurX, Y, GIdx, FG, BG, Transparent);
    Inc(CurX, F.CellWidth);
  end;
end;

function UTF8TextWidth(var F: TBitmapFont; const Text: ShortString): Integer;
var
  Pos: Integer;
  Count: Integer;
begin
  Pos := 1;
  Count := 0;
  while Pos <= Length(Text) do
  begin
    UTF8ToUnicode(Text, Pos);
    Inc(Count);
  end;
  Result := Count * F.CellWidth;
end;

end.
