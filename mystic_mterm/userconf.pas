{ ===========================================================================
  OpenOLMS — userconf.pas
  User self-configuration (replaces USERCONF.EXE)
  GPLv3 — Copyright (C) 2026 verta1878, wrench

  Lets a user change their OLMS preferences:
    - Default archiver (ZIP, ARJ, LHA, RAR, PAK, ARC)
    - Default protocol (Xmodem, Ymodem, Zmodem)
    - Message area selection (which areas to scan)
    - Keyword filters
    - Tagline preferences

  Reads/writes USERS.DAT using the binary-compatible packed records
  from OL_Compat.pas. Drop-in replacement for original USERCONF.EXE.

  Usage:
    userconf USERS.DAT USERNAME
    userconf USERS.DAT 0          (by record number)
  =========================================================================== }

{$MODE OBJFPC}{$H-}
{$PACKRECORDS 1}

program userconf;

uses SysUtils, CRT, OL_Compat;

const
  VERSION = 'OpenOLMS UserConf v1.0';
  ARCHIVER_NAMES: array[0..5] of String[10] = (
    'ARJ', 'LHA', 'ZIP', 'ARC', 'PAK', 'RAR');
  PROTOCOL_NAMES: array[0..2] of String[10] = (
    'Xmodem', 'Ymodem', 'Zmodem');

var
  Users: array[0..OLMS_MAX_USERS-1] of TOLMSUser;
  Areas: array[0..OLMS_MAX_AREAS-1] of TOLMSArea;
  AreaCount: Integer;
  UserCount: Integer;
  UserIdx: Integer;
  FileName: String;
  Modified: Boolean;

function Sum(var Flags: array of Byte): Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to High(Flags) do
    if Flags[I] <> 0 then Inc(Result);
end;

procedure LoadUsers;
var F: File;
begin
  UserCount := 0;
  if not FileExists(FileName) then
  begin
    WriteLn('ERROR: ', FileName, ' not found.');
    Halt(1);
  end;
  AssignFile(F, FileName);
  Reset(F, 1);
  UserCount := FileSize(F) div OLMS_USER_SIZE;
  if UserCount > OLMS_MAX_USERS then UserCount := OLMS_MAX_USERS;
  BlockRead(F, Users, UserCount * OLMS_USER_SIZE);
  CloseFile(F);
end;

procedure LoadAreas;
var
  F: File;
  CtlFile: String;
begin
  AreaCount := 0;
  FillChar(Areas, SizeOf(Areas), 0);
  { Try MESSAGES.CTL in same directory as USERS.DAT }
  CtlFile := ExtractFilePath(FileName) + 'MESSAGES.CTL';
  if not FileExists(CtlFile) then Exit;
  AssignFile(F, CtlFile);
  Reset(F, 1);
  AreaCount := FileSize(F) div OLMS_AREA_SIZE;
  if AreaCount > OLMS_MAX_AREAS then AreaCount := OLMS_MAX_AREAS;
  BlockRead(F, Areas, AreaCount * OLMS_AREA_SIZE);
  CloseFile(F);
end;

procedure SaveUsers;
var F: File;
begin
  AssignFile(F, FileName);
  Rewrite(F, 1);
  BlockWrite(F, Users, UserCount * OLMS_USER_SIZE);
  CloseFile(F);
end;

function FindUser(const Name: String): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to UserCount - 1 do
    if UpCase(Users[I].UserName) = UpCase(Name) then
    begin
      Result := I;
      Exit;
    end;
end;

procedure DrawHeader;
begin
  TextBackground(LightGray); TextColor(Black);
  GotoXY(1, 1); ClrEol;
  Write(' ', VERSION, ' -- User: ', Users[UserIdx].UserName);
  if Modified then begin TextColor(Red); Write(' [Modified]'); end;
  TextBackground(Black); TextColor(LightGray);
end;

procedure DrawStatus;
begin
  TextBackground(Cyan); TextColor(Black);
  GotoXY(1, 24); ClrEol;
  Write(' S:Save  Q:Quit  Up/Down:Navigate  Enter:Toggle/Edit  Space:Toggle');
  TextBackground(Black); TextColor(LightGray);
end;

procedure ShowArchiverMenu;
var I, Sel: Integer; K: Char;
begin
  Sel := Users[UserIdx].ArchiverSel[0];
  if Sel > 5 then Sel := 0;
  repeat
    ClrScr; DrawHeader;
    GotoXY(3, 3); TextColor(Yellow);
    WriteLn('Default Archiver:');
    WriteLn;
    for I := 0 to 5 do
    begin
      GotoXY(5, 5 + I);
      if I = Sel then begin TextColor(White); Write('> '); end
      else begin TextColor(LightGray); Write('  '); end;
      WriteLn(ARCHIVER_NAMES[I]);
    end;
    TextColor(LightGray);
    GotoXY(3, 13); WriteLn('Press Enter to select, Esc to cancel');
    DrawStatus;

    K := ReadKey;
    case K of
      #0: begin
            K := ReadKey;
            case K of
              #72: if Sel > 0 then Dec(Sel);     { Up }
              #80: if Sel < 5 then Inc(Sel);     { Down }
            end;
          end;
      #13: begin
             Users[UserIdx].ArchiverSel[0] := Sel;
             Modified := True;
             Exit;
           end;
      #27: Exit;
    end;
  until False;
end;

procedure ShowProtocolMenu;
var I, Sel: Integer; K: Char;
begin
  Sel := Users[UserIdx].ArchiverSel[1];
  if Sel > 2 then Sel := 2;
  repeat
    ClrScr; DrawHeader;
    GotoXY(3, 3); TextColor(Yellow);
    WriteLn('Default Protocol:');
    WriteLn;
    for I := 0 to 2 do
    begin
      GotoXY(5, 5 + I);
      if I = Sel then begin TextColor(White); Write('> '); end
      else begin TextColor(LightGray); Write('  '); end;
      WriteLn(PROTOCOL_NAMES[I]);
    end;
    TextColor(LightGray);
    GotoXY(3, 10); WriteLn('Press Enter to select, Esc to cancel');
    DrawStatus;

    K := ReadKey;
    case K of
      #0: begin
            K := ReadKey;
            case K of
              #72: if Sel > 0 then Dec(Sel);
              #80: if Sel < 2 then Inc(Sel);
            end;
          end;
      #13: begin
             Users[UserIdx].ArchiverSel[1] := Sel;
             Modified := True;
             Exit;
           end;
      #27: Exit;
    end;
  until False;
end;

procedure ShowAreaSelection;
var
  TopArea, Sel, I, Row: Integer;
  K: Char;
  MaxVisible: Integer;
begin
  TopArea := 0;
  Sel := 0;
  MaxVisible := 18;
  repeat
    ClrScr; DrawHeader;
    GotoXY(3, 3); TextColor(Yellow);
    WriteLn('Message Area Selection (Space to toggle, Enter to finish):');
    WriteLn;

    for I := 0 to MaxVisible - 1 do
    begin
      Row := TopArea + I;
      if Row >= OLMS_MAX_AREAS then Break;
      GotoXY(3, 5 + I);
      if Row = Sel then TextColor(White) else TextColor(LightGray);
      if Users[UserIdx].BoolFlags[Row] <> 0 then
        Write('[X] ')
      else
        Write('[ ] ');
      if (Row < AreaCount) and (Areas[Row].AreaTag <> '') then
        Write(Row:3, ' ', Areas[Row].AreaTag)
      else
        Write(Row:3, ' (empty)');
    end;
    DrawStatus;

    K := ReadKey;
    case K of
      #0: begin
            K := ReadKey;
            case K of
              #72: begin { Up }
                     if Sel > 0 then Dec(Sel);
                     if Sel < TopArea then TopArea := Sel;
                   end;
              #80: begin { Down }
                     if Sel < OLMS_MAX_AREAS - 1 then Inc(Sel);
                     if Sel >= TopArea + MaxVisible then Inc(TopArea);
                   end;
              #73: begin { PgUp }
                     Dec(Sel, MaxVisible);
                     if Sel < 0 then Sel := 0;
                     TopArea := Sel;
                   end;
              #81: begin { PgDn }
                     Inc(Sel, MaxVisible);
                     if Sel >= OLMS_MAX_AREAS then Sel := OLMS_MAX_AREAS - 1;
                     TopArea := Sel - MaxVisible + 1;
                     if TopArea < 0 then TopArea := 0;
                   end;
            end;
          end;
      ' ': begin
             if Users[UserIdx].BoolFlags[Sel] <> 0 then
               Users[UserIdx].BoolFlags[Sel] := 0
             else
               Users[UserIdx].BoolFlags[Sel] := 1;
             Modified := True;
           end;
      #13, #27: Exit;
    end;
  until False;
end;

procedure ShowMainMenu;
var K: Char; Sel: Integer;
begin
  Sel := 0;
  repeat
    ClrScr; DrawHeader;
    GotoXY(3, 3); TextColor(Yellow);
    WriteLn('User Configuration:');
    WriteLn;

    GotoXY(5, 5);
    if Sel = 0 then TextColor(White) else TextColor(LightGray);
    if Users[UserIdx].ArchiverSel[0] <= 5 then
      WriteLn('A  Default Archiver    : ', ARCHIVER_NAMES[Users[UserIdx].ArchiverSel[0]])
    else
      WriteLn('A  Default Archiver    : Unknown (', Users[UserIdx].ArchiverSel[0], ')');

    GotoXY(5, 6);
    if Sel = 1 then TextColor(White) else TextColor(LightGray);
    Write('P  Default Protocol    : ');
    if Users[UserIdx].ArchiverSel[1] <= 2 then
      WriteLn(PROTOCOL_NAMES[Users[UserIdx].ArchiverSel[1]])
    else
      WriteLn('Unknown');

    GotoXY(5, 7);
    if Sel = 2 then TextColor(White) else TextColor(LightGray);
    WriteLn('M  Message Area Select : [', Sum(Users[UserIdx].BoolFlags), ' areas enabled]');

    GotoXY(5, 9);
    TextColor(LightGray);
    WriteLn('Last login: ', Users[UserIdx].LastDate, ' ', Users[UserIdx].LastTime);
    WriteLn;

    GotoXY(5, 12);
    WriteLn('S  Save changes');
    GotoXY(5, 13);
    WriteLn('Q  Quit');

    DrawStatus;

    K := UpCase(ReadKey);
    case K of
      'A': ShowArchiverMenu;
      'P': ShowProtocolMenu;
      'M': ShowAreaSelection;
      'S': begin SaveUsers; Modified := False; end;
      'Q': begin
             if Modified then
             begin
               GotoXY(5, 20); TextColor(Yellow);
               Write('Save changes? (Y/N) ');
               K := UpCase(ReadKey);
               if K = 'Y' then SaveUsers;
             end;
             Exit;
           end;
      #0: begin
            K := ReadKey;
            case K of
              #72: if Sel > 0 then Dec(Sel);
              #80: if Sel < 2 then Inc(Sel);
            end;
          end;
      #13: case Sel of
             0: ShowArchiverMenu;
             1: ShowProtocolMenu;
             2: ShowAreaSelection;
           end;
    end;
  until False;
end;


begin
  if ParamCount < 2 then
  begin
    WriteLn(VERSION);
    WriteLn('Usage: userconf USERS.DAT USERNAME');
    WriteLn('       userconf USERS.DAT 0        (by record number)');
    Halt(0);
  end;

  FileName := ParamStr(1);
  LoadUsers;
  LoadAreas;

  { Find user by name or number }
  UserIdx := StrToIntDef(ParamStr(2), -1);
  if UserIdx < 0 then
    UserIdx := FindUser(ParamStr(2));
  if (UserIdx < 0) or (UserIdx >= UserCount) then
  begin
    WriteLn('ERROR: User "', ParamStr(2), '" not found.');
    Halt(1);
  end;

  Modified := False;
  ShowMainMenu;
  ClrScr;
  WriteLn('UserConf exited.');
end.
