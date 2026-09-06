// ====================================================================
// mystic_modem : legacy dialup / serial support for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// mdm_serial - a thin, cross-platform serial-port layer built on Free
// Pascal's standard `Serial` unit.  Works on Win32 (COM ports, named
// "COM1", "COM2", ... or "\\.\COMxx" for high ports) and on Unix/Linux
// (/dev/ttyS0, /dev/ttyUSB0, ...).  No platform #ifdefs are needed in
// callers - they just pass a device name.
// ====================================================================

Unit mdm_Serial;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  Serial;    // FPC RTL unit: SerOpen/SerClose/SerRead/SerWrite/Ser*state lines

Type
  TSerialParity = (spNone, spOdd, spEven);

  TModemSerial = Class
  Private
    FHandle   : TSerialHandle;
    FIsOpen   : Boolean;
    FDevice   : String;
    FBaud     : LongInt;
  Public
    Constructor Create;
    Destructor  Destroy; Override;

    // Open the named serial device (e.g. 'COM1' or '/dev/ttyS0').
    // Returns True on success.  Sets 8N1 at the given baud with RTS/CTS
    // hardware flow control (the sane default for modem links).
    Function  Open (Const DeviceName: String; Baud: LongInt;
                    HardwareFlow: Boolean = True): Boolean;
    Procedure Close;

    // Raw I/O.  Read is non-blocking-ish: returns however many bytes were
    // available (0 if none).  Write returns bytes actually written.
    Function  ReadBuf  (Var Buffer; Count: LongInt): LongInt;
    Function  WriteBuf (Var Buffer; Count: LongInt): LongInt;

    // Convenience string helpers for AT command work.
    Function  WriteStr (Const S: String): LongInt;
    Function  ReadAvail: String;               // drain whatever is waiting

    Procedure Flush;

    // Control / status lines.
    Procedure SetDTR (OnOff: Boolean);
    Procedure SetRTS (OnOff: Boolean);
    Function  GetCTS: Boolean;                 // clear to send
    Function  GetDSR: Boolean;                 // data set ready
    Function  GetRing: Boolean;                // ring indicator (RI)

    // Dropping DTR is the standard "hang up the modem" hardware signal.
    Procedure DropDTR;

    Property IsOpen : Boolean Read FIsOpen;
    Property Device : String  Read FDevice;
    Property Baud   : LongInt Read FBaud;
    Property Handle : TSerialHandle Read FHandle;
  End;

Implementation

Constructor TModemSerial.Create;
Begin
  Inherited Create;
  FHandle := -1;
  FIsOpen := False;
  FDevice := '';
  FBaud   := 0;
End;

Destructor TModemSerial.Destroy;
Begin
  If FIsOpen Then Close;
  Inherited Destroy;
End;

Function TModemSerial.Open (Const DeviceName: String; Baud: LongInt;
                            HardwareFlow: Boolean): Boolean;
Var
  Flags : TSerialFlags;
Begin
  Result := False;
  If FIsOpen Then Close;

  FHandle := SerOpen(DeviceName);

  // SerOpen returns a handle <= 0 on failure (0 on Unix is stdin, never a tty
  // we opened here; treat <= 0 as failure to be safe across platforms).
  If FHandle <= 0 Then Exit;

  Flags := [];
  If HardwareFlow Then Flags := [RtsCtsFlowControl];

  // 8 data bits, no parity, 1 stop bit - the universal modem default.
  SerSetParams(FHandle, Baud, 8, NoneParity, 1, Flags);

  // Assert DTR + RTS so the modem sees us as "ready".
  SerSetDTR(FHandle, True);
  SerSetRTS(FHandle, True);

  FDevice := DeviceName;
  FBaud   := Baud;
  FIsOpen := True;
  Result  := True;
End;

Procedure TModemSerial.Close;
Begin
  If Not FIsOpen Then Exit;
  SerClose(FHandle);
  FHandle := -1;
  FIsOpen := False;
End;

Function TModemSerial.ReadBuf (Var Buffer; Count: LongInt): LongInt;
Begin
  If Not FIsOpen Then Begin Result := 0; Exit; End;
  Result := SerRead(FHandle, Buffer, Count);
  If Result < 0 Then Result := 0;
End;

Function TModemSerial.WriteBuf (Var Buffer; Count: LongInt): LongInt;
Begin
  If Not FIsOpen Then Begin Result := 0; Exit; End;
  Result := SerWrite(FHandle, Buffer, Count);
  If Result < 0 Then Result := 0;
End;

Function TModemSerial.WriteStr (Const S: String): LongInt;
Var
  Tmp : String;
Begin
  If (Not FIsOpen) or (Length(S) = 0) Then Begin Result := 0; Exit; End;
  Tmp := S;                              // mutable copy: SerWrite takes var Buffer
  Result := SerWrite(FHandle, Tmp[1], Length(Tmp));
  If Result < 0 Then Result := 0;
End;

Function TModemSerial.ReadAvail: String;
Var
  Buf : Array[0..255] of Char;
  N   : LongInt;
  Old : LongInt;
Begin
  Result := '';
  If Not FIsOpen Then Exit;
  Repeat
    N := SerRead(FHandle, Buf, SizeOf(Buf));
    If N > 0 Then Begin
      Old := Length(Result);
      SetLength(Result, Old + N);
      Move(Buf, Result[Old + 1], N);
    End;
  Until N <= 0;
End;

Procedure TModemSerial.Flush;
Begin
  If FIsOpen Then SerFlush(FHandle);
End;

Procedure TModemSerial.SetDTR (OnOff: Boolean);
Begin If FIsOpen Then SerSetDTR(FHandle, OnOff); End;

Procedure TModemSerial.SetRTS (OnOff: Boolean);
Begin If FIsOpen Then SerSetRTS(FHandle, OnOff); End;

Function TModemSerial.GetCTS: Boolean;
Begin Result := FIsOpen and SerGetCTS(FHandle); End;

Function TModemSerial.GetDSR: Boolean;
Begin Result := FIsOpen and SerGetDSR(FHandle); End;

Function TModemSerial.GetRing: Boolean;
Begin Result := FIsOpen and SerGetRI(FHandle); End;

Procedure TModemSerial.DropDTR;
Begin
  If Not FIsOpen Then Exit;
  SerSetDTR(FHandle, False);
End;

End.
