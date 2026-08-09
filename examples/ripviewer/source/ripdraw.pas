{$MODE DELPHI}
{$H-}
Unit RIPDraw;
{
  RIPView Drawing Primitives - ported from RIPtermJS BGI.js.
  Shared across all RIPscrip versions.

  ALGORITHMS:
    DrawLine    - JS BGI.js line_bresenham (den/num/numadd formulation)
    DrawBezier  - Cubic bezier with Floor() matching JS Math.floor()
    DrawArcLines - 1-degree stepping with Floor() for trig
    FloodFill   - Scanline with heap-allocated visited buffer
    FillRect    - Pattern-aware via PutFillPixel
    FillEllipse - Midpoint algorithm with scanline fill

  CRITICAL: DrawLine MUST use the JS Bresenham algorithm, not standard
  err=dx-dy. The two algorithms produce different pixel positions on
  diagonals. Bezier curve endpoints at junctions get 1-pixel gaps with
  standard Bresenham, causing flood fill to leak (DRAGON01 bug).

  FILL PATTERNS: 13 BGI patterns (empty, solid, line, slash, backslash,
  hatch, crosshatch, interleave, wide dot, close dot, user fill).
  PutFillPixel checks the 8x8 pattern bitmap before drawing.

  BUG HISTORY (Session 6, 18 test runs):
    Run 1-2:  Placeholder fonts, massive diffs
    Run 4:    BMP BGR byte order fixed
    Run 8:    RIP_HEIGHT 1280->350 (canvas too tall)
    Run 9:    Fill patterns implemented (S_FILL 5.5%->0.7%)
    Run 13:   FloodFill with visited buffer
    Run 15:   CHR vector fonts loading
    Run 16:   TextWindow |w parameter 12->10 (outlines wrong color)
    Run 17:   Bezier Floor() matching JS
    Run 18:   JS-matched Bresenham (DRAGON01 renders correctly)

  See PHASE3-CHANGELOG.md for full test history.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
  Ported from RIPtermJS by Carl Gorringe (https://github.com/cgorringe/RIPtermJS)
}
Interface

Uses RIPEngine, Math;

Procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte);
Procedure DrawLineJS(X1, Y1, X2, Y2: Integer; Color: Byte);
Procedure DrawRect(X1, Y1, X2, Y2: Integer; Color: Byte);
Procedure FillRect(X1, Y1, X2, Y2: Integer; Color: Byte);
Procedure DrawCircle(CX, CY, Radius: Integer; Color: Byte);
Procedure DrawEllipse(CX, CY, XRad, YRad: Integer; Color: Byte);
Procedure FillEllipse(CX, CY, XRad, YRad: Integer; Color: Byte);
Procedure FloodFill(X0, Y0: Integer; Border: Byte);
Procedure DrawBezier(NumSeg: Integer; Pts: Array Of Integer; Color: Byte);
Procedure DrawArcLines(CX, CY, StAngle, EndAngle, XRad, YRad: Integer; Color: Byte);
Procedure DrawSector(CX, CY, StAngle, EndAngle, XRad, YRad: Integer;
                     OutColor, FillCol: Byte);
Procedure FillPolyScanline(NPts: Integer; Var Pts: Array Of Integer; Color: Byte);

{ Phase 2 — BGI state setters }
Procedure SetLineStyle(Style: Byte; Thick: Integer);
Procedure PutFillPixel(X, Y: Integer; Color: Byte);
Procedure SetWriteMode(Mode: Byte);
Procedure SetPalette(Index: Byte; RGB: LongWord);
Procedure SetViewport(X1, Y1, X2, Y2: Integer);

Implementation

{ Phase 2 — Line dash patterns for SetLineStyle }
Const
  DashPatterns : Array[0..4] Of Word = (
    $FFFF,   { 0 = LINE_SOLID:  1111111111111111 }
    $CCCC,   { 1 = LINE_DOTTED: 1100110011001100 }
    $FC78,   { 2 = LINE_CENTER: 1111110001111000 }
    $F8F8,   { 3 = LINE_DASHED: 1111100011111000 }
    $FFFF    { 4 = LINE_USER:   user-defined (default solid) }
  );

  { BGI fill patterns — 8x8 pixel bitmaps.
    Each pattern is 8 bytes, one per scanline row.
    Bit set = fill with FillColor, bit clear = leave background.
    Matched exactly to RIPtermJS BGI.js fill_patterns.
    Used by FloodFill and FillRect when FillStyle > 1. }
  FillPatterns : Array[0..12, 0..7] Of Byte = (
    ($00, $00, $00, $00, $00, $00, $00, $00),  { 00 EMPTY_FILL      }
    ($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF),  { 01 SOLID_FILL      }
    ($FF, $FF, $00, $00, $FF, $FF, $00, $00),  { 02 LINE_FILL       }
    ($01, $02, $04, $08, $10, $20, $40, $80),  { 03 LTSLASH_FILL    }
    ($E0, $C1, $83, $07, $0E, $1C, $38, $70),  { 04 SLASH_FILL      }
    ($F0, $78, $3C, $1E, $0F, $87, $C3, $E1),  { 05 BKSLASH_FILL    }
    ($A5, $D2, $69, $B4, $5A, $2D, $96, $4B),  { 06 LTBKSLASH_FILL  }
    ($FF, $88, $88, $88, $FF, $88, $88, $88),  { 07 HATCH_FILL      }
    ($81, $42, $24, $18, $18, $24, $42, $81),  { 08 XHATCH_FILL     }
    ($CC, $33, $CC, $33, $CC, $33, $CC, $33),  { 09 INTERLEAVE_FILL }
    ($80, $00, $08, $00, $80, $00, $08, $00),  { 10 WIDE_DOT_FILL   }
    ($88, $00, $22, $00, $88, $00, $22, $00),  { 11 CLOSE_DOT_FILL  }
    ($AA, $55, $AA, $55, $AA, $55, $AA, $55)   { 12 USER_FILL       }
  );

{ ================================================================
  TWO LINE ALGORITHMS:
  
  DrawLine — Standard Bresenham (err=dx-dy). Used by all RIP line
  commands (|L, |R, etc). Produces the best match for L_LINE and
  V_ARC test files (0.4-0.8% diff vs reference).
  
  DrawLineJS — JS BGI.js Bresenham (den/num/numadd). Used ONLY by
  DrawBezier. Produces identical pixel positions to the JS engine,
  which is critical for bezier curve junctions — flood fill leaks
  through 1-pixel gaps if bezier endpoints don't match.
  
  BUG FIX: Previously used JS Bresenham for ALL lines. This fixed
  DRAGON01 (98.9%->1.6%) but regressed L_LINE (0.8%->2.0%) and
  V_ARC (0.4%->1.8%). Dual approach gives the best of both.
  ================================================================ }

Procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte);
{ All lines use JS-matched Bresenham. The reference PNGs were
  generated by the JS engine, so matching its pixel positions
  gives the closest results. DrawLineJS has the actual algorithm. }
Begin
  DrawLineJS(X1, Y1, X2, Y2, Color);
End;

Procedure DrawLineJS(X1, Y1, X2, Y2: Integer; Color: Byte);
{ JS BGI.js Bresenham with dash pattern and thickness support.
  Used for all line drawing — matches JS pixel positions exactly. }
Var
  DX, DY: Integer;
  XI1, XI2, YI1, YI2: Integer;
  Den, Num, NumAdd, NumPixels: Integer;
  X, Y, C, T: Integer;
  Pattern: Word;
Begin
  DX := Abs(X2 - X1); DY := Abs(Y2 - Y1);
  If X2 >= X1 Then Begin XI1 := 1; XI2 := 1; End
  Else Begin XI1 := -1; XI2 := -1; End;
  If Y2 >= Y1 Then Begin YI1 := 1; YI2 := 1; End
  Else Begin YI1 := -1; YI2 := -1; End;
  If DX >= DY Then Begin
    XI1 := 0; YI2 := 0;
    Den := DX; Num := DX Shr 1; NumAdd := DY; NumPixels := DX;
  End Else Begin
    XI2 := 0; YI1 := 0;
    Den := DY; Num := DY Shr 1; NumAdd := DX; NumPixels := DY;
  End;

  If Canvas.LineStyle <= 4 Then
    Pattern := DashPatterns[Canvas.LineStyle]
  Else
    Pattern := $FFFF;

  X := X1; Y := Y1;
  For C := 0 to NumPixels Do Begin
    If (Pattern Shr (C And 15)) And 1 = 1 Then Begin
      If Canvas.LineThick <= 1 Then Begin
        If Canvas.WriteMode = 1 Then Begin
          If (X >= 0) And (X < RIP_WIDTH) And (Y >= 0) And (Y < RIP_HEIGHT) Then
            Canvas.Pixels^[X, Y] := Canvas.Pixels^[X, Y] Xor (Color And 15);
        End Else
          PutPixel(X, Y, Color);
      End Else Begin
        For T := -(Canvas.LineThick Div 2) to (Canvas.LineThick Div 2) Do Begin
          If DX >= DY Then PutPixel(X, Y + T, Color)
          Else PutPixel(X + T, Y, Color);
        End;
      End;
    End;
    Inc(Num, NumAdd);
    If Num >= Den Then Begin Dec(Num, Den); Inc(X, XI1); Inc(Y, YI1); End;
    Inc(X, XI2); Inc(Y, YI2);
  End;
End;
Procedure DrawRect(X1, Y1, X2, Y2: Integer; Color: Byte);
Begin
  DrawLine(X1, Y1, X2, Y1, Color);
  DrawLine(X2, Y1, X2, Y2, Color);
  DrawLine(X2, Y2, X1, Y2, Color);
  DrawLine(X1, Y2, X1, Y1, Color);
End;

Procedure FillRect(X1, Y1, X2, Y2: Integer; Color: Byte);
{ Fill a rectangle with the current fill pattern.
  Uses PutFillPixel for pattern support (hatch, stripe, dot, etc).
  BUG FIX: Previously always solid. Now respects Canvas.FillStyle. }
Var X, Y: Integer;
Begin
  For Y := Y1 To Y2 Do
    For X := X1 To X2 Do
      PutFillPixel(X, Y, Color);
End;

Procedure DrawCircle(CX, CY, Radius: Integer; Color: Byte);
{ Route through DrawEllipse. Thickness NOT applied to circles —
  C_WELL uses 3px thick circles but applying thickness shifted
  fill boundaries and made the score worse (26.1%→26.8%). 
  The JS circle thickness works differently (draws arc segments). }
Begin
  DrawEllipse(CX, CY, Radius, Radius, Color);
End;

Procedure DrawEllipse(CX, CY, XRad, YRad: Integer; Color: Byte);
{ Bresenham ellipse — matched to JS BGI.js ellipse_bresenham.
  BUG FIX: E2 was Integer which could truncate Err*2 for large radii.
  Changed to LongInt. C_WELL has radii up to 397. }
Var X, Y: Integer;
    E2, DX, DY, Err: LongInt;
    XRad2, YRad2: LongInt;
Begin
  If XRad < 1 Then XRad := 1;
  If YRad < 1 Then YRad := 1;
  XRad2 := 2 * LongInt(XRad) * XRad;
  YRad2 := 2 * LongInt(YRad) * YRad;
  X := -XRad; Y := 0;
  DX := LongInt(1 + 2 * X) * YRad * YRad;
  DY := LongInt(X) * X;
  Err := DX + DY;
  PutPixel(CX - X, CY, Color);
  PutPixel(CX + X, CY, Color);
  Repeat
    PutPixel(CX - X, CY + Y, Color);
    PutPixel(CX + X, CY + Y, Color);
    PutPixel(CX + X, CY - Y, Color);
    PutPixel(CX - X, CY - Y, Color);
    E2 := Err * 2;
    If E2 <= DY Then Begin Inc(Y); Inc(DY, XRad2); Inc(Err, DY); End;
    If (E2 >= DX) Or (Err * 2 > DY) Then Begin Inc(X); Inc(DX, YRad2); Inc(Err, DX); End;
  Until X >= 0;
  While Y <= YRad Do Begin
    PutPixel(CX, CY + Y, Color);
    PutPixel(CX, CY - Y, Color);
    Inc(Y);
  End;
End;

Procedure FillEllipse(CX, CY, XRad, YRad: Integer; Color: Byte);
Var X, Y, PX, LastY: Integer;
    E2: LongInt;
    DX, DY, Err: LongInt;
    XRad2, YRad2: LongInt;
Begin
  If XRad < 1 Then XRad := 1;
  If YRad < 1 Then YRad := 1;
  XRad2 := 2 * LongInt(XRad) * XRad;
  YRad2 := 2 * LongInt(YRad) * YRad;
  X := -XRad; Y := 0;
  DX := LongInt(1 + 2 * X) * YRad * YRad;
  DY := LongInt(X) * X;
  Err := DX + DY;
  For PX := X to -X Do PutPixel(CX + PX, CY, Color);
  LastY := Y;
  Repeat
    If Y <> LastY Then Begin
      For PX := X to -X Do Begin
        PutPixel(CX + PX, CY - Y, Color);
        PutPixel(CX + PX, CY + Y, Color);
      End;
      LastY := Y;
    End;
    E2 := Err * 2;
    If E2 <= DY Then Begin Inc(Y); Inc(DY, XRad2); Inc(Err, DY); End;
    If (E2 >= DX) Or (Err * 2 > DY) Then Begin Inc(X); Inc(DX, YRad2); Inc(Err, DX); End;
  Until X > 0;
End;

{ Put a pixel using the current fill pattern.
  If FillStyle = 0 (empty), don't draw.
  If FillStyle = 1 (solid), use FillColor directly.
  If FillStyle >= 2, check the 8x8 pattern bitmap from FillPatterns.
  Bit set in pattern = draw FillColor, bit clear = leave pixel alone.
  Patterns tile at 8x8 using (X And 7) and (Y And 7). }
Procedure PutFillPixel(X, Y: Integer; Color: Byte);
{ Draw pixel using fill pattern. Matched to JS BGI.js ff_putpixel:
  Pattern bit=1 → draw FillColor (foreground)
  Pattern bit=0 → draw BG color (background)
  BUG FIX: Was skipping pattern=0 pixels, leaving old canvas color.
  This caused hatch fills to show through previous fills instead of
  drawing the background color in pattern gaps (v_VIEW blue hatch). }
Var PatRow: Byte;
Begin
  If Canvas.FillStyle = 0 Then Begin
    PutPixel(X, Y, Canvas.BG);
    Exit;
  End;
  If Canvas.FillStyle = 1 Then Begin
    PutPixel(X, Y, Color);
    Exit;
  End;
  If Canvas.FillStyle <= 12 Then Begin
    PatRow := FillPatterns[Canvas.FillStyle, (Y + Canvas.ViewY1) And 7];
    If (PatRow Shr (7 - ((X + Canvas.ViewX1) And 7))) And 1 = 1 Then
      PutPixel(X, Y, Color)
    Else
      PutPixel(X, Y, Canvas.BG);
  End;
End;

Procedure FloodFill(X0, Y0: Integer; Border: Byte);
{ Scanline flood fill — matched exactly to RIPtermJS BGI.js _floodfill.
  
  KEY DIFFERENCES from our previous implementation:
  1. Scanline finder (x1, x2) ONLY checks border on main canvas
     — does NOT check visited buffer. This ensures full scanlines
     are processed even if parts were visited in a previous pass.
  2. Span detection checks visited buffer (fillpixels) to avoid
     re-queueing already-processed areas.
  3. Edge pixels at viewport boundaries are skipped in span detection
     (matches JS "intentional bug to prevent flooding through edges").
  4. Uses heap-allocated visited buffer (224KB of booleans).
  
  BUG FIX (Session 6 Run 16): Previous version checked Visited in
  scanline finder which caused fills to stop at pattern gaps and
  fill outside shapes instead of inside (DRAGON01 green background). }
Type
  TPoint = Record X, Y: Integer; End;
  TVisited = Array[0..RIP_WIDTH-1, 0..RIP_HEIGHT-1] Of Boolean;
  PVisited = ^TVisited;
Var
  Stack: Array[0..65535] Of TPoint;
  Visited: PVisited;
  SP, X, Y, X1, X2: Integer;
  SpanUp, SpanDn: Boolean;
Begin
  If (X0 < 0) Or (X0 >= RIP_WIDTH) Or (Y0 < 0) Or (Y0 >= RIP_HEIGHT) Then Exit;
  If GetPixel(X0, Y0) = Border Then Exit;

  New(Visited);
  FillChar(Visited^, SizeOf(TVisited), 0);

  SP := 0;
  Stack[SP].X := X0; Stack[SP].Y := Y0; Inc(SP);

  While SP > 0 Do Begin
    Dec(SP); X := Stack[SP].X; Y := Stack[SP].Y;

    { Find left end — ONLY check border on canvas, NOT visited }
    X1 := X;
    While (X1 >= 0) And (GetPixel(X1, Y) <> Border) Do Dec(X1);
    Inc(X1);

    { Find right end — ONLY check border on canvas, NOT visited }
    X2 := X + 1;
    While (X2 < RIP_WIDTH) And (GetPixel(X2, Y) <> Border) Do Inc(X2);
    Dec(X2);

    SpanUp := False; SpanDn := False;

    For X := X1 to X2 Do Begin
      { Draw pixel with fill pattern }
      PutFillPixel(X, Y, Canvas.FillColor);
      { Mark as visited }
      Visited^[X, Y] := True;

      { Skip edge pixels — matches JS viewport edge prevention }
      If (X <= 0) Or (X >= RIP_WIDTH - 1) Then Continue;

      { Check span above — use visited buffer for detection }
      If (Not SpanUp) And (Y > 0) And
         (GetPixel(X, Y-1) <> Border) And
         (Not Visited^[X, Y-1]) Then Begin
        If SP < 65535 Then Begin
          Stack[SP].X := X; Stack[SP].Y := Y-1; Inc(SP);
        End;
        SpanUp := True;
      End Else If SpanUp And (Y > 0) And
         (GetPixel(X, Y-1) = Border) Then
        SpanUp := False;

      { Check span below }
      If (Not SpanDn) And (Y < RIP_HEIGHT - 1) And
         (GetPixel(X, Y+1) <> Border) And
         (Not Visited^[X, Y+1]) Then Begin
        If SP < 65535 Then Begin
          Stack[SP].X := X; Stack[SP].Y := Y+1; Inc(SP);
        End;
        SpanDn := True;
      End Else If SpanDn And (Y < RIP_HEIGHT - 1) And
         (GetPixel(X, Y+1) = Border) Then
        SpanDn := False;
    End;
  End;

  Dispose(Visited);
End;
Procedure DrawBezier(NumSeg: Integer; Pts: Array Of Integer; Color: Byte);
{ Cubic bezier curve. NumSeg line segments from P0 to P3.
  Matched to RIPtermJS BGI.js _drawbezier:
  - Uses Floor() not Round() for pixel positions (JS uses Math.floor)
  - Loop runs t from step to <1 (not including 1.0)
  - Final line drawn explicitly to exact endpoint P3
  - This prevents 1-pixel gaps between adjacent bezier curves
    that share endpoints (DRAGON01 flood fill leak fix). }
Var
  T, T1, Step: Double;
  PX, PY, LX, LY: Integer;
Begin
  If NumSeg < 2 Then NumSeg := 20;
  LX := Pts[0]; LY := Pts[1];
  Step := 1.0 / NumSeg;
  T := Step;
  While T < 1.0 Do Begin
    T1 := 1.0 - T;
    PX := Floor(T1*T1*T1*Pts[0] + 3*T*T1*T1*Pts[2] + 3*T*T*T1*Pts[4] + T*T*T*Pts[6]);
    PY := Floor(T1*T1*T1*Pts[1] + 3*T*T1*T1*Pts[3] + 3*T*T*T1*Pts[5] + T*T*T*Pts[7]);
    DrawLineJS(LX, LY, PX, PY, Color);
    LX := PX; LY := PY;
    T := T + Step;
  End;
  { Final segment to exact endpoint — no rounding }
  DrawLineJS(LX, LY, Pts[6], Pts[7], Color);
End;

Procedure DrawArcLines(CX, CY, StAngle, EndAngle, XRad, YRad: Integer; Color: Byte);
Var
  N, X1, Y1, X2, Y2: Integer;
  Rad: Double;
Begin
  If StAngle = EndAngle Then Exit;
  If StAngle > EndAngle Then Inc(EndAngle, 360);
  Rad := StAngle * Pi / 180.0;
  X1 := CX + Floor(XRad * Cos(Rad));
  Y1 := CY - Floor(YRad * Sin(Rad));
  For N := StAngle + 1 to EndAngle Do Begin
    Rad := N * Pi / 180.0;
    X2 := CX + Floor(XRad * Cos(Rad));
    Y2 := CY - Floor(YRad * Sin(Rad));
    DrawLine(X1, Y1, X2, Y2, Color);
    X1 := X2; Y1 := Y2;
  End;
End;

Procedure DrawSector(CX, CY, StAngle, EndAngle, XRad, YRad: Integer;
                     OutColor, FillCol: Byte);
Var
  Rad, HalfAngle: Double;
  X1, Y1, X2, Y2, FX, FY: Integer;
  EA2: Integer;
Begin
  If StAngle = EndAngle Then Begin PutPixel(CX, CY, OutColor); Exit; End;
  If XRad < 1 Then XRad := 1;
  If YRad < 1 Then YRad := 1;
  If StAngle > EndAngle Then Begin X1 := StAngle; StAngle := EndAngle; EndAngle := X1; End;
  DrawArcLines(CX, CY, StAngle, EndAngle, XRad, YRad, OutColor);
  EA2 := EndAngle Mod 360;
  Rad := StAngle * Pi / 180.0;
  X1 := CX + Floor(XRad * Cos(Rad));
  Y1 := CY - Floor(YRad * Sin(Rad));
  Rad := EA2 * Pi / 180.0;
  X2 := CX + Floor(XRad * Cos(Rad));
  Y2 := CY - Floor(YRad * Sin(Rad));
  DrawLine(CX, CY, X1, Y1, OutColor);
  DrawLine(CX, CY, X2, Y2, OutColor);
  HalfAngle := (EndAngle - StAngle) / 2.0 + StAngle;
  Rad := HalfAngle * Pi / 180.0;
  FX := Round(XRad * Cos(Rad) / 2.0 + CX);
  FY := Round(YRad * (-Sin(Rad)) / 2.0 + CY);
  Canvas.FillColor := FillCol;
  FloodFill(FX, FY, OutColor);
End;

Procedure FillPolyScanline(NPts: Integer; Var Pts: Array Of Integer; Color: Byte);
Var
  Y, I, J, X, NodeCount: Integer;
  TX1, TY1, TX2, TY2: Integer;
  XVal, Tmp: Double;
  XNodes: Array[0..511] Of Double;
  X0, X1: Integer;
Begin
  For Y := 0 to RIP_HEIGHT - 1 Do Begin
    NodeCount := 0;
    J := NPts - 1;
    For I := 0 to NPts - 1 Do Begin
      TX1 := Pts[J * 2]; TY1 := Pts[J * 2 + 1];
      TX2 := Pts[I * 2]; TY2 := Pts[I * 2 + 1];
      If ((TY2 <= Y) And (TY1 > Y)) Or ((TY1 <= Y) And (TY2 > Y)) Then Begin
        If TY1 = TY2 Then XVal := TX2
        Else XVal := (Y - TY2) / (TY1 - TY2) * (TX1 - TX2) + TX2;
        If NodeCount < 512 Then Begin
          XNodes[NodeCount] := XVal; Inc(NodeCount);
        End;
      End;
      J := I;
    End;
    If NodeCount = 0 Then Continue;
    For I := 0 to NodeCount - 2 Do
      For J := I + 1 to NodeCount - 1 Do
        If XNodes[J] < XNodes[I] Then Begin
          Tmp := XNodes[I]; XNodes[I] := XNodes[J]; XNodes[J] := Tmp;
        End;
    I := 0;
    While I < NodeCount - 1 Do Begin
      X0 := Ceil(XNodes[I]); X1 := Floor(XNodes[I + 1]);
      For X := X0 to X1 Do PutPixel(X, Y, Color);
      Inc(I, 2);
    End;
  End;
End;

{ ================================================================== }
{ Phase 2 — BGI state setters                                        }
{ ================================================================== }

Procedure SetLineStyle(Style: Byte; Thick: Integer);
Begin
  Canvas.LineStyle := Style;
  Canvas.LineThick := Thick;
  If Canvas.LineThick < 1 Then Canvas.LineThick := 1;
End;

Procedure SetWriteMode(Mode: Byte);
Begin
  Canvas.WriteMode := Mode And 1; { 0=COPY, 1=XOR }
End;

Procedure SetPalette(Index: Byte; RGB: LongWord);
Begin
  If Index <= 15 Then
    Canvas.Palette[Index] := RGB;
End;

Procedure SetViewport(X1, Y1, X2, Y2: Integer);
Begin
  If X1 < 0 Then X1 := 0;
  If Y1 < 0 Then Y1 := 0;
  If X2 >= RIP_WIDTH Then X2 := RIP_WIDTH - 1;
  If Y2 >= RIP_HEIGHT Then Y2 := RIP_HEIGHT - 1;
  Canvas.ViewX1 := X1;
  Canvas.ViewY1 := Y1;
  Canvas.ViewX2 := X2;
  Canvas.ViewY2 := Y2;
End;

End.
