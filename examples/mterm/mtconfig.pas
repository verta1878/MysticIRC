{$MODE OBJFPC}
{$H+}
unit mtconfig;
{ mterm settings — persistent configuration

  Copyright (C) 2026 FPC264IRC Contributors
  License: GPLv3 }

interface

uses Objects, Drivers, Views, Dialogs, MsgBox;

type
  TMTermConfig = record
    TermType: Byte;        { 0=ANSI, 1=RIP, 2=Auto }
    LocalEcho: Boolean;
    ScrollBack: Word;      { lines }
    Baud: LongInt;
    ComPort: Byte;
    InitStr: String[40];
    DownloadPath: String[80];
    CapturePath: String[80];
    StripHigh: Boolean;
    Wrap: Boolean;
    CRtoCRLF: Boolean;
  end;

var
  Config: TMTermConfig;

procedure ShowSettings;
procedure LoadConfig;
procedure SaveConfig;

implementation

uses SysUtils, App;

const
  ConfigFile = 'mterm.cfg';

procedure LoadConfig;
var F: File of TMTermConfig;
begin
  FillChar(Config, SizeOf(Config), 0);
  Config.TermType := 2;      { Auto-detect }
  Config.LocalEcho := False;
  Config.ScrollBack := 1000;
  Config.Baud := 9600;
  Config.ComPort := 0;
  Config.InitStr := 'ATZ';
  Config.DownloadPath := '.';
  Config.CapturePath := '.';
  Config.Wrap := True;
  Config.CRtoCRLF := True;

  if FileExists(ConfigFile) then begin
    Assign(F, ConfigFile);
    Reset(F);
    if not EOF(F) then Read(F, Config);
    Close(F);
  end;
end;

procedure SaveConfig;
var F: File of TMTermConfig;
begin
  Assign(F, ConfigFile);
  Rewrite(F);
  Write(F, Config);
  Close(F);
end;

procedure ShowSettings;
var
  D: PDialog;
  s: String;
  R: TRect;
  Cmd: Word;
begin
  R.Assign(10, 3, 70, 20);
  D := New(PDialog, Init(R, 'mterm Settings'));

  R.Assign(3, 2, 55, 3);
  s := 'Auto';
  if Config.TermType = 0 then s := 'ANSI'
  else if Config.TermType = 1 then s := 'RIP';
  D^.Insert(New(PStaticText, Init(R, 'Terminal: ' + s)));

  R.Assign(3, 3, 55, 4);
  D^.Insert(New(PStaticText, Init(R,
    'Scrollback: ' + IntToStr(Config.ScrollBack) + ' lines')));

  R.Assign(3, 4, 55, 5);
  D^.Insert(New(PStaticText, Init(R,
    'Baud: ' + IntToStr(Config.Baud) + '  COM' + IntToStr(Config.ComPort + 1))));

  R.Assign(3, 5, 55, 6);
  D^.Insert(New(PStaticText, Init(R,
    'Init: ' + Config.InitStr)));

  R.Assign(3, 6, 55, 7);
  D^.Insert(New(PStaticText, Init(R,
    'Download: ' + Config.DownloadPath)));

  R.Assign(3, 8, 55, 9);
  D^.Insert(New(PStaticText, Init(R,
    'Local echo: ' + BoolToStr(Config.LocalEcho, 'ON', 'OFF') +
    '  Wrap: ' + BoolToStr(Config.Wrap, 'ON', 'OFF'))));

  R.Assign(20, 13, 35, 15);
  D^.Insert(New(PButton, Init(R, '~O~K', cmOK, bfDefault)));

  Cmd := Desktop^.ExecView(D);
  Dispose(D, Done);
end;

end.
