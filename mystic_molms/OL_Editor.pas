{ ===========================================================================
  OL_Editor — Offline mail reply editor with spell check
  Copyright (C) 2025-2026 IRC Fork: verta1878, sysop/0, evga, kiddo, wrench
  GPLv3

  Simple line editor for composing QWK/BlueWave replies in OLMS.
  Integrates mt_spell.pas (Hunspell) for spell checking.

  Usage:
    var Editor: TOLEditor;
    Editor.Init;
    Editor.SetQuote(OriginalMessage);
    If Editor.Edit Then
      PackReply(Editor.GetText);
    Editor.Done;
  =========================================================================== }

{$MODE OBJFPC}{$H+}

unit OL_Editor;

interface

uses SysUtils, Classes, mt_spell;

const
  OL_MAX_LINES = 500;
  OL_WRAP_COL  = 72;

type
  TOLEditor = class
  private
    FLines    : TStringList;
    FSpell    : THunSpell;
    FCurLine  : Integer;
    FCurCol   : Integer;
    FModified : Boolean;
    FSubject  : String;
    FQuotePfx : String;
    procedure WrapLine(LineNum: Integer);
  public
    constructor Create(const DataPath: String);
    destructor Destroy; override;
    procedure Clear;
    procedure SetQuote(const Lines: TStringList; const Author: String);
    procedure SetSubject(const Subj: String);
    procedure InsertLine(const S: String);
    procedure AddText(const S: String);
    function  GetText: TStringList;
    function  LineCount: Integer;
    function  GetLine(N: Integer): String;
    property  Modified: Boolean read FModified;
    property  Subject: String read FSubject write FSubject;
    property  CurLine: Integer read FCurLine write FCurLine;
    property  CurCol: Integer read FCurCol write FCurCol;

    { Spell check }
    function  SpellCheckAll: Integer;
    function  CheckWord(const W: String): Boolean;
    function  SuggestWord(const W: String): String;
    function  SpellAvailable: Boolean;
  end;

implementation

constructor TOLEditor.Create(const DataPath: String);
begin
  inherited Create;
  FLines := TStringList.Create;
  FSpell := THunSpell.Create(DataPath);
  FCurLine := 0;
  FCurCol := 1;
  FModified := False;
  FQuotePfx := ' > ';
  FSubject := '';
end;

destructor TOLEditor.Destroy;
begin
  FSpell.Free;
  FLines.Free;
  inherited;
end;

procedure TOLEditor.Clear;
begin
  FLines.Clear;
  FCurLine := 0;
  FCurCol := 1;
  FModified := False;
end;

procedure TOLEditor.SetQuote(const Lines: TStringList; const Author: String);
var
  I: Integer;
begin
  Clear;
  FQuotePfx := Copy(Author, 1, 2) + '> ';
  for I := 0 to Lines.Count - 1 do
    FLines.Add(FQuotePfx + Lines[I]);
  FLines.Add('');  { blank line after quote }
  FCurLine := FLines.Count - 1;
  FModified := False;
end;

procedure TOLEditor.SetSubject(const Subj: String);
begin
  FSubject := Subj;
end;

procedure TOLEditor.InsertLine(const S: String);
begin
  if FLines.Count < OL_MAX_LINES then begin
    FLines.Insert(FCurLine, S);
    Inc(FCurLine);
    FModified := True;
  end;
end;

procedure TOLEditor.AddText(const S: String);
begin
  if FLines.Count < OL_MAX_LINES then begin
    FLines.Add(S);
    FCurLine := FLines.Count - 1;
    FModified := True;
  end;
end;

procedure TOLEditor.WrapLine(LineNum: Integer);
var
  Line, Overflow: String;
  WrapAt: Integer;
begin
  if LineNum >= FLines.Count then Exit;
  Line := FLines[LineNum];
  if Length(Line) <= OL_WRAP_COL then Exit;

  { Find last space before wrap column }
  WrapAt := OL_WRAP_COL;
  while (WrapAt > 1) and (Line[WrapAt] <> ' ') do Dec(WrapAt);
  if WrapAt <= 1 then WrapAt := OL_WRAP_COL;

  Overflow := Copy(Line, WrapAt + 1, Length(Line));
  FLines[LineNum] := Copy(Line, 1, WrapAt);

  if LineNum + 1 < FLines.Count then
    FLines[LineNum + 1] := Overflow + ' ' + FLines[LineNum + 1]
  else
    FLines.Add(Overflow);

  WrapLine(LineNum + 1);
end;

function TOLEditor.GetText: TStringList;
begin
  Result := FLines;
end;

function TOLEditor.LineCount: Integer;
begin
  Result := FLines.Count;
end;

function TOLEditor.GetLine(N: Integer): String;
begin
  if (N >= 0) and (N < FLines.Count) then
    Result := FLines[N]
  else
    Result := '';
end;

{ Spell check all lines, return number of errors found }
function TOLEditor.SpellCheckAll: Integer;
var
  Line, Word, Sug: String;
  I, Col, WStart: Integer;
begin
  Result := 0;
  if not FSpell.Loaded then Exit;

  for I := 0 to FLines.Count - 1 do begin
    Line := FLines[I];
    { Skip quoted lines }
    if (Length(Line) > 0) and (Pos('>', Line) <= 4) then Continue;

    Col := 1;
    while Col <= Length(Line) do begin
      { Skip non-alpha }
      while (Col <= Length(Line)) and not (Line[Col] in ['A'..'Z', 'a'..'z', '''']) do
        Inc(Col);
      if Col > Length(Line) then Break;

      { Collect word }
      WStart := Col;
      Word := '';
      while (Col <= Length(Line)) and (Line[Col] in ['A'..'Z', 'a'..'z', '''', '-']) do begin
        Word := Word + Line[Col];
        Inc(Col);
      end;

      if Length(Word) < 2 then Continue;

      if not FSpell.CheckWord(Word) then begin
        Inc(Result);
        Sug := FSpell.Suggest(Word);
        { Could store errors for UI display }
        if Sug <> '' then
          WriteLn('Line ', I + 1, ': "', Word, '" -> ', Sug)
        else
          WriteLn('Line ', I + 1, ': "', Word, '"');
      end;
    end;
  end;
end;

function TOLEditor.CheckWord(const W: String): Boolean;
begin
  Result := FSpell.CheckWord(W);
end;

function TOLEditor.SuggestWord(const W: String): String;
begin
  Result := FSpell.Suggest(W);
end;

function TOLEditor.SpellAvailable: Boolean;
begin
  Result := FSpell.Loaded;
end;

end.
