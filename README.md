# Mystic BBS 1.11IRC — Community Fork

> **GitHub:** https://github.com/verta1878/mystic-bbs-irc
>
> **Release: 2026-07-25** — All 38 g00r00 1.11 A1-A6 items ported.
> RIPscrip v1.54 support (42/42 commands, pixel-perfect).
> Built with **FPC 2.6.4irc r3.1+**. GPLv3.

Based on **Mystic BBS** GPL source by James Coyle (g00r00).
Maintained by sysop/0 (Antonio Rico), Ecstasy BBS, FTN 1:152/158.

## Team

| Handle | Role |
|--------|------|
| sysop/0 | Project lead, Ecstasy BBS |
| evga | IRC fork foundation — RIP engines, MDL, build system |
| wrench | ClamAV integration, RIPtermJS reference port |
| Kiddo | 1.11IRC porting, MPL compiler, FOSSIL, chg2rip converter |

## Directory Structure

```
mystic/                  BBS core (mystic, mis, mplc, mide, mutil, fidopoll)
mdl/                     Mystic Development Library (52 units)
mystic_rip/              RIPscrip — ALL RIP code lives here
  v1/                      RIPscrip v1.54 engine (ripscr.pas, 4,041 lines)
  v2/                      RIPscrip v2.0 engine (rip2api.pas, 5,304 lines)
  v3/                      RIPscrip v3.0 engine (rip3api.pas, 40,788 lines)
  v4/                      RIPscrip v4.0 engine (rip4api.pas, 45,991 lines)
  chg2rip.pas              ANSI→RIP converter (pixel-perfect, v2.3)
  ans2png.pas              ANSI→BMP renderer (pixel-perfect)
  ripviewer/               RIPView v1.0.0 — 42/42 cmds, CLI + FV TUI
  vgafont.inc              VGA 8x16 CP437 font ROM (4,096 bytes)
mystic_sdl/              SDL2 graphical terminal
mystic_crypt/            CryptLib SSH/TLS
mystic_spell/            Hunspell spell check
mystic_modem/            Modem/FOSSIL front-end
mystic_mailer/           BINKP/FidoNet mailer
mystic_misdos/           DOS MIS
examples/
  ripterm154/              RIPterm 1.54 DOS binary (Carl Gorringe archive)
  riptermJS/               RIPtermJS JavaScript viewer (Carl Gorringe, GPLv3)
  hslink-src/              HS/Link protocol (clean-room Pascal port)
  ansilove-src/            Ansilove (VGA font source)
  marc/                    MARC — built-in ZIP archiver + MP3/MP4 metadata (MediaTag)
docs/                    Documentation (17 files)
  ANSI-TO-RIP-PROGRESS.md   chg2rip development log (39KB)
out-linux/               Linux build output
out-win32/               Win32 build output
out-dos/                 DOS build output
out-os2/                 OS/2 build output
out_darwin/              macOS build output
attic/                   Retired code
```

## RIPscrip Engines

All under `mystic_rip/`:

| Engine | Path | Lines | Status |
|--------|------|-------|--------|
| v1 ripscr.pas | v1/ | 4,041 | ✅ Compiles |
| v2 rip2api.pas | v2/ (+img, pasjpeg) | 5,304 | ✅ Compiles |
| v3 rip3api.pas | v3/ (+img, prg, wav, pasjpeg) | 40,788 | ✅ Compiles |
| v4 rip4api.pas | v4/ (+img, prg, wav, pasjpeg, prt) | 45,991 | ✅ Compiles |
| ripviewer | ripviewer/source/ | 1,602 | ✅ 42/42 cmds, 100% pixel match |
| chg2rip | ./ | 880 | ✅ 100% pixel-perfect |
| ans2png | ./ | 340 | ✅ 100% pixel-perfect |

## ANSI to RIP Converter (chg2rip v2.3)

- **100% pixel-perfect** — 0 diff pixels (ImageMagick verified)
- **44KB output** for 62KB ANSI (31x smaller than v1.0 pixel bars)
- **3 minutes at 2400 baud** (vs 97 minutes for v1.0)
- `-pd` flag for PabloDraw compatibility
- RIPtermJS-verified: charsize 2 for 16px text height
- Full dev log: `docs/ANSI-TO-RIP-PROGRESS.md`

## BBS Binaries

| Binary | Status |
|--------|--------|
| mystic | ✅ Compiles |
| mis | ✅ Compiles |
| mplc | ✅ Compiles |
| mide | ✅ Compiles |
| mutil | ✅ Compiles |
| fidopoll | ✅ Compiles |
| 20 MPL scripts | ✅ All compile |

## Key Features (1.11IRC)

- g00r00 1.11 A1-A6 fully ported (38 items)
- MPL: record VAR params, record function return, multi-dim arrays
- FOSSIL/serial: TIOFossil for DOS dial-up (`-COM1 -FOSSIL`)
- MIDE: help system (Index, Under Cursor, Help on Help)
- Archive library: ZIP, RAR, ARJ, LHA, ARC, PAK, SQZ, HYP, UC2
- Print API: ESC/P, PCL, PostScript, BMP (v1-v4)
- DESQview DOS multi-node setup documented

## Build

```bash
# Get the compiler
git clone https://github.com/verta1878/fpc264irc

# Build on Linux
./build-linux.sh

# Cross-compile for Win32
./build-win32.sh
```

See `docs/BUILDING.md` for full instructions.

## Platforms

| Platform | Status |
|----------|--------|
| x86_64-linux | ✅ Native |
| i386-win32 | ✅ Cross-compiled |
| i386-go32v2 (DOS) | ✅ Cross-compiled |
| i386-os2 | ✅ Working (slow compile via fpc264irc EMX) |
| i386-darwin | ✅ Needs clang + SDK |

## License

GNU General Public License v3. See `LICENSE`.

## Links

- Compiler: https://github.com/verta1878/fpc264irc
- RIPtermJS: https://github.com/cgorringe/RIPtermJS
- RIPterm 1.54: https://github.com/cgorringe/RIPterm154
