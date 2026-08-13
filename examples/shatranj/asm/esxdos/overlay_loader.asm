SECTION code_user

; SDCC/IY: two uint8 args are packed into one stack word:
;   SP+2 = ovl_id, SP+3 = entry_id.

PUBLIC _spectrum_overlay_exec
PUBLIC _spectrum_overlay_exec_cached
PUBLIC _spectrum_assets_load
PUBLIC _spectrum_assets_fatal
PUBLIC _spectrum_render_about
PUBLIC _netchesszx_piece_set_load
PUBLIC _spectrum_overlay_loaded_id
PUBLIC _overlay_code_slot
PUBLIC _overlay_scratch_base
PUBLIC _spectrum_overlay_context
PUBLIC ovl_close_overlay_file

_spectrum_overlay_context EQU 0x5FE0
_overlay_code_slot EQU 0x6800
_overlay_scratch_base EQU 0x672B
ovl_invalid_id EQU 0xff
INCLUDE "overlay_atlas_table.asm"
asset_load_addr EQU 0x6000
asset_load_size EQU 1196
asset_piece_offset EQU 812
piece_sprite_set_size EQU 384
piece_sprite_set_size_hi EQU piece_sprite_set_size / 256
piece_sprite_set_size_lo EQU piece_sprite_set_size - (piece_sprite_set_size_hi * 256)
asset_load_size_hi EQU asset_load_size / 256
asset_load_size_lo EQU asset_load_size - (asset_load_size_hi * 256)
about_board_offset EQU asset_load_size
about_board_size EQU 706
piece_set_extra_offset EQU about_board_offset + about_board_size
about_ovl_id EQU 12
about_render_entry EQU 0

SECTION bss_user

ovl_handle:   DEFS 1
ovl_entry_id: DEFS 1
ovl_id:       DEFS 1
ovl_cache_ready: DEFS 1
ovl_file_open: DEFS 1
asset_set_index: DEFS 1
_spectrum_overlay_loaded_id: DEFS 1
ovl_load_size: DEFS 2

SECTION code_user

_spectrum_overlay_exec:
    xor a
    ld (ovl_cache_ready), a

_spectrum_overlay_exec_cached:
    ld hl, 2
    add hl, sp
    ld a, (hl)
    inc hl
    ld b, (hl)
ovl_args_canonical:
    ld (ovl_id), a
    ld a, b
    ld (ovl_entry_id), a

    push ix
    push iy

    call ovl_ensure_loaded
    jp c, ovl_fail
    jp ovl_call_loaded

_spectrum_assets_load:
    push ix
    push iy
    call ovl_close_overlay_file
    ld hl, asset_filename
    push hl
    pop ix
    ld b, 0x01
    ld a, '*'
    rst 8
    defb 0x9a
    jr c, assets_fail
    ld (ovl_handle), a

    ld a, (ovl_handle)
    ld ix, asset_load_addr
    ld bc, asset_load_size
    rst 8
    defb 0x9d
    jr c, assets_fail_close
    ld a, b
    cp asset_load_size_hi
    jr nz, assets_fail_close
    ld a, c
    cp asset_load_size_lo
    jr nz, assets_fail_close

    call ovl_close
    pop iy
    pop ix
    ld hl, 1
    ret

assets_fail_close:
    call ovl_close
assets_fail:
    pop iy
    pop ix
    ld hl, 0
    ret

_netchesszx_piece_set_load:
    ld a, l
    cp 3
    jr c, npsl_index_ok
    xor a
npsl_index_ok:
    ld (asset_set_index), a
    push ix
    push iy
    call ovl_close_overlay_file

    ld hl, asset_filename
    push hl
    pop ix
    ld b, 0x01
    ld a, '*'
    rst 8
    defb 0x9a
    jr c, npsl_fail
    ld (ovl_handle), a

    ld a, (asset_set_index)
    add a, a
    ld e, a
    ld d, 0
    ld hl, piece_set_offsets
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)
    ld bc, 0
    ld a, (ovl_handle)
    ld ix, 0
    ld l, 0
    rst 8
    defb 0x9f
    jr c, npsl_fail_close

    ld a, (ovl_handle)
    ld ix, asset_load_addr + asset_piece_offset
    ld bc, piece_sprite_set_size
    rst 8
    defb 0x9d
    jr c, npsl_fail_close
    ld a, b
    cp piece_sprite_set_size_hi
    jr nz, npsl_fail_close
    ld a, c
    cp piece_sprite_set_size_lo
    jr nz, npsl_fail_close

    call ovl_close
    pop iy
    pop ix
    ld hl, 1
    ret
npsl_fail_close:
    call ovl_close
npsl_fail:
    pop iy
    pop ix
    ld hl, 0
    ret

piece_set_offsets:
    DW asset_piece_offset
    DW piece_set_extra_offset
    DW piece_set_extra_offset + piece_sprite_set_size

_spectrum_assets_fatal:
    di
    ld a, 2
    out (254), a
    ld hl, assets_fatal_bitmap
    ld de, 0x4000
    ld b, 8
assets_fatal_row:
    push bc
    ld b, 4
assets_fatal_col:
    ld a, (hl)
    ld (de), a
    inc hl
    inc e
    djnz assets_fatal_col
    ld a, e
    sub 4
    ld e, a
    inc d
    pop bc
    djnz assets_fatal_row
    ld hl, 0x5800
    ld a, 0x42
    ld b, 4
assets_fatal_attr:
    ld (hl), a
    inc hl
    djnz assets_fatal_attr
assets_fatal_halt:
    jr assets_fatal_halt

_spectrum_render_about:
    ld hl, about_ovl_id + (about_render_entry * 256)
    push hl
    call _spectrum_overlay_exec
    pop bc
    ret

assets_fatal_bitmap:
    DEFB 0xf8,0x38,0xfe,0x7c
    DEFB 0x84,0x44,0x10,0x82
    DEFB 0x82,0x82,0x10,0x02
    DEFB 0x82,0xfe,0x10,0x0c
    DEFB 0x82,0x82,0x10,0x10
    DEFB 0x84,0x82,0x10,0x00
    DEFB 0xf8,0x82,0x10,0x10
    DEFB 0x00,0x00,0x00,0x00

ovl_ensure_loaded:
    ld a, (ovl_cache_ready)
    or a
    jr z, ovl_load
    ld a, (_spectrum_overlay_loaded_id)
    ld hl, ovl_id
    cp (hl)
    jr nz, ovl_load
    ret

ovl_load:
    xor a
    ld (ovl_cache_ready), a

    ld a, (ovl_file_open)
    or a
    jr nz, ovl_file_ready
    ld hl, ovl_filename
    push hl
    pop ix
    ld b, 0x01
    ld a, '*'
    rst 8
    defb 0x9a
    jr c, ovl_load_fail
    ld (ovl_handle), a
    ld a, 1
    ld (ovl_file_open), a

ovl_file_ready:
    call ovl_select_atlas_entry
    jr c, ovl_load_fail_close

ovl_read:
    ld a, (ovl_handle)
    ld ix, _overlay_code_slot
    ld bc, (ovl_load_size)
    rst 8
    defb 0x9d
    jr c, ovl_load_fail_close

    ld hl, (ovl_load_size)
    or a
    sbc hl, bc
    jr nz, ovl_load_fail_close

    ld a, (ovl_id)
    ld (_spectrum_overlay_loaded_id), a
    ld a, 1
    ld (ovl_cache_ready), a
    ret

ovl_load_fail_close:
    call ovl_close_overlay_file

ovl_load_fail:
    xor a
    ld (ovl_cache_ready), a
    ld a, ovl_invalid_id
    ld (_spectrum_overlay_loaded_id), a
    scf
    ret

ovl_call_loaded:
    ld a, (ovl_entry_id)
    ld hl, _overlay_code_slot
    cp (hl)
    jr nc, ovl_fail
    add a, a
    jr c, ovl_fail
    ld e, a
    ld d, 0
    ld hl, _overlay_code_slot + 1
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)

    push de
    ex de, hl
    ld de, _overlay_code_slot
    or a
    sbc hl, de
    jr c, ovl_bad_entry
    ld de, (ovl_load_size)
    or a
    sbc hl, de
    jr nc, ovl_bad_entry
    pop de
    pop iy
    pop ix
    ; C fastcall entries need the context in HL; native ASM entries use DE.
    ; Stack the target so both registers can carry the same context pointer.
    ld bc, ovl_return
    push bc
    push de
    ld de, _spectrum_overlay_context
    ld h, d
    ld l, e
    ; Overlay entry starts under DI and ovl_return unconditionally enables IM1.
    ; Overlay callees may re-enable interrupts (for example via frame_wait), so
    ; this is not a whole-overlay DI guarantee.
    di
    ret

ovl_return:
    ei
    ret

ovl_bad_entry:
    pop de
    jr ovl_fail

ovl_fail:
    xor a
    ld (ovl_cache_ready), a
    pop iy
    pop ix
    ld hl, 0
    ret

ovl_select_atlas_entry:
    ld a, (ovl_id)
    cp ovl_atlas_count
    jr nc, ovl_select_bad
    add a, a
    ld e, a
    ld d, 0
    ld hl, ovl_atlas_table
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    ld h, b
    ld l, c
    or a
    sbc hl, de
    ld (ovl_load_size), hl
    ld a, h
    or l
    jr z, ovl_select_bad
    ld a, h
    cp 8
    jr c, ovl_select_size_ok
    jr nz, ovl_select_bad
    ld a, l
    or a
    jr nz, ovl_select_bad
ovl_select_size_ok:
    ld bc, 0
    ld a, (ovl_handle)
    ld ix, 0
    ld l, 0
    rst 8
    defb 0x9f
    ret
ovl_select_bad:
    scf
    ret

ovl_close_overlay_file:
    ld a, (ovl_file_open)
    or a
    ret z
    call ovl_close
    xor a
    ld (ovl_file_open), a
    ret

ovl_close:
    ld a, (ovl_handle)
    rst 8
    defb 0x9b
    ret


ovl_filename:
    DEFM "SHATRANJ.OVL"
    DEFB 0

asset_filename:
    DEFM "SHATRANJ.DAT"
    DEFB 0
