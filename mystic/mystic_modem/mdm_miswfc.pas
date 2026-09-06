// ====================================================================
// mystic_modem : legacy dialup / serial support for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// mdm_miswfc - a MIS-style "Waiting For Caller" status screen for the modem
// subsystem, drawn in the spirit of MIS's DrawStatusScreen (mis_ansiwfc.pas):
// a titled panel with labelled fields and a bottom hot-key bar.  Kept plain
// text so it is fully portable and has no dependency on Mystic's Console/ANSI
// engine; a themed ANSI version could replace DrawModemWfc later.
//
// This renders the MODEM side: device / line state / baud / rings / carrier,
// plus a small call-counter panel mirroring MIS's Connections/Statistics idea.
// ====================================================================

Unit mdm_MisWfc;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  mdm_Config;

Type
  // Live counters shown on the screen, mirroring MIS's stats panel.
  TModemWfcStats = Record
    LineState : String;    // WAITING / RING / CONNECT nnnn / OFFLINE
    ConnBaud  : LongInt;   // negotiated speed of the current/last call
    Carrier   : Boolean;
    Calls     : LongInt;   // total answered
    LastCall  : String;    // free-text note about the last call
  End;

// Draw the full modem WFC status screen for the given config + live stats.
Procedure DrawModemWfc (Const Cfg: TModemConfig; Const St: TModemWfcStats);

// If Cfg.WfcScreen names an ANSI file (e.g. WFCSCRN.ANS), stream it to the
// console verbatim (the authentic blue 1.07-style screen).  Returns True if a
// screen file was found and shown; False to fall back to DrawModemWfc.
Function ShowWfcAnsi (Const Cfg: TModemConfig): Boolean;

Implementation

Uses
  SysUtils;

Const
  W = 62;    // inner width of the status box

Function Pad (Const S: String; Len: LongInt): String;
Begin
  Result := S;
  While Length(Result) < Len Do Result := Result + ' ';
  If Length(Result) > Len Then Result := Copy(Result, 1, Len);
End;

Function Row (Const Label_, Value: String): String;
Begin
  // "| Label      : value...                              |"
  Row := '  | ' + Pad(Label_, 10) + ': ' + Pad(Value, W - 15) + ' |';
End;

Function Bar : String;
Var I : LongInt; S : String;
Begin
  S := '  +';
  For I := 1 to W - 2 Do S := S + '-';
  Bar := S + '+';
End;

Function Centre (Const S: String): String;
Var Pad2 : LongInt;
Begin
  Pad2 := (W - 2 - Length(S)) Div 2;
  If Pad2 < 0 Then Pad2 := 0;
  Centre := '  |' + Pad(StringOfChar(' ', Pad2) + S, W - 2) + '|';
End;

Procedure DrawModemWfc (Const Cfg: TModemConfig; Const St: TModemWfcStats);
Begin
  // Layout echoes the authentic Mystic 1.07 DOS "Waiting for a caller" screen:
  // a status panel plus the sysop command bar and the caller-info fields the
  // original showed.  (Field/label names taken from the 1.07 binary.)
  WriteLn;
  WriteLn(Bar);
  WriteLn(Centre('M Y S T I C   B B S   -   Waiting for a caller'));
  WriteLn(Bar);
  WriteLn(Row('Device',   Cfg.Device));
  WriteLn(Row('Baud',     IntToStr(Cfg.Baud)));
  WriteLn(Row('Init',     Cfg.InitString));
  WriteLn(Row('Rings',    IntToStr(Cfg.RingsToAns)));
  WriteLn(Row('FOSSIL',   BoolToStr(Cfg.UseFossil, 'yes', 'no')));
  WriteLn(Bar);
  WriteLn(Row('Status',   St.LineState));
  WriteLn(Row('Connect',  IntToStr(St.ConnBaud) + ' bps'));
  WriteLn(Row('Carrier',  BoolToStr(St.Carrier, 'detected', 'none')));
  WriteLn(Row('Calls',    IntToStr(St.Calls)));
  WriteLn(Row('Last',     St.LastCall));
  WriteLn(Bar);
  // The 1.07 sysop status/command bar (ALT keys).
  WriteLn('  ALT (C)hat  (S)plit  (E)dit  (H)angup  (J) DOS  (U)pgrade  (B) Bar');
  WriteLn('  (G) Offhook Modem   (L) Local Logon   (ESC) Exit Mystic');
  WriteLn;
End;

Function ShowWfcAnsi (Const Cfg: TModemConfig): Boolean;
Var
  F  : File;
  Buf: Array[0..1023] of Char;
  N  : LongInt;
  I  : LongInt;
Begin
  Result := False;
  If Cfg.WfcScreen = '' Then Exit;

  Assign(F, Cfg.WfcScreen);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  Repeat
    BlockRead(F, Buf, SizeOf(Buf), N);
    For I := 0 to N - 1 Do Write(Buf[I]);
  Until N = 0;

  Close(F);
  Result := True;
End;

End.
