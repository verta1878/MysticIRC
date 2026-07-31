unit ClusterChat;
{
  Cluster DCC Chat component by joepezT

  IRC: joepezT @ undernet :  #Delphi
  ICQ: 340148, 3941292
  Email: Gothic(a)bluezone.no (Primary mail)  - (a) = @
         vortex(a)berzerk.net (questions regarding this component)

  Main purpose:
  Easy implementation of Direct chat over IRC.

  download ICS from www.overbyte.be
  You can use this component freely as long as you mention my name :-)

}

interface

uses
  Messages, SysUtils, Classes, Controls, wsocket;

type
  TDCCChat = class(Tobject)
  end;
   Tstartevent     = procedure of object;
   TUserConnect    = procedure (Socket : TWsocket) of Object;
   TUserDisconnect = procedure (Socket : TWsocket) of Object;
   TUserMessage    = procedure (Socket : TWsocket; User, RemoteHost, ReceivedMessage : string) of Object;

type
  TClusterChat = class(TComponent)
  private
    Start           : Tstartevent;
    ListenServer    : Twsocket;
    Chatlist        : TList;
    FListen         : Boolean;
    FListenport     : string;
    FUserMessage    : TUserMessage;
    FUserConnect    : TUserConnect;
    FUserDisconnect : TUserDisconnect;
    procedure OnConnect(Sender: TObject; Error: Word);
    procedure OnListenConnect(Sender: TObject; Error: Word);
    procedure OnDisconnect(Sender: TObject; Error: Word);
    procedure OnSocketDataAvailable(Sender: TObject; Error: Word);
  protected
    procedure   Loaded; override;
    constructor Create  (AOwner : TComponent); override;
    destructor  Destroy; override;
  public
    procedure Connect(Remotehost, Remoteport, id: string);
    procedure SendMessage(id : integer; MessageToSend : string);
    function  RestartServer: boolean;
  published
    property Listen     : Boolean read FListen write FListen;
    property ListenPort : string read FListenport write FListenport;
    property OnStarted  : TStartEvent  read Start write Start;
    property OnMessage  : TUserMessage read FUserMessage write FUserMessage;
    property GetListenPort : string read FListenPort;
    property SetListenPort : string Write FListenPort;
    property OnUserConnect         : TUserConnect  read FUserConnect write FUserConnect;
    property OnListenSocketConnect : TUserConnect  read FUserConnect write FUserConnect;
    property OnUserDisconnect      : TUserDisconnect  read FUserDisconnect write FUserDisconnect;
  end;

procedure Register;

implementation


procedure Register;
begin
  RegisterComponents('joepezT', [TClusterChat]);
end;

procedure TClusterChat.OnSocketDataAvailable(Sender: TObject; Error: Word);
var
received : string;

begin
  if not assigned(ListenServer) then exit;
  with TWsocket(sender) do
  begin
    received := trim(ReceiveStr);
    If assigned(FUserMessage) then
    FUserMessage(twsocket(sender),IntToStr(tag),GetPeerAddr,received);
  end;
end;

procedure TClusterChat.OnListenConnect(Sender: TObject;
  Error: Word);
var
id : integer;
UserSock : Twsocket;
begin
   UserSock := Twsocket.create(self);
  with UserSock do
  begin
    Chatlist.Add(UserSock);
    OnDataAvailable := OnSocketDataAvailable;
{    OnSessionClosed := OnDisconnect;}
    OnSessionAvailable := OnDisconnect;
    tag := chatlist.Count;
    HSocket := twsocket(sender).Accept;
    if assigned(FuserConnect) then
    FuserConnect(twsocket(sender));
  end;
end;

procedure TClusterChat.OnConnect(Sender: TObject;
  Error: Word);
begin
  if assigned(FuserConnect) then
  FuserConnect(twsocket(sender));
end;



procedure TClusterChat.SendMessage(id : integer; MessageToSend : string);
begin
  with TObject(Chatlist.items[id-1]) as TWsocket do
  try
    SendStr(MessageToSend + #13#10);
  except
    {
      this error may trigger if there are no connection
      or the id does not exist OR out of bound.
    }
  end;
end;

procedure TClusterChat.Connect(Remotehost,Remoteport,id : string);
var
UserSock : Twsocket;
begin
  UserSock := Twsocket.create(self);
  with UserSock do
  begin
    Chatlist.Add(UserSock);
    OnDataAvailable := OnSocketDataAvailable;
    OnSessionClosed := OnDisconnect;
{    OnSessionAvailable := OnConnect;}
    OnSessionConnected := OnConnect;
    tag := chatlist.Count;
    port := Remoteport;
    addr := Remotehost;
    Connect;
  end;
end;

procedure TClusterChat.OnDisconnect(Sender: TObject;
  Error: Word);
begin
  if assigned(FuserDisconnect) then
    FUserDisconnect(twsocket(sender));
end;

function TClusterChat.RestartServer : boolean;
begin
  if assigned(ListenServer) then
  FreeAndNil(ListenServer);
  if FListen <> true then
  begin
    result := false;
  end;

  try
    ListenServer := TWSocket.Create(Self);
    With ListenServer do
    begin
      OnDataAvailable := OnSocketDataAvailable;
      OnSessionAvailable := OnListenConnect;
      OnSessionClosed := OnDisconnect;
      if GetListenPort = '' then
      begin
        {
          If we have not deffined any values we get a random port
          Avoid using a string here... :(
        }
        SetListenPort := format('%d',[random(65535)]);
      end;
      port := GetListenPort;
      Linemode := true;
      LineEnd := #13#10;
      proto := 'tcp';
      Addr  := '0.0.0.0';
      listen;
    end;
    except
      {
        Unable to make listening port
        False is returned if the listening part fails
      }
      result := false;
      exit;
    end;
    result := true;
end;



procedure TClusterChat.Loaded;
begin
  inherited Loaded;
  if not (csDesigning in ComponentState) then
  begin
    RestartServer; { Create listening server }
    if Assigned(start) then
       start;
  end;
end;


constructor TClusterChat.Create(AOwner: TComponent);
begin
  inherited Create(Aowner);
  if (csDesigning in ComponentState) then

  { set a random value }
  SetListenPort := format('%d',[random(65535)]);

  if not (csDesigning in ComponentState) then
    Chatlist := Tlist.create;
end;

destructor TClusterChat.Destroy;
begin
  if not (csDesigning in ComponentState) then
  FreeAndNil(Chatlist);

  inherited Destroy;
end;





end.

