{
  This file is part of the Mystic BBS IRC Fork.

  Copyright (C) 2026 Mystic BBS IRC Fork Contributors

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
}
{
  uforkpty — pure-FPC forkpty replacement (no libc dependency)

  Replaces the libc forkpty() call with direct Linux syscalls:
    /dev/ptmx → open master → grantpt → unlockpt → ptsname → open slave
    fpFork → child attaches slave to stdin/stdout/stderr via fpDup2

  Usage:
    uses uforkpty;
    pid := ForkPTY_Pure(@masterfd, nil, nil, nil);
    // pid=0: child (slave PTY is stdin/stdout/stderr)
    // pid>0: parent (masterfd is the PTY master)

  No libc, no libutil, no gcc-multilib needed.

  Copyright (c) 2026 fpc264irc contributors
  License: GPLv3+
}
unit uforkpty;

{$mode objfpc}

interface

uses baseunix, unix;

{ Drop-in replacement for libc forkpty().
  amaster: receives the master PTY fd
  name: receives slave PTY name (can be nil)
  termp: terminal attributes (can be nil, ignored)
  winp: window size (can be nil, ignored)
  Returns: 0 in child, child PID in parent, -1 on error }
function ForkPTY_Pure(amaster: PLongInt; name: PChar;
  termp: Pointer; winp: Pointer): LongInt;

{ Open a PTY pair without forking.
  Returns master fd, sets slavefd and slavename. }
function OpenPTY(var masterfd, slavefd: LongInt;
  slavename: PChar; namelen: LongInt): Boolean;

implementation

const
  O_RDWR   = $02;
  O_NOCTTY = $100;

function OpenPTY(var masterfd, slavefd: LongInt;
  slavename: PChar; namelen: LongInt): Boolean;
var
  ptsn: LongInt;
  ptspath: string[64];
  zero: LongInt;
begin
  Result := false;

  { Open master: /dev/ptmx }
  masterfd := fpOpen('/dev/ptmx', O_RDWR or O_NOCTTY);
  if masterfd < 0 then exit;

  { grantpt + unlockpt via ioctl }
  zero := 0;
  if fpIOCtl(masterfd, $5431, @zero) < 0 then begin { TIOCSPTLCK = unlock }
    fpClose(masterfd);
    exit;
  end;

  { ptsname via ioctl TIOCGPTN }
  if fpIOCtl(masterfd, $80045430, @ptsn) < 0 then begin
    fpClose(masterfd);
    exit;
  end;

  { Build slave path: /dev/pts/N }
  Str(ptsn, ptspath);
  ptspath := '/dev/pts/' + ptspath;

  { Copy slave name if requested }
  if slavename <> nil then begin
    if Length(ptspath) < namelen then begin
      Move(ptspath[1], slavename^, Length(ptspath));
      slavename[Length(ptspath)] := #0;
    end;
  end;

  { Open slave }
  slavename[0] := #0; { reuse slavename buffer }
  Move(ptspath[1], slavename[0], Length(ptspath));
  slavename[Length(ptspath)] := #0;
  slavefd := fpOpen(@slavename[0], O_RDWR);
  if slavefd < 0 then begin
    fpClose(masterfd);
    exit;
  end;

  Result := true;
end;

function ForkPTY_Pure(amaster: PLongInt; name: PChar;
  termp: Pointer; winp: Pointer): LongInt;
var
  masterfd, slavefd: LongInt;
  pid: LongInt;
  slavename: array[0..63] of Char;
begin
  ForkPTY_Pure := -1;

  { Open PTY pair }
  if not OpenPTY(masterfd, slavefd, @slavename[0], SizeOf(slavename)) then
    exit;

  { Copy name if requested }
  if name <> nil then
    Move(slavename, name^, 64);

  { Fork }
  pid := fpFork;

  if pid < 0 then begin
    { Fork failed }
    fpClose(masterfd);
    fpClose(slavefd);
    exit;
  end;

  if pid = 0 then begin
    { Child: attach slave PTY to stdin/stdout/stderr }
    fpClose(masterfd);

    { Create new session }
    fpSetSid;

    { Set controlling terminal }
    fpIOCtl(slavefd, $540E, nil); { TIOCSCTTY }

    { Redirect stdio }
    fpDup2(slavefd, 0); { stdin }
    fpDup2(slavefd, 1); { stdout }
    fpDup2(slavefd, 2); { stderr }

    if slavefd > 2 then
      fpClose(slavefd);

    ForkPTY_Pure := 0;
  end else begin
    { Parent: return master fd }
    fpClose(slavefd);
    if amaster <> nil then
      amaster^ := masterfd;
    ForkPTY_Pure := pid;
  end;
end;

end.
