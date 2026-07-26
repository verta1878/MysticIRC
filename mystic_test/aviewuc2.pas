Unit AViewUC2;

// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
// Kiddo — Copyright (C) 2026 — GPLv3 — 1.11IRC A7: UC2 internal archive reader
//
// UC2 format (Ad Infinitum Programs, 1992):
//   Header: UC2\x1A + version + file entries
//   Was popular on BBS systems, extremely high compression
// ====================================================================

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  AView;

Type
  UC2MainHdr = Record
    Magic    : Array[1..4] of Char;   // UC2\x1A
    Version  : Word;
    Flags    : Word;
  End;

  UC2FileRec = Record
    Tag      : Byte;          // Record type tag
    CompSize : LongInt;
    OrigSize : LongInt;
    DateTime : LongInt;
    CRC32    : LongInt;
    Attr     : Byte;
    FNameLen : Byte;
  End;

  PUC2Archive = ^TUC2Archive;
  TUC2Archive = Object(TGeneralArchive)
    Constructor Init;
    Procedure   FindFirst (Var SR: ArcSearchRec); Virtual;
    Procedure   FindNext  (Var SR: ArcSearchRec); Virtual;
  Private
    MainHdr : UC2MainHdr;
    FileHdr : UC2FileRec;
    NextPos : LongInt;
    Procedure GetHeader (Var SR: ArcSearchRec);
  End;

Implementation

Constructor TUC2Archive.Init;
Begin
  NextPos := 0;
End;

Procedure TUC2Archive.GetHeader (Var SR: ArcSearchRec);
Var
  NR : LongInt;
Begin
  FillChar(SR, SizeOf(SR), 0);

  Seek(ArcFile, NextPos);
  If Eof(ArcFile) Then Exit;

  BlockRead(ArcFile, FileHdr, SizeOf(FileHdr), NR);
  If NR < SizeOf(FileHdr) Then Exit;

  // Tag 0 = end of archive
  If FileHdr.Tag = 0 Then Exit;
  If FileHdr.FNameLen = 0 Then Exit;

  BlockRead(ArcFile, SR.Name[1], FileHdr.FNameLen);
  SR.Name[0] := Chr(FileHdr.FNameLen);

  SR.Size := FileHdr.OrigSize;
  SR.Time := FileHdr.DateTime;

  If FileHdr.Attr AND $10 <> 0 Then SR.Attr := $10;

  NextPos := FilePos(ArcFile) + FileHdr.CompSize;
End;

Procedure TUC2Archive.FindFirst (Var SR: ArcSearchRec);
Var
  NR : LongInt;
Begin
  BlockRead(ArcFile, MainHdr, SizeOf(MainHdr), NR);
  NextPos := FilePos(ArcFile);
  GetHeader(SR);
End;

Procedure TUC2Archive.FindNext (Var SR: ArcSearchRec);
Begin
  GetHeader(SR);
End;

End.
