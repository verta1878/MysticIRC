{$MODE DELPHI}
{$H-}
Unit RIPText;
{
  RIPView Text Rendering — VGA 8x16 CP437 font.
  Ported from RIPtermJS BGI.js drawPNGChar().
  Shared across all RIPscrip versions.

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses RIPEngine, RIPDraw;

Procedure DrawBitmapChar(Value: Byte; X0, Y0: Integer);
Procedure OutTextXY(X, Y: Integer; const Text: String);
Procedure OutText(const Text: String);
Procedure SetTextStyle(Font, Direction, CharSize: Integer);

Implementation

{ VGA 8x16 CP437 font ROM data }
{$I rip_font8x16.inc}

Procedure DrawBitmapChar(Value: Byte; X0, Y0: Integer);
Var
  Scale, XSize, YSize: Integer;
  ScanLine: Byte;
  X, Y, X1, Y1: Integer;
Begin
  Scale := Canvas.FontSize;
  If Scale < 1 Then Scale := 1;
  XSize := 8;
  YSize := 16;

  For Y := 0 to YSize - 1 Do Begin
    ScanLine := VGAFont[Value * 16 + Y];
    For X := 0 to XSize - 1 Do Begin
      { MSB first — bit 7 is leftmost pixel (standard VGA font) }
      If (ScanLine And $80) <> 0 Then Begin
        If Scale > 1 Then Begin
          If Canvas.FontDir = 0 Then Begin
            X1 := X0 + (X * Scale);
            Y1 := Y0 + (Y * Scale);
          End Else Begin
            X1 := X0 + (Y * Scale);
            Y1 := Y0 - (X * Scale);
          End;
          FillRect(X1, Y1, X1 + Scale - 1, Y1 + Scale - 1, Canvas.FG);
        End Else Begin
          If Canvas.FontDir = 0 Then
            PutPixel(X0 + X, Y0 + Y, Canvas.FG)
          Else
            PutPixel(X0 + Y, Y0 - X, Canvas.FG);
        End;
      End;
      ScanLine := ScanLine Shl 1;
    End;
  End;

  If Canvas.FontDir = 0 Then
    Canvas.CurX := X0 + (XSize * Scale)
  Else
    Canvas.CurY := Y0 - (XSize * Scale);
End;

Procedure OutTextXY(X, Y: Integer; const Text: String);
Var I: Integer;
Begin
  Canvas.CurX := X;
  Canvas.CurY := Y;
  For I := 1 to Length(Text) Do
    DrawBitmapChar(Ord(Text[I]), Canvas.CurX, Canvas.CurY);
End;

Procedure OutText(const Text: String);
Begin
  OutTextXY(Canvas.CurX, Canvas.CurY, Text);
End;

Procedure SetTextStyle(Font, Direction, CharSize: Integer);
Begin
  Canvas.FontNum := Font And 255;
  Canvas.FontDir := Direction And 1;
  Canvas.FontSize := CharSize;
  If Canvas.FontSize < 1 Then Canvas.FontSize := 1;
End;

End.
