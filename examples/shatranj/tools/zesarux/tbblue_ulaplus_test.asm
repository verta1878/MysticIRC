; Minimal reproduction for chernandezba/zesarux PR #12.
;
; Load as a TBBlue / ZX Spectrum Next NEX:
;   - Stock ZEsarUX 13.0 shows classic ULA colours and FLASH.
;   - With PR #12, the top half is red and the bottom half is green,
;     both remaining stable.
;
; Attribute 0x81 selects ULA+ CLUT 2 INK 1: palette entry 225.
; Attribute 0x8a selects ULA+ CLUT 2 INK 2: palette entry 226.
; No UART, network, storage, or input is used.

SECTION code_user

PUBLIC _main

_main:
    di

    nextreg 0x43, 0x00
    nextreg 0x68, 0x08

    nextreg 0x40, 225
    nextreg 0x41, 0xe0
    nextreg 0x40, 226
    nextreg 0x41, 0x1c

    xor a
    out (0xfe), a

    ld hl, 0x4000
    ld de, 0x4001
    ld bc, 6143
    ld (hl), 0xff
    ldir

    ld hl, 0x5800
    ld de, 0x5801
    ld bc, 383
    ld (hl), 0x81
    ldir

    ld hl, 0x5980
    ld de, 0x5981
    ld bc, 383
    ld (hl), 0x8a
    ldir

hang:
    jr hang
