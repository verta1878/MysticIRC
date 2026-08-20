{ ===========================================================================
  OpenOLMS — editor.pas
  Standalone message editor (replaces EDITOR.EXE)
  GPLv3 — Copyright (C) 2026 verta1878, wrench

  Console message editor for QWK/QWKE/BlueWave mail replies.
  Uses OL_Editor for editing engine + spell check.

  Usage:
    editor                     new message
    editor REPLY.MSG           edit existing reply file
    editor REPLY.MSG /Q:MSG    quote original message MSG

  Controls:
    Arrows: navigate  Enter: new line  Backspace: delete
    Ctrl-Y: delete line  Ctrl-K: spell check  Ctrl-W: save+exit
    Ctrl-Q: quit  Home/End: line start/end  PgUp/PgDn: scroll
  =========================================================================== }

{$MODE OBJFPC}{$H+}

program editor;

uses
  SysUtils, Classes, Keyboard, CRT, OL_Editor;

const
  VERSION = 'OpenOLMS Editor v1.0';
  EDIT_TOP  = 3;
  EDIT_ROWS = 20;

var
  Ed: TOLEditor;
  FileName, QuoteFile: String;
  TopLine: Integer;
  Running: Boolean;

procedure DrawHeader;
begin
  TextBackground(LightGray); TextColor(Black);
  GotoXY(1, 1); ClrEol;
  Write(VERSION, ' -- ', ExtractFileName(FileName));
  if Ed.Modified then begin TextColor(Red); Write(' [Modified]'); end;
  TextBackground(Blue); TextColor(White);
  GotoXY(1, 2); ClrEol;
  Write(' Subject: ', Ed.Subject);
end;

procedure DrawStatus;
begin
  TextBackground(Cyan); TextColor(Black);
  GotoXY(1, 24); ClrEol;
  Write(Format(' Line %d/%d  Col %d   Ctrl-W:Save  Ctrl-Q:Quit  Ctrl-K:Spell',
    [Ed.CurLine + 1, Ed.LineCount, Ed.CurCol]));
end;

procedure DrawEditor;
var I, LineIdx: Integer; S: String;
begin
  TextBackground(Black); TextColor(LightGray);
  for I := 0 to EDIT_ROWS - 1 do
  begin
    GotoXY(1, EDIT_TOP + I); ClrEol;
    LineIdx := TopLine + I;
    if LineIdx < Ed.LineCount then
    begin
      S := Ed.GetLine(LineIdx);
      if Length(S) > 79 then S := Copy(S, 1, 79);
      Write(S);
    end;
  end;
end;

procedure DrawScreen;
begin
  DrawHeader;
  DrawEditor;
  DrawStatus;
  { Position cursor }
  GotoXY(Ed.CurCol, EDIT_TOP + Ed.CurLine - TopLine);
end;

procedure EnsureVisible;
begin
  if Ed.CurLine < TopLine then TopLine := Ed.CurLine;
  if Ed.CurLine >= TopLine + EDIT_ROWS then TopLine := Ed.CurLine - EDIT_ROWS + 1;
end;

procedure HandleKey(K: TKeyEvent);
var C: Char; Code: Word; Line, Wrapped: String; WrapPos: Integer;
begin
  Code := GetKeyEventCode(K);
  C := GetKeyEventChar(K);

  if C <> #0 then
  begin
    case C of
      #23: begin { Ctrl-W: save }
             Ed.Lines.SaveToFile(FileName);
             Running := False; Exit;
           end;
      #17: begin Running := False; Exit; end; { Ctrl-Q: quit }
      #11: Ed.SpellCheckAll; { Ctrl-K }
      #25: begin { Ctrl-Y: delete line }
             if Ed.LineCount > 1 then begin
               Ed.DeleteLine(Ed.CurLine);
               if Ed.CurLine >= Ed.LineCount then Ed.CurLine := Ed.LineCount - 1;
             end else begin Ed.SetLine(0, ''); Ed.CurCol := 1; end;
           end;
      #13: begin { Enter }
             Line := Ed.GetLine(Ed.CurLine);
             if Ed.CurCol <= Length(Line) then begin
               Ed.SetLine(Ed.CurLine, Copy(Line, 1, Ed.CurCol - 1));
               Ed.InsertLineAt(Ed.CurLine + 1, Copy(Line, Ed.CurCol, Length(Line)));
             end else
               Ed.InsertLineAt(Ed.CurLine + 1, '');
             Ed.CurLine := Ed.CurLine + 1; Ed.CurCol := 1;
           end;
      #8:  begin { Backspace }
             Line := Ed.GetLine(Ed.CurLine);
             if Ed.CurCol > 1 then begin
               Delete(Line, Ed.CurCol - 1, 1);
               Ed.SetLine(Ed.CurLine, Line); Ed.CurCol := Ed.CurCol - 1;
             end else if Ed.CurLine > 0 then begin
               Ed.CurCol := Length(Ed.GetLine(Ed.CurLine - 1)) + 1;
               Ed.SetLine(Ed.CurLine - 1, Ed.GetLine(Ed.CurLine - 1) + Line);
               Ed.DeleteLine(Ed.CurLine); Ed.CurLine := Ed.CurLine - 1;
             end;
           end;
    else
      if (C >= ' ') and (C <= '~') then begin
        Line := Ed.GetLine(Ed.CurLine);
        if Ed.CurCol > Length(Line) then Line := Line + C
        else Insert(C, Line, Ed.CurCol);
        Ed.CurCol := Ed.CurCol + 1;

        { Word wrap at column 72 — match original EDITOR.EXE }
        if Length(Line) >= 72 then begin
          WrapPos := 72;
          while (WrapPos > 1) and (Line[WrapPos] <> ' ') do
            WrapPos := WrapPos - 1;
          if WrapPos > 1 then begin
            { Split at last space before column 72 }
            Wrapped := Copy(Line, WrapPos + 1, Length(Line));
            Line := Copy(Line, 1, WrapPos - 1);
            Ed.SetLine(Ed.CurLine, Line);
            Ed.InsertLineAt(Ed.CurLine + 1, Wrapped);
            Ed.CurLine := Ed.CurLine + 1;
            Ed.CurCol := Length(Wrapped) + 1;
          end else
            Ed.SetLine(Ed.CurLine, Line);
        end else
          Ed.SetLine(Ed.CurLine, Line);
      end;
    end;
  end
  else
  begin
    case Code of
      $4800: if Ed.CurLine > 0 then Ed.CurLine := Ed.CurLine - 1;
      $5000: if Ed.CurLine < Ed.LineCount - 1 then Ed.CurLine := Ed.CurLine + 1;
      $4B00: if Ed.CurCol > 1 then Ed.CurCol := Ed.CurCol - 1;
      $4D00: Ed.CurCol := Ed.CurCol + 1;
      $4700: Ed.CurCol := 1;
      $4F00: Ed.CurCol := Length(Ed.GetLine(Ed.CurLine)) + 1;
      $4900: begin Ed.CurLine := Ed.CurLine - EDIT_ROWS; if Ed.CurLine < 0 then Ed.CurLine := 0; end;
      $5100: begin Ed.CurLine := Ed.CurLine + EDIT_ROWS; if Ed.CurLine >= Ed.LineCount then Ed.CurLine := Ed.LineCount - 1; end;
      $5300: begin { Del }
               Line := Ed.GetLine(Ed.CurLine);
               if Ed.CurCol <= Length(Line) then begin
                 Delete(Line, Ed.CurCol, 1); Ed.SetLine(Ed.CurLine, Line);
               end else if Ed.CurLine < Ed.LineCount - 1 then begin
                 Ed.SetLine(Ed.CurLine, Line + Ed.GetLine(Ed.CurLine + 1));
                 Ed.DeleteLine(Ed.CurLine + 1);
               end;
             end;
    end;
  end;
  if Ed.CurCol < 1 then Ed.CurCol := 1;
  EnsureVisible;
end;

procedure ParseArgs;
var I: Integer; Arg: String;
begin
  FileName := 'REPLY.MSG'; QuoteFile := '';
  for I := 1 to ParamCount do begin
    Arg := ParamStr(I);
    if (Copy(Arg, 1, 3) = '/Q:') or (Copy(Arg, 1, 3) = '/q:') then
      QuoteFile := Copy(Arg, 4, Length(Arg))
    else if Arg[1] <> '/' then FileName := Arg;
  end;
end;

var K: TKeyEvent; Q: TStringList;
begin
  ParseArgs;
  Ed := TOLEditor.Create(ExtractFilePath(ParamStr(0)));
  if QuoteFile <> '' then begin
    Q := TStringList.Create;
    if FileExists(QuoteFile) then Q.LoadFromFile(QuoteFile);
    Ed.SetQuote(Q, 'Original');
    Q.Free;
  end else if FileExists(FileName) then
    Ed.Lines.LoadFromFile(FileName)
  else
    Ed.InsertLine('');

  InitKeyboard;
  ClrScr;
  TopLine := 0; Running := True;
  DrawScreen;
  while Running do begin
    K := GetKeyEvent; K := TranslateKeyEvent(K);
    if K <> 0 then begin HandleKey(K); DrawScreen; end;
  end;
  DoneKeyboard;
  ClrScr;
  Ed.Free;
  WriteLn('Editor exited.');
end.
