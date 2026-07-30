{*************************************************************}
{                     IMPORTANT NOTE:                         }
{ This software is provided 'as-is', without any express or   }
{ implied warranty. In no event will the author be held       }
{ liable for any damages arising from the use of this         }
{ software.                                                   }
{ Permission is granted to anyone to use this software for    }
{ any purpose, including commercial applications, and to      }
{ alter it and redistribute it freely, subject to the         }
{ following restrictions:                                     }
{ 1. The origin of this software must not be misrepresented,  }
{    you must not claim that you wrote the original software. }
{    If you use this software in a product, an acknowledgment }
{    in the product documentation would be appreciated but is }
{    not required.                                            }
{ 2. Altered source versions must be plainly marked as such,  }
{    and must not be misrepresented as being the original     }
{    software.                                                }
{ 3. This notice may not be removed or altered from any       }
{    source distribution.                                     }
{*************************************************************}

{                               VERSION : 1.13 Final                         }
{                                                                            }
{ This unit have been created by Jyrki Kyllönen. This is my version of what  }
{ Winsock TCP/IP programming should be all about.                            }
{ See README for more notes.                                                 }

{$IFNDEF VER80}          {Delphi 1}
 {$IFNDEF VER90}         {Delphi 2}
  {$IFNDEF VER93}        {BCB 1}
   {$DEFINE D3}          {* Delphi 3 or higher}
   {$IFNDEF VER100}      {Delphi 3}
    {$IFNDEF VER110}     {BCB 3}
     {$DEFINE D4}        {* Delphi 4 or higher}
     {$IFNDEF VER120}    {Delphi 4}
      {$IFNDEF VER125}   {BCB 4}
       {$DEFINE D5}      {* Delphi 5 or higher}
       {$IFNDEF VER130}  {Delphi/BCB 5}
        {$ObjExportAll On}
        {$WARN SYMBOL_PLATFORM OFF}
        {$DEFINE D6}     {* Delphi 6 or higher}
        {$IFNDEF VER140}  {Delphi/BCB 6}
         {$DEFINE D7}
         {$IFNDEF VER150} {Delphi/BCB 7}
           { * delphi 8? * }
         {$ENDIF}
        {$ENDIF}
       {$ENDIF}
      {$ENDIF}
     {$ENDIF}
    {$ENDIF}
   {$ENDIF}
  {$ENDIF}
 {$ENDIF}
{$ENDIF}

{$IFDEF D7}
  {$WARN UNIT_DEPRECATED OFF}
  {$WARN SYMBOL_DEPRECATED OFF}
{$ENDIF}

unit FasterTCP;
{$DEFINE DEBUGMODEOFF} 
{Can also use INT64_STREAMS}
{$IFDEF FPC}
  {$mode objfpc}
{$ENDIF}
{$H+}
interface

uses                                      
  Windows, Messages, Classes, WinSock, ExtCtrls
  {$IFDEF FPC},LResources{$ENDIF} ;

const
  SYNCSELECT_ID = WM_USER + $0001;
  {Packet structure: Size(4 bytes)|Command(4 bytes)|data}
  OWN_ID = 1000;
  StreamSize_of_Size = {$IFDEF INT64_STREAMS} SizeOf(Int64) {$ELSE} SizeOf(LongInt){$ENDIF};

type
 TPingStatus = (PingOK,WaitingPing);
 TClientStatusUpdate = (UpdateNone, Rooms, AllClients);
 TFasterHeader = record
  Size: LongInt;
  Command: LongInt;
  Complete: Boolean;
 end;

 TFasterPacket = record
    Size, Command: LongInt;
    Data: Pointer;
  end;

  TStreamSize = {$IFDEF INT64_STREAMS} Int64 {$ELSE} LongInt {$ENDIF};

  TFasterTCPServerClient = class; //defined here so that declaration of Events wont raise error about it

  TFasterTCPAcceptEvent =                procedure(Sender: TObject; Client: TFasterTCPServerClient; var Accept: Boolean) of object;
  TFasterTCPClientDataReceivedEvent =    procedure(Sender: TObject; DataSize: TStreamSize; DataInfo: String) of object;
  TFasterTCPClientDataAvailEvent =       procedure(Sender: TObject; Data: TMemoryStream; DataSize: LongInt) of object;
  TFasterTCPClientIOEvent =              procedure(Sender: TObject; TheMessage: String) of object;
  TFasterTCPClientNameListEvent =        procedure(Sender: TObject; List: TStringList) of object;
  TFasterTCPClientNewStreamComingEvent = procedure(Sender: TObject; StreamSize: TStreamSize; DataInfo: String; Var Accept: Boolean) of object;
  TFasterTCPClientStatusEvent =          procedure(Sender: TObject; Name: String) of object;
  TFasterTCPClientToClientEvent =        procedure(Sender: TObject; Name: String; Data: TMemoryStream) of object;
  TFasterTCPClientUnknownIDEvent =       procedure(Sender: TObject; Data: TMemoryStream; ID: LongInt) of object;
  TFasterTCPErrorEvent =                 procedure(Sender: TObject; Socket: TSocket; ErrorCode: LongInt; ErrorMsg: String) of object;
  TFasterTCPRegisterUserEvent =          procedure(Sender: TObject; Client: TFasterTCPServerClient; Var DontLetIn: Boolean; TheRoom,TheUserName : PChar) of object;
  TFasterTCPServerDataReceivedEvent =    procedure(Sender: TObject; Client: TFasterTCPServerClient; DataSize: TStreamSize; DataInfo: String) of object;
  TFasterTCPServerDataAvailEvent =       procedure(Sender: TObject; Client: TFasterTCPServerClient; Data: TMemoryStream; DataSize: LongInt) of object;
  TFasterTCPServerEvent =                procedure(Sender: TObject; Client: TFasterTCPServerClient) of object;
  TFasterTCPServerIOEvent =              procedure(Sender: TObject; Client: TFasterTCPServerClient; TheMessage: String) of object;
  TFasterTCPServerNewStreamComingEvent = procedure(Sender: TObject; Client: TFasterTCPServerClient; StreamSize: TStreamSize; DataInfo: String; Var Accept: Boolean) of object;
  TFasterTCPServerTimeOutEvent =         procedure(Sender: TObject; Client: TFasterTCPServerClient; Var ForceDisconnectClient: Boolean) of object;
  TFasterTCPServerUnknownIDEvent =       procedure(Sender: TObject; Client: TFasterTCPServerClient; Data: TMemoryStream; ID: LongInt) of object;

  TCustomFasterSocket = class(TComponent)
  private
    FAllowChangeHostAndPortOnConnection: Boolean;
    FHost: AnsiString;
    FPort: Word;
    FSocket: TSocket;
    FOnError: TFasterTCPErrorEvent;

    {$IFDEF DEBUGMODEON}
    FDebugInfo: TStringList;
    {$ENDIF}

    HostEnt: PHostEnt;
    ProcessingCommands: Boolean;
    SockAddrIn: TSockAddrIn;
    WindowHandle: hWnd;

    procedure   FlushSendBuffer(Sender: TObject); virtual; abstract;
    function    ReceiveFrom(Const aSocket: TSocket; Buffer: Pointer; BufLength: LongInt): LongInt; // returns N of bytes read
    procedure   ReceiveStreamFrom(Const aSocket: TSocket; Stream: TMemoryStream; DataSize: LongInt);
    procedure   SendBufferTo(Const aSocket: TCustomFasterSocket; Buffer: Pointer; BufLength: LongInt);
    procedure   SendStreamTo(Const aSocket: TCustomFasterSocket; Stream: TStream; Size: LongInt);
    procedure   SendPacketTo(aSocket: TCustomFasterSocket; Packet: TFasterPacket);
    procedure   ProcessTCPSelect(var Msg: TMessage); message SYNCSELECT_ID;
    procedure   WndProc(var Message: TMessage); virtual;
  protected  
    // For internal use
    FConnections: TList;
    ReceiveMS: TMemoryStream;
    SendMS: TMemoryStream;
    procedure   DoAccept; virtual; abstract;
    procedure   DoClose(aSocket: TSocket); virtual; abstract;
    procedure   DoConnect; virtual; abstract;
    Procedure   ProcessCommands(Client: TFasterTCPServerClient; Data: TMemoryStream; Command: LongInt); virtual; abstract;
    procedure   SetHost(Value: AnsiString); virtual; abstract;
    procedure   SetPort(Value: Word); virtual; abstract;
    procedure   SocketError(aSocket: TSocket; ErrorCode: LongInt); virtual;
  public
    constructor Create(aOwner: TComponent); override;
    destructor  Destroy; override;
    property    AllowChangeHostAndPortOnConnection: Boolean read FAllowChangeHostAndPortOnConnection write FAllowChangeHostAndPortOnConnection default False;
    property    Host: AnsiString read FHost write SetHost;
    property    OnError: TFasterTCPErrorEvent read FOnError write FOnError;
    property    Port: Word read FPort write SetPort default 0;
    property    Socket: TSocket read FSocket write FSocket;

    {$IFDEF DEBUGMODEON}
      property  DebugInfo: TStringList read FDebugInfo write FDebugInfo;
    {$ENDIF}
  end;

  { TFasterTCPServer }
  TFasterTCPServer = class(TCustomFasterSocket)
  private
    FAllowSameUserNames: Boolean;
    FClientStatusUpdate: TClientStatusUpdate;
    FListen: Boolean;
    FOnAccept: TFasterTCPAcceptEvent;
    FOnClientAcceptStream: TFasterTCPServerEvent;
    FOnClientConnected: TFasterTCPServerEvent;
    FOnClientDenyStream: TFasterTCPServerEvent;
    FOnClientDisconnected: TFasterTCPServerEvent;
    FOnClientMessageCome: TFasterTCPServerIOEvent;
    FOnClientNeedMoreData: TFasterTCPServerEvent;
    FOnClientPacketCome: TFasterTCPServerDataAvailEvent;
    FOnClientPong: TFasterTCPServerEvent;
    FOnClientReceivedStream: TFasterTCPServerEvent;
    FOnClientStopReceivingStream: TFasterTCPServerEvent;
    FOnClientStopSendingStream: TFasterTCPServerEvent;
    FOnClientTimeOut: TFasterTCPServerTimeOutEvent;
    FOnNewStreamComing: TFasterTCPServerNewStreamComingEvent;
    FOnServerGetUserName :TFasterTCPRegisterUserEvent;
    FOnStreamReceived: TFasterTCPServerDataReceivedEvent;
    FOnUnknownPacketID: TFasterTCPServerUnknownIDEvent;
    FPingInterval: Cardinal;
    FPingTimer: TTimer;
    procedure   FlushSendBuffer(Sender: TObject); override;
    function    GetLocalHostName: AnsiString;
    function    GetLocalIP: AnsiString;
    Procedure   SendCommand(Client: TFasterTCPServerClient; Command, CommandDataSize: LongInt; Data: Pointer);
    procedure   SetNoneStr(Value: AnsiString); //Does nothing, but allows user to access the LocalHostName and -IP properties. User can't access read-only values on DesignMode.
  protected
    procedure   DoAccept; override;
    procedure   DoClose(aSocket: TSocket); override;
    procedure   DoMessageCome(Client: TFasterTCPServerClient; Const ProcessedMessage: String);
    procedure   DoPacketCome(Client: TFasterTCPServerClient; Data: TMemoryStream; DataSize: LongInt);
    procedure   ServerDoPingUpdate(Sender: TObject); virtual;
    Procedure   ProcessCommands(Client: TFasterTCPServerClient; Data: TMemoryStream; Command: LongInt); override;  
    procedure   SocketError(aSocket: TSocket; ErrorCode: LongInt); override;
    procedure   SetListen(Value: Boolean); virtual;
    procedure   SetMaxPingInterval(Value: Cardinal); virtual;
    procedure   SetPort(Value: Word); override;
  public
    constructor Create(aOwner: TComponent); override;
    procedure   AskMoreData(Client: TFasterTCPServerClient);
    procedure   AskToReceiveStream(Client: TFasterTCPServerClient; Const DataSize: TStreamSize;
                                   Const DataInfo: String);
    procedure   Broadcast(Buffer: PChar; BufLength: LongInt);
    procedure   BroadcastStream(Stream: TStream; SendSize: LongInt);
    property    Clients: TList read FConnections;
    destructor  Destroy; override;
    procedure   DisconnectAClient(Client: TFasterTCPServerClient);
    procedure   DisconnectEveryone;
    procedure   KickOutAClient(Client: TFasterTCPServerClient);
    procedure   MakeRoomUserNameList(Const RoomName: String; TheList: TStringList);
    procedure   MakeUserNameList(TheList: TStringList);
    Procedure   Send(Client: TFasterTCPServerClient; Buffer: PChar; BufLength: LongInt);
    Procedure   SendCustomPacket(Client: TFasterTCPServerClient; ID, DataSize: LongInt; Data: TStream);
    Procedure   SendCustomPacketEx(Client: TFasterTCPServerClient; ID, DataSize: LongInt; Data: Pointer);
    Procedure   SendStream(Client: TFasterTCPServerClient; Stream: TStream; Size: LongInt); 
    procedure   StopReceivingData(Client: TFasterTCPServerClient);
    procedure   StopSendingData(Client: TFasterTCPServerClient);
    procedure   UpdatePingStatuses;
  published
    property    AllowChangeHostAndPortOnConnection;
    property    AllowSameUserNames: Boolean read FAllowSameUserNames write FAllowSameUserNames default False;
    property    ClientStatusUpdate: TClientStatusUpdate read FClientStatusUpdate write FClientStatusUpdate default UpdateNone;
    property    Listen: Boolean read FListen write SetListen stored False;
    property    LocalHostName: AnsiString read GetLocalHostName write SetNoneStr stored False;
    property    LocalIP: AnsiString read GetLocalIP write SetNoneStr stored False;
    property    MaxPing: Cardinal read FPingInterval write SetMaxPingInterval default 1000;
    property    Port;
    property    OnAccept: TFasterTCPAcceptEvent read FOnAccept write FOnAccept;
    property    OnClientAcceptStream: TFasterTCPServerEvent read FOnClientAcceptStream write FOnClientAcceptStream;
    property    OnClientConnected: TFasterTCPServerEvent read FOnClientConnected write FOnClientConnected;
    property    OnClientDenyStream: TFasterTCPServerEvent read FOnClientDenyStream write FOnClientDenyStream;
    property    OnClientDisconnected: TFasterTCPServerEvent read FOnClientDisconnected write FOnClientDisconnected;
    property    OnClientMessageCome: TFasterTCPServerIOEvent read FOnClientMessageCome write FOnClientMessageCome;
    property    OnClientNeedMoreData: TFasterTCPServerEvent read FOnClientNeedMoreData write FOnClientNeedMoreData;
    property    OnClientPacketCome: TFasterTCPServerDataAvailEvent read FOnClientPacketCome write FOnClientPacketCome;
    property    OnClientPong: TFasterTCPServerEvent read FOnClientPong write FOnClientPong;
    property    OnClientReceivedStream: TFasterTCPServerEvent read FOnClientReceivedStream write FOnClientReceivedStream;
    property    OnClientStopReceivingStream: TFasterTCPServerEvent read FOnClientStopReceivingStream write FOnClientStopReceivingStream;
    property    OnClientStopSendingStream: TFasterTCPServerEvent read FOnClientStopSendingStream write FOnClientStopSendingStream;
    property    OnClientTimeOut: TFasterTCPServerTimeOutEvent read FOnClientTimeOut Write FOnClientTimeOut;
    property    OnError;
    property    OnNewStreamComing: TFasterTCPServerNewStreamComingEvent read FOnNewStreamComing write FOnNewStreamComing;
    property    OnServerGetUserName: TFasterTCPRegisterUserEvent read FOnServerGetUserName write FOnServerGetUserName;
    property    OnStreamReceived: TFasterTCPServerDataReceivedEvent read FOnStreamReceived write FOnStreamReceived;
    property    OnUnknownPacketID: TFasterTCPServerUnknownIDEvent read FOnUnknownPacketID write FOnUnknownPacketID;
  end;

  {TFasterTCPServerClient}
  TFasterTCPServerClient = class(TCustomFasterSocket)
  private
    FConnected: Boolean;
    FExtraDataObject: TObject;   
    FlushTimer: TTimer;
    FRoom: String;
    FStream_FullSize: TStreamSize;
    FStreamDataInfo: String;
    FUserName: String;
    procedure   FlushSendBuffer(Sender: TObject); override;
  protected
    FPingStatus: TPingStatus;     
    FStreamDataReceived: TStreamSize;  
    FTimeOuts:  LongInt;
    Procedure   ClearStreamProperties;
    procedure   SetConnected(Value: Boolean); virtual;
  public
    constructor Create(aOwner: TComponent); override;
    destructor  Destroy; override;
    property    Connected: Boolean read FConnected write SetConnected stored False;
    property    ExtraDataObject: TObject read FExtraDataObject Write FExtraDataObject;
    property    PingStatus: TPingStatus read FPingStatus Stored False;
    property    Room: String read FRoom write FRoom;
    property    StreamDataFullSize: TStreamSize read FStream_FullSize Stored False;
    property    StreamDataInfo: String read FStreamDataInfo Stored False;
    property    StreamDataReceived: TStreamSize read FStreamDataReceived Stored False;
    property    TimeOuts: LongInt read FTimeOuts;
    property    UserName: String read FUserName write FUserName;
  end;

  {Server uses Client's FStreamDataReceived to know how much data it has received from
   the client. On Client it means how much data the Client has received from the server.
   StreamDataFullSize means the size received from last AskToReceiveStream-call.
   AskToReceiveStream sets the StreamDataInfo, -Received, -Size and fires the
   OnNewStreamComing event, nothing more.}

  {TFasterTCPClient}
  TFasterTCPClient = class(TFasterTCPServerClient)
  private
    FAutoTryReconnect: Boolean;  
    FOnAClientJoin: TFasterTCPClientStatusEvent;
    FOnAClientLeave: TFasterTCPClientStatusEvent;
    FOnConnected: TNotifyEvent;
    FOnDisconnected: TNotifyEvent;
    FOnMessageCome: TFasterTCPClientIOEvent;
    FOnNameListReceived: TFasterTCPClientNameListEvent;
    FOnNewStreamComing: TFasterTCPClientNewStreamComingEvent;
    FOnPacketCome: TFasterTCPClientDataAvailEvent;
    FOnPacketFromClient: TFasterTCPClientToClientEvent;
    FOnServerAccept: TNotifyEvent;
    FOnServerAcceptStream: TNotifyEvent;
    FOnServerDenyStream: TNotifyEvent;
    FOnServerDisconnectAll: TNotifyEvent;
    FOnServerDisconnectYou: TNotifyEvent;
    FOnServerKickYouOut: TNotifyEvent;
    FOnServerNameInUse: TNotifyEvent;
    FOnServerNeedMoreData: TNotifyEvent;
    FOnServerNotLetIn: TNotifyEvent;
    FOnServerPong: TNotifyEvent;
    FOnServerReceivedStream: TNotifyEvent;
    FOnServerStopReceivingStream: TNotifyEvent;
    FOnServerStopSendingStream: TNotifyEvent;
    FOnStreamReceived: TFasterTCPClientDataReceivedEvent;
    FOnTimeOut: TNotifyEvent;
    FOnUnknownPacketID: TFasterTCPClientUnknownIDEvent;  
    FPingInterval: Cardinal;
    FPingTimer: TTimer;
    function    GetIP: LongInt;    
    Procedure   SendCommand(Command, CommandDataSize: LongInt; Data: Pointer);
    procedure   SetIP(Value: LongInt);
  protected
//    procedure WndProc(var Message: TMessage); override;

    procedure   DoClose(aSocket: TSocket); override;
    procedure   DoConnect; override;
    procedure   DoMessageCome(ProcessedMessage: String);
    procedure   DoPacketCome(Data: TMemoryStream; DataSize: LongInt); 
    Procedure   ProcessCommands(Client: TFasterTCPServerClient; Data: TMemoryStream; Command: LongInt); override;
    procedure   SetConnected(Value: Boolean); override;
    procedure   SetHost(Value: AnsiString); override;
    procedure   SetMaxPingInterval(Value: Cardinal); virtual;
    procedure   SetPort(Value: Word); override;
    procedure   SocketError(aSocket: TSocket; ErrorCode: LongInt); override;
  public                            
    constructor Create(aOwner: TComponent); override;
    destructor  Destroy; override;
    property    IP: LongInt read GetIP write SetIP;
    procedure   AskMoreData;
    procedure   AskToReceiveStream(Const DataSize: TStreamSize; Const DataInfo: String);
    procedure   ClientDoPingUpdate(Sender: TObject); virtual;
    procedure   Send(Buffer: PChar; BufLength: LongInt);
    procedure   SendCustomPacket(ID, DataSize: LongInt; Data: TStream);
    procedure   SendCustomPacketEx(ID, DataSize: LongInt; Data: Pointer);
    procedure   SendStream(Stream: TStream; Size: LongInt);
    procedure   SendToClient(Buffer: Pointer; ClientName: PChar; Size: LongInt);
    procedure   StopReceivingData;
    procedure   StopSendingData;
    procedure   UpdatePingStatus;
  published
    property    AllowChangeHostAndPortOnConnection;
    property    AutoTryReconnect: Boolean read FAutoTryReconnect write FAutoTryReconnect default False;
    property    Connected;
    property    Host;  
    property    MaxPing: Cardinal read FPingInterval write SetMaxPingInterval default 1000;
    property    Port;
    property    Room;
    property    UserName;   
    property    OnAClientJoin: TFasterTCPClientStatusEvent read FOnAClientJoin write FOnAClientJoin;
    property    OnAClientLeave: TFasterTCPClientStatusEvent read FOnAClientLeave write FOnAClientLeave;
    property    OnConnected: TNotifyEvent read FOnConnected write FOnConnected;
    property    OnDisconnected: TNotifyEvent read FOnDisconnected write FOnDisconnected;
    property    OnError;
    property    OnMessageCome: TFasterTCPClientIOEvent read FOnMessageCome write FOnMessageCome;  
    property    OnNameListReceived: TFasterTCPClientNameListEvent read FOnNameListReceived write FOnNameListReceived;
    property    OnNewStreamComing: TFasterTCPClientNewStreamComingEvent read FOnNewStreamComing write FOnNewStreamComing;
    property    OnPacketCome: TFasterTCPClientDataAvailEvent read FOnPacketCome write FOnPacketCome;
    property    OnPacketFromClient: TFasterTCPClientToClientEvent read FOnPacketFromClient write FOnPacketFromClient;
    property    OnServerAccept: TNotifyEvent read FOnServerAccept write FOnServerAccept;
    property    OnServerAcceptStream: TNotifyEvent read FOnServerAcceptStream write FOnServerAcceptStream;
    property    OnServerDenyStream: TNotifyEvent read FOnServerDenyStream write FOnServerDenyStream;
    property    OnServerDisconnectAll: TNotifyEvent read FOnServerDisconnectAll write FOnServerDisconnectAll;
    property    OnServerDisconnectYou: TNotifyEvent read FOnServerDisconnectYou write FOnServerDisconnectYou;
    property    OnServerKickYouOut: TNotifyEvent read FOnServerKickYouOut write FOnServerKickYouOut;
    property    OnServerNameInUse: TNotifyEvent read FOnServerNameInUse write FOnServerNameInUse;
    property    OnServerNeedMoreData: TNotifyEvent read FOnServerNeedMoreData write FOnServerNeedMoreData;
    property    OnServerNotLetIn: TNotifyEvent read FOnServerNotLetIn write FOnServerNotLetIn;
    property    OnServerPong: TNotifyEvent read FOnServerPong write FOnServerPong;
    property    OnServerReceivedStream: TNotifyEvent read FOnServerReceivedStream write FOnServerReceivedStream;
    property    OnServerStopReceivingStream: TNotifyEvent read FOnServerStopReceivingStream write FOnServerStopReceivingStream;
    property    OnServerStopSendingStream: TNotifyEvent read FOnServerStopSendingStream write FOnServerStopSendingStream;
    property    OnStreamReceived: TFasterTCPClientDataReceivedEvent read FOnStreamReceived write FOnStreamReceived;
    property    OnTimeOut: TNotifyEvent read FOnTimeOut write FOnTimeOut;
    property    OnUnknownPacketID: TFasterTCPClientUnknownIDEvent read FOnUnknownPacketID write FOnUnknownPacketID;
  end;

procedure Register;

Procedure GetLocalIPs(list: TStringList);

implementation

uses SysUtils, Forms;

const

{ -Those with =1 send data in their packets
  -ID:s are used on ProcessCommands.
  }
  ASK_MORE_DATA_ID =                    1;
  ASKING_TO_RECEIVE_DATA_ID =           2;                      // = 1
  BroadCast_STREAM_Packet_ID =          3;
  DATA_RECEIVE_DENIED_ID =              4;
  DATA_RECEIVE_OK_ID =                  5;                      // = 1
  DATA_RECEIVING_STOPPED_ID =           6;
  DATA_SENDING_STOPPED_ID =             7;
  MESSAGE_Packet_ID =                   8;
  PING_ID =                             9;
  PONG_ID =                             10; //See also the constant values defined in the beginning of the unit
  REGISTER_NAME_ROOM_ID =               11;                     // = 1
  SERVER_ASK_REGISTER_NAME_ROOM_ID =    12;
  SERVER_DISCONNECT_ALL_ID =            13;
  SERVER_DISCONNECT_YOU_ID =            14;
  SERVER_KICK_OUT_ID =                  15;
  SERVER_NAME_IN_USE_ID =               16;
  SERVER_NOT_LET_IN_ID =                17; //(client must still be in to get this and then disconnect)
  SERVER_REGISTER_OK_ID =               18;
  STREAM_Packet_ID =                    19;
  STREAM_RECEIVED_ID =                  20;
  NAMELIST_ID =                         21;
  CLIENT_JOIN_ID =                      22;
  CLIENT_LEAVE_ID =                     23;
  CLIENT_TO_CLIENT_ID =                 24;
  HEADER_SIZE_OF_SIZE =                 sizeOf(LongInt);
  HEADER_SIZE_OF_COMMAND =              sizeOf(LongInt);
  HEADER_SIZE =                         HEADER_SIZE_OF_SIZE + HEADER_SIZE_OF_COMMAND;
  SEND_BUFFER_SIZE =                    16*1024;
  FLUSH_INTERVAL =                      10; //time between tries of flushing send buffer

  {Decreasing FLUSH_INTERVAL decreases the latency between server and clients,
   but setting it too low would just cause "operation would block" errors because
   the timer would just spam the socket all the time.}

{$IFNDEF D4}
type
  SunB = packed record
    s_b1, s_b2, s_b3, s_b4: Char;
  end;

  SunW = packed record
    s_w1, s_w2: Word;
  end;

  in_addr = record
    case Integer of
      0: (S_un_b: SunB);
      1: (S_un_w: SunW);
      2: (S_addr: LongInt);
  end;
{$ENDIF}

//WSAStartup and WSACleanup are called by FasterTCP
Procedure GetLocalIPs(list: TStringList);
type
  TAddressList = array[0..0] of PInAddr;
  PAddressList = ^TAddressList;
var
  HostEnt: PHostEnt;
  AddressList: PAddressList;
  HostName: array[0..MAX_PATH] of AnsiChar;
  I: Integer;
  //WSAData: TWSAData;
begin
  //WSAStartup($0101, WSAData);
  GetHostName(HostName, SizeOf(HostName));
  HostEnt := GetHostByName(HostName);
  if HostEnt = nil then
    Exit;

  AddressList := PAddressList(HostEnt^.h_addr_list);
  I := 0;
  while AddressList^[I] <> nil do
  begin
    list.Add(inet_ntoa(AddressList^[I]^));
    I := I +1;
  end;

  //WSACleanup;
end;

{ Internal utilities }

Function ConvertToString(Stream: TMemoryStream): String;
begin
  SetLength(Result, Stream.Size div (SizeOf(Char)));
  Stream.Read(Result[1], Stream.Size);
end;

Function CreatePacket(Size, Command: LongInt; Data: Pointer): TFasterPacket;
begin
  Result.Size := Size + HEADER_SIZE;//Header size is added here already!
  Result.Command := Command;
  Result.Data := Data;
end;

function IPToStr(IP: LongInt): AnsiString;
var
  Addr: TInAddr;
begin
  Addr.S_addr := IP;
  Result := inet_ntoa(Addr);
end;

function StrToIP(Host: PAnsiChar): LongInt;
begin
  Result := inet_addr(Host);
end;

{ Will clear OutputStream. After that the header is read if it is complete.
  If there is data, it is read, if data is complete, otherwise header and data are written to Output. }
function PacketStreamToPacket( PacketStream, OutputStream: TMemoryStream ): TFasterHeader;
var WriteSize: LongInt;
begin
  OutputStream.Clear;
  If PacketStream.Position + HEADER_SIZE <= PacketStream.Size then begin
    PacketStream.Read(Result.Size, HEADER_SIZE_OF_SIZE);
    PacketStream.Read(Result.Command, HEADER_SIZE_OF_COMMAND);
    WriteSize := Result.Size-HEADER_SIZE;
    If WriteSize>0 then begin
       if PacketStream.Position + WriteSize <= PacketStream.Size  then begin
        OutputStream.CopyFrom( PacketStream, WriteSize);  //Reading data that is after header
        Result.Complete := true;
      end else begin
        OutputStream.Write(Result.Size, HEADER_SIZE_OF_SIZE);
        OutputStream.Write(Result.Command, HEADER_SIZE_OF_COMMAND);
        Result.Size := 0;
        Result.Command := 0;
        Result.Complete := false;
        WriteSize := PacketStream.Size-PacketStream.Position;
        if WriteSize>0 then
          OutputStream.CopyFrom( PacketStream, WriteSize);
      end;
    end;
  end else begin
    Result.Size := 0;
    Result.Command := 0;
    WriteSize := PacketStream.Size-PacketStream.Position;
    Result.Complete := WriteSize=0;
    if WriteSize>0 then
      OutputStream.CopyFrom( PacketStream, WriteSize);
  end;
  OutputStream.Seek(0, soFromBeginning);
end;

{-------------------------------------------------------------------------------------------}


{ TCustomFasterSocket }     
constructor TCustomFasterSocket.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);

  FSocket := INVALID_SOCKET;
  ReceiveMS := TMemoryStream.Create;
  SendMS := TMemoryStream.Create;
  ProcessingCommands := false;
  WindowHandle := AllocateHWnd({$IFDEF FPC}@{$ENDIF}WndProc);

  {$IFDEF DEBUGMODEON}
    FDebugInfo:= TStringList.Create;
  {$ENDIF}
end;

destructor TCustomFasterSocket.Destroy;
begin
  DeallocateHWnd(WindowHandle);
  ReceiveMS.Free;
  SendMS.Free;
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Free;
  {$ENDIF}

  inherited Destroy;
end;

function TCustomFasterSocket.ReceiveFrom(Const aSocket: TSocket; Buffer: Pointer; BufLength: LongInt): LongInt;
begin
  Result := recv(aSocket, Buffer^, BufLength, 0);
  if Result = 0 then
    DoClose(aSocket)
  else
  If Result = SOCKET_ERROR then
   begin
    SocketError(aSocket, WSAGetLastError);
    Exit;
   end;
end;  

procedure TCustomFasterSocket.ReceiveStreamFrom(Const aSocket: TSocket; Stream: TMemoryStream; DataSize: LongInt);
var
  Buf: PByte;
  Received: LongInt;
begin
  Stream.Size := Stream.Size + DataSize;
  Buf := Stream.Memory;
  Inc(Buf, Stream.Position);
  Received := ReceiveFrom(aSocket, Buf, DataSize);
  Stream.Size := Stream.Size - DataSize + Received;
end;

procedure TCustomFasterSocket.SendBufferTo(Const aSocket: TCustomFasterSocket; Buffer: Pointer; BufLength: LongInt);
var p: TStreamSize;
begin
  If BufLength <> 0 then begin
    p := aSocket.SendMS.Position;
    aSocket.SendMS.Position := aSocket.SendMS.Size;
    aSocket.SendMS.Write(Buffer^, BufLength);
    aSocket.SendMS.Position := p;
    aSocket.FlushSendBuffer(nil);
  end;
end;

procedure TCustomFasterSocket.SendPacketTo(aSocket: TCustomFasterSocket; Packet: TFasterPacket);
Var
  SendDataSize: LongInt;
  p: TStreamSize;
begin
  SendDataSize := Packet.Size - HEADER_SIZE;

  p := aSocket.SendMS.Position;
  aSocket.SendMS.Position := aSocket.SendMS.Size;
  aSocket.SendMS.Write(Packet.Size, HEADER_SIZE_OF_SIZE);
  aSocket.SendMS.Write(Packet.Command, HEADER_SIZE_OF_COMMAND);
  If SendDataSize > 0 then
    aSocket.SendMS.Write(Packet.Data^, SendDataSize);
  aSocket.SendMS.Position := p;
  aSocket.FlushSendBuffer(nil);
end;

procedure  TCustomFasterSocket.SendStreamTo(Const aSocket: TCustomFasterSocket; Stream: TStream; Size: LongInt);
var
  TempHeaderData: TStreamSize;
  p: TStreamSize;
begin
  If aSocket.FSocket <> INVALID_SOCKET then
   begin

    If Stream = nil then Exit;

    Try
    {$WARNINGS OFF}
      If Stream.Size - Stream.Position < Size then
        Size := Stream.Size - Stream.Position;
    {$WARNINGS ON}
    Except Raise Exception.Create('Error, invalid stream while trying to send!'); end;
    If Size <= 0 then
      Raise Exception.Create('Error while sending stream! Stream position is in the end of the stream!');

    Try
      p := aSocket.SendMS.Position;
      aSocket.SendMS.Position := aSocket.SendMS.Size;
      TempHeaderData := Size + HEADER_SIZE;
      aSocket.SendMS.Write(TempHeaderData, HEADER_SIZE_OF_SIZE);
      TempHeaderData := STREAM_Packet_ID;
      aSocket.SendMS.Write(TempHeaderData, HEADER_SIZE_OF_COMMAND);
      aSocket.SendMS.CopyFrom(Stream,Size);
      aSocket.SendMS.Position := p;
      aSocket.FlushSendBuffer(nil);
    finally end;
  end;
end;

procedure TCustomFasterSocket.SocketError(aSocket: TSocket; ErrorCode: LongInt);
var
  ErrorMsg: String;
begin
  case ErrorCode of
    WSAEACCES: ErrorMsg := 'Permission denied';
    WSAEADDRINUSE: ErrorMsg := 'Address already in use';
    WSAEADDRNOTAVAIL: ErrorMsg := 'Can''t assign requested address';
    WSAEAFNOSUPPORT: ErrorMsg := 'Address family not supported by protocol family';
    WSAEALREADY: ErrorMsg := 'Operation already in progress';
    WSAEBADF: ErrorMsg := 'Bad file number';
    WSAECONNABORTED: ErrorMsg := 'Software caused connection abort';
    WSAECONNREFUSED: ErrorMsg := 'Connection refused';
    WSAECONNRESET: ErrorMsg := 'Connection reset by peer';
    WSAEDESTADDRREQ: ErrorMsg := 'Destination address required';
    WSAEDQUOT: ErrorMsg := 'Disk quota exceeded';
    WSAEFAULT: ErrorMsg := 'Bad address';
    WSAEHOSTDOWN: ErrorMsg := 'Host is down';
    WSAEHOSTUNREACH: ErrorMsg := 'No route to host';
    WSAEINPROGRESS: ErrorMsg := 'Operation now in progress';
    WSAEINTR: ErrorMsg := 'Interrupted system call';
    WSAEINVAL: ErrorMsg := 'Invalid argument';
    WSAEISCONN: ErrorMsg := 'Socket is already connected';
    WSAELOOP: ErrorMsg := 'Too many levels of symbolic links';
    WSAEMFILE: ErrorMsg := 'Too many open files';
    WSAEMSGSIZE: ErrorMsg := 'Message too long';
    WSAENAMETOOLONG: ErrorMsg := 'File name too long';
    WSAENETDOWN: ErrorMsg := 'Network is down';
    WSAENETRESET: ErrorMsg := 'Network dropped connection on reset';
    WSAENETUNREACH: ErrorMsg := 'Network is unreachable';
    WSAENOBUFS: ErrorMsg := 'No buffer space available';
    WSAENOPROTOOPT: ErrorMsg := 'Protocol not available';
    WSAENOTCONN: ErrorMsg := 'Socket is not connected';
    WSAENOTEMPTY: ErrorMsg := 'Directory not empty';
    WSAENOTSOCK: ErrorMsg := 'Socket operation on non-socket';
    WSAEOPNOTSUPP: ErrorMsg := 'Operation not supported on socket';
    WSAEPFNOSUPPORT: ErrorMsg := 'Protocol family not supported';
    WSAEPROCLIM: ErrorMsg := 'Too many processes';
    WSAEPROTONOSUPPORT: ErrorMsg := 'Protocol not supported';
    WSAEPROTOTYPE: ErrorMsg := 'Protocol wrong type for socket';
    WSAEREMOTE: ErrorMsg := 'Too many levels of remote in path';
    WSAESHUTDOWN: ErrorMsg := 'Can''t send after socket shutdown';
    WSAESOCKTNOSUPPORT: ErrorMsg := 'Socket type not supported';
    WSAESTALE: ErrorMsg := 'Stale NFS file handle';
    WSAETIMEDOUT: ErrorMsg := 'Connection timed out';
    WSAETOOMANYREFS: ErrorMsg := 'Too many references: can''t splice';
    WSAEUSERS: ErrorMsg := 'Too many users';
    WSAEWOULDBLOCK: ErrorMsg := 'Operation would block';
    WSAHOST_NOT_FOUND: ErrorMsg := 'Host not found';
    WSANO_DATA: ErrorMsg := 'No Data';
    WSANO_RECOVERY: ErrorMsg := 'Non-recoverable error';
    WSANOTINITIALISED: ErrorMsg := 'WinSock not initialized';
    WSASYSNOTREADY: ErrorMsg := 'Network sub-system is unusable';
    WSATRY_AGAIN: ErrorMsg := 'Non-authoritative host not found';
    WSAVERNOTSUPPORTED: ErrorMsg := 'WinSock DLL cannot support this application';
    else ErrorMsg := 'Unkown error was encountered!';
  end;

  If Assigned(FOnError) then
    FOnError(Self, aSocket, ErrorCode, ErrorMsg)
  else
  if (self is TFasterTCPServerClient) AND
    (Assigned(TFasterTCPServerClient(Owner).OnError)) then
    TFasterTCPServerClient(Owner).OnError(Self, aSocket, ErrorCode, ErrorMsg)
  else
    raise Exception.Create(ErrorMsg);
end;
                
procedure TCustomFasterSocket.ProcessTCPSelect(var Msg: TMessage);
var
  CSocket: TCustomFasterSocket;
  SelectEvent, I: LongInt;
  PacketData: TMemoryStream;

  DataAvail: LongInt; //data size
  HeaderInfo: TFasterHeader;
  ReceiveBuffer: TMemoryStream;
  StreamPos: TStreamSize;
begin
  {$IFDEF DEBUGMODEON}
    DebugInfo.Add('Processing TCPSelect.');
  {$ENDIF}
  I := WSAGetSelectError(Msg.LParam);
  If I > WSABASEERR then
    SocketError(Msg.wParam, I)
  else
   begin
    SelectEvent := WSAGetSelectEvent(Msg.lParam);
    case SelectEvent of
      FD_READ: begin  { check whether data available }
        If IoctlSocket(Msg.wParam, FIONREAD, DataAvail) = SOCKET_ERROR then begin
          SocketError(Msg.wParam, WSAGetLastError);
          Exit;
        end;
        if DataAvail=0 then Exit;

        {Will pick right buffer where to write the data. There is one buffer for each client.}

        CSocket := Self;
        { If this is the server }
        If Assigned(FConnections) then begin
          for I := 0 to FConnections.Count - 1 do begin
            CSocket := TCustomFasterSocket(FConnections.List^[I]);
            If CSocket.FSocket = Msg.wParam then Break; //find the right socket
          end;
          ReceiveBuffer := CSocket.ReceiveMS;
        end else
          ReceiveBuffer := ReceiveMS;

        PacketData := TMemoryStream.Create;
        try
          {$IFDEF DEBUGMODEON}
            DebugInfo.Add('##Starting to receive data, ' + IntToStr(DataAvail) +
              ' bytes available.');
            i := ReceiveBuffer.Size;
          {$ENDIF}
          StreamPos := ReceiveBuffer.Position;
          ReceiveStreamFrom(CSocket.FSocket, ReceiveBuffer, DataAvail);
          if(ProcessingCommands) then
            ReceiveBuffer.Position := StreamPos
          else
            ReceiveBuffer.Position := 0;
          {$IFDEF DEBUGMODEON}
            DebugInfo.Add('##Received ' + IntToStr(ReceiveBuffer.Size-i) +
              ' bytes of ' + IntToStr(DataAvail) + ' available.');
          {$ENDIF}

          Repeat //Split packets from datastream
            HeaderInfo := PacketStreamToPacket( ReceiveBuffer, PacketData );
            If HeaderInfo.Size > 0 then begin
              ProcessingCommands := true;
              If Assigned(FConnections) then
                ProcessCommands(TFasterTCPServerClient(CSocket), PacketData, HeaderInfo.Command) else
                ProcessCommands(nil, PacketData, HeaderInfo.Command);
              end;
          Until HeaderInfo.Size = 0;

          { If the stream was partially received, the rest will be received next time here. }

          {$IFDEF DEBUGMODEON}
            DebugInfo.Add('##Packetsplitting and command processing complete, ' +
              IntToStr(PacketData.Size) + ' bytes left in the receiving buffer.');
          {$ENDIF}
          ReceiveBuffer.Clear;
          ReceiveBuffer.CopyFrom(PacketData, PacketData.Size);
          PacketData.Free;
          ProcessingCommands := false;
        except
          PacketData.Free;
        end;
      end;
      FD_CLOSE: DoClose(Msg.wParam);
      FD_ACCEPT: DoAccept;
      FD_CONNECT: DoConnect;
      {$IFDEF DEBUGMODEON}
      else
         DebugInfo.Add('##TCPSelect Unhandled.');
      {$ENDIF}
     end;
   end;
end;

procedure TCustomFasterSocket.WndProc(var Message: TMessage);
begin
  with Message do
   try
     If Msg = WM_QUERYENDSESSION then
       Result := 1 // Correct shutdown
     else
       Dispatch(Msg);
   except
     Application.HandleException(Self);
   end;
end;           







{-------------------------------------------------------------------------------------------}






{ TFasterTCPServer }
constructor TFasterTCPServer.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FConnections := TList.Create;
  FPingInterval := 1000;
  FPingTimer := TTimer.Create(Self);
  FPingTimer.Enabled := false;
  FPingTimer.OnTimer := {$IFDEF FPC}@{$ENDIF}ServerDoPingUpdate;
  FPingTimer.Interval := FPingInterval;
end;

destructor TFasterTCPServer.Destroy;
begin
  Listen := False;  // cancel listening
  FConnections.Free;
  FPingTimer.Free;
  inherited Destroy;
end;

Procedure TFasterTCPServer.AskMoreData(Client: TFasterTCPServerClient);
begin
  SendCommand(Client,ASK_MORE_DATA_ID,0,nil);
end;

procedure  TFasterTCPServer.AskToReceiveStream(Client: TFasterTCPServerClient; Const DataSize: TStreamSize;
                                                Const DataInfo: String);
Var
  TempStream: TMemoryStream;
  a: LongInt;
begin
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Asking client to prepare for receiving a stream.');
  {$ENDIF}
  TempStream := TMemoryStream.Create;
  Try
    TempStream.Write{Integer}(DataSize, StreamSize_of_Size);
    a := Length(DataInfo);
    If a > 0 then
      TempStream.Write(DataInfo[1],a * SizeOf(Char));
    SendCommand(Client,ASKING_TO_RECEIVE_DATA_ID,TempStream.Size,TempStream.Memory);
  Finally TempStream.Free; end;
end;

procedure TFasterTCPServer.Broadcast(Buffer: PChar; BufLength: LongInt);
var
  I: LongInt;
  BufSize: LongInt;
  TempBuf: Pointer;
  PositionPointer: PByte;
begin
  If BufLength = 0 then Exit;
  BufSize := HEADER_SIZE + (BufLength * SizeOf(Char));
  GetMem(TempBuf,BufSize);
  Try
    System.Move( BufSize, TempBuf^, HEADER_SIZE_OF_SIZE ); //Write size
    PositionPointer := TempBuf;
    Inc( PositionPointer, HEADER_SIZE_OF_SIZE );
    BufSize := MESSAGE_Packet_ID;
    System.Move( BufSize, PositionPointer^, HEADER_SIZE_OF_COMMAND ); //Write ID
    Inc( PositionPointer, HEADER_SIZE_OF_COMMAND );
    System.Move( Buffer^, PositionPointer^, BufLength * SizeOf(Char) ); //Write data
  Except
    FreeMem(TempBuf);
  end;
  Try
    BufSize := HEADER_SIZE + (BufLength * SizeOf(Char));
    For I := FConnections.Count - 1 downto 0 do
      SendBufferTo(TFasterTCPServerClient(FConnections.List^[I]),TempBuf,BufSize);
  Finally
    FreeMem(TempBuf);
  end;
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Broadcasting message: ' + String(Buffer));
  {$ENDIF}
end;

procedure TFasterTCPServer.BroadcastStream(Stream: TStream; SendSize: LongInt);
var
  I: LongInt;
  BufSize: LongInt;
  TempBuf: Pointer;  //There is no need to create a new packet for every client,
                    //instead we use buffer to send data.
  PositionPointer: PByte;
begin
  If SendSize = 0 then Exit;

  BufSize := HEADER_SIZE + SendSize;
  GetMem(TempBuf,BufSize);
  Try                   //Creating packet manually
    System.Move( BufSize, TempBuf^, HEADER_SIZE_OF_SIZE ); //Write size
    PositionPointer := TempBuf;
    Inc(PositionPointer, HEADER_SIZE_OF_SIZE);
    BufSize := BroadCast_STREAM_Packet_ID;
    System.Move( BufSize, PositionPointer^, HEADER_SIZE_OF_COMMAND ); //Write ID
    Inc( PositionPointer, HEADER_SIZE_OF_COMMAND );
    Stream.Read( PositionPointer^, SendSize ); //Write data
  Except
    FreeMem(TempBuf);
  end;
  Try       
    BufSize := HEADER_SIZE + SendSize;
    For I := FConnections.Count - 1 downto 0 do
      SendBufferTo(TFasterTCPServerClient(FConnections.List^[I]),TempBuf,BufSize);
  Finally
    FreeMem(TempBuf);
  end;
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Broadcasting stream, size: ' + IntToStr(SendSize));
  {$ENDIF}
end;

procedure TFasterTCPServer.DisconnectAClient(Client:TFasterTCPServerClient);
begin
  SendCommand(Client,SERVER_DISCONNECT_YOU_ID,0,nil);
end;

procedure TFasterTCPServer.DisconnectEveryone;
Var
  I: LongInt;
begin
   For I := FConnections.Count - 1 downto 0 do
    SendCommand(TFasterTCPServerClient(FConnections.List^[I]),SERVER_DISCONNECT_YOU_ID,0,nil);
end;
            
procedure TFasterTCPServer.DoAccept;
var
  Tmp: LongInt;
  tmpSocket: TSocket;
  tmpTCPClient: TFasterTCPServerClient;
  IsAccept: Boolean;
begin
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Client is connecting.');
  {$ENDIF}
  Tmp := SizeOf(SockAddrIn);
  {$IFNDEF D3}
  tmpSocket := WinSock.Accept(FSocket, SockAddrIn, Tmp);
  {$ELSE}
  tmpSocket := WinSock.Accept(FSocket, @SockAddrIn, @Tmp);
  {$ENDIF}
  If tmpSocket = INVALID_SOCKET then
    SocketError(tmpSocket, WSAGetLastError);

{$WARNINGS OFF}
  tmpTCPClient := TFasterTCPServerClient.Create(self);
{$WARNINGS ON}

  tmpTCPClient.FSocket := tmpSocket;
  tmpTCPClient.FHost := inet_ntoa(SockAddrIn.SIn_Addr);
  tmpTCPClient.FPort := FPort;
  tmpTCPClient.FConnected := True;

  IsAccept := True; //Accept is true by default
  If Assigned(FOnAccept) then
   begin
    FOnAccept(Self, tmpTCPClient, IsAccept);
    If IsAccept then
      FConnections.Add(tmpTCPClient)
    else
      tmpTCPClient.Free;
   end
  else
   FConnections.Add(tmpTCPClient);

  If IsAccept then begin
    SendCommand(tmpTCPClient,SERVER_ASK_REGISTER_NAME_ROOM_ID,0,nil);

    If Assigned(FOnClientConnected) then
      FOnClientConnected(Self, tmpTCPClient);
  end;
end;
          
procedure TFasterTCPServer.DoClose(aSocket: TSocket);
var
  I: LongInt;
  len: Integer;
  tmpTCPClient: TFasterTCPServerClient;
begin
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Client disconnected.');
  {$ENDIF}
  tmpTCPClient := nil;
   for I := FConnections.Count - 1 downto 0 do
    begin
     tmpTCPClient := TFasterTCPServerClient(FConnections.List^[I]);
     If tmpTCPClient.FSocket = aSocket then
      begin
       FConnections.Delete(I);
       Break;
      end;
    end;

  If Assigned(tmpTCPClient) then
   begin
    If Assigned(FOnClientDisconnected) and not (csDestroying in ComponentState) then
      FOnClientDisconnected(Self, tmpTCPClient);

    case ClientStatusUpdate of
	    Rooms: begin
        len := Length(tmpTCPClient.FUserName);
		    for i := 0 to Clients.Count-1 do
			    if( TFasterTCPServerClient(FConnections.List^[I]).Room = tmpTCPClient.Room) then
				    SendCommand( TFasterTCPServerClient(FConnections.List^[I]), CLIENT_LEAVE_ID,
				    len * SizeOf(Char), PChar(tmpTCPClient.FUserName) );
      end;
	    AllClients: begin
        len := Length(tmpTCPClient.FUserName);
		    for i := 0 to Clients.Count-1 do
				  SendCommand( TFasterTCPServerClient(FConnections.List^[I]), CLIENT_LEAVE_ID,
				  len * SizeOf(Char), PChar(tmpTCPClient.FUserName) );
      end;
    end;

    tmpTCPClient.Free;
   end;
end;    

procedure TFasterTCPServer.DoMessageCome(Client: TFasterTCPServerClient; Const ProcessedMessage: String);
begin
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Received message from client (' + Client.UserName + '): ' + ProcessedMessage);
  {$ENDIF}
  If Assigned(FOnClientMessageCome) then
    FOnClientMessageCome(Self, Client, ProcessedMessage);
end;

procedure TFasterTCPServer.DoPacketCome(Client: TFasterTCPServerClient; Data: TMemoryStream; DataSize: LongInt);
begin
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Received packet, size: ' + IntToStr(DataSize));
  {$ENDIF}
  If Assigned(FOnClientPacketCome) then
    FOnClientPacketCome(Self, Client, Data, DataSize);

  If Client.FStreamDataReceived >= Client.FStream_FullSize then begin //completely received
    If Assigned(FOnStreamReceived) then
      FOnStreamReceived(Self, Client, Client.FStreamDataReceived, Client.FStreamDataInfo);
    SendCommand(Client,STREAM_RECEIVED_ID,0,nil);
  end;
end;

procedure TFasterTCPServer.ServerDoPingUpdate(Sender: TObject);
begin
  UpdatePingStatuses;
end;

procedure TFasterTCPServer.FlushSendBuffer(Sender: TObject);
var i: Integer;
begin
  for i := 0 to FConnections.Count-1 do
    TFasterTCPServerClient(FConnections.List^[I]).FlushSendBuffer(nil);
end;

function TFasterTCPServer.GetLocalHostName: AnsiString;
var
  HostName: Array[0..MAX_PATH] of AnsiChar;
begin
  If GetHostName(HostName, MAX_PATH) = 0 then
    Result := HostName
  else
    SocketError(FSocket, WSAGetLastError);
end;
       
function TFasterTCPServer.GetLocalIP: AnsiString;
var
  aSockAddrIn: TSockAddrIn;
  aHostEnt: PHostEnt;
  HostName: Array[0..MAX_PATH] of AnsiChar;
begin
  If GetHostName(HostName, MAX_PATH) = 0 then
   begin
    aHostEnt := GetHostByName(HostName);
    If aHostEnt = nil then
      Result := ''
    else
     begin
      aSockAddrIn.sin_addr.S_addr := LongInt(PLongInt(aHostEnt^.h_addr_list^)^);
      Result := inet_ntoa(aSockAddrIn.sin_addr);
     end;
   end
  else
   SocketError(FSocket, WSAGetLastError);
end;   

procedure TFasterTCPServer.KickOutAClient(Client: TFasterTCPServerClient);
begin
  SendCommand(Client,SERVER_KICK_OUT_ID,0,nil);
end;

procedure TFasterTCPServer.MakeRoomUserNameList(Const RoomName: String; TheList: TStringList);
Var
  I: LongInt;
  TempClient: TFasterTCPServerClient;
begin
  TheList.Clear;
  For I := 0 to FConnections.Count - 1 do begin
    TempClient := TFasterTCPServerClient(FConnections.List^[I]);
    If TempClient.FRoom = RoomName then
      TheList.Add(TempClient.FUserName);
  end;
end;

procedure TFasterTCPServer.MakeUserNameList(TheList: TStringList);
Var
  I: LongInt;
begin    
  TheList.Clear;
  For I := 0 to FConnections.Count - 1 do
    TheList.Add(TFasterTCPServerClient(FConnections.List^[I]).FUserName);
end;

Procedure TFasterTCPServer.ProcessCommands(Client: TFasterTCPServerClient; Data: TMemoryStream; Command: LongInt);
Var
  AcceptStream: Boolean;
  AlreadyInUse: Boolean;
  DataPointer: PByte;
  DontLetIn_: Boolean;
  I: LongInt;
  len: Integer;
  Reader: TReader;
  TempMessage: String;
  TempSize: TStreamSize;
  TmpUserName: String;
  uList: TStringList;
begin
  Case Command of

    ASK_MORE_DATA_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Client asking more data');
      {$ENDIF}    
      If Assigned(FOnClientNeedMoreData) then
        FOnClientNeedMoreData(Self, Client);
    end;

    ASKING_TO_RECEIVE_DATA_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Client asking to prepare for receiving data.');
      {$ENDIF}
      Data.Read{Integer}(TempSize, StreamSize_of_Size);
      If Data.Size > StreamSize_of_Size then begin
        i := Data.Size - StreamSize_of_Size;
        SetLength(TempMessage,i div SizeOf(Char));
        Data.Read(TempMessage[1],i);
      end;
      AcceptStream := False;
      If Assigned(FOnNewStreamComing) then
        FOnNewStreamComing(Self, Client, TempSize, TempMessage, AcceptStream);
      If AcceptStream then begin //no check for Packetsize
        Client.FStreamDataReceived := 0;
        Client.FStream_FullSize := TempSize;
        Client.FStreamDataInfo := TempMessage;
        SendCommand(Client,DATA_RECEIVE_OK_ID,0,nil);
      end else
       SendCommand(Client,DATA_RECEIVE_DENIED_ID,0,nil);
    end;

    CLIENT_TO_CLIENT_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Forwarding a CLIENT_TO_CLIENT packet.');
      {$ENDIF}
      Data.Read{Integer}(TempSize, SizeOf(LongInt));
      SetLength(TmpUserName, TempSize div SizeOf(Char));
      Data.Read(TmpUserName[1], TempSize);
      DataPointer := Data.Memory;
      Inc(DataPointer, Data.Position);

      For I := 0 to FConnections.Count - 1 do
        If TFasterTCPServerClient(FConnections.List^[I]).FUserName = TmpUserName then begin
          SendCommand(TFasterTCPServerClient(FConnections.List^[I]),CLIENT_TO_CLIENT_ID,
            Data.Size - Data.Position,DataPointer);
          Break;
        end;
    end;

    DATA_RECEIVE_DENIED_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Client refuses to accept the stream.');
      {$ENDIF}
      If Assigned(FOnClientDenyStream) then
        FOnClientDenyStream(Self, Client);
    end;

    DATA_RECEIVE_OK_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Client is ready to receive the stream.');
      {$ENDIF}
      If Assigned(FOnClientAcceptStream) then
        FOnClientAcceptStream(Self, Client);   
    end;

    DATA_RECEIVING_STOPPED_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Client stopped receiving the stream.');
      {$ENDIF}
      If Assigned(FOnClientStopReceivingStream) then
        FOnClientStopReceivingStream(Self, Client);  
    end;

    DATA_SENDING_STOPPED_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Client stopped sending the stream.');
      {$ENDIF}
      If Assigned(FOnClientStopSendingStream) then
        FOnClientStopSendingStream(Self, Client);  
    end;

    MESSAGE_Packet_ID: begin
      //Debugging handled in DoMessageCome
      DoMessageCome(Client, ConvertToString(Data));
    end;

    PING_ID: SendCommand(Client, PONG_ID, 0, nil);

    PONG_ID: begin
      Client.FPingStatus := PingOK;
      Client.FTimeOuts := 0;
      If Assigned(FOnClientPong) then
        FOnClientPong( Self, Client );
    end;

    REGISTER_NAME_ROOM_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Registering name and room for client.');
      {$ENDIF}
      AlreadyInUse := False;
      Reader := TReader.Create(Data,4096);
      Try
        TmpUserName := Reader.ReadString;
        TempMessage := Reader.ReadString;
      Finally Reader.Free; end;
      If not AllowSameUserNames then
        For I := 0 to FConnections.Count - 1 do
          If TFasterTCPServerClient(FConnections.List^[I]).FUserName = TmpUserName then begin
            AlreadyInUse := True;
            Break;
          end;                      // this should be the 2nd message sent by server
      If not AlreadyInUse then begin
        Client.FUserName := TmpUserName;
        Client.FRoom := TempMessage;
        DontLetIn_ := False;
        If Assigned(FOnServerGetUserName) then
          FOnServerGetUserName(Self, Client, DontLetIn_, PChar(TempMessage), PChar(TmpUserName));
        If DontLetIn_ then
          SendCommand(Client,SERVER_NOT_LET_IN_ID,0,nil)
        else begin
          SendCommand(Client,SERVER_REGISTER_OK_ID,0,nil);
          uList := TStringList.Create;

          case ClientStatusUpdate of
	          Rooms: begin
		           MakeRoomUserNameList( Client.Room, uList );
		           SendCommand( Client, NAMELIST_ID, Length(uList.Text), PChar(uList.Text) );
               len := Length(Client.FUserName);
		           for i := 0 to Clients.Count-1 do
			           if( (TFasterTCPServerClient(FConnections.List^[I]).FRoom = Client.FRoom) and
                   (TFasterTCPServerClient(FConnections.List^[I]).FSocket <> Client.FSocket) ) then
				            SendCommand( TFasterTCPServerClient(FConnections.List^[I]), CLIENT_JOIN_ID,
				            len * SizeOf(Char), PChar(Client.FUserName) );
            end;

	          AllClients: begin
		          MakeUserNameList( uList );
		          SendCommand( Client, NAMELIST_ID, Length(uList.Text), PChar(uList.Text) );
              len := Length(Client.FUserName);
		          for i := 0 to Clients.Count-1 do
		          	if(TFasterTCPServerClient(FConnections.List^[I]).FSocket <> Client.FSocket) then
			          	SendCommand( TFasterTCPServerClient(FConnections.List^[I]), CLIENT_JOIN_ID,
			          	len * SizeOf(Char), PChar(Client.FUserName) );
            end;
          end;

          uList.Free;
        end; 
      end else
       SendCommand(Client,SERVER_NAME_IN_USE_ID,0,nil);
    end;

    STREAM_Packet_ID: begin      
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Part of stream received from client.');
      {$ENDIF}
      Inc(Client.FStreamDataReceived,Data.Size);
      DoPacketCome(Client,Data, Data.Size);
    end;

    STREAM_RECEIVED_ID: begin
      If Assigned(FOnClientReceivedStream) then
        FOnClientReceivedStream(Self, Client);
    end;
    
    else begin //unknownID
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Received packet from a client with an unknown header: '+InttoStr(Command));
      {$ENDIF}
      If Assigned(FOnUnknownPacketID) then
        FOnUnknownPacketID(Self, Client, Data, Command);
    end;
  end; //~CASE END
end;

Procedure TFasterTCPServer.Send(Client: TFasterTCPServerClient; Buffer: PChar; BufLength: LongInt);
begin
  If BufLength = 0 then
    Exit;
    SendPacketTo(Client,CreatePacket(BufLength * SizeOf(Char),MESSAGE_Packet_ID,Buffer));
    {$IFDEF DEBUGMODEON}
      FDebugInfo.Add('Message sent to client: ' + String(Buffer));
    {$ENDIF}
end;

Procedure TFasterTCPServer.SendCommand(Client: TFasterTCPServerClient; Command, CommandDataSize: LongInt; Data: Pointer);
begin
  if Data <> nil then
    SendPacketTo(Client, CreatePacket(CommandDataSize,Command,Data)) else
  SendPacketTo(Client, CreatePacket(0,Command,nil));

  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Command sent :' + IntToStr(Command));
  {$ENDIF}
end;

Procedure TFasterTCPServer.SendCustomPacket(Client: TFasterTCPServerClient; ID, DataSize: LongInt; Data: TStream);
Var TempData: Pointer;
  TempPacket: TFasterPacket;
begin   
  TempData := nil;
  If DataSize > 0 then begin
      GetMem(TempData,DataSize);
      Try
        Data.Read(TempData^,DataSize);
        TempPacket := CreatePacket(DataSize,ID,TempData);
      Except
       FreeMem(TempData);
      end;
  end else
    TempPacket := CreatePacket(0,ID,nil);

  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Custom packet sent, ID:' + IntToStr(ID));
  {$ENDIF}
  SendPacketTo(Client,TempPacket);
  if TempData <> nil then
    FreeMem(TempData);
end;

Procedure TFasterTCPServer.SendCustomPacketEx(Client: TFasterTCPServerClient; ID, DataSize: LongInt; Data: Pointer);
Var TempPacket: TFasterPacket;
begin
  If DataSize > 0 then begin
    Try
      TempPacket := CreatePacket(DataSize,ID,Data);
    Except
    end;
  end else
    TempPacket := CreatePacket(0,ID,nil);

  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Custom packet sent, ID:' + IntToStr(ID));
  {$ENDIF}
  SendPacketTo(Client,TempPacket);
end;

Procedure TFasterTCPServer.SendStream(Client: TFasterTCPServerClient; Stream: TStream; Size: LongInt);
begin
  SendStreamTo(Client, Stream, Size);
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Stream sending started, size: ' + IntToStr(Size));
  {$ENDIF}
end;

procedure TFasterTCPServer.SetListen(Value: Boolean);
var
  I: LongInt;
  tmpTCPClient: TFasterTCPServerClient;
begin
  If not (csDesigning in ComponentState) then
   If FListen <> Value then
    begin
    {$IFDEF DEBUGMODEON}
      If Value then
        FDebugInfo.Add('Server starts listening') else
        FDebugInfo.Add('Server stops listening');
    {$ENDIF}
     If Value then
      begin
       FSocket := WinSock.Socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
       If FSocket = INVALID_SOCKET then
        begin
         SocketError(INVALID_SOCKET, WSAGetLastError);
         Exit;
        end;

       SockAddrIn.sin_family := AF_INET;
       SockAddrIn.sin_addr.s_addr := INADDR_ANY;
       SockAddrIn.sin_port := htons(FPort);
       If Bind(FSocket, SockAddrIn, SizeOf(SockAddrIn)) <> 0 then
        begin
         SocketError(FSocket, WSAGetLastError);
         Exit;
        end;

       If WinSock.Listen(FSocket, SOMAXCONN) <> 0 then
        begin
         SocketError(FSocket, WSAGetLastError);
         Exit;
        end;

       If WSAAsyncSelect(FSocket, WindowHandle, SYNCSELECT_ID,
                         FD_READ or FD_ACCEPT or FD_CLOSE) <> 0 then
        begin
         SocketError(FSocket, WSAGetLastError);
         Exit;
        end;

        FPingTimer.Enabled := true;
      end
     else
      begin
        FPingTimer.Enabled := false;
       // Closing all connections first
       //if I <> 0 then
        for I := FConnections.Count - 1 downto 0 do
         begin
          tmpTCPClient := TFasterTCPServerClient(FConnections.List^[I]);
          tmpTCPClient.Connected := False;
          tmpTCPClient.Free;
          FConnections.Delete(I);
         end;

       // Cancel listening
       WSAASyncSelect(FSocket, WindowHandle, SYNCSELECT_ID, 0);
       Shutdown(FSocket, 2);

       If CloseSocket(FSocket) <> 0 then
        begin
         SocketError(FSocket, WSAGetLastError);
         Exit;
        end;

       FSocket := INVALID_SOCKET;
      end;
      FListen := Value;
    end
   else
  else
   FListen := Value;
end;

procedure TFasterTCPServer.SetMaxPingInterval(Value: Cardinal);
begin
  FPingInterval := Value;
  FPingTimer.Interval := Value;
end;

procedure TFasterTCPServer.SetNoneStr(Value: AnsiString); begin end;

procedure TFasterTCPServer.SetPort(Value: Word);
begin
  If not (csDesigning in ComponentState) then
   If FPort <> Value then
    If FListen then
     If FAllowChangeHostAndPortOnConnection then
      begin
       Listen := False;
       FPort := Value;
       Listen := True;
      end
     else
      raise Exception.Create('Can not change Port while listening')
    else FPort := Value
   else
  else FPort := Value;
end;  

procedure TFasterTCPServer.SocketError(aSocket: TSocket; ErrorCode: LongInt);
begin
  if(ErrorCode <> WSAEWOULDBLOCK) then
    Listen := false;  // cancel listening
  inherited;
end;

procedure TFasterTCPServer.StopReceivingData(Client: TFasterTCPServerClient);
begin
  SendCommand(Client,DATA_RECEIVING_STOPPED_ID,0,nil);
end;

procedure TFasterTCPServer.StopSendingData(Client: TFasterTCPServerClient);
begin
  SendCommand(Client,DATA_SENDING_STOPPED_ID,0,nil);
end;

procedure TFasterTCPServer.UpdatePingStatuses;
var
  tmpTCPClient: TFasterTCPServerClient;
  I: LongInt;
  FForceClientDisconnect: Boolean;
begin
  For I := FConnections.Count - 1 downto 0 do begin
    tmpTCPClient := TFasterTCPServerClient(FConnections.List^[I]);
    SendCommand(tmpTCPClient, PING_ID, 0, nil);
    Case tmpTCPClient.FPingStatus of
     PingOK: tmpTCPClient.FPingStatus := WaitingPing;
     WaitingPing: begin
       Inc(tmpTCPClient.FTimeOuts);
       FForceClientDisconnect := False;
       If Assigned(FOnClientTimeOut) then
         FOnClientTimeOut(Self,tmpTCPClient,FForceClientDisconnect);
       If FForceClientDisconnect then begin
         tmpTCPClient.Connected := False;
         tmpTCPClient.Free;
         FConnections.Delete(I);
       end;
     end;
    End;
  end;
end;
{-------------------------------------------------------------------------------------------}














{ TFasterTCPServerClient }
constructor TFasterTCPServerClient.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FPingStatus := PingOK;
  FTimeOuts := 0;
  FlushTimer := TTimer.Create(Self);
  FlushTimer.OnTimer := {$IFDEF FPC}@{$ENDIF}FlushSendBuffer;
  FlushTimer.Interval := FLUSH_INTERVAL;
end;

destructor TFasterTCPServerClient.Destroy;
begin
  Connected := False;
  FExtraDataObject.Free;
  FlushTimer.Enabled := false;
  FlushTimer.Free;
  inherited Destroy;
end;

procedure TFasterTCPServerClient.ClearStreamProperties;
begin
  FStreamDataReceived := 0;
  FStream_FullSize := 0;
  FStreamDataInfo := '';
end;

procedure TFasterTCPServerClient.FlushSendBuffer(Sender: TObject);
var
  p: PByte;
  sendSize: LongInt;
  sent: Integer;
  newStream: TMemoryStream;
begin
  FlushTimer.Enabled := false;
  sendSize := SendMS.Size - SendMS.Position;
  if (sendSize = 0) or (Socket = INVALID_SOCKET) then Exit;

  p := SendMS.Memory;
  Inc(p, SendMS.Position);
  sent := WinSock.Send(Socket, p^, sendSize, 0);
  If sent = SOCKET_ERROR then begin
    SocketError(Socket, WSAGetLastError);
    if(WSAGetLastError = WSAEWOULDBLOCK) then
      FlushTimer.Enabled := true;
  end else
  begin
    SendMS.Position := SendMS.Position + sent;
    if SendMS.Position = SendMS.Size then
      SendMS.Clear;
    if SendMS.Size > SEND_BUFFER_SIZE then begin
      newStream := TMemoryStream.Create;
      newStream.CopyFrom(SendMS, SendMS.Size - SendMS.Position);
      newStream.Position := 0;
      SendMS.Free;
      SendMS := newStream;
    end;
    if SendMS.Size > 0 then
      FlushTimer.Enabled := true;
  end;
end;

procedure TFasterTCPServerClient.SetConnected(Value: Boolean);
var
  lin: TLinger;
  linx: Array[0..3] of AnsiChar absolute lin;
begin
   If FConnected <> Value then
    begin
    {$IFDEF DEBUGMODEON}
      If Value then
        FDebugInfo.Add('Server creating socket for a client') else
        FDebugInfo.Add('Server closing a client socket');
    {$ENDIF}
     ClearStreamProperties;
     If Value then
      begin
       SockAddrIn.sin_family := AF_INET;
       SockAddrIn.sin_port := htons(FPort);
       SockAddrIn.sin_addr.s_addr := inet_addr(PAnsiChar(Host));
       If (SockAddrIn.sin_addr.s_addr = INADDR_NONE) OR
       (SockAddrIn.sin_addr.s_addr = INADDR_ANY) then
        begin
         HostEnt := GetHostByName(PAnsiChar(Host));
         If HostEnt = nil then
          begin
           SocketError(INVALID_SOCKET, WSAEFAULT);
           Exit;
          end;
         SockAddrIn.sin_addr.S_addr := LongInt(PLongInt(HostEnt^.h_addr_list^)^);
        end;

       FSocket := WinSock.Socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
       If FSocket = INVALID_SOCKET then begin
         SocketError(INVALID_SOCKET, WSAGetLastError);
         Exit;
       end;

       If WSAASyncSelect(FSocket, WindowHandle, SYNCSELECT_ID,
                         FD_READ or FD_CONNECT or FD_CLOSE) <> 0 then
        begin
         SocketError(FSocket, WSAGetLastError);
         Exit;
        end;

      If (WinSock.Connect(FSocket, SockAddrIn, SizeOf(SockAddrIn)) <> 0) and
         (WSAGetLastError <> WSAEWOULDBLOCK) then
       begin
         SocketError(FSocket, WSAGetLastError);
         Exit;
      end;
      FConnected := Value;
      end
     else
      begin
       WSAASyncSelect(FSocket, WindowHandle, SYNCSELECT_ID, 0);
       Shutdown(FSocket, 2);
       lin.l_onoff := 1;
       lin.l_linger := 0;
       SetSockOpt(FSocket, SOL_SOCKET, SO_LINGER, linx, SizeOf(Lin));

       If CloseSocket(FSocket) <> 0 then begin
         SocketError(FSocket, WSAGetLastError);
         Exit;
       end;

       FSocket := INVALID_SOCKET;
       FConnected := False;
      end;
    end;
end;   
{------------------------------------------------------------}












constructor TFasterTCPClient.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FPingInterval := 1000;
  FPingTimer := TTimer.Create(Self);
  FPingTimer.OnTimer := {$IFDEF FPC}@{$ENDIF}ClientDoPingUpdate;
  FPingTimer.Interval := FPingInterval; 
  FPingTimer.Enabled := false;
end;

destructor TFasterTCPClient.Destroy;
begin
  FPingTimer.Free;
  inherited Destroy;
end;

{ TFasterTCPClient }

{procedure TFasterTCPClient.WndProc(var Message: TMessage);
begin
  inherited WndProc(Message);
end;}

Procedure TFasterTCPClient.AskMoreData;
begin
  SendCommand(ASK_MORE_DATA_ID,0,nil);
end;

procedure TFasterTCPClient.AskToReceiveStream(Const DataSize: TStreamSize; Const DataInfo: String);
Var
  TempStream: TMemoryStream;
  a: LongInt;
begin
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Asking server to prepare for receiving a stream.');
  {$ENDIF}
  TempStream := TMemoryStream.Create;
  Try
    TempStream.Write{Integer}(DataSize, StreamSize_of_Size);
    a := Length(DataInfo);
    If a > 0 then
      TempStream.Write(DataInfo[1],a * SizeOf(Char));
    SendCommand(ASKING_TO_RECEIVE_DATA_ID,TempStream.Size,TempStream.Memory);
  Finally TempStream.Free; end;
end;

procedure TFasterTCPClient.ClientDoPingUpdate(Sender: TObject);
begin
  UpdatePingStatus;
end;

procedure TFasterTCPClient.DoClose(aSocket: TSocket);
begin
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Client closing down.');
  {$ENDIF}
  Connected := False;
  ReceiveMS.Clear;
  SendMS.Clear;
  If not (csDestroying in ComponentState) then
   begin
    If Assigned(FOnDisconnected) then
      FOnDisconnected(Self);

    If FAutoTryReconnect then
      Connected := True;
   end;   
end;

procedure TFasterTCPClient.DoConnect;
begin
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Client established a connection to the server.');
  {$ENDIF}
  FConnected := True;
  If Assigned(FOnConnected) then
     FOnConnected(Self);
end;

procedure TFasterTCPClient.DoMessageCome(ProcessedMessage: String);
begin
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Received a message from the server :' + ProcessedMessage);
  {$ENDIF}
  If Assigned(FOnMessageCome) then
    FOnMessageCome(Self, ProcessedMessage);
end;

procedure TFasterTCPClient.DoPacketCome(Data: TMemoryStream; DataSize: LongInt);
begin
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Received a packet, size: ' + IntToStr(DataSize));
  {$ENDIF}
  If Assigned(FOnPacketCome) then
    FOnPacketCome(Self, Data, DataSize);

  If FStreamDataReceived >= FStream_FullSize then begin
    If Assigned(FOnStreamReceived) then
      FOnStreamReceived(Self, FStreamDataReceived, FStreamDataInfo);
    SendCommand(STREAM_RECEIVED_ID,0,nil);
  end;
end;

function  TFasterTCPClient.GetIP: LongInt;
begin
  Result := StrToIP(PAnsiChar(Host));
end;

procedure TFasterTCPClient.SetIP(Value: LongInt);
begin
  Host := IPToStr(Value);
end;

procedure TFasterTCPClient.ProcessCommands(Client: TFasterTCPServerClient; Data: TMemoryStream; Command: LongInt);
Var
  AcceptStream: Boolean;
  i: Integer;
  Writer: TWriter;
  TempDataInfo: String;
  TempSize: TStreamSize;
  TempStream: TMemoryStream;
  TmpStringList: TStringList;
begin
  Case Command of

    ASK_MORE_DATA_ID: begin 
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Server asking for more data');
      {$ENDIF}
      If Assigned(FOnServerNeedMoreData) then
        FOnServerNeedMoreData(Self);
    end;

    ASKING_TO_RECEIVE_DATA_ID: begin 
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Server asking to prepare for receiving data.');
      {$ENDIF}
      Data.Read{Integer}(TempSize, StreamSize_of_Size);
      If Data.Size > StreamSize_of_Size then begin
        i := Data.Size - StreamSize_of_Size;
        SetLength(TempDataInfo,i div SizeOf(Char));
        Data.Read(TempDataInfo[1],i);
      end;
      AcceptStream := False;
      If Assigned(FOnNewStreamComing) then
        FOnNewStreamComing(Self, TempSize,TempDataInfo, AcceptStream);

      If AcceptStream then begin
        FStreamDataReceived := 0;
        FStream_FullSize := TempSize;
        FStreamDataInfo := TempDataInfo;
        SendCommand(DATA_RECEIVE_OK_ID,0,nil);
      end else
        SendCommand(DATA_RECEIVE_DENIED_ID,0,nil);
    end;

    CLIENT_JOIN_ID:
      If Assigned(FOnAClientJoin) then begin
        i := Data.Size;
        SetLength(TempDataInfo,i div SizeOf(Char));
        Data.Read(TempDataInfo[1],i);
        FOnAClientJoin(Self, TempDataInfo);
    end;    

    CLIENT_LEAVE_ID:
      If Assigned(FOnAClientLeave) then begin   
        i := Data.Size;
        SetLength(TempDataInfo,i div SizeOf(Char));
        Data.Read(TempDataInfo[1],i);
        FOnAClientLeave(Self, TempDataInfo);
     end;   

    CLIENT_TO_CLIENT_ID:
      If(Assigned(FOnPacketFromClient)) then begin
        Data.Position := Data.Size - SizeOf(LongInt);
        Data.Read{Integer}(TempSize, SizeOf(LongInt));
        Data.Position := Data.Size - SizeOf(LongInt) - TempSize;
        SetLength(TempDataInfo, TempSize div SizeOf(Char));
        Data.Read(TempDataInfo[1], TempSize);
        Data.Position := 0;
        Data.Size := Data.Size - SizeOf(LongInt) - TempSize;
        FOnPacketFromClient(Self, TempDataInfo, Data);
      end;

    DATA_RECEIVE_DENIED_ID: begin 
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Server refuses to accept the stream.');
      {$ENDIF}
      If Assigned(FOnServerDenyStream) then
        FOnServerDenyStream(Self);
    end;

    DATA_RECEIVE_OK_ID: begin  
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Server is ready to receive the stream.');
      {$ENDIF}
      If Assigned(FOnServerAcceptStream) then
        FOnServerAcceptStream(Self);
    end;

    DATA_RECEIVING_STOPPED_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Server stops receiving the stream.');
      {$ENDIF}
      If Assigned(FOnServerStopReceivingStream) then
        FOnServerStopReceivingStream(Self); 
    end;

    DATA_SENDING_STOPPED_ID: begin  
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Server stops sending the stream.');
      {$ENDIF}
      If Assigned(FOnServerStopSendingStream) then
        FOnServerStopSendingStream(Client);    
    end;

    MESSAGE_Packet_ID: begin
      DoMessageCome(ConvertToString(Data));  
    end;

    NAMELIST_ID:
      If Assigned(FOnNameListReceived) then begin
        SetLength(TempDataInfo, Data.Size div SizeOf(Char));
        Data.Read(TempDataInfo[1], Data.Size);
        TmpStringList := TStringList.Create;
        TmpStringList.Text := TempDataInfo;
        FOnNameListReceived(Self, TmpStringList);
        TmpStringList.Free;
    end;

    PING_ID: SendCommand(PONG_ID, 0, nil);

    PONG_ID: begin
      FPingStatus := PingOK;
      FTimeOuts := 0;
      If Assigned(FOnServerPong) then
        FOnServerPong( Self );
    end;

    SERVER_ASK_REGISTER_NAME_ROOM_ID: begin 
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Sending name and room info for registering.');
      {$ENDIF}
      TempStream := TMemoryStream.Create;
      Try
        Writer := TWriter.Create(TempStream,4096);
        Writer.WriteString(FUserName);
        Writer.WriteString(FRoom);
        Writer.Free;
        SendCommand(REGISTER_NAME_ROOM_ID,TempStream.Size,TempStream.Memory);
      Finally TempStream.Free; end;
    end;

    SERVER_DISCONNECT_ALL_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Server disconnected all clients.');
      {$ENDIF}
      Connected := False;
      If Assigned(FOnServerDisconnectAll) then
        FOnServerDisconnectAll(Self);
    end;

    SERVER_DISCONNECT_YOU_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Server disconnected a client.');
      {$ENDIF}
      Connected := False;
      If Assigned(FOnServerDisconnectYou) then
        FOnServerDisconnectYou(Self);
    end;

    SERVER_KICK_OUT_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Server kicked out a client.');
      {$ENDIF}
      Connected := False;
      If Assigned(FOnServerKickYouOut) then
        FOnServerKickYouOut(Self);
    end;

    SERVER_NAME_IN_USE_ID: begin  
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Name was in use at the server.');
      {$ENDIF}
      Connected := False;
      If Assigned(FOnServerNameInUse) then
        FOnServerNameInUse(Self);
    end;

    SERVER_NOT_LET_IN_ID: begin  
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Server does not accept the client.');
      {$ENDIF}
      Connected := False;
      If Assigned(FOnServerNotLetIn) then
        FOnServerNotLetIn(Self);
    end;

    SERVER_REGISTER_OK_ID: begin  
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Client registered successfully.');
      {$ENDIF}
      If Assigned(FOnServerAccept) then
        FOnServerAccept(Self);
    end;

    STREAM_Packet_ID: begin
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Part of stream received from the server.');
      {$ENDIF}
      Inc(FStreamDataReceived,Data.Size);
      DoPacketCome(Data, Data.Size);
    end;

    STREAM_RECEIVED_ID: begin
      If Assigned(FOnServerReceivedStream) then
        FOnServerReceivedStream(Self);  
    end;

    else begin //unknownID   
      {$IFDEF DEBUGMODEON}
        DebugInfo.Add('Received a packet from the server with an unknown header: '+InttoStr(Command));
      {$ENDIF}
      If Assigned(FOnUnknownPacketID) then
        FOnUnknownPacketID(Self, Data, Command);
    end;
  end; //~CASE END
end;

Procedure TFasterTCPClient.Send(Buffer: PChar; BufLength: LongInt);
begin
  If BufLength = 0 then
    Exit;
  SendPacketTo(Self,CreatePacket(BufLength * SizeOf(Char),MESSAGE_Packet_ID,Buffer));
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Message sent to the server: ' + String(Buffer));
  {$ENDIF}
end;

Procedure TFasterTCPClient.SendCommand(Command, CommandDataSize: LongInt; Data: Pointer);
begin
  if Data <> nil then
    SendPacketTo(Self, CreatePacket(CommandDataSize,Command,Data)) else
  SendPacketTo(Self, CreatePacket(0,Command,nil));
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Command sent :' + IntToStr(Command));
  {$ENDIF}
end;

Procedure TFasterTCPClient.SendCustomPacket(ID, DataSize: LongInt; Data: TStream);
Var TempData: Pointer;
  TempPacket: TFasterPacket;
begin   
  TempData := nil;
  If DataSize > 0 then begin
      GetMem(TempData,DataSize);
      Try
        Data.Read(TempData^,DataSize);
        TempPacket := CreatePacket(DataSize,ID,TempData);
      Except
       FreeMem(TempData);
      end;
  end else
    TempPacket := CreatePacket(0,ID,nil);

  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Custom packet sent, ID: ' + IntToStr(ID));
  {$ENDIF}
  SendPacketTo(Self,TempPacket);
  if tempData <> nil then
    FreeMem(TempData);
end;

Procedure TFasterTCPClient.SendCustomPacketEx(ID, DataSize: LongInt; Data: Pointer);
Var TempPacket: TFasterPacket;
begin
  If DataSize > 0 then begin
      Try
        TempPacket := CreatePacket(DataSize,ID,Data);
      Except
      end;
  end else
    TempPacket := CreatePacket(0,ID,nil);

  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Custom packet sent, ID: ' + IntToStr(ID));
  {$ENDIF}
  SendPacketTo(Self,TempPacket);
end;

Procedure TFasterTCPClient.SendStream(Stream: TStream; Size: LongInt);
begin
  SendStreamTo(Self, Stream, Size);
  {$IFDEF DEBUGMODEON}
    FDebugInfo.Add('Stream sending started, size: ' + IntToStr(Size));
  {$ENDIF}
end;

Procedure TFasterTCPClient.SendToClient(Buffer: Pointer; ClientName: PChar; Size: LongInt);
Var
  TempPacket: TFasterPacket;
  TmpStream: TMemoryStream;
  len: LongInt;
begin                                   
  TmpStream := TMemoryStream.Create;     
  Try
    len := Length(ClientName) * SizeOf(Char);
    TmpStream.Write{Integer}(len, SizeOf(len));  
    TmpStream.Write(ClientName^, len);
    TmpStream.Write(Buffer^, Size);   

    len := Length(FUserName) * SizeOf(Char);
    TmpStream.Write(FUserName[1], len);
    TmpStream.Write{Integer}(len, SizeOf(len)); 

    TempPacket := CreatePacket(TmpStream.Size,CLIENT_TO_CLIENT_ID,TmpStream.Memory);
    SendPacketTo(Self,TempPacket);
  Finally TmpStream.Free; end;
end;

procedure TFasterTCPClient.SetConnected(Value: Boolean);
var
  lin: TLinger;
  linx: Array[0..3] of AnsiChar absolute lin;
begin
  If not (csDesigning in ComponentState) then
   If FConnected <> Value then
    begin
    {$IFDEF DEBUGMODEON}
      If Value then
        FDebugInfo.Add('Client starts the connection') else
        FDebugInfo.Add('Client closes the connection');
    {$ENDIF}
     ClearStreamProperties;
     If Value then
      begin
       If (FRoom = '') or (FUserName = '') then
         Raise Exception.Create('Room and username must be specified before connecting!');
       SockAddrIn.sin_family := AF_INET;
       SockAddrIn.sin_port := htons(FPort);
       SockAddrIn.sin_addr.s_addr := inet_addr(PAnsiChar(Host));
       If (SockAddrIn.sin_addr.s_addr = INADDR_NONE) OR
       (SockAddrIn.sin_addr.s_addr = INADDR_ANY) then
        begin
         HostEnt := GetHostByName(PAnsiChar(Host));
         If HostEnt = nil then
          begin
           SocketError(INVALID_SOCKET, WSAEFAULT);
           Exit;
          end;
         SockAddrIn.sin_addr.S_addr := LongInt(PLongInt(HostEnt^.h_addr_list^)^);
        end;
        
       FSocket := WinSock.Socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
       If FSocket = INVALID_SOCKET then begin
         SocketError(INVALID_SOCKET, WSAGetLastError);
         Exit;
       end;

       If WSAASyncSelect(FSocket, WindowHandle, SYNCSELECT_ID,
                         FD_READ or FD_CONNECT or FD_CLOSE) <> 0 then
        begin
         SocketError(FSocket, WSAGetLastError);
         Exit;
        end;

      If (WinSock.Connect(FSocket, SockAddrIn, SizeOf(SockAddrIn)) <> 0) and
         (WSAGetLastError <> WSAEWOULDBLOCK) then
       begin
         SocketError(FSocket, WSAGetLastError);
         Exit;
      end;
      FConnected := Value;
      FPingTimer.Enabled := true;
      end
     else
      begin
       FPingTimer.Enabled := false;

       WSAASyncSelect(FSocket, WindowHandle, SYNCSELECT_ID, 0);
       Shutdown(FSocket, 2);
       lin.l_onoff := 1;
       lin.l_linger := 0;
       SetSockOpt(FSocket, SOL_SOCKET, SO_LINGER, linx, SizeOf(Lin));

       If CloseSocket(FSocket) <> 0 then begin
         SocketError(FSocket, WSAGetLastError);
         Exit;
       end;

       FSocket := INVALID_SOCKET;
       FConnected := False;
       If Assigned(FOnDisconnected) and not (csDestroying in ComponentState) then
         FOnDisconnected(Self);
      end;
    end
   else
  else
   If Value then
    raise Exception.Create('Can not connect at design-time');
end; 

procedure TFasterTCPClient.SetHost(Value: AnsiString);
begin
  If not (csDesigning in ComponentState) then
   If FHost <> Value then
    If FConnected then
     If FAllowChangeHostAndPortOnConnection then
      begin
       Connected := False;
       FHost := Value;
       Connected := True;
       ClearStreamProperties;
      end
     else
      raise Exception.Create('Can not change the Host while connected')
    else
     FHost := Value
   else
  else FHost := Value;   
end;       

procedure TFasterTCPClient.SetMaxPingInterval(Value: Cardinal);
begin
  FPingInterval := Value;
  FPingTimer.Interval := Value;
end;

procedure TFasterTCPClient.SetPort(Value: Word);
begin
  If not (csDesigning in ComponentState) then
   If FPort <> Value then
    If FConnected then
     If FAllowChangeHostAndPortOnConnection then
      begin
       Connected := False;
       FPort := Value;
       Connected := True;
       ClearStreamProperties;
      end
     else
      raise Exception.Create('Can not change the Port while connected')
    else
     FPort := Value
   else
  else
   FPort := Value;
end;

procedure TFasterTCPClient.SocketError(aSocket: TSocket; ErrorCode: LongInt);
begin
  if(ErrorCode <> WSAEWOULDBLOCK) then
    Connected := false; // break connection
  inherited;
end;

procedure TFasterTCPClient.StopReceivingData;
begin
  SendCommand(DATA_RECEIVING_STOPPED_ID,0,nil);
end;

procedure TFasterTCPClient.StopSendingData;
begin
  SendCommand(DATA_SENDING_STOPPED_ID,0,nil);
end;

procedure TFasterTCPClient.UpdatePingStatus;
begin
  SendCommand(PING_ID, 0, nil);
  Case FPingStatus of
   PingOK: FPingStatus := WaitingPing;
   WaitingPing: begin
     Inc(FTimeOuts);
     If Assigned(FOnTimeOut) then
       FOnTimeOut(Self);
   end;
  End;
end;

procedure Register;
begin
  RegisterComponents('Faster TCP', [TFasterTCPServer, TFasterTCPClient]);
end;

var
  WSAData: TWSAData; // dummy WinSock startup data

initialization
  WSAStartup($0101, WSAData);
  {$IFDEF FPC}
  {$I fastertcp.lrs}
  {$ENDIF}

finalization
  WSACleanup;
  
end.
