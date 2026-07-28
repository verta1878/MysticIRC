# Mystic BBS 1.11IRC A4 — Community Fork

> **GitHub:** https://github.com/verta1878/mystic-bbs-irc
>
> **Release: 2026-07-28** — Version 1.11IRC A7.
> RIPscrip v1.54 support (42/42 commands, pixel-perfect).
> Built with **FPC 2.6.4irc r3.1+**. GPLv3.

Based on **Mystic BBS** GPL source by James Coyle (g00r00).
Maintained by verta1878, FTN 1:152/158.

## Team

| Handle | Role |
|--------|------|
| verta1878 | Project lead, FTN 1:152/158 |
| sysop/0 | serial.pas UART layer, architecture |
| evga | Free Pascal Compiler 2.6.4irc, RIP engines, MDL |
| kiddo | serial_irq.pas ISR, text rendering, MPL, chg2rip |
| wrench | fossil.pas, netfosdl.pas FOSSIL driver, netmodem2irc |

## Directory Structure

```
mystic/                  BBS core (clean, no RIP)
mystic_test/             BBS core + RIP integration (testing)
mdl/                     Mystic Development Library (52+ units)
mystic_rip/              RIPscrip — ALL RIP code lives here
  v1/                      RIPscrip v1.54 engine
  v2/                      RIPscrip v2.0 engine
  v3/                      RIPscrip v3.0 engine
  v4/                      RIPscrip v4.0 engine
  chg2rip.pas              ANSI→RIP converter (pixel-perfect, v2.3)
  ans2png.pas              ANSI→BMP renderer (pixel-perfect)
  ripviewer/               RIPView v1.0.0 — 42/42 cmds, CLI + FV TUI
    source/                  Pascal source (7 units, 1,656 lines)
    docs/                    ripjsapi.html (merged v1.54/v2.0/v3.0 specs)
    fonts/                   18 BGI + bitmap fonts
    icons/                   219 ICN/MSK/HIC files
    rips/                    259 test RIP files
    js-reference/            RIPtermJS source (read-only reference)
mystic_spell/            Hunspell spell check binding
mystic_crypt/            CryptLib SSH/TLS
mystic_sdl/              SDL2 graphical terminal
mystic_modem/            Modem/FOSSIL front-end
mystic_mailer/           BINKP/FidoNet mailer
examples/
  mterm/                   mterm terminal + OpenOLMS (28 files, 9,548 lines)
  serial/                  Serial v1.1 + FOSSIL driver (1,119 lines)
  door32/                  g00r00's Door32 library (d32.pas)
  thdproscan/              THD ProScan archive
  riptermJS/               RIPtermJS JavaScript viewer (Carl Gorringe, GPLv3)
  mkicon.pas               Pure Pascal ICO generator (186 lines)
  marc/                    MARC ZIP archiver + MP3/MP4 metadata
docs/                    Documentation
```

## BBS Binaries (18 Win32 PE32 i386)

| Binary | Status |
|--------|--------|
| mystic | ✅ |
| mis | ✅ |
| mplc | ✅ |
| mide | ✅ |
| mutil | ✅ |
| fidopoll | ✅ |
| marc | ✅ |
| maketheme | ✅ |
| mbbsutil | ✅ |
| install | ✅ |
| install_make | ✅ |
| nodespy | ✅ |
| qwkpoll | ✅ |
| mystpack | ✅ |
| 109to110 | ✅ |
| chg2rip | ✅ |
| ans2png | ✅ |
| ripview | ✅ |
| 20 MPL scripts | ✅ All compile |

## Key Features (1.11IRC A7)

- g00r00 1.11 A1-A3 base fully ported
- RIPscrip v1.54 (42/42 commands, pixel-perfect)
- RIPView CLI + Free Vision TUI viewer
- chg2rip/ans2png pixel-perfect converters
- Password MD5 hashing (auto-upgrade from plaintext)
- Hunspell spell check binding (runtime loaded)
- Serial v1.1: UART 16550, IRQ ring buffer, FOSSIL driver
- Zmodem >2GB file transfer (Int64 fix)
- MIS system tray icon (embedded resource)
- MIS clean shutdown (select-based polling)
- Stale node detection (5-min auto-reclaim)
- Active user warning in config mode
- maketheme cfgpath command
- MIDE help system (237 functions, mplfunc.txt)
- Searchlight-style lightbar menus (identical to 1.12)
- MPL: record VAR params, record function return, multi-dim arrays
- FOSSIL/serial: TIOFossil for DOS dial-up
- mterm terminal emulator + OpenOLMS offline reader
- mkicon pure Pascal ICO generator
- Door32 library (g00r00's d32.pas)

## Build

```bash
# Get the compiler
git clone https://github.com/verta1878/fpc264irc

# Build on Linux
./build-linux.sh

# Cross-compile for Win32
./build-win32.sh
```

## Platforms

| Platform | Status |
|----------|--------|
| x86_64-linux | ✅ Native |
| i386-win32 | ✅ Cross-compiled |
| i386-go32v2 (DOS) | ✅ Cross-compiled |
| i386-os2 | ✅ Working |
| i386-darwin | ✅ Needs clang + SDK |

## License

GNU General Public License v3. See `LICENSE`.

Copyright (C) 1997-2013 By James Coyle
Copyright (C) 2025-2026 IRC Fork: verta1878, sysop/0, evga, kiddo, wrench

## Links

- Compiler: https://github.com/verta1878/fpc264irc
- RIPtermJS: https://github.com/cgorringe/RIPtermJS
