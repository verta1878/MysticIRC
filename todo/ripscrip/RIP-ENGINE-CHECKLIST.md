# RIPscrip Engine Status — All Versions

## Date: 2026-08-19

## API Versions

| Version | File | Lines | Status |
|---------|------|-------|--------|
| v1 1.0.1-irc | ripscr.pas | 4186 | v1.54 server-side, WriteIcon implemented |
| v2 2.0.1-irc | rip2api.pas | 5394 | v2.0 256-color, WriteIcon implemented |
| v3 3.0.1-irc | rip3api.pas | 8371 | v3.0 + tables/forms, WriteIcon implemented |
| v4 3.1.0-irc | rip4api.pas | 8646 | v3.0 + v4 extensions, WriteIcon implemented |

## mterm Client Engine

| File | Lines | Status |
|------|-------|--------|
| mtrip.pas | 946 | v1.54 client-side, all 53 commands, zero stubs |
| mtripgfx.pas | 859 | 640x350 EGA canvas, live palette |
| mtsound.pas | 108 | SDL_mixer audio (WAV/MID/MOD/MP3/OGG) |

## Changes Applied (2026-08-19)

### All Versions (v1-v4)
- WriteIcon (1W): Implemented full ICN writer (EGA bitplane encoding)
- Added: ClipValid, SanitizePath, WriteClipboardICN helper methods
- Version bumped to x.x.x-irc

### mterm Client Engine
- 5 bugs fixed (=, l, 1G, 1D mappings + CmdLineStyle param count)
- 10 commands added (E, V, i, g, m, >, W, =, a, Q)
- EGA64→RGB palette conversion with live modifiable FPalette
- Text variable system (FVarNames/FVarValues)
- ProcessFile for recursive RIP scene load
- File Query with FILEERR variable
- SDL_mixer audio integration
- All stubs completed

### ANSI Baseline (mterm)
- 11 CSI sequences added
- 5 ESC sequences added
- Scroll region support
- Line wrap mode
- RIP auto-sense
- Device status report responses

## Remaining No-ops (Correct)

| What | Why |
|------|-----|
| Sound (server-side) | Server has no audio output — correct |
| # (no more) | Marks end of RIP — correct |
| E (end text) | Handled by text region system — correct |

## Accuracy Issues (Deferred)

| Issue | Phase |
|-------|-------|
| BGI stroked font parser (CHR files) | MT-16 |
| ICN icon file loader (EGA bitplane) | MT-17 |
| Flood fill stack limit vs RIPterm | MT-18 |
| Line thickness rendering | MT-18 |
| Write mode (XOR/OR/AND/NOT) application | MT-18 |

## Test Results

| Suite | Files | Result |
|-------|-------|--------|
| 16colo.rs corpus | 100 | 100/100 × 3 |
| ripviewer test/ | 15 | 15/15 × 3 |
| ripviewer bugs/ | 10 | 10/10 × 3 |
| **Total** | **125** | **125/125 × 3** |
