Unit BBS_Core;

// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================

{$I M_OPS.PAS}

Interface

Uses
  m_io_Base,
  {$IFDEF WINDOWS}
  m_io_Sockets,
  {$ENDIF}
  m_FileIO,
  m_Strings,
  m_IniReader,
  m_Pipe,
  m_DateTime,
  BBS_Records,
  BBS_IO,
  BBS_MsgBase,
  BBS_User,
  BBS_FileBase,
  BBS_Menus,
  MPL_Execute;

Const
  mysMessageThreshold = 3;
  TemplateOptions     = 'Options';

Type
  RecTemplateData = Record
    PercentBar : RecPercent;
    Screen     : Array[1..10] of Record X, Y, A: Byte; End;
    Prompt     : Array[1..10] of String[160];
  End;

Type
  TBBSCore = Class
    {$IFDEF WINDOWS}
      Client      : TIOBase;
    {$ENDIF}
    User           : TBBSUser;
    Msgs           : TMsgBase;
    FileBase       : TFileBase;
    Menu           : TMenuEngine;
    IO             : TBBSIO;
    Pipe           : TPipe;
    EventFile      : File of RecEvent;
    ThemeFile      : File of RecTheme;
    VoteFile       : File of VoteRec;
    Vote           : VoteRec;
    Chat           : ChatRec;
    CommHandle     : LongInt;
    ShutDown       : Boolean;
    SemQwkNet      : Boolean;
    SemEchomail    : Boolean;
    SemNetmail     : Boolean;
    SemUseNet      : Boolean;
    TempPath       : String;
    Event          : RecEvent;
    NextEvent      : RecEvent;
    Theme          : RecTheme;
    Template       : RecTemplateData;
    LocalMode      : Boolean;
    UseFossil      : Boolean;   // A7: Use FOSSIL/serial instead of socket
    SerialPort     : Byte;      // A7: COM port number (1-4)
    Baud           : LongInt;
    ExitLevel      : Byte;
    EventWarn      : Boolean;
    EventExit      : Boolean;
    EventRunAfter  : Boolean;
    NodeNum        : Byte;
    TimerStart     : Integer;
    TimerEnd       : Integer;
    LastTimeLeft   : Integer;
    TimeOut        : LongInt;
    UserLoginName  : String[30];
    UserLoginPW    : String[15];
    UserHostInfo   : String[50];
    UserIPInfo     : String[15];
    CheckTimeOut   : Boolean;
    TimeOffset     : Word;
    TimeSaved      : Word;
    TimerOn        : Boolean;
    TimeChecked    : Boolean;
    ConfigMode     : Boolean;
    InUserEdit     : Boolean;
    AllowMessages  : Boolean;
    InMessage      : Boolean;
    MessageCheck   : Byte;
    HistoryFile    : File of RecHistory;
    HistoryEmails  : Word;
    HistoryPosts   : Word;
    HistoryDLs     : Word;
    HistoryDLKB    : LongInt;
    HistoryULs     : Word;
    HistoryULKB    : LongInt;
    HistoryHour    : SmallInt;
    LastScanHadNew : Boolean;
    LastScanHadYou : Boolean;
    PromptData     : Array[0..mysMaxThemeText] of Pointer;
    StatusPtr      : Byte;
    CurRoom        : Byte;
    ConfigFile     : File of RecConfig;
    ChatFile       : File of ChatRec;
    RoomFile       : File of RoomRec;
    Room           : RoomRec;
    LastOnFile     : File of RecLastOn;
    LastOn         : RecLastOn;

    Constructor Create;
    Destructor  Destroy; Override;

    Procedure   UpdateHistory;
    Procedure   WriteSemFiles;
    Procedure   FindNextEvent;
    Function    GetPrompt         (N : Word) : String;
    Procedure   SystemLog         (Str: String);
    Function    MinutesUntilEvent (ExecTime: Integer): Integer;
    Procedure   SetTimeLeft       (Mins: Integer);
    Function    ElapsedTime       : Integer;
    Function    TimeLeft          : Integer;
    Function    LoadThemeData     (Str: String) : Boolean;
    Procedure   DisposeThemeData;
    Function    ReadTemplate      (FN: String; DoFree: Boolean) : Pointer;
  End;

Var
  Session : TBBSCore;

Procedure ConfigLog (Str: String);
Procedure ErrorLog (Msg: String);
Procedure ErrorLogWrite (FileName: String; Code: Integer);

Implementation

Uses
  BBS_DataBase;

Constructor TBBSCore.Create;
Begin
  Inherited Create;

  HistoryEmails := 0;
  HistoryPosts  := 0;
  HistoryDLs    := 0;
  HistoryDLKB   := 0;
  HistoryULs    := 0;
  HistoryULKB   := 0;
  HistoryHour   := 0;
  ShutDown      := False;
  SemQwkNet     := False;
  SemEchomail   := False;
  SemNetmail    := False;
  SemUseNet     := False;
  CommHandle    := -1;
  LocalMode     := False;
  UseFossil     := False;
  SerialPort    := 1;
  Baud          := 38400;
  ExitLevel     := 0;
  EventWarn     := False;
  EventExit     := False;
  EventRunAfter := False;
  NodeNum       := 0;
  UserLoginName := '';
  UserLoginPW   := '';
  UserHostInfo  := '';
  UserIPInfo    := '';
  CheckTimeOut  := True;
  TimeOut       := TimerSeconds;
  TimeOffset    := 0;
  TimeSaved     := 0;
  TimerOn       := False;
  TimeChecked   := False;
  ConfigMode    := False;
  InUserEdit    := False;
  AllowMessages := True;
  InMessage     := False;
  MessageCheck  := mysMessageThreshold;
  StatusPtr     := 1;

  {$IFDEF WINDOWS}
    Client := TIOSocket.Create;
    TIOSocket(Client).FTelnetServer := True;
  {$ENDIF}

  User     := TBBSUser.Create(Pointer(Self));
  IO       := TBBSIO.Create(Pointer(Self));
  Msgs     := TMsgBase.Create(Pointer(Self));
  FileBase := TFileBase.Create(Pointer(Self));
  Menu     := TMenuEngine.Create(Pointer(Self));
End;

Destructor TBBSCore.Destroy;
Begin
  WriteSemFiles;
  DisposeThemeData;

  Pipe.Free;
  Msgs.Free;
  FileBase.Free;
  Menu.Free;
  User.Free;
  IO.Free;

  {$IFDEF WINDOWS}
    Client.Free;
  {$ENDIF}

  Inherited Destroy;
End;

Procedure TBBSCore.WriteSemFiles;
Begin
  If SemEchomail Then
    AppendText (bbsCfg.SemaPath + fn_SemFileEchoOut, '');

  If SemQwkNet Then
    AppendText (bbsCfg.SemaPath + fn_SemFileQwk, '');

  If SemUseNet Then
    AppendText (bbsCfg.SemaPath + fn_SemFileNews, '');

  If SemNetmail Then
    AppendText (bbsCfg.SemaPath + fn_SemFileNet, '');

  SemQwkNet     := False;
  SemEchomail   := False;
  SemNetmail    := False;
  SemUseNet     := False;
End;

Procedure TBBSCore.UpdateHistory;
Var
  History : RecHistory;
Begin
  If User.ThisUser.Flags AND UserNoHistory <> 0 Then Exit;

  Assign (HistoryFile, bbsCfg.DataPath + 'history.dat');

  If Not ioReset (HistoryFile, SizeOf(RecHistory), fmRWDN) Then
    ioReWrite(HistoryFile, SizeOf(RecHistory), fmRWDW);

  History.Date := CurDateDos;

  While Not Eof(HistoryFile) Do Begin
    ioRead (HistoryFile, History);

    If DateDos2Str(History.Date, 1) = DateDos2Str(CurDateDos, 1) Then Begin
      ioSeek (HistoryFile, FilePos(HistoryFile) - 1);
      Break;
    End;
  End;

  If Eof(HistoryFile) Then Begin
    FillChar(History, SizeOf(History), 0);

    History.Date := CurDateDos;
  End;

  Inc (History.Emails,     HistoryEmails);
  Inc (History.Posts,      HistoryPosts);
  Inc (History.Downloads,  HistoryDLs);
  Inc (History.Uploads,    HistoryULs);
  Inc (History.DownloadKB, HistoryDLKB);
  Inc (History.UploadKB,   HistoryULKB);

  If Not LocalMode And (User.ThisUser.Flags AND UserNoLastCall = 0) Then
    Inc (History.Calls, 1);

  If User.ThisUser.Calls = 1 Then Inc (History.NewUsers);

  If Not LocalMode Then Inc (History.Hourly[HistoryHour]);

  ioWrite (HistoryFile, History);
  Close   (HistoryFile);
End;

Procedure TBBSCore.FindNextEvent;
Var
  MinCheck : Integer;
Begin
  NextEvent.Active := False;

  MinCheck := -1;

  Assign  (EventFile, bbsCfg.DataPath + 'event.dat');

  If Not ioReset (EventFile, SizeOf(RecEvent), fmRWDN) Then
    ioReWrite (EventFile, SizeOf(RecEvent), fmRWDN);

  While Not Eof(EventFile) Do Begin
    ioRead (EventFile, Event);

    If (MinCheck = -1) or ((MinCheck <> -1) and (MinutesUntilEvent(Event.ExecTime) < MinCheck)) Then Begin
      If Event.Active and (Event.ExecType = 0) and ((Event.Node = 0) or (Event.Node = NodeNum)) and (Event.ExecDays[DayOfWeek(CurDateDos)]) Then Begin
        MinCheck  := MinutesUntilEvent(Event.ExecTime);
        NextEvent := Event;
      End;
    End;
  End;

  Close (EventFile);
End;

Procedure TBBSCore.SystemLog (Str: String);
Var
  tLOG : Text;
Begin
  Assign (tLOG, bbsCfg.LogsPath + 'node' + strI2S(NodeNum) + '.log');
  {$I-} Append(tLOG); {$I+}
  If IoResult <> 0 Then ReWrite (tLOG);

  If Str = '-' Then
    WriteLn (tLOG, strRep('-', 40))
  Else
    WriteLn (tLOG, FormatDate (CurDateDT, 'NNN DD YYYY HH:II') + ' ' + Str);

  Close (tLOG);
End;

// Append-only -cfg log (mystic.log).  MUTIL handles rotation/management.
Procedure ConfigLog (Str: String);
Var
  T : Text;
Begin
  Assign (T, bbsCfg.LogsPath + 'mystic.log');
  {$I-} Append(T); {$I+}
  If IoResult <> 0 Then {$I-} ReWrite(T); {$I+}
  If IoResult <> 0 Then Exit;

  If Str = '-' Then
    WriteLn (T, strRep('-', 50))
  Else
    WriteLn (T, FormatDate(CurDateDT, 'NNN DD YYYY HH:II') + ' ' + Str);

  Close (T);
End;

// Append-only errors.log, matching the format later Mystic builds use:
//   YYYY.DD.MM HH:MM:SS MYSTIC NNN <message>
// (no trailing period; Code/PID only appear on write failures - see below)
Procedure ErrorLog (Msg: String);
Var
  T : Text;
Begin
  Assign (T, bbsCfg.LogsPath + 'errors.log');
  {$I-} Append(T); {$I+}
  If IoResult <> 0 Then {$I-} ReWrite(T); {$I+}
  If IoResult <> 0 Then Exit;

  WriteLn (T, FormatDate(CurDateDT, 'YYYY.DD.MM HH:II:SS') + ' MYSTIC ' +
              strPadL(strI2S(Session.NodeNum), 3, '0') + ' ' + Msg);

  Close (T);
End;

// File write failures carry the IoResult code and PID, e.g.:
//   ... MYSTIC 001 Cannot write to \mystic\data\chat1.dat. Code=2, PID=5492
Procedure ErrorLogWrite (FileName: String; Code: Integer);
Begin
  ErrorLog ('Cannot write to ' + FileName + '. Code=' + strI2S(Code) +
            ', PID=' + strI2S(GetProcessID));
End;

Function TBBSCore.MinutesUntilEvent (ExecTime: Integer): Integer;
Begin {exits if 0 mins}
  If ExecTime > TimerMinutes Then Result := ExecTime - TimerMinutes Else
  If TimerMinutes > ExecTime Then Result := 1440 - TimerMinutes + ExecTime Else
  If NextEvent.Active Then Begin
    If DateDos2Str(NextEvent.LastRan, 1) = DateDos2Str(CurDateDos, 1) Then Begin
      Result := 1440; {if it was already ran...}
      Exit;
    End;
    If NextEvent.Forced Then Begin
      EventExit := True;
      {$IFDEF UNIX}
        io.OutFullLn (GetPrompt(137));
        SystemLog ('User disconnected for system event');
      {$ELSE}
        If Not LocalMode Then begin
          io.OutFullLn    (GetPrompt(137));
          SystemLog('User disconnected for system event');
        End;
      {$ENDIF}

      SystemLog('Event: ' + NextEvent.Name);

      Halt (NextEvent.ExecLevel);
    End Else
      EventRunAfter := True;
  End;
End;

Procedure TBBSCore.SetTimeLeft (Mins: Integer);
Begin
  TimerStart := TimerMinutes;
  TimerEnd   := TimerStart + Mins;
  TimerOn    := True;
End;

Function TBBSCore.ElapsedTime : Integer;
Begin
  If TimerStart > TimerMinutes Then Begin
    Dec (TimerStart, 1440);
    Dec (TimerEnd,   1440);

    SetTimeLeft (User.Security.Time);
  End;

  ElapsedTime := TimerMinutes - TimerStart;
End;

Function TBBSCore.TimeLeft : Integer;
Begin
  If Not TimerOn Then Begin
    TimeLeft := 0;

    Exit;
  End;

  If TimerStart > TimerMinutes Then Begin
    Dec (TimerStart, 1440);
    Dec (TimerEnd,   1440);

    SetTimeLeft (User.Security.Time);
  End;

  TimeLeft := TimerEnd - TimerMinutes;
End;

Function TBBSCore.GetPrompt (N: Word) : String;
Begin
  Result := String(PromptData[N]^);

  If Result[1] = '@' Then Begin
    io.OutFile (Copy(Result, 2, Length(Result)), True, 0);

    Result := '';
  End Else
  If Result[1] = '!' Then Begin
    ExecuteMPL (NIL, Copy(Result, 2, Length(Result)));

    Result := '';
  End;
End;

Procedure TBBSCore.DisposeThemeData;
Var
  Count : LongInt;
Begin
  For Count := mysMaxThemeText DownTo 0 Do Begin
    If Assigned(PromptData[Count]) Then
      FreeMem(PromptData[Count]);

    PromptData[Count] := NIL;
  End;
End;

Function TBBSCore.LoadThemeData (Str: String) : Boolean;
Var
  Count      : LongInt;
  PathError  : Boolean;
  PromptFile : Text;
  Buffer     : Array[1..1024 * 8] of Char;
  Temp       : String;
  TempTheme  : RecTheme;
Begin
  Result := False;

  Reset (ThemeFile);

  While Not Eof(ThemeFile) Do Begin
    Read (ThemeFile, TempTheme);

    If strUpper(TempTheme.FileName) = strUpper(Str) Then Begin
      Result := True;
      Theme  := TempTheme;

      { Check all theme paths exist - report all missing then halt }
      PathError := False;
      If (Theme.TextPath <> '') and Not DirExists(Theme.TextPath) Then Begin
        SystemLog('ERROR: Text path not found: ' + Theme.TextPath);
        WriteLn('  Text path: ' + Theme.TextPath);
        PathError := True;
      End;
      If (Theme.MenuPath <> '') and Not DirExists(Theme.MenuPath) Then Begin
        SystemLog('ERROR: Menu path not found: ' + Theme.MenuPath);
        WriteLn('  Menu path: ' + Theme.MenuPath);
        PathError := True;
      End;
      If (Theme.ScriptPath <> '') and Not DirExists(Theme.ScriptPath) Then Begin
        SystemLog('ERROR: Script path not found: ' + Theme.ScriptPath);
        WriteLn('  Script path: ' + Theme.ScriptPath);
        PathError := True;
      End;
      
      If PathError Then Begin
        WriteLn('ERROR: Theme paths missing for theme: ' + Theme.FileName);
        WriteLn('Run: maketheme cfgtheme  to set the missing paths.');
        Halt(1);
      End;

      Break;
    End;
  End;

  Close (ThemeFile);

  If Not Result Then Exit;

  Result   := False;
  FileMode := 66;

  Assign     (PromptFile, bbsCfg.DataPath + Theme.FileName + '.txt');
  SetTextBuf (PromptFile, Buffer);

  {$I-} Reset (PromptFile); {$I+}

  If IoResult <> 0 Then Exit;

  DisposeThemeData;

  While Not Eof(PromptFile) Do Begin
    ReadLn (PromptFile, Temp);

    If Copy(Temp, 1, 3) = '000' Then
      Count := 0
    Else
    If strS2I(Copy(Temp, 1, 3)) > 0 Then
      Count := strS2I(Copy(Temp, 1, 3))
    Else
      Count := -1;

    If Count <> -1 Then Begin
      Temp := Copy(Temp, 5, Length(Temp));

      If Assigned (PromptData[Count]) Then
        FreeMem(PromptData[Count], SizeOf(PromptData[Count]^));

      GetMem (PromptData[Count], Length(Temp) + 1);
      Move   (Temp, PromptData[Count]^, Length(Temp) + 1);
    End;
  End;

  Close (PromptFile);

  Result := True;

  For Count := 1 to mysMaxThemeText Do
    If Not Assigned(PromptData[Count]) Then Begin
      SystemLog ('Missing prompt #' + strI2S(Count));
      IO.OutFullLn('|12Missing prompt #' + strI2S(Count));

      Result := False;
    End;

  If Not Result Then Halt(1);
End;

Function TBBSCore.ReadTemplate (FN: String; DoFree: Boolean) : Pointer;
Const
  strGeneral = 'Coords';
  strPercent = 'Percent';
  strPrompt  = 'Prompts';
Var
  TF    : TIniReader;
  Str   : String;
  Count : Byte;
Begin
  FillChar(Template, SizeOf(Template), 0);

  Result := NIL;
  FN     := FN + '.ini';
  Str    := Session.Theme.TextPath + FN;

  If Not FileExist(Str) And (Session.Theme.Flags AND ThmFallback <> 0) Then
    Str := bbsCfg.TextPath + FN;

  TF := TIniReader.Create(Str);

  For Count := 1 to 10 Do Begin
    Str := TF.ReadString(strGeneral, 'Coord' + strI2S(Count), '0,0,0');

    Val (strWordGet(1, Str, ','), Template.Screen[Count].X);
    Val (strWordGet(2, Str, ','), Template.Screen[Count].Y);
    Val (strWordGet(3, Str, ','), Template.Screen[Count].A);
  End;

  Template.PercentBar.Active    := TF.ReadBoolean(strPercent, 'active', False);
  Template.PercentBar.Format    := TF.ReadInteger(strPercent, 'bar_format', 0);
  Template.PercentBar.BarLength := TF.ReadInteger(strPercent, 'bar_length', 20);
  Template.PercentBar.StartX    := TF.ReadInteger(strPercent, 'location_x', 0);
  Template.PercentBar.StartY    := TF.ReadInteger(strPercent, 'location_y', 0);
  Template.PercentBar.LoChar    := Chr(TF.ReadInteger(strPercent, 'low_char', 176));
  Template.PercentBar.LoAttr    := TF.ReadInteger(strPercent, 'low_attr', 8);
  Template.PercentBar.HiChar    := Chr(TF.ReadInteger(strPercent, 'high_char', 178));
  Template.PercentBar.HiAttr    := TF.ReadInteger(strPercent, 'high_attr', 31);

  For Count := 1 to 10 Do
    Template.Prompt[Count] := TF.ReadString(strPrompt, 'str' + strI2S(Count), '');

  If DoFree Then
    TF.Free
  Else
    Result := TF;
End;

End.
