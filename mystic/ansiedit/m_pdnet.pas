{$MODE OBJFPC}
{$H+}
unit m_pdnet;
{ PabloDraw Pascal — Network Protocol (Client/Server)
  TCP teleconference for collaborative ANSI art editing.
  
  Wire protocol: [LEN:4][CMD:1][DATA:LEN-1]
  
  Commands:
    $01 Chat      — [fromLen][from][textLen][text]
    $02 Update    — [x1:2][y1:2][x2:2][y2:2][cells...]
    $03 LoadDoc   — [w:2][h:2][cells...]
    $04 UserList  — [count][alias+level...]
    $05 UserStatus— [idx][level]
    $06 Cursor    — [userIdx][x:2][y:2]
    $07 SetAttr   — [attr]
    $08 Kick      — [idx][reasonLen][reason]
    $09 Auth      — [version][aliasLen][alias][passLen][pass]
    $0A Welcome   — [yourIdx][level][w:2][h:2]
    $0B Bye       — [reasonLen][reason] }

interface

uses Classes, SysUtils,
  {$IFDEF GO32V2}
  Sockets,  { our pure Pascal sockets.pp }
  {$ELSE}
  {$IFDEF MSDOS}
  Sockets,  { our pure Pascal sockets.pp for i8086 }
  {$ELSE}
  {$IFDEF WINDOWS}
  Sockets, WinSock2,  { Windows }
  {$ELSE}
  Sockets, BaseUnix, Unix,  { Linux/BSD }
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  m_pdtypes;

const
  PD_NET_VERSION = 1;
  PD_NET_PORT    = 3693;
  PD_MAX_USERS   = 32;
  PD_MAX_MSG     = 65000;
  PD_RECV_BUF    = 8192;



  { Prevent SIGPIPE on broken socket writes }
  {$IFDEF UNIX}
  PD_SEND_FLAGS  = $4000;  { MSG_NOSIGNAL }
  {$ELSE}
  PD_SEND_FLAGS  = 0;
  {$ENDIF}

  CMD_CHAT       = $01;
  CMD_UPDATE     = $02;
  CMD_LOADDOC    = $03;
  CMD_USERLIST   = $04;
  CMD_USERSTATUS = $05;
  CMD_CURSOR     = $06;
  CMD_SETATTR    = $07;
  CMD_KICK       = $08;
  CMD_AUTH       = $09;
  CMD_WELCOME    = $0A;
  CMD_BYE        = $0B;

type
  TUserLevel = (ulViewer = 0, ulEditor = 1, ulOperator = 2);

  TPDNetUser = record
    Alias:    String[30];
    Level:    TUserLevel;
    CursorX:  Word;
    CursorY:  Word;
    Socket:   LongInt;
    Active:   Boolean;
    RecvBuf:  array[0..PD_RECV_BUF - 1] of Byte;
    RecvLen:  Integer;
  end;

  TPDNetMsg = record
    Len:  LongWord;
    Cmd:  Byte;
    Data: array[0..PD_MAX_MSG - 1] of Byte;
  end;

  { Callbacks }
  TOnChatEvent = procedure(const From, Text: String) of object;
  TOnUserEvent = procedure(Index: Integer; const Alias: String; Level: TUserLevel) of object;
  TOnUpdateEvent = procedure(X1, Y1, X2, Y2: Integer) of object;

  { ---- Server ---- }
  TPDNetServer = {$IFDEF CPU16}object{$ELSE}class{$ENDIF}
  private
    FUsers: array[0..PD_MAX_USERS - 1] of TPDNetUser;
    FCanvas: TPDCanvas;
    FPort: Word;
    FListenSock: LongInt;
    FRunning: Boolean;
    FPassword: String;
    FDefaultLevel: TUserLevel;
    FOnChat: TOnChatEvent;
    FOnUserJoin: TOnUserEvent;
    FOnUserLeave: TOnUserEvent;
    function  FindUser(Socket: LongInt): Integer;
    function  FindFreeSlot: Integer;
    function  UserCount: Integer;
    procedure SendRaw(Sock: LongInt; const Msg: TPDNetMsg);
    procedure SendToAll(const Msg: TPDNetMsg; ExceptIdx: Integer);
    procedure HandleNewConnection;
    procedure HandleUserData(Idx: Integer);
    procedure ProcessMessage(Idx: Integer; const Msg: TPDNetMsg);
    procedure SendUserList;
    procedure SendCanvas(Idx: Integer);
    procedure SendWelcome(Idx: Integer);
    procedure DisconnectUser(Idx: Integer; const Reason: String);
  public
    {$IFDEF CPU16}procedure Init(ACanvas: TPDCanvas); procedure Done;{$ELSE}constructor Create(ACanvas: TPDCanvas); destructor Destroy; override;{$ENDIF}
    function  Start(APort: Word): Boolean;
    procedure Stop;
    procedure Poll;
    procedure KickUser(Idx: Integer; const Reason: String);
    procedure SetUserLevel(Idx: Integer; Level: TUserLevel);
    procedure BroadcastChat(const From, Text: String);
    function  GetUser(Idx: Integer): TPDNetUser;
    {$IFNDEF CPU16}property Canvas: TPDCanvas read FCanvas;{$ENDIF}
    property Port: Word read FPort;
    property Running: Boolean read FRunning;
    property Password: String read FPassword write FPassword;
    property DefaultLevel: TUserLevel read FDefaultLevel write FDefaultLevel;
    property OnChat: TOnChatEvent read FOnChat write FOnChat;
    property OnUserJoin: TOnUserEvent read FOnUserJoin write FOnUserJoin;
    property OnUserLeave: TOnUserEvent read FOnUserLeave write FOnUserLeave;
  end;

  { ---- Client ---- }
  TPDNetClient = {$IFDEF CPU16}object{$ELSE}class{$ENDIF}
  private
    FSocket: LongInt;
    FCanvas: TPDCanvas;
    FAlias: String;
    FLevel: TUserLevel;
    FMyIndex: Integer;
    FConnected: Boolean;
    FRecvBuf: array[0..PD_RECV_BUF - 1] of Byte;
    FRecvLen: Integer;
    FUsers: array[0..PD_MAX_USERS - 1] of TPDNetUser;
    FUserCount: Integer;
    FOnChat: TOnChatEvent;
    FOnUpdate: TOnUpdateEvent;
    procedure SendRaw(const Msg: TPDNetMsg);
    procedure ProcessMessage(const Msg: TPDNetMsg);
    function  TryReadMessage(var Msg: TPDNetMsg): Boolean;
  public
    {$IFDEF CPU16}procedure Init(ACanvas: TPDCanvas); procedure Done;{$ELSE}constructor Create(ACanvas: TPDCanvas); destructor Destroy; override;{$ENDIF}
    function  Connect(const Host: String; APort: Word; const AAlias, APass: String): Boolean;
    procedure Disconnect;
    procedure Poll;
    procedure SendChat(const Text: String);
    procedure SendUpdate(X1, Y1, X2, Y2: Integer);
    procedure SendCursor(X, Y: Integer);
    function  GetUser(Idx: Integer): TPDNetUser;
    {$IFNDEF CPU16}property Canvas: TPDCanvas read FCanvas;{$ENDIF}
    property Alias: String read FAlias;
    property Level: TUserLevel read FLevel;
    property MyIndex: Integer read FMyIndex;
    property Connected: Boolean read FConnected;
    property UserCount: Integer read FUserCount;
    property OnChat: TOnChatEvent read FOnChat write FOnChat;
    property OnUpdate: TOnUpdateEvent read FOnUpdate write FOnUpdate;
  end;

{ Helpers }
procedure MsgPackWord(var D: array of Byte; var P: Integer; W: Word);
function  MsgUnpackWord(const D: array of Byte; var P: Integer): Word;
procedure MsgPackStr(var D: array of Byte; var P: Integer; const S: String);
function  MsgUnpackStr(const D: array of Byte; var P: Integer): String;
function  BuildChatMsg(const From, Text: String): TPDNetMsg;

implementation

{ Platform socket compatibility }
{$IFDEF WINDOWS}
function fpSocket(Domain, SockType, Protocol: LongInt): LongInt; begin Result := WinSock2.Socket(Domain, SockType, Protocol); end;
function fpBind(S: LongInt; Addr: Pointer; AddrLen: LongInt): LongInt; begin Result := WinSock2.Bind(S, Addr, AddrLen); end;
function fpListen(S, BackLog: LongInt): LongInt; begin Result := WinSock2.Listen(S, BackLog); end;
function fpConnect(S: LongInt; Addr: Pointer; AddrLen: LongInt): LongInt; begin Result := WinSock2.Connect(S, Addr, AddrLen); end;
function fpAccept(S: LongInt; Addr: Pointer; AddrLen: Pointer): LongInt; begin Result := WinSock2.Accept(S, Addr, AddrLen); end;
function fpSend(S: LongInt; Buf: Pointer; Len, Flags: LongInt): LongInt; begin Result := WinSock2.Send(S, Buf^, Len, Flags); end;
function fpRecv(S: LongInt; Buf: Pointer; Len, Flags: LongInt): LongInt; begin Result := WinSock2.Recv(S, Buf^, Len, Flags); end;
function fpSelect(N: LongInt; ReadFDs, WriteFDs, ExceptFDs: Pointer; TimeOut: Pointer): LongInt; begin Result := WinSock2.Select(N, ReadFDs, WriteFDs, ExceptFDs, TimeOut); end;
function fpSetSockOpt(S, Level, OptName: LongInt; OptVal: Pointer; OptLen: LongInt): LongInt; begin Result := WinSock2.SetSockOpt(S, Level, OptName, OptVal, OptLen); end;
procedure fpFD_ZERO(var FDS: TFDSet); begin WinSock2.FD_ZERO(FDS); end;
procedure fpFD_SET(FD: LongInt; var FDS: TFDSet); begin WinSock2.FD_SET(FD, FDS); end;
function fpFD_ISSET(FD: LongInt; var FDS: TFDSet): LongInt; begin If WinSock2.FD_ISSET(FD, FDS) Then Result := 1 Else Result := 0; end;
procedure CloseSocket(S: LongInt); begin WinSock2.CloseSocket(S); end;
function fpGetErrno: LongInt; begin Result := WSAGetLastError; end;
{$ENDIF}


{ ---- Pack/Unpack ---- }

procedure MsgPackWord(var D: array of Byte; var P: Integer; W: Word);
begin D[P] := Lo(W); D[P+1] := Hi(W); Inc(P, 2); end;

function MsgUnpackWord(const D: array of Byte; var P: Integer): Word;
begin Result := D[P] or (Word(D[P+1]) shl 8); Inc(P, 2); end;

procedure MsgPackStr(var D: array of Byte; var P: Integer; const S: String);
var I: Integer;
begin
  D[P] := Length(S); Inc(P);
  for I := 1 to Length(S) do begin D[P] := Ord(S[I]); Inc(P); end;
end;

function MsgUnpackStr(const D: array of Byte; var P: Integer): String;
var L, I: Integer;
begin
  L := D[P]; Inc(P); Result := '';
  for I := 1 to L do begin Result := Result + Chr(D[P]); Inc(P); end;
end;

function BuildChatMsg(const From, Text: String): TPDNetMsg;
var P: Integer;
begin
  Result.Cmd := CMD_CHAT;
  P := 0;
  MsgPackStr(Result.Data, P, From);
  MsgPackStr(Result.Data, P, Text);
  Result.Len := P + 1;
end;

{ ---- TPDNetServer ---- }

{$IFDEF CPU16}procedure TPDNetServer.Init(ACanvas: TPDCanvas);{$ELSE}constructor TPDNetServer.Create(ACanvas: TPDCanvas);{$ENDIF}
var I: Integer;
begin
  inherited Create;
  FCanvas := ACanvas;
  FPort := PD_NET_PORT;
  FListenSock := -1;
  FRunning := False;
  FDefaultLevel := ulEditor;
  for I := 0 to PD_MAX_USERS - 1 do begin
    FUsers[I].Active := False;
    FUsers[I].RecvLen := 0;
  end;
end;

{$IFDEF CPU16}procedure TPDNetServer.Done;{$ELSE}destructor TPDNetServer.Destroy;{$ENDIF}
begin
  Stop;
  inherited;
end;

function TPDNetServer.FindUser(Socket: LongInt): Integer;
var I: Integer;
begin
  for I := 0 to PD_MAX_USERS - 1 do
    if FUsers[I].Active and (FUsers[I].Socket = Socket) then
      begin Result := I; Exit; end;
  Result := -1;
end;

function TPDNetServer.FindFreeSlot: Integer;
var I: Integer;
begin
  for I := 0 to PD_MAX_USERS - 1 do
    if not FUsers[I].Active then begin Result := I; Exit; end;
  Result := -1;
end;

function TPDNetServer.UserCount: Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to PD_MAX_USERS - 1 do
    if FUsers[I].Active then Inc(Result);
end;

function TPDNetServer.GetUser(Idx: Integer): TPDNetUser;
begin
  if (Idx >= 0) and (Idx < PD_MAX_USERS) then
    Result := FUsers[Idx]
  else begin
    Result.Active := False;
    Result.Alias := '';
  end;
end;

procedure TPDNetServer.SendRaw(Sock: LongInt; const Msg: TPDNetMsg);
var Hdr: array[0..4] of Byte; Sent: Integer;
begin
  { Frame: [LEN:4][CMD:1][DATA] }
  Hdr[0] := Msg.Len and $FF;
  Hdr[1] := (Msg.Len shr 8) and $FF;
  Hdr[2] := (Msg.Len shr 16) and $FF;
  Hdr[3] := (Msg.Len shr 24) and $FF;
  Hdr[4] := Msg.Cmd;
  fpSend(Sock, @Hdr, 5, PD_SEND_FLAGS);
  if Msg.Len > 1 then
    fpSend(Sock, @Msg.Data, Msg.Len - 1, PD_SEND_FLAGS);
end;

procedure TPDNetServer.SendToAll(const Msg: TPDNetMsg; ExceptIdx: Integer);
var I: Integer;
begin
  for I := 0 to PD_MAX_USERS - 1 do
    if FUsers[I].Active and (I <> ExceptIdx) then
      SendRaw(FUsers[I].Socket, Msg);
end;

function TPDNetServer.Start(APort: Word): Boolean;
var
  Addr: TInetSockAddr;
  OptVal: LongInt;
begin
  Result := False;
  FPort := APort;
  
  FListenSock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if FListenSock < 0 then Exit;
  
  { SO_REUSEADDR }
  OptVal := 1;
  fpSetSockOpt(FListenSock, SOL_SOCKET, SO_REUSEADDR, @OptVal, SizeOf(OptVal));
  
  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(FPort);
  Addr.sin_addr.s_addr := 0; { INADDR_ANY }
  
  if fpBind(FListenSock, @Addr, SizeOf(Addr)) <> 0 then begin
    CloseSocket(FListenSock);
    FListenSock := -1;
    Exit;
  end;
  
  if fpListen(FListenSock, 5) <> 0 then begin
    CloseSocket(FListenSock);
    FListenSock := -1;
    Exit;
  end;
  
  FRunning := True;
  Result := True;
end;

procedure TPDNetServer.Stop;
var I: Integer;
begin
  if FRunning then begin
    for I := 0 to PD_MAX_USERS - 1 do
      if FUsers[I].Active then
        DisconnectUser(I, 'Server shutting down');
    CloseSocket(FListenSock);
    FListenSock := -1;
    FRunning := False;
  end;
end;

procedure TPDNetServer.HandleNewConnection;
var
  ClientSock: LongInt;
  ClientAddr: TInetSockAddr;
  AddrLen: TSockLen;
  Idx: Integer;
begin
  AddrLen := SizeOf(ClientAddr);
  ClientSock := fpAccept(FListenSock, @ClientAddr, @AddrLen);
  if ClientSock < 0 then Exit;
  
  Idx := FindFreeSlot;
  if Idx < 0 then begin
    CloseSocket(ClientSock);
    Exit;
  end;
  
  FUsers[Idx].Active := True;
  FUsers[Idx].Socket := ClientSock;
  FUsers[Idx].Alias := 'User' + IntToStr(Idx);
  FUsers[Idx].Level := FDefaultLevel;
  FUsers[Idx].CursorX := 0;
  FUsers[Idx].CursorY := 0;
  FUsers[Idx].RecvLen := 0;
  
  { Wait for AUTH command with alias }
end;

procedure TPDNetServer.HandleUserData(Idx: Integer);
var
  N: Integer;
  Msg: TPDNetMsg;
  FrameLen: LongWord;
begin
  N := fpRecv(FUsers[Idx].Socket,
    @FUsers[Idx].RecvBuf[FUsers[Idx].RecvLen],
    PD_RECV_BUF - FUsers[Idx].RecvLen, 0);
  
  if N <= 0 then begin
    DisconnectUser(Idx, 'Connection lost');
    Exit;
  end;
  
  Inc(FUsers[Idx].RecvLen, N);
  
  { Process complete frames }
  while FUsers[Idx].RecvLen >= 5 do begin
    FrameLen := FUsers[Idx].RecvBuf[0] or
      (LongWord(FUsers[Idx].RecvBuf[1]) shl 8) or
      (LongWord(FUsers[Idx].RecvBuf[2]) shl 16) or
      (LongWord(FUsers[Idx].RecvBuf[3]) shl 24);
    
    if FrameLen > PD_MAX_MSG then begin
      DisconnectUser(Idx, 'Message too large');
      Exit;
    end;
    
    if LongWord(FUsers[Idx].RecvLen) < FrameLen + 4 then Break; { incomplete }
    
    Msg.Len := FrameLen;
    Msg.Cmd := FUsers[Idx].RecvBuf[4];
    if FrameLen > 1 then
      Move(FUsers[Idx].RecvBuf[5], Msg.Data, FrameLen - 1);
    
    { Remove frame from buffer }
    N := FrameLen + 4;
    Dec(FUsers[Idx].RecvLen, N);
    if FUsers[Idx].RecvLen > 0 then
      Move(FUsers[Idx].RecvBuf[N], FUsers[Idx].RecvBuf[0], FUsers[Idx].RecvLen);
    
    ProcessMessage(Idx, Msg);
  end;
end;

procedure TPDNetServer.ProcessMessage(Idx: Integer; const Msg: TPDNetMsg);
var
  P: Integer;
  Alias, Pass, Text: String;
  ChatMsg: TPDNetMsg;
  X1, Y1, X2, Y2, X, Y: Integer;
  E: TPDCanvasElement;
begin
  case Msg.Cmd of
    CMD_AUTH: begin
      P := 0;
      { version } Inc(P);
      Alias := MsgUnpackStr(Msg.Data, P);
      Pass := MsgUnpackStr(Msg.Data, P);
      
      if (FPassword <> '') and (Pass <> FPassword) then begin
        DisconnectUser(Idx, 'Wrong password');
        Exit;
      end;
      
      FUsers[Idx].Alias := Alias;
      if (FPassword <> '') and (Pass = FPassword) then
        FUsers[Idx].Level := ulOperator;
      
      SendWelcome(Idx);
      SendCanvas(Idx);
      SendUserList;
      
      BroadcastChat('Server', Alias + ' joined');
      if Assigned(FOnUserJoin) then
        FOnUserJoin(Idx, Alias, FUsers[Idx].Level);
    end;
    
    CMD_CHAT: begin
      if FUsers[Idx].Level >= ulViewer then begin
        P := 0;
        Text := MsgUnpackStr(Msg.Data, P);
        ChatMsg := BuildChatMsg(FUsers[Idx].Alias, Text);
        SendToAll(ChatMsg, -1);
        if Assigned(FOnChat) then
          FOnChat(FUsers[Idx].Alias, Text);
      end;
    end;
    
    CMD_UPDATE: begin
      if FUsers[Idx].Level >= ulEditor then begin
        P := 0;
        X1 := MsgUnpackWord(Msg.Data, P);
        Y1 := MsgUnpackWord(Msg.Data, P);
        X2 := MsgUnpackWord(Msg.Data, P);
        Y2 := MsgUnpackWord(Msg.Data, P);
        { Apply cells to canvas }
        for Y := Y1 to Y2 do
          for X := X1 to X2 do begin
            if P + 2 < Integer(Msg.Len) then begin
              E.Ch.Ch := Msg.Data[P] or (SmallInt(Msg.Data[P+1]) shl 8);
              Inc(P, 2);
              E.Attr.Init(Msg.Data[P]);
              Inc(P);
              FCanvas[X, Y] := E;
            end;
          end;
        { Relay to others }
        SendToAll(Msg, Idx);
      end;
    end;
    
    CMD_CURSOR: begin
      P := 0;
      FUsers[Idx].CursorX := MsgUnpackWord(Msg.Data, P);
      FUsers[Idx].CursorY := MsgUnpackWord(Msg.Data, P);
      { Relay with user index prepended }
      SendToAll(Msg, Idx);
    end;
  end;
end;

procedure TPDNetServer.SendWelcome(Idx: Integer);
var Msg: TPDNetMsg; P: Integer;
begin
  Msg.Cmd := CMD_WELCOME;
  P := 0;
  Msg.Data[P] := Idx; Inc(P);
  Msg.Data[P] := Ord(FUsers[Idx].Level); Inc(P);
  MsgPackWord(Msg.Data, P, FCanvas.Width);
  MsgPackWord(Msg.Data, P, FCanvas.Height);
  Msg.Len := P + 1;
  SendRaw(FUsers[Idx].Socket, Msg);
end;

procedure TPDNetServer.SendCanvas(Idx: Integer);
var
  Msg: TPDNetMsg;
  P, X, Y: Integer;
  E: TPDCanvasElement;
begin
  Msg.Cmd := CMD_LOADDOC;
  P := 0;
  MsgPackWord(Msg.Data, P, FCanvas.Width);
  MsgPackWord(Msg.Data, P, FCanvas.Height);
  for Y := 0 to FCanvas.Height - 1 do
    for X := 0 to FCanvas.Width - 1 do begin
      if P + 3 >= PD_MAX_MSG then Break;
      E := FCanvas[X, Y];
      Msg.Data[P] := E.Ch.Ch and $FF; Inc(P);
      Msg.Data[P] := (E.Ch.Ch shr 8) and $FF; Inc(P);
      Msg.Data[P] := E.Attr.ToByte; Inc(P);
    end;
  Msg.Len := P + 1;
  SendRaw(FUsers[Idx].Socket, Msg);
end;

procedure TPDNetServer.SendUserList;
var
  Msg: TPDNetMsg;
  P, I, Count: Integer;
begin
  Msg.Cmd := CMD_USERLIST;
  P := 0;
  Count := UserCount;
  Msg.Data[P] := Count; Inc(P);
  for I := 0 to PD_MAX_USERS - 1 do
    if FUsers[I].Active then begin
      Msg.Data[P] := I; Inc(P);
      MsgPackStr(Msg.Data, P, FUsers[I].Alias);
      Msg.Data[P] := Ord(FUsers[I].Level); Inc(P);
    end;
  Msg.Len := P + 1;
  SendToAll(Msg, -1);
end;

procedure TPDNetServer.DisconnectUser(Idx: Integer; const Reason: String);
var Msg: TPDNetMsg; P: Integer;
begin
  if not FUsers[Idx].Active then Exit;
  { Send BYE }
  Msg.Cmd := CMD_BYE;
  P := 0;
  MsgPackStr(Msg.Data, P, Reason);
  Msg.Len := P + 1;
  SendRaw(FUsers[Idx].Socket, Msg);
  CloseSocket(FUsers[Idx].Socket);
  
  if Assigned(FOnUserLeave) then
    FOnUserLeave(Idx, FUsers[Idx].Alias, FUsers[Idx].Level);
  
  FUsers[Idx].Active := False;
  FUsers[Idx].RecvLen := 0;
  
  BroadcastChat('Server', FUsers[Idx].Alias + ' left: ' + Reason);
  SendUserList;
end;

procedure TPDNetServer.Poll;
var
  FDSet: TFDSet;
  I, MaxFD: Integer;
  TV: TTimeVal;
begin
  if not FRunning then Exit;
  
  { Build select set }
  fpFD_ZERO(FDSet);
  fpFD_SET(FListenSock, FDSet);
  MaxFD := FListenSock;
  for I := 0 to PD_MAX_USERS - 1 do
    if FUsers[I].Active then begin
      fpFD_SET(FUsers[I].Socket, FDSet);
      if FUsers[I].Socket > MaxFD then MaxFD := FUsers[I].Socket;
    end;
  
  TV.tv_sec := 0;
  TV.tv_usec := 10000; { 10ms }
  
  if fpSelect(MaxFD + 1, @FDSet, nil, nil, @TV) <= 0 then Exit;
  
  { New connection? }
  {$IFDEF GO32V2}
  if fpFD_ISSET(FListenSock, FDSet) then
  {$ELSE}
  if fpFD_ISSET(FListenSock, FDSet) <> 0 then
  {$ENDIF}
    HandleNewConnection;
  
  { Data from existing users? }
  for I := 0 to PD_MAX_USERS - 1 do
  {$IFDEF GO32V2}
    if FUsers[I].Active and fpFD_ISSET(FUsers[I].Socket, FDSet) then
  {$ELSE}
    if FUsers[I].Active and (fpFD_ISSET(FUsers[I].Socket, FDSet) <> 0) then
  {$ENDIF}
      HandleUserData(I);
end;

procedure TPDNetServer.KickUser(Idx: Integer; const Reason: String);
begin
  DisconnectUser(Idx, 'Kicked: ' + Reason);
end;

procedure TPDNetServer.SetUserLevel(Idx: Integer; Level: TUserLevel);
var Msg: TPDNetMsg; P: Integer;
begin
  if (Idx >= 0) and (Idx < PD_MAX_USERS) and FUsers[Idx].Active then begin
    FUsers[Idx].Level := Level;
    Msg.Cmd := CMD_USERSTATUS;
    P := 0;
    Msg.Data[P] := Idx; Inc(P);
    Msg.Data[P] := Ord(Level); Inc(P);
    Msg.Len := P + 1;
    SendToAll(Msg, -1);
  end;
end;

procedure TPDNetServer.BroadcastChat(const From, Text: String);
var Msg: TPDNetMsg;
begin
  Msg := BuildChatMsg(From, Text);
  SendToAll(Msg, -1);
end;

{ ---- TPDNetClient ---- }

{$IFDEF CPU16}procedure TPDNetClient.Init(ACanvas: TPDCanvas);{$ELSE}constructor TPDNetClient.Create(ACanvas: TPDCanvas);{$ENDIF}
begin
  inherited Create;
  FCanvas := ACanvas;
  FSocket := -1;
  FConnected := False;
  FRecvLen := 0;
  FUserCount := 0;
  FMyIndex := -1;
  FLevel := ulViewer;
end;

{$IFDEF CPU16}procedure TPDNetClient.Done;{$ELSE}destructor TPDNetClient.Destroy;{$ENDIF}
begin
  Disconnect;
  inherited;
end;

procedure TPDNetClient.SendRaw(const Msg: TPDNetMsg);
var Hdr: array[0..4] of Byte;
begin
  if not FConnected then Exit;
  Hdr[0] := Msg.Len and $FF;
  Hdr[1] := (Msg.Len shr 8) and $FF;
  Hdr[2] := (Msg.Len shr 16) and $FF;
  Hdr[3] := (Msg.Len shr 24) and $FF;
  Hdr[4] := Msg.Cmd;
  fpSend(FSocket, @Hdr, 5, PD_SEND_FLAGS);
  if Msg.Len > 1 then
    fpSend(FSocket, @Msg.Data, Msg.Len - 1, PD_SEND_FLAGS);
end;

function TPDNetClient.Connect(const Host: String; APort: Word;
  const AAlias, APass: String): Boolean;
var
  Addr: TInetSockAddr;
  HostEnt: LongWord;
  Msg: TPDNetMsg;
  {$IFDEF GO32V2}
  InAddr: TInAddr;
  {$ENDIF}
  P: Integer;
begin
  Result := False;
  FAlias := AAlias;
  
  FSocket := fpSocket(AF_INET, SOCK_STREAM, 0);
  if FSocket < 0 then Exit;
  
  {$IFDEF GO32V2}
  InAddr := StrToHostAddr(Host);
  Move(InAddr, HostEnt, 4);
  {$ELSE}
  HostEnt := htonl(LongWord(StrToHostAddr(Host)));
  {$ENDIF}
  
  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(APort);
  Addr.sin_addr.s_addr := HostEnt;
  
  if fpConnect(FSocket, @Addr, SizeOf(Addr)) <> 0 then begin
    CloseSocket(FSocket);
    FSocket := -1;
    Exit;
  end;
  
  FConnected := True;
  
  { Send AUTH }
  Msg.Cmd := CMD_AUTH;
  P := 0;
  Msg.Data[P] := PD_NET_VERSION; Inc(P);
  MsgPackStr(Msg.Data, P, AAlias);
  MsgPackStr(Msg.Data, P, APass);
  Msg.Len := P + 1;
  SendRaw(Msg);
  
  Result := True;
end;

procedure TPDNetClient.Disconnect;
var Msg: TPDNetMsg; P: Integer;
begin
  if FConnected then begin
    try
      Msg.Cmd := CMD_BYE;
      P := 0;
      MsgPackStr(Msg.Data, P, 'Quit');
      Msg.Len := P + 1;
      SendRaw(Msg);
    except
    end;
    CloseSocket(FSocket);
    FSocket := -1;
    FConnected := False;
  end;
end;

function TPDNetClient.TryReadMessage(var Msg: TPDNetMsg): Boolean;
var FrameLen: LongWord; N: Integer;
begin
  Result := False;
  if FRecvLen < 5 then Exit;
  
  FrameLen := FRecvBuf[0] or (LongWord(FRecvBuf[1]) shl 8) or
    (LongWord(FRecvBuf[2]) shl 16) or (LongWord(FRecvBuf[3]) shl 24);
  
  if FrameLen > PD_MAX_MSG then begin Disconnect; Exit; end;
  if LongWord(FRecvLen) < FrameLen + 4 then Exit;
  
  Msg.Len := FrameLen;
  Msg.Cmd := FRecvBuf[4];
  if FrameLen > 1 then
    Move(FRecvBuf[5], Msg.Data, FrameLen - 1);
  
  N := FrameLen + 4;
  Dec(FRecvLen, N);
  if FRecvLen > 0 then
    Move(FRecvBuf[N], FRecvBuf[0], FRecvLen);
  
  Result := True;
end;

procedure TPDNetClient.Poll;
var
  N: Integer;
  Msg: TPDNetMsg;
  FDSet: TFDSet;
  TV: TTimeVal;
begin
  if not FConnected then Exit;
  
  fpFD_ZERO(FDSet);
  fpFD_SET(FSocket, FDSet);
  TV.tv_sec := 0; TV.tv_usec := 10000;
  
  if fpSelect(FSocket + 1, @FDSet, nil, nil, @TV) > 0 then begin
    N := fpRecv(FSocket, @FRecvBuf[FRecvLen], PD_RECV_BUF - FRecvLen, 0);
    if N <= 0 then begin Disconnect; Exit; end;
    Inc(FRecvLen, N);
  end;
  
  while TryReadMessage(Msg) do
    ProcessMessage(Msg);
end;

procedure TPDNetClient.ProcessMessage(const Msg: TPDNetMsg);
var
  P, I, Count, X, Y: Integer;
  From, Text: String;
  E: TPDCanvasElement;
  W, H, X1, Y1, X2, Y2: Word;
begin
  case Msg.Cmd of
    CMD_WELCOME: begin
      P := 0;
      FMyIndex := Msg.Data[P]; Inc(P);
      FLevel := TUserLevel(Msg.Data[P]); Inc(P);
      W := MsgUnpackWord(Msg.Data, P);
      H := MsgUnpackWord(Msg.Data, P);
      FCanvas.Resize(W, H);
    end;
    
    CMD_CHAT: begin
      P := 0;
      From := MsgUnpackStr(Msg.Data, P);
      Text := MsgUnpackStr(Msg.Data, P);
      if Assigned(FOnChat) then FOnChat(From, Text);
    end;
    
    CMD_USERLIST: begin
      P := 0;
      Count := Msg.Data[P]; Inc(P);
      FUserCount := Count;
      for I := 0 to PD_MAX_USERS - 1 do FUsers[I].Active := False;
      for I := 0 to Count - 1 do begin
        X := Msg.Data[P]; Inc(P); { user index }
        FUsers[X].Alias := MsgUnpackStr(Msg.Data, P);
        FUsers[X].Level := TUserLevel(Msg.Data[P]); Inc(P);
        FUsers[X].Active := True;
      end;
    end;
    
    CMD_LOADDOC: begin
      P := 0;
      W := MsgUnpackWord(Msg.Data, P);
      H := MsgUnpackWord(Msg.Data, P);
      FCanvas.Resize(W, H);
      for Y := 0 to H - 1 do
        for X := 0 to W - 1 do begin
          if P + 2 < Integer(Msg.Len) then begin
            E.Ch.Ch := Msg.Data[P] or (SmallInt(Msg.Data[P+1]) shl 8);
            Inc(P, 2);
            E.Attr.Init(Msg.Data[P]); Inc(P);
            FCanvas[X, Y] := E;
          end;
        end;
      if Assigned(FOnUpdate) then FOnUpdate(0, 0, W-1, H-1);
    end;
    
    CMD_UPDATE: begin
      P := 0;
      X1 := MsgUnpackWord(Msg.Data, P);
      Y1 := MsgUnpackWord(Msg.Data, P);
      X2 := MsgUnpackWord(Msg.Data, P);
      Y2 := MsgUnpackWord(Msg.Data, P);
      for Y := Y1 to Y2 do
        for X := X1 to X2 do begin
          if P + 2 < Integer(Msg.Len) then begin
            E.Ch.Ch := Msg.Data[P] or (SmallInt(Msg.Data[P+1]) shl 8);
            Inc(P, 2);
            E.Attr.Init(Msg.Data[P]); Inc(P);
            FCanvas[X, Y] := E;
          end;
        end;
      if Assigned(FOnUpdate) then FOnUpdate(X1, Y1, X2, Y2);
    end;
    
    CMD_USERSTATUS: begin
      P := 0;
      I := Msg.Data[P]; Inc(P);
      FUsers[I].Level := TUserLevel(Msg.Data[P]); Inc(P);
      if I = FMyIndex then FLevel := FUsers[I].Level;
    end;
    
    CMD_BYE: begin
      Disconnect;
    end;
  end;
end;

procedure TPDNetClient.SendChat(const Text: String);
var Msg: TPDNetMsg; P: Integer;
begin
  Msg.Cmd := CMD_CHAT;
  P := 0;
  MsgPackStr(Msg.Data, P, Text);
  Msg.Len := P + 1;
  SendRaw(Msg);
end;

procedure TPDNetClient.SendUpdate(X1, Y1, X2, Y2: Integer);
var Msg: TPDNetMsg; P, X, Y: Integer; E: TPDCanvasElement;
begin
  Msg.Cmd := CMD_UPDATE;
  P := 0;
  MsgPackWord(Msg.Data, P, X1);
  MsgPackWord(Msg.Data, P, Y1);
  MsgPackWord(Msg.Data, P, X2);
  MsgPackWord(Msg.Data, P, Y2);
  for Y := Y1 to Y2 do
    for X := X1 to X2 do begin
      if P + 3 >= PD_MAX_MSG then Break;
      E := FCanvas[X, Y];
      Msg.Data[P] := E.Ch.Ch and $FF; Inc(P);
      Msg.Data[P] := (E.Ch.Ch shr 8) and $FF; Inc(P);
      Msg.Data[P] := E.Attr.ToByte; Inc(P);
    end;
  Msg.Len := P + 1;
  SendRaw(Msg);
end;

procedure TPDNetClient.SendCursor(X, Y: Integer);
var Msg: TPDNetMsg; P: Integer;
begin
  Msg.Cmd := CMD_CURSOR;
  P := 0;
  MsgPackWord(Msg.Data, P, X);
  MsgPackWord(Msg.Data, P, Y);
  Msg.Len := P + 1;
  SendRaw(Msg);
end;

function TPDNetClient.GetUser(Idx: Integer): TPDNetUser;
begin
  if (Idx >= 0) and (Idx < PD_MAX_USERS) then
    Result := FUsers[Idx]
  else begin Result.Active := False; Result.Alias := ''; end;
end;

end.
