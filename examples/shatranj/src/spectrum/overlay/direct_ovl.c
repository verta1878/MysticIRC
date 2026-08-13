#include "spectrum/overlay/overlay_api.h"
#include "spectrum/transport/mqtt_min.h"
#include "spectrum/transport/net.h"

#define WAIT_MED 500
#define WAIT_LONG 2000
#define WAIT_POLL 2
#define WAIT_DIRECT_PROMPT 50
#define WAIT_DIRECT_SEND_OK 150
#define DIRECT_SEND_GUARD_FRAMES 4u
#define DIRECT_KEY_CANCEL 0x8au
#define DIRECT_CIPSTART_PREFIX "AT+CIPSTART=\"TCP\",\""
#define DIRECT_CIPSTART_PREFIX_LEN 19u
#define DIRECT_CIPSTART_SUFFIX_LEN 2u
/* TCP keepalive (seconds): lets the guest ESP notice a dead peer and emit
   CLOSED instead of holding a half-open link forever. */
#define DIRECT_CIPSTART_KEEPALIVE ",60"
#define DIRECT_CIPSTART_KEEPALIVE_LEN 3u
#define DIRECT_PORT_MAX_LEN 5u
#define DIRECT_CIPSTART_MAX_LEN (DIRECT_CIPSTART_PREFIX_LEN + NETCHESSZX_DIRECT_HOST_MAX + DIRECT_CIPSTART_SUFFIX_LEN + DIRECT_PORT_MAX_LEN + DIRECT_CIPSTART_KEEPALIVE_LEN + 1u)
#if DIRECT_CIPSTART_MAX_LEN > SPECTRUM_NET_LINE_MAX
#error "DIRECT CIPSTART command exceeds line_buf"
#endif

extern char line_buf[];
extern char direct_rx_payload[];
extern char direct_rx_payload2[];
extern uint8_t direct_rx_link;
extern uint8_t direct_rx_link2;
extern uint8_t active_link;
extern uint8_t line_pos;
extern uint8_t direct_rx_count;
extern uint8_t direct_rx_head;
extern uint8_t direct_rx_payload_len;
extern uint16_t direct_ipd_remaining;
extern uint8_t direct_ipd_accept;
extern uint8_t direct_ipd_link;
extern uint8_t direct_link_closed;
extern uint8_t direct_peer_valid;
extern uint8_t direct_intruder_link;
#ifdef NETCHESSZX_HOST_TEST
static char direct_rx_spill[SPECTRUM_NET_PAYLOAD_MAX + 1u];
#define DIRECT_RX_SPILL direct_rx_spill
#else
#define DIRECT_RX_SPILL ((char *)SPECTRUM_MQTT_RUNTIME_ASSETS_END)
#endif
#if (SPECTRUM_MQTT_RUNTIME_ASSETS_END + SPECTRUM_NET_PAYLOAD_MAX + 1u) > SPECTRUM_MQTT_SCRATCH_BASE
#error "DIRECT spill exceeds inactive MQTT stream storage"
#endif
extern void reset_line_buf(void);
extern void net_wait_frame(void);
#ifdef NETCHESSZX_HOST_TEST
#define spectrum_net_at_cipserver_0 "AT+CIPSERVER=0"
#define spectrum_net_at_cipclose "AT+CIPCLOSE"
#define spectrum_net_at_cipmux_0 "AT+CIPMUX=0"
#else
extern const char spectrum_net_at_cipserver_0[];
extern const char spectrum_net_at_cipclose[];
extern const char spectrum_net_at_cipmux_0[];
#endif

#define direct_digit_value(c) ((uint8_t)((uint8_t)(c) - (uint8_t)'0'))
#define direct_is_digit(c) (direct_digit_value(c) <= 9u)
#define direct_is_link_digit(c) (direct_digit_value(c) <= 4u)
#define DIRECT_CTX_PTR_LO 0u
#define DIRECT_CTX_PTR_HI 1u
#define DIRECT_CTX_PAYLOAD_CAP 2u
#ifdef NETCHESSZX_HOST_TEST
/* Host regression tests can't pack a 64-bit pointer into the 2-byte ctx. */
char *direct_host_test_ptr;
#define direct_ctx_ptr(ctx) ((void)(ctx), direct_host_test_ptr)
#else
#define direct_ctx_ptr(ctx) \
    ((char *)((uint16_t)(ctx)[DIRECT_CTX_PTR_LO] | \
              ((uint16_t)(ctx)[DIRECT_CTX_PTR_HI] << 8)))
#endif

static char *direct_payload_slot_ovl(uint8_t slot)
{
    return slot == 0u ? direct_rx_payload
                      : (slot == 1u ? direct_rx_payload2
                                    : DIRECT_RX_SPILL);
}

static uint8_t direct_tail_slot_ovl(void)
{
    uint8_t slot = (uint8_t)(direct_rx_head + direct_rx_count);

    return slot < SPECTRUM_NET_DIRECT_RX_QUEUE_COUNT
        ? slot : (uint8_t)(slot - SPECTRUM_NET_DIRECT_RX_QUEUE_COUNT);
}

static uint8_t direct_head_link_ovl(void)
{
    return direct_rx_head == 0u ? direct_rx_link
                                : (direct_rx_head == 1u
                                       ? direct_rx_link2
                                       : (uint8_t)DIRECT_RX_SPILL[
                                             SPECTRUM_NET_PAYLOAD_MAX]);
}

static uint8_t direct_queue_payload_ovl(void)
{
    char *slot_payload;
    uint8_t slot;

    if (direct_rx_payload_len == 0u) {
        return 1u;
    }
    if (direct_rx_count >= SPECTRUM_NET_DIRECT_RX_QUEUE_COUNT) {
        direct_rx_payload_len = 0u;
        direct_ipd_accept = 0u;
        return 0u;
    }

    slot = direct_tail_slot_ovl();
    slot_payload = direct_payload_slot_ovl(slot);
    slot_payload[direct_rx_payload_len] = '\0';
    direct_rx_payload_len = 0u;
    if (slot == 0u) {
        direct_rx_link = direct_ipd_link;
    } else if (slot == 1u) {
        direct_rx_link2 = direct_ipd_link;
    } else {
        DIRECT_RX_SPILL[SPECTRUM_NET_PAYLOAD_MAX] = (char)direct_ipd_link;
    }
    ++direct_rx_count;
    return 1u;
}

static uint8_t direct_parse_ipd_header_ovl(void)
{
    char *p = line_buf + 5;
    uint16_t len;
    uint8_t link = 0u;
    uint8_t have_link = 0u;

    for (;;) {
        len = 0u;
        if (!direct_is_digit((uint8_t)*p)) {
            return 0u;
        }
        do {
            len = (uint16_t)((len << 3) + (len << 1) +
                             direct_digit_value((uint8_t)*p));
            ++p;
        } while (direct_is_digit((uint8_t)*p));

        if (*p != ',') {
            break;
        }
        if (have_link) {
            return 0u;
        }
        link = (uint8_t)len;
        have_link = 1u;
        ++p;
    }

    if (*p != ':') {
        return 0u;
    }
    /* len == 0 wraps to UINT16_MAX, rejecting zero and len > 2048 at once. */
    if (link > 4u || (uint16_t)(len - 1u) >= 2048u) {
        return 0u;
    }

    direct_ipd_accept = 1u;
    if (active_link != 0xffu) {
        if (link != active_link) {
            /* Third party connected while the session is live: swallow the
               burst and flag it so the read path closes that link, keeping
               the active session untouched. */
            direct_ipd_accept = 0u;
            direct_intruder_link = link;
        }
    }

    direct_ipd_link = link;
    direct_ipd_remaining = len;
    reset_line_buf();
    return 1u;
}

static uint8_t direct_feed_payload_byte_ovl(uint8_t c)
{
    uint8_t queued = 0u;

    --direct_ipd_remaining;
    if (direct_ipd_accept) {
        if (c == '\r') {
            /* ignore */
        } else if (c == '\n') {
            queued = direct_queue_payload_ovl();
        } else if (direct_rx_count >= SPECTRUM_NET_DIRECT_RX_QUEUE_COUNT ||
                   direct_rx_payload_len >= (SPECTRUM_NET_PAYLOAD_MAX - 1u)) {
            direct_rx_payload_len = 0u;
            direct_ipd_accept = 0u;
        } else {
            direct_payload_slot_ovl(direct_tail_slot_ovl())
                [direct_rx_payload_len++] = (char)c;
        }

    }

    if (direct_ipd_remaining == 0u) {
        /* Block exhausted without \n: keep the partial line so the next
           +IPD block continues it. Queuing it here forged messages when a
           line was split across TCP segments. */
        direct_ipd_accept = 0u;
        reset_line_buf();
    }
    if (direct_link_closed) {
        return 3u;
    }
    return queued ? 2u : 0u;
}

static uint8_t direct_feed_uart_byte_ovl(uint8_t c)
{
    if (direct_ipd_remaining != 0u) {
        return direct_feed_payload_byte_ovl(c);
    }

    if (c == '>') {
        return 4u;
    }

    if (c == '\r') {
        return 0u;
    }

    if (c == '\n') {
        if (line_pos == SPECTRUM_NET_LINE_MAX) {
            reset_line_buf();
            return 0u;
        }
        if (line_pos != 0u) {
            line_buf[line_pos] = '\0';
            line_pos = 0u;
            if ((active_link == 0xffu &&
                 ((line_buf[0] == 'C' && line_buf[1] == 'L') ||
                  (line_buf[0] == 'U' && line_buf[1] == 'N'))) ||
                (direct_is_link_digit((uint8_t)line_buf[0]) &&
                 line_buf[1] == ',' &&
                 direct_digit_value((uint8_t)line_buf[0]) == active_link &&
                 line_buf[2] == 'C' && line_buf[3] == 'L')) {
                direct_link_closed = 1u;
                return 3u;
            }
            return 1u;
        }
        return 0u;
    }

    if (line_pos < (SPECTRUM_NET_LINE_MAX - 1u)) {
        line_buf[line_pos++] = (char)c;
        line_buf[line_pos] = '\0';
    } else {
        line_pos = SPECTRUM_NET_LINE_MAX;
    }

    if (c == ':' &&
        line_buf[0] == '+' && line_buf[1] == 'I' &&
        line_buf[2] == 'P' && line_buf[3] == 'D' &&
        line_buf[4] == ',') {
        if (direct_parse_ipd_header_ovl()) {
            return 0u;
        }
        reset_line_buf();
    }

    return 0u;
}

static uint8_t direct_drain_uart_ovl(void)
{
    while (spectrum_uart_ready()) {
        uint8_t rc = direct_feed_uart_byte_ovl(spectrum_uart_read());

        if (rc != 0u) {
            return rc;
        }
    }
    net_wait_frame();
    return 0u;
}

static uint8_t direct_wait_for_ok_ovl(uint16_t frames, uint8_t cancellable)
{
    while (frames-- != 0u) {
        uint8_t rc = direct_drain_uart_ovl();

        if (cancellable && spectrum_key_poll() == DIRECT_KEY_CANCEL) {
            return SPECTRUM_LINK_CANCELLED;
        }
        if (rc == 3u) {
            return 0u;
        }
        if (rc != 1u) {
            continue;
        }
        if (line_buf[0] == 'O' && line_buf[1] == 'K') {
            return 1u;
        }
        if (line_buf[0] == 'S' && line_buf[1] == 'E' &&
            line_buf[5] == 'O') {
            return 1u;
        }
        if (line_buf[0] == 'E' || line_buf[0] == 'F') {
            return 0u;
        }
        net_wait_frame();
    }
    return 0u;
}

static uint8_t direct_wait_for_prompt_ovl(uint16_t frames)
{
    while (frames-- != 0u) {
        uint8_t rc = direct_drain_uart_ovl();

        if (rc == 4u) {
            return 1u;
        }
        if (rc == 3u) {
            return 0u;
        }
    }
    return 0u;
}

static uint8_t direct_send_linebuf_ovl(void)
{
    uint8_t ok = spectrum_uart_send_string(line_buf);

    reset_line_buf();
    if (!ok) {
        return 0u;
    }
    return spectrum_uart_send_crlf();
}

static uint8_t direct_tcp_connect_ovl(void)
{
    (void)spectrum_append_text(
        spectrum_append_u16(
            spectrum_append_text(
                spectrum_append_text(
                    spectrum_append_text(line_buf, DIRECT_CIPSTART_PREFIX),
                    netchesszx_direct_host),
                "\","),
            netchesszx_direct_port),
        DIRECT_CIPSTART_KEEPALIVE);
    if (!direct_send_linebuf_ovl()) {
        return 0u;
    }
    return direct_wait_for_ok_ovl(WAIT_LONG, 1u);
}

static uint8_t direct_prepare_link_ovl(void)
{
    if (!spectrum_net_ensure_command_mode()) {
        return 0u;
    }
    direct_link_closed = 0u;
    reset_line_buf();
    return 1u;
}

static void direct_reset_links_ovl(void)
{
    (void)spectrum_net_at_cmd(spectrum_net_at_cipserver_0, WAIT_MED);
    (void)spectrum_net_at_cmd("AT+CIPCLOSE=5", WAIT_MED);
}

static uint8_t direct_prepare_client_ovl(void)
{
    direct_reset_links_ovl();
    (void)spectrum_net_at_cmd(spectrum_net_at_cipclose, WAIT_MED);
    return spectrum_net_at_cmd(spectrum_net_at_cipmux_0, WAIT_MED);
}

uint8_t direct_listen_ovl(void)
{
    char *cmd;

    active_link = 0u;

    if (!direct_prepare_link_ovl()) {
        return 0u;
    }

    /* Re-listen after a lost session: stop the accept loop and close every
       stale/half-open server link first, or the ESP hits its 5-link cap and
       rejects all reconnect attempts. Both commands may reply ERROR on a
       fresh start (no server, no links) -- ignore. */
    direct_reset_links_ovl();

    if (!spectrum_net_at_cmd("AT+CIPMUX=1", WAIT_MED)) {
        return 0u;
    }

    cmd = spectrum_append_text(line_buf, spectrum_net_at_cipserver_0);
    cmd[-1] = '1';
    *cmd++ = ',';
    (void)spectrum_append_u16(cmd, netchesszx_direct_port);
    if (!direct_send_linebuf_ovl()) {
        return 0u;
    }
    if (!direct_wait_for_ok_ovl(WAIT_MED, 0u)) {
        return 0u;
    }

    return 1u;
}

uint8_t direct_connect_ovl(void)
{
    active_link = 0xffu;
    if (!direct_prepare_link_ovl()) {
        return 0u;
    }
    if (!direct_prepare_client_ovl()) {
        return 0u;
    }
    return direct_tcp_connect_ovl();
}

uint8_t direct_wait_pc_connect_ovl(void)
{
    uint16_t frames = WAIT_LONG;

    if (direct_rx_count != 0u) {
        goto payload_queued;
    }
    active_link = 0xffu;
    while (frames-- != 0u) {
        uint8_t rc = direct_drain_uart_ovl();

        if (spectrum_key_poll() == DIRECT_KEY_CANCEL) {
            return SPECTRUM_LINK_CANCELLED;
        }
        if (rc == 2u) {
            goto payload_queued;
        }
        if (rc == 3u) {
            active_link = 0u;
            return 0u;
        }
        if (rc == 1u && direct_is_link_digit(line_buf[0]) &&
            line_buf[1] == ',' && line_buf[2] == 'C' &&
            line_buf[3] == 'O') {
            active_link = direct_digit_value(line_buf[0]);
            return 1u;
        }
        net_wait_frame();
    }

    return 0u;

payload_queued:
    active_link = direct_head_link_ovl();
    return 1u;
}

static uint8_t direct_send_payload_ovl(const char *text, uint8_t link);

/* Close a third party without touching active_link. In CIPMUX=1, ESP-AT
   reports link closure as "<id>,CLOSED"; generic command ERROR belongs only
   to the rejected link operation. */
static void direct_reject_intruder_ovl(void)
{
    uint8_t link = direct_intruder_link;
    char *cmd;

    direct_intruder_link = 0xffu;
    if (direct_peer_valid) {
        (void)direct_send_payload_ovl("BUSY", link);
    }
    cmd = spectrum_append_text(line_buf, spectrum_net_at_cipclose);
    *cmd++ = '=';
    (void)spectrum_append_u16(cmd, link);
    (void)direct_send_linebuf_ovl();
    /* CIPCLOSE answers in ms. Do not block the active peer for the full send
       timeout; any late id-specific response is safe for the next poll. */
    (void)direct_wait_for_ok_ovl(DIRECT_SEND_GUARD_FRAMES, 0u);
}

uint8_t direct_read_payload_ovl(uint8_t *ctx) __z88dk_fastcall
{
    char *payload = direct_ctx_ptr(ctx);
    uint8_t payload_cap = ctx[DIRECT_CTX_PAYLOAD_CAP];
    uint8_t n;

    if (direct_intruder_link != 0xffu && direct_ipd_remaining == 0u) {
        direct_reject_intruder_ovl();
    }
    if (direct_rx_count == 0u && !direct_link_closed) {
        if (direct_drain_uart_ovl() == 0u) {
            (void)direct_drain_uart_ovl();
        }
    }
    if (direct_rx_count != 0u) {
        char *slot_payload = direct_payload_slot_ovl(direct_rx_head);

        n = 0u;
        if (payload_cap != 0u) {
            while (slot_payload[n] != '\0' && n + 1u < payload_cap) {
                payload[n] = slot_payload[n];
                ++n;
            }
            payload[n] = '\0';
        }
        n = direct_head_link_ovl();
        --direct_rx_count;
        /* Only advance head: the accumulation slot is (head+count)%3, so
           resetting head on empty (or zeroing direct_rx_payload_len) here
           would clobber a partial line still gathering in the other slot. */
        if (++direct_rx_head == SPECTRUM_NET_DIRECT_RX_QUEUE_COUNT) {
            direct_rx_head = 0u;
        }
        return n;
    }
    if (direct_link_closed) {
        return 0xfeu;
    }
    return (uint8_t)SPECTRUM_NET_READ_TIMEOUT;
}

static uint8_t direct_send_payload_ovl(const char *text, uint8_t link)
{
    char *cmd;
    uint8_t payload_len;
    uint8_t len;

    payload_len = 0u;
    while (text[payload_len] != '\0' &&
           payload_len < (SPECTRUM_NET_DIRECT_TX_PAYLOAD_CAP - 2u)) {
        ++payload_len;
    }
    len = (uint8_t)(payload_len + 1u);

    spectrum_net_guard_wait(DIRECT_SEND_GUARD_FRAMES);

    cmd = spectrum_append_text(line_buf, "AT+CIPSEND=");
    if (link != 0xffu) {
        cmd = spectrum_append_text(spectrum_append_u16(cmd, link), ",");
    }
    (void)spectrum_append_u16(cmd, len);
    if (!direct_send_linebuf_ovl()) {
        return 0u;
    }

    if (!direct_wait_for_prompt_ovl(WAIT_DIRECT_PROMPT)) {
        return 0u;
    }

    reset_line_buf();
    if (!spectrum_uart_send_bytes((const uint8_t *)text, payload_len) ||
        !spectrum_uart_send_bytes((const uint8_t *)"\n", 1u)) {
        return 0u;
    }
    /* TCP payload queued before CLOSED is still valid application data.
       Let the poll layer deliver it before reporting EOF on the next read. */
    return (uint8_t)(direct_wait_for_ok_ovl(WAIT_DIRECT_SEND_OK, 0u) +
                     (direct_link_closed && direct_rx_count));
}

uint8_t direct_send_text_ovl(uint8_t *ctx) __z88dk_fastcall
{
    return direct_send_payload_ovl(direct_ctx_ptr(ctx), active_link);
}
