# OpenOLMS — Open Offline Mail System

Clean-room reimplementation of Peter Rocca's OLMS (Offline Mail System,
Version 2000) in Free Pascal with ANSI/RIP rendering.

GPLv3 — Copyright (C) 2026 verta1878, sysop/0, wrench, kiddo, evga.
No original source code used. Reimplemented from published documentation.

## What It Does

A QWK/QWKE/BlueWave compatible offline mail system for BBS. Two sides:

**BBS side (door):** scans message areas, packs QWK, accepts REP uploads.
**User side (client):** connects to BBS, downloads QWK via Zmodem, reads
mail offline with ANSI/RIP rendering, composes replies with spell check,
uploads .REP.

## Programs (8)

| Binary | Source | Lines | What |
|--------|--------|-------|------|
| OLMS.EXE | openolms.pas | 436 | Main BBS door — QWK/QWKE/BlueWave offline mail |
| CONFIG.EXE | olmscfg.pas | 307 | Configuration editor (12 screens, FV TUI) |
| EDITOR.EXE | editor.pas | 661 | Standalone message editor (CRT, word wrap col 72) |
| MAINTAIN.EXE | olmsmnt.pas | 1135 | Database maintenance/packing |
| USERCONF.EXE | userconf.pas | 376 | User self-configuration (archiver, protocol, areas) |
| UPGRADE1.EXE | upgrade1.pas | 245 | Config + message area upgrade to v2000 |
| UPGRADE2.EXE | upgrade2.pas | 247 | User database upgrade to v2000 |
| MOLMS.EXE | molms.pas | 2602 | Win32 offline mail client (bonus — connect, read, reply) |

## MOLMS — The Offline Mail Client

Not a door — the user's program. Complete offline mail workflow:

```
Connect -> auto-login -> enter mail door -> Zmodem recv .QWK
  -> disconnect -> unpack QWK -> READ OFFLINE -> compose replies
  -> spell check -> pack .REP -> reconnect -> Zmodem send .REP
```

Auto Mail Run (Alt-M): one key does the full cycle.

Features: BBS address book, area navigation (Tab/Shift-Tab),
message threading, keyword search, ANSI/RIP message rendering,
reply editor with quoting and Hunspell spell check.

## DOS Door (openolms_dos.exe)

Classic BBS door. Reads DORINFO1.DEF or DOOR.SYS. ANSI menus.

```
openolms              interactive mode
openolms /D           auto download
openolms /U           auto upload
openolms /RG          reset all area pointers
openolms /RS          reset selected area pointers
openolms /RG=50       reset back 50 messages
```

## Formats

| Format | Read | Write |
|--------|------|-------|
| QWK | yes | yes |
| QWKE | planned | planned |
| BlueWave | yes | yes |

| Message Base | Read |
|-------------|------|
| Hudson (QuickBBS/RA) | yes |
| JAM | yes |
| Mystic (via MDL) | stub |

## Features

- QWK/BlueWave packet packing and unpacking
- Hudson and JAM message base reading
- ANSI terminal emulation (CSI/SGR, 16 color, cursor, scrollback)
- RIPscrip v1.54 graphics (640x350 EGA canvas, 42 commands)
- Per-user keyword filtering (include/exclude mode)
- Twit list (blocked senders)
- Per-user message pointers with reset (/RG, /RS, /RG=N)
- DORINFO1.DEF and DOOR.SYS drop file parsing
- Telnet, Serial/Modem, FOSSIL connections
- Zmodem (>2GB, Int64 fix), Ymodem, Xmodem, Kermit transfers
- BBS address book with auto-login
- Reply editor with word wrap at column 72
- Quote prefixing (author initials + ">")
- Hunspell spell check (dynamic loading, optional)
- Session capture to log file
- Phonebook with saved connections

## Source Files (37 units)

### OpenOLMS Core (13 units)

| File | Lines | What |
|------|-------|------|
| OL_QWK.pas | 259 | QWK packet format (128-byte blocks, CONTROL.DAT, NDX) |
| OL_Config.pas | 176 | OLMS.CFG configuration records |
| OL_DropFile.pas | 275 | DORINFO1.DEF + DOOR.SYS drop file parser |
| OL_MsgCtl.pas | 195 | MESSAGES.CTL conference control (64-byte records) |
| OL_Users.pas | 141 | Per-user settings + message pointers |
| OL_Hudson.pas | 328 | Hudson message base (MSGHDR/MSGTXT/MSGIDX/MSGINFO) |
| OL_JAM.pas | 425 | JAM message base (JHR/JDT/JDX/JLR + CRC-32) |
| OL_Packer.pas | 423 | QWK packer + REP unpacker |
| OL_Filter.pas | 275 | Keyword filtering (include/exclude) + twit list |
| OL_BlueWave.pas | 199 | BlueWave format (INF/MIX/FTI/DAT/UPL) |
| OL_Transfer.pas | 281 | Automated mail run (connect, login, download, upload) |
| OL_Editor.pas | 231 | Reply editor — word wrap, quoting, spell check |
| OL_MDL.pas | 225 | Mystic Development Library interface stub |

### ANSI / RIP Rendering (4 units)

| File | Lines | What |
|------|-------|------|
| mtterm.pas | 419 | ANSI CSI/SGR terminal — parser, scrollback, color |
| mtrip.pas | 267 | RIPscrip v1.54 command dispatcher (42 commands) |
| mtripgfx.pas | 409 | 640x350 EGA pixel canvas — line, circle, fill, BMP |
| mtcapture.pas | 74 | Session capture to log file |

### Connection + Transfer (12 units)

| File | Lines | What |
|------|-------|------|
| mtconn.pas | 164 | Connection manager — Telnet, Serial, FOSSIL |
| mtserial.pas | 125 | AT modem dialer (DOS COM1-COM4) |
| mtphone.pas | 136 | Phonebook — saved BBS connections |
| mtxfer.pas | 110 | File transfer framework |
| mtconfig.pas | 118 | Persistent settings |
| m_prot_base.pas | 894 | Protocol base class + state machine |
| m_prot_zmodem.pas | 2530 | Zmodem — Int64 fix for >2GB transfers |
| m_protocol_xmodem.pas | 357 | Xmodem 1K/CRC |
| m_protocol_ymodem.pas | 307 | Ymodem batch |
| m_protocol_kermit.pas | 565 | Kermit sliding window |
| m_protocol_queue.pas | 170 | Transfer queue manager |
| m_crc.pas | 173 | CRC-16 CCITT + CRC-32 tables |

### Spell Check (2 units)

| File | Lines | What |
|------|-------|------|
| mt_spell.pas | 179 | Hunspell dynamic loader (Win/Linux/macOS) |
| OL_Editor.pas | 231 | Reply editor with spell check integration |

### Programs (8)

| File | Lines | What |
|------|-------|------|
| openolms.pas | 436 | Main BBS door (FV TUI) |
| openolms_dos.pas | 353 | DOS door wrapper (ANSI menus) |
| olmscfg.pas | 307 | Configuration editor (FV TUI) |
| editor.pas | 661 | Standalone message editor (CRT) |
| olmsmnt.pas | 1135 | Database maintenance |
| userconf.pas | 376 | User self-configuration |
| upgrade1.pas | 245 | Config + area upgrade |
| upgrade2.pas | 247 | User database upgrade |
| molms.pas | 2602 | Win32 offline mail client |

### DOS Door Support (1 unit)

| File | Lines | What |
|------|-------|------|
| OL_ANSI.pas | 244 | Pure ANSI console output for DOS doors |

## Architecture

```
BBS Side:                           User Side:

openolms_dos.exe                    MOLMS (molms.exe)
  |                                   |
  |-- Drop file parser                |-- Connect (Telnet/Serial/FOSSIL)
  |-- Message base reader             |-- Auto-login + enter door
  |   (Hudson / JAM)                  |-- Zmodem receive .QWK
  |-- QWK packer                      |-- ANSI/RIP message rendering
  |-- REP unpacker                    |-- Reply editor + spell check
  |-- Keyword filter                  |-- REP packer
  |-- Area selection                  |-- Zmodem send .REP
  '-- ANSI menus                      '-- BBS address book + phonebook
```

## Data Files

| File | Format | What |
|------|--------|------|
| OLMS.CFG | binary | Main configuration |
| MESSAGES.CTL | binary, 64-byte records | Conference area list |
| USERS.DAT | binary | Per-user settings |
| *.KEY | text | Keyword filter (one per user) |
| *.TWT | text | Twit list (one per user) |
| *.QWK | ZIP archive | Downloaded mail packet |
| *.REP | ZIP archive | Upload reply packet |
| DORINFO1.DEF | text, 12 lines | BBS drop file |
| DOOR.SYS | text, 20 lines | BBS drop file (PCBoard) |
| mterm.cfg | binary | Terminal settings |
| mterm.phn | binary | Phonebook entries |

## Docs

| File | What |
|------|------|
| README.md | This file |
| MANUAL.md | User manual — keyboard, connecting, formats, building |
| OLMS_CFG_FORMAT.md | OLMS.CFG binary format documentation |
| SPELL_SETUP.md | Hunspell installation guide |
| index.htm | Color-coded documentation index |

## Credits

| Who | What |
|-----|------|
| Peter Rocca | Original OLMS author (MCC, 1994-1998) |
| verta1878 | Project lead, architecture |
| Leslie Given | Co-correspondence for author permission |
| sysop/0 | Terminal, serial UART, compiler |
| evga | Display, RIPView |
| kiddo | Serial IRQ, ring buffer, protocols |
| wrench | Network architecture, OpenOLMS reimplementation |
| g00r00 | Mystic BBS, protocol code (GPLv3) |

## License

GPLv3 — GNU General Public License v3.0

Clean-room reimplementation from published documentation only.
No decompilation, no original source code used.

Original OLMS: proprietary shareware ($25), Copyright Peter Rocca,
Multiboard Communications Centre, 1994-1998, Ontario Canada.
OpenOLMS created with author's permission.
