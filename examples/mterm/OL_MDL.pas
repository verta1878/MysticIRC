{ ===========================================================================
  MOLMS — OpenOLMS for Mystic BBS (MDL version)
  GPLv3 — clean-room reimplementation with Peter Rocca's permission.
  =========================================================================== }

unit OL_MDL;
{ ===========================================================================
  MOLMS — Mystic Development Library interface
  ---------------------------------------------------------------------------
  Stub unit that wraps Mystic BBS's MDL (Mystic Development Library).
  MDL provides the door framework for Mystic: I/O, user records,
  message base access, file transfers, and ANSI rendering.

  This stub defines the interface OpenOLMS needs from MDL. When
  building against real Mystic MDL, replace this unit with the
  actual MDL units or adjust the uses clause.

  MDL functions we need:
    - Session I/O (read/write to remote + local)
    - User record access (name, security, time left)
    - Message base access (Mystic uses a JAM-like format)
    - File transfer (protocol send/receive)
    - ANSI output with Mystic's pipe codes

  Mystic pipe codes: |01-|15 = colors, |CL = clear screen,
  |CR = carriage return, |PA = pause, |RA = right-align, etc.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

type
  { Mystic session — represents the current caller }
  TMysticSession = record
    UserName    : String;
    UserNum     : LongInt;
    SecurityLvl : Integer;
    TimeLeft    : Integer;
    NodeNum     : Integer;
    IsLocal     : Boolean;
    HasANSI     : Boolean;
  end;

  { Mystic message area info }
  TMysticMsgArea = record
    AreaNum     : Integer;
    Name        : String;
    FileName    : String;    { JAM base filename }
    AreaType    : Byte;      { 0=local, 1=echo, 2=netmail }
    ReadOnly    : Boolean;
  end;

{ Initialize MDL — call at door startup.
  In real MDL: reads Mystic's door data, opens COM port.
  In this stub: reads DORINFO1.DEF as a fallback. }
function MDLInit: Boolean;

{ Shutdown MDL — call before exit }
procedure MDLDone;

{ Get session info }
function MDLGetSession: TMysticSession;

{ Output to user (remote + local) }
procedure MDLWrite(const S: String);
procedure MDLWriteLn(const S: String);

{ Output with Mystic pipe codes (|01 = dark blue, |09 = bright blue, etc) }
procedure MDLWritePipe(const S: String);

{ Read a line from user }
function MDLReadLn(MaxLen: Integer): String;

{ Read a single key }
function MDLReadKey: Char;

{ Check if user has time remaining }
function MDLTimeLeft: Integer;

{ Check for carrier (hangup detection) }
function MDLCarrier: Boolean;

{ Clear screen }
procedure MDLCls;

{ Pause }
procedure MDLPause;

{ Get list of message areas }
function MDLGetAreas(var Areas: array of TMysticMsgArea): Integer;

implementation

uses SysUtils, OL_DropFile;

var
  GSession: TMysticSession;
  GInitDone: Boolean;

function MDLInit: Boolean;
var
  Info: TSessionInfo;
begin
  { Stub: read a drop file since we don't have real MDL.
    Real MDL would read Mystic's internal door data. }
  DefaultSession(Info);
  LoadDropFile('.', Info);

  GSession.UserName    := Info.UserName;
  GSession.UserNum     := 0;
  GSession.SecurityLvl := Info.SecurityLvl;
  GSession.TimeLeft    := Info.TimeLeft;
  GSession.NodeNum     := Info.NodeNum;
  GSession.IsLocal     := Info.ComPort = 0;
  GSession.HasANSI     := Info.ANSI;

  GInitDone := True;
  Result := True;
end;

procedure MDLDone;
begin
  GInitDone := False;
end;

function MDLGetSession: TMysticSession;
begin
  Result := GSession;
end;

procedure MDLWrite(const S: String);
begin
  Write(S);
end;

procedure MDLWriteLn(const S: String);
begin
  WriteLn(S);
end;

procedure MDLWritePipe(const S: String);
{ Stub: convert Mystic pipe codes to ANSI.
  |00-|15 = colors, |CL = cls, |CR = newline, |PA = pause.
  Real MDL handles this internally. }
var
  I: Integer;
  Code: String;
begin
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '|') and (I + 2 <= Length(S)) then
    begin
      Code := Copy(S, I + 1, 2);
      if Code = 'CL' then
        MDLCls
      else if Code = 'CR' then
        WriteLn
      else if Code = 'PA' then
        MDLPause
      else
      begin
        { Color code: |00-|15 }
        { Simplified: just output as-is for the stub }
        Write(S[I]);
        Inc(I);
        Continue;
      end;
      Inc(I, 3);
    end
    else
    begin
      Write(S[I]);
      Inc(I);
    end;
  end;
end;

function MDLReadLn(MaxLen: Integer): String;
var S: String;
begin
  ReadLn(S);
  if Length(S) > MaxLen then SetLength(S, MaxLen);
  Result := S;
end;

function MDLReadKey: Char;
begin
  Result := Chr(0);
  if not EOF(Input) then Read(Result);
end;

function MDLTimeLeft: Integer;
begin
  Result := GSession.TimeLeft;
end;

function MDLCarrier: Boolean;
begin
  { Stub: always true (local mode). Real MDL checks DCD. }
  Result := True;
end;

procedure MDLCls;
begin
  Write(#27'[2J', #27'[1;1H');
end;

procedure MDLPause;
begin
  Write('Press any key...');
  MDLReadKey;
  WriteLn;
end;

function MDLGetAreas(var Areas: array of TMysticMsgArea): Integer;
begin
  { Stub: return 0 areas. Real MDL reads Mystic's area config.
    When building against real Mystic, this reads the message
    base configuration directly — no MESSAGES.CTL needed. }
  Result := 0;
end;

end.
