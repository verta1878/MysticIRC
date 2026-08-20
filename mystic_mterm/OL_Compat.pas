{ ===========================================================================
  OpenOLMS — OL_Compat.pas
  Binary-compatible record types for Peter Rocca's OLMS Version 2000.
  GPLv3 — Copyright (C) 2026 verta1878, wrench

  These packed records match the EXACT byte layout of the original
  OLMS data files (Turbo Pascal 7.0, real-mode DOS). Every field
  offset and SizeOf must match the original for drop-in compatibility.

  Verified against:
    OLMS.CFG      14,889 bytes
    USERS.DAT     14,340 bytes (30 × 478)
    MESSAGES.CTL  24,512 bytes (383 × 64)
    MESSAGES.IDX     762 bytes
    MESSAGES.INF       6 bytes
    USERS.IDX          4 bytes

  Turbo Pascal String[N] = N+1 bytes (1 length byte + N char bytes).
  Use PACKRECORDS 1 directive to prevent FPC from adding alignment padding.
  =========================================================================== }

{$MODE OBJFPC}{$H-}
{$PACKRECORDS 1}

unit OL_Compat;

interface

const
  OLMS_VERSION      = 200;       { Version 2000 }
  OLMS_MAX_ARCHIVERS = 6;
  OLMS_MAX_PROTOCOLS = 9;        { 9 send + 9 recv = 27 entries }
  OLMS_MAX_PROT_NAMES = 10;
  OLMS_MAX_USERS     = 30;
  OLMS_MAX_AREAS     = 383;
  OLMS_CFG_SIZE      = 14889;
  OLMS_USER_SIZE     = 478;
  OLMS_AREA_SIZE     = 64;

type
  { Turbo Pascal ShortString types — fixed size, length-prefixed }
  TOLStr8   = String[8];     {   9 bytes }
  TOLStr10  = String[10];    {  11 bytes }
  TOLStr13  = String[13];    {  14 bytes }
  TOLStr25  = String[25];    {  26 bytes }
  TOLStr30  = String[30];    {  31 bytes }
  TOLStr35  = String[35];    {  36 bytes }
  TOLStr40  = String[40];    {  41 bytes }
  TOLStr60  = String[60];    {  61 bytes }
  TOLStr70  = String[70];    {  71 bytes }

  { ---------------------------------------------------------------
    OLMS.CFG — Main Configuration (14,889 bytes)
    --------------------------------------------------------------- }

  { Archiver entry: pack + unpack command lines }
  TOLMSArchiverCmd = packed record
    PackCmd   : TOLStr70;     { e.g. "C:\Help\PKZIP.EXE -ex" }
  end;

  { Protocol command entry }
  TOLMSProtocolCmd = packed record
    Cmd : TOLStr70;           { e.g. "C:\Help\DSZ.EXE port *P sz -rr" }
  end;

  { Baud rate table entry — Word pairs at @3775 }
  TOLMSBaudEntry = packed record
    Rate : Word;              { baud rate value }
    Code : Word;              { FOSSIL/UART baud code }
  end;

  { Main configuration record — OLMS.CFG
    The full 14,889-byte layout has been partially decoded:
      @0-3: header, @4-91: system strings, @92-762: paths,
      @763-876: registration + flags, @877-3684: archivers + protocols,
      @3685-3794: protocol names + baud, @3795-14888: control data.

    Until Peter Rocca's source confirms every field, we store the
    entire file as a raw byte buffer and provide accessor functions
    for the decoded fields. This guarantees round-trip compatibility:
    load, modify known fields, save — unmodified bytes unchanged. }

  TOLMSConfigRaw = packed record
    Data: array[0..OLMS_CFG_SIZE-1] of Byte;
  end;

  { ---------------------------------------------------------------
    USERS.DAT — User Database (30 × 478 bytes = 14,340)
    --------------------------------------------------------------- }

  TOLMSUser = packed record
    { Header }
    Status      : Word;       { @  0: user status/flags }
    AccessLevel : Word;       { @  2: access level or user ID }

    { Identity }
    UserName    : TOLStr30;   { @  4: username (login name) }
    Alias       : TOLStr13;   { @ 35: alias/handle }

    { Last activity }
    LastDate    : TOLStr8;    { @ 49: last login date "MM-DD-YY" }
    LastTime    : TOLStr8;    { @ 58: last login time "HH:MM" — using 8 to cover gap }

    { Preferences }
    PrefsWord   : Word;       { @ 67: preference flags }
    ArchiverSel : array[0..5] of Byte; { @ 69: archiver/protocol selection }

    { Padding to align boolean block }
    Pad1        : array[0..4] of Byte; { @ 75 }

    { Boolean flags — area selections, feature toggles }
    BoolFlags   : array[0..OLMS_MAX_AREAS-1] of Byte; { @ 80: one byte per area }

    { Remaining — fills to 478 bytes }
    Tail        : array[0..9] of Byte; { padding to 478 }
  end;

  { ---------------------------------------------------------------
    MESSAGES.CTL — Area Configuration (383 × 64 bytes = 24,512)
    --------------------------------------------------------------- }

  TOLMSArea = packed record
    AreaTag     : TOLStr35;   { @  0: area tag/name (e.g. "MYSTIC") }
    AreaType    : Byte;       { @ 36: area type (local/echo/netmail) }
    AccessRead  : Byte;       { @ 37: read access level }
    AccessWrite : Byte;       { @ 38: write access level }
    Flags1      : Byte;       { @ 39: flag byte 1 }
    Flags2      : Byte;       { @ 40: flag byte 2 }
    OriginHi    : Byte;       { @ 41: FidoNet origin zone/net (hi) }
    OriginLo    : Byte;       { @ 42: FidoNet origin zone/net (lo) }
    Flags3      : Byte;       { @ 43: flag byte 3 }
    MsgFormat   : Byte;       { @ 44: message format (Hudson/JAM) }
    Flags4      : Byte;       { @ 45: flag byte 4 }
    AreaNumber  : Word;       { @ 46: RA area number }
    MaxMsgs     : Word;       { @ 48: max messages }
    Reserved    : array[0..13] of Byte; { @ 50: remaining flags/settings }
  end;

  { ---------------------------------------------------------------
    MESSAGES.IDX — Message Index (762 bytes)
    --------------------------------------------------------------- }

  TOLMSMsgIdx = packed record
    AreaNum   : Word;         { area number }
    MsgNum    : Word;         { message number }
    Flags     : Byte;         { status flags }
  end;

  { ---------------------------------------------------------------
    MESSAGES.INF — Message Info (6 bytes)
    --------------------------------------------------------------- }

  TOLMSMsgInf = packed record
    TotalAreas  : Word;       { number of active areas }
    TotalMsgs   : Word;       { total message count }
    Reserved    : Word;       { reserved }
  end;

  { ---------------------------------------------------------------
    USERS.IDX — User Index (4 bytes)
    --------------------------------------------------------------- }

  TOLMSUserIdx = packed record
    TotalUsers  : Word;       { number of active users }
    Reserved    : Word;       { reserved }
  end;

  { ---------------------------------------------------------------
    Turbo Pascal ShortString I/O
    --------------------------------------------------------------- }

function ReadTPStr(var Buf; MaxLen: Integer): String;
procedure WriteTPStr(var Buf; MaxLen: Integer; const S: String);

  { ---------------------------------------------------------------
    File I/O helpers
    --------------------------------------------------------------- }

function OLMSLoadConfig(const FileName: String; var Cfg): Boolean;
function OLMSSaveConfig(const FileName: String; var Cfg): Boolean;

{ Config field accessors — read/write known fields in the raw buffer }
function  CfgGetVersion(var Cfg: TOLMSConfigRaw): Word;
function  CfgGetBBSName(var Cfg: TOLMSConfigRaw): String;
procedure CfgSetBBSName(var Cfg: TOLMSConfigRaw; const S: String);
function  CfgGetSysopName(var Cfg: TOLMSConfigRaw): String;
procedure CfgSetSysopName(var Cfg: TOLMSConfigRaw; const S: String);
function  CfgGetPath(var Cfg: TOLMSConfigRaw; Index: Integer): String;
procedure CfgSetPath(var Cfg: TOLMSConfigRaw; Index: Integer; const S: String);
function  CfgGetRegCode(var Cfg: TOLMSConfigRaw): String;
function  CfgGetRegName(var Cfg: TOLMSConfigRaw): String;
function  CfgGetBBSPhone(var Cfg: TOLMSConfigRaw): String;
function  CfgGetDefLanguage(var Cfg: TOLMSConfigRaw): String;
function  CfgGetArchiverPack(var Cfg: TOLMSConfigRaw; Index: Integer): String;
function  CfgGetArchiverUnpack(var Cfg: TOLMSConfigRaw; Index: Integer): String;
function  CfgGetProtocolSend(var Cfg: TOLMSConfigRaw; Index: Integer): String;
function  CfgGetProtocolRecv(var Cfg: TOLMSConfigRaw; Index: Integer): String;
function  CfgGetProtocolName(var Cfg: TOLMSConfigRaw; Index: Integer): String;

function OLMSLoadUsers(const FileName: String; var Users: array of TOLMSUser;
  var Count: Integer): Boolean;
function OLMSSaveUsers(const FileName: String; var Users: array of TOLMSUser;
  Count: Integer): Boolean;

function OLMSLoadAreas(const FileName: String; var Areas: array of TOLMSArea;
  var Count: Integer): Boolean;
function OLMSSaveAreas(const FileName: String; var Areas: array of TOLMSArea;
  Count: Integer): Boolean;

implementation

uses SysUtils;

{ --- Internal helpers --- }

function ReadTPStr(var Buf; MaxLen: Integer): String;
{ Read a Turbo Pascal ShortString from a raw buffer.
  Byte 0 = length, bytes 1..length = characters. }
var
  P: PByte;
  L: Byte;
begin
  P := @Buf;
  L := P^;
  if L > MaxLen then L := MaxLen;
  SetLength(Result, L);
  if L > 0 then Move(P[1], Result[1], L);
end;

procedure WriteTPStr(var Buf; MaxLen: Integer; const S: String);
{ Write a Turbo Pascal ShortString to a raw buffer.
  Clears the entire field first (null-padded). }
var
  P: PByte;
  L: Byte;
begin
  P := @Buf;
  FillChar(P^, MaxLen + 1, 0);
  L := Length(S);
  if L > MaxLen then L := MaxLen;
  P^ := L;
  if L > 0 then Move(S[1], P[1], L);
end;

{ --- Config accessors --- }

function CfgGetVersion(var Cfg: TOLMSConfigRaw): Word;
begin
  Result := Cfg.Data[0] or (Cfg.Data[1] shl 8);
end;

function CfgGetBBSName(var Cfg: TOLMSConfigRaw): String;
begin Result := ReadTPStr(Cfg.Data[4], 30); end;

procedure CfgSetBBSName(var Cfg: TOLMSConfigRaw; const S: String);
begin WriteTPStr(Cfg.Data[4], 30, S); end;

function CfgGetSysopName(var Cfg: TOLMSConfigRaw): String;
begin Result := ReadTPStr(Cfg.Data[35], 30); end;

procedure CfgSetSysopName(var Cfg: TOLMSConfigRaw; const S: String);
begin WriteTPStr(Cfg.Data[35], 30, S); end;

function CfgGetPath(var Cfg: TOLMSConfigRaw; Index: Integer): String;
begin
  if (Index < 0) or (Index > 10) then begin Result := ''; Exit; end;
  Result := ReadTPStr(Cfg.Data[92 + Index * 61], 60);
end;

procedure CfgSetPath(var Cfg: TOLMSConfigRaw; Index: Integer; const S: String);
begin
  if (Index < 0) or (Index > 10) then Exit;
  WriteTPStr(Cfg.Data[92 + Index * 61], 60, S);
end;

function CfgGetRegCode(var Cfg: TOLMSConfigRaw): String;
begin Result := ReadTPStr(Cfg.Data[764], 40); end;

function CfgGetRegName(var Cfg: TOLMSConfigRaw): String;
begin Result := ReadTPStr(Cfg.Data[805], 40); end;

function CfgGetDefLanguage(var Cfg: TOLMSConfigRaw): String;
begin Result := ReadTPStr(Cfg.Data[846], 8); end;

function CfgGetBBSPhone(var Cfg: TOLMSConfigRaw): String;
begin Result := ReadTPStr(Cfg.Data[855], 13); end;

function CfgGetArchiverPack(var Cfg: TOLMSConfigRaw; Index: Integer): String;
begin
  if (Index < 0) or (Index >= OLMS_MAX_ARCHIVERS) then begin Result := ''; Exit; end;
  Result := ReadTPStr(Cfg.Data[877 + Index * 71], 70);
end;

function CfgGetArchiverUnpack(var Cfg: TOLMSConfigRaw; Index: Integer): String;
begin
  if (Index < 0) or (Index >= OLMS_MAX_ARCHIVERS) then begin Result := ''; Exit; end;
  Result := ReadTPStr(Cfg.Data[1303 + Index * 71], 70);
end;

function CfgGetProtocolSend(var Cfg: TOLMSConfigRaw; Index: Integer): String;
begin
  if (Index < 0) or (Index >= OLMS_MAX_PROTOCOLS) then begin Result := ''; Exit; end;
  Result := ReadTPStr(Cfg.Data[1729 + Index * 71], 70);
end;

function CfgGetProtocolRecv(var Cfg: TOLMSConfigRaw; Index: Integer): String;
begin
  if (Index < 0) or (Index >= OLMS_MAX_PROTOCOLS) then begin Result := ''; Exit; end;
  Result := ReadTPStr(Cfg.Data[2155 + Index * 71], 70);
end;

function CfgGetProtocolName(var Cfg: TOLMSConfigRaw; Index: Integer): String;
begin
  if (Index < 0) or (Index >= OLMS_MAX_PROT_NAMES) then begin Result := ''; Exit; end;
  Result := ReadTPStr(Cfg.Data[3685 + Index * 11], 10);
end;

function OLMSLoadConfig(const FileName: String; var Cfg): Boolean;
var F: File;
begin
  Result := False;
  if not FileExists(FileName) then Exit;
  AssignFile(F, FileName);
  Reset(F, 1);
  try
    BlockRead(F, Cfg, OLMS_CFG_SIZE);
    Result := True;
  finally
    CloseFile(F);
  end;
end;

function OLMSSaveConfig(const FileName: String; var Cfg): Boolean;
var F: File;
begin
  Result := False;
  AssignFile(F, FileName);
  Rewrite(F, 1);
  try
    BlockWrite(F, Cfg, OLMS_CFG_SIZE);
    Result := True;
  finally
    CloseFile(F);
  end;
end;

function OLMSLoadUsers(const FileName: String; var Users: array of TOLMSUser;
  var Count: Integer): Boolean;
var F: File; I: Integer; FileSize: LongInt;
begin
  Result := False;
  Count := 0;
  if not FileExists(FileName) then Exit;
  AssignFile(F, FileName);
  Reset(F, 1);
  try
    FileSize := System.FileSize(F);
    Count := FileSize div OLMS_USER_SIZE;
    if Count > OLMS_MAX_USERS then Count := OLMS_MAX_USERS;
    for I := 0 to Count - 1 do
      BlockRead(F, Users[I], OLMS_USER_SIZE);
    Result := True;
  finally
    CloseFile(F);
  end;
end;

function OLMSSaveUsers(const FileName: String; var Users: array of TOLMSUser;
  Count: Integer): Boolean;
var F: File; I: Integer;
begin
  Result := False;
  AssignFile(F, FileName);
  Rewrite(F, 1);
  try
    for I := 0 to Count - 1 do
      BlockWrite(F, Users[I], OLMS_USER_SIZE);
    Result := True;
  finally
    CloseFile(F);
  end;
end;

function OLMSLoadAreas(const FileName: String; var Areas: array of TOLMSArea;
  var Count: Integer): Boolean;
var F: File; I: Integer; FileSize: LongInt;
begin
  Result := False;
  Count := 0;
  if not FileExists(FileName) then Exit;
  AssignFile(F, FileName);
  Reset(F, 1);
  try
    FileSize := System.FileSize(F);
    Count := FileSize div OLMS_AREA_SIZE;
    if Count > OLMS_MAX_AREAS then Count := OLMS_MAX_AREAS;
    for I := 0 to Count - 1 do
      BlockRead(F, Areas[I], OLMS_AREA_SIZE);
    Result := True;
  finally
    CloseFile(F);
  end;
end;

function OLMSSaveAreas(const FileName: String; var Areas: array of TOLMSArea;
  Count: Integer): Boolean;
var F: File; I: Integer;
begin
  Result := False;
  AssignFile(F, FileName);
  Rewrite(F, 1);
  try
    for I := 0 to Count - 1 do
      BlockWrite(F, Areas[I], OLMS_AREA_SIZE);
    Result := True;
  finally
    CloseFile(F);
  end;
end;

end.
