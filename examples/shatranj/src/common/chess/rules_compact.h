#ifndef NETCHESSZX_COMMON_RULES_COMPACT_H
#define NETCHESSZX_COMMON_RULES_COMPACT_H

#include <stdint.h>

#define NETCHESSZX_RULE_EMPTY 0

#define NETCHESSZX_RULE_WHITE 0u
#define NETCHESSZX_RULE_BLACK 1u

#define NETCHESSZX_RULE_PAWN   1
#define NETCHESSZX_RULE_KNIGHT 2
#define NETCHESSZX_RULE_BISHOP 3
#define NETCHESSZX_RULE_ROOK   4
#define NETCHESSZX_RULE_QUEEN  5
#define NETCHESSZX_RULE_KING   6

#define NETCHESSZX_RULE_WP  1
#define NETCHESSZX_RULE_WN  2
#define NETCHESSZX_RULE_WB  3
#define NETCHESSZX_RULE_WR  4
#define NETCHESSZX_RULE_WQ  5
#define NETCHESSZX_RULE_WK  6

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

#define NETCHESSZX_RULE_CHECK_NONE 0u
#define NETCHESSZX_RULE_CHECK 1u
#define NETCHESSZX_RULE_CHECK_MATE 2u
#define NETCHESSZX_RULE_STALEMATE 3u

uint8_t netchesszx_compact_is_legal_move(const int8_t board[64],
                                         uint8_t side,
                                         uint8_t from,
                                         uint8_t to,
                                         uint8_t castle_rights,
                                         int8_t ep_square);
uint8_t netchesszx_compact_check_state(const int8_t board[64],
                                       uint8_t side,
                                       uint8_t castle_rights,
                                       int8_t ep_square);

#endif