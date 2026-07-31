{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Clean-room reimplementation from published QWK specification.

  Pending licence — with permission from Peter Rocca.
  =========================================================================== }

unit OL_QWK;
{ ===========================================================================
  OpenOLMS — QWK packet format (clean-room from published spec)
  ---------------------------------------------------------------------------
  QWK is the offline mail packet format. A .QWK file is a ZIP archive
  containing:
    CONTROL.DAT    — conference list and BBS info (text)
    MESSAGES.DAT   — all messages in a fixed 128-byte block format
    *.NDX           — per-conference index (conference number = filename)
    NEWFILES.DAT   — new files list (optional)
    DOOR.ID        — door identification (optional)
    TOREADER.EXT   — commands to the offline reader (optional)

  A .REP file is the reply upload — same ZIP, containing:
    <BBSID>.MSG    — reply messages in the same 128-byte block format
    HEADERS.DAT    — extended headers (QWKE only)

  The 128-byte block format matches the PCBoard message index format.
  Block 1 of each message is the header. Remaining blocks are the body
  with lines separated by $E3 (the QWK line terminator, not CR/LF).

  Reference: QWK specification by Patrick Y. Lee, 1992.
  Reference: QWKE extensions by Peter Rocca (OLMS author), 1996.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

const
  { QWK uses 128-byte blocks, same as PCBoard message index }
  QWK_BLOCK_SIZE = 128;

  { QWK line terminator — replaces CR/LF in message body }
  QWK_NEWLINE = #$E3;

  { Message status flags (byte 1 of the header block) }
  QWK_STATUS_PUBLIC        = ' ';   { public, unread }
  QWK_STATUS_PUBLIC_READ   = '-';   { public, read }
  QWK_STATUS_PRIVATE       = '*';   { private, unread }
  QWK_STATUS_PRIVATE_READ  = '+';   { private, read }
  QWK_STATUS_COMMENT       = '~';   { comment to sysop }
  QWK_STATUS_SENDER_ONLY   = '`';   { sender has read }
  QWK_STATUS_VOTER          = '%';   { voter response }

type
  { QWK message header — first 128-byte block of each message.
    All text fields are space-padded, NOT null-terminated.
    Numeric fields are stored as ASCII text, space-padded.
    HAZARD: the spec says "ASCII number, right-justified,
    space-padded" but many doors left-justify. Parse both.

    This record must be EXACTLY 128 bytes. The compiler must not
    add any padding. }
  TQWKHeader = packed record
    Status    : Char;              {   1 byte  — message status }
    MsgNum    : array[1..7] of Char;  {   7 bytes — message number (ASCII) }
    DateTime  : array[1..13] of Char; {  13 bytes — MM-DD-YYHH:MM (no space, no seconds) }
    MsgTo     : array[1..25] of Char; {  25 bytes — recipient name }
    MsgFrom   : array[1..25] of Char; {  25 bytes — sender name }
    Subject   : array[1..25] of Char; {  25 bytes — message subject }
    Password  : array[1..12] of Char; {  12 bytes — message password (rarely used) }
    RefNum    : array[1..8] of Char;  {   8 bytes — reference message number (thread) }
    NumBlocks : array[1..6] of Char;  {   6 bytes — total blocks including header (ASCII) }
    Alive     : Char;              {   1 byte  — $E1 = live, $E2 = deleted }
    ConfNum   : Word;              {   2 bytes — conference number (binary LE) }
    _Unused   : Word;              {   2 bytes — not used / QWKE seq number }
    NetTag    : Char;              {   1 byte  — '*' if net-tagged }
  end;                             { = 128 bytes total }

  { CONTROL.DAT — the BBS descriptor in the QWK packet.
    This is a text file, one field per line. We parse it into
    a record for easy access. }
  TQWKConference = record
    Number : Integer;
    Name   : String;
  end;

  TQWKControl = record
    BBSName      : String;     { line 1: BBS name }
    BBSCity      : String;     { line 2: BBS city/location }
    BBSPhone     : String;     { line 3: BBS phone number }
    SysopName    : String;     { line 4: sysop name }
    DoorRegNum   : String;     { line 5: door registration # ("0" = unregistered) }
    PackDate     : String;     { line 6: pack date MM-DD-YYYY }
    PackTime     : String;     { line 7: pack time HH:MM:SS }
    UserName     : String;     { line 8: user who packed this }
    _Unused1     : String;     { line 9: unused }
    _Unused2     : String;     { line 10: unused }
    NumConfs     : Integer;    { line 11: number of conferences - 1 }
    Conferences  : array of TQWKConference;
  end;

  { NDX index record — one per message in each conference.
    Each record is 5 bytes. First 4 bytes = IEEE single-precision
    float containing the block offset of the message in MESSAGES.DAT.
    Fifth byte = conference number (redundant, for validation).
    HAZARD: the float encoding is the native Turbo Pascal Single
    type — NOT the same as IEEE 754 on all platforms. FPC's Single
    type is compatible. }
  TQWKNdxEntry = packed record
    BlockOffset : Single;   { 4 bytes — 1-based block number in MESSAGES.DAT }
    ConfNum     : Byte;     { 1 byte — conference number (low byte only) }
  end;

{ --- Parsing --- }

{ Parse a QWK header from a 128-byte buffer }
function QWKParseHeader(const Buf: array of Byte): TQWKHeader;

{ Extract the trimmed string from a fixed-width QWK text field }
function QWKFieldToStr(const Field; Size: Integer): String;

{ Parse the number-of-blocks field (ASCII, may be space-padded) }
function QWKBlockCount(const H: TQWKHeader): Integer;

{ Parse the message number field }
function QWKMsgNumber(const H: TQWKHeader): LongInt;

{ Parse the reference number field (for threading) }
function QWKRefNumber(const H: TQWKHeader): LongInt;

{ Read the message body from MESSAGES.DAT given block offset and count.
  Converts QWK_NEWLINE ($E3) to standard line endings. }
function QWKReadBody(var F: File; BlockOffset, BlockCount: Integer): String;

{ --- Packing --- }

{ Write a QWK header block to a 128-byte buffer }
procedure QWKWriteHeader(const H: TQWKHeader; var Buf: array of Byte);

{ Convert a string to a fixed-width QWK text field (space-padded) }
procedure QWKStrToField(const S: String; var Field; Size: Integer);

{ Write CONTROL.DAT to a text file }
procedure QWKWriteControl(var F: Text; const Ctrl: TQWKControl);

{ Write an NDX entry }
procedure QWKWriteNdx(var F: File; BlockOffset: LongInt; ConfNum: Byte);

implementation

uses SysUtils;

function QWKFieldToStr(const Field; Size: Integer): String;
var
  P: PChar;
  I: Integer;
begin
  SetLength(Result, Size);
  P := @Field;
  for I := 1 to Size do
    Result[I] := P[I - 1];
  Result := TrimRight(Result);
end;

function QWKBlockCount(const H: TQWKHeader): Integer;
begin
  Result := StrToIntDef(Trim(QWKFieldToStr(H.NumBlocks, 6)), 1);
end;

function QWKMsgNumber(const H: TQWKHeader): LongInt;
begin
  Result := StrToIntDef(Trim(QWKFieldToStr(H.MsgNum, 7)), 0);
end;

function QWKRefNumber(const H: TQWKHeader): LongInt;
begin
  Result := StrToIntDef(Trim(QWKFieldToStr(H.RefNum, 8)), 0);
end;

function QWKParseHeader(const Buf: array of Byte): TQWKHeader;
begin
  { HAZARD: Buf must be at least 128 bytes. The caller is responsible
    for reading the right amount from MESSAGES.DAT. }
  Move(Buf[0], Result, SizeOf(TQWKHeader));
end;

function QWKReadBody(var F: File; BlockOffset, BlockCount: Integer): String;
var
  Buf: array[0..QWK_BLOCK_SIZE - 1] of Byte;
  I, J, BodyBlocks: Integer;
  Ch: Char;
begin
  Result := '';
  BodyBlocks := BlockCount - 1;   { first block is the header }
  if BodyBlocks <= 0 then Exit;

  Seek(F, (BlockOffset) * QWK_BLOCK_SIZE);  { skip header block }
  for I := 0 to BodyBlocks - 1 do
  begin
    BlockRead(F, Buf, QWK_BLOCK_SIZE);
    for J := 0 to QWK_BLOCK_SIZE - 1 do
    begin
      Ch := Char(Buf[J]);
      if Ch = QWK_NEWLINE then
        Result := Result + LineEnding
      else if Ch <> #0 then
        Result := Result + Ch;
    end;
  end;
end;

procedure QWKWriteHeader(const H: TQWKHeader; var Buf: array of Byte);
begin
  FillChar(Buf[0], QWK_BLOCK_SIZE, ' ');
  Move(H, Buf[0], SizeOf(TQWKHeader));
end;

procedure QWKStrToField(const S: String; var Field; Size: Integer);
var
  P: PChar;
  I, Len: Integer;
begin
  P := @Field;
  FillChar(P^, Size, ' ');
  Len := Length(S);
  if Len > Size then Len := Size;
  for I := 1 to Len do
    P[I - 1] := S[I];
end;

procedure QWKWriteControl(var F: Text; const Ctrl: TQWKControl);
var I: Integer;
begin
  WriteLn(F, Ctrl.BBSName);
  WriteLn(F, Ctrl.BBSCity);
  WriteLn(F, Ctrl.BBSPhone);
  WriteLn(F, Ctrl.SysopName);
  WriteLn(F, Ctrl.DoorRegNum);
  WriteLn(F, Ctrl.PackDate);
  WriteLn(F, Ctrl.PackTime);
  WriteLn(F, Ctrl.UserName);
  WriteLn(F);    { line 9: unused }
  WriteLn(F);    { line 10: unused }
  WriteLn(F, Ctrl.NumConfs);
  for I := 0 to High(Ctrl.Conferences) do
  begin
    WriteLn(F, Ctrl.Conferences[I].Number);
    WriteLn(F, Ctrl.Conferences[I].Name);
  end;
end;

procedure QWKWriteNdx(var F: File; BlockOffset: LongInt; ConfNum: Byte);
var Entry: TQWKNdxEntry;
begin
  Entry.BlockOffset := Single(BlockOffset);
  Entry.ConfNum := ConfNum;
  BlockWrite(F, Entry, SizeOf(Entry));
end;

end.
