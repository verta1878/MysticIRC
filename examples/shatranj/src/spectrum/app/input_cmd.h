#ifndef NETCHESSZX_SPECTRUM_APP_INPUT_CMD_H
#define NETCHESSZX_SPECTRUM_APP_INPUT_CMD_H

#include <stdint.h>

#define SPECTRUM_INPUT_CMD_NONE 0u
#define SPECTRUM_INPUT_CMD_SAVE 1u
#define SPECTRUM_INPUT_CMD_LOAD 2u
#define SPECTRUM_INPUT_CMD_RESIGN 3u
#define SPECTRUM_INPUT_CMD_DRAW 4u
#define SPECTRUM_INPUT_CMD_TAKEBACK 5u

void netchesszx_input_edit_render_overlay(void);
void netchesszx_input_edit_begin_empty_overlay(void);
void netchesszx_input_edit_stop_clear_overlay(void);
void netchesszx_input_edit_key_overlay(uint8_t key) __z88dk_fastcall;
void netchesszx_input_edit_history_add_overlay(const char *text) __z88dk_fastcall;

#endif
