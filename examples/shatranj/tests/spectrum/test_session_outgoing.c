#include "spectrum/session/outgoing.h"

#include "spectrum/config/session.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *sent_text;

uint8_t spectrum_net_send_text(const char *text)
{
    sent_text = text;
    return 1u;
}

uint8_t spectrum_net_send_ping(void)
{
    sent_text = "PING";
    return 1u;
}

static void check(int condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void expect_sent(const char *expected, const char *message)
{
    check(sent_text != 0 && strcmp(sent_text, expected) == 0, message);
}

static void test_ack_nack(void)
{
    sent_text = 0;
    check(netchesszx_session_send_ack_move("0"), "zero ack move sent");
    expect_sent("ACK 0", "zero ack move text");
    check(netchesszx_session_send_nack_move("0"), "zero nack move sent");
    expect_sent("NACK 0", "zero nack move text");
    check(netchesszx_session_send_ack_move("12"), "ack move sent");
    expect_sent("ACK 12", "ack move text");
    check(netchesszx_session_send_nack_move("13"), "nack move sent");
    expect_sent("NACK 13", "nack move text");
    check(netchesszx_session_send_ack_move("65535"), "max ack move sent");
    expect_sent("ACK 65535", "max ack move text");
    check(netchesszx_session_send_nack_move("65535"), "max nack move sent");
    expect_sent("NACK 65535", "max nack move text");
}

static void test_ping_response(void)
{
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    check(netchesszx_session_send_ping(), "direct ping sent");
    expect_sent("PING", "direct ping text");
    check(netchesszx_session_send_ack_ping(), "ack ping sent");
    expect_sent("ACK PING", "ack ping text");
}

static void test_reset_start(void)
{
    check(netchesszx_session_send_ack_reset(), "ack reset sent");
    expect_sent("ACK RESET", "ack reset text");
    check(netchesszx_session_send_ack_game_start(), "ack start sent");
    expect_sent("ACK GAME START", "ack start text");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    check(netchesszx_session_send_start_game(), "mqtt start sent");
    expect_sent("GAME START", "mqtt start text");
}

int main(void)
{
    test_ack_nack();
    test_ping_response();
    test_reset_start();
    puts("session outgoing tests ok");
    return 0;
}
