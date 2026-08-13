#include "common/session/session_internal.h"

#include "common/protocol/game_protocol.h"
#include "common/protocol/mqtt_session_protocol.h"

#define MQTT_TX_NONE 0u
#define MQTT_TX_ONLINE 1u
#define MQTT_TX_HOST_RETAINED 2u
#define MQTT_TX_JOIN 3u
#define MQTT_TX_HOST_LIVE 4u
#define MQTT_TX_OFFLINE_END 5u
#define MQTT_TX_ONLINE_REFRESH 6u
#define MQTT_TX_START 7u
#define MQTT_TX_ACK_START 8u
#define MQTT_TX_MOVE 9u
#define MQTT_TX_ACK_MOVE 10u
#define MQTT_TX_NACK_MOVE 11u
#define MQTT_TX_CHAT 12u
#define MQTT_TX_RESET 13u
#define MQTT_TX_DRAW 14u
#define MQTT_TX_RESIGN 15u
#define MQTT_TX_TAKEBACK 16u
#define MQTT_TX_ACK_RESET 17u
#define MQTT_TX_NACK_RESET 18u
#define MQTT_TX_ACK_DRAW 19u
#define MQTT_TX_NACK_DRAW 20u
#define MQTT_TX_ACK_RESIGN 21u
#define MQTT_TX_ACK_RESIGN_CROSSED 22u
#define MQTT_TX_ACK_TAKEBACK 23u
#define MQTT_TX_NACK_TAKEBACK 24u
#define MQTT_TX_TRANSIENT_REPLY 25u
#define MQTT_TX_ACK_DRAW_CROSSED 26u
#define MQTT_TX_ACK_RESET_CROSSED 27u
#define MQTT_TX_PING 28u
#define MQTT_TX_BYE 29u
#define MQTT_TX_PEER_OFFLINE_END 30u
#define MQTT_TX_RQ 31u
#define MQTT_TX_RY 32u
#define MQTT_TX_RN 33u
#define MQTT_TX_RS0 34u
#define MQTT_TX_RS1 35u
#define MQTT_TX_RA 36u
#define MQTT_TX_PEER_OFFLINE_WAIT 37u
#define MQTT_TX_META_CLEAR 38u

#define MQTT_STATE_PROBING 0x01u
#define MQTT_STATE_OWN_ONLINE 0x02u

#define MQTT_SETUP_TICKS 250u
#define MQTT_LIVENESS_TICKS 250u
#define MQTT_PING_WAIT_TICKS 350u
#define MQTT_REPLY_TICKS 125u

#define MQTT_ORIGIN_NONE 0u
#define MQTT_ORIGIN_LOCAL 1u
#define MQTT_ORIGIN_REMOTE 2u

#define MQTT_CANCEL_WAIT 1u
#define MQTT_CANCEL_SENT 2u
#define MQTT_CANCEL_REMOTE 3u

#define MQTT_RESTORE_NONE SESSION_RESTORE_PHASE_NONE
#define MQTT_RESTORE_WAIT_RY 1u
#define MQTT_RESTORE_WAIT_RA 2u
#define MQTT_RESTORE_RECEIVE 3u
#define MQTT_RESTORE_APPLIED SESSION_RESTORE_PHASE_APPLIED
#define MQTT_RESTORE_CHUNK_MASK 3u
#define MQTT_RESTORE_PHASE_SHIFT 2u
#define MQTT_TX_UNHANDLED 0xffu
#define MQTT_RX_UNHANDLED MQTT_TX_UNHANDLED

static const uint8_t mqtt_reason_reject[] = "REJECT";
static const uint8_t mqtt_reason_sync[] = "SYNC";
static const uint8_t mqtt_reply_rn[] = "RN";

static uint8_t mqtt_slice_valid(const uint8_t *payload, uint8_t length)
{
    uint8_t i;

    if (payload == 0 || length > SESSION_PAYLOAD_MAX || payload[length] != 0u) {
        return 0u;
    }
    for (i = 0u; i < length; ++i) {
        if (payload[i] == 0u) {
            return 0u;
        }
    }
    return 1u;
}

static uint8_t mqtt_fixed_slice_valid(const uint8_t *payload, uint8_t length)
{
    uint8_t i;

    if (payload == 0) {
        return 0u;
    }
    for (i = 0u; i < length; ++i) {
        if (payload[i] == 0u) {
            return 0u;
        }
    }
    return 1u;
}

static uint8_t mqtt_text_equal(const uint8_t *payload,
                               uint8_t length,
                               const char *text)
{
    uint8_t i;

    for (i = 0u; i < length; ++i) {
        if (text[i] == '\0' || payload[i] != (uint8_t)text[i]) {
            return 0u;
        }
    }
    return (uint8_t)(text[length] == '\0');
}

static uint8_t mqtt_text_prefix(const uint8_t *payload,
                                uint8_t length,
                                const char *prefix)
{
    uint8_t i = 0u;

    while (prefix[i] != '\0') {
        if (i >= length || payload[i] != (uint8_t)prefix[i]) {
            return 0u;
        }
        ++i;
    }
    return 1u;
}

static uint8_t mqtt_text_length(const char *text)
{
    uint8_t length = 0u;

    while (length < SESSION_PAYLOAD_MAX && text[length] != '\0') {
        ++length;
    }
    return length;
}

static char *mqtt_u16_text(char *out, uint16_t value)
{
    static const uint16_t places[5] = {10000u, 1000u, 100u, 10u, 1u};
    uint16_t place;
    uint8_t digit;
    uint8_t i;
    uint8_t started = 0u;

    for (i = 0u; i < 5u; ++i) {
        place = places[i];
        digit = 0u;
        while (value >= place) {
            value = (uint16_t)(value - place);
            ++digit;
        }
        if (digit != 0u || started != 0u || place == 1u) {
            *out++ = (char)('0' + digit);
            started = 1u;
        }
    }
    *out = '\0';
    return out;
}

static uint16_t mqtt_parse_u16(const char *text)
{
    uint16_t value = 0u;
    uint8_t digit;

    if (*text < '0' || *text > '9') {
        return 0u;
    }
    while (*text >= '0' && *text <= '9') {
        digit = (uint8_t)(*text - '0');
        if (value > 6553u || (value == 6553u && digit > 5u)) {
            return 0u;
        }
        value = (uint16_t)(value * 10u + digit);
        ++text;
    }
    return *text == '\0' ? value : 0u;
}

static uint8_t mqtt_emit_timer_set(SessionState *state,
                                   SessionAction *actions,
                                   uint8_t *count,
                                   uint8_t timer_id,
                                   uint16_t ticks)
{
    if (*count >= SESSION_ACTION_CAPACITY || timer_id >= SESSION_TIMER_COUNT) {
        return 0u;
    }
    actions[*count].type = SESSION_ACT_TIMER_SET;
    actions[*count].data.timer_set.timer_id = timer_id;
    actions[*count].data.timer_set.duration_ticks = ticks;
    ++*count;
    state->timer_mask |= (uint8_t)(1u << timer_id);
    if (timer_id == SESSION_TIMER_LIVENESS) {
        state->liveness_misses = 0u;
    }
    return 1u;
}

static uint8_t mqtt_emit_timer_cancel(SessionState *state,
                                      SessionAction *actions,
                                      uint8_t *count,
                                      uint8_t timer_id)
{
    uint8_t bit = (uint8_t)(1u << timer_id);

    if ((state->timer_mask & bit) == 0u) {
        return 1u;
    }
    if (*count >= SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    actions[*count].type = SESSION_ACT_TIMER_CANCEL;
    actions[*count].data.timer_cancel.timer_id = timer_id;
    ++*count;
    state->timer_mask &= (uint8_t)~bit;
    return 1u;
}

static uint8_t mqtt_emit_session(SessionAction *actions,
                                 uint8_t *count,
                                 uint8_t status)
{
    if (*count >= SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    actions[*count].type = SESSION_ACT_SESSION_CHANGED;
    actions[*count].data.session.status = status;
    ++*count;
    return 1u;
}

static uint8_t mqtt_emit_side(SessionState *state,
                              SessionAction *actions,
                              uint8_t *count)
{
    if (*count >= SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    actions[*count].type = SESSION_ACT_SIDE_CHANGED;
    actions[*count].data.side.color = state->local_color;
    actions[*count].data.side.session_id = state->session_id;
    ++*count;
    return 1u;
}

static uint8_t mqtt_emit_close(SessionAction *actions,
                               uint8_t *count,
                               uint8_t link_id)
{
    if (*count >= SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    actions[*count].type = SESSION_ACT_LINK_CLOSE;
    actions[*count].data.link_close.link_id = link_id;
    ++*count;
    return 1u;
}

static uint8_t mqtt_emit_game(SessionAction *actions,
                              uint8_t *count,
                              uint8_t kind,
                              uint8_t delivery_id,
                              uint16_t value,
                              const uint8_t *payload,
                              uint8_t length)
{
    if (*count >= SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    actions[*count].type = SESSION_ACT_DELIVER_GAME;
    actions[*count].data.game.kind = kind;
    actions[*count].data.game.delivery_id = delivery_id;
    actions[*count].data.game.value = value;
    actions[*count].data.game.payload = payload;
    actions[*count].data.game.length = length;
    ++*count;
    return 1u;
}

static uint8_t mqtt_emit_decision(SessionAction *actions,
                                  uint8_t *count,
                                  uint8_t request_id,
                                  uint8_t control,
                                  uint16_t value)
{
    if (*count >= SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    actions[*count].type = SESSION_ACT_REQUEST_DECISION;
    actions[*count].data.decision.request_id = request_id;
    actions[*count].data.decision.control = control;
    actions[*count].data.decision.value = value;
    ++*count;
    return 1u;
}

static uint8_t mqtt_send_buffer(SessionState *state,
                                uint8_t *tx_scratch,
                                uint8_t tx_capacity,
                                SessionAction *actions,
                                uint8_t *count,
                                uint8_t route,
                                uint8_t retained,
                                uint8_t tx_kind)
{
    uint8_t length = 0u;
    uint8_t tx_id;

    if (state->pending_tx_kind != MQTT_TX_NONE || tx_scratch == 0 ||
        tx_capacity == 0u || *count + 2u > SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    while (length < tx_capacity && tx_scratch[length] != 0u) {
        ++length;
    }
    if (length == tx_capacity || length > SESSION_PAYLOAD_MAX) {
        return 0u;
    }
    tx_id = session_next_tx_id(state);
    state->pending_tx_id = tx_id;
    state->pending_tx_kind = tx_kind;
    state->tx_link = state->active_link;

    actions[*count].type = SESSION_ACT_SEND;
    actions[*count].data.send.payload = tx_scratch;
    actions[*count].data.send.length = length;
    actions[*count].data.send.tx_id = tx_id;
    actions[*count].data.send.route = route;
    actions[*count].data.send.retained = retained;
    actions[*count].data.send.link_id = state->active_link;
    ++*count;
    return mqtt_emit_timer_set(state,
                               actions,
                               count,
                               SESSION_TIMER_TX_GUARD,
                               SESSION_TX_GUARD_TICKS);
}

static uint8_t mqtt_send_text(SessionState *state,
                              const char *text,
                              uint8_t route,
                              uint8_t retained,
                              uint8_t tx_kind,
                              uint8_t *tx_scratch,
                              uint8_t tx_capacity,
                              SessionAction *actions,
                              uint8_t *count)
{
    uint8_t length = 0u;
    uint8_t i;

    while (length < SESSION_PAYLOAD_MAX && text[length] != '\0') {
        ++length;
    }
    if (length >= tx_capacity) {
        return 0u;
    }
    for (i = 0u; i <= length; ++i) {
        tx_scratch[i] = (uint8_t)text[i];
    }
    return mqtt_send_buffer(state,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            count,
                            route,
                            retained,
                            tx_kind);
}

static uint8_t mqtt_prepare_reply(SessionState *state,
                                  SessionAction *actions,
                                  uint8_t *count)
{
    uint8_t armed = (uint8_t)(
        (state->timer_mask & (uint8_t)(1u << SESSION_TIMER_LIVENESS)) != 0u);

    if (*count + 2u + armed > SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    return mqtt_emit_timer_cancel(state,
                                  actions,
                                  count,
                                  SESSION_TIMER_LIVENESS);
}

static uint8_t mqtt_send_side(SessionState *state,
                              uint8_t color,
                              char verb,
                              uint8_t retained,
                              uint8_t tx_kind,
                              uint8_t *tx_scratch,
                              uint8_t tx_capacity,
                              SessionAction *actions,
                              uint8_t *count)
{
    char side = netchess_mqtt_session_color_char(color);

    if (side == '\0' ||
        !netchess_mqtt_session_format_side((char *)tx_scratch,
                                           tx_capacity,
                                           verb,
                                           side,
                                           state->session_id,
                                           1u)) {
        return 0u;
    }
    return mqtt_send_buffer(state,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            count,
                            color == state->local_color
                                ? SESSION_ROUTE_PRESENCE
                                : SESSION_ROUTE_PRESENCE_PEER,
                            retained,
                            tx_kind);
}

static uint8_t mqtt_send_host(SessionState *state,
                              uint8_t retained,
                              uint8_t tx_kind,
                              uint8_t *tx_scratch,
                              uint8_t tx_capacity,
                              SessionAction *actions,
                              uint8_t *count)
{
    if (!netchess_mqtt_session_format_host((char *)tx_scratch,
                                           tx_capacity,
                                           state->config.host_color,
                                           state->session_id)) {
        return 0u;
    }
    return mqtt_send_buffer(state,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            count,
                            SESSION_ROUTE_META,
                            retained,
                            tx_kind);
}

static uint8_t mqtt_send_join(SessionState *state,
                              uint8_t *tx_scratch,
                              uint8_t tx_capacity,
                              SessionAction *actions,
                              uint8_t *count)
{
    if (!netchess_mqtt_session_format_join((char *)tx_scratch,
                                           tx_capacity,
                                           state->session_id)) {
        return 0u;
    }
    return mqtt_send_buffer(state,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            count,
                            SESSION_ROUTE_META,
                            0u,
                            MQTT_TX_JOIN);
}

static uint8_t mqtt_send_move(SessionState *state,
                              SessionWorkspace *workspace,
                              uint8_t *tx_scratch,
                              uint8_t tx_capacity,
                              SessionAction *actions,
                              uint8_t *count)
{
    char ply[6];

    mqtt_u16_text(ply, state->pending_value);
    if (!netchess_proto_format_move((char *)tx_scratch,
                                    tx_capacity,
                                    ply,
                                    workspace->move,
                                    0)) {
        return 0u;
    }
    return mqtt_send_buffer(state,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            count,
                            SESSION_ROUTE_GAME,
                            0u,
                            MQTT_TX_MOVE);
}

static uint8_t mqtt_send_value_text(SessionState *state,
                                    const char *prefix,
                                    uint16_t value,
                                    uint8_t route,
                                    uint8_t tx_kind,
                                    uint8_t *tx_scratch,
                                    uint8_t tx_capacity,
                                    SessionAction *actions,
                                    uint8_t *count)
{
    char value_text[6];
    uint8_t i = 0u;
    uint8_t j = 0u;

    mqtt_u16_text(value_text, value);
    while (prefix[i] != '\0') {
        if (i + 1u >= tx_capacity) {
            return 0u;
        }
        tx_scratch[i] = (uint8_t)prefix[i];
        ++i;
    }
    while (value_text[j] != '\0') {
        if (i + 1u >= tx_capacity) {
            return 0u;
        }
        tx_scratch[i++] = (uint8_t)value_text[j++];
    }
    tx_scratch[i] = 0u;
    return mqtt_send_buffer(state,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            count,
                            route,
                            0u,
                            tx_kind);
}

static uint8_t mqtt_send_restore_chunk(SessionState *state,
                                       SessionWorkspace *workspace,
                                       uint8_t chunk,
                                       uint8_t *tx_scratch,
                                       uint8_t tx_capacity,
                                       SessionAction *actions,
                                       uint8_t *count)
{
    if (!session_build_restore_chunk(workspace, chunk, tx_scratch,
                                     tx_capacity)) {
        return 0u;
    }
    return mqtt_send_buffer(state,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            count,
                            SESSION_ROUTE_GAME,
                            0u,
                            chunk == 0u ? MQTT_TX_RS0 : MQTT_TX_RS1);
}

static uint8_t mqtt_send_local_pending(SessionState *state,
                                       SessionWorkspace *workspace,
                                       uint8_t *tx_scratch,
                                       uint8_t tx_capacity,
                                       SessionAction *actions,
                                       uint8_t *count)
{
    switch (state->pending_control) {
    case SESSION_REQUEST_START:
        return mqtt_send_text(state,
                              "GAME START",
                              SESSION_ROUTE_CONTROL,
                              0u,
                              MQTT_TX_START,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              count);
    case SESSION_REQUEST_MOVE:
        return mqtt_send_move(state,
                              workspace,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              count);
    case SESSION_REQUEST_RESET:
        return mqtt_send_text(state,
                              state->pending_value == MQTT_CANCEL_SENT
                                  ? NETCHESS_PROTO_CANCEL_RESET : "RESET",
                              SESSION_ROUTE_CONTROL,
                              0u,
                              MQTT_TX_RESET,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              count);
    case SESSION_REQUEST_DRAW:
        return mqtt_send_text(state,
                              state->pending_value == MQTT_CANCEL_SENT
                                  ? NETCHESS_PROTO_CANCEL_DRAW : "DRAW",
                              SESSION_ROUTE_CONTROL,
                              0u,
                              MQTT_TX_DRAW,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              count);
    case SESSION_REQUEST_RESIGN:
        return mqtt_send_text(state,
                              "RESIGN",
                              SESSION_ROUTE_CONTROL,
                              0u,
                              MQTT_TX_RESIGN,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              count);
    case SESSION_REQUEST_TAKEBACK:
        return mqtt_send_value_text(state,
                                    "TAKEBACK ",
                                    state->pending_value,
                                    SESSION_ROUTE_CONTROL,
                                    MQTT_TX_TAKEBACK,
                                    tx_scratch,
                                    tx_capacity,
                                    actions,
                                    count);
    case SESSION_REQUEST_RESTORE:
        if (state->restore_phase == MQTT_RESTORE_WAIT_RA) {
            return mqtt_send_restore_chunk(state,
                                           workspace,
                                           0u,
                                           tx_scratch,
                                           tx_capacity,
                                           actions,
                                           count);
        }
        return mqtt_send_text(state,
                              "RQ",
                              SESSION_ROUTE_GAME,
                              0u,
                              MQTT_TX_RQ,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              count);
    default:
        return 0u;
    }
}

static uint8_t mqtt_send_move_reply(SessionState *state,
                                    uint16_t value,
                                    const uint8_t *detail,
                                    uint8_t detail_length,
                                    uint8_t accepted,
                                    uint8_t *tx_scratch,
                                    uint8_t tx_capacity,
                                    SessionAction *actions,
                                    uint8_t *count)
{
    char ply[6];
    const char *detail_text = detail_length == 0u
                                  ? 0
                                  : (const char *)detail;
    uint8_t formatted;

    if (!mqtt_prepare_reply(state, actions, count)) {
        return 0u;
    }
    mqtt_u16_text(ply, value);
    if (accepted != 0u) {
        formatted = netchess_proto_format_ack((char *)tx_scratch,
                                              tx_capacity,
                                              ply,
                                              detail_text);
    } else {
        formatted = netchess_proto_format_nack((char *)tx_scratch,
                                               tx_capacity,
                                               ply,
                                               detail_text);
    }
    if (formatted == 0u) {
        return 0u;
    }
    return mqtt_send_buffer(state,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            count,
                            SESSION_ROUTE_ACK,
                            0u,
                            accepted != 0u
                                ? MQTT_TX_ACK_MOVE
                                : MQTT_TX_NACK_MOVE);
}

static uint8_t mqtt_send_takeback_reply(SessionState *state,
                                        uint16_t value,
                                        const uint8_t *detail,
                                        uint8_t detail_length,
                                        uint8_t accepted,
                                        uint8_t tx_kind,
                                        uint8_t *tx_scratch,
                                        uint8_t tx_capacity,
                                        SessionAction *actions,
                                        uint8_t *count)
{
    char ply[6];
    const char *detail_text = detail_length == 0u
                                  ? 0
                                  : (const char *)detail;
    uint8_t formatted;

    mqtt_u16_text(ply, value);
    if (accepted != 0u) {
        formatted = netchess_proto_format_ack((char *)tx_scratch,
                                              tx_capacity,
                                              ply,
                                              detail_text);
    } else {
        formatted = netchess_proto_format_nack((char *)tx_scratch,
                                               tx_capacity,
                                               ply,
                                               detail_text);
    }
    if (formatted == 0u) {
        return 0u;
    }
    return mqtt_send_buffer(state,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            count,
                            SESSION_ROUTE_ACK,
                            0u,
                            tx_kind);
}

static uint8_t mqtt_finish(SessionState *state,
                           SessionAction *actions,
                           uint8_t count,
                           uint8_t close_link)
{
    uint8_t timer_id;

    for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
        if (!mqtt_emit_timer_cancel(state, actions, &count, timer_id)) {
            return 0u;
        }
    }
    if (close_link != SESSION_LINK_NONE &&
        !mqtt_emit_close(actions, &count, close_link)) {
        return 0u;
    }
    if (!mqtt_emit_session(actions, &count, SESSION_CHANGED_ENDED)) {
        return 0u;
    }
    session_reset(state);
    return count;
}

static uint8_t mqtt_wait_for_peer(SessionState *state,
                                  SessionAction *actions,
                                  uint8_t count)
{
    uint8_t timer_id;

    for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
        if (!mqtt_emit_timer_cancel(state, actions, &count, timer_id)) {
            return 0u;
        }
    }
    if (!mqtt_emit_session(actions, &count, SESSION_CHANGED_ENDED)) {
        return 0u;
    }
    state->current_ply = 0u;
    state->pending_value = 0u;
    state->last_value = 0u;
    state->phase = SESSION_PHASE_HANDSHAKE;
    state->deferred_decision &= MQTT_STATE_OWN_ONLINE;
    state->peer_ready = 0u;
    state->tx_link = SESSION_LINK_NONE;
    state->pending_control = 0u;
    state->pending_origin = MQTT_ORIGIN_NONE;
    state->pending_request_id = 0u;
    state->pending_tx_id = 0u;
    state->pending_tx_kind = MQTT_TX_NONE;
    state->control_retries = 0u;
    state->liveness_misses = 0u;
    state->last_rx_kind = 0u;
    state->last_result = 0u;
    state->delivery_id = 0u;
    state->restore_phase = 0u;
    state->restore_mask = 0u;
    if (state->config.role == SESSION_ROLE_HOST &&
        !mqtt_emit_timer_set(state,
                             actions,
                             &count,
                             SESSION_TIMER_CONTROL,
                             MQTT_SETUP_TICKS)) {
        return 0u;
    }
    return count;
}

static uint8_t mqtt_send_offline_end(SessionState *state,
                                     uint8_t *tx_scratch,
                                     uint8_t tx_capacity,
                                     SessionAction *actions,
                                     uint8_t *count)
{
    if (!mqtt_emit_timer_cancel(state,
                                actions,
                                count,
                                SESSION_TIMER_LIVENESS)) {
        return 0u;
    }
    return mqtt_send_side(state,
                          state->local_color,
                          NETCHESS_MQTT_SESSION_VERB_OFFLINE,
                          1u,
                          MQTT_TX_OFFLINE_END,
                          tx_scratch,
                          tx_capacity,
                          actions,
                          count);
}

static uint8_t mqtt_handle_link_up(SessionState *state,
                                   uint8_t link_id,
                                   uint8_t *tx_scratch,
                                   uint8_t tx_capacity,
                                   SessionAction *actions)
{
    uint8_t count = 0u;

    if (link_id == SESSION_LINK_NONE || state->link_up != 0u) {
        return 0u;
    }
    if (state->config.role == SESSION_ROLE_HOST &&
        (state->config.host_color > SESSION_COLOR_BLACK ||
         state->session_id == 0u)) {
        return 0u;
    }
    state->link_up = 1u;
    state->active_link = link_id;
    state->phase = SESSION_PHASE_HANDSHAKE;
    if (state->config.role == SESSION_ROLE_HOST &&
        !mqtt_send_side(state,
                        state->local_color,
                        NETCHESS_MQTT_SESSION_VERB_ONLINE,
                        1u,
                        MQTT_TX_ONLINE,
                        tx_scratch,
                        tx_capacity,
                        actions,
                        &count)) {
        session_reset(state);
        return 0u;
    }
    return count;
}

static uint8_t mqtt_handle_host(SessionState *state,
                                const SessionEvent *event,
                                uint8_t *tx_scratch,
                                uint8_t tx_capacity,
                                SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t host_color;
    uint8_t local_color;
    uint16_t session_id;

    if (!netchess_mqtt_session_parse_host(
            (const char *)event->data.rx.payload,
            &host_color,
            &session_id)) {
        return 0u;
    }
    if (state->config.role == SESSION_ROLE_HOST) {
        return 0u;
    }
    local_color = (uint8_t)(host_color ^ 1u);
    if ((event->data.rx.flags & SESSION_RX_RETAINED) != 0u) {
        if (state->peer_ready != 0u) {
            return 0u;
        }
        state->deferred_decision |= MQTT_STATE_PROBING;
        if (state->session_id == session_id &&
            state->local_color == local_color) {
            return 0u;
        }
        state->session_id = session_id;
        state->local_color = local_color;
        return mqtt_emit_side(state, actions, &count) ? count : 0u;
    }
    if ((event->data.rx.flags & SESSION_RX_LIVE) == 0u) {
        return 0u;
    }
    if (state->peer_ready != 0u) {
        if (state->session_id == session_id &&
            state->local_color == local_color) {
            return 0u;
        }
        if (state->phase != SESSION_PHASE_READY) {
            return 0u;
        }
    }
    if (state->session_id != session_id ||
        state->local_color != local_color) {
        state->session_id = session_id;
        state->local_color = local_color;
        if (!mqtt_emit_side(state, actions, &count)) {
            return 0u;
        }
    }
    if (state->peer_ready != 0u &&
        !mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_LIVENESS)) {
        return 0u;
    }
    state->deferred_decision &= (uint8_t)~MQTT_STATE_PROBING;
    return mqtt_send_side(state,
                          state->local_color,
                          NETCHESS_MQTT_SESSION_VERB_ONLINE,
                          1u,
                          MQTT_TX_ONLINE,
                          tx_scratch,
                          tx_capacity,
                          actions,
                          &count)
               ? count
               : 0u;
}

static uint8_t mqtt_handle_online(SessionState *state,
                                  const SessionEvent *event,
                                  SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t has_session_id;
    uint8_t local_side;
    char side;
    uint16_t session_id;

    if (event->data.rx.route != SESSION_ROUTE_PRESENCE ||
        !netchess_mqtt_session_parse_side(
            (const char *)event->data.rx.payload,
            NETCHESS_MQTT_SESSION_VERB_ONLINE,
            &side,
            &session_id,
            &has_session_id)) {
        return 0u;
    }
    local_side = (uint8_t)netchess_mqtt_session_color_char(state->local_color);
    if (state->config.role == SESSION_ROLE_GUEST &&
        (state->deferred_decision & MQTT_STATE_PROBING) != 0u &&
        (event->data.rx.flags & SESSION_RX_RETAINED) != 0u &&
        has_session_id != 0u && side == (char)local_side &&
        session_id == state->session_id && state->peer_ready == 0u) {
        if (!mqtt_emit_session(actions, &count, SESSION_CHANGED_BUSY) ||
            !mqtt_emit_close(actions, &count, state->active_link) ||
            !mqtt_emit_session(actions, &count, SESSION_CHANGED_ENDED)) {
            return 0u;
        }
        session_reset(state);
        return count;
    }
    return 0u;
}

static uint8_t mqtt_handle_offline(SessionState *state,
                                   const SessionEvent *event,
                                   uint8_t *tx_scratch,
                                   uint8_t tx_capacity,
                                   SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t has_session_id;
    char local_side;
    char side;
    uint16_t session_id;

    if (event->data.rx.route != SESSION_ROUTE_PRESENCE ||
        (event->data.rx.flags & SESSION_RX_LIVE) == 0u ||
        (event->data.rx.flags & SESSION_RX_RETAINED) != 0u ||
        !netchess_mqtt_session_parse_side(
            (const char *)event->data.rx.payload,
            NETCHESS_MQTT_SESSION_VERB_OFFLINE,
            &side,
            &session_id,
            &has_session_id) ||
        has_session_id == 0u || session_id != state->session_id) {
        return 0u;
    }
    local_side = netchess_mqtt_session_color_char(state->local_color);
    if (side == local_side &&
        (state->deferred_decision & MQTT_STATE_OWN_ONLINE) != 0u) {
        return mqtt_send_side(state,
                              state->local_color,
                              NETCHESS_MQTT_SESSION_VERB_ONLINE,
                              1u,
                              MQTT_TX_ONLINE_REFRESH,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              &count)
                   ? count
                   : 0u;
    }
    if (side != local_side) {
        return mqtt_finish(state, actions, count, SESSION_LINK_NONE);
    }
    return 0u;
}

static uint8_t mqtt_handle_join(SessionState *state,
                                const SessionEvent *event,
                                uint8_t *tx_scratch,
                                uint8_t tx_capacity,
                                SessionAction *actions)
{
    uint8_t count = 0u;
    uint16_t session_id;

    if (state->config.role != SESSION_ROLE_HOST ||
        (event->data.rx.flags & SESSION_RX_LIVE) == 0u ||
        !netchess_mqtt_session_parse_join(
            (const char *)event->data.rx.payload,
            &session_id) ||
        session_id != state->session_id ||
        state->phase == SESSION_PHASE_ACTIVE ||
        state->phase == SESSION_PHASE_OVER) {
        return 0u;
    }
    if ((state->peer_ready == 0u &&
         !mqtt_emit_timer_cancel(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_CONTROL)) ||
        !mqtt_send_host(state,
                        0u,
                        MQTT_TX_HOST_LIVE,
                        tx_scratch,
                        tx_capacity,
                        actions,
                        &count)) {
        return 0u;
    }
    return count;
}

static uint8_t mqtt_handle_game_start(SessionState *state,
                                      const SessionEvent *event,
                                      uint8_t *tx_scratch,
                                      uint8_t tx_capacity,
                                      SessionAction *actions)
{
    uint8_t count = 0u;

    if (state->config.role != SESSION_ROLE_GUEST ||
        state->peer_ready == 0u || state->session_id == 0u ||
        (event->data.rx.flags & SESSION_RX_LIVE) == 0u ||
        (event->data.rx.flags & SESSION_RX_RETAINED) != 0u ||
        (state->phase != SESSION_PHASE_READY &&
         state->phase != SESSION_PHASE_ACTIVE &&
         state->phase != SESSION_PHASE_OVER) ||
        (state->phase == SESSION_PHASE_OVER &&
         (state->pending_control != 0u ||
          state->pending_request_id != 0u)) ||
        !netchess_proto_parse_game_start(
            (const char *)event->data.rx.payload, 0, 0u)) {
        return 0u;
    }
    if (!mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_LIVENESS) ||
        (state->phase != SESSION_PHASE_ACTIVE &&
         !mqtt_emit_timer_cancel(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_CONTROL))) {
        return 0u;
    }
    if (state->phase != SESSION_PHASE_ACTIVE) {
        state->pending_control = SESSION_REQUEST_START;
        state->pending_origin = MQTT_ORIGIN_REMOTE;
        state->control_retries = 0u;
    }
    return mqtt_send_text(state,
                          "ACK GAME START",
                          SESSION_ROUTE_CONTROL,
                          0u,
                          MQTT_TX_ACK_START,
                          tx_scratch,
                          tx_capacity,
                          actions,
                          &count)
               ? count
               : 0u;
}

static uint8_t mqtt_handle_start_reply(SessionState *state,
                                       const SessionEvent *event,
                                       SessionAction *actions)
{
    static const char nack_prefix[] = "NACK GAME START";
    const uint8_t *payload = event->data.rx.payload;
    const uint8_t *reason = 0;
    uint8_t reason_length = 0u;
    uint8_t count = 0u;
    uint8_t accepted;

    if (state->config.role != SESSION_ROLE_HOST ||
        (event->data.rx.flags & SESSION_RX_LIVE) == 0u ||
        (event->data.rx.flags & SESSION_RX_RETAINED) != 0u) {
        return 0u;
    }
    accepted = mqtt_text_equal(payload,
                               event->data.rx.length,
                               "ACK GAME START");
    if (accepted == 0u) {
        if (!mqtt_text_prefix(payload,
                              event->data.rx.length,
                              nack_prefix) ||
            (event->data.rx.length > 15u && payload[15] != ' ')) {
            return 0u;
        }
        if (event->data.rx.length > 16u) {
            reason = payload + 16u;
            reason_length = (uint8_t)(event->data.rx.length - 16u);
        }
    }
    if (state->pending_control != SESSION_REQUEST_START ||
        state->pending_origin != MQTT_ORIGIN_LOCAL ||
        state->phase != SESSION_PHASE_READY) {
        if (state->peer_ready == 0u ||
            !mqtt_emit_timer_set(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_LIVENESS,
                                 MQTT_LIVENESS_TICKS)) {
            return 0u;
        }
        return count;
    }
    if (!mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_CONTROL)) {
        return 0u;
    }
    state->pending_control = 0u;
    state->pending_origin = MQTT_ORIGIN_NONE;
    if (accepted != 0u) {
        state->phase = SESSION_PHASE_ACTIVE;
        state->current_ply = 0u;
        if (!mqtt_emit_session(actions, &count, SESSION_CHANGED_STARTED)) {
            return 0u;
        }
    } else if (!mqtt_emit_game(actions,
                               &count,
                               SESSION_DELIVER_CONTROL_RESULT,
                               SESSION_CONTROL_REJECTED,
                               SESSION_REQUEST_START,
                               reason,
                               reason_length)) {
        return 0u;
    }
    return mqtt_emit_timer_set(state,
                               actions,
                               &count,
                               SESSION_TIMER_LIVENESS,
                               MQTT_LIVENESS_TICKS)
               ? count
               : 0u;
}

static uint8_t mqtt_handle_chat(SessionState *state,
                                const SessionEvent *event,
                                SessionAction *actions,
                                uint8_t rearm_liveness)
{
    char text[SESSION_CHAT_TEXT_MAX + 1u];
    uint8_t count = 0u;

    if (state->peer_ready == 0u ||
        (event->data.rx.flags & SESSION_RX_LIVE) == 0u ||
        (event->data.rx.flags & SESSION_RX_RETAINED) != 0u ||
        event->data.rx.length > (uint8_t)(5u + SESSION_CHAT_TEXT_MAX) ||
        !netchess_proto_parse_chat((const char *)event->data.rx.payload,
                                   text,
                                   sizeof(text)) ||
        !mqtt_emit_game(actions,
                        &count,
                        SESSION_DELIVER_CHAT,
                        0u,
                        SESSION_CHAT_REMOTE,
                        event->data.rx.payload + 5u,
                        (uint8_t)(event->data.rx.length - 5u))) {
        return 0u;
    }
    if (rearm_liveness != 0u &&
        !mqtt_emit_timer_set(state,
                             actions,
                             &count,
                             SESSION_TIMER_LIVENESS,
                             MQTT_LIVENESS_TICKS)) {
        return 0u;
    }
    return count;
}

static uint8_t mqtt_send_control_reply(SessionState *state,
                                       uint8_t control,
                                       uint16_t value,
                                       uint8_t accepted,
                                       uint8_t tx_kind,
                                       const uint8_t *detail,
                                       uint8_t detail_length,
                                       uint8_t *tx_scratch,
                                       uint8_t tx_capacity,
                                       SessionAction *actions,
                                       uint8_t *count)
{
    if (control == SESSION_REQUEST_TAKEBACK) {
        return mqtt_send_takeback_reply(state,
                                        value,
                                        detail,
                                        detail_length,
                                        accepted,
                                        tx_kind,
                                        tx_scratch,
                                        tx_capacity,
                                        actions,
                                        count);
    }
    if (control == SESSION_REQUEST_RESTORE) {
        return mqtt_send_text(state,
                              accepted != 0u ? "RY" : "RN",
                              SESSION_ROUTE_GAME,
                              0u,
                              tx_kind,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              count);
    }
    if (control == SESSION_REQUEST_RESET) {
        if (!mqtt_prepare_reply(state, actions, count)) {
            return 0u;
        }
        return mqtt_send_text(state,
                              accepted != 0u
                                  ? "ACK RESET"
                                  : "NACK RESET",
                              SESSION_ROUTE_CONTROL,
                              0u,
                              tx_kind,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              count);
    }
    if (control == SESSION_REQUEST_DRAW) {
        if (!mqtt_prepare_reply(state, actions, count)) {
            return 0u;
        }
        return mqtt_send_text(state,
                              accepted != 0u
                                  ? "ACK DRAW"
                                  : "NACK DRAW",
                              accepted != 0u
                                  ? SESSION_ROUTE_ACK
                                  : SESSION_ROUTE_CONTROL,
                              0u,
                              tx_kind,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              count);
    }
    return 0u;
}

static uint8_t mqtt_begin_decision(SessionState *state,
                                   uint8_t control,
                                   uint16_t value,
                                   uint8_t *tx_scratch,
                                   uint8_t tx_capacity,
                                   SessionAction *actions)
{
    uint8_t count = 0u;

    if (state->pending_request_id != 0u) {
        return control != SESSION_REQUEST_RESTORE &&
               mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_LIVENESS,
                                   MQTT_LIVENESS_TICKS)
                   ? count
                   : 0u;
    }
    if (state->last_rx_kind == control && state->last_value == value &&
        state->last_result != 0u) {
        return mqtt_send_control_reply(
                   state,
                   control,
                   value,
                   (uint8_t)(state->last_result == SESSION_DECISION_ACCEPT ||
                             state->last_result == SESSION_GAME_ACCEPTED),
                   MQTT_TX_TRANSIENT_REPLY,
                   0,
                   0u,
                   tx_scratch,
                   tx_capacity,
                   actions,
                   &count)
                   ? count
                   : 0u;
    }
    if (control == SESSION_REQUEST_TAKEBACK &&
        value != state->current_ply) {
        if (!mqtt_prepare_reply(state, actions, &count)) {
            return 0u;
        }
        return mqtt_send_control_reply(state,
                                       control,
                                       value,
                                       0u,
                                       MQTT_TX_TRANSIENT_REPLY,
                                       0,
                                       0u,
                                       tx_scratch,
                                       tx_capacity,
                                       actions,
                                       &count)
                   ? count
                   : 0u;
    }
    if (control == SESSION_REQUEST_TAKEBACK &&
        state->last_rx_kind == SESSION_REQUEST_TAKEBACK &&
        state->last_value != value &&
        state->last_result == SESSION_GAME_ACCEPTED) {
        if (!mqtt_prepare_reply(state, actions, &count)) {
            return 0u;
        }
        return mqtt_send_control_reply(state,
                                       control,
                                       value,
                                       0u,
                                       MQTT_TX_TRANSIENT_REPLY,
                                       0,
                                       0u,
                                       tx_scratch,
                                       tx_capacity,
                                       actions,
                                       &count)
                   ? count
                   : 0u;
    }
    if (control == SESSION_REQUEST_RESET &&
        state->phase != SESSION_PHASE_ACTIVE &&
        state->phase != SESSION_PHASE_OVER) {
        return mqtt_send_text(state,
                              "NACK RESET START",
                              SESSION_ROUTE_CONTROL,
                              0u,
                              MQTT_TX_TRANSIENT_REPLY,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              &count)
                   ? count
                   : 0u;
    }
    if ((control == SESSION_REQUEST_DRAW ||
         control == SESSION_REQUEST_TAKEBACK) &&
        state->phase != SESSION_PHASE_ACTIVE) {
        return mqtt_send_control_reply(state,
                                       control,
                                       value,
                                       0u,
                                       MQTT_TX_TRANSIENT_REPLY,
                                       0,
                                       0u,
                                       tx_scratch,
                                       tx_capacity,
                                       actions,
                                       &count)
                   ? count
                   : 0u;
    }
    if (control == SESSION_REQUEST_RESET &&
        state->phase == SESSION_PHASE_OVER &&
        state->pending_control == 0u &&
        state->last_rx_kind == SESSION_REQUEST_RESIGN &&
        state->last_result != 0u) {
        state->pending_request_id = session_next_delivery_id(state);
        state->pending_control = SESSION_REQUEST_RESET;
        state->pending_origin = MQTT_ORIGIN_REMOTE;
        state->pending_value = 0u;
        state->last_rx_kind = SESSION_REQUEST_RESET;
        state->last_value = 0u;
        state->last_result = SESSION_DECISION_ACCEPT;
        if (!mqtt_prepare_reply(state, actions, &count) ||
            !mqtt_send_control_reply(state,
                                     SESSION_REQUEST_RESET,
                                     0u,
                                     1u,
                                     MQTT_TX_ACK_RESET,
                                     0,
                                     0u,
                                     tx_scratch,
                                     tx_capacity,
                                     actions,
                                     &count)) {
            return 0u;
        }
        return count;
    }
    if (state->pending_control != 0u) {
        if (control == SESSION_REQUEST_DRAW &&
            state->pending_control == SESSION_REQUEST_DRAW &&
            state->pending_origin == MQTT_ORIGIN_LOCAL) {
            if (!mqtt_emit_timer_cancel(state,
                                        actions,
                                        &count,
                                        SESSION_TIMER_CONTROL) ||
                !mqtt_send_control_reply(state,
                                         control,
                                         0u,
                                         1u,
                                         MQTT_TX_ACK_DRAW_CROSSED,
                                         0,
                                         0u,
                                         tx_scratch,
                                         tx_capacity,
                                         actions,
                                         &count)) {
                return 0u;
            }
            state->last_rx_kind = SESSION_REQUEST_DRAW;
            state->last_value = 0u;
            state->last_result = SESSION_DECISION_ACCEPT;
            return count;
        }
        if (control == SESSION_REQUEST_RESET &&
            state->pending_control == SESSION_REQUEST_RESET &&
            state->phase == SESSION_PHASE_OVER) {
            if (!mqtt_emit_timer_cancel(state,
                                        actions,
                                        &count,
                                        SESSION_TIMER_CONTROL) ||
                !mqtt_send_control_reply(state,
                                         control,
                                         0u,
                                         1u,
                                         MQTT_TX_ACK_RESET_CROSSED,
                                         0,
                                         0u,
                                         tx_scratch,
                                         tx_capacity,
                                         actions,
                                         &count)) {
                return 0u;
            }
            state->last_rx_kind = SESSION_REQUEST_RESET;
            state->last_value = 0u;
            state->last_result = SESSION_DECISION_ACCEPT;
            return count;
        }
        if (control == SESSION_REQUEST_RESET) {
            return mqtt_send_text(state,
                                  "NACK RESET BUSY",
                                  SESSION_ROUTE_CONTROL,
                                  0u,
                                  MQTT_TX_TRANSIENT_REPLY,
                                  tx_scratch,
                                  tx_capacity,
                                  actions,
                                  &count)
                       ? count
                       : 0u;
        }
        return mqtt_send_control_reply(state,
                                       control,
                                       value,
                                       0u,
                                       MQTT_TX_TRANSIENT_REPLY,
                                       0,
                                       0u,
                                       tx_scratch,
                                       tx_capacity,
                                       actions,
                                       &count)
                   ? count
                   : 0u;
    }
    state->pending_request_id = session_next_delivery_id(state);
    state->pending_control = control;
    state->pending_origin = MQTT_ORIGIN_REMOTE;
    state->pending_value = value;
    if (!mqtt_emit_decision(actions,
                            &count,
                            state->delivery_id,
                            control,
                            value)) {
        return 0u;
    }
    if (control != SESSION_REQUEST_RESTORE &&
        !mqtt_emit_timer_set(state,
                             actions,
                             &count,
                             SESSION_TIMER_LIVENESS,
                             MQTT_LIVENESS_TICKS)) {
        return 0u;
    }
    return count;
}

static uint8_t mqtt_handle_resign(SessionState *state,
                                  uint8_t *tx_scratch,
                                  uint8_t tx_capacity,
                                  SessionAction *actions)
{
    uint8_t count = 0u;

    if (state->phase == SESSION_PHASE_OVER) {
        uint8_t tx_kind =
            state->pending_control == SESSION_REQUEST_RESIGN &&
                    state->pending_origin == MQTT_ORIGIN_LOCAL
                ? MQTT_TX_ACK_RESIGN_CROSSED
                : MQTT_TX_TRANSIENT_REPLY;

        if (tx_kind == MQTT_TX_ACK_RESIGN_CROSSED &&
            !mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        if (!mqtt_prepare_reply(state, actions, &count)) {
            return 0u;
        }
        state->last_rx_kind = SESSION_REQUEST_RESIGN;
        state->last_value = 0u;
        state->last_result = SESSION_DECISION_ACCEPT;
        return mqtt_send_text(state,
                              "ACK RESIGN",
                              SESSION_ROUTE_CONTROL,
                              0u,
                              tx_kind,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              &count)
                   ? count
                   : 0u;
    }
    if (state->phase != SESSION_PHASE_ACTIVE ||
        !mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_CONTROL) ||
        !mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_LIVENESS)) {
        return 0u;
    }
    state->pending_control = 0u;
    state->pending_origin = MQTT_ORIGIN_NONE;
    state->pending_request_id = 0u;
    state->restore_phase = MQTT_RESTORE_NONE;
    state->restore_mask = 0u;
    state->pending_request_id = session_next_delivery_id(state);
    state->pending_control = SESSION_REQUEST_RESIGN;
    state->pending_origin = MQTT_ORIGIN_REMOTE;
    state->last_rx_kind = SESSION_REQUEST_RESIGN;
    state->last_value = 0u;
    state->last_result = SESSION_DECISION_ACCEPT;
    return mqtt_send_text(state,
                          "ACK RESIGN",
                          SESSION_ROUTE_CONTROL,
                          0u,
                          MQTT_TX_ACK_RESIGN,
                          tx_scratch,
                          tx_capacity,
                          actions,
                          &count)
               ? count
               : 0u;
}

static uint8_t mqtt_handle_control_reply(SessionState *state,
                                         const SessionEvent *event,
                                         uint8_t *tx_scratch,
                                         uint8_t tx_capacity,
                                         SessionAction *actions)
{
    const uint8_t *payload = event->data.rx.payload;
    uint8_t count = 0u;
    uint8_t control;

    if ((event->data.rx.flags & SESSION_RX_LIVE) == 0u ||
        (event->data.rx.flags & SESSION_RX_RETAINED) != 0u) {
        return 0u;
    }
    if (mqtt_text_equal(payload, event->data.rx.length, "ACK RESET") &&
        state->pending_control == SESSION_REQUEST_RESET &&
        state->pending_origin == MQTT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u) {
        if (!mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_value = 0u;
        state->phase = SESSION_PHASE_ACTIVE;
        state->current_ply = 0u;
        session_clear_duplicate(state);
        if (!mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_CONTROL_RESULT,
                            SESSION_CONTROL_ACCEPTED,
                            SESSION_REQUEST_RESET,
                            0,
                            0u) ||
            !mqtt_emit_session(actions, &count, SESSION_CHANGED_STARTED) ||
            !mqtt_emit_timer_set(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_LIVENESS,
                                 MQTT_LIVENESS_TICKS)) {
            return 0u;
        }
        return count;
    }
    if (mqtt_text_equal(payload, event->data.rx.length, "ACK DRAW") &&
        state->pending_control == SESSION_REQUEST_DRAW &&
        state->pending_origin == MQTT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u) {
        if (!mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->phase = SESSION_PHASE_OVER;
        state->pending_control = SESSION_REQUEST_RESET;
        state->pending_origin = MQTT_ORIGIN_LOCAL;
        state->pending_value = 0u;
        state->control_retries = 0u;
        if (!mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_CONTROL_RESULT,
                            SESSION_CONTROL_ACCEPTED,
                            SESSION_REQUEST_DRAW,
                            0,
                            0u) ||
            !mqtt_send_local_pending(state,
                                     0,
                                     tx_scratch,
                                     tx_capacity,
                                     actions,
                                     &count)) {
            return 0u;
        }
        return count;
    }
    if (mqtt_text_equal(payload, event->data.rx.length, "ACK RESIGN") &&
        state->pending_control == SESSION_REQUEST_RESIGN &&
        state->pending_origin == MQTT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u) {
        if (!mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->pending_control = SESSION_REQUEST_RESET;
        state->pending_origin = MQTT_ORIGIN_LOCAL;
        state->pending_value = 0u;
        state->control_retries = 0u;
        if (!mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_CONTROL_RESULT,
                            SESSION_CONTROL_ACCEPTED,
                            SESSION_REQUEST_RESIGN,
                            0,
                            0u) ||
            !mqtt_send_local_pending(state,
                                     0,
                                     tx_scratch,
                                     tx_capacity,
                                     actions,
                                     &count)) {
            return 0u;
        }
        return count;
    }
    control = mqtt_text_prefix(payload,
                               event->data.rx.length,
                               "NACK RESET")
                  ? SESSION_REQUEST_RESET
                  : mqtt_text_prefix(payload,
                                     event->data.rx.length,
                                     "NACK DRAW")
                        ? SESSION_REQUEST_DRAW
                        : 0u;
    if (control == 0u || state->pending_control != control ||
        state->pending_origin != MQTT_ORIGIN_LOCAL ||
        state->pending_request_id != 0u) {
        return 0u;
    }
    if (!mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_CONTROL)) {
        return 0u;
    }
    {
        uint8_t result = state->pending_value == MQTT_CANCEL_SENT
                             ? SESSION_CONTROL_CANCELLED
                             : SESSION_CONTROL_REJECTED;

        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_value = 0u;
        return mqtt_emit_game(actions,
                              &count,
                              SESSION_DELIVER_CONTROL_RESULT,
                              result,
                              control,
                              payload,
                              event->data.rx.length) &&
                       mqtt_emit_timer_set(state,
                                           actions,
                                           &count,
                                           SESSION_TIMER_LIVENESS,
                                           MQTT_LIVENESS_TICKS)
                   ? count
                   : 0u;
    }
}

static uint8_t mqtt_handle_user_decision(SessionState *state,
                                         const SessionEvent *event,
                                         uint8_t *tx_scratch,
                                         uint8_t tx_capacity,
                                         SessionAction *actions)
{
    uint8_t accepted;
    uint8_t control;
    uint8_t count = 0u;
    uint8_t tx_kind;

    if (state->pending_tx_kind != MQTT_TX_NONE ||
        state->pending_request_id == 0u ||
        event->data.user.request_id != state->pending_request_id ||
        (event->data.user.decision != SESSION_DECISION_ACCEPT &&
         event->data.user.decision != SESSION_DECISION_REJECT)) {
        return 0u;
    }
    control = state->pending_control;
    accepted = (uint8_t)(event->data.user.decision ==
                         SESSION_DECISION_ACCEPT);
    if (control == SESSION_REQUEST_TAKEBACK && accepted != 0u) {
        if (!mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_TAKEBACK,
                            state->pending_request_id,
                            state->pending_value,
                            0,
                            0u) ||
            !mqtt_emit_timer_set(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_CONTROL,
                                 MQTT_REPLY_TICKS)) {
            return 0u;
        }
        return count;
    }
    state->last_rx_kind = control;
    state->last_value = state->pending_value;
    state->last_result = event->data.user.decision;
    if (control == SESSION_REQUEST_RESTORE) {
        tx_kind = accepted != 0u ? MQTT_TX_RY : MQTT_TX_RN;
    } else if (control == SESSION_REQUEST_RESET) {
        tx_kind = accepted != 0u
                      ? MQTT_TX_ACK_RESET
                      : MQTT_TX_NACK_RESET;
    } else if (control == SESSION_REQUEST_DRAW) {
        tx_kind = accepted != 0u
                      ? MQTT_TX_ACK_DRAW
                      : MQTT_TX_NACK_DRAW;
    } else if (control == SESSION_REQUEST_TAKEBACK) {
        tx_kind = MQTT_TX_NACK_TAKEBACK;
    } else {
        return 0u;
    }
    if (accepted == 0u &&
        (control == SESSION_REQUEST_TAKEBACK ||
         (control == SESSION_REQUEST_RESTORE &&
          state->phase == SESSION_PHASE_READY)) &&
        !mqtt_prepare_reply(state, actions, &count)) {
        return 0u;
    }
    if (!mqtt_send_control_reply(state,
                                 control,
                                 state->pending_value,
                                 accepted,
                                 tx_kind,
                                 0,
                                 0u,
                                 tx_scratch,
                                 tx_capacity,
                                 actions,
                                 &count)) {
        return 0u;
    }
    if (accepted == 0u) {
        state->pending_request_id = 0u;
    }
    return count;
}

static uint8_t mqtt_handle_move(SessionState *state,
                                const SessionEvent *event,
                                SessionWorkspace *workspace,
                                uint8_t *tx_scratch,
                                uint8_t tx_capacity,
                                SessionAction *actions)
{
    char ply_text[6];
    char move[6];
    const uint8_t *move_ptr;
    uint16_t ply;
    uint8_t count = 0u;
    uint8_t move_length;

    if ((event->data.rx.flags & SESSION_RX_LIVE) == 0u ||
        (event->data.rx.flags & SESSION_RX_RETAINED) != 0u ||
        !netchess_proto_parse_move((const char *)event->data.rx.payload,
                                   ply_text,
                                   sizeof(ply_text),
                                   move,
                                   sizeof(move),
                                   0,
                                   0u)) {
        return 0u;
    }
    ply = mqtt_parse_u16(ply_text);
    if (ply == 0u) {
        return 0u;
    }
    if (state->last_rx_kind == SESSION_REQUEST_MOVE &&
        state->last_value == ply) {
        return mqtt_send_move_reply(
                   state,
                   ply,
                   state->last_result == SESSION_GAME_ACCEPTED
                       ? 0
                       : mqtt_reason_reject,
                   state->last_result == SESSION_GAME_ACCEPTED ? 0u : 6u,
                   (uint8_t)(state->last_result == SESSION_GAME_ACCEPTED),
                   tx_scratch,
                   tx_capacity,
                   actions,
                   &count)
                   ? count
                   : 0u;
    }
    if (ply <= state->current_ply) {
        return mqtt_send_move_reply(state,
                                    ply,
                                    0,
                                    0u,
                                    1u,
                                    tx_scratch,
                                    tx_capacity,
                                    actions,
                                    &count)
                   ? count
                   : 0u;
    }
    if (state->pending_request_id != 0u ||
        state->phase != SESSION_PHASE_ACTIVE) {
        return 0u;
    }
    if (state->pending_control == SESSION_REQUEST_MOVE &&
        state->pending_origin == MQTT_ORIGIN_LOCAL &&
        ply == (uint16_t)(state->pending_value + 1u)) {
        if (!mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_CONTROL) ||
            !mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_LOCAL_MOVE,
                            0u,
                            state->pending_value,
                            (const uint8_t *)workspace->move,
                            mqtt_text_length(workspace->move))) {
            return 0u;
        }
        state->current_ply = state->pending_value;
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        session_clear_duplicate(state);
    } else if (state->pending_control != 0u) {
        static const uint8_t busy[] = "BUSY";

        return mqtt_send_move_reply(state,
                                    ply,
                                    busy,
                                    4u,
                                    0u,
                                    tx_scratch,
                                    tx_capacity,
                                    actions,
                                    &count)
                   ? count
                   : 0u;
    }
    if (ply != (uint16_t)(state->current_ply + 1u)) {
        return mqtt_send_move_reply(state,
                                    ply,
                                    mqtt_reason_sync,
                                    4u,
                                    0u,
                                    tx_scratch,
                                    tx_capacity,
                                    actions,
                                    &count)
                   ? count
                   : 0u;
    }
    move_ptr = event->data.rx.payload + 5u;
    while (*move_ptr >= '0' && *move_ptr <= '9') {
        ++move_ptr;
    }
    ++move_ptr;
    move_length = mqtt_text_length(move);
    state->pending_request_id = session_next_delivery_id(state);
    state->pending_control = SESSION_REQUEST_MOVE;
    state->pending_origin = MQTT_ORIGIN_REMOTE;
    state->pending_value = ply;
    state->control_retries = 0u;
    if (!mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_LIVENESS) ||
        !mqtt_emit_game(actions,
                        &count,
                        SESSION_DELIVER_REMOTE_MOVE,
                        state->delivery_id,
                        ply,
                        move_ptr,
                        move_length) ||
        !mqtt_emit_timer_set(state,
                             actions,
                             &count,
                             SESSION_TIMER_CONTROL,
                             MQTT_REPLY_TICKS)) {
        return 0u;
    }
    return count;
}

static uint8_t mqtt_handle_numeric_reply(SessionState *state,
                                         const SessionEvent *event,
                                         SessionWorkspace *workspace,
                                         SessionAction *actions)
{
    char value_text[6];
    char detail[16];
    const uint8_t *detail_ptr;
    uint16_t value;
    uint8_t count = 0u;
    uint8_t detail_length;
    uint8_t accepted;

    if ((event->data.rx.flags & SESSION_RX_LIVE) == 0u ||
        (event->data.rx.flags & SESSION_RX_RETAINED) != 0u) {
        return 0u;
    }
    accepted = netchess_proto_parse_ack(
        (const char *)event->data.rx.payload,
        value_text,
        sizeof(value_text),
        detail,
        sizeof(detail));
    if (accepted == 0u &&
        !netchess_proto_parse_nack((const char *)event->data.rx.payload,
                                   value_text,
                                   sizeof(value_text),
                                   detail,
                                   sizeof(detail))) {
        return 0u;
    }
    value = mqtt_parse_u16(value_text);
    if (value == 0u || state->pending_origin != MQTT_ORIGIN_LOCAL ||
        state->pending_request_id != 0u || value != state->pending_value) {
        return 0u;
    }
    if (state->pending_control == SESSION_REQUEST_TAKEBACK) {
        if (!mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        if (accepted != 0u) {
            state->pending_request_id = session_next_delivery_id(state);
            if (!mqtt_emit_game(actions,
                                &count,
                                SESSION_DELIVER_TAKEBACK,
                                state->delivery_id,
                                value,
                                0,
                                0u) ||
                !mqtt_emit_timer_set(state,
                                     actions,
                                     &count,
                                     SESSION_TIMER_LIVENESS,
                                     MQTT_LIVENESS_TICKS) ||
                !mqtt_emit_timer_set(state,
                                     actions,
                                     &count,
                                     SESSION_TIMER_CONTROL,
                                     MQTT_REPLY_TICKS)) {
                return 0u;
            }
            return count;
        }
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        if (!mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_CONTROL_RESULT,
                            SESSION_CONTROL_REJECTED,
                            SESSION_REQUEST_TAKEBACK,
                            event->data.rx.payload,
                            event->data.rx.length) ||
            !mqtt_emit_timer_set(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_LIVENESS,
                                 MQTT_LIVENESS_TICKS)) {
            return 0u;
        }
        return count;
    }
    if (state->pending_control != SESSION_REQUEST_MOVE) {
        return 0u;
    }
    if (accepted == 0u && mqtt_text_equal((const uint8_t *)detail,
                                          mqtt_text_length(detail),
                                          "BUSY")) {
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_CONTROL,
                                   MQTT_REPLY_TICKS)
                   ? count
                   : 0u;
    }
    if (!mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_CONTROL)) {
        return 0u;
    }
    state->pending_control = 0u;
    state->pending_origin = MQTT_ORIGIN_NONE;
    if (accepted != 0u) {
        state->current_ply = value;
        session_clear_duplicate(state);
        detail_ptr = event->data.rx.payload + 4u;
        while (detail_ptr < event->data.rx.payload + event->data.rx.length &&
               *detail_ptr >= '0' && *detail_ptr <= '9') {
            ++detail_ptr;
        }
        if (detail_ptr < event->data.rx.payload + event->data.rx.length &&
            *detail_ptr == ' ') {
            ++detail_ptr;
        }
        detail_length = (uint8_t)((event->data.rx.payload +
                                   event->data.rx.length) - detail_ptr);
        if (!mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_LOCAL_MOVE,
                            0u,
                            value,
                            (const uint8_t *)workspace->move,
                            mqtt_text_length(workspace->move)) ||
            !mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_CONTROL_RESULT,
                            SESSION_CONTROL_ACCEPTED,
                            SESSION_REQUEST_MOVE,
                            detail_ptr,
                            detail_length)) {
            return 0u;
        }
    } else if (!mqtt_emit_game(actions,
                               &count,
                               SESSION_DELIVER_CONTROL_RESULT,
                               SESSION_CONTROL_REJECTED,
                               SESSION_REQUEST_MOVE,
                               event->data.rx.payload,
                               event->data.rx.length)) {
        return 0u;
    }
    return mqtt_emit_timer_set(state,
                               actions,
                               &count,
                               SESSION_TIMER_LIVENESS,
                               MQTT_LIVENESS_TICKS)
               ? count
               : 0u;
}

static uint8_t mqtt_handle_ping(SessionState *state,
                                const SessionEvent *event,
                                uint8_t *tx_scratch,
                                uint8_t tx_capacity,
                                SessionAction *actions)
{
    const uint8_t *payload = event->data.rx.payload;
    uint8_t count = 0u;

    if (state->peer_ready == 0u ||
        (event->data.rx.flags & SESSION_RX_LIVE) == 0u ||
        (event->data.rx.flags & SESSION_RX_RETAINED) != 0u) {
        return 0u;
    }
    if (mqtt_text_equal(payload, event->data.rx.length, "ACK PING")) {
        if (state->liveness_misses == 0u ||
            !mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_LIVENESS) ||
            !mqtt_emit_timer_set(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_LIVENESS,
                                 MQTT_LIVENESS_TICKS)) {
            return 0u;
        }
        return count;
    }
    if (!mqtt_text_equal(payload, event->data.rx.length, "PING")) {
        return 0u;
    }
    state->liveness_misses = 0u;
    if (!mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_LIVENESS) ||
        !mqtt_send_text(state,
                        "ACK PING",
                        SESSION_ROUTE_ACK,
                        0u,
                        MQTT_TX_TRANSIENT_REPLY,
                        tx_scratch,
                        tx_capacity,
                        actions,
                        &count)) {
        return 0u;
    }
    return count;
}

static uint8_t mqtt_handle_restore_request(SessionState *state,
                                           const SessionEvent *event,
                                           uint8_t *tx_scratch,
                                           uint8_t tx_capacity,
                                           SessionAction *actions)
{
    const uint8_t *payload = event->data.rx.payload;
    uint8_t length = event->data.rx.length;
    uint8_t count = 0u;

    if ((event->data.rx.flags & SESSION_RX_LIVE) == 0u ||
        (event->data.rx.flags & SESSION_RX_RETAINED) != 0u) {
        return 0u;
    }
    if (mqtt_text_equal(payload, length, "RQ")) {
        if (state->config.role == SESSION_ROLE_HOST) {
            return mqtt_send_text(state, "RN", SESSION_ROUTE_GAME, 0u,
                                  MQTT_TX_TRANSIENT_REPLY, tx_scratch,
                                  tx_capacity, actions, &count)
                       ? count : 0u;
        }
        if (!state->peer_ready || state->phase < SESSION_PHASE_READY ||
            state->phase > SESSION_PHASE_OVER) {
            return 0u;
        }
        session_drop_restore_cache(state);
        if (state->pending_control == SESSION_REQUEST_RESTORE &&
            state->pending_origin == MQTT_ORIGIN_REMOTE) {
            if (state->pending_request_id != 0u) {
                return 0u;
            }
            if (state->restore_phase == MQTT_RESTORE_RECEIVE) {
                return mqtt_send_text(state, "RY", SESSION_ROUTE_GAME, 0u,
                                      MQTT_TX_TRANSIENT_REPLY, tx_scratch,
                                      tx_capacity, actions, &count)
                           ? count : 0u;
            }
        }
        if (state->pending_control != 0u ||
            state->pending_request_id != 0u) {
            return mqtt_send_text(state, "RN", SESSION_ROUTE_GAME, 0u,
                                  MQTT_TX_TRANSIENT_REPLY, tx_scratch,
                                  tx_capacity, actions, &count)
                       ? count : 0u;
        }
        return mqtt_begin_decision(state, SESSION_REQUEST_RESTORE, 0u,
                                   tx_scratch, tx_capacity, actions);
    }
    return MQTT_RX_UNHANDLED;
}

static uint8_t mqtt_handle_restore_reply(SessionState *state,
                                         const SessionEvent *event,
                                         SessionWorkspace *workspace,
                                         uint8_t *tx_scratch,
                                         uint8_t tx_capacity,
                                         SessionAction *actions)
{
    const uint8_t *payload = event->data.rx.payload;
    uint8_t length = event->data.rx.length;
    uint8_t count = 0u;

    if (mqtt_text_equal(payload, length, "RY") &&
        state->restore_phase == MQTT_RESTORE_WAIT_RY &&
        state->pending_control == SESSION_REQUEST_RESTORE &&
        state->pending_origin == MQTT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u) {
        if (!mqtt_emit_timer_cancel(state, actions, &count,
                                    SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->restore_phase = MQTT_RESTORE_WAIT_RA;
        state->control_retries = 0u;
        return mqtt_send_restore_chunk(state, workspace, 0u, tx_scratch,
                                       tx_capacity, actions, &count)
                   ? count : 0u;
    }
    if (mqtt_text_equal(payload, length, "RN") &&
        state->pending_control == SESSION_REQUEST_RESTORE &&
        ((state->pending_origin == MQTT_ORIGIN_REMOTE &&
          (state->pending_request_id != 0u ||
           state->restore_phase == MQTT_RESTORE_RECEIVE)) ||
         (state->pending_origin == MQTT_ORIGIN_LOCAL &&
          state->pending_request_id == 0u))) {
        if (!mqtt_emit_timer_cancel(state, actions, &count,
                                    SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        state->restore_phase = MQTT_RESTORE_NONE;
        state->restore_mask = 0u;
        session_clear_duplicate(state);
        if (!mqtt_emit_game(actions, &count,
                            SESSION_DELIVER_CONTROL_RESULT,
                            SESSION_CONTROL_REJECTED,
                            SESSION_REQUEST_RESTORE, payload, length) ||
            !mqtt_emit_timer_set(state, actions, &count,
                                 SESSION_TIMER_LIVENESS,
                                 MQTT_LIVENESS_TICKS)) {
            return 0u;
        }
        return count;
    }
    if (mqtt_text_equal(payload, length, "RA") &&
        state->restore_phase == MQTT_RESTORE_WAIT_RA &&
        state->pending_control == SESSION_REQUEST_RESTORE &&
        state->pending_origin == MQTT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u) {
        mqtt_emit_timer_cancel(state, actions, &count, SESSION_TIMER_CONTROL);
        state->phase =
            (uint8_t)(state->restore_mask >> MQTT_RESTORE_PHASE_SHIFT);
        state->current_ply = state->pending_value;
        mqtt_emit_game(actions, &count, SESSION_DELIVER_RESTORE, 0u,
                       state->current_ply, workspace->restore,
                       SESSION_RESTORE_BYTES);
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_value = 0u;
        state->restore_phase = MQTT_RESTORE_NONE;
        state->restore_mask = 0u;
        session_clear_duplicate(state);
        mqtt_emit_timer_set(state, actions, &count, SESSION_TIMER_LIVENESS,
                            MQTT_LIVENESS_TICKS);
        return count;
    }
    return MQTT_RX_UNHANDLED;
}

static uint8_t mqtt_handle_restore_chunk(SessionState *state,
                                         const SessionEvent *event,
                                         SessionWorkspace *workspace,
                                         uint8_t *tx_scratch,
                                         uint8_t tx_capacity,
                                         SessionAction *actions)
{
    const uint8_t *payload = event->data.rx.payload;
    uint8_t length = event->data.rx.length;
    uint8_t count = 0u;

    if (length == 35u &&
        (mqtt_text_prefix(payload, length, "RS00 ") ||
         mqtt_text_prefix(payload, length, "RS01 ")) &&
        state->restore_phase == MQTT_RESTORE_APPLIED) {
        uint8_t chunk = (uint8_t)(payload[3] - '0');

        if (!session_restore_chunk_matches(workspace, payload, chunk)) {
            state->restore_phase = MQTT_RESTORE_NONE;
            state->restore_mask = 0u;
            session_clear_duplicate(state);
            return mqtt_send_text(state, "RN", SESSION_ROUTE_GAME, 0u,
                                  MQTT_TX_TRANSIENT_REPLY, tx_scratch,
                                  tx_capacity, actions, &count)
                       ? count : 0u;
        }
        return mqtt_send_text(state, "RA", SESSION_ROUTE_GAME, 0u,
                              MQTT_TX_RA, tx_scratch, tx_capacity,
                              actions, &count)
                   ? count : 0u;
    }
    if (length == 35u &&
        (mqtt_text_prefix(payload, length, "RS00 ") ||
         mqtt_text_prefix(payload, length, "RS01 ")) &&
        state->restore_phase == MQTT_RESTORE_RECEIVE) {
        uint8_t chunk = (uint8_t)(payload[3] - '0');

        if (state->pending_request_id != 0u) {
            if (!session_restore_chunk_matches(workspace, payload, chunk)) {
                return 0u;
            }
            return mqtt_emit_timer_set(state, actions, &count,
                                       SESSION_TIMER_CONTROL,
                                       MQTT_REPLY_TICKS)
                       ? count : 0u;
        }
        session_store_restore_chunk(workspace, payload, chunk);
        state->control_retries = 0u;
        state->restore_mask |= (uint8_t)(1u << chunk);
        if ((state->restore_mask & MQTT_RESTORE_CHUNK_MASK) ==
                MQTT_RESTORE_CHUNK_MASK &&
            state->pending_request_id == 0u) {
            state->pending_request_id = session_next_delivery_id(state);
            if (!mqtt_emit_game(actions, &count, SESSION_DELIVER_RESTORE,
                                state->delivery_id, 0u, workspace->restore,
                                SESSION_RESTORE_BYTES)) {
                return 0u;
            }
        }
        mqtt_emit_timer_set(state, actions, &count, SESSION_TIMER_CONTROL,
                            MQTT_REPLY_TICKS);
        return count;
    }
    if (length == 35u &&
        (mqtt_text_prefix(payload, length, "RS00 ") ||
         mqtt_text_prefix(payload, length, "RS01 "))) {
        return mqtt_send_text(state, "RN", SESSION_ROUTE_GAME, 0u,
                              MQTT_TX_TRANSIENT_REPLY, tx_scratch,
                              tx_capacity, actions, &count)
                   ? count : 0u;
    }
    return MQTT_RX_UNHANDLED;
}

static uint8_t mqtt_handle_restore(SessionState *state,
                                   const SessionEvent *event,
                                   SessionWorkspace *workspace,
                                   uint8_t *tx_scratch,
                                   uint8_t tx_capacity,
                                   SessionAction *actions)
{
    uint8_t result;

    result = mqtt_handle_restore_request(state, event, tx_scratch,
                                         tx_capacity, actions);
    if (result != MQTT_RX_UNHANDLED) {
        return result;
    }
    result = mqtt_handle_restore_reply(state, event, workspace, tx_scratch,
                                       tx_capacity, actions);
    if (result != MQTT_RX_UNHANDLED) {
        return result;
    }
    result = mqtt_handle_restore_chunk(state, event, workspace, tx_scratch,
                                       tx_capacity, actions);
    return result != MQTT_RX_UNHANDLED ? result : 0u;
}

static uint8_t mqtt_handle_rx(SessionState *state,
                              const SessionEvent *event,
                              SessionWorkspace *workspace,
                              uint8_t *tx_scratch,
                              uint8_t tx_capacity,
                              SessionAction *actions)
{
    const uint8_t *payload = event->data.rx.payload;
    const char *takeback;
    uint16_t value;
    uint8_t count = 0u;
    uint8_t timer_id;

    if (state->link_up == 0u ||
        event->data.rx.link_id != state->active_link ||
        !mqtt_slice_valid(payload, event->data.rx.length)) {
        return 0u;
    }
    if (state->peer_ready != 0u &&
        (event->data.rx.flags & SESSION_RX_LIVE) != 0u &&
        (event->data.rx.flags & SESSION_RX_RETAINED) == 0u &&
        mqtt_text_equal(payload, event->data.rx.length, "BYE")) {
        if (state->config.role == SESSION_ROLE_HOST) {
            for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
                if (!mqtt_emit_timer_cancel(state,
                                            actions,
                                            &count,
                                            timer_id)) {
                    return 0u;
                }
            }
            return mqtt_send_side(
                       state,
                       state->local_color == SESSION_COLOR_WHITE
                           ? SESSION_COLOR_BLACK : SESSION_COLOR_WHITE,
                       NETCHESS_MQTT_SESSION_VERB_OFFLINE,
                       1u,
                       MQTT_TX_PEER_OFFLINE_WAIT,
                       tx_scratch,
                       tx_capacity,
                       actions,
                       &count)
                       ? count : 0u;
        }
        return mqtt_wait_for_peer(state, actions, 0u);
    }
    if (state->pending_tx_kind != MQTT_TX_NONE) {
        if (mqtt_text_prefix(payload, event->data.rx.length, "CHAT ")) {
            return mqtt_handle_chat(state, event, actions, 0u);
        }
        return 0u;
    }
    if (event->data.rx.length >= 2u && payload[1] == ' ') {
        if (payload[0] == NETCHESS_MQTT_SESSION_VERB_HOST) {
            return mqtt_handle_host(state,
                                    event,
                                    tx_scratch,
                                    tx_capacity,
                                    actions);
        }
        if (payload[0] == NETCHESS_MQTT_SESSION_VERB_JOIN) {
            return mqtt_handle_join(state,
                                    event,
                                    tx_scratch,
                                    tx_capacity,
                                    actions);
        }
        if (payload[0] == NETCHESS_MQTT_SESSION_VERB_ONLINE) {
            return mqtt_handle_online(state, event, actions);
        }
        if (payload[0] == NETCHESS_MQTT_SESSION_VERB_OFFLINE) {
            return mqtt_handle_offline(state,
                                       event,
                                       tx_scratch,
                                       tx_capacity,
                                       actions);
        }
    }
    if (netchess_proto_parse_game_start((const char *)payload, 0, 0u)) {
        return mqtt_handle_game_start(state,
                                      event,
                                      tx_scratch,
                                      tx_capacity,
                                      actions);
    }
    if (mqtt_text_equal(payload,
                        event->data.rx.length,
                        "ACK GAME START") ||
        mqtt_text_prefix(payload,
                         event->data.rx.length,
                         "NACK GAME START")) {
        return mqtt_handle_start_reply(state, event, actions);
    }
    if (mqtt_text_prefix(payload, event->data.rx.length, "CHAT ")) {
        return mqtt_handle_chat(state, event, actions, 1u);
    }
    if (mqtt_text_equal(payload, event->data.rx.length, "RQ") ||
        mqtt_text_equal(payload, event->data.rx.length, "RY") ||
        mqtt_text_equal(payload, event->data.rx.length, "RN") ||
        mqtt_text_equal(payload, event->data.rx.length, "RA") ||
        (event->data.rx.length == 35u &&
         (mqtt_text_prefix(payload, event->data.rx.length, "RS00 ") ||
          mqtt_text_prefix(payload, event->data.rx.length, "RS01 ")))) {
        return mqtt_handle_restore(state, event, workspace, tx_scratch,
                                   tx_capacity, actions);
    }
    if (mqtt_text_equal(payload, event->data.rx.length, "PING") ||
        mqtt_text_equal(payload, event->data.rx.length, "ACK PING")) {
        return mqtt_handle_ping(state,
                                event,
                                tx_scratch,
                                tx_capacity,
                                actions);
    }
    if (mqtt_text_prefix(payload, event->data.rx.length, "MOVE ")) {
        if (event->data.rx.route != SESSION_ROUTE_GAME) {
            return 0u;
        }
        return mqtt_handle_move(state,
                                event,
                                workspace,
                                tx_scratch,
                                tx_capacity,
                                actions);
    }
    if ((event->data.rx.flags & SESSION_RX_LIVE) != 0u &&
        (event->data.rx.flags & SESSION_RX_RETAINED) == 0u) {
        if (mqtt_text_equal(payload, event->data.rx.length,
                            NETCHESS_PROTO_CANCEL_RESET) ||
            mqtt_text_equal(payload, event->data.rx.length,
                            NETCHESS_PROTO_CANCEL_DRAW)) {
            uint8_t control = payload[7] == 'R' ? SESSION_REQUEST_RESET
                                                : SESSION_REQUEST_DRAW;
            uint8_t matched = (uint8_t)(
                state->pending_control == control &&
                state->pending_origin == MQTT_ORIGIN_REMOTE &&
                state->pending_request_id != 0u);

            if (matched) {
                state->pending_request_id = 0u;
                state->pending_value = MQTT_CANCEL_REMOTE;
            }
            return mqtt_send_control_reply(
                       state, control, 0u, 0u,
                       matched ? (control == SESSION_REQUEST_RESET
                                      ? MQTT_TX_NACK_RESET
                                      : MQTT_TX_NACK_DRAW)
                               : MQTT_TX_TRANSIENT_REPLY,
                       0, 0u, tx_scratch, tx_capacity, actions, &count)
                       ? count : 0u;
        }
        if (mqtt_text_equal(payload, event->data.rx.length, "RESET")) {
            return mqtt_begin_decision(state,
                                       SESSION_REQUEST_RESET,
                                       0u,
                                       tx_scratch,
                                       tx_capacity,
                                       actions);
        }
        if (mqtt_text_equal(payload, event->data.rx.length, "DRAW")) {
            return mqtt_begin_decision(state,
                                       SESSION_REQUEST_DRAW,
                                       0u,
                                       tx_scratch,
                                       tx_capacity,
                                       actions);
        }
        if (mqtt_text_equal(payload, event->data.rx.length, "RESIGN")) {
            return mqtt_handle_resign(state,
                                      tx_scratch,
                                      tx_capacity,
                                      actions);
        }
        takeback = netchess_after_prefix((const char *)payload,
                                         "TAKEBACK ");
        if (takeback != 0) {
            value = mqtt_parse_u16(takeback);
            if (value != 0u) {
                return mqtt_begin_decision(state,
                                           SESSION_REQUEST_TAKEBACK,
                                           value,
                                           tx_scratch,
                                           tx_capacity,
                                           actions);
            }
            return 0u;
        }
    }
    if (mqtt_text_equal(payload, event->data.rx.length, "ACK RESET") ||
        mqtt_text_equal(payload, event->data.rx.length, "ACK DRAW") ||
        mqtt_text_equal(payload, event->data.rx.length, "ACK RESIGN") ||
        mqtt_text_prefix(payload, event->data.rx.length, "NACK RESET") ||
        mqtt_text_prefix(payload, event->data.rx.length, "NACK DRAW")) {
        return mqtt_handle_control_reply(state,
                                         event,
                                         tx_scratch,
                                         tx_capacity,
                                         actions);
    }
    if (mqtt_text_prefix(payload, event->data.rx.length, "ACK ") ||
        mqtt_text_prefix(payload, event->data.rx.length, "NACK ")) {
        return mqtt_handle_numeric_reply(state, event, workspace, actions);
    }
    return 0u;
}

static uint8_t mqtt_handle_local(SessionState *state,
                                 const SessionEvent *event,
                                 SessionWorkspace *workspace,
                                 uint8_t *tx_scratch,
                                 uint8_t tx_capacity,
                                 SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t i;
    uint8_t timer_id;

    if (event->data.local.request == SESSION_REQUEST_RESTORE &&
        event->data.local.length == 0u) {
        if (state->pending_control != SESSION_REQUEST_RESTORE ||
            state->pending_origin != MQTT_ORIGIN_LOCAL ||
            state->pending_tx_kind != MQTT_TX_NONE ||
            state->restore_phase != MQTT_RESTORE_WAIT_RY ||
            !mqtt_emit_timer_cancel(state, actions, &count,
                                    SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        return mqtt_send_text(state, "RN", SESSION_ROUTE_GAME, 0u,
                              MQTT_TX_RN, tx_scratch, tx_capacity,
                              actions, &count)
                   ? count : 0u;
    }
    if (event->data.local.request == SESSION_REQUEST_BYE) {
        if (state->link_up == 0u ||
            state->pending_tx_kind != MQTT_TX_NONE ||
            tx_capacity < 4u) {
            return 0u;
        }
        for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
            if (!mqtt_emit_timer_cancel(state,
                                        actions,
                                        &count,
                                        timer_id)) {
                return 0u;
            }
        }
        state->pending_control = SESSION_REQUEST_BYE;
        state->pending_origin = MQTT_ORIGIN_LOCAL;
        state->pending_request_id = 0u;
        state->control_retries = 0u;
        return mqtt_send_text(state,
                              "BYE",
                              SESSION_ROUTE_CONTROL,
                              0u,
                              MQTT_TX_BYE,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              &count)
                   ? count
                   : 0u;
    }
    if (event->data.local.request == SESSION_REQUEST_RESIGN &&
        state->pending_control == SESSION_REQUEST_MOVE &&
        state->pending_origin == MQTT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u &&
        state->pending_tx_kind == MQTT_TX_NONE) {
        if (!mqtt_emit_timer_cancel(state, actions, &count,
                                    SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_value = 0u;
    }

    if (state->peer_ready == 0u ||
        state->pending_tx_kind != MQTT_TX_NONE ||
        (state->pending_control != 0u &&
         event->data.local.request != SESSION_REQUEST_CHAT)) {
        return 0u;
    }
    if (event->data.local.request == SESSION_REQUEST_CHAT) {
        if (state->pending_control == SESSION_REQUEST_MOVE ||
            state->pending_control == SESSION_REQUEST_RESTORE ||
            event->data.local.length > SESSION_CHAT_TEXT_MAX ||
            !mqtt_slice_valid(event->data.local.payload,
                              event->data.local.length) ||
            !netchess_proto_format_chat(
                (char *)tx_scratch,
                tx_capacity,
                (const char *)event->data.local.payload) ||
            !mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        session_drop_restore_cache(state);
        for (i = 0u; i <= event->data.local.length; ++i) {
            workspace->chat[i] = (char)event->data.local.payload[i];
        }
        return mqtt_send_buffer(state,
                                tx_scratch,
                                tx_capacity,
                                actions,
                                &count,
                                SESSION_ROUTE_GAME,
                                0u,
                                MQTT_TX_CHAT)
                   ? count
                   : 0u;
    }
    if (event->data.local.request == SESSION_REQUEST_MOVE) {
        if (state->phase != SESSION_PHASE_ACTIVE ||
            !mqtt_slice_valid(event->data.local.payload,
                              event->data.local.length) ||
            state->current_ply == 65535u ||
            (event->data.local.length != 4u &&
             event->data.local.length != 5u)) {
            return 0u;
        }
        if (!mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        session_drop_restore_cache(state);
        for (i = 0u; i < event->data.local.length; ++i) {
            workspace->move[i] = (char)event->data.local.payload[i];
        }
        workspace->move[event->data.local.length] = '\0';
        state->pending_control = SESSION_REQUEST_MOVE;
        state->pending_origin = MQTT_ORIGIN_LOCAL;
        state->pending_value = (uint16_t)(state->current_ply + 1u);
        state->control_retries = 0u;
        if (mqtt_send_move(state,
                           workspace,
                           tx_scratch,
                           tx_capacity,
                           actions,
                           &count)) {
            return count;
        }
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        return 0u;
    }
    if (event->data.local.request == SESSION_REQUEST_START) {
        if (state->config.role != SESSION_ROLE_HOST ||
            state->phase != SESSION_PHASE_READY ||
            !mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        state->pending_control = SESSION_REQUEST_START;
        state->pending_origin = MQTT_ORIGIN_LOCAL;
        state->control_retries = 0u;
        if (mqtt_send_text(state,
                           "GAME START",
                           SESSION_ROUTE_CONTROL,
                           0u,
                           MQTT_TX_START,
                           tx_scratch,
                           tx_capacity,
                           actions,
                           &count)) {
            return count;
        }
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        return 0u;
    }
    if (event->data.local.request == SESSION_REQUEST_RESTORE) {
        if (state->config.role != SESSION_ROLE_HOST ||
            event->data.local.length != SESSION_RESTORE_BYTES ||
            event->data.local.phase < SESSION_PHASE_READY ||
            event->data.local.phase > SESSION_PHASE_OVER ||
            !mqtt_fixed_slice_valid(event->data.local.payload,
                                    event->data.local.length) ||
            !mqtt_emit_timer_cancel(state, actions, &count,
                                    SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        session_drop_restore_cache(state);
        for (i = 0u; i < SESSION_RESTORE_BYTES; ++i) {
            workspace->restore[i] = event->data.local.payload[i];
        }
        state->pending_control = SESSION_REQUEST_RESTORE;
        state->pending_origin = MQTT_ORIGIN_LOCAL;
        state->pending_value = event->data.local.value;
        state->restore_phase = MQTT_RESTORE_WAIT_RY;
        state->restore_mask = (uint8_t)(
            event->data.local.phase << MQTT_RESTORE_PHASE_SHIFT);
        state->control_retries = 0u;
        if (mqtt_send_local_pending(state, workspace, tx_scratch,
                                    tx_capacity, actions, &count)) {
            return count;
        }
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_value = 0u;
        state->restore_phase = MQTT_RESTORE_NONE;
        state->restore_mask = 0u;
        return 0u;
    }
    if ((event->data.local.request == SESSION_REQUEST_RESET &&
         state->phase != SESSION_PHASE_ACTIVE &&
         state->phase != SESSION_PHASE_OVER) ||
        ((event->data.local.request == SESSION_REQUEST_DRAW ||
          event->data.local.request == SESSION_REQUEST_RESIGN ||
          event->data.local.request == SESSION_REQUEST_TAKEBACK) &&
         state->phase != SESSION_PHASE_ACTIVE) ||
        (event->data.local.request != SESSION_REQUEST_RESET &&
         event->data.local.request != SESSION_REQUEST_DRAW &&
         event->data.local.request != SESSION_REQUEST_RESIGN &&
         event->data.local.request != SESSION_REQUEST_TAKEBACK) ||
        (event->data.local.request == SESSION_REQUEST_TAKEBACK &&
         event->data.local.value == 0u) ||
        !mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_LIVENESS)) {
        return 0u;
    }
    state->pending_control = event->data.local.request;
    state->pending_origin = MQTT_ORIGIN_LOCAL;
    state->pending_value = event->data.local.value;
    state->control_retries = 0u;
    if (mqtt_send_local_pending(state,
                                workspace,
                                tx_scratch,
                                tx_capacity,
                                actions,
                                &count)) {
        return count;
    }
    state->pending_control = 0u;
    state->pending_origin = MQTT_ORIGIN_NONE;
    return 0u;
}

static uint8_t mqtt_handle_game_result(SessionState *state,
                                       const SessionEvent *event,
                                       uint8_t *tx_scratch,
                                       uint8_t tx_capacity,
                                       SessionAction *actions)
{
    const uint8_t *detail = mqtt_reason_reject;
    uint8_t detail_length = 6u;
    uint8_t accepted;
    uint8_t count = 0u;

    if (state->pending_tx_kind != MQTT_TX_NONE ||
        state->pending_request_id == 0u ||
        (state->pending_control != SESSION_REQUEST_MOVE &&
         state->pending_control != SESSION_REQUEST_TAKEBACK &&
         state->pending_control != SESSION_REQUEST_RESTORE) ||
        (state->pending_control == SESSION_REQUEST_MOVE &&
         state->pending_origin != MQTT_ORIGIN_REMOTE) ||
        (state->pending_control == SESSION_REQUEST_RESTORE &&
         (state->pending_origin != MQTT_ORIGIN_REMOTE ||
          state->restore_phase != MQTT_RESTORE_RECEIVE)) ||
        event->data.game.delivery_id != state->pending_request_id ||
        (state->pending_control != SESSION_REQUEST_RESTORE &&
         event->data.game.value != state->pending_value) ||
        event->data.game.result < SESSION_GAME_ACCEPTED ||
        event->data.game.result > SESSION_GAME_FAILED) {
        return 0u;
    }
    accepted = (uint8_t)(event->data.game.result == SESSION_GAME_ACCEPTED);
    if (state->pending_control == SESSION_REQUEST_RESTORE && accepted != 0u) {
        if (event->data.game.detail == 0 ||
            event->data.game.detail_length != 1u ||
            event->data.game.detail[0] < SESSION_PHASE_READY ||
            event->data.game.detail[0] > SESSION_PHASE_OVER) {
            return 0u;
        }
    } else if (event->data.game.detail_length != 0u &&
               !mqtt_slice_valid(event->data.game.detail,
                                 event->data.game.detail_length)) {
        return 0u;
    }
    if (event->data.game.detail_length != 0u) {
        detail = event->data.game.detail;
        detail_length = event->data.game.detail_length;
    } else if (accepted != 0u) {
        detail = 0;
        detail_length = 0u;
    }
    if (state->pending_control != SESSION_REQUEST_RESTORE &&
        state->pending_origin == MQTT_ORIGIN_REMOTE &&
        !mqtt_prepare_reply(state, actions, &count)) {
        return 0u;
    }
    if (!mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_CONTROL)) {
        return 0u;
    }
    if (state->pending_control == SESSION_REQUEST_MOVE) {
        if (accepted != 0u) {
            state->current_ply = state->pending_value;
        }
        state->last_rx_kind = SESSION_REQUEST_MOVE;
        state->last_value = state->pending_value;
        state->last_result = event->data.game.result;
        if (!mqtt_send_move_reply(state,
                                  state->pending_value,
                                  detail,
                                  detail_length,
                                  accepted,
                                  tx_scratch,
                                  tx_capacity,
                                  actions,
                                  &count)) {
            return 0u;
        }
        state->pending_request_id = 0u;
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        return count;
    }
    if (state->pending_control == SESSION_REQUEST_RESTORE) {
        if (accepted != 0u) {
            state->phase = event->data.game.detail[0];
            state->pending_value = event->data.game.value;
            state->current_ply = event->data.game.value;
        }
        if (!mqtt_send_text(state,
                            accepted != 0u ? "RA" : "RN",
                            SESSION_ROUTE_GAME,
                            0u,
                            accepted != 0u ? MQTT_TX_RA : MQTT_TX_RN,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            &count)) {
            return 0u;
        }
        state->last_rx_kind = SESSION_REQUEST_RESTORE;
        state->last_result = event->data.game.result;
        return count;
    }
    if (accepted != 0u) {
        state->current_ply = state->pending_value == 0u
                                 ? 0u
                                 : (uint16_t)(state->pending_value - 1u);
        session_clear_duplicate(state);
    }
    if (state->pending_origin == MQTT_ORIGIN_REMOTE) {
        state->last_rx_kind = SESSION_REQUEST_TAKEBACK;
        state->last_value = state->pending_value;
        state->last_result = event->data.game.result;
        if (!mqtt_send_takeback_reply(
                state,
                state->pending_value,
                detail,
                detail_length,
                accepted,
                accepted != 0u
                    ? MQTT_TX_ACK_TAKEBACK
                    : MQTT_TX_NACK_TAKEBACK,
                tx_scratch,
                tx_capacity,
                actions,
                &count)) {
            return 0u;
        }
        state->pending_request_id = 0u;
        return count;
    }
    state->pending_request_id = 0u;
    state->pending_control = 0u;
    state->pending_origin = MQTT_ORIGIN_NONE;
    if (!mqtt_emit_game(actions,
                        &count,
                        SESSION_DELIVER_CONTROL_RESULT,
                        accepted != 0u
                            ? SESSION_CONTROL_ACCEPTED
                            : SESSION_CONTROL_REJECTED,
                        SESSION_REQUEST_TAKEBACK,
                        accepted != 0u ? 0 : detail,
                        accepted != 0u ? 0u : detail_length) ||
        !mqtt_emit_timer_set(state,
                             actions,
                             &count,
                             SESSION_TIMER_LIVENESS,
                             MQTT_LIVENESS_TICKS)) {
        return 0u;
    }
    return count;
}

static uint8_t mqtt_tx_ok_bootstrap(SessionState *state,
                                    uint8_t tx_kind,
                                    uint8_t *tx_scratch,
                                    uint8_t tx_capacity,
                                    SessionAction *actions,
                                    uint8_t count)
{
    switch (tx_kind) {
    case MQTT_TX_ONLINE:
        state->deferred_decision |= MQTT_STATE_OWN_ONLINE;
        if (state->config.role == SESSION_ROLE_HOST) {
            return mqtt_send_host(state,
                                  1u,
                                  MQTT_TX_HOST_RETAINED,
                                  tx_scratch,
                                  tx_capacity,
                                  actions,
                                  &count)
                       ? count
                       : 0u;
        }
        return mqtt_send_join(state,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              &count)
                   ? count
                   : 0u;
    case MQTT_TX_HOST_RETAINED:
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_CONTROL,
                                   MQTT_SETUP_TICKS)
                   ? count
                   : 0u;
    case MQTT_TX_JOIN:
    case MQTT_TX_HOST_LIVE:
        if (state->peer_ready == 0u) {
            state->peer_ready = 1u;
            state->phase = SESSION_PHASE_READY;
            if (!mqtt_emit_session(actions, &count, SESSION_CHANGED_READY) ||
                !mqtt_emit_timer_set(state,
                                     actions,
                                     &count,
                                     SESSION_TIMER_LIVENESS,
                                     MQTT_LIVENESS_TICKS) ||
                (tx_kind == MQTT_TX_JOIN &&
                 state->config.role == SESSION_ROLE_GUEST &&
                 state->phase == SESSION_PHASE_READY &&
                 state->peer_ready != 0u &&
                 !mqtt_emit_timer_set(state,
                                      actions,
                                      &count,
                                      SESSION_TIMER_CONTROL,
                                      MQTT_SETUP_TICKS))) {
                return 0u;
            }
            return count;
        }
        if (tx_kind == MQTT_TX_JOIN) {
            if (!mqtt_emit_timer_set(state,
                                     actions,
                                     &count,
                                     SESSION_TIMER_LIVENESS,
                                     MQTT_LIVENESS_TICKS) ||
                (state->config.role == SESSION_ROLE_GUEST &&
                 state->phase == SESSION_PHASE_READY &&
                 state->peer_ready != 0u &&
                 !mqtt_emit_timer_set(state,
                                      actions,
                                      &count,
                                      SESSION_TIMER_CONTROL,
                                      MQTT_SETUP_TICKS))) {
                return 0u;
            }
            return count;
        }
        return count;
    case MQTT_TX_ONLINE_REFRESH:
        return count;
    default:
        return MQTT_TX_UNHANDLED;
    }
}

static uint8_t mqtt_tx_ok_outbound(SessionState *state,
                                   SessionWorkspace *workspace,
                                   uint8_t tx_kind,
                                   SessionAction *actions,
                                   uint8_t count)
{
    switch (tx_kind) {
    case MQTT_TX_START:
    case MQTT_TX_MOVE:
    case MQTT_TX_DRAW:
    case MQTT_TX_TAKEBACK:
    case MQTT_TX_RQ:
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_CONTROL,
                                   MQTT_REPLY_TICKS)
                   ? count
                   : 0u;
    case MQTT_TX_RESET:
        if (!mqtt_emit_timer_set(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_CONTROL,
                                 MQTT_REPLY_TICKS) ||
            (state->phase == SESSION_PHASE_OVER &&
             !mqtt_emit_timer_set(state,
                                  actions,
                                  &count,
                                  SESSION_TIMER_LIVENESS,
                                  MQTT_LIVENESS_TICKS))) {
            return 0u;
        }
        return count;
    case MQTT_TX_RESIGN:
        if (state->phase != SESSION_PHASE_OVER) {
            state->phase = SESSION_PHASE_OVER;
            if (!mqtt_emit_game(actions,
                                &count,
                                SESSION_DELIVER_CONTROL,
                                0u,
                                SESSION_REQUEST_RESIGN,
                                0,
                                0u)) {
                return 0u;
            }
        }
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_CONTROL,
                                   MQTT_REPLY_TICKS)
                   ? count
                   : 0u;
    case MQTT_TX_CHAT:
        if (!mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_CHAT,
                            0u,
                            SESSION_CHAT_LOCAL,
                            (const uint8_t *)workspace->chat,
                            mqtt_text_length(workspace->chat)) ||
            (state->pending_control == 0u &&
             !mqtt_emit_timer_set(state,
                                  actions,
                                  &count,
                                  SESSION_TIMER_LIVENESS,
                                  MQTT_LIVENESS_TICKS))) {
            return 0u;
        }
        return count;
    default:
        return MQTT_TX_UNHANDLED;
    }
}

static uint8_t mqtt_tx_ok_control(SessionState *state,
                                  SessionWorkspace *workspace,
                                  uint8_t tx_kind,
                                  uint8_t *tx_scratch,
                                  uint8_t tx_capacity,
                                  SessionAction *actions,
                                  uint8_t count)
{
    switch (tx_kind) {
    case MQTT_TX_ACK_RESET:
        if (state->pending_request_id != 0u) {
            state->phase = SESSION_PHASE_ACTIVE;
            state->current_ply = 0u;
            if (!mqtt_emit_game(actions,
                                &count,
                                SESSION_DELIVER_CONTROL,
                                0u,
                                SESSION_REQUEST_RESET,
                                0,
                                0u) ||
                !mqtt_emit_session(actions,
                                   &count,
                                   SESSION_CHANGED_STARTED)) {
                return 0u;
            }
        }
        session_clear_duplicate(state);
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_LIVENESS,
                                   MQTT_LIVENESS_TICKS)
                   ? count
                   : 0u;
    case MQTT_TX_ACK_DRAW:
        if (state->pending_request_id != 0u &&
            !mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_CONTROL,
                            0u,
                            SESSION_REQUEST_DRAW,
                            0,
                            0u)) {
            return 0u;
        }
        state->phase = SESSION_PHASE_OVER;
        state->pending_control = SESSION_REQUEST_RESET;
        state->pending_origin = MQTT_ORIGIN_REMOTE;
        state->pending_request_id = 0u;
        state->control_retries = 0u;
        state->pending_value = 0u;
        if (!mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_LIVENESS) ||
            !mqtt_emit_timer_set(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_CONTROL,
                                 MQTT_REPLY_TICKS)) {
            return 0u;
        }
        return count;
    case MQTT_TX_ACK_DRAW_CROSSED:
        state->phase = SESSION_PHASE_OVER;
        state->pending_control = SESSION_REQUEST_RESET;
        state->pending_origin = MQTT_ORIGIN_LOCAL;
        state->pending_request_id = 0u;
        state->control_retries = 0u;
        state->pending_value = 0u;
        if (!mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_CONTROL_RESULT,
                            SESSION_CONTROL_ACCEPTED,
                            SESSION_REQUEST_DRAW,
                            0,
                            0u) ||
            !mqtt_send_local_pending(state,
                                     workspace,
                                     tx_scratch,
                                     tx_capacity,
                                     actions,
                                     &count)) {
            return 0u;
        }
        return count;
    case MQTT_TX_ACK_RESET_CROSSED: {
        uint8_t local = (uint8_t)(state->pending_origin !=
                                  MQTT_ORIGIN_REMOTE);

        state->phase = SESSION_PHASE_ACTIVE;
        state->current_ply = 0u;
        session_clear_duplicate(state);
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        if (!mqtt_emit_game(actions,
                            &count,
                            local != 0u
                                ? SESSION_DELIVER_CONTROL_RESULT
                                : SESSION_DELIVER_CONTROL,
                            local != 0u
                                ? SESSION_CONTROL_ACCEPTED
                                : 0u,
                            SESSION_REQUEST_RESET,
                            0,
                            0u) ||
            !mqtt_emit_session(actions, &count, SESSION_CHANGED_STARTED) ||
            !mqtt_emit_timer_set(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_LIVENESS,
                                 MQTT_LIVENESS_TICKS)) {
            return 0u;
        }
        return count;
    }
    case MQTT_TX_ACK_RESIGN:
        if (state->pending_request_id != 0u) {
            state->phase = SESSION_PHASE_OVER;
            if (!mqtt_emit_game(actions,
                                &count,
                                SESSION_DELIVER_CONTROL,
                                0u,
                                SESSION_REQUEST_RESIGN,
                                0,
                                0u)) {
                return 0u;
            }
        }
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_LIVENESS,
                                   MQTT_LIVENESS_TICKS)
                   ? count
                   : 0u;
    case MQTT_TX_ACK_RESIGN_CROSSED:
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        state->control_retries = 0u;
        if (!mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_CONTROL_RESULT,
                            SESSION_CONTROL_ACCEPTED,
                            SESSION_REQUEST_RESIGN,
                            0,
                            0u)) {
            return 0u;
        }
        if (state->config.role == SESSION_ROLE_HOST) {
            state->pending_control = SESSION_REQUEST_RESET;
            state->pending_origin = MQTT_ORIGIN_LOCAL;
            return mqtt_send_local_pending(state,
                                           0,
                                           tx_scratch,
                                           tx_capacity,
                                           actions,
                                           &count)
                       ? count
                       : 0u;
        }
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_LIVENESS,
                                   MQTT_LIVENESS_TICKS)
                   ? count
                   : 0u;
    case MQTT_TX_ACK_TAKEBACK:
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_LIVENESS,
                                   MQTT_LIVENESS_TICKS)
                   ? count
                   : 0u;
    case MQTT_TX_NACK_RESET:
    case MQTT_TX_NACK_DRAW:
    case MQTT_TX_NACK_TAKEBACK:
        session_clear_duplicate(state);
        if ((tx_kind == MQTT_TX_NACK_RESET ||
             tx_kind == MQTT_TX_NACK_DRAW) &&
            state->pending_value == MQTT_CANCEL_REMOTE &&
            !mqtt_emit_game(actions,
                            &count,
                            SESSION_DELIVER_CONTROL_RESULT,
                            SESSION_CONTROL_EXPIRED,
                            state->pending_control,
                            0,
                            0u)) {
            return 0u;
        }
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_LIVENESS,
                                   MQTT_LIVENESS_TICKS)
                   ? count
                   : 0u;
    default:
        return MQTT_TX_UNHANDLED;
    }
}

static uint8_t mqtt_tx_ok_restore(SessionState *state,
                                  SessionWorkspace *workspace,
                                  uint8_t tx_kind,
                                  uint8_t *tx_scratch,
                                  uint8_t tx_capacity,
                                  SessionAction *actions,
                                  uint8_t count)
{
    switch (tx_kind) {
    case MQTT_TX_RN:
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        state->restore_phase = MQTT_RESTORE_NONE;
        state->restore_mask = 0u;
        if (state->last_rx_kind == SESSION_REQUEST_RESTORE) {
            session_clear_duplicate(state);
        }
        if (!mqtt_emit_game(actions, &count,
                            SESSION_DELIVER_CONTROL_RESULT,
                            SESSION_CONTROL_REJECTED,
                            SESSION_REQUEST_RESTORE,
                            mqtt_reply_rn,
                            2u) ||
            !mqtt_emit_timer_set(state, actions, &count,
                                 SESSION_TIMER_LIVENESS,
                                 MQTT_LIVENESS_TICKS)) {
            return 0u;
        }
        return count;
    case MQTT_TX_RY:
        state->restore_phase = MQTT_RESTORE_RECEIVE;
        state->restore_mask = 0u;
        state->pending_request_id = 0u;
        if (!mqtt_emit_timer_cancel(state, actions, &count,
                                    SESSION_TIMER_LIVENESS) ||
            !mqtt_emit_timer_set(state, actions, &count,
                                 SESSION_TIMER_CONTROL,
                                 MQTT_REPLY_TICKS)) {
            return 0u;
        }
        return count;
    case MQTT_TX_RS0:
        return mqtt_send_restore_chunk(state, workspace, 1u, tx_scratch,
                                       tx_capacity, actions, &count)
                   ? count : 0u;
    case MQTT_TX_RS1:
        return mqtt_emit_timer_set(state, actions, &count,
                                   SESSION_TIMER_CONTROL,
                                   MQTT_REPLY_TICKS)
                   ? count : 0u;
    case MQTT_TX_RA:
        state->pending_value = 0u;
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->restore_phase = MQTT_RESTORE_APPLIED;
        return mqtt_emit_timer_set(state, actions, &count,
                                   SESSION_TIMER_LIVENESS,
                                   MQTT_LIVENESS_TICKS)
                   ? count : 0u;
    default:
        return MQTT_TX_UNHANDLED;
    }
}

static uint8_t mqtt_tx_ok_session(SessionState *state,
                                  uint8_t tx_kind,
                                  uint8_t *tx_scratch,
                                  uint8_t tx_capacity,
                                  SessionAction *actions,
                                  uint8_t count)
{
    switch (tx_kind) {
    case MQTT_TX_TRANSIENT_REPLY:
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_LIVENESS,
                                   MQTT_LIVENESS_TICKS)
                   ? count
                   : 0u;
    case MQTT_TX_PING:
        if (!mqtt_emit_timer_set(state,
                                 actions,
                                 &count,
                                 SESSION_TIMER_LIVENESS,
                                 MQTT_PING_WAIT_TICKS)) {
            return 0u;
        }
        state->liveness_misses = 1u;
        return count;
    case MQTT_TX_BYE:
        if ((state->deferred_decision & MQTT_STATE_OWN_ONLINE) != 0u &&
            mqtt_send_offline_end(state,
                                  tx_scratch,
                                  tx_capacity,
                                  actions,
                                  &count)) {
            return count;
        }
        return mqtt_finish(state,
                           actions,
                           count,
                           state->active_link);
    case MQTT_TX_ACK_START:
        if (state->pending_control == SESSION_REQUEST_START &&
            state->pending_origin == MQTT_ORIGIN_REMOTE) {
            state->phase = SESSION_PHASE_ACTIVE;
            state->current_ply = 0u;
            state->pending_control = 0u;
            state->pending_origin = MQTT_ORIGIN_NONE;
            if (!mqtt_emit_session(actions, &count, SESSION_CHANGED_STARTED)) {
                return 0u;
            }
        }
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_LIVENESS,
                                   MQTT_LIVENESS_TICKS)
                   ? count
                   : 0u;
    case MQTT_TX_ACK_MOVE:
    case MQTT_TX_NACK_MOVE:
        return mqtt_emit_timer_set(state,
                                   actions,
                                   &count,
                                   SESSION_TIMER_LIVENESS,
                                   MQTT_LIVENESS_TICKS)
                   ? count
                   : 0u;
    case MQTT_TX_OFFLINE_END:
        if (state->config.role == SESSION_ROLE_HOST) {
            state->deferred_decision &=
                (uint8_t)~MQTT_STATE_OWN_ONLINE;
            if (mqtt_send_text(state,
                               "",
                               SESSION_ROUTE_META,
                               1u,
                               MQTT_TX_META_CLEAR,
                               tx_scratch,
                               tx_capacity,
                               actions,
                               &count)) {
                return count;
            }
        }
        return mqtt_finish(state, actions, count, state->active_link);
    case MQTT_TX_META_CLEAR:
        return mqtt_finish(state, actions, count, state->active_link);
    case MQTT_TX_PEER_OFFLINE_END:
        return mqtt_finish(state, actions, count, SESSION_LINK_NONE);
    case MQTT_TX_PEER_OFFLINE_WAIT:
        return mqtt_wait_for_peer(state, actions, count);
    default:
        return MQTT_TX_UNHANDLED;
    }
}

static uint8_t mqtt_tx_ok(SessionState *state,
                          SessionWorkspace *workspace,
                          uint8_t tx_kind,
                          uint8_t *tx_scratch,
                          uint8_t tx_capacity,
                          SessionAction *actions,
                          uint8_t count)
{
    uint8_t result;

    result = mqtt_tx_ok_bootstrap(state, tx_kind, tx_scratch, tx_capacity,
                                  actions, count);
    if (result != MQTT_TX_UNHANDLED) {
        return result;
    }
    result = mqtt_tx_ok_outbound(state, workspace, tx_kind, actions, count);
    if (result != MQTT_TX_UNHANDLED) {
        return result;
    }
    result = mqtt_tx_ok_control(state, workspace, tx_kind, tx_scratch,
                                tx_capacity, actions, count);
    if (result != MQTT_TX_UNHANDLED) {
        return result;
    }
    result = mqtt_tx_ok_restore(state, workspace, tx_kind, tx_scratch,
                                tx_capacity, actions, count);
    if (result != MQTT_TX_UNHANDLED) {
        return result;
    }
    result = mqtt_tx_ok_session(state, tx_kind, tx_scratch, tx_capacity,
                                actions, count);
    return result != MQTT_TX_UNHANDLED ? result : count;
}

static void mqtt_clear_pending_tx(SessionState *state)
{
    state->pending_tx_kind = MQTT_TX_NONE;
    state->pending_tx_id = 0u;
    state->tx_link = SESSION_LINK_NONE;
}

static uint8_t mqtt_handle_tx_failure(SessionState *state,
                                      uint8_t tx_kind,
                                      uint8_t *tx_scratch,
                                      uint8_t tx_capacity,
                                      SessionAction *actions,
                                      uint8_t count)
{
    if (tx_kind != MQTT_TX_ONLINE && tx_kind != MQTT_TX_OFFLINE_END &&
        (state->deferred_decision & MQTT_STATE_OWN_ONLINE) != 0u &&
        mqtt_send_offline_end(state, tx_scratch, tx_capacity,
                              actions, &count)) {
        return count;
    }
    return mqtt_finish(state, actions, count, state->active_link);
}

static uint8_t mqtt_handle_tx_result(SessionState *state,
                                     const SessionEvent *event,
                                     SessionWorkspace *workspace,
                                     uint8_t *tx_scratch,
                                     uint8_t tx_capacity,
                                     SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t tx_kind;

    if (state->pending_tx_kind == MQTT_TX_NONE ||
        event->data.tx.tx_id != state->pending_tx_id) {
        return 0u;
    }
    tx_kind = state->pending_tx_kind;
    if (!mqtt_emit_timer_cancel(state,
                                actions,
                                &count,
                                SESSION_TIMER_TX_GUARD)) {
        return 0u;
    }
    mqtt_clear_pending_tx(state);
    if (event->data.tx.result == SESSION_TX_OK) {
        return mqtt_tx_ok(state,
                          workspace,
                          tx_kind,
                          tx_scratch,
                          tx_capacity,
                          actions,
                          count);
    }
    return mqtt_handle_tx_failure(state, tx_kind, tx_scratch, tx_capacity,
                                  actions, count);
}

static uint8_t mqtt_handle_tx_guard_timeout(SessionState *state,
                                            uint8_t *tx_scratch,
                                            uint8_t tx_capacity,
                                            SessionAction *actions)
{
    uint8_t tx_kind = state->pending_tx_kind;

    state->timer_mask &=
        (uint8_t)~(uint8_t)(1u << SESSION_TIMER_TX_GUARD);
    mqtt_clear_pending_tx(state);
    return mqtt_handle_tx_failure(state, tx_kind, tx_scratch, tx_capacity,
                                  actions, 0u);
}

static uint8_t mqtt_rearm_liveness_during_tx(SessionState *state,
                                             SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t outstanding = state->liveness_misses;

    state->timer_mask &=
        (uint8_t)~(uint8_t)(1u << SESSION_TIMER_LIVENESS);
    if (!mqtt_emit_timer_set(state,
                             actions,
                             &count,
                             SESSION_TIMER_LIVENESS,
                             outstanding != 0u
                                 ? MQTT_PING_WAIT_TICKS
                                 : MQTT_LIVENESS_TICKS)) {
        return 0u;
    }
    state->liveness_misses = outstanding;
    return count;
}

static uint8_t mqtt_handle_pending_tx_timeout(SessionState *state,
                                              uint8_t timer_id,
                                              uint8_t *tx_scratch,
                                              uint8_t tx_capacity,
                                              SessionAction *actions)
{
    if (state->pending_tx_kind == MQTT_TX_NONE) {
        return MQTT_RX_UNHANDLED;
    }
    if (timer_id == SESSION_TIMER_TX_GUARD) {
        return mqtt_handle_tx_guard_timeout(state, tx_scratch, tx_capacity,
                                            actions);
    }
    if (timer_id == SESSION_TIMER_LIVENESS) {
        return mqtt_rearm_liveness_during_tx(state, actions);
    }
    return 0u;
}

static uint8_t mqtt_handle_liveness_timeout(SessionState *state,
                                            uint8_t *tx_scratch,
                                            uint8_t tx_capacity,
                                            SessionAction *actions)
{
    uint8_t count = 0u;

    if (state->peer_ready == 0u) {
        return 0u;
    }
    if (state->liveness_misses != 0u) {
        if (state->config.role == SESSION_ROLE_HOST) {
            return mqtt_send_side(
                       state,
                       state->local_color == SESSION_COLOR_WHITE
                           ? SESSION_COLOR_BLACK : SESSION_COLOR_WHITE,
                       NETCHESS_MQTT_SESSION_VERB_OFFLINE,
                       1u,
                       MQTT_TX_PEER_OFFLINE_END,
                       tx_scratch,
                       tx_capacity,
                       actions,
                       &count)
                       ? count : 0u;
        }
        return mqtt_finish(state, actions, count, SESSION_LINK_NONE);
    }
    return mqtt_send_text(state,
                          "PING",
                          SESSION_ROUTE_CONTROL,
                          0u,
                          MQTT_TX_PING,
                          tx_scratch,
                          tx_capacity,
                          actions,
                          &count)
               ? count
               : 0u;
}

static uint8_t mqtt_handle_pending_request_timeout(SessionState *state,
                                                   uint8_t timer_id,
                                                   uint8_t *tx_scratch,
                                                   uint8_t tx_capacity,
                                                   SessionAction *actions)
{
    uint8_t count = 0u;

    if (timer_id != SESSION_TIMER_CONTROL ||
        state->pending_request_id == 0u) {
        return MQTT_RX_UNHANDLED;
    }
    if (state->pending_control == SESSION_REQUEST_MOVE &&
        state->pending_origin == MQTT_ORIGIN_REMOTE) {
        static const uint8_t timeout_reason[] = "TIMEOUT";

        state->pending_request_id = 0u;
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        return mqtt_send_move_reply(state,
                                    state->pending_value,
                                    timeout_reason,
                                    7u,
                                    0u,
                                    tx_scratch,
                                    tx_capacity,
                                    actions,
                                    &count)
                   ? count
                   : 0u;
    }
    if (state->pending_control == SESSION_REQUEST_TAKEBACK &&
        state->pending_origin == MQTT_ORIGIN_REMOTE) {
        state->pending_request_id = 0u;
        return mqtt_send_takeback_reply(state,
                                        state->pending_value,
                                        0,
                                        0u,
                                        0u,
                                        MQTT_TX_NACK_TAKEBACK,
                                        tx_scratch,
                                        tx_capacity,
                                        actions,
                                        &count)
                   ? count
                   : 0u;
    }
    if (state->pending_control == SESSION_REQUEST_TAKEBACK &&
        state->pending_origin == MQTT_ORIGIN_LOCAL) {
        if ((state->deferred_decision & MQTT_STATE_OWN_ONLINE) != 0u &&
            mqtt_send_offline_end(state,
                                  tx_scratch,
                                  tx_capacity,
                                  actions,
                                  &count)) {
            return count;
        }
        return mqtt_finish(state, actions, count, state->active_link);
    }
    if (state->pending_control == SESSION_REQUEST_RESTORE &&
        state->pending_origin == MQTT_ORIGIN_REMOTE) {
        state->pending_request_id = 0u;
        return mqtt_send_control_reply(state,
                                       SESSION_REQUEST_RESTORE,
                                       0u,
                                       0u,
                                       MQTT_TX_RN,
                                       0,
                                       0u,
                                       tx_scratch,
                                       tx_capacity,
                                       actions,
                                       &count)
                   ? count : 0u;
    }
    return MQTT_RX_UNHANDLED;
}

static uint8_t mqtt_handle_remote_restore_timeout(SessionState *state,
                                                  uint8_t timer_id,
                                                  uint8_t *tx_scratch,
                                                  uint8_t tx_capacity,
                                                  SessionAction *actions)
{
    uint8_t count = 0u;

    if (timer_id != SESSION_TIMER_CONTROL ||
        state->pending_control != SESSION_REQUEST_RESTORE ||
        state->pending_origin != MQTT_ORIGIN_REMOTE ||
        state->restore_phase != MQTT_RESTORE_RECEIVE) {
        return MQTT_RX_UNHANDLED;
    }
    if (state->control_retries >= SESSION_DIRECT_REPLY_RETRIES) {
        state->pending_control = 0u;
        state->pending_origin = MQTT_ORIGIN_NONE;
        state->restore_phase = MQTT_RESTORE_NONE;
        state->restore_mask = 0u;
        return mqtt_send_text(state, "RN", SESSION_ROUTE_GAME, 0u,
                              MQTT_TX_RN, tx_scratch, tx_capacity,
                              actions, &count)
                   ? count : 0u;
    }
    ++state->control_retries;
    return mqtt_emit_timer_set(state, actions, &count,
                               SESSION_TIMER_CONTROL,
                               MQTT_REPLY_TICKS)
               ? count : 0u;
}

static uint8_t mqtt_handle_local_control_timeout(SessionState *state,
                                                 uint8_t timer_id,
                                                 SessionWorkspace *workspace,
                                                 uint8_t *tx_scratch,
                                                 uint8_t tx_capacity,
                                                 SessionAction *actions)
{
    uint8_t count = 0u;

    if (timer_id != SESSION_TIMER_CONTROL ||
        state->pending_origin != MQTT_ORIGIN_LOCAL ||
        (state->pending_control != SESSION_REQUEST_START &&
         state->pending_control != SESSION_REQUEST_MOVE &&
         state->pending_control != SESSION_REQUEST_RESET &&
         state->pending_control != SESSION_REQUEST_DRAW &&
         state->pending_control != SESSION_REQUEST_RESIGN &&
         state->pending_control != SESSION_REQUEST_TAKEBACK &&
         state->pending_control != SESSION_REQUEST_RESTORE)) {
        return MQTT_RX_UNHANDLED;
    }
    if ((state->pending_control == SESSION_REQUEST_RESET ||
         state->pending_control == SESSION_REQUEST_DRAW) &&
        state->pending_value == MQTT_CANCEL_WAIT) {
        state->pending_value = MQTT_CANCEL_SENT;
        state->control_retries = 0u;
        return mqtt_send_local_pending(state,
                                       workspace,
                                       tx_scratch,
                                       tx_capacity,
                                       actions,
                                       &count)
                   ? count : 0u;
    }
    if (state->control_retries >= SESSION_DIRECT_REPLY_RETRIES) {
        if (state->pending_control == SESSION_REQUEST_RESTORE &&
            state->restore_phase == MQTT_RESTORE_WAIT_RY) {
            state->pending_control = 0u;
            state->pending_origin = MQTT_ORIGIN_NONE;
            state->restore_phase = MQTT_RESTORE_NONE;
            return mqtt_send_text(state, "RN", SESSION_ROUTE_GAME, 0u,
                                  MQTT_TX_RN, tx_scratch, tx_capacity,
                                  actions, &count)
                       ? count : 0u;
        }
        if (state->pending_control == SESSION_REQUEST_RESET ||
            state->pending_control == SESSION_REQUEST_DRAW) {
            state->control_retries = 0u;
            if (state->pending_value == 0u) {
                state->pending_value = MQTT_CANCEL_WAIT;
            }
            return mqtt_emit_timer_set(state,
                                       actions,
                                       &count,
                                       SESSION_TIMER_CONTROL,
                                       SESSION_CONTROL_CANCEL_TICKS) &&
                           mqtt_emit_timer_set(state,
                                               actions,
                                               &count,
                                               SESSION_TIMER_LIVENESS,
                                               MQTT_LIVENESS_TICKS)
                       ? count : 0u;
        }
        if ((state->deferred_decision & MQTT_STATE_OWN_ONLINE) != 0u &&
            mqtt_send_offline_end(state,
                                  tx_scratch,
                                  tx_capacity,
                                  actions,
                                  &count)) {
            return count;
        }
        return mqtt_finish(state, actions, count, state->active_link);
    }
    ++state->control_retries;
    return mqtt_send_local_pending(state,
                                   workspace,
                                   tx_scratch,
                                   tx_capacity,
                                   actions,
                                   &count)
               ? count
               : 0u;
}

static uint8_t mqtt_handle_setup_timeout(SessionState *state,
                                         uint8_t timer_id,
                                         uint8_t *tx_scratch,
                                         uint8_t tx_capacity,
                                         SessionAction *actions)
{
    uint8_t count = 0u;

    if (timer_id == SESSION_TIMER_CONTROL &&
        state->config.role == SESSION_ROLE_GUEST &&
        state->peer_ready != 0u &&
        state->phase == SESSION_PHASE_READY) {
        if (!mqtt_emit_timer_cancel(state,
                                    actions,
                                    &count,
                                    SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        return mqtt_send_join(state,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              &count)
                   ? count
                   : 0u;
    }
    if (timer_id == SESSION_TIMER_CONTROL &&
        state->config.role == SESSION_ROLE_HOST &&
        state->peer_ready == 0u &&
        state->phase == SESSION_PHASE_HANDSHAKE) {
        return mqtt_send_host(state,
                              1u,
                              MQTT_TX_HOST_RETAINED,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              &count)
                   ? count
                   : 0u;
    }
    return MQTT_RX_UNHANDLED;
}

static uint8_t mqtt_handle_timeout(SessionState *state,
                                   const SessionEvent *event,
                                   SessionWorkspace *workspace,
                                   uint8_t *tx_scratch,
                                   uint8_t tx_capacity,
                                   SessionAction *actions)
{
    uint8_t result;
    uint8_t timer_id = event->data.timeout.timer_id;

    if (timer_id >= SESSION_TIMER_COUNT ||
        (state->timer_mask & (uint8_t)(1u << timer_id)) == 0u) {
        return 0u;
    }
    result = mqtt_handle_pending_tx_timeout(state, timer_id, tx_scratch,
                                            tx_capacity, actions);
    if (result != MQTT_RX_UNHANDLED) {
        return result;
    }
    state->timer_mask &= (uint8_t)~(uint8_t)(1u << timer_id);
    if (timer_id == SESSION_TIMER_LIVENESS) {
        return mqtt_handle_liveness_timeout(state, tx_scratch, tx_capacity,
                                            actions);
    }
    result = mqtt_handle_pending_request_timeout(state, timer_id, tx_scratch,
                                                 tx_capacity, actions);
    if (result != MQTT_RX_UNHANDLED) {
        return result;
    }
    result = mqtt_handle_remote_restore_timeout(state, timer_id, tx_scratch,
                                                tx_capacity, actions);
    if (result != MQTT_RX_UNHANDLED) {
        return result;
    }
    result = mqtt_handle_local_control_timeout(state, timer_id, workspace,
                                               tx_scratch, tx_capacity,
                                               actions);
    if (result != MQTT_RX_UNHANDLED) {
        return result;
    }
    result = mqtt_handle_setup_timeout(state, timer_id, tx_scratch,
                                       tx_capacity, actions);
    return result != MQTT_RX_UNHANDLED ? result : 0u;
}

uint8_t mqtt_session_step(SessionState *state,
                          const SessionEvent *event,
                          SessionWorkspace *workspace,
                          uint8_t *tx_scratch,
                          uint8_t tx_capacity,
                          SessionAction *actions,
                          uint8_t action_capacity)
{
    if (workspace == 0 || tx_scratch == 0 || tx_capacity == 0u ||
        actions == 0 || action_capacity < SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    switch (event->type) {
    case SESSION_EV_LINK_UP:
        return mqtt_handle_link_up(state,
                                   event->data.link.link_id,
                                   tx_scratch,
                                   tx_capacity,
                                   actions);
    case SESSION_EV_RX:
        return mqtt_handle_rx(state,
                              event,
                              workspace,
                              tx_scratch,
                              tx_capacity,
                              actions);
    case SESSION_EV_LOCAL_REQUEST:
        return mqtt_handle_local(state,
                                 event,
                                 workspace,
                                 tx_scratch,
                                 tx_capacity,
                                 actions);
    case SESSION_EV_TX_RESULT:
        return mqtt_handle_tx_result(state,
                                     event,
                                     workspace,
                                     tx_scratch,
                                     tx_capacity,
                                     actions);
    case SESSION_EV_TIMEOUT:
        return mqtt_handle_timeout(state,
                                   event,
                                   workspace,
                                   tx_scratch,
                                   tx_capacity,
                                   actions);
    case SESSION_EV_GAME_RESULT:
        return mqtt_handle_game_result(state,
                                       event,
                                       tx_scratch,
                                       tx_capacity,
                                       actions);
    case SESSION_EV_USER_DECISION:
        return mqtt_handle_user_decision(state,
                                         event,
                                         tx_scratch,
                                         tx_capacity,
                                         actions);
    default:
        return 0u;
    }
}
