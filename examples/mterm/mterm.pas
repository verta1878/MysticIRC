{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }

Program mterm;
{ mterm — Mystic Terminal
  DOS-first RIP/ANSI terminal emulator.
  MDL Console/Keyboard shell (replaces Free Vision). }

{$H+}

Uses
  SysUtils,
  m_Strings,
  m_DateTime,
  mtphone,
  {$IFDEF WINDOWS}
    m_Input_Windows,
    m_Output_Windows
  {$ENDIF}
  {$IFDEF UNIX}
    m_Input_Linux,
    m_Output_Linux
  {$ENDIF}
  ;

Const
  TERM_W  = 80;
  TERM_H  = 25;
  MENU_Y  = 1;
  VIEW_Y1 = 2;
  VIEW_Y2 = 23;
  STATUS_Y = 24;
  HELP_Y   = 25;

  mtermVersion = '0.2';
  mtermBuild   = '2026.08.16';
  mtermCrew    = 'verta1878 / sysop/0 / evga / kiddo / wrench';

  TERM_COLS = 80;
  TERM_ROWS = 22;    { VIEW_Y2 - VIEW_Y1 + 1 }
  SCROLLBACK = 500;

Type
  TTermCell = Record
    Ch   : Char;
    Attr : Byte;
  End;

Var
  Console  : {$IFDEF WINDOWS} TOutputWindows {$ELSE} TOutputLinux {$ENDIF};
  Keyboard : {$IFDEF WINDOWS} TInputWindows {$ELSE} TInputLinux {$ENDIF};

  { Terminal cell buffer — circular scrollback }
  Buffer   : Array[0..SCROLLBACK - 1, 0..TERM_COLS - 1] of TTermCell;
  BufTop   : Integer;   { first visible line in ring }
  TotalLines: Integer;  { total lines written }

  { Cursor }
  CurX, CurY : Integer;  { 0-based within viewport }
  CurAttr    : Byte;
  SavedX, SavedY: Integer;

  { ANSI parser state }
  AnsiState  : Integer;  { 0=normal, 1=ESC, 2=CSI }
  AnsiParams : String[80];

  { Scroll region }
  ScrollTop  : Integer;  { top of scroll region (0-based) }
  ScrollBot  : Integer;  { bottom of scroll region (0-based) }
  LineWrap   : Boolean;  { line wrap mode }

  { Response buffer — queued responses to send when connected }
  ResponseBuf : String;

  { Text scrollback for AddLine (status messages) }
  MsgLines   : Array[1..500] of String[79];
  MsgCount   : Integer;

  { State }
  Connected  : Boolean;
  RIPMode    : Boolean;
  Capturing  : Boolean;
  Done       : Boolean;
  ActivePage : Byte;  { 0=terminal, 1=settings }

  { Connection info }
  ConnHost   : String[40];
  ConnPort   : Word;
  ConnType   : String[8];   { TCP, SERIAL, FOSSIL, LOCAL }
  ConnBaud   : LongInt;
  ConnStart  : LongInt;     { unix timestamp of connect }
  BytesIn    : LongInt;
  BytesOut   : LongInt;

{ ====================================================================
  Drawing
  ==================================================================== }

Procedure DrawMenuBar;
Begin
  Console.WriteXY(1, MENU_Y, $70,
    StrPadR(' mterm  F2=Conn F3=Disc F4=Phone F5=Send F6=Recv F9=RIP ALT+X=Exit', TERM_W, ' '));
End;

Procedure DrawStatusBar;
Var
  Left, Right: String;
  Elapsed, H, M, S: LongInt;
Begin
  { Left side: connection status + mode }
  If Connected Then Begin
    Left := ' ' + ConnType + ' ' + ConnHost;
    If ConnType = 'TCP' Then
      Left := Left + ':' + strI2S(ConnPort);
    If ConnType = 'SERIAL' Then
      Left := Left + ' ' + strI2S(ConnBaud) + 'bps';
  End Else
    Left := ' OFFLINE';

  If RIPMode Then Left := Left + ' RIP'
  Else Left := Left + ' ANSI';

  If Capturing Then Left := Left + ' CAP';

  { Right side: elapsed time + bytes }
  If Connected Then Begin
    Elapsed := TimerSeconds - ConnStart;
    H := Elapsed div 3600;
    M := (Elapsed mod 3600) div 60;
    S := Elapsed mod 60;
    Right := strI2S(BytesIn) + '/' + strI2S(BytesOut) + 'b ' +
             strZero(H) + ':' + strZero(M) + ':' + strZero(S) + ' ';
  End Else
    Right := 'v' + mtermVersion + ' ';

  { Pad left to fill, then overlay right }
  Left := StrPadR(Left, TERM_W - Length(Right), ' ') + Right;

  Console.WriteXY(1, STATUS_Y, $1F, Left);
End;

Procedure DrawHelpBar;
Begin
  Console.WriteXY(1, HELP_Y, $30,
    StrPadR(' ^B=Conn ^D=Disc ^P=Phone ^R=RIP ALT+A=ANSI ALT+C=Cap ALT+O=Cfg', TERM_W, ' '));
End;

Procedure DrawTerminal;
Var
  Y, X, BufLine: Integer;
  C: TTermCell;
Begin
  For Y := 0 to TERM_ROWS - 1 Do Begin
    BufLine := (BufTop + Y) mod SCROLLBACK;
    For X := 0 to TERM_COLS - 1 Do Begin
      C := Buffer[BufLine, X];
      Console.WriteXY(X + 1, Y + VIEW_Y1, C.Attr, C.Ch);
    End;
  End;
End;

{ ====================================================================
  ANSI Terminal Engine
  ==================================================================== }

Procedure TermScrollUp;
Var X: Integer;
Begin
  Inc(BufTop);
  If BufTop >= SCROLLBACK Then BufTop := 0;
  { Clear new bottom line }
  For X := 0 to TERM_COLS - 1 Do Begin
    Buffer[(BufTop + TERM_ROWS - 1) mod SCROLLBACK, X].Ch := ' ';
    Buffer[(BufTop + TERM_ROWS - 1) mod SCROLLBACK, X].Attr := $07;
  End;
  Inc(TotalLines);
End;

Procedure TermNewLine;
Begin
  Inc(CurY);
  CurX := 0;
  If CurY >= TERM_ROWS Then Begin
    TermScrollUp;
    CurY := TERM_ROWS - 1;
  End;
End;

Procedure TermPutChar(Ch: Char);
Var Line: Integer;
Begin
  If CurX >= TERM_COLS Then Begin
    If LineWrap Then Begin
      CurX := 0;
      TermNewLine;
    End Else
      CurX := TERM_COLS - 1; { Stay at right edge }
  End;
  Line := (BufTop + CurY) mod SCROLLBACK;
  Buffer[Line, CurX].Ch := Ch;
  Buffer[Line, CurX].Attr := CurAttr;
  Inc(CurX);
End;

Procedure TermClearScreen;
Var X, Y: Integer;
Begin
  For Y := 0 to TERM_ROWS - 1 Do
    For X := 0 to TERM_COLS - 1 Do Begin
      Buffer[(BufTop + Y) mod SCROLLBACK, X].Ch := ' ';
      Buffer[(BufTop + Y) mod SCROLLBACK, X].Attr := CurAttr;
    End;
  CurX := 0;
  CurY := 0;
End;

Procedure TermClearLine(Mode: Integer);
Var X, Line, XStart, XEnd: Integer;
Begin
  Line := (BufTop + CurY) mod SCROLLBACK;
  Case Mode of
    0: Begin XStart := CurX; XEnd := TERM_COLS - 1; End;  { cursor to end }
    1: Begin XStart := 0; XEnd := CurX; End;               { start to cursor }
    2: Begin XStart := 0; XEnd := TERM_COLS - 1; End;      { whole line }
  Else Exit;
  End;
  For X := XStart to XEnd Do Begin
    Buffer[Line, X].Ch := ' ';
    Buffer[Line, X].Attr := CurAttr;
  End;
End;

Procedure ExecuteCSI;
Var
  Cmd: Char;
  P: String;
  Parts: Array[0..9] of Integer;
  NumParts, I, Code, N: Integer;
  S: String;
Begin
  If Length(AnsiParams) = 0 Then Exit;
  Cmd := AnsiParams[Length(AnsiParams)];
  P := Copy(AnsiParams, 1, Length(AnsiParams) - 1);

  { Strip ? prefix (private mode indicator) — save it for h/l handlers }
  If (Length(P) > 0) and (P[1] = '?') Then
    Delete(P, 1, 1);

  { Parse semicolon-separated params }
  NumParts := 0;
  While (P <> '') and (NumParts < 10) Do Begin
    I := Pos(';', P);
    If I = 0 Then Begin
      Val(P, Parts[NumParts], Code);
      If Code <> 0 Then Parts[NumParts] := 0;
      Inc(NumParts);
      P := '';
    End Else Begin
      S := Copy(P, 1, I - 1);
      Val(S, Parts[NumParts], Code);
      If Code <> 0 Then Parts[NumParts] := 0;
      Inc(NumParts);
      Delete(P, 1, I);
    End;
  End;

  If NumParts = 0 Then Begin Parts[0] := 0; NumParts := 1; End;

  Case Cmd of
    'A': Begin { Cursor Up }
      N := Parts[0]; If N = 0 Then N := 1;
      Dec(CurY, N); If CurY < 0 Then CurY := 0;
    End;
    'B': Begin { Cursor Down }
      N := Parts[0]; If N = 0 Then N := 1;
      Inc(CurY, N); If CurY >= TERM_ROWS Then CurY := TERM_ROWS - 1;
    End;
    'C': Begin { Cursor Forward }
      N := Parts[0]; If N = 0 Then N := 1;
      Inc(CurX, N); If CurX >= TERM_COLS Then CurX := TERM_COLS - 1;
    End;
    'D': Begin { Cursor Back }
      N := Parts[0]; If N = 0 Then N := 1;
      Dec(CurX, N); If CurX < 0 Then CurX := 0;
    End;
    'H', 'f': Begin { Cursor Position }
      If NumParts >= 2 Then Begin
        CurY := Parts[0] - 1; CurX := Parts[1] - 1;
      End Else Begin
        CurY := Parts[0] - 1; CurX := 0;
      End;
      If CurX < 0 Then CurX := 0;
      If CurY < 0 Then CurY := 0;
      If CurX >= TERM_COLS Then CurX := TERM_COLS - 1;
      If CurY >= TERM_ROWS Then CurY := TERM_ROWS - 1;
    End;
    'J': Begin { Erase Display }
      Case Parts[0] of
        0: Begin { Cursor to end }
          TermClearLine(0);
          For I := CurY + 1 to TERM_ROWS - 1 Do Begin
            CurY := I; TermClearLine(2);
          End;
        End;
        1: Begin { Start to cursor }
          For I := 0 to CurY - 1 Do Begin
            CurY := I; TermClearLine(2);
          End;
          TermClearLine(1);
        End;
        2: TermClearScreen;
      End;
    End;
    'K': TermClearLine(Parts[0]);
    'm': Begin { SGR }
      For I := 0 to NumParts - 1 Do Begin
        N := Parts[I];
        Case N of
          0: CurAttr := $07;
          1: CurAttr := CurAttr or $08;
          5: CurAttr := CurAttr or $80;
          7: CurAttr := ((CurAttr and $0F) shl 4) or ((CurAttr and $F0) shr 4);
          22: CurAttr := CurAttr and $F7; { Normal intensity }
          25: CurAttr := CurAttr and $7F; { Blink off }
          30..37: CurAttr := (CurAttr and $F8) or (N - 30);
          40..47: CurAttr := (CurAttr and $8F) or ((N - 40) shl 4);
        End;
      End;
    End;
    's': Begin SavedX := CurX; SavedY := CurY; End;
    'u': Begin CurX := SavedX; CurY := SavedY; End;
    '@': Begin { Insert spaces }
      N := Parts[0]; If N = 0 Then N := 1;
      { Shift chars right from cursor, insert spaces }
      For I := TERM_COLS - 1 downto CurX + N Do
        Buffer[(BufTop + CurY) mod SCROLLBACK, I] :=
          Buffer[(BufTop + CurY) mod SCROLLBACK, I - N];
      For I := CurX to CurX + N - 1 Do
        If I < TERM_COLS Then Begin
          Buffer[(BufTop + CurY) mod SCROLLBACK, I].Ch := ' ';
          Buffer[(BufTop + CurY) mod SCROLLBACK, I].Attr := CurAttr;
        End;
    End;
    'P': Begin { Delete characters }
      N := Parts[0]; If N = 0 Then N := 1;
      For I := CurX to TERM_COLS - N - 1 Do
        Buffer[(BufTop + CurY) mod SCROLLBACK, I] :=
          Buffer[(BufTop + CurY) mod SCROLLBACK, I + N];
      For I := TERM_COLS - N to TERM_COLS - 1 Do Begin
        Buffer[(BufTop + CurY) mod SCROLLBACK, I].Ch := ' ';
        Buffer[(BufTop + CurY) mod SCROLLBACK, I].Attr := CurAttr;
      End;
    End;
    'L': Begin { Insert lines }
      N := Parts[0]; If N = 0 Then N := 1;
      { Scroll lines down from cursor, insert blank lines }
      For I := ScrollBot downto CurY + N Do
        Buffer[(BufTop + I) mod SCROLLBACK] :=
          Buffer[(BufTop + I - N) mod SCROLLBACK];
      For I := CurY to CurY + N - 1 Do
        If I <= ScrollBot Then
          For Code := 0 to TERM_COLS - 1 Do Begin
            Buffer[(BufTop + I) mod SCROLLBACK, Code].Ch := ' ';
            Buffer[(BufTop + I) mod SCROLLBACK, Code].Attr := CurAttr;
          End;
    End;
    'M': Begin { Delete lines }
      N := Parts[0]; If N = 0 Then N := 1;
      For I := CurY to ScrollBot - N Do
        Buffer[(BufTop + I) mod SCROLLBACK] :=
          Buffer[(BufTop + I + N) mod SCROLLBACK];
      For I := ScrollBot - N + 1 to ScrollBot Do
        For Code := 0 to TERM_COLS - 1 Do Begin
          Buffer[(BufTop + I) mod SCROLLBACK, Code].Ch := ' ';
          Buffer[(BufTop + I) mod SCROLLBACK, Code].Attr := CurAttr;
        End;
    End;
    'S': Begin { Scroll up }
      N := Parts[0]; If N = 0 Then N := 1;
      For I := 1 to N Do TermScrollUp;
    End;
    'n': Begin { Device status report }
      Case Parts[0] of
        5: ResponseBuf := ResponseBuf + #27 + '[0n';  { OK status }
        6: ResponseBuf := ResponseBuf + #27 + '[' +
           strI2S(CurY + 1) + ';' + strI2S(CurX + 1) + 'R'; { Cursor pos }
      End;
    End;
    'c': Begin { Device attribute report — VT100 with AVO }
      ResponseBuf := ResponseBuf + #27 + '[?1;2c';
    End;
    'r': Begin { Set scrolling region }
      If NumParts >= 2 Then Begin
        ScrollTop := Parts[0] - 1;
        ScrollBot := Parts[1] - 1;
        If ScrollTop < 0 Then ScrollTop := 0;
        If ScrollBot >= TERM_ROWS Then ScrollBot := TERM_ROWS - 1;
        If ScrollTop > ScrollBot Then Begin
          ScrollTop := 0; ScrollBot := TERM_ROWS - 1;
        End;
      End Else Begin
        ScrollTop := 0;
        ScrollBot := TERM_ROWS - 1;
      End;
      CurX := 0; CurY := 0;
    End;
    'h': Begin { Set mode }
      If (Length(AnsiParams) > 1) and (AnsiParams[1] = '?') Then Begin
        { Private mode }
        Case Parts[0] of
          7: LineWrap := True;
        End;
      End;
    End;
    'l': Begin { Reset mode }
      If (Length(AnsiParams) > 1) and (AnsiParams[1] = '?') Then Begin
        Case Parts[0] of
          7: LineWrap := False;
        End;
      End;
    End;
    '!': Begin { RIP auto-sense }
      { ESC[! or ESC[0! = query, ESC[1! = disable RIP, ESC[2! = enable RIP }
      Case Parts[0] of
        0: ; { Query — would send RIPSCRIP015400 back }
        1: RIPMode := False;
        2: RIPMode := True;
      End;
    End;
  End;
End;

Procedure TermProcessByte(B: Byte);
Var Ch: Char;
Begin
  Ch := Chr(B);

  Case AnsiState of
    0: Begin { Normal }
      Case Ch of
        #27: AnsiState := 1;
        #13: CurX := 0;
        #10: TermNewLine;
        #8:  If CurX > 0 Then Dec(CurX);
        #7:  ; { Bell }
        #9:  CurX := (CurX + 8) and (not 7); { Tab }
      Else
        TermPutChar(Ch);
      End;
    End;
    1: Begin { ESC received }
      If Ch = '[' Then Begin
        AnsiState := 2;
        AnsiParams := '';
      End Else Begin
        Case Ch of
          'D': Begin { Index — cursor down, scroll if at bottom }
            Inc(CurY);
            If CurY >= TERM_ROWS Then Begin
              TermScrollUp;
              CurY := TERM_ROWS - 1;
            End;
          End;
          'E': Begin { Next Line — col 0 + index }
            CurX := 0;
            Inc(CurY);
            If CurY >= TERM_ROWS Then Begin
              TermScrollUp;
              CurY := TERM_ROWS - 1;
            End;
          End;
          '7': Begin SavedX := CurX; SavedY := CurY; End; { DEC Save }
          '8': Begin CurX := SavedX; CurY := SavedY; End; { DEC Restore }
          'c': Begin { Reset terminal — clear screen + reset attrs }
            CurX := 0; CurY := 0; CurAttr := $07;
            SavedX := 0; SavedY := 0;
            AnsiState := 0; AnsiParams := '';
            ScrollTop := 0; ScrollBot := TERM_ROWS - 1;
            LineWrap := True;
          End;
        End;
        AnsiState := 0;
      End;
    End;
    2: Begin { CSI collecting }
      If (Ch >= '0') and (Ch <= '?') Then
        AnsiParams := AnsiParams + Ch
      Else Begin
        AnsiParams := AnsiParams + Ch;
        ExecuteCSI;
        AnsiState := 0;
      End;
    End;
  End;
End;

Procedure TermInit;
Var X, Y: Integer;
Begin
  BufTop := 0;
  TotalLines := 0;
  CurX := 0;
  CurY := 0;
  CurAttr := $07;
  SavedX := 0;
  SavedY := 0;
  AnsiState := 0;
  AnsiParams := '';
  ScrollTop := 0;
  ScrollBot := TERM_ROWS - 1;
  LineWrap := True;
  ResponseBuf := '';
  For Y := 0 to SCROLLBACK - 1 Do
    For X := 0 to TERM_COLS - 1 Do Begin
      Buffer[Y, X].Ch := ' ';
      Buffer[Y, X].Attr := $07;
    End;
End;

Procedure DrawScreen;
Begin
  DrawMenuBar;
  DrawTerminal;
  DrawStatusBar;
  DrawHelpBar;
End;

Procedure AddLine(S: String);
Var I: Integer;
Begin
  For I := 1 to Length(S) Do
    TermProcessByte(Ord(S[I]));
  TermProcessByte(13);
  TermProcessByte(10);
  If ActivePage = 0 Then DrawTerminal;
End;

{ ====================================================================
  Dialogs (ansiedit-style Console.WriteXY popups)
  ==================================================================== }

Function InputDialog(Title, Prompt: String; Var Value: String): Boolean;
Const
  DX = 15; DY = 8; DW = 50; DH = 7;
Var
  Ch: Char;
  DialogDone: Boolean;
Begin
  Result := False;

  Console.WriteXY(DX, DY, $1F, #218 + StrPadR(#196 + ' ' + Title + ' ' + #196, DW-2, #196) + #191);
  Console.WriteXY(DX, DY+1, $1F, #179 + StrRep(' ', DW-2) + #179);
  Console.WriteXY(DX, DY+2, $1F, #179 + ' ' + StrPadR(Prompt, 15, ' ') + StrPadR(Value, DW-19, ' ') + ' ' + #179);
  Console.WriteXY(DX, DY+3, $1F, #179 + StrRep(' ', DW-2) + #179);
  Console.WriteXY(DX, DY+4, $1F, #179 + '  ENTER=OK  ESC=Cancel' + StrRep(' ', DW-25) + #179);
  Console.WriteXY(DX, DY+5, $1F, #192 + StrRep(#196, DW-2) + #217);
  Console.WriteXY(DX, DY+6, $1F, StrRep(' ', DW));

  DialogDone := False;
  Repeat
    Console.WriteXY(DX+17, DY+2, $0F, StrPadR(Value, DW-19, ' '));
    Console.CursorXY(DX+17+Length(Value), DY+2);
    Console.BufFlush;

    Ch := Keyboard.ReadKey;
    Case Ch of
      #13: Begin Result := True; DialogDone := True; End;
      #27: DialogDone := True;
      #8:  If Length(Value) > 0 Then SetLength(Value, Length(Value) - 1);
    Else
      If (Ch >= ' ') and (Length(Value) < 60) Then
        Value := Value + Ch;
    End;
  Until DialogDone;

  DrawScreen;
End;

Procedure ConnectDialog;
Var
  Host, Port: String;
Begin
  Host := '';
  Port := '23';
  If InputDialog('Connect', 'Host:', Host) Then Begin
    If Pos(':', Host) > 0 Then Begin
      Port := Copy(Host, Pos(':', Host) + 1, 255);
      Host := Copy(Host, 1, Pos(':', Host) - 1);
    End;
    If InputDialog('Connect', 'Port:', Port) Then Begin
      AddLine('Connecting to ' + Host + ':' + Port + '...');
      { TODO: wire to mtconn TConnection }
      ConnHost  := Host;
      ConnPort  := StrToIntDef(Port, 23);
      ConnType  := 'TCP';
      ConnBaud  := 0;
      ConnStart := TimerSeconds;
      BytesIn   := 0;
      BytesOut  := 0;
      Connected := True;
      AddLine('Connected to ' + Host + ':' + Port);
      DrawStatusBar;
    End;
  End;
End;

Procedure SerialDialog;
Var
  ComPort, Baud: String;
Begin
  ComPort := '1';
  Baud := '38400';
  If InputDialog('Serial/Modem', 'COM Port:', ComPort) Then Begin
    If InputDialog('Serial/Modem', 'Baud:', Baud) Then Begin
      AddLine('Connecting COM' + ComPort + ' at ' + Baud + ' baud...');
      {$IFDEF GO32V2}
      ConnHost  := 'COM' + ComPort;
      ConnPort  := 0;
      ConnType  := 'SERIAL';
      ConnBaud  := StrToIntDef(Baud, 38400);
      ConnStart := TimerSeconds;
      BytesIn   := 0;
      BytesOut  := 0;
      Connected := True;
      AddLine('Connected COM' + ComPort + ' at ' + Baud);
      {$ELSE}
      AddLine('Serial requires DOS. Use Telnet on this platform.');
      {$ENDIF}
      DrawStatusBar;
    End;
  End;
End;

Procedure PhonebookDialog;
Var
  PB: TPhonebook;
  Idx: Integer;
Begin
  LoadPhonebook(PB);
  Idx := ShowPhonebook(PB, Console, Keyboard);
  DrawScreen;
  If Idx >= 0 Then Begin
    AddLine('Connecting to ' + PB.Entries[Idx].Name + '...');
    ConnHost  := PB.Entries[Idx].Host;
    ConnPort  := PB.Entries[Idx].Port;
    If PB.Entries[Idx].ConnType = 0 Then
      ConnType := 'TCP'
    Else
      ConnType := 'SERIAL';
    ConnBaud  := PB.Entries[Idx].Baud;
    ConnStart := TimerSeconds;
    BytesIn   := 0;
    BytesOut  := 0;
    RIPMode   := PB.Entries[Idx].TermType = 1;
    { TODO: actual TCP/serial connect }
    Connected := True;
    AddLine('Connected to ' + ConnHost + ':' + strI2S(ConnPort));
    DrawStatusBar;
  End;
End;

Procedure SendFileDialog;
Var FName: String;
Begin
  FName := '';
  If InputDialog('Send File', 'Filename:', FName) Then Begin
    If FName = '' Then Begin
      AddLine('No filename given.');
      Exit;
    End;
    If Not Connected Then Begin
      AddLine('Not connected.');
      Exit;
    End;
    AddLine('Sending: ' + FName);
    { TODO: wire to mtxfer Zmodem/Ymodem send }
    AddLine('TODO: File transfer not wired yet');
  End;
End;

Procedure RecvFileDialog;
Begin
  If Not Connected Then Begin
    AddLine('Not connected.');
    Exit;
  End;
  AddLine('Receiving file (Zmodem auto-detect)...');
  { TODO: wire to mtxfer Zmodem receive }
  AddLine('TODO: File transfer not wired yet');
End;

Procedure ViewANSIDialog;
Var
  FName: String;
  F: File;
  Buf: Array[0..4095] of Byte;
  N, I: Integer;
Begin
  FName := '';
  If InputDialog('View ANSI/RIP', 'Filename:', FName) Then Begin
    If FName = '' Then Exit;
    If Not FileExists(FName) Then Begin
      AddLine('File not found: ' + FName);
      Exit;
    End;
    TermClearScreen;
    Assign(F, FName);
    {$I-} Reset(F, 1); {$I+}
    If IOResult <> 0 Then Begin
      AddLine('Cannot open: ' + FName);
      Exit;
    End;
    Repeat
      BlockRead(F, Buf, SizeOf(Buf), N);
      For I := 0 to N - 1 Do
        TermProcessByte(Buf[I]);
    Until N = 0;
    Close(F);
    DrawTerminal;
    AddLine('');
    AddLine('Loaded: ' + FName);
  End;
End;

Procedure ShowAbout;
Const DX = 15; DY = 7; DW = 50; DH = 9;
Begin
  Console.WriteXY(DX, DY,   $5F, #218 + StrPadR(#196 + ' About mterm ' + #196, DW-2, #196) + #191);
  Console.WriteXY(DX, DY+1, $5F, #179 + StrRep(' ', DW-2) + #179);
  Console.WriteXY(DX, DY+2, $5E, #179 + StrPadR('  mterm v' + mtermVersion + ' (' + mtermBuild + ')', DW-2, ' ') + #179);
  Console.WriteXY(DX, DY+3, $5F, #179 + StrPadR('  RIP/ANSI Terminal Emulator', DW-2, ' ') + #179);
  Console.WriteXY(DX, DY+4, $5F, #179 + StrPadR('  FPC 2.6.4irc r3.1', DW-2, ' ') + #179);
  Console.WriteXY(DX, DY+5, $5F, #179 + StrRep(' ', DW-2) + #179);
  Console.WriteXY(DX, DY+6, $5E, #179 + StrPadR('  ' + mtermCrew, DW-2, ' ') + #179);
  Console.WriteXY(DX, DY+7, $5F, #179 + StrPadR('  GPLv3 — Press any key', DW-2, ' ') + #179);
  Console.WriteXY(DX, DY+8, $5F, #192 + StrRep(#196, DW-2) + #217);
  Console.BufFlush;
  Keyboard.ReadKey;
  DrawScreen;
End;

{ ====================================================================
  Settings Page (page 1)
  ==================================================================== }

Procedure DrawSettingsPage;
Var
  Y: Integer;
  Elapsed, H, M, S: LongInt;
Begin
  { Clear viewport }
  For Y := 1 to TERM_H Do
    Console.WriteXY(1, Y, $07, StrRep(' ', TERM_W));

  Console.WriteXY(1, 1, $1F, StrPadR(' Settings — ESC=Back', TERM_W, ' '));

  Console.WriteXY(3, 3, $0E, 'Connection');
  Console.WriteXY(5, 4, $07, 'Status:    ');
  If Connected Then Begin
    Console.WriteXY(16, 4, $0A, 'Connected');
    Console.WriteXY(5, 5, $07, 'Type:      ' + ConnType);
    Console.WriteXY(5, 6, $07, 'Host:      ' + ConnHost);
    If ConnType = 'TCP' Then
      Console.WriteXY(5, 7, $07, 'Port:      ' + strI2S(ConnPort));
    If ConnType = 'SERIAL' Then
      Console.WriteXY(5, 7, $07, 'Baud:      ' + strI2S(ConnBaud));
    Elapsed := TimerSeconds - ConnStart;
    H := Elapsed div 3600;
    M := (Elapsed mod 3600) div 60;
    S := Elapsed mod 60;
    Console.WriteXY(5, 8, $07, 'Elapsed:   ' + strZero(H) + ':' + strZero(M) + ':' + strZero(S));
    Console.WriteXY(5, 9, $07, 'Bytes I/O: ' + strI2S(BytesIn) + ' / ' + strI2S(BytesOut));
  End Else
    Console.WriteXY(16, 4, $08, 'Offline');

  Console.WriteXY(3, 11, $0E, 'Display');
  Console.WriteXY(5, 12, $07, 'RIP Mode:  ');
  If RIPMode Then Console.WriteXY(16, 12, $0B, 'ON')
  Else Console.WriteXY(16, 12, $07, 'OFF');

  Console.WriteXY(5, 13, $07, 'Capture:   ');
  If Capturing Then Console.WriteXY(16, 13, $0C, 'ON')
  Else Console.WriteXY(16, 13, $07, 'OFF');

  Console.WriteXY(3, 15, $0E, 'Terminal');
  Console.WriteXY(5, 16, $07, 'Scrollback: ' + strI2S(TotalLines) + ' lines');
  Console.WriteXY(5, 17, $07, 'Version:    mterm v' + mtermVersion);

  Console.WriteXY(1, 25, $70, StrPadR(' R=RIP  C=Capture  ESC=Back to terminal', TERM_W, ' '));
End;

Procedure FlipPage;
Begin
  ActivePage := 1 - ActivePage;
  If ActivePage = 1 Then
    DrawSettingsPage
  Else
    DrawScreen;
End;

{ ====================================================================
  Key Processing
  ==================================================================== }

Procedure ProcessKey;
Var Ch: Char;
Begin
  If Not Keyboard.KeyWait(50) Then Exit;

  Ch := Keyboard.ReadKey;

  Case Ch of
    #0: Begin { Extended key }
      Ch := Keyboard.ReadKey;
      Case Ch of
        #60: ConnectDialog;      { F2 }
        #61: Begin               { F3 = Disconnect }
          If Connected Then Begin
            Connected := False;
            AddLine('Disconnected.');
            DrawStatusBar;
          End;
        End;
        #62: PhonebookDialog;    { F4 }
        #63: SendFileDialog;     { F5 }
        #64: RecvFileDialog;     { F6 }
        #67: Begin               { F9 = Toggle RIP }
          RIPMode := Not RIPMode;
          If RIPMode Then AddLine('*** RIP mode ON')
          Else AddLine('*** RIP mode OFF');
          DrawStatusBar;
        End;
        #45: Done := True;       { ALT+X = Exit }
        #46: Begin               { ALT+C = Toggle capture }
          Capturing := Not Capturing;
          If Capturing Then AddLine('*** Capture ON')
          Else AddLine('*** Capture OFF');
          DrawStatusBar;
        End;
        #24: FlipPage;           { ALT+O = Settings }
        #30: ViewANSIDialog;     { ALT+A = View ANSI }
        #31: SendFileDialog;     { ALT+S = Send file }
        #19: RecvFileDialog;     { ALT+R = Recv file }
      End;
    End;
    #2:  ConnectDialog;          { CTRL+B }
    #4:  Begin                   { CTRL+D = Disconnect }
      Connected := False;
      AddLine('Disconnected.');
      DrawStatusBar;
    End;
    #16: PhonebookDialog;        { CTRL+P }
    #18: Begin                   { CTRL+R = Toggle RIP }
      RIPMode := Not RIPMode;
      If RIPMode Then AddLine('*** RIP mode ON')
      Else AddLine('*** RIP mode OFF');
      DrawStatusBar;
    End;
  Else
    { Regular character — send to connection if connected }
    If Connected Then Begin
      { TODO: send byte via connection }
    End;
  End;
End;

Procedure ProcessSettingsKey;
Var Ch: Char;
Begin
  If Not Keyboard.KeyWait(50) Then Exit;
  Ch := Keyboard.ReadKey;
  Case Ch of
    #0: Begin
      Ch := Keyboard.ReadKey;
      If Ch = #45 Then Done := True;  { ALT+X }
    End;
    #27: FlipPage;  { ESC = back to terminal }
    'R', 'r': Begin
      RIPMode := Not RIPMode;
      DrawSettingsPage;
    End;
    'C', 'c': Begin
      Capturing := Not Capturing;
      DrawSettingsPage;
    End;
  End;
End;

{ ====================================================================
  Main
  ==================================================================== }

Begin
  {$IFDEF WINDOWS}
    Console := TOutputWindows.Create(True);
    Keyboard := TInputWindows.Create;
  {$ENDIF}
  {$IFDEF UNIX}
    Console := TOutputLinux.Create(True);
    Keyboard := TInputLinux.Create;
  {$ENDIF}

  Connected  := False;
  RIPMode    := False;
  Capturing  := False;
  Done       := False;
  ActivePage := 0;
  ConnHost   := '';
  ConnPort   := 0;
  ConnType   := '';
  ConnBaud   := 0;
  ConnStart  := 0;
  BytesIn    := 0;
  BytesOut   := 0;
  MsgCount   := 0;

  TermInit;

  Console.ClearScreen;
  DrawScreen;

  AddLine('mterm v' + mtermVersion + ' — Mystic Terminal');
  AddLine('RIP/ANSI terminal for Mystic BBS');
  AddLine('');
  AddLine('F2=Connect  F4=Phonebook  F9=RIP  ALT+X=Exit');
  AddLine('');

  Repeat
    Console.BufFlush;
    If ActivePage = 0 Then
      ProcessKey
    Else
      ProcessSettingsKey;
  Until Done;

  Console.TextAttr := 7;
  Console.ClearScreen;
  Console.BufFlush;
  Console.Free;
  Keyboard.Free;
End.
