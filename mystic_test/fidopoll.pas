Program FidoPoll;

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

Uses
  DOS,
  m_Crypt,
  m_DateTime,
  m_FileIO,
  m_Strings,
  m_IO_Sockets,
  m_Protocol_Queue,
  m_tcp_Client_FTP,
  BBS_Records,
  BBS_DataBase,
  MIS_Client_BINKP;

Var
  TempPath : String;

// A42: create the echomail.in semaphore after receiving files, so MIS/MUTIL
// knows to run an import cycle.  Called after any successful poll (BINKP/FTP/Dir).
Procedure CreateEchoSema;
Var SF : File;
Begin
  Assign (SF, bbsCfg.SemaPath + 'echomail.in');
  {$I-} ReWrite (SF, 1); {$I+}
  If IOResult = 0 Then Close (SF);
End;

// A44: queue files from the node's outbound FileBox (if enabled).
// UseFileBox: 0=No, 1=Hold (only when they connect to us), 2=Any (always).
// Files are deleted after successful transmission.
Procedure QueueFileBox (Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode);
Var
  DirInfo : SearchRec;
  BoxPath : String;
Begin
  If EchoNode.UseFileBox < 2 Then Exit;  // 0=No, 1=Hold (inbound only)
  If EchoNode.OutFileBox = '' Then Exit;

  BoxPath := DirLast(EchoNode.OutFileBox);

  FindFirst (BoxPath + '*', AnyFile, DirInfo);
  While DosError = 0 Do Begin
    If (DirInfo.Attr And Directory) = 0 Then
      Queue.Add (False, BoxPath, DirInfo.Name, '');
    FindNext (DirInfo);
  End;
  FindClose (DirInfo);
End;

// Delete successfully sent FileBox files after a poll.
Procedure CleanFileBox (Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode);
Var
  Count   : LongInt;
  BoxPath : String;
Begin
  If EchoNode.UseFileBox < 2 Then Exit;
  If EchoNode.OutFileBox = '' Then Exit;

  BoxPath := DirLast(EchoNode.OutFileBox);

  For Count := 0 to Queue.QSize - 1 Do
    If Queue.QData[Count].FilePath = BoxPath Then
      FileErase (BoxPath + Queue.QData[Count].FileName);
End;

Procedure PrintStatus (Owner: Pointer; Level: Byte; Str: String);
Var
  TF : Text;
Begin
  If Level = 1 Then
    WriteLn (Str)
  Else
    Str := '   ' + Str;

  Str      := FormatDate(CurDateDT, 'NNN DD HH:II') + ' ' + Str;
  FileMode := 66;

  Assign (TF, bbsCfg.LogsPath + 'fidopoll.log');

  {$I-} Append (TF); {$I+}

  If (IoResult <> 0) and (IoResult <> 5) Then
    {$I-} ReWrite(TF); {$I+}

  If IoResult = 0 Then Begin
    WriteLn (TF, Str);
    Close   (TF);
  End;
End;

Function PollNodeFTP (OnlyNew: Boolean; Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode) : Boolean;
Var
  FTP : TFTPClient;

  Function ExistsOnServer (Str: String) : Boolean;
  Var
    Count : LongInt;
  Begin
    Result := False;

//    writeln ('debug checking exists ', str, '  files:', ftp.responsedata.count);

    For Count := 1 to FTP.ResponseData.Count Do Begin
//      writeln('debug    remote: ', FTP.ResponseData.Strings[Count - 1]);

      If strUpper(JustFile(Str)) = strUpper(FTP.ResponseData.Strings[Count - 1]) Then Begin
        Result := True;

        Break;
      End;
    End;
  End;

Var
  Count  : LongInt;
  OldFN  : String;
  NewFN  : String;
  IsDupe : Boolean;
Begin
  Result := False;

  Queue.Clear;

  PrintStatus (NIL, 1, 'Scanning ' + Addr2Str(EchoNode.Address));

  QueueByNode (Queue, True, EchoNode);

  PrintStatus (NIL, 1, 'Queued ' + strI2S(Queue.QSize) + ' files (' + strI2S(Queue.QFSize) + ' bytes) to ' + Addr2Str(EchoNode.Address));

  If OnlyNew and (Queue.QSize = 0) Then Exit;

  PrintStatus (NIL, 1, 'Polling FTP node ' + Addr2Str(EchoNode.Address));

  If EchoNode.ftpOutHost = '' Then Begin
    PrintStatus (NIL, 1, 'FTP hostname is blank, skipping');
    Exit;
  End;

  FTP := TFTPClient.Create(bbsCfg.iNetInterface);

  If FTP.OpenConnection(EchoNode.ftpOutHost) Then Begin
    PrintStatus (NIL, 1, 'Connected');

    If FTP.Authenticate(EchoNode.ftpOutLogin, EchoNode.ftpOutPass) Then Begin
      If FTP.GetDirectoryList(EchoNode.ftpPassive, True, EchoNode.ftpInDir) Then Begin
        For Count := 1 to FTP.ResponseData.Count Do Begin
          PrintStatus (NIL, 1, 'Receiving ' + FTP.ResponseData.Strings[Count - 1]);

          If FTP.GetFile (EchoNode.ftpPassive, bbsCfg.InboundPath + FTP.ResponseData.Strings[Count - 1]) = ftpResOK Then Begin
            If FTP.SendCommand('DELE ' + FTP.ResponseData.Strings[Count - 1]) <> 250 Then Begin
              PrintStatus (NIL, 1, 'Unable to delete from server ' + FTP.ResponseData.Strings[Count - 1]);
              FileErase(bbsCfg.InboundPath + FTP.ResponseData.Strings[Count - 1]);
            End;
          End Else
            PrintStatus (NIL, 1, 'Failed');
        End;
      End Else
        PrintStatus (NIL, 1, 'Unable to list ' + EchoNode.ftpInDir);

      If Queue.QSize > 0 Then Begin
        If FTP.GetDirectoryList(EchoNode.ftpPassive, True, EchoNode.ftpOutDir) Then Begin
          For Count := 1 to Queue.QSize Do Begin
            OldFN  := Queue.QData[Count]^.FileNew;
            NewFN  := OldFN;
            IsDupe := False;

            Repeat
              If ExistsOnServer(NewFN) Then Begin
                NewFN := GetFTNBundleExt(True, NewFN);

                If NewFN = OldFN Then Begin
                  IsDupe := True;

                  Break;
                End;
              End Else
                Break;
            Until False;

            If IsDupe Then
              PrintStatus (NIL, 1, 'Cannot send ' + OldFN + '; already exists')
            Else Begin
              PrintStatus (NIL, 1, 'Sending ' + OldFN + ' as ' + NewFN);

              If FTP.SendFile(EchoNode.ftpPassive, Queue.QData[Count]^.FilePath + Queue.QData[Count]^.FileName, NewFN) = ftpResOK Then Begin
                // only remove by markings... or move to removefilesfromflo
                FileErase          (Queue.QData[Count]^.FilePath + Queue.QData[Count]^.FileName);
                RemoveFilesFromFLO (GetFTNOutPath(EchoNode), TempPath, Queue.QData[Count]^.FilePath + Queue.QData[Count]^.FileName);
              End Else
                PrintStatus (NIL, 1, 'Failed');
            End;
          End;
        End Else
          PrintStatus (NIL, 1, 'Unable to list ' + EchoNode.ftpOutDir);
      End;
    End Else
      PrintStatus (NIL, 1, 'Unable to authenticate');
  End Else
    PrintStatus (NIL, 1, 'Unable to connect');

  PrintStatus (NIL, 1, 'Session complete');

  FTP.Free;
End;

Function PollNodeDirectory (OnlyNew: Boolean; Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode) : Boolean;
Var
  Count   : LongInt;
  DirInfo : SearchRec;
  PKTName : String;
  NewName : String;
  OutPath : String;
Begin
  Result := False;

  Queue.Clear;

  PrintStatus (NIL, 1, 'Scanning ' + Addr2Str(EchoNode.Address));

  QueueByNode (Queue, False, EchoNode);

  PrintStatus(NIL, 1, 'Queued ' + strI2S(Queue.QSize) + ' files (' + strI2S(Queue.QFSize) + ' bytes) to ' + Addr2Str(EchoNode.Address));

  If OnlyNew and (Queue.QSize = 0) Then Exit;

  PrintStatus(NIL, 1, 'Polling DIRECTORY node ' + Addr2Str(EchoNode.Address));

  OutPath := GetFTNOutPath(EchoNode);

  For Count := 1 to Queue.QSize Do Begin
    PKTName := Queue.QData[Count]^.FilePath + Queue.QData[Count]^.FileName;
    NewName := GetFTNBundleExt(False, EchoNode.DirInDir + Queue.QData[Count]^.FileNew);

    PrintStatus (NIL, 1, 'Move ' + PKTName + ' to ' + NewName);

    If (Not FileExist(NewName)) And FileReName(PKTName, NewName) Then
      RemoveFilesFromFLO (OutPath, TempPath, PKTName)
    Else
      PrintStatus (NIL, 1, 'Failed to move to ' + NewName);
  End;

  FindFirst (EchoNode.DirOutDir + '*', AnyFile, DirInfo);

  While DosError = 0 Do Begin
    If DirInfo.Attr And Directory = 0 Then Begin
      PrintStatus (NIL, 1, 'Move ' + EchoNode.DirOutDir + DirInfo.Name + ' to ' + bbsCfg.InboundPath);

      If (Not FileExist(bbsCfg.InboundPath + DirInfo.Name)) and (Not FileReName(EchoNode.DirOutDir + DirInfo.Name, bbsCfg.InboundPath + DirInfo.Name)) Then
        PrintStatus (NIL, 1, 'Failed to move to ' + EchoNode.DirOutDir + DirInfo.Name);
    End;

    FindNext (DirInfo);
  End;

  FindClose (DirInfo);
End;

Function PollNodeBINKP (OnlyNew: Boolean; Var Queue: TProtocolQueue; Var EchoNode: RecEchoMailNode) : Boolean;
Var
  BinkP  : TBinkP;
  Client : TIOSocket;
  Port   : Word;
Begin
  Result := False;

  Queue.Clear;

  PrintStatus(NIL, 1, 'Scanning ' + Addr2Str(EchoNode.Address));

  QueueByNode (Queue, True, EchoNode);

  PrintStatus(NIL, 1, 'Queued ' + strI2S(Queue.QSize) + ' files (' + strI2S(Queue.QFSize) + ' bytes) to ' + Addr2Str(EchoNode.Address));

  If OnlyNew and (Queue.QSize = 0) Then Exit;

  PrintStatus(NIL, 1, 'Polling BINKP node ' + Addr2Str(EchoNode.Address));

  If EchoNode.binkHost = '' Then Begin
    PrintStatus (NIL, 1, 'BINKP hostname is blank, skipping');
    Exit;
  End;

  Client := TIOSocket.Create;

  Client.FTelnetClient := False;
  Client.FTelnetServer := False;

  PrintStatus (NIL, 1, 'Connecting to ' + EchoNode.binkHost);

  Port := strS2I(strWordGet(2, EchoNode.binkHost, ':'));

  If Port = 0 Then Port := 24554;

  If Not Client.Connect (strWordGet(1, EchoNode.binkHost, ':'), Port) Then Begin
    PrintStatus (NIL, 1, 'UNABLE TO CONNECT');

    Client.Free;

    Exit;
  End;

  PrintStatus(NIL, 1, 'Connected');

  BinkP := TBinkP.Create(Client, Client, Queue, True, EchoNode.binkTimeOut * 100);

  BinkP.StatusUpdate := @PrintStatus;
  BinkP.SetOutPath   := GetFTNOutPath(EchoNode);
  BinkP.SetPassword  := EchoNode.binkPass;
  BinkP.SetBlockSize := EchoNode.binkBlock;
  BinkP.UseMD5       := EchoNode.binkMD5 > 0;
  BinkP.ForceMD5     := EchoNode.binkMD5 = 2;
  BinkP.HideAKAs     := EchoNode.binkHideAKA;
  BinkP.HideSource   := EchoNode.Domain;  // A43: use domain, not zone

  If BinkP.DoAuthentication Then Begin
    Result := True;

    BinkP.DoTransfers;
  End;

  BinkP.Free;
  Client.Free;
End;

Function PollByAddress (Addr: String) : Boolean;
Var
  Queue    : TProtocolQueue;
  PollTime : LongInt;
  EchoNode : RecEchoMailNode;
Begin
  PollTime := CurDateDos;
  Queue    := TProtocolQueue.Create;

  Result := GetNodeByAddress(Addr, EchoNode);

  If Result And EchoNode.Active Then Begin
    QueueFileBox (Queue, EchoNode);

    Case EchoNode.ProtType of
      0 : If PollNodeBINKP(False, Queue, EchoNode) Then Begin
            EchoNode.LastSent := PollTime;
            CreateEchoSema;
            CleanFileBox (Queue, EchoNode);
          End;
      1 : If PollNodeFTP(False, Queue, EchoNode) Then Begin
            EchoNode.LastSent := PollTime;
            CreateEchoSema;
            CleanFileBox (Queue, EchoNode);
          End;
      2 : If PollNodeDirectory(False, Queue, EchoNode) Then Begin
            EchoNode.LastSent := PollTime;
            CreateEchoSema;
            CleanFileBox (Queue, EchoNode);
          End;
    End;

    // needs to save updated polltime
  End Else
    Result := False;

  Queue.Free;
End;

Procedure PollAll (OnlyNew: Boolean);
Var
  Queue    : TProtocolQueue;
  EchoFile : File of RecEchoMailNode;
  EchoNode : RecEchoMailNode;
  Total    : LongInt;
  PollTime : LongInt;
  Res      : Boolean;
Begin
  PollTime := CurDateDos;

  WriteLn ('Polling nodes...');
  WriteLn;

  Total := 0;
  Queue := TProtocolQueue.Create;

  Assign (EchoFile, bbsCfg.DataPath + 'echonode.dat');
  {$I-} Reset (EchoFile); {$I+}

  If IoResult <> 0 Then Exit;

  While Not Eof(EchoFile) Do Begin
    Read (EchoFile, EchoNode);

    If EchoNode.Active Then Begin
      QueueFileBox (Queue, EchoNode);

      Case EchoNode.ProtType of
        0 : Res := PollNodeBINKP(OnlyNew, Queue, EchoNode);
        1 : Res := PollNodeFTP(OnlyNew, Queue, EchoNode);
        2 : Res := PollNodeDirectory(False, Queue, EchoNode);
      End;

      If Res Then Begin
        Inc (Total);

        EchoNode.LastSent := PollTime;
        CreateEchoSema;
        CleanFileBox (Queue, EchoNode);

        Seek  (EchoFile, FilePos(EchoFile) - 1);
        Write (EchoFile, EchoNode);
      End;
    End;
  End;

  Close (EchoFile);

  Queue.Free;

  WriteLn;
  PrintStatus (NIL, 1, 'Polled ' + strI2S(Total) + ' nodes');
End;

// A43: list all active echomail nodes with description, address, and session type.
Procedure ListNodes;
Var
  EchoFile : File of RecEchoMailNode;
  EchoNode : RecEchoMailNode;
  TypeStr  : String;
Begin
  WriteLn ('Active echomail nodes:');
  WriteLn;
  WriteLn ('  Description                           Address          Type      Domain');
  WriteLn ('  ' + strRep('-', 72));

  Assign (EchoFile, bbsCfg.DataPath + 'echonode.dat');
  {$I-} Reset (EchoFile); {$I+}
  If IOResult <> 0 Then Begin WriteLn ('  No echomail nodes configured.'); Exit; End;

  While Not Eof(EchoFile) Do Begin
    Read (EchoFile, EchoNode);
    If Not EchoNode.Active Then Continue;

    Case EchoNode.ProtType of
      0 : TypeStr := 'BinkP';
      1 : TypeStr := 'FTP';
      2 : TypeStr := 'Dir';
    Else  TypeStr := '?';
    End;

    WriteLn ('  ' + strPadR(EchoNode.Description, 40, ' ') + strPadR(Addr2Str(EchoNode.Address), 17, ' ') + strPadR(TypeStr, 10, ' ') + EchoNode.Domain);
  End;

  Close (EchoFile);
End;

// A43: show configured netmail routing priority.
Procedure ShowRoute (FilterAddr: String);
Var
  EchoFile : File of RecEchoMailNode;
  EchoNode : RecEchoMailNode;
Begin
  WriteLn ('Netmail routing priority (top-down):');
  WriteLn;
  WriteLn ('  Node                Route Info');
  WriteLn ('  ' + strRep('-', 60));

  Assign (EchoFile, bbsCfg.DataPath + 'echonode.dat');
  {$I-} Reset (EchoFile); {$I+}
  If IOResult <> 0 Then Exit;

  While Not Eof(EchoFile) Do Begin
    Read (EchoFile, EchoNode);
    If Not EchoNode.Active Then Continue;
    If EchoNode.RouteInfo = '' Then Continue;
    If (FilterAddr <> '') and (Pos(FilterAddr, strUpper(Addr2Str(EchoNode.Address))) = 0) and
       (Pos(FilterAddr, strUpper(EchoNode.RouteInfo)) = 0) Then Continue;

    WriteLn ('  ' + strPadR(Addr2Str(EchoNode.Address), 20, ' ') + EchoNode.RouteInfo);
  End;

  Close (EchoFile);
End;

// A43: poll only nodes matching a session type filter (binkp/ftp/dir).
Procedure PollFiltered (OnlyNew: Boolean; TypeFilter: LongInt);
Var
  Queue    : TProtocolQueue;
  EchoFile : File of RecEchoMailNode;
  EchoNode : RecEchoMailNode;
  Total    : LongInt;
  PollTime : LongInt;
  Res      : Boolean;
Begin
  PollTime := CurDateDos;
  Total    := 0;
  Queue    := TProtocolQueue.Create;

  WriteLn ('Polling nodes (type filter: ', TypeFilter, ')...');

  Assign (EchoFile, bbsCfg.DataPath + 'echonode.dat');
  {$I-} Reset (EchoFile); {$I+}
  If IOResult <> 0 Then Begin Queue.Free; Exit; End;

  While Not Eof(EchoFile) Do Begin
    Read (EchoFile, EchoNode);

    If EchoNode.Active and ((TypeFilter = -1) or (EchoNode.ProtType = TypeFilter)) Then Begin
      Case EchoNode.ProtType of
        0 : Res := PollNodeBINKP(OnlyNew, Queue, EchoNode);
        1 : Res := PollNodeFTP(OnlyNew, Queue, EchoNode);
        2 : Res := PollNodeDirectory(False, Queue, EchoNode);
      End;

      If Res Then Begin
        Inc (Total);
        EchoNode.LastSent := PollTime;
        CreateEchoSema;
        Seek  (EchoFile, FilePos(EchoFile) - 1);
        Write (EchoFile, EchoNode);
      End;
    End;
  End;

  Close (EchoFile);
  Queue.Free;

  WriteLn;
  PrintStatus (NIL, 1, 'Polled ' + strI2S(Total) + ' nodes');
End;

// A43: poll only uplink nodes (nodes with RouteInfo set = they route for us).
Procedure PollUplinks (TypeFilter: LongInt);
Var
  Queue    : TProtocolQueue;
  EchoFile : File of RecEchoMailNode;
  EchoNode : RecEchoMailNode;
  Total    : LongInt;
  PollTime : LongInt;
  Res      : Boolean;
Begin
  PollTime := CurDateDos;
  Total    := 0;
  Queue    := TProtocolQueue.Create;

  WriteLn ('Polling uplink nodes...');

  Assign (EchoFile, bbsCfg.DataPath + 'echonode.dat');
  {$I-} Reset (EchoFile); {$I+}
  If IOResult <> 0 Then Begin Queue.Free; Exit; End;

  While Not Eof(EchoFile) Do Begin
    Read (EchoFile, EchoNode);

    If EchoNode.Active and (EchoNode.RouteInfo <> '') and
       ((TypeFilter = -1) or (EchoNode.ProtType = TypeFilter)) Then Begin
      Case EchoNode.ProtType of
        0 : Res := PollNodeBINKP(False, Queue, EchoNode);
        1 : Res := PollNodeFTP(False, Queue, EchoNode);
        2 : Res := PollNodeDirectory(False, Queue, EchoNode);
      End;

      If Res Then Begin
        Inc (Total);
        EchoNode.LastSent := PollTime;
        CreateEchoSema;
        Seek  (EchoFile, FilePos(EchoFile) - 1);
        Write (EchoFile, EchoNode);
      End;
    End;
  End;

  Close (EchoFile);
  Queue.Free;

  WriteLn;
  PrintStatus (NIL, 1, 'Polled ' + strI2S(Total) + ' uplink nodes');
End;

// A43: delete BSY (busy) lock files from BSO outbound directories.
Procedure KillBusy (Mode: String);
Var
  EchoFile : File of RecEchoMailNode;
  EchoNode : RecEchoMailNode;
  OutPath  : String;
  DirInfo  : SearchRec;
  Total    : LongInt;
Begin
  Total := 0;
  Mode  := strUpper(Mode);

  If (Mode = '') Then Mode := 'ECHO';

  WriteLn ('Removing BSY files (mode: ', Mode, ')...');

  // application-level BSY (tempftn/*.bsy)
  If (Mode = 'APP') or (Mode = 'ALL') Then Begin
    FindFirst (bbsCfg.SystemPath + 'tempftn' + PathChar + '*.bsy', AnyFile, DirInfo);
    While DosError = 0 Do Begin
      FileErase (bbsCfg.SystemPath + 'tempftn' + PathChar + DirInfo.Name);
      Inc (Total);
      FindNext (DirInfo);
    End;
    FindClose (DirInfo);
  End;

  // echomail BSO BSY files (per-node outbound dirs)
  If (Mode = 'ECHO') or (Mode = 'ALL') Then Begin
    Assign (EchoFile, bbsCfg.DataPath + 'echonode.dat');
    {$I-} Reset (EchoFile); {$I+}
    If IOResult = 0 Then Begin
      While Not Eof(EchoFile) Do Begin
        Read (EchoFile, EchoNode);
        If Not EchoNode.Active Then Continue;

        OutPath := GetFTNOutPath(EchoNode);

        FindFirst (OutPath + '*.bsy', AnyFile, DirInfo);
        While DosError = 0 Do Begin
          FileErase (OutPath + DirInfo.Name);
          WriteLn ('  Removed: ', OutPath, DirInfo.Name);
          Inc (Total);
          FindNext (DirInfo);
        End;
        FindClose (DirInfo);
      End;
      Close (EchoFile);
    End;
  End;

  WriteLn ('  ', Total, ' BSY file(s) removed.');
End;

// Parse session type string to ProtType value (-1 = all).
Function ParseTypeFilter (S: String) : LongInt;
Begin
  S := strUpper(strStripB(S, ' '));
  If (S = 'BINKP') or (S = 'BINK')  Then Result := 0
  Else If (S = 'FTP')                Then Result := 1
  Else If (S = 'DIR') or (S = 'DIRECTORY') Then Result := 2
  Else Result := -1;
End;

// A43: search the raw FTN nodelist (nodelist.txt) for matching entries.
// Matches against address, BBS name, location, sysop name, phone, or flags.
Procedure SearchNodeList (SearchStr: String);
Var
  NL      : Text;
  Line    : String;
  SU      : String;
  Zone    : Word;
  Net     : Word;
  Node    : Word;
  AddrStr : String;
  Fields  : Array[1..8] of String;
  FCount  : Byte;
  I       : Byte;
  P       : LongInt;
  Hits    : LongInt;

  Procedure ParseFields (Const S: String);
  Var C: LongInt; F: Byte;
  Begin
    FCount := 1;
    Fields[1] := '';
    For C := 1 to Length(S) Do
      If S[C] = ',' Then Begin
        If FCount < 8 Then Begin Inc(FCount); Fields[FCount] := ''; End;
      End Else
        Fields[FCount] := Fields[FCount] + S[C];
  End;

Begin
  SearchStr := strUpper(strStripB(SearchStr, ' '));

  If SearchStr = '' Then Begin
    WriteLn ('Usage: FIDOPOLL SEARCH <text>');
    WriteLn ('Searches nodelist.txt for matching BBS name, sysop, location, or address.');
    Exit;
  End;

  Assign (NL, bbsCfg.DataPath + 'nodelist.txt');
  {$I-} Reset (NL); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn ('Nodelist not found: ', bbsCfg.DataPath, 'nodelist.txt');
    Exit;
  End;

  WriteLn ('Searching nodelist for "', SearchStr, '"...');
  WriteLn;
  WriteLn ('  Address        BBS Name                   Location           SysOp');
  WriteLn ('  ' + strRep('-', 72));

  Zone := 1;
  Net  := 0;
  Hits := 0;

  While Not Eof(NL) Do Begin
    ReadLn (NL, Line);
    If (Line = '') or (Line[1] = ';') Then Continue;

    ParseFields(Line);
    If FCount < 6 Then Continue;

    SU := strUpper(Fields[1]);

    // Track current zone/net/host from the nodelist markers
    If SU = 'ZONE'   Then Begin Zone := strS2I(Fields[2]); Net := 0; End;
    If SU = 'REGION' Then Net := strS2I(Fields[2]);
    If SU = 'HOST'   Then Net := strS2I(Fields[2]);

    // Node entries have blank or 'Hub'/'Pvt'/'Hold'/'Down' in field 1
    If (SU = 'ZONE') or (SU = 'REGION') or (SU = 'HOST') Then
      Node := 0
    Else
      Node := strS2I(Fields[2]);

    AddrStr := strI2S(Zone) + ':' + strI2S(Net) + '/' + strI2S(Node);

    // Search all fields (case-insensitive)
    If (Pos(SearchStr, strUpper(AddrStr)) > 0) or
       (Pos(SearchStr, strUpper(Fields[3])) > 0) or
       (Pos(SearchStr, strUpper(Fields[4])) > 0) or
       (Pos(SearchStr, strUpper(Fields[5])) > 0) or
       (Pos(SearchStr, strUpper(Fields[6])) > 0) or
       ((FCount >= 8) and (Pos(SearchStr, strUpper(Fields[8])) > 0)) Then Begin
      // Replace underscores with spaces for display
      For I := 3 to 5 Do
        While Pos('_', Fields[I]) > 0 Do
          Fields[I][Pos('_', Fields[I])] := ' ';

      WriteLn ('  ' + strPadR(AddrStr, 17, ' ') + strPadR(Fields[3], 27, ' ') + strPadR(Fields[4], 19, ' ') + Fields[5]);
      Inc (Hits);
    End;
  End;

  Close (NL);
  WriteLn;
  WriteLn ('  ', Hits, ' match(es) found.');
End;

Var
  Str  : String;
  Str2 : String;
Begin
  FileMode := 66;

  WriteLn;
  WriteLn ('FIDOPOLL Version ' + mysVersion);
  WriteLn;

  Case bbsCfgStatus of
    CfgNotFound : Begin
                    WriteLn ('Unable to read MYSTIC.DAT');
                    Halt(1);
                  End;
    CfgMisMatch : Begin
                    WriteLn ('Mystic VERSION mismatch');
                    Halt(1);
                  End;
  End;

  If ParamCount = 0 Then Begin
    WriteLn ('Send and retrieve echomail packets for configured echomail nodes');
    WriteLn ('using BINKP, FTP, or Directory-based transmission.');
    WriteLn;
    WriteLn ('FIDOPOLL SEND            - Only send/poll if node has new outbound messages');
    WriteLn ('FIDOPOLL FORCED [Type]   - Poll/send to all nodes of session [Type] (Blank/All)');
    WriteLn ('FIDOPOLL UPLINK [Type]   - Poll all Uplink nodes of session [Type] (Blank/All)');
    WriteLn ('FIDOPOLL [Address]       - Poll/send echomail node [Address] (ex: 46:1/100)');
    WriteLn ('FIDOPOLL LIST            - List active echomail nodes');
    WriteLn ('FIDOPOLL ROUTE [Address] - Show configured netmail routing (Optional address)');
    WriteLn ('FIDOPOLL SEARCH [Text]   - Search nodelist for [Text]');
    WriteLn ('FIDOPOLL KILLBUSY [Mode] - Delete BSY files [App, Echo, All] (Blank/Echo)');

    Halt(1);
  End;

  TempPath := bbsCfg.SystemPath + 'tempftn' + PathChar;

  DirCreate(TempPath);

  Str := strUpper(strStripB(ParamStr(1), ' '));

  If ParamCount >= 2 Then
    Str2 := strStripB(ParamStr(2), ' ')
  Else
    Str2 := '';

  If Str = 'SEND' Then
    PollAll (True)
  Else
  If Str = 'FORCED' Then
    PollFiltered (False, ParseTypeFilter(Str2))
  Else
  If Str = 'UPLINK' Then
    PollUplinks (ParseTypeFilter(Str2))
  Else
  If Str = 'LIST' Then
    ListNodes
  Else
  If Str = 'ROUTE' Then
    ShowRoute (strUpper(Str2))
  Else
  If Str = 'SEARCH' Then
    SearchNodeList (Str2)
  Else
  If Str = 'KILLBUSY' Then
    KillBusy (Str2)
  Else
  If Not PollByAddress(Str) Then
    PrintStatus (NIL, 1, 'Invalid command line or address');
End.
