Unit bbs_cfg_editor;

// ====================================================================
// This file is part of mystic-bbs-irc and is released under the
// GNU General Public License v3. See COPYING for details.
// ====================================================================
//
// TConfigEditor — file editor for mystic -cfg
//
// Inherits TEditorANSI (the message editor) and overrides
// EditorCommands with a file-oriented ESC menu:
//   Continue, Help, Jump first, Jump last, Quit, Save, Save As, Open
//
// Bottom bar: ESC/Menu  ^G Goto  ^W Where  ^Y Delete  ^K Cut  line/total

{$I M_OPS.PAS}

Interface

Uses
  m_Types,
  m_Strings,
  m_FileIO,
  BBS_Records,
  BBS_Core,
  BBS_IO,
  BBS_Common,
  BBS_Ansi_MenuBox,
  BBS_Ansi_MenuForm,
  BBS_DataBase,
  BBS_Edit_Ansi,
  bbs_cfg_viewer;

Type
  TConfigEditor = Class(TEditorANSI)
  Private
    FFileName  : String;
    FChanged   : Boolean;

    Procedure DrawStatusBar;

  Public
    Constructor Create (Var O: Pointer);
    Destructor  Destroy; Override;

    Function  LoadFile (AFileName: String) : Boolean;
    Function  SaveFile : Boolean;
    Function  SaveFileAs (AFileName: String) : Boolean;
    Procedure EditorCommands; Override;
    Function  Edit : Boolean; Override;

    Property FileName : String Read FFileName;
  End;

Implementation

Constructor TConfigEditor.Create (Var O: Pointer);
Begin
  Inherited Create (O, '');

  FFileName := '';
  FChanged  := False;
End;

Destructor TConfigEditor.Destroy;
Begin
  Inherited Destroy;
End;

Function TConfigEditor.LoadFile (AFileName: String) : Boolean;
Var
  F    : Text;
  S    : String;
  Line : LongInt;
Begin
  Result := False;

  If Not FileExist(AFileName) Then Begin
    { Create empty file if it doesn't exist }
    Assign (F, AFileName);
    {$I-} ReWrite (F); {$I+}
    If IOResult = 0 Then Close(F);
    FFileName := AFileName;
    FChanged  := False;
    Result    := True;
    Exit;
  End;

  FFileName := AFileName;

  Assign (F, AFileName);
  {$I-} Reset (F); {$I+}
  If IOResult <> 0 Then Exit;

  Line := 1;

  While Not Eof(F) and (Line < ANSI.Lines) Do Begin
    ReadLn (F, S);
    SetLineText (Line, S);
    Inc (Line);
  End;

  Close (F);
  FindLastLine;

  FChanged := False;
  Result   := True;
End;

Function TConfigEditor.SaveFile : Boolean;
Var
  F    : Text;
  Line : LongInt;
Begin
  Result := False;

  If FFileName = '' Then Exit;

  FindLastLine;

  Assign (F, FFileName);
  {$I-} ReWrite (F); {$I+}
  If IOResult <> 0 Then Exit;

  For Line := 1 to LastLine Do
    WriteLn (F, GetLineText(Line));

  Close (F);
  FChanged := False;
  Result   := True;
End;

Function TConfigEditor.SaveFileAs (AFileName: String) : Boolean;
Begin
  FFileName := AFileName;
  Result    := SaveFile;
End;

Procedure TConfigEditor.DrawStatusBar;
Var
  Status : String;
  Pos    : String;
Begin
  If FFileName = '' Then
    Status := 'NEW'
  Else If FChanged Then
    Status := 'CHANGED'
  Else
    Status := '';

  Pos := strI2S(CurLine + TopLine) + '/' + strI2S(LastLine);

  WriteXY (1, 1, 112, strPadR(' File: ' + FFileName, 60, ' ') +
           strPadL(Status, 19, ' '));

  WriteXY (1, Session.User.ThisUser.ScreenSize, 112,
           strPadR(' ESC/Menu     ^G Goto     ^W Where     ^Y Delete     ^K Cut', 66, ' ') +
           strPadL(Pos, 14, ' '));
End;


Procedure TConfigEditor.EditorCommands;
Var
  Box  : TAnsiMenuBox;
  Form : TAnsiMenuForm;
  Img  : TConsoleImageRec;
  Res  : Char;
  NewFN: String;
Begin
  Console.GetScreenImage (24, 6, 52, 15, Img);

  Box := TAnsiMenuBox.Create;
  Box.Open (24, 6, 52, 15);

  Form := TAnsiMenuForm.Create;
  Form.ExitOnFirst := True;

  Form.AddNone ('C', ' C Continue',            26,  7, 26,  7, 24, '');
  Form.AddNone ('?', ' ? Help',                26,  8, 26,  8, 24, '');
  Form.AddNone ('\', ' \ Jump to first line',  26,  9, 26,  9, 24, '');
  Form.AddNone ('/', ' / Jump to last line',   26, 10, 26, 10, 24, '');
  Form.AddNone ('Q', ' Q Quit',               26, 11, 26, 11, 24, '');
  Form.AddNone ('S', ' S Save',               26, 12, 26, 12, 24, '');
  Form.AddNone ('A', ' A Save As...',          26, 13, 26, 13, 24, '');
  Form.AddNone ('O', ' O Open...',             26, 14, 26, 14, 24, '');

  Res := Form.Execute;

  Form.Free;
  Box.Close;
  Box.Free;

  Session.io.RemoteRestore (Img);

  Case Res of
    'C' : ;
    'Q' : Begin
            Done := True;
            Save := False;
          End;
    'S' : Begin
            If FFileName <> '' Then Begin
              If SaveFile Then
                DrawStatusBar;
            End;
          End;
    'A' : Begin
            WriteXY (1, Session.User.ThisUser.ScreenSize, 112,
                     strPadR(' Save as: ', 80, ' '));
            Session.io.AnsiGotoXY (11, Session.User.ThisUser.ScreenSize);
            NewFN := Session.io.GetInput (60, 60, 11, FFileName);
            If NewFN <> '' Then Begin
              If SaveFileAs(NewFN) Then
                DrawStatusBar;
            End;
            DrawStatusBar;
          End;
    'O' : Begin
            NewFN := FilePickerDialog(bbsCfg.DataPath, '*.*');
            If (NewFN <> '') and FileExist(NewFN) Then Begin
              LoadFile (NewFN);
              ReDrawTemplate (True);
              DrawPage (WinY1, WinY2, False);
              DrawStatusBar;
            End;
            DrawStatusBar;
          End;
    '\' : Begin
            TopLine := 0;
            CurLine := 0;
            CurY    := WinY1;
            DrawPage (WinY1, WinY2, False);
            LocateCursor;
          End;
    '/' : Begin
            FindLastLine;
            If LastLine > WinSize Then Begin
              TopLine := LastLine - WinSize;
              CurLine := WinSize - 1;
            End Else Begin
              TopLine := 0;
              CurLine := LastLine - 1;
            End;
            CurY := WinY1 + CurLine;
            DrawPage (WinY1, WinY2, False);
            LocateCursor;
          End;
  End;
End;

Function TConfigEditor.Edit : Boolean;
Var
  Ch : Char;
Begin
  If DrawMode Then Begin
    Result := Inherited Edit;
    Exit;
  End;

  Session.io.AllowArrow := True;

  Begin
    Session.io.OutRaw (#27 + '[2J');
    DrawStatusBar;

    WinY1   := 2;
    WinY2   := Session.User.ThisUser.ScreenSize - 1;
    WinSize := WinY2 - WinY1 + 1;
    WinX1   := 1;
    WinX2   := 79;
    RowSize := WinX2 - WinX1 + 1;

    InsertMode := True;
    WrapMode   := False;
    ClearEOL   := True;
    CurAttr    := 7;
    TopLine    := 0;
    CurLine    := 0;
    CurX       := WinX1;
    CurY       := WinY1;

    DrawPage (WinY1, WinY2, False);
    LocateCursor;
  End;

  Done := False;
  Save := False;

  Repeat
    Session.io.AnsiGotoXY (CurX, CurY);

    Ch := Session.io.GetKey;
    Case Ch of
      #07 : Begin { ^G Goto }
              WriteXY (1, Session.User.ThisUser.ScreenSize, 112,
                       strPadR(' Goto line: ', 80, ' '));
              Session.io.AnsiGotoXY (13, Session.User.ThisUser.ScreenSize);
              CurLine := strS2I(Session.io.GetInput(10, 10, 11, '')) - 1;
              If CurLine < 0 Then CurLine := 0;
              If CurLine > LastLine - 1 Then CurLine := LastLine - 1;
              If CurLine >= WinSize Then Begin
                TopLine := CurLine - WinSize Div 2;
                CurLine := CurLine - TopLine;
              End Else
                TopLine := 0;
              CurY := WinY1 + CurLine;
              DrawPage (WinY1, WinY2, False);
              DrawStatusBar;
              LocateCursor;
            End;
      #08 : DoBackSpace;
      #09 : Begin
              CurX := CurX + 8;
              If CurX > WinX2 Then CurX := WinX2;
              LocateCursor;
            End;
      #11 : Begin { ^K Cut }
              If CutTextPos < fseMaxCutText Then Begin
                Inc (CutTextPos);
                CutText[CutTextPos] := ANSI.Data[TopLine + CurLine + 1];
                DeleteLine (TopLine + CurLine + 1);
                DrawPage (CurY, WinY2, False);
                LocateCursor;
                FChanged := True;
                DrawStatusBar;
              End;
            End;
      #13 : Begin
              DoEnter;
              FChanged := True;
              DrawStatusBar;
            End;
      #25 : Begin { ^Y Delete line }
              DeleteLine (TopLine + CurLine + 1);
              DrawPage (CurY, WinY2, False);
              LocateCursor;
              FChanged := True;
              DrawStatusBar;
            End;
      #27 : Begin
              EditorCommands;
              If Not Done Then Begin
                DrawPage (WinY1, WinY2, False);
                DrawStatusBar;
              End;
            End;
      #00 : Case Session.io.GetKey of
              #71 : Begin CurX := WinX1; LocateCursor; End;
              #72 : If Not LineUp(True) Then ;
              #73 : PageUp;
              #75 : If CurX > WinX1 Then Begin Dec(CurX); LocateCursor; End;
              #77 : If CurX < WinX2 Then Begin Inc(CurX); LocateCursor; End;
              #79 : Begin
                      FindLastLine;
                      CurX := GetLineLength(ANSI.Data[TopLine + CurLine + 1], RowSize) + WinX1;
                      If CurX > WinX2 Then CurX := WinX2;
                      LocateCursor;
                    End;
              #80 : If Not LineDown(True) Then ;
              #81 : PageDown;
              #82 : ToggleInsert(True);
              #83 : Begin DoDelete; FChanged := True; End;
            End;
    Else
      If Not Session.io.IsArrow Then Begin
        DoChar (Ch);
        FChanged := True;
      End;
    End;
  Until Done;

  Result := Save;
End;

End.
