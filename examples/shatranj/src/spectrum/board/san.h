#ifndef NETCHESSZX_SPECTRUM_BOARD_SAN_H
#define NETCHESSZX_SPECTRUM_BOARD_SAN_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

#define SPECTRUM_SAN_TEXT_MAX 12u

uint8_t spectrum_board_move_san_base(const char *move, char *out);
uint8_t spectrum_board_san_append_suffix(char *san) NETCHESSZX_FASTCALL;

#endif
