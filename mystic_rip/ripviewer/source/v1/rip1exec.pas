{$MODE DELPHI}
{$H-}
Unit RIP1Exec;
{
  RIPscrip v1.54 Command Executor — 42-command dispatcher.
  Version-specific: v1.54 only.

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses SysUtils, RIPEngine, RIPDraw, RIPText, RIP1Parse;

Procedure ExecuteRIP(const Line: String);

Implementation

Procedure ExecuteRIP(const Line: String);
Var
  Pos  : Integer;
  Cmd  : TRIPCommand;
  X1, Y1, X2, Y2, R, C, I: Integer;
  NPts : Integer;
  BezPts  : Array[0..7] Of Integer;
  PolyPts : Array[0..1023] Of Integer;
  CmdPos  : Integer;
  DbgStr  : String;
Begin
  Pos := 1;
  While Pos <= Length(Line) Do Begin
    { Skip non-RIP text }
    If (Line[Pos] <> '!') Or (Pos + 1 > Length(Line)) Or (Line[Pos+1] <> '|') Then Begin
      Inc(Pos);
      Continue;
    End;
    
    { Save command position for debug }
    CmdPos := Pos;
    
    Cmd := ParseRIPCommand(Line, Pos);
    
    Case Cmd Of
      rcPixel: If Pos + 3 <= Length(Line) Then Begin
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        PutPixel(X1, Y1, Canvas.FG);
        Inc(Pos, 4);
      End;
      
      rcLine: If Pos + 7 <= Length(Line) Then Begin
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        X2 := DecodeMega2(Line, Pos + 4);
        Y2 := DecodeMega2(Line, Pos + 6);
        DrawLine(X1, Y1, X2, Y2, Canvas.FG);
        Inc(Pos, 8);
      End;
      
      rcRectangle: If Pos + 7 <= Length(Line) Then Begin
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        X2 := DecodeMega2(Line, Pos + 4);
        Y2 := DecodeMega2(Line, Pos + 6);
        DrawRect(X1, Y1, X2, Y2, Canvas.FG);
        Inc(Pos, 8);
      End;
      
      rcBar: If Pos + 7 <= Length(Line) Then Begin
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        X2 := DecodeMega2(Line, Pos + 4);
        Y2 := DecodeMega2(Line, Pos + 6);
        FillRect(X1, Y1, X2, Y2, Canvas.FillColor);
        Inc(Pos, 8);
      End;
      
      rcCircle: If Pos + 5 <= Length(Line) Then Begin
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        R  := DecodeMega2(Line, Pos + 4);
        DrawCircle(X1, Y1, R, Canvas.FG);
        Inc(Pos, 6);
      End;
      
      rcColor: If Pos + 1 <= Length(Line) Then Begin
        Canvas.FG := DecodeMega2(Line, Pos) And 15;
        Canvas.BG := 0;
        Inc(Pos, 2);
      End;
      
      rcFillStyle: If Pos + 3 <= Length(Line) Then Begin
        Canvas.FillStyle := DecodeMega2(Line, Pos);
        Canvas.FillColor := DecodeMega2(Line, Pos + 2) And 15;
        Inc(Pos, 4);
      End;
      
      rcEraseWindow: Begin
        FillChar(Canvas.Pixels^, SizeOf(TPixelBuffer), 0);
      End;
      
      rcResetWindows: Begin
        Canvas.ViewX1 := 0;
        Canvas.ViewY1 := 0;
        Canvas.ViewX2 := RIP_WIDTH - 1;
        Canvas.ViewY2 := RIP_HEIGHT - 1;
        Canvas.CurX := 0;
        Canvas.CurY := 0;
      End;
      
      rcHome: Begin
        Canvas.CurX := 0;
        Canvas.CurY := 0;
      End;
      
      rcGotoXY: If Pos + 3 <= Length(Line) Then Begin
        Canvas.CurX := DecodeMega2(Line, Pos);
        Canvas.CurY := DecodeMega2(Line, Pos + 2);
        Inc(Pos, 4);
      End;
      
      rcOnePalette: If Pos + 5 <= Length(Line) Then Begin
        C := DecodeMega2(Line, Pos);
        R := DecodeMega2(Line, Pos + 2);
        If (C >= 0) And (C <= 15) Then
          Canvas.Palette[C] := LongWord(R) * 256; { simplified }
        Inc(Pos, 6); { actually more params }
      End;
      
      { Text commands — ported from RIPtermJS ripterm.js }
      rcOutTextXY: If Pos + 3 <= Length(Line) Then Begin
        { !|@XXYY text — args format '22*': 2 mega coords + rest is text }
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        Inc(Pos, 4);
        { Rest of line is text (raw CP437 bytes) }
        OutTextXY(X1, Y1, Copy(Line, Pos, Length(Line) - Pos + 1));
        Pos := Length(Line) + 1; { consumed rest of line }
      End;
      
      rcOutText: Begin
        { !|T text — text at current cursor position }
        OutText(Copy(Line, Pos, Length(Line) - Pos + 1));
        Pos := Length(Line) + 1;
      End;
      
      rcFontStyle: If Pos + 7 <= Length(Line) Then Begin
        { !|Y FONT DIR SIZE RES — 4x 2-digit mega }
        X1 := DecodeMega2(Line, Pos);     { font }
        Y1 := DecodeMega2(Line, Pos + 2); { direction }
        X2 := DecodeMega2(Line, Pos + 4); { charsize }
        { Pos+6 = reserved, ignored }
        SetTextStyle(X1, Y1, X2);
        Inc(Pos, 8);
      End;
      
      { === Drawing commands ported from RIPtermJS === }
      
      rcOval: If Pos + 7 <= Length(Line) Then Begin
        { !|O CX CY XR YR — ellipse outline (mapped from stangle/endangle in JS) }
        X1 := DecodeMega2(Line, Pos);      { cx }
        Y1 := DecodeMega2(Line, Pos + 2);  { cy }
        X2 := DecodeMega2(Line, Pos + 4);  { x_rad }
        Y2 := DecodeMega2(Line, Pos + 6);  { y_rad }
        DrawEllipse(X1, Y1, X2, Y2, Canvas.FG);
        Inc(Pos, 8);
      End;
      
      rcFilledOval: If Pos + 7 <= Length(Line) Then Begin
        { !|o CX CY XR YR — filled ellipse }
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        X2 := DecodeMega2(Line, Pos + 4);
        Y2 := DecodeMega2(Line, Pos + 6);
        FillEllipse(X1, Y1, X2, Y2, Canvas.FillColor);
        DrawEllipse(X1, Y1, X2, Y2, Canvas.FG);
        Inc(Pos, 8);
      End;
      
      rcArc: If Pos + 9 <= Length(Line) Then Begin
        { !|A CX CY SA EA R — arc (5x 2-digit mega) }
        X1 := DecodeMega2(Line, Pos);      { cx }
        Y1 := DecodeMega2(Line, Pos + 2);  { cy }
        X2 := DecodeMega2(Line, Pos + 4);  { start_ang }
        Y2 := DecodeMega2(Line, Pos + 6);  { end_ang }
        R  := DecodeMega2(Line, Pos + 8);  { radius }
        { Arc uses aspect ratio — yradius adjusted like JS }
        DrawArcLines(X1, Y1, X2, Y2, R, R, Canvas.FG);
        Inc(Pos, 10);
      End;
      
      rcOvalArc: If Pos + 11 <= Length(Line) Then Begin
        { !|V CX CY SA EA XR YR — elliptical arc (6x 2-digit mega) }
        X1 := DecodeMega2(Line, Pos);       { cx }
        Y1 := DecodeMega2(Line, Pos + 2);   { cy }
        C  := DecodeMega2(Line, Pos + 4);   { start_ang }
        R  := DecodeMega2(Line, Pos + 6);   { end_ang }
        X2 := DecodeMega2(Line, Pos + 8);   { x_rad }
        Y2 := DecodeMega2(Line, Pos + 10);  { y_rad }
        DrawArcLines(X1, Y1, C, R, X2, Y2, Canvas.FG);
        Inc(Pos, 12);
      End;
      
      rcPieSlice: If Pos + 9 <= Length(Line) Then Begin
        { !|I CX CY SA EA R — pie slice }
        X1 := DecodeMega2(Line, Pos);      { cx }
        Y1 := DecodeMega2(Line, Pos + 2);  { cy }
        X2 := DecodeMega2(Line, Pos + 4);  { start_ang }
        Y2 := DecodeMega2(Line, Pos + 6);  { end_ang }
        R  := DecodeMega2(Line, Pos + 8);  { radius }
        DrawSector(X1, Y1, X2, Y2, R, R, Canvas.FG, Canvas.FillColor);
        Inc(Pos, 10);
      End;
      
      rcOvalPieSlice: If Pos + 11 <= Length(Line) Then Begin
        { !|i CX CY SA EA XR YR — oval pie }
        X1 := DecodeMega2(Line, Pos);       { cx }
        Y1 := DecodeMega2(Line, Pos + 2);   { cy }
        C  := DecodeMega2(Line, Pos + 4);   { start_ang }
        R  := DecodeMega2(Line, Pos + 6);   { end_ang }
        X2 := DecodeMega2(Line, Pos + 8);   { x_rad }
        Y2 := DecodeMega2(Line, Pos + 10);  { y_rad }
        DrawSector(X1, Y1, C, R, X2, Y2, Canvas.FG, Canvas.FillColor);
        Inc(Pos, 12);
      End;
      
      rcBezier: If Pos + 17 <= Length(Line) Then Begin
        { !|Z X0Y0 X1Y1 X2Y2 X3Y3 CNT — 9x 2-digit mega }
        BezPts[0] := DecodeMega2(Line, Pos);
        BezPts[1] := DecodeMega2(Line, Pos + 2);
        BezPts[2] := DecodeMega2(Line, Pos + 4);
        BezPts[3] := DecodeMega2(Line, Pos + 6);
        BezPts[4] := DecodeMega2(Line, Pos + 8);
        BezPts[5] := DecodeMega2(Line, Pos + 10);
        BezPts[6] := DecodeMega2(Line, Pos + 12);
        BezPts[7] := DecodeMega2(Line, Pos + 14);
        R := DecodeMega2(Line, Pos + 16);
        DrawBezier(R, BezPts, Canvas.FG);
        Inc(Pos, 18);
      End;
      
      rcPolygon: If Pos + 1 <= Length(Line) Then Begin
        { !|P NN X0Y0 X1Y1... — npoints then pairs }
        NPts := DecodeMega2(Line, Pos);
        Inc(Pos, 2);
        If (NPts >= 2) And (NPts <= 512) And (Pos + NPts * 4 - 1 <= Length(Line)) Then Begin
          For I := 0 to NPts - 1 Do Begin
            PolyPts[I * 2]     := DecodeMega2(Line, Pos + I * 4);
            PolyPts[I * 2 + 1] := DecodeMega2(Line, Pos + I * 4 + 2);
          End;
          { Draw outline }
          For I := 0 to NPts - 2 Do
            DrawLine(PolyPts[I*2], PolyPts[I*2+1], PolyPts[(I+1)*2], PolyPts[(I+1)*2+1], Canvas.FG);
          DrawLine(PolyPts[(NPts-1)*2], PolyPts[(NPts-1)*2+1], PolyPts[0], PolyPts[1], Canvas.FG);
          Inc(Pos, NPts * 4);
        End;
      End;
      
      rcFilledPolygon: If Pos + 1 <= Length(Line) Then Begin
        { !|p — filled polygon with scanline fill }
        NPts := DecodeMega2(Line, Pos);
        Inc(Pos, 2);
        If (NPts >= 2) And (NPts <= 512) And (Pos + NPts * 4 - 1 <= Length(Line)) Then Begin
          For I := 0 to NPts - 1 Do Begin
            PolyPts[I * 2]     := DecodeMega2(Line, Pos + I * 4);
            PolyPts[I * 2 + 1] := DecodeMega2(Line, Pos + I * 4 + 2);
          End;
          { Scanline fill }
          FillPolyScanline(NPts, PolyPts, Canvas.FillColor);
          { Outline }
          For I := 0 to NPts - 2 Do
            DrawLine(PolyPts[I*2], PolyPts[I*2+1], PolyPts[(I+1)*2], PolyPts[(I+1)*2+1], Canvas.FG);
          DrawLine(PolyPts[(NPts-1)*2], PolyPts[(NPts-1)*2+1], PolyPts[0], PolyPts[1], Canvas.FG);
          Inc(Pos, NPts * 4);
        End;
      End;
      
      rcPolyLine: If Pos + 1 <= Length(Line) Then Begin
        { !|l — polyline (no closing segment) }
        NPts := DecodeMega2(Line, Pos);
        Inc(Pos, 2);
        If (NPts >= 2) And (NPts <= 512) And (Pos + NPts * 4 - 1 <= Length(Line)) Then Begin
          For I := 0 to NPts - 1 Do Begin
            PolyPts[I * 2]     := DecodeMega2(Line, Pos + I * 4);
            PolyPts[I * 2 + 1] := DecodeMega2(Line, Pos + I * 4 + 2);
          End;
          For I := 0 to NPts - 2 Do
            DrawLine(PolyPts[I*2], PolyPts[I*2+1], PolyPts[(I+1)*2], PolyPts[(I+1)*2+1], Canvas.FG);
          Inc(Pos, NPts * 4);
        End;
      End;
      
      rcFill: If Pos + 5 <= Length(Line) Then Begin
        { !|F X Y BORDER — flood fill }
        X1 := DecodeMega2(Line, Pos);
        Y1 := DecodeMega2(Line, Pos + 2);
        C  := DecodeMega2(Line, Pos + 4) And 15;
        FloodFill(X1, Y1, C);
        Inc(Pos, 6);
      End;
      
      rcFillPattern: If Pos + 17 <= Length(Line) Then Begin
        { !|s C1..C8 COLOR — 9x 2-digit mega (user fill pattern) }
        { Store pattern bytes — TODO: use in fill operations }
        Canvas.FillColor := DecodeMega2(Line, Pos + 16) And 15;
        Canvas.FillStyle := 12; { USER_FILL }
        Inc(Pos, 18);
      End;
      
      rcLineStyle: If Pos + 7 <= Length(Line) Then Begin
        { !|= STYLE PATTERN THICK — fmt 242 }
        Canvas.LineStyle := DecodeMega2(Line, Pos);
        { skip 4-digit pattern }
        Canvas.LineThick := DecodeMega2(Line, Pos + 6);
        Inc(Pos, 8);
      End;
      
      rcWriteMode: If Pos + 1 <= Length(Line) Then Begin
        { !|W MODE — write mode (0=copy, 1=xor) }
        Canvas.WriteMode := DecodeMega2(Line, Pos);
        Inc(Pos, 2);
      End;
      
      rcEraseView: Begin
        { !|e — erase current viewport }
        For Y1 := Canvas.ViewY1 to Canvas.ViewY2 Do
          For X1 := Canvas.ViewX1 to Canvas.ViewX2 Do
            PutPixel(X1, Y1, 0);
      End;
      
      rcEraseEOL: Begin
        { !|> — erase to end of line (text cursor) }
        { Simplified: clear from CurX to right edge at CurY row }
        For X1 := Canvas.CurX to Canvas.ViewX2 Do
          For Y1 := Canvas.CurY to Canvas.CurY + 15 Do
            PutPixel(X1, Y1, 0);
      End;
      
      rcTextWindow: If Pos + 11 <= Length(Line) Then Begin
        { !|w X0 Y0 X1 Y1 WRAP SIZE — 4x2 + 2x1 digit mega }
        { Set text viewport — simplified }
        Inc(Pos, 12);
      End;
      
      rcViewPort: If Pos + 7 <= Length(Line) Then Begin
        { !|v X0 Y0 X1 Y1 — set graphics viewport }
        Canvas.ViewX1 := DecodeMega2(Line, Pos);
        Canvas.ViewY1 := DecodeMega2(Line, Pos + 2);
        Canvas.ViewX2 := DecodeMega2(Line, Pos + 4);
        Canvas.ViewY2 := DecodeMega2(Line, Pos + 6);
        Inc(Pos, 8);
      End;
      
      rcGetImage: If Pos + 9 <= Length(Line) Then Begin
        { !|1C X0 Y0 X1 Y1 RES — capture region (stub) }
        Inc(Pos, 10);
      End;
      
      rcPutImage: If Pos + 7 <= Length(Line) Then Begin
        { !|1P X Y MODE RES — paste region (stub) }
        Inc(Pos, 8);
      End;
      
      rcLoadIcon: If Pos + 9 <= Length(Line) Then Begin
        { !|1I X Y MODE CLIP RES FILENAME — load icon (stub, skip to EOL) }
        Pos := Length(Line) + 1;
      End;
      
      rcMouse: If Pos + 15 <= Length(Line) Then Begin
        { !|1M NUM X0 Y0 X1 Y1 CLK CLR RES TEXT — mouse region (stub, skip to EOL) }
        Pos := Length(Line) + 1;
      End;
      
      rcKillMouseFields: Begin
        { !|1K — kill mouse fields (no-op in viewer) }
      End;
      
      rcButton: If Pos + 13 <= Length(Line) Then Begin
        { !|1U X0 Y0 X1 Y1 HOTKEY FLAGS RES TEXT — button (stub, skip to EOL) }
        Pos := Length(Line) + 1;
      End;
      
      rcButtonStyle: If Pos + 27 <= Length(Line) Then Begin
        { !|1B 14x 2-digit mega — button style (stub) }
        Inc(Pos, 28);
      End;
      
      rcSetPalette: If Pos + 31 <= Length(Line) Then Begin
        { !|Q 16x 2-digit mega — set all 16 palette entries }
        For I := 0 to 15 Do Begin
          C := DecodeMega2(Line, Pos + I * 2);
          { C is EGA64 index — simplified: just store directly }
          Canvas.Palette[I] := EGA_PALETTE[C And 15];
        End;
        Inc(Pos, 32);
      End;
      
      rcNoMore: Begin
        { !|# — end of RIP, stop processing }
        Pos := Length(Line) + 1;
      End;
    Else
      { Skip unknown command — advance past parameters }
      Inc(Pos);
    End;
    
    { Debug: print command from original line }
    If DebugMode And (Cmd <> rcUnknown) Then Begin
      DbgStr := Copy(Line, CmdPos, Pos - CmdPos + 2);
      If Length(DbgStr) > 60 Then
        DbgStr := Copy(DbgStr, 1, 57) + '...';
      WriteLn('  ', DbgStr);
    End;
    
    { Baud emulation: delay based on bytes consumed }
    If (BaudDelay > 0) And (Cmd <> rcUnknown) Then Begin
      { Sleep for (bytes * BaudDelay) microseconds }
      { FPC Sleep is in milliseconds, minimum 1ms }
      I := (Pos - CmdPos) * BaudDelay Div 1000;
      If I > 0 Then Sleep(I);
    End;
  End;
End;

End.
