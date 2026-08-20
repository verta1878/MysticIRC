(* prnbmp.pas -- BMP File Print Driver
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   "Prints" to a BMP file for testing without a physical printer.
   Outputs 24-bit color BMP from the print page buffer.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit prnbmp;

interface

uses prnapi;

procedure PrnBMPRegister;

implementation

var
  BMPFile: File;
  BMPOpen: Boolean;

procedure WriteLEWord(var F: File; W: Word);
var B: array[0..1] of Byte;
begin
  B[0] := W and $FF; B[1] := (W shr 8) and $FF;
  BlockWrite(F, B, 2);
end;

procedure WriteLEDWord(var F: File; D: LongWord);
var B: array[0..3] of Byte;
begin
  B[0] := D and $FF; B[1] := (D shr 8) and $FF;
  B[2] := (D shr 16) and $FF; B[3] := (D shr 24) and $FF;
  BlockWrite(F, B, 4);
end;

function BMPDrvOpen(var Cfg: TPrnConfig): Boolean;
begin
  BMPOpen := False;
  Assign(BMPFile, Cfg.DeviceName);
  {$I-} Rewrite(BMPFile, 1); {$I+}
  Result := IOResult = 0;
  if Result then BMPOpen := True;
end;

function BMPDrvSend(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;
var
  RowStride: LongWord;
  FileSize, DataOffset: LongWord;
  Y: LongInt;
  X: LongWord;
  Pad: array[0..2] of Byte;
  PadBytes: Integer;
  Off: LongWord;
  R, G, B: Byte;
begin
  Result := False;
  if not BMPOpen then Exit;

  RowStride := ((Page.Width * 3 + 3) div 4) * 4;
  PadBytes := RowStride - Page.Width * 3;
  DataOffset := 54;
  FileSize := DataOffset + RowStride * Page.Height;
  FillChar(Pad, SizeOf(Pad), 0);

  { BMP header }
  BlockWrite(BMPFile, 'BM', 2);
  WriteLEDWord(BMPFile, FileSize);
  WriteLEDWord(BMPFile, 0);          { reserved }
  WriteLEDWord(BMPFile, DataOffset);

  { DIB header (BITMAPINFOHEADER) }
  WriteLEDWord(BMPFile, 40);
  WriteLEDWord(BMPFile, Page.Width);
  WriteLEDWord(BMPFile, Page.Height);
  WriteLEWord(BMPFile, 1);           { planes }
  WriteLEWord(BMPFile, 24);          { BPP }
  WriteLEDWord(BMPFile, 0);          { compression }
  WriteLEDWord(BMPFile, RowStride * Page.Height);
  WriteLEDWord(BMPFile, Cfg.DPI * 39); { X ppm (~DPI) }
  WriteLEDWord(BMPFile, Cfg.DPI * 39); { Y ppm }
  WriteLEDWord(BMPFile, 0);
  WriteLEDWord(BMPFile, 0);

  { Pixel data (bottom-up, BGR) }
  for Y := Page.Height - 1 downto 0 do
  begin
    for X := 0 to Page.Width - 1 do
    begin
      Off := (LongWord(Y) * Page.Width + X) * 3;
      R := Page.Pixels[Off]; G := Page.Pixels[Off+1]; B := Page.Pixels[Off+2];
      BlockWrite(BMPFile, B, 1);
      BlockWrite(BMPFile, G, 1);
      BlockWrite(BMPFile, R, 1);
    end;
    if PadBytes > 0 then
      BlockWrite(BMPFile, Pad, PadBytes);
  end;

  Result := True;
end;

procedure BMPDrvClose(var Cfg: TPrnConfig);
begin
  if BMPOpen then begin Close(BMPFile); BMPOpen := False; end;
end;

procedure PrnBMPRegister;
begin
  PrnDrivers[pdBMP].Open := @BMPDrvOpen;
  PrnDrivers[pdBMP].Send := @BMPDrvSend;
  PrnDrivers[pdBMP].Close := @BMPDrvClose;
  PrnDrivers[pdBMP].Name := 'BMP File';
end;

end.
