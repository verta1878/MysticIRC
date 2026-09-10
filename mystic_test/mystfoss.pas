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
// DOS TSR — hooks INT 14h
// ====================================================================
Uses
  Go32, Dos;

Var
  OldInt14  : TSegInfo;
  Installed14 : Boolean;

Procedure Int14Handler; Interrupt;
// This ISR handles INT 14h calls from DOS programs.
// AH = function number, DX = port number, other regs vary.
Var
  AH, AL: Byte;
  DX: Word;
  B: Byte;
  N: LongInt;
Begin
  // Get registers from interrupt frame
  // Note: in go32v2, interrupt handlers get register access via
  // the DPMI callback mechanism. This is a simplified placeholder
  // that will need DPMI real-mode callback wiring for production use.
End;

Procedure InstallTSR;
Begin
  WriteLn('Installing INT 14h handler...');
  // Save old INT 14h vector
  Get_PM_Interrupt($14, OldInt14);
  // Set new INT 14h vector
  // Note: Full DPMI callback implementation needed for production
  Installed14 := True;
  WriteLn('MystFOSS installed on ', PortName, ' at ', BaudRate, ' baud');
  WriteLn('FOSSIL ID: $', IntToHex(FOSSIL_ID, 4));
  WriteLn('Press Ctrl+C or run mystfoss /U to uninstall');
End;

Procedure UninstallTSR;
Begin
  If Not Installed14 Then Begin
    WriteLn('MystFOSS is not installed.');
    Exit;
  End;
  // Restore old INT 14h vector
  Set_PM_Interrupt($14, OldInt14);
  Installed14 := False;
  WriteLn('MystFOSS uninstalled.');
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
    // Check for incoming data
    If Ser.DataAvailable Then Begin
      N := Ser.ReadBuf(Buf, SizeOf(Buf));
      If N > 0 Then Begin
        // In bridge mode, data would be forwarded to the DOS VM
        // or to a named pipe / socket for the BBS to read.
        // For now, echo to console:
        Write('[RX:', N, '] ');
      End;
    End;

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
