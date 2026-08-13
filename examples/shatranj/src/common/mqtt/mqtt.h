#ifndef NETCHESSZX_NET_MQTT_H
#define NETCHESSZX_NET_MQTT_H

#include <stddef.h>
#include <stdint.h>

#define NETCHESSZX_MQTT_PACKET_MAX 512u
#define NETCHESSZX_MQTT_TOPIC_MAX 40u
#define NETCHESSZX_MQTT_PAYLOAD_MAX 192u

#define NETCHESSZX_MQTT_NEED_MORE 0
#define NETCHESSZX_MQTT_PACKET_READY 1
#define NETCHESSZX_MQTT_ERROR -1

enum netchess_mqtt_type {
    NETCHESS_MQTT_CONNECT = 1,
    NETCHESS_MQTT_CONNACK = 2,
    NETCHESS_MQTT_PUBLISH = 3,
    NETCHESS_MQTT_PUBACK = 4,
    NETCHESS_MQTT_SUBSCRIBE = 8,
    NETCHESS_MQTT_SUBACK = 9,
    NETCHESS_MQTT_UNSUBSCRIBE = 10,
    NETCHESS_MQTT_UNSUBACK = 11,
    NETCHESS_MQTT_PINGREQ = 12,
    NETCHESS_MQTT_PINGRESP = 13,
    NETCHESS_MQTT_DISCONNECT = 14
};

typedef struct netchess_mqtt_packet {
    uint8_t type;
    uint8_t flags;
    uint8_t qos;
    uint8_t retain;
    uint8_t session_present;
    uint8_t return_code;
    uint16_t packet_id;
    char topic[NETCHESSZX_MQTT_TOPIC_MAX + 1u];
    uint8_t payload[NETCHESSZX_MQTT_PAYLOAD_MAX];
    uint16_t payload_len;
} netchess_mqtt_packet_t;

typedef struct netchess_mqtt_parser {
    uint8_t buf[NETCHESSZX_MQTT_PACKET_MAX];
    uint16_t len;
    uint16_t expected;
} netchess_mqtt_parser_t;

void netchess_mqtt_parser_init(netchess_mqtt_parser_t *parser);
int netchess_mqtt_parser_feed(netchess_mqtt_parser_t *parser,
                              uint8_t byte,
                              netchess_mqtt_packet_t *packet);

size_t netchess_mqtt_encode_remaining(uint32_t value,
                                      uint8_t *out,
                                      size_t cap);
size_t netchess_mqtt_encode_connect(uint8_t *out,
                                    size_t cap,
                                    const char *client_id,
                                    uint16_t keepalive,
                                    const char *will_topic,
                                    const char *will_payload,
                                    uint8_t will_retain);
size_t netchess_mqtt_encode_subscribe(uint8_t *out,
                                      size_t cap,
                                      uint16_t packet_id,
                                      const char *topic,
                                      uint8_t qos);
size_t netchess_mqtt_encode_unsubscribe(uint8_t *out,
                                        size_t cap,
                                        uint16_t packet_id,
                                        const char *topic);
size_t netchess_mqtt_encode_publish(uint8_t *out,
                                    size_t cap,
                                    uint16_t packet_id,
                                    const char *topic,
                                    const uint8_t *payload,
                                    uint16_t payload_len,
                                    uint8_t qos,
                                    uint8_t retain);
size_t netchess_mqtt_encode_puback(uint8_t *out, size_t cap, uint16_t packet_id);
size_t netchess_mqtt_encode_pingreq(uint8_t *out, size_t cap);
size_t netchess_mqtt_encode_disconnect(uint8_t *out, size_t cap);

#endif
