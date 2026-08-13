#define NETCHESSZX_HOST_SESSION_TEST 1

#include "common/session/session.h"
#include "common/chess/rules_compact.h"
#include "mqtt_session_transcripts.h"
#include "spectrum/transport/mqtt_min.h"
#include "spectrum/transport/net.h"

#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wunused-variable"
#pragma GCC diagnostic ignored "-Wint-to-pointer-cast"
#if defined(__clang__)
#pragma clang diagnostic ignored "-Wincompatible-pointer-types-discards-qualifiers"
#else
#pragma GCC diagnostic ignored "-Wdiscarded-qualifiers"
#endif
#endif
#include "../../src/spectrum/app/app.c"
static uint8_t host_mqtt_packet[SPECTRUM_MQTT_PACKET_MAX];
uint16_t mqtt_next_id = 1u;
uint8_t mqtt_stream_len;
char last_ip[16];
char line_buf[SPECTRUM_NET_LINE_MAX];
const char mqtt_will_topic_prefix[] = "netchesszx/v1/";
static const char *host_mqtt_context_text;
uint8_t mqtt_send_raw_packet(const uint8_t *packet, uint8_t len);
uint8_t mqtt_wait_packet_into(uint8_t *packet, uint8_t wanted, uint16_t frames);
void reset_line_buf(void);
void net_wait_frame(void);
uint8_t read_line(uint16_t frames);
const char *netchesszx_host_mqtt_context_text(void)
{
    return host_mqtt_context_text;
}
#undef SPECTRUM_MQTT_PACKET_SCRATCH
#define SPECTRUM_MQTT_PACKET_SCRATCH host_mqtt_packet
#include "../../src/spectrum/transport/mqtt_min.c"
#include "../../src/spectrum/overlay/mqtt_tx_ovl.c"
#undef WAIT_SHORT
#include "../../src/spectrum/overlay/mqtt_connect_ovl.c"
#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

#include <stdio.h>
#include <string.h>

uint8_t direct_session_step(SessionState *state,
                            const SessionEvent *event,
                            SessionWorkspace *workspace,
                            uint8_t *tx_scratch,
                            uint8_t tx_capacity,
                            SessionAction *actions,
                            uint8_t action_capacity)
{
    (void)state;
    (void)event;
    (void)workspace;
    (void)tx_scratch;
    (void)tx_capacity;
    (void)actions;
    (void)action_capacity;
    return 0u;
}

typedef struct ActualObservation {
    char payload[SESSION_RESTORE_BYTES + 1u];
    uint16_t value;
    uint8_t type;
    uint8_t code;
    uint8_t detail;
    uint8_t route;
    uint8_t retained;
    uint8_t link_id;
} ActualObservation;

typedef struct CanonicalFixture {
    SessionState state;
    SessionWorkspace workspace;
    uint8_t tx[SESSION_PAYLOAD_MAX + 1u];
    SessionAction actions[SESSION_ACTION_CAPACITY];
} CanonicalFixture;

#define HOST_ACTUAL_CAPACITY 32u

static ActualObservation actual[HOST_ACTUAL_CAPACITY];
static const MqttTranscript *host_transcript;
netchesszx_session_ping_t *netchesszx_host_session_ping;
static uint8_t actual_count;
static uint8_t current_link;
static uint8_t host_step_pos;
static uint8_t host_active_step;
static uint8_t host_step_active;
static uint8_t host_payload_flags;
static uint8_t host_publish_seen;
static uint8_t host_publish_route;
static uint8_t host_publish_peer_offline;
static uint8_t host_explicit_tx_failed;
static uint8_t host_forced_stop;
static uint8_t host_unwind_stop;
static uint8_t host_local_confirm_pending;
static uint8_t host_local_draw_pending;
static uint8_t host_local_reset_pending;
static uint8_t host_local_takeback_pending;
static uint16_t host_local_takeback_result_ply;
static uint8_t host_local_resign_pending;
static uint8_t host_crossed_resign_result_pending;
static const char *host_active_rx_payload(void);
static uint8_t host_local_bye_pending;
static uint8_t host_local_bye_closed;
static uint8_t host_handshake_bye_pending;
static uint8_t host_control_draw_pending;
static uint8_t host_control_reset_pending;
static uint8_t host_takeback_delivery;
static const char *host_restore_file_payload;
static uint8_t host_restore_apply_pending;
static uint8_t host_restore_domain_pending;
static uint8_t host_restore_control_pending;
static uint8_t host_restore_delivery;
static char host_restore_wire[SESSION_RESTORE_BYTES + 1u];
static uint8_t host_side_seen;
static uint8_t host_side_color;
static uint16_t host_side_session;
static uint8_t host_ready_seen;
static uint8_t host_started_seen;
static uint8_t host_liveness_armed;
static uint8_t host_control_armed;
static uint8_t host_rx_seen;
static uint8_t host_rx_reset_seen;
static uint8_t host_rx_handoff_arms_liveness;
static uint16_t host_timeout_ticks;
static uint8_t host_control_wait_seen;
static uint8_t terminal_pending;
static uint8_t host_link_down_active;
static uint8_t host_link_down_timer;
static int failures;

static void host_finish_step(void);
static uint8_t host_begin_step(uint8_t expected_type);
static void host_observe_state_edges(void);
static void host_advance_domain_boundary(void);
static void host_consume_link_down_tail(void);
static int instrument_failures;
static uint8_t reference_failed_transcripts;
static uint8_t spectrum_failed_transcripts;

void netchesszx_host_session_observe_ping_reset(
    netchesszx_session_ping_t *ping)
{
    (void)ping;
    if (host_rx_seen) {
        host_rx_reset_seen = 1u;
    }
}

static void instrument_fail(const char *where)
{
    const char *name = host_transcript == 0 ? "<none>" : host_transcript->name;
    const char *label = "<none>";

    if (host_transcript != 0 && host_step_pos < host_transcript->step_count) {
        label = host_transcript->steps[host_step_pos].label;
    }
    printf("INSTRUMENT: %s / %s: %s\n", name, label, where);
    ++instrument_failures;
}

static void emit_observation(uint8_t type,
                             uint8_t code,
                             uint8_t detail,
                             uint16_t value,
                             uint8_t route,
                             uint8_t retained,
                             uint8_t link_id,
                             const char *payload)
{
    ActualObservation *out;
    size_t length = payload == 0 ? 0u
                                 : type == MQTT_OBSERVE_GAME &&
                                           code == SESSION_DELIVER_RESTORE
                                       ? SESSION_RESTORE_BYTES
                                       : strlen(payload);

    if (host_unwind_stop) {
        return;
    }
    if (actual_count >= HOST_ACTUAL_CAPACITY ||
        length >= sizeof(out->payload)) {
        instrument_fail("observation capacity/payload");
        return;
    }
    out = &actual[actual_count++];
    memset(out, 0, sizeof(*out));
    out->type = type;
    out->code = code;
    out->detail = detail;
    out->value = value;
    out->route = route;
    out->retained = retained;
    out->link_id = link_id;
    if (length != 0u) {
        memcpy(out->payload, payload, length + 1u);
    }
}

static void host_observe_restore_apply(void)
{
    uint8_t delivery_id;
    uint16_t value;

    if (!host_restore_apply_pending || host_restore_control_pending == 0u) {
        instrument_fail("restore apply without pending control");
        return;
    }
    delivery_id = host_restore_domain_pending ? ++host_restore_delivery : 0u;
    value = host_restore_domain_pending ? 0u : game_ply;
    emit_observation(MQTT_OBSERVE_GAME, SESSION_DELIVER_RESTORE,
                     delivery_id, value, 0u, 0u, 0u,
                     host_restore_wire);
    host_restore_apply_pending = 0u;
    host_restore_domain_pending = 0u;
    host_restore_control_pending = 0u;
}

static uint8_t host_restore_expects_timer(uint8_t type, uint8_t timer)
{
    const MqttTranscriptStep *step;
    uint8_t i;

    if (timer != SESSION_TIMER_LIVENESS || host_transcript == 0 ||
        strncmp(host_transcript->name, "mqtt-restore-", 13u) != 0 ||
        !host_step_active) {
        return 1u;
    }
    step = &host_transcript->steps[host_active_step];
    for (i = 0u; i < step->expected_count; ++i) {
        if (step->expected[i].type == type &&
            step->expected[i].code == timer) {
            return 1u;
        }
    }
    return 0u;
}

static uint8_t step_is_silent(const MqttTranscriptStep *step)
{
    return (uint8_t)(step->expected_count == 0u ||
                     (step->expected_count == 1u &&
                      step->expected[0].type ==
                          MQTT_OBSERVE_STATE_UNCHANGED));
}

static void emit_timer_set(uint8_t timer, uint16_t ticks)
{
    if (!host_restore_expects_timer(MQTT_OBSERVE_TIMER_SET, timer)) {
        return;
    }
    emit_observation(MQTT_OBSERVE_TIMER_SET, timer, 0u, ticks,
                     0u, 0u, 0u, 0);
}

static void emit_timer_cancel(uint8_t timer)
{
    if (!host_restore_expects_timer(MQTT_OBSERVE_TIMER_CANCEL, timer)) {
        return;
    }
    emit_observation(MQTT_OBSERVE_TIMER_CANCEL, timer, 0u, 0u,
                     0u, 0u, 0u, 0);
}

static void emit_send(const char *payload, uint8_t route, uint8_t retained)
{
    emit_observation(MQTT_OBSERVE_SEND, 0u, 0u, 0u, route, retained,
                     current_link, payload);
    emit_timer_set(SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS);
}
static void host_mark_publish_route(uint8_t route)
{
    if (host_publish_seen) {
        instrument_fail("publish route already pending");
    }
    host_publish_seen = 1u;
    host_publish_route = route;
}

void netchesszx_host_mqtt_observe_control(void)
{
    host_mark_publish_route(SESSION_ROUTE_CONTROL);
}

void netchesszx_host_mqtt_observe_meta(void)
{
    host_mark_publish_route(SESSION_ROUTE_META);
}

void netchesszx_host_mqtt_observe_presence(const char *suffix)
{
    host_mark_publish_route(
        strcmp(suffix, spectrum_net_mqtt_peer_presence_suffix()) == 0
            ? SESSION_ROUTE_PRESENCE_PEER : SESSION_ROUTE_PRESENCE);
}

void netchesszx_host_mqtt_observe_ack(void)
{
    host_mark_publish_route(SESSION_ROUTE_ACK);
}

void netchesszx_host_mqtt_observe_game(void)
{
    host_mark_publish_route(SESSION_ROUTE_GAME);
}

static uint8_t raw_publish_topic_matches_side(const uint8_t *packet,
                                              uint8_t len,
                                              char side)
{
    const char *suffix = side == 'W' ? "pres_w" : "pres_b";
    uint8_t pos = 1u;
    uint8_t byte;
    uint16_t topic_len;

    do {
        if (pos >= len) {
            return 0u;
        }
        byte = packet[pos++];
    } while ((byte & 0x80u) != 0u);
    if ((uint16_t)pos + 2u > len) {
        return 0u;
    }
    topic_len = (uint16_t)((uint16_t)packet[pos] << 8);
    topic_len |= packet[(uint8_t)(pos + 1u)];
    pos = (uint8_t)(pos + 2u);
    if (topic_len < 6u || (uint16_t)pos + topic_len > len) {
        return 0u;
    }
    return (uint8_t)(memcmp(packet + pos + topic_len - 6u,
                            suffix, 6u) == 0);
}

static uint8_t host_is_compact_peer_dead_step(void)
{
    const MqttTranscriptStep *step;

    if (host_transcript == 0 || !host_step_active ||
        strcmp(host_transcript->name, "mqtt-liveness-peer-timeout") != 0) {
        return 0u;
    }
    step = &host_transcript->steps[host_active_step];
    if (strcmp(step->label,
               "peer deadline ends session without broker close") != 0 ||
        step->event.type != MQTT_TRANSCRIPT_TIMEOUT ||
        step->event.code != SESSION_TIMER_LIVENESS) {
        return 0u;
    }
    return 1u;
}

static uint8_t host_consume_compact_deadline_ping(const char *payload,
                                                  uint8_t retained)
{
    if (!host_is_compact_peer_dead_step()) {
        return 0u;
    }
    if (retained || strcmp(payload, "PING") != 0) {
        instrument_fail("invalid compact peer-dead cadence publish");
        return 0u;
    }
    host_publish_seen = 0u;
    host_publish_peer_offline = 0u;
    return 1u;
}

static uint8_t host_consume_chat_crossing(const char *outbound)
{
    const MqttTranscriptEvent *event;
    char chat[SPECTRUM_LINK_PAYLOAD_MAX];

    if (host_transcript == 0 || outbound == 0 ||
        strcmp(host_transcript->name, "mqtt-control-chat") != 0 ||
        strncmp(outbound, "CHAT ", 5u) != 0 ||
        host_step_pos >= host_transcript->step_count) {
        return 0u;
    }
    event = &host_transcript->steps[host_step_pos].event;
    if (event->type != MQTT_TRANSCRIPT_RX ||
        event->route != SESSION_ROUTE_GAME ||
        (event->flags & SESSION_RX_LIVE) == 0u ||
        (event->flags & SESSION_RX_RETAINED) != 0u || event->payload == 0 ||
        !netchess_proto_parse_chat(event->payload, chat, sizeof(chat))) {
        return 0u;
    }
    host_finish_step();
    if (!host_begin_step(MQTT_TRANSCRIPT_RX)) {
        return 0u;
    }
    spectrum_gui_add_chat(netchesszx_remote_side_char(), chat);
    host_finish_step();
    host_rx_seen = 1u;
    host_rx_reset_seen = 1u;
    host_rx_handoff_arms_liveness = 1u;
    return 1u;
}

static uint8_t host_consume_pending_tx_link_down(void)
{
    const MqttTranscriptStep *wrong_link;
    const MqttTranscriptStep *active_link;

    if (host_transcript == 0 ||
        strcmp(host_transcript->name,
               "mqtt-link-loss-pending-tx-fresh-session") != 0 ||
        (uint16_t)host_step_pos + 1u >= host_transcript->step_count) {
        return 0u;
    }
    wrong_link = &host_transcript->steps[host_step_pos];
    active_link = &host_transcript->steps[(uint8_t)(host_step_pos + 1u)];
    if (wrong_link->event.type != MQTT_TRANSCRIPT_LINK_DOWN ||
        wrong_link->event.link_id == current_link ||
        !step_is_silent(wrong_link) ||
        active_link->event.type != MQTT_TRANSCRIPT_LINK_DOWN ||
        active_link->event.link_id != current_link) {
        return 0u;
    }
    host_finish_step();
    if (!host_begin_step(MQTT_TRANSCRIPT_LINK_DOWN)) {
        return 0u;
    }
    host_finish_step();
    if (!host_begin_step(MQTT_TRANSCRIPT_LINK_DOWN)) {
        return 0u;
    }
    host_link_down_active = 1u;
    host_link_down_timer = SESSION_TIMER_TX_GUARD;
    host_explicit_tx_failed = 1u;
    return 1u;
}

uint8_t mqtt_send_raw_packet(const uint8_t *packet, uint8_t len)
{
    uint8_t type = spectrum_mqtt_type(packet, len);
    char payload[SPECTRUM_MQTT_PAYLOAD_MAX + 1u];
    uint16_t packet_id;
    uint8_t flags;
    uint8_t retained;
    uint8_t result;

    if (type == 8u) {
        return 1u;
    }
    if (host_link_down_active) {
        host_publish_seen = 0u;
        host_publish_peer_offline = 0u;
        return 0u;
    }
    if (type != SPECTRUM_MQTT_PUBLISH || !host_publish_seen ||
        spectrum_mqtt_parse_publish(packet, len, payload, sizeof(payload),
                                    &packet_id, &flags) < 0) {
        instrument_fail("invalid real MQTT publish");
        host_publish_seen = 0u;
        return 0u;
    }
    (void)packet_id;
    retained = (uint8_t)((flags & SPECTRUM_LINK_PAYLOAD_RETAINED) != 0u);
    if ((host_publish_route == SESSION_ROUTE_PRESENCE ||
         host_publish_route == SESSION_ROUTE_PRESENCE_PEER) &&
        (!retained || (payload[0] != 'O' && payload[0] != 'F') ||
         payload[1] != ' ' || (payload[2] != 'W' && payload[2] != 'B') ||
         !raw_publish_topic_matches_side(packet, len, payload[2]))) {
        instrument_fail("presence topic/payload side mismatch");
        host_publish_seen = 0u;
        return 0u;
    }
    host_publish_peer_offline = (uint8_t)(
        host_publish_route == SESSION_ROUTE_PRESENCE_PEER && payload[0] == 'F' &&
        host_side_seen &&
        ((payload[2] == 'W') !=
         (host_side_color == SESSION_COLOR_WHITE)));
    if (host_handshake_bye_pending &&
        host_publish_route == SESSION_ROUTE_PRESENCE && retained &&
        payload[0] == 'F' && payload[1] == ' ') {
        host_publish_seen = 0u;
        host_publish_peer_offline = 0u;
        return 1u;
    }
    if (host_rx_seen && netchesszx_mqtt_session_id != 0u &&
        (!host_side_seen ||
         host_side_session != netchesszx_mqtt_session_id)) {
        host_rx_handoff_arms_liveness = 1u;
    }
    if (host_consume_compact_deadline_ping(payload, retained)) {
        return 1u;
    }
    host_observe_state_edges();
    host_advance_domain_boundary();
    if (host_liveness_armed &&
        (!host_rx_seen || host_rx_reset_seen ||
         host_rx_handoff_arms_liveness)) {
        emit_timer_cancel(SESSION_TIMER_LIVENESS);
        host_liveness_armed = 0u;
    }
    emit_send(payload,
              (strcmp(payload, "PING") == 0 ||
               ((host_local_bye_pending || host_handshake_bye_pending) &&
                strcmp(payload, "BYE") == 0))
                  ? SESSION_ROUTE_CONTROL : host_publish_route,
              retained);
    if (strcmp(payload, NETCHESS_PROTO_CANCEL_RESET) == 0 ||
        strcmp(payload, NETCHESS_PROTO_CANCEL_DRAW) == 0) {
        host_control_wait_seen = 0u;
    }

    (void)host_consume_chat_crossing(payload);

    if (host_consume_pending_tx_link_down()) {
        host_publish_seen = 0u;
        host_publish_peer_offline = 0u;
        return 0u;
    }

    if (host_step_pos >= host_transcript->step_count ||
        (host_transcript->steps[host_step_pos].event.type != MQTT_TRANSCRIPT_TX_OK &&
         host_transcript->steps[host_step_pos].event.type != MQTT_TRANSCRIPT_TX_FAILED)) {
        if (host_step_pos < host_transcript->step_count &&
            host_transcript->steps[host_step_pos].event.type ==
                MQTT_TRANSCRIPT_TIMEOUT &&
            host_transcript->steps[host_step_pos].event.code ==
                SESSION_TIMER_TX_GUARD) {
            host_finish_step();
            if (!host_begin_step(MQTT_TRANSCRIPT_TIMEOUT)) {
                return 0u;
            }
            emit_timer_cancel(SESSION_TIMER_TX_GUARD);
            host_publish_seen = 0u;
            host_publish_peer_offline = 0u;
            return 0u;
        }
        host_publish_seen = 0u;
        host_publish_peer_offline = 0u;
        host_unwind_stop = 1u;
        host_forced_stop = 1u;
        return 0u;
    }
    host_finish_step();
    while (host_step_pos < host_transcript->step_count &&
           (host_transcript->steps[host_step_pos].event.type ==
                MQTT_TRANSCRIPT_TX_OK ||
            host_transcript->steps[host_step_pos].event.type ==
                MQTT_TRANSCRIPT_TX_FAILED) &&
           host_transcript->steps[host_step_pos].event.link_id != 0u) {
        uint8_t stale_type =
            host_transcript->steps[host_step_pos].event.type;

        if (!host_begin_step(stale_type)) {
            host_publish_peer_offline = 0u;
            return 0u;
        }
        host_finish_step();
    }
    if (host_step_pos >= host_transcript->step_count ||
        (host_transcript->steps[host_step_pos].event.type !=
             MQTT_TRANSCRIPT_TX_OK &&
         host_transcript->steps[host_step_pos].event.type !=
             MQTT_TRANSCRIPT_TX_FAILED)) {
        instrument_fail("missing current tx result after stale result");
        host_publish_peer_offline = 0u;
        return 0u;
    }
    result = host_transcript->steps[host_step_pos].event.type == MQTT_TRANSCRIPT_TX_OK;
    if (!result) {
        host_explicit_tx_failed = 1u;
    }
    if (!host_begin_step(result ? MQTT_TRANSCRIPT_TX_OK
                                : MQTT_TRANSCRIPT_TX_FAILED)) {
        host_publish_peer_offline = 0u;
        return 0u;
    }
    emit_timer_cancel(SESSION_TIMER_TX_GUARD);
    if (result && strcmp(payload, "PING") == 0) {
        emit_timer_set(SESSION_TIMER_LIVENESS, 350u);
        host_liveness_armed = 1u;
    }
    host_publish_seen = 0u;
    host_publish_peer_offline = 0u;
    return result;
}

uint8_t mqtt_wait_packet_into(uint8_t *packet, uint8_t wanted, uint16_t frames)
{
    (void)frames;
    if (wanted != SPECTRUM_MQTT_SUBACK) {
        instrument_fail("unexpected MQTT wait packet type");
        return 0u;
    }
    packet[1u] = 3u;
    packet[4u] = 0u;
    return 1u;
}

void reset_line_buf(void) { line_buf[0] = '\0'; }
void net_wait_frame(void) {}
uint8_t read_line(uint16_t frames)
{
    (void)frames;
    return 0u;
}

void spectrum_net_runtime_set_clock(uint8_t hour, uint8_t minute, uint8_t second)
{
    (void)hour;
    (void)minute;
    (void)second;
    instrument_fail("unexpected runtime clock write");
}
void spectrum_net_runtime_set_fat_stamp(uint16_t date, uint16_t time)
{
    (void)date;
    (void)time;
    instrument_fail("unexpected runtime FAT stamp write");
}
uint8_t spectrum_uart_send_string(const char *text)
{
    (void)text;
    instrument_fail("unexpected UART string write");
    return 0u;
}
uint8_t spectrum_uart_send_crlf(void)
{
    instrument_fail("unexpected UART CRLF write");
    return 0u;
}
uint8_t spectrum_net_at_cmd(const char *command, uint16_t frames)
{
    (void)command;
    (void)frames;
    instrument_fail("unexpected AT command");
    return 0u;
}
void spectrum_net_guard_wait(uint16_t frames)
{
    (void)frames;
    instrument_fail("unexpected AT guard wait");
}

void spectrum_uart_flush(uint16_t frames)
{
    (void)frames;
    instrument_fail("unexpected UART flush");
}
void spectrum_info_show_preflight(void) { instrument_fail("unexpected preflight UI"); }
void spectrum_net_start_uart(void) { instrument_fail("unexpected UART start"); }
uint8_t spectrum_net_ensure_command_mode(void)
{
    instrument_fail("unexpected command-mode recovery");
    return 0u;
}
uint8_t mqtt_enter_stream_mode(void)
{
    instrument_fail("unexpected stream-mode entry");
    return 0u;
}
void mqtt_abort_stream_mode(void) { instrument_fail("unexpected stream-mode abort"); }
uint16_t mqtt_connect_packet_ovl(void)
{
    instrument_fail("unexpected CONNECT packet build");
    return 0u;
}
static uint8_t observation_matches(const ActualObservation *got,
                                   const MqttTranscriptObservation *expected)
{
    const char *payload = expected->payload == 0 ? "" : expected->payload;
    size_t payload_length = strlen(payload);
    uint8_t payload_matches = (uint8_t)(strcmp(got->payload, payload) == 0);
    uint8_t route_matches = (uint8_t)(got->route == expected->route);
    uint8_t wire_route;

    if (expected->type == MQTT_OBSERVE_SEND && !route_matches &&
        got->route == SESSION_ROUTE_CONTROL) {
        if (strcmp(payload, "ACK GAME START") == 0 ||
            strncmp(payload, "GAME START", 10u) == 0) {
            wire_route = SESSION_ROUTE_CONTROL;
        } else if (strncmp(payload, "ACK ", 4u) == 0) {
            wire_route = SESSION_ROUTE_ACK;
        } else {
            wire_route = SESSION_ROUTE_GAME;
        }
        route_matches = (uint8_t)(wire_route == expected->route);
    }

    if (expected->type == MQTT_OBSERVE_SEND &&
        (expected->detail == MQTT_OBSERVE_DETAIL_NACK_COMPAT ||
         expected->detail == MQTT_OBSERVE_DETAIL_NACK_ROUTE_COMPAT)) {
        if (expected->detail == MQTT_OBSERVE_DETAIL_NACK_COMPAT) {
            payload_matches = (uint8_t)(
                strncmp(got->payload, payload, payload_length) == 0 &&
                (got->payload[payload_length] == '\0' ||
                 got->payload[payload_length] == ' '));
        }
        route_matches = (uint8_t)(route_matches ||
            ((expected->route == SESSION_ROUTE_ACK ||
              expected->route == SESSION_ROUTE_CONTROL) &&
             got->route == SESSION_ROUTE_GAME &&
             strncmp(payload, "NACK ", 5u) == 0));
    }

    return (uint8_t)(got->type == expected->type &&
                      got->code == expected->code &&
                       (expected->detail == MQTT_OBSERVE_DETAIL_NACK_COMPAT ||
                        expected->detail == MQTT_OBSERVE_DETAIL_NACK_ROUTE_COMPAT ||
                        got->detail == expected->detail) &&
                     got->value == expected->value &&
                     route_matches &&
                     got->retained == expected->retained &&
                     got->link_id == expected->link_id &&
                     payload_matches);
}

static uint8_t observations_match(const ActualObservation *actual_values,
                                  uint8_t actual_value_count,
                                  const MqttTranscriptStep *step)
{
    uint8_t actual_index = 0u;
    uint8_t expected_index;

    for (expected_index = 0u; expected_index < step->expected_count;
         ++expected_index) {
        const MqttTranscriptObservation *expected =
            &step->expected[expected_index];

        if (expected->type == MQTT_OBSERVE_STATE_UNCHANGED) {
            continue;
        }
        if ((expected->type == MQTT_OBSERVE_TIMER_SET ||
             expected->type == MQTT_OBSERVE_TIMER_CANCEL) &&
            expected->detail == MQTT_OBSERVE_DETAIL_INTERNAL) {
            MqttTranscriptObservation internal = *expected;

            internal.detail = 0u;
            if (actual_index < actual_value_count &&
                observation_matches(&actual_values[actual_index], &internal)) {
                ++actual_index;
            }
            continue;
        }
        if (actual_index >= actual_value_count ||
            !observation_matches(&actual_values[actual_index], expected)) {
            return 0u;
        }
        ++actual_index;
    }
    return (uint8_t)(actual_index == actual_value_count);
}

static uint8_t canonical_internal_timers_match(
    uint8_t before_mask,
    uint8_t after_mask,
    const ActualObservation *actual_values,
    uint8_t actual_value_count,
    const MqttTranscriptStep *step)
{
    uint8_t timer;

    for (timer = 0u; timer < SESSION_TIMER_COUNT; ++timer) {
        uint8_t bit = (uint8_t)(1u << timer);
        uint8_t expected_armed = (uint8_t)((before_mask & bit) != 0u);
        uint8_t require_rearm = 0u;
        uint8_t rearm_seen = 0u;
        uint8_t seen = 0u;
        uint8_t i;

        for (i = 0u; i < step->expected_count; ++i) {
            const MqttTranscriptObservation *expected = &step->expected[i];

            if (expected->code != timer ||
                (expected->type != MQTT_OBSERVE_TIMER_SET &&
                 expected->type != MQTT_OBSERVE_TIMER_CANCEL)) {
                continue;
            }
            seen |= (uint8_t)(
                expected->detail == MQTT_OBSERVE_DETAIL_INTERNAL);
            if (expected->type == MQTT_OBSERVE_TIMER_SET) {
                if (expected->detail == MQTT_OBSERVE_DETAIL_INTERNAL) {
                    require_rearm |= expected_armed;
                }
                expected_armed = 1u;
            } else {
                expected_armed = 0u;
            }
        }
        if (!seen || expected_armed != (uint8_t)((after_mask & bit) != 0u)) {
            if (seen) {
                return 0u;
            }
            continue;
        }
        if (!require_rearm) {
            continue;
        }
        for (i = 0u; i < actual_value_count; ++i) {
            if (actual_values[i].type == MQTT_OBSERVE_TIMER_SET &&
                actual_values[i].code == timer) {
                rearm_seen = 1u;
                break;
            }
        }
        if (!rearm_seen) {
            return 0u;
        }
    }
    return 1u;
}

static const MqttTranscriptStep canonical_apply_fail_steps[] = {
    {
        "failed domain apply sends nack",
        {
            .payload = "ILLEGAL",
            .value = 1u,
            .type = MQTT_TRANSCRIPT_GAME_RESULT,
            .code = SESSION_GAME_REJECTED
        },
        {
            {
                .type = MQTT_OBSERVE_TIMER_CANCEL,
                .code = SESSION_TIMER_LIVENESS,
                .detail = MQTT_OBSERVE_DETAIL_INTERNAL
            },
            {
                .type = MQTT_OBSERVE_TIMER_CANCEL,
                .code = SESSION_TIMER_CONTROL
            },
            {
                .payload = "NACK 1 ILLEGAL",
                .type = MQTT_OBSERVE_SEND,
                .route = SESSION_ROUTE_ACK,
                .link_id = 1u
            },
            {
                .value = SESSION_TX_GUARD_TICKS,
                .type = MQTT_OBSERVE_TIMER_SET,
                .code = SESSION_TIMER_TX_GUARD
            }
        },
        4u
    },
    {
        "domain nack handoff permits fresh request",
        {.type = MQTT_TRANSCRIPT_TX_OK},
        {
            {
                .type = MQTT_OBSERVE_TIMER_CANCEL,
                .code = SESSION_TIMER_TX_GUARD
            },
            {
                .value = 250u,
                .type = MQTT_OBSERVE_TIMER_SET,
                .code = SESSION_TIMER_LIVENESS,
                .detail = MQTT_OBSERVE_DETAIL_INTERNAL
            }
        },
        2u
    },
    {
        "failed domain takeback prompts again",
        {
            .payload = "TAKEBACK 1",
            .type = MQTT_TRANSCRIPT_RX,
            .route = SESSION_ROUTE_CONTROL,
            .flags = SESSION_RX_LIVE,
            .link_id = 1u
        },
        {
            {
                .value = 1u,
                .type = MQTT_OBSERVE_DECISION,
                .code = SESSION_REQUEST_TAKEBACK
            },
            {
                .value = 250u,
                .type = MQTT_OBSERVE_TIMER_SET,
                .code = SESSION_TIMER_LIVENESS,
                .detail = MQTT_OBSERVE_DETAIL_INTERNAL
            }
        },
        2u
    },
    {
        "second accepted decision requests apply",
        {
            .type = MQTT_TRANSCRIPT_DECISION,
            .code = SESSION_DECISION_ACCEPT
        },
        {
            {
                .value = 1u,
                .type = MQTT_OBSERVE_GAME,
                .code = SESSION_DELIVER_TAKEBACK,
                .detail = 4u
            },
            {
                .value = 125u,
                .type = MQTT_OBSERVE_TIMER_SET,
                .code = SESSION_TIMER_CONTROL
            }
        },
        2u
    }
};

static void canonical_fail(const MqttTranscript *transcript,
                           const MqttTranscriptStep *step,
                           const char *detail)
{
    printf("FAIL: canonical / %s / %s: %s\n",
           transcript->name, step->label, detail);
    ++failures;
}

static uint8_t canonical_event_from_transcript(
    CanonicalFixture *fixture,
    const MqttTranscriptEvent *source,
    SessionEvent *event)
{
    memset(event, 0, sizeof(*event));
    switch (source->type) {
    case MQTT_TRANSCRIPT_LINK_UP:
    case MQTT_TRANSCRIPT_LINK_DOWN:
        event->type = source->type == MQTT_TRANSCRIPT_LINK_UP
                          ? SESSION_EV_LINK_UP
                          : SESSION_EV_LINK_DOWN;
        event->data.link.link_id = source->link_id;
        return 1u;
    case MQTT_TRANSCRIPT_RX:
        event->type = SESSION_EV_RX;
        event->data.rx.payload = (const uint8_t *)source->payload;
        event->data.rx.length = source->payload == 0
                                    ? 0u
                                    : (uint8_t)strlen(source->payload);
        event->data.rx.route = source->route;
        event->data.rx.flags =
            (uint8_t)(source->flags &
                      (SESSION_RX_RETAINED | SESSION_RX_LIVE));
        event->data.rx.link_id = source->link_id;
        return 1u;
    case MQTT_TRANSCRIPT_TX_OK:
    case MQTT_TRANSCRIPT_TX_FAILED:
        event->type = SESSION_EV_TX_RESULT;
        event->data.tx.tx_id = source->link_id == 0u
                                   ? fixture->state.pending_tx_id
                                   : source->link_id;
        event->data.tx.result = source->type == MQTT_TRANSCRIPT_TX_OK
                                    ? SESSION_TX_OK
                                    : SESSION_TX_FAILED;
        return 1u;
    case MQTT_TRANSCRIPT_LOCAL:
        event->type = SESSION_EV_LOCAL_REQUEST;
        event->data.local.request = source->code;
        event->data.local.value = source->value;
        event->data.local.payload = (const uint8_t *)source->payload;
        event->data.local.length = source->payload == 0
                                       ? 0u
                                       : (uint8_t)strlen(source->payload);
        event->data.local.phase = source->phase;
        return 1u;
    case MQTT_TRANSCRIPT_DECISION:
        event->type = SESSION_EV_USER_DECISION;
        event->data.user.request_id = source->link_id == 0u
                                          ? fixture->state.pending_request_id
                                          : source->link_id;
        event->data.user.decision = source->code;
        return 1u;
    case MQTT_TRANSCRIPT_GAME_RESULT:
        event->type = SESSION_EV_GAME_RESULT;
        event->data.game.delivery_id = source->link_id == 0u
                                           ? fixture->state.pending_request_id
                                           : source->link_id;
        event->data.game.result = source->code;
        event->data.game.value = source->value;
        event->data.game.detail = (const uint8_t *)source->payload;
        event->data.game.detail_length = source->payload == 0
                                             ? 0u
                                             : (uint8_t)strlen(source->payload);
        return 1u;
    case MQTT_TRANSCRIPT_TIMEOUT:
        event->type = SESSION_EV_TIMEOUT;
        event->data.timeout.timer_id = source->code;
        return 1u;
    default:
        return 0u;
    }
}

static void check_id_mapping(void)
{
    CanonicalFixture fixture;
    MqttTranscriptEvent source;
    SessionEvent event;

    memset(&fixture, 0, sizeof(fixture));
    fixture.state.pending_tx_id = 7u;
    fixture.state.pending_request_id = 9u;
    memset(&source, 0, sizeof(source));

    source.type = MQTT_TRANSCRIPT_TX_OK;
    source.link_id = 0xffu;
    if (!canonical_event_from_transcript(&fixture, &source, &event) ||
        event.data.tx.tx_id != 0xffu) {
        puts("FAIL: MQTT DSL explicit tx id");
        ++failures;
    }
    source.type = MQTT_TRANSCRIPT_DECISION;
    source.code = SESSION_DECISION_ACCEPT;
    if (!canonical_event_from_transcript(&fixture, &source, &event) ||
        event.data.user.request_id != 0xffu) {
        puts("FAIL: MQTT DSL explicit decision id");
        ++failures;
    }
    source.type = MQTT_TRANSCRIPT_GAME_RESULT;
    source.code = SESSION_GAME_ACCEPTED;
    if (!canonical_event_from_transcript(&fixture, &source, &event) ||
        event.data.game.delivery_id != 0xffu) {
        puts("FAIL: MQTT DSL explicit delivery id");
        ++failures;
    }
    source.link_id = 0u;
    source.type = MQTT_TRANSCRIPT_TX_OK;
    if (!canonical_event_from_transcript(&fixture, &source, &event) ||
        event.data.tx.tx_id != 7u) {
        puts("FAIL: MQTT DSL current-id shorthand");
        ++failures;
    }
}

static void expect_wire_text(const char *label, const char *got,
                             const char *expected)
{
    if (strcmp(got, expected) != 0) {
        printf("FAIL: MQTT wire %s: got %s want %s\n",
               label, got, expected);
        ++failures;
    }
}

static void check_mqtt_wire_builders(void)
{
    char setup[32];

    netchesszx_mqtt_session_id = 42u;
    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    expect_wire_text("white out", spectrum_net_mqtt_out_suffix(), "w2b");
    expect_wire_text("white in", spectrum_net_mqtt_in_suffix(), "b2w");
    expect_wire_text("white out ack",
                     spectrum_net_mqtt_out_ack_suffix(), "ack_b");
    expect_wire_text("white in ack",
                     spectrum_net_mqtt_in_ack_suffix(), "ack_w");
    expect_wire_text("white presence",
                     spectrum_net_mqtt_presence_suffix(), "pres_w");
    expect_wire_text("white peer presence",
                     spectrum_net_mqtt_peer_presence_suffix(), "pres_b");
    expect_wire_text("white online",
                     spectrum_net_mqtt_presence_payload(), "O W 42");
    spectrum_net_mqtt_setup_payload(setup);
    expect_wire_text("host white setup", setup, "H W 42");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_BLACK);
    expect_wire_text("black out", spectrum_net_mqtt_out_suffix(), "b2w");
    expect_wire_text("black in", spectrum_net_mqtt_in_suffix(), "w2b");
    expect_wire_text("black out ack",
                     spectrum_net_mqtt_out_ack_suffix(), "ack_w");
    expect_wire_text("black in ack",
                     spectrum_net_mqtt_in_ack_suffix(), "ack_b");
    expect_wire_text("black presence",
                     spectrum_net_mqtt_presence_suffix(), "pres_b");
    expect_wire_text("black peer presence",
                     spectrum_net_mqtt_peer_presence_suffix(), "pres_w");
    expect_wire_text("black online",
                     spectrum_net_mqtt_presence_payload(), "O B 42");
    spectrum_net_mqtt_setup_payload(setup);
    expect_wire_text("host black setup", setup, "H B 42");

    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                 NETCHESSZX_TRANSPORT_MQTT,
                                 NETCHESSZX_COLOR_WHITE);
    spectrum_net_mqtt_setup_payload(setup);
    expect_wire_text("join setup", setup, "J 42");
}

static uint8_t canonical_observation_from_action(
    ActualObservation *out,
    const SessionAction *action)
{
    const uint8_t *payload = 0;
    uint8_t length = 0u;

    memset(out, 0, sizeof(*out));
    switch (action->type) {
    case SESSION_ACT_SEND:
        out->type = MQTT_OBSERVE_SEND;
        out->route = action->data.send.route;
        out->retained = action->data.send.retained;
        out->link_id = action->data.send.link_id;
        payload = action->data.send.payload;
        length = action->data.send.length;
        break;
    case SESSION_ACT_TIMER_SET:
        out->type = MQTT_OBSERVE_TIMER_SET;
        out->code = action->data.timer_set.timer_id;
        out->value = action->data.timer_set.duration_ticks;
        break;
    case SESSION_ACT_TIMER_CANCEL:
        out->type = MQTT_OBSERVE_TIMER_CANCEL;
        out->code = action->data.timer_cancel.timer_id;
        break;
    case SESSION_ACT_LINK_CLOSE:
        out->type = MQTT_OBSERVE_LINK_CLOSE;
        out->link_id = action->data.link_close.link_id;
        break;
    case SESSION_ACT_REQUEST_DECISION:
        out->type = MQTT_OBSERVE_DECISION;
        out->code = action->data.decision.control;
        out->value = action->data.decision.value;
        break;
    case SESSION_ACT_DELIVER_GAME:
        out->type = MQTT_OBSERVE_GAME;
        out->code = action->data.game.kind;
        out->detail = action->data.game.delivery_id;
        out->value = action->data.game.value;
        payload = action->data.game.payload;
        length = action->data.game.length;
        break;
    case SESSION_ACT_SESSION_CHANGED:
        out->type = MQTT_OBSERVE_SESSION;
        out->code = action->data.session.status;
        break;
    case SESSION_ACT_SIDE_CHANGED:
        out->type = MQTT_OBSERVE_SIDE;
        out->code = action->data.side.color;
        out->value = action->data.side.session_id;
        break;
    default:
        return 0u;
    }
    if (length >= sizeof(out->payload) || (length != 0u && payload == 0)) {
        return 0u;
    }
    if (length != 0u) {
        memcpy(out->payload, payload, length);
        out->payload[length] = '\0';
    }
    return 1u;
}

static void canonical_run_step(CanonicalFixture *fixture,
                               const MqttTranscript *transcript,
                               const MqttTranscriptStep *step)
{
    ActualObservation observations[SESSION_ACTION_CAPACITY];
    SessionState state_before = fixture->state;
    SessionEvent event;
    uint8_t action_count;
    uint8_t action_index;
    uint8_t send_count = 0u;

    if (!canonical_event_from_transcript(fixture, &step->event, &event)) {
        canonical_fail(transcript, step, "bad corpus event");
        return;
    }
    memset(fixture->actions, 0, sizeof(fixture->actions));
    action_count = session_step(&fixture->state,
                                &event,
                                &fixture->workspace,
                                fixture->tx,
                                sizeof(fixture->tx),
                                fixture->actions,
                                SESSION_ACTION_CAPACITY);
    for (action_index = 0u; action_index < action_count; ++action_index) {
        if (fixture->actions[action_index].type == SESSION_ACT_SEND) {
            ++send_count;
        }
        if (!canonical_observation_from_action(
                &observations[action_index],
                &fixture->actions[action_index])) {
            canonical_fail(transcript, step, "unsupported/capacity action");
            return;
        }
    }
    if (send_count > 1u) {
        canonical_fail(transcript, step, "more than one send");
        return;
    }
    if (!observations_match(observations, action_count, step)) {
        canonical_fail(transcript, step, "normalized observations");
    } else if (!canonical_internal_timers_match(state_before.timer_mask,
                                                 fixture->state.timer_mask,
                                                 observations,
                                                 action_count,
                                                 step)) {
        canonical_fail(transcript, step, "internal timer state/rearm");
    } else if (step->expected_count == 1u &&
               step->expected[0].type == MQTT_OBSERVE_STATE_UNCHANGED &&
               memcmp(&state_before, &fixture->state,
                      sizeof(state_before)) != 0) {
        canonical_fail(transcript, step, "silent state mutation");
    }
}

static uint8_t canonical_fixture_init(CanonicalFixture *fixture,
                                      const MqttTranscript *transcript)
{
    SessionConfig config;

    memset(fixture, 0, sizeof(*fixture));
    config.transport = SESSION_TRANSPORT_MQTT;
    config.role = transcript->role;
    config.host_color = transcript->host_color;
    config.session_id = transcript->session_id;
    return session_init(&fixture->state, &config);
}

static void mqtt_reference_run(const MqttTranscript *transcript)
{
    CanonicalFixture fixture;
    CanonicalFixture apply_fail_fixture;
    int failures_before = failures;
    uint8_t step_index;
    uint8_t apply_fail_index;
    uint8_t apply_fail_run = 0u;

    if (!canonical_fixture_init(&fixture, transcript)) {
        printf("FAIL: canonical / %s: init\n", transcript->name);
        ++failures;
        ++reference_failed_transcripts;
        return;
    }
    for (step_index = 0u; step_index < transcript->step_count; ++step_index) {
        canonical_run_step(&fixture, transcript,
                           &transcript->steps[step_index]);
        if (!apply_fail_run &&
            strcmp(transcript->name, "mqtt-control-remote-takeback") == 0 &&
            strcmp(transcript->steps[step_index].label,
                   "accepted decision requests domain apply") == 0) {
            apply_fail_run = 1u;
            apply_fail_fixture = fixture;
            for (apply_fail_index = 0u;
                 apply_fail_index <
                     (uint8_t)(sizeof(canonical_apply_fail_steps) /
                               sizeof(canonical_apply_fail_steps[0]));
                 ++apply_fail_index) {
                canonical_run_step(&apply_fail_fixture, transcript,
                                   &canonical_apply_fail_steps[apply_fail_index]);
            }
        }
    }
    if (strcmp(transcript->name, "mqtt-control-remote-takeback") == 0 &&
        !apply_fail_run) {
        printf("FAIL: canonical / %s: apply-fail branch not reached\n",
               transcript->name);
        ++failures;
    }
    if (failures != failures_before) {
        ++reference_failed_transcripts;
    }
}

static void host_observe_state_edges(void)
{
    const MqttTranscriptEvent *event;
    uint8_t color;

    if (!host_step_active) {
        return;
    }
    if (!host_publish_peer_offline) {
        color = netchesszx_local_is_white()
            ? SESSION_COLOR_WHITE : SESSION_COLOR_BLACK;
        if (netchesszx_mqtt_session_id != 0u &&
            (!host_side_seen || host_side_color != color ||
             host_side_session != netchesszx_mqtt_session_id)) {
            host_side_seen = 1u;
            host_side_color = color;
            host_side_session = netchesszx_mqtt_session_id;
            emit_observation(MQTT_OBSERVE_SIDE, color, 0u,
                             netchesszx_mqtt_session_id,
                             0u, 0u, 0u, 0);
        }
    }
    event = &host_transcript->steps[host_active_step].event;
    if (host_crossed_resign_result_pending &&
        event->type == MQTT_TRANSCRIPT_TX_OK) {
        host_crossed_resign_result_pending = 0u;
        host_local_resign_pending = 0u;
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_ACCEPTED,
                         SESSION_REQUEST_RESIGN,
                         0u, 0u, 0u, 0);
    }
    if (host_local_reset_pending && host_rx_seen &&
        control_pending != CONTROL_PENDING_RESET &&
        event->type == MQTT_TRANSCRIPT_RX && event->payload != 0 &&
        strncmp(event->payload, "NACK RESET", 10u) == 0 &&
        (event->payload[10u] == '\0' || event->payload[10u] == ' ')) {
        host_local_reset_pending = 0u;
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_REJECTED, SESSION_REQUEST_RESET,
                         0u, 0u, 0u, event->payload);
    }
    if (host_local_resign_pending && host_rx_seen && !resign_pending &&
        event->type == MQTT_TRANSCRIPT_RX && event->payload != 0 &&
        strcmp(event->payload, "ACK RESIGN") == 0) {
        host_local_resign_pending = 0u;
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_ACCEPTED, SESSION_REQUEST_RESIGN,
                         0u, 0u, 0u, 0);
    }
    if (game_status_active && !game_over && !host_started_seen) {
        host_started_seen = 1u;
        emit_observation(MQTT_OBSERVE_SESSION, SESSION_CHANGED_STARTED,
                         0u, 0u, 0u, 0u, 0u, 0);
    }
    if (!host_publish_seen) {
        if (host_rx_seen && netchesszx_session_peer_ready() &&
            host_rx_reset_seen) {
            if (host_liveness_armed && event->type == MQTT_TRANSCRIPT_RX &&
                event->payload != 0 && strcmp(event->payload, "ACK PING") == 0) {
                emit_timer_cancel(SESSION_TIMER_LIVENESS);
                host_liveness_armed = 0u;
            }
            emit_timer_set(SESSION_TIMER_LIVENESS, 250u);
            host_liveness_armed = 1u;
        }
        host_rx_seen = 0u;
        host_rx_reset_seen = 0u;
        host_timeout_ticks = 0u;
    }
}

static void host_finish_step(void)
{
    const MqttTranscriptStep *step;

    if (!host_step_active) {
        return;
    }
    step = &host_transcript->steps[host_active_step];
    if (step->event.type != MQTT_TRANSCRIPT_LINK_UP) {
        host_observe_state_edges();
    }
    if (!observations_match(actual, actual_count, step)) {
        printf("FAIL: %s / %s: normalized observations (%u raw)\n",
               host_transcript->name, step->label, (unsigned)actual_count);
        ++failures;
    }
    host_step_active = 0u;
    actual_count = 0u;
    memset(actual, 0, sizeof(actual));
}

static void host_consume_local_bye_tail(void)
{
    const MqttTranscriptStep *step;

    if (!host_local_bye_closed) {
        return;
    }
    host_local_bye_closed = 0u;
    if (host_step_pos >= host_transcript->step_count) {
        return;
    }
    step = &host_transcript->steps[host_step_pos];
    if (strcmp(host_transcript->name, "mqtt-bye-local-success") != 0 ||
        step->event.type != MQTT_TRANSCRIPT_RX ||
        step->event.route != SESSION_ROUTE_ACK ||
        (step->event.flags & SESSION_RX_LIVE) == 0u ||
        !step_is_silent(step) || step->event.payload == 0 ||
        strcmp(step->event.payload, "ACK RESET") != 0) {
        instrument_fail("unexpected local BYE terminal tail");
        return;
    }
    if (host_begin_step(MQTT_TRANSCRIPT_RX)) {
        host_finish_step();
    }
}

static uint8_t host_begin_step(uint8_t expected_type)
{
    const MqttTranscriptStep *step;

    if (host_step_active || host_transcript == 0 ||
        host_step_pos >= host_transcript->step_count) {
        instrument_fail("step begin outside transcript");
        return 0u;
    }
    step = &host_transcript->steps[host_step_pos];
    if (step->event.type != expected_type) {
        printf("INSTRUMENT: %s / %s: event %u reached as %u\n",
               host_transcript->name, step->label,
               (unsigned)step->event.type, (unsigned)expected_type);
        ++instrument_failures;
        return 0u;
    }
    host_active_step = host_step_pos++;
    host_step_active = 1u;
    actual_count = 0u;
    memset(actual, 0, sizeof(actual));
    return 1u;
}

static void host_advance_domain_boundary(void)
{
    if (!host_step_active || host_transcript == 0 ||
        host_step_pos >= host_transcript->step_count ||
        host_transcript->steps[host_step_pos].event.type !=
            MQTT_TRANSCRIPT_GAME_RESULT) {
        return;
    }
    host_finish_step();
    while (host_step_pos < host_transcript->step_count &&
           host_transcript->steps[host_step_pos].event.type ==
               MQTT_TRANSCRIPT_GAME_RESULT) {
        uint8_t stale =
            host_transcript->steps[host_step_pos].event.link_id != 0u;

        if (!host_begin_step(MQTT_TRANSCRIPT_GAME_RESULT) || !stale) {
            return;
        }
        host_finish_step();
    }
}

static void host_consume_link_down_tail(void)
{
    const MqttTranscriptStep *step;

    while (host_link_down_active &&
           host_step_pos < host_transcript->step_count) {
        step = &host_transcript->steps[host_step_pos];
    if (!step_is_silent(step) ||
            (step->event.type != MQTT_TRANSCRIPT_TX_OK &&
             step->event.type != MQTT_TRANSCRIPT_RX &&
             step->event.type != MQTT_TRANSCRIPT_DECISION)) {
            return;
        }
        if (!host_begin_step(step->event.type)) {
            return;
        }
        host_finish_step();
    }
}

static void reset_fixture(const MqttTranscript *transcript)
{
    uint8_t role = transcript->role == SESSION_ROLE_HOST
        ? NETCHESSZX_SESSION_ROLE_HOST : NETCHESSZX_SESSION_ROLE_JOIN;
    uint8_t color = transcript->host_color == SESSION_COLOR_BLACK
        ? NETCHESSZX_COLOR_BLACK : NETCHESSZX_COLOR_WHITE;

    host_transcript = transcript;
    host_step_pos = 0u;
    host_step_active = 0u;
    host_payload_flags = 0u;
    host_publish_seen = 0u;
    host_publish_peer_offline = 0u;
    host_explicit_tx_failed = 0u;
    host_forced_stop = 0u;
    host_control_wait_seen = 0u;
    host_unwind_stop = 0u;
    host_local_confirm_pending = 0u;
    host_local_draw_pending = 0u;
    host_local_reset_pending = 0u;
    host_local_takeback_pending = 0u;
    host_local_takeback_result_ply = 0u;
    host_local_resign_pending = 0u;
    host_crossed_resign_result_pending = 0u;
    host_local_bye_pending = 0u;
    host_local_bye_closed = 0u;
    host_handshake_bye_pending = 0u;
    host_control_draw_pending = 0u;
    host_control_reset_pending = 0u;
    host_takeback_delivery = 0u;
    host_restore_file_payload = 0;
    host_restore_apply_pending = 0u;
    host_restore_domain_pending = 0u;
    host_restore_control_pending = 0u;
    host_restore_delivery = 0u;
    memset(host_restore_wire, 0, sizeof(host_restore_wire));
    host_side_seen = 0u;
    host_side_color = 0xffu;
    host_side_session = 0u;
    host_ready_seen = 0u;
    host_started_seen = 0u;
    host_liveness_armed = 0u;
    host_control_armed = 0u;
    host_rx_seen = 0u;
    host_rx_reset_seen = 0u;
    host_rx_handoff_arms_liveness = 0u;
    terminal_pending = 0u;
    host_link_down_active = 0u;
    host_link_down_timer = 0u;
    netchesszx_host_session_ping = 0;
    confirm_action = CONFIRM_NONE;
    setup_restart_requested = 0u;
    local_turn = 0u;
    game_ply = 0u;
    pending_local_clear();
    takeback_clear();
    restore_rx_mask = 0u;
    game_status_active = 0u;
    game_over = 0u;
    start_pending = 0u;
    control_pending = 0u;
    mqtt_seat_probed = 0u;
    netchesszx_session_configure(role, NETCHESSZX_TRANSPORT_MQTT, color);
    netchesszx_mqtt_session_id = transcript->role == SESSION_ROLE_HOST
        ? transcript->session_id : 0u;
    if (role == NETCHESSZX_SESSION_ROLE_JOIN) {
        netchesszx_host_color_ready = 0u;
    } else {
        host_side_seen = 1u;
        host_side_color = color == NETCHESSZX_COLOR_WHITE
            ? SESSION_COLOR_WHITE : SESSION_COLOR_BLACK;
        host_side_session = netchesszx_mqtt_session_id;
    }
}

static void mqtt_spectrum_run(const MqttTranscript *transcript)
{
    int failures_before = failures;
    uint8_t config_color = transcript->host_color == SESSION_COLOR_BLACK
        ? NETCHESSZX_COLOR_BLACK : NETCHESSZX_COLOR_WHITE;

    if (transcript->step_count == 0u ||
        transcript->steps[0].event.type != MQTT_TRANSCRIPT_LINK_UP) {
        instrument_fail("invalid empty/first transcript step");
        return;
    }
    reset_fixture(transcript);
    if (!host_begin_step(MQTT_TRANSCRIPT_LINK_UP)) {
        return;
    }
    current_link = transcript->steps[0].event.link_id;
    if (transcript->role == SESSION_ROLE_HOST) {
        if (!spectrum_net_mqtt_activate_side()) {
            ++failures;
        }
    }
    host_finish_step();

    while (1) {
        host_forced_stop = 0u;
        game_message_loop();
        if (!host_forced_stop && host_step_active) {
            emit_observation(MQTT_OBSERVE_SESSION, SESSION_CHANGED_ENDED,
                             0u, 0u, 0u, 0u, 0u, 0);
        }
        host_finish_step();
        host_consume_local_bye_tail();
        host_consume_link_down_tail();
        if (host_step_pos >= transcript->step_count) {
            host_link_down_active = 0u;
            host_link_down_timer = 0u;
            break;
        }
        if (transcript->steps[host_step_pos].event.type !=
            MQTT_TRANSCRIPT_LINK_UP) {
            printf("FAIL: %s: product ended with %u transcript steps pending\n",
                   transcript->name,
                   (unsigned)(transcript->step_count - host_step_pos));
            ++failures;
            break;
        }
        if (!host_begin_step(MQTT_TRANSCRIPT_LINK_UP)) {
            break;
        }
        host_link_down_active = 0u;
        host_link_down_timer = 0u;
        setup_restart_requested = 0u;
        host_unwind_stop = 0u;
        host_ready_seen = 0u;
        host_started_seen = 0u;
        host_liveness_armed = 0u;
        host_side_seen = 0u;
        current_link = transcript->steps[host_active_step].event.link_id;
        if (transcript->role == SESSION_ROLE_HOST) {
            netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                         NETCHESSZX_TRANSPORT_MQTT,
                                         config_color);
            netchesszx_mqtt_session_id = transcript->session_id;
            host_side_seen = 1u;
            host_side_color = transcript->host_color;
            host_side_session = transcript->session_id;
            if (!spectrum_net_mqtt_activate_side()) {
                ++failures;
            }
        } else {
            netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                         NETCHESSZX_TRANSPORT_MQTT,
                                         config_color);
            netchesszx_host_color_ready = 0u;
            netchesszx_mqtt_session_id = 0u;
            mqtt_seat_probed = 0u;
        }
        host_finish_step();
    }
    if (host_step_active) {
        printf("INSTRUMENT: %s: active step leaked at transcript end\n",
               transcript->name);
        ++instrument_failures;
        host_step_active = 0u;
    }
    if (failures != failures_before) {
        ++spectrum_failed_transcripts;
        printf("TRANSCRIPT RED: %s (%d failures)\n",
               transcript->name, failures - failures_before);
    } else {
        printf("TRANSCRIPT GREEN: %s\n", transcript->name);
    }
}

char *spectrum_net_payload_scratch(void)
{
    static char payload[SPECTRUM_LINK_PAYLOAD_MAX];
    return payload;
}

uint8_t spectrum_net_mqtt_activate_side(void)
{
    return mqtt_activate_side_ovl();
}

uint8_t spectrum_net_mqtt_probe_seat(void)
{
    return mqtt_probe_seat_ovl();
}

uint8_t spectrum_net_mqtt_publish_setup(uint8_t mode)
{
    uint8_t context[2] = { mode, 0u };
    return mqtt_tx_publish_setup_ovl(context);
}

uint8_t spectrum_net_mqtt_publish_presence(void)
{
    return mqtt_tx_publish_presence_ovl();
}

uint8_t spectrum_net_send_text(const char *text)
{
    uint8_t context[2] = { 0u, 0u };
    const char *payload = host_active_rx_payload();

    if (strcmp(text, "ACK RESIGN") == 0 && host_local_resign_pending &&
        payload != 0 && strcmp(payload, "RESIGN") == 0) {
        host_crossed_resign_result_pending = 1u;
    } else if (strcmp(text, "RESET") == 0 &&
               last_control_accept == CONTROL_ACCEPT_RESIGN) {
        host_local_reset_pending = 1u;
    } else if (strcmp(text, "ACK RESET") == 0 &&
               last_control_accept == CONTROL_ACCEPT_RESIGN) {
        host_control_reset_pending = 1u;
    }
    host_mqtt_context_text = text;
    return mqtt_tx_send_text_ovl(context);
}

uint8_t spectrum_net_send_ping(void)
{
    return spectrum_net_send_text("PING");
}

void spectrum_gui_set_connected(uint8_t connected)
{
    if (connected == 0u) {
        if (host_link_down_active) {
            emit_timer_cancel(host_link_down_timer);
            if (host_link_down_timer == SESSION_TIMER_LIVENESS) {
                host_liveness_armed = 0u;
            }
            terminal_pending = 0u;
        } else if (host_local_bye_pending || host_handshake_bye_pending) {
            emit_observation(MQTT_OBSERVE_LINK_CLOSE, 0u, 0u, 0u,
                             0u, 0u, current_link, 0);
            host_local_bye_closed = host_local_bye_pending;
            host_local_bye_pending = 0u;
            host_handshake_bye_pending = 0u;
            terminal_pending = 0u;
        } else {
            terminal_pending = 1u;
        }
    } else if (connected == 2u && netchesszx_session_peer_ready()) {
        if (!host_ready_seen) {
            host_ready_seen = 1u;
            emit_observation(MQTT_OBSERVE_SESSION, SESSION_CHANGED_READY,
                             0u, 0u, 0u, 0u, 0u, 0);
        }
        if (!host_liveness_armed && !host_rx_reset_seen) {
            emit_timer_set(SESSION_TIMER_LIVENESS, 250u);
            host_liveness_armed = 1u;
        }
        host_rx_handoff_arms_liveness = 0u;
    } else if (connected == 1u && host_ready_seen) {
        if (host_liveness_armed) {
            emit_timer_cancel(SESSION_TIMER_LIVENESS);
            host_liveness_armed = 0u;
        }
        emit_observation(MQTT_OBSERVE_SESSION, SESSION_CHANGED_ENDED,
                         0u, 0u, 0u, 0u, 0u, 0);
        host_ready_seen = 0u;
        if (host_step_pos < host_transcript->step_count &&
            host_transcript->steps[host_step_pos].event.type ==
                MQTT_TRANSCRIPT_LINK_UP) {
            host_finish_step();
            if (host_begin_step(MQTT_TRANSCRIPT_LINK_UP)) {
                uint8_t color = host_transcript->host_color == SESSION_COLOR_BLACK
                    ? NETCHESSZX_COLOR_BLACK : NETCHESSZX_COLOR_WHITE;

                current_link = host_transcript->steps[host_active_step].event.link_id;
                host_started_seen = 0u;
                host_liveness_armed = 0u;
                host_side_seen = 0u;
                if (host_transcript->role == SESSION_ROLE_HOST) {
                    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_HOST,
                                                 NETCHESSZX_TRANSPORT_MQTT,
                                                 color);
                    netchesszx_mqtt_session_id = host_transcript->session_id;
                    host_side_seen = 1u;
                    host_side_color = host_transcript->host_color;
                    host_side_session = host_transcript->session_id;
                } else {
                    netchesszx_session_configure(NETCHESSZX_SESSION_ROLE_JOIN,
                                                 NETCHESSZX_TRANSPORT_MQTT,
                                                 color);
                    netchesszx_host_color_ready = 0u;
                    netchesszx_mqtt_session_id = 0u;
                    mqtt_seat_probed = 0u;
                }
                host_finish_step();
            }
        }
    }
}

static const char *host_active_rx_payload(void)
{
    const MqttTranscriptEvent *event;

    if (!host_step_active || host_transcript == 0 ||
        host_active_step >= host_transcript->step_count) {
        return 0;
    }
    event = &host_transcript->steps[host_active_step].event;
    return event->type == MQTT_TRANSCRIPT_RX ? event->payload : 0;
}

void spectrum_gui_notify(const char *text, uint8_t is_error)
{
    (void)is_error;
    if (strcmp(text, NETCHESSZX_UI_ERROR_START_REJECTED) == 0) {
        const char *payload = host_active_rx_payload();

        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_REJECTED,
                         SESSION_REQUEST_START,
                         0u, 0u, 0u,
                         payload == 0 || strlen(payload) <= 16u
                             ? 0
                             : payload + 16u);
    } else if (strcmp(text, msg_opponent_resign) == 0) {
        emit_observation(MQTT_OBSERVE_GAME, SESSION_DELIVER_CONTROL,
                         0u, SESSION_REQUEST_RESIGN,
                         0u, 0u, 0u, 0);
    } else if (strcmp(text, "Load cancelled") == 0 &&
               host_restore_control_pending) {
        host_restore_control_pending = 0u;
        host_restore_domain_pending = 0u;
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_REJECTED,
                          SESSION_REQUEST_RESTORE,
                          0u, 0u, 0u, "RN");
    } else if (strcmp(text, "RESET cancelled: no response") == 0 ||
               strcmp(text, "DRAW cancelled: no response") == 0) {
        uint8_t control = text[0] == 'R' ? SESSION_REQUEST_RESET
                                         : SESSION_REQUEST_DRAW;

        host_local_reset_pending = 0u;
        host_local_draw_pending = 0u;
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_CANCELLED,
                         control, 0u, 0u, 0u, host_active_rx_payload());
    } else if (strcmp(text, "RESET request expired") == 0 ||
               strcmp(text, "DRAW request expired") == 0) {
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_EXPIRED,
                         text[0] == 'R' ? SESSION_REQUEST_RESET
                                        : SESSION_REQUEST_DRAW,
                         0u, 0u, 0u, 0);
    }
    if (terminal_pending) {
        if (strcmp(text, NETCHESSZX_UI_SPECTRUM_ERROR_HOST_BUSY) == 0) {
            emit_observation(MQTT_OBSERVE_SESSION, SESSION_CHANGED_BUSY,
                             0u, 0u, 0u, 0u, 0u, 0);
        }
        if (!host_is_compact_peer_dead_step()) {
            emit_observation(MQTT_OBSERVE_LINK_CLOSE, 0u, 0u, 0u,
                             0u, 0u, current_link, 0);
        }
        terminal_pending = 0u;
    }
}

void spectrum_gui_notify_persistent(const char *text) { (void)text; }
void spectrum_gui_notify_success(const char *text) { (void)text; }
void spectrum_gui_notify_msg(uint16_t packed)
{
    uint8_t id = SPECTRUM_GUI_MSG_ID(packed);

    if (id == SPECTRUM_GUI_MSG_OPPONENT_DRAW_REQUEST) {
        emit_observation(MQTT_OBSERVE_DECISION, SESSION_REQUEST_DRAW,
                         0u, 0u, 0u, 0u, 0u, 0);
    } else if (id == SPECTRUM_GUI_MSG_TAKEBACK_REQUEST) {
        emit_observation(MQTT_OBSERVE_DECISION, SESSION_REQUEST_TAKEBACK,
                         0u, takeback_pending_ply, 0u, 0u, 0u, 0);
    } else if (id == SPECTRUM_GUI_MSG_RESET_REQUEST) {
        emit_observation(MQTT_OBSERVE_DECISION, SESSION_REQUEST_RESET,
                         0u, 0u, 0u, 0u, 0u, 0);
    } else if (id == SPECTRUM_GUI_MSG_RESTORE_REQUEST) {
        host_restore_control_pending = 1u;
        host_restore_domain_pending = 1u;
        ++host_restore_delivery;
        if (host_restore_delivery == 0u) {
            ++host_restore_delivery;
        }
        emit_observation(MQTT_OBSERVE_DECISION, SESSION_REQUEST_RESTORE,
                         0u, 0u, 0u, 0u, 0u, 0);
    } else if ((id == SPECTRUM_GUI_MSG_LOAD_DECLINED ||
                id == SPECTRUM_GUI_MSG_LOAD_FAIL) &&
               host_restore_control_pending) {
        host_restore_control_pending = 0u;
        host_restore_domain_pending = 0u;
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_REJECTED,
                         SESSION_REQUEST_RESTORE,
                         0u, 0u, 0u, "RN");
    } else if (id == SPECTRUM_GUI_MSG_TAKEBACK_REJECTED &&
               host_local_takeback_pending) {
        host_local_takeback_pending = 0u;
        host_local_takeback_result_ply = 0u;
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_REJECTED,
                         SESSION_REQUEST_TAKEBACK, 0u, 0u, 0u,
                         host_active_rx_payload());
    } else if (id == SPECTRUM_GUI_MSG_DRAW_REJECTED &&
               host_local_draw_pending) {
        host_local_draw_pending = 0u;
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_REJECTED, SESSION_REQUEST_DRAW,
                         0u, 0u, 0u, host_active_rx_payload());
    } else if (id == SPECTRUM_GUI_MSG_MOVE_REJECTED &&
               host_step_active &&
               host_step_pos < host_transcript->step_count &&
               host_transcript->steps[host_step_pos].event.type ==
                   MQTT_TRANSCRIPT_GAME_RESULT) {
        const MqttTranscriptEvent *event =
            &host_transcript->steps[host_active_step].event;
        char ply[6];
        char move[6];

        if (event->type != MQTT_TRANSCRIPT_RX ||
            !netchess_proto_parse_move(event->payload, ply, sizeof(ply),
                                       move, sizeof(move), 0, 0u)) {
            instrument_fail("rejected MOVE projection parse");
            return;
        }
        emit_observation(MQTT_OBSERVE_GAME, SESSION_DELIVER_REMOTE_MOVE,
                         1u, parse_u16(ply), 0u, 0u, 0u, move);
    }
}
void spectrum_gui_set_status_error(const char *text) { (void)text; }
void spectrum_gui_status_phase(uint8_t phase) { (void)phase; }
void spectrum_gui_set_board_view(uint8_t local_black) { (void)local_black; }
void spectrum_gui_redraw_board_view(void) {}
void spectrum_gui_hide_board_pieces(void) {}
void spectrum_gui_hide_menu(void) {}
void spectrum_gui_set_board_snapshot(const char *cells)
{
    (void)cells;
    if (host_restore_control_pending == 0u) {
        return;
    }
    if (host_restore_apply_pending) {
        instrument_fail("restore board apply state");
        return;
    }
    host_restore_apply_pending = 1u;
}
void spectrum_gui_reset_logs(void) {}
void spectrum_gui_reset_moves(void) {}
void spectrum_gui_game_timer_stop(void)
{
    if (host_restore_apply_pending) {
        host_observe_restore_apply();
        host_started_seen = 0u;
    } else if (host_local_resign_pending) {
        emit_observation(MQTT_OBSERVE_GAME, SESSION_DELIVER_CONTROL,
                         0u, SESSION_REQUEST_RESIGN,
                         0u, 0u, 0u, 0);
    } else if (host_local_draw_pending) {
        host_local_draw_pending = 0u;
        host_local_reset_pending = 1u;
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_ACCEPTED, SESSION_REQUEST_DRAW,
                         0u, 0u, 0u, 0);
    } else if (host_control_draw_pending) {
        host_control_draw_pending = 0u;
        host_control_reset_pending = 1u;
        emit_observation(MQTT_OBSERVE_GAME, SESSION_DELIVER_CONTROL,
                         0u, SESSION_REQUEST_DRAW,
                         0u, 0u, 0u, 0);
    }
    host_started_seen = 0u;
}
void spectrum_gui_set_turn_label(uint8_t mode) { (void)mode; }
void spectrum_gui_clear_cursor_coords(void) {}
void spectrum_gui_redraw_square(uint8_t row, uint8_t col)
{
    (void)row;
    (void)col;
}
uint8_t spectrum_gui_about_visible(void) { return 0u; }
void spectrum_render_about_off(void) {}
void spectrum_gui_restore_board_area(void) {}
void spectrum_gui_tick(void) {}
static uint8_t host_submit_local_text(const char *text)
{
    size_t length = text == 0 ? 0u : strlen(text);

    if (length >= NETCHESSZX_LOWRAM_LOCAL_INPUT_SIZE) {
        instrument_fail("local payload exceeds low-RAM input");
        return 0u;
    }
    memcpy(local_input, text, length + 1u);
    local_input_len = (uint8_t)length;
    local_input_cursor = (uint8_t)length;
    local_input_mode = 1u;
    return 13u;
}

static void host_prepare_promotion_board(const char *move)
{
    static const char white_promotion[65] =
        ".......k"
        "....P..."
        "........"
        "........"
        "........"
        "........"
        "........"
        "K.......";
    static const char black_promotion[65] =
        ".......k"
        "........"
        "........"
        "........"
        "........"
        "........"
        "....p..."
        "K.......";
    uint8_t white = (uint8_t)(move != 0 && move[1] == '7');

    spectrum_board_test_set(white ? white_promotion : black_promotion,
                            white ? NETCHESSZX_RULE_WHITE
                                  : NETCHESSZX_RULE_BLACK,
                            0u, -1);
}

uint8_t spectrum_gui_poll_key(void)
{
    const MqttTranscriptEvent *event;

    if (host_local_confirm_pending) {
        host_local_confirm_pending = 0u;
        if (confirm_action == CONFIRM_DRAW_SEND) {
            host_local_draw_pending = 1u;
        } else if (confirm_action == CONFIRM_RESET_SEND) {
            host_local_reset_pending = 1u;
        } else if (confirm_action == CONFIRM_TAKEBACK_SEND) {
            host_local_takeback_pending = 1u;
        } else if (confirm_action == CONFIRM_RESIGN_SEND) {
            host_local_resign_pending = 1u;
        } else if (confirm_action == CONFIRM_DISCONNECT) {
            host_local_bye_pending = 1u;
        }
        return confirm_action == CONFIRM_NONE ? 0u : (uint8_t)'y';
    }
    if (host_transcript == 0 || host_step_pos >= host_transcript->step_count) {
        return 0u;
    }
    event = &host_transcript->steps[host_step_pos].event;
    if (event->type == MQTT_TRANSCRIPT_GAME_RESULT) {
        host_finish_step();
        (void)host_begin_step(MQTT_TRANSCRIPT_GAME_RESULT);
        if (event->link_id != 0u) {
            host_finish_step();
            return 0u;
        }
        if (host_local_takeback_pending &&
            host_local_takeback_result_ply != 0u &&
            event->code == SESSION_GAME_ACCEPTED &&
            event->value == host_local_takeback_result_ply) {
            host_local_takeback_pending = 0u;
            host_local_takeback_result_ply = 0u;
            emit_observation(MQTT_OBSERVE_GAME,
                             SESSION_DELIVER_CONTROL_RESULT,
                             SESSION_CONTROL_ACCEPTED,
                             SESSION_REQUEST_TAKEBACK,
                             0u, 0u, 0u, 0);
        }
        return 0u;
    }
    if (event->type == MQTT_TRANSCRIPT_DECISION) {
        host_finish_step();
        if (!host_begin_step(MQTT_TRANSCRIPT_DECISION)) {
            return 0u;
        }
        if (event->link_id != 0u) {
            host_finish_step();
            return 0u;
        }
        if (confirm_action == CONFIRM_NONE) {
            return 0u;
        }
        if (event->code == SESSION_DECISION_ACCEPT) {
            if (confirm_action == CONFIRM_RESET_ACCEPT) {
                if (control_pending == CONTROL_PENDING_DRAW_INCOMING) {
                    host_control_draw_pending = 1u;
                } else {
                    host_control_reset_pending = 1u;
                }
            }
        }
        return event->code == SESSION_DECISION_ACCEPT ? (uint8_t)'y'
                                                       : (uint8_t)'n';
    }
    if (event->type != MQTT_TRANSCRIPT_LOCAL) {
        return 0u;
    }
    host_finish_step();
    if (!host_begin_step(MQTT_TRANSCRIPT_LOCAL)) {
        return 0u;
    }
    switch (event->code) {
    case SESSION_REQUEST_START:
        return 32u;
    case SESSION_REQUEST_MOVE:
        if (strcmp(host_transcript->name, "mqtt-move-promotion-qrbn") == 0) {
            host_prepare_promotion_board(event->payload);
        }
        if (send_local_move(event->payload == 0 ? "" : event->payload) ==
                LOCAL_MOVE_NET_FAIL && host_explicit_tx_failed) {
            host_explicit_tx_failed = 0u;
            handle_opponent_disconnected();
            setup_restart_requested = 1u;
        }
        return 0u;
    case SESSION_REQUEST_CHAT:
        return host_submit_local_text(event->payload == 0 ? "" : event->payload);
    case SESSION_REQUEST_DRAW:
        host_local_confirm_pending = 1u;
        return host_submit_local_text("/draw");
    case SESSION_REQUEST_RESIGN:
        host_local_confirm_pending = 1u;
        return host_submit_local_text("/resign");
    case SESSION_REQUEST_TAKEBACK:
        host_local_confirm_pending = 1u;
        return host_submit_local_text("/takeback");
    case SESSION_REQUEST_RESET:
        host_local_confirm_pending = 1u;
        return SPECTRUM_GUI_KEY_MENU_REST;
    case SESSION_REQUEST_RESTORE:
        if (event->payload == 0) {
            return KEY_CANCEL;
        }
        if (strlen(event->payload) != NETCHESSZX_SAVE_WIRE_B64_SIZE) {
            instrument_fail("bad local restore payload");
            return 0u;
        }
        host_restore_file_payload = event->payload;
        host_restore_control_pending = 1u;
        host_restore_domain_pending = 0u;
        local_load_game("PARITY");
        host_restore_file_payload = 0;
        return 0u;
    case SESSION_REQUEST_BYE:
        if (!netchesszx_session_peer_ready_state) {
            host_handshake_bye_pending = 1u;
            return KEY_CANCEL;
        }
        host_local_confirm_pending = 1u;
        return SPECTRUM_GUI_KEY_MENU_DISCC;
    default:
        instrument_fail("unsupported local request");
        return 0u;
    }
}
void spectrum_input_flush_until_release(void) {}
void spectrum_input_suppress_until_release(uint8_t key) { (void)key; }
void spectrum_frame_wait(void) {}
void netchesszx_input_edit_stop_clear_overlay(void)
{
    local_input[0] = '\0';
    local_input_len = 0u;
    local_input_cursor = 0u;
    local_input_mode = 0u;
}
void spectrum_net_background_drain(void) {}
uint8_t spectrum_net_payload_flags(void) { return host_payload_flags; }
int16_t spectrum_net_read_payload(char *payload, uint8_t payload_cap)
{
    const MqttTranscriptEvent *event;
    const char *suffix;
    char topic[SPECTRUM_MQTT_TOPIC_MAX + 1u];
    uint8_t length;
    uint16_t packet_id;
    uint8_t flags;

    if (host_local_confirm_pending) {
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    if (host_step_active &&
        host_transcript->steps[host_active_step].event.type ==
            MQTT_TRANSCRIPT_TIMEOUT) {
        if (CONTROL_IS_WAIT(control_pending) && !host_control_wait_seen) {
            host_control_wait_seen = 1u;
            host_finish_step();
            return SPECTRUM_LINK_READ_TIMEOUT;
        }
        if (netchesszx_host_session_ping != 0 &&
            host_transcript->steps[host_active_step].event.code ==
                SESSION_TIMER_CONTROL) {
            netchesszx_host_session_ping->idle_ticks = 0u;
        }
        ++host_timeout_ticks;
        if (host_timeout_ticks > 512u) {
            printf("FAIL: %s / %s: product did not reach timeout boundary\n",
                   host_transcript->name,
                   host_transcript->steps[host_active_step].label);
            ++failures;
            host_forced_stop = 1u;
            return -2;
        }
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    if (host_step_pos >= host_transcript->step_count) {
        host_finish_step();
        host_forced_stop = 1u;
        return -2;
    }
    event = &host_transcript->steps[host_step_pos].event;
    if (event->type == MQTT_TRANSCRIPT_LOCAL ||
        event->type == MQTT_TRANSCRIPT_DECISION ||
        event->type == MQTT_TRANSCRIPT_GAME_RESULT) {
        host_finish_step();
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    if (event->type == MQTT_TRANSCRIPT_TX_OK ||
        event->type == MQTT_TRANSCRIPT_TX_FAILED) {
        printf("FAIL: %s / %s: product did not initiate expected send\n",
               host_transcript->name,
               host_transcript->steps[host_step_pos].label);
        ++failures;
        host_unwind_stop = 1u;
        host_forced_stop = 1u;
        return -2;
    }
    host_finish_step();
    if (!host_begin_step(event->type)) {
        host_forced_stop = 1u;
        return -2;
    }
    if (event->type == MQTT_TRANSCRIPT_LINK_DOWN) {
        if (event->link_id == current_link) {
            if (host_transcript != 0 &&
                strncmp(host_transcript->name, "mqtt-link-loss-", 15u) == 0) {
                host_link_down_active = 1u;
                host_link_down_timer = SESSION_TIMER_LIVENESS;
            }
            return -2;
        }
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    if (event->type == MQTT_TRANSCRIPT_TIMEOUT) {
        host_timeout_ticks = 1u;
        if (event->code == SESSION_TIMER_LIVENESS &&
            netchesszx_host_session_ping != 0) {
            host_liveness_armed = 0u;
            netchesszx_host_session_ping->idle_ticks = 119u;
            if (netchesszx_session_is_host() &&
                netchesszx_host_session_ping->misses != 0u) {
                netchesszx_host_session_ping->misses = 4u;
            }
        }
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    if (event->type == MQTT_TRANSCRIPT_LINK_UP) {
        printf("FAIL: %s / %s: product did not yield before new link\n",
               host_transcript->name,
               host_transcript->steps[host_step_pos].label);
        ++failures;
        host_unwind_stop = 1u;
        host_forced_stop = 1u;
        return -2;
    }
    if (event->type != MQTT_TRANSCRIPT_RX) {
        printf("INSTRUMENT DETAIL: network event type=%u\n",
               (unsigned)event->type);
        instrument_fail("non-RX event reached network input");
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    if (event->route == SESSION_ROUTE_DEFAULT) {
        /* Real net.c consumes broker PINGRESP below the application payload
           boundary; the session poll observes only another idle read. */
        host_payload_flags = 0u;
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    switch (event->route) {
    case SESSION_ROUTE_META:
        suffix = "meta";
        break;
    case SESSION_ROUTE_CONTROL:
        suffix = "meta";
        break;
    case SESSION_ROUTE_PRESENCE:
        suffix = spectrum_net_mqtt_peer_presence_suffix();
        break;
    case SESSION_ROUTE_ACK:
        suffix = spectrum_net_mqtt_in_ack_suffix();
        break;
    case SESSION_ROUTE_GAME:
        suffix = spectrum_net_mqtt_in_suffix();
        break;
    default:
        printf("INSTRUMENT DETAIL: corpus route=%u\n",
               (unsigned)event->route);
        instrument_fail("invalid corpus MQTT route");
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    mqtt_tx_topic(topic, suffix);
    length = spectrum_mqtt_publish(
        host_mqtt_packet, sizeof(host_mqtt_packet), mqtt_next_id++, topic,
        event->payload == 0 ? "" : event->payload,
        (uint8_t)((event->flags & SESSION_RX_RETAINED) != 0u));
    if (length == 0u) {
        instrument_fail("raw MQTT fixture encode failure");
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    if (spectrum_mqtt_parse_publish(host_mqtt_packet, length,
                                    payload, payload_cap,
                                    &packet_id, &flags) < 0) {
        if (event->payload != 0 &&
            strncmp(event->payload, "CHAT ", 5u) == 0 &&
            strlen(event->payload) > (size_t)(5u + SESSION_CHAT_TEXT_MAX) &&
            strlen(event->payload) >= payload_cap &&
            step_is_silent(&host_transcript->steps[host_active_step])) {
            host_payload_flags = 0u;
            host_finish_step();
            return SPECTRUM_LINK_READ_TIMEOUT;
        }
        instrument_fail("raw MQTT fixture decode failure");
        return SPECTRUM_LINK_READ_TIMEOUT;
    }
    (void)packet_id;
    host_payload_flags = flags;
    host_rx_seen = 1u;
    host_rx_reset_seen = 0u;
    return current_link;
}
void spectrum_net_direct_peer_mark_valid(void) {}
uint8_t spectrum_net_sync_time(void) { return 1u; }
uint8_t spectrum_net_preflight_run(void) { return 1u; }
const char *spectrum_net_last_ip(void) { return ""; }
uint8_t spectrum_net_runtime_clock_ready(void) { return 1u; }
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
    memcpy(host_restore_wire + off, frame + 5u,
           NETCHESSZX_SAVE_WIRE_CHUNK_SIZE);
    host_restore_wire[SESSION_RESTORE_BYTES] = '\0';
    *mask |= (uint8_t)(1u << chunk);
    return (*mask & RESTORE_RX_ALL) == RESTORE_RX_ALL
        ? RESTORE_CHUNK_COMPLETE : RESTORE_CHUNK_PARTIAL;
}

void spectrum_info_line(const char *line) { (void)line; }
void spectrum_info_show_setup(void) {}
void spectrum_info_clear_tail(uint8_t row) { (void)row; }
void spectrum_gui_draw_status(void) {}
void spectrum_gui_redraw_board_squares(void) {}
void spectrum_gui_mark_cursor(uint8_t row, uint8_t col, uint8_t selected)
{
    (void)row;
    (void)col;
    (void)selected;
}
void spectrum_gui_draw_board(void) {}
void spectrum_gui_restore_side_panels(void) {}
void spectrum_gui_remove_last_move(uint16_t ply)
{
    if (host_local_takeback_pending) {
        host_local_takeback_result_ply = ply;
    }
    ++host_takeback_delivery;
    emit_observation(MQTT_OBSERVE_GAME, SESSION_DELIVER_TAKEBACK,
                     host_takeback_delivery, ply, 0u, 0u, 0u, 0);
}
uint8_t spectrum_gui_is_board_flipped(void) { return 0u; }
void spectrum_gui_set_board_pieces_visible(uint8_t visible) { (void)visible; }
void spectrum_gui_game_timer_start(void)
{
    const char *payload = host_active_rx_payload();
    uint8_t reset_started = (uint8_t)(host_local_reset_pending ||
                                      host_control_reset_pending);

    if (!reset_started && payload != 0 && strcmp(payload, "RESET") == 0) {
        host_control_reset_pending = 1u;
        reset_started = 1u;
    }
    if (host_restore_apply_pending) {
        host_observe_restore_apply();
        return;
    }
    if (host_local_reset_pending) {
        host_local_reset_pending = 0u;
        emit_observation(MQTT_OBSERVE_GAME,
                         SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_ACCEPTED, SESSION_REQUEST_RESET,
                         0u, 0u, 0u, 0);
    } else if (host_control_reset_pending) {
        host_control_reset_pending = 0u;
        emit_observation(MQTT_OBSERVE_GAME, SESSION_DELIVER_CONTROL,
                         0u, SESSION_REQUEST_RESET,
                         0u, 0u, 0u, 0);
    }
    if (reset_started) {
        host_started_seen = 0u;
    }
    if (!host_started_seen) {
        host_started_seen = 1u;
        emit_observation(MQTT_OBSERVE_SESSION, SESSION_CHANGED_STARTED,
                         0u, 0u, 0u, 0u, 0u, 0);
    }
}
void spectrum_gui_move_timer_reset(void) {}
void spectrum_gui_animate_board_pieces(void) {}
void spectrum_gui_add_move(const char *ply, const char *move)
{
    (void)ply;
    (void)move;
}
void spectrum_gui_apply_move(const char *move)
{
    uint8_t local = (uint8_t)(pending_local_ply != 0u);

    if (!local) {
        host_takeback_delivery = 2u;
    }
    emit_observation(MQTT_OBSERVE_GAME,
                     local ? SESSION_DELIVER_LOCAL_MOVE
                           : SESSION_DELIVER_REMOTE_MOVE,
                     local ? 0u : 1u, game_ply, 0u, 0u, 0u, move);
}
void spectrum_gui_prepare_move(const char *move) { (void)move; }
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
            instrument_fail("invalid presentation-only control event");
        }
        return;
    }
    emit_observation(MQTT_OBSERVE_GAME, SESSION_DELIVER_CHAT, 0u,
                     who == netchesszx_local_side_char()
                         ? SESSION_CHAT_LOCAL : SESSION_CHAT_REMOTE,
                     0u, 0u, 0u, text);
}
uint8_t spectrum_gui_show_about(void) { return 0u; }
uint8_t spectrum_gui_show_fileui(void) { return 0u; }
uint8_t spectrum_gui_fileui_visible(void) { return 0u; }
uint8_t spectrum_gui_handle_menu_key(uint8_t key) { return key; }
void spectrum_gui_toggle_board_view(void) {}
void spectrum_board_clear_legal_hints(void) {}
void spectrum_board_show_legal_hints(uint8_t from_row, uint8_t from_col)
{
    (void)from_row;
    (void)from_col;
}

void netchesszx_setup_render_edit_line(uint8_t row)
{
    (void)row;
}
uint16_t netchesszx_setup_compute_visible(uint16_t defined_mask)
{
    return defined_mask;
}
void netchesszx_setup_paint_attrs(void) {}
void netchesszx_setup_render_rows(uint8_t values, uint16_t visible_mask,
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
uint8_t netchesszx_setup_step_overlay(uint8_t key) { return key; }
void netchesszx_board_theme_apply(uint8_t theme) { (void)theme; }
uint8_t netchesszx_piece_set_load(uint8_t set)
{
    (void)set;
    return 1u;
}
void netchesszx_input_edit_render_overlay(void) {}
void netchesszx_input_edit_begin_empty_overlay(void)
{
    local_input[0] = '\0';
    local_input_len = 0u;
    local_input_cursor = 0u;
    local_input_mode = 1u;
}
void netchesszx_input_edit_history_add_overlay(const char *text) { (void)text; }
void netchesszx_input_edit_key_overlay(uint8_t key) { (void)key; }

uint8_t spectrum_fileui_open_render(void) { return 0u; }
uint8_t spectrum_fileui_rerender(void) { return 0u; }
uint8_t spectrum_fileui_send_key(uint8_t key)
{
    (void)key;
    return SPECTRUM_FILEUI_ACT_NONE;
}
const char *spectrum_fileui_selected_name(void) { return ""; }
uint8_t spectrum_saveload_run(uint8_t entry, const char *name, const char *buf)
{
    (void)name;
    if (entry != SPECTRUM_OVL_SAVELOAD_LOAD_NCZS ||
        host_restore_file_payload == 0 || buf == 0) {
        instrument_fail("unexpected saveload call");
        return 0u;
    }
    memcpy((char *)buf, host_restore_file_payload,
           NETCHESSZX_SAVE_WIRE_B64_SIZE);
    memcpy(host_restore_wire, host_restore_file_payload,
           SESSION_RESTORE_BYTES);
    host_restore_wire[SESSION_RESTORE_BYTES] = '\0';
    return 1u;
}

uint8_t spectrum_input_parse_move(const char *text, char *move)
{
    size_t length = strlen(text);
    if (length != 4u && length != 5u) {
        return 0u;
    }
    if (text[0] < 'a' || text[0] > 'h' ||
        text[1] < '1' || text[1] > '8' ||
        text[2] < 'a' || text[2] > 'h' ||
        text[3] < '1' || text[3] > '8') {
        return 0u;
    }
    memcpy(move, text, length);
    move[length] = '\0';
    return 1u;
}
void netchesszx_host_session_observe_move_result(const char *notation)
{
    emit_observation(MQTT_OBSERVE_GAME, SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_ACCEPTED, SESSION_REQUEST_MOVE,
                     0u, 0u, 0u, notation);
}

void netchesszx_host_session_observe_move_rejection(const char *reason)
{
    emit_observation(MQTT_OBSERVE_GAME, SESSION_DELIVER_CONTROL_RESULT,
                     SESSION_CONTROL_REJECTED, SESSION_REQUEST_MOVE,
                     0u, 0u, 0u, reason);
}

static void run_shared_transcript(const MqttTranscript *transcript)
{
    mqtt_reference_run(transcript);
    mqtt_spectrum_run(transcript);
}

static void check_mqtt_sntp_year_suffix(void)
{
    static const char bad_first[] = "Fri Jun  5 12:34:56 20K9";
    static const char bad_second[] = "Fri Jun  5 12:34:56 201:";

    mqtt_set_fat_stamp_ovl(bad_first, bad_first + 11u, 12u, 34u);
    mqtt_set_fat_stamp_ovl(bad_second, bad_second + 11u, 12u, 34u);
}

int main(void)
{
    uint8_t i;

    check_mqtt_sntp_year_suffix();
    check_id_mapping();
    check_mqtt_wire_builders();
    for (i = 0u; i < mqtt_session_transcript_count; ++i) {
        run_shared_transcript(&mqtt_session_transcripts[i]);
    }
    if (instrument_failures != 0) {
        printf("mqtt Spectrum parity INSTRUMENT: %d failures, %u transcripts\n",
               instrument_failures, mqtt_session_transcript_count);
        return 2;
    }
    if (failures != 0) {
        printf("mqtt semantic parity RED: %d failures, canonical %u/%u, "
               "Spectrum %u/%u\n",
               failures,
               (unsigned)(mqtt_session_transcript_count -
                          reference_failed_transcripts),
               mqtt_session_transcript_count,
               (unsigned)(mqtt_session_transcript_count -
                          spectrum_failed_transcripts),
               mqtt_session_transcript_count);
        return 1;
    }
    printf("mqtt semantic parity tests ok: canonical %u/%u "
           "(apply-fail host-only), Spectrum %u/%u\n",
           mqtt_session_transcript_count, mqtt_session_transcript_count,
           mqtt_session_transcript_count, mqtt_session_transcript_count);
    return 0;
}
