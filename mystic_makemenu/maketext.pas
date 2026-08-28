{ maketext.pas — Mystic BBS Text/Prompt Editor
  Reads theme.dat, picks theme, loads that theme's default.txt.
  Part of Mystic BBS, MAKEMENU, MAKETEXT.

  Usage:
    maketext                    List themes, pick, edit prompts
    maketext -?                 Help

  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0. }
{$MODE DELPHI}
program maketext;

uses
  SysUtils, BBS_Records, m_Strings;

const
  VERSION    = '0.1.0';
  MaxPrompts = 515;

var
  bbsCfg: RecConfig;

function LoadConfig: Boolean;
var
  F: File of RecConfig;
begin
  Result := False;
  Assign(F, 'mystic.dat');
  {$I-} System.Reset(F); {$I+}
  if IOResult <> 0 then Exit;
  Read(F, bbsCfg);
  Close(F);
  Result := True;
end;

function LoadThemes(var Themes: Array of RecTheme; var Count: Integer): Boolean;
var
  F: File of RecTheme;
begin
  Result := False;
  Count := 0;
  Assign(F, bbsCfg.DataPath + 'theme.dat');
  {$I-} System.Reset(F); {$I+}
  if IOResult <> 0 then Exit;
  while not Eof(F) and (Count <= High(Themes)) do begin
    Read(F, Themes[Count]);
    Inc(Count);
  end;
  Close(F);
  Result := Count > 0;
end;

procedure ListThemes;
var
  Themes: Array[0..31] of RecTheme;
  Count, I: Integer;
begin
  if not LoadThemes(Themes, Count) then begin
    WriteLn('ERROR: No themes in ', bbsCfg.DataPath, 'theme.dat');
    Halt(1);
  end;

  WriteLn('');
  WriteLn('  MYSTIC BBS MAKETEXT v', VERSION);
  WriteLn('  ================================================');
  WriteLn('  Themes');
  WriteLn('  ------------------------------------------------');
  WriteLn('  #  File Name             Description');
  WriteLn('  ------------------------------------------------');
  for I := 0 to Count - 1 do
    WriteLn('  ', I + 1:2, ' ', Themes[I].FileName:21, ' ', Themes[I].Desc);
  WriteLn('  ------------------------------------------------');
  WriteLn('');
  Write('  Select theme (1-', Count, ') or 0 to exit: ');
end;

procedure EditPrompts(var Theme: RecTheme);
var
  F: Text;
  Buf: Array[1..4096] of Byte;
  Line, TxtFile: String;
  PromptNum, LineCount, PageSize, Page: Integer;
  Prompts: Array[0..MaxPrompts] of String;
  Comments: Array[0..MaxPrompts] of String;
  Loaded: Integer;
  I, StartIdx, EndIdx: Integer;
  Input: String;
begin
  { Find the text file }
  TxtFile := bbsCfg.DataPath + Theme.FileName + '.txt';
  if not FileExists(TxtFile) then
    TxtFile := bbsCfg.SystemPath + Theme.FileName + '.txt';
  if not FileExists(TxtFile) then begin
    WriteLn('  ERROR: Cannot find ', Theme.FileName, '.txt');
    Exit;
  end;

  { Load prompts }
  Loaded := 0;
  for I := 0 to MaxPrompts do begin
    Prompts[I] := '';
    Comments[I] := '';
  end;

  Assign(F, TxtFile);
  SetTextBuf(F, Buf);
  {$I-} System.Reset(F); {$I+}
  if IOResult <> 0 then begin
    WriteLn('  ERROR: Cannot open ', TxtFile);
    Exit;
  end;

  while not Eof(F) do begin
    ReadLn(F, Line);
    { Strip CR }
    if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
      Line := Copy(Line, 1, Length(Line) - 1);

    if (Length(Line) > 0) and (Line[1] = ';') then Continue;
    if (Length(Line) > 0) and (Line[1] = '#') then begin
      { Comment for next prompt }
      Continue;
    end;

    { Numbered prompt: NNN text }
    if (Length(Line) >= 4) and (Line[1] >= '0') and (Line[1] <= '9') and
       (Line[2] >= '0') and (Line[2] <= '9') and (Line[3] >= '0') and
       (Line[3] <= '9') and (Line[4] = ' ') then
    begin
      PromptNum := strS2I(Copy(Line, 1, 3));
      if (PromptNum >= 0) and (PromptNum <= MaxPrompts) then begin
        Prompts[PromptNum] := Copy(Line, 5, Length(Line) - 4);
        Inc(Loaded);
      end;
    end;
  end;
  Close(F);

  WriteLn('  Loaded: ', Loaded, ' prompts from ', TxtFile);

  { Display paged }
  PageSize := 16;
  Page := 0;

  repeat
    StartIdx := Page * PageSize;
    EndIdx := StartIdx + PageSize - 1;
    if EndIdx > MaxPrompts then EndIdx := MaxPrompts;

    WriteLn('');
    WriteLn('  Edit Prompts (', Theme.FileName, ')      ', TxtFile);
    WriteLn('  ------------------------------------------------');
    WriteLn('  ###  Text');
    WriteLn('  ------------------------------------------------');

    for I := StartIdx to EndIdx do begin
      if Prompts[I] <> '' then
        WriteLn('  ', I:3, '  ', Copy(Prompts[I], 1, 65))
      else
        WriteLn('  ', I:3, '  (empty)');
    end;

    WriteLn('  ------------------------------------------------');
    WriteLn('  Page ', Page + 1, ' of ', (MaxPrompts div PageSize) + 1,
            '    Prompts ', StartIdx, '-', EndIdx, ' of ', MaxPrompts);
    WriteLn('');
    Write('  [N]ext [P]rev [Q]uit or prompt # to edit: ');
    ReadLn(Input);

    if (Input = 'n') or (Input = 'N') then begin
      if EndIdx < MaxPrompts then Inc(Page);
    end
    else if (Input = 'p') or (Input = 'P') then begin
      if Page > 0 then Dec(Page);
    end
    else if (Input = 'q') or (Input = 'Q') or (Input = '') then
      Break
    else begin
      { Edit specific prompt }
      PromptNum := strS2I(Input);
      if (PromptNum >= 0) and (PromptNum <= MaxPrompts) then begin
        WriteLn('  Current: ', Prompts[PromptNum]);
        Write('  New text (ENTER to keep): ');
        ReadLn(Input);
        if Input <> '' then
          Prompts[PromptNum] := Input;
      end;
    end;
  until False;
end;

procedure ShowHelp;
begin
  WriteLn('maketext v', VERSION, ' — Mystic BBS Text/Prompt Editor');
  WriteLn('');
  WriteLn('Usage:');
  WriteLn('  maketext                    List themes, pick, edit prompts');
  WriteLn('  maketext -?                 This help');
  WriteLn('');
  WriteLn('Reads mystic.dat for paths, theme.dat for themes.');
  WriteLn('the crew 4free');
end;

var
  Themes: Array[0..31] of RecTheme;
  ThemeCount, Choice, I: Integer;
  Input: String;
begin
  if (ParamCount > 0) and ((ParamStr(1) = '-?') or (ParamStr(1) = '-h')) then begin
    ShowHelp; Halt(0);
  end;

  if not LoadConfig then begin
    WriteLn('ERROR: Cannot read mystic.dat');
    Halt(1);
  end;

  ListThemes;
  ReadLn(Input);
  LoadThemes(Themes, ThemeCount);
  Choice := strS2I(Input) - 1;
  if (Choice < 0) or (Choice >= ThemeCount) then begin
    WriteLn('  Exiting.');
    Halt(0);
  end;

  WriteLn('  Selected: ', Themes[Choice].FileName, ' — ', Themes[Choice].Desc);
  EditPrompts(Themes[Choice]);
end.
