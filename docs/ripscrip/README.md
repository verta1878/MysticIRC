# RIPscrip Documentation

## Sources

- **riplib** — https://github.com/BradHawthorne/riplib (MIT)
  Pure C99 platform-independent RIPscrip drawing library.

- **remote-imaging-protocol** — https://github.com/bbs-land/remote-imaging-protocol
  Documentation and extended information around RIPScrip/RIPTerm/RIPtel specifications.

## Version Directory

| Dir | What |
|-----|------|
| v154-spec/ | RIPscrip v1.54 — the standard. TeleGrafix 1993-1994. What every BBS used. |
| v154-techspecs/ | v1.54 implementation details (fill rasterization, icon format, BGI fonts, bitmap fonts, connection model). |
| v200-spec/ | RIPscrip v2.0 alpha 4 — TeleGrafix 1995-1996. Never widely shipped. Adds 256 colors, JPEG, drawing ports, data tables, audio. |
| v200-techspecs/ | v2.0 tech (JPEG, FastFont, MicroANSI, audio, UI resources). |
| v300-spec/ | RIPscrip v3.0 — TeleGrafix 1996-1997. RIPtel client. Column text, conditional templates, extended icons. |
| v300-techspecs/ | v3.0 tech deltas. |
| v300-research/ | Reverse engineering notes from RIPtel binary analysis. |
| v30-riplib/ | Unofficial third-party extensions (2026). Not TeleGrafix. RIPlib's initial revision. Differences from v3.0 only. |
| v31-riplib/ | Unofficial third-party extensions (2026). Not TeleGrafix. RIPlib's A2G.1-7 revision, wire ID RIPSCRIP031001 — new write modes, a third text direction, rendered font attributes, port alpha/compositing, and rendering work. Additions and differences only, with each claim checked against the 3.0 record. |
| v32-riplib/ | Unofficial third-party extensions (2026). RIPlib's follow-on A2G.8-13 revision, wire ID RIPSCRIP032001 — a drawing-state stack, layout/time/color-name variables, a DEBUG directive, and radial gradient. Additions and differences only. |
| baseline/ | Non-RIP baseline. Specification references beyond RIPscrip itself: the ANSI/VT-x text emulation RIPterm and RIPtel actually documented and shipped (CP437, VT-102, Doorway, auto-sense), plus modern terminals (SyncTERM, icy_term) as reference points with historically unevidenced features explicitly marked. |
| riplib-spec/ | riplib's own spec docs (wire format, commands, fonts, icons, variables, DLL deviations). |
| riplib-src/ | 13K lines C99 reference source (read-only reference). |
| riplib-design/ | Architecture decision records (ADRs). |
| historical/ | Original TeleGrafix docs: RIPSCRIP_v154.DOC, RIPSCRIP_v2A4.PRN, v3 whitepaper. |

## Future / Placeholder

| Dir | What |
|-----|------|
| next/ | Future enhancements. A placeholder for forward-looking, unofficial extensions (modern image/audio formats, font handling, UTF-8) that implementations may adopt and that could become a 3.5x/4.x enhancement of the specification. |

## Assets

| Dir | What |
|-----|------|
| examples/mterm/rip-fonts/ | 10 CHR stroked vector fonts + RIPTERM.FNT bitmap font |
| examples/mterm/rip-icons/ | 184 ICN icon files (from RIPterm 1.54 distribution) |

## Our RIP Engine Status

mtrip.pas + mtripgfx.pas: 40 commands implemented (Level 0 + Level 1).
Missing ~9 v1.54 commands. No BGI stroked font parser. No ICN icon loader.
See docs/MTERM-PHASES.md for upgrade plan.
