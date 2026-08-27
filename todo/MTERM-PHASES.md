# mterm — Phase Tracking

## What Is mterm?

mterm is a standalone RIP/ANSI terminal emulator for Mystic BBS.
DOS-first design. MDL Console/Keyboard shell (Free Vision stripped).
8 platform targets.

## Completed Phases

| Phase | What | Status |
|-------|------|--------|
| MT-1 | Strip Free Vision → MDL Console/Keyboard | DONE |
| MT-2 | Menu hotkeys (all F-keys, ALT, CTRL) | DONE |
| MT-3 | Status bar (connection, baud, elapsed, bytes) | DONE |
| MT-4 | Terminal viewport — ANSI engine (cell buffer, CSI parser, SGR, scrollback) | DONE |
| MT-6 | Virtual pages (page 0=terminal, page 1=settings) | DONE |

## Open Phases

| Phase | What |
|-------|------|
| MT-5 | Phonebook dialog | DONE |
| MT-7 | SDL graphics backend (SDL2 Linux/Win32/macOS/BSD + SDL 1.2 OS/2) — deferred until fpc264irc complete |
| MT-8 | Wire RIP engine into viewport |
| MT-9 | DOS GO32V2 — FPC Graph unit (VESA/VGA) — deferred until fpc264irc complete |
| MT-10 | DOS i8086 — BGI / INT 10h EGA 640x350 — deferred until fpc264irc complete |
| MT-13 | Amiga font loading (SDL_ttf) — deferred until fpc264irc complete |
| MT-14 | RIP v1.54 command completion | DONE |
| MT-15 | ANSI baseline completion | DONE |
| MT-16 | BGI stroked font parser (CHR files — 10 vector fonts) |
| MT-17 | ICN icon file loader (EGA bitplane format) |
| MT-18 | Flood fill accuracy (stack limits matching RIPterm) |
| MT-19 | RIP auto-sense (ESC[! query/response, ESC[1!/ESC[2! toggle) |
| MT-20 | Unofficial RIP extensions — modern formats |
| MT-21 | Character pacing / ANSI animation speed control |

### MT-14 — RIP v1.54 Missing Commands

| Cmd | Name | Priority |
|-----|------|----------|
| E | RIP_ERASE_VIEW | HIGH |
| g | RIP_GOTOXY_TEXT | HIGH |
| m | RIP_MOVE (lowercase) | HIGH |
| W | RIP_WRITE_MODE | HIGH (proc exists, wire it) |
| > | RIP_ERASE_EOL | MEDIUM |
| V | RIP_OVAL_ARC | MEDIUM |
| i | RIP_OVAL_PIE_SLICE | MEDIUM |
| 1t | RIP_REGION_TEXT | MEDIUM |
| 1E | RIP_END_TEXT | MEDIUM |
| 1D | RIP_DELAY | LOW |
| $ | RIP_QUERY | LOW |

Bug fixes: K/> swap, l=linestyle vs polyline, 1G mapped to wrong proc.

### MT-15 — ANSI Baseline (HIGH priority)

| Sequence | Function |
|----------|----------|
| ESC[5n | Device status report |
| ESC[6n | Cursor position report |
| ESC[c | Device attribute report |
| ESC[Pl;Pnr | Set scrolling region |
| ESC[! | Auto-sense RIP query |
| ESC[1!/ESC[2! | RIP enable/disable |

Plus 16 MEDIUM/LOW sequences (insert/delete, scroll, wrap, reset, Doorway).

### MT-20 — Unofficial RIP Extensions (Modern Formats)

| Feature | Format | Via |
|---------|--------|-----|
| Icons/images | PNG (replaces ICN/BMP) | SDL2_image |
| Animated icons | APNG, GIF | SDL2_image |
| Additional images | WebP | SDL2_image |
| Audio | MP3, OGG, Opus | SDL2_mixer |
| Fonts (terminal) | TTF, OTF | SDL2_ttf (already have m_sdl_ttf.pas) |
| Fonts (web/MIS) | WOFF, WOFF2 | MIS HTTP server / HTML pages |
| Text | UTF-8 / CP437 switching | MDL output units |

### MT-22 — riplib v3.0-3.2 Extensions

Unofficial third-party extensions from BradHawthorne's riplib (2026).
Not TeleGrafix standard, but we support them.

| Version | Wire ID | Features |
|---------|---------|----------|
| v3.0-riplib | — | Write modes, command inventory |
| v3.1-riplib | RIPSCRIP031001 | New write modes, third text direction, rendered font attributes, port alpha/compositing |
| v3.2-riplib | RIPSCRIP032001 | Drawing-state stack, layout/time/color-name variables, DEBUG directive, radial gradient |

Reference source: docs/ripscrip/riplib-src/ (13K lines C99)

## Graphics Backend Matrix

| Platform | Backend | RIP Resolution |
|----------|---------|----------------|
| Linux x86/x64 | SDL2 | 640x350 EGA |
| Win32 | SDL2 | 640x350 EGA |
| macOS | SDL2 | 640x350 EGA |
| BSD | SDL2 | 640x350 EGA |
| OS/2 | SDL 1.2 (DIVE) | 640x350 EGA |
| DOS GO32V2 | FPC Graph unit | 640x350 EGA |
| DOS i8086 | BGI / INT 10h | 640x350 EGA |

SDL covers 5 platforms (SDL2 for 4 modern + SDL 1.2 for OS/2).
DOS needs two backends (GO32V2 + i8086).

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


## License

GPLv3

### MT-23 — RIP Web Viewer

Web-based RIP viewer (riptermJS + ripviewer HTML output).
WOFF/WOFF2 webfont support lives here, not in the terminal.

| Feature | Status |
|---------|--------|
| riptermJS (JavaScript RIP viewer) | EXISTS — examples/riptermJS/ |
| ripviewer (Pascal, 42/42 cmds) | EXISTS — examples/ripviewer/ |
| WOFF/WOFF2 webfont support | TODO |
| Update viewer to match new RIP commands | TODO |
| PNG icon support in web viewer | TODO |

### MT-24 — ripviewer Command Sync

Sync ripviewer (42/42 currently) with mterm RIP engine updates.
When MT-14 adds missing commands, ripviewer gets them too.
Or consolidate engines first (MT-25).

### MT-25 — Engine Consolidation

9 RIP engines → fewer. Currently:
- mtrip.pas + mtripgfx.pas (mterm)
- ripdraw.pas (ripviewer)
- ripview source/ (ripviewer CLI)
- riptermJS (JavaScript)
- ans2rip
- Others in mystic/

Target: one core RIP engine shared by mterm, ripviewer, and mystic.
