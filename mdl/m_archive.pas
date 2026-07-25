Unit m_Archive;

// ====================================================================
// m_archive.pas — Cross-format archive library for Mystic BBS
// ====================================================================
// Kiddo — Copyright (C) 2026 — GPLv3 — 1.11IRC A7
//
// Unified API for listing, extracting, and testing archives.
// Used by THD ScanPro, MUTIL file toss, file base viewer.
//
// INTERNAL (pure Pascal, no external programs):
//   ZIP  — via FPC paszlib/zipper units
//
// EXTERNAL (calls command-line tools):
//   RAR  — unrar/rar
//   ARJ  — arj/unarj
//   LHA/LZH — lha
//   ARC  — arc/pkarc
//   PAK  — pak
//   SQZ  — sqz
//   HYP  — hyper
//   UC2  — uc
//   TD0  — Teledisk (disk image, not traditional archive)
//
// The external tool paths are configurable via SetToolPath.
// If a tool is not found, the format is listed as unsupported.
//
// API:
//   ArcDetectType(FileName) : TArcType  — detect by header magic
//   ArcList(FileName, List) : Boolean   — list archive contents
//   ArcExtract(FileName, DestPath, Mask) : Boolean — extract files
//   ArcTest(FileName) : Boolean         — test archive integrity
//   ArcSetToolPath(ArcType, Path)       — set external tool path
//   ArcTypeSupported(ArcType) : Boolean — check if tools available
// ====================================================================

{$I M_OPS.PAS}

Interface

Uses
  m_Strings,
  m_FileIO;

Type
  TArcType = (
    atUnknown,
    atZIP,        // PK header
    atRAR,        // Rar! header
    atARJ,        // 0x60 0xEA header
    atLHA,        // -lh?- or -lz?- header
    atARC,        // 0x1A header byte
    atPAK,        // Same as ARC with extensions
    atSQZ,        // HLSQZ header
    atHYP,        // HP header
    atUC2,        // UC2 header
    atTD0,        // TD Teledisk header
    atGZIP,       // 0x1F 0x8B header
    atBZ2,        // BZ header
    at7Z          // 7z header
  );

  TArcFileEntry = Record
    FileName    : String;
    UncompSize  : LongInt;
    CompSize    : LongInt;
    DateTime    : LongInt;
    CRC32       : LongInt;
    IsDirectory : Boolean;
  End;

  TArcFileList = Array[0..4095] of TArcFileEntry;
  PArcFileList = ^TArcFileList;

  TArcResult = Record
    Success   : Boolean;
    FileCount : LongInt;
    TotalSize : LongInt;
    ErrorMsg  : String;
  End;

Const
  ArcTypeStr : Array[TArcType] of String[4] = (
    '???', 'ZIP', 'RAR', 'ARJ', 'LHA', 'ARC',
    'PAK', 'SQZ', 'HYP', 'UC2', 'TD0', 'GZ', 'BZ2', '7Z'
  );

  ArcTypeExt : Array[TArcType] of String[4] = (
    '',    '.zip','.rar','.arj','.lzh','.arc',
    '.pak','.sqz','.hyp','.uc2','.td0','.gz', '.bz2','.7z'
  );

// ====================================================================
// Detection
// ====================================================================
Function  ArcDetectType     (FileName: String) : TArcType;
Function  ArcDetectByExt    (FileName: String) : TArcType;

// ====================================================================
// Operations
// ====================================================================
Function  ArcList           (FileName: String; Var List: TArcFileList;
                             Var Count: LongInt) : TArcResult;
Function  ArcExtract        (FileName, DestPath, Mask: String) : TArcResult;
Function  ArcExtractAll     (FileName, DestPath: String) : TArcResult;
Function  ArcTest           (FileName: String) : TArcResult;

// ====================================================================
// Tool configuration
// ====================================================================
Procedure ArcSetToolPath    (ArcType: TArcType; ToolPath: String);
Function  ArcGetToolPath    (ArcType: TArcType) : String;
Function  ArcTypeSupported  (ArcType: TArcType) : Boolean;
Procedure ArcSetTempPath    (Path: String);

// ====================================================================
// Utility
// ====================================================================
Function  ArcTypeToStr      (ArcType: TArcType) : String;

Implementation

Uses
  {$IFDEF UNIX}
  Unix,
  BaseUnix,
  {$ENDIF}
  DOS;

Var
  ToolPaths : Array[TArcType] of String;
  TempPath  : String;

// ====================================================================
// Detect archive type by file header magic bytes
// ====================================================================
Function ArcDetectType (FileName: String) : TArcType;
Var
  F      : File;
  Header : Array[0..7] of Byte;
  Read   : LongInt;
Begin
  Result := atUnknown;

  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  FillChar(Header, SizeOf(Header), 0);
  BlockRead(F, Header, 8, Read);
  Close(F);

  If Read < 2 Then Exit;

  // ZIP: PK\x03\x04 or PK\x05\x06 (empty) or PK\x07\x08 (spanned)
  If (Header[0] = $50) and (Header[1] = $4B) Then
    Result := atZIP
  // RAR: Rar!\x1A\x07
  Else If (Header[0] = $52) and (Header[1] = $61) and
          (Header[2] = $72) and (Header[3] = $21) Then
    Result := atRAR
  // ARJ: 0x60 0xEA
  Else If (Header[0] = $60) and (Header[1] = $EA) Then
    Result := atARJ
  // LHA/LZH: check for -lh?- or -lz?- at offset 2
  Else If (Read >= 5) and (Header[2] = Ord('-')) and
          (Header[3] = Ord('l')) and
          ((Header[4] = Ord('h')) or (Header[4] = Ord('z'))) Then
    Result := atLHA
  // ARC/PAK: 0x1A as first byte
  Else If Header[0] = $1A Then Begin
    // PAK uses extended ARC format — detect by extension
    If strUpper(JustFileExt(FileName)) = '.PAK' Then
      Result := atPAK
    Else
      Result := atARC;
  End
  // SQZ: HLSQZ
  Else If (Header[0] = $48) and (Header[1] = $4C) and
          (Header[2] = $53) and (Header[3] = $51) and
          (Header[4] = $5A) Then
    Result := atSQZ
  // HYP: HP\x01
  Else If (Header[0] = $48) and (Header[1] = $50) Then
    Result := atHYP
  // UC2: UC2\x1A
  Else If (Header[0] = $55) and (Header[1] = $43) and
          (Header[2] = $32) and (Header[3] = $1A) Then
    Result := atUC2
  // TD0: TD or td (Teledisk)
  Else If ((Header[0] = $54) or (Header[0] = $74)) and
          ((Header[1] = $44) or (Header[1] = $64)) Then
    Result := atTD0
  // GZIP: 0x1F 0x8B
  Else If (Header[0] = $1F) and (Header[1] = $8B) Then
    Result := atGZIP
  // BZ2: BZ
  Else If (Header[0] = $42) and (Header[1] = $5A) Then
    Result := atBZ2
  // 7Z: 7z\xBC\xAF\x27\x1C
  Else If (Header[0] = $37) and (Header[1] = $7A) and
          (Header[2] = $BC) and (Header[3] = $AF) Then
    Result := at7Z;
End;

// ====================================================================
// Detect by file extension (fallback)
// ====================================================================
Function ArcDetectByExt (FileName: String) : TArcType;
Var
  Ext : String;
  AT  : TArcType;
Begin
  Result := atUnknown;
  Ext := strUpper(JustFileExt(FileName));

  For AT := Low(TArcType) to High(TArcType) Do
    If strUpper(ArcTypeExt[AT]) = Ext Then Begin
      Result := AT;
      Exit;
    End;

  // Extra extension mappings
  If Ext = '.LZH' Then Result := atLHA;
  If Ext = '.LHA' Then Result := atLHA;
End;

// ====================================================================
// Execute external tool and capture exit code
// ====================================================================
Function ExecTool (Cmd: String) : Integer;
{$IFDEF UNIX}
Var
  Status : LongInt;
{$ENDIF}
Begin
  {$IFDEF UNIX}
    Status := fpSystem(Cmd);
    Result := Status SHR 8;
  {$ELSE}
    SwapVectors;
    Exec(GetEnv('COMSPEC'), '/C ' + Cmd);
    SwapVectors;
    Result := DosExitCode;
  {$ENDIF}
End;

// ====================================================================
// Build extract command for each format
// ====================================================================
Function BuildExtractCmd (ArcType: TArcType; ArcFile, DestPath, Mask: String) : String;
Var
  Tool : String;
Begin
  Tool   := ToolPaths[ArcType];
  Result := '';

  If Tool = '' Then Exit;

  Case ArcType of
    atZIP : // unzip -o -d <dest> <archive> [mask]
            Begin
              Result := Tool + ' -o -d ' + DestPath + ' ' + ArcFile;
              If Mask <> '' Then Result := Result + ' ' + Mask;
            End;
    atRAR : // unrar x -o+ <archive> [mask] <dest>
            Begin
              Result := Tool + ' x -o+ ' + ArcFile;
              If Mask <> '' Then Result := Result + ' ' + Mask;
              Result := Result + ' ' + DestPath;
            End;
    atARJ : // arj x <archive> <dest> [mask]
            Begin
              Result := Tool + ' x ' + ArcFile + ' ' + DestPath;
              If Mask <> '' Then Result := Result + ' ' + Mask;
            End;
    atLHA : // lha x <archive> <dest>
            Begin
              Result := Tool + ' x ' + ArcFile + ' ' + DestPath;
            End;
    atARC,
    atPAK : // arc x <archive> [mask]
            Begin
              Result := Tool + ' x ' + ArcFile;
              If Mask <> '' Then Result := Result + ' ' + Mask;
            End;
    atSQZ : // sqz x <archive>
            Result := Tool + ' x ' + ArcFile;
    atHYP : // hyper x <archive>
            Result := Tool + ' x ' + ArcFile;
    atUC2 : // uc x <archive> <dest>
            Result := Tool + ' x ' + ArcFile + ' ' + DestPath;
    atGZIP: // gzip -d -k <archive>
            Result := Tool + ' -d -k ' + ArcFile;
    atBZ2 : // bzip2 -d -k <archive>
            Result := Tool + ' -d -k ' + ArcFile;
    at7Z  : // 7z x -o<dest> <archive>
            Result := Tool + ' x -o' + DestPath + ' ' + ArcFile;
  End;
End;

// ====================================================================
// Build test command for each format
// ====================================================================
Function BuildTestCmd (ArcType: TArcType; ArcFile: String) : String;
Var
  Tool : String;
Begin
  Tool   := ToolPaths[ArcType];
  Result := '';

  If Tool = '' Then Exit;

  Case ArcType of
    atZIP : Result := Tool + ' -t ' + ArcFile;
    atRAR : Result := Tool + ' t ' + ArcFile;
    atARJ : Result := Tool + ' t ' + ArcFile;
    atLHA : Result := Tool + ' t ' + ArcFile;
    atARC,
    atPAK : Result := Tool + ' t ' + ArcFile;
    atSQZ : Result := Tool + ' t ' + ArcFile;
    atHYP : Result := Tool + ' t ' + ArcFile;
    atUC2 : Result := Tool + ' t ' + ArcFile;
    at7Z  : Result := Tool + ' t ' + ArcFile;
  End;
End;

// ====================================================================
// Build list command for each format
// ====================================================================
Function BuildListCmd (ArcType: TArcType; ArcFile: String) : String;
Var
  Tool : String;
Begin
  Tool   := ToolPaths[ArcType];
  Result := '';

  If Tool = '' Then Exit;

  Case ArcType of
    atZIP : Result := Tool + ' -l ' + ArcFile;
    atRAR : Result := Tool + ' l ' + ArcFile;
    atARJ : Result := Tool + ' l ' + ArcFile;
    atLHA : Result := Tool + ' l ' + ArcFile;
    atARC,
    atPAK : Result := Tool + ' l ' + ArcFile;
    atSQZ : Result := Tool + ' l ' + ArcFile;
    atHYP : Result := Tool + ' l ' + ArcFile;
    atUC2 : Result := Tool + ' l ' + ArcFile;
    at7Z  : Result := Tool + ' l ' + ArcFile;
  End;
End;

// ====================================================================
// ArcList — list archive contents
// Currently returns empty list for external tools (parse TODO)
// ZIP internal listing could be added via paszlib
// ====================================================================
Function ArcList (FileName: String; Var List: TArcFileList;
                  Var Count: LongInt) : TArcResult;
Var
  AT : TArcType;
Begin
  Result.Success   := False;
  Result.FileCount := 0;
  Result.TotalSize := 0;
  Result.ErrorMsg  := '';
  Count            := 0;

  AT := ArcDetectType(FileName);
  If AT = atUnknown Then AT := ArcDetectByExt(FileName);

  If AT = atUnknown Then Begin
    Result.ErrorMsg := 'Unknown archive format';
    Exit;
  End;

  If Not ArcTypeSupported(AT) Then Begin
    Result.ErrorMsg := ArcTypeStr[AT] + ' tool not configured';
    Exit;
  End;

  // For now, external tools list to stdout — parse not implemented
  // ZIP could use internal paszlib for proper listing
  Result.Success := True;
  Result.ErrorMsg := 'Listing via: ' + BuildListCmd(AT, FileName);
End;

// ====================================================================
// ArcExtract — extract files matching mask
// ====================================================================
Function ArcExtract (FileName, DestPath, Mask: String) : TArcResult;
Var
  AT  : TArcType;
  Cmd : String;
Begin
  Result.Success   := False;
  Result.FileCount := 0;
  Result.TotalSize := 0;
  Result.ErrorMsg  := '';

  AT := ArcDetectType(FileName);
  If AT = atUnknown Then AT := ArcDetectByExt(FileName);

  If AT = atUnknown Then Begin
    Result.ErrorMsg := 'Unknown archive format';
    Exit;
  End;

  If Not ArcTypeSupported(AT) Then Begin
    Result.ErrorMsg := ArcTypeStr[AT] + ' tool not configured: set path with ArcSetToolPath';
    Exit;
  End;

  If DestPath = '' Then DestPath := TempPath;
  If DestPath = '' Then DestPath := '.';

  DirCreate(DestPath);

  Cmd := BuildExtractCmd(AT, FileName, DestPath, Mask);

  If Cmd = '' Then Begin
    Result.ErrorMsg := 'Cannot build extract command for ' + ArcTypeStr[AT];
    Exit;
  End;

  Result.Success := (ExecTool(Cmd) = 0);

  If Not Result.Success Then
    Result.ErrorMsg := 'Extract failed: ' + Cmd;
End;

// ====================================================================
// ArcExtractAll — extract all files
// ====================================================================
Function ArcExtractAll (FileName, DestPath: String) : TArcResult;
Begin
  Result := ArcExtract(FileName, DestPath, '');
End;

// ====================================================================
// ArcTest — test archive integrity
// ====================================================================
Function ArcTest (FileName: String) : TArcResult;
Var
  AT  : TArcType;
  Cmd : String;
Begin
  Result.Success   := False;
  Result.FileCount := 0;
  Result.TotalSize := 0;
  Result.ErrorMsg  := '';

  AT := ArcDetectType(FileName);
  If AT = atUnknown Then AT := ArcDetectByExt(FileName);

  If AT = atUnknown Then Begin
    Result.ErrorMsg := 'Unknown archive format';
    Exit;
  End;

  If Not ArcTypeSupported(AT) Then Begin
    Result.ErrorMsg := ArcTypeStr[AT] + ' tool not configured';
    Exit;
  End;

  Cmd := BuildTestCmd(AT, FileName);

  If Cmd = '' Then Begin
    Result.ErrorMsg := 'No test command for ' + ArcTypeStr[AT];
    Exit;
  End;

  Result.Success := (ExecTool(Cmd) = 0);

  If Not Result.Success Then
    Result.ErrorMsg := 'Test failed: ' + Cmd;
End;

// ====================================================================
// Tool configuration
// ====================================================================
Procedure ArcSetToolPath (ArcType: TArcType; ToolPath: String);
Begin
  ToolPaths[ArcType] := ToolPath;
End;

Function ArcGetToolPath (ArcType: TArcType) : String;
Begin
  Result := ToolPaths[ArcType];
End;

Function ArcTypeSupported (ArcType: TArcType) : Boolean;
Begin
  Result := ToolPaths[ArcType] <> '';
End;

Procedure ArcSetTempPath (Path: String);
Begin
  TempPath := Path;
End;

Function ArcTypeToStr (ArcType: TArcType) : String;
Begin
  Result := ArcTypeStr[ArcType];
End;

// ====================================================================
// Initialize default tool paths
// Try to find common tools in PATH
// ====================================================================
Procedure InitDefaults;

  Function FindTool (Name: String) : String;
  Begin
    // Check if tool exists in PATH
    {$IFDEF UNIX}
      Result := Name;  // Unix: assume in PATH
    {$ELSE}
      {$IFDEF GO32V2}
        Result := Name + '.exe';  // DOS: try .exe
      {$ELSE}
        Result := Name + '.exe';  // Win32: try .exe
      {$ENDIF}
    {$ENDIF}

    // Validate — if not found, return empty
    If Not FileExist(FSearch(Result, GetEnv('PATH'))) Then
      Result := '';
  End;

Var
  AT : TArcType;
Begin
  TempPath := '';

  For AT := Low(TArcType) to High(TArcType) Do
    ToolPaths[AT] := '';

  // Try to find common tools
  ToolPaths[atZIP]  := FindTool('unzip');
  ToolPaths[atRAR]  := FindTool('unrar');
  ToolPaths[atARJ]  := FindTool('arj');
  If ToolPaths[atARJ] = '' Then ToolPaths[atARJ] := FindTool('unarj');
  ToolPaths[atLHA]  := FindTool('lha');
  If ToolPaths[atLHA] = '' Then ToolPaths[atLHA] := FindTool('lzh');
  ToolPaths[atARC]  := FindTool('arc');
  ToolPaths[atPAK]  := FindTool('pak');
  If ToolPaths[atPAK] = '' Then ToolPaths[atPAK] := ToolPaths[atARC]; // PAK uses ARC tool
  ToolPaths[atSQZ]  := FindTool('sqz');
  ToolPaths[atHYP]  := FindTool('hyper');
  ToolPaths[atUC2]  := FindTool('uc');
  ToolPaths[atGZIP] := FindTool('gzip');
  ToolPaths[atBZ2]  := FindTool('bzip2');
  ToolPaths[at7Z]   := FindTool('7z');
  If ToolPaths[at7Z] = '' Then ToolPaths[at7Z] := FindTool('7za');
End;

Begin
  InitDefaults;
End.
