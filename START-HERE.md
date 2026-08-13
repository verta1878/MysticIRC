# Start Here

Welcome to **Mystic BBS 1.11IRC** — the community fork.

## Quick Start

1. **Get the compiler:** https://github.com/verta1878/fpc264irc
2. **Build:** `./build-linux.sh` or `build-win32.bat`
3. **Read:** `docs/BUILDING.md` for full build instructions

## What's in the repo?

| Directory | What it is |
|-----------|------------|
| `mystic/` | BBS core — mystic, mis, mplc, mide, mutil, fidopoll |
| `mystic_test/` | BBS core + RIP integration + experimental |
| `mdl/` | Mystic Development Library (67 shared units) |
| `mystic_rip/` | RIPscrip engines (v1-v4), converters, tools |
| `mystic_perl/` | Perl integration (planned) |
| `mystic_rip/v1/` | RIPscrip v1.54 engine (4,123 lines) |
| `mystic_rip/v2/` | RIPscrip v2.0 engine + 256-color (5,331 lines) |
| `mystic_rip/v3/` | RIPscrip v3.0 engine + RGB24/32 (8,308 lines) |
| `mystic_rip/v4/` | RIPscrip v4.0 engine + printers (8,578 lines) |
| `examples/ripviewer/` | RIPView v1.0.0 — 42/42 cmds, pixel-perfect |
| `examples/mterm/` | mterm terminal + OpenOLMS (44 files) |
| `examples/hslink-src/` | HS/Link bidirectional protocol (1,067 lines) |
| `mystic_sdl/` | SDL2 graphical terminal |
| `docs/` | Documentation |
| `attic/` | Retired code (kept for history) |

## 9 RIP Engines

All engines share the same 17 backported fixes (Bresenham, FloodFill,
Bezier, fill patterns, button bevel, font system, viewport, etc.)

See `docs/BACKPORT-STATUS.md` for the full fix matrix.

## Key Files

| File | Read this for... |
|------|-----------------|
| `README.md` | Full project overview |
| `docs/BUILDING.md` | How to compile |
| `docs/TODO.md` | What's done, what's pending |
| `docs/BACKPORT-STATUS.md` | RIP engine fix matrix (all 9 engines) |
| `docs/MIS-112-REBUILD.md` | MIS 1.12 tabbed UI rebuild plan |
| `mystic_rip/README.md` | RIP utilities and engines guide |
| `examples/mterm/RIP-BACKPORT-TODO.md` | mterm RIP engine status |
| `examples/hslink-src/HSLINK.md` | HS/Link protocol documentation |

## Team

| Handle | Role |
|--------|------|
| verta1878 | Project lead, Ecstasy BBS FTN 1:152/158 |
| sysop/0 | serial.pas UART, architecture, Phase 3 testing |
| evga | FPC 2.6.4irc compiler, RIP engines |
| kiddo | serial_irq.pas ISR, text rendering, MPL, ans2rip |
| wrench | fossil.pas, netfosdl.pas FOSSIL driver |
| hexadecimal | PCBoard 15.4 Revival |
