{$MODE OBJFPC}
{$H+}
unit m_pdxbin;
{ PabloDraw Pascal — XBin format loader/saver
  XBin = eXtended BIN, includes embedded font + palette + compression.
  Header: "XBIN" + EOF + Width(2) + Height(2) + FontSize(1) + Flags(1) }

interface

uses Classes, SysUtils, m_pdtypes;

const
  XBIN_ID = 'XBIN';
  XBIN_FLAG_PALETTE    = $01;
  XBIN_FLAG_FONT       = $02;
  XBIN_FLAG_COMPRESS   = $04;
  XBIN_FLAG_NONBLINK   = $08;
  XBIN_FLAG_512CHARS   = $10;

type
  TXBinHeader = packed record
    ID:       array[0..3] of Char;
    EOFChar:  Byte;
    Width:    Word;
    Height:   Word;
    FontSize: Byte;
    Flags:    Byte;
  end;

procedure LoadXBin(S: TStream; Canvas: TPDCanvas;
  var Palette: TPDPalette; var FontData: array of Byte;
  var FontSize: Byte; var HasPalette, HasFont: Boolean);
procedure LoadXBinFile(const FileName: String; Canvas: TPDCanvas;
  var Palette: TPDPalette; var FontData: array of Byte;
  var FontSize: Byte; var HasPalette, HasFont: Boolean);

implementation

procedure LoadXBin(S: TStream; Canvas: TPDCanvas;
  var Palette: TPDPalette; var FontData: array of Byte;
  var FontSize: Byte; var HasPalette, HasFont: Boolean);
var
  Hdr: TXBinHeader;
  X, Y, I, Count: Integer;
  B, Ch, At, CompType: Byte;
  E: TPDCanvasElement;
  R, G, Bl: Byte;
begin
  HasPalette := False;
  HasFont := False;
  
  S.Read(Hdr, SizeOf(Hdr));
  if (Hdr.ID[0] <> 'X') or (Hdr.ID[1] <> 'B') or
     (Hdr.ID[2] <> 'I') or (Hdr.ID[3] <> 'N') then Exit;
  
  FontSize := Hdr.FontSize;
  if FontSize = 0 then FontSize := 16;
  
  Canvas.Resize(Hdr.Width, Hdr.Height);
  
  { Read palette (48 bytes = 16 × RGB) }
  if (Hdr.Flags and XBIN_FLAG_PALETTE) <> 0 then begin
    HasPalette := True;
    for I := 0 to 15 do begin
      S.Read(R, 1); S.Read(G, 1); S.Read(Bl, 1);
      Palette[I].R := (R shl 2) or (R shr 4);
      Palette[I].G := (G shl 2) or (G shr 4);
      Palette[I].B := (Bl shl 2) or (Bl shr 4);
    end;
  end;
  
  { Read font data }
  if (Hdr.Flags and XBIN_FLAG_FONT) <> 0 then begin
    HasFont := True;
    Count := 256 * FontSize;
    if (Hdr.Flags and XBIN_FLAG_512CHARS) <> 0 then
      Count := 512 * FontSize;
    if Count <= Length(FontData) then
      S.Read(FontData[0], Count);
  end;
  
  { Read character data }
  X := 0; Y := 0;
  
  if (Hdr.Flags and XBIN_FLAG_COMPRESS) <> 0 then begin
    { XBin compression }
    while (Y < Hdr.Height) and (S.Position < S.Size) do begin
      S.Read(B, 1);
      CompType := B and $C0;
      Count := (B and $3F) + 1;
      
      case CompType of
        $00: begin { No compression — Count literal pairs }
          for I := 1 to Count do begin
            if S.Read(Ch, 1) <> 1 then Break;
            if S.Read(At, 1) <> 1 then Break;
            E.Ch.Ch := Ch; E.Attr.Init(At);
            if (X < Hdr.Width) and (Y < Hdr.Height) then
              Canvas[X, Y] := E;
            Inc(X);
            if X >= Hdr.Width then begin X := 0; Inc(Y); end;
          end;
        end;
        $40: begin { Character compression — same char, different attrs }
          if S.Read(Ch, 1) <> 1 then Break;
          for I := 1 to Count do begin
            if S.Read(At, 1) <> 1 then Break;
            E.Ch.Ch := Ch; E.Attr.Init(At);
            if (X < Hdr.Width) and (Y < Hdr.Height) then
              Canvas[X, Y] := E;
            Inc(X);
            if X >= Hdr.Width then begin X := 0; Inc(Y); end;
          end;
        end;
        $80: begin { Attribute compression — different chars, same attr }
          if S.Read(At, 1) <> 1 then Break;
          for I := 1 to Count do begin
            if S.Read(Ch, 1) <> 1 then Break;
            E.Ch.Ch := Ch; E.Attr.Init(At);
            if (X < Hdr.Width) and (Y < Hdr.Height) then
              Canvas[X, Y] := E;
            Inc(X);
            if X >= Hdr.Width then begin X := 0; Inc(Y); end;
          end;
        end;
        $C0: begin { Both compression — same char+attr repeated }
          if S.Read(Ch, 1) <> 1 then Break;
          if S.Read(At, 1) <> 1 then Break;
          E.Ch.Ch := Ch; E.Attr.Init(At);
          for I := 1 to Count do begin
            if (X < Hdr.Width) and (Y < Hdr.Height) then
              Canvas[X, Y] := E;
            Inc(X);
            if X >= Hdr.Width then begin X := 0; Inc(Y); end;
          end;
        end;
      end;
    end;
  end else begin
    { Uncompressed — raw char+attr pairs }
    while (Y < Hdr.Height) and (S.Position < S.Size) do begin
      if S.Read(Ch, 1) <> 1 then Break;
      if S.Read(At, 1) <> 1 then Break;
      E.Ch.Ch := Ch; E.Attr.Init(At);
      if (X < Hdr.Width) and (Y < Hdr.Height) then
        Canvas[X, Y] := E;
      Inc(X);
      if X >= Hdr.Width then begin X := 0; Inc(Y); end;
    end;
  end;
end;

procedure LoadXBinFile(const FileName: String; Canvas: TPDCanvas;
  var Palette: TPDPalette; var FontData: array of Byte;
  var FontSize: Byte; var HasPalette, HasFont: Boolean);
var F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try LoadXBin(F, Canvas, Palette, FontData, FontSize, HasPalette, HasFont);
  finally F.Free; end;
end;

end.
