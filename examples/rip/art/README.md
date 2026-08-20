# RIP Test Corpus

100 RIPscrip v1.54 files from 16colo.rs artpacks.
Source: https://16colo.rs/tags/content/ripscrip

Downloaded via: https://16colo.rs/pack/{pack}/raw/{file}.RIP

## Test Results (2026-08-18)

- Engine: mtrip.pas + mtripgfx.pas
- Test tool: mtrip_test
- Result: 100/100 render without crash
- Visual verification: NOT DONE (needs pixel comparison)

## Command Usage in Corpus

| Command | Count | Status |
|---------|-------|--------|
| X (Pixel) | 36,004 | ✅ |
| c (Color) | 24,952 | ✅ |
| L (Line) | 6,977 | ✅ |
| p (Filled Polygon) | 1,263 | ✅ |
| l (Polyline) | 277 | ⚠️ BUG — mapped to LineStyle |
| S (Fill Style) | 225 | ✅ |
| = (Line Style) | 97 | ✅ |
| * (Reset) | many | ✅ |
| o (Filled Oval) | 52 | ✅ |
| a (One Palette) | 13 | ✅ |
| @ (TextXY) | 11 | ✅ |
| W (Write Mode) | 8 | ❌ MISSING — used in 99/100 files |
| Q (Set Palette) | 6 | ✅ |
| Z (Bezier) | 6 | ✅ |
| V (Oval Arc) | used in GOD-*.RIP | ❌ MISSING |
| Y (Font Style) | 3 | ✅ |
| 1K (Kill Mouse) | 8 | ✅ |
| w (Text Window) | 1 | ✅ |

## Key Findings

1. **|W (Write Mode) is critical** — used in first line of 99/100 files (|W00 = copy mode)
2. **|V (Oval Arc) is used** — GOD-*.RIP files from fire-34 pack use thousands
3. **|l is polyline not line style** — our mapping is wrong, 277 uses affected
4. Flood fill accuracy untested — need pixel comparison vs RIPterm/SyncTERM
5. No BGI font testing — no files in corpus use vector fonts extensively

## Packs Represented

ACiD, fire, mist, blender, CIA, echo, avenge, avpack, atb, surge, synth,
trip, blade, rile, phat, rca, and others.
