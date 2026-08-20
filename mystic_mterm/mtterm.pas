{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }
{$MODE OBJFPC}
{$H+}
unit mtterm;
{ Terminal view — scrollable text display with ANSI parsing }

interface

uses Objects, Drivers, Views;

const
  TermCols = 80;
  TermRows = 25;
  ScrollBack = 1000;

type
  TTermCell = record
    Ch: Char;
    Attr: Byte;
  end;

  TTermBuffer = array[0..ScrollBack - 1, 0..TermCols - 1] of TTermCell;

  PTermView = ^TTermView;
  TTermView = object(TView)
    Buffer: ^TTermBuffer;
    CurX, CurY: Integer;
    TopLine: Integer;
    TotalLines: Integer;
    CurAttr: Byte;
    { ANSI state machine }
    AnsiState: Integer;  { 0=normal, 1=ESC, 2=CSI }
    AnsiParams: String;
    RIPActive: Boolean;
    RIPBuf: String;
    RIPParser: Pointer;  { ^TRIPParser — forward ref, created on demand }
    constructor Init(var Bounds: TRect);
    destructor Done; virtual;
    procedure Draw; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure ProcessByte(B: Byte);
    procedure AddLine(const S: String);
    procedure LoadANSIFile(const FName: String);
    procedure LoadRIPFile(const FName: String);
    procedure PutChar(Ch: Char);
    procedure NewLine;
    procedure ScrollUp;
    procedure ProcessANSI(Ch: Char);
    procedure ExecuteCSI;
    procedure ProcessRIP(Ch: Char);
    procedure ClearScreen;
  end;

implementation

uses SysUtils, mtrip;

constructor TTermView.Init(var Bounds: TRect);
begin
  inherited Init(Bounds);
  GrowMode := gfGrowHiX or gfGrowHiY;
  { Not selectable — keys go to app first }
  New(Buffer);
  FillChar(Buffer^, SizeOf(TTermBuffer), 0);
  CurX := 0; CurY := 0;
  TopLine := 0; TotalLines := 1;
  CurAttr := $07;
  AnsiState := 0;
  AnsiParams := '';
  RIPActive := False;
  RIPBuf := '';
end;

destructor TTermView.Done;
begin
  Dispose(Buffer);
  inherited Done;
end;

procedure TTermView.Draw;
var
  X, Y, BufY: Integer;
  B: TDrawBuffer;
  C: TTermCell;
begin
  for Y := 0 to Size.Y - 1 do begin
    BufY := TopLine + Y;
    MoveChar(B, ' ', $07, Size.X);
    if (BufY >= 0) and (BufY < ScrollBack) then
      for X := 0 to Size.X - 1 do
        if X < TermCols then begin
          C := Buffer^[BufY mod ScrollBack, X];
          if C.Ch >= ' ' then
            MoveChar(B[X], C.Ch, C.Attr, 1)
          else
            MoveChar(B[X], ' ', C.Attr, 1);
        end;
    WriteLine(0, Y, Size.X, 1, B);
  end;
end;

procedure TTermView.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evKeyDown then begin
    case Event.KeyCode of
      kbPgUp: begin
        Dec(TopLine, Size.Y);
        if TopLine < 0 then TopLine := 0;
        DrawView;
        ClearEvent(Event);
      end;
      kbPgDn: begin
        Inc(TopLine, Size.Y);
        if TopLine > TotalLines - Size.Y then
          TopLine := TotalLines - Size.Y;
        if TopLine < 0 then TopLine := 0;
        DrawView;
        ClearEvent(Event);
      end;
    end;
  end;
end;

procedure TTermView.ProcessByte(B: Byte);
var Ch: Char;
begin
  Ch := Chr(B);

  { Check for RIP start: !|  }
  if RIPActive then begin
    ProcessRIP(Ch);
    Exit;
  end;

  if (Ch = '!') then begin
    { Could be RIP start — buffer it }
    RIPBuf := '!';
    Exit;
  end;

  if (RIPBuf = '!') and (Ch = '|') then begin
    RIPActive := True;
    RIPBuf := '!|';
    Exit;
  end;

  if RIPBuf <> '' then begin
    { Not RIP — flush buffer }
    ProcessANSI(RIPBuf[1]);
    RIPBuf := '';
  end;

  ProcessANSI(Ch);
end;

procedure TTermView.ProcessANSI(Ch: Char);
begin
  case AnsiState of
    0: begin { Normal }
      case Ch of
        #27: AnsiState := 1;
        #13: CurX := 0;
        #10: NewLine;
        #8:  if CurX > 0 then Dec(CurX);
        #7:  ; { Bell — ignore }
      else
        PutChar(Ch);
      end;
    end;
    1: begin { ESC received }
      if Ch = '[' then begin
        AnsiState := 2;
        AnsiParams := '';
      end else
        AnsiState := 0;
    end;
    2: begin { CSI — collecting params }
      if (Ch >= '0') and (Ch <= '?') then
        AnsiParams := AnsiParams + Ch
      else begin
        AnsiParams := AnsiParams + Ch;
        ExecuteCSI;
        AnsiState := 0;
      end;
    end;
  end;
end;

procedure TTermView.ExecuteCSI;
var
  Cmd: Char;
  P: String;
  N, M: Integer;
  Parts: array[0..9] of Integer;
  NumParts, I, Code: Integer;
  S: String;
begin
  if Length(AnsiParams) = 0 then Exit;
  Cmd := AnsiParams[Length(AnsiParams)];
  P := Copy(AnsiParams, 1, Length(AnsiParams) - 1);

  { Parse semicolon-separated params }
  NumParts := 0;
  while (P <> '') and (NumParts < 10) do begin
    I := Pos(';', P);
    if I = 0 then begin
      Val(P, Parts[NumParts], Code);
      if Code <> 0 then Parts[NumParts] := 0;
      Inc(NumParts);
      P := '';
    end else begin
      S := Copy(P, 1, I - 1);
      Val(S, Parts[NumParts], Code);
      if Code <> 0 then Parts[NumParts] := 0;
      Inc(NumParts);
      Delete(P, 1, I);
    end;
  end;

  if NumParts = 0 then begin Parts[0] := 0; NumParts := 1; end;

  case Cmd of
    'A': begin { Cursor Up }
      N := Parts[0]; if N = 0 then N := 1;
      Dec(CurY, N); if CurY < 0 then CurY := 0;
    end;
    'B': begin { Cursor Down }
      N := Parts[0]; if N = 0 then N := 1;
      Inc(CurY, N); if CurY >= TermRows then CurY := TermRows - 1;
    end;
    'C': begin { Cursor Forward }
      N := Parts[0]; if N = 0 then N := 1;
      Inc(CurX, N); if CurX >= TermCols then CurX := TermCols - 1;
    end;
    'D': begin { Cursor Back }
      N := Parts[0]; if N = 0 then N := 1;
      Dec(CurX, N); if CurX < 0 then CurX := 0;
    end;
    'H', 'f': begin { Cursor Position }
      if NumParts >= 2 then begin
        CurY := Parts[0] - 1; CurX := Parts[1] - 1;
      end else begin
        CurY := Parts[0] - 1; CurX := 0;
      end;
      if CurX < 0 then CurX := 0;
      if CurY < 0 then CurY := 0;
      if CurX >= TermCols then CurX := TermCols - 1;
      if CurY >= TermRows then CurY := TermRows - 1;
    end;
    'J': begin { Erase Display }
      if Parts[0] = 2 then ClearScreen;
    end;
    'K': begin { Erase Line }
      for I := CurX to TermCols - 1 do begin
        Buffer^[(TopLine + CurY) mod ScrollBack, I].Ch := ' ';
        Buffer^[(TopLine + CurY) mod ScrollBack, I].Attr := CurAttr;
      end;
    end;
    'm': begin { SGR — Set Graphics Rendition }
      for I := 0 to NumParts - 1 do begin
        N := Parts[I];
        case N of
          0: CurAttr := $07;
          1: CurAttr := CurAttr or $08;  { Bold }
          5: CurAttr := CurAttr or $80;  { Blink }
          7: CurAttr := ((CurAttr and $0F) shl 4) or ((CurAttr and $F0) shr 4);
          30..37: CurAttr := (CurAttr and $F8) or (N - 30);
          40..47: CurAttr := (CurAttr and $8F) or ((N - 40) shl 4);
        end;
      end;
    end;
    's': begin { Save cursor }
    end;
    'u': begin { Restore cursor }
    end;
  end;

  DrawView;
end;

procedure TTermView.ProcessRIP(Ch: Char);
begin
  case Ch of
    #13, #10: begin
      { End of RIP command — dispatch }
      { TODO: Parse RIPBuf and execute BGI commands }
      RIPActive := False;
      RIPBuf := '';
    end;
    '\': begin
      { Line continuation — next line continues this command }
    end;
  else
    RIPBuf := RIPBuf + Ch;
  end;
end;

procedure TTermView.PutChar(Ch: Char);
var Line: Integer;
begin
  if CurX >= TermCols then begin
    CurX := 0;
    NewLine;
  end;
  Line := (TopLine + CurY) mod ScrollBack;
  Buffer^[Line, CurX].Ch := Ch;
  Buffer^[Line, CurX].Attr := CurAttr;
  Inc(CurX);
  DrawView;
end;

procedure TTermView.NewLine;
begin
  Inc(CurY);
  CurX := 0;
  if CurY >= Size.Y then begin
    ScrollUp;
    CurY := Size.Y - 1;
  end;
  if TopLine + CurY >= TotalLines then
    TotalLines := TopLine + CurY + 1;
end;

procedure TTermView.ScrollUp;
var X: Integer;
begin
  Inc(TopLine);
  { Clear new line }
  for X := 0 to TermCols - 1 do begin
    Buffer^[(TopLine + Size.Y - 1) mod ScrollBack, X].Ch := ' ';
    Buffer^[(TopLine + Size.Y - 1) mod ScrollBack, X].Attr := $07;
  end;
  DrawView;
end;

procedure TTermView.ClearScreen;
var X, Y: Integer;
begin
  for Y := 0 to TermRows - 1 do
    for X := 0 to TermCols - 1 do begin
      Buffer^[(TopLine + Y) mod ScrollBack, X].Ch := ' ';
      Buffer^[(TopLine + Y) mod ScrollBack, X].Attr := CurAttr;
    end;
  CurX := 0; CurY := 0;
  DrawView;
end;

procedure TTermView.AddLine(const S: String);
var I: Integer;
begin
  for I := 1 to Length(S) do
    ProcessByte(Ord(S[I]));
  ProcessByte(13);
  ProcessByte(10);
end;

procedure TTermView.LoadANSIFile(const FName: String);
var
  F: File;
  Buf: array[0..4095] of Byte;
  N: Integer;
begin
  if not FileExists(FName) then begin
    AddLine('File not found: ' + FName);
    Exit;
  end;
  ClearScreen;
  Assign(F, FName);
  Reset(F, 1);
  repeat
    BlockRead(F, Buf, SizeOf(Buf), N);
    if N > 0 then
      for N := 0 to N - 1 do
        ProcessByte(Buf[N]);
  until N = 0;
  Close(F);
end;

procedure TTermView.LoadRIPFile(const FName: String);
var
  T: Text;
  Line: String;
  I: Integer;
begin
  if not FileExists(FName) then begin
    AddLine('File not found: ' + FName);
    Exit;
  end;
  ClearScreen;
  if RIPParser = nil then
    RIPParser := TRIPParser.Create;
  TRIPParser(RIPParser).Reset;
  Assign(T, FName);
  {$I-} Reset(T); {$I+}
  if IOResult <> 0 then begin
    AddLine('Cannot open: ' + FName);
    Exit;
  end;
  while not Eof(T) do begin
    ReadLn(T, Line);
    { RIP lines start with !| — feed to parser }
    if (Length(Line) >= 2) and (Line[1] = '!') and (Line[2] = '|') then
      TRIPParser(RIPParser).ProcessCommand(Line)
    else begin
      { Non-RIP lines are plain text — send through ANSI parser }
      for I := 1 to Length(Line) do
        ProcessByte(Ord(Line[I]));
    end;
  end;
  Close(T);
  AddLine('');
  AddLine('RIP file loaded: ' + FName);
end;

end.
