# ansiedit / PCBDraw — Phase Tracking

## What Is PCBDraw?

PCBDraw is ansiedit. One Pascal codebase, one editor, both BBSes.
Serves PCBoard 15.4/15.41 and Mystic BBS 1.11IRC.
No compile flag — one binary, runtime drop file detection.

The editor works in ANSI internally. Always. @X is an import/export
format for PCBoard compatibility, not the native format.

## Completed Phases

| Phase | What | Status |
|-------|------|--------|
| ANSIEDIT 1-6 | Core editor (canvas, line draw, blocks, undo, SAUCE, status bar) | DONE |
| TC 1-6 | Teleconference (virtual pages, chat, ALT+S, PabloDraw protocol) | DONE |
| Security 1-13 | All 13 findings fixed, zero unchecked fpSend | DONE |

## PCBDraw Phases (New)

| Phase | What |
|-------|------|
| PCBD-1 | Wire @X import/export into file menu (m_pdpcboard.pas in mdl/) |
| PCBD-2 | Drop file reader — pcbdrop.pas (PCBOARD.SYS + DOOR.SYS + DORINFO1.DEF). Code DONE, needs ansiedit integration. |
| PCBD-3 | Timeout + carrier detect in door mode |
| PCBD-4 | Command line flags |
| PCBD-5 | SAUCE viewer (command line dump + UI display) |
| PCBD-6 | File selector dialog |
| PCBD-7 | Config file (ansiedit.cfg) |
| PCBD-8 | Help screen (F1) |
| PCBD-9 | Test harness + unit tests |

## Command Line Flags

| Flag | What |
|------|------|
| `filename.ans` | Open file |
| `/ICE:ON` `/ICE:OFF` | Initial iCE color mode |
| `/SAUCE filename.ans` | Print SAUCE info to stdout, exit |
| `/DOOR` | Door mode (auto-detect drop file) |
| `/LOCAL` | Sysop local mode |
| `/NICK:name` | Set nickname |
| `/PWD:secret` | Teleconference password |
| `/SERIAL:COM1:9600` | Serial teleconference (built-in) |

## Config File (ansiedit.cfg)

- Nick
- Last file opened
- Default line draw set
- Color defaults

ICE and SAUCE are NOT config items.
- ICE: per-canvas toggle (high-intensity BG vs blink)
- SAUCE: per-file metadata (author, title, group, date, TInfo)

## Key Decisions

- No {$DEFINE PCBOARD} compile flag — one binary, both BBSes
- Runtime drop file detection (PCBOARD.SYS vs DOOR.SYS vs DORINFO1.DEF)
- Editor always works in ANSI internally
- @X is import/export only — PCBoard color code format
- Serial teleconference built-in on all platforms
- TCP teleconference via external program
- Drop file reader in pcbdrop.pas (mystic/ansiedit/) — standalone, no Mystic dependency
- Future: promote to mdl/m_door.pas for portability

## Platform Matrix

| Target | Serial | TCP | Status |
|--------|--------|-----|--------|
| DOS i8086 | FOSSIL / UART | External | Builds |
| DOS go32v2 | FOSSIL / UART | External | Builds |
| Linux x86/x64 | /dev/ttyS* | External | Builds |
| Win32 | COM* Win32 API | External | Builds |
| OS/2 | COM* | External | Builds |
| BSD | /dev/ttyS* | External | Builds |
| macOS | /dev/tty* | External | Builds |

## Credits

- CiA / Strider — original CIADraw (1994-96)
- James Coyle (g00r00) — Mystic BBS ansiedit
- Curtis Wensley — PabloDraw (C# original)
- sysop/0 — CIADraw FPC port, PabloDraw Pascal port, UART layer
- evga — FPC 2.6.4irc, RIP engines, MDL
- kiddo — ansiedit lead, serial_irq.pas, text rendering
- wrench — fossil.pas, netfosdl.pas FOSSIL driver
- hexadecimal — PCBoard integration docs, CIADraw preservation
- verta1878 — project lead, Ecstasy BBS FTN 1:152/158

## License

GPLv3
