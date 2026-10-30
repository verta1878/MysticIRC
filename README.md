# Mystic BBS 1.11IRC — Community Fork

> **GitHub:** https://github.com/verta1878/MysticIRC
>
> **Release: 2026-10-29** — Version 1.11IRC A5.
> v1 engine COMPLETE — zero stubs, all L0/L1 commands dispatched.
> ripengine 22,601 lines (viewport, state, UTF8Mode, SceneDone, EndScene).
> ripdraw 21,601 lines (24/24 BGI_WRAP, DrawPolygon, DrawBar3D, span FloodFill).
> riptext 13,689 lines (attributed text, UTF-8 aware, CHR vector fonts).
> ripicon 12,541 lines (64-slot cache, LoadPCX, LoadIMG, LoadTIF).
> riputf8.pas shared UTF-8 codec (CP437↔Unicode bidirectional).
> rip1exec 34,780 lines (L1 executor, End Scene, ReadScene, PutImage modes 0-4).
> RT154SRC verified — 42/42 parse, 34 exec, 3 stubs correct.
> RIPaint 674/674 decompiled source staged as reference.
> mterm v0.3: 2,009 lines — phonebook, capture, pacing, RIP auto-sense.
> mconfig v0.1. VIPEngine 323-line procedural wrapper.
> OpenOLMS released (mystic_molms/, 37 units, 8 programs).
> Built with **FPC 2.6.4irc r3.1+**. GPLv3.

Based on **Mystic BBS** GPL source by James Coyle (g00r00).
Maintained by verta1878, Ecstasy BBS, FTN 1:152/158.

## Team

| Handle | Role |
|--------|------|
| verta1878 | Project lead |
| sysop/0 | Compiler engineer, FPC, Tang Console, USB |
| bob | Compiler engineer, OpenWatcom, Glide, 3dfx drivers |
| evga | Display, Mystic, SIO rebuild |
| kiddo | Protocols, RIPscrip |
| wrench | Transport, FOSSIL, serial |
| hexadecimal | PCBoard, Cyclades |
| byte | Program discovery |
| DotMatrix | Documentation sourcing |
| fabric | FPGA, Voodoo 6 5000 Spinal |

## Directory Structure

```
mystic/                  BBS core (clean, no RIP)
mystic_test/             BBS core + RIP integration + A4 fixes
  mdl/                     Local copy of MDL (self-contained build)
mystic_ansiedit/         ANSI editor (ansiedit + PCBDraw support)
mystic_crypt/            CryptLib SSH/TLS example
mystic_mailer/           BINKP/FidoNet mailer
mystic_makemenu/         Menu builder
mystic_misdos/           DOS Waiting-For-Caller (modem/BinkP/local login)
  misdos.pas               WFC main loop — clock, modem watch, BinkP sniff
  misdos_commands.pas      Hot-key handlers (U/S/P/E/X/D/Q editors)
  misdos_screen.pas        ANSI screen loader + live clock/node fields
  wfc.ans                  80x25 CP437 WFC screen (classic 1.06 reconstruction)
mystic_modem/            Modem/FOSSIL front-end
mystic_molms/            OpenOLMS offline mail (37 units, 8 programs, GPLv3)
mystic_mterm/            mterm terminal emulator
  mterm.pas                Main terminal (44,201 bytes)
  mtrip.pas                RIP engine integration (35,044 bytes)
  mtripgfx.pas             RIP graphics rendering (29,722 bytes)
  mtcapture.pas            Capture/logging (ALT+C)
  mtphone.pas              Phonebook edit+validate
  + mtconn, mtconfig, mtserial, mtsound, mtxfer, mtterm
mystic_perl/             Perl DLL integration
mystic_ripview/          RIPView — Pascal RIP browser
  source/                  Main units + fonts/
    ripview.pas              Main viewer/browser (17,917 lines)
    ripengine.pas            Engine core (22,601 lines)
    ripdraw.pas              Drawing primitives (21,601 lines)
    riptext.pas              Text rendering, UTF-8 aware (13,689 lines)
    ripicon.pas              64-slot icon cache + LoadPCX/IMG/TIF (12,541 lines)
    ripwidgets.pas           19 UI widgets (7,529 lines)
    riputf8.pas              UTF-8 codec (CP437↔Unicode)
    + ripstate, riptextvar, ripmouse, ripbmp, ripdelta,
      riprender, ripbindec, riplayerdec, riptile, rip_compat
  source/v1/               v1 engine
    rip1exec.pas             L1 executor (34,780 lines)
    rip1parse.pas            L1 parser, 14 commands (5,431 lines)
  tools/                   Converter/test tools
  js-reference/            JavaScript RIPterm reference impl
mystic_sdl/              SDL2 graphical terminal
mystic_spell/            Hunspell spell check binding + SETUP.md
mystic_texteditor/       Text editor standalone
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
docs/                    Build documentation
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

## Key Features (1.11IRC A5)

- g00r00 1.10 A38 base with A39-A63 features ported
- g00r00 1.11 A1-A3 items: VAR records, TimerMS, FormatDate, Searchlight menus
- RIPscrip v1.54: v1 engine COMPLETE — zero stubs, 42/42 commands pixel-perfect
- End Scene (`!|#`): full state reset + SceneDone flag
- RT154SRC verified against RIPterm reference (42/42 parse, 34 exec)
- RIPaint 674/674 decompiled source as engine reference
- LoadIMG (GEM raster), LoadTIF (baseline TIFF) decoders in icon cache
- UTF-8 extension: riputf8.pas codec, Canvas.UTF8Mode, all text funcs aware
- Password MD5 hashing with auto-upgrade (bbs_crypt.pas)
- Hunspell spell check in FS editor
- Serial v1.1 + FOSSIL driver + IRQ ring buffer
- mterm terminal emulator (ANSI engine + RIP v1.54 client parser)
- OpenOLMS offline mail system (QWK/BlueWave/Hudson/JAM, 37 units)
- SDL_mixer audio (WAV/MID/MOD/MP3/OGG)
- Stale node detection, MIS shutdown fix, ANSI editor fix
- Zmodem >2GB file transfers (Int64)
- HS/Link bidirectional protocol (clean-room Pascal, 1067 lines)
- Embedded taskbar/tray icon (utrayit + mkicon)
- 20 MPL scripts, 237 functions documented
- Engine version: RIPSCRIP030002 (matches RIPtel 3.1 patched)

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
