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

Program MPLC;

{$I M_OPS.PAS}

Uses
  DOS,
  m_Output,
  m_Strings,
  MPL_Compile;

{$I RECORDS.PAS}

Var
  SavedX   : Byte;
  SavedY   : Byte;
  Console  : TOutput;
  WasError : Boolean;

Procedure Status (Info: TParserUpdateInfo);
Begin
  Case Info.Mode of
    StatusStart  : Begin
                     Console.WriteStr('Compiling ' + Info.FileName + ' ... ');
                     SavedX := Console.CursorX;
                   End;
    StatusUpdate : Begin
                     Console.CursorXY (SavedX, Console.CursorY);
                     Console.WriteStr (strPadL(strI2S(Info.Percent), 3, ' ') + '%');
                   End;
    StatusDone   : If Info.ErrorType = 0 Then Begin
                     Console.CursorXY (SavedX, Console.CursorY);
                     Console.WriteLine ('Success!');
                   End Else Begin
                     WasError := True;
                     Console.WriteLine(#13#10#13#10'Error in ' + Info.FileName + ' (Line:' + strI2S(Info.ErrorLine) + ', Col:' + strI2S(Info.ErrorCol) + '): ' + Info.ErrorText);
                   End;
  End;
End;

// Recursively compile every *.mps in Path and all of its subdirectories.
// TParserEngine.Compile reads/writes using JustFileName (current directory
// only), so we ChDir into each directory, compile there, then recurse.  The
// original working directory is restored by the caller.
// Compile every file matching Mask in the CURRENT directory.  If Recurse is
// True, then also descend into every subdirectory and repeat.  TParserEngine.
// Compile reads/writes via JustFileName (current directory only), so callers
// must ChDir into the target directory before calling this; recursion ChDirs
// into each subdir and back.
Procedure CompileMask (Mask: String; Recurse: Boolean);
Var
  Parser  : TParserEngine;
  Dir     : SearchRec;
  SubDirs : Array[1..512] of String;
  SubCnt  : Word;
  Count   : Word;
Begin
  // 1) compile every matching script in THIS directory
  FindFirst (Mask, AnyFile - Directory - VolumeID, Dir);
  While DosError = 0 Do Begin
    Parser := TParserEngine.Create(@Status);
    Parser.Compile(Dir.Name);
    Parser.Free;
    FindNext(Dir);
  End;
  FindClose(Dir);

  If Not Recurse Then Exit;

  // 2) collect subdirectories first (can't recurse while a FindFirst on this
  //    directory is still open), then descend into each.
  SubCnt := 0;
  FindFirst ('*', Directory, Dir);
  While DosError = 0 Do Begin
    If (Dir.Attr And Directory <> 0) and (Dir.Name <> '.') and (Dir.Name <> '..') Then
      If SubCnt < 512 Then Begin
        Inc (SubCnt);
        SubDirs[SubCnt] := Dir.Name;
      End;
    FindNext(Dir);
  End;
  FindClose(Dir);

  For Count := 1 to SubCnt Do Begin
    ChDir (SubDirs[Count]);
    CompileMask (Mask, True);
    ChDir ('..');                    // back up after the subtree
  End;
End;

// Compile Mask in Path (optionally recursive), restoring the working directory.
// A blank Path means "the current directory".
Procedure CompileInPath (Path, Mask: String; Recurse: Boolean);
Var
  StartDir : String;
Begin
  GetDir (0, StartDir);

  If Path <> '' Then Begin
    {$I-} ChDir (Path); {$I+}
    If IOResult <> 0 Then Begin
      Console.WriteLine ('Path not found: ' + Path);
      Exit;
    End;
  End;

  CompileMask (Mask, Recurse);

  ChDir (StartDir);
End;


Var
  Parser : TParserEngine;
  Cmd    : String;
Begin
  WasError := False;
  Console  := TOutput.Create(True);

  Console.WriteLine (#13#10'Mystic BBS Programming Language Compiler Version ' + mysVersion);
  Console.WriteLine ('Copyright (C) 1997-2013 James Coyle. IRC Fork (C) 2025-2026'#13#10);

  If ParamCount = 0 Then Begin
    Console.WriteLine ('MPLC [path/file] : Compile one script [path/file]');
    Console.WriteLine ('MPLC -ALL        : Compile all scripts in current directory and subdirectories');
    Console.WriteLine ('MPLC -C          : Compile all scripts in current directory');
    Console.WriteLine ('MPLC -P [path]   : Compile all scripts in [path]');
    Console.WriteLine ('MPLC -R [path]   : Compile all scripts in [path] and its subdirectories');
    Console.WriteLine ('MPLC -T          : Compile all scripts in Themes directory');
    Console.WriteLine ('MPLC -F [mask]   : Compile all scripts matching [mask] in Themes directory');
  End Else Begin
    Cmd := strUpper(ParamStr(1));

    If Cmd = '-ALL' Then
      // current directory + all subdirectories
      CompileInPath ('', '*.mps', True)
    Else
    If Cmd = '-C' Then
      // current directory only
      CompileInPath ('', '*.mps', False)
    Else
    If Cmd = '-P' Then Begin
      // a specific path, non-recursive
      If ParamStr(2) = '' Then
        Console.WriteLine ('MPLC -P requires a [path]')
      Else
        CompileInPath (ParamStr(2), '*.mps', False);
    End Else
    If Cmd = '-R' Then Begin
      // a specific path + its subdirectories
      If ParamStr(2) = '' Then
        Console.WriteLine ('MPLC -R requires a [path]')
      Else
        CompileInPath (ParamStr(2), '*.mps', True);
    End Else
    If Cmd = '-T' Then
      // every script under the Themes directory tree
      CompileInPath ('themes', '*.mps', True)
    Else
    If Cmd = '-F' Then Begin
      // scripts matching a mask under the Themes directory tree
      If ParamStr(2) = '' Then
        Console.WriteLine ('MPLC -F requires a [mask]')
      Else
        CompileInPath ('themes', ParamStr(2), True);
    End Else Begin
      // a single named file
      Parser := TParserEngine.Create(@Status);
      Parser.Compile(ParamStr(1));
      Parser.Free;
    End;
  End;

  Console.Free;

  If WasError Then Halt(1);
End.
