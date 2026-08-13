#ifndef NETCHESSZX_SPECTRUM_PLATFORM_INPUT_H
#define NETCHESSZX_SPECTRUM_PLATFORM_INPUT_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

void spectrum_input_frame_tick(void);
uint8_t spectrum_input_poll_event(void);
void spectrum_input_flush_until_release(void);
void spectrum_input_suppress_until_release(uint8_t key) NETCHESSZX_FASTCALL;
uint8_t spectrum_input_parse_move(const char *text, char *move);

#endif
