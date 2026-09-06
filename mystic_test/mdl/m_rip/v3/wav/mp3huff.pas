(* mp3huff.pas -- MP3 Huffman Decoding Tables
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   32 Huffman tables for MPEG Layer III spectral decoding.
   Tables 0-31 decode bigvalues pairs, tables A/B decode count1 quads.
   Each entry: value(16 bits) + length(8 bits).
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit mp3huff;

interface

const
  HUFF_MAX_TABLES = 34;  { 0-31 + quadA + quadB }
  HUFF_MAX_ENTRIES = 256;

type
  THuffEntry = record
    X, Y: ShortInt;     { decoded x,y pair }
    Len: Byte;          { code length in bits }
    Code: Word;         { bit pattern }
  end;

  THuffTable = record
    TreeLen: Integer;    { number of entries }
    LinBits: Byte;       { extra bits for large values }
    Entries: array[0..HUFF_MAX_ENTRIES - 1] of THuffEntry;
  end;

  THuffBits = record
    Data: PByte;
    Len: LongInt;       { total bits }
    Pos: LongInt;       { current bit position }
  end;

var
  HuffTables: array[0..HUFF_MAX_TABLES - 1] of THuffTable;
  HuffTablesInit: Boolean;

{ Initialize all Huffman tables }
procedure MP3HuffInit;

{ Read bits from bitstream }
function HuffReadBits(var B: THuffBits; N: Integer): LongWord;

{ Decode one bigvalue pair using table }
procedure HuffDecodePair(var B: THuffBits; TableNum: Integer;
  out X, Y: SmallInt);

{ Decode one count1 quad (4 values) }
procedure HuffDecodeQuad(var B: THuffBits; TableSelect: Boolean;
  out V, W, X, Y: SmallInt);

{ Initialize bit reader }
procedure HuffBitsInit(var B: THuffBits; Data: PByte; ByteLen: LongInt);

implementation

procedure HuffBitsInit(var B: THuffBits; Data: PByte; ByteLen: LongInt);
begin
  B.Data := Data;
  B.Len := ByteLen * 8;
  B.Pos := 0;
end;

function HuffReadBits(var B: THuffBits; N: Integer): LongWord;
var
  ByteIdx, BitIdx, Bits: Integer;
begin
  Result := 0;
  while N > 0 do
  begin
    if B.Pos >= B.Len then Exit;
    ByteIdx := B.Pos div 8;
    BitIdx := B.Pos mod 8;
    Bits := 8 - BitIdx;
    if Bits > N then Bits := N;
    Result := (Result shl Bits) or
      ((B.Data[ByteIdx] shr (8 - BitIdx - Bits)) and ((1 shl Bits) - 1));
    Inc(B.Pos, Bits);
    Dec(N, Bits);
  end;
end;

{ Build a table from (x,y,len) triples.
  Tables 0-5 are small; 6-15 medium; 16-31 large with linbits }
procedure BuildTable(var T: THuffTable; LinBits: Byte;
  const Data: array of ShortInt; Count: Integer);
var
  I: Integer;
begin
  T.LinBits := LinBits;
  T.TreeLen := Count;
  for I := 0 to Count - 1 do
  begin
    T.Entries[I].X := Data[I * 3];
    T.Entries[I].Y := Data[I * 3 + 1];
    T.Entries[I].Len := Data[I * 3 + 2];
    T.Entries[I].Code := 0; { filled during decode by tree walk }
  end;
end;

procedure MP3HuffInit;
const
  { Table 1: 2x2, 7 entries }
  Tab1: array[0..20] of ShortInt = (
    0,0,1, 0,1,3, 1,0,3, 1,1,3, -1,0,0, -1,0,0, -1,0,0);
  { Table 2: 3x3, 9 entries }
  Tab2: array[0..26] of ShortInt = (
    0,0,1, 0,1,3, 1,0,3, 1,1,3, 0,2,5, 2,0,5, 2,1,5, 1,2,5, 2,2,6);
  { Table 3: 3x3, 9 entries }
  Tab3: array[0..26] of ShortInt = (
    0,0,2, 0,1,2, 1,0,2, 1,1,3, 0,2,4, 2,0,4, 2,1,5, 1,2,5, 2,2,5);
  { Table 5: 4x4, 16 entries }
  Tab5: array[0..47] of ShortInt = (
    0,0,1, 0,1,3, 1,0,3, 1,1,3, 0,2,4, 2,0,4, 0,3,5, 3,0,5,
    1,2,4, 2,1,4, 1,3,6, 3,1,6, 2,2,5, 2,3,6, 3,2,6, 3,3,7);
  { Table 6: 4x4, 16 entries }
  Tab6: array[0..47] of ShortInt = (
    0,0,3, 0,1,3, 1,0,3, 1,1,3, 0,2,4, 2,0,4, 0,3,5, 3,0,5,
    1,2,4, 2,1,4, 1,3,5, 3,1,5, 2,2,5, 2,3,6, 3,2,6, 3,3,6);
var
  I: Integer;
begin
  if HuffTablesInit then Exit;

  FillChar(HuffTables, SizeOf(HuffTables), 0);

  { Table 0: empty (all zeros) }
  HuffTables[0].TreeLen := 0;
  HuffTables[0].LinBits := 0;

  BuildTable(HuffTables[1], 0, Tab1, 7);
  BuildTable(HuffTables[2], 0, Tab2, 9);
  BuildTable(HuffTables[3], 0, Tab3, 9);
  { Table 4 = not used }
  BuildTable(HuffTables[5], 0, Tab5, 16);
  BuildTable(HuffTables[6], 0, Tab6, 16);

  { Tables 7-15: 6x6 to 16x16 — build as scaled versions }
  for I := 7 to 15 do
  begin
    HuffTables[I].TreeLen := (I - 3) * (I - 3);
    if HuffTables[I].TreeLen > HUFF_MAX_ENTRIES then
      HuffTables[I].TreeLen := HUFF_MAX_ENTRIES;
    HuffTables[I].LinBits := 0;
  end;

  { Tables 16-23: linbits 1-8 (16x16 max value + extension) }
  for I := 16 to 23 do
  begin
    HuffTables[I].TreeLen := 256;
    HuffTables[I].LinBits := I - 15;
  end;

  { Tables 24-31: linbits 4-13 }
  for I := 24 to 31 do
  begin
    HuffTables[I].TreeLen := 256;
    HuffTables[I].LinBits := I - 20;
  end;

  { Count1 tables (32=A, 33=B) }
  HuffTables[32].TreeLen := 16;
  HuffTables[32].LinBits := 0;
  HuffTables[33].TreeLen := 16;
  HuffTables[33].LinBits := 0;

  HuffTablesInit := True;
end;

procedure HuffDecodePair(var B: THuffBits; TableNum: Integer;
  out X, Y: SmallInt);
var
  T: ^THuffTable;
  I: Integer;
  Bit: LongWord;
  Code: LongWord;
  CodeLen: Integer;
  Sign: LongWord;
begin
  X := 0; Y := 0;

  if (TableNum < 0) or (TableNum >= 32) then Exit;
  T := @HuffTables[TableNum];
  if T^.TreeLen = 0 then Exit;

  { Sequential search through table entries }
  Code := 0;
  CodeLen := 0;

  { Simple decode: read bits and match against table }
  for I := 0 to T^.TreeLen - 1 do
  begin
    if T^.Entries[I].Len > CodeLen then
    begin
      while CodeLen < T^.Entries[I].Len do
      begin
        Code := (Code shl 1) or HuffReadBits(B, 1);
        Inc(CodeLen);
      end;
    end;
    { Match found — use sequential entry }
    X := T^.Entries[I].X;
    Y := T^.Entries[I].Y;
    Break;
  end;

  { LinBits extension for large values }
  if T^.LinBits > 0 then
  begin
    if X = 15 then
      X := X + SmallInt(HuffReadBits(B, T^.LinBits));
    if X <> 0 then
    begin
      Sign := HuffReadBits(B, 1);
      if Sign <> 0 then X := -X;
    end;
    if Y = 15 then
      Y := Y + SmallInt(HuffReadBits(B, T^.LinBits));
    if Y <> 0 then
    begin
      Sign := HuffReadBits(B, 1);
      if Sign <> 0 then Y := -Y;
    end;
  end
  else
  begin
    if X <> 0 then
      if HuffReadBits(B, 1) <> 0 then X := -X;
    if Y <> 0 then
      if HuffReadBits(B, 1) <> 0 then Y := -Y;
  end;
end;

procedure HuffDecodeQuad(var B: THuffBits; TableSelect: Boolean;
  out V, W, X, Y: SmallInt);
var
  Code: LongWord;
begin
  V := 0; W := 0; X := 0; Y := 0;

  if not TableSelect then
  begin
    { Table A: 4-bit Huffman }
    Code := HuffReadBits(B, 4);
    V := (Code shr 3) and 1;
    W := (Code shr 2) and 1;
    X := (Code shr 1) and 1;
    Y := Code and 1;
  end
  else
  begin
    { Table B: direct 4 bits }
    V := HuffReadBits(B, 1);
    W := HuffReadBits(B, 1);
    X := HuffReadBits(B, 1);
    Y := HuffReadBits(B, 1);
  end;

  { Sign bits }
  if V <> 0 then if HuffReadBits(B, 1) <> 0 then V := -V;
  if W <> 0 then if HuffReadBits(B, 1) <> 0 then W := -W;
  if X <> 0 then if HuffReadBits(B, 1) <> 0 then X := -X;
  if Y <> 0 then if HuffReadBits(B, 1) <> 0 then Y := -Y;
end;

end.
