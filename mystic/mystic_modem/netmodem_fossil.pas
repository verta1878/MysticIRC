{
  This file is part of the Mystic BBS IRC Fork.

  Copyright (C) 2026 Mystic BBS IRC Fork Contributors

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
}
{ netmodem_fossil - FOSSIL serial test program for i8086 DOS
  Tests all FOSSIL INT 14h functions on real DOS hardware.
  This is the FOSSIL half of netmodem2irc — proves serial I/O
  works before adding TCP sockets.

  Usage: netmodem_fossil [comport]
    comport = 0 (COM1), 1 (COM2), default 0

  Requires: FOSSIL driver loaded (X00, BNU, NetFoss)

  Compile: build-dos.sh netmodem_fossil.pas }

Program netmodem_fossil;

Uses DOS;

Const
  FOSSIL_SIG   = $1954;
  FOSSIL_RXRDY = $0100;
  FOSSIL_TXRDY = $2000;
  FOSSIL_DCD   = $0080;
  BAUD_9600    = $E3;

Var
  ComPort : Word;
  I       : Word;
  B       : Byte;
  Ch      : Char;
  R       : Registers;
  Status  : Word;
  Done    : Boolean;
  Line    : String;

Function Int14(FuncAH, ParamAL: Byte; Port: Word): Word;
Begin
  R.AH := FuncAH;
  R.AL := ParamAL;
  R.DX := Port;
  Intr($14, R);
  Int14 := R.AX;
End;

Function FossilInit(Port: Word): Boolean;
Begin
  FossilInit := (Int14($04, $00, Port) = FOSSIL_SIG);
End;

Procedure FossilDeinit(Port: Word);
Begin
  Int14($05, $00, Port);
End;

Procedure FossilSendChar(Port: Word; C: Char);
Begin
  Int14($01, Ord(C), Port);
End;

Procedure FossilSendStr(Port: Word; S: String);
Var J: Word;
Begin
  For J := 1 to Length(S) Do
    Int14($01, Ord(S[J]), Port);
End;

Function FossilRxReady(Port: Word): Boolean;
Begin
  FossilRxReady := (Int14($03, $00, Port) And FOSSIL_RXRDY) <> 0;
End;

Function FossilRecvChar(Port: Word): Char;
Begin
  FossilRecvChar := Chr(Lo(Int14($02, $00, Port)));
End;

Function FossilCarrier(Port: Word): Boolean;
Begin
  FossilCarrier := (Int14($03, $00, Port) And FOSSIL_DCD) <> 0;
End;

Procedure FossilSetDTR(Port: Word; OnOff: Boolean);
Begin
  If OnOff Then Int14($06, $01, Port)
  Else Int14($06, $00, Port);
End;

Procedure FossilFlush(Port: Word);
Begin
  Int14($08, $00, Port);
End;

Procedure FossilPurgeIn(Port: Word);
Begin
  Int14($0A, $00, Port);
End;

Begin
  WriteLn('netmodem_fossil - FOSSIL serial test');
  WriteLn('------------------------------------');
  WriteLn;

  ComPort := 0;
  If ParamCount >= 1 Then
    Val(ParamStr(1), ComPort, I);

  { Test 1: FOSSIL init }
  Write('FOSSIL init on COM', ComPort + 1, '... ');
  If Not FossilInit(ComPort) Then Begin
    WriteLn('FAILED - no FOSSIL driver loaded!');
    WriteLn('Load X00, BNU, or NetFoss first.');
    Halt(1);
  End;
  WriteLn('OK (signature $1954 confirmed)');

  { Test 2: Set baud rate }
  Write('Setting 9600 baud 8N1... ');
  Int14($00, BAUD_9600, ComPort);
  WriteLn('OK');

  { Test 3: Purge buffers }
  Write('Purging buffers... ');
  FossilPurgeIn(ComPort);
  Int14($09, $00, ComPort);
  WriteLn('OK');

  { Test 4: Status }
  Status := Int14($03, $00, ComPort);
  WriteLn('Status: $', Copy(HexStr(Status, 4), 1, 4));
  Write('  RX ready: ');
  If (Status And FOSSIL_RXRDY) <> 0 Then WriteLn('YES') Else WriteLn('no');
  Write('  TX ready: ');
  If (Status And FOSSIL_TXRDY) <> 0 Then WriteLn('YES') Else WriteLn('no');
  Write('  Carrier:  ');
  If (Status And FOSSIL_DCD) <> 0 Then WriteLn('YES') Else WriteLn('no');

  { Test 5: Send ANSI welcome }
  WriteLn;
  WriteLn('Sending ANSI welcome to modem...');
  FossilSendStr(ComPort, #27'[2J');
  FossilSendStr(ComPort, #27'[1;37m');
  FossilSendStr(ComPort, 'netmodem_fossil v1.0 - FOSSIL test' + #13#10);
  FossilSendStr(ComPort, #27'[1;33m');
  FossilSendStr(ComPort, 'Connected to COM' + Chr(ComPort + 49) + #13#10);
  FossilSendStr(ComPort, #27'[0;37m');
  FossilSendStr(ComPort, 'Type text, it echoes back. ESC to quit.' + #13#10);
  FossilSendStr(ComPort, #13#10);
  FossilFlush(ComPort);
  WriteLn('Sent.');

  { Test 6: Echo loop }
  WriteLn;
  WriteLn('Echo mode active. Press ESC locally to quit.');
  WriteLn('Characters from modem will echo back to modem + local console.');
  WriteLn;

  Done := False;
  Line := '';

  Repeat
    { Check for incoming data from FOSSIL }
    While FossilRxReady(ComPort) Do Begin
      Ch := FossilRecvChar(ComPort);

      Case Ch of
        #27 : Begin
                WriteLn;
                WriteLn('ESC received from remote - disconnecting.');
                Done := True;
              End;
        #13 : Begin
                FossilSendStr(ComPort, #13#10);
                WriteLn('Remote: ', Line);
                Line := '';
              End;
        #8, #127 : Begin
                If Length(Line) > 0 Then Begin
                  Dec(Line[0]);
                  FossilSendStr(ComPort, #8' '#8);
                End;
              End;
      Else
        Line := Line + Ch;
        FossilSendChar(ComPort, Ch);
      End;
    End;

    { Check local keyboard }
    If KeyPressed Then Begin
      Ch := ReadKey;
      If Ch = #27 Then Begin
        WriteLn;
        WriteLn('ESC pressed locally - disconnecting.');
        Done := True;
      End Else Begin
        FossilSendChar(ComPort, Ch);
        Write(Ch);
      End;
    End;

    { Check carrier }
    If Not FossilCarrier(ComPort) Then Begin
      { Only warn if we had carrier before }
    End;

  Until Done;

  { Cleanup }
  WriteLn;
  WriteLn('Cleaning up...');
  FossilSendStr(ComPort, #13#10'Disconnecting...' + #13#10);
  FossilFlush(ComPort);
  FossilSetDTR(ComPort, False);
  FossilDeinit(ComPort);
  WriteLn('FOSSIL deinitialized. Done.');
End.
