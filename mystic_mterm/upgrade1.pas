{ ===========================================================================
  OpenOLMS — upgrade1.pas
  Upgrades OLMS.CFG + MESSAGES.CTL to Version 2000 format.
  GPLv3 — Copyright (C) 2026 verta1878, wrench

  Replaces original UPGRADE1.EXE. Converts older OLMS data files
  to the v2000 record layout. Safe: backs up originals first.

  Usage:
    upgrade1                     upgrade in current directory
    upgrade1 C:\OLMS             upgrade in specified directory
  =========================================================================== }

{$MODE OBJFPC}{$H-}
{$PACKRECORDS 1}

program upgrade1;

uses SysUtils, OL_Compat;

const
  VERSION = 'OpenOLMS Upgrade v1.0 — Config + Message Areas';
  OLMS_V2000 = 200;

var
  BasePath: String;

procedure BackupFile(const FN: String);
var
  BakName: String;
begin
  if not FileExists(FN) then Exit;
  BakName := FN + '.bak';
  if FileExists(BakName) then
  begin
    WriteLn('  WARNING: ', BakName, ' already exists, skipping backup');
    Exit;
  end;
  RenameFile(FN, BakName);
  WriteLn('  Backed up: ', ExtractFileName(FN), ' -> ', ExtractFileName(BakName));
end;

procedure UpgradeConfig;
var
  CfgFile: String;
  Cfg: TOLMSConfigRaw;
  F: File;
  FileSize: LongInt;
  Ver: Word;
begin
  CfgFile := BasePath + 'OLMS.CFG';
  WriteLn;
  WriteLn('--- OLMS.CFG ---');

  if not FileExists(CfgFile) then
  begin
    WriteLn('  Not found: ', CfgFile);
    WriteLn('  Creating new v2000 config...');
    FillChar(Cfg, SizeOf(Cfg), 0);
    Cfg.Data[0] := OLMS_V2000 and $FF;
    Cfg.Data[1] := (OLMS_V2000 shr 8) and $FF;
    { Set defaults }
    WriteTPStr(Cfg.Data[4], 30, 'My BBS');
    WriteTPStr(Cfg.Data[35], 30, 'SYSOP');
    WriteTPStr(Cfg.Data[846], 8, 'DEFAULT');
    AssignFile(F, CfgFile);
    Rewrite(F, 1);
    BlockWrite(F, Cfg, OLMS_CFG_SIZE);
    CloseFile(F);
    WriteLn('  Created: ', CfgFile, ' (', OLMS_CFG_SIZE, ' bytes)');
    Exit;
  end;

  { Read existing config }
  AssignFile(F, CfgFile);
  Reset(F, 1);
  FileSize := System.FileSize(F);
  FillChar(Cfg, SizeOf(Cfg), 0);
  if FileSize > OLMS_CFG_SIZE then FileSize := OLMS_CFG_SIZE;
  BlockRead(F, Cfg, FileSize);
  CloseFile(F);

  Ver := Cfg.Data[0] or (Cfg.Data[1] shl 8);
  WriteLn('  Current version: ', Ver);
  WriteLn('  File size: ', FileSize, ' bytes (v2000 = ', OLMS_CFG_SIZE, ')');

  if Ver >= OLMS_V2000 then
  begin
    if FileSize = OLMS_CFG_SIZE then
    begin
      WriteLn('  Already v2000 — no upgrade needed.');
      Exit;
    end;
    WriteLn('  Version OK but file size wrong — rewriting...');
  end
  else
    WriteLn('  Upgrading from v', Ver, ' to v2000...');

  { Backup original }
  BackupFile(CfgFile);

  { If the old file was smaller, the FillChar(0) already zeroed
    the new fields. Just update the version number. }
  Cfg.Data[0] := OLMS_V2000 and $FF;
  Cfg.Data[1] := (OLMS_V2000 shr 8) and $FF;

  { Set defaults for new fields if they're empty }
  if ReadTPStr(Cfg.Data[846], 8) = '' then
    WriteTPStr(Cfg.Data[846], 8, 'DEFAULT');

  { Write upgraded config }
  AssignFile(F, CfgFile);
  Rewrite(F, 1);
  BlockWrite(F, Cfg, OLMS_CFG_SIZE);
  CloseFile(F);

  WriteLn('  Upgraded to v2000 (', OLMS_CFG_SIZE, ' bytes)');
  WriteLn('  BBS Name: "', ReadTPStr(Cfg.Data[4], 30), '"');
  WriteLn('  Sysop:    "', ReadTPStr(Cfg.Data[35], 30), '"');
end;

procedure UpgradeMessageAreas;
var
  CtlFile: String;
  Areas: array[0..OLMS_MAX_AREAS-1] of TOLMSArea;
  F: File;
  FileSize: LongInt;
  OldCount, NewCount, I: Integer;
begin
  CtlFile := BasePath + 'MESSAGES.CTL';
  WriteLn;
  WriteLn('--- MESSAGES.CTL ---');

  if not FileExists(CtlFile) then
  begin
    WriteLn('  Not found: ', CtlFile);
    WriteLn('  Creating new empty area file...');
    FillChar(Areas, SizeOf(Areas), 0);
    AssignFile(F, CtlFile);
    Rewrite(F, 1);
    BlockWrite(F, Areas, OLMS_MAX_AREAS * OLMS_AREA_SIZE);
    CloseFile(F);
    WriteLn('  Created: ', CtlFile, ' (', OLMS_MAX_AREAS * OLMS_AREA_SIZE, ' bytes)');
    Exit;
  end;

  { Read existing areas }
  AssignFile(F, CtlFile);
  Reset(F, 1);
  FileSize := System.FileSize(F);
  FillChar(Areas, SizeOf(Areas), 0);
  OldCount := FileSize div OLMS_AREA_SIZE;
  if OldCount > OLMS_MAX_AREAS then OldCount := OLMS_MAX_AREAS;
  BlockRead(F, Areas, OldCount * OLMS_AREA_SIZE);
  CloseFile(F);

  WriteLn('  Current: ', OldCount, ' area slots (', FileSize, ' bytes)');

  { Count configured areas }
  NewCount := 0;
  for I := 0 to OldCount - 1 do
    if Areas[I].AreaTag <> '' then Inc(NewCount);
  WriteLn('  Active areas: ', NewCount);

  if (FileSize = OLMS_MAX_AREAS * OLMS_AREA_SIZE) then
  begin
    WriteLn('  Already correct size — no upgrade needed.');
    Exit;
  end;

  { Backup and rewrite with full 383 slots }
  BackupFile(CtlFile);

  AssignFile(F, CtlFile);
  Rewrite(F, 1);
  BlockWrite(F, Areas, OLMS_MAX_AREAS * OLMS_AREA_SIZE);
  CloseFile(F);

  WriteLn('  Upgraded: ', OLMS_MAX_AREAS, ' area slots (',
          OLMS_MAX_AREAS * OLMS_AREA_SIZE, ' bytes)');
  WriteLn('  Preserved ', NewCount, ' active areas');
end;

procedure UpgradeIndexFiles;
var
  F: File;
  Inf: TOLMSMsgInf;
  Idx: TOLMSUserIdx;
  FN: String;
begin
  WriteLn;
  WriteLn('--- Index Files ---');

  { MESSAGES.INF — create if missing }
  FN := BasePath + 'MESSAGES.INF';
  if not FileExists(FN) then
  begin
    FillChar(Inf, SizeOf(Inf), 0);
    AssignFile(F, FN);
    Rewrite(F, 1);
    BlockWrite(F, Inf, SizeOf(Inf));
    CloseFile(F);
    WriteLn('  Created: MESSAGES.INF (', SizeOf(Inf), ' bytes)');
  end
  else
    WriteLn('  MESSAGES.INF exists — OK');

  { USERS.IDX — create if missing }
  FN := BasePath + 'USERS.IDX';
  if not FileExists(FN) then
  begin
    FillChar(Idx, SizeOf(Idx), 0);
    AssignFile(F, FN);
    Rewrite(F, 1);
    BlockWrite(F, Idx, SizeOf(Idx));
    CloseFile(F);
    WriteLn('  Created: USERS.IDX (', SizeOf(Idx), ' bytes)');
  end
  else
    WriteLn('  USERS.IDX exists — OK');
end;

begin
  WriteLn(VERSION);
  WriteLn;

  if ParamCount >= 1 then
    BasePath := IncludeTrailingPathDelimiter(ParamStr(1))
  else
    BasePath := '';

  WriteLn('Directory: ', BasePath);
  if (BasePath <> '') and not DirectoryExists(BasePath) then
  begin
    WriteLn('ERROR: Directory not found: ', BasePath);
    Halt(1);
  end;

  UpgradeConfig;
  UpgradeMessageAreas;
  UpgradeIndexFiles;

  WriteLn;
  WriteLn('Upgrade complete.');
end.
