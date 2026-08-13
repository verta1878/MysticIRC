#include "spectrum/board/board.h"
#include "common/chess/move_coords.h"
#include "spectrum/lowram_map.h"
#include <string.h>
#ifndef NETCHESSZX_HOST_TEST
#include "spectrum/overlay/overlay.h"
#else
#include "common/chess/rules_compact.h"
#endif

#define NETCHESSZX_RULE_EMPTY 0
#define NETCHESSZX_RULE_WHITE 0u
#define NETCHESSZX_RULE_BLACK 1u
#define NETCHESSZX_RULE_WP 1
#define NETCHESSZX_RULE_WN 2
#define NETCHESSZX_RULE_WB 3
#define NETCHESSZX_RULE_WR 4
#define NETCHESSZX_RULE_WQ 5
#define NETCHESSZX_RULE_WK 6
#define NETCHESSZX_RULE_BP -1
#define NETCHESSZX_RULE_BN -2
#define NETCHESSZX_RULE_BB -3
#define NETCHESSZX_RULE_BR -4
#define NETCHESSZX_RULE_BQ -5
#define NETCHESSZX_RULE_BK -6
#define NETCHESSZX_RULE_CASTLE_WK 1u
#define NETCHESSZX_RULE_CASTLE_WQ 2u
#define NETCHESSZX_RULE_CASTLE_BK 4u
#define NETCHESSZX_RULE_CASTLE_BQ 8u
#define NETCHESSZX_RULE_NO_SQUARE (-1)

#define NO_EP NETCHESSZX_RULE_NO_SQUARE

#define SPECTRUM_BOARD_CELL_COUNT 64u

#ifndef NETCHESSZX_HOST_TEST
#if SPECTRUM_BOARD_CELL_COUNT != NETCHESSZX_LOWRAM_BOARD_CELL_COUNT
#error "board cell count must match low-RAM map"
#endif
#if NETCHESSZX_LOWRAM_CHESS_BOARD_END != NETCHESSZX_LOWRAM_RULES_BOARD_ADDR
#error "chess_board export must stay 64 contiguous bytes"
#endif
#define chess_board ((char *)NETCHESSZX_LOWRAM_CHESS_BOARD_ADDR)
#define rules_board ((int8_t *)NETCHESSZX_LOWRAM_RULES_BOARD_ADDR)
#else
static char chess_board[SPECTRUM_BOARD_CELL_COUNT];
static int8_t rules_board[SPECTRUM_BOARD_CELL_COUNT];
typedef char chess_board_layout_guard[
    sizeof(chess_board) == SPECTRUM_BOARD_CELL_COUNT ? 1 : -1];
#endif
uint8_t side_to_move;
uint8_t castle_rights;
int8_t ep_square;

#ifdef NETCHESSZX_HOST_TEST
static uint8_t abs_delta(uint8_t a, uint8_t b)
{
    return a > b ? (uint8_t)(a - b) : (uint8_t)(b - a);
}

static uint8_t piece_side(char piece)
{
    return (uint8_t)(piece >= 'a' && piece <= 'z');
}
#endif

#ifdef NETCHESSZX_HOST_TEST
static int8_t rules_piece_from_char(char piece)
{
    static const char pieces[] = "PNBRQKpnbrqk";
    uint8_t i;

    for (i = 0u; i < sizeof(pieces) - 1u; ++i) {
        if (piece == pieces[i]) {
            return (i < 6u) ? (int8_t)(i + 1u) : (int8_t)(-(int8_t)(i - 5u));
        }
    }
    return NETCHESSZX_RULE_EMPTY;
}

static char promotion_piece(char pawn, char promo)
{
    if (promo == '\0') {
        promo = 'q';
    }

    if (pawn >= 'A' && pawn <= 'Z') {
        if (promo >= 'a' && promo <= 'z') {
            promo = (char)(promo - 'a' + 'A');
        }
    } else if (promo >= 'A' && promo <= 'Z') {
        promo = (char)(promo - 'A' + 'a');
    }

    return promo;
}
#endif

void spectrum_board_reset(void)
{
    static const char backrank[] = "rnbqkbnr";
    static const int8_t backrank_rules[] = {
        NETCHESSZX_RULE_BR, NETCHESSZX_RULE_BN,
        NETCHESSZX_RULE_BB, NETCHESSZX_RULE_BQ,
        NETCHESSZX_RULE_BK, NETCHESSZX_RULE_BB,
        NETCHESSZX_RULE_BN, NETCHESSZX_RULE_BR
    };
    uint8_t i;

    for (i = 0u; i < 64u; ++i) {
        uint8_t row = i >> 3;
        int8_t rule;
        if (row == 0u) {
            chess_board[i] = backrank[i & 7u];
            rule = backrank_rules[i & 7u];
        } else if (row == 1u) {
            chess_board[i] = 'p';
            rule = NETCHESSZX_RULE_BP;
        } else if (row == 6u) {
            chess_board[i] = 'P';
            rule = NETCHESSZX_RULE_WP;
        } else if (row == 7u) {
            chess_board[i] = (char)(backrank[i & 7u] & ~0x20u);
            /* Piece encoding is signed by side: white == -black. */
            rule = (int8_t)-backrank_rules[i & 7u];
        } else {
            chess_board[i] = '.';
            rule = NETCHESSZX_RULE_EMPTY;
        }
        rules_board[i] = rule;
    }
    side_to_move = NETCHESSZX_RULE_WHITE;
    castle_rights = NETCHESSZX_RULE_CASTLE_WK |
                    NETCHESSZX_RULE_CASTLE_WQ |
                    NETCHESSZX_RULE_CASTLE_BK |
                    NETCHESSZX_RULE_CASTLE_BQ;
    ep_square = NO_EP;
}

void spectrum_board_clear(void)
{
    uint8_t i;

    for (i = 0u; i < 64u; ++i) {
        chess_board[i] = '.';
        rules_board[i] = NETCHESSZX_RULE_EMPTY;
    }
    side_to_move = NETCHESSZX_RULE_WHITE;
    castle_rights = 0u;
    ep_square = NO_EP;
}

#ifdef NETCHESSZX_HOST_TEST
void spectrum_board_test_set(const char cells[64],
                             uint8_t side,
                             uint8_t castle,
                             int8_t ep)
{
    uint8_t i;

    for (i = 0u; i < 64u; ++i) {
        chess_board[i] = cells[i];
        rules_board[i] = rules_piece_from_char(cells[i]);
    }
    side_to_move = side;
    castle_rights = castle;
    ep_square = ep;
}

int8_t spectrum_board_test_rule_cell(uint8_t index)
{
    return index < 64u ? rules_board[index] : NETCHESSZX_RULE_EMPTY;
}
#endif

const char *spectrum_board_cells(void)
{
    return chess_board;
}

void spectrum_board_snapshot_save(spectrum_board_snapshot_t *out) NETCHESSZX_FASTCALL
{
#ifndef NETCHESSZX_HOST_TEST
    uint16_t addr = (uint16_t)out;

    spectrum_overlay_context[SPECTRUM_OVL_CTX_PTR_LO] = (uint8_t)addr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_PTR_HI] = (uint8_t)(addr >> 8);
    (void)spectrum_overlay_exec_cached(SPECTRUM_OVL_BOARD,
                                       SPECTRUM_OVL_BOARD_SNAPSHOT_SAVE);
#else
    memcpy(out->cells, chess_board, 64u);
    out->side = side_to_move;
    out->castle = castle_rights;
    out->ep = ep_square;
#endif
}

void spectrum_board_snapshot_restore(const spectrum_board_snapshot_t *snapshot) NETCHESSZX_FASTCALL
{
#ifndef NETCHESSZX_HOST_TEST
    uint16_t addr = (uint16_t)snapshot;

    spectrum_overlay_context[SPECTRUM_OVL_CTX_PTR_LO] = (uint8_t)addr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_PTR_HI] = (uint8_t)(addr >> 8);
    (void)spectrum_overlay_exec_cached(SPECTRUM_OVL_BOARD,
                                       SPECTRUM_OVL_BOARD_SNAPSHOT_RESTORE);
#else
    uint8_t i;

    memcpy(chess_board, snapshot->cells, 64u);
    for (i = 0u; i < 64u; ++i) {
        rules_board[i] = rules_piece_from_char(chess_board[i]);
    }
    side_to_move = snapshot->side;
    castle_rights = snapshot->castle;
    ep_square = snapshot->ep;
#endif
}

char spectrum_board_cell(uint8_t row, uint8_t col)
{
    if (row >= 8u || col >= 8u) {
        return '.';
    }
    return chess_board[(uint8_t)((row << 3) + col)];
}

uint8_t spectrum_board_is_legal_move_coords(uint8_t from_idx, uint8_t to_idx)
{
    if (from_idx >= 64u || to_idx >= 64u) {
        return 0u;
    }

#ifdef NETCHESSZX_HOST_TEST
    return netchesszx_compact_is_legal_move(rules_board,
                                            side_to_move,
                                            from_idx,
                                            to_idx,
                                            castle_rights,
                                            ep_square);
#else
    {
        uint16_t board_addr = (uint16_t)rules_board;

        spectrum_overlay_context[0] = (uint8_t)board_addr;
        spectrum_overlay_context[1] = (uint8_t)(board_addr >> 8);
        spectrum_overlay_context[2] = side_to_move;
        spectrum_overlay_context[3] = from_idx;
        spectrum_overlay_context[4] = to_idx;
        spectrum_overlay_context[5] = castle_rights;
        spectrum_overlay_context[6] = (uint8_t)ep_square;
    }
    return spectrum_overlay_exec_cached(SPECTRUM_OVL_RULES, SPECTRUM_OVL_RULES_PLAY);
#endif
}

uint8_t spectrum_board_is_legal_move(const char *move) NETCHESSZX_FASTCALL
{
    uint16_t coords;
    uint8_t to_row;
    uint8_t from_idx;
    uint8_t to_idx;
    char promo;
    char piece;

    coords = netchesszx_move_parse_coords(move);
    if (coords == NETCHESSZX_MOVE_COORDS_INVALID) {
        return 0u;
    }

    promo = move[4];
    if (promo >= 'A' && promo <= 'Z') {
        promo = (char)(promo - ('A' - 'a'));
    }
    if (promo != '\0') {
        if (move[5] != '\0' ||
            (promo != 'q' && promo != 'r' && promo != 'b' && promo != 'n')) {
            return 0u;
        }
    }

    from_idx = NETCHESSZX_MOVE_FROM_INDEX(coords);
    to_idx = NETCHESSZX_MOVE_TO_INDEX(coords);
    to_row = (uint8_t)(to_idx >> 3);
    piece = chess_board[from_idx];
    if (promo != '\0' && piece != 'P' && piece != 'p') {
        return 0u;
    }
    if (((piece == 'P' && to_row == 0u) ||
         (piece == 'p' && to_row == 7u)) &&
        promo == '\0') {
        return 0u;
    }
    if ((piece == 'P' && to_row != 0u) ||
        (piece == 'p' && to_row != 7u)) {
        if (promo != '\0') {
            return 0u;
        }
    }

    return spectrum_board_is_legal_move_coords(from_idx, to_idx);
}

uint8_t spectrum_board_check_state(void)
{
#ifdef NETCHESSZX_HOST_TEST
    return netchesszx_compact_check_state(rules_board,
                                          side_to_move,
                                          castle_rights,
                                          ep_square);
#else
    {
        uint16_t board_addr = (uint16_t)rules_board;

        spectrum_overlay_context[0] = (uint8_t)board_addr;
        spectrum_overlay_context[1] = (uint8_t)(board_addr >> 8);
        spectrum_overlay_context[2] = side_to_move;
        spectrum_overlay_context[3] = 0u;
        spectrum_overlay_context[4] = 0u;
        spectrum_overlay_context[5] = castle_rights;
        spectrum_overlay_context[6] = (uint8_t)ep_square;
    }
    return spectrum_overlay_exec_cached(SPECTRUM_OVL_RULES,
                                        SPECTRUM_OVL_RULES_CHECK);
#endif
}

#ifdef NETCHESSZX_HOST_TEST
static void clear_castle_rights(uint8_t from_idx, uint8_t to_idx,
                                char piece, char target)
{
    if (piece == 'K') {
        castle_rights &= (uint8_t)~(NETCHESSZX_RULE_CASTLE_WK |
                                    NETCHESSZX_RULE_CASTLE_WQ);
    } else if (piece == 'k') {
        castle_rights &= (uint8_t)~(NETCHESSZX_RULE_CASTLE_BK |
                                    NETCHESSZX_RULE_CASTLE_BQ);
    } else if (piece == 'R') {
        if (from_idx == 56u) {
            castle_rights &= (uint8_t)~NETCHESSZX_RULE_CASTLE_WQ;
        } else if (from_idx == 63u) {
            castle_rights &= (uint8_t)~NETCHESSZX_RULE_CASTLE_WK;
        }
    } else if (piece == 'r') {
        if (from_idx == 0u) {
            castle_rights &= (uint8_t)~NETCHESSZX_RULE_CASTLE_BQ;
        } else if (from_idx == 7u) {
            castle_rights &= (uint8_t)~NETCHESSZX_RULE_CASTLE_BK;
        }
    }

    if (target == 'R') {
        if (to_idx == 56u) {
            castle_rights &= (uint8_t)~NETCHESSZX_RULE_CASTLE_WQ;
        } else if (to_idx == 63u) {
            castle_rights &= (uint8_t)~NETCHESSZX_RULE_CASTLE_WK;
        }
    } else if (target == 'r') {
        if (to_idx == 0u) {
            castle_rights &= (uint8_t)~NETCHESSZX_RULE_CASTLE_BQ;
        } else if (to_idx == 7u) {
            castle_rights &= (uint8_t)~NETCHESSZX_RULE_CASTLE_BK;
        }
    }
}

static uint8_t apply_parsed_move(const char *move,
                                 uint8_t from_row, uint8_t from_col,
                                 uint8_t to_row, uint8_t to_col,
                                 spectrum_board_undo_t *undo)
{
    uint8_t from_idx = (uint8_t)((from_row << 3) + from_col);
    uint8_t to_idx = (uint8_t)((to_row << 3) + to_col);
    char piece = chess_board[from_idx];
    char target = chess_board[to_idx];
    uint8_t promotion = (uint8_t)((piece == 'P' && to_row == 0u) ||
                                  (piece == 'p' && to_row == 7u));

    if (piece == '.' || piece_side(piece) != side_to_move ||
        (target != '.' && piece_side(target) == side_to_move)) {
        return 0u;
    }
    if (promotion && move[4] == '\0') {
        return 0u;
    }

    if (undo != 0) {
        undo->from = (uint8_t)(from_idx |
            (promotion ? SPECTRUM_BOARD_UNDO_PROMOTION : 0u));
        undo->to = to_idx;
        undo->captured = target;
        undo->castle = castle_rights;
        undo->ep = ep_square;
    }

    clear_castle_rights(from_idx, to_idx, piece, target);

    ep_square = NO_EP;

    if (((piece == 'K' && from_row == 7u) ||
         (piece == 'k' && from_row == 0u)) &&
        from_col == 4u && (to_col == 6u || to_col == 2u)) {
        uint8_t rook_from = (uint8_t)((from_row << 3) +
                                      (to_col == 6u ? 7u : 0u));
        uint8_t rook_to = (uint8_t)((from_row << 3) +
                                    (to_col == 6u ? 5u : 3u));
        char rook = chess_board[rook_from];

        chess_board[rook_to] = rook;
        rules_board[rook_to] = rules_piece_from_char(rook);
        chess_board[rook_from] = '.';
        rules_board[rook_from] = NETCHESSZX_RULE_EMPTY;
    }

    if ((piece == 'P' || piece == 'p') &&
        from_col != to_col && target == '.') {
        uint8_t captured_idx = (uint8_t)((from_row << 3) + to_col);

        chess_board[captured_idx] = '.';
        rules_board[captured_idx] = NETCHESSZX_RULE_EMPTY;
    }

    if ((piece == 'P' || piece == 'p') &&
        abs_delta(from_row, to_row) == 2u) {
        uint8_t mid = (uint8_t)((from_row + to_row) >> 1);
        ep_square = (int8_t)((mid * 8u) + from_col);
    }

    if (promotion) {
        piece = promotion_piece(piece, move[4]);
    }

    chess_board[to_idx] = piece;
    chess_board[from_idx] = '.';
    rules_board[to_idx] = rules_piece_from_char(piece);
    rules_board[from_idx] = NETCHESSZX_RULE_EMPTY;

    side_to_move ^= 1u;
    return 1u;
}

static void undo_set_cell(uint8_t index, char piece)
{
    chess_board[index] = piece;
    rules_board[index] = rules_piece_from_char(piece);
}

static void undo_restore(const spectrum_board_undo_t *undo)
{
    char moved = chess_board[undo->to];
    char original = moved;
    uint8_t side = piece_side(moved);
    uint8_t from_idx = (uint8_t)(undo->from &
                                  SPECTRUM_BOARD_UNDO_INDEX_MASK);
    uint8_t from_row = (uint8_t)(from_idx >> 3);
    uint8_t from_col = (uint8_t)(from_idx & 7u);
    uint8_t to_col = (uint8_t)(undo->to & 7u);

    if (undo->from & SPECTRUM_BOARD_UNDO_PROMOTION) {
        original = side == NETCHESSZX_RULE_WHITE ? 'P' : 'p';
    }
    undo_set_cell(from_idx, original);
    undo_set_cell(undo->to, undo->captured);

    if ((moved == 'P' || moved == 'p') && from_col != to_col &&
        undo->captured == '.' && undo->ep == (int8_t)undo->to) {
        undo_set_cell((uint8_t)((from_row << 3) + to_col),
                      side == NETCHESSZX_RULE_WHITE ? 'p' : 'P');
    } else if (((moved == 'K' && from_row == 7u) ||
                (moved == 'k' && from_row == 0u)) && from_col == 4u &&
               (to_col == 6u || to_col == 2u)) {
        uint8_t rook_from = (uint8_t)((from_row << 3) +
                                      (to_col == 6u ? 7u : 0u));
        uint8_t rook_to = (uint8_t)((from_row << 3) +
                                    (to_col == 6u ? 5u : 3u));

        undo_set_cell(rook_from,
                      side == NETCHESSZX_RULE_WHITE ? 'R' : 'r');
        undo_set_cell(rook_to, '.');
    }
    side_to_move = side;
    castle_rights = undo->castle;
    ep_square = undo->ep;
}
#endif

static uint8_t board_apply_trusted(const char *move,
                                   spectrum_board_undo_t *undo)
{
    uint16_t coords;
    uint8_t from_col;
    uint8_t from_row;
    uint8_t to_col;
    uint8_t to_row;

    coords = netchesszx_move_parse_coords(move);
    if (coords == NETCHESSZX_MOVE_COORDS_INVALID) {
        return 0u;
    }
    from_col = NETCHESSZX_MOVE_FROM_INDEX(coords);
    to_col = NETCHESSZX_MOVE_TO_INDEX(coords);
    from_row = (uint8_t)(from_col >> 3);
    to_row = (uint8_t)(to_col >> 3);
    from_col &= 7u;
    to_col &= 7u;
#ifndef NETCHESSZX_HOST_TEST
    {
        uint16_t move_addr = (uint16_t)move;
        uint16_t undo_addr = (uint16_t)undo;

        spectrum_overlay_context[0] = (uint8_t)move_addr;
        spectrum_overlay_context[1] = (uint8_t)(move_addr >> 8);
        spectrum_overlay_context[2] = from_row;
        spectrum_overlay_context[3] = from_col;
        spectrum_overlay_context[4] = to_row;
        spectrum_overlay_context[5] = to_col;
        spectrum_overlay_context[6] = (uint8_t)undo_addr;
        spectrum_overlay_context[7] = (uint8_t)(undo_addr >> 8);
    }
    return spectrum_overlay_exec(SPECTRUM_OVL_BOARD, SPECTRUM_OVL_BOARD_APPLY);
#else
    return apply_parsed_move(move, from_row, from_col, to_row, to_col, undo);
#endif
}

uint8_t spectrum_board_apply_trusted_move(const char *move) NETCHESSZX_FASTCALL
{
    return board_apply_trusted(move, 0);
}

uint8_t spectrum_board_apply_trusted_move_with_undo(
    const char *move, spectrum_board_undo_t *undo)
{
    return board_apply_trusted(move, undo);
}

void spectrum_board_undo_restore(const spectrum_board_undo_t *undo)
    NETCHESSZX_FASTCALL
{
#ifndef NETCHESSZX_HOST_TEST
    uint16_t undo_addr = (uint16_t)undo;

    spectrum_overlay_context[0] = (uint8_t)undo_addr;
    spectrum_overlay_context[1] = (uint8_t)(undo_addr >> 8);
    (void)spectrum_overlay_exec(SPECTRUM_OVL_BOARD,
                                SPECTRUM_OVL_BOARD_UNDO_RESTORE);
#else
    undo_restore(undo);
#endif
}

#ifdef NETCHESSZX_HOST_TEST
uint8_t spectrum_board_apply_move(const char *move) NETCHESSZX_FASTCALL
{
    uint16_t coords;
    uint8_t from_col;
    uint8_t from_row;
    uint8_t to_col;
    uint8_t to_row;

    coords = netchesszx_move_parse_coords(move);
    if (coords == NETCHESSZX_MOVE_COORDS_INVALID ||
        !spectrum_board_is_legal_move(move)) {
        return 0u;
    }
    from_col = NETCHESSZX_MOVE_FROM_INDEX(coords);
    to_col = NETCHESSZX_MOVE_TO_INDEX(coords);
    from_row = (uint8_t)(from_col >> 3);
    to_row = (uint8_t)(to_col >> 3);
    from_col &= 7u;
    to_col &= 7u;
    return apply_parsed_move(move, from_row, from_col, to_row, to_col, 0);
}
#endif
