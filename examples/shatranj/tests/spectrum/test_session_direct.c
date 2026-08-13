#include "spectrum/session/direct.h"

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

static void check(int condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void test_direct_start_side(void)
{
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    check(!netchesszx_session_direct_apply_start_side("GAME START WHITE=BAD"),
          "reject bad white owner");
    check(netchesszx_session_direct_apply_start_side("GAME START WHITE=HOST"),
          "accept host white owner");
    check(netchesszx_host_color == NETCHESSZX_COLOR_WHITE,
          "host white after host white");
    check(netchesszx_local_color == NETCHESSZX_COLOR_BLACK,
          "local black after host white");
    check(netchesszx_session_direct_apply_start_side(
              "GAME START WHITE=GUEST"),
          "accept guest white owner");
    check(netchesszx_host_color == NETCHESSZX_COLOR_BLACK,
          "host black after guest white");
    check(netchesszx_local_color == NETCHESSZX_COLOR_WHITE,
          "local white after guest white");
}

static void test_direct_hello(void)
{
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                  NETCHESSZX_TRANSPORT_DIRECT,
                                  NETCHESSZX_COLOR_WHITE);
    check(netchesszx_session_direct_apply_hello("HELLO DIRECT GUEST"),
          "host accepts guest hello");
    check(!netchesszx_session_direct_apply_hello(
              "HELLO DIRECT HOST WHITE=HOST"),
          "host rejects host hello");
    check(!netchesszx_session_direct_apply_hello("HELLO DIRECT BAD"),
          "host rejects bad hello");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                  NETCHESSZX_TRANSPORT_DIRECT,
                                  NETCHESSZX_COLOR_BLACK);
    netchesszx_host_color_ready = 0u;
    check(netchesszx_session_direct_apply_hello(
              "HELLO DIRECT HOST WHITE=HOST"),
          "accept host white");
    check(netchesszx_host_color == NETCHESSZX_COLOR_WHITE,
          "host white after host hello");
    check(netchesszx_local_color == NETCHESSZX_COLOR_BLACK,
          "local black after host hello");
    check(netchesszx_session_direct_apply_hello(
              "HELLO DIRECT HOST WHITE=HOST"),
          "accept duplicate host hello");
    check(!netchesszx_session_direct_apply_hello(
              "HELLO DIRECT HOST WHITE=GUEST"),
          "reject conflicting host hello");
    check(netchesszx_host_color == NETCHESSZX_COLOR_WHITE &&
              netchesszx_local_color == NETCHESSZX_COLOR_BLACK,
          "conflicting hello keeps negotiated colors");
    check(!netchesszx_session_direct_apply_hello("HELLO DIRECT GUEST"),
          "guest rejects guest hello");
    check(!netchesszx_session_direct_apply_hello(
              "HELLO DIRECT HOST WHITE=BAD"),
          "guest rejects bad white owner");
}

static void test_direct_hello_send(void)
{
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    sent_text = 0;
    check(netchesszx_session_direct_send_hello(), "host hello sent");
    check(sent_text != 0 &&
              strcmp(sent_text, "HELLO DIRECT HOST WHITE=HOST") == 0,
          "host hello text");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    sent_text = 0;
    check(netchesszx_session_direct_send_hello(), "guest hello sent");
    check(sent_text != 0 &&
              strcmp(sent_text, "HELLO DIRECT GUEST") == 0,
          "guest hello text");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    sent_text = 0;
    check(netchesszx_session_direct_send_hello(), "mqtt hello no-op");
    check(sent_text == 0, "mqtt hello does not send");
}

int main(void)
{
    test_direct_start_side();
    test_direct_hello();
    test_direct_hello_send();
    puts("session direct tests ok");
    return 0;
}
