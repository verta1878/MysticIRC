# mterm RIP Engine — Phase MT-6: Debug & Fix (COMPLETE)

## Compile Check — PASSED
- mtripgfx.pas: compiles clean (0 errors, 0 warnings)
- mtrip.pas: compiles clean (0 errors, 0 warnings)
- mtrip_test.pas: links clean

## API Fixes Applied
- FCurX/FCurY: added CurX/CurY properties (public)
- PutPixelRaw/GetPixelRaw: moved to public section
- mtterm dependency: removed (not needed by RIP engine)
- ButtonStyle fields: added Btn* properties (public)

## Code Audit Fixes
- Removed unused FFileCache, FBuf, FCacheCount fields
- FClipData reduced from 1024x768 to 640x350 (786KB → 224KB)
- ClearFileCache removed (unused)
- Compiles clean with zero errors, zero warnings

## Smoke Test Results

| Test | Before | After | Status |
|------|--------|-------|--------|
| F_FILL1 | 0.0% | **0.0%** | PIXEL-PERFECT |
| F_FILL2 | 0.6% | **0.6%** | GOOD |
| v_VIEW | 81.4% | **8.5%** | ✅ FloodFill viewport fix |
| S_FILL | 18.2% | **7.9%** | ✅ Bar fill patterns |
| DRAGON01 | 2.5% | **2.5%** | GOOD |
| ICONS | 1.9% | **1.9%** | GOOD (matches ripviewer) |
| L_LINE | 4.7% | **4.7%** | Line dash patterns |
| V_ARC | 5.8% | **5.8%** | Arc precision |
| COVAI | 9.8% | **9.8%** | EGA palette |
| Y_FONT | 12.2% | **12.2%** | Platform diff |
| C_WELL | 26.8% | **26.8%** | Circle precision |
| BUTTONS | 41.0% | **42.4%** | ButtonStyle offset |

## Bug Fixes Applied
1. FloodFill viewport coordinate mismatch — rewrote with proper
   viewport-relative iteration and absolute pixel access
2. Bar() fill patterns — now uses FillPatterns + bgcolor for gaps
3. Line() dash patterns — added FLineStyle pattern check
4. SetViewport/EraseView — new methods wired to |v and |e commands
5. PutPixel/GetPixel viewport offset — adds FViewX1/FViewY1
6. ButtonStyle record — |1B parsing with bevel rendering
7. LoadIcon filename offset — was 11, fixed to 10 (format 22212*)
8. EraseWindow — now erases viewport, not entire canvas
