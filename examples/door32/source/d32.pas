Unit D32;

(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)
(*                                                                         *)
(*  D32 Library Source Code                     Programmed By James Coyle  *)
(*                                                 Modified by Kim Jansen  *)
(*  ---------------------------------------------------------------------  *)
(*                                                                         *)
(*  This source code is provided as-is.  The author will not be held       *)
(*  responsible for any damage done by the use or misuse of this library.  *)
(*  If you do not agree to these terms, you must remove this library       *)
(*  and any of its files from storage immediately.                         *)
(*                                                                         *)
(*  ---------------------------------------------------------------------  *)
(*                                                                         *)
(*  FILE  : D32.PAS                                                        *)
(*  DESC  : Main D32 library functions                                     *)
(*  BUILD : Revision 5: June 28th, 2025                                    *)
(*                                                                         *)
(*  Note: This has been modenized to compile with Free Pascal 3.2.2        *)
(*  This may no longer work as it previously did with other compilers      *)
(*                                                                         *)
(*  DOS     - Untested                                                     *)
(*  Windows - Untested                                                     *)
(*  OS/2    - Untested                                                     *)
(*  Linux   - Tested - Free Pascal v3.2.2                                  *)
(*                                                                         *)
(* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *)

{$I OPS.PAS}

Interface

Uses
  ComBase,
{$IFDEF MSDOS}
  Fos_Com,
{$ENDIF}
{$IFDEF OS2}
  Os2Base,
  OS2Com,
  Telnet,
{$ENDIF}
{$IFDEF WIN32}
  Windows,
  W32Sngl,
  Telnet,
{$ENDIF}
{$IFDEF LINUX}
  Linux,
  Unix,
  BaseUnix,
{$ENDIF}
  crt,
  DOS,
  SysUtils,
  {$IFNDEF LINUX}
    Ansi,
    ScrnSave,
  {$ENDIF}
  msDelay;

{ ========================================================================= }
{ GLOBAL LIBRARY VARIABLES.  AVAILABLE TO DOOR PROGRAM                      }
{ ========================================================================= }

Type
{$IFDEF DOSORLINUX}
  LongWord = Word;
{$ELSE}
  LongWord = LongInt;
{$ENDIF}

Const
  DOOR32_VERSION = '0.4';
  SIGTERM = 15;
  SIGHUP  = 1;

Const
  Comm_BBSID    : String     = '';            { BBS ID for DOOR32.SYS }
  Comm_Type     : Byte       = 0;             { 0 local 1 dialup 2 telnet}
  Comm_Handle   : LongInt    = 0;             { Comm handle or port }
  Comm_Baud     : LongInt    = 0;             { Comm baud rate      }
  Comm_Local    : Boolean    = False;         { Comm local mode?    }
  User_Record   : LongInt    = 0;             { User's record #     }
  User_Name     : String[30] = '';            { User's real name    }
  User_Handle   : String[30] = '';            { User's alias/handle }
  User_Security : LongInt    = 0;             { User's security lvl }
  User_Time     : Integer    = 0;             { User's time left    }
  User_Term     : Byte       = 0;             { 0 = ASCII  1 = ANSI }
  User_Screen   : Byte       = 24;            { User's screen size  }
  AllowArrow    : Boolean    = True;
  IsLocalKey    : Boolean    = False;
  IsArrowKey    : Boolean    = False;
  IsNoFile      : Boolean    = False;
  PauseLinePos  : Byte       = 1;

Const
  inNormal   = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV' +
               'WXYZ1234567890~!@#$%^&*()-+\[]{};:`''".,/<> =_?|';
  inAny      = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV' +
               'WXYZ1234567890~!@#$%^&*()-+\[]{};:`''".,/<> =_?|' +
               'ÄÅÇÉÑÖÜáàâäãåçéèêëíìîïñóòôöõúùûü†°¢£§•¶ß®©™´¨≠Æ' +
               'Ø∞±≤≥¥µ∂∫∏π∫ªºΩæø¿¡¬√ƒ≈∆«»… ÀÃÕŒœ–—“”‘’÷◊ÿŸ⁄€‹›ﬁ' +
               'ﬂ‡·‚„‰ÂÊÁËÈÍÎÏÌÓÔÒÚÛÙıˆ˜¯˘˙˚¸˝˛';
  inNumber   = '1234567890-';
  inFileName = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV' +
               'WXYZ1234567890~!@#$%^&()-_{}.';
  inFileSpec = inFileName + '?*';
  {$IFDEF LINUX}
  inFilePath = InFileSpec + '/';
  {$ELSE}
  inFilePath = InFileSpec + ':\';
  {$ENDIF}

Const
  dOnNoCarrier    : Procedure = NIL;
  dOnTimeOut      : Procedure = NIL;
  dOnStatusUpdate : Procedure (Help : Boolean) = NIL;
  dOnChatMode     : Procedure = NIL;
  dOnLowTime      : Procedure = NIL;
  dOnNoTime       : Procedure = NIL;
  dOnKickUser     : Procedure = NIL;
  dOnFilePause    : Function : Byte = NIL;
  dOnOsShell      : Procedure = NIL;

{$IFNDEF LINUX}
Var
  Comm : PCommOBJ;
{$ENDIF}

{ ========================================================================= }
{ FUNCTIONS AND PROCEDURES AVAILABLE IN LIBRARY                             }
{ ========================================================================= }

{ initialization / deinitialization functions }

Function  OpenDoor (Path : String) : Byte;
Procedure CloseDoor;

{ screen output funtions }

Procedure Out      (Str : String);
Procedure OutLn    (Str : String);
Procedure Send     (Str : String);
Procedure SendLn   (Str : String);
Procedure SendCLS;
Procedure SendBS   (Num : Byte);
Procedure SendFile (FN : String; Pause : Boolean);

{ ansi-required screen functions }

Procedure Ansi_Color   (FG, BG : Byte);
Procedure Ansi_GotoXY  (X, Y : Byte);
Procedure Ansi_ClrEOL;

{ input functions }

Function KeyWaiting  : Boolean;
Function GetKey      : Char;
Function OneKey      (S : String; Echo : Boolean) : Char;
Function Input       (Mode : Byte; MaxLen : Byte; Valid : String; Default : String) : String;

{ miscellaneous door functions }

Procedure SetTimeLeft  (Time : Integer);
Function  GetTimeLeft  : Integer;
Function  TimerMin     : Integer;
Function  TimerSec     : LongInt;

{ miscellaneous non-door functions }

Function  Int2Str (N : LongInt) : String;
Function  Str2Int (Str : String) : LongInt;
Function  FExist  (Str : String) : Boolean;
Function  Upper   (Str : String) : String;
Procedure WriteXY (X, Y: Word; Str: String; Attr: Byte);

Implementation

{ private variables and definitions }

Const
  StatusHelp   : Boolean = False;
  StatusUpdate : LongInt = 0;
  InChatMode   : Boolean = False;
  TimeWarning  : Boolean = False;

Var
  TimeOut     : LongInt;
  TimerStart  : Integer;
  TimerEnd    : Integer;
  TaskType    : Byte;
  {$IFNDEF LINUX}
    ScrnWrite : ^ScrnSaveOBJ;
  {$ENDIF}

{ ========================================================================= }
{ PRIVATE FUNCTIONS AND PROCEDURES                                          }
{ ========================================================================= }

Function fExist (Str : String) : Boolean;
Begin
  fExist := FSearch(Str, '') <> '';
End;

Function Upper (Str: String) : String;
Var
  A : Byte;
Begin
  For A := 1 to Length(Str) Do Str[A] := UpCase(Str[A]);
  Upper := Str;
End;

Function Str2Int (Str: String): LongInt;
Var
  N : LongWord;
  T : LongInt;
Begin
  Val(Str, T, N);
  Str2Int := T;
End;

Function Int2Str (N: LongInt): String;
Var
  T : String;
Begin
  Str(N, T);
  Int2Str := T;
End;

Function LoCase (C: Char): Char;
Begin
  If (C in ['A'..'Z']) Then
    LoCase := Chr(Ord(C) + 32)
  Else
    LoCase := C;
End;

{$IFDEF MSDOS}
Procedure WriteXY (X, Y: Word; Str: String; Attr: Byte); Assembler;
Asm
  dec   x
  dec   y
  mov   ax, y
  mov   cl, 5
  shl   ax, cl
  mov   di, ax
  mov   cl, 2
  shl   ax, cl
  add   di, ax
  shl   x,  1
  add   di, x
  mov   ax, 0b800h     { 0b000h for mono. we assume color monitor }
  mov   es, ax
  xor   ch, ch
  push  ds
  lds   si, Str
  lodsb
  mov   cl, al
  mov   ah, attr
  jcxz  @@End
@@L1:
  lodsb
  stosw
  loop  @@L1
@@End:
  pop   ds
End;
{$ENDIF}
{$IFDEF LINUXOROS2}
Procedure WriteXY (X, Y: Word; Str: String; Attr: Byte);
Var
  SA : Byte;
  SX : Byte;
  SY : Byte;
Begin
  SA := TextAttr;
  SX := WhereX;
  SY := WhereY;

  TextAttr := Attr;
  GotoXY (X, Y);
  Write (Str);
  TextAttr := SA;
  GotoXY (SX, SY);
End;
{$ENDIF}
{$IFDEF WIN32}
Procedure WriteXY (X, Y: Word; Str: String; Attr: Byte);
Var
  Count    : Byte;
  Buf      : Array[1..80] of TextCellRec;
  BufSize  : TCoord;
  BufCoord : TCoord;
  Region   : TSmallRect;
Begin
  For Count := 1 to Length(Str) Do Begin
    Buf[Count].Attr := Attr;
    Buf[Count].Char := Byte(Str[Count]);
  End;

  BufSize.X     := Count - 1;
  BufSize.Y     := 1;
  BufCoord.X    := 0;
  BufCoord.Y    := 0;
  Region.Left   := X - 1;
  Region.Top    := Y - 1;
  Region.Right  := X + Count - 1;
  Region.Bottom := Y - 1;

  WriteConsoleOutput(GetStdHandle(STD_OUTPUT_HANDLE), @Buf, BufSize, BufCoord, Region);
End;
{$ENDIF}

{$IFDEF MSDOS}
Procedure GetTaskType; Assembler;
Asm
  MOV TaskType, 0
  MOV Ah, 30h
  INT 21h
  CMP Al, 14h
  JAE @OS2
  MOV Ax, 2B01h
  MOV Cx, 4445h
  MOV Dx, 5351h
  INT 21h
  CMP Al, 255
  JNE @DV
  MOV Ax, 160Ah
  INT 2Fh
  CMP Ax, 0h
  JE @WIN
  JMP @Done
@OS2:
  MOV TaskType, 1
  JMP @Done
@WIN:
  MOV TaskType, 2
  JMP @Done
@DV:
  MOV TaskType, 3
  JMP @Done
@DONE:
End;
{$ENDIF}

Procedure IdleTick;
Begin
{$IFDEF MSDOS}
  Asm
    CMP TaskType, 0
    JE @DOS
    CMP TaskType, 1
    JE @WINOS2
    CMP TaskType, 2
    JE @WINOS2
    CMP TaskType, 3
    JE @DV
    JMP @DONE
  @DOS:
    INT 28h
    JMP @DONE
  @DV:
    MOV Ax, 1000h
    INT 15h
    JMP @DONE
  @WINOS2:
    MOV AX, 1680h
    INT 2Fh
  @DONE:
  End;
{$ELSE}
  {$IFDEF OS2}
    DosSleep(1);
  {$ENDIF}

  {$IFDEF WIN32}
    Sleep(1);
  {$ENDIF}

  {$IFDEF LINUX}
    Delay(1);
  {$ENDIF}
{$ENDIF}
End;

{ ========================================================================= }
{ DOOR STARUP AND SHUTDOWN PROCEDURES                                       }
{ ========================================================================= }

{$IFNDEF MSDOS}
Function ReadDOOR32 (Path : String) : Byte;
Var
  tFile : Text;
  Temp  : String;
Begin
  ReadDOOR32 := 0;

  Assign (tFile, Path);
  {$I-} Reset(tFile); {$I+}
  If IoResult <> 0 Then Begin
    ReadDOOR32 := 1;
    Exit;
  End;

  {$I-}
  ReadLn (tFile, Temp);        Comm_Type   := Str2Int(Temp);  { 0 local 1 serial 2 telnet }
  ReadLn (tFile, Temp);        Comm_Handle := Str2Int(Temp);
  ReadLn (tFile, Temp);        Comm_Baud   := Str2Int(Temp);
  ReadLn (tFile, Comm_BBSID);
  ReadLn (tFile, Temp);        User_Record := Str2Int(Temp);
  ReadLn (tFile, User_Name);
  ReadLn (tFile, User_Handle);
  ReadLn (tFile, Temp);        User_Security := Str2Int(Temp);
  ReadLn (tFile, Temp);        User_Time     := Str2Int(Temp);
  ReadLn (tFile, Temp);        User_Term     := Str2Int(Temp);
  ReadLn (tFile, Temp);
  Close  (tFile);
  {$I+}

  Comm_Local := (Comm_Type = 0);

  If IoResult <> 0 Then ReadDOOR32 := 2;
End;
{$ENDIF}

{$IFDEF DOSORLINUX}
Function ReadDOORSYS (Path : String) : Byte;
Var
  TF   : Text;
  Temp : String;
  A    : Byte;
Begin
  ReadDOORSYS := 0;

  Assign (TF, Path);
  {$I-} Reset(TF); {$I+}
  If IoResult <> 0 Then Begin
    ReadDOORSYS := 1;
    Exit;
  End;

  {$I-}
  ReadLn (TF, Temp);
  Comm_Handle := Str2Int(Copy(Temp, 4, Pos(':', Temp) - 4));
  ReadLn (TF, Temp);
  Comm_Baud := Str2Int(Temp);
  For A := 1 to 7 Do ReadLn(TF, Temp);
  ReadLn (TF, User_Name);
  For A := 1 to 4 Do ReadLn (TF, Temp);
  ReadLn (TF, Temp);
  User_Security := Str2Int(Temp);
  For A := 1 to 3 Do ReadLn (TF, Temp);
  ReadLn (TF, Temp);
  User_Time := Str2Int(Temp);
  ReadLn (TF, Temp);
  If Temp = 'GR' Then User_Term := 1 Else User_Term := 0;
  ReadLn (TF, Temp);
  User_Screen := Str2Int(Temp);
  For A := 1 to 14 Do ReadLn (TF, Temp);
  ReadLn (TF, User_Handle);
  Close (TF);
  {$I+}

  Comm_Local := (Comm_Handle = 0);

  If IoResult <> 0 Then ReadDOORSYS := 2;
End;

Function ReadCHAINTXT (Path : String) : Byte;
Var
  TF   : Text;
  Temp : String;
  A    : Byte;
Begin
  ReadCHAINTXT := 0;

  Assign (TF, Path);
  {$I-} Reset(TF); {$I+}
  If IoResult <> 0 Then Begin
    ReadCHAINTXT := 1;
    Exit;
  End;

  {$I-}
  ReadLn (TF, Temp);
  ReadLn (TF, User_Handle);
  ReadLn (TF, User_Name);
  For A := 1 to 6 Do ReadLn (TF, Temp);
  ReadLn (TF, Temp);
  User_Screen := Str2Int(Temp);
  ReadLn (TF, Temp);
  User_Security := Str2Int(Temp);
  For A := 1 to 2 Do ReadLn (TF, Temp);
  ReadLn (TF, Temp);
  User_Term := Str2Int(Temp);
  ReadLn (TF, Temp);
  Comm_Local := Not Boolean(Str2Int(Temp));
  ReadLn (TF, Temp);
  User_Time := Str2Int(Temp) DIV 60;
  For A := 1 to 3 Do ReadLn (TF, Temp);
  ReadLn (TF, Temp);
  Comm_Baud := Str2Int(Temp);
  ReadLn (TF, Temp);
  Comm_Handle := Str2Int(Temp);
  Close (TF);
  {$I+}

  If IoResult <> 0 Then ReadCHAINTXT := 2;
End;

Function ReadDORINFO (Path : String) : Byte;
Var
  tFile : Text;
  Temp  : String;
Begin
  ReadDORINFO := 0;

  Assign (tFile, Path);
  {$I-} Reset(tFile); {$I+}
  If IoResult <> 0 Then Begin
    ReadDORINFO := 1;
    Exit;
  End;

  {$I-}
  ReadLn (tFile, Temp);
  ReadLn (tFile, Temp);
  ReadLn (tFile, Temp);
  ReadLn (tFile, Temp); Comm_Handle := Str2Int(Copy(Temp, 4, 1));
  ReadLn (tFile, Temp); Comm_Baud   := Str2Int(Temp);
  ReadLn (tFile, Temp);
  ReadLn (tFile, User_Name);
  ReadLn (tFile, Temp); User_Name := User_Name + ' ' + Temp;
  ReadLn (tFile, Temp);
  ReadLn (tFile, Temp); User_Term := Str2Int(Temp);
  ReadLn (tFile, Temp); User_Security := Str2Int(Temp);
  ReadLn (tFile, Temp); User_Time := Str2Int(Temp);
  Close  (tFile);
  {$I+}

  User_Handle := User_Name;
  Comm_Local  := (Comm_Handle = 0);

  If IoResult <> 0 Then ReadDORINFO := 2;
End;
{$ENDIF}

{$F+}
Procedure Int_ComReadProc (Var TempPtr: Pointer);
Begin
  {$IFDEF WIN32}
    Case Comm_Type of
      1 : PWin32Obj(Comm)^.Com_DataProc(TempPtr);
      2 : PTelnetObj(Comm)^.Com_ReadProc(TempPtr);
    End;
  {$ENDIF}

  {$IFDEF OS2}
    Case Comm_Type of
      1 : POs2Obj(Comm)^.Com_ReadProc(TempPtr);
      2 : PTelnetObj(Comm)^.Com_ReadProc(TempPtr);
    End;
  {$ENDIF}
End;

Procedure Int_ComWriteProc (Var TempPtr: Pointer);
Begin
  {$IFDEF WIN32}
    Case Comm_Type of
      1 : PWin32Obj(Comm)^.Com_DataProc(TempPtr);
      2 : PTelnetObj(Comm)^.Com_WriteProc(TempPtr);
    End;
  {$ENDIF}

  {$IFDEF OS2}
    Case Comm_Type of
      1 : POs2Obj(Comm)^.Com_WriteProc(TempPtr);
      2 : PTelnetObj(Comm)^.Com_WriteProc(TempPtr);
    End;
  {$ENDIF}
End;
{$F-}

Function OpenDOOR (Path : String) : Byte;
{ 0 = OK                               1 = Drop file not found    }
{ 2 = Error reading drop file          3 = Invalid drop file type }
{ 4 = Unable to open com driver                                   }
Var
  Error : Byte;
Begin
  {$IFNDEF LINUX}
    Path := Upper(Path);
  {$ENDIF}

  Error := 0;

  {$IFDEF MSDOS}
    If Pos('DOOR.SYS',   Path) > 0 Then Error := ReadDOORSYS(Path)  Else
    If Pos('CHAIN.TXT',  Path) > 0 Then Error := ReadCHAINTXT(Path) Else
    If Pos('DORINFO',    Path) > 0 Then Error := ReadDORINFO(Path)  Else
  {$ENDIF}
  {$IFDEF LINUX}
    If Pos('DOOR.SYS',   Upper(Path)) > 0 Then Error := ReadDOORSYS(Path)  Else
    If Pos('CHAIN.TXT',  Upper(Path)) > 0 Then Error := ReadCHAINTXT(Path) Else
    If Pos('DORINFO',    Upper(Path)) > 0 Then Error := ReadDORINFO(Path)  Else
    If Pos('DOOR32.SYS', Upper(Path)) > 0 Then Error := ReadDOOR32(Path)   Else
  {$ENDIF}
  {$IFDEF WIN32}
    If Pos('DOOR32.SYS', Path) > 0 Then Error := ReadDOOR32(Path) Else
  {$ENDIF}
  {$IFDEF OS2}
    If Pos('DOOR32.SYS', Path) > 0 Then Error := ReadDOOR32(Path) Else
  {$ENDIF}

  Error := 3;

  If Error > 0 Then Begin
    OpenDOOR := Error;
    Exit;
  End;

  If Not Comm_Local Then Begin
    {$IFDEF MSDOS}
      Comm := New(PFossilOBJ, Init);
    {$ENDIF}
    {$IFDEF WIN32}
      Case Comm_Type of
        1 : Comm := New(PWin32OBJ,  Init);    { init win32 serial i/o }
        2 : Comm := New(PTelnetOBJ, Init);    { init win32 tcp/ip i/o }
      End;
    {$ENDIF}
    {$IFDEF OS2}
      Case Comm_Type of
        1 : Comm := New(POS2OBJ,  Init);      { init os/2 serial i/o }
        2 : Comm := New(PTelnetOBJ, Init);    { init os/2 tcp/ip i/o }
      End;
    {$ENDIF}

    {$IFDEF WIN32}
      Comm^.Com_SetDataProc(@Int_ComReadProc, @Int_ComWriteProc);
      Comm^.DontClose := True;
    {$ENDIF}

    {$IFDEF OS2}
      Comm^.Com_SetDataProc(@Int_ComReadProc, @Int_ComWriteProc);
      Comm^.DontClose := True;
    {$ENDIF}

    {$IFDEF MSDOS}
      If Not Comm^.Com_Open (Comm_Handle, Comm_Baud, 8, 'N', 1) Then Begin
        Error := 4;
        Dispose (Comm, Done);
        Exit;
      End;
    {$ELSE}
      {$IFNDEF LINUX}
        Comm^.Com_OpenQuick(Comm_Handle);
      {$ENDIF}
    {$ENDIF}
  End;

  {$IFDEF MSDOS}
    GetTaskType;
  {$ENDIF}

  SetTimeLeft (User_Time);

  {$IFNDEF LINUX}
    StatusUpdate := TimerMin;
    Window (1, 1, 80, 24);
    dOnStatusUpdate(StatusHelp);
  {$ENDIF}

  { start time left counter here }

  OpenDOOR := Error;
End;

Procedure CloseDOOR;
Begin
End;

{ ========================================================================= }
{ SCREEN OUTPUT FUNCTIONS AND PROCEDURES                                    }
{ ========================================================================= }

Procedure Out (Str : String);
Var
  A : Byte;
Begin
  {$IFDEF LINUX}
    Write (Str);
  {$ELSE}
    For A := 1 to Length(Str) Do Begin
      AnsiWrite(Str[A]);
      If Not Comm_Local Then Comm^.Com_SendChar(Str[A]);
    End;
  {$ENDIF}
End;

Procedure OutLn (Str : String);
Begin
  Out (Str + #13#10);
  Inc (PauseLinePos);
End;

Procedure Send (Str : String);
Var
  A    : Byte;
  Code : String[2];
  FG   : Byte;
  BG   : Byte;
Begin
  For A := 1 to Length(Str) Do Begin
    If (Str[A] = '|') and (A + 2 <= Length(Str)) Then Begin
      FG   := TextAttr And $F;
      BG   := (TextAttr SHR 4) And 7;
      Code := Copy(Str, A + 1, 2);
      Inc (A, 2);
      If Code = '00' Then ansi_Color (00, BG) Else
      If Code = '01' Then ansi_Color (01, BG) Else
      If Code = '02' Then ansi_Color (02, BG) Else
      If Code = '03' Then ansi_Color (03, BG) Else
      If Code = '04' Then ansi_Color (04, BG) Else
      If Code = '05' Then ansi_Color (05, BG) Else
      If Code = '06' Then ansi_Color (06, BG) Else
      If Code = '07' Then ansi_Color (07, BG) Else
      If Code = '08' Then ansi_Color (08, BG) Else
      If Code = '09' Then ansi_Color (09, BG) Else
      If Code = '10' Then ansi_Color (10, BG) Else
      If Code = '11' Then ansi_Color (11, BG) Else
      If Code = '12' Then ansi_Color (12, BG) Else
      If Code = '13' Then ansi_Color (13, BG) Else
      If Code = '14' Then ansi_Color (14, BG) Else
      If Code = '15' Then ansi_Color (15, BG) Else
      If Code = '16' Then ansi_Color (FG, 00) Else
      If Code = '17' Then ansi_Color (FG, 01) Else
      If Code = '18' Then ansi_Color (FG, 02) Else
      If Code = '19' Then ansi_Color (FG, 03) Else
      If Code = '20' Then ansi_Color (FG, 04) Else
      If Code = '21' Then ansi_Color (FG, 05) Else
      If Code = '22' Then ansi_Color (FG, 06) Else
      If Code = '23' Then ansi_Color (FG, 07) Else
      If Code = 'CL' Then SendCLS             Else
      If Code = 'CR' Then OutLn('')           Else
      Begin
        Out('|');
        Dec (A, 2);
      End;

    End Else
      Out (Str[A]);
  End;
End;

Procedure SendLn (Str : String);
Begin
  Send (Str + #13#10);
  Inc (PauseLinePos);
End;

Procedure SendCLS;
Begin
  ClrScr;
  {$IFNDEF LINUX}
    If Not Comm_Local Then Out(#12);
  {$ENDIF}
  PauseLinePos := 1;
End;

Procedure SendBS (Num : Byte);
Var
  A : Byte;
Begin
  For A := 1 to Num Do Out(#8#32#8);
End;

Procedure SendFile (FN : String; Pause : Boolean);
Var
  Ext   : String[4];
  tFile : Text;
  Ch    : Char;
  dOnFilePause: Integer;
Begin
  IsNoFile     := False;
  PauseLinePos := 1;
  Ext          := '.asc';

  If Pos('.', FN) > 0 Then Ext := '' Else
  If (User_Term = 1) and fExist(FN + '.ans') Then Ext := '.ans';

  Assign (tFile, FN + Ext);
  {$I-} Reset (tFile); {$I+}
  If IoResult <> 0 Then Begin
    IsNoFile := True;
    Exit;
  End;

  While Not Eof(tFile) Do Begin
    Read (tFile, Ch);
    Out(Ch);
    If (Ch = #10) and Pause Then Begin
      Inc (PauseLinePos);
      If PauseLinePos >= User_Screen Then Begin
        Case dOnFilePause of
          2 : Break;
          3 : Pause := False;
        End;
        PauseLinePos := 1;
      End;
    End;
  End;

  Close (tFile);
End;

{ ========================================================================= }
{ ANSI SPECIFIC SCREEN FUNCTIONS AND PROCEDURES                             }
{ ========================================================================= }

Procedure Ansi_Color (FG, BG : Byte);
Begin
  If User_Term <> 1 Then Exit;

  Case FG of
    00: Out (#27 + '[0;30m');
    01: Out (#27 + '[0;34m');
    02: Out (#27 + '[0;32m');
    03: Out (#27 + '[0;36m');
    04: Out (#27 + '[0;31m');
    05: Out (#27 + '[0;35m');
    06: Out (#27 + '[0;33m');
    07: Out (#27 + '[0;37m');
    08: Out (#27 + '[1;30m');
    09: Out (#27 + '[1;34m');
    10: Out (#27 + '[1;32m');
    11: Out (#27 + '[1;36m');
    12: Out (#27 + '[1;31m');
    13: Out (#27 + '[1;35m');
    14: Out (#27 + '[1;33m');
    15: Out (#27 + '[1;37m');
  End;

  Case BG of
    00: Out (#27 + '[40m');
    01: Out (#27 + '[44m');
    02: Out (#27 + '[42m');
    03: Out (#27 + '[46m');
    04: Out (#27 + '[41m');
    05: Out (#27 + '[45m');
    06: Out (#27 + '[43m');
    07: Out (#27 + '[47m');
  End;
End;

Procedure Ansi_GotoXY (X, Y : Byte);
Begin
  If User_Term <> 1 Then Exit;

  Out (#27 + '[' + Int2Str(Y) + ';' + Int2Str(X) + 'H');
End;

Procedure Ansi_ClrEOL;
Begin
  If User_Term <> 1 Then Exit;

  Out (#27 + '[K');
End;

{ ========================================================================= }
{ INPUT FUNCTIONS AND PROCEDURES                                            }
{ ========================================================================= }

Function KeyWaiting : Boolean;
Begin
  {$IFDEF LINUX}
    KeyWaiting := KeyPressed;
  {$ELSE}
    If Comm_Local Then
      KeyWaiting := KeyPressed
    Else
      KeyWaiting := KeyPressed or Comm^.Com_CharAvail;
  {$ENDIF}
End;

{$IFDEF LINUX}
Function GetKey : Char;
Var
  Ch : Char;
Begin
  TimeOut    := TimerSec;
  IsArrowKey := False;

  Repeat
    If KeyPressed Then Begin
      IsLocalKey := False;
      Ch         := ReadKey;

      If Ch = #00 Then Begin
        Ch := ReadKey;

        If AllowArrow and (Ch in [#71..#73, #75, #77, #79..#81, #83]) Then Begin
          IsArrowKey := True;
          GetKey     := Ch;
          Exit;
        End;
      End Else Begin
        GetKey := Ch;
        Exit;
      End;
    End Else
    If TimerSec - TimeOut >= 180 Then Begin
      dOnTimeOut;
      TimeOut := TimerSec;
    End Else
    If (GetTimeLeft = 5) And Not TimeWarning Then Begin
      dOnLowTime;
      TimeWarning := True;
    End Else
    If GetTimeLeft <= 0 Then
      dOnNoTime
    Else
      IdleTick;
  Until False;
End;
{$ELSE}
Function GetKey : Char;
Var
  Ch : Char;
Begin
  TimeOut    := TimerSec;
  IsArrowKey := False;

  Repeat
    If KeyPressed Then Begin
      IsLocalKey := True;
      Ch         := ReadKey;

      If Ch = #00 Then Begin
        Ch := ReadKey;

        If AllowArrow and (Ch in [#71..#73, #75, #77, #79..#81, #83]) Then Begin
          IsArrowKey := True;
          GetKey     := Ch;
          Exit;
        End;

        Case Ch of
          #36 : dOnOsShell;
          #37 : dOnKickUser;
          #44 : Begin
                  StatusHelp := Not StatusHelp;
                  dOnStatusUpdate(StatusHelp);
                End;
          #46 : If Not InChatMode Then Begin
                  InChatMode := True;
                  dOnChatMode;
                  InChatMode := False;
                End;
          #130: If GetTimeLeft > 1 Then Begin
                  SetTimeLeft(GetTimeLeft - 1);
                  dOnStatusUpdate(StatusHelp);
                End;
          #131: If GetTimeLeft < 1440 Then Begin
                  SetTimeLeft(GetTimeLeft + 1);
                  dOnStatusUpdate(StatusHelp);
                End;
        End;
      End Else Begin
        GetKey := Ch;
        Break;
      End;
    End Else
    If Not Comm_Local and Comm^.Com_CharAvail Then Begin
      IsLocalKey := False;

      If AllowArrow Then Begin
        Ch         := Comm^.Com_GetChar;
        IsArrowKey := True;

        Case Ch of
          #03 : Ch := #81; { wordstar pgdn  }
          #04 : Ch := #77; { wordstar right }
          #05 : Ch := #72; { wordstar up    }
          #18 : Ch := #73; { wordstar pgup  }
          #19 : Ch := #75; { wordstar left  }
          #24 : Ch := #80; { wordstar down  }
          #27 : Begin
                  If Not Comm^.com_CharAvail Then ms_Delay(25);
                  If Not Comm^.com_CharAvail Then ms_Delay(25);
                  If Comm^.com_CharAvail Then Begin
                    If Comm^.com_GetChar = '[' Then
                      Case Comm^.com_GetChar of
                        'A' : Ch := #72; { ansi up    }
                        'B' : Ch := #80; { ansi down  }
                        'C' : Ch := #77; { ansi right }
                        'D' : Ch := #75; { ansi left  }
                        'H' : Ch := #71; { ansi home  }
                        'K' : Ch := #79; { ansi end   }
                      End;
                  End Else
                    IsArrowKey := False;
                End;
          #127: Ch := #83; { delete key }
        Else
          IsArrowKey := False;
          GetKey     := Ch;
          Break;
        End;
      End Else Begin
        GetKey := Comm^.Com_GetChar;
        Break;
      End;
    End Else
    If Not Comm_Local and Not Comm^.Com_Carrier Then
      dOnNoCarrier
    Else
    If TimerSec - TimeOut >= 180 Then Begin
      dOnTimeOut;
      TimeOut := TimerSec;
    End Else
    If TimerMin = StatusUpdate Then Begin
      dOnStatusUpdate(StatusHelp);
      StatusUpdate := TimerMin + 1;
      If StatusUpdate > 1439 Then StatusUpdate := 1;
    End Else
    If (GetTimeLeft = 5) And Not TimeWarning Then Begin
      dOnLowTime;
      TimeWarning := True;
    End Else
    If GetTimeLeft <= 0 Then
      dOnNoTime
    Else
      IdleTick;
  Until False;
End;
{$ENDIF}

Function OneKey (S : String; Echo : Boolean) : Char;
Var
  Ch : Char;
Begin
  Repeat
    Ch := UpCase(GetKey);
  Until Pos(Ch, S) > 0;
  If Echo Then OutLn(Ch);
  OneKey := Ch;
End;

Function Input (Mode : Byte; MaxLen : Byte; Valid : String; Default : String) : String;
Var
  Str : String;
  Ch  : Char;
Begin
  Str := '';

  If Default <> '' Then Begin
    Str := Default;
    If Length(Str) > MaxLen Then Str[0] := Chr(MaxLen);
    Out(Str);
  End;

  Repeat
    Ch := GetKey;
    Case Ch of
      #08 : If Length(Str) > 0 Then Begin
              Dec(Str[0]);
              SendBS(1);
            End;
      #13 : Break;
    Else
      If (Length(Str) < MaxLen) and (Pos(Ch, Valid) > 0) Then Begin
        Case Mode of
          1 : Ch := UpCase(Ch);
          2 : Ch := LoCase(Ch);
          3 : If (Str = '') or (Str[Length(Str)] = ' ') Then
                Ch := UpCase(Ch)
              Else
                Ch := LoCase(Ch);
        End;
        Str := Str + Ch;
        Out(Ch);
      End;
    End;
  Until False;

  OutLn('');

  Input := Str;
End;

{ ========================================================================= }
{ MISCELLANEOUS FUNCTIONS AND PROCEDURES                                    }
{ ========================================================================= }

Procedure SetTimeLeft (Time : Integer);
Begin
  TimerStart := TimerMin;
  TimerEnd   := TimerStart + Time;
End;

Function GetTimeLeft : Integer;
Begin
  If TimerStart > TimerMin Then Begin
    Dec (TimerStart, 1440);
    Dec (TimerEnd,   1440);
  End;

  GetTimeLeft := TimerEnd - TimerMin;
End;

Function TimerMin : Integer;
Var
  Hour,
  Min,
  Sec,
  Sec100 : LongWord;
Begin
  GetTime (Hour, Min, Sec, Sec100);
  TimerMin := (Hour * 60) + Min;
End;

Function TimerSec : LongInt;
Var
  Hour,
  Minute,
  Second,
  Sec100  : LongWord;
Begin
  GetTime (Hour, Minute, Second, Sec100);
  TimerSec := ((Hour * 60 * 60) + (Minute * 60) + (Second));
End;

{ ========================================================================= }
{ REDEFINABLE FUNCTIONS AND PROCEDURES                                      }
{ ========================================================================= }

{$F+}
Procedure ProcTimeOut;
Begin
  SendLn ('|CR|12* |14Inactivity timeout.');
  CloseDOOR;
  Halt(0);
End;

Procedure ProcNoCarrier;
Begin
  {$IFNDEF LINUX}
    TextAttr := 12;
    WriteLn ('Connection lost.');
    ms_Delay(3000);
  {$ENDIF}
  CloseDOOR;
  Halt(0);
End;

Procedure ProcStatusUpdate (Help : Boolean);
Begin
{$IFNDEF LINUX}
  If Help Then Begin
    WriteXY (1, 25, ' Alt-C  Chat     Alt-K  Kick     Alt +/- Time     Alt-J  Shell       Alt-Z Help ', 112)
  End Else Begin
    WriteXY ( 1, 25, ' User                                Baud             Time           Alt-Z Help ', 112);
    WriteXY ( 7, 25, '[                         ]', 113);
    WriteXY (43, 25, '[      ]', 113);
    WriteXY (60, 25, '[    ]', 113);

    WriteXY (8, 25, User_Handle, 120);

    If Comm_Local Then
      WriteXY (44, 25, 'LOCAL', 120)
    Else
    If Comm_Type = 2 Then
      WriteXY (44, 25, 'TELNET', 120)
    Else
      WriteXY (44, 25, Int2Str(Comm_Baud), 120);

    WriteXY (61, 25, Int2Str(GetTimeLeft), 120);
  End;
{$ENDIF}
End;

Procedure ProcChatMode;
{$IFNDEF LINUX}
Var
  Ch  : Char;
  Str : String;
  A   : Byte;
  LK  : Boolean;
{$ENDIF}
Begin
{$IFNDEF LINUX}
  SendLn ('|CR|14Chat mode engaged...|CR');

  Ansi_Color (9, 0);

  Str := '';
  LK  := True;

  Repeat
    Ch := GetKey;

    If IsLocalKey <> LK Then Begin
      LK := IsLocalKey;
      If LK Then ansi_Color(9, 0) Else ansi_Color(11, 0);
    End;

    Case Ch of
      #08 : If Str <> '' Then Begin
              Dec(Str[0]);
              SendBS (1);
            End;
      #13 : Begin
              OutLn ('');
              Str := '';
            End;
      #27 : Break;
    Else
      Str := Str + Ch;
      Out (Ch);
      If Length(Str) > 78 Then
        If Pos(' ', Str) > 0 Then Begin
          For A := Length(Str) DownTo 1 Do
            If Str[A] = ' ' Then Begin
              Str := Copy(Str, A+1, Length(Str));
              SendBS (Length(Str));
              OutLn ('');
              Out (Str);
              Break;
            End;
        End Else Begin
          Str := '';
          OutLn('');
        End;
    End;
  Until False;

  SendLn ('|14|CRChat mode complete...');
{$ENDIF}
End;

Procedure ProcLowTime;
Begin
  SendLn ('|CR|12* |14You have |155 |14minutes remaining.');
End;

Procedure ProcNoTime;
Begin
  SendLn ('|CR|12* |14You have |150 |14minutes remaining.');
  CloseDOOR;
  Halt(0);
End;

Function ProcFilePause : Byte;
Var
  FG : Byte;
  BG : Byte;
Begin
  FG := TextAttr And $F;
  BG := (TextAttr SHR 4) And 7;

  Send ('|12-More- |14(|15Y|14)es, (|15N|14)o, (|15C|14)ontinuous? |15');
  Case OneKey(#13 + 'YNC', False) of
    #13,
    'Y' : ProcFilePause := 1;
    'N' : ProcFilePause := 2;
    'C' : ProcFilePause := 3;
  End;

  SendBS (WhereX);
  Ansi_Color (FG, BG);
End;

Procedure ProcKickUser;
Begin
  CloseDOOR;
  Halt(0);
End;

Procedure ProcOsShell;
Begin
  {$IFNDEF LINUX}
    SendLn ('|CR|12* |14Sysop has shelled to the OS...');

    ScrnWrite^.Save;

    TextAttr := 7;
    Window (1, 1, 80, 25);
    ClrScr;
    WriteLn ('Type "EXIT" to return to door...');

    SwapVectors;
    Exec (GetEnv('COMSPEC'), '');
    SwapVectors;

    Window (1, 1, 80, 24);

    ScrnWrite^.Restore;

    dOnStatusUpdate(StatusHelp);

    SendLn ('|12* |14Sysop has returned from shell...');
  {$ENDIF}
End;
{$F-}

Procedure CleanUpExitProc; Far;
Begin
  If Not Comm_Local Then Begin
    {$IFDEF MSDOS}  Comm^.com_Close;      {$ENDIF}
    {$IFNDEF LINUX} Dispose (Comm, Done); {$ENDIF}
  End;

  TextAttr := 7;
  {$IFNDEF LINUX}
    Window (1, 1, 80, 25);
    GotoXY (1, 25);
  {$ENDIF}

  WriteLn;

  {$IFNDEF LINUX}
    If ScrnWrite <> Nil Then
      Dispose (ScrnWrite, Done);
  {$ENDIF}
End;

{$IFDEF LINUX}
Procedure HandleEventSignal (Sig : LongInt); cdecl;
Begin
  Case Sig of
    SIGHUP  : ProcNoCarrier;
    SIGTERM : ProcNoCarrier;
  End;
End;
{$ENDIF}

{$IFDEF WIN32}
Procedure Win32MouseOFF;
Var
  Mode : LongInt;
Begin
  If GetConsoleMode(SysFileStdIn, Mode) Then
    If SetConsoleMode(SysFileStdIn, Mode And Not Enable_Mouse_Input) Then;
End;
{$ENDIF}

Begin
  CheckBreak := False;

  {$IFDEF WIN32}
    Win32MouseOFF;
  {$ENDIF}

  {$IFDEF LINUX}
    fpSignal (SIGTERM, HandleEventSignal);
    fpSignal (SIGHUP,  HandleEventSignal);
  {$ENDIF}

  { assign default redefinable procedures }

  dOnNoCarrier    := ProcNoCarrier;
  dOnTimeOut      := ProcTimeOut;
  dOnStatusUpdate := ProcStatusUpdate;
  dOnChatMode     := ProcChatMode;
  dOnLowTime      := ProcLowTime;
  dOnNoTime       := ProcNoTime;
  dOnFilePause    := ProcFilePause;
  dOnKickUser     := ProcKickUser;
  dOnOsShell      := ProcOsShell;
  ExitProc        := @CleanUpExitProc;

  {$IFNDEF LINUX}
    New(ScrnWrite, Init);
  {$ENDIF}
End.
