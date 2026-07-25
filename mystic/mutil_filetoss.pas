// ====================================================================
// Mystic BBS Software               Copyright 2026 by Antonio Rico
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ====================================================================
//
// mutil_filetoss — TIC/FDN file tosser for Mystic BBS
//
// Implements the TIC file format per FTS-5006.001 (FTSC) and
// FSC-0087.001 (File Forwarding in FidoNet Technology Networks).
//
// Scans the inbound directory for .TIC files, parses them, verifies
// CRC-32, matches Area tags to file bases, imports files with
// descriptions, and forwards to downlinks.
//
// mutil.ini section: [ImportFileToss]
//   process         = true
//   unsecure_dir    = false    ; also scan UnsecurePath
//   auto_create     = false    ; create bases for unknown area tags
//   delete_tic      = true     ; delete .TIC after processing
//   bad_dir         =          ; directory for failed files (optional)
//
// ====================================================================

Unit MUTIL_FileToss;

{$I M_OPS.PAS}

Interface

Procedure uFileToss;

Implementation

Uses
  DOS,
  m_FileIO,
  m_Strings,
  m_DateTime,
  m_CRC,
  BBS_Records,
  BBS_Common,
  BBS_DataBase,
  mutil_Common;

Const
  Header_FILETOSS = 'ImportFileToss';

Type
  // Parsed TIC file contents per FTS-5006.001
  TTicData = Record
    Area      : String[40];
    AreaDesc  : String[60];
    Origin    : RecEchoMailAddr;
    FromAddr  : RecEchoMailAddr;
    ToAddr    : RecEchoMailAddr;
    FileName  : String[70];
    LongName  : String[70];
    Size      : LongInt;
    FileDate  : LongInt;
    Desc      : String[160];
    LDesc     : String;
    Magic     : String[40];
    Replaces  : String[70];
    CRC       : LongInt;
    HasCRC    : Boolean;
    Password  : String[20];
    Created   : String[80];
    Path      : String;        // accumulated PATH lines
    SeenBy    : String;        // accumulated SEENBY lines
    Valid     : Boolean;
  End;

// Parse a FTN address string (Z:N/N.P) into a RecEchoMailAddr
Procedure ParseAddr (Str: String; Var Addr: RecEchoMailAddr);
Var
  P : Byte;
Begin
  FillChar(Addr, SizeOf(Addr), 0);

  // Zone
  P := Pos(':', Str);
  If P > 0 Then Begin
    Addr.Zone := strS2I(Copy(Str, 1, P - 1));
    Delete(Str, 1, P);
  End;

  // Net/Node
  P := Pos('/', Str);
  If P > 0 Then Begin
    Addr.Net := strS2I(Copy(Str, 1, P - 1));
    Delete(Str, 1, P);
  End;

  // Point
  P := Pos('.', Str);
  If P > 0 Then Begin
    Addr.Node  := strS2I(Copy(Str, 1, P - 1));
    Addr.Point := strS2I(Copy(Str, P + 1, 255));
  End Else
    Addr.Node := strS2I(Str);
End;

// Format a RecEchoMailAddr as Z:N/N.P string
Function Addr2Str (Addr: RecEchoMailAddr) : String;
Begin
  Result := strI2S(Addr.Zone) + ':' + strI2S(Addr.Net) + '/' + strI2S(Addr.Node);
  If Addr.Point <> 0 Then
    Result := Result + '.' + strI2S(Addr.Point);
End;

// Parse a .TIC file per FTS-5006.001
Function ParseTIC (TicFile: String; Var TIC: TTicData) : Boolean;
Var
  TF      : Text;
  Line    : String;
  Keyword : String;
  Value   : String;
  P       : Byte;
Begin
  Result := False;

  FillChar(TIC, SizeOf(TIC), 0);
  TIC.LDesc  := '';
  TIC.Path   := '';
  TIC.SeenBy := '';
  TIC.Valid  := False;

  Assign (TF, TicFile);
  {$I-} Reset(TF); {$I+}
  If IoResult <> 0 Then Exit;

  While Not Eof(TF) Do Begin
    ReadLn(TF, Line);

    Line := strStripB(Line, ' ');
    If Line = '' Then Continue;

    P := Pos(' ', Line);
    If P = 0 Then Begin
      Keyword := strUpper(Line);
      Value   := '';
    End Else Begin
      Keyword := strUpper(Copy(Line, 1, P - 1));
      Value   := strStripL(Copy(Line, P + 1, 255), ' ');
    End;

    If Keyword = 'AREA'     Then TIC.Area     := Value
    Else
    If Keyword = 'AREADESC' Then TIC.AreaDesc  := Value
    Else
    If Keyword = 'ORIGIN'   Then ParseAddr(Value, TIC.Origin)
    Else
    If Keyword = 'FROM'     Then ParseAddr(Value, TIC.FromAddr)
    Else
    If Keyword = 'TO'       Then ParseAddr(Value, TIC.ToAddr)
    Else
    If Keyword = 'FILE'     Then TIC.FileName  := Value
    Else
    If (Keyword = 'LFILE') or (Keyword = 'FULLNAME') Then
      TIC.LongName := Value
    Else
    If Keyword = 'SIZE'     Then TIC.Size      := strS2I(Value)
    Else
    If Keyword = 'DATE'     Then TIC.FileDate  := strS2I(Value)
    Else
    If Keyword = 'DESC'     Then TIC.Desc      := Value
    Else
    If Keyword = 'LDESC'    Then Begin
      If TIC.LDesc <> '' Then TIC.LDesc := TIC.LDesc + #13#10;
      TIC.LDesc := TIC.LDesc + Value;
    End
    Else
    If Keyword = 'MAGIC'    Then TIC.Magic     := Value
    Else
    If Keyword = 'REPLACES' Then TIC.Replaces  := Value
    Else
    If Keyword = 'CRC'      Then Begin
      TIC.CRC    := strH2I(Value);
      TIC.HasCRC := True;
    End
    Else
    If Keyword = 'PW'       Then TIC.Password  := Value
    Else
    If Keyword = 'CREATED'  Then TIC.Created   := Value
    Else
    If Keyword = 'PATH'     Then Begin
      If TIC.Path <> '' Then TIC.Path := TIC.Path + #13#10;
      TIC.Path := TIC.Path + Value;
    End
    Else
    If Keyword = 'SEENBY'   Then Begin
      If TIC.SeenBy <> '' Then TIC.SeenBy := TIC.SeenBy + #13#10;
      TIC.SeenBy := TIC.SeenBy + Value;
    End;
    // FTS-5006.001: unknown keywords should be passed through (logged)
  End;

  Close(TF);

  // Validate required fields
  TIC.Valid := (TIC.Area <> '') and (TIC.FileName <> '') and
               (TIC.Origin.Zone <> 0) and (TIC.FromAddr.Zone <> 0);

  Result := TIC.Valid;
End;

// Find a file base by its EchoTag
Function FindBaseByTag (Tag: String; Var FBase: RecFileBase) : Boolean;
Var
  FBaseFile : File of RecFileBase;
Begin
  Result := False;

  Assign (FBaseFile, bbsCfg.DataPath + 'fbases.dat');
  {$I-} Reset(FBaseFile); {$I+}
  If IoResult <> 0 Then Exit;

  While Not Eof(FBaseFile) Do Begin
    Read (FBaseFile, FBase);

    If strUpper(FBase.EchoTag) = strUpper(Tag) Then Begin
      Result := True;
      Break;
    End;
  End;

  Close(FBaseFile);
End;

// Import a file into a file base directory listing
Function ImportFile (Var FBase: RecFileBase; Var TIC: TTicData;
                     SrcPath: String) : Boolean;
Var
  FDir     : RecFileList;
  FDirFile : File of RecFileList;
  FDescF   : File;
  DescStr  : String;
  DescLen  : Byte;
  DestFile : String;
Begin
  Result := False;

  // Determine actual filename
  If TIC.LongName <> '' Then
    DestFile := TIC.LongName
  Else
    DestFile := TIC.FileName;

  // Move file to the base directory
  // A4-02: Handle REPLACES — remove old file before copying new one
  If TIC.Replaces <> '' Then Begin
    If FileExist(DirLast(FBase.Path) + TIC.Replaces) Then Begin
      Log(3, '+', '   Replacing ' + TIC.Replaces + ' with ' + DestFile);
      FileErase(DirLast(FBase.Path) + TIC.Replaces);
    End;
  End;

  // Check if destination already exists (prevent false duplicate)
  If FileExist(DirLast(FBase.Path) + DestFile) Then Begin
    Log(3, '+', '   Overwriting existing ' + DestFile);
    FileErase(DirLast(FBase.Path) + DestFile);
  End;

  If Not FileCopy(SrcPath + TIC.FileName, DirLast(FBase.Path) + DestFile) Then Begin
    Log(1, '!', '   Cannot copy ' + TIC.FileName + ' to ' + FBase.Path);
    Exit;
  End;

  FileErase(SrcPath + TIC.FileName);

  // Build directory entry
  FillChar(FDir, SizeOf(FDir), 0);
  FDir.FileName  := DestFile;
  FDir.Size      := FileByteSize(DirLast(FBase.Path) + DestFile);
  FDir.DateTime  := CurDateDos;
  FDir.Uploader  := 'FileToss';
  FDir.Flags     := 0;
  FDir.Downloads := 0;
  FDir.Rating    := 0;

  // Write description to .DES file
  DescStr := TIC.Desc;
  If DescStr = '' Then DescStr := TIC.FileName;

  Assign (FDescF, bbsCfg.DataPath + FBase.FileName + '.des');
  {$I-} Reset(FDescF, 1); {$I+}
  If IoResult <> 0 Then ReWrite(FDescF, 1);

  Seek (FDescF, FileSize(FDescF));
  FDir.DescPtr   := FilePos(FDescF);
  FDir.DescLines := 1;

  DescLen := Length(DescStr);
  BlockWrite(FDescF, DescLen, 1);
  BlockWrite(FDescF, DescStr[1], DescLen);
  Close(FDescF);

  // Append to .DIR file
  Assign (FDirFile, bbsCfg.DataPath + FBase.FileName + '.dir');
  {$I-} Reset(FDirFile); {$I+}
  If IoResult <> 0 Then ReWrite(FDirFile);

  Seek (FDirFile, FileSize(FDirFile));
  Write(FDirFile, FDir);
  Close(FDirFile);

  Result := True;
End;

// Create a TIC file for forwarding to a downlink
Procedure ForwardTIC (Var TIC: TTicData; Var FBase: RecFileBase;
                      DestAddr: RecEchoMailAddr; OutPath: String);
Var
  TF     : Text;
  TicFN  : String;
Begin
  // Generate unique TIC filename
  TicFN := OutPath + Copy(strI2H(Random($FFFF), 4), 1, 4) +
           Copy(strI2H(Random($FFFF), 4), 1, 4) + '.TIC';

  Assign(TF, TicFN);
  {$I-} ReWrite(TF); {$I+}
  If IoResult <> 0 Then Exit;

  WriteLn(TF, 'Area ' + TIC.Area);
  WriteLn(TF, 'Origin ' + Addr2Str(TIC.Origin));
  WriteLn(TF, 'From ' + Addr2Str(bbsCfg.NetAddress[FBase.NetAddr]));
  WriteLn(TF, 'To ' + Addr2Str(DestAddr));
  WriteLn(TF, 'File ' + TIC.FileName);

  If TIC.LongName <> '' Then
    WriteLn(TF, 'Lfile ' + TIC.LongName);

  WriteLn(TF, 'Size ' + strI2S(TIC.Size));

  If TIC.Desc <> '' Then
    WriteLn(TF, 'Desc ' + TIC.Desc);

  If TIC.HasCRC Then
    WriteLn(TF, 'Crc ' + strI2H(TIC.CRC, 8));

  WriteLn(TF, 'Created by Mystic BBS ' + mysVersion);

  // Pass through PATH and add ourselves
  If TIC.Path <> '' Then
    WriteLn(TF, 'Path ' + TIC.Path);
  WriteLn(TF, 'Path ' + Addr2Str(bbsCfg.NetAddress[FBase.NetAddr]) + ' ' +
          strI2S(DateDos2Unix(CurDateDos)));

  // SEENBY: pass through existing + add ourselves + destination
  If TIC.SeenBy <> '' Then
    WriteLn(TF, 'Seenby ' + TIC.SeenBy);
  WriteLn(TF, 'Seenby ' + Addr2Str(bbsCfg.NetAddress[FBase.NetAddr]));
  WriteLn(TF, 'Seenby ' + Addr2Str(DestAddr));

  Close(TF);

  // Copy the file to the outbound for this node
  FileCopy(DirLast(FBase.Path) + TIC.FileName, OutPath + TIC.FileName);
End;

// Forward file to downlinks that are linked to this file base
Procedure TossToDownlinks (Var TIC: TTicData; Var FBase: RecFileBase);
Var
  LinkFile : File of RecEchoMailExport;
  LinkIdx  : RecEchoMailExport;
  NodeFile : File of RecEchoMailNode;
  EchoNode : RecEchoMailNode;
  OutPath  : String;
Begin
  Assign (LinkFile, bbsCfg.DataPath + FBase.FileName + '.lnk');
  {$I-} Reset(LinkFile); {$I+}
  If IoResult <> 0 Then Exit;

  Assign (NodeFile, bbsCfg.DataPath + 'echonode.dat');
  {$I-} Reset(NodeFile); {$I+}
  If IoResult <> 0 Then Begin
    Close(LinkFile);
    Exit;
  End;

  While Not Eof(LinkFile) Do Begin
    Read(LinkFile, LinkIdx);

    // Find the node record
    Seek(NodeFile, 0);
    While Not Eof(NodeFile) Do Begin
      Read(NodeFile, EchoNode);

      If EchoNode.Index = LinkIdx Then Begin
        // Don't send back to the sender
        If (EchoNode.Address.Zone = TIC.FromAddr.Zone) and
           (EchoNode.Address.Net  = TIC.FromAddr.Net) and
           (EchoNode.Address.Node = TIC.FromAddr.Node) Then Continue;

        OutPath := DirLast(bbsCfg.OutboundPath);
        DirCreate(OutPath);
        ForwardTIC(TIC, FBase, EchoNode.Address, OutPath);

        Log(3, '+', '   Forward to ' + Addr2Str(EchoNode.Address));
        Break;
      End;
    End;
  End;

  Close(NodeFile);
  Close(LinkFile);
End;

// Main file toss procedure
Procedure uFileToss;
Var
  DirInfo      : SearchRec;
  TIC          : TTicData;
  FBase        : RecFileBase;
  SrcPath      : String;
  TicPath      : String;
  BadDir       : String;
  DeleteTIC    : Boolean;
  AutoCreate   : Boolean;
  UnsecureToss : Boolean;
  FileCRC      : LongInt;
  TotalTossed  : LongInt;
  TotalFailed  : LongInt;
  FBaseFile    : File of RecFileBase;

  Procedure ScanDirectory (Path: String);
  Begin
    SrcPath := DirLast(Path);

    FindFirst(SrcPath + '*.tic', AnyFile, DirInfo);
    While DosError = 0 Do Begin
      TicPath := SrcPath + DirInfo.Name;

      Log(2, '+', '  Processing ' + DirInfo.Name);

      If Not ParseTIC(TicPath, TIC) Then Begin
        Log(1, '!', '   Invalid TIC file: ' + DirInfo.Name);
        Inc(TotalFailed);
        FindNext(DirInfo);
        Continue;
      End;

      Log(3, '+', '   Area: ' + TIC.Area + '  File: ' + TIC.FileName +
          '  From: ' + Addr2Str(TIC.FromAddr));

      // Verify the file exists in inbound
      If Not FileExist(SrcPath + TIC.FileName) Then Begin
        Log(1, '!', '   File not found: ' + TIC.FileName);
        Inc(TotalFailed);
        FindNext(DirInfo);
        Continue;
      End;

      // Verify CRC-32 if present (FTS-5006.001 §2.3)
      If TIC.HasCRC Then Begin
        FileCRC := FileCRC32(SrcPath + TIC.FileName);
        If FileCRC <> TIC.CRC Then Begin
          Log(1, '!', '   CRC mismatch: expected ' + strI2H(TIC.CRC, 8) +
              ' got ' + strI2H(FileCRC, 8));

          If BadDir <> '' Then Begin
            FileCopy(SrcPath + TIC.FileName, DirLast(BadDir) + TIC.FileName);
            FileCopy(TicPath, DirLast(BadDir) + DirInfo.Name);
          End;

          Inc(TotalFailed);
          FindNext(DirInfo);
          Continue;
        End;
      End;

      // Find the file base matching the area tag
      If Not FindBaseByTag(TIC.Area, FBase) Then Begin
        // A52: auto_create — create a new file base for unknown area tags
        If AutoCreate Then Begin
          Log(2, '+', '   Auto-creating file base for area: ' + TIC.Area);

          FillChar(FBase, SizeOf(FBase), 0);

          If TIC.AreaDesc <> '' Then
            FBase.Name := TIC.AreaDesc
          Else
            FBase.Name := TIC.Area;

          FBase.EchoTag  := TIC.Area;
          FBase.FileName := 'fecho_' + Copy(TIC.Area, 1, 30);
          FBase.Path     := DirLast(bbsCfg.DataPath) + 'fecho' + PathChar + TIC.Area + PathChar;
          FBase.Created  := CurDateDos;

          DirCreate(FBase.Path);

          // Append to fbases.dat and get the index
          Assign(FBaseFile, bbsCfg.DataPath + 'fbases.dat');
          {$I-} Reset(FBaseFile); {$I+}
          If IoResult <> 0 Then ReWrite(FBaseFile);
          FBase.Index := FileSize(FBaseFile);
          Seek(FBaseFile, FBase.Index);
          Write(FBaseFile, FBase);
          Close(FBaseFile);
        End Else Begin
          Log(2, '!', '   No file base for area: ' + TIC.Area);

          If BadDir <> '' Then Begin
            FileCopy(SrcPath + TIC.FileName, DirLast(BadDir) + TIC.FileName);
            FileCopy(TicPath, DirLast(BadDir) + DirInfo.Name);
          End;

          Inc(TotalFailed);
          FindNext(DirInfo);
          Continue;
        End;
      End;

      // Import the file into the base
      If ImportFile(FBase, TIC, SrcPath) Then Begin
        Log(2, '+', '   Tossed ' + TIC.FileName + ' to ' + strStripPipe(FBase.Name));
        Inc(TotalTossed);

        // Forward to downlinks
        TossToDownlinks(TIC, FBase);
      End Else Begin
        Log(1, '!', '   Failed to import ' + TIC.FileName);
        Inc(TotalFailed);
      End;

      // Delete TIC file
      If DeleteTIC Then FileErase(TicPath);

      FindNext(DirInfo);
    End;

    FindClose(DirInfo);
  End;

Begin
  Log(1, '+', 'Processing file tosser');

  TotalTossed  := 0;
  TotalFailed  := 0;
  DeleteTIC    := INI.ReadBoolean(Header_FILETOSS, 'delete_tic', True);
  AutoCreate   := INI.ReadBoolean(Header_FILETOSS, 'auto_create', False);
  UnsecureToss := INI.ReadBoolean(Header_FILETOSS, 'unsecure_dir', False);
  BadDir       := INI.ReadString (Header_FILETOSS, 'bad_dir', '');

  If BadDir <> '' Then DirCreate(BadDir);

  // Scan the secure inbound directory
  ScanDirectory(bbsCfg.InboundPath);

  // A52: also scan the unsecure inbound directory if enabled
  If UnsecureToss and (bbsCfg.UnsecurePath <> '') Then
    ScanDirectory(bbsCfg.UnsecurePath);

  Log(1, '+', 'File tosser complete: ' + strI2S(TotalTossed) + ' tossed, ' +
      strI2S(TotalFailed) + ' failed');
End;

End.
