{ mripui.pas — MRP Widget Library
  Built-in MRP widget renderer — boxes, windows, buttons, frames, dialogs. (boxes,
  windows, buttons, frames, dialogs).

  MRP widget concept inspired by JMedia v2.0 WIZ format.
  Clean-room implementation for Mystic BBS.

  Study reference: JMedia v2.0, JDraw Pro v4.2.
  Easy Fonts v2.0 registered to verta1878.

  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench, hexadecimal, byte, DotMatrix. }
{$MODE OBJFPC}
{$H+}
Unit mripui;

Interface

Const
  WIZ_MAX_LINES = 512;

Type
  { Drawing callback interface — the WIZ renderer calls these }
  TWizDrawCallbacks = Record
    SetColor    : Procedure(Color: Integer);
    SetFillStyle: Procedure(Style, Color: Integer);
    SetFillPat  : Procedure(Style, Color, Flag: Integer);
    DrawBar     : Procedure(X1, Y1, X2, Y2: Integer);
    DrawRect    : Procedure(X1, Y1, X2, Y2: Integer);
    DrawLine    : Procedure(X1, Y1, X2, Y2: Integer);
    DrawPixel   : Procedure(X, Y: Integer);
    FloodFill   : Procedure(X, Y, Border: Integer);
  End;

  TWizLine = Record
    Cmd  : Char;
    Args : String[80];
  End;

  TWizTemplate = Record
    Lines    : Array[0..WIZ_MAX_LINES-1] of TWizLine;
    Count    : Integer;
    Loaded   : Boolean;
    FileName : String[64];
  End;

Function  LoadMrpTemplate(const FileName: String; var Tpl: TWizTemplate): Boolean;
Procedure RenderMrpTemplate(var Tpl: TWizTemplate; X, Y, X2, Y2: Integer;
            var CB: TWizDrawCallbacks);

{ Built-in MRP widget types — no external files needed }
Procedure RenderBox(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Procedure RenderWindow(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Procedure RenderFrame(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Procedure RenderDialog(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Procedure RenderButtonUp(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Procedure RenderButtonDown(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);

{ Render by name — "Box", "Window", "Frame", "Dialog", "ButtonUp", "ButtonDown" }
Function  RenderWidget(const Name: String; X, Y, X2, Y2: Integer;
            var CB: TWizDrawCallbacks): Boolean;

Implementation

Uses SysUtils;

Function Trim(const S: String): String;
Var
  I, J: Integer;
Begin
  I := 1;
  While (I <= Length(S)) and (S[I] <= ' ') Do Inc(I);
  J := Length(S);
  While (J >= I) and (S[J] <= ' ') Do Dec(J);
  Result := Copy(S, I, J - I + 1);
End;

Function LoadMrpTemplate(const FileName: String; var Tpl: TWizTemplate): Boolean;
Var
  F: TextFile;
  Line, S: String;
  C: Char;
Begin
  Result := False;
  FillChar(Tpl, SizeOf(Tpl), 0);

  Assign(F, FileName);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  Tpl.FileName := FileName;
  Tpl.Count := 0;

  While Not Eof(F) Do Begin
    ReadLn(F, Line);
    S := Trim(Line);

    { Skip empty lines and comments }
    If Length(S) = 0 Then Continue;
    If S[1] = '''' Then Continue;  { comment }

    { First non-space character is the command }
    C := S[1];

    If Tpl.Count < WIZ_MAX_LINES Then Begin
      Tpl.Lines[Tpl.Count].Cmd := C;
      If Length(S) > 1 Then
        Tpl.Lines[Tpl.Count].Args := Trim(Copy(S, 2, Length(S) - 1))
      Else
        Tpl.Lines[Tpl.Count].Args := '';
      Inc(Tpl.Count);
    End;
  End;

  Close(F);
  Tpl.Loaded := True;
  Result := True;
End;

{ Evaluate a coordinate expression like "x+5", "y2-3", "cx" }
Function EvalCoord(const Expr: String; X, Y, X2, Y2: Integer): Integer;
Var
  S: String;
  CX, CY: Integer;
  Base, Offset: Integer;
  OpPos: Integer;
  I: Integer;
Begin
  CX := (X + X2) div 2;
  CY := (Y + Y2) div 2;
  S := Trim(Expr);

  { Direct variable }
  If S = 'x' Then Begin Result := X; Exit; End;
  If S = 'y' Then Begin Result := Y; Exit; End;
  If S = 'x2' Then Begin Result := X2; Exit; End;
  If S = 'y2' Then Begin Result := Y2; Exit; End;
  If S = 'cx' Then Begin Result := CX; Exit; End;
  If S = 'cy' Then Begin Result := CY; Exit; End;

  { Variable with arithmetic: x+5, y2-3, cx+10 }
  { Find + or - after the variable name }
  OpPos := 0;
  For I := 2 to Length(S) Do Begin
    If (S[I] = '+') or (S[I] = '-') Then Begin
      OpPos := I;
      Break;
    End;
  End;

  If OpPos > 0 Then Begin
    { Parse variable part }
    Offset := StrToIntDef(Copy(S, OpPos, Length(S) - OpPos + 1), 0);

    If Copy(S, 1, OpPos - 1) = 'x' Then Base := X
    Else If Copy(S, 1, OpPos - 1) = 'y' Then Base := Y
    Else If Copy(S, 1, OpPos - 1) = 'x2' Then Base := X2
    Else If Copy(S, 1, OpPos - 1) = 'y2' Then Base := Y2
    Else If Copy(S, 1, OpPos - 1) = 'cx' Then Base := CX
    Else If Copy(S, 1, OpPos - 1) = 'cy' Then Base := CY
    Else Begin
      { Plain number }
      Result := StrToIntDef(S, 0);
      Exit;
    End;

    Result := Base + Offset;
    Exit;
  End;

  { Plain number }
  Result := StrToIntDef(S, 0);
End;

{ Parse space-separated arguments into tokens }
Procedure ParseArgs(const Args: String; var Tokens: Array of String;
  var Count: Integer);
Var
  I, Start: Integer;
  InToken: Boolean;
Begin
  Count := 0;
  InToken := False;
  Start := 1;

  For I := 1 to Length(Args) Do Begin
    If Args[I] > ' ' Then Begin
      If Not InToken Then Begin
        Start := I;
        InToken := True;
      End;
    End Else Begin
      If InToken Then Begin
        If Count <= High(Tokens) Then Begin
          Tokens[Count] := Copy(Args, Start, I - Start);
          Inc(Count);
        End;
        InToken := False;
      End;
    End;
  End;

  { Last token }
  If InToken and (Count <= High(Tokens)) Then Begin
    Tokens[Count] := Copy(Args, Start, Length(Args) - Start + 1);
    Inc(Count);
  End;
End;

Procedure RenderMrpTemplate(var Tpl: TWizTemplate; X, Y, X2, Y2: Integer;
  var CB: TWizDrawCallbacks);
Var
  I, TCount: Integer;
  Tok: Array[0..7] of String;
  A1, A2, A3, A4: Integer;
Begin
  If Not Tpl.Loaded Then Exit;

  For I := 0 to Tpl.Count - 1 Do Begin
    ParseArgs(Tpl.Lines[I].Args, Tok, TCount);

    Case Tpl.Lines[I].Cmd of
      'c': Begin  { SetColor }
        If TCount >= 1 Then
          CB.SetColor(StrToIntDef(Tok[0], 0));
      End;

      'S': Begin  { SetFillStyle style color }
        If TCount >= 2 Then
          CB.SetFillStyle(StrToIntDef(Tok[0], 0), StrToIntDef(Tok[1], 0));
      End;

      '=': Begin  { FillPattern style color flag }
        If TCount >= 3 Then
          CB.SetFillPat(StrToIntDef(Tok[0], 0), StrToIntDef(Tok[1], 0),
                        StrToIntDef(Tok[2], 0));
      End;

      'B': Begin  { Bar x y x2 y2 }
        If TCount >= 4 Then Begin
          A1 := EvalCoord(Tok[0], X, Y, X2, Y2);
          A2 := EvalCoord(Tok[1], X, Y, X2, Y2);
          A3 := EvalCoord(Tok[2], X, Y, X2, Y2);
          A4 := EvalCoord(Tok[3], X, Y, X2, Y2);
          CB.DrawBar(A1, A2, A3, A4);
        End;
      End;

      'R': Begin  { Rectangle x y x2 y2 }
        If TCount >= 4 Then Begin
          A1 := EvalCoord(Tok[0], X, Y, X2, Y2);
          A2 := EvalCoord(Tok[1], X, Y, X2, Y2);
          A3 := EvalCoord(Tok[2], X, Y, X2, Y2);
          A4 := EvalCoord(Tok[3], X, Y, X2, Y2);
          CB.DrawRect(A1, A2, A3, A4);
        End;
      End;

      'L': Begin  { Line x1 y1 x2 y2 }
        If TCount >= 4 Then Begin
          A1 := EvalCoord(Tok[0], X, Y, X2, Y2);
          A2 := EvalCoord(Tok[1], X, Y, X2, Y2);
          A3 := EvalCoord(Tok[2], X, Y, X2, Y2);
          A4 := EvalCoord(Tok[3], X, Y, X2, Y2);
          CB.DrawLine(A1, A2, A3, A4);
        End;
      End;

      'X': Begin  { Pixel x y }
        If TCount >= 2 Then Begin
          A1 := EvalCoord(Tok[0], X, Y, X2, Y2);
          A2 := EvalCoord(Tok[1], X, Y, X2, Y2);
          CB.DrawPixel(A1, A2);
        End;
      End;

      'F': Begin  { FloodFill x y border }
        If TCount >= 3 Then Begin
          A1 := EvalCoord(Tok[0], X, Y, X2, Y2);
          A2 := EvalCoord(Tok[1], X, Y, X2, Y2);
          A3 := StrToIntDef(Tok[2], 0);
          CB.FloodFill(A1, A2, A3);
        End;
      End;
    End; { case }
  End; { for }
End;

Function LoadAndRenderMrp(const FileName: String; X, Y, X2, Y2: Integer;
  var CB: TWizDrawCallbacks): Boolean;
Var
  Tpl: TWizTemplate;
Begin
  Result := LoadMrpTemplate(FileName, Tpl);
  If Result Then
    RenderMrpTemplate(Tpl, X, Y, X2, Y2, CB);
End;

{ ================================================================
  Built-in MRP Widget Types
  Concept inspired by JMedia v2.0 WIZ format (credit: JMedia/JDraw)
  Clean-room implementation for Mystic BBS
  ================================================================ }

Procedure RenderBox(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Begin
  CB.SetFillStyle(1, 7);
  CB.DrawBar(X+1, Y+1, X2-1, Y2-1);
  CB.SetColor(15);
  CB.DrawRect(X, Y, X2, Y2);
  CB.SetColor(8);
  CB.DrawLine(X, Y2, X2, Y2);
  CB.DrawLine(X2, Y, X2, Y2);
End;

Procedure RenderWindow(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Begin
  CB.SetFillStyle(1, 7);
  CB.DrawBar(X+1, Y+1, X2-1, Y2-1);
  CB.SetColor(15);
  CB.DrawRect(X, Y, X2, Y2);
  CB.DrawRect(X+5, Y+20, X2-5, Y2-4);
  CB.SetColor(8);
  CB.DrawLine(X, Y2, X2, Y2);
  CB.DrawLine(X2, Y, X2, Y2);
  CB.DrawLine(X+5, Y+20, X+5, Y2-4);
  CB.DrawLine(X+5, Y+20, X2-5, Y+20);
End;

Procedure RenderFrame(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Begin
  CB.SetColor(9);
  CB.DrawRect(X+1, Y+1, X2-1, Y2-1);
  CB.DrawRect(X+2, Y+2, X2-2, Y2-2);
  CB.SetColor(1);
  CB.DrawRect(X, Y, X2, Y2);
  CB.DrawRect(X+3, Y+3, X2-3, Y2-3);
End;

Procedure RenderDialog(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Begin
  CB.SetColor(15);
  CB.DrawRect(X, Y, X2, Y2);
  CB.SetFillStyle(1, 0);
  CB.DrawBar(X+1, Y+1, X2-1, Y2-1);
  CB.SetFillStyle(1, 15);
  CB.DrawBar(X+2, Y+2, X2-2, Y2-20);
  CB.SetFillStyle(1, 0);
  CB.DrawBar(X+2, Y2-18, X2-2, Y2-2);
End;

Procedure RenderButtonUp(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Begin
  CB.SetFillStyle(1, 15);
  CB.DrawBar(X, Y, X2, Y2);
  CB.SetFillStyle(1, 7);
  CB.DrawBar(X+4, Y+4, X2-4, Y2-4);
  CB.SetColor(8);
  CB.DrawLine(X, Y2, X2, Y2);
  CB.DrawLine(X+1, Y2-1, X2, Y2-1);
  CB.DrawLine(X+2, Y2-2, X2, Y2-2);
  CB.DrawLine(X+3, Y2-3, X2, Y2-3);
  CB.DrawLine(X2, Y, X2, Y2-4);
  CB.DrawLine(X2-1, Y+1, X2-1, Y2-4);
  CB.DrawLine(X2-2, Y+2, X2-2, Y2-4);
  CB.DrawLine(X2-3, Y+3, X2-3, Y2-4);
End;

Procedure RenderButtonDown(X, Y, X2, Y2: Integer; var CB: TWizDrawCallbacks);
Begin
  RenderButtonUp(X, Y, X2, Y2, CB);
  CB.SetColor(15);
  CB.DrawRect(X+5, Y+5, X2-5, Y2-5);
End;

Function RenderWidget(const Name: String; X, Y, X2, Y2: Integer;
  var CB: TWizDrawCallbacks): Boolean;
Var
  N: String;
  I: Integer;
Begin
  Result := True;
  N := '';
  For I := 1 to Length(Name) Do
    N := N + UpCase(Name[I]);

  If N = 'BOX' Then RenderBox(X, Y, X2, Y2, CB)
  Else If N = 'WINDOW' Then RenderWindow(X, Y, X2, Y2, CB)
  Else If N = 'FRAME' Then RenderFrame(X, Y, X2, Y2, CB)
  Else If N = 'DIALOG' Then RenderDialog(X, Y, X2, Y2, CB)
  Else If N = 'BUTTONUP' Then RenderButtonUp(X, Y, X2, Y2, CB)
  Else If N = 'BUTTONDOWN' Then RenderButtonDown(X, Y, X2, Y2, CB)
  Else Result := False;
End;

End.
