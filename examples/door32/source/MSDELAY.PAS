Unit MSDELAY;

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
(*  FILE  : MSDELAY.PAS                                                    *)
(*  DESC  : Cross platform delay function with time slices                 *)
(*  BUILD : Revision 2: February 23, 2001                                  *)
(*                                                                         *)
(*  Tested with the following operating systems and compilers:             *)
(*                                                                         *)
(*  DOS     - Turbo Pascal v7.0                                            *)
(*  Windows - Virtual Pascal v2.1                                          *)
(*  OS/2    - Virtual Pascal v2.1                                          *)
(*  Linux   - Free Pascal v1.0                                             *)
(*                                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)

{$I OPS.PAS}

Interface

{$IFDEF WIN32}
  Uses Windows;
{$ENDIF}

{$IFDEF OS2}
  Uses Os2Base;
{$ENDIF}

{$IFDEF LINUX}
  {$IFDEF VIRTUALPASCAL}
    Uses Linux;
  {$ENDIF}
  {$IFDEF FPC}
    Uses CRT;
  {$ENDIF}
{$ENDIF}

Procedure ms_Delay (MS : Word);

Implementation

{$IFDEF MSDOS}
Procedure ms_Delay_Loop; Near; Assembler;
Asm
@1:SUB  AX,1
   SBB  DX,0
   JC   @2
   CMP  BL,ES:[DI]
   JE   @1
@2:
End;

Procedure ms_Delay (MS : Word); Assembler;
Type
  LongRec = Record
    Lo,
    Hi : Word
  End;
Const
  DelayCnt : Longint = 0;
  Op32               = $66;
Asm
   MOV  ES,Seg0040
   MOV  CX,ms
   MOV  SI,$6C
   MOV  AX,DelayCnt.LongRec.Lo
   OR   AX,DelayCnt.LongRec.Hi
   JNE  @2
   MOV  DI,SI
   MOV  BL,ES:[DI]
@1:CMP  BL,ES:[DI]
   JE   @1
   MOV  BL,ES:[DI]
   MOV  AX,-28
   CWD
   CALL ms_Delay_Loop
   NOT  AX
   NOT  DX
   MOV  BX,AX
   MOV  AX,DX
   XOR  DX,DX
   MOV  CX,55
   DIV  CX
   MOV  DelayCnt.LongRec.Hi,AX
   MOV  AX,BX
   DIV  CX
   MOV  DelayCnt.LongRec.Lo,AX
   MOV  CX,ms
   SUB  CX,83
   JBE  @x
@2:JCXZ @x
   XOR  DI,DI
   MOV  BL,ES:[DI]
   CMP  Test8086,2
   JNB  @4
@3:XOR  SI,SI
@4:MOV  BH,ES:[SI]
@5:MOV  AX,DelayCnt.LongRec.Lo
   MOV  DX,DelayCnt.LongRec.Hi
   CALL ms_Delay_Loop
   CMP  BH,ES:[SI]
   JNE  @7
@6:LOOP @5
   JMP  @x
@7:CMP  CX, 100            
   JB   @6              
   DB   op32;MOV DX,ES:[SI]
@8:MOV  AX,$1680
   INT  $2F
   OR   AL,AL
   JNZ  @3
   DB   op32;MOV AX,DX
   DB   op32;MOV DX,ES:[SI]
   DB   op32;SUB AX,DX
   JBE  @9
   DB   op32;MOV AX,DX
   JMP  @a
@9:DB   op32;NEG AX
@a:DB   op32;CMP AX,$4A7;DW 0 
   JA   @x
   PUSH DX
   PUSH CX
   MOV  CX,55
   MUL  CX
   POP  CX
   POP  DX
   SUB  CX,AX
   JBE  @x
   CMP  CX, 100
   JNB  @8
   JMP  @3
@x:
End;
{$ENDIF}

{$IFDEF WIN32}
Procedure ms_Delay (MS : Word);
Begin
  Sleep (MS);
End;
{$ENDIF}

{$IFDEF OS2}
Procedure ms_Delay (MS : Word);
Begin
  DosSleep(MS);
End;
{$ENDIF}

{$IFDEF LINUX}
  {$IFDEF VIRTUALPASCAL}
    Procedure ms_Delay (MS : Word);
    Var
      Req,
      Rem    : TTimeSpec;
      Result : LongInt;
    Begin
      Req.tv_Sec  := MS Div 1000;
      Req.tv_NSec := (MS mod 1000) * 1000000;

      Repeat
        Result := -LnxNanoSleep(Req, Rem);
        Req    := Rem;
      Until Result <> EAGAIN;
    End;
  {$ENDIF}
  {$IFDEF FPC}
    Procedure ms_Delay (MS : Word);
    Begin
      Delay(MS);
    End;
  {$ENDIF}
{$ENDIF}

End.
