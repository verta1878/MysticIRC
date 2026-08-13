#include "common/protocol/mqtt_session_protocol.h"

char netchess_mqtt_session_color_char(uint8_t color)
{
    return color == NETCHESS_MQTT_SESSION_COLOR_BLACK ? 'B' : 'W';
}

static uint8_t mqtt_session_init_out(char *out,
                                     uint8_t cap,
                                     char **p,
                                     char **end)
{
    if (cap == 0u) {
        return 0u;
    }
    *p = out;
    *end = out + cap - 1u;
    out[0] = '\0';
    return 1u;
}

static uint8_t mqtt_session_append_char(char **p, const char *end, char c)
{
    if (*p >= end) {
        return 0u;
    }
    **p = c;
    ++*p;
    **p = '\0';
    return 1u;
}

static uint8_t mqtt_session_append_text(char **p,
                                        const char *end,
                                        const char *text)
{
    while (*text != '\0') {
        if (!mqtt_session_append_char(p, end, *text++)) {
            return 0u;
        }
    }
    return 1u;
}

static uint8_t mqtt_session_append_u16(char **p,
                                       const char *end,
                                       uint16_t value)
{
    char tmp[6];
    uint8_t n = 0u;

    if (value == 0u) {
        return mqtt_session_append_char(p, end, '0');
    }
    while (value != 0u && n < sizeof(tmp)) {
        tmp[n++] = (char)('0' + (uint8_t)(value % 10u));
        value = (uint16_t)(value / 10u);
    }
    while (n != 0u) {
        --n;
        if (!mqtt_session_append_char(p, end, tmp[n])) {
            return 0u;
        }
    }
    return 1u;
}

uint8_t netchess_mqtt_session_format_host(char *out,
                                          uint8_t out_cap,
                                          uint8_t host_color,
                                          uint16_t session_id)
{
    char *p;
    char *end;

    if (session_id == 0u ||
        !mqtt_session_init_out(out, out_cap, &p, &end) ||
        !mqtt_session_append_text(&p, end, NETCHESS_MQTT_SESSION_HOST_PREFIX) ||
        !mqtt_session_append_char(&p, end,
                                  netchess_mqtt_session_color_char(host_color)) ||
        !mqtt_session_append_char(&p, end, ' ') ||
        !mqtt_session_append_u16(&p, end, session_id)) {
        return 0u;
    }
    return 1u;
}

uint8_t netchess_mqtt_session_format_join(char *out,
                                          uint8_t out_cap,
                                          uint16_t session_id)
{
    char *p;
    char *end;

    if (session_id == 0u ||
        !mqtt_session_init_out(out, out_cap, &p, &end) ||
        !mqtt_session_append_text(&p, end, NETCHESS_MQTT_SESSION_JOIN_PREFIX) ||
        !mqtt_session_append_u16(&p, end, session_id)) {
        return 0u;
    }
    return 1u;
}

uint8_t netchess_mqtt_session_format_side(char *out,
                                          uint8_t out_cap,
                                          char verb,
                                          char side,
                                          uint16_t session_id,
                                          uint8_t include_session_id)
{
    char *p;
    char *end;

    if ((verb != NETCHESS_MQTT_SESSION_VERB_ONLINE &&
         verb != NETCHESS_MQTT_SESSION_VERB_OFFLINE) ||
        (side != 'W' && side != 'B') ||
        !mqtt_session_init_out(out, out_cap, &p, &end) ||
        !mqtt_session_append_char(&p, end, verb) ||
        !mqtt_session_append_char(&p, end, ' ') ||
        !mqtt_session_append_char(&p, end, side)) {
        return 0u;
    }
    if (include_session_id) {
        if (session_id == 0u ||
            !mqtt_session_append_char(&p, end, ' ') ||
            !mqtt_session_append_u16(&p, end, session_id)) {
            return 0u;
        }
    }
    return 1u;
}
