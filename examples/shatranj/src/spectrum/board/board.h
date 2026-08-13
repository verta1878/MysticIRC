#ifndef NETCHESSZX_SPECTRUM_BOARD_H
#define NETCHESSZX_SPECTRUM_BOARD_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

void spectrum_board_reset(void);
void spectrum_board_clear(void);
uint8_t spectrum_board_is_legal_move(const char *move) NETCHESSZX_FASTCALL;
uint8_t spectrum_board_is_legal_move_coords(uint8_t from_idx, uint8_t to_idx);
#define SPECTRUM_BOARD_CHECK_NONE 0u
#define SPECTRUM_BOARD_CHECK 1u
#define SPECTRUM_BOARD_CHECK_MATE 2u
#define SPECTRUM_BOARD_STALEMATE 3u
typedef struct spectrum_board_snapshot {
    char cells[64];
    uint8_t side;
    uint8_t castle;
    int8_t ep;
} spectrum_board_snapshot_t;

typedef struct spectrum_board_undo {
    uint8_t from;
    uint8_t to;
    char captured;
    uint8_t castle;
    int8_t ep;
} spectrum_board_undo_t;

#define SPECTRUM_BOARD_UNDO_INDEX_MASK 0x3fu
#define SPECTRUM_BOARD_UNDO_PROMOTION 0x80u

typedef char spectrum_board_undo_size_check[
    sizeof(spectrum_board_undo_t) == 5u ? 1 : -1];

uint8_t spectrum_board_check_state(void);
void spectrum_board_clear_legal_hints(void);
void spectrum_board_show_legal_hints(uint8_t from_row, uint8_t from_col);
uint8_t spectrum_board_apply_trusted_move(const char *move) NETCHESSZX_FASTCALL;
uint8_t spectrum_board_apply_trusted_move_with_undo(
    const char *move, spectrum_board_undo_t *undo);
void spectrum_board_undo_restore(const spectrum_board_undo_t *undo)
    NETCHESSZX_FASTCALL;
void spectrum_board_snapshot_save(spectrum_board_snapshot_t *out) NETCHESSZX_FASTCALL;
void spectrum_board_snapshot_restore(const spectrum_board_snapshot_t *snapshot) NETCHESSZX_FASTCALL;
#ifdef NETCHESSZX_HOST_TEST
uint8_t spectrum_board_apply_move(const char *move) NETCHESSZX_FASTCALL;
#endif

/* Snapshot export for app-owned UI sync:
   64 sequential chars, row-major, row 0 = rank 8, col 0 = file A.
   Consumers may copy this buffer but must not cache or mutate it. */
const char *spectrum_board_cells(void);
char spectrum_board_cell(uint8_t row, uint8_t col);

#ifdef NETCHESSZX_HOST_TEST
void spectrum_board_test_set(const char cells[64],
                             uint8_t side,
                             uint8_t castle,
                             int8_t ep);
int8_t spectrum_board_test_rule_cell(uint8_t index);
#endif

#endif
