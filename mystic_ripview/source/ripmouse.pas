{$MODE DELPHI}
{$H-}
Unit RIPMouse;
{
  RIPscrip Mouse Field and Button Interactive Layer
  Ported from ripscr.pas TRIPEngine.

  Manages mouse regions, button click/hotkey/tab navigation, focus,
  and InvertRegion for visual feedback.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}
Interface

Uses RIPEngine;

Const
  RIP_MAX_MOUSE = 128;

Type
  TRIPMouseField = Record
    Active      : Boolean;
    X0, Y0      : Integer;
    X1, Y1      : Integer;
    HostCmd     : String[80];
    Text        : String[80];
    HotKey      : Char;
    IsButton    : Boolean;
    IsRadio     : Boolean;
    IsCheckbox  : Boolean;
    Invert      : Boolean;
    Selected    : Boolean;
    GroupID     : Byte;
    TabIndex    : Integer;
    IconFile    : String[12];
    HotIconFile : String[12];
  End;

Function  AddMouseField(X0, Y0, X1, Y1: Integer; HostCmd, Text: String): Integer;
Procedure KillMouseField(Index: Integer);
Procedure KillAllMouseFields;
Function  FindMouseField(X, Y: Integer): Integer;
Function  GetMouseCount: Integer;
Function  GetMouseField(Index: Integer): TRIPMouseField;
Function  FindButtonByHotkey(Key: Char): Integer;
Function  GetNextTabField: Integer;
Function  GetPrevTabField: Integer;
Procedure FocusField(Index: Integer);
Procedure UnfocusField;
Function  GetFocusedField: Integer;
Procedure InvertRegion(X0, Y0, X1, Y1: Integer);
Procedure ClickButton(Index: Integer);

Implementation

Var
  MouseFields  : Array[1..RIP_MAX_MOUSE] Of TRIPMouseField;
  MouseCount   : Integer;
  FocusedIdx   : Integer;
  HotKeysOn    : Boolean;
  TabOn        : Boolean;

Function AddMouseField(X0, Y0, X1, Y1: Integer; HostCmd, Text: String): Integer;
Begin
  Result := 0;
  If MouseCount >= RIP_MAX_MOUSE Then Exit;
  Inc(MouseCount);
  FillChar(MouseFields[MouseCount], SizeOf(TRIPMouseField), 0);
  MouseFields[MouseCount].Active  := True;
  MouseFields[MouseCount].X0     := X0;
  MouseFields[MouseCount].Y0     := Y0;
  MouseFields[MouseCount].X1     := X1;
  MouseFields[MouseCount].Y1     := Y1;
  MouseFields[MouseCount].HostCmd := HostCmd;
  MouseFields[MouseCount].Text   := Text;
  Result := MouseCount;
End;

Procedure KillMouseField(Index: Integer);
Begin
  If (Index >= 1) And (Index <= RIP_MAX_MOUSE) Then
    FillChar(MouseFields[Index], SizeOf(TRIPMouseField), 0);
End;

Procedure KillAllMouseFields;
Var I: Integer;
Begin
  MouseCount := 0;
  FocusedIdx := 0;
  For I := 1 To RIP_MAX_MOUSE Do
    FillChar(MouseFields[I], SizeOf(TRIPMouseField), 0);
End;

Function FindMouseField(X, Y: Integer): Integer;
Var I: Integer;
Begin
  Result := 0;
  For I := MouseCount DownTo 1 Do
    If MouseFields[I].Active And
       (X >= MouseFields[I].X0) And (X <= MouseFields[I].X1) And
       (Y >= MouseFields[I].Y0) And (Y <= MouseFields[I].Y1) Then Begin
      Result := I;
      Exit;
    End;
End;

Function GetMouseCount: Integer;
Begin
  Result := MouseCount;
End;

Function GetMouseField(Index: Integer): TRIPMouseField;
Begin
  If (Index >= 1) And (Index <= RIP_MAX_MOUSE) Then
    Result := MouseFields[Index]
  Else
    FillChar(Result, SizeOf(Result), 0);
End;

Procedure InvertRegion(X0, Y0, X1, Y1: Integer);
Var X, Y: Integer;
Begin
  For Y := ClipY(Y0) To ClipY(Y1) Do
    For X := ClipX(X0) To ClipX(X1) Do
      If (X >= 0) And (X < RIP_WIDTH) And (Y >= 0) And (Y < RIP_HEIGHT) Then
        Canvas.Pixels^[X, Y] := Canvas.Pixels^[X, Y] Xor $0F;
End;

Procedure ClickButton(Index: Integer);
Var I: Integer; MF: TRIPMouseField;
Begin
  If (Index < 1) Or (Index > MouseCount) Then Exit;
  If Not MouseFields[Index].Active Then Exit;
  If Not MouseFields[Index].IsButton Then Exit;
  MF := MouseFields[Index];

  { Radio button: deselect others in same group }
  If MF.IsRadio Then Begin
    For I := 1 To MouseCount Do
      If MouseFields[I].Active And MouseFields[I].IsRadio And
         (MouseFields[I].GroupID = MF.GroupID) And (I <> Index) Then
        If MouseFields[I].Selected Then Begin
          MouseFields[I].Selected := False;
          InvertRegion(MouseFields[I].X0, MouseFields[I].Y0,
                       MouseFields[I].X1, MouseFields[I].Y1);
        End;
    MouseFields[Index].Selected := True;
    InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
  End;

  { Checkbox: toggle }
  If MF.IsCheckbox Then Begin
    MouseFields[Index].Selected := Not MouseFields[Index].Selected;
    InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
  End;

  { Plain button with invert }
  If (Not MF.IsRadio) And (Not MF.IsCheckbox) And MF.Invert Then
    InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
End;

Function FindButtonByHotkey(Key: Char): Integer;
Var I: Integer; UKey: Char;
Begin
  Result := 0;
  If Not HotKeysOn Then Exit;
  UKey := Key;
  If (UKey >= 'a') And (UKey <= 'z') Then
    UKey := Chr(Ord(UKey) - 32);
  For I := 1 To MouseCount Do
    If MouseFields[I].Active And MouseFields[I].IsButton And
       (MouseFields[I].HotKey <> #0) Then Begin
      If MouseFields[I].HotKey = UKey Then Begin Result := I; Exit; End;
      If (MouseFields[I].HotKey >= 'a') And (MouseFields[I].HotKey <= 'z') Then
        If Chr(Ord(MouseFields[I].HotKey) - 32) = UKey Then Begin Result := I; Exit; End;
    End;
End;

Function GetNextTabField: Integer;
Var I, Start: Integer;
Begin
  Result := 0;
  If Not TabOn Then Exit;
  If MouseCount = 0 Then Exit;
  If FocusedIdx = 0 Then Start := 1 Else Start := FocusedIdx + 1;
  For I := Start To MouseCount Do
    If MouseFields[I].Active And (MouseFields[I].TabIndex > 0) Then Begin Result := I; Exit; End;
  For I := 1 To Start - 1 Do
    If MouseFields[I].Active And (MouseFields[I].TabIndex > 0) Then Begin Result := I; Exit; End;
End;

Function GetPrevTabField: Integer;
Var I, Start: Integer;
Begin
  Result := 0;
  If Not TabOn Then Exit;
  If MouseCount = 0 Then Exit;
  If FocusedIdx <= 1 Then Start := MouseCount Else Start := FocusedIdx - 1;
  For I := Start DownTo 1 Do
    If MouseFields[I].Active And (MouseFields[I].TabIndex > 0) Then Begin Result := I; Exit; End;
  For I := MouseCount DownTo Start + 1 Do
    If MouseFields[I].Active And (MouseFields[I].TabIndex > 0) Then Begin Result := I; Exit; End;
End;

Procedure FocusField(Index: Integer);
Begin
  If (Index < 1) Or (Index > MouseCount) Then Exit;
  If Not MouseFields[Index].Active Then Exit;
  UnfocusField;
  FocusedIdx := Index;
  InvertRegion(MouseFields[Index].X0, MouseFields[Index].Y0,
               MouseFields[Index].X1, MouseFields[Index].Y1);
End;

Procedure UnfocusField;
Begin
  If (FocusedIdx >= 1) And (FocusedIdx <= MouseCount) And
     MouseFields[FocusedIdx].Active Then
    InvertRegion(MouseFields[FocusedIdx].X0, MouseFields[FocusedIdx].Y0,
                 MouseFields[FocusedIdx].X1, MouseFields[FocusedIdx].Y1);
  FocusedIdx := 0;
End;

Function GetFocusedField: Integer;
Begin
  Result := FocusedIdx;
End;

Initialization
  MouseCount := 0;
  FocusedIdx := 0;
  HotKeysOn  := True;
  TabOn      := True;
  FillChar(MouseFields, SizeOf(MouseFields), 0);

End.
