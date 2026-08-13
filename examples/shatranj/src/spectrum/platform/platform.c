#include "spectrum/platform/platform.h"
#include "spectrum/platform/uart.h"
#include "spectrum/lowram_map.h"

extern void net_uart_init(void);
extern uint8_t net_uart_send(uint8_t c) NETCHESSZX_FASTCALL;
extern uint8_t net_uart_ready(void);
extern uint8_t net_uart_read(void);
#ifdef NETCHESSZX_NEXT
extern void net_uart_hard_reset(void);
#endif

#ifdef NETCHESSZX_HOST_TEST
void spectrum_frame_wait(void)
{
}
#else
void spectrum_frame_wait(void)
{
    /* ROM IM1 expects IY=$5C3A while interrupts are enabled. The sdcc_iy
       build keeps generated C off IY; handwritten ASM that borrows IY must
       run under DI and restore it before any EI path. */
#asm
    EXTERN _spectrum_input_frame_tick
    ei
    halt
    push af
    push bc
    push de
    push hl
    call _spectrum_input_frame_tick
    pop hl
    pop de
    pop bc
    pop af
#endasm
}
#endif

/* RX ring under the UART wrappers. spectrum_uart_background_pump() stockpiles
   HW bytes here while the app is blocked (notices, esxDOS ops, piece reveal)
   so a DIRECT +IPD burst is not lost to the small HW FIFO. Readers drain the
   ring first via the wrappers below, so byte order is preserved and every
   consumer (DIRECT overlay, esp_at line parser, MQTT stream) is covered
   without changes. Lives in the reclaimed printer buffer (see lowram_map.h)
   so it costs no BSS; indices are uint8_t, so 256 is the ceiling. */
#define SPECTRUM_UART_RING_SIZE NETCHESSZX_LOWRAM_UART_RING_SIZE
#ifdef NETCHESSZX_FIXED_LOW_RAM
static __at(NETCHESSZX_LOWRAM_UART_RING_ADDR) uint8_t uart_ring[SPECTRUM_UART_RING_SIZE];
#else
static uint8_t uart_ring[SPECTRUM_UART_RING_SIZE];
#endif
static uint8_t uart_ring_head;
static uint8_t uart_ring_tail;

#define uart_ring_next(i) ((uint8_t)(((uint8_t)(i) + 1u) & (SPECTRUM_UART_RING_SIZE - 1u)))

void spectrum_uart_background_pump(void)
{
    uint8_t next;

    while (net_uart_ready()) {
        next = uart_ring_next(uart_ring_tail);
        if (next == uart_ring_head) {
            break; /* ring full: leave the rest in the HW FIFO */
        }
        uart_ring[uart_ring_tail] = net_uart_read();
        uart_ring_tail = next;
    }
}

void spectrum_uart_init(void)
{
    uart_ring_head = 0u;
    uart_ring_tail = 0u;
    net_uart_init();
}

#ifdef NETCHESSZX_NEXT
void spectrum_uart_hard_reset(void)
{
    net_uart_hard_reset();
}
#endif

void spectrum_uart_flush(uint16_t frames) NETCHESSZX_FASTCALL
{
    uint16_t cap = 2048u;

    uart_ring_head = uart_ring_tail;
    while (frames-- != 0u && cap != 0u) {
        while (net_uart_ready() && cap != 0u) {
            (void)net_uart_read();
            --cap;
        }
        spectrum_frame_wait();
    }
}

/* net_uart_send now returns nonzero on a bounded TX-busy timeout (ESP
   servicing an inbound burst) instead of silently dropping the byte. Retry a
   few times before giving up so transient contention doesn't desync the AT/
   MQTT stream; the cap keeps a truly dead ESP from stalling the send. */
static uint8_t uart_send_byte(uint8_t c) NETCHESSZX_FASTCALL
{
    uint8_t tries = 4u;

    do {
        if (net_uart_send(c) == 0u) {
            return 1u;
        }
    } while (--tries != 0u);
    return 0u;
}

uint8_t spectrum_uart_send_string(const char *s) NETCHESSZX_FASTCALL
{
    while (*s != '\0') {
        if (!uart_send_byte((uint8_t)*s++)) {
            return 0u;
        }
    }
    return 1u;
}

uint8_t spectrum_uart_send_bytes(const uint8_t *data, uint8_t len)
{
    while (len-- != 0u) {
        if (!uart_send_byte(*data++)) {
            return 0u;
        }
    }
    return 1u;
}

uint8_t spectrum_uart_send_crlf(void)
{
    if (!uart_send_byte('\r')) {
        return 0u;
    }
    return uart_send_byte('\n');
}

uint8_t spectrum_uart_ready(void)
{
    if (uart_ring_head != uart_ring_tail) {
        return 1u;
    }
    return net_uart_ready();
}

uint8_t spectrum_uart_read(void)
{
    uint8_t c;

    if (uart_ring_head != uart_ring_tail) {
        c = uart_ring[uart_ring_head];
        uart_ring_head = uart_ring_next(uart_ring_head);
        return c;
    }
    return net_uart_read();
}
