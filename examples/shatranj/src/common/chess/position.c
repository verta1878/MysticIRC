#include "common/chess/position.h"

#include <string.h>

static int is_space(char c)
{
    return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

static int read_token(const char **pp, char *out, size_t cap)
{
    const char *p;
    size_t n;

    if (pp == 0 || *pp == 0 || out == 0 || cap == 0) {
        return NETCHESSZX_ERR_NULL;
    }

    p = *pp;
    while (is_space(*p)) {
        ++p;
    }
    if (*p == '\0') {
        return NETCHESSZX_ERR_TOKEN;
    }

    n = 0;
    while (*p != '\0' && !is_space(*p)) {
        if (n + 1 >= cap) {
            return NETCHESSZX_ERR_BUFFER;
        }
        out[n++] = *p++;
    }
    out[n] = '\0';
    *pp = p;
    return NETCHESSZX_OK;
}

static int parse_uint_range(const char *s, unsigned max, unsigned *out)
{
    unsigned v;

    if (s == 0 || *s == '\0' || out == 0) {
        return NETCHESSZX_ERR_NULL;
    }

    v = 0;
    while (*s != '\0') {
        if (*s < '0' || *s > '9') {
            return NETCHESSZX_ERR_NUMBER;
        }
        v = (v * 10u) + (unsigned)(*s - '0');
        if (v > max) {
            return NETCHESSZX_ERR_NUMBER;
        }
        ++s;
    }

    *out = v;
    return NETCHESSZX_OK;
}

static uint8_t piece_from_fen(char c)
{
    uint8_t color;
    uint8_t piece;

    color = NETCHESSZX_WHITE;
    if (c >= 'a' && c <= 'z') {
        color = NETCHESSZX_BLACK;
        c = (char)(c - ('a' - 'A'));
    }

    switch (c) {
    case 'P':
        piece = NETCHESSZX_PAWN;
        break;
    case 'N':
        piece = NETCHESSZX_KNIGHT;
        break;
    case 'B':
        piece = NETCHESSZX_BISHOP;
        break;
    case 'R':
        piece = NETCHESSZX_ROOK;
        break;
    case 'Q':
        piece = NETCHESSZX_QUEEN;
        break;
    case 'K':
        piece = NETCHESSZX_KING;
        break;
    default:
        return NETCHESSZX_OFFBOARD;
    }

    return (uint8_t)(piece | color);
}

static char fen_from_piece(uint8_t piece)
{
    char c;
    uint8_t type;

    type = (uint8_t)(piece & NETCHESSZX_TYPE_MASK);
    switch (type) {
    case NETCHESSZX_PAWN:
        c = 'P';
        break;
    case NETCHESSZX_KNIGHT:
        c = 'N';
        break;
    case NETCHESSZX_BISHOP:
        c = 'B';
        break;
    case NETCHESSZX_ROOK:
        c = 'R';
        break;
    case NETCHESSZX_QUEEN:
        c = 'Q';
        break;
    case NETCHESSZX_KING:
        c = 'K';
        break;
    default:
        return '\0';
    }

    if ((piece & NETCHESSZX_COLOR_MASK) == NETCHESSZX_BLACK) {
        c = (char)(c + ('a' - 'A'));
    }
    return c;
}

static int append_char(char **dst, size_t *left, char c)
{
    if (*left <= 1u) {
        return NETCHESSZX_ERR_BUFFER;
    }
    **dst = c;
    ++(*dst);
    --(*left);
    **dst = '\0';
    return NETCHESSZX_OK;
}

static int append_str(char **dst, size_t *left, const char *s)
{
    while (*s != '\0') {
        int rc;

        rc = append_char(dst, left, *s++);
        if (rc != NETCHESSZX_OK) {
            return rc;
        }
    }
    return NETCHESSZX_OK;
}

static int append_uint(char **dst, size_t *left, unsigned v)
{
    char tmp[6];
    size_t n;

    n = 0;
    do {
        tmp[n++] = (char)('0' + (v % 10u));
        v /= 10u;
    } while (v != 0u && n < sizeof(tmp));

    while (n > 0u) {
        int rc;

        rc = append_char(dst, left, tmp[--n]);
        if (rc != NETCHESSZX_OK) {
            return rc;
        }
    }
    return NETCHESSZX_OK;
}

void netchesszx_position_init(netchesszx_position_t *pos)
{
    int i;
    int rank;
    int file;

    if (pos == 0) {
        return;
    }

    for (i = 0; i < NETCHESSZX_BOARD_SIZE; ++i) {
        pos->board[i] = NETCHESSZX_OFFBOARD;
    }
    for (rank = 1; rank <= 8; ++rank) {
        for (file = 0; file < 8; ++file) {
            pos->board[21 + file + ((rank - 1) * 10)] = NETCHESSZX_EMPTY;
        }
    }

    pos->side_to_move = NETCHESSZX_WHITE;
    pos->castle_rights = 0u;
    pos->ep_square = NETCHESSZX_NO_SQUARE;
    pos->halfmove_clock = 0u;
    pos->fullmove_number = 1u;
}

int8_t netchesszx_square_index(char file, char rank)
{
    if (file < 'a' || file > 'h' || rank < '1' || rank > '8') {
        return NETCHESSZX_NO_SQUARE;
    }
    return (int8_t)(21 + (file - 'a') + ((rank - '1') * 10));
}

int netchesszx_square_to_coord(int8_t square, char out[3])
{
    int index;
    int rel;
    int file;
    int rank;

    if (out == 0) {
        return NETCHESSZX_ERR_NULL;
    }

    index = square;
    rel = index - 21;
    if (rel < 0) {
        return NETCHESSZX_ERR_EP;
    }
    file = rel % 10;
    rank = (rel / 10) + 1;
    if (file < 0 || file > 7 || rank < 1 || rank > 8) {
        return NETCHESSZX_ERR_EP;
    }

    out[0] = (char)('a' + file);
    out[1] = (char)('0' + rank);
    out[2] = '\0';
    return NETCHESSZX_OK;
}

static int parse_board(netchesszx_position_t *pos, const char *board)
{
    int rank;
    int file;

    rank = 8;
    file = 0;
    while (*board != '\0') {
        char c;

        c = *board++;
        if (c == '/') {
            if (file != 8) {
                return NETCHESSZX_ERR_BOARD;
            }
            --rank;
            file = 0;
            if (rank < 1) {
                return NETCHESSZX_ERR_BOARD;
            }
        } else if (c >= '1' && c <= '8') {
            int n;

            n = c - '0';
            if (file + n > 8) {
                return NETCHESSZX_ERR_BOARD;
            }
            file += n;
        } else {
            uint8_t piece;
            int square;

            if (file >= 8) {
                return NETCHESSZX_ERR_BOARD;
            }
            piece = piece_from_fen(c);
            if (piece == NETCHESSZX_OFFBOARD) {
                return NETCHESSZX_ERR_BOARD;
            }
            square = 21 + file + ((rank - 1) * 10);
            pos->board[square] = piece;
            ++file;
        }
    }

    if (rank != 1 || file != 8) {
        return NETCHESSZX_ERR_BOARD;
    }
    return NETCHESSZX_OK;
}

static int parse_castle(netchesszx_position_t *pos, const char *castle)
{
    pos->castle_rights = 0u;

    if (strcmp(castle, "-") == 0) {
        return NETCHESSZX_OK;
    }

    while (*castle != '\0') {
        switch (*castle) {
        case 'K':
            if ((pos->castle_rights & NETCHESSZX_CASTLE_WK) != 0u) {
                return NETCHESSZX_ERR_CASTLE;
            }
            pos->castle_rights |= NETCHESSZX_CASTLE_WK;
            break;
        case 'Q':
            if ((pos->castle_rights & NETCHESSZX_CASTLE_WQ) != 0u) {
                return NETCHESSZX_ERR_CASTLE;
            }
            pos->castle_rights |= NETCHESSZX_CASTLE_WQ;
            break;
        case 'k':
            if ((pos->castle_rights & NETCHESSZX_CASTLE_BK) != 0u) {
                return NETCHESSZX_ERR_CASTLE;
            }
            pos->castle_rights |= NETCHESSZX_CASTLE_BK;
            break;
        case 'q':
            if ((pos->castle_rights & NETCHESSZX_CASTLE_BQ) != 0u) {
                return NETCHESSZX_ERR_CASTLE;
            }
            pos->castle_rights |= NETCHESSZX_CASTLE_BQ;
            break;
        default:
            return NETCHESSZX_ERR_CASTLE;
        }
        ++castle;
    }
    return NETCHESSZX_OK;
}

int netchesszx_fen_import(netchesszx_position_t *pos, const char *fen)
{
    char board[96];
    char side[4];
    char castle[8];
    char ep[4];
    char half[8];
    char full[8];
    const char *p;
    unsigned v;
    int rc;

    if (pos == 0 || fen == 0) {
        return NETCHESSZX_ERR_NULL;
    }

    netchesszx_position_init(pos);
    p = fen;

    rc = read_token(&p, board, sizeof(board));
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = read_token(&p, side, sizeof(side));
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = read_token(&p, castle, sizeof(castle));
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = read_token(&p, ep, sizeof(ep));
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = read_token(&p, half, sizeof(half));
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = read_token(&p, full, sizeof(full));
    if (rc != NETCHESSZX_OK) {
        return rc;
    }

    rc = parse_board(pos, board);
    if (rc != NETCHESSZX_OK) {
        return rc;
    }

    if (strcmp(side, "w") == 0) {
        pos->side_to_move = NETCHESSZX_WHITE;
    } else if (strcmp(side, "b") == 0) {
        pos->side_to_move = NETCHESSZX_BLACK;
    } else {
        return NETCHESSZX_ERR_SIDE;
    }

    rc = parse_castle(pos, castle);
    if (rc != NETCHESSZX_OK) {
        return rc;
    }

    if (strcmp(ep, "-") == 0) {
        pos->ep_square = NETCHESSZX_NO_SQUARE;
    } else {
        if (ep[0] < 'a' || ep[0] > 'h' ||
            (ep[1] != '3' && ep[1] != '6') || ep[2] != '\0') {
            return NETCHESSZX_ERR_EP;
        }
        pos->ep_square = netchesszx_square_index(ep[0], ep[1]);
    }

    rc = parse_uint_range(half, 255u, &v);
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    pos->halfmove_clock = (uint8_t)v;

    rc = parse_uint_range(full, 65535u, &v);
    if (rc != NETCHESSZX_OK || v == 0u) {
        return NETCHESSZX_ERR_NUMBER;
    }
    pos->fullmove_number = (uint16_t)v;

    while (is_space(*p)) {
        ++p;
    }
    if (*p != '\0') {
        return NETCHESSZX_ERR_TOKEN;
    }

    return NETCHESSZX_OK;
}

int netchesszx_fen_export(const netchesszx_position_t *pos, char *out, size_t cap)
{
    char *dst;
    size_t left;
    int rank;
    int rc;
    char ep[3];

    if (pos == 0 || out == 0) {
        return NETCHESSZX_ERR_NULL;
    }
    if (cap == 0u) {
        return NETCHESSZX_ERR_BUFFER;
    }

    dst = out;
    left = cap;
    *dst = '\0';

    for (rank = 8; rank >= 1; --rank) {
        int file;
        int empty;

        empty = 0;
        for (file = 0; file < 8; ++file) {
            int square;
            uint8_t piece;

            square = 21 + file + ((rank - 1) * 10);
            piece = pos->board[square];
            if (piece == NETCHESSZX_EMPTY) {
                ++empty;
            } else {
                char c;

                if (empty != 0) {
                    rc = append_char(&dst, &left, (char)('0' + empty));
                    if (rc != NETCHESSZX_OK) {
                        return rc;
                    }
                    empty = 0;
                }
                c = fen_from_piece(piece);
                if (c == '\0') {
                    return NETCHESSZX_ERR_BOARD;
                }
                rc = append_char(&dst, &left, c);
                if (rc != NETCHESSZX_OK) {
                    return rc;
                }
            }
        }
        if (empty != 0) {
            rc = append_char(&dst, &left, (char)('0' + empty));
            if (rc != NETCHESSZX_OK) {
                return rc;
            }
        }
        if (rank != 1) {
            rc = append_char(&dst, &left, '/');
            if (rc != NETCHESSZX_OK) {
                return rc;
            }
        }
    }

    rc = append_char(&dst, &left, ' ');
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = append_char(&dst, &left,
                     pos->side_to_move == NETCHESSZX_BLACK ? 'b' : 'w');
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = append_char(&dst, &left, ' ');
    if (rc != NETCHESSZX_OK) {
        return rc;
    }

    if (pos->castle_rights == 0u) {
        rc = append_char(&dst, &left, '-');
        if (rc != NETCHESSZX_OK) {
            return rc;
        }
    } else {
        if ((pos->castle_rights & NETCHESSZX_CASTLE_WK) != 0u) {
            rc = append_char(&dst, &left, 'K');
            if (rc != NETCHESSZX_OK) {
                return rc;
            }
        }
        if ((pos->castle_rights & NETCHESSZX_CASTLE_WQ) != 0u) {
            rc = append_char(&dst, &left, 'Q');
            if (rc != NETCHESSZX_OK) {
                return rc;
            }
        }
        if ((pos->castle_rights & NETCHESSZX_CASTLE_BK) != 0u) {
            rc = append_char(&dst, &left, 'k');
            if (rc != NETCHESSZX_OK) {
                return rc;
            }
        }
        if ((pos->castle_rights & NETCHESSZX_CASTLE_BQ) != 0u) {
            rc = append_char(&dst, &left, 'q');
            if (rc != NETCHESSZX_OK) {
                return rc;
            }
        }
    }

    rc = append_char(&dst, &left, ' ');
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    if (pos->ep_square == NETCHESSZX_NO_SQUARE) {
        rc = append_char(&dst, &left, '-');
        if (rc != NETCHESSZX_OK) {
            return rc;
        }
    } else {
        rc = netchesszx_square_to_coord(pos->ep_square, ep);
        if (rc != NETCHESSZX_OK) {
            return rc;
        }
        rc = append_str(&dst, &left, ep);
        if (rc != NETCHESSZX_OK) {
            return rc;
        }
    }

    rc = append_char(&dst, &left, ' ');
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = append_uint(&dst, &left, pos->halfmove_clock);
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = append_char(&dst, &left, ' ');
    if (rc != NETCHESSZX_OK) {
        return rc;
    }
    rc = append_uint(&dst, &left, pos->fullmove_number);
    if (rc != NETCHESSZX_OK) {
        return rc;
    }

    return NETCHESSZX_OK;
}

const char *netchesszx_error_string(int code)
{
    switch (code) {
    case NETCHESSZX_OK:
        return "ok";
    case NETCHESSZX_ERR_NULL:
        return "null";
    case NETCHESSZX_ERR_TOKEN:
        return "token";
    case NETCHESSZX_ERR_BOARD:
        return "board";
    case NETCHESSZX_ERR_SIDE:
        return "side";
    case NETCHESSZX_ERR_CASTLE:
        return "castle";
    case NETCHESSZX_ERR_EP:
        return "ep";
    case NETCHESSZX_ERR_NUMBER:
        return "number";
    case NETCHESSZX_ERR_BUFFER:
        return "buffer";
    case NETCHESSZX_ERR_MOVE:
        return "move";
    case NETCHESSZX_ERR_ILLEGAL:
        return "illegal";
    case NETCHESSZX_ERR_UNSUPPORTED:
        return "unsupported";
    default:
        return "unknown";
    }
}
