# RIPKit 1.20 for PCBoard — Analysis and Porting Guide

## Date: 2026-08-20
## Source: RIPKT120.ZIP (Clark Development Company, 9/23/95)
## Author: Steve Catmull (CDC Technical Support)
## Original Target: PCBoard v15.21+

## What Is RIPKit?

RIPKit is a STARTER KIT for adding RIPscrip graphical menus to PCBoard BBS.
It replaces PCBoard's text prompts (PCBTEXT records) with RIP equivalents,
provides graphical menus (MNU files with RIP backgrounds), and includes
PPL scripts (PPE/PPS) for RIP-aware functionality.

It is NOT a complete RIP system — it's a starting point. Sysops are
expected to customize the RIP screens with RIPaint.

## Package Contents

| Dir | Files | What |
|-----|-------|------|
| / (root) | 313 RIP | Display screen replacements for PCBTEXT records |
| PPE/ | 27 PPE + 30 PPS | Compiled + source PPL scripts |
| MENUS/ | 8 MNU + 8 RIP | Menu definitions with RIP backgrounds |
| DOCS/ | 1 DOC | CONCERN.DOC (known issues/workarounds) |
| PCBTEXT.RIP | 1 | 738-record text replacement file |
| CMDFILES.ZIP | 1 | Command display file overrides |
| FLAG32R.ZIP | 1 | FLAG PPE v3.2 (file flagging in RIP mode) |

Total: 313 RIP screens, 30 PPL source files, 8 menu definitions.

## Architecture

PCBoard has a text replacement system (PCBTEXT) where each system prompt
is a numbered record. RIPKit replaces these records with RIP-capable
versions using three mechanisms:

1. **Display file references**: `%%PCBRIP%\WELCOME_` — PCBoard finds
   the .RIP version when caller is in RIP language mode.

2. **PPE calls**: `!%PCBRIP%\PPE\MORE.PPE` — PPL scripts that handle
   RIP-specific logic (save/restore screen, draw buttons, etc.)

3. **Menu files**: MAIN.MNU, FILE.MNU, etc. — PCBoard's CMD menu system
   with RIP background screens and mouse-clickable buttons.

The `%PCBRIP%` environment variable points to the RIPKit directory.
PCBoard's multi-language system (`PCBML.DAT`) treats RIP as a "language"
with .RIP file extensions.

## Key PPL Scripts (port to MPS/Pascal)

### GRAF-D.PPS (v2.31) — RIP/ANSI Auto-Detection
The most important script. Detects caller's terminal capabilities:
- Calls `CHECKRIP()` to send RIP query and check response
- Calls `ANSION()` to check ANSI capability
- Reads `RIPVER()` for terminal version + vendor code
- Stuffs keyboard with R (RIP), Y (ANSI), or N (no graphics)
- Command line: /NOR (skip RIP), /NOQ (force welcome), /C (compatible), /A (auto)

**Mystic equivalent:** Already have RIP auto-sense in mterm (ESC[!).
Port the detection logic to MPS for MIS login sequence.

### LANGPRMP.PPS — Language Auto-Select
Reads PCBML.DAT to find RIP language number, auto-selects it if
caller has RIP. Offers RIPTerm download via Zmodem if caller selects
RIP but doesn't have RIP terminal.

**Mystic equivalent:** Mystic's language system. Port the auto-detect
and terminal download concept.

### MORE.PPS — RIP More Prompt
Saves screen state (`|1<ESC>0000$SAVEALL$`), displays RIP more prompt
with buttons, gets response, restores screen (`$RESTOREALL$`).
Uses `CDON()` for carrier detect.

**Mystic equivalent:** Replace Mystic's more prompt with RIP version.
The save/restore screen technique is key.

### WELCOME.PPS — Welcome Screen Handler
Simply waits for Enter key. Used after RIP welcome screen display.

### SETPROT.PPS — Protocol Selection
Full-screen protocol picker with RIP buttons for each transfer protocol.

### SLCTCNF.PPS — Conference Selection
Conference select/deselect with RIP buttons. Handles long conference
names (PCBoard 15.2+).

### CALENDAR.PPS + CALENG.PPS — Calendar Engine
Date picker with graphical calendar. CALENG.PPS is a reusable
calendar engine included via `$INCLUDE`.

### FLAG.PPE (v3.2R) — File Flagging
Flags files for download with RIP mouse fields. Manages mouse field
count to prevent "Too many mouse fields" error.

### TXT2SCN.PPS — Text to Screen
Displays text within a RIP viewport. Used for viewing files.

### LMR.PPS — Last Message Read
Sets last message read pointer with RIP interface.

### CHAT.PPS — Sysop Chat
RIP-mode chat with separate display areas.

### ALIAS.PPS — Handle/Alias Management
Toggle alias on/off with RIP buttons.

## Menu System (MENUS/)

8 menus with RIP background screens and PCBoard CMD system:

| Menu | Purpose |
|------|---------|
| MAIN | Main board menu (Files, Messages, Conferences, Bulletins, etc.) |
| FILE | File operations (Upload, Download, List, Search, New, Test, View) |
| MSGS | Message menu (Read, Scan, Enter, Kill, Reply) |
| MSGR | Message read submenu |
| MSGA | Message area submenu |
| CONF | Conference menu |
| STNGS | User settings menu |
| USERS | User listing menu |

Each menu has:
- `.MNU` file — PCBoard menu definition (command mappings)
- `.RIP` file — RIP background screen (drawn by RIPaint)
- Subdirectory — additional RIP screens for that menu

## RIP Techniques Used

### Screen Save/Restore
```
!|1<ESC>0000$SAVEALL$    — save entire screen + mouse fields
!|1<ESC>0000$RESTOREALL$ — restore saved screen
```

### Screen Clear/Reset
```
!|*|#|#|#                — reset windows + end RIP (CLEARRIP.RIP)
```

### Mouse Field Button Inversion
Buttons "invert" when clicked — visual feedback that the click registered.
v1.20 updated many screens to add this feature.

### Text Window Management
RIP text windows set before text output, reset after. Critical for
mixing RIP graphics with PCBoard's text output.

### Environment Variable References
```
%%PCBRIP%\FILENAME       — display file via environment var
!%PCBRIP%\PPE\SCRIPT.PPE — execute PPE via environment var
```

## Installation Concept (for Mystic port)

PCBoard uses `SET PCBRIP=C:\PCB\RIP` in AUTOEXEC.BAT. All RIP files
are referenced relative to this variable.

**Mystic equivalent:** Theme directory under Mystic's data path.
All RIP menu screens, MPS scripts, and display files in one directory
per theme. Config setting instead of environment variable.

## Concerns (from CONCERN.DOC)

1. **NEWUSER screen > 25 lines** — RIP buttons overlap. Fix: add `@WAIT@`.
2. **Logon sequence** — screen must be reset between password and news.
3. **Conference INTRO files** — need `@WAIT@` for RIP callers.
4. **PPE more prompt carrier detect** — loop must check CDON().
5. **Mouse field limit** — scripts must kill their own fields.
6. **Backslash in filenames** — RIPscrip uses `\` for line continuation.
   Backslash in path names won't display. Known RIPscrip spec issue.

## Porting Plan for Mystic

### Phase 1 — Menu Screens (RIP art)
Port the 8 menu backgrounds (MAIN, FILE, MSGS, etc.) to Mystic's
menu system. These are .RIP files — just art. Need mouse field
coordinates adjusted for Mystic's menu layout.

### Phase 2 — Display File Replacements
Port key PCBTEXT replacements to Mystic's display file system.
Priority screens:
- WELCOME, NEWS, LOGOFF, NEWUSER
- More prompt, password prompt, protocol select
- Message read/scan/enter screens
- File list/download/upload screens

### Phase 3 — PPL→MPS Script Porting
Port the 30 PPL scripts to MPS (Mystic Pascal Script).
Priority:
- GRAF-D (auto-detect) → already in mterm, port to MPS
- MORE (save/restore) → replace Mystic's more prompt
- LANGPRMP (language select) → adapt to Mystic's language system
- SETPROT (protocol) → RIP protocol picker
- SLCTCNF (conference) → RIP conference selector

### Phase 4 — Menu System Integration
Wire RIP menus into Mystic's menu editor (mystic -cfg).
Each menu command maps to a Mystic action + RIP screen.

### Phase 5 — Theme System
Package everything as a "RIP theme" that can be installed/switched.
Multiple themes possible — users choose their visual style.

## PPL→MPS Function Mapping

| PCBoard PPL | Mystic MPS | What |
|-------------|-----------|------|
| CHECKRIP() | — | RIP detection (need to add) |
| RIPVER() | — | RIP version string (need to add) |
| ANSION() | — | ANSI detection |
| KBDSTUFF | STUFFKEY | Stuff keyboard buffer |
| INPUTSTR | INPUT | Get user input |
| INPUTYN | — | Yes/No prompt |
| DISPFILE | DISPFILE | Display file |
| SPRINTLN | WRITELN | Print to caller |
| PCBDAT() | — | PCBoard config file (Mystic: theme config) |
| READLINE | — | Read line from config |
| PPEPATH() | — | PPE directory (Mystic: script path) |
| PPENAME() | — | PPE filename |
| ONLOCAL() | — | Local login check |
| CDON() | — | Carrier detect |
| GETTOKEN() | — | Parse command line |
| FOPEN/FGET/FCLOSE | — | File I/O |
| STARTDISP | — | Start display mode |
| FRESHLINE | — | Fresh line |

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

Original: distributed with PCBoard (commercial, CDC).
Port: GPLv3 (clean-room reimplementation, not derivative).
