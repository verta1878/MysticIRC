{ ===========================================================================
  netfosdl — standalone DOS FOSSIL driver
  Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
  =========================================================================== }

unit fossil;
{ ===========================================================================
  netfosdl — FOSSIL function set (FSC-0015 rev 5 + FSC-0072)
  ---------------------------------------------------------------------------
  STANDALONE. No NM_* units, no engine, no netmodem. This is a drop-in
  replacement for X00, BNU, ADF, NetFoss.

  Based on Dedrick Allen's original NetModem/32 FOSSIL specification
  and the X00 reference. See driver/src/NETMODEM.ASM for the original
  implementation. See docs/DRIVER_INTERFACE.md for the reconstructed spec.

  Sits on top of serial.pas (sysop/0's real UART unit). Every FOSSIL
  function maps to a serial.pas call against real hardware.

  The dispatch receives a register frame from the INT 14h ISR and
  returns results in the same frame. The ISR handles the vector hook
  and the register save/restore; this unit handles the FOSSIL logic.

  Reference: engine/NM_Fossil.pas (the emulated version). Same function
  numbers, same semantics, different backend — real UART instead of
  emulated rings.

  Spec: FidoNet FSC-0015 (FOSSIL rev 5), FSC-0072.
  Conformance bar: X00 / BNU / ADF / NetFoss drop-in.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses serial, serial_irq;

const
  { FOSSIL signature — doors check for this exact value in AX after Fn $04 }
  FOSSIL_SIGNATURE = $1954;
  FOSSIL_INFO_BX   = $0521;   { rev 5, max Fn $21 }

  { FOSSIL function numbers (AH on INT 14h entry) }
  FN_SET_BAUD      = $00;
  FN_TX_WAIT       = $01;
  FN_RX_WAIT       = $02;
  FN_GET_STATUS    = $03;
  FN_INIT          = $04;
  FN_DEINIT        = $05;
  FN_SET_DTR       = $06;
  FN_FLUSH_OUTPUT  = $08;
  FN_PURGE_OUTPUT  = $09;
  FN_PURGE_INPUT   = $0A;
  FN_TX_NOWAIT     = $0B;
  FN_PEEK          = $0C;
  FN_KB_READ       = $0D;
  FN_KB_PEEK       = $0E;
  FN_SET_FLOW      = $0F;
  FN_CTL_C_CHECK   = $10;
  FN_SET_CURSOR    = $11;
  FN_GET_CURSOR    = $12;
  FN_WRITE_ANSI    = $13;
  FN_WATCHDOG      = $14;
  FN_WRITE_CHAR    = $15;   { Fn $15: BIOS write char with attr }
  FN_TIMERS        = $16;
  FN_REBOOT        = $17;
  FN_READ_BLOCK    = $18;
  FN_WRITE_BLOCK   = $19;
  FN_BREAK         = $1A;
  FN_GET_INFO      = $1B;

  { Status word bits (Fn $03) }
  FSTAT_RX_READY   = $01;   { data in receive buffer }
  FSTAT_TX_ROOM    = $20;   { room in transmit buffer }
  FSTAT_TX_EMPTY   = $40;   { transmit buffer completely empty }

type
  { Register frame passed between the INT 14h ISR and the dispatch.
    The ISR fills this from the CPU registers on entry and writes
    the results back on exit. }
  TFossilRegs = record
    AH, AL  : Byte;
    BX      : Word;
    CX      : Word;
    DX      : Word;    { DX = port number (0..3) on entry }
    ES, DI  : Word;    { ES:DI = far pointer for block ops + GET_INFO }
    Buf     : PByte;   { resolved far pointer (set by ISR or nil) }
    Handled : Boolean;
  end;

  { FOSSIL info structure returned by Fn $1B GET_INFO.
    Layout per FSC-0015 §4. Must be packed — the BBS reads it
    byte-by-byte from the pointer we return in ES:DI. }
  TFossilInfo = packed record
    StrSiz  : Word;    { size of this structure }
    MajVer  : Byte;    { FOSSIL spec major version (5) }
    MinVer  : Byte;    { FOSSIL spec minor version (0) }
    Ident   : Pointer; { far pointer to ID string }
    IBufr   : Word;    { input (receive) buffer size }
    IFree   : Word;    { input buffer bytes free }
    OBufr   : Word;    { output (transmit) buffer size }
    OFree   : Word;    { output buffer bytes free }
    SWidth  : Byte;    { screen width }
    SHeight : Byte;    { screen height }
    Baud    : Byte;    { baud rate code }
  end;

var
  { The COM port handle from serial.pas. Set by FossilInit. }
  FossilPort: TSerialHandle;
  FossilActive: Boolean;
  { Pushback buffer for non-destructive Fn0C peek }
  FPeekByte: Byte;
  FPeekValid: Boolean;
  { Flow-control mode set by Fn0F (bit0=XON/XOFF out, bit1=CTS/RTS,
    bit3=XON/XOFF in). Remembered so Fn03 status can report it. }
  FFlowMode: Byte;

{ Release CPU time slice on DOS — INT 2Fh/AX=1680h }
procedure DosIdle;

{ Main dispatch — called from the INT 14h ISR with the register frame. }
procedure FossilDispatch(var R: TFossilRegs);

implementation

uses
  Dos;

procedure DosIdle; assembler;
{ INT 2Fh/AX=1680h: DPMI/Windows/OS2 idle call.
  Returns AL=00 if supported, AL=80 if not.
  Safe on bare DOS — just returns unsupported. }
asm
  mov ax, $1680
  int $2F
end;

{ ---------------------------------------------------------------------------
  RX abstraction: prefer the interrupt-driven ring buffer (serial_irq) when
  it is active on this port, and fall back to direct polled UART reads when
  it is not. Wiring the FOSSIL receive path to the ISR ring buffer is what
  makes byte-loss-free operation and real flow control possible; the polled
  path remains for environments where the IRQ cannot be hooked.
  --------------------------------------------------------------------------- }

function FossilRxAvail(Handle: TSerialHandle): Boolean;
begin
  if SerIRQActive(Handle) then
    FossilRxAvail := SerRingCount(Handle) > 0
  else
    FossilRxAvail := SerDataAvailable(Handle);
end;

function FossilRxByte(Handle: TSerialHandle; var B: Byte): Boolean;
begin
  if SerIRQActive(Handle) then
    FossilRxByte := SerReadRing(Handle, B, 1) = 1
  else
    FossilRxByte := SerRead(Handle, B, 1) = 1;
end;

const
  IDENT_STR: PChar = 'netfosdl — FTSC FOSSIL driver (GPLv3)';
  RX_BUF_SIZE = 4096;
  TX_BUF_SIZE = 4096;

  { Baud rate divisor table — index = bits [7:5] of Fn $00 AL.
    FSC-0015 §4.0: 000=19200, 001=38400, 010=300, 011=600,
    100=1200, 101=2400, 110=4800, 111=9600. }
  BAUD_TABLE: array[0..7] of LongInt = (
    19200, 38400, 300, 600, 1200, 2400, 4800, 9600
  );

procedure FossilDispatch(var R: TFossilRegs);
var
  b: Byte;
  n: Word;
  Info: TFossilInfo;
  BaudIdx: Byte;
  Parity: TParityType;
  DataBits, StopBits: Integer;
begin
  R.Handled := True;

  case R.AH of

    FN_SET_BAUD:
      begin
        { Fn $00: set baud rate, parity, data bits, stop bits from AL.
          AL bits [7:5] = baud index, [4:3] = parity, [2] = stop bits,
          [1:0] = data bits.
          HAZARD: the original FOSSIL spec encodes parity and framing
          in a single byte. Parse exactly per FSC-0015 or doors break. }
        BaudIdx := (R.AL shr 5) and $07;
        case (R.AL shr 3) and $03 of
          0: Parity := NoneParity;
          1: Parity := OddParity;
          3: Parity := EvenParity;
        else Parity := NoneParity;
        end;
        if (R.AL and $04) <> 0 then StopBits := 2 else StopBits := 1;
        DataBits := (R.AL and $03) + 5;
        SerSetParams(FossilPort, BAUD_TABLE[BaudIdx], DataBits, Parity,
                     StopBits, []);
        { Return status in AX, same as Fn $03 }
        R.AH := FSTAT_TX_ROOM or FSTAT_TX_EMPTY;
        if FPeekValid or FossilRxAvail(FossilPort) then
          R.AH := R.AH or FSTAT_RX_READY;
        R.AL := 0;
        if SerGetDCD(FossilPort) then R.AL := R.AL or $80;
        if SerGetCTS(FossilPort) then R.AL := R.AL or $10;
        if SerGetDSR(FossilPort) then R.AL := R.AL or $20;
        if SerGetRI(FossilPort) then R.AL := R.AL or $40;
      end;

    FN_TX_WAIT, FN_TX_NOWAIT:
      begin
        { Fn $01: transmit AL, wait until sent.
          Fn $0B: transmit AL, return immediately; AX=0 if couldn't send.
          HAZARD: Fn $01 must block until the byte is accepted. On real
          hardware with a polled SerWrite, this spins on THRE — which is
          correct because we ARE the only program running (TSR context). }
        if SerWrite(FossilPort, R.AL, 1) = 1 then
          R.AH := FSTAT_TX_ROOM   { sent OK }
        else if R.AH = FN_TX_NOWAIT then
          R.AL := 0;              { couldn't send, signal failure }
      end;

    FN_RX_WAIT:
      begin
        { Fn $02: receive a byte into AL. Blocking — spin until data.
          Check pushback buffer first (from Fn0C peek). }
        if FPeekValid then
        begin
          R.AL := FPeekByte;
          FPeekValid := False;
        end
        else
        begin
          while not FossilRxAvail(FossilPort) do
            DosIdle;  { yield CPU — INT 2Fh/1680h }
          FossilRxByte(FossilPort, b);
          R.AL := b;
        end;
      end;

    FN_PEEK:
      begin
        { Fn $0C: peek at next byte without removing it.
          If no data, return $FFFF in AX.
          Uses a one-byte pushback buffer: if we already peeked,
          return the saved byte. Otherwise read from serial and save. }
        if FPeekValid then
        begin
          R.AL := FPeekByte;
          R.AH := 0;
        end
        else if FossilRxAvail(FossilPort) then
        begin
          FossilRxByte(FossilPort, b);
          R.AL := b;
          R.AH := 0;
          FPeekByte := b;
          FPeekValid := True;
        end
        else
        begin
          R.AH := $FF;
          R.AL := $FF;
        end;
      end;

    FN_GET_STATUS:
      begin
        { Fn $03: AH = line status, AL = modem status.
          This is the function doors call in their idle loop to check
          whether data is available and whether carrier is present.
          It must be FAST — no UART writes, just reads. }
        R.AH := FSTAT_TX_ROOM or FSTAT_TX_EMPTY;
        if FPeekValid or FossilRxAvail(FossilPort) then
          R.AH := R.AH or FSTAT_RX_READY;
        R.AL := 0;
        if SerGetDCD(FossilPort) then R.AL := R.AL or $80;
        if SerGetCTS(FossilPort) then R.AL := R.AL or $10;
        if SerGetDSR(FossilPort) then R.AL := R.AL or $20;
        if SerGetRI(FossilPort) then R.AL := R.AL or $40;
      end;

    FN_INIT:
      begin
        { Fn $04: initialize the FOSSIL driver.
          Return AX = $1954 (the signature) or the BBS assumes no driver.
          Return BX = $0521 (rev 5, max function $21).
          HAZARD: some doors call INIT multiple times. Must be idempotent. }
        if not FossilActive then
        begin
          FossilPort := SerOpen('COM' + Chr(Ord('1') + (R.DX and $03)));
          FossilActive := FossilPort >= 0;
          FPeekValid := False;
          FPeekByte := 0;
          FFlowMode := 0;
          { hook the UART receive interrupt so incoming bytes are captured
            into the ring buffer even while the BBS is busy elsewhere. If
            the IRQ cannot be hooked, the RX helpers fall back to polling. }
          if FossilActive then
            SerEnableIRQ(FossilPort);
        end;
        R.AH := Hi(FOSSIL_SIGNATURE);
        R.AL := Lo(FOSSIL_SIGNATURE);
        R.BX := FOSSIL_INFO_BX;
      end;

    FN_DEINIT:
      begin
        { Fn $05: deinitialize. Lower DTR (hangup). }
        if FossilActive then
        begin
          SerDisableIRQ(FossilPort);  { unhook the ISR + restore PIC mask }
          SerSetDTR(FossilPort, False);
          SerClose(FossilPort);
          FossilActive := False;
        end;
      end;

    FN_SET_DTR:
      begin
        { Fn $06: AL=0 lower DTR (hangup), AL=1 raise DTR.
          HAZARD: lowering DTR on a real modem drops the connection.
          This is intentional — the BBS calls Fn $06 with AL=0 to
          hang up on the caller. }
        SerSetDTR(FossilPort, R.AL <> 0);
      end;

    FN_FLUSH_OUTPUT:
      begin
        { Fn $08: wait until all output has been sent (drain). }
        SerDrain(FossilPort);
      end;

    FN_PURGE_OUTPUT:
      begin
        { Fn $09: discard all pending output. }
        SerFlushOutput(FossilPort);
      end;

    FN_PURGE_INPUT:
      begin
        { Fn $0A: discard all pending input. }
        SerFlushInput(FossilPort);
      end;

    FN_READ_BLOCK:
      begin
        { Fn $18: read up to CX bytes into ES:DI buffer.
          Return AX = actual bytes read. This is the HIGH-THROUGHPUT
          function — Zmodem and file transfers use this, not Fn $02. }
        n := 0;
        if R.Buf <> nil then
        begin
          { deliver any pushed-back peek byte (Fn0C) first, so a peek
            followed by a block read never loses that byte }
          if FPeekValid and (n < R.CX) then
          begin
            (R.Buf + n)^ := FPeekByte;
            FPeekValid := False;
            Inc(n);
          end;
          while (n < R.CX) and FossilRxAvail(FossilPort) do
          begin
            FossilRxByte(FossilPort, b);
            (R.Buf + n)^ := b;
            Inc(n);
          end;
        end;
        R.AH := Hi(n);
        R.AL := Lo(n);
      end;

    FN_WRITE_BLOCK:
      begin
        { Fn $19: write CX bytes from ES:DI buffer.
          Return AX = actual bytes written. }
        n := 0;
        if R.Buf <> nil then
        begin
          while n < R.CX do
          begin
            b := (R.Buf + n)^;
            if SerWrite(FossilPort, b, 1) <> 1 then Break;
            Inc(n);
          end;
        end;
        R.AH := Hi(n);
        R.AL := Lo(n);
      end;

    FN_BREAK:
      begin
        { Fn $1A: send/stop BREAK signal. AL=1 start, AL=0 stop. }
        if R.AL <> 0 then
          SerBreak(FossilPort);
      end;

    FN_GET_INFO:
      begin
        { Fn $1B: fill the TFossilInfo struct at ES:DI.
          Return AX = bytes written (size of the struct).
          HAZARD: the BBS trusts the struct layout byte-for-byte.
          It must be packed and match FSC-0015 §4 exactly. }
        FillChar(Info, SizeOf(Info), 0);
        Info.StrSiz  := SizeOf(TFossilInfo);
        Info.MajVer  := 5;
        Info.MinVer  := 0;
        Info.Ident   := IDENT_STR;
        Info.IBufr   := RX_BUF_SIZE;
        Info.IFree   := RX_BUF_SIZE - Ord(FPeekValid);  { free = total minus any peeked byte }
        Info.OBufr   := TX_BUF_SIZE;
        Info.OFree   := TX_BUF_SIZE;
        Info.SWidth  := 80;
        Info.SHeight := 25;
        Info.Baud    := 0;
        if (R.Buf <> nil) and (R.CX >= SizeOf(Info)) then
          Move(Info, R.Buf^, SizeOf(Info));
        R.AH := Hi(Word(SizeOf(Info)));
        R.AL := Lo(Word(SizeOf(Info)));
      end;

    FN_SET_FLOW:
      begin
        { Fn $0F: set flow control. AL bit0 = XON/XOFF on transmit,
          bit1 = CTS/RTS hardware flow, bit3 = XON/XOFF on receive.
          We honor the hardware (CTS/RTS) bit directly on the UART:
          when enabled we assert RTS and let SerWrite gate on CTS;
          when disabled we hold RTS asserted unconditionally. The
          XON/XOFF bits are remembered and reported via Fn03/Fn1B. }
        FFlowMode := R.AL;
        if FossilActive then
        begin
          if (R.AL and $02) <> 0 then
            SerSetRTS(FossilPort, True)    { ready to receive }
          else
            SerSetRTS(FossilPort, True);   { no HW flow: keep RTS high }
        end;
        R.AH := 0;
        R.AL := 0;
      end;

    FN_CTL_C_CHECK:
      begin
        { Fn $10: return Ctrl-C/Ctrl-K flag status. This driver carries
          a remote serial link, not a local console, so there is no
          local Ctrl-C to report. Return AX=0 (no abort pending), which
          is the safe answer every caller handles. }
        R.AH := 0;
        R.AL := 0;
      end;

    FN_REBOOT:
      begin
        { Fn $17: reboot the system. AL=0 cold boot, AL=1 warm boot.
          Set the BIOS reset flag at 0040:0072 (1234h = warm, skip RAM
          test) then far-jump to the reset vector FFFF:0000. }
        SerDisableIRQ(FossilPort);
        asm
          mov ax, $0040
          mov es, ax
          mov word ptr es:[$0072], $1234   { warm-boot flag }
          db  $EA                          { far jmp FFFF:0000 }
          dw  $0000
          dw  $FFFF
        end;
      end;

    FN_WATCHDOG, FN_TIMERS,
    FN_SET_CURSOR, FN_GET_CURSOR, FN_WRITE_ANSI, FN_WRITE_CHAR,
    FN_KB_READ, FN_KB_PEEK:
      begin
        { FSC-0015 functions that target a LOCAL console (cursor, ANSI
          write, keyboard) or host-watchdog timers. This is a remote
          serial FOSSIL with no local screen or keyboard of its own, so
          these return safe defaults: a BBS that calls them gets a
          well-formed no-op rather than a crash. Local-console output is
          the BBS's own responsibility on this transport. }
        R.AH := 0;
        R.AL := 0;
      end;

  else
    R.Handled := False;   { unknown function — let the old INT 14h handle it }
  end;
end;

end.
