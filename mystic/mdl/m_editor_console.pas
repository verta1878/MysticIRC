{$MODE DELPHI}
{$H-}
Unit m_editor_console;
{
  TEditorIOConsole — Standalone console I/O for ANSI editor.
  Uses m_Input/m_Output directly, no BBS Session needed.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses
  m_editor_io,
  m_Input,
  m_Output;

Type
  TEditorIOConsole = Class(TEditorIO)
  Private
    FInput  : TInput;
    FOutput : TOutput;
    FWidth  : Byte;
    FHeight : Byte;
  Public
    Constructor Create;
    Destructor  Destroy; Override;

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

Uses
  SysUtils;

Constructor TEditorIOConsole.Create;
Begin
  Inherited Create;
  FInput  := TInput.Create;
  FOutput := TOutput.Create(True); { True = local console }
  FWidth  := 80;
  FHeight := 25;
End;

Destructor TEditorIOConsole.Destroy;
Begin
  FInput.Free;
  FOutput.Free;
  Inherited Destroy;
End;

Procedure TEditorIOConsole.WriteXY(X, Y, Attr: Byte; S: String);
Begin
  FOutput.WriteXY(X, Y, Attr, S);
End;

Procedure TEditorIOConsole.WriteChar(Ch: Char);
Begin
  FOutput.WriteChar(Ch);
End;

Procedure TEditorIOConsole.WriteStr(S: String);
Begin
  FOutput.WriteStr(S);
End;

Procedure TEditorIOConsole.AnsiColor(Attr: Byte);
Begin
  FOutput.SetTextAttr(Attr);
End;

Procedure TEditorIOConsole.AnsiGotoXY(X, Y: Byte);
Begin
  FOutput.CursorXY(X, Y);
End;

Procedure TEditorIOConsole.ClearScreen;
Begin
  FOutput.ClearScreen;
End;

Procedure TEditorIOConsole.ClearEOL;
Begin
  FOutput.ClearEOL;
End;

Procedure TEditorIOConsole.CursorOn;
Begin
  FOutput.WriteStr(#27'[?25h');
End;

Procedure TEditorIOConsole.CursorOff;
Begin
  FOutput.WriteStr(#27'[?25l');
End;

Function TEditorIOConsole.GetKey: Char;
Begin
  Result := FInput.ReadKey;
End;

Function TEditorIOConsole.GetYN(Prompt: String; Default: Boolean): Boolean;
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

Function TEditorIOConsole.GetStr(Prompt: String; MaxLen: Byte; Default: String): String;
Var
  S  : String;
  Ch : Char;
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

Function TEditorIOConsole.KeyPressed: Boolean;
Begin
  Result := FInput.KeyPressed;
End;

Function TEditorIOConsole.ScreenWidth: Byte;
Begin
  Result := FWidth;
End;

Function TEditorIOConsole.ScreenHeight: Byte;
Begin
  Result := FHeight;
End;

Procedure TEditorIOConsole.SetStatusLine(S: String);
Begin
  WriteXY(1, FHeight, $70, S);
  While Length(S) < FWidth Do S := S + ' ';
End;

End.
