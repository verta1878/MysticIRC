Program mystic_texteditor;

// ====================================================================
// mystic_texteditor — Standalone text editor for Mystic BBS
// ====================================================================
//
// Direct keyboard input via m_input_windows / m_input_linux.
// No BBS I/O layer. No Session object. No socket handling.
// Works in config mode and standalone.
//
// Copyright (C) 1997-2013 James Coyle
// IRC Fork (C) 2025-2026 verta1878, sysop/0, evga, kiddo, wrench
// GPLv3
// ====================================================================

{$I M_OPS.PAS}

Uses
  {$IFDEF WINDOWS}
    Windows,
    m_Input_Windows,
    m_Output_Windows;
  {$ENDIF}
  {$IFDEF UNIX}
    m_Input_Linux,
    m_Output_Linux;
  {$ENDIF}

Const
  MAX_LINES = 1000;
  MAX_COLS  = 80;

Function IntToStr(N: LongInt): String;
Var S: String;
Begin
  Str(N, S);
  IntToStr := S;
End;

Type
  TTextLine = String[255];

  TTextEditor = Object
    Lines     : Array[1..MAX_LINES] of TTextLine;
    LineCount : Integer;
    CurLine   : Integer;
    CurCol    : Integer;
    TopLine   : Integer;
    WinHeight : Integer;
    Modified  : Boolean;
    FileName  : String;
    InsMode   : Boolean;
    Done      : Boolean;
    Console   : {$IFDEF WINDOWS} TOutputWindows {$ELSE} TOutputLinux {$ENDIF};
    Keyboard  : {$IFDEF WINDOWS} TInputWindows {$ELSE} TInputLinux {$ENDIF};

    Procedure Init;
    Procedure DrawScreen;
    Procedure DrawLine(Y: Integer);
    Procedure DrawStatus;
    Procedure MoveCursor;
    Procedure ProcessKey;
    Procedure InsertChar(Ch: Char);
    Procedure DeleteChar;
    Procedure BackSpace;
    Procedure Enter;
    Procedure ScrollUp;
    Procedure ScrollDown;
    Procedure LoadFile(FN: String);
    Procedure SaveFile;
    Procedure Run;
    Procedure Cleanup;
  End;

Procedure TTextEditor.Init;
Var I: Integer;
Begin
  Console  := {$IFDEF WINDOWS} TOutputWindows.Create(True) {$ELSE} TOutputLinux.Create(True) {$ENDIF};
  Keyboard := {$IFDEF WINDOWS} TInputWindows.Create {$ELSE} TInputLinux.Create {$ENDIF};

  For I := 1 to MAX_LINES Do Lines[I] := '';
  LineCount := 1;
  CurLine   := 1;
  CurCol    := 1;
  TopLine   := 1;
  WinHeight := 23;  { rows 1-23 for text, 24-25 for status }
  Modified  := False;
  FileName  := '';
  InsMode   := True;
  Done      := False;
End;

Procedure TTextEditor.DrawStatus;
Var
  Status: String;
  ModeStr: String;
Begin
  If InsMode Then ModeStr := 'INS' Else ModeStr := 'OVR';

  Status := ' Line:' + Copy('      ', 1, 5 - Length(IntToStr(CurLine))) + IntToStr(CurLine) +
            ' Col:' + Copy('    ', 1, 3 - Length(IntToStr(CurCol))) + IntToStr(CurCol) +
            ' ' + ModeStr +
            '  ' + FileName;

  While Length(Status) < MAX_COLS Do Status := Status + ' ';
  Status := Copy(Status, 1, MAX_COLS);

  Console.WriteXY(1, 24, 112, Status);
  Console.WriteXY(1, 25, 112, ' ESC=Menu  ^S=Save  ^Q=Quit  ^F=Find                                          ');
End;

Procedure TTextEditor.DrawLine(Y: Integer);
Var
  ActualLine: Integer;
  S: String;
Begin
  ActualLine := TopLine + Y - 1;

  If ActualLine <= LineCount Then
    S := Lines[ActualLine]
  Else
    S := '~';

  While Length(S) < MAX_COLS Do S := S + ' ';
  S := Copy(S, 1, MAX_COLS);

  Console.WriteXY(1, Y, 7, S);
End;

Procedure TTextEditor.DrawScreen;
Var Y: Integer;
Begin
  For Y := 1 to WinHeight Do
    DrawLine(Y);
  DrawStatus;
End;

Procedure TTextEditor.MoveCursor;
Begin
  Console.CursorXY(CurCol, CurLine - TopLine + 1);
End;

Procedure TTextEditor.InsertChar(Ch: Char);
Begin
  If InsMode Then Begin
    If Length(Lines[CurLine]) < 255 Then Begin
      Insert(Ch, Lines[CurLine], CurCol);
      Inc(CurCol);
      Modified := True;
    End;
  End Else Begin
    If CurCol > Length(Lines[CurLine]) Then
      Lines[CurLine] := Lines[CurLine] + Ch
    Else
      Lines[CurLine][CurCol] := Ch;
    Inc(CurCol);
    Modified := True;
  End;

  DrawLine(CurLine - TopLine + 1);
End;

Procedure TTextEditor.DeleteChar;
Begin
  If CurCol <= Length(Lines[CurLine]) Then Begin
    Delete(Lines[CurLine], CurCol, 1);
    Modified := True;
    DrawLine(CurLine - TopLine + 1);
  End Else If CurLine < LineCount Then Begin
    { Join next line }
    Lines[CurLine] := Lines[CurLine] + Lines[CurLine + 1];
    Move(Lines[CurLine + 2], Lines[CurLine + 1], (LineCount - CurLine - 1) * SizeOf(TTextLine));
    Dec(LineCount);
    Modified := True;
    DrawScreen;
  End;
End;

Procedure TTextEditor.BackSpace;
Begin
  If CurCol > 1 Then Begin
    Dec(CurCol);
    Delete(Lines[CurLine], CurCol, 1);
    Modified := True;
    DrawLine(CurLine - TopLine + 1);
  End Else If CurLine > 1 Then Begin
    CurCol := Length(Lines[CurLine - 1]) + 1;
    Lines[CurLine - 1] := Lines[CurLine - 1] + Lines[CurLine];
    Move(Lines[CurLine + 1], Lines[CurLine], (LineCount - CurLine) * SizeOf(TTextLine));
    Dec(LineCount);
    Dec(CurLine);
    If CurLine < TopLine Then Dec(TopLine);
    Modified := True;
    DrawScreen;
  End;
End;

Procedure TTextEditor.Enter;
Var
  Remainder: String;
  I: Integer;
Begin
  If LineCount >= MAX_LINES Then Exit;

  Remainder := Copy(Lines[CurLine], CurCol, 255);
  Lines[CurLine] := Copy(Lines[CurLine], 1, CurCol - 1);

  { Shift lines down }
  For I := LineCount DownTo CurLine + 1 Do
    Lines[I + 1] := Lines[I];

  Inc(LineCount);
  Inc(CurLine);
  Lines[CurLine] := Remainder;
  CurCol := 1;
  Modified := True;

  If CurLine - TopLine >= WinHeight Then Inc(TopLine);
  DrawScreen;
End;

Procedure TTextEditor.ScrollUp;
Begin
  If CurLine > 1 Then Begin
    Dec(CurLine);
    If CurLine < TopLine Then Begin
      Dec(TopLine);
      DrawScreen;
    End;
    If CurCol > Length(Lines[CurLine]) + 1 Then
      CurCol := Length(Lines[CurLine]) + 1;
  End;
End;

Procedure TTextEditor.ScrollDown;
Begin
  If CurLine < LineCount Then Begin
    Inc(CurLine);
    If CurLine - TopLine >= WinHeight Then Begin
      Inc(TopLine);
      DrawScreen;
    End;
    If CurCol > Length(Lines[CurLine]) + 1 Then
      CurCol := Length(Lines[CurLine]) + 1;
  End;
End;

Procedure TTextEditor.LoadFile(FN: String);
Var
  T: Text;
  S: String;
Begin
  FileName := FN;
  LineCount := 0;

  Assign(T, FN);
  {$I-} Reset(T); {$I+}
  If IOResult <> 0 Then Begin
    LineCount := 1;
    Lines[1] := '';
    Exit;
  End;

  While (Not Eof(T)) And (LineCount < MAX_LINES) Do Begin
    Inc(LineCount);
    ReadLn(T, Lines[LineCount]);
  End;

  Close(T);

  If LineCount = 0 Then Begin
    LineCount := 1;
    Lines[1] := '';
  End;

  CurLine := 1;
  CurCol := 1;
  TopLine := 1;
  Modified := False;
End;

Procedure TTextEditor.SaveFile;
Var
  T: Text;
  I: Integer;
Begin
  If FileName = '' Then Exit;

  Assign(T, FileName);
  {$I-} Rewrite(T); {$I+}
  If IOResult <> 0 Then Exit;

  For I := 1 to LineCount Do
    WriteLn(T, Lines[I]);

  Close(T);
  Modified := False;
  DrawStatus;
End;

Procedure TTextEditor.ProcessKey;
Var
  Ch: Char;
Begin
  If Not Keyboard.KeyWait(100) Then Exit;

  Ch := Keyboard.ReadKey;

  If Ch = #0 Then Begin
    { Extended key }
    Ch := Keyboard.ReadKey;
    Case Ch of
      #72: ScrollUp;          { Up }
      #80: ScrollDown;        { Down }
      #75: If CurCol > 1 Then Dec(CurCol);  { Left }
      #77: If CurCol <= Length(Lines[CurLine]) Then Inc(CurCol); { Right }
      #71: CurCol := 1;       { Home }
      #79: CurCol := Length(Lines[CurLine]) + 1; { End }
      #73: Begin              { PgUp }
             CurLine := CurLine - WinHeight;
             If CurLine < 1 Then CurLine := 1;
             TopLine := CurLine;
             DrawScreen;
           End;
      #81: Begin              { PgDn }
             CurLine := CurLine + WinHeight;
             If CurLine > LineCount Then CurLine := LineCount;
             TopLine := CurLine - WinHeight + 1;
             If TopLine < 1 Then TopLine := 1;
             DrawScreen;
           End;
      #83: DeleteChar;        { Delete }
      #82: Begin InsMode := Not InsMode; DrawStatus; End; { Insert }
    End;
  End Else
    Case Ch of
      #8:  BackSpace;
      #13: Enter;
      #9:  Begin { Tab → spaces }
             InsertChar(' ');
             While CurCol Mod 4 <> 1 Do InsertChar(' ');
           End;
      #19: SaveFile;          { Ctrl-S }
      #17: Done := True;      { Ctrl-Q }
      #27: Done := True;      { ESC }
    Else
      If Ch >= ' ' Then InsertChar(Ch);
    End;
End;

Procedure TTextEditor.Run;
Begin
  Console.SetWindow(1, 1, 80, 25, False);
  Console.TextAttr := 7;
  Console.ClearScreen;

  DrawScreen;

  Repeat
    MoveCursor;
    Console.BufFlush;
    ProcessKey;
  Until Done;
End;

Procedure TTextEditor.Cleanup;
Begin
  Console.TextAttr := 7;
  Console.ClearScreen;
  Console.BufFlush;
  Console.Free;
  Keyboard.Free;
End;

Var
  Editor: TTextEditor;
Begin
  Editor.Init;

  If ParamCount >= 1 Then
    Editor.LoadFile(ParamStr(1))
  Else
    Editor.FileName := 'untitled.txt';

  Editor.Run;
  Editor.Cleanup;
End.
