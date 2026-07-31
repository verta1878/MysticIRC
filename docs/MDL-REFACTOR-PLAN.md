# MDL Refactor Plan — DEFERRED

## Problem

MIS and the BBS core depend on mdl/ (g00r00's 2002 abstraction layer).
Every IO/string/file/socket operation goes through wrapper classes,
adding 3-4 layers of overhead. This is why Mystic is slow even with
newer fpc264irc releases — the compiler can optimize the RTL, but
can't optimize away the mdl class hierarchy.

## Phase 1: MIS Server (mis*.pas)
Replace mdl dependencies in MIS with FPC RTL equivalents.
MIS is the smallest consumer — 13 files, isolated from BBS UI.

| mdl unit | Replace with | MIS files affected |
|----------|-------------|-------------------|
| m_strings | SysUtils | all 13 |
| m_datetime | SysUtils + DateUtils | all 13 |
| m_fileio | SysUtils + FileUtil | all 13 |
| m_io_base + m_io_sockets | FPC Sockets + SSockets | mis_server, mis_client_* |
| m_input + m_output | Direct CRT / terminal | mis.pas, mis_ansiwfc |
| m_term_ansi | Keep (custom ANSI emulator) | mis_client_telnet |
| m_types | Inline type defs | mis_common |
| m_crypt | Keep (custom XOR cipher) | mis_client_* |
| uforkpty | Inline into mis_client_telnet | mis_client_telnet |

## Phase 2: BBS Core (mystic/*.pas)
Replace mdl in the main BBS. Larger scope — 50+ files.
Same replacements as Phase 1 plus:

| mdl unit | Replace with | Notes |
|----------|-------------|-------|
| m_prot_zmodem | Keep | Custom Zmodem, no FPC equivalent |
| m_prot_base | Keep | File transfer base class |
| m_menubox/form/help/input | Keep | TUI widgets, no FPC equivalent |
| m_socket_server | Keep or rewrite | Threaded TCP server |
| m_output_linux/darwin/windows | Keep or replace | Platform console output |
| m_pipe_* | Keep | IPC pipes |
| sockets_go32v2 | Keep | DOS TCP/IP, no equivalent |

## Phase 3: Clean mdl/
After Phases 1-2, mdl/ shrinks to only custom code:
- TUI widgets (menubox, menuform, menuhelp, menuinput)
- Protocol implementations (Zmodem, BinkP)
- ANSI terminal emulator
- Platform-specific console IO
- DOS sockets (Watt-32)
- Threaded server

Delete replaced units (m_strings, m_datetime, m_fileio, m_types,
m_crc, m_quicksort, m_inireader, m_bits, m_logroller).

## Status

- [ ] Phase 1: MIS refactor (DEFERRED)
- [ ] Phase 2: BBS core refactor (DEFERRED)
- [ ] Phase 3: Clean mdl/ (DEFERRED)

## Notes

- g00r00 built everything on mdl — there are no native replacements in mystic/
- The TUI widgets (m_menubox etc) must stay — they're the sysop config UI
- The protocol code (Zmodem, BinkP) must stay — custom implementations
- uforkpty was contributed by fpc264irc maintainer for evga's mis fix
- utextmouse was for RIPscrip v1 mouse, never wired — retired to attic
- sdl.pas, sdl_ttf.pas, m_sdlcrt.pas moved to mystic_sdl/
