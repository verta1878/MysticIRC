# Chess Piece Assets

Spectrum sprite package. The ASM asset is referenced by the current Spectrum
build.

- `chess_pieces_16x16.asm`: 24 public one-bit sprite labels for the Spectrum
  board, generated from `chess_pieces_16x16_onebit.zip/pieces.png`.
- Variant order is `white/light`, `white/dark`, `black/light`, `black/dark`.
- Piece order inside each variant is `K Q R B N P`.
- Source cells are already 16x16. Import is exact per-pixel: no threshold,
  scaling, smoothing, or redrawing.
- In the source atlas, the top row is black pieces and the bottom row is white
  pieces.
- The atlas has identical masks for `white/light == black/dark` and
  `white/dark == black/light`, so those pairs are label aliases instead of
  duplicated data.
- Each sprite is 16 rows x 16 pixels, stored as 32 bytes.
- Each row is two bytes, most-significant bit first, left to right.
- `1` bit means draw ink pixel. `0` bit means paper/background.

The current Spectrum renderer uses 16x16 pixel board squares, so these sprites
drop directly into the board path without rescaling. Compression is intentionally
disabled until the visual set is validated on hardware.
