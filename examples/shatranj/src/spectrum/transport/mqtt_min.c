#include "spectrum/transport/mqtt_min.h"
#include "spectrum/transport/link.h"

#ifdef NETCHESSZX_SDCC_IY
uint8_t netchesszx_asm_mqtt_strlen8(const char *s) NETCHESSZX_FASTCALL;
void netchesszx_asm_mqtt_copy(uint8_t *dst, const uint8_t *src, uint8_t len);
#define mqtt_strlen8 netchesszx_asm_mqtt_strlen8
#define mqtt_copy netchesszx_asm_mqtt_copy
#else
static uint8_t mqtt_strlen8(const char *s)
{
    uint8_t n = 0u;
    while (s[n] != '\0') { ++n; }
    return n;
}

static void mqtt_copy(uint8_t *dst, const uint8_t *src, uint8_t len)
{
    while (len-- != 0u) { *dst++ = *src++; }
}
#endif

void spectrum_mqtt_broker_keepalive_reset(
    spectrum_mqtt_broker_keepalive_t *keepalive) NETCHESSZX_FASTCALL
{
    keepalive->idle_ticks = 0u;
    keepalive->misses = 0u;
}

uint8_t spectrum_mqtt_broker_keepalive_timeout(
    spectrum_mqtt_broker_keepalive_t *keepalive) NETCHESSZX_FASTCALL
{
    ++keepalive->idle_ticks;
    if (keepalive->idle_ticks < SPECTRUM_MQTT_KEEPALIVE_POLL_TICKS) {
        return SPECTRUM_MQTT_KEEPALIVE_NONE;
    }
    keepalive->idle_ticks = 0u;
    if (keepalive->misses >= SPECTRUM_MQTT_KEEPALIVE_MISSES_MAX) {
        return SPECTRUM_MQTT_KEEPALIVE_LOST;
    }
    ++keepalive->misses;
    return SPECTRUM_MQTT_KEEPALIVE_SEND;
}

uint8_t spectrum_mqtt_subscribe(uint8_t *out,
                                 uint8_t cap,
                                 uint16_t packet_id,
                                 const char *topic)
{
    uint8_t topic_len = mqtt_strlen8(topic);
    uint8_t remaining = (uint8_t)(2u + 2u + topic_len + 1u);
    uint8_t packet_len = (uint8_t)(2u + remaining);

    if (packet_id == 0u || topic_len > SPECTRUM_MQTT_TOPIC_MAX ||
        cap < packet_len) {
        return 0u;
    }
    out[0u] = 0x82u;
    out[1u] = remaining;
    out[2u] = (uint8_t)(packet_id >> 8);
    out[3u] = (uint8_t)packet_id;
    out[4u] = 0u;
    out[5u] = topic_len;
    mqtt_copy(out + 6u, (const uint8_t *)topic, topic_len);
    out[6u + topic_len] = 1u;
    return packet_len;
}

uint8_t spectrum_mqtt_publish(uint8_t *out,
                               uint8_t cap,
                               uint16_t packet_id,
                               const char *topic,
                               const char *payload,
                               uint8_t retain)
{
    uint8_t topic_len = mqtt_strlen8(topic);
    uint8_t payload_len = mqtt_strlen8(payload);
    uint8_t remaining = (uint8_t)(2u + topic_len + 2u + payload_len);
    uint8_t pos = (uint8_t)(remaining < 128u ? 2u : 3u);
    uint8_t packet_len = (uint8_t)(pos + remaining);

    if (packet_id == 0u || topic_len > SPECTRUM_MQTT_TOPIC_MAX ||
        payload_len > SPECTRUM_MQTT_PAYLOAD_MAX ||
        cap < packet_len) {
        return 0u;
    }
    out[0u] = (uint8_t)(0x32u | (retain ? 1u : 0u));
    out[1u] = remaining;
    if (pos == 3u) {
        out[2u] = 1u;
    }
    out[pos++] = 0u;
    out[pos++] = topic_len;
    mqtt_copy(out + pos, (const uint8_t *)topic, topic_len);
    pos = (uint8_t)(pos + topic_len);
    out[pos++] = (uint8_t)(packet_id >> 8);
    out[pos++] = (uint8_t)packet_id;
    mqtt_copy(out + pos, (const uint8_t *)payload, payload_len);
    return packet_len;
}

uint8_t spectrum_mqtt_type(const uint8_t *packet, uint8_t len)
{
    if (len == 0u) {
        return 0u;
    }
    return (uint8_t)(packet[0] >> 4);
}

int16_t spectrum_mqtt_parse_publish(const uint8_t *packet,
                                    uint8_t len,
                                    char *payload,
                                    uint8_t payload_cap,
                                    uint16_t *packet_id,
                                    uint8_t *flags)
{
    uint8_t remaining;
    uint8_t pos;
    uint8_t end;
    uint8_t topic_len;
    uint8_t payload_len;
    uint8_t qos;
    uint8_t b;

    *packet_id = 0u;
    *flags = 0u;
    if (len < 4u || (packet[0] >> 4) != SPECTRUM_MQTT_PUBLISH) {
        return -1;
    }
    *flags = (uint8_t)(packet[0] & SPECTRUM_LINK_PAYLOAD_RETAINED);
    b = packet[1u];
    remaining = (uint8_t)(b & 0x7fu);
    pos = 2u;
    if ((b & 0x80u) != 0u) {
        if (len < 5u || (packet[2u] & 0x80u) != 0u) {
            return -1;
        }
        remaining = (uint8_t)(remaining + ((uint8_t)(packet[2u] & 0x7fu) << 7));
        pos = 3u;
    }
    end = (uint8_t)(pos + remaining);
    if (len < end) {
        return -1;
    }
    qos = (uint8_t)((packet[0] >> 1) & 3u);
    if (qos > 1u) {
        return -1;
    }
    if ((uint8_t)(pos + 2u) > end) {
        return -1;
    }
    if (packet[pos] != 0u) {
        return -1;
    }
    topic_len = packet[pos + 1u];
    pos = (uint8_t)(pos + 2u);
    if (topic_len > (uint8_t)(end - pos)) {
        return -1;
    }
    if (topic_len >= 4u) {
        const uint8_t *suffix = packet + pos + topic_len - 4u;

        if (suffix[0] == '/' &&
            ((suffix[1] == 'w' && suffix[2] == '2' && suffix[3] == 'b') ||
             (suffix[1] == 'b' && suffix[2] == '2' && suffix[3] == 'w'))) {
            *flags |= SPECTRUM_LINK_PAYLOAD_GAME_ROUTE;
        }
    }
    pos = (uint8_t)(pos + topic_len);
    if (qos != 0u) {
        if ((uint8_t)(pos + 2u) > end) {
            return -1;
        }
        *packet_id = (uint16_t)(((uint16_t)packet[pos] << 8) | packet[pos + 1u]);
        pos = (uint8_t)(pos + 2u);
    }
    payload_len = (uint8_t)(end - pos);
    if (payload_cap == 0u || payload_len >= payload_cap) {
        return -1;
    }
    mqtt_copy((uint8_t *)payload, packet + pos, payload_len);
    payload[payload_len] = '\0';
    return (int16_t)payload_len;
}
