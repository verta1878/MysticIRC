#include "spectrum/transport/net.h"

#include "spectrum/config/session.h"
#include "spectrum/platform/net_runtime.h"
#include "spectrum/transport/mqtt_min.h"
#include "spectrum/transport/esp_at.h"
#include "spectrum/lowram_map.h"
#include "spectrum/overlay/overlay.h"
#include "spectrum/platform/platform.h"

#ifdef NETCHESSZX_SDCC_IY
void netchesszx_asm_net_copy(uint8_t *dst, const uint8_t *src, uint16_t len);
void netchesszx_asm_net_move(uint8_t *dst, const uint8_t *src, uint16_t len);
#define net_copy netchesszx_asm_net_copy
#define net_move netchesszx_asm_net_move
#else
static void net_copy(uint8_t *dst, const uint8_t *src, uint16_t len)
{
    while (len-- != 0u) { *dst++ = *src++; }
}

static void net_move(uint8_t *dst, const uint8_t *src, uint16_t len)
{
    if (dst < src) {
        while (len-- != 0u) { *dst++ = *src++; }
    } else {
        dst += len; src += len;
        while (len-- != 0u) { *--dst = *--src; }
    }
}
#endif

#define WAIT_MED 500
#define WAIT_POLL 2
#define MQTT_STREAM_BACKGROUND_DRAIN_BUDGET 64u
#define SPECTRUM_NET_MQTT_READ_TIMEOUT (-4)

uint8_t active_link;
char direct_rx_payload[SPECTRUM_NET_PAYLOAD_MAX];
char direct_rx_payload2[SPECTRUM_NET_PAYLOAD_MAX];
uint8_t direct_rx_link;
uint8_t direct_rx_link2;
uint8_t direct_rx_count;
uint8_t direct_rx_head;
uint8_t direct_rx_payload_len;
uint16_t direct_ipd_remaining;
uint8_t direct_ipd_accept;
uint8_t direct_ipd_link;
uint8_t direct_link_closed;
uint8_t direct_peer_valid;
/* Link id of a third party that connected while a session is active; 0xff =
   none. The DIRECT overlay closes it without dropping the active session. */
uint8_t direct_intruder_link = 0xffu;
static uint8_t net_link_activity;
static uint8_t net_payload_flags;

static void direct_reset_rx_state(void);
static uint8_t mqtt_drain_uart_budget(uint8_t budget) __z88dk_fastcall;

void spectrum_net_background_drain(void)
{
    if (!netchesszx_transport_is_mqtt()) {
        /* DIRECT: stockpile raw UART bytes in the platform ring while the app
           is blocked; the DIRECT overlay parses them on its next read. */
        spectrum_uart_background_pump();
        return;
    }
    (void)mqtt_drain_uart_budget(MQTT_STREAM_BACKGROUND_DRAIN_BUDGET);
}

uint8_t spectrum_net_link_activity(void)
{
    uint8_t activity = net_link_activity;

    net_link_activity = 0u;
    return activity;
}

uint8_t spectrum_net_payload_flags(void)
{
    return net_payload_flags;
}

char *spectrum_net_payload_scratch(void)
{
    /* Each transport lends storage owned only by the inactive backend:
       MQTT uses the first DIRECT queue slot (the second stores a queued
       publish); DIRECT uses the MQTT packet scratch below the overlay slot. */
    return netchesszx_transport_is_mqtt()
        ? direct_rx_payload
        : (char *)SPECTRUM_MQTT_PACKET_SCRATCH;
}

void spectrum_net_start_uart(void)
{
    spectrum_uart_init();
    spectrum_uart_flush(25u);
    direct_reset_rx_state();
    reset_line_buf();
}

static void direct_reset_rx_state(void)
{
    direct_rx_count = 0u;
    direct_rx_head = 0u;
    direct_rx_payload_len = 0u;
    direct_ipd_remaining = 0u;
    direct_ipd_accept = 0u;
    direct_ipd_link = 0u;
    direct_link_closed = 0u;
    direct_peer_valid = 0u;
    direct_intruder_link = 0xffu;
    reset_line_buf();
}

void spectrum_net_direct_peer_mark_valid(void)
{
    direct_peer_valid = 1u;
}


uint8_t spectrum_net_listen(void)
{
    direct_reset_rx_state();
    return spectrum_overlay_exec(SPECTRUM_OVL_DIRECT,
                                 SPECTRUM_OVL_DIRECT_LISTEN);
}

uint8_t spectrum_net_connect_host(void)
{
    direct_reset_rx_state();
    return spectrum_overlay_exec(SPECTRUM_OVL_DIRECT,
                                 SPECTRUM_OVL_DIRECT_CONNECT);
}

uint8_t spectrum_net_wait_pc_connect(void)
{
    /* Flush stale RX state from any previous session so a reconnect is accepted
       cleanly. Without this, leftover direct_rx_count / direct_link_closed /
       active_link from the dropped peer make the accept return instantly on the
       dead link, then bail, alternating DISCONNECTED/WAITING forever. */
    direct_reset_rx_state();
    return spectrum_overlay_exec(SPECTRUM_OVL_DIRECT,
                                 SPECTRUM_OVL_DIRECT_WAIT_CONNECT);
}

static int16_t direct_read_payload(char *payload, uint8_t payload_cap)
{
    uint16_t payload_addr = (uint16_t)payload;
    uint8_t link;

    if (payload_cap != 0u) {
        payload[0] = '\0';
    }
    spectrum_overlay_context[0] = (uint8_t)payload_addr;
    spectrum_overlay_context[1] = (uint8_t)(payload_addr >> 8);
    spectrum_overlay_context[2] = payload_cap;
    link = spectrum_overlay_exec_cached(SPECTRUM_OVL_DIRECT,
                                         SPECTRUM_OVL_DIRECT_READ);
    if (link == 0u && payload_cap != 0u && payload[0] == '\0') {
        return SPECTRUM_NET_READ_TIMEOUT;
    }
    /* The overlay returns status codes truncated to a byte: 0xfd is
       READ_TIMEOUT (-3), 0xfe is link-closed (-2). Sign-extend so the
       poll layer sees the negative values again; real link ids stay in
       0..4. Without this a timeout came back as +253, was taken for a
       payload, and stale caller data was re-classified on every poll tick:
       PING/RESET ghost-event storms on the DIRECT link. */
    return (int16_t)(int8_t)link;
}

static uint8_t direct_send_text(const char *text) __z88dk_fastcall
{
    uint16_t text_addr = (uint16_t)text;

    spectrum_overlay_context[0] = (uint8_t)text_addr;
    spectrum_overlay_context[1] = (uint8_t)(text_addr >> 8);
    return spectrum_overlay_exec_cached(SPECTRUM_OVL_DIRECT,
                                        SPECTRUM_OVL_DIRECT_SEND);
}

static uint16_t mqtt_next_id;
static uint8_t mqtt_stream_len;
static uint8_t mqtt_stream_active;
static uint8_t mqtt_pending_len;
static uint8_t mqtt_queued_payload;
static uint8_t mqtt_queued_payload_len;
static uint8_t mqtt_queued_payload_flags;
static spectrum_mqtt_broker_keepalive_t mqtt_broker_keepalive;
#define MQTT_STREAM_MAX 223u
#define MQTT_STREAM_BASE SPECTRUM_MQTT_RUNTIME_ASSETS_END
#define MQTT_STREAM_DRAIN_BUDGET 64u
#if MQTT_STREAM_BASE < SPECTRUM_MQTT_RUNTIME_ASSETS_END
#error "MQTT stream overlaps runtime assets"
#endif
#if MQTT_STREAM_MAX < (SPECTRUM_MQTT_PACKET_MAX + MQTT_STREAM_DRAIN_BUDGET - 1u)
#error "MQTT_STREAM_MAX must hold one near-complete MQTT packet plus one UART drain"
#endif
#if SPECTRUM_MQTT_SCRATCH_BASE < (MQTT_STREAM_BASE + MQTT_STREAM_MAX)
#error "MQTT scratch overlaps mqtt_stream"
#endif
#if (SPECTRUM_MQTT_SCRATCH_BASE + SPECTRUM_MQTT_PACKET_MAX) > 0x6800u
#error "MQTT scratch overlaps overlay slot"
#endif
static __at(MQTT_STREAM_BASE) uint8_t mqtt_stream[MQTT_STREAM_MAX];
#define MQTT_PACKET SPECTRUM_MQTT_PACKET_SCRATCH
#define MQTT_STREAM mqtt_stream

static void mqtt_reset_session_state(void);
static void mqtt_puback_id(uint16_t packet_id) __z88dk_fastcall;

uint8_t spectrum_net_mqtt_publish_setup(uint8_t mode) NETCHESSZX_FASTCALL
{
    spectrum_overlay_context[0] = mode;
    return spectrum_overlay_exec_cached(SPECTRUM_OVL_MQTT_TX,
                                        SPECTRUM_OVL_MQTT_TX_PUBLISH_SETUP);
}

uint8_t spectrum_net_mqtt_activate_side(void)
{
    return spectrum_overlay_exec(SPECTRUM_OVL_MQTT_CONNECT,
                                 SPECTRUM_OVL_MQTT_CONNECT_ACTIVATE);
}

uint8_t spectrum_net_mqtt_probe_seat(void)
{
    return spectrum_overlay_exec(SPECTRUM_OVL_MQTT_CONNECT,
                                 SPECTRUM_OVL_MQTT_CONNECT_PROBE_SEAT);
}

uint8_t spectrum_net_mqtt_publish_presence(void)
{
    return spectrum_overlay_exec_cached(SPECTRUM_OVL_MQTT_TX,
                                        SPECTRUM_OVL_MQTT_TX_PUBLISH_PRESENCE);
}

uint8_t mqtt_enter_stream_mode(void)
{
    mqtt_stream_active = 0u;
    mqtt_stream_len = 0u;

    if (!spectrum_net_at_cmd("AT+CIPMODE=1", WAIT_MED)) {
        return 0u;
    }

    reset_line_buf();
    if (!spectrum_uart_send_string("AT+CIPSEND") ||
        !spectrum_uart_send_crlf()) {
        return 0u;
    }
    if (!wait_for_prompt(WAIT_MED)) {
        return 0u;
    }

    reset_line_buf();
    mqtt_stream_active = 1u;
    return 1u;
}

void mqtt_abort_stream_mode(void)
{
    mqtt_stream_active = 0u;
    mqtt_stream_len = 0u;
}

static uint8_t mqtt_drain_uart_budget(uint8_t budget) __z88dk_fastcall
{
    uint8_t any = 0u;

    if (!mqtt_stream_active) {
        return 0u;
    }

    while (budget-- != 0u && spectrum_uart_ready()) {
        if (mqtt_stream_len >= MQTT_STREAM_MAX) {
            /* Full: leave the byte in the UART/ring. Reading it before this
               check dropped it and desynced the MQTT parser. */
            return 2u;
        }
        MQTT_STREAM[mqtt_stream_len++] = spectrum_uart_read();
        any = 1u;
    }

    return any;
}

static uint8_t mqtt_fill_stream(uint16_t frames) __z88dk_fastcall
{
    if (!mqtt_stream_active) {
        return 0u;
    }

    while (frames-- != 0u) {
        uint8_t drained = mqtt_drain_uart_budget(MQTT_STREAM_DRAIN_BUDGET);

        if (drained != 0u) {
            return drained == 2u ? 0u : 1u;
        }
        spectrum_net_runtime_wait_frame_plain();
    }
    return 0u;
}

/* Return a view length; the caller consumes the stream after copying/parsing. */
static int16_t mqtt_take_stream_packet(void)
{
    uint8_t discard = 0u;
    uint8_t remaining;
    uint8_t total;
    uint8_t header_len;
    uint8_t b;

    /* Keep the last byte when no header survives: it may be the first byte of
       the next fragmented packet. Compact only once after discarded garbage. */
    while (mqtt_stream_len >= 2u) {
        b = MQTT_STREAM[discard];
        if ((b & 0xf0u) == 0x30u || b == 0x20u || b == 0x40u ||
            b == 0x90u || b == 0xd0u) {
            break;
        }
        ++discard;
        --mqtt_stream_len;
    }
    if (discard != 0u) {
        net_move(MQTT_STREAM, MQTT_STREAM + discard, mqtt_stream_len);
    }
    if (mqtt_stream_len < 2u) {
        return 0;
    }

    b = (uint8_t)MQTT_STREAM[1u];
    remaining = (uint8_t)(b & 0x7fu);
    header_len = 2u;
    if ((b & 0x80u) != 0u) {
        if (mqtt_stream_len < 3u) {
            return 0;
        }
        b = (uint8_t)MQTT_STREAM[2u];
        if ((b & 0x80u) != 0u || b > 1u) {
            mqtt_stream_len = 0u;
            return -1;
        }
        remaining = (uint8_t)(remaining + (uint8_t)(b << 7));
        header_len = 3u;
    }
    if (remaining > (uint8_t)(SPECTRUM_MQTT_PACKET_MAX - header_len)) {
        mqtt_stream_len = 0u;
        return -1;
    }
    total = (uint8_t)(header_len + remaining);
    if (mqtt_stream_len < total) {
        return 0;
    }

    spectrum_mqtt_broker_keepalive_reset(&mqtt_broker_keepalive);
    return total;
}

static void mqtt_consume_stream_packet(uint8_t total) __z88dk_fastcall
{
    mqtt_stream_len = (uint8_t)(mqtt_stream_len - total);
    if (mqtt_stream_len != 0u) {
        net_move(MQTT_STREAM, MQTT_STREAM + total, mqtt_stream_len);
    }
}

static int16_t mqtt_read_stream_packet(void)
{
    int16_t got = mqtt_take_stream_packet();

    if (got != 0) {
        return got;
    }
    if (!mqtt_fill_stream(WAIT_POLL)) {
        return SPECTRUM_NET_MQTT_READ_TIMEOUT;
    }
    got = mqtt_take_stream_packet();
    return got == 0 ? SPECTRUM_NET_MQTT_READ_TIMEOUT : got;
}

static uint8_t mqtt_queue_publish_payload(const uint8_t *packet, uint8_t len)
{
    uint16_t packet_id;
    uint8_t flags;
    int16_t payload_len;

    if (mqtt_queued_payload) {
        return 0u;
    }
    payload_len = spectrum_mqtt_parse_publish(packet,
                                              len,
                                              direct_rx_payload2,
                                               SPECTRUM_NET_PAYLOAD_MAX,
                                               &packet_id,
                                               &flags);
    mqtt_puback_id(packet_id);
    if (payload_len < 0) {
        return 1u;
    }
    mqtt_queued_payload = 1u;
    mqtt_queued_payload_len = (uint8_t)payload_len;
    mqtt_queued_payload_flags = flags;
    return 1u;
}

static uint8_t mqtt_stash_packet(const uint8_t *packet, uint8_t len)
{
    uint8_t type = spectrum_mqtt_type(packet, len);

    if (type == SPECTRUM_MQTT_PUBLISH && mqtt_queue_publish_payload(packet, len)) {
        return 1u;
    }
    if (mqtt_pending_len == 0u) {
        net_copy(MQTT_PACKET, packet, len);
        mqtt_pending_len = len;
        return 1u;
    }
    if (type == SPECTRUM_MQTT_PINGRESP && len <= 2u) {
        net_link_activity = 1u;
        return 1u;
    }
    return type == SPECTRUM_MQTT_PUBACK;
}

uint8_t mqtt_send_raw_packet(const uint8_t *packet, uint8_t len)
{
    if (mqtt_stream_active) {
        /* Transparent (CIPMODE=1) writes give no synchronous TCP status.
           The read path sends broker PINGREQs and closes the link after
           missing PINGRESPs, independently of peer liveness. */
        if (spectrum_uart_send_bytes(packet, len)) {
            return 1u;
        }
        mqtt_abort_stream_mode();
    }
    return 0u;
}

static int16_t mqtt_broker_keepalive_timeout(void)
{
    uint8_t event = spectrum_mqtt_broker_keepalive_timeout(
        &mqtt_broker_keepalive);

    if (event == SPECTRUM_MQTT_KEEPALIVE_NONE) {
        return SPECTRUM_NET_MQTT_READ_TIMEOUT;
    }
    if (event == SPECTRUM_MQTT_KEEPALIVE_LOST) {
        return -2;
    }
    MQTT_PACKET[0u] = SPECTRUM_MQTT_PINGREQ_HEADER;
    MQTT_PACKET[1u] = 0u;
    return mqtt_send_raw_packet(MQTT_PACKET, 2u)
        ? SPECTRUM_NET_MQTT_READ_TIMEOUT : -2;
}

static void mqtt_puback_id(uint16_t packet_id) __z88dk_fastcall
{
    uint8_t ack[4];

    if (packet_id == 0u) {
        return;
    }
    ack[0u] = 0x40u;
    ack[1u] = 0x02u;
    ack[2u] = (uint8_t)(packet_id >> 8);
    ack[3u] = (uint8_t)packet_id;
    (void)mqtt_send_raw_packet(ack, 4u);
}

uint8_t mqtt_wait_packet_into(uint8_t *packet, uint8_t wanted, uint16_t frames)
{
    while (frames-- != 0u) {
        int16_t got = mqtt_read_stream_packet();

        if (got == SPECTRUM_NET_MQTT_READ_TIMEOUT) {
            net_wait_frame();
            continue;
        }
        if (got <= 0) {
            return 0u;
        }
        {
            uint8_t type = spectrum_mqtt_type(MQTT_STREAM, (uint16_t)got);

            if (wanted == 0u || type == wanted) {
                net_copy(packet, MQTT_STREAM, (uint8_t)got);
                mqtt_consume_stream_packet((uint8_t)got);
                return 1u;
            }
            if ((uint16_t)got <= SPECTRUM_MQTT_PACKET_MAX) {
                uint8_t stashed = mqtt_stash_packet(MQTT_STREAM, (uint8_t)got);

                mqtt_consume_stream_packet((uint8_t)got);
                if (!stashed) {
                    return 0u;
                }
            }
        }
    }
    return 0u;
}

static void mqtt_reset_session_state(void)
{
    mqtt_stream_len = 0u;
    mqtt_stream_active = 0u;
    mqtt_pending_len = 0u;
    mqtt_queued_payload = 0u;
    net_payload_flags = 0u;
    spectrum_mqtt_broker_keepalive_reset(&mqtt_broker_keepalive);
    mqtt_next_id = 1u;
}

uint8_t spectrum_net_preflight_run(void)
{
    if (!spectrum_overlay_exec_cached(SPECTRUM_OVL_NET_CONNECT,
                                      SPECTRUM_OVL_NET_PREFLIGHT)) {
        return SPECTRUM_LINK_PREFLIGHT_OVL_FAIL;
    }
    if (spectrum_overlay_context[SPECTRUM_OVL_CTX_PREFLIGHT_OK]) {
        return SPECTRUM_LINK_PREFLIGHT_OK;
    }
    if (spectrum_overlay_context[SPECTRUM_OVL_CTX_PREFLIGHT_RETRY] == SPECTRUM_OVL_PREFLIGHT_RETRY_AGAIN) {
        return SPECTRUM_LINK_PREFLIGHT_RETRYING;
    }
    return SPECTRUM_LINK_PREFLIGHT_FAILED;
}

uint8_t spectrum_net_mqtt_start(void)
{
    mqtt_reset_session_state();
    return spectrum_overlay_exec(SPECTRUM_OVL_MQTT_CONNECT,
                                 SPECTRUM_OVL_MQTT_CONNECT_START);
}

int16_t spectrum_net_mqtt_read_payload(char *payload, uint8_t payload_cap)
{
    const uint8_t *packet;
    uint16_t packet_id;
    int16_t got;
    uint8_t packet_len;
    uint8_t pending;
    uint8_t flags;

    net_payload_flags = 0u;
    if (mqtt_queued_payload) {
        mqtt_queued_payload = 0u;
        if (payload_cap == 0u || mqtt_queued_payload_len >= payload_cap) {
            return SPECTRUM_NET_READ_TIMEOUT;
        }
        net_copy((uint8_t *)payload,
                 (const uint8_t *)direct_rx_payload2,
                 (uint16_t)(mqtt_queued_payload_len + 1u));
        net_payload_flags = mqtt_queued_payload_flags;
        return 0;
    }

    pending = mqtt_pending_len;
    if (pending != 0u) {
        mqtt_pending_len = 0u;
        if (pending > SPECTRUM_MQTT_PACKET_MAX) {
            return -2;
        }
        got = pending;
        packet = MQTT_PACKET;
    } else {
        got = mqtt_read_stream_packet();
        packet = MQTT_STREAM;
    }
    if (got == SPECTRUM_NET_MQTT_READ_TIMEOUT) {
        got = mqtt_broker_keepalive_timeout();
        if (got == SPECTRUM_NET_MQTT_READ_TIMEOUT) {
            return SPECTRUM_NET_READ_TIMEOUT;
        }
    }
    if (got <= 0) {
        return -2;
    }

    if (spectrum_mqtt_type(packet, (uint16_t)got) == SPECTRUM_MQTT_PINGRESP &&
        (uint16_t)got <= 2u) {
        net_link_activity = 1u;
        if (pending == 0u) {
            mqtt_consume_stream_packet((uint8_t)got);
        }
        return SPECTRUM_NET_READ_TIMEOUT;
    }

    if (spectrum_mqtt_type(packet, (uint16_t)got) !=
        SPECTRUM_MQTT_PUBLISH) {
        if (pending == 0u) {
            mqtt_consume_stream_packet((uint8_t)got);
        }
        return SPECTRUM_NET_READ_TIMEOUT;
    }

    packet_len = (uint8_t)got;
    got = spectrum_mqtt_parse_publish(packet,
                                       packet_len,
                                       payload,
                                       payload_cap,
                                       &packet_id,
                                       &flags);
    if (pending == 0u) {
        mqtt_consume_stream_packet(packet_len);
    }
    if (got < 0) {
        mqtt_puback_id(packet_id);
        return SPECTRUM_NET_READ_TIMEOUT;
    }
    mqtt_puback_id(packet_id);
    net_payload_flags = flags;
    return 0;
}

uint8_t spectrum_net_mqtt_send_text(const char *text) NETCHESSZX_FASTCALL
{
    uint16_t text_addr = (uint16_t)text;

    spectrum_overlay_context[0] = (uint8_t)text_addr;
    spectrum_overlay_context[1] = (uint8_t)(text_addr >> 8);
    return spectrum_overlay_exec_cached(SPECTRUM_OVL_MQTT_TX,
                                        SPECTRUM_OVL_MQTT_TX_SEND_TEXT);
}

int16_t spectrum_net_read_payload(char *payload, uint8_t payload_cap)
{
    net_payload_flags = 0u;
    if (netchesszx_transport_is_mqtt()) {
        return spectrum_net_mqtt_read_payload(payload, payload_cap);
    }
    return direct_read_payload(payload, payload_cap);
}

uint8_t spectrum_net_send_text(const char *text) NETCHESSZX_FASTCALL
{
    spectrum_net_background_drain();
    if (netchesszx_transport_is_mqtt()) {
        return spectrum_net_mqtt_send_text(text);
    }
    return direct_send_text(text);
}

uint8_t spectrum_net_send_ping(void)
{
    spectrum_net_background_drain();
    if (netchesszx_transport_is_mqtt()) {
        /* Application-level PING on the out topic: the peer answers ACK PING,
           so the session miss counter measures PEER liveness, not broker
           liveness. The periodic PUBLISH also satisfies broker keepalive. */
        return spectrum_net_mqtt_send_text(NETCHESS_PROTO_PING);
    }
    return direct_send_text(NETCHESS_PROTO_PING);
}
