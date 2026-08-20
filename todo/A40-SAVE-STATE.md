# A40 SAVE STATE — handoff for the next session

Written 2026-07-11. Purpose: know exactly where to compile/verify A40 and what
remains. The repo docs are the real memory; this is the quick pointer.

Repo: github.com/verta1878/mystic-bbs-irc  (fork of Mystic 1.10 A38, GPLv3)
Working clone in container: /home/claude/mystic-bbs-irc
Container HEAD: e9774c6  (clean, 106 commits ahead of GitHub origin)
AI CANNOT push — sysop pushes via GitHub Desktop.

--------------------------------------------------------------------------------
## THE #1 THING: where to compile A40

**A40 is feature-complete but NOT yet verified as a working whole.** Everything
below is implemented and MOST of it compiled individually, but the full A40 set
has to be built + tested together before A40 can be called done/FINAL.

### To compile + verify A40 (the remaining gate):
1. **Full build** — build all 14 binaries on at least one target (Linux is
   fastest): `./build.sh`  (Windows already did a full 14/14 build today, so the
   A40 code DOES compile as a complete set — see "compiled" list below).
2. **Run the A40 test harness — NEVER been executed:**
   `cd tests/a40 && ./run.sh`
   It checks: record anchors (901/5282/1536/768), compiles the A40-touched units
   (bbs_cfg_echomail, mutil_echoexport, bbs_database, mutil_common), and the
   logstamp format codes. Defaults to ppc386; override with `FPC=/path/to/ppc386`.
3. **Live tests on node 152/158** (the only real proof of runtime behavior):
   - PKT split at Max PKT Size, bundle split at Max ARC Size
   - untagged NetMail export (netmail-no-link)
   - netmail routing stage-1 direct match (+ the point→boss-node case)
   - AreaFix: remote node sends %LIST / +TAG / %RESCAN, gets netmail replies and
     the .lnk link list actually changes
   - a live mbcico BINKP session (CRAM-MD5 → plain fallback)
   - the reconstructed echonode editor: open `mystic -CFG` → EchoMail Nodes →
     edit a node, confirm it renders like g00r00's A40 screenshots

### Container reality (important):
The container is SLOW and gets resource-exhausted after a few FPC builds — full
compiles time out at ~4-5 min. Run compiles DETACHED:
  `setsid bash -c "ppc386 ... ; echo RC=$? >> log" &`  then poll
  `ps aux | grep [p]pc386`.
Live compiler: FPC 2.6.2 i386, ppc386 at /home/claude/i386root (pinned).
Windows cross: native `ppc386 -Twin32` + win32 RTL at
/home/claude/fpc262/fpc-2.6.2/rtl/units/i386-win32.

--------------------------------------------------------------------------------
## LOCKED RECORD ANCHORS (verify after ANY record change)
SizeOf: RecConfig=5282, RecTheme=768, RecEchoMailNode=901, RecUser=1536.
RecEchoMailNode was realigned to g00r00's records.110 this session — still 901.
Fast Python parser in the transcript verifies without compiling; always confirm
901.

--------------------------------------------------------------------------------
## A40 ITEM STATUS (read-verified unless noted)

DONE + verified:
- Max PKT/ARC size (per-node, KB, 0=None), defaults 512/2048 — record + editor
  aligned to g00r00's records.110; labels "Max PKT Size"/"Max ARC Size".
- Dup detection skips SEEN-BY + CTRL-A kludge lines (mutil_echocore CRC loop).
- Netmail routing stage-1 direct match (Zone/Net/Node, ignore Point) before Route
  Info — in BOTH GetNodeByRoute copies (bbs_database + mutil_common). Point case
  resolved via FTN history (point mail → boss node). FTS-validated.
- Netmail-no-link (NetType 3 exempt from EchoTag gate).
- MBCICO BINKP fix: verified FTS-1027 compliant — answering side accepts plain
  M_PWD even after offering CRAM-MD5 (keys on what remote SENT, not what Mystic
  offered); unless ForceMD5. Precise scenario confirmed in mis_client_binkp.pas.
- logstamp= (already present: mutil.pas reads it, mutil_common applies via
  FormatDate, all A40 codes supported). Test added.
- MCI #I, pass-through netmail, search_subdir, DNSBL, DNSCC(+badcountry.txt), log
  roller, area index CTRL-N/R/Z(+ansimidxhelp), auto-create overrides, revamped
  tossing — present (some grep-verified; see caveat).
- Built-in AreaFix (item 18): auth (GetNodeByAuth, bug fixed), all 9 commands
  (%HELP/%LIST/%LINKED/%UNLINKED/%PWD/%COMPRESS/%RESCAN + +/-/=ECHOTAG), netmail
  reply. %RESCAN fully wired (QueueRescan→areafix.rsn→ProcessRescanQueue re-export,
  R=/D=, default 250). Wired into toss at mutil_echoimport.pas:190. COMPILES CLEAN.
  Data model needs NO new records (AreaFixPass/PKTPass + .lnk + mbases.dat exist).
  areafixhelp.txt present.

N/A (internal optimizations, nothing to import): logging performance,
import/export performance.

CAVEAT: the original "15/22 already present" audit was grep-based and produced
2 FALSE "done" marks (17 was partial, 18 was a stub) that we then fixed. The
remaining grep-only marks (DNSBL, DNSCC, log roller, area index keys, auto-create,
pass-through netmail) SHOULD be read-verified before trusting.

--------------------------------------------------------------------------------
## COMPILED vs NOT (this session)
COMPILED CLEAN (RC=0): mutil_echofix, mutil_echoexport, bbs_cfg_echomail,
  bbs_database, mutil_common, AND a full Windows 14/14 build (so the whole A40 set
  compiles together on win32).
NOT COMPILED: mplc.pas (the milestone-1 -ALL change — container exhausted).

--------------------------------------------------------------------------------
## IN-FLIGHT WORK: mplc upgrade (milestone-based)

Plan (sysop): upgrade our A38 mplc toward the newer (1.12 A49) mplc, one command
per milestone, starting with -ALL. These options are POST-A40 (not in the A40
whatsnew) — a deliberate scope extension the sysop asked for.

- **mplc milestones -ALL/-C/-P/-R/-T/-F — DONE + compile-verified** (commit
  4f7d15e): the full A49-style option set is implemented and ppc386 builds
  mplc.o clean. -ALL/-R recurse; -C/-P are flat; -T/-F target the relative
  'themes' dir. Helpers: CompileMask(Mask,Recurse) + CompileInPath(Path,Mask,
  Recurse). Still recommended: a LIVE run on a themes tree to confirm the
  'Compiling: <file> [OK]' output end to end (compile proves it builds, not
  that the runtime output matches A49 exactly).

- THEN: clean up the GitHub docs — the date STAMPS are wrong in the docs shown
  when you first load the repo (README/front-page). Sysop flagged this for after
  mplc is done.

--------------------------------------------------------------------------------
## RELEASE / NAMING (make_release.sh)
- Names: mystic-<VER>-<tag>-<mode>-<STAMP>.zip
  VER=1.10a38irc (a38 for now, per sysop). STAMP=MM-DD-YYYY (today) or FINAL when
  an alpha's import is complete. Each archive unpacks into a matching folder (so
  FULL and UPDATE don't merge). FILE_ID.DIZ ends with "Released: <STAMP>".
  DIZ box uses + corners (fixed alignment). Version reads v1.10-IRC Fork.
- FULL archive = install.exe + install_data.mys + docs (NO loose binaries — they
  are inside install_data.mys, which install.exe unpacks).
- UPDATE archive = all 14 binaries, no payload.
- Build: `STAMP=07-10-2026 ./make_release.sh <tag> <bindir> both <outdir>`
- Other targets: build-dos.sh (WATT32LIB= for 14/14), build-os2.sh (LINK=1 +
  emx), build-darwin.sh (SDK= + cctools). See docs/BUILDING.md.

Today's deliverables (in outputs, dated 07-10-2026): win-full, win-update, src.
Source zip recipe (Option B, WinRAR-safe): git archive → deref symlinks → remove
libs/fpc264irc.tar.gz → zip.

--------------------------------------------------------------------------------
## KEY DOCS IN REPO (all committed)
docs/DECISIONS.md (append-only record — READ THIS FIRST), docs/BUILDING.md,
docs/CREATING-THE-INSTALLER.md, docs/DOS-SOCKETS.md, docs/TODO.md,
docs/SAVE-STATE.md, docs/a40/item18-areafix-checklist.md (AreaFix spec + item-17
point resolution), tests/a40/ (run.sh + checks). mystic/updatea40.txt (per-version
note, migration warning corrected). Reference uploads used: records.110 (g00r00's
1.10 records — the authority for record layout), 110alpah_info.txt (whatsnew),
mystic (A51 ELF), mystic.exe (1.12 A40 — used only for field order/labels), editor
screenshots.

--------------------------------------------------------------------------------
## PENDING (for the sysop)
- Push the 106 container commits to GitHub (via GitHub Desktop).
- Live A40 verification on node 152/158 (see "where to compile A40" above).
- Supply libwatt.a for the final DOS link-to-.exe proof.
- Decide the fork's alpha identity long-term (a38 vs a40 vs the DIZ "1.38" note).

## THE HONEST BOTTOM LINE
A40 is feature-complete; the whole set compiles on win32; help/txt files present.
It is NOT verified as a working whole (tests/a40/run.sh never run; no live toss/
mbcico/editor test). By the sysop's own date→FINAL rule, A40 is NOT FINAL — builds
correctly carry the date, not FINAL, until those live verifications pass.
