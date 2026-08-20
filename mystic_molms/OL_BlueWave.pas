{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Pending licence — with permission from Peter Rocca.
  =========================================================================== }

unit OL_BlueWave;
{ ===========================================================================
  OpenOLMS — BlueWave offline mail packet format
  ---------------------------------------------------------------------------
  BlueWave 2.x — the "deluxe" offline mail format, more capable than
  QWK. Uses fixed-size binary records rather than QWK's text-in-blocks
  approach. Supports longer fields, proper threading, and richer
  reader setup information.

  A .BW packet (ZIP archive) contains:
    *.INF  — door information (area list, reader setup)
    *.MIX  — message index (one record per message)
    *.FTI  — full text index (byte offset + length in .DAT)
    *.DAT  — message bodies (concatenated text)

  A .UPL upload packet contains:
    *.UPL  — uploaded message headers
    *.UPI  — upload info (door settings for the reader)
    *.NET  — net addresses for netmail
    *.REQ  — file requests

  Reference: BlueWave Offline Mail specification v3, by George Hatchew
  (Cutting Edge Computing), 1993-1996.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

const
  { BlueWave record sizes }
  BW_INF_HEADER_SIZE  = 188;
  BW_INF_AREA_SIZE    = 96;
  BW_MIX_RECORD_SIZE  = 14;
  BW_FTI_RECORD_SIZE  = 186;
  BW_UPL_RECORD_SIZE  = 512;

type
  { BlueWave .INF header — door information }
  TBWInfoHeader = packed record
    Ver         : array[0..5] of Char;     { "2" + version info }
    BBSName     : array[0..41] of Char;
    SysopName   : array[0..41] of Char;
    LoginName   : array[0..41] of Char;    { user logged in as }
    Defunct1    : array[0..41] of Char;
    DoorName   : array[0..12] of Char;
    CityState  : array[0..29] of Char;
    Phone      : array[0..25] of Char;
    NumAreas   : Word;
    _Pad        : array[0..7] of Byte;
  end;

  { BlueWave .INF area record }
  TBWInfoArea = packed record
    AreaNum    : Word;
    AreaTag    : array[0..20] of Char;     { echotag }
    AreaTitle  : array[0..49] of Char;     { display name }
    AreaType   : Byte;                      { 0=local, 1=echo, 2=netmail, 3=internet }
    Flags      : Byte;                      { active, personal, etc }
    MaxMsgs    : Word;
    _Pad       : array[0..17] of Byte;
  end;

  { BlueWave .MIX index record }
  TBWMixRecord = packed record
    AreaNum    : Word;
    TotalMsgs  : Word;
    PersonalMsgs: Word;
    FTIOffset  : LongInt;                   { byte offset into .FTI }
    _Pad       : array[0..1] of Byte;
  end;

  { BlueWave .FTI full-text index record }
  TBWFtiRecord = packed record
    MsgNum     : LongInt;
    MsgFrom    : array[0..35] of Char;
    MsgTo      : array[0..35] of Char;
    Subject    : array[0..71] of Char;
    DateTime   : array[0..19] of Char;
    ReplyTo    : LongInt;
    Flags      : Word;
    Offset     : LongInt;                   { byte offset into .DAT }
    Length     : LongInt;                   { message body length in .DAT }
    _Pad       : array[0..3] of Byte;
  end;

  { BlueWave .UPL upload record }
  TBWUplRecord = packed record
    MsgFrom    : array[0..35] of Char;
    MsgTo      : array[0..35] of Char;
    Subject    : array[0..71] of Char;
    DateTime   : array[0..19] of Char;
    ReplyTo    : LongInt;
    AreaTag    : array[0..20] of Char;
    Flags      : Word;
    Filename   : array[0..12] of Char;     { attached file if any }
    _Pad       : array[0..299] of Byte;    { pad to 512 bytes }
  end;

{ Convert a string to a fixed-width BlueWave text field (null-padded) }
procedure BWStrToField(const S: String; var Field; Size: Integer);

{ Extract trimmed string from a BlueWave field (null-terminated) }
function BWFieldToStr(const Field; Size: Integer): String;

{ Write a BlueWave .INF file (header + area records) }
procedure BWWriteINF(const Filename: String;
  const Header: TBWInfoHeader;
  const Areas: array of TBWInfoArea;
  AreaCount: Integer);

{ Read a BlueWave .UPL upload file }
function BWReadUPL(const Filename: String;
  var Uploads: array of TBWUplRecord): Integer;

implementation

uses SysUtils;

procedure BWStrToField(const S: String; var Field; Size: Integer);
var
  P: PChar;
  I, Len: Integer;
begin
  P := @Field;
  FillChar(P^, Size, 0);
  Len := Length(S);
  if Len >= Size then Len := Size - 1;  { leave room for null }
  for I := 1 to Len do
    P[I - 1] := S[I];
end;

function BWFieldToStr(const Field; Size: Integer): String;
var
  P: PChar;
  I: Integer;
begin
  P := @Field;
  Result := '';
  for I := 0 to Size - 1 do
  begin
    if P[I] = #0 then Break;
    Result := Result + P[I];
  end;
  Result := TrimRight(Result);
end;

procedure BWWriteINF(const Filename: String;
  const Header: TBWInfoHeader;
  const Areas: array of TBWInfoArea;
  AreaCount: Integer);
var
  F: File;
  I: Integer;
begin
  AssignFile(F, Filename);
  {$I-} Rewrite(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  try
    BlockWrite(F, Header, SizeOf(Header));
    for I := 0 to AreaCount - 1 do
      BlockWrite(F, Areas[I], SizeOf(TBWInfoArea));
  finally
    CloseFile(F);
  end;
end;

function BWReadUPL(const Filename: String;
  var Uploads: array of TBWUplRecord): Integer;
var
  F: File;
  BytesRead: LongInt;
begin
  Result := 0;
  if not FileExists(Filename) then Exit;

  AssignFile(F, Filename);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;

  try
    while (not EOF(F)) and (Result <= High(Uploads)) do
    begin
      FillChar(Uploads[Result], SizeOf(TBWUplRecord), 0);
      BlockRead(F, Uploads[Result], BW_UPL_RECORD_SIZE, BytesRead);
      if BytesRead <> BW_UPL_RECORD_SIZE then Break;
      Inc(Result);
    end;
  finally
    CloseFile(F);
  end;
end;

end.
