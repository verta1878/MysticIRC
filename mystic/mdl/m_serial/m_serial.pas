// ====================================================================
// m_serial.pas — Mystic BBS Cross-Platform Serial I/O
// ====================================================================
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors — GPLv3
//
// Single OOP class for serial port access on 6 platforms.
// Replaces serial.pas + serial_ext.pas + old m_serial.pas.
//
// PLATFORMS:
//   DOS (go32v2/i8086) — direct UART 8250/16550 via Port[]
//   Linux              — termios via file descriptor
//   FreeBSD/OpenBSD    — termios via file descriptor
//   Darwin (Mac)       — termios via file descriptor
//   Windows            — CreateFile / DCB / COM API
//   OS/2               — DosOpen / DosDevIOCtl ASYNC
//
// DEPENDENCY:
//   m_serial_irq.pas — DOS only, IRQ-driven ring buffer (kiddo)
//
// WIRING INTO MYSTIC:
//   m_io_fossil.pas (TIOBase adapter)
//     → m_fossil.pas (FOSSIL driver)
//       → m_serial.pas (THIS FILE — TModemSerial class)
//
// CREDITS:
//   sysop/0  — DOS UART implementation, cross-platform port
//   kiddo    — m_serial_irq.pas ring buffer
//   evga     — FOSSIL abstraction, SIO rebuild
//   wrench   — transport, FOSSIL, DVI/HDMI
// ====================================================================

Unit m_serial;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

{$IFDEF UNIX}
Uses BaseUnix, termio, Unix;
{$ENDIF}
{$IFDEF WINDOWS}
Uses Windows;
{$ENDIF}
{$IFDEF OS2}
Uses DosCalls;
{$ENDIF}
{$IFDEF GO32V2}
Uses Ports, m_serial_irq;
{$ENDIF}
{$IFDEF MSDOS}
Uses m_serial_irq;
{$ENDIF}

Type
  TSerialHandle = LongInt;
  TSerialParity = (spNone, spOdd, spEven, spMark, spSpace);

  TModemSerial = Class
  Private
    FHandle   : TSerialHandle;
    FIsOpen   : Boolean;
    FDevice   : String;
    FBaud     : LongInt;
    {$IFDEF GO32V2}
    FBase     : Word;
    {$ENDIF}
    Procedure SetParams(Baud: LongInt; DataBits: Integer;
                Parity: TSerialParity; StopBits: Integer; HWFlow: Boolean);
  Public
    Constructor Create;
    Destructor  Destroy; Override;

    // Connection
    Function  Open (Const DeviceName: String; Baud: LongInt;
                    HardwareFlow: Boolean = True): Boolean;
    Procedure Close;

    // Raw I/O
    Function  ReadBuf  (Var Buffer; Count: LongInt): LongInt;
    Function  WriteBuf (Var Buffer; Count: LongInt): LongInt;
    Function  ReadTimeout (Var Buffer; Count: LongInt; TimeoutMS: LongInt): LongInt;

    // Convenience
    Function  WriteStr (Const S: String): LongInt;
    Function  ReadAvail: String;

    // Buffer control
    Procedure Flush;
    Procedure FlushInput;
    Procedure FlushOutput;
    Procedure Drain;
    Procedure SendBreak;

    // Modem control lines
    Procedure SetDTR (State: Boolean);
    Procedure SetRTS (State: Boolean);
    Function  GetCTS: Boolean;
    Function  GetDSR: Boolean;
    Function  GetRI:  Boolean;
    Function  GetDCD: Boolean;
    Function  DataAvailable: Boolean;

    // Hardware info (DOS: real values, others: OS-level equivalents)
    Function  DetectUART: String;
    Procedure SetFIFO (Enable: Boolean; TriggerLevel: Byte);
    Function  GetBase: Word;

    // IRQ ring buffer (DOS only, stubs on other platforms)
    Procedure EnableIRQ;
    Procedure DisableIRQ;

    // Modem convenience
    Procedure DropDTR;

    Property IsOpen : Boolean Read FIsOpen;
    Property Device : String  Read FDevice;
    Property Baud   : LongInt Read FBaud;
    Property Handle : TSerialHandle Read FHandle;
  End;

Const
  InvalidSerialHandle = TSerialHandle(-1);

Implementation

{$IFDEF GO32V2}
Const
  COM_BASE: array[0..3] of Word = ($3F8, $2F8, $3E8, $2E8);
  UART_RBR = 0; UART_THR = 0; UART_IER = 1; UART_IIR = 2;
  UART_FCR = 2; UART_LCR = 3; UART_MCR = 4; UART_LSR = 5;
  UART_MSR = 6; UART_DLL = 0; UART_DLH = 1;
  LSR_DR = $01; LSR_THRE = $20; LSR_TEMT = $40;
  MCR_DTR = $01; MCR_RTS = $02;
  MSR_CTS = $10; MSR_DSR = $20; MSR_RI = $40; MSR_DCD = $80;
  UART_CLOCK = 115200;
{$ENDIF}

{$IFDEF UNIX}
Const
  TIOCM_DTR = $002;
  TIOCM_RTS = $004;
  TIOCM_CTS = $020;
  TIOCM_DSR = $100;
  TIOCM_RI  = $080;
  TIOCM_CD  = $040;
  TIOCMGET  = $5415;
  TIOCMSET  = $5418;
  TIOCMBIS  = $5416;
  TIOCMBIC  = $5417;
{$ENDIF}

{$IFDEF OS2}
Const
  IOCTL_ASYNC = $01;
Type
  TBaudRate   = record BaudRate: Cardinal; Fraction: Byte; end;
  TLineCtrl   = record DataBits, Parity, StopBits: Byte; end;
  TModemCtrl  = record OnMask, OffMask: Byte; end;
  TModemInput = record Signals: Byte; end;
{$ENDIF}

// ====================================================================
// Constructor / Destructor
// ====================================================================

Constructor TModemSerial.Create;
Begin
  Inherited Create;
  FHandle := InvalidSerialHandle;
  FIsOpen := False;
  FDevice := '';
  FBaud   := 0;
  {$IFDEF GO32V2}
  FBase   := 0;
  {$ENDIF}
End;

Destructor TModemSerial.Destroy;
Begin
  If FIsOpen Then Close;
  Inherited Destroy;
End;

// ====================================================================
// SetParams (private)
// ====================================================================

Procedure TModemSerial.SetParams(Baud: LongInt; DataBits: Integer;
  Parity: TSerialParity; StopBits: Integer; HWFlow: Boolean);
{$IFDEF GO32V2}
Var Div_: Word; LCR: Byte;
{$ENDIF}
{$IFDEF UNIX}
Var Tio: termios; Speed: Cardinal;
{$ENDIF}
{$IFDEF WINDOWS}
Var DCB: TDCB;
{$ENDIF}
{$IFDEF OS2}
Var BR: TBaudRate; LC: TLineCtrl; PL, DL: Cardinal;
{$ENDIF}
Begin
  {$IFDEF GO32V2}
  If Baud > 0 Then Div_ := UART_CLOCK div Baud Else Div_ := 12;
  Case DataBits of 5:LCR:=$00; 6:LCR:=$01; 7:LCR:=$02; Else LCR:=$03; End;
  If StopBits = 2 Then LCR := LCR or $04;
  Case Parity of
    spOdd: LCR:=LCR or $08; spEven: LCR:=LCR or $18;
    spMark: LCR:=LCR or $28; spSpace: LCR:=LCR or $38;
  Else End;
  Port[FBase+UART_LCR]:=LCR or $80;
  Port[FBase+UART_DLL]:=Lo(Div_); Port[FBase+UART_DLH]:=Hi(Div_);
  Port[FBase+UART_LCR]:=LCR;
  {$ENDIF}
  {$IFDEF UNIX}
  TCGetAttr(FHandle, Tio);
  Case Baud of
    300:Speed:=B300; 1200:Speed:=B1200; 2400:Speed:=B2400;
    4800:Speed:=B4800; 9600:Speed:=B9600; 19200:Speed:=B19200;
    38400:Speed:=B38400; 57600:Speed:=B57600; 115200:Speed:=B115200;
  Else Speed:=B9600; End;
  cfsetispeed(Tio, Speed); cfsetospeed(Tio, Speed);
  cfmakeraw(Tio);
  Tio.c_cflag := Tio.c_cflag and not CSIZE;
  Case DataBits of 5:Tio.c_cflag:=Tio.c_cflag or CS5; 6:Tio.c_cflag:=Tio.c_cflag or CS6;
    7:Tio.c_cflag:=Tio.c_cflag or CS7; Else Tio.c_cflag:=Tio.c_cflag or CS8; End;
  If StopBits=2 Then Tio.c_cflag:=Tio.c_cflag or CSTOPB
  Else Tio.c_cflag:=Tio.c_cflag and not CSTOPB;
  Case Parity of
    spOdd:  Tio.c_cflag:=Tio.c_cflag or PARENB or PARODD;
    spEven: Tio.c_cflag:=(Tio.c_cflag or PARENB) and not PARODD;
  Else Tio.c_cflag:=Tio.c_cflag and not PARENB; End;
  If HWFlow Then Tio.c_cflag:=Tio.c_cflag or CRTSCTS
  Else Tio.c_cflag:=Tio.c_cflag and not CRTSCTS;
  Tio.c_cflag:=Tio.c_cflag or CLOCAL or CREAD;
  Tio.c_cc[VMIN]:=0; Tio.c_cc[VTIME]:=1;
  TCSetAttr(FHandle, TCSANOW, Tio);
  {$ENDIF}
  {$IFDEF WINDOWS}
  FillChar(DCB, SizeOf(DCB), 0);
  DCB.DCBlength := SizeOf(DCB);
  GetCommState(THandle(FHandle), DCB);
  DCB.BaudRate := Baud;
  DCB.ByteSize := DataBits;
  Case Parity of spOdd:DCB.Parity:=ODDPARITY; spEven:DCB.Parity:=EVENPARITY;
  Else DCB.Parity:=NOPARITY; End;
  If StopBits=2 Then DCB.StopBits:=TWOSTOPBITS Else DCB.StopBits:=ONESTOPBIT;
  SetCommState(THandle(FHandle), DCB);
  {$ENDIF}
  {$IFDEF OS2}
  BR.BaudRate:=Baud; BR.Fraction:=0; PL:=SizeOf(BR); DL:=0;
  DosDevIOCtl(THandle(FHandle), IOCTL_ASYNC, $41, BR, PL, PL, BR, DL, DL);
  LC.DataBits:=DataBits;
  Case Parity of spOdd:LC.Parity:=1; spEven:LC.Parity:=2; Else LC.Parity:=0; End;
  If StopBits=2 Then LC.StopBits:=2 Else LC.StopBits:=0;
  PL:=SizeOf(LC); DL:=0;
  DosDevIOCtl(THandle(FHandle), IOCTL_ASYNC, $42, LC, PL, PL, LC, DL, DL);
  {$ENDIF}
End;

// ====================================================================
// Open / Close
// ====================================================================

Function TModemSerial.Open(Const DeviceName: String; Baud: LongInt;
                           HardwareFlow: Boolean): Boolean;
{$IFDEF GO32V2}
Var PortIdx: Integer;
{$ENDIF}
{$IFDEF WINDOWS}
Var Timeouts: TCommTimeouts;
{$ENDIF}
{$IFDEF OS2}
Var Action, RC: Cardinal;
{$ENDIF}
Begin
  Result := False;
  If FIsOpen Then Close;
  {$IFDEF GO32V2}
  If Length(DeviceName) < 4 Then Exit;
  Case UpCase(DeviceName[4]) of
    '1':PortIdx:=0; '2':PortIdx:=1; '3':PortIdx:=2; '4':PortIdx:=3;
  Else Exit; End;
  FBase := COM_BASE[PortIdx];
  Port[FBase+7]:=$55;
  If Port[FBase+7]<>$55 Then Exit;
  FHandle := PortIdx;
  {$ENDIF}
  {$IFDEF UNIX}
  FHandle := fpOpen(DeviceName, O_RDWR or O_NOCTTY or O_NONBLOCK);
  If FHandle < 0 Then Exit;
  fpfcntl(FHandle, F_SETFL, fpfcntl(FHandle, F_GETFL, 0) and not O_NONBLOCK);
  {$ENDIF}
  {$IFDEF WINDOWS}
  FHandle := TSerialHandle(CreateFile(PChar('\\\\.\\\\'+ DeviceName),
    GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0));
  If FHandle = TSerialHandle(INVALID_HANDLE_VALUE) Then Begin
    FHandle:=InvalidSerialHandle; Exit; End;
  FillChar(Timeouts, SizeOf(Timeouts), 0);
  Timeouts.ReadIntervalTimeout := MAXDWORD;
  SetCommTimeouts(THandle(FHandle), Timeouts);
  {$ENDIF}
  {$IFDEF OS2}
  RC := DosOpen(PChar(DeviceName), THandle(FHandle), Action, 0, 0, 1, $0042, nil);
  If RC<>0 Then Begin FHandle:=InvalidSerialHandle; Exit; End;
  {$ENDIF}
  FDevice:=DeviceName; FBaud:=Baud; FIsOpen:=True;
  SetParams(Baud, 8, spNone, 1, HardwareFlow);
  SetDTR(True); SetRTS(True);
  {$IFDEF GO32V2} EnableIRQ; {$ENDIF}
  Result := True;
End;

Procedure TModemSerial.Close;
Begin
  If Not FIsOpen Then Exit;
  {$IFDEF GO32V2}
  DisableIRQ; SetDTR(False); SetRTS(False);
  Port[FBase+UART_IER]:=0; Port[FBase+UART_FCR]:=0;
  {$ENDIF}
  {$IFDEF UNIX} fpClose(FHandle); {$ENDIF}
  {$IFDEF WINDOWS} CloseHandle(THandle(FHandle)); {$ENDIF}
  {$IFDEF OS2} DosClose(THandle(FHandle)); {$ENDIF}
  FHandle:=InvalidSerialHandle; FIsOpen:=False;
End;

// ====================================================================
// Read / Write
// ====================================================================

Function TModemSerial.ReadBuf(Var Buffer; Count: LongInt): LongInt;
{$IFDEF GO32V2}
Var P: PByte; I: LongInt;
{$ENDIF}
{$IFDEF WINDOWS}
Var BytesRead: DWORD;
{$ENDIF}
{$IFDEF OS2}
Var BytesRead: Cardinal;
{$ENDIF}
Begin
  Result:=0; If Not FIsOpen Then Exit;
  {$IFDEF GO32V2}
  P:=@Buffer;
  For I:=0 to Count-1 Do Begin
    If (Port[FBase+UART_LSR] and LSR_DR)=0 Then Break;
    P^:=Port[FBase+UART_RBR]; Inc(P); Inc(Result);
  End;
  {$ENDIF}
  {$IFDEF UNIX}
  Result:=fpRead(FHandle, Buffer, Count);
  If Result<0 Then Result:=0;
  {$ENDIF}
  {$IFDEF WINDOWS}
  If ReadFile(THandle(FHandle), Buffer, Count, BytesRead, nil) Then Result:=BytesRead;
  {$ENDIF}
  {$IFDEF OS2}
  If DosRead(THandle(FHandle), Buffer, Count, BytesRead)=0 Then Result:=BytesRead;
  {$ENDIF}
End;

Function TModemSerial.WriteBuf(Var Buffer; Count: LongInt): LongInt;
{$IFDEF GO32V2}
Var P: PByte; I, T: LongInt;
{$ENDIF}
{$IFDEF WINDOWS}
Var BytesWritten: DWORD;
{$ENDIF}
{$IFDEF OS2}
Var BytesWritten: Cardinal;
{$ENDIF}
Begin
  Result:=0; If Not FIsOpen Then Exit;
  {$IFDEF GO32V2}
  P:=@Buffer;
  For I:=0 to Count-1 Do Begin
    T:=100000;
    While ((Port[FBase+UART_LSR] and LSR_THRE)=0) and (T>0) Do Dec(T);
    If T=0 Then Break;
    Port[FBase+UART_THR]:=P^; Inc(P); Inc(Result);
  End;
  {$ENDIF}
  {$IFDEF UNIX}
  Result:=fpWrite(FHandle, Buffer, Count);
  If Result<0 Then Result:=0;
  {$ENDIF}
  {$IFDEF WINDOWS}
  If WriteFile(THandle(FHandle), Buffer, Count, BytesWritten, nil) Then Result:=BytesWritten;
  {$ENDIF}
  {$IFDEF OS2}
  If DosWrite(THandle(FHandle), Buffer, Count, BytesWritten)=0 Then Result:=BytesWritten;
  {$ENDIF}
End;

Function TModemSerial.ReadTimeout(Var Buffer; Count: LongInt; TimeoutMS: LongInt): LongInt;
{$IFDEF GO32V2}
Var Start: LongInt;
{$ENDIF}
{$IFDEF UNIX}
Var FDS: TFDSet; TV: TTimeVal;
{$ENDIF}
{$IFDEF WINDOWS}
Var Timeouts: TCommTimeouts;
{$ENDIF}
Begin
  Result:=0; If Not FIsOpen Then Exit;
  {$IFDEF GO32V2}
  Start:=0;
  While (Start<TimeoutMS) and (Result=0) Do Begin
    If DataAvailable Then Begin Result:=ReadBuf(Buffer,Count); Exit; End;
    Inc(Start);
  End;
  {$ENDIF}
  {$IFDEF UNIX}
  fpFD_ZERO(FDS); fpFD_SET(FHandle, FDS);
  TV.tv_sec:=TimeoutMS div 1000; TV.tv_usec:=(TimeoutMS mod 1000)*1000;
  If fpSelect(FHandle+1, @FDS, nil, nil, @TV)>0 Then Result:=ReadBuf(Buffer,Count);
  {$ENDIF}
  {$IFDEF WINDOWS}
  FillChar(Timeouts, SizeOf(Timeouts), 0);
  Timeouts.ReadTotalTimeoutConstant:=TimeoutMS;
  SetCommTimeouts(THandle(FHandle), Timeouts);
  Result:=ReadBuf(Buffer,Count);
  Timeouts.ReadTotalTimeoutConstant:=0;
  Timeouts.ReadIntervalTimeout:=MAXDWORD;
  SetCommTimeouts(THandle(FHandle), Timeouts);
  {$ENDIF}
  {$IFDEF OS2}
  Result:=ReadBuf(Buffer,Count);
  {$ENDIF}
End;

// ====================================================================
// String convenience
// ====================================================================

Function TModemSerial.WriteStr(Const S: String): LongInt;
Var Tmp: String;
Begin
  If (Not FIsOpen) or (Length(S)=0) Then Begin Result:=0; Exit; End;
  Tmp:=S;
  Result:=WriteBuf(Tmp[1], Length(Tmp));
End;

Function TModemSerial.ReadAvail: String;
Var Buf: Array[0..255] of Char; N, Old: LongInt;
Begin
  Result:=''; If Not FIsOpen Then Exit;
  Repeat
    N:=ReadBuf(Buf, SizeOf(Buf));
    If N>0 Then Begin Old:=Length(Result); SetLength(Result, Old+N); Move(Buf, Result[Old+1], N); End;
  Until N<=0;
End;

// ====================================================================
// Buffer control
// ====================================================================

Procedure TModemSerial.FlushInput;
{$IFDEF OS2}
Var Cmd: Byte; PL, DL: Cardinal;
{$ENDIF}
Begin
  If Not FIsOpen Then Exit;
  {$IFDEF GO32V2}
  While (Port[FBase+UART_LSR] and LSR_DR)<>0 Do Port[FBase+UART_RBR];
  {$ENDIF}
  {$IFDEF UNIX} tcflush(FHandle, TCIFLUSH); {$ENDIF}
  {$IFDEF WINDOWS} PurgeComm(THandle(FHandle), PURGE_RXCLEAR); {$ENDIF}
  {$IFDEF OS2}
  Cmd:=0; PL:=1; DL:=0;
  DosDevIOCtl(THandle(FHandle), IOCTL_ASYNC, $48, Cmd, PL, PL, Cmd, DL, DL);
  {$ENDIF}
End;

Procedure TModemSerial.FlushOutput;
Begin
  Drain;
End;

Procedure TModemSerial.Flush;
Begin
  FlushInput; Drain;
End;

Procedure TModemSerial.Drain;
{$IFDEF OS2}
Var Cmd: Byte; PL, DL: Cardinal;
{$ENDIF}
Begin
  If Not FIsOpen Then Exit;
  {$IFDEF GO32V2}
  While (Port[FBase+UART_LSR] and LSR_TEMT)=0 Do;
  {$ENDIF}
  {$IFDEF UNIX} tcdrain(FHandle); {$ENDIF}
  {$IFDEF WINDOWS} FlushFileBuffers(THandle(FHandle)); {$ENDIF}
  {$IFDEF OS2}
  Cmd:=0; PL:=1; DL:=0;
  DosDevIOCtl(THandle(FHandle), IOCTL_ASYNC, $47, Cmd, PL, PL, Cmd, DL, DL);
  {$ENDIF}
End;

Procedure TModemSerial.SendBreak;
{$IFDEF GO32V2}
Var L: Byte; I: LongInt;
{$ENDIF}
{$IFDEF OS2}
Var Cmd: Word; PL, DL: Cardinal;
{$ENDIF}
Begin
  If Not FIsOpen Then Exit;
  {$IFDEF GO32V2}
  L:=Port[FBase+UART_LCR];
  Port[FBase+UART_LCR]:=L or $40;
  For I:=1 to 10000 Do;
  Port[FBase+UART_LCR]:=L;
  {$ENDIF}
  {$IFDEF UNIX} tcsendbreak(FHandle, 0); {$ENDIF}
  {$IFDEF WINDOWS}
  SetCommBreak(THandle(FHandle)); Sleep(250); ClearCommBreak(THandle(FHandle));
  {$ENDIF}
  {$IFDEF OS2}
  Cmd:=0; PL:=SizeOf(Cmd); DL:=0;
  DosDevIOCtl(THandle(FHandle), IOCTL_ASYNC, $4D, Cmd, PL, PL, Cmd, DL, DL);
  DosSleep(250);
  DosDevIOCtl(THandle(FHandle), IOCTL_ASYNC, $4E, Cmd, PL, PL, Cmd, DL, DL);
  {$ENDIF}
End;

// ====================================================================
// Modem control lines
// ====================================================================

Procedure TModemSerial.SetDTR(State: Boolean);
{$IFDEF GO32V2}
Var M: Byte;
{$ENDIF}
{$IFDEF UNIX}
Var Bits: Cardinal;
{$ENDIF}
{$IFDEF OS2}
Var MC: TModemCtrl; PL, DL: Cardinal;
{$ENDIF}
Begin
  If Not FIsOpen Then Exit;
  {$IFDEF GO32V2}
  M:=Port[FBase+UART_MCR];
  If State Then M:=M or MCR_DTR Else M:=M and not MCR_DTR;
  Port[FBase+UART_MCR]:=M;
  {$ENDIF}
  {$IFDEF UNIX}
  Bits:=TIOCM_DTR;
  If State Then fpioctl(FHandle, TIOCMBIS, @Bits)
  Else fpioctl(FHandle, TIOCMBIC, @Bits);
  {$ENDIF}
  {$IFDEF WINDOWS}
  If State Then EscapeCommFunction(THandle(FHandle), SETDTR)
  Else EscapeCommFunction(THandle(FHandle), CLRDTR);
  {$ENDIF}
  {$IFDEF OS2}
  If State Then Begin MC.OnMask:=$01; MC.OffMask:=$FF; End
  Else Begin MC.OnMask:=$00; MC.OffMask:=$FE; End;
  PL:=SizeOf(MC); DL:=0;
  DosDevIOCtl(THandle(FHandle), IOCTL_ASYNC, $46, MC, PL, PL, MC, DL, DL);
  {$ENDIF}
End;

Procedure TModemSerial.SetRTS(State: Boolean);
{$IFDEF GO32V2}
Var M: Byte;
{$ENDIF}
{$IFDEF UNIX}
Var Bits: Cardinal;
{$ENDIF}
{$IFDEF OS2}
Var MC: TModemCtrl; PL, DL: Cardinal;
{$ENDIF}
Begin
  If Not FIsOpen Then Exit;
  {$IFDEF GO32V2}
  M:=Port[FBase+UART_MCR];
  If State Then M:=M or MCR_RTS Else M:=M and not MCR_RTS;
  Port[FBase+UART_MCR]:=M;
  {$ENDIF}
  {$IFDEF UNIX}
  Bits:=TIOCM_RTS;
  If State Then fpioctl(FHandle, TIOCMBIS, @Bits)
  Else fpioctl(FHandle, TIOCMBIC, @Bits);
  {$ENDIF}
  {$IFDEF WINDOWS}
  If State Then EscapeCommFunction(THandle(FHandle), SETRTS)
  Else EscapeCommFunction(THandle(FHandle), CLRRTS);
  {$ENDIF}
  {$IFDEF OS2}
  If State Then Begin MC.OnMask:=$02; MC.OffMask:=$FF; End
  Else Begin MC.OnMask:=$00; MC.OffMask:=$FD; End;
  PL:=SizeOf(MC); DL:=0;
  DosDevIOCtl(THandle(FHandle), IOCTL_ASYNC, $46, MC, PL, PL, MC, DL, DL);
  {$ENDIF}
End;

{$IFDEF UNIX}
Function UnixGetModem(Handle: TSerialHandle): Cardinal;
Begin Result:=0; fpioctl(Handle, TIOCMGET, @Result); End;
{$ENDIF}

{$IFDEF OS2}
Function OS2GetModem(Handle: TSerialHandle): Byte;
Var MI: TModemInput; PL, DL: Cardinal;
Begin MI.Signals:=0; PL:=0; DL:=SizeOf(MI);
  DosDevIOCtl(THandle(Handle), IOCTL_ASYNC, $67, MI, PL, PL, MI, DL, DL);
  Result:=MI.Signals; End;
{$ENDIF}

{$IFDEF WINDOWS}
Function WinGetModem(Handle: TSerialHandle): DWORD;
Begin Result:=0; GetCommModemStatus(THandle(Handle), Result); End;
{$ENDIF}

Function TModemSerial.GetCTS: Boolean;
Begin Result:=False; If Not FIsOpen Then Exit;
  {$IFDEF GO32V2} Result:=(Port[FBase+UART_MSR] and MSR_CTS)<>0; {$ENDIF}
  {$IFDEF UNIX} Result:=(UnixGetModem(FHandle) and TIOCM_CTS)<>0; {$ENDIF}
  {$IFDEF WINDOWS} Result:=(WinGetModem(FHandle) and MS_CTS_ON)<>0; {$ENDIF}
  {$IFDEF OS2} Result:=(OS2GetModem(FHandle) and $10)<>0; {$ENDIF}
End;

Function TModemSerial.GetDSR: Boolean;
Begin Result:=False; If Not FIsOpen Then Exit;
  {$IFDEF GO32V2} Result:=(Port[FBase+UART_MSR] and MSR_DSR)<>0; {$ENDIF}
  {$IFDEF UNIX} Result:=(UnixGetModem(FHandle) and TIOCM_DSR)<>0; {$ENDIF}
  {$IFDEF WINDOWS} Result:=(WinGetModem(FHandle) and MS_DSR_ON)<>0; {$ENDIF}
  {$IFDEF OS2} Result:=(OS2GetModem(FHandle) and $20)<>0; {$ENDIF}
End;

Function TModemSerial.GetRI: Boolean;
Begin Result:=False; If Not FIsOpen Then Exit;
  {$IFDEF GO32V2} Result:=(Port[FBase+UART_MSR] and MSR_RI)<>0; {$ENDIF}
  {$IFDEF UNIX} Result:=(UnixGetModem(FHandle) and TIOCM_RI)<>0; {$ENDIF}
  {$IFDEF WINDOWS} Result:=(WinGetModem(FHandle) and MS_RING_ON)<>0; {$ENDIF}
  {$IFDEF OS2} Result:=(OS2GetModem(FHandle) and $40)<>0; {$ENDIF}
End;

Function TModemSerial.GetDCD: Boolean;
Begin Result:=False; If Not FIsOpen Then Exit;
  {$IFDEF GO32V2} Result:=(Port[FBase+UART_MSR] and MSR_DCD)<>0; {$ENDIF}
  {$IFDEF UNIX} Result:=(UnixGetModem(FHandle) and TIOCM_CD)<>0; {$ENDIF}
  {$IFDEF WINDOWS} Result:=(WinGetModem(FHandle) and MS_RLSD_ON)<>0; {$ENDIF}
  {$IFDEF OS2} Result:=(OS2GetModem(FHandle) and $80)<>0; {$ENDIF}
End;

Function TModemSerial.DataAvailable: Boolean;
{$IFDEF UNIX}
Var FDS: TFDSet; TV: TTimeVal;
{$ENDIF}
{$IFDEF WINDOWS}
Var Errors: DWORD; ComStat: TComStat;
{$ENDIF}
{$IFDEF OS2}
Var QI: Record InCount, InSize, OutCount, OutSize: Word; End;
    PL, DL: Cardinal;
{$ENDIF}
Begin
  Result:=False; If Not FIsOpen Then Exit;
  {$IFDEF GO32V2} Result:=(Port[FBase+UART_LSR] and LSR_DR)<>0; {$ENDIF}
  {$IFDEF UNIX}
  fpFD_ZERO(FDS); fpFD_SET(FHandle, FDS);
  TV.tv_sec:=0; TV.tv_usec:=0;
  Result:=fpSelect(FHandle+1, @FDS, nil, nil, @TV)>0;
  {$ENDIF}
  {$IFDEF WINDOWS}
  ClearCommError(THandle(FHandle), Errors, @ComStat);
  Result:=ComStat.cbInQue>0;
  {$ENDIF}
  {$IFDEF OS2}
  PL:=0; DL:=SizeOf(QI); FillChar(QI, SizeOf(QI), 0);
  DosDevIOCtl(THandle(FHandle), IOCTL_ASYNC, $68, QI, PL, PL, QI, DL, DL);
  Result:=QI.InCount>0;
  {$ENDIF}
End;

// ====================================================================
// Hardware info
// ====================================================================

Function TModemSerial.DetectUART: String;
Begin
  If Not FIsOpen Then Begin Result:='closed'; Exit; End;
  {$IFDEF GO32V2}
  Port[FBase+UART_FCR]:=$E7;
  If (Port[FBase+UART_IIR] and $C0)=$C0 Then Begin
    If (Port[FBase+UART_IIR] and $20)<>0 Then Result:='16750'
    Else Result:='16550A';
  End Else If (Port[FBase+UART_IIR] and $80)<>0 Then Result:='16550'
  Else Begin Port[FBase+7]:=$5A; If Port[FBase+7]=$5A Then Result:='16450'
    Else Result:='8250'; End;
  Port[FBase+UART_FCR]:=$00;
  {$ENDIF}
  {$IFDEF UNIX} Result:='tty'; {$ENDIF}
  {$IFDEF WINDOWS} Result:='COM'; {$ENDIF}
  {$IFDEF OS2} Result:='SIO'; {$ENDIF}
End;

Procedure TModemSerial.SetFIFO(Enable: Boolean; TriggerLevel: Byte);
{$IFDEF GO32V2}
Var F: Byte;
{$ENDIF}
{$IFDEF UNIX}
Var Tio: termios;
{$ENDIF}
Begin
  If Not FIsOpen Then Exit;
  {$IFDEF GO32V2}
  If Not Enable Then Begin Port[FBase+UART_FCR]:=0; Exit; End;
  Case TriggerLevel of 1:F:=$01; 4:F:=$41; 8:F:=$81; Else F:=$C1; End;
  Port[FBase+UART_FCR]:=F or $06;
  {$ENDIF}
  {$IFDEF UNIX}
  TCGetAttr(FHandle, Tio);
  If Enable Then Begin Tio.c_cc[VMIN]:=TriggerLevel; Tio.c_cc[VTIME]:=1; End
  Else Begin Tio.c_cc[VMIN]:=1; Tio.c_cc[VTIME]:=0; End;
  TCSetAttr(FHandle, TCSANOW, Tio);
  {$ENDIF}
  {$IFDEF WINDOWS}
  If Enable Then SetupComm(THandle(FHandle), 4096, 1024)
  Else SetupComm(THandle(FHandle), 64, 64);
  {$ENDIF}
End;

Function TModemSerial.GetBase: Word;
Begin
  {$IFDEF GO32V2} Result:=FBase; {$ELSE} Result:=Word(FHandle and $FFFF); {$ENDIF}
End;

// ====================================================================
// IRQ (DOS only)
// ====================================================================

Procedure TModemSerial.EnableIRQ;
Begin
  {$IFDEF GO32V2}
  SerEnableIRQ(FHandle);
  {$ENDIF}
  {$IFDEF MSDOS}
  SerEnableIRQ(FHandle);
  {$ENDIF}
End;

Procedure TModemSerial.DisableIRQ;
Begin
  {$IFDEF GO32V2}
  SerDisableIRQ(FHandle);
  {$ENDIF}
  {$IFDEF MSDOS}
  SerDisableIRQ(FHandle);
  {$ENDIF}
End;

// ====================================================================
// Convenience
// ====================================================================

Procedure TModemSerial.DropDTR;
Begin SetDTR(False); End;

End.
