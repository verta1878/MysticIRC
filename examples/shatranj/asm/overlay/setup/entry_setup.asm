SECTION code_user

PUBLIC _setup_step_ovl_entry

EXTERN _setup_choice
EXTERN _setup_focus_choice
EXTERN _setup_focus_board_theme
EXTERN _setup_defined_mask
EXTERN _setup_visible_mask
EXTERN _setup_cursor
EXTERN _setup_room_editing
EXTERN _setup_edit_row
EXTERN _setup_port_text
EXTERN _netchesszx_mqtt_code
EXTERN _netchesszx_direct_host
EXTERN _netchesszx_direct_port

CTX             EQU 0x5FE0
CTX_KEY         EQU CTX + 0
CTX_FORCE_LO    EQU CTX + 1
CTX_FORCE_HI    EQU CTX + 2
CTX_CLEAR_FROM  EQU CTX + 3
CTX_ACTION      EQU CTX + 4
CTX_NOTICE      EQU CTX + 5
CTX_FLAGS       EQU CTX + 6

KEY_UP          EQU 0x81
KEY_DOWN        EQU 0x82
KEY_LEFT        EQU 0x83
KEY_RIGHT       EQU 0x84
KEY_CANCEL      EQU 0x8a
SETUP_CLEAR_NONE EQU 0xff

FLAG_RENDER     EQU 0x01
FLAG_PAINT      EQU 0x02
FLAG_EDIT       EQU 0x04
FLAG_SUPPRESS   EQU 0x08
ACTION_BOARD    EQU 1
ACTION_SET      EQU 2
ACTION_START    EQU 3
NOTICE_SELECT   EQU 1
NOTICE_PENDING  EQU 2
NOTICE_BAD_IP   EQU 3

    DEFB 2
    DW _setup_step_ovl_entry
    DW _setup_compute_visible_ovl_entry

_setup_compute_visible_ovl_entry:
    push de
    ld h, d
    ld l, e
    ld c, (hl)
    inc hl
    ld b, (hl)
    call su_compute_visible
    pop de
    ld a, l
    ld (de), a
    inc de
    ld a, h
    ld (de), a
    ret

_setup_step_ovl_entry:
    call su_clear_ctx
    ld a, (CTX_KEY)
    ld (su_key), a
    ld a, (_setup_room_editing)
    or a
    jp nz, su_edit_key
    ld a, (su_key)
    cp KEY_UP
    jr z, su_nav_prev
    cp 'q'
    jr z, su_nav_prev
    cp KEY_DOWN
    jr z, su_nav_next
    cp 'a'
    jr z, su_nav_next
    cp KEY_LEFT
    jr z, su_focus
    cp KEY_RIGHT
    jr z, su_focus
    cp 'o'
    jr z, su_focus
    cp 'p'
    jr z, su_focus
    cp 32
    jp z, su_select
    cp 13
    jp z, su_select
    jr su_ret1

; A = flag bits; ORs into CTX_FLAGS then falls through to return 1.
su_or_flags:
    ld hl, CTX_FLAGS
    or (hl)
    ld (hl), a
su_ret1:
    ld l, 1
    ret

su_clear_ctx:
    xor a
    ld (CTX_FORCE_LO), a
    ld (CTX_FORCE_HI), a
    ld (CTX_ACTION), a
    ld (CTX_NOTICE), a
    ld (CTX_FLAGS), a
    dec a
    ld (CTX_CLEAR_FROM), a
    ret

su_nav_prev:
    xor a
    jr su_nav_go
su_nav_next:
    ld a, 1
su_nav_go:
    call su_step_row
    ld (_setup_cursor), a
    ld a, FLAG_PAINT
    jp su_or_flags

su_focus:
    ld a, (_setup_cursor)
    or a
    jr z, su_focus_0
    cp 1
    jr z, su_focus_1
    cp 4
    jr z, su_focus_2
    cp 5
    jr z, su_focus_3
    cp 6
    jr z, su_focus_board
    cp 7
    jr z, su_focus_set
    cp 8
    jr z, su_focus_4
    jp su_ret1
su_focus_0:
    ld hl, _setup_focus_choice
    jr su_focus_toggle
su_focus_1:
    ld hl, _setup_focus_choice + 1
    jr su_focus_toggle
su_focus_2:
    ld hl, _setup_focus_choice + 2
    jr su_focus_toggle
su_focus_3:
    ld hl, _setup_focus_choice + 3
    jr su_focus_toggle
su_focus_4:
    ld hl, _setup_focus_choice + 4
su_focus_toggle:
    ld a, (hl)
    xor 1
    ld (hl), a
    jr su_focus_paint
su_focus_board:
    ld hl, _setup_focus_board_theme
    ld b, 5
    call su_cycle_choice
    jr su_focus_paint
su_focus_set:
    ld hl, _setup_focus_choice + 5
    ld b, 3
    call su_cycle_choice
su_focus_paint:
    ld a, FLAG_PAINT
    jp su_or_flags

su_cycle_choice:
    ld a, (su_key)
    cp KEY_LEFT
    jr z, su_cycle_left
    cp 'o'
    jr z, su_cycle_left
    ld a, (hl)
    inc a
    cp b
    jr c, su_cycle_store
    xor a
    jr su_cycle_store
su_cycle_left:
    ld a, (hl)
    dec a
    cp b
    jr c, su_cycle_store
    ld a, b
    dec a
su_cycle_store:
    ld (hl), a
    ret

su_select:
    ld hl, (_setup_visible_mask)
    ld (su_old_visible), hl
    ld a, SETUP_CLEAR_NONE
    ld (su_clear_from), a
    ld a, (_setup_cursor)
    or a
    jp z, su_select_game
    cp 1
    jp z, su_select_link
    cp 2
    jp z, su_select_endpoint
    cp 3
    jp z, su_select_endpoint
    cp 4
    jr z, su_select_side
    cp 5
    jr z, su_select_notation
    cp 6
    jr z, su_select_board
    cp 7
    jr z, su_select_set
    cp 8
    jr z, su_select_hints
    cp 9
    jp z, su_select_action
    jp su_ret1

su_select_side:
    ld a, (_setup_focus_choice + 2)
    ld (_setup_choice + 2), a
    ld a, 4
su_define_row_and_finish:
    call su_set_defined_row
    jp su_after_select

su_select_notation:
    ld a, (_setup_focus_choice + 3)
    ld (_setup_choice + 3), a
    ld a, 5
    jp su_define_row_and_finish

su_select_board:
    ld a, 6
    call su_set_defined_row
    ld a, ACTION_BOARD
    ld (CTX_ACTION), a
    jp su_after_select

su_select_set:
    ld a, ACTION_SET
    ld (CTX_ACTION), a
    jp su_ret1

su_select_hints:
    ld a, (_setup_focus_choice + 4)
    ld (_setup_choice + 4), a
    ld a, 8
    jp su_define_row_and_finish

su_select_endpoint:
    call su_room_editable
    jr z, su_endpoint_define
    call su_begin_room_edit
    ld a, FLAG_SUPPRESS
    jp su_or_flags
su_endpoint_define:
    ld a, (_setup_cursor)
    jp su_define_row_and_finish

su_select_action:
    call su_can_start
    jp z, su_ret1
    ld a, ACTION_START
    ld (CTX_ACTION), a
    ld a, FLAG_SUPPRESS
    jp su_or_flags

su_select_game:
    ld hl, (_setup_defined_mask)
    bit 0, l
    ld c, 0
    jr nz, su_game_had
    ld c, 1
su_game_had:
    ld a, (_setup_choice)
    ld b, a
    ld a, (_setup_focus_choice)
    cp b
    ld b, 0
    jr z, su_game_same
    ld b, 1
su_game_same:
    ld (_setup_choice), a
    ld hl, _setup_defined_mask
    set 0, (hl)
    ld a, b
    or c
    call nz, su_update_room
    ld a, b
    or a
    jp z, su_after_select
    ld hl, _setup_defined_mask
    ld a, (hl)
    and 1
    ld (hl), a
    inc hl
    ld (hl), 0
    ld a, 1
    ld (su_clear_from), a
    jp su_after_select

su_select_link:
    ld hl, (_setup_defined_mask)
    bit 1, l
    ld c, 0
    jr nz, su_link_had
    ld c, 1
su_link_had:
    ld a, (_setup_choice + 1)
    ld b, a
    ld a, (_setup_focus_choice + 1)
    cp b
    ld b, 0
    jr z, su_link_same
    ld b, 1
su_link_same:
    ld (_setup_choice + 1), a
    ld hl, _setup_defined_mask
    set 1, (hl)
    ld a, b
    or c
    call nz, su_update_room
    ld a, b
    or a
    jr z, su_link_auto_room
    ld hl, _setup_defined_mask
    ld a, (hl)
    and 3
    ld (hl), a
    inc hl
    ld (hl), 0
    ld a, 2
    ld (su_clear_from), a
su_link_auto_room:
    ld hl, (_setup_choice)
    ld a, h
    or l
    jp nz, su_after_select
    ld a, 2
    ld (su_clear_from), a
    jp su_define_row_and_finish

su_after_select:
    ld bc, (_setup_defined_mask)
    call su_compute_visible
    ld (su_new_visible), hl
    ld a, SETUP_CLEAR_NONE
    ld (su_next_cursor), a
    ld a, (su_clear_from)
    cp 2
    jr nz, su_as_clear_visible
    ld hl, (_setup_choice)
    ld a, l
    or a
    jr nz, su_as_clear_visible
    or h
    jr z, su_as_host_direct
    ld a, 2
    call su_set_defined_row
    ld a, 3
    call su_set_defined_row
    ld a, 4
    ld (su_next_cursor), a
    jr su_as_next_done
su_as_host_direct:
    ld hl, (su_new_visible)
    bit 3, l
    jr z, su_as_clear_visible
    ld a, 3
    ld (su_next_cursor), a
    jr su_as_next_done
su_as_clear_visible:
    ld a, (su_clear_from)
    cp SETUP_CLEAR_NONE
    jr z, su_as_first_new
    push af
    call su_row_bit_bc
    ld hl, (su_new_visible)
    ld a, l
    and c
    jr nz, su_as_use_clear_pop
    ld a, h
    and b
    jr nz, su_as_use_clear_pop
    pop af
    jr su_as_first_new
su_as_use_clear_pop:
    pop af
    ld (su_next_cursor), a
    jr su_as_next_done
su_as_first_new:
    ld hl, (su_new_visible)
    ld de, (su_old_visible)
    ld a, e
    cpl
    and l
    ld l, a
    ld a, d
    cpl
    and h
    ld h, a
    call su_first_row
    cp SETUP_CLEAR_NONE
    jr nz, su_as_store_next
    ld a, 1
    call su_step_row
su_as_store_next:
    ld (su_next_cursor), a
su_as_next_done:
    ld a, (su_next_cursor)
    cp SETUP_CLEAR_NONE
    jr z, su_as_no_cursor
    ld (_setup_cursor), a
su_as_no_cursor:
    ld a, (_setup_cursor)
    cp 2
    jr z, su_as_try_edit
    cp 3
    jr nz, su_as_flags
su_as_try_edit:
    call su_room_editable
    call nz, su_begin_room_edit
su_as_flags:
    ld a, (su_clear_from)
    call su_write_force_from_row
    ld a, (su_clear_from)
    ld (CTX_CLEAR_FROM), a
    ld a, FLAG_RENDER | FLAG_SUPPRESS
    jp su_or_flags

su_edit_key:
    ld a, (su_key)
    cp KEY_CANCEL
    jp z, su_edit_cancel
    cp 8
    jr z, su_edit_backspace
    cp 13
    jp z, su_edit_confirm
    cp 32
    jp z, su_edit_confirm
    call su_room_append
    jp z, su_ret1
    ld a, FLAG_EDIT
    jp su_or_flags

su_edit_backspace:
    call su_room_backspace
    jp z, su_ret1
    ld a, FLAG_EDIT
    jp su_or_flags

su_edit_cancel:
    xor a
    ld (_setup_room_editing), a
    ld a, (_netchesszx_mqtt_code)
    or a
    jr nz, su_ec_port
    ld a, (_setup_choice)
    or a
    call z, su_default_room
su_ec_port:
    ld a, (_setup_choice + 1)
    or a
    jr nz, su_ec_done_port
    ld a, (_setup_edit_row)
    cp 3
    call z, su_write_port_text
su_ec_done_port:
    ld a, NOTICE_SELECT
    ld (CTX_NOTICE), a
    ld a, FLAG_EDIT | FLAG_SUPPRESS
    jp su_or_flags

su_edit_confirm:
    call su_endpoint_text
    ld a, (hl)
    or a
    jp z, su_ret1
    ld a, (_setup_choice + 1)
    or a
    jr nz, su_ec_not_direct
    ld a, (_setup_choice)
    cp 1
    jr nz, su_ec_check_port
    ld a, (_setup_edit_row)
    cp 2
    jr nz, su_ec_check_port
    call su_validate_ip
    jr nz, su_ec_not_direct
    ld a, NOTICE_BAD_IP
    ld (CTX_NOTICE), a
    jp su_ret1
su_ec_check_port:
    ld a, (_setup_edit_row)
    cp 3
    jr nz, su_ec_not_direct
    call su_parse_port
    jp z, su_ret1
su_ec_not_direct:
    xor a
    ld (_setup_room_editing), a
    ld a, (_setup_edit_row)
    call su_set_defined_row
    ld a, (_setup_edit_row)
    cp 2
    jr nz, su_ec_after_port
    ld a, 3
    jr su_ec_store_cursor
su_ec_after_port:
    ld bc, (_setup_defined_mask)
    call su_compute_visible
    bit 4, l
    ld a, 4
    jr nz, su_ec_store_cursor
    ld a, 5
su_ec_store_cursor:
    ld (_setup_cursor), a
    ld a, (_setup_edit_row)
    call su_write_row_bit_to_force
    ld a, SETUP_CLEAR_NONE
    ld (CTX_CLEAR_FROM), a
    ld a, NOTICE_SELECT
    ld (CTX_NOTICE), a
    ld a, FLAG_RENDER | FLAG_SUPPRESS
    jp su_or_flags

su_update_room:
    ld hl, (_setup_choice)
    ld a, h
    or a
    ret z
    ld a, l
    or a
    jr z, su_ur_generate
    ld hl, _netchesszx_mqtt_code
    ld (hl), 0
    ret
su_ur_generate:
    ld de, _netchesszx_mqtt_code
    ld a, 'N'
    ld (de), a
    inc de
    ld a, 'C'
    ld (de), a
    inc de
    ld hl, (0x5c78)
    ld a, h
    or l
    jr nz, su_ur_seed_done
    ld hl, 0x5a3c
su_ur_seed_done:
    ld a, h
    rrca
    rrca
    rrca
    rrca
    call su_ur_store_hex
    ld a, h
    call su_ur_store_hex
    ld a, l
    rrca
    rrca
    rrca
    rrca
    call su_ur_store_hex
    ld a, l
    call su_ur_store_hex
    xor a
    ld (de), a
    ret
su_ur_store_hex:
    call su_hex
    ld (de), a
    inc de
    ret
su_hex:
    and 0x0f
    cp 10
    jr nc, su_hex_alpha
    add a, '0'
    ret
su_hex_alpha:
    add a, 'A' - 10
    ret

su_default_room:
    ld hl, su_default_room_text
    ld de, _netchesszx_mqtt_code
su_dr_loop:
    ld a, (hl)
    ld (de), a
    inc hl
    inc de
    or a
    jr nz, su_dr_loop
    ret

su_begin_room_edit:
    ld a, (_setup_cursor)
    ld (_setup_edit_row), a
    ld a, (_setup_choice + 1)
    or a
    jr z, su_bre_set
    ld hl, _netchesszx_mqtt_code
    ld a, (hl)
    cp 'D'
    jr nz, su_bre_set
    inc hl
    ld a, (hl)
    cp 'E'
    jr nz, su_bre_set
    inc hl
    ld a, (hl)
    cp 'V'
    jr nz, su_bre_set
    ld hl, _netchesszx_mqtt_code
    ld (hl), 0
su_bre_set:
    ld a, 1
    ld (_setup_room_editing), a
    ld a, FLAG_EDIT
    jp su_or_flags

su_room_editable:
    ld a, (_setup_cursor)
    sub 2
    jr nz, su_re_port
    ld hl, (_setup_choice)
    ld a, h
    or l
    ret
su_re_port:
    dec a
    jr nz, su_re_false
    ld a, (_setup_choice + 1)
    or a
    jr z, su_re_true
su_re_false:
    xor a
    ret
su_re_true:
    inc a
    ret

su_endpoint_text:
    ld a, (_setup_choice + 1)
    or a
    jr z, su_et_direct
    ld hl, _netchesszx_mqtt_code
    ret
su_et_direct:
    ld a, (_setup_edit_row)
    cp 2
    jr nz, su_et_port
    ld hl, _netchesszx_direct_host
    ret
su_et_port:
    ld hl, _setup_port_text
    ret

su_endpoint_max:
    ld a, (_setup_choice + 1)
    or a
    jr z, su_em_direct
    ld a, 6
    ret
su_em_direct:
    ld a, (_setup_edit_row)
    cp 2
    jr nz, su_em_port
    ld a, 15
    ret
su_em_port:
    ld a, 5
    ret

su_room_append:
    ld a, (su_key)
    call su_room_char
    or a
    ret z
    ld (su_ch), a
    call su_endpoint_text
    ld b, 0
su_ra_len:
    ld a, (hl)
    or a
    jr z, su_ra_len_done
    inc hl
    inc b
    jr su_ra_len
su_ra_len_done:
    call su_endpoint_max
    ld c, a
    ld a, b
    cp c
    ret nc
    ld a, (su_ch)
    ld (hl), a
    inc hl
    ld (hl), 0
    or 1
    ret

su_room_char:
    cp '0'
    jr c, su_rc_not_digit
    cp '9' + 1
    ret c
su_rc_not_digit:
    ld c, a
    ld a, (_setup_choice + 1)
    or a
    jr nz, su_rc_mqtt
    ld a, (_setup_edit_row)
    cp 2
    jr nz, su_rc_bad
    ld a, c
    cp '.'
    jr z, su_rc_dot
    cp ','
    jr z, su_rc_dot
    cp ';'
    jr z, su_rc_dot
    cp ':'
    jr z, su_rc_dot
su_rc_bad:
    xor a
    ret
su_rc_dot:
    ld a, '.'
    ret
su_rc_mqtt:
    ld a, c
    and 0xdf
    cp 'A'
    jr c, su_rc_bad
    cp 'Z' + 1
    jr nc, su_rc_bad
    ret

su_room_backspace:
    call su_endpoint_text
    ld b, 0
su_rb_len:
    ld a, (hl)
    or a
    jr z, su_rb_done
    inc hl
    inc b
    jr su_rb_len
su_rb_done:
    ld a, b
    or a
    ret z
    dec hl
    ld (hl), 0
    or 1
    ret

su_compute_visible:
    ld de, 1
    bit 0, c
    jr z, su_cv_done
    set 1, e
    bit 1, c
    jr z, su_cv_done
    ld hl, (_setup_choice)
    ld a, h
    or l
    jr nz, su_cv_link_room_only
    set 2, e
    set 3, e
    jr su_cv_after_link
su_cv_link_room_only:
    set 2, e
su_cv_after_link:
    bit 2, c
    jr z, su_cv_after_room
    set 3, e
su_cv_after_room:
    bit 3, c
    jr z, su_cv_after_mqtt
    ld a, (_setup_choice)
    or a
    jr z, su_cv_host_side
    set 5, e
    jr su_cv_after_mqtt
su_cv_host_side:
    set 4, e
    bit 4, c
    jr z, su_cv_after_mqtt
    set 5, e
su_cv_after_mqtt:
    bit 5, c
    jr z, su_cv_after_notation
    set 6, e
su_cv_after_notation:
    bit 6, c
    jr z, su_cv_after_board
    set 7, e
su_cv_after_board:
    bit 7, c
    jr z, su_cv_after_set
    set 0, d
su_cv_after_set:
    bit 0, b
    jr z, su_cv_done
    ld hl, (_setup_choice)
    ld a, l
    or a
    jr nz, su_cv_join_ready
    or h
    jr z, su_cv_host_direct_ready
    ld a, c
    cp 0xff
    jr z, su_cv_action
    jr su_cv_done
su_cv_host_direct_ready:
    ld a, c
    and 0xfb
    cp 0xfb
    jr z, su_cv_action
    jr su_cv_done
su_cv_join_ready:
    ld a, c
    and 0xef
    cp 0xef
    jr nz, su_cv_done
    ld a, (_setup_choice + 1)
    or a
    jr nz, su_cv_action
    ld a, (_netchesszx_direct_host)
    or a
    jr z, su_cv_done
su_cv_action:
    set 1, d
su_cv_done:
    ld h, d
    ld l, e
    ret

su_step_row:
    or a
    jr z, su_step_prev
    ld a, (_setup_cursor)
    inc a
su_step_next_loop:
    cp 10
    jr nc, su_step_restore
    push af
    call su_visible_a
    jr nz, su_step_found
    pop af
    inc a
    jr su_step_next_loop
su_step_prev:
    ld a, (_setup_cursor)
    or a
    jr z, su_step_restore
    dec a
su_step_prev_loop:
    push af
    call su_visible_a
    jr nz, su_step_found
    pop af
    or a
    jr z, su_step_restore
    dec a
    jr su_step_prev_loop
su_step_found:
    pop af
    ret
su_step_restore:
    ld a, (_setup_cursor)
    ret

su_visible_a:
    ld e, a
    ld d, 0
    cp 2
    jr nz, su_va_mask
    ld hl, (_setup_choice)
    ld a, h
    or l
    ret z
su_va_mask:
    ld hl, su_masks_lo
    add hl, de
    ld a, (_setup_visible_mask)
    and (hl)
    ret nz
    ld hl, su_masks_hi
    add hl, de
    ld a, (_setup_visible_mask + 1)
    and (hl)
    ret

su_first_row:
    ld (su_scan_mask), hl
    xor a
su_fr_loop:
    cp 10
    jr nc, su_fr_none
    push af
    call su_scan_mask_has_a
    jr nz, su_fr_found
    pop af
    inc a
    jr su_fr_loop
su_fr_found:
    pop af
    ret
su_fr_none:
    ld a, SETUP_CLEAR_NONE
    ret

su_scan_mask_has_a:
    ld e, a
    ld d, 0
    ld hl, su_masks_lo
    add hl, de
    ld a, (su_scan_mask)
    and (hl)
    ret nz
    ld hl, su_masks_hi
    add hl, de
    ld a, (su_scan_mask + 1)
    and (hl)
    ret

su_row_bit_bc:
    ld e, a
    ld d, 0
    ld hl, su_masks_lo
    add hl, de
    ld c, (hl)
    ld hl, su_masks_hi
    add hl, de
    ld b, (hl)
    ret

su_set_defined_row:
    call su_row_bit_bc
    ld hl, _setup_defined_mask
    ld a, (hl)
    or c
    ld (hl), a
    inc hl
    ld a, (hl)
    or b
    ld (hl), a
    ret

su_write_force_from_row:
    cp SETUP_CLEAR_NONE
    jr nz, su_wff_row
    xor a
    ld (CTX_FORCE_LO), a
    ld (CTX_FORCE_HI), a
    ret
su_wff_row:
    dec a
    add a, a
    cpl
    dec a
    ld (CTX_FORCE_LO), a
    ld a, 3
    ld (CTX_FORCE_HI), a
    ret

su_write_row_bit_to_force:
    call su_row_bit_bc
    ld a, c
    ld (CTX_FORCE_LO), a
    ld a, b
    ld (CTX_FORCE_HI), a
    ret

su_can_start:
    ld hl, (_setup_choice)
    ld a, l
    or a
    jr nz, su_cs_join
    or h
    jr z, su_cs_host_direct
    ld bc, 0x017f
    jr su_cs_check
su_cs_host_direct:
    ld bc, 0x017b
    jr su_cs_check
su_cs_join:
    ld bc, 0x016f
su_cs_check:
    ld hl, (_setup_defined_mask)
    ld a, l
    and c
    cp c
    jr nz, su_cs_pending
    ld a, h
    and b
    cp b
    jr nz, su_cs_pending
    or 1
    ret
su_cs_pending:
    ld a, NOTICE_PENDING
    ld (CTX_NOTICE), a
    xor a
    ret

su_validate_ip:
    ld hl, _netchesszx_direct_host
    ld b, 0
su_ip_segment:
    ld c, 0
    ld e, 0
su_ip_digit_loop:
    ld a, (hl)
    cp '0'
    jr c, su_ip_end_digits
    cp '9' + 1
    jr nc, su_ip_end_digits
    sub '0'
    ld (su_digit), a
    inc c
    ld a, c
    cp 4
    jr nc, su_ip_fail
    ld a, e
    add a, a
    jr c, su_ip_fail
    ld d, a
    add a, a
    jr c, su_ip_fail
    add a, a
    jr c, su_ip_fail
    add a, d
    jr c, su_ip_fail
    ld d, a
    ld a, (su_digit)
    add a, d
    jr c, su_ip_fail
    ld e, a
    inc hl
    jr su_ip_digit_loop
su_ip_end_digits:
    ld a, c
    or a
    jr z, su_ip_fail
    ld a, (hl)
    or a
    jr z, su_ip_end
    cp '.'
    jr nz, su_ip_fail
    ld a, b
    cp 3
    jr nc, su_ip_fail
    inc b
    inc hl
    jr su_ip_segment
su_ip_end:
    ld a, b
    cp 3
    jr nz, su_ip_fail
    inc a
    ret
su_ip_fail:
    xor a
    ret

su_parse_port:
    ld hl, _setup_port_text
    ld de, 0
su_pp_loop:
    ld a, (hl)
    or a
    jr z, su_pp_done
    cp '0'
    jr c, su_pp_fail
    cp '9' + 1
    jr nc, su_pp_fail
    sub '0'
    ld c, a
    push hl
    ld h, d
    ld l, e
    add hl, hl
    push hl
    add hl, hl
    add hl, hl
    pop de
    add hl, de
    ld e, c
    ld d, 0
    add hl, de
    ex de, hl
    pop hl
    inc hl
    jr su_pp_loop
su_pp_done:
    ld (_netchesszx_direct_port), de
    ld a, d
    or e
    ret nz
su_pp_fail:
    xor a
    ret

su_write_port_text:
    ld hl, (_netchesszx_direct_port)
    ld (su_value), hl
    ld de, _setup_port_text
    ld hl, su_divs
    ld a, 5
    ld (su_count), a
    xor a
    ld (su_seen), a
su_wpt_div:
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ld (su_div_ptr), hl
    ld a, '0'
    ld (su_digit), a
su_wpt_sub:
    ld hl, (su_value)
    or a
    sbc hl, bc
    jr c, su_wpt_emit
    ld (su_value), hl
    ld a, (su_digit)
    inc a
    ld (su_digit), a
    jr su_wpt_sub
su_wpt_emit:
    ld a, (su_digit)
    cp '0'
    jr nz, su_wpt_store
    ld a, (su_seen)
    or a
    jr nz, su_wpt_store
    ld a, b
    or a
    jr nz, su_wpt_next
    ld a, c
    cp 1
    jr nz, su_wpt_next
su_wpt_store:
    ld a, (su_digit)
    ld (de), a
    inc de
    ld a, 1
    ld (su_seen), a
su_wpt_next:
    ld hl, (su_div_ptr)
    ld a, (su_count)
    dec a
    ld (su_count), a
    jr nz, su_wpt_div
    xor a
    ld (de), a
    ret

su_key: DEFB 0
su_ch: DEFB 0
su_clear_from: DEFB 0
su_next_cursor: DEFB 0
su_digit: DEFB 0
su_count: DEFB 0
su_seen: DEFB 0
su_old_visible: DEFW 0
su_new_visible: DEFW 0
su_scan_mask: DEFW 0
su_value: DEFW 0
su_div_ptr: DEFW 0
su_default_room_text: DEFB 'D','E','V','R','O','O','M',0
su_masks_lo: DEFB 1,2,4,8,16,32,64,128,0,0
su_masks_hi: DEFB 0,0,0,0,0,0,0,0,1,2
su_divs: DEFW 10000,1000,100,10,1
