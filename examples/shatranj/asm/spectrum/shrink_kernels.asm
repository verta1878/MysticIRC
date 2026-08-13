SECTION code_user

PUBLIC _netchesszx_asm_direct_parse_role_owner
PUBLIC _netchesszx_asm_proto_copy_token
PUBLIC _netchesszx_asm_move_parse_coords
PUBLIC _netchesszx_asm_move_syntax_ok
PUBLIC _netchess_proto_copy_digits
PUBLIC _netchess_proto_copy_rest
PUBLIC _netchesszx_asm_put_timer_digit
PUBLIC _netchesszx_asm_timer_tick_one_second
PUBLIC _netchess_mqtt_session_parse_u16_token
PUBLIC _netchesszx_asm_line_has
PUBLIC _netchesszx_asm_mqtt_strlen8
PUBLIC _netchesszx_asm_mqtt_copy
PUBLIC _netchess_after_prefix
PUBLIC _netchesszx_asm_net_copy
PUBLIC _netchesszx_asm_net_move
PUBLIC _netchesszx_session_send_ack_move
PUBLIC _netchesszx_session_send_nack_move
PUBLIC _netchesszx_asm_restore_chunk_step

EXTERN _line_buf
EXTERN _NETCHESS_PROTO_ACK_PREFIX
EXTERN _NETCHESS_PROTO_NACK_PREFIX
EXTERN _spectrum_net_payload_scratch
EXTERN _spectrum_net_send_text

; Fixed RESTORE RS state kernel. The event classifier has already proved
; frame[3] is '0' or '1' and the frame is 35 bytes. Normal SDCC/IY ABI:
; mask at SP+2, cache at SP+4, frame at SP+6. It returns the C action code
; REJECT=0, PARTIAL=1, COMPLETE=2, REACK=3. C owns every send/apply/EXIT.
_netchesszx_asm_restore_chunk_step:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    push de
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    push de
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    pop hl
    pop de
    ld a, (de)
    bit 5, a
    jr nz, restore_step_applied
    bit 4, a
    jr z, restore_step_reject

    push de
    inc bc
    inc bc
    inc bc
    ld a, (bc)
    sub '0'
    push af
    inc bc
    inc bc
    or a
    jr z, restore_step_store_offset_ready
    ld de, 30
    add hl, de
restore_step_store_offset_ready:
    ld d, b
    ld e, c
    ex de, hl
    ld bc, 30
    ldir
    pop af
    inc a
    ld c, a
    pop de
    ld a, (de)
    or c
    ld (de), a
    and 3
    cp 3
    ld l, 1
    ret nz
    inc l
    ret

restore_step_applied:
    push de
    inc bc
    inc bc
    inc bc
    ld a, (bc)
    sub '0'
    inc bc
    inc bc
    or a
    jr z, restore_step_equal_offset_ready
    ld de, 30
    add hl, de
restore_step_equal_offset_ready:
    ld d, b
    ld e, c
    ld b, 30
restore_step_equal_loop:
    ld a, (de)
    cp (hl)
    jr nz, restore_step_conflict
    inc de
    inc hl
    djnz restore_step_equal_loop
    pop de
    ld l, 3
    ret
restore_step_conflict:
    pop de
    xor a
    ld (de), a
restore_step_reject:
    ld l, 0
    ret

; Compact ACK/NACK builder. Golden wire vectors, including 0 and 65535, live in
; tests/spectrum/test_session_outgoing.c::test_ack_nack. The normal SDCC/IY ABI
; leaves the text pointer at SP+2. Build into the inactive transport scratch,
; then pass that pointer in HL to spectrum_net_send_text()'s fastcall ABI.
_netchesszx_session_send_ack_move:
    ld bc, _NETCHESS_PROTO_ACK_PREFIX
    jr session_send_prefixed_text

_netchesszx_session_send_nack_move:
    ld bc, _NETCHESS_PROTO_NACK_PREFIX

session_send_prefixed_text:
    push bc
    call _spectrum_net_payload_scratch
    ex de, hl
    pop bc
    push de

    ld hl, 4
    add hl, sp
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    push hl
    call session_reply_copyz
    dec de
    pop bc
    call session_reply_copyz
    pop hl
    jp _spectrum_net_send_text

session_reply_copyz:
    ld a, (bc)
    inc bc
    ld (de), a
    inc de
    or a
    jr nz, session_reply_copyz
    ret

_netchesszx_asm_direct_parse_role_owner:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    ld l, 0

    ld a, (de)
    cp 'H'
    jr nz, dpro_guest
    inc de
    ld a, (de)
    cp 'O'
    ret nz
    inc de
    ld a, (de)
    cp 'S'
    ret nz
    inc de
    ld a, (de)
    cp 'T'
    ret nz
    inc de
    ld a, (de)
    or a
    ret nz
    ld (bc), a
    inc l
    ret

dpro_guest:
    ; de still points to the string start: the 'H' mismatch above branches here
    ; before de is advanced, so no reload from the stack frame is needed.
    ld a, (de)
    cp 'G'
    ret nz
    inc de
    ld a, (de)
    cp 'U'
    ret nz
    inc de
    ld a, (de)
    cp 'E'
    ret nz
    inc de
    ld a, (de)
    cp 'S'
    ret nz
    inc de
    ld a, (de)
    cp 'T'
    ret nz
    inc de
    ld a, (de)
    or a
    ret nz
    inc l
    ld a, l
    ld (bc), a
    ret

_netchesszx_asm_proto_copy_token:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ld a, (hl)
    or a
    jr z, cpb_ret0
    push de
    push af
    ld a, (de)
    ld l, a
    inc de
    ld h, (de)
    ld d, b
    ld e, c
    pop af
    ld b, a
    dec b
    ld c, 0
cpb_token_loop:
    ld a, b
    or a
    jr z, cpb_done
    ld a, (hl)
    or a
    jr z, cpb_done
    cp ' '
    jr z, cpb_done
    ld (de), a
    inc de
    inc hl
    inc c
    djnz cpb_token_loop

_netchess_proto_copy_digits:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ld a, (hl)
    or a
    jr z, cpb_ret0
    push de
    push af
    ld a, (de)
    ld l, a
    inc de
    ld h, (de)
    ld d, b
    ld e, c
    pop af
    ld b, a
    dec b
    ld c, 0
cpb_digit_loop:
    ld a, b
    or a
    jr z, cpb_done
    ld a, (hl)
    sub '0'
    cp 10
    jr nc, cpb_done
    add a, '0'
    ld (de), a
    inc de
    inc hl
    inc c
    djnz cpb_digit_loop

cpb_done:
    xor a
    ld (de), a
    pop de
    ld a, l
    ld (de), a
    inc de
    ld a, h
    ld (de), a
    ld l, c
    ret

cpb_ret0:
    ld l, 0
    ret

_netchess_proto_copy_rest:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ld a, (hl)
    or a
    ret z
    dec a
    ld l, e
    ld h, d
    ld d, b
    ld e, c
    ld b, a
cprest_loop:
    ld a, b
    or a
    jr z, cprest_done
    ld a, (hl)
    or a
    jr z, cprest_done
    ld (de), a
    inc hl
    inc de
    djnz cprest_loop
cprest_done:
    xor a
    ld (de), a
    ret

; __z88dk_fastcall: HL=move, return HL=(to_index<<8)|from_index or $ffff.
; Clobbers AF/BC/HL and flags; preserves DE/IX/IY and the caller's stack.
_netchesszx_asm_move_parse_coords:
    ld a, (hl)
    sub 'a'
    cp 8
    jr nc, move_coords_invalid
    ld c, a
    inc hl
    ld a, '8'
    sub (hl)
    cp 8
    jr nc, move_coords_invalid
    rlca
    rlca
    rlca
    add a, c
    ld c, a
    inc hl
    ld a, (hl)
    sub 'a'
    cp 8
    jr nc, move_coords_invalid
    ld b, a
    inc hl
    ld a, '8'
    sub (hl)
    cp 8
    jr nc, move_coords_invalid
    rlca
    rlca
    rlca
    add a, b
    cp c
    jr z, move_coords_invalid
    ld h, a
    ld l, c
    ret
move_coords_invalid:
    ld hl, $ffff
    ret

_netchesszx_asm_move_syntax_ok:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld b, (hl)
    ld l, 0
    ld a, b
    cp 4
    jr z, mso_len_ok
    cp 5
    ret nz
mso_len_ok:
    ld a, (de)
    call mso_file
    ret nc
    inc de
    ld a, (de)
    call mso_rank
    ret nc
    inc de
    ld a, (de)
    call mso_file
    ret nc
    inc de
    ld a, (de)
    call mso_rank
    ret nc
    ld a, b
    cp 4
    jr z, mso_ret1
    inc de
    ld a, (de)
    cp 'b'
    jr z, mso_ret1
    cp 'n'
    jr z, mso_ret1
    sub 'q'
    cp 2
    ret nc
mso_ret1:
    inc l
    ret
mso_file:
    sub 'a'
    jr mso_coord
mso_rank:
    sub '1'
mso_coord:
    cp 8
    ret

_netchesszx_asm_put_timer_digit:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld b, (hl)
    ld c, 0
ptd_loop:
    ld a, b
    cp 10
    jr c, ptd_store
    sub 10
    ld b, a
    inc c
    jr ptd_loop
ptd_store:
    ld a, c
    add a, '0'
    ld (de), a
    inc de
    ld a, b
    add a, '0'
    ld (de), a
    ret

_netchesszx_asm_timer_tick_one_second:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ld a, (de)
    cp 99
    jr nz, ttos_inc_second
    ld a, (bc)
    cp 59
    jr nz, ttos_inc_second
    ld a, (hl)
    cp 59
    ret z
ttos_inc_second:
    inc (hl)
    ld a, (hl)
    cp 60
    ret c
    ld (hl), 0
    ld a, (bc)
    inc a
    ld (bc), a
    cp 60
    ret c
    xor a
    ld (bc), a
    ld a, (de)
    inc a
    ld (de), a
    ret

_netchess_mqtt_session_parse_u16_token:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    push bc
    ld hl, 0
    ld b, 0
mqtt_u16_loop:
    ld a, (de)
    sub '0'
    cp 10
    jr nc, mqtt_u16_done
    ld c, a
    ld a, h
    cp 0x19
    jr c, mqtt_u16_safe
    jr nz, mqtt_u16_fail
    ld a, l
    cp 0x99
    jr c, mqtt_u16_safe
    jr nz, mqtt_u16_fail
    ld a, c
    cp 6
    jr nc, mqtt_u16_fail
mqtt_u16_safe:
    push de
    ld d, h
    ld e, l
    add hl, hl
    add hl, hl
    add hl, de
    add hl, hl
    ld e, c
    ld d, 0
    add hl, de
    pop de
    inc de
    inc b
    jr mqtt_u16_loop
mqtt_u16_done:
    ld a, b
    or a
    jr z, mqtt_u16_fail
    pop bc
    ld a, l
    ld (bc), a
    inc bc
    ld a, h
    ld (bc), a
    ex de, hl
    ret
mqtt_u16_fail:
    pop bc
    ld hl, 0
    ret

_netchesszx_asm_line_has:
    ld de, _line_buf
line_has_loop:
    ld a, (hl)
    or a
    jr z, line_has_ret1
    ld c, a
    ld a, (de)
    cp c
    jr nz, line_has_ret0
    inc hl
    inc de
    jr line_has_loop
line_has_ret1:
    ld l, 1
    ret
line_has_ret0:
    ld l, 0
    ret
_netchesszx_asm_mqtt_strlen8:
    ld b, 0
mqtt_strlen8_loop:
    ld a, (hl)
    or a
    jr z, mqtt_strlen8_done
    inc hl
    inc b
    jr mqtt_strlen8_loop
mqtt_strlen8_done:
    ld l, b
    ret

_netchesszx_asm_mqtt_copy:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ld a, (hl)
    or a
    ret z
    push bc
    ld c, a
    ld b, 0
    pop hl
    ldir
    ret

_netchess_after_prefix:
    ld hl, 2
    add hl, sp
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl
after_prefix_loop:
    ld a, (hl)
    or a
    jr z, after_prefix_match
    ld e, a
    ld a, (bc)
    cp e
    jr nz, after_prefix_fail
    inc hl
    inc bc
    jr after_prefix_loop
after_prefix_match:
    ld l, c
    ld h, b
    ret
after_prefix_fail:
    ld hl, 0
    ret

_netchesszx_asm_net_copy:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    push bc
    push de
    ld c, (hl)
    inc hl
    ld b, (hl)
    pop de
    pop hl
    ld a, b
    or c
    ret z
    ldir
    ret

_netchesszx_asm_net_move:
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    push bc
    push de
    ld c, (hl)
    inc hl
    ld b, (hl)
    pop de
    pop hl
    ld a, b
    or c
    ret z
    or a
    sbc hl, de
    jr c, nm_backward
    add hl, de
    ldir
    ret
nm_backward:
    add hl, de
    ex de, hl
    add hl, bc
    dec hl
    push hl
    ex de, hl
    add hl, bc
    dec hl
    pop de
    lddr
    ret
