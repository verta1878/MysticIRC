SECTION code_user

PUBLIC _about_render_ovl_entry

IFDEF NETCHESSZX_NEXT

    DEFB 1
    DW _about_render_ovl_entry

; The banking Next build owns a separate Layer 2 About image. Keep only a
; valid atlas entry; the loader never calls this ZX renderer.
_about_render_ovl_entry:
    ld hl, 0
    ret

ELSE

EXTERN ovl_close_overlay_file

about_payload_offset EQU 1196
about_payload_size EQU 706
about_first_read_size EQU 448
about_second_read_size EQU about_payload_size - about_first_read_size
about_logo_first_rows EQU 32
about_logo_tail_rows EQU 3
about_logo_tail_bytes EQU 14 * about_logo_tail_rows
about_board_width EQU 18
about_board_top_y EQU 32
about_board_rows EQU 144
about_board_attr_top EQU 4
about_board_attr_rows EQU 18
; Transient DAT buffer: immediately after MQTT scratch, ending 21 bytes below
; the 0x6800 overlay slot. The low-memory guard checks both boundaries.
about_input EQU 0x662B
about_input_size EQU 448

    DEFB 1
    DW _about_render_ovl_entry

_about_render_ovl_entry:
    push ix
    push iy
    call ovl_close_overlay_file
    ld hl, about_asset_filename
    push hl
    pop ix
    ld b, 0x01
    ld a, '*'
    rst 8
    defb 0x9a
    jp c, about_fail
    ld (about_handle), a

    ld a, (about_handle)
    ld de, about_payload_offset
    ld bc, 0
    ld ix, 0
    ld l, 0
    rst 8
    defb 0x9f
    jp c, about_fail_close

    call about_paint_base

    ld bc, about_first_read_size
    call about_read_input
    jp c, about_fail_close
    ld hl, about_input
    ld a, 24
    ld b, about_logo_first_rows
    call about_copy_14

    ld bc, about_second_read_size
    call about_read_input
    jp c, about_fail_close
    ld hl, about_input
    ld a, 56
    ld b, about_logo_tail_rows
    call about_copy_14
    ld hl, about_input + about_logo_tail_bytes
    ld a, 90
    ld b, 4
    call about_copy_14
    ld hl, about_input + about_logo_tail_bytes + 56
    ld a, 98
    ld b, 4
    call about_copy_14
    ld hl, about_input + about_logo_tail_bytes + 112
    ld a, 106
    ld b, 4
    call about_copy_14
    ld hl, about_input + about_logo_tail_bytes + 168
    ld a, 114
    ld b, 4
    call about_copy_12

about_ok:
    call about_close
    pop iy
    pop ix
    ld hl, 1
    ret

about_fail_close:
    call about_close
about_fail:
    pop iy
    pop ix
    ld hl, 0
    ret

; Paint the canonical black board area, white frame and exact attributes.
; Visible logo/text bytes are copied over this base afterwards.
about_paint_base:
    call about_paint_pixels

    xor a
    ld (about_row), a
    ld a, about_board_attr_rows
    ld (about_rows_left), a
about_attr_loop:
    ld a, (about_row)
    ld e, a
    ld d, 0
    ld hl, about_attr_inner
    add hl, de
    ld c, (hl)
    ld a, (about_row)
    call about_attr_addr
    ld (hl), 7
    inc hl
    ld b, 16
    ld a, c
about_attr_inner_loop:
    ld (hl), a
    inc hl
    djnz about_attr_inner_loop
    ld (hl), 7
    ld a, (about_row)
    inc a
    ld (about_row), a
    ld a, (about_rows_left)
    dec a
    ld (about_rows_left), a
    jr nz, about_attr_loop
    ret

about_paint_pixels:
    xor a
    ld (about_row), a
    ld a, about_board_rows
    ld (about_rows_left), a
about_pixel_loop:
    ld a, (about_row)
    call about_screen_addr
    ld a, (about_row)
    cp 7
    jr c, about_pixel_blank
    jr z, about_pixel_hline
    cp 136
    jr c, about_pixel_sides
    jr z, about_pixel_hline
about_pixel_blank:
    ld b, about_board_width
    xor a
about_pixel_blank_loop:
    ld (hl), a
    inc hl
    djnz about_pixel_blank_loop
    jr about_pixel_next

about_pixel_sides:
    ld (hl), 0x01
    inc hl
    ld b, 16
    xor a
about_pixel_inner_loop:
    ld (hl), a
    inc hl
    djnz about_pixel_inner_loop
    ld (hl), 0x80
    jr about_pixel_next

about_pixel_hline:
    ld (hl), 0x01
    inc hl
    ld b, 16
    ld a, 0xff
about_pixel_hline_loop:
    ld (hl), a
    inc hl
    djnz about_pixel_hline_loop
    ld (hl), 0x80

about_pixel_next:
    ld a, (about_row)
    inc a
    ld (about_row), a
    ld a, (about_rows_left)
    dec a
    ld (about_rows_left), a
    jr nz, about_pixel_loop
    ret

; HL=source, A=top row inside the 144-line board, B=row count.
about_copy_14:
    ld c, 2
    ld d, 14
    jr about_copy_setup
about_copy_12:
    ld c, 3
    ld d, 12
about_copy_setup:
    ld (about_row), a
    ld a, b
    ld (about_rows_left), a
    ld a, c
    ld (about_copy_left), a
    ld a, d
    ld (about_copy_width), a
about_copy_loop:
    push hl
    ld a, (about_row)
    call about_screen_addr
    ld a, (about_copy_left)
    add a, l
    ld l, a
    ex de, hl
    pop hl
    ld a, (about_copy_width)
    ld c, a
    ld b, 0
    ldir
    ld a, (about_row)
    inc a
    ld (about_row), a
    ld a, (about_rows_left)
    dec a
    ld (about_rows_left), a
    jr nz, about_copy_loop
    ret

about_read_input:
    push bc
    ld ix, about_input
    ld a, (about_handle)
    rst 8
    defb 0x9d
    jr c, about_read_fail
    pop de
    ld a, b
    cp d
    jr nz, about_short_read
    ld a, c
    cp e
    ret z
about_short_read:
    scf
    ret
about_read_fail:
    pop de
    scf
    ret

about_close:
    ld a, (about_handle)
    rst 8
    defb 0x9b
    ret

; A=row inside the About board. Returns the ULA bitmap address in HL.
about_screen_addr:
    add a, about_board_top_y
    ld b, a
    and 0x07
    add a, 0x40
    ld h, a
    ld a, b
    and 0xc0
    srl a
    srl a
    srl a
    add a, h
    ld h, a
    ld a, b
    and 0x38
    add a, a
    add a, a
    ld l, a
    ret

about_attr_addr:
    add a, about_board_attr_top
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, 0x5800
    add hl, de
    ret

about_attr_inner:
    DEFB 7,0,7,7,7,7,7,7,0,0,0,7,7,6,6,0,0,7

about_handle: DEFB 0
about_row: DEFB 0
about_rows_left: DEFB 0
about_copy_left: DEFB 0
about_copy_width: DEFB 0
about_asset_filename:
    DEFM "SHATRANJ.DAT"
    DEFB 0

ENDIF
