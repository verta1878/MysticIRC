SECTION code_user

PUBLIC _board_apply_ovl_entry
PUBLIC _board_snapshot_save_ovl_entry
PUBLIC _board_snapshot_restore_ovl_entry
PUBLIC _board_undo_restore_ovl_entry
EXTERN _board_apply_trusted_ovl
EXTERN _board_snapshot_restore_ovl
EXTERN _board_undo_restore_ovl
EXTERN _side_to_move
EXTERN _castle_rights
EXTERN _ep_square

NETCHESSZX_CHESS_BOARD EQU 0x5f60

    DEFB 4
    DW _board_apply_ovl_entry
    DW _board_snapshot_save_ovl_entry
    DW _board_snapshot_restore_ovl_entry
    DW _board_undo_restore_ovl_entry

DEFC _board_apply_ovl_entry = _board_apply_trusted_ovl

_board_snapshot_save_ovl_entry:
    ; DE = overlay context. Copy the 64 cells and three state bytes directly;
    ; this is the same overlay-local ABI as the former SDCC loop, but smaller.
    ex de, hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    ld hl, NETCHESSZX_CHESS_BOARD
    ld bc, 64
    ldir
    ld a, (_side_to_move)
    ld (de), a
    inc de
    ld a, (_castle_rights)
    ld (de), a
    inc de
    ld a, (_ep_square)
    ld (de), a
    ld hl, 1
    ret

DEFC _board_snapshot_restore_ovl_entry = _board_snapshot_restore_ovl

DEFC _board_undo_restore_ovl_entry = _board_undo_restore_ovl
