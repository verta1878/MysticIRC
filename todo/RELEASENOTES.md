# Mystic BBS 1.11IRC — Release Notes

**Release: July 2026**
**Status: Alpha Testing**
**Base: Mystic BBS 1.10 Alpha 38 GPL Source**
**Compiler: FPC 2.6.4irc r3.1+**
**License: GNU General Public License v3**

## What is 1.11IRC?

A community fork of Mystic BBS maintained by Antonio Rico (Reapern66),
Ecstasy BBS, FTN node 1:152/158. All alpha patches A41 through A63
ported from g00r00's official releases. Built with the fpc264irc
community compiler fork.

## New Features

### RIPscrip Rendering Engines (v1-v4)
- v1: Complete RIPscrip 1.54 — 51 commands, 16-color EGA, CHR fonts
- v2: 256-color, 1280x1024, JPEG/PNG, WAV streaming
- v3: 16M TrueColor, 11 image formats, MIDI FM synth, 4-stream audio
- v4: HTML 1.0 renderer, MPEG-1 video, Print API, Unicode/TTF, FLI/FLC
- 1,433 automated tests across all engines
- All codec filenames DOS 8.3 compliant

### Internal File Transfer Protocols
- Xmodem (CRC-16, 1K blocks)
- Ymodem (batch, Block 0 file info)
- Ymodem-G (streaming, no per-block ACK)
- Zmodem (1K, 8K, 32K blocks, CRC-32, crash recovery)
- Kermit (7-bit safe, CRC-16, parameter negotiation)
- HS/Link source archived as reference (GPLv3, Pascal port planned)

### HTTP File Server
- Built into MIS on port 8080
- Serves static web pages from webroot/ directory
- File downloads via FTP Name mapping
- HTTP/1.0, Content-Type detection, path traversal protection

### FTP Server Fixes
- SIZE command implemented (was "not implemented")
- REST command added for resume support
- PASV endian fix for passive mode
- SendFile error handling improved

### Media Support
- MediaTag unit: reads MP3 (ID3v1/v2) and MP4 (iTunes atoms) metadata
- AViewMeta: media tag viewer integrated into BBS file base
- MARC archiver: internal ZIP pack/unpack/list + media tag display

## Ported Alpha Patches (A41-A63)

### A41-A44 (27 items)
Initial port — FPC build fixes, platform detection, record alignment

### A45-A50 (38 items)
BINKP improvements, FidoNet compliance, socket fixes

### A51 (4 items)
Auto-ban, MIS crash fix, socket flush, CTRL+U

### A52 (14 items)
CTRL-P, |SS/|RS MCI codes, BINKP resume, mouse infrastructure

### A53 (13 items)
Area snap, pipe strip, group_list

### A54 (1 item)
IgnoreGroup restore

### A55 (4 items)
Record locking, X hotkey, BINKP_DEBUG

### A56 (17 items)
Argus auth, date 2070, BINKP NR, chat commands

### A58 (4 items)
Node chat colors, private base Enter

### A59 (3 items)
Kludge preservation, QWK Sent flag

### A60 (12 items)
goodip.txt whitelist, BINKP junk protection, Zmodem 32KB,
MPL AppendText, CfgChatStart/CfgChatEnd, LZH/LHA viewer

### A61 (16 items)
Output buffering, @TEXTDIZ/@TEXTVIEW/@TEXTSHOW, DI baud rates,
hourly events, DOS CRLF export, 80-char auto-wrap fix

### A62-A63
Version-bumped to 1.11IRC final. No code changes.

## New Subsystems
- uforkpty.pas: pure FPC forkpty() — no libc dependency
- mutil_filetoss.pas: TIC file tosser (FTS-5006.001/FSC-0087)
- netmodem_fossil.pas: FOSSIL INT 14h serial test for DOS

## Bug Fixes
- BUG-038: RIPscrip decimal vs MegaNum range error (RESOLVED)
- BUG-029: AnsiString concat crash under {$H-} on Win32 (FIXED)
- PASV endian fix in FTP server
- FTP SIZE/REST implementation
- HTTP header ShortString overflow fix

## Build Platforms
- Linux i386: 15/15 binaries
- Windows PE32: 15/15 cross-compiled
- DOS go32v2: 9/9 binaries
- OS/2 EMX: compiles, needs emxbind

## Known Issues
- default.txt prompt count must match mysMaxThemeText (515)
- HTTP server port 8080 hardcoded (no config UI yet)
- FTP download prompt (528-531) not wired into file base yet
- Web download option ([W]) not implemented (HTTP stub was empty)
- MPL scripts may need recompilation after upgrade

## Mystic BBS 1.11IRC Alpha 1 (July 24, 2026) — Final (untested alpha)

**g00r00 1.11 A1 port — 13 items:**
- MPL: Records passed by VAR reference (compiler + interpreter fix)
- Embedded ANSI support in message reading
- ANSI upload/edit in full screen editor with auto pipe-code conversion
- ANSI abort: waits for sequence completion, time-based checking
- File listing search performance (6x I/O reduction)
- FIDOPOLL blank hostname check
- Node chat /topic lockup fix + blank topic reset
- Install F2/ESC selectable with arrow keys
- ENTER aborts send node message

**IRC fork items:**
- HS/Link clean-room Pascal port (1,067 lines, 55 tests, all C features)
- HS/Link standalone program (DOS + Win32)
- FOSSIL/serial stack imported to mdl/ (m_fossil, m_serial, m_fossil_io)
- m_mouse.pas restored for cross-platform text-mode mouse
- RIP code isolated to mystic_rip/ (not in BBS core)
- ansi2pipe.pas utility compiles clean
- docs/PORT-111.md: g00r00 1.11 A1-A6 porting checklist (38 items)

**Test scripts** (all compile, none runtime tested):
- `scripts/testrec.mps` — Record VAR parameters
- `scripts/testarr.mps` — Multi-dim arrays in records
- `scripts/testrecfn.mps` — Record function return + `Var := Func()` call site
- `scripts/testdate.mps` — TimerMS, FormatDate masks, DateStr formats 4-6
- `scripts/appendtext_demo.mps` — AppendText procedure
- `scripts/chatcheck_demo.mps` — CfgChatStart/CfgChatEnd (Uses CFG)

**Reference files:**
- `mplfunc.txt` — 237 functions/variables, all with descriptions
- `mplref.txt` — Detailed examples for every new feature

**MIDE improvements:**
- RECORD and ARRAY added to syntax highlighting
- Help > Index: searchable function list from mplfunc.txt
- Help > Under Cursor: look up word at cursor position
- Improved error messages with fix hints

**Upgrade notes:** Run `mplc -ALL` to recompile all MPL scripts.

### 1.11IRC Alpha 4 (July 24, 2026)
- MUTIL echomail export resume tracking (user 0 lastread)
- TIC REPLACES keyword handling
- Editor strips kludge/tear/origin on load, regenerates on save
- Quote buffer overflow crash fix

### 1.11IRC Alpha 5 (July 24, 2026)
- Forward message strips and regenerates network info
- MPL multi-dim arrays in records: proper offset calculation (bytecode change)
- MPL FormatDate(DosDate, Mask) function (fn 563)
- MPL record function Var := Func() call site fully working
- MIDE Help system: Index, Under Cursor, Help on Help
- mplfunc.txt (237 entries) + mplref.txt (full examples)

### 1.11IRC Alpha 6 (pending)
- g00r00 1.11 A6: ANSI draw mode FSE + Amiga font Linux fix
- Last g00r00 alpha to port

### 1.11IRC Alpha 7 (July 24, 2026 — IRC fork Phase 2)
- FOSSIL/serial wired into mystic.exe: TIOFossil adapter,
  -COM and -FOSSIL command line flags, no MIS needed for dial-up
- Print API backport to v1-v4: version-independent, any framebuffer
  resolution, 6 drivers (ESC/P, PCL, PostScript, BMP, Raw)
- mis_client_serial removed — MIS is TCP only, FOSSIL is direct-run
- MDL refactor: pending
- OS/2 target via fpc264irc EMX linker (working, slow compile)

**ANSI to RIP Converter (ans2rip v2.3):**
- Pixel-perfect ANSI→RIP conversion (100% ImageMagick verified)
- 44KB output for 62KB ANSI (31x smaller than v1.0 pixel bars)
- VGA 8x16 font ROM for exact glyph rendering
- CGA palette 171/87 (not 170/85 — key discovery)
- Text-based emission: !|@ commands instead of per-pixel bars
- RIPtermJS-verified: ! safe in text, charsize 2 = 16px height
- -pd flag for PabloDraw compatibility (ASCII-only text)
- ans2png: pixel-perfect ANSI→BMP renderer (100% match)

**Reference material added:**
- examples/ripterm154/ — Original RIPterm 1.54 DOS binary (Carl Gorringe archive)
- examples/riptermJS/ — Carl Gorringe's JavaScript RIP viewer (GPLv3)

**Deferred to 1.12IRC:** FTP prompts, HTTP config

### 1.11IRC Alpha 2 (July 24, 2026)
- TZUTC kludge on echomail messages (FTS-4008 compliant)
- ANSI escape sequences stripped from quoted text

### 1.11IRC Alpha 3 (July 24, 2026)
- MPL: Functions can return record types
- MPL: TimerMS millisecond timer (function 562)
- MCI codes |-Y and |-N for Yes/No prompt defaults
- DateDos2Str/DateJulian2Str formats 4-6 (4-digit year)
- FormatDate mask function ready (YYYY YY MM DDD DD HH II SS NNN)
- MUTIL mass upload: better DIZ logging, temp dir purge
- Reset inactivity timeout after file transfer
- Searchlight prompt menus: functional, unverified vs g00r00 rework
- HTTP server configuration in mystic.dat
- Protocol menu strings in language file

## Credits
- g00r00 (James Coyle) — original Mystic BBS author
- Antonio Rico (Reapern66) — fork maintainer
- evga — contributor
- fpc264irc maintainers — compiler fork
- Samuel Smith — HS/Link protocol (GPLv3 re-release)

## Links
- Source: https://github.com/verta1878/mystic-bbs-irc
- Compiler: https://github.com/verta1878/fpc264irc
- FTN: 1:152/158 (Ecstasy BBS)
