# RIP Engine Integration Plan
## Merging reconstructed source + session 9 bridge code into mdl/m_rip

### Current State

**Our units (mdl/m_rip/):**
- `rip_canvas.pas` (157 lines) — abstract base class, TRipRGB, TRipColor, TRipMouseRegion
- `rip_surface.pas` (776 lines) — pixel buffer implementation, Bresenham lines, midpoint ellipses, BMP export
- `v1/ripscr.pas` (4202 lines) — the engine: TRIPEngine class, MegaNum, all 53 RIP commands, fill patterns, text window, mouse fields, icon load/save, CHR fonts, Bezier curves

**Session 9 bridge files (standalone units — to be folded in):**
- `riptwin.pas` (286 lines) — text window state machine with ANSI escape processing
- `ripdisp.pas` (145 lines) — command dispatch table + draw stats
- `ripicn.pas` (87 lines) — ICN icon utilities (flip, checksum, validate)
- `ripmouse.pas` (147 lines) — mouse region manager, multi-table hotspots
- `rip1exec.pas` (878 lines) — v1.54 command executor, 42-command dispatcher
- `rip1parse.pas` (163 lines) — v1.54 parser, MegaNum decoder, command enum

**Reconstructed source (reference — not direct copy):**
- `RIPCMD.PAS` (1096 lines) — TTextWinState, ANSI CSI processing, ExecuteRipCommand, drawing widgets
- `RIPPARSE.PAS` (887 lines) — stream parser with binary-layout TRipParser record
- `RIPDISP.PAS` (289 lines) — command dispatch table matching binary vtable
- `RIPMOUSE.PAS` (334 lines) — 10 tables × 20 regions
- `RIPICON.PAS` (255 lines) — ICN/HIC format load/save/display
- `RIPPARAM.PAS` (181 lines) — IdentifyCommand (53 commands from binary data segment), ParseParams
- `RIPFONT.PAS` (111 lines) — font index, text region scroll, Bezier
- `MEGANUM.PAS` (53 lines) — base-36 decoder
- `RIPRES.PAS` (124 lines) / `RIPRSRC.PAS` (318 lines) — resource file handler
- `RIPRESUT.PAS` (34 lines) — string parsing utils

---

### Conflict Analysis

#### 1. MegaNum — SAME BEHAVIOR, different signature
- Theirs: `DecodeMegaNum(var S: String): LongInt` — standalone function, full string
- Ours: `TRIPEngine.MegaNum(var S: String; var Pos: Integer; Digits: Integer): LongInt` — method, positional
- **Resolution:** Keep ours. It's more flexible (positional parsing inline). Their standalone version is just a convenience wrapper we don't need since our engine parses in-place.

#### 2. TextWindow — CONFLICTING implementations
- Theirs (RIPCMD): `TTextWinState` record, standalone procedures, `uses Graph` for drawing
- Session 9 (riptwin.pas): Backend-agnostic via callback functions (TPixelGetFunc etc.)
- Ours (ripscr.pas): Fields directly on TRIPEngine (TextWinX0/Y0/X1/Y1/Size), methods like SetTextWindow
- **Resolution:** Fold riptwin.pas ANSI processing logic INTO ripscr.pas's existing TextWindow methods. The ANSI CSI handler from RIPCMD is valuable new code — our engine doesn't have full ANSI escape processing in the text window yet. Add it to TRIPEngine as a private method `ProcessTextAnsi`.

#### 3. Mouse Regions — CONFLICTING record layout
- Theirs: `TMouseRegion` with X1,Y1,X2,Y2,Command:String[64], 10 tables × 20 regions
- Ours: `TRIPMouseField` with X0,Y0,X1,Y1,HostCmd,Text:String, flat array of 20
- **Resolution:** Keep our record layout (matches mystic data expectations). Add multi-table support from theirs if needed later. The flat array works for v1.54.

#### 4. Icon Handling — COMPLEMENTARY
- Theirs: Full ICN/HIC load/save/display with separate TIconData buffer
- Ours: LoadIcon/SaveIcon methods on TRIPEngine, reads directly into Pixels buffer
- Session 9 (ripicn.pas): Utility functions (flip, checksum, validate)
- **Resolution:** Fold ripicn.pas utility functions into ripscr.pas as private methods of TRIPEngine. Reference RIPICON.PAS for any ICN format details we're missing (HIC format especially).

#### 5. Fill Patterns — DIFFERENT BEHAVIOR (key conflict!)
- Session 9 ripscr.pas: `FillStyle = 0 → pixel = 0` (black), removed Y-swap in DrawLine
- Our ripscr.pas: `FillStyle = 0 → pixel = BGColor`, has Y-swap in DrawLine
- Theirs (RIPCMD): Uses `Graph.SetFillStyle` — delegates to BGI, no custom fill
- **Resolution:** Session 9 changes are a regression. FillStyle=0 means "empty fill" which should use BGColor, not hardcoded 0. The Y-swap in DrawLine fixes Bezier gap leaks per RIPtermJS reference. **Keep our current ripscr.pas fill behavior.** Apply session 9 changes selectively.

#### 6. Command Dispatch — COMPLEMENTARY
- Theirs (RIPDISP/RIPPARAM): Full dispatch table with 53 command records from binary
- Session 9 (ripdisp.pas): Dispatch table + draw stats
- Session 9 (rip1parse.pas): Command enum + parser
- Session 9 (rip1exec.pas): 42-command executor
- Ours (ripscr.pas): ParseLevel0/ParseLevel1/ParseLevel9 case statements
- **Resolution:** Our case-statement dispatch is simpler and works. The dispatch table from RIPPARAM's `IdentifyCommand` is valuable as a REFERENCE for verifying our command IDs against the binary. Fold the draw stats from ripdisp.pas into ripscr.pas. Don't replace our dispatch — just verify it matches.

#### 7. Compiler/Platform
- Theirs: `{$O+,F+}` (TP7 overlays), `uses Graph, Dos, Crt`
- Session 9: `{$MODE DELPHI}`, `{$H-}` (ShortStrings)
- Ours: No explicit mode (inherits from build command `-Mdelphi`)
- **Resolution:** All new code uses `{$MODE DELPHI}` with `{$H-}` for ShortStrings. No `uses Graph` — we use rip_surface pixel buffer. No `uses Dos` — use SysUtils. No `uses Crt` — we're headless.

---

### Integration Steps

#### Step 1: Apply session 9 ripscr.pas changes SELECTIVELY
- YES: `Uses SysUtils, Math` addition
- YES: FillStyle boundary fix (`<= 11` not `<= 12`)
- NO: `FillStyle = 0 → pixel = 0` (keep BGColor)
- NO: Remove Y-swap in DrawLine (keep the swap, it fixes gaps)
- YES: Remove stray debug WriteLn

#### Step 2: Fold riptwin.pas into ripscr.pas
- Add `ProcessTextAnsi(var S: String)` method to TRIPEngine
- Add ANSI CSI parameter parsing (from RIPCMD's ProcessAnsiSequence)
- Add text window scroll (from RIPCMD's TextWinScroll adapted to pixel buffer)
- Remove standalone riptwin.pas unit
- Remove `RIPTWin` from rip_surface.pas uses clause

#### Step 3: Fold ripdisp.pas stats into ripscr.pas
- Add draw command counters to TRIPEngine
- Add DumpStats method
- Remove standalone ripdisp.pas unit

#### Step 4: Fold ripicn.pas into ripscr.pas
- Add IconFlipH, IconFlipV, IconChecksum as private methods
- Remove standalone ripicn.pas unit

#### Step 5: Fold ripmouse.pas into ripscr.pas
- Our mouse field handling already covers this
- Check if multi-table support is needed (v1.54 spec says no)
- Remove standalone ripmouse.pas unit

#### Step 6: Merge rip1parse.pas command enum into ripscr.pas
- Cross-reference command IDs against RIPPARAM.PAS IdentifyCommand
- Verify our ParseLevel0/1/9 matches the binary's 53 commands
- Add any missing command IDs as constants

#### Step 7: Reference rip1exec.pas against ripscr.pas
- Compare each of the 42 command handlers
- Fix any parameter count mismatches
- Don't replace our engine — just verify and fix

#### Step 8: Apply doc updates from session 9
- Apply README.md, m_rip/README.md, v1-v4 PHASES.md and README.md from session 9 changed files
- **Adjust** all references to standalone units (riptwin.pas, rip1exec.pas, rip1parse.pas, ripdisp.pas, ripicn.pas, ripmouse.pas) to reflect that code is now folded into ripscr.pas and rip_surface.pas
- Update the "Two Rendering Stacks" section in m_rip/README.md — we have ONE stack, not two
- Update file table to show actual final unit layout
- Update session 9 entries in PHASES.md to say "folded into ripscr.pas" not "created standalone unit"

#### Step 9: Write IRC-WHITEPAPER.md (v1/)
Document what the IRC fork changed from the original and why:
- **Architecture:** Single-unit engine (ripscr.pas) vs multi-unit split. Why we fold everything into TRIPEngine instead of standalone units.
- **Rendering:** Pixel buffer (rip_surface.pas) vs BGI Graph unit. Why we don't use `uses Graph` — headless rendering, cross-platform, BMP export.
- **Fill patterns:** Our DrawFillPixel uses BGColor for empty fill (FillStyle=0), not hardcoded black. Matches RIPtermJS reference. Y-swap in DrawLine prevents Bezier gap leaks.
- **MegaNum:** Positional in-place parsing vs standalone string decoder. Same base-36 math, different API.
- **TextWindow + ANSI:** Folded into TRIPEngine from reconstructed binary's RIPCMD. ANSI CSI processing (SGR colors with SGR→EGA mapping, cursor movement, erase display/line). Scroll via pixel buffer blit not Graph.GetImage/PutImage.
- **Mouse fields:** Flat array matching mystic data layout vs multi-table design from binary. v1.54 spec uses single table.
- **Icon format:** ICN load/save works directly on pixel buffer. HIC (high-color) format documented from binary but not yet implemented.
- **Command IDs:** All 53 verified against RIPPARAM.PAS IdentifyCommand which was extracted from binary data segment offsets 0x11560-0x1160f.
- **API reference:** Public types (TRIPEngine, TRipSurface, TRipCanvas, TRipRGB, TRipColor, TRIPMouseField), constructor/destructor, ProcessByte/ProcessLine entry points, canvas abstract methods (SetDrawColor, LineTo, Bar, FloodFill, etc.), text window methods (SetTextWindow, ProcessTextAnsi), mouse field methods (Add/Kill/Find/GetMouseField), icon load/save, clipboard, BMP export — the full contract for ripview/mterm/mystic callers.
- **Compiler:** FPC 2.6.4 IRC fork, `{$MODE DELPHI}`, `{$H-}` ShortStrings. No Turbo Pascal overlays, no CRT unit, no DOS unit.
- **Platform targets:** Linux (native), DOS/GO32V2 (via fpc264irc cross-compiler + DOSBox). ptcgraph for DOS VGA, not Linux X11.
- **Font:** IBM VGA 8x8 from ROM dump, 256 chars, verified across all 18 copies in repo.

---

### Final Unit Layout (after integration)

```
mdl/m_rip/
  rip_canvas.pas         ← abstract base (unchanged)
  rip_surface.pas        ← pixel buffer impl (remove RIPTWin dep)
  rip_font8x8.inc        ← font data (unchanged)
  v1/
    ripscr.pas           ← THE engine: all commands, text window + ANSI,
                            mouse fields, icons, fill patterns, stats
    README.md            ← full command reference
    PHASES.md            ← phase tracking
    IRC-WHITEPAPER.md    ← design decisions doc
  v2/ v3/ v4/            ← future versions
```

No standalone riptwin/ripdisp/ripicn/ripmouse units. Everything in ripscr.pas or rip_surface.pas.
