# SAVE STATE — 2026-07-08 / 07-09 (session working notes)

This is a point-in-time snapshot for resuming work.  It complements
START-HERE.md (the durable bootstrap) with the *live* task list and the
exact toolchain/build state as of this session.  Read START-HERE.md first,
then this.

## Repo state at snapshot

Recent commits (newest first):
    (this save)  file_id metadata + release packager; cryptlib cross-compile
                 patch; 1.12 FILE_ID research; save-state refresh
    a47a737  Build scripts (os2/darwin), WFC ANSI from 1.06, MIS-DOS example
    1b90a4d  OS/2 target (compiles 14/14 cross) + libs/ populated
    16c1a34  Darwin cross-LINK proven: 14/14 Mach-O i386 from Linux
    80f5de3  RIP relocated to mystic_rip/ example module
    33108e7  RIP graphics Phase 1: ripterm engine lifted into the tree

Build status by target (all with FPC 2.6.2 / ppc386):
- i386-linux : 14/14 build+LINK (native to the container)
- win32      : 14/14 build+LINK (FPC internal PE linker)
- darwin     : 14/14 build+LINK as Mach-O i386 (cctools ld64 + 10.6 SDK
               + Csu-built crt1.o; runtime UNTESTED — needs a 10.4–10.14 Mac)
- os2        : 14/14 COMPILE (cross); LINK is native-only (ld+emxbind on OS/2)

## Container toolchains (EPHEMERAL — rebuilt per session; recipes in INSTALL)

- /home/claude/i386root ............ FPC 2.6.2 i386-linux (ppc386, /etc/fpc.cfg)
- /home/claude/fpc262/fpc-2.6.2 .... FPC source tree; cross RTL units built at
    rtl/units/{i386-linux,i386-win32,i386-darwin,os2} + packages/*/units/*
- /home/claude/darwin/xtools ....... cctools/ld64 (i386-apple-darwin10)
- /home/claude/darwin/MacOSX10.6.sdk  Apple SDK (+ Csu-built crt1.o installed)
- /home/claude/os2tools/xbin ....... binutils 2.30 i386-aout (as/ld), symlinked
    to the i386-os2- prefix.  NOTE: cannot emxbind, so OS/2 does not link here.
- /home/claude/libbuild ............ where SDL2/Hunspell/cryptlib were built

## libs/ (populated this session; platform subdirs)

    libs/win32/      SDL2.dll, libhunspell32.dll         (i386 PE)
    libs/linux-i386/ libSDL2-2.0.so.0, libhunspell-1.7.so.0, libcl.so  (i386 ELF)

Proven: SDL2 (rip_view/sdl_demo run), Hunspell (spelltest suggests).  cryptlib
binding loads+resolves; cryptInit -15 is container entropy only.  Missing:
win32 cl32.dll (needs MSVC).  Provenance: libs/README.md + DECISIONS 2026-07-08.

## Root release tooling (added 2026-07-09)

    file_id.diz      -> master example (xxx slot); file_id.{win,lnx,os2,
                        mac,dos} = 5 per-target DIZ (tag filled in)
    make_release.sh  -> release/mystic-a38-<t>.zip     (per-target, embeds DIZ)
    build-os2.sh / build-darwin.sh                     (per-target builds)
    docs/patches/cryptlib-mingw-endian.patch           (win32 cross enabler)

## TASK LIST for THIS session (in progress — check boxes as done)

1. [x] Save state (this file).
2. [x] OS/2 build scripts (build-os2.sh at root + module build-*.sh os2 arms).
       Compile-only in-container (no emxbind); documents the native-link step.
3. [x] Darwin build scripts: update build-darwin.sh to the proven ld64+SDK
       recipe; add darwin arms to module build scripts where useful.
4. [x] WFC ANSI: the uploaded 1.06 WFC screen (Node Listing / Modem Info /
       System Commands / clock+date) becomes the canonical WFC art used by BOTH
       the binkp (mystic_mailer) and modem (mystic_modem) examples.  Reconstruct
       as an ANSI (CP437, 80x25) since the upload was a screenshot, not a .ans.
5. [x] New example: a mis.pas that USES the modem + binkp code and draws the
       uploaded WFC screen, with EVERY option on it functional (U/S/P/E/#/M/Q/
       G/A/V/F/L/X/D + SPACE local login).  DECISION: keep this "MIS-DOS" mis.pas
       SEPARATE from the main mystic/ source — it lives in its own example dir.
6. [x] RIP binaries → their example dir (mystic_rip/bin — already there; confirm
       + keep out of committed tree, source only).
7. [x] libs: win32 (SDL2, hunspell, cl32.dll) + linux-i386 (SDL2, hunspell,
       cryptlib) + darwin-i386 (cryptlib dylib) done. ld64 moved into libs/
       with APSL+libdispatch licenses. SDL2/Hunspell for DARWIN not provided -
       need a 10.7+ SDK (documented in libs/README); optional + graceful-off.
8. [x] file_id release: file_id.diz is the sysop's single example DIZ (hand-
       edit the "xxx BINARIES" slot per target). make_release.sh <tag> <bindir>
       embeds it as FILE_ID.DIZ in a per-target archive. No auto-generator
       (sysop edits xxx himself). Applies ONLY to the DIZ - not the source.
9. [x] 9a DONE: color-aware DIZ. mdl/m_strings strDizColor() preserves pipe +
       converts ANSI SGR->pipe; wired into bbs_filebase + mutil_upload;
       14/14 + unit test verified. 9b (full-screen archive viewer) = LATER,
       huge, on TODO item 6.
10.[x] cryptlib cross-compile: DONE - not just feasible, BUILT. cl32.dll
       cross-built with mingw (endian patch + hand link + shipped DES asm +
       XP-stub), self-contained, in libs/win32/. darwin libcl.dylib too.

## Notes / decisions captured this session (see DECISIONS.md for full text)

- RIP is mystic_rip/ (example module, no mdl deps, FPC-RTL only).
- OS/2 port uses FPC RTL calls throughout (DosCalls, TProcess, so32dll,
  System/SysUtils); IFNDEF-UNIX flipped to IFDEF-WINDOWS across 9 bbs units.
- OS/2 + Darwin both follow "compile cross, link on/with the target's tools".
- libs binaries add ~9MB; can be git-rm'd + rebuilt from libs/README recipe.

## Open questions for the sysop

- Is 1.12's file_id.ans a per-file ANSI shown in the file listing, or the
  archive-embedded FILE_ID.ANS?  (Affects where the reader hooks in.)

- Darwin ld64 is now BUNDLED in-repo (libs/ld64-linux-x86_64,
  relocatable, Linux-amd64 host only) - build-darwin.sh finds it, links
  14/14 with no setup. SDK still sysop-supplied (SDK=...). Non-amd64-linux
  hosts: build-ld64-toolchain.sh. .mac is the Mac/Darwin target.

## Release snapshot (2026-07-09)

- **OS/2 link on Linux SOLVED.** Full 14/14 LX build on Linux via the
  self-hosted emx toolchain (libs/os2-linux-toolchain.zip). Build:
  `LINK=1 ./build-os2.sh` with the toolchain bin/ on PATH. Docs:
  docs/os2-linux-toolchain/. Patches: libs/emxbind-src/binutils-patch/.
- **Build matrix now:** Linux 14/14 ELF, Win32 14/14 PE32, Darwin 14/14
  Mach-O, OS/2 14/14 LX (all on Linux); DOS 10/14 (incl. the mystic server -
  socket layer + binutils link fix done; the 4 networked utilities need
  Watt-32 libwatt.a).
- **DOS platform branches added** (m_ops, records, m_fileio, m_output,
  m_input) - real source gaps that blocked go32v2; Linux reverified.
- Combined binaries archive naming: mystica38bin<YYYYMMDD>.zip.
  Per-platform installer archives: mystic-a38-<plat>.zip.
- Toolchains (dos-toolchain.zip, os2-linux-toolchain.zip) are in libs/
  and proven to build binaries; the built cross-tools themselves are
  container-ephemeral (rebuild from the zips per the docs).
- UPSTREAM-EMX.md is paste-ready for bitwiseworks/ArcaOS + FPC + emx SF;
  sysop must do the actual posting (AI can't open issues/PRs).

## Release naming + DIZ (2026-07-10)
- Archive names: mystic-<VER>-<tag>-<mode>-<STAMP>.zip
  VER default 1.10a38irc; STAMP = build date MM-DD-YYYY while importing an
  alpha, or FINAL when that alpha's import is complete+verified.
  e.g. mystic-1.10a38irc-win-full-07-10-2026.zip / -win-update-07-10-2026.zip
- Each archive packages contents inside a top-level folder named after the
  archive, so extracting FULL and UPDATE side by side does NOT merge them.
- FILE_ID.DIZ: header renders "Mystic BBS v1.10-IRC Fork  <tag> FULL/UPGRADE"
  (border re-padded/aligned), last line " Released: <STAMP>" (date or FINAL).
- make_release.sh globs all update*.txt notes into both archives.
- A40 work is feature-complete but NOT yet verified as a working whole (no full
  multi-target build run, tests/a40 never executed, no live toss/mbcico). So by
  the date->FINAL rule, A40 is NOT FINAL - current builds carry the date.
- Windows: 14/14 built (first full A40 build - compiles clean as a set).
