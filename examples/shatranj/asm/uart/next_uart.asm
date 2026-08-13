; next_uart.asm
;
; UART backend for ESP connected to the ZX Spectrum Next internal UART.
; Exposes the same z88dk/SDCC ABI as divmmc_uart.asm:
;   _net_uart_init / _net_uart_send / _net_uart_read
;   _net_uart_ready / _net_uart_ready_fast
;
; Ports (SpecNext):
;   0x133B = TX / status read (bit0=RX ready, bit1=TX busy)
;   0x143B = RX read / baud divisor write
;   0x153B = UART select (0x30 = ESP and write baud prescaler high bits)
;   0x163B = frame format
;   nextreg 0x243B/0x253B = register access
;   0x11 = video timing (0..7), 0x05 bit 2 = 60 Hz

SECTION code_user

PUBLIC _net_uart_init
PUBLIC _net_uart_send
PUBLIC _net_uart_read
PUBLIC _net_uart_ready
PUBLIC _net_uart_ready_fast
PUBLIC _net_uart_direct_idle_ticks
PUBLIC _net_uart_hard_reset

UART_TX            EQU 0x133B
UART_RX            EQU 0x143B
UART_SEL           EQU 0x153B
UART_FRAME         EQU 0x163B
UART_SET_BAUD      EQU 0x143B
UART_GET_STATUS    EQU 0x133B
UART_TX_BUSY       EQU 0x02
UART_RX_DATA_READY EQU 0x01
UART_SEL_ESP_BAUD_HI0 EQU 0x30
UART_FRAME_RESET_8N1  EQU 0x98
UART_FRAME_8N1        EQU 0x18
NEXTREG_SELECT     EQU 0x243B
NEXTREG_RESET      EQU 0x02
NEXTREG_DATA       EQU 0x253B
NEXTREG_VIDEO_TIMING EQU 0x11
NEXTREG_PERIPHERAL_1 EQU 0x05
NEXT_TIMING_COUNT  EQU 8
NEXT_TIMING_DEFAULT EQU 0       ; base VGA timing, safe fallback

SECTION data_user

; Two-frame DIRECT read timeouts per three seconds: 75 at 50 Hz, 90 at
; 60 Hz. net_uart_init refreshes this from nextreg 0x05 before sessions run.
; The golden mapping lives in test_next_refresh_rate_mapping().
_net_uart_direct_idle_ticks: DEFB 75

SECTION bss_user

_is_recv: DEFS 1
_rx_byte: DEFS 1

SECTION code_user

_net_uart_init:
    xor a
    ld (_is_recv), a
    ; _rx_byte is invalid while _is_recv is zero and is overwritten before
    ; that flag becomes nonzero, so clearing the cached byte is unnecessary.

    ld bc, UART_SEL
    ld a, UART_SEL_ESP_BAUD_HI0
    out (c), a

    inc b                       ; UART_FRAME = UART_SEL + 0x0100
    ld a, UART_FRAME_RESET_8N1
    out (c), a
    ld a, UART_FRAME_8N1
    out (c), a

    ld hl, baud_table
    jp next_uart_set_baud_from_table

; fastcall: byte in L. Returns L=0 sent, L=1 timed out.
; Bounded wait (256 polls, ~mirrors divmmc_uart) so a stuck/unplugged ESP
; cannot freeze the app forever on a self-loop; caller retries/aborts.
_net_uart_send:
    ld bc, UART_GET_STATUS
    ld d, 0
next_uart_send_wait:
    in a, (c)
    and UART_TX_BUSY
    jr z, next_uart_send_ready
    dec d
    jr nz, next_uart_send_wait
    ld l, 1              ; timed out: report, do not hang
    ret
next_uart_send_ready:
    out (c), l
    ld l, 0
    ret

; CF=1 and A=byte if available; CF=0 if no byte.
next_uart_raw_read:
    ld bc, UART_GET_STATUS
    in a, (c)
    rrca
    ret nc
    ld bc, UART_RX
    in a, (c)
    scf
    ret

_net_uart_ready:
    ld a, (_is_recv)
    or a
    jr nz, next_uart_ready_yes

    call next_uart_raw_read
    jr nc, next_uart_ready_no

    ld (_rx_byte), a
    ld a, 1
    ld (_is_recv), a

next_uart_ready_yes:
    ld l, a
    ret

next_uart_ready_no:
    ld l, 0
    ret

DEFC _net_uart_ready_fast = _net_uart_ready

_net_uart_read:
    ld a, (_is_recv)
    or a
    jr z, next_uart_read_direct

    ld a, (_rx_byte)
    ld l, a
    xor a
    ld (_is_recv), a
    ret

next_uart_read_direct:
    call next_uart_raw_read
    jr nc, next_uart_read_none
    ld l, a
    ret

next_uart_read_none:
    ld l, 0
    ret

; Last-resort ESP reset through NextReg 0x02 bit 7.
; Requires frame interrupts and returns with interrupts enabled.
_net_uart_hard_reset:
    di
    ld bc, NEXTREG_SELECT
    ld a, NEXTREG_RESET
    out (c), a
    ld bc, NEXTREG_DATA
    ld a, 0x80
    out (c), a
    ei
    ld b, 25
next_uart_reset_hold:
    halt
    djnz next_uart_reset_hold

    di
    ld bc, NEXTREG_SELECT
    ld a, NEXTREG_RESET
    out (c), a
    ld bc, NEXTREG_DATA
    xor a
    out (c), a
    ei
    ld b, 180
next_uart_reset_boot:
    halt
    djnz next_uart_reset_boot
    ret

; Reads nextreg 0x11 (video timing index 0..7) and writes the matching
; 115200 baud divisor from baud_table to the UART baud register.
; Index out of range (>= NEXT_TIMING_COUNT, e.g. garbage from a buggy or
; future nextreg) is CLAMPED to NEXT_TIMING_DEFAULT (mode 0) instead of
; wrapping, so a bad index never silently selects a wrong-but-valid baud.
next_uart_set_baud_from_table:
    ld a, i
    push af
    di
    ld bc, NEXTREG_SELECT
    ld a, NEXTREG_VIDEO_TIMING
    out (c), a
    ld bc, NEXTREG_DATA
    in a, (c)
    ld e, a
    dec b
    ld a, NEXTREG_PERIPHERAL_1
    out (c), a
    inc b
    in a, (c)
    ld d, a
    pop af
    jp po, next_uart_keep_di
    ei
next_uart_keep_di:
    ld a, e
    cp NEXT_TIMING_COUNT
    jr c, next_uart_index_valid
    ld a, NEXT_TIMING_DEFAULT
next_uart_index_valid:
    ld e, a
    bit 2, d
    ld a, 75               ; LD preserves the Z flag produced by BIT
    jr z, next_uart_store_idle_ticks
    ld a, 90
next_uart_store_idle_ticks:
    ld (_net_uart_direct_idle_ticks), a
    ld a, e
    add a, a
    ld e, a
    ld d, 0
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl

    ld bc, UART_SET_BAUD
    ld a, l
    and 0x7F
    out (c), a
    ld a, h
    rl l
    rla
    or 0x80
    out (c), a
    ret

; 115200 baud divisors indexed by nextreg 0x11 video timing mode (0..7).
; Derivation: divisor = uart_clk / baud, where uart_clk tracks the Next
; master clock per video timing. Mode 0 anchor: 28000000 / 115200 = 243.05
; -> 243 (exact). Subsequent entries follow the per-mode uart_clk; confirm
; each against the SpecNext UART spec during HW validation (Inc 3).
;   idx 0: base VGA timing   -> 243
;   idx 1: VGA setting 1     -> 248
;   idx 2: VGA setting 2     -> 256
;   idx 3: VGA setting 3     -> 260
;   idx 4: VGA setting 4     -> 269
;   idx 5: VGA setting 5     -> 278
;   idx 6: VGA setting 6     -> 286
;   idx 7: HDMI timing       -> 234
baud_table:
    DEFW 243, 248, 256, 260, 269, 278, 286, 234
