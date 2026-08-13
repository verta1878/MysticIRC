SECTION code_user

PUBLIC _input_edit_render_ovl_entry
PUBLIC _input_edit_begin_empty_ovl_entry
PUBLIC _input_edit_stop_clear_ovl_entry
PUBLIC _input_edit_key_ovl_entry
PUBLIC _input_edit_history_add_ovl_entry

EXTERN _input_edit_render_ovl
EXTERN _input_edit_begin_empty_ovl
EXTERN _input_edit_stop_clear_ovl
EXTERN _input_edit_key_ovl
EXTERN _input_edit_history_add_ovl

    DEFB 6
    DW _input_edit_render_ovl_entry
    DW _input_edit_begin_empty_ovl_entry
    DW _input_edit_stop_clear_ovl_entry
    DW _input_edit_key_ovl_entry
    DW _input_edit_history_add_ovl_entry
    DW input_edit_parse_move_ovl_entry

DEFC _input_edit_render_ovl_entry = _input_edit_render_ovl

DEFC _input_edit_begin_empty_ovl_entry = _input_edit_begin_empty_ovl

DEFC _input_edit_stop_clear_ovl_entry = _input_edit_stop_clear_ovl

DEFC _input_edit_key_ovl_entry = _input_edit_key_ovl

DEFC _input_edit_history_add_ovl_entry = _input_edit_history_add_ovl

input_edit_parse_move_ovl_entry:
    ld l, (de)
    inc de
    ld h, (de)
    inc de
    ld a, (de)
    inc de
    ld c, a
    ld b, (de)

app_input_skip_leading:
    ld a, (hl)
    cp ' '
    jr nz, app_input_first_square
    inc hl
    jr app_input_skip_leading

app_input_first_square:
    call app_input_parse_square
    jr c, app_input_fail
    ld a, (hl)
    cp '-'
    jr z, app_input_skip_separator
    cp ' '
    jr nz, app_input_second_square

app_input_skip_separator:
    inc hl

app_input_second_square:
    call app_input_parse_square
    jr c, app_input_fail
    xor a
    ld (bc), a
    ld a, (hl)
    or 0x20
    cp 'q'
    jr z, app_input_store_promo
    cp 'r'
    jr z, app_input_store_promo
    cp 'b'
    jr z, app_input_store_promo
    cp 'n'
    jr nz, app_input_skip_trailing

app_input_store_promo:
    ld (bc), a
    inc bc
    xor a
    ld (bc), a
    inc hl

app_input_skip_trailing:
    ld a, (hl)
    cp ' '
    jr nz, app_input_end_check
    inc hl
    jr app_input_skip_trailing

app_input_end_check:
    or a
    jr nz, app_input_fail
    ld l, 1
    ret

app_input_fail:
    ld l, 0
    ret

app_input_parse_square:
    ld a, (hl)
    or 0x20
    cp 'a'
    jr c, app_input_square_fail
    cp 'i'
    jr nc, app_input_square_fail

app_input_file_ok:
    ld (bc), a
    inc hl
    inc bc
    ld a, (hl)
    cp '1'
    jr c, app_input_square_fail
    cp '9'
    jr nc, app_input_square_fail
    ld (bc), a
    inc hl
    inc bc
    or a
    ret

app_input_square_fail:
    scf
    ret
