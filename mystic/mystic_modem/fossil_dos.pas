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
{ fossil_dos - 16-bit DOS FOSSIL driver (INT 14h only)
  Pure i8086-msdos FOSSIL interface. No classes, no mdm_serial.
  For netmodem2irc and any real-mode DOS program needing serial I/O
  through a FOSSIL driver (X00, BNU, NetFoss).
  FOSSIL spec: FidoNet FSC-0015, FSC-0072 }

Unit fossil_dos;

{$IFDEF FPC}{$MODE OBJFPC}{$ENDIF}

Interface

Uses
  DOS;

Const
  FOSSIL_SIGNATURE = $1954;
  FOSSIL_RX_READY  = $0100;
  FOSSIL_TX_READY  = $2000;
  FOSSIL_DCD       = $0080;

Function  Fossil_Init     (Port: Word) : Boolean;
Procedure Fossil_Deinit   (Port: Word);
Function  Fossil_SendByte (Port: Word; B: Byte) : Boolean;
Function  Fossil_SendStr  (Port: Word; Const S: String) : Word;
Function  Fossil_RecvByte (Port: Word; Var B: Byte) : Boolean;
Function  Fossil_RxReady  (Port: Word) : Boolean;
Function  Fossil_Carrier  (Port: Word) : Boolean;
Procedure Fossil_SetDTR   (Port: Word; OnOff: Boolean);
Procedure Fossil_Flush    (Port: Word);
Procedure Fossil_PurgeIn  (Port: Word);
Procedure Fossil_PurgeOut (Port: Word);
Function  Fossil_Status   (Port: Word) : Word;
Procedure Fossil_SetBaud  (Port: Word; BaudInit: Byte);

Implementation

Function Int14 (FuncAH, ParamAL: Byte; Port: Word) : Word;
Var R : Registers;
Begin
  R.AH := FuncAH; R.AL := ParamAL; R.DX := Port;
  Intr($14, R); Int14 := R.AX;
End;

Function Fossil_Init (Port: Word) : Boolean;
Begin Fossil_Init := (Int14($04, $00, Port) = FOSSIL_SIGNATURE); End;

Procedure Fossil_Deinit (Port: Word);
Begin Int14($05, $00, Port); End;

Function Fossil_SendByte (Port: Word; B: Byte) : Boolean;
Begin Int14($01, B, Port); Fossil_SendByte := True; End;

Function Fossil_SendStr (Port: Word; Const S: String) : Word;
Var I : Word;
Begin
  For I := 1 to Length(S) Do Int14($01, Byte(S[I]), Port);
  Fossil_SendStr := Length(S);
End;

Function Fossil_RecvByte (Port: Word; Var B: Byte) : Boolean;
Begin
  If (Int14($03, $00, Port) And FOSSIL_RX_READY) <> 0 Then Begin
    B := Lo(Int14($02, $00, Port)); Fossil_RecvByte := True;
  End Else Fossil_RecvByte := False;
End;

Function Fossil_RxReady (Port: Word) : Boolean;
Begin Fossil_RxReady := (Int14($03, $00, Port) And FOSSIL_RX_READY) <> 0; End;

Function Fossil_Carrier (Port: Word) : Boolean;
Begin Fossil_Carrier := (Int14($03, $00, Port) And FOSSIL_DCD) <> 0; End;

Procedure Fossil_SetDTR (Port: Word; OnOff: Boolean);
Begin If OnOff Then Int14($06, $01, Port) Else Int14($06, $00, Port); End;

Procedure Fossil_Flush (Port: Word);
Begin Int14($08, $00, Port); End;

Procedure Fossil_PurgeIn (Port: Word);
Begin Int14($0A, $00, Port); End;

Procedure Fossil_PurgeOut (Port: Word);
Begin Int14($09, $00, Port); End;

Function Fossil_Status (Port: Word) : Word;
Begin Fossil_Status := Int14($03, $00, Port); End;

Procedure Fossil_SetBaud (Port: Word; BaudInit: Byte);
Begin Int14($00, BaudInit, Port); End;

End.
