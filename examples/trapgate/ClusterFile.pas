unit ClusterFile;
{
  Cluster DCC File component by joepezT
  http://vortex.berzerk.net

  IRC: joepezT @ undernet :  #Delphi
  ICQ: 340148, 3941292
  Email: Gothic(a)bluezone.no (Primary mail)  - (a) = @
         vortex(a)berzerk.net (questions regarding this component)

  Note:
  Many things in this component still do not work.
  You will only be able to receive files.

  Main purpose:
  Easy implementation of Direct File transfer over IRC.

  download ICS from www.overbyte.be
  You can use this component freely as long as you mention my name :-)


}
interface

uses
  Messages, SysUtils, Classes, Controls, wsocket;

type
  TDCCFile = class(Tobject)
  end;
   TStartevent   = procedure of object;
   TProgress     = procedure (Filename,received,total,completed : string) of object;
   TFileDone     = procedure (Filename,Size : string) of object;
   TFileBroken   = procedure (Filename,Size : string) of object;

type
  TClusterFile = class(TComponent)
  private
    ControllSocket : TWSocket;
    Start          : TStartevent;
    FileThread     : TList;
    FListen        : Boolean;
    FChecksums     : Boolean;
    FCompleted     : TFileDone;
    FProgress      : TProgress;
    FListenPort    : string;
    FGlobalpath    : string;
    function  Percent(Received,TotalSize : int64): integer;
    procedure SetupControllSocket;
  protected
    procedure OnDCCGetConnect(Sender: TObject; Error: Word);
    procedure OnDCCError(Sender: TObject; Error: Word);
    procedure OnDCCGetDataAvailable(Sender: TObject; Error: Word);
    procedure OnDCCGetDisconnected(Sender: TObject; Error: Word);
    procedure OnDCCSendConnect(Sender: TObject; Error: Word);
    procedure OnDCCSendDisconnected(Sender: TObject; Error: Word);
    procedure OnDCCListenConnect(Sender: TObject; Error: Word);
    procedure OnDCCListenDisconnected(Sender: TObject; Error: Word);
  public
    procedure Sendfile(Hostname,Remoteport,Filepath,Filename : string);
    procedure GetFile (Hostname,Remoteport,FileSize, Filepath,Filename : string);
    procedure GetFileResume (Hostname,Remoteport,FileSize, StartByte, Filepath,Filename : string);
    procedure   Loaded; override;
    constructor Create  (AOwner : TComponent); override;
    destructor  Destroy; override;
  published
    property Listen         : boolean read FListen write FListen;
    property mIRCChecksums  : boolean read FChecksums write FChecksums; 
    property ListenPort     : string read FListenPort write FListenPort;
    property Filepath       : string read FGlobalpath write FGlobalpath;
    property GetFilepath    : string read FGlobalpath;
    property GetListenPort  : string read FListenPort;
    property SetFilepath    : string write FGlobalpath;
    property SetListenPort  : string write FListenPort;
    property OnStarted      : TStartEvent   read Start         write Start;
    property OnFileDone     : TFileDone     read FCompleted     write FCompleted;
    property OnFileProgress : Tprogress read FProgress write FProgress;
  end;

 type
   TDCCTransfer = class(TObject)
  private
    FMySocket      : TWSocket;
    FMyFile        : TFileStream;
    FPort          : string;
    FAddress       : string;
    FFilename      : string;
    FPath          : string;
    FNick          : string;
    FFileSize      : int64;
  protected

  public
    Constructor create;
    destructor destroy; override;
  Published
    property Socket       : TWSocket read FMySocket;
    property GetFileName  : String   read FFilename;
    property GetTotalSize : int64    read FFileSize;
    property GetPort      : string   read FPort;
    property GetPath      : string   read FPath;
    property GetNick      : string   read FNick;
    property GetAddress   : string   read FAddress;
    property SetFileName  : String write FFilename;
    property SetFileSize  : int64  write FFileSize;
    property SetPort      : string write FPort;
    property SetPath      : string write FPath;
    property SetNick      : string write FNick;
    property SetAddress   : string write FAddress;
 end;

procedure Register;

implementation

function TClusterFile.percent (Received,TotalSize : int64) : integer;
begin
  result :=  round(received * 100 / TotalSize);
end;

procedure Register;
begin
  RegisterComponents('joepezT', [TClusterFile]);
end;

{ TClusterFile }

procedure TClusterFile.SetupControllSocket;
begin
  if assigned(ControllSocket) then
  ControllSocket.Free;
  
  ControllSocket := TWsocket.Create(self);
  with ControllSocket do
  try
    OnSessionAvailable := OnDCCListenConnect;
    OnSessionClosed    := OnDCCListenDisconnected;
    proto := 'tcp';
    addr := '0.0.0.0';
    port := GetListenPort;
    Listen;
  except
    { Our listening socket failed }
  end;
end;

procedure TClusterFile.Loaded;
begin
  inherited Loaded;
  if not (csDesigning in ComponentState) then
  begin
    SetupControllSocket;
    if Assigned(start) then start;
  end;
  {
    SetFilepath := 'c:\';
    SetListenPort := '12345';
  }
end;


constructor TClusterFile.Create(AOwner: TComponent);
begin
  inherited Create(Aowner);
  if not (csDesigning in ComponentState) then
  begin
    FileThread := Tlist.create;
  end;

end;

destructor TClusterFile.Destroy;
begin
  if not (csDesigning in ComponentState) then
  begin
    FreeAndNil(FileThread);
  end;
  
  inherited Destroy;
end;

procedure TClusterFile.OnDCCGetConnect(Sender: TObject; Error: Word);
begin
 { We are connected }
end;

procedure TClusterFile.OnDCCGetDataAvailable(Sender: TObject; Error: Word);
var
   Len       : int64;
   Total     : string;
   Received  : string;
   Completed : byte;
   ID        : integer;
   Buf       : array[0..4095] Of Byte;
   B1, B2,
   B3, B4    : Char;

begin
  id := TWSocket(sender).Tag;
  with TObject(FileThread.items[id]) as TDCCTransfer do
  begin

   if (socket.State <> wsConnected) then
    begin
    { We are not connected anymore }
      FreeAndNil(FMyFile);
      FreeAndNil(FMySocket);
      // TObject(FileThread.Items[id]).free;
      FileThread.Items[id] := nil;
      exit;
    end;


    { if not assigned(FMyFile) then exit; }
    with socket do
    Len := Receive(@buf, sizeof(buf));

    with FMyFile do
    begin
      write(buf,len);
      If Len <= 0 Then
         exit;
    end;

    with FMyFile do
    begin
      if FChecksums then
      begin
       { DCC Check sums }
        len := Size;
        B1  := chr(Len shr 24);
        B2  := chr((Len shr 16) and $FF);
        B3  := chr((Len shr 8) and $FF);
        B4  := chr(Len and $FF);
        With Socket do
        SendStr(B1 + B2 + B3 + B4);
      end;
      Received := IntToStr(Size);
      Total    := IntToStr(GetTotalSize);
      { % complete }
      if GetTotalsize <> 0 then
      Completed := percent(StrToInt(Received),GetTotalSize);
    end;
    If Assigned(FProgress) then
       FProgress(GetFileName,Received,IntToStr(GetTotalSize),IntToStr(completed) + '%')
  end;
end;

procedure TClusterFile.OnDCCGetDisconnected(Sender: TObject; Error: Word);
begin
  with TWSocket(sender) do
  with TObject(FileThread.items[Tag]) as TDCCTransfer do
  begin
  { we cannot free this entirely because that would mess up the Stream ID's }
  { seems that the memory is not released at this point }
    FreeAndNil(FMyFile);
    FreeAndNil(FMySocket);
    FileThread.Items[Tag] := nil;
  end;

end;

procedure TClusterFile.OnDCCError(Sender: TObject; Error: Word);
begin
  { error... }
end;

procedure TClusterFile.Getfile(Hostname, Remoteport, FileSize, Filepath,
  Filename: string);
var
NewThread : TDCCTransfer;
FileParams : string;

begin
  NewThread := TDCCTransfer.create;
  FileThread.Add(NewThread);

  with NewThread do
  begin
    SetFileName := Filename;      { our temporary string }
    if Filepath[length(filepath)] <> '\' then
       Filepath := filepath + '\';

    SetPath := Filepath;
    FileParams := (filepath + Filename);
    SetFileSize := StrToInt64(FileSize);


    if FileExists(fileparams) then
    fileparams := fileparams + IntToStr(random(999)) + ExtractFileExt(fileparams);
    
    With FMyFile do
    FMyFile := TFilestream.Create(fileparams,fmCreate, fmShareCompat);

    FMySocket := TWSocket.Create(self);
    with FMySocket do
    begin
      OnDataAvailable    := OnDCCGetDataAvailable;
      OnSessionConnected := OnDCCGetConnect;
      OnSessionClosed    := OnDCCGetDisconnected;
      tag  := FileThread.Count -1;
      Addr := Hostname;
      port := Remoteport;
      connect;
    end;

  end;

end;

procedure TClusterFile.Sendfile(Hostname, Remoteport, Filepath,
  Filename: string);
var
NewThread : TDCCTransfer;

begin
  NewThread := TDCCTransfer.create;
  FileThread.Add(NewThread);

  with NewThread do
  begin
    SetFileName := Filename;      { our temporary string }
    SetPath := Filepath;

    With FMyFile do
    Create(GetFileName,fmOpenRead, fmShareCompat);

    with FMySocket do
    begin
      OnSessionConnected := OnDCCSendConnect;
      OnSessionClosed := OnDCCSendDisconnected;
      tag  := FileThread.Count -1;
      Addr := Hostname;
      port := Remoteport;
      connect;
    end;
  end;

end;

procedure TClusterFile.OnDCCSendConnect(Sender: TObject; Error: Word);
begin
  { DCC send connected }
end;

procedure TClusterFile.OnDCCSendDisconnected(Sender: TObject; Error: Word);
begin
  { Send closed }
end;

procedure TClusterFile.OnDCCListenConnect(Sender: TObject; Error: Word);
begin

end;

procedure TClusterFile.OnDCCListenDisconnected(Sender: TObject;
  Error: Word);
begin

end;

procedure TClusterFile.GetFileResume(Hostname, Remoteport, FileSize, StartByte,
  Filepath, Filename: string);
var
NewThread : TDCCTransfer;
FileParams : string;

begin
  NewThread := TDCCTransfer.create;
  FileThread.Add(NewThread);

  with NewThread do
  begin
    SetFileName := Filename;
    if Filepath[length(filepath)] <> '\' then
       Filepath := filepath + '\';

    SetPath := Filepath;
    FileParams := (filepath + Filename);


    if FileExists(fileparams) then
    fileparams := fileparams + IntToStr(random(999));
    
    With FMyFile do
    begin
      FMyFile := TFilestream.Create(fileparams,fmOpenReadWrite, fmShareCompat);
      SeekEof;
    end;

    FMySocket := TWSocket.Create(self);
    with FMySocket do
    begin
      OnDataAvailable    := OnDCCGetDataAvailable;
      OnSessionConnected := OnDCCGetConnect;
      OnSessionClosed    := OnDCCGetDisconnected;
      tag  := FileThread.Count -1;
      Addr := Hostname;
      port := Remoteport;
      connect;
    end;

  end;

end;

{ TDccTransfer }

constructor TDccTransfer.create;
begin
  inherited Create;
end;

destructor TDccTransfer.destroy;
begin
  if assigned(FMyFile) then
     FreeAndNil(FMyFile);
  inherited destroy;
end;

end.

