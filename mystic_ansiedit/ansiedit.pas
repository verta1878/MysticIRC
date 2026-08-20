Program ansiedit;

// ====================================================================
// ansiedit — Full ANSI Editor v2 (1.12 feature set)
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
{$H+}  { Use AnsiString for m_pdnet compatibility }

Uses
  {$IFDEF WINDOWS}
    Windows,
    m_Input_Windows,
    m_Output_Windows,
  {$ENDIF}
  {$IFDEF UNIX}
    m_Input_Linux,
    m_Output_Linux,
  {$ENDIF}
  m_Strings,
  m_DateTime,
  m_pdtypes,
  m_pdnet,
  ansiedit_transport;

Const
  CANVAS_W  = 80;
  CANVAS_H  = 23;
  STATUS_Y  = 24;
  HELP_Y    = 25;
  MAX_UNDO  = 50;

  { Line draw character sets: Single, Double, Single/Double, Double/Single,
    Block1, Block2, None, Dotted
    Index: 0=horiz 1=vert 2=TL 3=TR 4=BL 5=BR 6=left-T 7=right-T 8=top-T 9=bot-T 10=cross }
  LINE_SETS = 8;
  LineChars : Array[0..7, 0..10] of Byte = (
    ($C4,$B3,$DA,$BF,$C0,$D9,$C3,$B4,$C2,$C1,$C5),  { Single }
    ($CD,$BA,$C9,$BB,$C8,$BC,$CC,$B9,$CB,$CA,$CE),  { Double }
    ($C4,$BA,$D6,$B7,$D3,$BD,$C7,$B6,$D2,$D0,$D7),  { Single/Double }
    ($CD,$B3,$D5,$B8,$D4,$BE,$C6,$B5,$D1,$CF,$D8),  { Double/Single }
    ($DB,$DB,$DB,$DB,$DB,$DB,$DB,$DB,$DB,$DB,$DB),  { Block1 (solid) }
    ($DF,$DC,$DF,$DF,$DC,$DC,$DB,$DB,$DF,$DC,$DB),  { Block2 (half) }
    ($20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20),  { None (spaces) }
    ($FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA)   { Dotted }
  );
  LineSetNames : Array[0..7] of String[12] = (
    'Single', 'Double', 'Singl/Dbl', 'Dbl/Singl',
    'Block1', 'Block2', 'None', 'Dotted'
  );
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
    LineStyle : Byte;
    NoSAUCE   : Boolean;
    { Teleconference }
    NetMode   : Byte;        { 0=not connected, 1=server, 2=client }
    NetTrans  : Byte;        { 0=TCP, 1=Serial }
    NetFossil : Boolean;     { True=use FOSSIL driver, False=direct UART }
    NetHost   : String[60];
    NetPort   : String[5];
    NetNick   : String[20];
    NetPass   : String[20];
    Connected : Boolean;
    Transport : TTransport;
    NetCanvas : TPDCanvas;
    NetServer : TPDNetServer;
    NetClient : TPDNetClient;
    { Chat }
    ChatBuf   : Array[1..50] of String[79];
    ChatCount : Integer;
    ChatPage  : Boolean;     { True=chat page, False=canvas page }
    ChatInput : String[79];
    NotifyMsg : String[60];
    NotifyTime: LongInt;
    NotifyActive: Boolean;  { current chat input line }
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
    RedoMax   : Integer;  { highest valid undo slot for redo }
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
    Function  IsLineChar(X, Y: Integer): Boolean;
    Procedure PlaceLineChar(X, Y: Integer);
    Procedure DoLineDraw(DirX, DirY: Integer);
    Procedure ProcessKey;
    Procedure DoMenu;
    Procedure ColorPalette;
    Procedure CharMap;
    Procedure BlockSelect;
    Procedure BlockFill;
    Procedure BlockCopy;
    Procedure BlockPaste;
    Procedure BlockMove;
    Procedure BlockFlipH;
    Procedure BlockFlipV;
    Procedure BlockMirror;
    Procedure BlockCenterText;
    Procedure BlockErase;
    Procedure InsertLine;
    Procedure DeleteLine;
    Procedure ServerSetup;
    Procedure DoConnect;
    Procedure DoDisconnect;
    Procedure ProcessNetwork;
    Procedure SendCharPlace(X, Y: Integer; Ch: Char; Attr: Byte);
    Procedure AddChat(Msg: String);
    Procedure DrawChatPage;
    Procedure FlipPage;
    Procedure ProcessChatKey;
    Procedure OnNetChat(const From, Text: String);
    Procedure OnNetJoin(Index: Integer; const Alias: String; Level: TUserLevel);
    Procedure OnNetLeave(Index: Integer; const Alias: String; Level: TUserLevel);
    Procedure OnNetUpdate(X1, Y1, X2, Y2: Integer);
    Procedure PushUndo;
    Procedure PopUndo;
    Procedure DoRedo;
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
               SetLength(S, Length(S) - 1);
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
  LineStyle := 0;
  NoSAUCE := False;
  NetMode := 0;
  NetTrans := 0;
  NetFossil := True;  { default to FOSSIL }
  NetHost := '';
  NetPort := '8000';
  NetNick := '';
  NetPass := '';
  Connected := False;
  Transport := Nil;
  NetCanvas := Nil;
  NetServer := Nil;
  NetClient := Nil;
  ChatCount := 0;
  ChatPage := False;
  ChatInput := '';
  NotifyMsg := '';
  NotifyTime := 0;
  NotifyActive := False;
  Modified := False;
  Done := False;
  SaveResult := False;
  FileName := '';
  Block.Active := False;
  ClipH := 0; ClipW := 0;
  UndoCount := 0; UndoPos := 0; RedoMax := 0;

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
  If DrawMode Then ModeStr := 'DRAW/' + LineSetNames[LineStyle] Else ModeStr := 'EDIT';
  If ICEMode Then IceStr := 'iCE' Else IceStr := '   ';

  { Left side: position + mode }
  S := ' ' + StrPadR(IntToStr(CurX), 3, ' ') + ',' + StrPadR(IntToStr(CurY), 3, ' ') +
       ' ' + ModeStr;

  If Block.Active Then
    S := S + ' BLK ' + IntToStr(Block.X2-Block.X1+1) + 'x' + IntToStr(Block.Y2-Block.Y1+1);

  If Modified Then S := S + ' *';

  Console.WriteXY(1, STATUS_Y, $70, StrPadR(S, 40, ' '));

  { Right side }
  If NotifyActive Then Begin
    { Chat notification — flash message }
    Console.WriteXY(41, STATUS_Y, $4E, StrPadR(' ' + NotifyMsg, 34, ' '));
  End Else Begin
    S := IceStr;
    If Connected Then Begin
      If NetMode = 1 Then S := S + ' HOST'
      Else S := S + ' CLIENT';
    End;
    S := S + ' ' + StrPadL(FileName, 20, ' ') + ' ';
    Console.WriteXY(41, STATUS_Y, $78, StrPadR(S, 34, ' '));
  End;

  { FG color block }
  Console.WriteXY(75, STATUS_Y, (FGColor And $0F), #219);
  { BG color block }
  Console.WriteXY(76, STATUS_Y, ((BGColor And $07) Shl 4), #219);
  { Character sample }
  Console.WriteXY(77, STATUS_Y, CurAttr, ' ' + CurChar + ' ');
End;

Procedure TAnsiEditor2.DrawHelpBar;
Begin
  Console.WriteXY(1, HELP_Y, 113,
    StrPadR(' ESC=Menu F1=Color F2=Char F5=Draw F6=Ins F7=Del TAB=Line ^Z/^Y=Undo/Redo ALT+S=Net', CANVAS_W, ' '));
End;

Procedure TAnsiEditor2.MoveCursor;
Begin Console.CursorXY(CurX, CurY); End;

Procedure TAnsiEditor2.PushUndo;
Begin
  If UndoPos < MAX_UNDO Then Inc(UndoPos);
  If UndoCount < UndoPos Then UndoCount := UndoPos;
  If Undo[UndoPos] = Nil Then New(Undo[UndoPos]);
  Undo[UndoPos]^.Data := Canvas;
  Undo[UndoPos]^.CX := CurX;
  Undo[UndoPos]^.CY := CurY;
  RedoMax := UndoPos;  { new edit kills redo history }
End;

Procedure TAnsiEditor2.PopUndo;
Begin
  If UndoPos > 1 Then Begin
    Dec(UndoPos);
    Canvas := Undo[UndoPos]^.Data;
    CurX := Undo[UndoPos]^.CX;
    CurY := Undo[UndoPos]^.CY;
    DrawScreen;
  End;
End;

Procedure TAnsiEditor2.DoRedo;
Begin
  If UndoPos < RedoMax Then Begin
    Inc(UndoPos);
    Canvas := Undo[UndoPos]^.Data;
    CurX := Undo[UndoPos]^.CX;
    CurY := Undo[UndoPos]^.CY;
    DrawScreen;
  End;
End;

Procedure TAnsiEditor2.PlaceChar(Ch: Char);
Begin
  PushUndo;
  Canvas[CurY, CurX].Ch := Ch;
  Canvas[CurY, CurX].Attr := CurAttr;
  DrawCell(CurX, CurY);
  SendCharPlace(CurX, CurY, Ch, CurAttr);
  Modified := True;
  If CurX < CANVAS_W Then Inc(CurX)
  Else If CurY < CANVAS_H Then Begin CurX := 1; Inc(CurY); End;
End;

// ====================================================================
// Line Draw — intelligent corner/intersection selection
// ====================================================================

Function TAnsiEditor2.IsLineChar(X, Y: Integer): Boolean;
{ Check if cell at (X,Y) contains a line draw character from current set }
Var Ch: Byte; I: Integer;
Begin
  Result := False;
  If (X < 1) or (X > CANVAS_W) or (Y < 1) or (Y > CANVAS_H) Then Exit;
  Ch := Ord(Canvas[Y, X].Ch);
  For I := 0 to 10 Do
    If LineChars[LineStyle, I] = Ch Then Begin Result := True; Exit; End;
End;

Procedure TAnsiEditor2.PlaceLineChar(X, Y: Integer);
{ Place the correct line draw character based on neighbors.
  Checks up/down/left/right for existing line chars and picks
  the right piece: horizontal, vertical, corner, T, or cross. }
Var
  U, D, L, R: Boolean;  { neighbors that are line chars }
  Ch: Byte;
Begin
  U := IsLineChar(X, Y - 1);
  D := IsLineChar(X, Y + 1);
  L := IsLineChar(X - 1, Y);
  R := IsLineChar(X + 1, Y);

  { Pick character based on neighbor connectivity }
  If U and D and L and R Then Ch := LineChars[LineStyle, 10]  { cross }
  Else If U and D and L   Then Ch := LineChars[LineStyle, 7]  { right-T }
  Else If U and D and R   Then Ch := LineChars[LineStyle, 6]  { left-T }
  Else If U and L and R   Then Ch := LineChars[LineStyle, 9]  { bot-T }
  Else If D and L and R   Then Ch := LineChars[LineStyle, 8]  { top-T }
  Else If U and D         Then Ch := LineChars[LineStyle, 1]  { vert }
  Else If L and R         Then Ch := LineChars[LineStyle, 0]  { horiz }
  Else If D and R         Then Ch := LineChars[LineStyle, 2]  { TL corner }
  Else If D and L         Then Ch := LineChars[LineStyle, 3]  { TR corner }
  Else If U and R         Then Ch := LineChars[LineStyle, 4]  { BL corner }
  Else If U and L         Then Ch := LineChars[LineStyle, 5]  { BR corner }
  Else If U or D          Then Ch := LineChars[LineStyle, 1]  { vert }
  Else If L or R          Then Ch := LineChars[LineStyle, 0]  { horiz }
  Else                         Ch := LineChars[LineStyle, 10]; { isolated = cross }

  Canvas[Y, X].Ch := Chr(Ch);
  Canvas[Y, X].Attr := CurAttr;
  DrawCell(X, Y);
  SendCharPlace(X, Y, Chr(Ch), CurAttr);
  Modified := True;
End;

Procedure TAnsiEditor2.DoLineDraw(DirX, DirY: Integer);
{ Draw a line char at current position, then update the cell we came from
  (in case it needs to become a corner/T/cross now). }
Var PrevX, PrevY: Integer;
Begin
  PushUndo;
  PrevX := CurX;
  PrevY := CurY;

  { Place line char at current position }
  PlaceLineChar(CurX, CurY);

  { Move cursor }
  If DirX < 0 Then Begin If CurX > 1 Then Dec(CurX); End
  Else If DirX > 0 Then Begin If CurX < CANVAS_W Then Inc(CurX); End;
  If DirY < 0 Then Begin If CurY > 1 Then Dec(CurY); End
  Else If DirY > 0 Then Begin If CurY < CANVAS_H Then Inc(CurY); End;

  { Place line char at new position }
  PlaceLineChar(CurX, CurY);

  { Update previous cell — it may need a new char now that we moved away }
  PlaceLineChar(PrevX, PrevY);
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
{ 1.12: Fill with Character, Attribute, Both, New Attribute }
Var X, Y: Integer; Ch: Char; FillCh: Char; FillAttr: Byte;
Begin
  If Not Block.Active Then Exit;

  Console.WriteXY(1, STATUS_Y, $0E,
    StrPadR(' Fill: C=Character A=Attribute B=Both N=NewAttr Q=Quit', 80, ' '));
  Ch := UpCase(Keyboard.ReadKey);

  Case Ch of
    'C': Begin
      Console.WriteXY(1, STATUS_Y, $0E, StrPadR(' Enter fill character: ', 80, ' '));
      FillCh := Keyboard.ReadKey;
      PushUndo;
      For Y := Block.Y1 to Block.Y2 Do
        For X := Block.X1 to Block.X2 Do
          Canvas[Y, X].Ch := FillCh;
      Modified := True;
    End;
    'A': Begin
      PushUndo;
      For Y := Block.Y1 to Block.Y2 Do
        For X := Block.X1 to Block.X2 Do
          Canvas[Y, X].Attr := CurAttr;
      Modified := True;
    End;
    'B': Begin
      PushUndo;
      For Y := Block.Y1 to Block.Y2 Do
        For X := Block.X1 to Block.X2 Do Begin
          Canvas[Y, X].Ch := CurChar;
          Canvas[Y, X].Attr := CurAttr;
        End;
      Modified := True;
    End;
    'N': Begin
      Console.WriteXY(1, STATUS_Y, $0E, StrPadR(' Enter new attribute (hex): ', 80, ' '));
      FillAttr := CurAttr; { TODO: hex input }
      PushUndo;
      For Y := Block.Y1 to Block.Y2 Do
        For X := Block.X1 to Block.X2 Do
          Canvas[Y, X].Attr := FillAttr;
      Modified := True;
    End;
  End;
  DrawScreen;
  DrawStatus;
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

Procedure TAnsiEditor2.BlockMove;
{ Move block to cursor position (cut + paste) }
Var X, Y, W, H: Integer;
Begin
  If Not Block.Active Then Exit;
  BlockCopy;
  { Erase source }
  PushUndo;
  For Y := Block.Y1 to Block.Y2 Do
    For X := Block.X1 to Block.X2 Do Begin
      Canvas[Y, X].Ch := ' ';
      Canvas[Y, X].Attr := 7;
    End;
  { Paste at cursor }
  For Y := 1 to ClipH Do
    For X := 1 to ClipW Do
      If (CurY + Y - 1 <= CANVAS_H) and (CurX + X - 1 <= CANVAS_W) Then
        Canvas[CurY + Y - 1, CurX + X - 1] := Clipboard[Y][X];
  Block.Active := False;
  Modified := True;
  DrawScreen;
End;

Procedure TAnsiEditor2.BlockFlipH;
{ Flip block horizontally (left-right mirror) }
Var X, Y, W: Integer; Temp: TCell;
Begin
  If Not Block.Active Then Exit;
  PushUndo;
  W := Block.X2 - Block.X1;
  For Y := Block.Y1 to Block.Y2 Do
    For X := 0 to W div 2 Do Begin
      Temp := Canvas[Y, Block.X1 + X];
      Canvas[Y, Block.X1 + X] := Canvas[Y, Block.X2 - X];
      Canvas[Y, Block.X2 - X] := Temp;
    End;
  Modified := True;
  DrawScreen;
End;

Procedure TAnsiEditor2.BlockFlipV;
{ Flip block vertically (top-bottom mirror) }
Var X, Y, H: Integer; Temp: TCell;
Begin
  If Not Block.Active Then Exit;
  PushUndo;
  H := Block.Y2 - Block.Y1;
  For Y := 0 to H div 2 Do
    For X := Block.X1 to Block.X2 Do Begin
      Temp := Canvas[Block.Y1 + Y, X];
      Canvas[Block.Y1 + Y, X] := Canvas[Block.Y2 - Y, X];
      Canvas[Block.Y2 - Y, X] := Temp;
    End;
  Modified := True;
  DrawScreen;
End;

Procedure TAnsiEditor2.BlockMirror;
{ Mirror block — flip horizontally and swap line draw chars }
Var X, Y, W: Integer; Ch: Byte;
Begin
  BlockFlipH;
  { Swap left/right line draw chars }
  For Y := Block.Y1 to Block.Y2 Do
    For X := Block.X1 to Block.X2 Do Begin
      Ch := Ord(Canvas[Y, X].Ch);
      Case Ch of
        $DA: Canvas[Y, X].Ch := Chr($BF);  { TL → TR }
        $BF: Canvas[Y, X].Ch := Chr($DA);  { TR → TL }
        $C0: Canvas[Y, X].Ch := Chr($D9);  { BL → BR }
        $D9: Canvas[Y, X].Ch := Chr($C0);  { BR → BL }
        $C3: Canvas[Y, X].Ch := Chr($B4);  { left-T → right-T }
        $B4: Canvas[Y, X].Ch := Chr($C3);  { right-T → left-T }
        $C9: Canvas[Y, X].Ch := Chr($BB);  { dbl TL → dbl TR }
        $BB: Canvas[Y, X].Ch := Chr($C9);  { dbl TR → dbl TL }
        $C8: Canvas[Y, X].Ch := Chr($BC);  { dbl BL → dbl BR }
        $BC: Canvas[Y, X].Ch := Chr($C8);  { dbl BR → dbl BL }
        $CC: Canvas[Y, X].Ch := Chr($B9);  { dbl left-T → dbl right-T }
        $B9: Canvas[Y, X].Ch := Chr($CC);  { dbl right-T → dbl left-T }
      End;
    End;
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

Procedure TAnsiEditor2.InsertLine;
{ Insert blank line at CurY, push everything down }
Var X, Y: Integer;
Begin
  PushUndo;
  For Y := CANVAS_H DownTo CurY + 1 Do
    For X := 1 to CANVAS_W Do
      Canvas[Y, X] := Canvas[Y - 1, X];
  For X := 1 to CANVAS_W Do Begin
    Canvas[CurY, X].Ch := ' ';
    Canvas[CurY, X].Attr := 7;
  End;
  Modified := True;
  DrawScreen;
End;

Procedure TAnsiEditor2.DeleteLine;
{ Delete line at CurY, pull everything up }
Var X, Y: Integer;
Begin
  PushUndo;
  For Y := CurY to CANVAS_H - 1 Do
    For X := 1 to CANVAS_W Do
      Canvas[Y, X] := Canvas[Y + 1, X];
  For X := 1 to CANVAS_W Do Begin
    Canvas[CANVAS_H, X].Ch := ' ';
    Canvas[CANVAS_H, X].Attr := 7;
  End;
  Modified := True;
  DrawScreen;
End;

Procedure TAnsiEditor2.ServerSetup;
{ ALT+S — Server/Client connection setup dialog }
Const
  DX = 20;
  DY = 6;
  DW = 42;
  DH = 15;
  AttrBox   = $1F;  { bright white on blue }
  AttrLabel = $1E;  { yellow on blue }
  AttrField = $70;  { black on gray }
  AttrBtn   = $2F;  { bright white on green }
  AttrBtnD  = $4F;  { bright white on red }
Var
  Ch     : Char;
  Field  : Byte;
  MenuDone   : Boolean;
  TmpHost, TmpPort, TmpNick, TmpPass : String;
  TmpMode  : Byte;
  TmpTrans : Byte;
  TmpFossil : Boolean;
  X, Y, I : Integer;

  Procedure DrawField(FY: Integer; Label_: String; Value: String; Active: Boolean; IsPwd: Boolean);
  Var Disp: String; Attr: Byte; J: Integer;
  Begin
    Console.WriteXY(DX + 2, FY, AttrLabel, StrPadR(Label_, 10, ' '));
    If IsPwd Then Begin
      Disp := '';
      For J := 1 to Length(Value) Do Disp := Disp + '*';
    End Else
      Disp := Value;
    If Active Then Attr := $0F Else Attr := AttrField;
    Console.WriteXY(DX + 12, FY, Attr, StrPadR(Disp, 27, ' '));
  End;

  Procedure DrawDialog;
  Var LY: Integer;
  Begin
    { Box }
    Console.WriteXY(DX, DY,     AttrBox, #218 + StrPadR(#196 + ' Server/Client Setup ' + #196, DW-2, #196) + #191);
    For LY := DY + 1 to DY + DH - 1 Do
      Console.WriteXY(DX, LY,    AttrBox, #179 + StrRep(' ', DW-2) + #179);
    Console.WriteXY(DX, DY+DH,  AttrBox, #192 + StrRep(#196, DW-2) + #217);

    { Mode selector }
    Console.WriteXY(DX + 2, DY + 2, AttrLabel, 'Mode:     ');
    If TmpMode = 1 Then Console.WriteXY(DX + 12, DY + 2, $1F, '(X) Server    ( ) Client      ')
    Else Console.WriteXY(DX + 12, DY + 2, $1F, '( ) Server    (X) Client      ');

    { Transport selector }
    Console.WriteXY(DX + 2, DY + 3, AttrLabel, 'Transport:');
    If TmpTrans = 0 Then
      Console.WriteXY(DX + 12, DY + 3, $1F, '(X) TCP       ( ) Serial         ')
    Else
      Console.WriteXY(DX + 12, DY + 3, $1F, '( ) TCP       (X) Serial         ');

    { Separator }
    Console.WriteXY(DX, DY + 4, AttrBox, #195 + StrRep(#196, DW-2) + #180);

    { Fields }
    If TmpTrans = 0 Then Begin
      { TCP fields }
      DrawField(DY + 5, 'Host:', TmpHost, Field = 1, False);
      DrawField(DY + 6, 'Port:', TmpPort, Field = 2, False);
    End Else Begin
      { Serial fields }
      Console.WriteXY(DX + 2, DY + 5, AttrLabel, 'Driver:   ');
      If TmpFossil Then
        Console.WriteXY(DX + 12, DY + 5, $1F, '(X) FOSSIL    ( ) UART          ')
      Else
        Console.WriteXY(DX + 12, DY + 5, $1F, '( ) FOSSIL    (X) UART          ');
      DrawField(DY + 6, 'COM Port:', TmpPort, Field = 1, False);
      DrawField(DY + 7, 'Baud:', TmpHost, Field = 2, False);
    End;
    DrawField(DY + 7, 'Nick:', TmpNick, Field = 3, False);
    DrawField(DY + 8, 'Password:', TmpPass, Field = 4, True);

    { Status }
    Console.WriteXY(DX + 2, DY + 10, AttrLabel, 'Status:   ');  { row 10 }
    If Connected Then
      Console.WriteXY(DX + 12, DY + 10, $0A, StrPadR('Connected', 27, ' '))
    Else
      Console.WriteXY(DX + 12, DY + 10, $08, StrPadR('Not connected', 27, ' '));

    { Separator }
    Console.WriteXY(DX, DY + 11, AttrBox, #195 + StrRep(#196, DW-2) + #180);

    { Buttons }
    If Not Connected Then Begin
      Console.WriteXY(DX + 4,  DY + 12, AttrBtn,  ' C Connect  ');
      Console.WriteXY(DX + 24, DY + 12, AttrBox,  ' Q Cancel   ');
    End Else Begin
      Console.WriteXY(DX + 4,  DY + 12, AttrBtnD, ' D Disconnect ');
      Console.WriteXY(DX + 24, DY + 12, AttrBox,  ' Q Cancel     ');
    End;

    { Help }
    Console.WriteXY(DX + 2, DY + 13, $17, 'TAB=next S/J=mode T=transport F=driver C=Connect');
  End;

Begin
  TmpMode := NetMode;
  TmpTrans := NetTrans;
  TmpFossil := NetFossil;
  TmpHost := NetHost;
  TmpPort := NetPort;
  TmpNick := NetNick;
  TmpPass := NetPass;
  If TmpMode = 0 Then TmpMode := 1;  { default to server }
  Field := 0;
  MenuDone := False;

  Repeat
    DrawDialog;

    Ch := UpCase(Keyboard.ReadKey);
    Case Ch of
      #09: Begin { TAB = next field }
        Field := (Field + 1) mod 5;
      End;
      'S': TmpMode := 1;        { S = Server mode }
      'J': TmpMode := 2;        { J = Client (join) mode }
      'T': TmpTrans := 1 - TmpTrans;  { T = toggle TCP/Serial }
      'F': TmpFossil := Not TmpFossil; { F = toggle FOSSIL/UART }
      'C': Begin { Connect }
        NetMode := TmpMode;
        NetTrans := TmpTrans;
        NetFossil := TmpFossil;
        NetHost := TmpHost;
        NetPort := TmpPort;
        NetNick := TmpNick;
        NetPass := TmpPass;
        If NetMode In [1, 2] Then DoConnect;
        MenuDone := True;
      End;
      'D': Begin { Disconnect }
        DoDisconnect;
        MenuDone := True;
      End;
      'Q', #27: MenuDone := True;
      #00: Begin { Extended keys }
        Ch := Keyboard.ReadKey;
        Case Ch of
          #72: If Field > 0 Then Dec(Field);  { Up }
          #80: If Field < 4 Then Inc(Field);  { Down }
        End;
      End;
    Else
      { Edit active field }
      Case Field of
        0: Begin { Mode - L/H/J only } End;
        1: If Length(TmpHost) < 60 Then Begin
             If Ch = #8 Then Begin If Length(TmpHost) > 0 Then Delete(TmpHost, Length(TmpHost), 1); End
             Else TmpHost := TmpHost + Ch;
           End;
        2: If Length(TmpPort) < 5 Then Begin
             If Ch = #8 Then Begin If Length(TmpPort) > 0 Then Delete(TmpPort, Length(TmpPort), 1); End
             Else If Ch in ['0'..'9'] Then TmpPort := TmpPort + Ch;
           End;
        3: If Length(TmpNick) < 20 Then Begin
             If Ch = #8 Then Begin If Length(TmpNick) > 0 Then Delete(TmpNick, Length(TmpNick), 1); End
             Else TmpNick := TmpNick + Ch;
           End;
        4: If Length(TmpPass) < 20 Then Begin
             If Ch = #8 Then Begin If Length(TmpPass) > 0 Then Delete(TmpPass, Length(TmpPass), 1); End
             Else TmpPass := TmpPass + Ch;
           End;
      End;
    End;
  Until MenuDone;

  DrawScreen;
  DrawStatus;
End;

// ====================================================================
// Network — Teleconference
// ====================================================================

Procedure TAnsiEditor2.DoConnect;
Var PortNum: Word; Code: Integer;
Begin
  Val(NetPort, PortNum, Code);
  If Code <> 0 Then PortNum := 8000;

  NetCanvas := TPDCanvas.Create(CANVAS_W, CANVAS_H);

  If NetMode = 1 Then Begin
    { Server mode }
    NetServer := TPDNetServer.Create(NetCanvas);
    NetServer.OnChat := OnNetChat;
    NetServer.OnUserJoin := OnNetJoin;
    NetServer.OnUserLeave := OnNetLeave;
    If NetServer.Start(PortNum) Then Begin
      Connected := True;
      AddChat('Server started on port ' + NetPort);
    End Else Begin
      AddChat('ERROR: Cannot start server on port ' + NetPort);
      NetServer.Free;
      NetServer := Nil;
      NetCanvas.Free;
      NetCanvas := Nil;
    End;
  End Else Begin
    { Client mode }
    NetClient := TPDNetClient.Create(NetCanvas);
    NetClient.OnChat := OnNetChat;
    NetClient.OnUpdate := OnNetUpdate;
    If NetClient.Connect(NetHost, PortNum, NetNick, NetPass) Then Begin
      Connected := True;
      AddChat('Connected to ' + NetHost + ':' + NetPort);
      { Canvas sync happens via OnNetUpdate callback when server
        sends the full canvas state to this new client. }
    End Else Begin
      AddChat('ERROR: Cannot connect to ' + NetHost + ':' + NetPort);
      NetClient.Free;
      NetClient := Nil;
      NetCanvas.Free;
      NetCanvas := Nil;
    End;
  End;
End;

Procedure TAnsiEditor2.DoDisconnect;
Begin
  If NetServer <> Nil Then Begin NetServer.Free; NetServer := Nil; End;
  If NetClient <> Nil Then Begin NetClient.Free; NetClient := Nil; End;
  If NetCanvas <> Nil Then Begin NetCanvas.Free; NetCanvas := Nil; End;
  Connected := False;
  NetMode := 0;
  AddChat('Disconnected');
End;

Procedure TAnsiEditor2.ProcessNetwork;
{ Called from main loop — non-blocking poll for network data.
  Callbacks handle canvas updates (OnNetUpdate), chat (OnNetChat),
  and user events (OnNetJoin/OnNetLeave). }
Begin
  If Not Connected Then Exit;

  If NetMode = 1 Then Begin
    If NetServer <> Nil Then NetServer.Poll;
  End Else Begin
    If NetClient <> Nil Then NetClient.Poll;
  End;
End;

Procedure TAnsiEditor2.SendCharPlace(X, Y: Integer; Ch: Char; Attr: Byte);
{ Broadcast a local edit to all connected users. }
Var El: TPDCanvasElement;
Begin
  If Not Connected Then Exit;
  If NetCanvas = Nil Then Exit;

  El.Ch.Ch := Ord(Ch);
  El.Attr.Init(Attr);
  NetCanvas.Elements[X - 1, Y - 1] := El;

  If NetMode = 1 Then Begin
    { Server: canvas updated, clients will get it on next poll }
    { TODO: build update message and SendToAll }
  End Else Begin
    If NetClient <> Nil Then NetClient.SendUpdate(X - 1, Y - 1, X - 1, Y - 1);
  End;
End;

Procedure TAnsiEditor2.AddChat(Msg: String);
Begin
  If ChatCount < 50 Then Inc(ChatCount)
  Else Begin
    Move(ChatBuf[2], ChatBuf[1], SizeOf(ChatBuf[1]) * 49);
  End;
  ChatBuf[ChatCount] := Copy(Msg, 1, 79);

  { If on chat page, update display }
  If ChatPage Then DrawChatPage;
End;

Procedure TAnsiEditor2.DrawChatPage;
{ Draw the full chat window (page 1) }
Var Y, Offset, StartLine: Integer;
Begin
  { Title bar }
  Console.WriteXY(1, 1, $1F,
    StrPadR(' Chat' + StrRep(' ', 30) +
    'ALT+C=Canvas  /who /nick /quit', 80, ' '));

  { Chat scrollback — fill rows 2-22 from bottom up }
  StartLine := ChatCount - 21;
  If StartLine < 1 Then StartLine := 1;

  For Y := 2 to 22 Do Begin
    Offset := StartLine + (Y - 2);
    If (Offset >= 1) and (Offset <= ChatCount) Then
      Console.WriteXY(1, Y, $07, StrPadR(' ' + ChatBuf[Offset], 80, ' '))
    Else
      Console.WriteXY(1, Y, $07, StrRep(' ', 80));
  End;

  { Separator }
  Console.WriteXY(1, 23, $08, StrRep(#196, 80));

  { Input line }
  Console.WriteXY(1, 24, $0F, StrPadR(' > ' + ChatInput, 80, ' '));

  { Help bar }
  Console.WriteXY(1, 25, $70,
    StrPadR(' Type message + ENTER to send.  /who /nick /kick /save /quit', 80, ' '));

  { Position cursor at end of input }
  Console.CursorXY(4 + Length(ChatInput), 24);
End;

Procedure TAnsiEditor2.FlipPage;
Begin
  ChatPage := Not ChatPage;
  If ChatPage Then Begin
    ChatInput := '';
    DrawChatPage;
  End Else Begin
    DrawScreen;
    DrawStatus;
    DrawHelpBar;
  End;
End;

Procedure TAnsiEditor2.OnNetChat(const From, Text: String);
Begin
  AddChat('<' + From + '> ' + Text);
  { Flash on canvas status bar if not on chat page }
  If Not ChatPage Then Begin
    NotifyMsg := Copy('<' + From + '> ' + Text, 1, 60);
    NotifyTime := TimerSeconds;
    NotifyActive := True;
    DrawStatus;
  End;
End;

Procedure TAnsiEditor2.OnNetJoin(Index: Integer; const Alias: String; Level: TUserLevel);
Begin
  AddChat('*** ' + Alias + ' joined');
End;

Procedure TAnsiEditor2.OnNetLeave(Index: Integer; const Alias: String; Level: TUserLevel);
Begin
  AddChat('*** ' + Alias + ' left');
End;

Procedure TAnsiEditor2.OnNetUpdate(X1, Y1, X2, Y2: Integer);
{ Remote user edited the canvas — copy from NetCanvas to local Canvas and redraw }
Var X, Y: Integer; El: TPDCanvasElement;
Begin
  If NetCanvas = Nil Then Exit;
  For Y := Y1 to Y2 Do
    For X := X1 to X2 Do
      If (X >= 0) and (X < CANVAS_W) and (Y >= 0) and (Y < CANVAS_H) Then Begin
        El := NetCanvas.Elements[X, Y];
        Canvas[Y + 1, X + 1].Ch := Chr(El.Ch.Ch);
        Canvas[Y + 1, X + 1].Attr := El.Attr.ToByte;
        If Not ChatPage Then DrawCell(X + 1, Y + 1);
      End;
End;

Procedure TAnsiEditor2.ProcessChatKey;
{ Handle keyboard input on the chat page }
Var
  Ch        : Char;
  Cmd       : String;
  Params    : String;
  SpPos     : Integer;
  WhoIdx    : Integer;
  WhoUser   : TPDNetUser;
  KickFound : Boolean;
Begin
  If Not Keyboard.KeyWait(50) Then Exit;

  Ch := Keyboard.ReadKey;

  Case Ch of
    #0: Begin { Extended keys }
      Ch := Keyboard.ReadKey;
      Case Ch of
        #46: FlipPage;     { ALT+C = back to canvas }
        #31: ServerSetup;  { ALT+S = server setup }
      End;
    End;
    #13: Begin { ENTER = send message or process command }
      If ChatInput = '' Then Exit;

      If ChatInput[1] = '/' Then Begin
        { Parse /command }
        Cmd := '';
        Params := '';
        SpPos := Pos(' ', ChatInput);
        If SpPos > 0 Then Begin
          Cmd := Copy(ChatInput, 2, SpPos - 2);
          Params := Copy(ChatInput, SpPos + 1, 255);
        End Else
          Cmd := Copy(ChatInput, 2, 255);

        Cmd := StrUpper(Cmd);

        If Cmd = 'HELP' Then Begin
          AddChat('--- Commands ---');
          AddChat('  /help          Show this help');
          AddChat('  /who           Show connected users');
          AddChat('  /nick <name>   Change your display name');
          AddChat('  /kick <user>   Kick user (host only)');
          AddChat('  /save          Save canvas to file');
          AddChat('  /quit          Return to canvas');
          AddChat('  /disconnect    Disconnect from session');
          AddChat('---');
        End Else
        If Cmd = 'QUIT' Then Begin
          FlipPage;  { back to canvas }
          ChatInput := '';
          Exit;
        End Else
        If Cmd = 'DISCONNECT' Then Begin
          DoDisconnect;
        End Else
        If Cmd = 'WHO' Then Begin
          AddChat('--- Connected Users ---');
          If Connected Then Begin
            If NetMode = 1 Then Begin
              { Server: list from NetServer }
              AddChat('  * ' + NetNick + ' (host)');
              For WhoIdx := 0 to PD_MAX_USERS - 1 Do Begin
                WhoUser := NetServer.GetUser(WhoIdx);
                If WhoUser.Active Then
                  AddChat('    ' + WhoUser.Alias + ' (level ' + IntToStr(Ord(WhoUser.Level)) + ')');
              End;
            End Else Begin
              { Client: list from NetClient }
              For WhoIdx := 0 to PD_MAX_USERS - 1 Do Begin
                WhoUser := NetClient.GetUser(WhoIdx);
                If WhoUser.Active Then
                  AddChat('    ' + WhoUser.Alias + ' (level ' + IntToStr(Ord(WhoUser.Level)) + ')');
              End;
            End;
          End Else
            AddChat('  Not connected');
          AddChat('---');
        End Else
        If Cmd = 'NICK' Then Begin
          If Params <> '' Then Begin
            NetNick := Params;
            AddChat('Nick changed to ' + NetNick);
            { Note: nick change only takes effect on next connect }
            { Protocol does not support mid-session nick change }
          End Else
            AddChat('Usage: /nick <name>');
        End Else
        If Cmd = 'KICK' Then Begin
          If NetMode <> 1 Then
            AddChat('Only the host can kick users')
          Else If Params <> '' Then Begin
            KickFound := False;
            If NetServer <> Nil Then
              For WhoIdx := 0 to PD_MAX_USERS - 1 Do Begin
                WhoUser := NetServer.GetUser(WhoIdx);
                If WhoUser.Active and (StrUpper(WhoUser.Alias) = StrUpper(Params)) Then Begin
                  NetServer.KickUser(WhoIdx, 'Kicked by host');
                  AddChat('Kicked ' + Params);
                  KickFound := True;
                  Break;
                End;
              End;
            If Not KickFound Then AddChat('User not found: ' + Params);
          End Else
            AddChat('Usage: /kick <user>');
        End Else
        If Cmd = 'SAVE' Then Begin
          If FileName = '' Then
            AddChat('No filename. Use SaveAs from ESC menu first.')
          Else Begin
            SaveFile;
            AddChat('Saved to ' + FileName);
          End;
        End Else
          AddChat('Unknown command: /' + Cmd);
      End Else Begin
        { Regular chat message }
        If Connected Then Begin
          AddChat('<' + NetNick + '> ' + ChatInput);
          If NetClient <> Nil Then
            NetClient.SendChat(ChatInput);
          { TODO: server broadcast }
        End Else
          AddChat('Not connected — message not sent');
      End;

      ChatInput := '';
      DrawChatPage;
    End;
    #8: Begin { Backspace }
      If Length(ChatInput) > 0 Then Begin
        Delete(ChatInput, Length(ChatInput), 1);
        Console.WriteXY(1, 24, $0F, StrPadR(' > ' + ChatInput, 80, ' '));
        Console.CursorXY(4 + Length(ChatInput), 24);
      End;
    End;
    #27: FlipPage;  { ESC = back to canvas }
  Else
    { Regular character — add to input }
    If (Ch >= ' ') and (Length(ChatInput) < 72) Then Begin
      ChatInput := ChatInput + Ch;
      Console.WriteXY(1, 24, $0F, StrPadR(' > ' + ChatInput, 80, ' '));
      Console.CursorXY(4 + Length(ChatInput), 24);
    End;
  End;
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
              Case Code of
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
  SF: File;
  SauceBuf: Array[0..128] of Byte;
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
    While (Length(Line) > 0) And (Line[Length(Line)] = ' ') Do SetLength(Line, Length(Line) - 1);
    WriteLn(F, Line);
  End;

  Close(F);

  { 1.12: Write SAUCE record unless /NOSAUCE }
  If Not NoSAUCE Then Begin
    Assign(SF, FileName);
    {$I-} Reset(SF, 1); {$I+}
    If IOResult = 0 Then Begin
      Seek(SF, FileSize(SF));
      { SAUCE record: 128 bytes }
      FillChar(SauceBuf, SizeOf(SauceBuf), 0);
      SauceBuf[0] := 26;  { EOF marker }
      Move('SAUCE', SauceBuf[1], 5);
      SauceBuf[6] := Ord('0'); SauceBuf[7] := Ord('0');  { version 00 }
      { DataType=1 (Character), FileType=1 (ANSi) }
      SauceBuf[94] := 1;  { DataType }
      SauceBuf[95] := 1;  { FileType }
      SauceBuf[96] := Lo(CANVAS_W); SauceBuf[97] := Hi(CANVAS_W);  { TInfo1 = width }
      SauceBuf[98] := Lo(CANVAS_H); SauceBuf[99] := Hi(CANVAS_H);  { TInfo2 = height }
      If ICEMode Then SauceBuf[104] := 1;  { TFlags: iCE colors }
      BlockWrite(SF, SauceBuf, 129);
      Close(SF);
    End;
  End;

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
             'S:S Select|F:F Fill|C:C Copy|P:P Paste|M:M Move|H:H Flip Horiz|V:V Flip Vert|R:R Mirror|T:T Center|E:E Erase|X:X Clear');
           Case Ch of
             'S': BlockSelect;
             'F': BlockFill;
             'C': BlockCopy;
             'P': BlockPaste;
             'M': BlockMove;
             'H': BlockFlipH;
             'V': BlockFlipV;
             'R': BlockMirror;
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
      #72: Begin { Up }
        If DrawMode Then DoLineDraw(0, -1)
        Else If CurY > 1 Then Dec(CurY);
      End;
      #80: Begin { Down }
        If DrawMode Then DoLineDraw(0, 1)
        Else If CurY < CANVAS_H Then Inc(CurY);
      End;
      #75: Begin { Left }
        If DrawMode Then DoLineDraw(-1, 0)
        Else If CurX > 1 Then Dec(CurX);
      End;
      #77: Begin { Right }
        If DrawMode Then DoLineDraw(1, 0)
        Else If CurX < CANVAS_W Then Inc(CurX);
      End;
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
      #64: InsertLine;     { F6 = Insert line }
      #65: DeleteLine;     { F7 = Delete line }
      #31: ServerSetup;    { ALT+S = Server/Client setup }
      #46: FlipPage;       { ALT+C = flip canvas/chat page }
    End;
  End Else
    Case Ch of
      #09: Begin { Tab = cycle line draw style }
        LineStyle := (LineStyle + 1) mod LINE_SETS;
        DrawStatus;
      End;
      #27: DoMenu;
      #2:  BlockSelect;        { Ctrl-B }
      #26: PopUndo;            { Ctrl-Z = Undo }
      #25: DoRedo;             { Ctrl-Y = Redo }
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
      ' '..#255: Begin
        If Connected and (Ch = '/') Then Begin
          ChatInput := '/';  { pre-fill / for command entry }
          FlipPage;
        End Else
          PlaceChar(Ch);
      End;
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
    If Not ChatPage Then MoveCursor;
    Console.BufFlush;
    If Connected Then ProcessNetwork;
    If ChatPage Then
      ProcessChatKey
    Else Begin
      { Fade chat notification after 3 seconds }
      If NotifyActive and (TimerSeconds - NotifyTime >= 3) Then Begin
        NotifyActive := False;
        DrawStatus;
      End;
      ProcessKey;
    End;
  Until Done;
End;

Procedure TAnsiEditor2.Cleanup;
Var I: Integer;
Begin
  If Connected Then DoDisconnect;
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
