#include "spectrum/session/event.h"

#include "common/savegame/savegame_format.h"
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

static void expect_event(const char *payload,
                         uint8_t is_mqtt,
                         uint8_t retained,
                         netchesszx_session_event_t expected,
                         const char *message)
{
    netchesszx_session_event_t ev;

    ev = netchesszx_session_classify_event(payload,
                                           is_mqtt,
                                           retained,
                                           netchesszx_session_is_host());
    check(ev == expected, message);
}

static void make_restore_frame(char *out, char chunk)
{
    uint8_t i;

    out[0] = 'R';
    out[1] = 'S';
    out[2] = '0';
    out[3] = chunk;
    out[4] = ' ';
    for (i = 5u; i < NETCHESSZX_SAVE_RESTORE_FRAME_MAX; ++i) {
        out[i] = 'A';
    }
    out[NETCHESSZX_SAVE_RESTORE_FRAME_MAX] = '\0';
}

static void test_common_protocol_events(void)
{
    char restore_frame[NETCHESSZX_SAVE_RESTORE_FRAME_MAX + 1u];

    expect_event("HELLO DIRECT HOST WHITE=HOST",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_DIRECT_HELLO,
                 "direct hello");
    expect_event("PING",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_PING,
                 "ping");
    expect_event("ACK PING",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_PING,
                 "ack ping");
    expect_event("ACK 12",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_MOVE,
                 "ack move");
    expect_event("ACK RESET",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_RESET,
                 "ack reset");
    expect_event("ACK DRAW",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_DRAW,
                 "ack draw");
    expect_event("ACK GAME START",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_GAME_START,
                 "ack game start");
    expect_event("ACK RESIGN",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_RESIGN,
                 "ack resign");
    expect_event("ACK GAME STARTED", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_MOVE,
                 "ack game start boundary");
    expect_event("ACK RESETX", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_MOVE,
                 "ack reset boundary");
    expect_event("ACK DRAWjunk", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_MOVE,
                 "ack draw boundary");
    expect_event("ACK RESIGNED", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_MOVE,
                 "ack resign boundary");
    expect_event("ACK GAME START BUSY", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_ACK_MOVE,
                 "ack game start rejects detail");
    expect_event("NACK 12",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_NACK_MOVE,
                 "nack move");
    expect_event("NACK RESET",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_NACK_RESET,
                 "nack reset");
    expect_event("NACK DRAW",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_NACK_DRAW,
                 "nack draw");
    expect_event("NACK GAME START BUSY",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_NACK_GAME_START,
                 "nack game start");
    expect_event("NACK RESET BUSY", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_NACK_RESET,
                 "nack reset reason");
    expect_event("NACK GAME STARTED", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_NACK_MOVE,
                 "nack game start boundary");
    expect_event("NACK RESETX", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_NACK_MOVE,
                 "nack reset boundary");
    expect_event("NACK DRAW BUSY", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_NACK_MOVE,
                 "nack draw boundary");
    expect_event("NACK RESIGN", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_NACK_MOVE,
                 "nack resign remains move nack");
    expect_event("BYE",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_BYE,
                 "bye");
    expect_event("BUSY",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_HOST_BUSY,
                 "direct busy");
    expect_event("RESET",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_RESET,
                 "reset");
    expect_event("GAME START WHITE=GUEST",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_GAME_START,
                 "game start");
    expect_event("GAME STARTED",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "bad game start boundary");
    expect_event("RESET BUSY", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "bare reset rejects detail");
    expect_event("DRAW BUSY", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "bare draw rejects detail");
    expect_event("RESIGN NOW", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "bare resign rejects detail");
    expect_event("MOVE 1 e2e4",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_MOVE,
                 "move");
    expect_event("TAKEBACK 1",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_TAKEBACK,
                 "takeback");
    expect_event("TAKEBACK 1x", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "takeback rejects suffix");
    expect_event("TAKEBACK 1 extra", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "takeback rejects extra token");
    expect_event("TAKEBACK 0", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "takeback rejects zero");
    expect_event("TAKEBACK 65536", 0u, 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "takeback rejects overflow");
    expect_event("CHAT hello",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_CHAT,
                 "chat");
    expect_event("DRAW",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_DRAW,
                 "draw");
    expect_event("RESIGN",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_RESIGN,
                 "resign");
    expect_event("RQ",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_RESTORE_RQ,
                 "restore request");
    expect_event("RY",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_RESTORE_RY,
                 "restore yes");
    expect_event("RN",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_RESTORE_RN,
                 "restore no");
    expect_event("RA",
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_RESTORE_RA,
                 "restore ack");
    make_restore_frame(restore_frame, '0');
    expect_event(restore_frame,
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_RESTORE_RS,
                 "restore chunk 0");
    make_restore_frame(restore_frame, '1');
    expect_event(restore_frame,
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_RESTORE_RS,
                 "restore chunk 1");
    make_restore_frame(restore_frame, '2');
    expect_event(restore_frame,
                 0u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "bad restore chunk id rejected");
}

static void test_mqtt_session_events(void)
{
    netchesszx_session_event_t ev;

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_mqtt_session_id = 7u;
    expect_event("",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_MQTT_EMPTY,
                 "mqtt empty");
    expect_event("F B 7",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_MQTT_PEER_OFFLINE,
                 "mqtt peer offline");
    expect_event("F W",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_MQTT_LOCAL_OFFLINE,
                 "mqtt local offline");
    expect_event("OFFLINE",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "unknown offline ignored");
    expect_event("H W 8",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_MQTT_FOREIGN_HOST,
                 "mqtt foreign host");
    expect_event("H W 7",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "same session host echo ignored by classifier");
    expect_event("GAME START WHITE=GUEST",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_GAME_START,
                 "mqtt game start stays game start");
    expect_event("GAME STARTED",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_MQTT_TEXT,
                 "mqtt bad game start is text");
    ev = netchesszx_session_classify_event("J 7",
                                           1u,
                                           0u,
                                           netchesszx_session_is_host());
    check(ev == NETCHESSZX_SESSION_EVENT_MQTT_PEER_READY,
          "mqtt peer ready");
    expect_event("J 7",
                 1u,
                 1u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "retained join ignored");
    expect_event("J 8",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "stale join ignored");
    expect_event("J 7 DEVICE",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "legacy join token ignored");
    expect_event("TEXT",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_MQTT_TEXT,
                 "mqtt text");
    expect_event("DRAW",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_DRAW,
                 "mqtt draw");
    expect_event("CANCEL DRAW",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_CANCEL_DRAW,
                 "mqtt cancel draw");
    expect_event("CANCEL RESET",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_CANCEL_RESET,
                 "mqtt cancel reset");
    expect_event("CANCEL RESET OLD",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_MQTT_TEXT,
                 "mqtt malformed cancel is text");
    expect_event("RESIGN",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_RESIGN,
                 "mqtt resign");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_BLACK);
    expect_event("H W 7",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_MQTT_HOST,
                 "mqtt host");
    expect_event("O W 7",
                 1u,
                 1u,
                 NETCHESSZX_SESSION_EVENT_MQTT_SEAT_TAKEN,
                 "mqtt retained local seat taken");
    expect_event("O W 8",
                 1u,
                 1u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "mqtt stale retained local seat ignored");
    expect_event("O W 7",
                 1u,
                 0u,
                 NETCHESSZX_SESSION_EVENT_UNKNOWN,
                 "mqtt live local echo ignored");
}

static void test_retained_policy(void)
{
    check(netchesszx_session_event_ignores_retained(NETCHESSZX_SESSION_EVENT_ACK_MOVE,
                                                    1u),
          "retained ack move ignored");
    check(netchesszx_session_event_ignores_retained(NETCHESSZX_SESSION_EVENT_DRAW,
                                                    1u),
          "retained draw ignored");
    check(netchesszx_session_event_ignores_retained(
              NETCHESSZX_SESSION_EVENT_CANCEL_RESET, 1u),
          "retained cancel reset ignored");
    check(netchesszx_session_event_ignores_retained(NETCHESSZX_SESSION_EVENT_RESIGN,
                                                    1u),
          "retained resign ignored");
    check(netchesszx_session_event_ignores_retained(
              NETCHESSZX_SESSION_EVENT_MQTT_PEER_OFFLINE,
              1u),
          "retained offline ignored");
    check(netchesszx_session_event_ignores_retained(
              NETCHESSZX_SESSION_EVENT_GAME_START,
              1u),
          "retained game start ignored");
    check(netchesszx_session_event_ignores_retained(
              NETCHESSZX_SESSION_EVENT_TAKEBACK,
              1u),
          "retained takeback ignored");
    check(netchesszx_session_event_ignores_retained(
              NETCHESSZX_SESSION_EVENT_MQTT_FOREIGN_HOST,
              1u),
          "retained foreign host ignored");
    check(netchesszx_session_event_ignores_retained(
              NETCHESSZX_SESSION_EVENT_MQTT_TEXT,
              1u),
          "retained text ignored");
    check(!netchesszx_session_event_ignores_retained(
              NETCHESSZX_SESSION_EVENT_MQTT_HOST,
              1u),
          "retained host handled");
    check(netchesszx_session_event_ignores_retained(
              NETCHESSZX_SESSION_EVENT_ACK_PING,
              1u),
          "retained ack ping ignored");
    check(!netchesszx_session_event_ignores_retained(
              NETCHESSZX_SESSION_EVENT_MQTT_LOCAL_OFFLINE,
              1u),
          "retained local offline handled");
    check(!netchesszx_session_event_ignores_retained(
              NETCHESSZX_SESSION_EVENT_MQTT_SEAT_TAKEN,
              1u),
          "retained seat taken handled");
}

static void test_peer_state_actions(void)
{
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_peer_reset();
    check(!netchesszx_session_peer_ready(), "peer starts clear");
    netchesszx_session_peer_mark_ready();
    check(netchesszx_session_peer_ready(), "peer ready state");
    netchesszx_session_peer_clear();
    check(!netchesszx_session_peer_ready(), "peer clear state");
}

static void test_mqtt_host_flags(void)
{
    uint8_t bad;
    uint8_t flags;
    uint8_t old_local_color;

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_BLACK);
    netchesszx_mqtt_session_id = 0u;
    netchesszx_session_peer_reset();
    old_local_color = netchesszx_local_color;
    check(!netchesszx_session_mqtt_can_accept_game_start(),
          "mqtt start gate starts closed");
    netchesszx_session_peer_mark_ready();
    check(!netchesszx_session_mqtt_can_accept_game_start(),
          "mqtt start gate needs session id");
    netchesszx_session_peer_reset();

    flags = netchesszx_session_mqtt_host_flags("H W 9", 0u, 1u, &bad);
    check(!bad, "retained host valid");
    check(flags & NETCHESSZX_SESSION_MQTT_HOST_RETAINED_WAIT,
          "retained host waits");
    check(!netchesszx_session_peer_ready(), "retained host no peer ready");
    check(!netchesszx_session_mqtt_can_accept_game_start(),
          "retained host cannot start game");
    check(netchesszx_mqtt_session_id == 0u, "retained host keeps session clear");
    check(netchesszx_local_color == old_local_color,
          "retained host keeps local color");
    check((flags & (NETCHESSZX_SESSION_MQTT_HOST_COLOR_CHANGED |
                    NETCHESSZX_SESSION_MQTT_HOST_ACTIVATE_SIDE)) == 0u,
          "retained host has no side effects");

    flags = netchesszx_session_mqtt_host_flags("H W 9", 0u, 0u, &bad);
    check(!bad, "live host valid");
    check(flags & NETCHESSZX_SESSION_MQTT_HOST_READY_WAIT,
          "live host ready wait");
    check(netchesszx_session_peer_ready(), "live host marks ready");
    check(netchesszx_session_mqtt_can_accept_game_start(),
          "live host enables game start");

    flags = netchesszx_session_mqtt_host_flags("H X 9", 0u, 0u, &bad);
    check(flags == 0u && bad, "bad host color");
}

int main(void)
{
    test_common_protocol_events();
    test_mqtt_session_events();
    test_retained_policy();
    test_peer_state_actions();
    test_mqtt_host_flags();
    puts("session event tests ok");
    return 0;
}
