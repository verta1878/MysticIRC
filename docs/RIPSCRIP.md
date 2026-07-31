# RIPscrip in Mystic BBS (IRC fork)

How the fork's RIPscrip v1.54 support works — setup, file layout, detection,
and how .rip files flow from sysop to caller.

## What RIPscrip is

RIPscrip (Remote Imaging Protocol) is a graphical BBS protocol from 1992-1993
by TeleGrafix Communications. It gave BBSs a GUI before the web existed:
clickable buttons, vector graphics, icons, and mouse support — all over a
standard modem/telnet connection. RIPscrip commands are embedded in the same
byte stream as ANSI text, prefixed with `!|`.

The protocol was designed around Borland's BGI (Borland Graphics Interface),
so every RIP drawing command maps 1:1 to a BGI function: line, circle, bar,
fill, text, viewport, palette, etc. The native resolution is 640×350×16 (EGA).

## How it works in Mystic

Mystic's RIPscrip support is **server-side only** — the BBS detects whether
the caller's terminal supports RIP, and if so, sends `.rip` display files
instead of `.ans` files. The caller's RIP-capable terminal (e.g. RIPterm,
SyncTerm, mterm) handles all the rendering.

### Terminal modes

Mystic tracks three terminal modes in `Session.io.Graphics`:

| Value | Constant     | Meaning |
|-------|-------------|---------|
| 0     | `TERM_ASCII` | Plain text, no escape sequences |
| 1     | `TERM_ANSI`  | ANSI/VT-100 color and cursor control |
| 2     | `TERM_RIP`   | RIPscrip v1.54 graphical terminal |

RIP is a **superset of ANSI** — a RIP terminal understands ANSI escape
sequences too. So all ANSI features (lightbar menus, color prompts, input
fields) work for RIP callers. The code uses `>= TERM_ANSI` checks throughout
instead of `= 1`.

### Auto-detection

When a caller connects, Mystic auto-detects their terminal:

1. First, it sends the standard ANSI detection query and checks for a response
2. If ANSI is detected, it then sends the RIP query command: `!|1Q00000000`
3. If the terminal responds with a string starting with `R` (the RIPscrip
   identification response), Mystic sets `Graphics := TERM_RIP`
4. Detection works for both remote (socket) and local (console) sessions

The detection mode is configured in `mystic -cfg` → General → Terminal:

| Setting | Behavior |
|---------|----------|
| Ask     | Prompt the caller for their terminal type |
| Detect  | Auto-detect ANSI, then RIP |
| Detect/Ask | Auto-detect first, then ask if detection fails |
| ANSI    | Force ANSI mode (skip detection) |
| RIP     | Force RIP mode (skip detection) |

### Display file resolution

When Mystic needs to show a display file (e.g. `welcome`, `logoff`, a menu),
it looks for files in this priority order for RIP callers:

1. `<textpath>/rip/<filename>.rip` — RIP version in the `rip/` subdirectory
2. `<textpath>/<filename>.rip` — RIP version alongside the ANSI files
3. `<textpath>/<filename>.ans` — falls back to ANSI if no .rip exists
4. `<textpath>/<filename>.asc` — falls back to ASCII

For ANSI callers, steps 1-2 are skipped (only .ans/.asc are checked).

### Raw .rip file sending

When a `.rip` file is found, Mystic sends it **raw** — no ANSI processing,
no MCI code expansion, no pause prompts. The file is piped byte-for-byte to
the caller's terminal. The RIP terminal handles all rendering (drawing
commands, button registration, mouse regions, icon loading, etc.).

This is the correct approach: RIP commands must not be mangled by ANSI
processing or line-wrapping. The `!|` escape sequences are meant for the
client's RIP parser, not the server.

### Menu display

The menu system (`ShowMenu`) checks for a `.rip` version of each menu:

1. If `Graphics >= TERM_RIP`, look for `<menupath>/<menuname>.rip`
2. If found, send it raw (same as display files)
3. If not found, fall back to the standard `.ans` menu display

This means a sysop can provide RIP menus for some screens and ANSI menus for
others — the fallback is seamless.

### MCI codes

Two RIP-related MCI codes:

| Code | Function |
|------|----------|
| `\|RI` | Sends the RIP reset command `!|*` to the caller (clears the RIP viewport and resets state). Only sent when `Graphics = TERM_RIP`. |
| `\|TE` | Returns the terminal type as text: `"RIP"`, `"Ansi"`, or `"Ascii"` |

### Door support

When launching external doors, Mystic's drop files report graphics capability
for both ANSI and RIP terminals (`GR` flag). This ensures doors that check for
ANSI support work correctly for RIP callers too.

## Directory layout

```
mystic/
├── themes/
│   └── default/
│       └── text/
│           ├── welcome.ans        ← ANSI version
│           ├── welcome.rip        ← RIP version (optional, same dir)
│           ├── rip/               ← dedicated RIP directory
│           │   ├── welcome.rip
│           │   ├── mainmenu.rip
│           │   └── ...
│           └── icons/             ← RIPscrip .ICN icon files
│               ├── button1.icn
│               └── ...
```

The `text/rip/` and `text/icons/` directories are created by the installer.

## Creating .rip files

RIPscrip files are text files containing `!|` escape sequences. They can be
created with:

- **mripcfg** — WYSIWYG RIPscrip scene editor
- **ripmake** — text-description to .RIP generator
- **ans2rip** — converts .ANS files to .RIP format
- **A text editor** — RIP commands are human-readable text

Example `.rip` file (draws a red line and a blue circle):
```
!|*
!|c04L0A0A3K3K
!|c01C1414050A
```

Line by line:
- `!|*` — reset the RIP viewport
- `!|c04` — set color to 4 (red)
- `!|L0A0A3K3K` — draw a line from (10,10) to (120,120) in base-36
- `!|c01` — set color to 1 (blue)
- `!|C1414050A` — draw a circle at (50,50) radius 186

## RIPscrip protocol reference

The full RIPscrip v1.54 protocol specification is included in the mterm
project at `docs/RIPscrip154.txt` (5,150 lines). Key points:

- **Arguments are base-36 encoded** (0-9, A-Z) in 2-character pairs
- **Level 0 commands** are single-character (drawing primitives)
- **Level 1 commands** are two-character (buttons, mouse, icons, text blocks)
- **Lines starting with `!` containing `|`** are RIP commands
- **All other lines** are plain text (ANSI terminal content)
- **Continuation**: a `\` before the line terminator joins the next line

## Configuration summary

| Setting | Location | Values |
|---------|----------|--------|
| Terminal mode | `-cfg` → General → Terminal | Ask / Detect / Detect-Ask / ANSI / RIP |
| .rip files | `<textpath>/rip/` or `<textpath>/` | any `.rip` file |
| .icn icons | `<textpath>/icons/` | RIPscrip icon files |
| RIP detection | automatic | sends `!|1Q00000000`, checks for `R` response |

## Tools

### ans2rip

ANSI-to-RIPscrip converter in `mystic_rip/ans2rip.pas`. Uses PabloDraw-
compatible output format: base-36 mega-numbers, line wrapping at 70 chars
with backslash continuation, CP437 encoding.

```
ans2rip input.ans output.rip
```

### mripedit

Standalone RIPscrip scene editor in `mripedit/`. WYSIWYG editor for
creating .rip files with 14 drawing tools, undo/redo, and native .rip
format save. Run from the command line or via mystic -cfg Other menu.

```
mripedit [--iconpath=DIR] [--fontpath=DIR] [filename.rip]
```

### rip_render / rip_view

Headless renderer and SDL2 viewer in `mystic_rip/`. For testing .rip
files without a BBS connection.

```
rip_render screen.rip output.bmp     # headless
rip_view screen.rip                  # SDL2 window
```

## mystic_rip engine

The RIPscrip engine in `mystic_rip/` implements 51 of 51 RIPscrip v1.54
commands across Level 0 (drawing primitives) and Level 1 (buttons, text
blocks, clipboard, icons). TTermRip parallels TTermAnsi: same interface,
same hook points in bbs_io/mis/nodespy. See `mystic_rip/README.md` for
the full command table.

All 51 RIPscrip v1.54 commands implemented including Polygon,
Define, ReadScene, and FileQuery.

## Credits

- RIPscrip v1.54: TeleGrafix Communications (freely licensed protocol)
- PabloDraw (MIT): reference for RipWriter encoding patterns
- BGI fonts (.CHR): originally Borland International, freely available
- Carl Gorringe / RIPtermJS (GPLv3): studied as reference (no code copied)
