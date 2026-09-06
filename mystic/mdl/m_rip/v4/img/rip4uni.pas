(* rip4uni.pas -- RIPscrip v4.0 Unicode Companion Unit
   Copyright (C) 2026 Mystic BBS IRC Fork Contributors
   Licensed under GNU General Public License v3.

   Bridges cp437u8.pas, u8render.pas, and ttfglyph.pas
   into a single API for the engine. Provides:
   - CP437 ↔ UTF-8 translation (256 codepoints)
   - UTF-8 text width measurement
   - UTF-8 glyph rendering to RGB24 pixel buffer
   - TTF font loading and bitmap conversion

   DOS 8.3 safe: rip4uni.pas (7 chars)
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit rip4uni;

interface

Uses cp437u8, u8render, TTFGlyph;

Type
  TRIPUniFont = record
    BitmapFont : TBitmapFont;     // bitmap glyph cache from u8render
    TTF        : TTTFFont;        // loaded TTF font data
    HasTTF     : Boolean;         // TTF loaded?
    HasBitmap  : Boolean;         // bitmap font initialized?
    PixelSize  : Integer;         // current render size
  end;

// Initialize with CP437 bitmap font (always available)
procedure RIPUniInit(var F: TRIPUniFont);

// Load a TTF file and generate bitmap glyphs at given pixel size
function RIPUniLoadTTF(var F: TRIPUniFont;
                       const FileName: ShortString;
                       PixSize: Integer): Boolean;

// Free all font data
procedure RIPUniFree(var F: TRIPUniFont);

// Render UTF-8 text to RGB24 pixel buffer
procedure RIPUniDrawText(var F: TRIPUniFont;
                         Pixels: PByte; W, H: Word;
                         X, Y: SmallInt;
                         const Text: ShortString;
                         R, G, B: Byte);

// Measure UTF-8 text width in pixels
function RIPUniTextWidth(var F: TRIPUniFont;
                         const Text: ShortString): Integer;

// Convert a UTF-8 string to CP437 (lossy — unmapped chars become '?')
function RIPUniToCP437(const UTF8Text: ShortString): ShortString;

// Convert a CP437 string to UTF-8
function RIPCP437ToUni(const CP437Text: ShortString): ShortString;

implementation

procedure RIPUniInit(var F: TRIPUniFont);
Begin
  FillChar(F, SizeOf(F), 0);
  UTF8FontInitCP437(F.BitmapFont);
  F.HasBitmap := True;
  F.HasTTF    := False;
  F.PixelSize := 8;
End;

function RIPUniLoadTTF(var F: TRIPUniFont;
                       const FileName: ShortString;
                       PixSize: Integer): Boolean;
Var OK : Boolean;
Begin
  Result := False;
  If F.HasTTF Then Begin
    TTFFree(F.TTF);
    F.HasTTF := False;
  End;

  OK := TTFLoadFile(FileName, F.TTF);
  If Not OK Then Exit;

  F.HasTTF    := True;
  F.PixelSize := PixSize;

  // Generate bitmap glyphs from TTF at requested size
  // This populates the bitmap font with TTF-rendered glyphs
  // for all ASCII + Latin-1 codepoints
  TTFToBitmapFont(F.TTF, PixSize, F.BitmapFont, 0, 255);
  F.HasBitmap := True;
  Result := True;
End;

procedure RIPUniFree(var F: TRIPUniFont);
Begin
  If F.HasTTF Then Begin
    TTFFree(F.TTF);
    F.HasTTF := False;
  End;
  F.HasBitmap := False;
  FillChar(F.BitmapFont, SizeOf(F.BitmapFont), 0);
End;

procedure RIPUniDrawText(var F: TRIPUniFont;
                         Pixels: PByte; W, H: Word;
                         X, Y: SmallInt;
                         const Text: ShortString;
                         R, G, B: Byte);
Var Color : TTextColor;
Begin
  If Not F.HasBitmap Then Exit;
  Color := TextColor(R, G, B);
  UTF8RenderText(F.BitmapFont, Pixels, W, H, X, Y, Text,
                 Color, TextColor(0, 0, 0), True);
End;

function RIPUniTextWidth(var F: TRIPUniFont;
                         const Text: ShortString): Integer;
Begin
  Result := 0;
  If Not F.HasBitmap Then Exit;
  Result := UTF8TextWidth(F.BitmapFont, Text);
End;

function RIPUniToCP437(const UTF8Text: ShortString): ShortString;
Var
  Pos : Integer;
  B   : Byte;
Begin
  Result := '';
  Pos := 1;
  While Pos <= Length(UTF8Text) Do Begin
    B := UTF8ToCP437(UTF8Text, Pos);
    Result := Result + Chr(B);
  End;
End;

function RIPCP437ToUni(const CP437Text: ShortString): ShortString;
Var
  I   : Integer;
  UTF : ShortString;
Begin
  Result := '';
  For I := 1 to Length(CP437Text) Do Begin
    UTF := CP437ToUTF8(Ord(CP437Text[I]));
    If Length(Result) + Length(UTF) <= 255 Then
      Result := Result + UTF;
  End;
End;

end.
