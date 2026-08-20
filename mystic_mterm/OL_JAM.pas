{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Pending licence — with permission from Peter Rocca.
  =========================================================================== }

unit OL_JAM;
{ ===========================================================================
  OpenOLMS — JAM message base reader
  ---------------------------------------------------------------------------
  JAM (Joaquim-Andrew-Mats) message base format, 1993. Used by many
  FidoNet-capable BBS packages. Four files per area:

    .JHR  — fixed-size header records (TJAMHeader)
    .JDT  — message body text (variable-length, offset from header)
    .JDX  — index records (CRC32 of recipient + offset into .JHR)
    .JLR  — last-read pointers per user

  Each header is 76 bytes. The body is stored at a byte offset in
  .JDT with a length from the header. Subfields follow the header
  in .JHR — variable-length tagged data (from, to, subject, msgid,
  reply, origin, etc).

  Reference: JAM specification by Joaquim Homrighausen,
  Andrew Milner, Mats Birch, Mats Wallin — 1993.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

const
  JAM_SIGNATURE = 'JAM'#0;
  JAM_HDR_SIZE  = 76;

  { JAM attribute bits }
  JAM_LOCAL    = $00000001;
  JAM_INTRANS  = $00000002;
  JAM_PRIVATE  = $00000004;
  JAM_READ     = $00000008;
  JAM_SENT     = $00000010;
  JAM_KILLSENT = $00000020;
  JAM_HOLD     = $00000080;
  JAM_DELETED  = $80000000;

  { JAM subfield types }
  JAMSFLD_OADDRESS    = 0;
  JAMSFLD_DADDRESS    = 1;
  JAMSFLD_SENDERNAME  = 2;
  JAMSFLD_RECVRNAME   = 3;
  JAMSFLD_MSGID       = 4;
  JAMSFLD_REPLYID     = 5;
  JAMSFLD_SUBJECT     = 6;
  JAMSFLD_PID         = 7;
  JAMSFLD_TRACE       = 8;
  JAMSFLD_ENCLFILE    = 9;
  JAMSFLD_ENCLFREQ    = 10;
  JAMSFLD_ENCLOSEDFILE= 11;
  JAMSFLD_ENCLOSEDFRE = 12;
  JAMSFLD_FTSKLUDGE   = 2000;

type
  { JAM fixed header — 76 bytes }
  TJAMHeader = packed record
    Signature   : array[0..3] of Char;   {  4 — 'JAM\0' }
    Revision    : Word;                   {  2 — spec revision }
    ReservedWord: Word;                   {  2 }
    SubfieldLen : LongInt;                {  4 — total bytes of subfields }
    TimesRead   : LongInt;                {  4 }
    MSGIDcrc    : LongInt;                {  4 — CRC-32 of MSGID }
    REPLYcrc    : LongInt;                {  4 — CRC-32 of REPLY }
    ReplyTo     : LongInt;                {  4 — msg number of parent }
    Reply1st    : LongInt;                {  4 — first reply }
    ReplyNext   : LongInt;                {  4 — next reply in chain }
    DateWritten : LongInt;                {  4 — Unix timestamp }
    DateReceived: LongInt;                {  4 }
    DateProcessed: LongInt;               {  4 }
    MsgNum      : LongInt;                {  4 }
    Attr        : LongInt;                {  4 — attribute bits }
    Attr2       : LongInt;                {  4 }
    TxtOffset   : LongInt;                {  4 — offset into .JDT }
    TxtLen      : LongInt;                {  4 — length in .JDT }
    PasswordCRC : LongInt;                {  4 }
    Cost        : LongInt;                {  4 }
  end;                                    { = 76 bytes }

  { JAM subfield header — variable length }
  TJAMSubfield = packed record
    LoID    : Word;       { subfield type }
    HiID    : Word;       { unused (0) }
    DataLen : LongInt;    { length of data following this header }
  end;

  { JAM index record }
  TJAMIndex = packed record
    UserCRC : LongInt;    { CRC-32 of lowercase recipient name }
    HdrOfs  : LongInt;    { byte offset into .JHR }
  end;

  { JAM last-read record }
  TJAMLast = packed record
    UserCRC  : LongInt;   { CRC-32 of lowercase user name }
    UserID   : LongInt;   { user number (BBS-specific) }
    LastRead : LongInt;   { last message number read }
    HighRead : LongInt;   { highest message number read }
  end;

  { Parsed JAM message for OpenOLMS use }
  TJAMMessage = record
    MsgNum    : LongInt;
    MsgTo     : String;
    MsgFrom   : String;
    Subject   : String;
    DateStr   : String;
    Body      : String;
    IsPrivate : Boolean;
    IsDeleted : Boolean;
    ReplyTo   : LongInt;
    Attr      : LongInt;
  end;

{ Read messages from a JAM area.
  BaseName is the path+name without extension (e.g. 'C:\MSG\GENERAL').
  Returns count of messages read into the Messages array. }
function JAMReadArea(const BaseName: String;
  StartMsg: LongInt; MaxMsgs: Integer;
  var Messages: array of TJAMMessage): Integer;

{ Read a single message by number }
function JAMReadMessage(const BaseName: String; MsgNum: LongInt;
  var Msg: TJAMMessage): Boolean;

{ Get the last-read pointer for a user }
function JAMGetLastRead(const BaseName: String;
  const UserName: String): LongInt;

{ Set the last-read pointer for a user }
procedure JAMSetLastRead(const BaseName: String;
  const UserName: String; LastRead: LongInt);

{ CRC-32 of a lowercase string (used for user matching in JAM) }
function JAMCRC32(const S: String): LongInt;

implementation

uses SysUtils;

function JAMUnixToDateTime(UnixTime: LongInt): TDateTime;
const UNIX_EPOCH: TDateTime = 25569.0;
begin Result := UNIX_EPOCH + (UnixTime / 86400.0); end;

const
  CRC32_POLY = LongInt($EDB88320);

var
  CRC32_TABLE: array[0..255] of LongInt;
  CRC32_INIT: Boolean = False;

procedure InitCRC32Table;
var I, J: Integer; CRC: LongInt;
begin
  for I := 0 to 255 do
  begin
    CRC := I;
    for J := 0 to 7 do
      if (CRC and 1) <> 0 then CRC := (CRC shr 1) xor CRC32_POLY
      else CRC := CRC shr 1;
    CRC32_TABLE[I] := CRC;
  end;
  CRC32_INIT := True;
end;


function JAMCRC32(const S: String): LongInt;
var
  I: Integer;
  CRC: LongInt;
  C: Byte;
begin
  if not CRC32_INIT then InitCRC32Table;
  CRC := LongInt($FFFFFFFF);
  for I := 1 to Length(S) do
  begin
    C := Ord(LowerCase(S[I]));
    CRC := CRC32_TABLE[Byte(CRC) xor C] xor (CRC shr 8);
  end;
  Result := CRC xor LongInt($FFFFFFFF);
end;

function JAMReadMessage(const BaseName: String; MsgNum: LongInt;
  var Msg: TJAMMessage): Boolean;
var
  FHdr, FDat: File;
  Hdr: TJAMHeader;
  Sub: TJAMSubfield;
  SubData: String;
  BytesRead: LongInt;
  SubBytesLeft: LongInt;
  Buf: array[0..4095] of Byte;
begin
  Result := False;

  { Open .JHR }
  AssignFile(FHdr, BaseName + '.JHR');
  {$I-} Reset(FHdr, 1); {$I+}
  if IOResult <> 0 then Exit;

  try
    { Scan for the message number }
    while not EOF(FHdr) do
    begin
      FillChar(Hdr, SizeOf(Hdr), 0);
      BlockRead(FHdr, Hdr, JAM_HDR_SIZE, BytesRead);
      if BytesRead <> JAM_HDR_SIZE then Break;

      { Read subfields even if not our message (to advance file pos) }
      SubBytesLeft := Hdr.SubfieldLen;
      Msg.MsgFrom := '';
      Msg.MsgTo := '';
      Msg.Subject := '';

      while SubBytesLeft > SizeOf(TJAMSubfield) do
      begin
        BlockRead(FHdr, Sub, SizeOf(TJAMSubfield), BytesRead);
        if BytesRead <> SizeOf(TJAMSubfield) then Break;
        Dec(SubBytesLeft, SizeOf(TJAMSubfield));

        if Sub.DataLen > 0 then
        begin
          if Sub.DataLen > 4096 then
          begin
            Seek(FHdr, FilePos(FHdr) + Sub.DataLen);
            Dec(SubBytesLeft, Sub.DataLen);
            Continue;
          end;
          FillChar(Buf, SizeOf(Buf), 0);
          BlockRead(FHdr, Buf, Sub.DataLen);
          Dec(SubBytesLeft, Sub.DataLen);
          SetLength(SubData, Sub.DataLen);
          Move(Buf[0], SubData[1], Sub.DataLen);
        end else
          SubData := '';

        if Hdr.MsgNum = MsgNum then
        begin
          case Sub.LoID of
            JAMSFLD_SENDERNAME: Msg.MsgFrom := SubData;
            JAMSFLD_RECVRNAME: Msg.MsgTo := SubData;
            JAMSFLD_SUBJECT:   Msg.Subject := SubData;
          end;
        end;
      end;

      if Hdr.MsgNum = MsgNum then
      begin
        Msg.MsgNum    := Hdr.MsgNum;
        Msg.IsPrivate := (Hdr.Attr and JAM_PRIVATE) <> 0;
        Msg.IsDeleted := (Hdr.Attr and JAM_DELETED) <> 0;
        Msg.ReplyTo   := Hdr.ReplyTo;
        Msg.Attr      := Hdr.Attr;
        Msg.DateStr   := FormatDateTime('mm-dd-yy',
          JAMUnixToDateTime(Hdr.DateWritten));

        { Read body from .JDT }
        Msg.Body := '';
        if (Hdr.TxtLen > 0) and FileExists(BaseName + '.JDT') then
        begin
          AssignFile(FDat, BaseName + '.JDT');
          {$I-} Reset(FDat, 1); {$I+}
          if IOResult = 0 then
          try
            Seek(FDat, Hdr.TxtOffset);
            SetLength(Msg.Body, Hdr.TxtLen);
            BlockRead(FDat, Msg.Body[1], Hdr.TxtLen);
          finally
            CloseFile(FDat);
          end;
        end;

        Result := True;
        Exit;
      end;
    end;
  finally
    CloseFile(FHdr);
  end;
end;

function JAMReadArea(const BaseName: String;
  StartMsg: LongInt; MaxMsgs: Integer;
  var Messages: array of TJAMMessage): Integer;
var
  FHdr: File;
  Hdr: TJAMHeader;
  BytesRead: LongInt;
  Count: Integer;
begin
  Result := 0;
  Count := 0;

  AssignFile(FHdr, BaseName + '.JHR');
  {$I-} Reset(FHdr, 1); {$I+}
  if IOResult <> 0 then Exit;

  try
    while not EOF(FHdr) do
    begin
      FillChar(Hdr, SizeOf(Hdr), 0);
      BlockRead(FHdr, Hdr, JAM_HDR_SIZE, BytesRead);
      if BytesRead <> JAM_HDR_SIZE then Break;

      { Skip subfields — we read them fully in JAMReadMessage }
      if Hdr.SubfieldLen > 0 then
        Seek(FHdr, FilePos(FHdr) + Hdr.SubfieldLen);

      { Filter }
      if (Hdr.Attr and JAM_DELETED) <> 0 then Continue;
      if Hdr.MsgNum < StartMsg then Continue;
      if Count > High(Messages) then Break;
      if (MaxMsgs > 0) and (Count >= MaxMsgs) then Break;

      { Lightweight record — body is read lazily during packing }
      Messages[Count].MsgNum    := Hdr.MsgNum;
      Messages[Count].IsPrivate := (Hdr.Attr and JAM_PRIVATE) <> 0;
      Messages[Count].IsDeleted := False;
      Messages[Count].ReplyTo   := Hdr.ReplyTo;
      Messages[Count].Attr      := Hdr.Attr;
      Messages[Count].DateStr   := FormatDateTime('mm-dd-yy',
        JAMUnixToDateTime(Hdr.DateWritten));
      Messages[Count].Body      := '';
      Messages[Count].MsgFrom   := '';
      Messages[Count].MsgTo     := '';
      Messages[Count].Subject   := '';

      Inc(Count);
    end;
  finally
    CloseFile(FHdr);
  end;
  Result := Count;
end;

function JAMGetLastRead(const BaseName: String;
  const UserName: String): LongInt;
var
  F: File;
  LR: TJAMLast;
  UserCRC: LongInt;
  BytesRead: LongInt;
begin
  Result := 0;
  UserCRC := JAMCRC32(UserName);

  AssignFile(F, BaseName + '.JLR');
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;

  try
    while not EOF(F) do
    begin
      BlockRead(F, LR, SizeOf(LR), BytesRead);
      if BytesRead <> SizeOf(LR) then Break;
      if LR.UserCRC = UserCRC then
      begin
        Result := LR.LastRead;
        Exit;
      end;
    end;
  finally
    CloseFile(F);
  end;
end;

procedure JAMSetLastRead(const BaseName: String;
  const UserName: String; LastRead: LongInt);
var
  F: File;
  LR: TJAMLast;
  UserCRC: LongInt;
  BytesRead: LongInt;
  Found: Boolean;
begin
  UserCRC := JAMCRC32(UserName);
  Found := False;

  AssignFile(F, BaseName + '.JLR');
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then
  begin
    {$I-} Rewrite(F, 1); {$I+}
    if IOResult <> 0 then Exit;
  end;

  try
    while not EOF(F) do
    begin
      BlockRead(F, LR, SizeOf(LR), BytesRead);
      if BytesRead <> SizeOf(LR) then Break;
      if LR.UserCRC = UserCRC then
      begin
        LR.LastRead := LastRead;
        if LastRead > LR.HighRead then
          LR.HighRead := LastRead;
        Seek(F, FilePos(F) - SizeOf(LR));
        BlockWrite(F, LR, SizeOf(LR));
        Found := True;
        Break;
      end;
    end;

    if not Found then
    begin
      { Append new record }
      LR.UserCRC  := UserCRC;
      LR.UserID   := 0;
      LR.LastRead := LastRead;
      LR.HighRead := LastRead;
      Seek(F, FileSize(F));
      BlockWrite(F, LR, SizeOf(LR));
    end;
  finally
    CloseFile(F);
  end;
end;

end.
