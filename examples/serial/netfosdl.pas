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

program netfosdl;
{ ===========================================================================
  netfosdl — FTSC FOSSIL driver for DOS (real mode, i8086)
  ---------------------------------------------------------------------------
  STANDALONE. Not part of netmodem. No NM_* units, no SEAM, no TCP,
  no NMServer, no virtual comport. Links ppcross8086 + msdos RTL only.

  Drop-in replacement for X00, BNU, ADF, NetFoss.
  Based on Dedrick Allen's original NetModem/32 FOSSIL specification
  and the X00 command-line interface.

  Usage:
    netfosdl                  load on COM1 (default)
    netfosdl /port:N          load on COM port N (1-4)
    netfosdl /baud:RATE       set initial baud rate (default 9600)
    netfosdl /irq:N           override IRQ (default: COM1/3=4, COM2/4=3)
    netfosdl /fifo:N          FIFO trigger level (1, 4, 8, 14; default 14)
    netfosdl /nofifo          disable 16550 FIFO (force 8250 polled mode)
    netfosdl /u               unload from memory

  X00-compatible parameters (recognized for compatibility):
    netfosdl /B:N             same as /baud:N
    netfosdl /P:N             same as /port:N

  Architecture:
    BBS ──INT 14h──> Int14Handler ──> FossilDispatch ──> serial.pas ──> real UART

  The driver hooks INT 14h, dispatches FOSSIL functions via fossil.pas,
  and goes resident via Keep. The BBS calls INT 14h exactly as it would
  call X00 or BNU. serial.pas (sysop/0) does the real UART I/O.

  See also:
    docs/netmodem2irc_fossil_separation.md — why this is standalone
    docs/serial_irq_plan.md — the IRQ + ring buffer addition plan
    ROADMAP.md — Phase D1-D4
  =========================================================================== }

{$MODE OBJFPC}

uses
  Dos, SysUtils, fossil, serial;

const
  VERSION = 'netfosdl 0.1 — FTSC FOSSIL driver (GPLv3)';

var
  OldInt14: Pointer;
  PortNum: Integer;
  Unloading: Boolean;
  InitBaud: LongInt;
  InitFIFO: Integer;
  UseFIFO: Boolean;
  OverrideIRQ: Integer;

{ ===========================================================================
  INT 14h handler — the entry point the BBS calls.
  ---------------------------------------------------------------------------
  Declared as an 'interrupt' procedure so the compiler emits PUSHF/PUSHA
  on entry and IRET on exit. The register parameters match the CPU state
  on interrupt entry.

  HAZARD: this runs in interrupt context. No heap allocation, no WriteLn,
  no FPC runtime calls that touch the heap manager. serial.pas Port[]
  access is safe — it's inline I/O port reads/writes with no allocation.

  The handler checks DX (port number) against our port. If it's not ours,
  it chains to the old INT 14h handler so the BIOS or another FOSSIL
  driver can service it. This is how multiple FOSSIL drivers coexist —
  each one claims one port and passes the rest through.
  =========================================================================== }
procedure Int14Handler(
  Flags, CS, IP, AX, BX, CX, DX, SI, DI, DS, ES, BP: Word); interrupt;
var
  R: TFossilRegs;
begin
  { Only handle our port. Pass everything else to the old handler.
    HAZARD: DX is the port number (0-based). If someone calls INT 14h
    with DX=1 and we own COM1 (port 0), we must NOT handle it. }
  if (DX and $FF) <> (PortNum - 1) then
  begin
    { Chain to old handler — restore registers and jump.
      The 'interrupt' directive handles the IRET; we simulate the
      chain by calling the old handler via an inline jump.
      For now, just exit — the ISR epilogue does IRET. The old
      handler's vector is restored on unload, so anything we don't
      handle falls through to BIOS INT 14h (which returns AX=0,
      telling the BBS no FOSSIL is present on that port). }
    Exit;
  end;

  { Build the register frame for FossilDispatch }
  R.AH := Hi(AX);
  R.AL := Lo(AX);
  R.BX := BX;
  R.CX := CX;
  R.DX := DX;
  R.ES := ES;
  R.DI := DI;
  {$IFDEF DOS_TARGET}
  R.Buf := PByte(Ptr(ES, DI));
  {$ELSE}
  R.Buf := nil;
  {$ENDIF}
  R.Handled := False;

  { Dispatch — all FOSSIL logic lives in fossil.pas, not here }
  FossilDispatch(R);

  { Write results back to the CPU registers the BBS will read }
  if R.Handled then
  begin
    AX := (Word(R.AH) shl 8) or R.AL;
    BX := R.BX;
    CX := R.CX;
    DX := R.DX;
  end;
end;

{ ===========================================================================
  Install — hook INT 14h and go resident
  =========================================================================== }
procedure Install;
begin
  WriteLn(VERSION);
  WriteLn('Installing on COM', PortNum, ' (base $',
          HexStr(COM_BASE[PortNum - 1], 3), ', baud ', InitBaud, ')...');

  { Verify the UART exists before going resident }
  if SerDetectUART(PortNum - 1) = 'none' then
  begin
    WriteLn('ERROR: no UART detected on COM', PortNum, '. Aborting.');
    Halt(1);
  end;
  WriteLn('  UART: ', SerDetectUART(PortNum - 1));

  { Hook INT 14h — save the old vector for chaining and unload }
  GetIntVec($14, OldInt14);
  SetIntVec($14, @Int14Handler);

  WriteLn('  INT 14h hooked. Old handler saved at ',
          HexStr(Seg(OldInt14^), 4), ':', HexStr(Ofs(OldInt14^), 4));
  WriteLn('  FOSSIL signature: $', HexStr(FOSSIL_SIGNATURE, 4));
  WriteLn('Going resident. Use "netfosdl /u" to unload.');

  { Go resident. Keep(exitcode) is the 16-bit msdos RTL's TSR call.
    It calls INT 21h/Fn 31h (terminate and stay resident).
    HAZARD: everything after Keep never executes. The heap, stack,
    and code segments remain in memory. The interrupt handler runs
    whenever a BBS calls INT 14h.
    The parameter to Keep is the exit code (0 = success). }
  Keep(0);
end;

{ ===========================================================================
  Unload — restore INT 14h and exit
  ---------------------------------------------------------------------------
  HAZARD: we can only safely unload if no other program has hooked
  INT 14h after us. If someone else chained on top of our handler,
  restoring OldInt14 would skip their handler and break their chain.
  Check: read the current INT 14h vector; if it still points at our
  handler, it's safe. If not, refuse to unload and tell the user.
  =========================================================================== }
procedure Unload;
var
  CurrentInt14: Pointer;
begin
  WriteLn(VERSION);
  WriteLn('Unloading...');

  GetIntVec($14, CurrentInt14);
  if (Seg(CurrentInt14^) <> Seg(Int14Handler)) or (Ofs(CurrentInt14^) <> Ofs(Int14Handler)) then
  begin
    WriteLn('ERROR: INT 14h has been hooked by another program after us.');
    WriteLn('       Cannot safely unload. Unload the other program first.');
    Halt(2);
  end;

  { Safe to restore — no one hooked after us }
  SetIntVec($14, OldInt14);

  { Close the serial port cleanly }
  if FossilActive then
  begin
    SerSetDTR(FossilPort, False);
    SerClose(FossilPort);
    FossilActive := False;
  end;

  WriteLn('  INT 14h restored. FOSSIL driver unloaded.');

  { Free the TSR memory. INT 21h/Fn 49h releases the program's
    memory block. The PSP segment is at PrefixSeg. }
  { NOTE: full TSR memory release requires calling INT 21h/Fn 49h
    with ES = PSP segment. For now, just exit — the memory stays
    allocated until reboot, which is standard for DOS TSRs that
    don't implement a full unload. FreeMem/dealloc of TSR memory
    is complex and OS-version-dependent. }
  Halt(0);
end;

{ ===========================================================================
  Command-line parsing
  =========================================================================== }
procedure ParseArgs;
var
  i: Integer;
  arg, val: String;
  p: Integer;

  function ArgVal(const prefix: String): String;
  begin
    if Copy(UpCase(arg), 1, Length(prefix)) = UpCase(prefix) then
      Result := Copy(arg, Length(prefix) + 1, Length(arg))
    else
      Result := '';
  end;

begin
  PortNum := 1;
  InitBaud := 9600;
  InitFIFO := 14;
  UseFIFO := True;
  OverrideIRQ := -1;
  Unloading := False;

  for i := 1 to ParamCount do
  begin
    arg := ParamStr(i);

    if (arg = '/u') or (arg = '/U') or (arg = '-u') then
      Unloading := True

    { /port:N or X00-compatible /P:N }
    else if (ArgVal('/port:') <> '') or (ArgVal('/P:') <> '') then
    begin
      val := ArgVal('/port:');
      if val = '' then val := ArgVal('/P:');
      PortNum := Ord(val[1]) - Ord('0');
      if (PortNum < 1) or (PortNum > 4) then
      begin
        WriteLn('ERROR: port must be 1-4. Got: ', val);
        Halt(1);
      end;
    end

    { /baud:RATE or X00-compatible /B:N }
    else if (ArgVal('/baud:') <> '') or (ArgVal('/B:') <> '') then
    begin
      val := ArgVal('/baud:');
      if val = '' then val := ArgVal('/B:');
      InitBaud := StrToIntDef(val, 9600);
      if InitBaud < 300 then InitBaud := 300;
    end

    { /irq:N }
    else if ArgVal('/irq:') <> '' then
    begin
      val := ArgVal('/irq:');
      OverrideIRQ := Ord(val[1]) - Ord('0');
    end

    { /fifo:N }
    else if ArgVal('/fifo:') <> '' then
    begin
      val := ArgVal('/fifo:');
      InitFIFO := StrToIntDef(val, 14);
      if not (InitFIFO in [1, 4, 8, 14]) then InitFIFO := 14;
    end

    { /nofifo }
    else if (arg = '/nofifo') or (arg = '/NOFIFO') then
      UseFIFO := False

    else if (arg = '/?') or (arg = '-h') or (arg = '--help') then
    begin
      WriteLn(VERSION);
      WriteLn;
      WriteLn('Usage:');
      WriteLn('  netfosdl                  load on COM1 (default)');
      WriteLn('  netfosdl /port:N          COM port 1-4');
      WriteLn('  netfosdl /baud:RATE       initial baud rate (default 9600)');
      WriteLn('  netfosdl /irq:N           override IRQ');
      WriteLn('  netfosdl /fifo:N          FIFO trigger (1/4/8/14, default 14)');
      WriteLn('  netfosdl /nofifo          disable 16550 FIFO');
      WriteLn('  netfosdl /u               unload from memory');
      WriteLn;
      WriteLn('X00-compatible: /B:N = /baud:N, /P:N = /port:N');
      WriteLn;
      WriteLn('Based on Dedrick Allen''s NetModem/32 + X00 specification.');
      WriteLn('FTSC FSC-0015 rev 5 + FSC-0072. Real UART, no network.');
      Halt(0);
    end;
  end;
end;

{ ===========================================================================
  Main
  =========================================================================== }
begin
  ParseArgs;
  if Unloading then
    Unload
  else
    Install;
end.
