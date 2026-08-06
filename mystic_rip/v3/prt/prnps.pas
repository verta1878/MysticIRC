(* prnps.pas -- PostScript Printer Driver
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   PostScript Level 1/2 output. Encodes page as hex bitmap
   or can emit vector commands for RIPscript primitives.
   Output to file or pipe to lpr.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit prnps;

interface

uses prnapi;

procedure PrnPSRegister;

implementation

var
  PSFile: File;
  PSOpen: Boolean;

procedure PSWrite(var F: File; const S: ShortString);
begin
  BlockWrite(F, S[1], Length(S));
end;

procedure PSWriteLn(var F: File; const S: ShortString);
var
  NL: array[0..0] of Byte;
begin
  PSWrite(F, S);
  NL[0] := 10;
  BlockWrite(F, NL, 1);
end;

function PSDrvOpen(var Cfg: TPrnConfig): Boolean;
begin
  PSOpen := False;
  Assign(PSFile, Cfg.DeviceName);
  {$I-} Rewrite(PSFile, 1); {$I+}
  Result := IOResult = 0;
  if not Result then Exit;
  PSOpen := True;

  { PostScript header }
  PSWriteLn(PSFile, '%!PS-Adobe-2.0');
  PSWriteLn(PSFile, '%%Creator: FPC 2.6.4irc RIPscript Print API');
  PSWriteLn(PSFile, '%%Pages: 1');
  PSWriteLn(PSFile, '%%BoundingBox: 0 0 612 792');
  PSWriteLn(PSFile, '%%EndComments');
  PSWriteLn(PSFile, '%%Page: 1 1');
end;

function PSDrvSend(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;
var
  X, Y: LongWord;
  Off: LongWord;
  ScaleX, ScaleY: ShortString;
  WStr, HStr: ShortString;
  HexByte: ShortString;
  ColCount: Integer;
  B: Byte;
begin
  Result := False;
  if not PSOpen then Exit;

  { Calculate scale to fit page (72 points/inch) }
  Str(Page.Width, WStr);
  Str(Page.Height, HStr);

  { Position and scale }
  PSWriteLn(PSFile, 'gsave');
  PSWriteLn(PSFile, '36 36 translate');  { 0.5" margin }

  Str((Cfg.PageWidthInch100 - 100) * 72 div 100, ScaleX);
  Str((Cfg.PageHeightInch100 - 100) * 72 div 100, ScaleY);
  PSWriteLn(PSFile, ScaleX + ' ' + ScaleY + ' scale');

  { Image command }
  PSWriteLn(PSFile, WStr + ' ' + HStr + ' 8');
  PSWriteLn(PSFile, '[' + WStr + ' 0 0 -' + HStr + ' 0 ' + HStr + ']');
  PSWriteLn(PSFile, '{currentfile ' + WStr + ' 3 mul string readhexstring pop}');
  PSWriteLn(PSFile, 'false 3 colorimage');

  { Hex-encoded RGB pixel data }
  ColCount := 0;
  for Y := 0 to Page.Height - 1 do
  begin
    for X := 0 to Page.Width - 1 do
    begin
      Off := (Y * Page.Width + X) * 3;

      { R }
      B := Page.Pixels[Off];
      HexByte := '';
      HexByte := HexByte + Chr(Ord('0') + (B shr 4));
      if (B shr 4) > 9 then HexByte[Length(HexByte)] := Chr(Ord('a') + (B shr 4) - 10);
      HexByte := HexByte + Chr(Ord('0') + (B and $F));
      if (B and $F) > 9 then HexByte[Length(HexByte)] := Chr(Ord('a') + (B and $F) - 10);
      PSWrite(PSFile, HexByte);

      { G }
      B := Page.Pixels[Off + 1];
      HexByte := '';
      HexByte := HexByte + Chr(Ord('0') + (B shr 4));
      if (B shr 4) > 9 then HexByte[Length(HexByte)] := Chr(Ord('a') + (B shr 4) - 10);
      HexByte := HexByte + Chr(Ord('0') + (B and $F));
      if (B and $F) > 9 then HexByte[Length(HexByte)] := Chr(Ord('a') + (B and $F) - 10);
      PSWrite(PSFile, HexByte);

      { B }
      B := Page.Pixels[Off + 2];
      HexByte := '';
      HexByte := HexByte + Chr(Ord('0') + (B shr 4));
      if (B shr 4) > 9 then HexByte[Length(HexByte)] := Chr(Ord('a') + (B shr 4) - 10);
      HexByte := HexByte + Chr(Ord('0') + (B and $F));
      if (B and $F) > 9 then HexByte[Length(HexByte)] := Chr(Ord('a') + (B and $F) - 10);
      PSWrite(PSFile, HexByte);

      Inc(ColCount, 6);
      if ColCount >= 72 then
      begin
        PSWriteLn(PSFile, '');
        ColCount := 0;
      end;
    end;
  end;

  PSWriteLn(PSFile, '');
  PSWriteLn(PSFile, 'grestore');
  PSWriteLn(PSFile, 'showpage');

  Result := True;
end;

procedure PSDrvClose(var Cfg: TPrnConfig);
begin
  if PSOpen then
  begin
    PSWriteLn(PSFile, '%%EOF');
    Close(PSFile);
    PSOpen := False;
  end;
end;

procedure PrnPSRegister;
begin
  PrnDrivers[pdPostScript].Open := @PSDrvOpen;
  PrnDrivers[pdPostScript].Send := @PSDrvSend;
  PrnDrivers[pdPostScript].Close := @PSDrvClose;
  PrnDrivers[pdPostScript].Name := 'PostScript';
end;

end.
