{$MODE DELPHI}
{$H-}
Unit RIPText;
{
  RIPView Text Rendering - VGA bitmap + BGI CHR vector fonts.
  Ported from RIPtermJS BGI.js by Carl Gorringe - drawPNGChar() and drawStrokeChar().

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses SysUtils, RIPEngine, RIPDraw;

Procedure DrawBitmapChar(Value: Byte; X0, Y0: Integer);
Procedure OutTextXY(X, Y: Integer; const Text: String);
Procedure OutText(const Text: String);
Procedure SetTextStyle(Font, Direction, CharSize: Integer);
Function TextWidth(const Text: String): Integer;
Function TextHeight: Integer;

Implementation

Const
  CHRFontNames : Array[1..10] Of String[8] = (
    'TRIP', 'LITT', 'SANS', 'GOTH', 'SCRI',
    'SIMP', 'TSCR', 'LCOM', 'EURO', 'BOLD'
  );

  FontScales : Array[0..10] Of Double = (
    1.0, 0.6, 0.667, 0.75, 1.0, 1.333, 1.667, 2.0, 2.5, 3.0, 4.0
  );

  CHR_MAX_CHARS   = 256;
  CHR_MAX_STROKES = 16384;

Type
  TCHRStroke = Record
    Op : Byte;
    X  : SmallInt;
    Y  : SmallInt;
  End;

  TCHRFont = Record
    Loaded     : Boolean;
    FirstChar  : Byte;
    NumChars   : Word;
    OrgToCap   : SmallInt;
    OrgToBase  : SmallInt;
    Widths     : Array[0..CHR_MAX_CHARS-1] Of Byte;
    Offsets    : Array[0..CHR_MAX_CHARS-1] Of Word;
    Strokes    : Array[0..CHR_MAX_STROKES-1] Of TCHRStroke;
    NumStrokes : Word;
  End;
  PCHRFont = ^TCHRFont;

Var
  CHRFonts   : Array[1..10] Of PCHRFont;
  FontsInit  : Boolean = False;
  FontPath   : String = 'fonts' + DirectorySeparator;

{$I rip_font8x16.inc}

Procedure InitFonts;
Var I: Integer;
Begin
  For I := 1 to 10 Do CHRFonts[I] := Nil;
  FontsInit := True;
End;

Function LoadCHRFont(FontNum: Byte): Boolean;
Type
  TLoadBuf = Array[0..32767] Of Byte;
  PLoadBuf = ^TLoadBuf;
Var
  F        : File;
  Data     : PLoadBuf;
  FileLen  : LongInt;
  I, FPos, PathIdx : Integer;
  PlusOff  : Integer;
  NC       : Word;
  FC       : Byte;
  B1, B2   : Byte;
  SX, SY   : SmallInt;
  Op       : Byte;
  FileName : String;
  OtStart, WtStart: Integer;
Begin
  Result := False;
  If (FontNum < 1) Or (FontNum > 10) Then Exit;
  If Not FontsInit Then InitFonts;
  If (CHRFonts[FontNum] <> Nil) And CHRFonts[FontNum]^.Loaded Then Begin
    Result := True; Exit;
  End;

  FileName := '';
  For PathIdx := 0 to 2 Do Begin
    Case PathIdx Of
      0: FileName := FontPath + CHRFontNames[FontNum] + '.CHR';
      1: FileName := '..' + DirectorySeparator + FontPath + CHRFontNames[FontNum] + '.CHR';
      2: FileName := CHRFontNames[FontNum] + '.CHR';
    End;
    If FileExists(FileName) Then Break;
    FileName := '';
  End;
  If FileName = '' Then Exit;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  New(Data);
  FileLen := FileSize(F);
  If FileLen > SizeOf(Data^) Then FileLen := SizeOf(Data^);
  BlockRead(F, Data^, FileLen);
  Close(F);

  PlusOff := -1;
  For I := 80 to FileLen - 20 Do
    If Data^[I] = $2B Then Begin
      NC := Data^[I+1] Or (Data^[I+2] Shl 8);
      FC := Data^[I+4];
      If (NC >= 32) And (NC <= 256) And (FC >= 32) And (FC <= 127) Then Begin
        PlusOff := I; Break;
      End;
    End;

  If PlusOff < 0 Then Begin Dispose(Data); Exit; End;

  If CHRFonts[FontNum] <> Nil Then Dispose(CHRFonts[FontNum]);
  New(CHRFonts[FontNum]);

  With CHRFonts[FontNum]^ Do Begin
    Loaded    := True;
    NumChars  := NC;
    FirstChar := FC;
    OrgToCap  := SmallInt(Data^[PlusOff + 8]);
    OrgToBase := SmallInt(Data^[PlusOff + 9]);

    OtStart := PlusOff + 16;
    For I := 0 to NumChars - 1 Do
      If I < CHR_MAX_CHARS Then
        Offsets[I] := Data^[OtStart + I*2] Or (Data^[OtStart + I*2 + 1] Shl 8);

    WtStart := OtStart + NumChars * 2;
    For I := 0 to NumChars - 1 Do
      If I < CHR_MAX_CHARS Then
        Widths[I] := Data^[WtStart + I];

    NumStrokes := 0;
    For I := 0 to NumChars - 1 Do Begin
      If I >= CHR_MAX_CHARS Then Break;
      Offsets[I] := NumStrokes;
      FPos := WtStart + NumChars +
              (Data^[OtStart + I*2] Or (Data^[OtStart + I*2 + 1] Shl 8));
      Repeat
        If (FPos + 1 >= FileLen) Or (NumStrokes >= CHR_MAX_STROKES) Then Break;
        B1 := Data^[FPos]; B2 := Data^[FPos + 1];
        If (B1 And $40) <> 0 Then SX := -((-B1) And $3F)
        Else SX := B1 And $3F;
        If (B2 And $40) <> 0 Then SY := -((-B2) And $3F)
        Else SY := B2 And $3F;
        If (B1 And $80 = 0) And (B2 And $80 = 0) Then Op := 0
        Else If (B2 And $80 = 0) Then Op := 1
        Else Op := 2;
        Strokes[NumStrokes].Op := Op;
        Strokes[NumStrokes].X := SX;
        Strokes[NumStrokes].Y := SY;
        Inc(NumStrokes);
        Inc(FPos, 2);
      Until Op = 0;
    End;
  End;
  Dispose(Data);
  Result := True;
End;

Procedure DrawCHRChar(FontNum: Byte; Value: Byte; X0, Y0: Integer);
Var
  CharIdx, DX, DY, PenX, PenY, DestX, DestY: Integer;
  ActualScale: Double;
  J: Integer;
  StrokeOff: Word;
Begin
  If (FontNum < 1) Or (FontNum > 10) Then Exit;
  If CHRFonts[FontNum] = Nil Then Exit;
  If Not CHRFonts[FontNum]^.Loaded Then Exit;
  If Canvas.FontSize <= 10 Then ActualScale := FontScales[Canvas.FontSize]
  Else ActualScale := 1.0;
  With CHRFonts[FontNum]^ Do Begin
    CharIdx := Value - FirstChar;
    If (CharIdx < 0) Or (CharIdx >= NumChars) Then Exit;
    StrokeOff := Offsets[CharIdx];
    PenX := X0; PenY := Y0;
    J := StrokeOff;
    While J < NumStrokes Do Begin
      DX := Trunc(Strokes[J].X * ActualScale);
      DY := Trunc(Strokes[J].Y * ActualScale);
      If Canvas.FontDir = 0 Then Begin
        DestX := X0 + DX; DestY := Y0 - DY;
      End Else Begin
        DestX := X0 - DY; DestY := Y0 - DX;
      End;
      Case Strokes[J].Op Of
        0: Break;
        1: Begin PenX := DestX; PenY := DestY; End;
        2: Begin
             DrawLine(PenX, PenY, DestX, DestY, Canvas.FG);
             PenX := DestX; PenY := DestY;
           End;
      End;
      Inc(J);
    End;
    If Canvas.FontDir = 0 Then Begin
      Canvas.CurX := X0 + Trunc(Widths[CharIdx] * ActualScale);
      Canvas.CurY := Y0;
    End Else Begin
      Canvas.CurX := X0;
      Canvas.CurY := Y0 + Trunc(Widths[CharIdx] * ActualScale);
    End;
  End;
End;

Procedure DrawBitmapChar(Value: Byte; X0, Y0: Integer);
Var
  Scale, XSize, YSize, X, Y, X1, Y1: Integer;
  ScanLine: Byte;
Begin
  Scale := Canvas.FontSize;
  If Scale < 1 Then Scale := 1;
  XSize := 8; YSize := 16;
  For Y := 0 to YSize - 1 Do Begin
    ScanLine := VGAFont[Value * 16 + Y];
    For X := 0 to XSize - 1 Do Begin
      If (ScanLine And $80) <> 0 Then Begin
        If Scale > 1 Then Begin
          If Canvas.FontDir = 0 Then Begin
            X1 := X0 + (X * Scale); Y1 := Y0 + (Y * Scale);
          End Else Begin
            X1 := X0 + (Y * Scale); Y1 := Y0 - (X * Scale);
          End;
          FillRect(X1, Y1, X1 + Scale - 1, Y1 + Scale - 1, Canvas.FG);
        End Else Begin
          If Canvas.FontDir = 0 Then PutPixel(X0 + X, Y0 + Y, Canvas.FG)
          Else PutPixel(X0 + Y, Y0 - X, Canvas.FG);
        End;
      End;
      ScanLine := ScanLine Shl 1;
    End;
  End;
  If Canvas.FontDir = 0 Then Canvas.CurX := X0 + (XSize * Scale)
  Else Canvas.CurY := Y0 - (XSize * Scale);
End;

Procedure OutTextXY(X, Y: Integer; const Text: String);
Var
  I, R, C: Integer;
  ActualScale: Double;
  YOffset: Integer;
Begin
  Canvas.CurX := X; Canvas.CurY := Y;
  If (Canvas.FontNum >= 1) And (Canvas.FontNum <= 10) Then Begin
    If LoadCHRFont(Canvas.FontNum) Then Begin
      If Canvas.FontSize <= 10 Then ActualScale := FontScales[Canvas.FontSize]
      Else ActualScale := 1.0;
      If (CHRFonts[Canvas.FontNum] <> Nil) And
         CHRFonts[Canvas.FontNum]^.Loaded Then Begin
        If Canvas.FontDir = 0 Then Begin
          YOffset := Trunc(CHRFonts[Canvas.FontNum]^.OrgToCap * ActualScale);
          Canvas.CurY := Y + YOffset;
        End Else Begin
          YOffset := Trunc(CHRFonts[Canvas.FontNum]^.OrgToCap * ActualScale);
          Canvas.CurX := X + YOffset;
        End;
      End;
      For I := 1 to Length(Text) Do
        DrawCHRChar(Canvas.FontNum, Ord(Text[I]), Canvas.CurX, Canvas.CurY);
      Exit;
    End;
  End;
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

Function TextWidth(const Text: String): Integer;
Var I, C, W: Integer;
    ActualScale: Double;
Begin
  If (Canvas.FontNum >= 1) And (Canvas.FontNum <= 10) And
     (CHRFonts[Canvas.FontNum] <> Nil) And
     CHRFonts[Canvas.FontNum]^.Loaded Then Begin
    If Canvas.FontSize <= 10 Then ActualScale := FontScales[Canvas.FontSize]
    Else ActualScale := 1.0;
    W := 0;
    With CHRFonts[Canvas.FontNum]^ Do
      For I := 1 to Length(Text) Do Begin
        C := Ord(Text[I]) - FirstChar;
        If (C >= 0) And (C < NumChars) Then
          W := W + Widths[C];
      End;
    Result := Trunc(W * ActualScale);
  End Else
    Result := Length(Text) * Canvas.FontSize * 8;
End;

Function TextHeight: Integer;
Var ActualScale: Double;
Begin
  If (Canvas.FontNum >= 1) And (Canvas.FontNum <= 10) And
     (CHRFonts[Canvas.FontNum] <> Nil) And
     CHRFonts[Canvas.FontNum]^.Loaded Then Begin
    If Canvas.FontSize <= 10 Then ActualScale := FontScales[Canvas.FontSize]
    Else ActualScale := 1.0;
    Result := Trunc(CHRFonts[Canvas.FontNum]^.OrgToCap * ActualScale);
  End Else
    Result := Canvas.FontSize * 16;
End;
End.
