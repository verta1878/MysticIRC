{$MODE DELPHI}
{$H-}
Unit RIPTextVar;
{
  RIPscrip Text Variable System — ported from ripscr.pas.
  Manages user-defined variables ($NAME$) and resolves built-in
  system variables (DATE, TIME, CURX, CURY, etc.).

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}
Interface

Uses RIPEngine;

Const
  RIP_MAX_VARS = 256;

Type
  TRIPVariable = Record
    Active   : Boolean;
    Name     : String[40];
    Value    : String[200];
    Persist  : Boolean;
    Required : Boolean;
  End;

Procedure DefineVar(Name, Value: String; Persist, Required: Boolean);
Function  GetVar(Name: String): String;
Procedure SetVar(Name, Value: String);
Function  FindVar(Name: String): Integer;
Procedure KillAllVars;
Function  SaveVars(FileName: String): Boolean;
Function  LoadVars(FileName: String): Boolean;
Function  ResolveVar(Name: String): String;
Function  ExpandVars(S: String): String;

Implementation

Var
  Variables : Array[1..RIP_MAX_VARS] Of TRIPVariable;
  VarCount  : Integer;

Function IntToStr(I: Integer): String;
Begin
  Str(I, Result);
End;

Procedure DefineVar(Name, Value: String; Persist, Required: Boolean);
Var Idx: Integer;
Begin
  Idx := FindVar(Name);
  If Idx = 0 Then Begin
    If VarCount >= RIP_MAX_VARS Then Exit;
    Inc(VarCount);
    Idx := VarCount;
  End;
  Variables[Idx].Active   := True;
  Variables[Idx].Name     := Name;
  Variables[Idx].Value    := Value;
  Variables[Idx].Persist  := Persist;
  Variables[Idx].Required := Required;
End;

Function GetVar(Name: String): String;
Var Idx: Integer;
Begin
  Idx := FindVar(Name);
  If Idx > 0 Then Result := Variables[Idx].Value
  Else Result := '';
End;

Procedure SetVar(Name, Value: String);
Var Idx: Integer;
Begin
  Idx := FindVar(Name);
  If Idx > 0 Then Variables[Idx].Value := Value;
End;

Function FindVar(Name: String): Integer;
Var I: Integer;
Begin
  Result := 0;
  For I := 1 To VarCount Do
    If Variables[I].Active And (Variables[I].Name = Name) Then Begin
      Result := I;
      Exit;
    End;
End;

Procedure KillAllVars;
Var I: Integer;
Begin
  VarCount := 0;
  For I := 1 To RIP_MAX_VARS Do
    Variables[I].Active := False;
End;

Function SaveVars(FileName: String): Boolean;
Var F: Text; I: Integer;
Begin
  Result := False;
  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;
  For I := 1 To RIP_MAX_VARS Do
    If Variables[I].Active And Variables[I].Persist Then
      WriteLn(F, Variables[I].Name, '=', Variables[I].Value);
  Close(F);
  Result := True;
End;

Function LoadVars(FileName: String): Boolean;
Var F: Text; Line: String; P: Integer; Name, Val: String;
Begin
  Result := False;
  Assign(F, FileName);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;
  While Not EOF(F) Do Begin
    ReadLn(F, Line);
    If Length(Line) = 0 Then Continue;
    P := 1;
    While (P <= Length(Line)) And (Line[P] <> '=') Do Inc(P);
    If P > Length(Line) Then Continue;
    Name := Copy(Line, 1, P - 1);
    Val  := Copy(Line, P + 1, Length(Line));
    If FindVar(Name) > 0 Then
      SetVar(Name, Val)
    Else
      DefineVar(Name, Val, True, False);
  End;
  Close(F);
  Result := True;
End;

Function ResolveVar(Name: String): String;
Var I: Integer; UName: String;
Begin
  Result := '';
  UName := Name;
  For I := 1 To Length(UName) Do
    If (UName[I] >= 'a') And (UName[I] <= 'z') Then
      UName[I] := Chr(Ord(UName[I]) - 32);

  { System variables }
  If UName = 'DATE'    Then Begin Result := '01/01/26'; Exit; End;
  If UName = 'TIME'    Then Begin Result := '00:00:00'; Exit; End;
  If UName = 'RUNDATE' Then Begin Result := '01/01/26'; Exit; End;
  If UName = 'RUNTIME' Then Begin Result := '00:00:00'; Exit; End;
  If UName = 'CURX'    Then Begin Result := IntToStr(Canvas.CurX); Exit; End;
  If UName = 'CURY'    Then Begin Result := IntToStr(Canvas.CurY); Exit; End;
  If UName = 'CURSOR'  Then Begin Result := 'YES'; Exit; End;

  { Text window variables }
  If UName = 'TWX0'   Then Begin Result := IntToStr(Canvas.TWinX0); Exit; End;
  If UName = 'TWY0'   Then Begin Result := IntToStr(Canvas.TWinY0); Exit; End;
  If UName = 'TWX1'   Then Begin Result := IntToStr(Canvas.TWinX1); Exit; End;
  If UName = 'TWY1'   Then Begin Result := IntToStr(Canvas.TWinY1); Exit; End;
  If UName = 'TWW'    Then Begin Result := IntToStr(Canvas.TWinX1 - Canvas.TWinX0 + 1); Exit; End;
  If UName = 'TWH'    Then Begin Result := IntToStr(Canvas.TWinY1 - Canvas.TWinY0 + 1); Exit; End;
  If UName = 'TWFONT' Then Begin Result := IntToStr(Canvas.TWinSize); Exit; End;

  { Sound variables — no-op server side }
  If UName = 'ALARM'     Then Exit;
  If UName = 'PHASER'    Then Exit;
  If UName = 'REVPHASER' Then Exit;

  { User-defined variables }
  I := FindVar(Name);
  If I > 0 Then Begin
    Result := Variables[I].Value;
    Exit;
  End;
End;

Function ExpandVars(S: String): String;
Var P, Start: Integer; VarName, Value, Buf: String;
Begin
  { Fast path: no $ in string }
  P := 1;
  While (P <= Length(S)) And (S[P] <> '$') Do Inc(P);
  If P > Length(S) Then Begin Result := S; Exit; End;

  Buf := '';
  P := 1;
  While P <= Length(S) Do Begin
    If S[P] = '$' Then Begin
      Start := P + 1;
      Inc(P);
      While (P <= Length(S)) And (S[P] <> '$') Do Inc(P);
      If (P <= Length(S)) And (S[P] = '$') Then Begin
        VarName := Copy(S, Start, P - Start);
        Value := ResolveVar(VarName);
        If Value <> '' Then Buf := Buf + Value
        Else Buf := Buf + '$' + VarName + '$';
        Inc(P);
      End Else
        Buf := Buf + '$' + Copy(S, Start, P - Start);
    End Else Begin
      Start := P;
      While (P <= Length(S)) And (S[P] <> '$') Do Inc(P);
      Buf := Buf + Copy(S, Start, P - Start);
    End;
  End;
  Result := Buf;
End;

Initialization
  VarCount := 0;
  FillChar(Variables, SizeOf(Variables), 0);

End.
