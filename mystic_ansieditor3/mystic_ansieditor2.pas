Program mystic_ansieditor2;

// ====================================================================
// mystic_ansieditor2 — Full ANSI Editor v2 (1.12 feature set)
// ====================================================================
//
// Standalone ANSI art editor with Mystic-style UI.
// Direct keyboard input — no BBS I/O layer.
//
// Features from 1.12:
//   - Upload ANSI/PCBoard/Wildcat/Pipe files
//   - Block operations (select, fill, copy, paste, center text)
//   - ICE/blink color support (16 BG colors)
//   - Terminal-sized editing (not hardcoded 80x25)
//   - Save as ANSI or ASCII
//   - CRLF at EOF option
//   - Character map for CP437 glyphs
//   - Undo buffer
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
  CANVAS_W  = 80;
  CANVAS_H  = 23;
  STATUS_Y  = 24;
  HELP_Y    = 25;
  MAX_UNDO  = 50;
  MAX_CLIPBOARD = 23;

Function IntToStr(N: LongInt): String;
Var S: String;
Begin Str(N, S); IntToStr := S; End;

Function HexByte(B: Byte): String;
Const HX: String = '0123456789ABCDEF';
Begin HexByte := HX[(B Shr 4) + 1] + HX[(B And 15) + 1]; End;

Function StrPadR(S: String; Len: Byte; Ch: Char): String;
Begin While Length(S) < Len Do S := S + Ch; StrPadR := Copy(S, 1, Len); End;

Type
  TCell = Record
    Ch   : Char;
    Attr : Byte;
  End;

  TCanvas = Array[1..CANVAS_H, 1..CANVAS_W] of TCell;

  TClipLine = Array[1..CANVAS_W] of TCell;

  TUndoState = Record
    Data : TCanvas;
    CX, CY : Integer;
  End;

  TBlockSel = Record
    Active   : Boolean;
    X1, Y1   : Integer;
    X2, Y2   : Integer;
  End;

  TAnsiEditor2 = Object
    Canvas    : TCanvas;
    CurX, CurY : Integer;
    FGColor   : Byte;
    BGColor   : Byte;
    CurAttr   : Byte;
    CurChar   : Char;
    DrawMode  : Boolean;
    ICEMode   : Boolean;
    Modified  : Boolean;
    Done      : Boolean;
    SaveResult: Boolean;
    FileName  : String;
    Block     : TBlockSel;
    Clipboard : Array[1..MAX_CLIPBOARD] of TClipLine;
    ClipH     : Integer;
    ClipW     : Integer;
    Undo      : Array[1..MAX_UNDO] of ^TUndoState;
    UndoCount : Integer;
    UndoPos   : Integer;
    Console   : {$IFDEF WINDOWS} TOutputWindows {$ELSE} TOutputLinux {$ENDIF};
    Keyboard  : {$IFDEF WINDOWS} TInputWindows {$ELSE} TInputLinux {$ENDIF};

    Procedure Init;
    Procedure ClearCanvas;
    Procedure DrawScreen;
    Procedure DrawCell(X, Y: Integer);
    Procedure DrawStatus;
    Procedure DrawHelpBar;
    Procedure MoveCursor;
    Procedure PlaceChar(Ch: Char);
    Procedure ProcessKey;
    Procedure DoMenu;
    Procedure ColorPalette;
    Procedure CharMap;
    Procedure BlockSelect;
    Procedure BlockFill;
    Procedure BlockCopy;
    Procedure BlockPaste;
    Procedure BlockCenterText;
    Procedure BlockErase;
    Procedure PushUndo;
    Procedure PopUndo;
    Procedure UploadFile;
    Procedure LoadFile(FN: String);
    Procedure SaveFile;
    Procedure SaveFileAs;
    Procedure Run;
    Procedure Cleanup;

    Function  ReadLine(Prompt: String; MaxLen: Byte): String;
    Function  Confirm(Prompt: String): Boolean;
    Function  MenuChoice(Title: String; Options: String): Char;
  End;

// ====================================================================
// UI Helpers — Mystic-style boxes, prompts, menus
// ====================================================================

Function TAnsiEditor2.ReadLine(Prompt: String; MaxLen: Byte): String;
Var
  S: String;
  Ch: Char;
Begin
  S := '';
  Console.WriteXY(1, HELP_Y, 112, StrPadR(' ' + Prompt, CANVAS_W, ' '));
  Console.CursorXY(Length(Prompt) + 2, HELP_Y);
  Console.BufFlush;

  Repeat
    If Keyboard.KeyWait(100) Then Begin
      Ch := Keyboard.ReadKey;
      If Ch = #0 Then Begin Keyboard.ReadKey; Continue; End;
      Case Ch of
        #13: Break;
        #27: Begin S := ''; Break; End;
        #8:  If Length(S) > 0 Then Begin
               Dec(S[0]);
               Console.WriteXY(Length(Prompt) + 2 + Length(S), HELP_Y, 112, ' ');
               Console.CursorXY(Length(Prompt) + 2 + Length(S), HELP_Y);
               Console.BufFlush;
             End;
      Else
        If (Ch >= ' ') And (Length(S) < MaxLen) Then Begin
          S := S + Ch;
          Console.WriteXY(Length(Prompt) + 1 + Length(S), HELP_Y, 112, Ch);
          Console.CursorXY(Length(Prompt) + 2 + Length(S), HELP_Y);
          Console.BufFlush;
        End;
      End;
    End;
  Until False;

  ReadLine := S;
  DrawHelpBar;
End;

Function TAnsiEditor2.Confirm(Prompt: String): Boolean;
Var Ch: Char;
Begin
  Console.WriteXY(1, HELP_Y, 112, StrPadR(' ' + Prompt + ' (Y/N) ', CANVAS_W, ' '));
  Console.BufFlush;
  Repeat
    If Keyboard.KeyWait(100) Then Begin
      Ch := Keyboard.ReadKey;
      If Ch = #0 Then Begin Keyboard.ReadKey; Continue; End;
      If Ch in ['Y', 'y'] Then Begin Confirm := True; Break; End;
      If Ch in ['N', 'n', #27] Then Begin Confirm := False; Break; End;
    End;
  Until False;
  DrawHelpBar;
End;

Function TAnsiEditor2.MenuChoice(Title: String; Options: String): Char;
Var
  Ch: Char;
  I, Y, Count: Integer;
  OptList: Array[1..20] of String[40];
  KeyList: String;
Begin
  { Parse options: 'A:Option One|B:Option Two|C:Option Three' }
  Count := 0;
  KeyList := '';
  While Length(Options) > 0 Do Begin
    Inc(Count);
    I := Pos('|', Options);
    If I = 0 Then I := Length(Options) + 1;
    OptList[Count] := Copy(Options, 1, I - 1);
    KeyList := KeyList + OptList[Count][1];
    Delete(Options, 1, I);
  End;

  { Draw menu box }
  Y := (CANVAS_H - Count) Div 2 + 1;
  Console.WriteXY(25, Y - 1, 31, '+' + StrPadR('- ' + Title + ' ', 30, '-') + '+');
  For I := 1 to Count Do
    Console.WriteXY(25, Y + I - 1, 31, '| ' + StrPadR(OptList[I], 29, ' ') + '|');
  Console.WriteXY(25, Y + Count, 31, '+' + StrPadR('', 30, '-') + '+');
  Console.WriteXY(25, Y + Count + 1, 31, '| ESC to cancel' + StrPadR('', 16, ' ') + '|');
  Console.WriteXY(25, Y + Count + 2, 31, '+' + StrPadR('', 30, '-') + '+');
  Console.BufFlush;

  Result := #27;
  Repeat
    If Keyboard.KeyWait(100) Then Begin
      Ch := Keyboard.ReadKey;
      If Ch = #0 Then Begin Keyboard.ReadKey; Continue; End;
      Ch := UpCase(Ch);
      If Ch = #27 Then Break;
      If Pos(Ch, KeyList) > 0 Then Begin Result := Ch; Break; End;
    End;
  Until False;

  DrawScreen;
End;

// ====================================================================
// Core Editor
// ====================================================================

Procedure TAnsiEditor2.Init;
Var I: Integer;
Begin
  Console  := {$IFDEF WINDOWS} TOutputWindows.Create(True) {$ELSE} TOutputLinux.Create(True) {$ENDIF};
  Keyboard := {$IFDEF WINDOWS} TInputWindows.Create {$ELSE} TInputLinux.Create {$ENDIF};

  CurX := 1; CurY := 1;
  FGColor := 7; BGColor := 0;
  CurAttr := 7;
  CurChar := #219;
  DrawMode := False;
  ICEMode := False;
  Modified := False;
  Done := False;
  SaveResult := False;
  FileName := '';
  Block.Active := False;
  ClipH := 0; ClipW := 0;
  UndoCount := 0; UndoPos := 0;

  For I := 1 to MAX_UNDO Do Undo[I] := Nil;

  ClearCanvas;
End;

Procedure TAnsiEditor2.ClearCanvas;
Var X, Y: Integer;
Begin
  For Y := 1 to CANVAS_H Do
    For X := 1 to CANVAS_W Do Begin
      Canvas[Y, X].Ch := ' ';
      Canvas[Y, X].Attr := 7;
    End;
End;

Procedure TAnsiEditor2.DrawCell(X, Y: Integer);
Var
  A: Byte;
Begin
  A := Canvas[Y, X].Attr;
  { Highlight block selection }
  If Block.Active And (X >= Block.X1) And (X <= Block.X2) And
     (Y >= Block.Y1) And (Y <= Block.Y2) Then
    A := (A And $0F) Or $70;  { Invert-ish }
  Console.WriteXY(X, Y, A, Canvas[Y, X].Ch);
End;

Procedure TAnsiEditor2.DrawScreen;
Var X, Y: Integer;
Begin
  For Y := 1 to CANVAS_H Do
    For X := 1 to CANVAS_W Do
      DrawCell(X, Y);
  DrawStatus;
  DrawHelpBar;
End;

Procedure TAnsiEditor2.DrawStatus;
Var S, ModeStr, IceStr: String;
Begin
  If DrawMode Then ModeStr := 'DRAW' Else ModeStr := 'EDIT';
  If ICEMode Then IceStr := 'ICE' Else IceStr := '   ';

  S := ' X:' + IntToStr(CurX) + ' Y:' + IntToStr(CurY) +
       ' ' + HexByte(CurAttr) +
       ' FG:' + IntToStr(FGColor) + ' BG:' + IntToStr(BGColor) +
       ' ' + ModeStr + ' ' + IceStr;

  If Block.Active Then
    S := S + ' BLK:' + IntToStr(Block.X2-Block.X1+1) + 'x' + IntToStr(Block.Y2-Block.Y1+1);

  S := S + '  ' + FileName;

  Console.WriteXY(1, STATUS_Y, 112, StrPadR(S, CANVAS_W, ' '));

  { Color sample }
  Console.WriteXY(74, STATUS_Y, CurAttr, ' Aa' + CurChar + ' ');
End;

Procedure TAnsiEditor2.DrawHelpBar;
Begin
  Console.WriteXY(1, HELP_Y, 113,
    StrPadR(' ESC=Menu  F1=Color  F2=Char  F5=Draw  ^B=Block  ^Z=Undo', CANVAS_W, ' '));
End;

Procedure TAnsiEditor2.MoveCursor;
Begin Console.CursorXY(CurX, CurY); End;

Procedure TAnsiEditor2.PushUndo;
Begin
  If UndoCount < MAX_UNDO Then Inc(UndoCount) Else UndoCount := MAX_UNDO;
  UndoPos := UndoCount;
  If Undo[UndoPos] = Nil Then New(Undo[UndoPos]);
  Undo[UndoPos]^.Data := Canvas;
  Undo[UndoPos]^.CX := CurX;
  Undo[UndoPos]^.CY := CurY;
End;

Procedure TAnsiEditor2.PopUndo;
Begin
  If UndoPos > 0 Then Begin
    Canvas := Undo[UndoPos]^.Data;
    CurX := Undo[UndoPos]^.CX;
    CurY := Undo[UndoPos]^.CY;
    Dec(UndoPos);
    Dec(UndoCount);
    DrawScreen;
  End;
End;

Procedure TAnsiEditor2.PlaceChar(Ch: Char);
Begin
  PushUndo;
  Canvas[CurY, CurX].Ch := Ch;
  Canvas[CurY, CurX].Attr := CurAttr;
  DrawCell(CurX, CurY);
  Modified := True;
  If CurX < CANVAS_W Then Inc(CurX)
  Else If CurY < CANVAS_H Then Begin CurX := 1; Inc(CurY); End;
End;

// ====================================================================
// Color Palette — supports ICE (16 BG colors)
// ====================================================================

Procedure TAnsiEditor2.ColorPalette;
Var
  Ch: Char;
  I: Integer;
  PalDone: Boolean;
  SelFG, SelBG: Byte;
  MaxBG: Byte;
Begin
  SelFG := FGColor;
  SelBG := BGColor;
  PalDone := False;
  If ICEMode Then MaxBG := 15 Else MaxBG := 7;

  Console.WriteXY(20, 3, 31, '+-- Color Palette ------------------+');
  Console.WriteXY(20, 4, 31, '|                                   |');
  Console.WriteXY(20, 5, 31, '| FG: 0123456789ABCDEF              |');
  For I := 0 to 15 Do Console.WriteXY(26 + I, 5, I, Chr(219));
  Console.WriteXY(20, 6, 31, '|                                   |');
  Console.WriteXY(20, 7, 31, '| BG: 01234567');
  If ICEMode Then Console.WriteXY(34, 7, 31, '89ABCDEF        |')
  Else Console.WriteXY(34, 7, 31, '                       |');
  For I := 0 to MaxBG Do Console.WriteXY(26 + I, 7, (I * 16) + 15, Chr(219));
  Console.WriteXY(20, 8, 31, '|                                   |');
  Console.WriteXY(20, 9, 31, '| Sample:                           |');
  Console.WriteXY(20, 10, 31, '|                                   |');
  Console.WriteXY(20, 11, 31, '| Arrows=Move  Enter=OK  ESC=Cancel |');
  If ICEMode Then
    Console.WriteXY(20, 12, 31, '| I=Toggle ICE mode (ON)            |')
  Else
    Console.WriteXY(20, 12, 31, '| I=Toggle ICE mode (OFF)           |');
  Console.WriteXY(20, 13, 31, '+-----------------------------------+');

  Repeat
    CurAttr := SelFG + (SelBG * 16);
    Console.WriteXY(30, 9, CurAttr, ' Sample Text ');
    Console.WriteXY(26 + SelFG, 6, 112, '^');
    Console.WriteXY(26 + SelBG, 8, 112, '^');
    Console.BufFlush;

    If Keyboard.KeyWait(100) Then Begin
      Ch := Keyboard.ReadKey;
      If Ch = #0 Then Begin
        Ch := Keyboard.ReadKey;
        Case Ch of
          #75: If SelFG > 0 Then Begin Console.WriteXY(26+SelFG,6,31,' '); Dec(SelFG); End;
          #77: If SelFG < 15 Then Begin Console.WriteXY(26+SelFG,6,31,' '); Inc(SelFG); End;
          #72: If SelBG > 0 Then Begin Console.WriteXY(26+SelBG,8,31,' '); Dec(SelBG); End;
          #80: If SelBG < MaxBG Then Begin Console.WriteXY(26+SelBG,8,31,' '); Inc(SelBG); End;
        End;
      End Else Case Ch of
        #13: Begin FGColor := SelFG; BGColor := SelBG; PalDone := True; End;
        #27: Begin CurAttr := FGColor + (BGColor * 16); PalDone := True; End;
        'I','i': Begin
                   ICEMode := Not ICEMode;
                   If ICEMode Then MaxBG := 15 Else Begin MaxBG := 7; If SelBG > 7 Then SelBG := 7; End;
                   PalDone := True; ColorPalette; Exit;
                 End;
        '0'..'9': Begin Console.WriteXY(26+SelFG,6,31,' '); SelFG := Ord(Ch)-Ord('0'); End;
        'a'..'f': Begin Console.WriteXY(26+SelFG,6,31,' '); SelFG := 10+Ord(Ch)-Ord('a'); End;
        'A'..'F': Begin Console.WriteXY(26+SelFG,6,31,' '); SelFG := 10+Ord(Ch)-Ord('A'); End;
      End;
    End;
  Until PalDone;

  CurAttr := FGColor + (BGColor * 16);
  DrawScreen;
End;

// ====================================================================
// Character Map — CP437 glyph picker
// ====================================================================

Procedure TAnsiEditor2.CharMap;
Var
  Ch: Char;
  Sel: Byte;
  I, Row, Col: Integer;
  MapDone: Boolean;
Begin
  Sel := Ord(CurChar);
  MapDone := False;

  Repeat
    Console.WriteXY(15, 3, 31, '+-- Character Map (CP437) -------------------------+');
    For Row := 0 to 15 Do Begin
      Console.WriteXY(15, 4 + Row, 31, '| ');
      For Col := 0 to 15 Do Begin
        I := Row * 16 + Col;
        If I = Sel Then
          Console.WriteXY(17 + Col * 3, 4 + Row, 113, ' ' + Chr(I) + ' ')
        Else
          Console.WriteXY(17 + Col * 3, 4 + Row, 31, ' ' + Chr(I) + ' ');
      End;
      Console.WriteXY(65, 4 + Row, 31, ' |');
    End;
    Console.WriteXY(15, 20, 31, '| Arrows=Move  Enter=OK  ESC=Cancel                |');
    Console.WriteXY(15, 21, 31, '+--------------------------------------------------+');
    Console.WriteXY(40, 20, 112, ' Char:' + IntToStr(Sel) + ' ');
    Console.BufFlush;

    If Keyboard.KeyWait(100) Then Begin
      Ch := Keyboard.ReadKey;
      If Ch = #0 Then Begin
        Ch := Keyboard.ReadKey;
        Case Ch of
          #75: If Sel > 0 Then Dec(Sel);
          #77: If Sel < 255 Then Inc(Sel);
          #72: If Sel >= 16 Then Dec(Sel, 16);
          #80: If Sel <= 239 Then Inc(Sel, 16);
        End;
      End Else Case Ch of
        #13: Begin CurChar := Chr(Sel); MapDone := True; End;
        #27: MapDone := True;
      End;
    End;
  Until MapDone;

  DrawScreen;
End;

// ====================================================================
// Block Operations
// ====================================================================

Procedure TAnsiEditor2.BlockSelect;
Var I: Integer;
Begin
  If Not Block.Active Then Begin
    Block.Active := True;
    Block.X1 := CurX; Block.Y1 := CurY;
    Block.X2 := CurX; Block.Y2 := CurY;
  End Else Begin
    Block.X2 := CurX; Block.Y2 := CurY;
    { Normalize }
    If Block.X1 > Block.X2 Then Begin I := Block.X1; Block.X1 := Block.X2; Block.X2 := I; End;
    If Block.Y1 > Block.Y2 Then Begin I := Block.Y1; Block.Y1 := Block.Y2; Block.Y2 := I; End;
  End;
  DrawScreen;
End;

Procedure TAnsiEditor2.BlockFill;
Var X, Y: Integer;
Begin
  If Not Block.Active Then Exit;
  PushUndo;
  For Y := Block.Y1 to Block.Y2 Do
    For X := Block.X1 to Block.X2 Do Begin
      Canvas[Y, X].Ch := CurChar;
      Canvas[Y, X].Attr := CurAttr;
    End;
  Modified := True;
  DrawScreen;
End;

Procedure TAnsiEditor2.BlockCopy;
Var X, Y: Integer;
Begin
  If Not Block.Active Then Exit;
  ClipH := Block.Y2 - Block.Y1 + 1;
  ClipW := Block.X2 - Block.X1 + 1;
  For Y := 1 to ClipH Do
    For X := 1 to ClipW Do
      Clipboard[Y][X] := Canvas[Block.Y1 + Y - 1, Block.X1 + X - 1];
End;

Procedure TAnsiEditor2.BlockPaste;
Var X, Y: Integer;
Begin
  If ClipH = 0 Then Exit;
  PushUndo;
  For Y := 1 to ClipH Do
    For X := 1 to ClipW Do
      If (CurY + Y - 1 <= CANVAS_H) And (CurX + X - 1 <= CANVAS_W) Then
        Canvas[CurY + Y - 1, CurX + X - 1] := Clipboard[Y][X];
  Modified := True;
  DrawScreen;
End;

Procedure TAnsiEditor2.BlockCenterText;
Var
  Y, X, First, Last, Len, Offset: Integer;
  Temp: Array[1..CANVAS_W] of TCell;
Begin
  If Not Block.Active Then Exit;
  PushUndo;
  For Y := Block.Y1 to Block.Y2 Do Begin
    { Find first and last non-space }
    First := CANVAS_W + 1; Last := 0;
    For X := Block.X1 to Block.X2 Do Begin
      If Canvas[Y, X].Ch <> ' ' Then Begin
        If X < First Then First := X;
        If X > Last Then Last := X;
      End;
    End;
    If Last = 0 Then Continue;
    Len := Last - First + 1;
    Offset := Block.X1 + ((Block.X2 - Block.X1 + 1 - Len) Div 2);
    { Copy to temp }
    For X := 1 to CANVAS_W Do Begin Temp[X].Ch := ' '; Temp[X].Attr := CurAttr; End;
    For X := First to Last Do Temp[Offset + X - First] := Canvas[Y, X];
    { Write back }
    For X := Block.X1 to Block.X2 Do Canvas[Y, X] := Temp[X];
  End;
  Modified := True;
  DrawScreen;
End;

Procedure TAnsiEditor2.BlockErase;
Var X, Y: Integer;
Begin
  If Not Block.Active Then Exit;
  PushUndo;
  For Y := Block.Y1 to Block.Y2 Do
    For X := Block.X1 to Block.X2 Do Begin
      Canvas[Y, X].Ch := ' ';
      Canvas[Y, X].Attr := 7;
    End;
  Block.Active := False;
  Modified := True;
  DrawScreen;
End;

// ====================================================================
// File Operations
// ====================================================================

Procedure TAnsiEditor2.UploadFile;
Var FN: String;
Begin
  FN := ReadLine('Upload file:', 60);
  If FN = '' Then Exit;
  LoadFile(FN);
  DrawScreen;
End;

Procedure TAnsiEditor2.LoadFile(FN: String);
Var
  F: File;
  Buf: Array[0..4095] of Byte;
  N, I: Integer;
  PX, PY: Integer;
  InEsc: Boolean;
  EscBuf: String;
  TmpAttr: Byte;
  Params: String;
  P, Code: Integer;
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
          If Chr(Buf[I]) = 'm' Then Begin
            { Parse SGR parameters }
            Params := Copy(EscBuf, 2, Length(EscBuf) - 2); { skip [ and m }
            While Length(Params) > 0 Do Begin
              P := Pos(';', Params);
              If P = 0 Then P := Length(Params) + 1;
              Val(Copy(Params, 1, P - 1), Code, P);
              If I = 0 Then Case Code of
                0: TmpAttr := 7;
                1: TmpAttr := TmpAttr Or 8;
                5: If ICEMode Then TmpAttr := TmpAttr Or 128 Else TmpAttr := TmpAttr Or 128;
                30..37: TmpAttr := (TmpAttr And $F8) Or (Code - 30);
                40..47: TmpAttr := (TmpAttr And $8F) Or ((Code - 40) Shl 4);
              End;
              Delete(Params, 1, P);
            End;
          End Else If Chr(Buf[I]) = 'H' Then Begin
            { Cursor position }
            Params := Copy(EscBuf, 2, Length(EscBuf) - 2);
            P := Pos(';', Params);
            If P > 0 Then Begin
              Val(Copy(Params, 1, P-1), PY, Code);
              Val(Copy(Params, P+1, 255), PX, Code);
            End;
          End Else If Chr(Buf[I]) = 'J' Then Begin
            { Clear screen — ignore for loading }
          End Else If Chr(Buf[I]) = 'K' Then Begin
            { Clear EOL — ignore for loading }
          End;
          InEsc := False;
          EscBuf := '';
        End;
      End Else If Buf[I] = 27 Then Begin
        InEsc := True;
        EscBuf := '';
      End Else If Buf[I] = 13 Then Begin
        { CR }
      End Else If Buf[I] = 10 Then Begin
        PX := 1; Inc(PY);
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

Procedure TAnsiEditor2.SaveFile;
Var
  F: Text;
  X, Y: Integer;
  LastAttr: Byte;
  Line: String;
  FG, BG: Byte;
  Bold: Boolean;
Begin
  If FileName = '' Then Begin SaveFileAs; Exit; End;

  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;

  LastAttr := 255; { Force first color output }

  For Y := 1 to CANVAS_H Do Begin
    Line := '';
    For X := 1 to CANVAS_W Do Begin
      If Canvas[Y, X].Attr <> LastAttr Then Begin
        LastAttr := Canvas[Y, X].Attr;
        FG := LastAttr And $0F;
        BG := (LastAttr Shr 4) And $0F;
        Bold := (FG And 8) <> 0;
        Line := Line + #27 + '[0';
        If Bold Then Begin Line := Line + ';1'; FG := FG And 7; End;
        Line := Line + ';' + IntToStr(30 + FG);
        Line := Line + ';' + IntToStr(40 + (BG And 7));
        If (BG > 7) And ICEMode Then Line := Line + ';5';
        Line := Line + 'm';
      End;
      Line := Line + Canvas[Y, X].Ch;
    End;
    { Trim trailing spaces }
    While (Length(Line) > 0) And (Line[Length(Line)] = ' ') Do Dec(Line[0]);
    WriteLn(F, Line);
  End;

  Close(F);
  Modified := False;
  DrawStatus;
End;

Procedure TAnsiEditor2.SaveFileAs;
Var FN: String;
Begin
  FN := ReadLine('Save as:', 60);
  If FN <> '' Then Begin
    FileName := FN;
    SaveFile;
  End;
End;

// ====================================================================
// Main Menu — Mystic style box
// ====================================================================

Procedure TAnsiEditor2.DoMenu;
Var Ch: Char;
Begin
  Ch := MenuChoice('ANSI Editor v2',
    'F:F File Menu|C:C Color Palette|M:M Character Map|B:B Block Menu|D:D Toggle Draw|I:I Toggle ICE|U:U Upload ANSI|S:S Save|Q:Q Quit');

  Case Ch of
    'F': Begin
           Ch := MenuChoice('File',
             'L:L Load File|S:S Save|A:A Save As|N:N New (Clear)|Q:Q Back');
           Case Ch of
             'L': Begin
                    FileName := ReadLine('Load file:', 60);
                    If FileName <> '' Then Begin LoadFile(FileName); DrawScreen; End;
                  End;
             'S': SaveFile;
             'A': SaveFileAs;
             'N': If Confirm('Clear canvas?') Then Begin PushUndo; ClearCanvas; Modified := True; DrawScreen; End;
           End;
         End;
    'C': ColorPalette;
    'M': CharMap;
    'B': Begin
           Ch := MenuChoice('Block',
             'S:S Select (mark corners)|F:F Fill with char|C:C Copy|P:P Paste|T:T Center Text|E:E Erase|X:X Clear Selection');
           Case Ch of
             'S': BlockSelect;
             'F': BlockFill;
             'C': BlockCopy;
             'P': BlockPaste;
             'T': BlockCenterText;
             'E': BlockErase;
             'X': Begin Block.Active := False; DrawScreen; End;
           End;
         End;
    'D': Begin DrawMode := Not DrawMode; DrawStatus; End;
    'I': Begin ICEMode := Not ICEMode; DrawStatus; End;
    'U': UploadFile;
    'S': SaveFile;
    'Q': If (Not Modified) Or Confirm('Unsaved changes. Quit?') Then Done := True;
  End;
End;

// ====================================================================
// Main Key Handler
// ====================================================================

Procedure TAnsiEditor2.ProcessKey;
Var Ch: Char;
Begin
  If Not Keyboard.KeyWait(100) Then Exit;

  Ch := Keyboard.ReadKey;

  If Ch = #0 Then Begin
    Ch := Keyboard.ReadKey;
    Case Ch of
      #72: Begin If DrawMode Then PlaceChar(CurChar); If CurY > 1 Then Dec(CurY); End;
      #80: Begin If DrawMode Then PlaceChar(CurChar); If CurY < CANVAS_H Then Inc(CurY); End;
      #75: Begin If DrawMode Then PlaceChar(CurChar); If CurX > 1 Then Dec(CurX); End;
      #77: Begin If DrawMode Then PlaceChar(CurChar); If CurX < CANVAS_W Then Inc(CurX); End;
      #71: CurX := 1;
      #79: CurX := CANVAS_W;
      #73: CurY := 1;
      #81: CurY := CANVAS_H;
      #83: Begin Canvas[CurY,CurX].Ch := ' '; Canvas[CurY,CurX].Attr := CurAttr; DrawCell(CurX,CurY); Modified := True; End;
      #59: ColorPalette;
      #60: CharMap;
      #62: SaveFile;
      #63: Begin DrawMode := Not DrawMode; DrawStatus; End;
      #67: If Confirm('Clear canvas?') Then Begin PushUndo; ClearCanvas; Modified := True; DrawScreen; End;
    End;
  End Else
    Case Ch of
      #27: DoMenu;
      #2:  BlockSelect;        { Ctrl-B }
      #26: PopUndo;            { Ctrl-Z }
      #19: SaveFile;           { Ctrl-S }
      #13: Begin CurX := 1; If CurY < CANVAS_H Then Inc(CurY); End;
      #8:  Begin
             If CurX > 1 Then Begin
               Dec(CurX);
               PushUndo;
               Canvas[CurY,CurX].Ch := ' ';
               Canvas[CurY,CurX].Attr := CurAttr;
               DrawCell(CurX, CurY);
               Modified := True;
             End;
           End;
      ' '..#255: PlaceChar(Ch);
    End;

  If Block.Active Then Begin
    Block.X2 := CurX;
    Block.Y2 := CurY;
  End;

  DrawStatus;
End;

Procedure TAnsiEditor2.Run;
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

Procedure TAnsiEditor2.Cleanup;
Var I: Integer;
Begin
  For I := 1 to MAX_UNDO Do If Undo[I] <> Nil Then Dispose(Undo[I]);
  Console.TextAttr := 7;
  Console.ClearScreen;
  Console.BufFlush;
  Console.Free;
  Keyboard.Free;
End;

Var
  Editor: TAnsiEditor2;
  I: Integer;
Begin
  Editor.Init;

  If ParamCount >= 1 Then
    Editor.LoadFile(ParamStr(1))
  Else
    Editor.FileName := 'untitled.ans';

  Editor.Run;
  Editor.Cleanup;
End.
