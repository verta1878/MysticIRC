#ifndef NETCHESSZX_SPECTRUM_SESSION_PING_H
#define NETCHESSZX_SPECTRUM_SESSION_PING_H

#include <stdint.h>

#define NETCHESSZX_SESSION_PING_NONE 0u
#define NETCHESSZX_SESSION_PING_SEND 1u
#define NETCHESSZX_SESSION_PING_LOST 2u

/* Golden mapping for NextReg 0x05 bit 2 in next_uart.asm. */
#define NETCHESSZX_NEXT_DIRECT_IDLE_TICKS(peripheral_1) \
    ((uint8_t)(((peripheral_1) & 0x04u) != 0u ? 90u : 75u))

typedef struct netchesszx_session_ping {
    uint8_t idle_ticks;
    uint8_t misses;
    /* DIRECT: nonzero also counts 3-second windows while a guest PING is
       pending or a host passively waits; no extra timer state is needed. */
    uint8_t direct_pending;
} netchesszx_session_ping_t;

void netchesszx_session_ping_reset(netchesszx_session_ping_t *ping);
#define netchesszx_session_ping_rx_data netchesszx_session_ping_reset
#define netchesszx_session_ping_rx_direct_peer_ping netchesszx_session_ping_reset
#define netchesszx_session_ping_rx_mqtt_pingresp netchesszx_session_ping_reset
uint8_t netchesszx_session_ping_timeout(netchesszx_session_ping_t *ping,
                                        uint8_t is_mqtt,
                                        uint8_t can_send_direct_ping);
void netchesszx_session_ping_sent(netchesszx_session_ping_t *ping,
                                  uint8_t is_mqtt);
uint8_t netchesszx_session_ping_ack(netchesszx_session_ping_t *ping,
                                    uint8_t is_mqtt);

#endif
