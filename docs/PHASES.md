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
| MIS-3 | Enhanced logging (timestamps, IP, hostname, duplicate IP) |
| MIS-4 | ESC menu system (replaces status bar hotkeys) |
| MIS-5 | BBS name in console title |
| MIS-6 | Slot-based connection management |
| MIS-UI | TUI rendering — Console.WriteXY, color attrs, tab highlight, scroll region |

## Pending — mDraw (ANSI Editor)

Standalone ANSI drawing tool — separate from mystic -cfg.
Extracted from BBS editor code but rebuilt as independent program.

| Phase | Description |
|-------|-------------|
| MDRAW-1 | Core canvas — 80x25+ screen buffer, CP437 charset, 16-color attrs |
| MDRAW-2 | Drawing tools — freehand, line, box, fill, text entry |
| MDRAW-3 | Block operations — select, copy, paste, move, flip, mirror |
| MDRAW-4 | Undo system — multi-level undo/redo stack |
| MDRAW-5 | File I/O — load/save .ANS, .ASC, SAUCE metadata |
| MDRAW-6 | UI chrome — status bar, color picker, character set, tool palette |

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
