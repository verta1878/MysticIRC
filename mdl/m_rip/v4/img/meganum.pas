(* meganum.pas -- RIPscript MegaNum Base-36 Encoder/Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   MegaNum is the base-36 number encoding used by RIPscript
   for coordinates, colors, and parameters. Digits 0-9, A-Z.
   2 digits = 0-1295, 4 digits = 0-1679615.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit meganum;

interface

{ Encode integer to MegaNum string (fixed-width, zero-padded) }
function MegaNumEncode(Value: LongInt; Digits: Integer): ShortString;

{ Decode MegaNum string to integer }
function MegaNumDecode(const S: ShortString): LongInt;

{ Decode N digits from buffer at position }
function MegaNumDecodeAt(Buf: PChar; Pos, Digits: Integer): LongInt;

{ Encode integer and write to buffer at position }
procedure MegaNumEncodeAt(Buf: PChar; Pos: Integer;
  Value: LongInt; Digits: Integer);

{ Max value for N digits }
function MegaNumMax(Digits: Integer): LongInt;

{ Validate: are all chars valid MegaNum digits? }
function MegaNumValid(const S: ShortString): Boolean;

implementation

const
  MegaChars: ShortString = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

function CharToVal(C: Char): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'A'..'Z': Result := Ord(C) - Ord('A') + 10;
    'a'..'z': Result := Ord(C) - Ord('a') + 10;
  else
    Result := -1;
  end;
end;

function MegaNumEncode(Value: LongInt; Digits: Integer): ShortString;
var
  I: Integer;
begin
  if Digits < 1 then Digits := 1;
  if Digits > 8 then Digits := 8;
  if Value < 0 then Value := 0;

  SetLength(Result, Digits);
  for I := Digits downto 1 do
  begin
    Result[I] := MegaChars[(Value mod 36) + 1];
    Value := Value div 36;
  end;
end;

function MegaNumDecode(const S: ShortString): LongInt;
var
  I, V: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) do
  begin
    V := CharToVal(S[I]);
    if V < 0 then Exit;
    Result := Result * 36 + V;
  end;
end;

function MegaNumDecodeAt(Buf: PChar; Pos, Digits: Integer): LongInt;
var
  I, V: Integer;
begin
  Result := 0;
  for I := 0 to Digits - 1 do
  begin
    V := CharToVal(Buf[Pos + I]);
    if V < 0 then Exit;
    Result := Result * 36 + V;
  end;
end;

procedure MegaNumEncodeAt(Buf: PChar; Pos: Integer;
  Value: LongInt; Digits: Integer);
var
  I: Integer;
begin
  if Value < 0 then Value := 0;
  for I := Digits - 1 downto 0 do
  begin
    Buf[Pos + I] := MegaChars[(Value mod 36) + 1];
    Value := Value div 36;
  end;
end;

function MegaNumMax(Digits: Integer): LongInt;
var
  I: Integer;
begin
  Result := 1;
  for I := 1 to Digits do
    Result := Result * 36;
  Dec(Result);
end;

function MegaNumValid(const S: ShortString): Boolean;
var
  I: Integer;
begin
  Result := Length(S) > 0;
  for I := 1 to Length(S) do
    if CharToVal(S[I]) < 0 then
    begin
      Result := False;
      Exit;
    end;
end;

end.
