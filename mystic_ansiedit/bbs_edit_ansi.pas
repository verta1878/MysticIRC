Unit bbs_Edit_Ansi;

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

Interface

Uses
  m_FileIO,
  BBS_Database,
  BBS_MsgBase_Ansi;

Const
  fseMaxCutText = 60;

  GlyphTypeMax = 10;
  GlyphTypeStr : Array[1..10] of String[10] = (
    ('ÂÚ¿ÀÙÄ³Ã´Á'),
    ('ËÉ»È¼ÍºÌ¹Ê'),
    ('ÑÕ¸Ô¾Í³ÆµÏ'),
    ('ÒÖ·Ó½ÄºÇ¶Ð'),
    ('ïÅÎØ×èé›œ™'),
    ('ú°±²ÛßÜÝÞþ'),
    ('ð'),
    (''),
    ('¬®¯òó©ªýö«'),
    ('üãñôõêäøû')
	);

Type
  TEditorANSI = Class
    Owner        : Pointer;
    ANSI         : TMsgBaseANSI;
    WinY1        : Byte;
    WinY2        : Byte;
    WinX1        : Byte;
    WinX2        : Byte;
    WinSize      : Byte;
    RowSize      : Byte;
    CurX         : Byte;
    CurY         : SmallInt;
    CurAttr      : Byte;
    QuoteAttr    : Byte;
    CurLength    : Byte;
    TopLine      : LongInt;
    CurLine      : LongInt;
    InsertMode   : Boolean;
    DrawMode     : Boolean;
    GlyphMode    : Boolean;
    GlyphPtr     : Byte;
    WrapMode     : Boolean;
    ClearEOL     : Boolean;
    LastLine     : LongInt;
    QuoteTopPage : SmallInt;
    QuoteCurLine : SmallInt;
    CutText      : Array[1..fseMaxCutText] of RecAnsiBufferLine;
    CutTextPos   : Word;
    CutPasted    : Boolean;
    Save         : Boolean;
    Forced       : Boolean;
    Done         : Boolean;
    Subject      : String;
    Template     : String;
    DrawTemplate : String;
    SavedInsert  : Boolean;
    MaxMsgLines  : Word;
    MaxMsgCols   : Byte;

    { File mode fields }
    FileMode     : Boolean;
    FileReadOnly : Boolean;
    FileName     : String;
    FileChanged  : Boolean;

    { File mode methods }
    Function    LoadFile (AFileName: String) : Boolean;
    Function    SaveFile : Boolean;
    Function    SaveFileAs (AFileName: String) : Boolean;
    Procedure   FileEditorCommands;
    Procedure   DrawFileStatusBar;

    Constructor Create (Var O: Pointer; TemplateFile: String);
    Destructor  Destroy; Override;

    Function    IsAnsiLine    (Line: LongInt) : Boolean;
    Function    IsBlankLine   (Var Line; LineSize: Byte) : Boolean;
    Function    GetLineLength (Var Line; LineSize: Byte) : Byte;
    Function    GetWrapPos    (Var Line; LineSize, WrapPos: Byte) : Byte;
    Procedure   TrimLeft      (Var Line; LineSize: Byte);
    Procedure   TrimRight     (Var Line; LineSize: Byte);
    Procedure   DeleteLine    (Line: LongInt);
    Procedure   InsertLine    (Line: LongInt);
    Function    GetLineText   (Line: Word) : String;
    Procedure   SetLineText   (Line: LongInt; Str: String);
    Procedure   FindLastLine;
    Procedure   WordWrap;
    Procedure   ReformParagraph;
    Procedure   LocateCursor;
    Procedure   ToggleInsert (Toggle: Boolean);
    Procedure   ReDrawTemplate (Reset: Boolean);
    Procedure   DrawPage (StartY, EndY: Byte; ExitEOF: Boolean);
    Procedure   ScrollUp;
    Procedure   ScrollDown (Draw: Boolean);
    Function    LineUp (Reset: Boolean) : Boolean;
    Function    LineDown (Reset: Boolean) : Boolean;
    Procedure   PageUp;
    Procedure   PageDown;
    Procedure   DrawLine (Line: LongInt; XP, YP: Byte);
    Procedure   DoEnter;
    Procedure   DoBackSpace;
    Procedure   DoDelete;
    Procedure   DoChar (Ch: Char);
    Function    Edit : Boolean; Virtual;
    Procedure   Quote;
    Procedure   QuoteWindow;
    Procedure   EditorCommands; Virtual;
    Procedure   DrawCommands;
    Procedure   MessageUpload;
  End;

Implementation

Uses
  m_Types,
  m_Strings,
  BBS_Records,
  BBS_Core,
  BBS_Ansi_MenuBox,
  BBS_Ansi_MenuForm,
  BBS_Common,
  DOS;

Constructor TEditorANSI.Create (Var O: Pointer; TemplateFile: String);
Begin
  Inherited Create;

  Owner       := O;
  ANSI        := TMsgBaseANSI.Create(NIL, False);
  WinX1       := 1;
  WinX2       := 79;
  WinY1       := 2;
  WinY2       := 23;
  WinSize     := WinY2 - WinY1 + 1;
  RowSize     := WinX2 - WinX1 + 1;
  CurX        := 1;
  CurY        := 1;
  CurLine     := 1;
  TopLine     := 1;
  CurAttr     := 7;
  QuoteAttr   := 9;
  InsertMode  := True;
  DrawMode    := False;
  GlyphMode   := False;
  GlyphPtr    := 6;
  WrapMode    := True;
  ClearEOL    := RowSize >= 79;
  LastLine    := 1;
  CutPasted   := False;
  CutTextPos  := 0;
  Template    := TemplateFile;
  MaxMsgLines := mysMaxMsgLines;
  MaxMsgCols  := 79;
  FileMode    := False;
  FileReadOnly:= False;
  FileName    := '';
  FileChanged := False;

  FillChar (CutText, SizeOf(CutText), 0);
End;

Destructor TEditorANSI.Destroy;
Begin
  Inherited Destroy;

  ANSI.Free;
End;

Function TEditorANSI.GetLineText (Line: Word) : String;
Var
  Count : Word;
Begin
  Result := '';

  For Count := 1 to GetLineLength(ANSI.Data[Line], RowSize) Do
    If ANSI.Data[Line][Count].Ch = #0 Then
      Result := Result + ' '
    Else
      Result := Result + ANSI.Data[Line][Count].Ch;
End;

Procedure TEditorANSI.SetLineText (Line: LongInt; Str: String);
Var
  Count : Byte;
Begin
  FillChar (ANSI.Data[Line], SizeOf(ANSI.Data[Line]), 0);

  For Count := 1 to Length(Str) Do Begin
    ANSI.Data[Line][Count].Ch   := Str[Count];
    ANSI.Data[Line][Count].Attr := CurAttr;
  End;
End;

Procedure TEditorANSI.FindLastLine;
Begin
  LastLine := MaxMsgLines;

  While (LastLine > 1) And IsBlankLine(ANSI.Data[LastLine], 80) Do
    Dec(LastLine);
End;

Function TEditorANSI.IsAnsiLine (Line: LongInt) : Boolean;
Var
  Count : Byte;
Begin
  Result := False;

  If GetLineLength(ANSI.Data[Line], 80) >= RowSize Then Begin
    Result := True;

    Exit;
  End;

  For Count := 1 to 80 Do
    If (Ord(ANSI.Data[Line][Count].Ch) < 32) or (Ord(ANSI.Data[Line][Count].Ch) > 128) Then Begin
      Result := True;

      Exit;
    End;
End;

Function TEditorANSI.IsBlankLine (Var Line; LineSize: Byte) : Boolean;
Var
  EndPos : Byte;
  Data   : Array[1..255] of RecAnsiBufferChar absolute Line;
Begin
  EndPos := LineSize;

  While (EndPos > 0) and (Data[EndPos].Ch = #0) Do
    Dec (EndPos);

  Result := EndPos = 0;
End;

Procedure TEditorANSI.TrimLeft (Var Line; LineSize: Byte);
Var
  Data   : Array[1..255] of RecAnsiBufferChar absolute Line;
  EndPos : Byte;
Begin
  EndPos := 1;

  While (EndPos <= LineSize) and (Data[1].Ch = ' ') Do Begin
    Move (Data[2], Data[1], SizeOf(RecAnsiBufferChar) * (LineSize - 1));

    Data[LineSize].Ch := #0;

    Inc (EndPos);
  End;
End;

Procedure TEditorANSI.TrimRight (Var Line; LineSize: Byte);
Var
  Data   : Array[1..255] of RecAnsiBufferChar absolute Line;
Begin
  While ((Data[LineSize].Ch = ' ') or (Data[LineSize].Ch = #0)) Do Begin
    Data[LineSize].Ch := #0;

    Dec (LineSize);
  End;
End;

Procedure TEditorANSI.DeleteLine (Line: LongInt);
Var
  Count : LongInt;
Begin
  For Count := Line to MaxMsgLines - 1 Do
    ANSI.Data[Count] := ANSI.Data[Count + 1];

  FillChar (ANSI.Data[MaxMsgLines], SizeOf(RecAnsiBufferLine), #0);

  If LastLine > 1 Then Dec(LastLine);
End;

Procedure TEditorANSI.InsertLine (Line: LongInt);
Var
  Count : LongInt;
Begin
  For Count := MaxMsgLines DownTo Line + 1 Do
    ANSI.Data[Count] := ANSI.Data[Count - 1];

  FillChar(ANSI.Data[Line], SizeOf(RecAnsiBufferLine), #0);

  If LastLine < MaxMsgLines Then Inc(LastLine);
End;

Function TEditorANSI.GetWrapPos (Var Line; LineSize: Byte; WrapPos: Byte) : Byte;
Var
  Data : Array[1..255] of RecAnsiBufferChar absolute Line;
Begin
  If GetLineLength(Line, LineSize) < WrapPos Then Begin
    Result := 0;

    Exit;
  End;

  Result := LineSize;

  While (Result > 0) and ((Data[Result].Ch <> ' ') or (Result > WrapPos)) Do
    Dec (Result);
End;

Function TEditorANSI.GetLineLength (Var Line; LineSize: Byte) : Byte;
Var
  Data : Array[1..255] of RecAnsiBufferChar absolute Line;
Begin
  Result := LineSize;

  While (Result > 0) and (Data[Result].Ch = #0) Do
    Dec (Result);
End;

Procedure TEditorANSI.WordWrap;
Var
  WrapData  : Array[1..255] of RecAnsiBufferChar;
  TempStr   : Array[1..255] of RecAnsiBufferChar;
  NewLine   : Array[1..255] of RecAnsiBufferChar;
  Count     : LongInt;
  LineSize  : Byte;
  StartY    : Byte;
  StartLine : LongInt;
  EndLine   : LongInt;
  First     : Boolean = True;

  Procedure Update;
  Var
    NewY : LongInt;
  Begin
    NewY := StartY + EndLine - StartLine + 1;

    If NewY > WinSize Then NewY := WinSize;

    If CurY > WinSize Then
      ScrollDown(True)
    Else
      DrawPage (StartY, NewY, True);
  End;

Begin
  FillChar (WrapData, SizeOf(WrapData), #0);

  Count     := CurLine;
  StartY    := CurY;
  StartLine := Count;

  While Count <= MaxMsgLines Do Begin
    If Count > LastLine Then LastLine := Count;

    FillChar (TempStr, SizeOf(TempStr), #0);
    Move     (Ansi.Data[Count], TempStr, SizeOf(Ansi.Data[Count]));

    If Not IsBlankLine(WrapData, 255) Then Begin
      If IsBlankLine(TempStr, 255) Then Begin
        If Count < LastLine Then Begin
          InsertLine(Count);
          EndLine := MaxMsgLines;
        End Else
          EndLine := Count;

        Move (WrapData, ANSI.Data[Count], SizeOf(Ansi.Data[Count]));

        Update;

        Exit;
      End;

      FillChar (NewLine, SizeOf(NewLine), #0);

      LineSize := GetLineLength(WrapData, 255);

      Move (WrapData, NewLine, LineSize * SizeOf(RecAnsiBufferChar));

      NewLine[LineSize + 1].Ch   := ' ';
      NewLine[LineSize + 1].Attr := WrapData[LineSize].Attr;

      Move (TempStr, NewLine[LineSize + 2], GetLineLength(TempStr, 255) * SizeOf(RecAnsiBufferChar));
      Move (NewLine, TempStr, SizeOf(NewLine));
    End;

    FillChar (WrapData, SizeOf(WrapData), #0);

    LineSize := GetWrapPos(TempStr, 255, RowSize);

    If LineSize > 0 Then Begin
      Move     (TempStr[LineSize], WrapData, (GetLineLength(TempStr, 255) - LineSize + 1) * SizeOf(RecAnsiBufferChar));
      FillChar (TempStr[LineSize], (255 - LineSize) * SizeOf(RecAnsiBufferChar), #0);

      TrimLeft (WrapData, 255);

      If First Then Begin
        If CurX > LineSize Then Begin
          CurX := CurX - LineSize;

          Inc (CurY);
          Inc (CurLine);
        End;

        First := False;
      End;
    End;

    FillChar (ANSI.Data[Count], SizeOf(ANSI.Data[Count]), #0);
    Move     (TempStr, ANSI.Data[Count], RowSize * SizeOf(RecAnsiBufferChar));

    If LineSize = 0 Then Begin
      EndLine := Count;

      Update;

      Exit;
    End;

    Inc (Count);
  End;
End;

Procedure TEditorANSI.ToggleInsert (Toggle: Boolean);
Begin
  If Toggle Then InsertMode := Not InsertMode;

  Session.io.AnsiColor  (Session.io.ScreenInfo[3].A);
  Session.io.AnsiGotoXY (Session.io.ScreenInfo[3].X, Session.io.ScreenInfo[3].Y);

  If InsertMode Then Session.io.BufAddStr('INS') Else Session.io.BufAddStr('OVR'); { ++lang++ }
End;

Procedure TEditorANSI.ReDrawTemplate (Reset: Boolean);
Var
  Count      : LongInt;
  Temp       : Byte;
  StrGlyph   : String[3];
  StrInsert  : String[3];
  StrCharSet : String;
Begin
  FillChar (Session.io.ScreenInfo, SizeOf(Session.io.ScreenInfo), 0);

  TBBSCore(Owner).io.AllowArrow := True;

  If DrawMode Then Begin
    // NOTES
    // start in glyph mode, not character mode?
    // ctrl-a = attribute?
    // ctrl-d = enter into draw mode from editor?
    // ctrl-z = help
    // ctrl-? = toggle glyph/draw mode (draw mode sounds better?)
    // ctrl-? = change glyph set
    // ctrl-b = disable during draw mode or reuse as something else
    // ctrl-v = toggle insert and update status line
    // ctrl-q = exit ansi editor and go back to normal?
    // ctrl-u = upload ansi file?
    // temporarily build status bar until we template it

    If InsertMode Then StrInsert := 'INS' Else StrInsert := 'OVR';
    If GlyphMode  Then StrGlyph  := 'GLY' Else StrGlyph  := 'CHR';

    StrCharSet := '';

    For Count := 1 to 10 Do Begin
      If Count = 10 Then
        Temp := 0
      Else
        Temp := Count;

      StrCharSet := StrCharSet + strI2S(Temp) + GlyphTypeStr[GlyphPtr][Count] + ' ';
    End;

    Session.io.ScreenInfo[1].Y := 2;
    Session.io.ScreenInfo[1].A := 7;
    Session.io.ScreenInfo[2].Y := TBBSCore(Owner).User.ThisUser.ScreenSize - 1;
    Session.io.ScreenInfo[2].A := 9;

    Session.io.AnsiColor(7);
    Session.io.AnsiClear;

    WriteXY (1, 1, 8, '[');
    WriteXY (2, 1, 15, 'X');
    WriteXY (3, 1, 8, ':');
    WriteXY (7, 1, 15, 'Y');
    WriteXY (8, 1, 8, ':');
    WriteXY (14, 1, 8, ']');
    WriteXY (21, 1, 8, '[');
    WriteXY (22, 1, 7, StrInsert);
    WriteXY (25, 1, 8, '] [');
    WriteXY (28, 1, 7, StrGlyph);
    WriteXY (31, 1, 8, '] <');
    WriteXY (33, 1, 7, 'CTRL');
    WriteXY (37, 1, 8, '+');
    WriteXY (38, 1, 7, 'Z ');
    WriteXY (40, 1, 15, 'Help');
    WriteXY (44, 1, 8, '> #' + StrZero(GlyphPtr));
    WriteXY (51, 1, 112, StrCharSet);
    WriteXY     (16, 1, CurAttr, 'ATTR');
  End Else If FileMode Then Begin
    Session.io.ScreenInfo[1].Y := 2;
    Session.io.ScreenInfo[1].A := 7;
    Session.io.ScreenInfo[2].Y := TBBSCore(Owner).User.ThisUser.ScreenSize - 1;
    Session.io.ScreenInfo[2].A := 7;

    Session.io.AnsiColor(7);
    Session.io.AnsiClear;
    DrawFileStatusBar;
  End Else Begin
    Session.io.PromptInfo[2] := Subject;
    Session.io.OutFile (Template, True, 0);

    ToggleInsert (False);
  End;

  WinX1  := 1;
  WinX2  := MaxMsgCols; //79
//  WinX1    := Session.io.ScreenInfo[1].X;
//  WinX2    := Session.io.ScreenInfo[2].X;
  WinY1    := Session.io.ScreenInfo[1].Y;
  WinY2    := Session.io.ScreenInfo[2].Y;

  WinSize  := WinY2 - WinY1 + 1;
  RowSize  := WinX2 - WinX1 + 1;
  // if rowsize > msgmaxcols then rowsize := maxmsgcols;
  ClearEOL := RowSize >= 79;

  If Reset Then Begin
    CurX      := 1;
    CurY      := 1;
    CurAttr   := Session.io.ScreenInfo[1].A;
    QuoteAttr := Session.io.ScreenInfo[2].A;

    FindLastLine;

    If LastLine > 1 Then
      For Count := 1 to LastLine Do
        If Session.Msgs.IsQuotedText(GetLineText(Count)) Then
          ANSI.SetLineColor(QuoteAttr, Count)
        Else
          ANSI.SetLineColor(CurAttr, Count);
  End;

  DrawPage (1, WinSize, False);
End;
Procedure TEditorANSI.LocateCursor;
Begin
  CurLength := GetLineLength(ANSI.Data[CurLine], RowSize);

  If CurX < 1         Then CurX := 1;
  If CurX > CurLength Then CurX := CurLength + 1;
  If CurY < 1         Then CurY := 1;

  While TopLine + CurY - 1 > LastLine Do
    Dec (CurY);

  If DrawMode Then Begin
    // update X/Y position

    With TBBSCore(Owner).io Do Begin
      AnsiColor  (7);
      AnsiGotoXY (4, 1);
      BufAddStr  (strI2S(CurX));
      AnsiGotoXY (9, 1);
      BufAddStr  (strI2S(CurLine));
    End;
  End;

//  With TBBSCore(Owner).io Do Begin
//    AnsiGotoXY (1, 1);
//    BufAddStr  ('X:' + strI2S(CurX) + ' Y:' + strI2S(CurY) + ' CL:' + strI2S(CurLine) + ' TopL:' + strI2S(TopLine) + ' Last:' + strI2S(LastLine) + ' Len:' + strI2S(GetLineLength(ANSI.Data[CurLine], 80)) + ' Row:' + strI2S(RowSize) + '          ');
//  End;

  With TBBSCore(Owner).io Do Begin
    AnsiGotoXY (WinX1 + CurX - 1, WinY1 + CurY - 1);
    AnsiColor  (CurAttr);

    BufFlush;
  End;
End;

Procedure TEditorANSI.DrawPage (StartY, EndY: Byte; ExitEOF: Boolean);
Var
  CountY : LongInt;
Begin
  TBBSCore(Owner).io.Buffer.Start;  // A61

  For CountY := StartY to EndY Do Begin
    If TopLine + CountY - 1 > LastLine + 1 Then Begin
      TBBSCore(Owner).io.AnsiGotoXY (WinX1, WinY1 + CountY - 1);
      TBBSCore(Owner).io.AnsiColor  (7);

      If ClearEOL Then
        TBBSCore(Owner).io.AnsiClrEOL
      Else
        TBBSCore(Owner).io.BufAddStr (strRep(' ', RowSize));
    End Else
    If TopLine + CountY - 1 = LastLine + 1 Then Begin
      TBBSCore(Owner).io.AnsiGotoXY (WinX1, WinY1 + CountY - 1);
      TBBSCore(Owner).io.AnsiColor  (8);
      TBBSCore(Owner).io.BufAddStr  (strPadC('(END)', RowSize, ' '));

      If ExitEOF Then Begin
        TBBSCore(Owner).io.Buffer.Stop;  // A61
        TBBSCore(Owner).io.BufFlush;
        Exit;
      End;
    End Else
      DrawLine (TopLine + CountY - 1, 1, CountY);
  End;

  TBBSCore(Owner).io.Buffer.Stop;  // A61
  TBBSCore(Owner).io.BufFlush;
End;

Procedure TEditorANSI.ScrollUp;
Var
  NewTop : LongInt;
Begin
  NewTop := TopLine - (WinSize DIV 2) + 1;

  If NewTop < 1 Then NewTop := 1;

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  DrawPage(1, WinSize, False);
End;

Procedure TEditorANSI.ScrollDown (Draw: Boolean);
Var
  NewTop : LongInt;
Begin
  NewTop := TopLine + (WinSize DIV 2) + 1;

  While NewTop >= MaxMsgLines Do
    Dec (NewTop, 2);

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  If Draw Then
    DrawPage(1, WinSize, False);
End;

Function TEditorANSI.LineUp (Reset: Boolean) : Boolean;
Begin
  Result := False;

  If CurLine = 1 Then Exit;

  Dec (CurLine);
  Dec (CurY);

  // might be able to use curlength
  If Reset or (CurX > GetLineLength(ANSI.Data[CurLine], 80)) Then
    CurX := GetLineLength(ANSI.Data[CurLine], 80) + 1;

  If CurY < 1 Then Begin
    ScrollUp;

    Result := True;
  End;
End;

Function TEditorANSI.LineDown (Reset: Boolean) : Boolean;
Begin
  Result := False;

  If CurLine >= LastLine Then Exit;
//  If CurLine >= MaxMsgLines Then Exit;

  Inc (CurLine);
  Inc (CurY);

  If Reset Then CurX := 1;

  If CurX > GetLineLength(ANSI.Data[CurLine], 80) Then
    CurX := GetLineLength(ANSI.Data[CurLine], 80) + 1;

  If CurY > WinSize Then Begin
    Result := True;

    ScrollDown(True);
  End;
End;

Procedure TEditorANSI.DrawLine (Line: LongInt; XP, YP: Byte);
Var
  Count   : Byte;
  LineLen : Byte;
Begin
  TBBSCore(Owner).io.AnsiGotoXY (WinX1 + XP - 1, WinY1 + YP - 1);

  LineLen := GetLineLength(ANSI.Data[Line], RowSize);

  For Count := XP to LineLen Do Begin
    If ANSI.Data[Line][Count].Ch = #0 Then Begin
      TBBSCore(Owner).io.AnsiColor  (7);
      TBBSCore(Owner).io.BufAddChar (' ');
    End Else Begin
      TBBSCore(Owner).io.AnsiColor  (ANSI.Data[Line][Count].Attr);
      TBBSCore(Owner).io.BufAddChar (ANSI.Data[Line][Count].Ch);
    End;
  End;

  If LineLen < RowSize Then
    If ClearEOL Then Begin
      TBBSCore(Owner).io.AnsiColor (7);
      TBBSCore(Owner).io.AnsiClrEOL;
    End Else Begin
      TBBSCore(Owner).io.AnsiColor (7);
      TBBSCore(Owner).io.BufAddStr (strRep(' ', RowSize - LineLen));

    End;
End;

Procedure TEditorANSI.DoDelete;
Var
  JoinLen : Byte;
  JoinPos : Byte;
  JoinBuf : Array[1..255] of RecAnsiBufferChar;
Begin
  If CurX <= CurLength Then Begin
    Move (ANSI.Data[CurLine][CurX + 1], ANSI.Data[CurLine][CurX], (CurLength - CurX + 1) * SizeOf(RecAnsiBufferChar));

    ANSI.Data[CurLine][CurLength].Ch := #0;

    DrawLine (CurLine, CurX, CurY);
  End Else
  If CurLine < LastLine Then
    If (CurLength = 0) and (LastLine > 1) Then Begin
      DeleteLine (CurLine);
      DrawPage   (CurY, WinSize, False);
    End Else Begin
      JoinLen := GetLineLength(ANSI.Data[CurLine + 1], RowSize);

      If CurLength + JoinLen <= RowSize Then Begin
        Move       (ANSI.Data[CurLine + 1], ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * JoinLen);
        DeleteLine (CurLine + 1);
        DrawPage   (CurY, WinSize, False); //optimize
      End Else Begin
        JoinPos := GetWrapPos(ANSI.Data[CurLine + 1], RowSize, RowSize - CurLength);

        If JoinPos > 0 Then Begin
          Move     (ANSI.Data[CurLine + 1], ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * (JoinPos - 1));

          FillChar (JoinBuf, SizeOf(JoinBuf), #0);
          Move     (ANSI.Data[CurLine + 1][JoinPos + 1], JoinBuf, (JoinLen - JoinPos + 1) * SizeOf(RecAnsiBufferChar));
          Move     (JoinBuf, ANSI.Data[CurLine + 1], RowSize * SizeOf(RecAnsiBufferChar));

          DrawPage (CurY, CurY + 1, True);
        End;
      End;

    End;
End;

Procedure TEditorANSI.DoBackSpace;
Var
  JoinPos : Byte;
  JoinBuf : Array[1..255] of RecAnsiBufferChar;
Begin
  If CurX > 1 Then Begin
    Dec  (CurX);
    Move (ANSI.Data[CurLine][CurX + 1], ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * (80 - CurX + 1));

    ANSI.Data[CurLine][80].Ch := #0;

    If CurX > GetLineLength(ANSI.Data[CurLine], 80) Then
      TBBSCore(Owner).io.OutBS(1, True)
    Else
      DrawLine (CurLine, CurX, CurY);
  End Else
  If CurLine > 1 Then Begin
    If GetLineLength(ANSI.Data[CurLine - 1], 80) + CurLength <= RowSize Then Begin
      CurX := GetLineLength(ANSI.Data[CurLine - 1], 80) + 1;

      Move (ANSI.Data[CurLine], ANSI.Data[CurLine - 1][CurX], SizeOf(RecAnsiBufferChar) * CurLength);

      DeleteLine (CurLine);

      If Not LineUp(False) Then DrawPage (CurY, WinSize, False); //optimize
    End Else Begin
      JoinPos := GetWrapPos(ANSI.Data[CurLine], RowSize, RowSize - GetLineLength(ANSI.Data[CurLine - 1], RowSize));

      If JoinPos > 0 Then Begin
        CurX := GetLineLength(ANSI.Data[CurLine - 1], 80) + 1;

        Move     (ANSI.Data[CurLine], ANSI.Data[CurLine - 1][CurX], SizeOf(RecAnsiBufferChar) * (JoinPos - 1));
        FillChar (JoinBuf, SizeOf(JoinBuf), #0);
        Move     (ANSI.Data[CurLine][JoinPos + 1], JoinBuf, (CurLength - JoinPos + 1) * SizeOf(RecAnsiBufferChar));
        Move     (JoinBuf, ANSI.Data[CurLine], RowSize * SizeOf(RecAnsiBufferChar));

        If Not LineUp(False) Then DrawPage (CurY, WinSize, False);
      End Else Begin
        LineUp(False);

        CurX := CurLength + 1;
      End;
    End;
  End;
End;

Procedure TEditorANSI.DoChar (Ch: Char);
Var
  CharAttr : Byte;
Begin
  CharAttr := CurAttr;

  If DrawMode Then Begin
    If (Ch in ['0'..'9']) And GlyphMode Then
      Ch := GlyphTypeStr[GlyphPtr][strS2I(Ch) + 1]
  End Else
    If (Session.io.ScreenInfo[6].A <> 0) and (Pos(Ch, '0123456789') > 0) Then
      CharAttr := Session.io.ScreenInfo[6].A
    Else
    If (Session.io.ScreenInfo[5].A <> 0) and (Pos(Ch, '.,!@#$%^&*()_+-=~`''"?;:<>\/[]{}|') > 0) Then
      CharAttr := Session.io.ScreenInfo[5].A
    Else
    If (Session.io.ScreenInfo[4].A <> 0) and (Ch = UpCase(Ch)) Then
      CharAttr := Session.io.ScreenInfo[4].A;

  If InsertMode Then Begin
    Move (ANSI.Data[CurLine][CurX], ANSI.Data[CurLine][CurX + 1], SizeOf(RecAnsiBufferChar) * (CurLength - CurX + 1));

    ANSI.Data[CurLine][CurX].Ch   := Ch;
    ANSI.Data[CurLine][CurX].Attr := CharAttr;

    If CurLength < RowSize {-1} Then Begin
      If CurX <= CurLength Then
        DrawLine (CurLine, CurX, CurY)
      Else Begin
        TBBSCore(Owner).io.AnsiColor  (CharAttr);
        TBBSCore(Owner).io.BufAddChar (Ch);
      End;

      Inc (CurX);
    End Else Begin
      Inc (CurX);

      WordWrap;
    End;
  End Else
  If CurX <= RowSize Then Begin
    ANSI.Data[CurLine][CurX].Ch   := Ch;
    ANSI.Data[CurLine][CurX].Attr := CharAttr;

    TBBSCore(Owner).io.AnsiColor  (CharAttr);
    TBBSCore(Owner).io.BufAddChar (Ch);

    Inc (CurX);
  End;
End;

Procedure TEditorANSI.PageUp;
Var
  NewTop : LongInt;
Begin
  If CurLine = 1 Then Exit;

  If TopLine = 1 Then Begin
    CurLine := 1;
    CurY    := 1;
    CurX    := 1;

    Exit;
  End;

  Dec (CurLine, WinSize);

  If CurLine < 1 Then Begin
    CurLine := 1;
    NewTop  := 1;
  End Else Begin
    NewTop := TopLine - WinSize;

    If NewTop < 1 Then NewTop := 1;
  End;

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  DrawPage (1, WinSize, False);
End;

Procedure TEditorANSI.PageDown;
Var
  NewTop : LongInt;
Begin
  If CurLine = LastLine Then Exit;

  If (LastLine > TopLine) And (LastLine <= TopLine + WinSize - 1) Then Begin
    CurLine := LastLine;
    CurY    := CurLine - TopLine + 1;
    CurX    := 1;

    Exit;
  End;

  Inc (CurLine, WinSize);

  If CurLine > LastLine Then CurLine := LastLine;

  NewTop := TopLine + WinSize;

  While NewTop >= LastLine - (WinSize DIV 2) Do
    Dec (NewTop);

  If NewTop < 1 Then NewTop := 1;

  CurY    := CurLine - NewTop + 1;
  TopLine := NewTop;

  DrawPage (1, WinSize, False);
End;

Procedure TEditorANSI.DoEnter;
Var
  TempLine : RecAnsiBufferLine;
Begin
  If InsertMode and IsBlankLine(ANSI.Data[MaxMsgLines], 80) Then Begin
    If CurX > CurLength Then Begin
      InsertLine (CurLine + 1);

      If Not LineDown(True) Then DrawPage(CurY, WinSize, True);
    End Else Begin
      TempLine := ANSI.Data[CurLine];

      InsertLine (CurLine + 1);

      FillChar (ANSI.Data[CurLine][CurX], SizeOf(RecAnsiBufferChar) * (80 - CurX + 1), #0);
      Move     (TempLine[CurX], ANSI.Data[CurLine + 1][1], SizeOf(RecAnsiBufferChar) * (80 - CurX + 1));

      If Not LineDown(True) Then
        DrawPage (CurY - 1, WinSize, True);
    End;
  End Else Begin
    If CurLine = LastLine Then
      InsertLine (CurLine + 1);

    If Not LineDown(True) Then
      DrawPage (CurY - 1, WinSize, True);
  End;
End;

Procedure TEditorANSI.Quote;
Var
  InFile   : Text;
  Start    : Integer;
  Finish   : Integer;
  NumLines : Integer;
  Text     : Array[1..mysMaxMsgLines] of String[80];
  PI1      : String;
  PI2      : String;
Begin
  Assign (InFile, Session.TempPath + 'msgtmp');
  {$I-} Reset (InFile); {$I+}
  If IoResult <> 0 Then Begin
    Session.io.OutFullLn (Session.GetPrompt(158));
    Exit;
  End;

  NumLines := 0;

  Session.io.AllowPause := True;

  While Not Eof(InFile) Do Begin
    Inc    (NumLines);
    ReadLn (InFile, Text[NumLines]);
  End;

  Close (InFile);

  PI1 := Session.io.PromptInfo[1];
  PI2 := Session.io.PromptInfo[2];

  Session.io.OutFullLn('|CL' + Session.GetPrompt(452));

  For Start := 1 to NumLines Do Begin
    Session.io.PromptInfo[1] := strI2S(Start);
    Session.io.PromptInfo[2] := Text[Start];

    Session.io.OutFullLn (Session.GetPrompt(341));

    If (Session.io.PausePtr >= Session.User.ThisUser.ScreenSize) and (Session.io.AllowPause) Then
      Case Session.io.MorePrompt of
        'N' : Break;
        'C' : Session.io.AllowPause := False;
      End;
  End;

  Session.io.AllowPause := True;

  Session.io.OutFull (Session.GetPrompt(159));
  Start := strS2I(Session.io.GetInput(3, 3, 11, ''));

  Session.io.OutFull (Session.GetPrompt(160));

  Finish := strS2I(Session.io.GetInput(3, 3, 11, ''));

  If (Start > 0) and (Start <= NumLines) and (Finish <= NumLines) Then Begin
    If Finish = 0 Then Finish := Start;

    For NumLines := Start to Finish Do Begin
      If LastLine = MaxMsgLines Then Break;

      If Not IsBlankLine(Ansi.Data[CurLine], 80) Then Begin
        Inc (CurLine);
        Inc (CurY);

        InsertLine (CurLine);
      End;

      SetLineText (CurLine, Text[NumLines]);
      ANSI.SetLineColor (QuoteAttr, CurLine);

      If CurY > WinSize Then
        ScrollDown(False);
    End;
  End;

  If CurLine < MaxMsgLines Then Begin
    Inc (CurLine);
    Inc (CurY);

    InsertLine(CurLine);

    If CurY > WinSize Then
      ScrollDown(False);
  End;

  Session.io.PromptInfo[1] := PI1;
  Session.io.PromptInfo[2] := PI2;
End;

Procedure TEditorANSI.QuoteWindow;
Var
  QText      : Array[1..mysMaxMsgLines] of String[79];
  QTextSize  : Byte;
  InFile     : Text;
  QuoteLines : Integer;
  NoMore     : Boolean;

  Procedure UpdateBar (On: Boolean);
  Begin
    Session.io.AnsiGotoXY (1, QuoteCurLine + Session.io.ScreenInfo[2].Y);

    If On Then
      Session.io.AnsiColor (Session.io.ScreenInfo[3].A)
    Else
      Session.io.AnsiColor (Session.io.ScreenInfo[2].A);

    Session.io.BufAddStr (strPadR(QText[QuoteTopPage + QuoteCurLine], 79, ' '));
  End;

  Procedure UpdateWindow;
  Var
    Count : Integer;
  Begin
    Session.io.AnsiGotoXY (1, Session.io.ScreenInfo[2].Y);
    Session.io.AnsiColor  (Session.io.ScreenInfo[2].A);

    For Count := QuoteTopPage to QuoteTopPage + QTextSize - 1 Do Begin
      If Count <= QuoteLines Then Session.io.BufAddStr (QText[Count]);

      Session.io.AnsiClrEOL;

      If Count <= QuoteLines Then Session.io.BufAddStr(#13#10);
    End;

    UpdateBar(True);
  End;

Var
  Ch          : Char;
  QWinSize    : Byte;
  QWinDataPos : Byte;
  QWinData    : Array[1..15] of String[79];

  Procedure AddQuoteWin (S: String);
  Var
    Count : Byte;
  Begin
    If QWinDataPos < QWinSize Then Begin
      Inc (QWinDataPos);
    End Else Begin
      For Count := 2 to QWinSize Do
        QWinData[Count - 1] := QWinData[Count]
    End;

    QWinData[QWinDataPos] := S;
  End;

  Procedure DrawQWin;
  Var
    Count : Byte;
  Begin
    Session.io.AnsiColor (Session.io.ScreenInfo[1].A);

    For Count := 1 to QWinSize + 1 Do Begin
      Session.io.AnsiGotoXY (WinX1, WinY1 + Count - 1);

      If Count <= QWinSize Then
        Session.io.BufAddStr(QWinData[Count]);

      Session.io.AnsiClrEOL;
    End;
  End;

Var
  Temp  : Integer;
  Added : Boolean = False;
Begin
  Assign (InFile, Session.TempPath + 'msgtmp');
  {$I-} Reset(InFile); {$I+}

  If IoResult <> 0 Then Exit;

  NoMore       := False;
  QWinDataPos  := 0;
  QuoteLines   := 0;

  While Not Eof(InFile) Do Begin
    Inc    (QuoteLines);
    ReadLn (InFile, QText[QuoteLines]);
  End;

  Close (InFile);

  Session.io.OutFile ('ansiquot', True, 0);

  FillChar (QWinData, SizeOf(QWinData), 0);

  QTextSize := Session.io.ScreenInfo[3].Y - Session.io.ScreenInfo[2].Y + 1;
  QWinSize  := Session.io.ScreenInfo[1].Y - WinY1 + 1;

  For Temp := CurLine - ((QWinSize DIV 2) + 1) To CurLine - 1 Do
    If Temp >= 1 Then AddQuoteWin(GetLineText(Temp));

  DrawQWin;
  UpdateWindow;

  Repeat
    Ch := Session.io.GetKey;

    If Session.io.IsArrow Then Begin
      Case Ch of
        #71 : If QuoteCurLine > 0 Then Begin
                QuoteTopPage := 1;
                QuoteCurLine := 0;
                NoMore       := False;

                UpdateWindow;
              End;
        #72 : Begin
                If QuoteCurLine > 0 Then Begin
                  UpdateBar(False);

                  Dec(QuoteCurLine);

                  UpdateBar(True);
                End Else
                If QuoteTopPage > 1 Then Begin
                  Dec (QuoteTopPage);

                  UpdateWindow;
                End;

                NoMore := False;
              End;
        #73,
        #75 : Begin
                If QuoteTopPage > QTextSize Then
                  Dec (QuoteTopPage, QTextSize)
                Else Begin
                  QuoteTopPage := 1;
                  QuoteCurLine := 0;
                End;

                NoMore := False;

                UpdateWindow;
              End;
        #79 : Begin
                If QuoteLines <= QTextSize Then
                  QuoteCurLine := QuoteLines - QuoteTopPage
                Else Begin
                  QuoteTopPage := QuoteLines - QTextSize + 1;
                  QuoteCurLine := QTextSize - 1;
                End;

                UpdateWindow;
              End;
        #80 : If QuoteTopPage + QuoteCurLine < QuoteLines Then Begin
                If QuoteCurLine = QTextSize - 1 Then Begin
                  Inc (QuoteTopPage);

                  UpdateWindow;
                End Else Begin
                  UpdateBar(False);

                  Inc (QuoteCurLine);

                  UpdateBar(True);
                End;
              End;
        #77,
        #81 : Begin
                If QuoteLines <= QTextSize Then
                  QuoteCurLine := QuoteLines - QuoteTopPage
                Else
                If QuoteTopPage + QTextSize - 1 < QuoteLines - QTextSize + 1 Then
                  Inc (QuoteTopPage, QTextSize)
                Else Begin
                  QuoteTopPage := QuoteLines - QTextSize + 1;
                  QuoteCurLine := QTextSize - 1;
                End;

                UpdateWindow;
              End;
      End;
    End Else
      Case Ch of
        #27 : Break;
        #13 : If (LastLine < MaxMsgLines) and (Not NoMore) Then Begin

                If QuoteTopPage + QuoteCurLine = QuoteLines Then NoMore := True;

                InsertLine  (CurLine);
                SetLineText (CurLine, QText[QuoteTopPage + QuoteCurLine]);

                Added := True;

                ANSI.SetLineColor (QuoteAttr, CurLine);

                Inc (CurLine);
                Inc (CurY);

                If CurY > WinSize Then
                  ScrollDown(False);

                AddQuoteWin(QText[QuoteTopPage + QuoteCurLine]);
                DrawQWin;

                If QuoteTopPage + QuoteCurLine < QuoteLines Then
                  If QuoteCurLine = QTextSize - 1 Then Begin
                    Inc (QuoteTopPage);

                    UpdateWindow;
                  End Else Begin
                    UpdateBar(False);

                    Inc (QuoteCurLine);

                    UpdateBar(True);
                  End;
              End;
      End;
  Until False;

  Session.io.OutFull('|16');

  If Added And (CurLine < MaxMsgLines) Then Begin
    Inc (CurLine);
    Inc (CurY);

    InsertLine(CurLine);

    If CurY > WinSize Then
      ScrollDown(False);
  End;
End;

Procedure TEditorANSI.EditorCommands;
Var
  Ch  : Char;
  Str : String;
Begin
  Done := False;
  Save := False;

  Repeat
    Session.io.OutFull (Session.GetPrompt(354));

//    {$IFDEF TESTEDITOR}
    Ch := Session.io.OneKey ('?ACDHQRSTU', True);
//    {$ELSE}
//    Ch := Session.io.OneKey ('?ACHQRSTU', True);
//    {$ENDIF}

    Case Ch of
      '?' : Session.io.OutFullLn (Session.GetPrompt(355));
      'A' : If Forced Then Begin
              Session.io.OutFull (Session.GetPrompt(307));
              Exit;
            End Else Begin
              Done := Session.io.GetYN(Session.GetPrompt(356), False);

              Exit;
            End;
      'C' : Exit;
      'D' : Begin
              DrawMode    := True;
              SavedInsert := InsertMode;
              InsertMode  := False;

              Exit;
            End;
      'H' : Begin
              Session.io.OutFile ('fshelp', True, 0);
              Exit;
            End;
      'Q' : Begin
              If Session.User.ThisUser.UseLBQuote Then
                QuoteWindow
              Else
                Quote;
              Exit;
            End;
      'R' : Exit;
      'S' : Begin
              Save := True;
              Done := True;
            End;
      'T' : Begin
              Session.io.OutFull(Session.GetPrompt(463));
              Str := Session.io.GetInput(60, 60, 11, Subject);
              If Str <> '' Then Subject := Str;
              Session.io.PromptInfo[2] := Subject;
              Exit;
            End;
      'U' : Begin
              MessageUpload;
              Exit;
            End;
    End;
  Until Done;
End;


Function FilePickerDialog (APath, AMask: String) : String;
Var
  Box     : TAnsiMenuBox;
  Img     : TConsoleImageRec;
  DirInfo : SearchRec;
  FName   : Array[1..50] of String[80];
  FSize   : Array[1..50] of LongInt;
  FIsDir  : Array[1..50] of Boolean;
  Count   : Integer;
  Pick    : Integer;
  Top     : Integer;
  MaxShow : Integer;
  Row     : Integer;
  Ch      : Char;
  CurPath : String;
  Done    : Boolean;
  DelFile : File;

  Procedure ScanDir;
  Begin
    Count := 0;
    Inc(Count); FName[Count] := '..'; FSize[Count] := 0; FIsDir[Count] := True;
    FindFirst(CurPath + '*.*', $10, DirInfo);
    While (DosError = 0) and (Count < 40) Do Begin
      If (DirInfo.Attr And $10 <> 0) and (DirInfo.Name <> '.') and (DirInfo.Name <> '..') Then Begin
        Inc(Count);
        FName[Count] := DirInfo.Name + PathChar;
        FSize[Count] := 0;
        FIsDir[Count] := True;
      End;
      FindNext(DirInfo);
    End;
    FindClose(DirInfo);
    FindFirst(CurPath + AMask, $27, DirInfo);
    While (DosError = 0) and (Count < 50) Do Begin
      If DirInfo.Attr And $10 = 0 Then Begin
        Inc(Count);
        FName[Count] := DirInfo.Name;
        FSize[Count] := DirInfo.Size;
        FIsDir[Count] := False;
      End;
      FindNext(DirInfo);
    End;
    FindClose(DirInfo);
  End;

  Procedure DrawList;
  Var K, Attr: Integer;
      SizeStr: String;
  Begin
    WriteXY(10, 5, 11, strPadR(' ' + CurPath + AMask, 42, ' '));
    For K := 1 to MaxShow Do Begin
      If Top + K <= Count Then Begin
        If Top + K = Pick Then Attr := 112
        Else If FIsDir[Top + K] Then Attr := 11
        Else Attr := 7;
        If FIsDir[Top + K] Then
          SizeStr := '   <DIR>'
        Else
          SizeStr := strPadL(strI2S(FSize[Top + K]), 8, ' ');
        WriteXY(10, 5 + K, Attr, strPadR(' ' + FName[Top + K], 33, ' ') + SizeStr + ' ');
      End Else
        WriteXY(10, 5 + K, 7, strRep(' ', 42));
    End;
  End;

Begin
  Result  := '';
  CurPath := APath;
  MaxShow := 15;
  Done    := False;

  Console.GetScreenImage(8, 4, 54, 5 + MaxShow + 1, Img);
  Box := TAnsiMenuBox.Create;
  Box.Open(8, 4, 54, 5 + MaxShow + 1);

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
              #83 : Begin { DELETE key }
                      If (Pick >= 1) and (Pick <= Count) and (Not FIsDir[Pick]) Then Begin
                        If ShowMsgBox(1, 'Delete ' + FName[Pick] + '?') Then Begin
                          Assign(DelFile, CurPath + FName[Pick]);
                          {$I-} Erase(DelFile); {$I+}
                          If IOResult = 0 Then;
                          ScanDir;
                          If Pick > Count Then Pick := Count;
                          If Pick < 1 Then Pick := 1;
                          DrawList;
                        End;
                      End;
                    End;
            End;
      #13 : Begin
              If (Pick >= 1) and (Pick <= Count) Then Begin
                If FIsDir[Pick] Then Begin
                  If FName[Pick] = '..' Then Begin
                    If Length(CurPath) > 1 Then Begin
                      Delete(CurPath, Length(CurPath), 1);
                      While (Length(CurPath) > 0) and
                            (CurPath[Length(CurPath)] <> PathChar) Do
                        Delete(CurPath, Length(CurPath), 1);
                    End;
                  End Else
                    CurPath := CurPath + Copy(FName[Pick], 1, Length(FName[Pick]) - 1) + PathChar;
                  ScanDir; Pick := 1; Top := 0; DrawList;
                End Else Begin
                  Result := CurPath + FName[Pick];
                  Done := True;
                End;
              End;
            End;
    End;
  Until Done;

  Box.Close;
  Box.Free;
  Session.io.RemoteRestore(Img);
End;

Procedure TEditorANSI.DrawCommands;
Var
  Box      : TAnsiMenuBox;
  Ch       : Char;
  ColorStr : String;
  Img      : TConsoleImageRec;
  OpenFile : File;
  SaveFile : Text;
  OpenBuf  : Array[1..4096] of Char;
  OpenLen  : LongInt;
  FG       : Byte;
  BG       : Byte;
  Row      : Byte;
  Col      : Byte;
  GSet     : Byte;

  Procedure DrawMenu;
  Var C, G: Byte;
  Begin
    { Title }
    WriteXY (18, 7, 15, strPadC('Draw Menu (ESC/Close)', 44, ' '));

    { Foreground colors }
    WriteXY (15, 8, 7, '  >> Foreground');
    For C := 0 to 15 Do
      WriteXY (15 + C * 2, 9, C + C * 16, #219#219);

    { Background colors }
    WriteXY (15, 11, 7, '     Background');
    For C := 0 to 7 Do
      WriteXY (15 + C * 2, 12, C * 16 + 15, #219#219);

    { Highlight selected FG }
    FG := CurAttr And 15;
    BG := (CurAttr And $70) Shr 4;
    WriteXY (15 + FG * 2, 10, 15, #24#24);
    WriteXY (15 + BG * 2, 13, 15, #24#24);

    { Glyph sets a-m }
    For G := 1 to 10 Do Begin
      If G <= 5 Then Begin
        WriteXY (15, 13 + G, 7, Chr(96 + G) + '. ');
        For C := 1 to 10 Do
          WriteXY (17 + (C - 1) * 2, 13 + G, 15, GlyphTypeStr[G][C] + ' ');
      End Else Begin
        WriteXY (37, 8 + G, 7, Chr(96 + G) + '. ');
        For C := 1 to 10 Do
          WriteXY (39 + (C - 1) * 2, 8 + G, 15, GlyphTypeStr[G][C] + ' ');
      End;
    End;

    { FG/BG display }
    WriteXY (15, 20, 11, 'FG:' + strZero(FG));
    WriteXY (24, 20, 11, 'color');
    WriteXY (30, 20, CurAttr, #219#219#219);
    WriteXY (34, 20, 11, 'BG:' + strZero(BG));

    { Commands }
    WriteXY (15, 22, 3, 'O Open File');
    WriteXY (37, 22, 3, '# Keys Normal');
    WriteXY (15, 23, 3, 'S Save File');
    WriteXY (37, 23, 3, 'Q Quit Drawing');
  End;

Begin
  Console.GetScreenImage (13, 6, 60, 24, Img);

  Session.io.BufFlush;

  { Use Mystic's themed box for the frame }
  Box := TAnsiMenuBox.Create;
  Box.Open (13, 6, 60, 24);

  DrawMenu;
  Session.io.BufFlush;

  { Small delay to let any ESC sequence complete }
  Session.io.BufFlush;

  FG := CurAttr And 15;
  BG := (CurAttr And $70) Shr 4;

  Repeat
    Ch := Session.io.GetKey;

    Case Ch of
      #0  : Begin { Arrow keys for CiADraw-style navigation }
              Ch := Session.io.GetKey;
              Case Ch of
                #75 : Begin { Left: FG backward }
                        FG := (CurAttr - 1) And $0F;
                        CurAttr := (CurAttr And $F0) Or FG;
                        DrawMenu;
                      End;
                #77 : Begin { Right: FG forward }
                        FG := (CurAttr + 1) And $0F;
                        CurAttr := (CurAttr And $F0) Or FG;
                        DrawMenu;
                      End;
                #72 : Begin { Up: BG forward }
                        BG := ((CurAttr Shr 4) + 1) And $07;
                        CurAttr := (CurAttr And $0F) Or (BG Shl 4);
                        DrawMenu;
                      End;
                #80 : Begin { Down: BG backward }
                        BG := ((CurAttr Shr 4) - 1) And $07;
                        CurAttr := (CurAttr And $0F) Or (BG Shl 4);
                        DrawMenu;
                      End;
              End;
            End;
      #27 : Break; { ESC closes menu }
      'Q', 'q' : Begin
              DrawMode   := False;
              InsertMode := SavedInsert;
              Done       := True;
              Save       := False;
              Break;
            End;
      'G', 'g' : Begin
              GlyphMode := Not GlyphMode;
              Break;
            End;
      '#' : Begin
              { Toggle normal key mode }
              GlyphMode := False;
              Break;
            End;
      'O', 'o' : Begin
              Session.io.RemoteRestore(Img);
              ColorStr := FilePickerDialog(bbsCfg.TextPath, '*.ans');
              If (ColorStr <> '') and FileExist(ColorStr) Then Begin
                { Load the ANSI file into the editor buffer }
                ANSI.Clear;
                Assign(OpenFile, ColorStr);
                ioReset(OpenFile, 1, fmReadWrite + fmDenyNone);
                While Not Eof(OpenFile) Do Begin
                  ioBlockRead(OpenFile, OpenBuf, SizeOf(OpenBuf), OpenLen);
                  If ANSI.ProcessBuf(OpenBuf, OpenLen) Then Break;
                End;
                Close(OpenFile);
                Subject   := ColorStr;
                FindLastLine;
                TopLine   := 0;
                CurLine   := 0;
                CurX      := 1;
                CurY      := 1;
              End;
              Break;
            End;
      'S', 's' : Begin
              Session.io.RemoteRestore(Img);
              If Subject = '' Then Begin
                ColorStr := FilePickerDialog(bbsCfg.TextPath, '*.ans');
                If ColorStr = '' Then Begin Break; End;
              End Else
                ColorStr := Subject;
              { Save ANSI data to file }
              Subject := ColorStr;
              Assign(SaveFile, ColorStr);
              {$I-} ReWrite(SaveFile); {$I+}
              If IOResult = 0 Then Begin
                FindLastLine;
                For OpenLen := 1 to LastLine Do
                  WriteLn(SaveFile, GetLineText(OpenLen));
                Close(SaveFile);
              End;
              Break;
            End;
      { Foreground: 0-9 a-f select FG color }
      '0'..'9' : Begin
              FG := Ord(Ch) - Ord('0');
              CurAttr := (CurAttr And $F0) Or FG;
              DrawMenu;
            End;
      'a'..'f' : Begin
              FG := Ord(Ch) - Ord('a') + 10;
              CurAttr := (CurAttr And $F0) Or FG;
              DrawMenu;
            End;
      'A'..'F' : Begin
              FG := Ord(Ch) - Ord('A') + 10;
              CurAttr := (CurAttr And $F0) Or FG;
              DrawMenu;
            End;
      { Background: Alt+0 to Alt+7 or use arrow keys }
      { For now: Shift+1 through Shift+8 (!@#$%^&*) }
      '!' : Begin BG := 0; CurAttr := (CurAttr And $0F) Or (BG Shl 4); DrawMenu; End;
      '@' : Begin BG := 1; CurAttr := (CurAttr And $0F) Or (BG Shl 4); DrawMenu; End;
      '$' : Begin BG := 2; CurAttr := (CurAttr And $0F) Or (BG Shl 4); DrawMenu; End;
      '%' : Begin BG := 3; CurAttr := (CurAttr And $0F) Or (BG Shl 4); DrawMenu; End;
      '^' : Begin BG := 4; CurAttr := (CurAttr And $0F) Or (BG Shl 4); DrawMenu; End;
      '&' : Begin BG := 5; CurAttr := (CurAttr And $0F) Or (BG Shl 4); DrawMenu; End;
      '*' : Begin BG := 6; CurAttr := (CurAttr And $0F) Or (BG Shl 4); DrawMenu; End;
      '(' : Begin BG := 7; CurAttr := (CurAttr And $0F) Or (BG Shl 4); DrawMenu; End;
    End;
  Until False;

  Box.Close;
  Box.Free;
  Session.io.RemoteRestore (Img);
  Session.io.BufFlush;
  ReDrawTemplate (False);
End;

Procedure TEditorANSI.MessageUpload;
Var
  FN : String[100];
  T1 : String[30];
  T2 : String[60];
  OK : Boolean;
  F  : File;
  B  : Array[1..2048] of Char;
  BR : LongInt;
Begin
  OK := False;

  T1 := Session.io.PromptInfo[1];
  T2 := Session.io.PromptInfo[2];

  Session.io.OutFull (Session.GetPrompt(352));

  If Session.LocalMode Then Begin
    FN := Session.io.GetInput(70, 70, 11, '');

    If FN = '' Then Exit;

    OK := FileExist(FN);
  End Else Begin
    FN := Session.TempPath + Session.io.GetInput(70, 70, 11, '');

    If Session.FileBase.SelectProtocol(True, False) = 'Q' Then Exit;

    Session.FileBase.ExecuteProtocol(1, FN);

    OK := Session.FileBase.dszSearch(JustFile(FN));
  End;

  If OK Then Begin
    Assign (F, FN);
    Reset  (F, 1);

    ANSI.Lines := CurLine;
    Ansi.CurX  := CurX;
    Ansi.CurY  := CurLine;

    While Not Eof(F) Do Begin
      BlockRead (F, B, SizeOf(B), BR);

      If BR = 0 Then Break;

      ANSI.ProcessBuf(B, BR);
    End;

    Close(F);
  End;

  If Not Session.LocalMode Then FileErase(FN);

  DirClean (Session.TempPath, 'msgtmp');

  Session.io.PromptInfo[1] := T1;
  Session.io.PromptInfo[2] := T2;

  FindLastLine;
End;

Procedure TEditorANSI.ReformParagraph;
Var
  Line    : LongInt;
  LineLen : Byte;
  JoinPos : Byte;
  JoinLen : Byte;
  JoinBuf : Array[1..255] of RecAnsiBufferChar;
Begin
  Line := CurLine;

  Repeat
    If (Line = LastLine) or IsBlankLine(ANSI.Data[Line], RowSize) Then Break;

    TrimRight (ANSI.Data[Line], RowSize);
    TrimLeft  (ANSI.Data[Line + 1], RowSize);

    LineLen := GetLineLength(ANSI.Data[Line], RowSize);
    JoinLen := GetLineLength(ANSI.Data[Line + 1], RowSize);
    JoinPos := GetWrapPos(ANSI.Data[Line + 1], JoinLen, RowSize - LineLen);

    If JoinLen = 0 Then Break;

    If LineLen + JoinLen < RowSize Then Begin
      Move       (ANSI.Data[Line + 1], ANSI.Data[Line][LineLen + 2], SizeOf(RecAnsiBufferChar) * JoinLen);

      ANSI.Data[Line][LineLen + 1].Ch := ' ';

      DeleteLine (Line + 1);
    End Else
    If JoinPos > 0 Then Begin
      Move     (ANSI.Data[Line + 1], ANSI.Data[Line][LineLen + 2], SizeOf(RecAnsiBufferChar) * (JoinPos - 1));

      ANSI.Data[Line][LineLen + 1].Ch := ' ';

      FillChar (JoinBuf, SizeOf(JoinBuf), #0);
      Move     (ANSI.Data[Line + 1][JoinPos + 1], JoinBuf, (JoinLen - JoinPos + 1) * SizeOf(RecAnsiBufferChar));
      Move     (JoinBuf, ANSI.Data[Line + 1], RowSize * SizeOf(RecAnsiBufferChar));
    End Else
      Inc (Line);
  Until False;

  DrawPage (CurY, WinSize, False);

  // need to optimize this output.
End;

Function TEditorANSI.Edit : Boolean;
Var
  Ch    : Char;
  Count : LongInt;
Begin
  Result       := False;
  QuoteCurLine := 0;
  QuoteTopPage := 1;

  // A55: enable mouse tracking for CIADraw-style drawing in the editor.
  // Only active inside the editor â€” disabled on exit.
  Session.io.MouseEnable;

  ReDrawTemplate(True);

  Repeat
    LocateCursor;

    Ch := TBBSCore(Owner).io.GetKey;

    If Session.io.IsArrow Then Begin
      Case Ch of
        #71 : CurX := 1;
        #72 : LineUp(False);
        #73 : PageUp;
        #75 : If CurX > 1 Then Dec(CurX) Else LineUp(True);
        #77 : If CurX <= CurLength Then Inc(CurX) Else LineDown(True);
        #79 : CurX := CurLength + 1;
        #80 : If CurLine < LastLine Then LineDown(False);
        #81 : PageDown;
        #83 : DoDelete;
      End;
    End Else
      Case Ch of
        ^B   : ReformParagraph;
        ^F   : CurX := 1;
        ^G   : CurX := CurLength + 1;
        ^H   : DoBackSpace;
        ^I   : If CurLength < RowSize Then Begin
                 If (CurX < RowSize) and (CurX MOD 5 = 0) Then
                   DoChar(' ');

                 While (CurX < RowSize) and (CurX MOD 5 <> 0) Do Begin
                   CurLength := GetLineLength(ANSI.Data[CurLine], RowSize);

                   DoChar(' ');
                 End;
               End;
        ^K   : Begin
                 If CutPasted Then Begin
                   CutTextPos := 0;
                   CutPasted  := False;
                 End;

                 If CutTextPos < fseMaxCutText Then Begin
                   Inc (CutTextPos);

                   CutText[CutTextPos] := ANSI.Data[CurLine];

                   DeleteLine(CurLine);

                   DrawPage (CurY, WinSize, False);  //optimize + 1
                 End;
               End;
        ^M   : DoEnter;
        ^O   : Begin
                 Session.io.OutFile('fshelp', True, 0);
                 ReDrawTemplate(False);
               End;
        ^Q   : If Not DrawMode Then Begin
                 If Session.User.ThisUser.UseLBQuote Then
                   QuoteWindow
                 Else
                   Quote;

                 ReDrawTemplate(False);
               End;
        ^U   : If CutTextPos > 0 Then Begin
                 CutPasted := True;

                 For Count := CutTextPos DownTo 1 Do
                   If LastLine < MaxMsgLines Then Begin
                     InsertLine(CurLine);

                     ANSI.Data[CurLine] := CutText[Count];
                   End;

                 DrawPage (CurY, WinSize, False);
               End;
        ^V   : ToggleInsert(True);
        ^Y   : If (CurLine < LastLine) or ((CurLine = LastLine) And Not IsBlankLine(ANSI.Data[CurLine], 80)) Then Begin
                 DeleteLine (CurLine);

                 If CurLine > LastLine Then
                   InsertLine (CurLine);

                 DrawPage (CurY, WinSize, False);
               End;
        ^A   : Begin { CiADraw ALT-A: cycle FG color forward }
                 If DrawMode Then Begin
                   CurAttr := (CurAttr And $F0) Or ((CurAttr + 1) And $0F);
                   ReDrawTemplate(False);
                 End;
               End;
        ^P   : Begin { CiADraw ALT-P: pickup attribute under cursor }
                 If DrawMode Then Begin
                   CurAttr := ANSI.Data[TopLine + CurLine + 1][CurX].Attr;
                   ReDrawTemplate(False);
                 End;
               End;
        ^E   : Begin { CiADraw: cycle BG color forward }
                 If DrawMode Then Begin
                   CurAttr := (CurAttr And $0F) Or (((CurAttr Shr 4) + 1) And $07) Shl 4;
                   ReDrawTemplate(False);
                 End;
               End;
        ^D   : Begin { CiADraw: cycle FG color backward }
                 If DrawMode Then Begin
                   CurAttr := (CurAttr And $F0) Or ((CurAttr - 1) And $0F);
                   ReDrawTemplate(False);
                 End;
               End;
        ^N   : Begin { CiADraw: clear canvas }
                 If DrawMode Then Begin
                   ANSI.Clear;
                   TopLine := 0;
                   CurLine := 0;
                   CurX    := 1;
                   CurY    := WinY1;
                   DrawPage(WinY1, WinY2, False);
                   ReDrawTemplate(False);
                 End;
               End;
        ^X   : Begin { Ctrl+X - exit, ask to save if changed }
                 If FileMode and FileChanged Then Begin
                   If ShowMsgBox(1, 'Save changes before exit?') Then
                     SaveFile;
                 End;
                 Done := True;
                 Save := False;
               End;
        ^Z,
        ^[   : Begin
                 If DrawMode Then
                   DrawCommands
                 Else If FileMode Then
                   FileEditorCommands
                 Else
                   EditorCommands;

                 If (Not Save) and (Not Done) Then ReDrawTemplate(False);
               End;
        #32..
        #254 : If (CurLength >= RowSize) and (GetWrapPos(ANSI.Data[CurLine], RowSize, RowSize) = 0) And InsertMode Then Begin
                 DoEnter;
                 DoChar(Ch);
               End Else
                 If (CurX = 1) and (Ch = '/') and (Not DrawMode) Then Begin
                   EditorCommands;

                   If (Not Save) and (Not Done) Then ReDrawTemplate(False);
                 End Else
                   DoChar(Ch);
      End;
  Until Done;

  Session.io.AllowArrow := False;

  // A55: disable mouse tracking on exit â€” must always be turned off
  Session.io.MouseDisable;

  If Save Then FindLastLine;

  Result := Save;

  Session.io.AnsiGotoXY (1, Session.User.ThisUser.ScreenSize);
End;


Function TEditorANSI.LoadFile (AFileName: String) : Boolean;
Var
  F      : File;
  Buf    : Array[1..4096] of Char;
  BufLen : LongInt;
Begin
  Result := False;

  If Not FileExist(AFileName) Then Begin
    { Create empty file if it doesn't exist }
    Assign(F, AFileName);
    {$I-} ReWrite(F, 1); {$I+}
    If IOResult = 0 Then Close(F);
    FileName    := AFileName;
    FileChanged := False;
    Result      := True;
    Exit;
  End;

  FileName := AFileName;
  ANSI.Clear;

  Assign (F, AFileName);
  ioReset (F, 1, fmReadWrite + fmDenyNone);

  While Not Eof(F) Do Begin
    ioBlockRead (F, Buf, SizeOf(Buf), BufLen);
    If ANSI.ProcessBuf(Buf, BufLen) Then Break;
  End;

  Close (F);
  FindLastLine;
  FileChanged := False;
  Result      := True;
End;

Function TEditorANSI.SaveFile : Boolean;
Var
  F    : Text;
  Line : LongInt;
Begin
  Result := False;
  If FileName = '' Then Exit;

  FindLastLine;

  Assign (F, FileName);
  {$I-} ReWrite (F); {$I+}
  If IOResult <> 0 Then Exit;

  // Write CRLF line endings even on Linux for BBS cross-platform compatibility
  {$IFDEF UNIX}
  SetTextLineEnding(F, #13#10);
  {$ENDIF}

  For Line := 1 to LastLine Do
    WriteLn (F, GetLineText(Line));

  Close (F);
  FileChanged := False;
  Result      := True;
End;

Function TEditorANSI.SaveFileAs (AFileName: String) : Boolean;
Begin
  FileName := AFileName;
  Result   := SaveFile;
End;

Procedure TEditorANSI.DrawFileStatusBar;
Var
  Status : String;
  Pos    : String;
Begin
  If FileReadOnly Then
    Status := 'VIEW ONLY'
  Else If FileName = '' Then
    Status := '      NEW'
  Else If FileChanged Then
    Status := '  CHANGED'
  Else
    Status := '         ';

  Pos := strI2S(TopLine + CurLine) + '/' + strI2S(LastLine);

  WriteXY (1, 1, 112, strPadR(' File: ' + FileName, 60, ' ') + strPadL(Status, 19, ' '));

  If FileReadOnly Then
    WriteXY (1, TBBSCore(Owner).User.ThisUser.ScreenSize, 112,
             strPadR(' ESC/Menu     ^G Goto     ^W Where', 66, ' ') +
             strPadL(Pos, 14, ' '))
  Else
    WriteXY (1, TBBSCore(Owner).User.ThisUser.ScreenSize, 112,
             strPadR(' ESC/Menu     ^G Goto     ^W Where     ^Y Delete     ^K Cut', 66, ' ') +
             strPadL(Pos, 14, ' '));
End;

Procedure TEditorANSI.FileEditorCommands;
Var
  Box  : TAnsiMenuBox;
  Form : TAnsiMenuForm;
  Img  : TConsoleImageRec;
  Res  : Char;
  NewFN: String;
Begin
  Console.GetScreenImage (24, 6, 52, 15, Img);

  Box := TAnsiMenuBox.Create;

  If FileReadOnly Then Begin
    Box.Open (24, 8, 52, 14);

    Form := TAnsiMenuForm.Create;
    Form.ExitOnFirst := True;

    Form.AddNone ('C', ' C Continue',            26,  9, 26,  9, 24, '');
    Form.AddNone ('?', ' ? Help',                26, 10, 26, 10, 24, '');
    Form.AddNone ('\', ' \ Jump to first line',  26, 11, 26, 11, 24, '');
    Form.AddNone ('/', ' / Jump to last line',   26, 12, 26, 12, 24, '');
    Form.AddNone ('Q', ' Q Quit',               26, 13, 26, 13, 24, '');

    Res := Form.Execute;
    Form.Free;
    Box.Close;
    Box.Free;
    Session.io.RemoteRestore (Img);

    Case Res of
      'Q' : Begin Done := True; Save := False; End;
      '\' : Begin TopLine := 0; CurLine := 0; CurY := WinY1;
              DrawPage (WinY1, WinY2, False); LocateCursor; End;
      '/' : Begin FindLastLine;
              If LastLine > WinSize Then Begin
                TopLine := LastLine - WinSize; CurLine := WinSize - 1;
              End Else Begin TopLine := 0; CurLine := LastLine - 1; End;
              CurY := WinY1 + CurLine;
              DrawPage (WinY1, WinY2, False); LocateCursor; End;
    End;
  End Else Begin
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
      'Q' : Begin
              // Bug fix: prompt to save unsaved changes before quitting
              If FileChanged Then Begin
                If ShowMsgBox(1, 'Save changes before exit?') Then
                  SaveFile;
              End;
              Done := True; Save := False;
            End;
      'S' : Begin
              If FileName <> '' Then Begin
                If SaveFile Then Begin
                  DrawFileStatusBar;
                  ShowMsgBox(0, 'File saved');
                End;
              End;
            End;
      'A' : Begin
              NewFN := FilePickerDialog(bbsCfg.DataPath, '*.*');
              If NewFN <> '' Then Begin
                If SaveFileAs(NewFN) Then Begin
                  DrawFileStatusBar;
                  ShowMsgBox(0, 'File saved');
                End;
              End;
              DrawFileStatusBar;
            End;
      'O' : Begin
              NewFN := FilePickerDialog(bbsCfg.DataPath, '*.*');
              If (NewFN <> '') and FileExist(NewFN) Then Begin
                LoadFile (NewFN);
                ReDrawTemplate (True);
                DrawPage (WinY1, WinY2, False);
                DrawFileStatusBar;
              End;
              DrawFileStatusBar;
            End;
      '\' : Begin TopLine := 0; CurLine := 0; CurY := WinY1;
              DrawPage (WinY1, WinY2, False); LocateCursor; End;
      '/' : Begin FindLastLine;
              If LastLine > WinSize Then Begin
                TopLine := LastLine - WinSize; CurLine := WinSize - 1;
              End Else Begin TopLine := 0; CurLine := LastLine - 1; End;
              CurY := WinY1 + CurLine;
              DrawPage (WinY1, WinY2, False); LocateCursor; End;
    End;
  End;
End;

End.
