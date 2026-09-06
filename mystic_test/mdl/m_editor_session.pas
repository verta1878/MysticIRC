{$MODE DELPHI}
{$H-}
Unit m_editor_session;
{
  TEditorIOSession — BBS Session I/O wrapper for ANSI editor.
  Wraps BBS_Core Session.io calls through the TEditorIO interface.
  Used when the editor runs inside Mystic BBS (-cfg mode).

  The Session pointer is untyped to avoid pulling BBS_Core into MDL.
  The actual BBS_Core.TBBSCore is cast at runtime.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses
  m_editor_io;

Type
  { Function pointers for BBS Session I/O operations.
    These are set by the BBS layer at initialization to avoid
    compile-time dependency on BBS_Core/BBS_IO. }
  TSessionWriteXY   = Procedure(X, Y, Attr: Byte; S: String) Of Object;
  TSessionWriteChar = Procedure(Ch: Char) Of Object;
  TSessionWriteStr  = Procedure(S: String) Of Object;
  TSessionAnsiColor = Procedure(Attr: Byte) Of Object;
  TSessionGotoXY    = Procedure(X, Y: Byte) Of Object;
  TSessionClearScr  = Procedure Of Object;
  TSessionClearEOL  = Procedure Of Object;
  TSessionGetKey    = Function: Char Of Object;
  TSessionKeyPress  = Function: Boolean Of Object;

  TEditorIOSession = Class(TEditorIO)
  Private
    FScreenW : Byte;
    FScreenH : Byte;
  Public
    { Set these to Session.io methods before using the editor }
    OnWriteXY   : TSessionWriteXY;
    OnWriteChar : TSessionWriteChar;
    OnWriteStr  : TSessionWriteStr;
    OnAnsiColor : TSessionAnsiColor;
    OnGotoXY    : TSessionGotoXY;
    OnClearScr  : TSessionClearScr;
    OnClearEOL  : TSessionClearEOL;
    OnGetKey    : TSessionGetKey;
    OnKeyPress  : TSessionKeyPress;

    Constructor Create(AWidth, AHeight: Byte);

    Procedure WriteXY(X, Y, Attr: Byte; S: String); Override;
    Procedure WriteChar(Ch: Char); Override;
    Procedure WriteStr(S: String); Override;
    Procedure AnsiColor(Attr: Byte); Override;
    Procedure AnsiGotoXY(X, Y: Byte); Override;
    Procedure ClearScreen; Override;
    Procedure ClearEOL; Override;
    Procedure CursorOn; Override;
    Procedure CursorOff; Override;
    Function  GetKey: Char; Override;
    Function  GetYN(Prompt: String; Default: Boolean): Boolean; Override;
    Function  GetStr(Prompt: String; MaxLen: Byte; Default: String): String; Override;
    Function  KeyPressed: Boolean; Override;
    Function  ScreenWidth: Byte; Override;
    Function  ScreenHeight: Byte; Override;
    Procedure SetStatusLine(S: String); Override;
  End;

Implementation

Constructor TEditorIOSession.Create(AWidth, AHeight: Byte);
Begin
  Inherited Create;
  FScreenW := AWidth;
  FScreenH := AHeight;
  OnWriteXY   := Nil;
  OnWriteChar := Nil;
  OnWriteStr  := Nil;
  OnAnsiColor := Nil;
  OnGotoXY    := Nil;
  OnClearScr  := Nil;
  OnClearEOL  := Nil;
  OnGetKey    := Nil;
  OnKeyPress  := Nil;
End;

Procedure TEditorIOSession.WriteXY(X, Y, Attr: Byte; S: String);
Begin
  If Assigned(OnWriteXY) Then OnWriteXY(X, Y, Attr, S);
End;

Procedure TEditorIOSession.WriteChar(Ch: Char);
Begin
  If Assigned(OnWriteChar) Then OnWriteChar(Ch);
End;

Procedure TEditorIOSession.WriteStr(S: String);
Begin
  If Assigned(OnWriteStr) Then OnWriteStr(S);
End;

Procedure TEditorIOSession.AnsiColor(Attr: Byte);
Begin
  If Assigned(OnAnsiColor) Then OnAnsiColor(Attr);
End;

Procedure TEditorIOSession.AnsiGotoXY(X, Y: Byte);
Begin
  If Assigned(OnGotoXY) Then OnGotoXY(X, Y);
End;

Procedure TEditorIOSession.ClearScreen;
Begin
  If Assigned(OnClearScr) Then OnClearScr;
End;

Procedure TEditorIOSession.ClearEOL;
Begin
  If Assigned(OnClearEOL) Then OnClearEOL;
End;

Procedure TEditorIOSession.CursorOn;
Begin
  { Session handles cursor visibility through ANSI sequences }
  WriteStr(#27'[?25h');
End;

Procedure TEditorIOSession.CursorOff;
Begin
  WriteStr(#27'[?25l');
End;

Function TEditorIOSession.GetKey: Char;
Begin
  If Assigned(OnGetKey) Then Result := OnGetKey
  Else Result := #0;
End;

Function TEditorIOSession.GetYN(Prompt: String; Default: Boolean): Boolean;
Var Ch: Char;
Begin
  WriteStr(Prompt);
  If Default Then WriteStr(' [Y/n] ')
  Else WriteStr(' [y/N] ');
  Repeat
    Ch := GetKey;
    If Ch In [#13, #10] Then Begin Result := Default; Exit; End;
    If UpCase(Ch) = 'Y' Then Begin Result := True; Exit; End;
    If UpCase(Ch) = 'N' Then Begin Result := False; Exit; End;
  Until False;
End;

Function TEditorIOSession.GetStr(Prompt: String; MaxLen: Byte; Default: String): String;
Var S: String; Ch: Char;
Begin
  WriteStr(Prompt);
  S := Default;
  WriteStr(S);
  Repeat
    Ch := GetKey;
    Case Ch Of
      #13, #10: Begin Result := S; Exit; End;
      #27: Begin Result := ''; Exit; End;
      #8: If Length(S) > 0 Then Begin
            Delete(S, Length(S), 1);
            WriteStr(#8' '#8);
          End;
    Else
      If (Ch >= ' ') And (Length(S) < MaxLen) Then Begin
        S := S + Ch;
        WriteChar(Ch);
      End;
    End;
  Until False;
End;

Function TEditorIOSession.KeyPressed: Boolean;
Begin
  If Assigned(OnKeyPress) Then Result := OnKeyPress
  Else Result := False;
End;

Function TEditorIOSession.ScreenWidth: Byte;
Begin
  Result := FScreenW;
End;

Function TEditorIOSession.ScreenHeight: Byte;
Begin
  Result := FScreenH;
End;

Procedure TEditorIOSession.SetStatusLine(S: String);
Begin
  WriteXY(1, FScreenH, $70, S);
End;

End.
