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
Program rip2ans;

// ====================================================================
// rip2ans - RIPscrip to ANSI converter
// ====================================================================
//
// Reads a .rip file (RIPscrip v1.54 commands) and produces a .ans file
// (ANSI escape sequences) that approximates the same visual output in
// text mode (80x25).
//
// RIPscrip is vector graphics (640x350 pixels). ANSI is character cells
// (80x25). This converter maps RIP coordinates to character positions
// and translates drawing commands to ANSI color/cursor sequences.
//
// The conversion is approximate — RIP graphics cannot be perfectly
// represented in ANSI text. But menus with text, colors, and button
// labels convert well.
//
// Based on PabloDraw's RIP format handling (credit: Curtis Wensley).
// GPLv3.

{$MODE OBJFPC}{$H+}

Uses SysUtils;

Const
  CELL_W = 8;    // pixels per character cell width
  CELL_H = 14;   // pixels per character cell height (EGA: 8, VGA: 14)
  COLS   = 80;
  ROWS   = 25;

Type
  TCell = Record
    Ch   : Char;
    Fg   : Byte;
    Bg   : Byte;
  End;

Var
  Screen   : Array[0..ROWS-1, 0..COLS-1] of TCell;
  CurColor : Byte;
  CurX, CurY : Integer;
  InFile   : Text;
  OutFile  : Text;
  Line     : AnsiString;
  InPath   : String;
  OutPath  : String;

Function FromB36(C: Char): Integer;
Begin
  Case C of
    '0'..'9' : Result := Ord(C) - Ord('0');
    'A'..'Z' : Result := Ord(C) - Ord('A') + 10;
    'a'..'z' : Result := Ord(C) - Ord('a') + 10;
  Else
    Result := 0;
  End;
End;

Function MegaNum(Const S: AnsiString; Var Idx: Integer): Integer;
Begin
  Result := 0;
  If Idx + 1 <= Length(S) Then Begin
    Result := FromB36(S[Idx]) * 36 + FromB36(S[Idx + 1]);
    Inc(Idx, 2);
  End;
End;

Procedure ClearScreen;
Var R, C: Integer;
Begin
  For R := 0 to ROWS-1 Do
    For C := 0 to COLS-1 Do Begin
      Screen[R][C].Ch := ' ';
      Screen[R][C].Fg := 7;
      Screen[R][C].Bg := 0;
    End;
  CurColor := 7;
  CurX := 0; CurY := 0;
End;

Procedure PutText(PX, PY: Integer; Const S: AnsiString);
Var
  Col, Row, I: Integer;
Begin
  Col := PX Div CELL_W;
  Row := PY Div CELL_H;
  If (Row < 0) Or (Row >= ROWS) Then Exit;
  For I := 1 to Length(S) Do Begin
    If (Col >= 0) And (Col < COLS) Then Begin
      Screen[Row][Col].Ch := S[I];
      Screen[Row][Col].Fg := CurColor;
    End;
    Inc(Col);
  End;
End;

Procedure DrawBar(X0, Y0, X1, Y1: Integer);
Var
  R, C, R0, R1, C0, C1: Integer;
Begin
  R0 := Y0 Div CELL_H; R1 := Y1 Div CELL_H;
  C0 := X0 Div CELL_W; C1 := X1 Div CELL_W;
  If R0 < 0 Then R0 := 0; If R1 >= ROWS Then R1 := ROWS - 1;
  If C0 < 0 Then C0 := 0; If C1 >= COLS Then C1 := COLS - 1;
  For R := R0 to R1 Do
    For C := C0 to C1 Do Begin
      Screen[R][C].Ch := #219;  // solid block
      Screen[R][C].Fg := CurColor;
    End;
End;

Procedure DrawLine(X0, Y0, X1, Y1: Integer);
Var
  R0, C0, R1, C1, R, C: Integer;
Begin
  R0 := Y0 Div CELL_H; C0 := X0 Div CELL_W;
  R1 := Y1 Div CELL_H; C1 := X1 Div CELL_W;
  // Horizontal line
  If R0 = R1 Then Begin
    If C0 > C1 Then Begin R := C0; C0 := C1; C1 := R; End;
    If (R0 >= 0) And (R0 < ROWS) Then
      For C := C0 to C1 Do
        If (C >= 0) And (C < COLS) Then Begin
          Screen[R0][C].Ch := #196;  // horizontal line char
          Screen[R0][C].Fg := CurColor;
        End;
  End
  // Vertical line
  Else If C0 = C1 Then Begin
    If R0 > R1 Then Begin R := R0; R0 := R1; R1 := R; End;
    If (C0 >= 0) And (C0 < COLS) Then
      For R := R0 to R1 Do
        If (R >= 0) And (R < ROWS) Then Begin
          Screen[R][C0].Ch := #179;  // vertical line char
          Screen[R][C0].Fg := CurColor;
        End;
  End;
End;

Procedure DrawRect(X0, Y0, X1, Y1: Integer);
Begin
  DrawLine(X0, Y0, X1, Y0);  // top
  DrawLine(X0, Y1, X1, Y1);  // bottom
  DrawLine(X0, Y0, X0, Y1);  // left
  DrawLine(X1, Y0, X1, Y1);  // right
End;

Procedure HandleButton(Const Args: AnsiString; Idx: Integer);
Var
  X0, Y0, X1, Y1, Col, Row: Integer;
  Params, LabelText: AnsiString;
  P: Integer;
Begin
  X0 := MegaNum(Args, Idx); Y0 := MegaNum(Args, Idx);
  X1 := MegaNum(Args, Idx); Y1 := MegaNum(Args, Idx);
  Params := Copy(Args, Idx, Length(Args));
  // Parse the <> delimited fields: icon<>label<>hostcmd
  P := Pos('<>', Params);
  If P > 0 Then Begin
    Delete(Params, 1, P + 1);
    P := Pos('<>', Params);
    If P > 0 Then
      LabelText := Copy(Params, 1, P - 1)
    Else
      LabelText := Params;
  End Else
    LabelText := '';
  // Place button label as text
  Col := X0 Div CELL_W;
  Row := Y0 Div CELL_H;
  If (Row >= 0) And (Row < ROWS) And (LabelText <> '') Then
    PutText(X0, Y0, LabelText);
End;

Procedure ProcessCommand(Const Cmd: AnsiString);
Var
  P, Level: Integer;
  Op: Char;
  X0, Y0, X1, Y1: Integer;
  S: AnsiString;
Begin
  If Length(Cmd) < 3 Then Exit;
  If (Cmd[1] <> '!') Or (Cmd[2] <> '|') Then Exit;

  P := 3;
  Level := 0;
  While (P <= Length(Cmd)) And (Cmd[P] In ['0'..'9']) Do Begin
    Level := Level * 10 + (Ord(Cmd[P]) - Ord('0'));
    Inc(P);
  End;
  If P > Length(Cmd) Then Exit;
  Op := Cmd[P]; Inc(P);

  If Level = 0 Then
  Case Op of
    '*' : ClearScreen;
    'c' : CurColor := MegaNum(Cmd, P) And 15;
    '@' : Begin  // text at position
            X0 := MegaNum(Cmd, P); Y0 := MegaNum(Cmd, P);
            S := Copy(Cmd, P, Length(Cmd));
            PutText(X0, Y0, S);
          End;
    'T' : Begin  // text at current position
            S := Copy(Cmd, P, Length(Cmd));
            PutText(CurX, CurY, S);
          End;
    'L' : Begin
            X0 := MegaNum(Cmd, P); Y0 := MegaNum(Cmd, P);
            X1 := MegaNum(Cmd, P); Y1 := MegaNum(Cmd, P);
            DrawLine(X0, Y0, X1, Y1);
          End;
    'R' : Begin
            X0 := MegaNum(Cmd, P); Y0 := MegaNum(Cmd, P);
            X1 := MegaNum(Cmd, P); Y1 := MegaNum(Cmd, P);
            DrawRect(X0, Y0, X1, Y1);
          End;
    'B' : Begin
            X0 := MegaNum(Cmd, P); Y0 := MegaNum(Cmd, P);
            X1 := MegaNum(Cmd, P); Y1 := MegaNum(Cmd, P);
            DrawBar(X0, Y0, X1, Y1);
          End;
    'm' : Begin
            CurX := MegaNum(Cmd, P); CurY := MegaNum(Cmd, P);
          End;
  End
  Else If Level = 1 Then
  Case Op of
    'U' : HandleButton(Cmd, P);  // button with label
  End;
End;

// ANSI color code from EGA color index
Function AnsiColor(Fg: Byte): AnsiString;
Var
  Bold: Boolean;
  Base: Byte;
Begin
  Bold := Fg > 7;
  Base := Fg And 7;
  // EGA to ANSI: 0=black 1=blue 2=green 3=cyan 4=red 5=magenta 6=brown 7=white
  // ANSI SGR:    30=black 34=blue 32=green 36=cyan 31=red 35=magenta 33=yellow 37=white
  Case Base of
    0 : Base := 30;
    1 : Base := 34;
    2 : Base := 32;
    3 : Base := 36;
    4 : Base := 31;
    5 : Base := 35;
    6 : Base := 33;
    7 : Base := 37;
  End;
  If Bold Then
    Result := #27 + '[1;' + IntToStr(Base) + 'm'
  Else
    Result := #27 + '[0;' + IntToStr(Base) + 'm';
End;

Procedure WriteANSI;
Var
  R, C: Integer;
  LastFg: Byte;
  HasContent: Boolean;
Begin
  Assign(OutFile, OutPath);
  Rewrite(OutFile);
  LastFg := 255;  // force first color write

  For R := 0 to ROWS - 1 Do Begin
    // check if row has content
    HasContent := False;
    For C := 0 to COLS - 1 Do
      If Screen[R][C].Ch <> ' ' Then Begin HasContent := True; Break; End;
    If Not HasContent Then Begin
      Write(OutFile, #13#10);
      Continue;
    End;

    For C := 0 to COLS - 1 Do Begin
      If Screen[R][C].Fg <> LastFg Then Begin
        Write(OutFile, AnsiColor(Screen[R][C].Fg));
        LastFg := Screen[R][C].Fg;
      End;
      Write(OutFile, Screen[R][C].Ch);
    End;
    Write(OutFile, #13#10);
  End;

  // reset colors at end
  Write(OutFile, #27 + '[0m');
  Close(OutFile);
End;

Var
  Cmd: AnsiString;
Begin
  If (ParamCount < 2) Or (ParamStr(1) = '--help') Or (ParamStr(1) = '-H') Then Begin
    WriteLn('rip2ans - RIPscrip to ANSI converter');
    WriteLn('Usage: rip2ans input.rip output.ans');
    WriteLn;
    WriteLn('Converts RIPscrip v1.54 scenes to ANSI text approximation.');
    WriteLn('Maps 640x350 pixel coordinates to 80x25 character cells.');
    WriteLn('Text, bars, lines, rectangles, and button labels are converted.');
    WriteLn;
    WriteLn('Credit: PabloDraw by Curtis Wensley (RIP format reference)');
    WriteLn('GPLv3');
    Halt(0);
  End;

  InPath  := ParamStr(1);
  OutPath := ParamStr(2);

  ClearScreen;

  Assign(InFile, InPath);
  {$I-} Reset(InFile); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('Error: cannot open ', InPath);
    Halt(1);
  End;

  While Not EOF(InFile) Do Begin
    ReadLn(InFile, Line);
    // Handle line continuation
    While (Length(Line) > 0) And (Line[Length(Line)] = '\') And Not EOF(InFile) Do Begin
      Delete(Line, Length(Line), 1);
      ReadLn(InFile, Cmd);
      Line := Line + Cmd;
    End;
    // Process each !| command on the line
    Cmd := Line;
    While Pos('!|', Cmd) > 0 Do Begin
      Delete(Cmd, 1, Pos('!|', Cmd) - 1);
      // Find end of this command (next !| or end of line)
      If Pos('!|', Copy(Cmd, 3, Length(Cmd))) > 0 Then Begin
        ProcessCommand(Copy(Cmd, 1, Pos('!|', Copy(Cmd, 3, Length(Cmd))) + 1));
        Delete(Cmd, 1, Pos('!|', Copy(Cmd, 3, Length(Cmd))) + 1);
      End Else Begin
        ProcessCommand(Cmd);
        Cmd := '';
      End;
    End;
  End;

  Close(InFile);

  WriteANSI;
  WriteLn('Converted: ', InPath, ' -> ', OutPath);
End.
