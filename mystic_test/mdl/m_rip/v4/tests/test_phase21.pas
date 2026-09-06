{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// Phase 21: Text Variables v3.0 — tests
// Tests variable scoping (local/session/persist), $RESET$ commands,
// extended variables ($PIXFMT$, $CANVASW$, etc), KillLocalVars
//
Program test_phase21;

Uses rip4api;

Var
  RIP    : TRIPEngine;
  Pass   : Integer;
  Fail   : Integer;
  Total  : Integer;

Procedure Check (Name: String; Cond: Boolean);
Begin
  Inc(Total);
  If Cond Then Begin
    Inc(Pass);
    WriteLn('  PASS  ', Name);
  End Else Begin
    Inc(Fail);
    WriteLn('  FAIL  ', Name);
  End;
End;

// ==== Variable Scoping ====

Procedure TestDefineVarScoped;
Begin
  WriteLn;
  WriteLn('--- DefineVarScoped ---');
  RIP.KillAllVars;

  RIP.DefineVarScoped('LOCAL1', 'val1', RIP_SCOPE_LOCAL, False);
  Check('Local var defined', RIP.GetVar('LOCAL1') = 'val1');

  RIP.DefineVarScoped('SESSION1', 'val2', RIP_SCOPE_SESSION, False);
  Check('Session var defined', RIP.GetVar('SESSION1') = 'val2');

  RIP.DefineVarScoped('PERSIST1', 'val3', RIP_SCOPE_PERSIST, False);
  Check('Persist var defined', RIP.GetVar('PERSIST1') = 'val3');

  RIP.KillAllVars;
End;

Procedure TestKillLocalVars;
Begin
  WriteLn;
  WriteLn('--- KillLocalVars ---');
  RIP.KillAllVars;

  RIP.DefineVarScoped('LOCAL_A', 'aaa', RIP_SCOPE_LOCAL, False);
  RIP.DefineVarScoped('LOCAL_B', 'bbb', RIP_SCOPE_LOCAL, False);
  RIP.DefineVarScoped('SESSION_A', 'ccc', RIP_SCOPE_SESSION, False);
  RIP.DefineVarScoped('PERSIST_A', 'ddd', RIP_SCOPE_PERSIST, False);

  RIP.KillLocalVars;

  Check('Local A cleared', RIP.GetVar('LOCAL_A') = '');
  Check('Local B cleared', RIP.GetVar('LOCAL_B') = '');
  Check('Session A survives', RIP.GetVar('SESSION_A') = 'ccc');
  Check('Persist A survives', RIP.GetVar('PERSIST_A') = 'ddd');

  RIP.KillAllVars;
End;

Procedure TestKillSessionVars;
Begin
  WriteLn;
  WriteLn('--- KillSessionVars ---');
  RIP.KillAllVars;

  RIP.DefineVarScoped('LOCAL_X', '111', RIP_SCOPE_LOCAL, False);
  RIP.DefineVarScoped('SESSION_X', '222', RIP_SCOPE_SESSION, False);
  RIP.DefineVarScoped('PERSIST_X', '333', RIP_SCOPE_PERSIST, False);

  RIP.KillSessionVars;

  Check('Local X survives', RIP.GetVar('LOCAL_X') = '111');
  Check('Session X cleared', RIP.GetVar('SESSION_X') = '');
  Check('Persist X survives', RIP.GetVar('PERSIST_X') = '333');

  RIP.KillAllVars;
End;

Procedure TestClearScreenKillsLocal;
Begin
  WriteLn;
  WriteLn('--- ClearScreen Kills Local ---');
  RIP.KillAllVars;

  RIP.DefineVarScoped('SCENE_TEMP', 'temp', RIP_SCOPE_LOCAL, False);
  RIP.DefineVarScoped('USER_NAME', 'sysop', RIP_SCOPE_SESSION, False);

  Check('Before clear: SCENE_TEMP exists', RIP.GetVar('SCENE_TEMP') = 'temp');
  RIP.ClearScreen;
  Check('After clear: SCENE_TEMP gone', RIP.GetVar('SCENE_TEMP') = '');
  Check('After clear: USER_NAME survives', RIP.GetVar('USER_NAME') = 'sysop');

  RIP.KillAllVars;
End;

Procedure TestLegacyDefineVar;
Begin
  WriteLn;
  WriteLn('--- Legacy DefineVar ---');
  RIP.KillAllVars;

  // Persist=False → SESSION scope
  RIP.DefineVar('TEST1', 'hello', False, False);
  RIP.KillLocalVars;
  Check('Legacy non-persist: survives KillLocal', RIP.GetVar('TEST1') = 'hello');

  // Persist=True → PERSIST scope
  RIP.DefineVar('TEST2', 'world', True, False);
  RIP.KillSessionVars;
  Check('Legacy persist: survives KillSession', RIP.GetVar('TEST2') = 'world');

  RIP.KillAllVars;
End;

// ==== Reset Commands ====

Procedure TestResetPal;
Var S : String;
Begin
  WriteLn;
  WriteLn('--- $RESET(PAL)$ ---');

  RIP.SetPalette(0, 63);  // modify palette
  S := RIP.ExpandVars('$RESET(PAL)$');
  Check('$RESET(PAL)$ returns empty', S = '');
  Check('$RESET(PAL)$ no crash', True);
End;

Procedure TestResetAll;
Var S : String;
Begin
  WriteLn;
  WriteLn('--- $RESET(ALL)$ ---');

  RIP.SetColor(14);
  S := RIP.ExpandVars('$RESET(ALL)$');
  Check('$RESET(ALL)$ returns empty', S = '');
  Check('$RESET(ALL)$ resets color', RIP.GetColor = 15);
End;

// ==== Extended Variables ====

Procedure TestPixFmt;
Var S : String;
Begin
  WriteLn;
  WriteLn('--- $PIXFMT$ ---');

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  S := RIP.ExpandVars('$PIXFMT$');
  Check('INDEXED8', S = 'INDEXED8');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  S := RIP.ExpandVars('$PIXFMT$');
  Check('RGB24', S = 'RGB24');

  RIP.SetPixelFormat(RIP_PIXFMT_RGB32);
  S := RIP.ExpandVars('$PIXFMT$');
  Check('RGB32', S = 'RGB32');

  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
End;

Procedure TestCanvasVars;
Var S : String;
Begin
  WriteLn;
  WriteLn('--- $CANVASW$ / $CANVASH$ ---');

  S := RIP.ExpandVars('$CANVASW$');
  Check('CANVASW = 640', S = '640');

  S := RIP.ExpandVars('$CANVASH$');
  Check('CANVASH = 350', S = '350');

  RIP.SetResolution(800, 600);
  S := RIP.ExpandVars('$CANVASW$');
  Check('After 800x600: CANVASW = 800', S = '800');
  RIP.SetResolution(640, 350);
End;

Procedure TestRFFFontVar;
Var S : String;
Begin
  WriteLn;
  WriteLn('--- $RFFFONT$ ---');

  S := RIP.ExpandVars('$RFFFONT$');
  Check('No RFF font: empty', S = '');
End;

Procedure TestMAFResVar;
Var S : String;
Begin
  WriteLn;
  WriteLn('--- $MAFRES$ ---');

  S := RIP.ExpandVars('$MAFRES$');
  Check('No MAF loaded: empty', S = '');
End;

// ==== Edge Cases ====

Procedure TestMixedExpansion;
Var S : String;
Begin
  WriteLn;
  WriteLn('--- Mixed Expansion ---');
  RIP.KillAllVars;
  RIP.DefineVar('NAME', 'Mystic', False, False);

  S := RIP.ExpandVars('Hello $NAME$, canvas=$CANVASW$x$CANVASH$, fmt=$PIXFMT$');
  Check('Mixed expansion', S = 'Hello Mystic, canvas=640x350, fmt=INDEXED8');

  RIP.KillAllVars;
End;

Procedure TestScopeOverwrite;
Begin
  WriteLn;
  WriteLn('--- Scope Overwrite ---');
  RIP.KillAllVars;

  RIP.DefineVarScoped('X', 'local', RIP_SCOPE_LOCAL, False);
  Check('X = local', RIP.GetVar('X') = 'local');

  // Overwrite with session scope
  RIP.DefineVarScoped('X', 'session', RIP_SCOPE_SESSION, False);
  Check('X = session (overwritten)', RIP.GetVar('X') = 'session');

  // KillLocal should NOT clear it now (it's session scope)
  RIP.KillLocalVars;
  Check('X survives KillLocal (now session)', RIP.GetVar('X') = 'session');

  RIP.KillAllVars;
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 21: Text Variables v3.0 — TESTS ===');

  RIP := TRIPEngine.Create;

  TestDefineVarScoped;
  TestKillLocalVars;
  TestKillSessionVars;
  TestClearScreenKillsLocal;
  TestLegacyDefineVar;
  TestResetPal;
  TestResetAll;
  TestPixFmt;
  TestCanvasVars;
  TestRFFFontVar;
  TestMAFResVar;
  TestMixedExpansion;
  TestScopeOverwrite;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
