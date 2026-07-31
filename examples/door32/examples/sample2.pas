Program Sample2;

(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*                                                                         *)
(*  FILE  : SAMPLE2.PAS                                                    *)
(*  DESC  : An example of a simple number guessing game.  The user has up  *)
(*          to 10 chances to guess a number from 1 to 1000.  Again, it     *)
(*          will compile for all supported operating systems and compilers *)
(*  BUILD : Revision 1: February 23, 2001                                  *)
(*                                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)

Uses
  D32;

Procedure PlayGame;
Var
  Winner : Boolean;
  Number : Word;
  Guess  : Word;
  A      : Word;
  Ch     : Char;
Begin
  Randomize;

  Repeat
    Winner := False;
    Number := Random(999) + 1;

    SendCLS;
    SendLn ('|14Guess a number between 1 and 1000 - you have 10 guesses!');

    For Guess := 1 to 10 Do Begin
      Send ('|CR|09Guess #' + Int2Str(Guess) + ': ');

      A := Str2Int(Input(0, 4, inNumber, ''));

      SendLn ('');

      If Number > A Then
        SendLn ('|10The number is greater than |15' + Int2Str(A))
      Else
      If Number < A Then
        SendLn ('|10The number is less than |15' + Int2Str(A))
      Else Begin
        Winner := True;
        Break;
      End;
    End;

    If Winner Then
      SendLn ('|12You won!  And it only took you ' + Int2Str(Guess) + ' guesses!')
    Else
      SendLn ('|09You lost.  The number was ' + Int2Str(Number));

    Send ('|11Play again? (Y/N): ');
    If OneKey('YN', True) = 'N' Then Break;
  Until False;
End;

Var
  Res : Byte;
  Str : String;
Begin
  If ParamCount <> 1 Then Begin
    WriteLn;
    WriteLn ('SAMPLE2 : A simple sample door program');
    WriteLn;
    WriteLn ('Syntax  : SAMPLE2 <Path and filename of drop file>');
    {$IFNDEF MSDOS}
      {$IFDEF LINUX}
        WriteLn ('Example : sample2 /bbs/door32.sys');
        WriteLn ('          sample2 /bbs/door.sys');
        WriteLn ('          sample2 /bbs/door/dorinfo1.def');
        WriteLn ('          sample2 /bbs/chain.txt');
      {$ELSE}
        WriteLn ('Example : SAMPLE2 C:\BBS\DOOR32.SYS');
      {$ENDIF}
    {$ELSE}
      WriteLn ('Example : SAMPLE2 C:\BBS\DORINFO1.DEF');
      WriteLn ('          SAMPLE2 C:\BBS\DOOR.SYS');
      WriteLn ('          SAMPLE2 C:\BBS\CHAIN.TXT');
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
