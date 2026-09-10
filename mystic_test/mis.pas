// ====================================================================
// Mystic BBS Software               Copyright 1997-2012 By James Coyle
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

Program MIS;

{$I M_OPS.PAS}

{$IFDEF WINDOWS}
  {$R mystic.res}
{$ENDIF}

Uses
  {$IFDEF DEBUG}
    HeapTrc,
    LineInfo,
  {$ENDIF}
  {$IFDEF UNIX}
    cThreads,
    BaseUnix,
  {$ENDIF}
  DOS,
  m_Output,
  m_Input,
  m_DateTime,
  m_io_Base,
  m_io_Sockets,
  m_FileIO,
  m_Strings,
  m_Term_Ansi,
  MIS_Common,
  MIS_NodeData,
  MIS_Server,
  MIS_Client_Telnet,
  MIS_Client_SMTP,
  MIS_Client_POP3,
  MIS_Client_FTP,
  MIS_Client_NNTP,
  MIS_Client_BINKP,
  MIS_Client_HTTP,
  MIS_Events,
  BBS_Records,
  BBS_DataBase,
  utrayit;

Const
  FocusTelnet = 0;
  FocusSMTP   = 1;
  FocusPOP3   = 2;
  FocusFTP    = 3;
  FocusNNTP   = 4;
  FocusBINKP  = 5;
  FocusEVENT  = 6;
  FocusMax    = 6;

  { 1.12 console color attributes }
  ATTR_HEADER_YEL = $1E;  { yellow on blue }
  ATTR_PROMPT     = $1F;  { white on blue  }

Var
  Keyboard     : TInput;
  TelnetServer : TServerManager;
  FTPServer    : TServerManager;
  POP3Server   : TServerManager;
  SMTPServer   : TServerManager;
  NNTPServer   : TServerManager;
  BINKPServer  : TServerManager;
  HTTPServer   : TServerManager;
  EventThread  : TEventEngine;
  FocusPTR     : TServerManager;
  FocusCurrent : Byte;
  ActiveTab    : Byte = 0;  { 1.12 view tab: 0=Messages 1=Connections 2=Events 3=Stats }
  TopPage      : Integer;
  BarPos       : Integer;
  NodeData     : TNodeData;
  DaemonMode   : Boolean = False;
  TrayMode     : Boolean = False;
  ShutdownRequested : Boolean = False;

{$I MIS_ANSIWFC.PAS}

Procedure ReadConfiguration;
Begin
  Case bbsCfgStatus of
    cfgNotFound : If Not DaemonMode Then Begin
                    Console.WriteLine (#13#10 + 'ERROR: Unable to read MYSTIC.DAT.  This file must exist in the same');
                    Console.WriteLine ('directory as MIS or MYSTICBBS environment location');

                    Halt(1);
                  End;
    cfgMisMatch : Begin
                    WriteLn('ERROR: Data files are not current and must be upgraded.');
                    Halt(1);
                  End;
  End;

  DirChange(bbsCfg.SystemPath);

  LoadMISConfig;
End;

Function GetFocusPtr : TServerManager;
Begin
  Result := NIL;

  Case FocusCurrent of
    FocusTelnet : GetFocusPtr := TelnetServer;
    FocusSMTP   : GetFocusPtr := SMTPServer;
    FocusPOP3   : GetFocusPtr := POP3Server;
    FocusFTP    : GetFocusPtr := FTPServer;
    FocusNNTP   : GetFocusPtr := NNTPServer;
    FocusBINKP  : GetFocusPtr := BINKPServer;
  End;
End;

Procedure UpdateConnectionList;
{ 1.12: Connections tab — SERVER USER STATUS ORIGIN columns }
Var
  Count : Byte;
  Attr  : Byte;
  PosY  : Byte;
  NI    : TNodeInfoRec;
Begin

  If ActiveTab <> TAB_CONNECTIONS Then Exit;
  If FocusPtr = NIL Then Exit;

  NodeData.SynchronizeNodeData;

  PosY := 0;

  For Count := TopPage to TopPage + 7 Do Begin
    NodeData.GetNodeInfo(Count, NI);

    Inc (PosY);

    If Count = BarPos Then Attr := 31 Else Attr := 7;

    Case FocusCurrent of
      0 : If NI.Busy Then Begin
            { 1.12 format: SERVER USER STATUS ORIGIN }
            Console.WriteXY (2, 8 + PosY, Attr,
              strPadR(FocusPtr.ServerName, 8, ' ') +
              strPadR(NI.User, 15, ' ') +
              strPadR(NI.Action, 25, ' ') +
              strPadL(NI.IP, 22, ' '));
          End Else
          If Count <= FocusPtr.ClientMax Then
            Console.WriteXY (2, 8 + PosY, Attr,
              strPadR(FocusPtr.ServerName, 8, ' ') +
              strPadR('Waiting', 15, ' ') +
              strPadR('slot ' + strI2S(Count) + '/' + strI2S(FocusPtr.ClientMax), 25, ' ') +
              strRep(' ', 22))
          Else
            Console.WriteXY (2, 8 + PosY, Attr, strRep(' ', 70));
      1,
      2,
      3,
      4,
      5 : If (Count <= FocusPtr.ClientList.Count) And (FocusPtr.ClientList[Count - 1] <> NIL) Then Begin
            Console.WriteXY (2, 8 + PosY, Attr,
              strPadR(FocusPtr.ServerName, 8, ' ') +
              strPadR(TFTPServer(FocusPtr.ClientList[Count - 1]).User.Handle, 15, ' ') +
              strPadR('Connected', 25, ' ') +
              strPadL(TFTPServer(FocusPtr.ClientList[Count - 1]).Client.PeerIP, 22, ' '));
          End Else
          If Count <= FocusPtr.ClientMax Then
            Console.WriteXY (2, 8 + PosY, Attr,
              strPadR(FocusPtr.ServerName, 8, ' ') +
              strPadR('Waiting', 15, ' ') +
              strPadR('slot ' + strI2S(Count) + '/' + strI2S(FocusPtr.ClientMax), 25, ' ') +
              strRep(' ', 22))
          Else
            Console.WriteXY (2, 8 + PosY, Attr, strRep(' ', 70));
    End;
  End;
End;

Procedure UpdateStatus;
Var
  Offset  : Integer;
  Count   : Integer;
  LogLine : String;
Begin
  If FocusPtr = NIL Then Exit;

  FocusPtr.StatusUpdated := False;

  // Stats tab: show connection statistics
  If ActiveTab = TAB_STATS Then Begin
    Console.WriteXY (20, 10, 7, strPadR(strI2S(FocusPtr.ClientActive), 5, ' '));
    Console.WriteXY (20, 11, 7, strPadR(strI2S(FocusPtr.ClientBlocked), 5, ' '));
    Console.WriteXY (20, 12, 7, strPadR(strI2S(FocusPtr.ClientRefused), 5, ' '));
    Console.WriteXY (20, 13, 7, strPadR(strI2S(FocusPtr.ClientTotal), 5, ' '));
  End;

  // Messages tab: show scrolling server log with colored fields
  // Format: "HH:MM:SS SERVICE TEXT" or "HH:MM:SS MANAGER TEXT"
  If ActiveTab = TAB_MESSAGES Then Begin
    Offset := FocusPtr.ServerStatus.Count;

    For Count := MIS_CONTENT_BOT DownTo MIS_CONTENT_TOP Do Begin
      If Offset > 0 Then Begin
        Dec(Offset);
        LogLine := FocusPtr.ServerStatus.Strings[Offset];
        { Color-code: timestamp(cyan) service(yellow) text(gray) }
        If Length(LogLine) >= 17 Then Begin
          Console.WriteXY (2, Count, ATTR_TIMESTAMP, Copy(LogLine, 1, 8));
          Console.WriteXY (10, Count, ATTR_SERVICE, Copy(LogLine, 10, 8));
          If Pos('Refused', LogLine) > 0 Then
            Console.WriteXY (18, Count, ATTR_ERROR, strPadR(Copy(LogLine, 18, 255), 61, ' '))
          Else If Pos('> Connect', LogLine) > 0 Then
            Console.WriteXY (18, Count, ATTR_CONTENT_HI, strPadR(Copy(LogLine, 18, 255), 61, ' '))
          Else
            Console.WriteXY (18, Count, ATTR_CONTENT, strPadR(Copy(LogLine, 18, 255), 61, ' '));
        End Else
          Console.WriteXY (2, Count, ATTR_CONTENT, strPadR(LogLine, 77, ' '));
      End Else
        Console.WriteXY (2, Count, ATTR_CONTENT, strRep(' ', 77));
    End;
  End;

  // Connections tab: update connection list
  If ActiveTab = TAB_CONNECTIONS Then
    UpdateConnectionList;
End;

Procedure EventStatus;
Var
  Count : LongInt;
  Loop  : LongInt;
  Attr  : Byte;
Begin
  If ActiveTab <> TAB_EVENTS Then Begin
    EventThread.Updated := False;
    Exit;
  End;

  Loop := EventThread.EventList.Count;

  For Count := 8 DownTo 1 Do Begin
    If Loop > 0 Then Begin
      If Loop = EventThread.NextPos Then
        Attr := 31
      Else
        Attr := 7;

      Console.WriteXY (2, 7 + Count, Attr, EventThread.EventList.Strings[Loop - 1] + ' ')
    End Else
      Console.WriteXY (2, 7 + Count, 7, strRep(' ', 51));

    Dec (Loop);
  End;

  Loop := EventThread.StatusList.Count;

  For Count := 8 DownTo 1 Do Begin
    If Loop > 0 Then
      Console.WriteXY (2, 15 + Count, 7, strPadR(EventThread.StatusList.Strings[Loop - 1], 75, ' '))
    Else
      Console.WriteXY (2, 15 + Count, 7, strRep(' ', 75));

    Dec (Loop);
  End;

  EventThread.Updated := False;
End;

Procedure SwitchFocus;
Begin
  BarPos  := 1;
  TopPage := 1;

  Repeat
    If FocusCurrent = FocusMax Then FocusCurrent := 0 Else Inc(FocusCurrent);

    Case FocusCurrent of
      FocusTelnet : If TelnetServer <> NIL Then Break;
      FocusSMTP   : If SmtpServer   <> NIL Then Break;
      FocusPOP3   : If Pop3Server   <> NIL Then Break;
      FocusFTP    : If FtpServer    <> NIL Then Break;
      FocusNNTP   : If NNTPServer   <> NIL Then Break;
      FocusBINKP  : If BINKPServer  <> NIL Then Break;
      FocusEVENT  : Break;
    End;
  Until False;

  { 1.12: Show active service in title bar row 5 }
  Console.WriteXY(3, 5, ATTR_HEADER_YEL,
    'Mystic Internet Server' + strPadR('', 55, ' '));

  Case FocusCurrent of
    FocusTelnet : Console.WriteXY(26, 5, ATTR_PROMPT, '[TELNET]');
    FocusSMTP   : Console.WriteXY(26, 5, ATTR_PROMPT, '[SMTP]');
    FocusPOP3   : Console.WriteXY(26, 5, ATTR_PROMPT, '[POP3]');
    FocusFTP    : Console.WriteXY(26, 5, ATTR_PROMPT, '[FTP]');
    FocusNNTP   : Console.WriteXY(26, 5, ATTR_PROMPT, '[NNTP]');
    FocusBINKP  : Console.WriteXY(26, 5, ATTR_PROMPT, '[BINKP]');
    FocusEVENT  : Console.WriteXY(26, 5, ATTR_PROMPT, '[EVENT]');
  End;

  FocusPtr := GetFocusPtr;

  If FocusPtr <> NIL Then Begin
    Console.WriteXY (69, 5, 7, strPadR(strI2S(FocusPtr.Port), 5, ' '));
    Console.WriteXY (69, 6, 7, strPadR(strI2S(FocusPtr.ClientMax), 5, ' '));

    UpdateStatus;

    Console.WriteXY (2, 7, 15, 'Connections');
  End Else
    Case FocusCurrent of
      FocusEVENT : EventStatus;
    End;
End;


Procedure LocalLogin; Forward;

Procedure ShowESCMenu;
{ 1.12: ESC opens popup menu instead of immediate shutdown }
Var
  Ch     : Char;
  MenuY  : Integer;
  MenuDone : Boolean;
Begin
  MenuY := 10;

  { Draw menu box }
  Console.WriteXY(25, MenuY,   $1F, '  浜様様様様様様様様様様様様?  ');
  Console.WriteXY(25, MenuY+1, $1F, '  ?  Mystic Internet Server ?  ');
  Console.WriteXY(25, MenuY+2, $1F, '  麺様様様様様様様様様様様様?  ');
  Console.WriteXY(25, MenuY+3, $1E, '  ?  L  Local Login          ?  ');
  Console.WriteXY(25, MenuY+4, $1E, '  ?  K  Kill User            ?  ');
  Console.WriteXY(25, MenuY+5, $1E, '  ?  S  Switch Service       ?  ');
  Console.WriteXY(25, MenuY+6, $1E, '  ?  H  Help                 ?  ');
  Console.WriteXY(25, MenuY+7, $1F, '  麺様様様様様様様様様様様様?  ');
  Console.WriteXY(25, MenuY+8, $1C, '  ?  Q  Shutdown Servers     ?  ');
  Console.WriteXY(25, MenuY+9, $1F, '  藩様様様様様様様様様様様様?  ');

  MenuDone := False;
  Repeat
    If Keyboard.KeyWait(100) Then Begin
      Ch := UpCase(Keyboard.ReadKey);
      Case Ch of
        'L': Begin
          MenuDone := True;
          LocalLogin;
          DrawStatusScreen;
          ActiveTab := TAB_MESSAGES;
        End;
        'K': Begin
          { TODO: Kill user by node number }
          MenuDone := True;
        End;
        'S': Begin
          SwitchFocus;
          MenuDone := True;
        End;
        'H': Begin
          DrawHelpScreen;
          Repeat Until Keyboard.ReadKey = #13;
          MenuDone := True;
        End;
        'Q': Begin
          Console.WriteXY(25, MenuY+8, $4F, '  ?  Shutdown Servers?  Y/N  ?  ');
          Repeat
            Ch := UpCase(Keyboard.ReadKey);
            If Ch = 'Y' Then Begin ShutdownRequested := True; MenuDone := True; End;
            If Ch in ['N', #27] Then MenuDone := True;
          Until Ch in ['Y', 'N', #27];
        End;
        #27: MenuDone := True;
      End;
    End;
  Until MenuDone;

  { Redraw the screen }
  DrawTabScreen(ActiveTab);
End;

Procedure LocalLogin;
Const
  BufferSize = 1024 * 4;
Var
  Client : TIOSocket;
  Term   : TTermAnsi;
  Res    : LongInt;
  Buffer : Array[1..BufferSize] of Char;
  Done   : Boolean;
  Ch     : Char;
Begin
  Console.TextAttr := 7;
  Console.ClearScreen;
//  Console.WriteStr ('Connecting to 127.0.0.1... ');

  Client := TIOSocket.Create;

  Client.FTelnetClient := True;

  If Not Client.Connect(bbsCfg.inetInterface{'127.0.0.1'}, bbsCfg.InetTNPort) Then
    Console.WriteLine('Unable to connect')
  Else Begin
    Done := False;
    Term := TTermAnsi.Create(Console);

    Console.SetWindow (1, 1, 80, 24, True);
    Console.WriteXY   (1, 25, 112, strPadC('Local TELNET: ALT-X to Quit', 80, ' '));

    Term.SetReplyClient(TIOBase(Client));

    Repeat
      If Client.WaitForData(0) > 0 Then Begin
        Repeat
          Res := Client.ReadBuf (Buffer, BufferSize);

          If Res < 0 Then Begin
            Done := True;
            Break;
          End;

          Term.ProcessBuf(Buffer, Res);
        Until Res <> BufferSize;
      End Else
      If Keyboard.KeyPressed Then Begin
        Ch := Keyboard.ReadKey;
        Case Ch of
          #00 : Case Keyboard.ReadKey of
                  #45 : Break;
                  #71 : Client.WriteStr(#27 + '[H');
                  #72 : Client.WriteStr(#27 + '[A');
                  #73 : Client.WriteStr(#27 + '[V');
                  #75 : Client.WriteStr(#27 + '[D');
                  #77 : Client.WriteStr(#27 + '[C');
                  #79 : Client.WriteStr(#27 + '[K');
                  #80 : Client.WriteStr(#27 + '[B');
                  #81 : Client.WriteStr(#27 + '[U');
                  #83 : Client.WriteStr(#127);
                End;
        Else
          Client.WriteBuf(Ch, 1);
          If Client.FTelnetEcho Then Term.Process(Ch);
        End;
      End Else
        WaitMS(5);
    Until Done;

    Term.Free;
  End;

  Client.Free;

  Console.TextAttr := 7;
  Console.SetWindow (1, 1, 80, 25, True);

  FocusCurrent := FocusMax;

  DrawStatusScreen;
  ActiveTab := TAB_MESSAGES;

  SwitchFocus;
End;

{$IFDEF UNIX}
Procedure SetUserOwner;
Var
  Info   : Stat;
  MysLoc : String;
Begin
  MysLoc := GetEnv('mysticbbs');

  If MysLoc <> '' Then MysLoc := DirSlash(MysLoc);

  If fpStat(MysLoc + 'mis', Info) = 0 Then Begin
    // A45: drop root privileges after binding ports.  fpSetEUID/fpSetEGID
    // set the effective UID/GID only, so file ownership matches MIS binary.
    // Available in fpc264irc r3.1 (commit edb234e7, PPU rebuilt).
    {$IFDEF VER2}
    fpSetEGID (Info.st_GID);
    fpSetEUID (Info.st_UID);
    {$ENDIF}
  End;
End;
{$ENDIF}

Function ServerStartup : Boolean;
Var
  BsyFN   : String;
  KillBsy : Boolean;
  I       : LongInt;
Begin
  Result := False;

  ReadConfiguration;

  // A38 fork (from 1.12): running-lock via a mis.bsy semaphore.  If it already
  // exists another MIS is running (or crashed leaving a stale lock); refuse to
  // start a second instance that would fight over the same ports.  KILLBUSY on
  // the command line removes a stale lock.
  BsyFN   := bbsCfg.SemaPath + fn_SemFileMisBusy;
  KillBsy := False;

  For I := 1 to ParamCount Do
    If strUpper(ParamStr(I)) = 'KILLBUSY' Then KillBsy := True;

  If KillBsy Then
    If FileExist(BsyFN) Then FileErase(BsyFN);

  If FileExist(BsyFN) Then Begin
    Console.ClearScreen;
    Console.WriteLine('ERROR: Mystic servers are already running.');
    Console.WriteLine('(If this is a stale lock after a crash, run: MIS KILLBUSY)');
    Halt(1);
  End;

  AppendText(BsyFN, '');

  TelnetServer := NIL;
  FTPServer    := NIL;
  POP3Server   := NIL;
  SMTPServer   := NIL;
  NNTPServer   := NIL;
  BINKPServer  := NIL;
  HTTPServer   := NIL;
  NodeData     := TNodeData.Create(bbsCfg.INetTNNodes);

  If bbsCfg.InetTNUse Then Begin
    TelnetServer := TServerManager.Create(bbsCfg, bbsCfg.InetTNPort, bbsCfg.INetTNNodes, NodeData, @CreateTelnet);
    TelnetServer.ServerName := 'TELNET';
    TelnetServer.Status(-1, 'Starting TELNET');

    TelnetServer.Server.FTelnetServer := True;
    TelnetServer.ClientMaxIPs         := bbsCfg.InetTNDupes;

    TelnetServer.BanMaxConns         := bbsCfg.inetBanIP;
    TelnetServer.BanTimeSecs         := bbsCfg.inetBanSecs;    TelnetServer.LogFile              := 'telnet';

    Result := True;
  End;

  If bbsCfg.InetSMTPUse Then Begin
    SMTPServer := TServerManager.Create(bbsCfg, bbsCfg.INetSMTPPort, bbsCfg.inetSMTPMax, NodeData, @CreateSMTP);
    SMTPServer.ServerName := 'SMTP';
    SMTPServer.Status(-1, 'Starting SMTP');

    SMTPServer.Server.FTelnetServer := False;
    SMTPServer.ClientMaxIPs         := bbsCfg.INetSMTPDupes;

    SMTPServer.BanMaxConns         := bbsCfg.inetBanIP;
    SMTPServer.BanTimeSecs         := bbsCfg.inetBanSecs;    SMTPServer.LogFile              := 'smtp';

    Result := True;
  End;

  If bbsCfg.InetPOP3Use Then Begin
    POP3Server := TServerManager.Create(bbsCfg, bbsCfg.INetPOP3Port, bbsCfg.inetPOP3Max, NodeData, @CreatePOP3);
    POP3Server.ServerName := 'POP3';
    POP3Server.Status(-1, 'Starting POP3');

    POP3Server.Server.FTelnetServer := False;
    POP3Server.ClientMaxIPs         := bbsCfg.inetPOP3Dupes;

    POP3Server.BanMaxConns         := bbsCfg.inetBanIP;
    POP3Server.BanTimeSecs         := bbsCfg.inetBanSecs;    POP3Server.LogFile              := 'pop3';

    Result := True;
  End;

  If bbsCfg.InetFTPUse Then Begin
    FTPServer := TServerManager.Create(bbsCfg, bbsCfg.InetFTPPort, bbsCfg.inetFTPMax, NodeData, @CreateFTP);
    FTPServer.ServerName := 'FTP';
    FTPServer.Status(-1, 'Starting FTP');

    FTPServer.Server.FTelnetServer := False;
    FTPServer.ClientMaxIPs         := bbsCfg.inetFTPDupes;

    FTPServer.BanMaxConns         := bbsCfg.inetBanIP;
    FTPServer.BanTimeSecs         := bbsCfg.inetBanSecs;    FTPServer.LogFile              := 'ftp';

    Result := True;
  End;

  If bbsCfg.InetNNTPUse Then Begin
    NNTPServer := TServerManager.Create(bbsCfg, bbsCfg.InetNNTPPort, bbsCfg.inetNNTPMax, NodeData, @CreateNNTP);
    NNTPServer.ServerName := 'NNTP';
    NNTPServer.Status(-1, 'Starting NNTP');

    NNTPServer.Server.FTelnetServer := False;
    NNTPServer.ClientMaxIPs         := bbsCfg.inetNNTPDupes;

    NNTPServer.BanMaxConns         := bbsCfg.inetBanIP;
    NNTPServer.BanTimeSecs         := bbsCfg.inetBanSecs;    NNTPServer.LogFile              := 'nntp';

    Result := True;
  End;

  If bbsCfg.InetBINKPUse Then Begin
    BINKPServer := TServerManager.Create(bbsCfg, bbsCfg.InetBINKPPort, bbsCfg.inetBINKPMax, NodeData, @CreateBINKP);
    BINKPServer.ServerName := 'BINKP';
    BINKPServer.Status(-1, 'Starting BINKP');

    BINKPServer.Server.FTelnetServer := False;
    BINKPServer.ClientMaxIPs         := bbsCfg.inetBINKPDupes;

    BINKPServer.BanMaxConns         := bbsCfg.inetBanIP;
    BINKPServer.BanTimeSecs         := bbsCfg.inetBanSecs;    BINKPServer.LogFile              := 'binkp';

    Result := True;
  End;

  // HTTP file server on port 8080 (webroot: SystemPath/webroot/)
  HTTPServer := TServerManager.Create(bbsCfg, 8080, 10, NodeData, @CreateHTTP);

  HTTPServer.Server.FTelnetServer := False;
  HTTPServer.ClientMaxIPs         := 5;
  HTTPServer.BanMaxConns          := bbsCfg.inetBanIP;
  HTTPServer.BanTimeSecs          := bbsCfg.inetBanSecs;
  HTTPServer.LogFile              := 'http';

  Result := True;

  If Result Then
    EventThread := TEventEngine.Create(bbsCfg);

  {$IFDEF UNIX}
    SetUserOwner;
  {$ENDIF}

  TempPath := bbsCfg.SystemPath + 'temp0' + PathChar;

  DirCreate(TempPath);
End;

{$IFDEF UNIX}
(*
Procedure Snoop;
Begin
  If FocusCurrent <> FocusTelnet Then Exit;

  If FocusPtr.ClientList[BarPos - 1] <> NIL Then Begin
    Term := TTermAnsi.Create(Console);

    Console.TextAttr := 7;

    Console.ClearScreen;

    Console.SetWindow (1, 1, 80, 24, True);
    Console.WriteXY   (1, 25, 112, strPadC('Snooping : Press [ESC] to Quit', 80, ' '));

    TTelnetServer(FocusPtr.ClientList[BarPos - 1]).Snooping := True;

    Repeat Until Keyboard.ReadKey = #27;

    If TTelnetServer(FocusPtr.ClientList[BarPos - 1]) <> NIL Then
      TTelnetServer(FocusPtr.ClientList[BarPos - 1]).Snooping := False;

    Term.Free;

    Console.TextAttr := 7;

    Console.SetWindow (1, 1, 80, 25, True);

    FocusCurrent := FocusMax;

    DrawStatusScreen;
  ActiveTab := TAB_MESSAGES;

    SwitchFocus;
  End;
End;
*)
Procedure DaemonEventSignal (Sig : LongInt); cdecl;
Begin
  Case Sig of
    SIGTERM : Begin
                EventThread.Free;
                TelnetServer.Free;
                SMTPServer.Free;
                POP3Server.Free;
                FTPServer.Free;
                NNTPServer.Free;
                BinkPServer.Free;
                NodeData.Free;
                Halt(0);
              End;

  End;
End;

Procedure ExecuteDaemon;
Var
  PID : TPID;
  SID : TPID;
Begin
  WriteLn('- [MIS] Executing Mystic Internet Server in daemon mode');

  PID := fpFork;

  If PID < 0 Then Halt(1);
  If PID > 0 Then Halt(0);

  SID := fpSetSID;

  If SID < 0 Then Halt(1);

  Close (Input);
  Close (Output);
  //CLOSE STDERR?

  If Not ServerStartup Then Begin
    NodeData.Free;
    Halt(1);
  End;

  fpSignal (SIGTERM, DaemonEventSignal);

  Repeat
    WaitMS(60000);  // Heartbeat
    // change to wait 45 and check for event
  Until False;
End;
{$ENDIF}

Const
  WinTitle = 'Mystic Internet Server';

Var
  Count : Integer;
  Tray  : TTrayIt;
Begin
  {$IFDEF UNIX}
    DaemonMode := Pos('-D', strUpper(ParamStr(1))) > 0;
  {$ENDIF}

  // -T flag: minimize to system tray (Windows) or iconify terminal (Unix)
  TrayMode := Pos('-T', strUpper(ParamStr(1))) > 0;

  Randomize;

  {$IFDEF DEBUG}
    SetHeapTraceOutput('mis.mem');
  {$ENDIF}

  {$IFDEF UNIX}
    If DaemonMode Then ExecuteDaemon;
  {$ENDIF}

  Console  := TOutput.Create(True);
  Keyboard := TInput.Create;

  Console.SetWindowTitle(WinTitle);

  // process command lines here and exit

  If Not ServerStartup Then Begin
    Console.ClearScreen;
    Console.WriteLine('ERROR: No servers are configured as active.');

    NodeData.Free;

    Halt(10);
  End;

  Count := 0;

  DrawStatusScreen;
  ActiveTab := TAB_MESSAGES;

  { 1.12: BBS name in console title }
  Console.SetWindowTitle('Mystic Internet Server (' + bbsCfg.BBSName + ')');

  // Tray mode: minimize to system tray (Windows) or iconify (Unix)
  Tray := TTrayIt.Create;

  If TrayMode Then Begin
    If Not Tray.TrayConsole(WinTitle + ' - ' + bbsCfg.BBSName) Then
      TrayMode := False;  // tray not supported, continue normally
  End;

  FocusCurrent := FocusMax;

  SwitchFocus;

  Repeat
    If Keyboard.KeyWait(500) Then
      Case Keyboard.ReadKey of
        #00 : Case Keyboard.ReadKey of
                #72 : If BarPos > TopPage Then Begin
                        Dec(BarPos);
                        UpdateConnectionList;
                      End Else
                      If TopPage > 1 Then Begin
                        Dec(TopPage);
                        Dec(BarPos);

                        UpdateConnectionList;
                      End;
                #75 : Begin
                        Dec (TopPage, 8);
                        Dec (BarPos, 8);

                        If TopPage < 1 Then TopPage := 1;
                        If BarPos  < 1 Then BarPos  := TopPage;

                        UpdateConnectionList;
                      End;
                #77 : Begin
                        Inc (TopPage, 8);
                        Inc (BarPos, 8);

                        If TopPage + 7 > FocusPtr.ClientList.Count Then TopPage := FocusPtr.ClientList.Count - 7;
                        If BarPos > FocusPtr.ClientList.Count Then BarPos := FocusPtr.ClientList.Count;
                        If TopPage < 1 Then TopPage := 1;
                        UpdateConnectionList;
                      End;

                #80 : If (BarPos < FocusPtr.ClientMax) and (BarPos < TopPage + 7) Then Begin
                        Inc(BarPos);
                        UpdateConnectionList;
                      End Else
                      If (TopPage + 7 < FocusPtr.ClientMax) Then Begin
                        Inc(TopPage);
                        Inc(BarPos);
                        UpdateConnectionList;
                      End;
              End;
        #09 : Begin { TAB = cycle view tabs }
              ActiveTab := (ActiveTab + 1) mod TAB_COUNT;
              DrawTabScreen(ActiveTab);
              { Force immediate content update for new tab }
              Case ActiveTab of
                TAB_MESSAGES    : If FocusPtr <> NIL Then FocusPtr.StatusUpdated := True;
                TAB_CONNECTIONS : UpdateConnectionList;
                TAB_EVENTS      : If Assigned(EventThread) Then EventThread.Updated := True;
              End;
            End;
        '+' : SwitchFocus; { + = cycle service focus }
//        #13 : {$IFDEF UNIX}Snoop{$ENDIF};
        #27 : ShowESCMenu;
      End;

    If ShutdownRequested Then Break;

    If (FocusPtr <> NIL) Then
      If FocusPtr.StatusUpdated Then Begin
        UpdateStatus;
        Count := 1;
      End Else
      If Count = 10 Then Begin  // force update every 10 seconds since mystic
        UpdateStatus;           // cannot yet talk to MIS directly
        Count := 1;
      End Else
        Inc (Count);
  Until False;

  Console.TextAttr := 7;

  Console.ClearScreen;

  Console.WriteLine ('Mystic Internet Server Version ' + mysVersion);
  Console.WriteLine ('');

  { 1.12: Log shutdown to server status before freeing }
  If FocusPtr <> NIL Then
    FocusPtr.Status(-1, 'Server shutdown received from console');

  Console.WriteStr  ('Shutting down servers: TELNET');

  If FocusPtr <> NIL Then FocusPtr.Status(-1, 'Shutdown: TELNET');
  TelnetServer.Free;

  Console.WriteStr (' SMTP');
  SMTPServer.Free;

  Console.WriteStr (' POP3');
  POP3Server.Free;

  Console.WriteStr (' FTP');
  FTPServer.Free;

  Console.WriteStr (' NNTP');
  NNTPServer.Free;

  Console.WriteStr (' BINKP');
  BINKPServer.Free;
  If HTTPServer <> NIL Then HTTPServer.Free;

  Console.WriteLine (' (DONE)');

  Console.WriteLine ('Shutdown complete');

  // Restore console from tray before exit
  If TrayMode Then Tray.UnTrayConsole;
  Tray.Free;

  NodeData.Free;

  // A38 fork: release the MIS running-lock so the next launch can start.
  If FileExist(bbsCfg.SemaPath + fn_SemFileMisBusy) Then
    FileErase(bbsCfg.SemaPath + fn_SemFileMisBusy);

  Halt(255);
End.
