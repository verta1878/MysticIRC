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
(*  FILE  : OPS.PAS                                                        *)
(*  DESC  : Compiler options and definitions                               *)
(*  BUILD : Revision 2: February 18th, 2002                                *)
(*                                                                         *)
(*  Tested with the following operating systems and compilers:             *)
(*                                                                         *)
(*  DOS     - Turbo Pascal v7.0                                            *)
(*  Windows - Virtual Pascal v2.1                                          *)
(*  OS/2    - Virtual Pascal v2.1                                          *)
(*  Linux   - Free Pascal v1.0                                             *)
(*                                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)

{$IFDEF MSDOS}
  {$DEFINE OVERLAYS}
  {$DEFINE DOSORLINUX}
{$ENDIF}
{$IFDEF LINUX}
  {$DEFINE DOSORLINUX}
  {$DEFINE LINUXOROS2}
{$ENDIF}
{$IFDEF OS2}
  {$DEFINE LINUXOROS2}
{$ENDIF}

(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(* The below line can be uncommented to include debugging compiler options *)
(* {$DEFINE DEBUGGING}                                                     *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)

{$IFNDEF MSDOS}
  {$IFDEF VIRTUALPASCAL}
    {$T-}
    {$I-}
    {&StdCall+}
    {$B-}
    {&Use32-}
    {&Delphi-}
    {$V-}
    {$X+}
    {&Asm-}
    {$IFDEF DEBUGGING}
      {&LocInfo+}
      {&D+}
      {&Zd+}
      {$R+}
    {$ELSE}
      {&LocInfo-}
      {&D-}
      {&G4+}
      {&Speed+}
      {&Zd-}
    {$ENDIF}
  {$ENDIF}

  {$IFDEF FPC}
    {$I-}
    {$PACKRECORDS 1}
    {$IFNDEF DEBUGGING}
      {$SMARTLINK ON}
    {$ENDIF}
    {$D-}
    {$MODE TP}
  {$ENDIF}
{$ENDIF}

(**************************************************************************)

{$IFDEF MSDOS}
  {$A+}                   { Data Alignment........Word                  }
  {$I-}                   { I/O Checking..........Off                   }
  {$X+}                   { Enhanced Syntax.......On                    }
  {$V-}                   { String Type Checking..Relaxed               }
  {$P-}                   { Open Strings..........Off                   }
  {$T-}                   { @ Pointers............UnTyped               }
  {$G+}                   { 286 OpCodes...........On                    }
  {$B-}                   { Boolean Evaluation....Short Circuit         }

  {$IFDEF OVERLAYS}
    {$F+}                   { Far Calls.............On                    }
    {$O+}                   { Overlays Allowed......Yes                   }
  {$ELSE}
    {$F-}                   { Far Calls.............Off                   }
    {$O-}                   { Overlays Allowed......No                    }
  {$ENDIF}

  {$IFDEF DEBUGGING}
    {$D+}                   { Debugging Info........On                    }
    {$L+}                   { Line Numbers..........On                    }
    {$Y+}                   { Symbol Information....On                    }
    {$R+}                   { Range Checking........On                    }
    {$S+}                   { Stack Checking........On                    }
    {$Q-}                   { Overflow Checking.....On                    }
  {$ELSE}
    {$D-}                   { Debugging Info........Off                   }
    {$L-}                   { Line Numbers..........Off                   }
    {$Y-}                   { Symbol Information....Off                   }
    {$R-}                   { Range Checking........Off                   }
    {$S-}                   { Stack Checking........Off                   }
    {$Q-}                   { Overflow Checking.....On                    }
  {$ENDIF}

  { The stack size may need to be modified based on the size of your }
  { door program. }

  { Stack Size, Heap Min, Heap Max }
  {$M 60000,0,100000}

{$ENDIF}
