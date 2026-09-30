# RIP v1.54 Engine — Phase Tracking

## COMPLETED

### Sessions 1-7
- MT-1 thru MT-6: mterm terminal
- MT-8a: ShowBuffer paint hook
- MT-14/MT-15: RIP v1.54 engine (53 commands)
- MT-16: CHR font parser
- MRP-1 thru MRP-7: Widgets, CHR font, load/save, demos
- MRP-12: Load/save .mnu text format
- FONT-1: IBM VGA 8x8 font (all 18 copies)

### Session 8
- Real login screen capture via Python pty
- Data file generators: mkconfig, mktheme, mksec, mkuser
- ANSI screen renderer with IBM VGA 8x8 font

### Session 9
- MIS-1: MIS compiles (ATTR constants, ShowESCMenu, forward decl)
- MTERM-CONN: TCP wiring — mterm connects to mystic via socat
- SGR→EGA color mapping in mterm terminal
- DumpScreen (ALT+D) full 25-row buffer dump
- FlushRIPBuf fix (RIPActive=True during replay)
- Integration plan: 6 standalone units folded into ripscr.pas
- IRC whitepaper with API reference
- VIPER-1 thru VIPER-6: shared rendering stack in mdl/m_rip/
  - ripengine, ripdraw, riptext, ripbmp moved to mdl/m_rip/
  - rip1parse, rip1exec moved to mdl/m_rip/v1/
  - mterm switched from OOP (ripscr.pas) to procedural stack
  - v2-v4 decomposed from 22,372-line monoliths to 626-line extensions
  - Old code archived in attic/rip_v1_homebrew/ and attic/rip_v2v3v4_monolith/
  - m_output_graph.pas archived (FPC Graph unit/X11 dep removed)
  - mystic_test/mdl/ duplicate removed (69 files)
  - cleanup.bat updated for post-VIPER layout
- ACCT-1: SysOp account — record layout correct (1536 bytes), checkuser reads it, but FindUser fails at runtime (OPEN — debug next session)
- ACCT-3: "Selected theme not available" — setup issue, theme Flags fixed (AllowASCII|AllowANSI), CLOSED
- Theme.dat regenerated with correct RecTheme layout (Flags field at offset 0)
- FONT-2/3: IBM VGA 8x14 and 8x16 fonts from ROM dumps (CLOSED)

### Session 10
- RIPterm 1.54 source: 100% FINAL (455 files, 844KB, GPLv3)
- RIPterm verification: all 12 files cross-referenced against ripview
- Critical correction: ~45 "missing" functions exist in ripscr.pas OOP class
- Bar3D (L1 'O') recovered — was wrongly listed as dead code
- 60+ functions ported OOP→procedural across ripengine, ripdraw, rip1parse, rip1exec
- 5 new units: ripstate (7), riptextvar (9), ripmouse (14), ripicon (8), ripwidgets (19)
- All 14 L1 commands dispatched in rip1parse.pas
- Zero direct Canvas writes in rip1exec.pas (was 25)
- 6 protocol units ported to mystic_test/mdl/ (xmodem/ymodem/zmodem/kermit/base/queue)
- SDL files moved to mdl/sdl/ canonical path
- mconfig.exe v0.1: FPC Graph display, keyboard input, reads/writes mystic.dat
- VIPEngine documented in VIPER.md — TRIPEngine→VIPEngine wrapper pending
- 16+ docs updated, all "C source" refs changed to "RIPterm"

## OPEN

All open phases tracked in `RIP-GRAPHICS-PHASES.md`.

## ARCHIVED

Pre-VIPER code in attic/:
- attic/rip_v1_homebrew/ — ripscr.pas, rip_surface.pas, rip_canvas.pas, m_output_graph.pas, m_output_rip.pas
- attic/rip_v2v3v4_monolith/ — rip2api.pas (5381), rip3api.pas (8358), rip4api.pas (8633)

## RIP Graphics Phases

See `RIP-GRAPHICS-PHASES.md` (repo root) for all RIP display phases
covering mystic_test, mterm, and ripview in one document.

### Session 10c (2026-09-30) — kiddo
- ripengine.pas: 720 lines, 45+ functions (viewport stack, ClipLine, transforms, ResetRIPState)
- riptext.pas: 470 lines, attributed text (DrawBitmapChar16, RenderStringAttr, GfxText API), LoadCHRFont exported
- ripdraw.pas: 614 lines, DrawArrow (24/24 BGI_WRAP), DrawPolygon, DrawBar3D, span-based FloodFill
- ripicon.pas: 64-slot cache, both engines wired
- ripscr.pas: LoadCHR delegates to RIPText (130 lines removed), 4,341 lines
- rip4ext.pas: 332 lines, zero stubs (JPEG/GIF/PNG/HTML/Print/MPEG all wired)
- v1.54 print: mterm PrintScrollback/LPTPutChar/PrintDialog
- CHR font: auto-load wired, shared between OOP and procedural

### Session 10d (2026-09-30) — kiddo
- rcQuery (!|$): responds RIPSCRIP015400 via QueryResponseBuf pointer
- rcDefine (!|1D), rcCopyRegion (!|1G), rcReadScene (!|1R), rcFileQuery (!|1F), rcDelay (!|1E): all dispatched + handled
- All L0 + L1 commands now have handlers — no unhandled commands remain
- v1 engine complete (pending: VIPEngine wrapper, prnapi in rip3ext)
- rip3ext.pas: prnapi wired (282→312 lines), PrintPage Canvas→RGB24→driver, print chain complete v1→v3→v4
- vipengine.pas: 323 lines, 30 exports — procedural wrapper for TRIPEngine, flat API for mterm/mconfig/ripview
- All v1 engine units complete — no remaining stubs
- mterm phonebook edit + capture/logging wired. 2,009 total lines
