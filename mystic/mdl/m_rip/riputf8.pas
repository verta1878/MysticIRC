{ =========================================================================

  riputf8.pas — UTF-8 Codec and CP437 ↔ Unicode Mapping
  Part of the RIPscrip 3.0 UTF-8 extension (kiddo's lane)

  Follows the Ripscrip.dll MultiByteToWideChar/WideCharToMultiByte
  pattern: bytes in → wide chars (UCS-4 codepoints) → render via
  CP437 glyph index for bitmap/vector fonts.

  Shared unit — used by both mystic_ripview and mystic_mterm.

  2026-10-29  kiddo  Initial implementation

  ========================================================================= }

{$MODE OBJFPC}
{$H+}

Unit riputf8;

Interface

Type
  { UTF-8 decode result — codepoint + how many bytes consumed }
  TUTF8DecodeResult = Record
    CodePoint : LongWord;   { UCS-4 codepoint (0..$10FFFF) }
    Advance   : Integer;    { bytes consumed (1-4, or 0 on error) }
  End;

{ --- Core UTF-8 Decode/Encode --- }

{ Decode one UTF-8 character starting at position Pos in S.
  Returns codepoint and advance count.  On invalid sequence,
  CodePoint = $FFFD (replacement char) and Advance = 1 (skip byte). }
Function  DecodeUTF8Char(Const S: String; Pos: Integer): TUTF8DecodeResult;

{ Count the number of Unicode codepoints in a UTF-8 string. }
Function  UTF8Len(Const S: String): Integer;

{ Encode a single UCS-4 codepoint to a UTF-8 string (1-4 bytes). }
Function  EncodeUTF8Char(CodePoint: LongWord): String;

{ --- CP437 ↔ Unicode Mapping --- }

{ Map a CP437 byte (0-255) to its Unicode codepoint. }
Function  CP437ToUnicode(B: Byte): LongWord;

{ Map a Unicode codepoint back to CP437 byte.
  Returns the CP437 equivalent, or FallbackChar if no mapping exists.
  Default fallback is $3F ('?'). }
Function  UnicodeToCP437(CodePoint: LongWord; FallbackChar: Byte = $3F): Byte;

{ --- UTF-8-aware text iteration helper --- }

{ Walk a string by codepoints, calling a callback for each.
  If UTF8Mode is True, decodes UTF-8 sequences.
  If UTF8Mode is False, treats each byte as a CP437 value (identity). }
Type
  TCodePointCallback = Procedure(CodePoint: LongWord; Index: Integer);

Procedure ForEachCodePoint(Const S: String; UTF8Mode: Boolean;
                           Callback: TCodePointCallback);

{ --- Convenience --- }

{ Convert entire UTF-8 string to a sequence of CP437 bytes.
  Codepoints with no CP437 equivalent become FallbackChar. }
Function  UTF8ToCP437(Const S: String; FallbackChar: Byte = $3F): String;

{ Convert CP437 byte string to UTF-8. }
Function  CP437ToUTF8(Const S: String): String;

Implementation

{ ========================================================================
  CP437 → Unicode mapping table
  Positions 0x00-0x7F: control codes and ASCII
  Positions 0x80-0xFF: the extended CP437 set
  Source: Unicode.org CP437 mapping (ftp://ftp.unicode.org/Public/MAPPINGS/
  VENDORS/MSDOS/CP437.TXT)
  ======================================================================== }

Const
  { CP437 bytes 0x00-0x1F — these are the special graphical characters
    that CP437 displays instead of control codes (smileys, card suits,
    arrows, musical notes, etc.) }
  CP437_Low: Array[0..31] of LongWord = (
    $0000, { 00 NUL — null }
    $263A, { 01 ☺ }
    $263B, { 02 ☻ }
    $2665, { 03 ♥ }
    $2666, { 04 ♦ }
    $2663, { 05 ♣ }
    $2660, { 06 ♠ }
    $2022, { 07 • }
    $25D8, { 08 ◘ }
    $25CB, { 09 ○ }
    $25D9, { 0A ◙ }
    $2642, { 0B ♂ }
    $2640, { 0C ♀ }
    $266A, { 0D ♪ }
    $266B, { 0E ♫ }
    $263C, { 0F ☼ }
    $25BA, { 10 ► }
    $25C4, { 11 ◄ }
    $2195, { 12 ↕ }
    $203C, { 13 ‼ }
    $00B6, { 14 ¶ }
    $00A7, { 15 § }
    $25AC, { 16 ▬ }
    $21A8, { 17 ↨ }
    $2191, { 18 ↑ }
    $2193, { 19 ↓ }
    $2192, { 1A → }
    $2190, { 1B ← }
    $221F, { 1C ∟ }
    $2194, { 1D ↔ }
    $25B2, { 1E ▲ }
    $25BC  { 1F ▼ }
  );

  { CP437 bytes 0x7F-0xFF — DEL + extended set }
  CP437_High: Array[0..128] of LongWord = (
    $2302, { 7F ⌂ — house }
    $00C7, { 80 Ç }
    $00FC, { 81 ü }
    $00E9, { 82 é }
    $00E2, { 83 â }
    $00E4, { 84 ä }
    $00E0, { 85 à }
    $00E5, { 86 å }
    $00E7, { 87 ç }
    $00EA, { 88 ê }
    $00EB, { 89 ë }
    $00E8, { 8A è }
    $00EF, { 8B ï }
    $00EE, { 8C î }
    $00EC, { 8D ì }
    $00C4, { 8E Ä }
    $00C5, { 8F Å }
    $00C9, { 90 É }
    $00E6, { 91 æ }
    $00C6, { 92 Æ }
    $00F4, { 93 ô }
    $00F6, { 94 ö }
    $00F2, { 95 ò }
    $00FB, { 96 û }
    $00F9, { 97 ù }
    $00FF, { 98 ÿ }
    $00D6, { 99 Ö }
    $00DC, { 9A Ü }
    $00A2, { 9B ¢ }
    $00A3, { 9C £ }
    $00A5, { 9D ¥ }
    $20A7, { 9E ₧ }
    $0192, { 9F ƒ }
    $00E1, { A0 á }
    $00ED, { A1 í }
    $00F3, { A2 ó }
    $00FA, { A3 ú }
    $00F1, { A4 ñ }
    $00D1, { A5 Ñ }
    $00AA, { A6 ª }
    $00BA, { A7 º }
    $00BF, { A8 ¿ }
    $2310, { A9 ⌐ }
    $00AC, { AA ¬ }
    $00BD, { AB ½ }
    $00BC, { AC ¼ }
    $00A1, { AD ¡ }
    $00AB, { AE « }
    $00BB, { AF » }
    $2591, { B0 ░ }
    $2592, { B1 ▒ }
    $2593, { B2 ▓ }
    $2502, { B3 │ }
    $2524, { B4 ┤ }
    $2561, { B5 ╡ }
    $2562, { B6 ╢ }
    $2556, { B7 ╖ }
    $2555, { B8 ╕ }
    $2563, { B9 ╣ }
    $2551, { BA ║ }
    $2557, { BB ╗ }
    $255D, { BC ╝ }
    $255C, { BD ╜ }
    $255B, { BE ╛ }
    $2510, { BF ┐ }
    $2514, { C0 └ }
    $2534, { C1 ┴ }
    $252C, { C2 ┬ }
    $251C, { C3 ├ }
    $2500, { C4 ─ }
    $253C, { C5 ┼ }
    $255E, { C6 ╞ }
    $255F, { C7 ╟ }
    $255A, { C8 ╚ }
    $2554, { C9 ╔ }
    $2569, { CA ╩ }
    $2566, { CB ╦ }
    $2560, { CC ╠ }
    $2550, { CD ═ }
    $256C, { CE ╬ }
    $2567, { CF ╧ }
    $2568, { D0 ╨ }
    $2564, { D1 ╤ }
    $2565, { D2 ╥ }
    $2559, { D3 ╙ }
    $2558, { D4 ╘ }
    $2552, { D5 ╒ }
    $2553, { D6 ╓ }
    $256B, { D7 ╫ }
    $256A, { D8 ╪ }
    $2518, { D9 ┘ }
    $250C, { DA ┌ }
    $2588, { DB █ }
    $2584, { DC ▄ }
    $258C, { DD ▌ }
    $2590, { DE ▐ }
    $2580, { DF ▀ }
    $03B1, { E0 α }
    $00DF, { E1 ß }
    $0393, { E2 Γ }
    $03C0, { E3 π }
    $03A3, { E4 Σ }
    $03C3, { E5 σ }
    $00B5, { E6 µ }
    $03C4, { E7 τ }
    $03A6, { E8 Φ }
    $0398, { E9 Θ }
    $03A9, { EA Ω }
    $03B4, { EB δ }
    $221E, { EC ∞ }
    $03C6, { ED φ }
    $03B5, { EE ε }
    $2229, { EF ∩ }
    $2261, { F0 ≡ }
    $00B1, { F1 ± }
    $2265, { F2 ≥ }
    $2264, { F3 ≤ }
    $2320, { F4 ⌠ }
    $2321, { F5 ⌡ }
    $00F7, { F6 ÷ }
    $2248, { F7 ≈ }
    $00B0, { F8 ° }
    $2219, { F9 ∙ }
    $00B7, { FA · }
    $221A, { FB √ }
    $207F, { FC ⁿ }
    $00B2, { FD ² }
    $25A0, { FE ■ }
    $00A0  { FF   (non-breaking space) }
  );

{ ========================================================================
  UTF-8 Decode
  ======================================================================== }

Function DecodeUTF8Char(Const S: String; Pos: Integer): TUTF8DecodeResult;
Var
  B     : Byte;
  CP    : LongWord;
  Expect: Integer;
  I     : Integer;
  Cont  : Byte;
Begin
  Result.CodePoint := $FFFD;
  Result.Advance   := 1;

  If (Pos < 1) Or (Pos > Length(S)) Then Exit;

  B := Ord(S[Pos]);

  { Single byte — ASCII }
  If B < $80 Then
  Begin
    Result.CodePoint := B;
    Result.Advance   := 1;
    Exit;
  End;

  { Determine sequence length from lead byte }
  If (B And $E0) = $C0 Then
  Begin
    CP     := B And $1F;
    Expect := 2;
  End
  Else If (B And $F0) = $E0 Then
  Begin
    CP     := B And $0F;
    Expect := 3;
  End
  Else If (B And $F8) = $F0 Then
  Begin
    CP     := B And $07;
    Expect := 4;
  End
  Else
    Exit; { invalid lead byte — return replacement, advance 1 }

  { Check we have enough bytes }
  If Pos + Expect - 1 > Length(S) Then Exit;

  { Read continuation bytes }
  For I := 1 To Expect - 1 Do
  Begin
    Cont := Ord(S[Pos + I]);
    If (Cont And $C0) <> $80 Then Exit; { invalid continuation }
    CP := (CP Shl 6) Or (Cont And $3F);
  End;

  { Reject overlong encodings }
  If (Expect = 2) And (CP < $80) Then Exit;
  If (Expect = 3) And (CP < $800) Then Exit;
  If (Expect = 4) And (CP < $10000) Then Exit;

  { Reject surrogates and out-of-range }
  If (CP >= $D800) And (CP <= $DFFF) Then Exit;
  If CP > $10FFFF Then Exit;

  Result.CodePoint := CP;
  Result.Advance   := Expect;
End;

{ ========================================================================
  UTF-8 Length (codepoint count)
  ======================================================================== }

Function UTF8Len(Const S: String): Integer;
Var
  Pos : Integer;
  DR  : TUTF8DecodeResult;
Begin
  Result := 0;
  Pos := 1;
  While Pos <= Length(S) Do
  Begin
    DR := DecodeUTF8Char(S, Pos);
    Inc(Pos, DR.Advance);
    Inc(Result);
  End;
End;

{ ========================================================================
  UTF-8 Encode
  ======================================================================== }

Function EncodeUTF8Char(CodePoint: LongWord): String;
Begin
  If CodePoint < $80 Then
    Result := Chr(CodePoint)
  Else If CodePoint < $800 Then
    Result := Chr($C0 Or (CodePoint Shr 6)) +
              Chr($80 Or (CodePoint And $3F))
  Else If CodePoint < $10000 Then
    Result := Chr($E0 Or (CodePoint Shr 12)) +
              Chr($80 Or ((CodePoint Shr 6) And $3F)) +
              Chr($80 Or (CodePoint And $3F))
  Else If CodePoint <= $10FFFF Then
    Result := Chr($F0 Or (CodePoint Shr 18)) +
              Chr($80 Or ((CodePoint Shr 12) And $3F)) +
              Chr($80 Or ((CodePoint Shr 6) And $3F)) +
              Chr($80 Or (CodePoint And $3F))
  Else
    Result := Chr($EF) + Chr($BF) + Chr($BD); { U+FFFD replacement }
End;

{ ========================================================================
  CP437 → Unicode
  ======================================================================== }

Function CP437ToUnicode(B: Byte): LongWord;
Begin
  If B < $20 Then
    Result := CP437_Low[B]
  Else If B < $7F Then
    Result := B                    { ASCII range — identity }
  Else
    Result := CP437_High[B - $7F]; { 7F-FF → table }
End;

{ ========================================================================
  Unicode → CP437 (reverse lookup)
  Uses a simple linear scan of both tables.  256 entries total —
  plenty fast for per-character use.
  ======================================================================== }

Function UnicodeToCP437(CodePoint: LongWord; FallbackChar: Byte): Byte;
Var
  I: Integer;
Begin
  { Fast path: ASCII printable range is identity }
  If (CodePoint >= $20) And (CodePoint < $7F) Then
  Begin
    Result := Byte(CodePoint);
    Exit;
  End;

  { Search low table (0x00-0x1F) }
  For I := 0 To 31 Do
    If CP437_Low[I] = CodePoint Then
    Begin
      Result := I;
      Exit;
    End;

  { Search high table (0x7F-0xFF) }
  For I := 0 To 128 Do
    If CP437_High[I] = CodePoint Then
    Begin
      Result := I + $7F;
      Exit;
    End;

  Result := FallbackChar;
End;

{ ========================================================================
  ForEachCodePoint — iterate by codepoints or bytes
  ======================================================================== }

Procedure ForEachCodePoint(Const S: String; UTF8Mode: Boolean;
                           Callback: TCodePointCallback);
Var
  Pos, Idx : Integer;
  DR       : TUTF8DecodeResult;
Begin
  Pos := 1;
  Idx := 0;
  If UTF8Mode Then
  Begin
    While Pos <= Length(S) Do
    Begin
      DR := DecodeUTF8Char(S, Pos);
      Callback(DR.CodePoint, Idx);
      Inc(Pos, DR.Advance);
      Inc(Idx);
    End;
  End
  Else
  Begin
    While Pos <= Length(S) Do
    Begin
      Callback(Ord(S[Pos]), Idx);
      Inc(Pos);
      Inc(Idx);
    End;
  End;
End;

{ ========================================================================
  UTF8ToCP437 — bulk convert
  ======================================================================== }

Function UTF8ToCP437(Const S: String; FallbackChar: Byte): String;
Var
  Pos : Integer;
  DR  : TUTF8DecodeResult;
Begin
  Result := '';
  Pos := 1;
  While Pos <= Length(S) Do
  Begin
    DR := DecodeUTF8Char(S, Pos);
    Result := Result + Chr(UnicodeToCP437(DR.CodePoint, FallbackChar));
    Inc(Pos, DR.Advance);
  End;
End;

{ ========================================================================
  CP437ToUTF8 — bulk convert
  ======================================================================== }

Function CP437ToUTF8(Const S: String): String;
Var
  I : Integer;
Begin
  Result := '';
  For I := 1 To Length(S) Do
    Result := Result + EncodeUTF8Char(CP437ToUnicode(Ord(S[I])));
End;

End.
