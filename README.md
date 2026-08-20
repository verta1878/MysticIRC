# Mystic BBS 1.11IRC — Community Fork

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
| kiddo | serial_irq.pas ISR, text rendering, MPL, ans2rip |
| wrench | fossil.pas, netfosdl.pas FOSSIL driver, netmodem2irc |
| hexadecimal | PCBoard 15.4 Revival |

## Directory Structure

```
mystic/                  BBS core (clean, no RIP)
mystic_test/             BBS core + RIP integration + A4 fixes
  mdl/                     Local copy of MDL (self-contained build)
mdl/                     Mystic Development Library (67 units)
mystic_sdl/              SDL2 graphical terminal
mystic_rip/              RIPscrip engines + converters
  v1/                      RIPscrip v1.54 engine (evga/wrench)
  v2/                      RIPscrip v2.0 engine (evga/wrench)
  v3/                      RIPscrip v3.0 engine (evga/wrench)
  v4/                      RIPscrip v4.0 engine (evga/wrench)
  ans2rip.pas              ANSI→RIP converter (pixel-perfect, -p flag)
  ans2png.pas              ANSI→BMP renderer (pixel-perfect)
  ripscrip-irc-whitepaper.htm  Our RIP implementation whitepaper
mystic_spell/            Hunspell spell check binding + SETUP.md
mystic_crypt/            CryptLib SSH/TLS example
mystic_modem/            Modem/FOSSIL front-end
mystic_mailer/           BINKP/FidoNet mailer
mystic_ansiedit/         ANSI editor cfg
mystic_texteditor/       Text editor standalone
examples/
  ripviewer/               RIPView v1.0.0 — evga's Pascal viewer (42/42 cmds)
    source/                  Pascal source (7 units, 1,656 lines)
    fonts/                   18 BGI + bitmap fonts
    icons/                   219 ICN/MSK/HIC files
    rips/                    259 test RIP files
    ripscrip-irc-whitepaper.htm  Our RIP implementation whitepaper
  riptermJS/               RIPtermJS (Carl Gorringe, GPLv3) zip + v3.0 txt
  ripterm154/              RIPterm 1.54 DOS binary (Carl Gorringe archive)
  mterm/                   mterm terminal + OpenOLMS (44 files)
  serial/                  Serial v1.1 + FOSSIL driver (5 files)
  door32/                  Door32 BBS Door Kit (g00r00, ONiX, SqZ) zip
  utrayit/                 Console tray unit + mkicon ICO generator
  thdpro/                  THD ProScan (original + clean room remake)
  trapgate/                TrapGate FTN Mailer (43 Pascal, ZLib128, 4 releases)
  naplps/                  NAPLPS specs (NAP.txt, FIPS121 PDF)
  marc/                    MARC ZIP archiver + MP3/MP4 metadata
  hslink-src/              HS/Link protocol source
  ansilove-src/            Ansilove (VGA font source)
  rez2ans-next/            REZ to ANSI converter
  ciadraw/                 CIA Draw ANSI tool
  libs/                    Runtime libs (hunspell, SDL2, cryptlib) per platform
docs/                    Documentation
attic/                   Retired code and archives
  docs-a40/                AreaFix implementation checklist
  docs-os2-linux-toolchain/  OS/2 cross-compile docs (sysop/0)
  docs-patches/            Old patch notes
  toolchain-src.zip        emxbind + binutils + ld64 source
out-linux/               Linux build output
out-win32/               Win32 build output
out-dos/                 DOS build output
out-os2/                 OS/2 build output
out_darwin/              macOS build output
out-bsd/                FreeBSD/OpenBSD/NetBSD build output
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
| ans2rip | ✅ |
| ans2png | ✅ |

## Key Features (1.11IRC A4)

- g00r00 1.10 A38 base with A39-A63 features ported
- g00r00 1.11 A1-A3 items: VAR records, TimerMS, FormatDate, Searchlight menus
- RIPscrip v1.54: 9 RIP engines, RIPView 42/42 commands pixel-perfect
- Password MD5 hashing with auto-upgrade (bbs_crypt.pas)
- Hunspell spell check in FS editor
- Serial v1.1 + FOSSIL driver + IRQ ring buffer
- mterm terminal + OpenOLMS offline mail reader
- MIS 1.12 rebuild plan (tabbed UI, ASCII art header, ESC menu)
- Stale node detection, MIS shutdown fix, ANSI editor fix
- Zmodem >2GB file transfers (Int64)
- HS/Link bidirectional protocol (clean-room Pascal, 1067 lines)
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
| x86_64-freebsd | ✅ Cross-compiled (fpc264irc) |

## License

GNU General Public License v3. See `LICENSE`.

## Links

- Compiler: https://github.com/verta1878/fpc264irc
- RIPtermJS: https://github.com/cgorringe/RIPtermJS
- PCBoard 15.4 Revival: https://github.com/verta1878/pcbrevival
- RIPView scene release: https://github.com/cwensley/pablodraw/issues/136
