{$MODE DELPHI}
{$H-}
Unit RIPDraw;
{
  RIPView Drawing Primitives — ported from RIPtermJS BGI.js.
  Shared across all RIPscrip versions.

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses RIPEngine, Math;

Procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte);
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

Implementation

Procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte);
Var DX, DY, SX, SY, Err, E2: Integer;
Begin
  DX := Abs(X2 - X1); DY := Abs(Y2 - Y1);
  If X1 < X2 Then SX := 1 Else SX := -1;
  If Y1 < Y2 Then SY := 1 Else SY := -1;
  Err := DX - DY;
  While True Do Begin
    PutPixel(X1, Y1, Color);
    If (X1 = X2) And (Y1 = Y2) Then Break;
    E2 := 2 * Err;
    If E2 > -DY Then Begin Dec(Err, DY); Inc(X1, SX); End;
    If E2 < DX Then Begin Inc(Err, DX); Inc(Y1, SY); End;
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
Var X, Y: Integer;
Begin
  For Y := Y1 To Y2 Do
    For X := X1 To X2 Do
      PutPixel(X, Y, Color);
End;

Procedure DrawCircle(CX, CY, Radius: Integer; Color: Byte);
Var X, Y, D: Integer;
Begin
  X := 0; Y := Radius; D := 3 - 2 * Radius;
  While X <= Y Do Begin
    PutPixel(CX+X, CY+Y, Color); PutPixel(CX-X, CY+Y, Color);
    PutPixel(CX+X, CY-Y, Color); PutPixel(CX-X, CY-Y, Color);
    PutPixel(CX+Y, CY+X, Color); PutPixel(CX-Y, CY+X, Color);
    PutPixel(CX+Y, CY-X, Color); PutPixel(CX-Y, CY-X, Color);
    If D < 0 Then D := D + 4 * X + 6
    Else Begin D := D + 4 * (X - Y) + 10; Dec(Y); End;
    Inc(X);
  End;
End;

Procedure DrawEllipse(CX, CY, XRad, YRad: Integer; Color: Byte);
Var X, Y, E2: Integer;
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
  PutPixel(CX - X, CY, Color);
  PutPixel(CX + X, CY, Color);
  Repeat
    PutPixel(CX - X, CY + Y, Color);
    PutPixel(CX + X, CY + Y, Color);
    PutPixel(CX + X, CY - Y, Color);
    PutPixel(CX - X, CY - Y, Color);
    E2 := Integer(Err * 2);
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
Var X, Y, PX, E2, LastY: Integer;
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
    E2 := Integer(Err * 2);
    If E2 <= DY Then Begin Inc(Y); Inc(DY, XRad2); Inc(Err, DY); End;
    If (E2 >= DX) Or (Err * 2 > DY) Then Begin Inc(X); Inc(DX, YRad2); Inc(Err, DX); End;
  Until X > 0;
End;

Procedure FloodFill(X0, Y0: Integer; Border: Byte);
Type
  TPoint = Record X, Y: Integer; End;
Var
  Stack: Array[0..65535] Of TPoint;
  SP, X, Y, X1, X2: Integer;
  SpanUp, SpanDn: Boolean;
Begin
  If (X0 < 0) Or (X0 >= RIP_WIDTH) Or (Y0 < 0) Or (Y0 >= RIP_HEIGHT) Then Exit;
  If Canvas.Pixels^[X0, Y0] = Border Then Exit;
  SP := 0;
  Stack[SP].X := X0; Stack[SP].Y := Y0; Inc(SP);
  While SP > 0 Do Begin
    Dec(SP); X := Stack[SP].X; Y := Stack[SP].Y;
    X1 := X;
    While (X1 >= 0) And (Canvas.Pixels^[X1, Y] <> Border) Do Dec(X1);
    Inc(X1);
    X2 := X + 1;
    While (X2 < RIP_WIDTH) And (Canvas.Pixels^[X2, Y] <> Border) Do Inc(X2);
    Dec(X2);
    SpanUp := False; SpanDn := False;
    For X := X1 to X2 Do Begin
      PutPixel(X, Y, Canvas.FillColor);
      If (Y > 0) Then Begin
        If (Canvas.Pixels^[X, Y-1] <> Border) And (Canvas.Pixels^[X, Y-1] <> Canvas.FillColor) Then Begin
          If Not SpanUp Then Begin
            If SP < 65535 Then Begin Stack[SP].X := X; Stack[SP].Y := Y-1; Inc(SP); End;
            SpanUp := True;
          End;
        End Else SpanUp := False;
      End;
      If (Y < RIP_HEIGHT - 1) Then Begin
        If (Canvas.Pixels^[X, Y+1] <> Border) And (Canvas.Pixels^[X, Y+1] <> Canvas.FillColor) Then Begin
          If Not SpanDn Then Begin
            If SP < 65535 Then Begin Stack[SP].X := X; Stack[SP].Y := Y+1; Inc(SP); End;
            SpanDn := True;
          End;
        End Else SpanDn := False;
      End;
    End;
  End;
End;

Procedure DrawBezier(NumSeg: Integer; Pts: Array Of Integer; Color: Byte);
Var
  I: Integer;
  T, T2, T3, MT, MT2, MT3: Double;
  PX, PY, LX, LY: Integer;
Begin
  If NumSeg < 2 Then NumSeg := 20;
  LX := Pts[0]; LY := Pts[1];
  For I := 1 to NumSeg Do Begin
    T := I / NumSeg; MT := 1.0 - T;
    T2 := T * T; T3 := T2 * T;
    MT2 := MT * MT; MT3 := MT2 * MT;
    PX := Round(MT3*Pts[0] + 3*T*MT2*Pts[2] + 3*T2*MT*Pts[4] + T3*Pts[6]);
    PY := Round(MT3*Pts[1] + 3*T*MT2*Pts[3] + 3*T2*MT*Pts[5] + T3*Pts[7]);
    DrawLine(LX, LY, PX, PY, Color);
    LX := PX; LY := PY;
  End;
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

End.
