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
| MIS-4 | ESC popup menu (Local Login, Kill, Switch, Help, Shutdown) | done |
| MIS-5 | Console title: "Mystic Internet Server (BBSName)" | done |
| MIS-6 | Slot-based connections (SERVER/USER/STATUS/ORIGIN columns) | done |
| MIS-UI | TUI rendering — Console.WriteXY, color attrs, tab highlight, scroll region |

## Pending — ansiedit (ANSI Editor)

Separate binary inside /mystic — compiled alongside mystic, mis, mplc, mide, mutil, fidopoll.
Extracted from BBS ANSI editor code. Ships as ansiedit.exe / ansiedit.

| Phase | Description |
|-------|-------------|
| ANSIEDIT-1 | Core canvas (ansiedit.pas, 900+ lines, line draw, 8 char sets) — 80x25+ screen buffer, CP437 charset, 16-color attrs |
| ANSIEDIT-2 | Drawing tools (line draw 8 sets, fill C/A/B/N, ins/del line) — freehand, line, box, fill, text entry |
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

## Pending — ansiedit Teleconference (PabloDraw Protocol)

Built into ansiedit, NOT MIS. Uses m_pdnet.pas from examples/pablodraw/.

| Phase | Description |
|-------|-------------|
| ANSIEDIT-TC-1 | Virtual pages (canvas/chat), chat scrollback, /commands, input line | done |
| ANSIEDIT-TC-2 | Wire m_pdserver/m_pdclient into ansiedit — host/join mode on startup |
| ANSIEDIT-TC-3 | Session mgmt: /who real users, /kick, /nick, join/leave callbacks | done |
| ANSIEDIT-TC-4 | Real-time sync: OnNetUpdate copies NetCanvas to local Canvas + redraw | done |
| ANSIEDIT-TC-5 | Chat notification on canvas (3s flash on status bar) | done |
| ANSIEDIT-TC-6 | Save shared canvas, OnNetUpdate handles sync on connect | done |
| ANSIEDIT-MDL | Migrate m_pd* units to mdl/, create mdltest12-16 |

### UI Conversion Notes (ANSIEDIT-TC-1)
m_pdviewfv.pas uses Free Vision (Objects, Drivers, Views) which is the
Turbo Vision clone. Mystic BBS uses its own TOutput (m_Output_*.pas) and
TInput (m_Input_*.pas) console system. The conversion:
- Free Vision TView → Mystic Console.WriteXY for rendering
- Free Vision TEvent/GetEvent → Mystic Keyboard.ReadKey/KeyWait
- Free Vision TApplication.Run → ansiedit main loop
- Free Vision TDialog → Mystic box-drawing with Console.WriteXY
- Free Vision TStatusLine → ansiedit status bar (already exists)

### PabloDraw Files in mystic/ansiedit/
| File | Lines | Purpose |
|------|-------|---------|
| m_pdnet.pas | 907 | Network protocol (teleconference core) |
| m_pdserver.pas | 177 | Server — hosts sessions |
| m_pdclient.pas | 234 | Client — joins sessions |
| m_pdtypes.pas | 254 | Type definitions |
| m_pdansi.pas | 383 | ANSI parser |
| m_pdansiw.pas | 166 | ANSI writer |
| m_pdsauce.pas | 331 | SAUCE metadata |
| m_pdbitfont.pas | 200 | Bitmap font |
| m_pdviewfv.pas | 216 | Free Vision viewer (to be converted) |
| m_pdrip.pas | 330 | RIPscrip parser |
| + 9 format parsers | ~700 | ASCII, PCBoard, Avatar, Binary, XBin, iDF, Tundra |


### m_pd* MDL Migration Plan
Once ANSIEDIT-TC-1 converts m_pdviewfv.pas away from Free Vision,
the m_pd* units move to mdl/:

**Units → mdl/ (no Free Vision deps):**
- m_pdtypes.pas — type definitions
- m_pdnet.pas — network protocol
- m_pdansi.pas — ANSI parser
- m_pdansiw.pas — ANSI writer
- m_pdsauce.pas — SAUCE metadata
- m_pdbitfont.pas — bitmap font
- m_pdascii.pas, m_pdavatar.pas, m_pdbinary.pas, m_pdpcboard.pas
- m_pdtundra.pas, m_pdxbin.pas, m_pdidf.pas, m_pdrip.pas

**Programs → stay in mystic/ansiedit/:**
- m_pdserver.pas, m_pdclient.pas, m_pdmain.pas
- m_pdviewfv.pas (converted to Mystic UI)
- m_pdtest.pas

**New MDL tests needed:**
- mdltest12.pas — m_pdtypes + m_pdsauce (SAUCE read/write round-trip)
- mdltest13.pas — m_pdansi + m_pdansiw (ANSI parse/write round-trip)
- mdltest14.pas — m_pdnet (loopback protocol test, packet encode/decode)
- mdltest15.pas — m_pdbitfont (font rendering sanity check)
- mdltest16.pas — format parsers (PCBoard, Avatar, XBin, iDF, Tundra, Binary)
