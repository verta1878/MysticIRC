SECTION code_user

; overlay_loader_next.asm
;
; No-graphical Next overlay/assets loader. Same PUBLIC ABI as the esxDOS
; loader (asm/esxdos/overlay_loader.asm) but reads overlays, the DAT asset
; block and piece sets from a ZX0-compressed .nex bundle.
; At boot the 14 raw 8K pages are expanded from banks 8-10 into free banks
; 16-22; normal copies then page those raw banks through MMU slot 1.
;
; Screen is asm/spectrum/screen.asm with NETCHESSZX_NEXT_GFX: board squares,
; pieces and move markers are Next hardware sprites. Cold sprite/palette setup
; and About rendering execute from raw bundle page 39; this resident half owns
; the guarded slot-0 trampoline and bundle copies.
; _spectrum_render_about displays the separate full-screen Layer 2 image;
; the ZX ULA About payload and renderer are omitted from this target.

PUBLIC _spectrum_overlay_exec
PUBLIC _spectrum_overlay_exec_cached
PUBLIC _spectrum_assets_load
PUBLIC _spectrum_assets_fatal
PUBLIC _spectrum_render_about
PUBLIC _spectrum_render_about_off
PUBLIC _netchesszx_piece_set_load
PUBLIC _spectrum_overlay_loaded_id
PUBLIC _overlay_code_slot
PUBLIC _overlay_scratch_base
PUBLIC _spectrum_overlay_context
PUBLIC ovl_close_overlay_file
PUBLIC nextreg_read
PUBLIC nextreg_write

_spectrum_overlay_context EQU 0x5FE0
_overlay_code_slot EQU 0x6800
_overlay_scratch_base EQU 0x672B
ovl_invalid_id EQU 0xff
INCLUDE "overlay_atlas_table.asm"
INCLUDE "asm/next/graphics_bank_layout.asm"

asset_load_size       EQU 1196
about_board_size      EQU 0

; Next MMU banking. Compressed NEX banks 8-10 map as pages 16-21. The raw
; seven-bank bundle is rebuilt into banks 16-22 (pages 32-45).
next_mmu_slot0        EQU 0x50
next_mmu_slot1        EQU 0x51
next_mmu_slot2        EQU 0x52
next_compressed_page_base EQU 16
next_bundle_page_base EQU 32
next_bundle_raw_bank_base EQU 16
next_bundle_page_count EQU 14
next_bundle_header_size EQU 8 + (next_bundle_page_count * 2)
next_bundle_window    EQU 0x2000

SECTION bss_user

ovl_entry_id:           DEFS 1
ovl_id:                 DEFS 1
ovl_cache_ready:        DEFS 1
asset_set_index:        DEFS 1
_spectrum_overlay_loaded_id: DEFS 1
ovl_load_size:          DEFS 2
next_saved_mmu1:        DEFS 1
next_saved_mmu0:        DEFS 1
next_saved_mmu2:        DEFS 1
next_copy_page:         DEFS 1
next_expand_left:       DEFS 1

SECTION code_user

; SDCC/IY: two uint8 args packed into one stack word:
;   SP+2 = ovl_id, SP+3 = entry_id.
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
    call next_expand_bundle
    jr c, next_assets_load_fail
    ld hl, next_bundle_dat_offset
    ld de, asset_load_addr
    ld bc, asset_load_size
    call next_copy_bundle
    ld hl, next_graphics_bank_init_entry
    call next_graphics_bank_call
    pop iy
    pop ix
    ld hl, 1
    ret
next_assets_load_fail:
    pop iy
    pop ix
    ld hl, 0
    ret

; fastcall: piece-set index in L. Copies the 384-byte set from the bundle
; (DAT piece-set region) to the asset area right after the startup block.
_netchesszx_piece_set_load:
    ld a, l
    cp 3
    jr c, npsl_index_ok
    xor a
npsl_index_ok:
    ld (asset_set_index), a
    ld hl, next_graphics_bank_set_entry
    jp next_graphics_bank_call

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

; Show the About screen: full-screen Layer 2 image from expanded VRAM. The
; palette is staged through the overlay slot and written as 9-bit pairs; the
; pixels are displayed in place from the bundle banks (no copy).
_spectrum_render_about:
    xor a
    ld (ovl_cache_ready), a
    ld hl, next_graphics_bank_about_entry
    jp next_graphics_bank_call

; Hide the About Layer 2 screen (called when the board UI is restored).
_spectrum_render_about_off:
    ld bc, layer2_port
    xor a
    out (c), a
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

    call ovl_select_atlas_entry
    jp c, ovl_load_fail

    ld de, _overlay_code_slot
    ld bc, (ovl_load_size)
    call next_copy_bundle
    jp c, ovl_load_fail

    ld a, (ovl_id)
    ld (_spectrum_overlay_loaded_id), a
    ld a, 1
    ld (ovl_cache_ready), a
    ret

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
    ; Overlay entry starts under DI; ovl_return re-enables IM1.
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
    ex de, hl
    xor a
    ret
ovl_select_bad:
    scf
    ret

; In banking mode there is no .OVL file handle to close. Resident/overlays
; still call this symbol; keep it as a safe no-op so link/semantics match.
ovl_close_overlay_file:
    ret

; ---- Next cold graphics bank ----

; HL = one of the fixed entry addresses in graphics_bank_layout.asm. Slot 0
; replaces ROM, so IM1 must remain disabled until the original page is back.
; The cold module is constrained to resident helpers that never remap slot 0.
next_graphics_bank_call:
    ld a, i
    push af
    di
    ld a, next_mmu_slot0
    call nextreg_read
    push af
    ld a, next_graphics_bank_page
    call next_map_slot0
    ld de, next_graphics_bank_return
    push de
    jp (hl)

next_graphics_bank_return:
    pop af
    call next_map_slot0
    pop af
    jp po, next_graphics_bank_keep_di
    ei
next_graphics_bank_keep_di:
    ret

nextreg_write:
    ld bc, nextreg_select
    out (c), a
    ld bc, nextreg_data
    ld a, e
    out (c), a
    ret

; ---- Bundle copy primitive (MMU slot 1 paging) ----
; Input: HL = bundle source offset, DE = Z80 destination, BC = byte count.
; Output: CF clear always (copy cannot fail); preserves IFF (restores DI/EI).
next_copy_bundle:
    ld a, b
    or c
    ret z

    ld a, i
    push af
    di

    push bc
    push de
    push hl
    ld a, next_mmu_slot1
    call nextreg_read
    ld (next_saved_mmu1), a
    pop hl
    pop de
    pop bc

    ld a, h
    and 0xe0
    rlca
    rlca
    rlca
    add a, next_bundle_page_base
    ld (next_copy_page), a
    call next_map_copy_page

    ld a, h
    and 0x1f
    add a, next_bundle_window / 256
    ld h, a

next_copy_loop:
    ldi
    jp po, next_copy_done
    ld a, h
    cp (next_bundle_window / 256) + 0x20
    jr nz, next_copy_loop
    ld hl, next_bundle_window
    ld a, (next_copy_page)
    inc a
    ld (next_copy_page), a
    call next_map_copy_page
    jr next_copy_loop

next_copy_done:
    push bc
    push de
    push hl
    ld a, (next_saved_mmu1)
    call next_map_slot1
    pop hl
    pop de
    pop bc
    pop af
    jp po, next_copy_keep_di
    ei
next_copy_keep_di:
    xor a
    ret

next_map_copy_page:
    push bc
    push de
    push hl
    call next_map_slot1
    pop hl
    pop de
    pop bc
    ret

next_map_slot1:
    ld e, a
    ld a, next_mmu_slot1
    jp nextreg_write

nextreg_read:
    ld bc, nextreg_select
    out (c), a
    ld bc, nextreg_data
    in a, (c)
    ret

; ---- Boot expansion of the compressed NEX bundle ----
; Directory in compressed bank 8:
;   0..3 "NXZ0", 4 version=1, 5 page shift=13, 6 page count=14,
;   7 raw 16K bank base=16, then fourteen little-endian stream offsets.
; Each classic ZX0 stream expands to exactly 8K and never crosses a compressed
; 16K bank. Source occupies MMU slots 0+1; destination uses slot 2. Resident
; code starts in slot 3 at 0x7000 and the stack is high, so neither is paged.
next_expand_bundle:
    ld a, i
    push af
    di

    ld a, next_mmu_slot0
    call nextreg_read
    ld (next_saved_mmu0), a
    ld a, next_mmu_slot1
    call nextreg_read
    ld (next_saved_mmu1), a
    ld a, next_mmu_slot2
    call nextreg_read
    ld (next_saved_mmu2), a

    ld a, next_compressed_page_base
    call next_map_compressed_bank
    ld hl, 0
    ld de, next_sprite_stage
    ld bc, next_bundle_header_size
    ldir

    ld hl, next_sprite_stage
    ld a, (hl)
    cp 0x4e
    jr nz, next_expand_bad
    inc hl
    ld a, (hl)
    cp 0x58
    jr nz, next_expand_bad
    inc hl
    ld a, (hl)
    cp 0x5a
    jr nz, next_expand_bad
    inc hl
    ld a, (hl)
    cp 0x30
    jr nz, next_expand_bad
    inc hl
    ld a, (hl)
    cp 1
    jr nz, next_expand_bad
    inc hl
    ld a, (hl)
    cp 13
    jr nz, next_expand_bad
    inc hl
    ld a, (hl)
    cp next_bundle_page_count
    jr nz, next_expand_bad
    inc hl
    ld a, (hl)
    cp next_bundle_raw_bank_base
    jr nz, next_expand_bad

    ld ix, next_sprite_stage + 8
    ld a, next_bundle_page_base
    ld (next_copy_page), a
    ld a, next_bundle_page_count
    ld (next_expand_left), a
next_expand_loop:
    ld l, (ix+0)
    ld h, (ix+1)
    ld a, h
    and 0xc0
    rlca
    rlca
    add a, a
    add a, next_compressed_page_base
    call next_map_compressed_bank
    ld a, h
    and 0x3f
    ld h, a

    ld a, (next_copy_page)
    call next_map_slot2
    ld de, 0x4000
    call next_dzx0_standard
    ld a, d
    cp 0x60
    jr nz, next_expand_bad
    ld a, e
    or a
    jr nz, next_expand_bad

    inc ix
    inc ix
    ld a, (next_copy_page)
    inc a
    ld (next_copy_page), a
    ld a, (next_expand_left)
    dec a
    ld (next_expand_left), a
    jr nz, next_expand_loop
    jr next_expand_restore

next_expand_bad:
    ld a, 1
    ld (next_expand_left), a
next_expand_restore:
    ld a, (next_saved_mmu2)
    call next_map_slot2
    ld a, (next_saved_mmu1)
    call next_map_slot1
    ld a, (next_saved_mmu0)
    call next_map_slot0
    pop af
    jp po, next_expand_keep_di
    ei
next_expand_keep_di:
    ld a, (next_expand_left)
    or a
    ret z
    scf
    ret

; A = first MMU page of a compressed 16K bank. Maps both source slots.
next_map_compressed_bank:
    push af
    call next_map_slot0
    pop af
    inc a
    jp next_map_slot1

next_map_slot0:
    ld e, a
    ld a, next_mmu_slot0
    jp nextreg_write

next_map_slot2:
    ld e, a
    ld a, next_mmu_slot2
    jp nextreg_write

; Classic ZX0 standard decoder by Einar Saukas (69 bytes). HL=source,
; DE=destination. Uses main registers only and preserves IX/IY.
next_dzx0_standard:
    ld bc, 0xffff
    push bc
    inc bc
    ld a, 0x80
next_dzx0_literals:
    call next_dzx0_elias
    ldir
    add a, a
    jr c, next_dzx0_new_offset
    call next_dzx0_elias
next_dzx0_copy:
    ex (sp), hl
    push hl
    add hl, de
    ldir
    pop hl
    ex (sp), hl
    add a, a
    jr nc, next_dzx0_literals
next_dzx0_new_offset:
    call next_dzx0_elias
    ex af, af'
    pop af
    xor a
    sub c
    ret z
    ld b, a
    ex af, af'
    ld c, (hl)
    inc hl
    rr b
    rr c
    push bc
    ld bc, 1
    call nc, next_dzx0_elias_backtrack
    inc bc
    jr next_dzx0_copy
next_dzx0_elias:
    inc c
next_dzx0_elias_loop:
    add a, a
    jr nz, next_dzx0_elias_skip
    ld a, (hl)
    inc hl
    rla
next_dzx0_elias_skip:
    ret c
next_dzx0_elias_backtrack:
    add a, a
    rl c
    rl b
    jr next_dzx0_elias_loop
