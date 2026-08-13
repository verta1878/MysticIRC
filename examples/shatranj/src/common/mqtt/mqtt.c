#include "common/mqtt/mqtt.h"

#include <string.h>

static size_t mqtt_strlen(const char *text)
{
    return text == 0 ? 0u : strlen(text);
}

static int mqtt_put_u8(uint8_t *out, size_t cap, size_t *pos, uint8_t value)
{
    if (*pos >= cap) {
        return 0;
    }
    out[*pos] = value;
    ++*pos;
    return 1;
}

static int mqtt_put_u16(uint8_t *out, size_t cap, size_t *pos, uint16_t value)
{
    return mqtt_put_u8(out, cap, pos, (uint8_t)(value >> 8)) &&
           mqtt_put_u8(out, cap, pos, (uint8_t)value);
}

static int mqtt_put_bytes(uint8_t *out,
                          size_t cap,
                          size_t *pos,
                          const uint8_t *src,
                          size_t len)
{
    if (len > cap || *pos > cap - len) {
        return 0;
    }
    if (len != 0u) {
        memcpy(out + *pos, src, len);
    }
    *pos += len;
    return 1;
}

static int mqtt_put_string(uint8_t *out, size_t cap, size_t *pos, const char *text)
{
    size_t len = mqtt_strlen(text);

    if (len > 65535u) {
        return 0;
    }
    return mqtt_put_u16(out, cap, pos, (uint16_t)len) &&
           mqtt_put_bytes(out, cap, pos, (const uint8_t *)text, len);
}

size_t netchess_mqtt_encode_remaining(uint32_t value, uint8_t *out, size_t cap)
{
    size_t pos = 0u;

    do {
        uint8_t byte = (uint8_t)(value & 0x7fu);
        value >>= 7;
        if (value != 0u) {
            byte = (uint8_t)(byte | 0x80u);
        }
        if (!mqtt_put_u8(out, cap, &pos, byte)) {
            return 0u;
        }
    } while (value != 0u && pos < 4u);

    if (value != 0u) {
        return 0u;
    }
    return pos;
}

static size_t mqtt_start_packet(uint8_t *out,
                                size_t cap,
                                uint8_t header,
                                uint32_t remaining,
                                size_t *pos)
{
    uint8_t enc[4];
    size_t enc_len;

    enc_len = netchess_mqtt_encode_remaining(remaining, enc, sizeof(enc));
    if (enc_len == 0u || cap < 1u + enc_len + remaining) {
        return 0u;
    }
    *pos = 0u;
    if (!mqtt_put_u8(out, cap, pos, header) ||
        !mqtt_put_bytes(out, cap, pos, enc, enc_len)) {
        return 0u;
    }
    return 1u;
}

size_t netchess_mqtt_encode_connect(uint8_t *out,
                                    size_t cap,
                                    const char *client_id,
                                    uint16_t keepalive,
                                    const char *will_topic,
                                    const char *will_payload,
                                    uint8_t will_retain)
{
    size_t pos;
    size_t client_len = mqtt_strlen(client_id);
    size_t will_topic_len = mqtt_strlen(will_topic);
    size_t will_payload_len = mqtt_strlen(will_payload);
    uint8_t flags = 0x02u;
    uint32_t remaining = 10u + 2u + (uint32_t)client_len;

    if (client_len > 65535u || will_topic_len > 65535u || will_payload_len > 65535u) {
        return 0u;
    }
    if (will_topic != 0 && will_payload != 0) {
        flags = (uint8_t)(flags | 0x04u | (will_retain ? 0x20u : 0u));
        remaining += 2u + (uint32_t)will_topic_len + 2u + (uint32_t)will_payload_len;
    }
    if (!mqtt_start_packet(out, cap, 0x10u, remaining, &pos)) {
        return 0u;
    }
    if (!mqtt_put_string(out, cap, &pos, "MQTT") ||
        !mqtt_put_u8(out, cap, &pos, 4u) ||
        !mqtt_put_u8(out, cap, &pos, flags) ||
        !mqtt_put_u16(out, cap, &pos, keepalive) ||
        !mqtt_put_string(out, cap, &pos, client_id)) {
        return 0u;
    }
    if (will_topic != 0 && will_payload != 0) {
        if (!mqtt_put_string(out, cap, &pos, will_topic) ||
            !mqtt_put_string(out, cap, &pos, will_payload)) {
            return 0u;
        }
    }
    return pos;
}

size_t netchess_mqtt_encode_subscribe(uint8_t *out,
                                      size_t cap,
                                      uint16_t packet_id,
                                      const char *topic,
                                      uint8_t qos)
{
    size_t pos;
    size_t topic_len = mqtt_strlen(topic);
    uint32_t remaining = 2u + 2u + (uint32_t)topic_len + 1u;

    if (topic_len > NETCHESSZX_MQTT_TOPIC_MAX || qos > 1u || packet_id == 0u) {
        return 0u;
    }
    if (!mqtt_start_packet(out, cap, 0x82u, remaining, &pos)) {
        return 0u;
    }
    if (!mqtt_put_u16(out, cap, &pos, packet_id) ||
        !mqtt_put_string(out, cap, &pos, topic) ||
        !mqtt_put_u8(out, cap, &pos, qos)) {
        return 0u;
    }
    return pos;
}

size_t netchess_mqtt_encode_unsubscribe(uint8_t *out,
                                        size_t cap,
                                        uint16_t packet_id,
                                        const char *topic)
{
    size_t pos;
    size_t topic_len = mqtt_strlen(topic);
    uint32_t remaining = 2u + 2u + (uint32_t)topic_len;

    if (topic_len > NETCHESSZX_MQTT_TOPIC_MAX || packet_id == 0u) {
        return 0u;
    }
    if (!mqtt_start_packet(out, cap, 0xa2u, remaining, &pos)) {
        return 0u;
    }
    if (!mqtt_put_u16(out, cap, &pos, packet_id) ||
        !mqtt_put_string(out, cap, &pos, topic)) {
        return 0u;
    }
    return pos;
}

size_t netchess_mqtt_encode_publish(uint8_t *out,
                                    size_t cap,
                                    uint16_t packet_id,
                                    const char *topic,
                                    const uint8_t *payload,
                                    uint16_t payload_len,
                                    uint8_t qos,
                                    uint8_t retain)
{
    size_t pos;
    size_t topic_len = mqtt_strlen(topic);
    uint8_t header;
    uint32_t remaining;

    if (topic_len > NETCHESSZX_MQTT_TOPIC_MAX ||
        payload_len > NETCHESSZX_MQTT_PAYLOAD_MAX ||
        qos > 1u ||
        (qos != 0u && packet_id == 0u)) {
        return 0u;
    }
    remaining = 2u + (uint32_t)topic_len + (uint32_t)payload_len;
    if (qos != 0u) {
        remaining += 2u;
    }
    header = (uint8_t)(0x30u | (uint8_t)(qos << 1) | (retain ? 1u : 0u));
    if (!mqtt_start_packet(out, cap, header, remaining, &pos)) {
        return 0u;
    }
    if (!mqtt_put_string(out, cap, &pos, topic)) {
        return 0u;
    }
    if (qos != 0u && !mqtt_put_u16(out, cap, &pos, packet_id)) {
        return 0u;
    }
    if (!mqtt_put_bytes(out, cap, &pos, payload, payload_len)) {
        return 0u;
    }
    return pos;
}

size_t netchess_mqtt_encode_puback(uint8_t *out, size_t cap, uint16_t packet_id)
{
    size_t pos;

    if (packet_id == 0u || !mqtt_start_packet(out, cap, 0x40u, 2u, &pos)) {
        return 0u;
    }
    return mqtt_put_u16(out, cap, &pos, packet_id) ? pos : 0u;
}

size_t netchess_mqtt_encode_pingreq(uint8_t *out, size_t cap)
{
    size_t pos;

    return mqtt_start_packet(out, cap, 0xc0u, 0u, &pos) ? pos : 0u;
}

size_t netchess_mqtt_encode_disconnect(uint8_t *out, size_t cap)
{
    size_t pos;

    return mqtt_start_packet(out, cap, 0xe0u, 0u, &pos) ? pos : 0u;
}

void netchess_mqtt_parser_init(netchess_mqtt_parser_t *parser)
{
    parser->len = 0u;
    parser->expected = 0u;
}

static uint16_t mqtt_get_u16(const uint8_t *data)
{
    return (uint16_t)(((uint16_t)data[0] << 8) | data[1]);
}

static int mqtt_decode_remaining(const uint8_t *buf,
                                 uint16_t len,
                                 uint32_t *remaining,
                                 uint8_t *used,
                                 uint8_t *malformed)
{
    uint32_t multiplier = 1u;
    uint32_t value = 0u;
    uint8_t i;

    *remaining = 0u;
    *used = 0u;
    *malformed = 0u;
    for (i = 1u; i < len && i < 5u; ++i) {
        uint8_t encoded = buf[i];
        value += (uint32_t)(encoded & 0x7fu) * multiplier;
        multiplier <<= 7;
        *used = i;
        if ((encoded & 0x80u) == 0u) {
            *remaining = value;
            return 1;
        }
    }
    if (len >= 5u && (buf[4] & 0x80u) != 0u) {
        *malformed = 1u;
        return -1;
    }
    return 0;
}

static int mqtt_read_string(const uint8_t *buf,
                            uint16_t end,
                            uint16_t *pos,
                            char *dst,
                            uint16_t dst_cap,
                            uint16_t *len_out)
{
    uint16_t len;

    if (*pos > end || (uint16_t)(end - *pos) < 2u) {
        return 0;
    }
    len = mqtt_get_u16(buf + *pos);
    *pos = (uint16_t)(*pos + 2u);
    if (len > end - *pos || len >= dst_cap) {
        return 0;
    }
    if (len != 0u) {
        memcpy(dst, buf + *pos, len);
    }
    dst[len] = '\0';
    *pos = (uint16_t)(*pos + len);
    if (len_out != 0) {
        *len_out = len;
    }
    return 1;
}

static int mqtt_parse_publish(const uint8_t *buf,
                              uint16_t end,
                              uint8_t flags,
                              netchess_mqtt_packet_t *packet)
{
    uint16_t pos = 0u;
    uint16_t topic_len = 0u;

    packet->qos = (uint8_t)((flags >> 1) & 0x03u);
    packet->retain = (uint8_t)(flags & 0x01u);
    if (packet->qos == 2u || packet->qos == 3u) {
        return 0;
    }
    if (!mqtt_read_string(buf, end, &pos, packet->topic, sizeof(packet->topic), &topic_len)) {
        return 0;
    }
    (void)topic_len;
    if (packet->qos != 0u) {
        if ((uint16_t)(end - pos) < 2u) {
            return 0;
        }
        packet->packet_id = mqtt_get_u16(buf + pos);
        pos = (uint16_t)(pos + 2u);
        if (packet->packet_id == 0u) {
            return 0;
        }
    }
    if ((uint16_t)(end - pos) > NETCHESSZX_MQTT_PAYLOAD_MAX) {
        return 0;
    }
    packet->payload_len = (uint16_t)(end - pos);
    if (packet->payload_len != 0u) {
        memcpy(packet->payload, buf + pos, packet->payload_len);
    }
    return 1;
}

static int mqtt_parse_packet(const uint8_t *buf,
                             uint16_t len,
                             uint8_t vli_used,
                             uint32_t remaining,
                             netchess_mqtt_packet_t *packet)
{
    uint16_t pos = (uint16_t)(1u + vli_used);
    uint16_t end = (uint16_t)(pos + remaining);
    uint8_t type = (uint8_t)(buf[0] >> 4);
    uint8_t flags = (uint8_t)(buf[0] & 0x0fu);

    if (len != end) {
        return 0;
    }
    memset(packet, 0, sizeof(*packet));
    packet->type = type;
    packet->flags = flags;

    switch (type) {
    case NETCHESS_MQTT_CONNACK:
        if (flags != 0u || remaining != 2u) {
            return 0;
        }
        packet->session_present = buf[pos];
        packet->return_code = buf[pos + 1u];
        return packet->session_present <= 1u;
    case NETCHESS_MQTT_PUBLISH:
        return mqtt_parse_publish(buf + pos, remaining, flags, packet);
    case NETCHESS_MQTT_UNSUBACK:
    case NETCHESS_MQTT_PUBACK:
        if (flags != 0u || remaining != 2u) {
            return 0;
        }
        packet->packet_id = mqtt_get_u16(buf + pos);
        return packet->packet_id != 0u;
    case NETCHESS_MQTT_SUBACK:
        if (flags != 0u || remaining < 3u) {
            return 0;
        }
        packet->packet_id = mqtt_get_u16(buf + pos);
        packet->return_code = buf[pos + 2u];
        return packet->packet_id != 0u &&
               (packet->return_code == 0u || packet->return_code == 1u ||
                packet->return_code == 0x80u);
    case NETCHESS_MQTT_PINGRESP:
        return flags == 0u && remaining == 0u;
    default:
        return 0;
    }
}

int netchess_mqtt_parser_feed(netchess_mqtt_parser_t *parser,
                              uint8_t byte,
                              netchess_mqtt_packet_t *packet)
{
    uint32_t remaining;
    uint8_t used;
    uint8_t malformed;
    int decoded;

    if (parser->len >= NETCHESSZX_MQTT_PACKET_MAX) {
        netchess_mqtt_parser_init(parser);
        return NETCHESSZX_MQTT_ERROR;
    }
    parser->buf[parser->len++] = byte;

    if (parser->len < 2u) {
        return NETCHESSZX_MQTT_NEED_MORE;
    }

    decoded = mqtt_decode_remaining(parser->buf,
                                    parser->len,
                                    &remaining,
                                    &used,
                                    &malformed);
    if (decoded < 0 || malformed || remaining > NETCHESSZX_MQTT_PACKET_MAX) {
        netchess_mqtt_parser_init(parser);
        return NETCHESSZX_MQTT_ERROR;
    }
    if (decoded == 0) {
        return NETCHESSZX_MQTT_NEED_MORE;
    }

    if (1u + used + remaining > NETCHESSZX_MQTT_PACKET_MAX) {
        netchess_mqtt_parser_init(parser);
        return NETCHESSZX_MQTT_ERROR;
    }
    parser->expected = (uint16_t)(1u + used + remaining);
    if (parser->len < parser->expected) {
        return NETCHESSZX_MQTT_NEED_MORE;
    }
    if (parser->len > parser->expected ||
        !mqtt_parse_packet(parser->buf, parser->len, used, remaining, packet)) {
        netchess_mqtt_parser_init(parser);
        return NETCHESSZX_MQTT_ERROR;
    }

    netchess_mqtt_parser_init(parser);
    return NETCHESSZX_MQTT_PACKET_READY;
}
