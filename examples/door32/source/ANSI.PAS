Unit Ansi;

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
(*  FILE  : ANSI.PAS                                                       *)
(*  DESC  : Ansi emulation functions for D32 library                       *)
(*  BUILD : Revision 2: February 23, 2001                                  *)
(*  NOTES : Originally released as public domain source code.  This has    *)
(*          been modified to compile for other compilers and some slight   *)
(*          changes have been made.                                        *)
(*                                                                         *)
(*  Tested with the following operating systems and compilers:             *)
(*                                                                         *)
(*  DOS     - Turbo Pascal v7.0                                            *)
(*  Windows - Virtual Pascal v2.1                                          *)
(*  OS/2    - Virtual Pascal v2.1                                          *)
(*  Linux   - Free Pascal v1.0                                             *)
(*                                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)

Interface

Uses
	Crt;

Procedure AnsiWrite (Ch : Char);

Implementation

Var
  Escape,
  Saved_X,
  Saved_Y      : Byte;
  Control_Code : String;

Function GetNumber (Var Line: String): Integer;
Var
  i : integer;
{$IFDEF MSDOS}
  j : integer;
{$ELSE}
  j : longint;
{$ENDIF}
  Str1 : String;
  Str2 : String;
Begin
  Str1 := Line;
  Val (Str1, i, j);
  If j = 0 Then
    Str1 := ''
  Else Begin
    Str2 := COPY (Str1, 1, j - 1);
    Delete (Str1, 1, j);
    VAL (Str2, i, j);
  End;
  Line := Str1;
  GetNumber := i;
End;

PROCEDURE loseit;
BEGIN
  escape       := 0;
  control_code := '';
END;

Procedure Ansi_Cursor_Move;
Var
  X : Byte;
  Y : Byte;
Begin
  Y := GetNumber (Control_Code);
  If Y = 0 Then Y := 1;
  X := GetNumber (Control_Code);
  If X = 0 Then X := 1;
  GotoXY (X, Y);
  LoseIt;
End;

Procedure Cursor_Up;
Var
  Y,
  NewY,
  offset : Integer;
Begin
  offset := getnumber (control_code);
  If offset = 0 Then offset := 1;
  Y := WhereY;
  If (Y - offset) < 1 Then
    NewY := 1
  Else
    NewY := Y - offset;
  GotoXY (WhereX, NewY);
  LoseIt;
End;

Procedure Ansi_Cursor_Down;  { does not check for > 25 }
Var
  NewY : Byte;
Begin
  NewY := GetNumber (Control_Code);
  If NewY = 0 Then NewY := 1;
  GotoXY (WhereX, WhereY + NewY);
  LoseIt;
End;

PROCEDURE Ansi_Cursor_Left;
VAR
  x, new_x, offset          : INTEGER;
BEGIN
  Offset := getnumber (control_code);
  IF Offset = 0 THEN offset := 1;
  x := WHEREX;
  IF (x - Offset) < 1 THEN
    New_x := 1
  ELSE
    New_x := x - offset;
  GotoXY (new_x, WHEREY);
  loseit;
END;

PROCEDURE Ansi_Cursor_Right;

 VAR
   x, new_x, offset          : INTEGER;

   BEGIN
     Offset := getnumber (control_code);
        IF Offset = 0 THEN offset := 1;
      x := WHEREX;
      IF (x + Offset) > 80 THEN
             New_x := 1
          ELSE
             New_x := x + offset;
       GotoXY (New_x, WHEREY);
  loseit;
  END;

Procedure Check_Code (Ch : Char);
Begin
  Case Ch of
    '0'..'9', ';' : control_code := control_code + ch;
    'H', 'f'      : Ansi_Cursor_Move;
    'A'           : Cursor_up;
    'B'           : Ansi_Cursor_Down;
    'C'           : Ansi_Cursor_Right;
    'D'           : Ansi_Cursor_Left;
    'J'           : Begin
                      CLRSCR;
                      LoseIt;
                    End;
    'K'           : Begin
                      ClrEOL;
                      LoseIt;
                    End;
    'm'           : Begin
                      While Length(Control_Code) > 0 Do Begin
                        Case GetNumber(Control_Code) of
                          0 : TextAttr := 7;
                          1 : HIGHVIDEO;
                          5 : TextAttr := (TextAttr OR $80);
                          7 : Begin
                                LowVideo;
                                TextAttr := ((TextAttr AND $70) SHR 4) + ((TextAttr AND $7) SHL 4) + TextAttr AND $80;
                              End;
                          30: textAttr := (TextAttr AND $F8) + black;
                          31: textattr := (TextAttr AND $f8) + red;
                          32: textattr := (TextAttr AND $f8) + green;
                          33: textattr := (TextAttr AND $f8) + brown;
                          34: textattr := (TextAttr AND $f8) + blue;
                          35: textattr := (TextAttr AND $f8) + magenta;
                          36: textattr := (TextAttr AND $f8) + cyan;
                          37: textattr := (TextAttr AND $f8) + Lightgray;
                          40: TEXTBACKGROUND (black);
                          41: TEXTBACKGROUND (red);
                          42: TEXTBACKGROUND (green);
                          43: TEXTBACKGROUND (yellow);
                          44: TEXTBACKGROUND (blue);
                          45: TEXTBACKGROUND (magenta);
                          46: TEXTBACKGROUND (cyan);
                          47: TEXTBACKGROUND (white);
                        End;
                      End;
                      LoseIt;
                    End;
    's'           : Begin
                      Saved_X := WHEREX;
                      Saved_Y := WHEREY;
                      loseit;
                    End;
    'u'           : Begin
                      GotoXY (Saved_X, Saved_Y);
                      loseit;
                    end;
  Else
    loseit;
  End;
END;

Procedure AnsiWrite (Ch : Char);
Begin
  Case Escape of
    0 : Begin
          Case Ch of
            #27 : Escape := 1;
            #9  : GotoXY (WhereX + 8, WhereY);
{           #9  : GotoXY ((WhereX SHR 3 + 1) SHL 3, WhereY);}
            #12 : ClrScr;
          Else
            Write (Ch);
            Escape := 0;
          End;
        End;
    1 : If Ch = '[' Then Begin
           Escape       := 2;
           Control_Code := '';
         End Else
           Escape := 0;
     2 : Check_Code(Ch);
   Else
     LoseIt;
   End;
End;

End.
