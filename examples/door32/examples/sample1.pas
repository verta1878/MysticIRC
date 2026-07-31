Program Sample1;

(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*                                                                         *)
(*  FILE  : SAMPLE1.PAS                                                    *)
(*  DESC  : An example of the most minimal door, it can be compiled for    *)
(*          all supporting operating systems and compilers.  The door      *)
(*          greets the user and asks them to press [ENTER] to return to    *)
(*          the BBS.                                                       *)
(*  BUILD : Revision 1: February 23, 2001                                  *)
(*                                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)

Uses
  D32;

Procedure PlayGame;
Begin
  SendCLS;
  SendLn ('Welcome to this door game ' + User_Handle);
  SendLn ('Press [ENTER] to Quit');
  Repeat Until GetKey = #13;
End;

Var
  Res : Byte;
Begin
  If ParamCount <> 1 Then Begin
    WriteLn;
    WriteLn ('SAMPLE1 : A simple sample door program');
    WriteLn;
    WriteLn ('Syntax  : SAMPLE1 <Path and filename of drop file>');
    {$IFNDEF MSDOS}
      {$IFDEF LINUX}
        WriteLn ('Example : sample1 /bbs/door32.sys');
        WriteLn ('          sample1 /bbs/door.sys');
        WriteLn ('          sample1 /bbs/door/dorinfo1.def');
        WriteLn ('          sample1 /bbs/chain.txt');
      {$ELSE}
        WriteLn ('Example : SAMPLE1 C:\BBS\DOOR32.SYS');
      {$ENDIF}
    {$ELSE}
      WriteLn ('Example : SAMPLE1 C:\BBS\DORINFO1.DEF');
      WriteLn ('          SAMPLE1 C:\BBS\DOOR.SYS');
      WriteLn ('          SAMPLE1 C:\BBS\CHAIN.TXT');
    {$ENDIF}
    Halt;
  End;

  Res := OpenDOOR(ParamStr(1));

  Case Res of
    1 : WriteLn ('ERROR: Drop file not found.');
    2 : WriteLn ('ERROR: Error reading drop file');
    3 : WriteLn ('ERROR: Unknown drop file type');
    4 : WriteLn ('ERROR: Unable to open communications port');
  End;

  If Res <> 0 Then Halt;

  PlayGame;

  CloseDOOR;
End.
