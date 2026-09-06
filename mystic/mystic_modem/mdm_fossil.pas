// ====================================================================
// mystic_modem : legacy dialup / serial support for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// mdm_fossil - a FOSSIL-style communications abstraction.
//
// FOSSIL ("Fido/Opus/SEAdog Standard Interface Layer") is the classic BBS
// serial API, historically an INT 14h driver (X00, BNU) under DOS.  Native
// 32-bit programs cannot issue INT 14h, so this unit presents the FAMILIAR
// FOSSIL API SHAPE (init/deinit, tx/rx, carrier, DTR, flush, status) on top
// of interchangeable backends:
//
//   * fbSerial : real serial hardware via mdm_serial (Win32 COMx / Unix tty)
//                - the working native backend.
//   * fbInt14  : real FOSSIL INT 14h - compiled ONLY for a DOS target
//                ({$IFDEF MSDOS}/{$IFDEF GO32V2}); a stub elsewhere.  This is
//                where X00/BNU or a NetFoss-style driver is reached on DOS.
//
// Code written against TFossil therefore looks and behaves like traditional
// FOSSIL BBS code, but runs on modern systems through the serial backend and
// can drop onto real DOS+FOSSIL unchanged.
// ====================================================================

Unit mdm_Fossil;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  mdm_Serial;

Type
  TFossilBackend = (fbSerial, fbInt14);

  // Mirrors the classic FOSSIL "driver info" (function 1Bh) fields that BBS
  // code commonly reads.  Sizes are the useful subset, not the full 34 bytes.
  TFossilInfo = Record
    CurrBaud : LongInt;    // current line rate
    RxFree   : LongInt;    // receive buffer space free
    TxFree   : LongInt;    // transmit buffer space free
    Carrier  : Boolean;    // DCD present
    CTS      : Boolean;
    DSR      : Boolean;
  End;

  TFossil = Class
  Private
    FBackend : TFossilBackend;
    FSer     : TModemSerial;    // used when FBackend = fbSerial
    FOwnsSer : Boolean;
    FPort    : Word;            // FOSSIL port number (INT14h backend)
    FActive  : Boolean;
  Public
    // Serial backend: wrap an existing (already-open or to-be-opened) serial
    // object.  If ASer is nil, one is created and owned internally.
    Constructor CreateSerial (ASer: TModemSerial = Nil);
    // INT 14h backend: FOSSIL port number (0 = COM1).  Real only on DOS.
    Constructor CreateInt14 (PortNum: Word);
    Destructor  Destroy; Override;

    // Function 04h: initialise the driver / open the port.
    Function  Init (Const DeviceName: String; Baud: LongInt): Boolean;
    // Function 05h: deinitialise / close.
    Procedure Deinit;

    // Function 01h/02h: transmit; 0Ch/02h: receive.
    Function  Send (Const S: String): LongInt;
    Function  SendByte (B: Byte): Boolean;
    Function  Recv: String;                 // drain input
    Function  RecvReady: Boolean;           // function 03h bit: chars waiting

    // Function 03h: line/modem status.
    Function  CarrierDetect: Boolean;       // DCD
    Procedure SetDTR (OnOff: Boolean);      // function 06h
    Procedure Flush;                        // function 08h (purge/flush output)
    Procedure PurgeInput;                   // function 0Ah
    Function  GetInfo: TFossilInfo;         // function 1Bh (subset)

    Property Backend : TFossilBackend Read FBackend;
    Property Active  : Boolean Read FActive;
    Property Serial  : TModemSerial Read FSer;
  End;

Implementation

{$IFDEF MSDOS}{$DEFINE FOSSIL_INT14}{$ENDIF}
{$IFDEF GO32V2}{$DEFINE FOSSIL_INT14}{$ENDIF}

{$IFDEF FOSSIL_INT14}
Uses
  Dos;   // for Registers / Intr on a real DOS target
{$ENDIF}

Constructor TFossil.CreateSerial (ASer: TModemSerial);
Begin
  Inherited Create;
  FBackend := fbSerial;
  FActive  := False;
  FPort    := 0;
  If ASer = Nil Then Begin
    FSer     := TModemSerial.Create;
    FOwnsSer := True;
  End Else Begin
    FSer     := ASer;
    FOwnsSer := False;
  End;
End;

Constructor TFossil.CreateInt14 (PortNum: Word);
Begin
  Inherited Create;
  FBackend := fbInt14;
  FActive  := False;
  FPort    := PortNum;
  FSer     := Nil;
  FOwnsSer := False;
End;

Destructor TFossil.Destroy;
Begin
  If FActive Then Deinit;
  If FOwnsSer and Assigned(FSer) Then FSer.Free;
  Inherited Destroy;
End;

// --------------------------------------------------------------------
// INT 14h helpers - real only on a DOS target; harmless stubs elsewhere.
// --------------------------------------------------------------------
{$IFDEF FOSSIL_INT14}
Function Int14 (AH: Byte; AL: Byte; Port: Word): Word;
Var
  R : Registers;
Begin
  R.AH := AH;
  R.AL := AL;
  R.DX := Port;
  Intr($14, R);
  Int14 := R.AX;
End;
{$ENDIF}

Function TFossil.Init (Const DeviceName: String; Baud: LongInt): Boolean;
Begin
  Result := False;
  Case FBackend of
    fbSerial :
      Begin
        Result  := FSer.Open(DeviceName, Baud, True);
        FActive := Result;
      End;
    fbInt14 :
      Begin
        {$IFDEF FOSSIL_INT14}
          // Function 04h: initialise FOSSIL on FPort.  AX=$1954 confirms driver.
          If Int14($04, $00, FPort) = $1954 Then Begin
            FActive := True;
            Result  := True;
          End;
        {$ELSE}
          // No INT 14h off DOS.  Caller should use the serial backend instead.
          Result  := False;
          FActive := False;
        {$ENDIF}
      End;
  End;
End;

Procedure TFossil.Deinit;
Begin
  If Not FActive Then Exit;
  Case FBackend of
    fbSerial : FSer.Close;
    fbInt14  : {$IFDEF FOSSIL_INT14} Int14($05, $00, FPort); {$ENDIF} ;
  End;
  FActive := False;
End;

Function TFossil.Send (Const S: String): LongInt;
Begin
  Result := 0;
  If Not FActive Then Exit;
  Case FBackend of
    fbSerial : Result := FSer.WriteStr(S);
    fbInt14  :
      {$IFDEF FOSSIL_INT14}
        Begin
          For Result := 1 to Length(S) Do
            Int14($01, Byte(S[Result]), FPort);
          Result := Length(S);
        End;
      {$ELSE} Result := 0;
      {$ENDIF}
  End;
End;

Function TFossil.SendByte (B: Byte): Boolean;
Var
  C : Char;
Begin
  Result := False;
  If Not FActive Then Exit;
  Case FBackend of
    fbSerial : Begin C := Chr(B); Result := FSer.WriteBuf(C, 1) = 1; End;
    fbInt14  : {$IFDEF FOSSIL_INT14} Begin Int14($01, B, FPort); Result := True; End;
               {$ELSE} Result := False; {$ENDIF}
  End;
End;

Function TFossil.Recv: String;
Begin
  Result := '';
  If Not FActive Then Exit;
  Case FBackend of
    fbSerial : Result := FSer.ReadAvail;
    fbInt14  :
      {$IFDEF FOSSIL_INT14}
        While (Int14($03, $00, FPort) and $0100) <> 0 Do
          Result := Result + Chr(Lo(Int14($02, $00, FPort)));
      {$ELSE} ;
      {$ENDIF}
  End;
End;

Function TFossil.RecvReady: Boolean;
Begin
  Result := False;
  If Not FActive Then Exit;
  Case FBackend of
    fbSerial : Result := FSer.GetDSR;   // proxy: data path is live
    fbInt14  : {$IFDEF FOSSIL_INT14} Result := (Int14($03, $00, FPort) and $0100) <> 0;
               {$ELSE} Result := False; {$ENDIF}
  End;
End;

Function TFossil.CarrierDetect: Boolean;
Begin
  Result := False;
  If Not FActive Then Exit;
  Case FBackend of
    // On serial, DSR is the portable carrier proxy the FPC unit exposes.
    fbSerial : Result := FSer.GetDSR;
    fbInt14  : {$IFDEF FOSSIL_INT14} Result := (Int14($03, $00, FPort) and $0080) <> 0;
               {$ELSE} Result := False; {$ENDIF}
  End;
End;

Procedure TFossil.SetDTR (OnOff: Boolean);
Begin
  If Not FActive Then Exit;
  Case FBackend of
    fbSerial : FSer.SetDTR(OnOff);
    fbInt14  : {$IFDEF FOSSIL_INT14} If OnOff Then Int14($06, $01, FPort)
                                     Else Int14($06, $00, FPort); {$ENDIF} ;
  End;
End;

Procedure TFossil.Flush;
Begin
  If Not FActive Then Exit;
  Case FBackend of
    fbSerial : FSer.Flush;
    fbInt14  : {$IFDEF FOSSIL_INT14} Int14($08, $00, FPort); {$ENDIF} ;
  End;
End;

Procedure TFossil.PurgeInput;
Begin
  If Not FActive Then Exit;
  Case FBackend of
    fbSerial : FSer.ReadAvail;   // drain and discard
    fbInt14  : {$IFDEF FOSSIL_INT14} Int14($0A, $00, FPort); {$ENDIF} ;
  End;
End;

Function TFossil.GetInfo: TFossilInfo;
Begin
  FillChar(Result, SizeOf(Result), 0);
  If Not FActive Then Exit;
  Case FBackend of
    fbSerial :
      Begin
        Result.CurrBaud := FSer.Baud;
        Result.Carrier  := FSer.GetDSR;
        Result.CTS      := FSer.GetCTS;
        Result.DSR      := FSer.GetDSR;
        Result.RxFree   := 0;   // serial layer is unbuffered here
        Result.TxFree   := 0;
      End;
    fbInt14 :
      {$IFDEF FOSSIL_INT14}
        Begin
          Result.Carrier := (Int14($03, $00, FPort) and $0080) <> 0;
          Result.CTS     := (Int14($03, $00, FPort) and $0010) <> 0;
          Result.DSR     := (Int14($03, $00, FPort) and $0020) <> 0;
        End;
      {$ELSE} ;
      {$ENDIF}
  End;
End;

End.
