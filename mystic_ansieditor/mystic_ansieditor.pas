Program mystic_ansieditor;

// ====================================================================
// mystic_ansieditor — Standalone ANSI art editor for Mystic BBS
// ====================================================================
//
// Direct keyboard input. No BBS I/O layer.
// Draw mode with color palette, character placement, block ops.
//
// Copyright (C) 1997-2013 James Coyle
// IRC Fork (C) 2025-2026 verta1878, sysop/0, evga, kiddo, wrench
// GPLv3
// ====================================================================

{$I M_OPS.PAS}

Uses
  {$IFDEF WINDOWS}
    Windows,
    m_Input_Windows,
    m_Output_Windows;
  {$ENDIF}
  {$IFDEF UNIX}
    m_Input_Linux,
    m_Output_Linux;
  {$ENDIF}

Const
  CANVAS_W = 80;
  CANVAS_H = 23;
  STATUS_Y = 24;
  HELP_Y   = 25;

Function IntToStr(N: LongInt): String;
Var S: String;
Begin Str(N, S); IntToStr := S; End;

Function HexByte(B: Byte): String;
Const HX: String = '0123456789ABCDEF';
Begin HexByte := HX[(B Shr 4) + 1] + HX[(B And 15) + 1]; End;

Type
  TCell = Record
    Ch   : Char;
    Attr : Byte;
  End;

  TAnsiEditor = Object
    Canvas    : Array[1..CANVAS_H, 1..CANVAS_W] of TCell;
    CurX, CurY : Integer;
    CurAttr   : Byte;
    CurChar   : Char;
    FGColor   : Byte;
    BGColor   : Byte;
    InsMode   : Boolean;
    DrawMode  : Boolean;
    Modified  : Boolean;
    Done      : Boolean;
    FileName  : String;
    Console   : {$IFDEF WINDOWS} TOutputWindows {$ELSE} TOutputLinux {$ENDIF};
    Keyboard  : {$IFDEF WINDOWS} TInputWindows {$ELSE} TInputLinux {$ENDIF};

    Procedure Init;
    Procedure ClearCanvas;
    Procedure DrawScreen;
    Procedure DrawCell(X, Y: Integer);
    Procedure DrawStatus;
    Procedure DrawColorBar;
    Procedure MoveCursor;
    Procedure PlaceChar(Ch: Char);
    Procedure ProcessKey;
    Procedure ColorPalette;
    Procedure LoadFile(FN: String);
    Procedure SaveFile;
    Procedure Run;
    Procedure Cleanup;
  End;

Procedure TAnsiEditor.Init;
Begin
  Console  := {$IFDEF WINDOWS} TOutputWindows.Create(True) {$ELSE} TOutputLinux.Create(True) {$ENDIF};
  Keyboard := {$IFDEF WINDOWS} TInputWindows.Create {$ELSE} TInputLinux.Create {$ENDIF};

  CurX     := 1;
  CurY     := 1;
  FGColor  := 7;
  BGColor  := 0;
  CurAttr  := 7;
  CurChar  := #219;  { solid block }
  InsMode  := True;
  DrawMode := False;
  Modified := False;
  Done     := False;
  FileName := '';

  ClearCanvas;
End;

Procedure TAnsiEditor.ClearCanvas;
Var X, Y: Integer;
Begin
  For Y := 1 to CANVAS_H Do
    For X := 1 to CANVAS_W Do Begin
      Canvas[Y, X].Ch   := ' ';
      Canvas[Y, X].Attr := 7;
    End;
End;

Procedure TAnsiEditor.DrawCell(X, Y: Integer);
Begin
  Console.WriteXY(X, Y, Canvas[Y, X].Attr, Canvas[Y, X].Ch);
End;

Procedure TAnsiEditor.DrawScreen;
Var X, Y: Integer;
Begin
  For Y := 1 to CANVAS_H Do
    For X := 1 to CANVAS_W Do
      DrawCell(X, Y);

  DrawStatus;
  DrawColorBar;
End;

Procedure TAnsiEditor.DrawStatus;
Var
  Status: String;
  ModeStr: String;
Begin
  If DrawMode Then ModeStr := 'DRAW' Else ModeStr := 'MOVE';

  Status := ' X:' + IntToStr(CurX) +
            ' Y:' + IntToStr(CurY) +
            ' Attr:' + HexByte(CurAttr) +
            ' FG:' + IntToStr(FGColor) +
            ' BG:' + IntToStr(BGColor) +
            ' Chr:' + IntToStr(Ord(CurChar)) +
            ' ' + ModeStr +
            '  ' + FileName;

  While Length(Status) < CANVAS_W Do Status := Status + ' ';
  Status := Copy(Status, 1, CANVAS_W);

  Console.WriteXY(1, STATUS_Y, 112, Status);
End;

Procedure TAnsiEditor.DrawColorBar;
Var
  I: Integer;
  S: String;
Begin
  S := ' ';
  Console.WriteXY(1, HELP_Y, 112, ' F1=Color F2=Char F3=Load F4=Save F5=Draw F9=Clear  ESC=Quit               ');

  { Show current color sample }
  Console.WriteXY(72, HELP_Y, CurAttr, ' Aa ');
  Console.WriteXY(76, HELP_Y, CurAttr, CurChar + CurChar + CurChar + CurChar);
End;

Procedure TAnsiEditor.MoveCursor;
Begin
  Console.CursorXY(CurX, CurY);
End;

Procedure TAnsiEditor.PlaceChar(Ch: Char);
Begin
  Canvas[CurY, CurX].Ch   := Ch;
  Canvas[CurY, CurX].Attr := CurAttr;
  DrawCell(CurX, CurY);
  Modified := True;

  If CurX < CANVAS_W Then
    Inc(CurX)
  Else If CurY < CANVAS_H Then Begin
    CurX := 1;
    Inc(CurY);
  End;
End;

Procedure TAnsiEditor.ColorPalette;
Var
  Ch: Char;
  I, Row, Col: Integer;
  OldX, OldY: Integer;
  PalDone: Boolean;
  SelFG, SelBG: Byte;
Begin
  OldX := CurX;
  OldY := CurY;
  SelFG := FGColor;
  SelBG := BGColor;
  PalDone := False;

  { Draw palette window }
  Console.WriteXY(20, 4, 112, '+-- Select Color -------------------+');
  Console.WriteXY(20, 5, 112, '|                                   |');
  Console.WriteXY(20, 6, 112, '| Foreground:                       |');

  { FG colors 0-15 }
  For I := 0 to 15 Do
    Console.WriteXY(34 + I, 6, I, Chr(219));

  Console.WriteXY(20, 7, 112, '|                                   |');
  Console.WriteXY(20, 8, 112, '| Background:                       |');

  { BG colors 0-7 }
  For I := 0 to 7 Do
    Console.WriteXY(34 + I, 8, I * 16 + 15, Chr(219));

  Console.WriteXY(20, 9, 112, '|                                   |');
  Console.WriteXY(20, 10, 112, '| Sample:                           |');
  Console.WriteXY(20, 11, 112, '|                                   |');
  Console.WriteXY(20, 12, 112, '| Arrow keys=Select  Enter=OK       |');
  Console.WriteXY(20, 13, 112, '| 0-9/A-F=FG  Shift+0-7=BG         |');
  Console.WriteXY(20, 14, 112, '| ESC=Cancel                        |');
  Console.WriteXY(20, 15, 112, '+-----------------------------------+');

  Repeat
    { Show sample }
    CurAttr := SelFG + (SelBG * 16);
    Console.WriteXY(34, 10, CurAttr, ' Sample Text ');

    { Show selection markers }
    Console.WriteXY(34 + SelFG, 7, 112, '^');
    Console.WriteXY(34 + SelBG, 9, 112, '^');

    Console.BufFlush;

    If Keyboard.KeyWait(100) Then Begin
      Ch := Keyboard.ReadKey;

      If Ch = #0 Then Begin
        Ch := Keyboard.ReadKey;
        Case Ch of
          #75: If SelFG > 0 Then Begin  { Left }
                 Console.WriteXY(34 + SelFG, 7, 112, ' ');
                 Dec(SelFG);
               End;
          #77: If SelFG < 15 Then Begin { Right }
                 Console.WriteXY(34 + SelFG, 7, 112, ' ');
                 Inc(SelFG);
               End;
          #72: If SelBG > 0 Then Begin  { Up = BG down }
                 Console.WriteXY(34 + SelBG, 9, 112, ' ');
                 Dec(SelBG);
               End;
          #80: If SelBG < 7 Then Begin  { Down = BG up }
                 Console.WriteXY(34 + SelBG, 9, 112, ' ');
                 Inc(SelBG);
               End;
        End;
      End Else
        Case Ch of
          #13: Begin FGColor := SelFG; BGColor := SelBG; PalDone := True; End;
          #27: Begin CurAttr := FGColor + (BGColor * 16); PalDone := True; End;
          '0'..'9': Begin
                      Console.WriteXY(34 + SelFG, 7, 112, ' ');
                      SelFG := Ord(Ch) - Ord('0');
                    End;
          'a'..'f': Begin
                      Console.WriteXY(34 + SelFG, 7, 112, ' ');
                      SelFG := 10 + Ord(Ch) - Ord('a');
                    End;
          'A'..'F': Begin
                      Console.WriteXY(34 + SelFG, 7, 112, ' ');
                      SelFG := 10 + Ord(Ch) - Ord('A');
                    End;
        End;
    End;
  Until PalDone;

  CurAttr := FGColor + (BGColor * 16);
  CurX := OldX;
  CurY := OldY;
  DrawScreen;
End;

Procedure TAnsiEditor.LoadFile(FN: String);
Var
  F: File;
  Buf: Array[0..4095] of Byte;
  N, I: Integer;
  PX, PY: Integer;
  InEsc: Boolean;
  EscBuf: String;
  TmpFG, TmpBG: Byte;
  TmpAttr: Byte;
Begin
  FileName := FN;
  ClearCanvas;

  Assign(F, FN);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  PX := 1; PY := 1;
  InEsc := False;
  EscBuf := '';
  TmpAttr := 7;

  Repeat
    BlockRead(F, Buf, SizeOf(Buf), N);
    For I := 0 to N - 1 Do Begin
      If InEsc Then Begin
        EscBuf := EscBuf + Chr(Buf[I]);
        If Chr(Buf[I]) in ['A'..'Z', 'a'..'z'] Then Begin
          { Parse ANSI sequence — simplified SGR only }
          If Chr(Buf[I]) = 'm' Then Begin
            { Parse color codes from EscBuf }
            { This is simplified — full parser would handle all SGR }
            TmpAttr := 7; { Reset to default on any SGR for now }
          End;
          InEsc := False;
          EscBuf := '';
        End;
      End Else If Buf[I] = 27 Then Begin
        InEsc := True;
        EscBuf := '';
      End Else If Buf[I] = 13 Then Begin
        { CR — ignore }
      End Else If Buf[I] = 10 Then Begin
        { LF — next line }
        PX := 1;
        Inc(PY);
        If PY > CANVAS_H Then Break;
      End Else Begin
        If (PX >= 1) And (PX <= CANVAS_W) And (PY >= 1) And (PY <= CANVAS_H) Then Begin
          Canvas[PY, PX].Ch := Chr(Buf[I]);
          Canvas[PY, PX].Attr := TmpAttr;
        End;
        Inc(PX);
      End;
    End;
  Until (N = 0) Or (PY > CANVAS_H);

  Close(F);
  Modified := False;
End;

Procedure TAnsiEditor.SaveFile;
Var
  F: Text;
  X, Y: Integer;
  LastAttr: Byte;
  Line: String;
Begin
  If FileName = '' Then Exit;

  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;

  LastAttr := 7;

  For Y := 1 to CANVAS_H Do Begin
    Line := '';
    For X := 1 to CANVAS_W Do Begin
      If Canvas[Y, X].Attr <> LastAttr Then Begin
        { Write ANSI color escape }
        LastAttr := Canvas[Y, X].Attr;
        Line := Line + #27 + '[0';
        If (LastAttr And 8) <> 0 Then Line := Line + ';1';
        Line := Line + ';' + IntToStr(30 + (LastAttr And 7));
        Line := Line + ';' + IntToStr(40 + ((LastAttr Shr 4) And 7));
        Line := Line + 'm';
      End;
      Line := Line + Canvas[Y, X].Ch;
    End;
    { Trim trailing spaces }
    While (Length(Line) > 0) And (Line[Length(Line)] = ' ') Do
      Dec(Line[0]);
    WriteLn(F, Line);
  End;

  Close(F);
  Modified := False;
  DrawStatus;
End;

Procedure TAnsiEditor.ProcessKey;
Var
  Ch: Char;
Begin
  If Not Keyboard.KeyWait(100) Then Exit;

  Ch := Keyboard.ReadKey;

  If Ch = #0 Then Begin
    Ch := Keyboard.ReadKey;
    Case Ch of
      #72: If CurY > 1 Then Begin  { Up }
             If DrawMode Then PlaceChar(CurChar);
             Dec(CurY);
           End;
      #80: If CurY < CANVAS_H Then Begin { Down }
             If DrawMode Then PlaceChar(CurChar);
             Inc(CurY);
           End;
      #75: If CurX > 1 Then Begin  { Left }
             If DrawMode Then PlaceChar(CurChar);
             Dec(CurX);
           End;
      #77: If CurX < CANVAS_W Then Begin { Right }
             If DrawMode Then PlaceChar(CurChar);
             Inc(CurX);
           End;
      #71: CurX := 1;              { Home }
      #79: CurX := CANVAS_W;       { End }
      #73: CurY := 1;              { PgUp }
      #81: CurY := CANVAS_H;       { PgDn }
      #83: Begin                    { Delete }
             Canvas[CurY, CurX].Ch := ' ';
             Canvas[CurY, CurX].Attr := CurAttr;
             DrawCell(CurX, CurY);
             Modified := True;
           End;
      #59: ColorPalette;           { F1 = color }
      #60: Begin                    { F2 = char select }
             Console.WriteXY(1, HELP_Y, 112, ' Enter character (0-255): ');
             Console.BufFlush;
             { Simple: cycle through block chars }
             Case CurChar of
               #219: CurChar := #220;
               #220: CurChar := #221;
               #221: CurChar := #222;
               #222: CurChar := #223;
               #223: CurChar := #176;
               #176: CurChar := #177;
               #177: CurChar := #178;
             Else
               CurChar := #219;
             End;
             DrawStatus;
             DrawColorBar;
           End;
      #61: Begin                    { F3 = load }
             { Reload current file }
             If FileName <> '' Then Begin
               LoadFile(FileName);
               DrawScreen;
             End;
           End;
      #62: SaveFile;               { F4 = save }
      #63: Begin                    { F5 = toggle draw }
             DrawMode := Not DrawMode;
             DrawStatus;
           End;
      #67: Begin                    { F9 = clear }
             ClearCanvas;
             DrawScreen;
             Modified := True;
           End;
    End;
  End Else
    Case Ch of
      #27: Done := True;           { ESC }
      #13: Begin                    { Enter }
             CurX := 1;
             If CurY < CANVAS_H Then Inc(CurY);
           End;
      #8:  Begin                    { Backspace }
             If CurX > 1 Then Begin
               Dec(CurX);
               Canvas[CurY, CurX].Ch := ' ';
               Canvas[CurY, CurX].Attr := CurAttr;
               DrawCell(CurX, CurY);
               Modified := True;
             End;
           End;
      #9:  Begin                    { Tab }
             CurX := ((CurX - 1) Div 8 + 1) * 8 + 1;
             If CurX > CANVAS_W Then CurX := CANVAS_W;
           End;
      ' '..#255: PlaceChar(Ch);     { Printable chars }
    End;

  DrawStatus;
End;

Procedure TAnsiEditor.Run;
Begin
  Console.SetWindow(1, 1, 80, 25, False);
  Console.TextAttr := 7;
  Console.ClearScreen;

  DrawScreen;

  Repeat
    MoveCursor;
    Console.BufFlush;
    ProcessKey;
  Until Done;
End;

Procedure TAnsiEditor.Cleanup;
Begin
  Console.TextAttr := 7;
  Console.ClearScreen;
  Console.BufFlush;
  Console.Free;
  Keyboard.Free;
End;

Var
  Editor: TAnsiEditor;
Begin
  Editor.Init;

  If ParamCount >= 1 Then
    Editor.LoadFile(ParamStr(1));

  If Editor.FileName = '' Then Begin
    Editor.FileName := 'untitled.ans';
  End;

  Editor.Run;
  Editor.Cleanup;
End.
