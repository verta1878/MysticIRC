# START HERE — Mystic BBS A38 fork, working notes for the assistant

**Read this first, then follow the reading order below. Keep this file
current: update it whenever the plan changes so a fresh session can
resume from it alone.**

## What this is

The sysop (an original-era BBS operator) runs a live board on this
Mystic 1.10 fork and works on it here, in a container with FPC
2.6.4irc r3.1 (i386, from libs/fpc264irc.tar.gz). The tree is a git repo
(github.com/verta1878/mystic-bbs-irc — push from the sysop's side;
the container cannot push). Work is delivered as a source zip in
/mnt/user-data/outputs/ which the sysop applies and pushes.

Version: 1.10 A38irc-A43. All A41, A42, and A43 features from g00r00's
whatsnew have been ported. 7/7 core targets + marc compile clean with r3.1.

## Reading order (on resume)

1. **docs/TODO.md** — the ONE canonical roadmap (forward-looking).
2. **docs/DECISIONS.md** — the deep record: every decision, correction,
   "do NOT revert" note. Skim the last few entries for recent state.
3. **mystic/whatsnew.txt** — user-facing changelog (what's DONE).
4. **docs/RIP-INTEGRATION.md** — the RIP graphics design + status.
5. **INSTALL** — build instructions per platform.

## Orientation checklist (before any new work)

1. Confirm the tree + FPC 2.6.4irc r3.1 are present; if the container was
   reset, restore from the latest mystic-A38fork-source-*.zip in
   /mnt/user-data/outputs/ (or re-clone) and rebuild the toolchain
   (DECISIONS.md 2026-07-08 "Container toolchain rebuilt" records the
   exact recipe: release tarball → /home/claude/i386root, fpc.cfg at
   /etc/fpc.cfg, libc6-dev-i386, win32 cross units from the source
   tarball).
2. Run a BASELINE build before new work: `FPC=ppc386 bash build.sh`
   must be 14/14. Win32 cross-check when the change touches shared
   code.
3. After changes: 14/14 again (both platforms when relevant), and if
   anything near records.pas moved, verify the on-disk anchors:
   SizeOf RecConfig=5282, RecTheme=768, RecEchoMailNode=901.
4. Deliver: fresh source zip to /mnt/user-data/outputs/, docs updated
   (whatsnew for users, DECISIONS for the record, TODO for what's
   next, and THIS file).

## House rules (locked decisions — details in DECISIONS.md)

- FPC 2.6.4irc (release r3.1) is the default project compiler
  (libs/fpc264irc.tar.gz — self-sustaining, ships its own tools; verified to
  compile the Mystic tree). PPU wordversion is unchanged vs stock 2.6.4, so the
  on-disk record layout / anchors are unaffected. (2.6.2 was the earlier pin.)
- New modules stay SEPARATE from core (mystic_sdl/, mystic_spell/,
  mystic_crypt/, mystic_modem/); optional libraries are RUNTIME-loaded
  (dlopen/LoadLibrary), never linked.
- BBS text docs: 79 cols, CRLF. Core code style: A38 house style
  (Delphi mode, {$LONGSTRINGS OFF} — use AnsiString explicitly where
  >255 is possible and say why).
- Never commit live board data. libs/ binaries are the sysop's
  drop-in (licenses already in libs/).

## Current state (2026-07-08)

- A39 feature-import work essentially complete (tosser, JAM A51
  compat, ANSI draw mode, themed boxes, index reader). Waiting on the
  live-FTN validation gate (TODO item 1, sysop-side).
- **RIP graphics Phase 1 LANDED this date**: ripterm client engine is
  in the tree as its own example module, **mystic_rip/** (TTermRip in
  rip_term.pas — the TTermAnsi parallel — plus rip_canvas seam,
  software surface, SDL viewer, demos). FPC RTL units only — no mdl
  deps; threading (future) = FPC TThread. mdl/ is pristine. Promotion
  to mdl/m_term_rip.pas happens at the Phase 2b hook-up. Verified
  14/14 linux AND win32, module both, pixel-identical to the client
  reference. Next: Phase 2 — TODO item 4.
- **Darwin now LINKS from Linux (2026-07-08)**: sysop supplied a real
  10.6 SDK; cctools-port ld64 + Csu-built crt1.o + external-as darwin
  RTL produced Mach-O i386 binaries for ALL 14 programs + rip demos.
  Recipe: INSTALL (Darwin section) + DECISIONS entry. Runtime untested
  (needs a 10.4–10.14 era Mac — i386 died with Mojave). The container
  toolchain is ephemeral; rebuild per INSTALL if needed.
- **OS/2 LINK ON LINUX — SOLVED (2026-07-09)**: the final link now runs
  entirely on Linux. Self-hosted emx cross-toolchain — patched GNU
  binutils (new `a.out-emx` BFD target + emx IMPORT# symbol patch), a
  Linux port of emxbind, the emxl.exe loader, and a data-alignment ld
  wrapper — turns FPC's a.out into a native OS/2 LX .exe. ALL 14 build +
  verify "LX for OS/2 ... emx 0.9d". Build via `LINK=1 ./build-os2.sh`
  with the fork's emx toolchain (libs/fpc264irc.tar.gz: bin/tools/i386-emx). FULL
  docs: **fpc264irc/patches/os2-cross/** (README.md + EMXL-LOADER.md +
  EMXL-LOADER.md); patches in fpc264irc/patches/os2-cross/.
  This is the step ArcaOS/bitwiseworks track as unsolved. Also links
  natively on OS/2 with the stock FPC 2.6.2 OS/2 release. (Platform layer:
  DosCalls, TProcess, so32dll, generic Keyboard path.)
- **DOS/go32v2 (2026-07-09)**: DOS builds 10/14, including the mystic server.
  The socket layer (mdl/sockets_go32v2.pas, a Watt-32-backed FPC-Sockets API)
  and the binutils C_SECTION link fix (now handled by FPC 2.6.4irc r3.1's bundled go32v2 toolchain) are done and
  in the repo. The 4 networked utilities compile + are link-ready, needing only
  Watt-32 (libwatt.a); build-dos.sh wires -lwatt via WATT32LIB=. See
  docs/DOS-SOCKETS.md.
- **libs/ now POPULATED (2026-07-08)**: SDL2 2.32.8, Hunspell 1.7.2,
  cryptlib 3.4.9.1 built in-container, i386, under libs/win32 and
  libs/linux-i386. Linux SDL2 built with -mstackrealign — the long-
  standing SDL_Init crash under FPC 2.6.2 is FIXED for the shipped .so
  (rip_view/sdl_demo run against it). Hunspell proven live (spelltest
  returns suggestions); cryptlib binding loads + resolves all symbols
  (cryptInit -15 is container entropy only, clears on a real box). Only
  gap: win32 cl32.dll (needs MSVC). Provenance in libs/README.md +
  DECISIONS. These add ~9MB to the repo — git-rm + rebuild-from-recipe
  if a lean repo is wanted.

- Darwin toolchain is now scripted: tools/darwin/build-ld64-toolchain.sh
  builds ld64 once; build-darwin.sh auto-discovers it + the SDK (you still
  supply the Apple SDK). .mac is the canonical Mac target (.drn = alias).
