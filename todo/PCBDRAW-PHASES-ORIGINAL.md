# PCBDraw — ANSI Art Editor for PCBoard and Mystic BBS

## What Is PCBDraw?

PCBDraw is ansiedit — one Pascal codebase, one editor, both BBSes.

The ansiedit codebase from mysticbbsirc is the single ANSI art editor
for the pcbirc project. It serves PCBoard 15.4/15.41 and Mystic BBS
1.11IRC. No separate C implementation. No duplicate code.

Compiled with FPC 2.6.4irc. Runs on i8086, go32v2, Linux, Win32, OS/2.

kiddo is lead on ansiedit. hexadecimal documents PCBoard integration.

## One Codebase — Everything

```
ansiedit
  |
  +-- Editor core (drawing, blocks, undo, ICE, CP437, mouse)
  |     Already done: 10,705 lines
  |
  +-- File I/O (ANSI, PCB @X, ASCII, BIN, XBIN, SAUCE)
  |     Mostly done: 19 m_pd*.pas format modules
  |
  +-- Serial teleconference (built-in)
  |     Already done: FOSSIL (m_fossil.pas) + direct UART
  |     (serial.pas, serial_irq.pas)
  |     Works on i8086, go32v2, Linux, Win32
  |
  +-- TCP teleconference (external program)
  |     ansiedit pipes to external TCP tool
  |     No sockets compiled into the editor
  |
  +-- Door mode — Mystic BBS
  |     Already done: bbs_edit_ansi.pas (2,194 lines)
  |
  +-- Door mode — PCBoard           <-- NEW
  |     pcbd_door.pas: PCBOARD.SYS reader, timeout, carrier detect
  |     {$DEFINE PCBOARD} compile flag
  |
  +-- PCBoard @X format             <-- NEW (small)
        m_pdpcboard.pas already exists (70 lines)
        Wire into save/load menu
```

## Platform Matrix

| Target | Compiler | Serial | TCP | Status |
|--------|----------|--------|-----|--------|
| DOS i8086 | FPC 2.6.4irc ppcross8086 | FOSSIL INT 14h / UART | External program | Builds |
| DOS go32v2 | FPC 2.6.4irc ppc386 | FOSSIL / UART | External program | Builds |
| Linux x86 | FPC 2.6.4irc ppc386 | /dev/ttyS* termios | External program | Builds |
| Win32 | FPC 2.6.4irc ppc386 | COM* Win32 API | External program | Builds |
| OS/2 | FPC 2.6.4irc ppc386 | COM* | External program | Builds |

Serial teleconference is built-in on ALL platforms.
TCP teleconference uses an external program on ALL platforms.

## What's New for PCBoard (small additions)

The ansiedit codebase already has almost everything. PCBoard needs:

### 1. PCBoard @X Color Code Support

m_pdpcboard.pas already exists (70 lines). Wire it into the file
menu so users can Load/Save as PCBoard @X format.

@X codes: @X00 through @XFF (hex attribute byte). PCBoard's native
color format. Example: @X0F = bright white on black.

### 2. PCBoard Door Mode (pcbd_door.pas — NEW file)

```pascal
Unit pcbd_door;
{ PCBoard door interface for ansiedit.
  Reads PCBOARD.SYS drop file, handles timeout and carrier detect. }
```

PCBOARD.SYS reader:
- Line 1: Display (local/remote)
- Line 5: Sysop name
- Line 26: COM port (0=local, 1-4=COMn)
- Line 28: Baud rate
- Line 31: User first name
- Line 34: Time remaining (minutes)
- Line 35: Node number

Also support DOOR.SYS (different format, same fields needed).

Timeout handling:
- Inactivity timeout: 5 minutes default (configurable)
- Timer resets on any keypress from remote caller
- On timeout: auto-save work, send "Timeout" message, exit cleanly
- Time remaining from drop file: warn at 2 minutes, force exit at 0

Carrier detect:
- Poll DCD via FOSSIL every second
- On carrier loss: save work to temp file, exit immediately
- Don't hang — just exit, let PCBoard handle cleanup

ANSI check:
- Verify caller supports ANSI from drop file
- If no ANSI: show error, exit (can't run a drawing editor without ANSI)

Launch:
- ansiedit /DOOR — enter PCBoard door mode
- ansiedit /DOOR /LOCAL — sysop local mode (no modem)
- Reads PCBOARD.SYS from current directory
- Saves to PCBoard file base path
- Exit with errorlevel 0 (returns to PCBoard)

### 3. Compile Flag

```pascal
{$DEFINE PCBOARD}   { Enable PCBoard door mode + @X format }
```

Without the flag: pure Mystic BBS build (existing behavior).
With the flag: adds PCBoard door mode and @X save option to menus.
Same binary can serve both if compiled with both flags.

## Version Plan

### v1.0 (PCBoard 15.4 — what Clark would have shipped)

Standalone ANSI editor. No networking. No door mode.

- [x] Canvas + screen + cursor movement
- [x] 8 line draw modes with direction detection
- [x] ICE/blink color toggle
- [x] Block operations (select, copy, move, fill, center)
- [x] Multi-level undo/redo
- [x] Character map popup (CP437)
- [x] Mouse support
- [x] File I/O: ANSI (.ans) with SAUCE
- [ ] File I/O: PCBoard @X (.pcb) — wire m_pdpcboard.pas into menu
- [x] File I/O: ASCII (.asc/.txt)
- [x] File I/O: BIN (.bin)
- [ ] File selector dialog
- [ ] Config file (PCBDRAW.CFG — nick, defaults, last file, prefs)
- [ ] Help screen (F1)
- [ ] ESC menu (File/Color/CharMap/Block/Draw/ICE/Help/Quit)
- [ ] Status bar: X,Y MODE/LineType iCE filename

[x] = ansiedit already has this. [ ] = needs work or wiring.

Deliverable: ansiedit.exe (or pcbdraw.exe renamed) — standalone ANSI
editor on DOS. Type, draw, save, load. No network, no BBS.

### v2.0 (PCBoard 15.41 — crew additions)

Everything from v1.0 plus:

- [ ] Serial teleconference (already built-in, needs testing)
- [ ] TCP teleconference via external program
- [ ] PCBoard door mode (pcbd_door.pas)
- [ ] PCBOARD.SYS / DOOR.SYS reader
- [ ] Timeout + carrier detect in door mode
- [ ] XBIN format support (m_pdxbin.pas — 163 lines, exists)
- [ ] ALT+S connection setup dialog (exists, needs testing)
- [ ] Virtual pages: canvas + chat (from TC-PLAN.md)
- [ ] Remote cursor display
- [ ] /who, /nick, /kick commands

External TCP program for teleconference:
- ansiedit talks to external program via pipe (stdin/stdout)
- External program handles TCP connect/listen/accept
- Wire protocol is the same as m_pdnet.pas (11 commands,
  binary framed packets) so ansiedit and pcbdraw instances
  are interoperable regardless of platform
- External program TBD: could be a small standalone tool
  (pcbdsync? pcbdtcp?) or netcat-style pipe

Command line (v2.0):
- ansiedit filename.ans — open file
- ansiedit /NOSAUCE — save without SAUCE
- ansiedit /ICE — start with ICE mode
- ansiedit /DOOR — PCBoard door mode
- ansiedit /DOOR /LOCAL — sysop local mode
- ansiedit /HOST:8000 — serial host on port (via external TCP tool)
- ansiedit /JOIN:host:8000 — serial join (via external TCP tool)
- ansiedit /JOIN:host:8000 password — join with password
- ansiedit /NICK:name — set nickname
- ansiedit /SERIAL:COM1:9600 — direct serial teleconference (built-in)

## Coding Standards

This goes back to kiddo. Clean code, single style, no exceptions:

### Style Rules
- Pascal, FPC 2.6.4irc, {$MODE OBJFPC} or {$MODE TP} for i8086
- Begin/End on own lines, 2-space indent
- PascalCase for types, procedures, functions
- camelCase for local variables
- UPPER_CASE for constants
- No magic numbers — named constants for everything
- Max line length: 80 columns (DOS terminal width)

### Comments — Aggressive
Every procedure and function gets a block comment header:

```pascal
{ ---------------------------------------------------------------
  PlaceLineChar — Place a line draw character with auto-detection

  Examines the 4 adjacent cells (up, down, left, right) to pick
  the correct line draw piece: horizontal, vertical, corner,
  T-junction, or crossover. Uses the current line draw set
  (Single, Double, Block1, etc.) from DrawMode.

  CIADraw called this "smart line drawing." ansiedit expanded it
  to 8 character sets. The detection algorithm is the same: check
  adjacency, look up in the 11-entry piece table.

  Parameters:
    X, Y  — canvas position (0-based)
    Dir   — arrow key direction that triggered this placement

  Modifies: Canvas[Y][X].Ch (attribute unchanged)
  --------------------------------------------------------------- }
```

Every non-obvious line gets an inline comment.
Every {$IFDEF} gets a comment explaining why.
Every magic constant gets a name and a comment.

### Code Once, Audit, Test Three Times

1. **Code once** — write it, compile on all targets
2. **Audit** — second person reads every line, checks:
   - Does it match the reference (CIADraw / ansiedit)?
   - Edge cases (canvas boundaries, empty canvas, max undo)?
   - Platform-specific paths ({$IFDEF} correct for each target)?
   - No memory leaks (every alloc has a matching free)?
3. **Test three times:**
   - **Test 1: Unit test** — exercise the function in isolation
     with known inputs and expected outputs. Automated where possible.
   - **Test 2: Integration test** — run the full editor, perform
     the operation manually, verify screen output matches expected.
     Test on DOS (DOSBox or real hardware) AND Linux.
   - **Test 3: Stress test** — push limits. 500-row canvas with
     undo. Rapid key repeat. Block select entire canvas. Load a
     200KB ANSI file. 8 users in teleconference. Serial at 300 baud.

### Test Code

Test code lives alongside source, not in a separate tree:

```
mystic/ansiedit/
  ansiedit.pas              Main editor
  ansiedit_test.pas         Test harness — runs all tests
  test_canvas.pas           Canvas unit tests
  test_draw.pas             Drawing tool tests
  test_undo.pas             Undo/redo tests
  test_fileio.pas           File format round-trip tests
  test_net.pas              Wire protocol encode/decode tests
  test_sauce.pas            SAUCE read/write tests
```

Test harness runs headless (no screen required):
```
ansiedit_test            Run all tests, print PASS/FAIL
ansiedit_test canvas     Run only canvas tests
ansiedit_test draw       Run only drawing tests
```

Each test:
```pascal
Procedure Test_Canvas_PlaceChar;
{ Place a character at 0,0 and verify canvas contents }
Begin
  Canvas_Init(80, 25);
  Canvas_PlaceChar(0, 0, 'A', $07);
  Assert(Canvas_GetChar(0, 0) = 'A', 'char should be A');
  Assert(Canvas_GetAttr(0, 0) = $07, 'attr should be $07');
  Canvas_Free;
  WriteLn('  PASS: Test_Canvas_PlaceChar');
End;
```

## Source Location

```
github.com/verta1878/mysticbbsirc
  mystic/ansiedit/       Editor source (kiddo's territory)
  mdl/                   Required library

github.com/verta1878/pcbirc
  1541/pcbdraw/           This doc + CIADraw historical reference
  1541/pcbdraw/ciadraw/   CIADraw original (study only)
```

ansiedit source lives in mysticbbsirc. pcbirc/pcbdraw/ has this
phases doc and the CIADraw reference. The compiled binary
(ansiedit.exe or pcbdraw.exe) ships with PCBoard 15.41.

## Provenance

| Source | Role | License |
|--------|------|---------|
| CIADraw (CiA/Strider 1994-96) | Drawing engine ancestor, mouse, font, palette | Public domain |
| ansiedit (Mystic BBS / g00r00) | Full editor — line draw, blocks, ICE, undo, formats, TC | GPLv3 |
| PabloDraw (Curtis Wensley) | Wire protocol, format parsers (C# original) | MIT |
| PabloDraw Pascal port (sysop/0) | m_pd*.pas modules | GPLv3 |
| MDL (g00r00 + crew) | I/O, serial, FOSSIL, sockets, protocols, UI | GPLv3 |

## Credits

- CiA / Strider — original CIADraw (1994-96)
- James Coyle (g00r00) — Mystic BBS ansiedit
- Curtis Wensley — PabloDraw (C# original)
- sysop/0 — CIADraw FPC port, PabloDraw Pascal port, UART layer
- evga — FPC 2.6.4irc, RIP engines, MDL
- kiddo — ansiedit lead, serial_irq.pas, text rendering
- wrench — fossil.pas, netfosdl.pas FOSSIL driver
- hexadecimal — PCBoard integration docs, CIADraw preservation
- verta1878 — project lead, Ecstasy BBS FTN 1:152/158

## License

GPLv3
