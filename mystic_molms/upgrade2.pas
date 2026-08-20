{ ===========================================================================
  OpenOLMS — upgrade2.pas
  Upgrades USERS.DAT to Version 2000 format.
  GPLv3 — Copyright (C) 2026 verta1878, wrench

  Replaces original UPGRADE2.EXE. Converts older user database
  to the v2000 record layout (478 bytes/record, 30 slots).
  Safe: backs up original first.

  Usage:
    upgrade2                     upgrade in current directory
    upgrade2 C:\OLMS             upgrade in specified directory
  =========================================================================== }

{$MODE OBJFPC}{$H-}
{$PACKRECORDS 1}

program upgrade2;

uses SysUtils, OL_Compat;

const
  VERSION = 'OpenOLMS Upgrade v1.0 — User Database';

var
  BasePath: String;

procedure BackupFile(const FN: String);
var BakName: String;
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

procedure UpgradeUsers;
var
  UsrFile: String;
  Users: array[0..OLMS_MAX_USERS-1] of TOLMSUser;
  F: File;
  FileSize: LongInt;
  OldRecSize, OldCount, I, ActiveCount: Integer;
begin
  UsrFile := BasePath + 'USERS.DAT';
  WriteLn;
  WriteLn('--- USERS.DAT ---');

  if not FileExists(UsrFile) then
  begin
    WriteLn('  Not found: ', UsrFile);
    WriteLn('  Creating new empty user database...');
    FillChar(Users, SizeOf(Users), 0);
    AssignFile(F, UsrFile);
    Rewrite(F, 1);
    BlockWrite(F, Users, OLMS_MAX_USERS * OLMS_USER_SIZE);
    CloseFile(F);
    WriteLn('  Created: ', UsrFile, ' (',
            OLMS_MAX_USERS * OLMS_USER_SIZE, ' bytes, ',
            OLMS_MAX_USERS, ' slots)');
    Exit;
  end;

  { Read existing file }
  AssignFile(F, UsrFile);
  Reset(F, 1);
  FileSize := System.FileSize(F);

  { Detect old record size }
  if FileSize = OLMS_MAX_USERS * OLMS_USER_SIZE then
  begin
    { Already v2000 format }
    FillChar(Users, SizeOf(Users), 0);
    BlockRead(F, Users, OLMS_MAX_USERS * OLMS_USER_SIZE);
    CloseFile(F);

    ActiveCount := 0;
    for I := 0 to OLMS_MAX_USERS - 1 do
      if Users[I].UserName <> '' then Inc(ActiveCount);

    WriteLn('  Already v2000 format (', OLMS_USER_SIZE, ' bytes/record)');
    WriteLn('  ', ActiveCount, ' active users, ', OLMS_MAX_USERS, ' slots');
    WriteLn('  No upgrade needed.');
    Exit;
  end;

  WriteLn('  File size: ', FileSize, ' bytes');
  WriteLn('  Expected:  ', OLMS_MAX_USERS * OLMS_USER_SIZE, ' bytes');

  { Try to detect old record size by finding common divisors }
  OldRecSize := 0;
  for I := 50 to 1000 do
    if FileSize mod I = 0 then
    begin
      OldCount := FileSize div I;
      if (OldCount >= 1) and (OldCount <= 100) then
      begin
        OldRecSize := I;
        Break;
      end;
    end;

  if OldRecSize = 0 then
  begin
    WriteLn('  ERROR: Cannot determine old record size.');
    WriteLn('  File may be corrupt. Manual recovery needed.');
    CloseFile(F);
    Halt(1);
  end;

  OldCount := FileSize div OldRecSize;
  WriteLn('  Detected: ', OldCount, ' records x ', OldRecSize, ' bytes');

  { Read old records into raw buffer, then copy common fields }
  FillChar(Users, SizeOf(Users), 0);

  if OldRecSize <= OLMS_USER_SIZE then
  begin
    { Old record is smaller — read each into the start of the new record.
      Fields at the same offsets are preserved. New fields default to 0. }
    Seek(F, 0);
    for I := 0 to OldCount - 1 do
    begin
      if I >= OLMS_MAX_USERS then Break;
      BlockRead(F, Users[I], OldRecSize);
    end;
  end
  else
  begin
    { Old record is LARGER — truncate each to v2000 size.
      Read the first OLMS_USER_SIZE bytes of each old record. }
    Seek(F, 0);
    for I := 0 to OldCount - 1 do
    begin
      if I >= OLMS_MAX_USERS then Break;
      BlockRead(F, Users[I], OLMS_USER_SIZE);
      { Skip remaining bytes of the old record }
      Seek(F, LongInt(I + 1) * OldRecSize);
    end;
  end;
  CloseFile(F);

  { Count active users }
  ActiveCount := 0;
  for I := 0 to OLMS_MAX_USERS - 1 do
    if Users[I].UserName <> '' then
    begin
      Inc(ActiveCount);
      WriteLn('  User ', I, ': "', Users[I].UserName, '"',
              ' Last: ', Users[I].LastDate);
    end;

  WriteLn('  Active users: ', ActiveCount);

  { Backup original }
  BackupFile(UsrFile);

  { Write upgraded database }
  AssignFile(F, UsrFile);
  Rewrite(F, 1);
  BlockWrite(F, Users, OLMS_MAX_USERS * OLMS_USER_SIZE);
  CloseFile(F);

  WriteLn('  Upgraded: ', OLMS_MAX_USERS, ' slots x ',
          OLMS_USER_SIZE, ' bytes = ',
          OLMS_MAX_USERS * OLMS_USER_SIZE, ' bytes');
  WriteLn('  Preserved ', ActiveCount, ' users');
end;

procedure UpgradeScreens;
var
  ScrFile: String;
  FileSize: LongInt;
  F: File;
begin
  ScrFile := BasePath + 'SCREENS.DAT';
  WriteLn;
  WriteLn('--- SCREENS.DAT ---');

  if not FileExists(ScrFile) then
  begin
    WriteLn('  Not found — will be created by CONFIG on first run.');
    Exit;
  end;

  AssignFile(F, ScrFile);
  Reset(F, 1);
  FileSize := System.FileSize(F);
  CloseFile(F);

  WriteLn('  Size: ', FileSize, ' bytes');
  WriteLn('  SCREENS.DAT format is version-independent — no upgrade needed.');
end;

procedure CreateWorkDirs;
var Dir: String;
begin
  WriteLn;
  WriteLn('--- Work Directories ---');

  Dir := BasePath + 'WORK1';
  if not DirectoryExists(Dir) then
  begin
    CreateDir(Dir);
    WriteLn('  Created: WORK1');
  end
  else
    WriteLn('  WORK1 exists — OK');

  Dir := BasePath + 'WORK2';
  if not DirectoryExists(Dir) then
  begin
    CreateDir(Dir);
    WriteLn('  Created: WORK2');
  end
  else
    WriteLn('  WORK2 exists — OK');
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

  UpgradeUsers;
  UpgradeScreens;
  CreateWorkDirs;

  WriteLn;
  WriteLn('Upgrade complete.');
end.
