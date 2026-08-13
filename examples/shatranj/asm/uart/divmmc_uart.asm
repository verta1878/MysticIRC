; divmmc_uart.asm
;
; UART backend for ESP connected through a divMMC/divTIESUS
; ZX-Uno compatible UART.
;
; Keep this close to SpectalkZX's proven SDCC/IY backend. Shatranj exposes
; ready/read wrappers, so those wrappers cache one byte around uartRead.

SECTION code_user

EXTERN _spectrum_frame_wait
PUBLIC _net_uart_init
PUBLIC _net_uart_send
PUBLIC _net_uart_read
PUBLIC _net_uart_ready
PUBLIC _net_uart_ready_fast
PUBLIC uartRead

UART_DATA_REG     EQU 0xC6
UART_STAT_REG     EQU 0xC7
UART_BYTE_RECEIVED EQU 0x80
UART_BYTE_SENDING EQU 0x40
ZXUNO_ADDR        EQU 0xFC3B

SECTION bss_user

_is_recv:    DEFS 1
_rx_byte:    DEFS 1

SECTION code_user

; Internal helper: uartRead
;   Returns: CF=1 and A=byte if data available
;            CF=0 if nothing to read

uartRead:
    ld bc, ZXUNO_ADDR
    ld a, UART_STAT_REG
    out (c), a

    inc b
    in a, (c)
    add a, a
    ret nc

    dec b
    ld a, UART_DATA_REG
    out (c), a

    inc b
    in a, (c)       ; IN preserves CF from the RX-ready status test.
    ret

_net_uart_init:
    xor a
    ld (_is_recv), a
    ld (_rx_byte), a

    ; Prime status/data register reads, as in SpectalkZX.
    ld bc, ZXUNO_ADDR
    ld a, UART_STAT_REG
    out (c), a
    inc b
    in a, (c)

    dec b
    ld a, UART_DATA_REG
    out (c), a
    inc b
    in a, (c)

    ld b, 10
uartInit_wait:
    push bc
    call uartRead
    call _spectrum_frame_wait
    pop bc
    djnz uartInit_wait

    ld de, 0x0200
uartInit_flush:
    call uartRead
    dec de
    ld a, d
    or e
    jr nz, uartInit_flush

    ret

; _net_uart_send
;   fastcall: byte in L

_net_uart_send:
    ld bc, ZXUNO_ADDR
    ld a, UART_STAT_REG
    out (c), a

    inc b
    ld d, 0
uartSend_wait_tx:
    in a, (c)
    and UART_BYTE_SENDING
    jr z, uartSend_ready_tx
    dec d
    jr nz, uartSend_wait_tx
    ld l, 1              ; timed out: report so caller retries, not silent drop
    ret

uartSend_ready_tx:
    dec b
    ld a, UART_DATA_REG
    out (c), a

    inc b
    out (c), l
    ld l, 0             ; sent
    ret

; _net_uart_ready
;   Returns L=1 if one byte is available, else L=0

_net_uart_ready:
    ld a, (_is_recv)
    or a
    jr nz, uartReady_yes

    call uartRead
    jr nc, uartReady_no

    ld (_rx_byte), a
    ld a, 1
    ld (_is_recv), a

uartReady_yes:
    ld l, a
    ret

uartReady_no:
    ld l, 0
    ret

DEFC _net_uart_ready_fast = _net_uart_ready

; _net_uart_read
;   Returns L=byte if available, else L=0

_net_uart_read:
    ld a, (_is_recv)
    or a
    jr z, uartRead_direct

    ld a, (_rx_byte)
    ld l, a
    xor a
    ld (_is_recv), a
    ret

uartRead_direct:
    call uartRead
    jr nc, uartRead_none
    ld l, a
    ret

uartRead_none:
    ld l, 0
    ret
