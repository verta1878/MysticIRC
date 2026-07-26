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

Unit MIS_Server;

{$I M_OPS.PAS}

Interface

Uses
  {$IFDEF GO32V2}
    sockets_go32v2,   // DOS: no RTL Sockets unit (see mdl/sockets_go32v2.pas)
  {$ELSE}
    Sockets,
  {$ENDIF}
  Classes,
  m_io_Base,
  m_io_Sockets,
  MIS_Common,
  MIS_NodeData,
  BBS_Records;

Const
  MaxStatusText = 20;

Type
  TServerManager    = Class;
  TServerClient     = Class;
  TServerCreateProc = Function (Manager: TServerManager; Cfg: RecConfig; ND: TNodeData; Client: TIOSocket): TServerClient;

  // A51: auto-ban tracking
  TBanTrack = Record
    IP   : String[45];
    Time : LongInt;
  End;

  TServerManager = Class(TThread)
    Critical      : TRTLCriticalSection;
    NodeInfo      : TNodeData;
    Server        : TIOSocket;
    ServerStatus  : TStringList;
    LogFile       : String[20];
    StatusUpdated : Boolean;
    ClientList    : TList;
    NewClientProc : TServerCreateProc;
    Config        : RecConfig;
    ClientMax     : LongInt;
    ClientMaxIPs  : LongInt;
    ClientRefused : LongInt;
    ClientBlocked : LongInt;
    ClientTotal   : LongInt;
    ClientActive  : LongInt;
    Port          : LongInt;
    TextPath      : String[80];
    BanMaxConns   : Byte;
    BanTimeSecs   : Word;
    BanTrack      : Array[0..255] of TBanTrack;
    BanTrackCount : Word;

    Constructor Create       (Cfg: RecConfig; PortNum: Word; CliMax: Word; ND: TNodeData; CreateProc: TServerCreateProc);
    Destructor  Destroy;     Override;
    Procedure   Execute;     Override;
    Procedure   Status       (ProcID: LongInt; Str: String);
    Function    CheckIP      (IP, Mask: String) : Boolean;
    Function    IsBlockedIP  (Var Client: TIOSocket) : Boolean;
    Function    IsFloodIP    (IP: String) : Boolean;
    Function    DuplicateIPs (Var Client: TIOSocket) : Byte;
  End;

  TServerClient = Class(TThread)
    Client    : TIOSocket;
    Manager   : TServerManager;
    ProcessID : LongInt;

    Constructor Create (Owner: TServerManager; CliSock: TIOSocket);
    Destructor  Destroy; Override;
  End;

Implementation

Uses
  m_Strings,
  m_DateTime;

Constructor TServerManager.Create (Cfg: RecConfig; PortNum: Word; CliMax: Word; ND: TNodeData; CreateProc: TServerCreateProc);
Var
  Count : Byte;
Begin
  Inherited Create(False);

  InitCriticalSection(Critical);

  Port          := PortNum;
  ClientMax     := CliMax;
  ClientRefused := 0;
  ClientBlocked := 0;
  ClientTotal   := 0;
  ClientActive  := 0;
  ClientMaxIPs  := 1;
  NewClientProc := CreateProc;
  Server        := TIOSocket.Create;
  ServerStatus  := TStringList.Create;
  StatusUpdated := False;
  ClientList    := TList.Create;
  TextPath      := Cfg.DataPath;
  NodeInfo      := ND;
  Config        := Cfg;
  LogFile       := '';

  For Count := 1 to ClientMax Do
    ClientList.Add(NIL);

  FreeOnTerminate := False;

  BanMaxConns   := 0;
  BanTimeSecs   := 0;
  BanTrackCount := 0;
End;

Function TServerManager.CheckIP (IP, Mask: String) : Boolean;
Var
  A     : Byte;
  Count : Byte;
  Str   : String;
  Str2  : String;
Begin
  Result := True;

  For Count := 1 to 4 Do Begin
    If Count < 4 Then Begin
      Str  := Copy(IP, 1, Pos('.', IP) - 1);
      Str2 := Copy(Mask, 1, Pos('.', Mask) - 1);
      Delete (IP, 1, Pos('.', IP));
      Delete (Mask, 1, Pos('.', Mask));
    End Else Begin
      Str  := Copy(IP, 1, Length(IP));
      Str2 := Copy(Mask, 1, Length(Mask));
    End;

    For A := 1 to Length(Str) Do
      If Str2[A] = '*' Then
        Break
      Else
      If Str[A] <> Str2[A] Then Begin
        Result := False;
        Break;
      End;

    If Not Result Then Break;
  End;
End;

Function TServerManager.IsBlockedIP (Var Client: TIOSocket) : Boolean;
Var
  TF     : Text;
  Str    : String;
  Res    : String;
  Count  : Byte;
  SIN    : TINetSockAddr;
  CC     : Word;
  Buffer : Array[1..8 * 1024] of Char;
Begin
  Result   := False;
  FileMode := 66;

  // A60: goodip.txt whitelist — exempt from badip, DNSBL, DNSCC, and auto-ban
  Assign     (TF, TextPath + 'goodip.txt');
  SetTextBuf (TF, Buffer);
  {$I-} Reset (TF); {$I+}

  If IoResult = 0 Then Begin
    While Not Eof(TF) Do Begin
      ReadLn (TF, Str);

      If CheckIP (Client.PeerIP, Str) Then Begin
        Close (TF);
        Exit;  // whitelisted — skip all blocking checks
      End;
    End;

    Close (TF);
  End;

  Assign     (TF, TextPath + 'badip.txt');
  SetTextBuf (TF, Buffer);
  Reset      (TF);

  If IoResult = 0 Then Begin
    While Not Eof(TF) Do Begin
      ReadLn (TF, Str);

      If CheckIP (Client.PeerIP, Str) Then Begin
        Result := True;
        Break;
      End;
    End;

    Close (TF);
  End;

  Str := '';

  For Count := 4 DownTo 1 Do Begin
    Str := Str + strWordGet(Count, Client.FPeerIP, '.');

    If Count <> 1 Then Str := Str + '.';
  End;

  If Not Result And Config.inetUseDNSBL And (Config.inetDNSBL <> '') Then Begin
    SIN.sin_addr.s_Addr := Client.ResolveAddress(Str + '.' + Config.iNetDNSBL);

    Res    := NetAddrToStr(SIN.sin_Addr);
    Result := Copy(Res, 1, 3) = '127';

    If Result Then
      Status (-1, 'Connection DNS blacklisted ' + Res);
  End;

  If Not Result and Config.inetUseDNSCC and (Config.inetDNSCC <> '') Then Begin
    SIN.sin_addr.s_Addr := Client.ResolveAddress(Str + '.' + Config.iNetDNSCC);

    Res := NetAddrToStr(SIN.sin_Addr);
    CC  := strS2I(strWordGet(3, Res, '.')) * 256 + strS2I(strWordGet(4, Res, '.'));

    IF CC <> 0 Then Begin
      Assign     (TF, TextPath + 'badcountry.txt');
      SetTextBuf (TF, Buffer);
      Reset      (TF);

      If IoResult = 0 Then Begin
        While Not Eof(TF) Do Begin
          ReadLn (TF, Str);

          If (Str = '') or ((Str[1] <> 'A') and (Str[1] <> 'B')) Then Continue;

          If strS2I(Copy(Str, 4, 3)) = CC Then Begin
            Status (-1, 'Connection from ' + Copy(Str, 9, 255));

            Result := Str[1] = 'B';

            Break;
          End;
        End;

        Close (TF);
      End;
    End;
  End;
End;

Function TServerManager.IsFloodIP (IP: String) : Boolean;
Var
  Count : Word;
  Now   : LongInt;
  Hits  : Byte;
Begin
  Result := False;
  If (BanMaxConns = 0) or (BanTimeSecs = 0) Then Exit;
  Now  := DateDos2Unix(CurDateDos);
  Hits := 0;
  For Count := 0 to BanTrackCount - 1 Do
    If (BanTrack[Count].IP = IP) and ((Now - BanTrack[Count].Time) <= BanTimeSecs) Then
      Inc(Hits);
  If BanTrackCount < 256 Then Begin
    BanTrack[BanTrackCount].IP   := IP;
    BanTrack[BanTrackCount].Time := Now;
    Inc(BanTrackCount);
  End Else Begin
    Move(BanTrack[1], BanTrack[0], SizeOf(TBanTrack) * 255);
    BanTrack[255].IP   := IP;
    BanTrack[255].Time := Now;
  End;
  Result := (Hits >= BanMaxConns);
End;

Function TServerManager.DuplicateIPs (Var Client: TIOSocket) : Byte;
Var
  Count : Byte;
Begin
  Result := 0;

  For Count := 0 to ClientMax - 1 Do
    If Assigned(ClientList[Count]) Then Begin
      If Client.PeerIP = TServerClient(ClientList[Count]).Client.FPeerIP Then
        Inc(Result);
    End;
End;

Procedure TServerManager.Status (ProcID: LongInt; Str: String);
Var
  Res : String;
  T   : Text;
Begin
  If ServerStatus = NIL Then Exit;

  EnterCriticalSection(Critical);

  Try
    If ServerStatus.Count > MaxStatusText Then
      ServerStatus.Delete(0);

    Res := FormatDate (CurDateDT, 'NNN DD HH:II') + ' ' + strI2S(ProcID + 1) + ' ' + Str;

    If Length(Res) > 74 Then Begin
      ServerStatus.Add(Copy(Res, 1, 74));

      If ServerStatus.Count > MaxStatusText Then
        ServerStatus.Delete(0);

      ServerStatus.Add(strRep(' ', 15) + Copy(Res, 75, 255));
    End Else
      ServerStatus.Add(Res);

    If Config.inetLogging And (LogFile <> '') Then Begin
      FileMode := 66;
      Assign (T, Config.LogsPath + 'server_' + LogFile + '.log');
      {$I-} Append (T); {$I+}
      If (IoResult <> 0) and (IoResult <> 5) Then
        {$I-} ReWrite(T); {$I+}
      If IoResult = 0 Then Begin
        WriteLn (T, Res);
        Close (T);
      End;
    End;

    StatusUpdated := True;
  Finally
    LeaveCriticalSection(Critical);
  End;
End;

Procedure TServerManager.Execute;
Var
  NewClient : TIOSocket;
Begin
  Repeat Until Server <> NIL;  // Synchronize with server class
  Repeat Until ServerStatus <> NIL; // Syncronize with status class

  // If the sysop never set an interface, say so plainly in the server log
  // (so they aren't left wondering why nothing binds) and fall back to all.
  If strStripB(Config.inetInterface, ' ') = '' Then Begin
    Status(-1, 'ERROR: Server interface not configured - using 0.0.0.0 (all interfaces). Set System Config -> Servers -> Interface.');
    Config.inetInterface := '0.0.0.0';
  End;

  Server.WaitInit(Config.inetInterface, Port);

  If Terminated Then Exit;

  If ClientMax = 0 Then
  	Status(-1, 'WARNING: At least one server is configured 0 max clients');

  Status(-1, 'Opening server socket on port ' + strI2S(Port));

  Repeat
    NewClient := Server.WaitConnection(1000);

    If NewClient = NIL Then Begin
      If Terminated Then Break;  // clean shutdown
      Continue;                   // timeout, loop back and listen again
    End;

    If (ClientMax > 0) And (ClientActive >= ClientMax) Then Begin
      Inc (ClientRefused);

      Status (-1, 'BUSY: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');

      If Not NewClient.WriteFile('', TextPath + 'busy.txt') Then
        NewClient.WriteLine('BUSY');

      WaitMS(3000);

      NewClient.Free;
    End Else
    If IsBlockedIP(NewClient) Then Begin
      Inc (ClientBlocked);

      Status(-1, 'BLOCK: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');

      If Not NewClient.WriteFile('', TextPath + 'blocked.txt') Then
        NewClient.WriteLine('BLOCKED');

      WaitMS(3000);

      NewClient.Free;
    End Else
    If IsFloodIP(NewClient.PeerIP) Then Begin
      Inc (ClientBlocked);

      Status(-1, 'FLOOD: ' + NewClient.PeerIP + ' (auto-banned)');

      NewClient.Free;
    End Else
    If (ClientMaxIPs > 0) and (DuplicateIPs(NewClient) >= ClientMaxIPs) Then Begin
      Inc (ClientRefused);

      Status(-1, 'MULTI: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');

      If Not NewClient.WriteFile('', TextPath + 'dupeip.txt') Then
        NewClient.WriteLine('Only ' + strI2S(ClientMaxIPs) + ' connection(s) per user');

      WaitMS(3000);

      NewClient.Free;
    End Else Begin
      Inc (ClientTotal);
      Inc (ClientActive);

      Status (-1, 'Connect: ' + NewClient.PeerIP + ' (' + NewClient.PeerName + ')');

      NewClientProc(Self, Config, NodeInfo, NewClient);
    End;
  Until Terminated;

  Status (-1, 'Shutting down server...');
End;

Destructor TServerManager.Destroy;
Var
  Count : LongInt;
  Angry : Byte;
Begin
  Angry := 20; // about 5 seconds before we get mad at thread...

  ClientList.Pack;

  While (ClientList.Count > 0) and (Angry > 0) Do Begin
    For Count := 0 To ClientList.Count - 1 Do
      If ClientList[Count] <> NIL Then Begin
        TServerClient(ClientList[Count]).Client.Disconnect;
        TServerClient(ClientList[Count]).Terminate;
      End;

    WaitMS(250);

    Dec (Angry);

    ClientList.Pack;
  End;

  DoneCriticalSection(Critical);

  ClientList.Free;
  ServerStatus.Free;
  Server.Free;

  Inherited Destroy;
End;

Constructor TServerClient.Create (Owner: TServerManager; CliSock: TIOSocket);
Var
  Count : Byte;
Begin
  Manager := Owner;
  Client  := CliSock;

  For Count := 0 to Manager.ClientMax - 1 Do
    If Manager.ClientList[Count] = NIL Then Begin
      Manager.ClientList[Count] := Self;
      ProcessID := Count;
      Break;
    End;

  Inherited Create(False);

  FreeOnTerminate := True;
End;

Destructor TServerClient.Destroy;
Begin
  Client.Free;

  Manager.ClientList[Manager.ClientList.IndexOf(Self)] := NIL;

  If Manager.Server <> NIL Then
    Manager.StatusUpdated := True;

  Dec (Manager.ClientActive);

  Inherited Destroy;
End;

End.
