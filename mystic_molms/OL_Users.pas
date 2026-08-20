{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Clean-room reimplementation from published documentation.
  Pending licence — with permission from Peter Rocca.
  =========================================================================== }

unit OL_Users;
{ ===========================================================================
  OpenOLMS — USERS.DAT format
  ---------------------------------------------------------------------------
  USERS.DAT stores per-user offline mail settings: last message read
  pointers, selected areas, archive preference, and session history.

  Binary format (from original distribution binary dump):

    Each record is approximately 256 bytes (packed):
      Offset 0:     Record length / flags (Word + Word)
      Offset 4:     User name (length-prefixed, up to 36 chars)
      Offset 48:    Last pack date (8 bytes, MM-DD-YY format)
      Offset 56:    Last pack time (5 bytes, HH:MM format)
      Offset 64:    Password/registration hash (8 bytes)
      Offset 72:    User flags (Byte)
      Offset 80:    Archive preference (Byte: 0=ZIP,1=ARJ,2=LHA...)
      Offset 81:    Protocol preference (Byte)
      Offset 82:    Packet format (Byte: 0=QWK,1=BlueWave)
      Offset 83:    Conference selection bitmap (variable length)

  The exact layout varies with the number of configured conferences.
  We handle this by reading the header fixed portion and then the
  variable-length conference bitmap.

  This record layout was reconstructed from the USERS.DAT binary in
  the original distribution, showing "Leslie Given" as a user with
  conference selections and last-pack timestamps.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

const
  OLMS_USER_NAME_LEN = 36;
  OLMS_MAX_CONFS     = 200;   { max conferences OLMS supports }

type
  TOLMSUser = record
    Name          : String;
    LastPackDate  : String;    { MM-DD-YY }
    LastPackTime  : String;    { HH:MM }
    ArchivePref   : Byte;     { 0=ZIP, 1=ARJ, 2=LHA, 3=ARC, 4=PAK, 5=RAR }
    ProtocolPref  : Byte;     { 0=Xmodem, 1=Ymodem, 2=Zmodem }
    PacketFormat  : Byte;     { 0=QWK, 1=BlueWave }
    ConfSelected  : array[0..OLMS_MAX_CONFS - 1] of Boolean;
    MsgPointers   : array[0..OLMS_MAX_CONFS - 1] of LongInt;
    TotalPacks    : LongInt;
    TotalMsgs     : LongInt;
  end;

  TOLMSUserList = array of TOLMSUser;

{ Find a user by name in USERS.DAT (case-insensitive) }
function FindUser(const Users: TOLMSUserList; const Name: String): Integer;

{ Create a new user with defaults }
procedure NewUser(var User: TOLMSUser; const Name: String);

{ Reset message pointers for a user }
procedure ResetPointers(var User: TOLMSUser; ResetBack: LongInt);

{ Reset selected area pointers only }
procedure ResetSelectedPointers(var User: TOLMSUser;
  const Areas: array of Boolean; ResetBack: LongInt);

implementation

uses SysUtils;

function FindUser(const Users: TOLMSUserList; const Name: String): Integer;
var I: Integer;
begin
  for I := 0 to High(Users) do
    if CompareText(Users[I].Name, Name) = 0 then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

procedure NewUser(var User: TOLMSUser; const Name: String);
var I: Integer;
begin
  FillChar(User, SizeOf(User), 0);
  User.Name := Name;
  User.ArchivePref := 0;    { ZIP default }
  User.ProtocolPref := 2;   { Zmodem default }
  User.PacketFormat := 0;   { QWK default }
  { Select all conferences by default }
  for I := 0 to OLMS_MAX_CONFS - 1 do
    User.ConfSelected[I] := True;
end;

procedure ResetPointers(var User: TOLMSUser; ResetBack: LongInt);
var I: Integer;
begin
  { /RG — reset all pointers.
    If ResetBack > 0 (e.g. /RG=50), subtract that many from each pointer.
    If ResetBack = 0, reset to 0 (re-scan everything). }
  for I := 0 to OLMS_MAX_CONFS - 1 do
  begin
    if ResetBack > 0 then
    begin
      User.MsgPointers[I] := User.MsgPointers[I] - ResetBack;
      if User.MsgPointers[I] < 0 then
        User.MsgPointers[I] := 0;
    end
    else
      User.MsgPointers[I] := 0;
  end;
end;

procedure ResetSelectedPointers(var User: TOLMSUser;
  const Areas: array of Boolean; ResetBack: LongInt);
var I: Integer;
begin
  { /RS — reset only user-selected areas }
  for I := 0 to High(Areas) do
    if (I < OLMS_MAX_CONFS) and Areas[I] then
    begin
      if ResetBack > 0 then
      begin
        User.MsgPointers[I] := User.MsgPointers[I] - ResetBack;
        if User.MsgPointers[I] < 0 then
          User.MsgPointers[I] := 0;
      end
      else
        User.MsgPointers[I] := 0;
    end;
end;

end.
