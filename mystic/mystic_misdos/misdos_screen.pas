// ====================================================================
// mystic_misdos : a DOS-style MIS "Waiting For Caller" example
// ====================================================================
//
// This file is part of an optional add-on EXAMPLE for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// misdos_screen - loads and paints the WFC ANSI screen (wfc.ans, the
// reconstruction of the classic Mystic 1.06 Waiting-For-Caller display)
// and fills its live fields: the clock/date, the node listing, and the
// modem-info line.  The ANSI carries literal @TIME@ / @DATE@ tokens that
// this unit overwrites in place, the way Mystic's template engine does
// with MCI codes.
//
// Deliberately FPC-RTL only (Crt for cursor + colour) so the example is
// portable across the same targets as the rest of the tree.
// ====================================================================

Unit misdos_Screen;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  SysUtils;

// Paint the full WFC screen from wfc.ans (searched next to the exe, then
// the current dir).  Returns False if the art file can't be found.
Function  DrawWfcScreen (Const AnsiPath: String = '') : Boolean;

// Update the live fields on an already-painted screen.
Procedure SetClock  (Const TimeStr, DateStr: String);
Procedure SetNode   (Num: Integer; Const Who, Action: String);
Procedure SetModem  (Const Info: String);
Procedure SetStatus (Const NodeNo, OS, Overlay, NextEvent: String);

// Low-level: position the cursor (1-based) and write text at current attr.
Procedure GotoXYAbs (X, Y: Integer);
Procedure WriteAt   (X, Y: Integer; Const S: String);

Implementation

Uses
  Crt;

Const
  ESC = #27;

Function FindAnsi (Const Given: String) : String;
Var
  ExeDir : String;
Begin
  Result := '';

  If (Given <> '') and FileExists(Given) Then Begin Result := Given; Exit; End;

  ExeDir := ExtractFilePath(ParamStr(0));

  If FileExists(ExeDir + 'wfc.ans') Then Begin Result := ExeDir + 'wfc.ans'; Exit; End;
  If FileExists('wfc.ans')          Then Begin Result := 'wfc.ans';          Exit; End;
End;

Function DrawWfcScreen (Const AnsiPath: String) : Boolean;
Var
  FN   : String;
  F    : File;
  Buf  : Array[0..8191] of Char;
  Got  : LongInt;
Begin
  Result := False;

  FN := FindAnsi(AnsiPath);
  If FN = '' Then Exit;

  // Raw dump of the ANSI to the console; the escape codes position and
  // colour everything themselves.
  Assign (F, FN);
  {$I-} Reset (F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  Repeat
    BlockRead (F, Buf, SizeOf(Buf), Got);
    If Got > 0 Then
      System.Write(StdOut, Copy(String(Buf), 1, Got));  // pass bytes through
  Until Got = 0;

  Close (F);

  Result := True;
End;

Procedure GotoXYAbs (X, Y: Integer);
Begin
  System.Write(ESC + '[' + IntToStr(Y) + ';' + IntToStr(X) + 'H');
End;

Procedure WriteAt (X, Y: Integer; Const S: String);
Begin
  GotoXYAbs (X, Y);
  System.Write(S);
End;

// --- live-field helpers (coordinates match gen_wfc.py / wfc.ans) ----------

Procedure SetClock (Const TimeStr, DateStr: String);
Begin
  System.Write(ESC + '[1;33;44m');            // yellow on blue
  WriteAt (6,  24, TimeStr + '      ');
  WriteAt (70, 24, DateStr);
End;

Procedure SetNode (Num: Integer; Const Who, Action: String);
Var
  Row : Integer;
Begin
  If (Num < 1) or (Num > 8) Then Exit;

  Row := 3 + Num;                             // node 1 -> row 4

  System.Write(ESC + '[0;36;44m');            // cyan on blue
  // clear the node line's data area, then write
  WriteAt (10, Row, StringOfChar(' ', 27));
  WriteAt (10, Row, Copy(Who, 1, 20));
  WriteAt (30, Row, Copy(Action, 1, 8));
End;

Procedure SetModem (Const Info: String);
Begin
  System.Write(ESC + '[1;37;44m');            // bright white on blue
  WriteAt (46, 4, StringOfChar(' ', 30));
  WriteAt (46, 4, Copy(Info, 1, 30));
End;

Procedure SetStatus (Const NodeNo, OS, Overlay, NextEvent: String);
Begin
  System.Write(ESC + '[1;37;44m');
  WriteAt (70, 15, NodeNo    + '   ');
  WriteAt (70, 16, OS        + '   ');
  WriteAt (70, 17, Overlay   + '   ');
  WriteAt (70, 18, NextEvent + '   ');
End;

End.
