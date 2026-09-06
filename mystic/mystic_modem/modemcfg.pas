// ====================================================================
// mystic_modem : legacy dialup / serial support for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// modemcfg - a small interactive setup tool that lets a sysop configure the
// modem (modem.ini) without hand-editing the file.  It reads the current
// config, shows a numbered menu of settings, lets the sysop change any of
// them, and saves.  Shared by BOTH add-on modules (mystic_modem and
// mystic_mailer) since they use the same modem.ini / TModemConfig.
// ====================================================================

Program modemcfg;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Uses
  SysUtils,
  mdm_Config;

Var
  Cfg     : TModemConfig;
  IniPath : String;

Function YN (B: Boolean): String;
Begin If B Then YN := 'Yes' Else YN := 'No'; End;

Procedure Draw;
Begin
  WriteLn;
  WriteLn('  +------------------------------------------------------------+');
  WriteLn('  |        M Y S T I C   -   Modem Configuration                |');
  WriteLn('  +------------------------------------------------------------+');
  WriteLn('  |  1. Serial device      : ', Cfg.Device);
  WriteLn('  |  2. Locked baud rate    : ', Cfg.Baud);
  WriteLn('  |  3. Init string         : ', Cfg.InitString);
  WriteLn('  |  4. Rings to answer     : ', Cfg.RingsToAns);
  WriteLn('  |  5. Hardware flow (RTS/CTS): ', YN(Cfg.HardwareFlow));
  WriteLn('  |  6. WFC screen file     : ', Cfg.WfcScreen);
  WriteLn('  |  7. Local mode          : ', YN(Cfg.LocalMode));
  WriteLn('  |  8. Use FOSSIL layer    : ', YN(Cfg.UseFossil));
  WriteLn('  |  9. FOSSIL port number  : ', Cfg.FossilPort);
  WriteLn('  |  A. Answer string       : ', Cfg.AnswerStr);
  WriteLn('  |  O. Offhook string      : ', Cfg.OffhookStr);
  WriteLn('  +------------------------------------------------------------+');
  WriteLn('  |  S. Save    Q. Quit without saving                         |');
  WriteLn('  +------------------------------------------------------------+');
  Write  ('  Choice: ');
End;

Function AskStr (Const Prompt, Cur: String): String;
Var S : String;
Begin
  WriteLn('  ', Prompt);
  WriteLn('  (current: ', Cur, ' - blank keeps current)');
  Write  ('  > ');
  ReadLn(S);
  If S = '' Then AskStr := Cur Else AskStr := S;
End;

Function AskInt (Const Prompt: String; Cur: LongInt): LongInt;
Var S : String;
Begin
  WriteLn('  ', Prompt);
  WriteLn('  (current: ', Cur, ' - blank keeps current)');
  Write  ('  > ');
  ReadLn(S);
  If S = '' Then AskInt := Cur Else AskInt := StrToIntDef(S, Cur);
End;

Function AskBool (Const Prompt: String; Cur: Boolean): Boolean;
Var S : String;
Begin
  WriteLn('  ', Prompt, ' (Y/N, current: ', YN(Cur), ')');
  Write  ('  > ');
  ReadLn(S);
  If S = '' Then AskBool := Cur
  Else AskBool := UpCase(S[1]) = 'Y';
End;

Var
  Ch   : String;
  Done : Boolean;
Begin
  IniPath := 'modem.ini';
  If ParamCount >= 1 Then IniPath := ParamStr(1);

  WriteLn('Mystic modem configuration  (', IniPath, ')');
  Cfg := LoadModemConfig(IniPath);

  Done := False;
  Repeat
    Draw;
    ReadLn(Ch);
    If Ch = '' Then Continue;

    Case UpCase(Ch[1]) of
      '1' : Cfg.Device       := AskStr('Serial device (e.g. COM1 or /dev/ttyS0):', Cfg.Device);
      '2' : Cfg.Baud         := AskInt('Locked baud rate (e.g. 38400, 115200):', Cfg.Baud);
      '3' : Cfg.InitString   := AskStr('Modem init string (e.g. AT&D2&C1):', Cfg.InitString);
      '4' : Cfg.RingsToAns   := AskInt('Rings before answering:', Cfg.RingsToAns);
      '5' : Cfg.HardwareFlow := AskBool('Use hardware RTS/CTS flow control?', Cfg.HardwareFlow);
      '6' : Cfg.WfcScreen    := AskStr('WFC screen ANSI file (blank = none):', Cfg.WfcScreen);
      '7' : Cfg.LocalMode    := AskBool('Start in local mode (skip modem)?', Cfg.LocalMode);
      '8' : Cfg.UseFossil    := AskBool('Route through the FOSSIL layer?', Cfg.UseFossil);
      '9' : Cfg.FossilPort   := AskInt('FOSSIL port number (0 = COM1):', Cfg.FossilPort);
      'A' : Cfg.AnswerStr    := AskStr('Answer string (classic: ATA):', Cfg.AnswerStr);
      'O' : Cfg.OffhookStr   := AskStr('Offhook string (e.g. ATH1):', Cfg.OffhookStr);
      'S' : Begin
              SaveModemConfig(IniPath, Cfg);
              WriteLn('  Saved to ', IniPath, '.');
              Done := True;
            End;
      'Q' : Begin
              WriteLn('  Quit without saving.');
              Done := True;
            End;
    End;
  Until Done;
End.
