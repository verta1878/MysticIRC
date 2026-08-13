#ifndef NETCHESSZX_SPECTRUM_UI_RENDER_H
#define NETCHESSZX_SPECTRUM_UI_RENDER_H

#include <stdint.h>
#include "spectrum/render_status.h"

void spectrum_render_board(const char *board) __z88dk_fastcall;
void spectrum_render_board_area(const char *board) __z88dk_fastcall;
void spectrum_render_board_coords(void);
void spectrum_render_board_coord_mark(const char *spec) __z88dk_fastcall;
void spectrum_render_status(const char *text) __z88dk_fastcall;
void spectrum_render_clock(const char *text) __z88dk_fastcall;
void spectrum_render_game_timer_clear(const char *text) __z88dk_fastcall;
void spectrum_render_game_timer_char(const char *spec) __z88dk_fastcall;
void spectrum_render_menu_timer_char(const char *spec) __z88dk_fastcall;
void spectrum_render_turn_label(uint8_t mode) __z88dk_fastcall;
void spectrum_render_notice(const char *text) __z88dk_fastcall;
void spectrum_render_notice_error(const char *text) __z88dk_fastcall;
void spectrum_render_notice_success(const char *text) __z88dk_fastcall;
void spectrum_render_connection(uint8_t connected) __z88dk_fastcall;
void spectrum_render_menu(uint8_t visible) __z88dk_fastcall;
void spectrum_render_square(const char *spec) __z88dk_fastcall;
void spectrum_render_square_attr(const char *spec) __z88dk_fastcall;
void spectrum_render_square_with_hint(const char *spec) __z88dk_fastcall;
void spectrum_render_square_mark(const char *spec) __z88dk_fastcall;
void spectrum_render_square_mark_with_hint(const char *spec) __z88dk_fastcall;
void spectrum_render_moves(const char *moves) __z88dk_fastcall;
void spectrum_render_move_at(const char *line) __z88dk_fastcall;
void spectrum_render_moves_scroll(void);
void spectrum_render_chat(const char *chat) __z88dk_fastcall;
void spectrum_render_chat_at(const char *line) __z88dk_fastcall;
void spectrum_render_chat_scroll(void);
void spectrum_render_input(const char *text) __z88dk_fastcall;
void spectrum_render_input_cell(const char *spec) __z88dk_fastcall;
uint8_t spectrum_render_about(void);
#ifdef NETCHESSZX_NEXT_BANKING
void spectrum_render_about_off(void);
#endif
#ifdef NETCHESSZX_NEXT_BANKING
void spectrum_next_sprites_hide_all(void);
#endif
void spectrum_render_ikkle_at(const char *spec) __z88dk_fastcall;
void spectrum_render_fileui_frame(void);
void spectrum_render_fileui_select(uint16_t slot_on) __z88dk_fastcall;

uint8_t spectrum_key_edit_pressed(void);
uint8_t spectrum_key_poll(void);

#endif
