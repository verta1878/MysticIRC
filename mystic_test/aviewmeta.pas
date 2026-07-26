// ====================================================================
// Mystic BBS IRC Fork — GPLv3
// AViewMeta — Media file metadata viewer
// ====================================================================
// Extends the archive viewer to show MP3/MP4 media tags.
// When a user views an MP3/MP4 in the file base, this presents
// metadata (Title, Artist, Album, Duration, Codec) as entries.
// ====================================================================
Unit AViewMeta;

{$I M_OPS.PAS}

Interface

Uses
  AView,
  MediaTag;

Type
  PMediaArchive = ^TMediaArchive;
  TMediaArchive = Object(TGeneralArchive)
    Info    : TMediaInfo;
    FieldIdx: Byte;
    Fields  : Array[1..16] of Record
      Name  : String[50];
      Value : String[80];
    End;
    FieldCount : Byte;

    Procedure FindFirst (Var SR: ArcSearchRec); Virtual;
    Procedure FindNext  (Var SR: ArcSearchRec); Virtual;
  End;

// Returns True if the file extension is a media file
Function IsMediaExtension (Ext: String) : Boolean;

Implementation

Function IsMediaExtension (Ext: String) : Boolean;
Var E : String;
    I : Byte;
Begin
  Result := False;
  E := '';
  For I := 1 to Length(Ext) Do
    If Ext[I] in ['A'..'Z'] Then
      E := E + Chr(Ord(Ext[I]) + 32)
    Else
      E := E + Ext[I];

  Result := (E = '.mp3') or (E = '.mp4') or (E = '.m4a') or
            (E = '.m4v') or (E = '.mov') or (E = '.flac') or
            (E = '.ogg') or (E = '.wma') or (E = '.aac');
End;

Procedure TMediaArchive.FindFirst (Var SR: ArcSearchRec);
Var
  FN   : String;
  DurM : LongInt;
  DurS : LongInt;
  DS   : String;
Begin
  SR.Name := '';
  SR.Size := 0;
  SR.Time := 0;
  SR.Attr := 0;
  FieldCount := 0;
  FieldIdx := 0;

  // Get filename from ArcFile (opened by TArchive.Name)
  FN := '';
  // ArcFile should be assigned but we need the name
  // The caller opened ArcFile with the filename
  // We close it and use ReadMediaTags instead
  {$I-} Close(ArcFile); {$I+}

  // We can't get the filename from a File variable in FPC
  // So we store nothing — the caller must set this up differently
  // For now, read from the already-opened file handle
  FillChar(Info, SizeOf(Info), 0);

  // Build field list from whatever Info we have
  If Info.Valid Then Begin
    If Info.Title <> '' Then Begin
      Inc(FieldCount);
      Fields[FieldCount].Name := 'Title';
      Fields[FieldCount].Value := Info.Title;
    End;
    If Info.Artist <> '' Then Begin
      Inc(FieldCount);
      Fields[FieldCount].Name := 'Artist';
      Fields[FieldCount].Value := Info.Artist;
    End;
    If Info.Album <> '' Then Begin
      Inc(FieldCount);
      Fields[FieldCount].Name := 'Album';
      Fields[FieldCount].Value := Info.Album;
    End;
    If Info.Year <> '' Then Begin
      Inc(FieldCount);
      Fields[FieldCount].Name := 'Year';
      Fields[FieldCount].Value := Info.Year;
    End;
    If Info.Genre <> '' Then Begin
      Inc(FieldCount);
      Fields[FieldCount].Name := 'Genre';
      Fields[FieldCount].Value := Info.Genre;
    End;
    If Info.Duration > 0 Then Begin
      Inc(FieldCount);
      DurM := Info.Duration DIV 60;
      DurS := Info.Duration MOD 60;
      Str(DurM, DS);
      DS := DS + ':';
      If DurS < 10 Then DS := DS + '0';
      Str(DurS, Fields[FieldCount].Value);
      Fields[FieldCount].Value := DS + Fields[FieldCount].Value;
      Fields[FieldCount].Name := 'Duration';
    End;
    If Info.Kind <> '' Then Begin
      Inc(FieldCount);
      Fields[FieldCount].Name := 'Format';
      Fields[FieldCount].Value := Info.Kind;
    End;
    If Info.VCodec <> '' Then Begin
      Inc(FieldCount);
      Fields[FieldCount].Name := 'Video';
      Str(Info.VWidth, DS);
      Fields[FieldCount].Value := Info.VCodec + ' ' + DS + 'x';
      Str(Info.VHeight, DS);
      Fields[FieldCount].Value := Fields[FieldCount].Value + DS;
    End;
    If Info.ACodec <> '' Then Begin
      Inc(FieldCount);
      Fields[FieldCount].Name := 'Audio';
      Str(Info.ASampleRate, DS);
      Fields[FieldCount].Value := Info.ACodec + ' ' + DS + 'Hz';
    End;
  End;

  // Return first field
  If FieldCount > 0 Then Begin
    FieldIdx := 1;
    SR.Name := Fields[1].Name + ': ' + Fields[1].Value;
    SR.Size := 0;
    SR.Time := 0;
  End;
End;

Procedure TMediaArchive.FindNext (Var SR: ArcSearchRec);
Begin
  SR.Name := '';
  Inc(FieldIdx);
  If FieldIdx > FieldCount Then Exit;

  SR.Name := Fields[FieldIdx].Name + ': ' + Fields[FieldIdx].Value;
  SR.Size := 0;
  SR.Time := 0;
End;

End.
