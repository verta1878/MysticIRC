{$MODE OBJFPC}
{$H+}
unit mtserial;
{ Serial/modem connection with AT command dialer

  Copyright (C) 2026 FPC264IRC Contributors
  License: GPLv3 }

interface

{$IFDEF GO32V2}
uses serial, serial_irq;

type
  TModemDialer = class
  private
    FHandle: TSerialHandle;
    FInitStr: String;
    FBaud: LongInt;
    FConnected: Boolean;
    procedure SendATCmd(const Cmd: String);
    function WaitResponse(TimeoutMs: LongInt): String;
  public
    constructor Create(ComPort: Byte; Baud: LongInt);
    destructor Destroy; override;
    procedure Init(const InitStr: String);
    function Dial(const Number: String): Boolean;
    procedure Hangup;
    property Handle: TSerialHandle read FHandle;
    property Connected: Boolean read FConnected;
  end;
{$ENDIF}

implementation

{$IFDEF GO32V2}
uses SysUtils;

constructor TModemDialer.Create(ComPort: Byte; Baud: LongInt);
begin
  inherited Create;
  FBaud := Baud;
  FConnected := False;
  FInitStr := 'ATZ';
  FHandle := SerOpen('COM' + Chr(Ord('1') + ComPort));
  if FHandle >= 0 then begin
    SerSetParams(FHandle, Baud, 8, NoneParity, 1, []);
    SerSetDTR(FHandle, True);
    SerSetRTS(FHandle, True);
    SerEnableIRQ(FHandle);
  end;
end;

destructor TModemDialer.Destroy;
begin
  if FConnected then Hangup;
  if FHandle >= 0 then begin
    SerDisableIRQ(FHandle);
    SerClose(FHandle);
  end;
  inherited;
end;

procedure TModemDialer.SendATCmd(const Cmd: String);
var S: String;
begin
  S := Cmd + #13;
  SerWrite(FHandle, S[1], Length(S));
end;

function TModemDialer.WaitResponse(TimeoutMs: LongInt): String;
var
  B: Byte;
  Start: QWord;
begin
  Result := '';
  Start := Trunc(Now * 86400000);
  while (Trunc(Now * 86400000) - Start) < TimeoutMs do begin
    if SerRingCount(FHandle) > 0 then begin
      SerReadRing(FHandle, B, 1);
      if B = 13 then begin
        if Result <> '' then Exit;
      end else if B >= 32 then
        Result := Result + Chr(B);
    end;
  end;
end;

procedure TModemDialer.Init(const InitStr: String);
begin
  FInitStr := InitStr;
  SendATCmd('ATZ');
  WaitResponse(2000);
  if InitStr <> 'ATZ' then begin
    SendATCmd(InitStr);
    WaitResponse(2000);
  end;
end;

function TModemDialer.Dial(const Number: String): Boolean;
var Resp: String;
begin
  Result := False;
  SendATCmd('ATD' + Number);
  Resp := WaitResponse(60000); { 60 second timeout }
  if Pos('CONNECT', Resp) > 0 then begin
    FConnected := True;
    Result := True;
  end;
end;

procedure TModemDialer.Hangup;
begin
  SerSetDTR(FHandle, False);
  { Wait 1 second }
  SerSetDTR(FHandle, True);
  SendATCmd('+++');
  WaitResponse(1500);
  SendATCmd('ATH0');
  WaitResponse(2000);
  FConnected := False;
end;
{$ENDIF}

end.
