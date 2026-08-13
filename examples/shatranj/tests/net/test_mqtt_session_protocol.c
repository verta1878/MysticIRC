#include "common/protocol/mqtt_session_protocol.h"

#include <stdio.h>
#include <string.h>

static int failures;

static void check(int ok, const char *label)
{
    if (!ok) {
        printf("FAIL: %s\n", label);
        ++failures;
    }
}

static void check_text(const char *got, const char *expected, const char *label)
{
    if (strcmp(got, expected) != 0) {
        printf("FAIL: %s got='%s' expected='%s'\n", label, got, expected);
        ++failures;
    }
}

static void test_wire_constants(void)
{
    check(NETCHESS_MQTT_SESSION_VERB_HOST == 'H', "host verb constant");
    check(NETCHESS_MQTT_SESSION_VERB_JOIN == 'J', "join verb constant");
    check(NETCHESS_MQTT_SESSION_VERB_ONLINE == 'O', "online verb constant");
    check(NETCHESS_MQTT_SESSION_VERB_OFFLINE == 'F', "offline verb constant");
    check_text(NETCHESS_MQTT_SESSION_HOST_PREFIX, "H ", "host prefix constant");
    check_text(NETCHESS_MQTT_SESSION_JOIN_PREFIX, "J ", "join prefix constant");
    check_text(NETCHESS_MQTT_SESSION_ONLINE_WHITE_PREFIX, "O W ", "online white prefix constant");
    check_text(NETCHESS_MQTT_SESSION_ONLINE_BLACK_PREFIX, "O B ", "online black prefix constant");
}

static void test_host_payload(void)
{
    uint8_t color = 9u;
    uint16_t session_id = 0u;

    check(netchess_mqtt_session_parse_host("H W 123",
                                           &color,
                                           &session_id),
          "host parse");
    check(color == NETCHESS_MQTT_SESSION_COLOR_WHITE, "host color white");
    check(session_id == 123u, "host session");

    check(netchess_mqtt_session_parse_host("H B 65535",
                                           &color,
                                           &session_id),
          "host parse max");
    check(color == NETCHESS_MQTT_SESSION_COLOR_BLACK, "host color black");
    check(session_id == 65535u, "host max session");
    check(!netchess_mqtt_session_parse_host("H W 123 DEVICE",
                                            &color,
                                            &session_id),
          "host rejects trailing identity token");

    check(!netchess_mqtt_session_parse_host("H X 1",
                                            &color,
                                            &session_id),
          "host rejects color");
    check(!netchess_mqtt_session_parse_host("H W 0",
                                            &color,
                                            &session_id),
          "host rejects zero session");
    check(!netchess_mqtt_session_parse_host("H W 65536",
                                            &color,
                                            &session_id),
          "host rejects overflow session");
    check(!netchess_mqtt_session_parse_host("H W 1 TOKEN",
                                            &color,
                                            &session_id),
          "host rejects trailing token");
    check(!netchess_mqtt_session_parse_host("H  W 1",
                                            &color,
                                            &session_id),
          "host rejects extra space");
}

static void test_join_payload(void)
{
    uint16_t session_id = 0u;

    check(netchess_mqtt_session_parse_join("J 42",
                                           &session_id),
          "join parse");
    check(session_id == 42u, "join session");
    check(!netchess_mqtt_session_parse_join("J 42 DEVICE",
                                            &session_id),
          "join rejects trailing identity token");
    check(!netchess_mqtt_session_parse_join("J 0",
                                            &session_id),
          "join rejects zero session");
    check(!netchess_mqtt_session_parse_join("J 42 X",
                                            &session_id),
          "join rejects trailing token");
}

static void test_side_payload(void)
{
    char side = '?';
    uint16_t session_id = 99u;
    uint8_t has_session_id = 9u;

    check(netchess_mqtt_session_parse_side("O W",
                                           'O',
                                           &side,
                                           &session_id,
                                           &has_session_id),
          "online parse no session");
    check(side == 'W', "online side");
    check(session_id == 0u, "online session empty");
    check(has_session_id == 0u, "online has no session");

    check(netchess_mqtt_session_parse_side("F B 77",
                                           'F',
                                           &side,
                                           &session_id,
                                           &has_session_id),
          "offline parse session");
    check(side == 'B', "offline side");
    check(session_id == 77u, "offline session");
    check(has_session_id == 1u, "offline has session");

    check(!netchess_mqtt_session_parse_side("F X 77",
                                            'F',
                                            &side,
                                            &session_id,
                                            &has_session_id),
          "side rejects bad side");
    check(!netchess_mqtt_session_parse_side("F B 0",
                                            'F',
                                            &side,
                                            &session_id,
                                            &has_session_id),
          "side rejects zero session");
    check(!netchess_mqtt_session_parse_side("F B 77x",
                                            'F',
                                            &side,
                                            &session_id,
                                            &has_session_id),
          "side rejects trailing garbage");
}

static void test_formatters(void)
{
    char out[24];

    check(netchess_mqtt_session_format_host(
              out,
              sizeof(out),
              NETCHESS_MQTT_SESSION_COLOR_BLACK,
              99u),
          "format host");
    check_text(out, "H B 99", "host format text");

    check(netchess_mqtt_session_format_join(
              out,
              sizeof(out),
              99u),
          "format join");
    check_text(out, "J 99", "join format text");

    check(netchess_mqtt_session_format_side(out, sizeof(out),
                                            'O', 'W', 0u, 0u),
          "format online no session");
    check_text(out, "O W", "online format text");

    check(netchess_mqtt_session_format_side(out, sizeof(out),
                                            'F', 'B', 99u, 1u),
          "format offline session");
    check_text(out, "F B 99", "offline format text");

    check(!netchess_mqtt_session_format_host(
              out,
              5u,
              NETCHESS_MQTT_SESSION_COLOR_WHITE,
              99u),
          "format detects overflow");
    check(!netchess_mqtt_session_format_join(
              out,
              sizeof(out),
              0u),
          "format rejects zero session");
}

int main(void)
{
    test_wire_constants();
    test_host_payload();
    test_join_payload();
    test_side_payload();
    test_formatters();

    if (failures != 0) {
        printf("mqtt session protocol tests failed: %d\n", failures);
        return 1;
    }
    printf("mqtt session protocol tests ok\n");
    return 0;
}
