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

## OPEN

All open phases tracked in `RIP-GRAPHICS-PHASES.md`.

## ARCHIVED

Pre-VIPER code in attic/:
- attic/rip_v1_homebrew/ — ripscr.pas, rip_surface.pas, rip_canvas.pas, m_output_graph.pas, m_output_rip.pas
- attic/rip_v2v3v4_monolith/ — rip2api.pas (5381), rip3api.pas (8358), rip4api.pas (8633)

## RIP Graphics Phases

See `mdl/m_rip/RIP-GRAPHICS-PHASES.md` for all RIP display phases
covering mystic_test, mterm, and ripview in one document.
