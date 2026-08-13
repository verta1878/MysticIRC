#include "spectrum/transport/net.h"

#include "common/protocol/mqtt_session_protocol.h"
#include "spectrum/config/session.h"
#include "spectrum/lowram_map.h"
#include "spectrum/platform/text.h"

#ifdef NETCHESSZX_HOST_SESSION_TEST
static char mqtt_presence_payload[16];
#else
#define mqtt_presence_payload ((char *)NETCHESSZX_LOWRAM_MQTT_PRESENCE_ADDR)
#endif

#define MQTT_SUFFIX_OUT 0u
#define MQTT_SUFFIX_IN 1u
#define MQTT_SUFFIX_OUT_ACK 2u
#define MQTT_SUFFIX_IN_ACK 3u
#define MQTT_SUFFIX_PRESENCE 4u
#define MQTT_SUFFIX_PEER_PRESENCE 5u

static const char mqtt_suffix_w2b[] = "w2b";
static const char mqtt_suffix_b2w[] = "b2w";
static const char mqtt_suffix_ack_b[] = "ack_b";
static const char mqtt_suffix_ack_w[] = "ack_w";
static const char mqtt_suffix_pres_w[] = "pres_w";
static const char mqtt_suffix_pres_b[] = "pres_b";

static const char *const mqtt_side_suffixes[] = {
    mqtt_suffix_w2b, mqtt_suffix_b2w,
    mqtt_suffix_ack_b, mqtt_suffix_ack_w,
    mqtt_suffix_pres_w, mqtt_suffix_pres_b
};

static uint8_t mqtt_presence_offline;

static const char *mqtt_side_suffix(uint8_t pair_index) __z88dk_fastcall
{
    return mqtt_side_suffixes[(uint8_t)(pair_index ^
        (netchesszx_local_is_white() ? 0u : 1u))];
}

const char *spectrum_net_mqtt_out_suffix(void)
{
    return mqtt_side_suffix(MQTT_SUFFIX_OUT);
}

const char *spectrum_net_mqtt_in_suffix(void)
{
    return mqtt_side_suffix(MQTT_SUFFIX_IN);
}

const char *spectrum_net_mqtt_out_ack_suffix(void)
{
    return mqtt_side_suffix(MQTT_SUFFIX_OUT_ACK);
}

const char *spectrum_net_mqtt_in_ack_suffix(void)
{
    return mqtt_side_suffix(MQTT_SUFFIX_IN_ACK);
}

const char *spectrum_net_mqtt_presence_suffix(void)
{
    return mqtt_presence_offline == SPECTRUM_LINK_ROUTE_PRESENCE_PEER
        ? spectrum_net_mqtt_peer_presence_suffix()
        : mqtt_side_suffix(MQTT_SUFFIX_PRESENCE);
}

const char *spectrum_net_mqtt_peer_presence_suffix(void)
{
    return mqtt_side_suffix(MQTT_SUFFIX_PEER_PRESENCE);
}

const char *spectrum_net_mqtt_presence_payload(void)
{
    uint8_t white = (uint8_t)(netchesszx_local_is_white() ^
        (mqtt_presence_offline == SPECTRUM_LINK_ROUTE_PRESENCE_PEER));
    const char *prefix = mqtt_presence_offline
        ? (white ? NETCHESS_MQTT_SESSION_OFFLINE_WHITE_PREFIX
                 : NETCHESS_MQTT_SESSION_OFFLINE_BLACK_PREFIX)
        : (white ? NETCHESS_MQTT_SESSION_ONLINE_WHITE_PREFIX
                 : NETCHESS_MQTT_SESSION_ONLINE_BLACK_PREFIX);
    char *p = spectrum_append_text(mqtt_presence_payload, prefix);

    (void)spectrum_append_u16(p, netchesszx_mqtt_session_id);
    return mqtt_presence_payload;
}

void spectrum_net_mqtt_setup_payload(char *out) NETCHESSZX_FASTCALL
{
    char *p;

    if (netchesszx_session_is_host()) {
        p = spectrum_append_text(out, NETCHESS_MQTT_SESSION_HOST_PREFIX);
        *p++ = netchesszx_local_side_char();
        *p++ = ' ';
        (void)spectrum_append_u16(p, netchesszx_mqtt_session_id);
        return;
    }
    p = spectrum_append_text(out, NETCHESS_MQTT_SESSION_JOIN_PREFIX);
    (void)spectrum_append_u16(p, netchesszx_mqtt_session_id);
}

/* Retained offline marker (F <side> <sid>) over a retained presence O.
   A host releasing its own seat also clears retained H metadata; peer-seat
   releases keep H because the host remains available for a replacement. */
uint8_t spectrum_net_mqtt_publish_offline(uint8_t route) NETCHESSZX_FASTCALL
{
    uint8_t result;

    mqtt_presence_offline = route;
    result = spectrum_net_mqtt_publish_presence();
    mqtt_presence_offline = 0u;
    if (result && route == SPECTRUM_LINK_ROUTE_PRESENCE &&
        netchesszx_session_is_host()) {
        result = spectrum_net_mqtt_publish_setup(
            SPECTRUM_LINK_MQTT_SETUP_CLEAR);
    }
    return result;
}
