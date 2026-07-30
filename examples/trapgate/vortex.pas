unit vortex;
{
  Allabagitta Soft Presents.
  TVortex v2.8.5 by joepezT

  http://vortex.berzerk.net

  IRC: joepezT @ undernet :  #Delphi
  ICQ: 340148, 3941292
  Email: Gothic(a)bluezone.no (Primary mail)  - (a) = @
         vortex(a)berzerk.net (questions regarding this component)

  TVortex is an OpenSource IRC component by joepezt
  Feel free to use it on whatever you want, send me bug fixes & suggestions
  and or just help me develop it.

  note: I have changed alot of the event name to more logical names
  also I am in the work of adding "before" events.

  hope it wont make much problems for you ;)
  many options is now available under

  vortex.IrcOptions.ircnick
  vortex.ctcpoptions.versionreply... etc etc

  If you plan to use it in your own application,
  please write somewhere that you use vortex, and link to my pages..
  and i also want a copy and test it :)
  you might also put a "Powered by Vortex" on your project ;)

  I would also like to have your projects posted on my page, eighter the
  whole compiled project and or a link to it. or even a small description
  of it.

  If anyone of you find and fixes a bug, please send them back to me
  vortex@berzerk.net. just use "vortex" as subject

  IRC Related information
  RFC1459 : http://vortex.berzerk.net/rfc1459.html

  Last minute news:
  There might be a bug if you get kicked, which somehow stops you from parsing the strings,
  This might also reside in the topic area..
  other bug in the topic is the first time you join you seem to get the nick and timestamp. 

  _____________________________________________________
  these peoples have contributed to the Vortex Project:
  (In no particular order)

  Guano,
  Cubud   : I could not start on this if it werent for you ;)
            specially the component writings.
  Acryl   : See annotations marked with "Acryl"
  WolfMan : some suggestions,
  + some other people i do not have the names from.

}

{$D+}

interface
 uses
 {$IFDEF WIN32}
  Classes, Controls, Windows, wsocket, SysUtils, dialogs, VortexChannels;
 {$ELSE}
 { Linux Kylix }
  Classes, IcsSocket, SysUtils, VortexChannels;
 {$ENDIF}


  type
    TjpNetEvents = class(Tobject)
    { commands which will be triggered from the server }
  end;
    TStartEvent      = procedure of object;
    TError           = procedure (Sender : Tobject; Error : word) of object;
    TBGException     = procedure (Sender : Tobject; E : Exception; Var CanClose : boolean) of Object;
    TServerError     = procedure (ErrorString : string) of object;
    TServerMsg       = procedure (Command : string) of object;

  type
    TjpAfterEvents = class(Tobject)
    { commands which will be triggered AFTER you send them OR from the server }
  end;
    TAfterServerPing  = procedure of object;
    TAfterDisconnect  = procedure of object;
    TAfterConnect     = procedure of object;
    TAfterNickChanged = procedure (Oldnick, Newnick : string) of object; { me }
    TAfterNickChange  = procedure (Oldnick, Newnick : string) of object; { not me }
    TAfterNotify      = procedure (NotifyUsers : string)      of object;
    TAfterTopic       = procedure (ChannelName,Nickname,Topic : string) of object;
    TAfterKicked      = procedure (Nickname, Channel, Reason  : string) of object;
    TAfterJoin        = procedure (Nickname, Hostname,Channel : string) of object;
    TAfterJoined      = procedure (Channelname : string) of object;
    TAfterParted      = procedure (Channelname : string) of object;
    TAfterPart        = procedure (Nickname,Hostname,Channelname,Reason : string) of object;
    TAfterChannelMsg  = procedure (Channelname,Content,Nickname, Ident, Mask : string) of object;
    TAfterPrivmsg     = procedure (Nickname, Ident, Mask, Content : string) of object;
    TAfterCtcp        = procedure (Nickname, Command, Destination : string) of object; // Acryl : Modified ( see DataReceive-Handler for explanation )
    TAfterMode        = procedure (Nickname, Destination, Mode : string)    of object;
    TAfterUserKick    = procedure (KickedUser, Kicker, Channel, Reason : string) of object;
    TAfterIrcAction   = procedure (NickName, Content, Destination : string)      of Object; // Acryl : added
    TAfterNickInUse   = procedure (Nickname : string)      of object;
    TAfterNoSuchNick  = procedure (Value : string)         of object;
    TAfterNotice      = procedure (Nick, Content : string) of object;
    TAfterInvited     = procedure (NickName, Channel : string) of ObjecT;       // Acryl : added
    TAfterUserQuit    = procedure (Nickname,Reason : string)   of object;
    TAfterWho         = procedure (Channel, Nickname,Username,Hostname, Name, Servername,status,other : string; EndOfWho : boolean) of object;
    TAfterChannelList = procedure (ChannelName, Topic : string; Users : integer; EndOfList : boolean) of object;
    TAfterNames       = procedure (Commanicks, Channel : string; endofnames : boolean)                of object;
    TAfterWhois       = procedure (Info : string; EndOfWhois : boolean)                               of object;
    TAfterMotd        = procedure (Line : string; EndOfMotd : boolean) of object;

  type
    TjpBeforeSend = class(Tobject)
    { commands which will be triggered BEFORE you send them to the server }
  end;
    TBeforeDisconnect = procedure of object;
    TBeforeConnect    = procedure (Ircserver,Ircport : string);
    TBeforeQuit       = procedure (Reason : string) of object;
    TBeforeQuote      = procedure (raw : string) of object;
    TBeforeJoin       = procedure (Channelname : string) of object;
    TBeforePart       = procedure (Channelname : string) of object;
    TBeforeMode       = procedure (Nickname, Commands, parameters : string) of object;
    TBeforeTopic      = procedure (Channelname, Topic   : string) of object;
    TBeforePrivmsg    = procedure (Destination, Content : string) of object;
    TBeforeNotice     = procedure (Destination, Content : string) of object;
    TBeforeNickChange = procedure (Oldnick, Newnick     : string) of object;

  type
    TjpDirectClientEvents = class(Tobject)
    { Used for DCC handling
      Sending is not complete yet }
  end;
    TDccChatIncoming = procedure (Nickname, Port,Address : string) of object;
    TDccChatOutgoing = procedure (Nickname, Port,Address : string) of object;
    TDccSendResume   = procedure (Nickname, Filename, Port, Position : string) of object;
    TDccGetResume    = procedure (Nickname, Filename, Port, Position : string) of object;
    TDccSend         = procedure (Nickname, Port,Address, Filename, Filesize : string) of object;
    TDccGet          = procedure (Nickname, Port,Address, Filename, Filesize : string) of object;

  { IdentD/Auth server } 
  type
    TAuthOptions = class(TPersistent)
  private
    FSystem  : string;
    FIdent   : string;
    FAnswer  : boolean;
    FEnabled : boolean;
    {$IFDEF WIN32}
    FAuthServer : TWSocket;
    {$ELSE}
    FAuthServer : TIcsSocket;
    {$ENDIF}
  protected
    procedure OnIdentDserverSessionAvailable(Sender: TObject; Error: Word);
  public
    procedure Assign(Source : TPersistent); override;
    procedure StartAuth;
    procedure StopAuth;
  published
    property System  : string  read FSystem  write FSystem;
    property Ident   : string  read FIdent   write FIdent;
    property UseAuth : Boolean read FEnabled write FEnabled; { to start the service }
    property Enabled : Boolean read FAnswer  write FAnswer;  { to answer on requests. }
  end;
    TAuthConnect = procedure (host : string) of object;

  { some component expanded options }
  type
    TIrcOptions = class(TPersistent)
  private
    FServerHost  : string;
    FServerPort  : string;
    FUserNick    : string;
    FUserName    : string;
    FUserIdent   : string;
    FQuitMessage : string;
  public
    procedure Assign(Source : TPersistent); override;
  published
    property GetServerHost : string read FServerHost;
    property GetServerPort : string read FServerPort;
    property GetUserNick   : string read FUserNick;
    property GetUserName   : string read FUserName;
    property GetUserIdent  : string read FUserIdent;
    property SetServerHost : string write FServerHost;
    property SetServerPort : string write FServerPort;
    property SetUserNick   : string write FUserNick;
    property SetUserName   : string write FUserName;
    property SetUserIdent  : string write FUserIdent;
    property ServerHost    : string read FServerHost write FServerHost;
    property ServerPort    : string read FServerPort write FServerPort;
    property UserName      : string read FUserName   write FUserName;
    property UserIdent     : string read FUserIdent  write FUserIdent;
    property MyNick        : string read FUserNick   write FUserNick;
    property DefaultQuitMessage : string read FQuitMessage write FQuitMessage;
  end;

  type
    TCtcpOptions = class(TPersistent)
  private
    FVersionReply : string;
    FTimeReply    : string;
    FFingerReply  : string;
    FPingReply    : string;
    FClientInfo   : string;
    {FUnknownReply : string;}
    FReplyToPing  : boolean;
    FReplyToCtcp  : boolean; { if we decide not to reply at all }
  public
    procedure Assign(Source : TPersistent); override;
  published
    property GetVersionInfo : string read  FVersionReply;
    property GetTimeReply   : string read  FTimeReply;
    property GetFingerReply : string read  FFingerReply;
    property GetPingReply   : string read  FPingReply;
    property VersionReply   : string read  FVersionReply write FVersionReply;
    property TimeReply      : string read  FTimeReply    write FTimeReply;
    property FingerReply    : string read  FFingerReply  write FFingerReply;
    property PingReply      : string read  FPingReply    write FPingReply;
    property ReplyOnPing    : Boolean read FReplyToPing write FReplyToPing;
    property AnswerCtcps    : Boolean read FReplyToCtcp write FReplyToCtcp;
  end;

  type
    TSocksOptions = class(TPersistent)
  private
    FSocksLevel    : string;
    FSocksPort     : string;
    FSocksServer   : string;
    FSocksPassword : string;
    FSocksUserCode : string;
    FSocksAuthentication : TSocksAuthentication;
  public
  published
    property SocksPort      : string read FSocksPort     write FSocksPort;
    property SocksServer    : string read FSocksServer   write FSocksServer;
    property SocksPassword  : string read FSocksPassword write FSocksPassword;
    property SocksLevel     : string read FSocksLevel    write FSocksLevel;
    property SocksUserCode  : string  read FSocksUserCode write FSocksUserCOde;
    property SocksAuthentication : TSocksAuthentication read FSocksAuthentication write FSocksAuthentication;
  end;

  { Main component }
  Type
    TVortex = class(TComponent)
  private
    { expanded properties }
    FIrcOptions   : TIrcOptions;
    FCtcpOptions  : TCtcpOptions;
    FSocksOptions : TSocksOptions;
    FAuthOptions  : TAuthOptions;
    { some variuables }
    FCurrServer  : string;  // Which server are we connected to ?
    FConnected   : boolean; // Am I connected (?)
    {$IFDEF WIN32}
    FClient      : TwSocket;
    {$ELSE}
    FClient      : TIcsSocket;
    {$ENDIF}

    { DCC Related events }
    FDccGet            : TDCCGet;
    FDccGetResume      : TDCCGetResume;
    FDccSend           : TDCCGet;
    FDccSendResume     : TDCCGetResume;
    FDccChatIncoming   : TDccChatIncoming;
    FDccChatOutgoing   : TDccChatIncoming;
    { All below is IRC Related and triggered before }
    FBeforeQuote       : TBeforeQuote;
    FBeforeConnect     : TBeforeConnect;
    FBeforeDisconnect  : TBeforeDisconnect;
    FBeforeQuit        : TBeforeQuit;
    FBeforeJoin        : TBeforeJoin;
    FBeforeTopic       : TBeforeTopic;
    FBeforePart        : TBeforePart;
    FBeforePrivmsg     : TBeforePrivmsg;
    FBeforeNickChange  : TBeforeNickChange;
    FBeforeNotice      : TBeforeNotice;
    FBeforeMode        : TBeforeMode;
    { All below is IRC Related and triggered after something }
    FAfterNickChanged  : TAfterNickChanged;
    FAfterDisconnect   : TAfterDisconnect;
    FAfterTopic        : TAfterTopic;
    FAfterMode         : TAfterMode;
    FAfterKicked       : TAfterKicked;
    FAfterJoin         : TAfterjoin;
    FAfterParted       : TAfterParted;
    FAfterConnect      : TAfterConnect;
    FAfterChannelMsg   : TAfterChannelMsg;
    FAfterChannelList  : TAfterChannelList;
    FAfterNoSuchNick   : TAfterNoSuchNick;
    FAfterCtcp         : TAfterCtcp;
    FAfterNotify       : TAfterNotify;
    FAfterUserKick     : TAfterUserKick;
    FAfterjoined       : TAfterJoined;
    FAfterServerPing   : TAfterServerPing;
    FAfterNotice       : TAfterNotice;
    FAfterWhois        : TAfterWhois;
    FAfterWho          : TAfterwho;
    FAfterPart         : TAfterPart;
    FAfterNickChange   : TAfterNickChange;
    FAfterUserQuit     : TAfterUserQuit;
    FAfterNickInUse    : TAfterNickInUse;
    FAfterNames        : TAfterNames;
    FAfterPrivMsg      : TAfterPrivMsg;
    FAfterMotd         : TAfterMotd;      { Message of the day }
    FAfterircAction    : TAfterIrcAction;
    FAfterInvited      : TAfterInvited;
    FError             : TError;
    FServerMsg         : TServerMsg;
    FServerError       : TServerError;
    FStart             : TStartEvent;
    FBgException       : TBGException;
    { these are executed when you join part got kicked... }
    procedure SetIRCMode   (destination, command, parameters: string);
    procedure Parted    (Nickname, HostName, UserName, ChannelName, Reason : string);
    procedure Joined    (Nickname, ChannelName,HostName   : string);
    procedure Kicked    (Victim, BOFH, Channel, Reason : string);
    procedure Quited    (Nickname, user, host, reason  : string);
    procedure NamesChan    (ChannelName, CommaNicks    : string; EndOfNames : boolean);
    procedure NickChange   (OldNick, Newnick           : string);
    procedure Messages     (Line, nick, host, user, destination, Content : string);
    procedure CTCPMessage  (Line, nick, host, user, destination, Content : string);
    procedure ChannelTopic (ChannelName, UserName, Topic  : string);
    procedure ChannelTopicSetBy (ChannelName, Nickname  : string);
    { Mask is always the param (format: Nickname!Ident@some.host.com) }
    function GetNickFromMask     (S : string) : string;  // e.g. Vortex2345
    function GetHostmaskFromMask (S : string) : string;  // e.g. vortex@dialup23123.Dubplates.org
    function GetIdentFromMask    (S : string) : string;  // e.g. My Vortex name
    function GetHostFromMask     (S : string) : string;
    procedure SetIrcOptions(const Value: TIrcOptions);
    procedure SetCtcpOptions(const Value: TCtcpOptions);
    procedure SetSocksOptions(const Value: TSocksOptions);
    procedure SetAuthOptions(const Value: TAuthOptions);
    procedure SetupSocket(ConnectToServer : boolean);
  protected
    procedure OnConnectDataAvailable(Sender: TObject; Error: Word);
    procedure OnSocketDataAvailable(Sender: TObject; Error: Word);
    procedure OnSocketClosed(Sender: TObject; Error: Word);
    procedure OnSocketConnected(Sender: TObject; Error: Word);
    procedure OnVortexIRCError (Sender: TObject);
    procedure OnVortexBgException(Sender: TObject; E: Exception;  var CanClose: boolean);
  public
    FChannels   : Tlist; { A List containing our channels.. }
    constructor Create(AOwner : TComponent); override;
    destructor  Destroy; override;
    procedure   Loaded; override;

    { first thing sent to IRC when you connect. should not be used by user..}
    procedure genericparser (socketmessage : string);
    function User(nick, user, ConnectMethod, realname : string) : string;
    function Between(S,Start,stop:string)  : string;
    function LongIP(IP : string)           : string; { Acryl : Modified }
    function ShortIP(const S: string)      : string; { Acryl : Modified }
    { user commands goes here...  }
    procedure InitDCCsendResume(nick, port, Position : string);
    procedure InitDCCchat      (nick, port, address  : string);
    procedure InitDCCsend      (nick, port, address, filename, filesize : string);
    procedure InitDCCGet(nick, port,address, filename, filesize : string);
    procedure InitDCCGetResume(nick, port, Position : string);
    { Raw Commands (quote and raw is the same.. ) }
    procedure Quote     (_Quote : string);
    procedure Raw       (_raw : string);
    procedure NoticeChannelOps (DestinationChannel,Content : string);
    procedure Notice    (destination, content : string);
    procedure Say       (destination, content : string);
    procedure SendCTCP  (nick, command : string);
    procedure CtcpReply (nick, command : string);
    procedure Join      (channel,key    : string);
    procedure Part      (channel,reason : string);
    procedure Quit      (reason         : string);
    procedure Kick    (Victim, channel, Reason : string);
    procedure Ban     (nick, mask, channel : string);
    procedure Op      (nick, channel       : string);
    procedure Deop    (nick, channel       : string);
    procedure Voice   (nick, channel       : string);
    procedure DeVoice (nick, channel       : string);
    procedure Topic   (channel, Topic      : string);
    { Request change nick on IRC }
    procedure Nick(newnick : string);
    { Info commands...}
    procedure ListChannels (max,min : integer);
    procedure who          (mask : string);
    procedure whowas       (nick : string);
    procedure whois        (nick,server : string);
    { Connect is used by the Server procedure.. }
    procedure connect;
    procedure Server      (server,ircport : string);
    procedure Disconnect  (force          : boolean; reason : string);
    { Misc commands }
    procedure SetCurrentServer (Value    : string);
    procedure SetVersionInfo   (Info     : string);
    procedure SetMyUserName    (Value    : string);
    procedure SetIRCPort       (Value    : string);
    procedure SetIRCName       (Value    : string);
    procedure SetMyNick        (Nickname : string);  // This one does NOT change your nick on IRC
    function LocalIP           (num      : byte)   : string;
    function IsNumeric         (Value    : string) :boolean;
    { Channel Related   }
    procedure ClearUsersInChannel  (value    : string);
    function FindChannelID         (AChannel : string) : integer;
    function CountUsersFromChannel (Value    : string) : integer;
    function GetChannelTopic       (value    : string) : string;
    function GetTopicSetBy         (value    : string) : string;
    function GetUsersFromChannel   (Value    : string) : string;
  published
    property GetCurrentServer : string Read FCurrServer;
    property IsConnected    : boolean Read FConnected;
    { sub items }
    property IrcOptions     : TIrcOptions   read FIrcOptions write SetIrcOptions;
    property CtcpOptions    : TCtcpOptions  read FCtcpOptions write SetCtcpOptions;
    property SocksOptions   : TSocksOptions read FSocksOptions write SetSocksOptions;
    property AuthOptions    : TAuthOptions  read FAuthOptions write SetAuthOptions;
    { User-defined event handlers  }
    property BeforeQuote         : TBeforeQuote      read FBeforeQuote         write FBeforeQuote;
    property BeforeDisconnect    : TBeforeDisconnect read FBeforeDisconnect    write FBeforeDisconnect;
    property BeforeQuit          : TBeforeQuit       read FBeforeQuit          write FBeforeQuit;
    property BeforeJoin          : TBeforeJoin       read FBeforeJoin          write FBeforeJoin;
    property BeforeTopic         : TBeforeTopic      read FBeforeTopic         write FBeforeTopic;
    property BeforePart          : TBeforePart       read FBeforePart          write FBeforePart;
    property BeforePrivateMessage: TBeforePrivmsg    read FBeforePrivmsg       write FBeforePrivmsg;
    property BeforeNickChange    : TBeforeNickChange read FBeforeNickChange    write FBeforeNickChange;
    property BeforeNotice        : TBeforeNotice     read FBeforeNotice        write FBeforeNotice;
    property BeforeMode          : TBeforeMode       read FBeforeMode          write FBeforeMode;
    property AfterPrivateMessage : TAfterprivMsg     read FAfterPrivmsg        write FAfterPrivmsg;
    property AfterUserJoin       : TAfterJoin        read FAfterJoin           write FAfterJoin;
    property AfterJoined         : TAfterjoined      read FAfterJoined         write FAfterJoined;
    property AfterUserPart       : TAfterPart        read FAfterPart           write FAfterPart;
    property AfterParted         : TAfterParted      read FAfterParted         write FAfterParted;
    property AfterTopic          : TAfterTopic       read FAfterTopic          write FAfterTopic;
    property AfterUserQuit       : TAfterUserQuit    read FAfterUserQuit       write FAfterUserQuit;
    property AfterUserKick       : TAfterUserKick    read FAfterUserKick       write FAfterUserKick;
    property AfterKicked         : TAfterKicked      read FAfterKicked         write FAfterKicked;
    property AfterCtcp           : TAfterCtcp        read FAfterCtcp           write FAfterCtcp;
    property AfterUserNickChange : TAfterNickChange  read FAfterNickChange     write FAfterNickChange;
    property AfterNickChanged    : TAfterNickChanged read FAfterNickChanged    write FAfterNickChanged;
    property AfterStarted        : TStartEvent       read FStart               write FStart;
    property AfterAction         : TAfterIrcAction   read FAfterIrcAction      write FAfterIrcAction; {Acryl : added}
    property AfterInvited        : TAfterInvited     read FAfterInvited        write FAfterInvited;    {Acryl : added}
    property AfterServerPing     : TAfterServerPing  read FAfterServerPing     write FAfterServerPing;
    property OnNoSuchNickChannel : TAfterNoSuchNick  read FAfterNoSuchNick     write FAfterNoSuchNick;
    property OnChannelMessage    : TAfterChannelmsg  read FAfterChannelMsg     write FAfterChannelMsg;
    property OnQuoteServer       : TServerMsg        read FServerMsg           write FServerMsg;
    property OnServerError       : TServerError      read FServerError         write FServerError;
    property OnNickInUse         : TAfterNickInUse   read FAfterNickInUse      write FAfterNickInUse;
    property OnNotice            : TAfterNotice      read FAfterNotice         write FAfterNotice;
    property OnNotify            : TAfterNotify      read FAfterNotify         write FAfterNotify;
    property OnNames             : TAfterNames       read FAfterNames          write FAfterNames;
    property OnWhois             : TAfterWhois       read FAfterWhois          write FAfterWhois;
    property OnMOTD              : TAfterMotd        read FAfterMotd           write FAfterMotd;
    property OnList              : TAfterChannelList read FAfterChannelList    write FAfterChannelList;
    property OnMode              : TAfterMode        read FAfterMode           write FAfterMode;
    property OnWho               : TAfterWho         read FAfterWho            write FAfterWho;
    { DCC related events, you can use them with my other components }
    property OnDCCFileReceive    : TDCCGet          read FDCCGet               write FDCCGet;
    property OnDCCFileResume     : TDCCGetResume    read FDCCGetResume         write FDCCGetResume;
    property OnDCCChat           : TDccChatIncoming read FDccChatIncoming      write FDccChatIncoming;
    { Socket related stuff }
    property OnDisconnect        : TAfterDisconnect Read FAfterDisconnect      write FAfterDisconnect;
    property OnConnect           : TAfterConnect    Read FAfterConnect         write FAfterConnect;
    Property OnError             : Terror           Read FError                write FError;
    Property OnBgException       : TBgException     Read FBGException          write FBGException;
end;

procedure Register;

implementation

////////////////////////////////////////////////////////////////////////////////
////////////////////////// Misc constants //////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

Const
  MWG_VERSION_MAJOR     = '2';
  MWG_VERSION_MINOR     = '8';
  MWG_VERSION_TAG       = 'Vortex IRC component for Delphi';
  CrLf                  = #13#10;
  ChannelPrefix = '#!&+'; { <- # = Normal channels  ! = Secure channels (?)
                               & = Local channels   + = Mode less channels }

  Commands: Array [0..33] of integer =
  (324,329,                     // get MODE
   301,311,312,313,317,318,319, // Whois return codes
   401,433,303,                 // Nickname in use, IsON
   315,352,                     // who...
   332,333,                     // topic set
   353,366,                     // names / end of.
   321,322,323,324,             // Channel Listing
   250,251,252,253,254,255,     // Motd stuff
   265,266,373,372,375,376      // ----"----
   );


{
// uncomment this if you are using Delphi 4 or older)
procedure FreeAndNil(var Value: TObject);
begin
  Value.Free;
  Value := nil;
end;
}

{ Match the different IRC Numeric commands }
function match (cmd: string) : integer;
var
i : integer;
begin
  i := 0;
  while i <= High(Commands) do
  begin
    if Cmd = inttostr(Commands[i]) then
    begin
      Result := commands[i];
      exit;
    end;
    Inc(I);
  end;
  result := -1;
end;

procedure Register;
begin
  RegisterComponents('joepezT', [Tvortex]);
end;


{
  ------------------------------------------------------------------
                        Constructor / Destructor
  ------------------------------------------------------------------
}

{ TVortex }

function TVortex.IsNumeric( Value:String ):boolean;
var
    Code : integer;
    Tmp  : integer;
begin
  { check if a value really is a value }
  Val ( Value, tmp, Code );
  Result := Code = 0;
end;

procedure Tvortex.SetupSocket(ConnectToServer : boolean);
begin
  if assigned(FClient) then
     Fclient.Free;
  {$IFDEF WIN32} FClient := TWSocket.Create(Self);
  {$ELSE}        FClient := TIcsSocket.Create(Self);{$ENDIF}
  with FIrcOptions do
  With FSocksOptions do
  With FClient do
  Begin
    if assigned(FBeforeConnect) then
       FBeforeConnect(GetServerHost, GetServerPort);

    if GetServerPort       = '' then SetServerPort := '6667';
    if trim(GetServerHost) = '' then exit; { exit if there is no address specified }
    OnDataAvailable    := OnConnectDataAvailable;
    OnSessionClosed    := OnSocketClosed;
    OnError            := OnvortexIRCError;
    OnBgException      := OnVortexBgException;
    OnSessionConnected := OnSocketConnected;

    LineEdit := False;
    LineEcho := False;
    LineMode := True;
    LineEnd  := #13#10;
    Proto := 'tcp';
    Port  := FIrcOptions.GetServerPort;
    Addr  := FIrcOptions.GetServerHost;

    SocksPort     := FsocksPort;
    SocksServer   := FSocksServer;
    Sockspassword := FSocksPassword;
    SocksLevel    := FSocksLevel;
    SocksUserCode := FSocksUserCode;
    {SocksAuthentication := TSocksAuthentication;}

    if ConnectToServer then
    Connect;
  end;
end;

Constructor Tvortex.Create(AOwner: TComponent);
Begin
  Inherited Create(Aowner);
  FIrcOptions   := TIrcOptions.Create;
  FCtcpOptions  := TCtcpOptions.Create;
  FSocksOptions := TSocksOptions.Create;
  FAuthOptions  := TAuthOptions.Create;
  with FIrcOptions do
  with FAuthOptions do
  with FCtcpOptions do
  begin
    if GetServerHost = '' then SetServerHost := 'stockholm.se.eu.undernet.org';
    if GetServerPort = '' then SetServerPort := '6667';
    if GetUserName   = '' then SetUserName   := 'IRC Component';
    if GetUserIdent  = '' then SetUserIdent  := 'Vortex';
    if GetUserNick   = '' then SetUserNick   := 'Vortex' + inttostr(random(999));
    if FSystem       = '' then FSystem       := 'UNIX';
    if FIdent        = '' then FSystem       := 'Vortex';
    if FFingerReply  = '' then FFingerReply  := 'FooBar';
    if FClientInfo   = '' then FClientInfo   := format('CLIENTINFO Vortex engine, version: %s %s %s',[MWG_VERSION_MAJOR,MWG_VERSION_MINOR,MWG_VERSION_TAG]);
  end;

  SetVersionInfo(format('Vortex - v%s.%s.',[MWG_VERSION_MAJOR,MWG_VERSION_MINOR]));


  If not (csDesigning in ComponentState) Then
  Begin
    Fchannels := TList.create;
  {SetupSocket(false);}
  end;
End;

Destructor Tvortex.Destroy;
Begin
  If not (csDesigning in ComponentState) Then
  Begin
    FreeAndNil(FClient);
    FreeAndNil(Fchannels);
    with FAuthOptions do
    begin
      FreeAndNil(FAuthServer);

    end;
  End;

  inherited Destroy();
End;


procedure Tvortex.Loaded();
Begin
  Inherited Loaded();
  If not (csDesigning in ComponentState) Then
  begin
    { if we decide to use identd server }
    With FAuthOptions do
    begin
      if FEnabled = true then
      StartAuth;
    end;

  If Assigned(FStart) Then FStart();
  end;
End;

////////////////////////////////////////////////////////////////////////////////
// String manipulation functions
// Great string manipulation which i got from Wolfman :)
////////////////////////////////////////////////////////////////////////////////

function Tvortex.Between(S,Start,stop:string):string;
Var      P1,P2:integer;
Begin
  P1:=Pos(start,s);
  P2:=pos(stop,s);
  Result:=copy(s,p1+1,p2-p1-1);
End;

function Tvortex.shortIP(const S: string): string;
Var
  IP         : int64;
  A, B, C, D : Byte;
Begin
  {
   ShortIP
   Example: 3232235777 -> 192.168.1.1
  }
  IP := StrToInt64(S);
  A  := (IP and $FF000000) shr 24;
  B  := (IP and $00FF0000) shr 16;
  C  := (IP and $0000FF00) shr 8;
  D  := (IP and $000000FF);
  Result := Format('%d.%d.%d.%d', [A, B, C, D]);
End;

{ Long IP converted by joepezt }
function Tvortex.LongIP(IP : string) : string;
var
IPaddr   : array[1..4] of integer;
temp     : string;
res      : Longword;
i        : integer;

begin
  temp := ip;
  temp := temp + '.';
  for i := 1 to 4 do
  begin
    try
      ipaddr[i] := strtoint(copy(temp,1,pos('.',temp) - 1));
      delete(temp,1,pos('.',temp));
      if ipaddr[i] > 255 then raise exception.Create('');
    except
     result := 'Invalid IP address.';
     exit;
    end;
  end;

  res := (ipaddr[1] * $FFFFFF) + ipaddr[1] + (ipaddr[2] * $FFFF)   + ipaddr[2] + (ipaddr[3] * $FF)     + ipaddr[3] + (ipaddr[4]);
  result := format('%u',[res]);
end;

////////////////////////////////////////////////////////////////////////////////
// Command parsers by Acryl
////////////////////////////////////////////////////////////////////////////////
function  Tvortex.GetNickFromMask(S : string) : string;
Var
 C         : integer;
 TmpString : string;
Begin
  S := Trim(S);
  If (Length(S) = 0) Then Exit;
  TmpString := '';
  For C:=1 To Length(S) Do
  Begin
    If (S[C] = '!') Then break;
    TmpString := TmpString + S[C];
  End;
  Result := TmpString;
end;

function  Tvortex.GetIdentFromMask(S : string) : string;
Var
  C       : integer;
  Copying : boolean;
  TmpString : string;
Begin
  S := Trim(S);
  If (Length(S) = 0) Then Exit;
  TmpString := '';
  Copying    := False;
  For C:=1 To Length(S) Do
  Begin
    If (S[C] = '@') Then break;
    If (S[C] = '!') Then Copying := True
    else If (Copying) Then TmpString := TmpString + S[C];
  End;
  Result := TmpString;
end;

function  Tvortex.GetHostFromMask(S : string) : string;
Var
 C       : integer;
 Copying : boolean;
 TmpString : string;
Begin
  S := Trim(S);
  If (Length(S) = 0) Then exit;
  TmpString := '';
  Copying    := False;
  For C:=1 To Length(S) Do
  Begin
    If (S[C] = '@') Then Copying := True
    else If (Copying) Then TmpString := TmpString + S[C];
  End;
  Result := TmpString;
end;

function  Tvortex.GetHostmaskFromMask(S : string) : string;
Var
  C       : integer;
  Copying : boolean;
  TmpString : string;

Begin
  S := Trim(S);
  If (Length(S) = 0) Then Exit;
  TmpString := '';
  Copying    := False;
  For C:=1 To Length(S) Do
  Begin
    If (S[C] = '!') Then Copying := True
    else If (Copying) Then TmpString := TmpString + S[C];
  End;
  Result := TmpString;
end;


{
-------------------------------------------------------------------
                             User commands
-------------------------------------------------------------------
}
procedure Tvortex.Quote(_quote : string);
Begin
  if assigned(Fclient) then
  FClient.sendstr(_quote + crlf);
End;

procedure Tvortex.Raw(_raw : string);
Begin
  if assigned(FBeforeQuote) then
  Quote(_raw + crlf);
End;

procedure Tvortex.Say(destination, content : string);
Begin
  if Assigned(FBeforePrivmsg) then
     FBeforePrivmsg(destination, content);
  Quote(format('PRIVMSG %s :%s',[destination,content]));
End;

procedure Tvortex.Notice(destination, content : string);
begin
 if assigned(FBeforeNotice) then
    FBeforeNotice(destination,content);

  Quote(format('NOTICE %s :%s',[destination,content]));
end;

procedure Tvortex.NoticeChannelOps(DestinationChannel,
  Content: string);
begin
  if assigned(FBeforeNotice) then
     FBeforeNotice(destinationChannel,content);
  { sends this notice to channel ops  }
  Quote(format('WALLCHOPS %s :%s',[destinationChannel,content]));
end;

procedure Tvortex.whois(nick, server : string);
begin
  if server <> '' then
  Quote(format('WHOIS %s %s',[nick,server]))
  else Quote(format('WHOIS %s',[nick]))
end;

procedure TVortex.listChannels (max,min : integer);
begin
 { LIST <3,>1,C<10,T>0  ; 2 users, younger than 10 min., topic set.
   probably a better way to do this  }
  if min <0 then
  if max >0 then
  begin
    Quote(format('List <%d,>%d',[max,min]));
    exit
  end;
  if min >0 then
  begin
    Quote(format('List >%d',[min]));
    exit
  end;
  if max >0 then
  begin
    Quote(format('List <%d',[max]));
    exit;
  end;
end;

procedure Tvortex.who(mask : string);
begin
  Quote(format('WHO %s',[Mask]))
end;

procedure Tvortex.whowas(nick : string);
begin
  quote(format('WHOWAS %s',[nick]))
end;

procedure Tvortex.Op(nick, channel : string);
begin
  if assigned(FBeforeMode) then
    FBeforeMode(nick,'op',channel);
  Quote(format('MODE %s +oooo %s',[channel,nick]));
end;

procedure Tvortex.Deop(nick, channel : string);
begin
  if assigned(FBeforeMode) then
    FBeforeMode(nick,'deop',channel);
  Quote(format('MODE %s -oooo %s',[channel,nick]));
end;

procedure Tvortex.Voice(nick, channel : string);
begin
  if assigned(FBeforeMode) then
    FBeforeMode(nick,'voice',channel);

   Quote(format('MODE %s +vvvv %s',[channel,nick]));
end;

procedure Tvortex.DeVoice(nick, channel : string);
begin
  if assigned(FBeforeMode) then
    FBeforeMode(nick,'devoice',channel);
  Quote(format('MODE %s -vvvv %s',[channel,nick]));
end;

procedure Tvortex.SetIRCMode(destination, command, parameters : string);
begin
  if assigned(FBeforeMode) then
     FBeforeMode(Destination,Command,Parameters);
  Quote(format('MODE %s %s %s',[destination,command,parameters]));
end;

procedure Tvortex.Ban(nick, mask, channel : string);
begin
{  if assigned(FBeforeMode) then
     FBeforeMode(Destination,Command,Parameters);}
  Quote(format('MODE %s +b %s',[channel,mask]));
end;

procedure Tvortex.Topic(channel, Topic : string);
begin
  if assigned(FBeforeTopic) then
     FBeforeTopic(channel,topic);

  Quote(format('TOPIC %s :%s',[channel,Topic]));
end;

procedure Tvortex.Kick(Victim, channel, Reason : string);
begin
   Quote(format('KICK %s %s :%s',[channel,victim,reason]));
end;

procedure Tvortex.join(channel,key : string);
begin
  if assigned(FBeforeJoin) then
    FBeforeJoin(Channel);

 if key <> '' then
    Quote(format('Join %s :%s',[channel,key]))
    else
    Quote(format('Join %s',[channel]))
end;

procedure Tvortex.connect;
begin
  SetupSocket(true);
end;


procedure Tvortex.InitDCCchat(nick,port,address : string);
var
CustomLongIP : string;

begin
  if port = '' then port := '59';
  if address = '' then customlongip := longip(localip(0))
  else CustomLongIP := longip(address);

  Quote(format('PRIVMSG %s :' + #1 + 'DCC CHAT chat %s %s' + #1,[nick, CustomLongIP,port]));
end;

procedure Tvortex.InitDCCsend(nick, port,Address, filename, filesize : string);
var
CustomLongIP : string;

begin
  if port = '' then port := '59';
  if address = '' then customlongip := longip(localip(0))
  else CustomLongIP := longip(address);

  Quote(format('PRIVMSG %s :' + #1 + 'DCC SEND "%s" %s %s %s' + #1,[nick,filename, CustomLongIP, port, filesize]));
end;

procedure TVortex.InitDCCsendResume(nick, port, Position : string);
begin
  Quote(format('PRIVMSG %s :' + #1 + 'DCC RESUME file.ext %s %s',[nick, port, position]));
end;

procedure Tvortex.Part(channel,reason : string);
begin
  if assigned(FBeforePart) then
  FBeforePart(channel);
  if reason <> '' then
  Quote(format('part %s :%s',[channel,reason]))
  else Quote(format('part %s',[channel]))
end;

procedure Tvortex.Quit(reason : string);
Begin
 { change it to whatever you want  }
  if assigned(FBeforeQuit) then
    FBeforeQuit(reason);
  If (trim(Reason) = '') Then
  Reason := FIrcOptions.DefaultQuitMessage;
  Quote(format('QUIT :%s',[reason]));
End;

procedure Tvortex.SendCTCP(nick, command : string);
Begin
  Quote(format('PRIVMSG %s :%s%s',[nick,#1,command]));
End;

procedure Tvortex.CtcpReply(nick, command : string);
Begin
  Quote(format('NOTICE %s :%s%s%s',[nick,#1,command,#1]));
End;

procedure Tvortex.Disconnect(force : boolean; reason : string);
var
i : integer;
Begin
  if assigned(FBeforeDisconnect) then
      FBeforeDisconnect;
  If (not force) Then Quit(reason)
  Else FClient.close;

  FConnected := False;

  With Fchannels do
  begin
    if assigned(Fchannels) then
    begin
      for i := 0 to count -1 do
      with Tobject(FChannels[i]) as TChannels do
        begin
          DeleteUsers;
          Fchannels[i] := nil;
        end;
        FChannels.Clear;
    end;
      FChannels := TList.create;
  end;

End;

procedure Tvortex.Nick(newnick : string);
Begin
  Quote(format('NICK %s',[newnick]))
End;



procedure Tvortex.Server(server,ircport : string);
Begin
  { connect to IRC, or reconnect... }
  if assigned(Fclient) then
  begin
    If (FConnected) Then Quit('Vortex - Changing server.');
        Fconnected := false;
  end;
  with FIrcOptions do
  begin
    SetServerHost := server;
    SetServerPort := ircport;
    SetupSocket(true);
  end;

end;

function Tvortex.User(nick, user, ConnectMethod, realname : string) : string;
begin
{ 4.1.3 User message | Only used during Authentications
        Command: USER
        Parameters: <username> <hostname> <servername> <realname>
  Quote(format('USER %s %s %s :%s',[nick,user,ConnectMethod,realname]));

  Use this procedure if you want to use other clients than ICS
  you have to handle socket operations self tho...

  procedure Tdata.ClientSocket1Connect(Sender: TObject; Socket: TCustomWinSocket);
  begin
    socket.SendText(vortex.User('someone','something','-1','hehe:P') + #13#10);
  end;
}

  With FIrcOptions do
  begin
    SetUserName  := RealName;
    SetUserIdent := User;
    SetUserNick  := nick;
    if connectmethod = '-1' then
    begin
       result := format(
         'NICK %s'           + CrLf +
         'USER %s %s %s :%s' + CrLf,[GetUserNick,GetUserNick,GetUserIdent,localiplist[0],GetUserName]);
       exit;
    end;

    if assigned(Fclient) then
    Quote(format('USER %s %s %s :%s',[GetUserIdent,localiplist[0],Fclient.addr,GetUserName]));
  end;
end;


procedure Tvortex.OnConnectDataAvailable(Sender: TObject; Error: Word);
var
received : string;
temp     : string;
Command  : integer;
i        : integer;
{ On Connect Events
 This one is used during connection! }

begin
  if not assigned(fclient) then exit;
  received := trim(Twsocket(sender).ReceiveStr);
  temp := received;

  { Trigger server (dataavailable / any data) }
  If Assigned(FServerMsg) then
     FServerMsg(Received);

  { Reply to Server Pings, to avoid disconnection }
  If copy(received,1,4) = 'PING' Then
  Begin
    Quote('PONG ' + copy(received,6,length(received)));
    if assigned(FAfterServerPing) then FAfterServerPing;
    Exit;
  end;

  If copy(received,1,5) = 'ERROR' Then
    Begin
      if assigned(FServerError) then
         FServerError(Received);
      exit;
    end;

  If copy(received,1,11) = 'NOTICE AUTH' Then
  Begin
    If assigned(FAfterNotice) then
       FAfterNotice('server',copy(received,14,length(received)));
    Exit;
  end;

  { Remove garbage. }
  delete(temp,1,pos(' ',temp));
  delete(temp,pos(' ',temp),length(temp));

  { Ensure temp is a number }
  if isnumeric(temp) then command := strtoint(temp);
  temp := received;

  case command of
  001..003:
  begin
    if command = 001 then
    begin
    { Grab my nick & Local server name from the start }
      FCurrserver := trim(copy(temp,2,pos(' ',temp)-1));
      for i := 0 to 1 do
      delete(received,1,pos(' ',received));
      SetMyNick(trim(copy(received,1,pos(' ',received))));
    end;

    for i := 0 to 1 do
    delete(temp,1,pos(':',temp));
    if assigned(FAfterMotd) then
       FAfterMotd(temp,false);
       exit;
  end;



  004,005:
  begin
 { We can extract lots of good information on these lines
   Oslo.NO.EU.undernet.org u2.10.10.pl18.(release) dioswkg biklmnopstv
   SILENCE=15 WHOX WALLCHOPS USERIP CPRIVMSG CNOTICE MODES=6 MAXCHANNELS=10 MAXBANS=30 NICKLEN=9 TOPICLEN=160 KICKLEN=160 CHANTYPES=+#& :are supported by this server
   PREFIX=(ov)@+ CHANMODES=b,k,l,imnpst CHARSET=rfc1459 NETWORK=Undernet :are supported by this server
 }

   { Get Server name }
    SetCurrentServer(copy(temp,2,pos(' ',temp)));

    for i := 1 to 3 do
    delete(temp,1,pos(' ',temp));

    temp := stringreplace(temp,' :',' ', [rfReplaceAll]);
    if assigned(FAfterMotd) then FAfterMotd(trim(temp),false);
    exit;
  end;

  251..255:
  begin
    if (command = 251) or (command = 255) then
    begin
      for i := 1 to 2 do
      delete(temp,1,pos(':',temp));
      temp := stringreplace(temp,' :',' ', [rfReplaceAll]);
      if assigned(FAfterMotd) then FAfterMotd(temp,false);
      exit;
    end;
    for i := 1 to 3 do
    delete(temp,1,pos(' ',temp));
    temp := stringreplace(temp,' :',' ', [rfReplaceAll]);
    if assigned(FAfterMotd) then FAfterMotd(temp,false);
    exit;
  end;

  376,422:
  begin
  { Assign all incoming data to alternate events }
    for i := 0 to 1 do
    delete(temp,1,pos(':',temp));
    if assigned(FAfterMotd) then
    FAfterMotd(temp,true);
    with Fclient do
    begin
      LineEnd := crlf;
      OnDataAvailable := OnSocketDataAvailable;
    end;
    exit;
  end;

  { Might be buggy =/ }
  433: If Assigned(FAfterNickInUse) Then
       with FIrcOptions do
          FAfterNickInUse(GetUserNick);
  end;

end;

procedure Tvortex.genericparser (socketmessage : string);
var
  i,j          : integer;
  Received     : string;
  Backup       : string;
  Channel      : string;
  Temp         : string;
  CmdFrom      : string;   // Who sent us this command ?
  CmdName      : string;   // What command is it ?
  CmdTo        : string;   // To whom does this go - irgnored most of the time
  CmdMiddle    : string;   // Possible Middle string;
  CmdAllParams : string;   // Everything past :
  Params       : Array[0..10] Of String;  // just extra parameters, used for temporary strings

  {
  Format of Standart Messages:
  :From MessageType To :Parameters
      From can either be:
              Server.host.address
      Or:
              Nickname!ident@host.mask.com
 Some special messages:
  NOTICE Constant/To :Message
      Constant is e.g. AUTH
  PING :From
      From is server.address.com
 CTCPS are sent as privmsgs delimited by #1 at beginning & end

 Sometimes Messages got the following format:
 :From MessageType To SomethingElseHere :Parameters
 If this is the case "S1omethingElseHere" will be stroed in cmdMiddle
 }

begin
  received := trim(socketmessage);
  Backup   := Received;

  { Quick exit - unlikely but possible still }
  If (Length(Received) = 0) Then exit;

  { Command parsing. }

  { If From is specified ... } 
  If (Received[1] = ':') Then
  Begin
    I := Pos(' ', Received);
    If (I > 2) Then CmdFrom := Copy(Received,2,I-2);
    Delete(Received,1,I);
  End;

  { Now get the command name }
  Begin
    I := Pos(' ', Received);
    If (I > 1) Then CmdName := Copy(Received,1,I-1);
    Delete(Received,1,I);
  ENd;

  { Now check if there is an additional constant or "to" }
  If (Received[1] <> ':') Then
  Begin
    I := Pos(' ', Received);
    If (I > 1) Then CmdTo := Copy(Received,1,I-1);
    Delete(Received,1,I);
  End;

  { Now check if there is an additional middle-string }
  If (Received[1] <> ':') Then
  Begin
    I := Pos(' ', Received);
    If (I > 1) Then CmdMiddle := Copy(Received,1,I-1);
    Delete(Received,1,I);
  End;

  { Now the get the rest with out the ":" }
  If (Length(Received) > 1) Then
    If (Received[1] = ':') Then CmdAllParams := Copy(Received,2,Length(Received)-1)
    Else CmdAllParams := Received;

  //////////////////////////////////////////////////////////////////
  ///////////////////////// END OF PARSING /////////////////////////
  //////////////////////////////////////////////////////////////////

  { Restore the original received string.              }
  Received := Backup;

  { Trigger server (dataavailable / any data)          }
  If Assigned(FServerMsg) then FServerMsg(Received);

  { Reply to Server Pings, to avoid disconnection      }
  If (uppercase(cmdName) = 'PING') Then
  Begin
    Quote('PONG ' + cmdAllParams);
    if assigned(FAfterServerPing) then FAfterServerPing;
    Exit;
  end;

  {
   User Joining, (this includes me as well)
   (nickname host channel)
  }
  If (uppercase(cmdName) = 'JOIN') Then
  Begin
    Joined(GetNickFromMask(cmdFrom),cmdAllParams,GetHostmaskFromMask(cmdFrom));
    exit;
  end;

  { User quitting }
  If (uppercase(cmdName) = 'QUIT') Then
  Begin
  {
   (nickname reason)
   :nick!user@host QUIT :reason
  }
    Quited(GetNickFromMask(cmdFrom), GetHostMaskFromMask(CmdFrom), GetIdentFromMask(CmdFrom), cmdAllParams);
    exit;
  end;

  { User parting (this includes me as well)
   (nickname host channel reason) }
  If (uppercase(cmdName) = 'PART') Then
  Begin
  for i := 0 to 1 do  { get channelname  }
    params[i] := received;
    delete(params[0],1,lastdelimiter('#',received)-1);
    delete(params[0],pos(':',params[0])-1,length(params[1])-1);

  { get part reason  }
  for i := 0 to 1 do
    delete(params[1],1,pos(':',params[1]));
    Parted(GetNickFromMask(cmdFrom),GetHostMaskFromMask(CmdFrom),GetIdentFromMask(CmdFrom),params[0],params[1]);
    exit;
  End;

  { This one is very incomplete..  }
  If (uppercase(cmdName) = 'MODE') Then
  Begin
    If Assigned(FAfterMode) Then
    Begin
      If (cmdFrom <> '') Then
        if assigned(FAfterMode) then
        FAfterMode(GetNickFromMask(cmdFrom),CmdTo, cmdAllParams)
    end;
    Exit;
  End;

  {
  There are 2 types of NOTICEs:
   1. NOTICE Constant :SomeTextHere                (coming from server)
   2. :Nick!ident@host.com NOTICE To :SomeTextHere (coming from user 'nick')
  }
  If (uppercase(cmdName) = 'NOTICE') Then
  Begin
    If Assigned(FAfterNotice) Then
    Begin
      If (cmdFrom <> '') Then
      if assigned(FAfterNotice) then
        FAfterNotice(GetNickFromMask(cmdFrom),cmdAllParams)
        Else if assigned(FAfterNotice) then
        FAfterNotice('',cmdAllParams);
    end;
    Exit;
  End;

  If (uppercase(cmdName) = 'INVITE') Then
  Begin
  { :Nick!Ident@host.com INVITE MyNick :Channel  }
    If Assigned(FAfterInvited) Then
       FAfterInvited(GetNickFromMask(cmdFrom),cmdAllParams);
    Exit;
  End;

  { User was kicked }
  If (uppercase(cmdName) = 'KICK') Then
  begin
    { there might be a bug here if I am kicked, beware }

    Kicked(CmdMiddle,GetNickFromMask(CmdFrom), CmdTo,CmdAllParams);
    exit;
  end;

  If (uppercase(cmdName) = 'TOPIC') Then
  Begin
  {
    SOmeone changed the topic
    :Nick!ident@host.com TOPIC Channel :NewTopic
  }
    ChannelTopic(cmdTo,GetNickFromMask(cmdFrom),CmdAllParams);
    Exit;
  End;

  If (uppercase(cmdName) = 'NICK') Then
  Begin
  { :Nick!Ident@host.com NICK <newnick> }
    NickChange(GetNickFromMask(GetNickFromMask(cmdFrom)),CmdAllParams);
    exit;
  End;

  If (UpperCase(cmdName) = 'PRIVMSG') Then
  Begin
    { this might be removed later...   }
    If (Length(cmdAllParams) = 0) Then Exit;
    Messages(received,GetNickFromMask(cmdFrom),GetHostFromMask(CmdFrom),GetIdentFromMask(CmdFrom),CmdTo,CmdAllParams);
    exit;
  end;

  If (UpperCase(cmdName) = 'ERROR:') Then
    Begin
    { these error codes appears often right after you connect   }
      if assigned(FServerError) then FServerError(Received);
      exit;
    end;



{ Number to command translator as shown in RFC1459
 putting the most unused stuff at the bottom.
 Sorted after how often they likely would appear }
  i := match(CmdName);
  case i of

  324,329:
  begin
  { Message of the day stuff }
    if assigned(FAfterMode) then  FAfterMode(GetNickFromMask(cmdFrom),CmdTo, cmdAllParams);
    exit;
  end;

  353:
  Begin
   {
   Names
      :irc.server.com 353 To = Channel :SpaceSperatedNickList
      (@ and + prefixes are included)
      ChannelName, CommaNicks, end of names = false
   }
    temp := received;
    channel := received;
    delete(channel,1,pos('#',channel)-1);
    delete(channel,pos(' ',channel),length(channel));
    delete(temp,1,pos(' :',temp)+1);
    NamesChan(channel,temp,false);
    Exit;
  End;

  366:
  begin
  { end of /names }
    channel := received;
    delete(channel,1,pos('#',channel)-1);
    delete(channel,pos(' ',channel),length(channel));
    NamesChan(channel,cmdAllParams,true);
    Exit;
  end;

  301,311..314,
  316..319:
  begin
  { Whois thingie... }
    If Assigned(FAfterWhois) Then
    begin
      if i <> 318 then FAfterWhois(CmdAllParams, false)
      else FAfterWhois(CmdAllParams, true);  // End of /whois
      exit
    end;
  end;

  303: begin { Ison }
        If assigned(FAfterNotify) then
           FAfterNotify(CmdAllParams);
          exit;
       end;

  461:
  begin
  { :irc.homelien.no 461 joepezt ISON :Not enough parameters }
     exit;
  end;

  352,315:
  Begin { who stuff }
    If Assigned(FAfterWho) Then
    if i <> 315 then
    begin
      temp := received;
      for i := 0 to 3 do
      delete(temp,1,pos(' ',temp));

      { user host server nick away/here ??? :navn channelname }
      params[7] := Cmdmiddle;
      params[6] := trim(copy(temp,pos(':',temp)+2,length(temp)));
      for i  := 0 to 5 do
      begin
        params[i] := trim(copy(temp,1,pos(' ',temp)));
        delete(temp,1,pos(' ',temp));
      end;
      if assigned(FAfterWho) then
         FAfterWho(params[7], params[3], params[0], params[1], params[6], params[2], params[4], params[5],  false)
    end
    else FAfterWho('End of /Who','','','','','','','', true);  // End of /whois
    exit;
  End;

  332,333:  { Topic when joining a channel }
  Begin
 { :Diemen.NL.EU.Undernet.org 332 joepezT #somechannel :some topic }

    if i = 333 then
    begin
      { :Diemen.NL.EU.Undernet.org 333 joepezT #skien blygblome 1033906982 }
          if channel = '' then
          begin
            channel := CmdFrom;
            channel := Cmdto;
          end;
      ChannelTopicSetBy(channel,CmdAllParams);
      Exit;
    end;

    if channel = '' then
      channel := CmdMiddle;

    ChannelTopic(channel,'',CmdAllParams);
    Exit;
  end;

  401:
  begin
    {
       No such nich / channel
       fix ;)
    }
    If Assigned(FAfterNoSuchNick) Then
       FAfterNoSuchNick(CmdFrom);
    exit;
  end;

  433:
  begin
    {
      Nickname is allready in use
      :irc.server.com 433 * OldNickName :Description
    }
    If Assigned(FAfterNickInUse) Then
       FAfterNickInUse(cmdMiddle);
    exit;
  end;

  321..323:
  begin
  {
    Channel listing. Example: LIST <3,>1,C<10,T>0  ;
    2 users, younger than 10 min., topic set.
  }
    if i <> 323 then
    begin
      channel := cmdmiddle;
      params[0] := copy(CmdAllParams,pos(':',CmdAllParams)+1,length(CmdAllParams));
      params[1] := trim(copy(CmdAllParams,1,pos(':',CmdAllParams) -1));
      if isnumeric(params[1]) = false then params[1] := '0';
      if assigned(FAfterChannelList) then FAfterChannelList(channel,params[0],strtoint(params[1]), false);
      exit;
    end;
    if assigned(FAfterChannelList) then
       FAfterChannelList('','',0,true);
    exit;
  end;

  250..255,
  260..266,
  370..376:
  begin { motd stuff again }
    if i = 004 then
    begin
      FCurrServer := received;
      for j := 0 to 2 do
      delete(FCurrServer,1,pos(' ',FCurrServer));
      delete(FCurrServer,pos(' ',FCurrServer),length(FCurrServer));
      FCurrServer := trim(FCurrServer);
    end;

   If Assigned(FAfterMotd) Then
     begin
       if i <> 376 then FAfterMotd(cmdAllParams, false)
       else             FAfterMotd(cmdAllParams, true);  // End of /motd
       Exit;
     end;
   end;

  -1: begin
      { This command is unimplemented }
      exit;
      end;
  end;
  { end case }
end;


procedure Tvortex.OnSocketDataAvailable(Sender: TObject; Error: Word);
Var
  received : string;
begin
  received := trim(Twsocket(sender).ReceiveStr);
  genericparser(received);
End;

procedure Tvortex.OnvortexIRCError (Sender: TObject);
Var       Error : word;
Begin
  Error := FClient.LastError;

  { winsock error 10057 }
  if error = 10057 then Fclient.OnDataAvailable := OnConnectDataAvailable;
  If Assigned(OnError) Then OnError(sender,error);
End;

procedure Tvortex.OnVortexBgException(Sender: TObject; E: Exception;  var CanClose: boolean);
Begin
  If Assigned(FBgException) Then
     FBgException(sender,E,Canclose);
End;

procedure Tvortex.OnSocketClosed (Sender: TObject; Error: Word);
Begin
  FConnected := False;
  If Assigned(FAfterDisconnect) Then
     FAfterDisconnect();
End;

procedure Tvortex.OnSocketConnected (Sender: TObject; Error: Word);
Begin
  FConnected := True;
  with FIrcOptions do
  begin
    User(GetUserNick, GetUserIdent, '8', FUserName);
    Nick(GetUserNick);
  end;
  If Assigned(FAfterConnect) Then FAfterConnect();
End;


function Tvortex.LocalIP(num : byte) : string;
Begin
  Try
   Result := LocalIpList[num];
   Except
    Try
      Result := LocalIpList[0];
    Except
      MessageBox(0,'No IP!','error.',mb_ok);
   End;
  End;
End;

procedure Tvortex.Joined(Nickname, ChannelName, HostName : string);
var
me : boolean;
channel : TChannels;
i : integer;
begin
  { Check wether this is me or others }
  With FIrcOptions do
  if ansisametext(Nickname,GetUserNick) then Me := true
  else me := false;

  case me of
  false:
  begin
    { fikse ? }
    If Assigned(FAfterJoin) Then
       FAfterJoin(Nickname,HostName,ChannelName);
    for i := 0 to FChannels.Count -1 do
    with Tobject(Fchannels[i]) as TChannels do
    if Tobject(Fchannels[i]) <> nil then
    if GetChannelName = ChannelName then
    begin
      AddUserToChannel(Nickname);
      Fchannels[i] := nil;
      break;
    end;


  end;
  true:
  begin
    { Add this channel to later be used :) }
    If Assigned(FAfterJoined) Then
       FAfterJoined(ChannelName);

    Channel := Tchannels.Create;
    FChannels.add(Channel);
    with Channel do
    begin
      SetChannelName(ChannelName);
      SetChannelID(FChannels.Count);
    end;
  end;

  end;
end;

procedure Tvortex.Parted(Nickname, HostName, UserName, ChannelName, Reason: string);
var
me : boolean;
i  : integer;
begin
 { Check wether this is me or someone else }
  With FIrcOptions do
  if ansisametext(Nickname,GetUserNick) then Me := true
  else me := false;

  Case Me of
  true:
  begin
    if Assigned(FAfterParted) Then
       FAfterParted(ChannelName);

    { Delete channel; }
    for i := 0 to FChannels.Count -1 do
    with Tobject(Fchannels[i]) as TChannels do
    if Tobject(Fchannels[i]) <> nil then
    if GetChannelName = ChannelName then
    begin
      Fchannels[i] := nil;
      break;
    end;
    exit;

  end;
  false:
  begin
    If Assigned(FAfterPart) then
       FAfterPart(Nickname,HostName,ChannelName,reason);

      { Delete user from channel; }
      for i := 0 to FChannels.Count -1 do
      with Tobject(Fchannels[i]) as TChannels do
      if Tobject(Fchannels[i]) <> nil then
      if GetChannelName = ChannelName then
      begin
        RemoveUserFromChannel(NickName);
        exit;
      end;
    end;
  end;
end;

procedure Tvortex.Quited(Nickname, user, host, reason: string);
begin
  If Assigned(FAfterUserQuit) Then
     FAfterUserQuit(NickName, Reason);
     {
        TODO: Add user ident and hostname..
        delete user from channellist
     }
end;

procedure Tvortex.Kicked(Victim, BOFH, Channel, Reason: string);
var
me : boolean;
begin
  { Check wether this is me or others }
  With FIrcOptions do
  if ansisametext(Victim,GetUserNick) then Me := true
  else me := false;

  Case Me of
  false:
  begin
    If Assigned(FAfterUserKick) Then
    FAfterUserKick(Victim,BOFH,Channel,Reason);
    exit;
  end;
  true:
  begin
    if FindChannelID(Channel) = -1 then exit;

    with Tobject(Fchannels[FindChannelID(Channel)]) as TChannels do
    begin
      with Tobject(Fchannels[FindChannelID(Channel)]) as TChannels do
      Fchannels[FindChannelID(channel)] := nil;
    end;
    If Assigned(FAfterKicked) then
       FAfterKicked(BOFH,Channel,Reason);
  end;
  end;
end;



procedure Tvortex.NamesChan(ChannelName, CommaNicks: string;
  EndOfNames: boolean);
var
temp : string;
i : integer;

begin
  if EndOfNames then
  begin
  If Assigned(FAfterNames) Then
     FAfterNames('End of /Names',channelName, True);
  end;
    temp := CommaNicks;;
    Delete(Temp,1, Pos(':',temp));

    { Replace spaces with commatas }
    If (Length(Temp) > 0) Then
    For I:=0 To Length(Temp) Do
    If (Temp[I] = ' ') Then Temp[I] := ',';

    If Assigned(FAfterNames) Then
       FAfterNames(temp,ChannelName, false);

    i := FindChannelID(Channelname);
    if i = -1 then exit;

    with Tobject(Fchannels[i]) as TChannels do
    AddUsersFromCommaText(commanicks);

end;


procedure TVortex.ChannelTopic (ChannelName, UserName, Topic  : string);
begin
  If Assigned(FAfterTopic) Then
  FAfterTopic(ChannelName,UserName,Topic);

 { Clean up ... }
  try

  case FindChannelID(Channelname) of
   -1: exit;
  else
  with Tobject(Fchannels[FindChannelID(Channelname)]) as TChannels do
    begin
      { bug in VortexChannels. :( }
      SetTopic(Topic);
      SetTopicSetBy(UserName);
    end;
  end;
  except
  end;
end;

procedure TVortex.ChannelTopicSetBy (ChannelName, Nickname  : string);
begin
  try
  case FindChannelID(Channelname) of
     -1: exit;
    else
    with Tobject(Fchannels[FindChannelID(Channelname)]) as TChannels do
         SetTopicSetBy(NickName);
    end;
  except
  end;
end;

procedure Tvortex.NickChange(OldNick, Newnick: string);
var
me : boolean;
begin
  if assigned(FBeforeNickChange) then
     FBeforeNickChange(oldnick,Newnick);

 { Check wether this is me or someone else }
  With FIrcOptions do
  if AnsiSameText(OldNick,GetUserNick) then Me := true;

  Case Me of
  false:
  begin
    If Assigned(FAfterNickChange) Then
       FAfterNickChange(OldNick,NewNick);
  { ToDo: Update channels with the new nickname...   }
  end;
  true:
  begin
    SetMyNick(NewNick);;
     If Assigned(FAfterNickChanged) Then
        FAfterNickChanged(NewNick,OldNick);
    exit;
  end;
  end;

end;

procedure Tvortex.SetMyNick(Nickname: string);
begin
  { This one does NOT change your nick on IRC }
  With FIrcOptions do
  SetUserNick := NickName;
end;

procedure Tvortex.SetCurrentServer(Value: string);
begin
  { Which server we are currently connected to }
  FCurrServer := Value;
end;

procedure Tvortex.SetIRCName(Value: string);
begin
  With FIrcOptions do
  FUserName := Value;
end;

procedure Tvortex.SetIRCPort(Value: string);
begin
  With FIrcOptions do
  FServerPort := Value;
end;

procedure Tvortex.SetMyUserName(Value: string);
begin
  With FIrcOptions do
  SetUserNick := Value;
end;

procedure Tvortex.SetVersionInfo(Info: string);
begin
  with FCtcpOptions do
  FVersionReply := info;
end;


//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//                                                                          //
//                     !!! Channel & Private messages !!!                   //
//       probably the biggest part of vortex is the message handling.       //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

{
  There are different types of PRIVMSGs:
  :Nick!ident@host.com PRIVMSG To :SomeTextHere

  Now "To" can either be your current Nick, then it's aprivate message
  or a channel name then it's a channel message.
  If The PRIVMSG was a CTCP then "SomeTextHere" begins and ends with char #1.
  Again CTCPs can be sent to individuals or to channels
  Some CTCPs have a really stupid formatting sicne they append the Nick of
  after the trailing #1
  In this case we can safely ignore "NicknameItComesFrom" sicne it's alos passed
  as :Nick!ident@...
}
procedure TVortex.Messages (Line, nick, host, user, destination, Content : string);
begin
  {
    Is it a CTCP-Message ?
    A third parameter "Dest" was added so that the user-assigned event-handler
    can destinguish between CTCPs sent directly to the user and
    CTCPs sent to a whole channel.
  }

  If (Content[1] = #1) Then
  Begin
    CTCPMessage(Line,Nick,Host,User,Destination,Content);
    exit;
  end;

  { Is this a channel message ? }
  if Destination[1] = '#' Then
  Begin
    If Assigned(FAfterChannelMsg) Then
       FAfterChannelMsg(Destination, Content, nick, User, host);
    Exit;
  End;

  { Ok this must be a private Message :-) }
  if Assigned(FAfterPrivMsg) then
     FAfterPrivMsg(Nick,User,Host,Content);
end;


procedure Tvortex.CTCPMessage(Line, nick, host, user, destination,
  Content: string);
var
i : integer;
streng : string;
temp   : string;
params : array[0..5] of string;

begin
  streng := Content;
  {
    Strip of the leading #10 char and the trailing
    #10 char including everything that comes behind it
  }
  Delete(Streng,1,1);
  If (Length(Streng) > 0) Then
  Begin
    I:=Pos(#1,Streng);
    If (I = 0) Then I := Length(Streng) + 1;
    Streng := Copy(Streng,1,I-1);
  End;

  {
    Check if it's an action
    If ((Length(cmdAllParams) > 6) and (UpperCase(Copy(cmdAllParams,1,6)) = 'ACTION')) Then
  }
  If ansisametext(copy(streng,1,6),'ACTION') Then
  Begin
    delete(content,1,pos(' ',content));
    If Assigned(FAfterIrcAction) Then
       FAfterIrcAction(nick,Content,Destination);
    Exit;
  End;

 {
   Handle DCCs Here
   If ((Length(Streng) > 3) and (UpperCase(Copy(cmdAllParams,1,3)) = 'DCC')) Then
 }
 If UpperCase(Copy(streng,1,3)) = 'DCC' Then
  Begin
    temp := streng;

    { if the client send a file with spaces.. }
    if pos('"',temp) <> 0 then
    begin
      Line := between(temp,'"','" ') ;
      delete(temp,pos('"',temp), length(line) +3);
    end else
    begin
      Line := temp;
      for i := 0 to 1 do
      delete(line,1,pos(' ',line));
      delete(line,pos(' ',line),length(line));
      delete(temp,9,length(line)+1);
    end;


    for i := 0 to 5 do
    begin { Find out what type of DCC we received...  }
        params[i] := trim(copy(temp,1,pos(' ',temp)));
        delete(temp,1,pos(' ',temp));
    end;
      params[5] := temp; { port }

//////////////////////////////////////////////////////////////////////////////
//////////////// when receiving a DCC chat request ///////////////////////////
//////////////////////////////////////////////////////////////////////////////

  if ansisametext(params[1],'chat') then
  begin
    delete(temp,1,pos(#32,temp));
    params[0] := trim(copy(temp,1,pos(#32,temp)));
    delete(temp,1,pos(#32,temp));
    if params[3] = '0' then { might be a bad idea   }
       params[3] := host;

    { DCC CHAT chat ip [temp = port] }
    if assigned(FdccChatIncoming) then
    FdccChatIncoming(nick, temp, shortip(params[2]));
    exit;
  end;

//////////////////////////////////////////////////////////////////////////////
//////////////// when receiving a DCC RESUME request /////////////////////////
//////////////////////////////////////////////////////////////////////////////

  if trim(lowercase(params[1])) = 'resume' then
  begin
    exit;
  end;

//////////////////////////////////////////////////////////////////////////////
//////////////// User accepted your resume request ///////////////////////////
//////////////////////////////////////////////////////////////////////////////

  if lowercase(params[1]) = 'accept' then
  begin
    { Getting the last information we need to make a connection }
    for i := 1 to 2 do
    begin
      params[i] := trim(copy(temp,1,pos(#32,temp)));
      delete(temp,1,pos(#32,temp));
    end;

  {
      params[3] := trim(CmdAllParams);
      params[4] := trim(copy(cmdAllParams,1,pos('"',cmdAllParams)-1));
  }
    if params[4] = '' then
       params[4] := 'file.ext';

    If assigned(FDCCGetResume) then
       FDCCGetResume(nick, Params[4],temp,params[3]);
    exit;
  end;

//////////////////////////////////////////////////////////////////////////////
//////////////// when receiving a DCC Send request ///////////////////////////
//////////////////////////////////////////////////////////////////////////////
  if ansisametext(params[1],'send') then
  begin
    {
       Might need a try loop here
       nick port address filename FileSize
       Some clients sends the entire path. damn!
    }
    if pos ('/',Line) <> 0 then delete(Line,1,Lastdelimiter('/',Line));
    if pos ('\',Line) <> 0 then delete(Line,1,Lastdelimiter('\',Line));
    if assigned(FDCCGet) then
       FDCCGet(nick,params[3],shortip(params[2]),Line,Params[5]);
      exit;
    end;
  End;  { End of DCC stuff.. }

  {
    Ok it's *no* DCC request and *no* Action -> fire a CTCP event
    The only *standart* CTCP we handle here is PING - this is required by the standart
    Everything else should be handled by the user-assigned eventhandler imho
    The CTCP event will still be fired though - since clients wnat to rect on this event
  }
  with FCtcpOptions do
  if FReplyToCtcp = true then
  begin
  If ((Length(streng) > 4) and (UpperCase(Copy(streng,1,4)) = 'PING')) Then
  begin
    CtcpReply(nick,streng);
    exit;
  end;

  If ((Length(streng) >= 7) and (UpperCase(Copy(streng,1,7)) = 'VERSION')) Then
  begin
    CtcpReply(nick,'VERSION ' + GetVersionInfo);
    exit;
  end;

  If ((Length(streng) >= 6) and (UpperCase(Copy(streng,1,6)) = 'FINGER')) Then
  begin
    with FCtcpOptions do
    CtcpReply(nick,'FINGER ' + FingerReply);
    exit;
  end;

  If ((Length(streng) >= 4) and (UpperCase(Copy(streng,1,4)) = 'TIME')) Then
  begin
    with FCtcpOptions do
    begin
      if FTimeReply = '' then
      CtcpReply(nick,'TIME ' + timetostr(now))
      else
      CtcpReply(nick,'TIME ' + FTimeReply);
    end;
    exit;
  end;

  { Please leave this line intact... :-) }
  If ((Length(streng) >= 10) and (UpperCase(Copy(streng,1,10)) = 'CLIENTINFO')) Then
  begin
    with FCtcpOptions do
    CtcpReply(nick,FClientInfo);
    exit;
  end;

  { Now fire the CTCP-event handler }
  If Assigned(FAfterCtcp) Then
  FAfterCtcp(nick, streng, Destination);
  end;
end;

function Tvortex.FindChannelID(AChannel: string): integer;
var
i : integer;
begin
  for i := 0 to Fchannels.Count -1 do
  if Fchannels[i] <> nil then
  with Tobject(Fchannels[i]) as TChannels do
  if AnsiSameText(GetChannelname,Achannel) then
  begin
    result := i;
    exit;
  end;
  result := -1;
end;

function Tvortex.GetChannelTopic(value: string): string;
begin
  if (value <> '') and
     (value[1] = '#') then { mulig bug fiks }
  if findchannelid(value) <> -1 then
    begin
      with Tobject(Fchannels[findchannelID(value)]) as Tchannels do
      result := GetTopic;
      exit;
    end;
    Result := 'unknown channel';
end;

procedure Tvortex.ClearUsersInChannel(value: string);
begin
  if value = '' then exit;
  if FindChannelID(value) <> -1 then
  begin
    with Tobject(Fchannels[findchannelid(value)]) as Tchannels do
    ClearUsers;
    Quote(format('names %s',[value]));
  end;
end;

function Tvortex.GetTopicSetBy(value: string): string;
begin
  if findchannelid(value) = -1 then
    begin
      Result := 'unknown channel';
      exit;
    end;
  with Tobject(Fchannels[findchannelid(value)]) as Tchannels do
  result := GetTopicSetBy;
end;

function Tvortex.GetUsersFromChannel(Value: string): string;
var
i : integer;

begin
  i := findchannelid(value);
  if i = -1 then
    begin
      Result := 'unknown channel';
      exit;
    end;
  with Tobject(Fchannels[i]) as Tchannels do
  result := GetAllNicksFromChannel;

end;

function Tvortex.CountUsersFromChannel(Value: string): integer;
var
i : integer;

begin
  i := findchannelid(value);
  if i = -1 then
    begin
      Result := 0;
      exit;
    end;
  with Tobject(Fchannels[i]) as Tchannels do
  result := CountUsers;

end;

{ I put these on one line since they wont be modified anyway }
procedure TVortex.SetIrcOptions(const Value: TIrcOptions);begin  FIrcOptions.Assign(Value);end;
procedure TVortex.SetCtcpOptions(const Value: TCtcpOptions);begin  FCtcpOptions.Assign(Value);end;
procedure TVortex.SetSocksOptions(const Value: TSocksOptions);begin  FSocksOptions.Assign(Value);end;
procedure TVortex.SetAuthOptions(const Value: TAuthOptions);begin  FAuthOptions.Assign(Value);end;
procedure TCtcpOptions.Assign(Source: TPersistent);begin  inherited;end;
procedure TAuthOptions.Assign(Source: TPersistent);begin  inherited;end;
procedure TircOptions.Assign(Source: TPersistent);begin  inherited;end;



procedure TVortex.InitDCCGet(nick, port, address, filename,
  filesize: string);
begin

end;

procedure TVortex.InitDCCGetResume(nick, port, Position: string);
begin

end;


{ TAuthOptions }

procedure TAuthOptions.OnIdentDserverSessionAvailable(Sender: TObject;
  Error: Word);
var
AuthClient : TWSocket;
UserIdent : string;
begin
  { uferdig }
  AuthClient := TWSocket.Create(nil);
  With AuthClient do
  begin
    LineMode := TRUE;
    HSocket  := TWSocket(sender).Accept;
 { We are answering on Identd requests}
    if FAnswer = true then
           SendStr(format('%s, 113 : USERID : %s : %s' + crlf,['6667', FSystem, FIdent]))
      else SendStr(format('%s, 113 : ERROR : NO-USER'  + crlf,['6667']));
    Close;
  end;
  FreeAndNil(AuthClient);
end;

procedure TAuthOptions.StartAuth;
 { experimental IdentD daemon }
begin
  if FAuthServer <> nil then FAuthServer.free;
  FAuthServer := TWSocket.create(nil);
  with FAuthServer do
  begin
    OnSessionAvailable := OnIdentDserverSessionAvailable;
    Addr  := '0.0.0.0';
    port  := '113';
    proto := 'tcp';
    try
      listen;
    except
      free
    end;
  end;
  exit;
end;

procedure TAuthOptions.StopAuth;
begin
  if FAuthServer <> nil then
     FAuthServer.free;
end;



End.
