{$MODE OBJFPC}
{$H+}
unit mtxfer;
{ File transfer — Zmodem, Ymodem, Xmodem

  Copyright (C) 2026 FPC264IRC Contributors
  License: GPLv3

  Protocol implementations pluggable — provide code for:
  - Zmodem send/receive
  - Ymodem send/receive  
  - Xmodem 1K/CRC send/receive }

interface

uses Classes, mtconn;

type
  TXferProtocol = (xpZmodem, xpYmodem, xpXmodem);
  TXferDirection = (xdSend, xdReceive);

  TXferProgress = record
    FileName: String;
    FileSize: LongInt;
    BytesDone: LongInt;
    Percent: Integer;
    BytesPerSec: LongInt;
    ErrorCount: Integer;
  end;

  TXferOnProgress = procedure(const Progress: TXferProgress) of object;

  TFileTransfer = class
  private
    FConn: TConnection;
    FProtocol: TXferProtocol;
    FDirection: TXferDirection;
    FDownloadPath: String;
    FOnProgress: TXferOnProgress;
    FActive: Boolean;
  public
    constructor Create(AConn: TConnection);
    destructor Destroy; override;
    function Send(const FileName: String; Proto: TXferProtocol): Boolean;
    function Receive(const DownPath: String; Proto: TXferProtocol): Boolean;
    procedure Cancel;
    property Active: Boolean read FActive;
    property OnProgress: TXferOnProgress read FOnProgress write FOnProgress;
    property DownloadPath: String read FDownloadPath write FDownloadPath;
  end;

implementation

uses SysUtils;

constructor TFileTransfer.Create(AConn: TConnection);
begin
  inherited Create;
  FConn := AConn;
  FActive := False;
  FDownloadPath := '.';
end;

destructor TFileTransfer.Destroy;
begin
  inherited;
end;

function TFileTransfer.Send(const FileName: String; Proto: TXferProtocol): Boolean;
begin
  Result := False;
  if not FConn.Connected then Exit;
  if FActive then Exit;
  FProtocol := Proto;
  FDirection := xdSend;
  FActive := True;

  { TODO: Plug in protocol engine
    case Proto of
      xpZmodem: ZmodemSend(FConn, FileName, FOnProgress);
      xpYmodem: YmodemSend(FConn, FileName, FOnProgress);
      xpXmodem: XmodemSend(FConn, FileName, FOnProgress);
    end; }

  FActive := False;
  Result := True;
end;

function TFileTransfer.Receive(const DownPath: String; Proto: TXferProtocol): Boolean;
begin
  Result := False;
  if not FConn.Connected then Exit;
  if FActive then Exit;
  FProtocol := Proto;
  FDirection := xdReceive;
  FDownloadPath := DownPath;
  FActive := True;

  { TODO: Plug in protocol engine }

  FActive := False;
  Result := True;
end;

procedure TFileTransfer.Cancel;
begin
  FActive := False;
end;

end.
