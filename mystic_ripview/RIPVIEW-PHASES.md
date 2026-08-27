# RIPView — Phase Tracking

## What Is RIPView?

RIPView is the RIPscrip file viewer / engine test platform.
Lives in examples/ripviewer/. Demonstrates the RIP engines.

Two roles:
1. **Viewer** — render .RIP files to BMP or SDL window
2. **Test platform** — validate engine command coverage (like HTML5Test for RIPscrip)

## Completed

| Phase | What | Status |
|-------|------|--------|
| Phase 1 | v1.54 parser + 42 commands | DONE |
| Phase 2 | BMP output, EGA palette | DONE |
| Phase 3 | Bug fixes (Bresenham, flood fill, canvas height) | DONE |
| FV Mode | Free Vision TUI file picker | DONE |
| Baud emu | Modem speed simulation | DONE |

## Current Stats

- 42/42 v1.54 commands (ripview's own parser in rip1parse/rip1exec)
- Pixel-perfect rendering vs RIPtermJS reference
- 612 lines main, 533 lines ripdraw, 183 lines engine
- CLI + Free Vision TUI modes

## Open Phases

| Phase | What |
|-------|------|
| RV-1 | Engine test scorecard (command coverage grid) |
| RV-2 | HTML 1.0 website viewer (via htmlrip.pas pipeline) |
| RV-3 | Multi-engine support (load v1/v2/v3/v4 and compare) |
| RV-4 | Visual diff tool (render two engines, show pixel differences) |
| RV-5 | Sync with mterm engine updates (MT-14/MT-15 commands) |

### RV-1 — Engine Test Scorecard

Display a grid of all RIP commands, mark each green/yellow/red
per engine version. Output as ANSI (BBS) + HTML (webroot).

MPS version: mystic/scripts/riptest.mps (already created)
Pascal version: ripview --scorecard (generate standalone)

### RV-2 — HTML 1.0 Website Viewer

RIPweb-style HTML→RIP conversion. Load an HTML 1.0 page,
convert to RIP commands, render on the 640×350 canvas.

Pipeline (already exists in mystic_rip/v4/img/):
```
HTML source → htmlpars.pas (tokenizer, ~40 tags)
           → htmltree.pas (DOM tree builder)
           → htmllayo.pas (layout engine, 640×350)
           → htmlrip.pas  (RIP command translator)
           → ripengine    (render to canvas)
           → BMP/SDL      (display)
```

Usage: `ripview page.html` or `ripview http://example.com/`

This is how RIPterm displayed web pages in 1997. We're
bringing it back. No JavaScript needed — pure Pascal rendering.

Tags supported (htmlpars.pas):
- Document: HTML, HEAD, TITLE, BODY
- Headings: H1-H6
- Text: P, BR, HR, PRE, BLOCKQUOTE
- Formatting: B, I, U, EM, STRONG, TT, CODE
- Lists: UL, OL, LI
- Links: A (HREF)
- Images: IMG (SRC, ALT, WIDTH, HEIGHT)
- Tables: TABLE, TR, TD, TH (basic)
- Forms: FORM, INPUT, SELECT, TEXTAREA (display only)

### RV-3 — Multi-Engine Support

Load a .RIP file through v1, v2, v3, v4 engines side by side.
Show which engine renders what. Identify regressions.

### RV-4 — Visual Diff Tool

Render same .RIP through two engines, output a diff image
highlighting pixel differences. Already used manually during
Session 6 testing (sysop/0's visual-diffs).

### RV-5 — Engine Sync

ripview uses its own parser (rip1parse.pas/rip1exec.pas, 42 cmds).
mterm uses mtrip.pas (53 cmds). Need to sync command coverage
so ripview has the same commands as mterm.

This is part of MT-25 (engine consolidation).

## Source Files

| File | Lines | What |
|------|-------|------|
| ripview.pas | 612 | Main program, CLI + FV modes |
| rip1parse.pas | — | v1.54 command parser |
| rip1exec.pas | — | v1.54 command executor |
| ripdraw.pas | 533 | Drawing primitives (see RIPDRAW.md) |
| ripengine.pas | 183 | Canvas, palette, pixel buffer |
| riptext.pas | — | Text rendering (8x16 bitmap + CHR vector) |
| ripbmp.pas | — | BMP file output |
| rip_compat.pas | — | FPC compatibility shims |

## 16-bit DOS Notes

Current pixel buffer: 640×350 = 224KB flat array.
Exceeds 64KB single-segment limit on real-mode DOS (i8086).

For DOS i8086 target: row-pointer approach needed.
350 pointers × 640 bytes per row, no single alloc over 64KB.
FloodFill visited buffer: bitmask (28KB fits in one segment).
Reference: riplib C99 uses this approach.

Not blocking — DOS targets deferred until fpc264irc complete.

## Team

| Handle | Role |
|--------|------|
| verta1878 | Project lead |
| sysop/0 | Compiler engineer, FPC, Tang Console, USB |
| bob | Compiler engineer, OpenWatcom, Glide, 3dfx drivers |
| evga | Display, Mystic, SIO rebuild |
| kiddo | Protocols, RIPscrip |
| wrench | Transport, FOSSIL, DVI/HDMI |
| hexadecimal | PCBoard, Cyclades |
| byte | Program discovery |
| DotMatrix | Documentation sourcing |


## License

GPLv3
