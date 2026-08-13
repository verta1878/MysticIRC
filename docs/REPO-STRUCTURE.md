# Mystic BBS 1.11IRC — Repository Structure

## Directory Layout

```
mystic-repo/
├── mystic/                  BBS core (production)
│   ├── mystic.pas           Main BBS binary
│   ├── mis.pas              Mystic Internet Server
│   ├── mplc.pas             MPL compiler
│   ├── mide.pas             MPL IDE
│   ├── mutil.pas            Maintenance utility
│   ├── fidopoll.pas         FidoNet poller
│   ├── mutil_*.pas          MUTIL task modules (15 files)
│   ├── bbs_*.pas            BBS subsystems (40+ files)
│   └── scripts/             MPL scripts (blackjack, etc.)
│
├── mystic_test/             BBS core (development/experimental)
│   ├── (mirrors mystic/ with experimental features)
│   ├── mis_ansiwfc.pas      MIS 1.12 WFC screen (tabbed UI)
│   ├── mis_imagedata.inc    Compiled ANSI screens for MIS
│   ├── mis_status1.ans      MIS Messages tab ANSI
│   ├── mis_status2.ans      MIS Connections tab ANSI
│   ├── mis_events.ans       MIS Events tab ANSI
│   ├── mis_stats.ans        MIS Stats tab ANSI
│   ├── mis_help.ans         MIS Help screen ANSI
│   └── mis_poll.ans         MIS FTN Poll screen ANSI
│
├── mdl/                     Mystic Development Library (67 units)
│   ├── m_strings.pas        String functions
│   ├── m_io_sockets.pas     TCP/IP sockets
│   ├── m_output*.pas        Console output
│   ├── m_protocol_*.pas     Transfer protocols (Zmodem, etc.)
│   └── ...
│
├── mystic_rip/              RIPscrip engines & tools
│   ├── v1/ripscr.pas        RIP v1.54 engine (4,123 lines)
│   ├── v2/rip2api.pas       RIP v2.0 + 256-color (5,331 lines)
│   ├── v3/rip3api.pas       RIP v3.0 + RGB24/32 (8,308 lines)
│   ├── v4/rip4api.pas       RIP v4.0 + printers (8,578 lines)
│   ├── rip_surface.pas      Canvas/surface split (775 lines)
│   ├── ans2rip.pas          ANSI→RIP converter (pixel-perfect -p)
│   ├── ans2png.pas          ANSI→BMP renderer
│   ├── ripmake.pas          RIP file generator
│   ├── test_rip_files.pas   Batch test harness
│   ├── ans2img.py           ANSI→IMAGEDATA converter
│   └── README.md
│
├── examples/
│   ├── ripviewer/           RIPView v1.0.0 (42/42 cmds)
│   ├── mterm/               mterm terminal + OpenOLMS (44 files)
│   ├── hslink-src/          HS/Link protocol (1,067 lines)
│   ├── mpl/                 MPL script examples
│   ├── door32/              Door32.sys gateway
│   ├── shatranj/            Network chess (C/Z80 ASM)
│   └── ...
│
├── mystic_sdl/              SDL2 graphical terminal
├── mystic_modem/            Modem/FOSSIL driver
├── mystic_perl/             Perl integration (planned)
│   ├── example_door.pl        Example Perl BBS door
│
├── docs/                    Documentation
│   ├── PHASES.md            Master phase list
│   ├── BACKPORT-STATUS.md   RIP engine fix matrix
│   ├── MIS-112-REBUILD.md   MIS 1.12 rebuild plan
│   ├── MIS-112-BINARY-AUDIT.md  MIS binary audit
│   ├── MUTIL-112-AUDIT.md   MUTIL binary audit
│   ├── BUILDING.md          Build instructions
│   ├── CREATING-THE-INSTALLER.md  Release packaging
│   ├── TODO.md              Current task list
│   ├── BUGS.md              Known bugs
│   ├── REPO-STRUCTURE.md    This file
│   └── ...
│
├── attic/                   Retired code (kept for history)
├── README.md                Project overview
└── START-HERE.md            Quick start guide
```

## Binaries Produced

| Binary | Source | Description |
|--------|--------|-------------|
| mystic | mystic/mystic.pas | BBS server |
| mis | mystic/mis.pas | Internet server (Telnet/SMTP/POP3/FTP/NNTP/BinkP) |
| mplc | mystic/mplc.pas | MPL script compiler |
| mide | mystic/mide.pas | MPL IDE |
| mutil | mystic/mutil.pas | Maintenance utility (25 tasks, -RUN/-LIST/-VER) |
| fidopoll | mystic/fidopoll.pas | FidoNet poller |
| ansiedit | (planned) | ANSI art editor |

## Build

See `docs/BUILDING.md` for full instructions.

```bash
# Quick start
git clone https://github.com/verta1878/fpc264irc
./build-linux.sh        # or build-win32.bat
```

## Platform Support

| Platform | Compiler | Status |
|----------|----------|--------|
| Linux x86_64 | fpc264irc | Primary development |
| Linux i386 | fpc264irc | Supported |
| Windows 32-bit | fpc264irc | Supported |
| Windows 64-bit | fpc264irc | Supported |
| FreeBSD | fpc264irc | Supported |
| OS/2 | fpc264irc | Supported |
| DOS (DPMI) | fpc264irc | Limited (no networking) |

## Version History

| Version | Base | Status |
|---------|------|--------|
| 1.10 A38 | g00r00 release | Original fork point |
| 1.11 IRC | Community fork | Current development |
| 1.12 A49 | g00r00 release | Reference for feature parity |
