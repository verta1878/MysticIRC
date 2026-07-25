Unit AView;

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

{$I M_OPS.PAS}

Interface

Uses Dos;

Type
  ArcSearchRec = Record
    Name : String[50];
    Size : LongInt;
    Time : LongInt;
    Attr : Byte;
  End;

Type
  PGeneralArchive = ^TGeneralArchive;
  TGeneralArchive = Object
    ArcFile : File;
    Constructor Init;
    Destructor  Done; Virtual;
    Procedure   FindFirst (Var SR: ArcSearchRec); Virtual;
    Procedure   FindNext  (Var SR: ArcSearchRec); Virtual;
  End;

Type
  PArchive = ^TArchive;
  TArchive = Object
    Constructor Init;
    Destructor  Done;
    Function    Name      (N: String) : Boolean;
    Procedure   FindFirst (Var SR: ArcSearchRec);
    Procedure   FindNext  (Var SR: ArcSearchRec);
  Private
    _Name    : String;
    _Archive : PGeneralArchive;
  End;

Function GetArchiveType (Name: String) : Char;

Implementation

Uses
  AViewZIP,
  AViewARJ,
  AViewLZH,
  AViewRAR,
  AViewARC,
  AViewSQZ,
  AViewHYP,
  AViewUC2,
  AViewMeta;

Function GetArchiveType (Name: String) : Char;
Var
  ArcFile : File;
  Buf     : Array[1..5] of Char;
  Res     : LongInt;
Begin
  Result := '?';

  If Name = '' Then Exit;

  Assign (ArcFile, Name);
  {$I-} Reset (ArcFile, 1); {$I+}
  If IoResult <> 0 Then Exit;

  BlockRead (ArcFile, Buf, SizeOf(Buf), Res);
  Close (ArcFile);

  If Res = 0 Then Exit;

  If (Buf[1] = 'R') and (Buf[2] = 'a') and (Buf[3] = 'r') Then
    Result := 'R'
  Else
  If (Buf[1] = #$60) And (Buf[2] = #$EA) Then
    Result := 'A'
  Else
  If (Buf[1] = 'P') And (Buf[2] = 'K') Then
    Result := 'Z'
  Else
  If (Buf[3] = '-') and (Buf[4] = 'l') and (Buf[5] in ['h', 'z']) Then
    Result := 'L'
  Else
  // ARC/PAK: 0x1A marker byte
  If Buf[1] = #$1A Then
    Result := 'C'
  Else
  // SQZ: HLSQZ
  If (Buf[1] = 'H') and (Buf[2] = 'L') and (Buf[3] = 'S') and
     (Buf[4] = 'Q') and (Buf[5] = 'Z') Then
    Result := 'S'
  Else
  // HYP: HP
  If (Buf[1] = 'H') and (Buf[2] = 'P') Then
    Result := 'H'
  Else
  // UC2: UC2\x1A
  If (Buf[1] = 'U') and (Buf[2] = 'C') and (Buf[3] = '2') and
     (Buf[4] = #$1A) Then
    Result := 'U';

  // Media files: detect by extension (no single magic number)
  If Result = '?' Then Begin
    If IsMediaExtension(Name) Then
      Result := 'M';
  End;
End;

Constructor TGeneralArchive.Init;
Begin
End;

Destructor TGeneralArchive.Done;
Begin
End;

Procedure TGeneralArchive.FindFirst(var sr:ArcSearchRec);
Begin
End;

Procedure TGeneralArchive.FindNext(var sr:ArcSearchRec);
Begin
End;

Constructor TArchive.Init;
Begin
  _Name    := '';
  _Archive := Nil;
End;

Destructor TArchive.Done;
Begin
  If _Archive <> Nil Then Begin
    Close   (_Archive^.ArcFile);
    Dispose (_Archive, Done);
  End;
End;

Function TArchive.Name (N: String): Boolean;
Var
  SR : SearchRec;
Begin
  If _Archive <> Nil Then Begin
    Close   (_Archive^.ArcFile);
    Dispose (_Archive, Done);
    _Archive := Nil;
  End;

  Name  := False;
  _Name := N;

  Dos.FindFirst(_Name, AnyFile, SR);
  FindClose (SR);

  If DosError <> 0 Then Exit;

  Case GetArchiveType(_Name) of
    '?' : Exit;
    'A' : _Archive := New(PArjArchive, Init);
    'Z' : _Archive := New(PZipArchive, Init);
    'L' : _Archive := New(PLzhArchive, Init);
    'R' : _Archive := New(PRarArchive, Init);
    'C' : _Archive := New(PArcArchive, Init);
    'S' : _Archive := New(PSqzArchive, Init);
    'H' : _Archive := New(PHypArchive, Init);
    'U' : _Archive := New(PUC2Archive, Init);
    'M' : _Archive := New(PMediaArchive, Init);
  End;

  Assign(_Archive^.ArcFile, N);
  {$I-} Reset(_Archive^.ArcFile, 1); {$I+}
  If IoResult <> 0 Then Begin
    Dispose (_Archive, Done);
    Exit;
  End;

  Name := True;
End;

Procedure TArchive.FindFirst (Var SR : ArcSearchRec);
Begin
  FillChar(SR, SizeOf(SR), 0);
  If _Archive = Nil Then Exit;
  _Archive^.FindFirst(SR);
End;

Procedure TArchive.FindNext(var sr:ArcSearchRec);
Begin
  FillChar(SR, SizeOf(SR), 0);
  If _Archive = Nil Then Exit;
  _Archive^.FindNext(SR);
End;

End.
