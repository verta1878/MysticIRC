Unit AViewSQZ;

// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
// Kiddo — Copyright (C) 2026 — GPLv3 — 1.11IRC A7: SQZ internal archive reader
//
// SQZ format (Haruyasu Yoshizaki, 1990s):
//   Header: HLSQZ magic + version + file entries
// ====================================================================

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  AView;

Type
  SqzHeaderRec = Record
    Magic    : Array[1..5] of Char;   // HLSQZ
    Version  : Byte;
    Flags    : Word;
  End;

  SqzFileRec = Record
    Method   : Byte;
    CompSize : LongInt;
    OrigSize : LongInt;
    DateTime : LongInt;
    Attr     : Byte;
    CRC32    : LongInt;
    FNameLen : Byte;
  End;

  PSqzArchive = ^TSqzArchive;
  TSqzArchive = Object(TGeneralArchive)
    Constructor Init;
    Procedure   FindFirst (Var SR: ArcSearchRec); Virtual;
    Procedure   FindNext  (Var SR: ArcSearchRec); Virtual;
  Private
    MainHdr : SqzHeaderRec;
    FileHdr : SqzFileRec;
    NextPos : LongInt;
    Procedure GetHeader (Var SR: ArcSearchRec);
  End;

Implementation

Constructor TSqzArchive.Init;
Begin
  NextPos := 0;
End;

Procedure TSqzArchive.GetHeader (Var SR: ArcSearchRec);
Var
  NR : LongInt;
Begin
  FillChar(SR, SizeOf(SR), 0);

  Seek(ArcFile, NextPos);
  If Eof(ArcFile) Then Exit;

  BlockRead(ArcFile, FileHdr, SizeOf(FileHdr), NR);

  If NR < SizeOf(FileHdr) Then Exit;
  If FileHdr.FNameLen = 0 Then Exit;

  BlockRead(ArcFile, SR.Name[1], FileHdr.FNameLen);
  SR.Name[0] := Chr(FileHdr.FNameLen);

  SR.Size := FileHdr.OrigSize;
  SR.Time := FileHdr.DateTime;

  NextPos := FilePos(ArcFile) + FileHdr.CompSize;
End;

Procedure TSqzArchive.FindFirst (Var SR: ArcSearchRec);
Var
  NR : LongInt;
Begin
  // Skip main header
  BlockRead(ArcFile, MainHdr, SizeOf(MainHdr), NR);
  NextPos := FilePos(ArcFile);
  GetHeader(SR);
End;

Procedure TSqzArchive.FindNext (Var SR: ArcSearchRec);
Begin
  GetHeader(SR);
End;

End.
