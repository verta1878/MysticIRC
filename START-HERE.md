# Start Here

Welcome to **Mystic BBS 1.11IRC A5** — the community fork.

## Quick Start

1. **Get the compiler:** https://github.com/verta1878/fpc264irc
2. **Build:** `./build-linux.sh` or `build-win32.bat`
3. **Read:** `docs/MDL-COMPILER.md` for build notes

## What's in the repo?

| Directory | What it is |
|-----------|------------|
| `mystic/` | BBS core — mystic, mis, mplc, mide, mutil, fidopoll |
| `mystic_test/` | BBS core + RIP integration + experimental |
| `mystic_mterm/` | mterm terminal emulator (RIP auto-sense, phonebook, capture) |
| `mystic_ripview/` | RIPView — Pascal RIP browser (v1 engine complete, zero stubs) |
| `mystic_molms/` | OpenOLMS offline mail (37 units, 8 programs, GPLv3) |
| `mystic_ansiedit/` | ANSI editor (ansiedit + PCBDraw support) |
| `mystic_sdl/` | SDL2 graphical terminal |
| `mystic_spell/` | Hunspell spell check binding |
| `mystic_crypt/` | CryptLib SSH/TLS example |
| `mystic_modem/` | Modem/FOSSIL front-end |
| `mystic_mailer/` | BINKP/FidoNet mailer |
| `mystic_makemenu/` | Menu builder |
| `mystic_misdos/` | DOS Waiting-For-Caller (modem/BinkP/local login) |
| `mystic_perl/` | Perl DLL integration |
| `mystic_texteditor/` | Text editor standalone |
| `examples/` | RIP art (226 files), fonts (18), icons (222), HS/Link, serial, more |
| `todo/` | Documentation + phase tracking |
| `attic/` | Retired code (kept for history) |

## RIPView Engine

v1 engine COMPLETE — zero stubs, all L0/L1 commands dispatched.
RT154SRC verified against RIPterm reference (42/42 parse, 34 exec).
RIPaint 674/674 decompiled source staged as reference.

Key units in `mystic_ripview/source/`:
ripview.pas (17,917 lines), ripengine.pas (22,601), ripdraw.pas (21,601),
riptext.pas (13,689), ripicon.pas (12,541), rip1exec.pas (34,780),
rip1parse.pas (5,431), ripwidgets.pas (7,529), riputf8.pas (UTF-8 codec),
+ ripstate, riptextvar, ripmouse, ripbmp, ripdelta, riprender, and more.

## Key Files

| File | Read this for... |
|------|-----------------|
| `README.md` | Full project overview |
| `RELEASE-NOTES.md` | Release history and platform matrix |
| `INSTALL` | Installation instructions |
| `LICENSE` | GPLv3 license |
| `RIP-GRAPHICS-PHASES.md` | RIP engine audit + phase tracking |
| `mystic_ripview/NEXT.TXT` | ripview current priorities |
| `mystic_ripview/STATUS.TXT` | ripview per-unit status |
| `mystic_mterm/README.md` | mterm overview |
| `mystic_molms/OPENOLMS-README.md` | OpenOLMS documentation |

## Team

| Handle | Role |
|--------|------|
| verta1878 | Project lead, Ecstasy BBS FTN 1:152/158 |
| sysop/0 | Compiler engineer, FPC, Tang Console, USB |
| bob | Compiler engineer, OpenWatcom, Glide, 3dfx drivers |
| evga | Display, Mystic, SIO rebuild |
| kiddo | Protocols, RIPscrip |
| wrench | Transport, FOSSIL, serial |
| hexadecimal | PCBoard, Cyclades |
| byte | Program discovery |
| DotMatrix | Documentation sourcing |
| fabric | FPGA, Voodoo 6 5000 Spinal |
