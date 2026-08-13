#include "common/protocol/mqtt_session_protocol.h"

#ifndef NETCHESSZX_SDCC_IY
const char *netchess_mqtt_session_parse_u16_token(const char *p, uint16_t *out)
{
    uint16_t value = 0u;
    uint8_t digits = 0u;
    uint8_t digit;

    while (*p >= '0' && *p <= '9') {
        digit = (uint8_t)(*p - '0');
        if (value > 6553u || (value == 6553u && digit > 5u)) {
            return 0;
        }
        value = (uint16_t)((value << 3) + (value << 1) + (uint16_t)digit);
        ++p;
        ++digits;
    }
    if (digits == 0u) {
        return 0;
    }
    *out = value;
    return p;
}
#endif

uint8_t netchess_mqtt_session_color_value(char color, uint8_t *out)
{
    if (color == 'W') {
        *out = NETCHESS_MQTT_SESSION_COLOR_WHITE;
        return 1u;
    }
    if (color == 'B') {
        *out = NETCHESS_MQTT_SESSION_COLOR_BLACK;
        return 1u;
    }
    return 0u;
}

uint8_t netchess_mqtt_session_parse_host(const char *payload,
                                         uint8_t *host_color,
                                         uint16_t *session_id)
{
    const char *p;

    if (payload[0] != 'H' || payload[1] != ' ') {
        return 0u;
    }
    if (!netchess_mqtt_session_color_value(payload[2u], host_color)) {
        return 0u;
    }
    if (payload[3u] != ' ') {
        return 0u;
    }
    p = netchess_mqtt_session_parse_u16_token(payload + 4u, session_id);
    if (p == 0 || *session_id == 0u) {
        return 0u;
    }
    return (uint8_t)(*p == '\0');
}

uint8_t netchess_mqtt_session_parse_join(const char *payload,
                                         uint16_t *session_id)
{
    const char *p;

    if (payload[0] != 'J' || payload[1] != ' ') {
        return 0u;
    }
    p = netchess_mqtt_session_parse_u16_token(payload + 2u, session_id);
    if (p == 0 || *session_id == 0u) {
        return 0u;
    }
    return (uint8_t)(*p == '\0');
}

uint8_t netchess_mqtt_session_parse_side(const char *payload,
                                         char verb,
                                         char *side,
                                         uint16_t *session_id,
                                         uint8_t *has_session_id)
{
    const char *p;

    if (payload[0] != verb || payload[1] != ' ') {
        return 0u;
    }
    if (payload[2u] != 'W' && payload[2u] != 'B') {
        return 0u;
    }
    *side = payload[2u];
    if (payload[3u] == '\0') {
        *session_id = 0u;
        *has_session_id = 0u;
        return 1u;
    }
    if (payload[3u] != ' ') {
        return 0u;
    }
    p = netchess_mqtt_session_parse_u16_token(payload + 4u, session_id);
    if (p == 0 || *p != '\0' || *session_id == 0u) {
        return 0u;
    }
    *has_session_id = 1u;
    return 1u;
}
