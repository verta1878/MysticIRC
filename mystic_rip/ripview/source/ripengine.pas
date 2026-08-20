{$MODE DELPHI}
{$H-}
Unit RIPEngine;
{
  RIPView Engine — Canvas, palette, pixels, global state.
  Shared across all RIPscrip versions.

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Const
  VERSION    = '1.0.0';
  RIP_WIDTH  = 640;
  RIP_HEIGHT = 1280;

  { CGA/ANSI palette order — matches SGR color indices from chg2rip }
  EGA_PALETTE : Array[0..15] Of LongWord = (
    $000000, $AA0000, $00AA00, $AA5500,
    $0000AA, $AA00AA, $00AAAA, $AAAAAA,
    $555555, $FF5555, $55FF55, $FFFF55,
    $5555FF, $FF55FF, $55FFFF, $FFFFFF
  );

Type
  TPixelBuffer = Array[0..RIP_WIDTH-1, 0..RIP_HEIGHT-1] Of Byte;

  TBGICanvas = Record
    Pixels     : ^TPixelBuffer;
    FG         : Byte;
    BG         : Byte;
    FillColor  : Byte;
    FillStyle  : Byte;
    LineStyle  : Byte;
    LineThick  : Integer;
    WriteMode  : Byte;
    CurX, CurY: Integer;
    ViewX1, ViewY1, ViewX2, ViewY2: Integer;
    Palette    : Array[0..15] Of LongWord;
    FontNum    : Byte;
    FontDir    : Byte;
    FontSize   : Byte;
  End;

Var
  Canvas    : TBGICanvas;
  DebugMode : Boolean = False;
  BaudRate  : LongInt = 0;
  BaudDelay : LongInt = 0;

Procedure InitCanvas;
Procedure PutPixel(X, Y: Integer; Color: Byte);

Implementation

Procedure InitCanvas;
Begin
  New(Canvas.Pixels);
  FillChar(Canvas.Pixels^, SizeOf(TPixelBuffer), 0);
  Canvas.FG := 15;
  Canvas.BG := 0;
  Canvas.FillColor := 0;
  Canvas.FillStyle := 1;
  Canvas.LineStyle := 0;
  Canvas.LineThick := 1;
  Canvas.WriteMode := 0;
  Canvas.CurX := 0;
  Canvas.CurY := 0;
  Canvas.ViewX1 := 0;
  Canvas.ViewY1 := 0;
  Canvas.ViewX2 := RIP_WIDTH - 1;
  Canvas.ViewY2 := RIP_HEIGHT - 1;
  Canvas.FontNum := 0;
  Canvas.FontDir := 0;
  Canvas.FontSize := 1;
  Move(EGA_PALETTE, Canvas.Palette, SizeOf(EGA_PALETTE));
End;

Procedure PutPixel(X, Y: Integer; Color: Byte);
Begin
  If (X >= 0) And (X < RIP_WIDTH) And (Y >= 0) And (Y < RIP_HEIGHT) Then
    Canvas.Pixels^[X, Y] := Color And 15;
End;

End.
