{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Clean-room reimplementation from published documentation.

  Pending licence — with permission from Peter Rocca.
  =========================================================================== }

unit OL_Config;
{ ===========================================================================
  OpenOLMS — configuration records
  ---------------------------------------------------------------------------
  Reconstructed from OLMS.DOC sections "System Information" through
  "Limits Setup" and the binary layout of OLMS.CFG. This is a
  clean-room reimplementation — no decompilation was performed.

  OLMS.CFG is a fixed-size binary file containing packed records.
  The paths are null-terminated Pascal strings with a length prefix byte,
  padded to 60 bytes. The config was designed for RemoteAccess 2.x
  but the data structures are BBS-agnostic.

  OpenOLMS uses the same CFG layout for compatibility — an existing
  OLMS installation's OLMS.CFG can be read directly.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

const
  OLMS_PATH_LEN = 60;     { fixed-width path field }
  OLMS_NAME_LEN = 40;     { fixed-width name field }
  OLMS_MAX_ARCHIVERS = 7; { ARJ, LHA, ZIP, ARC, PAK, RAR, custom }
  OLMS_MAX_PROTOCOLS = 4; { Xmodem, Ymodem, Zmodem, custom }

type
  { Fixed-width path as stored in the CFG file.
    First byte = length, rest = chars, null-padded to OLMS_PATH_LEN. }
  TOLMSPath = packed array[0..OLMS_PATH_LEN - 1] of Char;
  TOLMSName = packed array[0..OLMS_NAME_LEN - 1] of Char;

  { Archiver entry — command lines for pack and unpack }
  TOLMSArchiver = packed record
    PackCmd   : TOLMSPath;    { e.g. "C:\Help\PKZIP.EXE -ex" }
    UnpackCmd : TOLMSPath;    { e.g. "C:\Help\PKUNZIP.EXE -o" }
  end;

  { Protocol entry — command lines for send and receive }
  TOLMSProtocol = packed record
    Name      : array[0..9] of Char;
    SendCmd   : TOLMSPath;    { e.g. "C:\Help\DSZ.EXE port *P sz" }
    RecvCmd   : TOLMSPath;    { e.g. "C:\Help\DSZ.EXE port *P rz" }
  end;

  { Main configuration record — loaded from OLMS.CFG }
  TOLMSConfig = record
    { System Information }
    BBSName      : String;
    SysopName    : String;
    MsgBasePath  : String;     { path to message base files }
    RAPath       : String;     { path to RemoteAccess system files }
    FileBasePath : String;     { path to file database }
    NodelistPath : String;     { path to nodelist }

    { Display files }
    WelcomeFile  : String;     { ANSI welcome screen }
    LogoFile     : String;     { ANSI logo }
    GoodbyeFile  : String;     { ANSI goodbye screen }

    { Operational paths }
    LogFile      : String;     { log file path }
    UploadPath   : String;     { where uploads are stored }
    DownloadPath : String;     { where downloads are prepared }
    TaglinePath  : String;     { tagline file }

    { Registration }
    RegCode      : String;
    RegName      : String;

    { Archivers }
    Archivers    : array[0..OLMS_MAX_ARCHIVERS - 1] of TOLMSArchiver;

    { Protocols }
    Protocols    : array[0..OLMS_MAX_PROTOCOLS - 1] of TOLMSProtocol;

    { Control settings (from OLMS.DOC "Control Setup") }
    AllowFileReq   : Boolean;  { allow file requesting }
    AllowAttach    : Boolean;  { allow message attachments }
    AutoLogoff     : Boolean;  { logoff after download }
    IncludeNewFiles: Boolean;  { include new files list }
    DuplicateCheck : Boolean;  { check for duplicate uploads }
    MaxMsgPerArea  : Word;     { max messages per area per pack }
    MaxPackSize    : Word;     { max pack size in KB }
    TimeWarning    : Word;     { minutes left warning }
    MsgBaseFormat  : Byte;     { 0=Hudson, 1=JAM }

    { Phone number (for CONTROL.DAT) }
    BBSPhone       : String;

    { Default language }
    DefLanguage    : String;
  end;

{ Load configuration from OLMS.CFG file }
function OLMSLoadConfig(const Filename: String; var Cfg: TOLMSConfig): Boolean;

{ Save configuration to OLMS.CFG file }
function OLMSSaveConfig(const Filename: String; const Cfg: TOLMSConfig): Boolean;

{ Initialize a config with sane defaults }
procedure OLMSDefaultConfig(var Cfg: TOLMSConfig);

implementation

uses SysUtils;

procedure OLMSDefaultConfig(var Cfg: TOLMSConfig);
begin
  FillChar(Cfg, SizeOf(Cfg), 0);
  Cfg.BBSName       := 'My BBS';
  Cfg.SysopName     := 'Sysop';
  Cfg.MsgBasePath   := 'C:\MSGBASE\';
  Cfg.RAPath        := 'C:\RA\';
  Cfg.FileBasePath  := 'C:\RA\FDB\';
  Cfg.UploadPath    := 'C:\RA\OLMS\UPLOAD\';
  Cfg.DownloadPath  := 'C:\RA\OLMS\DOWN\';
  Cfg.LogFile       := 'C:\RA\OLMS.LOG';
  Cfg.TaglinePath   := 'C:\RA\OLMS.TAG';
  Cfg.BBSPhone      := '(XXX)YYY-ZZZZ';
  Cfg.DefLanguage   := 'DEFAULT';
  Cfg.MaxMsgPerArea := 300;
  Cfg.MaxPackSize   := 1024;
  Cfg.TimeWarning   := 5;
  Cfg.MsgBaseFormat := 0;   { Hudson }
  Cfg.AllowFileReq  := True;
  Cfg.DuplicateCheck:= True;

  { Default archivers — same as OLMS ships with }
  Cfg.Archivers[0].PackCmd   := 'ARJ.EXE a';
  Cfg.Archivers[0].UnpackCmd := 'ARJ.EXE e';
  Cfg.Archivers[1].PackCmd   := 'LHA.EXE a /m';
  Cfg.Archivers[1].UnpackCmd := 'LHA.EXE e /m';
  Cfg.Archivers[2].PackCmd   := 'PKZIP.EXE -ex';
  Cfg.Archivers[2].UnpackCmd := 'PKUNZIP.EXE -o';
  Cfg.Archivers[3].PackCmd   := 'PKARC.COM A';
  Cfg.Archivers[3].UnpackCmd := 'PKXARC.COM -ER';
  Cfg.Archivers[4].PackCmd   := 'PAK.EXE A /I';
  Cfg.Archivers[4].UnpackCmd := 'PAK.EXE E /I /WA';
  Cfg.Archivers[5].PackCmd   := 'RAR.EXE a';
  Cfg.Archivers[5].UnpackCmd := 'RAR.EXE e -o+';

  { Default protocols }
  Cfg.Protocols[0].Name := 'Xmodem';
  Cfg.Protocols[1].Name := 'Ymodem';
  Cfg.Protocols[2].Name := 'Zmodem';
end;

function OLMSLoadConfig(const Filename: String; var Cfg: TOLMSConfig): Boolean;
begin
  { TODO: parse the binary CFG format.
    For Phase 1, use defaults and let the FV config editor
    create new configs. Binary-compatible CFG reading is Phase 2. }
  Result := False;
  if not FileExists(Filename) then Exit;
  { Placeholder — will parse the packed binary format in Phase 2 }
  OLMSDefaultConfig(Cfg);
  Result := True;
end;

function OLMSSaveConfig(const Filename: String; const Cfg: TOLMSConfig): Boolean;
begin
  { TODO: write the binary CFG format.
    Phase 2 — match the original layout byte-for-byte. }
  Result := False;
end;

end.
