// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================
Unit m_io_stdio;

{$I M_OPS.PAS}

Interface

Uses
  {$IFDEF OS2}
    DosCalls,   // OS/2: FPC RTL Dos* API (no BaseUnix on OS/2)
  {$ELSE}
    {$IFDEF GO32V2}
      Dos, SysUtils,   // DOS/go32v2: no BaseUnix; FileRead/FileWrite handle I/O
    {$ELSE}
      BaseUnix,
    {$ENDIF}
  {$ENDIF}
  m_io_Base;

Const
  STDIO_IN  = 0;
  STDIO_OUT = 1;

Type
  TSTDIO = Class(TIOBase)
    Constructor Create; Override;
    Destructor  Destroy; Override;
    Function    DataWaiting      : Boolean; Override;
    Function    WriteBuf         (Var Buf; Len: LongInt) : LongInt; Override;
    Function    ReadBuf          (Var Buf; Len: LongInt) : LongInt; Override;
    Procedure   BufWriteChar     (Ch: Char); Override;
    Procedure   BufWriteStr      (Str: String); Override;
    Procedure   BufFlush;        Override;
    Function    WriteLine        (Str: String) : LongInt; Override;
    Function    ReadLine         (Var Str: String) : LongInt; Override;
    Function    WaitForData      (TimeOut: LongInt) : LongInt; Override;
    Function    PeekChar         (Num: Byte) : Char; Override;
    Function    ReadChar         : Char; Override;
  End;

Implementation

// Raw stdio primitives.  Unix uses the fp* syscalls; OS/2 uses the FPC
// RTL DosCalls API on the standard handles.  Everything above these two
// helpers is platform-independent.

Function StdWrite (Var Buf; Len: LongInt) : LongInt;
{$IFDEF OS2}
Var
  Actual : LongInt;
{$ENDIF}
Begin
  {$IFDEF OS2}
    If DosWrite (STDIO_OUT, Buf, Len, Actual) = 0 Then
      Result := Actual
    Else
      Result := -1;
  {$ELSE}
    {$IFDEF GO32V2}
      // DOS: write to stdout handle (1) via the RTL file-handle writer.
      Result := FileWrite(STDIO_OUT, Buf, Len);
    {$ELSE}
      Result := fpWrite(STDIO_OUT, Buf, Len);
    {$ENDIF}
  {$ENDIF}
End;

Function StdRead (Var Buf; Len: LongInt) : LongInt;
{$IFDEF OS2}
Var
  Actual : LongInt;
{$ENDIF}
Begin
  {$IFDEF OS2}
    If DosRead (STDIO_IN, Buf, Len, Actual) = 0 Then
      Result := Actual
    Else
      Result := -1;
  {$ELSE}
    {$IFDEF GO32V2}
      // DOS: read from stdin handle (0) via the RTL file-handle reader.
      Result := FileRead(STDIO_IN, Buf, Len);
    {$ELSE}
      Result := fpRead(STDIO_IN, Buf, Len);
    {$ENDIF}
  {$ENDIF}
End;

Constructor TSTDIO.Create;
Begin
  Inherited Create;

  FInBufPos  := 0;
  FInBufEnd  := 0;
  FOutBufPos := 0;
End;

Destructor TSTDIO.Destroy;
Begin
  Inherited Destroy;
End;

Function TSTDIO.DataWaiting : Boolean;
Begin
  Result := (FInBufPos < FInBufEnd) or (WaitForData(1) > 0);
End;

Function TSTDIO.WriteBuf (Var Buf; Len: LongInt) : LongInt;
Begin
  Result := StdWrite(Buf, Len);
End;

Procedure TSTDIO.BufFlush;
Begin
  If FOutBufPos > 0 Then Begin
    StdWrite (FOutBuf, FOutBufPos);

    FOutBufPos := 0;
  End;
End;

Procedure TSTDIO.BufWriteChar (Ch: Char);
Begin
  FOutBuf[FOutBufPos] := Ch;

  Inc(FOutBufPos);

  If FOutBufPos > TIOBufferSize Then
    BufFlush;
End;

Procedure TSTDIO.BufWriteStr (Str: String);
Var
  Count : LongInt;
Begin
  For Count := 1 to Length(Str) Do
    BufWriteChar(Str[Count]);
End;

Function TSTDIO.ReadChar : Char;
Begin
  ReadBuf(Result, 1);
End;

Function TSTDIO.PeekChar (Num: Byte) : Char;
Begin
  If (FInBufPos = FInBufEnd) and DataWaiting Then
    ReadBuf(Result, 0);

  If FInBufPos + Num < FInBufEnd Then
    Result := FInBuf[FInBufPos + Num];
End;

Function TSTDIO.ReadBuf (Var Buf; Len: LongInt) : LongInt;
Begin
  If FInBufPos = FInBufEnd Then Begin
    FInBufEnd := StdRead(FInBuf, TIOBufferSize);
    FInBufPos := 0;

    If FInBufEnd <= 0 Then Begin
      FInBufEnd := 0;
      Result    := -1;
      Exit;
    End;
  End;

  If Len > FInBufEnd - FInBufPos Then Len := FInBufEnd - FInBufPos;

  Move (FInBuf[FInBufPos], Buf, Len);
  Inc  (FInBufPos, Len);

  Result := Len;
End;

Function TSTDIO.ReadLine (Var Str: String) : LongInt;
Var
  Ch  : Char;
  Res : LongInt;
Begin
  Str := '';
  Res := 0;

  Repeat
    If FInBufPos = FInBufEnd Then Res := ReadBuf(Ch, 0);

    Ch := FInBuf[FInBufPos];

    Inc (FInBufPos);

    If (Ch <> #10) And (Ch <> #13) And (FInBufEnd > 0) Then Str := Str + Ch;
  Until (Ch = #10) Or (Res < 0) Or (FInBufEnd = 0);

  If Res < 0 Then Result := -1 Else Result := Length(Str);
End;

Function TSTDIO.WriteLine (Str: String) : LongInt;
Begin
  Str    := Str + #13#10;
  Result := StdWrite(Str[1], Length(Str));
End;

Function TSTDIO.WaitForData (TimeOut: LongInt) : LongInt;
{$IF (not Defined(OS2)) and (not Defined(GO32V2))}
Var
  FDSIN : TFDSET;
{$IFEND}
Begin
  {$IFDEF OS2}
    // OS/2 phase 1: no select() on file handles.  Report "ready" and let
    // DosRead block - correct for a blocking pipe/handle session.  Revisit
    // with DosPeekNPipe/DosWaitEventSem once the native session model is
    // exercised on real OS/2 (see docs/TODO.md OS/2 item).
    Result := 1;
  {$ELSE}
    {$IFDEF GO32V2}
      // DOS: no select() on file handles (single-tasking).  Report "ready"
      // and let FileRead block - a DOS door/stdio session is inherently
      // blocking.  (Network sessions use m_io_sockets + Watt-32 select,
      // not this stdio path.)
      Result := 1;
    {$ELSE}
      fpFD_Zero (FDSIN);
      fpFD_Set  (STDIO_IN, FDSIN);

      Result := fpSelect (STDIO_IN + 1, @FDSIN, NIL, NIL, TimeOut);
    {$ENDIF}
  {$ENDIF}
End;

End.
