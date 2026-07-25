// ====================================================================
// TESTREC.MPS : MPL Record VAR Parameter Test (1.11IRC A1-02)
// ====================================================================
//
// WHAT THIS TESTS:
//   Records passed to procedures by VAR reference vs by value.
//   VAR means the procedure modifies the CALLER's copy.
//   By value means the procedure gets a COPY — changes are lost.
//
// HOW TO RUN:
//   mplc testrec.mps        (compile)
//   then run from BBS menu: GX testrec
//
// EXPECTED OUTPUT:
//   After SetPlayer(Var P):  Name=Hero Score=1000 Level=5
//   After ShowPlayer(P):     same values (read only, no change)
//   After BadSet(P):         values UNCHANGED (passed by value)
//
// IF IT FAILS:
//   VAR param not modifying caller = compiler/interpreter bug
//   Type mismatch error = wrong record type passed to VAR param
//
// SEE ALSO: mplref.txt "Record Parameters" section
// ====================================================================

Type
  TestRec = Record
    Name  : String[30];
    Score : LongInt;
    Level : Byte;
  End;

Var
  MyTest : TestRec;

// Pass by VAR reference — changes persist
Procedure SetRecord (Var T: TestRec);
Begin
  T.Name  := 'Modified';
  T.Score := 9999;
  T.Level := 42;
End;

// Pass by value — changes do NOT persist
Procedure PrintRecord (T: TestRec);
Begin
  WriteLn('  Name:  ' + T.Name);
  WriteLn('  Score: ' + Int2Str(T.Score));
  WriteLn('  Level: ' + Int2Str(T.Level));
  // This change should NOT affect caller
  T.Name := 'Changed';
End;

Begin
  WriteLn('testrec — MPL Record VAR Parameter Test');
  WriteLn('');

  // Initialize
  MyTest.Name  := 'Original';
  MyTest.Score := 100;
  MyTest.Level := 1;

  WriteLn('1. Initial values:');
  PrintRecord(MyTest);

  // Verify by-value did not change our record
  WriteLn('');
  WriteLn('2. After PrintRecord (by value, should be unchanged):');
  PrintRecord(MyTest);

  // Now modify by VAR reference
  SetRecord(MyTest);

  WriteLn('');
  WriteLn('3. After SetRecord (by VAR, should be modified):');
  PrintRecord(MyTest);

  WriteLn('');
  If MyTest.Score = 9999 Then
    WriteLn('PASS: VAR reference works!')
  Else
    WriteLn('FAIL: VAR reference did not persist');

  WriteLn('');
  WriteLn('Done.');
End.
