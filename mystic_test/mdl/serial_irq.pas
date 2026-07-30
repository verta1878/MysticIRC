{ ===========================================================================
  serial_irq — interrupt-driven receive ring buffer for DOS UART
  Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)
  GPLv3 — see LICENSE
  ---------------------------------------------------------------------------
  Sits on top of serial.pas. When enabled via SerEnableIRQ, incoming
  bytes are captured by an ISR and stored in a 4KB ring buffer.
  
  Credits: kiddo (ring buffer + ISR), sysop/0 (serial.pas UART layer)
  =========================================================================== }

{$MODE OBJFPC}{$H+}

unit serial_irq;

interface

uses serial;

procedure SerEnableIRQ(Handle: TSerialHandle);
procedure SerDisableIRQ(Handle: TSerialHandle);
function  SerReadRing(Handle: TSerialHandle; var Buffer; Count: LongInt): LongInt;
function  SerRingCount(Handle: TSerialHandle): Word;
function  SerRingOverruns(Handle: TSerialHandle): LongInt;
function  SerIRQActive(Handle: TSerialHandle): Boolean;

implementation

{$IFDEF GO32V2}
uses Go32, Ports;
{$ELSE}
uses Dos;
{$ENDIF}

const
  RING_SIZE = 4096;
  PIC1_CMD  = $20;
  PIC1_DATA = $21;
  EOI_CMD   = $20;

type
  TSerRingBuffer = record
    Data: array[0..RING_SIZE - 1] of Byte;
    Head: Word;
    Tail: Word;
    Count: Word;
    Overruns: LongInt;
  end;

  TSerIRQState = record
    Active: Boolean;
    ComIdx: Integer;
    Base: Word;
    IRQNum: Byte;
    {$IFDEF GO32V2}
    OldHandler: TSegInfo;
    {$ELSE}
    OldHandler: Pointer;
    {$ENDIF}
    OldMask: Byte;
    Ring: TSerRingBuffer;
  end;

var
  IRQState: array[0..3] of TSerIRQState;

{ --- ISR core --- }
procedure SerISR_Core(ComIdx: Integer);
var Base: Word; Ch: Byte;
begin
  Base := IRQState[ComIdx].Base;
  while (Port[Base + UART_LSR] and LSR_DR) <> 0 do
  begin
    Ch := Port[Base + UART_RBR];
    with IRQState[ComIdx].Ring do
      if Count < RING_SIZE then
      begin
        Data[Head] := Ch;
        Head := (Head + 1) and (RING_SIZE - 1);
        Inc(Count);
      end
      else Inc(Overruns);
  end;
  Port[PIC1_CMD] := EOI_CMD;
end;

{$IFDEF GO32V2}
procedure SerISR_COM1; interrupt; begin SerISR_Core(0); end;
procedure SerISR_COM2; interrupt; begin SerISR_Core(1); end;
procedure SerISR_COM3; interrupt; begin SerISR_Core(2); end;
procedure SerISR_COM4; interrupt; begin SerISR_Core(3); end;

const ISR_TABLE: array[0..3] of Pointer = (
  @SerISR_COM1, @SerISR_COM2, @SerISR_COM3, @SerISR_COM4);
{$ENDIF}

procedure SerEnableIRQ(Handle: TSerialHandle);
var
  Base: Word; IRQ, IntNo: Byte; Mask: Byte;
  {$IFDEF GO32V2} NewSeg: TSegInfo; {$ENDIF}
begin
  if (Handle < 0) or (Handle > 3) then Exit;
  if IRQState[Handle].Active then Exit;
  Base := SerGetBase(Handle);
  if Base = 0 then Exit;
  IRQ := COM_IRQ[Handle];

  with IRQState[Handle] do
  begin
    Active := True; ComIdx := Handle;
    IRQState[Handle].Base := Base; IRQNum := IRQ;
    Ring.Head := 0; Ring.Tail := 0; Ring.Count := 0; Ring.Overruns := 0;
  end;

  {$IFDEF GO32V2}
  IntNo := IRQ + $08;
  Get_pm_interrupt(IntNo, IRQState[Handle].OldHandler);
  NewSeg.Offset := ISR_TABLE[Handle];
  NewSeg.Segment := Get_cs;
  Set_pm_interrupt(IntNo, NewSeg);
  {$ENDIF}

  Port[Base + UART_IER] := Port[Base + UART_IER] or $01;
  Port[Base + UART_MCR] := Port[Base + UART_MCR] or MCR_OUT2;
  Mask := Port[PIC1_DATA];
  IRQState[Handle].OldMask := Mask and (1 shl IRQ);
  Port[PIC1_DATA] := Mask and not (1 shl IRQ);
end;

procedure SerDisableIRQ(Handle: TSerialHandle);
var Base: Word; IRQ, IntNo: Byte;
begin
  if (Handle < 0) or (Handle > 3) then Exit;
  if not IRQState[Handle].Active then Exit;
  Base := IRQState[Handle].Base; IRQ := IRQState[Handle].IRQNum;

  Port[Base + UART_IER] := Port[Base + UART_IER] and not $01;
  Port[Base + UART_MCR] := Port[Base + UART_MCR] and not MCR_OUT2;
  if IRQState[Handle].OldMask <> 0 then
    Port[PIC1_DATA] := Port[PIC1_DATA] or (1 shl IRQ);

  {$IFDEF GO32V2}
  IntNo := IRQ + $08;
  Set_pm_interrupt(IntNo, IRQState[Handle].OldHandler);
  {$ENDIF}
  IRQState[Handle].Active := False;
end;

function SerReadRing(Handle: TSerialHandle; var Buffer; Count: LongInt): LongInt;
var P: PByte; I: LongInt;
begin
  Result := 0; P := @Buffer;
  with IRQState[Handle].Ring do
    for I := 0 to Count - 1 do
    begin
      if IRQState[Handle].Ring.Count = 0 then Break;
      P^ := Data[Tail];
      Tail := (Tail + 1) and (RING_SIZE - 1);
      Dec(IRQState[Handle].Ring.Count);
      Inc(P); Inc(Result);
    end;
end;

function SerRingCount(Handle: TSerialHandle): Word;
begin
  if (Handle >= 0) and (Handle <= 3) and IRQState[Handle].Active then
    Result := IRQState[Handle].Ring.Count
  else Result := 0;
end;

function SerRingOverruns(Handle: TSerialHandle): LongInt;
begin
  if (Handle >= 0) and (Handle <= 3) and IRQState[Handle].Active then
    Result := IRQState[Handle].Ring.Overruns
  else Result := 0;
end;

function SerIRQActive(Handle: TSerialHandle): Boolean;
begin
  Result := (Handle >= 0) and (Handle <= 3) and IRQState[Handle].Active;
end;

var I: Integer;

initialization
  for I := 0 to 3 do begin
    IRQState[I].Active := False;
    IRQState[I].ComIdx := I;
  end;

finalization
  for I := 0 to 3 do
    if IRQState[I].Active then SerDisableIRQ(I);

end.
