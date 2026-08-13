#ifndef NETCHESSZX_POSITION_H
#define NETCHESSZX_POSITION_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NETCHESSZX_BOARD_SIZE 120

#define NETCHESSZX_EMPTY      0x00u
#define NETCHESSZX_OFFBOARD   0x7Fu
#define NETCHESSZX_WHITE      0x00u
#define NETCHESSZX_BLACK      0x80u
#define NETCHESSZX_COLOR_MASK 0x80u
#define NETCHESSZX_TYPE_MASK  0x78u

#define NETCHESSZX_PAWN       0x08u
#define NETCHESSZX_KNIGHT     0x10u
#define NETCHESSZX_BISHOP     0x18u
#define NETCHESSZX_ROOK       0x20u
#define NETCHESSZX_QUEEN      0x28u
#define NETCHESSZX_KING       0x30u

#define NETCHESSZX_CASTLE_WK  0x01u
#define NETCHESSZX_CASTLE_WQ  0x02u
#define NETCHESSZX_CASTLE_BK  0x04u
#define NETCHESSZX_CASTLE_BQ  0x08u

#define NETCHESSZX_NO_SQUARE  (-1)

enum {
    NETCHESSZX_OK = 0,
    NETCHESSZX_ERR_NULL = -1,
    NETCHESSZX_ERR_TOKEN = -2,
    NETCHESSZX_ERR_BOARD = -3,
    NETCHESSZX_ERR_SIDE = -4,
    NETCHESSZX_ERR_CASTLE = -5,
    NETCHESSZX_ERR_EP = -6,
    NETCHESSZX_ERR_NUMBER = -7,
    NETCHESSZX_ERR_BUFFER = -8,
    NETCHESSZX_ERR_MOVE = -9,
    NETCHESSZX_ERR_ILLEGAL = -10,
    NETCHESSZX_ERR_UNSUPPORTED = -11
};

typedef struct {
    uint8_t board[NETCHESSZX_BOARD_SIZE];
    uint8_t side_to_move;
    uint8_t castle_rights;
    int8_t ep_square;
    uint8_t halfmove_clock;
    uint16_t fullmove_number;
} netchesszx_position_t;

void netchesszx_position_init(netchesszx_position_t *pos);
int netchesszx_fen_import(netchesszx_position_t *pos, const char *fen);
int netchesszx_fen_export(const netchesszx_position_t *pos, char *out, size_t cap);

int8_t netchesszx_square_index(char file, char rank);
int netchesszx_square_to_coord(int8_t square, char out[3]);
const char *netchesszx_error_string(int code);

#ifdef __cplusplus
}
#endif

#endif
