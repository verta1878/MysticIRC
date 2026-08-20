# RIPscrip v1.54 Engine — Implementation Phases

## Phase 1: Screen State Management — COMPLETE

- [x] SaveScreen(0-9) / RestoreScreen(0-9) — 10 pixel buffer slots (224KB each)
- [x] SaveTextWin / RestoreTextWin
- [x] SaveMouseAll / RestoreMouseAll
- [x] SaveClip / RestoreClip
- [x] SaveAll / RestoreAll
- [x] 15 action text variables ($SAVE$, $RESTORE$, $STW$, etc)

## Phase 2: Icon Masks and Highlights — COMPLETE

- [x] .MSK mask file loading (BGI GetImage format, AND mask)
- [x] LoadIconMasked (icon + mask rendering for transparency)
- [x] .HIC highlighted icon loading (hover/selected state)
- [x] DrawButtonEx: hot-icon mode (ICN normal, HIC selected)
- [x] DrawButtonEx: radio button group behavior (one per group)
- [x] DrawButtonEx: checkbox toggle behavior
- [x] InvertRegion: XOR all pixels with $0F (INVERT flag)

## Phase 3: Pre-defined Text Variables — COMPLETE

- [x] System info: $DATE$, $TIME$, $RUNDATE$, $RUNTIME$
- [x] Screen state: $CURX$, $CURY$, $CURSOR$
- [x] Text window: $TWH$, $TWW$, $TWX0$-$TWY1$, $TWWIN$, $TWFONT$
- [x] Sound: $ALARM$, $PHASER$, $REVPHASER$ (no-op server-side)
- [x] Mode control: $HKEYON$/$HKEYOFF$, $TABON$/$TABOFF$, etc
- [x] ExpandVars — $VARNAME$ expansion in OutText/OutTextXY
- [x] User variable persistence (save/load database file)

## Phase 4: Image Format Support — COMPLETE

- [x] PCX loading (16-color EGA 640x350, RLE decode)
- [x] PCX as splash screen / logo overlay
- [x] BMP loading (in addition to existing SaveBMP)
- [x] Heap-based clipboard (variable size Get/PutImage)

## Phase 5: Advanced Button System — COMPLETE

- [x] Full TRIPButtonStyle rendering (all 14 parameters)
- [x] Button label with underline hotkey character
- [x] Button group management (radio: one selected per group)
- [x] Checkbox state tracking (toggle on click)
- [x] Button hotkey system (keyboard char -> button activation)
- [x] Tab navigation through button/mouse fields

## Phase 6: System Font Modes — COMPLETE

- [x] 80x43 mode (8x8 font, default)
- [x] 80x25 mode (8x14 font)
- [x] 40x25 mode (16x14 font, double-width)
- [x] 91x43 mode (7x8 font)
- [x] 91x25 mode (7x14 font)
- [x] Font switching via SetTextStyle / $SYSFONT$
- [x] Text window reflow on font change

## Phase 7: Parser and Viewer Updates — COMPLETE

- [x] RIP_Viewer: wire Phase 4-6 engine APIs to parser events
- [x] RIP_Parser: text variable trigger events
- [x] Icon path fallback search (BBS subdir -> ICONS/)
- [x] Text variable expansion in OnTextCmd / OnTextXY
- [x] ripview: test harness for all phases
- [x] Test with real RIPterm154 scenes

## Phase 8: Documentation — COMPLETE

- [x] Update ripscript.doc/txt/htm with all new APIs
- [x] Document MSK/HIC file formats
- [x] Document PCX loading constraints
- [x] Document pre-defined text variable list (all 103)
- [x] Document button system flags and behavior
- [x] Update mystic/whatsnew.txt
- [x] Update README.md files

## Summary

Phases 1-3: COMPLETE (20/21 items, 1 deferred)
Phases 4-8: PENDING (34 items)
Total: 20 done, 35 todo
