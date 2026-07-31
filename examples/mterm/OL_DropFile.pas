{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Clean-room reimplementation from published documentation.
  Pending licence — with permission from Peter Rocca.
  =========================================================================== }

unit OL_DropFile;
{ ===========================================================================
  OpenOLMS — BBS drop file parser
  ---------------------------------------------------------------------------
  Every BBS door reads a "drop file" to learn about the current caller:
  who they are, what COM port they're on, how much time they have, and
  their security level. Three formats exist:

    DORINFO1.DEF  — the most portable, works with most BBS software
    DOOR.SYS      — PCBoard-originated, widely adopted
    EXITINFO.BBS  — RemoteAccess specific

  OpenOLMS reads DORINFO1.DEF first (like the original OLMS), then
  falls back to DOOR.SYS if not found. EXITINFO.BBS is Phase 2.

  The session info is used for:
  - Addressing the COM port (for file transfers via DSZ/etc)
  - Enforcing time limits
  - Personalizing the QWK packet (user name in CONTROL.DAT)
  - Security-based area filtering
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

type
  TDropFileType = (dfNone, dfDorInfo, dfDoorSys, dfExitInfo);

  { Session info extracted from the drop file.
    Every field has a sane default so the door can run in local
    mode (no drop file) for testing. }
  TSessionInfo = record
    DropType    : TDropFileType;
    BBSName     : String;
    SysopFirst  : String;
    SysopLast   : String;
    ComPort     : Integer;    { 0 = local mode }
    BaudRate    : LongInt;
    UserFirst   : String;
    UserLast    : String;
    UserName    : String;     { combined first + last }
    UserCity    : String;
    SecurityLvl : Integer;
    TimeLeft    : Integer;    { minutes remaining }
    ANSI        : Boolean;    { user has ANSI capability }
    NodeNum     : Integer;    { node number (multinode BBS) }
  end;

{ Try to find and parse a drop file. Searches in order:
  1. DORINFO1.DEF (or DORINFOx.DEF where x = node number)
  2. DOOR.SYS
  Returns True if a drop file was found and parsed. }
function LoadDropFile(const Path: String; var Info: TSessionInfo): Boolean;

{ Parse DORINFO1.DEF specifically }
function ParseDorInfo(const Filename: String; var Info: TSessionInfo): Boolean;

{ Parse DOOR.SYS specifically }
function ParseDoorSys(const Filename: String; var Info: TSessionInfo): Boolean;

{ Initialize session with local-mode defaults }
procedure DefaultSession(var Info: TSessionInfo);

implementation

uses SysUtils;

procedure DefaultSession(var Info: TSessionInfo);
begin
  Info.DropType    := dfNone;
  Info.BBSName     := 'Local';
  Info.SysopFirst  := 'Sysop';
  Info.SysopLast   := '';
  Info.ComPort     := 0;
  Info.BaudRate    := 0;
  Info.UserFirst   := 'Local';
  Info.UserLast    := 'User';
  Info.UserName    := 'Local User';
  Info.UserCity    := '';
  Info.SecurityLvl := 255;
  Info.TimeLeft    := 60;
  Info.ANSI        := True;
  Info.NodeNum     := 1;
end;

function ReadLine(var F: Text): String;
begin
  if not EOF(F) then
    ReadLn(F, Result)
  else
    Result := '';
  Result := Trim(Result);
end;

function ParseDorInfo(const Filename: String; var Info: TSessionInfo): Boolean;
{ DORINFO1.DEF format (one value per line):
    Line 1:  BBS name
    Line 2:  Sysop first name
    Line 3:  Sysop last name
    Line 4:  COM port (COM0 = local, COM1, COM2, etc)
    Line 5:  Baud rate (0 = local)
    Line 6:  unused (0)
    Line 7:  User first name
    Line 8:  User last name
    Line 9:  User city
    Line 10: ANSI (1=yes, 0=no)
    Line 11: Security level
    Line 12: Time remaining (minutes) }
var
  F: Text;
  S: String;
begin
  Result := False;
  if not FileExists(Filename) then Exit;

  AssignFile(F, Filename);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then Exit;

  try
    Info.DropType   := dfDorInfo;
    Info.BBSName    := ReadLine(F);
    Info.SysopFirst := ReadLine(F);
    Info.SysopLast  := ReadLine(F);

    { COM port: "COM0" = local, "COM1" = 1, etc }
    S := UpperCase(ReadLine(F));
    if (Length(S) >= 4) and (Copy(S, 1, 3) = 'COM') then
      Info.ComPort := StrToIntDef(Copy(S, 4, Length(S) - 3), 0)
    else
      Info.ComPort := 0;

    Info.BaudRate    := StrToIntDef(ReadLine(F), 0);
    ReadLine(F);   { skip unused line 6 }
    Info.UserFirst   := ReadLine(F);
    Info.UserLast    := ReadLine(F);
    Info.UserName    := Trim(Info.UserFirst + ' ' + Info.UserLast);
    Info.UserCity    := ReadLine(F);

    { ANSI: 1 = yes, 0 = no. Some doors write GR (graphics) }
    S := UpperCase(ReadLine(F));
    Info.ANSI := (S = '1') or (S = 'GR') or (S = 'YES');

    Info.SecurityLvl := StrToIntDef(ReadLine(F), 0);
    Info.TimeLeft    := StrToIntDef(ReadLine(F), 60);
    Info.NodeNum     := 1;

    Result := True;
  finally
    CloseFile(F);
  end;
end;

function ParseDoorSys(const Filename: String; var Info: TSessionInfo): Boolean;
{ DOOR.SYS format (PCBoard-style, one value per line):
    Line 1:  COM port ("COM1:", "COM0:" = local)
    Line 2:  Baud rate
    Line 3:  Data bits (8)
    Line 4:  Node number
    Line 5:  DTE rate
    Line 6:  Screen display (Y/N)
    Line 7:  Printer (Y/N)
    Line 8:  Page bell (Y/N)
    Line 9:  Caller alarm (Y/N)
    Line 10: User name
    Line 11: User city
    Line 12: Home phone
    Line 13: Work phone
    Line 14: Password
    Line 15: Security level
    Line 16: Number of times on
    Line 17: Last date on
    Line 18: Seconds remaining
    Line 19: Time remaining (minutes)
    Line 20: GR (graphics) / NG (no graphics) / 7E (7-bit) }
var
  F: Text;
  S: String;
  I: Integer;
begin
  Result := False;
  if not FileExists(Filename) then Exit;

  AssignFile(F, Filename);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then Exit;

  try
    Info.DropType := dfDoorSys;

    { Line 1: COM port }
    S := UpperCase(ReadLine(F));
    if (Length(S) >= 4) and (Copy(S, 1, 3) = 'COM') then
      Info.ComPort := StrToIntDef(Copy(S, 4, 1), 0)
    else
      Info.ComPort := 0;

    Info.BaudRate := StrToIntDef(ReadLine(F), 0);
    ReadLine(F);   { data bits }
    Info.NodeNum := StrToIntDef(ReadLine(F), 1);

    { skip lines 5-9 }
    for I := 5 to 9 do ReadLine(F);

    Info.UserName := ReadLine(F);   { line 10 }
    { Split name into first/last }
    I := Pos(' ', Info.UserName);
    if I > 0 then
    begin
      Info.UserFirst := Copy(Info.UserName, 1, I - 1);
      Info.UserLast  := Copy(Info.UserName, I + 1, Length(Info.UserName));
    end else begin
      Info.UserFirst := Info.UserName;
      Info.UserLast  := '';
    end;

    Info.UserCity := ReadLine(F);   { line 11 }

    { skip lines 12-14 }
    for I := 12 to 14 do ReadLine(F);

    Info.SecurityLvl := StrToIntDef(ReadLine(F), 0);   { line 15 }

    { skip lines 16-18 }
    for I := 16 to 18 do ReadLine(F);

    Info.TimeLeft := StrToIntDef(ReadLine(F), 60);   { line 19 }

    { Line 20: graphics mode }
    S := UpperCase(ReadLine(F));
    Info.ANSI := (S = 'GR') or (S = 'Y');

    Result := True;
  finally
    CloseFile(F);
  end;
end;

function LoadDropFile(const Path: String; var Info: TSessionInfo): Boolean;
var
  SearchPath: String;
begin
  DefaultSession(Info);
  SearchPath := IncludeTrailingPathDelimiter(Path);

  { Try DORINFO1.DEF first — most portable }
  if ParseDorInfo(SearchPath + 'DORINFO1.DEF', Info) then
  begin
    Result := True;
    Exit;
  end;

  { Try DOOR.SYS }
  if ParseDoorSys(SearchPath + 'DOOR.SYS', Info) then
  begin
    Result := True;
    Exit;
  end;

  { No drop file found — local mode }
  Result := False;
end;

end.
