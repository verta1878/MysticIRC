#include "spectrum/session/event.h"

#include "common/protocol/direct_session_protocol.h"
#include "common/protocol/mqtt_session_protocol.h"
#include "spectrum/config/session.h"
#include "spectrum/session/mqtt.h"
#include "spectrum/transport/keepalive_protocol.h"

uint8_t netchesszx_session_peer_ready_state;

void netchesszx_session_peer_reset(void)
{
    netchesszx_session_peer_ready_state = 0u;
}

void netchesszx_session_peer_mark_ready(void)
{
    netchesszx_session_peer_ready_state = 1u;
}

uint8_t netchesszx_session_peer_ready(void)
{
    return netchesszx_session_peer_ready_state;
}

uint8_t netchesszx_session_mqtt_can_accept_game_start(void)
{
    return (uint8_t)(netchesszx_session_peer_ready_state &&
                     netchesszx_host_color_ready &&
                     netchesszx_mqtt_session_id != 0u);
}

uint8_t netchesszx_session_event_ignores_retained(netchesszx_session_event_t event,
                                                   uint8_t retained)
{
    uint8_t e = (uint8_t)event;

    return (uint8_t)(retained &&
        ((e >= (uint8_t)NETCHESSZX_SESSION_EVENT_PING &&
          e <= (uint8_t)NETCHESSZX_SESSION_EVENT_HOST_BUSY) ||
         e == (uint8_t)NETCHESSZX_SESSION_EVENT_MQTT_PEER_OFFLINE ||
         e == (uint8_t)NETCHESSZX_SESSION_EVENT_MQTT_FOREIGN_HOST ||
         e == (uint8_t)NETCHESSZX_SESSION_EVENT_MQTT_TEXT));
}


uint8_t netchesszx_session_mqtt_host_flags(const char *payload,
                                           uint8_t game_active,
                                           uint8_t retained,
                                           uint8_t *bad_color)
{
    uint8_t host_color;
    uint8_t color_changed;
    uint8_t new_live_session;
    uint16_t retained_session_id;
    uint8_t flags = 0u;

    *bad_color = 0u;
    if (game_active) {
        return 0u;
    }
    if (retained) {
        if (!netchesszx_session_mqtt_parse_host_payload(payload,
                                                        &host_color,
                                                        &retained_session_id)) {
            *bad_color = 1u;
            return 0u;
        }
        return NETCHESSZX_SESSION_MQTT_HOST_RETAINED_WAIT;
    }
    host_color = netchesszx_session_mqtt_apply_host_color(payload,
                                                          game_active,
                                                          &color_changed,
                                                          &new_live_session);
    if (host_color == 0u) {
        *bad_color = 1u;
        return 0u;
    }
    if (new_live_session) {
        netchesszx_session_peer_ready_state = 0u;
    }
    if (color_changed) {
        flags |= NETCHESSZX_SESSION_MQTT_HOST_COLOR_CHANGED;
    }
    if (host_color == 2u) {
        flags |= NETCHESSZX_SESSION_MQTT_HOST_ACTIVATE_SIDE;
    }
    if ((host_color == 1u || host_color == 2u) && !netchesszx_session_peer_ready_state) {
        if (host_color == 1u) {
            flags |= NETCHESSZX_SESSION_MQTT_HOST_PUBLISH_SETUP;
        }
        netchesszx_session_peer_ready_state = 1u;
        flags |= NETCHESSZX_SESSION_MQTT_HOST_READY_WAIT;
    }
    return flags;
}

netchesszx_session_event_t netchesszx_session_classify_event(
    const char *payload,
    uint8_t is_mqtt,
    uint8_t retained,
    uint8_t is_host)
{
    if (!is_mqtt && netchess_direct_is_hello(payload)) {
        return NETCHESSZX_SESSION_EVENT_DIRECT_HELLO;
    }
    if (spectrum_keepalive_is_ack_ping(payload)) {
        return NETCHESSZX_SESSION_EVENT_ACK_PING;
    }
    if (spectrum_keepalive_is_ping(payload)) {
        return NETCHESSZX_SESSION_EVENT_PING;
    }

    {
        netchesszx_session_event_t event =
            netchesszx_session_classify_game_payload(payload);

        if (event != NETCHESSZX_SESSION_EVENT_UNKNOWN) {
            return event;
        }
    }

    if (!is_mqtt) {
        return NETCHESSZX_SESSION_EVENT_UNKNOWN;
    }
    if (payload[0] == '\0') {
        return NETCHESSZX_SESSION_EVENT_MQTT_EMPTY;
    }
    switch (payload[0]) {
    case 'F': {
        uint8_t relation =
            netchesszx_session_mqtt_side_relation(payload, 'F');

        /* F without the current session id is a stray client's will and
           cannot kill a live game. */
        if (relation == (NETCHESSZX_SESSION_MQTT_SIDE_REMOTE |
                         NETCHESSZX_SESSION_MQTT_SIDE_CURRENT)) {
            return NETCHESSZX_SESSION_EVENT_MQTT_PEER_OFFLINE;
        }
        if ((relation & NETCHESSZX_SESSION_MQTT_SIDE_LOCAL) != 0u) {
            return NETCHESSZX_SESSION_EVENT_MQTT_LOCAL_OFFLINE;
        }
        break;
    }
    case 'H':
        if (is_host &&
            netchesszx_session_mqtt_payload_is_foreign_host(payload)) {
            return NETCHESSZX_SESSION_EVENT_MQTT_FOREIGN_HOST;
        }
        if (!is_host && payload[1] == ' ') {
            return NETCHESSZX_SESSION_EVENT_MQTT_HOST;
        }
        break;
    case 'J':
        if (!retained &&
            netchesszx_session_mqtt_payload_marks_peer_ready(payload,
                                                             is_host)) {
            return NETCHESSZX_SESSION_EVENT_MQTT_PEER_READY;
        }
        break;
    case 'M':
        break;
    case 'O':
        /* Only a retained O for our own side AND the probed session proves
           occupancy. Stale sessions and live echoes fall through. */
        if (retained && !is_host &&
            netchesszx_session_mqtt_side_relation(payload, 'O') ==
                (NETCHESSZX_SESSION_MQTT_SIDE_LOCAL |
                 NETCHESSZX_SESSION_MQTT_SIDE_CURRENT)) {
            return NETCHESSZX_SESSION_EVENT_MQTT_SEAT_TAKEN;
        }
        break;
    default:
        return NETCHESSZX_SESSION_EVENT_MQTT_TEXT;
    }
    return NETCHESSZX_SESSION_EVENT_UNKNOWN;
}
