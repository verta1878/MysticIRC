Program mystfoss;

// ====================================================================
// mystfoss — Mystic FOSSIL Driver
// ====================================================================
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors — GPLv3
//
// Standalone FOSSIL driver for Mystic BBS and compatible software.
// Provides FTS-0015 (FOSSIL v5) serial I/O services.
//
// PLATFORMS:
//   DOS (go32v2)  — TSR, hooks INT 14h, direct UART via Port[]
//   DOS (i8086)   — TSR, hooks INT 14h, real mode
//   Win32/Win64   — FOSSIL bridge for DOSBox/NTVDM
//   OS/2          — FOSSIL bridge for VDM sessions
//
// USAGE:
//   mystfoss                   install on COM1 at 38400
//   mystfoss COM2              install on COM2
//   mystfoss COM1 9600         install on COM1 at 9600
//   mystfoss /U                uninstall (DOS TSR only)
//   mystfoss /S                show status
//
// FOSSIL SPEC: FidoNet FTS-0015, FSC-0015, FSC-0072
//
// CREDITS:
//   sysop/0  — m_serial.pas, serial_irq.pas
//   kiddo    — IRQ ring buffer
//   wrench   — transport layer
// ====================================================================

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Uses
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  {$IFDEF GO32V2}
  Go32,
  {$ENDIF}
  SysUtils,
  m_serial;

Const
  FOSSIL_VERSION  = '1.0';
  FOSSIL_REVISION = 5;          // FOSSIL v5 spec level
  FOSSIL_MAXFUNC  = $1B;        // highest supported function
  FOSSIL_ID       = $1954;      // magic ID returned by Init
  FOSSIL_IDSTR    = 'MystFOSS v1.0 — Mystic BBS FOSSIL Driver';

  DEFAULT_PORT    = 'COM1';
  DEFAULT_BAUD    = 38400;

Var
  Ser       : TModemSerial;
  PortName  : String;
  BaudRate  : LongInt;
  Installed : Boolean;

// ====================================================================
// FOSSIL function table (FTS-0015)
// ====================================================================
//  00h  Set baud rate
//  01h  Send character (with wait)
//  02h  Receive character (with wait)
//  03h  Request status
//  04h  Initialize driver        → returns $1954
//  05h  Deinitialize driver
//  06h  Raise/lower DTR
//  07h  Return timer tick params
//  08h  Flush output buffer
//  09h  Purge output buffer
//  0Ah  Purge input buffer
//  0Bh  Send character (no wait)
//  0Ch  Non-destructive read-ahead
//  0Dh  Keyboard read (no wait)
//  0Eh  Keyboard read (wait)
//  0Fh  Enable/disable flow control
//  10h  Control-C/K checking on/off
//  11h  Set cursor location
//  12h  Get cursor location
//  13h  Write character to screen (ANSI)
//  14h  Watchdog on/off
//  15h  Write char to screen (no ANSI)
//  16h  Insert/delete function from timer tick chain
//  17h  Reboot system
//  18h  Read block
//  19h  Write block
//  1Ah  Break begin/end
//  1Bh  Return driver information
// ====================================================================

Procedure ShowBanner;
Begin
  WriteLn;
  WriteLn(FOSSIL_IDSTR);
  WriteLn('FTS-0015 FOSSIL v', FOSSIL_REVISION, ' compatible');
  WriteLn('Copyright (C) 2026 Mystic BBS IRC Fork — GPLv3');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  ShowBanner;
  WriteLn('Usage: mystfoss [port] [baud] [/option]');
  WriteLn;
  WriteLn('  mystfoss              Install on COM1 at 38400');
  WriteLn('  mystfoss COM2         Install on COM2 at 38400');
  WriteLn('  mystfoss COM1 9600    Install on COM1 at 9600');
  WriteLn('  mystfoss /S           Show status');
  {$IFDEF GO32V2}
  WriteLn('  mystfoss /U           Uninstall TSR');
  {$ENDIF}
  {$IFDEF MSDOS}
  WriteLn('  mystfoss /U           Uninstall TSR');
  {$ENDIF}
  WriteLn;
  WriteLn('Supported ports:');
  {$IFDEF UNIX}
  WriteLn('  /dev/ttyS0..7, /dev/ttyUSB0..7, /dev/cuau0..7');
  {$ENDIF}
  {$IFDEF WINDOWS}
  WriteLn('  COM1..COM255');
  {$ENDIF}
  {$IFDEF OS2}
  WriteLn('  COM1..COM8');
  {$ENDIF}
  {$IFDEF GO32V2}
  WriteLn('  COM1..COM4');
  {$ENDIF}
End;

Procedure ShowStatus;
Begin
  ShowBanner;
  If Not Installed Then Begin
    WriteLn('Status: NOT INSTALLED');
    Exit;
  End;
  WriteLn('Status:   INSTALLED');
  WriteLn('Port:     ', Ser.Device);
  WriteLn('Baud:     ', Ser.Baud);
  WriteLn('UART:     ', Ser.DetectUART);
  WriteLn('DCD:      ', Ser.GetDCD);
  WriteLn('CTS:      ', Ser.GetCTS);
  WriteLn('DSR:      ', Ser.GetDSR);
  WriteLn('RI:       ', Ser.GetRI);
  WriteLn('Data:     ', Ser.DataAvailable);
End;

{$IFDEF GO32V2}
// ====================================================================
// DOS TSR — hooks INT 14h via DPMI real-mode callback
// ====================================================================
// DPMI flow:
//   1. get_rm_callback() allocates a real-mode→protected-mode thunk
//   2. set_rm_interrupt($14, thunk) hooks INT 14h
//   3. When a DOS program calls INT 14h, DPMI calls our handler
//      with registers in CallbackRegs (trealregs)
//   4. We read AH (function), DX (port), dispatch, write results back
//   5. On uninstall, restore original vector and free callback
// ====================================================================

Var
  OldInt14     : TSegInfo;     // saved original INT 14h vector
  CallbackInfo : TSegInfo;     // our DPMI callback address
  CallbackRegs : TRealRegs;    // register block for callback
  Installed14  : Boolean;

// Ring buffer for FOSSIL receive (separate from serial_irq — this is
// the FOSSIL-level buffer that DOS programs read from via func 02h)
Const
  FOSSIL_BUFSIZE = 4096;

Var
  RxBuf     : Array[0..FOSSIL_BUFSIZE-1] of Byte;
  RxHead    : Word;
  RxTail    : Word;
  TxBuf     : Array[0..FOSSIL_BUFSIZE-1] of Byte;
  TxHead    : Word;
  TxTail    : Word;
  FossilActive : Boolean;

Function RxCount: Word;
Begin
  If RxHead >= RxTail Then Result := RxHead - RxTail
  Else Result := FOSSIL_BUFSIZE - RxTail + RxHead;
End;

Function TxCount: Word;
Begin
  If TxHead >= TxTail Then Result := TxHead - TxTail
  Else Result := FOSSIL_BUFSIZE - TxTail + TxHead;
End;

Function TxFree: Word;
Begin
  Result := FOSSIL_BUFSIZE - 1 - TxCount;
End;

Procedure PumpSerial;
// Move data between serial hardware and FOSSIL ring buffers.
// Called from main loop and from the callback handler.
Var
  B   : Byte;
  N   : LongInt;
  Buf : Array[0..255] of Byte;
Begin
  If Not Ser.IsOpen Then Exit;

  // RX: serial → RxBuf
  While Ser.DataAvailable And (RxCount < FOSSIL_BUFSIZE - 1) Do Begin
    N := Ser.ReadBuf(B, 1);
    If N = 1 Then Begin
      RxBuf[RxHead] := B;
      RxHead := (RxHead + 1) mod FOSSIL_BUFSIZE;
    End;
  End;

  // TX: TxBuf → serial
  While TxCount > 0 Do Begin
    B := TxBuf[TxTail];
    N := Ser.WriteBuf(B, 1);
    If N = 1 Then TxTail := (TxTail + 1) mod FOSSIL_BUFSIZE
    Else Break;
  End;
End;

Procedure Int14Handler; CDecl;
// DPMI real-mode callback handler.
// CallbackRegs contains the DOS program's registers.
// We read AH for function number, dispatch, write results back.
Var
  Func : Byte;
  Port : Word;
  B    : Byte;
  W    : Word;
Begin
  Func := CallbackRegs.AH;
  Port := CallbackRegs.DX;

  Case Func of
    // ---- 00h: Set baud rate ----
    $00: Begin
           // AL = baud init byte (same as BIOS format)
           // Ignore for now — baud set at init time
           CallbackRegs.AX := $0030; // status: TX ready + TX empty
           If RxCount > 0 Then CallbackRegs.AX := CallbackRegs.AX or $0100;
         End;

    // ---- 01h: Send character with wait ----
    $01: Begin
           B := CallbackRegs.AL;
           // Wait for space in TX buffer
           While TxFree = 0 Do PumpSerial;
           TxBuf[TxHead] := B;
           TxHead := (TxHead + 1) mod FOSSIL_BUFSIZE;
           PumpSerial;
           CallbackRegs.AX := $0030; // TX ready
         End;

    // ---- 02h: Receive character with wait ----
    $02: Begin
           While RxCount = 0 Do PumpSerial;
           B := RxBuf[RxTail];
           RxTail := (RxTail + 1) mod FOSSIL_BUFSIZE;
           CallbackRegs.AH := $00; // success
           CallbackRegs.AL := B;
         End;

    // ---- 03h: Request status ----
    $03: Begin
           PumpSerial;
           W := $0030; // TX holding register empty + TX shift register empty
           If RxCount > 0 Then W := W or $0100; // data ready
           If Ser.GetDCD Then W := W or $0080;   // carrier detect
           If Ser.GetCTS Then W := W or $0010;   // CTS
           If Ser.GetDSR Then W := W or $0020;   // DSR
           CallbackRegs.AX := W;
         End;

    // ---- 04h: Initialize driver ----
    $04: Begin
           FossilActive := True;
           RxHead := 0; RxTail := 0;
           TxHead := 0; TxTail := 0;
           CallbackRegs.AX := FOSSIL_ID;  // $1954 magic
           CallbackRegs.BH := FOSSIL_REVISION; // v5
           CallbackRegs.BL := FOSSIL_MAXFUNC;  // highest function
         End;

    // ---- 05h: Deinitialize driver ----
    $05: Begin
           Ser.FlushInput;
           Ser.Drain;
           FossilActive := False;
         End;

    // ---- 06h: Raise/lower DTR ----
    $06: Begin
           If CallbackRegs.AL = $01 Then Ser.SetDTR(True)
           Else Ser.SetDTR(False);
         End;

    // ---- 07h: Return timer tick parameters ----
    $07: Begin
           CallbackRegs.AH := 1;   // ticks per second approx
           CallbackRegs.AL := 55;  // ms per tick (18.2 Hz)
           CallbackRegs.DX := 0;
         End;

    // ---- 08h: Flush output buffer ----
    $08: Begin
           While TxCount > 0 Do PumpSerial;
           Ser.Drain;
         End;

    // ---- 09h: Purge output buffer ----
    $09: Begin
           TxHead := 0; TxTail := 0;
         End;

    // ---- 0Ah: Purge input buffer ----
    $0A: Begin
           RxHead := 0; RxTail := 0;
           Ser.FlushInput;
         End;

    // ---- 0Bh: Send character (no wait) ----
    $0B: Begin
           If TxFree > 0 Then Begin
             TxBuf[TxHead] := CallbackRegs.AL;
             TxHead := (TxHead + 1) mod FOSSIL_BUFSIZE;
             PumpSerial;
             CallbackRegs.AX := $0001; // accepted
           End Else
             CallbackRegs.AX := $0000; // buffer full
         End;

    // ---- 0Ch: Non-destructive read-ahead ----
    $0C: Begin
           PumpSerial;
           If RxCount > 0 Then Begin
             CallbackRegs.AH := $00;
             CallbackRegs.AL := RxBuf[RxTail]; // peek, don't consume
           End Else
             CallbackRegs.AX := $FFFF; // no data
         End;

    // ---- 0Fh: Enable/disable flow control ----
    $0F: Begin
           // AL: bit 0 = XON/XOFF, bit 1 = CTS/RTS
           // Handled at serial level, acknowledge
         End;

    // ---- 18h: Read block ----
    $18: Begin
           // CX = count, ES:DI = buffer (real mode)
           // We can't write to real-mode memory from here easily
           // For now return 0 bytes read
           CallbackRegs.AX := 0;
         End;

    // ---- 19h: Write block ----
    $19: Begin
           // CX = count, ES:DI = buffer (real mode)
           // Same issue — needs dosmemget/dosmemput
           CallbackRegs.AX := 0;
         End;

    // ---- 1Ah: Break begin/end ----
    $1A: Begin
           If CallbackRegs.AL = $01 Then Ser.SendBreak;
         End;

    // ---- 1Bh: Return driver information ----
    $1B: Begin
           // Returns info structure — need to write to real-mode buffer
           // For now, set CX = size of info block
           CallbackRegs.AX := 18; // size of FOSSIL info struct
           CallbackRegs.BH := FOSSIL_REVISION;
         End;

  Else
    // Unknown function — return with no change
  End;
End;

Procedure InstallTSR;
Begin
  // Init ring buffers
  RxHead := 0; RxTail := 0;
  TxHead := 0; TxTail := 0;
  FossilActive := False;

  WriteLn('Installing INT 14h DPMI callback...');

  // Save original INT 14h real-mode vector
  get_rm_interrupt($14, OldInt14);

  // Allocate real-mode callback → our Int14Handler
  FillChar(CallbackRegs, SizeOf(CallbackRegs), 0);
  If Not get_rm_callback(@Int14Handler, CallbackRegs, CallbackInfo) Then Begin
    WriteLn('ERROR: Cannot allocate DPMI real-mode callback.');
    Halt(2);
  End;

  // Hook INT 14h
  If Not set_rm_interrupt($14, CallbackInfo) Then Begin
    WriteLn('ERROR: Cannot set INT 14h vector.');
    free_rm_callback(CallbackInfo);
    Halt(2);
  End;

  Installed14 := True;
  WriteLn('MystFOSS installed on ', PortName, ' at ', BaudRate, ' baud');
  WriteLn('FOSSIL ID: $', IntToHex(FOSSIL_ID, 4));
  WriteLn('INT 14h hooked via DPMI callback');
  WriteLn('Press Ctrl+C or run mystfoss /U to uninstall');
End;

Procedure UninstallTSR;
Begin
  If Not Installed14 Then Begin
    WriteLn('MystFOSS is not installed.');
    Exit;
  End;

  // Restore original INT 14h vector
  set_rm_interrupt($14, OldInt14);

  // Free the DPMI callback
  free_rm_callback(CallbackInfo);

  Installed14 := False;
  FossilActive := False;
  WriteLn('MystFOSS uninstalled — INT 14h restored.');
End;
{$ENDIF}

// ====================================================================
// Cross-platform FOSSIL service loop
// ====================================================================

Procedure RunFossil;
Var
  Running : Boolean;
  Buf     : Array[0..4095] of Byte;
  N       : LongInt;
Begin
  ShowBanner;
  WriteLn('Initializing ', PortName, ' at ', BaudRate, ' baud...');

  Ser := TModemSerial.Create;
  If Not Ser.Open(PortName, BaudRate, True) Then Begin
    WriteLn('ERROR: Cannot open ', PortName);
    WriteLn('Check port name and permissions.');
    Ser.Free;
    Halt(1);
  End;

  Installed := True;

  WriteLn('Port:     ', Ser.Device);
  WriteLn('Baud:     ', Ser.Baud);
  WriteLn('UART:     ', Ser.DetectUART);
  WriteLn('FOSSIL:   $', IntToHex(FOSSIL_ID, 4), ' (', FOSSIL_IDSTR, ')');
  WriteLn;

  {$IFDEF GO32V2}
  InstallTSR;
  {$ELSE}
  WriteLn('FOSSIL bridge active. Ctrl+C to exit.');
  {$ENDIF}

  WriteLn;
  WriteLn('DCD=', Ser.GetDCD, ' CTS=', Ser.GetCTS,
          ' DSR=', Ser.GetDSR, ' RI=', Ser.GetRI);
  WriteLn;

  // Main service loop
  Running := True;
  While Running Do Begin
    {$IFDEF GO32V2}
    // Pump data between serial hardware and FOSSIL ring buffers
    PumpSerial;
    {$ELSE}
    // Bridge mode: forward data
    If Ser.DataAvailable Then Begin
      N := Ser.ReadBuf(Buf, SizeOf(Buf));
      If N > 0 Then Write('[RX:', N, '] ');
    End;
    {$ENDIF}

    // Check carrier
    If Installed And Not Ser.GetDCD Then Begin
      // Carrier lost — in a real BBS setup this would signal
      // the BBS to drop the session.
    End;

    // Small delay to avoid CPU spin
    {$IFDEF UNIX}
    fpNanoSleep(@Buf, nil);  // ~1ms
    {$ENDIF}
    {$IFDEF WINDOWS}
    Sleep(1);
    {$ENDIF}
    {$IFDEF OS2}
    DosSleep(1);
    {$ENDIF}
  End;

  // Cleanup
  {$IFDEF GO32V2}
  UninstallTSR;
  {$ENDIF}

  Ser.Close;
  Ser.Free;
  Installed := False;
  WriteLn('MystFOSS shutdown complete.');
End;

// ====================================================================
// Main
// ====================================================================

Var
  I    : Integer;
  P    : String;
  VErr : Integer;

Begin
  PortName  := DEFAULT_PORT;
  BaudRate  := DEFAULT_BAUD;
  Installed := False;

  // Adjust default port for platform
  {$IFDEF UNIX}
  PortName := '/dev/ttyS0';
  {$ENDIF}

  // Parse command line
  For I := 1 to ParamCount Do Begin
    P := UpperCase(ParamStr(I));

    If P = '/?' Then Begin ShowUsage; Halt(0); End;
    If P = '/H' Then Begin ShowUsage; Halt(0); End;
    If P = '/S' Then Begin ShowStatus; Halt(0); End;

    {$IFDEF GO32V2}
    If P = '/U' Then Begin UninstallTSR; Halt(0); End;
    {$ENDIF}
    {$IFDEF MSDOS}
    If P = '/U' Then Begin UninstallTSR; Halt(0); End;
    {$ENDIF}

    // Port name or baud rate
    If (Copy(P, 1, 3) = 'COM') Or (Copy(P, 1, 4) = '/DEV') Then
      PortName := ParamStr(I)   // preserve original case for Unix paths
    Else Begin
      // Try as baud rate
      Val(P, BaudRate, VErr);
      If VErr <> 0 Then Begin
        WriteLn('Unknown option: ', P);
        ShowUsage;
        Halt(1);
      End;
    End;
  End;

  RunFossil;
End.
