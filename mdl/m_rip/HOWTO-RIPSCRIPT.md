# Adding RIPscrip Support to Mystic BBS (mystic110a38irc)

Step-by-step guide for the mystic-bbs-irc maintainer.

## What this adds

RIPscrip v1.54 graphical terminal support. When a RIP-capable terminal
(such as mterm) connects, Mystic sends graphical .RIP scene files instead
of ANSI art. Buttons in the RIP scenes send the same menu hotkeys as ANSI —
the menu system is unchanged.

## Prerequisites

- mystic-bbs-irc source (github.com/verta1878/mystic-bbs-irc)
- FPC 2.6.4irc (or 2.6.2+)
- The files from this package:
  - mystic_ripscript.patch (the code changes)
  - text/rip/*.rip (20 default display files)
  - text/icons/ (empty directory for .ICN icon files)
  - ripmake.pas (optional: RIP scene generator tool)

## Step 1: Apply the patch

    cd mystic-bbs-irc
    git apply mystic_ripscript.patch

This modifies 5 files (92 insertions, 15 deletions):

| File | Change |
|------|--------|
| records.pas | Adds TERM_ASCII/TERM_ANSI/TERM_RIP constants |
| bbs_io.pas | Display file search adds .rip before .ans; raw .rip send; MCI codes |
| bbs_user.pas | RIP terminal detection; manual RIP selection; DefTermMode=4 |
| bbs_doors.pas | Door drop files report GR for RIP terminals |
| bbs_cfg_syscfg.pas | Sysop config terminal toggle adds RIP option |

## Step 2: Build

Build as normal — no new units or dependencies added.

    ./build.sh                    # Linux
    build-win32.bat               # Windows
    ./build-darwin.sh             # macOS
    ./build-dos.sh                # DOS
    ./build-os2.sh                # OS/2

The patch uses only existing FPC standard library functions (FileExist,
PathSep, BlockRead). No new units, no new dependencies. Cross-platform.

## Step 3: Install the RIP display files

Copy the display files into your Mystic text directory:

    mkdir -p /mystic/text/rip
    mkdir -p /mystic/text/icons
    cp text/rip/*.rip /mystic/text/rip/

On Windows:

    mkdir \mystic\text\rip
    mkdir \mystic\text\icons
    copy text\rip\*.rip \mystic\text\rip\

The directory structure should be:

    \mystic\text\             <- existing ANSI display files (.ans)
    \mystic\text\rip\         <- NEW: RIPscrip display files (.rip)
    \mystic\text\icons\       <- NEW: RIP icon files (.icn)

## Step 4: Configure (optional)

In mystic -cfg under System Configuration:

    Terminal: [Ask / Detect / Detect/Ask / ANSI / RIP]

- **Detect** (default, recommended): auto-detects RIP support at login.
  Sends a RIP query (!|1Q) after ANSI detection. If the terminal responds,
  RIP mode is enabled. Falls back to ANSI if no response.
- **RIP**: forces RIP mode for all connections (for testing).
- **Ask**: prompts the user to choose ASCII (0), ANSI (1), or RIP (2).

Most sysops should leave this at Detect.

## Step 5: Test

1. Start Mystic as normal (mis or mystic -l for local)
2. Connect with a RIP-capable terminal (mterm --rip host:port)
3. The terminal should receive .RIP files for each menu screen
4. Verify button clicks work (they send the same hotkeys as ANSI)
5. If no .rip file exists for a screen, it falls back to .ans

## How it works

### Terminal detection (login)

After ANSI detection (ESC[6n), Mystic sends the RIP query:

    !|1Q00000000\r\n

A RIP terminal (mterm) responds with RIPSCRIP. Mystic waits up to 2
seconds for the response. If received, Session.io.Graphics is set to
TERM_RIP (2). If not, it stays at TERM_ANSI (1) or TERM_ASCII (0).

### Display file selection

When Mystic needs to show a screen (e.g. the main menu), the file
search order is:

    RIP terminal:  text/rip/mainmenu.rip -> text/mainmenu.ans -> text/mainmenu.asc
    ANSI terminal: text/mainmenu.ans -> text/mainmenu.asc
    ASCII terminal: text/mainmenu.asc

If no .rip file exists, the .ans fallback is used. This means a sysop
does NOT have to create .rip files for every screen — any screen without
a .rip file simply shows its ANSI version.

### RIP file sending

.RIP files are sent as RAW content — no ANSI/MCI processing, no pause
prompts, no baud emulation. The client (mterm) parses the !| commands
and renders the graphics. The server just pipes the file bytes through.

### Button clicks

RIP buttons send host command strings back to Mystic as keyboard input.
A button defined as:

    !|1U...000<>[M] Messages<>M

sends "M" when clicked. Mystic receives "M" and processes it through
the menu system exactly as if the user typed it. No special input
handling needed — the menu system is terminal-independent.

## MCI codes

| Code | Description |
|------|-------------|
| \|SE | Shows "RIP", "Ansi", or "Ascii" depending on terminal type |
| \|RI | Sends !|\* (RIP reset) if the terminal is RIP; no-op otherwise |

Use \|RI in prompt strings before displaying a new RIP screen.

## Creating RIP art

### Option 1: ripmake (included)

    fpc -Mobjfpc ripmake.pas
    ./ripmake mainmenu.txt text/rip/mainmenu.rip

Write a simple text description:

    CLEAR
    COLOR 1
    BAR 0 0 639 349
    COLOR 15
    TEXT 200 30 Main Menu
    BUTTON 40 90 200 115 [M]essages M
    BUTTON 40 125 200 150 [F]iles F

ripmake converts to .RIP format with base-36 encoding handled
automatically.

### Option 2: mripcfg (separate tool)

A WYSIWYG RIP editor with drawing tools, color palette, and undo/redo.
See the mripcfg package.

### Option 3: hand-edit

.RIP files are plain text. Each line starting with !| is a RIPscrip
command. The RIPscrip v1.54 spec documents all commands. Coordinates
are base-36 encoded (0-9, A-Z).

## .RIP file format quick reference

    !|*                              Reset screen (clear everything)
    !|c<color:2>                     Set color (00-0F = 16 EGA colors)
    !|L<x1:2><y1:2><x2:2><y2:2>     Draw line
    !|R<x1:2><y1:2><x2:2><y2:2>     Draw rectangle
    !|B<x1:2><y1:2><x2:2><y2:2>     Filled bar
    !|C<cx:2><cy:2><r:2>            Circle
    !|F<x:2><y:2><border:2>         Flood fill
    !|@<x:2><y:2><text>             Text at position
    !|S<pattern:2><color:2>          Fill style
    !|1U<x1><y1><x2><y2><f>         Button: <f> = hotkey<>label<>hostcmd
    !|1M<x1><y1><x2><y2><f><cmd>    Mouse region
    !|1K                             Clear mouse regions
    !|1I<x><y><f><file>              Load icon (.ICN)
    !|1R<f><file>                    Include .RIP scene

    Coordinates are 2-digit base-36: 00=0, 0A=10, 10=36, ZZ=1295, HS=640, 9Q=350

## Troubleshooting

**RIP not detected:** Make sure the terminal supports the RIP query
(!|1Q). mterm supports this. Some older terminals may not — users can
manually select RIP via the Ask terminal mode.

**Garbled display:** The .RIP file may have Windows line endings (\r\n)
which is correct. Unix-only line endings (\n) also work. Do not use
\r-only line endings.

**Button clicks not working:** Verify the host command in the .RIP file
matches the menu hotkey. Example: if the menu command is 'M' for
messages, the button's host command must be 'M' (case-sensitive).

**Fallback to ANSI:** If a .rip file is missing for a screen, Mystic
shows the .ans version. This is by design — sysops don't have to create
.rip files for every screen.

## Files included

    HOWTO-RIPSCRIPT.md          This document
    mystic_ripscript.patch      Code changes (git apply)
    ripmake.pas                 RIP scene generator tool
    mainmenu.txt                Example ripmake input
    text/rip/                   Default .RIP display files (22 files, incl. shared header/footer):
        ansigal.rip               ANSI gallery browser
        ansigalh.rip              ANSI gallery help
        birthday.rip              Birthday greeting
        blindul.rip               Blind upload
        closed.rip                System closed
        download.rip              File download
        feedback.rip              Sysop feedback
        fgroup.rip                File group selection
        flisthlp.rip              File list help
        fsearch.rip               File search
        group.rip                 Message group selection
        logoff.rip                Logoff screen
        logon.rip                 Login welcome
        mainmenu.rip              Main menu with buttons
        newuser.rip               New user registration
        nodesearch.rip            Node search
        nonewusr.rip              No new users message
        prelogon.rip              Pre-login banner
        header.rip                Shared header (logo + title bar)
        footer.rip                Shared footer (status line)
        sl.rip                    Security level denied
        upload.rip                File upload
    text/icons/               Icon files (8 icons):
        mail.icn                  Envelope (messages)
        files.icn                 Folder (file areas)
        chat.icn                  Speech bubble (chat)
        door.icn                  Door (doors/games)
        quit.icn                  Exit arrow (goodbye)
        logo.icn                  Diamond (BBS logo)
        who.icn                   Person (who is online)
        sysinfo.icn               Info circle (system info)

## License

GPLv3. RIPscrip protocol (c) TeleGrafix Communications, Inc. —
freely licensed for use in other products.
