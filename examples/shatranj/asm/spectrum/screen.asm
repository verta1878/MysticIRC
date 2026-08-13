SECTION code_user

PUBLIC _spectrum_render_board
PUBLIC _spectrum_render_board_area
PUBLIC _spectrum_render_status
PUBLIC _spectrum_render_status_error
PUBLIC _spectrum_render_clock
PUBLIC _spectrum_render_game_timer_clear
PUBLIC _spectrum_render_game_timer_char
PUBLIC _spectrum_render_menu_timer_char
PUBLIC _spectrum_render_turn_label
PUBLIC _spectrum_render_notice
PUBLIC _spectrum_render_notice_error
PUBLIC _spectrum_render_notice_success
PUBLIC _spectrum_render_connection
PUBLIC _spectrum_render_menu
PUBLIC _spectrum_info_show_game
PUBLIC _spectrum_render_board_coord_mark
PUBLIC _spectrum_info_show_setup
PUBLIC _spectrum_info_show_game_setup
PUBLIC _spectrum_info_show_preflight
PUBLIC _spectrum_info_clear_tail
PUBLIC _spectrum_info_line
PUBLIC _spectrum_render_board_coords
PUBLIC _spectrum_render_square
PUBLIC _spectrum_render_square_attr
PUBLIC _spectrum_render_square_with_hint
PUBLIC _spectrum_render_square_mark
PUBLIC _spectrum_render_square_mark_with_hint
PUBLIC compute_square_bc
PUBLIC compute_attr_base
PUBLIC set_square_attr_2x2
PUBLIC compute_screen_base
PUBLIC board_row
PUBLIC board_col
PUBLIC tmp_attr
PUBLIC _spectrum_board_show_legal_hints
PUBLIC _spectrum_render_moves
PUBLIC _spectrum_render_move_at
PUBLIC _spectrum_render_moves_scroll
PUBLIC _spectrum_render_chat
PUBLIC _spectrum_render_chat_at
PUBLIC _spectrum_render_chat_scroll
PUBLIC _spectrum_render_input
PUBLIC _spectrum_render_input_cell
PUBLIC _spectrum_key_edit_pressed
PUBLIC _spectrum_key_poll
PUBLIC _spectrum_input_frame_tick
PUBLIC _spectrum_input_poll_event
PUBLIC _spectrum_input_flush_until_release
PUBLIC _spectrum_input_suppress_until_release
PUBLIC _netchesszx_board_theme_apply
PUBLIC _spectrum_input_parse_move
PUBLIC _netchesszx_setup_render_edit_line
PUBLIC _netchesszx_setup_compute_visible
PUBLIC _netchesszx_setup_paint_attrs
PUBLIC _netchesszx_setup_render_rows
PUBLIC _netchesszx_setup_render_overlay
PUBLIC _netchesszx_setup_step_overlay
PUBLIC _spectrum_board_clear_legal_hints
PUBLIC _spectrum_board_view_redraw_square
PUBLIC _spectrum_board_view_flipped
PUBLIC board_theme_hint_inks
IFDEF NETCHESSZX_NEXT
PUBLIC _spectrum_next_sprites_hide_all
EXTERN nextreg_read
EXTERN nextreg_write
ENDIF

EXTERN _spectrum_gui_board_flipped
EXTERN _spectrum_gui_redraw_square
EXTERN _netchesszx_movement_hints
EXTERN _netchesszx_hinted_rows
EXTERN _netchesszx_board_theme_index
EXTERN _netchesszx_board_light_attr
EXTERN _netchesszx_board_dark_attr
EXTERN _spectrum_overlay_exec
EXTERN _spectrum_overlay_exec_cached
EXTERN _side_to_move
EXTERN _castle_rights
EXTERN _ep_square

SCREEN_BASE EQU 0x4000
ATTR_BASE   EQU 0x5800
NETCHESSZX_ASSET_BASE EQU 0x6000
NETCHESSZX_RULES_BOARD_BASE EQU 0x5fa0
NETCHESSZX_OVERLAY_CONTEXT EQU 0x5fe0
SPECTRUM_OVL_INPUT_EDIT EQU 9
SPECTRUM_OVL_INPUT_EDIT_PARSE_MOVE_PRIVATE EQU 5
SPECTRUM_OVL_MENU_CONFIG EQU 6
SPECTRUM_OVL_MENU_CONFIG_RUN EQU 0
SPECTRUM_OVL_MENU_CONFIG_PAINT_ATTRS EQU 1
SPECTRUM_OVL_MENU_CONFIG_VALIDATE_IP EQU 2
SPECTRUM_OVL_MENU_CONFIG_EDIT_LINE EQU 3
SPECTRUM_OVL_MENU_CONFIG_RENDER EQU 4
SPECTRUM_OVL_HINTS EQU 0
SPECTRUM_OVL_HINTS_SHOW EQU 2
SPECTRUM_OVL_HINTS_CLEAR EQU 3
SPECTRUM_OVL_SETUP EQU 8
SPECTRUM_OVL_SETUP_STEP EQU 0
SPECTRUM_OVL_SETUP_COMPUTE_VISIBLE_PRIVATE EQU 1
SPECTRUM_OVL_CTX_HINTS_BOARD_LO EQU 0
SPECTRUM_OVL_CTX_HINTS_BOARD_HI EQU 1
SPECTRUM_OVL_CTX_HINTS_SIDE_TO_MOVE EQU 2
SPECTRUM_OVL_CTX_HINTS_SQUARE EQU 3
SPECTRUM_OVL_CTX_HINTS_CASTLE EQU 4
SPECTRUM_OVL_CTX_HINTS_EP EQU 5
DEFC _spectrum_board_view_redraw_square = _spectrum_gui_redraw_square
DEFC _spectrum_board_view_flipped = _spectrum_gui_board_flipped
expand_2x EQU NETCHESSZX_ASSET_BASE
font_lut EQU NETCHESSZX_ASSET_BASE + 16
chat_icon_white EQU NETCHESSZX_ASSET_BASE + 26
chat_icon_black EQU NETCHESSZX_ASSET_BASE + 32
timer_ikkle_packed EQU NETCHESSZX_ASSET_BASE + 38
font_packed EQU NETCHESSZX_ASSET_BASE + 166
badge_pattern EQU NETCHESSZX_ASSET_BASE + 454
conn_pattern EQU NETCHESSZX_ASSET_BASE + 462
rank_digit_patterns EQU NETCHESSZX_ASSET_BASE + 470
file_letter_patterns EQU NETCHESSZX_ASSET_BASE + 510
psfc_piece_chars EQU NETCHESSZX_ASSET_BASE + 550
title_msg EQU NETCHESSZX_ASSET_BASE + 556
chat_msg EQU NETCHESSZX_ASSET_BASE + 567
session_setup_msg EQU NETCHESSZX_ASSET_BASE + 572
game_setup_msg EQU NETCHESSZX_ASSET_BASE + 589
preflight_setup_msg EQU NETCHESSZX_ASSET_BASE + 600
input_prompt_msg EQU NETCHESSZX_ASSET_BASE + 622
white_turn_msg EQU NETCHESSZX_ASSET_BASE + 625
black_turn_msg EQU NETCHESSZX_ASSET_BASE + 639
white_check_msg EQU NETCHESSZX_ASSET_BASE + 653
black_check_msg EQU NETCHESSZX_ASSET_BASE + 665
menu_cursor_masks EQU NETCHESSZX_ASSET_BASE + 677
tab_label_file EQU NETCHESSZX_ASSET_BASE + 701
tab_label_discc EQU NETCHESSZX_ASSET_BASE + 706
tab_label_reset EQU NETCHESSZX_ASSET_BASE + 712
tab_label_flip EQU NETCHESSZX_ASSET_BASE + 718
tab_label_theme EQU NETCHESSZX_ASSET_BASE + 723
tab_label_about EQU NETCHESSZX_ASSET_BASE + 729
moves_white_msg EQU NETCHESSZX_ASSET_BASE + 735
moves_black_msg EQU NETCHESSZX_ASSET_BASE + 741
banner_info_top_msg EQU NETCHESSZX_ASSET_BASE + 747
board_theme_mark_inks EQU NETCHESSZX_ASSET_BASE + 781
board_theme_light_attrs EQU NETCHESSZX_ASSET_BASE + 786
board_theme_dark_attrs EQU NETCHESSZX_ASSET_BASE + 791
version_banner_msg EQU NETCHESSZX_ASSET_BASE + 796
piece_sprites_16x16 EQU NETCHESSZX_ASSET_BASE + 812

NETCHESSZX_GAME_BOARD_TOP_ROW EQU 5
NETCHESSZX_GAME_BOARD_LEFT_COL EQU 1
IFDEF NETCHESSZX_NEXT
NEXT_SPRITE_Y_BASE EQU 32 + (NETCHESSZX_GAME_BOARD_TOP_ROW * 8)
NEXT_SPRITE_X_BASE EQU 32 + (NETCHESSZX_GAME_BOARD_LEFT_COL * 8)
NEXT_SPRITE_SLOT_PORT EQU 0x303B
NEXT_SPRITE_ATTR_PORT EQU 0x0057
NEXT_SPRITE_VISIBLE EQU 0x80
NEXT_BOARD_SPRITE_SLOT_BASE EQU 0
NEXT_PIECE_SPRITE_SLOT_BASE EQU 64
NEXT_MARKER_SPRITE_SLOT_BASE EQU 96
NEXT_BOARD_PATTERN_BASE EQU 12
NEXT_MARKER_PATTERN_BASE EQU 22
NEXT_MARKER_FLAG_HINT EQU 1
NEXT_MARKER_FLAG_MARK EQU 2
NEXT_MARKER_FLAG_SELECTED EQU 4
NEXT_EMPTY_SLOT EQU 0xff
NEXTREG_SELECT_PORT EQU 0x243b
NEXTREG_DATA_PORT EQU 0x253b
NEXTREG_PALETTE_INDEX EQU 0x40
NEXTREG_PALETTE_CONTROL EQU 0x43
NEXTREG_PALETTE_VALUE_9 EQU 0x44
NEXTREG_ULA_CONTROL EQU 0x68
NEXT_BOARD_COORD_LINE_ATTR EQU 0x81
NEXT_BOARD_COORD_SELECTED_ATTR EQU 0x8a
NEXT_BOARD_COORD_INK1_INDEX EQU 225
NEXT_BOARD_COORD_INK2_INDEX EQU 226
NEXT_BOARD_COORD_PAPER0_INDEX EQU 232
NEXT_BOARD_COORD_PAPER1_INDEX EQU 233
ENDIF
NETCHESSZX_INFO_PANEL_COL EQU 18
NETCHESSZX_INFO_TEXT_COL  EQU (NETCHESSZX_INFO_PANEL_COL * 2) + 1
NETCHESSZX_INFO_HEADER_ROW EQU 5
NETCHESSZX_INFO_HEADER_HLINE_ROW EQU 6
NETCHESSZX_INFO_SETUP_GAME_HEADER_ROW EQU 12
NETCHESSZX_INFO_SETUP_GAME_HLINE_ROW EQU 13
NETCHESSZX_INFO_PANEL_CLEAR_FIRST_ROW EQU NETCHESSZX_INFO_HEADER_ROW
NETCHESSZX_INFO_NOTICE_ROW EQU 21
NETCHESSZX_INFO_PANEL_CLEAR_LIMIT_ROW EQU NETCHESSZX_INFO_NOTICE_ROW + 1
NETCHESSZX_INFO_SETUP_LINE_BASE_ROW EQU 7
NETCHESSZX_INFO_MOVES_FIRST_ROW EQU 6
NETCHESSZX_INFO_MOVES_FIRST_Y EQU 51
NETCHESSZX_INFO_MOVES_CLEAR_Y EQU 50
NETCHESSZX_INFO_MOVES_CLEAR_HEIGHT EQU 43
NETCHESSZX_MOVE_ROWS EQU 7
NETCHESSZX_INFO_TIGHT_LINE_STEP EQU 6
NETCHESSZX_INFO_CHAT_TITLE_ROW EQU 12
NETCHESSZX_INFO_CHAT_HLINE_ROW EQU 13
NETCHESSZX_INFO_CHAT_FIRST_ROW EQU 16
NETCHESSZX_INFO_CHAT_FIRST_Y EQU 110
NETCHESSZX_INFO_CHAT_CLEAR_Y EQU 108
NETCHESSZX_INFO_CHAT_CLEAR_HEIGHT EQU 67
NETCHESSZX_CHAT_ROWS EQU 9
NETCHESSZX_STATUS_ROW     EQU 22
NETCHESSZX_INPUT_ROW       EQU 23
NETCHESSZX_MOVE_LINES_BASE EQU 0x5cb6
NETCHESSZX_MOVE_SLOT_SIZE EQU 32
NETCHESSZX_MOVE_BLACK_OFFSET EQU 18
NETCHESSZX_MOVE_BLACK_COL EQU NETCHESSZX_INFO_TEXT_COL + 14
NETCHESSZX_CHAT_SLOT_SIZE EQU 28
NETCHESSZX_CHAT_LINES_BASE EQU 0x5d96
NETCHESSZX_CHAT_TEXT_OFFSET EQU 7
NETCHESSZX_CHAT_ICON_BYTE_COL EQU NETCHESSZX_INFO_PANEL_COL
NETCHESSZX_CHAT_TIME_COL EQU NETCHESSZX_INFO_TEXT_COL + 2
NETCHESSZX_CHAT_TEXT_COL EQU NETCHESSZX_INFO_TEXT_COL + 8
NETCHESSZX_TOP_TIMER_ROW  EQU 2
NETCHESSZX_TOP_TIMER_SCAN EQU 2
NETCHESSZX_TOP_TIMER_COL  EQU 41
NETCHESSZX_TOP_TURN_ROW   EQU 3
NETCHESSZX_TOP_TURN_SCAN  EQU 2
NETCHESSZX_TOP_TURN_CLEAR_COL EQU 51
NETCHESSZX_TOP_TURN_BYTE_COL EQU 25
NETCHESSZX_TOP_TURN_WIDTH_BYTES EQU 7
NETCHESSZX_STATUS_CLOCK_COL EQU 55
NETCHESSZX_STATUS_TEXT_COL EQU 1
NETCHESSZX_STATUS_SCAN EQU 2
NETCHESSZX_STATUS_LEFT_BYTES EQU 27
NETCHESSZX_MOVES_HEADER_WHITE_ICON_BYTE_COL EQU NETCHESSZX_INFO_PANEL_COL
NETCHESSZX_MOVES_HEADER_BLACK_ICON_BYTE_COL EQU NETCHESSZX_INFO_PANEL_COL + 7
NETCHESSZX_MOVES_HEADER_WHITE_TEXT_COL EQU NETCHESSZX_INFO_TEXT_COL + 3
NETCHESSZX_MOVES_HEADER_BLACK_TEXT_COL EQU NETCHESSZX_INFO_TEXT_COL + 17
NETCHESSZX_MOVES_HEADER_DIVIDER_BYTE_COL EQU NETCHESSZX_INFO_PANEL_COL + 7
NETCHESSZX_MENU_ROW EQU 2
NETCHESSZX_MENU_SCAN EQU 2
NETCHESSZX_MENU_CURSOR_SCAN EQU 1
NETCHESSZX_MENU_ABOUT_COL EQU 0
NETCHESSZX_MENU_DISCC_COL EQU 7
NETCHESSZX_MENU_REST_COL EQU 13
NETCHESSZX_MENU_FLIP_COL EQU 18
NETCHESSZX_MENU_THEME_COL EQU 24
NETCHESSZX_BANNER_INFO_COL EQU 18

ATTR_TEXT       EQU 0x07
ATTR_BANNER_TOP EQU 0x47
ATTR_BANNER_BOT EQU 0x07
ATTR_STATUS     EQU 0x38
ATTR_STATUS_ERROR EQU 0x3a
ATTR_TIMER      EQU 0x07
ATTR_TIMER_INV  EQU 0x38
ATTR_TIMER_CHECK_WHITE EQU 0x06
ATTR_TIMER_CHECK_BLACK EQU 0x30
ATTR_NOTICE     EQU 0x06
ATTR_ERROR      EQU 0x42
ATTR_SUCCESS    EQU 0x44
ATTR_CONN_OFF   EQU 0x3a
ATTR_CONN_MQTT  EQU 0x3e
ATTR_CONN_ON    EQU 0x3c
ATTR_MOVES_TITLE EQU 0x06
ATTR_CHAT_TITLE  EQU 0x06
ATTR_CHAT_BLACK  EQU 0x38
SECTION bss_user

board_ptr:    DEFS 2
status_ptr:   DEFS 2
notice_ptr:   DEFS 2
text_ptr:     DEFS 2
move_ptr:     DEFS 2
tmp_row:      DEFS 1
tmp_col:      DEFS 1
tmp_char:     DEFS 1
tmp_attr:     DEFS 1
tmp_scan:     DEFS 1
current_attr: DEFS 1
board_row:    DEFS 1
board_col:    DEFS 1
board_iter:   DEFS 2
piece_row:    DEFS 1
piece_col:    DEFS 1
piece_char:   DEFS 1
piece_scan:   DEFS 1
scaled_row:   DEFS 1
scaled_col:   DEFS 1
conn_attr:    DEFS 1
sprite_ptr:   DEFS 2
mark_mode:    DEFS 1
key_last:     DEFS 1
key_repeat_timer: DEFS 1
key_event:    DEFS 1
key_raw:      DEFS 1
key_suppress: DEFS 1
IFDEF NETCHESSZX_NEXT
piece_slot_squares: DEFS 32
marker_slot_squares: DEFS 32
marker_slot_flags: DEFS 32
ENDIF

SECTION code_user

_spectrum_render_board:
    ld (board_ptr), hl
IFDEF NETCHESSZX_NEXT
    call next_board_coord_palette_sync
ENDIF
    call clear_screen
    call draw_banner
    call hide_menu
    call restore_board_frame_attrs
    call draw_board_coords
    call draw_board
    jp draw_board_frame

_spectrum_render_board_area:
    ld (board_ptr), hl
    call clear_board_coords
    call restore_board_frame_attrs
    call draw_board_coords
    call draw_board
    jp draw_board_frame

_spectrum_render_board_coords:
    call clear_board_coords
    call restore_board_frame_attrs
    call draw_board_coords
    jp draw_board_frame

_spectrum_render_board_coord_mark:
    ld a, (hl)
    ld (board_row), a
    inc hl
    ld a, (hl)
    ld (board_col), a
    inc hl
    ld a, (hl)
    or a
    jr z, srcm_text
IFDEF NETCHESSZX_NEXT
    ld a, (_netchesszx_board_theme_index)
    or a
    jr z, srcm_selected_classic
    ld a, NEXT_BOARD_COORD_SELECTED_ATTR
    jr srcm_attr_ready
srcm_selected_classic:
ENDIF
    ld a, (_netchesszx_board_light_attr)
    jr srcm_attr_ready
srcm_text:
    call board_light_line_attr
srcm_attr_ready:
    ld (tmp_attr), a

    ld a, (board_col)
    add a, a
    add a, NETCHESSZX_GAME_BOARD_LEFT_COL
    ld c, a
    ld a, NETCHESSZX_GAME_BOARD_TOP_ROW - 1
    call compute_attr_base
    ld a, c
    add a, l
    ld l, a
    ld a, (tmp_attr)
    ld (hl), a
    inc hl
    ld (hl), a

    ld a, (board_row)
    add a, a
    add a, NETCHESSZX_GAME_BOARD_TOP_ROW
    call compute_attr_base
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL - 1
    add a, l
    ld l, a
    ld a, (tmp_attr)
    ld (hl), a
    ld de, 32
    add hl, de
    ld (hl), a
    ret

_spectrum_render_status:
    ld a, ATTR_STATUS
    jr render_status_common

_spectrum_render_status_error:
    ld a, ATTR_STATUS_ERROR

render_status_common:
    ; Caller pads the text with spaces to the full left width; ikkle drawing
    ; self-clears each cell, so no destructive pre-clear (avoids flash).
    ld (status_ptr), hl
    ld (current_attr), a
    ld b, NETCHESSZX_STATUS_ROW
    ld c, NETCHESSZX_STATUS_TEXT_COL
    ld d, NETCHESSZX_STATUS_SCAN
    call store_tmp_rcs
    ld hl, (status_ptr)
    jp draw_ikkle_text_at

_spectrum_render_clock:
    ld a, ATTR_STATUS
    ld (current_attr), a
    ld b, NETCHESSZX_STATUS_ROW
    ld c, NETCHESSZX_STATUS_CLOCK_COL
    ld d, NETCHESSZX_STATUS_SCAN
    call store_tmp_rcs
    jp draw_ikkle_text_at

_spectrum_render_game_timer_clear:
    ld (text_ptr), hl
    ld a, ATTR_TIMER
    ld (current_attr), a
    ld b, NETCHESSZX_TOP_TIMER_ROW
    ld c, NETCHESSZX_TOP_TIMER_COL
    ld de, NETCHESSZX_TOP_TIMER_SCAN * 256 + 12
    call clear_ikkle_region
    ld hl, (text_ptr)
    jp draw_ikkle_text_at

; Game and menu timer chars share position (row 2, scan 2, col base 41);
; only the attribute differs between the closed and taboption states.
_spectrum_render_game_timer_char:
    ld a, ATTR_TIMER
    jr render_timer_char_common
_spectrum_render_menu_timer_char:
    ld a, ATTR_STATUS
render_timer_char_common:
    ld (current_attr), a
    ld a, (hl)
    add a, NETCHESSZX_TOP_TIMER_COL
    ld (tmp_col), a
    inc hl
    ld a, (hl)
    ld (tmp_char), a
    inc hl
    ld a, (hl)
    ld (mark_mode), a
    ld a, NETCHESSZX_TOP_TIMER_ROW
    ld (tmp_row), a
    ld a, NETCHESSZX_TOP_TIMER_SCAN
    ld (tmp_scan), a

    ld a, (tmp_row)
    call compute_screen_base
    ld a, (tmp_scan)
    add a, h
    ld h, a
    ld a, (tmp_col)
    srl a
    add a, l
    ld l, a
    ld a, (tmp_col)
    ld c, a
    ld a, (mark_mode)
    or a
    jr z, srtc_no_clear
    call ikkle_clear_cell_hl
srtc_no_clear:
    push hl
    ld a, (tmp_row)
    call attr_cell_for_tmpcol
    ld a, (current_attr)
    ld (hl), a
    pop hl

    ld a, (tmp_char)
    cp 33
    ret c
    cp 128
    ret nc
    cp 96
    jr c, srtc_no_fold
    sub 32
srtc_no_fold:
    sub 32
    add a, a
    ld e, a
    ld d, 0
    push hl
    ld hl, timer_ikkle_packed
    add hl, de
    ld d, (hl)
    inc hl
    ld e, (hl)
    pop hl
    jp ikkle_blit_de_hl

_spectrum_render_turn_label:
    ld a, l
    ld (mark_mode), a
    ld a, ATTR_TIMER
    ld (current_attr), a
    call clear_turn_strip
    ld a, (mark_mode)
    cp 4
    ret nc
    cp 2
    jr z, srtl_white_check
    cp 3
    jr z, srtl_black_check
    or a
    ld a, NETCHESSZX_TOP_TURN_CLEAR_COL
    jr nz, srtl_black
    ld hl, white_turn_msg
    jr srtl_draw
srtl_black:
    ld hl, black_turn_msg
    jr srtl_draw
srtl_white_check:
    ld a, ATTR_TIMER_CHECK_WHITE
    ld (current_attr), a
    ld a, NETCHESSZX_TOP_TURN_CLEAR_COL + 2
    ld hl, white_check_msg
    jr srtl_draw
srtl_black_check:
    ld a, ATTR_TIMER_CHECK_BLACK
    ld (current_attr), a
    ld a, NETCHESSZX_TOP_TURN_CLEAR_COL + 2
    ld hl, black_check_msg
srtl_draw:
    ld (tmp_col), a
    ld a, NETCHESSZX_TOP_TURN_ROW
    ld (tmp_row), a
    ld a, NETCHESSZX_TOP_TURN_SCAN
    ld (tmp_scan), a
    jp draw_ikkle_text_at

clear_turn_strip:
    ld a, NETCHESSZX_TOP_TURN_ROW
    call compute_screen_base
    ld a, NETCHESSZX_TOP_TURN_BYTE_COL
    add a, l
    ld l, a
    ld c, 8
cts_scan:
    ld b, NETCHESSZX_TOP_TURN_WIDTH_BYTES
    push hl
    xor a
cts_fill:
    ld (hl), a
    inc hl
    djnz cts_fill
    pop hl
    inc h
    dec c
    jr nz, cts_scan
    ret

_spectrum_render_notice:
    ld a, ATTR_NOTICE
    jr render_notice_common

_spectrum_render_notice_error:
    ld a, ATTR_ERROR
    jr render_notice_common

_spectrum_render_notice_success:
    ld a, ATTR_SUCCESS

render_notice_common:
    ld (notice_ptr), hl
    ld (current_attr), a
    call clear_notice_row
    ld hl, (notice_ptr)
    call calc_len64
    ld (tmp_col), a
    ld a, NETCHESSZX_INFO_NOTICE_ROW
    ld (tmp_row), a
    ld a, 2
    ld (tmp_scan), a
    ld hl, (notice_ptr)
    jp draw_ikkle_text_at

_spectrum_render_connection:
    ld a, l
    or a
    jr z, src_off
    cp 1
    jr z, src_mqtt
    ld a, ATTR_CONN_ON
    jr src_set
src_mqtt:
    ld a, ATTR_CONN_MQTT
    jr src_set
src_off:
    ld a, ATTR_CONN_OFF
src_set:
    ld (conn_attr), a
    jp draw_connection_indicator

_spectrum_render_menu:
    ld a, l
    or a
    jp z, hide_menu
    bit 7, a
    jp nz, draw_menu_partial
    jp draw_menu

_spectrum_info_show_game:
    call clear_right_panel_rows
    jp draw_static_panels

_spectrum_info_show_setup:
    call clear_right_panel_rows
    jr draw_connection_setup_header

_spectrum_info_show_game_setup:
    ld b, NETCHESSZX_INFO_SETUP_GAME_HEADER_ROW
    ld hl, game_setup_msg
    call draw_setup_header_at_b
    ld a, NETCHESSZX_INFO_SETUP_GAME_HLINE_ROW
    jp draw_right_hline

draw_connection_setup_header:
    ld b, NETCHESSZX_INFO_HEADER_ROW
    ld hl, session_setup_msg
    call draw_setup_header_at_b
    ld a, NETCHESSZX_INFO_HEADER_HLINE_ROW
    jp draw_right_hline

store_tmp_rcs:
    ld a, b
    ld (tmp_row), a
    ld a, c
    ld (tmp_col), a
    ld a, d
    ld (tmp_scan), a
    ret

PUBLIC _spectrum_render_ikkle_at
; HL -> spec: row cell, ikkle half-column (0-63), attr, NUL-terminated text.
_spectrum_render_ikkle_at:
    ld a, (hl)
    ld (tmp_row), a
    inc hl
    ld a, (hl)
    ld (tmp_col), a
    inc hl
    ld a, (hl)
    ld (current_attr), a
    inc hl
    ld a, 2
    ld (tmp_scan), a
    jp draw_ikkle_text_at

PUBLIC _spectrum_render_fileui_select
EXTERN _spectrum_fileui_count
; L = list slot (0-9), H = 1 select / 0 deselect. Paints the item's 12
; attribute cells (items at ikkle half-col 4, rows 9-18): normal ink for
; deselect, inverted (taboption-style) for select; saved rows cyan, free
; rows white.
_spectrum_render_fileui_select:
    ld de, 0x0507        ; D = saved off (cyan), E = free off (white)
    ld a, h
    or a
    jr z, srfs_pick
    ld de, 0x2838        ; D = saved on, E = free on (inverted)
srfs_pick:
    ld a, (_spectrum_fileui_count)
    ld b, a
    ld a, l
    cp b
    jr c, srfs_saved
    ld d, e
srfs_saved:
    add a, 9
    push de
    call compute_attr_base
    pop de
    ld a, 2
    add a, l
    ld l, a
    ld a, d
    ld b, 12
srfs_loop:
    ld (hl), a
    inc l
    djnz srfs_loop
    ret

PUBLIC _spectrum_render_fileui_frame
; Clear the board interior (rows 5-20, cells 1-16) to ATTR_TEXT while
; leaving the board frame pixels in the border cells untouched.
_spectrum_render_fileui_frame:
    call clear_board_coords
    ld c, NETCHESSZX_GAME_BOARD_TOP_ROW
srff_row:
    ld a, c
    call compute_screen_base_de8
srff_scan:
    ld h, d
    ld l, e
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL
    add a, l
    ld l, a
    push bc
    ld b, 16
    xor a
srff_px:
    ld (hl), a
    inc l
    djnz srff_px
    pop bc
    inc d
    djnz srff_scan
    ld a, c
    call compute_attr_base
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL
    add a, l
    ld l, a
    ld b, 16
    ld a, ATTR_TEXT
srff_attr:
    ld (hl), a
    inc l
    djnz srff_attr
    inc c
    ld a, c
    cp NETCHESSZX_GAME_BOARD_TOP_ROW + 16
    jr c, srff_row
    ld a, 8
    call compute_screen_base
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL
    add a, l
    ld l, a
    ld b, 16
    ld a, 0xff
srff_sep:
    ld (hl), a
    inc l
    djnz srff_sep
    jp draw_board_frame

attr_cell_for_tmpcol:
    call compute_attr_base
    ld a, (tmp_col)
    srl a
    add a, l
    ld l, a
    ret

draw_setup_header_at_b:
    ld a, ATTR_MOVES_TITLE
    ld (current_attr), a
    ld c, NETCHESSZX_INFO_TEXT_COL
    ld d, 2
    call store_tmp_rcs
    jp draw_ikkle_text_at

_spectrum_info_show_preflight:
    call clear_right_panel_rows
    ld a, ATTR_MOVES_TITLE
    ld (current_attr), a
    ld b, NETCHESSZX_INFO_HEADER_ROW
    ld c, NETCHESSZX_INFO_TEXT_COL
    ld d, 2
    call store_tmp_rcs
    ld hl, preflight_setup_msg
    call draw_ikkle_text_at
    ld a, NETCHESSZX_INFO_HEADER_HLINE_ROW
    jp draw_right_hline

clear_right_panel_rows:
    ld a, NETCHESSZX_INFO_PANEL_CLEAR_FIRST_ROW
srsp_clear_loop:
    push af
    call clear_right_text_row
    pop af
    inc a
    cp NETCHESSZX_INFO_PANEL_CLEAR_LIMIT_ROW
    jr nz, srsp_clear_loop
    ret

_spectrum_info_clear_tail:
    ld a, l
    add a, NETCHESSZX_INFO_SETUP_LINE_BASE_ROW
srsct_loop:
    cp NETCHESSZX_INFO_PANEL_CLEAR_LIMIT_ROW
    ret nc
    push af
    call clear_right_text_row
    pop af
    inc a
    jr srsct_loop

_spectrum_info_line:
    ld a, (hl)
    inc hl
    ld b, a
    ld c, NETCHESSZX_INFO_TEXT_COL
    ld d, 14
    jp draw_text64_line_pixels_fast

_spectrum_render_square:
    call read_square_spec
    jp draw_one_board_square

_spectrum_render_square_attr:
    call read_square_spec
    ld d, a
    call compute_square_bc
    ld a, d
    jp set_square_attr_2x2

_spectrum_render_square_with_hint:
    push hl
    call _spectrum_render_square
    pop hl

    xor a
render_hint_from_spec:
    ld (mark_mode), a
    ld a, (_netchesszx_movement_hints)
    or a
    ret z
    push hl
    inc hl
    inc hl
    inc hl
    ld a, (hl)
    cp 8
    jp nc, rsh_no_hint
    ld e, a
    ld d, 0
    inc hl
    ld a, (hl)
    cp 8
    jp nc, rsh_no_hint
    ld c, a
    ld hl, _netchesszx_hinted_rows
    add hl, de
    ld a, (hl)
    ld e, a
    ld b, 0
    ld hl, hint_col_mask
    add hl, bc
    ld a, e
    and (hl)
    pop hl
    ret z
    ld a, (hl)
    ld (board_row), a
    inc hl
    ld a, (hl)
    ld (board_col), a
    inc hl
    ld a, (mark_mode)
    or a
    jr z, rsh_piece_ptr_ready
    inc hl
    inc hl
    inc hl
rsh_piece_ptr_ready:
    ld c, 0
    ld a, (hl)
    cp '.'
    jr z, rsh_piece_ready
    ld c, 0x80
rsh_piece_ready:
    ld a, (_netchesszx_board_theme_index)
    ld e, a
    ld d, 0
    ld hl, board_theme_hint_inks
    ld a, (mark_mode)
    or a
    jr z, rsh_inks_ready
    ld hl, board_theme_mark_inks
rsh_inks_ready:
    add hl, de
    ld a, (hl)
    or c
    ld (tmp_attr), a
IFDEF NETCHESSZX_NEXT
    ld a, (mark_mode)
    or a
    jr nz, rsh_next_mark
    call next_marker_set_hint_current_square
    jr rsh_next_marker_done
rsh_next_mark:
    call next_marker_set_mark_current_square
rsh_next_marker_done:
ENDIF

render_square_hint_loaded:
    call compute_square_bc
    ld a, b
    call compute_attr_base
    ld a, c
    add a, l
    ld l, a
    ld a, (hl)
    and 0x78
    ld d, a
    ld a, (tmp_attr)
    and 0x07
    or d
    call set_square_attr_2x2

    ld a, (tmp_attr)
    add a, a
    ret c

    ld a, b
    call compute_screen_base
    ld a, 6
    add a, h
    ld h, a
    ld a, c
    add a, l
    ld l, a

    ld de, 0x8001
    call draw_dot_row
    dec l
    inc h
    ld de, 0xc003
    call draw_dot_row

    ld a, b
    inc a
    call compute_screen_base
    ld a, c
    add a, l
    ld l, a

    ld de, 0xc003
    call draw_dot_row
    dec l
    inc h
    ld de, 0x8001
    jr draw_dot_row

rsh_no_hint:
    pop hl
    ret

draw_dot_row:
    ld a, (hl)
    or e
    ld (hl), a
    inc l
    ld a, (hl)
    or d
    ld (hl), a
    ret

hint_col_mask:
    DEFB 1, 2, 4, 8, 16, 32, 64, 128

board_theme_hint_inks:
IFDEF NETCHESSZX_NEXT
    ; Next boards: black&white, blue3, green, brown, wood
    DEFB 6, 7, 7, 0, 0
ELSE
    DEFB 3, 2, 1, 3, 7
ENDIF

_spectrum_render_square_mark:
    call read_square_spec
    ld (tmp_attr), a
    jp draw_square_mark

_spectrum_render_square_mark_with_hint:
    push hl
    call read_square_spec
    ld (tmp_attr), a
    call draw_square_mark
    pop hl

render_hint_from_mark_spec:
    ld a, 1
    jp render_hint_from_spec



_spectrum_board_show_legal_hints:
    ld hl, 2
    add hl, sp
    ld a, (hl)
    inc hl
    ld c, (hl)
    add a, a
    add a, a
    add a, a
    add a, c
    ld d, a
    ld hl, NETCHESSZX_OVERLAY_CONTEXT
    ld (hl), NETCHESSZX_RULES_BOARD_BASE & 0xff
    inc hl
    ld (hl), NETCHESSZX_RULES_BOARD_BASE >> 8
    inc hl
    ld a, (_side_to_move)
    ld (hl), a
    inc hl
    ld (hl), d
    inc hl
    ld a, (_castle_rights)
    ld (hl), a
    inc hl
    ld a, (_ep_square)
    ld (hl), a
    ld hl, SPECTRUM_OVL_HINTS + (SPECTRUM_OVL_HINTS_SHOW * 256)
    push hl
    call _spectrum_overlay_exec_cached
    pop bc
    ret

call_overlay_ae:
    ld h, e
    ld l, a
    push hl
    call _spectrum_overlay_exec
    pop bc
    ret

call_overlay_cached_ae:
    ld h, e
    ld l, a
    push hl
    call _spectrum_overlay_exec_cached
    pop bc
    ret

_spectrum_input_parse_move:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    ld hl, NETCHESSZX_OVERLAY_CONTEXT
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    ld (hl), c
    inc hl
    ld (hl), b
    ld a, SPECTRUM_OVL_INPUT_EDIT
    ld e, SPECTRUM_OVL_INPUT_EDIT_PARSE_MOVE_PRIVATE
    jr call_overlay_cached_ae

_netchesszx_setup_step_overlay:
    ld a, l
    ld (NETCHESSZX_OVERLAY_CONTEXT), a
    ld a, SPECTRUM_OVL_SETUP
    ld e, SPECTRUM_OVL_SETUP_STEP
    jr call_overlay_cached_ae

_netchesszx_setup_render_edit_line:
    ld a, l
    ld (NETCHESSZX_OVERLAY_CONTEXT), a
    ld a, SPECTRUM_OVL_MENU_CONFIG
    ld e, SPECTRUM_OVL_MENU_CONFIG_EDIT_LINE
    jr call_overlay_cached_ae

_netchesszx_setup_compute_visible:
    ld (NETCHESSZX_OVERLAY_CONTEXT), hl
    ld a, SPECTRUM_OVL_SETUP
    ld e, SPECTRUM_OVL_SETUP_COMPUTE_VISIBLE_PRIVATE
    jr call_overlay_cached_ae

_netchesszx_setup_render_overlay:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    ld hl, NETCHESSZX_OVERLAY_CONTEXT
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    ld (hl), c
    inc hl
    ld (hl), b
    ld a, SPECTRUM_OVL_MENU_CONFIG
    ld e, SPECTRUM_OVL_MENU_CONFIG_RENDER
    jr call_overlay_cached_ae

_netchesszx_setup_paint_attrs:
    ld a, SPECTRUM_OVL_MENU_CONFIG
    ld e, SPECTRUM_OVL_MENU_CONFIG_PAINT_ATTRS
    jr call_overlay_cached_ae

_netchesszx_setup_render_rows:
    ld hl, 2
    add hl, sp
    ld b, (hl)
    inc hl
    ld c, (hl)
    inc hl
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    ld hl, NETCHESSZX_OVERLAY_CONTEXT
    ld (hl), b
    inc hl
    ld (hl), c
    inc hl
    ld (hl), e
    inc hl
    ld (hl), d
    ld a, SPECTRUM_OVL_MENU_CONFIG
    ld e, SPECTRUM_OVL_MENU_CONFIG_RUN
    jp call_overlay_cached_ae


_spectrum_board_clear_legal_hints:
    ld a, SPECTRUM_OVL_HINTS
    ld e, SPECTRUM_OVL_HINTS_CLEAR
    jp call_overlay_cached_ae

read_square_spec:
    ld a, (hl)
    ld (board_row), a
    inc hl
    ld a, (hl)
    ld (board_col), a
    inc hl
    ld a, (hl)
    ret

compute_square_bc:
    ld a, (board_row)
    add a, a
    add a, NETCHESSZX_GAME_BOARD_TOP_ROW
    ld b, a
    ld a, (board_col)
    add a, a
    add a, NETCHESSZX_GAME_BOARD_LEFT_COL
    ld c, a
    ret

square_parity:
    ld a, (board_row)
    ld d, a
    ld a, (board_col)
    add a, d
    and 1
    ret

_spectrum_render_moves:
    ld (move_ptr), hl
    ld a, NETCHESSZX_INFO_MOVES_CLEAR_Y
    ld b, NETCHESSZX_INFO_MOVES_CLEAR_HEIGHT
    call clear_right_pixel_band_abs
    ld a, NETCHESSZX_INFO_MOVES_FIRST_Y
    ld (tmp_scan), a
    ld b, NETCHESSZX_MOVE_ROWS
rm_loop:
    push bc
    call render_move_current_line
    ld hl, (move_ptr)
    ld de, NETCHESSZX_MOVE_SLOT_SIZE
    add hl, de
    ld (move_ptr), hl
    ld a, (tmp_scan)
    add a, NETCHESSZX_INFO_TIGHT_LINE_STEP
    ld (tmp_scan), a
    pop bc
    djnz rm_loop
    ret

_spectrum_render_move_at:
    ld (move_ptr), hl
    ld de, NETCHESSZX_MOVE_LINES_BASE
    or a
    sbc hl, de
    ld b, 0
rma_row_loop:
    ld a, l
    cp NETCHESSZX_MOVE_SLOT_SIZE
    jr c, rma_row_ready
    sub NETCHESSZX_MOVE_SLOT_SIZE
    ld l, a
    inc b
    jr rma_row_loop
rma_row_ready:
    ld a, NETCHESSZX_INFO_MOVES_FIRST_Y
rma_y_loop:
    inc b
    dec b
    jr z, rma_y_ready
    add a, NETCHESSZX_INFO_TIGHT_LINE_STEP
    djnz rma_y_loop
rma_y_ready:
    ld (tmp_scan), a

render_move_current_line:
    ld a, ATTR_TEXT
    ld (current_attr), a
    ld hl, (move_ptr)
    bit 7, (hl)
    jr z, rmc_attr_ready
    res 7, (hl)
    ld a, ATTR_ERROR
    ld (current_attr), a
rmc_attr_ready:
    ld a, (tmp_scan)
    ld b, a
    ld c, NETCHESSZX_INFO_TEXT_COL
    call draw_ikkle_text_abs_y
    ld a, (current_attr)
    cp ATTR_ERROR
    jr nz, rmc_no_restore
    ld hl, (move_ptr)
    set 7, (hl)
rmc_no_restore:
    ld hl, (move_ptr)
    ld de, NETCHESSZX_MOVE_BLACK_OFFSET
    add hl, de
    ld a, (tmp_scan)
    ld b, a
    ld c, NETCHESSZX_MOVE_BLACK_COL
    jp draw_ikkle_text_abs_y

_spectrum_render_moves_scroll:
    ld a, NETCHESSZX_INFO_MOVES_FIRST_Y
    ld b, (NETCHESSZX_MOVE_ROWS - 1) * NETCHESSZX_INFO_TIGHT_LINE_STEP
    jr scroll_right_tight_band_up

_spectrum_render_chat_scroll:
    ld a, NETCHESSZX_INFO_CHAT_FIRST_Y
    ld b, (NETCHESSZX_CHAT_ROWS - 1) * NETCHESSZX_INFO_TIGHT_LINE_STEP

scroll_right_tight_band_up:
    ld (tmp_scan), a
    ld a, b
    ld (piece_scan), a
    ld a, (tmp_scan)
    call compute_pixel_base
    ld a, NETCHESSZX_INFO_PANEL_COL
    add a, l
    ld l, a
    ex de, hl
    ld a, (tmp_scan)
    add a, NETCHESSZX_INFO_TIGHT_LINE_STEP
    call compute_pixel_base
    ld a, NETCHESSZX_INFO_PANEL_COL
    add a, l
    ld l, a
srub_loop:
    ld a, (piece_scan)
    or a
    ret z
    push hl
    push de
    ld bc, 14
    ldir
    pop de
    pop hl
    call pixel_down_hl
    ex de, hl
    call pixel_down_hl
    ex de, hl
    ld a, (piece_scan)
    dec a
    ld (piece_scan), a
    jr srub_loop

_spectrum_render_chat:
    ld (move_ptr), hl
    ld a, NETCHESSZX_INFO_CHAT_CLEAR_Y
    ld b, NETCHESSZX_INFO_CHAT_CLEAR_HEIGHT
    call clear_right_pixel_band_abs
    ld a, NETCHESSZX_INFO_CHAT_FIRST_Y
    ld (tmp_scan), a
    ld b, NETCHESSZX_CHAT_ROWS
rc_loop:
    push bc
    call render_chat_current_line
    ld hl, (move_ptr)
    ld de, NETCHESSZX_CHAT_SLOT_SIZE
    add hl, de
    ld (move_ptr), hl
    ld a, (tmp_scan)
    add a, NETCHESSZX_INFO_TIGHT_LINE_STEP
    ld (tmp_scan), a
    pop bc
    djnz rc_loop
    ret

_spectrum_render_chat_at:
    ld (move_ptr), hl
    ld de, NETCHESSZX_CHAT_LINES_BASE
    or a
    sbc hl, de
    ld b, 0
rca_row_loop:
    ld a, l
    cp NETCHESSZX_CHAT_SLOT_SIZE
    jr c, rca_row_ready
    sub NETCHESSZX_CHAT_SLOT_SIZE
    ld l, a
    inc b
    jr rca_row_loop
rca_row_ready:
    ld a, NETCHESSZX_INFO_CHAT_FIRST_Y
rca_y_loop:
    inc b
    dec b
    jr z, rca_y_ready
    add a, NETCHESSZX_INFO_TIGHT_LINE_STEP
    djnz rca_y_loop
rca_y_ready:
    push af
    dec a
    ld b, NETCHESSZX_INFO_TIGHT_LINE_STEP
    call clear_right_pixel_band_abs
    pop af
    ld (tmp_scan), a

render_chat_current_line:
    ld a, ATTR_TEXT
    ld (current_attr), a
    ld hl, (move_ptr)
    ld a, (hl)
    and 0x7f
    ; Chat is black-paper UI: these glyph choices are intentionally inverted
    ; versus the white-paper move header.
    cp 'B'
    ld hl, chat_icon_white
    jr z, rc_draw_label
    cp 'W'
    ld hl, chat_icon_black
    jr z, rc_draw_label
    jr rc_draw_ikkle_line
rc_draw_label:
    call draw_chat_icon_at
    ld a, ATTR_TEXT
    ld (current_attr), a
    ld hl, (move_ptr)
    inc hl
    ld a, (tmp_scan)
    ld b, a
    ld c, NETCHESSZX_CHAT_TIME_COL
    jp draw_ikkle_text_abs_y
rc_draw_ikkle_line:
    ld hl, (move_ptr)
    inc hl
    ld a, (tmp_scan)
    ld b, a
    ld c, NETCHESSZX_CHAT_TIME_COL
    jp draw_ikkle_text_abs_y

draw_chat_icon_at:
    ld (sprite_ptr), hl
    ld a, NETCHESSZX_CHAT_ICON_BYTE_COL
    ld (tmp_col), a
    ld a, 5
    ld (tmp_char), a

draw_icon_byte_abs_at_tmp:
    xor a
    ld (piece_scan), a
diba_loop:
    ld hl, (sprite_ptr)
    ld a, (hl)
    inc hl
    ld (sprite_ptr), hl
    ld c, a
    ld a, (tmp_scan)
    ld d, a
    ld a, (piece_scan)
    add a, d
    call compute_pixel_base
    ld a, (tmp_col)
    add a, l
    ld l, a
    ld (hl), c
    ld a, (piece_scan)
    inc a
    ld (piece_scan), a
    ld c, a
    ld a, (tmp_char)
    cp c
    jr nz, diba_loop
    ret

draw_icon_sprite_at_tmp:
dci_loop:
    ld a, (tmp_row)
    call compute_screen_base
    ld a, (tmp_scan)
    add a, h
    ld h, a
    ld a, (tmp_col)
    add a, l
    ld l, a
    ex de, hl
    ld hl, (sprite_ptr)
    ld a, (hl)
    inc hl
    ld (sprite_ptr), hl
    ld c, a
    ex de, hl
    ld a, c
    and 0xf0
    rrca
    rrca
    rrca
    rrca
    ld b, a
    ld a, (hl)
    and 0xf0
    or b
    ld (hl), a
    inc hl
    ld a, c
    and 0x0f
    rlca
    rlca
    rlca
    rlca
    ld b, a
    ld a, (hl)
    and 0x0f
    or b
    ld (hl), a
    ld a, (tmp_scan)
    inc a
    ld (tmp_scan), a
    ld a, (tmp_char)
    ld c, a
    ld a, (tmp_scan)
    cp c
    jr c, dci_loop
    ret

_spectrum_render_input:
    ld (notice_ptr), hl
    ld a, NETCHESSZX_INPUT_ROW
    ld c, ATTR_TEXT
    call clear_text_row
    ld a, ATTR_TEXT
    ld (current_attr), a
    ld b, NETCHESSZX_INPUT_ROW
    ld c, 0
    ld d, 1
    ld hl, input_prompt_msg
    call draw_text64_line_attr_fast
    ld b, NETCHESSZX_INPUT_ROW
    ld c, 2
    ld d, 31
    ld hl, (notice_ptr)
    jp draw_text64_line_attr_fast

_spectrum_render_input_cell:
    ld a, (hl)
    add a, 2
    cp 64
    ret nc
    ld d, a
    inc hl
    ld a, (hl)
    ld (tmp_char), a
    inc hl
    ld a, (hl)
    ld (mark_mode), a

    ld a, d
    ld (tmp_col), a
    ld a, NETCHESSZX_INPUT_ROW
    ld (tmp_row), a

    ld a, ATTR_TEXT
    ld (current_attr), a
    ld a, (tmp_char)
    call draw_char64_at_tmp

    ld a, (mark_mode)
    or a
    ret z
    jp draw_input_cursor_at_tmp

clear_screen:
    xor a
    out (0xfe), a

    ld hl, SCREEN_BASE
    ld de, SCREEN_BASE + 1
    ld bc, 6143
    ld (hl), a
    ldir

    ld h, d
    ld l, e
    inc de
    ld a, ATTR_TEXT
    ld (hl), a
    ld bc, 767
    ldir
    ret

draw_banner:
    xor a
    ld c, ATTR_BANNER_TOP
    call fill_attr_line
    ld a, 1
    ld c, ATTR_BANNER_BOT
    call fill_attr_line

    ld hl, title_msg
    ld b, 0
    ld c, 0
    call draw_scaled_text

    call draw_banner_info
    jp draw_badge

draw_banner_info:
    ld a, ATTR_TEXT
    ld (current_attr), a
    ld hl, version_banner_msg
    ld b, 4
    ld c, NETCHESSZX_BANNER_INFO_COL
    call draw_ikkle_text_abs_y
    ld hl, banner_info_top_msg
    ld b, 10
    ld c, NETCHESSZX_BANNER_INFO_COL
    jp draw_ikkle_text_abs_y

draw_menu:
    ld (mark_mode), a
    ld a, NETCHESSZX_MENU_ROW
    ld c, ATTR_STATUS
    call fill_attr_line
    ld a, ATTR_STATUS
    ld (current_attr), a
    call clear_menu_pixels
    ld hl, tab_label_file
    ld c, 1
    call draw_tab_text_at
    ld hl, tab_label_discc
    ld c, 6
    call draw_tab_text_at
    ld hl, tab_label_reset
    ld c, 12
    call draw_tab_text_at
    ld hl, tab_label_flip
    ld c, 18
    call draw_tab_text_at
    ld hl, tab_label_theme
    ld c, 23
    call draw_tab_text_at
    ld hl, tab_label_about
    ld c, 29
    call draw_tab_text_at
    ld a, (mark_mode)
    dec a
    cp 6
    jr c, dm_focus_ok
    xor a
dm_focus_ok:
    jr draw_menu_cursor

draw_menu_partial:
    ld (mark_mode), a
    and 0x38
    srl a
    srl a
    srl a
    call draw_menu_cursor
    ld a, (mark_mode)
    and 0x07
    jr draw_menu_cursor

clear_menu_pixels:
    ld a, NETCHESSZX_MENU_ROW
    call compute_screen_base
    xor a
    ld b, 32
cmp_sep_loop:
    ld (hl), a
    inc l
    djnz cmp_sep_loop
    ld a, l
    sub 32
    ld l, a
    inc h
    ld c, 7
    xor a
cmp_scan_loop:
    ld b, 20
    push hl
cmp_px_loop:
    ld (hl), a
    inc l
    djnz cmp_px_loop
    pop hl
    inc h
    dec c
    jr nz, cmp_scan_loop
    ret

draw_menu_cursor:
    cp 6
    ret nc
    add a, a
    add a, a
    ld e, a
    ld d, 0
    ld hl, menu_cursor_masks
    add hl, de
    ld a, (hl)
    ld (tmp_col), a
    inc hl
    ld a, (hl)
    ld (piece_scan), a
    inc hl
    ld a, (hl)
    ld (tmp_char), a
    inc hl
    ld a, (hl)
    ld (tmp_scan), a
    ld a, NETCHESSZX_MENU_ROW
    call compute_screen_base
    inc h
    ld c, l
    ld b, 6
dmc_scan_loop:
    push bc
    ld l, c
    ld a, (tmp_col)
    add a, l
    ld l, a
    ld a, (piece_scan)
    xor (hl)
    ld (hl), a
    inc l
    ld a, (tmp_char)
    ld b, a
dmc_mid_loop:
    ld a, (hl)
    cpl
    ld (hl), a
    inc l
    djnz dmc_mid_loop
    ld a, (tmp_scan)
    xor (hl)
    ld (hl), a
    pop bc
    inc h
    djnz dmc_scan_loop
    ret

draw_tab_text_at:
    ld a, NETCHESSZX_MENU_ROW
    ld (tmp_row), a
    ld a, 2
    ld (tmp_scan), a
    ld a, c
    ld (tmp_col), a
    jp draw_ikkle_text_at

hide_menu:
    call clear_menu_pixels
    ld a, NETCHESSZX_MENU_ROW
    ld c, ATTR_TEXT
    call fill_attr_line
    jp draw_banner_separator

draw_static_panels:
    call draw_moves_header

    ld a, ATTR_CHAT_TITLE
    ld (current_attr), a
    ld b, NETCHESSZX_INFO_CHAT_TITLE_ROW
    ld c, NETCHESSZX_INFO_TEXT_COL
    ld d, 2
    call store_tmp_rcs
    ld hl, chat_msg
    call draw_ikkle_text_at
    ld a, NETCHESSZX_INFO_CHAT_HLINE_ROW
    jp draw_right_hline_full_left

draw_moves_header:
    ld a, NETCHESSZX_INFO_HEADER_ROW
    call compute_screen_base
    ld a, NETCHESSZX_INFO_PANEL_COL
    add a, l
    ld l, a
    ld d, h
    ld e, l
    ld c, 13
    call clear_pixels_8

    ld a, NETCHESSZX_INFO_HEADER_ROW
    call compute_attr_base
    ld a, NETCHESSZX_INFO_PANEL_COL
    add a, l
    ld l, a
    ld b, 14
dmh_attr_loop:
    ld (hl), ATTR_STATUS
    inc hl
    djnz dmh_attr_loop

    call draw_moves_header_divider

    ld a, NETCHESSZX_MOVES_HEADER_WHITE_ICON_BYTE_COL
    ld hl, chat_icon_white
    call draw_moves_header_icon
    ld a, NETCHESSZX_MOVES_HEADER_BLACK_ICON_BYTE_COL
    ld hl, chat_icon_black
    call draw_moves_header_icon

    ld a, ATTR_STATUS
    ld (current_attr), a
    ld b, NETCHESSZX_INFO_HEADER_ROW
    ld c, NETCHESSZX_MOVES_HEADER_WHITE_TEXT_COL
    ld d, 2
    call store_tmp_rcs
    ld hl, moves_white_msg
    call draw_ikkle_text_at
    ld b, NETCHESSZX_INFO_HEADER_ROW
    ld c, NETCHESSZX_MOVES_HEADER_BLACK_TEXT_COL
    ld d, 2
    call store_tmp_rcs
    ld hl, moves_black_msg
    jp draw_ikkle_text_at

draw_moves_header_icon:
    ld (sprite_ptr), hl
    ld (tmp_col), a
    ld a, NETCHESSZX_INFO_HEADER_ROW
    ld (tmp_row), a
    ld a, 1
    ld (tmp_scan), a
    ld a, 6
    ld (tmp_char), a
    jp draw_icon_sprite_at_tmp

draw_moves_header_divider:
    ld a, NETCHESSZX_INFO_HEADER_ROW
    call compute_screen_base
    ld a, NETCHESSZX_MOVES_HEADER_DIVIDER_BYTE_COL
    add a, l
    ld l, a
    ld b, 8
dmhd_loop:
    ld a, (hl)
    or 0x80
    ld (hl), a
    inc h
    djnz dmhd_loop
    ret

clear_board_coords:
    ld a, NETCHESSZX_GAME_BOARD_TOP_ROW - 1
    call compute_screen_base_de8
cbc_file_scan:
    push bc
    push de
    ld h, d
    ld l, e
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL - 1
    add a, l
    ld l, a
    ld b, 18
    xor a
cbc_file_byte:
    ld (hl), a
    inc hl
    djnz cbc_file_byte
    pop de
    pop bc
    inc d
    djnz cbc_file_scan

    ld c, NETCHESSZX_GAME_BOARD_TOP_ROW
    ld b, 16
cbc_rank_row:
    push bc
    ld a, c
    call compute_screen_base_de8
cbc_rank_scan:
    ld h, d
    ld l, e
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL - 1
    add a, l
    ld l, a
    xor a
    ld (hl), a
    inc d
    djnz cbc_rank_scan
    pop bc
    inc c
    djnz cbc_rank_row
    ret

draw_board_coords:
    call board_light_line_attr
    ld (current_attr), a
    xor a
    ld (board_col), a

coord_file_loop:
    ld a, (board_col)
    cp 8
    jr nc, coord_rank_start

    ld a, (_spectrum_gui_board_flipped)
    or a
    jr z, coord_file_white
    ld a, 'H'
    ld d, a
    ld a, (board_col)
    ld e, a
    ld a, d
    sub e
    jr coord_file_draw
coord_file_white:
    ld a, 'A'
    ld d, a
    ld a, (board_col)
    add a, d
coord_file_draw:
    call draw_file_letter_centered

    ld a, (board_col)
    inc a
    ld (board_col), a
    jr coord_file_loop

coord_rank_start:
    xor a
    ld (board_row), a

coord_rank_loop:
    ld a, (board_row)
    cp 8
    ret nc

    ld a, (_spectrum_gui_board_flipped)
    or a
    jr z, coord_rank_white
    ld a, '1'
    ld d, a
    ld a, (board_row)
    add a, d
    jr coord_rank_draw
coord_rank_white:
    ld a, '8'
    ld d, a
    ld a, (board_row)
    ld e, a
    ld a, d
    sub e
coord_rank_draw:
    call draw_rank_digit_centered

    ld a, (board_row)
    inc a
    ld (board_row), a
    jr coord_rank_loop

draw_rank_digit_centered:
    ld (tmp_char), a

    ld a, (board_row)
    add a, a
    add a, NETCHESSZX_GAME_BOARD_TOP_ROW
    call compute_attr_base
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL - 1
    add a, l
    ld l, a
    ld a, (current_attr)
    ld (hl), a
    ld de, 32
    add hl, de
    ld (hl), a

    ld a, (tmp_char)
    sub '1'
    ret c
    cp 8
    ret nc
    ld e, a
    add a, a
    add a, a
    add a, e
    ld e, a
    ld d, 0
    ld hl, rank_digit_patterns
    add hl, de
    ld (sprite_ptr), hl

    xor a
    ld (piece_scan), a

drdc_loop:
    ld a, (piece_scan)
    cp 5
    ret nc

    ld hl, (sprite_ptr)
    ld c, (hl)
    inc hl
    ld (sprite_ptr), hl

    ld a, (board_row)
    add a, a
    add a, a
    add a, a
    add a, a
    add a, NETCHESSZX_GAME_BOARD_TOP_ROW * 8 + 5
    ld d, a
    ld a, (piece_scan)
    add a, d
    ld d, a
    srl a
    srl a
    srl a
    call compute_screen_base
    ld a, d
    and 7
    add a, h
    ld h, a
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL - 1
    add a, l
    ld l, a
    ld (hl), c

    ld a, (piece_scan)
    inc a
    ld (piece_scan), a
    jr drdc_loop

draw_file_letter_centered:
    ld (tmp_char), a

    ld a, NETCHESSZX_GAME_BOARD_TOP_ROW - 1
    call compute_attr_base
    ld a, (board_col)
    add a, a
    add a, NETCHESSZX_GAME_BOARD_LEFT_COL
    add a, l
    ld l, a
    ld a, (current_attr)
    ld (hl), a

    ld a, (tmp_char)
    sub 'A'
    ret c
    cp 8
    ret nc
    ld e, a
    add a, a
    add a, a
    add a, e
    ld e, a
    ld d, 0
    ld hl, file_letter_patterns
    add hl, de
    ld (sprite_ptr), hl

    xor a
    ld (piece_scan), a

dflc_loop:
    ld a, (piece_scan)
    cp 5
    ret nc

    ld hl, (sprite_ptr)
    ld a, (hl)
    rrca
    rrca
    rrca
    rrca
    ld c, a
    and 0x01
    ld (tmp_attr), a
    ld a, c
    srl a
    ld c, a
    inc hl
    ld (sprite_ptr), hl

    ld a, NETCHESSZX_GAME_BOARD_TOP_ROW - 1
    call compute_screen_base
    ld a, (piece_scan)
    inc a
    add a, h
    ld h, a
    ld a, (board_col)
    add a, a
    add a, NETCHESSZX_GAME_BOARD_LEFT_COL
    add a, l
    ld l, a
    ld (hl), c
    ld a, (tmp_attr)
    or a
    jr z, dflc_no_carry
    inc hl
    ld a, (hl)
    or 0x80
    ld (hl), a
dflc_no_carry:

    ld a, (piece_scan)
    inc a
    ld (piece_scan), a
    jr dflc_loop

draw_board:
    ld hl, (board_ptr)
    ld (board_iter), hl
    xor a
    ld (board_row), a

board_piece_row_loop:
    ld a, (board_row)
    cp 8
    ret nc

    xor a
    ld (board_col), a

board_piece_col_loop:
    ld a, (board_col)
    cp 8
    jr nc, board_piece_next_row

    ld hl, (board_iter)
    ld a, (hl)
    inc hl
    ld (board_iter), hl
    call draw_one_board_square

board_piece_skip:
    ld a, (board_col)
    inc a
    ld (board_col), a
    jr board_piece_col_loop

board_piece_next_row:
    ld a, (board_row)
    inc a
    ld (board_row), a
    jr board_piece_row_loop

draw_board_frame:
    ld a, NETCHESSZX_GAME_BOARD_TOP_ROW - 1
    call compute_screen_base
    ld a, 7
    add a, h
    ld h, a
    call draw_board_hline

    ld a, NETCHESSZX_GAME_BOARD_TOP_ROW + 16
    call compute_screen_base
    call draw_board_hline

    ld a, NETCHESSZX_GAME_BOARD_TOP_ROW
    ld (tmp_row), a
    ld b, 16
dbf_row:
    push bc
    ld a, (tmp_row)
    call compute_screen_base_de8
dbf_scan:
    ld h, d
    ld l, e
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL - 1
    add a, l
    ld l, a
    ld a, (hl)
    or 0x01
    ld (hl), a

    ld h, d
    ld l, e
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL + 16
    add a, l
    ld l, a
    ld a, (hl)
    or 0x80
    ld (hl), a

    inc d
    djnz dbf_scan
    ld a, (tmp_row)
    inc a
    ld (tmp_row), a
    pop bc
    djnz dbf_row
    ret

draw_board_hline:
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL - 1
    add a, l
    ld l, a
    ld a, (hl)
    or 0x01
    ld (hl), a
    inc l
    ld b, 16
dbh_mid:
    ld (hl), 0xff
    inc l
    djnz dbh_mid
    ld a, (hl)
    or 0x80
    ld (hl), a
    ret

restore_board_frame_attrs:
    ; ABOUT asset leaves only frame bits in the right/bottom border bytes.
    call board_light_line_attr
    ld (tmp_attr), a
    ld a, NETCHESSZX_GAME_BOARD_TOP_ROW - 1
    call restore_board_attr_hline
    ld a, NETCHESSZX_GAME_BOARD_TOP_ROW + 16
    call restore_board_attr_hline
    ld a, NETCHESSZX_GAME_BOARD_TOP_ROW
    call compute_attr_base
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL - 1
    add a, l
    ld l, a
    ld b, 16
    ld a, (tmp_attr)
rbfa_side_loop:
    ld (hl), a
    ld de, 17
    add hl, de
    ld (hl), a
    ld de, 15
    add hl, de
    djnz rbfa_side_loop
    ret

restore_board_attr_hline:
    call compute_attr_base
    ld a, NETCHESSZX_GAME_BOARD_LEFT_COL - 1
    add a, l
    ld l, a
    ld b, 18
    ld a, (tmp_attr)
rbah_loop:
    ld (hl), a
    inc hl
    djnz rbah_loop
    ret

board_light_line_attr:
IFDEF NETCHESSZX_NEXT
    ld a, (_netchesszx_board_theme_index)
    or a
    jr z, blla_classic
    ld a, NEXT_BOARD_COORD_LINE_ATTR
    ret
blla_classic:
ENDIF
    ld a, (_netchesszx_board_light_attr)
    ld d, a
    and 0x40
    ld e, a
    ld a, d
    and 0x38
    rrca
    rrca
    rrca
    or e
    ret

draw_one_board_square:
    cp '.'
    jr nz, dobs_piece_ready
    ld a, ' '
dobs_piece_ready:
    ld (piece_char), a
    call square_parity
    jr z, dobs_light
    ld a, (_netchesszx_board_dark_attr)
    jr dobs_attr
dobs_light:
    ld a, (_netchesszx_board_light_attr)
dobs_attr:
    ld d, a
    call compute_square_bc
    push de
    push bc
    call clear_square_pixels_2x2
    pop bc
    pop de
    ld a, d
    call set_square_attr_2x2
IFDEF NETCHESSZX_NEXT
    call next_marker_release_current_square
    call next_draw_board_square_sprite

    ld a, (piece_char)
    cp ' '
    jr z, next_hide_square_sprite
    ld a, (piece_char)
    jr next_draw_piece_sprite_16x16
ELSE
    ld a, (piece_char)
    cp ' '
    ret z
    ld a, (piece_char)
    jp draw_piece_sprite_16x16
ENDIF

clear_square_pixels_2x2:
    ld e, c
    ld c, b
    ld d, 2
csp_row_loop:
    ld a, c
    call compute_screen_base
    ld a, e
    add a, l
    ld l, a
    ld b, 8
    xor a
csp_scan_loop:
    ld (hl), a
    inc l
    ld (hl), a
    dec l
    inc h
    djnz csp_scan_loop
    inc c
    dec d
    jr nz, csp_row_loop
    ret

set_square_attr_2x2:
    ld d, a
    ld a, b
    call compute_attr_base
    ld a, c
    add a, l
    ld l, a
    ld a, d
    ld (hl), a
    inc hl
    ld (hl), a
    ld de, 31
    add hl, de
    ld (hl), a
    inc hl
    ld (hl), a
    ret

IFDEF NETCHESSZX_NEXT
next_draw_piece_sprite_16x16:
    call next_piece_pattern_for_char
    jr c, next_hide_square_sprite
    ld (tmp_char), a
    call next_square_sprite_slot
    ld (tmp_attr), a
    call next_find_piece_slot
    jr nc, ndps_slot_ready
    call next_alloc_piece_slot
    ret c
ndps_slot_ready:
    add a, NEXT_PIECE_SPRITE_SLOT_BASE
    ld bc, NEXT_SPRITE_SLOT_PORT
    out (c), a
    call next_write_square_sprite_xy
    ld a, (tmp_char)
    or NEXT_SPRITE_VISIBLE
    out (c), a
    ret

next_hide_square_sprite:
    call next_square_sprite_slot
    ld (tmp_attr), a
    call next_find_piece_slot
    ret c
    jp next_hide_piece_slot

next_draw_board_square_sprite:
    call next_square_sprite_slot
    add a, NEXT_BOARD_SPRITE_SLOT_BASE
    ld bc, NEXT_SPRITE_SLOT_PORT
    out (c), a
    call next_write_square_sprite_xy
    call square_parity
    ld (tmp_scan), a
    ld a, (_netchesszx_board_theme_index)
    add a, a
    ld e, a
    ld a, (tmp_scan)
    add a, e
    add a, NEXT_BOARD_PATTERN_BASE
    or NEXT_SPRITE_VISIBLE
    out (c), a
    ret

next_marker_set_hint_current_square:
    ld a, NEXT_MARKER_FLAG_HINT
    jr next_marker_or_current_square

next_marker_set_mark_current_square:
    ld a, NEXT_MARKER_FLAG_MARK
    ld c, a
    ld a, (mark_mode)
    or a
    jr z, nmsm_flags_ready
    ld a, c
    or NEXT_MARKER_FLAG_SELECTED
    ld c, a
nmsm_flags_ready:
    ld a, c

next_marker_or_current_square:
    ld (tmp_char), a
    call next_square_sprite_slot
    ld (tmp_attr), a
    call next_find_marker_slot
    jr nc, nmuf_slot_ready
    call next_alloc_marker_slot
    ret c

nmuf_slot_ready:
    ld e, a
    ld d, 0
    ld hl, marker_slot_flags
    add hl, de
    ld a, (tmp_char)
    or (hl)
    ld (hl), a
    ld (tmp_char), a
    ld a, e
    add a, NEXT_MARKER_SPRITE_SLOT_BASE
    ld bc, NEXT_SPRITE_SLOT_PORT
    out (c), a
    call next_write_square_sprite_xy
    ld a, (tmp_char)
    bit 2, a
    jr nz, nmuf_selected
    bit 1, a
    jr z, nmuf_hint
    bit 0, a
    jr z, nmuf_cursor
    ld a, NEXT_MARKER_PATTERN_BASE + 2
    jr nmuf_pattern_ready
nmuf_selected:
    ld a, NEXT_MARKER_PATTERN_BASE + 3
    jr nmuf_pattern_ready
nmuf_cursor:
    ld a, NEXT_MARKER_PATTERN_BASE + 1
    jr nmuf_pattern_ready
nmuf_hint:
    ld a, NEXT_MARKER_PATTERN_BASE
nmuf_pattern_ready:
    or NEXT_SPRITE_VISIBLE
    out (c), a
    ret

next_marker_release_current_square:
    call next_square_sprite_slot
    ld (tmp_attr), a
    call next_find_marker_slot
    ret c
    ld e, a
    ld d, 0
    ld hl, marker_slot_flags
    add hl, de
    ld (hl), 0
    ld a, e
    jr next_hide_marker_slot

next_find_piece_slot:
    ld hl, piece_slot_squares
    jr next_find_slot

next_find_marker_slot:
    ld hl, marker_slot_squares

next_find_slot:
    ld b, 32
    ld c, 0
nfs_loop:
    ld a, (tmp_attr)
    cp (hl)
    jr z, nfs_found
    inc hl
    inc c
    djnz nfs_loop
    scf
    ret
nfs_found:
    ld a, c
    or a
    ret

next_alloc_piece_slot:
    ld hl, piece_slot_squares
    jr next_alloc_slot

next_alloc_marker_slot:
    ld hl, marker_slot_squares

next_alloc_slot:
    ld b, 32
    ld c, 0
nas_loop:
    ld a, (hl)
    cp NEXT_EMPTY_SLOT
    jr z, nas_found
    inc hl
    inc c
    djnz nas_loop
    scf
    ret
nas_found:
    ld a, (tmp_attr)
    ld (hl), a
    ld a, c
    or a
    ret

next_hide_piece_slot:
    ld e, a
    ld d, 0
    ld hl, piece_slot_squares
    add hl, de
    ld (hl), NEXT_EMPTY_SLOT
    ld a, e
    add a, NEXT_PIECE_SPRITE_SLOT_BASE
    jr next_hide_hardware_sprite

next_hide_marker_slot:
    ld e, a
    ld d, 0
    ld hl, marker_slot_squares
    add hl, de
    ld (hl), NEXT_EMPTY_SLOT
    ld a, e
    add a, NEXT_MARKER_SPRITE_SLOT_BASE

next_hide_hardware_sprite:
    ld bc, NEXT_SPRITE_SLOT_PORT
    out (c), a
    ld bc, NEXT_SPRITE_ATTR_PORT
    xor a
    out (c), a
    out (c), a
    out (c), a
    out (c), a
    ret

next_write_square_sprite_xy:
    ld bc, NEXT_SPRITE_ATTR_PORT
    ld a, (board_col)
    add a, a
    add a, a
    add a, a
    add a, a
    add a, NEXT_SPRITE_X_BASE
    out (c), a
    ld a, (board_row)
    add a, a
    add a, a
    add a, a
    add a, a
    add a, NEXT_SPRITE_Y_BASE
    out (c), a
    xor a
    out (c), a
    ret

_spectrum_next_sprites_hide_all:
    ld d, 0
next_hide_all_loop:
    ld a, d
    call next_hide_hardware_sprite
    inc d
    ld a, d
    cp 128
    jr nz, next_hide_all_loop

next_sprite_tables_reset:
    ld hl, piece_slot_squares
    ld b, 32
    ld a, NEXT_EMPTY_SLOT
nstr_piece_loop:
    ld (hl), a
    inc hl
    djnz nstr_piece_loop
    ld hl, marker_slot_squares
    ld b, 32
    ld a, NEXT_EMPTY_SLOT
nstr_marker_loop:
    ld (hl), a
    inc hl
    djnz nstr_marker_loop
    ld hl, marker_slot_flags
    ld b, 32
    xor a
nstr_flags_loop:
    ld (hl), a
    inc hl
    djnz nstr_flags_loop
    ret

next_square_sprite_slot:
    ld a, (board_row)
    add a, a
    add a, a
    add a, a
    ld d, a
    ld a, (board_col)
    add a, d
    ret

next_piece_pattern_for_char:
    ld c, 0
    cp 'a'
    jr c, npp_upper_ready
    sub 32
    ld c, 6
npp_upper_ready:
    ld (tmp_char), a
    ld hl, psfc_piece_chars
    ld b, 6
npp_match:
    cp (hl)
    jr z, npp_found
    inc hl
    djnz npp_match
    scf
    ret
npp_found:
    ld a, 6
    sub b
    add a, c
    or a
    ret
ENDIF

draw_scaled_text:
    ld (text_ptr), hl
    ld a, b
    ld (scaled_row), a
    ld a, c
    ld (scaled_col), a

dst_loop:
    ld hl, (text_ptr)
    ld a, (hl)
    or a
    ret z
    ld b, a
    ld a, (scaled_row)
    ld d, a
    ld a, (scaled_col)
    ld c, a
    ld a, b
    ld b, d
    call draw_scaled_glyph
    ld hl, (text_ptr)
    inc hl
    ld (text_ptr), hl
    ld a, (scaled_col)
    inc a
    ld (scaled_col), a
    jr dst_loop

draw_scaled_glyph:
    ld (piece_char), a
    ld a, b
    ld (piece_row), a
    ld a, c
    ld (piece_col), a
    xor a
    ld (piece_scan), a

dsg_loop:
    ld a, (piece_scan)
    cp 6
    ret nc

    ld (tmp_scan), a
    ld a, (piece_char)
    call font_scanline
    rrca
    rrca
    rrca
    rrca
    and 0x0f
    ld e, a
    ld d, 0
    ld hl, expand_2x
    add hl, de
    ld d, (hl)

    ld a, (piece_scan)
    add a, a
    add a, 2
    ld e, a
    and 7
    ld (tmp_scan), a
    ld a, e
    rrca
    rrca
    rrca
    and 0x1f
    ld e, a
    ld a, (piece_row)
    add a, e
    call compute_screen_base
    ld a, (tmp_scan)
    add a, h
    ld h, a
    ld a, (piece_col)
    add a, l
    ld l, a
    ld (hl), d
    inc h
    ld (hl), d

    ld a, (piece_scan)
    inc a
    ld (piece_scan), a
    jr dsg_loop

draw_piece_sprite_16x16:
    ld (piece_char), a
    ld a, b
    ld (piece_row), a
    ld a, c
    ld (piece_col), a

    ld a, (piece_char)
    call piece_sprite_for_char
    ld a, h
    or l
    ret z
    ex de, hl                  ; DE = sprite data pointer (32 bytes, sequential)

    ; --- top char row: pixel scanlines 0..7 ---
    ld a, (piece_row)
    call compute_screen_base   ; HL = scan 0 of char row; clobbers A/HL, keeps DE
    ld a, (piece_col)
    add a, l
    ld l, a                    ; HL = top-left pixel address
    ld b, 8
    call dps_blit_8

    ; --- bottom char row: pixel scanlines 8..15 ---
    ld a, (piece_row)
    inc a
    call compute_screen_base
    ld a, (piece_col)
    add a, l
    ld l, a
    ld b, 8
    ; falls through into dps_blit_8

; Blit B pixel lines of a 16x16 sprite into one char row.
; DE = sprite pointer (advances 2 bytes/line), HL = left pixel address.
; inc h walks down within the char block; no per-line address recompute.
dps_blit_8:
    ld a, (de)
    ld (hl), a
    inc l
    inc de
    ld a, (de)
    ld (hl), a
    dec l
    inc de
    inc h
    djnz dps_blit_8
    ret

piece_sprite_for_char:
    ld c, 0
    cp 'a'
    jr c, psfc_upper_ready
    sub 32
    ld c, 12
psfc_upper_ready:
    ld (tmp_char), a

    call square_parity
    jr z, psfc_black_light
    ld a, c
    xor 12
    ld c, a
psfc_black_light:
    ld a, (tmp_char)
    ld hl, psfc_piece_chars
    ld b, 6
psfc_match:
    cp (hl)
    jr z, psfc_found
    inc hl
    djnz psfc_match
    ld hl, 0
    ret

psfc_found:
    ld a, 6
    sub b
    add a, a
    add a, c
    ld e, a
    ld d, 0
    ld hl, psfc_table
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl
    ret

psfc_table:
    DW piece_sprites_16x16 + 0
    DW piece_sprites_16x16 + 64
    DW piece_sprites_16x16 + 128
    DW piece_sprites_16x16 + 192
    DW piece_sprites_16x16 + 256
    DW piece_sprites_16x16 + 320
    DW piece_sprites_16x16 + 32
    DW piece_sprites_16x16 + 96
    DW piece_sprites_16x16 + 160
    DW piece_sprites_16x16 + 224
    DW piece_sprites_16x16 + 288
    DW piece_sprites_16x16 + 352

draw_char64_at_tmp:
    call draw_char64_pixels_at_tmp
    ld a, (tmp_row)
    call attr_cell_for_tmpcol
    ld a, (current_attr)
    ld (hl), a
    ret

draw_text64_line_attr_fast:
    call draw_text64_line_prepare
    call draw_text64_line_fill_attr
    jr draw_text64_line_pixels_prepared

draw_text64_line_pixels_fast:
    call draw_text64_line_prepare
    jr draw_text64_line_pixels_prepared

draw_text64_line_prepare:
    ld (text_ptr), hl
    ld a, b
    ld (tmp_row), a
    ld a, c
    ld (tmp_col), a
    ld a, d
    ld (tmp_char), a
    ret

draw_text64_line_fill_attr:
    ld a, (tmp_row)
    call attr_cell_for_tmpcol
    ld a, (tmp_char)
    ld b, a
    ld a, (current_attr)
dt64laf_loop:
    ld (hl), a
    inc hl
    djnz dt64laf_loop
    ret

draw_text64_line_pixels_prepared:
    xor a
    ld (piece_scan), a

dst64_scan_loop:
    ld a, (tmp_row)
    call compute_screen_base
    ld a, (piece_scan)
    add a, h
    ld h, a
    ld a, (tmp_col)
    srl a
    add a, l
    ld l, a
    ld (sprite_ptr), hl

    ld a, (piece_scan)
    or a
    jr z, dst64_blank_scan
    cp 7
    jr z, dst64_blank_scan

    dec a
    ld (tmp_scan), a
    ld hl, (text_ptr)
    ld a, (tmp_char)
    ld b, a
    ld a, (tmp_col)
    and 1
    xor 1
    ld c, a

dst64_pair_loop:
    ld a, c
    or a
    jr nz, dst64_left_from_text
    inc c
    xor a
    jr dst64_left_ready

dst64_left_from_text:
    call text64_next_glyph
    and 0xf0
dst64_left_ready:
    ld (tmp_attr), a
    call text64_next_glyph
    and 0x0f
    ld e, a
    ld a, (tmp_attr)
    or e
    push hl
    ld hl, (sprite_ptr)
    ld (hl), a
    inc hl
    ld (sprite_ptr), hl
    pop hl
    djnz dst64_pair_loop
    jr dst64_next_scan

dst64_blank_scan:
    ld hl, (sprite_ptr)
    ld a, (tmp_char)
    ld b, a
    xor a
dst64_blank_loop:
    ld (hl), a
    inc hl
    djnz dst64_blank_loop

dst64_next_scan:
    ld a, (piece_scan)
    inc a
    ld (piece_scan), a
    cp 8
    jr c, dst64_scan_loop
    ret

text64_next_glyph:
    ld a, (hl)
    or a
    ret z
    inc hl
    push hl
    call font_scanline
    pop hl
    ret

draw_char64_pixels_at_tmp:
    ld (tmp_char), a
    xor a
    ld (tmp_scan), a

dc64_scan_loop:
    ld a, (tmp_row)
    call compute_screen_base
    ld a, (tmp_scan)
    add a, h
    ld h, a
    ld a, (tmp_col)
    srl a
    add a, l
    ld l, a

    ld a, (tmp_scan)
    or a
    jr z, dc64_blank
    cp 7
    jr z, dc64_blank
    dec a
    ld (tmp_scan), a
    push hl
    ld a, (tmp_char)
    call font_scanline
    ld e, a
    pop hl
    ld a, (tmp_scan)
    inc a
    ld (tmp_scan), a
    jr dc64_got_pattern

dc64_blank:
    xor a
    ld e, a

dc64_got_pattern:
    ld a, (tmp_col)
    and 1
    jr nz, dc64_odd
    ld a, (hl)
    and 0x0f
    ld d, a
    ld a, e
    and 0xf0
    or d
    ld (hl), a
    jr dc64_next_scan

dc64_odd:
    ld a, (hl)
    and 0xf0
    ld d, a
    ld a, e
    and 0x0f
    or d
    ld (hl), a

dc64_next_scan:
    inc h
    ld a, (tmp_scan)
    inc a
    ld (tmp_scan), a
    cp 8
    jr c, dc64_scan_loop
    ret

draw_input_cursor_at_tmp:
    ld a, (tmp_row)
    call compute_screen_base
    ld a, 7
    add a, h
    ld h, a
    ld a, (tmp_col)
    srl a
    add a, l
    ld l, a
    ld a, (tmp_col)
    and 1
    ld b, 0xf0
    jr z, dict_apply
    ld b, 0x0f
dict_apply:
    ld a, (hl)
    or b
    ld (hl), a
    ret

clear_ikkle_region:
    ld a, b
    ld (tmp_row), a
    ld a, c
    ld (tmp_col), a
    ld a, d
    ld (tmp_scan), a
    ld a, e
    ld (tmp_char), a
    xor a
    ld (piece_scan), a

cir_scan_loop:
    ld a, (piece_scan)
    cp 4
    jr nc, cir_attrs

    ld a, (tmp_row)
    call compute_screen_base
    ld a, (tmp_scan)
    ld d, a
    ld a, (piece_scan)
    add a, d
    add a, h
    ld h, a
    ld a, (tmp_col)
    srl a
    add a, l
    ld l, a
    ld a, (tmp_char)
    ld b, a
    xor a
cir_px_loop:
    ld (hl), a
    inc hl
    djnz cir_px_loop

    ld a, (piece_scan)
    inc a
    ld (piece_scan), a
    jr cir_scan_loop

cir_attrs:
    ld a, (tmp_row)
    call attr_cell_for_tmpcol
    ld a, (tmp_char)
    ld b, a
    ld a, (current_attr)
cir_attr_loop:
    ld (hl), a
    inc hl
    djnz cir_attr_loop
    ret

draw_ikkle_text_at:
    ld (text_ptr), hl

dit_loop:
    ld a, (tmp_col)
    cp 64
    ret nc

    ld hl, (text_ptr)
    ld a, (hl)
    or a
    ret z
    ld (tmp_char), a
    push hl

    ld a, (tmp_row)
    call compute_screen_base
    ld a, (tmp_scan)
    add a, h
    ld h, a
    ld a, (tmp_col)
    srl a
    add a, l
    ld l, a
    ld a, (tmp_col)
    ld c, a
    call ikkle_clear_cell_hl

    push hl
    ld a, (tmp_row)
    call attr_cell_for_tmpcol
    ld a, (current_attr)
    ld (hl), a
    pop hl

    ld a, (tmp_char)
    cp 33
    jr c, dit_space
    cp 128
    jr nc, dit_space
    cp 96
    jr c, dit_no_fold
    sub 32
dit_no_fold:
    sub 32
    add a, a
    ld e, a
    ld d, 0
    push hl
    ld hl, timer_ikkle_packed
    add hl, de
    ld d, (hl)
    inc hl
    ld e, (hl)
    pop hl
    call ikkle_blit_de_hl

dit_space:
    pop hl
    inc hl
    ld (text_ptr), hl
    ld a, (tmp_col)
    inc a
    ld (tmp_col), a
    jr dit_loop

draw_ikkle_text_abs_y:
    ld (text_ptr), hl
    ld a, b
    ld (tmp_scan), a
    ld a, c
    ld (tmp_col), a

dita_loop:
    ld a, (tmp_col)
    cp 64
    ret nc

    ld hl, (text_ptr)
    ld a, (hl)
    or a
    ret z
    ld (tmp_char), a
    push hl

    call ikkle_clear_abs_cell
    call ikkle_attr_abs_cell

    ld a, (tmp_char)
    cp 33
    jr c, dita_space
    cp 128
    jr nc, dita_space
    cp 96
    jr c, dita_no_fold
    sub 32
dita_no_fold:
    sub 32
    add a, a
    ld e, a
    ld d, 0
    ld hl, timer_ikkle_packed
    add hl, de
    ld d, (hl)
    inc hl
    ld e, (hl)
    ld a, d
    ld (piece_row), a
    ld a, e
    ld (piece_col), a
    xor a
    ld (piece_scan), a
    call ikkle_blit_abs_saved

dita_space:
    pop hl
    inc hl
    ld (text_ptr), hl
    ld a, (tmp_col)
    inc a
    ld (tmp_col), a
    jr dita_loop

ikkle_clear_abs_cell:
    xor a
    ld (piece_scan), a
icac_loop:
    ld a, (tmp_scan)
    ld d, a
    ld a, (piece_scan)
    add a, d
    call compute_pixel_base
    ld a, (tmp_col)
    srl a
    add a, l
    ld l, a
    ld a, (tmp_col)
    bit 0, a
    jr nz, icac_odd
    ld a, (hl)
    and 0x0f
    ld (hl), a
    jr icac_next
icac_odd:
    ld a, (hl)
    and 0xf0
    ld (hl), a
icac_next:
    ld a, (piece_scan)
    inc a
    ld (piece_scan), a
    cp 4
    jr c, icac_loop
    ret

ikkle_attr_abs_cell:
    ld a, (tmp_scan)
    srl a
    srl a
    srl a
    call ikkle_set_abs_attr_row
    ld a, (tmp_scan)
    add a, 3
    srl a
    srl a
    srl a
    ld d, a
    ld a, (tmp_scan)
    srl a
    srl a
    srl a
    cp d
    ret z
    ld a, d

ikkle_set_abs_attr_row:
    call compute_attr_base
    ld a, (tmp_col)
    srl a
    add a, l
    ld l, a
    ld a, (current_attr)
    ld (hl), a
    ret

ikkle_blit_abs_saved:
    ld a, (piece_row)
    and 0xf0
    rrca
    rrca
    rrca
    rrca
    call ikkle_draw_abs_nibble
    ld a, (piece_row)
    and 0x0f
    call ikkle_draw_abs_nibble
    ld a, (piece_col)
    and 0xf0
    rrca
    rrca
    rrca
    rrca
    call ikkle_draw_abs_nibble
    ld a, (piece_col)
    and 0x0f

ikkle_draw_abs_nibble:
    ld (tmp_attr), a
    ld a, (tmp_scan)
    ld d, a
    ld a, (piece_scan)
    add a, d
    call compute_pixel_base
    ld a, (tmp_col)
    srl a
    add a, l
    ld l, a
    ld a, (tmp_col)
    bit 0, a
    jr nz, idan_odd
    ld a, (tmp_attr)
    rlca
    rlca
    rlca
    rlca
    ld b, a
    ld a, (hl)
    and 0x0f
    or b
    ld (hl), a
    jr idan_next
idan_odd:
    ld a, (tmp_attr)
    ld b, a
    ld a, (hl)
    and 0xf0
    or b
    ld (hl), a
idan_next:
    ld a, (piece_scan)
    inc a
    ld (piece_scan), a
    ret

ikkle_clear_cell_hl:
    push hl
    bit 0, c
    jr nz, icc_odd

    ld b, 4
icc_even_loop:
    ld a, (hl)
    and 0x0f
    ld (hl), a
    inc h
    djnz icc_even_loop
    pop hl
    ret

icc_odd:
    ld b, 4
icc_odd_loop:
    ld a, (hl)
    and 0xf0
    ld (hl), a
    inc h
    djnz icc_odd_loop
    pop hl
    ret

ikkle_blit_de_hl:
    bit 0, c
    jr nz, ib_odd_col

    ld a, d
    and 0xf0
    ld b, a
    ld a, (hl)
    and 0x0f
    or b
    ld (hl), a
    ld a, d
    and 0x0f
    rlca
    rlca
    rlca
    rlca
    inc h
    ld b, a
    ld a, (hl)
    and 0x0f
    or b
    ld (hl), a
    ld a, e
    and 0xf0
    inc h
    ld b, a
    ld a, (hl)
    and 0x0f
    or b
    ld (hl), a
    ld a, e
    and 0x0f
    rlca
    rlca
    rlca
    rlca
    inc h
    ld b, a
    ld a, (hl)
    and 0x0f
    or b
    ld (hl), a
    ret

ib_odd_col:
    ld a, d
    rrca
    rrca
    rrca
    rrca
    and 0x0f
    ld b, a
    ld a, (hl)
    and 0xf0
    or b
    ld (hl), a
    ld a, d
    and 0x0f
    inc h
    ld b, a
    ld a, (hl)
    and 0xf0
    or b
    ld (hl), a
    ld a, e
    rrca
    rrca
    rrca
    rrca
    and 0x0f
    inc h
    ld b, a
    ld a, (hl)
    and 0xf0
    or b
    ld (hl), a
    ld a, e
    and 0x0f
    inc h
    ld b, a
    ld a, (hl)
    and 0xf0
    or b
    ld (hl), a
    ret

draw_connection_indicator:
    ld a, NETCHESSZX_STATUS_ROW
    call compute_screen_base
    ld a, 31
    add a, l
    ld l, a
    ld de, conn_pattern
    ld b, 8
dci_px:
    ld a, (de)
    ld (hl), a
    inc de
    inc h
    djnz dci_px
    ld a, NETCHESSZX_STATUS_ROW
    call compute_attr_base
    ld a, 31
    add a, l
    ld l, a
    ld a, (conn_attr)
    or a
    jr nz, dci_attr_ready
    ld a, ATTR_CONN_OFF
dci_attr_ready:
    ld (hl), a
    ret

draw_right_hline:
    call compute_screen_base
    ld a, NETCHESSZX_INFO_PANEL_COL
    add a, l
    ld l, a
    ld a, (hl)
    or 0x0f
    ld (hl), a
    inc l
    ld b, 13
drh_loop:
    ld (hl), 0xff
    inc l
    djnz drh_loop
    ret

draw_right_hline_full_left:
    call compute_screen_base
    ld a, NETCHESSZX_INFO_PANEL_COL
    add a, l
    ld l, a
    ld b, 14
drhfl_loop:
    ld (hl), 0xff
    inc l
    djnz drhfl_loop
    ret

draw_banner_separator:
    ld a, 2
    call compute_screen_base
    ld b, 32
dbs_loop:
    ld (hl), 0xff
    inc hl
    djnz dbs_loop
    ret

_spectrum_key_edit_pressed:
    ld hl, 0
    ld bc, 0xfefe
    in a, (c)
    rra
    ret c
    ld b, 0xf7
    in a, (c)
    rra
    ret c
    inc l
    ret

spectrum_key_scan_raw:
    ld bc, 0xfefe
    in a, (c)
    bit 0, a
    jr nz, skp_no_break
    ld b, 0x7f
    in a, (c)
    bit 0, a
    jr nz, skp_no_break
    ld hl, 0x8a
    ret

skp_no_break:
    ld b, 0xbf
    in a, (c)
    bit 0, a
    jr nz, skp_space
    ld hl, 13
    ret

skp_space:
    ld b, 0x7f
    in a, (c)
    bit 0, a
    jr nz, skp_shift
    ld hl, 32
    ret

skp_shift:
    ld b, 0xfe
    in a, (c)
    bit 0, a
    jr nz, skp_symbol_check
    ld hl, skp_shift_table
    call skp_scan_table
    ret c

skp_symbol_check:
    ld b, 0x7f
    in a, (c)
    bit 1, a
    jr nz, skp_letters

skp_symbol:
    ld hl, skp_symbol_table
    jp skp_scan_table

skp_letters:
    ld hl, skp_letters_table
    jp skp_scan_table

; Port high followed by active-low mask/key pairs and a zero mask.
; A zero port ends the table; pair order preserves key priority.
skp_scan_table:
    ld b, (hl)
    inc hl
    ld a, b
    or a
    jr z, skp_none
    in a, (c)
    cpl
    ld e, a
skp_scan_row:
    ld a, (hl)
    inc hl
    or a
    jr z, skp_scan_table
    and e
    ld a, (hl)
    inc hl
    jr z, skp_scan_row
    ld l, a
    ld h, 0
    scf
    ret

skp_none:
    ld hl, 0
    ret

skp_shift_table:
    DEFB 0xef,0x01,8,0x02,0,0x04,0x84,0x08,0x81,0x10,0x82,0
    DEFB 0xf7,0x01,0x88,0x02,0x89,0x10,0x83,0
    DEFB 0

skp_symbol_table:
    DEFB 0xfe,0x08,'?',0x02,':',0x04,'`',0x10,'/',0
    DEFB 0xfd,0x01,'~',0x02,'|',0x04,92,0x08,'{',0x10,'}',0
    DEFB 0xfb,0x01,0,0x02,0,0x04,0,0x08,'<',0x10,'>',0
    DEFB 0xf7,0x01,'!',0x02,'@',0x04,'#',0x08,'$',0x10,'%',0
    DEFB 0xef,0x10,'&',0x08,39,0x04,'(',0x02,')',0x01,'_',0
    DEFB 0xdf,0x01,34,0x02,';',0x04,0,0x08,']',0x10,'[',0
    DEFB 0xbf,0x10,'^',0x08,'-',0x04,'+',0x02,'=',0
    DEFB 0x7f,0x04,'.',0x08,44,0x10,'*',0
    DEFB 0

skp_letters_table:
    DEFB 0xfe,0x08,'c',0x02,'z',0x04,'x',0x10,'v',0
    DEFB 0xfb,0x01,'q',0x02,'w',0x04,'e',0x08,'r',0x10,'t',0
    DEFB 0xfd,0x01,'a',0x02,'s',0x04,'d',0x08,'f',0x10,'g',0
    DEFB 0x7f,0x10,'b',0x04,'m',0x08,'n',0
    DEFB 0xbf,0x10,'h',0x08,'j',0x04,'k',0x02,'l',0
    DEFB 0xdf,0x01,'p',0x02,'o',0x04,'i',0x08,'u',0x10,'y',0
    DEFB 0xf7,0x01,'1',0x02,'2',0x04,'3',0x08,'4',0x10,'5',0
    DEFB 0xef,0x10,'6',0x08,'7',0x04,'8',0x02,'9',0x01,'0',0
    DEFB 0
_spectrum_key_poll:
_spectrum_input_poll_event:
    ld a, (key_event)
    ld l, a
    ld h, 0
    xor a
    ld (key_event), a
    ret

spectrum_input_scan_raw:
    call _spectrum_key_edit_pressed
    ld a, l
    or a
    jr z, sisr_scan_key
    ld hl, 0x90
    ret
sisr_scan_key:
    jp spectrum_key_scan_raw

_spectrum_input_flush_until_release:
    xor a
    ld (key_event), a
    call spectrum_input_scan_raw
    ld a, l
    ld (key_raw), a
    ld (key_suppress), a
    or a
    ret nz
    ld (key_last), a
    ld (key_repeat_timer), a
    ret

_spectrum_input_suppress_until_release:
    xor a
    ld (key_event), a
    ld a, l
    ld (key_suppress), a
    ret

_spectrum_input_frame_tick:
    call spectrum_input_scan_raw
    ld a, l
    ld (key_raw), a
    or a
    jr nz, skp_tick_got_key
    ld (key_last), a
    ld (key_repeat_timer), a
    ld (key_suppress), a
    ret

skp_tick_got_key:
    ld b, a
    ld a, (key_suppress)
    or a
    jr z, skp_tick_check_last
    cp b
    ret z
    xor a
    ld (key_suppress), a

skp_tick_check_last:
    ld a, (key_last)
    cp b
    jr z, skp_tick_same_key

    ld a, b
    ld (key_last), a
    call skp_repeat_start_delay
    ld (key_repeat_timer), a
    ld a, b
    jr skp_latch_event

skp_tick_same_key:
    ld a, b
    call skp_repeatable
    or a
    ret z

    ld hl, key_repeat_timer
    ld a, (hl)
    or a
    jr z, skp_tick_repeat_fire
    dec (hl)
    ret

skp_tick_repeat_fire:
    ld a, b
    call skp_repeat_next_delay
    ld (key_repeat_timer), a
    ld a, b

skp_latch_event:
    ld b, a
    cp 0x8a
    jr z, skp_latch_store
    cp 0x90
    jr z, skp_latch_store
    ld a, (key_event)
    or a
    ret nz

skp_latch_store:
    ld a, b
    ld (key_event), a
    ret


skp_repeatable:
    cp 8
    jr z, skp_repeatable_yes
    cp 0x81
    jr c, skp_repeatable_text
    cp 0x8a
    jr c, skp_repeatable_yes

skp_repeatable_text:
    cp 33
    jr c, skp_repeatable_no
    cp 127
    jr c, skp_repeatable_yes

skp_repeatable_no:
    xor a
    ret

skp_repeatable_yes:
    ld a, 1
    ret

skp_repeat_start_delay:
    cp 8
    jr z, skp_repeat_start_backspace
    cp 0x81
    jr c, skp_repeat_start_text
    cp 0x8a
    jr c, skp_repeat_start_nav

skp_repeat_start_text:
    ld a, 20
    ret

skp_repeat_start_backspace:
    ld a, 12
    ret

skp_repeat_start_nav:
    ld a, 15
    ret

skp_repeat_next_delay:
    cp 8
    jr z, skp_repeat_next_backspace
    cp 0x81
    jr z, skp_repeat_next_vertical
    cp 0x82
    jr z, skp_repeat_next_vertical
    cp 0x83
    jr c, skp_repeat_next_text
    cp 0x8a
    jr c, skp_repeat_next_nav

skp_repeat_next_text:
    ld a, 3
    ret

skp_repeat_next_backspace:
    ld a, 1
    ret

skp_repeat_next_nav:
    ld a, 2
    ret

skp_repeat_next_vertical:
    ld a, 5
    ret

clear_right_text_pixels:
    ld (tmp_row), a
    call compute_screen_base
    ld d, h
    ld a, NETCHESSZX_INFO_PANEL_COL
    add a, l
    ld e, a
    ld c, 13
    jp clear_pixels_8

clear_right_pixel_band_abs:
    ld (tmp_scan), a
    ld a, b
    ld (piece_scan), a
    ld a, (tmp_scan)
    call compute_pixel_base
    ld a, NETCHESSZX_INFO_PANEL_COL
    add a, l
    ld l, a
crpba_loop:
    ld a, (piece_scan)
    or a
    ret z
    push hl
    ld b, 14
    xor a
crpba_px_loop:
    ld (hl), a
    inc hl
    djnz crpba_px_loop
    pop hl
    call pixel_down_hl
    ld a, (piece_scan)
    dec a
    ld (piece_scan), a
    jr crpba_loop

pixel_down_hl:
    inc h
    ld a, h
    and 7
    ret nz
    ld a, l
    add a, 32
    ld l, a
    ret c
    ld a, h
    sub 8
    ld h, a
    ret

clear_right_text_row:
    call clear_right_text_pixels
    ld a, (tmp_row)
    call compute_attr_base
    ld a, NETCHESSZX_INFO_PANEL_COL
    add a, l
    ld l, a
    ld b, 14
crtr_attr:
    ld (hl), ATTR_TEXT
    inc hl
    djnz crtr_attr
    ret

clear_notice_row:
    ld a, NETCHESSZX_INFO_NOTICE_ROW
    jp clear_right_text_row

calc_len64:
    ld b, 64
cl64_loop:
    ld a, (hl)
    or a
    jr z, cl64_done
    inc hl
    djnz cl64_loop
cl64_done:
    ld a, b
    ret

font_scanline:
    cp 127
    jr nz, fs_not_swatch
    ld a, 0xf0
    ret
fs_not_swatch:
    cp 32
    jr c, fs_blank
    cp 127
    jr nc, fs_blank
    sub 32
    ld l, a
    ld h, 0
    add hl, hl
    ld d, 0
    ld e, a
    add hl, de
    ld de, font_packed
    add hl, de
    ld a, (tmp_scan)
    srl a
    ld e, a
    ld d, 0
    add hl, de
    ld a, (hl)
    ld d, a
    ld a, (tmp_scan)
    and 1
    ld a, d
    jr nz, fs_low
    rrca
    rrca
    rrca
    rrca
fs_low:
    and 0x0f
    ld e, a
    ld d, 0
    ld hl, font_lut
    add hl, de
    ld a, (hl)
    ret
fs_blank:
    xor a
    ret

clear_text_row:
    push af
    push bc
    call clear_row_pixels
    pop bc
    pop af
    jp fill_attr_line

clear_row_pixels:
    call compute_screen_base
    ld d, h
    ld e, l
    ld c, 31
    jp clear_pixels_8

clear_pixels_8:
    ld b, 8
cp8_loop:
    push bc
    push de
    ld h, d
    ld l, e
    ld (hl), 0
    inc de
    ld b, 0
    ldir
    pop de
    pop bc
    inc d
    djnz cp8_loop
    ret

fill_attr_line:
    call compute_attr_base
    ld (hl), c
    ld d, h
    ld e, l
    inc de
    ld bc, 31
    ldir
    ret

_netchesszx_board_theme_apply:
    ld hl, 2
    add hl, sp
    ld a, (hl)
    cp 5
    jr c, nbta_index_ok
    xor a
nbta_index_ok:
    ld (_netchesszx_board_theme_index), a
IFDEF NETCHESSZX_NEXT
    call next_board_coord_palette_sync
    ld a, (_netchesszx_board_theme_index)
ENDIF
    ld e, a
    ld d, 0
    ld hl, board_theme_light_attrs
    add hl, de
    ld a, (hl)
    ld (_netchesszx_board_light_attr), a
    ld hl, board_theme_dark_attrs
    add hl, de
    ld a, (hl)
    ld (_netchesszx_board_dark_attr), a
    call restore_board_frame_attrs
    jp draw_board_frame

IFDEF NETCHESSZX_NEXT
; Theme 1 stays on classic ULA attributes.  Themes 2-5 use private ULA+ group
; 2 entries: unselected INK1/PAPER0 and selected INK2/PAPER1.  Groups 0/1,
; generated menu attributes and board/piece sprites are not modified.
next_board_coord_palette_sync:
    ld a, NEXTREG_PALETTE_CONTROL
    call nextreg_read
    and 0xfe                    ; ULANext off; preserve active palette choices
    ld (tmp_scan), a
    ld a, (_netchesszx_board_theme_index)
    or a
    jr nz, nbcps_apply

    ld a, (tmp_scan)
    ld e, a
    ld a, NEXTREG_PALETTE_CONTROL
    call nextreg_write
    ld a, NEXTREG_ULA_CONTROL
    call nextreg_read
    and 0xf7                    ; theme 1: classic ULA, never group-2 FLASH
    ld e, a
    ld a, NEXTREG_ULA_CONTROL
    jp nextreg_write

nbcps_apply:
    dec a
    add a, a
    add a, a
    ld e, a
    ld d, 0
    ld hl, next_board_coord_rgb333
    add hl, de
    ld d, (hl)
    inc hl
    ld e, (hl)
    inc hl
    push de                     ; COLOR1
    ld d, (hl)
    inc hl
    ld e, (hl)                  ; COLOR2
    push de

    xor a                       ; Next init owns ULA palette 0
    ld e, a
    ld a, NEXTREG_PALETTE_CONTROL
    call nextreg_write

    pop hl
    ld e, NEXT_BOARD_COORD_INK2_INDEX
    call next_board_write_ula_pair
    pop hl
    push hl
    ld e, NEXT_BOARD_COORD_INK1_INDEX
    call next_board_write_ula_pair
    pop hl
    ld e, NEXT_BOARD_COORD_PAPER1_INDEX
    call next_board_write_ula_pair

    ld a, (tmp_scan)
    ld e, a
    ld a, NEXTREG_PALETTE_CONTROL
    call nextreg_write
    ld a, NEXTREG_ULA_CONTROL
    call nextreg_read
    or 0x08                     ; enable only after all group-2 entries are live
    ld e, a
    ld a, NEXTREG_ULA_CONTROL
    jp nextreg_write

; E = ULA palette index, HL = exact NextReg 0x44 pair.
next_board_write_ula_pair:
    ld a, NEXTREG_PALETTE_INDEX
    call nextreg_write
    ld bc, NEXTREG_SELECT_PORT
    ld a, NEXTREG_PALETTE_VALUE_9
    out (c), a
    ld bc, NEXTREG_DATA_PORT
    ld a, h
    out (c), a
    ld a, l
    out (c), a
    ret

next_board_coord_rgb333:
    DEFB 0xbb,0x00,0x4e,0x01
    DEFB 0xff,0x00,0x95,0x01
    DEFB 0xfa,0x01,0xb1,0x01
    DEFB 0xd1,0x00,0x88,0x01
next_board_coord_rgb333_end:
ENDIF

compute_screen_base:
    ld l, a
    and 0x18
    or 0x40
    ld h, a
    ld a, l
    and 0x07
    rrca
    rrca
    rrca
    ld l, a
    ret

compute_screen_base_de8:
    call compute_screen_base
    ld d, h
    ld e, l
    ld b, 8
    ret

compute_pixel_base:
    ld l, a
    and 0xc0
    rrca
    rrca
    rrca
    ld h, a
    ld a, l
    and 0x07
    or h
    or 0x40
    ld h, a
    ld a, l
    and 0x38
    rlca
    rlca
    ld l, a
    ret

compute_attr_base:
    rrca
    rrca
    rrca
    ld l, a
    and 0x03
    or 0x58
    ld h, a
    ld a, l
    and 0xe0
    ld l, a
    ret

draw_badge:
    ld hl, 0x401c
    ld c, 4
    call draw_badge_cells
    ld hl, 0x403b
    ld c, 5
    call draw_badge_cells

    ld hl, 0x581c
    ld (hl), 0x42
    inc hl
    ld (hl), 0x56
    inc hl
    ld (hl), 0x74
    inc hl
    ld (hl), 0x61

    ld hl, 0x583b
    ld (hl), 0x42
    inc hl
    ld (hl), 0x56
    inc hl
    ld (hl), 0x74
    inc hl
    ld (hl), 0x61
    inc hl
    ld (hl), 0x48
    ret

draw_badge_cells:
    ld de, badge_pattern
    ld b, 8
dbc_scan:
    push bc
    push hl
    ld a, (de)
    ld b, c
dbc_byte:
    ld (hl), a
    inc l
    djnz dbc_byte
    pop hl
    inc h
    inc de
    pop bc
    djnz dbc_scan
    ret

draw_square_mark:
    call compute_square_bc
    ld a, b
    ld (piece_row), a
    ld a, c
    ld (piece_col), a

    ld a, (tmp_attr)
    ld (mark_mode), a
IFDEF NETCHESSZX_NEXT
    call next_marker_set_mark_current_square
ENDIF
    ld a, (piece_row)
    call compute_attr_base
    ld a, (piece_col)
    add a, l
    ld l, a
    ld a, (hl)
    and 0x78
    ld (tmp_attr), a
    ld a, (_netchesszx_board_theme_index)
    ld e, a
    ld d, 0
    ld hl, board_theme_mark_inks
    add hl, de
    ld a, (tmp_attr)
    or (hl)
    ld d, a
    ld a, (piece_row)
    ld b, a
    ld a, (piece_col)
    ld c, a
    ld a, d
    call set_square_attr_2x2

    ld a, (piece_row)
    ld e, 0
    call dsm_draw_horizontal

    ld a, (piece_row)
    inc a
    ld e, 7
    call dsm_draw_horizontal

    ld d, 0x80
    ld e, 0x01
    ld a, (piece_row)
    call dsm_prepare_side_row
    ld b, 8
    call dsm_draw_side_span
    ld a, (piece_row)
    inc a
    call dsm_prepare_side_row
    ld b, 8
    call dsm_draw_side_span

    ld a, (mark_mode)
    or a
    ret z
    ld a, (piece_col)
    ld c, a
    ld a, (piece_row)
    ld e, 1
    call dsm_draw_horizontal

    ld a, (piece_row)
    inc a
    ld e, 6
    call dsm_draw_horizontal

    ld d, 0x40
    ld e, 0x02
    ld a, (piece_row)
    call dsm_prepare_side_row
    inc h
    ld b, 7
    call dsm_draw_side_span
    ld a, (piece_row)
    inc a
    call dsm_prepare_side_row
    ld b, 7
    jp dsm_draw_side_span

dsm_draw_horizontal:
    call compute_screen_base
    ld a, e
    add a, h
    ld h, a
    ld a, (piece_col)
    add a, l
    ld l, a
    ld (hl), 0xff
    inc l
    ld (hl), 0xff
    ret

dsm_prepare_side_row:
    call compute_screen_base
    ld a, (piece_col)
    add a, l
    ld l, a
    ret

dsm_draw_side_span:
    ld a, (hl)
    or d
    ld (hl), a
    inc l
    ld a, (hl)
    or e
    ld (hl), a
    dec l
    inc h
    djnz dsm_draw_side_span
    ret
