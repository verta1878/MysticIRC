# Mystic BBS 1.11IRC A3 — Community Fork

> **GitHub:** https://github.com/verta1878/mystic-bbs-irc
>
> **Release: 2026-07-28** — Version 1.11IRC A4.
> RIPscrip v1.54 support (42/42 commands, pixel-perfect).
> Built with **FPC 2.6.4irc r3.1+**. GPLv3.

Based on **Mystic BBS** GPL source by James Coyle (g00r00).
Maintained by verta1878, Ecstasy BBS, FTN 1:152/158.

## Team

| Handle | Role |
|--------|------|
| verta1878 | Project lead, Ecstasy BBS FTN 1:152/158 |
| sysop/0 | serial.pas UART layer, architecture |
| evga | Free Pascal Compiler 2.6.4irc, RIP engines, MDL |
| kiddo | serial_irq.pas ISR, text rendering, MPL, chg2rip |
| wrench | fossil.pas, netfosdl.pas FOSSIL driver, netmodem2irc |

## Directory Structure

```
mystic/                  BBS core (clean, no RIP)
mystic_test/             BBS core + RIP integration + A4 fixes
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
mystic_crypt/            CryptLib SSH/TLS example
mystic_sdl/              SDL2 graphical terminal
mystic_modem/            Modem/FOSSIL front-end
mystic_mailer/           BINKP/FidoNet mailer
mystic_misdos/           DOS MIS
examples/
  mterm/                   mterm terminal + OpenOLMS (38 files, 11,721 lines)
  serial/                  Serial v1.1 + FOSSIL driver (4 files, 1,119 lines)
  door32/                  g00r00's Door32 library (d32.pas)
  utrayit/                 Console tray unit + mkicon ICO generator
  thdproscan/              THD ProScan archive
  riptermJS/               RIPtermJS JavaScript viewer (Carl Gorringe, GPLv3)
  marc/                    MARC ZIP archiver + MP3/MP4 metadata
  hslink-src/              HS/Link protocol (clean-room Pascal port)
  ansilove-src/            Ansilove (VGA font source)
docs/                    Documentation
attic/                   Retired code
out-linux/               Linux build output
out-win32/               Win32 build output
out-dos/                 DOS build output
out-os2/                 OS/2 build output
out_darwin/              macOS build output
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
| install | ✅ |
| mbbsutil | ✅ |
| nodespy | ✅ |
| qwkpoll | ✅ |
| mystpack | ✅ |
| maketheme | ✅ |
| install_make | ✅ |
| 109to110 | ✅ |
| ripview | ✅ |
| chg2rip | ✅ |
| ans2png | ✅ |

## Key Features (1.11IRC A4)

- g00r00 1.10 A38 base with A39-A63 features ported
- g00r00 1.11 A1-A3 items: VAR records, TimerMS, FormatDate, Searchlight menus
- RIPscrip v1.54: RIPView 42/42 commands pixel-perfect
- Password MD5 hashing with auto-upgrade (bbs_crypt.pas)
- Hunspell spell check in FS editor
- Serial v1.1 + FOSSIL driver + IRQ ring buffer
- mterm terminal + OpenOLMS offline mail reader
- Stale node detection, MIS shutdown fix, ANSI editor fix
- Zmodem >2GB file transfers (Int64)
- Embedded taskbar/tray icon (utrayit + mkicon)
- 20 MPL scripts, 237 functions documented

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
| i386-os2 | ✅ EMX |
| i386-darwin | ✅ Needs clang + SDK |

## License

GNU General Public License v3. See `LICENSE`.

## Links

- Compiler: https://github.com/verta1878/fpc264irc
- RIPtermJS: https://github.com/cgorringe/RIPtermJS
