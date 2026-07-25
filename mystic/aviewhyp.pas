Unit AViewHYP;

// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
// Kiddo — Copyright (C) 2026 — GPLv3 — 1.11IRC A7: HYP internal archive reader
//
// HYP format (Peter Sawatzki, 1993):
//   Header: HP + version byte + file entries
// ====================================================================

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  AView;

Type
  HypFileRec = Record
    CompSize : LongInt;
    OrigSize : LongInt;
    DateTime : LongInt;
    CRC32    : LongInt;
    FNameLen : Byte;
    Method   : Byte;
    Flags    : Byte;
  End;

  PHypArchive = ^THypArchive;
  THypArchive = Object(TGeneralArchive)
    Constructor Init;
    Procedure   FindFirst (Var SR: ArcSearchRec); Virtual;
    Procedure   FindNext  (Var SR: ArcSearchRec); Virtual;
  Private
    FileHdr : HypFileRec;
    NextPos : LongInt;
    Procedure GetHeader (Var SR: ArcSearchRec);
  End;

Implementation

Constructor THypArchive.Init;
Begin
  NextPos := 0;
End;

Procedure THypArchive.GetHeader (Var SR: ArcSearchRec);
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

Procedure THypArchive.FindFirst (Var SR: ArcSearchRec);
Var
  Magic : Array[1..3] of Byte;
  NR    : LongInt;
Begin
  // Skip HP + version header
  BlockRead(ArcFile, Magic, 3, NR);
  NextPos := FilePos(ArcFile);
  GetHeader(SR);
End;

Procedure THypArchive.FindNext (Var SR: ArcSearchRec);
Begin
  GetHeader(SR);
End;

End.
