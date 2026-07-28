{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }
{$MODE OBJFPC}
{$H+}
unit mtconn;
{ Connection manager — telnet, serial, FOSSIL }

interface

uses Classes, SysUtils, Sockets
  {$IFDEF GO32V2}
  , serial, serial_irq, fossil
  {$ENDIF};

type
  TConnType = (ctNone, ctTelnet, ctSerial, ctFossil);

  TConnection = class
  private
    FType: TConnType;
    FSock: TSocket;
    FConnected: Boolean;
    {$IFDEF GO32V2}
    FSerHandle: TSerialHandle;
    {$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;
    function ConnectTelnet(const Host: String; Port: Word): Boolean;
    {$IFDEF GO32V2}
    function ConnectSerial(ComPort: Byte; Baud: LongInt): Boolean;
    function ConnectFossil(ComPort: Byte): Boolean;
    {$ENDIF}
    procedure Disconnect;
    function Receive(var Buf; Count: Integer): Integer;
    procedure SendByte(B: Byte);
    procedure SendBuf(const Buf; Count: Integer);
    property Connected: Boolean read FConnected;
    property ConnType: TConnType read FType;
  end;

implementation

{ platform units handled by Sockets }

constructor TConnection.Create;
begin
  inherited;
  FType := ctNone;
  FSock := -1;
  FConnected := False;
end;

destructor TConnection.Destroy;
begin
  if FConnected then Disconnect;
  inherited;
end;

function TConnection.ConnectTelnet(const Host: String; Port: Word): Boolean;
var Addr: TInetSockAddr;
begin
  Result := False;
  FSock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if FSock < 0 then Exit;

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(Port);
  Addr.sin_addr := StrToHostAddr(Host);

  if fpConnect(FSock, @Addr, SizeOf(Addr)) = 0 then begin
    FType := ctTelnet;
    FConnected := True;
    Result := True;
  end else begin
    CloseSocket(FSock);
    FSock := -1;
  end;
end;

{$IFDEF GO32V2}
function TConnection.ConnectSerial(ComPort: Byte; Baud: LongInt): Boolean;
begin
  Result := False;
  FSerHandle := SerOpen('COM' + Chr(Ord('1') + ComPort));
  if FSerHandle < 0 then Exit;
  SerSetParams(FSerHandle, Baud, 8, NoneParity, 1, []);
  SerEnableIRQ(FSerHandle);
  FType := ctSerial;
  FConnected := True;
  Result := True;
end;

function TConnection.ConnectFossil(ComPort: Byte): Boolean;
begin
  Result := False;
  if FossilInit(ComPort) = FOSSIL_MAGIC then begin
    FType := ctFossil;
    FConnected := True;
    Result := True;
  end;
end;
{$ENDIF}

procedure TConnection.Disconnect;
begin
  case FType of
    ctTelnet: begin
      CloseSocket(FSock);
      FSock := -1;
    end;
    {$IFDEF GO32V2}
    ctSerial: begin
      SerDisableIRQ(FSerHandle);
      SerClose(FSerHandle);
    end;
    ctFossil: begin
      FossilDeinit(0);
    end;
    {$ENDIF}
  end;
  FType := ctNone;
  FConnected := False;
end;

function TConnection.Receive(var Buf; Count: Integer): Integer;
begin
  Result := 0;
  if not FConnected then Exit;
  case FType of
    ctTelnet: Result := fpRecv(FSock, @Buf, Count, 0);
    {$IFDEF GO32V2}
    ctSerial: begin
      if SerRingCount(FSerHandle) > 0 then
        Result := SerReadRing(FSerHandle, Buf, Count)
      else
        Result := SerRead(FSerHandle, Buf, Count);
    end;
    ctFossil: Result := FossilReadBlock(0, Buf, Count);
    {$ENDIF}
  end;
end;

procedure TConnection.SendByte(B: Byte);
begin
  SendBuf(B, 1);
end;

procedure TConnection.SendBuf(const Buf; Count: Integer);
begin
  if not FConnected then Exit;
  case FType of
    ctTelnet: fpSend(FSock, @Buf, Count, 0);
    {$IFDEF GO32V2}
    ctSerial: SerWrite(FSerHandle, Buf, Count);
    ctFossil: FossilWriteBlock(0, Buf, Count);
    {$ENDIF}
  end;
end;

end.
