Program MakeTheme;

// ====================================================================
// Mystic BBS Software               Copyright 1997-2012 By James Coyle
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
  DOS,
  m_Strings,
  m_FileIO;

{$I RECORDS.PAS}

Var
  bbsConfig  : RecConfig;
  BasePath   : String;
  InFN       : String;
  OutFN      : String;
  Action     : String;

  ConfigFile : File of RecConfig;
  ThemeFile  : File of RecPrompt;
  Theme      : RecPrompt;
  Found      : Array[0..mysMaxThemeText] of Boolean;
  FDir       : DirStr;
  FName      : NameStr;
  FExt       : ExtStr;
  Buffer     : Array[1..2048] of Byte;
  TF         : Text;

Procedure CompileTheme;
Var
  Count : LongInt;
  Temp  : String;
  Tried : String;
  Opened : Boolean;
Begin
  FSplit (InFN, FDir, FName, FExt);

  // An empty name would make Reset() below open stdin and hang; reject it.
  If FName + FExt = '' Then Begin
    WriteLn ('ERROR: No input file specified');
    Halt (1);
  End;

  // Resolve the source prompt file.  The user may give a bare theme name
  // ("default") rather than an exact filename, so try, in order:
  //   1. the name exactly as typed (current dir)
  //   2. name + ".txt" (the documented convention) if no extension was given
  //   3. the same two under the BBS DataPath
  // Report every path tried if none open, so the user knows where we looked.
  Tried := '';

  Assign (TF, FName + FExt);
  SetTextBuf (TF, Buffer, SizeOf(Buffer));
  {$I-} Reset (TF); {$I+}
  Opened := IoResult = 0;
  If Not Opened Then Tried := Tried + '  ' + FName + FExt + #13#10;

  If (Not Opened) and (FExt = '') Then Begin
    Assign (TF, FName + '.txt');
    SetTextBuf (TF, Buffer, SizeOf(Buffer));
    {$I-} Reset (TF); {$I+}
    Opened := IoResult = 0;
    If Not Opened Then Tried := Tried + '  ' + FName + '.txt' + #13#10;
  End;

  If Not Opened Then Begin
    Assign (TF, bbsConfig.DataPath + FName + FExt);
    SetTextBuf (TF, Buffer, SizeOf(Buffer));
    {$I-} Reset (TF); {$I+}
    Opened := IoResult = 0;
    If Not Opened Then Tried := Tried + '  ' + bbsConfig.DataPath + FName + FExt + #13#10;
  End;

  If (Not Opened) and (FExt = '') Then Begin
    Assign (TF, bbsConfig.DataPath + FName + '.txt');
    SetTextBuf (TF, Buffer, SizeOf(Buffer));
    {$I-} Reset (TF); {$I+}
    Opened := IoResult = 0;
    If Not Opened Then Tried := Tried + '  ' + bbsConfig.DataPath + FName + '.txt' + #13#10;
  End;

  If Not Opened Then Begin
    WriteLn ('ERROR: Theme source file for "' + FName + FExt + '" not found.');
    WriteLn ('Looked in:');
    Write   (Tried);
    Halt (1);
  End;

  Write ('Compiling Theme file: ');

  Assign  (ThemeFile, bbsConfig.DataPath + FName + '.thm');
  ReWrite (ThemeFile);

  If IoResult <> 0 Then Begin
    WriteLn;
    WriteLn;
    WriteLn ('ERROR: Cannot run while Mystic is loaded');
    Halt(1);
  End;

  Theme := '';

  For Count := 0 to mysMaxThemeText Do Begin
    Found[Count] := False;
    Write (ThemeFile, Theme);
  End;

  Reset (ThemeFile);

  While Not Eof(TF) Do Begin
    ReadLn (TF, Temp);

    If Copy(Temp, 1, 3) = '000' Then
      Count := 0
    Else
    If strS2I(Copy(Temp, 1, 3)) > 0 Then
      Count := strS2I(Copy(Temp, 1, 3))
    Else
      Count := -1;

    If Count <> -1 Then Begin
      If Count > mysMaxThemeText Then Begin
        WriteLn;
        WriteLn;
        WriteLn ('ERROR: Prompt #', Count, ' was not expected.  Theme file not created');
        Close (ThemeFile);
        Erase (ThemeFile);
        Halt(1);
      End;

      If Found[Count] Then Begin
        WriteLn;
        WriteLn;
        WriteLn ('ERROR: Prompt #', Count, ' was found twice.  Theme file not created');
        Close (ThemeFile);
        Erase (ThemeFile);
        Halt  (1);
      End;

      Found[Count] := True;
      Seek (ThemeFile, Count);
      Theme := Copy(Temp, 5, Length(Temp));
      Write (ThemeFile, Theme);
    End;
  End;

  Close (TF);
  Close (ThemeFile);

  WriteLn ('Done.');

  For Count := 0 to mysMaxThemeText Do Begin
    If Not Found[Count] Then Begin
      WriteLn;
      WriteLn (^G'ERROR: Prompt #', Count, ' was not found.  Theme file not created');
      Erase (ThemeFile);
      Halt (1);
    End;
  End;
End;

Procedure ExtractTheme;
Var
  Count : LongInt;
Begin
  FSplit (InFN, FDir, FName, FExt);

  Assign (ThemeFile, bbsConfig.DataPath + FName + '.thm');
  {$I-} Reset (ThemeFile); {$I+}

  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Input file (' + bbsConfig.DataPath + FName + '.thm) not found');
    Halt (1);
  End;

  Assign (TF, OutFN);
  ReWrite(TF);

  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Unable to create output file');
    Halt(1);
  End;

  Write ('Decompiling Theme file ... ');

  Count := 0;

  While Not Eof(ThemeFile) Do Begin
    Read (ThemeFile, Theme);
    WriteLn (TF, strPadL(strI2S(Count), 3, '0') + ' ' + Theme);
    Inc (Count);
  End;

  WriteLn (Count - 1, ' prompts.');

  Close (TF);
  Close (ThemeFile);
End;

Procedure ListThemes;
Var
  TL    : File of RecTheme;
  CT    : RecTheme;
  Count : LongInt;
Begin
  Assign (TL, bbsConfig.DataPath + 'theme.dat');
  {$I-} Reset (TL); {$I+}

  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Unable to open ' + bbsConfig.DataPath + 'theme.dat');
    WriteLn;
    WriteLn ('Or use: MakeTheme cfgpath <DataPath>');
    Halt (1);
  End;

  WriteLn ('Themes in theme.dat  (' + bbsConfig.DataPath + ')');
  WriteLn;

  Count := 0;

  While Not Eof(TL) Do Begin
    Read (TL, CT);

    If strUpper(CT.FileName) = strUpper(bbsConfig.DefThemeFile) Then
      WriteLn ('  theme: ' + CT.Desc + '   [fallback]')
    Else
      WriteLn ('  theme: ' + CT.Desc);
    WriteLn ('     Text  : ' + CT.TextPath);
    WriteLn ('     Menu  : ' + CT.MenuPath);
    WriteLn ('     Script: ' + CT.ScriptPath);
    WriteLn ('     Icon  : ' + CT.IconPath);
    WriteLn ('     Font  : ' + CT.FontPath);
    WriteLn;

    Inc (Count);
  End;

  Close (TL);

  WriteLn (Count, ' theme(s).');
End;

Procedure ConfigTheme;
Var
  TL     : File of RecTheme;
  CT     : RecTheme;
  Target : String;
  RecNum : LongInt;
  Found  : Boolean;

  Function AskPath (Name, Current: String) : String;
  Var
    S   : String;
    Ans : String;
  Begin
    WriteLn;
    WriteLn ('  ' + Name);
    WriteLn ('    Current: ' + Current);
    Write   ('    New (blank = keep): ');
    ReadLn  (S);

    If S = '' Then
      S := Current
    Else Begin
      If (S[Length(S)] <> '\') and (S[Length(S)] <> '/') Then
        S := S + PathChar;
    End;

    If (S <> '') and Not DirExists(S) Then Begin
      Write ('    Directory does not exist. Create it? (Y/n): ');
      ReadLn (Ans);
      If (Ans = '') or (UpCase(Ans[1]) = 'Y') Then Begin
        {$I-} MkDir(S); {$I+}
        If IOResult = 0 Then
          WriteLn ('    Created: ' + S)
        Else
          WriteLn ('    ERROR: Could not create ' + S);
      End;
    End;

    Result := S;
  End;

Begin
  // Edit the load-critical paths (Text/Menu/Script) of a theme record in
  // theme.dat from the command line.  Needed when those paths point at a
  // different machine (e.g. moved config) - Mystic will not load until the
  // default theme's paths are valid, and normally they can only be fixed in
  // the MCFG theme editor, which requires a loading Mystic.  This breaks that
  // chicken-and-egg.  No name given -> edits bbsConfig.DefThemeFile.
  If InFN <> '' Then
    Target := InFN
  Else
    Target := bbsConfig.DefThemeFile;

  Assign (TL, bbsConfig.DataPath + 'theme.dat');
  {$I-} Reset (TL); {$I+}

  If IoResult <> 0 Then Begin
    WriteLn ('ERROR: Unable to open ' + bbsConfig.DataPath + 'theme.dat');
    WriteLn;
    WriteLn ('Or use: MakeTheme cfgpath <DataPath>');
    Halt (1);
  End;

  Found  := False;
  RecNum := 0;

  While Not Eof(TL) Do Begin
    Read (TL, CT);

    If strUpper(CT.FileName) = strUpper(Target) Then Begin
      Found := True;
      Break;
    End;

    Inc (RecNum);
  End;

  If Not Found Then Begin
    WriteLn ('ERROR: Theme "' + Target + '" not found in theme.dat');
    Close (TL);
    Halt (1);
  End;

  WriteLn ('Editing theme: ' + CT.FileName + '  (' + CT.Desc + ')');
  WriteLn ('Leave a path blank to keep its current value.');

  CT.TextPath   := AskPath ('Text Path',   CT.TextPath);
  CT.MenuPath   := AskPath ('Menu Path',   CT.MenuPath);
  CT.ScriptPath := AskPath ('Script Path', CT.ScriptPath);
  CT.IconPath   := AskPath ('Icon Path',   CT.IconPath);
  CT.FontPath   := AskPath ('Font Path',   CT.FontPath);

  Seek  (TL, RecNum);
  Write (TL, CT);
  Close (TL);

  WriteLn;
  WriteLn ('Saved.  Paths updated for theme "' + CT.FileName + '".');
End;

Begin
  WriteLn;
  WriteLn ('MAKETHEME : Mystic BBS Theme Compiler Version ' + mysVersion);
  WriteLn ('Copyright (C) 1997-2013 James Coyle. IRC Fork (C) 2025-2026');
  WriteLn;

  If ParamCount < 1 Then Begin
    WriteLn ('Usage: MakeTheme [Action] [Input File] <Output File>');
    WriteLn;
    WriteLn ('<Action> Options:');
    WriteLn ('   COMPILE : Compiles [Input File] into a Mystic Theme file');
    WriteLn ('   EXTRACT : Decompiles [Input File] into a text file ([Output File])');
    WriteLn ('   LIST    : List the themes in theme.dat and their paths');
    WriteLn ('   CFGTHEME: Edit a theme''s Text/Menu/Script paths in theme.dat');
    WriteLn ('   CFGPATH : Set Data path directly (bypasses mystic.dat)');
    WriteLn;
    WriteLn ('Examples:');
    WriteLn ('   MakeTheme compile default.txt');
    WriteLn ('   MakeTheme extract default prompts.txt');
    WriteLn ('   MakeTheme list');
    WriteLn ('   MakeTheme cfgtheme               (edits the default theme)');
    WriteLn ('   MakeTheme cfgtheme default');
    WriteLn ('   MakeTheme cfgpath c:\mystic\data\');
    WriteLn;
    WriteLn ('Note: Since MakeTheme does not compile comments into a compiled theme file,');
    WriteLn ('      comments will not be included when decompiling a theme file.');
    Halt (1);
  End;

  Action   := '';
  InFN     := '';
  OutFN    := '';
  FileMode := 2;

  Action := strUpper(ParamStr(1));
  InFN   := ParamStr(2);
  OutFN  := ParamStr(3);

  { CFGPATH: Set Data path in mystic.dat directly }
  If (Action = 'CFGPATH') Then Begin
    If InFN = '' Then Begin
      WriteLn ('Usage: MakeTheme cfgpath <DataPath>');
      WriteLn;
      WriteLn ('Example: MakeTheme cfgpath c:\mystic\data\');
      Halt (1);
    End;

    Assign (ConfigFile, 'mystic.dat');
    {$I-} Reset (ConfigFile); {$I+}

    If IoResult <> 0 Then Begin
      BasePath := GetENV('mysticbbs');
      If BasePath <> '' Then BasePath := DirSlash(BasePath);
      Assign (ConfigFile, BasePath + 'mystic.dat');
      {$I-} Reset (ConfigFile); {$I+}
      If IoResult <> 0 Then Begin
        WriteLn ('ERROR: Unable to read MYSTIC.DAT');
        Halt (1);
      End;
    End;

    Read  (ConfigFile, bbsConfig);

    WriteLn ('Current Data path: ', bbsConfig.DataPath);
    bbsConfig.DataPath := DirSlash(InFN);
    WriteLn ('New Data path:     ', bbsConfig.DataPath);

    If Not DirExists(bbsConfig.DataPath) Then Begin
      {$I-} MkDir(bbsConfig.DataPath); {$I+}
      If IOResult = 0 Then
        WriteLn ('Created: ', bbsConfig.DataPath)
      Else
        WriteLn ('WARNING: Directory does not exist and could not be created.');
    End;

    Reset   (ConfigFile);
    Write   (ConfigFile, bbsConfig);
    Close   (ConfigFile);

    WriteLn;
    WriteLn ('Saved. Data path updated in mystic.dat.');
    Halt (0);
  End;

  { Load mystic.dat }
  Begin
    Assign (ConfigFile, 'mystic.dat');
    {$I-} Reset (ConfigFile); {$I+}

    If IoResult <> 0 Then Begin
      BasePath := GetENV('mysticbbs');

      If BasePath <> '' Then BasePath := DirSlash(BasePath);

      Assign (ConfigFile, BasePath + 'mystic.dat');
      {$I-} Reset (ConfigFile); {$I+}

      If IoResult <> 0 Then Begin
        WriteLn ('ERROR: Unable to read MYSTIC.DAT');
        WriteLn;
        WriteLn ('MYSTIC.DAT must exist in the same directory as MakeTheme, or in the');
        WriteLn ('path defined by the MYSTICBBS environment variable.');
        WriteLn ('Or use: MakeTheme cfgpath <DataPath>');
        Halt    (1);
      End;
    End;

    Read  (ConfigFile, bbsConfig);
    Close (ConfigFile);

    If bbsConfig.DataChanged <> mysDataChanged Then Begin
      WriteLn ('ERROR: MakeTheme has detected a version mismatch');
      WriteLn;
      WriteLn ('MakeTheme or another BBS utility is an older incompatible version.  Make');
      WriteLn ('sure you have upgraded properly!');
      Halt (1);
    End;

    { Sanitize RIP fields }
    If (bbsConfig.RipScreenW = 0) Or (bbsConfig.RipScreenW > 4096) Then
      bbsConfig.RipScreenW := 640;
    If (bbsConfig.RipScreenH = 0) Or (bbsConfig.RipScreenH > 4096) Then
      bbsConfig.RipScreenH := 350;
  End;

  // COMPILE and EXTRACT both need an input file.  Without one, InFN is empty and
  // FPC's Reset() on an empty filename opens STANDARD INPUT instead of failing -
  // so the tool would silently hang waiting on the console.  Catch it here.
  If ((Action = 'COMPILE') or (Action = 'EXTRACT')) and (InFN = '') Then Begin
    WriteLn ('ERROR: No input file specified for ', Action, '.');
    WriteLn;
    WriteLn ('Usage: MakeTheme ', Action, ' [Input File]');
    Halt (1);
  End;

  If (Action = 'LIST') or (Action = '-LIST') Then ListThemes Else
  If Action = 'COMPILE'  Then CompileTheme Else
  If Action = 'EXTRACT'  Then ExtractTheme Else
  If Action = 'CFGTHEME' Then ConfigTheme Else
  Begin
    WriteLn ('Invalid <action> option');
    Halt (1);
  End;
End.
