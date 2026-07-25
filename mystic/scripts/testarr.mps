// ====================================================================
// TESTARR.MPS : MPL Multi-Dimensional Array in Record Test (A5-02)
// ====================================================================
//
// WHAT THIS TESTS:
//   2D arrays inside record types. The compiler outputs dimension
//   sizes in the bytecode and the interpreter calculates offsets
//   using proper multi-dim indexing:
//     1D: (index-1) * OneSize
//     2D: ((a-1)*dim2 + (b-1)) * OneSize
//     3D: ((a-1)*dim2*dim3 + (b-1)*dim3 + (c-1)) * OneSize
//
// HOW TO RUN:
//   mplc testarr.mps        (compile)
//   then run from BBS menu: GX testarr
//
// EXPECTED OUTPUT:
//   Board: TicTacToe
//     1 2 3
//     4 5 6
//     7 8 9
//   PASS: Cells[2,3] = 6
//
// IF IT FAILS:
//   Wrong value = multi-dim offset calculation is broken
//   "Expected: ]" = wrong number of dimensions in access
//   Check mpl_execute.pas CheckArray and mpl_compile.pas ParseArray
//
// SEE ALSO: mplref.txt "Multi-Dimensional Arrays" section
// ====================================================================
// Copyright (C) 2026 Kiddo — GPLv3 — Mystic BBS IRC Fork


Type
  BoardRec = Record
    Cells : Array[1..3, 1..3] of Byte;
    Name  : String[20];
  End;

Var
  Board : BoardRec;
  X, Y  : Byte;

Begin
  WriteLn('testarr — MPL Multi-Dim Array in Record Test');
  WriteLn('');

  Board.Name := 'TicTacToe';

  // Fill the board
  For X := 1 to 3 Do
    For Y := 1 to 3 Do
      Board.Cells[X, Y] := (X - 1) * 3 + Y;

  // Display
  WriteLn('Board: ' + Board.Name);
  For X := 1 to 3 Do Begin
    Write('  ');
    For Y := 1 to 3 Do
      Write(Int2Str(Board.Cells[X, Y]) + ' ');
    WriteLn('');
  End;

  // Verify
  WriteLn('');
  If Board.Cells[2, 3] = 6 Then
    WriteLn('PASS: Cells[2,3] = 6')
  Else
    WriteLn('FAIL: Cells[2,3] = ' + Int2Str(Board.Cells[2, 3]));

  WriteLn('');
  WriteLn('Done.');
End.
