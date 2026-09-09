# Start Here

Welcome to **Mystic BBS 1.11IRC A4** — the community fork.

## Quick Start

1. **Get the compiler:** https://github.com/verta1878/fpc264irc
2. **Build:** `./build-linux.sh` or `build-win32.bat`
3. **Clean:** `cleanup.bat` (Windows) or `./make_clean.sh` (Linux)

## What's in the repo?

| Directory | What it is |
|-----------|------------|
| `mystic/` | BBS core — 16 binaries (mystic, mis, mutil, mplc, mide, mbbsutil, fidopoll, nodespy, qwkpoll, mystpack, install, install_make, maketheme, 109to110, marc, mystfoss) |
| `mystic_test/` | BBS core + RIP + crypto + spellcheck (unstable branch) |
| `mystic/mdl/` | Mystic Development Library — shared units |
| `mystic/mdl/m_serial/` | Serial I/O stack (4 files, 6 platforms) |
| `mystic_modem/` | Modem config + WFC support (7 files) |
| `mystic_misdos/` | DOS Waiting-For-Caller example |
| `mystic_ansiedit/` | ANSI art editor |
| `mystic_texteditor/` | Text editor |
| `mystic_mterm/` | Terminal emulator + modem dialer |
| `mystic_molms/` | OpenOLMS integration |
| `mystic_ripview/` | RIPscrip viewer (v1-v4 engines) |
| `mystic_sdl/` | SDL2 graphical terminal |
| `mystic_spell/` | Hunspell spellcheck integration |
| `mystic_crypt/` | Crypto/hashing library |
| `mystic_mailer/` | FidoNet mailer (DOS-only) |
| `mystic_makemenu/` | Menu compiler |
| `mystic_perl/` | Perl door integration (planned) |
| `examples/` | Door32, HS/Link, SDL demo, misc |
| `historical/` | Archives (RIPkit, old releases) |
| `attic/` | Retired code (kept for history) |
| `todo/` | Planning docs, feature analysis |
| `docs/` | Documentation |

## Serial Stack (mdl/m_serial/)

4 files, 6 platforms (DOS, Linux, FreeBSD, Darwin, Windows, OS/2):

| File | Description |
|------|-------------|
| `m_serial.pas` | TModemSerial — OOP serial port class (758 lines) |
| `m_serial_irq.pas` | DOS IRQ ring buffer (go32v2 + i8086) |
| `m_fossil.pas` | TFossil — FOSSIL driver (serial + INT 14h backends) |
| `m_fossil_io.pas` | TIOFossil — Mystic TIOBase adapter |

## 16 Binaries

| Binary | Description |
|--------|-------------|
| mystic | BBS engine |
| mis | MIS server (WFC + node manager) |
| mutil | Maintenance utility (echomail, users, packing) |
| mplc | MPL script compiler |
| mide | Integrated development environment |
| mbbsutil | BBS utility tool |
| fidopoll | FidoNet poller |
| nodespy | Node activity monitor |
| qwkpoll | QWK mail poller |
| mystpack | Message base packer |
| install | BBS installer |
| install_make | Installer builder |
| maketheme | Theme compiler |
| 109to110 | Database upgrade tool |
| marc | Message archiver |
| mystfoss | FOSSIL v5 driver (FTS-0015, 5 target platforms) |

## Key Files

| File | Read this for... |
|------|-----------------|
| `README.md` | Full project overview |
| `RELEASE-NOTES.md` | What changed |
| `docs/SERIAL.md` | Serial unit API reference |
| `mystic_modem/README.md` | Modem/FOSSIL architecture |
| `cleanup.bat` | Clean build output (writes cleanup.log) |
| `build-linux.sh` | Linux build script (stable + test) |
| `build-win32.bat` | Windows build script |

## Build

```bash
# Linux stable (16 binaries):
./build-linux.sh x64

# Linux test branch (16 binaries):
./build-linux.sh x64 test

# Windows:
build-win32.bat

# Clean everything:
cleanup.bat          # Windows (writes cleanup.log)
./make_clean.sh      # Linux
```

## Compiler

FPC 2.6.4irc r311 — 6 patches (defutil, nopt, symdef, fppu, dl/dynlibs, MZ linker source recovery).
https://github.com/verta1878/fpc264irc

## Team

| Handle | Role |
|--------|------|
| verta1878 | Project lead, Ecstasy BBS FTN 1:152/158 |
| sysop/0 | Compiler engineer, FPC, Tang Console, USB |
| bob | Compiler engineer, OpenWatcom2 x64, Glide, 3dfx drivers |
| evga | Display, Mystic, SIO rebuild |
| kiddo | Protocols, RIPscrip |
| wrench | Transport, FOSSIL, DVI/HDMI |
| hexadecimal | PCBoard, Cyclades |
| DotMatrix | Documentation sourcing |
| byte | Program discovery |
