// ====================================================================
// mystic_modem : legacy dialup / serial support for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// mdm_modem - Hayes AT-command modem control on top of mdm_serial.
// Handles init, wait-for-ring, answer, dial-out, connect detection and
// baud parsing, carrier-loss detection, and hangup.  Result codes are
// read as verbose text (ATV1) so we can parse CONNECT strings for the
// negotiated speed.
// ====================================================================

Unit mdm_Modem;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  SysUtils,
  mdm_Serial;

Type
  TModemState = (msIdle, msInitialised, msRinging, msConnected, msError);

  TModemResult = (mrNone, mrOK, mrConnect, mrRing, mrNoCarrier,
                  mrError, mrNoDialtone, mrBusy, mrNoAnswer, mrTimeout);

  TModem = Class
  Private
    FSer      : TModemSerial;
    FState    : TModemState;
    FInitStr  : String;
    FConnBaud : LongInt;
    FLastResp : String;

    // Read result codes for up to TimeoutMS, returning the first recognised
    // one.  Accumulates raw text into FLastResp for CONNECT-speed parsing.
    Function  WaitResult (TimeoutMS: LongInt): TModemResult;
    Function  ParseResult (Const S: String): TModemResult;
    Procedure ParseConnectSpeed (Const S: String);
  Public
    Constructor Create (ASerial: TModemSerial);
    Destructor  Destroy; Override;

    // Send an AT command, wait for a result code.
    Function  Command (Const Cmd: String; TimeoutMS: LongInt = 3000): TModemResult;

    // Send the init string (ATZ + user init).  True if the modem answers OK.
    Function  Initialise (Const InitString: String = 'ATZ'): Boolean;

    // Non-blocking ring check (reads RI line and/or a pending RING result).
    Function  IsRinging: Boolean;

    // Answer an incoming call.  AnswerCmd defaults to ATA; pass the sysop's
    // configured answer string to override.  On CONNECT, FConnBaud holds speed.
    Function  Answer (TimeoutMS: LongInt = 60000; Const AnswerCmd: String = 'ATA'): Boolean;

    // Dial out (ATDT<number>).  On CONNECT, FConnBaud holds the speed.
    Function  Dial (Const Number: String; TimeoutMS: LongInt = 60000): Boolean;

    // True while carrier is present (DCD via DSR proxy or lack of NO CARRIER).
    Function  CarrierPresent: Boolean;

    // Hang up: drop DTR, or +++ / ATH fallback.
    Procedure HangUp;

    Property State     : TModemState Read FState;
    Property ConnBaud  : LongInt     Read FConnBaud;
    Property LastResp  : String      Read FLastResp;
    Property Serial    : TModemSerial Read FSer;
  End;

Implementation

Const
  CR = #13;
  LF = #10;

Constructor TModem.Create (ASerial: TModemSerial);
Begin
  Inherited Create;
  FSer      := ASerial;
  FState    := msIdle;
  FInitStr  := 'ATZ';
  FConnBaud := 0;
  FLastResp := '';
End;

Destructor TModem.Destroy;
Begin
  Inherited Destroy;
End;

Function TModem.ParseResult (Const S: String): TModemResult;
Var
  U : String;
Begin
  U := UpperCase(S);
  Result := mrNone;
  If Pos('CONNECT', U)     > 0 Then Result := mrConnect Else
  If Pos('RING', U)        > 0 Then Result := mrRing Else
  If Pos('NO CARRIER', U)  > 0 Then Result := mrNoCarrier Else
  If Pos('NO DIALTONE', U) > 0 Then Result := mrNoDialtone Else
  If Pos('BUSY', U)        > 0 Then Result := mrBusy Else
  If Pos('NO ANSWER', U)   > 0 Then Result := mrNoAnswer Else
  If Pos('ERROR', U)       > 0 Then Result := mrError Else
  If Pos('OK', U)          > 0 Then Result := mrOK;
End;

Procedure TModem.ParseConnectSpeed (Const S: String);
Var
  U       : String;
  I, P, L : LongInt;
  Num     : String;
Begin
  U := UpperCase(S);
  P := Pos('CONNECT', U);
  If P = 0 Then Exit;
  Inc(P, 7);
  L := Length(U);
  // skip spaces after CONNECT
  While (P <= L) and (U[P] = ' ') Do Inc(P);
  Num := '';
  For I := P to L Do
    If (U[I] >= '0') and (U[I] <= '9') Then Num := Num + U[I]
    Else Break;
  If Num <> '' Then FConnBaud := StrToIntDef(Num, 0);
End;

Function TModem.WaitResult (TimeoutMS: LongInt): TModemResult;
Var
  Elapsed : LongInt;
  Chunk   : String;
  R       : TModemResult;
Begin
  Result    := mrNone;
  FLastResp := '';
  Elapsed   := 0;

  While Elapsed < TimeoutMS Do Begin
    Chunk := FSer.ReadAvail;
    If Chunk <> '' Then Begin
      FLastResp := FLastResp + Chunk;
      R := ParseResult(FLastResp);
      If R <> mrNone Then Begin
        If R = mrConnect Then ParseConnectSpeed(FLastResp);
        Result := R;
        Exit;
      End;
    End;
    Sleep(50);
    Inc(Elapsed, 50);
  End;

  Result := mrTimeout;
End;

Function TModem.Command (Const Cmd: String; TimeoutMS: LongInt): TModemResult;
Begin
  FSer.Flush;
  FSer.WriteStr(Cmd + CR);
  Result := WaitResult(TimeoutMS);
End;

Function TModem.Initialise (Const InitString: String): Boolean;
Begin
  FInitStr := InitString;
  Result := False;
  If Not FSer.IsOpen Then Exit;

  // Make sure we're in a known state: reset, verbose result codes, echo off.
  FSer.SetDTR(True);
  Sleep(250);

  If Command('ATZ', 2000) <> mrOK Then
    // some modems need a moment after reset; try once more
    If Command('ATZ', 2000) <> mrOK Then Exit;

  Command('ATE0V1', 1500);          // echo off, verbose results

  If InitString <> '' Then
    If UpperCase(InitString) <> 'ATZ' Then
      Command(InitString, 2000);

  FState := msInitialised;
  Result := True;
End;

Function TModem.IsRinging: Boolean;
Var
  Chunk : String;
Begin
  Result := False;
  If Not FSer.IsOpen Then Exit;

  // Hardware RI line is the fastest signal.
  If FSer.GetRing Then Begin Result := True; Exit; End;

  // Otherwise look for a RING result code in whatever text is pending.
  Chunk := FSer.ReadAvail;
  If Chunk <> '' Then Begin
    FLastResp := Chunk;
    If ParseResult(Chunk) = mrRing Then Result := True;
  End;
  If Result Then FState := msRinging;
End;

Function TModem.Answer (TimeoutMS: LongInt; Const AnswerCmd: String): Boolean;
Begin
  Result := False;
  If Not FSer.IsOpen Then Exit;
  If Command(AnswerCmd, TimeoutMS) = mrConnect Then Begin
    FState := msConnected;
    Result := True;
  End Else
    FState := msInitialised;
End;

Function TModem.Dial (Const Number: String; TimeoutMS: LongInt): Boolean;
Begin
  Result := False;
  If Not FSer.IsOpen Then Exit;
  If Command('ATDT' + Number, TimeoutMS) = mrConnect Then Begin
    FState := msConnected;
    Result := True;
  End Else
    FState := msInitialised;
End;

Function TModem.CarrierPresent: Boolean;
Begin
  // DSR/DCD proxy: most modems raise DSR while a call is up.  A more precise
  // build can map DCD specifically; DSR is the portable approximation the FPC
  // Serial unit exposes.
  Result := FSer.IsOpen and FSer.GetDSR and (FState = msConnected);
End;

Procedure TModem.HangUp;
Begin
  If Not FSer.IsOpen Then Exit;

  // Preferred: drop DTR (modem configured with AT&D2 hangs up on DTR loss).
  FSer.DropDTR;
  Sleep(500);
  FSer.SetDTR(True);

  // Fallback escape sequence + ATH in case &D2 isn't set.
  Sleep(1100);
  FSer.WriteStr('+++');
  Sleep(1100);
  Command('ATH0', 2000);

  FState := msInitialised;
  FConnBaud := 0;
End;

End.
