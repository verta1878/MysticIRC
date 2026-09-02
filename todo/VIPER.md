# VIPER — V1 Integration of Proper Engine Rendering
## Branch: viper | Base: main (session 9)

### Goal

Replace the homebrew pixel buffer engine in v1/ripscr.pas with Borland BGI
(ptcgraph) calls. Same API the original RIPscrip binary used. Pixel-accurate
rendering against real RIP art.

### Why

- RIP art was drawn and tested against BGI. Our Bresenham/midpoint/scanline
  reimplementation looks close but isn't pixel-identical — fill patterns,
  arc endpoints, flood fill boundaries all differ slightly.
- ptcgraph IS the BGI — FPC's port of the Borland Graph unit. Same Line,
  Circle, Bar, SetColor, SetFillStyle, FloodFill, PutPixel, GetPixel API.
- Once v1 uses BGI, v2-v4 inherit and extend instead of duplicating 5000+
  lines each.

### What Changes

**ripscr.pas (v1 engine):**
- Remove: DrawPixel, DrawLine, DrawRect, DrawBar, DrawCircle, DrawOval,
  DrawFilledOval, DrawArc, DrawOvalArc, DrawPieSlice, DrawOvalPie,
  DrawPolygon, DrawBezier, FloodFill, DrawFillPixel — all homebrew primitives
- Replace with: Graph.Line, Graph.Circle, Graph.Bar, Graph.Arc,
  Graph.Ellipse, Graph.PieSlice, Graph.FillPoly, Graph.FloodFill,
  Graph.PutPixel, Graph.GetPixel, Graph.SetColor, Graph.SetFillStyle,
  Graph.SetLineStyle, Graph.SetWriteMode, etc.
- Keep: MegaNum parser, command dispatch (ParseLevel0/1/9), TextWindow + ANSI,
  mouse fields, icon load/save, CHR fonts, button rendering, clipboard
- Add: `uses Graph` (or `uses ptcgraph` depending on target)

**rip_surface.pas → rip_framebuf.pas (or rename):**
- For ripview (headless BMP export): init BGI in memory mode, render commands,
  read framebuffer out for BMP. ptcgraph can render to an offscreen buffer.
- For mterm: BGI renders to its window, RIPBlitToTerminal reads pixels via
  GetPixel or direct framebuffer access.
- For mystic_test (USEGRAPH mode): BGI renders to ptcgraph window directly.

**rip_canvas.pas:**
- May become unnecessary — BGI IS the canvas. Or keep as thin abstraction
  if we need both BGI and headless paths.

### Programs Affected

| Program | How it uses RIP | What changes |
|---------|----------------|--------------|
| ripview | Offline .RIP → BMP | Init BGI offscreen, render, read pixels, write BMP |
| mterm | Live RIP over TCP | BGI renders to buffer, blit to terminal cells |
| mystic_test | USEGRAPH mode | Already uses ptcgraph — BGI calls go direct |

### Architecture

**No ptcgraph. No BGI. Use mdl's m_output system.**

The RIP engine keeps its pixel buffer (640×350 byte array, EGA palette indices).
Display goes through m_output — extended with a graphics pixel mode alongside
its existing text cell mode.

m_output_graph.pas already does text-buffer → pixels (GraphPaintBuffer reads
TConsoleScreenRec, paints via Font8x8). VIPER adds the reverse: the RIP
engine's pixel buffer becomes the graphics-mode buffer inside m_output, and
each display driver (m_output_linux, m_output_windows, m_output_dos) renders it.

This means:
- ripview: writes pixels → reads buffer → BMP export (no display needed)
- mterm: writes pixels → m_output displays via its driver
- mystic_test: writes pixels → m_output displays via USEGRAPH driver
- DOS target: m_output_dos writes pixels to VGA framebuffer directly

No X11 dependency. No ptcgraph. Works headless (ripview) and with display
(mterm, mystic).

### Phase Plan

#### VIPER-1: m_output graphics mode
- Extend m_output with a pixel buffer mode (640×350, EGA indexed)
- RIP engine writes to this buffer instead of its own Pixels^ array
- m_output drivers render the pixel buffer to screen
- ripview reads the buffer for BMP export (headless, no display)

#### VIPER-2: ripview on m_output
- ripview uses m_output in headless mode (no display driver, just buffer)
- Render BILL.RIP, GOD-CTH.RIP → BMP
- Compare against homebrew renders and real RIP viewer output

#### VIPER-3: mterm integration
- mterm's RIPBlitToTerminal reads from BGI framebuffer
- Test: mterm connects to mystic, RIP mode renders correctly
- Screen dump (ALT+D) captures BGI output

#### VIPER-4: mystic_test USEGRAPH
- mystic_test already has InitGraph — verify RIP engine uses same BGI context
- Test: mystic in USEGRAPH mode with RIP-enabled menu

#### VIPER-5: v2-v4 inheritance
- v2/rip2api.pas inherits from v1's TRIPEngine, adds v2 extensions
- v3/rip3api.pas inherits from v2, adds v3 extensions (forms, tables, RFF)
- v4/rip4api.pas inherits from v3, adds v4 extensions (JPEG, print, HTML)
- No more duplicated base engine code

#### VIPER-6: Cleanup
- Remove homebrew primitives from codebase (archived in attic/)
- Update docs, IRC whitepaper, API reference
- Pixel-for-pixel comparison test suite against known-good RIP renders

### Done When

1. ripview renders RIP files via BGI — pixel-accurate against real viewers
2. mterm renders RIP graphics live over TCP via BGI
3. mystic_test USEGRAPH mode works with RIP engine
4. v2-v4 inherit from v1 — no duplicated engine code
5. All three programs compile clean on Linux
6. Homebrew code archived in attic/
7. Test suite: BMP comparison of 10+ RIP files against reference renders

### Open Questions

- m_output pixel buffer: new unit (m_output_pixbuf.pas) or extend existing
  m_output_graph.pas?
- Does the RIP engine own the pixel buffer, or does m_output own it and the
  RIP engine gets a pointer?
- CHR font rendering: keep our m_rip_chrfont.pas or use BGI's InstallUserFont
  via Graph unit? (If we're not using Graph, we keep ours.)
- Drawing primitives: keep our homebrew or port to BGI-compatible library?
  The original RIP art was rendered against BGI — pixel differences in arc
  endpoints and fill patterns matter. But if we're not using Graph unit,
  we need our primitives to match BGI exactly.

### Conflict & Compatibility Checklist

These must be resolved during each VIPER phase before merging code:

#### 1. Conflicting implementations
- Same function name, different behavior between homebrew and BGI/m_output paths
- Fill routines: our DrawFillPixel vs Graph.SetFillStyle behavior
- Parser: our MegaNum positional vs standalone DecodeMegaNum
- **Rule:** Test both against known RIP art, keep the one that matches real viewers

#### 2. Record/type mismatches
- Field order, sizes, names must match mystic's data files (users.dat, theme.dat, etc.)
- TRIPMouseField layout must match what mystic reads/writes
- TCharInfo (Attributes, UnicodeChar) order matters for binary compatibility
- **Rule:** mdl types are authoritative — new code adapts to them, not the other way

#### 3. Unit circular dependencies
- Folding code into existing units can create circular uses clauses
- m_output ↔ rip engine ↔ m_output_graph is already a risk
- **Rule:** Check dependency graph before adding any uses clause. Draw it out if needed

#### 4. Global state conflicts
- Module-level vars (SurfRef in rip_surface.pas) that assume single instance
- Two units touching the same global = overwrite bugs
- **Rule:** No module-level state for engine data. All state on TRIPEngine instance. Display state on m_output instance. No globals linking them

#### 5. Naming collisions
- Constants, types, procedures with same name but different meaning
- Example: DrawColor (our engine field) vs SetColor (BGI/Graph procedure)
- Example: TRIPRgb (our type) vs Graph's palette types
- **Rule:** Prefix engine types with RIP_, display types with OUT_. No bare names that collide with Graph unit identifiers (even though we're not using Graph, future compatibility)

#### 6. Compiler directive mismatches
- {$MODE OBJFPC} vs {$MODE DELPHI} — all mdl uses Delphi mode
- {$H+} AnsiStrings vs {$H-} ShortStrings — engine uses {$H-}
- {$IFDEF USEGRAPH} guards need updating when m_output_graph goes away
- {$IFDEF UNIX}/{$IFDEF WINDOWS}/{$IFDEF GO32V2} for platform code
- **Rule:** All new code: {$MODE DELPHI}, {$H-}. Platform code uses proper ifdefs for all three targets (Linux, Windows, DOS/GO32V2)

#### 7. Platform assumptions
- Code that assumes Linux (fpSocket, BaseUnix) without ifdefs
- Code that assumes Windows (Windows unit) without ifdefs
- Code that assumes DOS (Graph unit, VGA hardware, Mem[], Port[]) without ifdefs
- fpc264irc cross-compiler targets GO32V2 — all code must compile there
- **Rule:** Every platform-specific call wrapped in {$IFDEF}. Test compile on Linux native. Cross-compile check for GO32V2 when possible
