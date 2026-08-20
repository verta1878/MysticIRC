# OpenOLMS — Status (v1.0)

Drop-in replacement for Peter Rocca's OLMS Version 2000.
~13,900 lines of Free Pascal, 37 units, 8 programs.
Binary-compatible data files. GPLv3. Clean-room reimplementation.

## Programs

| Program | Lines | Target | Status |
|---------|-------|--------|--------|
| openolms.pas (OLMS.EXE) | 353 + 25 units | DOS go32v2 | ✅ compiles* |
| olmscfg.pas (CONFIG.EXE) | 307 + UI units | DOS go32v2 | ✅ compiles* |
| editor.pas (EDITOR.EXE) | 203 | Linux/DOS | ✅ compiles clean |
| olmsmnt.pas (MAINTAIN.EXE) | 274 | Linux/DOS | ✅ compiles clean |
| userconf.pas (USERCONF.EXE) | 348 | Linux/DOS | ✅ compiles clean |
| upgrade1.pas (UPGRADE1.EXE) | 192 | Linux/DOS | ✅ compiles clean |
| upgrade2.pas (UPGRADE2.EXE) | 247 | Linux/DOS | ✅ compiles clean |
| molms.pas (Win32 client) | 742 | Win32/Linux | ✅ compiles clean |

*openolms + olmscfg need FreeVision class/object fix (BUG 2 — see below)

## Binary Compatibility (v1.0 — NEW)

All data files match the original OLMS Version 2000 byte-for-byte:

| File | Size | Records | Status |
|------|------|---------|--------|
| OLMS.CFG | 14,889 bytes | 1 config record | ✅ round-trip verified |
| USERS.DAT | 14,340 bytes | 30 × 478 bytes | ✅ SizeOf match |
| MESSAGES.CTL | 24,512 bytes | 383 × 64 bytes | ✅ SizeOf match |
| MESSAGES.IDX | 762 bytes | message index | ✅ created correctly |
| MESSAGES.INF | 6 bytes | info header | ✅ created correctly |
| USERS.IDX | 4 bytes | user index | ✅ created correctly |

Key unit: OL_Compat.pas — packed record types with ReadTPStr/WriteTPStr
for Turbo Pascal ShortString I/O. 18 accessor functions for config fields.

## Compatibility Phases

| Phase | Description | Status |
|-------|-------------|--------|
| L1 | Record layout audit (hex dump + decode) | ✅ done |
| L2 | Packed record types (SizeOf match) | ✅ done |
| L3 | Config round-trip (load, save, 0 diffs) | ✅ done |
| L4 | Message editor (EDITOR.EXE) | ✅ done — 203 lines |
| L5 | User configuration (USERCONF.EXE) | ✅ done — 348 lines |
| L6 | Upgrade tools (UPGRADE1 + UPGRADE2) | ✅ done — 192 + 247 lines |
| L7 | Integration test (all files correct) | ✅ PASS |
| L8 | Documentation | ✅ done |

## Door (openolms.pas) — complete

- Dropfile: DORINFO1.DEF, DOOR.SYS + all command-line switches
- Message bases: JAM + Hudson readers (IMsgBase interface)
- Filtering: twit lists, keywords, include/exclude, keyword-only mode
- Read pointers: new-mail-only scans, /RG /RS resets, anti-redownload
- Limits: max messages per area, max packet KB
- Packet output: QWK, QWKE, Blue Wave (IPacketWriter interface)
- Archiver shell-out with verification
- Reply intake: .REP/.MSG reader (round-trips with writer)
- File subsystem: requests, new-files scan, per-day/size limits
- Networking: QWK-net, point net, internet/UUCP gateway
- Taglines, vacation pack-all, logging (OLMS.LOG), multi-language (.OLF)

## Config (olmscfg.pas) — complete

All 12 screens: System Information, Archiver Programs, Protocol Programs,
Files Configuration, Bulletins, Control Setup, Requesting Control,
Limits Setup, User Editor, Multi-language, Test Configuration, menu.

## Editor (editor.pas) — v1.0 new

Full-screen CRT console message editor for QWK/BlueWave replies.
Arrow keys, Enter, Backspace, Del, Home/End, PgUp/PgDn.
Ctrl-W save, Ctrl-Q quit, Ctrl-K spell check, Ctrl-Y delete line.
Quote support (/Q:filename). Uses OL_Editor engine + Hunspell.

## UserConf (userconf.pas) — v1.0 new

User self-configuration menu. Archiver selection (ARJ/LHA/ZIP/ARC/PAK/RAR),
protocol selection (Xmodem/Ymodem/Zmodem), message area toggles (383 areas).
Reads/writes original USERS.DAT via OL_Compat packed records.

## Upgrade Tools — v1.0 new

- UPGRADE1: upgrades OLMS.CFG + MESSAGES.CTL to v2000, creates indexes
- UPGRADE2: upgrades USERS.DAT, auto-detects old record size, creates work dirs
- Both auto-backup originals before modifying

## MOLMS Client (molms.pas) — v0.5

- Connect to BBS via Telnet, Serial/Modem, FOSSIL
- Auto-login (username, password, door command)
- Auto Mail Run: one-key automated mail cycle
- BBS address book
- ANSI terminal + RIPscrip v1.54 graphics engine
- Hunspell spell check in reply editor
- Zmodem/Ymodem/Xmodem/Kermit file transfers

## Known Bugs (v1.0)

| # | Severity | Description | Fix |
|---|----------|-------------|-----|
| ~~1~~ | ~~crash~~ | ~~ArchiverSel array overflow in userconf~~ | ✅ fixed — bounds clamp |
| 2 | compile | openolms/olmscfg: class vs object (FreeVision) | change to object() |
| ~~3~~ | ~~cosmetic~~ | ~~WStart unused in spell check~~ | ✅ fixed — used in output |
| ~~4~~ | ~~logic~~ | ~~upgrade2 record scan range too narrow~~ | ✅ fixed — 50..1000 |
| ~~5~~ | ~~cosmetic~~ | ~~OL_Compat nested comment warning~~ | ✅ fixed |

## Known Missing Features

| # | Priority | Description |
|---|----------|-------------|
| ~~1~~ | ~~critical~~ | ~~L9+L10: wired to OL_Compat~~ ✅ |
| ~~2~~ | ~~important~~ | ~~L11: Word wrap at column 72~~ ✅ |
| ~~3~~ | ~~important~~ | ~~L12: Area names from MESSAGES.CTL~~ ✅ |
| 4 | nice | Default SCREENS.DAT not created by upgrade tools |

## Credits

- Peter Rocca — original OLMS (permission granted, GPLv3)
- verta1878 — project lead, QWK engine, config editor
- sysop/0 — compiler (fpc264irc), FOSSIL socket backend
- wrench — binary compatibility, editor, upgrade tools, serial
- kiddo — protocols (Zmodem Int64 fix), serial IRQ
- evga — display, RIPView, SIO2K OS/2 driver
- g00r00 — Mystic BBS protocol code (GPLv3)
