# RIP Engine Platform Tiers

## Date: 2026-08-20

## Why Four Versions?

The four engine versions exist because of platform constraints,
not feature creep. Each targets a different hardware tier.

## Platform Tier Matrix

| Tier | Engine | Video | Memory | DOS Mode | Era |
|------|--------|-------|--------|----------|-----|
| 1 | v1 | INT 10h / VBE | 64KB segments | i8086 real-mode | 1993 (RIPterm 1.54) |
| 2 | v2 | VBE 1.2/2.0 | Flat (extender) | go32v2 / DOS4G | 1994-95 (RIPaint 2.1) |
| 2a | v2 stripped | VBE | 64KB (row-ptrs) | i8086 real-mode | 1994 (no codecs) |
| 3 | v3 | VBE / SDL | Flat | go32v2 / Win32 / Linux | 1996 (RIPtel 3.x) |
| 4 | v4 | SDL2 | Flat | Win32 / Linux / macOS / BSD | 1995-96 multimedia PC |

## What Each Tier Adds

### Tier 1 — v1 (RIPscrip 1.54, 1993)

Baseline BBS graphics. 16-color EGA. What every RIP BBS used.

- 53 commands (37 Level 0 + 16 Level 1)
- 640x350 EGA 16-color canvas
- BGI bitmap + stroked fonts
- ICN icon files (EGA bitplane)
- Mouse fields and buttons
- No image codecs, no audio
- Fits in 640KB conventional memory

Video: INT 10h mode 10h (640x350x16) or VBE for higher res.
Memory: 64KB segments. Row-pointer canvas (28KB visited buffer).

### Tier 2 — v2 (RIPscrip 2.0, 1994-95)

Adds 256 colors and image loading. RIPaint 2.1 scene files.

- v1.54 commands + 15 new v2 commands
- 256-color palette (VGA mode 13h or VBE)
- JPEG decoder (pasjpeg, 33K lines pure Pascal)
- PNG decoder (pngdecr, 571 lines)
- WAV audio playback
- Print drivers (PostScript, PCL, ESC/P)

Video: VBE 1.2 (banked) or VBE 2.0 (linear framebuffer).
Memory: Decode buffers exceed 64KB — needs DOS extender (go32v2/DOS4G)
or row-pointer codec rewrite for pure real-mode DOS.

### Tier 2a — v2 Stripped (Pure DOS, No Codecs)

v2 command set but without JPEG/PNG decoders. For real-mode i8086
with VBE display. Handles v2 RIP commands, skips image loads gracefully.

### Tier 3 — v3 (RIPscrip 3.0, 1996)

Full multimedia. RIPtel client era. Column text, conditional templates.

- v2 commands + tables, forms, conditionals
- 22-unit dependency chain
- 10+ image format decoders (JPEG, PNG, GIF animated, BMP, PCX, TGA, PBM, ICO, RFF)
- Progressive JPEG, interlaced GIF/PNG
- Sprite animation
- Advanced graphics (bezier, texture mapping, clipping)
- FM synthesis (MIDI)
- Scene layering and progressive rendering

Video: VBE or SDL.
Memory: Heavy. go32v2 minimum, Win32/Linux preferred.
DOS: Possible with DOS/32A extender but pushing limits.

### Tier 4 — v4 (Full Stack, 1995-96 Multimedia PC)

Everything. The target is a 1995-96 multimedia PC — Windows 3.1/95
era hardware. That's when TeleGrafix shipped RIPterm 2.0/RIPtel.

- v3 commands + Unicode, TTF, HTML, MPEG, video
- 42-unit hard Uses clause
- Unicode text (CP437 ↔ UTF-8)
- TrueType font rendering (TTFGlyph)
- HTML 1.0 renderer (parser, DOM tree, layout, RIP translator)
- MPEG video playback
- Full print pipeline
- Server-side rendering (Mystic BBS produces bitmap output)

Video: SDL2.
Memory: Flat model only. No DOS target.
Platforms: Win32, Linux, macOS, BSD, OS/2 (via SDL).

## VBE (VESA BIOS Extensions)

VBE provides high-res framebuffer access on real-mode DOS without
a DOS extender. Used by Tier 1 and Tier 2.

- VBE 1.2: banked access (64KB window into VRAM, bank switch)
- VBE 2.0: linear framebuffer (direct memory-mapped VRAM)
- VBE 3.0: hardware triple buffering

INT 10h AX=4F00h — get VBE info
INT 10h AX=4F01h — get mode info
INT 10h AX=4F02h — set mode

Source: verta1878 has VBE source code.

## DOS Extenders

| Extender | Mode | Memory | FPC Target |
|----------|------|--------|------------|
| go32v2 (CWSDPMI) | DPMI 32-bit protected | 4GB flat | go32v2 |
| DOS/4G (Watcom) | DPMI 32-bit | 4GB flat | — |
| DOS/32A | DPMI 32-bit | 4GB flat | — |
| None (real mode) | i8086 16-bit | 640KB + 64KB segments | i8086 |

FPC supports go32v2 natively. i8086 real-mode added in FPC 3.0.

## Codec Memory Issue

PNG decoder: `GetMem(Pixels, Width * Height * 3)` — 640x350 = 672KB.
Exceeds 64KB segment. Real-mode DOS can't allocate this.

Options for real-mode codecs:
1. Row-pointer decode (same as canvas fix)
2. EMS/XMS for decode buffer
3. Strip codecs (Tier 2a)
4. Require DOS extender (Tier 2)

## Future: Plugin Architecture

hexadecimal's design: ONE engine with registered codecs (prnapi pattern).
Link-time configuration replaces four separate source files.

| Build | Links | Result |
|-------|-------|--------|
| DOS i8086 | v1 handlers only | Tier 1 |
| DOS go32v2 | v1+v2 handlers + JPEG/PNG | Tier 2 |
| Modern | all handlers + all codecs | Tier 4 |

This is RIP-MIG-1. Not started yet.

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

