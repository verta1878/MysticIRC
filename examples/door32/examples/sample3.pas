Program Sample3;

(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*                                                                         *)
(*  FILE  : SAMPLE3.PAS                                                    *)
(*  DESC  : An example of how to use the extended input functions for      *)
(*          arrow key support.                                             *)
(*  BUILD : Revision 1: February 23, 2001                                  *)
(*                                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)

Uses
  D32;

Procedure PlayGame;
Var
  Ch : Char;
Begin
  SendCLS;
  SendLn ('|09D32 Input Demo.  Press ESCAPE when done|CR');

  Repeat
    Ch := GetKey;

    If IsArrowKey Then Begin
      Send ('|04You entered: |12');
      Case Ch of
        #71 : SendLn ('HOME');
        #72 : SendLn ('UP ARROW');
        #73 : SendLn ('PAGE UP');
        #75 : SendLn ('LEFT ARROW');
        #77 : SendLn ('RIGHT ARROW');
        #79 : SendLn ('END');
        #80 : SendLn ('DOWN ARROW');
        #81 : SendLn ('PAGE DOWN');
        #83 : SendLn ('DELETE');
      End;
    End Else
      If Ch = #27 Then
        Break
      Else
        SendLn ('|02You entered: |10' + Ch);
  Until False;

  SendLn ('|CR|07Thank you for using this demo');
End;

Var
  Res : Byte;
Begin
  If ParamCount <> 1 Then Begin
    WriteLn;
    WriteLn ('SAMPLE3 : A simple sample door program');
    WriteLn;
    WriteLn ('Syntax  : SAMPLE3 <Path and filename of drop file>');
    {$IFNDEF MSDOS}
      {$IFDEF LINUX}
        WriteLn ('Example : sample3 /bbs/door32.sys');
        WriteLn ('          sample3 /bbs/door.sys');
        WriteLn ('          sample3 /bbs/door/dorinfo1.def');
        WriteLn ('          sample3 /bbs/chain.txt');
      {$ELSE}
        WriteLn ('Example : SAMPLE3 C:\BBS\DOOR32.SYS');
      {$ENDIF}
    {$ELSE}
      WriteLn ('Example : SAMPLE3 C:\BBS\DORINFO1.DEF');
      WriteLn ('          SAMPLE3 C:\BBS\DOOR.SYS');
      WriteLn ('          SAMPLE3 C:\BBS\CHAIN.TXT');
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
