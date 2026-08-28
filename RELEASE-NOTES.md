# Mystic BBS 1.10 A38 — Community IRC Fork — Release Notes

**Release date:** 2026-07-09
**Base:** Mystic BBS 1.10 alpha 38 (A38), brought to ~1.10 A39 feature level
**Repository:** https://github.com/verta1878/mystic-bbs-irc
**License:** GNU General Public License v3 (GPLv3)
**Live node:** Ecstasy BBS — FidoNet 152/158 — tnabbs.org

This document is the single, complete reference for the release: what's in it,
which platforms it runs on, how the binaries and source are packaged, how to
build and install it, and what is and isn't finished. It supersedes scattered
notes; for day-to-day build detail see INSTALL and docs/.

================================================================================
## 1. What this release is

A clean, buildable, well-documented community fork of the Mystic BBS 1.10 A38
source, released under the GPLv3. The goal is a tree the BBS scene can build,
run, study, and carry forward across the platforms Mystic historically targeted
— now including a fully self-hosted **OS/2 build on Linux**.

Feature level is roughly Mystic 1.10 A39: the FidoNet tosser, JAM/Squish
compatibility, ANSI draw mode, themed message boxes, and the full message-base
index reader are all in. On-disk record layouts are held byte-compatible with
stock Mystic (RecConfig=5282, RecTheme=768, RecEchoMailNode=901, RecUser=1536),
so existing data files and third-party tools keep working.

================================================================================
## 2. Platform / build matrix

All 14 core programs (see §3) build for four platforms; a fifth (DOS) is
partial. Everything below is built from a single Linux host with FPC 2.6.2.

    Platform   Binaries  Format                 Toolchain
    --------   --------  --------------------   ---------------------------------
    Linux      14/14     ELF 32-bit i386        native ppc386
    Win32      14/14     PE32 i386 (XP+)        FPC internal PE linker
    macOS      14/14     Mach-O i386 (10.6+)    ld64 + Apple SDK (you supply)
    OS/2       14/14     LX (emx 0.9d)          self-hosted emx toolchain ON LINUX
    DOS        10/14     MZ/COFF/DJGPP go32v2   go32v2 cross toolchain (patched)

Notes:
  * **OS/2 is the headline.** The final OS/2 link (a.out -> LX .exe) now runs
    entirely on Linux — historically it required an OS/2 machine. See §6.
  * **DOS is 10/14, including the mystic server.** The socket layer is written
    and the binutils link blocker is solved (both bundled in the repo); the
    four networked utilities compile and are link-ready, needing only Watt-32
    (libwatt.a). See §8.
  * macOS binaries are built and linked but runtime-untested (i386 macOS needs
    a 10.4–10.14-era machine).

================================================================================
## 3. The 14 core programs

    mystic         the BBS server / login shell
    mis            Mystic Internet Server (telnet/IRC/socket services)
    mutil          maintenance utility (packing, indexing, imports)
    mplc           Mystic Pascal Language Compiler (menu/door scripts)
    mide           the script IDE
    mbbsutil       BBS utility helpers
    fidopoll       FidoNet/FTN mail poller + tosser
    nodespy        node monitor
    qwkpoll        QWK network poller
    mystpack       message base packer
    install        the installer (unpacks install_data.mys into a new BBS)
    install_make   builds install_data.mys from a data tree
    maketheme      theme builder
    109to110       1.09 -> 1.10 data converter

================================================================================
## 4. Optional example modules (mystic_*)

These are **separate, self-contained example modules** that show how the fork
can be extended. They are drop-in / runtime-loaded and do not touch the core
record layout. Each has its own README.

    mystic_rip     RIPscrip 1.x terminal engine (graphics terminal)
    mystic_sdl     full-screen SDL DOS-text renderer front-end
    mystic_spell   on-the-fly spell checking (Hunspell)
    mystic_crypt   optional SSH/TLS transport example (cryptlib)
    mystic_mailer  FrontDoor/BinkleyTerm-style FTN mailer front-end
    mystic_modem   real serial-modem dialup support
    mystic_misdos  recreation of the classic Mystic "MIS/DOS" behavior

================================================================================
## 5. Bundled runtime & build libraries (libs/)

Runtime libraries (i386, runtime-loaded — "drop-in DLL" model):

    libs/win32/       SDL2 2.32.8, libhunspell, cl32.dll (cryptlib) — Wine-verified
    libs/linux-i386/  SDL2, Hunspell, cryptlib
    libs/darwin-i386/ SDL2 2.0.1, Hunspell 1.6.2, cryptlib (built on 10.6 SDK)

Build toolchains (self-contained zips):

    libs/dos-toolchain.zip        FPC 2.6.2 compiler + go32v2 binutils + RTL
                                  (self-contained DOS cross toolchain)
    libs/os2-linux-toolchain.zip  the emx-on-Linux toolchain: emxbind Linux port,
                                  binutils patches + a.out-emx target, emxl.exe,
                                  ld wrapper, upstream emx sources, full docs
    libs/ld64-linux-x86_64/       cctools ld64 for the macOS cross-link

Each library is used under its own license (see the LICENSE files in libs/);
their inclusion is "mere aggregation" in the GPL sense. Match library bitness
to the build (all provided binaries are i386).

================================================================================
## 6. OS/2 on Linux — the self-hosted emx toolchain (headline feature)

FPC's OS/2 target compiles to a.out, then links via `ld` + `emxbind` into an
OS/2 LX executable. That link historically ran only on OS/2. This release makes
it run **entirely on a Linux x86-64 host** — the same problem the ArcaOS /
bitwiseworks maintainers track as an open "emx toolchain on Linux" issue.

    $ ppc386 -Tos2 ... maketheme.pas
    $ file maketheme.exe
    maketheme.exe: MS-DOS executable, LX for OS/2 (console) i80386, emx 0.9d

The solution has five parts, all included and documented:

  1. **binutils N_IMP patch** — teaches GNU ld to resolve emx a.out IMPORT#
     DLL symbols (N_IMP1/N_IMP2), the piece considered the hard blocker.
  2. **a.out-emx BFD target** — a new binutils target with emx's a.out layout
     (text at file 0x400, vaddr 0x10000, 64 KB data segment).
  3. **emxbind Linux port** — Eberhard Mattes' GPL emxbind built to run on
     Linux (32-bit build; getopt fix; small shim layer).
  4. **emxl.exe loader** — the emx loader stub emxbind binds into the image.
  5. **data-alignment ld wrapper** — places the data segment on the 64 KB
     boundary emxbind expects.

Build it: unpack `libs/os2-linux-toolchain.zip`, follow
`docs/os2-linux-toolchain/BUILD-ON-UBUNTU-24.04.md`, put the tools on PATH, then
`LINK=1 ./build-os2.sh`. Full technical reference (format, every fix, an
emxbind-error -> fix debug map) is in
`docs/os2-linux-toolchain/TECHNICAL-REFERENCE.md`; the patches are in
`libs/emxbind-src/binutils-patch/`.

emx is GPL (c) 1990–1998 Eberhard Mattes; the port and patches are offered under
the GPL. `UPSTREAM-EMX.md` is a paste-ready contribution writeup for
bitwiseworks/ArcaOS, FPC, and the emx project.

================================================================================
## 7. Building from source

Prerequisites: FPC 2.6.2 (i386) as `ppc386`; for OS/2 the emx toolchain on
PATH; for macOS an Apple 10.6 SDK (`SDK=...`). Full detail in INSTALL and
docs/os2-linux-toolchain/.

    ./build.sh                         # Linux   -> out/bin/          (14/14)
    ./build-win32.bat  (or the loop)   # Win32   -> out/bin-win/      (14/14)
    SDK=... ./build-darwin.sh          # macOS   -> out_darwin/bin/   (14/14)
    LINK=1 ./build-os2.sh              # OS/2    -> out/bin-os2/      (14/14)
    ./build-dos.sh                     # DOS     -> out/bin-dos/      (10/14)

Compiled-binary output directories (all gitignored — build output never enters
the repo):

    Linux out/bin   Win32 out/bin-win   macOS out_darwin/bin
    OS/2  out/bin-os2   DOS out/bin-dos

Cross-platform text: the BBS emits the right newline per target at runtime via
`LineTerm` in records.pas (CRLF for DOS/OS2/Win, LF for Linux/Mac). Shipped BBS
text artifacts (FILE_ID.DIZ, whatsnew, upgrade, .asc, .mnu) are pinned to CRLF
via `.gitattributes` so a Linux cross-compile still ships correct DOS text.

================================================================================
## 8. DOS status (10/14 — socket layer done; needs Watt-32)

DOS here means **32-bit protected-mode go32v2** (DJGPP; needs a 386+ and a DPMI
host, CWSDPMI). It is not a 16-bit real-mode (i8086) build — FPC 2.6.x has no
i8086 target. The go32v2 DOS toolchain (`libs/dos-toolchain.zip`) is
self-contained and now
ships PATCHED binutils. DOS builds **10/14**, including `mystic` (the BBS
server): the non-networked utilities, mide, mbbsutil, and mystic all compile
and link. The four networked utilities (mis, fidopoll, nodespy, qwkpoll)
compile and reach the link stage, failing only on undefined Watt-32 symbols —
i.e. they need `libwatt.a`.

What this session added (all in the repo):
  * **Complete socket layer** — `mdl/sockets_go32v2.pas`, a full FPC-`Sockets`-
    compatible BSD API (TCP+UDP, DNS, select, sockopts, address helpers) bound
    to Watt-32. The fork's socket code is unchanged; on go32v2 it simply
    `Uses sockets_go32v2` instead of the RTL `Sockets` unit (which FPC 2.6.2's
    go32v2 target does not ship). See docs/DOS-SOCKETS.md.
  * **binutils link fix** — FPC 2.6.x emits COFF storage class 0x68 (C_SECTION)
    for section symbols; stock binutils 2.30 coff-go32 rejected it, which broke
    linking any FPC DOS program against a C library. FPC 2.6.4irc r3 resolves this
    at the toolchain level: it bundles a go32v2 toolchain (bin/tools/i386-go32v2/)
    whose `ld`/`nm`/`objdump` read FPC's COFF output natively. (Earlier builds
    used a standalone binutils patch in libs/; r3 supersedes it.)
  * **mis/events/md5 code gaps closed** — DOS branches for stdin/stdout
    (`m_io_stdio`), disk pipes (`m_pipe`), ShellExec, and the go32v2 MD5 unit.

DOS concurrency model: Watt-32 is a real TCP/IP stack and handles MULTIPLE
concurrent sockets (it exposes `select_s()` for exactly that). The DOS
constraint is *no preemptive threads*, not "one connection." The correct design
is cooperative multiplexing — one process, non-blocking sockets, polled with
`select` — many connections, one thread. The current DOS `mis` `Execute` serves
one caller at a time as an initial-bring-up simplification; a cooperative
`select()` accept-loop is the planned multi-node upgrade.

Remaining for a networked DOS binary: build Watt-32 (libwatt.a) for djgpp;
`build-dos.sh` already wires `-lwatt` via `WATT32LIB=<dir>`. Then link-test and
run with a packet driver + WATTCP.CFG. See docs/DOS-SOCKETS.md.

================================================================================
## 9. The installer and the MYS payload

Mystic installs itself with its own tools — no external setup program:

  * `install` unpacks a working BBS from `install_data.mys`.
  * `install_data.mys` is the fork's **MYS** archive (version 3): **stored, not
    compressed** — 135 files across 6 sections (DOCS 3, DATA 18, TEXT 47,
    MENUS 24, SCRIPT 32, ROOT 11). Format defined in mystic/install_arc.pas.
  * `install_make` rebuilds the payload from a data tree (only needed if you
    change the stock menus/themes/scripts/data).

Full format spec and build detail: `docs/CREATING-THE-INSTALLER.md`.

================================================================================
## 10. Release artifacts & how they're packaged

### Per-target release directories
Each platform gets its own directory, holding a FULL install and an UPGRADE
bundle:

    release/
      lnx/  mysticlnxfull.zip     mysticlnxupd.zip
      win/  mysticwinfull.zip     mysticwinupd.zip
      mac/  mysticmacfull.zip     mysticmacupd.zip
      os2/  mysticos2full.zip     mysticos2upd.zip

    mystic<tag>full.zip   FULL    — 14 binaries + install_data.mys + docs +
                                    FILE_ID.DIZ labelled "<tag> FULL"
    mystic<tag>upd.zip    UPGRADE — 14 binaries + docs + FILE_ID.DIZ labelled
                                    "<tag> UPGRADE" (no payload; drop over an
                                    existing install)

Docs in every archive: whatsnew.txt, upgrade.txt, COPYING (GPLv3), and a
per-target FILE_ID.DIZ (CRLF).

### Building the archives
    ./make_release.sh <tag> <bin-dir> [full|upgrade|both] [out-dir]
    ./make_all_releases.sh [full|upgrade|both] [out-dir]   # every platform

`make_release.sh` strips build intermediates, generates the CRLF FILE_ID.DIZ,
adds docs, includes install_data.mys only in FULL, and writes into
`release/<tag>/`.

### Source release
    mystica38src<YYYYMMDD>.zip    the full source tree (this repo, minus .git and
                                  build output). Includes all sources, the
                                  optional modules, libs/ (runtime libs +
                                  toolchain zips), and all docs.

================================================================================
## 11. Documentation map

    README.md                        overview + quick build table
    START-HERE.md                    orientation + current state
    INSTALL                          full per-platform build instructions
    UPSTREAM-EMX.md                  paste-ready upstream contribution writeup
    COPYING                          GPLv3

    docs/CREATING-THE-INSTALLER.md   installer + MYS format + release process
    docs/DECISIONS.md                the running record of locked decisions
    docs/TODO.md                     open items (incl. DOS sockets)
    docs/SAVE-STATE.md               session-continuity snapshot
    docs/RIP-INTEGRATION.md          RIP graphics integration notes
    docs/os2-linux-toolchain/        the OS/2-on-Linux toolchain docs:
      README.md                        index
      TECHNICAL-REFERENCE.md           format + every fix + debug map
      BUILD-ON-UBUNTU-24.04.md         from-scratch reproduction recipe

    libs/README.md                   runtime-lib provenance + toolchain index
    libs/DOS-TOOLCHAIN-README.md     DOS toolchain usage
    libs/emxbind-src/                emxbind sources, shim, patches, status

================================================================================
## 12. Known limitations / open items

  * DOS: 10/14 (incl. the mystic server). Socket layer + binutils link fix are
    done; the 4 networked utilities need Watt-32 (libwatt.a). See §8.
  * macOS: built + linked, runtime-untested (needs an i386-era Mac).
  * OS/2: builds fully on Linux; live shake-out on real OS/2/ArcaOS is the gate.
  * Live FidoNet validation of the tosser on node 152/158 is sysop-side.
  * Version string reads "1.10 A38" internally while the DIZ shows the fork
    version — cosmetic, tracked in TODO.
  * Upstream emx contribution (UPSTREAM-EMX.md) is prepared but must be posted
    by the maintainer.

================================================================================
## 13. Licensing summary

  * The fork (all Pascal sources, scripts, docs): **GPLv3** — see COPYING.
  * emx / emxbind / the OS/2 toolchain patches: **GPL** (c) Eberhard Mattes;
    corresponding source in libs/emxbind-src/upstream/.
  * GNU binutils patches: **GPL**.
  * Bundled runtime libs (SDL2, Hunspell, cryptlib, ld64/cctools): each under
    its own license (see libs/*-LICENSE*.txt); "mere aggregation".
  * The Apple macOS SDK is NOT redistributed — the sysop supplies it locally.

================================================================================
## 14. Credits

Fork maintained by Antonio Rico (Reapern66). Base Mystic BBS (c) 1997–2013 by
James Coyle. emx / emxbind (c) 1990–1998 Eberhard Mattes. FidoNet node 152/158,
Ecstasy BBS (tnabbs.org).

---


## Session 6 — July 24-25, 2026

### ripviewer v1.0.0 — Full RIPtermJS Command Parity

**42/42 RIPscrip commands implemented** — all ported from RIPtermJS BGI.js.

#### Bugs Fixed
- **rcResetWindows (`!|#`) erased canvas** — was wiping pixel buffer right
  before BMP output. Fixed to reset viewport/cursor only (matching JS).
- **8×8 font instead of 8×16** — ans2rip outputs VGA 8×16 coordinates.
  Added vgafont.inc (8×16 CP437 ROM) and switched to MSB-first bit order.
- **EGA palette order vs CGA/ANSI order** — palette had indices 1=blue/4=red
  (EGA order) but ans2rip outputs SGR indices 1=red/4=blue (CGA order).
  Reordered palette constant to match ans2rip output.
- **Duplicate rcGotoXY handler** — removed.
- **'o' mapped to rcMove instead of rcFilledOval** — fixed parser.
- **rcMove orphan in enum** — removed ('m' = rcGotoXY is the move command).
- **Canvas height 350 too small** — increased to 1280 for multi-page ANSI
  (80 rows × 16px = 1280px).

#### Pixel-Perfect Verification
- **100.0% pixel match** (819,200 pixels, 0 mismatches) between ans2png
  reference and ripviewer output on sd-fluph test ANSI.

#### Drawing Primitives Added (ported from BGI.js)
- `DrawEllipse` — Bresenham ellipse outline
- `FillEllipse` — Bresenham filled ellipse with scanline
- `DrawArcLines` — trig-based arc with angle clipping (degree-by-degree)
- `DrawSector` — pie slice: arc + wedge lines + floodfill interior
- `FloodFill` — scanline stack-based flood fill
- `DrawBezier` — cubic Bezier curve (Bernstein polynomial)
- `FillPolyScanline` — scanline polygon fill (alienryderflex algorithm)
- `DrawRect` — rectangle outline via DrawLine

#### Command Handlers Added (26 new, 16 existing = 42 total)
Drawing: Oval, FilledOval, Arc, OvalArc, PieSlice, OvalPieSlice,
  Bezier, Polygon, FilledPolygon, PolyLine, Fill (FloodFill)
Style: FillPattern, LineStyle, WriteMode
Window: EraseView, EraseEOL, TextWindow, Viewport
Image: GetImage, PutImage, LoadIcon (stubs — skip args correctly)
Mouse: Mouse, KillMouseFields, Button, ButtonStyle (stubs)
Palette: SetPalette (all 16 entries)

#### Multi-char Command Parser
Expanded '1' prefix handler for: 1K, 1C, 1P, 1I, 1M, 1U, 1B commands.

#### Files Changed
- `mystic_rip/ripviewer/source/ripview.pas` — 599→1107 lines
- `mystic_rip/ripviewer/source/rip_font8x16.inc` — NEW (VGA 8×16 CP437 font)

#### Build Status
- ripviewer: 1107 lines, compiles clean (0 errors, 0 warnings)
- ans2rip: compiles clean
- All BBS binaries: compile clean

### ripviewer CLI Features

**File picker** — pass a directory to get an interactive numbered list:
  `ripview /path/to/rips/` → pick by number
  `ripview -l /path/to/rips/` → list only, no render

**Baud rate emulation** — `-b RATE` throttles rendering at simulated bps.
  Uses RIPtermJS formula: bytes/sec = baud/10 (8N1).
  Sleep per byte = 10000000/baud microseconds.
  Example: `-b 2400` renders 44KB file in ~183 seconds (real modem time).
  Supported: 300 1200 2400 4800 9600 14400 19200 28800 38400 57600 115200.

**Debug mode** — `-d` prints each command as it executes:
  `[42] !|B0D0FN0O0FZ` (line number + raw command)
  `  !|B0D0FN0O0FZ` (parsed command echo)
  Shows timing stats at end: lines, commands, milliseconds.

**Combo** — all flags work together: `ripview -d -b 9600 scene.rip out.bmp`

**Files:** ripview.pas 1330 lines, compiles clean, 100% pixel match preserved.

### ripviewer Free Vision GUI

**Compile:** `fpc -Mdelphi -dFREEVISION -Fu<fv-path> ripview.pas -oripviewgui`

Single source file, two targets:
- `ripview` — CLI mode (default, no defines needed)
- `ripviewgui` — Free Vision TUI (`-dFREEVISION`)

**GUI features (Free Vision TUI):**
- Menu bar: File (Open/Render/Stop/Quit), Baud, Debug
- File > Open: FV TFileDialog with *.rip filter
- Baud menu: Full Speed, 300-115200 bps
- Debug > Toggle: enable/disable command logging
- Debug > Clear: clear log
- Status line: file name, baud rate, debug state, command count
- F3=Open, F5=Debug, F9=Render, Alt-X=Quit

**1602 lines, both modes compile clean, 100% pixel match.**

### Modular Split

ripview.pas split into 7 units (1656 total lines):

**Shared (all versions):**
- `ripengine.pas` (87 lines) — canvas, palette, PutPixel, globals
- `ripdraw.pas` (286 lines) — line, rect, circle, ellipse, arc, bezier, floodfill, polygon
- `riptext.pas` (91 lines) — VGA 8x16 font, DrawBitmapChar, OutTextXY
- `ripbmp.pas` (70 lines) — BMP file output

**v1.54-specific (in v1/ subdirectory):**
- `v1/rip1parse.pas` (137 lines) — mega decoder, TRIPCommand enum, parser
- `v1/rip1exec.pas` (426 lines) — 42-command Case dispatcher

**Main program:**
- `ripview.pas` (559 lines) — CLI + FV GUI, file picker, baud, debug

Build: `fpc -Mdelphi -Fuv1 ripview.pas`

v2/v3/v4 can add their own `v2/rip2parse.pas`, `v2/rip2exec.pas` etc.
while sharing the engine, drawing, text, and BMP units.

---

## Session 7 — August 19-28, 2026

### mterm Terminal Emulator (MT-1 through MT-5 DONE)
- Stripped Free Vision, migrated to MDL Console/Keyboard
- Menu hotkeys, status bar, virtual pages
- ANSI terminal engine: 80x22 cell buffer, CSI parser, SGR, scroll regions,
  device status reports, RIP auto-sense, line wrap mode
- Phonebook dialog: scrollable list, Add/Delete/Edit, saved to mterm.phn

### RIP v1.54 Engine — MT-14 DONE (all 53 commands)
- Fixed 5 bugs: =/W swap, l=polyline, 1G=CopyRegion, 1D=Define, CmdLineStyle
- Implemented 10 commands: E, V, i, g, m, >, W, =, a, Q
- EGA64-to-RGB palette conversion, live modifiable FPalette
- Text variable system, ProcessFile for recursive scene load
- File Query with FILEERR variable, ICN writer (EGA bitplane encoding)
- SDL_mixer audio (mtsound.pas): WAV/MID/MOD/MP3/OGG
- All 53 v1.54 commands dispatched, zero stubs
- 125/225 corpus test files pass x 3 runs

### ANSI Engine — MT-15 DONE
- 11 CSI + 5 ESC sequences added
- Scroll region, line wrap, RIP auto-sense, device status responses

### MT-16 — BGI CHR Stroked Font Parser
- m_rip_chrfont.pas (340 lines) — standalone MDL unit
- Built from Easy Fonts v2.0 docs by Pino Navato (registered to verta1878)
- CHR format fully decoded: PK header, offset table, width table, stroke data
- All 10 Borland CHR fonts load (BOLD, EURO, GOTH, LCOM, LITT, SANS, SCRI,
  SIMP, TRIP, TSCR — 2169 to 7785 strokes each)

### RIP API v1-v4 — All Updated
- WriteIcon implemented across all 4 engines (was no-op)
- ClipValid, SanitizePath, WriteClipboardICN helpers added
- Versions: 1.0.1-irc, 2.0.1-irc, 3.0.1-irc, 3.1.0-irc
- v1-v3 retired to attic/ with RETIRED headers

### Architecture Decisions (with hexadecimal)
- ONE server engine (m_rip.pas from v4) with plugin codec registration
- mtrip.pas stays as lightweight client parser (946 lines)
- Server vs client = different architectures, not size trade-off
- Handler registration same mechanism as codecs (prnapi.pas pattern)
- DOS i8086 real-mode confirmed, row-pointers from day one
- SavedScreens 2.24MB issue identified, capped for DOS
- Provenance markers required during engine merge
- Four engine versions = four platform tiers (i8086 through 1995 multimedia PC)

### PCBDraw — ansiedit PCBoard Support
- m_door.pas in mdl/ (drop file reader, 309 lines, 29/29 tests pass)
- m_pdpcboard.pas updated with LoadAtX/SaveAtX (@X format)
- 9 PCBD phases documented
- RIPKit 1.20 analyzed (313 RIP screens, 30 PPL scripts, 8 menus)
- .mrp menu extension documented (8.3 compatible)

### Bug Fixes
- RecConfig one-byte drift: Reserved 552->553 (SizeOf=5282 PASS)
- build-linux.sh libpthread/libdl probe adapted for glibc 2.34+

### Repo Cleanup
- Consolidated all RIP assets to examples/ripart/ (226 art, 222 icons, 18 fonts)
- Removed all duplicate MDL units from mterm/ansiedit
- Moved standalone programs from mdl/m_rip/ to mystic_ripview/tools/
- Moved 345 RIP docs to attic/
- Created mystic_mterm/ and mystic_molms/ as top-level directories
- cleanup.bat: 8-section repo cleanup script (65 files cleaned, 0 errors)

### New Phase Docs
- todo/RIPKIT-PCB-HOWTO.md — RIPKit 1.20 analysis, PPL-to-MPS porting plan
- todo/RIP-PLATFORM-TIERS.md — v1-v4 as platform tiers
- todo/OPENOLMS-MOLMS-MIGRATION.md — 10 phases
- todo/ANSIEDIT-MDL-MIGRATION.md — 9 phases

### Team (10 members)

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

Motto: the crew 4free

---

## Session 8 — August 28, 2026

### mystic_makemenu — Menu and Text Editor (NEW)

Created complete standalone menu/text editor example:

- makemenu.pas — Menu editor with theme selector, -demo, -txt, -? modes
- maketext.pas — 516 prompt stub generator from default.txt
- mrpdata.pas — Standalone menu data (load/save .mnu binary + .mrp text)
- rendermrp.pas — Pixel-perfect 640x350 EGA BMP renderer

### MDL m_rip/ Updates

- mripchr.pas (was m_rip_chrfont.pas) — CHR stroked font parser, 10 fonts
- mripui.pas (was mripwiz.pas) — Built-in MRP widget renderer
  6 widget types: Box, Window, Frame, Dialog, ButtonUp, ButtonDown
  Widget concept inspired by JMedia v2.0 WIZ format (credited)
- rip_surface.pas — Fixed font8x8.inc include and flat array access
- All filenames 8.3 DOS compatible

### RIPKit 1.20 Analysis

- RIPKIT-PCB-HOWTO.md — 313 RIP screens, 30 PPL scripts, 8 menus
- .mrp format documented in RIP-UI-PLAN.md (947 lines)
- WIZ/J authoring merged into .mrp section
- Screen modes (EGA 640x350, VGA 640x480) documented with FPC ptcgraph

### Private Study (not released)

- JDraw Pro v4.2, JMedia v2.0, JView v6.0 — RIP authoring tools
- Easy Fonts v2.0 (registered to verta1878) — CHR font documentation
- Tombstone Artist v2.0, ElyEdit v4.0, Empathy v1.00p
- DOSBox-X environment with TP7, BP7, BC31, TC201, all study programs
- JMedia .J scripting format and WIZ widget templates studied

### Repo Cleanup

- cleanup.bat updated with /Q flags, pure ASCII, append mode
- RELEASENOTES.md merged into RELEASE-NOTES.md
- mystic_editmrp/ renamed to mystic_makemenu/
- All files renamed to 8.3 (mripchr, mripui, tchr, tui)
- 37 programs compile, 0 failures

### Compile Results

37 PASS, 0 FAIL across all programs:
- mdl/m_rip/: 9 units + 2 tests
- mystic_ripview/: 10 tools + 12 source units
- mystic_makemenu/: 4 programs
- mystic_mterm/, mystic_ansiedit/, mystic_test/: all clean

### Team (10 members)

the crew 4free
