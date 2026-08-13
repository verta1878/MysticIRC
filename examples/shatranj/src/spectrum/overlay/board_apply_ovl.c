#include <stdint.h>

#include "spectrum/board/board.h"
#include "spectrum/lowram_map.h"

#define RULE_EMPTY 0
#define RULE_WHITE 0u
#define RULE_BLACK 1u
#define RULE_WP 1
#define RULE_WN 2
#define RULE_WB 3
#define RULE_WR 4
#define RULE_WQ 5
#define RULE_WK 6
#define RULE_BP -1
#define RULE_BN -2
#define RULE_BB -3
#define RULE_BR -4
#define RULE_BQ -5
#define RULE_BK -6
#define CASTLE_WK 1u
#define CASTLE_WQ 2u
#define CASTLE_BK 4u
#define CASTLE_BQ 8u
#define NO_EP (-1)

#define chess_board ((char *)NETCHESSZX_LOWRAM_CHESS_BOARD_ADDR)
#define rules_board ((int8_t *)NETCHESSZX_LOWRAM_RULES_BOARD_ADDR)

extern uint8_t side_to_move;
extern uint8_t castle_rights;
extern int8_t ep_square;

uint8_t abs_delta(uint8_t a, uint8_t b);
uint8_t piece_side(char piece);
int8_t rules_piece_from_char(char piece);
char promotion_piece(char pawn, char promo);

static spectrum_board_snapshot_t *snapshot_from_ctx(uint8_t *ctx)
{
    return (spectrum_board_snapshot_t *)((uint16_t)ctx[0] |
                                        ((uint16_t)ctx[1] << 8));
}

static void board_set_cell(uint8_t index, char piece)
{
    chess_board[index] = piece;
    rules_board[index] = rules_piece_from_char(piece);
}

uint8_t board_snapshot_restore_ovl(uint8_t *ctx) __z88dk_fastcall
{
    spectrum_board_snapshot_t *snapshot = snapshot_from_ctx(ctx);
    uint8_t i;

    for (i = 0u; i < 64u; ++i) {
        board_set_cell(i, snapshot->cells[i]);
    }
    side_to_move = snapshot->side;
    castle_rights = snapshot->castle;
    ep_square = snapshot->ep;
    return 1u;
}

static void clear_castle_rights(uint8_t from_idx, uint8_t to_idx,
                                char piece, char target)
{
    if (piece == 'K') {
        castle_rights &= (uint8_t)~(CASTLE_WK | CASTLE_WQ);
    } else if (piece == 'k') {
        castle_rights &= (uint8_t)~(CASTLE_BK | CASTLE_BQ);
    } else if (piece == 'R') {
        if (from_idx == 56u) {
            castle_rights &= (uint8_t)~CASTLE_WQ;
        } else if (from_idx == 63u) {
            castle_rights &= (uint8_t)~CASTLE_WK;
        }
    } else if (piece == 'r') {
        if (from_idx == 0u) {
            castle_rights &= (uint8_t)~CASTLE_BQ;
        } else if (from_idx == 7u) {
            castle_rights &= (uint8_t)~CASTLE_BK;
        }
    }

    if (target == 'R') {
        if (to_idx == 56u) {
            castle_rights &= (uint8_t)~CASTLE_WQ;
        } else if (to_idx == 63u) {
            castle_rights &= (uint8_t)~CASTLE_WK;
        }
    } else if (target == 'r') {
        if (to_idx == 0u) {
            castle_rights &= (uint8_t)~CASTLE_BQ;
        } else if (to_idx == 7u) {
            castle_rights &= (uint8_t)~CASTLE_BK;
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

        board_set_cell(rook_to, chess_board[rook_from]);
        board_set_cell(rook_from, '.');
    }

    if ((piece == 'P' || piece == 'p') &&
        from_col != to_col && target == '.') {
        board_set_cell((uint8_t)((from_row << 3) + to_col), '.');
    }

    if ((piece == 'P' || piece == 'p') &&
        abs_delta(from_row, to_row) == 2u) {
        ep_square = (int8_t)(((from_row + to_row) >> 1) << 3);
        ep_square = (int8_t)(ep_square + (int8_t)from_col);
    }

    if (promotion) {
        piece = promotion_piece(piece, move[4]);
    }

    chess_board[to_idx] = piece;
    chess_board[from_idx] = '.';
    rules_board[to_idx] = rules_piece_from_char(piece);
    rules_board[from_idx] = RULE_EMPTY;

    side_to_move ^= 1u;
    return 1u;
}

uint8_t board_apply_trusted_ovl(uint8_t *ctx) __z88dk_fastcall
{
    const char *move = (const char *)((uint16_t)ctx[0] | ((uint16_t)ctx[1] << 8));
    spectrum_board_undo_t *undo =
        (spectrum_board_undo_t *)((uint16_t)ctx[6] |
                                  ((uint16_t)ctx[7] << 8));

    return apply_parsed_move(move, ctx[2], ctx[3], ctx[4], ctx[5], undo);
}

uint8_t board_undo_restore_ovl(uint8_t *ctx) __z88dk_fastcall
{
    const spectrum_board_undo_t *undo =
        (const spectrum_board_undo_t *)((uint16_t)ctx[0] |
                                        ((uint16_t)ctx[1] << 8));
    char moved = chess_board[undo->to];
    char original = moved;
    uint8_t side = piece_side(moved);
    uint8_t from_idx = (uint8_t)(undo->from &
                                  SPECTRUM_BOARD_UNDO_INDEX_MASK);
    uint8_t from_row = (uint8_t)(from_idx >> 3);
    uint8_t from_col = (uint8_t)(from_idx & 7u);
    uint8_t to_col = (uint8_t)(undo->to & 7u);

    if (undo->from & SPECTRUM_BOARD_UNDO_PROMOTION) {
        original = side == RULE_WHITE ? 'P' : 'p';
    }
    board_set_cell(from_idx, original);
    board_set_cell(undo->to, undo->captured);

    if ((moved == 'P' || moved == 'p') && from_col != to_col &&
        undo->captured == '.' && undo->ep == (int8_t)undo->to) {
        board_set_cell((uint8_t)((from_row << 3) + to_col),
                       side == RULE_WHITE ? 'p' : 'P');
    } else if (((moved == 'K' && from_row == 7u) ||
                (moved == 'k' && from_row == 0u)) && from_col == 4u &&
               (to_col == 6u || to_col == 2u)) {
        uint8_t rook_from = (uint8_t)((from_row << 3) +
                                      (to_col == 6u ? 7u : 0u));
        uint8_t rook_to = (uint8_t)((from_row << 3) +
                                    (to_col == 6u ? 5u : 3u));

        board_set_cell(rook_from, side == RULE_WHITE ? 'R' : 'r');
        board_set_cell(rook_to, '.');
    }
    side_to_move = side;
    castle_rights = undo->castle;
    ep_square = undo->ep;
    return 1u;
}
