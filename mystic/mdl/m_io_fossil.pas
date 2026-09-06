Unit m_io_fossil;

// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
// 1.11IRC A7: TIOFossil -- TIOBase adapter for FOSSIL/serial I/O
//
// Allows mystic.exe to use a FOSSIL driver or serial port for
// remote I/O instead of a TCP socket. Extends TIOBase so the
// rest of the BBS code works unchanged.
//
// Usage: mystic -COM1 -FOSSIL -B38400
//   Creates TIOFossil instead of TIOSocket as Session.Client
//
// DOS:   INT 14h FOSSIL driver via m_fossil.pas
// Win32: COM port via m_serial.pas
// Unix:  /dev/ttyS* via m_serial.pas
// ====================================================================

{$I M_OPS.PAS}

Interface

Uses
  m_io_Base,
  m_Fossil_IO;

Type
  TIOFossil = Class(TIOBase)
    Fossil    : TFossil;
    PortNum   : Byte;
    BaudRate  : LongInt;
    Connected : Boolean;

    Constructor Create (APort: Byte; ABaud: LongInt);
    Destructor  Destroy; Override;

    Function    DataWaiting : Boolean; Override;
    Function    WriteBuf    (Var Buf; Len: LongInt) : LongInt; Override;
    Function    ReadBuf     (Var Buf; Len: LongInt) : LongInt; Override;
    Procedure   BufFlush; Override;
    Procedure   PurgeInputData (DrainWait: LongInt); Override;
    Procedure   PurgeOutputData; Override;
  End;

Implementation

Uses
  m_Strings;

Constructor TIOFossil.Create (APort: Byte; ABaud: LongInt);
Var
  DevName : String;
Begin
  Inherited Create;

  PortNum  := APort;
  BaudRate := ABaud;

  {$IFDEF GO32V2}
    Fossil := TFossil.CreateInt14(PortNum - 1);
    DevName := 'COM' + strI2S(PortNum);
  {$ELSE}
    Fossil := TFossil.CreateSerial(NIL);
    {$IFDEF WINDOWS}
      DevName := 'COM' + strI2S(PortNum);
    {$ELSE}
      DevName := '/dev/ttyS' + strI2S(PortNum - 1);
    {$ENDIF}
  {$ENDIF}

  Connected := Fossil.Init(DevName, BaudRate);
End;

Destructor TIOFossil.Destroy;
Begin
  If Fossil <> NIL Then Begin
    Fossil.Deinit;
    Fossil.Free;
  End;

  Inherited Destroy;
End;

Function TIOFossil.DataWaiting : Boolean;
Begin
  Result := Connected and Fossil.RecvReady;
End;

Function TIOFossil.WriteBuf (Var Buf; Len: LongInt) : LongInt;
Var
  Data : Array[0..4095] of Char Absolute Buf;
  S    : String;
  I    : LongInt;
Begin
  Result := 0;
  If Not Connected Then Exit;
  S := '';
  For I := 0 to Len - 1 Do
    S := S + Data[I];
  Result := Fossil.Send(S);
End;

Function TIOFossil.ReadBuf (Var Buf; Len: LongInt) : LongInt;
Var
  Data : Array[0..4095] of Char Absolute Buf;
  S    : String;
  I    : LongInt;
Begin
  Result := 0;
  If Not Connected Then Exit;
  S := Fossil.Recv;
  If Length(S) > Len Then
    S := Copy(S, 1, Len);
  For I := 1 to Length(S) Do
    Data[I - 1] := S[I];
  Result := Length(S);
End;

Procedure TIOFossil.BufFlush;
Begin
  If Connected Then Fossil.Flush;
End;

Procedure TIOFossil.PurgeInputData (DrainWait: LongInt);
Begin
  If Connected Then Fossil.PurgeInput;
End;

Procedure TIOFossil.PurgeOutputData;
Begin
  If Connected Then Fossil.Flush;
End;

End.
