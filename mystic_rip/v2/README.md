# RIPscrip v2.0 Server-Side Rendering Engine

Extension of mystic_ripapi v1.0.0 (RIPscrip v1.54) with v2.0 features.

## Status: ALL PHASES COMPLETE

227 items done. 67 RIP commands. 5160 lines. 0 stubs.

## v1.54 Base (Complete)

All 51 v1.54 commands, standalone, zero dependencies.
See `../mystic_ripapi/` for the v1.54 engine.

## v2.0 Extensions (Complete)

New features decoded from RIPaint 2.1 (TeleGrafix, 1997) scene files.
No code taken — all information from file format observation.

### New Commands (16)
| Cmd | Params | Purpose |
|-----|--------|---------|
| `J` | 2 | Protocol version init |
| `n` | 4 | Set resolution |
| `M` | 2 | Color mode (256-color) |
| `f` | 4 | RFF font select (loaded and rendered) |
| `k` | 2 | Pen width |
| `N` | 2 | Drawing layer |
| `K` | 8 | Clear bounded region |
| `D` | var | Define palette/gradient |
| `d` | 7 | Palette entry (cycling) |
| `y` | var | Extended polyline/path |
| `x` | var | Extended filled polygon |
| `j` | 4 | Jump to coordinates |
| `t` | var | Text on path |
| `1b` | var | Extended button (mouse field) |
| `1i` | var | Extended icon load |
| `1p` | var | Extended put image |

### File Format Support
- `.BMP` — full pixel rendering
- `.PCX` — full pixel rendering
- `.ICN` — full EGA planar icon rendering
- `.BMH` — BMP highlight icons (standard Windows BMP)
- `.PAL` — 256-color RGB palette (768 bytes + header)
- `.RFF` — scalable vector fonts (full stroke rendering)
- `.JPG` — full pixel rendering via jpegdecraw.pas
- `.WAV` — audio codecs in wav/ directory

### Enhancements (from SVGACC reference, author permission)
- Configurable resolution (640x480, 800x600, 1024x768)
- 256-color palette with fade/dim/rotate
- Block resize and rotate
- 2D/3D point transformations
- Sprite system with collision detection
- Animation and frame rate control
- Wu anti-aliased line drawing

## Architecture

Same standalone approach as v1.54: `{$H-}`, zero MDL dependencies.
NOTE: `{$H-}` (short strings) required to avoid BUG-029.
`Classes`/`TStream` require `{$H+}` and are incompatible.
All file I/O uses `Assign`/`Reset`/`BlockRead`.

## Compile

```
ppc386 -Mdelphi -Fu<path-to-mystic_ripapi2> -Fu<path>/img -Fu<path>/pasjpeg yourprogram.pas
```

## Directory Structure

- `rip2api.pas` — main engine source (5160 lines)
- `rip_font8x8.inc` — 8x8 bitmap font data
- `rip_font8x14.inc` — 8x14 bitmap font data
- `img/` — standalone {$H-} decoder
  - `jpegdecraw.pas` — JPEG pixel decoder
- `wav/` — audio codecs (DOS Sound Blaster)
  - `dosplay.pas`, `pcmdec.pas`, `wavdec.pas`, `wavplay.pas`
- `pasjpeg/` — JPEG decoder library (58 units, TStream-based)
- `PHASES.md` — phase roadmap and checklist
- `RFF_FORMAT_NOTESv2.md` — RFF font format notes
- `RIPAINT_FINDINGS.md` — RIPaint 2.0 binary analysis
- `VERSION` — version and status
- `features.txt` — feature summary

## License

GNU General Public License v3. Part of the Mystic BBS IRC Fork.
