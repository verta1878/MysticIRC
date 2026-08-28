# Mystic BBS 1.11IRC — Community Fork

> **GitHub:** https://github.com/verta1878/mysticbbsirc
>
> **Release: 2026-08-27** — Version 1.11IRC A4.
> RIPscrip v1.54 support (42/42 commands, pixel-perfect).
> Built with **FPC 2.6.4irc r3.1+**. GPLv3.

Based on **Mystic BBS** GPL source by James Coyle (g00r00).
Maintained by verta1878, Ecstasy BBS, FTN 1:152/158.

## Directory Structure
## Team

| Handle | Role |
|--------|------|
| verta1878 | Project lead |
| sysop/0 | Compiler engineer, FPC, Tang Console, USB |
| bob | Compiler engineer, OpenWatcom, Glide, 3dfx drivers |
| evga | Display, Mystic, SIO rebuild |
| kiddo | Protocols, RIPscrip |
| wrench | Transport, FOSSIL, DVI/HDMI |
| hexadecimal | PCBoard, Cyclades |
| byte | Program discovery |
| DotMatrix | Documentation sourcing |

```
mdl/                     Mystic Development Library (79 units)
  m_rip/                   RIP engine + tools
    v1/                      RIPscrip v1.54 engine (kiddo)
    v2/                      RIPscrip v2.0 engine (kiddo)
    v3/                      RIPscrip v3.0 engine (kiddo)
    v4/                      RIPscrip v4.0 engine (kiddo)
    rip_canvas.pas           Canvas/surface primitives
    rip_render.pas           BMP/screen renderer
    rip_surface.pas          Software raster backend
    rip_term.pas             Terminal integration
    rip_window.pas           Viewport management
    ans2rip.pas              ANSI→RIP converter
    ans2png.pas              ANSI→BMP renderer
    ripmake.pas              RIP file builder
    mkicons.pas              Icon generator
mystic/                  BBS core (clean, no RIP)
mystic_test/             BBS core + RIP integration + A4 fixes
  mdl/                     Local copy of MDL (self-contained build)
mystic_ansiedit/         ANSI editor (ansiedit + PCBDraw support)
mystic_mterm/            mterm terminal emulator (85 files)
mystic_molms/            MOLMS offline mail system (36 files)
mystic_ripview/          RIPView v1.0.0 — Pascal RIP viewer (12 source, 565 total)
mystic_sdl/              SDL2 graphical terminal
mystic_spell/            Hunspell spell check binding + SETUP.md
mystic_crypt/            CryptLib SSH/TLS example
mystic_modem/            Modem/FOSSIL front-end
mystic_mailer/           BINKP/FidoNet mailer
mystic_texteditor/       Text editor standalone
mystic_misdos/           MIS DOS version
mystic_perl/             Perl DLL integration
examples/
  ripart/                  RIP art, fonts, icons (single source of truth)
    art/                     226 RIP files (16colo.rs corpus + test suite)
    fonts/                   18 BGI + bitmap fonts (CHR/FNT)
    icons/                   222 ICN/MSK/HIC icon files
  serial/                  Serial v1.1 + FOSSIL driver (wrench)
  riptermJS/               RIPtermJS (Carl Gorringe, GPLv3)
  door32/                  Door32 BBS Door Kit (g00r00, ONiX, SqZ)
  utrayit/                 Console tray unit + mkicon ICO generator
  thdpro/                  THD ProScan (original + clean room remake)
  trapgate/                TrapGate FTN Mailer (Pascal, ZLib128)
  naplps/                  NAPLPS specs (NAP.txt, FIPS121 PDF)
  marc/                    MARC ZIP archiver + MP3/MP4 metadata
  hslink-src/              HS/Link protocol source
  ansilove-src/            Ansilove (VGA font source)
  rez2ans-next/            REZ to ANSI converter
  ciadraw/                 CIA Draw ANSI tool
  sdl_demo/                SDL2 demo programs
  mpl/                     MPL script examples
  shatranj/                Shatranj chess engine
todo/                    Documentation + phase tracking
  ripscrip/                RIP specs (v1.54-v3.2, riplib, historical)
historical/
  ripterm154/              RIPterm 1.54 DOS binary (Carl Gorringe archive)
attic/                   Retired code and archives
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
- RIPscrip v1.54: RIP engine v1-v4, RIPView 42/42 commands pixel-perfect
- Password MD5 hashing with auto-upgrade (bbs_crypt.pas)
- Hunspell spell check in FS editor
- Serial v1.1 + FOSSIL driver + IRQ ring buffer
- mterm terminal emulator (ANSI engine + RIP v1.54 client parser)
- MOLMS offline mail system (QWK/BlueWave/Hudson/JAM)
- SDL_mixer audio (WAV/MID/MOD/MP3/OGG)
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

# Build mterm
cd mystic_mterm && fpc -Mdelphi -Fu../mdl -Fi../mdl mterm.pas

# Build ansiedit
cd mystic_ansiedit && fpc -Mdelphi -Fu../mdl -Fi../mdl ansiedit.pas
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
