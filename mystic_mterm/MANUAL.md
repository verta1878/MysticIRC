# mterm v0.1 — User Manual

## Programs

| Program | What |
|---------|------|
| `mterm` | Terminal emulator + offline mail client |
| `molms` | Standalone MOLMS offline mail reader |

## Quick Start

```
mterm              — launch terminal
```

## Keyboard — Terminal Mode

| Key | Action |
|-----|--------|
| F2 | Connect (telnet) |
| F3 | Disconnect |
| F4 | Phonebook |
| F9 | Toggle RIP/ANSI |
| F10 | Menu bar |
| Alt-A | View ANSI/RIP file offline |
| Alt-C | Toggle capture → mterm.log |
| Alt-S | Send file |
| Alt-R | Receive file |
| Alt-O | Settings |
| Alt-X | Exit |
| PgUp/PgDn | Scroll back/forward |

## Keyboard — MOLMS Mail Mode

| Key | Action |
|-----|--------|
| Alt-C | Connect to BBS |
| Alt-Q | Download QWK packet |
| Alt-U | Upload REP packet |
| Alt-M | Auto mail run (full cycle) |
| F4 | BBS list |
| Alt-N | Next message |
| Alt-P | Previous message |
| Alt-R | Reply |
| Alt-F | Search messages |

## Connecting

### Telnet
Press F2 → enter host + port → OK.

### Phonebook
Press F4 → select BBS → Connect. Entries saved in `mterm.phn`.

### Serial/Modem (DOS)
Compile with `-dGO32V2`. COM1-COM4, IRQ-driven receive, AT dialer.
Modem init: ATZ, baud rate in Settings.

### FOSSIL (DOS)
For FOSSIL-aware doors and BBS software.

## ANSI Terminal

Fully implemented:
- Cursor: Up/Down/Left/Right, Position, Save/Restore
- Colors: 16 foreground (8 + bold), 8 background
- Attributes: Bold, Blink, Reverse, Reset
- Screen: Clear, Clear to EOL
- 1000-line scrollback, 80×25 display

## RIP Graphics

Toggle with F9. 640×350 pixel canvas with EGA 16-color palette.

Rendering engine (`mtripgfx.pas`):
- Line (Bresenham), Rectangle, Bar (filled)
- Circle (midpoint), Ellipse, Filled Ellipse
- Arc, Flood Fill (stack-based), Pixel
- Text output, BMP export, text-mode approximation

37 RIPscrip v1.54 commands parsed and rendered.

## File Transfer

| Protocol | Lines | Features |
|----------|-------|----------|
| Zmodem | 2,530 | CRC-32, streaming, crash recovery, >2GB (Int64 fix) |
| Ymodem | 307 | Batch transfer, Block 0 file info, Int64 |
| Xmodem | 357 | 1K blocks, CRC-16 mode |
| Kermit | 565 | Sliding window, 7-bit prefix encoding |

## Offline Mail (MOLMS)

**Complete offline mail workflow:**

```
Connect → auto-login → enter mail door → Zmodem recv .QWK
  → disconnect → unpack QWK → READ OFFLINE → compose replies
  → spell check → pack .REP → reconnect → Zmodem send .REP
```

### Auto Mail Run (Alt-M)
One-key automated mail cycle: connect, login, download QWK,
disconnect, then reconnect and upload REP when replies are ready.

### Supported Formats
- QWK packets (128-byte blocks, CONTROL.DAT, NDX)
- QWKE extended format
- BlueWave packets (INF/MIX/FTI/DAT/UPL)
- Hudson message bases (MSGHDR/MSGTXT/MSGIDX/MSGINFO)
- JAM message bases (JHR/JDT/JDX/JLR + CRC-32)

### Reply Editor
- Word wrap at column 72
- Quote prefix (initials + ">")
- Hunspell spell check (if available)

### Message Filtering
- Per-user keyword include/exclude lists
- Twit list (ignore specific senders)
- Per-conference filtering

## Spell Check

Optional. Requires Hunspell:
- Windows: `libhunspell32.dll` in mterm directory
- Linux: `libhunspell.so` (`apt install libhunspell-dev`)
- Dictionary: `dictionary.aff` + `dictionary.dic` in data path

Without Hunspell, everything works — spell check silently disabled.
See `SPELL_SETUP.md` for setup details.

## Settings

Stored in `mterm.cfg`:
- Terminal type: ANSI / RIP / Auto
- Local echo, line wrap
- Scrollback lines
- Baud rate, COM port, modem init string
- Download path

## Building

```bash
fpc mterm.pas          # Linux — terminal
fpc molms.pas          # Linux — standalone mail client

ppc386 -Tgo32v2 -dGO32V2 mterm.pas   # DOS
ppc386 -Twin32 mterm.pas              # Windows
```

## Source Files (33 units, 11,310 lines)

### Terminal (9 units)
mterm, mtterm, mtrip, mtripgfx, mtconn, mtserial, mtphone, mtxfer, mtcapture, mtconfig

### Protocols (7 units)
m_prot_base, m_prot_zmodem, m_protocol_xmodem, m_protocol_ymodem, m_protocol_kermit, m_protocol_queue, m_crc

### OpenOLMS (13 units)
OL_QWK, OL_Config, OL_DropFile, OL_MsgCtl, OL_Users, OL_Hudson, OL_JAM, OL_Packer, OL_Filter, OL_BlueWave, OL_MDL, OL_Editor, OL_Transfer

### Standalone
molms (MOLMS client), mt_spell (Hunspell)

## Credits

| Who | What |
|-----|------|
| verta1878 | Architect |
| sysop/0 | Terminal, serial, compiler |
| evga | Display, RIPView |
| kiddo | Serial IRQ, ring buffer, protocols |
| wrench | Network, OpenOLMS |
| g00r00 | Mystic BBS (GPLv3) |
| Peter Rocca | Original OLMS (1994-1998) |

## License

GPLv3
