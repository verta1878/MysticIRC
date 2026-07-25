# RIPscrip v2.0 Server-Side Rendering Engine — Implementation Phases

Based on mystic_ripapi v1.0.0 (RIPscrip v1.54, all 8 phases complete).
New features decoded from RIPaint 2.1 scene files — no code taken.

## Inherited from v1.54 (COMPLETE)

All 51 v1.54 commands, 4037 lines, 175/175 items done.

## Phase 9: Protocol and Color Extensions — COMPLETE

- [x] Bare pipe `|` command prefix (in addition to `!|`)
- [x] Extended MegaNum (3-4 digit values for coords > 1295)
- [x] 256-color palette (extend Palette[0..15] to [0..255])
- [x] Extended color values in commands (0G..9R = colors 16-255)
- [x] Configurable canvas resolution (640x480, 800x600, 1024x768)
- [x] Pixel buffer as dynamic allocation (not fixed 640x350)
- [x] |J nn — protocol version init
- [x] |n nnnn — set resolution
- [x] |M nn — set color mode

## Phase 10: New Drawing Commands — COMPLETE

- [x] |K nnnnnnnn — clear/kill bounded region (x0 y0 x1 y1)
- [x] |k nn — pen width / line thickness
- [x] |N nn — drawing context / layer select
- [x] |j nnnn — jump to coordinates
- [x] |y nn... — extended polyline/path (variable length)
- [x] |x nn... — extended filled polygon (variable length)
- [x] |t nn... — text on path
- [x] |D nn... — define palette/gradient/gradient (variable length)
- [x] |d nnnnnnn — define palette entry (palette cycling)

## Phase 11: New File Formats — COMPLETE

- [x] .BMH loading (BMP highlight icons — standard BMP, already works)
- [x] .PAL loading (16-byte EGA or 868-byte 256-color RGB)
- [x] .JPG loading (full pixel rendering via jpegdecraw.pas, nearest EGA color mapping)
- [x] .RFF loading (full stroke data decoded — pen encoding: (0,0) = pen lift, first pair = move, rest = draw. Renders via DrawTextCHR. See RFF_FORMAT_NOTESv2.md.)
- [x] .WAV reference (audio codecs in wav/ directory — dosplay, pcmdec, wavdec, wavplay)
- [x] |f nnnn — font select (RFF font loaded and rendered)
- [x] |1i — extended icon load (JPEG/BMP)
- [x] |1b — extended button (creates mouse field with host command and status text)
- [x] |1p — extended put image

## Phase 12: SVGACC-Inspired Enhancements — COMPLETE

Based on Zypher Software SVGACC v2.6 API (source rights from author).
Backported to Pascal — no SVGACC code used, API as design reference.

- [x] Block resize (scale raster block to new dimensions)
- [x] Block rotate (rotate raster block by angle)
- [x] 2D transforms: rotate, scale, translate point arrays
- [x] 3D transforms: rotate, scale, translate, project (3D->2D)
- [x] 256-color palette fade/dim/rotate (palchgstep, paldimstep)
- [x] Sprite system (transparency color, background save)
- [x] Sprite collision detection
- [x] 4-direction region scrolling (up/down/left/right)
- [x] Antialiased line drawing (Wu algorithm) drawing

## Phase 13: Animation and Multimedia — COMPLETE

- [x] Frame-based BMP animation (LoadAnimFrame) (EARTH_01..EARTH_30 sequences)
- [x] Palette cycling (PalCycle fwd/rev) (CYC*.RIP fade transitions)
- [x] FADEIN/FADEOUT transitions (FadeIn/FadeOut with steps) transitions
- [x] WAV audio playback (wavdec + pcmdec + dosplay + wavplay) hooks
- [x] Animation timer (SetFrameRate/GetFrameRate, 1-60 FPS)/frame rate control

## Phase 14: Documentation — COMPLETE

- [x] Update rip2api.doc/txt/htm for all v2.0 commands
- [x] Document RFF font format (RFF_FORMAT_NOTESv2.md)
- [x] Document PAL file format (16-byte and 868-byte)
- [x] Document BMH format (= standard BMP)
- [x] Document new command parameters
- [x] Update VERSION, README, features.txt

## Summary

v1.54 base: 175 done, 0 todo (inherited)
v2.0 additions: 52 done, 0 todo (Phases 9-14)
Total: 227 done, 0 todo. ALL PHASES COMPLETE.

## Phase 15: v3 Backports — PENDING

- [x] JPEG streaming (JPEGStreamInit/Feed/Complete — from v3 Phase 17)
- [x] PNG support — pngdecr.pas + LoadPNG (pngdecraw.pas — from v3 Phase 17)
- [x] FLAC decoder — flacdec.pas in wav/ (flacdec.pas — from v3 codecs)
- [x] MP3 decoder — mp3dec.pas in wav/ (mp3dec.pas — from v3 codecs)
- [x] WAV streaming implementation (WAVStreamInit/Feed/Stop/IsPlaying — state tracking)
- [x] Audio codec wiring — pcmdecraw/pcmmix/wavplay in wav/ (pcmdecraw/pcmmix/wavplay integration)
