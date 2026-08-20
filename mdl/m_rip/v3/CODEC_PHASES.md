# FPC Codecs — Development Phases

## v1 Audio Codecs (decode-only, file/memory)

| Phase | Codec | Lines | Status |
|-------|-------|-------|--------|
| C1 | vocdec.pas — Creative Voice File | 418 | DONE |
| C1b | ansimusic.pas — ANSI/MML music + PCM synth | 500 | DONE |
| C2 | adpcmdec.pas — IMA/MS ADPCM 4-bit | 419 | DONE |
| C3 | audec.pas — Sun AU/SND (mu-law, A-law, PCM) | 286 | DONE |
| C4 | aiffdec.pas — Apple AIFF/AIFF-C | 373 | DONE |
| C5 | moddec.pas — ProTracker MOD (4-channel tracker) | ~600 | TODO |
| C6 | s3mdec.pas — Scream Tracker S3M | ~500 | TODO |
| C7 | xmdec.pas — FastTracker XM / Impulse Tracker IT | ~800 | TODO |
| C8 | flacdec.pas — FLAC lossless audio | ~500 | TODO |
| C9 | mp3dec.pas — MPEG Layer 3 (header/frame/side info) | 610 | DONE |

## v1 Graphics Codecs (decode-only)

| Phase | Codec | Lines | Status |
|-------|-------|-------|--------|
| — | jpegdecraw.pas — Baseline JPEG | 308 | DONE |
| — | pngcodec.pas — PNG (all color types) | 393 | DONE |
| — | gifdecraw.pas — GIF + animation (256 frames) | 510 | DONE |
| — | pasjpeg/ — Full JPEG encode+decode library | 58 files | DONE |
| G1 | bmpdec.pas — BMP standalone (1/4/8/24/32-bit) | ~200 | TODO |
| G2 | pcxdec.pas — PCX standalone (16/256-color RLE) | ~200 | TODO |
| G3 | tgadec.pas — Targa TGA (RLE, 8/16/24/32-bit) | ~200 | TODO |
| G4 | icodec.pas — Windows ICO/CUR | ~150 | TODO |
| G5 | pbmdec.pas — Netpbm PBM/PGM/PPM | ~100 | TODO |

## Existing Playback/Utility Units

| Unit | Lines | Description |
|------|-------|-------------|
| wavdec.pas | 294 | WAV file parser |
| wavplay.pas | 451 | Cross-platform WAV playback (Win32/Linux/DOS/Darwin/OS2) |
| dosplay.pas | 481 | Sound Blaster DMA (DOS), stubs elsewhere |
| pcmdec.pas | 310 | PCM decoder with format detection |
| pcmdecraw.pas | 197 | Raw PCM decoder |
| pcmmix.pas | 342 | 16-stream PCM mixer |
| mididec.pas | 378 | MIDI SMF format 0/1 parser |
| lzmadecpas.pas | 652 | LZMA1/LZMA2 decompressor |
| fixedmath.pas | 264 | 16.16 fixed-point math (no FPU) |
| dfm2lfm.pas | 257 | Delphi DFM to Lazarus LFM converter |

## v2 Streaming (deferred)

### MP3 Full Decode (v2 enhancement, deferred)
| Phase | Feature |
|-------|---------|
| C9b | MP3 Huffman tables (32 tables, ~2000 entries) |
| C9c | MP3 requantization + stereo processing |
| C9d | MP3 IMDCT (36-point + 12-point transforms) |
| C9e | MP3 subband synthesis (32-point polyphase filter) |
| C9f | MP3 full decode integration + verification |

Current mp3dec.pas (610 lines) handles: frame sync, ID3v2 skip,
header parsing, side info decode, bit reservoir, duration/format
detection. Full audio decode requires C9b-C9f (~2500 additional lines).

### Audio Streaming
| Phase | Feature |
|-------|---------|
| C10 | Streaming API — callback-based chunk decode for all audio codecs |
| C11 | WAV streaming (chunked read, feed to mixer) |
| C12 | VOC streaming |
| C13 | MOD/S3M streaming (tick-based mixing) |
| C14 | Network audio streaming (BBS telnet audio) |
| C15 | Ring buffer + double-buffer DMA integration with dosplay |
| C16 | Cross-platform async playback (threaded Win32/Linux, IRQ DOS) |

### Graphics Streaming
| Phase | Feature |
|-------|---------|
| G10 | Progressive JPEG decode (scan-by-scan) |
| G11 | Interlaced PNG streaming (pass-by-pass) |
| G12 | Interlaced GIF streaming |
| G13 | Animated GIF frame-by-frame playback with timing |
| G14 | RIP scene progressive rendering (command-by-command) |
| G15 | Sprite animation frame streaming |

## How to Compile

All codecs compile with FPC 2.6.4irc r3.1+ in Delphi mode:

```bash
# Single unit compile check
ppc386 -Mdelphi -s vocdec.pas

# Compile a program using codecs
ppc386 -Mdelphi -Fu<path-to-codecs> myprogram.pas

# With paszlib (needed for pngcodec.pas only)
ppc386 -Mdelphi -Fu<path-to-codecs> -Fu<path-to-paszlib> myprogram.pas

# Cross-compile for different targets
ppc386 -Mdelphi -Twin32 -Fu<units>/i386-win32 -Fu<codecs> myprogram.pas
ppc386 -Mdelphi -Tgo32v2 -Fu<units>/i386-go32v2 -Fu<codecs> myprogram.pas
ppc386 -Mdelphi -Tdarwin -Fu<units>/i386-darwin -Fu<codecs> myprogram.pas
```

## How to Use

### Image Decoding
```pascal
uses jpegdecraw, pngcodec, gifdecraw;
var Pixels: PByte; W, H: LongInt; Alpha: Boolean;
begin
  // JPEG -> RGB
  if JPEGLoadFileRaw('photo.jpg', Pixels, W, H) then begin
    // Pixels = W*H*3 bytes (RGB)
    FreeMem(Pixels);
  end;

  // PNG -> RGB or RGBA
  if PNGDecodeFile('icon.png', Pixels, W, H, Alpha) then begin
    // Alpha=True: 4 bytes/pixel, Alpha=False: 3 bytes/pixel
    FreeMem(Pixels);
  end;

  // GIF -> RGB (first frame)
  if GIFLoadFileRaw('image.gif', Pixels, W, H) then begin
    FreeMem(Pixels);
  end;
end.
```

### Audio Decoding
```pascal
uses wavdec, vocdec, audec, aiffdec, adpcmdec;
var W: TWAVInfo; V: TVOCInfo; A: TAUInfo; AF: TAIFFInfo;
begin
  // WAV
  if WAVLoadFile('sound.wav', W) then begin
    // W.Data, W.DataSize, W.SampleRate, W.BitsPerSample, W.Channels
    WAVFree(W);
  end;

  // VOC (Sound Blaster native)
  if VOCLoadFile('sound.voc', V) then begin
    // V.Data, V.SampleRate, V.BitsPerSample, V.Channels
    VOCFree(V);
  end;

  // AU/SND (Sun/NeXT, mu-law/A-law/PCM)
  if AULoadFile('sound.au', A) then begin
    // A.Data = 16-bit signed PCM
    AUFree(A);
  end;

  // AIFF (Apple, big-endian PCM/mu-law/A-law)
  if AIFFLoadFile('sound.aiff', AF) then begin
    // AF.Data = 16-bit signed PCM
    AIFFFree(AF);
  end;
end.
```

### ANSI Music
```pascal
uses ansimusic, wavplay;
var Events: PAMEvent; Count: Integer;
    PCM: PByte; PCMSize: LongWord;
begin
  // Parse MML string
  if AMParseMML('T120 O4 L4 C D E F G A B > C', Events, Count) then begin
    // Option 1: PC speaker (DOS only)
    AMPlayEvents(Events, Count);

    // Option 2: Synthesize to PCM + play via wavplay
    if AMSynthPCM(Events, Count, 22050, PCM, PCMSize) then begin
      PlayPCMBuffer(PCM, PCMSize, 22050, 8, 1);
      FreeMem(PCM);
    end;

    FreeMem(Events);
  end;

  // Extract from ANSI art file
  // AMExtractFromANSI(FileData, FileSize, MMLString);
end.
```

### Audio Playback
```pascal
uses wavplay;
begin
  if AudioAvailable then begin
    PlayWAV('sound.wav');        // blocking
    PlayWAVAsync('music.wav');   // non-blocking (Win32/Linux/Darwin)
    StopWAV;                     // stop async playback
  end;
end.
```

### ADPCM Decoding (for compressed WAV files)
```pascal
uses adpcmdec;
var OutPCM: PSmallInt; OutSamples: LongInt;
begin
  // IMA ADPCM (WAV format tag 0x0011)
  if IMADecode(CompData, CompSize, 1, 512, OutPCM, OutSamples) then begin
    // OutPCM = 16-bit signed, OutSamples = sample count
    FreeMem(OutPCM);
  end;

  // MS ADPCM (WAV format tag 0x0002)
  if MSDecode(CompData, CompSize, 1, 512, 500, 7, @Coeffs, OutPCM, OutSamples) then begin
    FreeMem(OutPCM);
  end;
end.
```

## Platforms

All decoders compile on: Win32, Linux, FreeBSD, Darwin, DOS (go32v2), OS/2.
wavplay.pas has native backends for all six.
dosplay.pas is DOS-only (stubs on other platforms).

## Dependencies

All codecs are zero-dependency EXCEPT:
- pngcodec.pas requires paszlib (inflate, included with FPC)

## License

GNU General Public License v3
Part of FPC 2.6.4irc r3.1 — Mystic BBS IRC Fork

## RIP Scene Progressive Rendering — Format Options

Five approaches for streaming RIP graphics incrementally, from simplest
to most optimized. These can be combined.

### R1: RIP Stream (text-based, incremental)
Raw RIP commands parsed and rendered as each command arrives over the
wire. Like our existing `ProcessLine` but chunked — the engine draws
immediately without waiting for the full scene.

- **Pros:** Zero overhead, works with existing BBS protocol, no new format
- **Cons:** Text parsing overhead, no random access, no partial updates
- **Implementation:** Feed telnet bytes to RIP parser, call `ProcessLine`
  per complete command, blit framebuffer to display after each command
- **Use case:** Live BBS connection, real-time terminal rendering

### R2: Binary Scene File (compact encoding)
Compact binary encoding of drawing commands — each RIP command encoded
as a 1-byte opcode + packed binary parameters instead of MegaNum text.
4-8x smaller than text RIP, faster to parse.

- **Pros:** Fast decode, small files, good for caching/offline viewing
- **Cons:** New format (not standard RIPscrip), needs encoder
- **Implementation:** Binary writer (RIP-to-bin converter) + binary reader
  that feeds commands to the existing engine
- **Use case:** Cached scenes, precompiled RIP art, offline gallery

### R3: Tile-Based (rectangular regions)
Scene split into rectangular tiles (e.g. 64x64 or 128x128 pixels), each
tile rendered independently and sent as a separate chunk. Like progressive
JPEG but for vector scenes. Tiles can arrive in any order.

- **Pros:** Partial display immediately, parallel decode possible,
  random access to scene regions
- **Cons:** Tile boundaries visible during load, needs scene subdivision,
  commands that span tiles need clipping
- **Implementation:** Pre-render full scene, split framebuffer into tiles,
  encode each tile as RLE bitmap or mini-RIP command block
- **Use case:** Slow connections, large scenes, thumbnail generation

### R4: Layer-Based (depth ordering)
Background rendered first, then overlays added as separate chunks. Each
layer is a complete drawing pass at a specific depth. Allows progressive
detail: first the solid fills, then outlines, then text, then icons.

- **Pros:** Natural for RIP scenes (background → buttons → text → icons),
  each layer meaningful on its own, good for partial rendering
- **Cons:** Needs layer assignment (manual or automatic), overdraw
- **Implementation:** Sort RIP commands by type/depth into layers,
  render each layer to transparent overlay, composite progressively
- **Layer order:** 1) Background fills 2) Lines/shapes 3) Text/fonts
  4) Icons/images 5) Buttons/UI 6) Mouse fields (invisible)
- **Use case:** Complex scenes with many elements, preview rendering

### R5: Delta/Diff (changed regions only)
Only changed regions sent after the initial frame. The first frame is a
full scene render; subsequent frames send rectangular diff patches for
regions that changed. Ideal for animation and interactive updates.

- **Pros:** Minimal bandwidth for small changes, excellent for animation,
  button hover/click feedback is just a small patch
- **Cons:** Requires tracking dirty rectangles, first frame still full,
  out-of-order patches cause artifacts
- **Implementation:** Track dirty rect per RIP command, encode changed
  pixels as RLE bitmap patches with (x, y, w, h) headers
- **Patch format:** [X:2][Y:2][W:2][H:2][RLE pixel data]
- **Use case:** RIP animation, interactive button feedback, scrolling,
  palette cycling effects

### Combining Approaches

For the RIP browser, the recommended stack is:

```
R1 (live BBS)     ← telnet stream, immediate rendering
  + R5 (deltas)   ← button clicks send diff patches back
  + R4 (layers)   ← initial scene loads background first

R2 (cached)       ← precompiled scenes for offline viewing
  + R3 (tiles)    ← thumbnail generation, partial preview
```

### Codec Pattern

All RIP scene codecs follow the standard codec pattern:

- Standalone `.pas` unit in `src/lazarus/lcl/` directory
- `{$H-}` compatible (ShortString mode)
- Uses `Assign`/`Reset`/`BlockRead` (no TStream, no Classes)
- GPLv3 header
- File + memory buffer APIs
- Zero external dependencies

Planned units:

| Unit | Approach | Description |
|------|----------|-------------|
| ripdecraw.pas | R1 | RIP stream decoder — incremental text command parser |
| ripbindec.pas | R2 | Binary scene file decoder — compact opcode format |
| riptile.pas | R3 | Tile-based scene splitter/loader |
| riplayerdec.pas | R4 | Layer-based scene decoder — depth-ordered chunks |
| ripdelta.pas | R5 | Delta/diff patch decoder — dirty rectangle updates |
| scenedecraw.pas | All | Unified scene decoder — auto-detects format, dispatches |

### Related Phases
- G14 in v2 Graphics Streaming covers the engine integration
- C13 in v2 Audio Streaming covers MOD/audio sync with scene rendering
- DOS_LCL_RIP_BROWSER_ROADMAP.md covers the full browser architecture

## Phase 23: RIP Advanced Graphics (6 items)

Graphics rendering primitives integrated into the RIP renderer
(ripdecraw.pas / ripbindec.pas / riplayerdec.pas). These extend
the existing pixel buffer drawing in rip2api.pas with
production-quality effects.

Implemented WITHIN the R1-R5 RIP rendering units, not as
separate standalone codecs. The rendering pipeline is:

```
RIP Stream (R1) -> Command Parse -> Render Pipeline:
  grclip    (clip region setup)
  grfill    (gradient fills)
  grbezier  (variable-width curves)
  grtexmap  (texture mapping)
  grfx      (shadows/glow post-process)
  grlayer   (layer composite -> final output via R4)
  ripdelta  (dirty rect tracking via R5)
```

| # | Feature | Unit | Description |
|---|---------|------|-------------|
| 7 | Gradient fills | grfill.pas | Linear, radial, and conical gradients. Fills arbitrary regions with smooth color transitions. Palette-mapped (16/256) and truecolor (24-bit) modes. Dithering for low-color displays. |
| 8 | Drop shadows / glow | grfx.pas | Per-shape drop shadow with configurable offset, blur radius, color, and opacity. Outer glow (bloom) for text and icons. Gaussian blur kernel for shadow softening. |
| 9 | Bezier curves (variable width) | grbezier.pas | Cubic and quadratic Bezier with per-control-point width. Stroke width interpolated along curve. Cap styles (butt, round, square). Join styles (miter, round, bevel). Builds on rip2api Bezier but adds width variation. |
| 10 | Texture mapping | grtexmap.pas | Affine texture mapping on convex polygons. Perspective-correct option for 3D projected quads. Bilinear filtering. UV coordinate mapping. Source texture from any pixel buffer (BMP, PCX, JPEG decode output). |
| 11 | Layer compositing | grlayer.pas | Alpha blending (source-over), multiply, screen, overlay, darken, lighten blend modes. Per-layer opacity (0-255). Layer stack with arbitrary depth. Composites layers onto final framebuffer. |
| 12 | Clipping paths | grclip.pas | Non-rectangular clipping regions defined by polygon paths. Even-odd and winding fill rules. Clip stack (push/pop). All drawing primitives respect active clip path. Scanline-based clip test for performance. |

### Dependencies Between Phase 23 Items

```
fixedmath.pas ──→ grbezier.pas (curve math)
                ──→ grtexmap.pas (perspective divide)
                ──→ grfill.pas (gradient interpolation)

grclip.pas ────→ grfill.pas (clipped gradient fills)
               ──→ grbezier.pas (clipped curves)
               ──→ grtexmap.pas (clipped texture mapping)

grlayer.pas ───→ grfx.pas (shadow/glow rendered to separate layer)
```

### Integration with RIPscript Engines

These units are called BY rip2api.pas, not the other way around.
The RIP engine maintains the pixel buffer; Phase 23 units operate
on that buffer via pointer + width + height parameters:

```pascal
{ Example: gradient fill a rectangle }
uses grfill;
GradientFillRect(RIPEngine.FrameBuffer, RIPEngine.Width, RIPEngine.Height,
  X1, Y1, X2, Y2, Color1, Color2, gtLinear, 45);

{ Example: draw bezier with variable width }
uses grbezier;
BezierDrawVarWidth(RIPEngine.FrameBuffer, RIPEngine.Width, RIPEngine.Height,
  Points, 4, Width1, Width2, Color, csRound);

{ Example: composite layers }
uses grlayer;
LayerComposite(BackgroundBuf, ForegroundBuf, OutputBuf,
  Width, Height, bmAlpha, 192);
```

### Build Order

Phase 23 depends on Phase G1-G5 (graphics codecs) being complete
for texture sources, and on fixedmath.pas for curve/gradient math.
Recommended build order: grclip → grfill → grbezier → grtexmap → grfx → grlayer.

## v4.0 Deferred Items (Starting Point)

- [ ] Full-Motion Video — FLI/AVI decoder (TeleGrafix whitepaper §4.2)
- [ ] Document Oriented Interface — page layout engine (TeleGrafix whitepaper §4.6)
- [ ] HTML Rendering — embedded HTML within RIPscrip (TeleGrafix whitepaper §4.7)
- [ ] MIDI Synthesis — currently parse-only via mididec.pas, host plays (needs wavetable/FM synth)
- [ ] Full Unicode — rip3unicode.pas companion unit (CP437 sufficient for current BBS use)

## v4 Preview Files (held — not in v3 source)

Source: fpc264irc-v4-preview-unicode-20260721.zip
Location: docs/rip/

- cp437utf8.pas (201 lines) — CP437 to UTF-8 translation table (256 codepoints)
- utf8render.pas (279 lines) — UTF-8 text renderer with bitmap glyph support
- ttfglyph.pas (386 lines) — TrueType/OpenType glyph loader + rasterizer

These implement the deferred "Full Unicode" item. When v4 work
begins, these units go into a new font/ or unicode/ codec directory
and wire into rip4api.pas.

## v4.0 Preview Units (held in docs/v4-preview/)

- cp437utf8.pas (201 lines) — CP437 to UTF-8 translation table
- utf8render.pas (279 lines) — UTF-8 text renderer with bitmap glyphs
- ttfglyph.pas (386 lines) — TrueType/OpenType glyph loader + rasterizer

These units enable Full Unicode and TTF font support for v4.0.
Not included in v3 engine source. See docs/v4-preview/README.md.
