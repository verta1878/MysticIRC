Program MUTIL;

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

Uses
  {$IFDEF DEBUG}
    HeapTrc,
    LineInfo,
  {$ENDIF}
  m_Output,
  m_DateTime,
  m_Strings,
  m_FileIO,
  m_IniReader,
  BBS_Records,
  mUtil_Common,
  mUtil_Status,
  mUtil_ImportNA,
  mUtil_ImportMsgBase,
  mUtil_FileBone,
  mUtil_Upload,
  mUtil_TopLists,
  mUtil_FilesBBS,
  mUtil_AllFiles,
  mUtil_MsgPurge,
  mUtil_MsgPack,
  mUtil_MsgPost,
  mUtil_EchoExport,
  mUtil_EchoImport,
  mUtil_FileToss,
  mUtil_NodeList,
  mUtil_EchoTrack,
  mUtil_EchoUnlink,
  mUtil_AutoHatch,
  mUtil_PackFileBases,
  mUtil_FileSort,
  mUtil_LinkMsg,
  mUtil_PurgeUser,
  mUtil_PackUser,
  mUtil_ExportFileBone,
  mUtil_ExportAreas,
  mUtil_ExportGolded,
  bbs_DataBase;

{$I MUTIL_ANSI.PAS}

Function CheckProcess (pName: String) : Boolean;
Begin
  { 1.12: -RUN mode overrides INI settings }
  If RunMode Then
    Result := Pos(strUpper(pName), strUpper(RunList)) > 0
  Else
    Result := INI.ReadBoolean(Header_General, pName, False);

  If Result Then Begin
    Inc (ProcessTotal);

    Log (2, '+', '   EXEC ' + pName);
  End Else
    Log (3, '+', '   SKIP ' + pName);
End;

Procedure ApplicationShutdown;
Begin
  Log (1, '+', '=> Shutdown');
  Log (1, '+', '');

  If Assigned(Console) Then Begin
    Console.SetWindow (1, 1, 80, 25, False);
    Console.CursorXY  (3, 22);

    Console.TextAttr := 15;
    Console.WriteLine('> Execution of ' + strI2S(ProcessTotal) + ' processes complete');
    Console.TextAttr := 7;
  End;

  BarOne.Free;
  BarAll.Free;
  INI.Free;
End;

Procedure ApplicationStartup;
Var
  FN : String;
  CF : File of RecConfig;
  F  : File;
  PI : Integer;
Begin
  ExitProc := @ApplicationShutdown;
  { 1.12: -NOSCREEN can be in any arg position }
  NoScreen := False;
  For PI := 1 to ParamCount Do
    If strUpper(ParamStr(PI)) = '-NOSCREEN' Then NoScreen := True;

  Console  := TOutput.Create(Not NoScreen);

  If Console.Active Then DrawStatusScreen;

  Console.SetWindow(5, 14, 76, 20, True);

  { 1.12: Find INI file -- skip flags (-VER, -LIST, -RUN, -NOSCREEN) }
  FN := '';
  For PI := 1 to ParamCount Do Begin
    If ParamStr(PI)[1] <> '-' Then Begin
      { Skip the argument after -RUN (it's the task list, not an INI file) }
      If (PI > 1) and (strUpper(ParamStr(PI - 1)) = '-RUN') Then Continue;
      If FileExist(ParamStr(PI)) Then Begin FN := ParamStr(PI); Break; End;
      If FileExist(ParamStr(PI) + '.ini') Then Begin FN := ParamStr(PI) + '.ini'; Break; End;
    End;
  End;
  If FN = '' Then
    If FileExist('mutil.ini') Then FN := 'mutil.ini';
  If FN = '' Then Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('Missing file', True);
    ProcessResult (rFATAL, False);

    Halt(1);
  End;

  INI := TINIReader.Create(FN);

  Console.WriteXY (26, 10, 8, FN);

  Assign (CF, INI.ReadString(Header_GENERAL, 'mystic_directory', 'mystic.dat'));

  {$I-} Reset(CF); {$I+}

  If IoResult <> 0 Then Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('Missing MYSTIC.DAT', True);
    ProcessResult (rFATAL, False);

    Halt(1);
  End;

  Read  (CF, bbsCfg);
  Close (CF);

  If bbsCfg.DataChanged <> mysDataChanged Then Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('Version mismatch', True);
    ProcessResult (rFATAL, False);

    Halt(1);
  End;

  TempPath := bbsCfg.SystemPath + 'temputil' + PathChar;

  GetDIR (0, StartPath);

  {$I-}
  MkDir (TempPath);
  {$I+}

  If IoResult <> 0 Then;

  DirClean (TempPath, '');

  LogFile := INI.ReadString(Header_GENERAL, 'logfile', '');

  If (LogFile <> '') and (Pos(PathChar, LogFile) = 0) Then
    LogFile := bbsCfg.LogsPath + LogFile;

  LogLevel    := INI.ReadInteger(Header_GENERAL, 'loglevel', 1);
  LogStamp    := INI.ReadString (Header_GENERAL, 'logstamp', 'NNN DD HH:II:SS');
  MaxLogFiles := INI.ReadInteger(Header_GENERAL, 'maxlogfiles', 10);
  MaxLogSize  := INI.ReadInteger(Header_GENERAL, 'maxlogsize', 500);
  LogType     := INI.ReadInteger(Header_GENERAL, 'logtype', 0);
  LogCache    := INI.ReadBoolean(Header_GENERAL, 'logcache', True);

  BarOne := TStatusBar.Create(3);
  BarAll := TStatusBar.Create(6);

  If LogFile <> '' Then Begin
    Assign (F, LogFile);
    If Not ioReset(F, 1, fmRWDN) Then ReWrite(F);
    Close (F);
  End;
End;

Const
  { 1.12: All task names for -LIST and -RUN }
  TaskNames : Array[0..24] of String[25] = (
    'Import_FIDONET.NA',    'Import_MessageBase',
    'Import_FILEBONE.NA',   'Export_FILEBONE.NA',
    'Export_AREAS.BBS',     'Export_Golded',
    'Import_FILES.BBS',     'MassUpload',
    'GenerateTopLists',     'GenerateAllFiles',
    'PurgeMessageBases',    'PackMessageBases',
    'PostTextFiles',        'ImportEchoMail',
    'ExportEchoMail',       'MergeNodeLists',
    'ImportFileToss',       'PackFileBases',
    'FileSort',             'LinkMessages',
    'PurgeUserBase',        'PackUserBase',
    'AutoHatch',            'EchoNodeTracker',
    'EchoUnlink'
  );

Procedure ShowVersion;
Begin
  WriteLn('MUTIL v' + mysVersion);
  Halt(0);
End;

Procedure ShowList;
Var I: Integer;
Begin
  WriteLn('MUTIL v' + mysVersion + ' - Available functions:');
  WriteLn('');
  For I := 0 to High(TaskNames) Do
    WriteLn('  ' + TaskNames[I]);
  WriteLn('');
  WriteLn('Usage: MUTIL -RUN ImportEchoMail,ExportEchoMail');
  Halt(0);
End;

Procedure ShowHelp;
Begin
  WriteLn('MUTIL v' + mysVersion);
  WriteLn('');
  WriteLn('MUTIL                           Execute using mutil.ini file');
  WriteLn('MUTIL [IniFile]                 Execute using a custom INI file');
  WriteLn('MUTIL [IniFile] -RUN [Command]  Execute specific functions');
  WriteLn('MUTIL -RUN [Command]            Execute one or more (comma separated)');
  WriteLn('MUTIL -LIST                     List all MUTIL functions');
  WriteLn('MUTIL -VER                      Show version information');
  WriteLn('MUTIL -NOSCREEN                 Execute without screen output');
  Halt(0);
End;

Var
  RunMode      : Boolean;
  RunList      : String;
  RunIdx       : Integer;
  DoImportNA   : Boolean;
  DoFilesBBS   : Boolean;
  DoFileBone   : Boolean;
  DoMassUpload : Boolean;
  DoTopLists   : Boolean;
  DoAllFiles   : Boolean;
  DoEchoExport : Boolean;
  DoEchoImport : Boolean;
  DoMsgPurge   : Boolean;
  DoMsgPack    : Boolean;
  DoMsgPost    : Boolean;
  DoImportMB   : Boolean;
  DoNodeList   : Boolean;
  DoFileToss   : Boolean;
  DoEchoTrack  : Boolean;
  DoEchoUnlink : Boolean;
  DoAutoHatch  : Boolean;
  DoPackFBase  : Boolean;
  DoFileSort   : Boolean;
  DoLinkMsg    : Boolean;
  DoPurgeUser  : Boolean;
  DoPackUser   : Boolean;
  DoExpFBone   : Boolean;
  DoExpAreas   : Boolean;
  DoExpGolded  : Boolean;
Begin
  { 1.12: Command line flags before startup }
  If ParamCount > 0 Then Begin
    If strUpper(ParamStr(1)) = '-VER'  Then ShowVersion;
    If strUpper(ParamStr(1)) = '-LIST' Then ShowList;
    If strUpper(ParamStr(1)) = '-HELP' Then ShowHelp;
    If strUpper(ParamStr(1)) = '-H'    Then ShowHelp;
  End;

  ApplicationStartup;

  { 1.12: -RUN flag -- override INI, enable only named tasks }
  RunMode := False;
  RunList := '';
  For RunIdx := 1 to ParamCount Do
    If strUpper(ParamStr(RunIdx)) = '-RUN' Then Begin
      RunMode := True;
      If RunIdx < ParamCount Then RunList := ParamStr(RunIdx + 1);
    End;

  Log (1, '+', '=> Startup using ' + JustFile(INI.FileName));
  Log (1, '+', '   Log level: ' + strI2S(LogLevel));
  If RunMode Then Log (1, '+', '   -RUN: ' + RunList);

  // Build process list

  DoImportNA   := CheckProcess(Header_IMPORTNA);
  DoImportMB   := CheckProcess(Header_IMPORTMB);
  DoFileBone   := CheckProcess(Header_FILEBONE);
  DoMassUpload := CheckProcess(Header_UPLOAD);
  DoTopLists   := CheckProcess(Header_TOPLISTS);
  DoFilesBBS   := CheckProcess(Header_FILESBBS);
  DoAllFiles   := CheckProcess(Header_ALLFILES);
  DoEchoExport := CheckProcess(Header_ECHOEXPORT);
  DoEchoImport := CheckProcess(Header_ECHOIMPORT);
  DoMsgPurge   := CheckProcess(Header_MSGPURGE);
  DoMsgPack    := CheckProcess(Header_MSGPACK);
  DoMsgPost    := CheckProcess(Header_MSGPOST);
  DoNodeList   := CheckProcess(Header_NODELIST);
  DoFileToss   := CheckProcess(Header_FILETOSS);
  DoEchoTrack  := CheckProcess(Header_ECHOTRACK);
  DoEchoUnlink := CheckProcess(Header_ECHOUNLINK);
  DoAutoHatch  := CheckProcess(Header_AUTOHATCH);
  DoPackFBase  := CheckProcess(Header_PACKCRC);
  DoFileSort   := CheckProcess(Header_FILESORT);
  DoLinkMsg    := CheckProcess(Header_LINKMSG);
  DoPurgeUser  := CheckProcess(Header_PURGEUSER);
  DoPackUser   := CheckProcess(Header_PACKUSER);
  DoExpFBone   := CheckProcess(Header_EXPORTBONE);
  DoExpAreas   := CheckProcess(Header_EXPORTAREA);
  DoExpGolded  := CheckProcess(Header_EXPORTGOLD);

  // Exit with an error if nothing is configured

  If ProcessTotal = 0 Then Begin
    ProcessName   ('Load configuration', False);
    ProcessStatus ('No processes configured', True);
    ProcessResult (rFATAL, False);

    Halt(1);
  End;

  // We're good lets execute this stuff!

  If DoImportNA   Then Begin TaskBegin('Import_FIDONET.NA'); uImportNA; TaskEnd('Import_FIDONET.NA'); End;
  If DoFileBone   Then Begin TaskBegin('Import_FILEBONE.NA'); uImportFileBone; TaskEnd('Import_FILEBONE.NA'); End;
  If DoFilesBBS   Then Begin TaskBegin('Import_FILES.BBS'); uImportFilesBBS; TaskEnd('Import_FILES.BBS'); End;
  If DoMassUpload Then Begin TaskBegin('MassUpload'); uMassUpload; TaskEnd('MassUpload'); End;
  If DoTopLists   Then Begin TaskBegin('GenerateTopLists'); uTopLists; TaskEnd('GenerateTopLists'); End;
  If DoAllFiles   Then Begin TaskBegin('GenerateAllFiles'); uAllFilesList; TaskEnd('GenerateAllFiles'); End;
  If DoEchoImport Then Begin TaskBegin('ImportEchoMail'); uEchoImport; TaskEnd('ImportEchoMail'); End;
  If DoFileToss   Then Begin TaskBegin('ImportFileToss'); uFileToss; TaskEnd('ImportFileToss'); End;
  If DoEchoExport Then Begin TaskBegin('ExportEchoMail'); uEchoExport; TaskEnd('ExportEchoMail'); End;
  If DoMsgPurge   Then Begin TaskBegin('PurgeMessageBases'); uPurgeMessageBases; TaskEnd('PurgeMessageBases'); End;
  If DoMsgPack    Then Begin TaskBegin('PackMessageBases'); uPackMessageBases; TaskEnd('PackMessageBases'); End;
  If DoMsgPost    Then Begin TaskBegin('PostTextFiles'); uPostMessages; TaskEnd('PostTextFiles'); End;
  If DoImportMB   Then Begin TaskBegin('Import_MessageBase'); uImportMessageBases; TaskEnd('Import_MessageBase'); End;
  If DoNodeList   Then Begin TaskBegin('MergeNodeLists'); uMergeNodeList; TaskEnd('MergeNodeLists'); End;
  If DoEchoTrack  Then Begin TaskBegin('EchoNodeTracker'); uEchoNodeTracker; TaskEnd('EchoNodeTracker'); End;
  If DoEchoUnlink Then Begin TaskBegin('EchoUnlink'); uEchoUnlink; TaskEnd('EchoUnlink'); End;
  If DoAutoHatch  Then Begin TaskBegin('AutoHatch'); uAutoHatch; TaskEnd('AutoHatch'); End;
  If DoPackFBase  Then Begin TaskBegin('PackFileBases'); uPackFileBases; TaskEnd('PackFileBases'); End;
  If DoFileSort   Then Begin TaskBegin('FileSort'); uFileSort; TaskEnd('FileSort'); End;
  If DoLinkMsg    Then Begin TaskBegin('LinkMessages'); uLinkMessages; TaskEnd('LinkMessages'); End;
  If DoPurgeUser  Then Begin TaskBegin('PurgeUserBase'); uPurgeUserBase; TaskEnd('PurgeUserBase'); End;
  If DoPackUser   Then Begin TaskBegin('PackUserBase'); uPackUserBase; TaskEnd('PackUserBase'); End;
  If DoExpFBone   Then Begin TaskBegin('Export_FILEBONE.NA'); uExportFileBone; TaskEnd('Export_FILEBONE.NA'); End;
  If DoExpAreas   Then Begin TaskBegin('Export_AREAS.BBS'); uExportAreasBBS; TaskEnd('Export_AREAS.BBS'); End;
  If DoExpGolded  Then Begin TaskBegin('Export_Golded'); uExportGolded; TaskEnd('Export_Golded'); End;

  LogClose;
End.
