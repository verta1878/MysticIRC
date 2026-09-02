// ====================================================================
// Mystic BBS IRC Fork — RIP Graphics Pixel Buffer
// ====================================================================
//
// Provides a 640x350 pixel framebuffer for RIP graphics rendering.
// No display driver dependency — pure buffer operations.
// Display drivers (m_output_linux, etc.) can read this buffer to
// paint pixels to screen. ripview reads it for BMP export.
//
// Part of VIPER — V1 Integration of Proper Engine Rendering.
// ====================================================================

{$I M_OPS.PAS}

Unit m_Output_Rip;

Interface

Uses
  m_Types;

Const
  { Standard EGA palette — matches IBM VGA ROM defaults }
  EGA_PALETTE : TEGAPaletteRec = (
    (R:$00; G:$00; B:$00),  { 0  black        }
    (R:$00; G:$00; B:$AA),  { 1  blue         }
    (R:$00; G:$AA; B:$00),  { 2  green        }
    (R:$00; G:$AA; B:$AA),  { 3  cyan         }
    (R:$AA; G:$00; B:$00),  { 4  red          }
    (R:$AA; G:$00; B:$AA),  { 5  magenta      }
    (R:$AA; G:$55; B:$00),  { 6  brown        }
    (R:$AA; G:$AA; B:$AA),  { 7  light gray   }
    (R:$55; G:$55; B:$55),  { 8  dark gray    }
    (R:$55; G:$55; B:$FF),  { 9  light blue   }
    (R:$55; G:$FF; B:$55),  { 10 light green  }
    (R:$55; G:$FF; B:$FF),  { 11 light cyan   }
    (R:$FF; G:$55; B:$55),  { 12 light red    }
    (R:$FF; G:$55; B:$FF),  { 13 light magenta}
    (R:$FF; G:$FF; B:$55),  { 14 yellow       }
    (R:$FF; G:$FF; B:$FF)   { 15 white        }
  );

Type
  TOutputRip = Class
  Private
    FActive   : Boolean;
    FPalette  : TEGAPaletteRec;

  Public
    Pixels    : PPixelBufferRec;

    Constructor Create;
    Destructor  Destroy; Override;

    { Buffer operations }
    Procedure Clear(Color: Byte);
    Procedure PutPixel(X, Y: Integer; Color: Byte);
    Function  GetPixel(X, Y: Integer): Byte;
    Function  InBounds(X, Y: Integer): Boolean;

    { Palette }
    Procedure SetPaletteColor(Index: Byte; R, G, B: Byte);
    Procedure GetPaletteColor(Index: Byte; Var R, G, B: Byte);
    Procedure ResetPalette;

    { BMP export }
    Procedure SaveBMP(Const FileName: String);

    { Blit pixel buffer to text console buffer (for terminal display) }
    Procedure BlitToConsole(Var Buf: TConsoleScreenRec;
                            StartRow, Rows, Cols: Integer);

    Property Active: Boolean Read FActive;
  End;

Implementation

Uses
  SysUtils;

Constructor TOutputRip.Create;
Begin
  Inherited Create;
  New(Pixels);
  FillChar(Pixels^, SizeOf(TPixelBufferRec), 0);
  FPalette := EGA_PALETTE;
  FActive  := True;
End;

Destructor TOutputRip.Destroy;
Begin
  If Pixels <> Nil Then Begin
    Dispose(Pixels);
    Pixels := Nil;
  End;
  Inherited Destroy;
End;

Procedure TOutputRip.Clear(Color: Byte);
Begin
  FillChar(Pixels^, SizeOf(TPixelBufferRec), Color);
End;

Function TOutputRip.InBounds(X, Y: Integer): Boolean;
Begin
  Result := (X >= 0) And (X < RIP_SCREEN_WIDTH) And
            (Y >= 0) And (Y < RIP_SCREEN_HEIGHT);
End;

Procedure TOutputRip.PutPixel(X, Y: Integer; Color: Byte);
Begin
  If InBounds(X, Y) Then
    Pixels^[X, Y] := Color And 15;
End;

Function TOutputRip.GetPixel(X, Y: Integer): Byte;
Begin
  If InBounds(X, Y) Then
    Result := Pixels^[X, Y]
  Else
    Result := 0;
End;

Procedure TOutputRip.SetPaletteColor(Index: Byte; R, G, B: Byte);
Begin
  If Index <= 15 Then Begin
    FPalette[Index].R := R;
    FPalette[Index].G := G;
    FPalette[Index].B := B;
  End;
End;

Procedure TOutputRip.GetPaletteColor(Index: Byte; Var R, G, B: Byte);
Begin
  If Index <= 15 Then Begin
    R := FPalette[Index].R;
    G := FPalette[Index].G;
    B := FPalette[Index].B;
  End;
End;

Procedure TOutputRip.ResetPalette;
Begin
  FPalette := EGA_PALETTE;
End;

Procedure TOutputRip.SaveBMP(Const FileName: String);
Var
  F        : File;
  Row, Col : Integer;
  Pad      : Integer;
  RowSize  : Integer;
  R, G, B  : Byte;
  PIdx     : Byte;
  Zero     : Byte;
  FileSize : LongInt;
  W, H     : Word;
  BmpHdr   : Array[0..53] of Byte;
Begin
  W := RIP_SCREEN_WIDTH;
  H := RIP_SCREEN_HEIGHT;
  RowSize := (W * 3 + 3) And (Not 3);
  Pad := RowSize - W * 3;
  FileSize := 54 + LongInt(RowSize) * H;

  FillChar(BmpHdr, 54, 0);
  BmpHdr[0] := Ord('B');
  BmpHdr[1] := Ord('M');
  Move(FileSize, BmpHdr[2], 4);
  BmpHdr[10] := 54;           { pixel data offset }
  BmpHdr[14] := 40;           { DIB header size }
  Move(W, BmpHdr[18], 2);     { width }
  { Height negative for top-down — but BMP standard uses bottom-up }
  Move(H, BmpHdr[22], 2);     { height (positive = bottom-up) }
  BmpHdr[26] := 1;            { color planes }
  BmpHdr[28] := 24;           { bits per pixel }

  Assign(F, FileName);
  {$I-} ReWrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockWrite(F, BmpHdr, 54);

  Zero := 0;
  { BMP is bottom-up }
  For Row := H - 1 DownTo 0 Do Begin
    For Col := 0 To W - 1 Do Begin
      PIdx := Pixels^[Col, Row] And 15;
      B := FPalette[PIdx].B;
      G := FPalette[PIdx].G;
      R := FPalette[PIdx].R;
      BlockWrite(F, B, 1);
      BlockWrite(F, G, 1);
      BlockWrite(F, R, 1);
    End;
    { Row padding }
    If Pad > 0 Then
      BlockWrite(F, Zero, Pad);
  End;

  Close(F);
End;

Procedure TOutputRip.BlitToConsole(Var Buf: TConsoleScreenRec;
                                    StartRow, Rows, Cols: Integer);
{ Map pixel buffer to text console cells.
  Each cell samples the top-left pixel of its 8x8 block and becomes
  a solid block character (219) with that color as foreground. }
Var
  Row, Col : Integer;
  PIdx     : Byte;
Begin
  For Row := 0 To Rows - 1 Do
    For Col := 0 To Cols - 1 Do Begin
      PIdx := GetPixel(Col * 8, (StartRow + Row) * 8);
      If PIdx > 15 Then PIdx := 0;
      Buf[Row + 1][Col + 1].UnicodeChar := Chr(219);
      Buf[Row + 1][Col + 1].Attributes  := PIdx;
    End;
End;

End.
