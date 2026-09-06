{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// Phase 20: Data Tables and Forms — functional and stress tests
// Tests SERVER-SIDE table API and CLIENT-SIDE form API
//
Program test_phase20;

Uses rip3api;

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

// ==== SERVER-SIDE: Table Tests ====

Procedure TestTableCreateClear;
Begin
  WriteLn;
  WriteLn('--- Table Create/Clear ---');
  RIP.TableCreate(10, 10, 3);
  Check('TableCreate: no crash', True);
  Check('TableGetCols = 0 (added via AddCol)', RIP.TableGetCols = 0);
  Check('TableGetRows = 0', RIP.TableGetRows = 0);
  RIP.TableClear;
  Check('TableClear: no crash', True);
End;

Procedure TestTableColumns;
Begin
  WriteLn;
  WriteLn('--- Table Columns ---');
  RIP.TableCreate(10, 10, 3);
  RIP.TableAddCol('Name', 100, RIP_COL_LEFT);
  RIP.TableAddCol('Score', 60, RIP_COL_RIGHT);
  RIP.TableAddCol('Rank', 50, RIP_COL_CENTER);
  Check('3 columns added', RIP.TableGetCols = 3);
  RIP.TableClear;
End;

Procedure TestTableRows;
Begin
  WriteLn;
  WriteLn('--- Table Rows ---');
  RIP.TableCreate(10, 10, 2);
  RIP.TableAddCol('A', 80, 0);
  RIP.TableAddCol('B', 80, 0);
  RIP.TableAddRow;
  RIP.TableAddRow;
  RIP.TableAddRow;
  Check('3 rows added', RIP.TableGetRows = 3);
  RIP.TableSetCell(0, 0, 'Hello', 15);
  RIP.TableSetCell(1, 1, 'World', 14);
  Check('SetCell: no crash', True);
  RIP.TableClear;
End;

Procedure TestTableRender;
Begin
  WriteLn;
  WriteLn('--- Table Render ---');
  RIP.ClearScreen;
  RIP.TableCreate(10, 10, 2);
  RIP.TableAddCol('Col1', 100, 0);
  RIP.TableAddCol('Col2', 100, 1);
  RIP.TableAddRow;
  RIP.TableSetCell(0, 0, 'Data1', 15);
  RIP.TableSetCell(0, 1, 'Data2', 14);
  RIP.TableRender;
  Check('TableRender: no crash', True);
  // Header should have drawn something
  Check('Header area has pixels', RIP.GetPixel(50, 12) <> 0);
  RIP.TableClear;
End;

Procedure TestTableScroll;
Begin
  WriteLn;
  WriteLn('--- Table Scroll ---');
  RIP.TableCreate(10, 10, 1);
  RIP.TableAddCol('Data', 200, 0);
  RIP.TableAddRow; RIP.TableSetCell(0, 0, 'Row0', 15);
  RIP.TableAddRow; RIP.TableSetCell(1, 0, 'Row1', 15);
  RIP.TableAddRow; RIP.TableSetCell(2, 0, 'Row2', 15);
  RIP.TableScroll(1);
  Check('Scroll +1: no crash', True);
  RIP.TableScroll(-5);
  Check('Scroll -5 (clamps to 0): no crash', True);
  RIP.TableScroll(100);
  Check('Scroll +100 (clamps to max): no crash', True);
  RIP.TableClear;
End;

Procedure TestTableBadIndices;
Begin
  WriteLn;
  WriteLn('--- Table Bad Indices ---');
  RIP.TableCreate(10, 10, 1);
  RIP.TableAddCol('A', 80, 0);
  RIP.TableAddRow;
  RIP.TableSetCell(-1, 0, 'Bad', 15);
  Check('SetCell row=-1: no crash', True);
  RIP.TableSetCell(0, -1, 'Bad', 15);
  Check('SetCell col=-1: no crash', True);
  RIP.TableSetCell(999, 0, 'Bad', 15);
  Check('SetCell row=999: no crash', True);
  RIP.TableSetCell(0, 999, 'Bad', 15);
  Check('SetCell col=999: no crash', True);
  RIP.TableClear;
End;

Procedure TestTableEmpty;
Begin
  WriteLn;
  WriteLn('--- Table Empty Render ---');
  RIP.TableCreate(10, 10, 0);
  RIP.TableRender;
  Check('Render with 0 cols: no crash', True);
  RIP.TableClear;
  RIP.TableRender;
  Check('Render after clear: no crash', True);
End;

Procedure TestTableMaxCols;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- Table Max Columns ---');
  RIP.TableCreate(0, 0, 0);
  For I := 1 to 40 Do
    RIP.TableAddCol('C', 10, 0);
  Check('40 cols (max 32): clamped', RIP.TableGetCols = 32);
  RIP.TableClear;
End;

// ==== CLIENT-SIDE: Form Tests ====

Procedure TestFormAddField;
Var Idx : Integer;
Begin
  WriteLn;
  WriteLn('--- Form AddField ---');
  RIP.FormClear;
  Idx := RIP.FormAddField(RIP_FIELD_TEXT, 'Username', 10, 50, 200, 20);
  Check('FormAddField: returns 0', Idx = 0);
  Idx := RIP.FormAddField(RIP_FIELD_CHECKBOX, 'Remember', 10, 80, 150, 20);
  Check('FormAddField: returns 1', Idx = 1);
  Idx := RIP.FormAddField(RIP_FIELD_DROPDOWN, 'Color', 10, 110, 150, 20);
  Check('FormAddField: returns 2', Idx = 2);
  RIP.FormClear;
End;

Procedure TestFormSetGetValue;
Var Idx : Integer;
Begin
  WriteLn;
  WriteLn('--- Form Set/Get Value ---');
  RIP.FormClear;
  Idx := RIP.FormAddField(RIP_FIELD_TEXT, 'Name', 10, 50, 200, 20);
  RIP.FormSetValue(Idx, 'John');
  Check('FormGetValue = John', RIP.FormGetValue(Idx) = 'John');
  RIP.FormSetValue(Idx, '');
  Check('FormGetValue empty', RIP.FormGetValue(Idx) = '');
  RIP.FormClear;
End;

Procedure TestFormOptions;
Var Idx : Integer;
Begin
  WriteLn;
  WriteLn('--- Form Options ---');
  RIP.FormClear;
  Idx := RIP.FormAddField(RIP_FIELD_DROPDOWN, 'Color', 10, 50, 150, 20);
  RIP.FormSetOptions(Idx, 'Red|Green|Blue');
  RIP.FormSetValue(Idx, 'Green');
  Check('Dropdown value = Green', RIP.FormGetValue(Idx) = 'Green');
  RIP.FormClear;
End;

Procedure TestFormValidate;
Var Idx : Integer;
Begin
  WriteLn;
  WriteLn('--- Form Validate ---');
  RIP.FormClear;
  Idx := RIP.FormAddField(RIP_FIELD_TEXT, 'Required', 10, 50, 200, 20);
  RIP.FormSetRequired(Idx, True);
  Check('Empty required: fails', Not RIP.FormValidate);
  RIP.FormSetValue(Idx, 'filled');
  Check('Filled required: passes', RIP.FormValidate);
  RIP.FormClear;
End;

Procedure TestFormBindVar;
Var Idx : Integer;
Begin
  WriteLn;
  WriteLn('--- Form Bind Variable ---');
  RIP.FormClear;
  Idx := RIP.FormAddField(RIP_FIELD_TEXT, 'User', 10, 50, 200, 20);
  RIP.FormBindVar(Idx, 'USERNAME');
  RIP.FormSetValue(Idx, 'sysop');
  RIP.FormSyncToVars;
  Check('SyncToVars: $USERNAME$ = sysop', RIP.GetVar('USERNAME') = 'sysop');

  RIP.SetVar('USERNAME', 'admin');
  RIP.FormSyncFromVars;
  Check('SyncFromVars: field = admin', RIP.FormGetValue(Idx) = 'admin');
  RIP.FormClear;
  RIP.KillAllVars;
End;

Procedure TestFormRender;
Begin
  WriteLn;
  WriteLn('--- Form Render ---');
  RIP.FormClear;
  RIP.ClearScreen;
  RIP.FormAddField(RIP_FIELD_TEXT, 'Name', 10, 50, 200, 20);
  RIP.FormAddField(RIP_FIELD_CHECKBOX, 'Accept', 10, 80, 150, 20);
  RIP.FormAddField(RIP_FIELD_LABEL, 'Info', 10, 110, 200, 20);
  RIP.FormSetValue(2, 'Read-only label');
  RIP.FormRender;
  Check('FormRender: no crash', True);
  RIP.FormClear;
End;

Procedure TestFormBadIndices;
Begin
  WriteLn;
  WriteLn('--- Form Bad Indices ---');
  RIP.FormSetValue(-1, 'bad');
  Check('SetValue(-1): no crash', True);
  RIP.FormSetValue(999, 'bad');
  Check('SetValue(999): no crash', True);
  Check('GetValue(-1) empty', RIP.FormGetValue(-1) = '');
  Check('GetValue(999) empty', RIP.FormGetValue(999) = '');
  RIP.FormBindVar(-1, 'X');
  Check('BindVar(-1): no crash', True);
  RIP.FormSetOptions(999, 'A|B');
  Check('SetOptions(999): no crash', True);
End;

Procedure TestFormMaxFields;
Var I, Idx : Integer;
Begin
  WriteLn;
  WriteLn('--- Form Max Fields ---');
  RIP.FormClear;
  For I := 1 to 70 Do
    Idx := RIP.FormAddField(RIP_FIELD_TEXT, 'F', 0, 0, 50, 20);
  Check('70 fields (max 64): last returns -1', Idx = -1);
  RIP.FormClear;
End;

Procedure TestFormAllPixelFormats;
Var Fmt : Byte;
Begin
  WriteLn;
  WriteLn('--- Form All Pixel Formats ---');
  RIP.FormClear;
  RIP.FormAddField(RIP_FIELD_TEXT, 'T', 10, 10, 100, 20);
  RIP.FormSetValue(0, 'Test');
  For Fmt := RIP_PIXFMT_INDEXED8 to RIP_PIXFMT_RGB32 Do Begin
    RIP.SetPixelFormat(Fmt);
    RIP.ClearScreen;
    RIP.FormRender;
  End;
  Check('All 3 pixel formats: no crash', True);
  RIP.SetPixelFormat(RIP_PIXFMT_INDEXED8);
  RIP.FormClear;
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 20: Data Tables and Forms — TESTS ===');

  RIP := TRIPEngine.Create;

  // Server-side
  TestTableCreateClear;
  TestTableColumns;
  TestTableRows;
  TestTableRender;
  TestTableScroll;
  TestTableBadIndices;
  TestTableEmpty;
  TestTableMaxCols;

  // Client-side
  TestFormAddField;
  TestFormSetGetValue;
  TestFormOptions;
  TestFormValidate;
  TestFormBindVar;
  TestFormRender;
  TestFormBadIndices;
  TestFormMaxFields;
  TestFormAllPixelFormats;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.
