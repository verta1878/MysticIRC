{$MODE DELPHI}
// m_mouse.pas — Cross-platform text-mode mouse support
// GPLv3 — Part of Mystic BBS / fpc264irc

Unit m_Mouse;

Interface

Type
  TMouseButton = (mbNone, mbLeft, mbRight, mbMiddle);
  TMouseAction = (maMove, maDown, maUp, maScroll);

  TTextMouseEvent = Record
    X       : Word;
    Y       : Word;
    Button  : TMouseButton;
    Action  : TMouseAction;
    ScrollY : SmallInt;
  End;

Function  TextMouseInit      : Boolean;
Procedure TextMouseDone;
Function  TextMousePoll      (Var Event: TTextMouseEvent) : Boolean;
Function  TextMouseSupported : Boolean;
Procedure TextMouseShow;
Procedure TextMouseHide;

Implementation

{$IFDEF WINDOWS}
Uses Windows;
Const ENABLE_QUICK_EDIT_MODE = $0040;
{$ENDIF}
{$IFDEF UNIX}
Uses BaseUnix;
{$ENDIF}
{$IFDEF GO32V2}
Uses Dos;
{$ENDIF}
{$IFDEF OS2}
Uses MouCalls;
{$ENDIF}

Var
  MouseActive  : Boolean = False;
  MouseVisible : Boolean = False;

Function StrVal (S: String) : Integer;
Var Code, V : Integer;
Begin
  System.Val(S, V, Code);
  If Code <> 0 Then V := 0;
  Result := V;
End;

{$IFDEF UNIX}
Function TextMouseInit : Boolean;
Begin
  Write(#27'[?1000h'#27'[?1002h'#27'[?1006h');
  MouseActive := True;
  Result := True;
End;

Procedure TextMouseDone;
Begin
  If Not MouseActive Then Exit;
  Write(#27'[?1006l'#27'[?1002l'#27'[?1000l');
  MouseActive := False;
End;

Function TextMousePoll (Var Event: TTextMouseEvent) : Boolean;
Var
  Ch    : Char;
  Btn   : Integer;
  Buf   : String;
  Parts : Array[0..2] Of Integer;
  Idx   : Integer;
  Press : Boolean;
Begin
  Result := False;
  If Not MouseActive Then Exit;
  Buf := ''; Idx := 0;
  Parts[0] := 0; Parts[1] := 0; Parts[2] := 0;
  Repeat
    If fpRead(0, @Ch, 1) <> 1 Then Exit;
    If (Ch = 'M') Or (Ch = 'm') Then Begin
      Press := (Ch = 'M');
      If Idx < 3 Then Parts[Idx] := StrVal(Buf);
      Break;
    End Else If Ch = ';' Then Begin
      If Idx < 3 Then Parts[Idx] := StrVal(Buf);
      Inc(Idx); Buf := '';
    End Else
      Buf := Buf + Ch;
  Until False;
  Btn := Parts[0]; Event.X := Parts[1]; Event.Y := Parts[2]; Event.ScrollY := 0;
  Case Btn And 3 Of 0: Event.Button := mbLeft; 1: Event.Button := mbMiddle;
    2: Event.Button := mbRight; Else Event.Button := mbNone; End;
  If (Btn And 64) <> 0 Then Begin
    Event.Action := maScroll;
    If (Btn And 1) = 0 Then Event.ScrollY := -1 Else Event.ScrollY := 1;
  End Else If (Btn And 32) <> 0 Then Event.Action := maMove
  Else If Press Then Event.Action := maDown
  Else Event.Action := maUp;
  Result := True;
End;

Function TextMouseSupported : Boolean; Begin Result := True; End;
Procedure TextMouseShow; Begin MouseVisible := True; End;
Procedure TextMouseHide; Begin MouseVisible := False; End;
{$ENDIF}

{$IFDEF WINDOWS}
Var
  OldConsoleMode : DWord;
  ConsoleInput   : THandle;

Function TextMouseInit : Boolean;
Var Mode : DWord;
Begin
  Result := False;
  ConsoleInput := GetStdHandle(STD_INPUT_HANDLE);
  If ConsoleInput = INVALID_HANDLE_VALUE Then Exit;
  GetConsoleMode(ConsoleInput, OldConsoleMode);
  Mode := (OldConsoleMode Or ENABLE_MOUSE_INPUT) And (Not ENABLE_QUICK_EDIT_MODE);
  SetConsoleMode(ConsoleInput, Mode);
  MouseActive := True; Result := True;
End;

Procedure TextMouseDone;
Begin
  If Not MouseActive Then Exit;
  SetConsoleMode(ConsoleInput, OldConsoleMode);
  MouseActive := False;
End;

Function TextMousePoll (Var Event: TTextMouseEvent) : Boolean;
Var IR : TInputRecord; Count : DWord;
Begin
  Result := False;
  If Not MouseActive Then Exit;
  While PeekConsoleInput(ConsoleInput, IR, 1, Count) And (Count > 0) Do Begin
    ReadConsoleInput(ConsoleInput, IR, 1, Count);
    If IR.EventType = _MOUSE_EVENT Then Begin
      Event.X := IR.Event.MouseEvent.dwMousePosition.X + 1;
      Event.Y := IR.Event.MouseEvent.dwMousePosition.Y + 1;
      Event.ScrollY := 0;
      If (IR.Event.MouseEvent.dwButtonState And FROM_LEFT_1ST_BUTTON_PRESSED) <> 0 Then
        Event.Button := mbLeft
      Else If (IR.Event.MouseEvent.dwButtonState And RIGHTMOST_BUTTON_PRESSED) <> 0 Then
        Event.Button := mbRight
      Else Event.Button := mbNone;
      If IR.Event.MouseEvent.dwEventFlags = 0 Then
        Event.Action := maDown
      Else If (IR.Event.MouseEvent.dwEventFlags And 1) <> 0 Then
        Event.Action := maMove
      Else If (IR.Event.MouseEvent.dwEventFlags And 4) <> 0 Then Begin
        Event.Action := maScroll;
        If SmallInt(HiWord(IR.Event.MouseEvent.dwButtonState)) > 0 Then
          Event.ScrollY := -1 Else Event.ScrollY := 1;
      End Else
        Event.Action := maUp;
      Result := True; Exit;
    End;
  End;
End;

Function TextMouseSupported : Boolean; Begin Result := True; End;
Procedure TextMouseShow; Begin MouseVisible := True; End;
Procedure TextMouseHide; Begin MouseVisible := False; End;
{$ENDIF}

{$IFDEF GO32V2}
Function TextMouseInit : Boolean;
Var Regs : Registers;
Begin
  Result := False; Regs.AX := $0000; Intr($33, Regs);
  If Regs.AX = $FFFF Then Begin MouseActive := True; Result := True; End;
End;

Procedure TextMouseDone; Begin MouseActive := False; End;

Function TextMousePoll (Var Event: TTextMouseEvent) : Boolean;
Var Regs : Registers;
Begin
  Result := False; If Not MouseActive Then Exit;
  Regs.AX := $0003; Intr($33, Regs);
  Event.X := (Regs.CX Div 8) + 1; Event.Y := (Regs.DX Div 8) + 1; Event.ScrollY := 0;
  If (Regs.BX And 1) <> 0 Then Event.Button := mbLeft
  Else If (Regs.BX And 2) <> 0 Then Event.Button := mbRight
  Else If (Regs.BX And 4) <> 0 Then Event.Button := mbMiddle
  Else Event.Button := mbNone;
  If Event.Button <> mbNone Then Event.Action := maDown Else Event.Action := maMove;
  Result := True;
End;

Function TextMouseSupported : Boolean;
Var Regs : Registers;
Begin Regs.AX := $0000; Intr($33, Regs); Result := (Regs.AX = $FFFF); End;

Procedure TextMouseShow;
Var Regs : Registers;
Begin If Not MouseActive Then Exit; MouseVisible := True; Regs.AX := $0001; Intr($33, Regs); End;

Procedure TextMouseHide;
Var Regs : Registers;
Begin If Not MouseActive Then Exit; MouseVisible := False; Regs.AX := $0002; Intr($33, Regs); End;
{$ENDIF}

{$IFDEF OS2}
Var
  MouHandle : Word;

Function TextMouseInit : Boolean;
Var Buttons : Word;
Begin
  Result := False;
  If MouOpen(Nil, MouHandle) <> 0 Then Exit;
  If MouGetNumButtons(Buttons, MouHandle) <> 0 Then Begin
    MouClose(MouHandle); Exit;
  End;
  MouseActive := True; Result := True;
End;

Procedure TextMouseDone;
Begin
  If Not MouseActive Then Exit;
  MouClose(MouHandle); MouseActive := False;
End;

Function TextMousePoll (Var Event: TTextMouseEvent) : Boolean;
Var MouEvent : TMouEventInfo; WaitFlag : Word;
Begin
  Result := False;
  If Not MouseActive Then Exit;
  WaitFlag := MOU_NOWAIT;
  If MouReadEventQue(MouEvent, WaitFlag, MouHandle) <> 0 Then Exit;
  If MouEvent.fs = 0 Then Exit;
  Event.X := MouEvent.Col + 1; Event.Y := MouEvent.Row + 1; Event.ScrollY := 0;
  If (MouEvent.fs And MOUSE_BN1_DOWN) <> 0 Then Event.Button := mbLeft
  Else If (MouEvent.fs And MOUSE_BN2_DOWN) <> 0 Then Event.Button := mbRight
  Else If (MouEvent.fs And MOUSE_BN3_DOWN) <> 0 Then Event.Button := mbMiddle
  Else Event.Button := mbNone;
  If (MouEvent.fs And (MOUSE_BN1_DOWN Or MOUSE_BN2_DOWN Or MOUSE_BN3_DOWN)) <> 0 Then
    Event.Action := maDown
  Else If (MouEvent.fs And MOUSE_MOTION) <> 0 Then Event.Action := maMove
  Else Event.Action := maUp;
  Result := True;
End;

Function TextMouseSupported : Boolean;
Var Handle, Buttons : Word;
Begin
  Result := False;
  If MouOpen(Nil, Handle) = 0 Then Begin
    Result := (MouGetNumButtons(Buttons, Handle) = 0) And (Buttons > 0);
    MouClose(Handle);
  End;
End;

Procedure TextMouseShow;
Begin
  If Not MouseActive Then Exit;
  MouseVisible := True; MouDrawPtr(MouHandle);
End;

Procedure TextMouseHide;
Var NoPtrRect : TNoPtrRect;
Begin
  If Not MouseActive Then Exit;
  MouseVisible := False;
  NoPtrRect.Row := 0; NoPtrRect.Col := 0;
  NoPtrRect.cRow := 9999; NoPtrRect.cCol := 9999;
  MouRemovePtr(NoPtrRect, MouHandle);
End;
{$ENDIF}

End.
