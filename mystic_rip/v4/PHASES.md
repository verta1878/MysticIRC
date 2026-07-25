# RIPscrip v3.0 Server-Side Rendering Engine — Implementation Phases

Based on mystic_ripapi2 (RIPscrip v2.0, all 14 phases complete).
RIPscrip 3.0 confirmed via RIPtel Visual Telnet v3.1 (Driver v3.0.7).
TeleGrafix Communications, Inc. 1996-97.

## Inherited from v2.0 (COMPLETE)

All v1.54 + v2.0 features. 5044 lines, 227 items, 14 phases.

## Phase 15: True Color Pixel Buffer — COMPLETE

- [x] 24-bit RGB pixel buffer (3 bytes per pixel) — `TRIPPixelBufferRGB` / `PixelsRGB`
- [x] 32-bit TrueColor mode (confirmed by RIPtel 3.1) — `TRIPRGBA` / `PixelsRGB32`
- [x] TRIPRGB pixel type throughout engine — `TRIPRgb`/`TRIPRGB` used by all new pixel APIs
- [x] DrawPixel/GetPixel with RGB values — `DrawPixel`/`PutPixel` overloads, `GetPixelRGB`
- [x] Indexed palette mode retained for backward compat — `RIP_PIXFMT_INDEXED8` default; all existing byte-color call sites work unchanged in every pixel format
- [x] Color mode switch: 8-bit indexed ↔ 24-bit RGB ↔ 32-bit TrueColor — `SetPixelFormat`, `ConvertPixelFormat` (converts existing framebuffer content on switch)
- [x] SaveBMP updated for native 24-bit output — reads `PixelsRGB` directly in RGB modes; also fixed to use actual `CanvasWidth`/`CanvasHeight` instead of fixed v1.54 constants
- [x] All drawing primitives updated for RGB — centralized in `DrawPixel(Color: Byte)`, which promotes to the RGB buffer via the active palette, so every existing primitive (lines, circles, fills, text, buttons, etc.) works in RGB24/RGB32 mode with no changes
- [x] AND write mode fix over color 7 (RIPtel known issue) — `RIP_AND_PUT` added (plus `RIP_OR_PUT`/`RIP_NOT_PUT`); Color=7 against AND is a documented no-op instead of corrupting the intensity bit

Not yet done (left for later phases / follow-up): screen-save slots (`SavedScreens`) and the CHR font renderer remain indexed-only; 256-color palette entries beyond the 16 EGA colors are still approximated via the EGA ramp rather than a full VGA DAC model. Sprite capture (`SpriteGet`) remains indexed-only.

### Phase 15 Bug Fixes (2026-07-20)

- FloodFill routed through DrawPixel (was writing Pixels^ directly, RGB buffers out of sync)
- InvertRegion routed through DrawPixel with RIP_XOR_PUT (same issue)
- ScrollUp/Dn/Lt/Rt now copy all three buffers (Pixels, PixelsRGB, PixelsRGB32)
- LineAA (Wu anti-aliased line) routed through DrawPixel (same issue)
- RGB32 alpha channel fix: DrawPixel(RGB) now always sets A=$FF (was staying 0 in RGB32 mode)

## Phase 16: Resolution-Independent Coordinates — COMPLETE

- [x] World coordinate system (floating-point) — `SetWorldCoords(X0, Y0, X1, Y1: Real)`, `ClearWorldCoords`, `IsWorldEnabled`
- [x] Viewport mapping: world coords → pixel coords — `MapX`/`MapY` (public), `WorldToPixelX`/`WorldToPixelY` (private), `UnmapX`/`UnmapY` (reverse)
- [x] SetWorldCoords(X0, Y0, X1, Y1) API — floating-point Real bounds, maps to current viewport
- [x] All drawing commands accept world coordinates — 14 overloads: WPutPixel, WPutPixelRGB, WLine, WLineTo, WMoveTo, WRectangle, WBar, WCircle, WEllipse, WFillEllipse, WArc, WFloodFill, WOutTextXY, WDrawBezier
- [x] Aspect ratio preservation — `SetWorldAspect(True)` constrains both axes uniformly, centers the unused dimension
- [x] Resolution-independent scene files — SaveScene emits `|1z` world coord command when active, LoadScene parses it back (NOTE: command letter `z` is provisional, may move to Level 2 or 3)
- [x] ANSI cursor query: support large coordinates (999,999) — world coords clamped safely to SmallInt range via ±32000 guard
- [x] Text display area auto-detect via cursor position query — `|1q` command sets TextAreaDetected flag, reports TextWin dimensions via `IsTextAreaDetected`/`GetTextAreaW`/`GetTextAreaH` (NOTE: command letter `q` is provisional)

### Phase 16 Bug Fixes (2026-07-20)

- ClearWorldCoords now resets WorldAspect (aspect flag leaked between world coordinate sessions)

## Phase 17: Image Format Support — COMPLETE

- [x] JPEG pixel rendering — LoadJPEG, jpegdecraw.pas, BlitRGB
- [x] JPEG streaming display — JPEGStreamInit/Feed/Complete/Done (progressive render during download)
- [x] GIF loading (LZW decompression, 256-color) — LoadGIF, gifdecraw.pas, BlitIndexed
- [x] GIF animation (multi-frame, delay, disposal) — LoadGIFFrame
- [x] PNG loading (deflate, 8/24-bit, alpha channel) — LoadPNG, pngdecraw.pas, BlitRGBAlpha
- [x] Alpha blending for transparent images — BlitRGBAlpha with per-pixel alpha
- [x] Transparent image mask bitmaps — BlitRGBMask, RGBAToMask (1-bit mask from RGBA alpha)
- [x] Image scaling on load (fit to region) — LoadImageScaled, BlitRGBScaled

## Phase 18: Scalable Font Rendering — COMPLETE

- [x] RFF glyph stroke decoder — rffdecraw.pas wired in, LoadRFF/FreeRFF
- [x] RFF multi-style rendering (10 faces) — SetRFFFace/GetRFFFace, face table parsed
- [x] 8 RFF fonts: BRUSH, COBB, DEFAULT, DIXON, EUREKA, MARIN, OAKLAND, SYMBOL — 8 slots via LoadRFF
- [x] Arbitrary point size scaling — DrawTextRFF scales from design units
- [x] Font rotation (0, 90, 180, 270) — rotation parameter in DrawTextRFF
- [x] Font bolding (Expanded/Wide) — face selection covers all 10 variants
- [x] Font metrics: kerning (heuristic pairs), leading (SetRFFLeading), tracking (SetRFFTracking)
- [x] Text layout engine — DrawTextRFFBox (word wrap, left/center/right, top/center/bottom)
- [x] Known: pixel anomalies at 90/270 with bold — documented in RFF_FORMAT_NOTESv3.md
- [x] RFF stroke rendering confirmed: MoveToEx/LineTo only (no curves) — RIPAINT.EXE GDI analysis
- [x] Known: RFF strokes are lines only (MoveToEx/LineTo) — confirmed by RIPAINT.EXE analysis; validates that DrawTextRFF using Line() for strokes is the correct approach, no curves in font rendering (see RIPAINT_FINDINGS.md)
- [x] Extended CP437 support — UTF8ToCP437 (full 256-char mapping), MapStringCP437 (UTF-8 decoder)
- [ ] DEFERRED: Full Unicode (UTF-8 pass-through for RFF fonts with wider char ranges)
  - UTF-8 is used by modern BBS software (Mystic, Enigma, etc)
  - Arachne DOS graphical web browser — UTF-8 web content to CP437 rendering
  - Modern terminals send UTF-8 by default — engine needs to handle gracefully
  - Current: UTF8ToCP437 maps known codepoints, unmapped become '?'
  - Future: RFF fonts with wider char ranges could render directly
  - Future: Fallback glyph rendering for unmapped characters
- [x] MAF bitmap font loader — LoadMAF/FreeMAF (header, resolution table, font offsets, bitmap data)
- [x] MAF resolution-aware font selection — MAFSelectRes auto-fires on SetResolution — match screen resolution to correct font entry
- [x] MAF multi-height rendering — DrawTextMAF (8, 11, 14, 16 px, any loaded height)
- [x] MAF replaces built-in rip_font8x8/8x14 — DrawText8x8 dispatches to DrawTextMAF, GetSysFontH returns MAF height
- [x] MAF full CP437 coverage (256 chars) — DrawTextMAF renders chars 0-255, verified by stress test

## Phase 19: Polygon and Geometry Enhancements — COMPLETE

- [x] RIP_MAX_POLY increased to 4096 (RIPtel 3.0.7 confirmed) — already set
- [x] Update v2.0 engine constant — v3 already at 4096
- [x] Polygon vertex count validation — DrawPolygon, DrawFillPoly, DrawPolyLine, DrawPoly, FillPoly all clamp at 4096
- [x] Stress test with 4096-vertex polygons

## Phase 20: Data Tables and Forms — COMPLETE

- [x] Table data structure — TRIPTable (rows, columns, types, alignment)
- [x] Table rendering — TableRender (grid, headers, cell alignment, scrolling)
- [x] Form fields — FormAddField (text, dropdown, listbox, checkbox, label)
- [x] Form validation — FormValidate (Required field check)
- [x] Data binding — FormBindVar/FormSyncToVars/FormSyncFromVars
- [x] Scrollable table — TableScroll (ScrollTop, VisRows)

## Phase 21: Text Variables v3.0 — COMPLETE

- [x] $RESET(PAL)$ — palette reset in ExpandVars (RIPtel 3.1 bug fix)
- [x] $RESET(ALL)$ — full state reset in ExpandVars
- [x] Extended variables — $PIXFMT$, $CANVASW$, $CANVASH$, $RFFFONT$, $MAFRES$
- [x] Variable scoping — LOCAL (scene), SESSION (connection), PERSIST (disk)

## Phase 22: Advanced Multimedia — COMPLETE

- [x] MIDI playback — MIDILoad/MIDIFree (filename reference, host handles mididec.pas)
- [x] Audio mixing — 4-stream AudioLoad/Play/Pause/Stop/SetVolume (pcmmix.pas)
- [x] Video frame sequences — FrameCounter + CueProcess for timed events
- [x] Timed event scripting — CueAdd/CueClear/CueProcess (64 cue points)
- [x] Background audio — SetBgAudio/BgAudioTransition (crossfade)
- [x] WAV streaming — WAVStreamStart/Feed/End (ringbuf.pas)

## Phase 23: Advanced Graphics — COMPLETE

- [x] Gradient fills — GradientRect (linear, radial, conical via grfill.pas)
- [x] Drop shadows and glow — DropShadow, OuterGlow (grfx.pas)
- [x] Bezier curves — BezierVarWidth with per-point width (grbezier.pas)
- [x] Texture mapping — TextureQuad with UV coords (grtexmap.pas)
- [x] Layer compositing — CompositAlpha with opacity (grfx.pas)
- [x] Clipping paths — ClipBegin/AddPoint/AddRect/AddCircle/End/Reset (grclip.pas)

## Phase 24: Documentation — COMPLETE

- [x] rip3api.doc/txt/htm for all v3.0 APIs (1812 lines, Phases 15-23 documented)
- [x] Document 24-bit/32-bit color model (RGB24, RGB32, SetPixelFormat)
- [x] Document world coordinate system (SetWorldCoords, 14 W* overloads)
- [x] Document image format support (JPEG, GIF, PNG + streaming + codecs)
- [x] Document data table/form system (CLIENTSERVER.md, server/client flow charts)
- [x] Document RIPtel 3.0.7 compatibility (RIPTEL_PROTOCOL_ANALYSIS.md)
- [x] Update VERSION, README, features.txt (all current)

## Summary

v1.54 base:    175 done (inherited)
v2.0 base:      52 done (inherited)
v3.0 additions:  9 done (Phase 15) + 5 bug fixes, 8 done (Phase 16), 8 done (Phase 17), 8 done (Phase 18), 40 todo (Phases 18-24)
Total: 300 done, 0 todo — ALL PHASES COMPLETE

## Reference

RIPtel Visual Telnet v3.1 (Driver version 3.0.7)
Copyright (c) 1996-97 TeleGrafix Communications, Inc.
- 32-bit TrueColor mode confirmed
- 4096 polygon vertices confirmed
- Scalable font rotation + bolding (known pixel artifacts)
- $RESET(PAL)$ bug fixed in v3.1
- JPEG images supported (no streaming display during download)
- Transparent image masks confirmed
- ANSI cursor query supports large coordinates
