#include "common/savegame/savegame_format.h"
#include "spectrum/config/session.h"
#include "spectrum/session/poll.h"
#include "spectrum/transport/link.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int16_t stub_read_result;
static const char *stub_payload;
static uint8_t stub_payload_flags;
static uint8_t stub_background_drain_count;
static uint8_t stub_link_activity;
static uint8_t stub_partial_copy;
static uint8_t stub_send_ping_count;
static uint8_t stub_send_ping_ok = 1u;
static uint8_t stub_send_ack_ping_count;
static uint8_t stub_send_ack_ping_ok = 1u;
static uint8_t stub_publish_offline_count;
static uint8_t stub_publish_offline_ok = 1u;

static void reset_stubs(void)
{
    stub_read_result = SPECTRUM_LINK_READ_TIMEOUT;
    stub_payload = "";
    stub_payload_flags = 0u;
    stub_background_drain_count = 0u;
    stub_link_activity = 0u;
    stub_partial_copy = 0u;
    stub_send_ping_count = 0u;
    stub_send_ping_ok = 1u;
    stub_send_ack_ping_count = 0u;
    stub_send_ack_ping_ok = 1u;
    stub_publish_offline_count = 0u;
    stub_publish_offline_ok = 1u;
}

int16_t spectrum_net_read_payload(char *payload, uint8_t payload_cap)
{
    if (stub_read_result >= 0 && payload_cap != 0u) {
        if (stub_partial_copy) {
            size_t len = strlen(stub_payload);

            if (len > payload_cap) {
                len = payload_cap;
            }
            memcpy(payload, stub_payload, len);
        } else {
            strncpy(payload, stub_payload, (size_t)payload_cap - 1u);
            payload[payload_cap - 1u] = '\0';
        }
    }
    return stub_read_result;
}

void spectrum_net_background_drain(void)
{
    ++stub_background_drain_count;
}

uint8_t spectrum_net_link_activity(void)
{
    uint8_t activity = stub_link_activity;

    stub_link_activity = 0u;
    return activity;
}

uint8_t spectrum_net_payload_flags(void)
{
    return stub_payload_flags;
}

uint8_t netchesszx_session_send_ping(void)
{
    ++stub_send_ping_count;
    return stub_send_ping_ok;
}

uint8_t netchesszx_session_send_ack_ping(void)
{
    ++stub_send_ack_ping_count;
    return stub_send_ack_ping_ok;
}

uint8_t spectrum_net_mqtt_publish_offline(uint8_t route)
{
    (void)route;
    ++stub_publish_offline_count;
    return stub_publish_offline_ok;
}

static void require_u8(const char *label, uint8_t got, uint8_t want)
{
    if (got != want) {
        fprintf(stderr, "%s: got %u want %u\n", label, got, want);
        exit(1);
    }
}

static void test_payload_event(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_ping_reset(&ping);
    ping.idle_ticks = 42u;
    ping.misses = 3u;
    stub_read_result = 0;
    stub_payload = "MOVE 1 e2e4";

    require_u8("poll event",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("event tag", (uint8_t)out.event, NETCHESSZX_SESSION_EVENT_MOVE);
    require_u8("retained", out.retained, 0u);
    require_u8("background drain", stub_background_drain_count, 1u);
    require_u8("direct payload idle reset", ping.idle_ticks, 0u);
    require_u8("direct payload misses reset", ping.misses, 0u);
}

static void test_retained_side_effect_event_ignored(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_ping_reset(&ping);
    stub_read_result = 0;
    stub_payload = "MOVE 1 e2e4";
    stub_payload_flags = SPECTRUM_LINK_PAYLOAD_RETAINED;

    require_u8("retained poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("retained ignored event",
               (uint8_t)out.event,
               NETCHESSZX_SESSION_EVENT_UNKNOWN);
}

static void test_short_restore_frame_does_not_use_stale_tail(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;
    uint8_t i;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_ping_reset(&ping);
    stub_read_result = 0;
    stub_payload = "RS00 ";
    stub_partial_copy = 1u;
    for (i = 0u; i < sizeof(payload); ++i) {
        payload[i] = 'A';
    }
    payload[NETCHESSZX_SAVE_RESTORE_FRAME_MAX] = '\0';

    require_u8("short restore poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("short restore event",
               (uint8_t)out.event,
               NETCHESSZX_SESSION_EVENT_UNKNOWN);
}

static void test_direct_guest_timeout_sends_ping(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;
    uint8_t i;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_ping_reset(&ping);
    stub_read_result = SPECTRUM_LINK_READ_TIMEOUT;

    /* DIRECT guest owns keepalive PING. */
    for (i = 0u; i < 75u; ++i) {
        require_u8("timeout poll",
                   netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
                   NETCHESSZX_SESSION_POLL_NONE);
    }
    require_u8("send ping count", stub_send_ping_count, 1u);
}

static void test_direct_failed_ping_disconnects(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;
    uint16_t i;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_ping_reset(&ping);
    stub_read_result = SPECTRUM_LINK_READ_TIMEOUT;
    stub_send_ping_ok = 0u;

    for (i = 0u; i < 74u; ++i) {
        require_u8("failed ping timeout poll",
                   netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
                   NETCHESSZX_SESSION_POLL_NONE);
    }
    require_u8("failed ping disconnect",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_DISCONNECTED);
    require_u8("failed ping count", stub_send_ping_count, 1u);
    require_u8("failed ping not counted as sent", ping.misses, 0u);
    require_u8("failed ping not pending", ping.direct_pending, 0u);
}


static void test_direct_host_timeout_is_passive(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;
    uint16_t i;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_ping_reset(&ping);
    stub_read_result = SPECTRUM_LINK_READ_TIMEOUT;

    /* Two missed 3-window waits: 18 seconds at 50 Hz. */
    for (i = 0u; i < (uint16_t)(75u * 6u - 1u); ++i) {
        require_u8("passive host timeout poll",
                   netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
                   NETCHESSZX_SESSION_POLL_NONE);
    }
    require_u8("passive host sends no ping", stub_send_ping_count, 0u);
    require_u8("passive host lost",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_DISCONNECTED);
}

static void test_mqtt_waiting_peer_does_not_run_liveness(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;
    uint16_t i;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_peer_reset();
    netchesszx_session_ping_reset(&ping);
    stub_read_result = SPECTRUM_LINK_READ_TIMEOUT;
    /* Only peer PING is suppressed here; broker PINGREQ is transport-owned. */

    for (i = 0u; i < 720u; ++i) {
        require_u8("waiting peer timeout poll",
                   netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
                   NETCHESSZX_SESSION_POLL_NONE);
    }
    require_u8("waiting peer sends no ping", stub_send_ping_count, 0u);
    require_u8("waiting peer idle unchanged", ping.idle_ticks, 0u);
    require_u8("waiting peer misses unchanged", ping.misses, 0u);

    netchesszx_session_peer_mark_ready();
    for (i = 0u; i < 120u; ++i) {
        require_u8("ready peer timeout poll",
                   netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
                   NETCHESSZX_SESSION_POLL_NONE);
    }
    require_u8("ready peer sends ping", stub_send_ping_count, 1u);
}

static void test_mqtt_broker_activity_does_not_mask_peer_loss(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;

    /* Broker PINGRESP (link activity) proves the broker is alive, not the
       peer: it must NOT reset the session miss counter. With the miss
       counter at the limit, the next idle tick declares the peer lost. */
    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_peer_mark_ready();
    netchesszx_session_ping_reset(&ping);
    ping.idle_ticks = 119u;
    ping.misses = 4u;
    stub_read_result = SPECTRUM_LINK_READ_TIMEOUT;
    stub_link_activity = 1u;

    require_u8("mqtt activity poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("mqtt activity peer loss",
               (uint8_t)out.event,
               NETCHESSZX_SESSION_EVENT_BYE);
    require_u8("mqtt activity releases peer", stub_publish_offline_count, 1u);
    require_u8("mqtt activity misses kept", ping.misses, 4u);
}


static void test_mqtt_only_live_peer_payload_resets_liveness(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_mqtt_session_id = 78u;
    netchesszx_session_peer_reset();
    netchesszx_session_peer_mark_ready();
    netchesszx_session_ping_reset(&ping);
    ping.idle_ticks = 42u;
    ping.misses = 3u;

    stub_read_result = 0;
    stub_payload = "O W 77";
    require_u8("stale online poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("stale online idle kept", ping.idle_ticks, 42u);
    require_u8("stale online misses kept", ping.misses, 3u);

    stub_payload = "F W 78";
    stub_payload_flags = SPECTRUM_LINK_PAYLOAD_RETAINED;
    require_u8("retained offline poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("retained offline idle kept", ping.idle_ticks, 42u);
    require_u8("retained offline misses kept", ping.misses, 3u);

    stub_payload = "F B 78";
    stub_payload_flags = 0u;
    require_u8("local offline poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("local offline idle kept", ping.idle_ticks, 42u);
    require_u8("local offline misses kept", ping.misses, 3u);

    stub_payload = "O W 78";
    require_u8("current online poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("current online idle kept", ping.idle_ticks, 42u);
    require_u8("current online misses kept", ping.misses, 3u);

    stub_payload = "CHAT live";
    require_u8("live peer poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("live peer idle reset", ping.idle_ticks, 0u);
    require_u8("live peer misses reset", ping.misses, 0u);
}

static void seed_ping(netchesszx_session_ping_t *ping, uint8_t misses)
{
    netchesszx_session_ping_reset(ping);
    ping->idle_ticks = 42u;
    ping->misses = misses;
}

static void test_mqtt_ping_liveness_guards(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_peer_reset();
    stub_read_result = 0;

    seed_ping(&ping, 3u);
    stub_payload = "PING";
    stub_payload_flags = SPECTRUM_LINK_PAYLOAD_RETAINED;
    require_u8("retained ping poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("retained ping no ack", stub_send_ack_ping_count, 0u);
    require_u8("retained ping idle kept", ping.idle_ticks, 42u);
    require_u8("retained ping misses kept", ping.misses, 3u);

    stub_payload_flags = 0u;
    require_u8("pre-peer ping poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("pre-peer ping no ack", stub_send_ack_ping_count, 0u);
    require_u8("pre-peer ping idle kept", ping.idle_ticks, 42u);

    netchesszx_session_peer_mark_ready();
    require_u8("live peer ping poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("live peer ping ack", stub_send_ack_ping_count, 1u);
    require_u8("live peer ping idle reset", ping.idle_ticks, 0u);
    require_u8("live peer ping misses reset", ping.misses, 0u);

    seed_ping(&ping, 0u);
    stub_payload = "ACK PING";
    require_u8("unsolicited ack poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("unsolicited ack idle kept", ping.idle_ticks, 42u);

    seed_ping(&ping, 2u);
    require_u8("live ack poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("live ack idle reset", ping.idle_ticks, 0u);
    require_u8("live ack misses reset", ping.misses, 0u);

    seed_ping(&ping, 2u);
    stub_payload_flags = SPECTRUM_LINK_PAYLOAD_RETAINED;
    require_u8("retained ack poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("retained ack idle kept", ping.idle_ticks, 42u);
    require_u8("retained ack misses kept", ping.misses, 2u);
}

static void test_mqtt_setup_liveness_guards(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_mqtt_session_id = 78u;
    netchesszx_session_peer_reset();
    stub_read_result = 0;

    seed_ping(&ping, 3u);
    stub_payload = "H B 88";
    require_u8("fresh pregame host poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("fresh pregame host idle kept", ping.idle_ticks, 42u);

    seed_ping(&ping, 3u);
    stub_payload = "H W 78";
    require_u8("exact active host poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("exact active host idle kept", ping.idle_ticks, 42u);

    seed_ping(&ping, 3u);
    stub_payload = "H B 88";
    require_u8("foreign active host poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("foreign active host idle kept", ping.idle_ticks, 42u);
    require_u8("foreign active host misses kept", ping.misses, 3u);

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_mqtt_session_id = 78u;
    netchesszx_session_peer_reset();
    seed_ping(&ping, 3u);
    ping.idle_ticks = 119u;
    stub_payload = "J 78";
    require_u8("initial join poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("initial join idle kept", ping.idle_ticks, 119u);

    netchesszx_session_peer_mark_ready();
    stub_payload = "PING";
    require_u8("post-bootstrap ping poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("post-bootstrap ping ack", stub_send_ack_ping_count, 1u);
    require_u8("post-bootstrap ping idle reset", ping.idle_ticks, 0u);
    require_u8("post-bootstrap ping misses reset", ping.misses, 0u);

    seed_ping(&ping, 3u);
    stub_payload = "J 78";
    require_u8("duplicate pregame join poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("duplicate pregame join idle kept", ping.idle_ticks, 42u);

    seed_ping(&ping, 3u);
    require_u8("active duplicate join poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_EVENT);
    require_u8("active duplicate join idle kept", ping.idle_ticks, 42u);
}

static void test_direct_ping_is_consumed_and_acked_each_time(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_ping_reset(&ping);
    ping.direct_pending = 1u;
    ping.misses = 4u;
    stub_read_result = 0;
    stub_payload = "PING";

    require_u8("direct ping poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("direct ping ack count", stub_send_ack_ping_count, 1u);
    require_u8("direct ping pending", ping.direct_pending, 0u);
    require_u8("direct ping misses", ping.misses, 0u);

    require_u8("direct ping duplicate poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("direct ping duplicate ack count", stub_send_ack_ping_count, 2u);
}

static void test_direct_ack_ping_is_consumed(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;

    reset_stubs();
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_ping_reset(&ping);
    ping.direct_pending = 1u;
    ping.misses = 2u;
    stub_read_result = 0;
    stub_payload = "ACK PING";

    require_u8("direct ack ping poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_NONE);
    require_u8("direct ack pending", ping.direct_pending, 0u);
    require_u8("direct ack misses", ping.misses, 0u);
}

static void test_read_disconnect(void)
{
    char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    netchesszx_session_ping_t ping;
    netchesszx_session_poll_result_t out;

    reset_stubs();
    netchesszx_session_ping_reset(&ping);
    stub_read_result = -2;

    require_u8("disconnect poll",
               netchesszx_session_poll(&ping, payload, sizeof(payload), &out),
               NETCHESSZX_SESSION_POLL_DISCONNECTED);
}

int main(void)
{
    test_payload_event();
    test_retained_side_effect_event_ignored();
    test_short_restore_frame_does_not_use_stale_tail();
    test_direct_guest_timeout_sends_ping();
    test_direct_failed_ping_disconnects();
    test_direct_host_timeout_is_passive();
    test_mqtt_waiting_peer_does_not_run_liveness();
    test_mqtt_broker_activity_does_not_mask_peer_loss();
    test_mqtt_only_live_peer_payload_resets_liveness();
    test_mqtt_ping_liveness_guards();
    test_mqtt_setup_liveness_guards();
    test_direct_ping_is_consumed_and_acked_each_time();
    test_direct_ack_ping_is_consumed();
    test_read_disconnect();
    puts("session poll tests ok");
    return 0;
}
