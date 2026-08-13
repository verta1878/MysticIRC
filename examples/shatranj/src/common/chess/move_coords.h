#ifndef NETCHESSZX_COMMON_CHESS_MOVE_COORDS_H
#define NETCHESSZX_COMMON_CHESS_MOVE_COORDS_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

#define NETCHESSZX_MOVE_COORDS_INVALID 0xffffu
#define NETCHESSZX_MOVE_FROM_INDEX(coords) ((uint8_t)(coords))
#define NETCHESSZX_MOVE_TO_INDEX(coords) ((uint8_t)((coords) >> 8))

#ifdef NETCHESSZX_SDCC_IY
uint16_t netchesszx_asm_move_parse_coords(const char *move) NETCHESSZX_FASTCALL;
#define netchesszx_move_parse_coords netchesszx_asm_move_parse_coords
#else
uint16_t netchesszx_move_parse_coords(const char *move) NETCHESSZX_FASTCALL;
#endif

#endif
