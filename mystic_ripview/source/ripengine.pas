{$MODE DELPHI}
{$H-}
Unit RIPEngine;
{
  RIPView Engine - Canvas, palette, pixels, global state.
  Shared across all RIPscrip versions.

  This is the core state for evga's rendering engine. Every drawing
  primitive reads from and writes to the global Canvas record. The
  pixel buffer is a 2D array indexed by [X, Y] with 4-bit color
  indices (0-15) mapped through the EGA palette.

  CANVAS DIMENSIONS:
    RIP v1.54 uses EGA 640x350 (mode 10h). The canvas MUST be 640x350.
    DO NOT change RIP_HEIGHT to anything other than 350 for v1.54.

    BUG HISTORY (Session 6, Test Run 8):
      RIP_HEIGHT was set to 1280. This made the BMP output 640x1280
      instead of 640x350. When compared against 640x350 reference PNGs,
      98.9% of pixels were "wrong" because rows 350-1279 (all black)
      existed in our output but not in the reference. The dragon in
      DRAGON01 was actually rendering correctly in rows 0-349 but the
      file was 3.66x too tall. Every test file was affected.
      Visual diff images from sysop/0 made this immediately obvious.

  PALETTE FORMAT:
    Stored as $BBGGRR LongWords (Blue in high byte, Red in low byte).
    This is NOT standard RGB - it's reversed for BMP compatibility.
    EGA palette index 1 (Blue)  = $AA0000 (BB=$AA, GG=$00, RR=$00)
    EGA palette index 4 (Red)   = $0000AA (BB=$00, GG=$00, RR=$AA)
    The 8-bit BMP writer extracts: Shr 16 = Blue, Shr 8 = Green, And $FF = Red.

  PUTPIXEL:
    Foundation of all drawing. Clips to viewport bounds (ViewX1..ViewX2,
    ViewY1..ViewY2). All primitives in ripdraw.pas ultimately call this.
    Color is masked to 4 bits (And 15) to prevent buffer overflow.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
  RIPscrip engine ported from RIPtermJS by Carl Gorringe
}

Interface

Const
  VERSION    = '1.0.0';

  { Canvas dimensions - EGA 640x350 for RIP v1.54.
    DO NOT change to 1280 or any other value.
    See BUG HISTORY above for what happens when this is wrong. }
  RIP_WIDTH  = 640;
  RIP_HEIGHT = 350;

  { EGA 16-color palette in $BBGGRR format.
    VERIFIED against RIPtermJS BGI.js ega_palette (RGBA format).
    JS: [R, G, B, A] -> our $BBGGRR = (B shl 16) or (G shl 8) or R.

    BUG FIX (Session 6 Run 18): Indices 3(cyan) and 6(brown) were
    swapped. Index 9-14 had wrong values. Entire palette rebuilt
    from JS RGBA values.

    Index 0 = Black, 1 = Blue, 2 = Green, 3 = Cyan,
    4 = Red, 5 = Magenta, 6 = Brown, 7 = Light Gray,
    8 = Dark Gray, 9 = Light Blue, 10 = Light Green, 11 = Light Cyan,
    12 = Light Red, 13 = Light Magenta, 14 = Yellow, 15 = White. }
  EGA_PALETTE : Array[0..15] Of LongWord = (
    $000000,   {  0 Black:         R=00  G=00  B=00  }
    $AA0000,   {  1 Blue:          R=00  G=00  B=AA  }
    $00AA00,   {  2 Green:         R=00  G=AA  B=00  }
    $AAAA00,   {  3 Cyan:          R=00  G=AA  B=AA  }
    $0000AA,   {  4 Red:           R=AA  G=00  B=00  }
    $AA00AA,   {  5 Magenta:       R=AA  G=00  B=AA  }
    $0055AA,   {  6 Brown:         R=AA  G=55  B=00  }
    $AAAAAA,   {  7 Light Gray:    R=AA  G=AA  B=AA  }
    $555555,   {  8 Dark Gray:     R=55  G=55  B=55  }
    $FF5555,   {  9 Light Blue:    R=55  G=55  B=FF  }
    $55FF55,   { 10 Light Green:   R=55  G=FF  B=55  }
    $FFFF55,   { 11 Light Cyan:    R=55  G=FF  B=FF  }
    $5555FF,   { 12 Light Red:     R=FF  G=55  B=55  }
    $FF55FF,   { 13 Light Magenta: R=FF  G=55  B=FF  }
    $55FFFF,   { 14 Yellow:        R=FF  G=FF  B=55  }
    $FFFFFF    { 15 White:         R=FF  G=FF  B=FF  }
  );

Type
  { Pixel buffer - one byte per pixel, 4-bit color index (0-15).
    Indexed as [X, Y] where X = 0..639, Y = 0..349.
    Total size: 640 * 350 = 224,000 bytes.
    FillChar with 0 clears to black (palette index 0). }
  TPixelBuffer = Array[0..RIP_WIDTH-1, 0..RIP_HEIGHT-1] Of Byte;

  { BGI canvas state - matches Borland Graphics Interface conventions.
    All drawing primitives read FG/FillColor/LineStyle from here.
    Viewport clips all PutPixel calls to ViewX1..ViewX2, ViewY1..ViewY2.
    Palette can be modified per-session by rcSetPalette/rcOnePalette. }
  TBGICanvas = Record
    Pixels     : ^TPixelBuffer;  { pixel buffer (heap allocated)          }
    FG         : Byte;           { foreground color index (0-15)          }
    BG         : Byte;           { background color index (0-15)          }
    FillColor  : Byte;           { flood fill color (0-15)                }
    FillStyle  : Byte;           { fill pattern (0=empty, 1=solid, etc)   }
    LineStyle  : Byte;           { line dash pattern (0=solid, 1=dotted)  }
    LineThick  : Integer;        { line thickness in pixels (1 or 3)      }
    WriteMode  : Byte;           { 0=COPY (overwrite), 1=XOR             }
    CurX, CurY: Integer;        { current cursor position (text output)  }
    ViewX1, ViewY1: Integer;     { viewport top-left (clip region)        }
    ViewX2, ViewY2: Integer;     { viewport bottom-right (clip region)    }
    Palette    : Array[0..15] Of LongWord; { current session palette      }
    FontNum    : Byte;           { current font (0=default 8x16 bitmap)   }
    FontDir    : Byte;           { text direction (0=horiz, 1=vert)       }
    FontSize   : Byte;           { text size multiplier                   }
  End;

Var
  Canvas    : TBGICanvas;        { global canvas state - all units use this }
  DebugMode : Boolean = False;   { print command names during rendering     }
  BaudRate  : LongInt = 0;       { simulated baud rate (0 = no delay)       }
  BaudDelay : LongInt = 0;       { microseconds per byte at current baud    }

Procedure InitCanvas;
Procedure PutPixel(X, Y: Integer; Color: Byte);
Function GetPixel(X, Y: Integer): Byte;

Implementation

Procedure InitCanvas;
{ Allocate pixel buffer and set all state to EGA defaults.
  Called once at program start. Canvas.Pixels is heap-allocated
  because TPixelBuffer is 224KB - too large for the stack.
  FillChar with 0 sets all pixels to color index 0 (black).
  Viewport starts as full screen (0,0 to 639,349). }
Begin
  New(Canvas.Pixels);
  FillChar(Canvas.Pixels^, SizeOf(TPixelBuffer), 0);
  Canvas.FG := 15;         { white foreground }
  Canvas.BG := 0;          { black background }
  Canvas.FillColor := 0;   { fill with black }
  Canvas.FillStyle := 1;   { solid fill }
  Canvas.LineStyle := 0;   { solid line }
  Canvas.LineThick := 1;   { 1 pixel thick }
  Canvas.WriteMode := 0;   { copy mode (overwrite) }
  Canvas.CurX := 0;
  Canvas.CurY := 0;
  Canvas.ViewX1 := 0;
  Canvas.ViewY1 := 0;
  Canvas.ViewX2 := RIP_WIDTH - 1;   { 639 }
  Canvas.ViewY2 := RIP_HEIGHT - 1;  { 349 }
  Canvas.FontNum := 0;     { default bitmap font }
  Canvas.FontDir := 0;     { horizontal }
  Canvas.FontSize := 1;    { 1x scale }
  Move(EGA_PALETTE, Canvas.Palette, SizeOf(EGA_PALETTE));
End;

Procedure PutPixel(X, Y: Integer; Color: Byte);
{ Set one pixel in the canvas buffer.
  Coordinates are VIEWPORT-RELATIVE — offset by ViewX1/ViewY1.
  Then clips to viewport bounds. Matched to JS BGI.js _putpixel:
    x += vp.left; y += vp.top;
  BUG FIX (Session 6): Was using absolute coordinates — viewport
  only clipped without offsetting. v_VIEW test showed only one
  viewport box because shapes at (16,16) weren't offset to
  viewport 2 origin. }
Var AX, AY: Integer;
Begin
  AX := X + Canvas.ViewX1;
  AY := Y + Canvas.ViewY1;
  If (AX >= Canvas.ViewX1) And (AX <= Canvas.ViewX2) And
     (AY >= Canvas.ViewY1) And (AY <= Canvas.ViewY2) Then
    Canvas.Pixels^[AX, AY] := Color And 15;
End;
Function GetPixel(X, Y: Integer): Byte;
{ Read pixel with viewport offset - matches JS getpixel. }
Var AX, AY: Integer;
Begin
  AX := X + Canvas.ViewX1;
  AY := Y + Canvas.ViewY1;
  If (AX >= 0) And (AX < RIP_WIDTH) And (AY >= 0) And (AY < RIP_HEIGHT) Then
    Result := Canvas.Pixels^[AX, AY]
  Else
    Result := 0;
End;

End.
