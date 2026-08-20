{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Clean-room reimplementation from published documentation.
  Pending licence — with permission from Peter Rocca.
  =========================================================================== }

unit OL_MsgCtl;
{ ===========================================================================
  OpenOLMS — MESSAGES.CTL parser
  ---------------------------------------------------------------------------
  MESSAGES.CTL is the conference control file. It defines which message
  areas are available for offline mail and their properties: name, base
  type, flags, and limits.

  Binary format (from the original OLMS distribution):

    Each record is 64 bytes (packed):
      Offset 0:   Length-prefixed area name (1 byte length + up to 35 chars)
      Offset 36:  Reserved/padding
      Offset 40:  Area flags (Word) — read-only, private, netmail, etc
      Offset 42:  Area number in the BBS (Word)
      Offset 44:  Base type (Byte) — 0=Hudson, 1=JAM
      Offset 46:  Max messages (Word) — 0 = use default from config
      Offset 48-63: Reserved/padding

  The area name is the FidoNet-style tag (e.g. "PUBLIC", "THE_TOASTER_OVEN").

  This record layout was reconstructed from the binary dump of
  MESSAGES.CTL in the original distribution, cross-referenced with
  the documentation in OLMS.DOC §"Files Configuration".
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

const
  MSGCTL_RECORD_SIZE = 64;
  MSGCTL_NAME_LEN    = 35;

  { Area flags }
  AF_READONLY    = $0001;   { sysop forced area — can't unsubscribe }
  AF_BLOCKED     = $0002;   { sysop blocked — never included }
  AF_PRIVATE     = $0004;   { private messages only }
  AF_NETMAIL     = $0008;   { netmail area }
  AF_INTERNET    = $0010;   { internet gateway area }

type
  TMsgAreaRec = packed record
    NameLen   : Byte;
    Name      : array[1..MSGCTL_NAME_LEN] of Char;
    _Pad1     : array[1..4] of Byte;
    Flags     : Word;
    AreaNum   : Word;
    BaseType  : Byte;
    _Pad2     : Byte;
    MaxMsgs   : Word;
    _Pad3     : array[1..16] of Byte;
  end;

  { Parsed area info — clean Pascal record }
  TMsgArea = record
    Name      : String;
    AreaNum   : Word;
    Flags     : Word;
    BaseType  : Byte;
    MaxMsgs   : Word;
    Selected  : Boolean;   { user has selected this area for scanning }
  end;

  TMsgAreaList = array of TMsgArea;

{ Load MESSAGES.CTL and return the area list }
function LoadMsgCtl(const Filename: String; var Areas: TMsgAreaList): Boolean;

{ Save MESSAGES.CTL from the area list }
function SaveMsgCtl(const Filename: String; const Areas: TMsgAreaList): Boolean;

{ Find an area by number }
function FindArea(const Areas: TMsgAreaList; AreaNum: Word): Integer;

{ Check if an area has a specific flag }
function AreaHasFlag(const Area: TMsgArea; Flag: Word): Boolean;

implementation

uses SysUtils;

function LoadMsgCtl(const Filename: String; var Areas: TMsgAreaList): Boolean;
var
  F: File;
  Rec: TMsgAreaRec;
  BytesRead: LongInt;
  Count, I: Integer;
  FileSize: LongInt;
begin
  Result := False;
  SetLength(Areas, 0);
  if not FileExists(Filename) then Exit;

  AssignFile(F, Filename);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult <> 0 then Exit;

  try
    FileSize := System.FileSize(F);
    Count := FileSize div MSGCTL_RECORD_SIZE;
    SetLength(Areas, Count);

    for I := 0 to Count - 1 do
    begin
      FillChar(Rec, SizeOf(Rec), 0);
      BlockRead(F, Rec, MSGCTL_RECORD_SIZE, BytesRead);
      if BytesRead <> MSGCTL_RECORD_SIZE then
      begin
        SetLength(Areas, I);
        Break;
      end;

      { Extract the area name — length-prefixed Pascal string }
      if Rec.NameLen > MSGCTL_NAME_LEN then
        Rec.NameLen := MSGCTL_NAME_LEN;
      SetLength(Areas[I].Name, Rec.NameLen);
      Move(Rec.Name[1], Areas[I].Name[1], Rec.NameLen);

      Areas[I].AreaNum  := Rec.AreaNum;
      Areas[I].Flags    := Rec.Flags;
      Areas[I].BaseType := Rec.BaseType;
      Areas[I].MaxMsgs  := Rec.MaxMsgs;
      Areas[I].Selected := True;   { default: all areas selected }

      { Sysop-blocked areas are never selected }
      if (Areas[I].Flags and AF_BLOCKED) <> 0 then
        Areas[I].Selected := False;
    end;

    Result := Count > 0;
  finally
    CloseFile(F);
  end;
end;

function SaveMsgCtl(const Filename: String; const Areas: TMsgAreaList): Boolean;
var
  F: File;
  Rec: TMsgAreaRec;
  I, Len: Integer;
begin
  Result := False;
  AssignFile(F, Filename);
  {$I-}
  Rewrite(F, 1);
  {$I+}
  if IOResult <> 0 then Exit;

  try
    for I := 0 to High(Areas) do
    begin
      FillChar(Rec, SizeOf(Rec), 0);
      Len := Length(Areas[I].Name);
      if Len > MSGCTL_NAME_LEN then Len := MSGCTL_NAME_LEN;
      Rec.NameLen := Len;
      Move(Areas[I].Name[1], Rec.Name[1], Len);
      Rec.AreaNum  := Areas[I].AreaNum;
      Rec.Flags    := Areas[I].Flags;
      Rec.BaseType := Areas[I].BaseType;
      Rec.MaxMsgs  := Areas[I].MaxMsgs;
      BlockWrite(F, Rec, MSGCTL_RECORD_SIZE);
    end;
    Result := True;
  finally
    CloseFile(F);
  end;
end;

function FindArea(const Areas: TMsgAreaList; AreaNum: Word): Integer;
var I: Integer;
begin
  for I := 0 to High(Areas) do
    if Areas[I].AreaNum = AreaNum then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

function AreaHasFlag(const Area: TMsgArea; Flag: Word): Boolean;
begin
  Result := (Area.Flags and Flag) <> 0;
end;

end.
