{$MODE DELPHI}
{$H-}
Unit RIP_Compat;
{
  RIP Engine Compatibility Layer

  Maps ripdraw's global API to m_rip_graph's TRIPGraphics methods.
  rip1exec.pas accesses Canvas.FG, Canvas.FillColor etc as record
  fields — we expose G.Canvas directly and alias the field names.

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

{$IFDEF EXPERIMENTAL_RIP}
Uses m_rip_graph, RIPEngine, RIPBMP;

Const
  RIP_WIDTH  = 640;
  RIP_HEIGHT = 350;

  EGA_PALETTE : Array[0..15] Of LongWord = (
    $000000, $AA0000, $00AA00, $AAAA00,
    $0000AA, $AA00AA, $0055AA, $AAAAAA,
    $555555, $FF5555, $55FF55, $FFFF55,
    $5555FF, $FF55FF, $55FFFF, $FFFFFF
  );

Type
  TPixelBuffer = Array[0..RIP_WIDTH-1, 0..RIP_HEIGHT-1] Of Byte;

Type
  { Alias record that maps ripdraw field names to m_rip_graph field names }
  TCompatCanvas = Record
    FG         : Byte;    { maps to FGColor }
    BG         : Byte;    { maps to BGColor }
    FillColor  : Byte;
    FillStyle  : Byte;
    LineStyle  : Byte;
    LineThick  : Integer;
    WriteMode  : Byte;
    CurX, CurY : Integer;
    ViewX1, ViewY1, ViewX2, ViewY2 : Integer;
    Pixels     : Pointer;
    Palette    : Array[0..15] Of LongWord;
    FontNum    : Byte;
    FontDir    : Byte;
    FontSize   : Byte;
  End;

Var
  G      : TRIPGraphics;
  Canvas : TCompatCanvas;
  DebugMode : Boolean;
  BaudRate  : LongInt;
  BaudDelay : LongInt;

Procedure SyncToG;    { Canvas → G.Canvas before drawing }
Procedure SyncFromG;  { G.Canvas → Canvas after drawing }

Procedure InitCanvas;
Procedure PutPixel(X, Y: Integer; Color: Byte);
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
Procedure OutTextXY(X, Y: Integer; const Text: String);
Procedure OutText(const Text: String);
Procedure SetTextStyle(Font, Direction, CharSize: Integer);
Procedure WriteBMP(const FileName: String);

{$ENDIF}

Implementation

{$IFDEF EXPERIMENTAL_RIP}

Procedure SyncToG;
{ Push compat Canvas state into G.Canvas before any draw call }
Begin
  G.Canvas.FGColor   := Canvas.FG;
  G.Canvas.BGColor   := Canvas.BG;
  G.Canvas.FillColor := Canvas.FillColor;
  G.Canvas.FillStyle := Canvas.FillStyle;
  G.Canvas.LineStyle := Canvas.LineStyle;
  G.Canvas.LineThick := Canvas.LineThick;
  G.Canvas.WriteMode := Canvas.WriteMode;
  G.Canvas.CurX      := Canvas.CurX;
  G.Canvas.CurY      := Canvas.CurY;
  G.Canvas.ViewX1    := Canvas.ViewX1;
  G.Canvas.ViewY1    := Canvas.ViewY1;
  G.Canvas.ViewX2    := Canvas.ViewX2;
  G.Canvas.ViewY2    := Canvas.ViewY2;
  G.Canvas.FontNum   := Canvas.FontNum;
  G.Canvas.FontDir   := Canvas.FontDir;
  G.Canvas.FontSize  := Canvas.FontSize;
End;

Procedure SyncFromG;
{ Pull G.Canvas state back into compat Canvas after draw calls }
Begin
  Canvas.FG        := G.Canvas.FGColor;
  Canvas.BG        := G.Canvas.BGColor;
  Canvas.FillColor := G.Canvas.FillColor;
  Canvas.FillStyle := G.Canvas.FillStyle;
  Canvas.CurX      := G.Canvas.CurX;
  Canvas.CurY      := G.Canvas.CurY;
  Canvas.Pixels    := G.Canvas.Pixels;
End;

Procedure InitCanvas;
{ Create Engine B (m_rip_graph) and also init RIPEngine's global Canvas
  so ripbmp.WriteBMP can read from it when we sync before writing. }
Begin
  G := TRIPGraphics.Create(640, 350, rbBuffer);
  RIPEngine.InitCanvas;  { allocates RIPEngine.Canvas.Pixels }
  SyncFromG;
End;

Procedure PutPixel(X, Y: Integer; Color: Byte);
Begin SyncToG; G.PutPixel(X, Y, Color); End;

Procedure DrawLine(X1, Y1, X2, Y2: Integer; Color: Byte);
Begin SyncToG; G.SetColor(Color); G.Line(X1, Y1, X2, Y2); SyncFromG; End;

Procedure DrawRect(X1, Y1, X2, Y2: Integer; Color: Byte);
Begin SyncToG; G.SetColor(Color); G.Rectangle(X1, Y1, X2, Y2); SyncFromG; End;

Procedure FillRect(X1, Y1, X2, Y2: Integer; Color: Byte);
Begin SyncToG; G.Canvas.FillColor := Color; G.FilledRect(X1, Y1, X2, Y2); SyncFromG; End;

Procedure DrawCircle(CX, CY, Radius: Integer; Color: Byte);
Begin SyncToG; G.SetColor(Color); G.Circle(CX, CY, Radius); SyncFromG; End;

Procedure DrawEllipse(CX, CY, XRad, YRad: Integer; Color: Byte);
Begin SyncToG; G.SetColor(Color); G.Ellipse(CX, CY, XRad, YRad); SyncFromG; End;

Procedure FillEllipse(CX, CY, XRad, YRad: Integer; Color: Byte);
Begin SyncToG; G.Canvas.FillColor := Color; G.FilledEllipse(CX, CY, XRad, YRad); SyncFromG; End;

Procedure FloodFill(X0, Y0: Integer; Border: Byte);
Begin SyncToG; G.FloodFill(X0, Y0, Border); SyncFromG; End;

Procedure DrawBezier(NumSeg: Integer; Pts: Array Of Integer; Color: Byte);
Begin SyncToG; G.SetColor(Color); G.Bezier(NumSeg, Pts); SyncFromG; End;

Procedure DrawArcLines(CX, CY, StAngle, EndAngle, XRad, YRad: Integer; Color: Byte);
Begin SyncToG; G.SetColor(Color); G.Arc(CX, CY, StAngle, EndAngle, XRad, YRad); SyncFromG; End;

Procedure DrawSector(CX, CY, StAngle, EndAngle, XRad, YRad: Integer;
                     OutColor, FillCol: Byte);
Begin
  SyncToG;
  G.SetColor(OutColor);
  G.Canvas.FillColor := FillCol;
  G.PieSlice(CX, CY, StAngle, EndAngle, XRad, YRad);
  SyncFromG;
End;

Procedure FillPolyScanline(NPts: Integer; Var Pts: Array Of Integer; Color: Byte);
Begin SyncToG; G.Canvas.FillColor := Color; G.FilledPolygon(NPts, Pts); SyncFromG; End;

Procedure OutTextXY(X, Y: Integer; const Text: String);
Begin SyncToG; G.OutText(X, Y, Text); SyncFromG; End;

Procedure OutText(const Text: String);
Begin SyncToG; G.OutText(G.Canvas.CurX, G.Canvas.CurY, Text); SyncFromG; End;

Procedure SetTextStyle(Font, Direction, CharSize: Integer);
Begin G.SetFont(Font, Direction, CharSize); SyncFromG; End;

Procedure WriteBMP(const FileName: String);
{ Use ripbmp's writer (supports BMP_8BIT) instead of m_rip_graph's SaveBMP.
  Copy G's pixel data and palette into RIPEngine's global Canvas,
  then call RIPBMP.WriteBMP which reads from RIPEngine.Canvas.
  This ensures both engines output the same BMP format. }
Begin
  SyncFromG;
  { Copy pixel data from G's buffer into RIPEngine's buffer }
  Move(G.Canvas.Pixels^, RIPEngine.Canvas.Pixels^, SizeOf(TPixelBuffer));
  { Copy palette }
  Move(G.Canvas.Palette, RIPEngine.Canvas.Palette, SizeOf(RIPEngine.Canvas.Palette));
  RIPBMP.WriteBMP(FileName);
End;

{$ENDIF}

End.
