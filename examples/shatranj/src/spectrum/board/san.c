#include "spectrum/board/san.h"

#include "common/chess/move_coords.h"
#include "spectrum/board/board.h"

#define file_char(col) ((char)('a' + (col)))
#define rank_char(row) ((char)('8' - (row)))

static char *san_p;
static uint8_t san_len;

static char san_piece_letter(char piece)
{
    char up = (char)(piece & (char)0xdf);

    if (up == 'N' || up == 'B' || up == 'R' ||
        up == 'Q' || up == 'K') {
        return up;
    }
    return '\0';
}

static void san_put(char c)
{
    *san_p++ = c;
    ++san_len;
}

static uint8_t san_done(void)
{
    *san_p = '\0';
    return san_len;
}

static void append_disambiguation(char piece,
                                  uint8_t from_idx,
                                  uint8_t from_row,
                                  uint8_t from_col,
                                  uint8_t to_idx)
{
    const char *cells = spectrum_board_cells();
    uint8_t conflict = 0u;
    uint8_t same_file = 0u;
    uint8_t same_rank = 0u;
    uint8_t idx;

    for (idx = 0u; idx < 64u; ++idx) {
        if (idx == from_idx || cells[idx] != piece) {
            continue;
        }
        if (spectrum_board_is_legal_move_coords(idx, to_idx)) {
            conflict = 1u;
            if ((idx & 7u) == from_col) {
                same_file = 1u;
            }
            if ((idx >> 3) == from_row) {
                same_rank = 1u;
            }
        }
    }

    if (!conflict) {
        return;
    }
    if (!same_file) {
        san_put(file_char(from_col));
    } else if (!same_rank) {
        san_put(rank_char(from_row));
    } else {
        san_put(file_char(from_col));
        san_put(rank_char(from_row));
    }
}

uint8_t spectrum_board_move_san_base(const char *move, char *out)
{
    const char *cells;
    uint16_t coords;
    uint8_t from_row;
    uint8_t from_col;
    uint8_t to_row;
    uint8_t to_col;
    uint8_t from_idx;
    uint8_t to_idx;
    uint8_t pawn;
    uint8_t capture;
    uint8_t king;
    char piece;
    char target;
    char letter;

    if (move == (const char *)0 || out == (char *)0) {
        return 0u;
    }
    san_p = out;
    san_len = 0u;
    *san_p = '\0';

    coords = netchesszx_move_parse_coords(move);
    if (coords == NETCHESSZX_MOVE_COORDS_INVALID) {
        return 0u;
    }
    if (move[4] != '\0' && move[5] != '\0') {
        return 0u;
    }

    cells = spectrum_board_cells();
    from_idx = NETCHESSZX_MOVE_FROM_INDEX(coords);
    to_idx = NETCHESSZX_MOVE_TO_INDEX(coords);
    from_row = (uint8_t)(from_idx >> 3);
    from_col = (uint8_t)(from_idx & 7u);
    to_row = (uint8_t)(to_idx >> 3);
    to_col = (uint8_t)(to_idx & 7u);
    piece = cells[from_idx];
    if (piece == '.') {
        return 0u;
    }

    king = (uint8_t)(piece == 'K' || piece == 'k');
    if (king && from_col == 4u && (to_col == 6u || to_col == 2u)) {
        san_put('O');
        san_put('-');
        san_put('O');
        if (to_col == 2u) {
            san_put('-');
            san_put('O');
        }
        return san_done();
    }

    pawn = (uint8_t)(piece == 'P' || piece == 'p');
    target = cells[to_idx];
    capture = (uint8_t)(target != '.' || (pawn && from_col != to_col));

    if (pawn) {
        if (capture) {
            san_put(file_char(from_col));
        }
    } else {
        letter = san_piece_letter(piece);
        if (letter == '\0') {
            return 0u;
        }
        san_put(letter);
        if (!king) {
            append_disambiguation(piece, from_idx, from_row, from_col, to_idx);
        }
    }

    if (capture) {
        san_put('x');
    }
    san_put(file_char(to_col));
    san_put(rank_char(to_row));

    if (move[4] != '\0') {
        letter = san_piece_letter(move[4]);
        if (letter == '\0') {
            return 0u;
        }
        san_put('=');
        san_put(letter);
    }

    return san_done();
}

uint8_t spectrum_board_san_append_suffix(char *san) NETCHESSZX_FASTCALL
{
    char *p;
    uint8_t state;

    if (san == (char *)0) {
        return 0u;
    }
    state = spectrum_board_check_state();
    if (state != SPECTRUM_BOARD_CHECK && state != SPECTRUM_BOARD_CHECK_MATE) {
        return state;
    }
    p = san;
    while (*p != '\0') {
        ++p;
    }
    if (p != san && (p[-1] == '+' || p[-1] == '#')) {
        return state;
    }
    *p++ = state == SPECTRUM_BOARD_CHECK_MATE ? '#' : '+';
    *p = '\0';
    return state;
}
