SECTION code_user

PUBLIC _menu_config_run_ovl_entry
PUBLIC _menu_config_paint_attrs_ovl_entry
PUBLIC _menu_config_validate_ip_ovl_entry
PUBLIC _menu_config_edit_line_ovl_entry
PUBLIC _menu_config_render_ovl_entry
PUBLIC _menu_config_piece_set_options_asm

EXTERN _spectrum_info_line
EXTERN _spectrum_info_show_game_setup
EXTERN _spectrum_overlay_context
EXTERN _spectrum_info_show_setup
EXTERN _setup_choice
EXTERN _setup_focus_choice
EXTERN _setup_focus_board_theme
EXTERN _setup_visible_mask
EXTERN _setup_defined_mask
EXTERN _setup_cursor
EXTERN _setup_room_editing
EXTERN _setup_edit_row
EXTERN _setup_port_text
EXTERN _netchesszx_mqtt_code
EXTERN _netchesszx_direct_host
EXTERN _last_ip

    DEFB 5
    DW _menu_config_run_ovl_entry
    DW _menu_config_paint_attrs_ovl_entry
    DW _menu_config_validate_ip_ovl_entry
    DW _menu_config_edit_line_ovl_entry
    DW _menu_config_render_ovl_entry

_menu_config_run_ovl_entry:
    inc de
    inc de
    ld a, (de)
    ld c, a
    inc de
    ld a, (de)
    ld b, a
menu_config_run_dirty:
    bit 0, c
    ld hl, menu_config_line_game
    call nz, menu_config_info_line
    bit 1, c
    ld hl, menu_config_line_link
    call nz, menu_config_info_line
    bit 3, c
    ld hl, menu_config_line_mqtt
    call nz, menu_config_info_line
    ld a, c
    and 0x30
    call nz, menu_config_show_game_setup
    bit 4, c
    ld hl, menu_config_line_side
    call nz, menu_config_info_line
    bit 5, c
    ld hl, menu_config_line_notation
    call nz, menu_config_info_line
    bit 6, c
    ld hl, menu_config_line_board
    call nz, menu_config_info_line
    bit 7, c
    ld hl, menu_config_line_set
    call nz, menu_config_info_line
    bit 0, b
    ld hl, menu_config_line_hints
    call nz, menu_config_info_line
    bit 1, b
    ld hl, menu_config_line_start
    call nz, menu_config_info_line
    ld l, 1
    ret

_menu_config_render_ovl_entry:
    push de
    ld hl, (_setup_visible_mask)
    ld a, (_setup_cursor)
    ld b, a
    inc b
    ld de, 1
menu_config_render_cursor_shift:
    dec b
    jr z, menu_config_render_cursor_mask
    sla e
    rl d
    jr menu_config_render_cursor_shift
menu_config_render_cursor_mask:
    ld a, l
    and e
    ld c, a
    ld a, h
    and d
    or c
    jr nz, menu_config_render_cursor_ready
    xor a
    ld (_setup_cursor), a
menu_config_render_cursor_ready:
    pop de
    inc de
    inc de
    ld a, (de)
    or a
    jr z, menu_config_render_incremental
    ld hl, (_setup_visible_mask)
    ld (menu_config_render_dirty), hl
    call _spectrum_info_show_setup
    jr menu_config_render_force
menu_config_render_incremental:
    push de
    inc de
    inc de
    ld a, (de)
    cpl
    ld c, a
    inc de
    ld a, (de)
    cpl
    ld b, a
    ld hl, (_setup_visible_mask)
    ld a, l
    and c
    ld l, a
    ld a, h
    and b
    ld h, a
    ld (menu_config_render_dirty), hl
    pop de
    inc de
    ld a, (de)
    cp 0xff
    jr z, menu_config_render_force
    cp 9
    jr nz, menu_config_render_clear_normal
    ld a, 13
    jr menu_config_render_clear
menu_config_render_clear_normal:
    cp 4
    jr c, menu_config_render_clear
    add a, 3
menu_config_render_clear:
    ld l, a
    call menu_config_clear_tail
menu_config_render_force:
    ld hl, (_spectrum_overlay_context)
    ld de, (_setup_visible_mask)
    ld a, l
    and e
    ld l, a
    ld a, h
    and d
    ld h, a
    ld de, (menu_config_render_dirty)
    ld a, l
    or e
    ld l, a
    ld a, h
    or d
    ld h, a
    ld (menu_config_render_dirty), hl
    ld a, (_setup_choice + 1)
    or a
    ld a, l
    jr z, menu_config_render_edit_direct
    and 0x04
    jr menu_config_render_edit_ready
menu_config_render_edit_direct:
    and 0x0c
menu_config_render_edit_ready:
    ld (menu_config_render_edit), a
    cpl
    and l
    ld l, a
    ld a, h
    or l
    jr z, menu_config_render_overlay_done
    ld b, h
    ld c, l
    call menu_config_run_dirty
menu_config_render_overlay_done:
    ld a, (menu_config_render_edit)
    and 0x04
    jr z, menu_config_render_mqtt
    ld a, 2
    call menu_config_edit_line
menu_config_render_mqtt:
    ld a, (menu_config_render_edit)
    and 0x08
    jr z, menu_config_render_paint
    ld a, 3
    call menu_config_edit_line
menu_config_render_paint:
    call _menu_config_paint_attrs_ovl_entry
    ld l, 1
    ret

menu_config_clear_tail:
    ld a, l
    add a, 7
menu_config_clear_tail_loop:
    cp 22
    ret nc
    ld (menu_config_blank_line), a
    push af
    ld hl, menu_config_blank_line
    call _spectrum_info_line
    pop af
    inc a
    jr menu_config_clear_tail_loop

menu_config_info_line:
    push bc
    call _spectrum_info_line
    pop bc
    ret

menu_config_show_game_setup:
    push bc
    call _spectrum_info_show_game_setup
    pop bc
    ret

_menu_config_paint_attrs_ovl_entry:
IFDEF NETCHESSZX_NEXT
    ; Setup previews use ULA+ group 3; START reapplies the chosen game theme.
    ld bc, 0x243b
    ld a, 0x68
    out (c), a
    inc b
    in a, (c)
    or 0x08
    out (c), a
ENDIF
    ld hl, _setup_choice + 4
    call menu_config_pack_choices
    ld (menu_config_values), a
    ld hl, (_setup_visible_mask)
    ld a, l
    ld (menu_config_visible_l), a
    ld a, h
    ld (menu_config_visible_h), a
    ld hl, (_setup_defined_mask)
    ld a, l
    ld (menu_config_defined_l), a
    ld a, h
    ld (menu_config_defined_h), a
    ld a, (_setup_cursor)
    ld (menu_config_cursor), a
    ld hl, _setup_focus_choice + 4
    call menu_config_pack_choices
    ld (menu_config_focus_bits), a
    ld a, (_setup_focus_board_theme)
    ld (menu_config_board_theme), a
    ld a, (_setup_focus_choice + 5)
    ld (menu_config_piece_set), a
    ld a, (_setup_choice + 5)
    ld (menu_config_piece_selected), a
    call menu_config_paint_game_attrs
    call menu_config_paint_link_attrs
    call menu_config_paint_room_attrs
    call menu_config_paint_mqtt_attrs
    call menu_config_paint_side_attrs
    call menu_config_paint_notation_attrs
    call menu_config_paint_board_attrs
    call menu_config_paint_set_attrs
    call menu_config_paint_hints_attrs
    call menu_config_paint_action_attrs
    ld l, 1
    ret

menu_config_pack_choices:
    ld b, 5
    xor a
menu_config_pack_choices_loop:
    add a, a
    or (hl)
    dec hl
    djnz menu_config_pack_choices_loop
    ret

_menu_config_edit_line_ovl_entry:
    ld a, (de)
menu_config_edit_line:
    ld (menu_config_edit_row), a
    ld a, (_setup_choice + 1)
    or a
    jr z, menu_config_edit_direct
    ld a, 1
    ld (menu_config_edit_flags), a
    ld hl, _netchesszx_mqtt_code
    ld a, 6
    jr menu_config_edit_selected
menu_config_edit_direct:
    xor a
    ld (menu_config_edit_flags), a
    ld a, (menu_config_edit_row)
    cp 2
    jr nz, menu_config_edit_port
    ld a, (_setup_choice)
    or a
    jr nz, menu_config_edit_join_host
    ld hl, _last_ip
    ld a, 4
    ld (menu_config_edit_flags), a
    jr menu_config_edit_direct_host_ready
menu_config_edit_join_host:
    ld hl, _netchesszx_direct_host
menu_config_edit_direct_host_ready:
    ld a, 15
    jr menu_config_edit_selected
menu_config_edit_port:
    ld hl, _setup_port_text
    ld a, 5
menu_config_edit_selected:
    ld (menu_config_edit_max), a
    ld a, (_setup_room_editing)
    or a
    jr z, menu_config_edit_have_cursor
    ld a, (_setup_edit_row)
    ld c, a
    ld a, (menu_config_edit_row)
    cp c
    jr nz, menu_config_edit_have_cursor
    ld a, (menu_config_edit_flags)
    or 2
    ld (menu_config_edit_flags), a
menu_config_edit_have_cursor:
    ld a, (menu_config_edit_flags)
    bit 2, a
    jr z, menu_config_edit_have_text
    ld a, (hl)
    or a
    jr nz, menu_config_edit_have_text
    ld hl, menu_config_text_local
menu_config_edit_have_text:
    push hl
    ld hl, menu_config_edit_line_buf
    ld a, (menu_config_edit_row)
    call menu_config_setup_screen_row
    ld (hl), a
    inc hl
    ld a, (menu_config_edit_flags)
    bit 0, a
    jr nz, menu_config_edit_label_room
    ld a, (menu_config_edit_row)
    cp 2
    jr z, menu_config_edit_label_ip
    ld de, menu_config_label_port
    jr menu_config_edit_copy_label
menu_config_edit_label_room:
    ld de, menu_config_label_room
    jr menu_config_edit_copy_label
menu_config_edit_label_ip:
    ld de, menu_config_label_ip
menu_config_edit_copy_label:
    ld b, 7
menu_config_edit_copy_label_loop:
    ld a, (de)
    ld (hl), a
    inc de
    inc hl
    djnz menu_config_edit_copy_label_loop
    pop de
    ld b, 0
menu_config_edit_copy_text_loop:
    ld a, (de)
    or a
    jr z, menu_config_edit_after_text
    ld (hl), a
    inc de
    inc hl
    inc b
    jr menu_config_edit_copy_text_loop
menu_config_edit_after_text:
    ld a, (menu_config_edit_flags)
    bit 1, a
    jr z, menu_config_edit_finish
    ld a, (menu_config_edit_max)
    cp b
    jr z, menu_config_edit_finish
    jr c, menu_config_edit_finish
    ld (hl), '_'
    inc hl
menu_config_edit_finish:
    ld (hl), 0
    ld hl, menu_config_edit_line_buf
    call _spectrum_info_line
    ld l, 1
    ret

menu_config_setup_screen_row:
    cp 9
    jr z, menu_config_setup_screen_row_action
    ld e, a
    cp 4
    ld a, e
    jr c, menu_config_setup_screen_row_base
    add a, 3
menu_config_setup_screen_row_base:
    add a, 7
    ret
menu_config_setup_screen_row_action:
    ld a, 20
    ret

menu_config_paint_game_attrs:
    ld a, (menu_config_visible_l)
    bit 0, a
    ret z
    ld a, 1
    ld (menu_config_binary_mask), a
    ld (menu_config_binary_row), a
    dec a
    ld (menu_config_binary_row), a
    ld a, 1
    ld (menu_config_binary_bit), a
    xor a
    ld (menu_config_binary_invert), a
    call menu_config_prepare_binary
    ld hl, 0x58f2
    ld b, 3
    call menu_config_header_span
    ld hl, 0x58f6
    ld b, 3
    call menu_config_paint_left_binary
    ld hl, 0x58fb
    ld b, 2
    jp menu_config_paint_right_binary

menu_config_paint_link_attrs:
    ld a, (menu_config_visible_l)
    bit 1, a
    ret z
    ld a, 2
    ld (menu_config_binary_mask), a
    ld a, 1
    ld (menu_config_binary_row), a
    ld a, 2
    ld (menu_config_binary_bit), a
    ld a, 1
    ld (menu_config_binary_invert), a
    call menu_config_prepare_binary
    ld hl, 0x5912
    ld b, 3
    call menu_config_header_span
    ld hl, 0x5916
    ld b, 2
    call menu_config_paint_left_binary
    ld hl, 0x591b
    ld b, 3
    jp menu_config_paint_right_binary

menu_config_paint_side_attrs:
    ld a, (menu_config_visible_l)
    bit 4, a
    ret z
    ld a, 16
    ld (menu_config_binary_mask), a
    ld a, 4
    ld (menu_config_binary_row), a
    ld a, 4
    ld (menu_config_binary_bit), a
    xor a
    ld (menu_config_binary_invert), a
    call menu_config_prepare_binary
    ld hl, 0x59d2
    ld b, 4
    call menu_config_header_span
    ld hl, 0x59d6
    ld b, 3
    call menu_config_paint_left_binary
    ld hl, 0x59db
    ld b, 3
    jp menu_config_paint_right_binary

menu_config_paint_notation_attrs:
    ld a, (menu_config_visible_l)
    bit 5, a
    ret z
    ld a, 32
    ld (menu_config_binary_mask), a
    ld a, 5
    ld (menu_config_binary_row), a
    ld a, 8
    ld (menu_config_binary_bit), a
    xor a
    ld (menu_config_binary_invert), a
    call menu_config_prepare_binary
    ld hl, 0x59f2
    ld b, 4
    call menu_config_header_span
    ld hl, 0x59f6
    ld b, 3
    call menu_config_paint_left_binary
    ld hl, 0x59fb
    ld b, 2
    jp menu_config_paint_right_binary

menu_config_prepare_binary:
    ld a, (menu_config_binary_bit)
    ld b, a
    ld a, (menu_config_values)
    and b
    ld c, a
    ld a, (menu_config_focus_bits)
    and b
    ld e, a
    ld a, (menu_config_binary_invert)
    or a
    jr z, menu_config_prepare_binary_no_invert
    ld a, c
    xor b
    ld c, a
    ld a, e
    xor b
    ld e, a
menu_config_prepare_binary_no_invert:
    ld a, c
    ld (menu_config_value_flag), a
    ld a, e
    ld (menu_config_focus_value), a
    ld a, (menu_config_defined_l)
    ld c, a
    ld a, (menu_config_binary_mask)
    and c
    ld (menu_config_defined_flag), a
    ld a, (menu_config_cursor)
    ld c, a
    ld a, (menu_config_binary_row)
    cp c
    ld a, 0
    jr nz, menu_config_prepare_binary_row_done
    inc a
menu_config_prepare_binary_row_done:
    ld (menu_config_row_focus), a
    ret

menu_config_header_span:
    ld a, 0x03
    jp menu_config_attr_span

menu_config_paint_left_binary:
    ld a, b
    ld (menu_config_option_width), a
    ld d, 0
    ld a, (menu_config_defined_flag)
    or a
    jr z, menu_config_left_selected_done
    ld a, (menu_config_value_flag)
    or a
    jr nz, menu_config_left_selected_done
    inc d
menu_config_left_selected_done:
    ld e, 0
    ld a, (menu_config_row_focus)
    or a
    jr z, menu_config_left_focused_done
    ld a, (menu_config_focus_value)
    or a
    jr nz, menu_config_left_focused_done
    inc e
menu_config_left_focused_done:
    ld a, (menu_config_option_width)
    ld b, a
    jp menu_config_option_span

menu_config_paint_right_binary:
    ld a, b
    ld (menu_config_option_width), a
    ld d, 0
    ld a, (menu_config_defined_flag)
    or a
    jr z, menu_config_right_selected_done
    ld a, (menu_config_value_flag)
    or a
    jr z, menu_config_right_selected_done
    inc d
menu_config_right_selected_done:
    ld e, 0
    ld a, (menu_config_row_focus)
    or a
    jr z, menu_config_right_focused_done
    ld a, (menu_config_focus_value)
    or a
    jr z, menu_config_right_focused_done
    inc e
menu_config_right_focused_done:
    ld a, (menu_config_option_width)
    ld b, a
    jp menu_config_option_span

menu_config_paint_room_attrs:
    ld a, (menu_config_visible_l)
    bit 2, a
    ret z
    ld hl, 0x5932
    ld b, 3
    call menu_config_header_span
    ld hl, 0x5936
    ld a, (menu_config_values)
    bit 1, a
    ld b, 6
    jr nz, menu_config_room_width_done
    ld b, 8
menu_config_room_width_done:
    ld d, 0
    ld a, (menu_config_defined_l)
    bit 2, a
    jr z, menu_config_room_selected_done
    inc d
menu_config_room_selected_done:
    ld e, 0
    ld a, (menu_config_cursor)
    cp 2
    jr nz, menu_config_room_focused_done
    inc e
menu_config_room_focused_done:
    jp menu_config_option_span

menu_config_paint_mqtt_attrs:
    ld a, (menu_config_visible_l)
    bit 3, a
    ret z
    ld hl, 0x5952
    ld b, 3
    call menu_config_header_span
    ld hl, 0x5956
    ld a, (menu_config_values)
    bit 1, a
    ld b, 3
    jr z, menu_config_mqtt_width_done
    ld b, 6
menu_config_mqtt_width_done:
    ld d, 0
    ld a, (menu_config_defined_l)
    bit 3, a
    jr z, menu_config_mqtt_selected_done
    inc d
menu_config_mqtt_selected_done:
    ld e, 0
    ld a, (menu_config_cursor)
    cp 3
    jr nz, menu_config_mqtt_focused_done
    inc e
menu_config_mqtt_focused_done:
    jp menu_config_option_span

menu_config_paint_board_attrs:
    ld a, (menu_config_visible_l)
    bit 6, a
    ret z
    ld hl, 0x5a12
    ld b, 4
    call menu_config_header_span
    ld a, (menu_config_cursor)
    cp 6
    jr nz, menu_config_board_not_cursor
    ld a, (menu_config_board_theme)
    ld l, a
    jp menu_config_board_swatches
menu_config_board_not_cursor:
    ld a, (menu_config_defined_l)
    bit 6, a
    jr z, menu_config_board_not_defined
    ld a, (menu_config_board_theme)
    add a, 5
    ld l, a
    jp menu_config_board_swatches
menu_config_board_not_defined:
    ld l, 0xff
    jp menu_config_board_swatches

menu_config_paint_set_attrs:
    ld a, (menu_config_visible_l)
    bit 7, a
    ret z
    ld hl, 0x5a32
    ld b, 3
    call menu_config_header_span
    ld a, (menu_config_defined_l)
    bit 7, a
    jr nz, menu_config_set_selected_ready
    ld a, 0xff
    jr menu_config_set_selected_store
menu_config_set_selected_ready:
    ld a, (_setup_choice + 5)
menu_config_set_selected_store:
    ld (menu_config_piece_selected), a
    ld a, (menu_config_cursor)
    cp 7
    jr nz, menu_config_set_not_cursor
    ld a, (menu_config_piece_set)
    ld l, a
    jp _menu_config_piece_set_options_asm
menu_config_set_not_cursor:
    ld l, 0xff
    jp _menu_config_piece_set_options_asm

menu_config_paint_hints_attrs:
    ld a, (menu_config_visible_h)
    bit 0, a
    ret z
    xor a
    ld (menu_config_binary_mask), a
    ld a, 8
    ld (menu_config_binary_row), a
    ld a, 16
    ld (menu_config_binary_bit), a
    xor a
    ld (menu_config_binary_invert), a
    call menu_config_prepare_binary
    ld a, (menu_config_defined_h)
    and 1
    ld (menu_config_defined_flag), a
    ld hl, 0x5a52
    ld b, 4
    call menu_config_header_span
    ld hl, 0x5a56
    ld b, 2
    call menu_config_paint_left_binary
    ld hl, 0x5a5b
    ld b, 1
    jp menu_config_paint_right_binary

menu_config_paint_action_attrs:
    ld a, (menu_config_visible_h)
    bit 1, a
    ret z
    ld a, (menu_config_cursor)
    cp 9
    ld a, 0x44
    jr nz, menu_config_paint_action_span
    ld a, 0x38
menu_config_paint_action_span:
    ld hl, 0x5a9d
    ld b, 3
    jp menu_config_attr_span

menu_config_option_span:
    ld a, e
    or a
    jr z, menu_config_option_not_focused
    ld a, d
    or a
    ld a, 0x38
    jr z, menu_config_attr_span
    inc a
    jr menu_config_attr_span
menu_config_option_not_focused:
    ld a, d
    or a
    ld a, 0x06
    jr nz, menu_config_attr_span
    ld a, 0x07
menu_config_attr_span:
    ld (hl), a
    inc hl
    djnz menu_config_attr_span
    ret

_menu_config_validate_ip_ovl_entry:
    ld l, 0
    ret

_menu_config_piece_set_options_asm:
    ld c, l
    ld b, 0
    ld hl, 0x5a36
    ld d, 2
    call menu_config_piece_set_option_span
    ld b, 1
    ld hl, 0x5a39
    ld d, 2
    call menu_config_piece_set_option_span
    ld b, 2
    ld hl, 0x5a3c
    ld d, 2
menu_config_piece_set_option_span:
    call menu_config_piece_set_option_attr
menu_config_piece_set_option_store:
    ld (hl), a
    inc hl
    dec d
    jr nz, menu_config_piece_set_option_store
    ret

menu_config_piece_set_option_attr:
    ld a, c
    cp b
    jr z, menu_config_piece_set_option_focus
    ld a, (menu_config_piece_selected)
    cp b
    jr z, menu_config_piece_set_option_selected
    ld a, 0x07
    ret
menu_config_piece_set_option_focus:
    ld a, (menu_config_piece_selected)
    cp b
    ld a, 0x38
    ret nz
    inc a
    ret
menu_config_piece_set_option_selected:
    ld a, 0x06
    ret

; Swatches read the per-platform theme attrs straight from the resident DAT.
; Next replaces only wood with its dedicated ULA+ group-3 colour pair.
menu_config_dat_light_attrs EQU 0x6000 + 786

menu_config_board_swatches:
    ld c, l
    ld hl, 0x5a16
    ld b, 0
    ld de, menu_config_dat_light_attrs
menu_config_board_swatch_loop:
    ld a, (de)
    push de
    call menu_config_board_swatch
    pop de
    inc de
    inc b
    ld a, b
    cp 5
    jr nz, menu_config_board_swatch_loop
    ret
menu_config_board_swatch:
IFDEF NETCHESSZX_NEXT
    cp 0x37
    jr nz, menu_config_board_swatch_attr_ready
    ld a, 0xc1
menu_config_board_swatch_attr_ready:
ENDIF
    ld e, a
    ld a, c
    cp b
    ld a, e
    jr z, menu_config_board_swatch_flash
    ld a, b
    add a, 5
    cp c
    ld a, e
    jr nz, menu_config_board_swatch_store
IFDEF NETCHESSZX_NEXT
    ; Keep the ULA+ palette group selected by the theme attribute.
ELSE
    or 0x40
ENDIF
    jr menu_config_board_swatch_store
menu_config_board_swatch_flash:
    ld a, e
    and 0xc0
    ld d, a
    ld a, e
    and 0x07
    rlca
    rlca
    rlca
    or d
    ld d, a
    ld a, e
    and 0x38
    rrca
    rrca
    rrca
    or d
IFDEF NETCHESSZX_NEXT
    ; Swapping ink/paper is enough to mark focus without changing palette group.
ELSE
    or 0x80
ENDIF
menu_config_board_swatch_store:
    ld (hl), a
    inc hl
    ld (hl), 0x07
    inc hl
    ret

menu_config_line_game:
    DEFB 7, "GAME   CREATE    JOIN", 0
menu_config_line_link:
    DEFB 8, "LINK   MQTT      DIRECT", 0
menu_config_line_mqtt:
    DEFB 10, "MQTT   HIVEMQ:1883", 0
menu_config_line_side:
    DEFB 14, "COLOR  WHITE     BLACK", 0
menu_config_line_notation:
    DEFB 15, "NOTAT  COORD     SAN", 0
menu_config_line_board:
    DEFB 16, "BOARD  ", 127, "   ", 127, "   ", 127, "   ", 127, "   ", 127, 0
menu_config_line_set:
IFDEF NETCHESSZX_NEXT
    ; Next sprite sets: california, mpchess, totoy (lichess), truncated to fit.
    DEFB 17, "SET    CALI  MPCH  TOTY", 0
ELSE
    DEFB 17, "SET    BRRY  SPCY  PIXL", 0
ENDIF
menu_config_line_hints:
    DEFB 18, "HINTS  OFF       ON", 0
menu_config_line_start:
    DEFB 20, "                     START", 0

menu_config_label_room:
    DEFB "ROOM   "
menu_config_label_ip:
    DEFB "IP     "
menu_config_label_port:
    DEFB "PORT   "
menu_config_text_local:
    DEFB "LOCAL", 0
menu_config_edit_row:
    DEFB 0
menu_config_edit_flags:
    DEFB 0
menu_config_edit_max:
    DEFB 0
menu_config_edit_line_buf:
    DEFS 24
menu_config_values:
    DEFB 0
menu_config_visible_l:
    DEFB 0
menu_config_visible_h:
    DEFB 0
menu_config_defined_l:
    DEFB 0
menu_config_defined_h:
    DEFB 0
menu_config_cursor:
    DEFB 0
menu_config_focus_bits:
    DEFB 0
menu_config_board_theme:
    DEFB 0
menu_config_piece_set:
    DEFB 0
menu_config_piece_selected:
    DEFB 0
menu_config_binary_mask:
    DEFB 0
menu_config_binary_row:
    DEFB 0
menu_config_binary_bit:
    DEFB 0
menu_config_binary_invert:
    DEFB 0
menu_config_defined_flag:
    DEFB 0
menu_config_value_flag:
    DEFB 0
menu_config_focus_value:
    DEFB 0
menu_config_row_focus:
    DEFB 0
menu_config_option_width:
    DEFB 0
menu_config_render_dirty:
    DEFW 0
menu_config_render_edit:
    DEFB 0
menu_config_blank_line:
    DEFB 0
    DEFM "              "
    DEFB 0
