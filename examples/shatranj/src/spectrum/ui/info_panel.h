#ifndef NETCHESSZX_SPECTRUM_UI_INFO_PANEL_H
#define NETCHESSZX_SPECTRUM_UI_INFO_PANEL_H

#include <stdint.h>

void spectrum_info_show_game(void);
void spectrum_info_show_setup(void);
void spectrum_info_show_game_setup(void);
void spectrum_info_show_preflight(void);
void spectrum_info_clear_tail(uint8_t row) __z88dk_fastcall;
void spectrum_info_line(const char *line) __z88dk_fastcall;

#endif
