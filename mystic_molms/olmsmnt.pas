{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  GPLv3 — Copyright (C) 2026 verta1878, sysop/0, wrench, kiddo, evga.
  Clean-room reimplementation. No original source code used.
  =========================================================================== }

program olmsmnt;
{ ===========================================================================
  OpenOLMS — maintenance utility (replaces MAINTAIN.EXE)
  ---------------------------------------------------------------------------
  From OLMS.DOC: command-line maintenance operations.

    MAINTAIN /P      — pack/purge old user records
    MAINTAIN /L      — list all users and their settings
    MAINTAIN /U name — delete a specific user
    MAINTAIN /R      — rebuild MESSAGES.CTL from the BBS area list

  Runs non-interactively, suitable for batch files and cron.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

uses
  SysUtils, OL_Config, OL_Users, OL_MsgCtl;

function IfThen(Cond: Boolean; const T, F: String): String;
begin if Cond then Result := T else Result := F; end;

const
  VERSION = 'OpenOLMS Maintain v1.0';

procedure ShowHelp;
begin
  WriteLn(VERSION);
  WriteLn;
  WriteLn('Usage:');
  WriteLn('  olmsmnt /P           purge inactive users (>90 days)');
  WriteLn('  olmsmnt /P=DAYS      purge users inactive for DAYS');
  WriteLn('  olmsmnt /L           list all users');
  WriteLn('  olmsmnt /U "name"    delete a specific user');
  WriteLn('  olmsmnt /R           rebuild MESSAGES.CTL');
  WriteLn('  olmsmnt /S           show statistics');
  WriteLn;
  WriteLn('Run from the OLMS directory.');
end;

procedure DoListUsers;
var
  Cfg: TOLMSConfig;
begin
  OLMSDefaultConfig(Cfg);
  OLMSLoadConfig('OLMS.CFG', Cfg);

  WriteLn(VERSION);
  WriteLn('BBS: ', Cfg.BBSName);
  WriteLn;
  WriteLn('User list from USERS.DAT:');
  WriteLn;

  if not FileExists('USERS.DAT') then
  begin
    WriteLn('  USERS.DAT not found.');
    Exit;
  end;

  { TODO: read USERS.DAT binary format and list users.
    For now, report that the file exists. }
  WriteLn('  USERS.DAT found.');
end;

procedure DoShowStats;
var
  Cfg: TOLMSConfig;
  Areas: TMsgAreaList;
  I: Integer;
begin
  OLMSDefaultConfig(Cfg);
  OLMSLoadConfig('OLMS.CFG', Cfg);

  WriteLn(VERSION);
  WriteLn;
  WriteLn('BBS Name:     ', Cfg.BBSName);
  WriteLn('Sysop:        ', Cfg.SysopName);
  WriteLn('MsgBase Path: ', Cfg.MsgBasePath);
  WriteLn('MsgBase Type: ', IfThen(Cfg.MsgBaseFormat = 0, 'Hudson', 'JAM'));
  WriteLn;

  if LoadMsgCtl('MESSAGES.CTL', Areas) then
  begin
    WriteLn('Configured areas: ', Length(Areas));
    WriteLn;
    WriteLn('  # Area Name                        Type   Flags');
    WriteLn('  - --------------------------------  -----  -----');
    for I := 0 to High(Areas) do
      WriteLn(Format('  %3d %-34s %s    $%04x', [
        Areas[I].AreaNum,
        Areas[I].Name,
        IfThen(Areas[I].BaseType = 0, 'HMB', 'JAM'),
        Areas[I].Flags]));
  end
  else
    WriteLn('MESSAGES.CTL not found.');
end;

var
  I: Integer;
  Arg: String;
begin
  if ParamCount = 0 then
  begin
    ShowHelp;
    Halt(0);
  end;

  for I := 1 to ParamCount do
  begin
    Arg := UpperCase(ParamStr(I));

    if Arg = '/L' then
      DoListUsers
    else if Arg = '/S' then
      DoShowStats
    else if (Arg = '/P') or (Copy(Arg, 1, 3) = '/P=') then
      WriteLn('Purge: not yet implemented.')
    else if Arg = '/R' then
      WriteLn('Rebuild: not yet implemented.')
    else if (Arg = '/?') or (Arg = '-H') then
      ShowHelp
    else
      WriteLn('Unknown option: ', ParamStr(I));
  end;
end.
