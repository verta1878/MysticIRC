# RIP Test Results

## How to Run

```bash
cd examples/ripviewer
fpc -Mdelphi -Fusource -Fusource/v1 source/ripview.pas -oripview

# Single file test
./ripview rips/test/F_FILL1.RIP /tmp/output.bmp

# Batch test
cd ../../mystic_rip
fpc -Mdelphi test_rip_files.pas
./test_rip_files ../examples/ripviewer/rips/test/

# Pixel comparison
compare -metric AE output.png reference.png /dev/null
```

## RIPview Results (Session 6 — 35 test runs)

| Test | Score | Status |
|------|-------|--------|
| F_FILL1 | 0.0% | PIXEL-PERFECT |
| F_FILL2 | 0.0% | PIXEL-PERFECT |
| v_VIEW | 0.0% | PIXEL-PERFECT |
| DRAGON01 | 0.8% | EXCELLENT |
| S_FILL | 1.2% | EXCELLENT |
| V_ARC | 1.8% | GOOD |
| ICONS | 1.9% | GOOD |
| L_LINE | 2.0% | GOOD |
| L_LINE2 | 2.4% | GOOD |
| COVAI | 2.8% | GOOD |
| Y_FONT | 11.4% | platform diff |
| BUTTONS | 17.9% | platform diff |
| C_WELL | 26.1% | JS FIXME |

## mterm Results (Session 6 — after gap closure)

| Test | Score | Status |
|------|-------|--------|
| F_FILL1 | 0.0% | PIXEL-PERFECT |
| F_FILL2 | 0.6% | GOOD |
| ICONS | 1.9% | matches ripviewer |
| DRAGON01 | 2.5% | GOOD |
| L_LINE | 4.7% | |
| V_ARC | 5.8% | |
| S_FILL | 7.9% | fixed (was 18.2%) |
| v_VIEW | 8.5% | fixed (was 81.4%) |
| COVAI | 9.8% | |

## ans2rip Pixel-Perfect Test

```bash
cd mystic_rip
fpc -Mdelphi ans2rip.pas ans2png.pas

# Pixel-perfect mode
./ans2rip -p test.ans test.rip
../examples/ripviewer/source/ripview test.rip /tmp/rip.bmp
./ans2png test.ans /tmp/ref.bmp
convert /tmp/rip.bmp -background black -extent 640x350 /tmp/rip350.png
convert /tmp/ref.bmp -background black -extent 640x350 /tmp/ref350.png
compare -metric AE /tmp/rip350.png /tmp/ref350.png /dev/null
# Result: 0 pixels difference
```

## Full 213 RIP Batch Test
- ZERO failures across all 213 RIP files
- Run with test_rip_files.pas
