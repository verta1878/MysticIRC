(* prnapi.pas -- Common Print API
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Platform-independent print API for RIPscript engines.
   Config, page buffer, DPI scaling, dithering.
   Drivers plug in via function pointers.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit prnapi;

interface

type
  TPrnDriver = (pdNone, pdEscP, pdPCL, pdPostScript, pdBMP, pdRaw);
  TPrnOrient = (poPortrait, poLandscape);
  TPrnPaper = (ppLetter, ppA4, ppLegal, ppCustom);
  TPrnDither = (pdtNone, pdtOrdered, pdtFloydSteinberg);

  TPrnConfig = record
    Driver: TPrnDriver;
    DPI: Word;
    Paper: TPrnPaper;
    Orientation: TPrnOrient;
    MarginTop: Word;        { 1/100 inch }
    MarginBottom: Word;
    MarginLeft: Word;
    MarginRight: Word;
    PageWidthDots: LongWord;
    PageHeightDots: LongWord;
    PageWidthInch100: Word; { paper width in 1/100 inch }
    PageHeightInch100: Word;
    DeviceName: ShortString;
    Copies: Byte;
    Dither: TPrnDither;
  end;

  TPrnPage = record
    Pixels: PByte;          { RGB, 3 bytes/pixel at target DPI }
    Mono: PByte;            { 1-bit dithered for dot-matrix }
    Width, Height: LongWord;
    Stride: LongWord;       { bytes per row in mono bitmap }
    BPP: Byte;              { 24=color, 8=gray, 1=mono }
    Allocated: Boolean;
  end;

  { Driver function pointers }
  TPrnDrvOpen = function(var Cfg: TPrnConfig): Boolean;
  TPrnDrvSend = function(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;
  TPrnDrvClose = procedure(var Cfg: TPrnConfig);

  TPrnDriverRec = record
    Open: TPrnDrvOpen;
    Send: TPrnDrvSend;
    Close: TPrnDrvClose;
    Name: ShortString;
  end;

var
  PrnDrivers: array[TPrnDriver] of TPrnDriverRec;

{ Initialize config with paper/DPI defaults }
procedure PrnInitConfig(var Cfg: TPrnConfig; Driver: TPrnDriver; DPI: Word);

{ Set paper size }
procedure PrnSetPaper(var Cfg: TPrnConfig; Paper: TPrnPaper);

{ Set margins (1/100 inch) }
procedure PrnSetMargins(var Cfg: TPrnConfig; Top, Bottom, Left, Right: Word);

{ Create page buffer at configured DPI }
procedure PrnCreatePage(var Cfg: TPrnConfig; var Page: TPrnPage);

{ Render RIP framebuffer to print page (bilinear scale to DPI) }
procedure PrnRenderFrame(var Page: TPrnPage;
  RIPPixels: PByte; RIPW, RIPH: Word);

{ Convert color page to mono (1-bit) with dithering }
procedure PrnDitherPage(var Page: TPrnPage; Method: TPrnDither);

{ Send page to printer via configured driver }
function PrnPrintPage(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;

{ Free page }
procedure PrnFreePage(var Page: TPrnPage);

{ Calculate printable area in dots }
procedure PrnCalcArea(var Cfg: TPrnConfig);

implementation

procedure PrnSetPaper(var Cfg: TPrnConfig; Paper: TPrnPaper);
begin
  Cfg.Paper := Paper;
  case Paper of
    ppLetter: begin Cfg.PageWidthInch100 := 850; Cfg.PageHeightInch100 := 1100; end;
    ppA4:     begin Cfg.PageWidthInch100 := 827; Cfg.PageHeightInch100 := 1169; end;
    ppLegal:  begin Cfg.PageWidthInch100 := 850; Cfg.PageHeightInch100 := 1400; end;
    ppCustom: ; { user sets manually }
  end;
  PrnCalcArea(Cfg);
end;

procedure PrnSetMargins(var Cfg: TPrnConfig; Top, Bottom, Left, Right: Word);
begin
  Cfg.MarginTop := Top; Cfg.MarginBottom := Bottom;
  Cfg.MarginLeft := Left; Cfg.MarginRight := Right;
  PrnCalcArea(Cfg);
end;

procedure PrnCalcArea(var Cfg: TPrnConfig);
var
  PrintW, PrintH: Word;
begin
  PrintW := Cfg.PageWidthInch100 - Cfg.MarginLeft - Cfg.MarginRight;
  PrintH := Cfg.PageHeightInch100 - Cfg.MarginTop - Cfg.MarginBottom;
  Cfg.PageWidthDots := (LongWord(PrintW) * Cfg.DPI) div 100;
  Cfg.PageHeightDots := (LongWord(PrintH) * Cfg.DPI) div 100;
end;

procedure PrnInitConfig(var Cfg: TPrnConfig; Driver: TPrnDriver; DPI: Word);
begin
  FillChar(Cfg, SizeOf(Cfg), 0);
  Cfg.Driver := Driver;
  Cfg.DPI := DPI;
  Cfg.Copies := 1;
  Cfg.Orientation := poPortrait;
  Cfg.Dither := pdtFloydSteinberg;
  Cfg.DeviceName := 'LPT1';
  PrnSetMargins(Cfg, 50, 50, 50, 50);  { 0.5" margins }
  PrnSetPaper(Cfg, ppLetter);
end;

procedure PrnCreatePage(var Cfg: TPrnConfig; var Page: TPrnPage);
begin
  FillChar(Page, SizeOf(Page), 0);
  Page.Width := Cfg.PageWidthDots;
  Page.Height := Cfg.PageHeightDots;
  Page.BPP := 24;
  GetMem(Page.Pixels, Page.Width * Page.Height * 3);
  FillChar(Page.Pixels^, Page.Width * Page.Height * 3, 255); { white }
  Page.Stride := (Page.Width + 7) div 8;
  GetMem(Page.Mono, Page.Stride * Page.Height);
  FillChar(Page.Mono^, Page.Stride * Page.Height, 0);
  Page.Allocated := True;
end;

procedure PrnRenderFrame(var Page: TPrnPage;
  RIPPixels: PByte; RIPW, RIPH: Word);
var
  X, Y: LongWord;
  SrcX, SrcY: LongWord;
  SrcOff, DstOff: LongWord;
  XRatio, YRatio: LongWord; { 16.16 fixed }
begin
  if (RIPW = 0) or (RIPH = 0) then Exit;
  XRatio := (LongWord(RIPW) shl 16) div Page.Width;
  YRatio := (LongWord(RIPH) shl 16) div Page.Height;

  for Y := 0 to Page.Height - 1 do
  begin
    SrcY := (Y * YRatio) shr 16;
    if SrcY >= RIPH then SrcY := RIPH - 1;
    for X := 0 to Page.Width - 1 do
    begin
      SrcX := (X * XRatio) shr 16;
      if SrcX >= RIPW then SrcX := RIPW - 1;
      SrcOff := (SrcY * LongWord(RIPW) + SrcX) * 3;
      DstOff := (Y * Page.Width + X) * 3;
      Page.Pixels[DstOff] := RIPPixels[SrcOff];
      Page.Pixels[DstOff + 1] := RIPPixels[SrcOff + 1];
      Page.Pixels[DstOff + 2] := RIPPixels[SrcOff + 2];
    end;
  end;
end;

procedure PrnDitherPage(var Page: TPrnPage; Method: TPrnDither);
var
  X, Y: LongWord;
  Off: LongWord;
  Gray, OldPixel, NewPixel: Integer;
  Err: Integer;
  ErrBuf: PLongInt;
  ErrSize: LongWord;
begin
  ErrSize := (Page.Width + 2) * SizeOf(LongInt);
  GetMem(ErrBuf, ErrSize);
  FillChar(ErrBuf^, ErrSize, 0);

  for Y := 0 to Page.Height - 1 do
  begin
    for X := 0 to Page.Width - 1 do
    begin
      Off := (Y * Page.Width + X) * 3;
      { Convert to grayscale }
      Gray := (Integer(Page.Pixels[Off]) * 77 +
               Integer(Page.Pixels[Off+1]) * 150 +
               Integer(Page.Pixels[Off+2]) * 29) shr 8;

      case Method of
        pdtNone:
          NewPixel := Ord(Gray < 128);

        pdtOrdered:
        begin
          { 4x4 Bayer matrix }
          case ((Y and 3) * 4 + (X and 3)) of
            0: Err := 0;   1: Err := 128; 2: Err := 32;  3: Err := 160;
            4: Err := 192; 5: Err := 64;  6: Err := 224; 7: Err := 96;
            8: Err := 48;  9: Err := 176; 10: Err := 16; 11: Err := 144;
            12: Err := 240;13: Err := 112; 14: Err := 208;15: Err := 80;
          else Err := 128;
          end;
          NewPixel := Ord(Gray < Err);
        end;

        pdtFloydSteinberg:
        begin
          OldPixel := Gray + ErrBuf[X + 1];
          if OldPixel < 128 then NewPixel := 1 else NewPixel := 0;
          if NewPixel = 1 then Err := OldPixel else Err := OldPixel - 255;
          { Distribute error }
          if X + 2 < LongWord(Page.Width + 2) then
            Inc(ErrBuf[X + 2], (Err * 7) div 16);
        end;
      else
        NewPixel := Ord(Gray < 128);
      end;

      { Set mono bit }
      if NewPixel = 1 then
        Page.Mono[Y * Page.Stride + X div 8] :=
          Page.Mono[Y * Page.Stride + X div 8] or ($80 shr (X and 7));
    end;

    { Reset error buffer for next row }
    if Method = pdtFloydSteinberg then
      FillChar(ErrBuf^, ErrSize, 0);
  end;

  FreeMem(ErrBuf);
end;

function PrnPrintPage(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;
begin
  Result := False;
  if Cfg.Driver = pdNone then Exit;
  if not Assigned(PrnDrivers[Cfg.Driver].Open) then Exit;
  if not Assigned(PrnDrivers[Cfg.Driver].Send) then Exit;

  if not PrnDrivers[Cfg.Driver].Open(Cfg) then Exit;
  Result := PrnDrivers[Cfg.Driver].Send(Cfg, Page);
  if Assigned(PrnDrivers[Cfg.Driver].Close) then
    PrnDrivers[Cfg.Driver].Close(Cfg);
end;

procedure PrnFreePage(var Page: TPrnPage);
begin
  if Page.Pixels <> nil then begin FreeMem(Page.Pixels); Page.Pixels := nil; end;
  if Page.Mono <> nil then begin FreeMem(Page.Mono); Page.Mono := nil; end;
  Page.Allocated := False;
end;

end.
