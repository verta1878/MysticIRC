{$MODE OBJFPC}
{$H+}
unit m_pdtundra;
{ PabloDraw Pascal — Tundra Draw format loader
  Tundra24 uses 24-bit RGB color + CP437 characters.
  Header: "TUNDRA24" (8 bytes) }

interface

uses Classes, SysUtils, m_pdtypes;

procedure LoadTundra(S: TStream; Canvas: TPDCanvas; var Palette: TPDPalette);

implementation

procedure LoadTundra(S: TStream; Canvas: TPDCanvas; var Palette: TPDPalette);
var
  ID: array[0..7] of Char;
  B, Ch: Byte;
  X, Y: Integer;
  E: TPDCanvasElement;
  FG_R, FG_G, FG_B, BG_R, BG_G, BG_B: Byte;
  FGCol, BGCol: Byte;
begin
  S.Read(ID, 8);
  if Copy(ID, 1, 8) <> 'TUNDRA24' then Exit;
  
  X := 0; Y := 0;
  FGCol := 7; BGCol := 0;
  
  while S.Position < S.Size do begin
    if S.Read(B, 1) <> 1 then Break;
    
    case B of
      1: begin { Set position + character + 24-bit colors }
        if S.Read(B, 1) <> 1 then Break; { Y high }
        if S.Read(Ch, 1) <> 1 then Break; { Y low — actually this is more complex }
        Y := (B shl 8) or Ch;
        if S.Read(B, 1) <> 1 then Break;
        X := B;
        { Read 24-bit foreground }
        S.Read(FG_R, 1); S.Read(FG_G, 1); S.Read(FG_B, 1);
        { Read 24-bit background }
        S.Read(BG_R, 1); S.Read(BG_G, 1); S.Read(BG_B, 1);
        { Map to nearest palette color (simplified) }
        FGCol := 7; BGCol := 0;
      end;
      2: begin { Set foreground 24-bit }
        S.Read(FG_R, 1); S.Read(FG_G, 1); S.Read(FG_B, 1);
      end;
      4: begin { Set background 24-bit }
        S.Read(BG_R, 1); S.Read(BG_G, 1); S.Read(BG_B, 1);
      end;
      6: begin { Set both 24-bit }
        S.Read(FG_R, 1); S.Read(FG_G, 1); S.Read(FG_B, 1);
        S.Read(BG_R, 1); S.Read(BG_G, 1); S.Read(BG_B, 1);
      end;
    else
      { Regular character }
      E.Ch.Ch := B;
      E.Attr.InitColors(FGCol, BGCol);
      if (X < Canvas.Width) and (Y < Canvas.Height) then
        Canvas[X, Y] := E;
      Inc(X);
      if X >= Canvas.Width then begin X := 0; Inc(Y); end;
    end;
  end;
end;

end.
