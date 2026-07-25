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

Unit MIS_Client_Telnet;

{$I M_OPS.PAS}

Interface

{$IFDEF DARWIN}
  {$DEFINE USEPROCESS}
{$ELSE}
  {$IFDEF OS2}
    {$DEFINE USEPROCESS}   // OS/2: spawn per-node via TProcess (fcl-process),
                           // same model as Darwin - no fork(), no Win32 API
  {$ENDIF}
  {$IFDEF UNIX}
    {$DEFINE USEFORK}
  {$ENDIF}

  {$IFDEF USEFORK}
    // ForkPTY_Pure inlined below — pure FPC syscalls, no libc needed
  {$ENDIF}
{$ENDIF}

Uses
  {$IFDEF USEPROCESS}
    Process,
    m_DateTime,
  {$ENDIF}
  {$IFDEF UNIX}
    BaseUnix,
    Unix,
  {$ENDIF}
  {$IFDEF WINDOWS}
    Windows,
  {$ENDIF}
  {$IFDEF GO32V2}
    SysUtils,   // DOS: ExecuteProcess / GetEnvironmentVariable for single-node
  {$ENDIF}
  m_io_Base,
  m_io_Sockets,
  m_FileIO,
  m_Strings,
  MIS_Common,
  MIS_NodeData,
  MIS_Server,
  BBS_Records,
  BBS_DataBase;

{$IFDEF USEFORK}
  // ForkPTY_Pure is inlined in Implementation section
{$ENDIF}

Function CreateTelnet (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;

Type
  TTelnetServer = Class(TServerClient)
    ND : TNodeData;

    Constructor Create (Owner: TServerManager; NewND: TNodeData; CliSock: TIOSocket);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;
  End;

Implementation

// ====================================================================
// Inlined forkpty — pure FPC, no libc/libutil dependency
// Originally from uforkpty.pas (fpc264irc contributors, GPLv3)
// ====================================================================
{$IFDEF USEFORK}
Const
  PTY_O_RDWR   = $02;
  PTY_O_NOCTTY = $100;

Function ForkPTY_Pure (amaster: PLongInt; name: PChar;
  termp: Pointer; winp: Pointer): LongInt;
Var
  masterfd, slavefd : LongInt;
  ptsn              : LongInt;
  ptspath           : String[64];
  slavename         : Array[0..63] of Char;
  zero              : LongInt;
  pid               : LongInt;
Begin
  ForkPTY_Pure := -1;

  // Open master: /dev/ptmx
  masterfd := fpOpen('/dev/ptmx', PTY_O_RDWR or PTY_O_NOCTTY);
  If masterfd < 0 Then Exit;

  // grantpt + unlockpt via ioctl
  zero := 0;
  If fpIOCtl(masterfd, $5431, @zero) < 0 Then Begin // TIOCSPTLCK = unlock
    fpClose(masterfd);
    Exit;
  End;

  // ptsname via ioctl TIOCGPTN
  If fpIOCtl(masterfd, $80045430, @ptsn) < 0 Then Begin
    fpClose(masterfd);
    Exit;
  End;

  // Build slave path: /dev/pts/N
  Str(ptsn, ptspath);
  ptspath := '/dev/pts/' + ptspath;
  Move(ptspath[1], slavename[0], Length(ptspath));
  slavename[Length(ptspath)] := #0;

  // Open slave
  slavefd := fpOpen(@slavename[0], PTY_O_RDWR);
  If slavefd < 0 Then Begin
    fpClose(masterfd);
    Exit;
  End;

  // Fork
  pid := fpFork;
  If pid < 0 Then Begin
    fpClose(masterfd);
    fpClose(slavefd);
    Exit;
  End;

  If pid = 0 Then Begin
    // Child: attach slave PTY to stdin/stdout/stderr
    fpClose(masterfd);
    fpSetSid;
    fpIOCtl(slavefd, $540E, Nil); // TIOCSCTTY
    fpDup2(slavefd, 0);
    fpDup2(slavefd, 1);
    fpDup2(slavefd, 2);
    If slavefd > 2 Then fpClose(slavefd);
    ForkPTY_Pure := 0;
  End Else Begin
    // Parent: return master fd
    fpClose(slavefd);
    If amaster <> Nil Then amaster^ := masterfd;
    ForkPTY_Pure := pid;
  End;
End;
{$ENDIF}
// ====================================================================

Function CreateTelnet (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;
Begin
  Result := TTelnetServer.Create(Owner, ND, CliSock);
End;

Constructor TTelnetServer.Create (Owner: TServerManager; NewND: TNodeData; CliSock: TIOSocket);
Begin
  Inherited Create(Owner, CliSock);

  Self.ND := NewND;
End;

{$IFDEF WINDOWS}
Procedure TTelnetServer.Execute;
Var
  Cmd        : String;
  SI         : TStartupInfo;
  PI         : TProcessInformation;
  Num        : LongInt;
  NI         : TNodeInfoRec;
  PassHandle : LongInt;
Begin
  If Not DuplicateHandle (
    GetCurrentProcess,
    Client.FSocketHandle,
    GetCurrentProcess,
    @PassHandle,
    0,
    TRUE,
    DUPLICATE_SAME_ACCESS) Then Exit;

  Num := ND.GetFreeNode;
  Cmd := 'mystic.exe -n' + strI2S(Num) + ' -TID' + strI2S(PassHandle) + ' -IP' + Client.FPeerIP + ' -HOST' + Client.FPeerName + #0;

  FillChar(NI, SizeOf(NI), 0);

  NI.Num    := Num;
  NI.Busy   := True;
  NI.IP     := Client.FPeerIP;
  NI.User   := 'Unknown';
  NI.Action := 'Logging In';

  ND.SetNodeInfo(Num, NI);

  FillChar(SI, SizeOf(SI), 0);
  FillChar(PI, SizeOf(PI), 0);

  SI.dwFlags := STARTF_USESHOWWINDOW;

  If bbsCfg.inetTNHidden Then
    SI.wShowWindow := SW_HIDE
  Else
    SI.wShowWindow := SW_SHOWMINNOACTIVE;

  If CreateProcess(NIL, PChar(@Cmd[1]),
    NIL, NIL, True, Create_New_Console + Normal_Priority_Class, NIL, NIL, SI, PI) Then
      WaitForSingleObject (PI.hProcess, INFINITE);

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';

  ND.SetNodeInfo(Num, NI);

  FileErase (bbsCfg.DataPath + 'chat' + strI2S(Num) + '.dat');
End;
{$ENDIF}

{$IFDEF USEFORK}
Procedure TTelnetServer.Execute;
Var
  Num      : LongInt;
  NI       : TNodeInfoRec;
  PID      : LongInt;
  PTYFD    : LongInt;
  RDFDSET  : TFDSet;
  Count    : LongInt;
  Buffer   : Array[1..8 * 1024] of Char;
  MaxFD    : LongInt;
  WaitStat : LongInt;
Begin
  Client.FTelnetServer := True;

  Num := ND.GetFreeNode;

  PID := ForkPTY_Pure (@PTYFD, NIL, NIL, NIL);

  If PID = 0 Then Begin
    fpSetSID;
    //tcSetPGrp (0, fpGetPID);

    fpExecLP ('./mystic', ['-n' + strI2S(Num), '-TID' + strI2S(Client.FSocketHandle), '-IP' + Client.FPeerIP, '-HOST' + Client.FPeerName]);

    Exit;
  End Else
  If PID = -1 Then
    Exit;

  FillChar (NI, SizeOf(NI), 0);

  NI.Num    := Num;
  NI.Busy   := True;
  NI.IP     := Client.FPeerIP;
  NI.User   := 'Unknown';
  NI.Action := 'Logging In';

  ND.SetNodeInfo(Num, NI);

  MaxFD := Client.FSocketHandle;

  If PTYFD > Client.FSocketHandle Then MaxFD := PTYFD;

  Repeat
    fpFD_ZERO (RDFDSET);
    fpFD_SET  (PTYFD, RDFDSET);
    fpFD_SET  (Client.FSocketHandle, RDFDSET);

    If fpSelect (MaxFD + 1, @RDFDSET, NIL, NIL, 3000) < 0 Then Break;

    If fpFD_ISSET(PTYFD, RDFDSET) = 1 Then Begin
      Count := fpRead (PTYFD, Buffer, SizeOf(Buffer));

      If Count <= 0 Then Break;

      Client.WriteBuf (Buffer, Count);
    End;

    If fpFD_ISSET(Client.FSocketHandle, RDFDSET) = 1 Then Begin
      Count := Client.ReadBuf (Buffer, SizeOf(Buffer));

      If Count < 0 Then Break;

      If fpWrite (PTYFD, Buffer, Count) <> Count Then Break;
    End;
  Until False;

  fpClose (PTYFD);

  Repeat
  Until fpWaitPID(PID, WaitStat, WUNTRACED) = PID;

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';

  ND.SetNodeInfo(Num, NI);

  FileErase (bbsCfg.DataPath + 'chat' + strI2S(NI.Num) + '.dat');
End;
{$ENDIF}

{$IFDEF USEPROCESS}
Procedure TTelnetServer.Execute;
Var
  Cmd    : String;
  Num    : LongInt;
  NI     : TNodeInfoRec;
  Proc   : TProcess;
  Buffer : TIOBuffer;
  bRead  : LongInt;
  bWrite : LongInt;
Begin
  Client.FTelnetServer := True;

  Proc := TProcess.Create(Nil);
  Num  := ND.GetFreeNode;

  Proc.CommandLine := 'mystic -n' + strI2S(Num) + ' -IP' + Client.FPeerIP + ' -HOST' + Client.FPeerName;
  Proc.Options     := [poUsePipes];

  FillChar(NI, SizeOf(NI), 0);

  NI.Num    := Num;
  NI.Busy   := True;
  NI.IP     := Client.FPeerIP;
  NI.User   := 'Unknown';
  NI.Action := 'Logging In';

  ND.SetNodeInfo(Num, NI);

  Proc.Execute;

  While Proc.Running Or (Proc.Output.NumBytesAvailable > 0) Do Begin
    If Proc.Output.NumBytesAvailable > 0 Then Begin
      bRead := Proc.Output.Read(Buffer, TIOBufferSize);
      Client.WriteBufEscaped (Buffer, bRead);
    End Else
    If Client.DataWaiting Then Begin
      bWrite := Client.ReadBuf(Buffer, TIOBufferSize);

      If bWrite < 0 Then Break;

      If bWrite > 0 Then Begin
        Proc.Input.Write(Buffer, bWrite);
      End;
    End Else
      WaitMS(10);
  End;

  Proc.Free;

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';

  ND.SetNodeInfo(Num, NI);

  FileErase (bbsCfg.DataPath + 'chat' + strI2S(NI.Num) + '.dat');
End;
{$ENDIF}

{$IFDEF GO32V2}
// DOS/go32v2 concurrency model.
//
// Watt-32 is a real TCP/IP stack and handles MULTIPLE concurrent sockets - it
// exposes select_s() precisely so one process can watch several connections.
// The DOS constraint is NOT "one connection"; it is "no preemptive threads"
// (DOS is single-tasking, so the thread-per-client model TServerClient uses on
// other platforms does not apply). The correct multi-node DOS design is
// cooperative: one process, non-blocking sockets (FIONBIO), polled with
// fpSelect - many connections, one thread. sockets_go32v2 already provides all
// of those primitives (fpSelect/fpFD_*/ioctlSocket+FIONBIO).
//
// This first implementation is deliberately simpler: it serves ONE caller at a
// time by handing the accepted socket to a `mystic -n<N> -TID<handle>` session
// (the same -TID/CommHandle handoff the Windows path uses) and waiting for it
// to finish. That is an implementation choice for the initial DOS bring-up, not
// a Watt-32 limitation. A cooperative select() accept-loop that multiplexes
// several concurrent nodes in-process is the planned upgrade (see
// docs/DOS-SOCKETS.md).
Procedure TTelnetServer.Execute;
Var
  Num : LongInt;
  NI  : TNodeInfoRec;
Begin
  Client.FTelnetServer := True;

  Num := ND.GetFreeNode;

  FillChar(NI, SizeOf(NI), 0);
  NI.Num    := Num;
  NI.Busy   := True;
  NI.IP     := Client.FPeerIP;
  NI.User   := 'Unknown';
  NI.Action := 'Logging In';
  ND.SetNodeInfo(Num, NI);

  // Run the single node directly on this socket handle and wait for it to
  // finish (single-tasking: the listener is idle for the duration of the call).
  ExecuteProcess(GetEnvironmentVariable('COMSPEC'),
    '/C mystic -n' + strI2S(Num) +
    ' -TID' + strI2S(Client.FSocketHandle) +
    ' -IP'  + Client.FPeerIP +
    ' -HOST' + Client.FPeerName);

  NI.Busy   := False;
  NI.IP     := '';
  NI.User   := '';
  NI.Action := '';
  ND.SetNodeInfo(Num, NI);

  FileErase(bbsCfg.DataPath + 'chat' + strI2S(NI.Num) + '.dat');
End;
{$ENDIF}

Destructor TTelnetServer.Destroy;
Begin
  Inherited Destroy;
End;

End.
