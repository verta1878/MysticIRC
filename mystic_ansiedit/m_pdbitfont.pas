{$MODE OBJFPC}
{$H+}
unit m_pdbitfont;
{ PabloDraw Pascal — Bitmap Font (CP437) + Canvas Renderer
  Renders TPDCanvas to a pixel buffer using bitmap fonts.
  Default: 8x16 VGA font, CP437 character set. }

interface

uses Classes, SysUtils, m_pdtypes;

const
  FONT_WIDTH  = 8;
  FONT_HEIGHT = 16;
  FONT_CHARS  = 256;

type
  TPixelBuffer = class
  private
    FWidth, FHeight: Integer;
    FPixels: array of TPDColor;
  public
    constructor Create(AWidth, AHeight: Integer);
    procedure SetPixel(X, Y: Integer; const C: TPDColor);
    function  GetPixel(X, Y: Integer): TPDColor;
    procedure Clear(const C: TPDColor);
    procedure SaveToBMP(const FileName: String);
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
  end;

  TBitFont = class
  private
    FFontData: array[0..FONT_CHARS * FONT_HEIGHT - 1] of Byte;
    FFontHeight: Integer;
  public
    constructor Create;
    procedure LoadFromStream(S: TStream; NumChars, CharHeight: Integer);
    procedure LoadDefault;
    function  GetGlyph(Ch: Byte; Row: Integer): Byte;
    property  FontHeight: Integer read FFontHeight;
  end;

procedure RenderCanvas(Canvas: TPDCanvas; Font: TBitFont;
  const Palette: TPDPalette; Buffer: TPixelBuffer);

implementation

{ ---- TPixelBuffer ---- }

constructor TPixelBuffer.Create(AWidth, AHeight: Integer);
begin
  inherited Create;
  FWidth := AWidth; FHeight := AHeight;
  SetLength(FPixels, FWidth * FHeight);
end;

procedure TPixelBuffer.SetPixel(X, Y: Integer; const C: TPDColor);
begin
  if (X >= 0) and (X < FWidth) and (Y >= 0) and (Y < FHeight) then
    FPixels[Y * FWidth + X] := C;
end;

function TPixelBuffer.GetPixel(X, Y: Integer): TPDColor;
begin
  if (X >= 0) and (X < FWidth) and (Y >= 0) and (Y < FHeight) then
    Result := FPixels[Y * FWidth + X]
  else begin
    Result.R := 0; Result.G := 0; Result.B := 0;
  end;
end;

procedure TPixelBuffer.Clear(const C: TPDColor);
var I: Integer;
begin
  for I := 0 to Length(FPixels) - 1 do FPixels[I] := C;
end;

procedure TPixelBuffer.SaveToBMP(const FileName: String);
var
  F: TFileStream;
  BmpFileHdr: packed record
    bfType: Word;
    bfSize: LongWord;
    bfReserved: LongWord;
    bfOffBits: LongWord;
  end;
  BmpInfoHdr: packed record
    biSize: LongWord;
    biWidth: LongInt;
    biHeight: LongInt;
    biPlanes: Word;
    biBitCount: Word;
    biCompression: LongWord;
    biSizeImage: LongWord;
    biXPels: LongInt;
    biYPels: LongInt;
    biClrUsed: LongWord;
    biClrImportant: LongWord;
  end;
  RowSize, X, Y: Integer;
  Pad: array[0..3] of Byte;
  PadBytes: Integer;
  C: TPDColor;
begin
  RowSize := FWidth * 3;
  PadBytes := (4 - (RowSize mod 4)) mod 4;
  FillChar(Pad, 4, 0);
  
  FillChar(BmpFileHdr, SizeOf(BmpFileHdr), 0);
  BmpFileHdr.bfType := $4D42; { 'BM' }
  BmpFileHdr.bfOffBits := 14 + 40;
  BmpFileHdr.bfSize := BmpFileHdr.bfOffBits + LongWord((RowSize + PadBytes) * FHeight);
  
  FillChar(BmpInfoHdr, SizeOf(BmpInfoHdr), 0);
  BmpInfoHdr.biSize := 40;
  BmpInfoHdr.biWidth := FWidth;
  BmpInfoHdr.biHeight := -FHeight; { top-down }
  BmpInfoHdr.biPlanes := 1;
  BmpInfoHdr.biBitCount := 24;
  
  F := TFileStream.Create(FileName, fmCreate);
  try
    F.Write(BmpFileHdr, 14);
    F.Write(BmpInfoHdr, 40);
    for Y := 0 to FHeight - 1 do begin
      for X := 0 to FWidth - 1 do begin
        C := FPixels[Y * FWidth + X];
        F.Write(C.B, 1); F.Write(C.G, 1); F.Write(C.R, 1);
      end;
      if PadBytes > 0 then F.Write(Pad, PadBytes);
    end;
  finally
    F.Free;
  end;
end;

{ ---- TBitFont ---- }

constructor TBitFont.Create;
begin
  inherited;
  FFontHeight := FONT_HEIGHT;
  FillChar(FFontData, SizeOf(FFontData), 0);
end;

procedure TBitFont.LoadFromStream(S: TStream; NumChars, CharHeight: Integer);
begin
  FFontHeight := CharHeight;
  S.Read(FFontData[0], NumChars * CharHeight);
end;

{$I cp437font.inc}

procedure TBitFont.LoadDefault;
begin
  FFontHeight := 16;
  Move(CP437_Font, FFontData, 4096);
end;

function TBitFont.GetGlyph(Ch: Byte; Row: Integer): Byte;
begin
  if Row < FFontHeight then
    Result := FFontData[Integer(Ch) * FFontHeight + Row]
  else
    Result := 0;
end;

{ ---- Renderer ---- }

procedure RenderCanvas(Canvas: TPDCanvas; Font: TBitFont;
  const Palette: TPDPalette; Buffer: TPixelBuffer);
var
  X, Y, PX, PY, Row, Bit: Integer;
  E: TPDCanvasElement;
  Glyph: Byte;
  FG, BG: TPDColor;
begin
  for Y := 0 to Canvas.Height - 1 do begin
    for X := 0 to Canvas.Width - 1 do begin
      E := Canvas[X, Y];
      FG := Palette[E.Attr.GetForeground and $0F];
      BG := Palette[E.Attr.GetBackground and $0F];
      
      for Row := 0 to Font.FontHeight - 1 do begin
        Glyph := Font.GetGlyph(Byte(E.Ch.Ch), Row);
        PY := Y * Font.FontHeight + Row;
        for Bit := 0 to FONT_WIDTH - 1 do begin
          PX := X * FONT_WIDTH + Bit;
          if (Glyph and ($80 shr Bit)) <> 0 then
            Buffer.SetPixel(PX, PY, FG)
          else
            Buffer.SetPixel(PX, PY, BG);
        end;
      end;
    end;
  end;
end;

end.
