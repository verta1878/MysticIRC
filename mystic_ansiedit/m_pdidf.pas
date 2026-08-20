{$MODE OBJFPC}
{$H+}
unit m_pdidf;
{ PabloDraw Pascal — iCE Draw Format (IDF) loader
  IDF files have a 48-byte palette, embedded font,
  then character data in char+attr pairs. }

interface

uses Classes, SysUtils, m_pdtypes;

const
  IDF_HEADER_SIZE = 12;

procedure LoadIDF(S: TStream; Canvas: TPDCanvas; var Palette: TPDPalette);

implementation

procedure LoadIDF(S: TStream; Canvas: TPDCanvas; var Palette: TPDPalette);
var
  ID: array[0..3] of Byte;
  X1, Y1, X2, Y2: Word;
  X, Y, I, W, H: Integer;
  Ch, At: Byte;
  E: TPDCanvasElement;
  R, G, Bl: Byte;
  FontData: array[0..4095] of Byte;
begin
  { Header: ID(4) + x1(2) + y1(2) + x2(2) + y2(2) }
  S.Read(ID, 4);
  S.Read(X1, 2); S.Read(Y1, 2);
  S.Read(X2, 2); S.Read(Y2, 2);
  
  W := X2 - X1 + 1;
  H := Y2 - Y1 + 1;
  if W > Canvas.Width then W := Canvas.Width;
  if H > Canvas.Height then H := Canvas.Height;
  
  { Read character data }
  X := 0; Y := 0;
  for I := 0 to W * H - 1 do begin
    if S.Read(Ch, 1) <> 1 then Break;
    if S.Read(At, 1) <> 1 then Break;
    E.Ch.Ch := Ch;
    E.Attr.Init(At);
    if (X < Canvas.Width) and (Y < Canvas.Height) then
      Canvas[X, Y] := E;
    Inc(X);
    if X >= W then begin X := 0; Inc(Y); end;
  end;
  
  { Read font (4096 bytes = 256 chars × 16 rows) }
  S.Read(FontData, 4096);
  
  { Read palette (48 bytes = 16 × RGB) }
  for I := 0 to 15 do begin
    S.Read(R, 1); S.Read(G, 1); S.Read(Bl, 1);
    Palette[I].R := (R shl 2) or (R shr 4);
    Palette[I].G := (G shl 2) or (G shr 4);
    Palette[I].B := (Bl shl 2) or (Bl shr 4);
  end;
end;

end.
