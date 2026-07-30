// ====================================================================
// Mystic BBS IRC Fork — GPLv3
// ====================================================================
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ====================================================================

// ====================================================================
// m_serial.pas — OOP serial wrapper for Mystic BBS
// ====================================================================
//
// THIS IS THE BBS LAYER. NOT THE HARDWARE LAYER.
//
// This unit wraps sysop/0's serial.pas (in mdl/) into a TModemSerial
// class that m_fossil_io.pas uses. Do NOT edit serial.pas here — edit
// the master copy in examples/serial/ and sync to mdl/.
//
// DEPENDENCY CHAIN:
//   m_serial.pas (this file, OOP wrapper)
//     → serial.pas (sysop/0's hardware layer, in mdl/)
//       → serial_irq.pas (kiddo's IRQ ring buffer, in mdl/, DOS only)
//
// WIRING INTO MYSTIC:
//   mystic.pas -COM1 -FOSSIL
//     → m_io_fossil.pas (TIOBase adapter)
//       → m_fossil_io.pas (FOSSIL API shape)
//         → m_serial.pas (THIS FILE — TModemSerial class)
//           → serial.pas (direct UART/OS serial access)
//
// FEATURES (all delegated to serial.pas):
//   Open/Close, Read/Write, DTR/RTS/CTS/DSR/DCD/RI,
//   UART detection (8250/16450/16550A/16750),
//   FIFO control (16550+ trigger level),
//   IRQ-driven ring buffer (DOS FOSSIL-grade),
//   DataAvailable (non-blocking check),
//   SerFlush (input + output)
//
// CREDITS:
//   sysop/0  — serial.pas hardware layer, DOS UART/IRQ implementation
//   evga     — m_fossil_io.pas FOSSIL abstraction, m_io_fossil.pas adapter
//   wrench   — tork netmodem2irc integration
//
// DO NOT put serial.pas in mystic/ or mystic_test/.
// It lives in mdl/ (compile path) and examples/serial/ (standalone).
// ====================================================================

Unit m_serial;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  Serial    // FPC RTL unit: SerOpen/SerClose/SerRead/SerWrite/Ser*state lines
  {$IFDEF GO32V2}
  , serial_irq  // kiddo: IRQ-driven ring buffer for DOS UART
  {$ENDIF}
  {$IFDEF MSDOS}
  , serial_irq
  {$ENDIF}
  ;

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
    Function  GetDCD: Boolean;                 // data carrier detect

    // Data available check (non-blocking)
    Function  DataAvailable: Boolean;

    // UART detection (DOS: 8250/16450/16550A/16750, others: 'native')
    Function  DetectUART: String;

    // FIFO control (16550+ UART)
    Procedure SetFIFO(Enable: Boolean; TriggerLevel: Byte);

    // IRQ-driven receive for DOS (FOSSIL-grade ring buffer)
    Procedure EnableIRQ;
    Procedure DisableIRQ;

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

  {$IFDEF GO32V2}
  SerEnableIRQ(FHandle);    // kiddo: activate IRQ ring buffer on DOS
  {$ENDIF}
  {$IFDEF MSDOS}
  SerEnableIRQ(FHandle);
  {$ENDIF}

  Result  := True;
End;

Procedure TModemSerial.Close;
Begin
  If Not FIsOpen Then Exit;

  {$IFDEF GO32V2}
  SerDisableIRQ(FHandle);   // kiddo: deactivate IRQ ring buffer
  {$ENDIF}
  {$IFDEF MSDOS}
  SerDisableIRQ(FHandle);
  {$ENDIF}

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

Function TModemSerial.GetDCD: Boolean;
Begin Result := FIsOpen and SerGetDCD(FHandle); End;

Function TModemSerial.DataAvailable: Boolean;
Begin Result := FIsOpen and SerDataAvailable(FHandle); End;

Function TModemSerial.DetectUART: String;
Begin
  If FIsOpen Then
    Result := SerDetectUART(FHandle)
  Else
    Result := 'closed';
End;

Procedure TModemSerial.SetFIFO(Enable: Boolean; TriggerLevel: Byte);
Begin
  If FIsOpen Then SerSetFIFO(FHandle, Enable, TriggerLevel);
End;

Procedure TModemSerial.EnableIRQ;
Begin
  If FIsOpen Then SerEnableIRQ(FHandle);
End;

Procedure TModemSerial.DisableIRQ;
Begin
  If FIsOpen Then SerDisableIRQ(FHandle);
End;

Procedure TModemSerial.DropDTR;
Begin
  If Not FIsOpen Then Exit;
  SerSetDTR(FHandle, False);
End;

End.
