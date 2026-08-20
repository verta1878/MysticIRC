{$MODE OBJFPC}
{$H+}
unit mtrip;
{ mterm RIP Graphics — RIPscrip v1.54 command dispatcher
  Parses RIP commands and draws on terminal canvas.

  Copyright (C) 2026 FPC264IRC Contributors
  License: GPLv3 }

interface

uses mtripgfx;

type
  TRIPMouseField = record
    X1, Y1, X2, Y2: Integer;
    HostCmd: String[80];
    Active: Boolean;
  end;

  TRIPState = record
    Active: Boolean;
    Viewport: record X1, Y1, X2, Y2: Integer; end;
    TextWin: record X1, Y1, X2, Y2: Integer; end;
    FGColor: Byte;
    BGColor: Byte;
    FillStyle: Byte;
    FillColor: Byte;
    LineStyle: Byte;
    LineThick: Byte;
    UserPattern: Word;
    WriteMode: Byte;
    FontStyle: Byte;
    FontSize: Byte;
  end;

  TRIPParser = class
  private
    FState: TRIPState;
    FCanvas: TRIPCanvas;
    FClipData: array[0..639, 0..349] of Byte;
    FClipW, FClipH: Integer;
    FClipValid: Boolean;
    { Text region state (|1T / |1t / |1E) }
    FTextActive: Boolean;
    FTextX1, FTextY1, FTextX2, FTextY2: Integer;
    FTextCurY: Integer;  { current Y position in text region }
    { Text variables ($APP0$-$APP9$, user defined) }
    FVarNames: Array[0..31] of String[40];
    FVarValues: Array[0..31] of String[80];
    FVarCount: Integer;
    FMouseFields: array[0..127] of TRIPMouseField;
    FMouseCount: Integer;
    function ParseMegaNum(const S: String; Pos: Integer): Integer;
    procedure ExecCommand(const Cmd: String);
    { RIP commands }
    procedure CmdTextWindow(const P: String);
    procedure CmdViewport(const P: String);
    procedure CmdResetWindows;
    procedure CmdEraseWindow;
    procedure CmdEraseEOL;
    procedure CmdColor(const P: String);
    procedure CmdFillStyle(const P: String);
    procedure CmdLineStyle(const P: String);
    procedure CmdWriteMode(const P: String);
    procedure CmdFontStyle(const P: String);
    procedure CmdPixel(const P: String);
    procedure CmdLine(const P: String);
    procedure CmdRectangle(const P: String);
    procedure CmdBar(const P: String);
    procedure CmdCircle(const P: String);
    procedure CmdOval(const P: String);
    procedure CmdFilledOval(const P: String);
    procedure CmdArc(const P: String);
    procedure CmdPieSlice(const P: String);
    procedure CmdFill(const P: String);
    procedure CmdGotoXY(const P: String);
    procedure CmdHome;
    procedure CmdOutText(const P: String);
    procedure CmdOutTextXY(const P: String);
    procedure CmdMove(const P: String);
    procedure CmdButton(const P: String);
    procedure CmdMouseField(const P: String);
    procedure CmdKillMouseFields;
    procedure CmdBeginText(const P: String);
    procedure CmdGetImage(const P: String);
    procedure CmdPutImage(const P: String);
    procedure CmdPolyLine(const P: String);
    procedure CmdFilledPolygon(const P: String);
    procedure CmdBezier(const P: String);
    procedure CmdQuery(const P: String);
    procedure CmdCopyRegion(const P: String);
    procedure CmdLoadIcon(const P: String);
  public
    constructor Create;
    procedure ProcessCommand(const RIPLine: String);
    procedure ProcessFile(const FileName: String);
    procedure Reset;
    { Terminal features }
    function  MouseHitTest(X, Y: Integer): String;
    function  MouseFieldCount: Integer;
    
    property State: TRIPState read FState;
    property Canvas: TRIPCanvas read FCanvas;
    destructor Destroy; override;
  end;

implementation

uses SysUtils, Math, mtsound;

constructor TRIPParser.Create;
begin
  inherited;
  FCanvas := TRIPCanvas.Create;
  SoundInit;
  Reset;
end;

destructor TRIPParser.Destroy;
begin SoundShutdown; FCanvas.Free; inherited; end;

procedure TRIPParser.Reset;
var I: Integer;
begin
  FState.Active := True;
  FState.Viewport.X1 := 0;
  FState.Viewport.Y1 := 0;
  FState.Viewport.X2 := 639;
  FState.Viewport.Y2 := 349;
  FState.FGColor := 15;
  FState.BGColor := 0;
  FState.FillStyle := 1;
  FState.FillColor := 0;
  FState.LineStyle := 0;
  FState.LineThick := 1;
  FState.UserPattern := $FFFF;
  FState.WriteMode := 0;
  FState.FontStyle := 0;
  FState.FontSize := 1;
  FMouseCount := 0;
  FClipValid := False;
  FTextActive := False;
  FTextX1 := 0; FTextY1 := 0;
  FTextX2 := 0; FTextY2 := 0;
  FTextCurY := 0;
  FVarCount := 0;
  for I := 0 to 127 do FMouseFields[I].Active := False;
end;

function TRIPParser.ParseMegaNum(const S: String; Pos: Integer): Integer;
var Ch: Char; V: Integer;
begin
  Result := 0;
  if Pos > Length(S) then Exit;
  Ch := S[Pos];
  if (Ch >= '0') and (Ch <= '9') then V := Ord(Ch) - Ord('0')
  else if (Ch >= 'A') and (Ch <= 'Z') then V := Ord(Ch) - Ord('A') + 10
  else V := 0;
  Result := V;
  if Pos + 1 <= Length(S) then begin
    Ch := S[Pos + 1];
    if (Ch >= '0') and (Ch <= '9') then Result := Result * 36 + Ord(Ch) - Ord('0')
    else if (Ch >= 'A') and (Ch <= 'Z') then Result := Result * 36 + Ord(Ch) - Ord('A') + 10;
  end;
end;

procedure TRIPParser.ProcessCommand(const RIPLine: String);
{ Parse a RIP line — handles !| prefix and bare | separator.
  BUG FIX (backport): first command uses !| prefix, subsequent
  commands on the same line use bare | as separator.
  Also handles |! comment (skip to next |) and |# (no more). }
var I: Integer; Cmd: String;
begin
  if Length(RIPLine) < 3 then Exit;
  I := 1;
  while I <= Length(RIPLine) do begin
    { Find !| or bare | }
    if (I <= Length(RIPLine) - 1) and
       ((RIPLine[I] = '!') or (RIPLine[I] = #1) or (RIPLine[I] = #2)) and
       (RIPLine[I+1] = '|') then begin
      Inc(I, 2); { skip !| }
      Cmd := '';
      while (I <= Length(RIPLine)) and (RIPLine[I] <> '|') and
            not ((RIPLine[I] = '!') and (I < Length(RIPLine)) and (RIPLine[I+1] = '|')) do begin
        Cmd := Cmd + RIPLine[I]; Inc(I);
      end;
      if Length(Cmd) > 0 then begin
        if Cmd[1] = '!' then begin { |! comment — skip } end
        else if Cmd[1] = '#' then Exit { |# no more }
        else ExecCommand(Cmd);
      end;
    end else if (RIPLine[I] = '|') then begin
      Inc(I); { skip bare | }
      Cmd := '';
      while (I <= Length(RIPLine)) and (RIPLine[I] <> '|') and
            not ((RIPLine[I] = '!') and (I < Length(RIPLine)) and (RIPLine[I+1] = '|')) do begin
        Cmd := Cmd + RIPLine[I]; Inc(I);
      end;
      if Length(Cmd) > 0 then begin
        if Cmd[1] = '!' then begin { |! comment — skip } end
        else if Cmd[1] = '#' then Exit
        else ExecCommand(Cmd);
      end;
    end else
      Inc(I);
  end;
end;

procedure TRIPParser.ProcessFile(const FileName: String);
var
  F: Text;
  Line: String;
begin
  {$I-} Assign(F, FileName); System.Reset(F); {$I+}
  if IOResult <> 0 then Exit;
  While Not EOF(F) Do Begin
    ReadLn(F, Line);
    ProcessCommand(Line);
  End;
  Close(F);
end;

procedure TRIPParser.ExecCommand(const Cmd: String);
var Op: Char; Params, S, VarName, VarVal: String;
    I, J, K, Plane, Pix, RowBytes: Integer; Found: Boolean;
    ICNFile: File; ICNBuf: Array[0..79] of Byte;
begin
  if Length(Cmd) = 0 then Exit;
  Op := Cmd[1];
  Params := Copy(Cmd, 2, Length(Cmd) - 1);

  case Op of
    '*': CmdResetWindows;
    'w': CmdTextWindow(Params);
    'v': CmdViewport(Params);
    'e': CmdEraseWindow;
    'E': CmdEraseWindow;      { |E — Erase View (same as erase window) }
    'K': CmdEraseEOL;         { legacy mapping }
    '>': CmdEraseEOL;         { |> — Erase EOL (spec-correct) }
    'c': CmdColor(Params);
    'S': CmdFillStyle(Params);
    '=': CmdLineStyle(Params);  { |= — Line Style (spec-correct) }
    'W': CmdWriteMode(Params);  { |W — Write Mode (spec-correct) }
    'l': CmdPolyLine(Params);   { |l — Polyline (spec-correct, was LineStyle) }
    'Y': CmdFontStyle(Params);
    'X': CmdPixel(Params);
    'L': CmdLine(Params);
    'R': CmdRectangle(Params);
    'B': CmdBar(Params);
    'C': CmdCircle(Params);
    'O': CmdOval(Params);       { |O — Oval/Elliptical Arc }
    'V': CmdOval(Params);       { |V — Oval Arc (same as O per riplib) }
    'o': CmdFilledOval(Params);
    'A': CmdArc(Params);
    'I': CmdPieSlice(Params);
    'i': CmdPieSlice(Params);   { |i — Oval Pie Slice (same params as I) }
    'F': CmdFill(Params);
    'G': CmdGotoXY(Params);
    'g': CmdGotoXY(Params);     { |g — GotoXY Text (text cursor) }
    'H': CmdHome;
    'T': CmdOutText(Params);
    '@': CmdOutTextXY(Params);
    'M': CmdMove(Params);
    'm': CmdMove(Params);       { |m — Move (lowercase, same as M) }
    'P': CmdPolyLine(Params);
    'p': CmdFilledPolygon(Params);
    'Z': CmdBezier(Params);
    'a': begin { |a — One Palette: set single palette entry }
      if Length(Params) >= 4 then begin
        { color:2 value:2 — value is EGA64 index (0-63) }
        I := ParseMegaNum(Params, 1) and 15;
        J := ParseMegaNum(Params, 3) and 63;
        { EGA64 bit layout: bit5=r' bit4=g' bit3=b' bit2=R bit1=G bit0=B }
        { 2-bit RGB: combine high and low intensity bits }
        FCanvas.SetPaletteEntry(I,
          (((J shr 2) and 1) shl 1) or ((J shr 5) and 1),  { R }
          (((J shr 1) and 1) shl 1) or ((J shr 4) and 1),  { G }
          (((J shr 0) and 1) shl 1) or ((J shr 3) and 1)); { B }
      end;
    end;
    'Q': begin { |Q — Set All Palette: 16 entries, each EGA64 value:2 }
      if Length(Params) >= 32 then begin
        for I := 0 to 15 do begin
          J := ParseMegaNum(Params, 1 + I * 2) and 63;
          FCanvas.SetPaletteEntry(I,
            (((J shr 2) and 1) shl 1) or ((J shr 5) and 1),
            (((J shr 1) and 1) shl 1) or ((J shr 4) and 1),
            (((J shr 0) and 1) shl 1) or ((J shr 3) and 1));
        end;
      end;
    end;
    '1': begin { Two-char extended commands }
      if Length(Params) > 0 then case Params[1] of
        'B': begin { |1B — ButtonStyle: 22242222222222 = 28 chars }
          if Length(Params) >= 29 then begin { 1 + 28 params }
            FCanvas.BtnWid     := ParseMegaNum(Copy(Params,2,99), 1);
            FCanvas.BtnHgt     := ParseMegaNum(Copy(Params,2,99), 3);
            FCanvas.BtnOrient  := ParseMegaNum(Copy(Params,2,99), 5);
            FCanvas.BtnFlags   := ParseMegaNum(Copy(Params,2,99), 7) * 36 * 36 +
                                   ParseMegaNum(Copy(Params,2,99), 9);
            FCanvas.BtnBevSize := ParseMegaNum(Copy(Params,2,99), 11);
            FCanvas.BtnDFore   := ParseMegaNum(Copy(Params,2,99), 13) and 15;
            FCanvas.BtnBright  := ParseMegaNum(Copy(Params,2,99), 19) and 15;
            FCanvas.BtnDark    := ParseMegaNum(Copy(Params,2,99), 21) and 15;
            FCanvas.BtnSurface := ParseMegaNum(Copy(Params,2,99), 23) and 15;
            FCanvas.BtnCorner  := ParseMegaNum(Copy(Params,2,99), 25) and 15;
            FCanvas.BtnValid   := True;
          end;
        end;
        'U': CmdButton(Copy(Params, 2, Length(Params) - 1));
        'K': CmdKillMouseFields;
        'M': CmdMouseField(Copy(Params, 2, Length(Params) - 1));
        'T': CmdBeginText(Copy(Params, 2, Length(Params) - 1));
        't': begin { |1t — Region Text: justify:1 + text string }
          if FTextActive and (Length(Params) >= 2) then begin
            { Params[1] is '1' prefix, Params[2] is justify, rest is text }
            if Length(Params) >= 3 then begin
              { Draw text at FTextCurY using bitmap font }
              FCanvas.OutTextXY(FTextX1, FTextCurY,
                Copy(Params, 3, Length(Params) - 2));
              { Advance Y by font height (8 pixels for bitmap font) }
              Inc(FTextCurY, 8);
              { Clip to region bottom }
              if FTextCurY > FTextY2 then FTextCurY := FTextY2;
            end;
          end;
        end;
        'E': begin { |1E — End Text: close text region }
          FTextActive := False;
        end;
        'I': CmdLoadIcon(Copy(Params, 2, Length(Params) - 1));
        'W': begin { |1W — Write Icon: res:2 + filename }
          { Write clipboard to ICN file (BGI putimage format) }
          if FClipValid and (Length(Params) >= 4) then begin
            S := Copy(Params, 4, Length(Params) - 3);
            { Strip path for safety }
            While Pos('..', S) > 0 Do Delete(S, Pos('..', S), 2);
            While Pos('/', S) > 0 Do Delete(S, Pos('/', S), 1);
            While Pos('\', S) > 0 Do Delete(S, Pos('\', S), 1);
            If S <> '' Then Begin
              { ICN format: 2 bytes width-1, 2 bytes height-1, 2 bytes reserved,
                then 4 EGA bitplanes per row (blue, green, red, intensity) }
              Assign(ICNFile, S);
              {$I-} Rewrite(ICNFile, 1); {$I+}
              If IOResult = 0 Then Begin
                { Header: width-1, height-1, reserved }
                ICNBuf[0] := (FClipW - 1) and $FF;
                ICNBuf[1] := ((FClipW - 1) shr 8) and $FF;
                ICNBuf[2] := (FClipH - 1) and $FF;
                ICNBuf[3] := ((FClipH - 1) shr 8) and $FF;
                ICNBuf[4] := 0; ICNBuf[5] := 0;
                BlockWrite(ICNFile, ICNBuf, 6);
                { Write pixel data — 4 bitplanes per row }
                RowBytes := (FClipW + 7) div 8;
                For I := 0 to FClipH - 1 Do Begin
                  { 4 planes: blue(0), green(1), red(2), intensity(3) }
                  For Plane := 0 to 3 Do Begin
                    FillChar(ICNBuf, SizeOf(ICNBuf), 0);
                    For J := 0 to FClipW - 1 Do Begin
                      Pix := FClipData[J, I];
                      { EGA index: bit3=intensity, bit2=red, bit1=green, bit0=blue }
                      If (Pix and (1 shl Plane)) <> 0 Then
                        ICNBuf[J div 8] := ICNBuf[J div 8] or (128 shr (J mod 8));
                    End;
                    BlockWrite(ICNFile, ICNBuf, RowBytes);
                  End;
                End;
                Close(ICNFile);
              End;
            End;
          end;
        end;
        'G': CmdCopyRegion(Copy(Params, 2, Length(Params) - 1));
        'C': CmdGetImage(Copy(Params, 2, Length(Params) - 1));
        'P': CmdPutImage(Copy(Params, 2, Length(Params) - 1));
        'D': begin { |1D — Define: flags:3 res:2 text }
          { Parse: varname[,width]:?prompt?[default] }
          if Length(Params) >= 6 then begin
            { Skip prefix '1' + flags:3 + res:2 = 6 chars }
            S := Copy(Params, 6, Length(Params) - 5);
            { Extract variable name (up to comma or colon) }
            VarName := '';
            VarVal := '';
            J := 1;
            While (J <= Length(S)) and (S[J] <> ',') and (S[J] <> ':') and (S[J] <> '?') Do Begin
              VarName := VarName + S[J];
              Inc(J);
            End;
            { Skip to default value after last ? }
            K := Length(S);
            While (K > J) and (S[K] <> '?') Do Dec(K);
            If K > J Then
              VarVal := Copy(S, K + 1, Length(S) - K);
            { Store variable }
            If (VarName <> '') and (FVarCount < 32) Then Begin
              { Check for existing var with same name }
              Found := False;
              For I := 0 to FVarCount - 1 Do
                If FVarNames[I] = VarName Then Begin
                  FVarValues[I] := VarVal;
                  Found := True;
                  Break;
                End;
              If Not Found Then Begin
                FVarNames[FVarCount] := VarName;
                FVarValues[FVarCount] := VarVal;
                Inc(FVarCount);
              End;
            End;
          end;
        end;
        'R': begin { |1R — Read Scene: res:2 hor:2 vert:2 res2:2 filename }
          { Load and execute a local .RIP file }
          if Length(Params) >= 10 then begin
            S := Copy(Params, 10, Length(Params) - 9);
            { Strip path separators for safety }
            While Pos('..', S) > 0 Do Delete(S, Pos('..', S), 2);
            While Pos('/', S) > 0 Do Delete(S, Pos('/', S), 1);
            While Pos('\', S) > 0 Do Delete(S, Pos('\', S), 1);
            { Only allow .RIP extension }
            If (Length(S) > 4) and
               (UpperCase(Copy(S, Length(S) - 3, 4)) = '.RIP') Then Begin
              If FileExists(S) Then
                ProcessFile(S);
            End;
          end;
        end;
        'F': begin { |1F — File Query: mode:2 res:2 filename }
          { Check if file exists locally. In connected mode, would
            send response back to BBS. For now just check and store
            result in $FILEERR$ variable }
          if Length(Params) >= 6 then begin
            S := Copy(Params, 6, Length(Params) - 5);
            { Strip path for safety }
            While Pos('..', S) > 0 Do Delete(S, Pos('..', S), 2);
            While Pos('/', S) > 0 Do Delete(S, Pos('/', S), 1);
            While Pos('\', S) > 0 Do Delete(S, Pos('\', S), 1);
            { Store result in $FILEERR$ — 0=exists, 1=not found }
            If FileExists(S) Then VarVal := '0'
            Else VarVal := '1';
            { Set variable }
            Found := False;
            For I := 0 to FVarCount - 1 Do
              If FVarNames[I] = 'FILEERR' Then Begin
                FVarValues[I] := VarVal;
                Found := True; Break;
              End;
            If (Not Found) and (FVarCount < 32) Then Begin
              FVarNames[FVarCount] := 'FILEERR';
              FVarValues[FVarCount] := VarVal;
              Inc(FVarCount);
            End;
          end;
        end;
        'S': begin { |1S — Sound: res:2 filename (WAV/MID/MP3/OGG/MOD) }
          if Length(Params) >= 4 then begin
            S := Copy(Params, 4, Length(Params) - 3);
            { Strip path for safety }
            While Pos('..', S) > 0 Do Delete(S, Pos('..', S), 2);
            While Pos('/', S) > 0 Do Delete(S, Pos('/', S), 1);
            While Pos('\', S) > 0 Do Delete(S, Pos('\', S), 1);
            If S <> '' Then SoundPlay(S);
          end;
        end;
      end;
    end;
  end;
end;

{ RIP command implementations — store state, rendering done by terminal view }

procedure TRIPParser.CmdResetWindows;
begin Reset; FCanvas.Clear(0); end;

procedure TRIPParser.CmdTextWindow(const P: String);
{ |w X0(2) Y0(2) X1(2) Y1(2) WRAP(1) SIZE(1) — format 222211 = 10 chars }
begin
  if Length(P) >= 9 then begin
    FState.TextWin.X1 := ParseMegaNum(P, 1);
    FState.TextWin.Y1 := ParseMegaNum(P, 3);
    FState.TextWin.X2 := ParseMegaNum(P, 5);
    FState.TextWin.Y2 := ParseMegaNum(P, 7);
    { P[9] = wrap mode (1 digit), P[10] = size (1 digit) }
  end;
end;

procedure TRIPParser.CmdViewport(const P: String);
begin
  if Length(P) >= 8 then begin
    FState.Viewport.X1 := ParseMegaNum(P, 1);
    FState.Viewport.Y1 := ParseMegaNum(P, 3);
    FState.Viewport.X2 := ParseMegaNum(P, 5);
    FState.Viewport.Y2 := ParseMegaNum(P, 7);
    FCanvas.SetViewport(FState.Viewport.X1, FState.Viewport.Y1,
                        FState.Viewport.X2, FState.Viewport.Y2);
  end;
end;

procedure TRIPParser.CmdEraseWindow;
begin
  { |e — erase current viewport area }
  FCanvas.EraseView;
end;
procedure TRIPParser.CmdEraseEOL;
begin
  FCanvas.Bar(FCanvas.CurX, FCanvas.CurY, 639, FCanvas.CurY + 7);
end;

procedure TRIPParser.CmdColor(const P: String);
begin if Length(P) >= 2 then begin FState.FGColor := ParseMegaNum(P, 1); FCanvas.SetColor(FState.FGColor); end; end;

procedure TRIPParser.CmdFillStyle(const P: String);
begin
  if Length(P) >= 4 then begin
    FState.FillStyle := ParseMegaNum(P, 1);
    FState.FillColor := ParseMegaNum(P, 3);
    FCanvas.SetFillStyle(FState.FillStyle, FState.FillColor);
  end;
end;

procedure TRIPParser.CmdLineStyle(const P: String);
{ |= — Line Style: style:2 user_pat:4 thick:2 (8 chars total) }
begin
  if Length(P) >= 2 then FState.LineStyle := ParseMegaNum(P, 1);
  if Length(P) >= 6 then FState.UserPattern :=
    ParseMegaNum(P, 3) * 36 * 36 + ParseMegaNum(P, 5);
  if Length(P) >= 8 then FState.LineThick := ParseMegaNum(P, 7);
  { Pass thickness to canvas }
  FCanvas.SetLineStyle(FState.LineStyle);
end;

procedure TRIPParser.CmdWriteMode(const P: String);
begin if Length(P) >= 2 then FState.WriteMode := ParseMegaNum(P, 1); end;

procedure TRIPParser.CmdFontStyle(const P: String);
{ |Y FONT(2) DIR(2) SIZE(2) RES(2) }
var Font, Dir, Size: Integer;
begin
  if Length(P) >= 6 then begin
    Font := ParseMegaNum(P, 1);
    Dir := ParseMegaNum(P, 3);
    Size := ParseMegaNum(P, 5);
    FState.FontStyle := Font;
    FState.FontSize := Size;
    FCanvas.SetTextStyle(Font, Dir, Size);
  end;
end;

procedure TRIPParser.CmdPixel(const P: String); begin if Length(P)>=4 then FCanvas.PutPixel(ParseMegaNum(P,1), ParseMegaNum(P,3), FState.FGColor); end;
procedure TRIPParser.CmdLine(const P: String); begin if Length(P)>=8 then FCanvas.Line(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5), ParseMegaNum(P,7)); end;
procedure TRIPParser.CmdRectangle(const P: String); begin if Length(P)>=8 then FCanvas.Rectangle(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5), ParseMegaNum(P,7)); end;
procedure TRIPParser.CmdBar(const P: String); begin if Length(P)>=8 then FCanvas.Bar(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5), ParseMegaNum(P,7)); end;
procedure TRIPParser.CmdCircle(const P: String); begin if Length(P)>=6 then FCanvas.Circle(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5)); end;
procedure TRIPParser.CmdOval(const P: String); begin if Length(P)>=8 then FCanvas.Ellipse(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5), ParseMegaNum(P,7)); end;
procedure TRIPParser.CmdFilledOval(const P: String); begin if Length(P)>=8 then FCanvas.FilledEllipse(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5), ParseMegaNum(P,7)); end;
procedure TRIPParser.CmdArc(const P: String);
begin
  if Length(P) >= 10 then
    FCanvas.Arc(ParseMegaNum(P,1), ParseMegaNum(P,3),
                ParseMegaNum(P,5), ParseMegaNum(P,7), ParseMegaNum(P,9));
end;
procedure TRIPParser.CmdPieSlice(const P: String);
begin
  if Length(P) >= 10 then
    FCanvas.Arc(ParseMegaNum(P,1), ParseMegaNum(P,3),
                ParseMegaNum(P,5), ParseMegaNum(P,7), ParseMegaNum(P,9));
end;
procedure TRIPParser.CmdFill(const P: String); begin if Length(P)>=6 then FCanvas.FloodFill(ParseMegaNum(P,1), ParseMegaNum(P,3), ParseMegaNum(P,5)); end;
procedure TRIPParser.CmdGotoXY(const P: String);
begin
  if Length(P) >= 4 then begin
    FCanvas.CurX := ParseMegaNum(P, 1);
    FCanvas.CurY := ParseMegaNum(P, 3);
  end;
end;
procedure TRIPParser.CmdHome;
begin FCanvas.CurX := 0; FCanvas.CurY := 0; end;
procedure TRIPParser.CmdOutText(const P: String);
var S: String; I: Integer;
begin
  S := ''; I := 1;
  while (I <= Length(P)) and (P[I] <> '|') do begin S := S + P[I]; Inc(I); end;
  FCanvas.OutTextXY(FCanvas.CurX, FCanvas.CurY, S);
end;
procedure TRIPParser.CmdOutTextXY(const P: String);
var S: String; I: Integer;
begin
  if Length(P) >= 4 then begin
    S := ''; I := 5;
    while (I <= Length(P)) and (P[I] <> '|') do begin S := S + P[I]; Inc(I); end;
    FCanvas.OutTextXY(ParseMegaNum(P,1), ParseMegaNum(P,3), S);
  end;
end;
procedure TRIPParser.CmdMove(const P: String);
begin
  if Length(P) >= 4 then begin
    FCanvas.CurX := ParseMegaNum(P, 1);
    FCanvas.CurY := ParseMegaNum(P, 3);
  end;
end;
procedure TRIPParser.CmdButton(const P: String);
{ |1U X0(2) Y0(2) X1(2) Y1(2) HOTKEY(2) FLAGS(1) RES(1) TEXT }
var X1, Y1, X2, Y2, I, Bev: Integer;
    S, Lbl: String;
    OldFG: Byte;
begin
  if Length(P) >= 14 then begin
    X1 := ParseMegaNum(P,1); Y1 := ParseMegaNum(P,3);
    X2 := ParseMegaNum(P,5); Y2 := ParseMegaNum(P,7);
    OldFG := FCanvas.ForeColor;

    if FCanvas.BtnValid then begin
      { Draw surface }
      FCanvas.ForeColor := FCanvas.BtnSurface;
      FCanvas.Bar(X1, Y1, X2, Y2);
      { Bevel outside coords }
      Bev := FCanvas.BtnBevSize;
      if Bev < 1 then Bev := 1;
      if (FCanvas.BtnFlags and 512) <> 0 then begin
        if (FCanvas.BtnFlags and 32768) <> 0 then begin
          { SUNKEN }
          FCanvas.ForeColor := FCanvas.BtnDark;
          for I := 1 to Bev do begin
            FCanvas.Line(X1-I, Y1-I+1, X2+I, Y1-I+1);
            FCanvas.Line(X1-I, Y1-I+1, X1-I, Y2+I);
          end;
          FCanvas.ForeColor := FCanvas.BtnBright;
          for I := 1 to Bev do begin
            FCanvas.Line(X1-I, Y2+I, X2+I, Y2+I);
            FCanvas.Line(X2+I, Y1-I+1, X2+I, Y2+I);
          end;
        end else begin
          { RAISED }
          FCanvas.ForeColor := FCanvas.BtnBright;
          for I := 1 to Bev do begin
            FCanvas.Line(X1-I, Y1-I+1, X2+I, Y1-I+1);
            FCanvas.Line(X1-I, Y1-I+1, X1-I, Y2+I);
          end;
          FCanvas.ForeColor := FCanvas.BtnDark;
          for I := 1 to Bev do begin
            FCanvas.Line(X1-I, Y2+I, X2+I, Y2+I);
            FCanvas.Line(X2+I, Y1-I+1, X2+I, Y2+I);
          end;
        end;
        { CHISEL }
        if (FCanvas.BtnFlags and 8) <> 0 then begin
          FCanvas.ForeColor := FCanvas.BtnDark;
          FCanvas.Line(X1,Y1,X2,Y1); FCanvas.Line(X1,Y1,X1,Y2);
          FCanvas.ForeColor := FCanvas.BtnBright;
          FCanvas.Line(X1,Y2,X2,Y2); FCanvas.Line(X2,Y1,X2,Y2);
        end;
        { Corner pixels }
        FCanvas.PutPixelRaw(X1-Bev+FCanvas.ViewX1, Y1-Bev+1+FCanvas.ViewY1, FCanvas.BtnCorner);
        FCanvas.PutPixelRaw(X2+Bev+FCanvas.ViewX1, Y1-Bev+1+FCanvas.ViewY1, FCanvas.BtnCorner);
        FCanvas.PutPixelRaw(X1-Bev+FCanvas.ViewX1, Y2+Bev+FCanvas.ViewY1, FCanvas.BtnCorner);
        FCanvas.PutPixelRaw(X2+Bev+FCanvas.ViewX1, Y2+Bev+FCanvas.ViewY1, FCanvas.BtnCorner);
      end;
      FCanvas.ForeColor := FCanvas.BtnDFore;
    end else begin
      FCanvas.Bar(X1, Y1, X2, Y2);
    end;

    { Extract label }
    S := Copy(P, 15, Length(P)-14);
    I := Pos('<>', S);
    if I > 0 then begin Delete(S,1,I+1); I := Pos('<>',S); if I>0 then Lbl:=Copy(S,1,I-1) else Lbl:=S; end else Lbl:=S;
    if Length(Lbl) > 0 then
      FCanvas.OutTextXY(X1+((X2-X1-FCanvas.TextWidth(Lbl)) div 2),
                        Y1+((Y2-Y1-FCanvas.TextHeight) div 2), Lbl);
    FCanvas.ForeColor := OldFG;
  end;
end;
procedure TRIPParser.CmdMouseField(const P: String);
{ |1M X0(2) Y0(2) X1(2) Y1(2) HOTKEY(2) FLAGS(1) RES(1) TEXT<>HOSTCMD }
var I: Integer; S, HostCmd: String;
begin
  if (Length(P) >= 14) and (FMouseCount < 128) then begin
    FMouseFields[FMouseCount].X1 := ParseMegaNum(P, 1);
    FMouseFields[FMouseCount].Y1 := ParseMegaNum(P, 3);
    FMouseFields[FMouseCount].X2 := ParseMegaNum(P, 5);
    FMouseFields[FMouseCount].Y2 := ParseMegaNum(P, 7);
    { Extract host command from TEXT<>HOSTCMD }
    S := Copy(P, 15, Length(P) - 14);
    I := Pos('<>', S);
    if I > 0 then begin
      HostCmd := Copy(S, I + 2, Length(S));
      I := Pos('<>', HostCmd);
      if I > 0 then HostCmd := Copy(HostCmd, 1, I - 1);
    end else
      HostCmd := S;
    FMouseFields[FMouseCount].HostCmd := HostCmd;
    FMouseFields[FMouseCount].Active := True;
    Inc(FMouseCount);
  end;
end;

procedure TRIPParser.CmdKillMouseFields;
var I: Integer;
begin
  for I := 0 to FMouseCount - 1 do
    FMouseFields[I].Active := False;
  FMouseCount := 0;
end;
procedure TRIPParser.CmdBeginText(const P: String);
{ |1T — Begin Text: x1:2 y1:2 x2:2 y2:2 res:2 (10 chars) }
begin
  if Length(P) >= 8 then begin
    FTextX1 := ParseMegaNum(P, 1);
    FTextY1 := ParseMegaNum(P, 3);
    FTextX2 := ParseMegaNum(P, 5);
    FTextY2 := ParseMegaNum(P, 7);
    FTextCurY := FTextY1;
    FTextActive := True;
  end;
end;
procedure TRIPParser.CmdGetImage(const P: String);
var X1, Y1, X2, Y2, W, H, R, C: Integer;
begin
  if Length(P) >= 9 then begin
    X1:=ParseMegaNum(P,1); Y1:=ParseMegaNum(P,3);
    X2:=ParseMegaNum(P,5); Y2:=ParseMegaNum(P,7);
    W:=X2-X1+1; H:=Y2-Y1+1;
    if (W>0) and (W<=1024) and (H>0) and (H<=768) then begin
      FClipW:=W; FClipH:=H; FClipValid:=True;
      for R:=0 to H-1 do for C:=0 to W-1 do
        FClipData[C,R]:=FCanvas.GetPixelRaw(X1+C, Y1+R);
    end;
  end;
end;
procedure TRIPParser.CmdPutImage(const P: String);
var X1, Y1, Mode, R, C: Integer;
begin
  if (Length(P)>=6) and FClipValid then begin
    X1:=ParseMegaNum(P,1); Y1:=ParseMegaNum(P,3); Mode:=ParseMegaNum(P,5);
    for R:=0 to FClipH-1 do for C:=0 to FClipW-1 do
      case Mode of
        1: FCanvas.PutPixelRaw(X1+C, Y1+R, FCanvas.GetPixelRaw(X1+C,Y1+R) xor FClipData[C,R]);
      else FCanvas.PutPixelRaw(X1+C, Y1+R, FClipData[C,R]);
      end;
  end;
end;
procedure TRIPParser.CmdPolyLine(const P: String);
var Count, I, X1, Y1, X2, Y2: Integer;
begin
  if Length(P) >= 2 then begin
    Count:=ParseMegaNum(P,1);
    if (Count>=2) and (Length(P)>=2+Count*4) then begin
      X1:=ParseMegaNum(P,3); Y1:=ParseMegaNum(P,5);
      for I:=1 to Count-1 do begin
        X2:=ParseMegaNum(P,3+I*4); Y2:=ParseMegaNum(P,5+I*4);
        FCanvas.Line(X1,Y1,X2,Y2); X1:=X2; Y1:=Y2;
      end;
    end;
  end;
end;
procedure TRIPParser.CmdFilledPolygon(const P: String);
{ |p — Filled Polygon: count:2 then count pairs of x:2 y:2 }
var
  Count, I, J, Y, MinY, MaxY, Nodes, Swap: Integer;
  PX, PY: array[0..49] of Integer;
  NodeX: array[0..99] of Integer;
begin
  if Length(P) < 2 then Exit;
  Count := ParseMegaNum(P, 1);
  if Count < 3 then Exit;
  if Count > 50 then Count := 50;
  if Length(P) < 2 + Count * 4 then Exit;

  { Parse vertex coordinates }
  MinY := 9999; MaxY := -1;
  for I := 0 to Count - 1 do begin
    PX[I] := ParseMegaNum(P, 3 + I * 4);
    PY[I] := ParseMegaNum(P, 5 + I * 4);
    if PY[I] < MinY then MinY := PY[I];
    if PY[I] > MaxY then MaxY := PY[I];
  end;

  { Scanline fill }
  for Y := MinY to MaxY do begin
    Nodes := 0;
    J := Count - 1;
    for I := 0 to Count - 1 do begin
      if ((PY[I] < Y) and (PY[J] >= Y)) or
         ((PY[J] < Y) and (PY[I] >= Y)) then begin
        if Nodes < 100 then begin
          NodeX[Nodes] := PX[I] +
            (Y - PY[I]) * (PX[J] - PX[I]) div (PY[J] - PY[I]);
          Inc(Nodes);
        end;
      end;
      J := I;
    end;

    { Sort nodes }
    I := 0;
    while I < Nodes - 1 do begin
      if NodeX[I] > NodeX[I + 1] then begin
        Swap := NodeX[I];
        NodeX[I] := NodeX[I + 1];
        NodeX[I + 1] := Swap;
        if I > 0 then Dec(I) else Inc(I);
      end else
        Inc(I);
    end;

    { Fill between pairs }
    I := 0;
    while I < Nodes - 1 do begin
      for J := NodeX[I] to NodeX[I + 1] do
        FCanvas.PutPixel(J, Y, FState.FillColor);
      Inc(I, 2);
    end;
  end;

  { Draw outline }
  CmdPolyLine(P);
end;
procedure TRIPParser.CmdBezier(const P: String);
{ Bezier matched to JS: Floor() not Round(), explicit endpoint. Backport. }
var
  X1, Y1, X2, Y2, X3, Y3, X4, Y4, Count: Integer;
  T, T1, Step: Double;
  PX, PY, LX, LY: Integer;
begin
  if Length(P) < 18 then Exit;
  X1 := ParseMegaNum(P, 1); Y1 := ParseMegaNum(P, 3);
  X2 := ParseMegaNum(P, 5); Y2 := ParseMegaNum(P, 7);
  X3 := ParseMegaNum(P, 9); Y3 := ParseMegaNum(P, 11);
  X4 := ParseMegaNum(P, 13); Y4 := ParseMegaNum(P, 15);
  Count := ParseMegaNum(P, 17);
  if Count < 2 then Count := 20;
  LX := X1; LY := Y1;
  Step := 1.0 / Count;
  T := Step;
  while T < 1.0 do begin
    T1 := 1.0 - T;
    PX := Floor(T1*T1*T1*X1 + 3*T*T1*T1*X2 + 3*T*T*T1*X3 + T*T*T*X4);
    PY := Floor(T1*T1*T1*Y1 + 3*T*T1*T1*Y2 + 3*T*T*T1*Y3 + T*T*T*Y4);
    Canvas.Line(LX, LY, PX, PY);
    LX := PX; LY := PY;
    T := T + Step;
  end;
  Canvas.Line(LX, LY, X4, Y4);
end;
procedure TRIPParser.CmdQuery(const P: String);
begin { terminal query — respond with capabilities } end;
procedure TRIPParser.CmdCopyRegion(const P: String);
{ |1G — Copy Region: x0:2 y0:2 x1:2 y1:2 res:2 dest_line:2 (12 chars) }
var X0, Y0, X1, Y1, DestY, W, H, R, C: Integer;
    Pixel: Byte;
begin
  if Length(P) >= 12 then begin
    X0 := ParseMegaNum(P, 1);
    Y0 := ParseMegaNum(P, 3);
    X1 := ParseMegaNum(P, 5);
    Y1 := ParseMegaNum(P, 7);
    { P[9..10] is reserved }
    DestY := ParseMegaNum(P, 11);
    { Align X to 8-pixel boundaries per spec }
    X0 := (X0 div 8) * 8;
    X1 := ((X1 + 7) div 8) * 8 - 1;
    W := X1 - X0 + 1;
    H := Y1 - Y0 + 1;
    if (W <= 0) or (H <= 0) then Exit;
    { Check dest fits on screen }
    if (DestY < 0) or (DestY + H > 350) then Exit;
    { Copy — handle overlap by choosing direction }
    if DestY < Y0 then begin
      { Copy top-to-bottom }
      for R := 0 to H - 1 do
        for C := 0 to W - 1 do begin
          Pixel := FCanvas.GetPixelRaw(X0 + C, Y0 + R);
          FCanvas.PutPixelRaw(X0 + C, DestY + R, Pixel);
        end;
    end else begin
      { Copy bottom-to-top }
      for R := H - 1 downto 0 do
        for C := 0 to W - 1 do begin
          Pixel := FCanvas.GetPixelRaw(X0 + C, Y0 + R);
          FCanvas.PutPixelRaw(X0 + C, DestY + R, Pixel);
        end;
    end;
  end;
end;
procedure TRIPParser.CmdLoadIcon(const P: String);
var X1, Y1: Integer; FileName: String;
    F: File; IconBuf: array[0..65535] of Byte;
    IconSize: LongInt; IconW, IconH, IconBW, IconOfs: Integer;
    R, C, I: Integer; BP0, BP1, BP2, BP3, Pixel: Byte;
begin
  if Length(P) >= 9 then begin
    X1:=ParseMegaNum(P,1); Y1:=ParseMegaNum(P,3);
    FileName:=Copy(P, 10, Length(P)-9);
    while (Length(FileName)>0) and (FileName[Length(FileName)]<=' ') do Delete(FileName,Length(FileName),1);
    if FileExists('icons'+DirectorySeparator+FileName) then FileName:='icons'+DirectorySeparator+FileName;
    if not FileExists(FileName) then Exit;
    Assign(F, FileName);
    {$I-} System.Reset(F, 1); {$I+}
    if IOResult <> 0 then Exit;
    IconSize:=FileSize(F);
    if IconSize > SizeOf(IconBuf) then begin Close(F); Exit; end;
    BlockRead(F, IconBuf, IconSize); Close(F);
    IconW:=(IconBuf[1] shl 8 or IconBuf[0])+1;
    IconH:=(IconBuf[3] shl 8 or IconBuf[2])+1;
    if (IconW<=0) or (IconW>640) or (IconH<=0) or (IconH>350) then Exit;
    IconBW:=(IconW+7) div 8;
    for R:=0 to IconH-1 do begin
      IconOfs:=4+R*IconBW*4;
      for C:=0 to IconBW-1 do if IconOfs+C+IconBW*3 < IconSize then begin
        BP3:=IconBuf[IconOfs+C]; BP2:=IconBuf[IconOfs+C+IconBW];
        BP1:=IconBuf[IconOfs+C+IconBW*2]; BP0:=IconBuf[IconOfs+C+IconBW*3];
        for I:=7 downto 0 do begin
          Pixel:=((BP3 and 1) shl 3) or ((BP2 and 1) shl 2) or ((BP1 and 1) shl 1) or (BP0 and 1);
          BP3:=BP3 shr 1; BP2:=BP2 shr 1; BP1:=BP1 shr 1; BP0:=BP0 shr 1;
          if C*8+I < IconW then FCanvas.PutPixelRaw(X1+C*8+I, Y1+R, Pixel and 15);
        end;
      end;
    end;
  end;
end;

{ === Terminal Feature Methods === }

function TRIPParser.MouseHitTest(X, Y: Integer): String;
{ Check if pixel (X,Y) is inside any mouse field.
  Returns the host command string if hit, empty string if miss.
  Used by the terminal view to send commands on mouse click. }
var I: Integer;
begin
  Result := '';
  for I := 0 to FMouseCount - 1 do
    if FMouseFields[I].Active and
       (X >= FMouseFields[I].X1) and (X <= FMouseFields[I].X2) and
       (Y >= FMouseFields[I].Y1) and (Y <= FMouseFields[I].Y2) then begin
      Result := FMouseFields[I].HostCmd;
      Exit;
    end;
end;

function TRIPParser.MouseFieldCount: Integer;
begin
  Result := FMouseCount;
end;

end.
