#include "spectrum/session/ping.h"

#ifdef NETCHESSZX_HOST_SESSION_TEST
void netchesszx_host_session_observe_ping_reset(
    netchesszx_session_ping_t *ping);
#define HOST_SESSION_OBSERVE_PING_RESET(ping) \
    netchesszx_host_session_observe_ping_reset(ping)
#else
#define HOST_SESSION_OBSERVE_PING_RESET(ping) ((void)0)
#endif

#define MQTT_PING_MISSES_MAX 4u
#ifdef NETCHESSZX_NEXT
extern uint8_t net_uart_direct_idle_ticks;
#define DIRECT_IDLE_PING_TICKS net_uart_direct_idle_ticks
#else
#define DIRECT_IDLE_PING_TICKS 75u
#endif
#define MQTT_IDLE_PING_TICKS \
    ((uint8_t)(DIRECT_IDLE_PING_TICKS == 90u ? 144u : 120u))
#define DIRECT_PING_WAIT_WINDOWS 3u
#define DIRECT_PING_MISSES_MAX 2u

void netchesszx_session_ping_reset(netchesszx_session_ping_t *ping)
{
    ping->idle_ticks = 0u;
    ping->misses = 0u;
    ping->direct_pending = 0u;
    HOST_SESSION_OBSERVE_PING_RESET(ping);
}

uint8_t netchesszx_session_ping_timeout(netchesszx_session_ping_t *ping,
                                        uint8_t is_mqtt,
                                        uint8_t can_send_direct_ping)
{
    ++ping->idle_ticks;
    if (ping->idle_ticks < (is_mqtt ? MQTT_IDLE_PING_TICKS :
                                      DIRECT_IDLE_PING_TICKS)) {
        return NETCHESSZX_SESSION_PING_NONE;
    }

    ping->idle_ticks = 0u;
    if (is_mqtt) {
        return ping->misses >= MQTT_PING_MISSES_MAX
            ? NETCHESSZX_SESSION_PING_LOST
            : NETCHESSZX_SESSION_PING_SEND;
    }
    if (!can_send_direct_ping) {
        ++ping->direct_pending;
        if (ping->direct_pending < DIRECT_PING_WAIT_WINDOWS) {
            return NETCHESSZX_SESSION_PING_NONE;
        }
        ping->direct_pending = 0u;
        ++ping->misses;
        return ping->misses >= DIRECT_PING_MISSES_MAX
            ? NETCHESSZX_SESSION_PING_LOST
            : NETCHESSZX_SESSION_PING_NONE;
    }
    if (ping->direct_pending == 0u) {
        return NETCHESSZX_SESSION_PING_SEND;
    }
    if (ping->direct_pending < DIRECT_PING_WAIT_WINDOWS) {
        ++ping->direct_pending;
        return NETCHESSZX_SESSION_PING_NONE;
    }
    ping->direct_pending = 0u;
    if (ping->misses >= DIRECT_PING_MISSES_MAX) {
        return NETCHESSZX_SESSION_PING_LOST;
    }
    return NETCHESSZX_SESSION_PING_SEND;
}

void netchesszx_session_ping_sent(netchesszx_session_ping_t *ping,
                                  uint8_t is_mqtt)
{
    if (is_mqtt) {
        ++ping->misses;
        return;
    }
    ping->direct_pending = 1u;
    ++ping->misses;
}

uint8_t netchesszx_session_ping_ack(netchesszx_session_ping_t *ping,
                                    uint8_t is_mqtt)
{
    if (is_mqtt) {
        return 1u;
    }
    if (ping->direct_pending) {
        ping->misses = 0u;
        ping->direct_pending = 0u;
        return 1u;
    }
    return 0u;
}
