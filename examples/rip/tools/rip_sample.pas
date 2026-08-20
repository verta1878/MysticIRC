// ====================================================================
// mystic_rip : optional RIPscrip graphics example for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// rip_sample - the built-in sample RIPscrip screen shared by the
// rip_render and rip_view demos: a titled dialog with two mouse
// "buttons", in the style of a BBS RIP menu.  Kept hand-readable via
// the MN mega-number helper.
// ====================================================================

Unit rip_Sample;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

// 2-char base-36 "mega number" encoder (RIPscrip numeric fields)
Function MN (V: Integer): AnsiString;

// the sample screen as a CR/LF-framed RIP stream
Function SampleRip: AnsiString;

Implementation

Function MN (V: Integer): AnsiString;
Const
  D = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
Begin
  Result := D[(V Div 36) + 1] + D[(V Mod 36) + 1];
End;

Function SampleRip: AnsiString;

  Procedure A (Var R: AnsiString; Const L: AnsiString);
  Begin
    R := R + L + #13#10;   // RIP lines are CR-framed on the wire
  End;

Var
  S : AnsiString;
Begin
  S := '';

  A (S, '!|e');                                          // erase
  A (S, '!|c' + MN(9));                                  // light blue
  A (S, '!|R' + MN(40) + MN(30) + MN(600) + MN(320));    // outer frame
  A (S, '!|c' + MN(14));                                 // yellow
  A (S, '!|R' + MN(50) + MN(40) + MN(590) + MN(70));     // title bar box
  A (S, '!|@' + MN(230) + MN(48) + 'Ecstasy BBS  -  RIP');
  A (S, '!|c' + MN(11));                                 // light cyan
  A (S, '!|@' + MN(70) + MN(110) + 'Welcome to the board.');
  A (S, '!|@' + MN(70) + MN(130) + 'Click a button below:');
  // a filled button (bar) with a mouse hot-region
  A (S, '!|c' + MN(2));
  A (S, '!|B' + MN(70) + MN(170) + MN(220) + MN(200));   // green button
  A (S, '!|c' + MN(15));
  A (S, '!|@' + MN(100) + MN(180) + '[ Messages ]');
  // mouse region: num, x0, y0, x1, y1, clk, clr, res(5), text
  A (S, '!|M' + MN(1) + MN(70) + MN(170) + MN(220) + MN(200) + '10     M');
  A (S, '!|c' + MN(4));
  A (S, '!|B' + MN(260) + MN(170) + MN(410) + MN(200));  // red button
  A (S, '!|c' + MN(15));
  A (S, '!|@' + MN(295) + MN(180) + '[ Files ]');
  A (S, '!|M' + MN(2) + MN(260) + MN(170) + MN(410) + MN(200) + '10     F');
  // a circle flourish
  A (S, '!|c' + MN(13));
  A (S, '!|C' + MN(500) + MN(250) + MN(30));

  Result := S;
End;

End.
