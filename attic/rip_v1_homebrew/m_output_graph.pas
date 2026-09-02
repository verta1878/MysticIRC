{ m_output_graph.pas — Graphics paint hook for TOutput
  Renders TConsoleScreenRec buffer to ptcgraph canvas using Font8x8.
  Called from ShowBuffer when USEGRAPH is defined.

  The text console writes to Buffer (80x25 TCharInfo array) as normal.
  This unit reads that buffer and paints each character as 8x8 pixels
  with the correct foreground/background colors from the Attributes byte.

  Part of Mystic BBS, MAKEMENU, MAKETEXT.

  Copyright (C) 2026 FPC264IRC Contributors.
  License: GPLv3. }
{$MODE DELPHI}
Unit m_output_graph;

Interface

Uses
  m_Types;

Procedure GraphPaintBuffer(var Buffer: TConsoleScreenRec; Rows, Cols: Integer);

Implementation

Uses
  ptcgraph;

{$I m_rip/rip_font8x8.inc}

Const
  { EGA 16-color palette — map text attribute to RGB }
  EGA_R: Array[0..15] of Byte = (0, 0, 0, 0, 170, 170, 170, 170, 85, 85, 85, 85, 255, 255, 255, 255);
  EGA_G: Array[0..15] of Byte = (0, 0, 170, 170, 0, 0, 85, 170, 85, 85, 255, 255, 85, 85, 255, 255);
  EGA_B: Array[0..15] of Byte = (0, 170, 0, 170, 0, 170, 0, 170, 85, 255, 85, 255, 85, 255, 85, 255);

Procedure GraphPaintBuffer(var Buffer: TConsoleScreenRec; Rows, Cols: Integer);
Var
  Row, Col, PX, PY, FontRow, FontCol: Integer;
  Ch: Byte;
  Attr, FG, BG: Byte;
  Bits: Byte;
Begin
  For Row := 1 to Rows Do Begin
    For Col := 1 to Cols Do Begin
      Ch := Ord(Buffer[Row][Col].UnicodeChar);
      Attr := Buffer[Row][Col].Attributes;
      FG := Attr and $0F;
      BG := (Attr shr 4) and $07;

      PX := (Col - 1) * 8;
      PY := (Row - 1) * 8;

      { Draw 8x8 character cell }
      For FontRow := 0 to 7 Do Begin
        Bits := Font8x8[Ch * 8 + FontRow];
        For FontCol := 0 to 7 Do Begin
          If (Bits and (128 shr FontCol)) <> 0 Then
            PutPixel(PX + FontCol, PY + FontRow, FG)
          Else
            PutPixel(PX + FontCol, PY + FontRow, BG);
        End;
      End;
    End;
  End;
End;

End.
