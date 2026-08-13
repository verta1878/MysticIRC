#ifndef NETCHESSZX_SPECTRUM_SESSION_MQTT_H
#define NETCHESSZX_SPECTRUM_SESSION_MQTT_H

#include "common/protocol/mqtt_session_protocol.h"

#include <stdint.h>

#define netchesszx_session_mqtt_parse_host_payload(payload, host_color, session_id) \
    netchess_mqtt_session_parse_host((payload), (host_color), (session_id))
#define netchesszx_session_mqtt_parse_join_payload(payload, session_id) \
    netchess_mqtt_session_parse_join((payload), (session_id))
#define NETCHESSZX_SESSION_MQTT_SIDE_LOCAL 0x01u
#define NETCHESSZX_SESSION_MQTT_SIDE_REMOTE 0x02u
#define NETCHESSZX_SESSION_MQTT_SIDE_CURRENT 0x04u
uint8_t netchesszx_session_mqtt_side_relation(const char *payload, char verb);
uint8_t netchesszx_session_mqtt_payload_is_foreign_host(const char *payload);
uint8_t netchesszx_session_mqtt_payload_marks_peer_ready(const char *payload,
                                                         uint8_t is_host);
uint8_t netchesszx_session_mqtt_apply_host_color(const char *payload,
                                                 uint8_t game_active,
                                                 uint8_t *color_changed,
                                                 uint8_t *new_live_session);

#endif
