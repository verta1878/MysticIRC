{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// rip3server.pas — Server-side demo
// Demonstrates: table creation, rendering, scrolling, form definitions,
// variable binding, validation, and BMP export of rendered output.
//
// Compile: ppcx64 -Mdelphi -Fu<path-to-mystic_ripapi3>
//          -Fu<path>/img -Fu<path>/wav -Fu<path>/pasjpeg rip3server.pas
//
// This is what runs on the BBS host. The server:
//   1. Creates tables with data
//   2. Defines form fields with constraints
//   3. Binds form fields to text variables
//   4. Renders everything to the pixel buffer
//   5. Exports to BMP for verification
//
Program rip3server;

Uses rip3api;

Var
  RIP : TRIPEngine;
  Idx : Integer;

Procedure DemoTable;
Begin
  WriteLn('=== SERVER: Table Demo ===');
  WriteLn;

  // Create a user list table
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.OutTextXY(10, 5, 'BBS User Directory');

  RIP.TableCreate(10, 25, 4);
  RIP.TableAddCol('Handle',   120, RIP_COL_LEFT);
  RIP.TableAddCol('Location', 150, RIP_COL_LEFT);
  RIP.TableAddCol('Calls',     60, RIP_COL_RIGHT);
  RIP.TableAddCol('Level',     50, RIP_COL_CENTER);

  // Add user data
  RIP.TableAddRow;
  RIP.TableSetCell(0, 0, 'SysOp',      15);
  RIP.TableSetCell(0, 1, 'Local',      7);
  RIP.TableSetCell(0, 2, '1024',       14);
  RIP.TableSetCell(0, 3, '255',        12);

  RIP.TableAddRow;
  RIP.TableSetCell(1, 0, 'CoolDude',   15);
  RIP.TableSetCell(1, 1, 'New York',   7);
  RIP.TableSetCell(1, 2, '512',        14);
  RIP.TableSetCell(1, 3, '100',        10);

  RIP.TableAddRow;
  RIP.TableSetCell(2, 0, 'H4ck3r',     15);
  RIP.TableSetCell(2, 1, 'Unknown',    7);
  RIP.TableSetCell(2, 2, '42',         14);
  RIP.TableSetCell(2, 3, '10',         11);

  RIP.TableAddRow;
  RIP.TableSetCell(3, 0, 'ArtScene',   15);
  RIP.TableSetCell(3, 1, 'Portland',   7);
  RIP.TableSetCell(3, 2, '256',        14);
  RIP.TableSetCell(3, 3, '50',         13);

  RIP.TableAddRow;
  RIP.TableSetCell(4, 0, 'NewUser',    15);
  RIP.TableSetCell(4, 1, 'Nowhere',    7);
  RIP.TableSetCell(4, 2, '1',          14);
  RIP.TableSetCell(4, 3, '5',          9);

  WriteLn('  Created table: ', RIP.TableGetCols, ' columns, ',
          RIP.TableGetRows, ' rows');

  // Render table
  RIP.TableRender;
  WriteLn('  Table rendered to pixel buffer');

  // Export
  If RIP.SaveBMP('/tmp/rip3_server_table.bmp') Then
    WriteLn('  Saved: /tmp/rip3_server_table.bmp')
  Else
    WriteLn('  ERROR: SaveBMP failed');

  // Demo scrolling
  WriteLn;
  WriteLn('  Scrolling demo:');
  RIP.ClearScreen;
  RIP.TableSetVisRows(3);  // show only 3 rows at a time
  RIP.TableRender;
  WriteLn('    Visible rows: 3 (scroll position 0)');

  RIP.TableScroll(2);
  RIP.ClearScreen;
  RIP.TableRender;
  WriteLn('    Scrolled +2 (now showing rows 2-4)');

  RIP.TableClear;
  WriteLn('  Table cleared');
  WriteLn;
End;

Procedure DemoVariableScoping;
Var S : String;
Begin
  WriteLn('=== SERVER: Variable Scoping Demo ===');
  WriteLn;

  RIP.DefineVarScoped('SCENE_BG', 'blue', RIP_SCOPE_LOCAL, False);
  RIP.DefineVarScoped('USERNAME', 'SysOp', RIP_SCOPE_SESSION, False);
  RIP.DefineVarScoped('TOTAL_CALLS', '1024', RIP_SCOPE_PERSIST, False);

  WriteLn('  Defined: SCENE_BG (local), USERNAME (session), TOTAL_CALLS (persist)');

  S := RIP.ExpandVars('User: $USERNAME$, Calls: $TOTAL_CALLS$, BG: $SCENE_BG$');
  WriteLn('  Expanded: ', S);

  WriteLn;
  WriteLn('  ClearScreen (scene end)...');
  RIP.ClearScreen;
  WriteLn('  SCENE_BG: "', RIP.GetVar('SCENE_BG'), '" (expected: empty)');
  WriteLn('  USERNAME: "', RIP.GetVar('USERNAME'), '" (expected: SysOp)');
  WriteLn('  TOTAL_CALLS: "', RIP.GetVar('TOTAL_CALLS'), '" (expected: 1024)');

  WriteLn;
  WriteLn('  Extended variables:');
  WriteLn('    $PIXFMT$  = ', RIP.ExpandVars('$PIXFMT$'));
  WriteLn('    $CANVASW$ = ', RIP.ExpandVars('$CANVASW$'));
  WriteLn('    $CANVASH$ = ', RIP.ExpandVars('$CANVASH$'));

  RIP.KillAllVars;
  WriteLn;
End;

Procedure DemoForm;
Var
  Valid : Boolean;
Begin
  WriteLn('=== SERVER: Form Definition Demo ===');
  WriteLn;

  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.OutTextXY(10, 5, 'New User Registration');

  // Define form fields (server sets layout and constraints)
  Idx := RIP.FormAddField(RIP_FIELD_LABEL, 'Title', 10, 30, 300, 16);
  RIP.FormSetValue(Idx, 'Please fill in your details:');

  Idx := RIP.FormAddField(RIP_FIELD_TEXT, 'Handle', 10, 55, 200, 20);
  RIP.FormBindVar(Idx, 'REG_HANDLE');
  RIP.FormSetRequired(Idx, True);
  WriteLn('  Field 1: Handle (text, required, bound to $REG_HANDLE$)');

  Idx := RIP.FormAddField(RIP_FIELD_TEXT, 'Location', 10, 85, 200, 20);
  RIP.FormBindVar(Idx, 'REG_LOCATION');
  WriteLn('  Field 2: Location (text, optional, bound to $REG_LOCATION$)');

  Idx := RIP.FormAddField(RIP_FIELD_DROPDOWN, 'Terminal', 10, 115, 200, 20);
  RIP.FormSetOptions(Idx, 'ANSI|RIPscrip|VT100|ASCII');
  RIP.FormSetValue(Idx, 'RIPscrip');
  RIP.FormBindVar(Idx, 'REG_TERMINAL');
  WriteLn('  Field 3: Terminal (dropdown: ANSI|RIPscrip|VT100|ASCII)');

  Idx := RIP.FormAddField(RIP_FIELD_CHECKBOX, 'Expert Mode', 10, 145, 200, 20);
  RIP.FormBindVar(Idx, 'REG_EXPERT');
  WriteLn('  Field 4: Expert Mode (checkbox, bound to $REG_EXPERT$)');

  // Render the empty form
  RIP.FormRender;
  WriteLn;
  WriteLn('  Form rendered (empty fields)');

  // Simulate server-side validation (no values yet)
  Valid := RIP.FormValidate;
  WriteLn('  Validation (empty): ', Valid, ' (expected: FALSE — Handle required)');

  // Simulate client filling in values
  WriteLn;
  WriteLn('  Simulating client input...');
  RIP.FormSetValue(1, 'CoolDude');      // Handle
  RIP.FormSetValue(2, 'New York');      // Location
  RIP.FormSetValue(3, 'RIPscrip');      // Terminal (already set)
  RIP.FormSetValue(4, '1');             // Expert = checked

  // Re-render with values
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.OutTextXY(10, 5, 'New User Registration');
  RIP.FormRender;

  // Validate again
  Valid := RIP.FormValidate;
  WriteLn('  Validation (filled): ', Valid, ' (expected: TRUE)');

  // Sync to text variables
  RIP.FormSyncToVars;
  WriteLn;
  WriteLn('  After SyncToVars:');
  WriteLn('    $REG_HANDLE$   = ', RIP.GetVar('REG_HANDLE'));
  WriteLn('    $REG_LOCATION$ = ', RIP.GetVar('REG_LOCATION'));
  WriteLn('    $REG_TERMINAL$ = ', RIP.GetVar('REG_TERMINAL'));
  WriteLn('    $REG_EXPERT$   = ', RIP.GetVar('REG_EXPERT'));

  // Export
  If RIP.SaveBMP('/tmp/rip3_server_form.bmp') Then
    WriteLn('  Saved: /tmp/rip3_server_form.bmp')
  Else
    WriteLn('  ERROR: SaveBMP failed');

  // Demo SyncFromVars (server pushes values back)
  WriteLn;
  WriteLn('  Server changes $REG_HANDLE$ to "Admin"...');
  RIP.SetVar('REG_HANDLE', 'Admin');
  RIP.FormSyncFromVars;
  WriteLn('  After SyncFromVars: Handle field = ', RIP.FormGetValue(1));

  RIP.FormClear;
  RIP.KillAllVars;
  WriteLn;
  WriteLn('  Form cleared, variables killed');
  WriteLn;
End;

Begin
  WriteLn;
  WriteLn('RIPscrip v3.0 — Server-Side Demo');
  WriteLn('================================');
  WriteLn;

  RIP := TRIPEngine.Create;

  DemoTable;
  DemoForm;
  DemoVariableScoping;

  RIP.Free;

  WriteLn('Server demo complete.');
  WriteLn;
End.
