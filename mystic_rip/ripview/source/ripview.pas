{$MODE DELPHI}
{$H-}
Program RIPView;
{
  RIPView v1.0.0 — RIPscrip File Viewer

  Single source, two compile targets:
    fpc -Mdelphi ripview.pas                    → CLI mode
    fpc -Mdelphi -dFREEVISION ripview.pas       → Free Vision TUI

  Modular units:
    ripengine.pas   — Canvas, palette, pixels (shared)
    ripdraw.pas     — Drawing primitives (shared)
    riptext.pas     — VGA 8x16 text rendering (shared)
    ripbmp.pas      — BMP file output (shared)
    v1/rip1parse.pas — v1.54 mega decoder + command parser
    v1/rip1exec.pas  — v1.54 42-command dispatcher

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
  Mystic BBS IRC Fork — Ecstasy BBS FTN 1:152/158
}

Uses
  SysUtils,
  RIPEngine, RIPDraw, RIPText, RIPBMP, RIP1Parse, RIP1Exec
  {$IFDEF FREEVISION}
  , App, Objects, Views, Menus, Drivers, Dialogs, StdDlg, MsgBox
  {$ENDIF}
  ;

{$IFNDEF FREEVISION}
{ ======================================================================
  File picker — list .rip files in a directory
  ====================================================================== }

Procedure ListRipFiles(const Dir: String);
Var
  SR  : TSearchRec;
  Cnt : Integer;
Begin
  Cnt := 0;
  WriteLn('RIP files in: ', Dir);
  WriteLn;
  If FindFirst(Dir + '*.rip', faAnyFile, SR) = 0 Then Begin
    Repeat
      Inc(Cnt);
      WriteLn('  ', Cnt:3, '. ', SR.Name, '  (', SR.Size, ' bytes)');
    Until FindNext(SR) <> 0;
    FindClose(SR);
  End;
  If Cnt = 0 Then
    WriteLn('  (no .rip files found)');
  WriteLn;
  WriteLn('  ', Cnt, ' file(s)');
End;

{ Pick a .rip file interactively from a directory }
Function PickRipFile(const Dir: String): String;
Var
  SR    : TSearchRec;
  Files : Array[1..999] Of String;
  Cnt   : Integer;
  Choice: Integer;
  S     : String;
Begin
  Result := '';
  Cnt := 0;
  If FindFirst(Dir + '*.rip', faAnyFile, SR) = 0 Then Begin
    Repeat
      Inc(Cnt);
      If Cnt <= 999 Then
        Files[Cnt] := SR.Name;
      WriteLn('  ', Cnt:3, '. ', SR.Name, '  (', SR.Size, ' bytes)');
    Until FindNext(SR) <> 0;
    FindClose(SR);
  End;
  
  If Cnt = 0 Then Begin
    WriteLn('  No .rip files found in ', Dir);
    Exit;
  End;
  
  WriteLn;
  Write('Select file (1-', Cnt, '): ');
  ReadLn(S);
  Val(S, Choice, Cnt);
  If (Choice >= 1) And (Choice <= Cnt) Then
    Result := Dir + Files[Choice];
End;

{ ======================================================================
  Parse command-line flags
  ====================================================================== }

Procedure ParseFlags;
Var
  I : Integer;
  S : String;
  V : Integer;
  Code: Integer;
Begin
  For I := 1 to ParamCount Do Begin
    S := ParamStr(I);
    If (S = '-d') Or (S = '--debug') Then
      DebugMode := True
    Else If (S = '-b') Or (Copy(S, 1, 7) = '--baud=') Then Begin
      If Copy(S, 1, 7) = '--baud=' Then
        S := Copy(S, 8, Length(S) - 7)
      Else If I < ParamCount Then Begin
        S := ParamStr(I + 1);
      End Else
        S := '0';
      Val(S, V, Code);
      If (Code = 0) And (V >= 0) Then Begin
        BaudRate := V;
        If BaudRate > 0 Then
          { microseconds per byte: 1000000 / (baud/10) = 10000000/baud }
          BaudDelay := 10000000 Div BaudRate
        Else
          BaudDelay := 0;
      End;
    End
    Else If (S = '-l') Or (S = '--list') Then Begin
      { handled in main }
    End;
  End;
End;

{ Get first non-flag parameter }
Function GetFileParam: String;
Var I: Integer;
    S: String;
Begin
  Result := '';
  I := 1;
  While I <= ParamCount Do Begin
    S := ParamStr(I);
    If S[1] <> '-' Then Begin
      Result := S;
      Exit;
    End;
    { Skip -b value }
    If (S = '-b') Then Inc(I);
    Inc(I);
  End;
End;

{ Get second non-flag parameter (output file) }
Function GetOutParam: String;
Var I, Found: Integer;
    S: String;
Begin
  Result := '';
  Found := 0;
  I := 1;
  While I <= ParamCount Do Begin
    S := ParamStr(I);
    If S[1] <> '-' Then Begin
      Inc(Found);
      If Found = 2 Then Begin Result := S; Exit; End;
    End;
    If (S = '-b') Then Inc(I);
    Inc(I);
  End;
End;

{ ======================================================================
  Main — CLI mode (default)
  ====================================================================== }

Var
  F       : TextFile;
  Line    : String;
  FName   : String;
  OutFile : String;
  LCount  : Integer;
  CCount  : Integer;
  StartT  : TDateTime;
  Elapsed : LongInt;
  HasList : Boolean;
  Dir     : String;
Begin
  WriteLn('RIPView v', VERSION, ' — RIPscrip File Viewer [GPLv3]');
  WriteLn('verta1878, sysop/0, evga, kiddo, wrench');
  WriteLn;
  
  ParseFlags;
  
  If ParamCount < 1 Then Begin
    WriteLn('Usage: ripview [options] <file.rip|directory> [output.bmp]');
    WriteLn;
    WriteLn('Options:');
    WriteLn('  -d, --debug        Show commands as they execute');
    WriteLn('  -b, --baud=RATE    Baud rate emulation (300-115200, 0=max)');
    WriteLn('  -l, --list         List .rip files in directory');
    WriteLn;
    WriteLn('Baud rates: 300 1200 2400 4800 9600 14400 19200 28800 38400 57600 115200');
    WriteLn;
    WriteLn('Examples:');
    WriteLn('  ripview scene.rip                    Render to scene.bmp');
    WriteLn('  ripview -d scene.rip                 Render with debug output');
    WriteLn('  ripview -b 2400 scene.rip            Render at 2400 baud');
    WriteLn('  ripview -d -b 9600 scene.rip out.bmp Debug + baud + custom output');
    WriteLn('  ripview -l /path/to/rips/            List .rip files');
    WriteLn('  ripview /path/to/rips/               Pick from directory');
    Halt(1);
  End;
  
  { Check for --list flag }
  HasList := False;
  For LCount := 1 to ParamCount Do
    If (ParamStr(LCount) = '-l') Or (ParamStr(LCount) = '--list') Then
      HasList := True;
  
  FName := GetFileParam;
  
  { Directory mode: list or pick }
  If (FName <> '') And DirectoryExists(FName) Then Begin
    Dir := IncludeTrailingPathDelimiter(FName);
    If HasList Then Begin
      ListRipFiles(Dir);
      Halt(0);
    End;
    WriteLn('Select a .rip file:');
    WriteLn;
    FName := PickRipFile(Dir);
    If FName = '' Then Halt(1);
    WriteLn;
  End;
  
  If FName = '' Then Begin
    WriteLn('No file specified.');
    Halt(1);
  End;
  
  OutFile := GetOutParam;
  If OutFile = '' Then
    OutFile := ChangeFileExt(FName, '.bmp');
  
  If Not FileExists(FName) Then Begin
    WriteLn('File not found: ', FName);
    Halt(1);
  End;
  
  { Show settings }
  If BaudRate > 0 Then
    WriteLn('Baud: ', BaudRate, ' bps (', BaudRate Div 10, ' bytes/sec, ',
            BaudDelay, ' us/byte)');
  If DebugMode Then
    WriteLn('Debug: ON');
  
  InitCanvas;
  
  WriteLn('Loading: ', FName);
  
  Assign(F, FName);
  {$I-} Reset(F); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('Cannot open: ', FName);
    Halt(1);
  End;
  
  StartT := Now;
  LCount := 0;
  CCount := 0;
  
  While Not EOF(F) Do Begin
    ReadLn(F, Line);
    Inc(LCount);
    If Pos('!|', Line) > 0 Then Begin
      If DebugMode Then Begin
        Write('[', CCount + 1, '] ', Copy(Line, 1, 40));
        If Length(Line) > 40 Then Write('...');
        WriteLn;
      End;
      ExecuteRIP(Line);
      Inc(CCount);
    End;
  End;
  Close(F);
  
  Elapsed := Round((Now - StartT) * 86400000);
  
  WriteLn;
  WriteLn('Parsed: ', LCount, ' lines, ', CCount, ' RIP command lines');
  WriteLn('Canvas: ', RIP_WIDTH, 'x', RIP_HEIGHT, ' pixels');
  WriteLn('Time:   ', Elapsed, ' ms');
  If BaudRate > 0 Then
    WriteLn('Baud:   ', BaudRate, ' bps simulated');
  
  WriteBMP(OutFile);
  WriteLn('Output: ', OutFile);

{$ELSE}
{ ======================================================================
  Free Vision GUI — compile with -dFREEVISION
  TUI with menu bar, file dialog, canvas view, debug panel,
  baud rate selection, play/pause/stop controls.
  ====================================================================== }

Const
  cmFileOpen   = 1001;
  cmRender     = 1002;
  cmStop       = 1003;
  cmDebugTgl   = 1004;
  cmDebugClr   = 1005;
  cmBaud0      = 1100;  { Full speed }
  cmBaud300    = 1101;
  cmBaud1200   = 1102;
  cmBaud2400   = 1103;
  cmBaud9600   = 1104;
  cmBaud14400  = 1105;
  cmBaud19200  = 1106;
  cmBaud38400  = 1107;
  cmBaud57600  = 1108;
  cmBaud115200 = 1109;

Type
  { Debug log — scrolling list of command strings }
  PDebugList = ^TDebugList;
  TDebugList = Object(TListBox)
    Procedure HandleEvent(Var Event: TEvent); Virtual;
  End;

  { Status line showing file info }
  PRIPStatus = ^TRIPStatus;
  TRIPStatus = Object(TStaticText)
  End;

  { Main application }
  PRIPApp = ^TRIPApp;
  TRIPApp = Object(TApplication)
    RIPFile   : String;
    CmdCount  : Integer;
    DebugCol  : PStringCollection;
    DebugBox  : PDebugList;
    StatusTxt : PStaticText;
    Procedure InitMenuBar; Virtual;
    Procedure InitStatusLine; Virtual;
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    Procedure DoFileOpen;
    Procedure DoRender;
    Procedure DoSetBaud(Rate: LongInt);
    Procedure UpdateStatus;
  End;

Procedure TDebugList.HandleEvent(Var Event: TEvent);
Begin
  Inherited HandleEvent(Event);
End;

{ --- TRIPApp --- }

Procedure TRIPApp.InitMenuBar;
Var R: TRect;
Begin
  GetExtent(R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~F~ile', hcNoContext, NewMenu(
      NewItem('~O~pen...', 'F3', kbF3, cmFileOpen, hcNoContext,
      NewItem('~R~ender', 'F9', kbF9, cmRender, hcNoContext,
      NewItem('~S~top', 'Esc', kbEsc, cmStop, hcNoContext,
      NewLine(
      NewItem('~Q~uit', 'Alt-X', kbAltX, cmQuit, hcNoContext,
      nil)))))),
    NewSubMenu('~B~aud', hcNoContext, NewMenu(
      NewItem('Full Speed', '', kbNoKey, cmBaud0, hcNoContext,
      NewLine(
      NewItem('300 bps', '', kbNoKey, cmBaud300, hcNoContext,
      NewItem('1200 bps', '', kbNoKey, cmBaud1200, hcNoContext,
      NewItem('2400 bps', '', kbNoKey, cmBaud2400, hcNoContext,
      NewItem('9600 bps', '', kbNoKey, cmBaud9600, hcNoContext,
      NewItem('14400 bps', '', kbNoKey, cmBaud14400, hcNoContext,
      NewItem('19200 bps', '', kbNoKey, cmBaud19200, hcNoContext,
      NewItem('38400 bps', '', kbNoKey, cmBaud38400, hcNoContext,
      NewItem('57600 bps', '', kbNoKey, cmBaud57600, hcNoContext,
      NewItem('115200 bps', '', kbNoKey, cmBaud115200, hcNoContext,
      nil)))))))))))),
    NewSubMenu('~D~ebug', hcNoContext, NewMenu(
      NewItem('~T~oggle Debug', 'F5', kbF5, cmDebugTgl, hcNoContext,
      NewItem('~C~lear Log', '', kbNoKey, cmDebugClr, hcNoContext,
      nil))),
    nil)))
  )));
End;

Procedure TRIPApp.InitStatusLine;
Var R: TRect;
Begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  StatusTxt := New(PStaticText, Init(R, ' RIPView v' + VERSION +
    ' — No file loaded'));
  Insert(StatusTxt);
End;

Procedure TRIPApp.HandleEvent(Var Event: TEvent);
Begin
  Inherited HandleEvent(Event);
  If Event.What = evCommand Then Begin
    Case Event.Command Of
      cmFileOpen:  DoFileOpen;
      cmRender:    DoRender;
      cmDebugTgl:  Begin
        DebugMode := Not DebugMode;
        UpdateStatus;
      End;
      cmDebugClr:  Begin
        If DebugCol <> nil Then Begin
          DebugCol^.FreeAll;
          If DebugBox <> nil Then Begin
            DebugBox^.SetRange(0);
            DebugBox^.DrawView;
          End;
        End;
      End;
      cmBaud0:      DoSetBaud(0);
      cmBaud300:    DoSetBaud(300);
      cmBaud1200:   DoSetBaud(1200);
      cmBaud2400:   DoSetBaud(2400);
      cmBaud9600:   DoSetBaud(9600);
      cmBaud14400:  DoSetBaud(14400);
      cmBaud19200:  DoSetBaud(19200);
      cmBaud38400:  DoSetBaud(38400);
      cmBaud57600:  DoSetBaud(57600);
      cmBaud115200: DoSetBaud(115200);
    Else
      Exit;
    End;
    ClearEvent(Event);
  End;
End;

Procedure TRIPApp.DoFileOpen;
Var
  D: PFileDialog;
  F: String;
Begin
  D := New(PFileDialog, Init('*.rip', 'Open RIP File',
    '~N~ame', fdOpenButton, 100));
  If ExecuteDialog(D, @F) <> cmCancel Then Begin
    RIPFile := F;
    UpdateStatus;
  End;
End;

Procedure TRIPApp.DoRender;
Var
  F       : TextFile;
  Line    : String;
  LCount  : Integer;
  OutFile : String;
Begin
  If RIPFile = '' Then Begin
    MessageBox('No file loaded. Use File > Open first.',
      nil, mfError + mfOKButton);
    Exit;
  End;

  If Not FileExists(RIPFile) Then Begin
    MessageBox('File not found: ' + RIPFile,
      nil, mfError + mfOKButton);
    Exit;
  End;

  InitCanvas;
  CmdCount := 0;
  LCount := 0;

  Assign(F, RIPFile);
  {$I-} Reset(F); {$I+}
  If IOResult <> 0 Then Begin
    MessageBox('Cannot open: ' + RIPFile,
      nil, mfError + mfOKButton);
    Exit;
  End;

  While Not EOF(F) Do Begin
    ReadLn(F, Line);
    Inc(LCount);
    If Pos('!|', Line) > 0 Then Begin
      ExecuteRIP(Line);
      Inc(CmdCount);

      { Add to debug log }
      If DebugMode And (DebugCol <> nil) Then Begin
        If Length(Line) > 70 Then
          Line := Copy(Line, 1, 67) + '...';
        DebugCol^.Insert(NewStr('[' + IntToStr(CmdCount) + '] ' + Line));
        If DebugBox <> nil Then Begin
          DebugBox^.SetRange(DebugCol^.Count);
          DebugBox^.FocusItem(DebugCol^.Count - 1);
        End;
      End;
    End;
  End;
  Close(F);

  OutFile := ChangeFileExt(RIPFile, '.bmp');
  WriteBMP(OutFile);

  UpdateStatus;
  MessageBox('Rendered ' + IntToStr(CmdCount) + ' commands to ' + OutFile,
    nil, mfInformation + mfOKButton);
End;

Procedure TRIPApp.DoSetBaud(Rate: LongInt);
Begin
  BaudRate := Rate;
  If BaudRate > 0 Then
    BaudDelay := 10000000 Div BaudRate
  Else
    BaudDelay := 0;
  UpdateStatus;
End;

Procedure TRIPApp.UpdateStatus;
Var S: String;
Begin
  S := ' RIPView v' + VERSION;
  If RIPFile <> '' Then
    S := S + ' — ' + ExtractFileName(RIPFile);
  If BaudRate > 0 Then
    S := S + ' [' + IntToStr(BaudRate) + ' bps]'
  Else
    S := S + ' [MAX]';
  If DebugMode Then
    S := S + ' [DEBUG]';
  If CmdCount > 0 Then
    S := S + ' (' + IntToStr(CmdCount) + ' cmds)';

  If StatusTxt <> nil Then Begin
    StatusTxt^.Text := NewStr(S);
    StatusTxt^.DrawView;
  End;
End;

{ --- Main (Free Vision) --- }

Var
  MyApp: TRIPApp;
Begin
  MyApp.RIPFile := '';
  MyApp.CmdCount := 0;
  MyApp.DebugCol := New(PStringCollection, Init(100, 50));
  MyApp.DebugBox := nil;

  { Check for CLI file argument }
  If ParamCount >= 1 Then Begin
    If FileExists(ParamStr(1)) Then
      MyApp.RIPFile := ParamStr(1);
  End;

  MyApp.Init;
  MyApp.Run;
  MyApp.Done;

{$ENDIF}
End.
