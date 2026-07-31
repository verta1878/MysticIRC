# Phase 3 — Pixel-Perfect Engine Verification

## What This Is

Two RIP rendering engines exist. Both must produce identical
pixel output before we merge them. This test proves that.

- **Engine A (ripdraw)** — evga's proven engine, 42/42 pixel-perfect
- **Engine B (m_rip_graph)** — kiddo's experimental OOP engine

## Prerequisites

- fpc264irc compiler (or standard FPC)
- Run from `examples/ripviewer/` directory
- Test RIP files in `rips/` subdirectory

## Step 1 — Compile the comparator

```
fpc -Mdelphi ../../mystic_test/experimental/bmpcompare.pas -obmpcompare
```

## Step 2 — Compile Engine A (ripdraw — proven)

```
fpc -Mdelphi -Fusource -Fusource/v1 test_phase3.pas -ot_ripdraw
```

## Step 3 — Run Engine A

```
t_ripdraw
```

Reads every .rip in `rips/`, writes BMPs to `test-output-ripdraw/`.
You should see OK for each file.

## Step 4 — Compile Engine B (m_rip_graph — experimental)

```
fpc -Mdelphi -Fusource -Fusource/v1 -Fu../../mystic_test/experimental -Fi../../mdl -dEXPERIMENTAL_RIP test_phase3.pas -ot_mrgraph
```

Note: `-dEXPERIMENTAL_RIP` switches to kiddo's engine.

## Step 5 — Run Engine B

```
t_mrgraph
```

Same RIPs, BMPs go to `test-output-mrgraph/`.

## Step 6 — Compare every BMP pair

One at a time:
```
bmpcompare test-output-ripdraw/DRAGON01.bmp test-output-mrgraph/DRAGON01.bmp
```

Or all at once (DOS/Windows batch):
```
for %f in (test-output-ripdraw\*.bmp) do bmpcompare %f test-output-mrgraph\%~nxf
```

Or all at once (Linux/bash):
```
for f in test-output-ripdraw/*.bmp; do
  b=$(basename "$f")
  ./bmpcompare "$f" "test-output-mrgraph/$b"
done
```

## Expected Results

Every file should print:
```
PASS — pixel-perfect match (NNNN bytes)
```

Any file that prints:
```
FAIL — N bytes differ out of NNNN
```
means the engines render that RIP differently. Report which
file failed and how many bytes differ. We fix it before merging.

## What Happens Next

- All PASS → Phase 4: wire {$IFDEF EXPERIMENTAL_RIP} into mystic_test
- Any FAIL → debug the difference, fix, re-test

## Files

| File | Location | Purpose |
|------|----------|---------|
| test_phase3.pas | examples/ripviewer/ | Test program (both engines) |
| bmpcompare.pas | mystic_test/experimental/ | BMP byte comparator |
| ripdraw.pas | examples/ripviewer/source/ | Engine A (evga) |
| m_rip_graph.pas | mystic_test/experimental/ | Engine B (kiddo) |
| rips/ | examples/ripviewer/rips/ | 259 test RIP files |

## Credits

- evga/wrench — ripdraw.pas primitives, ripscr.pas CHR fonts
- kiddo — m_rip_graph.pas OOP wrapper
- Carl Gorringe — RIPtermJS (original pixel math reference)
- sysop/0 — architecture direction

o7
