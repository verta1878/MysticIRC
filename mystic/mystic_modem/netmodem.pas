{
  This file is part of the Mystic BBS IRC Fork.

  Copyright (C) 2026 Mystic BBS IRC Fork Contributors

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
}
{ netmodem - DOS serial-to-TCP bridge (FOSSIL + Watt-32 sockets)
  A dumb relay: bytes from FOSSIL serial go to TCP socket,
  bytes from TCP socket go to FOSSIL serial. No protocol awareness.
  Usage: netmodem <host> <port> [comport]
  Requires: FOSSIL driver loaded, Watt-32 TCP/IP configured }

Program netmodem;

{$IFDEF FPC}{$MODE OBJFPC}{$ENDIF}

Uses
  DOS, Sockets, fossil_dos;

Const
  BUF_SIZE = 1024;
  BAUD_9600 = $E3;

Var
  Host     : String;
  Port     : Word;
  ComPort  : Word;
  Sock     : TSocket;
  Addr     : TInetSockAddr;
  Resolved : TInAddr;
  RxBuf    : Array[1..BUF_SIZE] of Byte;
  TxBuf    : Array[1..BUF_SIZE] of Byte;
  RxLen    : ssize_t;
  TxLen    : Word;
  FDs      : TFDSet;
  TV       : TTimeVal;
  Done     : Boolean;
  B        : Byte;
  I        : Word;
  NonBlock : cint;

Begin
  WriteLn('netmodem - DOS serial-to-TCP bridge');
  WriteLn('-----------------------------------');

  If ParamCount < 2 Then Begin
    WriteLn('Usage: netmodem <host> <port> [comport]');
    Halt(1);
  End;

  Host := ParamStr(1);
  Val(ParamStr(2), Port, I);
  If Port = 0 Then Begin WriteLn('Invalid port'); Halt(1); End;

  ComPort := 0;
  If ParamCount >= 3 Then Val(ParamStr(3), ComPort, I);

  Write('FOSSIL COM', ComPort + 1, '... ');
  If Not Fossil_Init(ComPort) Then Begin
    WriteLn('FAILED'); Halt(2);
  End;
  WriteLn('OK');
  Fossil_SetBaud(ComPort, BAUD_9600);
  Fossil_PurgeIn(ComPort);
  Fossil_PurgeOut(ComPort);

  Write('TCP/IP... ');
  If Not InitWatt32 Then Begin
    WriteLn('FAILED'); Fossil_Deinit(ComPort); Halt(3);
  End;
  WriteLn('OK');

  Write('Resolving ', Host, '... ');
  If Not ResolveName(Host, Resolved) Then Begin
    WriteLn('FAILED'); DoneWatt32; Fossil_Deinit(ComPort); Halt(4);
  End;
  WriteLn(inet_ntoa(Resolved));

  Sock := fpSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  If Sock < 0 Then Begin
    WriteLn('Socket failed'); DoneWatt32; Fossil_Deinit(ComPort); Halt(5);
  End;

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port   := htons(Port);
  Addr.sin_addr   := Resolved;

  Write('Connecting ', Host, ':', Port, '... ');
  If fpConnect(Sock, @Addr, SizeOf(Addr)) < 0 Then Begin
    WriteLn('FAILED'); CloseSocket(Sock); DoneWatt32;
    Fossil_Deinit(ComPort); Halt(6);
  End;
  WriteLn('OK');

  NonBlock := 1;
  ioctlSocket(Sock, FIONBIO, @NonBlock);

  WriteLn('Bridge active. Carrier loss disconnects.');
  Done := False;

  Repeat
    { TCP -> FOSSIL }
    fpFD_Zero(FDs);
    fpFD_Set(Sock, FDs);
    TV.tv_sec := 0; TV.tv_usec := 10000;

    If fpSelect(Sock + 1, @FDs, Nil, Nil, @TV) > 0 Then Begin
      RxLen := fpRecv(Sock, @RxBuf[1], BUF_SIZE, 0);
      If RxLen <= 0 Then Begin
        WriteLn; WriteLn('Remote disconnected.'); Done := True;
      End Else
        For I := 1 to RxLen Do Fossil_SendByte(ComPort, RxBuf[I]);
    End;

    { FOSSIL -> TCP }
    TxLen := 0;
    While Fossil_RxReady(ComPort) and (TxLen < BUF_SIZE) Do Begin
      If Fossil_RecvByte(ComPort, B) Then Begin
        Inc(TxLen); TxBuf[TxLen] := B;
      End;
    End;
    If TxLen > 0 Then
      If fpSend(Sock, @TxBuf[1], TxLen, 0) < 0 Then Begin
        WriteLn; WriteLn('Send error.'); Done := True;
      End;

    { Carrier check }
    If Not Fossil_Carrier(ComPort) Then Begin
      WriteLn; WriteLn('Carrier lost.'); Done := True;
    End;
  Until Done;

  WriteLn('Disconnecting...');
  fpShutdown(Sock, SHUT_RDWR);
  CloseSocket(Sock);
  Fossil_SetDTR(ComPort, False);
  Fossil_Deinit(ComPort);
  DoneWatt32;
  WriteLn('Done.');
End.
