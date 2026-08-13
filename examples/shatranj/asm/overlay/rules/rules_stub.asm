SECTION code_user

PUBLIC _rules_hints_ovl
PUBLIC _rules_hints_clear_ovl
EXTERN _spectrum_board_view_redraw_square
EXTERN _netchesszx_board_theme_index
EXTERN _netchesszx_hinted_rows
EXTERN _spectrum_board_view_flipped
EXTERN board_theme_hint_inks
EXTERN compute_square_bc
EXTERN compute_attr_base
EXTERN set_square_attr_2x2
EXTERN compute_screen_base
EXTERN board_row
EXTERN board_col
EXTERN tmp_attr
PUBLIC _rules_play_ovl
PUBLIC _rules_check_ovl

RULE_EMPTY  EQU 0
RULE_WHITE  EQU 0
RULE_BLACK  EQU 1
RULE_PAWN   EQU 1
RULE_KNIGHT EQU 2
RULE_BISHOP EQU 3
RULE_ROOK   EQU 4
RULE_QUEEN  EQU 5
RULE_KING   EQU 6
RULE_WP     EQU 1
RULE_WN     EQU 2
RULE_WB     EQU 3
RULE_WR     EQU 4
RULE_WQ     EQU 5
RULE_WK     EQU 6
RULE_BP     EQU 255
RULE_BN     EQU 254
RULE_BB     EQU 253
RULE_BR     EQU 252
RULE_BQ     EQU 251
RULE_BK     EQU 250
CASTLE_WK   EQU 1
CASTLE_WQ   EQU 2
CASTLE_BK   EQU 4
CASTLE_BQ   EQU 8

; rules_attack_* uses IX/IY as scratch. Overlay loader enters under DI; this
; stub must restore both registers before returning and must not call EI paths
; while IY is borrowed.

rules_import_board:
    ld h, d
    ld l, e
    ld e, (hl)
    inc hl
    ld d, (hl)
    ld (r_board), de
    ld (r_active), de
    inc hl
    ret

_rules_hints_ovl:
    push ix
    push iy
    call rules_import_board
    ld de, r_side
    ldi
    ldi
    inc de
    ldi
    ldi
    ld a, (_netchesszx_board_theme_index)
    ld hl, board_theme_hint_inks
    ld e, a
    ld d, 0
    add hl, de
    ld a, (hl)
    ld (r_hint_ink), a
    xor a
rh_loop:
    ld (r_to), a
    push af
    call rules_current_legal
    or a
    call nz, rh_draw_to
    pop af
    inc a
    cp 64
    jr nz, rh_loop
    ld l, 1
    pop iy
    pop ix
    ret

rh_draw_to:
    ld a, (r_to)
    ld c, a
    rrca
    rrca
    rrca
    and 7
    ld b, a
    ld a, c
    and 7
    ld c, a
    ld hl, _netchesszx_hinted_rows
    ld e, b
    ld d, 0
    add hl, de
    ld d, c
    inc d
    scf
    ld a, 0
rh_rot_loop:
    rla
    dec d
    jr nz, rh_rot_loop
    or (hl)
    ld (hl), a
    ld a, (_spectrum_board_view_flipped)
    or a
    jr z, rh_store_spec
    ld a, 7
    sub b
    ld b, a
    ld a, 7
    sub c
    ld c, a
rh_store_spec:
    ld hl, r_tmp
    ld (hl), b
    inc hl
    ld (hl), c
    inc hl
    ld a, (r_hint_ink)
    ld d, a
    ld a, (r_dst)
    or a
    ld a, d
    jr z, rh_store_hint_mode
    or 0x80
rh_store_hint_mode:
    ld (hl), a
    dec hl
    dec hl
    jp draw_square_hint

_rules_hints_clear_ovl:
    ld hl, _netchesszx_hinted_rows
    ld d, 0
rhc_row_loop:
    ld c, (hl)
    ld (hl), 0
    ld a, c
    or a
    jr z, rhc_next_row
    ld e, 0
rhc_col_loop:
    srl c
    jr nc, rhc_skip_square
    push hl
    push de
    push bc
    ld l, d
    ld h, e
    push hl
    call _spectrum_board_view_redraw_square
    pop bc
    pop bc
    pop de
    pop hl
rhc_skip_square:
    inc e
    ld a, c
    or a
    jr nz, rhc_col_loop
rhc_next_row:
    inc hl
    inc d
    ld a, d
    cp 8
    jr nz, rhc_row_loop
    ld l, 1
    ret

draw_square_hint:
    ld a, (hl)
    ld (board_row), a
    inc hl
    ld a, (hl)
    ld (board_col), a
    inc hl
    ld a, (hl)
    ld (tmp_attr), a

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
draw_dot_row:
    ld a, (hl)
    or e
    ld (hl), a
    inc l
    ld a, (hl)
    or d
    ld (hl), a
    ret


_rules_play_ovl:
    push ix
    push iy
    call rules_import_board
    ld de, r_side
    ld bc, 5
    ldir

    call rules_current_legal
    ld l, a
    pop iy
    pop ix
    ret

_rules_check_ovl:
    push ix
    push iy
    call rules_import_board
    ld de, r_side
    ld bc, 5
    ldir
    ld hl, (r_board)
    ld de, r_tmp
    ld bc, 64
    ldir
    ld hl, r_tmp
    ld (r_active), hl
    call rules_find_king
    cp 255
    jr z, rules_check_none
    ld c, a
    ld a, (r_side)
    xor 1
    ld b, a
    ld a, c
    call rules_attacked_by
    ld (r_in_check), a
    ld d, 0
rules_check_from_loop:
    ld a, d
    ld (r_from), a
    ; Skip empty/enemy from-squares. Read r_board directly: r_active may
    ; still point at r_tmp from the previous rules_current_legal call.
    ld hl, (r_board)
    add a, l
    ld l, a
    jr nc, rules_check_from_ok
    inc h
rules_check_from_ok:
    ld a, (hl)
    or a
    jr z, rules_check_next_from
    call rules_piece_side
    ld hl, r_side
    cp (hl)
    jr nz, rules_check_next_from
    ld e, 0
rules_check_to_loop:
    ld a, e
    ld (r_to), a
    push de
    call rules_current_legal
    pop de
    or a
    jr nz, rules_check_found_escape
    inc e
    ld a, e
    cp 64
    jr nz, rules_check_to_loop
rules_check_next_from:
    inc d
    ld a, d
    cp 64
    jr nz, rules_check_from_loop
    ld a, (r_in_check)
    or a
    jr z, rules_check_stalemate
    ld l, 2
    jr rules_check_done
rules_check_stalemate:
    ld l, 3
rules_check_done:
    pop iy
    pop ix
    ret
rules_check_found_escape:
    ld a, (r_in_check)
    or a
    jr z, rules_check_none
    ld l, 1
    jr rules_check_done
rules_check_none:
    ld l, 0
    jr rules_check_done

rules_current_legal:
    call rules_pseudo
    or a
    jr z, rcl_illegal
    call rules_make_tmp
    call rules_find_king
    cp 255
    jr z, rcl_illegal
    ld c, a
    ld hl, r_tmp
    ld (r_active), hl
    ld a, (r_side)
    xor 1
    ld b, a
    ld a, c
    call rules_attacked_by
    or a
    jr nz, rcl_illegal
    ld a, 1
    ret
rcl_illegal:
    xor a
    ret


rules_pseudo:
    ld hl, (r_board)
    ld (r_active), hl
    ld a, (r_from)
    call rules_get_active
    ld (r_piece), a
    or a
    jp z, rules_ret0
    call rules_piece_side
    ld hl, r_side
    cp (hl)
    jp nz, rules_ret0

    ld a, (r_to)
    call rules_get_active
    ld (r_dst), a
    or a
    jr z, rules_pseudo_dst_ok
    call rules_piece_side
    ld hl, r_side
    cp (hl)
    jp z, rules_ret0
    ld a, (r_dst)
    call rules_abs
    cp RULE_KING
    jp z, rules_ret0
rules_pseudo_dst_ok:
    ld a, (r_piece)
    call rules_abs
    ld (r_type), a

    ld a, (r_from)
    and 7
    ld (r_ff), a
    ld a, (r_from)
    srl a
    srl a
    srl a
    ld (r_fr), a
    ld a, (r_to)
    and 7
    ld (r_tf), a
    ld a, (r_to)
    srl a
    srl a
    srl a
    ld (r_tr), a

    ld a, (r_tr)
    ld hl, r_fr
    sub (hl)
    ld (r_dr), a
    call rules_abs
    ld (r_adr), a
    ld a, (r_tf)
    ld hl, r_ff
    sub (hl)
    ld (r_df), a
    call rules_abs
    ld (r_adf), a

    ld a, (r_type)
    cp RULE_PAWN
    jr z, rules_pawn
    cp RULE_KNIGHT
    jp z, rules_knight
    cp RULE_BISHOP
    jp z, rules_bishop
    cp RULE_ROOK
    jp z, rules_rook
    cp RULE_QUEEN
    jp z, rules_queen
    cp RULE_KING
    jp z, rules_king
    jp rules_ret0

rules_pawn:
    ld a, (r_side)
    or a
    jp nz, rules_pawn_black
rules_pawn_white:
    ld a, (r_df)
    or a
    jr nz, rules_pawn_white_capture
    ld a, (r_dr)
    cp 255
    jr nz, rules_pawn_white_double
    ld a, (r_dst)
    or a
rules_return_z:
    jp z, rules_ret1
    jp rules_ret0
rules_pawn_white_double:
    ld a, (r_fr)
    cp 6
    jp nz, rules_ret0
    ld a, (r_dr)
    cp 254
    jp nz, rules_ret0
    ld a, (r_dst)
    or a
    jp nz, rules_ret0
    ld a, (r_from)
    sub 8
    call rules_get_active
    or a
    jp rules_return_z
rules_pawn_white_capture:
    ld a, (r_adf)
    cp 1
    jp nz, rules_ret0
    ld a, (r_dr)
    cp 255
    jp nz, rules_ret0
    ld a, (r_dst)
    or a
    jp nz, rules_ret1
    ld a, (r_to)
    ld hl, r_ep
    cp (hl)
    jp nz, rules_ret0
    add a, 8
    call rules_get_active
    cp RULE_BP
    jp rules_return_z

rules_pawn_black:
    ld a, (r_df)
    or a
    jr nz, rules_pawn_black_capture
    ld a, (r_dr)
    cp 1
    jr nz, rules_pawn_black_double
    ld a, (r_dst)
    or a
    jp rules_return_z
rules_pawn_black_double:
    ld a, (r_fr)
    cp 1
    jp nz, rules_ret0
    ld a, (r_dr)
    cp 2
    jp nz, rules_ret0
    ld a, (r_dst)
    or a
    jp nz, rules_ret0
    ld a, (r_from)
    add a, 8
    call rules_get_active
    or a
    jp rules_return_z
rules_pawn_black_capture:
    ld a, (r_adf)
    cp 1
    jp nz, rules_ret0
    ld a, (r_dr)
    cp 1
    jp nz, rules_ret0
    ld a, (r_dst)
    or a
    jp nz, rules_ret1
    ld a, (r_to)
    ld hl, r_ep
    cp (hl)
    jp nz, rules_ret0
    sub 8
    call rules_get_active
    cp RULE_WP
    jp rules_return_z

rules_knight:
    ld a, (r_adr)
    dec a
    cp 2
    jp nc, rules_ret0
    ld b, a
    ld a, (r_adf)
    dec a
    cp 2
    jp nc, rules_ret0
    add a, b
    cp 1
    jp rules_return_z

rules_bishop:
    ld a, (r_adr)
    or a
    jp z, rules_ret0
    ld hl, r_adf
    cp (hl)
    jp nz, rules_ret0
    call rules_diag_step
    jp rules_path_clear

rules_rook:
    ld a, (r_dr)
    or a
    jr z, rules_rook_file
    ld a, (r_df)
    or a
    jp nz, rules_ret0
    ld a, (r_dr)
    bit 7, a
    ld a, 8
    jr z, rules_rook_step
    ld a, 248
    jr rules_rook_step
rules_rook_file:
    ld a, (r_df)
    or a
    jp z, rules_ret0
    bit 7, a
    ld a, 1
    jr z, rules_rook_step
    ld a, 255
rules_rook_step:
    ld (r_step), a
    jr rules_path_clear

rules_queen:
    ld a, (r_adr)
    or a
    jr z, rules_rook
    ld hl, r_adf
    cp (hl)
    jr nz, rules_rook
    call rules_diag_step
    jr rules_path_clear

rules_diag_step:
    ld a, (r_dr)
    bit 7, a
    ld b, 8
    jr z, rules_diag_df
    ld b, 248
rules_diag_df:
    ld a, (r_df)
    bit 7, a
    ld a, 1
    jr z, rules_diag_sum
    ld a, 255
rules_diag_sum:
    add a, b
    ld (r_step), a
    ret

rules_path_clear:
    ld a, (r_step)
    ld b, a
    ld a, (r_from)
    add a, b
rules_path_loop:
    ld hl, r_to
    cp (hl)
    jp z, rules_ret1
    push af
    push bc
    call rules_get_active
    pop bc
    or a
    jr nz, rules_path_blocked
    pop af
    add a, b
    jr rules_path_loop
rules_path_blocked:
    pop af
    jp rules_ret0

rules_king:
    ld a, (r_adr)
    cp 2
    jr nc, rules_king_castle
    ld a, (r_adf)
    cp 2
    jr nc, rules_king_castle
    ld a, (r_adr)
    ld hl, r_adf
    or (hl)
    jp nz, rules_ret1
rules_king_castle:
    ld a, (r_dr)
    or a
    jp nz, rules_ret0
    ld a, (r_adf)
    cp 2
    jp nz, rules_ret0
    ld a, (r_dst)
    or a
    jp nz, rules_ret0

    ld a, (r_side)
    or a
    ld d, 56
    ld a, CASTLE_WK
    jr z, rkc_side_ok
    ld d, 0
    ld a, CASTLE_BK
rkc_side_ok:
    ld (r_scan_piece), a

    ld a, (r_from)
    ld e, a
    ld a, d
    add a, 4
    cp e
    jp nz, rules_ret0

    ld a, (r_to)
    ld e, a
    ld a, d
    add a, 6
    cp e
    jr z, rkc_king_side
    ld a, d
    add a, 2
    cp e
    jr z, rkc_queen_side
    jp rules_ret0

rkc_king_side:
    ld a, (r_scan_piece)
    ld b, a
    ld a, (r_castle)
    and b
    jp z, rules_ret0

    ld c, 7
    call rkc_check_rook_offset

    ld c, 5
    call rkc_check_empty_offset

    ld c, 6
    call rkc_check_empty_offset

    ld a, (r_side)
    xor 1
    ld b, a

    ld c, 4
    call rkc_check_attack_offset

    ld c, 5
    call rkc_check_attack_offset

    ld c, 6
    call rkc_check_attack_offset

    jp rules_ret1

rkc_queen_side:
    ld a, (r_scan_piece)
    add a, a
    ld b, a
    ld a, (r_castle)
    and b
    jp z, rules_ret0

    ld c, 0
    call rkc_check_rook_offset

    ld c, 3
    call rkc_check_empty_offset

    ld c, 2
    call rkc_check_empty_offset

    ld c, 1
    call rkc_check_empty_offset

    ld a, (r_side)
    xor 1
    ld b, a

    ld c, 4
    call rkc_check_attack_offset

    ld c, 3
    call rkc_check_attack_offset

    ld c, 2
    call rkc_check_attack_offset

    jp rules_ret1

rkc_check_attack_offset:
    ; INVARIANT: these rkc_check_*_offset helpers fail by popping the
    ; caller return address and jumping to rules_ret0. Callers must not hold
    ; extra stack state across these calls, and rules_king must be reached by
    ; JP, not CALL.
    ld a, d
    add a, c
    call rkc_check_attack
    ret z
    pop hl
    jp rules_ret0

rkc_check_empty_offset:
    ld a, d
    add a, c
    call rules_get_active
    or a
    ret z
    pop hl
    jp rules_ret0

rkc_check_rook_offset:
    ld a, d
    add a, c
    call rules_get_active
    ld b, a
    ld a, (r_side)
    or a
    ld a, RULE_WR
    jr z, rkc_check_rook_cmp
    ld a, RULE_BR
rkc_check_rook_cmp:
    cp b
    ret z
    pop hl
    jp rules_ret0

rkc_check_attack:
    push bc
    push de
    call rules_attacked_by
    pop de
    pop bc
    or a
    ret

rules_make_tmp:
    ld hl, (r_board)
    ld de, r_tmp
    ld bc, 64
    ldir
    ld a, (r_from)
    ld e, a
    ld d, 0
    ld hl, r_tmp
    add hl, de
    ld a, (hl)
    ld (r_moving), a
    ld (hl), RULE_EMPTY
    ld a, (r_to)
    ld e, a
    ld d, 0
    ld hl, r_tmp
    add hl, de
    ld a, (r_moving)
    ld (hl), a

    call rules_abs
    cp RULE_PAWN
    jr nz, rules_make_castle
    ld a, (r_dst)
    or a
    jr nz, rules_make_castle
    ld a, (r_ff)
    ld hl, r_tf
    cp (hl)
    jr z, rules_make_castle
    ld a, (r_to)
    ld hl, r_ep
    cp (hl)
    jr nz, rules_make_castle
    ld a, (r_side)
    or a
    ld a, (r_to)
    jr nz, rules_make_ep_black
    add a, 8
    jr rules_make_ep_clear
rules_make_ep_black:
    sub 8
rules_make_ep_clear:
    ld e, a
    ld d, 0
    ld hl, r_tmp
    add hl, de
    ld (hl), RULE_EMPTY

rules_make_castle:
    ld a, (r_moving)
    cp RULE_WK
    jr nz, rules_make_castle_black
    ld a, (r_from)
    cp 60
    ret nz
    ld a, (r_to)
    cp 62
    jr z, rules_make_wk
    cp 58
    ret nz
    ld a, RULE_WR
    ld (r_tmp + 59), a
    xor a
    ld (r_tmp + 56), a
    ret
rules_make_wk:
    ld a, RULE_WR
    ld (r_tmp + 61), a
    xor a
    ld (r_tmp + 63), a
    ret
rules_make_castle_black:
    cp RULE_BK
    ret nz
    ld a, (r_from)
    cp 4
    ret nz
    ld a, (r_to)
    cp 6
    jr z, rules_make_bk
    cp 2
    ret nz
    ld a, RULE_BR
    ld (r_tmp + 3), a
    xor a
    ld (r_tmp + 0), a
    ret
rules_make_bk:
    ld a, RULE_BR
    ld (r_tmp + 5), a
    xor a
    ld (r_tmp + 7), a
    ret

rules_find_king:
    ld a, (r_side)
    or a
    ld b, RULE_WK
    jr z, rules_find_king_go
    ld b, RULE_BK
rules_find_king_go:
    ld hl, r_tmp
    ld c, 0
rules_find_king_loop:
    ld a, (hl)
    cp b
    jr z, rules_find_king_found
    inc hl
    inc c
    ld a, c
    cp 64
    jr nz, rules_find_king_loop
    ld a, 255
    ret
rules_find_king_found:
    ld a, c
    ret

rules_attacked_by:
    ld (r_attack_sq), a
    ld a, b
    ld (r_by_side), a
    ld a, (r_attack_sq)
    and 7
    ld (r_af), a
    ld a, (r_attack_sq)
    srl a
    srl a
    srl a
    ld (r_ar), a

    ld a, (r_by_side)
    or a
    ; c = left attacker offset, b = right attacker offset.
    ; rules_get_active preserves DE; keep expected pawn in E across probes.
    ld c, 7
    ld b, 9
    ld e, RULE_WP
    ld a, (r_attack_sq)
    jr z, r_at_p_white_ok
    ld c, 247
    ld b, 249
    ld e, RULE_BP
    cp 8
    jr c, rules_attack_knights
    jr r_at_p_boundary_ok
r_at_p_white_ok:
    cp 56
    jr nc, rules_attack_knights
r_at_p_boundary_ok:
    ld a, (r_af)
    or a
    jr z, r_at_p_left_skip
    ld a, (r_attack_sq)
    add a, c
    call rules_get_active
    cp e
    jp z, rules_ret1
r_at_p_left_skip:
    ld a, (r_af)
    cp 7
    jr z, rules_attack_knights
    ld a, (r_attack_sq)
    add a, b
    call rules_get_active
    cp e
    jp z, rules_ret1

rules_attack_knights:
    ld ix, knight_dr
    ld iy, knight_df
    ld hl, r_by_side
    bit 0, (hl)
    ld b, RULE_WN
    jr z, r_at_k_go
    ld b, RULE_BN
r_at_k_go:
    call rules_attack_loop_shared
    or a
    jp nz, rules_ret1

rules_attack_kings:
    ld ix, ray_dr
    ld iy, ray_df
    ld hl, r_by_side
    bit 0, (hl)
    ld b, RULE_WK
    jr z, r_at_ki_go
    ld b, RULE_BK
r_at_ki_go:
    call rules_attack_loop_shared
    or a
    jp nz, rules_ret1
    jr rules_attack_rays

rules_attack_loop_shared:
    ld c, 8
rules_attack_loop:
    ld a, (r_ar)
    add a, (ix+0)
    cp 8
    jr nc, rules_attack_next
    ld d, a
    ld a, (r_af)
    add a, (iy+0)
    cp 8
    jr nc, rules_attack_next
    ld e, a
    call rules_rf_to_sq
    call rules_get_active
    cp b
    jr nz, rules_attack_next
    ld a, 1
    ret
rules_attack_next:
    inc ix
    inc iy
    dec c
    jr nz, rules_attack_loop
    xor a
    ret

rules_attack_rays:
    ld ix, ray_dr
    ld iy, ray_df
    ld c, 8
rules_attack_ray_dir:
    ld a, (r_ar)
    add a, (ix+0)
    ld d, a
    ld a, (r_af)
    add a, (iy+0)
    ld e, a
rules_attack_ray_loop:
    ld a, d
    cp 8
    jr nc, rules_attack_ray_next
    ld a, e
    cp 8
    jr nc, rules_attack_ray_next
    call rules_rf_to_sq
    call rules_get_active
    or a
    jr z, rules_attack_ray_advance
    ld b, a
    call rules_piece_side
    ld hl, r_by_side
    cp (hl)
    jr nz, rules_attack_ray_next
    ld a, b
    call rules_abs
    ld b, a
    ld a, c
    cp 5
    jr c, rules_attack_ray_straight
    ld a, b
    cp RULE_BISHOP
    jr z, rules_ret1
    cp RULE_QUEEN
    jr z, rules_ret1
    jr rules_attack_ray_next
rules_attack_ray_straight:
    ld a, b
    cp RULE_ROOK
    jr z, rules_ret1
    cp RULE_QUEEN
    jr z, rules_ret1
    jr rules_attack_ray_next
rules_attack_ray_advance:
    ld a, d
    add a, (ix+0)
    ld d, a
    ld a, e
    add a, (iy+0)
    ld e, a
    jr rules_attack_ray_loop
rules_attack_ray_next:
    inc ix
    inc iy
    dec c
    jr nz, rules_attack_ray_dir
    jr rules_ret0

rules_rf_to_sq:
    ld a, d
    add a, a
    add a, a
    add a, a
    add a, e
    ret

rules_get_active:
    push de
    ld e, a
    ld d, 0
    ld hl, (r_active)
    add hl, de
    ld a, (hl)
    pop de
    ret

rules_piece_side:
    bit 7, a
    jr nz, rules_piece_black
    xor a
    ret
rules_piece_black:
    ld a, 1
    ret

rules_abs:
    bit 7, a
    ret z
    neg
    ret

rules_ret1:
    ld a, 1
    ret
rules_ret0:
    xor a
    ret

knight_dr:
    DEFB 254,254,255,255,1,1,2,2
knight_df:
    DEFB 255,1,254,2,254,2,255,1
ray_dr:
    DEFB 255,255,1,1,255,0,0,1
ray_df:
    DEFB 255,1,255,1,0,255,1,0

r_board:        DEFW 0
r_active:       DEFW 0
r_side:         DEFB 0
r_from:         DEFB 0
r_to:           DEFB 0
r_castle:       DEFB 0
r_ep:           DEFB 0
r_piece:        DEFB 0
r_dst:          DEFB 0
r_type:         DEFB 0
r_moving:       DEFB 0
r_fr:           DEFB 0
r_ff:           DEFB 0
r_tr:           DEFB 0
r_tf:           DEFB 0
r_dr:           DEFB 0
r_df:           DEFB 0
r_adr:          DEFB 0
r_adf:          DEFB 0
r_step:         DEFB 0
r_attack_sq:    DEFB 0
r_by_side:      DEFB 0
r_in_check:     DEFB 0
r_ar:           DEFB 0
r_af:           DEFB 0
r_scan_piece:   DEFB 0
; Must equal the linked _overlay_scratch_base; check_lowmem_layout.py proves it.
r_tmp           EQU 0x672B
rules_tmp_size  EQU 64

r_hint_ink:
    DEFB 0
