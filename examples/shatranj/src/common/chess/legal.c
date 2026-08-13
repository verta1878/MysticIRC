#include "common/chess/legal.h"

#include "common/chess/rules_compact.h"

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define RULES_BOARD_CELLS 64u

typedef struct rules_state {
    int8_t board[RULES_BOARD_CELLS];
    uint8_t side;
    uint8_t castle;
    int8_t ep;
} rules_state_t;

typedef struct parsed_move {
    uint8_t from;
    uint8_t to;
    char promo;
} parsed_move_t;

static rules_state_t rules;

static uint8_t row_of(uint8_t square)
{
    return (uint8_t)(square >> 3);
}

static uint8_t col_of(uint8_t square)
{
    return (uint8_t)(square & 7u);
}

static uint8_t abs_delta(uint8_t a, uint8_t b)
{
    return a > b ? (uint8_t)(a - b) : (uint8_t)(b - a);
}


static int8_t promoted_piece(int8_t pawn, char promo)
{
    const uint8_t white = (uint8_t)(pawn > 0);

    switch (promo) {
    case 'q':
        return white ? NETCHESSZX_RULE_WQ : NETCHESSZX_RULE_BQ;
    case 'r':
        return white ? NETCHESSZX_RULE_WR : NETCHESSZX_RULE_BR;
    case 'b':
        return white ? NETCHESSZX_RULE_WB : NETCHESSZX_RULE_BB;
    case 'n':
        return white ? NETCHESSZX_RULE_WN : NETCHESSZX_RULE_BN;
    default:
        return NETCHESSZX_RULE_EMPTY;
    }
}

static int parse_move(const char *text, parsed_move_t *move)
{
    char promotion;

    if (text == NULL || move == NULL) {
        return NETCHESSZX_ERR_NULL;
    }

    if (text[0] < 'a' || text[0] > 'h' ||
        text[1] < '1' || text[1] > '8' ||
        text[2] < 'a' || text[2] > 'h' ||
        text[3] < '1' || text[3] > '8') {
        return NETCHESSZX_ERR_MOVE;
    }

    promotion = text[4];
    if (promotion >= 'A' && promotion <= 'Z') {
        promotion = (char)(promotion - 'A' + 'a');
    }
    if (promotion != '\0') {
        if (text[5] != '\0') {
            return NETCHESSZX_ERR_MOVE;
        }
        if (promotion != 'q' && promotion != 'r' &&
            promotion != 'b' && promotion != 'n') {
            return NETCHESSZX_ERR_UNSUPPORTED;
        }
    }

    move->from = (uint8_t)(((uint8_t)('8' - text[1]) << 3) |
                           (uint8_t)(text[0] - 'a'));
    move->to = (uint8_t)(((uint8_t)('8' - text[3]) << 3) |
                         (uint8_t)(text[2] - 'a'));
    move->promo = promotion;

    return NETCHESSZX_OK;
}

static int parse_square(const char *text, uint8_t *square)
{
    if (text == NULL || square == NULL) {
        return NETCHESSZX_ERR_NULL;
    }

    if (text[0] < 'a' || text[0] > 'h' ||
        text[1] < '1' || text[1] > '8' ||
        text[2] != '\0') {
        return NETCHESSZX_ERR_MOVE;
    }

    *square = (uint8_t)(((uint8_t)('8' - text[1]) << 3) |
                        (uint8_t)(text[0] - 'a'));
    return NETCHESSZX_OK;
}

static uint8_t is_promotion_target(int8_t piece, uint8_t to)
{
    const uint8_t row = row_of(to);

    return (uint8_t)((piece == NETCHESSZX_RULE_WP && row == 0u) ||
                     (piece == NETCHESSZX_RULE_BP && row == 7u));
}

static int validate_promotion(const parsed_move_t *move)
{
    const int8_t piece = rules.board[move->from];
    const uint8_t promotion = is_promotion_target(piece, move->to);

    if (move->promo != '\0' && !promotion) {
        return NETCHESSZX_ERR_MOVE;
    }
    if (promotion && move->promo == '\0') {
        return NETCHESSZX_ERR_MOVE;
    }
    return NETCHESSZX_OK;
}

static uint8_t compact_legal(uint8_t from, uint8_t to)
{
    return netchesszx_compact_is_legal_move(rules.board,
                                            rules.side,
                                            from,
                                            to,
                                            rules.castle,
                                            rules.ep);
}

static int move_is_legal(const parsed_move_t *move)
{
    int rc = validate_promotion(move);
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    return compact_legal(move->from, move->to) ? NETCHESSZX_OK
                                               : NETCHESSZX_ERR_ILLEGAL;
}

static void clear_castle_rights(uint8_t from, uint8_t to,
                                int8_t piece, int8_t target)
{
    if (piece == NETCHESSZX_RULE_WK) {
        rules.castle &= (uint8_t)~(NETCHESSZX_RULE_CASTLE_WK |
                                   NETCHESSZX_RULE_CASTLE_WQ);
    } else if (piece == NETCHESSZX_RULE_BK) {
        rules.castle &= (uint8_t)~(NETCHESSZX_RULE_CASTLE_BK |
                                   NETCHESSZX_RULE_CASTLE_BQ);
    } else if (piece == NETCHESSZX_RULE_WR) {
        if (from == 56u) {
            rules.castle &= (uint8_t)~NETCHESSZX_RULE_CASTLE_WQ;
        } else if (from == 63u) {
            rules.castle &= (uint8_t)~NETCHESSZX_RULE_CASTLE_WK;
        }
    } else if (piece == NETCHESSZX_RULE_BR) {
        if (from == 0u) {
            rules.castle &= (uint8_t)~NETCHESSZX_RULE_CASTLE_BQ;
        } else if (from == 7u) {
            rules.castle &= (uint8_t)~NETCHESSZX_RULE_CASTLE_BK;
        }
    }

    if (target == NETCHESSZX_RULE_WR) {
        if (to == 56u) {
            rules.castle &= (uint8_t)~NETCHESSZX_RULE_CASTLE_WQ;
        } else if (to == 63u) {
            rules.castle &= (uint8_t)~NETCHESSZX_RULE_CASTLE_WK;
        }
    } else if (target == NETCHESSZX_RULE_BR) {
        if (to == 0u) {
            rules.castle &= (uint8_t)~NETCHESSZX_RULE_CASTLE_BQ;
        } else if (to == 7u) {
            rules.castle &= (uint8_t)~NETCHESSZX_RULE_CASTLE_BK;
        }
    }
}

static void apply_move(const parsed_move_t *move)
{
    const uint8_t from = move->from;
    const uint8_t to = move->to;
    const uint8_t from_row = row_of(from);
    const uint8_t from_col = col_of(from);
    const uint8_t to_row = row_of(to);
    const uint8_t to_col = col_of(to);
    int8_t piece = rules.board[from];
    const int8_t target = rules.board[to];
    const uint8_t pawn = (uint8_t)(piece == NETCHESSZX_RULE_WP ||
                                   piece == NETCHESSZX_RULE_BP);
    const uint8_t castle = (uint8_t)((piece == NETCHESSZX_RULE_WK ||
                                      piece == NETCHESSZX_RULE_BK) &&
                                     from_col == 4u &&
                                     (to_col == 6u || to_col == 2u));
    const uint8_t en_passant = (uint8_t)(pawn && from_col != to_col &&
                                         target == NETCHESSZX_RULE_EMPTY);

    clear_castle_rights(from, to, piece, target);
    rules.ep = NETCHESSZX_RULE_NO_SQUARE;

    if (en_passant) {
        rules.board[(uint8_t)((from_row << 3) | to_col)] = NETCHESSZX_RULE_EMPTY;
    }
    if (pawn && abs_delta(from_row, to_row) == 2u) {
        rules.ep = (int8_t)((((from_row + to_row) >> 1) << 3) | from_col);
    }
    if (is_promotion_target(piece, to)) {
        piece = promoted_piece(piece, move->promo);
    }

    rules.board[to] = piece;
    rules.board[from] = NETCHESSZX_RULE_EMPTY;

    if (castle) {
        const uint8_t rook_from = (uint8_t)((from_row << 3) |
                                            (to_col == 6u ? 7u : 0u));
        const uint8_t rook_to = (uint8_t)((from_row << 3) |
                                          (to_col == 6u ? 5u : 3u));
        rules.board[rook_to] = rules.board[rook_from];
        rules.board[rook_from] = NETCHESSZX_RULE_EMPTY;
    }

    rules.side ^= 1u;
}

int netchesszx_rules_reset(void)
{
    static const int8_t initial_board[RULES_BOARD_CELLS] = {
        NETCHESSZX_RULE_BR, NETCHESSZX_RULE_BN, NETCHESSZX_RULE_BB, NETCHESSZX_RULE_BQ,
        NETCHESSZX_RULE_BK, NETCHESSZX_RULE_BB, NETCHESSZX_RULE_BN, NETCHESSZX_RULE_BR,
        NETCHESSZX_RULE_BP, NETCHESSZX_RULE_BP, NETCHESSZX_RULE_BP, NETCHESSZX_RULE_BP,
        NETCHESSZX_RULE_BP, NETCHESSZX_RULE_BP, NETCHESSZX_RULE_BP, NETCHESSZX_RULE_BP,
        NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY,
        NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY,
        NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY,
        NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY,
        NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY,
        NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY,
        NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY,
        NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY, NETCHESSZX_RULE_EMPTY,
        NETCHESSZX_RULE_WP, NETCHESSZX_RULE_WP, NETCHESSZX_RULE_WP, NETCHESSZX_RULE_WP,
        NETCHESSZX_RULE_WP, NETCHESSZX_RULE_WP, NETCHESSZX_RULE_WP, NETCHESSZX_RULE_WP,
        NETCHESSZX_RULE_WR, NETCHESSZX_RULE_WN, NETCHESSZX_RULE_WB, NETCHESSZX_RULE_WQ,
        NETCHESSZX_RULE_WK, NETCHESSZX_RULE_WB, NETCHESSZX_RULE_WN, NETCHESSZX_RULE_WR
    };

    memcpy(rules.board, initial_board, sizeof(rules.board));
    rules.side = NETCHESSZX_RULE_WHITE;
    rules.castle = NETCHESSZX_RULE_CASTLE_WK |
                   NETCHESSZX_RULE_CASTLE_WQ |
                   NETCHESSZX_RULE_CASTLE_BK |
                   NETCHESSZX_RULE_CASTLE_BQ;
    rules.ep = NETCHESSZX_RULE_NO_SQUARE;
    return NETCHESSZX_OK;
}

int netchesszx_rules_can_play(const char *move_text)
{
    parsed_move_t move;
    int rc = parse_move(move_text, &move);

    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    return move_is_legal(&move);
}

int netchesszx_rules_play(const char *move_text)
{
    parsed_move_t move;
    int rc = parse_move(move_text, &move);

    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = move_is_legal(&move);
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    apply_move(&move);
    return NETCHESSZX_OK;
}

uint8_t netchesszx_rules_check_state(void)
{
    return netchesszx_compact_check_state(rules.board, rules.side,
                                          rules.castle, rules.ep);
}

int netchesszx_rules_has_legal_moves(void)
{
    const uint8_t state = netchesszx_rules_check_state();

    return (int)(state != NETCHESSZX_RULE_CHECK_MATE &&
                 state != NETCHESSZX_RULE_STALEMATE);
}

size_t netchesszx_rules_state_size(void)
{
    return sizeof(rules);
}

#ifndef NETCHESSZX_FIXED_LOW_RAM
int netchesszx_rules_save(void *state, size_t cap)
{
    if (state == NULL) {
        return NETCHESSZX_ERR_NULL;
    }
    if (cap < sizeof(rules)) {
        return NETCHESSZX_ERR_MOVE;
    }
    memcpy(state, &rules, sizeof(rules));
    return NETCHESSZX_OK;
}

int netchesszx_rules_restore(const void *state, size_t cap)
{
    if (state == NULL) {
        return NETCHESSZX_ERR_NULL;
    }
    if (cap < sizeof(rules)) {
        return NETCHESSZX_ERR_MOVE;
    }
    memcpy(&rules, state, sizeof(rules));
    return NETCHESSZX_OK;
}
#endif

int netchesszx_rules_legal_targets(const char *from_text, char *out, size_t cap)
{
    uint8_t from;
    size_t used = 0u;
    int rc;
    int to;

    if (out == NULL || cap == 0u) {
        return NETCHESSZX_ERR_NULL;
    }
    out[0] = '\0';

    rc = parse_square(from_text, &from);
    if (rc != NETCHESSZX_OK) {
        return rc;
    }

    for (to = 63; to >= 0; --to) {
        if (compact_legal(from, (uint8_t)to)) {
            const char file = (char)('a' + col_of((uint8_t)to));
            const char rank = (char)('8' - row_of((uint8_t)to));

            if (used != 0u) {
                if (used + 1u >= cap) {
                    return NETCHESSZX_ERR_BUFFER;
                }
                out[used++] = ' ';
            }
            if (used + 2u >= cap) {
                return NETCHESSZX_ERR_BUFFER;
            }
            out[used++] = file;
            out[used++] = rank;
            out[used] = '\0';
        }
    }

    return NETCHESSZX_OK;
}
