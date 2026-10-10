{$MODE DELPHI}
{$H-}
Program MConfig;
{
  MConfig v0.1 — Mystic BBS Configuration Tool (RIPscrip/BGI UI)
  Standalone replacement for mystic.exe -cfg

  Uses FPC Graph unit for screen display (ptcgraph on Linux,
  Graph on DOS/Windows via fpc264irc).
  Uses the ripview procedural stack for all UI rendering.
  Reads/writes mystic.dat (RecConfig record).

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Uses
  SysUtils, Keyboard,
  {$IFDEF UNIX}ptcgraph, ptcmouse{$ELSE}Graph{$ENDIF},
  RIPEngine, RIPDraw, RIPText, RIPWidgets, RIPMouse, RIPState,
  RIPTextVar, RIPBmp;

{$I records.pas}

Const
  VERSION = 'MConfig v0.1 (2026-09-29) — Mystic BBS Configuration';

  { Colors — EGA palette }
  CLR_BG      = 1;   { dark blue background }
  CLR_TITLE   = 15;  { white title }
  CLR_MENU_BG = 7;   { light gray menu surface }
  CLR_MENU_FG = 0;   { black text }
  CLR_HILITE  = 9;   { light blue highlight }
  CLR_SHADOW  = 8;   { dark gray shadow }
  CLR_BRIGHT  = 15;  { white highlight }

Var
  Config     : RecConfig;
  ConfigPath : String;
  HasConfig  : Boolean;
  Selection  : Integer;
  Running    : Boolean;
  K          : TKeyEvent;
  Gd, Gm    : SmallInt;

{ ---- Config file I/O ---- }

Function LoadConfig(Const Path: String): Boolean;
Var F: File;
Begin
  Result := False;
  Assign(F, Path);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  If FileSize(F) >= SizeOf(RecConfig) Then Begin
    BlockRead(F, Config, SizeOf(RecConfig));
    Result := True;
  End;
  Close(F);
End;

Function SaveConfig(Const Path: String): Boolean;
Var F: File;
Begin
  Result := False;
  Assign(F, Path);
  {$I-} ReWrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  BlockWrite(F, Config, SizeOf(RecConfig));
  Close(F);
  Result := True;
End;

{ ---- Flush canvas to screen via Graph ---- }

Procedure FlushToScreen;
Var X, Y: Integer;
Begin
  For Y := 0 To RIP_HEIGHT - 1 Do
    For X := 0 To RIP_WIDTH - 1 Do
      {$IFDEF UNIX}ptcgraph{$ELSE}Graph{$ENDIF}.PutPixel(X, Y, Canvas.Pixels^[X, Y]);
End;

{ ---- UI Drawing ---- }

Procedure DrawBackground;
Var Y: Integer;
Begin
  For Y := 0 To RIP_HEIGHT - 1 Do
    HLine(0, RIP_WIDTH - 1, Y, 1);
End;

Procedure DrawTitleBar;
Begin
  DrawRaisedBox(0, 0, RIP_WIDTH - 1, 28, CLR_MENU_BG, CLR_BRIGHT, CLR_SHADOW);
  DrawTextCentered(0, 0, RIP_WIDTH - 1, 28, VERSION, CLR_MENU_FG);
End;

Procedure DrawStatusBar(Const Msg: String);
Begin
  FillRect(0, RIP_HEIGHT - 16, RIP_WIDTH - 1, RIP_HEIGHT - 1, 0);
  OutTextXY(8, RIP_HEIGHT - 14, Msg);
End;

Procedure DrawMenuItem(X, Y, W: Integer; Const Text: String; Selected: Boolean);
Begin
  If Selected Then
    DrawRaisedBox(X, Y, X + W, Y + 20, CLR_HILITE, CLR_BRIGHT, CLR_SHADOW)
  Else
    DrawRaisedBox(X, Y, X + W, Y + 20, CLR_MENU_BG, CLR_BRIGHT, CLR_SHADOW);
  OutTextXY(X + 8, Y + 4, Text);
End;

Procedure DrawMainMenu;
Var Y, MX, MW: Integer;
Begin
  DrawBackground;
  DrawTitleBar;

  MX := 10; MW := 200;
  DrawRaisedBox(MX - 5, 30, MX + MW + 5, 200, CLR_MENU_BG, CLR_BRIGHT, CLR_SHADOW);
  OutTextXY(MX, 34, 'Main Configuration Menu');

  Y := 50;
  DrawMenuItem(MX, Y,       MW, '1. General Settings',    Selection = 0); Y := Y + 24;
  DrawMenuItem(MX, Y,       MW, '2. System Paths',        Selection = 1); Y := Y + 24;
  DrawMenuItem(MX, Y,       MW, '3. New User Settings',   Selection = 2); Y := Y + 24;
  DrawMenuItem(MX, Y,       MW, '4. Console / Status Bar', Selection = 3); Y := Y + 24;
  DrawSeparatorH(MX, MX + MW, Y + 2, CLR_BRIGHT, CLR_SHADOW);
  Y := Y + 8;
  DrawMenuItem(MX, Y,       MW, 'Q. Save and Quit',       Selection = 4);

  If HasConfig Then
    DrawStatusBar('Loaded: ' + ConfigPath + ' | Arrows/Enter/Q')
  Else
    DrawStatusBar('No mystic.dat — defaults | Arrows/Enter/Q');

  FlushToScreen;
End;

{ ---- General Settings field definitions ---- }

Const
  GS_FIELDS = 8;  { 6 text + 2 checkbox }
  GS_FY : Array[0..GS_FIELDS-1] of Integer = (60, 82, 104, 126, 148, 170, 200, 200);
  GS_LBL: Array[0..GS_FIELDS-1] of String[16] =
    ('BBS Name:', 'Sysop Name:', 'Feedback To:', 'Inactivity:', 'Start Menu:', 'Theme File:',
     'Log sysop chat', 'Feedback missed');
  GS_FX  = 120;   { field X for text fields }
  GS_CBX = 200;   { second checkbox X }

Function GS_FieldVal(Idx: Integer): String;
Begin
  Case Idx Of
    0: Result := Config.BBSName;
    1: Result := Config.SysopName;
    2: Result := Config.FeedbackTo;
    3: Result := IntToStr(Config.Inactivity) + 's';
    4: Result := Config.DefStartMenu;
    5: Result := Config.DefThemeFile;
    6: If Config.ChatLogging Then Result := 'ON' Else Result := 'OFF';
    7: If Config.ChatFeedback Then Result := 'ON' Else Result := 'OFF';
  Else Result := '';
  End;
End;

Function GS_FieldWidth(Idx: Integer): Integer;
Begin
  Case Idx Of
    0, 1, 2: Result := 500;
    3:       Result := 200;
    4, 5:    Result := 300;
  Else       Result := 0;
  End;
End;

Function GS_MaxLen(Idx: Integer): Integer;
Begin
  Case Idx Of
    0, 1, 2: Result := 40;
    3:       Result := 5;
    4, 5:    Result := 30;
  Else       Result := 0;
  End;
End;

Procedure DrawGeneralPage(CurField: Integer);
Var I, Y, BX2: Integer;
    IsSelected: Boolean;
Begin
  DrawBackground;
  DrawTitleBar;
  DrawRaisedBox(5, 35, RIP_WIDTH - 6, RIP_HEIGHT - 20, CLR_MENU_BG, CLR_BRIGHT, CLR_SHADOW);
  OutTextXY(12, 40, 'General Settings');
  DrawSeparatorH(10, RIP_WIDTH - 10, 52, CLR_BRIGHT, CLR_SHADOW);

  { Text fields 0..5 }
  For I := 0 to 5 Do Begin
    Y := GS_FY[I];
    IsSelected := (I = CurField);
    OutTextXY(12, Y, GS_LBL[I]);
    BX2 := GS_FieldWidth(I);
    If IsSelected Then
      DrawSunkenBox(GS_FX, Y-2, BX2, Y+12, 4, CLR_SHADOW, CLR_BRIGHT)  { highlight bg=4 red }
    Else
      DrawSunkenBox(GS_FX, Y-2, BX2, Y+12, 0, CLR_SHADOW, CLR_BRIGHT);
    If IsSelected Then SetColor(15) Else SetColor(CLR_MENU_FG);
    OutTextXY(GS_FX + 4, Y, GS_FieldVal(I));
  End;

  { Checkboxes 6..7 }
  Y := GS_FY[6];
  DrawCheckbox(12, Y, 12, Config.ChatLogging, CLR_MENU_FG, CLR_MENU_BG);
  If CurField = 6 Then SetColor(15) Else SetColor(CLR_MENU_FG);
  OutTextXY(30, Y + 2, GS_LBL[6]);

  DrawCheckbox(GS_CBX, Y, 12, Config.ChatFeedback, CLR_MENU_FG, CLR_MENU_BG);
  If CurField = 7 Then SetColor(15) Else SetColor(CLR_MENU_FG);
  OutTextXY(GS_CBX + 18, Y + 2, GS_LBL[7]);

  SetColor(CLR_MENU_FG);
  DrawStatusBar('Up/Down=Move  ENTER=Edit  SPACE=Toggle  ESC=Back');
  FlushToScreen;
End;

Function EditTextField(Var Val: String; MaxLen: Integer; FX, FY, FW: Integer): Boolean;
{ Inline editor — draws directly into the sunken box area.
  Returns True if committed (Enter), False if cancelled (Esc). }
Var
  Buf : String;
  K   : TKeyEvent;
  Code: Word;
  Ch  : Char;
  Done: Boolean;
Begin
  Result := False;
  Buf := Val;
  Done := False;
  Repeat
    { Clear field area and redraw }
    DrawSunkenBox(FX, FY-2, FW, FY+12, 1, CLR_SHADOW, CLR_BRIGHT);  { bg=1 blue = editing }
    SetColor(15);
    OutTextXY(FX + 4, FY, Buf + '_');
    FlushToScreen;

    K := GetKeyEvent;
    K := TranslateKeyEvent(K);
    Code := GetKeyEventCode(K);
    Ch := GetKeyEventChar(K);

    Case Code Of
      $000D: Begin Val := Buf; Result := True; Done := True; End;  { Enter }
      $001B: Done := True;                                          { Esc }
      $0008: If Length(Buf) > 0 Then Delete(Buf, Length(Buf), 1);   { Backspace }
    Else
      If (Ch >= ' ') And (Ch <= '~') And (Length(Buf) < MaxLen) Then
        Buf := Buf + Ch;
    End;
  Until Done;
End;

Function EditNumField(Var Val: LongInt; MaxLen: Integer; Lo, Hi: LongInt;
                       FX, FY, FW: Integer): Boolean;
Var
  Buf : String;
  K   : TKeyEvent;
  Code: Word;
  Ch  : Char;
  Done: Boolean;
  N   : LongInt;
Begin
  Result := False;
  Buf := IntToStr(Val);
  Done := False;
  Repeat
    DrawSunkenBox(FX, FY-2, FW, FY+12, 1, CLR_SHADOW, CLR_BRIGHT);
    SetColor(15);
    OutTextXY(FX + 4, FY, Buf + '_');
    FlushToScreen;

    K := GetKeyEvent;
    K := TranslateKeyEvent(K);
    Code := GetKeyEventCode(K);
    Ch := GetKeyEventChar(K);

    Case Code Of
      $000D: Begin
        N := StrToIntDef(Buf, -1);
        If (N >= Lo) And (N <= Hi) Then Begin Val := N; Result := True; End;
        Done := True;
      End;
      $001B: Done := True;
      $0008: If Length(Buf) > 0 Then Delete(Buf, Length(Buf), 1);
    Else
      If (Ch >= '0') And (Ch <= '9') And (Length(Buf) < MaxLen) Then
        Buf := Buf + Ch;
    End;
  Until Done;
End;

Procedure RunGeneralSettings;
Var
  CurField : Integer;
  GSRunning: Boolean;
  K        : TKeyEvent;
  Code     : Word;
  S        : String;
  N        : LongInt;
Begin
  CurField := 0;
  GSRunning := True;
  DrawGeneralPage(CurField);

  While GSRunning Do Begin
    K := GetKeyEvent;
    K := TranslateKeyEvent(K);
    Code := GetKeyEventCode(K);

    Case Code Of
      $4800: Begin { Up }
        If CurField > 0 Then Dec(CurField);
        DrawGeneralPage(CurField);
      End;
      $5000: Begin { Down }
        If CurField < GS_FIELDS - 1 Then Inc(CurField);
        DrawGeneralPage(CurField);
      End;
      $4B00: Begin { Left — on checkbox row, move between checkboxes }
        If (CurField = 7) Then Begin CurField := 6; DrawGeneralPage(CurField); End;
      End;
      $4D00: Begin { Right }
        If (CurField = 6) Then Begin CurField := 7; DrawGeneralPage(CurField); End;
      End;
      $000D: Begin { Enter — edit text field or toggle checkbox }
        Case CurField Of
          0: Begin S := Config.BBSName;      If EditTextField(S, GS_MaxLen(0), GS_FX, GS_FY[0], GS_FieldWidth(0)) Then Config.BBSName := S; End;
          1: Begin S := Config.SysopName;    If EditTextField(S, GS_MaxLen(1), GS_FX, GS_FY[1], GS_FieldWidth(1)) Then Config.SysopName := S; End;
          2: Begin S := Config.FeedbackTo;   If EditTextField(S, GS_MaxLen(2), GS_FX, GS_FY[2], GS_FieldWidth(2)) Then Config.FeedbackTo := S; End;
          3: Begin N := Config.Inactivity;   If EditNumField(N, GS_MaxLen(3), 0, 99999, GS_FX, GS_FY[3], GS_FieldWidth(3)) Then Config.Inactivity := N; End;
          4: Begin S := Config.DefStartMenu; If EditTextField(S, GS_MaxLen(4), GS_FX, GS_FY[4], GS_FieldWidth(4)) Then Config.DefStartMenu := S; End;
          5: Begin S := Config.DefThemeFile;  If EditTextField(S, GS_MaxLen(5), GS_FX, GS_FY[5], GS_FieldWidth(5)) Then Config.DefThemeFile := S; End;
          6: Config.ChatLogging  := Not Config.ChatLogging;
          7: Config.ChatFeedback := Not Config.ChatFeedback;
        End;
        DrawGeneralPage(CurField);
      End;
      $0020: Begin { Space — toggle checkboxes }
        If CurField = 6 Then Config.ChatLogging  := Not Config.ChatLogging;
        If CurField = 7 Then Config.ChatFeedback := Not Config.ChatFeedback;
        DrawGeneralPage(CurField);
      End;
      $001B: GSRunning := False; { ESC — back }
    End;
  End;
End;

{ ---- System Paths page ---- }

Const
  SP_FIELDS = 12;
  SP_FY_BASE = 60;
  SP_STEP    = 20;
  SP_FX      = 130;
  SP_FW      = 580;
  SP_LBL: Array[0..SP_FIELDS-1] of String[16] =
    ('System:', 'Data:', 'Logs:', 'Messages:', 'Attach:', 'Scripts:',
     'QWK:', 'Semaphore:', 'Inbound:', 'Menus:', 'Text:', 'Outbound:');

Function SP_GetVal(Idx: Integer): String;
Begin
  Case Idx Of
    0:  Result := Config.SystemPath;
    1:  Result := Config.DataPath;
    2:  Result := Config.LogsPath;
    3:  Result := Config.MsgsPath;
    4:  Result := Config.AttachPath;
    5:  Result := Config.ScriptPath;
    6:  Result := Config.QwkPath;
    7:  Result := Config.SemaPath;
    8:  Result := Config.InboundPath;
    9:  Result := Config.MenuPath;
    10: Result := Config.TextPath;
    11: Result := Config.OutboundPath;
  Else  Result := '';
  End;
End;

Procedure SP_SetVal(Idx: Integer; Const Val: String);
Begin
  Case Idx Of
    0:  Config.SystemPath   := Val;
    1:  Config.DataPath     := Val;
    2:  Config.LogsPath     := Val;
    3:  Config.MsgsPath     := Val;
    4:  Config.AttachPath   := Val;
    5:  Config.ScriptPath   := Val;
    6:  Config.QwkPath      := Val;
    7:  Config.SemaPath     := Val;
    8:  Config.InboundPath  := Val;
    9:  Config.MenuPath     := Val;
    10: Config.TextPath     := Val;
    11: Config.OutboundPath := Val;
  End;
End;

Procedure DrawPathsPage(CurField: Integer);
Var I, Y: Integer;
Begin
  DrawBackground;
  DrawTitleBar;
  DrawRaisedBox(5, 35, RIP_WIDTH - 6, RIP_HEIGHT - 20, CLR_MENU_BG, CLR_BRIGHT, CLR_SHADOW);
  OutTextXY(12, 40, 'System Paths');
  DrawSeparatorH(10, RIP_WIDTH - 10, 52, CLR_BRIGHT, CLR_SHADOW);

  For I := 0 to SP_FIELDS - 1 Do Begin
    Y := SP_FY_BASE + I * SP_STEP;
    OutTextXY(12, Y, SP_LBL[I]);
    If I = CurField Then Begin
      DrawSunkenBox(SP_FX, Y-2, SP_FW, Y+12, 4, CLR_SHADOW, CLR_BRIGHT);
      SetColor(15);
    End Else Begin
      DrawSunkenBox(SP_FX, Y-2, SP_FW, Y+12, 0, CLR_SHADOW, CLR_BRIGHT);
      SetColor(CLR_MENU_FG);
    End;
    OutTextXY(SP_FX + 4, Y, SP_GetVal(I));
  End;

  SetColor(CLR_MENU_FG);
  DrawStatusBar('Up/Down=Move  ENTER=Edit  ESC=Back');
  FlushToScreen;
End;

Procedure RunSystemPaths;
Var
  CurField : Integer;
  SPRunning: Boolean;
  K        : TKeyEvent;
  Code     : Word;
  S        : String;
Begin
  CurField := 0;
  SPRunning := True;
  DrawPathsPage(CurField);

  While SPRunning Do Begin
    K := GetKeyEvent;
    K := TranslateKeyEvent(K);
    Code := GetKeyEventCode(K);

    Case Code Of
      $4800: Begin
        If CurField > 0 Then Dec(CurField);
        DrawPathsPage(CurField);
      End;
      $5000: Begin
        If CurField < SP_FIELDS - 1 Then Inc(CurField);
        DrawPathsPage(CurField);
      End;
      $000D: Begin
        S := SP_GetVal(CurField);
        If EditTextField(S, 80, SP_FX, SP_FY_BASE + CurField * SP_STEP, SP_FW) Then
          SP_SetVal(CurField, S);
        DrawPathsPage(CurField);
      End;
      $001B: SPRunning := False;
    End;
  End;
End;

{ ---- New User Settings page ---- }

Const
  NU_FIELDS = 14;  { top section: 4 settings + 10 choice/toggle fields }
  NU_ASK    = 14;  { bottom: 14 ask-for checkboxes }

  NU_LBL: Array[0..NU_FIELDS-1] of String[16] =
    ('Allow New Users', 'New User Sec:', 'New User PW:', 'Email Verify',
     'Name Format:', 'Date Format:', 'Editor:', 'Hot Keys:',
     'Full Chat:', 'File List:', 'Msg Reader:', 'Mail Index:',
     'Quote Window:', 'Protocol:');

  NU_ASK_LBL: Array[0..NU_ASK-1] of String[14] =
    ('Theme', 'Real Name', 'Alias', 'Street', 'City/State', 'Zip Code',
     'Home Phone', 'Data Phone', 'Birthdate', 'Gender', 'Email',
     'User Note', 'Screen Size', 'Screen Cols');

Function NU_ChoiceStr(Val, Max: Byte; Const Labels: Array of String): String;
Var I: Integer;
Begin
  I := Val;
  If I > Max Then I := 0;
  Result := Labels[I];
End;

Procedure DrawNewUserPage(CurField, ScrollOfs: Integer);
Var I, Y, Col: Integer;
    S: String;
    IsSelected: Boolean;
Begin
  DrawBackground;
  DrawTitleBar;
  DrawRaisedBox(5, 35, RIP_WIDTH - 6, RIP_HEIGHT - 20, CLR_MENU_BG, CLR_BRIGHT, CLR_SHADOW);
  OutTextXY(12, 40, 'New User Settings');
  DrawSeparatorH(10, RIP_WIDTH - 10, 52, CLR_BRIGHT, CLR_SHADOW);

  { Top section — settings fields }
  For I := 0 to NU_FIELDS - 1 Do Begin
    Y := 58 + I * 16;
    IsSelected := (CurField = I);
    If IsSelected Then SetColor(15) Else SetColor(CLR_MENU_FG);
    OutTextXY(12, Y, NU_LBL[I]);

    Case I Of
      0: If Config.AllowNewUsers Then S := '[YES]' Else S := '[NO]';
      1: S := IntToStr(Config.NewUserSec);
      2: S := Config.NewUserPW;
      3: If Config.NewUserEMail Then S := '[YES]' Else S := '[NO]';
      4: S := NU_ChoiceStr(Config.UserNameFormat, 3, ['Typed', 'Upper', 'Lower', 'Proper']);
      5: S := NU_ChoiceStr(Config.UserDateType, 3, ['MM/DD/YY', 'DD/MM/YY', 'YY/DD/MM', 'Ask']);
      6: S := NU_ChoiceStr(Config.UserEditorType, 2, ['Line', 'Full', 'Ask']);
      7: S := NU_ChoiceStr(Config.UserHotKeys, 2, ['No', 'Yes', 'Ask']);
      8: S := NU_ChoiceStr(Config.UserFullChat, 2, ['No', 'Yes', 'Ask']);
      9: S := NU_ChoiceStr(Config.UserFileList, 2, ['Normal', 'Lightbar', 'Ask']);
     10: S := NU_ChoiceStr(Config.UserReadType, 2, ['Normal', 'ANSI', 'Ask']);
     11: S := NU_ChoiceStr(Config.UserMailIndex, 2, ['Normal', 'ANSI', 'Ask']);
     12: S := NU_ChoiceStr(Config.UserQuoteWin, 2, ['Line', 'Window', 'Ask']);
     13: S := NU_ChoiceStr(Config.UserProtocol, 2, ['No', 'Yes', 'Ask']);
    Else S := '';
    End;

    If IsSelected Then
      DrawSunkenBox(150, Y-2, 300, Y+12, 4, CLR_SHADOW, CLR_BRIGHT)
    Else
      DrawSunkenBox(150, Y-2, 300, Y+12, 0, CLR_SHADOW, CLR_BRIGHT);
    If IsSelected Then SetColor(15) Else SetColor(CLR_MENU_FG);
    OutTextXY(154, Y, S);
  End;

  { Bottom section — ask-for checkboxes, 2 columns }
  DrawSeparatorH(10, RIP_WIDTH - 10, 290, CLR_BRIGHT, CLR_SHADOW);
  SetColor(CLR_MENU_FG);
  OutTextXY(12, 295, 'Ask New User For:');

  For I := 0 to NU_ASK - 1 Do Begin
    If I < 7 Then Begin Col := 12;  Y := 310 + I * 16; End
    Else          Begin Col := 250; Y := 310 + (I - 7) * 16; End;

    IsSelected := (CurField = NU_FIELDS + I);

    Case I Of
      0:  DrawCheckbox(Col, Y, 10, Config.AskTheme,      CLR_MENU_FG, CLR_MENU_BG);
      1:  DrawCheckbox(Col, Y, 10, Config.AskRealName,    CLR_MENU_FG, CLR_MENU_BG);
      2:  DrawCheckbox(Col, Y, 10, Config.AskAlias,       CLR_MENU_FG, CLR_MENU_BG);
      3:  DrawCheckbox(Col, Y, 10, Config.AskStreet,      CLR_MENU_FG, CLR_MENU_BG);
      4:  DrawCheckbox(Col, Y, 10, Config.AskCityState,   CLR_MENU_FG, CLR_MENU_BG);
      5:  DrawCheckbox(Col, Y, 10, Config.AskZipCode,     CLR_MENU_FG, CLR_MENU_BG);
      6:  DrawCheckbox(Col, Y, 10, Config.AskHomePhone,   CLR_MENU_FG, CLR_MENU_BG);
      7:  DrawCheckbox(Col, Y, 10, Config.AskDataPhone,   CLR_MENU_FG, CLR_MENU_BG);
      8:  DrawCheckbox(Col, Y, 10, Config.AskBirthdate,   CLR_MENU_FG, CLR_MENU_BG);
      9:  DrawCheckbox(Col, Y, 10, Config.AskGender,      CLR_MENU_FG, CLR_MENU_BG);
      10: DrawCheckbox(Col, Y, 10, Config.AskEmail,       CLR_MENU_FG, CLR_MENU_BG);
      11: DrawCheckbox(Col, Y, 10, Config.AskUserNote,    CLR_MENU_FG, CLR_MENU_BG);
      12: DrawCheckbox(Col, Y, 10, Config.AskScreenSize,  CLR_MENU_FG, CLR_MENU_BG);
      13: DrawCheckbox(Col, Y, 10, Config.AskScreenCols,  CLR_MENU_FG, CLR_MENU_BG);
    End;

    If IsSelected Then SetColor(15) Else SetColor(CLR_MENU_FG);
    OutTextXY(Col + 16, Y + 1, NU_ASK_LBL[I]);
  End;

  SetColor(CLR_MENU_FG);
  DrawStatusBar('Up/Dn=Move  ENTER/SPACE=Edit/Toggle  ESC=Back');
  FlushToScreen;
End;

Procedure NU_ToggleAsk(Idx: Integer);
Begin
  Case Idx Of
    0:  Config.AskTheme      := Not Config.AskTheme;
    1:  Config.AskRealName   := Not Config.AskRealName;
    2:  Config.AskAlias      := Not Config.AskAlias;
    3:  Config.AskStreet     := Not Config.AskStreet;
    4:  Config.AskCityState  := Not Config.AskCityState;
    5:  Config.AskZipCode    := Not Config.AskZipCode;
    6:  Config.AskHomePhone  := Not Config.AskHomePhone;
    7:  Config.AskDataPhone  := Not Config.AskDataPhone;
    8:  Config.AskBirthdate  := Not Config.AskBirthdate;
    9:  Config.AskGender     := Not Config.AskGender;
    10: Config.AskEmail      := Not Config.AskEmail;
    11: Config.AskUserNote   := Not Config.AskUserNote;
    12: Config.AskScreenSize := Not Config.AskScreenSize;
    13: Config.AskScreenCols := Not Config.AskScreenCols;
  End;
End;

Procedure NU_CycleChoice(Idx: Integer);
Begin
  Case Idx Of
    4:  Config.UserNameFormat := (Config.UserNameFormat + 1) Mod 4;
    5:  Config.UserDateType   := (Config.UserDateType + 1) Mod 4;
    6:  Config.UserEditorType := (Config.UserEditorType + 1) Mod 3;
    7:  Config.UserHotKeys    := (Config.UserHotKeys + 1) Mod 3;
    8:  Config.UserFullChat   := (Config.UserFullChat + 1) Mod 3;
    9:  Config.UserFileList   := (Config.UserFileList + 1) Mod 3;
    10: Config.UserReadType   := (Config.UserReadType + 1) Mod 3;
    11: Config.UserMailIndex  := (Config.UserMailIndex + 1) Mod 3;
    12: Config.UserQuoteWin   := (Config.UserQuoteWin + 1) Mod 3;
    13: Config.UserProtocol   := (Config.UserProtocol + 1) Mod 3;
  End;
End;

Procedure RunNewUserSettings;
Var
  CurField  : Integer;
  NURunning : Boolean;
  K         : TKeyEvent;
  Code      : Word;
  S         : String;
  N         : LongInt;
  MaxField  : Integer;
Begin
  CurField := 0;
  NURunning := True;
  MaxField := NU_FIELDS + NU_ASK - 1;
  DrawNewUserPage(CurField, 0);

  While NURunning Do Begin
    K := GetKeyEvent;
    K := TranslateKeyEvent(K);
    Code := GetKeyEventCode(K);

    Case Code Of
      $4800: Begin
        If CurField > 0 Then Dec(CurField);
        DrawNewUserPage(CurField, 0);
      End;
      $5000: Begin
        If CurField < MaxField Then Inc(CurField);
        DrawNewUserPage(CurField, 0);
      End;
      $000D, $0020: Begin { Enter or Space }
        If CurField < NU_FIELDS Then Begin
          Case CurField Of
            0: Config.AllowNewUsers := Not Config.AllowNewUsers;
            1: Begin N := Config.NewUserSec; If EditNumField(N, 5, 0, 32767, 150, 58 + 1*16, 300) Then Config.NewUserSec := N; End;
            2: Begin S := Config.NewUserPW;  If EditTextField(S, 15, 150, 58 + 2*16, 300) Then Config.NewUserPW := S; End;
            3: Config.NewUserEMail := Not Config.NewUserEMail;
            4..13: NU_CycleChoice(CurField);
          End;
        End Else Begin
          NU_ToggleAsk(CurField - NU_FIELDS);
        End;
        DrawNewUserPage(CurField, 0);
      End;
      $001B: NURunning := False;
    End;
  End;
End;

{ ---- Console / Status Bar page ---- }

Const
  CO_FIELDS = 12;  { 8 macros + UseStatusBar + 3 colors }
  CO_LBL: Array[0..CO_FIELDS-1] of String[16] =
    ('F1 Macro:', 'F2 Macro:', 'F3 Macro:', 'F4 Macro:',
     'F5 Macro:', 'F6 Macro:', 'F7 Macro:', 'F8 Macro:',
     'Status Bar:', 'Color 1:', 'Color 2:', 'Color 3:');

Function CO_GetVal(Idx: Integer): String;
Begin
  Case Idx Of
    0..7: Result := Config.SysopMacro[Idx + 1];
    8:    If Config.UseStatusBar Then Result := '[ON]' Else Result := '[OFF]';
    9:    Result := IntToStr(Config.StatusColor1);
    10:   Result := IntToStr(Config.StatusColor2);
    11:   Result := IntToStr(Config.StatusColor3);
  Else    Result := '';
  End;
End;

Procedure DrawConsolePage(CurField: Integer);
Var I, Y, FW: Integer;
    ColorVal: Byte;
Begin
  DrawBackground;
  DrawTitleBar;
  DrawRaisedBox(5, 35, RIP_WIDTH - 6, RIP_HEIGHT - 20, CLR_MENU_BG, CLR_BRIGHT, CLR_SHADOW);
  OutTextXY(12, 40, 'Console / Status Bar');
  DrawSeparatorH(10, RIP_WIDTH - 10, 52, CLR_BRIGHT, CLR_SHADOW);

  For I := 0 to CO_FIELDS - 1 Do Begin
    Y := 60 + I * 20;
    If I <= 7 Then FW := 580 Else FW := 250;

    If I = CurField Then SetColor(15) Else SetColor(CLR_MENU_FG);
    OutTextXY(12, Y, CO_LBL[I]);

    If I = CurField Then
      DrawSunkenBox(130, Y-2, FW, Y+12, 4, CLR_SHADOW, CLR_BRIGHT)
    Else
      DrawSunkenBox(130, Y-2, FW, Y+12, 0, CLR_SHADOW, CLR_BRIGHT);

    If I = CurField Then SetColor(15) Else SetColor(CLR_MENU_FG);
    OutTextXY(134, Y, CO_GetVal(I));

    { Color preview swatch }
    If (I >= 9) And (I <= 11) Then Begin
      Case I Of
        9:  ColorVal := Config.StatusColor1;
        10: ColorVal := Config.StatusColor2;
        11: ColorVal := Config.StatusColor3;
      Else ColorVal := 0;
      End;
      Bar(FW + 10, Y - 1, FW + 40, Y + 11);
      SetFillStyle(SolidFill, ColorVal And $0F);
      Bar(FW + 10, Y - 1, FW + 40, Y + 11);
    End;
  End;

  SetColor(CLR_MENU_FG);
  DrawStatusBar('Up/Dn=Move  ENTER=Edit  SPACE=Toggle  ESC=Back');
  FlushToScreen;
End;

Procedure RunConsoleSettings;
Var
  CurField  : Integer;
  CORunning : Boolean;
  K         : TKeyEvent;
  Code      : Word;
  S         : String;
  N         : LongInt;
Begin
  CurField := 0;
  CORunning := True;
  DrawConsolePage(CurField);

  While CORunning Do Begin
    K := GetKeyEvent;
    K := TranslateKeyEvent(K);
    Code := GetKeyEventCode(K);

    Case Code Of
      $4800: Begin
        If CurField > 0 Then Dec(CurField);
        DrawConsolePage(CurField);
      End;
      $5000: Begin
        If CurField < CO_FIELDS - 1 Then Inc(CurField);
        DrawConsolePage(CurField);
      End;
      $000D, $0020: Begin
        Case CurField Of
          0..7: Begin
            S := Config.SysopMacro[CurField + 1];
            If EditTextField(S, 60, 130, 60 + CurField * 20, 580) Then
              Config.SysopMacro[CurField + 1] := S;
          End;
          8: Config.UseStatusBar := Not Config.UseStatusBar;
          9: Begin
            N := Config.StatusColor1;
            If EditNumField(N, 2, 0, 255, 130, 60 + 9 * 20, 250) Then
              Config.StatusColor1 := N;
          End;
          10: Begin
            N := Config.StatusColor2;
            If EditNumField(N, 2, 0, 255, 130, 60 + 10 * 20, 250) Then
              Config.StatusColor2 := N;
          End;
          11: Begin
            N := Config.StatusColor3;
            If EditNumField(N, 2, 0, 255, 130, 60 + 11 * 20, 250) Then
              Config.StatusColor3 := N;
          End;
        End;
        DrawConsolePage(CurField);
      End;
      $001B: CORunning := False;
    End;
  End;
End;

{ ---- Main ---- }

Begin
  { Init graphics — 640x350 EGA }
  Gd := EGA;
  Gm := EGAHi;
  InitGraph(Gd, Gm, '');
  If GraphResult <> grOk Then Begin
    WriteLn('Graphics init failed: ', GraphErrorMsg(GraphResult));
    Halt(1);
  End;

  InitCanvas;
  EnterGraphics;
  InitKeyboard;

  { Load config }
  ConfigPath := 'mystic.dat';
  If ParamCount > 0 Then ConfigPath := ParamStr(1);
  HasConfig := LoadConfig(ConfigPath);
  If Not HasConfig Then FillChar(Config, SizeOf(Config), 0);

  { Main loop }
  Selection := 0;
  Running := True;
  DrawMainMenu;

  While Running Do Begin
    K := GetKeyEvent;
    K := TranslateKeyEvent(K);

    Case GetKeyEventCode(K) Of
      $4800: Begin { Up }
        If Selection > 0 Then Dec(Selection);
        DrawMainMenu;
      End;
      $5000: Begin { Down }
        If Selection < 4 Then Inc(Selection);
        DrawMainMenu;
      End;
      $000D: Begin { Enter }
        Case Selection Of
          0: Begin RunGeneralSettings; DrawMainMenu; End;
          1: Begin RunSystemPaths; DrawMainMenu; End;
          2: Begin RunNewUserSettings; DrawMainMenu; End;
          3: Begin RunConsoleSettings; DrawMainMenu; End;
          4: Running := False;
        End;
      End;
      $0071, $0051: Running := False; { Q/q }
      $001B: Running := False;        { ESC }
    End;
  End;

  { Save and exit }
  If HasConfig Then SaveConfig(ConfigPath);
  DoneKeyboard;
  CloseGraph;
  WriteLn('MConfig — saved to ', ConfigPath);
End.
