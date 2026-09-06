(* prnpcl.pas -- PCL5 LaserJet Printer Driver
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   HP Printer Command Language Level 5. Raster graphics mode.
   Sends mono or grayscale bitmap via PCL raster transfer.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit prnpcl;

interface

uses prnapi;

procedure PrnPCLRegister;

implementation

var
  PCLFile: File;
  PCLOpen: Boolean;

procedure PCLCmd(var F: File; const Cmd: ShortString);
begin
  BlockWrite(F, Cmd[1], Length(Cmd));
end;

procedure PCLEsc(var F: File; const Cmd: ShortString);
var
  B: Byte;
begin
  B := 27;
  BlockWrite(F, B, 1);
  BlockWrite(F, Cmd[1], Length(Cmd));
end;

function PCLDrvOpen(var Cfg: TPrnConfig): Boolean;
var
  DPIStr: ShortString;
begin
  PCLOpen := False;
  Assign(PCLFile, Cfg.DeviceName);
  {$I-} Rewrite(PCLFile, 1); {$I+}
  Result := IOResult = 0;
  if not Result then Exit;
  PCLOpen := True;

  { Reset }
  PCLEsc(PCLFile, 'E');

  { Set resolution }
  Str(Cfg.DPI, DPIStr);
  PCLEsc(PCLFile, '*t' + DPIStr + 'R');

  { Orientation }
  if Cfg.Orientation = poLandscape then
    PCLEsc(PCLFile, '&l1O')
  else
    PCLEsc(PCLFile, '&l0O');

  { Paper size }
  case Cfg.Paper of
    ppLetter: PCLEsc(PCLFile, '&l2A');
    ppA4:     PCLEsc(PCLFile, '&l26A');
    ppLegal:  PCLEsc(PCLFile, '&l3A');
  end;
end;

function PCLDrvSend(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;
var
  Y: LongWord;
  RowBytes: LongWord;
  LenStr: ShortString;
begin
  Result := False;
  if not PCLOpen then Exit;

  RowBytes := Page.Stride;

  { Start raster graphics }
  PCLEsc(PCLFile, '*r0A');   { start at current position }

  for Y := 0 to Page.Height - 1 do
  begin
    Str(RowBytes, LenStr);
    { Transfer raster data: ESC *b [n] W [data] }
    PCLEsc(PCLFile, '*b' + LenStr + 'W');
    BlockWrite(PCLFile, Page.Mono[Y * Page.Stride], RowBytes);
  end;

  { End raster }
  PCLEsc(PCLFile, '*rB');

  { Form feed }
  PCLCmd(PCLFile, #12);

  Result := True;
end;

procedure PCLDrvClose(var Cfg: TPrnConfig);
begin
  if PCLOpen then
  begin
    PCLEsc(PCLFile, 'E');  { reset }
    Close(PCLFile);
    PCLOpen := False;
  end;
end;

procedure PrnPCLRegister;
begin
  PrnDrivers[pdPCL].Open := @PCLDrvOpen;
  PrnDrivers[pdPCL].Send := @PCLDrvSend;
  PrnDrivers[pdPCL].Close := @PCLDrvClose;
  PrnDrivers[pdPCL].Name := 'PCL5 LaserJet';
end;

end.
