(* prnescp.pas -- ESC/P Dot-Matrix Printer Driver
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Epson Standard Code for Printers. 9-pin and 24-pin modes.
   Sends mono bitmap as graphics lines via ESC * commands.
   The BBS-era printer.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit prnescp;

interface

uses prnapi;

procedure PrnEscPRegister;

implementation

var
  EscFile: File;
  EscOpen: Boolean;

procedure SendBytes(var F: File; const Data: array of Byte);
begin
  BlockWrite(F, Data, Length(Data));
end;

procedure SendStr(var F: File; const S: ShortString);
begin
  BlockWrite(F, S[1], Length(S));
end;

function EscDrvOpen(var Cfg: TPrnConfig): Boolean;
begin
  EscOpen := False;
  Assign(EscFile, Cfg.DeviceName);
  {$I-} Rewrite(EscFile, 1); {$I+}
  Result := IOResult = 0;
  if not Result then Exit;
  EscOpen := True;

  { Initialize printer }
  SendBytes(EscFile, [27, Ord('@')]);  { ESC @ = reset }

  { Set line spacing for graphics: 24/180" for 24-pin, 8/72" for 9-pin }
  if Cfg.DPI >= 180 then
    SendBytes(EscFile, [27, Ord('3'), 24])   { ESC 3 n = n/180" }
  else
    SendBytes(EscFile, [27, Ord('3'), 8]);   { 8/72" for 9-pin }
end;

function EscDrvSend(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;
var
  Y, X: LongWord;
  Band: Integer;
  BandHeight: Integer;
  ColByte: Byte;
  ByteCount: Word;
  NL, NH: Byte;
  GfxMode: Byte;
  Row, Bit: Integer;
begin
  Result := False;
  if not EscOpen then Exit;

  if Cfg.DPI >= 180 then
  begin
    BandHeight := 24;  { 24-pin }
    GfxMode := 33;     { ESC * 33 = 360 DPI, 24-pin }
  end
  else
  begin
    BandHeight := 8;   { 9-pin }
    GfxMode := 0;      { ESC * 0 = 60 DPI single density }
  end;

  Y := 0;
  while Y < Page.Height do
  begin
    ByteCount := Page.Width;
    NL := ByteCount and $FF;
    NH := (ByteCount shr 8) and $FF;

    { Start graphics line: ESC * mode nL nH }
    SendBytes(EscFile, [27, Ord('*'), GfxMode, NL, NH]);

    { Send columns }
    for X := 0 to Page.Width - 1 do
    begin
      if BandHeight = 24 then
      begin
        { 24-pin: 3 bytes per column (24 pins) }
        for Band := 0 to 2 do
        begin
          ColByte := 0;
          for Bit := 0 to 7 do
          begin
            Row := Y + Band * 8 + Bit;
            if Row < LongInt(Page.Height) then
            begin
              if (Page.Mono[Row * Page.Stride + X div 8] and
                  ($80 shr (X and 7))) <> 0 then
                ColByte := ColByte or ($80 shr Bit);
            end;
          end;
          BlockWrite(EscFile, ColByte, 1);
        end;
      end
      else
      begin
        { 9-pin: 1 byte per column (8 pins) }
        ColByte := 0;
        for Bit := 0 to 7 do
        begin
          Row := Y + Bit;
          if Row < LongInt(Page.Height) then
          begin
            if (Page.Mono[Row * Page.Stride + X div 8] and
                ($80 shr (X and 7))) <> 0 then
              ColByte := ColByte or ($80 shr Bit);
          end;
        end;
        BlockWrite(EscFile, ColByte, 1);
      end;
    end;

    { Carriage return + line feed }
    SendBytes(EscFile, [13, 10]);

    Inc(Y, BandHeight);
  end;

  { Form feed }
  SendBytes(EscFile, [12]);
  Result := True;
end;

procedure EscDrvClose(var Cfg: TPrnConfig);
begin
  if EscOpen then begin Close(EscFile); EscOpen := False; end;
end;

procedure PrnEscPRegister;
begin
  PrnDrivers[pdEscP].Open := @EscDrvOpen;
  PrnDrivers[pdEscP].Send := @EscDrvSend;
  PrnDrivers[pdEscP].Close := @EscDrvClose;
  PrnDrivers[pdEscP].Name := 'ESC/P Dot-Matrix';
end;

end.
