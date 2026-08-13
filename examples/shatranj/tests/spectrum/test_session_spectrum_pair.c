#include "common/protocol/mqtt_session_protocol.h"
#include "spectrum/config/session.h"
#include "spectrum/session/direct.h"
#include "spectrum/session/mqtt.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *sent_text;

uint8_t spectrum_net_send_text(const char *text)
{
    sent_text = text;
    return 1u;
}

static void check(int condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void test_direct_spectrum_pair_contract(void)
{
    const char *host_hello;
    const char *guest_hello;
    const char *start_text;

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_BLACK);
    sent_text = 0;
    check(netchesszx_session_direct_send_hello(), "direct host hello sends");
    host_hello = sent_text;
    check(host_hello != 0 &&
              strcmp(host_hello, "HELLO DIRECT HOST WHITE=GUEST") == 0,
          "direct host advertises Spectrum guest as white");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    check(netchesszx_session_direct_apply_hello(host_hello),
          "direct Spectrum guest accepts host hello");
    check(netchesszx_local_color == NETCHESSZX_COLOR_WHITE,
          "direct guest becomes white");

    sent_text = 0;
    check(netchesszx_session_direct_send_hello(), "direct guest hello sends");
    guest_hello = sent_text;
    check(guest_hello != 0 && strcmp(guest_hello, "HELLO DIRECT GUEST") == 0,
          "direct guest advertises role, not device type");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_BLACK);
    check(netchesszx_session_direct_apply_hello(guest_hello),
          "direct Spectrum host accepts guest hello");
    start_text = netchesszx_session_start_text();
    check(strcmp(start_text, "GAME START WHITE=GUEST") == 0,
          "direct start assigns white to guest role");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    check(netchesszx_session_direct_apply_start_side(start_text),
          "direct Spectrum guest accepts start side");
    check(netchesszx_local_color == NETCHESSZX_COLOR_WHITE,
          "direct start keeps guest white");
}

static void test_mqtt_spectrum_pair_contract(void)
{
    char host_payload[16];
    char join_payload[16];
    uint8_t color_changed;
    uint8_t new_live_session;
    uint8_t rc;

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_BLACK);
    netchesszx_mqtt_session_id = 4242u;
    check(netchess_mqtt_session_format_host(host_payload,
                                            sizeof(host_payload),
                                            netchesszx_host_color,
                                            netchesszx_mqtt_session_id),
          "mqtt host setup formats");
    check(strcmp(host_payload, "H B 4242") == 0,
          "mqtt host advertises role color and session");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_mqtt_session_id = 0u;
    color_changed = 0u;
    new_live_session = 0u;
    rc = netchesszx_session_mqtt_apply_host_color(host_payload,
                                                  0u,
                                                  &color_changed,
                                                  &new_live_session);
    check(rc == 1u, "mqtt Spectrum join accepts host setup");
    check(netchesszx_mqtt_session_id == 4242u, "mqtt join stores session");
    check(netchesszx_local_color == NETCHESSZX_COLOR_WHITE,
          "mqtt join becomes opposite host color");

    check(netchess_mqtt_session_format_join(join_payload,
                                            sizeof(join_payload),
                                            netchesszx_mqtt_session_id),
          "mqtt join setup formats");
    check(strcmp(join_payload, "J 4242") == 0,
          "mqtt join advertises session, not device type");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_BLACK);
    netchesszx_mqtt_session_id = 4242u;
    check(netchesszx_session_mqtt_payload_marks_peer_ready(join_payload, 1u),
          "mqtt Spectrum host accepts join setup");
    check(strcmp(netchesszx_session_start_text(), "GAME START") == 0,
          "mqtt game start is transport-neutral");
}

int main(void)
{
    test_direct_spectrum_pair_contract();
    test_mqtt_spectrum_pair_contract();
    puts("session Spectrum pair tests ok");
    return 0;
}
