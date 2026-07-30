unit XiRC;

{
////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
////                                                                    ////
////                          XiRC Component                            ////
////                    Written by Martin Bleakley                      ////
////                        Indy Socket Version                         ////
////                                                                    ////
////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////


  File:    XiRC.Pas
  Version: 0.3a
  Author:  Martin Bleakley
  E.Mail:  marty@xsm.co.nz
  Web:     http://www.xsm.co.nz
  IRC:     XsMarty or XsM @ EFNet
  Date:    16 November 2001

  Delphi:  6
  Needs:   Indy 8 should work with 9

  License: Don't redistribute for cash.  Don't change and
           redistribute under your name.  Let me know
           if you fix anything or improve anything and
           I will add it to the main release with credits.

  Desc:    Component for easly creating IRC chat clients

  Use:     I don't have time to write a help file sorry.

  Changes: Added some checking for connection to try and handle the conneciton reset by peer


}


interface

uses
  Windows, Messages, SysUtils, Classes, IdBaseComponent, IdComponent,IdIntercept,IdException,
  IdTCPConnection,IdWinsock, IdTCPClient, IdThread, IdSocks, DateUtils, Token, dialogs;

type
  TConState = (ssDisconnected, ssConnected, ssLoggedin);
  TUser = class;
  TXiRC = class;
  TReplies = class;

  TSocketThread = class(TThread)
  private
    procedure HandleData;
    procedure GetCommand(FData: string);
  protected
    procedure Execute; override;
  public
    Parent: TXiRC;
    RawData: string;
    Command: string;
  published
  end;

  TConnectThread = class(TThread)
  private
  protected
    procedure Execute; override;
  public
    Parent: TXiRC;
  published
  end;

  TUser = class(TPersistent)
  private
    FNick: string;
    FAltNick: string;
    FPassword: string;
    FUserName: string;
    FEmail: string;
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
  published
    property Nick: string read FNick write FNick;
    property AltNick: string read FAltNick write FAltNick;
    property Password: string read FPassword write FPassword;
    property UserName: string read FUserName write FUserName;
    property Email: string read FEmail write FEmail;
  end;

  TReplies = class(TPersistent)
  private
    FFinger: string;
    FVersion: string;
    FUserInfo: string;
    FClientInfo: string;
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
  published
    property Finger: string read FFinger write FFinger;
    property Version: string read FVersion write FVersion;
    property UserInfo: string read FUserInfo write FUserInfo;
    property ClientInfo: string read FClientInfo write FClientInfo;
  end;

  TServerEvent = procedure of object;
  TOnRawData = procedure(Text: string) of object;
  TOnServerMsg = procedure(Text: string) of object;
  TOnSend = procedure(Data : string) of object;
  TOnPrivMsg = procedure(Nick, Address, Dest, Content: string) of object;
  TOnNotice = procedure(From, Dest, Text: string) of object;
  TOnInfo = procedure(Info: string) of object;
  TOnCTCPRequest = procedure(From, Address, CTCP, Request: string) of object;
  TOnPingPong = procedure(Data: string) of object;
  TOnJoin = procedure(Nick, Address, Channel: string) of object;
  TOnPart = procedure(Nick, Address, Channel, PartMsg: string) of object;
  TOnNames = procedure(Channel, Data: string) of object;
  TOnNamesEnd = procedure(Channel, Data: string) of object;
  TOnError = procedure(ErrorNumber: integer; Errormsg: string) of object;
  TOnNumeric = procedure(CMD: integer; Content, Nick, Address: string) of object;
  TOnCommand = procedure(Command, Nick, Address, Content: string) of object;
  TOnServerError = procedure(ErrorMsg: string) of object;
  TOnQuit = procedure(Nick, Address, QuitMsg: string) of object;
  TOnKick = procedure(Nick, Address, Channel, Person, Reason: string) of object;
  TOnAction = procedure(Nick, Address, Channel, Content: string) of object;
  TOnSound = procedure(Nick, Address, Channel, FileName: string) of object;
  TOnDCC = procedure(Nick, Address, Data: string) of object;
  TOnChannelMode = procedure(Nick, Channel, Modes: string) of object;
  TOnUserMode = procedure(Modes: string) of object;
  TOnInvite = procedure(Nick, Address, Channel: string) of object;
  TOnNick = procedure(OldNick, Address, NewNick: string) of object;
  TOnMOTD = procedure(Content: string) of object;
  TOnMOTDEnd = procedure(Content: string) of object;
  TOnLoggedIn = procedure(ServerName, NickName: string) of object;
  TOnKill = procedure(Oper, Victium, Reason: string) of object;
  TOnWho = procedure(Data: string) of object;
  TOnWhoIS = procedure(Data: string) of object;
  TOnTopic = procedure(Channel, Title: string) of object;
  TOnTopicInfo = procedure(channel, Who: string; When: TDatetime) of object;
  TOnTopicChange = procedure(channel, Who, Topic: string) of object;
  TChanModeIs = procedure(Channel,Modes : string) of object;

  TXiRC = class(TComponent)

  private
    FHost: string;
    FPort: integer;
    FReplies: TReplies;
    FUser: TUser;
    FSocket: TIdTCPClient;
    SocketClose: TServerEvent;
    SocketOpen: TServerEvent;
    FPrivMsg: TOnPrivmsg;
    FNotice: TOnNotice;
    FOnSend : TOnSend;
    FServerMsg: TOnServerMsg;
    FCTCP: TOnCTCPRequest;
    FRawData: TOnRawData;
    FPingPong: TOnPingPong;
    FOnNames: TOnNames;
    FOnNamesEnd: TOnNamesEnd;
    FOnError: TOnError;
    FOnServerError : TOnServerError;
    FNumeric: TOnNumeric;
    FOnCommand: TOnCommand;
    FOnInfo: TOnInfo;
    FOnJoin: TOnJoin;
    FOnPart: TOnPart;
    FOnQuit: TOnQuit;
    FOnKick: TOnKick;
    FOnAction: TOnAction;
    FOnSound: TOnSound;
    FOnDCC: TOnDCC;
    FOnChannelMode: TOnChannelMode;
    FOnUserMode: TOnUserMode;
    FOnInvite: TOnInvite;
    FOnNick: TOnNick;
    FOnMOTD: TOnMOTD;
    FOnMOTDEnd: TOnMOTDEnd;
    FOnLoggedIn: TOnLoggedIn;
    FConState: TConState;
    FOnKill: TOnKill;
    FOnWho: TOnWho;
    FOnWhoIS: TOnWhoIS;
    FOnTopic: TOnTopic;
    FOnTopicInfo: TOnTopicInfo;
    FOnTopicChange: TonTopicChange;
    FChanModeIs : TChanModeIs;
    Command: string;
    FisAltNick : boolean;
    function GetIntercept: TIdConnectionIntercept;
    function GetInterceptEnable : boolean;
    function GetSocksInfo : TSocksInfo;
    function MatchCommand: integer;
    function SplitStrings(const str: string; const separator: string;
     Strings: TStrings): TStrings;
    procedure SetReplies(Value: TReplies);
    procedure SetUser(Value: TUser);
    procedure OnConnected(Sender: TObject);
    procedure OnDisconnected(Sender: TObject);
    procedure ProcessNumeric(Data: string);
    procedure ProcessCommand(Data: string);
    procedure ProcessPrivMsg(Nick, Address, Content: string);
    procedure ProcessNotice(Nick, Address, Content: string);
    procedure ProcessJoin(Nick, Address, Content: string);
    procedure ProcessPart(Nick, Address, Content: string);
    procedure ProcessKick(Nick, Address, Content: string);
    procedure ProcessMode(Nick, Address, Content: string);
    procedure ProcessQuit(Nick, Address, Content: string);
    procedure ProcessCTCP(Nick, Address, Dest, CTCP, Request: string);
    procedure ProcessNick(Nick, Address, Content: string);
    procedure ProcessInvite(Nick, Address, Content: string);
    procedure ProcessKill(Nick, Address, Content: string);
    procedure ProcessNames(RawData: string);
    procedure ProcessNamesEnd(Data: string);
    procedure ProcessTopic(Data: string);
    procedure ProcessTopicInfo(Data: string);
    procedure ProcessTopicChange(Nick, Data: string);
    procedure ProcessIdleTime(Data : string);
    procedure ProcessChannelModeIs(Data : string);
    procedure SetConState(const Value: TConState);
    procedure SetIntercept(AValue: TIdConnectionIntercept);
    procedure SetInterceptEnabled(AValue: Boolean);
    procedure SetSocksInfo(AValue : TSocksInfo);
  protected

  public
    FServer: string;
    CurrentNick: string;
    CurrentServer: string;
    function GetLocalIP: string;
    function GetLongIP: Cardinal;
    procedure Connect;
    procedure Disconnect;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Raw(Command: string);
    procedure Notice(User, Text: string);
    procedure Say(Dest, Text: string);
    procedure Quit(QuitMsg: string);
    procedure Join(Channel: string);
    procedure Part(Channel, Reason: string);
    procedure SetAway(Msg: String);
    procedure SetBack;
    procedure CTCPQuery(Target, Command, Parameters: String);
    procedure GetTopic(Channel: String);
    procedure SetTopic(Channel, Topic: String);
    procedure OnThreadException(Sender: TObject; E: Exception);
    property ConState: TConState read FConState;
    procedure SendDccChat(Nick : string;Port : integer);
    procedure SendDCCMsg(Nick,Filename : string;Size : int64;Port : integer;Turbo : boolean);
    procedure SendDCCAccept(Nick,Filename : string;Port: integer;Size : int64);
    procedure SendDccResume(Nick,Filename : string;Port: integer;Size : int64);
  published

    property Host: string read FHost write FHost;
    property Port: integer read FPort write FPort;
    property CTCPInfo: TReplies read FReplies write SetReplies;
    property UserInfo: TUser read FUser write SetUser;
    property Intercept : TidConnectionIntercept read GetIntercept write SetIntercept;
    property InterceptEnabled: Boolean read GetInterceptEnable write SetInterceptEnabled default False;
    property SocksInfo: TSocksInfo read GetSocksInfo write SetSocksInfo;

    property OnConnect: TServerEvent read SocketOpen write SocketOpen;
    property OnDisConnect: TServerEvent read SocketClose write SocketClose;
    property OnRaw: TOnRawData read FRawData write FRawData;
    property OnPrivMsg: TOnPrivMsg read FPrivMsg write FPrivMsg;
    property OnNotice: TOnNotice read FNotice write FNotice;
    property OnServerMsg: TOnServerMsg read FServerMsg write FServerMsg;
    property OnSend : TOnSend read FOnSend write FOnSend;
    property OnCTCPRequest: TOnCTCPRequest read FCTCP write FCTCP;
    property OnPing: TOnPingPong read FPingPong write FPingPong;
    property OnNames: TOnNames read FOnNames write FOnNames;
    property OnNamesEnd: TOnNamesEnd read FOnNamesEnd write FOnNamesEnd;
    property OnError: TOnError read FOnError write FOnError;
    property OnNumeric: TOnNumeric read FNumeric write FNumeric;
    property OnCommand: TOnCommand read FOnCommand write FOnCommand;
    property OnInfo: TOnInfo read FOnInfo write FOnInfo;
    property OnJoin: TOnJoin read FOnJoin write FOnJoin;
    property OnPart: TOnpart read FOnPart write FOnPart;
    property OnQuit: TOnQuit read FOnQuit write FOnQuit;
    property OnKick: TOnKick read FOnKick write FOnKick;
    property OnAction: TOnAction read FOnAction write FOnAction;
    property OnSound: TOnSound read FOnSound write FOnSound;
    property OnDCC: TOnDCC read FOnDCC write FOnDCC;
    property OnChannelMode: TOnCHannelMode read FOnChannelMode write FOnChannelMode;
    property OnUserMode: TOnUserMode read FOnUserMode write FOnUserMode;
    property OnInvite: TOnInVite read FOnInvite write FOnInvite;
    property OnNick: TOnNick read FOnNick write FOnNick;
    property OnMOTD: TOnMOTD read FOnMOTD write FOnMOTD;
    property OnMOTDEnd: TOnMOTDEnd read FOnMOTDEnd write FOnMOTDEnd;
    property OnLoggedIn: TOnLoggedIn read FOnLoggedIn write FOnLoggedIn;
    property OnKill: TOnKill read FOnKill write FOnKill;
    property OnWho: TOnWho read FOnWho write FOnWho;
    property OnWhoIS: TOnWhoIS read FOnWhoIS write FOnWhoIS;
    property OnTopic: TOnTopic read FOnTopic write FOnTopic;
    property OnTopicInfo: TOnTopicInfo read FOnTopicInfo write FOnTopicInfo;
    property OnTopicChange: TOnTopicChange read FOnTopicChange write FOnTopicChange;
    property OnChanModeIs : TChanModeIs read FChanModeIs write FChanModeIs;
    property OnServerError : TOnServerError read FOnServerError write FOnServerError;
  end;

const
  LF = #10;
  CR = #13;
  EOL = CR + LF;

  Commands: array[0..17] of string = ('PRIVMSG', 'NOTICE', 'JOIN', 'PART',
    'KICK',
    'MODE', 'NICK', 'QUIT', 'INVITE', 'KILL', 'PING', 'WALLOPS', 'TOPIC',
      'ERROR', 'CREATE', 'KNOCK', 'PROP', 'WHISPER');

var
  CurrentServer: string;

procedure Register;

implementation

/////////////////////////////////////////////////////////
// TSocketThread                                       //
/////////////////////////////////////////////////////////


procedure TSocketThread.Execute;
begin
  while not Terminated and Parent.FSocket.Connected do
  begin
    try
      RawData := Parent.FSocket.ReadLn;
      Synchronize(HandleData);
    except
      Terminate;
    end;
  end;
end;

procedure TSocketThread.HandleData;
begin
  GetCommand(RawData);
end;

procedure TSocketThread.GetCommand(FData: string);
var
  Cmd: integer;
  CmdString,content: string;
begin
  GetFirstToken(FData);
  CmdString := GetNextToken;
  Cmd := StrToIntDef(CmdString, -1);
  if assigned(Parent.FRawData) then
    Parent.FRawData(FData);
  if Cmd > -1 then
  begin
    Parent.ProcessNumeric(FData);
  end
  else
  begin
  //handle ping here just in case your
  //going a long operation like list and this will make you time out
   if UpperCase(GetFirstToken(FData)) = 'PING' then
   begin
    Content := GetRemainingTokens;
    if assigned(Parent.FPingPong) then Parent.FPingPong(Content);
    Parent.Raw('PONG '+Content);
   end; 
   Parent.ProcessCommand(FData);
  end;
end;

/////////////////////////////////////////////////////////
// TConnectThread                                      //
/////////////////////////////////////////////////////////

procedure TConnectThread.Execute;
begin
  while not Terminated and not Parent.FSocket.Connected do
  begin
    try
      TXiRC(Parent).FSocket.Connect;
    except
      Terminate;
    end;
  end;
end;

/////////////////////////////////////////////////////////
// TXiRC                                               //
/////////////////////////////////////////////////////////
function TXiRC.GetLocalIp : string;
type
  TaPInAddr = Array[0..10] of PInAddr;
  PaPInAddr = ^TaPInAddr;
var
  phe: PHostEnt;
  pptr: PaPInAddr;
  Buffer: Array[0..63] of Char;
  I: Integer;
  GInitData: TWSAData;
begin
  WSAStartup($101, GInitData);
  Result := '';
  GetHostName(Buffer, SizeOf(Buffer));
  phe := GetHostByName(buffer);
  if phe = nil then Exit;
  pPtr := PaPInAddr(phe^.h_addr_list);
  I := 0;
  while pPtr^[I] <> nil do
   begin
    Result := inet_ntoa(pptr^[I]^);
    Inc(I);
   end;
  WSACleanup;
end;

function TXiRC.SplitStrings(const str: string; const separator: string;
   Strings: TStrings): TStrings;
var
   n: integer;
   p, q, s: PChar;
   item: string;
begin
  if Strings = nil then
    Result := TStringList.Create
  else
   Result := Strings;
  try
    p := PChar(str);
    s := PChar(separator);
    n := Length(separator);
  repeat
    q := StrPos(p, s);
    if q = nil then q := StrScan(p, #0);
    SetString(item, p, q - p);
    Result.Add(item);
    p := q + n;
  until q^ = #0;
  except
  item := '';
  if Strings = nil then Result.Free;
   raise;
   end;
end;

function TXiRC.GetLongIP: Cardinal;
var
  szIP: PChar;
  IP : string;
  IPList: TStringList;
begin
  try
    IP := GetLocalIP;
    iplist := Tstringlist.Create;
    SplitStrings(IP, '.', iplist);
    if iplist.count - 1 = 3 then
    begin
      ip := Format('%d.%d.%d.%d', [StrToInt(iplist[3]), StrToInt(iplist[2]), StrToInt(iplist[1]), StrToInt(iplist[0])]);
    end;
    iplist.free;
    szIP := PChar(IP);
    result := inet_addr(szIP);
  except
    result := Inet_Addr('0.0.0.0');
  end;
end;

procedure TXiRC.SendDccChat(Nick : string;Port : integer);
begin
  Raw(format('NOTICE %s :DCC Chat (%s)',[Nick,GetLocalIp]));
  Raw(format('PRIVMSG %s :DCC CHAT chat %s %s',[Nick,Inttostr(GetLongIP),inttostr(Port)]));
end;

procedure TXiRC.SendDCCMsg(Nick,Filename : string;Size : int64;Port : integer;Turbo : boolean);
begin
  if pos(' ',FileName) <> 0 then Filename := '"'+FileName+'"';
  if Turbo then
  begin
    Raw(Format('PRIVMSG %s :'#1'DCC TSEND %s %s %d %s T'#1, [Nick, FileName, Inttostr(GetLongIP), Port, inttostr(Size)]));
    Raw(Format('NOTICE %s :DCC TSend %s (%s) [%s, Port %d]', [Nick, FileName,inttostr(Size) ,GetLocalIP , Port]));
  end else
  begin
    Raw(Format('PRIVMSG %s :'#1'DCC SEND %s %s %d %s T'#1, [Nick, FileName, Inttostr(GetLongIP), Port, inttostr(Size)]));
    Raw(Format('NOTICE %s :DCC Send %s (%s) [%s, Port %d]', [Nick, FileName,inttostr(Size) ,GetLocalIP , Port]));
  end;
end;

procedure TXiRC.SendDCCAccept(Nick,Filename : string;Port: integer;Size : int64);
begin
  Raw(format('PRIVMSG %s :DCC ACCEPT %s %s %s',[Nick,filename,inttostr(Port),inttostr(size)]));
end;

procedure TXiRC.SendDccResume(Nick,Filename : string;Port: integer;Size : int64);
begin
  Raw(format('PRIVMSG %s :DCC RESUME %s %s %s',[Nick,filename,inttostr(Port),inttostr(size)]));
end;

constructor TXiRC.Create(AOwner: Tcomponent);
begin
  inherited create(AOwner);
  FReplies := TReplies.Create;
  FUser := TUser.Create;
  FHost := '';
  FPort := 6667;
  with FReplies do
  begin
    Finger := '';
    Version := 'XiRC Component written by Martin Bleakley';
    UserInfo := '';
    ClientInfo := '';
  end;
  with FUser do
  begin
    Nick := 'Nick';
    AltNick := 'AltNick';
    Password := '';
    UserName := 'Name';
    Email := 'your@email.com';
  end;
  FSocket := TiDTCPClient.Create(nil);
  FSocket.OnConnected := OnConnected;
  FSocket.OnDisconnected := OnDisconnected;
  FConState := ssDisconnected;
  FisAltNick := False;
end;

destructor TXiRC.Destroy;
begin
  FSocket.Free;
  FUser.Free;
  FReplies.Free;
  inherited destroy;
end;

procedure TXiRC.OnThreadException(Sender: TObject; E: Exception);
begin

end;

procedure TXiRC.SetReplies(Value: TReplies);
begin
  FReplies.Assign(Value);
end;

procedure TXiRC.SetUser(Value: TUser);
begin
  FUser.Assign(Value);
end;

procedure TXiRC.Connect;
var
  ConnectThread: TConnectThread;
begin
  if FHost <> '' then
  begin
    FSocket.Host := FHost;
    FSocket.Port := FPort;
    ConnectThread := TConnectThread.Create(False);
    ConnectThread.Parent := self;
    ConnectThread.FreeOnTerminate := true;
  end
  else if assigned(FServerMsg) then
    FServerMsg('* No HOST specified');
end;

procedure TXiRC.Disconnect;
begin
  SetConState(ssDisconnected);
  if TSocketThread(self) <> nil then
    TSocketThread(self).Terminate;
  FSocket.Disconnect;
end;

procedure TXiRC.Raw(Command: string);
begin
  FSocket.CheckForDisconnect(false,false);
  if FSocket.Connected then
  try
    FSocket.WriteLn(Command);
    if assigned(FOnSend) then FOnSend(Command);
    except
     if assigned(FOnServerError) then FOnServerError('Connection Closed');
     SetConState(ssDisconnected);
     if Assigned(socketclose) then socketclose;
  end;
end;

procedure TXiRC.Notice(User, Text: string);
begin
  raw(format('NOTICE %s :%s', [User, Text]));
end;

procedure TXiRC.Say(Dest, Text: string);
begin
  raw(format('PRIVMSG %s :%s', [Dest, Text]));
end;

procedure TXiRC.Quit(QuitMsg: string);
begin
  raw(format('QUIT :%s', [QuitMsg]));
  Disconnect;
end;

procedure TXiRC.Join(Channel: string);
begin
  raw(format('join %s', [channel]));
end;

procedure TXiRC.SetAway(Msg: String);
begin
  Raw(Format('AWAY %s', [Msg]));
end;

procedure TXiRC.SetBack;
begin
  Raw('AWAY');
end;

procedure TXiRC.CTCPQuery(Target, Command, Parameters: String);
begin
  Say(Target, Format(#1'%s %s'#1, [Uppercase(Command), Parameters]));
end;

procedure TXiRC.GetTopic(Channel: String);
begin
  Raw(Format('TOPIC %s', [Channel]));
end;

procedure TXiRC.SetTopic(Channel, Topic: String);
begin
  Raw(Format('TOPIC %s :%s', [Channel, Topic]));
end;

procedure TXiRC.Part(Channel, Reason: string);
begin
  raw(format('part %s :%s', [channel, Reason]));
end;

procedure TXiRC.OnConnected(Sender: TObject);
var
  DataThread: TSocketThread;
begin
  SetConState(ssConnected);
  DataThread := TSocketThread.Create(False);
  DataThread.Parent := Self;
  
  DataThread.FreeOnTerminate := true;
  if FSocket.Connected then
  begin
    if pos(':',FUser.Email) <> 0 then
    FUser.Email := '"'+FUser.Email+'"';
    Raw('ISIRCX');
    if FUser.Password <> '' then
      Raw('PASS :' + FUser.Password);
    Raw('NICK ' + FUser.Nick);
    Raw(format('USER %s %s %s :%s', [FUser.Nick, FUser.Email, GetLocalIP,
      FUser.UserName]));
  end;
  if Assigned(SocketOpen) then
    SocketOpen;
end;

procedure TXiRC.OnDisConnected(Sender: TObject);
begin
  SetConState(ssDisconnected);
  if Assigned(socketclose) then
    socketclose;
    FisAltNick := False;
end;

function TXiRC.MatchCommand: integer;
var
  Index: Integer;
begin
  Index := 0;
  Result := -1;
  while (Result < 0) and (Index <= High(17)) do
  begin
    if Command = Commands[Index] then
      Result := Index;
    Inc(Index);
  end;
end;

function TXiRC.GetSocksInfo : TSocksInfo;
begin
  result := FSocket.SocksInfo;
end;


function TXiRC.GetInterceptEnable : boolean;
begin
  result := FSocket.InterceptEnabled;
end;

Function TXiRC.GetIntercept: TIdConnectionIntercept;
begin
  result := FSocket.Intercept;
end;

procedure TXiRC.SetSocksInfo(AValue : TSocksInfo);
begin
  if FSocket = nil then Exit else
  FSocket.SocksInfo := AValue;
end;

procedure TXiRC.SetIntercept(AValue: TIdConnectionIntercept);
begin
  if FSocket = nil then exit else
  if AValue <> FSocket.Intercept then
     FSocket.Intercept := AValue;
end;


procedure TXiRC.SetInterceptEnabled(AValue: Boolean);
begin
  if FSocket = nil then exit else
  if AValue <> FSocket.InterceptEnabled then
     FSocket.InterceptEnabled := AValue;
end;



procedure TXiRC.SetConState(const Value: TConState);
begin
  if value <> FConState then
    FConState := Value;
end;

procedure TXiRC.ProcessNumeric(Data: string);
var
  numeric, Index: integer;
  Tmp, Tmp2, Tmp3, Dest, Content: string;
  Nick, Address: string;
begin
  tmp := GetFirstToken(Data);
  tmp2 := GetNextToken;
  tmp3 := GetRemainingTokens;
  if tmp[1] = ':' then
    delete(tmp, 1, 1);
  Index := pos('!', Tmp);
  if Index > 0 then
  begin
    Nick := Copy(Tmp, 1, Index - 1);
    Address := Copy(Tmp, Index + 1, 512);
  end
  else
  begin
    Nick := '';
    Address := tmp;
  end;
  numeric := StrToIntDef(tmp2, -1);
  Dest := GetFirstToken(Tmp3);
  Content := GetRemainingTokens;
  if Content[1] = ':' then
    delete(content, 1, 1);
  if assigned(FNumeric) then
    FNumeric(Numeric, Content, Nick, Address);
  case numeric of
    001:
      begin
        CurrentNick := Dest;
        CurrentServer := Address;
        if Assigned(FServerMsg) then
          FServerMsg(Content);
        SetConState(ssLoggedIn);
        if assigned(FOnLoggedIn) then
          FOnLoggedIn(Address, CurrentNick);
      end;
    003, 004, 005: if Assigned(FServerMsg) then
        FServerMsg(Content);
    250, 251, 252, 253, 254, 255, 265, 266:
      begin
        if assigned(FOnInfo) then
          FOnInfo(Content);
      end;
    311, 312,313,318, 319: if assigned(FOnWhoIS) then FOnWhoIS(Content);
    317 : ProcessIdleTime(content);
    324: ProcessChannelModeIs(content);
    329: ;
    332: ProcessTopic(Content);
    333: ProcessTopicInfo(Content);
    315,
      352: if assigned(FOnWho) then
        FOnWho(Content);
    353: ProcessNames(Content);
    366: ProcessNamesEnd(Content);
    367,368:;//this is 367 for the banned list and 368 for end of band list
    372,
      375: if Assigned(FOnMOTD) then
        FOnMOTD(Content);
    376: if Assigned(FOnMOTDEnd) then
        FOnMOTDEnd(Content);
    381: if assigned(FOnInfo) then
        FOnInfo(Content);
    {error codes TODO :alot still to be worked on}
    401, { <nickname> :No such nick/channel }
    402, { <server name> :No such server }
    403, { <channel name> :No such channel }
    404, { <channel name> :Cannot send to channel }
    405, { <channel name> :You have joined too many channels }
    406, { <nickname> :There was no such nickname }
    407, { <target> :Duplicate recipients. No message delivered }
    409, { :No origin specified }
    411, { :No recipient given (<command>) }
    412, { :No text to send }
    413, { <mask> :No toplevel domain specified }
    414, { <mask> :Wildcard in toplevel domain }
    421, { <command> :Unknown command }
    422, { :MOTD File is missing }
    423, { <server> :No administrative info available }
    424: { :File error doing <file op> on <file> }
      begin
        if Assigned(FOnError) then
          FOnError(Numeric, Content);
      end;
    431, { :No nickname given }
    432, { <nick> :Erroneus nickname }
    433: { <nick> :Nickname is already in use }
      begin
        case Numeric of
          431,
            432: if assigned(FServerMSG) then
              FServerMsg('* Please enter valid Nick Name !!!');
          433:
            begin
              if ConState = ssLoggedin then
              begin
                if assigned(FServerMSG) then
                  FServerMsg(Content);
              end
              else
              begin
                if FUser.AltNick <> '' then
                begin
                  if assigned(FServerMSG) then
                  if FisAltNick then
                  begin
                    FServerMsg('All NickNames in Use');
                    Disconnect;
                  end else
                  begin
                    FServerMsg(format('* %S in use Sending Alternate( %s ) now......', [FUser.Nick, FUser.AltNick]));
                    Raw('NICK ' + FUser.AltNick);
                    FisAltNick := True;
                  end;
                end
                else
                begin
                  if assigned(FServerMSG) then
                    FServerMsg('* Please enter valid Nick Name !!!');
                end;
              end;
            end;
        end;
      end;
    436, { <nick> :Nickname collision KILL }
    441, { <nick> <channel> :They aren't on that channel }
    442, { <channel> :You're not on that channel }
    443, { <user> <channel> :is already on channel }
    444, { <user> :User not logged in }
    445, { :SUMMON has been disabled }
    446, { :USERS has been disabled }
    451, { :You have not registered }
    461, { <command> :Not enough parameters }
    462, { :You may not reregister }
    463, { :Your host isn't among the privileged }
    464, { :Password incorrect }
    465, { :You are banned from this server }
    467, { <channel> :Channel key already set }
    471, { <channel> :Cannot join channel (+l) }
    472, { <char> :is unknown mode char to me }
    473, { <channel> :Cannot join channel (+i) }
    474, { <channel> :Cannot join channel (+b) }
    475, { <channel> :Cannot join channel (+k) }
    481, { :Permission Denied- You're not an IRC operator }
    482, { <channel> :You're not channel operator }
    483, { :You cant kill a server! }
    491, { :No O-lines for your host }
    501, { :Unknown MODE flag }
    502: { :Cant change mode for other users }
      begin
        if Assigned(FOnError) then
          FOnError(Numeric, Content);
      end;
  end;
end;

procedure TXiRC.ProcessTopic(Data: string);
var
  chan, topic: string;
begin
  chan := GetFirstToken(Data);
  Topic := GetRemainingTokens;
  if Topic[1] = ':' then
    delete(Topic, 1, 1);
  if assigned(FOnTopic) then
    FOnTopic(Chan, Topic);
end;

procedure TXiRC.ProcessTopicInfo(Data: string);
var
  Chan, Who, tmp: string;
  Time: TDateTime;
begin
  Chan := GetFirstToken(Data);
  Who := GetNextToken;
  Tmp := GetRemainingTokens;
  if StrToInt64Def(Tmp, -1) > -1 then
  begin
    Time := UnixToDateTime(StrToInt64(Tmp));
    if assigned(FOnTopicInfo) then
      FOnTopicInfo(Chan, who, time);
  end;
end;

procedure TXiRC.ProcessTopicChange(Nick, Data: string);
var
  Channel, Topic: string;
begin
  CHannel := GetFirstToken(Data);
  Topic := GetRemainingTokens;
  if Topic[1] = ':' then
    delete(Topic, 1, 1);
  if assigned(FOnTopicCHange) then
    FOnTopicChange(Channel, Nick, Topic);
end;

procedure TXiRC.ProcessCommand(Data: string);
var
  numeric, Index: integer;
  Tmp, Tmp2, Tmp3, Content: string;
  Nick, Address: string;
begin

  if Data[1] = ':' then
  begin
    Tmp := GetFirstToken(Data);
    Tmp2 := GetNextToken;
    Tmp3 := GetRemainingTokens;
    delete(Tmp, 1, 1);
    Index := pos('!', Tmp);
    if Index > 0 then
    begin
      Nick := Copy(Tmp, 1, Index - 1);
      Address := Copy(Tmp, Index + 1, 512);
      Command := Tmp2;
      Content := Tmp3;
    end
    else
    begin
      Nick := '';
      Address := tmp;
      Command := tmp2;
      Content := Tmp3;
    end;
  end
  else
  begin
    Command := GetFirstToken(Data);
    Content := GetRemainingTokens;
  end;
  if assigned(FOnCommand) then
    FOnCommand(Command, Nick, Address, Content);
  Numeric := MatchCOmmand;
  case Numeric of
    0: ProcessPrivMsg(Nick, Address, Content); //PRIVMSG 0
    1: ProcessNotice(Nick, Address, Content); //NOTICE 1
    2: ProcessJoin(Nick, Address, Content); //JOIN 2
    3: ProcessPart(Nick, Address, Content); //PART 3
    4: ProcessKick(Nick, Address, Content); //KICK 4
    5: ProcessMode(Nick, Address, Content); //MODE 5
    6: ProcessNick(Nick, Address, Content); //NICK 6
    7: ProcessQuit(Nick, Address, Content); //QUIT 7
    8: ProcessInvite(Nick, Address, Content); //INVITE 8
    9: ProcessKill(Nick, Address, Content); //KILL 9
    11: if assigned(FServerMsg) then
        FServerMsg(Content); //WALLOPS 11
    12: ProcessTopicChange(Nick, Content); //TOPIC 12
    13:
      begin
        if Content[1] = ':' then
          delete(content, 1, 1);
        if assigned(FServerMsg) then
          FServerMsg(Content);
      end; //ERROR 13
  end;
end;

procedure TXiRC.ProcessPrivMsg(Nick, Address, Content: string);
var
  Dest: string;
begin
  Dest := GetFirstToken(Content);
  Content := GetRemainingTokens;
  if Content[1] = ':' then
    delete(COntent, 1, 1);
  if Content[1] = #1 then
  begin
    Delete(Content, 1, 1);
    Delete(Content, Length(Content), 1);
    ProcessCTCP(Nick, Address, Dest, GetFirstToken(Content),
      GetRemainingTokens);
  end
  else
  begin
    if assigned(FPrivMsg) then
      FPrivMsg(Nick, Address, Dest, Content);
  end;
end;

procedure TXiRC.ProcessCTCP(Nick, Address, Dest, CTCP, Request: string);
begin
  if assigned(FCTCP) then
    FCTCP(Nick, Address, CTCP, Request);
  if CTCP = 'ACTION' then
  begin
    if assigned(FOnAction) then
      FOnAction(Nick, Address, Dest, Request);
  end
  else if CTCP = 'VERSION' then
  begin
    raw('NOTICE ' + Nick + ' :' + #1 + CTCP + ' ' + FReplies.Version + #1);
  end
  else if CTCP = 'FINGER' then
  begin
    raw('NOTICE ' + Nick + ' :' + #1 + CTCP + ' ' + FReplies.Finger + #1);
  end
  else if CTCP = 'USERINFO' then
  begin
    raw('NOTICE ' + Nick + ' :' + #1 + CTCP + ' ' + FReplies.UserInfo + #1);
  end
  else if CTCP = 'CLIENTINFO' then
  begin
    raw('NOTICE ' + Nick + ' :' + #1 + CTCP + ' ' + FReplies.ClientInfo + #1);
  end
  else if CTCP = 'PING' then
  begin
    raw('NOTICE ' + Nick + ' :' + #1 + CTCP + ' ' + Request + #1);
  end
  else if CTCP = 'TIME' then
  begin
    raw('NOTICE ' + Nick + ' :' + #1 + CTCP + ' ' +
      FormatDateTime('dddd, mmmm d, h:nn am/pm', Now) + #1);
  end
  else if CTCP = 'ERROR' then
  begin
    raw('NOTICE ' + Nick + ' :' + #1 + CTCP + ' ' + Request + #1);
  end
  else if CTCP = 'DCC' then
  begin
    if assigned(FOnDCC) then
      FOnDCC(Nick, Address, Request);
  end
  else if CTCP = 'SOUND' then
  begin
    if assigned(FOnSound) then
      FOnSound(Nick, Address, Dest, Request);
  end;
end;

procedure TXiRC.ProcessIdleTime(Data : string);
var
  who ,idle : string;
  signon : Tdatetime;
begin
 who := GetFirstToken(Data);
 idle := GetNextToken;
 signon := UnixToDateTime(StrToInt(GetNextToken)); 
 if assigned(FOnWhoIS) then FOnWhoIS(format('%s has been idle %s , Signed on %s',
 [who,idle,FormatDateTime('dddd, mmmm d ,yyyy  hh:mm AM/PM',SignOn)]));
end;

procedure TXiRC.ProcessNick(Nick, Address, Content: string);
begin
  if Content[1] = ':' then
    delete(Content, 1, 1);
  if Nick = CurrentNick then
    CurrentNick := Content;
  if assigned(FOnNick) then
    FOnNick(Nick, Address, Content);
end;

procedure TXiRC.ProcessKill(Nick, Address, Content: string);
var
  Victium, tmp, tmp2: string;

begin
  Victium := GetFirstToken(Content);
  tmp := GetNextToken;
  tmp2 := GetRemainingTokens;

  if Assigned(FOnKill) then
    FOnKill(Nick, victium, tmp2);
end;

procedure TXiRC.ProcessNotice(Nick, Address, Content: string);
var
  dest, tmp, tmp2: string;
begin
  if Nick = '' then
  begin
    tmp := GetFirstToken(content);
    tmp2 := GetRemainingTokens;
    if tmp2[1] = ':' then
      delete(tmp2, 1, 1);
    if assigned(FServerMsg) then
      FServerMsg(Tmp2);
  end
  else
  begin
    dest := GetFirstToken(Content);
    Content := GetRemainingTokens;
    if Content[1] = ':' then
      Delete(Content, 1, 1);
    if assigned(FNotice) then
      FNotice(Nick, Dest, Content);
  end;
end;

procedure TXiRC.ProcessJoin(Nick, Address, Content: string);
begin
  if Content[1] = ':' then
    delete(Content, 1, 1);
  if assigned(FOnJoin) then
    FOnJoin(Nick, Address, Content);
end;

procedure TXiRC.ProcessKick(Nick, Address, Content: string);
var
  Channel, Person, Reason: string;
begin
  if Content[1] = ':' then
    delete(Content, 1, 1);
  Channel := GetFirstToken(Content);
  Person := GetNextToken;
  Reason := GetRemainingTokens;
  if Reason[1] = ':' then
    delete(Reason, 1, 1);
  if assigned(FOnKick) then
    FOnKick(Nick, Address, CHannel, Person, Reason);
end;

procedure TXiRC.ProcessPart(Nick, Address, Content: string);
var
  Channel, PartMsg: string;
begin
  if Content[1] = ':' then
    delete(Content, 1, 1);
  Channel := GetFirstToken(Content);
  PartMsg := GetRemainingTokens;
  if PartMsg <> '' then
    if (PartMsg[1] = ':') then
      delete(PartMsg, 1, 1);
  if assigned(FOnPart) then
    FOnPart(Nick, Address, Channel, PartMsg);
end;

procedure TXiRC.ProcessInvite(Nick, Address, Content: string);
var
  dest, chan: string;
begin
  dest := GetFirstToken(Content);
  Chan := GetRemainingTokens;
  if Chan[1] = ':' then
    delete(chan, 1, 1);
  if assigned(FOnINvite) then
    FOnInvite(Nick, Address, Chan);
end;

procedure TXiRC.ProcessMode(Nick, Address, Content: string);
var
  modes, Chan: string;
begin
  Chan := GetFirstToken(Content);
  Modes := GetRemainingTokens;
  if Chan[1] = '#' then
  begin
    if assigned(FOnCHannelMode) then
      FOnChannelMode(Nick, Chan, Modes);
  end
  else
  begin
    if modes[1] = ':' then
      delete(modes, 1, 1);
    if assigned(FOnUserMode) then
      FOnUserMode(Modes);
  end;
end;

procedure TXiRC.ProcessNames(RawData: string);
var
  Tmp, Tmp2, Tmp3: string;
begin
  tmp := GetFirstToken(RawData);
  tmp2 := GetNextToken;
  tmp3 := GetRemainingTokens;
  if tmp3[1] = ':' then
    delete(tmp3, 1, 1);
  if assigned(FOnNames) then
    FOnNames(tmp2, tmp3);
end;

procedure TXiRC.ProcessNamesEnd(Data: string);
var
  chan, Content: string;
begin
  chan := GetFirstToken(Data);
  Content := GetRemainingTokens;
  if COntent[1] = ':' then
    delete(Content, 1, 1);
  if Assigned(FOnNamesEnd) then
    FOnNamesEnd(Chan, Data);
end;

procedure TXiRC.ProcessQuit(Nick, Address, Content: string);
begin
  if Content[1] = ':' then
    delete(Content, 1, 1);
  if assigned(FOnQuit) then
    FOnQuit(Nick, Address, Content);
end;


procedure TXiRC.ProcessChannelModeIs(Data : string);
var
Chan,Modes : string;
begin
  Chan := GetFirstToken(Data);
  Modes := GetRemainingTokens;
  if assigned(FChanModeIs) then FChanModeIs(Chan,Modes);
end;

/////////////////////////////////////////////////////////
// TReplies                                            //
/////////////////////////////////////////////////////////

constructor TReplies.Create;
begin
  inherited Create;
  FFinger := '';
  FVersion := '';
  FUserInfo := '';
  FClientInfo := '';
end;

procedure TReplies.Assign(Source: TPersistent);
begin
  if Source is TReplies then
  begin
    FFinger := TReplies(Source).Finger;
    FVersion := TReplies(Source).Version;
    FUserInfo := TReplies(Source).UserInfo;
    FClientInfo := TReplies(Source).ClientInfo;
  end;
end;

/////////////////////////////////////////////////////////
// TUser                                               //
/////////////////////////////////////////////////////////

constructor TUser.Create;
begin
  inherited Create;

  FNick := '';
  FAltNick := '';
  FPassword := '';
  FUserName := '';
  FEmail := '';
end;

procedure TUser.Assign(Source: TPersistent);
begin
  if Source is TUser then
  begin
    FNick := TUser(Source).Nick;
    FAltNick := TUser(Source).AltNick;
    FPassword := TUser(Source).Password;
    FUserName := TUser(Source).UserName;
    FEmail := TUser(Source).Email;
  end;
end;

procedure Register;
begin
  RegisterComponents('Irc', [TXiRC]);
end;

end.
