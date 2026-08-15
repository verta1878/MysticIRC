{$MODE OBJFPC}
{$H+}
unit m_pdbinary;
{ PabloDraw Pascal — Binary format loader (char+attr pairs)
  Two bytes per cell: character byte, attribute byte.
  Width typically 160 (80 columns × 2 bytes). }

interface

uses Classes, SysUtils, m_pdtypes;

procedure LoadBinary(S: TStream; Canvas: TPDCanvas; Width: Integer);
procedure LoadBinaryFile(const FileName: String; Canvas: TPDCanvas; Width: Integer);
procedure SaveBinary(S: TStream; Canvas: TPDCanvas);

implementation

procedure LoadBinary(S: TStream; Canvas: TPDCanvas; Width: Integer);
var
  X, Y: Integer;
  Ch, At: Byte;
  E: TPDCanvasElement;
begin
  X := 0; Y := 0;
  while S.Read(Ch, 1) = 1 do begin
    if S.Read(At, 1) <> 1 then Break;
    E.Ch.Ch := Ch;
    E.Attr.Init(At);
    if (X < Canvas.Width) and (Y < Canvas.Height) then
      Canvas[X, Y] := E;
    Inc(X);
    if X >= Width then begin
      X := 0; Inc(Y);
      if Y >= Canvas.Height then Break;
    end;
  end;
end;

procedure LoadBinaryFile(const FileName: String; Canvas: TPDCanvas; Width: Integer);
var F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try LoadBinary(F, Canvas, Width);
  finally F.Free; end;
end;

procedure SaveBinary(S: TStream; Canvas: TPDCanvas);
var X, Y: Integer; E: TPDCanvasElement; B: Byte;
begin
  for Y := 0 to Canvas.Height - 1 do
    for X := 0 to Canvas.Width - 1 do begin
      E := Canvas[X, Y];
      B := Byte(E.Ch.Ch);
      S.Write(B, 1);
      B := E.Attr.ToByte;
      S.Write(B, 1);
    end;
end;

end.
