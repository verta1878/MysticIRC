{ makemenu.pas — Mystic BBS Menu Editor
  Reads theme.dat, lets sysop pick a theme, lists menus from
  that theme's MenuPath, edits .mnu + auto-generates .mrp.
  Part of Mystic BBS, MAKEMENU, MAKETEXT.

  Usage:
    makemenu                    List themes, pick, edit menus
    makemenu -demo main         Create demo .mnu + .mrp
    makemenu -?                 Help

  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, bob, evga, kiddo, wrench,
           hexadecimal, byte, DotMatrix. }
{$MODE DELPHI}
program makemenu;

uses
  SysUtils, Dos, BBS_Records, mrpdata;

const
  VERSION = '0.1.0';

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
  while not Eof(F) and (Count < High(Themes)) do begin
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
    WriteLn('ERROR: No themes found in ', bbsCfg.DataPath, 'theme.dat');
    Halt(1);
  end;

  WriteLn('');
  WriteLn('  MYSTIC BBS MAKEMENU v', VERSION);
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

procedure ListMenus(var Theme: RecTheme);
var
  SR: SearchRec;
  MenuCount: Integer;
  MenuPath: String;
begin
  MenuPath := Theme.MenuPath;
  if MenuPath = '' then MenuPath := 'menus/';

  WriteLn('');
  WriteLn('  Menu Editor (', Theme.FileName, ')');
  WriteLn('  ------------------------------------------------');
  WriteLn('  Menu Name             Description');
  WriteLn('  ------------------------------------------------');

  MenuCount := 0;
  FindFirst(MenuPath + '*.mnu', Archive, SR);
  while DosError = 0 do begin
    WriteLn('  ', ChangeFileExt(SR.Name, ''):21, ' ', SR.Name);
    Inc(MenuCount);
    FindNext(SR);
  end;
  FindClose(SR);

  if MenuCount = 0 then
    WriteLn('  (no menus found in ', MenuPath, ')')
  else
    WriteLn('  ------------------------------------------------');

  WriteLn('  ', MenuCount, ' menus in ', MenuPath);
  WriteLn('');
end;

procedure EditMenu(var Theme: RecTheme; const MenuName: String);
var
  Menu: TMenuData;
  MenuPath: String;
  I, J: Integer;
begin
  MenuPath := Theme.MenuPath;
  if MenuPath = '' then MenuPath := 'menus/';

  Menu := TMenuData.Create;
  try
    if not Menu.LoadMnu(MenuPath + MenuName + '.mnu') then begin
      WriteLn('  ERROR: Cannot load ', MenuPath, MenuName, '.mnu');
      Exit;
    end;

    WriteLn('');
    WriteLn('  Editing: ', MenuName, '.mnu (', Menu.Info.Description, ')');
    WriteLn('  ------------------------------------------------');
    WriteLn('  #  Key  Text                     Cmd  Data');
    WriteLn('  ------------------------------------------------');

    for I := 1 to Menu.NumItems do begin
      if Menu.Item[I] <> nil then begin
        Write('  ', I:2, ' ', Menu.Item[I]^.HotKey:4, ' ');
        Write(Menu.Item[I]^.Text:24, ' ');
        if Menu.Item[I]^.Commands > 0 then begin
          if Menu.Item[I]^.CmdData[1] <> nil then
            Write(Menu.Item[I]^.CmdData[1]^.MenuCmd:4, ' ',
                  Menu.Item[I]^.CmdData[1]^.Data);
        end;
        WriteLn;
      end;
    end;

    WriteLn('  ------------------------------------------------');
    WriteLn('  ', Menu.NumItems, ' items');

    { Auto-generate .mrp }
    if Menu.SaveMrp(MenuPath + MenuName + '.mrp') then
      WriteLn('  Generated: ', MenuPath, MenuName, '.mrp')
    else
      WriteLn('  WARNING: Could not generate .mrp');
  finally
    Menu.Free;
  end;
end;

procedure ShowHelp;
begin
  WriteLn('makemenu v', VERSION, ' — Mystic BBS Menu Editor');
  WriteLn('');
  WriteLn('Usage:');
  WriteLn('  makemenu                    List themes, pick, edit menus');
  WriteLn('  makemenu -demo <name>       Create demo menu files');
  WriteLn('  makemenu -?                 This help');
  WriteLn('');
  WriteLn('Reads mystic.dat for paths, theme.dat for themes.');
  WriteLn('the crew 4free');
end;

procedure AddMenuItem(Menu: TMenuData; const AText, AHotKey, ACmd, AData: String;
  AX, AY: Byte);
var
  N: Integer;
begin
  N := Menu.NumItems + 1;
  Menu.InsertItem(N);
  Menu.Item[N]^.Text := AText;
  Menu.Item[N]^.HotKey := AHotKey;
  Menu.Item[N]^.X := AX;
  Menu.Item[N]^.Y := AY;
  if ACmd <> '' then begin
    Menu.InsertCommand(N, 1);
    Menu.Item[N]^.CmdData[1]^.MenuCmd := ACmd;
    Menu.Item[N]^.CmdData[1]^.Data := AData;
  end;
end;

procedure CreateDemo(const BaseName: String);
var
  Menu: TMenuData;
begin
  Menu := TMenuData.Create;
  try
    Menu.Info.Description := 'Main Menu';
    AddMenuItem(Menu, 'File Areas',     'F', 'MN', 'file',     5, 33);
    AddMenuItem(Menu, 'Message Areas',  'M', 'MN', 'msg',      5, 41);
    AddMenuItem(Menu, 'Email',          'E', 'MN', 'email',    5, 49);
    AddMenuItem(Menu, 'Settings',       'S', 'MN', 'settings', 5, 57);
    AddMenuItem(Menu, 'Who Is Online',  'W', 'WO', '',         5, 65);
    AddMenuItem(Menu, 'Page Sysop',     'P', 'PC', '',         5, 73);
    AddMenuItem(Menu, 'Goodbye',        'G', 'GX', '',         5, 81);

    if Menu.SaveMnu(BaseName + '.mnu') then
      WriteLn('Created: ', BaseName, '.mnu (', Menu.NumItems, ' items)');
    if Menu.SaveMrp(BaseName + '.mrp') then
      WriteLn('Created: ', BaseName, '.mrp');
  finally
    Menu.Free;
  end;
end;

var
  Themes: Array[0..31] of RecTheme;
  ThemeCount, Choice, I: Integer;
  Input, MenuName: String;
begin
  if (ParamCount > 0) then begin
    if (ParamStr(1) = '-?') or (ParamStr(1) = '-h') then begin
      ShowHelp; Halt(0);
    end;
    if ParamStr(1) = '-demo' then begin
      if ParamCount >= 2 then CreateDemo(ParamStr(2))
      else CreateDemo('main');
      Halt(0);
    end;
  end;

  if not LoadConfig then begin
    WriteLn('ERROR: Cannot read mystic.dat');
    WriteLn('Run from Mystic BBS root directory.');
    Halt(1);
  end;

  { Theme selector }
  ListThemes;
  ReadLn(Input);
  Choice := 0;
  Val(Input, Choice, I);
  if (Choice < 1) or (Choice > ThemeCount) then begin
    { Reload count }
    LoadThemes(Themes, ThemeCount);
    if (Choice < 1) or (Choice > ThemeCount) then begin
      WriteLn('  Exiting.');
      Halt(0);
    end;
  end;
  LoadThemes(Themes, ThemeCount);
  Dec(Choice);

  WriteLn('  Selected: ', Themes[Choice].FileName, ' — ', Themes[Choice].Desc);

  { List menus }
  ListMenus(Themes[Choice]);

  { Pick a menu to edit }
  Write('  Enter menu name (without .mnu) or ENTER to exit: ');
  ReadLn(MenuName);
  if MenuName <> '' then
    EditMenu(Themes[Choice], MenuName);
end.
