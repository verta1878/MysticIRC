#ifndef NETCHESSZX_SPECTRUM_NET_H
#define NETCHESSZX_SPECTRUM_NET_H

#include <stdint.h>
#include "spectrum/config/session.h"
#include "spectrum/transport/link.h"

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

#define SPECTRUM_NET_PAYLOAD_MAX SPECTRUM_LINK_PAYLOAD_MAX
#define SPECTRUM_NET_LINE_MAX 48u
#define SPECTRUM_NET_DIRECT_TX_PAYLOAD_CAP 64u
#define SPECTRUM_NET_DIRECT_RX_QUEUE_COUNT 3u
#define SPECTRUM_NET_READ_TIMEOUT SPECTRUM_LINK_READ_TIMEOUT
#define SPECTRUM_NET_PAYLOAD_RETAINED 0x01u

void spectrum_net_start_uart(void);
const char *spectrum_net_last_ip(void);
uint8_t spectrum_net_listen(void);
uint8_t spectrum_net_connect_host(void);
uint8_t spectrum_net_sync_time(void);
uint8_t spectrum_net_wait_pc_connect(void);
void spectrum_net_direct_peer_mark_valid(void);
int16_t spectrum_net_read_payload(char *payload, uint8_t payload_cap);
uint8_t spectrum_net_send_text(const char *text) NETCHESSZX_FASTCALL;
uint8_t spectrum_net_send_ping(void);
char *spectrum_net_payload_scratch(void);
uint8_t spectrum_net_link_activity(void);
uint8_t spectrum_net_payload_flags(void);
void spectrum_net_background_drain(void);
uint8_t spectrum_net_at_cmd(const char *cmd, uint16_t frames);
void spectrum_net_guard_wait(uint16_t frames) NETCHESSZX_FASTCALL;
uint8_t spectrum_net_ensure_command_mode(void);
const char *spectrum_net_mqtt_out_suffix(void);
const char *spectrum_net_mqtt_in_suffix(void);
const char *spectrum_net_mqtt_out_ack_suffix(void);
const char *spectrum_net_mqtt_in_ack_suffix(void);
const char *spectrum_net_mqtt_presence_suffix(void);
const char *spectrum_net_mqtt_peer_presence_suffix(void);
const char *spectrum_net_mqtt_presence_payload(void);
void spectrum_net_mqtt_setup_payload(char *out) NETCHESSZX_FASTCALL;
uint8_t spectrum_net_mqtt_activate_side(void);
uint8_t spectrum_net_mqtt_probe_seat(void);
uint8_t spectrum_net_mqtt_publish_presence(void);
uint8_t spectrum_net_mqtt_publish_offline(uint8_t route) NETCHESSZX_FASTCALL;
uint8_t spectrum_net_mqtt_start(void);
int16_t spectrum_net_mqtt_read_payload(char *payload, uint8_t payload_cap);
uint8_t spectrum_net_mqtt_send_text(const char *text) NETCHESSZX_FASTCALL;
uint8_t spectrum_net_mqtt_publish_setup(uint8_t mode) NETCHESSZX_FASTCALL;

#endif
