(* prnraw.pas -- Raw Bitmap Printer Driver
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Sends raw bitmap data directly to printer device.
   Simplest driver — no protocol, just bytes to LPT/PRN.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit prnraw;

interface

uses prnapi;

procedure PrnRawRegister;

implementation

var
  RawFile: File;
  RawOpen: Boolean;

function RawDrvOpen(var Cfg: TPrnConfig): Boolean;
begin
  RawOpen := False;
  Assign(RawFile, Cfg.DeviceName);
  {$I-} Rewrite(RawFile, 1); {$I+}
  Result := IOResult = 0;
  if Result then RawOpen := True;
end;

function RawDrvSend(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;
var
  Y: LongWord;
begin
  Result := False;
  if not RawOpen then Exit;
  { Send mono bitmap row by row }
  for Y := 0 to Page.Height - 1 do
    BlockWrite(RawFile, Page.Mono[Y * Page.Stride], Page.Stride);
  Result := True;
end;

procedure RawDrvClose(var Cfg: TPrnConfig);
begin
  if RawOpen then begin Close(RawFile); RawOpen := False; end;
end;

procedure PrnRawRegister;
begin
  PrnDrivers[pdRaw].Open := @RawDrvOpen;
  PrnDrivers[pdRaw].Send := @RawDrvSend;
  PrnDrivers[pdRaw].Close := @RawDrvClose;
  PrnDrivers[pdRaw].Name := 'Raw Bitmap';
end;

end.
