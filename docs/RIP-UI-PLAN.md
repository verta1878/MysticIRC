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

The BBS stores .mrp files alongside .ans files.
Display priority: .mrp → .rip → .ans (existing)

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

### Phase A: m_rip_graph.pas — COMPLETE

`mdl/m_rip_graph.pas` — 974 lines.
Compiles on Win32 (buffer mode). DOS Graph mode ready but
untested (needs go32v2 target).

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
| chg2rip | mystic_rip/ | Already uses BGI algorithms. Unify with shared engine. |
| ans2png | mystic_rip/ | ANSI renderer. Could use m_rip_graph for pixel buffer + BMP export. |

### Integration Order

1. **ripview** — FIRST. Swap backend, verify 42/42 still pixel-perfect.
   This proves the engine works. No risk to BBS.

2. **mystic_test** — SECOND. Wire RIP display into BBS. If it breaks,
   mystic_test is the experimental tree — mystic/ stays clean.

3. **mterm** — THIRD. Graphics mode for the terminal emulator.
   Receives RIP commands from BBS, renders via m_rip_graph.

4. **chg2rip / ans2png** — FOURTH. Unify the converter tools.
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
m_rip_graph.pas stays in MDL as a standalone library.

Safe to use in:
- ripview (standalone viewer, no text mode needed)
- mterm (can manage its own display modes)
- chg2rip / ans2png (file converters, no display)

NOT safe to use in:
- mystic.exe (would break all text output)
- mis.exe (console-based server monitor)
- any BBS binary that uses WriteXY

### Next Steps

1. Research FPC Graph text output capabilities
2. Study VGA split screen (CRTC Line Compare) for DOS
3. Prototype: ripview with graphics mode — standalone test
4. Prototype: text rendering within graphics mode
5. Only then consider wiring into mystic_test
