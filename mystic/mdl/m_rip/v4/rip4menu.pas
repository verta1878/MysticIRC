{$MODE DELPHI}
{$H-}
Unit RIP4Menu;
{ RIPscrip v4.0 IRC Extension — Menu System
  File format: .rmu (RIP Menu Unit)
  Adds structured menu support to the RIP protocol.

  .rmu format (text, line-oriented):
    Line 1: RMU1                         — magic + version
    Line 2: Menu title
    Line 3: X Y W                        — position and width (mega2)
    Line 4: FG BG HL                     — colors (fg, bg, highlight)
    Line 5: FLAGS                        — bit flags (see below)
    Then N item blocks, each 3 lines:
      ITEM <type> <hotkey>
      <display text>
      <command string>
    Terminated by:
      END

  Item types:
    N = normal item
    S = separator (display text and command ignored)
    C = checkbox (command = varname, toggled on click)
    R = radio (command = group:value)
    M = submenu (command = filename.rmu)

  Flags (bit field):
    $01 = dropdown (anchored to position, auto-close on click)
    $02 = popup (centered, modal)
    $04 = menubar (horizontal layout)
    $08 = persist (stays open until ESC)

  RIP command: !|4M <filename.rmu>  — load and display menu
  RIP command: !|4m                 — close active menu

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses
  RIPEngine;

Const
  RMU_MAX_ITEMS   = 32;
  RMU_MAX_MENUS   = 4;    { nested/stacked menu depth }
  RMU_MAX_TEXTLEN = 40;

  { Item types }
  RMU_ITEM_NORMAL = 0;
  RMU_ITEM_SEP    = 1;
  RMU_ITEM_CHECK  = 2;
  RMU_ITEM_RADIO  = 3;
  RMU_ITEM_SUB    = 4;

  { Menu flags }
  RMU_FLAG_DROPDOWN = $01;
  RMU_FLAG_POPUP    = $02;
  RMU_FLAG_MENUBAR  = $04;
  RMU_FLAG_PERSIST  = $08;

Type
  TRMUItem = Record
    ItemType : Byte;
    HotKey   : Char;
    Text     : String[RMU_MAX_TEXTLEN];
    Command  : String[79];
    Checked  : Boolean;   { for checkbox/radio }
    Enabled  : Boolean;
  End;

  TRMUMenu = Record
    Title    : String[RMU_MAX_TEXTLEN];
    X, Y     : SmallInt;
    Width    : SmallInt;
    FG, BG   : Byte;
    Highlight: Byte;
    Flags    : Byte;
    Items    : Array[0..RMU_MAX_ITEMS-1] of TRMUItem;
    Count    : Integer;
    Selected : Integer;   { currently highlighted item }
    Visible  : Boolean;
    FileName : String[79];
  End;
  PRMUMenu = ^TRMUMenu;

{ Load/Free }
Function  RMULoad(Var Menu: TRMUMenu; FileName: String): Boolean;
Procedure RMUFree(Var Menu: TRMUMenu);

{ Display }
Procedure RMURender(Var Menu: TRMUMenu);
Procedure RMURenderItem(Var Menu: TRMUMenu; Index: Integer; Active: Boolean);

{ Navigation }
Procedure RMUMoveUp(Var Menu: TRMUMenu);
Procedure RMUMoveDown(Var Menu: TRMUMenu);
Function  RMUFindHotKey(Var Menu: TRMUMenu; Key: Char): Integer;
Function  RMUSelect(Var Menu: TRMUMenu): String;  { returns command of selected item }
Procedure RMUToggleCheck(Var Menu: TRMUMenu; Index: Integer);

{ Menu stack — for nested/submenu support }
Procedure RMUPush(Var Menu: TRMUMenu);
Function  RMUPop: PRMUMenu;
Procedure RMUCloseAll;
Function  RMUActiveMenu: PRMUMenu;
Function  RMUStackDepth: Integer;

{ Hit test — returns item index at pixel coords, -1 if none }
Function  RMUHitTest(Var Menu: TRMUMenu; PixX, PixY: SmallInt): Integer;

Implementation

Uses
  SysUtils, RIPWidgets, RIPText;

Const
  ITEM_HEIGHT  = 16;   { pixels per menu item (8x16 font) }
  SEP_HEIGHT   = 8;    { separator height }
  PADDING_X    = 8;    { horizontal padding }
  PADDING_Y    = 4;    { vertical padding }
  TITLE_HEIGHT = 18;   { title bar height }

Var
  MenuStack : Array[0..RMU_MAX_MENUS-1] of PRMUMenu;
  StackTop  : Integer;

{ === Load === }

Function RMULoad(Var Menu: TRMUMenu; FileName: String): Boolean;
Var
  F    : Text;
  Line : String;
  Magic: String;
  Itm  : ^TRMUItem;
Begin
  Result := False;
  FillChar(Menu, SizeOf(TRMUMenu), 0);
  Menu.FileName := FileName;

  Assign(F, FileName);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  { Line 1: magic }
  ReadLn(F, Magic);
  If Trim(Magic) <> 'RMU1' Then Begin Close(F); Exit; End;

  { Line 2: title }
  ReadLn(F, Line);
  Menu.Title := Trim(Line);

  { Line 3: X Y W }
  ReadLn(F, Line);
  Line := Trim(Line);
  If Length(Line) >= 6 Then Begin
    Menu.X     := StrToIntDef(Copy(Line, 1, 2), 0);
    Menu.Y     := StrToIntDef(Copy(Line, 3, 2), 0);
    Menu.Width := StrToIntDef(Copy(Line, 5, 2), 120);
  End;

  { Line 4: FG BG HL }
  ReadLn(F, Line);
  Line := Trim(Line);
  If Length(Line) >= 6 Then Begin
    Menu.FG        := StrToIntDef(Copy(Line, 1, 2), 15);
    Menu.BG        := StrToIntDef(Copy(Line, 3, 2), 1);
    Menu.Highlight := StrToIntDef(Copy(Line, 5, 2), 14);
  End;

  { Line 5: flags }
  ReadLn(F, Line);
  Menu.Flags := StrToIntDef(Trim(Line), 0);

  { Items }
  Menu.Count := 0;
  While Not EOF(F) Do Begin
    ReadLn(F, Line);
    Line := Trim(Line);

    If UpperCase(Line) = 'END' Then Break;

    If (Length(Line) >= 6) And (UpperCase(Copy(Line, 1, 4)) = 'ITEM') Then Begin
      If Menu.Count >= RMU_MAX_ITEMS Then Break;
      Itm := @Menu.Items[Menu.Count];
      Itm^.Enabled := True;
      Itm^.Checked := False;

      { Parse type }
      Case UpCase(Line[6]) Of
        'N': Itm^.ItemType := RMU_ITEM_NORMAL;
        'S': Itm^.ItemType := RMU_ITEM_SEP;
        'C': Itm^.ItemType := RMU_ITEM_CHECK;
        'R': Itm^.ItemType := RMU_ITEM_RADIO;
        'M': Itm^.ItemType := RMU_ITEM_SUB;
      Else
        Itm^.ItemType := RMU_ITEM_NORMAL;
      End;

      { Hotkey }
      If Length(Line) >= 8 Then
        Itm^.HotKey := Line[8]
      Else
        Itm^.HotKey := #0;

      { Display text (next line) }
      If Not EOF(F) Then ReadLn(F, Line) Else Line := '';
      Itm^.Text := Trim(Line);

      { Command (next line) }
      If Not EOF(F) Then ReadLn(F, Line) Else Line := '';
      Itm^.Command := Trim(Line);

      Inc(Menu.Count);
    End;
  End;

  Close(F);
  Menu.Selected := 0;
  Menu.Visible := True;

  { Skip to first non-separator }
  While (Menu.Selected < Menu.Count) And
        (Menu.Items[Menu.Selected].ItemType = RMU_ITEM_SEP) Do
    Inc(Menu.Selected);

  Result := True;
End;

Procedure RMUFree(Var Menu: TRMUMenu);
Begin
  FillChar(Menu, SizeOf(TRMUMenu), 0);
End;

{ === Rendering === }

Function ItemY(Var Menu: TRMUMenu; Index: Integer): Integer;
Var I, YP: Integer;
Begin
  YP := Menu.Y + TITLE_HEIGHT + PADDING_Y;
  For I := 0 To Index - 1 Do Begin
    If Menu.Items[I].ItemType = RMU_ITEM_SEP Then
      Inc(YP, SEP_HEIGHT)
    Else
      Inc(YP, ITEM_HEIGHT);
  End;
  Result := YP;
End;

Function MenuHeight(Var Menu: TRMUMenu): Integer;
Var I, H: Integer;
Begin
  H := TITLE_HEIGHT + PADDING_Y * 2;
  For I := 0 To Menu.Count - 1 Do Begin
    If Menu.Items[I].ItemType = RMU_ITEM_SEP Then
      Inc(H, SEP_HEIGHT)
    Else
      Inc(H, ITEM_HEIGHT);
  End;
  Result := H;
End;

Procedure RMURender(Var Menu: TRMUMenu);
Var
  I, MH: Integer;
Begin
  If Not Menu.Visible Then Exit;

  MH := MenuHeight(Menu);

  { Background + border }
  DrawRaisedBox(Menu.X, Menu.Y, Menu.X + Menu.Width, Menu.Y + MH,
                Menu.BG, 15, 8);

  { Title bar }
  DrawBar(Menu.X + 2, Menu.Y + 2,
          Menu.X + Menu.Width - 2, Menu.Y + TITLE_HEIGHT, Menu.Highlight);
  DrawTextCentered(Menu.X + 2, Menu.Y + 2,
                   Menu.X + Menu.Width - 2, Menu.Y + TITLE_HEIGHT,
                   Menu.Title, Menu.BG);

  { Items }
  For I := 0 To Menu.Count - 1 Do
    RMURenderItem(Menu, I, I = Menu.Selected);
End;

Procedure RMURenderItem(Var Menu: TRMUMenu; Index: Integer; Active: Boolean);
Var
  YP : Integer;
  Itm: TRMUItem;
  FG : Byte;
  Prefix: String[4];
Begin
  If (Index < 0) Or (Index >= Menu.Count) Then Exit;
  Itm := Menu.Items[Index];
  YP := ItemY(Menu, Index);

  If Itm.ItemType = RMU_ITEM_SEP Then Begin
    DrawSeparatorH(Menu.X + 4, Menu.X + Menu.Width - 4, YP + SEP_HEIGHT Div 2,
                   15, 8);
    Exit;
  End;

  { Active highlight bar }
  If Active Then Begin
    DrawBar(Menu.X + 2, YP, Menu.X + Menu.Width - 2, YP + ITEM_HEIGHT - 1,
            Menu.Highlight);
    FG := Menu.BG;
  End Else Begin
    DrawBar(Menu.X + 2, YP, Menu.X + Menu.Width - 2, YP + ITEM_HEIGHT - 1,
            Menu.BG);
    If Itm.Enabled Then FG := Menu.FG Else FG := 8;
  End;

  { Checkbox/radio prefix }
  Prefix := '';
  Case Itm.ItemType Of
    RMU_ITEM_CHECK: If Itm.Checked Then Prefix := '[X] ' Else Prefix := '[ ] ';
    RMU_ITEM_RADIO: If Itm.Checked Then Prefix := '(*) ' Else Prefix := '( ) ';
    RMU_ITEM_SUB:   Prefix := '';
  End;

  { Draw text }
  GfxTextSetColor(FG, 255);
  GfxTextSetPos((Menu.X + PADDING_X) Div 8, YP Div 16);
  GfxTextPuts(Prefix + Itm.Text);

  { Submenu arrow }
  If Itm.ItemType = RMU_ITEM_SUB Then Begin
    GfxTextSetPos((Menu.X + Menu.Width - PADDING_X - 8) Div 8, YP Div 16);
    GfxTextPuts(#16); { right arrow }
  End;

  { Hotkey on right }
  If Itm.HotKey <> #0 Then Begin
    GfxTextSetColor(Menu.Highlight, 255);
    GfxTextSetPos((Menu.X + Menu.Width - PADDING_X - 16) Div 8, YP Div 16);
    GfxTextPuts(Itm.HotKey);
  End;
End;

{ === Navigation === }

Procedure RMUMoveUp(Var Menu: TRMUMenu);
Var Old, I: Integer;
Begin
  If Menu.Count <= 0 Then Exit;
  Old := Menu.Selected;
  For I := 1 To Menu.Count Do Begin
    Dec(Menu.Selected);
    If Menu.Selected < 0 Then Menu.Selected := Menu.Count - 1;
    If Menu.Items[Menu.Selected].ItemType <> RMU_ITEM_SEP Then Break;
  End;
  If Old <> Menu.Selected Then Begin
    RMURenderItem(Menu, Old, False);
    RMURenderItem(Menu, Menu.Selected, True);
  End;
End;

Procedure RMUMoveDown(Var Menu: TRMUMenu);
Var Old, I: Integer;
Begin
  If Menu.Count <= 0 Then Exit;
  Old := Menu.Selected;
  For I := 1 To Menu.Count Do Begin
    Inc(Menu.Selected);
    If Menu.Selected >= Menu.Count Then Menu.Selected := 0;
    If Menu.Items[Menu.Selected].ItemType <> RMU_ITEM_SEP Then Break;
  End;
  If Old <> Menu.Selected Then Begin
    RMURenderItem(Menu, Old, False);
    RMURenderItem(Menu, Menu.Selected, True);
  End;
End;

Function RMUFindHotKey(Var Menu: TRMUMenu; Key: Char): Integer;
Var I: Integer;
Begin
  Result := -1;
  For I := 0 To Menu.Count - 1 Do
    If (Menu.Items[I].HotKey = Key) And Menu.Items[I].Enabled And
       (Menu.Items[I].ItemType <> RMU_ITEM_SEP) Then Begin
      Result := I;
      Exit;
    End;
End;

Function RMUSelect(Var Menu: TRMUMenu): String;
Begin
  Result := '';
  If (Menu.Selected < 0) Or (Menu.Selected >= Menu.Count) Then Exit;
  If Not Menu.Items[Menu.Selected].Enabled Then Exit;
  Result := Menu.Items[Menu.Selected].Command;
End;

Procedure RMUToggleCheck(Var Menu: TRMUMenu; Index: Integer);
Var I: Integer;
    Grp: String;
Begin
  If (Index < 0) Or (Index >= Menu.Count) Then Exit;
  Case Menu.Items[Index].ItemType Of
    RMU_ITEM_CHECK:
      Menu.Items[Index].Checked := Not Menu.Items[Index].Checked;
    RMU_ITEM_RADIO: Begin
      { Find group — everything before ':' in command }
      Grp := '';
      I := Pos(':', Menu.Items[Index].Command);
      If I > 0 Then Grp := Copy(Menu.Items[Index].Command, 1, I - 1);
      { Uncheck all in same group }
      For I := 0 To Menu.Count - 1 Do
        If (Menu.Items[I].ItemType = RMU_ITEM_RADIO) And
           (Pos(Grp + ':', Menu.Items[I].Command) = 1) Then
          Menu.Items[I].Checked := False;
      Menu.Items[Index].Checked := True;
    End;
  End;
  RMURenderItem(Menu, Index, Index = Menu.Selected);
End;

{ === Hit test === }

Function RMUHitTest(Var Menu: TRMUMenu; PixX, PixY: SmallInt): Integer;
Var I, YP: Integer;
Begin
  Result := -1;
  If Not Menu.Visible Then Exit;
  If (PixX < Menu.X) Or (PixX > Menu.X + Menu.Width) Then Exit;

  For I := 0 To Menu.Count - 1 Do Begin
    YP := ItemY(Menu, I);
    If Menu.Items[I].ItemType = RMU_ITEM_SEP Then Continue;
    If (PixY >= YP) And (PixY < YP + ITEM_HEIGHT) Then Begin
      Result := I;
      Exit;
    End;
  End;
End;

{ === Menu stack === }

Procedure RMUPush(Var Menu: TRMUMenu);
Begin
  If StackTop >= RMU_MAX_MENUS Then Exit;
  MenuStack[StackTop] := @Menu;
  Inc(StackTop);
End;

Function RMUPop: PRMUMenu;
Begin
  Result := Nil;
  If StackTop <= 0 Then Exit;
  Dec(StackTop);
  Result := MenuStack[StackTop];
  MenuStack[StackTop] := Nil;
End;

Procedure RMUCloseAll;
Var I: Integer;
Begin
  For I := 0 To StackTop - 1 Do Begin
    If MenuStack[I] <> Nil Then
      MenuStack[I]^.Visible := False;
    MenuStack[I] := Nil;
  End;
  StackTop := 0;
End;

Function RMUActiveMenu: PRMUMenu;
Begin
  If StackTop > 0 Then
    Result := MenuStack[StackTop - 1]
  Else
    Result := Nil;
End;

Function RMUStackDepth: Integer;
Begin
  Result := StackTop;
End;

Initialization
  FillChar(MenuStack, SizeOf(MenuStack), 0);
  StackTop := 0;

Finalization
  RMUCloseAll;

End.
