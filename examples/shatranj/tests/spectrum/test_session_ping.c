#include "spectrum/session/ping.h"

#include <stdio.h>
#include <stdlib.h>

#ifdef NETCHESSZX_NEXT
uint8_t net_uart_direct_idle_ticks;
#endif

static uint8_t test_direct_idle_ticks = 75u;
#define TEST_DIRECT_PING_WAIT_WINDOWS 3u

static void check(int condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void tick(netchesszx_session_ping_t *ping, uint8_t is_mqtt,
                 uint8_t can_send_direct_ping, uint8_t count,
                 uint8_t expected)
{
    uint8_t rc = NETCHESSZX_SESSION_PING_NONE;

    while (count-- != 0u) {
        rc = netchesszx_session_ping_timeout(ping, is_mqtt,
                                             can_send_direct_ping);
    }
    check(rc == expected, "unexpected timeout event");
}

static void test_direct_ping_ack(void)
{
    netchesszx_session_ping_t ping;

    netchesszx_session_ping_reset(&ping);
    tick(&ping, 0u, 1u, (uint8_t)(test_direct_idle_ticks - 1u),
         NETCHESSZX_SESSION_PING_NONE);
    tick(&ping, 0u, 1u, 1u, NETCHESSZX_SESSION_PING_SEND);
    netchesszx_session_ping_sent(&ping, 0u);
    check(netchesszx_session_ping_ack(&ping, 0u), "accept direct ack");
    tick(&ping, 0u, 1u, test_direct_idle_ticks,
         NETCHESSZX_SESSION_PING_SEND);
}

static void test_direct_loss_after_misses(void)
{
    netchesszx_session_ping_t ping;
    uint8_t window;

    netchesszx_session_ping_reset(&ping);
    tick(&ping, 0u, 1u, test_direct_idle_ticks,
         NETCHESSZX_SESSION_PING_SEND);
    netchesszx_session_ping_sent(&ping, 0u);
    for (window = 1u; window < TEST_DIRECT_PING_WAIT_WINDOWS; ++window) {
        tick(&ping, 0u, 1u, test_direct_idle_ticks,
             NETCHESSZX_SESSION_PING_NONE);
    }
    tick(&ping, 0u, 1u, test_direct_idle_ticks,
         NETCHESSZX_SESSION_PING_SEND);
    netchesszx_session_ping_sent(&ping, 0u);
    for (window = 1u; window < TEST_DIRECT_PING_WAIT_WINDOWS; ++window) {
        tick(&ping, 0u, 1u, test_direct_idle_ticks,
             NETCHESSZX_SESSION_PING_NONE);
    }
    tick(&ping, 0u, 1u, test_direct_idle_ticks,
         NETCHESSZX_SESSION_PING_LOST);
}

static void test_direct_passive_host_loss(void)
{
    netchesszx_session_ping_t ping;
    uint8_t window;

    netchesszx_session_ping_reset(&ping);
    for (window = 1u;
         window < (uint8_t)(2u * TEST_DIRECT_PING_WAIT_WINDOWS);
         ++window) {
        tick(&ping, 0u, 0u, test_direct_idle_ticks,
             NETCHESSZX_SESSION_PING_NONE);
    }
    tick(&ping, 0u, 0u, test_direct_idle_ticks,
         NETCHESSZX_SESSION_PING_LOST);
}

static void test_direct_peer_ping_resets_pending(void)
{
    netchesszx_session_ping_t ping;

    netchesszx_session_ping_reset(&ping);
    ping.idle_ticks = (uint8_t)(test_direct_idle_ticks - 1u);
    ping.misses = 2u;
    ping.direct_pending = TEST_DIRECT_PING_WAIT_WINDOWS;
    netchesszx_session_ping_rx_direct_peer_ping(&ping);
    check(ping.idle_ticks == 0u, "peer ping resets idle");
    check(ping.misses == 0u, "peer ping resets misses");
    check(ping.direct_pending == 0u, "peer ping clears pending");
}

static void test_mqtt_loss_after_misses(uint8_t idle_ticks)
{
    netchesszx_session_ping_t ping;
    uint8_t i;

    netchesszx_session_ping_reset(&ping);
    for (i = 0u; i != 4u; ++i) {
        tick(&ping, 1u, 1u, idle_ticks, NETCHESSZX_SESSION_PING_SEND);
        netchesszx_session_ping_sent(&ping, 1u);
    }
    tick(&ping, 1u, 1u, idle_ticks, NETCHESSZX_SESSION_PING_LOST);
}

static void test_next_refresh_rate_mapping(void)
{
    check(NETCHESSZX_NEXT_DIRECT_IDLE_TICKS(0x00u) == 75u,
          "Next 50 Hz threshold");
    check(NETCHESSZX_NEXT_DIRECT_IDLE_TICKS(0x04u) == 90u,
          "Next 60 Hz threshold");
    check(NETCHESSZX_NEXT_DIRECT_IDLE_TICKS(0xfbu) == 75u,
          "other NextReg 0x05 bits do not select 60 Hz");
    check(NETCHESSZX_NEXT_DIRECT_IDLE_TICKS(0xffu) == 90u,
          "NextReg 0x05 bit 2 selects 60 Hz");
}

static void run_direct_tests(void)
{
    test_direct_ping_ack();
    test_direct_loss_after_misses();
    test_direct_passive_host_loss();
    test_direct_peer_ping_resets_pending();
}

int main(void)
{
    test_next_refresh_rate_mapping();
    test_direct_idle_ticks = 75u;
#ifdef NETCHESSZX_NEXT
    net_uart_direct_idle_ticks = test_direct_idle_ticks;
#endif
    run_direct_tests();
    test_mqtt_loss_after_misses(120u);
#ifdef NETCHESSZX_NEXT
    test_direct_idle_ticks = 90u;
    net_uart_direct_idle_ticks = test_direct_idle_ticks;
    run_direct_tests();
    test_mqtt_loss_after_misses(144u);
#endif
    puts("session ping tests ok");
    return 0;
}
