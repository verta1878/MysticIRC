{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Clean-room reimplementation from published Hudson/QuickBBS specification.
  Pending licence — with permission from Peter Rocca.
  =========================================================================== }

unit OL_Hudson;
{ ===========================================================================
  OpenOLMS — Hudson message base reader
  ---------------------------------------------------------------------------
  Hudson (also called QuickBBS) message base format. Used by RemoteAccess,
  QuickBBS, SuperBBS, and many others. Defined by Adam Hudson, 1987.

  The format uses 5 files in the message base directory:

    MSGHDR.BBS    — fixed-size header records (one per message)
    MSGTXT.BBS    — message body text (variable-length records)
    MSGIDX.BBS    — index: msgnum + board number (for fast lookup)
    MSGTOIDX.BBS  — index: recipient name (for "mail waiting" check)
    MSGINFO.BBS   — global counters (total messages, etc)

  Header record: 118 bytes packed. All text fields are space-padded.
  Text records: first byte = length (0-255), followed by that many chars.
  Index record: 4 bytes (MsgNum: Word + Board: Word).

  This is the format OLMS scans to build QWK packets. OpenOLMS reads
  the same files and produces the same output.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

const
  HUDSON_HDR_SIZE = 118;

type
  { Hudson message header — exactly 118 bytes packed.
    HAZARD: text fields are space-padded, NOT null-terminated.
    The Board field is 1-based (board 1 = first message area). }
  THudsonHdr = packed record
    MsgNum      : Word;                   {   2 bytes }
    PrevReply   : Word;                   {   2 bytes — previous in thread }
    NextReply   : Word;                   {   2 bytes — next in thread }
    TimesRead   : Word;                   {   2 bytes }
    StartBlock  : Word;                   {   2 bytes — first block in MSGTXT }
    NumBlocks   : Word;                   {   2 bytes — blocks in MSGTXT }
    DestNet     : Word;                   {   2 bytes — FidoNet destination net }
    DestNode    : Word;                   {   2 bytes — FidoNet destination node }
    OrigNet     : Word;                   {   2 bytes — FidoNet origin net }
    OrigNode    : Word;                   {   2 bytes — FidoNet origin node }
    DestZone    : Byte;                   {   1 byte }
    OrigZone    : Byte;                   {   1 byte }
    Cost        : Word;                   {   2 bytes }
    MsgAttr     : Byte;                   {   1 byte — message attributes }
    NetAttr     : Byte;                   {   1 byte — netmail attributes }
    Board       : Word;                   {   2 bytes — 1-based board number }
    PostDate    : array[1..8] of Char;    {   8 bytes — MM-DD-YY }
    PostTime    : array[1..5] of Char;    {   5 bytes — HH:MM }
    MsgTo       : array[1..35] of Char;   {  35 bytes }
    MsgFrom     : array[1..35] of Char;   {  35 bytes }
    Subject     : array[1..72] of Char;   {  72 bytes — original says 72 }
    _Pad        : array[1..6] of Byte;    {   padding to 118 }
  end;

  { Hudson index record }
  THudsonIdx = packed record
    MsgNum : Word;
    Board  : Word;
  end;

  { Hudson info record (MSGINFO.BBS) }
  THudsonInfo = packed record
    LowMsg    : Word;    { lowest message number }
    HighMsg   : Word;    { highest message number }
    TotalMsgs : Word;    { total active messages }
    TotalAreas: Word;    { total areas with messages }
  end;

  { Parsed message for OpenOLMS use }
  THudsonMessage = record
    MsgNum    : Word;
    Board     : Word;
    MsgTo     : String;
    MsgFrom   : String;
    Subject   : String;
    PostDate  : String;
    PostTime  : String;
    Body      : String;
    IsPrivate : Boolean;
    IsDeleted : Boolean;
    PrevReply : Word;
    NextReply : Word;
    OrigZone, OrigNet, OrigNode: Word;
    DestZone, DestNet, DestNode: Word;
  end;

  { Message attribute bits }
const
  HA_DELETED   = $01;
  HA_UNSENT    = $02;
  HA_PERMANENT = $04;
  HA_PRIVATE   = $08;
  HA_RECEIVED  = $10;
  HA_UNREAD    = $20;
  HA_LOCAL     = $40;

{ Read message headers for a specific board, starting from MsgNum.
  Returns messages in order. MaxMsgs = 0 means no limit. }
function HudsonReadBoard(const BasePath: String; Board: Word;
  StartMsg: Word; MaxMsgs: Word;
  var Messages: array of THudsonMessage): Integer;

{ Read a single message by number }
function HudsonReadMessage(const BasePath: String; MsgNum: Word;
  var Msg: THudsonMessage): Boolean;

{ Read the message body text from MSGTXT.BBS }
function HudsonReadText(const BasePath: String;
  StartBlock, NumBlocks: Word): String;

{ Read the MSGINFO.BBS counters }
function HudsonReadInfo(const BasePath: String;
  var Info: THudsonInfo): Boolean;

{ Extract trimmed string from a fixed-width field }
function HudsonFieldStr(const Field; Size: Integer): String;

implementation

uses SysUtils;

function HudsonFieldStr(const Field; Size: Integer): String;
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

function HudsonReadInfo(const BasePath: String;
  var Info: THudsonInfo): Boolean;
var
  F: File;
  Path: String;
begin
  Result := False;
  Path := IncludeTrailingPathDelimiter(BasePath) + 'MSGINFO.BBS';
  if not FileExists(Path) then Exit;

  AssignFile(F, Path);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;

  try
    BlockRead(F, Info, SizeOf(Info));
    Result := True;
  finally
    CloseFile(F);
  end;
end;

function HudsonReadText(const BasePath: String;
  StartBlock, NumBlocks: Word): String;
var
  F: File;
  Path: String;
  Len: Byte;
  Buf: array[0..255] of Char;
  I: Integer;
begin
  Result := '';
  Path := IncludeTrailingPathDelimiter(BasePath) + 'MSGTXT.BBS';
  if not FileExists(Path) then Exit;

  AssignFile(F, Path);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;

  try
    { Each text "block" in MSGTXT.BBS is a length-prefixed string:
      1 byte length + up to 255 bytes of text.
      HAZARD: blocks are variable-length, so we must read sequentially
      from block 0 to reach StartBlock. There is no random access. }
    I := 0;
    while not EOF(F) do
    begin
      BlockRead(F, Len, 1);
      if I >= StartBlock then
      begin
        if I >= StartBlock + NumBlocks then Break;
        if Len > 0 then
        begin
          FillChar(Buf, SizeOf(Buf), 0);
          BlockRead(F, Buf, Len);
          Result := Result + Copy(Buf, 1, Len);
        end;
        Result := Result + #13#10;
      end
      else begin
        { Skip this block }
        if Len > 0 then
          Seek(F, FilePos(F) + Len);
      end;
      Inc(I);
    end;
  finally
    CloseFile(F);
  end;
end;

function HudsonReadMessage(const BasePath: String; MsgNum: Word;
  var Msg: THudsonMessage): Boolean;
var
  F: File;
  Hdr: THudsonHdr;
  Path: String;
  BytesRead: LongInt;
begin
  Result := False;
  Path := IncludeTrailingPathDelimiter(BasePath) + 'MSGHDR.BBS';
  if not FileExists(Path) then Exit;

  AssignFile(F, Path);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;

  try
    { Scan headers for the matching message number }
    while not EOF(F) do
    begin
      FillChar(Hdr, SizeOf(Hdr), 0);
      BlockRead(F, Hdr, HUDSON_HDR_SIZE, BytesRead);
      if BytesRead <> HUDSON_HDR_SIZE then Break;

      if Hdr.MsgNum = MsgNum then
      begin
        Msg.MsgNum    := Hdr.MsgNum;
        Msg.Board     := Hdr.Board;
        Msg.MsgTo     := HudsonFieldStr(Hdr.MsgTo, 35);
        Msg.MsgFrom   := HudsonFieldStr(Hdr.MsgFrom, 35);
        Msg.Subject   := HudsonFieldStr(Hdr.Subject, 72);
        Msg.PostDate  := HudsonFieldStr(Hdr.PostDate, 8);
        Msg.PostTime  := HudsonFieldStr(Hdr.PostTime, 5);
        Msg.IsPrivate := (Hdr.MsgAttr and HA_PRIVATE) <> 0;
        Msg.IsDeleted := (Hdr.MsgAttr and HA_DELETED) <> 0;
        Msg.PrevReply := Hdr.PrevReply;
        Msg.NextReply := Hdr.NextReply;
        Msg.OrigZone  := Hdr.OrigZone;
        Msg.OrigNet   := Hdr.OrigNet;
        Msg.OrigNode  := Hdr.OrigNode;
        Msg.DestZone  := Hdr.DestZone;
        Msg.DestNet   := Hdr.DestNet;
        Msg.DestNode  := Hdr.DestNode;

        { Read the body }
        Msg.Body := HudsonReadText(BasePath, Hdr.StartBlock, Hdr.NumBlocks);

        Result := True;
        Exit;
      end;
    end;
  finally
    CloseFile(F);
  end;
end;

function HudsonReadBoard(const BasePath: String; Board: Word;
  StartMsg: Word; MaxMsgs: Word;
  var Messages: array of THudsonMessage): Integer;
var
  F: File;
  Hdr: THudsonHdr;
  Path: String;
  BytesRead: LongInt;
  Count: Integer;
begin
  Result := 0;
  Count := 0;
  Path := IncludeTrailingPathDelimiter(BasePath) + 'MSGHDR.BBS';
  if not FileExists(Path) then Exit;

  AssignFile(F, Path);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;

  try
    while not EOF(F) do
    begin
      FillChar(Hdr, SizeOf(Hdr), 0);
      BlockRead(F, Hdr, HUDSON_HDR_SIZE, BytesRead);
      if BytesRead <> HUDSON_HDR_SIZE then Break;

      { Skip deleted, wrong board, and messages before the pointer }
      if (Hdr.MsgAttr and HA_DELETED) <> 0 then Continue;
      if Hdr.Board <> Board then Continue;
      if Hdr.MsgNum < StartMsg then Continue;

      if Count > High(Messages) then Break;
      if (MaxMsgs > 0) and (Count >= MaxMsgs) then Break;

      Messages[Count].MsgNum   := Hdr.MsgNum;
      Messages[Count].Board    := Hdr.Board;
      Messages[Count].MsgTo    := HudsonFieldStr(Hdr.MsgTo, 35);
      Messages[Count].MsgFrom  := HudsonFieldStr(Hdr.MsgFrom, 35);
      Messages[Count].Subject  := HudsonFieldStr(Hdr.Subject, 72);
      Messages[Count].PostDate := HudsonFieldStr(Hdr.PostDate, 8);
      Messages[Count].PostTime := HudsonFieldStr(Hdr.PostTime, 5);
      Messages[Count].IsPrivate:= (Hdr.MsgAttr and HA_PRIVATE) <> 0;
      Messages[Count].IsDeleted:= False;
      Messages[Count].PrevReply:= Hdr.PrevReply;
      Messages[Count].NextReply:= Hdr.NextReply;
      { Body is read lazily — only when packing to QWK }
      Messages[Count].Body := '';

      Inc(Count);
    end;
  finally
    CloseFile(F);
  end;
  Result := Count;
end;

end.
