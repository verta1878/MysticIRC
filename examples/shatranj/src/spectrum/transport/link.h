#ifndef NETCHESSZX_SPECTRUM_LINK_H
#define NETCHESSZX_SPECTRUM_LINK_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

#define SPECTRUM_LINK_PAYLOAD_MAX 48u
#define SPECTRUM_LINK_READ_TIMEOUT (-3)
#define SPECTRUM_LINK_CANCELLED 2u
#define SPECTRUM_LINK_PAYLOAD_RETAINED 0x01u
#define SPECTRUM_LINK_PAYLOAD_GAME_ROUTE 0x02u
#define SPECTRUM_LINK_PREFLIGHT_FAILED 0u
#define SPECTRUM_LINK_PREFLIGHT_OK 1u
#define SPECTRUM_LINK_PREFLIGHT_RETRYING 2u
#define SPECTRUM_LINK_PREFLIGHT_OVL_FAIL 3u
#define SPECTRUM_LINK_MQTT_SETUP_LIVE 0u
#define SPECTRUM_LINK_MQTT_SETUP_RETAINED 1u
#define SPECTRUM_LINK_MQTT_SETUP_CLEAR 2u
/* Compact mirrors of the stable common session-route ABI. */
#define SPECTRUM_LINK_ROUTE_PRESENCE 2u
#define SPECTRUM_LINK_ROUTE_PRESENCE_PEER 5u

/* Transport contract shared by Spectrum and Next:
   - read_payload() copies a transport-owned RX payload into caller storage.
   - payload_scratch() returns storage unused by the active backend; it may
     borrow inactive-backend storage but never the active RX queue/parser.
   - send_text(), send_ping(), and background_drain() may pump the transport,
     but must not destroy a queued RX payload before read_payload() copies it.
   - link state belongs here; board/game/session state belongs above this API. */

void spectrum_net_start_uart(void);
uint8_t spectrum_net_listen(void);
uint8_t spectrum_net_connect_host(void);
uint8_t spectrum_net_wait_pc_connect(void);
void spectrum_net_direct_peer_mark_valid(void);
int16_t spectrum_net_read_payload(char *payload, uint8_t payload_cap);
uint8_t spectrum_net_send_text(const char *text) NETCHESSZX_FASTCALL;
uint8_t spectrum_net_send_ping(void);
char *spectrum_net_payload_scratch(void);
uint8_t spectrum_net_link_activity(void);
uint8_t spectrum_net_payload_flags(void);
void spectrum_net_background_drain(void);
uint8_t spectrum_net_preflight_run(void);
const char *spectrum_net_last_ip(void);
uint8_t spectrum_net_sync_time(void);

#define spectrum_link_start_uart spectrum_net_start_uart
#define spectrum_link_listen spectrum_net_listen
#define spectrum_link_connect_host spectrum_net_connect_host
#define spectrum_link_wait_pc_connect spectrum_net_wait_pc_connect
#define spectrum_link_direct_peer_mark_valid spectrum_net_direct_peer_mark_valid
#define spectrum_link_read_payload spectrum_net_read_payload
#define spectrum_link_send_text spectrum_net_send_text
#define spectrum_link_send_ping spectrum_net_send_ping
#define spectrum_link_payload_scratch spectrum_net_payload_scratch
#define spectrum_link_activity spectrum_net_link_activity
#define spectrum_link_payload_flags spectrum_net_payload_flags
#define spectrum_link_background_drain spectrum_net_background_drain
#define spectrum_link_preflight_run spectrum_net_preflight_run
#define spectrum_link_last_ip spectrum_net_last_ip
#define spectrum_link_sync_time spectrum_net_sync_time

uint8_t spectrum_net_mqtt_start(void);
uint8_t spectrum_net_mqtt_activate_side(void);
uint8_t spectrum_net_mqtt_probe_seat(void);
uint8_t spectrum_net_mqtt_publish_presence(void);
uint8_t spectrum_net_mqtt_publish_offline(uint8_t route) NETCHESSZX_FASTCALL;
uint8_t spectrum_net_mqtt_publish_setup(uint8_t mode) NETCHESSZX_FASTCALL;

#define spectrum_link_mqtt_start spectrum_net_mqtt_start
#define spectrum_link_mqtt_activate_side spectrum_net_mqtt_activate_side
#define spectrum_link_mqtt_probe_seat spectrum_net_mqtt_probe_seat
#define spectrum_link_mqtt_publish_presence spectrum_net_mqtt_publish_presence
#define spectrum_link_mqtt_publish_offline spectrum_net_mqtt_publish_offline
#define spectrum_link_mqtt_publish_setup spectrum_net_mqtt_publish_setup

#endif
