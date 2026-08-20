{ RETIRED — moved to mdl/m_door.pas (2026-08-19) }
{ pcbdrop.pas — Drop file reader for PCBoard/door programs.
  Reads PCBOARD.SYS, DOOR.SYS, and DORINFO1.DEF.
  Standalone — no Mystic BBS dependency.

  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench, hexadecimal. }
{$H+}
Unit pcbdrop;

Interface

Type
  TDropFileType = (dfNone, dfPCBoardSys, dfDoorSys, dfDorInfo);

  TDropInfo = Record
    DropType : TDropFileType;
    { Connection }
    ComPort  : Byte;     { 0=local, 1-4=COM }
    BaudRate : LongInt;
    { User }
    UserName : String[40];
    UserFirst: String[20];
    UserLast : String[20];
    Location : String[30];
    { Session }
    TimeLeft : Integer;   { minutes remaining }
    NodeNum  : Byte;
    ANSIMode : Boolean;
    RIPMode  : Boolean;
    { Security }
    SecLevel : Word;
    SysOpName: String[40];
  End;

Function  DetectDropFile(Const Path: String): TDropFileType;
Function  ReadDropFile(Const Path: String; Var Info: TDropInfo): Boolean;
Function  ReadPCBoardSys(Const FN: String; Var Info: TDropInfo): Boolean;
Function  ReadDoorSys(Const FN: String; Var Info: TDropInfo): Boolean;
Function  ReadDorInfo(Const FN: String; Var Info: TDropInfo): Boolean;

Implementation

Uses SysUtils;

Procedure InitDropInfo(Var Info: TDropInfo);
Begin
  FillChar(Info, SizeOf(Info), 0);
  Info.DropType := dfNone;
  Info.BaudRate := 0;
  Info.ComPort  := 0;
  Info.TimeLeft := 60;
  Info.ANSIMode := True;
  Info.NodeNum  := 1;
End;

Function ReadLine(Var F: Text): String;
Var S: String;
Begin
  If EOF(F) Then Begin Result := ''; Exit; End;
  ReadLn(F, S);
  { Strip CR if present (DOS files) }
  While (Length(S) > 0) and (S[Length(S)] in [#13, #10]) Do
    SetLength(S, Length(S) - 1);
  Result := Trim(S);
End;

Function DetectDropFile(Const Path: String): TDropFileType;
Var P: String;
Begin
  Result := dfNone;
  P := IncludeTrailingPathDelimiter(Path);
  If FileExists(P + 'PCBOARD.SYS') Then Result := dfPCBoardSys
  Else If FileExists(P + 'pcboard.sys') Then Result := dfPCBoardSys
  Else If FileExists(P + 'DOOR.SYS') Then Result := dfDoorSys
  Else If FileExists(P + 'door.sys') Then Result := dfDoorSys
  Else If FileExists(P + 'DORINFO1.DEF') Then Result := dfDorInfo
  Else If FileExists(P + 'dorinfo1.def') Then Result := dfDorInfo;
End;

Function ReadDropFile(Const Path: String; Var Info: TDropInfo): Boolean;
Var
  P: String;
  DFT: TDropFileType;
Begin
  Result := False;
  InitDropInfo(Info);
  P := IncludeTrailingPathDelimiter(Path);
  DFT := DetectDropFile(Path);
  Case DFT of
    dfPCBoardSys: Begin
      If FileExists(P + 'PCBOARD.SYS') Then
        Result := ReadPCBoardSys(P + 'PCBOARD.SYS', Info)
      Else
        Result := ReadPCBoardSys(P + 'pcboard.sys', Info);
    End;
    dfDoorSys: Begin
      If FileExists(P + 'DOOR.SYS') Then
        Result := ReadDoorSys(P + 'DOOR.SYS', Info)
      Else
        Result := ReadDoorSys(P + 'door.sys', Info);
    End;
    dfDorInfo: Begin
      If FileExists(P + 'DORINFO1.DEF') Then
        Result := ReadDorInfo(P + 'DORINFO1.DEF', Info)
      Else
        Result := ReadDorInfo(P + 'dorinfo1.def', Info);
    End;
  End;
End;

Function ReadPCBoardSys(Const FN: String; Var Info: TDropInfo): Boolean;
{ PCBOARD.SYS format (PCBoard 15.x):
  Line 1:  Display (PC runpath, ignored)
  Line 2:  Sysop name -1 if not at console, name if sysop
  Line 3:  -1 (always, ignored)
  Line 4:  Caller name
  Line 5:  Time allowed (minutes)
  Line 6:  -1 (always)
  Line 7:  ANSI? (-1=yes, 0=no)
  Line 8:  Node number
  Line 9:  Door path
  Line 10: BBS path
  Line 11: Sysop first name
  Line 12: Sysop last name
  Line 13: Baud rate (0=local)
  Line 14: COM port (0=local, 1-4=COM)
  Lines 15+: additional fields (security level, location, etc.) }
Var
  F: Text;
  S: String;
  Code, I: Integer;
Begin
  Result := False;
  InitDropInfo(Info);
  Info.DropType := dfPCBoardSys;

  Assign(F, FN);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  ReadLine(F);                          { 1: Display }
  Info.SysOpName := ReadLine(F);        { 2: Sysop / -1 }
  ReadLine(F);                          { 3: -1 }
  Info.UserName := ReadLine(F);         { 4: Caller name }
  S := ReadLine(F);                     { 5: Time allowed }
  Val(S, Info.TimeLeft, Code);
  ReadLine(F);                          { 6: -1 }
  S := ReadLine(F);                     { 7: ANSI }
  Info.ANSIMode := (Trim(S) = '-1');
  S := ReadLine(F);                     { 8: Node number }
  Val(S, Info.NodeNum, Code);
  ReadLine(F);                          { 9: Door path }
  ReadLine(F);                          { 10: BBS path }
  S := ReadLine(F);                     { 11: Sysop first }
  Info.SysOpName := S;
  S := ReadLine(F);                     { 12: Sysop last }
  Info.SysOpName := Info.SysOpName + ' ' + S;
  S := ReadLine(F);                     { 13: Baud rate }
  Val(S, Info.BaudRate, Code);
  S := ReadLine(F);                     { 14: COM port }
  Val(S, Info.ComPort, Code);

  { Parse user name into first/last }
  I := Pos(' ', Info.UserName);
  If I > 0 Then Begin
    Info.UserFirst := Copy(Info.UserName, 1, I - 1);
    Info.UserLast := Copy(Info.UserName, I + 1, Length(Info.UserName));
  End Else Begin
    Info.UserFirst := Info.UserName;
    Info.UserLast := '';
  End;

  Close(F);
  Result := True;
End;

Function ReadDoorSys(Const FN: String; Var Info: TDropInfo): Boolean;
{ DOOR.SYS format (GAP/Wildcat/etc):
  Line 1:  COM port (COM1:, COM0:=local)
  Line 2:  Baud rate
  Line 3:  Parity (8)
  Line 4:  Node number
  Line 5:  Baud rate (locked, may differ from line 2)
  Line 6:  Screen display (Y/N)
  Line 7:  Printer toggle (Y/N)
  Line 8:  Page bell (Y/N)
  Line 9:  Caller alarm (Y/N)
  Line 10: User full name
  Line 11: User location
  Line 12: Home phone
  Line 13: Work phone
  Line 14: Password
  Line 15: Security level
  Line 16: Total calls
  Line 17: Last call date
  Line 18: Seconds remaining
  Line 19: Time limit in minutes
  Line 20: GR (graphics: 0=none, 1=ANSI, 2=ANSI+RIP) }
Var
  F: Text;
  S: String;
  Code: Integer;
  I: Integer;
Begin
  Result := False;
  InitDropInfo(Info);
  Info.DropType := dfDoorSys;

  Assign(F, FN);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  S := ReadLine(F);                     { 1: COM port }
  If Pos('COM0', UpperCase(S)) > 0 Then Info.ComPort := 0
  Else If Pos('COM1', UpperCase(S)) > 0 Then Info.ComPort := 1
  Else If Pos('COM2', UpperCase(S)) > 0 Then Info.ComPort := 2
  Else If Pos('COM3', UpperCase(S)) > 0 Then Info.ComPort := 3
  Else If Pos('COM4', UpperCase(S)) > 0 Then Info.ComPort := 4;

  S := ReadLine(F); Val(S, Info.BaudRate, Code);  { 2: Baud }
  ReadLine(F);                          { 3: Parity }
  S := ReadLine(F); Val(S, Info.NodeNum, Code);   { 4: Node }
  ReadLine(F);                          { 5: Locked baud }
  ReadLine(F);                          { 6: Screen }
  ReadLine(F);                          { 7: Printer }
  ReadLine(F);                          { 8: Page bell }
  ReadLine(F);                          { 9: Caller alarm }
  Info.UserName := ReadLine(F);         { 10: User name }
  Info.Location := ReadLine(F);         { 11: Location }
  ReadLine(F);                          { 12: Home phone }
  ReadLine(F);                          { 13: Work phone }
  ReadLine(F);                          { 14: Password }
  S := ReadLine(F); Val(S, Info.SecLevel, Code);  { 15: Security }
  ReadLine(F);                          { 16: Total calls }
  ReadLine(F);                          { 17: Last call }
  ReadLine(F);                          { 18: Seconds remaining }
  S := ReadLine(F); Val(S, Info.TimeLeft, Code);  { 19: Minutes }
  S := ReadLine(F);                     { 20: Graphics }
  Val(S, I, Code);
  Info.ANSIMode := (I >= 1);
  Info.RIPMode := (I >= 2);

  { Parse name }
  I := Pos(' ', Info.UserName);
  If I > 0 Then Begin
    Info.UserFirst := Copy(Info.UserName, 1, I - 1);
    Info.UserLast := Copy(Info.UserName, I + 1, Length(Info.UserName));
  End Else Begin
    Info.UserFirst := Info.UserName;
    Info.UserLast := '';
  End;

  Close(F);
  Result := True;
End;

Function ReadDorInfo(Const FN: String; Var Info: TDropInfo): Boolean;
{ DORINFO1.DEF format:
  Line 1: BBS name
  Line 2: Sysop first name
  Line 3: Sysop last name
  Line 4: COM port (COM0=local)
  Line 5: Baud rate
  Line 6: Parity (0)
  Line 7: User first name
  Line 8: User last name
  Line 9: Location
  Line 10: ANSI (1=yes, 0=no)
  Line 11: Security level
  Line 12: Time remaining (minutes) }
Var
  F: Text;
  S: String;
  Code: Integer;
Begin
  Result := False;
  InitDropInfo(Info);
  Info.DropType := dfDorInfo;

  Assign(F, FN);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  ReadLine(F);                          { 1: BBS name }
  S := ReadLine(F);                     { 2: Sysop first }
  Info.SysOpName := S;
  S := ReadLine(F);                     { 3: Sysop last }
  Info.SysOpName := Info.SysOpName + ' ' + S;
  S := ReadLine(F);                     { 4: COM port }
  If Pos('0', S) > 0 Then Info.ComPort := 0
  Else If Pos('1', S) > 0 Then Info.ComPort := 1
  Else If Pos('2', S) > 0 Then Info.ComPort := 2;
  S := ReadLine(F); Val(S, Info.BaudRate, Code);  { 5: Baud }
  ReadLine(F);                          { 6: Parity }
  Info.UserFirst := ReadLine(F);        { 7: User first }
  Info.UserLast := ReadLine(F);         { 8: User last }
  Info.UserName := Trim(Info.UserFirst + ' ' + Info.UserLast);
  Info.Location := ReadLine(F);         { 9: Location }
  S := ReadLine(F);                     { 10: ANSI }
  Info.ANSIMode := (Trim(S) = '1');
  S := ReadLine(F); Val(S, Info.SecLevel, Code);  { 11: Security }
  S := ReadLine(F); Val(S, Info.TimeLeft, Code);  { 12: Time }

  Close(F);
  Result := True;
End;

End.
