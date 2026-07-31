unit ClusterDCC;
{
        TClusterDCC v2.0 by joepezT

        IRC: SpeizZa / joepezT @ undernet :  #Delphi
        ICQ: 340148, 3941292
        Email: joepezt@c2i.net

        This is a very experimental component
        will only listen to the specified port, else it listens on ServerPort 59
        if no ServerPort is defined.

        Resuming is experimental!

        will only handle dcc chats both ways..
        only download transfers at this time.


        if you find this component usefull, please give me credits !
        -- SpeizZa / joepezT -- www.allabagitta.net --
}
{$d+}
interface

uses
  Windows, Messages, SysUtils, Classes, Controls, wsocket;

type
    TDCCEvents = class(TObject)
  end;
   TChatMessageEvent = procedure(Sender: TObject; const Text: string) of object;
   Tstartevent     = procedure of object;
   TData           = procedure (Sender : Tobject; ID : integer; received : String) of object;
   Tprogress       = procedure (sender : Tobject; readbytes : integer; TotalSize : int64) of object;
   TRawFileData    = procedure (data : pointer; len : integer) of object;
   TFileError      = procedure (sender :Tobject; error :word) of object;
   TFileConnect    = Procedure (tag:  integer; remoteaddr, remoteport,ANick : string) of object;
   TFileDisconnect = procedure (Sender : Tobject) of object;
   TFileDone       = Procedure (sender : Tobject; AFileName : string; AFileSize : int64) of object;
   TChatMessage    = procedure (AMessage, ANick : string) of Object;
   TChatDisconnect = procedure (ANick : string) of object;
   TChatConnect    = procedure (ANick : String) of object;

   // Main Component
type
  TClusterDCC = class(TComponent)
  private
   Server             : TWsocket;
   FDCCServer         : Boolean;
   FDCCServerPort     : string;
   FStart             : Tstartevent;
   FChatMessage       : TChatMessage;
   FChatConnect       : TChatConnect;
   FChatDisconnect    : TChatDisconnect;
   FData              : TData;
   FRawFileData       : TRawFileData;
   FFileDone          : TFileDone;
   FFileProgress      : Tprogress;
   FFileConnect       : TFileConnect;
   FFileDisconnect    : TFileDisconnect;
   FFileError         : TFileError;
   FFiletrack         : integer;
   FGetDir            : String;
   FGetPath           : string;
   procedure WriteFile(Sender : TObject;error : word);
   Procedure SendFile (Sender : TObject;error : word);
  protected
   ChatList           : Tlist;
   procedure SessionAvailable(Sender: TObject; Error: Word);
   procedure Error(Sender: TObject; Error: Word);
   procedure DataAvailable(Sender: TObject; Error: Word);
   procedure Connected(sender : Tobject; Error: Word);
   procedure Disconnected(Sender: TObject; Error: Word);
   procedure ChatDisconnected(Sender: TObject; Error: Word);
   procedure CustomFileSocketReceiveData(Sender: TObject; error: word);
   procedure CustomFileSocketConnected(Sender: TObject; error: word);
   procedure SendFileConnected (sender :Tobject; error : word);
   procedure SendFileOnSessionAvailable (sender :Tobject; error : word);
   procedure FileDisconnected (sender :Tobject; error : word);
   procedure SendFileOnDataAvailable (sender :Tobject; error : word);
  public
    ChatCount : integer;
    FileList  : Tlist;
    tempnick  : string;
    // File related
    Function  FileSend(ANickName, AFilePath, AFileName, AFileSize, APort : string) : string;
    procedure NewFileSocket(APort : string);
    procedure FileConnect(nick, remoteaddr, remoteport, path, filename : string; size,start : int64;id : integer);
    procedure SetFilePath (path : string);
    procedure SetServerPort (Port : string);
    // Initialization routuines
    procedure Loaded; override;
    constructor Create  (AOwner         : TComponent); override;
    destructor  Destroy; override;
  published
    property DCCServer        : Boolean      read FDCCServer      write FDCCServer;
    property ServerPort       : String       read FDCCServerPort  write FDCCServerPort;
    property Getdir           : string       read FGetPath        write FGetPath;
    property GetReceivePath   : string       read FGetPath;
    property OnStarted        : TStartEvent  read FStart          write FStart;
    property OnFileDone       : TFileDone    read FFileDone       write FFileDone;
    property OnFileProgress   : TProgress    read FFileProgress   write FFileProgress;
    property OnFileRawData    : TRawFileData read FRawFileData    write FRawFileData;
    property OnFileError      : TFileError   read FFileError      write FFileError;
    property OnFileConnect    : TFileConnect read FFileConnect    write FFileConnect;
    property OnFileDisconnect : TFileDisconnect read FFileDisconnect write FFileDisconnect;
    property OnChatMessage    : TChatMessage    read FChatMessage    write FChatMessage;
    property OnChatConnected  : TChatConnect    read FChatConnect    write FChatConnect;
    property OnChatDisconnect : TChatDisconnect read FChatDisconnect write FChatDisconnect;
    procedure DoChatMessage;
  end;

 type
   TFileTransfers = class(TThread)
  private
    FMySocket      : Twsocket;
    FMyFile        : TFileStream;
    FAddress       : String;
    FPort          : String;
    FFilename      : string;
    FFrom          : string;
    FPath          : string;
    FID            : integer;
    FProgressID    : integer;
    FFileSize      : int64;
    FTotalReceived : int64;
    FLastbytes     : int64;
    FSending       : Boolean;
    FProsent       : integer;
    FLastProsent   : integer;
  public
    Function  Percent      : integer;
    procedure SetFileID   (ID : integer);
    procedure SetUserName (NickName : string);
    procedure SetFileName (FileName : string);
    procedure SetFilePath (Path : string);
    procedure SetFileSize (Size : Int64);
    procedure SetReceived (Total : int64);
    procedure SetSinceLast(Total : int64);
    procedure SetPercentDone (prosent : byte);
    procedure SetLastPercent (prosent : byte);
    Constructor create;
    destructor destroy;
  Published
    property GetSocket    : TWSocket read FMySocket;
    property GetUserName  : string read FFrom;
    property GetFileName  : String read FFilename;
    property GetPort      : string read FPort;
    property GetAddress   : string read FAddress;
    property GetPath      : string read FPath;
    property GetFileSize  : int64  read FFileSize;
    property GetSinceLast : int64  read FLastBytes;
    property GetReceived  : int64  read FTotalReceived;
    property ID           : integer  read FID;
    property ProgressID   : integer  read FProgressID;
    property GetPercentDone : integer read FProsent;
    property GetLastPercent : integer read FLastProsent;
 end;

type
  TDCCChatUser = class(TThread)
  private
    Socket   : TWsocket;
    FNick    : string;
    FHostAdd : String;
    FPort    : string;
    procedure DoChatMessage;
  protected
    procedure OnChatDataAvailable(sender: Tobject; error: word);
    procedure OnChatDisconnected(sender: Tobject; error: word);
    procedure OnChatSessionConnected(sender: Tobject; error: word);
  public
    procedure SetNick (value : string);
    procedure SetHost (value : string);
    procedure SetPort (Value : string);
    procedure Say     (Value : string);
    procedure CloseChat;
    procedure Connect;
    Function Listen   (port : string) : string;
    Constructor Create;
    Destructor  Destroy;
  published
    property GetUserNick : String read FNick;
    property GetAddress : string read FHostAdd;
    property GetPort  : string read FPort;
//  property OnChatMessage: TChatMessageEvent read FOnChatMessage write FOnChatMessage;
end;

procedure Register;

implementation

////////////////////////////////////
// File threads
////////////////////////////////////

function TFileTransfers.percent : integer;
begin
  result :=  round(GetReceived * 100 / GetFileSize);
end;

constructor TFileTransfers.create;
begin
  inherited Create(True)
end;

destructor TFileTransfers.destroy;
begin
  If assigned(FMyFile) then
     FMyFile.Free;

  // bugs ?
  If assigned(FMySocket) then
     FMySocket.Free;

  inherited destroy
end;

procedure TFileTransfers.SetUserName(NickName: string);begin  FFrom := NickName;end;
procedure TFileTransfers.SetFileName(FileName: string);begin  FFileName := Filename;end;
procedure TFileTransfers.SetFilePath(Path: string);    begin  FPath := Path;end;
procedure TFileTransfers.SetFileID(ID: integer);       begin  FID := Id;end;
procedure TFileTransfers.SetLastPercent(prosent: byte);begin  FLastProsent := Prosent;end;
procedure TFileTransfers.SetPercentDone(prosent: byte);begin  FProsent := Prosent;end;
procedure TFileTransfers.SetReceived(Total: int64);    begin  FTotalReceived := Total;end;
procedure TFileTransfers.SetSinceLast(Total: int64);   begin  FLastBytes := Total;end;
procedure TFileTransfers.SetFileSize(Size: Int64);     begin  FFileSize := size;end;

////////////////////////////////////////////////////////////////////////
//////////////////////// File Connectivity /////////////////////////////
////////////////////////////////////////////////////////////////////////

procedure TClusterDCC.FileConnect(nick, remoteaddr, remoteport, path, filename : string; size, start : int64;id: integer);
var
FileThread : TFileTransfers;

begin
  repeat
  if start = 0 then
  if FileExists(path + FileName) = true then
     Filename := '_' + Filename;
  until FileExists(path + FileName) = false;

  FileThread := TFileTransfers.Create;
  FileList.Add(FileThread);

  // ID for this thread
  FFiletrack := FileList.Count;

  With FileThread do
  begin
    SetFileID(FFileTrack);
    SetFilePath(FGetDir);
    SetFileName(filename);
    SetFileSize(size);
    SetPercentDone(0);
    SetLastPercent(0);
    FProgressID := FFileTrack;
    SetUserName(nick);

    if start <> 0 then
    begin  //  resume
      FMyFile := Tfilestream.Create(GetPath + FFilename, fmOpenReadWrite, fmShareCompat);
      FMyFile.seek(start,SofromEnd)
    end else
      Fmyfile := Tfilestream.Create(GetPath + FFilename, FmCreate, fmShareCompat);

     FMysocket := Twsocket.create(FMysocket);
     with FMysocket do
     begin
       tag := FFileTrack;
       port := remoteport;
       addr := remoteaddr;
       OnDataAvailable := writefile;
       OnSessionConnected := Connected;
       OnSessionAvailable := SessionAvailable;
       OnSessionClosed := FileDisconnected;
       connect;
     end;
  end;
end;

procedure TClusterDCC.WriteFile(Sender : TObject;error : word);
var
   Len: int64;
   id : integer;
   B1, B2, B3, B4: Char;
//   Buf: array[0..1023] Of Byte;
   Buf: array[0..4095] Of Byte;

begin
  id := twsocket(sender).Tag;
  with TObject(filelist.items[id -1]) as TFileTransfers do
  begin

    if (FMySocket.State <> wsConnected) then
    begin
      if assigned(FFileDone) then
         FFileDone(FMySocket,GetFileName,GetFileSize);
      FreeAndNil(FMyFile);
      FreeAndNil(FMySocket);
      exit;
    end;

    if not assigned(FMyFile) then
    exit;

    Len := FMySocket.Receive(@buf, sizeof(buf));

    with FMyFile do
    begin
      write(buf,len);
      If Len <= 0 Then
         exit;
    end;

  // DCC Checksums
    with FMyFile do
    begin
      len := Size;
      B1  := chr(Len shr 24);
      B2  := chr((Len shr 16) and $FF);
      B3  := chr((Len shr 8) and $FF);
      B4  := chr(Len and $FF);

      FMySocket.SendStr(B1 + B2 + B3 + B4);
      If Assigned(FFileProgress) then
         FFileProgress(sender,FMySocket.ReadCount,size);

      SetReceived(size);
      SetSinceLast(FMySocket.ReadCount);
      SetPercentDone(Percent);

    end;

  end;
end;

////////////////////////////////////////////////////////////////////////////////
/////////////////// File sending, Procedures & Functions ///////////////////////
////////////////////////////////////////////////////////////////////////////////

Function TclusterDCC.FileSend(ANickName, AFilePath, AFileName, AFileSize, APort : string) : string;
var
FileThread : TFileTransfers;

begin
  if (APort = '') then
  APort := '0';

  FileThread := TFileTransfers.Create;
  FileList.Add(FileThread);

  // ID for this thread
  FFiletrack := FileList.Count;

  With FileThread do
  begin
    SetFileID(FFileTrack);
    SetFilePath(FGetDir);
    SetFileName(Afilename);
    SetFileSize(StrToInt(AFileSize));
    SetUserName(ANickName);
    FSending := True;
    Fmyfile := Tfilestream.Create(AFilePath + AFileName, FmOpenRead, fmShareCompat);
    FMysocket := Twsocket.create(FMysocket);
    try
    with FMysocket do
    begin
      addr := '0.0.0.0';
      port := APort;
      OnDataAvailable := SendFile;
      OnDataAvailable := SendFileOnDataAvailable;
      OnSessionAvailable := SendFileConnected;
      OnSessionClosed := FileDisconnected;
      tag := FFileTrack;
      Listen;
      result := port;
    end
    except
      FileList.Remove(FileThread);
      FMySocket.Free;
      FileThread.Free;
      result := '-1';
    end;
  end;
end;

procedure TClusterDCC.SendFile(Sender: TObject; error: word);
var
   Len: int64;
   id : integer;
   Buf: array[0..1023] of Byte;
begin
  id := twsocket(sender).Tag -1;  len := 1;

  with TObject(filelist.items[id]) as TFileTransfers do
  while (len <> 0) and (FMySocket.State = wsConnected) do
  begin
    Len := FMyFile.Read(Buf, sizeof(Buf));

    if Len <> 0 then
    try
      FMySocket.Send(@Buf, Len);
    except

    end;

    if (FMySocket.State <> wsConnected) then
    begin
      FreeAndNil(FMyFile);
      FreeAndNil(FMySocket);
      break;
    end;

   end;
end;


procedure TClusterDCC.SendFileConnected(sender: Tobject; error: word);
var
id : integer;

begin
  id := Twsocket(sender).Tag;
  with TObject(filelist.items[id -1]) as TFileTransfers do
  begin
    FMySocket := Twsocket.create(self);
    with FMySocket do
    begin
      OnDataAvailable := SendFileOnDataAvailable;
      OnSessionClosed := FileDisconnected;
      FMySocket.tag := id;
      HSocket := twsocket(sender).Accept;
      SendFileOnDataAvailable(sender,error);
      If Assigned(FFileConnect) then
         FFileConnect(tag, PeerAddr, PeerPort, tempnick);
      end;
  end;
end;

procedure TClusterDCC.SendFileOnDataAvailable(sender: Tobject;
  error: word);
var
   Len: int64;
   id : integer;
   Buf: array[0..1023] of Byte;
begin
  id := twsocket(sender).Tag -1;
  with TObject(filelist.items[id]) as TFileTransfers do
  begin
    Len := FMyFile.Read(Buf, sizeof(Buf));

    if (FMySocket.State <> wsConnected) or (len = 0) then
    begin
      FreeAndNil(FMyFile);
      FreeAndNil(FMySocket);
      exit;
    end;

    FMySocket.Send(@Buf, Len);
    If Assigned(FFileProgress) then
       FFileProgress(sender,FMySocket.ReadCount,FMyFile.Size);

  end;
end;


procedure TClusterDCC.SendFileOnSessionAvailable(sender: Tobject;
  error: word);
begin

end;

procedure TClusterDCC.FileDisconnected(sender: Tobject; error: word);
var
i : integer;

begin
  i :=   twsocket(sender).tag;
  with TObject(filelist.items[i-1]) as TFileTransfers do
  begin
    If Assigned(FFileDone) then
       FFileDone(FMySocket,GetFileName,GetFileSize);
    FMySocket.CloseDelayed;
    FMyFile.Free;
    // bug ?
    FMySocket.Free;
  end;
end;


// DCC SERVER
procedure TClusterDCC.NewFileSocket(APort: string);
var
NewSocket : TWSocket;
begin
  NewSocket := TWsocket.create(self);
  with NewSocket do
  begin
    OnSessionConnected := Connected;
    OnSessionAvailable := CustomFileSocketConnected;
    OnSessionClosed := Disconnected;
    Addr  := '0.0.0.0';
    proto := 'tcp';
    port  := APort;
    listen;
  end;
end;

// Experimental
procedure TClusterDCC.CustomFileSocketReceiveData(Sender: TObject; error: word);
var
buf : Array[0..1023] of byte;
len : int64;

begin
  len := twsocket(sender).receive(@buf, sizeof(buf));
  If Len <= 0 Then Exit;
  if Twsocket(sender)<> nil then
  if assigned(FRawFileData) then
     FRawFileData(@buf,len);
end;

// Experimental
procedure TClusterDCC.CustomFileSocketConnected(Sender: TObject; error: word);
var
newclient : Twsocket;

begin
  newclient := Twsocket.create(self);
  with newclient do
  begin
    OnDataAvailable := CustomFileSocketReceiveData;
    HSocket := Twsocket(sender).Accept;
    sendstr('121 Client nickname resume 0' + #13#10);
  end;
end;

procedure TClusterDCC.SessionAvailable(Sender: TObject; Error: Word);
var
newclient : Twsocket;

begin
  inc(ChatCount);
  newclient := Twsocket.create(self);
  with newclient do
  begin
    OnDataAvailable := DataAvailable;
    OnSessionClosed := Disconnected;
    tag := ChatCount;
    HSocket := server.Accept;
    ChatList.Add(newclient);
    If Assigned(FFileConnect) then
       FFileConnect(tag, PeerAddr, PeerPort, tempnick);
  end;
end;

procedure TClusterDCC.Disconnected(Sender: TObject; Error: Word);
begin

end;

procedure TClusterDCC.ChatDisconnected(Sender: TObject; Error: Word);
var
I : integer;
begin
  i := twsocket(sender).Tag;
  // bugs ?
  with TObject(ChatList.items[i - 1]) as Twsocket do
  Begin
    self := nil;
    free;
  end;
  // fix this ..
  If Assigned(FFileDisconnect) then
    FFileDisconnect(Sender);
end;


procedure TClusterDCC.DataAvailable(Sender: TObject; Error: Word);
var
received : string;
ID       : integer;

begin
  received := trim(twsocket(sender).receivestr);
  ID := twsocket(sender).Tag;
  If assigned(Fdata) then
     Fdata(sender,Id,received);
end;

procedure TClusterDCC.Connected(sender : Tobject; Error: Word);
Begin
  with twsocket(sender) do
    If Assigned(FFileConnect) then
       FFileConnect(tag, PeerAddr, PeerPort,tempnick);
end;

procedure TClusterDCC.SetFilePath(path: string);
begin
  FGetDir := Path;
end;

procedure TClusterDCC.SetServerPort(Port: string);
begin
  FDCCServerPort := Port;
end;

////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// { TDCCChatUser } /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TDCCChatUser.CloseChat;
begin
  with socket do
  begin
    CloseDelayed;
  end;
end;

procedure TDCCChatUser.Connect;
begin
  with socket do
  begin
    addr := GetAddress;
    port := GetPort;
    Connect;
  end;
end;

constructor TDCCChatUser.Create;
begin
  inherited Create(True);
  Socket := Twsocket.Create(socket);
  with socket do
  begin
    OnDataAvailable    := OnChatDataAvailable;
    OnSessionClosed    := OnChatDisconnected;
    OnSessionAvailable := OnChatSessionConnected;
  end;
end;

destructor TDCCChatUser.Destroy
;
begin
  FreeAndNil(socket);
  inherited Destroy;
end;

function TDCCChatUser.Listen(port: string): string;
begin
  with socket do
  begin
    addr := '0.0.0.0';
    port := GetPort;
    listen;
    result := Port;
  end;
end;

procedure TDCCChatUser.OnChatDataAvailable(sender: Tobject; error: word);

begin
//  if assigned(FChatMessage) then
//     FchatMessage(GetUserNick,TWsocket(sender).ReceiveStr);
end;

procedure TDCCChatUser.OnChatDisconnected(sender: Tobject; error: word);
begin
//  if assigned(FChatDisconnect) then
//    FChatDisconnect(GetUserNick);
end;

procedure TDCCChatUser.OnChatSessionConnected(sender: Tobject;
  error: word);
begin
//  if assigned(FChatConnect) then
 //    FChatConnect(GetUserNick);
end;

procedure TDCCChatUser.Say(Value: string);begin  socket.SendStr(value + #13#10);end;
procedure TDCCChatUser.SetHost(value: string);begin  FHostAdd := Value;end;
procedure TDCCChatUser.SetNick(value: string);begin  Fnick := Value;end;
procedure TDCCChatUser.SetPort(Value: string);begin  FPort := value;end;

////////////////////////////////////////////////////////////////////////
//////////////// Stuff who should be left alone  ///////////////////////
////////////////////////////////////////////////////////////////////////

procedure Register;
begin
  RegisterComponents('joepezT', [TClusterDCC]);
end;

constructor TClusterDCC.Create(AOwner: TComponent);
begin
  inherited Create(Aowner);
  if not(csDesigning in ComponentState) then
  ChatList := Tlist.create;
  filelist := Tlist.create;
end;

destructor TClusterDCC.Destroy;
begin
  if (csDesigning in ComponentState) then
  begin
  // Free up files here ?
    server.Free;
    ChatList.free;
    filelist.free;
  end;

  inherited Destroy;
end;

procedure TClusterDCC.Error(Sender: TObject; Error: Word);
begin
  if assigned(FFileError) then
     FFileError(sender,error);
end;

procedure TClusterDCC.Loaded;
begin
  inherited Loaded;
  if FDCCserverport = '' then FDCCServerPort := '59';

  if not (csDesigning in ComponentState) then
  begin
    Server := TWSocket.Create(Self);
  if FDCCServer = true then
    with Server do
    begin
      OnSessionAvailable := CustomFileSocketConnected;
      OnDataAvailable := CustomFileSocketReceiveData;
      Addr  := '0.0.0.0';
      proto := 'tcp';
      Port  := '49';
      Port;
      server.listen;
    end;
    if Assigned(Fstart) then
       Fstart;
  end;
end;

procedure TClusterDCC.DoChatMessage;
BEGIN
END;

procedure TDCCChatUser.DoChatMessage;
begin
// if Assigned(FChatMessage) then FChatMessage(Self, '<some text>');
end;

end.
