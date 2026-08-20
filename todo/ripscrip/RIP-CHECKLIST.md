# RIPscrip v1.54 Command Checklist — Our Engine vs Spec

## LEVEL 0 — WINDOWS & DISPLAY

| Cmd | Name | Status | Our Code |
|-----|------|--------|----------|
| w | RIP_TEXT_WINDOW | ✅ | CmdTextWindow |
| v | RIP_VIEWPORT | ✅ | CmdViewport |
| * | RIP_RESET_WINDOWS | ✅ | CmdResetWindows |
| e | RIP_ERASE_WINDOW | ✅ | CmdEraseWindow |
| E | RIP_ERASE_VIEW | ❌ MISSING | — |
| G | RIP_GOTOXY | ✅ | CmdGotoXY |
| g | RIP_GOTOXY_TEXT | ❌ MISSING | — |
| H | RIP_HOME | ✅ | CmdHome |
| K | RIP_ERASE_EOL | ⚠️ BUG | CmdEraseEOL (spec uses >) |
| > | RIP_ERASE_EOL | ❌ MISSING | — |

## LEVEL 0 — COLORS & ATTRIBUTES

| Cmd | Name | Status | Our Code |
|-----|------|--------|----------|
| c | RIP_COLOR | ✅ | CmdColor |
| Q | RIP_SET_PALETTE | ✅ | inline |
| a | RIP_ONE_PALETTE | ✅ | inline |
| = | RIP_LINE_STYLE | ⚠️ BUG | CmdWriteMode (= is line style, not write mode) |
| W | RIP_WRITE_MODE | ❌ MISSING | proc exists, not wired |
| S | RIP_FILL_STYLE | ✅ | CmdFillStyle |
| Y | RIP_FONT_STYLE | ✅ | CmdFontStyle |

## LEVEL 0 — LINES

| Cmd | Name | Status | Our Code |
|-----|------|--------|----------|
| X | RIP_PIXEL | ✅ | CmdPixel |
| L | RIP_LINE | ✅ | CmdLine |
| l | RIP_POLYLINE | ⚠️ BUG | CmdLineStyle (spec: l=polyline) |

## LEVEL 0 — CURVES

| Cmd | Name | Status | Our Code |
|-----|------|--------|----------|
| C | RIP_CIRCLE | ✅ | CmdCircle |
| O | RIP_OVAL | ✅ | CmdOval |
| A | RIP_ARC | ✅ | CmdArc |
| V | RIP_OVAL_ARC | ❌ MISSING | — |
| Z | RIP_BEZIER | ✅ | CmdBezier |

## LEVEL 0 — SHAPES & FILLS

| Cmd | Name | Status | Our Code |
|-----|------|--------|----------|
| R | RIP_RECTANGLE | ✅ | CmdRectangle |
| B | RIP_BAR | ✅ | CmdBar |
| o | RIP_FILLED_OVAL | ✅ | CmdFilledOval |
| I | RIP_PIE_SLICE | ✅ | CmdPieSlice |
| i | RIP_OVAL_PIE_SLICE | ❌ MISSING | — |
| P | RIP_POLYGON | ✅ | CmdPolyLine |
| p | RIP_FILL_POLYGON | ✅ | CmdFilledPolygon |
| F | RIP_FILL | ✅ | CmdFill |

## LEVEL 0 — TEXT & POSITION

| Cmd | Name | Status | Our Code |
|-----|------|--------|----------|
| T | RIP_TEXT | ✅ | CmdOutText |
| @ | RIP_TEXT_XY | ✅ | CmdOutTextXY |
| M | RIP_MOVE | ✅ | CmdMove |
| m | RIP_MOVE (lowercase) | ❌ CHECK | may be correct version |

## LEVEL 1 — INTERACTIVE

| Cmd | Name | Status | Our Code |
|-----|------|--------|----------|
| 1B | RIP_BUTTON_STYLE | ✅ | inline |
| 1U | RIP_BUTTON | ✅ | CmdButton |
| 1K | RIP_KILL_MOUSE | ✅ | CmdKillMouseFields |
| 1M | RIP_MOUSE | ✅ | CmdMouseField |
| 1T | RIP_BEGIN_TEXT | ✅ | CmdBeginText |
| 1t | RIP_REGION_TEXT | ❌ MISSING | — |
| 1E | RIP_END_TEXT | ❌ MISSING | — |
| 1I | RIP_LOAD_ICON | ✅ | CmdLoadIcon |
| 1C | RIP_GET_IMAGE | ✅ | CmdGetImage |
| 1P | RIP_PUT_IMAGE | ✅ | CmdPutImage |
| 1S | RIP_SOUND | ✅ stub | — |
| 1D | RIP_DELAY | ❌ MISSING | — |
| 1G | RIP_SCROLL | ⚠️ BUG | mapped to CmdGetImage |

## LEVEL 9 — META

| Cmd | Name | Status | Our Code |
|-----|------|--------|----------|
| ! | RIP_COMMENT | ✅ | skip |
| # | RIP_NO_MORE | ✅ | exit |
| $ | RIP_QUERY | ❌ MISSING | — |

## SUMMARY

- Implemented: 36 commands
- Missing: 13 commands
- Bugs/Wrong mapping: 3 commands

## ACCURACY ISSUES

| Issue | Status |
|-------|--------|
| BGI stroked font parser (CHR files) | ❌ Not implemented |
| ICN icon file loader (EGA bitplane) | ❌ Not implemented |
| Flood fill stack limit vs RIPterm | ⚠️ Needs verification |
| Polygon degenerate handling | ⚠️ Needs testing |
| Clipboard 64KB limit | ❌ Not enforced |
| Character pacing / ANSI animation | ❌ Not implemented |

## BASELINE TERMINAL FEATURES

| Feature | Status |
|---------|--------|
| CP437 charset | ✅ |
| VT-102 emulation | ⚠️ Partial (ANSI only) |
| Doorway mode | ❌ Not implemented |
| Auto-sense RIP detection | ❌ Not implemented |
| ANSI music | ❌ Not implemented |

## ANSI/VT BASELINE (RIPterm Appendix B)

What RIPterm 1.54 actually supported for text/ANSI. Our mterm ANSI engine
must match this to be a proper RIP terminal.

### Cursor Movement

| Sequence | Function | Status |
|----------|----------|--------|
| ESC[PnA | Cursor Up | ✅ |
| ESC[PnB | Cursor Down | ✅ |
| ESC[PnC | Cursor Right | ✅ |
| ESC[PnD | Cursor Left | ✅ |
| ESC[Py;PxH | Cursor Position | ✅ |
| ESC[Py;Pxf | Cursor Position (alt) | ✅ |

### Erase

| Sequence | Function | Status |
|----------|----------|--------|
| ESC[J / ESC[0J | Clear cursor to end | ✅ |
| ESC[1J | Clear cursor to start | ✅ |
| ESC[2J | Clear screen + home | ✅ |
| ESC[K / ESC[0K | Clear to end of line | ✅ |
| ESC[1K | Clear start to cursor | ✅ |
| ESC[2K | Clear entire line | ✅ |

### Attributes

| Sequence | Function | Status |
|----------|----------|--------|
| ESC[...m | SGR (color/bold/blink) | ✅ |

### Save/Restore

| Sequence | Function | Status |
|----------|----------|--------|
| ESC[s | Save cursor position | ✅ |
| ESC[u | Restore cursor position | ✅ |

### MISSING — Must Add

| Sequence | Function | Priority |
|----------|----------|----------|
| ESC[Pn@ | Insert spaces | MEDIUM |
| ESC[PnP | Delete characters | MEDIUM |
| ESC[PnL | Insert lines | MEDIUM |
| ESC[PnM | Delete lines | MEDIUM |
| ESC[PnZ | Backtab | LOW |
| ESC[g / ESC[0g | Clear tab stop | LOW |
| ESC[3g | Clear all tab stops | LOW |
| ESC[5n | Device status report | HIGH (BBSes query this) |
| ESC[6n | Cursor position report | HIGH (BBSes query this) |
| ESC[c | Device attribute report | HIGH |
| ESC[Pl;Pnr | Set scrolling region | HIGH |
| ESC[S | Scroll up | MEDIUM |
| ESC[?7h | Line wrap on | MEDIUM |
| ESC[?7l | Line wrap off | MEDIUM |
| ESC[! | Auto-sense RIP terminal | HIGH (RIP detection) |
| ESC[1! | Disable RIPscrip | HIGH |
| ESC[2! | Enable RIPscrip | HIGH |
| ESC c | Reset terminal | MEDIUM |
| ESC D | Index (down+scroll) | MEDIUM |
| ESC E | Next line (col 1+scroll) | MEDIUM |
| ESC 7 / ESC 8 | DEC save/restore cursor | LOW |
| ESC[=255h | Doorway mode on | LOW |
| ESC[=255l | Doorway mode off | LOW |

### Summary — ANSI Baseline

- Implemented: 11 sequences
- Missing: 22 sequences (6 HIGH priority)

## UNOFFICIAL EXTENSIONS (riplib v3.0-v3.2)

In our phases as MT-22. These are 2026 additions by BradHawthorne,
not TeleGrafix standard, but we support them.

- v3.0-riplib: Write modes, command inventory comparison
- v3.1-riplib: New write modes, text direction, font attributes, port compositing
- v3.2-riplib: State stack, radial gradient, debug directive, layout variables

## FUTURE (next/)

Developer placeholder for possible 3.5x/4.x enhancements.
In our phases as MT-20 (modern formats) and MT-23 (web viewer):
- PNG/APNG/WebP/GIF icons replacing ICN/BMP
- MP3/OGG/Opus audio replacing WAV
- TTF/OTF font support (terminal via SDL_ttf)
- WOFF/WOFF2 font support (web viewer)
- UTF-8 / Unicode text rendering
- CP437 ↔ UTF-8 switching command
