{$MODE DELPHI}
{$H-}
Unit RIPWidgets;
{
  RIPscrip UI Widget Drawing Functions
  Ported from BGI_WRAP.C via ripscr.pas and mripui.pas.

  These are viewer-side UI drawing helpers, not RIP protocol commands.
  Used by button renderer, dialog boxes, and interactive UI.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}
Interface

Uses RIPEngine, RIPDraw;

{ 3D box styles }
Procedure DrawRaisedBox(X0, Y0, X1, Y1: Integer; Surface, Bright, Dark: Byte);
Procedure DrawSunkenBox(X0, Y0, X1, Y1: Integer; Surface, Bright, Dark: Byte);
Procedure DrawRoundedRect(X0, Y0, X1, Y1, Radius: Integer; Color: Byte);

{ Line helpers }
Procedure HLine(X0, X1, Y: Integer; Color: Byte);
Procedure VLine(X, Y0, Y1: Integer; Color: Byte);
Procedure DrawDashedLine(X0, Y0, X1, Y1: Integer; Color: Byte; DashLen: Integer);
Procedure DrawDottedRect(X0, Y0, X1, Y1: Integer; Color: Byte);

{ Text helpers }
Procedure DrawTextCentered(X0, Y0, X1, Y1: Integer; Const S: String; Color: Byte);

{ Form controls }
Procedure DrawCheckbox(X, Y, Size: Integer; Checked: Boolean; FG, BG: Byte);
Procedure DrawRadioButton(X, Y, Size: Integer; Selected: Boolean; FG, BG: Byte);

{ Panels and separators }
Procedure DrawPanelRaised(X0, Y0, X1, Y1: Integer; Bright, Dark: Byte);
Procedure DrawPanelSunken(X0, Y0, X1, Y1: Integer; Bright, Dark: Byte);
Procedure DrawSeparatorH(X0, X1, Y: Integer; Bright, Dark: Byte);
Procedure DrawSeparatorV(X, Y0, Y1: Integer; Bright, Dark: Byte);

{ Scrollbars }
Procedure DrawScrollbarH(X0, Y, X1, Pos, Size: Integer; BG, FG: Byte);
Procedure DrawScrollbarV(X, Y0, Y1, Pos, Size: Integer; BG, FG: Byte);

{ Complex widgets }
Procedure DrawTab(X0, Y0, W, H: Integer; Active: Boolean; FG, BG: Byte);
Procedure DrawTooltip(X, Y: Integer; Const S: String; FG, BG: Byte);

Implementation

Uses RIPText;

{ ---- Optimized horizontal/vertical lines ---- }

Procedure HLine(X0, X1, Y: Integer; Color: Byte);
Var X: Integer;
Begin
  If (Y < Canvas.ViewY1) Or (Y > Canvas.ViewY2) Then Exit;
  If X0 > X1 Then Begin X := X0; X0 := X1; X1 := X; End;
  If X0 < Canvas.ViewX1 Then X0 := Canvas.ViewX1;
  If X1 > Canvas.ViewX2 Then X1 := Canvas.ViewX2;
  For X := X0 To X1 Do
    Canvas.Pixels^[X, Y] := Color;
End;

Procedure VLine(X, Y0, Y1: Integer; Color: Byte);
Var Y: Integer;
Begin
  If (X < Canvas.ViewX1) Or (X > Canvas.ViewX2) Then Exit;
  If Y0 > Y1 Then Begin Y := Y0; Y0 := Y1; Y1 := Y; End;
  If Y0 < Canvas.ViewY1 Then Y0 := Canvas.ViewY1;
  If Y1 > Canvas.ViewY2 Then Y1 := Canvas.ViewY2;
  For Y := Y0 To Y1 Do
    Canvas.Pixels^[X, Y] := Color;
End;

{ ---- 3D box styles ---- }

Procedure DrawRaisedBox(X0, Y0, X1, Y1: Integer; Surface, Bright, Dark: Byte);
Begin
  FillRect(X0, Y0, X1, Y1, Surface);
  HLine(X0, X1, Y0, Bright);
  VLine(X0, Y0, Y1, Bright);
  HLine(X0, X1, Y1, Dark);
  VLine(X1, Y0, Y1, Dark);
End;

Procedure DrawSunkenBox(X0, Y0, X1, Y1: Integer; Surface, Bright, Dark: Byte);
Begin
  FillRect(X0, Y0, X1, Y1, Surface);
  HLine(X0, X1, Y0, Dark);
  VLine(X0, Y0, Y1, Dark);
  HLine(X0, X1, Y1, Bright);
  VLine(X1, Y0, Y1, Bright);
End;

Procedure DrawRoundedRect(X0, Y0, X1, Y1, Radius: Integer; Color: Byte);
Begin
  { Horizontal edges (inset by radius) }
  DrawLine(X0 + Radius, Y0, X1 - Radius, Y0, Color);
  DrawLine(X0 + Radius, Y1, X1 - Radius, Y1, Color);
  { Vertical edges (inset by radius) }
  DrawLine(X0, Y0 + Radius, X0, Y1 - Radius, Color);
  DrawLine(X1, Y0 + Radius, X1, Y1 - Radius, Color);
  { Corner arcs (quarter circles) }
  DrawArcLines(X0 + Radius, Y0 + Radius, 90, 180, Radius, Radius, Color);
  DrawArcLines(X1 - Radius, Y0 + Radius, 0, 90, Radius, Radius, Color);
  DrawArcLines(X0 + Radius, Y1 - Radius, 180, 270, Radius, Radius, Color);
  DrawArcLines(X1 - Radius, Y1 - Radius, 270, 360, Radius, Radius, Color);
End;

{ ---- Line helpers ---- }

Procedure DrawDashedLine(X0, Y0, X1, Y1: Integer; Color: Byte; DashLen: Integer);
Var DX, DY, Steps, I: Integer; FX, FY, StepX, StepY: Double; Draw: Boolean;
Begin
  DX := X1 - X0; DY := Y1 - Y0;
  If Abs(DX) > Abs(DY) Then Steps := Abs(DX) Else Steps := Abs(DY);
  If Steps = 0 Then Begin PutPixel(X0, Y0, Color); Exit; End;
  StepX := DX / Steps; StepY := DY / Steps;
  FX := X0; FY := Y0;
  For I := 0 To Steps Do Begin
    Draw := ((I Div DashLen) Mod 2) = 0;
    If Draw Then PutPixel(Round(FX), Round(FY), Color);
    FX := FX + StepX; FY := FY + StepY;
  End;
End;

Procedure DrawDottedRect(X0, Y0, X1, Y1: Integer; Color: Byte);
Begin
  DrawDashedLine(X0, Y0, X1, Y0, Color, 2);
  DrawDashedLine(X1, Y0, X1, Y1, Color, 2);
  DrawDashedLine(X0, Y1, X1, Y1, Color, 2);
  DrawDashedLine(X0, Y0, X0, Y1, Color, 2);
End;

{ ---- Text helper ---- }

Procedure DrawTextCentered(X0, Y0, X1, Y1: Integer; Const S: String; Color: Byte);
Var TX, TY: Integer;
Begin
  TX := X0 + ((X1 - X0 - TextWidth(S)) Div 2);
  TY := Y0 + ((Y1 - Y0 - TextHeight) Div 2);
  OutTextXY(TX, TY, S);
End;

{ ---- Form controls ---- }

Procedure DrawCheckbox(X, Y, Size: Integer; Checked: Boolean; FG, BG: Byte);
Begin
  DrawSunkenBox(X, Y, X + Size, Y + Size, BG, 8, 15);
  If Checked Then Begin
    DrawLine(X + 2, Y + Size Div 2, X + Size Div 2, Y + Size - 2, FG);
    DrawLine(X + Size Div 2, Y + Size - 2, X + Size - 2, Y + 2, FG);
  End;
End;

Procedure DrawRadioButton(X, Y, Size: Integer; Selected: Boolean; FG, BG: Byte);
Var R: Integer;
Begin
  R := Size Div 2;
  DrawCircle(X + R, Y + R, R, 8);
  If Selected Then
    FillEllipse(X + R, Y + R, R - 3, R - 3, FG);
End;

{ ---- Panels and separators ---- }

Procedure DrawPanelRaised(X0, Y0, X1, Y1: Integer; Bright, Dark: Byte);
Begin
  HLine(X0, X1, Y0, Bright);
  VLine(X0, Y0, Y1, Bright);
  HLine(X0, X1, Y1, Dark);
  VLine(X1, Y0, Y1, Dark);
End;

Procedure DrawPanelSunken(X0, Y0, X1, Y1: Integer; Bright, Dark: Byte);
Begin
  HLine(X0, X1, Y0, Dark);
  VLine(X0, Y0, Y1, Dark);
  HLine(X0, X1, Y1, Bright);
  VLine(X1, Y0, Y1, Bright);
End;

Procedure DrawSeparatorH(X0, X1, Y: Integer; Bright, Dark: Byte);
Begin
  HLine(X0, X1, Y, Dark);
  HLine(X0, X1, Y + 1, Bright);
End;

Procedure DrawSeparatorV(X, Y0, Y1: Integer; Bright, Dark: Byte);
Begin
  VLine(X, Y0, Y1, Dark);
  VLine(X + 1, Y0, Y1, Bright);
End;

{ ---- Scrollbars ---- }

Procedure DrawScrollbarH(X0, Y, X1, Pos, Size: Integer; BG, FG: Byte);
Var ThumbX: Integer;
Begin
  DrawSunkenBox(X0, Y, X1, Y + 14, BG, 8, 15);
  ThumbX := X0 + 1 + Pos;
  If ThumbX + Size > X1 - 1 Then ThumbX := X1 - 1 - Size;
  DrawRaisedBox(ThumbX, Y + 1, ThumbX + Size, Y + 13, 7, 15, 8);
End;

Procedure DrawScrollbarV(X, Y0, Y1, Pos, Size: Integer; BG, FG: Byte);
Var ThumbY: Integer;
Begin
  DrawSunkenBox(X, Y0, X + 14, Y1, BG, 8, 15);
  ThumbY := Y0 + 1 + Pos;
  If ThumbY + Size > Y1 - 1 Then ThumbY := Y1 - 1 - Size;
  DrawRaisedBox(X + 1, ThumbY, X + 13, ThumbY + Size, 7, 15, 8);
End;

{ ---- Complex widgets ---- }

Procedure DrawTab(X0, Y0, W, H: Integer; Active: Boolean; FG, BG: Byte);
Begin
  If Active Then Begin
    FillRect(X0, Y0, X0 + W, Y0 + H, BG);
    HLine(X0, X0 + W, Y0, 15);
    VLine(X0, Y0, Y0 + H, 15);
    VLine(X0 + W, Y0, Y0 + H, 8);
  End Else Begin
    FillRect(X0, Y0 + 2, X0 + W, Y0 + H, 7);
    HLine(X0, X0 + W, Y0 + 2, 15);
    VLine(X0, Y0 + 2, Y0 + H, 15);
    VLine(X0 + W, Y0 + 2, Y0 + H, 8);
  End;
End;

Procedure DrawTooltip(X, Y: Integer; Const S: String; FG, BG: Byte);
Var W, H: Integer;
Begin
  W := TextWidth(S) + 6;
  H := TextHeight + 4;
  FillRect(X, Y, X + W, Y + H, BG);
  DrawRect(X, Y, X + W, Y + H, 0);
  OutTextXY(X + 3, Y + 2, S);
End;

End.
