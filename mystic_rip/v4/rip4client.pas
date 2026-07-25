{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// rip3client.pas — Client-side demo
// Demonstrates: form input handling, focus cycling, checkbox toggling,
// dropdown selection, field rendering, and pixel buffer export.
//
// Compile: ppcx64 -Mdelphi -Fu<path-to-mystic_ripapi3>
//          -Fu<path>/img -Fu<path>/wav -Fu<path>/pasjpeg rip3client.pas
//
// This simulates what runs on the terminal/viewer. The client:
//   1. Receives form definitions from server (FormAddField)
//   2. Handles user input (keyboard, mouse clicks)
//   3. Updates field values (FormSetValue)
//   4. Manages focus (Tab cycling)
//   5. Re-renders after each input event
//
// In a real BBS, the host application bridges server and client:
//   - Server defines fields via RIP commands
//   - Client processes keystrokes and mouse events
//   - Host calls FormSetValue + FormRender after each event
//
Program rip3client;

Uses rip4api;

Var
  RIP        : TRIPEngine;
  FocusIdx   : Integer;
  FieldCount : Integer;
  TestF      : File;

Procedure SetupForm;
// Server would normally send these via RIP commands.
// We define them directly to simulate.
Var Idx : Integer;
Begin
  RIP.FormClear;
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.OutTextXY(10, 5, 'Login Form (Client Demo)');

  // Username field
  Idx := RIP.FormAddField(RIP_FIELD_TEXT, 'Username', 10, 35, 200, 20);
  RIP.FormSetRequired(Idx, True);
  RIP.FormBindVar(Idx, 'LOGIN_USER');

  // Password field
  Idx := RIP.FormAddField(RIP_FIELD_TEXT, 'Password', 10, 65, 200, 20);
  RIP.FormSetRequired(Idx, True);
  RIP.FormBindVar(Idx, 'LOGIN_PASS');

  // Terminal type dropdown
  Idx := RIP.FormAddField(RIP_FIELD_DROPDOWN, 'Terminal', 10, 95, 200, 20);
  RIP.FormSetOptions(Idx, 'ANSI|RIPscrip|VT100|ASCII');
  RIP.FormSetValue(Idx, 'ANSI');
  RIP.FormBindVar(Idx, 'LOGIN_TERM');

  // Remember me checkbox
  Idx := RIP.FormAddField(RIP_FIELD_CHECKBOX, 'Remember me', 10, 125, 200, 20);
  RIP.FormSetValue(Idx, '0');
  RIP.FormBindVar(Idx, 'LOGIN_REMEMBER');

  // Status label
  Idx := RIP.FormAddField(RIP_FIELD_LABEL, 'Status', 10, 160, 300, 16);
  RIP.FormSetValue(Idx, 'Enter your credentials');

  FieldCount := 5;
  FocusIdx := 0;
End;

Procedure SimulateKeypress (FieldIdx: Integer; NewValue: String);
// Simulate a client keypress updating a field value.
// In a real client, this would come from the keyboard handler.
Begin
  WriteLn('  [KEY] Field ', FieldIdx, ' ← "', NewValue, '"');
  RIP.FormSetValue(FieldIdx, NewValue);
End;

Procedure SimulateCheckboxClick (FieldIdx: Integer);
// Simulate clicking a checkbox — toggle between "0" and "1".
Var Val : String;
Begin
  Val := RIP.FormGetValue(FieldIdx);
  If Val = '1' Then
    RIP.FormSetValue(FieldIdx, '0')
  Else
    RIP.FormSetValue(FieldIdx, '1');
  WriteLn('  [CLICK] Checkbox toggled → ', RIP.FormGetValue(FieldIdx));
End;

Procedure SimulateDropdownSelect (FieldIdx: Integer; Selection: String);
// Simulate selecting from a dropdown menu.
Begin
  WriteLn('  [SELECT] Dropdown → "', Selection, '"');
  RIP.FormSetValue(FieldIdx, Selection);
End;

Procedure RenderAndExport (FileName: String; Label_: String);
Begin
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.OutTextXY(10, 5, 'Login Form (Client Demo)');
  RIP.FormRender;
  If RIP.SaveBMP(FileName) Then
    WriteLn('  Saved: ', FileName, ' (', Label_, ')')
  Else
    WriteLn('  ERROR: SaveBMP failed');
End;

Begin
  WriteLn;
  WriteLn('RIPscrip v3.0 — Client-Side Demo');
  WriteLn('================================');
  WriteLn;

  RIP := TRIPEngine.Create;

  // ---- Step 1: Setup (server defines form) ----
  WriteLn('=== CLIENT: Form Setup ===');
  SetupForm;
  RenderAndExport('/tmp/rip3_client_step1.bmp', 'empty form');
  WriteLn;

  // ---- Step 2: User types username ----
  WriteLn('=== CLIENT: User Types Username ===');
  SimulateKeypress(0, 'sysop');
  RenderAndExport('/tmp/rip3_client_step2.bmp', 'username entered');
  WriteLn;

  // ---- Step 3: User types password ----
  WriteLn('=== CLIENT: User Types Password ===');
  SimulateKeypress(1, '********');
  RenderAndExport('/tmp/rip3_client_step3.bmp', 'password entered');
  WriteLn;

  // ---- Step 4: User selects terminal type ----
  WriteLn('=== CLIENT: User Selects Terminal ===');
  SimulateDropdownSelect(2, 'RIPscrip');
  RenderAndExport('/tmp/rip3_client_step4.bmp', 'terminal selected');
  WriteLn;

  // ---- Step 5: User clicks checkbox ----
  WriteLn('=== CLIENT: User Clicks Checkbox ===');
  SimulateCheckboxClick(3);
  RenderAndExport('/tmp/rip3_client_step5.bmp', 'checkbox checked');
  WriteLn;

  // ---- Step 6: Validate before submit ----
  WriteLn('=== CLIENT: Validate ===');
  If RIP.FormValidate Then Begin
    WriteLn('  Validation: PASSED');
    RIP.FormSetValue(4, 'Login accepted!');
  End Else Begin
    WriteLn('  Validation: FAILED');
    RIP.FormSetValue(4, 'Missing required fields');
  End;
  RenderAndExport('/tmp/rip3_client_step6.bmp', 'validated');
  WriteLn;

  // ---- Step 7: Sync to server variables ----
  WriteLn('=== CLIENT: Sync to Server ===');
  RIP.FormSyncToVars;
  WriteLn('  $LOGIN_USER$     = ', RIP.GetVar('LOGIN_USER'));
  WriteLn('  $LOGIN_PASS$     = ', RIP.GetVar('LOGIN_PASS'));
  WriteLn('  $LOGIN_TERM$     = ', RIP.GetVar('LOGIN_TERM'));
  WriteLn('  $LOGIN_REMEMBER$ = ', RIP.GetVar('LOGIN_REMEMBER'));
  WriteLn;

  // ---- Step 8: Server pushes back ----
  WriteLn('=== CLIENT: Server Response ===');
  RIP.SetVar('LOGIN_USER', 'SysOp');  // server corrects capitalization
  RIP.FormSyncFromVars;
  WriteLn('  Server corrected username: ', RIP.FormGetValue(0));
  RIP.FormSetValue(4, 'Welcome back, SysOp!');
  RenderAndExport('/tmp/rip3_client_step7.bmp', 'server response');
  WriteLn;

  // ---- Cleanup ----
  RIP.FormClear;
  RIP.KillAllVars;

  // ---- Step 9: Audio file tests ----
  WriteLn('=== CLIENT: Audio File Tests ===');
  WriteLn('  Testing audio files in testdata/ (server-side reference):');

  Assign(TestF, 'testdata/test_beep.wav');
  {$I-} System.Reset(TestF, 1); {$I+}
  If IOResult = 0 Then Begin
    WriteLn('  test_beep.wav: found (', FileSize(TestF), ' bytes, 440Hz beep)');
    Close(TestF);
  End Else
    WriteLn('  test_beep.wav: not found (run from mystic_ripapi3/ dir)');

  Assign(TestF, 'testdata/test_silence.wav');
  {$I-} System.Reset(TestF, 1); {$I+}
  If IOResult = 0 Then Begin
    WriteLn('  test_silence.wav: found (', FileSize(TestF), ' bytes)');
    Close(TestF);
  End Else
    WriteLn('  test_silence.wav: not found');

  Assign(TestF, 'testdata/test_voice.voc');
  {$I-} System.Reset(TestF, 1); {$I+}
  If IOResult = 0 Then Begin
    WriteLn('  test_voice.voc: found (', FileSize(TestF), ' bytes)');
    Close(TestF);
  End Else
    WriteLn('  test_voice.voc: not found');

  Assign(TestF, 'testdata/test_sun.au');
  {$I-} System.Reset(TestF, 1); {$I+}
  If IOResult = 0 Then Begin
    WriteLn('  test_sun.au: found (', FileSize(TestF), ' bytes)');
    Close(TestF);
  End Else
    WriteLn('  test_sun.au: not found');

  WriteLn;
  RIP.Free;

  WriteLn('Client demo complete.');
  WriteLn('BMP files saved to /tmp/rip3_client_step*.bmp');
  WriteLn;
End.
