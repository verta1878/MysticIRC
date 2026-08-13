#ifndef NETCHESSZX_SPECTRUM_MQTT_MIN_H
#define NETCHESSZX_SPECTRUM_MQTT_MIN_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

#define SPECTRUM_MQTT_PACKET_MAX 160u
#define SPECTRUM_MQTT_TOPIC_MAX 48u
#define SPECTRUM_MQTT_PAYLOAD_MAX 96u
/* Runtime assets (screen.asm EQUs, loaded at 0x6000) end at
   piece_sprites_16x16 + 384 = 0x64ac. The MQTT stream and packet scratch sit
   between that end and the overlay slot at 0x6800. check_lowmem_layout.py
   verifies this against the .map on every tap build. */
#define SPECTRUM_MQTT_RUNTIME_ASSETS_END 0x64acu
#define SPECTRUM_MQTT_SCRATCH_BASE 0x658bu
#define SPECTRUM_MQTT_PACKET_SCRATCH ((uint8_t *)SPECTRUM_MQTT_SCRATCH_BASE)

#define SPECTRUM_MQTT_CONNACK 2u
#define SPECTRUM_MQTT_PUBLISH 3u
#define SPECTRUM_MQTT_PUBACK 4u
#define SPECTRUM_MQTT_SUBACK 9u
#define SPECTRUM_MQTT_PINGRESP 13u
#define SPECTRUM_MQTT_PINGREQ_HEADER 0xc0u

#define SPECTRUM_MQTT_KEEPALIVE_NONE 0u
#define SPECTRUM_MQTT_KEEPALIVE_SEND 1u
#define SPECTRUM_MQTT_KEEPALIVE_LOST 2u
/* net.c waits two frames per empty poll: 10s at 50 Hz, 8.3s at 60 Hz. */
#define SPECTRUM_MQTT_KEEPALIVE_POLL_TICKS 250u
#define SPECTRUM_MQTT_KEEPALIVE_MISSES_MAX 2u

typedef struct spectrum_mqtt_broker_keepalive {
    uint8_t idle_ticks;
    uint8_t misses;
} spectrum_mqtt_broker_keepalive_t;

void spectrum_mqtt_broker_keepalive_reset(
    spectrum_mqtt_broker_keepalive_t *keepalive) NETCHESSZX_FASTCALL;
uint8_t spectrum_mqtt_broker_keepalive_timeout(
    spectrum_mqtt_broker_keepalive_t *keepalive) NETCHESSZX_FASTCALL;

uint8_t spectrum_mqtt_subscribe(uint8_t *out,
                                 uint8_t cap,
                                 uint16_t packet_id,
                                 const char *topic);
uint8_t spectrum_mqtt_publish(uint8_t *out,
                               uint8_t cap,
                               uint16_t packet_id,
                               const char *topic,
                               const char *payload,
                               uint8_t retain);
uint8_t spectrum_mqtt_type(const uint8_t *packet, uint8_t len);
int16_t spectrum_mqtt_parse_publish(const uint8_t *packet,
                                    uint8_t len,
                                    char *payload,
                                    uint8_t payload_cap,
                                    uint16_t *packet_id,
                                    uint8_t *flags);

#endif
