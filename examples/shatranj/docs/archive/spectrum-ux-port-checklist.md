# Spectrum UX Port Checklist

Source of truth:
- Final mockup generator: `experiments/moves-panel-tap/tools/mockups/gen_moves_panel_tap.py`
- This document is the implementation contract. Do not rely on chat memory.
- Mark every item before closing the port.

Status tags:
- `[done]` implemented and visually accepted by user.
- `[check]` implemented, needs visual confirmation on Spectrum/emulator.
- `[todo]` not implemented.
- `[changed]` final decision differs from older mockup.

## Global Layout

- [done] Use `EDIT` to toggle taboption. No `T` key in final app.
- [done] Board flip from taboption `FLIP` toggles orientation.
- [done] Bottom status bar uses ikkle font.
- [done] Bottom status clock format is `[XX:XX]`.
- [done] Bottom status indicator appears at the far right of the status bar.
- [check] Green status indicator must sit inside the real banner/status badge shape, matching app style.
- [todo] Reconfirm board frame/coordinates match the real app exactly after later cursor/highlight changes.

## Top Banner, Timer, Turn Line

- [done] When taboption is visible, the 1-pixel line under the banner disappears.
- [done] Top timer line uses BRIGHT 0 to avoid visual collision with the bright banner.
- [done] Top timer is on row `2`, scan `2`, col64 `41`.
- [check] Timer must not repaint/flicker while taboption is open.
- [todo] Factor timer character renderer: keep wrappers for open/closed positions, share the ASM core.

### `BLACK TO MOVE` / `WHITE TO MOVE`

- [check] White turn text uses normal ikkle at col64 `51`, row `3`, scan `2`.
- [check] Black turn text uses a pixel-built inverted row, not a broad Spectrum attribute rectangle.
- [check] Black inverted rectangle geometry:
  - one pixel less at top and bottom (`y=1..6` within 8-pixel row);
  - two pixels less on the left edge per latest user correction;
  - no stray white pixels before `BLACK`;
  - no corruption of the top timer line.
- [check] Rebuild this as a dedicated pixel row blit from mockup logic, not by post-processing live screen bytes.

## Taboption

Mockup constants:
- Text: `ABOUT  DISCC  RECC  FLIP  THEME`
- Attr row: `2`
- Pixel width: `16` bytes
- Options: `(0,5)`, `(7,5)`, `(14,4)`, `(20,4)`, `(26,5)`
- Pixel offsets: `[2,0,0,0,0]`
- Compact offsets: `[0,-2,-4,-6,-8]`
- Highlight left pad: `1` pixel

Checklist:
- [check] Taboption appears under banner on `EDIT`.
- [check] Taboption hides on `EDIT`.
- [check] Option navigation works left/right.
- [check] `FLIP` action works.
- [todo] Verify ABOUT starts with the exact final +1px correction and does not touch the left border when selected.
- [todo] Verify cursor/highlight is pixel-based, not only attribute-cell based.
- [todo] Verify final spacing after `DISCC`/`RECC` naming change.
- [todo] Verify timer text on same line stays aligned one pixel higher, with free pixel below inside taboption band.
- [todo] Verify cursor movement does not repaint whole taboption.
- [todo] Verify timer update does not repaint whole taboption.

## Moves Panel

Mockup constants:
- Info panel byte col: `18`
- Info text col64: `37`
- White move col64: `37`
- Black move col64: `51`
- Move text width: `13`
- Header row: `5`, scan `2`
- Header icon y: `row * 8 + 1`
- Header white icon x: `149`
- Header black icon x: `205`
- Header white text col64: `40`
- Header black text col64: `54`
- Move rows: 6
- Move first absolute y: `49`
- Move vertical step: `6` pixels

Checklist:
- [done] `LAST MOVES` replaced by the WHITE/BLACK header.
- [check] Header uses paper white / ink black.
- [check] Header white box is trimmed by 1 pixel at the bottom.
- [check] WHITE uses hollow icon, BLACK uses filled icon.
- [check] Header icons use mockup header patterns:
  - white: `1E 21 21 21 1E`
  - black: `1E 3F 3F 3F 1E`
- [todo] Header icon + color label must be left-aligned inside each half with at least the final mockup margin.
- [todo] White label spacing from icon must equal black label spacing.
- [check] Moves render with absolute-y tight spacing: first `y=49`, step `6`, not one Spectrum character row per move.
- [check] Adding a move renders only the affected move line.
- [check] Moves scroll uses 6-pixel screen scroll, then renders only the new last line.
- [check] Confirm move distribution exactly 6 rows, with no overlap into CHAT.
- [todo] Confirm SAN/MOVE text length still fits with timestamp prefix.

## Chat Panel

Mockup constants:
- CHAT title col64: `37`
- CHAT title row: `11`, scan `2`
- CHAT hline y: `96`
- CHAT hline starts at the same left x as the MOVES header.
- Chat first absolute y: `102`
- Chat vertical step: `6` pixels
- Chat icon byte col: `18`
- Chat time col64: `39`
- Chat text col64: `45`
- Chat rows: 4 visible sample rows in mockup; final app target was reduced by one row vs previous real layout.

Checklist:
- [done] Remove `READY` pseudo-line from chat.
- [check] Chat uses ikkle font.
- [check] Chat icons use mockup small patterns:
  - white: `3C 42 42 42 3C`
  - black: `3C 7E 7E 7E 3C`
- [check] Chat lines use the same tight 6-pixel interline spacing as moves.
- [check] Chat lines start at `y=102`, closer to the CHAT separator than previous row-based renderer.
- [check] Icon-to-timestamp gap is 4 pixels / one ikkle character (`time col64=39`, `text col64=45`).
- [check] Chat scroll uses 6-pixel screen scroll, then renders only the new last line.
- [check] Verify text capacity improves after tight spacing and reduced icon gap.

## Board Cursor, Coordinates, Hints

Mockup constants:
- Board top row: `5`
- Board left byte col: `1`
- Square size: `16x16`
- Initial cursor row/col in mockup: row `6`, col `4`
- Active coord attr: `ATTR_STATUS` (`0x38`)
- Cursor mark attrs:
  - light square: `0x7D`
  - dark square: `0x45`

Mockup behavior:
- Active file letter uses paper white / ink black across both attribute cells of that column.
- Active rank number uses paper white / ink black across both attribute cells of that rank.
- Cursor mark is pixel border over the square:
  - outer 1-pixel border on all four sides;
  - selected square adds inner 1-pixel border;
  - no wraparound at board edges.

Checklist:
- [check] Implement active coordinate highlight for current cursor file/rank.
- [check] Restore previous coordinate attrs when cursor moves.
- [done] Cursor movement is bounded; no Pac-Man wraparound at board limits.
- [check] Cursor movement must be free over board, no row/column skipping.
- [check] Cursor/highlight system must not corrupt pieces.
- [check] Cursor/highlight system must not erase legal-move hints.
- [check] Cursor/highlight system must remain coherent when board is flipped.
- [todo] Legal hints root cause already fixed in `main`; verify no regression after UX port.
- [todo] Highlighting style in current code differs from mockup; replace with mockup border/coord system.

## Validation Before Merge

- [todo] Generate TAP and visually compare against mockup final.
- [todo] `make NO_COLOR=1 test`
- [todo] `make NO_COLOR=1 tap`
- [todo] `make NO_COLOR=1 module-guards`
- [todo] `make NO_COLOR=1 abi-check`
- [todo] `make NO_COLOR=1 size-check`
- [todo] `git diff --check`
- [todo] Split into small commits after visual acceptance.
