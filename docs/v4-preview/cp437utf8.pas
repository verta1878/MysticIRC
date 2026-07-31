(* cp437utf8.pas -- CP437 to UTF-8 Translation Table
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Complete 256-codepoint mapping from IBM PC Code Page 437
   to Unicode/UTF-8. Used by BBS terminals, ANSI art viewers,
   and the RIPscript renderer for modern terminal output.

   Usage:
     var UTF8: ShortString;
     begin
       UTF8 := CP437ToUTF8(#219);  // full block → U+2588
       UTF8 := CP437ToUTF8(#176);  // light shade → U+2591
     end;
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit cp437utf8;

interface

{ Convert single CP437 byte to UTF-8 string }
function CP437ToUTF8(C: Byte): ShortString;

{ Convert CP437 buffer to UTF-8 buffer.
  OutBuf must be at least InLen * 3 bytes.
  Returns bytes written to OutBuf. }
function CP437BufToUTF8(InBuf: PByte; InLen: LongInt;
  OutBuf: PByte; OutMax: LongInt): LongInt;

{ Convert UTF-8 character back to CP437 (returns 0 if no mapping) }
function UTF8ToCP437(const S: ShortString; var Pos: Integer): Byte;

{ Encode a Unicode codepoint as UTF-8 bytes }
function UnicodeToUTF8(CodePoint: LongWord): ShortString;

{ Decode UTF-8 bytes to Unicode codepoint }
function UTF8ToUnicode(const S: ShortString; var Pos: Integer): LongWord;

const
  { CP437 to Unicode codepoint mapping (256 entries) }
  CP437Map: array[0..255] of Word = (
    { 0x00-0x1F: control chars mapped to symbols }
    $0000, $263A, $263B, $2665, $2666, $2663, $2660, $2022,
    $25D8, $25CB, $25D9, $2642, $2640, $266A, $266B, $263C,
    $25BA, $25C4, $2195, $203C, $00B6, $00A7, $25AC, $21A8,
    $2191, $2193, $2192, $2190, $221F, $2194, $25B2, $25BC,
    { 0x20-0x7E: standard ASCII }
    $0020, $0021, $0022, $0023, $0024, $0025, $0026, $0027,
    $0028, $0029, $002A, $002B, $002C, $002D, $002E, $002F,
    $0030, $0031, $0032, $0033, $0034, $0035, $0036, $0037,
    $0038, $0039, $003A, $003B, $003C, $003D, $003E, $003F,
    $0040, $0041, $0042, $0043, $0044, $0045, $0046, $0047,
    $0048, $0049, $004A, $004B, $004C, $004D, $004E, $004F,
    $0050, $0051, $0052, $0053, $0054, $0055, $0056, $0057,
    $0058, $0059, $005A, $005B, $005C, $005D, $005E, $005F,
    $0060, $0061, $0062, $0063, $0064, $0065, $0066, $0067,
    $0068, $0069, $006A, $006B, $006C, $006D, $006E, $006F,
    $0070, $0071, $0072, $0073, $0074, $0075, $0076, $0077,
    $0078, $0079, $007A, $007B, $007C, $007D, $007E, $2302,
    { 0x80-0xFF: extended characters }
    $00C7, $00FC, $00E9, $00E2, $00E4, $00E0, $00E5, $00E7,
    $00EA, $00EB, $00E8, $00EF, $00EE, $00EC, $00C4, $00C5,
    $00C9, $00E6, $00C6, $00F4, $00F6, $00F2, $00FB, $00F9,
    $00FF, $00D6, $00DC, $00A2, $00A3, $00A5, $20A7, $0192,
    $00E1, $00ED, $00F3, $00FA, $00F1, $00D1, $00AA, $00BA,
    $00BF, $2310, $00AC, $00BD, $00BC, $00A1, $00AB, $00BB,
    { 0xB0-0xBF: shading + box single }
    $2591, $2592, $2593, $2502, $2524, $2561, $2562, $2556,
    $2555, $2563, $2551, $2557, $255D, $255C, $255B, $2510,
    { 0xC0-0xCF: box drawing }
    $2514, $2534, $252C, $251C, $2500, $253C, $255E, $255F,
    $255A, $2554, $2569, $2566, $2560, $2550, $256C, $2567,
    { 0xD0-0xDF: box drawing continued }
    $2568, $2564, $2565, $2559, $2558, $2552, $2553, $256B,
    $256A, $2518, $250C, $2588, $2584, $258C, $2590, $2580,
    { 0xE0-0xEF: Greek + math }
    $03B1, $00DF, $0393, $03C0, $03A3, $03C3, $00B5, $03C4,
    $03A6, $0398, $03A9, $03B4, $221E, $03C6, $03B5, $2229,
    { 0xF0-0xFF: math + misc }
    $2261, $00B1, $2265, $2264, $2320, $2321, $00F7, $2248,
    $00B0, $2219, $00B7, $221A, $207F, $00B2, $25A0, $00A0
  );

implementation




function UnicodeToUTF8(CodePoint: LongWord): ShortString;
begin
  if CodePoint < $80 then
  begin
    SetLength(Result, 1);
    Result[1] := Chr(CodePoint);
  end
  else if CodePoint < $800 then
  begin
    SetLength(Result, 2);
    Result[1] := Chr($C0 or (CodePoint shr 6));
    Result[2] := Chr($80 or (CodePoint and $3F));
  end
  else if CodePoint < $10000 then
  begin
    SetLength(Result, 3);
    Result[1] := Chr($E0 or (CodePoint shr 12));
    Result[2] := Chr($80 or ((CodePoint shr 6) and $3F));
    Result[3] := Chr($80 or (CodePoint and $3F));
  end
  else
  begin
    SetLength(Result, 4);
    Result[1] := Chr($F0 or (CodePoint shr 18));
    Result[2] := Chr($80 or ((CodePoint shr 12) and $3F));
    Result[3] := Chr($80 or ((CodePoint shr 6) and $3F));
    Result[4] := Chr($80 or (CodePoint and $3F));
  end;
end;

function UTF8ToUnicode(const S: ShortString; var Pos: Integer): LongWord;
var
  B: Byte;
begin
  Result := 0;
  if Pos > Length(S) then Exit;
  B := Ord(S[Pos]);
  if B < $80 then
  begin
    Result := B;
    Inc(Pos);
  end
  else if (B and $E0) = $C0 then
  begin
    Result := (LongWord(B and $1F) shl 6);
    Inc(Pos);
    if Pos <= Length(S) then
      Result := Result or (Ord(S[Pos]) and $3F);
    Inc(Pos);
  end
  else if (B and $F0) = $E0 then
  begin
    Result := (LongWord(B and $0F) shl 12);
    Inc(Pos);
    if Pos <= Length(S) then
      Result := Result or (LongWord(Ord(S[Pos]) and $3F) shl 6);
    Inc(Pos);
    if Pos <= Length(S) then
      Result := Result or (Ord(S[Pos]) and $3F);
    Inc(Pos);
  end
  else
  begin
    Result := B;
    Inc(Pos);
  end;
end;

function CP437ToUTF8(C: Byte): ShortString;
begin
  Result := UnicodeToUTF8(CP437Map[C]);
end;

function CP437BufToUTF8(InBuf: PByte; InLen: LongInt;
  OutBuf: PByte; OutMax: LongInt): LongInt;
var
  I: LongInt;
  UTF: ShortString;
  J: Integer;
begin
  Result := 0;
  for I := 0 to InLen - 1 do
  begin
    UTF := CP437ToUTF8(InBuf[I]);
    for J := 1 to Length(UTF) do
    begin
      if Result >= OutMax then Exit;
      OutBuf[Result] := Ord(UTF[J]);
      Inc(Result);
    end;
  end;
end;

function UTF8ToCP437(const S: ShortString; var Pos: Integer): Byte;
var
  CP: LongWord;
  I: Integer;
begin
  Result := 0;
  CP := UTF8ToUnicode(S, Pos);
  { Reverse lookup }
  for I := 0 to 255 do
    if CP437Map[I] = CP then
    begin
      Result := I;
      Exit;
    end;
end;

end.
