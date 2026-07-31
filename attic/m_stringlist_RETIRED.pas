//
// This file is part of the Mystic BBS IRC Fork.
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// ====================================================================
// RETIRED - not built, kept for reference / scene history
// --------------------------------------------------------------------
// TMDLStringList: g00r00's TMDL string-list wrapper.  This fork
// standardized on the FPC RTL (Classes.TStringList) and translated every
// consumer over; mis_events was the last one.  With zero consumers left,
// this shim is retired here (not deleted) for GPL-3 attribution and
// Mystic scene history.  Retired 2026-07-06 (fork) - completes the
// TMDL->FPC RTL migration tree-wide.
// ====================================================================

Unit m_StringList;

{$I M_OPS.PAS}

Interface

Type
  TMDLList = Class
    List  : Array of Pointer;
    Count : LongInt;

    Constructor Create;
    Procedure Add     (Ptr: Pointer);
    Function  IndexOf (PTR: Pointer) : LongInt;
    Procedure Pack;
  End;

  TMDLStringListSortMethod = (sortAscending, sortDecending);

  TMDLStringList = Class
    Strings : Array of String;

    Procedure Add     (Const Line: String);
    Procedure Delete  (Num: LongInt);
    Procedure Clear;
    Function  Count   : LongInt;
    Function  IndexOf (Const Line: String) : LongInt;
    Procedure Sort;
    Procedure Sort    (Left, Right: LongInt; Mode: TMDLStringListSortMethod);
    Function  TextSize : LongInt;
  End;

Implementation

Constructor TMDLList.Create;
Begin
  Count := 0;
End;

Procedure TMDLList.Pack;
Var
  Loop     : LongInt;
  NewCount : LongInt;
  SrcPtr   : PPointer;
  DestPtr  : PPointer;
Begin
  NewCount := 0;
  SrcPtr   := @List[0];
  DestPtr  := SrcPtr;

  For Loop := 0 to Length(List) - 1 Do Begin
    If Assigned(SrcPtr^) Then Begin
      DestPtr^ := SrcPtr^;

      Inc (DestPtr);
      Inc (NewCount);
    End;

    Inc (SrcPtr);
  End;

  Count := NewCount;
End;

Procedure TMDLList.Add (Ptr: Pointer);
Var
  Total : LongInt;
Begin
  Total := Length(List);

  SetLength(List, Total + 1);

  List[Total] := PTR;
End;

Function TMDLList.IndexOf (PTR: Pointer) : LongInt;
Var
  Loop : LongInt;
Begin
  Result := -1;

  For Loop := 0 To Length(List) - 1 Do Begin
    If List[Loop] = PTR Then Begin
      Result := Loop;

      Break;
    End;
  End;
End;

Function TMDLStringList.TextSize : LongInt;
Var
  Loop : LongInt;
Begin
  Result := 0;

  For Loop := 0 To Length(Strings) - 1 Do
    Inc (Result, Length(Strings[Loop]));
End;

Procedure TMDLStringList.Sort (Left, Right: LongInt; Mode: TMDLStringListSortMethod);
Var
  Upper : LongInt;
  Lower : LongInt;
  Pivot : String;
  Temp  : String;
Begin
  If Right <= 0 Then Exit;

  Left  := Left;
  Right := Right;
  Lower := Left;
  Upper := Right;
  Pivot := Strings[(Left + Right) DIV 2];

  Repeat
    Case Mode of
      sortAscending:
        Begin
          While Strings[Lower] < Pivot Do Inc(Lower);
          While Pivot < Strings[Upper] Do Dec(Upper);
        End;
      sortDecending:
        Begin
          While Strings[Lower] > Pivot Do Inc(Lower);
          While Pivot > Strings[Upper] Do Dec(Upper);
        End;
    End;

    If Lower <= Upper Then Begin
      Temp           := Strings[Lower];
      Strings[Lower] := Strings[Upper];
      Strings[Upper] := Temp;

      Inc (Lower);
      Dec (Upper);
    End;

  Until Lower > Upper;

  If Left  < Upper Then Sort(Left,  Upper, Mode);
  If Lower < Right Then Sort(Lower, Right, Mode);
End;

Procedure TMDLStringList.Sort;
Begin
  Sort(0, Length(Strings) - 1, sortAscending);
End;

Function TMDLStringList.IndexOf (Const Line: String) : LongInt;
Var
  Loop : LongInt;
Begin
  Result := -1;

  For Loop := 0 To Length(Strings) - 1 Do Begin
    If Strings[Loop] = Line Then Begin
      Result := Loop;

      Break;
    End;
  End;
End;

Procedure TMDLStringList.Clear;
Begin
  SetLength (Strings, 0);
End;

Function TMDLStringList.Count : LongInt;
Begin
  Result := Length(Strings);
End;

Procedure TMDLStringList.Add (Const Line: String);
Var
  Total : LongInt;
Begin
  Total := Length(Strings);

  SetLength(Strings, Total + 1);

  Strings[Total] := Line;
End;

Procedure TMDLStringList.Delete (Num: LongInt);
Var
  Total : LongInt;
Begin
  Total := Length(Strings);

  If (Num < 0) or (Num >= Total) Then Exit;

  If Num < Total - 1 Then
    Move (Strings[Num + 1], Strings[Num], SizeOf(Strings[0]) * (Total - 1 - Num));

  PPointer  (@Strings[Total - 1])^ := NIL;
  SetLength (Strings, Total - 1);
End;

End.
