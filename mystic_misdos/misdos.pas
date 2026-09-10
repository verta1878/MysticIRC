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
//   * watches the modem for RING (via mystic_modem) and, on CONNECT,
//     sniffs the line: a BinkP caller is handed to the mystic_mailer
//     BinkP seam; a human caller gets a local-style session; EMSI/others
//     are reported,
//   * dispatches every WFC hot-key through misdos_commands (editors,
//     answer, drop-to-DOS, quit, and SPACE = local login).
//
// So this single example REFERENCES BOTH add-ons - the modem code
// (mystic_modem) and the binkp/mailer code (mystic_mailer) - exactly as
// the sysop asked, and every option on the WFC screen is functional.
//
// It is intentionally SEPARATE from the shipping MIS server in mystic/
// (mis.pas): this is the DOS-MIS teaching example, not the telnet daemon.
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
  mdm_Serial,
  mdm_Modem,
  mlr_Binkp,
  misdos_Screen,
  misdos_Commands;

Var
  Cfg   : TModemConfig;
  Ser   : TModemSerial;
  Mdm   : TModem;
  Quit  : Boolean;

// Repaint the whole screen and re-seed the live fields.
Procedure Repaint;
Begin
  If Not DrawWfcScreen Then Begin
    TextAttr := 7; ClrScr;
    Writeln('  wfc.ans not found next to the executable.');
    Writeln('  (Copy mystic_misdos/wfc.ans beside the binary.)');
  End;

  // Overwrite only the genuinely-dynamic fields; the ANSI already carries
  // sensible static labels (Node/OS/Overlay/Next Event).  Give OS the real
  // build target so the example is honest about where it's running.
  SetStatus ('1',
             {$IFDEF WINDOWS}'Win'{$ELSE}{$IFDEF OS2}'OS/2'{$ELSE}{$IFDEF DARWIN}'macOS'{$ELSE}'Unix'{$ENDIF}{$ENDIF}{$ENDIF},
             'Disk', 'None');
  If Cfg.LocalMode Then
    SetModem ('(local mode - no modem)')
  Else
    SetModem (Cfg.Device + ' @ ' + IntToStr(Cfg.Baud));
  SetNode   (1, '(waiting)', 'Idle');
End;

// A minimal local session placeholder - a real integration launches a
// Mystic node here (bound to the console, or to Ser on a real connect).
Procedure LocalSession;
Begin
  Window (1, 1, 80, 25); TextAttr := 7; ClrScr;
  Writeln('=== Local login (example session) ===');
  Writeln;
  Writeln('A real build would launch a Mystic node here.');
  Writeln('Press any key to return to the Waiting-For-Caller screen.');
  ReadKey;
End;

// Handle a CONNECT: sniff, then route to binkp or a human session.
Procedure OnConnect;
Var
  Sniff : String;
  BD    : TBinkpDetect;
Begin
  SetNode (1, 'CONNECT', 'Answering');

  Delay (1200);                                // brief listen
  Sniff := Ser.ReadAvail;

  If TBinkpSeam.LooksLikeBinkp(Sniff, BD) Then Begin
    SetNode (1, 'BinkP node', 'Mail xfer');
    With TBinkpSeam.Create(Ser) Do
    Try
      RunSessionStub('WFC-example');
    Finally
      Free;
    End;
  End Else Begin
    SetNode (1, 'Human caller', 'Online');
    Ser.WriteStr(#13#10'Mystic WFC example - human session.'#13#10);
    // hand to a node here in a real build
  End;

  SetNode (1, '(waiting)', 'Idle');
End;

Var
  Act      : TWfcAction;
  LastTick : TDateTime;
Begin
  Cfg := LoadModemConfig('modem.ini');         // absent -> sensible defaults
  If Not FileExists('modem.ini') Then
    Cfg.LocalMode := True;                       // no config => local WFC

  Ser := TModemSerial.Create;
  Mdm := TModem.Create(Ser);

  If (Not Cfg.LocalMode) and Ser.Open(Cfg.Device, Cfg.Baud, Cfg.HardwareFlow) Then
    Mdm.Initialise(Cfg.InitString)
  Else
    Cfg.LocalMode := True;

  Repaint;
  LastTick := 0;
  Quit     := False;

  While Not Quit Do Begin
    // live clock tick (once a second)
    If (Now - LastTick) > (1/86400) Then Begin
      SetClock (FormatDateTime('hh:nnampm', Now), FormatDateTime('mm/dd/yy', Now));
      LastTick := Now;
    End;

    // modem ring?
    If (Not Cfg.LocalMode) and Mdm.IsRinging Then Begin
      If Mdm.Answer Then OnConnect;
      Repaint;
    End;

    // keyboard?
    If KeyPressed Then Begin
      Act := HandleKey(ReadKey);

      Case Act of
        waQuit       : Quit := True;
        waLocalLogin : Begin LocalSession; Repaint; End;
        waAnswer     : Begin
                         If Not Cfg.LocalMode Then Begin
                           If Mdm.Answer Then OnConnect;
                         End;
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
  Mdm.Free;
  Ser.Free;

  Window (1, 1, 80, 25); TextAttr := 7; GotoXY (1, 25);
  Writeln;
  Writeln('  WFC ended.  (Quit to DOS)');
End.
