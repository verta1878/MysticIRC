(* htmlrend.pas -- HTML 1.0 Direct Pixel Buffer Renderer
   Copyright (C) 2026 Mystic BBS IRC Fork Contributors
   Licensed under GNU General Public License v3.

   Renders an HTML document directly to an RGB24 pixel buffer,
   bypassing the RIP command layer. Used when the host wants
   pixel output without a TRIPEngine instance.

   Uses htmlpars for tokenizing, htmltree for DOM, htmllayo
   for layout, then draws text and elements directly to pixels.

   Usage:
     HTMLRenderToBuffer(Source, Len, Pixels, 640, 350);
     // Pixels now contains the rendered HTML page
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit htmlrend;

interface

Uses htmlpars, htmltree, htmllayo;

// Forward declare ParseHTMLColor from htmllayo
// (already in Uses, accessible)

// Render HTML source directly to an RGB24 pixel buffer
// Pixels must be pre-allocated: W * H * 3 bytes
procedure HTMLRenderToBuffer(Source: PChar; SrcLen: LongInt;
                             Pixels: PByte; W, H: Word);

// Render a pre-computed layout to an RGB24 pixel buffer
procedure HTMLRenderLayout(var Layout: THTMLLayout;
                           Pixels: PByte; W, H: Word);

implementation

// ====================================================================
// Pixel drawing primitives (self-contained, no engine dependency)
// ====================================================================

procedure PutPixelRGB(Pixels: PByte; W, H: Word; X, Y: SmallInt;
                      R, G, B: Byte);
Var Ofs : LongInt;
Begin
  If (X < 0) or (X >= W) or (Y < 0) or (Y >= H) Then Exit;
  Ofs := (LongInt(Y) * W + X) * 3;
  Pixels[Ofs]     := R;
  Pixels[Ofs + 1] := G;
  Pixels[Ofs + 2] := B;
End;

procedure DrawHLine(Pixels: PByte; W, H: Word;
                    X1, X2, Y: SmallInt; R, G, B: Byte);
Var X : SmallInt;
Begin
  If (Y < 0) or (Y >= H) Then Exit;
  If X1 < 0 Then X1 := 0;
  If X2 >= W Then X2 := W - 1;
  For X := X1 to X2 Do
    PutPixelRGB(Pixels, W, H, X, Y, R, G, B);
End;

procedure FillRect(Pixels: PByte; W, H: Word;
                   X1, Y1, X2, Y2: SmallInt; R, G, B: Byte);
Var Y : SmallInt;
Begin
  For Y := Y1 to Y2 Do
    DrawHLine(Pixels, W, H, X1, X2, Y, R, G, B);
End;

// Simple 8x8 character renderer using CP437 bitmap font
// We draw a simple block representation — real font rendering
// would use the engine's DrawText8x8 or DrawTextRFF
procedure DrawChar8x8(Pixels: PByte; W, H: Word;
                      X, Y: SmallInt; C: Char; R, G, B: Byte);
// Simplified: draw a filled block for non-space characters
// Full implementation would use rip_font8x8.inc glyph data
Var
  CX, CY : SmallInt;
Begin
  If C = ' ' Then Exit;
  // Draw a 6x8 glyph placeholder
  For CY := 0 to 7 Do
    For CX := 0 to 5 Do
      PutPixelRGB(Pixels, W, H, X + CX, Y + CY, R, G, B);
End;

procedure DrawText(Pixels: PByte; W, H: Word;
                   X, Y: SmallInt; const Text: String;
                   FontSize: Byte; R, G, B: Byte;
                   Bold, Underline: Boolean);
Var
  I     : Integer;
  CharW : SmallInt;
  CX    : SmallInt;
Begin
  // Character width based on font size
  CharW := (FontSize * 6) DIV 10;
  If CharW < 4 Then CharW := 4;

  CX := X;
  For I := 1 to Length(Text) Do Begin
    If CX + CharW > W Then Break; // clip right edge

    // Scale: for sizes > 8, multiply Y range
    DrawChar8x8(Pixels, W, H, CX, Y, Text[I], R, G, B);
    CX := CX + CharW;

    // Bold: draw again offset by 1
    If Bold Then
      DrawChar8x8(Pixels, W, H, CX - CharW + 1, Y, Text[I], R, G, B);
  End;

  // Underline
  If Underline and (Length(Text) > 0) Then
    DrawHLine(Pixels, W, H, X, CX, Y + FontSize - 1, R, G, B);
End;

// ====================================================================
// Layout → Pixel rendering
// ====================================================================

procedure RenderBox(var Box: THTMLBox; Pixels: PByte; W, H: Word);
Var
  Node  : PHTMLNode;
  Var_S : String;
Begin
  Node := Box.Node;
  If Node = Nil Then Exit;

  // Text node
  If Node^.Kind = hnkText Then Begin
    If Length(Node^.Text) > 0 Then
      DrawText(Pixels, W, H, Box.X, Box.Y, Node^.Text,
               Box.Font.Size,
               Box.Font.ColorR, Box.Font.ColorG, Box.Font.ColorB,
               Box.Font.Bold, Box.Font.Underline);
    Exit;
  End;

  If Node^.Kind <> hnkElement Then Exit;

  Case Node^.TagID of
    htHR: Begin
      // Horizontal rule
      DrawHLine(Pixels, W, H, Box.X, Box.X + Box.W, Box.Y,
                128, 128, 128);
      DrawHLine(Pixels, W, H, Box.X, Box.X + Box.W, Box.Y + 1,
                64, 64, 64);
    End;

    htLI: Begin
      // Bullet or number
      If Box.ListIndex > 0 Then Begin
        // Ordered list number
        Var_S := '';
        Str(Box.ListIndex, Var_S);
        Var_S := Var_S + '.';
        DrawText(Pixels, W, H, Box.X - 16, Box.Y, Var_S,
                 Box.Font.Size,
                 Box.Font.ColorR, Box.Font.ColorG, Box.Font.ColorB,
                 False, False);
      End Else Begin
        // Bullet: filled circle (4x4 block)
        FillRect(Pixels, W, H,
                 Box.X - 10, Box.Y + 3,
                 Box.X - 7,  Box.Y + 6,
                 Box.Font.ColorR, Box.Font.ColorG, Box.Font.ColorB);
      End;
    End;

    htINPUT: Begin
      DrawHLine(Pixels, W, H, Box.X, Box.X + 120, Box.Y, 192, 192, 192);
      DrawHLine(Pixels, W, H, Box.X, Box.X + 120, Box.Y + Box.Font.Size + 2, 192, 192, 192);
      FillRect(Pixels, W, H, Box.X, Box.Y, Box.X, Box.Y + Box.Font.Size + 2, 192, 192, 192);
      FillRect(Pixels, W, H, Box.X + 120, Box.Y, Box.X + 120, Box.Y + Box.Font.Size + 2, 192, 192, 192);
    End;

    htSELECT: Begin
      DrawHLine(Pixels, W, H, Box.X, Box.X + 100, Box.Y, 192, 192, 192);
      DrawHLine(Pixels, W, H, Box.X, Box.X + 100, Box.Y + Box.Font.Size + 2, 192, 192, 192);
      FillRect(Pixels, W, H, Box.X, Box.Y, Box.X, Box.Y + Box.Font.Size + 2, 192, 192, 192);
      FillRect(Pixels, W, H, Box.X + 100, Box.Y, Box.X + 100, Box.Y + Box.Font.Size + 2, 192, 192, 192);
    End;

    htTEXTAREA: Begin
      DrawHLine(Pixels, W, H, Box.X, Box.X + 200, Box.Y, 192, 192, 192);
      DrawHLine(Pixels, W, H, Box.X, Box.X + 200, Box.Y + 40, 192, 192, 192);
      FillRect(Pixels, W, H, Box.X, Box.Y, Box.X, Box.Y + 40, 192, 192, 192);
      FillRect(Pixels, W, H, Box.X + 200, Box.Y, Box.X + 200, Box.Y + 40, 192, 192, 192);
    End;
  End;
End;

procedure HTMLRenderLayout(var Layout: THTMLLayout;
                           Pixels: PByte; W, H: Word);
Var I : Integer;
Begin
  // Clear to dark background (BBS style)
  FillChar(Pixels^, LongInt(W) * H * 3, 0);

  For I := 0 to Layout.BoxCount - 1 Do
    RenderBox(Layout.Boxes[I], Pixels, W, H);
End;

procedure HTMLRenderToBuffer(Source: PChar; SrcLen: LongInt;
                             Pixels: PByte; W, H: Word);
Var
  PTree   : ^THTMLTree;
  Layout  : THTMLLayout;
  BgNode  : PHTMLNode;
  BgColor : String;
  R, G, B : Byte;
Begin
  New(PTree);
  HTMLTreeParse(PTree^, Source, SrcLen);

  // Check for BODY BGCOLOR
  R := 0; G := 0; B := 0;  // default black
  BgNode := HTMLTreeFindTag(PTree^, htBODY);
  If BgNode <> Nil Then Begin
    BgColor := HTMLNodeGetAttr(BgNode, 'BGCOLOR');
    If Length(BgColor) > 0 Then
      ParseHTMLColor(BgColor, R, G, B);
  End;
  FillRect(Pixels, W, H, 0, 0, W - 1, H - 1, R, G, B);

  HTMLLayoutCompute(Layout, PTree^, W, H);
  HTMLRenderLayout(Layout, Pixels, W, H);
  HTMLTreeFree(PTree^);
  Dispose(PTree);
End;

end.
