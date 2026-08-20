# mterm — Mystic Terminal + MOLMS Offline Mail

DOS-first RIP/ANSI terminal emulator with integrated offline mail
reader. One program: dial the BBS, transfer files, read mail offline.

## Programs

| Program | What |
|---------|------|
| mterm | Terminal emulator + offline mail client |
| openolms_dos | BBS-side mail door (pure DOS, ANSI) |
| olmscfg | Configuration editor (FV TUI) |
| olmsmnt | Maintenance CLI |

## Build

```
fpc -Fumterm mterm.pas
```

## Terminal Features

- ANSI CSI/SGR terminal emulation (full color, cursor, scroll)
- RIPscrip v1.54 command parser (42 graphics commands)
- Telnet client (TCP via sockets.pp)
- Serial/modem with AT dialer (DOS: COM1-COM4, IRQ, FIFO)
- FOSSIL INT 14h support (DOS)
- Phonebook with saved BBS connections
- File transfer: Zmodem (>2GB fix), Ymodem, Xmodem, Kermit
- Session capture to log file
- 1000-line scrollback buffer
- Load .ans/.rip files offline
- Persistent settings (mterm.cfg)

## MOLMS — Offline Mail

Connect to a BBS, download QWK packets via Zmodem, read mail offline,
compose replies with spell check, upload .REP packets on next call.

Flow:
```
Connect -> auto-login -> enter mail door -> Zmodem recv .QWK
  -> disconnect -> unpack QWK -> READ OFFLINE -> compose replies
  -> spell check -> pack .REP -> reconnect -> Zmodem send .REP
```

Supported formats: QWK, QWKE, BlueWave.
Message bases: Hudson (QuickBBS/RA), JAM.
Filtering: per-user keywords (include/exclude) + twit list.

Based on Peter Rocca's OLMS (Multiboard Communications Centre,
1994-1998). Clean-room reimplementation with author's permission.

## Spell Check

Hunspell integration via dynamic loading. If the library is present,
spell check works. If not, it's silently disabled.

Requirements:
- Hunspell library (libhunspell32.dll / libhunspell.so / libhunspell.dylib)
- Dictionary files (dictionary.aff + dictionary.dic) in data path

See SPELL_SETUP.md for detailed installation instructions.

## Source Files

### Terminal Core

| File | Lines | What |
|------|-------|------|
| mterm.pas | 282 | FV TUI application shell |
| mtterm.pas | 419 | Terminal view — ANSI parser, scrollback, RIP detect |
| mtrip.pas | 259 | RIPscrip v1.54 command dispatcher (42 commands) |
| mtconn.pas | 164 | Connection manager — Telnet, serial, FOSSIL |
| mtserial.pas | 125 | AT modem dialer (DOS, COM1-COM4) |
| mtphone.pas | 118 | Phonebook — saved BBS connections |
| mtxfer.pas | 110 | File transfer framework |
| mtcapture.pas | 74 | Session logging to file |
| mtconfig.pas | 118 | Persistent settings (mterm.cfg) |

### Protocol Stack (g00r00, GPLv3)

| File | Lines | What |
|------|-------|------|
| m_prot_base.pas | 894 | Protocol base class + state machine |
| m_prot_zmodem.pas | 2530 | Zmodem — Int64 fix for >2GB transfers |
| m_protocol_xmodem.pas | 357 | Xmodem 1K/CRC — checksum + CRC-16 |
| m_protocol_ymodem.pas | 307 | Ymodem batch — Block 0 file info |
| m_protocol_kermit.pas | 565 | Kermit — sliding window, 7-bit safe |
| m_protocol_queue.pas | 170 | Transfer queue manager |
| m_crc.pas | 173 | CRC-16 CCITT + CRC-32 tables |

### OpenOLMS — Offline Mail Library

| File | Lines | What |
|------|-------|------|
| OL_QWK.pas | 259 | QWK packet format — 128-byte blocks, CONTROL.DAT, NDX |
| OL_Config.pas | 176 | OLMS.CFG configuration records |
| OL_DropFile.pas | 275 | DORINFO1.DEF + DOOR.SYS parser |
| OL_MsgCtl.pas | 195 | MESSAGES.CTL conference control (64-byte records) |
| OL_Users.pas | 141 | Per-user settings + message pointers |
| OL_Hudson.pas | 328 | Hudson message base (MSGHDR/MSGTXT/MSGIDX/MSGINFO) |
| OL_JAM.pas | 425 | JAM message base (JHR/JDT/JDX/JLR + CRC-32) |
| OL_Packer.pas | 423 | QWK packer (scan->pack->ZIP) + REP unpacker |
| OL_Filter.pas | 275 | Keyword filtering (include/exclude) + twit list |
| OL_BlueWave.pas | 199 | BlueWave packet format (INF/MIX/FTI/DAT/UPL) |
| OL_MDL.pas | 225 | Mystic Development Library interface stub |
| OL_Editor.pas | 229 | Reply editor — word wrap, quoting, spell check |
| mt_spell.pas | 134 | Hunspell dynamic loader (Win/Linux/macOS) |

## Architecture

```
mterm (FV TUI)
  |-- Terminal View (ANSI/RIP rendering)
  |-- Connection (Telnet/Serial/FOSSIL)
  |-- File Transfer (Zmodem/Ymodem/Xmodem/Kermit)
  |-- Phonebook (saved BBS list)
  |-- Capture (session logging)
  '-- MOLMS (offline mail)
       |-- QWK packer/unpacker
       |-- Hudson message base reader
       |-- JAM message base reader
       |-- Keyword filter + twit list
       |-- Reply editor + spell check
       '-- BlueWave support
```

## License

GPLv3 — GNU General Public License v3.0

Protocol code (m_prot_*.pas) copyright 1997-2013 James Coyle (g00r00),
GPLv3. OpenOLMS clean-room reimplementation with Peter Rocca's
permission.

## Credits

| Who | What |
|-----|------|
| verta1878 | Project lead, architect |
| sysop/0 | Terminal, connection, serial UART, compiler |
| evga | Display, RIPView, Mystic monitor |
| kiddo | Serial IRQ, ring buffer, protocols |
| wrench | Network architecture, OpenOLMS |
| g00r00 | Mystic BBS (GPLv3) |
| Peter Rocca | Original OLMS (MCC, 1994-1998) |
