#define NETCHESSZX_HOST_SESSION_TEST 1

#include "direct_parity.h"

#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wunused-variable"
#endif
#include "../../src/spectrum/app/app.c"
#include "../../src/spectrum/overlay/direct_ovl.c"
#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

typedef char direct_parity_nack_sync_capacity_check[
    sizeof("NACK 65535 SYNC") == 16u &&
    sizeof("NACK 65535 SYNC") <= SPECTRUM_LINK_PAYLOAD_MAX ? 1 : -1];

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

netchesszx_session_ping_t *netchesszx_host_session_ping;

void netchesszx_host_session_observe_ping_reset(
    netchesszx_session_ping_t *ping)
{
    (void)ping;
}

static char host_payload[SPECTRUM_LINK_PAYLOAD_MAX];
static const DirectParityScenario *host_scenario;
static DirectParityTrace *host_trace;
static uint8_t host_step_pos;
static uint8_t host_link_id;
static uint8_t host_role;
static uint8_t host_side_initialized;
static uint8_t host_observed_color;
static uint8_t host_ready_seen;
static uint8_t host_started_seen;
static uint8_t host_failed;
static uint16_t host_now_ticks;
static uint16_t host_timeout_deadline;
static uint8_t host_timeout_active;
static const uint8_t *host_fail_payload;
static uint8_t host_fail_length;
static uint8_t host_failed_send_pending;
static uint8_t host_active_link_down;
static uint8_t host_control_draw_pending;
static uint8_t host_control_reset_pending;
static uint8_t host_local_confirm_pending;
static uint8_t host_local_draw_pending;
static uint8_t host_local_reset_pending;
static uint8_t host_local_takeback_pending;
static uint8_t host_takeback_result_seen;
static uint8_t host_resign_control_pending;
static uint8_t host_local_resign_pending;
static uint8_t host_connected_state;
static uint8_t host_pieces_visible;
static uint8_t host_board_flipped;
static uint8_t host_side_panels_visible;
static uint8_t host_about_visible;
static uint8_t host_fileui_visible;
static uint8_t host_menu_key_calls;
static uint8_t host_menu_visible;
static const uint8_t *host_restore_file_payload;
static uint8_t host_restore_apply_pending;
static uint8_t host_restore_marker_seen;
static uint8_t host_restore_domain_pending;
static uint8_t host_restore_result_seen;
static uint8_t host_restore_reject_seen;
static uint8_t host_restore_control_pending;
#ifdef NETCHESSZX_NEXT_BANKING
static uint8_t host_next_sprites_reset_seen;
#endif
#ifdef NETCHESSZX_NEXT
uint8_t net_uart_direct_idle_ticks = 75u;
#endif

/* Real DIRECT overlay state and UART seam.  Candidate transcripts enter the
   same parser/rejector used by the target; this harness only captures its AT
   wire and normalizes that physical wire to SEND/CLOSE observations. */
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
static const uint8_t *host_uart_feed;
static size_t host_uart_feed_len;
static size_t host_uart_feed_pos;
static char host_uart_tx[96];
static size_t host_uart_tx_len;

void reset_line_buf(void)
{
    line_pos = 0u;
    line_buf[0] = '\0';
}

void net_wait_frame(void) {}
uint8_t spectrum_uart_ready(void)
{
    return (uint8_t)(host_uart_feed_pos < host_uart_feed_len);
}
uint8_t spectrum_uart_read(void) { return host_uart_feed[host_uart_feed_pos++]; }
static uint8_t host_uart_capture(const uint8_t *data, size_t length)
{
    if (host_uart_tx_len + length >= sizeof(host_uart_tx)) {
        host_failed = 1u;
        return 0u;
    }
    memcpy(host_uart_tx + host_uart_tx_len, data, length);
    host_uart_tx_len += length;
    host_uart_tx[host_uart_tx_len] = '\0';
    return 1u;
}
uint8_t spectrum_uart_send_string(const char *text)
{
    return host_uart_capture((const uint8_t *)text, strlen(text));
}
uint8_t spectrum_uart_send_bytes(const uint8_t *data, uint8_t length)
{
    return host_uart_capture(data, length);
}
uint8_t spectrum_uart_send_crlf(void)
{
    return host_uart_capture((const uint8_t *)"\r\n", 2u);
}
uint8_t spectrum_key_poll(void) { return 0u; }
void spectrum_net_guard_wait(uint16_t frames) { (void)frames; }
uint8_t spectrum_net_at_cmd(const char *command, uint16_t frames)
{
    (void)command;
    (void)frames;
    return 1u;
}
uint8_t spectrum_net_ensure_command_mode(void) { return 1u; }

static void check(uint8_t condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void check_restore_host_color_guard(void)
{
    netchesszx_save_meta_t meta = { 0 };

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    meta.host_color = NETCHESSZX_SAVE_HOST_WHITE;
    check(restore_host_color_ok(&meta),
          "matching DIRECT restore host color accepted");
    meta.host_color = NETCHESSZX_SAVE_HOST_BLACK;
    check(!restore_host_color_ok(&meta),
          "cross-color DIRECT restore rejected");
}

#ifdef NETCHESSZX_NEXT_BANKING
static uint8_t host_next_find_slot(const uint8_t *slots, uint8_t square)
{
    uint8_t i;

    for (i = 0u; i < 32u; ++i) {
        if (slots[i] == square) {
            return i;
        }
    }
    return 0xffu;
}

static uint8_t host_next_restore_redraw(uint8_t reset_slots)
{
    static const char initial[65] =
        "rnbqkbnrpppppppp................................PPPPPPPPRNBQKBNR";
    char target[64];
    uint8_t slots[32];
    uint8_t slot_count = 0u;
    uint8_t square;
    uint8_t drawn = 0u;

    memcpy(target, initial, sizeof(target));
    target[1] = '.';
    target[18] = 'n';
    target[36] = 'P';
    target[52] = '.';
    for (square = 0u; square < 64u; ++square) {
        if (initial[square] != '.') {
            slots[slot_count++] = square;
        }
    }
    check(slot_count == 32u, "Next sprite fixture starts with 32 pieces");
    if (reset_slots) {
        memset(slots, 0xff, sizeof(slots));
    }

    /* Faithful branch transcription of screen.asm next_find_slot,
       next_alloc_slot and next_hide_piece_slot while redraw scans 0..63. */
    for (square = 0u; square < 64u; ++square) {
        uint8_t slot = host_next_find_slot(slots, square);

        if (target[square] == '.') {
            if (slot != 0xffu) {
                slots[slot] = 0xffu;
            }
            continue;
        }
        if (slot == 0xffu) {
            slot = host_next_find_slot(slots, 0xffu);
            if (slot == 0xffu) {
                continue;
            }
            slots[slot] = square;
        }
        if (square == 36u) {
            drawn |= 1u;
        } else if (square == 18u) {
            drawn |= 2u;
        }
    }
    return drawn;
}

static void check_next_restore_sprite_allocator_contract(void)
{
    check(host_next_restore_redraw(0u) == 2u,
          "dirty Next slots drop e4 but draw c6");
    check(host_next_restore_redraw(1u) == 3u,
          "reset Next slots draw e4 and c6");
}
#endif

static void check_restore_codec_contract(void)
{
    static const char expected_b64[] =
        "uazam4iIiIgAAAAAAAAAAAAAAAAAAAAAEREREUI1YyR8_wAAAQEAAAAAOwGm";
    static const char expected_chunk_0[] =
        "uazam4iIiIgAAAAAAAAAAAAAAAAAAA";
    static const char expected_chunk_1[] =
        "AAEREREUI1YyR8_wAAAQEAAAAAOwGm";
    spectrum_board_snapshot_t source;
    spectrum_board_snapshot_t decoded;
    netchesszx_save_meta_t source_meta = { 0 };
    netchesszx_save_meta_t decoded_meta = { 0 };
    char b64[NETCHESSZX_SAVE_WIRE_B64_SIZE];

    spectrum_board_reset();
    spectrum_board_snapshot_save(&source);
    source_meta.flags = NETCHESSZX_SAVE_FLAG_ACTIVE;
    source_meta.host_color = NETCHESSZX_SAVE_HOST_WHITE;
    source_meta.view_flags = NETCHESSZX_SAVE_VIEW_FLIPPED;
    source_meta.timers[0] = 1u;
    source_meta.timers[5] = 59u;
    check(spectrum_restore_build_b64(&source, &source_meta, b64),
          "real restore overlay host encoder");
    check(sizeof(expected_b64) - 1u == NETCHESSZX_SAVE_WIRE_B64_SIZE &&
              sizeof(expected_chunk_0) - 1u == NETCHESSZX_SAVE_WIRE_CHUNK_SIZE &&
              sizeof(expected_chunk_1) - 1u == NETCHESSZX_SAVE_WIRE_CHUNK_SIZE &&
              memcmp(b64, expected_b64, NETCHESSZX_SAVE_WIRE_B64_SIZE) == 0 &&
              memcmp(b64, expected_chunk_0,
                     NETCHESSZX_SAVE_WIRE_CHUNK_SIZE) == 0 &&
              memcmp(b64 + NETCHESSZX_SAVE_WIRE_CHUNK_SIZE,
                     expected_chunk_1, NETCHESSZX_SAVE_WIRE_CHUNK_SIZE) == 0,
          "real restore overlay exact 60-byte two-chunk vector");
    check(spectrum_restore_decode(b64, &decoded, &decoded_meta),
          "real restore overlay host decoder");
    check(memcmp(source.cells, decoded.cells, sizeof(source.cells)) == 0 &&
              source.side == decoded.side &&
              source.castle == decoded.castle && source.ep == decoded.ep &&
              source_meta.ply == decoded_meta.ply &&
              source_meta.flags == decoded_meta.flags &&
              source_meta.host_color == decoded_meta.host_color &&
              source_meta.view_flags == decoded_meta.view_flags &&
              memcmp(source_meta.timers, decoded_meta.timers,
                     sizeof(source_meta.timers)) == 0,
          "real restore overlay roundtrip");
    b64[0] = '!';
    check(!spectrum_restore_decode(b64, &decoded, &decoded_meta),
          "real restore overlay rejects invalid base64");
}

static uint8_t host_trace_push(uint8_t type,
                               uint8_t link_id,
                               uint8_t code,
                               uint16_t value,
                               const char *payload)
{
    DirectParityObservation *observation;
    size_t length = payload == 0 ? 0u : strlen(payload);

    if (host_trace == 0 || host_trace->count >= DIRECT_PARITY_TRACE_CAPACITY ||
        length >= DIRECT_PARITY_PAYLOAD_CAPACITY) {
        host_failed = 1u;
        return 0u;
    }
    observation = &host_trace->observations[host_trace->count++];
    observation->type = type;
    observation->link_id = link_id;
    observation->code = code;
    observation->value = value;
    observation->length = (uint8_t)length;
    if (length != 0u) {
        memcpy(observation->payload, payload, length);
    }
    observation->payload[length] = '\0';
    return 1u;
}

static uint8_t host_restore_phase(void)
{
    if (game_over) {
        return DIRECT_PARITY_PHASE_OVER;
    }
    return game_status_active ? DIRECT_PARITY_PHASE_ACTIVE
                              : DIRECT_PARITY_PHASE_READY;
}

static void host_observe_restore_apply(void)
{
    static const char ready[] = "R";
    static const char active[] = "A";
    static const char over[] = "O";
    uint8_t phase = host_restore_phase();
    const char *text = phase == DIRECT_PARITY_PHASE_READY
        ? ready : (phase == DIRECT_PARITY_PHASE_ACTIVE ? active : over);

    if (!host_restore_apply_pending || host_restore_control_pending == 0u ||
        host_restore_marker_seen != 1u) {
        host_failed = 1u;
        return;
    }
    host_restore_apply_pending = 0u;
    host_restore_marker_seen = 0u;
    host_restore_control_pending = 0u;
    if (host_restore_domain_pending) {
        host_restore_result_seen = 1u;
    }
    (void)host_trace_push(DIRECT_PARITY_OBS_GAME,
                          DIRECT_PARITY_LINK_NONE,
                          DIRECT_PARITY_GAME_RESTORE, game_ply, text);
}

static void host_observe_restore_rejected(uint8_t domain_result)
{
    if (!host_restore_control_pending || host_restore_apply_pending) {
        host_failed = 1u;
        return;
    }
    host_restore_control_pending = 0u;
    host_restore_domain_pending = 0u;
    host_restore_reject_seen = domain_result;
    (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL_RESULT,
                          DIRECT_PARITY_LINK_NONE,
                          DIRECT_PARITY_REQUEST_RESTORE,
                          DIRECT_PARITY_RESULT_REJECTED, "RN");
}

static void host_observe_side(void)
{
    if (host_role == DIRECT_PARITY_ROLE_GUEST &&
        netchesszx_session_peer_ready() &&
        (!host_side_initialized ||
         host_observed_color != netchesszx_local_color)) {
        host_side_initialized = 1u;
        host_observed_color = netchesszx_local_color;
        (void)host_trace_push(DIRECT_PARITY_OBS_SIDE,
                              DIRECT_PARITY_LINK_NONE,
                              netchesszx_local_color, 0u, 0);
    }
}

static void host_transport_feed(const uint8_t *bytes, size_t length)
{
    size_t i;

    for (i = 0u; i < length; ++i) {
        (void)direct_feed_uart_byte_ovl(bytes[i]);
    }
}

static uint8_t host_transport_reject_intruder(const DirectParityStep *step)
{
    static const uint8_t validated_replies[] = ">\r\nSEND OK\r\nOK\r\n";
    static const uint8_t handshake_replies[] = "OK\r\n";
    static const uint8_t active_close_replies[] = ">\r\n1,CLOSED\r\nOK\r\n";
    char header[24];
    char expected[64];
    char payload[SPECTRUM_NET_PAYLOAD_MAX];
    uint8_t ctx[3] = { 0u, 0u, (uint8_t)sizeof(payload) };
    int header_length;
    int expected_length;
    uint8_t active_closed;
    uint8_t read_result;

    if (step == 0 || step->payload == 0 || step->length == 0u ||
        step->link_id == host_link_id || step->link_id > 4u ||
        direct_ipd_remaining != 0u || direct_intruder_link != 0xffu) {
        return 0u;
    }
    header_length = snprintf(header, sizeof(header), "+IPD,%u,%u:",
                             (unsigned)step->link_id,
                             (unsigned)(step->length + 1u));
    if (header_length <= 0 || (size_t)header_length >= sizeof(header)) {
        return 0u;
    }
    host_transport_feed((const uint8_t *)header, (size_t)header_length);
    host_transport_feed(step->payload, step->length);
    host_transport_feed((const uint8_t *)"\n", 1u);
    if (direct_intruder_link != step->link_id || direct_ipd_remaining != 0u) {
        return 0u;
    }

    active_closed = (uint8_t)(host_fail_length == 4u &&
        host_fail_payload != 0 && memcmp(host_fail_payload, "BUSY", 4u) == 0);
    if (host_fail_length != 0u && !active_closed) {
        return 0u;
    }

    host_uart_tx_len = 0u;
    host_uart_tx[0] = '\0';
    host_uart_feed = active_closed ? active_close_replies
        : (direct_peer_valid ? validated_replies : handshake_replies);
    host_uart_feed_len = active_closed ? sizeof(active_close_replies) - 1u
        : (direct_peer_valid ? sizeof(validated_replies) - 1u
                             : sizeof(handshake_replies) - 1u);
    host_uart_feed_pos = 0u;
    direct_host_test_ptr = payload;
    read_result = direct_read_payload_ovl(ctx);
    if (read_result != (active_closed ? 0xfeu
                                      : (uint8_t)SPECTRUM_NET_READ_TIMEOUT) ||
        host_uart_feed_pos != host_uart_feed_len ||
        direct_link_closed != active_closed ||
        active_link != host_link_id || direct_intruder_link != 0xffu) {
        return 0u;
    }
    if (active_closed) {
        host_fail_payload = 0;
        host_fail_length = 0u;
    }

    if (direct_peer_valid) {
        expected_length = snprintf(expected, sizeof(expected),
            "AT+CIPSEND=%u,5\r\nBUSY\nAT+CIPCLOSE=%u\r\n",
            (unsigned)step->link_id, (unsigned)step->link_id);
    } else {
        expected_length = snprintf(expected, sizeof(expected),
            "AT+CIPCLOSE=%u\r\n", (unsigned)step->link_id);
    }
    if (expected_length <= 0 || (size_t)expected_length >= sizeof(expected) ||
        strcmp(host_uart_tx, expected) != 0) {
        return 0u;
    }
    if (direct_peer_valid &&
        !host_trace_push(DIRECT_PARITY_OBS_SEND, step->link_id,
                         0u, 0u, "BUSY")) {
        return 0u;
    }
    return host_trace_push(DIRECT_PARITY_OBS_CLOSE, step->link_id,
                           0u, 0u, 0);
}

static uint8_t host_transport_link_down(uint8_t link_id)
{
    char line[12];
    int length;

    if (link_id > 4u || direct_ipd_remaining != 0u) {
        return 0u;
    }
    length = snprintf(line, sizeof(line), "%u,CLOSED\r\n",
                      (unsigned)link_id);
    if (length <= 0 || (size_t)length >= sizeof(line)) {
        return 0u;
    }
    host_transport_feed((const uint8_t *)line, (size_t)length);
    return (uint8_t)(direct_link_closed == (link_id == host_link_id));
}

static void host_transport_begin_link(uint8_t link_id)
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
    active_link = link_id;
    host_uart_feed = 0;
    host_uart_feed_len = 0u;
    host_uart_feed_pos = 0u;
    host_uart_tx_len = 0u;
    host_uart_tx[0] = '\0';
    reset_line_buf();
}

char *spectrum_net_payload_scratch(void)
{
    return host_payload;
}

int16_t spectrum_net_read_payload(char *payload, uint8_t payload_cap)
{
    const DirectParityStep *step;

read_next_step:
    if (host_local_confirm_pending) {
        spectrum_frame_wait();
        spectrum_frame_wait();
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    if (host_scenario == 0 || host_step_pos >= host_scenario->step_count) {
        host_failed = 1u;
        return -2;
    }
    step = &host_scenario->steps[host_step_pos];
    if (step->type == DIRECT_PARITY_IN_LOCAL ||
        step->type == DIRECT_PARITY_IN_DOMAIN ||
        step->type == DIRECT_PARITY_IN_SEND_FAIL ||
        step->type == DIRECT_PARITY_IN_SEND_PENDING ||
        step->type == DIRECT_PARITY_IN_TX_RESULT ||
        step->type == DIRECT_PARITY_IN_TX_GUARD_TIMEOUT ||
        step->type == DIRECT_PARITY_IN_DECISION) {
        spectrum_frame_wait();
        spectrum_frame_wait();
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    /* A failed send that reaches another transport poll did not trigger
       fail-hard teardown (ACK PING is the intentional compact equivalent). */
    host_failed_send_pending = 0u;
    ++host_step_pos;
    if (step->type == DIRECT_PARITY_IN_RX &&
        step->link_id != host_link_id) {
        if (!host_transport_reject_intruder(step)) {
            host_failed = 1u;
            return -2;
        }
        goto read_next_step;
    }
    if (step->type == DIRECT_PARITY_IN_LINK_DOWN) {
        if (!host_transport_link_down(step->link_id)) {
            host_failed = 1u;
            return -2;
        }
        host_active_link_down = (uint8_t)(step->link_id == host_link_id);
        if (step->link_id == host_link_id) {
            return -2;
        }
        goto read_next_step;
    }
    if (step->type == DIRECT_PARITY_IN_RX && step->payload != 0 &&
        step->length == 6u && memcmp(step->payload, "RESIGN", 6u) == 0 &&
        game_status_active) {
        host_resign_control_pending = 1u;
    }
    if (step->type == DIRECT_PARITY_IN_RX && step->payload != 0 &&
        step->length == 2u && memcmp(step->payload, "RQ", 2u) == 0 &&
        host_role == DIRECT_PARITY_ROLE_GUEST) {
        host_restore_control_pending = 1u;
        host_restore_domain_pending = 1u;
    }
    if (step->type == DIRECT_PARITY_IN_TIMEOUT) {
        --host_step_pos;
        if (!host_timeout_active) {
            if (step->value == 0u || (step->value & 1u) != 0u) {
                host_failed = 1u;
                return -2;
            }
            host_timeout_deadline = (uint16_t)(host_now_ticks + step->value);
            host_timeout_active = 1u;
        }
        /* direct_read_payload_ovl() waits WAIT_POLL=2 PAL frames before
           returning one transport timeout. Keep one 20 ms protocol clock. */
        spectrum_frame_wait();
        spectrum_frame_wait();
        if (host_now_ticks == host_timeout_deadline) {
            host_timeout_active = 0u;
            ++host_step_pos;
        }
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    if (step->type != DIRECT_PARITY_IN_RX || step->payload == 0 ||
        step->length == 0u || step->length >= payload_cap) {
        host_failed = 1u;
        return -2;
    }
    memcpy(payload, step->payload, step->length);
    payload[step->length] = '\0';
    return 0;
}

uint8_t spectrum_net_send_text(const char *text)
{
    uint8_t traced;

    if (strcmp(text, "RESET") == 0 && host_local_resign_pending) {
        host_local_resign_pending = 0u;
        (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL_RESULT,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_RESIGN,
                              DIRECT_PARITY_RESULT_ACCEPTED, 0);
    }
    if (strcmp(text, "RESET") == 0 &&
        last_control_accept == CONTROL_ACCEPT_RESIGN) {
        host_local_reset_pending = 1u;
    } else if (strcmp(text, "ACK RESET") == 0 &&
               last_control_accept == CONTROL_ACCEPT_RESIGN) {
        host_control_reset_pending = 1u;
    }
    host_observe_side();
    traced = host_trace_push(DIRECT_PARITY_OBS_SEND, host_link_id,
                             0u, 0u, text);
    if (traced && strcmp(text, "ACK RESIGN") == 0 &&
        host_local_resign_pending) {
        host_local_resign_pending = 0u;
        (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL_RESULT,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_RESIGN,
                              DIRECT_PARITY_RESULT_ACCEPTED, 0);
    }
    if (!traced || host_fail_length == 0u) {
        return traced;
    }
    if (host_fail_payload == 0 || strlen(text) != host_fail_length ||
        memcmp(text, host_fail_payload, host_fail_length) != 0) {
        host_failed = 1u;
        return 0u;
    }
    host_fail_payload = 0;
    host_fail_length = 0u;
    host_failed_send_pending = 1u;
    return 0u;
}

void spectrum_net_direct_peer_mark_valid(void) { direct_peer_valid = 1u; }
void spectrum_net_background_drain(void) {}
/* DIRECT fixture: transcript RX is live/non-retained and has no unframed
   activity outside explicit steps. */
uint8_t spectrum_net_payload_flags(void) { return 0u; }
uint8_t spectrum_net_link_activity(void) { return 0u; }
uint8_t spectrum_net_mqtt_activate_side(void)
{
    host_failed = 1u;
    return 0u;
}
uint8_t spectrum_net_mqtt_probe_seat(void)
{
    host_failed = 1u;
    return 0u;
}
uint8_t spectrum_net_mqtt_publish_presence(void)
{
    host_failed = 1u;
    return 0u;
}
uint8_t spectrum_net_mqtt_publish_offline(uint8_t route)
{
    (void)route;
    host_failed = 1u;
    return 0u;
}
uint8_t spectrum_net_mqtt_publish_setup(uint8_t mode)
{
    (void)mode;
    host_failed = 1u;
    return 0u;
}
uint8_t spectrum_net_send_ping(void)
{
    return spectrum_net_send_text("PING");
}
uint8_t spectrum_net_sync_time(void)
{
    host_failed = 1u;
    return 0u;
}
uint8_t spectrum_net_preflight_run(void)
{
    host_failed = 1u;
    return 0u;
}
const char *spectrum_net_last_ip(void)
{
    host_failed = 1u;
    return "";
}
uint8_t spectrum_net_runtime_clock_ready(void)
{
    host_failed = 1u;
    return 0u;
}
uint8_t netchesszx_asm_mqtt_strlen8(const char *text)
{
    uint8_t length = 0u;

    while (text[length] != '\0') {
        ++length;
    }
    return length;
}

uint8_t netchesszx_asm_restore_chunk_step(uint8_t *mask,
                                          char *cache,
                                          const char *frame)
{
    uint8_t chunk = (uint8_t)(frame[3] - '0');
    uint8_t off = (uint8_t)(chunk * NETCHESSZX_SAVE_WIRE_CHUNK_SIZE);

    if ((*mask & RESTORE_RX_APPLIED) != 0u) {
        if (memcmp(cache + off, frame + 5u,
                   NETCHESSZX_SAVE_WIRE_CHUNK_SIZE) != 0) {
            *mask = 0u;
            return RESTORE_CHUNK_REJECT;
        }
        return RESTORE_CHUNK_REACK;
    }
    if ((*mask & RESTORE_RX_RECEIVE) == 0u) {
        return RESTORE_CHUNK_REJECT;
    }
    memcpy(cache + off, frame + 5u, NETCHESSZX_SAVE_WIRE_CHUNK_SIZE);
    *mask |= (uint8_t)(1u << chunk);
    return (*mask & RESTORE_RX_ALL) == RESTORE_RX_ALL
        ? RESTORE_CHUNK_COMPLETE : RESTORE_CHUNK_PARTIAL;
}

uint8_t spectrum_gui_poll_key(void)
{
    const DirectParityStep *step;

    if (host_local_confirm_pending) {
        host_local_confirm_pending = 0u;
        if (confirm_action == CONFIRM_DRAW_SEND) {
            host_local_draw_pending = 1u;
        } else if (confirm_action == CONFIRM_RESET_SEND) {
            host_local_reset_pending = 1u;
        }
        if (confirm_action != CONFIRM_NONE) {
            return 'y';
        }
    }
    if (host_scenario != 0 && host_step_pos < host_scenario->step_count) {
process_next_step:
        step = &host_scenario->steps[host_step_pos];
        if (step->type == DIRECT_PARITY_IN_LOCAL) {
            ++host_step_pos;
            if (step->request == DIRECT_PARITY_REQUEST_START) {
                return 32u;
            }
            if (step->request == DIRECT_PARITY_REQUEST_BYE &&
                step->length == 0u) {
                confirm_action = CONFIRM_DISCONNECT;
                return 'y';
            }
            if ((step->request == DIRECT_PARITY_REQUEST_MOVE ||
                 step->request == DIRECT_PARITY_REQUEST_CHAT) &&
                step->payload != 0) {
                if (step->length >= NETCHESSZX_LOWRAM_LOCAL_INPUT_SIZE) {
                    host_failed = 1u;
                    return 0u;
                }
                memcpy(local_input, step->payload, step->length);
                local_input[step->length] = '\0';
                local_input_len = step->length;
                local_input_cursor = step->length;
                local_input_mode = 1u;
                return 13u;
            }
            if (step->request == DIRECT_PARITY_REQUEST_DRAW &&
                step->length == 0u) {
                memcpy(local_input, "/draw", 6u);
                local_input_len = 5u;
                local_input_cursor = 5u;
                local_input_mode = 1u;
                host_local_confirm_pending = 1u;
                return 13u;
            }
            if (step->request == DIRECT_PARITY_REQUEST_RESET &&
                step->length == 0u) {
                host_local_confirm_pending = 1u;
                return SPECTRUM_GUI_KEY_MENU_REST;
            }
            if (step->request == DIRECT_PARITY_REQUEST_RESIGN &&
                step->length == 0u) {
                memcpy(local_input, "/resign", 8u);
                local_input_len = 7u;
                local_input_cursor = 7u;
                local_input_mode = 1u;
                host_local_confirm_pending = 1u;
                host_resign_control_pending = 1u;
                host_local_resign_pending = 1u;
                return 13u;
            }
            if (step->request == DIRECT_PARITY_REQUEST_TAKEBACK &&
                step->length == 0u) {
                memcpy(local_input, "/takeback", 10u);
                local_input_len = 9u;
                local_input_cursor = 9u;
                local_input_mode = 1u;
                host_local_confirm_pending = 1u;
                host_local_takeback_pending = 1u;
                return 13u;
            }
            if (step->request == DIRECT_PARITY_REQUEST_RESTORE) {
                if (step->length == 0u) {
                    return KEY_CANCEL;
                }
                if (step->payload == 0 ||
                    step->length != NETCHESSZX_SAVE_WIRE_B64_SIZE) {
                    host_failed = 1u;
                    return 0u;
                }
                host_restore_file_payload = step->payload;
                host_restore_control_pending = 1u;
                host_restore_domain_pending = 0u;
                local_load_game("PARITY");
                host_restore_file_payload = 0;
                return 0u;
            }
            host_failed = 1u;
        } else if (step->type == DIRECT_PARITY_IN_DOMAIN) {
            ++host_step_pos;
            if (step->phase != 0u) {
                if (host_step_pos < host_scenario->step_count) {
                    goto process_next_step;
                }
            } else if (host_restore_result_seen) {
                if (step->request != DIRECT_PARITY_RESULT_ACCEPTED ||
                    step->payload == 0 || step->length != 1u ||
                    step->value != game_ply ||
                    step->payload[0] != host_restore_phase()) {
                    host_failed = 1u;
                }
                host_restore_result_seen = 0u;
                host_restore_domain_pending = 0u;
            } else if (host_restore_reject_seen) {
                if (step->request != DIRECT_PARITY_RESULT_REJECTED) {
                    host_failed = 1u;
                }
                host_restore_reject_seen = 0u;
            } else if (step->request != DIRECT_PARITY_RESULT_ACCEPTED) {
                host_failed = 1u;
            }
            if (host_takeback_result_seen) {
                if (step->value == 0u || game_ply != step->value - 1u) {
                    host_failed = 1u;
                }
                host_takeback_result_seen = 0u;
            }
        } else if (step->type == DIRECT_PARITY_IN_SEND_FAIL ||
                   step->type == DIRECT_PARITY_IN_SEND_PENDING) {
            ++host_step_pos;
            if (host_fail_length != 0u || step->payload == 0 ||
                step->length == 0u) {
                host_failed = 1u;
            } else {
                host_fail_payload = step->payload;
                host_fail_length = step->length;
                if (host_step_pos < host_scenario->step_count) {
                    goto process_next_step;
                }
            }
        } else if (step->type == DIRECT_PARITY_IN_TX_GUARD_TIMEOUT) {
            ++host_step_pos;
            if (!host_failed_send_pending) {
                host_failed = 1u;
            }
            host_failed_send_pending = 0u;
            if (host_step_pos < host_scenario->step_count) {
                goto process_next_step;
            }
        } else if (step->type == DIRECT_PARITY_IN_TX_RESULT) {
            ++host_step_pos;
            if (step->request != DIRECT_PARITY_TX_OK &&
                step->request != DIRECT_PARITY_TX_FAILED) {
                host_failed = 1u;
            } else if (step->phase == 0u) {
                if (!host_failed_send_pending) {
                    host_failed = 1u;
                }
                host_failed_send_pending = 0u;
            }
            if (host_step_pos < host_scenario->step_count) {
                goto process_next_step;
            }
        } else if (step->type == DIRECT_PARITY_IN_DECISION) {
            ++host_step_pos;
            if (step->request != DIRECT_PARITY_DECISION_ACCEPT &&
                step->request != DIRECT_PARITY_DECISION_REJECT) {
                host_failed = 1u;
            } else if (step->phase != 0u) {
                if (host_step_pos < host_scenario->step_count) {
                    goto process_next_step;
                }
            } else if (confirm_action == CONFIRM_TAKEBACK_ACCEPT &&
                       takeback_pending_ply != 0u) {
                return step->request == DIRECT_PARITY_DECISION_ACCEPT
                           ? 'y' : 'n';
            } else if (confirm_action == CONFIRM_RESTORE_ACCEPT) {
                return step->request == DIRECT_PARITY_DECISION_ACCEPT
                           ? 'y' : 'n';
            } else if (confirm_action == CONFIRM_RESET_ACCEPT &&
                       control_pending == 0u) {
                if (step->request == DIRECT_PARITY_DECISION_ACCEPT) {
                    host_control_reset_pending = 1u;
                    host_started_seen = 0u;
                    return 'y';
                }
                return 'n';
            } else if (confirm_action != CONFIRM_RESET_ACCEPT ||
                       control_pending != CONTROL_PENDING_DRAW_INCOMING) {
                host_failed = 1u;
            } else if (step->request == DIRECT_PARITY_DECISION_ACCEPT) {
                host_control_draw_pending = 1u;
                return 'y';
            } else {
                return 'n';
            }
        }
    }
    return 0u;
}
void spectrum_input_flush_until_release(void) {}
void spectrum_input_suppress_until_release(uint8_t key) { (void)key; }
static char host_move_lower(char value)
{
    if (value >= 'A' && value <= 'Z') {
        return (char)(value + ('a' - 'A'));
    }
    return value;
}

static uint8_t host_move_square(const char **text, char **move)
{
    char value = host_move_lower(**text);

    if (value < 'a' || value > 'h') {
        return 0u;
    }
    *(*move)++ = value;
    ++*text;
    value = **text;
    if (value < '1' || value > '8') {
        return 0u;
    }
    *(*move)++ = value;
    ++*text;
    return 1u;
}

uint8_t spectrum_input_parse_move(const char *text, char *move)
{
    const char *source = text;
    char *destination = move;
    char promotion;

    /* Host transcription of asm/overlay/input_edit/entry_input_edit.asm's
       input_edit_parse_move_ovl_entry; this symbol is otherwise outside the
       judge because the target implementation is Z80-only. */
    while (*source == ' ') {
        ++source;
    }
    if (!host_move_square(&source, &destination)) {
        return 0u;
    }
    if (*source == '-' || *source == ' ') {
        ++source;
    }
    if (!host_move_square(&source, &destination)) {
        return 0u;
    }
    *destination = '\0';
    promotion = host_move_lower(*source);
    if (promotion == 'q' || promotion == 'r' || promotion == 'b' ||
        promotion == 'n') {
        *destination++ = promotion;
        *destination = '\0';
        ++source;
    }
    while (*source == ' ') {
        ++source;
    }
    return (uint8_t)(*source == '\0');
}

static void check_move_parser_contract(void)
{
    typedef struct HostMoveParserVector {
        const char *input;
        const char *output;
    } HostMoveParserVector;
    static const HostMoveParserVector accepted[] = {
        { "  e2e4", "e2e4" },
        { "a1h8", "a1h8" },
        { "h8a1", "h8a1" },
        { "E2-E4", "e2e4" },
        { "e2-e4", "e2e4" },
        { "e2 e4", "e2e4" },
        { "e2e4", "e2e4" },
        { "e7e8q", "e7e8q" },
        { "a2a1R", "a2a1r" },
        { "b7b8b", "b7b8b" },
        { "g2g1N", "g2g1n" },
        { "e2e4   ", "e2e4" },
        { "e7e8q ", "e7e8q" }
    };
    static const char *const rejected[] = {
        "\te2e4", "/draw", "", "i2e4", "e0e4", "e9e4",
        "e2  e4", "e2 - e4", "e2xe4", "e7e8k", "e7e8 q",
        "e7e8qq", "e2e4!", "e2e4 x"
    };
    struct HostMoveBuffer {
        char move[6];
        uint8_t guard[4];
    } output;
    uint8_t i;

    /* Golden branch map for entry_input_edit.asm's move parser:
       Leading-space loop: "  e2e4" / tab reject.
       File/rank bounds and ASCII fold: limits, i/0/9,
       command/empty rejects, and uppercase vectors.
       Exactly one '-', one space, or no separator; doubled/invalid
       separators reject.
       q/r/b/n immediate promotion and fold; invalid, separated, or
       doubled promotions reject.
       Trailing-space loop and NUL end check: trailing spaces accept;
       other suffixes reject.  Failed parses may leave partial output, so only
       the return value is contractual on rejected vectors. */
    for (i = 0u; i < (uint8_t)(sizeof(accepted) / sizeof(accepted[0])); ++i) {
        memset(&output, 0x5au, sizeof(output));
        if (!spectrum_input_parse_move(accepted[i].input, output.move) ||
            strcmp(output.move, accepted[i].output) != 0 ||
            output.guard[0] != 0x5au || output.guard[1] != 0x5au ||
            output.guard[2] != 0x5au || output.guard[3] != 0x5au) {
            fprintf(stderr, "FAIL: ASM move parser accepted vector %u\n",
                    (unsigned)i);
            exit(1);
        }
    }
    for (i = 0u; i < (uint8_t)(sizeof(rejected) / sizeof(rejected[0])); ++i) {
        memset(&output, 0x5au, sizeof(output));
        if (spectrum_input_parse_move(rejected[i], output.move) ||
            output.guard[0] != 0x5au || output.guard[1] != 0x5au ||
            output.guard[2] != 0x5au || output.guard[3] != 0x5au) {
            fprintf(stderr, "FAIL: ASM move parser rejected vector %u\n",
                    (unsigned)i);
            exit(1);
        }
    }
}

static void check_text_helper_contract(void)
{
    typedef struct HostU16Vector {
        uint16_t value;
        const char *text;
    } HostU16Vector;
    static const HostU16Vector vectors[] = {
        { 0u, "0" }, { 9u, "9" }, { 10u, "10" }, { 99u, "99" },
        { 100u, "100" }, { 999u, "999" }, { 1000u, "1000" },
        { 9999u, "9999" }, { 10000u, "10000" }, { 65535u, "65535" }
    };
    char buffer[49];
    char length_48[49];
    char *end;
    uint8_t i;

    /* Golden contracts for shrink_kernels.asm:472-483 and
       asm/spectrum/text.asm:8-27,31-95: length, exact text, terminating NUL,
       and returned pointer. */
    memset(length_48, 'x', 48u);
    length_48[48] = '\0';
    check(netchesszx_asm_mqtt_strlen8("") == 0u &&
              netchesszx_asm_mqtt_strlen8("x") == 1u &&
              netchesszx_asm_mqtt_strlen8(length_48) == 48u,
          "ASM strlen8 golden vectors");

    memset(buffer, 0x5au, sizeof(buffer));
    end = spectrum_append_text(buffer, "");
    check(end == buffer && buffer[0] == '\0' && buffer[1] == 0x5a,
          "ASM append text empty vector");
    memset(buffer, 0x5au, sizeof(buffer));
    end = spectrum_append_text(buffer, "ABC");
    check(end == buffer + 3 && strcmp(buffer, "ABC") == 0 &&
              buffer[4] == 0x5a,
          "ASM append text nonempty vector");

    for (i = 0u; i < (uint8_t)(sizeof(vectors) / sizeof(vectors[0])); ++i) {
        size_t length = strlen(vectors[i].text);

        memset(buffer, 0x5au, sizeof(buffer));
        end = spectrum_append_u16(buffer, vectors[i].value);
        if (end != buffer + length || strcmp(buffer, vectors[i].text) != 0 ||
            buffer[length + 1u] != 0x5a) {
            fprintf(stderr, "FAIL: ASM append u16 vector %u\n", (unsigned)i);
            exit(1);
        }
    }
}

void netchesszx_input_edit_render_overlay(void) {}
void netchesszx_input_edit_begin_empty_overlay(void)
{
    local_input[0] = '\0';
    local_input_len = 0u;
    local_input_cursor = 0u;
    local_input_mode = 1u;
}
void netchesszx_input_edit_stop_clear_overlay(void)
{
    local_input[0] = '\0';
    local_input_len = 0u;
    local_input_cursor = 0u;
    local_input_mode = 0u;
}
static void check_input_editor_driver(void)
{
    local_input_mode = 0u;
    local_input_len = 3u;
    local_input_cursor = 2u;
    local_input[0] = 'x';
    netchesszx_input_edit_begin_empty_overlay();
    check(local_input_mode == 1u && local_input_len == 0u &&
              local_input_cursor == 0u && local_input[0] == '\0',
          "host input editor begin invariants");
    local_input_len = 2u;
    local_input_cursor = 1u;
    local_input[0] = 'y';
    netchesszx_input_edit_stop_clear_overlay();
    check(local_input_mode == 0u && local_input_len == 0u &&
              local_input_cursor == 0u && local_input[0] == '\0',
          "host input editor stop invariants");
}
void netchesszx_input_edit_key_overlay(uint8_t key) { (void)key; }
void netchesszx_input_edit_history_add_overlay(const char *text) { (void)text; }

void spectrum_gui_status_phase(uint8_t phase) { (void)phase; }
void spectrum_gui_set_status_error(const char *text) { (void)text; }
void spectrum_gui_game_timer_start(void)
{
    if (host_restore_apply_pending) {
        host_observe_restore_apply();
        return;
    }
    if (host_local_reset_pending) {
        host_local_reset_pending = 0u;
        (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL_RESULT,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_RESET,
                              DIRECT_PARITY_RESULT_ACCEPTED, 0);
    } else if (host_control_reset_pending) {
        host_control_reset_pending = 0u;
        (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_RESET,
                              DIRECT_PARITY_RESULT_ACCEPTED, 0);
    }
    if (!host_started_seen) {
        host_started_seen = 1u;
        (void)host_trace_push(DIRECT_PARITY_OBS_STARTED,
                              DIRECT_PARITY_LINK_NONE, 0u, 0u, 0);
    }
}
void spectrum_gui_game_timer_stop(void)
{
    if (host_restore_apply_pending) {
        host_observe_restore_apply();
        return;
    }
    if (host_resign_control_pending) {
        host_resign_control_pending = 0u;
        (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_RESIGN,
                              DIRECT_PARITY_RESULT_ACCEPTED, 0);
    } else if (host_local_draw_pending) {
        host_local_draw_pending = 0u;
        host_local_reset_pending = 1u;
        (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL_RESULT,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_DRAW,
                              DIRECT_PARITY_RESULT_ACCEPTED, 0);
    } else if (host_control_draw_pending) {
        host_control_draw_pending = 0u;
        host_control_reset_pending = 1u;
        (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_DRAW,
                              DIRECT_PARITY_RESULT_ACCEPTED, 0);
    }
    host_started_seen = 0u;
}
void spectrum_gui_move_timer_reset(void) {}
void spectrum_gui_set_turn_label(uint8_t mode) { (void)mode; }
void spectrum_gui_set_connected(uint8_t connected)
{
    if (connected == 0u && !host_active_link_down) {
        (void)host_trace_push(DIRECT_PARITY_OBS_CLOSE, host_link_id,
                              0u, 0u, 0);
    }
    if (connected == 0u) {
        if (confirm_action != CONFIRM_NONE || restore_rx_mask != 0u) {
            host_failed = 1u;
        }
        host_restore_control_pending = 0u;
        host_restore_domain_pending = 0u;
        host_active_link_down = 0u;
        host_failed_send_pending = 0u;
        host_local_reset_pending = 0u;
    }
    host_connected_state = connected;
}
void spectrum_gui_notify(const char *text, uint8_t is_error)
{
    (void)is_error;
    if (strcmp(text, "Load cancelled") == 0) {
        host_observe_restore_rejected(0u);
    } else if (strcmp(text, "RESET cancelled: no response") == 0 ||
               strcmp(text, "DRAW cancelled: no response") == 0) {
        (void)host_trace_push(
            DIRECT_PARITY_OBS_CONTROL_RESULT,
            DIRECT_PARITY_LINK_NONE,
            text[0] == 'R' ? DIRECT_PARITY_REQUEST_RESET
                           : DIRECT_PARITY_REQUEST_DRAW,
            DIRECT_PARITY_RESULT_CANCELLED,
            text[0] == 'R' ? "NACK RESET" : "NACK DRAW");
    } else if (strcmp(text, "RESET request expired") == 0 ||
               strcmp(text, "DRAW request expired") == 0) {
        (void)host_trace_push(
            DIRECT_PARITY_OBS_CONTROL_RESULT,
            DIRECT_PARITY_LINK_NONE,
            text[0] == 'R' ? DIRECT_PARITY_REQUEST_RESET
                           : DIRECT_PARITY_REQUEST_DRAW,
            DIRECT_PARITY_RESULT_EXPIRED, 0);
    }
}
void spectrum_gui_notify_persistent(const char *text) { (void)text; }
void spectrum_gui_notify_success(const char *text) { (void)text; }
void spectrum_gui_notify_msg(uint16_t packed)
{
    uint8_t msg_id = SPECTRUM_GUI_MSG_ID(packed);
    uint8_t kind = SPECTRUM_GUI_MSG_KIND(packed);

    if (kind > SPECTRUM_GUI_MSG_KIND_SUCCESS) {
        host_failed = 1u;
    }
    if (!host_ready_seen && netchesszx_session_peer_ready() &&
        (msg_id == SPECTRUM_GUI_MSG_OPPONENT_READY_WAIT ||
         msg_id == SPECTRUM_GUI_MSG_OPPONENT_READY_GO)) {
        host_ready_seen = 1u;
        (void)host_trace_push(DIRECT_PARITY_OBS_READY,
                              DIRECT_PARITY_LINK_NONE, 0u, 0u, 0);
    }
    if (msg_id == SPECTRUM_GUI_MSG_OPPONENT_DRAW_REQUEST) {
        (void)host_trace_push(DIRECT_PARITY_OBS_DECISION,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_DRAW, 0u, 0);
    }
    if (msg_id == SPECTRUM_GUI_MSG_TAKEBACK_REQUEST) {
        (void)host_trace_push(DIRECT_PARITY_OBS_DECISION,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_TAKEBACK, 0u, 0);
    }
    if (msg_id == SPECTRUM_GUI_MSG_RESET_REQUEST) {
        (void)host_trace_push(DIRECT_PARITY_OBS_DECISION,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_RESET, 0u, 0);
    }
    if (msg_id == SPECTRUM_GUI_MSG_TAKEBACK_DONE &&
        host_local_takeback_pending) {
        host_local_takeback_pending = 0u;
        host_takeback_result_seen = 1u;
        (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL_RESULT,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_TAKEBACK,
                              DIRECT_PARITY_RESULT_ACCEPTED, 0);
    }
    if (msg_id == SPECTRUM_GUI_MSG_RESTORE_REQUEST) {
        (void)host_trace_push(DIRECT_PARITY_OBS_DECISION,
                              DIRECT_PARITY_LINK_NONE,
                              DIRECT_PARITY_REQUEST_RESTORE, 0u, 0);
    }
    if ((msg_id == SPECTRUM_GUI_MSG_LOAD_DECLINED ||
         msg_id == SPECTRUM_GUI_MSG_LOAD_FAIL) &&
        host_restore_control_pending) {
        host_observe_restore_rejected(
            (uint8_t)(msg_id == SPECTRUM_GUI_MSG_LOAD_FAIL));
    }
}
void spectrum_gui_tick(void) {}
void spectrum_gui_set_board_view(uint8_t local_black)
{
    host_board_flipped = local_black;
}
uint8_t spectrum_gui_is_board_flipped(void) { return host_board_flipped; }
void spectrum_gui_toggle_board_view(void) { host_board_flipped ^= 1u; }
void spectrum_gui_set_board_snapshot(const char *cells)
{
    (void)cells;
    if (!host_restore_control_pending) {
        return;
    }
    if (host_restore_apply_pending) {
        host_failed = 1u;
        return;
    }
#ifdef NETCHESSZX_NEXT_BANKING
    host_next_sprites_reset_seen = 0u;
#endif
    host_restore_marker_seen = 0u;
    host_restore_apply_pending = 1u;
}
void spectrum_gui_set_board_pieces_visible(uint8_t visible)
{
    host_pieces_visible = visible;
}
void spectrum_gui_hide_board_pieces(void) { host_pieces_visible = 0u; }
void spectrum_gui_draw_board(void) {}
void spectrum_gui_redraw_board_view(void) {}
void spectrum_gui_restore_board_area(void) {}
void spectrum_gui_animate_board_pieces(void) { host_pieces_visible = 1u; }
void spectrum_gui_draw_status(void) {}
void spectrum_gui_restore_side_panels(void) { host_side_panels_visible = 1u; }
uint8_t spectrum_gui_side_panels_visible(void)
{
    return host_side_panels_visible;
}
void spectrum_gui_redraw_board_squares(void)
{
#ifdef NETCHESSZX_NEXT_BANKING
    if (host_restore_apply_pending && !host_next_sprites_reset_seen) {
        host_failed = 1u;
    }
#endif
}
void spectrum_render_about_off(void) {}
#ifdef NETCHESSZX_NEXT_BANKING
void spectrum_next_sprites_hide_all(void)
{
    host_next_sprites_reset_seen = 1u;
}
#endif
void spectrum_gui_reset_logs(void) {}
void spectrum_gui_reset_moves(void) {}
void spectrum_gui_add_move(const char *ply, const char *move)
{
    if (host_restore_apply_pending) {
        const char *expected = (game_ply & 1u) != 0u ? "1" : "2";

        ++host_restore_marker_seen;
        if (move != 0 || strcmp(ply, expected) != 0) {
            host_failed = 1u;
        }
    }
}
void spectrum_gui_remove_last_move(uint16_t ply)
{
    if (ply == 0u || game_ply != ply - 1u) {
        host_failed = 1u;
        return;
    }
    (void)host_trace_push(DIRECT_PARITY_OBS_GAME,
                          DIRECT_PARITY_LINK_NONE,
                          DIRECT_PARITY_GAME_TAKEBACK, ply, 0);
}
void spectrum_gui_add_chat(char who, const char *text)
{
    if (((uint8_t)who & NETCHESSZX_CHAT_EVENT_SIDE_FLAG) != 0u) {
        char side = (char)((uint8_t)who &
                           (uint8_t)~NETCHESSZX_CHAT_EVENT_SIDE_FLAG);

        if ((side != netchesszx_local_side_char() &&
             side != netchesszx_remote_side_char()) ||
            (strcmp(text, NETCHESS_PROTO_DRAW) != 0 &&
             strcmp(text, NETCHESS_PROTO_RESIGN) != 0 &&
             strcmp(text, NETCHESS_PROTO_TAKEBACK) != 0 &&
             strcmp(text, NETCHESSZX_UI_EVENT_OPPONENT_RESIGN) != 0)) {
            host_failed = 1u;
        }
        return;
    }
    (void)host_trace_push(
        DIRECT_PARITY_OBS_CHAT,
        DIRECT_PARITY_LINK_NONE,
        who == netchesszx_local_side_char() ? DIRECT_PARITY_CHAT_LOCAL
                                           : DIRECT_PARITY_CHAT_REMOTE,
        0u,
        text);
}
void spectrum_gui_prepare_move(const char *move) { (void)move; }
void spectrum_gui_apply_move(const char *move)
{
    uint8_t local = (uint8_t)(pending_local_ply != 0u);

    (void)host_trace_push(DIRECT_PARITY_OBS_GAME,
                          DIRECT_PARITY_LINK_NONE,
                          local ? DIRECT_PARITY_GAME_LOCAL_MOVE
                                : DIRECT_PARITY_GAME_REMOTE_MOVE,
                          game_ply, move);
}
void netchesszx_host_session_observe_move_result(const char *notation)
{
    (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL_RESULT,
                          DIRECT_PARITY_LINK_NONE,
                          DIRECT_PARITY_REQUEST_MOVE,
                          DIRECT_PARITY_RESULT_ACCEPTED, notation);
}
void netchesszx_host_session_observe_move_rejection(const char *reason)
{
    (void)host_trace_push(DIRECT_PARITY_OBS_CONTROL_RESULT,
                          DIRECT_PARITY_LINK_NONE,
                          DIRECT_PARITY_REQUEST_MOVE,
                          DIRECT_PARITY_RESULT_REJECTED, reason);
}
void spectrum_gui_set_input(const char *text) { (void)text; }
void spectrum_gui_set_input_edit(const char *text, uint8_t len, uint8_t cursor)
{
    (void)text;
    (void)len;
    (void)cursor;
}
void spectrum_gui_input_cell(uint8_t pos, char c, uint8_t cursor)
{
    (void)pos;
    (void)c;
    (void)cursor;
}
void spectrum_gui_redraw_square(uint8_t row, uint8_t col)
{
    (void)row;
    (void)col;
}
void spectrum_gui_mark_cursor(uint8_t row, uint8_t col, uint8_t selected)
{
    (void)row;
    (void)col;
    (void)selected;
}
void spectrum_gui_clear_cursor_coords(void) {}
uint8_t spectrum_gui_show_about(void)
{
    host_failed = 1u;
    return 0u;
}
uint8_t spectrum_gui_about_visible(void) { return host_about_visible; }
uint8_t spectrum_gui_show_fileui(void)
{
    host_failed = 1u;
    return 0u;
}
uint8_t spectrum_gui_fileui_visible(void) { return host_fileui_visible; }
uint8_t spectrum_gui_handle_menu_key(uint8_t key)
{
    ++host_menu_key_calls;
    if (key == SPECTRUM_GUI_KEY_MENU) {
        host_menu_visible ^= 1u;
        return 0u;
    }
    return key;
}
void spectrum_gui_hide_menu(void) { host_menu_visible = 0u; }

void spectrum_info_show_setup(void) {}
void spectrum_info_clear_tail(uint8_t row) { (void)row; }
void spectrum_info_line(const char *line) { (void)line; }

void netchesszx_setup_render_edit_line(uint8_t row)
{
    (void)row;
}
uint16_t netchesszx_setup_compute_visible(uint16_t defined_mask)
{
    (void)defined_mask;
    host_failed = 1u;
    return 0u;
}
void netchesszx_setup_paint_attrs(void) {}
void netchesszx_setup_render_rows(uint8_t values,
                                  uint16_t visible_mask,
                                  uint16_t dirty_mask)
{
    (void)values;
    (void)visible_mask;
    (void)dirty_mask;
}
void netchesszx_setup_render_overlay(uint16_t force_dirty,
                                    uint16_t render_mode)
{
    (void)force_dirty;
    (void)render_mode;
}
uint8_t netchesszx_setup_step_overlay(uint8_t key)
{
    (void)key;
    host_failed = 1u;
    return 0u;
}
void netchesszx_board_theme_apply(uint8_t theme) { (void)theme; }
uint8_t netchesszx_piece_set_load(uint8_t set)
{
    (void)set;
    host_failed = 1u;
    return 0u;
}

void spectrum_board_clear_legal_hints(void) {}
void spectrum_board_show_legal_hints(uint8_t from_row, uint8_t from_col)
{
    (void)from_row;
    (void)from_col;
}

uint8_t spectrum_fileui_open_render(void)
{
    host_failed = 1u;
    return 0u;
}
uint8_t spectrum_fileui_rerender(void)
{
    host_failed = 1u;
    return 0u;
}
uint8_t spectrum_fileui_send_key(uint8_t key)
{
    (void)key;
    host_failed = 1u;
    return SPECTRUM_FILEUI_ACT_NONE;
}
const char *spectrum_fileui_selected_name(void)
{
    host_failed = 1u;
    return "";
}
uint8_t spectrum_saveload_run(uint8_t entry, const char *name, const char *buf)
{
    (void)name;
    if (entry != SPECTRUM_OVL_SAVELOAD_LOAD_NCZS ||
        host_restore_file_payload == 0 || buf == 0) {
        host_failed = 1u;
        return 0u;
    }
    memcpy((char *)buf, host_restore_file_payload,
           NETCHESSZX_SAVE_WIRE_B64_SIZE);
    return 1u;
}
void spectrum_frame_wait(void)
{
    ++host_now_ticks;
}

uint8_t direct_spectrum_run(const DirectParityScenario *scenario,
                            DirectParityTrace *trace)
{
    DirectParityObservation *observation;
    uint8_t role;
    uint8_t color;

    if (scenario == 0 || trace == 0 || scenario->step_count == 0u ||
        scenario->steps[0].type != DIRECT_PARITY_IN_LINK_UP) {
        return 0u;
    }
    if (scenario->role == DIRECT_PARITY_ROLE_HOST) {
        role = NETCHESSZX_SESSION_ROLE_HOST;
    } else if (scenario->role == DIRECT_PARITY_ROLE_GUEST) {
        role = NETCHESSZX_SESSION_ROLE_JOIN;
    } else {
        return 0u;
    }
    if (scenario->host_color == DIRECT_PARITY_COLOR_WHITE) {
        color = NETCHESSZX_COLOR_WHITE;
    } else if (scenario->host_color == DIRECT_PARITY_COLOR_BLACK) {
        color = NETCHESSZX_COLOR_BLACK;
    } else {
        return 0u;
    }

    memset(trace, 0, sizeof(*trace));
    host_scenario = scenario;
    host_trace = trace;
    host_step_pos = 1u;
    host_link_id = scenario->steps[0].link_id;
    host_role = scenario->role;
    host_side_initialized = 0u;
    host_observed_color = DIRECT_PARITY_COLOR_UNKNOWN;
    host_ready_seen = 0u;
    host_started_seen = 0u;
    host_failed = 0u;
    host_now_ticks = 0u;
    host_timeout_deadline = 0u;
    host_timeout_active = 0u;
    host_fail_payload = 0;
    host_fail_length = 0u;
    host_failed_send_pending = 0u;
    host_active_link_down = 0u;
    host_control_draw_pending = 0u;
    host_control_reset_pending = 0u;
    host_local_confirm_pending = 0u;
    host_local_draw_pending = 0u;
    host_local_reset_pending = 0u;
    host_local_takeback_pending = 0u;
    host_takeback_result_seen = 0u;
    host_resign_control_pending = 0u;
    host_local_resign_pending = 0u;
    host_connected_state = 0xffu;
    host_pieces_visible = 0xffu;
    host_board_flipped = 0u;
    host_side_panels_visible = 0u;
    host_about_visible = 0u;
    host_fileui_visible = 0u;
    host_restore_file_payload = 0;
    host_restore_apply_pending = 0u;
    host_restore_marker_seen = 0u;
    host_restore_domain_pending = 0u;
    host_restore_result_seen = 0u;
    host_restore_reject_seen = 0u;
    host_restore_control_pending = 0u;
#ifdef NETCHESSZX_NEXT_BANKING
    host_next_sprites_reset_seen = 0u;
#endif
    setup_restart_requested = 0u;
    host_transport_begin_link(host_link_id);
    netchesszx_session_configure(role, NETCHESSZX_TRANSPORT_DIRECT, color);
    while (1) {
        const DirectParityStep *next;

        game_message_loop();
        if (!host_trace_push(DIRECT_PARITY_OBS_ENDED,
                             DIRECT_PARITY_LINK_NONE, 0u, 0u, 0)) {
            return 0u;
        }
        if (host_step_pos >= scenario->step_count) {
            break;
        }
        next = &scenario->steps[host_step_pos];
        if (next->type != DIRECT_PARITY_IN_LINK_UP) {
            host_failed = 1u;
            break;
        }
        ++host_step_pos;
        host_link_id = next->link_id;
        host_side_initialized = 0u;
        host_observed_color = DIRECT_PARITY_COLOR_UNKNOWN;
        host_ready_seen = 0u;
        host_started_seen = 0u;
        host_active_link_down = 0u;
        setup_restart_requested = 0u;
        host_transport_begin_link(host_link_id);
    }
    if (host_failed || host_timeout_active || host_fail_length != 0u ||
        host_failed_send_pending ||
        host_control_draw_pending || host_control_reset_pending ||
        host_local_confirm_pending || host_local_draw_pending ||
        host_local_reset_pending || host_local_takeback_pending ||
        host_takeback_result_seen || host_resign_control_pending ||
        host_restore_file_payload != 0 || host_restore_apply_pending ||
        host_restore_domain_pending || host_restore_result_seen ||
        host_restore_reject_seen ||
        host_restore_control_pending ||
        host_connected_state == 0xffu || host_pieces_visible == 0xffu ||
        host_step_pos != scenario->step_count ||
        netchesszx_session_peer_ready() ||
        trace->count >= DIRECT_PARITY_TRACE_CAPACITY) {
        fprintf(stderr,
                "Spectrum runner state: failed=%u timeout=%u fail_len=%u "
                "draw=%u reset=%u confirm=%u local_draw=%u local_reset=%u "
                "step=%u/%u ready=%u trace=%u\n",
                (unsigned)host_failed, (unsigned)host_timeout_active,
                (unsigned)host_fail_length,
                (unsigned)host_control_draw_pending,
                (unsigned)host_control_reset_pending,
                (unsigned)host_local_confirm_pending,
                (unsigned)host_local_draw_pending,
                (unsigned)host_local_reset_pending,
                (unsigned)host_step_pos, (unsigned)scenario->step_count,
                (unsigned)netchesszx_session_peer_ready(),
                (unsigned)trace->count);
        for (observation = trace->observations;
             observation < &trace->observations[trace->count];
             ++observation) {
            fprintf(stderr, "  trace %u: %u/%u/%u/%u/%.*s\n",
                    (unsigned)(observation - trace->observations),
                    (unsigned)observation->type,
                    (unsigned)observation->link_id,
                    (unsigned)observation->code,
                    (unsigned)observation->value,
                    (int)observation->length, observation->payload);
        }
        return 0u;
    }
    return 1u;
}

static void check_trace(const DirectParityScenario *scenario,
                        const DirectParityTrace *trace,
                        const char *runner)
{
    uint8_t i;

    if (trace->count != scenario->expected_count) {
        fprintf(stderr, "FAIL: %s %s observation count %u != %u\n",
                scenario->id, runner, (unsigned)trace->count,
                (unsigned)scenario->expected_count);
        for (i = 0u; i < trace->count; ++i) {
            fprintf(stderr, "  trace %u: %u/%u/%u/%u/%.*s\n",
                    (unsigned)i,
                    (unsigned)trace->observations[i].type,
                    (unsigned)trace->observations[i].link_id,
                    (unsigned)trace->observations[i].code,
                    (unsigned)trace->observations[i].value,
                    (int)trace->observations[i].length,
                    trace->observations[i].payload);
        }
        exit(1);
    }
    for (i = 0u; i < trace->count; ++i) {
        if (trace->observations[i].type != scenario->expected[i].type ||
            trace->observations[i].link_id != scenario->expected[i].link_id ||
            trace->observations[i].code != scenario->expected[i].code ||
            trace->observations[i].length != scenario->expected[i].length ||
            trace->observations[i].value != scenario->expected[i].value ||
            memcmp(trace->observations[i].payload,
                   scenario->expected[i].payload,
                   trace->observations[i].length) != 0) {
            fprintf(stderr,
                    "FAIL: %s %s observation %u got=%u/%u/%u/%u/%.*s "
                    "expected=%u/%u/%u/%u/%.*s\n",
                    scenario->id, runner, (unsigned)i,
                    (unsigned)trace->observations[i].type,
                    (unsigned)trace->observations[i].link_id,
                    (unsigned)trace->observations[i].code,
                    (unsigned)trace->observations[i].value,
                    (int)trace->observations[i].length,
                    trace->observations[i].payload,
                    (unsigned)scenario->expected[i].type,
                    (unsigned)scenario->expected[i].link_id,
                    (unsigned)scenario->expected[i].code,
                    (unsigned)scenario->expected[i].value,
                    (int)scenario->expected[i].length,
                    scenario->expected[i].payload);
            exit(1);
        }
    }
}

static void check_mqtt_peer_loss_blocks_taboption(void)
{
    char payload[] = "";

    host_menu_key_calls = 0u;
    host_menu_visible = 0u;
    game_status_active = 1u;
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_peer_mark_ready();
    check(process_local_key(SPECTRUM_GUI_KEY_MENU),
          "TABOPTION key consumed while peer present");
    check(host_menu_visible, "TABOPTION opens while peer present");
    check(session_presence_handle_event(NETCHESSZX_SESSION_EVENT_MQTT_PEER_OFFLINE,
                                        payload, 0u) == SESSION_DISPATCH_HANDLED,
          "MQTT peer-offline handled");
    check(!netchesszx_session_peer_ready(), "MQTT peer cleared after offline");
    check(!host_menu_visible, "TABOPTION closed on MQTT peer loss");
    check(process_local_key(SPECTRUM_GUI_KEY_MENU),
          "TABOPTION key consumed while peer absent");
    check(host_menu_key_calls == 1u,
          "TABOPTION handler not reached while peer absent");

    setup_restart_requested = 0u;
    netchesszx_mqtt_session_id = 0u;
    check(process_local_key(KEY_CANCEL),
          "BREAK consumed while waiting without peer");
    check(setup_restart_requested,
          "BREAK returns to setup while waiting without peer");

    setup_restart_requested = 0u;
    netchesszx_session_peer_mark_ready();
    check(process_local_key(SPECTRUM_GUI_KEY_MENU),
          "TABOPTION key consumed after new peer");
    check(host_menu_key_calls == 2u && host_menu_visible,
          "TABOPTION available again after new peer");
    spectrum_gui_hide_menu();
    game_over = 1u;
    check(process_local_key(SPECTRUM_GUI_KEY_MENU),
          "TABOPTION key consumed at rematch boundary");
    check(host_menu_key_calls == 3u && host_menu_visible,
          "TABOPTION remains available at rematch boundary with peer");
    spectrum_gui_hide_menu();
    game_ply = 42u;
    host_pieces_visible = 1u;
    check(session_presence_handle_event(NETCHESSZX_SESSION_EVENT_MQTT_PEER_OFFLINE,
                                        payload, 0u) == SESSION_DISPATCH_HANDLED,
          "MQTT peer-offline handled from game over");
    check(!game_over && game_ply == 0u && !host_pieces_visible,
          "MQTT peer loss discards finished board and history");
}

static void check_direct_guest_disconnect_forgets_side(void)
{
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_BLACK);
    netchesszx_host_color_ready = 1u;
    clear_disconnected_session_state();
    check(!netchesszx_host_color_ready,
          "DIRECT guest disconnect forgets learned side");
}

static void check_cursor_reselects_own_piece(void)
{
    uint8_t saved_hints = netchesszx_movement_hints;

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_peer_mark_ready();
    spectrum_board_reset();
    game_status_active = 1u;
    control_pending = 0u;
    local_turn = 1u;
    pending_local_ply = 0u;
    netchesszx_movement_hints = 0u;
    selected_row = 7u;
    selected_col = 1u;
    cursor_row = 7u;
    cursor_col = 6u;

    check(cursor_select_or_move('\r'), "own-piece reselection consumed");
    check(selected_row == cursor_row && selected_col == cursor_col,
          "own-piece reselection changes move origin");

    game_status_active = 0u;
    local_turn = 0u;
    netchesszx_movement_hints = saved_hints;
    selected_row = NO_SQUARE;
    selected_col = NO_SQUARE;
}

static void check_local_move_ply_overflow(void)
{
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_peer_mark_ready();
    spectrum_board_reset();
    game_status_active = 1u;
    control_pending = 0u;
    pending_local_clear();
    takeback_clear();
    game_ply = 65535u;
    host_uart_feed_len = 0u;
    host_uart_feed_pos = 0u;
    host_uart_tx_len = 0u;

    check(send_local_move("e2e4") == LOCAL_MOVE_REJECTED &&
              host_uart_tx_len == 0u &&
              pending_local_ply == 0u &&
              game_ply == 65535u,
          "local move beyond ply 65535 rejected before transmission");

    game_status_active = 0u;
    game_ply = 0u;
    netchesszx_session_peer_clear();
}

static void check_chat_editor_during_pending_control(void)
{
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_DIRECT,
                                 NETCHESSZX_COLOR_WHITE);
    netchesszx_session_peer_mark_ready();
    host_menu_visible = 0u;
    confirm_action = CONFIRM_NONE;
    pending_local_ply = 0u;
    local_input_mode = 0u;
    game_over = 0u;
    game_status_active = 1u;
    control_pending = CONTROL_PENDING_DRAW_SENT;

    check(process_local_key(13u), "chat editor opens during pending draw");
    check(local_input_mode, "pending draw does not block chat editor");
    check(process_local_key(SPECTRUM_GUI_KEY_MENU),
          "TABOPTION opens from chat editor");
    check(!local_input_mode && host_menu_visible,
          "TABOPTION closes chat editor before opening");
    spectrum_gui_hide_menu();

    game_over = 1u;
    game_status_active = 0u;
    control_pending = CONTROL_PENDING_RESET;
    last_control_accept = CONTROL_ACCEPT_RESIGN;
    check(process_local_key(13u), "chat editor opens during resign rematch");
    check(local_input_mode && confirm_action == CONFIRM_NONE,
          "resign rematch does not open restart prompt");
    edit_stop_clear();

    control_pending = 0u;
    last_control_accept = CONTROL_ACCEPT_NONE;
    game_over = 0u;
}

int main(int argc, char **argv)
{
    static const DirectParityScenario *const scenarios[] = {
        &direct_parity_host_smoke,
        &direct_parity_guest_smoke,
        &direct_parity_guest_hello_conflict,
        &direct_parity_link_zero,
        &direct_parity_intruder_active,
        &direct_parity_intruder_handshake,
        &direct_parity_intruder_teardown,
        &direct_parity_bye_local_handshake,
        &direct_parity_bye_local_send_fail,
        &direct_parity_bye_local_restore_prompt,
        &direct_parity_bye_remote_active,
        &direct_parity_duplicate_hello,
        &direct_parity_start_host,
        &direct_parity_start_guest,
        &direct_parity_move_local_ack,
        &direct_parity_move_local_stale_results,
        &direct_parity_move_remote_duplicate,
        &direct_parity_move_ply_sync,
        &direct_parity_takeback_local_ack,
        &direct_parity_takeback_remote_accept,
        &direct_parity_takeback_reject_retry,
        &direct_parity_takeback_move_inflight,
        &direct_parity_takeback_latch_next_move,
        &direct_parity_restore_local_active,
        &direct_parity_restore_remote_fresh,
        &direct_parity_restore_cancel_early,
        &direct_parity_restore_cancel_late,
        &direct_parity_restore_remote_rn,
        &direct_parity_restore_reject_retry,
        &direct_parity_restore_crossed_rq,
        &direct_parity_restore_reack_send_fail,
        &direct_parity_intruder_restore_receive,
        &direct_parity_restore_partial_reconnect,
        &direct_parity_draw_rematch_guest,
        &direct_parity_reset_after_reset,
        &direct_parity_reset_crossed_active,
        &direct_parity_move_pending_controls_busy,
        &direct_parity_takeback_pending_controls_busy,
        &direct_parity_draw_crossed,
        &direct_parity_resign_remote_duplicate,
        &direct_parity_resign_crossed,
        &direct_parity_cancel_local_reset,
        &direct_parity_cancel_remote_draw,
        &direct_parity_liveness_ack,
        &direct_parity_liveness_pending_window,
        &direct_parity_liveness_guest_loss,
        &direct_parity_liveness_host_loss,
        &direct_parity_liveness_prompt_loss,
        &direct_parity_ping_send_fail,
        &direct_parity_ack_ping_send_fail,
        &direct_parity_ack_ping_send_timeout,
        &direct_parity_ack_ping_stale_tx_result
    };
    DirectParityTrace reference;
    DirectParityTrace spectrum;
    uint8_t i;
    uint8_t ran = 0u;

    check_restore_host_color_guard();
    check_restore_codec_contract();
#ifdef NETCHESSZX_NEXT_BANKING
    check_next_restore_sprite_allocator_contract();
#endif
    check_move_parser_contract();
    check_text_helper_contract();
    check_input_editor_driver();
    check_cursor_reselects_own_piece();
    check_local_move_ply_overflow();
    check_chat_editor_during_pending_control();
    check_mqtt_peer_loss_blocks_taboption();
    check_direct_guest_disconnect_forgets_side();
    for (i = 0u; i < (uint8_t)(sizeof(scenarios) / sizeof(scenarios[0]));
         ++i) {
        const DirectParityScenario *scenario = scenarios[i];

        if (argc == 2 && strcmp(argv[1], scenario->id) != 0) {
            continue;
        }
        ran = 1u;
        if (!direct_reference_run(scenario, &reference)) {
            fprintf(stderr, "FAIL: %s reference scenario ran\n", scenario->id);
            return 1;
        }
        check_trace(scenario, &reference, "reference");
        if (!direct_spectrum_run(scenario, &spectrum)) {
            fprintf(stderr, "FAIL: %s Spectrum scenario ran\n", scenario->id);
            return 1;
        }
        check_trace(scenario, &spectrum, "Spectrum");
    }
    check(ran, "requested scenario exists");
    puts("DIRECT semantic parity scenarios ok");
    return 0;
}
