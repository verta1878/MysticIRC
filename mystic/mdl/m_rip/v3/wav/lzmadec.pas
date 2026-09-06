{ This file is part of FPC 2.6.4irc.
  Copyright (C) 2026 fpc264irc contributors.

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <https://www.gnu.org/licenses/>.
}
{ Pure Pascal LZMA1/LZMA2 Decoder
  Based on LZMA SDK specification (Igor Pavlov, public domain)
  No C dependencies, no $L linking, compiles on all FPC targets.

  Usage:
    var InBuf, OutBuf: PByte;
        InSize, OutSize: Cardinal;
        Props: array[0..4] of Byte;  // LZMA properties header
    begin
      LzmaDecode(InBuf, InSize, OutBuf, OutSize, @Props[0]);
    end;
}
unit lzmadec;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  ELzmaError = class(Exception);

  TLzmaRes = (
    lrOK,
    lrDataError,
    lrInputEOF,
    lrOutputEOF,
    lrFinished
  );

{ Decode LZMA1 stream }
function LzmaDecode(
  InBuf: PByte; InSize: Cardinal;
  OutBuf: PByte; var OutSize: Cardinal;
  Props: PByte  // 5 bytes: lc/lp/pb + 4-byte dictSize (little-endian)
): TLzmaRes;

{ Decode LZMA2 stream }
function Lzma2Decode(
  InBuf: PByte; InSize: Cardinal;
  OutBuf: PByte; var OutSize: Cardinal
): TLzmaRes;

implementation

const
  kNumBitModelTotalBits = 11;
  kBitModelTotal = 1 shl kNumBitModelTotalBits;  // 2048
  kNumMoveBits = 5;

  kNumPosBitsMax = 4;
  kNumPosStatesMax = 1 shl kNumPosBitsMax;  // 16

  kLenNumLowBits = 3;
  kLenNumLowSymbols = 1 shl kLenNumLowBits;   // 8
  kLenNumMidBits = 3;
  kLenNumMidSymbols = 1 shl kLenNumMidBits;   // 8
  kLenNumHighBits = 8;
  kLenNumHighSymbols = 1 shl kLenNumHighBits;  // 256

  kNumLenProbs = kLenNumLowSymbols * kNumPosStatesMax +
                 kLenNumMidSymbols * kNumPosStatesMax +
                 kLenNumHighSymbols + 2;

  kNumStates = 12;
  kNumLitStates = 7;

  kStartPosModelIndex = 4;
  kEndPosModelIndex = 14;
  kNumFullDistances = 1 shl (kEndPosModelIndex shr 1);  // 128

  kNumAlignBits = 4;
  kAlignTableSize = 1 shl kNumAlignBits;  // 16

  kMatchMinLen = 2;
  kMatchSpecLenStart = kMatchMinLen + kLenNumLowSymbols +
                       kLenNumMidSymbols + kLenNumHighSymbols;  // 274

type
  TProb = Word;  // probability value 0..2047
  TProbArray = array of TProb;

  TRangeDecoder = record
    Range: Cardinal;
    Code: Cardinal;
    InBuf: PByte;
    InPos: Cardinal;
    InSize: Cardinal;
  end;

procedure RangeDecInit(var rd: TRangeDecoder);
var
  i: Integer;
begin
  rd.Range := $FFFFFFFF;
  rd.Code := 0;
  for i := 0 to 4 do
  begin
    if rd.InPos < rd.InSize then
    begin
      rd.Code := (rd.Code shl 8) or rd.InBuf[rd.InPos];
      Inc(rd.InPos);
    end;
  end;
end;

function RangeDecBit(var rd: TRangeDecoder; var prob: TProb): Integer;
var
  bound: Cardinal;
begin
  bound := (rd.Range shr kNumBitModelTotalBits) * prob;
  if rd.Code < bound then
  begin
    rd.Range := bound;
    prob := prob + ((kBitModelTotal - prob) shr kNumMoveBits);
    if rd.Range < $01000000 then
    begin
      rd.Range := rd.Range shl 8;
      if rd.InPos < rd.InSize then
      begin
        rd.Code := (rd.Code shl 8) or rd.InBuf[rd.InPos];
        Inc(rd.InPos);
      end
      else
        rd.Code := rd.Code shl 8;
    end;
    Result := 0;
  end
  else
  begin
    rd.Range := rd.Range - bound;
    rd.Code := rd.Code - bound;
    prob := prob - (prob shr kNumMoveBits);
    if rd.Range < $01000000 then
    begin
      rd.Range := rd.Range shl 8;
      if rd.InPos < rd.InSize then
      begin
        rd.Code := (rd.Code shl 8) or rd.InBuf[rd.InPos];
        Inc(rd.InPos);
      end
      else
        rd.Code := rd.Code shl 8;
    end;
    Result := 1;
  end;
end;

function RangeDecDirectBits(var rd: TRangeDecoder; NumBits: Integer): Cardinal;
var
  i: Integer;
begin
  Result := 0;
  for i := NumBits - 1 downto 0 do
  begin
    rd.Range := rd.Range shr 1;
    rd.Code := rd.Code - rd.Range;
    // t = 0 if Code was >= Range (bit=1), else t = -1 (bit=0)
    Result := Result shl 1;
    if (rd.Code and $80000000) = 0 then
      Result := Result or 1
    else
      rd.Code := rd.Code + rd.Range;
    if rd.Range < $01000000 then
    begin
      rd.Range := rd.Range shl 8;
      if rd.InPos < rd.InSize then
      begin
        rd.Code := (rd.Code shl 8) or rd.InBuf[rd.InPos];
        Inc(rd.InPos);
      end
      else
        rd.Code := rd.Code shl 8;
    end;
  end;
end;

function RangeDecBitTree(var rd: TRangeDecoder; probs: PWord;
  NumBits: Integer): Cardinal;
var
  i: Integer;
  m: Cardinal;
begin
  m := 1;
  for i := 0 to NumBits - 1 do
    m := (m shl 1) or Cardinal(RangeDecBit(rd, probs[m]));
  Result := m - (Cardinal(1) shl NumBits);
end;

function RangeDecBitTreeReverse(var rd: TRangeDecoder; probs: PWord;
  NumBits: Integer): Cardinal;
var
  i: Integer;
  m, bit: Cardinal;
begin
  Result := 0;
  m := 1;
  for i := 0 to NumBits - 1 do
  begin
    bit := Cardinal(RangeDecBit(rd, probs[m]));
    m := (m shl 1) or bit;
    Result := Result or (bit shl Cardinal(i));
  end;
end;

procedure LenDecode(var rd: TRangeDecoder; probs: PWord;
  posState: Cardinal; out len: Cardinal);
var
  offset: Integer;
begin
  if RangeDecBit(rd, probs[0]) = 0 then
  begin
    len := RangeDecBitTree(rd,
      @probs[2 + posState * kLenNumLowSymbols * 2],
      kLenNumLowBits);
    Exit;
  end;
  if RangeDecBit(rd, probs[1]) = 0 then
  begin
    offset := 2 + kNumPosStatesMax * kLenNumLowSymbols * 2;
    len := kLenNumLowSymbols + RangeDecBitTree(rd,
      @probs[offset + posState * kLenNumMidSymbols * 2],
      kLenNumMidBits);
    Exit;
  end;
  offset := 2 + kNumPosStatesMax * kLenNumLowSymbols * 2 +
            kNumPosStatesMax * kLenNumMidSymbols * 2;
  len := kLenNumLowSymbols + kLenNumMidSymbols +
         RangeDecBitTree(rd, @probs[offset], kLenNumHighBits);
end;

function LzmaDecode(
  InBuf: PByte; InSize: Cardinal;
  OutBuf: PByte; var OutSize: Cardinal;
  Props: PByte
): TLzmaRes;
var
  rd: TRangeDecoder;
  probs: TProbArray;
  lc, lp, pb: Integer;
  dictSizeInProps, dictSize: Cardinal;
  numProbs: Integer;
  state: Integer;
  rep0, rep1, rep2, rep3: Cardinal;
  outPos, outLimit: Cardinal;
  posState: Cardinal;
  probIdx: Integer;
  litProbs, posSlotProbs, alignProbs: Integer;
  lenProbs, repLenProbs: Integer;
  isMatchProbs, isRepProbs, isRepG0Probs, isRepG1Probs, isRepG2Probs: Integer;
  isRep0LongProbs: Integer;
  posDecoders: Integer;
  d, propByte: Byte;
  matchByte, litState: Cardinal;
  symbol, bit, prevByte: Cardinal;
  len, dist, posSlot, numDirectBits: Cardinal;
  i: Integer;
  temp: Cardinal;
begin
  Result := lrDataError;

  // Parse 5-byte properties header
  propByte := Props[0];
  if propByte >= (9 * 5 * 5) then Exit;

  lc := propByte mod 9;
  propByte := propByte div 9;
  pb := propByte div 5;
  lp := propByte mod 5;

  dictSizeInProps := Props[1] or (Cardinal(Props[2]) shl 8) or
                     (Cardinal(Props[3]) shl 16) or (Cardinal(Props[4]) shl 24);
  if dictSizeInProps < 4096 then
    dictSize := 4096
  else
    dictSize := dictSizeInProps;

  // Allocate probability array
  litProbs := 0;
  numProbs := (Cardinal(768) shl (lc + lp));

  isMatchProbs := numProbs;       Inc(numProbs, kNumStates shl kNumPosBitsMax);
  isRepProbs := numProbs;          Inc(numProbs, kNumStates);
  isRepG0Probs := numProbs;        Inc(numProbs, kNumStates);
  isRepG1Probs := numProbs;        Inc(numProbs, kNumStates);
  isRepG2Probs := numProbs;        Inc(numProbs, kNumStates);
  isRep0LongProbs := numProbs;     Inc(numProbs, kNumStates shl kNumPosBitsMax);
  lenProbs := numProbs;            Inc(numProbs, kNumLenProbs);
  repLenProbs := numProbs;         Inc(numProbs, kNumLenProbs);
  posSlotProbs := numProbs;        Inc(numProbs, 4 * (1 shl 6)); // 4 groups * 64
  posDecoders := numProbs;         Inc(numProbs, kNumFullDistances - kStartPosModelIndex);
  alignProbs := numProbs;          Inc(numProbs, kAlignTableSize);

  SetLength(probs, numProbs);
  for i := 0 to numProbs - 1 do
    probs[i] := kBitModelTotal shr 1;  // 1024

  // Initialize range decoder
  rd.InBuf := InBuf;
  rd.InPos := 0;
  rd.InSize := InSize;
  RangeDecInit(rd);

  // Initialize state
  state := 0;
  rep0 := 0; rep1 := 0; rep2 := 0; rep3 := 0;
  outPos := 0;
  outLimit := OutSize;

  // Main decode loop
  while outPos < outLimit do
  begin
    posState := outPos and ((1 shl pb) - 1);

    if RangeDecBit(rd, probs[isMatchProbs + (state shl kNumPosBitsMax) + posState]) = 0 then
    begin
      // Literal
      if outPos > 0 then
        prevByte := OutBuf[outPos - 1]
      else
        prevByte := 0;

      litState := ((outPos and ((1 shl lp) - 1)) shl lc) +
                  (prevByte shr (8 - lc));

      probIdx := litProbs + Integer(litState) * 768; // was 0x300
      symbol := 1;

      if state >= kNumLitStates then
      begin
        // Match literal
        if rep0 < outPos then
          matchByte := OutBuf[outPos - rep0 - 1]
        else
          matchByte := 0;
        repeat
          matchByte := matchByte shl 1;
          bit := (matchByte and $100) shr 8;
          i := RangeDecBit(rd, probs[probIdx + Cardinal($100) + (bit shl 8) + symbol]);
          symbol := (symbol shl 1) or Cardinal(i);
          if bit <> Cardinal(i) then Break;
        until symbol >= $100;
      end;

      while symbol < $100 do
        symbol := (symbol shl 1) or Cardinal(RangeDecBit(rd, probs[probIdx + symbol]));

      OutBuf[outPos] := Byte(symbol and $FF);
      Inc(outPos);

      if state < 4 then state := 0
      else if state < 10 then Dec(state, 3)
      else Dec(state, 6);
    end
    else
    begin
      // Match or rep
      if RangeDecBit(rd, probs[isRepProbs + state]) = 0 then
      begin
        // Simple match
        temp := rep3; rep3 := rep2; rep2 := rep1; rep1 := rep0;

        LenDecode(rd, @probs[lenProbs], posState, len);
        Inc(len, kMatchMinLen);

        if state < kNumLitStates then state := kNumLitStates
        else state := kNumLitStates + 3;

        // Decode distance
        if len - kMatchMinLen < 4 then
          posSlot := RangeDecBitTree(rd,
            @probs[posSlotProbs + (len - kMatchMinLen) * (1 shl 6) * 2],
            6)
        else
          posSlot := RangeDecBitTree(rd,
            @probs[posSlotProbs + 3 * (1 shl 6) * 2],
            6);

        if posSlot < kStartPosModelIndex then
          rep0 := posSlot
        else
        begin
          numDirectBits := (posSlot shr 1) - 1;
          rep0 := (2 or (posSlot and 1)) shl numDirectBits;

          if posSlot < kEndPosModelIndex then
          begin
            rep0 := rep0 + RangeDecBitTreeReverse(rd,
              @probs[posDecoders + rep0 - posSlot - 1],
              numDirectBits);
          end
          else
          begin
            rep0 := rep0 + (RangeDecDirectBits(rd, numDirectBits - kNumAlignBits) shl kNumAlignBits);
            rep0 := rep0 + RangeDecBitTreeReverse(rd,
              @probs[alignProbs], kNumAlignBits);
          end;
        end;

        if rep0 = $FFFFFFFF then
        begin
          // End marker
          OutSize := outPos;
          Result := lrFinished;
          Exit;
        end;

        if rep0 >= outPos then
        begin
          Result := lrDataError;
          Exit;
        end;
      end
      else
      begin
        // Rep match
        if RangeDecBit(rd, probs[isRepG0Probs + state]) = 0 then
        begin
          // rep0
          if RangeDecBit(rd, probs[isRep0LongProbs + (state shl kNumPosBitsMax) + posState]) = 0 then
          begin
            // ShortRep
            if rep0 >= outPos then
            begin
              Result := lrDataError;
              Exit;
            end;
            OutBuf[outPos] := OutBuf[outPos - rep0 - 1];
            Inc(outPos);
            if state < kNumLitStates then state := 9 else state := 11;
            Continue;
          end;
        end
        else
        begin
          if RangeDecBit(rd, probs[isRepG1Probs + state]) = 0 then
          begin
            temp := rep1;
            rep1 := rep0;
            rep0 := temp;
          end
          else
          begin
            if RangeDecBit(rd, probs[isRepG2Probs + state]) = 0 then
            begin
              temp := rep2;
              rep2 := rep1;
              rep1 := rep0;
              rep0 := temp;
            end
            else
            begin
              temp := rep3;
              rep3 := rep2;
              rep2 := rep1;
              rep1 := rep0;
              rep0 := temp;
            end;
          end;
        end;

        LenDecode(rd, @probs[repLenProbs], posState, len);
        Inc(len, kMatchMinLen);

        if state < kNumLitStates then state := 8 else state := 11;
      end;

      // Copy match
      if rep0 >= outPos then
      begin
        Result := lrDataError;
        Exit;
      end;

      for i := 0 to Integer(len) - 1 do
      begin
        if outPos >= outLimit then
        begin
          OutSize := outPos;
          Result := lrOutputEOF;
          Exit;
        end;
        OutBuf[outPos] := OutBuf[outPos - rep0 - 1];
        Inc(outPos);
      end;
    end;
  end;

  OutSize := outPos;
  Result := lrOK;
end;

function Lzma2Decode(
  InBuf: PByte; InSize: Cardinal;
  OutBuf: PByte; var OutSize: Cardinal
): TLzmaRes;
var
  inPos, outPos, outLimit: Cardinal;
  control, dictBits: Byte;
  unpackSize, packSize: Cardinal;
  chunkOut: Cardinal;
  props: array[0..4] of Byte;
  needProps, needDict: Boolean;
begin
  inPos := 0;
  outPos := 0;
  outLimit := OutSize;
  needProps := True;
  needDict := True;

  while inPos < InSize do
  begin
    if inPos >= InSize then
    begin
      Result := lrInputEOF;
      OutSize := outPos;
      Exit;
    end;

    control := InBuf[inPos];
    Inc(inPos);

    if control = 0 then
    begin
      // End marker
      OutSize := outPos;
      Result := lrFinished;
      Exit;
    end;

    if control = 1 then
    begin
      // Dictionary reset + uncompressed
      needDict := True;
    end;

    if control < $80 then
    begin
      // Uncompressed chunk
      if (control = 1) or (control = 2) then
      begin
        if inPos + 2 > InSize then
        begin
          Result := lrInputEOF;
          OutSize := outPos;
          Exit;
        end;
        unpackSize := (Cardinal(InBuf[inPos]) shl 8) or InBuf[inPos + 1] + 1;
        Inc(inPos, 2);
        if inPos + unpackSize > InSize then
        begin
          Result := lrInputEOF;
          OutSize := outPos;
          Exit;
        end;
        if outPos + unpackSize > outLimit then
        begin
          Result := lrOutputEOF;
          OutSize := outPos;
          Exit;
        end;
        Move(InBuf[inPos], OutBuf[outPos], unpackSize);
        Inc(inPos, unpackSize);
        Inc(outPos, unpackSize);
      end;
      Continue;
    end;

    // LZMA chunk
    if (control and $40) <> 0 then
      needProps := True;

    if needProps then
    begin
      if inPos >= InSize then
      begin
        Result := lrInputEOF;
        OutSize := outPos;
        Exit;
      end;
      props[0] := InBuf[inPos];
      Inc(inPos);
      needProps := False;
    end;

    if inPos + 4 > InSize then
    begin
      Result := lrInputEOF;
      OutSize := outPos;
      Exit;
    end;

    unpackSize := ((Cardinal(control) and $1F) shl 16) or
                  (Cardinal(InBuf[inPos]) shl 8) or InBuf[inPos + 1] + 1;
    Inc(inPos, 2);
    packSize := (Cardinal(InBuf[inPos]) shl 8) or InBuf[inPos + 1] + 1;
    Inc(inPos, 2);

    if inPos + packSize > InSize then
    begin
      Result := lrInputEOF;
      OutSize := outPos;
      Exit;
    end;

    // Set dict size in props (use remaining output buffer size)
    props[1] := Byte(outLimit);
    props[2] := Byte(outLimit shr 8);
    props[3] := Byte(outLimit shr 16);
    props[4] := Byte(outLimit shr 24);

    chunkOut := unpackSize;
    if outPos + chunkOut > outLimit then
      chunkOut := outLimit - outPos;

    Result := LzmaDecode(@InBuf[inPos], packSize,
                         @OutBuf[outPos], chunkOut, @props[0]);

    if not (Result in [lrOK, lrFinished]) then
    begin
      OutSize := outPos;
      Exit;
    end;

    Inc(inPos, packSize);
    Inc(outPos, chunkOut);
    needDict := False;
  end;

  OutSize := outPos;
  Result := lrOK;
end;

end.
