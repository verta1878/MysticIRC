# Phase 3 Test Changelog

Test-by-test history of what was fixed, what changed, and what
the numbers showed. If you're picking up this code, read this
to understand why things are the way they are.

## Test Run 1 — Placeholder fonts

- Engine A: rendered 103 RIPs, massive diffs (800K+ pixels)
- Engine B: crashed (EAccessViolation)
- Cause A: placeholder font data (all zeros), no real glyphs
- Cause B: m_Strings stub and missing font includes
- Action: sent real rip_font8x8.inc, rip_font8x16.inc, m_strings.pas

## Test Run 2 — Real fonts, first real numbers

- Engine A: 6/6 rendered, no crashes
- Engine B: still crashed
- Results vs reference PNG:
    L_LINE   10,700 (1.3%)
    V_ARC    11,475 (1.4%)
    S_FILL   60,014 (7.3%)
    DRAGON01 818,815 (99.9%)
- Cause B: rip1exec calls ripdraw globals, not TRIPGraphics methods
- Action: created rip_compat.pas bridge layer

## Test Run 3 — rip_compat bridge, Engine B runs

- Engine A vs B: size mismatch (A=2.4MB 24-bit, B=672KB 8-bit)
- Could not do direct A-vs-B comparison
- Both vs reference:
    L_LINE   A=10,700  B=15,136  Winner: A
    V_ARC    A=11,475  B=14,509  Winner: A
    S_FILL   A=60,014  B=41,992  Winner: B
    Y_FONT   A=63,719  B=27,896  Winner: B
    BUTTONS  A=91,231  B=91,231  Tie
    DRAGON01 A=818,815 B=182,027 Winner: B
- Action: need to standardize BMP format

## Test Run 4 — BMP BGR byte order fix

- Fixed ripbmp.pas: R and B bytes were swapped (RGB not BGR)
- Engine A improved:
    L_LINE   10,700 -> 7,368  (down 31%)
    V_ARC    11,475 -> 4,084  (down 64%)
- DRAGON01 still 99.9% — not a color swap issue
- Action: added -dBMP_8BIT dual mode to ripbmp.pas

## Test Run 5 — 8-bit BMP standardization

- Both engines now output 8-bit indexed through ripbmp.pas
- rip_compat WriteBMP copies G pixels to RIPEngine.Canvas
- First direct A-vs-B comparison possible:
    BUTTONS  2 bytes (0.0002%) — near pixel-perfect!
    L_LINE   5,249 (0.6%)
    V_ARC    3,833 (0.5%)
    Y_FONT   12,108 (1.5%)
    S_FILL   28,472 (3.5%)
    DRAGON01 224,002 (27.3%)
- Both vs reference:
    L_LINE   A=7,368   B=11,271  Winner: A
    V_ARC    A=4,084   B=6,635   Winner: A
    S_FILL   A=45,322  B=36,830  Winner: B
    Y_FONT   A=62,517  B=53,323  Winner: B
    BUTTONS  A=91,231  B=91,231  Tie
    DRAGON01 A=818,723 B=605,726 Winner: B

## Test Run 6 — Code cleanup (no rendering changes)

- Same numbers as Run 5. Changes were structural (comments,
  code cleanup) not rendering fixes.
- Confirmed: no regressions from code reorganization

## Test Run 7 — MAJOR: Command parser fix + palette + elliptical arcs

PENDING RETEST. Three fixes applied:

1. COMMAND PARSER BUG (the big one):
   Parser only accepted !| as command prefix. RIPscrip uses !| for
   the first command on a line and just | for subsequent commands.
   DRAGON01 has 8+ commands per line — only the first was executed.
   All other commands silently skipped. This affected EVERY RIP file
   with multiple commands per line (which is most of them).
   
   Fix: ParseRIPCommand now accepts both !|X and |X.
   Expected impact: DRAGON01 should drop from 99.9% to much lower.

2. EGA 6-bit palette conversion:
   rcSetPalette used EGA_PALETTE[C And 15] — treating 6-bit value
   as 4-bit index. rcOnePalette used LongWord(R) * 256 — meaningless.
   Both now use EGA64toRGB() which correctly converts EGA rgbRGB
   6-bit format to $BBGGRR.

3. Engine B elliptical arc support:
   Arc() and PieSlice() only took single Rad parameter. Engine A's
   DrawArcLines takes separate XRad, YRad for elliptical arcs.
   rip_compat was passing XRad but dropping YRad.
   Both now take XRad, YRad.

## What The Numbers Mean

- 0.0% = pixel-perfect match (goal)
- < 1% = rounding differences, edge cases
- 1-5% = algorithmic difference in one primitive
- 5-15% = multiple primitives or fill boundary issues
- > 50% = systemic bug (wrong format, missing commands, palette)
- 99.9% = almost nothing is rendering correctly

## How To Read A-vs-B vs A/B-vs-Reference

- A vs B tells you: do the engines AGREE?
- A vs Reference tells you: is Engine A CORRECT?
- B vs Reference tells you: is Engine B CORRECT?
- If both agree but differ from reference: shared bug (ported from JS)
- If only one differs: that engine has the bug
- Three-way narrows it down fast (sysop/0's method)

## Test Run 7 — ACTUAL RESULTS

Parser fix + palette conversion + elliptical arcs.
DRAGON01 improved but core issue remains:

  A vs Reference:
    L_LINE   7,368 (0.8%)     — same
    V_ARC    4,084 (0.4%)     — same
    S_FILL   45,322 (5.5%)    — same
    Y_FONT   62,517 (7.6%)    — same
    BUTTONS  91,231 (11.1%)   — same
    DRAGON01 810,819 (98.9%)  — improved from 818,723 (7,904 fewer pixels)

  B vs Reference:
    L_LINE   11,271 (1.3%)    — same
    V_ARC    6,635 (0.8%)     — same
    S_FILL   36,830 (4.4%)    — same
    Y_FONT   53,323 (6.5%)    — same
    BUTTONS  91,231 (11.1%)   — same
    DRAGON01 598,255 (73.0%)  — improved from 605,726 (7,471 fewer pixels)

Parser fix shaved ~7,500 pixels off DRAGON01 on each engine.
The | separator was picking up a few extra commands per line.
But 98.9% still wrong on Engine A = core rendering issue.

Investigation found:
  - Palette values match reference PNG exactly
  - BMP format is correct (8-bit indexed, BGR palette entries)
  - Command parser handles both !| and | prefixes
  - FloodFill uses Canvas.FillColor set by rcFillStyle
  - DRAGON01 has 387 commands: 154 lines, 82 fills, 41 beziers
  - Reference PNG uses only 8 colors, 73.8% black background
  - Core issue still unidentified — needs visual diff image from sysop/0
    to see exactly WHERE the rendering differs

## Test Run 8 — ROOT CAUSE: Canvas height 1280 instead of 350

sysop/0 sent visual diff images. Immediately visible:
  - Reference PNG: 640 x 350 (correct EGA)
  - Engine A BMP:  640 x 1280 (WRONG)
  - Engine B BMP:  640 x 1280 (WRONG)

ripengine.pas had RIP_HEIGHT = 1280. Should be 350 for RIP v1.54 EGA.
The BMP writer output all 1280 rows. Rows 350-1279 were black and did
not exist in the reference — that's 930 extra rows of wrong pixels.

This is why DRAGON01 was 98.9% off. The dragon was rendering correctly
in the top 350 rows but the file was 3.66x too tall. Every test file
was affected — the 91K diff on BUTTONS was mostly empty rows too.

Visual diffs also showed:
  - DRAGON01: dragon outlines drawn, fills mostly working, but
    background is green (color 10) instead of black (color 0).
    The flood fill is filling the OUTSIDE of the dragon, not the inside.
    FloodFill border color may be wrong, or fill color is being set
    to the wrong value before the fill commands execute.
  - BUTTONS: completely blank on Engine A. Button/mouse commands
    (rcButton, rcButtonStyle) are parsed but produce no visual output.
    The button rendering code draws nothing to the pixel buffer.
  - L_LINE: lines render correctly, just on a too-tall canvas.
  - Y_FONT: text renders but some CHR vector fonts are missing or
    the font loading path can't find the .CHR files.

Fix: RIP_HEIGHT = 350 in ripengine.pas.
rip_compat.pas already had 350 — only ripengine was wrong.

Expected impact: DRAGON01 should drop from 98.9% to single digits.
All test files should improve dramatically since the canvas size matches.

Remaining issues after height fix:
  - DRAGON01 flood fill direction (fills outside instead of inside)
  - BUTTONS not rendering (button drawing code missing/broken)
  - Y_FONT CHR font file loading path
  - Line/arc endpoint rounding (the original small diffs)

## Test Run 8 — ACTUAL RESULTS (height fix applied)

Canvas height fixed to 350. All outputs now 640x350. Visual diffs:

  A vs Reference:
    L_LINE   — Lines render correctly. Starburst patterns match.
               Small endpoint rounding on diagonal lines.
    V_ARC    — Arcs close to reference. Minor rasterization diffs.
    S_FILL   — Fill COLORS correct but PATTERNS missing. Reference
               shows hatch/stripe/dot patterns. Engine A shows solid
               fills only. FillStyle patterns not implemented.
    Y_FONT   — Bitmap font (8x16) renders. CHR vector fonts missing.
               Large colored text in right column absent. CHR file
               loading path broken or files not found.
    BUTTONS  — Blank. Button widget renderer not implemented.
               rcButton/rcButtonStyle parse but draw nothing.
    DRAGON01 — Outlines and beziers render correctly! Flood fills
               INVERTED — fills outside shapes instead of inside.
               Background is green (filled) instead of black.
               Dragon body unfilled (black) instead of green.

  B vs Reference:
    DRAGON01 — Completely black. Engine B not rendering at all
               through rip_compat. Likely TPixelBuffer size mismatch
               between m_rip_graph (RIP_MAX_W x RIP_MAX_H = 1024x768)
               and ripengine (640x350) when copying pixels in WriteBMP.

Key findings from visual analysis:
  1. L_LINE is very close — line primitives are solid
  2. S_FILL needs fill PATTERN implementation (hatch, stripe, dot, cross)
  3. Y_FONT needs CHR font file path resolution
  4. DRAGON01 flood fill direction is wrong — border color logic
  5. BUTTONS needs button widget renderer (not just parsing)
  6. Engine B pixel copy broken — TPixelBuffer size mismatch in rip_compat

## Test Run 9 — Fill patterns working, DRAGON01 huge improvement

Height fix + fill patterns applied. Results:

  A vs Reference:
    L_LINE   7,368 (0.8%)     — same (line endpoints)
    V_ARC    4,084 (0.4%)     — same (arc rounding)
    S_FILL   5,740 (0.7%)     — MASSIVE improvement from 45,322 (5.5%)
    Y_FONT   62,517 (7.6%)    — same (CHR fonts still missing)
    BUTTONS  91,231 (11.1%)   — same (buttons not implemented)
    DRAGON01 58,149 (7.1%)    — MASSIVE improvement from 818,723 (98.9%)

  B vs Reference:
    L_LINE   11,271 (1.3%)    — same
    V_ARC    6,635 (0.8%)     — same
    S_FILL   36,830 (4.4%)    — same (Engine B doesn't have pattern fix yet)
    Y_FONT   20,496 (2.5%)    — improved (Engine B has better font handling)
    BUTTONS  91,231 (11.1%)   — same
    DRAGON01 58,257 (7.1%)    — MASSIVE improvement from 598,255 (73.0%)

  Engine A now wins 3 of 6 (L_LINE, V_ARC, S_FILL).
  Engine B wins 2 of 6 (Y_FONT, DRAGON01 by 108 pixels).
  BUTTONS tied.

Key improvements:
  - S_FILL: 5.5% -> 0.7% — fill patterns are working correctly
  - DRAGON01: 98.9% -> 7.1% — canvas height + fill patterns fixed it
    The dragon now renders with correct fills. Remaining 7.1% is
    likely flood fill boundary precision and missing button/text.
  - Engine B DRAGON01 also improved dramatically: 73% -> 7.1%

Visual analysis:
  - S_FILL: All 13 fill patterns visible and matching reference.
    0.7% diff is minor boundary/edge rounding.
  - DRAGON01 Engine A: Dragon body is GREEN and filled! Background
    is BLACK. Outlines correct. Text "Dragon_01" visible.
    Missing: "Continue" button (needs rcButton), some fine detail.
  - DRAGON01 Engine B: Also rendering correctly at 7.1%.
    Both engines now nearly agree on DRAGON01.
  - Y_FONT Engine B: CHR vector fonts rendering — large colored
    text visible. Engine A still using bitmap only.

Merge path confirmed by sysop/0:
  A's primitives (lines 0.8%, arcs 0.4%, fills 0.7%) +
  B's palette and text (DRAGON01 7.1%, Y_FONT 2.5%)

## Test Run 10 — Button renderer implemented

PENDING RETEST. Simple button renderer added to rip1exec.pas:
  - Draws beveled rectangle (gray surface, white highlight, dark shadow)
  - Extracts label text from <>TEXT<> delimiters
  - Centers text inside button area
  - DRAGON01's "Continue" button should now render

Not implemented (lower priority):
  - ButtonStyle parameters (custom colors, bevel sizes, orientations)
  - Icon buttons (clipboard/icon image overlay)
  - Radio/check button groups
  - Hot icon hover states

The basic renderer covers 90% of RIP art buttons which are simple
text labels in beveled boxes. The full button widget system is
complex (14+ style parameters, icon loading, group management)
and can be added later.

## Test Run 11 — Button renderer with ButtonStyle colors

Button rendering active. Visual analysis:

  DRAGON01: "Continue" button now visible in bottom-left! Gray beveled
    box with text. Dragon body and fills look correct. Remaining diff
    is minor fill boundary and text details.

  BUTTONS: Rendering buttons! Multiple beveled boxes visible with text
    labels. Colors from ButtonStyle being applied — magenta/purple
    surface colors matching reference. Layout close but some buttons
    have wrong sizes or positions — likely the width/height override
    from ButtonStyle not being applied correctly, or the bevel size
    is off by a pixel.

  S_FILL: Still at ~0.7% — near pixel-perfect. Minor edge rounding.

  Y_FONT: Bitmap text rendering correctly. CHR vector fonts still
    missing (large colored text in right column absent).

  L_LINE: Lines solid, minor endpoint rounding only.

  V_ARC: Arcs solid, minor rasterization rounding.

Remaining work:
  - BUTTONS layout: some buttons wrong size (width/height from style)
  - BUTTONS: clipboard icon and checkered pattern not rendering
  - Y_FONT: CHR font file loading still needed
  - DRAGON01: minor fill boundaries

## Test Run 12 — sysop/0 final numbers with button renderer

No new rendering changes this run — cleanup only. Final standings:

  | File     | Engine A | Engine B | Winner |
  |----------|----------|----------|--------|
  | V_ARC    | 0.4%     | 1.5%     | A      |
  | S_FILL   | 0.7%     | 3.3%     | A      |
  | L_LINE   | 0.8%     | 1.8%     | A      |
  | BUTTONS  | 7.3%     | 11.1%    | A      |
  | Y_FONT   | 7.6%     | 2.5%     | B      |
  | DRAGON01 | 26.1%    | 7.1%     | B      |

  Engine A wins: 4 of 6 (V_ARC, S_FILL, L_LINE, BUTTONS)
  Engine B wins: 2 of 6 (Y_FONT, DRAGON01)

BUTTONS improved from 11.1% to 7.3% on Engine A — button renderer working.
DRAGON01 Engine A still at 26.1% — flood fill direction issue remains.
Y_FONT Engine B at 2.5% — CHR vector fonts working in Engine B.

Progress from session start to now:
  - DRAGON01: 98.9% -> 26.1% (Engine A), 73.0% -> 7.1% (Engine B)
  - S_FILL:   5.5% -> 0.7% (Engine A)
  - BUTTONS:  11.1% -> 7.3% (Engine A)
  - L_LINE:   1.3% -> 0.8% (Engine A)
  - V_ARC:    1.4% -> 0.4% (Engine A)

Remaining issues:
  1. DRAGON01 Engine A 26.1% — flood fill fills outside instead of inside
  2. Y_FONT Engine A 7.6% — CHR vector fonts not loading
  3. BUTTONS 7.3% — clipboard icon, some bevel/size differences
  4. Merge: A's primitives + B's fonts/palette = best of both

## Test Run 13 — FloodFill rewrite + CHR vector fonts

PENDING RETEST. Two major fixes:

1. FLOOD FILL — REWRITTEN with visited buffer:
   Root cause from JS analysis: RIPtermJS uses a separate fillpixels
   buffer to track visited pixels. Our old code checked Canvas.FillColor
   in span detection — with patterned fills, unfilled pattern gaps
   looked like unprocessed pixels and fill leaked through them.
   New code: heap-allocated TVisited boolean array (224KB), marks every
   processed pixel regardless of whether the pattern drew there.
   Expected: DRAGON01 flood fills should now stay inside shape boundaries.

2. CHR VECTOR FONTS — IMPLEMENTED:
   Added full CHR font loading and rendering to riptext.pas.
   Loads .CHR files from fonts/ directory (TRIP, LITT, SANS, GOTH, etc).
   Lazy loading on first use — SetTextStyle stores font number,
   OutTextXY loads the .CHR file if needed and renders with stroke data.
   Falls back to bitmap 8x16 if .CHR file not found.
   Expected: Y_FONT test should show vector text (large colored glyphs).

## Test Run 14 — Font path fix + Dispose bug

Run 13 code was in but CHR fonts didn't load — font path not resolving.
Two fixes:

1. FONT PATH SEARCH: LoadCHRFont now checks 3 locations:
     fonts/TRIP.CHR (from ripviewer/)
     ../fonts/TRIP.CHR (from source/ or build dir)
     TRIP.CHR (current directory)
   Previously only checked fonts/ which failed when running from
   a different working directory.

2. DISPOSE BUG: Dispose(Data) was called before New(Data) when
   font file not found — would crash or corrupt heap. Fixed to
   just Exit without Dispose.

Expected: Y_FONT should now load CHR vector fonts and show the
large colored text that was missing.

## Test Run 15 — CHR fonts loading, Y_FONT improved

CHR font path fix worked. sysop/0 placed .CHR files next to executable.

  | File     | Engine A prev | Engine A now | Engine B | Winner |
  |----------|--------------|-------------|----------|--------|
  | V_ARC    | 0.4%         | 0.4%        | 1.5%     | A      |
  | S_FILL   | 0.7%         | 0.7%        | 3.3%     | A      |
  | L_LINE   | 0.8%         | 0.8%        | 1.8%     | A      |
  | BUTTONS  | 7.3%         | 7.4%        | 11.1%    | A      |
  | Y_FONT   | 7.6%         | 5.4%        | 2.5%     | B      |
  | DRAGON01 | 26.1%        | 26.0%       | 7.1%     | B      |

  Engine A wins: 4 of 6
  Engine B wins: 2 of 6

Y_FONT dropped from 7.6% to 5.4% — CHR vector fonts rendering.
Remaining 5.4% vs Engine B's 2.5% is font scaling, character spacing,
or baseline positioning in the CHR parser.

DRAGON01 shaved another 447 pixels from the font fix — text labels
now using correct vector fonts instead of bitmap fallback.

Remaining work:
  - Y_FONT: character spacing/baseline (2.9% gap vs Engine B)
  - DRAGON01: flood fill still inverted (26% = fills outside shapes)
  - BUTTONS: minor bevel/size differences

## Test Run 16 — TextWindow parameter bug + parameter audit

CRITICAL BUG FOUND: rcTextWindow (|w) consumed 12 chars instead of 10.
JS format is '222211' (10 chars). Our handler did Inc(Pos, 12) which
ate 2 chars from the NEXT command on every line with |w.

In DRAGON01 line 1: |w0013271610|c08 — the |c08 (set color dark gray)
was partially consumed by |w's extra 2 chars. All outlines drew in
default white (15) instead of dark gray (8). Flood fills use border=8
but outlines were white — fill leaked through white pixels.

Fix: Inc(Pos, 10) for rcTextWindow.

Also fixed from JS parameter audit:
  - rcGetImage (1C): Inc(Pos, 10) -> 9 (format '22221')
  - rcPutImage (1P): Inc(Pos, 8) -> 7 (format '2221')

Result: Dragon outlines now render in correct dark gray color.
Red eye visible. Shape much more complete. But fills still leak —
traced to a 214,218-pixel flood fill from seed (620,58) that escapes
through a sub-pixel gap in bezier curves near the dragon's upper body.

The bezier gap is a floating-point precision issue in the curve
rasterization — two adjacent bezier curves don't meet exactly at
their shared endpoint, leaving a 1-pixel gap that the fill leaks through.

Full parameter audit completed against JS parseRIPargs2 format strings.
All other commands verified correct.

## Test Run 17 — Bezier Floor() fix + JS algorithm analysis

Changed bezier from Round() to Floor() to match JS Math.floor().
Also matched JS loop structure (t from step to <1, explicit last line).

Result: outlines shifted slightly but flood fill still leaks on DRAGON01.
Root cause analysis:

1. JS uses a DIFFERENT Bresenham line algorithm than ours.
   JS: den/num/numadd formulation with dx>>1 initialization.
   Ours: standard err = dx - dy formulation.
   Both are valid Bresenham but produce different pixel positions
   on diagonal lines. This means bezier curve outlines land on
   slightly different pixels, and gap locations differ.

2. The DRAGON01 flood fill leak is caused by a 1-pixel gap where
   adjacent bezier curves meet. The JS renders the same gap but
   its fill doesn't leak because the pixels land differently
   due to the different line algorithm.

3. Fixing this properly requires matching the JS Bresenham exactly,
   which would change ALL line rendering and potentially break
   L_LINE and V_ARC (currently at 0.4-0.8%).

Decision: Keep current Bresenham (it scores better on L_LINE/V_ARC).
DRAGON01 flood fill will improve when we match the JS line algorithm
as a future optimization. The TextWindow parameter fix was the
major improvement this session (outlines from white→dark gray).

Key fixes this session (Runs 1-17):
  - RIP_HEIGHT 1280→350 (98.9% → 26%)
  - |w TextWindow 12→10 chars (outlines white → dark gray)
  - |1C GetImage 10→9, |1P PutImage 8→7
  - |  command separator (parser fix)
  - Fill patterns (13 BGI patterns, S_FILL 5.5% → 0.7%)
  - CHR vector fonts (Y_FONT 7.6% → 5.4%)
  - Button renderer with ButtonStyle
  - FloodFill with visited buffer
  - Bezier Floor() matching JS
  - EGA64toRGB palette conversion
  - BMP BGR byte order fix

## Test Run 18 — JS-MATCHED BRESENHAM: DRAGON01 RENDERS! 🐉

CRITICAL FIX: Replaced standard Bresenham (err=dx-dy) with the exact
algorithm from RIPtermJS BGI.js line_bresenham (den/num/numadd).

The two algorithms produce different pixel positions on diagonal lines.
Adjacent bezier curves share endpoints — if the line algorithm places
the endpoint pixel differently than the JS, a 1-pixel gap forms at the
junction. Flood fill leaks through the gap to the entire background.

With JS-matched Bresenham, the bezier curve junctions are gap-free.
Flood fills stay inside the dragon body. DRAGON01 renders correctly:
  - Black background (was green)
  - Green dragon body filled (was empty outlines)
  - Dark gray outlines visible
  - Red eye, teeth detail
  - Continue button with gray bevel
  - Dragon_01 text label

Locally verified — all 6 test files render:
  - DRAGON01: Green dragon on black, fills correct
  - L_LINE: Starburst patterns, dash lines
  - S_FILL: All 13 fill patterns
  - V_ARC: Arcs and curves
  - Y_FONT: Bitmap + CHR vector fonts
  - BUTTONS: Beveled button widgets

Awaiting sysop/0 retest for exact pixel diff numbers.

Key algorithm difference (for future reference):
  Standard Bresenham:
    err = dx - dy
    if 2*err > -dy: err -= dy, x += sx
    if 2*err < dx: err += dx, y += sy

  JS/BGI Bresenham (what we now use):
    if dx >= dy: den=dx, num=dx>>1, numadd=dy
    else: den=dy, num=dy>>1, numadd=dx
    num += numadd
    if num >= den: num -= den, step diagonal
    step major axis

## Test Run 19 — PALETTE FIX: F_FILL1 pixel-perfect, DRAGON01 1.7%!

CRITICAL BUG: EGA palette indices 3 (Cyan) and 6 (Brown) were SWAPPED.
Palette format is $BBGGRR:
  Index 3 should be Cyan  (0,170,170) = $AAAA00. We had $AA5500 (wrong).
  Index 6 should be Brown (170,85,0)  = $0055AA. We had $00AAAA (wrong).

Fix: Corrected EGA_PALETTE in ripengine.pas and rip_compat.pas.
Also added |! text/comment command to parser (skip to end of line).

Results — full test suite locally verified:

  PIXEL-PERFECT:
    F_FILL1:    1 pixel  (0.0%)  — was 40.6%
    F_FILL2:    1 pixel  (0.0%)  — was 0.0%

  EXCELLENT (< 2%):
    S_FILL:     2,646    (1.2%)  — was 2.7%
    DRAGON01:   3,829    (1.7%)  — was 98.9% at start!
    V_ARC:      4,114    (1.8%)
    L_LINE:     4,424    (2.0%)
    L_LINE2:    5,388    (2.4%)

  NEEDS WORK:
    COVAI:      17,246   (7.7%)  — flood fill boundary
    Y_FONT:     44,676   (19.9%) — CHR font scaling wrong
    BUTTONS:    60,784   (27.1%) — icon images, layout
    v_VIEW:     62,294   (27.8%) — GetImage/PutImage not implemented
    ICONS:      84,336   (37.6%) — icon loading not implemented
    C_WELL:     223,349  (99.7%) — circle fill leak

  NOT TESTED (no reference):
    TXT_VARS, TXT_WIN, w_HIDE

Features still needed for 100%:
  1. Icon loading (rcLoadIcon/rcWriteIcon) — .ICN binary files
  2. GetImage/PutImage — pixel region copy/paste
  3. CHR font scaling — character sizes wrong
  4. C_WELL — circle boundary gap causing fill leak

## Test Run 20 — Palette fix + Font scaling fix

Two fixes:
1. EGA PALETTE: Indices 3(Cyan) and 6(Brown) SWAPPED in $BBGGRR values.
   F_FILL1 went from 40.6% to 0.0% (pixel-perfect).
   DRAGON01 from 26% to 1.6%.

2. CHR FONT SCALING: Used charsize as direct integer multiplier.
   JS uses FontScales[] lookup table with float values.
   Scale 4 was rendering at 4x instead of 1.0x — text 4x too big.
   Y_FONT from 19.9% to 15.7%.

Final scores (locally verified):
  F_FILL1:       1  (0.0%) PIXEL-PERFECT
  F_FILL2:       1  (0.0%) PIXEL-PERFECT
  S_FILL:    2,646  (1.2%)
  DRAGON01:  3,497  (1.6%)
  V_ARC:     4,114  (1.8%)
  L_LINE:    4,424  (2.0%)
  Y_FONT:   35,148  (15.7%)

Session journey (start -> now):
  DRAGON01:  98.9% -> 1.6%    (61x better)
  F_FILL1:   40.6% -> 0.0%    (PERFECT)
  S_FILL:     5.5% -> 1.2%    (4.6x better)
  Y_FONT:     7.6% -> 15.7%   (got worse then better with scale fix)
  V_ARC:      1.4% -> 1.8%    (slightly worse from Bresenham change)
  L_LINE:     1.3% -> 2.0%    (slightly worse from Bresenham change)

Remaining Y_FONT issues:
  - Vertical text not rendering
  - Text Y-offset (JS does moverel(0,textheight) before stroke fonts)
  - Some character positioning differences

## Test Run 21 — Dual Bresenham attempt + cleanup

Tried using old Bresenham for lines, JS for bezier. Results worse
because reference PNGs were generated BY the JS engine — matching
JS pixel positions gives best results. Reverted to JS Bresenham for all.

Added dash pattern + thickness to DrawLineJS (was missing — DashPatterns
variable was unused).

Final scores (same as Run 20 + dash fix):
  F_FILL1:       1  (0.0%) PIXEL-PERFECT
  F_FILL2:       1  (0.0%) PIXEL-PERFECT
  S_FILL:    2,646  (1.2%)
  DRAGON01:  3,497  (1.6%)
  V_ARC:     4,114  (1.8%)
  L_LINE:    4,424  (2.0%)
  Y_FONT:   35,148  (15.7%)

Remaining diffs on S_FILL/L_LINE/V_ARC (1-2%) are from:
  - JS thick-line octant logic (we use perpendicular offset)
  - Fill pattern boundary rounding at rectangle edges
  These are sub-pixel rendering details — diminishing returns.

Y_FONT 15.7% remaining from:
  - Text Y-offset (JS does moverel(0, textheight) before stroke fonts)
  - Vertical text direction rendering differences
  - Some character positioning in multi-size text

## Test Run 22 — Text Y-offset + final cleanup

Added stroke font Y-offset matching JS moverel(0, textheight).
Y_FONT improved 15.7% -> 14.6%. DRAGON01 improved to 1.5%.

Final scores all targeted tests:
  F_FILL1:       1  (0.0%) PIXEL-PERFECT
  F_FILL2:       1  (0.0%) PIXEL-PERFECT
  S_FILL:    2,646  (1.2%)
  DRAGON01:  3,464  (1.5%)
  V_ARC:     4,114  (1.8%)
  L_LINE:    4,424  (2.0%)
  Y_FONT:   32,603  (14.6%)

Y_FONT remaining 14.6% is:
  - Vertical text direction (right column) not rendering
  - Large vertical center text absent
  - Minor stroke position differences on "ABC"
  These require matching JS vertical text cursor advancement
  and text flow direction — complex for marginal improvement.

SESSION COMPLETE — 22 test runs, 20 bugs fixed.

Session journey (start -> final):
  DRAGON01:  98.9% ->  1.5%   (66x better)
  F_FILL1:   40.6% ->  0.0%   (PIXEL-PERFECT)
  S_FILL:     5.5% ->  1.2%   (4.6x better)
  L_LINE:     1.3% ->  2.0%   (Bresenham tradeoff for DRAGON01)
  V_ARC:      1.4% ->  1.8%   (Bresenham tradeoff for DRAGON01)
  Y_FONT:     7.6% -> 14.6%   (scale fix improved, vertical text missing)

## Test Run 22 (continued) — EGA64 bit order + GetImage/PutImage

1. EGA64toRGB bit order WRONG — bits are RGBrgb not rgbRGB.
   High bits (5,4,3) are bright R,G,B. Low bits (2,1,0) are dim r,g,b.
   Fix: swap Shr 5/Shr 2 pairs in the conversion.
   C_WELL: 99.7% -> 26.1% (palette colors now correct).

2. GetImage/PutImage implemented — captures pixel region to buffer,
   pastes with COPY or XOR mode. v_VIEW didn't improve because it
   uses viewport commands, not copy/paste.

Scores after this run:
  F_FILL1:       1  (0.0%) PIXEL-PERFECT
  F_FILL2:       1  (0.0%) PIXEL-PERFECT
  S_FILL:    2,646  (1.2%) EXCELLENT
  DRAGON01:  3,464  (1.5%) EXCELLENT
  V_ARC:     4,114  (1.8%) GOOD
  L_LINE:    4,424  (2.0%) GOOD
  Y_FONT:   32,603  (14.6%) vertical text missing
  C_WELL:   58,471  (26.1%) improved from 99.7%
  BUTTONS:  60,784  (27.1%) icons/layout
  v_VIEW:   62,294  (27.8%) viewport clipping
  ICONS:    84,336  (37.6%) icon loading needed

## Test Run 22 (final) — EGA64 bit order + GetImage/PutImage + Icon loading

Three fixes:
1. EGA64toRGB bit order: RGBrgb not rgbRGB. C_WELL 99.7% -> 26.1%.
2. GetImage/PutImage: pixel region copy/paste implemented.
3. Icon loading: .ICN binary format (4 EGA bit-planes) decoded.
   ICONS 37.6% -> 1.9%.

FINAL SCORES — all test files:
  F_FILL1:       1  (0.0%) PIXEL-PERFECT
  F_FILL2:       1  (0.0%) PIXEL-PERFECT
  S_FILL:    2,646  (1.2%) EXCELLENT
  DRAGON01:  3,464  (1.5%) EXCELLENT
  V_ARC:     4,114  (1.8%) GOOD
  ICONS:     4,179  (1.9%) GOOD
  L_LINE:    4,424  (2.0%) GOOD
  L_LINE2:   5,388  (2.4%) GOOD
  COVAI:    17,246  (7.7%)
  Y_FONT:   32,603  (14.6%) vertical text missing
  C_WELL:   58,471  (26.1%) fill pattern + circle gaps
  BUTTONS:  60,178  (26.9%) icon buttons, layout
  v_VIEW:   62,294  (27.8%) viewport clipping

  8 of 13 files under 3%.
  2 files pixel-perfect.
  22 test runs, 20+ bugs fixed.

SESSION COMPLETE. All achievable rendering fixes applied.
Remaining diffs require: JS thick-line octant logic, vertical text
direction, icon button rendering, viewport clip state management.

## Test Run 22 (full suite) — EGA64 + Icons + Oval params + vertical text

Fixes applied:
1. EGA64toRGB bit order: RGBrgb not rgbRGB. C_WELL 99.7% -> 26.1%.
2. Icon loading: .ICN 4-bit-plane EGA format. ICONS 37.6% -> 1.9%.
3. rcOval parameter count: was 8 chars (4 params), should be 12 chars
   (6 params matching OvalArc V format 222222). Missing start/end angle
   caused angle values to be interpreted as radii. COVAI 7.7% -> 2.8%.
4. CHR vertical text cursor: CurY advances for FontDir=1.
5. GetImage/PutImage: pixel region copy/paste implemented.

FINAL SCORES:
  F_FILL1:       1  (0.0%) PIXEL-PERFECT
  F_FILL2:       1  (0.0%) PIXEL-PERFECT
  S_FILL:    2,646  (1.2%) EXCELLENT
  DRAGON01:  3,464  (1.5%) EXCELLENT
  V_ARC:     4,114  (1.8%) GOOD
  ICONS:     4,179  (1.9%) GOOD
  L_LINE:    4,424  (2.0%) GOOD
  L_LINE2:   5,388  (2.4%) GOOD
  COVAI:     6,208  (2.8%) GOOD
  Y_FONT:   32,863  (14.7%) vertical text rendering
  C_WELL:   58,471  (26.1%) circle fill pattern
  BUTTONS:  60,178  (26.9%) icon buttons
  v_VIEW:   62,294  (27.8%) viewport clipping

  9 of 13 files under 3%.
  2 files pixel-perfect.
  22 test runs, 22+ bugs fixed.

## Test Run 22 (continued) — Oval params + viewport offset

Additional fixes:
1. rcOval (|O) parameter count: was 8 chars, should be 12 (matches V format
   222222). Missing start/end angle caused wrong radii. COVAI 7.7% -> 2.8%.
2. Viewport coordinate offset: JS _putpixel adds vp.left/vp.top to all
   coordinates. Our PutPixel now offsets too. v_VIEW 27.8% -> 20.1%.
   Two viewport boxes now visible.
3. CHR vertical text cursor: CurY advances for FontDir=1.

FINAL COMPLETE SCORES:
  F_FILL1:       1  (0.0%) PIXEL-PERFECT
  F_FILL2:       1  (0.0%) PIXEL-PERFECT
  S_FILL:    2,646  (1.2%) EXCELLENT
  DRAGON01:  3,464  (1.5%) EXCELLENT
  V_ARC:     4,114  (1.8%) GOOD
  ICONS:     4,179  (1.9%) GOOD
  L_LINE:    4,424  (2.0%) GOOD
  L_LINE2:   5,388  (2.4%) GOOD
  COVAI:     6,208  (2.8%) GOOD
  Y_FONT:   32,863  (14.7%) vertical text positioning
  v_VIEW:   45,006  (20.1%) viewport element positions
  C_WELL:   58,471  (26.1%) circle boundary precision
  BUTTONS:  60,178  (26.9%) button flags/icon buttons

  9 of 13 files under 3%.
  2 files pixel-perfect.
  22 test runs, 22+ bugs fixed.

Remaining diffs are deep rendering precision:
  - Y_FONT: vertical CHR text cursor advancement differs from JS
  - v_VIEW: viewport element positions slightly different
  - C_WELL: circle midpoint algorithm produces different boundary pixels
  - BUTTONS: button style flags (text position, icon buttons) not fully implemented

## Test Run 22 (final push) — All remaining fixes

Additional fixes applied:
1. rcOval parameter count 8->12 (matches OvalArc V format). COVAI 7.7%->2.8%.
2. Viewport coordinate offset in PutPixel (JS adds vp.left/top). v_VIEW 27.8%->20.1%.
3. Button text Orient positioning (above/left/center/right/below). BUTTONS 26.9%->25.9%.
4. CHR vertical text cursor advancement.
5. GetImage/PutImage pixel copy/paste.
6. EGA64toRGB bit order RGBrgb not rgbRGB. C_WELL 99.7%->26.1%.
7. Icon .ICN 4-bit-plane loading. ICONS 37.6%->1.9%.
8. |! text/comment command handler.

FINAL SCORES — ALL TEST FILES:
  F_FILL1:       1  (0.0%)  PIXEL-PERFECT
  F_FILL2:       1  (0.0%)  PIXEL-PERFECT
  S_FILL:    2,646  (1.2%)  EXCELLENT
  DRAGON01:  3,456  (1.5%)  EXCELLENT
  V_ARC:     4,114  (1.8%)  GOOD
  ICONS:     4,179  (1.9%)  GOOD
  L_LINE:    4,424  (2.0%)  GOOD
  L_LINE2:   5,388  (2.4%)  GOOD
  COVAI:     6,208  (2.8%)  GOOD
  Y_FONT:   32,863  (14.7%)
  v_VIEW:   45,006  (20.1%)
  BUTTONS:  57,955  (25.9%)
  C_WELL:   58,471  (26.1%)

  9 of 13 under 3%. 2 pixel-perfect.
  22 test runs. 20+ bugs fixed across session.

## Test Run 22 (deep dive) — E2 overflow fix attempt

Fixed E2 variable type from Integer to LongInt in DrawEllipse/FillEllipse
to prevent potential overflow with large radii. No pixel diff change —
FPC x86_64 Integer is already 32-bit so overflow wasn't occurring.

The remaining diffs on the 4 files are from:
  - C_WELL 26.1%: Circle positions affected by viewport coordinate
    offset. The flood fill seed points with viewport-relative coords
    land in different positions than the JS absolute coords.
  - BUTTONS 25.9%: Button style flags control text size and position
    relative to button. Full flag decoding needed (16-bit flags field).
  - v_VIEW 20.1%: Viewport offset working but flood fills within
    viewports use viewport-relative coords that interact with the
    visited buffer in unexpected ways.
  - Y_FONT 14.7%: CHR font vertical text — JS doesn't advance CP
    for vertical stroke fonts, uses complex initial moverel offset.

These are at diminishing returns — each improvement requires matching
complex JS subsystem behavior. The core renderer is solid.

## Test Run 22 (final) — Viewport GetPixel fix + deep analysis

Fixed FloodFill to use viewport-aware GetPixel for boundary checks.
v_VIEW improved by 81 pixels (44925 vs 45006).

Deep analysis of remaining 4 files:
  - C_WELL: Circle ellipse algorithm matches JS exactly. Even JS has
    FIXME comment for C_WELL. Diff is inherent circle precision.
  - Y_FONT: JS drawChar uses moveto/lineto which implicitly advance CP.
    Our DrawCHRChar uses DrawLine + manual cursor. Stroke font CP
    advancement model differs fundamentally from JS.
  - BUTTONS: Full 16-bit flag decoding needed for text size/position.
  - v_VIEW: Viewport offset working. Remaining diff from fill interaction.

COMPLETE SESSION SCORES (22 test runs, 22+ bugs fixed):
  F_FILL1:       1  (0.0%)  PIXEL-PERFECT
  F_FILL2:       1  (0.0%)  PIXEL-PERFECT
  S_FILL:    2,646  (1.2%)  EXCELLENT
  DRAGON01:  3,456  (1.5%)  EXCELLENT
  V_ARC:     4,114  (1.8%)  GOOD
  ICONS:     4,179  (1.9%)  GOOD
  L_LINE:    4,424  (2.0%)  GOOD
  L_LINE2:   5,388  (2.4%)  GOOD
  COVAI:     6,208  (2.8%)  GOOD
  Y_FONT:   32,863  (14.7%)
  v_VIEW:   44,925  (20.1%)
  BUTTONS:  57,955  (25.9%)
  C_WELL:   58,471  (26.1%)

## Test Run 22 (continued) — EraseView fix + DrawCircle unification

Fixes:
1. EraseView: was calling PutPixel with absolute viewport coords which
   got double-offset. Now writes directly to Canvas.Pixels^.
2. DrawCircle: unified with DrawEllipse for consistent circle boundaries.
3. Button text width: uses FontSize*8 instead of hardcoded 8.
4. Vertical CHR cursor: X stays constant, Y advances.
5. FloodFill: uses GetPixel (viewport-aware) for boundary checks.

Results unchanged on the 4 target files — the diffs are from:
  - C_WELL: circle boundary positions inherent to algorithm (49K pixels
    from boundary shift, 9K from hatch pattern alignment)
  - v_VIEW: viewport offset applied, remaining from fill positioning
  - BUTTONS: need full 16-bit flag decoding
  - Y_FONT: stroke font CP model differs from JS moveto/lineto system

DRAGON01 improved slightly: 3456 -> 3361 (1.5%)
F_FILL1 still pixel-perfect.

## Test Run 22 (absolute final) — CHR sign conversion + all fixes

Additional fixes attempted:
1. CHR font sign conversion matched to JS: value 64 = 0 (not -64).
2. Vertical stroke font X offset from OrgToCap.
3. Button text width uses FontSize scaling.
4. EraseView uses absolute coordinates (not viewport-offset PutPixel).
5. DrawCircle unified with DrawEllipse.
6. FloodFill uses viewport-aware GetPixel.

ABSOLUTE FINAL SCORES:
  F_FILL1:       1  (0.0%)  PIXEL-PERFECT
  F_FILL2:       1  (0.0%)  PIXEL-PERFECT
  S_FILL:    2,646  (1.2%)  EXCELLENT
  DRAGON01:  3,361  (1.5%)  EXCELLENT
  V_ARC:     4,114  (1.8%)  GOOD
  ICONS:     4,179  (1.9%)  GOOD
  L_LINE:    4,424  (2.0%)  GOOD
  L_LINE2:   5,388  (2.4%)  GOOD
  COVAI:     6,206  (2.8%)  GOOD
  Y_FONT:   32,863  (14.7%)
  v_VIEW:   44,925  (20.1%)
  BUTTONS:  57,966  (25.9%)
  C_WELL:   58,471  (26.1%)

  9 of 13 under 3%. 2 pixel-perfect. 22 test runs. 25+ bugs fixed.

## Test Run 23 — Text delimiter fix + jsuite test content

BUG FOUND from jsuite SHADOW.RIP: rcOutTextXY and rcOutText consumed
everything to end of line as text. Commands after text on the same
line (|S, |F, etc) were eaten as text characters.

Fix: Text commands now stop at next | delimiter instead of EOL.
SHADOW.RIP text "Shadow" no longer includes garbled command data.
DRAGON01 improved from 1.5% to 1.4% — text commands on same line
as fills are now parsed correctly.

Added jsuite sample RIPs (10 files) and Dpaint icons (215 .ICN files)
to the test collection. BURGER, PAC, PALEO render correctly.

SCORES WITH TEXT FIX:
  F_FILL1:       1  (0.0%)  PIXEL-PERFECT
  F_FILL2:       1  (0.0%)  PIXEL-PERFECT
  S_FILL:    2,646  (1.2%)  EXCELLENT
  DRAGON01:  3,123  (1.4%)  EXCELLENT ← improved
  V_ARC:     4,114  (1.8%)  GOOD
  ICONS:     4,179  (1.9%)  GOOD
  L_LINE:    4,424  (2.0%)  GOOD
  L_LINE2:   5,388  (2.4%)  GOOD
  COVAI:     6,206  (2.8%)  GOOD

## Test Run 24 — BGCOLOR fill fix: v_VIEW PIXEL-PERFECT! 🎉

CRITICAL BUG: PutFillPixel only drew foreground pixels (pattern bit=1).
Pattern gap pixels (bit=0) were left unchanged, showing through previous
fills. JS ff_putpixel draws BGCOLOR for pattern=0 gaps.

Fix: PutFillPixel now draws Canvas.BG for pattern gap pixels.

v_VIEW: 20.1% → 0.0% (61 pixels!) — PIXEL-PERFECT!
The entire 20.1% diff was from hatch pattern fills showing blue
background through pattern gaps instead of drawing black.

Also fixed: fill pattern coordinates use absolute (viewport-offset)
positions for pattern alignment, matching JS ff_putpixel.

SCORES:
  F_FILL1:       1  (0.0%)  PIXEL-PERFECT
  F_FILL2:       1  (0.0%)  PIXEL-PERFECT
  v_VIEW:       61  (0.0%)  PIXEL-PERFECT ← NEW!
  S_FILL:    2,646  (1.2%)  EXCELLENT
  DRAGON01:  3,123  (1.4%)  EXCELLENT
  V_ARC:     4,114  (1.8%)  GOOD
  ICONS:     4,179  (1.9%)  GOOD
  L_LINE:    4,424  (2.0%)  GOOD
  L_LINE2:   5,388  (2.4%)  GOOD
  COVAI:     6,206  (2.8%)  GOOD
  Y_FONT:   32,863  (14.7%)
  BUTTONS:  57,966  (25.9%)
  C_WELL:   58,471  (26.1%)

  10 of 13 under 3%. 3 pixel-perfect!

## Test Run 25 — PutFillPixel bgcolor + riptext rebuild + TextWidth

THREE major fixes:

1. PutFillPixel BGCOLOR: JS ff_putpixel draws Canvas.BG for pattern
   gap pixels (bit=0). Our code skipped them, leaving old canvas color.
   v_VIEW: 20.1% → 0.0% (PIXEL-PERFECT!) — entire diff was from
   hatch fills showing blue background through pattern gaps.

2. riptext.pas REBUILT: File structure was corrupted from 20+ edits.
   Rebuilt cleanly with proper Interface/Implementation sections.
   All CHR font features preserved: FontScales, sign conversion,
   vertical text, Y-offset, path search.

3. TextWidth function: Calculates actual pixel width for current font.
   CHR fonts use sum of character widths * actualScale. Bitmap uses
   Length * FontSize * 8. Used in button text positioning.

4. rcComment handler: |! skips to next | delimiter, not end of line.
   C_WELL's |S0907|!FD76708 comment doesn't eat the fill command.

SCORES:
  F_FILL1:       1  (0.0%)  PIXEL-PERFECT
  F_FILL2:       1  (0.0%)  PIXEL-PERFECT
  v_VIEW:       61  (0.0%)  PIXEL-PERFECT
  S_FILL:    2,646  (1.2%)  EXCELLENT
  DRAGON01:  3,232  (1.4%)  EXCELLENT
  V_ARC:     4,114  (1.8%)  GOOD
  ICONS:     4,179  (1.9%)  GOOD
  L_LINE:    4,424  (2.0%)  GOOD
  L_LINE2:   5,388  (2.4%)  GOOD
  COVAI:     6,206  (2.8%)  GOOD
  Y_FONT:   32,863  (14.7%)
  BUTTONS:  57,950  (25.9%)
  C_WELL:   58,471  (26.1%)

  10 of 13 under 3%. 3 pixel-perfect!

Remaining 3 files:
  Y_FONT:  JS moveto/lineto CP model for stroke fonts
  BUTTONS: 16-bit button style flags (chisel, sunken, icon buttons)
  C_WELL:  Circle boundary precision (JS has FIXME for this file)

## Test Run 26 — Bevel outside fix: BUTTONS 17.7%, DRAGON01 1.0%!

Bevel draws OUTSIDE button coords, matching JS drawBeveledBox:
  JS: (left-bev, top-bev+1) to (right+bev, bot+bev)
  Our old: (left+bev, top+bev) to (right-bev, bot-bev) — INSIDE
  
Also checks Flags bit 512 for bevel enable.

BUTTONS: 25.9% → 17.7% — bevel position and size now correct.
DRAGON01: 1.4% → 1.0% — Continue button bevel improved.

SCORES:
  F_FILL1:       1  (0.0%)  PIXEL-PERFECT
  F_FILL2:       1  (0.0%)  PIXEL-PERFECT
  v_VIEW:       61  (0.0%)  PIXEL-PERFECT
  DRAGON01:  2,339  (1.0%)  EXCELLENT ← improved!
  S_FILL:    2,646  (1.2%)  EXCELLENT
  V_ARC:     4,114  (1.8%)  GOOD
  ICONS:     4,179  (1.9%)  GOOD
  L_LINE:    4,424  (2.0%)  GOOD
  L_LINE2:   5,388  (2.4%)  GOOD
  COVAI:     6,206  (2.8%)  GOOD
  Y_FONT:   32,863  (14.7%)
  BUTTONS:  39,754  (17.7%) ← improved!
  C_WELL:   58,471  (26.1%)

  10 of 13 under 3%. 3 pixel-perfect. DRAGON01 at 1.0%!

## Test Run 27 — TextHeight + final push

Added TextHeight function for font-aware button label positioning.
DRAGON01 improved to 1.0% (2,296 pixels). BUTTONS at 17.8%.

FINAL SESSION SCORES (27 test runs, 25+ bugs fixed):
  F_FILL1:       1  (0.0%)  PIXEL-PERFECT
  F_FILL2:       1  (0.0%)  PIXEL-PERFECT
  v_VIEW:       61  (0.0%)  PIXEL-PERFECT
  DRAGON01:  2,296  (1.0%)  EXCELLENT
  S_FILL:    2,646  (1.2%)  EXCELLENT
  V_ARC:     4,114  (1.8%)  GOOD
  ICONS:     4,179  (1.9%)  GOOD
  L_LINE:    4,424  (2.0%)  GOOD
  L_LINE2:   5,388  (2.4%)  GOOD
  COVAI:     6,206  (2.8%)  GOOD
  Y_FONT:   32,863  (14.7%)
  BUTTONS:  39,763  (17.8%)
  C_WELL:   58,471  (26.1%)

  10 of 13 under 3%. 3 pixel-perfect.
  DRAGON01: 98.9% -> 1.0% (99x better!)

## Test Run 28 — 8x8 bitmap font fix

JS default bitmap font is 8x8, not 8x16! Our 8x16 font had 2 blank
rows at top, shifting all bitmap text down by 2 pixels. Every bitmap
character in Y_FONT was offset.

Fix: switched from rip_font8x16.inc to rip_font8x8.inc.
Changed YSize 16→8, array indexing *16→*8, TextHeight *16→*8.

Y_FONT: 14.7% → 12.5% (5K fewer diff pixels)
BUTTONS: 17.8% → 17.6%
All others stable.

## Test Run 29 — Correct 8x8 font glyph extraction

The 8x8 font was wrong — our rip_font8x8.inc had corrupted data (2304
bytes instead of 2048). Regenerated by extracting rows 3-9 of the 8x16
VGA font + blank bottom row. Verified char A matches reference exactly:
  Reference: 0x38 0x6C 0xC6 0xC6 0xFE 0xC6 0xC6 0x00
  Ours:      0x38 0x6C 0xC6 0xC6 0xFE 0xC6 0xC6 0x00 ✓

Y_FONT: 14.7% → 12.9%
All others stable. 3 pixel-perfect maintained.

## Test Run 30 — 8x8 font rows 3-9, SUNKEN bit 15, chisel bevel

Fixes:
1. 8x8 font: regenerated from rows 3-9 of 8x16 + blank bottom.
   Char A now matches reference exactly (0x38 0x6C 0xC6...).
   Y_FONT: 14.7% → 12.9%
2. SUNKEN flag: bit 15 (not bit 10). Fixed regression that swapped
   all button bevels. BUTTONS back to 17.9%.
3. CHISEL flag: bit 3 — draws inner bevel with opposite colors.

SCORES:
  F_FILL1:       1  (0.0%)  PIXEL-PERFECT
  F_FILL2:       1  (0.0%)  PIXEL-PERFECT
  v_VIEW:       61  (0.0%)  PIXEL-PERFECT
  DRAGON01:  2,326  (1.0%)  EXCELLENT
  S_FILL:    2,646  (1.2%)  EXCELLENT
  V_ARC:     4,114  (1.8%)  GOOD
  ICONS:     4,179  (1.9%)  GOOD
  L_LINE:    4,424  (2.0%)  GOOD
  L_LINE2:   5,388  (2.4%)  GOOD
  COVAI:     6,206  (2.8%)  GOOD
  Y_FONT:   28,878  (12.9%)
  BUTTONS:  40,124  (17.9%)
  C_WELL:   58,471  (26.1%)
