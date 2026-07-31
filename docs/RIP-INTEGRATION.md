# RIP in Mystic a38 — integration design (mapped to the real source)

*Now written against the actual Mystic a38 tree, not a sketch. Maps the RIP client
engine we built (`ripterm_client_v0`) onto Mystic's real classes and files.*

---

## 1. The class RIP parallels: `TTermAnsi`

Confirmed in the source. The ANSI class is **`TTermAnsi`**, in **`mdl/m_term_ansi.pas`**:

```pascal
Unit m_Term_Ansi;
Uses m_Output, m_io_Base, m_Strings;
Type
  TTermAnsi = Class
    Screen  : TOutput;          // render target
    Client  : TIOBase;          // reply channel (query responses)
    State   : Byte;             // parser state machine
    Options : String;           // accumulated parameters
    ...
    Constructor Create (Var Con: TOutput);
    Procedure   Process (Ch: Char);              // feed one char
    Procedure   ProcessBuf (Var Buf; BufLen : Word);
    Procedure   SetReplyClient (Var Cli: TIOBase);
  End;
```

It's a **stream interpreter**: `Process(Ch)` runs a state machine over an incoming
terminal stream and renders to `Screen: TOutput`. That is exactly the shape a RIP
class takes — which is why your "a class like the ANSI class" instinct was dead on.

**Where it's used (the hook points), from the source:**
- `mystic/bbs_io.pas` — `TBBSIO` holds `Term: TTermAnsi`, `Term := TTermAnsi.Create(Console)`, feeds `Term.Process(Ch)`.
- `mystic/mis.pas` — the telnet server, same pattern.
- `mystic/nodespy_term.pas` — node-spy terminal viewer, same pattern.

## 2. The one real difference: render target

`TTermAnsi` renders to **`TOutput`** — a **text-cell** model (80x25 CP437, char +
attribute per cell; platform classes `TOutputCRT/Windows/Linux/Darwin`). RIP is
**graphics** (vector primitives, pixels). So a RIP class **cannot** render to the
text `TOutput`. It needs a **graphics canvas**.

This is precisely the gap the `IRipCanvas` seam (from the client) fills.

## 3. The bridge already exists: the SDL pixel surface

Mystic's SDL front-end already does pixel rendering. In
**`mystic_sdl/sdl_dosscreen.pas`**, `TDosScreen`:
- 80x25 cells → an **ARGB pixel buffer** `FPixels: Array of LongWord` (640x400 px,
  8x16 font),
- presented via SDL2 (`sdl_bind.pas`: renderer + texture),
- with a **headless PPM export** for testing.

That is the *same architecture* as our RIP framebuffer: a pixel buffer + SDL
present + headless image export (we used BMP). The two were built to meet.

## 4. How the client engine maps in

| Client unit (built) | Becomes in Mystic | Role |
|---|---|---|
| `RipParser.pas` | core of new **`mdl/m_term_rip.pas`** (`TTermRip`) | the `!|` / mega-number / level-1 state machine — parallels `TTermAnsi` |
| `RipCanvas.pas` (`IRipCanvas`) | the graphics render-target interface | the seam RIP draws to instead of text `TOutput` |
| `RipFrameBuffer.pas` | a `TRipSurface` drawing into an ARGB buffer | presented via the same `sdl_bind` layer `TDosScreen` uses |

So `TTermRip` gets the **same public shape** as `TTermAnsi`
(`Create`, `Process`, `ProcessBuf`, `SetReplyClient`) — drop-in parallel — but its
`Screen` is a graphics canvas, not text `TOutput`.

## 5. Two directions (keep them distinct)

- **Rendering/interpreting RIP** (client side, SDL front-end): incoming RIP codes →
  graphics. This is `TTermRip` = the direct `TTermAnsi` parallel. Our engine *is*
  this.
- **Serving/emitting RIP** (BBS → RIP-capable caller): Mystic emits RIP command
  sequences, the way it emits ANSI from templates/MCI. This is a separate *emitter*
  (author screens → `!|` codes). Phase 2+ concern; not needed to first render RIP.

## 6. Revised phasing (with real filenames)

- **Phase 1** — Create `mdl/m_term_rip.pas` (`TTermRip`) from `RipParser`, rendering
  to a `TRipSurface` (from `RipFrameBuffer`) presented through `mystic_sdl`. Wire a
  local test path (like `sdl_demo`/the PPM export) to render a `.RIP` in the SDL
  window. Core primitives only. **Visible result fast.**
- **Phase 2** — Fill patterns, stroked fonts, and the mouse/button system (the
  interactive part); begin the RIP **emitter** for serving screens.
- **Phase 3** — Long tail (Beziers, clipboard ops, rare commands).

## 7. Why this is now low-risk

Every unknown from the earlier difficulty note is resolved by the source:
- **What class to parallel** → `TTermAnsi` (`mdl/m_term_ansi.pas`). ✓
- **Exact interface** → `Create(Con)` / `Process(Ch)` / `ProcessBuf`. ✓
- **Where it hooks** → `bbs_io.pas`, `mis.pas`, `nodespy_term.pas`. ✓
- **The graphics gap** → bridged by the existing SDL pixel surface
  (`sdl_dosscreen.pas` + `sdl_bind.pas`). ✓
- **The engine** → already built and proven (`ripterm_client_v0`). ✓

The RIP client and the Mystic RIP class share one engine: **built once, used twice.**

## 8. Licensing note

Mystic a38 is **GPLv3**. The RIP engine will be lifted into it, so licensing the
RIP repo **GPLv3** keeps them compatible — same call we flagged when planning the
RIP repo. All the RIP code is your own clean-room work, so this is free to choose;
GPLv3 is simply the friction-free match.

---

## 9. Implementation status — Phase 1 LANDED (2026-07-08)

Phase 1 is in the tree and verified. The design's mapping became:

| Design item | Landed as |
|---|---|
| `TTermRip` (parallels `TTermAnsi`) | **`mystic_rip/rip_term.pas`** — same public shape (`Create` / `Process` / `ProcessBuf` / `SetReplyClient`), CR-framed line state machine with `\` continuation, level-1 commands `c W = m X L R B C O o F @ T M K e E` |
| `IRipCanvas` (the graphics seam) | **`mystic_rip/rip_canvas.pas`** — `TRipCanvas` **abstract class** (not a COM interface): plain Create/Free lifetime like the rest of MDL, works identically under the core's `-Mdelphi` and the modules' `-Mobjfpc` |
| `TRipSurface` (ARGB software raster) | **`mystic_rip/rip_surface.pas`** — pure-Pascal 640x350 buffer (Bresenham, midpoint ellipse, flood fill, 8x8 font, BMP export) |
| SDL presenter | **`mystic_rip/rip_window.pas`** — ported from the client's `RipWindow` onto the module's runtime-loading `sdl_bind` (never links SDL); `sdl_bind` gained `SDL_MOUSEBUTTONDOWN` + mouse-coordinate decode helpers |
| Local test path | **`mystic_rip/rip_render.pas`** (headless, RIP → BMP — the container-verifiable path) and **`mystic_rip/rip_view.pas`** (SDL window + clickable hot regions); shared sample screen in **`mystic_rip/rip_sample.pas`**; built by `mystic_rip/build-rip.sh` |

**Placement (revised 2026-07-08, sysop call):** Phase 1 lives as a
self-contained EXAMPLE module — **`mystic_rip/`** — like the other add-ons,
NOT in `mdl/`.  It uses FPC RTL units only (no `mdl` units; the reply seam
is an FPC-native callback `TRipReplyProc` for now), and any future threading
uses FPC's own `TThread`/cthreads as `m_socket_server` already does.  The
section-4 table's `mdl/m_term_rip.pas` remains the **promotion target**:
when RIP goes live in the core, `rip_term.pas` moves there and the callback
swaps to `TIOBase` — the public shape (`Create`/`Process`/`ProcessBuf`/
`SetReplyClient`) already matches `TTermAnsi` exactly.

Verified: linux + win32 builds green (core 14/14 both, module both);
`rip_render --sample` output is **pixel-identical** to the ripterm_client_v0
reference `sample.bmp` (ImageChops diff = None) — the "built once, used twice"
claim is now a measurement, not a plan. Hot regions parse and hit-test; the
no-SDL graceful-off path exits cleanly.

One environment note: running the SDL window with a **modern distro** 32-bit
SDL (Ubuntu 24's 2.30) crashes inside `SDL_Init` — reproduced identically with
the pre-existing `sdl_demo`, so it is not a Phase-1 regression but the known
FPC 2.6.2 4-byte-stack-alignment vs modern i386 ABI mismatch. Windows SDL2.dll
and period-appropriate Linux builds are unaffected.

Phase 2/3 tracking moved to docs/TODO.md (fills, stroked fonts, buttons,
emitter; then Beziers/clipboard/long tail).

---

## Current status (session update)

### Completed

- rip_term.pas: 51 of 51 commands. Level 0 + Level 1
  dispatch with proper level tracking. All phases complete.
- rip_canvas.pas: 49 abstract methods. Full RIPscrip v1.54
  drawing surface interface. All implemented in rip_surface.pas.
- ans2rip: PabloDraw-compatible ANSI-to-RIP converter. Moved to
  mystic_rip/.
- bbs_ansi_console.pas: TAbstractConsole + TAnsiEscConsole. MDL-free
  console replacement for TOutput. Pure ANSI escape codes.
- bbs_term_ansi.pas: MDL-free copy of TTermAnsi. Uses
  TAbstractConsole instead of TOutput. Ready for cfg ANSI editor.
- bbs_cfg_viewer.pas: TAnsiFileViewer class. Scrollable file viewer
  with ESC popup menu (Continue/Help/Jump/Quit), ^G Goto, ^W Where.
  Used by View Log Files in the Other menu.
- Theme path validation: LoadThemeData checks all 5 theme paths
  (Text, Menu, Script, Icon, Font). Reports all missing, then halts.
- RecTheme: IconPath + FontPath carved from Reserved (188 -> 26).
  Record size unchanged. On-disk compatible.
- mripedit: standalone RIP scene editor (renamed from mripcfg).
- maketheme: cfgtheme prompts for Icon/Font paths, offers to create dirs.
- ans2rip: PabloDraw-compatible output (CRLF, ASCII 32-126, base-36).
- 48 tests passing (Phase 3 test suite).

### Decisions

- NO MDL in new code. All new units use FPC RTL only.
- Server-side RIP rendering deferred (Option 3). Client only for now.
- mterm deleted. RIPscrip rendering stays in mystic_rip framework.
- Icon/Font paths are theme-only (RecTheme), not system config.
- RecConfig unchanged (mystic.dat compatible).

### Remaining

- All 51 commands implemented. No Phase 3 stubs remain.
- rip_surface.pas: all 49 abstract methods implemented.
- Doc audit: reconcile all docs with current code.
- New user email: debug logging added, needs testing.
