# Mystic BBS 1.11IRC — Master Phase List

## Completed ✅

| Phase | Description |
|-------|-------------|
| RIPview | 35 test runs, 25+ bugs, 3 pixel-perfect, 10/13 under 3% |
| v1-v4 backport | All 17 fixes + printer drivers to all engines |
| Phase 4 | bbs_rip.pas + EXPERIMENTAL_RIP ifdef |
| SDL rename | sdl.pas → m_sdl.pas (4 files) |
| MT-1 | mterm Core Rendering (Bresenham, FloodFill, Bezier) |
| MT-2 | mterm Font System (CHR, 8x8, TextWidth/Height) |
| MT-3 | mterm Extended Commands (19 stubs → implementations) |
| MT-4 | mterm Protocol (| separator, |! comment, 49 dispatch) |
| MT-5 | mterm Terminal Features (mouse fields, hit test) |
| MT-6 | mterm Debug & Fix (compile clean, smoke test, gap closure) |
| Palette | EGA palette standardized across all 9 engines + utilities |
| ans2rip | Pixel-perfect ANSI→RIP converter (-p flag, 0 diff) |
| Doc audit | All docs updated, stale refs fixed |

## Pending — MIS 1.12 Rebuild

See docs/MIS-112-REBUILD.md for full details + 1.12 screenshot.

| Phase | Description |
|-------|-------------|
| MIS-1 | New ANSI screen — ASCII art header + tab bar | ✅ |
| MIS-2 | Tabbed panel system (Messages/Connections/Events/Stats) |
| MIS-3 | Enhanced logging (timestamps, IP, hostname, duplicate IP) | ✅ |
| MIS-4 | ESC menu system (replaces status bar hotkeys) |
| MIS-5 | BBS name in console title |
| MIS-6 | Slot-based connection management |
| MIS-UI | TUI rendering — Console.WriteXY, color attrs, tab highlight, scroll region |

## Pending — ansiedit (ANSI Editor)

Separate binary inside /mystic — compiled alongside mystic, mis, mplc, mide, mutil, fidopoll.
Extracted from BBS ANSI editor code. Ships as ansiedit.exe / ansiedit.

| Phase | Description |
|-------|-------------|
| ANSIEDIT-1 | Core canvas — 80x25+ screen buffer, CP437 charset, 16-color attrs |
| ANSIEDIT-2 | Drawing tools — freehand, line, box, fill, text entry |
| ANSIEDIT-3 | Block operations — select, copy, paste, move, flip, mirror |
| ANSIEDIT-4 | Undo system — multi-level undo/redo stack |
| ANSIEDIT-5 | File I/O — load/save .ANS, .ASC, SAUCE metadata |
| ANSIEDIT-6 | UI chrome — status bar, color picker, character set, tool palette |

## Pending — mterm Phase 4+

| Phase | Description |
|-------|-------------|
| MT-7 | Remaining gaps (BUTTONS 42%, COVAI 9.8%, V_ARC 5.8%) |

## Backlog

| Item | Description |
|------|-------------|
| Engine consolidation | 9 RIP engines → fewer (deferred — all working, no urgency) |
| openwatcomirc | Compiler fork for pcbirc |
| Password migration | Testing |
| RIPscrip v2/v3/v4 | Protocol testing |
| Printer drivers | ESC/P, PCL, PostScript testing |
| Duplicate cleanup | v3/prg=v4/prg, font inc dupes |

## Pending — MIS IPv6

| Phase | Description |
|-------|-------------|
| MIS-7 | IPv6 support (evga cleanup from 1.12). Dual-stack: listen on IPv6 when available, fall back to IPv4 on XP/systems without IPv6 stack. Auto-detect at startup. |

## Pending — MIS Script Server

| Phase | Description |
|-------|-------------|
| MIS-8 | Script Server — TScriptServer class, MPL clientread/clientwrite/clientconnected functions, per-port script config. See docs/MIS-112-BINARY-AUDIT.md and examples/scripts/ for examples. |

## Pending — MUTIL 1.12 Upgrade

See docs/MUTIL-112-AUDIT.md for full binary audit.

| Phase | Description |
|-------|-------------|
| MUTIL-1 | Command line: -RUN, -LIST, -VER, -HELP, -NOSCREEN | done |
| MUTIL-2 | Logging: timestamp, log roller, cache, per-stanza loglevel, timing | done |
| MUTIL-3 | New tasks: EchoNodeTracker, EchoUnlink, AutoHatch | done |
| MUTIL-4 | INI file synced with 1.12 (26 sections, 25 task toggles) | done |
| MUTIL-5 | All 25 tasks wired, 8 stub modules created | done |
