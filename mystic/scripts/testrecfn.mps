// ====================================================================
// TESTRECFN.MPS : MPL Record Function Return Test (A3-04 + A5)
// ====================================================================
//
// WHAT THIS TESTS:
//   1. Functions that declare a record return type:
//        Function MakePoint (X, Y: LongInt) : PointRec;
//   2. Setting the result inside the function:
//        MakePoint := P;
//   3. Assigning the result at the call site:
//        Pt := MakePoint(10, 20);
//      This required BOTH compiler AND interpreter fixes:
//        Compiler:  ParseVarRecord handles Proc=True (emits opProcExec)
//        Interpreter: iRecord case peeks ProcID, calls ExecuteProcedure,
//                     copies function's data to target variable
//   4. Combining record functions with VAR record params
//
// HOW TO RUN:
//   mplc testrecfn.mps      (compile)
//   then run from BBS menu: GX testrecfn
//
// EXPECTED OUTPUT:
//   MakePoint(10, 20): X=10 Y=20 PASS
//   MakePoint(5,5) then MovePoint(+3,-2): X=8 Y=3 PASS
//   MakeColor(255, 128, 0, Orange): R=255 G=128 B=0 Name=Orange PASS
//
// IF IT FAILS:
//   X=0 Y=0 = function result not copied to caller variable
//   Syntax error on Pt := MakePoint() = ParseVarRecord not handling Proc
//   Wrong values = data copy size mismatch (RecInfo.OneSize)
//
// NOTE: Multiple record types need separate Type blocks in MPL.
//   Type Rec1 = Record ... End;
//   Type Rec2 = Record ... End;   // NOT in same Type block
//
// SEE ALSO: mplref.txt "Record Function Results" section
// ====================================================================
// Copyright (C) 2026 Kiddo — GPLv3 — Mystic BBS IRC Fork


Type
  PointRec = Record
    X : LongInt;
    Y : LongInt;
  End;

Type
  ColorRec = Record
    R : Byte;
    G : Byte;
    B : Byte;
    Name : String[20];
  End;

// Function returning a record — set result inside function
Function MakePoint (PX, PY: LongInt) : PointRec;
Var P : PointRec;
Begin
  P.X := PX;
  P.Y := PY;
  MakePoint := P;
End;

Function MakeColor (CR, CG, CB: Byte; CN: String) : ColorRec;
Var C : ColorRec;
Begin
  C.R := CR;
  C.G := CG;
  C.B := CB;
  C.Name := CN;
  MakeColor := C;
End;

// Procedure taking record by VAR
Procedure MovePoint (Var P: PointRec; DX, DY: LongInt);
Begin
  P.X := P.X + DX;
  P.Y := P.Y + DY;
End;

Var
  Pt  : PointRec;
  Clr : ColorRec;

Begin
  WriteLn('testrecfn — MPL Record Function Tests');
  WriteLn('');

  // Test 1: Basic record function call + assign
  Pt := MakePoint(10, 20);
  WriteLn('MakePoint(10, 20):');
  WriteLn('  X=' + Int2Str(Pt.X) + ' Y=' + Int2Str(Pt.Y));

  If (Pt.X = 10) And (Pt.Y = 20) Then
    WriteLn('  PASS')
  Else
    WriteLn('  FAIL');

  WriteLn('');

  // Test 2: Record function + VAR param combo
  Pt := MakePoint(5, 5);
  MovePoint(Pt, 3, -2);
  WriteLn('MakePoint(5,5) then MovePoint(+3,-2):');
  WriteLn('  X=' + Int2Str(Pt.X) + ' Y=' + Int2Str(Pt.Y));

  If (Pt.X = 8) And (Pt.Y = 3) Then
    WriteLn('  PASS')
  Else
    WriteLn('  FAIL');

  WriteLn('');

  // Test 3: Different record type function
  Clr := MakeColor(255, 128, 0, 'Orange');
  WriteLn('MakeColor(255, 128, 0, Orange):');
  WriteLn('  R=' + Int2Str(Clr.R) + ' G=' + Int2Str(Clr.G) +
          ' B=' + Int2Str(Clr.B) + ' Name=' + Clr.Name);

  If (Clr.R = 255) And (Clr.G = 128) And (Clr.B = 0) And (Clr.Name = 'Orange') Then
    WriteLn('  PASS')
  Else
    WriteLn('  FAIL');

  WriteLn('');
  WriteLn('Done.');
End.
