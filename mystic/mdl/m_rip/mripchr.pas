{ m_rip_chrfont.pas — BGI CHR Stroked Font Parser
  Built from Easy Fonts v2.0 documentation and SHOWFONT.PAS reference.

  CHR format: vector/stroked fonts used by Borland Graphics Interface.
  Each character is defined as a series of pen-up/pen-down + x,y moves.
  Used by RIPscrip for text rendering with |Y (FontStyle) command.

  CHR format documentation from Easy Fonts v2.0 by Pino Navato.
  Easy Fonts registered to verta1878 — converts TrueType to CHR.
  SHOWFONT.PAS reference by Pino Navato (Easy Fonts, Borland BGI demo).

  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench, hexadecimal, byte. }
{$MODE OBJFPC}
{$H+}
Unit mripchr;

Interface

Const
  CHR_MAX_CHARS  = 256;
  CHR_MAX_STROKES = 32000;
  CHR_MAGIC      = $4B50;  { 'PK' }

  { Stroke opcodes (encoded in high bits of x,y bytes) }
  CHR_STROKE_END  = 0;  { end of character }
  CHR_STROKE_MOVE = 1;  { pen up, move to x,y }
  CHR_STROKE_DRAW = 2;  { pen down, draw to x,y }

Type
  TCHRStroke = Record
    OpCode : Byte;    { 0=end, 1=move(pen up), 2=draw(pen down) }
    X, Y   : SmallInt;
  End;

  TCHRDrawLineProc = Procedure(X1, Y1, X2, Y2: Integer);

  TCHRCharDef = Record
    Width    : SmallInt;  { character width }
    Offset   : Word;      { offset into stroke data }
    NumStrokes : Word;    { number of strokes }
  End;

  TCHRFont = Record
    { Header }
    FontName   : String[4];   { 4-char name (Borland requirement) }
    HeaderText : String[80];  { copyright/description text }
    Version    : Word;        { font version }

    { Metrics }
    FirstChar  : Byte;        { first defined character (usually 32) }
    LastChar   : Byte;        { last defined character }
    OrgToCap   : SmallInt;    { origin to capital height (negative = above baseline) }
    OrgToBase  : SmallInt;    { origin to baseline }
    OrgToBot   : SmallInt;    { origin to descender bottom }

    { Character definitions }
    CharDefs   : Array[0..CHR_MAX_CHARS-1] of TCHRCharDef;

    { Stroke data }
    Strokes    : Array[0..CHR_MAX_STROKES-1] of TCHRStroke;
    StrokeCount: Word;

    { State }
    Loaded     : Boolean;
  End;

Function  LoadCHRFont(const FileName: String; var Font: TCHRFont): Boolean;
Procedure DrawCHRChar(var Font: TCHRFont; Ch: Char; X, Y, Size: Integer;
            DrawLine: TCHRDrawLineProc);
Procedure DrawCHRText(var Font: TCHRFont; const Text: String; X, Y, Size: Integer;
            DrawLine: TCHRDrawLineProc);
Function  CHRTextWidth(var Font: TCHRFont; const Text: String; Size: Integer): Integer;
Function  CHRTextHeight(var Font: TCHRFont; Size: Integer): Integer;

Implementation

Uses SysUtils;

Function LoadCHRFont(const FileName: String; var Font: TCHRFont): Boolean;
{ CHR file format (from Easy Fonts v2.0 docs by Pino Navato):

  TEXT HEADER (variable length):
    0x00-0x01: 'PK' magic (0x50, 0x4B)
    0x02: header size indicator
    0x03: file type (0x08 = stroked font)
    0x04+: ASCII text (copyright string)
    ...
    0x1A byte: DOS EOF marker

  BINARY HEADER (at text header size offset):
    +0x00: header size (word, little-endian) — usually 0x0080
    +0x02: font name (4 bytes, padded)
    +0x06: font data size (word)
    +0x08: font version major
    +0x09: font version minor
    +0x0A: BGI driver version

  DATA BLOCK (at header size):
    +0x00: stroke data start marker
    +0x02: number of chars in font
    +0x04: first char code (usually 0x20 = space)
    +0x06: stroke data offset from start of data block
    +0x08: scan flag
    +0x09: org to cap (signed byte — negative = above baseline)
    +0x0A: org to baseline (signed byte)
    +0x0B: org to descender (signed byte)
    +0x0C: unused[4]
    +0x10: char width table (1 byte per char)
    +0x10+numchars: char offset table (2 bytes per char, LE)
    After offsets: stroke data

  STROKE ENCODING (2 bytes per stroke):
    Byte 0: x coordinate (bits 0-6) + opcode bit 7
    Byte 1: y coordinate (bits 0-6) + opcode bit 7
    Opcode: bit7(byte1):bit7(byte0)
      0:0 = end of character
      1:0 = pen up, move to (x,y)
      0:1 = pen down, draw to (x,y)
      1:1 = pen down, draw to (x,y)
    X,Y are signed 7-bit (-64..+63)
}
Var
  F: File;
  Buf: Array[0..16383] of Byte;
  BytesRead: Integer;
  I, P, HeaderSize: Integer;
  NumChars, FirstChar: Integer;
  StrokeOfs: Word;
  B0, B1: Byte;
  SX, SY: SmallInt;
  Op: Byte;
  CharIdx: Integer;
Begin
  Result := False;
  FillChar(Font, SizeOf(Font), 0);

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockRead(F, Buf, SizeOf(Buf), BytesRead);
  Close(F);

  If BytesRead < 128 Then Exit;

  { Check magic }
  If (Buf[0] <> $50) or (Buf[1] <> $4B) Then Exit;  { 'PK' }

  { Read text header — scan for 0x1A (DOS EOF marker) }
  P := 2;
  Font.HeaderText := '';
  While (P < BytesRead) and (Buf[P] <> $1A) Do Begin
    If (Buf[P] >= 32) and (Buf[P] < 127) and (Length(Font.HeaderText) < 80) Then
      Font.HeaderText := Font.HeaderText + Chr(Buf[P]);
    Inc(P);
  End;

  If P >= BytesRead Then Exit;
  Inc(P);  { skip 0x1A }

  { Binary header starts here }
  HeaderSize := Buf[P] or (Buf[P+1] shl 8);
  Inc(P, 2);

  { Font name — 4 chars }
  Font.FontName := '';
  For I := 0 to 3 Do
    If Buf[P+I] >= 32 Then Font.FontName := Font.FontName + Chr(Buf[P+I]);
  Inc(P, 4);

  { Skip font data size + version }
  Font.Version := Buf[P+2];
  P := HeaderSize;  { jump to data block }

  If P >= BytesRead Then Exit;

  { Data block header }
  { +0: sign char '+' }
  { +1: number of chars (byte) }
  NumChars := Buf[P+1];
  If NumChars = 0 Then NumChars := 256;  { 0 means 256 }
  If NumChars > CHR_MAX_CHARS Then NumChars := CHR_MAX_CHARS;

  { +2-3: reserved (0x0000) }
  { +4: first char code }
  FirstChar := Buf[P+4];
  Font.FirstChar := FirstChar;
  Font.LastChar := FirstChar + NumChars - 1;
  If Font.LastChar > 255 Then Font.LastChar := 255;

  { +5-6: stroke data offset from data block start (word LE) }
  StrokeOfs := Buf[P+5] or (Buf[P+6] shl 8);

  { +7: reserved }
  { +8: org to cap (signed byte) }
  Font.OrgToCap := ShortInt(Buf[P+8]);
  { +9: reserved }
  { +10: org to bot (signed byte) }
  Font.OrgToBot := ShortInt(Buf[P+10]);
  Font.OrgToBase := 0;  { baseline is at origin }

  { Character offset table: starts at P+16, 2 bytes per char (word LE) }
  For I := 0 to NumChars-1 Do Begin
    CharIdx := FirstChar + I;
    If CharIdx < CHR_MAX_CHARS Then
      Font.CharDefs[CharIdx].Offset := Buf[P+16+I*2] or
                                        (Buf[P+16+I*2+1] shl 8);
  End;

  { Character width table: starts after offset table, 1 byte per char }
  For I := 0 to NumChars-1 Do Begin
    CharIdx := FirstChar + I;
    If CharIdx < CHR_MAX_CHARS Then
      Font.CharDefs[CharIdx].Width := Buf[P+16+NumChars*2+I];
  End;

  { Parse stroke data for each character }
  Font.StrokeCount := 0;

  For I := 0 to NumChars-1 Do Begin
    CharIdx := FirstChar + I;
    If CharIdx >= CHR_MAX_CHARS Then Continue;

    { Stroke data offset for this char (relative to stroke data start) }
    P := HeaderSize + StrokeOfs + Font.CharDefs[CharIdx].Offset;
    Font.CharDefs[CharIdx].Offset := Font.StrokeCount;  { update to absolute index }
    Font.CharDefs[CharIdx].NumStrokes := 0;

    { Read strokes until end-of-char marker }
    While P + 1 < BytesRead Do Begin
      B0 := Buf[P];
      B1 := Buf[P+1];
      Inc(P, 2);

      { Decode opcode from high bits: bit7(B1):bit7(B0) }
      Op := ((B1 and $80) shr 6) or ((B0 and $80) shr 7);

      { Decode signed 7-bit coordinates }
      SX := B0 and $7F;
      If SX >= 64 Then SX := SX - 128;
      SY := B1 and $7F;
      If SY >= 64 Then SY := SY - 128;

      If Font.StrokeCount < CHR_MAX_STROKES Then Begin
        Font.Strokes[Font.StrokeCount].OpCode := Op;
        Font.Strokes[Font.StrokeCount].X := SX;
        Font.Strokes[Font.StrokeCount].Y := SY;
        Inc(Font.StrokeCount);
        Inc(Font.CharDefs[CharIdx].NumStrokes);
      End;

      If Op = CHR_STROKE_END Then Break;
    End;
  End;

  Font.Loaded := True;
  Result := True;
End;

Procedure DrawCHRChar(var Font: TCHRFont; Ch: Char; X, Y, Size: Integer;
            DrawLine: TCHRDrawLineProc);
Var
  CharIdx: Integer;
  I, StartIdx, EndIdx: Integer;
  CurX, CurY: Integer;
  SX, SY: Integer;
  PenDown: Boolean;
Begin
  If Not Font.Loaded Then Exit;

  CharIdx := Ord(Ch);
  If (CharIdx < Font.FirstChar) or (CharIdx > Font.LastChar) Then Exit;
  If Font.CharDefs[CharIdx].NumStrokes = 0 Then Exit;

  StartIdx := Font.CharDefs[CharIdx].Offset;
  EndIdx := StartIdx + Font.CharDefs[CharIdx].NumStrokes - 1;

  CurX := X;
  CurY := Y;
  PenDown := False;

  For I := StartIdx to EndIdx Do Begin
    SX := X + (Font.Strokes[I].X * Size);
    SY := Y + (Font.Strokes[I].Y * Size);

    Case Font.Strokes[I].OpCode of
      CHR_STROKE_END: Break;
      CHR_STROKE_MOVE: Begin
        CurX := SX;
        CurY := SY;
        PenDown := False;
      End;
      CHR_STROKE_DRAW: Begin
        If PenDown Then
          DrawLine(CurX, CurY, SX, SY);
        CurX := SX;
        CurY := SY;
        PenDown := True;
      End;
    End;
  End;
End;

Procedure DrawCHRText(var Font: TCHRFont; const Text: String; X, Y, Size: Integer;
            DrawLine: TCHRDrawLineProc);
Var
  I: Integer;
  CurX: Integer;
  CharIdx: Integer;
Begin
  If Not Font.Loaded Then Exit;

  CurX := X;
  For I := 1 to Length(Text) Do Begin
    DrawCHRChar(Font, Text[I], CurX, Y, Size, DrawLine);
    CharIdx := Ord(Text[I]);
    If (CharIdx >= Font.FirstChar) and (CharIdx <= Font.LastChar) Then
      CurX := CurX + (Font.CharDefs[CharIdx].Width * Size)
    Else
      CurX := CurX + (8 * Size);  { default width for undefined chars }
  End;
End;

Function CHRTextWidth(var Font: TCHRFont; const Text: String; Size: Integer): Integer;
Var
  I, CharIdx, W: Integer;
Begin
  W := 0;
  For I := 1 to Length(Text) Do Begin
    CharIdx := Ord(Text[I]);
    If (CharIdx >= Font.FirstChar) and (CharIdx <= Font.LastChar) Then
      W := W + Font.CharDefs[CharIdx].Width * Size
    Else
      W := W + 8 * Size;
  End;
  Result := W;
End;

Function CHRTextHeight(var Font: TCHRFont; Size: Integer): Integer;
Begin
  If Font.Loaded Then
    Result := (Font.OrgToCap - Font.OrgToBot) * Size
  Else
    Result := 8 * Size;
End;

End.
