Program MArc;

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
// MARC - Mystic ARChiver.
//
// A self-contained, pure-Pascal ZIP archiver so a sysop can add ONE
// entry to the Archive Editor that works on every Mystic target with
// no external tool installed.  It is driven exactly like any other
// archiver, so FidoNet bundling, QWK packets and FILE_ID.DIZ extraction
// all use it through Mystic's existing ExecuteArchive() path:
//
//   Pack   : marc a <archive.zip> <files...>
//   Unpack : marc x <archive.zip> [destdir]
//   View   : marc l <archive.zip>
//   Media  : marc m <mediafile>          (MP3/MP4 tag view, via MediaTag)
//
// Compression is ZIP (DEFLATE) via FPC's own zipper/paszlib units, so
// bundles are the de-facto FidoNet/QWK standard.  MARC never touches the
// FTS-0001 .pkt structure - Mystic builds those; MARC only compresses.
//
// Exit code 0 = success, 1 = error (matches typical archiver behaviour).
//
// ====================================================================

Uses
  SysUtils,
  Classes,
  Zipper,
  MediaTag;

Var
  ExitOK : Boolean = True;

// -------------------------------------------------------------------
Procedure Usage;
Begin
  WriteLn ('MARC : Mystic ARChiver (built-in ZIP, all platforms)');
  WriteLn;
  WriteLn ('  marc a <archive> <file...>   pack files into <archive> (ZIP)');
  WriteLn ('  marc x <archive> [destdir]   extract <archive> (to destdir)');
  WriteLn ('  marc l <archive>             list contents of <archive>');
  WriteLn ('  marc m <mediafile>           show MP3/MP4 media tags');
End;

// expand a simple *.ext or * mask in the current directory
Procedure AddMask (List: TStrings; Mask: String);
Var
  SR : TSearchRec;
  Dir: String;
Begin
  Dir := ExtractFilePath(Mask);
  If FindFirst(Mask, faAnyFile - faDirectory, SR) = 0 Then Begin
    Repeat
      List.Add(Dir + SR.Name);
    Until FindNext(SR) <> 0;
    FindClose(SR);
  End;
End;

// -------------------------------------------------------------------
// PACK : marc a <archive> <file|mask ...>
// -------------------------------------------------------------------
Procedure DoPack;
Var
  Z     : TZipper;
  Files : TStringList;
  I     : Integer;
  Arch  : String;
Begin
  If ParamCount < 3 Then Begin Usage; ExitOK := False; Exit; End;

  Arch  := ParamStr(2);
  Files := TStringList.Create;

  For I := 3 to ParamCount Do
    If (Pos('*', ParamStr(I)) > 0) or (Pos('?', ParamStr(I)) > 0) Then
      AddMask(Files, ParamStr(I))
    Else
      Files.Add(ParamStr(I));

  If Files.Count = 0 Then Begin
    WriteLn('MARC: nothing to pack');
    Files.Free;
    ExitOK := False;
    Exit;
  End;

  Z := TZipper.Create;
  Try
    Z.FileName := Arch;
    For I := 0 to Files.Count - 1 Do
      // store under the bare filename (archive-relative), as mail bundles expect
      Z.Entries.AddFileEntry(Files[I], ExtractFileName(Files[I]));
    Z.ZipAllFiles;
    WriteLn('MARC: packed ', Files.Count, ' file(s) into ', ExtractFileName(Arch));
  Except
    On E: Exception Do Begin
      WriteLn('MARC: pack error: ', E.Message);
      ExitOK := False;
    End;
  End;
  Z.Free;
  Files.Free;
End;

// -------------------------------------------------------------------
// UNPACK : marc x <archive> [destdir]
// -------------------------------------------------------------------
Procedure DoUnpack;
Var
  U    : TUnZipper;
  Arch : String;
  Dest : String;
Begin
  If ParamCount < 2 Then Begin Usage; ExitOK := False; Exit; End;

  Arch := ParamStr(2);
  If ParamCount >= 3 Then Dest := ParamStr(3) Else Dest := GetCurrentDir;

  If Not FileExists(Arch) Then Begin
    WriteLn('MARC: archive not found: ', Arch);
    ExitOK := False;
    Exit;
  End;

  U := TUnZipper.Create;
  Try
    U.FileName   := Arch;
    U.OutputPath := Dest;
    U.UnZipAllFiles;
    WriteLn('MARC: extracted ', ExtractFileName(Arch));
  Except
    On E: Exception Do Begin
      WriteLn('MARC: extract error: ', E.Message);
      ExitOK := False;
    End;
  End;
  U.Free;
End;

// -------------------------------------------------------------------
// LIST : marc l <archive>
// -------------------------------------------------------------------
Procedure DoList;
Var
  U    : TUnZipper;
  Arch : String;
  I    : Integer;
Begin
  If ParamCount < 2 Then Begin Usage; ExitOK := False; Exit; End;

  Arch := ParamStr(2);
  If Not FileExists(Arch) Then Begin
    WriteLn('MARC: archive not found: ', Arch);
    ExitOK := False;
    Exit;
  End;

  U := TUnZipper.Create;
  Try
    U.FileName := Arch;
    U.Examine;                          // read central directory only
    WriteLn('Archive: ', ExtractFileName(Arch));
    WriteLn('  Size        Name');
    WriteLn('  ----------  ------------------------------');
    For I := 0 to U.Entries.Count - 1 Do
      WriteLn('  ',
              U.Entries[I].Size:10, '  ',
              U.Entries[I].ArchiveFileName);
    WriteLn('  ', U.Entries.Count, ' file(s)');
  Except
    On E: Exception Do Begin
      WriteLn('MARC: list error: ', E.Message);
      ExitOK := False;
    End;
  End;
  U.Free;
End;

// -------------------------------------------------------------------
// MEDIA : marc m <mediafile>
// -------------------------------------------------------------------
Procedure DoMedia;
Var
  Info : TMediaInfo;
  FN   : String;
Begin
  If ParamCount < 2 Then Begin Usage; ExitOK := False; Exit; End;

  FN := ParamStr(2);
  If Not FileExists(FN) Then Begin
    WriteLn('MARC: file not found: ', FN);
    ExitOK := False;
    Exit;
  End;

  If ReadMediaTags(FN, Info) Then Begin
    WriteLn('Media : ', ExtractFileName(FN), '  (', Info.Kind, ')');
    If Info.Title    <> '' Then WriteLn('  Title   : ', Info.Title);
    If Info.Artist   <> '' Then WriteLn('  Artist  : ', Info.Artist);
    If Info.Album    <> '' Then WriteLn('  Album   : ', Info.Album);
    If Info.Year     <> '' Then WriteLn('  Year    : ', Info.Year);
    If Info.Genre    <> '' Then WriteLn('  Genre   : ', Info.Genre);
    If Info.Comment  <> '' Then WriteLn('  Comment : ', Info.Comment);
    If Info.Duration >  0  Then WriteLn('  Length  : ', Info.Duration, ' sec');
    If Info.VCodec   <> '' Then WriteLn('  Video   : ', Info.VCodec, '  ', Info.VWidth, 'x', Info.VHeight);
    If Info.ACodec   <> '' Then Begin
      Write('  Audio   : ', Info.ACodec);
      If Info.ASampleRate > 0 Then Write('  ', Info.ASampleRate, ' Hz');
      If Info.AChannels > 0 Then Write('  ', Info.AChannels, 'ch');
      WriteLn;
    End;
  End Else Begin
    WriteLn('MARC: no readable media tags in ', ExtractFileName(FN));
    ExitOK := False;
  End;
End;

// -------------------------------------------------------------------
Var
  Cmd : String;
Begin
  If ParamCount < 1 Then Begin
    Usage;
    Halt(1);
  End;

  Cmd := UpperCase(ParamStr(1));

  If      Cmd = 'A' Then DoPack
  Else If Cmd = 'X' Then DoUnpack
  Else If Cmd = 'L' Then DoList
  Else If Cmd = 'M' Then DoMedia
  Else Begin
    WriteLn('MARC: unknown command "', ParamStr(1), '"');
    Usage;
    ExitOK := False;
  End;

  If Not ExitOK Then Halt(1);
End.
