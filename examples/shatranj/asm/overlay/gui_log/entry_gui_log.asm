SECTION code_user

PUBLIC _gui_log_add_move_ovl_entry
PUBLIC _gui_log_add_chat_ovl_entry
PUBLIC _gui_log_notify_msg_ovl_entry
PUBLIC _gui_log_remove_last_move_ovl_entry
PUBLIC _chat_clean_char
PUBLIC _chat_word_len
PUBLIC _chat_copy_clock_line
PUBLIC _gui_log_parse_ply
PUBLIC _clear_move_line
PUBLIC _clear_log_line
PUBLIC _scroll_move_lines
PUBLIC _scroll_chat_lines
PUBLIC _move_line_at
PUBLIC _log_line_at

EXTERN _gui_log_add_move_ovl
EXTERN _gui_log_add_chat_ovl
EXTERN _gui_log_notify_msg_ovl
EXTERN _gui_log_remove_last_move_ovl

chat_clock_line_src EQU 0x5e92

    DEFB 4
    DW _gui_log_add_move_ovl_entry
    DW _gui_log_add_chat_ovl_entry
    DW _gui_log_notify_msg_ovl_entry
    DW _gui_log_remove_last_move_ovl_entry

DEFC _gui_log_add_move_ovl_entry = _gui_log_add_move_ovl

DEFC _gui_log_add_chat_ovl_entry = _gui_log_add_chat_ovl

DEFC _gui_log_notify_msg_ovl_entry = _gui_log_notify_msg_ovl

DEFC _gui_log_remove_last_move_ovl_entry = _gui_log_remove_last_move_ovl

_chat_clean_char:
    ld a, l
    cp ' '
    jr c, ccc_space
    cp '~' + 1
    jr c, ccc_done
ccc_space:
    ld a, ' '
ccc_done:
    ld l, a
    ret

_chat_word_len:
    ld b, 24
    ld c, 0
cwl_loop:
    ld a, (hl)
    or a
    jr z, cwl_done
    cp ' '
    jr z, cwl_done
    inc hl
    inc c
    djnz cwl_loop
cwl_done:
    ld l, c
    ret

_chat_copy_clock_line:
    inc hl
    ex de, hl
    ld hl, chat_clock_line_src
    ld bc, 6
    ldir
    ret

_gui_log_parse_ply:
    ld b, h
    ld c, l
    ld hl, 0
glpp_loop:
    ld a, (bc)
    sub '0'
    jr c, glpp_done
    cp 10
    jr nc, glpp_done
    inc bc
    add hl, hl
    ld d, h
    ld e, l
    add hl, hl
    add hl, hl
    add hl, de
    ld e, a
    ld d, 0
    add hl, de
    jr glpp_loop
glpp_done:
    ret

_clear_move_line:
    ld a, ' '
    ld b, 32
    jr cll_loop

_clear_log_line:
    ld b, 28
    xor a
cll_loop:
    ld (hl), a
    inc hl
    djnz cll_loop
    ret

_scroll_move_lines:
    push hl
    pop de
    ld bc, 32
    add hl, bc
    ld bc, 192
    ldir
    ret

_scroll_chat_lines:
    ld bc, 224

scroll_log_lines_count:
    push bc
    ld d, h
    ld e, l
    ld bc, 28
    add hl, bc
    pop bc
    ldir
    ret

_move_line_at:
    ld a, 32
    jr line_at

_log_line_at:
    ld a, 28
line_at:
    ld hl, 4
    add hl, sp
    ld b, (hl)
    ld hl, 2
    add hl, sp
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl
    ld e, a
    ld d, 0
line_at_loop:
    ld a, b
    or a
    ret z
    add hl, de
    djnz line_at_loop
    ret
