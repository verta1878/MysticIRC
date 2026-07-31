Unit MediaTag;

// ====================================================================
// Copyright 2026 by Antonio Rico (verta1878)
// Part of mystic-bbs-irc (GPLv3 community fork)
// ====================================================================
//
// This file is part of mystic-bbs-irc.
//
// mystic-bbs-irc is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// mystic-bbs-irc is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// ====================================================================
//
// MediaTag - pure Pascal media-metadata reader used by MARC.
//
// Reads descriptive tags from media files WITHOUT any external tool or
// library, so it compiles unchanged on every Mystic target (Windows,
// Linux, Darwin/macOS, FreeBSD, OS/2, DOS/go32v2).  It reads structure
// (tags/atoms) only - it never decodes audio or video.
//
// Supported now:
//   MP3  - ID3v2 (2.2/2.3/2.4) preferred, ID3v1 128-byte tail fallback
//   MP4  - ISO base-media (MP4/M4A/MOV) 'moov/udta/meta/ilst' iTunes atoms
//          plus 'mvhd' duration
//
// Kept intentionally small and dependency-free (only the RTL).
//
// ====================================================================

Interface

Type
  TMediaInfo = Record
    Valid      : Boolean;      // was any metadata found
    Kind       : String;       // 'MP3' / 'MP4' / '' (unknown)
    Title      : String;
    Artist     : String;
    Album      : String;
    Year       : String;
    Genre      : String;
    Comment    : String;
    Duration   : LongInt;      // seconds, 0 if unknown
    // A52: extended MP4 codec info (from trak/stsd/tkhd/mdhd atoms)
    VCodec     : String;       // video codec FourCC e.g. 'avc1', 'mp4v'
    VWidth     : Word;         // video width in pixels
    VHeight    : Word;         // video height in pixels
    VBitRate   : LongInt;      // video bitrate in kbps (estimated), 0 if unknown
    VFrameRate : String;       // frame rate e.g. '29.97', '25', '' if unknown
    ACodec     : String;       // audio codec FourCC e.g. 'mp4a', ''
    ASampleRate: LongInt;      // audio sample rate in Hz e.g. 48000
    AChannels  : Word;         // audio channels (1=mono, 2=stereo)
    ABitRate   : LongInt;      // audio bitrate in kbps, 0 if unknown
  End;

// Fill Info from FileName.  Returns True if the file was recognised as a
// media file we can read (even if some fields are blank).
Function  ReadMediaTags (FileName: String; Var Info: TMediaInfo) : Boolean;

// Convenience: True if the extension looks like something we can read.
Function  IsMediaFile   (FileName: String) : Boolean;

Implementation

Uses
  SysUtils;

// -------------------------------------------------------------------
// helpers
// -------------------------------------------------------------------

Function UpExt (FileName: String) : String;
Var
  P : LongInt;
  E : String;
Begin
  E := '';
  P := Length(FileName);
  While (P > 0) and (FileName[P] <> '.') and (FileName[P] <> '\') and (FileName[P] <> '/') Do
    Dec (P);
  If (P > 0) and (FileName[P] = '.') Then
    E := Copy(FileName, P + 1, Length(FileName) - P);
  UpExt := UpperCase(E);
End;

// strip trailing NULs/spaces (ID3v1 fields are NUL/space padded)
Function TrimTag (S: String) : String;
Var
  L : LongInt;
Begin
  L := Length(S);
  While (L > 0) and ((S[L] = #0) or (S[L] = ' ')) Do Dec (L);
  TrimTag := Copy(S, 1, L);
End;

// read a big-endian value of N bytes (1..4) from a stream position
Function BEInt (Const B: Array of Byte; Ofs, N: LongInt) : LongInt;
Var
  I : LongInt;
  V : LongInt;
Begin
  V := 0;
  For I := 0 to N - 1 Do
    V := (V Shl 8) Or B[Ofs + I];
  BEInt := V;
End;

// -------------------------------------------------------------------
// ID3v1 - fixed 128-byte record at end of file
// -------------------------------------------------------------------

Const
  ID3v1Genres : Array[0..24] of String = (
    'Blues','Classic Rock','Country','Dance','Disco','Funk','Grunge',
    'Hip-Hop','Jazz','Metal','New Age','Oldies','Other','Pop','R&B',
    'Rap','Reggae','Rock','Techno','Industrial','Alternative','Ska',
    'Death Metal','Pranks','Soundtrack');

Function ReadID3v1 (Var F: File; Var Info: TMediaInfo) : Boolean;
Var
  Buf : Array[0..127] of Byte;
  Got : LongInt;
  S   : String;
  G   : Byte;
  I   : LongInt;

  Function Fld (Start, Len: LongInt) : String;
  Var J : LongInt; R : String;
  Begin
    R := '';
    For J := 0 to Len - 1 Do R := R + Chr(Buf[Start + J]);
    Fld := TrimTag(R);
  End;

Begin
  ReadID3v1 := False;

  If FileSize(F) < 128 Then Exit;

  Seek     (F, FileSize(F) - 128);
  BlockRead(F, Buf, 128, Got);
  If Got < 128 Then Exit;

  S := Chr(Buf[0]) + Chr(Buf[1]) + Chr(Buf[2]);
  If S <> 'TAG' Then Exit;

  // Only fill fields still blank (ID3v2 wins if it ran first)
  If Info.Title  = '' Then Info.Title  := Fld(3, 30);
  If Info.Artist = '' Then Info.Artist := Fld(33, 30);
  If Info.Album  = '' Then Info.Album  := Fld(63, 30);
  If Info.Year   = '' Then Info.Year   := Fld(93, 4);
  If Info.Comment= '' Then Info.Comment:= Fld(97, 30);

  If Info.Genre = '' Then Begin
    G := Buf[127];
    If G <= 24 Then Info.Genre := ID3v1Genres[G];
  End;

  ReadID3v1 := True;
End;

// -------------------------------------------------------------------
// ID3v2 - header at start of file, size is syncsafe (7 bits per byte)
// -------------------------------------------------------------------

Function SyncSafe (Const B: Array of Byte; Ofs: LongInt) : LongInt;
Begin
  SyncSafe := (B[Ofs] And $7F) Shl 21 Or (B[Ofs+1] And $7F) Shl 14 Or
              (B[Ofs+2] And $7F) Shl 7  Or (B[Ofs+3] And $7F);
End;

Function ReadID3v2 (Var F: File; Var Info: TMediaInfo) : Boolean;
Var
  Hdr   : Array[0..9] of Byte;
  Got   : LongInt;
  Major : Byte;
  TagSz : LongInt;
  Data  : Array of Byte;
  Pos   : LongInt;
  FrID  : String;
  FrSz  : LongInt;
  FrHdr : LongInt;       // frame header length (6 for 2.2, 10 for 2.3/2.4)
  IDLen : LongInt;       // frame id length (3 for 2.2, 4 for 2.3/2.4)
  Txt   : String;
  I     : LongInt;

  Function FrameText (Start, Len: LongInt) : String;
  Var J : LongInt; R : String; Enc : Byte;
  Begin
    R := '';
    If Len <= 1 Then Begin FrameText := ''; Exit; End;
    Enc := Data[Start];                       // first byte = text encoding
    // Read as raw bytes, skipping the encoding byte; treat as Latin-1/ASCII.
    // (UTF-16 frames will include NULs which TrimTag/printable-filter clean.)
    For J := Start + 1 to Start + Len - 1 Do
      If Data[J] >= 32 Then R := R + Chr(Data[J]);
    FrameText := TrimTag(R);
  End;

Begin
  ReadID3v2 := False;

  Seek     (F, 0);
  BlockRead(F, Hdr, 10, Got);
  If Got < 10 Then Exit;

  If (Chr(Hdr[0]) + Chr(Hdr[1]) + Chr(Hdr[2])) <> 'ID3' Then Exit;

  Major := Hdr[3];
  TagSz := SyncSafe(Hdr, 6);
  If (TagSz <= 0) or (TagSz > 8 * 1024 * 1024) Then Exit;   // sanity cap 8MB

  If Major = 2 Then Begin IDLen := 3; FrHdr := 6; End
               Else Begin IDLen := 4; FrHdr := 10; End;

  SetLength (Data, TagSz);
  BlockRead (F, Data[0], TagSz, Got);
  If Got < TagSz Then TagSz := Got;

  Pos := 0;
  While Pos + FrHdr <= TagSz Do Begin
    FrID := '';
    For I := 0 to IDLen - 1 Do FrID := FrID + Chr(Data[Pos + I]);
    If (FrID = '') or (Data[Pos] = 0) Then Break;           // padding

    If Major = 2 Then
      FrSz := BEInt(Data, Pos + 3, 3)
    Else
    If Major = 4 Then
      FrSz := SyncSafe(Data, Pos + 4)                        // 2.4 = syncsafe
    Else
      FrSz := BEInt(Data, Pos + 4, 4);                       // 2.3 = plain

    If (FrSz <= 0) or (Pos + FrHdr + FrSz > TagSz) Then Break;

    Txt := FrameText(Pos + FrHdr, FrSz);

    // map common frame IDs (2.2 uses 3-char, 2.3/2.4 use 4-char)
    If      (FrID = 'TT2') or (FrID = 'TIT2') Then Info.Title  := Txt
    Else If (FrID = 'TP1') or (FrID = 'TPE1') Then Info.Artist := Txt
    Else If (FrID = 'TAL') or (FrID = 'TALB') Then Info.Album  := Txt
    Else If (FrID = 'TYE') or (FrID = 'TYER') or (FrID = 'TDRC') Then Info.Year := Txt
    Else If (FrID = 'TCO') or (FrID = 'TCON') Then Info.Genre  := Txt
    Else If (FrID = 'COM') or (FrID = 'COMM') Then Info.Comment:= Txt;

    Pos := Pos + FrHdr + FrSz;
  End;

  ReadID3v2 := (Info.Title <> '') or (Info.Artist <> '') or (Info.Album <> '');
End;

// -------------------------------------------------------------------
// MP4 / M4A / MOV - ISO base media atom tree
// walk top-level atoms, descend into moov->udta->meta->ilst
// -------------------------------------------------------------------

Function ReadMP4 (Var F: File; Var Info: TMediaInfo) : Boolean;
Var
  FileLen : LongInt;
  Found   : Boolean;

  // read a 4-byte big-endian size and 4-char type at current position
  Procedure ReadAtomHdr (Var Sz: LongInt; Var Typ: String);
  Var B : Array[0..7] of Byte; Got : LongInt;
  Begin
    Sz := 0; Typ := '';
    BlockRead(F, B, 8, Got);
    If Got < 8 Then Exit;
    Sz  := (B[0] Shl 24) Or (B[1] Shl 16) Or (B[2] Shl 8) Or B[3];
    Typ := Chr(B[4]) + Chr(B[5]) + Chr(B[6]) + Chr(B[7]);
  End;

  // read text payload of an ilst 'data' atom into S
  Function ReadDataAtom (Limit: LongInt) : String;
  Var
    Sz  : LongInt; Typ : String; Got : LongInt;
    Buf : Array of Byte; I : LongInt; R : String;
  Begin
    R := '';
    ReadAtomHdr(Sz, Typ);
    If (Typ = 'data') and (Sz > 16) and (Sz <= Limit) Then Begin
      Seek(F, FilePos(F) + 8);              // skip 4 type-flags + 4 reserved
      SetLength(Buf, Sz - 16);
      BlockRead(F, Buf[0], Sz - 16, Got);
      For I := 0 to Got - 1 Do
        If Buf[I] >= 32 Then R := R + Chr(Buf[I]);
    End;
    ReadDataAtom := TrimTag(R);
  End;

  // read mvhd duration into Info.Duration
  Procedure Declare_mvhd (Body: LongInt);
  Var B : Array[0..19] of Byte; Got : LongInt; TS, Dur : LongInt;
  Begin
    Seek(F, Body);
    BlockRead(F, B, 20, Got);
    If Got < 20 Then Exit;
    TS  := (B[12] Shl 24) Or (B[13] Shl 16) Or (B[14] Shl 8) Or B[15];
    Dur := (B[16] Shl 24) Or (B[17] Shl 16) Or (B[18] Shl 8) Or B[19];
    If TS > 0 Then Info.Duration := Dur Div TS;
  End;

  // A52: read tkhd (track header) for video dimensions
  Procedure Read_tkhd (Body: LongInt);
  Var B : Array[0..83] of Byte; Got : LongInt; W, H : LongInt;
  Begin
    Seek(F, Body);
    BlockRead(F, B, 84, Got);
    If Got < 84 Then Exit;
    // v0: width @ 76 (fixed-point 16.16), height @ 80
    W := (B[76] Shl 8) Or B[77];
    H := (B[80] Shl 8) Or B[81];
    If (W > 0) and (H > 0) and (Info.VWidth = 0) Then Begin
      Info.VWidth  := W;
      Info.VHeight := H;
    End;
  End;

  // A52: read stsd (sample description) for codec FourCC + codec-specific data
  Procedure Read_stsd (Body, Len: LongInt);
  Var B : Array[0..79] of Byte; Got : LongInt; CC : String; SR : LongInt;
  Begin
    Seek(F, Body);
    BlockRead(F, B, 80, Got);
    If Got < 40 Then Exit;
    // B[0..3]=version+flags, B[4..7]=entry count; first entry at +8
    // Entry: B[8..11]=size, B[12..15]=FourCC
    CC := Chr(B[12]) + Chr(B[13]) + Chr(B[14]) + Chr(B[15]);
    // Video codecs
    If (CC = 'avc1') or (CC = 'avc3') or (CC = 'mp4v') or (CC = 'hvc1') or
       (CC = 'hev1') or (CC = 'av01') Then Begin
      If Info.VCodec = '' Then Begin
        Info.VCodec := CC;
        // Video entry: width @ 32, height @ 34 (from entry start at +8)
        If Got >= 44 Then Begin
          Info.VWidth  := (B[8+24] Shl 8) Or B[8+25];
          Info.VHeight := (B[8+26] Shl 8) Or B[8+27];
        End;
      End;
    End Else
    // Audio codecs
    If (CC = 'mp4a') or (CC = 'ac-3') or (CC = 'ec-3') or
       (CC = 'Opus') or (CC = 'fLaC') or (CC = 'alac') Then Begin
      If Info.ACodec = '' Then Begin
        Info.ACodec := CC;
        // Audio entry: channels @ 8+16, samplerate @ 8+24 (fixed 16.16)
        If Got >= 34 Then
          Info.AChannels := (B[8+16] Shl 8) Or B[8+17];
        If Got >= 42 Then Begin
          SR := (B[8+24] Shl 8) Or B[8+25];
          If SR > 0 Then Info.ASampleRate := SR;
        End;
      End;
    End;
  End;

  // recursively scan atoms within [Start, Start+Len) for containers/items
  Procedure Scan (Start, Len: LongInt; Depth: Integer);
  Var
    Cur : LongInt; Sz : LongInt; Typ : String; Body : LongInt; AtomKey : String;
  Begin
    If Depth > 10 Then Exit;
    Cur := Start;
    While Cur + 8 <= Start + Len Do Begin
      Seek(F, Cur);
      ReadAtomHdr(Sz, Typ);
      If Sz < 8 Then Break;
      If Cur + Sz > Start + Len Then Sz := (Start + Len) - Cur;
      Body := Cur + 8;

      If (Typ = 'moov') or (Typ = 'udta') or (Typ = 'ilst') or
         (Typ = 'trak') or (Typ = 'mdia') or (Typ = 'minf') or
         (Typ = 'stbl') Then
        Scan(Body, Sz - 8, Depth + 1)
      Else
      If Typ = 'meta' Then
        Scan(Body + 4, Sz - 12, Depth + 1)
      Else
      If Typ = 'mvhd' Then
        Declare_mvhd(Body)
      Else
      If Typ = 'tkhd' Then
        Read_tkhd(Body)
      Else
      If Typ = 'stsd' Then
        Read_stsd(Body, Sz - 8)
      Else
      If (Length(Typ) = 4) and (Typ[1] = #$A9) Then Begin
        // iTunes text atom: (c)nam/(c)ART/(c)alb/(c)day/(c)gen/(c)cmt
        Seek(F, Body);
        AtomKey := Copy(Typ, 2, 3);
        If      (AtomKey = 'nam') and (Info.Title   = '') Then Info.Title   := ReadDataAtom(Sz - 8)
        Else If (AtomKey = 'ART') and (Info.Artist  = '') Then Info.Artist  := ReadDataAtom(Sz - 8)
        Else If (AtomKey = 'alb') and (Info.Album   = '') Then Info.Album   := ReadDataAtom(Sz - 8)
        Else If (AtomKey = 'day') and (Info.Year    = '') Then Info.Year    := ReadDataAtom(Sz - 8)
        Else If (AtomKey = 'gen') and (Info.Genre   = '') Then Info.Genre   := ReadDataAtom(Sz - 8)
        Else If (AtomKey = 'cmt') and (Info.Comment = '') Then Info.Comment := ReadDataAtom(Sz - 8);
        Found := True;
      End;

      Cur := Cur + Sz;
    End;
  End;

Begin
  ReadMP4 := False;
  Found   := False;
  FileLen := FileSize(F);
  If FileLen < 16 Then Exit;

  Scan(0, FileLen, 0);

  ReadMP4 := Found or (Info.Title <> '') or (Info.Artist <> '');
End;

// -------------------------------------------------------------------
// public
// -------------------------------------------------------------------

Function IsMediaFile (FileName: String) : Boolean;
Var E : String;
Begin
  E := UpExt(FileName);
  IsMediaFile := (E = 'MP3') or (E = 'MP4') or (E = 'M4A') or
                 (E = 'M4V') or (E = 'MOV');
End;

Function ReadMediaTags (FileName: String; Var Info: TMediaInfo) : Boolean;
Var
  F   : File;
  E   : String;
  OM  : Byte;
Begin
  FillChar(Info, SizeOf(Info), 0);
  Info.Valid := False;
  Info.Kind  := '';
  ReadMediaTags := False;

  E := UpExt(FileName);

  Assign (F, FileName);
  OM := FileMode;
  FileMode := 0;                     // read-only open
  {$I-} Reset(F, 1); {$I+}
  FileMode := OM;
  If IOResult <> 0 Then Exit;

  If E = 'MP3' Then Begin
    Info.Kind := 'MP3';
    ReadID3v2(F, Info);              // preferred
    ReadID3v1(F, Info);              // fill any blanks
    Info.Valid := (Info.Title <> '') or (Info.Artist <> '') or
                  (Info.Album <> '') or (Info.Year <> '');
  End Else
  If (E = 'MP4') or (E = 'M4A') or (E = 'M4V') or (E = 'MOV') Then Begin
    Info.Kind := 'MP4';
    ReadMP4(F, Info);
    Info.Valid := (Info.Title <> '') or (Info.Artist <> '') or
                  (Info.Album <> '') or (Info.Duration > 0);
  End;

  Close (F);

  ReadMediaTags := Info.Valid;
End;

End.
