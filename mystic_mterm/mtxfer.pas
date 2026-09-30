{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }
{$MODE OBJFPC}
{$H+}
Unit mtxfer;
{ File transfer for mterm — bridges TConnection to Mystic protocol units.
  TConnIO wraps TConnection as TIOBase so m_protocol_zmodem etc can use it.
  TFileTransfer provides Send/Receive wired to real Zmodem/Ymodem. }

Interface

Uses
  SysUtils, Classes,
  m_io_Base,
  m_Protocol_Queue,
  m_Protocol_Base,
  m_Protocol_Zmodem,
  m_Protocol_Ymodem,
  m_Protocol_Xmodem,
  mtconn;

Type
  TXferProtocol = (xpZmodem, xpYmodem, xpXmodem);
  TXferDirection = (xdSend, xdReceive);

  TXferProgress = Record
    FileName    : String;
    FileSize    : Int64;
    BytesDone   : Int64;
    Percent     : Integer;
    ErrorCount  : Integer;
    LastMessage : String;
  End;

  TXferOnStatus = Procedure(Const Msg: String);

  { TIOBase adapter wrapping mterm's TConnection.
    Protocol units expect TIOBase for their Client field. }
  TConnIO = Class(TIOBase)
  Private
    FConn: TConnection;
  Public
    Constructor Create(AConn: TConnection);
    Function    DataWaiting    : Boolean; Override;
    Function    WriteBuf       (Var Buf; Len: LongInt) : LongInt; Override;
    Function    ReadBuf        (Var Buf; Len: LongInt) : LongInt; Override;
    Function    WaitForData    (TimeOut: LongInt) : LongInt; Override;
    Procedure   PurgeInputData (DrainWait: LongInt); Override;
    Procedure   PurgeOutputData; Override;
  End;

  { High-level file transfer wired to Mystic protocol units }
  TFileTransfer = Class
  Private
    FConn       : TConnection;
    FActive     : Boolean;
    FDownloadPath : String;
  Public
    Constructor Create(AConn: TConnection);
    Destructor Destroy; Override;
    Function Send(Const FileName: String; Proto: TXferProtocol): Boolean;
    Function Receive(Const DownPath: String; Proto: TXferProtocol): Boolean;
    Procedure Cancel;
    Property Active: Boolean Read FActive;
    Property DownloadPath: String Read FDownloadPath Write FDownloadPath;
  End;

Var
  XferOnStatus : TXferOnStatus;

Implementation

{ ---- TConnIO — TIOBase adapter for TConnection ---- }

Constructor TConnIO.Create(AConn: TConnection);
Begin
  Inherited Create;
  FConn := AConn;
End;

Function TConnIO.DataWaiting: Boolean;
Begin
  Result := FConn.DataAvailable;
End;

Function TConnIO.WriteBuf(Var Buf; Len: LongInt): LongInt;
Begin
  FConn.SendBuf(Buf, Len);
  Result := Len;
End;

Function TConnIO.ReadBuf(Var Buf; Len: LongInt): LongInt;
Begin
  Result := FConn.Receive(Buf, Len);
End;

Function TConnIO.WaitForData(TimeOut: LongInt): LongInt;
Var Elapsed: LongInt;
Begin
  Elapsed := 0;
  While Elapsed < TimeOut Do Begin
    If FConn.DataAvailable Then Begin Result := 1; Exit; End;
    Sleep(10);
    Inc(Elapsed, 10);
  End;
  Result := 0;
End;

Procedure TConnIO.PurgeInputData(DrainWait: LongInt);
Var Junk: Array[0..255] Of Byte;
Begin
  While FConn.DataAvailable Do
    FConn.Receive(Junk, SizeOf(Junk));
End;

Procedure TConnIO.PurgeOutputData;
Begin
End;

{ ---- Status callback bridge ---- }

Procedure StatusBridge(Starting, Ending: Boolean; Status: RecProtocolStatus);
Begin
  If Assigned(XferOnStatus) Then Begin
    If Starting Then
      XferOnStatus('Starting ' + Status.Protocol + ': ' + Status.FileName)
    Else If Ending Then
      XferOnStatus(Status.Protocol + ' complete: ' + Status.FileName +
                   ' (' + IntToStr(Status.Position) + ' bytes)')
    Else
      XferOnStatus(Status.Protocol + ': ' + Status.FileName + ' ' +
                   IntToStr(Status.Position) + '/' + IntToStr(Status.FileSize) +
                   ' E:' + IntToStr(Status.Errors));
  End;
End;

Function NoAbort: Boolean;
Begin
  Result := False;
End;

{ ---- TFileTransfer ---- }

Constructor TFileTransfer.Create(AConn: TConnection);
Begin
  Inherited Create;
  FConn := AConn;
  FActive := False;
  FDownloadPath := '.';
End;

Destructor TFileTransfer.Destroy;
Begin
  Inherited;
End;

Function TFileTransfer.Send(Const FileName: String; Proto: TXferProtocol): Boolean;
Var
  IO: TConnIO;
  Q: TProtocolQueue;
  Dir, FName: String;
Begin
  Result := False;
  If Not FConn.Connected Then Exit;
  If FActive Then Exit;
  If Not FileExists(FileName) Then Exit;

  Dir   := ExtractFilePath(FileName);
  FName := ExtractFileName(FileName);
  FActive := True;

  IO := TConnIO.Create(FConn);
  Q  := TProtocolQueue.Create;
  Try
    Q.Add(True, Dir, FName, '');
    Case Proto Of
      xpZmodem: Begin
        With TProtocolZmodem.Create(TIOBase(IO), Q) Do Begin
          StatusProc := @StatusBridge;
          AbortProc  := @NoAbort;
          QueueSend;
          Result := (Status.Errors = 0);
          Free;
        End;
      End;
      xpYmodem: Begin
        With TProtocolYmodem.Create(TIOBase(IO), Q) Do Begin
          StatusProc := @StatusBridge;
          AbortProc  := @NoAbort;
          QueueSend;
          Result := (Status.Errors = 0);
          Free;
        End;
      End;
      xpXmodem: Begin
        With TProtocolXmodem.Create(TIOBase(IO), Q) Do Begin
          StatusProc := @StatusBridge;
          AbortProc  := @NoAbort;
          QueueSend;
          Result := (Status.Errors = 0);
          Free;
        End;
      End;
    End;
  Finally
    Q.Free;
    IO.Free;
  End;
  FActive := False;
End;

Function TFileTransfer.Receive(Const DownPath: String; Proto: TXferProtocol): Boolean;
Var
  IO: TConnIO;
  Q: TProtocolQueue;
Begin
  Result := False;
  If Not FConn.Connected Then Exit;
  If FActive Then Exit;

  FDownloadPath := DownPath;
  FActive := True;

  IO := TConnIO.Create(FConn);
  Q  := TProtocolQueue.Create;
  Try
    Case Proto Of
      xpZmodem: Begin
        With TProtocolZmodem.Create(TIOBase(IO), Q) Do Begin
          StatusProc  := @StatusBridge;
          AbortProc   := @NoAbort;
          ReceivePath := FDownloadPath;
          QueueReceive;
          Result := (Status.Errors = 0);
          Free;
        End;
      End;
      xpYmodem: Begin
        With TProtocolYmodem.Create(TIOBase(IO), Q) Do Begin
          StatusProc  := @StatusBridge;
          AbortProc   := @NoAbort;
          ReceivePath := FDownloadPath;
          QueueReceive;
          Result := (Status.Errors = 0);
          Free;
        End;
      End;
      xpXmodem: Begin
        With TProtocolXmodem.Create(TIOBase(IO), Q) Do Begin
          StatusProc  := @StatusBridge;
          AbortProc   := @NoAbort;
          ReceivePath := FDownloadPath;
          QueueReceive;
          Result := (Status.Errors = 0);
          Free;
        End;
      End;
    End;
  Finally
    Q.Free;
    IO.Free;
  End;
  FActive := False;
End;

Procedure TFileTransfer.Cancel;
Begin
  FActive := False;
End;

End.
