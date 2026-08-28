# RIP UI + 16 Color Graphics Support for mystic_test

## The Goal

Real graphical RIP display — 640x350 EGA/VGA mode using FPC's
Graph unit (BGI compatible). No text-mode approximation. Native
pixel rendering like the original RIPterm from the 90s.

Our RIP engine (ripdraw.pas) already uses BGI algorithms —
Bresenham lines, ellipses, arc, flood fill, polygon fill.
We just redirect output from BMP file to live screen.

## What We Have

- `mystic_rip/ripviewer/` — 42/42 v1.54 commands, pixel-perfect
- `mystic_rip/v1/ripscr.pas` — full v1.54 engine (4,041 lines)
- `mystic_test/rip_graph.pas` — RIP graphics canvas (1,091 lines)
- `ripdraw.pas` — BGI drawing primitives (286 lines)
- `riptext.pas` — BGI font text rendering (91 lines)
- `ripbmp.pas` — BMP output (70 lines)
- BGI fonts (.CHR), 219 icons, 259 test RIP files
- EGA 16-color palette (standard CGA/EGA mapping)
- FPC `Graph` unit available for DOS (go32v2) and Win32

## Architecture

### Option 1: FPC Graph Unit (Primary)

FPC's `Graph` unit provides BGI-compatible graphics:

```pascal
Uses Graph;

InitGraph(GD, GM, '');     // 640x350x16 EGA or 640x480x16 VGA
SetColor(14);              // Yellow
Line(0, 0, 639, 349);      // Draw line
OutTextXY(10, 10, 'Hello'); // BGI text
CloseGraph;
```

Our ripdraw.pas primitives map DIRECTLY to Graph calls:
- `RIP_Line` → `Graph.Line`
- `RIP_Rectangle` → `Graph.Rectangle`
- `RIP_Ellipse` → `Graph.Ellipse`
- `RIP_FloodFill` → `Graph.FloodFill`
- `RIP_SetColor` → `Graph.SetColor`
- `RIP_SetFillStyle` → `Graph.SetFillStyle`

This is almost a 1:1 mapping. The RIP spec was DESIGNED
around BGI — TeleGrafix used Borland's BGI as the graphics
layer. FPC's Graph unit is the same API.

Platforms:
- DOS (go32v2): real VGA/VESA hardware, DPMI
- Win32: WinGraph emulation window
- Linux: X11 or framebuffer (limited)

### Option 3: DOS Native (Future)

Direct VESA framebuffer for DOS with memory overlays:

- **VESA 2.0** linear framebuffer at physical address
- **XMS overlay**: swap canvas pages to XMS when not visible
  (up to 64MB on 386+). Allows multiple RIP screens cached.
- **EMS overlay**: 16KB pages for icon/font cache.
  EMS 4.0 gives 32MB, maps into conventional memory window.
- **Combined**: Canvas in XMS, fonts/icons in EMS, active
  page in linear framebuffer. Fast page flip for menus.

```
VESA Framebuffer (640x350x4bit = 112KB)
  ↕ swap via XMS
XMS Bank 0: Menu screen
XMS Bank 1: Message reader screen
XMS Bank 2: File browser screen
  ...
EMS Pages: Font cache, icon cache, mouse cursor
```

This gives instant menu switching — swap a 112KB block
from XMS to framebuffer in <1ms on a 386.

## 16-Color Palette

RIP uses EGA 16-color palette (BGI compatible):
```
 0 = Black         8 = Dark Gray
 1 = Blue          9 = Light Blue
 2 = Green        10 = Light Green
 3 = Cyan         11 = Light Cyan
 4 = Red          12 = Light Red
 5 = Magenta      13 = Light Magenta
 6 = Brown        14 = Yellow
 7 = Light Gray   15 = White
```

Maps 1:1 to:
- BGI color index (Graph unit)
- ANSI attribute foreground (0-15)
- EGA hardware palette registers
- RIP `!|1c` color command parameter

## RIP Buttons and Mouse

RIP v1.54 button command `!|1B`:
```
!|1B x0 y0 x1 y1 hotkey flags label|
```

Defines a clickable region. When clicked (mouse) or hotkey
pressed (keyboard), the label text is sent to the BBS as
if the user typed it.

Mouse in graphics mode:
- DOS: INT 33h mouse driver (cursor, position, buttons)
- Win32: WM_MOUSEMOVE / WM_LBUTTONDOWN from window
- Telnet: not applicable (RIP client handles locally)

## .mrp File Format (Mystic RIP Menu)

Standard RIP commands that define a menu screen. The BBS
sends these to the RIP terminal on menu entry:

```
!|1K              ; Reset windows (clear)
!|1w00001B00      ; Set viewport
!|1c0F            ; Color white
!|1T0008001001Mystic BBS|  ; Text "Mystic BBS"
!|1B000000280050001EL Login|     ; Button "Login" hotkey L
!|1B001400280050001EN New User|  ; Button "New User" hotkey N
```

### Display File Priority

When displaying a screen, Mystic checks for files in this order:

| Extension | What | Capability |
|-----------|------|------------|
| .mrp | Mystic RIP Menu (buttons + mouse fields) | Full RIP GUI |
| .rip | RIP display (graphics, no buttons) | RIP art |
| .ans | ANSI display (text + color) | Fallback |

### File Type Mapping (PCBoard -> Mystic)

| PCBoard | Mystic | What |
|---------|--------|------|
| .MNU | .mrp | Menu definition with clickable RIP buttons |
| .ANS | .rip | Display screen (ANSI equivalent in RIP) |

The BBS stores .mrp files alongside .ans files in the theme directory.

### .mrp Authoring — WIZ Widget Templates

Instead of hand-coding raw RIP escape sequences, .mrp files are built
from reusable widget templates (.wiz files) and readable script commands.
Based on study of JMedia v2.0 authoring system.

#### WIZ Format

A .wiz file is a text file with single-letter drawing commands and
relative coordinate variables. The Wizard command substitutes x, y,
x2, y2 at runtime, making each widget resizable and repositionable.

Commands:

| Cmd | Parameters | What |
|-----|-----------|------|
| c | color | Set drawing color |
| S | style color | Set fill style + fill color |
| B | x y x2 y2 | Filled bar (solid rectangle) |
| R | x y x2 y2 | Rectangle outline |
| L | x1 y1 x2 y2 | Line |
| X | x y | Plot pixel in current draw color |
| F | x y border | Flood fill stopping at border color |

Variables: x, y, x2, y2 (from Wizard command), cx, cy (center).
Arithmetic supported: x+1, y2-1, x+5, x2-5, etc.

Example — BOX1.WIZ (3D raised box):

```
S 1 7                    ; fill solid, light gray
B x+1 y+1 x2-1 y2-1     ; fill interior (inset 1px)
c 15                     ; white
R x y x2 y2              ; outer rectangle
c 8                      ; dark gray
L x y2 x2 y2             ; bottom shadow
L x2 y x2 y2             ; right shadow
```

Usage: `Wizard 10 10 +90 +90 BOX1.WIZ`

Example — METWIN.WIZ (metallic window with title bar):

```
S 1 7                    ; fill solid, light gray
B x+1 y+1 x2-1 y2-1     ; fill interior
c 15                     ; white
R x y x2 y2              ; outer frame
R x+5 y+20 x2-5 y2-4    ; inner content area
c 8                      ; dark gray
L x y2 x2 y2             ; bottom shadow
L x2 y x2 y2             ; right shadow
L x+5 y+20 x+5 y2-4     ; inner left shadow
L x+5 y+20 x2-5 y+20    ; inner top shadow
```

Widget library (from JDraw/JMedia study): 54 .wiz files covering
boxes (BOX1-3), windows (METWIN, MACWIN, WINWIN), buttons (BUT1-6,
BUT1C-6C for pressed state), dialogs (DWIN1-11), utility windows
(UWIN1-11), frames (FRAME1-5), viewer windows (VDWIN1-6).

#### .mrp Script Commands

Human-readable commands that compile to raw RIP. The + prefix on
coordinates means relative (width/height) not absolute.

| Command | Parameters | RIP Equivalent |
|---------|-----------|----------------|
| KillMouseFields | none | !&#124;1K |
| ResetWindows | none | !&#124;# |
| TextWindow | x y x2 y2 wrap font | !&#124;1w |
| SetDimensions | oldW oldH newW newH | (virtual coord scaling) |
| Color | name_or_number | !&#124;1c |
| Bar | x y x2 y2 | !&#124;B |
| Rectangle | x y x2 y2 | !&#124;R |
| Line | x1 y1 x2 y2 | !&#124;L |
| FillStyle | pattern color | !&#124;S |
| FillPattern | 8_bytes color | !&#124;= |
| FontStyle | font dir size | !&#124;Y |
| TextXY | x y text | !&#124;T |
| Wizard | x y x2 y2 filename | (WIZ macro expansion) |
| Button | x y w h hotkey label cmd | !&#124;1B |
| ButtonStyle.* | property value | !&#124;1D |
| Mouse | x y w h hostcmd clientcmd | !&#124;1M |

ButtonStyle properties: Mouse, UnderLine, HighLightKey, LeftJustify,
Bevel, Recess, Chisel, Shadow, Sunken, Invertable, Width, Height,
Bright, Dark, Surface, DFore, DBack, ULineCol. Apply with `ButtonStyle`
(no suffix = commit).

#### Example: Complete BBS Main Menu

```
'main_menu — Mystic BBS main menu
KillMouseFields
ResetWindows
TextWindow 0 0 0 0 0 0

'background
FillPattern 194 180 150 145 168 162 165 203 LightBlue
Bar 0 0 639 349
SetDimensions 640 350 128 100

'title
Wizard 8 4 +110 +15 BOX1.WIZ
FontStyle Triplex HorizDir 4
Color Yellow
TextXY 18 5 MYSTIC BBS

'menu window
Wizard 2 25 +124 +65 METWIN.WIZ
FontStyle Default HorizDir 1
Color Black
TextXY 3 27 MAIN MENU

'buttons
ButtonStyle.Mouse ON
ButtonStyle.UnderLine ON
ButtonStyle.HighLightKey ON
ButtonStyle.LeftJustify ON
ButtonStyle.Width 190
ButtonStyle.Height 20
ButtonStyle

Button 5 33 0 0 f <>File Areas<>f^M
Button 5 41 0 0 m <>Message Areas<>m^M
Button 5 49 0 0 e <>Email<>e^M
Button 5 57 0 0 s <>Settings<>s^M
Button 5 65 0 0 g <>Goodbye<>g^M
```

#### Sysop Workflow

1. Sysop opens menu editor (mystic -cfg or mrpedit)
2. Edits buttons, layout, colors visually or in readable script
3. Hits save — editor compiles to .mrp automatically
4. No manual command line step

The compiler is trivial (JMedia's CODE.EXE is 6KB). The .mrp script
format maps 1:1 to RIP commands — "compilation" is string substitution
+ base-36 encoding. The hard part is the editor UI, not compilation.

| Component | What |
|-----------|------|
| .wiz files | Reusable widget templates (shipped with theme) |
| .mrp source | Readable script (internal to editor) |
| .mrp compiled | Raw RIP commands (sent to terminal) |
| mrpedit | Visual editor (future) |

### Screen Modes for RIP

RIPscrip v1.54 runs in EGA 640x350x16. The editor needs to match.

| Mode | Resolution | Colors | RIP Version |
|------|-----------|--------|-------------|
| EGA EGAHi | 640x350 | 16 | v1.54 (standard) |
| VGA VGAMed | 640x350 | 16 | v1.54 (VGA card in EGA mode) |
| VGA VGAHi | 640x480 | 16 | v2.0+ |

#### FPC Graph Unit — Setting Screen Mode

DOS (go32v2 target):
```pascal
uses Graph;
var gd, gm: SmallInt;
begin
  gd := EGA; gm := EGAHi;     { 640x350x16 for RIP v1.54 }
  InitGraph(gd, gm, '');
end;
```

Linux/Win32 (FPC ptcgraph backend — opens a window at the right resolution):
```pascal
uses ptcgraph;                  { drop-in replacement for Graph }
var gd, gm: SmallInt;
begin
  gd := VGA; gm := VGAMed;     { 640x350 via ptcgraph window }
  InitGraph(gd, gm, '');
end;
```

ptcgraph is BGI-compatible — same API as the DOS Graph unit.
All BGI drawing calls work: SetColor, Rectangle, Bar, Line,
OutTextXY, SetFillStyle, FloodFill, etc. CHR stroked fonts
load with InstallUserFont or our m_rip_chrfont parser.

Tested: FPC 3.2.2, ptcgraph compiles and links on Linux x86_64.
Requires SDL 1.2 (libsdl1.2-dev).

## Phase Plan

### Phase A: Graph Backend for RIPView

Replace ripbmp.pas BMP output with Graph unit output.
ripview becomes a live graphical viewer instead of
file-based renderer.

Files:
- New: `ripgraph_screen.pas` — Graph unit backend
- Modify: `ripview.pas` — add `-g` flag for graphics mode
- Test: display .rip files in a real 640x350 window

### Phase B: RIP Display in BBS

Wire Graph-mode RIP rendering into mystic_test.
When TERM_RIP and local mode, open graphics window
and render RIP commands to it.

Files:
- New: `bbs_rip_display.pas` — manages Graph window for BBS
- Modify: `bbs_io.pas` — route display to Graph when RIP
- Modify: `bbs_menus.pas` — load .mrp, render buttons

### Phase C: Mouse + Button Integration

INT 33h mouse on DOS, window messages on Win32.
Hit-test clicks against RIP button regions.
Return hotkey to menu engine.

Files:
- Modify: `m_mouse.pas` — already in mdl/, needs Graph coords
- Modify: `bbs_io.pas` — mouse click → button hotkey

### Phase D: DOS Memory Overlays (Future)

XMS/EMS page swapping for instant menu switching.
Cache multiple RIP screens in extended memory.

Files:
- New: `m_xms.pas` — XMS 3.0 API
- New: `m_ems.pas` — EMS 4.0 API
- New: `m_rip_cache.pas` — screen page manager

### Phase E: mterm Graphics Mode

Add Graph-mode rendering to mterm terminal emulator.
When connected to a RIP BBS, mterm opens a graphics
window and renders received RIP commands live.

## Dependencies

- FPC `Graph` unit (in fpc264irc for all targets)
- BGI .CHR fonts (in ripviewer/fonts/)
- .ICN icon files (in ripviewer/icons/)
- No SDL required for Phase A-C
- DOS: DPMI + VESA for graphics mode
- Win32: WinGraph creates a window automatically

## Key Insight

The RIP spec IS BGI. Telegrafix built RIPscrip directly
on top of Borland's BGI graphics library. Every RIP drawing
command maps to a BGI function call. FPC's Graph unit IS
BGI. So our path is:

BBS sends RIP commands → parser → BGI calls → Graph unit → screen

No translation layer needed. It's the same API all the way down.

## Status

### Phase A: m_rip_graph.pas — IN PROGRESS (experimental)

`mystic_test/experimental/m_rip_graph.pas` — 974 lines.
Compiles on Win32 (buffer mode). Untested against 42/42 commands.
Needs Arc, PieSlice, FilledPolygon, BGI vector font stubs completed
using proven algorithms from ripdraw.pas before verification.

Implemented:
- TRIPGraphics class with buffer + Graph backends
- Full BGI state management (color, fill, line, write mode, viewport, font)
- PutPixel/GetPixel with viewport clipping and XOR write mode
- Bresenham line drawing
- Rectangle (outline + filled)
- Ellipse (outline + filled) via midpoint algorithm
- Circle (delegates to ellipse)
- FloodFill (stack-based, 16K stack)
- Polygon (outline)
- Text output (8x8 bitmap font via rip_font8x8.inc)
- Mouse regions: DefineRegion, ClearRegions, HitTest
- BMP export (24-bit, bottom-up)
- DOS Graph mode init/close/copy
- EGA 16-color palette with per-session modification

Stubs (TODO):
- Arc with angle clipping
- PieSlice with radial lines + fill
- Cubic Bezier
- Filled polygon (scanline)
- BGI vector font rendering (.CHR files)
- Icon loading (.ICN files)
- XMS/EMS page swapping

Aggressive comments throughout with:
- Purpose, architecture, dependencies, credits
- API quick reference
- 1:1 RIP command → BGI function mapping table
- Every section labeled with RIP command it implements

## Unified Engine — Programs That Benefit

m_rip_graph.pas is the shared graphics backend for ALL programs
in the Mystic BBS ecosystem. One engine, one codebase, consistent
rendering across everything.

### Programs using m_rip_graph.pas

| Program | Directory | How it uses the engine |
|---------|-----------|----------------------|
| ripview | mystic_rip/ripviewer/ | Replace ripbmp.pas BMP output. Add -g flag for Graph mode. Verify pixel-perfect match. THIS IS THE TEST BED. |
| mystic_test | mystic_test/ | Live RIP display for RIP terminals. Render .mrp menus. Mouse button hit-test. |
| mystic_ansieditor2 | mystic_ansieditor2/ | 16-color canvas. Could render ANSI art at pixel level for preview. |
| mterm | examples/mterm/ | RIP graphics mode when connected to RIP BBS. Replace mtrip.pas text-mode parser with real pixel rendering. |
| ans2rip | mystic_rip/ | Already uses BGI algorithms. Unify with shared engine. |
| ans2png | mystic_rip/ | ANSI renderer. Could use m_rip_graph for pixel buffer + BMP export. |

### Integration Order

1. **ripview** — FIRST. Swap backend, verify 42/42 still pixel-perfect.
   This proves the engine works. No risk to BBS.

2. **mystic_test** — SECOND. Wire RIP display into BBS. If it breaks,
   mystic_test is the experimental tree — mystic/ stays clean.

3. **mterm** — THIRD. Graphics mode for the terminal emulator.
   Receives RIP commands from BBS, renders via m_rip_graph.

4. **ans2rip / ans2png** — FOURTH. Unify the converter tools.
   Low risk, same algorithms already proven.

5. **mystic_ansieditor2** — FIFTH. Pixel-level ANSI preview.
   Nice-to-have, not critical path.

### Why mystic_test is Safe

mystic_test/ is the experimental tree. ALL RIP code, ALL fixes,
ALL new features go here first. mystic/ stays clean — the stable
A3 base. If m_rip_graph breaks something in mystic_test, we fix
it there. mystic/ is never touched until features are proven.

This is why we have two trees:
- mystic/      = stable, ships to sysops
- mystic_test/ = experimental, ships to the crew

### Notes for the Team

**evga:** m_rip_graph.pas replaces your ripbmp.pas pixel buffer.
Same TPixelBuffer layout, same EGA palette, same PutPixel API.
Your ripviewer drawing code (ripdraw.pas) stays — just change
the PutPixel calls to go through TRIPGraphics instead of the
global Canvas record.

**kiddo:** The RIP command parser (rip1exec.pas) calls drawing
functions. Those calls now go through m_rip_graph instead of
ripdraw.pas directly. Same function names, same parameters.
Your parser code doesn't change — only the backend it draws to.

**sysop/0:** DOS Graph mode is ready in m_rip_graph. InitGraphMode
opens 640x350 EGA or 640x480 VGA via FPC's Graph unit. PutPixel
dual-writes to both buffer and screen. XMS/EMS page swapping
comes later as Phase D.

**wrench:** mterm's mtrip.pas RIP parser can switch to m_rip_graph
for real pixel rendering instead of text-mode approximation.
When connected to a RIP BBS, mterm opens a graphics window
and renders received commands through the unified engine.

**verta1878:** The test order protects the BBS. ripview first
(standalone, no risk), mystic_test second (experimental tree),
mystic/ never until proven. Same strategy we've used all along.

## CRITICAL: Resolution Change + ANSI Coexistence

### The Problem

Mystic's entire console output system (WriteXY, AnsiColor,
AnsiGotoXY, BufFlush, status bar, menus, prompts, user input)
is built for 80x25 text mode. Switching to 640x350 graphics
mode will BREAK all text output:

- No text cursor in graphics mode
- WriteXY writes to text buffer — doesn't exist in graphics
- Status bar, menus, prompts — all gone
- Input display (user typing) — gone
- Every WriteXY call in every unit — broken

WE DO NOT KNOW what happens to Mystic's ANSI rendering at
graphics resolution. DO NOT add RIP graphics to mystic until
this is understood and solved.

### How Original RIPterm Solved It

RIPterm used a SPLIT SCREEN:
- Top portion: RIP graphics viewport (pixel rendering)
- Bottom portion: ANSI text window (standard text mode)
- Both coexist on the same screen simultaneously

The RIP v1.54 `!|1w` (text window) command defines where the
text area lives within the graphics screen. Text I/O goes to
the text window. Graphics draw above/around it.

### What We Need to Research

1. How does FPC Graph unit handle text output in graphics mode?
   - Graph.OutTextXY exists — but it's pixel-based, not cell-based
   - Does SetTextStyle + OutTextXY give us usable text?

2. Can we keep a text window within the graphics screen?
   - RIPterm did it — text scrolls in a defined region
   - Need to implement text cursor, scrolling, ANSI parsing
     within a pixel-rendered text area

3. Should we use dual-mode instead?
   - Text mode for ANSI portions (menus, prompts, input)
   - Switch to graphics mode only for RIP rendering
   - Switch back to text for input
   - This flickers but is simpler

4. On DOS: VGA supports split screen via CRTC registers
   - Top half: graphics mode (RIP viewport)
   - Bottom half: text mode (ANSI window)
   - Hardware split — no flicker, no mode switching
   - Need to program VGA CRTC Line Compare register

5. On Win32: could use separate window for graphics
   - Console window stays for text (existing code works)
   - Graphics window opens alongside for RIP rendering
   - Two windows, no mode conflict

### Decision: DO NOT wire RIP graphics into mystic yet

Until we understand and solve the ANSI coexistence problem,
the experimental engine stays isolated.

#### Engine Status (Session 6)

TWO engines exist:

1. **ripdraw.pas** (examples/ripviewer/source/) — PROVEN
   - 42/42 RIPscrip v1.54 commands, pixel-perfect verified
   - Flat procedures, global vars, BMP output only
   - Has: Arc, PieSlice, FilledPolygon, BGI vector fonts
   - Missing: LineStyle, WriteMode, Palette, Viewport, Mouse, Graph output

2. **m_rip_graph.pas** (mystic_test/experimental/) — UNTESTED
   - TRIPGraphics class, buffer + Graph unit backends
   - Has: LineStyle, WriteMode, Palette, Viewport, Mouse, Graph output
   - Missing (stubs): Arc, PieSlice, FilledPolygon, BGI vector fonts

#### Decisions Made

- Both engines will be brought to FEATURE PARITY before merging
- ripdraw.pas proven algorithms will be ported INTO m_rip_graph.pas stubs
- m_rip_graph.pas stays in mystic_test/experimental/ until it passes
  42/42 pixel-perfect verification
- When ready, promote to mdl/ and use {$IFDEF EXPERIMENTAL_RIP} to
  switch engines at compile time — no file shuffling
- ripviewer continues using ripdraw.pas (working code) until swap
- ANSI coexistence must be solved before wiring into mystic_test
- Do NOT update all programs at once — mystic_test first, then others

#### File Locations

- ripdraw.pas (production): examples/ripviewer/source/
- m_rip_graph.pas (experimental): mystic_test/experimental/
- rip_graph.pas (BBS integration): mystic_test/rip_graph.pas
- v1-v4 engines: mystic_rip/v1/ v2/ v3/ v4/

### Next Steps

1. ~~Port ripdraw.pas Arc/PieSlice/FilledPolygon/VectorFont into m_rip_graph.pas~~ DONE
2. ~~Port m_rip_graph.pas LineStyle/WriteMode/Palette/Viewport into ripdraw.pas~~ DONE
3. Test both engines against 259 RIPs — pixel-perfect match required — IN PROGRESS
4. Research ANSI coexistence (VGA split screen, text-in-graphics, mode switching)
5. Only then wire into mystic_test with {$IFDEF EXPERIMENTAL_RIP}
6. Needs evga for display layer architecture decisions

### Phase 3 Test Results (Session 6)

Test harness: test_phase3.pas + bmpcompare.pas (pure Pascal, no external deps)
Three-way comparison designed by sysop/0:
  1. ripdraw BMP vs m_rip_graph BMP — do both engines agree?
  2. ripdraw BMP vs reference PNG — is evga's engine correct?
  3. m_rip_graph BMP vs reference PNG — is kiddo's engine correct?

#### Engine A (ripdraw — evga): RUNS, CLOSE ON PRIMITIVES

- Compiled and rendered with real fonts
- Results with proper font data (sysop/0 report):

  | File     | Pixels Diff | %     | Analysis                          |
  |----------|-------------|-------|-----------------------------------|
  | L_LINE   | 10,700      | 1.3%  | Line endpoint or thickness diff   |
  | V_ARC    | 11,475      | 1.4%  | Arc rasterization rounding        |
  | S_FILL   | 60,014      | 7.3%  | Fill pattern or boundary issue    |
  | DRAGON01 | 818,815     | 99.9% | Systemic — palette/background init|

- L_LINE and V_ARC at ~1% — primitive math is close, edge cases only
- DRAGON01 at 99.9% — systemic issue: canvas background init or
  EGA palette mapping differs from JS canvas defaults
- Action for evga: fix background color init and palette mapping first,
  then remaining 1-2% on lines/arcs is endpoint rounding

#### Engine B (m_rip_graph — kiddo): CRASHES

- EAccessViolation at runtime even with real deps
- Constructor allocates pixel buffer correctly (New → Reset → FillChar)
- Real cause: RIP1Exec calls ripdraw's global procedures (PutPixel,
  DrawLine etc), NOT m_rip_graph's TRIPGraphics methods. The
  {$IFDEF EXPERIMENTAL_RIP} in test_phase3 creates a TRIPGraphics
  object but the RIP command dispatcher still calls the old engine.
- This is a Phase 4 problem — RIP1Exec needs an abstraction layer
  or {$IFDEF} to route commands to either engine
- Action for kiddo: wire RIP1Exec to call m_rip_graph methods when
  EXPERIMENTAL_RIP is defined

#### What Was Sent to sysop/0

- phase3-test-files.zip (test_phase3.pas, bmpcompare.pas, PHASE3-TESTING.md)
- rip1-parser-files.zip (rip1parse.pas, rip1exec.pas)
- rip-test-files.zip (259 test RIPs with reference PNGs)
- rip-engines-comparison.zip (both engines)
- phase3-missing-deps.zip (m_strings.pas, rip_font8x8.inc, rip_font8x16.inc)
- phase3-complete.zip (flat, all files + rip_compat.pas)

#### Three-Way Test Results - FINAL (sysop/0 report)

Both engines run. 6/6 rendered each. BMP format standardized to 8-bit
indexed via -dBMP_8BIT. rip_compat.WriteBMP routes through ripbmp.pas.

Engine A vs Engine B (direct byte comparison, same 8-bit format):

  | File     | Bytes diff | of 820,278 | %      | Notes              |
  |----------|-----------|------------|--------|--------------------|
  | BUTTONS  | 2         | 820,278    | 0.0002%| Near pixel-perfect |
  | L_LINE   | 5,249     | 820,278    | 0.6%   | Endpoint rounding  |
  | V_ARC    | 3,833     | 820,278    | 0.5%   | Arc rasterization  |
  | Y_FONT   | 12,108    | 820,278    | 1.5%   | Font positioning   |
  | S_FILL   | 28,472    | 820,278    | 3.5%   | Fill boundary      |
  | DRAGON01 | 224,002   | 820,278    | 27.3%  | Palette/init diff  |

Both engines vs Reference PNG:

  | File     | Engine A | Engine B | Best |
  |----------|----------|----------|------|
  | L_LINE   | 7,368    | 11,271   | A    |
  | V_ARC    | 4,084    | 6,635    | A    |
  | S_FILL   | 45,322   | 36,830   | B    |
  | Y_FONT   | 62,517   | 53,323   | B    |
  | BUTTONS  | 91,231   | 91,231   | tie  |
  | DRAGON01 | 818,723  | 605,726  | B    |

Key findings:
  - BUTTONS: 2 bytes diff between engines - near pixel-perfect agreement
  - Engine A wins on geometry (lines 0.6%, arcs 0.5% closer to reference)
  - Engine B wins on rendering state (fills, text, palette init)
  - BUTTONS tie at 91K - shared bug from RIPtermJS port (text positioning)
  - DRAGON01: A=99.9% off, B=73.9% off - both have palette/init issues

#### BMP Format Fixes (Session 6)

Three fixes applied:
  1. ripbmp.pas BGR byte order - R and B were swapped (99.9% diffs)
  2. ripbmp.pas dual mode - -dBMP_8BIT for 8-bit indexed (Phase 3),
     default 24-bit for future RIP v2/v3 browser
  3. rip_compat.pas WriteBMP - copies G pixels to RIPEngine.Canvas,
     calls RIPBMP.WriteBMP so both engines use same writer

#### Phase 3 Test History

Full test-by-test changelog with numbers, fixes, and what each
run changed: examples/ripviewer/PHASE3-CHANGELOG.md

7 test runs so far. Key milestones:
  - Run 2: first real numbers (placeholder fonts fixed)
  - Run 3: Engine B runs (rip_compat bridge)
  - Run 5: first direct A-vs-B comparison (8-bit BMP standardized)
  - Run 7: command parser fix (PENDING retest — expected major improvement)

#### Command Parser Bug — FIXED (Session 6)

MAJOR BUG: The parser only accepted !| as command prefix. RIPscrip uses
!| for the FIRST command on a line and just | for subsequent commands on
the same line. DRAGON01 has 8+ commands per line — only the first was
being executed. All subsequent commands were silently skipped.

Example from DRAGON01.RIP line 1:
  !|*|1K|w0013271610|c08|W0|=00000001|ZFC0ZFL1OHF0NHM1D1E
  ^^                                                        processed
     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^      ALL SKIPPED

This affected EVERY RIP file with multiple commands per line — which is
most of them. The 99.9% diff on DRAGON01 was not palette init — it was
the parser ignoring most of the drawing commands.

Fix applied to rip1parse.pas and rip1exec.pas:
  - ParseRIPCommand now accepts both !|X and |X as command start
  - ExecuteRIP loop looks for ! OR | as command entry point
  - Both engines affected equally since they share rip1parse/rip1exec

Additional fixes applied this round:
  - EGA64toRGB function added for rcSetPalette and rcOnePalette
    (previously used wrong conversion: C And 15, LongWord * 256)
  - Engine B Arc/PieSlice upgraded to elliptical (XRad + YRad)
    (previously only circular — dropped YRad through rip_compat)

#### Canvas Height Bug - FIXED (Session 6, visual diffs)

sysop/0 sent visual diff images. Root cause immediately visible:
  - Reference PNG: 640 x 350 (correct EGA)
  - Engine A BMP:  640 x 1280 (WRONG)
  - Engine B BMP:  640 x 1280 (WRONG)

ripengine.pas had RIP_HEIGHT = 1280. Fixed to 350.
This was the 98.9% DRAGON01 diff - not palette, not parser.
The dragon was rendering correctly in rows 0-349 but the
BMP file had 930 extra rows of black pixels.

Visual diffs also revealed:
  - DRAGON01 flood fill fills OUTSIDE the dragon (green background)
    instead of inside. FloodFill border color or fill direction bug.
  - BUTTONS renders blank - button drawing code produces no pixels.
  - Y_FONT some CHR fonts not loading (file path issue).

Awaiting retest by sysop/0 with height fix.

#### Priority Fix Order (updated)

  1. DONE - Command parser | separator fix (the big one)
  2. DONE - EGA64toRGB palette conversion
  3. DONE - Engine B elliptical arc support
  4. Engine B line/arc endpoints - Bresenham rounding vs Engine A
  5. Both engines S_FILL - fill pattern boundaries
  6. Both engines Y_FONT - glyph positioning
  7. Both engines BUTTONS - text positioning
  8. Run against full 118 RIPs with parser fix
  9. Phase 4: wire {$IFDEF EXPERIMENTAL_RIP} into mystic_test

#### Merge Path (sysop/0 direction)

Use evga's line/arc math (better Bresenham) + kiddo's palette init.
This is the end-state architecture sysop/0 defined earlier:
evga's primitives = shared drawing core, kiddo's class = wrapper.
#### rip_compat.pas — Engine Bridge (Session 6)

Created `examples/ripviewer/source/rip_compat.pas` — compatibility layer that
maps ripdraw's global API (DrawLine, FillRect, Canvas.FG etc) to m_rip_graph's
TRIPGraphics methods. Uses SyncToG/SyncFromG to keep Canvas state synchronized.

rip1exec.pas change: one {$IFDEF EXPERIMENTAL_RIP} in the Uses clause:
  - Without define: uses RIPEngine, RIPDraw, RIPText (Engine A)
  - With define: uses RIP_Compat (routes to Engine B via G.Method() calls)

Both modes compile clean. No other source changes needed.

#### Scene Release Plan (verta1878/sysop/0 decision)

evga's standalone engine to be released as a separate GitHub repo for the
BBS/ANSI art scene. PabloDraw has no RIP support — this fills that gap.

Release scope (standalone, no Mystic dependencies):
  - ripengine.pas — canvas, palette, pixels
  - ripdraw.pas — drawing primitives
  - riptext.pas — VGA 8x16 text rendering
  - ripbmp.pas — BMP file output
  - rip1parse.pas — v1.54 mega decoder + command parser
  - rip1exec.pas — v1.54 42-command dispatcher
  - rip_font8x16.inc — VGA font data
  - GPLv3, credit Carl Gorringe for RIPtermJS port origin

NOT released (Mystic-specific):
  - m_rip_graph.pas — TRIPGraphics class, multi-backend
  - rip_compat.pas — engine bridge layer
  - bmpcompare.pas, test_phase3.pas — internal test tools

#### Visual Analysis — Test Run 8 (640x350 correct)

sysop/0 visual diffs with corrected canvas height:

  L_LINE: CLOSE. Lines render correctly. Starburst patterns match
    reference. Small endpoint rounding on diagonals only.
    FIX NEEDED: None critical — endpoint rounding is sub-pixel.

  S_FILL: PATTERNS MISSING. Fill colors are correct but all fills
    are solid. Reference shows hatch/stripe/dot/cross patterns.
    FIX NEEDED: Implement BGI fill patterns in FloodFill and FillRect.
    The FillStyle field is set but never used — solid fill always.

  Y_FONT: BITMAP OK, VECTOR MISSING. 8x16 bitmap font renders.
    CHR vector fonts (large colored text) absent.
    FIX NEEDED: CHR font file path resolution. The .CHR files exist
    in fonts/ but the engine can't find them at runtime.

  DRAGON01: FLOOD FILL INVERTED. Dragon outlines and bezier curves
    render correctly. But flood fills fill the OUTSIDE of shapes
    instead of the inside. Background is green, dragon body is black.
    FIX NEEDED: FloodFill border color logic — may be comparing
    against wrong color or starting from wrong seed point.

  BUTTONS: BLANK. Button widget commands parse but nothing draws.
    FIX NEEDED: Implement rcButton/rcButtonStyle rendering.
    This is a UI widget system — rectangles + text + bevels.
    Lower priority — most RIP art doesn't use buttons.

#### JS-Matched Bresenham — FIXED (Session 6 Run 18)

ROOT CAUSE of DRAGON01 flood fill leak: Standard Bresenham (err=dx-dy)
and JS Bresenham (den/num/numadd) produce DIFFERENT pixel positions on
diagonal lines. Adjacent bezier curves share endpoints — when the line
algorithm places the endpoint pixel differently, a 1-pixel gap forms.
Flood fill leaks through the gap to the entire background.

Fix: Replaced DrawLine with exact JS BGI.js line_bresenham algorithm.
Bezier curves now produce gap-free junctions. Flood fills stay contained.

DRAGON01 now renders: black background, green dragon body, dark gray
outlines, red eye, teeth, Continue button, text labels. Locally verified.

Complete fix list this session (Runs 1-18):
  1. RIP_HEIGHT 1280->350 (canvas too tall)
  2. | command separator (parser only accepted !|)
  3. BMP BGR byte order (R/B swapped)
  4. BMP 8-bit indexed mode (-dBMP_8BIT)
  5. rip_compat WriteBMP routing (Engine B format mismatch)
  6. EGA64toRGB palette conversion (rcSetPalette/rcOnePalette)
  7. Engine B elliptical arcs (XRad+YRad, was circular only)
  8. rcTextWindow |w parameter length 12->10 (ate |c color command)
  9. rcGetImage |1C parameter length 10->9
  10. rcPutImage |1P parameter length 8->7
  11. Fill patterns (13 BGI patterns in PutFillPixel)
  12. FloodFill visited buffer (prevent leak through pattern gaps)
  13. CHR vector font loading (LoadCHRFont with path search)
  14. Button renderer (rcButton + rcButtonStyle with bevel/colors)
  15. Bezier Floor() matching JS Math.floor()
  16. JS-matched Bresenham line algorithm (den/num/numadd)
  17. Bezier explicit endpoint (last segment to exact P3)

#### Current Scores (awaiting sysop/0 retest with Run 18 code)

Locally verified — all 6 test files render correctly.
DRAGON01 visually matches reference (green dragon, black background).
Exact pixel diff numbers pending from sysop/0.

#### Final Scores — Session 6 Complete (20 test runs)

  PIXEL-PERFECT:
    F_FILL1:       1  (0.0%)
    F_FILL2:       1  (0.0%)

  EXCELLENT (< 2%):
    S_FILL:    2,646  (1.2%)
    DRAGON01:  3,497  (1.6%)
    V_ARC:     4,114  (1.8%)
    L_LINE:    4,424  (2.0%)

  NEEDS WORK:
    Y_FONT:   35,148  (15.7%) — CHR scale improved, needs Y-offset

  Bresenham tradeoff: JS Bresenham fixed DRAGON01 (98.9%->1.6%) but
  regressed L_LINE (0.8%->2.0%), V_ARC (0.4%->1.8%), S_FILL (0.7%->1.2%).
  Future work: use JS Bresenham for bezier curves only, original
  Bresenham for regular lines. Deferred.

  19 bugs fixed across 20 test runs. All documented in
  examples/ripviewer/PHASE3-CHANGELOG.md with full numbers and
  root cause analysis.

#### Ripview Completion Status — Session 6 Final

  RENDERING ENGINE: 42/42 RIPscrip v1.54 commands implemented.
  
  PIXEL ACCURACY (27 test runs, 25+ bugs fixed):
    3 pixel-perfect: F_FILL1, F_FILL2, v_VIEW
    10 of 13 under 3% diff vs RIPtermJS reference
    DRAGON01: 98.9% → 1.0% (99x improvement)

  ALGORITHMS MATCHED TO JS:
    - Bresenham line (den/num/numadd)
    - Bezier curves (Floor rounding, explicit endpoint)
    - Flood fill (visited buffer, bgcolor for pattern gaps)
    - Fill patterns (13 BGI patterns, absolute alignment)
    - Viewport offset (PutPixel/GetPixel add ViewX1/ViewY1)
    - EGA64 palette (RGBrgb bit order)
    - CHR font scaling (FontScales float lookup)
    - Button bevel (draws outside coords)

  REMAINING 3 FILES:
    Y_FONT 14.7%  — JS moveto/lineto stroke font CP model
    BUTTONS 17.8% — icon button images, full flag system
    C_WELL 26.1%  — circle precision (JS has FIXME)

  MDL INTEGRATION:
    SDL units moved from mystic_sdl/ to mdl/
    serial_ext.pas added (6 serial functions)
    utrayit.pas bugfix deployed to all 4 locations
    MDL-OOP-ANALYSIS.md: 76% already OOP, 3-step migration plan

### Linux Terminal Setup for Mystic BBS

Before running Mystic in a Linux terminal, set CP437 codepage:

```
echo -e '\033(U'
```

This sends ESC(U which switches the Linux console to CP437 character
set. Without it, high-ASCII characters (block drawing ░▒▓█▄▀│─)
display as garbled UTF-8.

Mystic 1.11IRC sends ESC(U automatically at startup, but the terminal
must support it. Most Linux console terminals (xterm, rxvt, PuTTY)
honor this sequence.

For UTF-8 terminals, switch back with:
```
echo -e '\033(B'
```

ESC(B restores ISO 8859-1 / UTF-8 character set.

Build commands:
```
# Text mode (standard)
fpc -Mdelphi -Fu../mdl mystic.pas

# Graphics mode (640x350 ptcgraph window)
fpc -Mdelphi -dUSEGRAPH -Fu../mdl -Fu../mdl/m_rip mystic.pas
```
