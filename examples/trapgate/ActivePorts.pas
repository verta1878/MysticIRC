unit ActivePorts;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, WinSock, SnmpTypes;

type
  TListStatus = (_Idle,_Updating);

  TIncludePorts = class(TPersistent)
  private
    FHost0000,
    FLoopBack : Boolean;
    constructor Create;
  published
    property Host0000 : Boolean read FHost0000 write FHost0000;
    property LoopBack : Boolean read FLoopBack write FLoopBack; 
  end;

  TPortData = class
  private
    function RightJustify(Value : String; Digits : Integer) : String;
    function InAddr2String(IpAddr : TInAddr):String;
    function Status2String : String;
  public
    Status,
    LocalPort,
    RemotePort    : Integer;
    LocalAddress,
    RemoteAddress : TInAddr;
    Protocol      : String;
    constructor Create(ProtoName : String);
  end;

  TActivePorts = class(TComponent)
  private
    FTrojansInfoAvail : Boolean;
    FWSInitialized    : Bool;
    FSnmpLib,
    FAccessMutex      : THandle;
    FSnmpInitProc,
    FSnmpQueryProc    : Pointer;
    FListStatus       : TListStatus;
    FIncludePorts     : TIncludePorts;
    FOpenPorts        : TList;
    FTrojansInfoList  : TStringList;
    FListView         : TListView;
    procedure FatalError(ErrorNumber : Integer);
    procedure SetListView(lv : TListView);
    procedure SetIncludePorts(Values : TIncludePorts);
    function GetPortsCount : Integer;
    function GetOpenPorts(Number :Integer) : TPortData;
    procedure Clear;
    procedure UpdateList;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Status : TListStatus read FListStatus;
    property OpenPorts[Number : Integer] : TPortData read GetOpenPorts;
    property PortsCount : Integer read GetPortsCount;
    procedure Update;
  published
    property IncludePorts : TIncludePorts read FIncludePorts write SetIncludePorts;
    property ListView : TListView read FListView write SetListView;
  end;

procedure Register;

implementation

{$DEFINE CLOSE_ON_ERROR}

const
  LockError         = 1;
  UnlockError       = 2;
  AllocError        = 3;
  NotIdleStatus     = 4;
  WSStartupError    = 5;
  LoadLibraryError  = 6;
  InitLibraryError  = 7;
  SnmpQueryError    = 8;
  SnmpQueryEndError = 9;

  ErrorMessages : array[LockError..SnmpQueryEndError] of String =
                       ('Connection list lock failure','Connection list unlock failure',
                        'Error allocating required resources',
                        'Connection list is in update mode, wait for idle status',
                        'Failed to initialize Windows Sockets library',
                        'SNMP extension library "' + SNMP_LIB_NAME + '" is not available',
                        'Error initializing SNMP extension agent',
                        'SNMP query failed','Unexpected end of query results encountered');

  StatusPhrase : array[Closed..Tcb_Discard] of string =
                      ('Closed','Listen','Syn_Sent','Syn_recived','Established',
                       'Close_wait','Fin_wait_1','Closing','Last_ack','Fin_wait_2',
                       'Time_wait','TCB_discard');

  First_LV_Column = 1;
  Last_LV_Column  = 6;

  ColumnsCaptions : Array[First_LV_Column..Last_LV_Column] of String =
                         ('Local port','Protocol','Remote host','Remote port',
                          'Status','Suspected activity');
  ColumnsWidths   : Array[First_LV_Column..Last_LV_Column] of Integer =
                         (94,80,130,104,110,200);

  sHost0000 = '0.0.0.0';
  sLoopBack = '127.0.0.1';

var
  sTrojansFName : String = 'Trojans.inf';


constructor TIncludePorts.Create;

begin
  Inherited Create;
  FHost0000 := False;
  FLoopBack := True;
end;

constructor TPortData.Create(ProtoName : String);

begin
  inherited Create;
  Status := Listen;
  Protocol := ProtoName;
end;

function TPortData.RightJustify(Value : String; Digits : Integer) : String;

begin
  while Length(Value) < Digits do
    Value := #32 + Value;
  Result := Value;
end;

function TPortData.InAddr2String(IpAddr : TInAddr):String;

begin
  with IpAddr.s_un_b do
    Result := IntToStr(Integer(s_b1)) + '.' + IntToStr(Integer(s_b2)) + '.' +
              IntToStr(Integer(s_b3)) + '.' + IntToStr(Integer(s_b4));
end;

function TPortData.Status2String :String;

begin
  if Status in [Closed..Tcb_Discard] then
    Result := StatusPhrase[Status]
  else
    Result := 'Undefined';
end;

constructor TActivePorts.Create(AOwner: TComponent);

var
  aData       : TWSAData;
  aHandle     : THandle;
  aIdentifier : TAsnObjectIdentifier;

begin
  inherited Create(AOwner);
  FListStatus := _Idle;
  FWSInitialized := (WsaStartup($0101, aData) = 0);
  if not FWSInitialized then
    FatalError(WSStartupError);
  FSnmpLib := SafeLoadLibrary(SNMP_LIB_NAME, SEM_NOOPENFILEERRORBOX);
  if FSnmpLib = 0 then
    FatalError(LoadLibraryError);
  FSnmpInitProc := GetProcAddress(FSNmpLib, SNMP_INITPROC_NAME);
  FSnmpQueryProc := GetProcAddress(FSNmpLib, SNMP_QUERYPROC_NAME);
  if ((FSnmpQueryProc = nil) or (FSnmpInitProc = nil)) then
    FatalError(LoadLibraryError);
  if not TSnmpInitProc(FSnmpInitProc)(GetTickCount, aHandle, aIdentifier) then
    FatalError(InitLibraryError);
  FAccessMutex := CreateMutex(nil, False, nil);
  if FAccessMutex = 0 then
    FatalError(AllocError);
  FIncludePorts := TIncludePorts.Create;
  FOpenPorts := TList.Create;
  sTrojansFName := ExtractFilePath(Application.ExeName) + sTrojansFName;
  FTrojansInfoAvail :=  FileExists(sTrojansFName);
  if FTrojansInfoAvail then
  begin
    FTrojansInfoList := TStringList.Create;
    FTrojansInfoList.LoadFromFile(sTrojansFName);
  end;
end;

destructor TActivePorts.Destroy;

begin
  Clear;
  FOpenPorts.Free;
  if FTrojansInfoAvail then
    FTrojansInfoList.Free;
  FIncludePorts.Free;
  if FAccessMutex <> 0 then
    CloseHandle(FAccessMutex);
  if FSnmpLib <> 0 then
    FreeLibrary(FSnmpLib);
  if FWSInitialized then
    WSACleanup;
  inherited Destroy;
end;

procedure TActivePorts.FatalError(ErrorNumber : Integer);

begin
  MessageDlg('TActivePorts exception: ' + ErrorMessages[ErrorNumber], mtError, [mbOK], 0);
{$IFDEF CLOSE_ON_ERROR}
  TForm(Owner).Close;
{$ENDIF}
end;

procedure TActivePorts.SetListView(lv : TListView);

var
  I       : Integer;
  aColumn : TListColumn;

begin
  if Not Assigned(lv) then
    exit;
  FListView := lv;
  with FListView do
  begin
    ViewStyle := vsReport;
    ReadOnly := True;
    GridLines := True;
    SortType := stText;
    with Font do
    begin
      Name := 'Courier New';
      Size := 8;
    end;
    with Columns do
    begin
      Clear;
      for I := First_LV_Column to Last_LV_Column do
      begin
        aColumn := Add;
        with aColumn do
        begin
          Caption := ColumnsCaptions[I];
          Width := ColumnsWidths[I];
        end;
      end;
    end;
  end;
end;

procedure TActivePorts.SetIncludePorts(Values : TIncludePorts);

begin
  FIncludePorts := Values;
end;

function TActivePorts.GetPortsCount : Integer;

begin
  Result := FOpenPorts.Count;
end;

function TActivePorts.GetOpenPorts(Number :Integer) : TPortData;

begin
  Result := FOpenPorts[Number];
end;

procedure TActivePorts.Clear;

var
  I : Integer;

begin
  for I := 0 to FOpenPorts.Count - 1 do
    TPortData(FOpenPorts[I]).Free;
  FOpenPorts.Clear;
end;

procedure TActivePorts.UpdateList;

var
  Number,
  ListEnd : Integer;
  vS, vI  : LongInt;
  vBind   : TRFC1157VarBind;
  vBList  : TRFC1157VarBindList;
  Data    : TPortData;

  procedure InitList(var ID : TListID);

  begin
    FillChar(vBList, SizeOf(vBList), 0);
    FillChar(vBind, SizeOf(vBind), 0);
    vBList.List := @vBind;
    vBList.len := 1;
    vBind.Name.idLength := SNMP_NAME_LENGTH;
    vBind.name.ids := @ID;
    ListEnd := FOpenPorts.Count;
  end;

begin
  InitList(TcpList);
  if not TSnmpQueryProc(FSnmpQueryProc)(NextRequest, vBList, vS, vI) then
    FatalError(SnmpQueryError);
  if vBList.list.value.asnType <> ASN_NULL then
  begin
    while (vBList.list.value.asnType = ASN_INTEGER) do
    begin
      Data := TPortData.Create('TCP');
      Data.Status := vBList.list.value.Counter;
      FOpenPorts.Add(Data);
      if not TSnmpQueryProc(FSnmpQueryProc)(NextRequest, vBList, vS, vI) then
        FatalError(SnmpQueryError);
    end;
    if vBList.list.value.asnType = ASN_NULL then
      FatalError(SnmpQueryEndError);
    Number := ListEnd;
    while (vBList.list.value.asnType = ASN_RFC1155_IPADDRESS) do
    begin
      with TPortData(FOpenPorts[Number]) do
        Move(vBList.list.value.address.stream^, LocalAddress, SizeOf(TInAddr));
      if not TSnmpQueryProc(FSnmpQueryProc)(NextRequest, vBList, vS, vI) then
        FatalError(SnmpQueryError);
      Inc(Number);
    end;
    if vBList.list.value.asnType = ASN_NULL then
      FatalError(SnmpQueryEndError);
    Number := ListEnd;
    while (vBList.list.value.asnType = ASN_INTEGER) do
    begin
      TPortData(FOpenPorts[Number]).LocalPort := vBList.list.value.counter;
      if not TSnmpQueryProc(FSnmpQueryProc)(NextRequest, vBList, vS, vI) then
        FatalError(SnmpQueryError);
      Inc(Number);
    end;
    if vBList.list.value.asnType = ASN_NULL then
      FatalError(SnmpQueryEndError);
    Number := ListEnd;
    while (vBList.list.value.asnType = ASN_RFC1155_IPADDRESS) do
    begin
      with TPortData(FOpenPorts[Number]) do
        Move(vBList.list.value.address.stream^, RemoteAddress, SizeOf(TInAddr));
      if not TSnmpQueryProc(FSnmpQueryProc)(NextRequest, vBList, vS, vI) then
        FatalError(SnmpQueryError);
      Inc(Number);
    end;
    if vBList.list.value.asnType = ASN_NULL then
       FatalError(SnmpQueryEndError);
    Number := ListEnd;
    while (vBList.list.value.asnType = ASN_INTEGER) do
    begin
      TPortData(FOpenPorts[Number]).RemotePort := vBList.list.value.counter;
      if not TSnmpQueryProc(FSnmpQueryProc)(NextRequest, vBList, vS, vI) then
        FatalError(SnmpQueryError);
      Inc(Number);
    end;
  end;
  InitList(UdpList);
  if not TSnmpQueryProc(FSnmpQueryProc)(NextRequest, vBList, vS, vI) then
    FatalError(SnmpQueryError);
  if vBList.list.value.asnType = ASN_NULL then
    Exit;
  while (vBList.list.value.asnType = ASN_RFC1155_IPADDRESS) do
  begin
    Data := TPortData.Create('UDP');
    Move(vBList.list.value.address.stream^, Data.LocalAddress, SizeOf(TInAddr));
    FOpenPorts.Add(Data);
    if not TSnmpQueryProc(FSnmpQueryProc)(NextRequest, vBList, vS, vI) then
      FatalError(SnmpQueryError);
  end;
  if vBList.list.value.asnType = ASN_NULL then
    FatalError(SnmpQueryEndError);
  Number := ListEnd;
  while (vBList.list.value.asnType = ASN_INTEGER) do
  begin
    TPortData(FOpenPorts[Number]).LocalPort := vBList.list.value.counter;
    if not TSnmpQueryProc(FSnmpQueryProc)(NextRequest, vBList, vS, vI) then
      FatalError(SnmpQueryError);
    Inc(Number);
  end;
end;

procedure TActivePorts.Update;

var
  I      : Integer;
  S1, S2 : String;
  Item   : TListItem;

begin
  if FListStatus <> _Idle then
    FatalError(NotIdleStatus);
  if (WaitForSingleObject(FAccessMutex, 100) <> WAIT_OBJECT_0) then
    FatalError(LockError);
  try
    FListStatus := _Updating;
    Clear;
    UpdateList;
  finally
    if not ReleaseMutex(FAccessMutex) then
      FatalError(UnlockError);
    FListStatus := _Idle;
  end;
  if not Assigned(FListView) then
    Exit;
  with FListView do
  begin
    Items.BeginUpdate;
    Items.Clear;
    for I := 0 to PortsCount - 1 do
      with OpenPorts[I] do
      begin
        if (not IncludePorts.Host0000) and (InAddr2String(LocalAddress) = sHost0000) then
          Continue;
        if (not IncludePorts.LoopBack) and (InAddr2String(LocalAddress) = sLoopBack) then
          Continue;
        if FTrojansInfoAvail then
        begin
          S1 := Protocol + #32 + RightJustify(IntToStr(LocalPort), 5);
          S1 := FTrojansInfoList.Values[S1];
        end;
        Item := Items.Add;
        Item.Caption := RightJustify(IntToStr(LocalPort), 10);
        Item.SubItems.Add(Protocol);
        Item.SubItems.Add(InAddr2String(RemoteAddress));
        if Status = Listen then
          S2 := RightJustify('0', 11)
        else
          S2 := RightJustify(IntToStr(RemotePort), 11);
        Item.SubItems.Add(S2);
        Item.SubItems.Add(Status2String);
        if FTrojansInfoAvail then
          Item.SubItems.Add(S1);
      end;
    Items.EndUpdate;
  end;
end;

procedure Register;

begin
  RegisterComponents('LGM', [TActivePorts]);
end;

end.
