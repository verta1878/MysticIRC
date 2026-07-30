//
// This file is part of the Mystic BBS IRC Fork.
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// ============================================================================
//  sockets_go32v2.pas  -  COMPLETE BSD-socket layer for DOS (go32v2)
//
//  A full FPC-`Sockets`-compatible unit for the DOS/go32v2 target, implemented
//  as bindings to the Watt-32 TCP/IP library (C, linked externally as
//  libwatt.a).  This is LAYER 1 of the DOS networking stack:
//
//      services (FTP, telnet, SMTP, POP3, NNTP, binkp, ...)   <- Layer 2
//                          |
//      sockets_go32v2  (this unit)  -  complete fp* BSD API   <- Layer 1
//                          |
//      libwatt.a  (Watt-32 C stack)  -  external dependency
//                          |
//      packet driver + WATTCP.CFG    -  runtime
//
//  It intentionally exposes the SAME symbols FPC's own `Sockets` unit does, so
//  the fork's socket layer (mdl/m_io_sockets.pas) and future service units
//  `Uses` it unchanged.  The fork's own code stays pure Pascal; the C TCP/IP
//  stack (Watt-32) is an external build/runtime dependency, NOT bundled here.
//
//  COMPLETE means: TCP + UDP (recvfrom/sendto), full name/address helpers,
//  select + FD_SET, get/setsockopt, getpeername/getsockname, and the DNS
//  resolver set (gethostbyname/gethostbyaddr/inet_addr/inet_ntoa/inet_aton).
//  Every routine is a thin passthrough to a real Watt-32 entry point.
//
//  BUILD/LINK: needs Watt-32 for djgpp (libwatt.a) on the link path
//  (`-k-lwatt`).  Call InitWatt32 (wraps sock_init) once before use.  Runtime
//  needs a DOS packet driver + WATTCP.CFG (or DHCP).  See docs/DOS-SOCKETS.md.
//
//  LICENSE: Watt-32 is a separate, permissively-licensed C library; this unit
//  only DECLARES its entry points.  Watt-32 itself is not part of this repo.
// ============================================================================
{$I M_OPS.PAS}

Unit sockets_go32v2;

Interface

Type
  { ---- FPC Sockets-compatible scalar types ---- }
  cint      = LongInt;
  pcint     = ^cint;
  cuint     = LongWord;
  cushort   = Word;
  TSocket   = LongInt;
  ssize_t   = LongInt;
  tsize_t   = LongWord;
  TSockLen  = cint;
  PSockLen  = ^TSockLen;

  { ---- in_addr / sockaddr_in (byte-compatible with BSD/Watt-32) ---- }
  TInAddr = packed record
    Case Integer of
      0: (s_addr : LongWord);
      1: (s_bytes: packed array[1..4] of Byte);
  end;
  PInAddr = ^TInAddr;

  TInetSockAddr = packed record
    sin_family : Word;
    sin_port   : Word;
    sin_addr   : TInAddr;
    sin_zero   : packed array[0..7] of Byte;
  end;
  PInetSockAddr = ^TInetSockAddr;
  TSockAddr     = TInetSockAddr;
  PSockAddr     = ^TSockAddr;

  { ---- fd_set (classic bit array; 256 fds is plenty for DOS) ---- }
  TFDSet = packed record
    fds_bits : packed array[0..7] of LongWord;
  end;
  PFDSet = ^TFDSet;

  TTimeVal = packed record
    tv_sec  : LongInt;
    tv_usec : LongInt;
  end;
  PTimeVal = ^TTimeVal;

  { ---- hostent (name/addr resolution) ---- }
  THostEnt = packed record
    h_name      : PChar;
    h_aliases   : ^PChar;
    h_addrtype  : cint;
    h_length    : cint;
    h_addr_list : ^PChar;
  end;
  PHostEnt = ^THostEnt;

  { ---- servent / protoent (service + protocol lookups) ---- }
  TServEnt = packed record
    s_name    : PChar;
    s_aliases : ^PChar;
    s_port    : cint;
    s_proto   : PChar;
  end;
  PServEnt = ^TServEnt;

Const
  { address / socket families }
  AF_UNSPEC    = 0;
  AF_INET      = 2;
  PF_INET      = 2;

  { socket types }
  SOCK_STREAM  = 1;
  SOCK_DGRAM   = 2;
  SOCK_RAW     = 3;

  { protocols }
  IPPROTO_IP   = 0;
  IPPROTO_ICMP = 1;
  IPPROTO_TCP  = 6;
  IPPROTO_UDP  = 17;

  { setsockopt levels }
  SOL_SOCKET   = $FFFF;

  { SOL_SOCKET options }
  SO_DEBUG     = $0001;
  SO_REUSEADDR = $0004;
  SO_KEEPALIVE = $0008;
  SO_DONTROUTE = $0010;
  SO_BROADCAST = $0020;
  SO_LINGER    = $0080;
  SO_SNDBUF    = $1001;
  SO_RCVBUF    = $1002;
  SO_ERROR     = $1007;
  SO_TYPE      = $1008;

  { IPPROTO_TCP options }
  TCP_NODELAY  = $0001;

  { send/recv flags }
  MSG_NONE     = 0;
  MSG_OOB      = $01;
  MSG_PEEK     = $02;
  MSG_DONTWAIT = $40;

  { shutdown() how }
  SHUT_RD      = 0;
  SHUT_WR      = 1;
  SHUT_RDWR    = 2;

  { ioctl }
  FIONBIO      = LongInt($8004667E);
  FIONREAD     = LongInt($4004667F);

  { special addresses }
  INADDR_ANY       = LongWord($00000000);
  INADDR_BROADCAST = LongWord($FFFFFFFF);
  INADDR_LOOPBACK  = LongWord($7F000001);
  INADDR_NONE      = LongWord($FFFFFFFF);

  { errno of interest - BSD/Watt-32 numbering }
  ESOCKEWOULDBLOCK = 35;   { EWOULDBLOCK / EAGAIN }
  ESOCKEINPROGRESS = 36;   { EINPROGRESS }
  ESOCKEINTR       = 4;    { EINTR }

Var
  Watt32Ready : Boolean = False;

{ ---- one-time Watt-32 startup ---- }
Function  InitWatt32 : Boolean;
Procedure DoneWatt32;

{ ===================== core socket calls (fp* = FPC style) ============= }
Function  fpSocket    (Domain, SockType, Protocol: cint) : TSocket;
Function  fpBind      (Sock: TSocket; Addr: PInetSockAddr; AddrLen: cint) : cint;
Function  fpConnect   (Sock: TSocket; Addr: PInetSockAddr; AddrLen: cint) : cint;
Function  fpListen    (Sock: TSocket; Backlog: cint) : cint;
Function  fpAccept    (Sock: TSocket; Addr: PInetSockAddr; AddrLen: PSockLen) : TSocket;
Function  fpShutdown  (Sock: TSocket; How: cint) : cint;

{ ---- stream I/O ---- }
Function  fpSend      (Sock: TSocket; Buf: Pointer; Len, Flags: cint) : ssize_t;
Function  fpRecv      (Sock: TSocket; Buf: Pointer; Len, Flags: cint) : ssize_t;

{ ---- datagram I/O (UDP) ---- }
Function  fpSendTo    (Sock: TSocket; Buf: Pointer; Len, Flags: cint;
                       ToAddr: PInetSockAddr; ToLen: cint) : ssize_t;
Function  fpRecvFrom  (Sock: TSocket; Buf: Pointer; Len, Flags: cint;
                       FromAddr: PInetSockAddr; FromLen: PSockLen) : ssize_t;

{ ---- socket options ---- }
Function  fpSetSockOpt(Sock, Level, OptName: cint; OptVal: Pointer; OptLen: cint) : cint;
Function  fpGetSockOpt(Sock, Level, OptName: cint; OptVal: Pointer; OptLen: PSockLen) : cint;

{ ---- names ---- }
Function  fpGetSockName(Sock: TSocket; Addr: PInetSockAddr; AddrLen: PSockLen) : cint;
Function  fpGetPeerName(Sock: TSocket; Addr: PInetSockAddr; AddrLen: PSockLen) : cint;

{ ---- multiplexing ---- }
Function  fpSelect    (Nfds: cint; ReadFDs, WriteFDs, ExceptFDs: PFDSet; TimeOut: PTimeVal) : cint;

{ ---- fd_set helpers ---- }
Procedure fpFD_Zero   (Var FDSet: TFDSet);
Procedure fpFD_Set    (Sock: TSocket; Var FDSet: TFDSet);
Procedure fpFD_Clr    (Sock: TSocket; Var FDSet: TFDSet);
Function  fpFD_IsSet  (Sock: TSocket; Var FDSet: TFDSet) : Boolean;

{ non-fp aliases used by the fork's non-unix path }
Procedure FD_Zero     (Var FDSet: TFDSet);
Procedure FD_Set      (Sock: TSocket; Var FDSet: TFDSet);
Procedure FD_Clr      (Sock: TSocket; Var FDSet: TFDSet);
Function  FD_IsSet    (Sock: TSocket; Var FDSet: TFDSet) : Boolean;
Function  Select      (Nfds: cint; ReadFDs, WriteFDs, ExceptFDs: PFDSet; TimeOut: PTimeVal) : cint;

{ ---- close / ioctl ---- }
Function  CloseSocket (Sock: TSocket) : cint;
Function  ioctlSocket (Sock: TSocket; Cmd: cint; Arg: Pointer) : cint;

{ ---- last error ---- }
Function  SocketError : cint;

{ ===================== byte order ===================== }
Function  htons (HostShort: Word) : Word;
Function  htonl (HostLong: LongWord) : LongWord;
Function  ntohs (NetShort: Word) : Word;
Function  ntohl (NetLong: LongWord) : LongWord;

{ ===================== address helpers ===================== }
Function  inet_addr (Const IP: String) : LongWord;      { dotted -> net-order }
Function  inet_ntoa (Addr: TInAddr) : String;           { net-order -> dotted }
Function  inet_aton (Const IP: String; Var Addr: TInAddr) : Boolean;

{ FPC-Sockets-style aliases the fork uses }
Function  StrToNetAddr (Const IP: String) : TInAddr;
Function  NetAddrToStr (Addr: TInAddr) : String;
Function  HostAddrToStr(Addr: TInAddr) : String;
Function  StrToHostAddr(Const IP: String) : TInAddr;

{ ===================== DNS / resolver ===================== }
Function  GetHostByName(Name: PChar) : PHostEnt;
Function  GetHostByAddr(Addr: Pointer; Len, Family: cint) : PHostEnt;
{ convenience: resolve a hostname or dotted-IP to a net-order address }
Function  ResolveName  (Const HostName: String; Var Addr: TInAddr) : Boolean;
{ service / protocol lookups }
Function  GetServByName(Name, Proto: PChar) : PServEnt;
Function  GetProtoByName(Name: PChar) : Pointer;

Implementation

// ---------------------------------------------------------------------------
//  Watt-32 C entry points (cdecl).  These resolve against libwatt.a at link.
//  Watt-32 provides a full BSD-socket API plus its startup (sock_init) and the
//  resolver.  close_s() is Watt-32's socket close (plain close() hits the DOS
//  file layer).  select_s() is Watt-32's socket select.
// ---------------------------------------------------------------------------
Function w_sock_init : cint; cdecl; external name 'sock_init';
Procedure w_sock_exit; cdecl; external name 'sock_exit';

Function w_socket   (af, styp, proto: cint) : cint; cdecl; external name 'socket';
Function w_bind     (s: cint; name: Pointer; namelen: cint) : cint; cdecl; external name 'bind';
Function w_connect  (s: cint; name: Pointer; namelen: cint) : cint; cdecl; external name 'connect';
Function w_listen   (s, backlog: cint) : cint; cdecl; external name 'listen';
Function w_accept   (s: cint; addr, addrlen: Pointer) : cint; cdecl; external name 'accept';
Function w_shutdown (s, how: cint) : cint; cdecl; external name 'shutdown';

Function w_send     (s: cint; buf: Pointer; len, flags: cint) : cint; cdecl; external name 'send';
Function w_recv     (s: cint; buf: Pointer; len, flags: cint) : cint; cdecl; external name 'recv';
Function w_sendto   (s: cint; buf: Pointer; len, flags: cint; addr: Pointer; addrlen: cint) : cint; cdecl; external name 'sendto';
Function w_recvfrom (s: cint; buf: Pointer; len, flags: cint; addr, addrlen: Pointer) : cint; cdecl; external name 'recvfrom';

Function w_setsockopt(s, level, optname: cint; optval: Pointer; optlen: cint) : cint; cdecl; external name 'setsockopt';
Function w_getsockopt(s, level, optname: cint; optval, optlen: Pointer) : cint; cdecl; external name 'getsockopt';
Function w_getsockname(s: cint; name, namelen: Pointer) : cint; cdecl; external name 'getsockname';
Function w_getpeername(s: cint; name, namelen: Pointer) : cint; cdecl; external name 'getpeername';

Function w_select   (nfds: cint; rd, wr, ex, tv: Pointer) : cint; cdecl; external name 'select_s';
Function w_close_s  (s: cint) : cint; cdecl; external name 'close_s';
Function w_ioctlsocket(s, cmd: cint; argp: Pointer) : cint; cdecl; external name 'ioctlsocket';

Function w_inet_addr(cp: PChar) : LongWord; cdecl; external name 'inet_addr';
Function w_inet_ntoa(inn: TInAddr) : PChar; cdecl; external name 'inet_ntoa';
Function w_inet_aton(cp: PChar; addr: Pointer) : cint; cdecl; external name 'inet_aton';

Function w_gethostbyname(name: PChar) : PHostEnt; cdecl; external name 'gethostbyname';
Function w_gethostbyaddr(addr: Pointer; len, styp: cint) : PHostEnt; cdecl; external name 'gethostbyaddr';
Function w_getservbyname(name, proto: PChar) : PServEnt; cdecl; external name 'getservbyname';
Function w_getprotobyname(name: PChar) : Pointer; cdecl; external name 'getprotobyname';

Function w_errno_location : pcint; cdecl; external name '__errno';

// ===================== startup / shutdown =====================
Function InitWatt32 : Boolean;
Begin
  If Watt32Ready Then Begin InitWatt32 := True; Exit; End;
  Watt32Ready := (w_sock_init = 0);
  InitWatt32  := Watt32Ready;
End;

Procedure DoneWatt32;
Begin
  If Watt32Ready Then Begin
    w_sock_exit;
    Watt32Ready := False;
  End;
End;

// ===================== core socket calls =====================
Function fpSocket(Domain, SockType, Protocol: cint): TSocket;
Begin fpSocket := w_socket(Domain, SockType, Protocol); End;

Function fpBind(Sock: TSocket; Addr: PInetSockAddr; AddrLen: cint): cint;
Begin fpBind := w_bind(Sock, Addr, AddrLen); End;

Function fpConnect(Sock: TSocket; Addr: PInetSockAddr; AddrLen: cint): cint;
Begin fpConnect := w_connect(Sock, Addr, AddrLen); End;

Function fpListen(Sock: TSocket; Backlog: cint): cint;
Begin fpListen := w_listen(Sock, Backlog); End;

Function fpAccept(Sock: TSocket; Addr: PInetSockAddr; AddrLen: PSockLen): TSocket;
Begin fpAccept := w_accept(Sock, Addr, AddrLen); End;

Function fpShutdown(Sock: TSocket; How: cint): cint;
Begin fpShutdown := w_shutdown(Sock, How); End;

// ---- stream I/O ----
Function fpSend(Sock: TSocket; Buf: Pointer; Len, Flags: cint): ssize_t;
Begin fpSend := w_send(Sock, Buf, Len, Flags); End;

Function fpRecv(Sock: TSocket; Buf: Pointer; Len, Flags: cint): ssize_t;
Begin fpRecv := w_recv(Sock, Buf, Len, Flags); End;

// ---- datagram I/O ----
Function fpSendTo(Sock: TSocket; Buf: Pointer; Len, Flags: cint;
                 ToAddr: PInetSockAddr; ToLen: cint): ssize_t;
Begin fpSendTo := w_sendto(Sock, Buf, Len, Flags, ToAddr, ToLen); End;

Function fpRecvFrom(Sock: TSocket; Buf: Pointer; Len, Flags: cint;
                   FromAddr: PInetSockAddr; FromLen: PSockLen): ssize_t;
Begin fpRecvFrom := w_recvfrom(Sock, Buf, Len, Flags, FromAddr, FromLen); End;

// ---- options ----
Function fpSetSockOpt(Sock, Level, OptName: cint; OptVal: Pointer; OptLen: cint): cint;
Begin fpSetSockOpt := w_setsockopt(Sock, Level, OptName, OptVal, OptLen); End;

Function fpGetSockOpt(Sock, Level, OptName: cint; OptVal: Pointer; OptLen: PSockLen): cint;
Begin fpGetSockOpt := w_getsockopt(Sock, Level, OptName, OptVal, OptLen); End;

// ---- names ----
Function fpGetSockName(Sock: TSocket; Addr: PInetSockAddr; AddrLen: PSockLen): cint;
Begin fpGetSockName := w_getsockname(Sock, Addr, AddrLen); End;

Function fpGetPeerName(Sock: TSocket; Addr: PInetSockAddr; AddrLen: PSockLen): cint;
Begin fpGetPeerName := w_getpeername(Sock, Addr, AddrLen); End;

// ---- select ----
Function fpSelect(Nfds: cint; ReadFDs, WriteFDs, ExceptFDs: PFDSet; TimeOut: PTimeVal): cint;
Begin fpSelect := w_select(Nfds, ReadFDs, WriteFDs, ExceptFDs, TimeOut); End;

// ===================== fd_set helpers =====================
Procedure fpFD_Zero(Var FDSet: TFDSet);
Var i: Integer;
Begin For i := 0 to High(FDSet.fds_bits) Do FDSet.fds_bits[i] := 0; End;

Procedure fpFD_Set(Sock: TSocket; Var FDSet: TFDSet);
Begin
  If (Sock >= 0) and (Sock < 256) Then
    FDSet.fds_bits[Sock shr 5] := FDSet.fds_bits[Sock shr 5] or (LongWord(1) shl (Sock and 31));
End;

Procedure fpFD_Clr(Sock: TSocket; Var FDSet: TFDSet);
Begin
  If (Sock >= 0) and (Sock < 256) Then
    FDSet.fds_bits[Sock shr 5] := FDSet.fds_bits[Sock shr 5] and not (LongWord(1) shl (Sock and 31));
End;

Function fpFD_IsSet(Sock: TSocket; Var FDSet: TFDSet): Boolean;
Begin
  fpFD_IsSet := (Sock >= 0) and (Sock < 256) and
    ((FDSet.fds_bits[Sock shr 5] and (LongWord(1) shl (Sock and 31))) <> 0);
End;

Procedure FD_Zero(Var FDSet: TFDSet);            Begin fpFD_Zero(FDSet); End;
Procedure FD_Set(Sock: TSocket; Var FDSet: TFDSet); Begin fpFD_Set(Sock, FDSet); End;
Procedure FD_Clr(Sock: TSocket; Var FDSet: TFDSet); Begin fpFD_Clr(Sock, FDSet); End;
Function  FD_IsSet(Sock: TSocket; Var FDSet: TFDSet): Boolean; Begin FD_IsSet := fpFD_IsSet(Sock, FDSet); End;

Function Select(Nfds: cint; ReadFDs, WriteFDs, ExceptFDs: PFDSet; TimeOut: PTimeVal): cint;
Begin Select := fpSelect(Nfds, ReadFDs, WriteFDs, ExceptFDs, TimeOut); End;

// ===================== close / ioctl / errno =====================
Function CloseSocket(Sock: TSocket): cint;  Begin CloseSocket := w_close_s(Sock); End;
Function ioctlSocket(Sock: TSocket; Cmd: cint; Arg: Pointer): cint;
Begin ioctlSocket := w_ioctlsocket(Sock, Cmd, Arg); End;

Function SocketError: cint;
Var P: pcint;
Begin
  P := w_errno_location;
  If P = Nil Then SocketError := 0 Else SocketError := P^;
End;

// ===================== byte order (i386 = little-endian) =====================
Function htons(HostShort: Word): Word;
Begin htons := (HostShort shr 8) or (HostShort shl 8); End;

Function ntohs(NetShort: Word): Word;  Begin ntohs := htons(NetShort); End;

Function htonl(HostLong: LongWord): LongWord;
Begin
  htonl := ((HostLong and $000000FF) shl 24) or
           ((HostLong and $0000FF00) shl 8)  or
           ((HostLong and $00FF0000) shr 8)  or
           ((HostLong and $FF000000) shr 24);
End;

Function ntohl(NetLong: LongWord): LongWord;  Begin ntohl := htonl(NetLong); End;

// ===================== address helpers =====================
Function inet_addr(Const IP: String): LongWord;
Var Z: Array[0..63] of Char; i: Integer;
Begin
  If Length(IP) > 62 Then Begin inet_addr := INADDR_NONE; Exit; End;
  For i := 1 to Length(IP) Do Z[i-1] := IP[i];
  Z[Length(IP)] := #0;
  inet_addr := w_inet_addr(@Z[0]);
End;

Function inet_ntoa(Addr: TInAddr): String;
Var P: PChar;
Begin
  P := w_inet_ntoa(Addr);
  If P = Nil Then inet_ntoa := '0.0.0.0' Else inet_ntoa := StrPas(P);
End;

Function inet_aton(Const IP: String; Var Addr: TInAddr): Boolean;
Var Z: Array[0..63] of Char; i: Integer;
Begin
  If Length(IP) > 62 Then Begin inet_aton := False; Exit; End;
  For i := 1 to Length(IP) Do Z[i-1] := IP[i];
  Z[Length(IP)] := #0;
  inet_aton := (w_inet_aton(@Z[0], @Addr) <> 0);
End;

Function StrToNetAddr(Const IP: String): TInAddr;
Begin Result.s_addr := inet_addr(IP); End;

Function NetAddrToStr(Addr: TInAddr): String;  Begin NetAddrToStr := inet_ntoa(Addr); End;
Function HostAddrToStr(Addr: TInAddr): String; Begin HostAddrToStr := inet_ntoa(Addr); End;
Function StrToHostAddr(Const IP: String): TInAddr; Begin Result.s_addr := inet_addr(IP); End;

// ===================== DNS / resolver =====================
Function GetHostByName(Name: PChar): PHostEnt;  Begin GetHostByName := w_gethostbyname(Name); End;
Function GetHostByAddr(Addr: Pointer; Len, Family: cint): PHostEnt;
Begin GetHostByAddr := w_gethostbyaddr(Addr, Len, Family); End;

Function GetServByName(Name, Proto: PChar): PServEnt; Begin GetServByName := w_getservbyname(Name, Proto); End;
Function GetProtoByName(Name: PChar): Pointer; Begin GetProtoByName := w_getprotobyname(Name); End;

// Resolve a hostname OR a dotted-quad to a net-order address.  Tries a literal
// IP first (no DNS round-trip), then falls back to gethostbyname.  DoveNet
// hubs are hostnames, so this is the path that actually matters.
Function ResolveName(Const HostName: String; Var Addr: TInAddr): Boolean;
Var
  L    : LongWord;
  HE   : PHostEnt;
  Z    : Array[0..255] of Char;
  PP   : ^PChar;
  i    : Integer;
Begin
  ResolveName := False;
  { 1. literal dotted-quad? }
  L := inet_addr(HostName);
  If (L <> INADDR_NONE) or (HostName = '255.255.255.255') Then Begin
    Addr.s_addr := L; ResolveName := True; Exit;
  End;
  { 2. DNS }
  If Length(HostName) > 254 Then Exit;
  For i := 1 to Length(HostName) Do Z[i-1] := HostName[i];
  Z[Length(HostName)] := #0;
  HE := w_gethostbyname(@Z[0]);
  If (HE = Nil) or (HE^.h_addr_list = Nil) Then Exit;
  PP := HE^.h_addr_list;
  If PP^ = Nil Then Exit;
  { h_addr_list[0] points to 4 network-order bytes }
  Move(PP^^, Addr.s_addr, 4);
  ResolveName := True;
End;

End.
