# TODO / ROADMAP — Mystic BBS A38 Fork ("IRC")

> The ONE canonical roadmap. Read this first on resume.
> This file is FORWARD-LOOKING (what's left). For what's already DONE, see
> **whatsnew.txt** (user-facing changelog). For the deep record of *why* every
> change was made — decisions, corrections, "do NOT revert" notes, research
> findings — see **DECISIONS.md** (~1900 lines). Build instructions: **INSTALL**.

--------------------------------------------------------------------------

## STATUS (2026-07-08)

The substantive A39 feature-import work is essentially COMPLETE. The full list
of what landed is in whatsnew.txt; in brief: the FidoNet tosser subsystem, JAM
A51-compatibility, the ANSI draw mode, themed message boxes (|#B/|#I + the theme
editor screen), and the full message base index reader with its template
subsystem. All build 14/14 on win32 + linux, compile clean for Darwin, and are
cross-checked against the stock A51/A49 binaries. On-disk data format unchanged
(anchors SizeOf RecConfig=5282 / RecTheme=768 / RecEchoMailNode=901).

NEW (2026-07-08): RIP graphics Phase 1 landed — the ripterm client engine is
now IN THE TREE as a self-contained example module, mystic_rip/ (TTermRip in
rip_term.pas — the TTermAnsi parallel — plus the rip_canvas seam, software
surface, SDL viewer and demos; FPC RTL units only, no mdl deps). Verified
both platforms; renders pixel-identical to the client reference. Promotion
to mdl/ happens at the live hook-up. Design + status: docs/RIP-INTEGRATION.md.
Phases 2/3 below (item 4).

What remains on the A39 side is not more porting — it's PROOF. See item 1.

--------------------------------------------------------------------------

## ORIENTATION (on resume, do this first)

  1. cd /home/claude/mystic-src/msrc110a38
  2. Confirm the tree + FPC 2.6.2 are present; run a baseline build before new
     work. If the container reset wiped the tree, restore from the latest
     mystic-A38fork-source-*.zip in /mnt/user-data/outputs/, then re-read this
     file + DECISIONS.md.
  3. Invariants to verify after ANY records.pas change:
       SizeOf(RecConfig)=5282, SizeOf(RecTheme)=768, SizeOf(RecEchoMailNode)=901
  4. Ground truth for "what shipped": the A51 binaries (1.10) and A49 binaries
     (1.12). Real board .jdx/.jhr files are the ultimate proof for JAM/data
     behavior. User-facing UI strings are conclusive; internal symbol names are
     not (may not appear in `strings`).
  5. Build check = 14 programs, both platforms, plus Darwin-compile clean. See
     INSTALL.

--------------------------------------------------------------------------

## 1. FINAL VALIDATION GATE — Live FTN testing on the board (SYSOP to run)

Node 152/158, tnabbs.org. Nothing else matters as much as this. Everything
compiles and matches the shipped binaries, but none of it is truly proven until
real echomail flows through a live node.

Test on the board:
  - Tosser inbound: import a real packet; confirm dupe detection catches a
    re-sent message (SEEN-BY aware).
  - Tosser outbound: bundle + queue mail; confirm it routes to the right uplinks
    via GetNodeByRoute; check the FLO queue.
  - Semaphore .out files: confirm they trigger the tosser.
  - Hide AKAs: enable on a node, poll an uplink, confirm only the uplink's-zone
    AKAs are advertised in the BinkP handshake.
  - RefuseForeign: mis.ini RefuseForeign=false accepts foreign-domain mail;
    =true (or no file) rejects it.
  - AreaFix (echofix): subscribe/unsubscribe an echo, confirm it works.
  - Index reader (NEW): menu command 'I' / MI opens the message base index —
    a searchable list of all bases with total/new/personal counts; scroll,
    search, select to read. Needs the ansimidx.* files (in default_theme_text/)
    dropped into the theme's text dir, and at least one message group.

Whatever surfaces here IS the next real work.

--------------------------------------------------------------------------

## 2. OPTIONAL POLISH (deferred by choice — current behavior works)

  (Nothing currently pending.  The RefuseForeign setting was moved from the
  interim data/mis.ini into the config editor — Config -> Servers -> SMTP Server
  -> Allow Foreign — on 2026-07-07; see whatsnew.txt / DECISIONS.md.)

--------------------------------------------------------------------------

## 3. OPEN INVESTIGATIONS (watch, need live observation — don't necessarily act)

  - ZMODEM "transfers stopped": the nodespy protocol-layer unification (m_prot_*
    vs old m_protocol_*) MAY be relevant. Live testing will tell. The 2TB figure
    is impossible by protocol (32-bit offset); likely escaping/timing.
  - XP socket anomaly: code binds AF_INET6/'::' dual-stack; XP has no IPv6 yet
    accepts telnet. Mechanism unknown. KEEP the working code, flagged.
  - ANSI high-ASCII bleeding (chars 128-255): in output (m_output_*) AND parser
    (bbs_ansi*); strStripPipe a candidate.

--------------------------------------------------------------------------

## 4. RIP GRAPHICS — ALL PHASES COMPLETE

51/51 RIPscrip v1.54 commands implemented. 48 tests passing.

### Completed

- **Phase 1** (core drawing): c W = m X L R B C O o F @ T M K e E (17 cmds)
- **Phase 2** (full Level 0 + Level 1): arcs, bezier, viewport, text window,
  palette, font style, fill style, buttons, text blocks, clipboard, icons,
  mouse regions, query response (28 more cmds)
- **Phase 3** (final 6): Polygon/FillPolygon/Polyline with point array
  parsing, Define (\$variable storage), ReadScene (file includes),
  FileQuery (host file check with reply)

### Engine files (mystic_rip/)

- rip_term.pas (599 lines): parser + Level 0/1 command dispatch
- rip_canvas.pas (157 lines): 49 abstract methods
- rip_surface.pas (765 lines): software 640x350 rasterizer, all methods
- rip_window.pas: SDL2 presenter
- rip_render.pas: headless .RIP to BMP
- ans2rip.pas: ANSI-to-RIP converter (PabloDraw compatible)
- mkicons.pas: .ICN icon generator
- test_phase3.pas: 48 tests

### Mystic integration (mystic/)

- records.pas: TERM_RIP, ThmAllowRIP, UseRipDetect, IconPath/FontPath
- bbs_core.pas: theme path halt (all 5 paths checked)
- bbs_cfg_main.pas: Other menu (14 items), TAnsiFileViewer log viewer
- bbs_cfg_theme.pas: Icon Path + Font Path fields, Allow RIP flag
- bbs_cfg_syscfg.pas: Terminal toggle 0-4 (adds RIP)
- bbs_ansi_console.pas + bbs_term_ansi.pas: MDL-free TTermAnsi
- maketheme.pas: cfgtheme prompts Icon/Font paths, creates dirs

### Content (mystic_rip/)

- 32 display .rip files, 5 menu .rip files, 85 example .RIP art
- 8 .icn icons, 10 .CHR fonts, HOWTO doc


## 5. OS/2 TARGET — source done, native link + live test outstanding

  Source ported and compiles 14/14 for i386-os2 (cross, compile-only) as of
  2026-07-08; details + toolchain in docs/DECISIONS.md. Remaining:
  - OS/2 NATIVE LINK: the container can compile but not link OS/2 (needs
    emxbind + EMX OS/2 import libs; FPC's os2 link is ld-then-emxbind). Build
    natively on OS/2/eComStation/ArcaOS with the FPC 2.6.2 OS/2 release
    (period-matched to this fork's compiler). This produces the actual .exe.
  - LIVE SHAKE-OUT on real OS/2: m_io_stdio's OS/2 WaitForData is a blocking
    stub (revisit with DosPeekNPipe if a nonblocking poll is needed); confirm
    so32dll TCP/IP sockets, TProcess per-node spawning, and door drop-file
    behavior. Sysop has OS/2 history - this is his gate.
  - Optional: once linking works, wire an os2 arm into build.sh (today it's
    linux/win32/darwin).

--------------------------------------------------------------------------

## 6. 1.12 FILE_ID / DIZ support (9a + 9b DONE)

  9a DONE (2026-07-09): color-aware DIZ. mdl/m_strings.pas strDizColor()
  preserves pipe codes + converts ANSI SGR color to pipe; wired into
  bbs_filebase ReadDIZ and mutil_upload. Verified 14/14 + unit test.
  Still pending (minor, fold in later):
  - @BEGIN_FILE_ID.DIZ inline-tag scanner (description embedded in a text file).
  - Raise the desc line cap toward 99 (mind mysMaxFileDescLen=50 + MsgText).
  - Wildcat/PCBoard/WWIV color notations (only ANSI+pipe handled so far).
  9b DONE (2026-07-09): full-screen FILE_ID.ANS archive viewer.
  TFileBase.ShowFileIDAns extracts FILE_ID.ANS (same ExecuteArchive path as
  the DIZ reader) and shows it via OutFile; hooked into ArchiveView (auto-
  shows cover on open) + an 'A' key to redisplay. Reused existing PArchive/
  ExecuteArchive/OutFile infra. 14/14 build.
  Intentionally skipped (niche): @BEGIN_FILE_ID.DIZ inline scanner,
  Wildcat/PCBoard/WWIV color notations, desc-width 50->79 (all-desc change).

## 7. cryptlib win32 cross-build (feasibility proven; finish the wiring)

  Answered: cl32.dll CAN cross-compile with mingw. docs/patches/
  cryptlib-mingw-endian.patch (one endian branch) makes the entropy module
  random/win32.c compile under i686-w64-mingw32. Remaining: wire cryptlib's
  makefile win32 target (target-init win32 + WIN32ASMOBJS) to the mingw prefix
  and link the DLL, then drop it in libs/win32/cl32.dll. Or use a vendor
  (commercial-license) DLL. See DECISIONS.md 2026-07-09.

## 8. Release packaging (tooling done; use it per build)

  file_id.diz = master example (literal "xxx BINARIES"); 6 per-target files
  file_id.{win,lnx,os2,mac,dos} each have their tag filled in.
  make_release.sh <tag> <bin-dir> copies file_id.<tag> into a per-target
  archive renamed to FILE_ID.DIZ. One archive per target, never combined.
  (dos DIZ exists; no dos build target yet - come back to it.)

--------------------------------------------------------------------------

## 9. Adopt FPC 2.6.4irc as the default compiler — DONE (verify remains)

  GOAL (met): FPC 2.6.4irc release r3.1 (libs/fpc264irc.tar.gz) is now the DEFAULT
  project compiler, replacing 2.6.2.

  Done (2026-07-12):
   - Bundle upgraded to r3.1 (self-sustaining: ships its own as/ld/ar via the
     3-tier fallback; see fpc264irc/docs/tier_fallback_system.md).
   - Verified r3.1 COMPILES the Mystic tree: it built all 7 core units +
     mplc.o clean in-container (only the final link stalled on the container's
     known slow-ld, which hits 2.6.2 identically - not an r3.1 issue).
   - Build-script headers + docs (START-HERE, BUILDING, libs/README, DECISIONS)
     updated to name r3.1 as the default. PPU wordversion unchanged vs stock 2.6.4
     -> record anchors safe by construction.

  Remaining verification (not blockers to it being default):
   - Full 14/14 build on win32 + linux end-to-end under r3.1 (link included) once
     the container link path is unblocked, or on the sysop's machine.
   - Run tests/a40/run.sh under r3.1 (FPC= -> fpc264irc/bin/ppc386).
   - Anchor re-check (5282/768/901/1536) after a full r3.1 build.
   - Live smoke test on the board.

## 10. Clean up libs/ + source-code COMMENTS (SYSOP GOAL)

  GOAL: tidy the comment/header cruft across libs/ and the Pascal sources.
  Known stale items to sweep (cosmetic - none affect builds):
   - build-*.sh / build-*.bat headers still say "1.10 A38 fork" though the tree
     now carries A40 work (see docs/BUILDING.md note).
   - Any remaining "A39"-era comments / version strings in sources and libs/
     READMEs that no longer match where the fork is.
   - Normalise/refresh libs/ per-toolchain READMEs where they drifted.
  Do this as a dedicated pass so a comment sweep never mixes with a code change
  (keeps diffs reviewable). No behaviour change intended.

--------------------------------------------------------------------------

## INTENTIONAL DIVERGENCES — do NOT "align" these back to A39/A51

  - qwkpoll PrintLog: our qwkpoll logs each poll line to a timestamped
    qwkpoll.log (fork enhancement). A39/A51 use plain WriteLn. KEEP OURS.
  - RefuseForeign via mis.ini: fork-original; A51 hardcodes the refusal. Ours is
    a strict superset (identical by default, adds an escape hatch).
  - JAM CRC = StringCRC32 (raw), matching A51/1.10. Verified vs real board data.
    NOTE: 1.12 uses LOWERCASED JAM CRCs (per A34 changelog) — a known
    1.10-vs-1.12 divergence. Correct for our 1.10 base; do NOT undo without real
    1.12 data.
  - GetMBaseByIndex kept returning Boolean (ours) vs A39's LongInt. AreaIndex was
    adapted to our Boolean API; all our callers rely on it.

--------------------------------------------------------------------------

Everything done is in whatsnew.txt; every decision + rationale is in DECISIONS.md
(incl the JAM CRC 1.10-vs-1.12 timeline, the template subsystem, A49 cross-checks,
and SizeOf anchors). A fresh session picks up from item 1.

o7

## DOS port - networking (socket layer DONE; needs Watt-32 libwatt.a)

Scope: 32-bit protected-mode DOS (go32v2/DJGPP, needs 386+ and CWSDPMI). NOT
16-bit real-mode - FPC 2.6.x has no i8086 target.

DONE (2026-07-09): DOS builds 10/14, including the mystic server. The socket
layer is written and the binutils link blocker is solved - both in the repo.

  - mdl/sockets_go32v2.pas: a complete FPC-Sockets-compatible BSD API (TCP+UDP,
    DNS, select, sockopts, address helpers) bound to Watt-32. The fork's code
    is unchanged; go32v2 `Uses sockets_go32v2` in place of the RTL Sockets unit
    (which FPC 2.6.2's go32v2 target does not ship). This keeps the fork's code
    Pascal on our PINNED 2.6.2 - no risky re-pin to 3.0.4/3.2.2, so the SizeOf
    record anchors stay intact.
  - The C_SECTION(0x68) COFF link fix (so ld reads FPC objects) is now handled
    by FPC 2.6.4irc r3.1's bundled go32v2 toolchain (bin/tools/i386-go32v2/), which
    emits/reads the proper COFF section attributes. (The old standalone
    libs/dos-binutils-patch/ was removed - r3.1 supersedes it. NOTE: r3.1 also ships
    a go32v2 Sockets unit, so whether the fork still needs mdl/sockets_go32v2.pas
    is an open question to settle during live DOS testing under r3.1.)
  - DOS code gaps closed: m_io_stdio, m_pipe, mis_events ShellExec, go32v2 MD5.

REMAINING - build Watt-32 (libwatt.a) for djgpp/go32v2:
  - build-dos.sh already wires the link: set WATT32LIB=<dir-with-libwatt.a> and
    it adds -Fl<dir> -k-lwatt. With libwatt.a present the 4 networked programs
    (mis/fidopoll/nodespy/qwkpoll) link.
  - Watt-32 is external C (a real TCP/IP stack + a runtime packet driver), NOT
    bundled - it is a build/runtime dependency like a driver. Candidate sources:
    the jwt27/watt32 djgpp cross-compile fork, gvanem/Watt-32, sezero/watt32.
    Check the specific fork's LICENSE before bundling any Watt-32 SOURCE (the
    old Waterloo "may not sell" clause is non-standard; not legal advice).
  - Then: link-test, and runtime shake-out with a packet driver + WATTCP.CFG.

CONCURRENCY: Watt-32 handles multiple concurrent sockets (it has select_s). The
DOS constraint is no preemptive threads, not "one connection". The DOS mis
Execute currently serves one caller at a time (bring-up simplification); a
cooperative select() accept-loop for multiple concurrent nodes is the planned
upgrade. See docs/DOS-SOCKETS.md.

## 11. Configuration Editor + ANSI Editor + Server-side RIP (2026-07-17)

### Completed

**TEditorANSI unified editor** — merged TConfigEditor + TAnsiFileViewer
into g00r00's TEditorANSI class. Four modes in one class:
- Normal mode (FileMode=False, DrawMode=False): message editor
- File mode (FileMode=True): text file editor, 8-item ESC menu
- View mode (FileMode=True, FileReadOnly=True): log viewer, 5-item ESC
- Draw mode (DrawMode=True): ANSI editor with graphical draw menu

**cfg Other menu** — 14 items fully wired:
- A ANSI Editor, T Text Editor, L View Log Files, R RIP Editor
- N-G Edit config files (badnames, bademail, newletter, etc.)
- C Reset Caller Data (with SystemLog), V Version Info, X Exit

**FilePickerDialog** — in bbs_edit_ansi.pas (shared by text + ANSI editor):
- Arrow key navigation with highlighted selection bar
- .. parent directory, subdirectories with trailing \
- File sizes, <DIR> markers
- DELETE key deletes files (with confirmation)
- ESC cancels, Enter selects

**g00r00 editor features** (from whatsnew.112):
- Ctrl+X exits editor, asks to save if file changed
- "File saved" confirmation box after successful save
- Filename retained between save dialogs (Subject field)

**DrawCommands graphical draw menu:**
- 16 foreground colors (0-9, a-f to select)
- 8 background colors (!, @, $, %, ^, &, *, ( to select)
- 10 CP437 glyph character sets displayed
- FG/BG color preview with current attribute
- O Open (FilePickerDialog, *.ans filter, loads via ProcessBuf)
- S Save (prompts filename, saves via GetLineText)
- Q Quit Drawing (exits editor)
- # Keys Normal (toggles glyph mode off)

**Status bar fixes:**
- WriteXY instead of WriteXYPipe (no MCI pipe processing)
- ScreenInfo[1].A = 7 for draw mode (fixes invisible text)
- ScreenInfo[2].Y uses ScreenSize (not hardcoded 24)
- F-key glyph bar renders CP437 directly

**ans2rip bug fixes:**
- RipNewCommand always writes !| prefix (was writing | without !)
- Chained commands now work: !|S0102!|B08040F07
- rip_render handles CRLF line endings
- Verified with ImageMagick compare: all 5 test files render with color

**Code quality:**
- All 219 .pas files normalized to CRLF (g00r00 standard)
- Reset Caller Data logged to mystic.log
- 4 files retired to retired/ (code merged into TEditorANSI)
- mystpack confirmed compatible (rebuilt with current records)
- mutil already does MsgPurge + MsgPack (mystpack redundant)

**Tools documented** (mystic_rip/TOOLS.md):
- ansilove: ANSI art renderer (IRC/BBS standard, in libs/)
- ImageMagick: pixel diff, side-by-side comparison
- rip_render: headless FPC RIP renderer
- Validation workflow: ansilove -> ans2rip -> rip_render -> compare

### Blocked on testing

- T (Text Editor) FileMode: untested since merge into TEditorANSI
- L (Log Viewer) FileReadOnly: untested since merge
- A (ANSI Editor) DrawMode: draw menu, text rendering, F-key glyphs
- N-G (Edit files) FileMode with pre-loaded files: untested since merge
- New user email: needs fresh install test with Sysop account
- ans2rip text positioning: bars correct, text offset from bars

### Still to add (from g00r00 whatsnew.112)

- Upload ANSI option in draw menu
- Theme Editor "Display Files" -> lists .a?? -> opens ANSI editor
- Theme Editor "Templates" -> lists .ini -> opens text editor
- Menu command *2 Edit ANSI file (with /open parameter)
- FS editor .ini template format (msg_editor.ini, major refactor)

### Deferred features (from DurDraw study)

- Alt+Up/Down: cycle foreground color while drawing
- Alt+Left/Right: cycle background color while drawing
- Alt+[/]: cycle character sets without opening draw menu
- Alt+S: character set picker popup

To implement: add Alt+arrow handlers to the draw mode key loop
in TEditorANSI.Edit. Alt keys come as ESC+arrow (#27 followed by
arrow key code). Need to distinguish ESC-as-menu from ESC-as-alt.

### Server-side RIP support (planned)

When a RIP terminal connects (RIPterm, PabloDraw), Mystic detects
RIP mode and sends .rip display files instead of .ans. User input
stays text. RIP rendering happens on the CLIENT, not the server.

**Implementation order:**
1. OutFile() .rip file selection (bbs_io.pas, small change)
   - Try .rip before .ans when UseRipTerm is set
2. RIP terminal detection in login sequence
   - Client sends !|Q00000000 (RIP query)
   - Server sets Session.io.UseRipTerm, Graphics := TERM_RIP
3. Theme .rip file generation via ans2rip
   - text/login.rip, text/matrix.rip, text/newuser.rip, etc.
4. Menu .rip files with mouse regions
   - !|M command for clickable buttons (TTermRip already parses)
5. Door/game RIP support (future)

**All dependencies done:**
- UseRipDetect in RecConfig (carved from Reserved, size unchanged)
- TERM_RIP = 2 constant
- ThmAllowRIP = $00000004 flag
- IconPath/FontPath in RecTheme (carved from Reserved, size unchanged)
- ans2rip converter (working, verified with ImageMagick)
- 51/51 RIP commands in TTermRip (48 tests passing)
- rip_render headless renderer
- Theme path halt (all 5 paths checked, maketheme cfgtheme)

**What TTermRip does NOT need on the server:**
- No server-side rendering (client renders)
- No TRipSurface (converter/tools only)
- No font/icon loading (client resources)

### Build status

- 14/14 Windows binaries: OK
- Linux build: OK
- 48/48 RIPscrip tests: OK
- ans2rip: compiles, renders correctly
- All .pas files: CRLF
- GitHub: needs push (synced at 16d3663)
- Repo: 789 entries, 111 .pas in mystic/, 4 in retired/
