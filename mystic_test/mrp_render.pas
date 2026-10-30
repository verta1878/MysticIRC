{$MODE DELPHI}
{$H-}
Unit MRP_Render;
{
  MRP_Render — Mystic Menu → RIPscrip renderer

  Loads Mystic .MNU text-format menu files (same format as BBS_MenuData)
  and renders menu items as RIPscrip 3D button graphics instead of ANSI
  pipe-code sequences.

  This is the "MRP extension" — porting Mystic's ANSI lightbar menus
  to RIPscrip graphical buttons for the mconfig testbed.

  Menu file format (text, one field per line):
    14-line header (RecMenuInfo fields)
    Per item: 21 lines + 6 lines per command

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses SysUtils;

Const
  MRP_MAX_ITEMS = 75;
  MRP_MAX_CMDS  = 25;

Type
  TMRPCommand = Record
    MenuCmd : String;
    Access  : String;
    Data    : String;
    JumpID  : Byte;
  End;

  TMRPItem = Record
    Text       : String;   { display text (ANSI pipe codes) }
    TextLo     : String;   { unselected text }
    TextHi     : String;   { selected/highlighted text }
    HotKey     : String;
    Access     : String;
    ShowType   : Byte;
    ReDraw     : Byte;
    TimerType  : Byte;
    JumpUp     : Byte;
    JumpDown   : Byte;
    JumpLeft   : Byte;
    JumpRight  : Byte;
    JumpEscape : Byte;
    JumpTab    : Byte;
    JumpPgUp   : Byte;
    JumpPgDn   : Byte;
    JumpHome   : Byte;
    JumpEnd    : Byte;
    X          : Byte;
    Y          : Byte;
    Timer      : Word;
    Commands   : Byte;
    Cmds       : Array[1..MRP_MAX_CMDS] of TMRPCommand;
  End;

  TMRPMenuInfo = Record
    Description : String;
    Access      : String;
    Fallback    : String;
    NodeStatus  : String;
    Header      : String;
    Footer      : String;
    DispFile    : String;
    DoneX       : Byte;
    DoneY       : Byte;
    MenuType    : Byte;
    InputType   : Byte;
    CharType    : Byte;
    DispCols    : Byte;
    Global      : Boolean;
  End;

  TMRPMenu = Record
    Info     : TMRPMenuInfo;
    Items    : Array[1..MRP_MAX_ITEMS] of TMRPItem;
    NumItems : Integer;
    Loaded   : Boolean;
  End;

{ Load a .MNU text file into a TMRPMenu record }
Function MRP_LoadMenu(Const FileName: String; Var Menu: TMRPMenu): Boolean;

{ Strip ANSI pipe codes from a string, returning plain text }
Function MRP_StripPipes(Const S: String): String;

{ Render the menu as RIP graphics on the current canvas }
Procedure MRP_RenderMenu(Var Menu: TMRPMenu; Selected: Integer);

{ Render a single menu item as a RIP 3D button }
Procedure MRP_RenderButton(Var Item: TMRPItem; X0, Y0, W, H: Integer;
                           IsSelected: Boolean);

Implementation

Uses RIPEngine, RIPDraw, RIPText, RIPWidgets;

{ ---- Pipe code stripping ---- }

Function MRP_StripPipes(Const S: String): String;
{ Strips Mystic BBS pipe codes: |XX where XX is 00-23 (color),
  |CR (newline), and other |xx control codes.
  Returns plain text suitable for RIP rendering. }
Var
  I   : Integer;
  Len : Integer;
Begin
  Result := '';
  I := 1;
  Len := Length(S);
  While I <= Len Do Begin
    If (S[I] = '|') And (I + 2 <= Len) Then Begin
      { Check for 2-char pipe code }
      If (S[I+1] >= '0') And (S[I+1] <= '9') And
         (S[I+2] >= '0') And (S[I+2] <= '9') Then Begin
        Inc(I, 3); { skip |XX color code }
        Continue;
      End;
      If (UpCase(S[I+1]) = 'C') And (UpCase(S[I+2]) = 'R') Then Begin
        Inc(I, 3); { skip |CR }
        Continue;
      End;
      { Check for other 2-char codes like |BS, |CL, etc }
      If (S[I+1] >= 'A') And (S[I+1] <= 'Z') And
         (S[I+2] >= 'A') And (S[I+2] <= 'Z') Then Begin
        Inc(I, 3);
        Continue;
      End;
      If (UpCase(S[I+1]) >= 'a') And (UpCase(S[I+1]) <= 'z') And
         (UpCase(S[I+2]) >= 'a') And (UpCase(S[I+2]) <= 'z') Then Begin
        Inc(I, 3);
        Continue;
      End;
    End;
    Result := Result + S[I];
    Inc(I);
  End;
End;

{ ---- Safe string→integer ---- }

Function SafeStrToInt(Const S: String; Default: Integer): Integer;
Var Code: Integer;
Begin
  Val(S, Result, Code);
  If Code <> 0 Then Result := Default;
End;

{ ---- Menu file loader ---- }

Function MRP_LoadMenu(Const FileName: String; Var Menu: TMRPMenu): Boolean;
Var
  F     : Text;
  Buf   : Array[1..4096] of Byte;
  S     : String;
  Flags : String;
  I, C  : Integer;
Begin
  Result := False;
  FillChar(Menu, SizeOf(Menu), 0);
  Menu.Loaded := False;

  If Not FileExists(FileName) Then Exit;

  Assign(F, FileName);
  SetTextBuf(F, Buf);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  { Read 14-line header }
  ReadLn(F, Menu.Info.Description);
  ReadLn(F, Menu.Info.Access);
  ReadLn(F, Menu.Info.Fallback);
  ReadLn(F, Flags);
  ReadLn(F, S); { reserved }
  ReadLn(F, Menu.Info.NodeStatus);
  ReadLn(F, Menu.Info.Header);
  ReadLn(F, Menu.Info.Footer);
  ReadLn(F, Menu.Info.DispFile);
  ReadLn(F, S); Menu.Info.DoneX := SafeStrToInt(S, 0);
  ReadLn(F, S); Menu.Info.DoneY := SafeStrToInt(S, 0);
  ReadLn(F, S); { reserved }
  ReadLn(F, S); { reserved }
  ReadLn(F, S); { reserved }

  { Parse flags }
  If Length(Flags) >= 5 Then Begin
    Menu.Info.CharType  := Ord(Flags[1]) - Ord('0');
    Menu.Info.MenuType  := Ord(Flags[2]) - Ord('0');
    Menu.Info.InputType := Ord(Flags[3]) - Ord('0');
    Menu.Info.DispCols  := Ord(Flags[4]) - Ord('0');
    Menu.Info.Global    := (Flags[5] = '1');
  End;

  { Read items }
  Menu.NumItems := 0;
  While Not EOF(F) And (Menu.NumItems < MRP_MAX_ITEMS) Do Begin
    Inc(Menu.NumItems);
    I := Menu.NumItems;

    ReadLn(F, Menu.Items[I].Text);
    ReadLn(F, Menu.Items[I].TextLo);
    ReadLn(F, Menu.Items[I].TextHi);
    ReadLn(F, Menu.Items[I].HotKey);
    ReadLn(F, Menu.Items[I].Access);
    ReadLn(F, Flags);
    ReadLn(F, S); Menu.Items[I].Timer := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].X := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].Y := SafeStrToInt(S, 0);
    ReadLn(F, S); { reserved }
    ReadLn(F, S); { reserved }
    ReadLn(F, S); { reserved }
    ReadLn(F, S); Menu.Items[I].JumpUp     := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].JumpDown   := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].JumpLeft   := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].JumpRight  := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].JumpEscape := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].JumpTab    := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].JumpPgUp   := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].JumpPgDn   := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].JumpHome   := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].JumpEnd    := SafeStrToInt(S, 0);
    ReadLn(F, S); Menu.Items[I].Commands   := SafeStrToInt(S, 0);

    { Parse item flags }
    If Length(Flags) >= 3 Then Begin
      Menu.Items[I].ReDraw    := Ord(Flags[1]) - Ord('0');
      Menu.Items[I].TimerType := Ord(Flags[2]) - Ord('0');
      Menu.Items[I].ShowType  := Ord(Flags[3]) - Ord('0');
    End;

    { Read commands }
    For C := 1 to Menu.Items[I].Commands Do Begin
      If C <= MRP_MAX_CMDS Then Begin
        ReadLn(F, Menu.Items[I].Cmds[C].MenuCmd);
        ReadLn(F, Menu.Items[I].Cmds[C].Access);
        ReadLn(F, Menu.Items[I].Cmds[C].Data);
        ReadLn(F, S); Menu.Items[I].Cmds[C].JumpID := SafeStrToInt(S, 0);
        ReadLn(F, S); { reserved }
        ReadLn(F, S); { reserved }
      End Else Begin
        { Skip excess commands }
        ReadLn(F, S); ReadLn(F, S); ReadLn(F, S);
        ReadLn(F, S); ReadLn(F, S); ReadLn(F, S);
      End;
    End;
  End;

  Close(F);
  Menu.Loaded := True;
  Result := True;
End;

{ ---- RIP button rendering ---- }

Procedure MRP_RenderButton(Var Item: TMRPItem; X0, Y0, W, H: Integer;
                           IsSelected: Boolean);
{ Renders a single menu item as a RIP 3D button.
  Selected items get a raised bright look; unselected get flat gray. }
Var
  Label_  : String;
  HK      : String;
  LabelX  : Integer;
  LabelY  : Integer;
Begin
  { Strip pipe codes to get plain text }
  If IsSelected Then
    Label_ := MRP_StripPipes(Item.TextHi)
  Else
    Label_ := MRP_StripPipes(Item.TextLo);

  If Label_ = '' Then
    Label_ := MRP_StripPipes(Item.Text);

  HK := Item.HotKey;

  { Draw button box }
  If IsSelected Then Begin
    { Raised bright button — selected }
    DrawRaisedBox(X0, Y0, X0 + W, Y0 + H, 9, 15, 1);  { light blue surface }
    SetColor(15);  { white text }
  End Else Begin
    { Flat gray button — unselected }
    DrawRaisedBox(X0, Y0, X0 + W, Y0 + H, 7, 15, 8);  { gray surface }
    SetColor(0);   { black text }
  End;

  { Center text vertically }
  LabelY := Y0 + (H - TextHeight) Div 2;

  { Draw hotkey in brackets on the left }
  If HK <> '' Then Begin
    LabelX := X0 + 6;
    If IsSelected Then SetColor(14) Else SetColor(4); { yellow / dark red }
    OutTextXY(LabelX, LabelY, '(' + HK + ')');
    LabelX := LabelX + TextWidth('(' + HK + ') ');
    If IsSelected Then SetColor(15) Else SetColor(0);
    OutTextXY(LabelX, LabelY, Label_);
  End Else Begin
    { Center text horizontally }
    LabelX := X0 + (W - TextWidth(Label_)) Div 2;
    OutTextXY(LabelX, LabelY, Label_);
  End;
End;

{ ---- Full menu renderer ---- }

Procedure MRP_RenderMenu(Var Menu: TMRPMenu; Selected: Integer);
{ Renders the entire menu as RIP graphics.
  Layout: title bar at top, items arranged in columns per DispCols,
  each item as a 3D button. }
Var
  I         : Integer;
  BtnW      : Integer;
  BtnH      : Integer;
  BtnX      : Integer;
  BtnY      : Integer;
  Col       : Integer;
  Row       : Integer;
  Cols      : Integer;
  MarginX   : Integer;
  MarginY   : Integer;
  GapX      : Integer;
  GapY      : Integer;
  MaxRows   : Integer;
  Title     : String;
Begin
  If Not Menu.Loaded Then Exit;

  { Layout parameters }
  Cols := Menu.Info.DispCols;
  If Cols < 1 Then Cols := 1;
  If Cols > 4 Then Cols := 4;

  MarginX := 10;
  MarginY := 50;
  GapX := 6;
  GapY := 4;
  BtnH := 20;

  { Calculate button width based on columns }
  BtnW := (RIP_WIDTH - 2 * MarginX - (Cols - 1) * GapX) Div Cols;

  { Draw background }
  FillRect(0, 0, RIP_WIDTH - 1, RIP_HEIGHT - 1, 1); { dark blue }

  { Title bar }
  Title := MRP_StripPipes(Menu.Info.Description);
  If Title = '' Then Title := 'Menu';
  DrawRaisedBox(0, 0, RIP_WIDTH - 1, 28, 7, 15, 8);
  SetColor(0);
  DrawTextCentered(0, 0, RIP_WIDTH - 1, 28, Title, 0);

  { Header text }
  If Menu.Info.Header <> '' Then Begin
    SetColor(14);
    OutTextXY(MarginX, 34, MRP_StripPipes(Menu.Info.Header));
  End;

  { Render each item as a button }
  For I := 1 to Menu.NumItems Do Begin
    Col := (I - 1) Mod Cols;
    Row := (I - 1) Div Cols;

    BtnX := MarginX + Col * (BtnW + GapX);
    BtnY := MarginY + Row * (BtnH + GapY);

    { Skip if off-screen }
    If BtnY + BtnH > RIP_HEIGHT - 20 Then Break;

    { Use item X/Y if set (non-zero = absolute positioning) }
    If (Menu.Items[I].X > 0) And (Menu.Items[I].Y > 0) Then Begin
      { Convert text col/row (1-based, 8px char) to pixel coords }
      BtnX := (Menu.Items[I].X - 1) * 8;
      BtnY := (Menu.Items[I].Y - 1) * 14;  { 14px per row in EGA }
    End;

    MRP_RenderButton(Menu.Items[I], BtnX, BtnY, BtnW, BtnH,
                     (I = Selected));
  End;

  { Footer / status bar }
  FillRect(0, RIP_HEIGHT - 16, RIP_WIDTH - 1, RIP_HEIGHT - 1, 0);
  SetColor(11);
  If Menu.Info.Footer <> '' Then
    OutTextXY(8, RIP_HEIGHT - 14, MRP_StripPipes(Menu.Info.Footer))
  Else
    OutTextXY(8, RIP_HEIGHT - 14, 'Up/Dn=Navigate  Enter=Select  Esc=Back');
End;

End.
