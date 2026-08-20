Unit ansiedit_transport;

// ====================================================================
// ansiedit Transport Abstraction
//
// Provides a common interface for teleconference connections
// over TCP (sockets) or Serial (UART/FOSSIL). The m_pdnet protocol
// engine uses this instead of raw fpSocket calls.
//
// TCP:    Uses m_io_sockets (TIOSocket)
// Serial: Uses serial.pas (UART) or fossil.pas (FOSSIL driver)
// ====================================================================

{$I M_OPS.PAS}

Interface

Uses
  m_io_Base;

Type
  TTransportType = (ttNone, ttTCP, ttSerial);
  { ttSerial: tries FOSSIL first, falls back to direct UART }

  TTransport = Class
    FType      : TTransportType;
    FIO        : TIOBase;       { actual I/O object (socket or serial) }
    FConnected : Boolean;
  Public
    Constructor Create(AType: TTransportType);
    Destructor  Destroy; Override;

    { Server operations }
    Function  Listen(Port: Word): Boolean;
    Function  Accept: TTransport;

    { Client operations }
    Function  Connect(Host: String; Port: Word): Boolean;

    { I/O }
    Function  DataWaiting: Boolean;
    Function  ReadBuf(Var Buf; Len: LongInt): LongInt;
    Function  WriteBuf(Var Buf; Len: LongInt): LongInt;
    Function  WaitForData(TimeOut: LongInt): LongInt;

    { State }
    Procedure Disconnect;

    Property  Connected: Boolean Read FConnected;
    Property  TransportType: TTransportType Read FType;
  End;

Implementation

Uses
  SysUtils,
  m_io_Sockets
  {$IFDEF GO32V2}
  , m_io_fossil
  {$ENDIF}
  ;

Constructor TTransport.Create(AType: TTransportType);
Begin
  Inherited Create;
  FType := AType;
  FIO := Nil;
  FConnected := False;
End;

Destructor TTransport.Destroy;
Begin
  Disconnect;
  Inherited;
End;

Function TTransport.Listen(Port: Word): Boolean;
Begin
  Result := False;
  Case FType of
    ttTCP: Begin
      FIO := TIOSocket.Create;
      { TODO: bind and listen }
      Result := True;
    End;
    ttSerial: Begin
      {$IFDEF GO32V2}
      { Try FOSSIL first, falls back to direct UART }
      FIO := TIOFossil.Create(1, 38400);  { COM1, 38400 baud default }
      FConnected := True;
      Result := True;
      {$ELSE}
      { Serial not available on this platform }
      {$ENDIF}
    End;
  End;
End;

Function TTransport.Accept: TTransport;
Begin
  Result := Nil;
  { TCP: accept socket. Serial: carrier detect = accepted }
End;

Function TTransport.Connect(Host: String; Port: Word): Boolean;
Begin
  Result := False;
  Case FType of
    ttTCP: Begin
      FIO := TIOSocket.Create;
      If TIOSocket(FIO).Connect(Host, Port) Then Begin
        FConnected := True;
        Result := True;
      End;
    End;
    ttSerial: Begin
      {$IFDEF GO32V2}
      FIO := TIOFossil.Create(1, 38400);
      FConnected := True;
      Result := True;
      {$ENDIF}
    End;
  End;
End;

Function TTransport.DataWaiting: Boolean;
Begin
  If FIO <> Nil Then Result := FIO.DataWaiting
  Else Result := False;
End;

Function TTransport.ReadBuf(Var Buf; Len: LongInt): LongInt;
Begin
  If FIO <> Nil Then Result := FIO.ReadBuf(Buf, Len)
  Else Result := 0;
End;

Function TTransport.WriteBuf(Var Buf; Len: LongInt): LongInt;
Begin
  If FIO <> Nil Then Result := FIO.WriteBuf(Buf, Len)
  Else Result := 0;
End;

Function TTransport.WaitForData(TimeOut: LongInt): LongInt;
Begin
  If FIO <> Nil Then Result := FIO.WaitForData(TimeOut)
  Else Result := 0;
End;

Procedure TTransport.Disconnect;
Begin
  If FIO <> Nil Then Begin FIO.Free; FIO := Nil; End;
  FConnected := False;
End;

End.
