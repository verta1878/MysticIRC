
## MIS Shutdown Hang Fix (Session 6)

**Problem:** MIS hangs on exit. Server threads block in `fpAccept()` 
with `WaitConnection(0)` (blocking mode, no timeout). When 
`TServerManager.Destroy` calls `Inherited Destroy` → `WaitFor`, the 
thread never returns because `fpAccept` is stuck waiting for a 
connection that will never arrive.

**Option A: Close socket first** — close the listening socket from 
the destructor thread, forcing `fpAccept` to return -1. Rejected: 
race condition — closing a socket from one thread while another 
blocks on it is undefined behavior on Windows, can crash.

**Option B: Poll with timeout** ✅ — change `WaitConnection(0)` to 
`WaitConnection(1000)`. Thread wakes every 1 second via `select()`, 
checks `Terminated`, loops back. Zero CPU overhead (kernel sleep). 
Zero latency (select wakes instantly on incoming connection). 
Clean shutdown within 1 second.

**Decision:** Option B. Same pattern as `KeyWait(500)` in MIS main loop.
7 server threads × 1 select() call/second = negligible.

**File:** `mis_server.pas` line 374
**Change:** `Server.WaitConnection(0)` → `Server.WaitConnection(1000)`
**Also:** NIL return now checks `Terminated` before breaking, uses 
`Continue` on timeout to loop back instead of exiting.

## Phase 7: Data Upgrade Tool (110to112.pas)

**Goal:** Convert 1.10/1.11IRC data files to 1.12 A49 format.

**Reference:** docs/records-112-a49.pas (g00r00's 1.12 A49 records)

**Records to convert:**
- RecConfig — SSH, Python, country blocking, optional user fields, etc.
- RecUser — new fields (SSH key, country, optional fields)
- RecTheme — theme boxes, new color fields
- RecMBase — message base changes
- RecFBase — file base changes
- RecSecurity — security profile changes

**Approach:** Same pattern as 109to110.pas:
- Define OldRecConfig (1.10 layout) and new RecConfig (1.12 layout)
- Read old .dat, field-by-field copy to new, set defaults for new fields
- Convert: mystic.dat, users.dat, theme.dat, security profiles

**Status:** Deferred until runtime testing complete.
**Depends on:** New user login, ANSI editor, MIS shutdown all tested.

## Master Phase Plan — Mystic BBS 1.11IRC

**Phase 1: ans2rip / RIPView** ✅ COMPLETE
- ans2rip v2.3 pixel-perfect ANSI→RIP converter
- RIPView v1.0.0 — 42/42 commands, 100% pixel match
- Modular: 7 units, CLI + Free Vision TUI
- VGA 8x16 font, baud emulation, debug mode

**Phase 2: BBS Core RIP Integration** ✅ COMPLETE
- TERM_RIP, .mrp/.rip/.ans display priority
- Config editor, -R flag, theme flags
- RecConfig RIP fields carved from Reserved

**Phase 3: Win32 Runtime Testing** 🔧 IN PROGRESS
- 18/18 binaries compile (fpc264irc r3.1)
- Login screen works, config editor works
- Bugs found and fixed: BUSY, theme crash, Set_Node_Action,
  stale nodes, MIS shutdown, ANSI draw, email user check
- TODO: new user signup, ANSI editor, text editor, MIS tray

**Phase 4: OS/2 (EMX)** ⏳ DEFERRED
- fpc264irc EMX builds + testing on ArcaOS/Warp 4

**Phase 5: Data Upgrade Tool (110to112.pas)** ⏳ PLANNED
- Convert 1.10/1.11IRC data files to 1.12 A49 format
- Reference: docs/records-112-a49.pas
- Records: RecConfig, RecUser, RecTheme, RecMBase, RecFBase
- Same pattern as 109to110.pas

**Phase 6: 1.12 Feature Port** ⏳ PLANNED
- SSH server (libssh2 or pure Pascal)
- Python embedding
- Country blocking / DNS blacklist
- Extended user fields (optional fields)
- Theme boxes
- ANSI gallery
- Spell check

**Phase 7: MDL Refactor** ⏳ DEFERRED
- MIS wrappers, mystic core, cleanup

**Phase 8: RIP Editor** ⏳ PLANNED
- Create/edit .mrp and .rip files
- RIPaint-style drawing + button placement
- Uses ripviewer shared units

**Phase 9: 1.12IRC Release** ⏳ PLANNED
- FTP prompts, HTTP config, FOSSIL config UI
- Wire RIP into BBS core menus
- Full runtime testing across platforms

**Phase 10: Runtime Testing (LAST)** ⏳ DEFERRED
- PabloDraw CP437 crash fix (ans2rip compat mode)
- Cross-platform verification
- FidoNet mail testing

## IPv6 Dual Stack Verification

**Current (1.11IRC A7):** IPv4 only. PF_INET sockets.
Comment in m_io_sockets.pas says AF_INET6 broke XP — removed.

**1.12 (mysticbbs.com):** Claims "IPV4 and IPV6 dual stack for all servers."
Needs verification — does 1.12 actually bind AF_INET6 sockets?
Or does it just have the code path without using it on XP?

**Action:** When 1.12 source (m_io_sockets.pas) is available, verify:
- Does it create AF_INET6 sockets?
- Does it use IPV6_V6ONLY=0 for dual stack?
- Does it fall back to IPv4 on XP?

**Phase 6 item.** Do not add IPv6 until verified against 1.12.

## RIP v1 Video Driver Integration

**Goal:** mystic_test loads video drivers for RIPscrip v1.54 16-color support.
**Requires:** evga's display layer (mystic_sdl or direct framebuffer).
**Context:** RIPView renders to a 640x350 EGA canvas with 16 colors.
The BBS needs to display this canvas to the user — either via
SDL2 (graphical terminal), direct VGA framebuffer (DOS), or
converted to ANSI escape sequences (telnet).

**Approach:**
- DOS: Direct VGA mode 10h (640x350x16) via m_output.pas
- Win32/Linux: SDL2 window via mystic_sdl/ or pixel-to-ANSI conversion
- Telnet: RIP commands sent raw to RIP-capable terminal (RIPterm, mterm)

**Status:** Deferred. Needs evga for display layer architecture.
**Depends on:** RIPView pixel-perfect (done), mystic_test RIP integration (done)
