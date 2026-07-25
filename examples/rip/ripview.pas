//
// This file is part of the Mystic BBS IRC Fork.
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// ====================================================================
// ripview — RIPscrip scene viewer demo
//
// Loads a .RIP scene file, renders it using the RIPscrip v1.54 engine,
// and exports the result as a 24-bit BMP file.
//
// Usage: ripview <scene.rip> [output.bmp]
//
// Fonts and icons are loaded from examples/ripterm154js/
//
// This file is part of Mystic BBS (GPLv3).
// ====================================================================

Program ripview;

Uses
  RIP_Viewer;

Var
  Viewer   : TRIPViewer;
  F        : Text;
  Line     : String;
  InFile   : String;
  OutFile  : String;
  FontDir  : String;
  IconDir  : String;

Begin
  If ParamCount < 1 Then Begin
    WriteLn('ripview — RIPscrip v1.54 Scene Viewer');
    WriteLn('Usage: ripview <scene.rip> [output.bmp]');
    WriteLn;
    WriteLn('Renders a .RIP scene file to a 640x350 24-bit BMP.');
    WriteLn('Fonts: FONTS/');
    WriteLn('Icons: ICONS/');
    Halt(1);
  End;

  InFile  := ParamStr(1);
  If ParamCount >= 2 Then
    OutFile := ParamStr(2)
  Else
    OutFile := 'output.bmp';

  // Default paths relative to repo root
  FontDir := 'FONTS';
  IconDir := 'ICONS';

  WriteLn('Loading fonts from: ', FontDir);
  WriteLn('Loading icons from: ', IconDir);
  WriteLn('Input:  ', InFile);
  WriteLn('Output: ', OutFile);
  WriteLn;

  Viewer := TRIPViewer.Create;
  Viewer.LoadFonts(FontDir);
  Viewer.SetIconPath(IconDir);

  // Read and process the RIP file line by line
  Assign(F, InFile);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('ERROR: Cannot open ', InFile);
    Viewer.Free;
    Halt(2);
  End;

  While Not Eof(F) Do Begin
    ReadLn(F, Line);
    // Feed each character through the parser
    Viewer.ProcessStr(Line + #13#10);
  End;

  Close(F);

  // Export
  If Viewer.Engine.SaveBMP(OutFile) Then
    WriteLn('Saved: ', OutFile, ' (640x350 24-bit BMP)')
  Else
    WriteLn('ERROR: Failed to save ', OutFile);

  WriteLn('Mouse fields: ', Viewer.Engine.GetMouseCount);

  Viewer.Free;
End.
