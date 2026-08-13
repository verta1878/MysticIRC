#include "spectrum/session/mqtt.h"

#include "spectrum/config/session.h"

#include <stdio.h>
#include <stdlib.h>

static void check(int condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void test_parse_host_join(void)
{
    uint8_t color;
    uint16_t session_id;

    check(netchesszx_session_mqtt_parse_host_payload("H W 42",
                                                     &color,
                                                     &session_id),
          "host payload parses");
    check(color == NETCHESSZX_COLOR_WHITE, "host color white");
    check(session_id == 42u, "host session id");
    check(!netchesszx_session_mqtt_parse_host_payload("H X 42",
                                                      &color,
                                                      &session_id),
          "bad host color rejected");
    check(!netchesszx_session_mqtt_parse_host_payload("H W 0",
                                                      &color,
                                                      &session_id),
          "zero host session rejected");
    check(!netchesszx_session_mqtt_parse_host_payload("H W 65536",
                                                      &color,
                                                      &session_id),
          "overflow host session rejected");
    check(!netchesszx_session_mqtt_parse_host_payload("H W 42 DEVICE",
                                                       &color,
                                                       &session_id),
          "legacy host token rejected");
    check(!netchesszx_session_mqtt_parse_host_payload("H W 42 TOKEN",
                                                      &color,
                                                      &session_id),
          "trailing host identity word rejected");
    check(!netchesszx_session_mqtt_parse_host_payload("H W 42 X",
                                                      &color,
                                                      &session_id),
          "trailing host token rejected");

    check(netchesszx_session_mqtt_parse_join_payload("J 42",
                                                     &session_id),
          "join payload parses");
    check(session_id == 42u, "join session id");
    check(!netchesszx_session_mqtt_parse_join_payload("J 0",
                                                     &session_id),
          "zero join session rejected");
    check(!netchesszx_session_mqtt_parse_join_payload("J 65536",
                                                     &session_id),
          "overflow join session rejected");
    check(!netchesszx_session_mqtt_parse_join_payload("J 42 DEVICE",
                                                      &session_id),
          "legacy join token rejected");
    check(!netchesszx_session_mqtt_parse_join_payload("J 42 TOKEN",
                                                     &session_id),
          "trailing join identity word rejected");
    check(!netchesszx_session_mqtt_parse_join_payload("J 42 X",
                                                     &session_id),
          "trailing join token rejected");
}

static void test_peer_matches(void)
{
    uint8_t relation;

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_mqtt_session_id = 77u;

    /* Id-less F is a stray client's will (armed before it knew the session
       id); honoring it would let any intruder kill a live game. */
    relation = netchesszx_session_mqtt_side_relation("F B", 'F');
    check(relation == NETCHESSZX_SESSION_MQTT_SIDE_REMOTE,
          "offline without session id is remote but not current");
    relation = netchesszx_session_mqtt_side_relation("F B 77", 'F');
    check(relation == (NETCHESSZX_SESSION_MQTT_SIDE_REMOTE |
                       NETCHESSZX_SESSION_MQTT_SIDE_CURRENT),
          "offline session matches remote current");
    relation = netchesszx_session_mqtt_side_relation("F B 78", 'F');
    check(relation == NETCHESSZX_SESSION_MQTT_SIDE_REMOTE,
          "offline stale session remains remote only");
    relation = netchesszx_session_mqtt_side_relation("F W", 'F');
    check(relation == NETCHESSZX_SESSION_MQTT_SIDE_LOCAL,
          "local offline matches");
    relation = netchesszx_session_mqtt_side_relation("O W 77", 'O');
    check(relation == (NETCHESSZX_SESSION_MQTT_SIDE_LOCAL |
                       NETCHESSZX_SESSION_MQTT_SIDE_CURRENT),
          "seat marker matches local current");
    check(netchesszx_session_mqtt_side_relation("O X 77", 'O') == 0u,
          "bad side relation rejected");
    check(!netchesszx_session_mqtt_payload_is_foreign_host("H B 77"),
          "same host session not foreign");
    check(netchesszx_session_mqtt_payload_is_foreign_host("H B 78"),
          "foreign host session");
    check(netchesszx_session_mqtt_payload_marks_peer_ready("J 77", 1u),
          "join marks peer ready");
    check(!netchesszx_session_mqtt_payload_marks_peer_ready("J 77", 0u),
          "join does not mark peer ready for guest classifier");
    check(!netchesszx_session_mqtt_payload_marks_peer_ready("J 78", 1u),
          "stale join session ignored");
    check(!netchesszx_session_mqtt_payload_marks_peer_ready("J 77 DEVICE", 1u),
          "legacy join token ignored");
}

static void test_apply_host_color(void)
{
    uint8_t color_changed = 0u;
    uint8_t new_live_session = 0u;
    uint8_t rc;

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_BLACK);
    netchesszx_mqtt_session_id = 0u;
    rc = netchesszx_session_mqtt_apply_host_color("H B 123",
                                                  0u,
                                                  &color_changed,
                                                  &new_live_session);
    check(rc == 1u, "apply host color returns ready");
    check(netchesszx_mqtt_session_id == 123u, "apply session id");
    check(netchesszx_local_color == NETCHESSZX_COLOR_WHITE,
          "apply local white when host black");
    check(!color_changed, "same local color unchanged");
    check(!new_live_session, "first session not replacement");

    rc = netchesszx_session_mqtt_apply_host_color("H W 124",
                                                  0u,
                                                  &color_changed,
                                                  &new_live_session);
    check(rc == 2u, "new live session not previously ready");
    check(color_changed, "new live color changed");
    check(new_live_session, "new live session flagged");
    check(netchesszx_local_color == NETCHESSZX_COLOR_BLACK,
          "apply local black when host white");

    rc = netchesszx_session_mqtt_apply_host_color("H B 125",
                                                  1u,
                                                  &color_changed,
                                                  &new_live_session);
    check(rc == 0u, "reject different host while game active");
    check(netchesszx_mqtt_session_id == 124u,
          "active game keeps current session id");
}

int main(void)
{
    test_parse_host_join();
    test_peer_matches();
    test_apply_host_color();
    puts("session mqtt tests ok");
    return 0;
}
