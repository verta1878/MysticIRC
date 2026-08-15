{$MODE OBJFPC}
{$H+}
unit serial;
{ Serial port unit for DOS - direct UART 8250/16550 access.
  Same API as FPC serial unit (Unix/Windows).
  Supports COM1-COM4 via hardware I/O ports. }

interface

type
  TParityType = (NoneParity, OddParity, EvenParity, MarkParity, SpaceParity);
  TSerialHandle = LongInt;
  TSerialFlags = set of (sfRtsControl);
  TSerialState = record
    BitsPerSec: LongInt;
    ByteSize: Integer;
    Parity: TParityType;
    StopBits: Integer;
    Flags: TSerialFlags;
  end;

const
  COM_BASE: array[0..3] of Word = ($3F8, $2F8, $3E8, $2E8);
  COM_IRQ: array[0..3] of Byte = (4, 3, 4, 3);
  UART_RBR = 0; UART_THR = 0; UART_IER = 1; UART_IIR = 2;
  UART_FCR = 2; UART_LCR = 3; UART_MCR = 4; UART_LSR = 5;
  UART_MSR = 6; UART_DLL = 0; UART_DLH = 1;
  LSR_DR = $01; LSR_THRE = $20; LSR_TEMT = $40;
  MCR_DTR = $01; MCR_RTS = $02; MCR_OUT2 = $08;
  MSR_CTS = $10; MSR_DSR = $20; MSR_RI = $40; MSR_DCD = $80;
  UART_CLOCK = 115200;

function  SerOpen(const DeviceName: String): TSerialHandle;
procedure SerClose(Handle: TSerialHandle);
function  SerRead(Handle: TSerialHandle; var Buffer; Count: LongInt): LongInt;
function  SerWrite(Handle: TSerialHandle; const Buffer; Count: LongInt): LongInt;
procedure SerSetParams(Handle: TSerialHandle; BitsPerSec: LongInt;
            ByteSize: Integer; Parity: TParityType; StopBits: Integer;
            Flags: TSerialFlags);
function  SerSaveState(Handle: TSerialHandle): TSerialState;
procedure SerRestoreState(Handle: TSerialHandle; State: TSerialState);
procedure SerSetDTR(Handle: TSerialHandle; State: Boolean);
procedure SerSetRTS(Handle: TSerialHandle; State: Boolean);
function  SerGetCTS(Handle: TSerialHandle): Boolean;
function  SerGetDSR(Handle: TSerialHandle): Boolean;
function  SerGetDCD(Handle: TSerialHandle): Boolean;
function  SerGetRI(Handle: TSerialHandle): Boolean;
procedure SerFlushInput(Handle: TSerialHandle);
procedure SerFlushOutput(Handle: TSerialHandle);
procedure SerSync(Handle: TSerialHandle);
procedure SerDrain(Handle: TSerialHandle);
function  SerDataAvailable(Handle: TSerialHandle): Boolean;
procedure SerBreak(Handle: TSerialHandle);
function  SerDetectUART(Handle: TSerialHandle): String;
function  SerGetBase(Handle: TSerialHandle): Word;
procedure SerSetFIFO(Handle: TSerialHandle; Enable: Boolean; TriggerLevel: Byte);

implementation

uses SysUtils{$IFDEF GO32V2}, Ports{$ENDIF};

function GetBase(Handle: TSerialHandle): Word; {$IFDEF FPC}inline;{$ENDIF}
begin
  if (Handle >= 0) and (Handle <= 3) then Result := COM_BASE[Handle]
  else Result := 0;
end;

function SerOpen(const DeviceName: String): TSerialHandle;
var PortIdx: Integer; Base: Word;
begin
  Result := -1;
  if Length(DeviceName) < 4 then Exit;
  case UpCase(DeviceName[4]) of
    '1': PortIdx := 0; '2': PortIdx := 1;
    '3': PortIdx := 2; '4': PortIdx := 3;
  else Exit; end;
  Base := COM_BASE[PortIdx];
  { B-6 note: scratch register probe may fail on some UART clones
    that don't implement register 7. Works on 8250/16450/16550. }
  Port[Base + 7] := $55;
  if Port[Base + 7] <> $55 then Exit;
  Result := PortIdx;
  SerSetParams(Result, 9600, 8, NoneParity, 1, []);
  SerSetDTR(Result, True); SerSetRTS(Result, True);
end;

procedure SerClose(Handle: TSerialHandle);
var B: Word;
begin
  B := GetBase(Handle); if B = 0 then Exit;
  SerSetDTR(Handle, False); SerSetRTS(Handle, False);
  Port[B + UART_IER] := 0; Port[B + UART_FCR] := 0;
end;

function SerRead(Handle: TSerialHandle; var Buffer; Count: LongInt): LongInt;
var B: Word; P: PByte; I: LongInt;
begin
  Result := 0; B := GetBase(Handle); if B = 0 then Exit;
  P := @Buffer;
  for I := 0 to Count-1 do begin
    if (Port[B + UART_LSR] and LSR_DR) = 0 then Break;
    P^ := Port[B + UART_RBR]; Inc(P); Inc(Result);
  end;
end;

function SerWrite(Handle: TSerialHandle; const Buffer; Count: LongInt): LongInt;
var B: Word; P: PByte; I, T: LongInt;
begin
  Result := 0; B := GetBase(Handle); if B = 0 then Exit;
  P := @Buffer;
  for I := 0 to Count-1 do begin
    T := 100000;
    while ((Port[B + UART_LSR] and LSR_THRE) = 0) and (T > 0) do Dec(T);
    if T = 0 then Break;
    Port[B + UART_THR] := P^; Inc(P); Inc(Result);
  end;
end;

procedure SerSetParams(Handle: TSerialHandle; BitsPerSec: LongInt;
  ByteSize: Integer; Parity: TParityType; StopBits: Integer; Flags: TSerialFlags);
var B: Word; Div_: Word; LCR: Byte;
begin
  B := GetBase(Handle); if B = 0 then Exit;
  if BitsPerSec > 0 then Div_ := UART_CLOCK div BitsPerSec else Div_ := 12;
  case ByteSize of 5: LCR:=$00; 6: LCR:=$01; 7: LCR:=$02; else LCR:=$03; end;
  if StopBits = 2 then LCR := LCR or $04;
  case Parity of
    OddParity: LCR := LCR or $08; EvenParity: LCR := LCR or $18;
    MarkParity: LCR := LCR or $28; SpaceParity: LCR := LCR or $38;
  else end;
  Port[B + UART_LCR] := LCR or $80;
  Port[B + UART_DLL] := Lo(Div_); Port[B + UART_DLH] := Hi(Div_);
  Port[B + UART_LCR] := LCR;
end;

function SerSaveState(Handle: TSerialHandle): TSerialState;
begin Result.BitsPerSec:=9600; Result.ByteSize:=8; Result.Parity:=NoneParity; Result.StopBits:=1; Result.Flags:=[]; end;

procedure SerRestoreState(Handle: TSerialHandle; State: TSerialState);
begin SerSetParams(Handle, State.BitsPerSec, State.ByteSize, State.Parity, State.StopBits, State.Flags); end;

procedure SerSetDTR(Handle: TSerialHandle; State: Boolean);
var B: Word; M: Byte;
begin B:=GetBase(Handle); if B=0 then Exit; M:=Port[B+UART_MCR];
  if State then M:=M or MCR_DTR else M:=M and not MCR_DTR; Port[B+UART_MCR]:=M; end;

procedure SerSetRTS(Handle: TSerialHandle; State: Boolean);
var B: Word; M: Byte;
begin B:=GetBase(Handle); if B=0 then Exit; M:=Port[B+UART_MCR];
  if State then M:=M or MCR_RTS else M:=M and not MCR_RTS; Port[B+UART_MCR]:=M; end;

function SerGetCTS(Handle: TSerialHandle): Boolean;
begin Result:=(Port[GetBase(Handle)+UART_MSR] and MSR_CTS)<>0; end;
function SerGetDSR(Handle: TSerialHandle): Boolean;
begin Result:=(Port[GetBase(Handle)+UART_MSR] and MSR_DSR)<>0; end;
function SerGetDCD(Handle: TSerialHandle): Boolean;
begin Result:=(Port[GetBase(Handle)+UART_MSR] and MSR_DCD)<>0; end;
function SerGetRI(Handle: TSerialHandle): Boolean;
begin Result:=(Port[GetBase(Handle)+UART_MSR] and MSR_RI)<>0; end;

procedure SerFlushInput(Handle: TSerialHandle);
var B: Word; X: Byte; Limit: LongInt;
begin B:=GetBase(Handle); if B=0 then Exit;
  Limit := 0;
  while ((Port[B+UART_LSR] and LSR_DR)<>0) and (Limit < 65536) do
    begin X:=Port[B+UART_RBR]; Inc(Limit); end;
end;  { B-4 fix: added iteration limit }

procedure SerFlushOutput(Handle: TSerialHandle); begin SerDrain(Handle); end;
procedure SerSync(Handle: TSerialHandle); begin SerDrain(Handle); end;

procedure SerDrain(Handle: TSerialHandle);
var B: Word; Timeout: LongInt;
begin B:=GetBase(Handle); if B=0 then Exit;
  Timeout := 0;
  while ((Port[B+UART_LSR] and LSR_TEMT)=0) and (Timeout < 50000) do Inc(Timeout);
end;  { B-3 fix: added timeout counter }

function SerDataAvailable(Handle: TSerialHandle): Boolean;
begin Result:=(Port[GetBase(Handle)+UART_LSR] and LSR_DR)<>0; end;

procedure SerBreak(Handle: TSerialHandle);
var B: Word; L: Byte; I: LongInt;
begin B:=GetBase(Handle); if B=0 then Exit;
  L:=Port[B+UART_LCR];
  Port[B+UART_LCR]:=L or $40;
  For I := 1 to 10000 Do;  { B-5 fix: delay between set/clear }
  Port[B+UART_LCR]:=L;
end;

function SerDetectUART(Handle: TSerialHandle): String;
var B: Word;
begin
  B:=GetBase(Handle); if B=0 then begin Result:='none'; Exit; end;
  Port[B+UART_FCR]:=$E7;
  if (Port[B+UART_IIR] and $C0)=$C0 then begin
    if (Port[B+UART_IIR] and $20)<>0 then Result:='16750' else Result:='16550A';
  end else if (Port[B+UART_IIR] and $80)<>0 then Result:='16550'
  else begin Port[B+7]:=$5A; if Port[B+7]=$5A then Result:='16450' else Result:='8250'; end;
  Port[B+UART_FCR]:=$00;
end;

function SerGetBase(Handle: TSerialHandle): Word;
begin Result:=GetBase(Handle); end;

procedure SerSetFIFO(Handle: TSerialHandle; Enable: Boolean; TriggerLevel: Byte);
var B: Word; F: Byte;
begin B:=GetBase(Handle); if B=0 then Exit;
  if not Enable then begin Port[B+UART_FCR]:=0; Exit; end;
  case TriggerLevel of 1:F:=$01; 4:F:=$41; 8:F:=$81; else F:=$C1; end;
  Port[B+UART_FCR]:=F or $06;
end;

end.
