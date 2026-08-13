/* Regression tests for DIRECT +IPD framing: +IPD delimits a TCP block, not a
   protocol line. TCP/ESP may coalesce two lines into one block or split one
   line across blocks; only \n ends a message (docs/wire-contract.md). */
#include <stdio.h>
#include <string.h>

#include "spectrum/overlay/direct_ovl.c"

/* Resident symbols the overlay imports. */
char line_buf[SPECTRUM_NET_LINE_MAX];
char direct_rx_payload[SPECTRUM_NET_PAYLOAD_MAX];
char direct_rx_payload2[SPECTRUM_NET_PAYLOAD_MAX];
uint8_t direct_rx_link;
uint8_t direct_rx_link2;
uint8_t active_link;
uint8_t line_pos;
uint8_t direct_rx_count;
uint8_t direct_rx_head;
uint8_t direct_rx_payload_len;
uint16_t direct_ipd_remaining;
uint8_t direct_ipd_accept;
uint8_t direct_ipd_link;
uint8_t direct_link_closed;
uint8_t direct_peer_valid;
uint8_t direct_intruder_link;
char netchesszx_direct_host[NETCHESSZX_DIRECT_HOST_MAX + 1u];
uint16_t netchesszx_direct_port;
static const uint8_t *uart_feed;
static size_t uart_feed_len;
static size_t uart_feed_pos;
static size_t uart_release_pos[2];
static uint16_t uart_release_frame[2];
static uint8_t uart_release_count;
static uint8_t uart_release_index;
static uint16_t frame_count;
static char uart_tx[96];
static size_t uart_tx_len;

void reset_line_buf(void)
{
    line_pos = 0u;
    line_buf[0] = '\0';
}

void net_wait_frame(void) { ++frame_count; }
uint8_t spectrum_uart_ready(void)
{
    if (uart_release_index < uart_release_count &&
        uart_feed_pos == uart_release_pos[uart_release_index]) {
        if (frame_count < uart_release_frame[uart_release_index]) {
            return 0u;
        }
        ++uart_release_index;
    }
    return uart_feed_pos < uart_feed_len;
}
uint8_t spectrum_uart_read(void) { return uart_feed[uart_feed_pos++]; }
static uint8_t capture_tx(const uint8_t *data, size_t len)
{
    if (uart_tx_len + len >= sizeof(uart_tx)) {
        return 0u;
    }
    memcpy(uart_tx + uart_tx_len, data, len);
    uart_tx_len += len;
    uart_tx[uart_tx_len] = '\0';
    return 1u;
}
uint8_t spectrum_uart_send_string(const char *s)
{
    return capture_tx((const uint8_t *)s, strlen(s));
}
uint8_t spectrum_uart_send_bytes(const uint8_t *d, uint8_t n)
{
    return capture_tx(d, n);
}
uint8_t spectrum_uart_send_crlf(void)
{
    return capture_tx((const uint8_t *)"\r\n", 2u);
}
uint8_t spectrum_key_poll(void) { return 0u; }
void spectrum_net_guard_wait(uint16_t frames) { (void)frames; }
uint8_t spectrum_net_at_cmd(const char *cmd, uint16_t frames)
{
    (void)cmd;
    (void)frames;
    return 1u;
}
uint8_t spectrum_net_ensure_command_mode(void) { return 1u; }
static int failures;

static void check(int ok, const char *label)
{
    if (!ok) {
        printf("FAIL: %s\n", label);
        ++failures;
    }
}

static void reset_state(void)
{
    /* Mirrors direct_reset_rx_state() in net.c. */
    direct_rx_count = 0u;
    direct_rx_head = 0u;
    direct_rx_payload_len = 0u;
    direct_ipd_remaining = 0u;
    direct_ipd_accept = 0u;
    direct_ipd_link = 0u;
    direct_link_closed = 0u;
    direct_peer_valid = 0u;
    direct_intruder_link = 0xffu;
    active_link = 0u;
    uart_feed = 0;
    uart_feed_len = 0u;
    uart_feed_pos = 0u;
    uart_release_count = 0u;
    uart_release_index = 0u;
    frame_count = 0u;
    uart_tx_len = 0u;
    uart_tx[0] = '\0';
    reset_line_buf();
}

static void feed(const char *bytes, size_t len)
{
    size_t i;

    for (i = 0u; i < len; ++i) {
        (void)direct_feed_uart_byte_ovl((uint8_t)bytes[i]);
    }
}

static void feed_str(const char *bytes)
{
    feed(bytes, strlen(bytes));
}

static void release_uart_at(uint8_t index, size_t pos, uint16_t frame)
{
    uart_release_pos[index] = pos;
    uart_release_frame[index] = frame;
    uart_release_count = (uint8_t)(index + 1u);
}

static uint8_t dequeue(char *out, uint8_t cap)
{
    uint8_t ctx[3];

    direct_host_test_ptr = out;
    ctx[DIRECT_CTX_PTR_LO] = 0u;
    ctx[DIRECT_CTX_PTR_HI] = 0u;
    ctx[DIRECT_CTX_PAYLOAD_CAP] = cap;
    return direct_read_payload_ovl(ctx);
}

/* Two 36-byte RESTORE frames coalesced into one +IPD block (PC sends both
   chunks back to back; Nagle/ESP merges them). Old code rejected any block
   over 48 bytes, losing both frames. */
static void test_coalesced_lines(void)
{
    char out[SPECTRUM_NET_PAYLOAD_MAX];
    const char *l1 = "RS00 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    const char *l2 = "RS01 BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";

    reset_state();
    feed_str("+IPD,0,72:");
    feed_str(l1);
    feed_str("\n");
    feed_str(l2);
    feed_str("\n");

    check(direct_rx_count == 2u, "coalesced: two payloads queued");
    check(dequeue(out, sizeof(out)) == 0u, "coalesced: first link id");
    check(strcmp(out, l1) == 0, "coalesced: first payload");
    check(dequeue(out, sizeof(out)) == 0u, "coalesced: second link id");
    check(strcmp(out, l2) == 0, "coalesced: second payload");
    check(dequeue(out, sizeof(out)) == (uint8_t)SPECTRUM_NET_READ_TIMEOUT,
          "coalesced: queue empty after both");
}

/* A peer burst may arrive after the CIPSEND prompt but before SEND OK. The
   blocking send wait must preserve every complete line while it drains the
   ESP response behind them. */
static void test_three_lines_during_send_wait(void)
{
    static const uint8_t replies[] =
        ">\r\n+IPD,0,14:ONE\nTWO\nTHREE\n\r\nSEND OK\r\n";
    char out[SPECTRUM_NET_PAYLOAD_MAX];

    reset_state();
    active_link = 0u;
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;

    check(direct_send_payload_ovl("PING", active_link),
          "send burst: local payload handed off");
    check(dequeue(out, sizeof(out)) == 0u && strcmp(out, "ONE") == 0,
          "send burst: first payload");
    check(dequeue(out, sizeof(out)) == 0u && strcmp(out, "TWO") == 0,
          "send burst: second payload");
    check(dequeue(out, sizeof(out)) == 0u && strcmp(out, "THREE") == 0,
          "send burst: third payload");
}

static void test_max_payload_in_spill(void)
{
    char header[24];
    char max_line[SPECTRUM_NET_PAYLOAD_MAX];
    char out[SPECTRUM_NET_PAYLOAD_MAX];

    reset_state();
    active_link = 4u;
    memset(max_line, 'X', SPECTRUM_NET_PAYLOAD_MAX - 1u);
    max_line[SPECTRUM_NET_PAYLOAD_MAX - 1u] = '\0';
    memset(DIRECT_RX_SPILL, 0xa5, SPECTRUM_NET_PAYLOAD_MAX + 1u);

    feed_str("+IPD,4,2:A\n");
    feed_str("+IPD,4,2:B\n");
    (void)snprintf(header, sizeof(header), "+IPD,4,%u:",
                   (unsigned)SPECTRUM_NET_PAYLOAD_MAX);
    feed_str(header);
    feed(max_line, SPECTRUM_NET_PAYLOAD_MAX - 1u);
    feed_str("\n");

    check(DIRECT_RX_SPILL[SPECTRUM_NET_PAYLOAD_MAX - 1u] == '\0',
          "spill max: payload terminator preserved");
    check((uint8_t)DIRECT_RX_SPILL[SPECTRUM_NET_PAYLOAD_MAX] == 4u,
          "spill max: link stored beyond payload terminator");
    check(dequeue(out, sizeof(out)) == 4u && strcmp(out, "A") == 0,
          "spill max: first payload");
    check(dequeue(out, sizeof(out)) == 4u && strcmp(out, "B") == 0,
          "spill max: second payload");
    check(dequeue(out, sizeof(out)) == 4u &&
              memcmp(out, max_line, sizeof(max_line)) == 0,
          "spill max: third maximum payload");
}

/* One line split across two +IPD blocks. Old code queued the first fragment
   as a complete message, forging two bogus payloads. */
static void test_split_line(void)
{
    char out[SPECTRUM_NET_PAYLOAD_MAX];

    reset_state();
    feed_str("+IPD,0,20:RS00 AAAAAAAAAAAAAAA");
    check(direct_rx_count == 0u, "split: partial not queued at block end");

    feed_str("+IPD,0,16:AAAAAAAAAAAAAAA\n");
    check(direct_rx_count == 1u, "split: one payload after \\n");
    check(dequeue(out, sizeof(out)) == 0u, "split: link id");
    check(strcmp(out, "RS00 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA") == 0,
          "split: reassembled payload");
}

static void test_large_block_header(void)
{
    reset_state();
    strcpy(line_buf, "+IPD,0,0:");
    check(!direct_parse_ipd_header_ovl(), "zero block: header rejected");

    reset_state();
    strcpy(line_buf, "+IPD,0,2048:");

    check(direct_parse_ipd_header_ovl(), "large block: header accepted");
    check(direct_ipd_remaining == 2048u, "large block: length preserved");

    reset_state();
    strcpy(line_buf, "+IPD,7:");
    check(direct_parse_ipd_header_ovl(), "implicit link: header accepted");
    check(direct_ipd_link == 0u && direct_ipd_remaining == 7u,
          "implicit link: fields preserved");

    reset_state();
    strcpy(line_buf, "+IPD,04,7:");
    check(direct_parse_ipd_header_ovl() && direct_ipd_link == 4u &&
              direct_ipd_remaining == 7u,
          "padded link: header accepted");

    reset_state();
    strcpy(line_buf, "+IPD,4,7,1:");
    check(!direct_parse_ipd_header_ovl(), "extra field: header rejected");
    check(direct_ipd_remaining == 0u && !direct_ipd_accept,
          "extra field: parser state unchanged");

    reset_state();
    strcpy(line_buf, "+IPD,4,:");
    check(!direct_parse_ipd_header_ovl(), "empty length: header rejected");
}

static void test_two_frame_read_cadence(void)
{
    static const uint8_t delayed[] = "+IPD,0,5:PING\n";
    static const uint8_t prefixed[] = "OK\r\n+IPD,0,5:PONG\n";
    char out[SPECTRUM_NET_PAYLOAD_MAX];

    reset_state();
    uart_feed = delayed;
    uart_feed_len = sizeof(delayed) - 1u;
    release_uart_at(0u, 0u, 1u);
    check(dequeue(out, sizeof(out)) == 0u,
          "two-frame read: delayed payload delivered");
    check(strcmp(out, "PING") == 0, "two-frame read: delayed payload exact");
    check(frame_count == 1u, "two-frame read: one empty frame elapsed");

    reset_state();
    uart_feed = prefixed;
    uart_feed_len = sizeof(prefixed) - 1u;
    check(dequeue(out, sizeof(out)) == (uint8_t)SPECTRUM_NET_READ_TIMEOUT,
          "two-frame read: line event short-circuits second drain");
    check(dequeue(out, sizeof(out)) == 0u && strcmp(out, "PONG") == 0,
          "two-frame read: next poll delivers queued payload");
}

static void test_impossible_block_does_not_swallow_prompt(void)
{
    static const uint8_t replies[] = "+IPD,0,2049:>\r\nSEND OK\r\n";

    reset_state();
    active_link = 0u;
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;

    check(direct_send_payload_ovl("ACK PING", active_link),
          "impossible block: prompt remains visible");
    check(direct_ipd_remaining == 0u,
          "impossible block: receive count not poisoned");
    check(strcmp(uart_tx, "AT+CIPSEND=0,9\r\nACK PING\n") == 0,
          "impossible block: ACK PING remains byte exact");
}

/* Dequeuing a completed line must not clobber a partial line still gathering
   in the other slot. */
static void test_dequeue_keeps_partial(void)
{
    char out[SPECTRUM_NET_PAYLOAD_MAX];

    reset_state();
    feed_str("+IPD,0,9:LINE1\nPAR");
    check(direct_rx_count == 1u, "partial: first line queued");
    check(dequeue(out, sizeof(out)) == 0u, "partial: dequeue link id");
    check(strcmp(out, "LINE1") == 0, "partial: dequeued line");

    feed_str("+IPD,0,3:T1\n");
    check(direct_rx_count == 1u, "partial: continued line queued");
    check(dequeue(out, sizeof(out)) == 0u, "partial: continuation link id");
    check(strcmp(out, "PART1") == 0, "partial: continuation payload");
}

static void test_intruder_gets_busy_before_close(void)
{
    static const uint8_t replies[] = ">\r\nSEND OK\r\nOK\r\n";

    reset_state();
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;
    direct_peer_valid = 1u;
    direct_intruder_link = 2u;
    direct_reject_intruder_ovl();

    check(strcmp(uart_tx,
                 "AT+CIPSEND=2,5\r\nBUSY\nAT+CIPCLOSE=2\r\n") == 0,
          "intruder: BUSY sent before close");
    check(direct_intruder_link == 0xffu, "intruder: rejection consumed");
}

static void test_unvalidated_peer_does_not_claim_busy(void)
{
    static const uint8_t replies[] = "OK\r\n";

    reset_state();
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;
    direct_intruder_link = 2u;
    direct_reject_intruder_ovl();

    check(strcmp(uart_tx, "AT+CIPCLOSE=2\r\n") == 0,
          "handshake intruder: close without false BUSY");
}

/* The PC aborts immediately after receiving BUSY. ESP-AT may then report
   ERROR for that CIPSEND before accepting CIPCLOSE=<intruder>. The ERROR
   belongs to the intruder command and must not poison the active peer link. */
static void test_intruder_send_error_keeps_active_link(void)
{
    static const uint8_t replies[] = ">\r\nERROR\r\nOK\r\n";

    reset_state();
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;
    direct_peer_valid = 1u;
    direct_intruder_link = 2u;
    direct_reject_intruder_ovl();

    check(!direct_link_closed,
          "intruder send error: active link remains open");
}

static void test_active_close_during_intruder_rejection_survives(void)
{
    static const uint8_t replies[] = ">\r\n0,CLOSED\r\nOK\r\n";

    reset_state();
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;
    direct_peer_valid = 1u;
    direct_intruder_link = 2u;
    direct_reject_intruder_ovl();

    check(direct_link_closed,
          "intruder rejection: real active close remains observable");
}

static void test_busy_payload_precedes_close(void)
{
    static const uint8_t replies[] =
        ">\r\n+IPD,0,5:BUSY\n\r\n0,CLOSED\r\n";
    char out[SPECTRUM_NET_PAYLOAD_MAX];

    reset_state();
    active_link = 0u;
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;

    check(direct_send_payload_ovl("HELLO DIRECT GUEST", active_link),
          "busy-close: queued payload keeps send alive");
    check(dequeue(out, sizeof(out)) == 0u,
          "busy-close: payload delivered before close");
    check(strcmp(out, "BUSY") == 0, "busy-close: busy payload");
    check(dequeue(out, sizeof(out)) == 0xfeu,
          "busy-close: close delivered after payload");
}

static void test_close_without_payload_fails_send(void)
{
    static const uint8_t replies[] = ">\r\n0,CLOSED\r\n";
    char out[SPECTRUM_NET_PAYLOAD_MAX];

    reset_state();
    active_link = 0u;
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;

    check(!direct_send_payload_ovl("HELLO DIRECT GUEST", active_link),
          "close-only: send fails without payload");
    check(dequeue(out, sizeof(out)) == 0xfeu,
          "close-only: close remains observable");
}

static void test_delayed_esp_send_succeeds(void)
{
    static const uint8_t replies[] = ">\r\nSEND OK\r\n";

    reset_state();
    active_link = 0u;
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;
    release_uart_at(0u, 0u, 3u);
    release_uart_at(1u, 1u, 8u);

    check(direct_send_payload_ovl("PING", active_link),
          "slow ESP: delayed prompt and SEND OK succeed");
    check(frame_count >= 8u && frame_count < WAIT_DIRECT_PROMPT,
          "slow ESP: product waits for delayed replies by frame");
    check(strcmp(uart_tx, "AT+CIPSEND=0,5\r\nPING\n") == 0,
          "slow ESP: outgoing PING remains byte exact");
}

static void test_esp_error_before_close_fails_send(void)
{
    static const uint8_t replies[] = ">\r\nERROR\r\n";

    reset_state();
    active_link = 0u;
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;
    release_uart_at(0u, 0u, 2u);
    release_uart_at(1u, 1u, 5u);

    check(!direct_send_payload_ovl("PING", active_link),
          "slow ESP: ERROR fails handoff before CLOSED");
    check(!direct_link_closed,
          "slow ESP: send failure is distinct from link close");
    check(frame_count >= 5u && frame_count < WAIT_DIRECT_SEND_OK,
          "slow ESP: ERROR terminates the bounded wait early");
}

static void test_listen_command_exact(void)
{
    static const uint8_t replies[] = "OK\r\n";

    reset_state();
    netchesszx_direct_port = 4242u;
    uart_feed = replies;
    uart_feed_len = sizeof(replies) - 1u;
    check(direct_listen_ovl(), "listen command: server accepts OK");
    check(strcmp(uart_tx, "AT+CIPSERVER=1,4242\r\n") == 0,
          "listen command: wire bytes exact");
}

int main(void)
{
    test_coalesced_lines();
    test_three_lines_during_send_wait();
    test_max_payload_in_spill();
    test_split_line();
    test_large_block_header();
    test_two_frame_read_cadence();
    test_impossible_block_does_not_swallow_prompt();
    test_dequeue_keeps_partial();
    test_intruder_gets_busy_before_close();
    test_unvalidated_peer_does_not_claim_busy();
    test_intruder_send_error_keeps_active_link();
    test_active_close_during_intruder_rejection_survives();
    test_busy_payload_precedes_close();
    test_close_without_payload_fails_send();
    test_delayed_esp_send_succeeds();
    test_esp_error_before_close_fails_send();
    test_listen_command_exact();

    if (failures != 0) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("direct ipd tests passed\n");
    return 0;
}
