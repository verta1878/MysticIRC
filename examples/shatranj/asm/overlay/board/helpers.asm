SECTION code_user

PUBLIC _abs_delta
PUBLIC _piece_side
PUBLIC _rules_piece_from_char
PUBLIC _promotion_piece

_abs_delta:
    ; SDCC/IY packed uint8 args: a@sp+2, b@sp+3.
    ld hl, 3
    add hl, sp
    ld a, (hl)
    dec hl
    sub (hl)
    jr nc, abs_done
    neg
abs_done:
    ld l, a
    ld h, 0
    ret

_piece_side:
    ; piece@sp+2.
    ld hl, 2
    add hl, sp
    ld a, (hl)
    cp 'a'
    jr c, ps_white
    cp 'z' + 1
    jr nc, ps_white
    ld hl, 1
    ret
ps_white:
    ld hl, 0
    ret

_rules_piece_from_char:
    ; piece@sp+2.
    ld hl, 2
    add hl, sp
    ld a, (hl)
    ld hl, 1
    cp 'P'
    ret z
    inc l
    cp 'N'
    ret z
    inc l
    cp 'B'
    ret z
    inc l
    cp 'R'
    ret z
    inc l
    cp 'Q'
    ret z
    inc l
    cp 'K'
    ret z
    ld hl, -1
    cp 'p'
    ret z
    dec l
    cp 'n'
    ret z
    dec l
    cp 'b'
    ret z
    dec l
    cp 'r'
    ret z
    dec l
    cp 'q'
    ret z
    dec l
    cp 'k'
    ret z
    ld hl, 0
    ret

_promotion_piece:
    ; SDCC/IY packed uint8 args: pawn@sp+2, promo@sp+3.
    ld hl, 3
    add hl, sp
    ld a, (hl)
    or a
    jr nz, pp_have_promo
    ld a, 'q'
pp_have_promo:
    ld e, a
    dec hl
    ld a, (hl)
    cp 'A'
    jr c, pp_black
    cp 'Z' + 1
    jr nc, pp_black
    ld a, e
    cp 'a'
    jr c, pp_done
    cp 'z' + 1
    jr nc, pp_done
    sub 'a' - 'A'
    jr pp_done
pp_black:
    ld a, e
    cp 'A'
    jr c, pp_done
    cp 'Z' + 1
    jr nc, pp_done
    add a, 'a' - 'A'
pp_done:
    ld l, a
    ld h, 0
    ret
