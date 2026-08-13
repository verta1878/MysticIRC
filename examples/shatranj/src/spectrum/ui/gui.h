#ifndef NETCHESSZX_SPECTRUM_GUI_H
#define NETCHESSZX_SPECTRUM_GUI_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

#define SPECTRUM_GUI_KEY_MENU 0x90u
#define SPECTRUM_GUI_KEY_MENU_FILE 0x91u
#define SPECTRUM_GUI_KEY_MENU_ABOUT 0x8cu
#define SPECTRUM_GUI_KEY_MENU_FLIP 0x8bu
#define SPECTRUM_GUI_KEY_MENU_DISCC 0x8du
#define SPECTRUM_GUI_KEY_MENU_REST 0x8eu
#define SPECTRUM_GUI_KEY_MENU_THEME 0x8fu
#define SPECTRUM_GUI_TURN_WHITE 0u
#define SPECTRUM_GUI_TURN_BLACK 1u
#define SPECTRUM_GUI_TURN_WHITE_CHECK 2u
#define SPECTRUM_GUI_TURN_BLACK_CHECK 3u
#define SPECTRUM_GUI_TURN_CLEAR 4u

#define SPECTRUM_GUI_MSG_PACK(id, kind) \
    ((uint16_t)(uint8_t)(id) | ((uint16_t)(uint8_t)(kind) << 8))
#define SPECTRUM_GUI_MSG_ID(packed) ((uint8_t)(packed))
#define SPECTRUM_GUI_MSG_KIND(packed) ((uint8_t)((packed) >> 8))

void spectrum_gui_set_status(const char *text) NETCHESSZX_FASTCALL;
void spectrum_gui_status_phase(uint8_t phase) NETCHESSZX_FASTCALL;
void spectrum_gui_set_status_error(const char *text) NETCHESSZX_FASTCALL;
void spectrum_gui_set_clock(uint8_t hour, uint8_t minute, uint8_t second);
void spectrum_gui_game_timer_start(void);
void spectrum_gui_game_timer_stop(void);
void spectrum_gui_move_timer_reset(void);
void spectrum_gui_set_turn_label(uint8_t mode) NETCHESSZX_FASTCALL;
void spectrum_gui_set_connected(uint8_t connected) NETCHESSZX_FASTCALL;
void spectrum_gui_notify(const char *text, uint8_t is_error);
void spectrum_gui_notify_persistent(const char *text) NETCHESSZX_FASTCALL;
void spectrum_gui_notify_success(const char *text) NETCHESSZX_FASTCALL;
void spectrum_gui_notify_msg(uint16_t packed) NETCHESSZX_FASTCALL;
void spectrum_gui_tick(void);
void spectrum_gui_set_board_view(uint8_t local_black) NETCHESSZX_FASTCALL;
uint8_t spectrum_gui_is_board_flipped(void);
void spectrum_gui_toggle_board_view(void);
/* Host judges copy a snapshot; product reads gui.c's immutable low-RAM view. */
#ifdef NETCHESSZX_HOST_SESSION_TEST
void spectrum_gui_set_board_snapshot(const char *cells) NETCHESSZX_FASTCALL;
#else
#define spectrum_gui_set_board_snapshot(cells) ((void)0)
#endif
void spectrum_gui_set_board_pieces_visible(uint8_t visible) NETCHESSZX_FASTCALL;
void spectrum_gui_hide_board_pieces(void);
void spectrum_gui_draw_board(void);
void spectrum_gui_redraw_board_view(void);
void spectrum_gui_restore_board_area(void);
void spectrum_gui_animate_board_pieces(void);
void spectrum_gui_draw_status(void);
void spectrum_gui_restore_side_panels(void);
uint8_t spectrum_gui_side_panels_visible(void);
void spectrum_gui_redraw_board_squares(void);
void spectrum_gui_reset_moves(void);
void spectrum_gui_reset_logs(void);
void spectrum_gui_add_move(const char *ply, const char *move);
void spectrum_gui_remove_last_move(uint16_t ply);
void spectrum_gui_add_chat(char who, const char *text);
void spectrum_gui_prepare_move(const char *move) NETCHESSZX_FASTCALL;
void spectrum_gui_apply_move(const char *move) NETCHESSZX_FASTCALL;
void spectrum_gui_set_input(const char *text) NETCHESSZX_FASTCALL;
void spectrum_gui_set_input_edit(const char *text, uint8_t len, uint8_t cursor);
void spectrum_gui_input_cell(uint8_t pos, char c, uint8_t cursor);
void spectrum_gui_redraw_square(uint8_t row, uint8_t col);
void spectrum_gui_mark_cursor(uint8_t row, uint8_t col, uint8_t selected);
void spectrum_gui_clear_cursor_coords(void);
uint8_t spectrum_gui_show_about(void);
uint8_t spectrum_gui_about_visible(void);
uint8_t spectrum_gui_show_fileui(void);
uint8_t spectrum_gui_fileui_visible(void);
uint8_t spectrum_gui_poll_key(void);
uint8_t spectrum_gui_handle_menu_key(uint8_t key) NETCHESSZX_FASTCALL;
void spectrum_gui_hide_menu(void);

#endif
