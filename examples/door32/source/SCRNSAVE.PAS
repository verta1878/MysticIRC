Unit ScrnSave;

(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*                                                                         *)
(*  D32 Library Source Code                     Programmed By James Coyle  *)
(*  ---------------------------------------------------------------------  *)
(*                                                                         *)
(*  This source code is provided as-is.  The author will not be held       *)
(*  responsible for any damage done by the use or misuse of this library.  *)
(*  If you do not agree to these terms, you must remove this library       *)
(*  and any of its files from storage immediately.                         *)
(*                                                                         *)
(*  ---------------------------------------------------------------------  *)
(*                                                                         *)
(*  FILE  : SCRNSAVE.PAS                                                   *)
(*  DESC  : Screen writing and save/restore functions                      *)
(*  BUILD : Revision 3: February 18th, 2002                                *)
(*  NOTES : Rewrote from scratch for Revision 3.  These functions assume   *)
(*          a terminal size no larger than 80 columns by 25 lines.         *)
(*                                                                         *)
(*  Tested with the following operating systems and compilers:             *)
(*                                                                         *)
(*  DOS     - Turbo Pascal v7.0                                            *)
(*  Windows - Virtual Pascal v2.1                                          *)
(*  OS/2    - Virtual Pascal v2.1                                          *)
(*                                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)

{$I OPS.PAS}

Interface

Uses
  {$IFDEF WIN32}
    Windows,
  {$ENDIF}
  {$IFDEF OS2}
    VpSysLow,
  {$ENDIF}
  CRT;

Type
  TextCellRec = Record
    Char : {$IFDEF WIN32} Word {$ELSE} Byte {$ENDIF};
    Attr : {$IFDEF WIN32} Word {$ELSE} Byte {$ENDIF};
  End;

Type
  ScrnSavePTR = ^ScrnSaveOBJ;
  ScrnSaveOBJ = Object
   {$IFDEF WIN32}
    ConOut   : THandle;
    ConIn    : THandle;
   {$ENDIF}
    CursorX  : Byte;
    CursorY  : Byte;
    CursorA  : Byte;
    WinTop   : Byte;
    WinBot   : Byte;
    WinLeft  : Byte;
    WinRight : Byte;
    Buffer   : Array[1..25] of Array[1..80] of TextCellRec;

    Constructor Init;
    Destructor  Done;
    Procedure   Save;
    Procedure   Restore;
  End;

Implementation

Constructor ScrnSaveOBJ.Init;
Begin
  {$IFDEF WIN32}
    ConIn  := GetStdHandle(STD_INPUT_HANDLE);
    ConOut := GetStdHandle(STD_OUTPUT_HANDLE);
  {$ENDIF}
End;

Destructor ScrnSaveOBJ.Done;
Begin
End;

Procedure ScrnSaveOBJ.Save;
{$IFDEF WIN32}
Var
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;
{$ENDIF}
{$IFDEF OS2}
Var
  X : Byte;
  Y : Byte;
{$ENDIF}
Begin
  CursorX  := WhereX;
  CursorY  := WhereY;
  CursorA  := TextAttr;

 {$IFDEF WIN32}
  BufSize.X     := 80;
  BufSize.Y     := 25;
  BufCoord.X    := 0;
  BufCoord.Y    := 0;
  Region.Left   := 0;
  Region.Top    := 0;
  Region.Right  := 79;
  Region.Bottom := 24;

  ReadConsoleOutput (ConOut, @Buffer[1][1], BufSize, BufCoord, Region);
 {$ENDIF}

 {$IFDEF MSDOS}
    Move (Mem[$B800:$0000], Buffer[1][1], 4000);
 {$ENDIF}

 {$IFDEF OS2}
  For Y := 0 to 24 Do
    For X := 0 to 79 Do Begin
      Buffer[Y+1][X+1].Char := Byte(SysReadCharAt(X, Y));
      Buffer[Y+1][X+1].Attr := SysReadAttributesAt(X, Y);
    End;
 {$ENDIF}
End;

Procedure ScrnSaveOBJ.Restore;
{$IFDEF WIN32}
Var
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;
{$ENDIF}
{$IFDEF OS2}
Var
  X : Byte;
  Y : Byte;
{$ENDIF}
Begin
 {$IFDEF WIN32}
  BufSize.X     := 80;
  BufSize.Y     := 25;
  BufCoord.X    := 0;
  BufCoord.Y    := 0;
  Region.Left   := 0;
  Region.Top    := 0;
  Region.Right  := 79;
  Region.Bottom := 24;

  WriteConsoleOutput (ConOut, @Buffer[1][1], BufSize, BufCoord, Region);
 {$ENDIF}

 {$IFDEF MSDOS}
    Move (Buffer[1][1], Mem[$B800:$0000], 4000);
 {$ENDIF}

 {$IFDEF OS2}
  For Y := 0 to 24 Do
    For X := 0 to 79 Do
      SysWrtCharStrAtt (@Buffer[Y+1][X+1].Char, 1, X, Y, Buffer[Y+1][X+1].Attr);
 {$ENDIF}

  GotoXY(CursorX, CursorY);
  TextAttr := CursorA;
End;

End.
