// ====================================================================
// This file is part of mystic-bbs-irc and is released under the
// GNU General Public License v3. See COPYING for details.
// ====================================================================
//
Unit bbs_cfg_viewer;

// ====================================================================
// TAnsiFileViewer - Reusable file viewer/editor class for mystic -cfg
// ====================================================================
//
// Scrollable ANSI file viewer with ESC popup menu, ^G Goto, ^W Where.
// Used by: Log Viewer (ReadOnly), Text Editor (future), RIP Viewer (future).
//
// Based on AnsiViewer logic from bbs_general.pas but implemented as a
// class for inheritance and reuse. Does not modify bbs_general.pas.
//
// GPLv3.

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
  BBS_MsgBase_Ansi;

Type
  TAnsiFileViewer = Class
  Private
    FOwner     : Pointer;
    FAnsi      : TMsgBaseAnsi;
    FTopLine   : LongInt;
    FWinTop    : Byte;
    FWinBot    : Byte;
    FWinSize   : LongInt;
    FFileName  : String;
    FReadOnly  : Boolean;
    FDone      : Boolean;
    FSaveImage : TConsoleImageRec;

    Procedure DrawTopBar;
    Procedure DrawBottomBar;
    Procedure DrawContent;

  Protected
    Procedure HandleArrowKey (Ch: Char); Virtual;
    Procedure HandleCharKey  (Ch: Char); Virtual;
    Procedure ShowESCMenu; Virtual;

  Public
    Constructor Create (AOwner: Pointer; AReadOnly: Boolean);
    Destructor  Destroy; Override;

    Function  LoadFile (AFileName: String) : Boolean;
    Procedure Run;

    Procedure ScrollUp;
    Procedure ScrollDown;
    Procedure PageUp;
    Procedure PageDown;
    Procedure JumpToStart;
    Procedure JumpToEnd;
    Procedure GotoLine;
    Procedure SearchText;

    Property FileName : String  Read FFileName;
    Property ReadOnly : Boolean Read FReadOnly Write FReadOnly;
  End;

Function FilePickerDialog (APath, AMask: String) : String;

Implementation

Uses
  DOS,
  BBS_DataBase;

Constructor TAnsiFileViewer.Create (AOwner: Pointer; AReadOnly: Boolean);
Begin
  Inherited Create;

  FOwner    := AOwner;
  FAnsi     := TMsgBaseAnsi.Create(AOwner, False);
  FReadOnly := AReadOnly;
  FTopLine  := 1;
  FWinTop   := 2;
  FWinBot   := 23;
  FWinSize  := FWinBot - FWinTop + 1;
  FDone     := False;
  FFileName := '';
End;

Destructor TAnsiFileViewer.Destroy;
Begin
  FAnsi.Free;

  Inherited Destroy;
End;

Function TAnsiFileViewer.LoadFile (AFileName: String) : Boolean;
Var
  AFile  : File;
  Buf    : Array[1..4096] of Char;
  BufLen : LongInt;
Begin
  Result := False;

  If Not FileExist(AFileName) Then Exit;

  FFileName := AFileName;

  FAnsi.Clear;

  Assign  (AFile, AFileName);
  ioReset (AFile, 1, fmReadWrite + fmDenyNone);

  While Not Eof(AFile) Do Begin
    ioBlockRead (AFile, Buf, SizeOf(Buf), BufLen);
    If FAnsi.ProcessBuf(Buf, BufLen) Then Break;
  End;

  Close (AFile);

  FTopLine := 1;
  Result   := True;
End;

Procedure TAnsiFileViewer.DrawTopBar;
Var
  Status : String;
Begin
  If FReadOnly Then
    Status := 'VIEW ONLY'
  Else If FFileName = '' Then
    Status := '      NEW'
  Else
    Status := '         ';

  WriteXY (1, 1, 112, strPadR(' File: ' + FFileName, 70, ' ') + strPadL(Status, 10, ' '));
End;

Procedure TAnsiFileViewer.DrawBottomBar;
Var
  Pos : String;
Begin
  Pos := strI2S(FTopLine) + '/' + strI2S(FAnsi.Lines);

  If FReadOnly Then
    WriteXY (1, TBBSCore(FOwner).User.ThisUser.ScreenSize, 112, strPadR(' ESC/Menu' + strRep(' ', 14) + '^G Goto     ^W Where', 66, ' ') + strPadL(Pos, 14, ' '))
  Else
    WriteXY (1, TBBSCore(FOwner).User.ThisUser.ScreenSize, 112, strPadR(' ESC/Menu     ^G Goto     ^W Where     ^Y Delete     ^K Cut', 66, ' ') + strPadL(Pos, 14, ' '));
End;

Procedure TAnsiFileViewer.DrawContent;
Begin
  FAnsi.DrawPage (FWinTop, FWinBot, FTopLine);
  DrawBottomBar;
End;

Procedure TAnsiFileViewer.ScrollUp;
Begin
  If FTopLine > 1 Then Begin
    Dec (FTopLine);
    DrawContent;
  End;
End;

Procedure TAnsiFileViewer.ScrollDown;
Begin
  If FTopLine + FWinSize <= FAnsi.Lines Then Begin
    Inc (FTopLine);
    DrawContent;
  End;
End;

Procedure TAnsiFileViewer.PageUp;
Begin
  If FTopLine > 1 Then Begin
    Dec (FTopLine, FWinSize);
    If FTopLine < 1 Then FTopLine := 1;
    DrawContent;
  End;
End;

Procedure TAnsiFileViewer.PageDown;
Begin
  If FTopLine + FWinSize <= FAnsi.Lines Then Begin
    Inc (FTopLine, FWinSize);
    If FTopLine + FWinSize > FAnsi.Lines Then
      FTopLine := FAnsi.Lines - FWinSize + 1;
    If FTopLine < 1 Then FTopLine := 1;
    DrawContent;
  End;
End;

Procedure TAnsiFileViewer.JumpToStart;
Begin
  If FTopLine <> 1 Then Begin
    FTopLine := 1;
    DrawContent;
  End;
End;

Procedure TAnsiFileViewer.JumpToEnd;
Begin
  If FTopLine + FWinSize <= FAnsi.Lines Then Begin
    FTopLine := FAnsi.Lines - FWinSize + 1;
    If FTopLine < 1 Then FTopLine := 1;
    DrawContent;
  End;
End;

Procedure TAnsiFileViewer.GotoLine;
Var
  Str  : String;
  Line : LongInt;
Begin
  WriteXY (1, TBBSCore(FOwner).User.ThisUser.ScreenSize, 112, strPadR(' Goto line: ', 80, ' '));

  Session.io.AnsiGotoXY(13, TBBSCore(FOwner).User.ThisUser.ScreenSize);
  Str := Session.io.GetInput(10, 10, 11, '');

  If Str <> '' Then Begin
    Line := strS2I(Str);
    If Line < 1 Then Line := 1;
    If Line > FAnsi.Lines Then Line := FAnsi.Lines;

    FTopLine := Line - (FWinSize Div 2);
    If FTopLine < 1 Then FTopLine := 1;
    If FTopLine + FWinSize > FAnsi.Lines Then
      FTopLine := FAnsi.Lines - FWinSize + 1;
    If FTopLine < 1 Then FTopLine := 1;
  End;

  DrawContent;
End;

Procedure TAnsiFileViewer.SearchText;
Var
  Str   : String;
  Line  : Word;
  Col   : Byte;
  Found : Boolean;
  Check : String;
Begin
  WriteXY (1, TBBSCore(FOwner).User.ThisUser.ScreenSize, 112, strPadR(' Search: ', 80, ' '));

  Session.io.AnsiGotoXY(10, TBBSCore(FOwner).User.ThisUser.ScreenSize);
  Str := Session.io.GetInput(60, 60, 11, '');

  If Str = '' Then Begin
    DrawContent;
    Exit;
  End;

  Str   := strUpper(Str);
  Found := False;

  For Line := FTopLine + 1 to FAnsi.Lines Do Begin
    Check := '';
    For Col := 1 to 80 Do
      Check := Check + FAnsi.Data[Line][Col].Ch;

    If Pos(Str, strUpper(Check)) > 0 Then Begin
      FTopLine := Line - (FWinSize Div 2);
      If FTopLine < 1 Then FTopLine := 1;
      Found := True;
      Break;
    End;
  End;

  If Not Found Then Begin
    WriteXY (1, TBBSCore(FOwner).User.ThisUser.ScreenSize, 112, strPadR(' Not found: ' + Str, 80, ' '));
    Session.io.GetKey;
  End;

  DrawContent;
End;

Procedure TAnsiFileViewer.ShowESCMenu;
Var
  Box  : TAnsiMenuBox;
  Form : TAnsiMenuForm;
  Img  : TConsoleImageRec;
  Res  : Char;
Begin
  Console.GetScreenImage (20, 7, 50, 13, Img);

  Box := TAnsiMenuBox.Create;
  Box.Open (20, 7, 50, 13);

  Form := TAnsiMenuForm.Create;
  Form.ExitOnFirst := True;

  Form.AddNone ('C', ' C Continue',            26,  9, 26,  9, 22, '');
  Form.AddNone ('?', ' ? Help',                26, 10, 26, 10, 22, '');
  Form.AddNone ('\', ' \ Jump to first line',  26, 11, 26, 11, 22, '');
  Form.AddNone ('/', ' / Jump to last line',   26, 12, 26, 12, 22, '');
  Form.AddNone ('Q', ' Q Quit',               26, 13, 26, 13, 22, '');

  Res := Form.Execute;

  Form.Free;
  Box.Close;
  Box.Free;

  Session.io.RemoteRestore (Img);

  Case Res of
    'Q' : FDone := True;
    '\' : JumpToStart;
    '/' : JumpToEnd;
  End;
End;

Procedure TAnsiFileViewer.HandleArrowKey (Ch: Char);
Begin
  Case Ch of
    #71 : JumpToStart;
    #72 : ScrollUp;
    #73 : PageUp;
    #79 : JumpToEnd;
    #80 : ScrollDown;
    #77,
    #81 : PageDown;
  End;
End;

Procedure TAnsiFileViewer.HandleCharKey (Ch: Char);
Begin
  Case Ch of
    #27 : Begin
            ShowESCMenu;
            If Not FDone Then Begin
              DrawContent;
              DrawTopBar;
            End;
          End;
    #07 : GotoLine;
    #23 : SearchText;
    'P' : PageDown;
    'N',
    #13 : PageDown;
  End;
End;

Procedure TAnsiFileViewer.Run;
Var
  Ch : Char;
Begin
  Console.GetScreenImage (1, 1, 80, 25, FSaveImage);

  Session.io.AllowArrow := True;
  Session.io.AnsiColor(7);
  Session.io.AnsiClear;

  DrawTopBar;
  DrawContent;

  Repeat
    Ch := Session.io.GetKey;

    If Session.io.IsArrow Then
      HandleArrowKey (Ch)
    Else
      HandleCharKey (Ch);
  Until FDone;

  Session.io.RemoteRestore (FSaveImage);
End;

Function FilePickerDialog (APath, AMask: String) : String;
Var
  Box     : TAnsiMenuBox;
  Img     : TConsoleImageRec;
  DirInfo : SearchRec;
  Files   : Array[1..50] of String[80];
  IsDir   : Array[1..50] of Boolean;
  Count   : Integer;
  Pick    : Integer;
  Top     : Integer;
  MaxShow : Integer;
  Row     : Integer;
  Ch      : Char;
  CurPath : String;
  Done    : Boolean;

  Procedure ScanDir;
  Begin
    Count := 0;
    Inc(Count); Files[Count] := '..'; IsDir[Count] := True;
    FindFirst(CurPath + '*.*', $10, DirInfo);
    While (DosError = 0) and (Count < 45) Do Begin
      If (DirInfo.Attr And $10 <> 0) and (DirInfo.Name <> '.') and (DirInfo.Name <> '..') Then Begin
        Inc(Count); Files[Count] := '[' + DirInfo.Name + ']'; IsDir[Count] := True;
      End;
      FindNext(DirInfo);
    End;
    FindClose(DirInfo);
    FindFirst(CurPath + AMask, $27, DirInfo);
    While (DosError = 0) and (Count < 50) Do Begin
      If DirInfo.Attr And $10 = 0 Then Begin
        Inc(Count); Files[Count] := DirInfo.Name; IsDir[Count] := False;
      End;
      FindNext(DirInfo);
    End;
    FindClose(DirInfo);
  End;

  Procedure DrawList;
  Var I, Attr: Integer;
  Begin
    WriteXY(10, 5, 15, strPadR(' ' + CurPath, 40, ' '));
    For I := 1 to MaxShow Do Begin
      If Top + I <= Count Then Begin
        If Top + I = Pick Then Attr := 112 Else If IsDir[Top + I] Then Attr := 11 Else Attr := 7;
        WriteXY(10, 5 + I, Attr, strPadR(' ' + Files[Top + I], 40, ' '));
      End Else
        WriteXY(10, 5 + I, 7, strRep(' ', 41));
    End;
  End;

Begin
  Result  := '';
  CurPath := APath;
  MaxShow := 15;
  Done    := False;

  Console.GetScreenImage(8, 4, 52, 5 + MaxShow + 1, Img);
  Box := TAnsiMenuBox.Create;
  Box.Open(8, 4, 52, 5 + MaxShow + 1);

  ScanDir;
  Pick := 1;
  Top  := 0;
  DrawList;

  Repeat
    Ch := Session.io.GetKey;
    Case Ch of
      #27 : Begin Done := True; End;
      #00 : Case Session.io.GetKey of
              #72 : If Pick > 1 Then Begin Dec(Pick); If Pick <= Top Then Dec(Top); DrawList; End;
              #80 : If Pick < Count Then Begin Inc(Pick); If Pick > Top + MaxShow Then Inc(Top); DrawList; End;
              #73 : Begin Pick := Pick - MaxShow; If Pick < 1 Then Pick := 1; Top := Pick - 1; If Top < 0 Then Top := 0; DrawList; End;
              #81 : Begin Pick := Pick + MaxShow; If Pick > Count Then Pick := Count; Top := Pick - MaxShow; If Top < 0 Then Top := 0; DrawList; End;
            End;
      #13 : Begin
              If IsDir[Pick] Then Begin
                If Files[Pick] = '..' Then Begin
                  If Length(CurPath) > 1 Then Begin
                    Delete(CurPath, Length(CurPath), 1);
                    While (Length(CurPath) > 0) and (CurPath[Length(CurPath)] <> '/') and
                          (CurPath[Length(CurPath)] <> '\\') Do
                      Delete(CurPath, Length(CurPath), 1);
                  End;
                End Else
                  CurPath := CurPath + Copy(Files[Pick], 2, Length(Files[Pick]) - 2) + PathChar;
                ScanDir; Pick := 1; Top := 0; DrawList;
              End Else Begin
                Result := CurPath + Files[Pick];
                Done := True;
              End;
            End;
    End;
  Until Done;

  Box.Close;
  Box.Free;
  Session.io.RemoteRestore(Img);
End;

End.
