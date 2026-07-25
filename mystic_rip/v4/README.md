# RIPscrip v3.0 Server-Side Rendering Engine

Extension of mystic_ripapi2 (RIPscrip v2.0) with v3.0 features.

## Status: Phase 18 IN PROGRESS

RIPscrip 3.0 confirmed via RIPtel Visual Telnet v3.1 (Driver v3.0.7).
TeleGrafix Communications, Inc. 1996-97.

## Implemented Features

### Phase 15: True Color Pixel Buffer (COMPLETE)

- 24-bit RGB pixel buffer (3 bytes per pixel)
- 32-bit TrueColor mode (confirmed by RIPtel 3.1)
- TRIPRGB pixel type throughout engine
- DrawPixel/GetPixel with RGB values
- Indexed palette mode retained for backward compat
- Color mode switch: 8-bit indexed / 24-bit RGB / 32-bit TrueColor
- SaveBMP updated for native 24-bit output
- All drawing primitives updated for RGB
- AND/OR/NOT write modes, Color=7 guard
- FloodFill, InvertRegion, Scroll, LineAA routed through DrawPixel
- RGB32 alpha channel fix

### Phase 16: Resolution-Independent Coordinates (COMPLETE)

- World coordinate system (floating-point Real)
- Viewport mapping (MapX/MapY/UnmapX/UnmapY)
- SetWorldCoords / ClearWorldCoords / IsWorldEnabled
- 14 world-coordinate drawing overloads (WPutPixel, WLine, etc)
- Aspect ratio preservation (SetWorldAspect)
- Resolution-independent scene files (|1z command)
- Large coordinates (999,999) clamped safely
- Text display area auto-detect (|1q command)

### Phase 17: Image Format Support (COMPLETE)

- JPEG pixel rendering (jpegdecraw.pas)
- GIF loading with LZW decompression (gifdecraw.pas)
- PNG loading with deflate and alpha (pngdecraw.pas)
- BlitRGB / BlitRGBScaled / BlitRGBAlpha / BlitRGBMask / BlitIndexed
- RGBAToMask (1-bit mask from RGBA alpha channel)
- TRIPImageBuffer convenience wrappers
- LoadImage auto-detect, LoadImageScaled

## Planned Features (Phases 18-24)

- RFF scalable font glyph rendering
- Polygon enhancements (4096 vertices)
- Data tables and form fields
- Text variables v3.0
- Advanced multimedia (WAV, MIDI)
- Gradient fills, drop shadows, texture mapping
- Layer compositing with alpha blending
- Documentation

## Architecture

Extends `mystic_ripapi2/rip2api.pas` (v2.0 engine).
Same standalone approach: `{$H-}`, zero MDL dependencies.
NOTE: `{$H-}` (short strings) is required to avoid BUG-029.
`Classes`/`TStream` require `{$H+}` and are incompatible.
All file I/O uses `Assign`/`Reset`/`BlockRead` instead.
Decoders (img/, wav/) follow the same convention.
- `prg/` — progressive rendering codecs (5 decoders: stream, binary, tile, layer, delta)
6859 lines. 262 items complete, 37 todo.

## Compile

```
ppcx64 -Mdelphi -Fu<path-to-mystic_ripapi3> -Fu<path>/img -Fu<path>/wav -Fu<path>/pasjpeg yourprogram.pas
```

No -Fumdl or -Fumystic needed. The unit is fully standalone.

## Directory Structure

- `rip3api.pas` — main engine source
- `rip_font8x8.inc` — 8x8 bitmap font data
- `rip_font8x14.inc` — 8x14 bitmap font data
- `img/` — standalone {$H-} image and font decoders (v3.0)
  - `jpegdecraw.pas` — JPEG decoder (raw, no TStream)
  - `gifdecraw.pas` — GIF decoder (LZW, animation)
  - `pngdecraw.pas` — PNG decoder (deflate, alpha)
  - `rffdecraw.pas` — RFF v2.2 scalable font parser
- `wav/` — audio/multimedia units
- `prg/` — progressive rendering codecs (5 decoders: stream, binary, tile, layer, delta)
  - `dosplay.pas` — DOS Sound Blaster playback
  - `wavplay.pas` — WAV file playback
  - `pcmmix.pas` — PCM audio mixer
  - `pcmdecraw.pas` — PCM decoder (raw, standalone)
  - `pcmdec.pas` — PCM decoder (legacy)
  - `mididec.pas` — MIDI decoder
  - `fixedmath.pas` — fixed-point math helpers
  - `jpegdec.pas` — JPEG decoder (legacy)
- `pasjpeg/` — JPEG decoder library (60 units, v2.0 compat)
- `PHASES.md` — phase roadmap and checklist
- `RIPTEL_PROTOCOL_ANALYSIS.md` — RIPtel v3.1 protocol analysis
- `RFF_FORMAT_NOTESv3.md` — RFF v2.2 font format reverse engineering notes
- `MAF_FORMAT_NOTES.md` — MAF bitmap font format notes
- `CLIENTSERVER.md` — client/server architecture and variable scoping docs
- `PROGRESSIVE.md` — progressive rendering architecture and codec guide
- `RIPAINT_FINDINGS.md` — RIPaint 2.0 binary analysis findings
- `VERSION` — version and status

## License

GNU General Public License v3. Part of the Mystic BBS IRC Fork.
