#include "common/chess/rules_compact.h"

static uint8_t piece_type(int8_t p)
{
    return (uint8_t)((p < 0) ? -p : p);
}

static uint8_t piece_color(int8_t p)
{
    return p > 0 ? NETCHESSZX_RULE_WHITE : NETCHESSZX_RULE_BLACK;
}

static uint8_t abs_char(int8_t v)
{
    return (uint8_t)((v < 0) ? -v : v);
}

static uint8_t inside_board(int8_t r, int8_t f)
{
    return (uint8_t)(r >= 0 && r < 8 && f >= 0 && f < 8);
}

static uint8_t sq_from_rf(int8_t r, int8_t f)
{
    return (uint8_t)((r << 3) + f);
}

static uint8_t path_clear(const int8_t board[64],
                          uint8_t from,
                          uint8_t to,
                          int8_t step)
{
    int8_t s = (int8_t)(from + step);

    while ((uint8_t)s != to) {
        if (board[(uint8_t)s] != NETCHESSZX_RULE_EMPTY) {
            return 0u;
        }
        s = (int8_t)(s + step);
    }

    return 1u;
}

static uint8_t square_attacked_by(const int8_t board[64],
                                  uint8_t sq,
                                  uint8_t by_side)
{
    static const int8_t knight_dr[8] = {-2, -2, -1, -1, 1, 1, 2, 2};
    static const int8_t knight_df[8] = {-1, 1, -2, 2, -2, 2, -1, 1};
    static const int8_t ray_dr[8] = {-1, -1, -1, 0, 0, 1, 1, 1};
    static const int8_t ray_df[8] = {-1, 0, 1, -1, 1, -1, 0, 1};

    uint8_t r = (uint8_t)(sq >> 3);
    uint8_t f = (uint8_t)(sq & 7u);
    uint8_t i;
    int8_t rr;
    int8_t ff;
    int8_t p;
    uint8_t t;

    if (by_side == NETCHESSZX_RULE_WHITE) {
        if (f > 0u && sq <= 55u &&
            board[(uint8_t)(sq + 7u)] == NETCHESSZX_RULE_WP) {
            return 1u;
        }
        if (f < 7u && sq <= 55u &&
            board[(uint8_t)(sq + 9u)] == NETCHESSZX_RULE_WP) {
            return 1u;
        }
    } else {
        if (f < 7u && sq >= 8u &&
            board[(uint8_t)(sq - 7u)] == NETCHESSZX_RULE_BP) {
            return 1u;
        }
        if (f > 0u && sq >= 8u &&
            board[(uint8_t)(sq - 9u)] == NETCHESSZX_RULE_BP) {
            return 1u;
        }
    }

    for (i = 0u; i < 8u; ++i) {
        rr = (int8_t)((int8_t)r + knight_dr[i]);
        ff = (int8_t)((int8_t)f + knight_df[i]);

        if (inside_board(rr, ff)) {
            p = board[sq_from_rf(rr, ff)];
            if (p == (int8_t)(by_side == NETCHESSZX_RULE_WHITE ?
                              NETCHESSZX_RULE_WN : NETCHESSZX_RULE_BN)) {
                return 1u;
            }
        }
    }

    for (rr = -1; rr <= 1; ++rr) {
        for (ff = -1; ff <= 1; ++ff) {
            if (rr != 0 || ff != 0) {
                int8_t kr = (int8_t)((int8_t)r + rr);
                int8_t kf = (int8_t)((int8_t)f + ff);

                if (inside_board(kr, kf)) {
                    p = board[sq_from_rf(kr, kf)];
                    if (p == (int8_t)(by_side == NETCHESSZX_RULE_WHITE ?
                                      NETCHESSZX_RULE_WK : NETCHESSZX_RULE_BK)) {
                        return 1u;
                    }
                }
            }
        }
    }

    for (i = 0u; i < 8u; ++i) {
        rr = (int8_t)((int8_t)r + ray_dr[i]);
        ff = (int8_t)((int8_t)f + ray_df[i]);

        while (inside_board(rr, ff)) {
            p = board[sq_from_rf(rr, ff)];

            if (p != NETCHESSZX_RULE_EMPTY) {
                if (piece_color(p) == by_side) {
                    t = piece_type(p);

                    if (ray_dr[i] != 0 && ray_df[i] != 0) {
                        if (t == NETCHESSZX_RULE_BISHOP ||
                            t == NETCHESSZX_RULE_QUEEN) {
                            return 1u;
                        }
                    } else if (t == NETCHESSZX_RULE_ROOK ||
                               t == NETCHESSZX_RULE_QUEEN) {
                        return 1u;
                    }
                }
                break;
            }

            rr = (int8_t)(rr + ray_dr[i]);
            ff = (int8_t)(ff + ray_df[i]);
        }
    }

    return 0u;
}

static uint8_t find_king(const int8_t board[64], uint8_t side)
{
    uint8_t i;
    int8_t king = (int8_t)(side == NETCHESSZX_RULE_WHITE ?
                           NETCHESSZX_RULE_WK : NETCHESSZX_RULE_BK);

    for (i = 0u; i < 64u; ++i) {
        if (board[i] == king) {
            return i;
        }
    }

    return 0xffu;
}

static uint8_t is_pseudo_legal_move(const int8_t board[64],
                                    uint8_t side,
                                    uint8_t from,
                                    uint8_t to,
                                    uint8_t castle_rights,
                                    int8_t ep_square)
{
    int8_t p = board[from];
    int8_t dst = board[to];
    uint8_t type;
    uint8_t fr;
    uint8_t ff;
    uint8_t tr;
    uint8_t tf;
    int8_t dr;
    int8_t df;
    uint8_t adr;
    uint8_t adf;
    int8_t step;

    if (p == NETCHESSZX_RULE_EMPTY) {
        return 0u;
    }
    if (piece_color(p) != side) {
        return 0u;
    }
    if (dst != NETCHESSZX_RULE_EMPTY && piece_color(dst) == side) {
        return 0u;
    }
    if (dst != NETCHESSZX_RULE_EMPTY &&
        piece_type(dst) == NETCHESSZX_RULE_KING) {
        return 0u;
    }

    type = piece_type(p);

    fr = (uint8_t)(from >> 3);
    ff = (uint8_t)(from & 7u);
    tr = (uint8_t)(to >> 3);
    tf = (uint8_t)(to & 7u);

    dr = (int8_t)((int8_t)tr - (int8_t)fr);
    df = (int8_t)((int8_t)tf - (int8_t)ff);

    adr = abs_char(dr);
    adf = abs_char(df);

    switch (type) {
    case NETCHESSZX_RULE_PAWN:
        if (side == NETCHESSZX_RULE_WHITE) {
            if (df == 0 && dr == -1 && dst == NETCHESSZX_RULE_EMPTY) {
                return 1u;
            }
            if (df == 0 && fr == 6u && dr == -2 &&
                dst == NETCHESSZX_RULE_EMPTY &&
                board[(uint8_t)(from - 8u)] == NETCHESSZX_RULE_EMPTY) {
                return 1u;
            }

            if (adf == 1u && dr == -1) {
                if (dst != NETCHESSZX_RULE_EMPTY) {
                    return 1u;
                }

                if ((int8_t)to == ep_square) {
                    int8_t cap = (int8_t)(to + 8u);
                    if (cap >= 0 && cap < 64 &&
                        board[(uint8_t)cap] == NETCHESSZX_RULE_BP) {
                        return 1u;
                    }
                }
            }
        } else {
            if (df == 0 && dr == 1 && dst == NETCHESSZX_RULE_EMPTY) {
                return 1u;
            }
            if (df == 0 && fr == 1u && dr == 2 &&
                dst == NETCHESSZX_RULE_EMPTY &&
                board[(uint8_t)(from + 8u)] == NETCHESSZX_RULE_EMPTY) {
                return 1u;
            }

            if (adf == 1u && dr == 1) {
                if (dst != NETCHESSZX_RULE_EMPTY) {
                    return 1u;
                }

                if ((int8_t)to == ep_square) {
                    int8_t cap = (int8_t)(to - 8u);
                    if (cap >= 0 && cap < 64 &&
                        board[(uint8_t)cap] == NETCHESSZX_RULE_WP) {
                        return 1u;
                    }
                }
            }
        }
        return 0u;

    case NETCHESSZX_RULE_KNIGHT:
        return (uint8_t)((adr == 2u && adf == 1u) ||
                         (adr == 1u && adf == 2u));

    case NETCHESSZX_RULE_BISHOP:
        if (adr != adf || adr == 0u) {
            return 0u;
        }
        step = (int8_t)((dr > 0 ? 8 : -8) + (df > 0 ? 1 : -1));
        return path_clear(board, from, to, step);

    case NETCHESSZX_RULE_ROOK:
        if (dr != 0 && df != 0) {
            return 0u;
        }
        if (dr == 0 && df == 0) {
            return 0u;
        }
        step = dr != 0 ? (int8_t)(dr > 0 ? 8 : -8) :
                         (int8_t)(df > 0 ? 1 : -1);
        return path_clear(board, from, to, step);

    case NETCHESSZX_RULE_QUEEN:
        if (adr == adf && adr != 0u) {
            step = (int8_t)((dr > 0 ? 8 : -8) + (df > 0 ? 1 : -1));
            return path_clear(board, from, to, step);
        }

        if ((dr == 0 && df != 0) || (df == 0 && dr != 0)) {
            step = dr != 0 ? (int8_t)(dr > 0 ? 8 : -8) :
                             (int8_t)(df > 0 ? 1 : -1);
            return path_clear(board, from, to, step);
        }
        return 0u;

    case NETCHESSZX_RULE_KING:
        if (adr <= 1u && adf <= 1u && (adr != 0u || adf != 0u)) {
            return 1u;
        }
        if (dr != 0 || adf != 2u || dst != NETCHESSZX_RULE_EMPTY) {
            return 0u;
        }

        if (side == NETCHESSZX_RULE_WHITE && from == 60u) {
            if (to == 62u) {
                if ((castle_rights & NETCHESSZX_RULE_CASTLE_WK) == 0u) {
                    return 0u;
                }
                if (board[63] != NETCHESSZX_RULE_WR ||
                    board[61] != NETCHESSZX_RULE_EMPTY ||
                    board[62] != NETCHESSZX_RULE_EMPTY) {
                    return 0u;
                }
                if (square_attacked_by(board, 60u, NETCHESSZX_RULE_BLACK)) {
                    return 0u;
                }
                if (square_attacked_by(board, 61u, NETCHESSZX_RULE_BLACK)) {
                    return 0u;
                }
                if (square_attacked_by(board, 62u, NETCHESSZX_RULE_BLACK)) {
                    return 0u;
                }
                return 1u;
            }

            if (to == 58u) {
                if ((castle_rights & NETCHESSZX_RULE_CASTLE_WQ) == 0u) {
                    return 0u;
                }
                if (board[56] != NETCHESSZX_RULE_WR ||
                    board[59] != NETCHESSZX_RULE_EMPTY ||
                    board[58] != NETCHESSZX_RULE_EMPTY ||
                    board[57] != NETCHESSZX_RULE_EMPTY) {
                    return 0u;
                }
                if (square_attacked_by(board, 60u, NETCHESSZX_RULE_BLACK)) {
                    return 0u;
                }
                if (square_attacked_by(board, 59u, NETCHESSZX_RULE_BLACK)) {
                    return 0u;
                }
                if (square_attacked_by(board, 58u, NETCHESSZX_RULE_BLACK)) {
                    return 0u;
                }
                return 1u;
            }
        }

        if (side == NETCHESSZX_RULE_BLACK && from == 4u) {
            if (to == 6u) {
                if ((castle_rights & NETCHESSZX_RULE_CASTLE_BK) == 0u) {
                    return 0u;
                }
                if (board[7] != NETCHESSZX_RULE_BR ||
                    board[5] != NETCHESSZX_RULE_EMPTY ||
                    board[6] != NETCHESSZX_RULE_EMPTY) {
                    return 0u;
                }
                if (square_attacked_by(board, 4u, NETCHESSZX_RULE_WHITE)) {
                    return 0u;
                }
                if (square_attacked_by(board, 5u, NETCHESSZX_RULE_WHITE)) {
                    return 0u;
                }
                if (square_attacked_by(board, 6u, NETCHESSZX_RULE_WHITE)) {
                    return 0u;
                }
                return 1u;
            }

            if (to == 2u) {
                if ((castle_rights & NETCHESSZX_RULE_CASTLE_BQ) == 0u) {
                    return 0u;
                }
                if (board[0] != NETCHESSZX_RULE_BR ||
                    board[3] != NETCHESSZX_RULE_EMPTY ||
                    board[2] != NETCHESSZX_RULE_EMPTY ||
                    board[1] != NETCHESSZX_RULE_EMPTY) {
                    return 0u;
                }
                if (square_attacked_by(board, 4u, NETCHESSZX_RULE_WHITE)) {
                    return 0u;
                }
                if (square_attacked_by(board, 3u, NETCHESSZX_RULE_WHITE)) {
                    return 0u;
                }
                if (square_attacked_by(board, 2u, NETCHESSZX_RULE_WHITE)) {
                    return 0u;
                }
                return 1u;
            }
        }
        return 0u;
    default:
        break;
    }

    return 0u;
}

uint8_t netchesszx_compact_is_legal_move(const int8_t board[64],
                                         uint8_t side,
                                         uint8_t from,
                                         uint8_t to,
                                         uint8_t castle_rights,
                                         int8_t ep_square)
{
    int8_t tmp[64];
    int8_t moving;
    uint8_t i;
    uint8_t king_sq;

    if (from > 63u || to > 63u) {
        return 0u;
    }
    if (side > NETCHESSZX_RULE_BLACK) {
        return 0u;
    }
    if (ep_square < NETCHESSZX_RULE_NO_SQUARE || ep_square > 63) {
        return 0u;
    }

    if (!is_pseudo_legal_move(board, side, from, to,
                              castle_rights, ep_square)) {
        return 0u;
    }

    for (i = 0u; i < 64u; ++i) {
        tmp[i] = board[i];
    }

    moving = tmp[from];
    tmp[from] = NETCHESSZX_RULE_EMPTY;
    tmp[to] = moving;

    if (piece_type(moving) == NETCHESSZX_RULE_PAWN &&
        board[to] == NETCHESSZX_RULE_EMPTY &&
        (from & 7u) != (to & 7u) &&
        (int8_t)to == ep_square) {
        if (side == NETCHESSZX_RULE_WHITE) {
            tmp[(uint8_t)(to + 8u)] = NETCHESSZX_RULE_EMPTY;
        } else {
            tmp[(uint8_t)(to - 8u)] = NETCHESSZX_RULE_EMPTY;
        }
    }

    if (moving == NETCHESSZX_RULE_WK && from == 60u) {
        if (to == 62u) {
            tmp[61] = NETCHESSZX_RULE_WR;
            tmp[63] = NETCHESSZX_RULE_EMPTY;
        } else if (to == 58u) {
            tmp[59] = NETCHESSZX_RULE_WR;
            tmp[56] = NETCHESSZX_RULE_EMPTY;
        }
    } else if (moving == NETCHESSZX_RULE_BK && from == 4u) {
        if (to == 6u) {
            tmp[5] = NETCHESSZX_RULE_BR;
            tmp[7] = NETCHESSZX_RULE_EMPTY;
        } else if (to == 2u) {
            tmp[3] = NETCHESSZX_RULE_BR;
            tmp[0] = NETCHESSZX_RULE_EMPTY;
        }
    }

    king_sq = find_king(tmp, side);
    if (king_sq == 0xffu) {
        return 0u;
    }

    return (uint8_t)!square_attacked_by(tmp, king_sq, (uint8_t)(side ^ 1u));
}

uint8_t netchesszx_compact_check_state(const int8_t board[64],
                                       uint8_t side,
                                       uint8_t castle_rights,
                                       int8_t ep_square)
{
    uint8_t king_sq;
    uint8_t from;
    uint8_t to;
    uint8_t in_check;
    int8_t moving;

    if (side > NETCHESSZX_RULE_BLACK) {
        return NETCHESSZX_RULE_CHECK_NONE;
    }

    king_sq = find_king(board, side);
    if (king_sq == 0xffu) {
        return NETCHESSZX_RULE_CHECK_NONE;
    }
    in_check = square_attacked_by(board, king_sq, (uint8_t)(side ^ 1u));

    for (from = 0u; from < 64u; ++from) {
        moving = board[from];
        if (moving == NETCHESSZX_RULE_EMPTY || piece_color(moving) != side) {
            continue;
        }
        for (to = 0u; to < 64u; ++to) {
            if (netchesszx_compact_is_legal_move(board,
                                                 side,
                                                 from,
                                                 to,
                                                 castle_rights,
                                                 ep_square)) {
                return in_check ? NETCHESSZX_RULE_CHECK : NETCHESSZX_RULE_CHECK_NONE;
            }
        }
    }

    return in_check ? NETCHESSZX_RULE_CHECK_MATE : NETCHESSZX_RULE_STALEMATE;
}
