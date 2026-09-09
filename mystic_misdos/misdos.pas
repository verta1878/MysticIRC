// ====================================================================
// mystic_misdos : a DOS-style MIS "Waiting For Caller" example
// ====================================================================
//
// This file is part of an optional add-on EXAMPLE for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// misdos - the example entry point.  Draws the classic 1.06 Waiting-For-
// Caller screen (misdos_screen + wfc.ans), then loops:
//
//   * ticks the clock live,
//   * watches the serial port for RING via m_serial (MDL),
//   * on CONNECT, hands off to a local session placeholder,
//   * dispatches every WFC hot-key through misdos_commands.
//
// Uses Mystic's own m_serial (MDL) directly — no FPC Serial unit
// dependency.  Compiles for x86_64, i386, go32v2, and i8086.
//
//   Build:  ./build-misdos.sh          (see that script)
//   Run:    bin/misdos                 (uses modem.ini if present; else
//                                        starts in Local Mode)
// ====================================================================

Program misdos;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Uses
  SysUtils,
  Crt,
  mdm_Config,
  m_serial,
  misdos_Screen,
  misdos_Commands;

Var
  Cfg      : TModemConfig;
  Ser      : TModemSerial;
  Quit     : Boolean;
  LastResp : String;

// ---- AT command helpers (inline, no mdm_modem dependency) -----------

Function SendAT (Const Cmd: String; TimeoutMS: LongInt): String;
Var
  Elapsed : LongInt;
  Chunk   : String;
Begin
  Result  := '';
  Ser.Flush;
  Ser.WriteStr(Cmd + #13);
  Elapsed := 0;
  While Elapsed < TimeoutMS Do Begin
    Chunk := Ser.ReadAvail;
    If Chunk <> '' Then Begin
      Result := Result + Chunk;
      If (Pos('OK', Result) > 0) or (Pos('ERROR', Result) > 0) or
         (Pos('CONNECT', Result) > 0) or (Pos('NO CARRIER', Result) > 0) or
         (Pos('RING', Result) > 0) or (Pos('BUSY', Result) > 0) Then
        Exit;
    End;
    Delay(50);
    Inc(Elapsed, 50);
  End;
End;

Function ModemInit (Const InitString: String): Boolean;
Var
  R : String;
Begin
  Result := False;
  If Not Ser.IsOpen Then Exit;
  Ser.SetDTR(True);
  Delay(250);
  R := SendAT('ATZ', 2000);
  If Pos('OK', R) = 0 Then
    R := SendAT('ATZ', 2000);
  If Pos('OK', R) = 0 Then Exit;
  SendAT('ATE0V1', 1500);
  If (InitString <> '') and (UpperCase(InitString) <> 'ATZ') Then
    SendAT(InitString, 2000);
  Result := True;
End;

Function IsRinging: Boolean;
Var
  Chunk : String;
Begin
  Result := False;
  If Not Ser.IsOpen Then Exit;
  If Ser.GetRI Then Begin Result := True; Exit; End;
  Chunk := Ser.ReadAvail;
  If Chunk <> '' Then Begin
    LastResp := Chunk;
    If Pos('RING', UpperCase(Chunk)) > 0 Then Result := True;
  End;
End;

Function AnswerCall (TimeoutMS: LongInt): Boolean;
Var
  R : String;
Begin
  Result := False;
  If Not Ser.IsOpen Then Exit;
  R := SendAT(Cfg.AnswerStr, TimeoutMS);
  Result := Pos('CONNECT', UpperCase(R)) > 0;
End;

Procedure HangUp;
Begin
  If Not Ser.IsOpen Then Exit;
  Ser.DropDTR;
  Delay(500);
  Ser.SetDTR(True);
  Delay(1100);
  Ser.WriteStr('+++');
  Delay(1100);
  SendAT('ATH0', 2000);
End;

// ---- Screen / session -----------------------------------------------

Procedure Repaint;
Begin
  If Not DrawWfcScreen Then Begin
    TextAttr := 7; ClrScr;
    Writeln('  wfc.ans not found next to the executable.');
    Writeln('  (Copy mystic_misdos/wfc.ans beside the binary.)');
  End;
  SetStatus ('1',
             {$IFDEF WINDOWS}'Win'{$ELSE}{$IFDEF OS2}'OS/2'{$ELSE}{$IFDEF GO32V2}'DOS'{$ELSE}{$IFDEF MSDOS}'DOS'{$ELSE}{$IFDEF DARWIN}'macOS'{$ELSE}'Unix'{$ENDIF}{$ENDIF}{$ENDIF}{$ENDIF}{$ENDIF},
             'Disk', 'None');
  If Cfg.LocalMode Then
    SetModem ('(local mode - no modem)')
  Else
    SetModem (Cfg.Device + ' @ ' + IntToStr(Cfg.Baud));
  SetNode (1, '(waiting)', 'Idle');
End;

Procedure LocalSession;
Begin
  Window (1, 1, 80, 25); TextAttr := 7; ClrScr;
  Writeln('=== Local login (example session) ===');
  Writeln;
  Writeln('A real build would launch a Mystic node here.');
  Writeln('Press any key to return to the Waiting-For-Caller screen.');
  ReadKey;
End;

Procedure OnConnect;
Begin
  SetNode (1, 'CONNECT', 'Answering');
  Delay (1200);
  SetNode (1, 'Caller', 'Online');
  Ser.WriteStr(#13#10'Mystic WFC example — caller session.'#13#10);
  // hand to a Mystic node here in a real build
  Delay (3000);
  HangUp;
  SetNode (1, '(waiting)', 'Idle');
End;

// ---- Main -----------------------------------------------------------

Var
  Act      : TWfcAction;
  LastTick : TDateTime;
Begin
  Cfg := LoadModemConfig('modem.ini');
  If Not FileExists('modem.ini') Then
    Cfg.LocalMode := True;

  Ser      := TModemSerial.Create;
  LastResp := '';

  If (Not Cfg.LocalMode) and Ser.Open(Cfg.Device, Cfg.Baud, Cfg.HardwareFlow) Then Begin
    If Not ModemInit(Cfg.InitString) Then
      Cfg.LocalMode := True;
  End Else
    Cfg.LocalMode := True;

  Repaint;
  LastTick := 0;
  Quit     := False;

  While Not Quit Do Begin
    If (Now - LastTick) > (1/86400) Then Begin
      SetClock (FormatDateTime('hh:nnampm', Now), FormatDateTime('mm/dd/yy', Now));
      LastTick := Now;
    End;

    If (Not Cfg.LocalMode) and IsRinging Then Begin
      If AnswerCall(60000) Then OnConnect;
      Repaint;
    End;

    If KeyPressed Then Begin
      Act := HandleKey(ReadKey);
      Case Act of
        waQuit       : Quit := True;
        waLocalLogin : Begin LocalSession; Repaint; End;
        waAnswer     : Begin
                         If Not Cfg.LocalMode Then
                           If AnswerCall(60000) Then OnConnect;
                         Repaint;
                       End;
        waRedraw     : Repaint;
      Else
        ;
      End;
    End;

    Delay (50);
  End;

  If Not Cfg.LocalMode Then Ser.Close;
  Ser.Free;

  Window (1, 1, 80, 25); TextAttr := 7; GotoXY (1, 25);
  Writeln;
  Writeln('  WFC ended.  (Quit to DOS)');
End.
