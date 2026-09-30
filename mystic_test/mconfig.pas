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

Procedure DrawGeneralSettings;
Var Y: Integer;
Begin
  DrawBackground;
  DrawTitleBar;

  DrawRaisedBox(5, 35, RIP_WIDTH - 6, RIP_HEIGHT - 20, CLR_MENU_BG, CLR_BRIGHT, CLR_SHADOW);
  OutTextXY(12, 40, 'General Settings');
  DrawSeparatorH(10, RIP_WIDTH - 10, 52, CLR_BRIGHT, CLR_SHADOW);

  Y := 60;
  OutTextXY(12, Y, 'BBS Name:');    DrawSunkenBox(120, Y-2, 500, Y+12, 0, CLR_SHADOW, CLR_BRIGHT); OutTextXY(124, Y, Config.BBSName);
  Y := Y + 22;
  OutTextXY(12, Y, 'Sysop Name:');  DrawSunkenBox(120, Y-2, 500, Y+12, 0, CLR_SHADOW, CLR_BRIGHT); OutTextXY(124, Y, Config.SysopName);
  Y := Y + 22;
  OutTextXY(12, Y, 'Feedback To:'); DrawSunkenBox(120, Y-2, 500, Y+12, 0, CLR_SHADOW, CLR_BRIGHT); OutTextXY(124, Y, Config.FeedbackTo);
  Y := Y + 22;
  OutTextXY(12, Y, 'Inactivity:');  DrawSunkenBox(120, Y-2, 200, Y+12, 0, CLR_SHADOW, CLR_BRIGHT); OutTextXY(124, Y, IntToStr(Config.Inactivity) + 's');
  Y := Y + 22;
  OutTextXY(12, Y, 'Start Menu:');  DrawSunkenBox(120, Y-2, 300, Y+12, 0, CLR_SHADOW, CLR_BRIGHT); OutTextXY(124, Y, Config.DefStartMenu);
  Y := Y + 22;
  OutTextXY(12, Y, 'Theme File:');  DrawSunkenBox(120, Y-2, 300, Y+12, 0, CLR_SHADOW, CLR_BRIGHT); OutTextXY(124, Y, Config.DefThemeFile);
  Y := Y + 30;
  DrawCheckbox(12, Y, 12, Config.ChatLogging, CLR_MENU_FG, CLR_MENU_BG);
  OutTextXY(30, Y + 2, 'Log sysop chat');
  DrawCheckbox(200, Y, 12, Config.ChatFeedback, CLR_MENU_FG, CLR_MENU_BG);
  OutTextXY(218, Y + 2, 'Feedback on missed page');

  DrawStatusBar('General Settings — ESC to go back');
  FlushToScreen;
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
          0: Begin DrawGeneralSettings;
             Repeat K := GetKeyEvent; K := TranslateKeyEvent(K);
             Until GetKeyEventCode(K) = $001B;
             DrawMainMenu; End;
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
