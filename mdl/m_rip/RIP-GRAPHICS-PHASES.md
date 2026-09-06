# RIP Graphics Phases — mystic_test, mterm, ripview

All three programs share the same rendering stack (`mdl/m_rip/`) and display
approach. This document covers setup, integration, display output, and testing
for all three in one place.

Reference: `todo/RIPSCRIP.md` — how Mystic serves RIP content

## Programs

| Program | Role | Display |
|---------|------|---------|
| mystic_test | BBS server — serves RIP content to callers, sysop preview | FPC Graph on DOS, text console on Linux |
| mterm | Terminal — connects to BBS, renders RIP graphics for caller | FPC Graph on DOS, text console on Linux |
| ripview | Viewer — renders .RIP files offline | FPC Graph on DOS, BMP export on Linux |

## Shared Infrastructure

All three use:
- `mdl/m_rip/ripengine.pas` — pixel buffer, canvas state, PutPixel/GetPixel
- `mdl/m_rip/ripdraw.pas` — drawing primitives (line, circle, bar, fill, etc.)
- `mdl/m_rip/riptext.pas` — text rendering, CHR fonts
- `mdl/m_rip/ripbmp.pas` — BMP export (debug/headless)
- `mdl/m_rip/v1/rip1parse.pas` — v1.54 command parser
- `mdl/m_rip/v1/rip1exec.pas` — v1.54 command executor
- `mdl/m_rip/rip_font8x8.inc` — IBM VGA ROM 8x8 font
- `mdl/m_rip/rip_font8x14.inc` — IBM VGA ROM 8x14 font
- `mdl/m_rip/rip_font8x16.inc` — IBM VGA ROM 8x16 font

---

## Phase 1: Setup (RIP-M1 — RIP-M4)

| Phase | What |
|-------|------|
| RIP-M1 | Create mystic_test/mdl/ with fonts and shared rendering stack |
| RIP-M2 | Create mystic_test/text/rip/ with test .rip display files |
| RIP-M3 | Create RIP-enabled menu (.mnu) that sends .rip files |
| RIP-M4 | Create mystic_test/icons/ with test .ICN icon files |

## Phase 2: Mystic RIP Integration (RIP-M5 — RIP-M10)

| Phase | What | Program |
|-------|------|---------|
| RIP-M5 | Display file resolution: .rip → .ans fallback | mystic_test |
| RIP-M6 | RIP terminal detection: !|1Q00000000 query + R response | mystic_test |
| RIP-M7 | Raw .rip file sending (no ANSI processing, no MCI) | mystic_test |
| RIP-M8 | Test: mterm → mystic, RIP detected, .rip menu displayed | mterm + mystic_test |
| RIP-M9 | Test FlushRIPBuf with actual !| over live TCP | mterm |
| RIP-M10 | MCI codes: \|RI (RIP reset) and \|TE (terminal type) | mystic_test |

## Phase 3: DOS VGA Display (VGA-1 — VGA-7)

FPC `uses Graph` on DOS = direct VGA hardware. No ptcgraph, no X11.
RIPscrip v1.54 video mode: EGA Mode 10h — 640×350×16 colors.
v1/v2: real-mode DOS — no DPMI/GO32V2 extender needed.
v3/v4: GO32V2 (protected mode) for large buffers.

| Phase | What | Program |
|-------|------|---------|
| VGA-1 | `uses Graph`, `InitGraph(VGA, VGAMed)` under `{$IFDEF DOS}` | mterm |
| VGA-2 | RIP engine renders to Graph framebuffer (PutPixel/Line/Circle/Bar) | mterm |
| VGA-3 | `uses Graph` for screen display on DOS | ripview |
| VGA-4 | Screen default on DOS, BMP default on Linux | ripview |
| VGA-5 | `uses Graph` for server-side RIP preview under `{$IFDEF DOS}` | mystic_test |
| VGA-6 | Cross-compile all three with fpc264irc (real-mode DOS for v1/v2) | all |
| VGA-7 | Test mterm.exe in DOSBox → telnet → Mystic → RIP on VGA | mterm |
| VGA-8 | Test ripview.exe in DOSBox → .RIP on VGA screen | ripview |
| VGA-9 | Test mystic.exe in DOSBox → sysop sees RIP screens on VGA | mystic_test |

## Phase 4: SDL 1.2 Display (Future / Maybe)

If Linux/Windows screen display is needed beyond DOS/DOSBox.

| Phase | What | Program |
|-------|------|---------|
| SDL-1 | SDL 1.2 display unit for pixel framebuffer | shared |
| SDL-2 | Render to SDL surface under `{$IFDEF SDL}` | mterm |
| SDL-3 | Render to SDL surface under `{$IFDEF SDL}` | ripview |
| SDL-4 | Render to SDL surface under `{$IFDEF SDL}` | mystic_test |
| SDL-5 | Test on Linux — native SDL window, no DOSBox | all |

## Build Commands

```
# Linux (native) — text console + BMP export
cd mystic_test && fpc -Mdelphi -Fu../mdl -Fi../mdl mystic.pas
cd mystic_mterm && fpc -Mdelphi -Fu../mdl -Fu../mdl/m_rip -Fu../mdl/m_rip/v1 -Fi../mdl mterm.pas
cd mystic_ripview/source && fpc -Mdelphi -Fu../../mdl/m_rip -Fu../../mdl/m_rip/v1 ripview.pas

# DOS (fpc264irc) — FPC Graph VGA display
fpc264irc -Mdelphi -dDOS -Fu../mdl -Fi../mdl mystic.pas → mystic.exe
fpc264irc -Mdelphi -dDOS -Fu../mdl -Fu../mdl/m_rip mterm.pas → mterm.exe
fpc264irc -Mdelphi -dDOS -Fu../../mdl/m_rip ripview.pas → ripview.exe
```

## Platform Summary

| Platform | Display | RIP Rendering | Build |
|----------|---------|--------------|-------|
| DOS (DOSBox) | FPC Graph → VGA Mode 10h | Direct to VGA framebuffer | fpc264irc |
| Linux | Text console (mterm), BMP file (ripview) | Pixel buffer in memory | fpc native |
| Linux + SDL (future) | SDL 1.2 window | Pixel buffer → SDL surface | fpc native + SDL |

## Phase 0: Replace Homebrew Primitives with FPC Graph (VIPER-FIX)

The core issue: `ripdraw.pas` uses homebrew Bresenham/midpoint/scanline
code instead of FPC's `Graph` unit. JVIEW (the byte-for-byte reference)
uses `uses Graph` (BGI) for all rendering — Line, Circle, Bar, FloodFill,
etc. Our output doesn't match because we reimplemented these instead of
using the same API.

`m_output_graph.pas` (archived in `attic/rip_v1_homebrew/`) was the right
concept — an mdl unit providing the graphics drawing API. It needs to be
resurrected, stripped of ptcgraph/X11, and rewired:
- `{$IFDEF DOS}`: FPC `Graph` unit (= BGI, pixel-perfect)
- `{$ELSE}`: pixel buffer in memory (headless, BMP export)

Then `ripdraw.pas` calls through this unit instead of homebrew primitives.
Same API as JVIEW's RIPCMD.PAS → same pixel output.

This is Phase 0 because everything else (RIP-M, VGA, SDL) depends on
correct rendering. Must be done first.

| Phase | What |
|-------|------|
| FIX-1 | Resurrect m_output_graph.pas from attic, strip ptcgraph |
| FIX-2 | Add {$IFDEF DOS} path using FPC Graph unit |
| FIX-3 | Add {$ELSE} path using pixel buffer (headless/Linux) |
| FIX-4 | Replace ripdraw.pas homebrew calls with m_output_graph calls |
| FIX-5 | Verify: ripview renders BILL.RIP + GOD-CTH.RIP — compare against JVIEW |
| FIX-6 | Verify: all three programs compile clean (Linux + DOS cross-compile) |
