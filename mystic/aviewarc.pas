Unit AViewARC;

// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
// Kiddo — Copyright (C) 2026 — GPLv3 — 1.11IRC A7: ARC/PAK internal archive reader
//
// ARC format (System Enhancement Associates, 1985):
//   Header: 0x1A + method byte + 13-char filename + sizes + CRC
//   Method 0 = end marker, 1-9 = compression methods
//
// PAK format (NoGate Consulting, 1989):
//   Same as ARC with methods 10-11 added (Crush/Distill)
// ====================================================================

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  AView;

Type
  ArcHeaderRec = Record
    Marker   : Byte;         // Always 0x1A
    Method   : Byte;         // 0=end, 1=old, 2=stored, 3-9=packed
    FileName : Array[1..13] of Char;
    CompSize : LongInt;
    DateTime : Word;
    DateDate : Word;
    CRC16    : Word;
    OrigSize : LongInt;      // Only in method >= 2
  End;

  PArcArchive = ^TArcArchive;
  TArcArchive = Object(TGeneralArchive)
    Constructor Init;
    Procedure   FindFirst (Var SR: ArcSearchRec); Virtual;
    Procedure   FindNext  (Var SR: ArcSearchRec); Virtual;
  Private
    Hdr     : ArcHeaderRec;
    NextPos : LongInt;
    Procedure GetHeader (Var SR: ArcSearchRec);
  End;

Implementation

Constructor TArcArchive.Init;
Begin
  NextPos := 0;
End;

Procedure TArcArchive.GetHeader (Var SR: ArcSearchRec);
Var
  NR    : LongInt;
  FName : String;
  I     : Byte;
Begin
  FillChar(SR, SizeOf(SR), 0);

  Seek(ArcFile, NextPos);

  If Eof(ArcFile) Then Exit;

  FillChar(Hdr, SizeOf(Hdr), 0);
  BlockRead(ArcFile, Hdr, SizeOf(Hdr), NR);

  // ARC marker must be 0x1A
  If Hdr.Marker <> $1A Then Exit;

  // Method 0 = end of archive
  If Hdr.Method = 0 Then Begin
    SR.Name := '';
    Exit;
  End;

  // Extract null-terminated filename
  FName := '';
  For I := 1 to 13 Do Begin
    If Hdr.FileName[I] = #0 Then Break;
    FName := FName + Hdr.FileName[I];
  End;

  SR.Name := FName;
  SR.Size := Hdr.OrigSize;
  SR.Time := LongInt(Hdr.DateDate) SHL 16 + Hdr.DateTime;

  // Method 1 (old format) has no OrigSize — header is 2 bytes shorter
  If Hdr.Method = 1 Then Begin
    SR.Size := Hdr.CompSize;
    NextPos := NextPos + 2 + 1 + 13 + 4 + 4 + Hdr.CompSize;
  End Else
    NextPos := NextPos + SizeOf(Hdr) + Hdr.CompSize;
End;

Procedure TArcArchive.FindFirst (Var SR: ArcSearchRec);
Begin
  NextPos := 0;
  GetHeader(SR);
End;

Procedure TArcArchive.FindNext (Var SR: ArcSearchRec);
Begin
  GetHeader(SR);
End;

End.
