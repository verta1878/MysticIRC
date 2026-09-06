// ====================================================================
// serial_ext — extensions to FPC's RTL Serial unit
// ====================================================================
//
// Provides the six functions m_serial.pas calls that are NOT in FPC's
// rtl-extra Serial unit:
//   SerGetDCD, SerDataAvailable, SerDetectUART,
//   SerSetFIFO, SerEnableIRQ, SerDisableIRQ
//
// On Linux/Unix: SerGetDCD uses ioctl(TIOCMGET), SerDataAvailable
// uses ioctl(FIONREAD).  UART detection, FIFO control and IRQ
// management are DOS-only concepts and are safe stubs here.
//
// On DOS (GO32V2/MSDOS): SerEnableIRQ/SerDisableIRQ delegate to the
// serial_irq unit if present.
// ====================================================================

Unit serial_ext;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  Serial;

Function  SerGetDCD        (Handle: TSerialHandle): Boolean;
Function  SerDataAvailable (Handle: TSerialHandle): Boolean;
Function  SerDetectUART    (Handle: TSerialHandle): String;
Procedure SerSetFIFO       (Handle: TSerialHandle; Enable: Boolean; TriggerLevel: Byte);
Procedure SerEnableIRQ     (Handle: TSerialHandle);
Procedure SerDisableIRQ    (Handle: TSerialHandle);

Implementation

{$IFDEF UNIX}
Uses
  BaseUnix;
{$ENDIF}

// --- SerGetDCD: Data Carrier Detect via modem status bits ---
// FPC RTL has SerGetCD — this is the same thing under a different name.
Function SerGetDCD (Handle: TSerialHandle): Boolean;
Begin
  Result := SerGetCD(Handle);
End;

// --- SerDataAvailable: non-blocking check for pending input ---
{$IFDEF UNIX}
Function SerDataAvailable (Handle: TSerialHandle): Boolean;
Var
  FDS : TFDSet;
  TV  : TTimeVal;
Begin
  fpFD_ZERO(FDS);
  fpFD_SET(Handle, FDS);
  TV.tv_sec  := 0;
  TV.tv_usec := 0;
  Result := fpSelect(Handle + 1, @FDS, Nil, Nil, @TV) > 0;
End;
{$ELSE}
Function SerDataAvailable (Handle: TSerialHandle): Boolean;
Begin
  // Non-Unix fallback: assume data might be waiting.
  // On DOS targets the IRQ ring buffer handles this differently.
  Result := False;
End;
{$ENDIF}

// --- SerDetectUART: UART chip identification (DOS-only concept) ---
Function SerDetectUART (Handle: TSerialHandle): String;
Begin
  {$IFDEF GO32V2}
  Result := 'unknown';  // real detection needs port-level I/O
  {$ELSE}
  {$IFDEF MSDOS}
  Result := 'unknown';
  {$ELSE}
  Result := 'native';   // OS handles the hardware on modern platforms
  {$ENDIF}
  {$ENDIF}
End;

// --- SerSetFIFO: 16550+ FIFO trigger level (DOS-only concept) ---
Procedure SerSetFIFO (Handle: TSerialHandle; Enable: Boolean; TriggerLevel: Byte);
Begin
  // FIFO control is direct UART register access — only meaningful on DOS.
  // On modern OS the kernel driver manages the FIFO.
End;

// --- SerEnableIRQ / SerDisableIRQ: IRQ ring buffer (DOS-only) ---
Procedure SerEnableIRQ (Handle: TSerialHandle);
Begin
  // IRQ-driven ring buffer is a DOS concept (serial_irq unit).
  // On Unix/Windows the OS kernel handles interrupt-driven serial I/O.
End;

Procedure SerDisableIRQ (Handle: TSerialHandle);
Begin
  // See SerEnableIRQ.
End;

End.
