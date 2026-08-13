#include "common/session/session_internal.h"

#include "common/protocol/direct_session_protocol.h"
#include "common/protocol/game_protocol.h"

#define DIRECT_TX_NONE 0u
#define DIRECT_TX_HELLO 1u
#define DIRECT_TX_BUSY 2u
#define DIRECT_TX_START 3u
#define DIRECT_TX_MOVE 4u
#define DIRECT_TX_PING 5u
#define DIRECT_TX_ACK_PING 6u
#define DIRECT_TX_ACK_START 7u
#define DIRECT_TX_ACK_MOVE 8u
#define DIRECT_TX_NACK_MOVE 9u
#define DIRECT_TX_RESET 10u
#define DIRECT_TX_ACK_RESET 11u
#define DIRECT_TX_NACK_RESET 12u
#define DIRECT_TX_DRAW 13u
#define DIRECT_TX_ACK_DRAW 14u
#define DIRECT_TX_NACK_DRAW 15u
#define DIRECT_TX_RESIGN 16u
#define DIRECT_TX_ACK_RESIGN 17u
#define DIRECT_TX_TAKEBACK 18u
#define DIRECT_TX_ACK_TAKEBACK 19u
#define DIRECT_TX_NACK_TAKEBACK 20u
#define DIRECT_TX_CHAT 21u
#define DIRECT_TX_BYE 22u
#define DIRECT_TX_RQ 23u
#define DIRECT_TX_RY 24u
#define DIRECT_TX_RN 25u
#define DIRECT_TX_RS0 26u
#define DIRECT_TX_RS1 27u
#define DIRECT_TX_RA 28u
#define DIRECT_TX_NACK_START 29u
#define DIRECT_TX_ACK_DRAW_CROSSED 30u
#define DIRECT_TX_NACK_RESET_BUSY 31u
#define DIRECT_TX_RN_BUSY 32u
#define DIRECT_TX_ACK_RESET_CROSSED 33u
#define DIRECT_TX_ACK_RESIGN_CROSSED 34u

#define DIRECT_ORIGIN_NONE 0u
#define DIRECT_ORIGIN_LOCAL 1u
#define DIRECT_ORIGIN_REMOTE 2u

#define DIRECT_CANCEL_WAIT 1u
#define DIRECT_CANCEL_SENT 2u
#define DIRECT_CANCEL_REMOTE 3u

#define DIRECT_RESTORE_NONE SESSION_RESTORE_PHASE_NONE
#define DIRECT_RESTORE_WAIT_RY 1u
#define DIRECT_RESTORE_WAIT_RA 2u
#define DIRECT_RESTORE_RECEIVE 3u
#define DIRECT_RESTORE_APPLIED SESSION_RESTORE_PHASE_APPLIED
#define DIRECT_RESTORE_CHUNK_MASK 3u
#define DIRECT_RESTORE_PHASE_SHIFT 2u
#define DIRECT_RX_UNHANDLED 0xffu
#define DIRECT_TX_UNHANDLED DIRECT_RX_UNHANDLED

static const uint8_t direct_reason_busy[] = "BUSY";
static const uint8_t direct_reason_reject[] = "REJECT";
static const uint8_t direct_reply_rn[] = "RN";

static uint8_t direct_send_control_reply(SessionState *state,
                                         uint8_t control,
                                         uint8_t accepted,
                                         uint8_t *tx_scratch,
                                         uint8_t tx_capacity,
                                         SessionAction *actions,
                                         uint8_t *count);

static uint8_t direct_apply_user_decision(SessionState *state,
                                          uint8_t decision,
                                          uint8_t *tx_scratch,
                                          uint8_t tx_capacity,
                                          SessionAction *actions,
                                          uint8_t *count);

static uint8_t direct_text_length(const char *text)
{
    uint8_t length = 0u;

    while (length < SESSION_PAYLOAD_MAX && text[length] != '\0') {
        ++length;
    }
    return length;
}

static uint8_t direct_text_equal(const uint8_t *payload,
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

static uint8_t direct_text_prefix(const uint8_t *payload,
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

static uint8_t direct_slice_valid(const uint8_t *payload, uint8_t length)
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

static uint8_t direct_fixed_slice_valid(const uint8_t *payload,
                                        uint8_t length)
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

static uint8_t direct_emit_timer_set(SessionState *state,
                                     SessionAction *actions,
                                     uint8_t *count,
                                     uint8_t timer_id,
                                     uint16_t ticks)
{
    SessionAction *action;

    if (*count >= SESSION_ACTION_CAPACITY || timer_id >= SESSION_TIMER_COUNT) {
        return 0u;
    }
    action = &actions[*count];
    action->type = SESSION_ACT_TIMER_SET;
    action->data.timer_set.timer_id = timer_id;
    action->data.timer_set.duration_ticks = ticks;
    ++*count;
    state->timer_mask |= (uint8_t)(1u << timer_id);
    return 1u;
}

static uint8_t direct_emit_timer_cancel(SessionState *state,
                                        SessionAction *actions,
                                        uint8_t *count,
                                        uint8_t timer_id)
{
    SessionAction *action;
    uint8_t bit = (uint8_t)(1u << timer_id);

    if ((state->timer_mask & bit) == 0u) {
        return 1u;
    }
    if (*count >= SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    action = &actions[*count];
    action->type = SESSION_ACT_TIMER_CANCEL;
    action->data.timer_cancel.timer_id = timer_id;
    ++*count;
    state->timer_mask &= (uint8_t)~bit;
    return 1u;
}

static uint8_t direct_emit_session(SessionAction *actions,
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

static uint8_t direct_emit_side(SessionState *state,
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

static uint8_t direct_emit_close(SessionAction *actions,
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

static uint8_t direct_emit_game(SessionAction *actions,
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

static uint8_t direct_emit_decision(SessionAction *actions,
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

static uint8_t direct_send_buffer(SessionState *state,
                                  uint8_t *tx_scratch,
                                  uint8_t tx_capacity,
                                  SessionAction *actions,
                                  uint8_t *count,
                                  uint8_t link_id,
                                  uint8_t tx_kind)
{
    uint8_t length;
    uint8_t tx_id;

    if (state->pending_tx_kind != DIRECT_TX_NONE || tx_scratch == 0 ||
        tx_capacity == 0u || *count + 2u > SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    length = direct_text_length((const char *)tx_scratch);
    if (length >= tx_capacity || length > SESSION_PAYLOAD_MAX) {
        return 0u;
    }
    tx_id = session_next_tx_id(state);
    state->pending_tx_id = tx_id;
    state->pending_tx_kind = tx_kind;
    state->tx_link = link_id;

    actions[*count].type = SESSION_ACT_SEND;
    actions[*count].data.send.payload = tx_scratch;
    actions[*count].data.send.length = length;
    actions[*count].data.send.tx_id = tx_id;
    actions[*count].data.send.route = SESSION_ROUTE_DEFAULT;
    actions[*count].data.send.retained = 0u;
    actions[*count].data.send.link_id = link_id;
    ++*count;
    return direct_emit_timer_set(state,
                                 actions,
                                 count,
                                 SESSION_TIMER_TX_GUARD,
                                 SESSION_TX_GUARD_TICKS);
}

static uint8_t direct_send_text(SessionState *state,
                                const char *text,
                                uint8_t *tx_scratch,
                                uint8_t tx_capacity,
                                SessionAction *actions,
                                uint8_t *count,
                                uint8_t link_id,
                                uint8_t tx_kind)
{
    uint8_t length = direct_text_length(text);
    uint8_t i;

    if (tx_scratch == 0 || length >= tx_capacity) {
        return 0u;
    }
    for (i = 0u; i <= length; ++i) {
        tx_scratch[i] = (uint8_t)text[i];
    }
    return direct_send_buffer(state,
                              tx_scratch,
                              tx_capacity,
                              actions,
                              count,
                              link_id,
                              tx_kind);
}

static char *direct_u16_text(char *out, uint16_t value)
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
        if (digit != 0u || started || place == 1u) {
            *out++ = (char)('0' + digit);
            started = 1u;
        }
    }
    *out = '\0';
    return out;
}

static uint16_t direct_parse_u16(const char *text)
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

static uint8_t direct_finish(SessionState *state,
                             SessionAction *actions,
                             uint8_t count,
                             uint8_t close_link)
{
    uint8_t timer_id;
    uint8_t candidate_link = SESSION_LINK_NONE;

    if (state->pending_tx_kind == DIRECT_TX_BUSY &&
        state->tx_link != SESSION_LINK_NONE &&
        state->tx_link != close_link) {
        candidate_link = state->tx_link;
    }

    for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
        if (!direct_emit_timer_cancel(state, actions, &count, timer_id)) {
            return 0u;
        }
    }
    if (close_link != SESSION_LINK_NONE &&
        !direct_emit_close(actions, &count, close_link)) {
        return 0u;
    }
    if (candidate_link != SESSION_LINK_NONE &&
        !direct_emit_close(actions, &count, candidate_link)) {
        return 0u;
    }
    if (!direct_emit_session(actions, &count, SESSION_CHANGED_ENDED)) {
        return 0u;
    }
    session_reset(state);
    return count;
}

static uint16_t direct_liveness_ticks(const SessionState *state)
{
    return state->config.role == SESSION_ROLE_HOST
               ? SESSION_DIRECT_PING_TICKS
               : SESSION_DIRECT_IDLE_TICKS;
}

static uint8_t direct_arm_liveness(SessionState *state,
                                   SessionAction *actions,
                                   uint8_t *count)
{
    if (!state->peer_ready ||
        (state->pending_control != 0u &&
         !(state->pending_origin == DIRECT_ORIGIN_LOCAL &&
           (state->pending_control == SESSION_REQUEST_RESET ||
            state->pending_control == SESSION_REQUEST_DRAW) &&
           state->pending_value != 0u))) {
        return 1u;
    }
    return direct_emit_timer_set(state,
                                 actions,
                                 count,
                                 SESSION_TIMER_LIVENESS,
                                 direct_liveness_ticks(state));
}

static uint8_t direct_rearm_liveness_after_rx(SessionState *state,
                                              SessionAction *actions,
                                              uint8_t *count)
{
    if (state->pending_request_id != 0u &&
        (state->timer_mask &
         (uint8_t)(1u << SESSION_TIMER_CONTROL)) == 0u) {
        return direct_emit_timer_set(state, actions, count,
                                     SESSION_TIMER_LIVENESS,
                                     direct_liveness_ticks(state));
    }
    return direct_arm_liveness(state, actions, count);
}

static uint8_t direct_send_hello(SessionState *state,
                                 uint8_t *tx_scratch,
                                 uint8_t tx_capacity,
                                 SessionAction *actions,
                                 uint8_t *count)
{
    const char *hello = netchess_direct_hello(
        (uint8_t)(state->config.role == SESSION_ROLE_HOST),
        (uint8_t)(state->config.host_color == SESSION_COLOR_WHITE));

    return direct_send_text(state,
                            hello,
                            tx_scratch,
                            tx_capacity,
                            actions,
                            count,
                            state->active_link,
                            DIRECT_TX_HELLO);
}

static uint8_t direct_send_start(SessionState *state,
                                 uint8_t *tx_scratch,
                                 uint8_t tx_capacity,
                                 SessionAction *actions,
                                 uint8_t *count)
{
    const char *text = state->config.host_color == SESSION_COLOR_WHITE
                           ? "GAME START WHITE=HOST"
                           : "GAME START WHITE=GUEST";

    return direct_send_text(state, text, tx_scratch, tx_capacity, actions,
                            count, state->active_link, DIRECT_TX_START);
}

static uint8_t direct_send_move(SessionState *state,
                                SessionWorkspace *workspace,
                                uint8_t *tx_scratch,
                                uint8_t tx_capacity,
                                SessionAction *actions,
                                uint8_t *count)
{
    char ply[6];

    direct_u16_text(ply, state->pending_value);
    if (!netchess_proto_format_move((char *)tx_scratch,
                                    tx_capacity,
                                    ply,
                                    workspace->move,
                                    0)) {
        return 0u;
    }
    return direct_send_buffer(state, tx_scratch, tx_capacity, actions, count,
                              state->active_link, DIRECT_TX_MOVE);
}

static uint8_t direct_send_value_reply(SessionState *state,
                                       uint16_t value,
                                       const uint8_t *detail,
                                       uint8_t detail_length,
                                       uint8_t accepted,
                                       uint8_t *tx_scratch,
                                       uint8_t tx_capacity,
                                       SessionAction *actions,
                                       uint8_t *count,
                                       uint8_t tx_kind)
{
    char value_text[6];
    char detail_text[16];
    uint8_t i;

    direct_u16_text(value_text, value);
    if (detail_length >= sizeof(detail_text)) {
        detail_length = (uint8_t)(sizeof(detail_text) - 1u);
    }
    for (i = 0u; i < detail_length; ++i) {
        detail_text[i] = (char)detail[i];
    }
    detail_text[detail_length] = '\0';
    if (accepted) {
        if (!netchess_proto_format_ack((char *)tx_scratch,
                                       tx_capacity,
                                       value_text,
                                       detail_length == 0u ? 0 : detail_text)) {
            return 0u;
        }
    } else if (!netchess_proto_format_nack((char *)tx_scratch,
                                           tx_capacity,
                                           value_text,
                                           detail_length == 0u ? 0 : detail_text)) {
        return 0u;
    }
    return direct_send_buffer(state, tx_scratch, tx_capacity, actions, count,
                              state->active_link, tx_kind);
}

static uint8_t direct_send_takeback(SessionState *state,
                                    uint8_t *tx_scratch,
                                    uint8_t tx_capacity,
                                    SessionAction *actions,
                                    uint8_t *count)
{
    char value[6];
    uint8_t i = 0u;
    uint8_t j = 0u;
    const char *prefix = NETCHESS_PROTO_TAKEBACK_PREFIX;

    direct_u16_text(value, state->pending_value);
    while (prefix[i] != '\0') {
        ++i;
    }
    while (value[j] != '\0') {
        ++j;
    }
    if (tx_scratch == 0 || (uint16_t)i + (uint16_t)j >= tx_capacity) {
        return 0u;
    }
    i = 0u;
    while (prefix[i] != '\0') {
        tx_scratch[i] = (uint8_t)prefix[i];
        ++i;
    }
    j = 0u;
    while (value[j] != '\0') {
        tx_scratch[i++] = (uint8_t)value[j++];
    }
    tx_scratch[i] = 0u;
    return direct_send_buffer(state, tx_scratch, tx_capacity, actions, count,
                              state->active_link, DIRECT_TX_TAKEBACK);
}

static uint8_t direct_send_restore_chunk(SessionState *state,
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
    return direct_send_buffer(state, tx_scratch, tx_capacity, actions, count,
                              state->active_link,
                              chunk == 0u ? DIRECT_TX_RS0 : DIRECT_TX_RS1);
}

static uint8_t direct_send_local_pending(SessionState *state,
                                         SessionWorkspace *workspace,
                                         uint8_t *tx_scratch,
                                         uint8_t tx_capacity,
                                         SessionAction *actions,
                                         uint8_t *count)
{
    switch (state->pending_control) {
    case SESSION_REQUEST_START:
        return direct_send_start(state, tx_scratch, tx_capacity, actions, count);
    case SESSION_REQUEST_MOVE:
        return direct_send_move(state, workspace, tx_scratch, tx_capacity,
                                actions, count);
    case SESSION_REQUEST_RESET:
        return direct_send_text(state,
                                state->pending_value == DIRECT_CANCEL_SENT
                                    ? NETCHESS_PROTO_CANCEL_RESET : "RESET",
                                tx_scratch, tx_capacity,
                                actions, count, state->active_link,
                                DIRECT_TX_RESET);
    case SESSION_REQUEST_DRAW:
        return direct_send_text(state,
                                state->pending_value == DIRECT_CANCEL_SENT
                                    ? NETCHESS_PROTO_CANCEL_DRAW : "DRAW",
                                tx_scratch, tx_capacity,
                                actions, count, state->active_link,
                                DIRECT_TX_DRAW);
    case SESSION_REQUEST_RESIGN:
        return direct_send_text(state, "RESIGN", tx_scratch, tx_capacity,
                                actions, count, state->active_link,
                                DIRECT_TX_RESIGN);
    case SESSION_REQUEST_TAKEBACK:
        return direct_send_takeback(state, tx_scratch, tx_capacity,
                                    actions, count);
    case SESSION_REQUEST_RESTORE:
        if (state->restore_phase == DIRECT_RESTORE_WAIT_RA) {
            return direct_send_restore_chunk(state, workspace, 0u, tx_scratch,
                                             tx_capacity, actions, count);
        }
        return direct_send_text(state, "RQ", tx_scratch, tx_capacity,
                                actions, count, state->active_link,
                                DIRECT_TX_RQ);
    default:
        return 0u;
    }
}

static uint8_t direct_tx_ok_outbound(SessionState *state,
                                     SessionWorkspace *workspace,
                                     uint8_t tx_kind,
                                     uint8_t tx_link,
                                     uint8_t *tx_scratch,
                                     uint8_t tx_capacity,
                                     SessionAction *actions,
                                     uint8_t count)
{
    switch (tx_kind) {
    case DIRECT_TX_HELLO:
        if (state->peer_ready) {
            if (state->pending_value == 0u &&
                !direct_emit_session(actions, &count, SESSION_CHANGED_READY)) {
                return 0u;
            }
            state->pending_value = 0u;
            if (!direct_arm_liveness(state, actions, &count)) {
                return 0u;
            }
        } else if (!direct_emit_timer_set(state, actions, &count,
                                          SESSION_TIMER_CONTROL,
                                          SESSION_DIRECT_HELLO_TICKS)) {
            return 0u;
        }
        break;
    case DIRECT_TX_BUSY:
        if (!direct_emit_close(actions, &count, tx_link) ||
            !direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        break;
    case DIRECT_TX_START:
    case DIRECT_TX_MOVE:
    case DIRECT_TX_RESET:
    case DIRECT_TX_DRAW:
    case DIRECT_TX_TAKEBACK:
    case DIRECT_TX_RQ:
    case DIRECT_TX_RS1:
        if (!direct_emit_timer_set(state, actions, &count,
                                   SESSION_TIMER_CONTROL,
                                   SESSION_DIRECT_REPLY_TICKS)) {
            return 0u;
        }
        break;
    case DIRECT_TX_RESIGN:
        if (state->phase != SESSION_PHASE_OVER) {
            state->phase = SESSION_PHASE_OVER;
            if (!direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL,
                                  0u, SESSION_REQUEST_RESIGN, 0, 0u)) {
                return 0u;
            }
        }
        if (!direct_emit_timer_set(state, actions, &count,
                                   SESSION_TIMER_CONTROL,
                                   SESSION_DIRECT_REPLY_TICKS)) {
            return 0u;
        }
        break;
    case DIRECT_TX_PING: {
        uint8_t decision = state->deferred_decision;

        state->deferred_decision = 0u;
        if (decision != 0u) {
            if (!direct_apply_user_decision(state, decision, tx_scratch,
                                            tx_capacity, actions, &count)) {
                return 0u;
            }
            break;
        }
        if (!direct_emit_timer_set(state, actions, &count,
                                   SESSION_TIMER_LIVENESS,
                                   SESSION_DIRECT_PING_TICKS)) {
            return 0u;
        }
        break;
    }
    case DIRECT_TX_ACK_PING: {
        uint8_t decision = state->deferred_decision;

        state->deferred_decision = 0u;
        if (decision != 0u) {
            if (!direct_apply_user_decision(state, decision, tx_scratch,
                                            tx_capacity, actions, &count)) {
                return 0u;
            }
            break;
        }
        if (state->peer_ready) {
            if (!direct_rearm_liveness_after_rx(state, actions, &count)) {
                return 0u;
            }
        } else if (!direct_emit_timer_set(state, actions, &count,
                                          SESSION_TIMER_CONTROL,
                                          SESSION_DIRECT_HELLO_TICKS)) {
            return 0u;
        }
        break;
    }
    case DIRECT_TX_CHAT:
        if (!direct_emit_game(actions, &count, SESSION_DELIVER_CHAT, 0u,
                              SESSION_CHAT_LOCAL,
                              (const uint8_t *)workspace->chat,
                              direct_text_length(workspace->chat)) ||
            !direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        break;
    default:
        return DIRECT_TX_UNHANDLED;
    }
    return count;
}

static uint8_t direct_tx_ok_control_reply(SessionState *state,
                                          uint8_t tx_kind,
                                          SessionAction *actions,
                                          uint8_t count)
{
    switch (tx_kind) {
    case DIRECT_TX_ACK_START:
        if (state->pending_value == 0u) {
            state->phase = SESSION_PHASE_ACTIVE;
            state->current_ply = 0u;
            session_clear_duplicate(state);
            if (!direct_emit_session(actions, &count,
                                     SESSION_CHANGED_STARTED)) {
                return 0u;
            }
        }
        state->pending_value = 0u;
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        if (!direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        break;
    case DIRECT_TX_ACK_RESET:
        if (state->pending_request_id != 0u) {
            state->phase = SESSION_PHASE_ACTIVE;
            state->current_ply = 0u;
            if (!direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL, 0u,
                                  SESSION_REQUEST_RESET, 0, 0u) ||
                !direct_emit_session(actions, &count,
                                     SESSION_CHANGED_STARTED)) {
                return 0u;
            }
        }
        session_clear_duplicate(state);
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        if (!direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        break;
    case DIRECT_TX_ACK_DRAW:
        if (state->pending_request_id != 0u) {
            if (!direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL, 0u,
                                  state->pending_control, 0, 0u)) {
                return 0u;
            }
        }
        state->phase = SESSION_PHASE_OVER;
        state->pending_control = SESSION_REQUEST_RESET;
        state->pending_origin = DIRECT_ORIGIN_REMOTE;
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        state->control_retries = 0u;
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_LIVENESS) ||
            !direct_emit_timer_set(state, actions, &count,
                                   SESSION_TIMER_CONTROL,
                                   SESSION_DIRECT_REPLY_TICKS)) {
            return 0u;
        }
        break;
    case DIRECT_TX_ACK_RESIGN:
        if (state->pending_request_id != 0u) {
            if (!direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL, 0u,
                                  SESSION_REQUEST_RESIGN, 0, 0u)) {
                return 0u;
            }
            state->phase = SESSION_PHASE_OVER;
        }
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        if (!direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        break;
    case DIRECT_TX_ACK_TAKEBACK:
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        if (!direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        break;
    default:
        return DIRECT_TX_UNHANDLED;
    }
    return count;
}

static uint8_t direct_tx_ok_crossed_control(SessionState *state,
                                            uint8_t tx_kind,
                                            uint8_t *tx_scratch,
                                            uint8_t tx_capacity,
                                            SessionAction *actions,
                                            uint8_t count)
{
    switch (tx_kind) {
    case DIRECT_TX_ACK_DRAW_CROSSED:
        state->phase = SESSION_PHASE_OVER;
        state->pending_control = SESSION_REQUEST_RESET;
        state->pending_origin = DIRECT_ORIGIN_LOCAL;
        state->pending_request_id = 0u;
        state->control_retries = 0u;
        state->pending_value = 0u;
        if (!direct_emit_game(actions, &count,
                              SESSION_DELIVER_CONTROL_RESULT,
                              SESSION_CONTROL_ACCEPTED,
                              SESSION_REQUEST_DRAW, 0, 0u) ||
            !direct_send_text(state, "RESET", tx_scratch, tx_capacity,
                              actions, &count, state->active_link,
                              DIRECT_TX_RESET)) {
            return 0u;
        }
        break;
    case DIRECT_TX_ACK_RESET_CROSSED: {
        uint8_t control_result = (uint8_t)(
            state->pending_origin != DIRECT_ORIGIN_REMOTE);
        uint8_t delivery_kind = control_result
                                    ? SESSION_DELIVER_CONTROL_RESULT
                                    : SESSION_DELIVER_CONTROL;

        state->phase = SESSION_PHASE_ACTIVE;
        state->current_ply = 0u;
        session_clear_duplicate(state);
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        if (!direct_emit_game(actions, &count,
                              delivery_kind,
                              control_result ? SESSION_CONTROL_ACCEPTED : 0u,
                              SESSION_REQUEST_RESET, 0, 0u) ||
            !direct_emit_session(actions, &count, SESSION_CHANGED_STARTED) ||
            !direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        break;
    }
    case DIRECT_TX_ACK_RESIGN_CROSSED:
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        state->control_retries = 0u;
        if (!direct_emit_game(actions, &count,
                              SESSION_DELIVER_CONTROL_RESULT,
                              SESSION_CONTROL_ACCEPTED,
                              SESSION_REQUEST_RESIGN, 0, 0u)) {
            return 0u;
        }
        if (state->config.role == SESSION_ROLE_HOST) {
            state->pending_control = SESSION_REQUEST_RESET;
            state->pending_origin = DIRECT_ORIGIN_LOCAL;
            if (!direct_send_text(state, "RESET", tx_scratch, tx_capacity,
                                  actions, &count, state->active_link,
                                  DIRECT_TX_RESET)) {
                return 0u;
            }
        } else {
            state->pending_control = 0u;
            state->pending_origin = DIRECT_ORIGIN_NONE;
            if (!direct_arm_liveness(state, actions, &count)) {
                return 0u;
            }
        }
        break;
    default:
        return DIRECT_TX_UNHANDLED;
    }
    return count;
}

static uint8_t direct_tx_ok_rejection_restore(SessionState *state,
                                              SessionWorkspace *workspace,
                                              uint8_t tx_kind,
                                              uint8_t *tx_scratch,
                                              uint8_t tx_capacity,
                                              SessionAction *actions,
                                              uint8_t count)
{
    switch (tx_kind) {
    case DIRECT_TX_NACK_RESET:
    case DIRECT_TX_NACK_DRAW:
    case DIRECT_TX_NACK_TAKEBACK:
    case DIRECT_TX_RN:
        if (tx_kind != DIRECT_TX_RN) {
            session_clear_duplicate(state);
        }
        if ((tx_kind == DIRECT_TX_NACK_RESET ||
             tx_kind == DIRECT_TX_NACK_DRAW) &&
            state->pending_value == DIRECT_CANCEL_REMOTE &&
            !direct_emit_game(actions, &count,
                              SESSION_DELIVER_CONTROL_RESULT,
                              SESSION_CONTROL_EXPIRED,
                              state->pending_control, 0, 0u)) {
            return 0u;
        }
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        if (tx_kind == DIRECT_TX_RN) {
            state->pending_value = 0u;
            state->restore_phase = DIRECT_RESTORE_NONE;
            state->restore_mask = 0u;
            if (state->last_rx_kind == SESSION_REQUEST_RESTORE) {
                session_clear_duplicate(state);
            }
            if (!direct_emit_game(actions, &count,
                                  SESSION_DELIVER_CONTROL_RESULT,
                                  SESSION_CONTROL_REJECTED,
                                  SESSION_REQUEST_RESTORE,
                                  direct_reply_rn, 2u)) {
                return 0u;
            }
        }
        if (!direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        break;
    case DIRECT_TX_RY:
        state->restore_phase = DIRECT_RESTORE_RECEIVE;
        state->restore_mask = 0u;
        state->pending_request_id = 0u;
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_LIVENESS) ||
            !direct_emit_timer_set(state, actions, &count,
                                   SESSION_TIMER_CONTROL,
                                   SESSION_DIRECT_REPLY_TICKS)) {
            return 0u;
        }
        break;
    case DIRECT_TX_RS0:
        if (!direct_send_restore_chunk(state, workspace, 1u, tx_scratch,
                                       tx_capacity, actions, &count)) {
            return 0u;
        }
        break;
    case DIRECT_TX_RA:
        state->pending_value = 0u;
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->restore_phase = DIRECT_RESTORE_APPLIED;
        if (!direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        break;
    case DIRECT_TX_NACK_START:
    case DIRECT_TX_RN_BUSY: {
        uint8_t decision = state->deferred_decision;

        state->deferred_decision = 0u;
        if (decision != 0u &&
            !direct_apply_user_decision(state, decision, tx_scratch,
                                        tx_capacity, actions, &count)) {
            return 0u;
        }
        break;
    }
    case DIRECT_TX_NACK_RESET_BUSY:
        break;
    default:
        return DIRECT_TX_UNHANDLED;
    }
    return count;
}

static uint8_t direct_tx_ok(SessionState *state,
                            SessionWorkspace *workspace,
                            uint8_t tx_kind,
                            uint8_t tx_link,
                            uint8_t *tx_scratch,
                            uint8_t tx_capacity,
                            SessionAction *actions,
                            uint8_t count)
{
    uint8_t result;

    result = direct_tx_ok_outbound(state, workspace, tx_kind, tx_link,
                                   tx_scratch, tx_capacity, actions, count);
    if (result != DIRECT_TX_UNHANDLED) {
        return result;
    }
    result = direct_tx_ok_control_reply(state, tx_kind, actions, count);
    if (result != DIRECT_TX_UNHANDLED) {
        return result;
    }
    result = direct_tx_ok_crossed_control(state, tx_kind, tx_scratch,
                                          tx_capacity, actions, count);
    if (result != DIRECT_TX_UNHANDLED) {
        return result;
    }
    result = direct_tx_ok_rejection_restore(state, workspace, tx_kind,
                                            tx_scratch, tx_capacity, actions,
                                            count);
    if (result != DIRECT_TX_UNHANDLED) {
        return result;
    }
    if (tx_kind == DIRECT_TX_BYE) {
        return direct_finish(state, actions, count, state->active_link);
    }
    if (state->peer_ready &&
        !direct_arm_liveness(state, actions, &count)) {
        return 0u;
    }
    return count;
}

static void direct_clear_pending_tx(SessionState *state)
{
    state->pending_tx_kind = DIRECT_TX_NONE;
    state->pending_tx_id = 0u;
    state->tx_link = SESSION_LINK_NONE;
}

static uint8_t direct_handle_tx_failure(SessionState *state,
                                        SessionWorkspace *workspace,
                                        uint8_t tx_kind,
                                        uint8_t tx_link,
                                        uint8_t *tx_scratch,
                                        uint8_t tx_capacity,
                                        SessionAction *actions,
                                        uint8_t count)
{
    if (tx_kind == DIRECT_TX_BUSY) {
        if (!direct_emit_close(actions, &count, tx_link) ||
            !direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        return count;
    }
    if (tx_kind == DIRECT_TX_ACK_PING) {
        return direct_tx_ok(state, workspace, tx_kind, tx_link,
                            tx_scratch, tx_capacity, actions, count);
    }
    return direct_finish(state, actions, count, state->active_link);
}

static uint8_t direct_handle_tx_result(SessionState *state,
                                       const SessionEvent *event,
                                       SessionWorkspace *workspace,
                                       uint8_t *tx_scratch,
                                       uint8_t tx_capacity,
                                       SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t tx_kind;
    uint8_t tx_link;

    if (state->pending_tx_kind == DIRECT_TX_NONE ||
        event->data.tx.tx_id != state->pending_tx_id) {
        return 0u;
    }
    tx_kind = state->pending_tx_kind;
    tx_link = state->tx_link;
    if (!direct_emit_timer_cancel(state, actions, &count,
                                  SESSION_TIMER_TX_GUARD)) {
        return 0u;
    }
    direct_clear_pending_tx(state);
    if (event->data.tx.result != SESSION_TX_OK) {
        return direct_handle_tx_failure(state, workspace, tx_kind, tx_link,
                                        tx_scratch, tx_capacity, actions,
                                        count);
    }
    return direct_tx_ok(state, workspace, tx_kind, tx_link, tx_scratch,
                        tx_capacity, actions, count);
}

static uint8_t direct_handle_link_up(SessionState *state,
                                     uint8_t link_id,
                                     uint8_t *tx_scratch,
                                     uint8_t tx_capacity,
                                     SessionAction *actions)
{
    uint8_t count = 0u;

    if (link_id == SESSION_LINK_NONE) {
        return 0u;
    }
    if (state->link_up) {
        if (link_id == state->active_link) {
            return 0u;
        }
        if (!state->peer_ready || state->pending_tx_kind != DIRECT_TX_NONE) {
            direct_emit_close(actions, &count, link_id);
            return count;
        }
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_LIVENESS) ||
            !direct_send_text(state, "BUSY", tx_scratch, tx_capacity,
                              actions, &count, link_id, DIRECT_TX_BUSY)) {
            return 0u;
        }
        return count;
    }
    state->link_up = 1u;
    state->active_link = link_id;
    state->phase = SESSION_PHASE_HANDSHAKE;
    state->control_retries = 0u;
    if (!direct_send_hello(state, tx_scratch, tx_capacity, actions, &count)) {
        session_reset(state);
        return 0u;
    }
    return count;
}

static uint8_t direct_handle_hello(SessionState *state,
                                   const SessionEvent *event,
                                   uint8_t *tx_scratch,
                                   uint8_t tx_capacity,
                                   SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t owner = SESSION_COLOR_UNKNOWN;
    uint8_t local_color = state->local_color;
    uint8_t was_ready = state->peer_ready;
    uint8_t valid;

    if (state->config.role == SESSION_ROLE_HOST) {
        valid = netchess_direct_parse_guest_hello(
            (const char *)event->data.rx.payload);
    } else {
        valid = netchess_direct_parse_host_hello(
            (const char *)event->data.rx.payload, &owner);
    }
    if (!valid) {
        if (!direct_send_text(state, "BYE", tx_scratch, tx_capacity,
                              actions, &count, state->active_link,
                              DIRECT_TX_BYE)) {
            return direct_finish(state, actions, 0u, state->active_link);
        }
        return count;
    }
    if (state->config.role == SESSION_ROLE_GUEST) {
        local_color = (uint8_t)(owner ^ 1u);
        if (was_ready && state->local_color != local_color) {
            if (!direct_send_text(state, "BYE", tx_scratch, tx_capacity,
                                  actions, &count, state->active_link,
                                  DIRECT_TX_BYE)) {
                return direct_finish(state, actions, 0u,
                                     state->active_link);
            }
            return count;
        }
    }
    if (was_ready) {
        direct_arm_liveness(state, actions, &count);
        return count;
    }
    if (!direct_emit_timer_cancel(state, actions, &count,
                                  SESSION_TIMER_CONTROL)) {
        return 0u;
    }
    if (state->config.role == SESSION_ROLE_GUEST) {
        state->local_color = local_color;
        if (!direct_emit_side(state, actions, &count)) {
            return 0u;
        }
    }
    state->peer_ready = 1u;
    state->phase = state->phase == SESSION_PHASE_ACTIVE
                       ? SESSION_PHASE_ACTIVE
                       : SESSION_PHASE_READY;
    state->control_retries = 0u;
    state->pending_value = 0u;
    if (state->pending_tx_kind == DIRECT_TX_HELLO) {
        return count;
    }
    if (!direct_send_hello(state, tx_scratch, tx_capacity, actions, &count)) {
        return 0u;
    }
    return count;
}

static uint8_t direct_handle_start(SessionState *state,
                                   const SessionEvent *event,
                                   uint8_t *tx_scratch,
                                   uint8_t tx_capacity,
                                   SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t local_color;
    uint8_t owner;

    if (state->config.role == SESSION_ROLE_HOST || !state->peer_ready ||
        !netchess_direct_parse_start_white_owner(
            (const char *)event->data.rx.payload, &owner)) {
        return direct_send_text(state,
                                state->config.role == SESSION_ROLE_HOST
                                    ? "NACK GAME START HOST"
                                    : "NACK GAME START BAD",
                                tx_scratch, tx_capacity, actions, &count,
                                state->active_link, DIRECT_TX_NACK_START)
                   ? count
                   : 0u;
    }
    if (state->pending_control != 0u || state->pending_request_id != 0u) {
        return direct_send_text(state, "NACK GAME START BUSY", tx_scratch,
                                tx_capacity, actions, &count,
                                state->active_link, DIRECT_TX_NACK_START)
                   ? count
                   : 0u;
    }
    local_color = (uint8_t)(owner ^ 1u);
    if (state->phase == SESSION_PHASE_ACTIVE) {
        if (state->local_color != local_color) {
            state->local_color = local_color;
            if (!direct_emit_side(state, actions, &count)) {
                return 0u;
            }
        }
        state->pending_value = 1u;
        return direct_send_text(state, "ACK GAME START", tx_scratch,
                                tx_capacity, actions, &count,
                                state->active_link, DIRECT_TX_ACK_START)
                   ? count
                   : 0u;
    }
    if (state->phase != SESSION_PHASE_READY &&
        state->phase != SESSION_PHASE_OVER) {
        return direct_send_text(state, "NACK GAME START BAD", tx_scratch,
                                tx_capacity, actions, &count,
                                state->active_link, DIRECT_TX_NACK_START)
                   ? count
                   : 0u;
    }
    if (state->local_color != local_color) {
        state->local_color = local_color;
        if (!direct_emit_side(state, actions, &count)) {
            return 0u;
        }
    }
    state->pending_value = 0u;
    state->pending_control = SESSION_REQUEST_START;
    state->pending_origin = DIRECT_ORIGIN_REMOTE;
    if (!direct_send_text(state, "ACK GAME START", tx_scratch, tx_capacity,
                          actions, &count, state->active_link,
                          DIRECT_TX_ACK_START)) {
        return 0u;
    }
    return count;
}

static uint8_t direct_handle_move(SessionState *state,
                                  const SessionEvent *event,
                                  SessionWorkspace *workspace,
                                  uint8_t *tx_scratch,
                                  uint8_t tx_capacity,
                                  SessionAction *actions)
{
    char ply_text[6];
    char move[6];
    uint16_t ply;
    const uint8_t *move_ptr;
    uint8_t count = 0u;
    uint8_t move_length;

    if (!netchess_proto_parse_move((const char *)event->data.rx.payload,
                                   ply_text, sizeof(ply_text),
                                   move, sizeof(move), 0, 0u)) {
        return 0u;
    }
    ply = direct_parse_u16(ply_text);
    if (ply == 0u) {
        return 0u;
    }
    if (state->last_rx_kind == SESSION_REQUEST_MOVE &&
        state->last_value == ply &&
        state->last_result != SESSION_GAME_ACCEPTED) {
        return direct_send_value_reply(state, ply, direct_reason_reject, 6u, 0u,
                                       tx_scratch, tx_capacity, actions,
                                       &count, DIRECT_TX_NACK_MOVE)
                   ? count
                   : 0u;
    }
    if (ply <= state->current_ply) {
        return direct_send_value_reply(state, ply, 0, 0u, 1u, tx_scratch,
                                       tx_capacity, actions, &count,
                                       DIRECT_TX_ACK_MOVE)
                   ? count
                   : 0u;
    }
    if (state->pending_request_id != 0u) {
        return 0u;
    }
    if (state->phase != SESSION_PHASE_ACTIVE ||
        (state->pending_control != 0u &&
         state->pending_control != SESSION_REQUEST_MOVE)) {
        return direct_send_value_reply(state, ply, direct_reason_busy, 4u, 0u, tx_scratch,
                                       tx_capacity, actions, &count,
                                       DIRECT_TX_NACK_MOVE)
                   ? count
                   : 0u;
    }
    if (state->pending_control == SESSION_REQUEST_MOVE &&
        state->pending_request_id == 0u &&
        ply == (uint16_t)(state->pending_value + 1u)) {
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_CONTROL) ||
            !direct_emit_game(actions, &count, SESSION_DELIVER_LOCAL_MOVE, 0u,
                              state->pending_value,
                              (const uint8_t *)workspace->move,
                              direct_text_length(workspace->move))) {
            return 0u;
        }
        state->current_ply = state->pending_value;
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        session_clear_duplicate(state);
    } else if (state->pending_control == SESSION_REQUEST_MOVE &&
               state->pending_request_id == 0u) {
        return direct_send_value_reply(state, ply, direct_reason_busy, 4u, 0u, tx_scratch,
                                       tx_capacity, actions, &count,
                                       DIRECT_TX_NACK_MOVE)
                   ? count
                   : 0u;
    }
    if (ply != (uint16_t)(state->current_ply + 1u)) {
        static const uint8_t sync[] = "SYNC";
        return direct_send_value_reply(state, ply, sync, 4u, 0u, tx_scratch,
                                       tx_capacity, actions, &count,
                                       DIRECT_TX_NACK_MOVE)
                   ? count
                   : 0u;
    }
    move_ptr = event->data.rx.payload + 5u;
    while (*move_ptr >= '0' && *move_ptr <= '9') {
        ++move_ptr;
    }
    ++move_ptr;
    move_length = direct_text_length(move);
    state->pending_request_id = session_next_delivery_id(state);
    state->pending_control = SESSION_REQUEST_MOVE;
    state->pending_origin = DIRECT_ORIGIN_REMOTE;
    state->pending_value = ply;
    state->control_retries = 0u;
    if (!direct_emit_timer_cancel(state, actions, &count,
                                  SESSION_TIMER_LIVENESS) ||
        !direct_emit_game(actions, &count, SESSION_DELIVER_REMOTE_MOVE,
                          state->delivery_id, ply, move_ptr, move_length) ||
        !direct_emit_timer_set(state, actions, &count, SESSION_TIMER_CONTROL,
                               SESSION_DIRECT_REPLY_TICKS)) {
        return 0u;
    }
    return count;
}

static uint8_t direct_send_duplicate_reply(SessionState *state,
                                           uint8_t control,
                                           uint16_t value,
                                           uint8_t accepted,
                                           uint8_t *tx_scratch,
                                           uint8_t tx_capacity,
                                           SessionAction *actions,
                                           uint8_t *count)
{
    const char *text;

    if (control == SESSION_REQUEST_TAKEBACK) {
        return direct_send_value_reply(state, value, 0, 0u, accepted,
                                       tx_scratch, tx_capacity, actions,
                                       count, DIRECT_TX_NACK_MOVE);
    }
    if (control == SESSION_REQUEST_RESET) {
        text = accepted ? "ACK RESET" : "NACK RESET";
    } else if (control == SESSION_REQUEST_DRAW) {
        text = accepted ? "ACK DRAW" : "NACK DRAW";
    } else if (control == SESSION_REQUEST_RESTORE) {
        text = accepted ? "RY" : "RN";
    } else {
        return 0u;
    }
    return direct_send_text(state, text, tx_scratch, tx_capacity, actions,
                            count, state->active_link,
                            DIRECT_TX_NACK_RESET_BUSY);
}

static uint8_t direct_begin_decision(SessionState *state,
                                     uint8_t control,
                                     uint16_t value,
                                     uint8_t *tx_scratch,
                                     uint8_t tx_capacity,
                                     SessionAction *actions)
{
    uint8_t count = 0u;

    if (state->pending_request_id != 0u) {
        return 0u;
    }
    if (state->last_rx_kind == control && state->last_value == value &&
        state->last_result != 0u) {
        return direct_send_duplicate_reply(
                   state,
                   control,
                   value,
                   (uint8_t)(state->last_result == SESSION_DECISION_ACCEPT ||
                             state->last_result == SESSION_GAME_ACCEPTED),
                   tx_scratch,
                   tx_capacity,
                   actions,
                   &count)
                   ? count
                   : 0u;
    }
    if (control == SESSION_REQUEST_TAKEBACK &&
        value != state->current_ply) {
        return direct_send_value_reply(state, value, 0, 0u, 0u,
                                       tx_scratch, tx_capacity, actions,
                                       &count, DIRECT_TX_NACK_MOVE)
                   ? count
                   : 0u;
    }
    if (control == SESSION_REQUEST_TAKEBACK &&
        state->last_rx_kind == SESSION_REQUEST_TAKEBACK &&
        state->last_value != value &&
        state->last_result == SESSION_GAME_ACCEPTED) {
        return direct_send_value_reply(state, value, 0, 0u, 0u,
                                       tx_scratch, tx_capacity, actions,
                                       &count, DIRECT_TX_NACK_MOVE)
                   ? count
                   : 0u;
    }
    if (control == SESSION_REQUEST_RESET &&
        state->phase != SESSION_PHASE_ACTIVE &&
        state->phase != SESSION_PHASE_OVER) {
        return direct_send_text(state, "NACK RESET START", tx_scratch,
                                tx_capacity, actions, &count,
                                state->active_link,
                                DIRECT_TX_NACK_RESET_BUSY)
                   ? count
                   : 0u;
    }
    if (control == SESSION_REQUEST_DRAW &&
        state->phase != SESSION_PHASE_ACTIVE) {
        return direct_send_text(state, "NACK DRAW", tx_scratch, tx_capacity,
                                actions, &count, state->active_link,
                                DIRECT_TX_NACK_RESET_BUSY)
                   ? count
                   : 0u;
    }
    if (control == SESSION_REQUEST_TAKEBACK &&
        state->phase != SESSION_PHASE_ACTIVE) {
        return direct_send_value_reply(state, value, 0, 0u, 0u, tx_scratch,
                                       tx_capacity, actions, &count,
                                       DIRECT_TX_NACK_MOVE)
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
        state->pending_origin = DIRECT_ORIGIN_REMOTE;
        state->pending_value = 0u;
        state->last_rx_kind = SESSION_REQUEST_RESET;
        state->last_value = 0u;
        state->last_result = SESSION_DECISION_ACCEPT;
        return direct_emit_timer_cancel(state, actions, &count,
                                        SESSION_TIMER_LIVENESS) &&
                       direct_send_text(state, "ACK RESET", tx_scratch,
                                        tx_capacity, actions, &count,
                                        state->active_link,
                                        DIRECT_TX_ACK_RESET)
                   ? count
                   : 0u;
    }
    if (state->pending_control != 0u || state->pending_request_id != 0u) {
        if (control == SESSION_REQUEST_DRAW &&
            state->pending_control == SESSION_REQUEST_DRAW &&
            state->pending_origin == DIRECT_ORIGIN_LOCAL &&
            state->pending_request_id == 0u) {
            if (!direct_emit_timer_cancel(state, actions, &count,
                                          SESSION_TIMER_CONTROL) ||
                !direct_send_text(state, "ACK DRAW", tx_scratch, tx_capacity,
                                  actions, &count, state->active_link,
                                  DIRECT_TX_ACK_DRAW_CROSSED)) {
                return 0u;
            }
            state->last_rx_kind = SESSION_REQUEST_DRAW;
            state->last_value = 0u;
            state->last_result = SESSION_DECISION_ACCEPT;
            return count;
        }
        if (control == SESSION_REQUEST_RESET &&
            state->pending_control == SESSION_REQUEST_RESET &&
            state->pending_request_id == 0u &&
            state->phase == SESSION_PHASE_OVER) {
            if (!direct_emit_timer_cancel(state, actions, &count,
                                          SESSION_TIMER_CONTROL) ||
                !direct_send_text(state, "ACK RESET", tx_scratch,
                                  tx_capacity, actions, &count,
                                  state->active_link,
                                  DIRECT_TX_ACK_RESET_CROSSED)) {
                return 0u;
            }
            state->last_rx_kind = SESSION_REQUEST_RESET;
            state->last_value = 0u;
            state->last_result = SESSION_DECISION_ACCEPT;
            return count;
        }
        if (control == SESSION_REQUEST_RESET) {
            return direct_send_text(state, "NACK RESET BUSY", tx_scratch,
                                    tx_capacity, actions, &count,
                                    state->active_link,
                                    DIRECT_TX_NACK_RESET_BUSY)
                       ? count
                       : 0u;
        }
        if (control == SESSION_REQUEST_DRAW) {
            return direct_send_text(state, "NACK DRAW", tx_scratch,
                                    tx_capacity, actions, &count,
                                    state->active_link,
                                    DIRECT_TX_NACK_RESET_BUSY)
                       ? count
                       : 0u;
        }
        if (control == SESSION_REQUEST_TAKEBACK) {
            return direct_send_value_reply(state, value, 0, 0u, 0u,
                                           tx_scratch, tx_capacity, actions,
                                           &count, DIRECT_TX_NACK_MOVE)
                       ? count
                       : 0u;
        }
        return 0u;
    }
    state->pending_request_id = session_next_delivery_id(state);
    state->pending_control = control;
    state->pending_origin = DIRECT_ORIGIN_REMOTE;
    state->pending_value = value;
    if (!direct_emit_decision(actions, &count, state->delivery_id,
                              control, value)) {
        return 0u;
    }
    return count;
}

static uint8_t direct_handle_numeric_ack(SessionState *state,
                                         const uint8_t *payload,
                                         uint8_t length,
                                         SessionWorkspace *workspace,
                                         SessionAction *actions)
{
    char value_text[6];
    char detail[16];
    const uint8_t *detail_ptr;
    uint16_t value;
    uint8_t count = 0u;
    uint8_t detail_length;

    if (!netchess_proto_parse_ack((const char *)payload,
                                  value_text, sizeof(value_text),
                                  detail, sizeof(detail))) {
        return 0u;
    }
    value = direct_parse_u16(value_text);
    if (state->pending_control == SESSION_REQUEST_MOVE &&
        state->pending_origin == DIRECT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u &&
        value == state->pending_value) {
        direct_emit_timer_cancel(state, actions, &count,
                                 SESSION_TIMER_CONTROL);
        state->current_ply = value;
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        session_clear_duplicate(state);
        detail_ptr = payload + 4u;
        while (detail_ptr < payload + length &&
               *detail_ptr >= '0' && *detail_ptr <= '9') {
            ++detail_ptr;
        }
        if (detail_ptr < payload + length && *detail_ptr == ' ') {
            ++detail_ptr;
        }
        detail_length = (uint8_t)((payload + length) - detail_ptr);
        direct_emit_game(actions, &count, SESSION_DELIVER_LOCAL_MOVE,
                         0u, value, (const uint8_t *)workspace->move,
                         direct_text_length(workspace->move));
        direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_ACCEPTED, SESSION_REQUEST_MOVE,
                         detail_ptr,
                         detail_length);
        direct_arm_liveness(state, actions, &count);
    } else if (state->pending_control == SESSION_REQUEST_TAKEBACK &&
               state->pending_origin == DIRECT_ORIGIN_LOCAL &&
               state->pending_request_id == 0u &&
               value == state->pending_value) {
        direct_emit_timer_cancel(state, actions, &count,
                                 SESSION_TIMER_CONTROL);
        state->pending_request_id = session_next_delivery_id(state);
        direct_emit_game(actions, &count, SESSION_DELIVER_TAKEBACK,
                         state->delivery_id, value, 0, 0u);
        direct_emit_timer_set(state, actions, &count, SESSION_TIMER_CONTROL,
                              SESSION_DIRECT_REPLY_TICKS);
    }
    return count;
}

static uint8_t direct_handle_numeric_nack(SessionState *state,
                                          const uint8_t *payload,
                                          uint8_t length,
                                          SessionAction *actions)
{
    char value_text[6];
    char reason[16];
    uint16_t value;
    uint8_t count = 0u;

    if (!netchess_proto_parse_nack((const char *)payload,
                                   value_text, sizeof(value_text),
                                   reason, sizeof(reason))) {
        return 0u;
    }
    value = direct_parse_u16(value_text);
    if (state->pending_control == SESSION_REQUEST_MOVE &&
        state->pending_origin == DIRECT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u &&
        value == state->pending_value &&
        direct_text_equal((const uint8_t *)reason,
                          direct_text_length(reason), "BUSY")) {
        direct_emit_timer_set(state, actions, &count, SESSION_TIMER_CONTROL,
                              SESSION_DIRECT_REPLY_TICKS);
        return count;
    }
    if (state->pending_control == SESSION_REQUEST_MOVE &&
        state->pending_origin == DIRECT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u &&
        value == state->pending_value) {
        direct_emit_timer_cancel(state, actions, &count,
                                 SESSION_TIMER_CONTROL);
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_REJECTED, SESSION_REQUEST_MOVE,
                         payload, length);
        direct_arm_liveness(state, actions, &count);
    } else if (state->pending_control == SESSION_REQUEST_TAKEBACK &&
               state->pending_origin == DIRECT_ORIGIN_LOCAL &&
               state->pending_request_id == 0u &&
               value == state->pending_value) {
        direct_emit_timer_cancel(state, actions, &count,
                                 SESSION_TIMER_CONTROL);
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_REJECTED, SESSION_REQUEST_TAKEBACK,
                         payload, length);
        direct_arm_liveness(state, actions, &count);
    }
    return count;
}

static uint8_t direct_handle_control_request_rx(SessionState *state,
                                                const SessionEvent *event,
                                                uint8_t *tx_scratch,
                                                uint8_t tx_capacity,
                                                SessionAction *actions)
{
    const uint8_t *payload = event->data.rx.payload;
    uint8_t length = event->data.rx.length;
    uint8_t count = 0u;
    const char *takeback;
    uint16_t value;

    if (direct_text_equal(payload, length, NETCHESS_PROTO_CANCEL_RESET) ||
        direct_text_equal(payload, length, NETCHESS_PROTO_CANCEL_DRAW)) {
        uint8_t control = payload[7] == 'R' ? SESSION_REQUEST_RESET
                                            : SESSION_REQUEST_DRAW;
        uint8_t matched = (uint8_t)(
            state->pending_control == control &&
            state->pending_origin == DIRECT_ORIGIN_REMOTE &&
            state->pending_request_id != 0u);

        if (matched) {
            state->pending_request_id = 0u;
            state->pending_value = DIRECT_CANCEL_REMOTE;
            return direct_send_control_reply(state, control, 0u,
                                             tx_scratch, tx_capacity,
                                             actions, &count)
                       ? count : 0u;
        }
        return direct_send_text(state,
                                control == SESSION_REQUEST_RESET
                                    ? "NACK RESET" : "NACK DRAW",
                                tx_scratch, tx_capacity, actions, &count,
                                state->active_link,
                                DIRECT_TX_NACK_RESET_BUSY)
                   ? count : 0u;
    }
    if (direct_text_equal(payload, length, "RESET")) {
        return direct_begin_decision(state, SESSION_REQUEST_RESET, 0u,
                                     tx_scratch, tx_capacity, actions);
    }
    if (direct_text_equal(payload, length, "DRAW")) {
        return direct_begin_decision(state, SESSION_REQUEST_DRAW, 0u,
                                     tx_scratch, tx_capacity, actions);
    }
    if (direct_text_equal(payload, length, "RESIGN")) {
        uint8_t duplicate;

        if (state->pending_tx_kind != DIRECT_TX_NONE || tx_scratch == 0 ||
            tx_capacity < 11u) {
            return 0u;
        }
        duplicate = (uint8_t)(
            state->last_rx_kind == SESSION_REQUEST_RESIGN &&
            state->last_result != 0u);
        if (state->phase == SESSION_PHASE_OVER) {
            uint8_t tx_kind =
                state->pending_control == SESSION_REQUEST_RESIGN &&
                        state->pending_origin == DIRECT_ORIGIN_LOCAL
                    ? DIRECT_TX_ACK_RESIGN_CROSSED
                    : DIRECT_TX_NACK_RESET_BUSY;

            state->last_rx_kind = SESSION_REQUEST_RESIGN;
            state->last_value = 0u;
            state->last_result = SESSION_DECISION_ACCEPT;
            if (tx_kind == DIRECT_TX_ACK_RESIGN_CROSSED &&
                !direct_emit_timer_cancel(state, actions, &count,
                                          SESSION_TIMER_CONTROL)) {
                return 0u;
            }
            return direct_send_text(state, "ACK RESIGN", tx_scratch,
                                    tx_capacity, actions, &count,
                                    state->active_link, tx_kind)
                       ? count
                       : 0u;
        }
        if (duplicate) {
            return direct_send_text(state, "ACK RESIGN", tx_scratch,
                                    tx_capacity, actions, &count,
                                    state->active_link,
                                    DIRECT_TX_NACK_RESET_BUSY)
                       ? count
                       : 0u;
        }
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_CONTROL) ||
            !direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->restore_phase = DIRECT_RESTORE_NONE;
        state->restore_mask = 0u;
        state->pending_request_id = session_next_delivery_id(state);
        state->pending_control = SESSION_REQUEST_RESIGN;
        state->pending_origin = DIRECT_ORIGIN_REMOTE;
        state->last_rx_kind = SESSION_REQUEST_RESIGN;
        state->last_result = SESSION_DECISION_ACCEPT;
        return direct_send_text(state, "ACK RESIGN", tx_scratch, tx_capacity,
                                actions, &count, state->active_link,
                                DIRECT_TX_ACK_RESIGN)
                   ? count
                   : 0u;
    }
    takeback = netchess_after_prefix((const char *)payload, "TAKEBACK ");
    if (takeback != 0) {
        value = direct_parse_u16(takeback);
        if (value != 0u) {
            return direct_begin_decision(state, SESSION_REQUEST_TAKEBACK,
                                         value, tx_scratch, tx_capacity,
                                         actions);
        }
        return 0u;
    }
    return DIRECT_RX_UNHANDLED;
}

static uint8_t direct_handle_restore_rx(SessionState *state,
                                        const SessionEvent *event,
                                        SessionWorkspace *workspace,
                                        uint8_t *tx_scratch,
                                        uint8_t tx_capacity,
                                        SessionAction *actions)
{
    const uint8_t *payload = event->data.rx.payload;
    uint8_t length = event->data.rx.length;
    uint8_t count = 0u;

    if (direct_text_equal(payload, length, "RQ")) {
        if (state->config.role == SESSION_ROLE_HOST) {
            return direct_send_text(state, "RN", tx_scratch, tx_capacity,
                                    actions, &count, state->active_link,
                                    DIRECT_TX_RN_BUSY)
                       ? count
                       : 0u;
        }
        if (state->restore_phase == DIRECT_RESTORE_APPLIED) {
            state->restore_phase = DIRECT_RESTORE_NONE;
            state->restore_mask = 0u;
            if (state->last_rx_kind == SESSION_REQUEST_RESTORE) {
                session_clear_duplicate(state);
            }
        }
        if (state->pending_control == SESSION_REQUEST_RESTORE &&
            state->pending_origin == DIRECT_ORIGIN_REMOTE) {
            if (state->pending_request_id != 0u) {
                return 0u;
            }
            if (state->restore_phase == DIRECT_RESTORE_RECEIVE) {
                return direct_send_text(state, "RY", tx_scratch,
                                        tx_capacity, actions, &count,
                                        state->active_link,
                                        DIRECT_TX_NACK_RESET_BUSY)
                           ? count
                           : 0u;
            }
        }
        if (state->pending_control != 0u ||
            state->pending_request_id != 0u) {
            return direct_send_text(state, "RN", tx_scratch, tx_capacity,
                                    actions, &count, state->active_link,
                                    DIRECT_TX_RN_BUSY)
                       ? count
                       : 0u;
        }
        return direct_begin_decision(state, SESSION_REQUEST_RESTORE, 0u,
                                     tx_scratch, tx_capacity, actions);
    }
    if (direct_text_equal(payload, length, "RY") &&
        state->restore_phase == DIRECT_RESTORE_WAIT_RY &&
        state->pending_control == SESSION_REQUEST_RESTORE &&
        state->pending_origin == DIRECT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u) {
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->restore_phase = DIRECT_RESTORE_WAIT_RA;
        state->control_retries = 0u;
        if (!direct_send_restore_chunk(state, workspace, 0u, tx_scratch,
                                       tx_capacity, actions, &count)) {
            return 0u;
        }
        return count;
    }
    if (direct_text_equal(payload, length, "RN") &&
        state->pending_control == SESSION_REQUEST_RESTORE &&
        state->pending_origin == DIRECT_ORIGIN_REMOTE &&
        (state->pending_request_id != 0u ||
         state->restore_phase == DIRECT_RESTORE_RECEIVE)) {
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_request_id = 0u;
        state->pending_value = 0u;
        state->restore_phase = DIRECT_RESTORE_NONE;
        state->restore_mask = 0u;
        session_clear_duplicate(state);
        if (!direct_emit_game(actions, &count,
                              SESSION_DELIVER_CONTROL_RESULT,
                              SESSION_CONTROL_REJECTED,
                              SESSION_REQUEST_RESTORE, payload, length) ||
            !direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        return count;
    }
    if (direct_text_equal(payload, length, "RN") &&
        state->pending_control == SESSION_REQUEST_RESTORE &&
        state->pending_origin == DIRECT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u) {
        direct_emit_timer_cancel(state, actions, &count, SESSION_TIMER_CONTROL);
        direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_REJECTED,
                         SESSION_REQUEST_RESTORE, payload, length);
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_value = 0u;
        state->restore_phase = DIRECT_RESTORE_NONE;
        state->restore_mask = 0u;
        direct_arm_liveness(state, actions, &count);
        return count;
    }
    if (direct_text_equal(payload, length, "RA") &&
        state->restore_phase == DIRECT_RESTORE_WAIT_RA &&
        state->pending_control == SESSION_REQUEST_RESTORE &&
        state->pending_origin == DIRECT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u) {
        direct_emit_timer_cancel(state, actions, &count, SESSION_TIMER_CONTROL);
        state->phase =
            (uint8_t)(state->restore_mask >> DIRECT_RESTORE_PHASE_SHIFT);
        state->current_ply = state->pending_value;
        direct_emit_game(actions, &count, SESSION_DELIVER_RESTORE, 0u,
                         state->current_ply, workspace->restore,
                         SESSION_RESTORE_BYTES);
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_value = 0u;
        state->restore_phase = DIRECT_RESTORE_NONE;
        state->restore_mask = 0u;
        session_clear_duplicate(state);
        direct_arm_liveness(state, actions, &count);
        return count;
    }
    if (length == 35u &&
        (direct_text_prefix(payload, length, "RS00 ") ||
         direct_text_prefix(payload, length, "RS01 ")) &&
        state->restore_phase == DIRECT_RESTORE_APPLIED) {
        uint8_t chunk = (uint8_t)(payload[3] - '0');

        if (!session_restore_chunk_matches(workspace, payload, chunk)) {
            state->restore_phase = DIRECT_RESTORE_NONE;
            state->restore_mask = 0u;
            session_clear_duplicate(state);
            return direct_send_text(state, "RN", tx_scratch,
                                    tx_capacity, actions, &count,
                                    state->active_link,
                                    DIRECT_TX_RN_BUSY)
                       ? count
                       : 0u;
        }
        return direct_send_text(state, "RA", tx_scratch, tx_capacity,
                                actions, &count, state->active_link,
                                DIRECT_TX_RA)
                   ? count
                   : 0u;
    }
    if (length == 35u &&
        (direct_text_prefix(payload, length, "RS00 ") ||
         direct_text_prefix(payload, length, "RS01 ")) &&
        state->restore_phase == DIRECT_RESTORE_RECEIVE) {
        uint8_t chunk = (uint8_t)(payload[3] - '0');

        if (state->pending_request_id != 0u) {
            if (!session_restore_chunk_matches(workspace, payload, chunk)) {
                return 0u;
            }
            return direct_emit_timer_set(state, actions, &count,
                                         SESSION_TIMER_CONTROL,
                                         SESSION_DIRECT_REPLY_TICKS)
                       ? count
                       : 0u;
        }
        session_store_restore_chunk(workspace, payload, chunk);
        state->control_retries = 0u;
        state->restore_mask |= (uint8_t)(1u << chunk);
        if ((state->restore_mask & DIRECT_RESTORE_CHUNK_MASK) ==
                DIRECT_RESTORE_CHUNK_MASK &&
            state->pending_request_id == 0u) {
            state->pending_request_id = session_next_delivery_id(state);
            if (!direct_emit_game(actions, &count, SESSION_DELIVER_RESTORE,
                                  state->delivery_id, 0u, workspace->restore,
                                  SESSION_RESTORE_BYTES)) {
                return 0u;
            }
        }
        direct_emit_timer_set(state, actions, &count, SESSION_TIMER_CONTROL,
                              SESSION_DIRECT_REPLY_TICKS);
        return count;
    }
    if (length == 35u &&
        (direct_text_prefix(payload, length, "RS00 ") ||
         direct_text_prefix(payload, length, "RS01 "))) {
        return direct_send_text(state, "RN", tx_scratch, tx_capacity,
                                actions, &count, state->active_link,
                                DIRECT_TX_RN_BUSY)
                   ? count
                   : 0u;
    }
    return DIRECT_RX_UNHANDLED;
}

static uint8_t direct_handle_control_reply_rx(SessionState *state,
                                              const SessionEvent *event,
                                              SessionWorkspace *workspace,
                                              uint8_t *tx_scratch,
                                              uint8_t tx_capacity,
                                              SessionAction *actions)
{
    const uint8_t *payload = event->data.rx.payload;
    uint8_t length = event->data.rx.length;
    uint8_t count = 0u;

    if (direct_text_equal(payload, length, "ACK RESET") &&
        state->pending_control == SESSION_REQUEST_RESET &&
        state->pending_origin == DIRECT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u) {
        direct_emit_timer_cancel(state, actions, &count, SESSION_TIMER_CONTROL);
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_value = 0u;
        state->phase = SESSION_PHASE_ACTIVE;
        state->current_ply = 0u;
        session_clear_duplicate(state);
        direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_ACCEPTED,
                         SESSION_REQUEST_RESET, 0, 0u);
        direct_emit_session(actions, &count, SESSION_CHANGED_STARTED);
        direct_arm_liveness(state, actions, &count);
        return count;
    }
    if (direct_text_equal(payload, length, "ACK DRAW")) {
        if (state->pending_control != SESSION_REQUEST_DRAW ||
            state->pending_origin != DIRECT_ORIGIN_LOCAL ||
            state->pending_request_id != 0u) {
            return 0u;
        }
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->phase = SESSION_PHASE_OVER;
        state->pending_control = SESSION_REQUEST_RESET;
        state->pending_origin = DIRECT_ORIGIN_LOCAL;
        state->pending_value = 0u;
        state->control_retries = 0u;
        if (!direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL_RESULT,
                              SESSION_CONTROL_ACCEPTED,
                              SESSION_REQUEST_DRAW, 0, 0u) ||
            !direct_send_text(state, "RESET", tx_scratch, tx_capacity,
                              actions, &count, state->active_link,
                              DIRECT_TX_RESET)) {
            return 0u;
        }
        return count;
    }
    if (direct_text_equal(payload, length, "ACK RESIGN")) {
        if (state->pending_control == SESSION_REQUEST_RESIGN &&
            state->pending_origin == DIRECT_ORIGIN_LOCAL &&
            state->pending_request_id == 0u) {
            direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_CONTROL);
            state->pending_control = SESSION_REQUEST_RESET;
            state->pending_origin = DIRECT_ORIGIN_LOCAL;
            state->pending_value = 0u;
            state->control_retries = 0u;
            direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL_RESULT,
                             SESSION_CONTROL_ACCEPTED,
                             SESSION_REQUEST_RESIGN, 0, 0u);
            if (!direct_send_text(state, "RESET", tx_scratch, tx_capacity,
                                  actions, &count, state->active_link,
                                  DIRECT_TX_RESET)) {
                return 0u;
            }
        }
        return count;
    }
    if (direct_text_prefix(payload, length, "ACK ")) {
        return direct_handle_numeric_ack(state, payload, length, workspace,
                                         actions);
    }
    if (direct_text_prefix(payload, length, "NACK GAME START") &&
        state->pending_control == SESSION_REQUEST_START &&
        state->pending_origin == DIRECT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u) {
        direct_emit_timer_cancel(state, actions, &count, SESSION_TIMER_CONTROL);
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->phase = SESSION_PHASE_READY;
        direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL_RESULT,
                         SESSION_CONTROL_REJECTED,
                         SESSION_REQUEST_START, payload, length);
        direct_arm_liveness(state, actions, &count);
        return count;
    }
    if ((direct_text_prefix(payload, length, "NACK RESET") &&
         state->pending_control == SESSION_REQUEST_RESET &&
         state->pending_origin == DIRECT_ORIGIN_LOCAL &&
         state->pending_request_id == 0u) ||
        (direct_text_prefix(payload, length, "NACK DRAW") &&
         state->pending_control == SESSION_REQUEST_DRAW &&
         state->pending_origin == DIRECT_ORIGIN_LOCAL &&
         state->pending_request_id == 0u)) {
        uint8_t control = state->pending_control;
        uint8_t result = state->pending_value == DIRECT_CANCEL_SENT
                             ? SESSION_CONTROL_CANCELLED
                             : SESSION_CONTROL_REJECTED;

        direct_emit_timer_cancel(state, actions, &count, SESSION_TIMER_CONTROL);
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_value = 0u;
        direct_emit_game(actions, &count, SESSION_DELIVER_CONTROL_RESULT,
                         result,
                         control, payload, length);
        direct_arm_liveness(state, actions, &count);
        return count;
    }
    if (direct_text_prefix(payload, length, "NACK ")) {
        return direct_handle_numeric_nack(state, payload, length, actions);
    }
    return DIRECT_RX_UNHANDLED;
}

static uint8_t direct_handle_rx(SessionState *state,
                                const SessionEvent *event,
                                SessionWorkspace *workspace,
                                uint8_t *tx_scratch,
                                uint8_t tx_capacity,
                                SessionAction *actions)
{
    const uint8_t *payload = event->data.rx.payload;
    uint8_t length = event->data.rx.length;
    uint8_t count = 0u;

    if (event->data.rx.link_id == SESSION_LINK_NONE) {
        return 0u;
    }
    if (event->data.rx.link_id != state->active_link) {
        if (state->peer_ready && state->pending_tx_kind == DIRECT_TX_NONE) {
            if (direct_emit_timer_cancel(state, actions, &count,
                                         SESSION_TIMER_LIVENESS) &&
                direct_send_text(state, "BUSY", tx_scratch, tx_capacity,
                                 actions, &count, event->data.rx.link_id,
                                 DIRECT_TX_BUSY)) {
                return count;
            }
        }
        direct_emit_close(actions, &count, event->data.rx.link_id);
        return count;
    }
    if (!direct_slice_valid(payload, length)) {
        return 0u;
    }
    state->liveness_misses = 0u;

    if (state->peer_ready && direct_text_equal(payload, length, "PING")) {
        return direct_send_text(state, "ACK PING", tx_scratch, tx_capacity,
                                actions, &count, state->active_link,
                                DIRECT_TX_ACK_PING)
                   ? count
                   : 0u;
    }
    if (!state->peer_ready && direct_text_equal(payload, length, "PING")) {
        if (state->pending_tx_kind != DIRECT_TX_NONE ||
            !direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        return direct_send_text(state, "ACK PING", tx_scratch, tx_capacity,
                                actions, &count, state->active_link,
                                DIRECT_TX_ACK_PING)
                   ? count
                   : 0u;
    }
    if (state->peer_ready &&
        direct_text_equal(payload, length, "ACK PING")) {
        if (!direct_rearm_liveness_after_rx(state, actions, &count)) {
            return 0u;
        }
        return count;
    }
    if (direct_text_prefix(payload, length, "HELLO DIRECT ")) {
        return direct_handle_hello(state, event, tx_scratch, tx_capacity,
                                   actions);
    }
    if (!state->peer_ready) {
        if (direct_text_equal(payload, length, "BUSY")) {
            uint8_t timer_id;

            for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
                if (!direct_emit_timer_cancel(state, actions, &count,
                                              timer_id)) {
                    return 0u;
                }
            }
            if (!direct_emit_session(actions, &count, SESSION_CHANGED_BUSY) ||
                !direct_emit_close(actions, &count, state->active_link) ||
                !direct_emit_session(actions, &count, SESSION_CHANGED_ENDED)) {
                return 0u;
            }
            session_reset(state);
            return count;
        }
        return 0u;
    }
    if (direct_text_equal(payload, length, "BYE")) {
        return direct_finish(state, actions, 0u, state->active_link);
    }
    if (state->pending_tx_kind != DIRECT_TX_NONE) {
        if (direct_text_prefix(payload, length, "CHAT ") && length > 5u &&
            length <= (uint8_t)(5u + SESSION_CHAT_TEXT_MAX)) {
            return direct_emit_game(actions, &count, SESSION_DELIVER_CHAT, 0u,
                                    SESSION_CHAT_REMOTE, payload + 5u,
                                    (uint8_t)(length - 5u))
                       ? count
                       : 0u;
        }
        return 0u;
    }
    if (direct_text_prefix(payload, length, "GAME START")) {
        return direct_handle_start(state, event, tx_scratch, tx_capacity,
                                   actions);
    }
    if (direct_text_equal(payload, length, "ACK GAME START")) {
        if (state->pending_control != SESSION_REQUEST_START ||
            state->pending_origin != DIRECT_ORIGIN_LOCAL ||
            state->pending_request_id != 0u) {
            return 0u;
        }
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->phase = SESSION_PHASE_ACTIVE;
        state->current_ply = 0u;
        if (!direct_emit_session(actions, &count, SESSION_CHANGED_STARTED) ||
            !direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        return count;
    }
    if (direct_text_prefix(payload, length, "MOVE ")) {
        return direct_handle_move(state, event, workspace, tx_scratch,
                                  tx_capacity, actions);
    }
    {
        uint8_t result = direct_handle_control_request_rx(
            state, event, tx_scratch, tx_capacity, actions);

        if (result != DIRECT_RX_UNHANDLED) {
            return result;
        }
    }
    {
        uint8_t result = direct_handle_restore_rx(
            state, event, workspace, tx_scratch, tx_capacity, actions);

        if (result != DIRECT_RX_UNHANDLED) {
            return result;
        }
    }
    {
        uint8_t result = direct_handle_control_reply_rx(
            state, event, workspace, tx_scratch, tx_capacity, actions);

        if (result != DIRECT_RX_UNHANDLED) {
            return result;
        }
    }
    if (direct_text_prefix(payload, length, "CHAT ") && length > 5u &&
        length <= (uint8_t)(5u + SESSION_CHAT_TEXT_MAX)) {
        direct_emit_game(actions, &count, SESSION_DELIVER_CHAT, 0u,
                         SESSION_CHAT_REMOTE,
                         payload + 5u, (uint8_t)(length - 5u));
        direct_arm_liveness(state, actions, &count);
        return count;
    }
    direct_arm_liveness(state, actions, &count);
    return count;
}

static uint8_t direct_handle_local(SessionState *state,
                                   const SessionEvent *event,
                                   SessionWorkspace *workspace,
                                   uint8_t *tx_scratch,
                                   uint8_t tx_capacity,
                                   SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t i;

    if (event->data.local.request == SESSION_REQUEST_RESTORE &&
        event->data.local.length == 0u) {
        if (state->pending_control != SESSION_REQUEST_RESTORE ||
            state->pending_origin != DIRECT_ORIGIN_LOCAL ||
            state->pending_tx_kind != DIRECT_TX_NONE ||
            state->restore_phase != DIRECT_RESTORE_WAIT_RY) {
            return 0u;
        }
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        return direct_send_text(state, "RN", tx_scratch, tx_capacity,
                                actions, &count, state->active_link,
                                DIRECT_TX_RN)
                   ? count
                   : 0u;
    }
    if (event->data.local.request == SESSION_REQUEST_BYE) {
        if (!state->link_up ||
            state->pending_tx_kind != DIRECT_TX_NONE ||
            !direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        return direct_send_text(state, "BYE", tx_scratch, tx_capacity,
                                actions, &count, state->active_link,
                                DIRECT_TX_BYE)
                   ? count
                   : 0u;
    }
    if (event->data.local.request == SESSION_REQUEST_RESIGN &&
        state->pending_control == SESSION_REQUEST_MOVE &&
        state->pending_origin == DIRECT_ORIGIN_LOCAL &&
        state->pending_request_id == 0u &&
        state->pending_tx_kind == DIRECT_TX_NONE) {
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_CONTROL)) {
            return 0u;
        }
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        state->pending_value = 0u;
    }
    if (!state->peer_ready || state->pending_tx_kind != DIRECT_TX_NONE ||
        (state->pending_control != 0u &&
         event->data.local.request != SESSION_REQUEST_CHAT)) {
        return 0u;
    }
    switch (event->data.local.request) {
    case SESSION_REQUEST_START:
        if (state->config.role != SESSION_ROLE_HOST ||
            state->phase != SESSION_PHASE_READY) {
            return 0u;
        }
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        state->pending_control = SESSION_REQUEST_START;
        state->pending_origin = DIRECT_ORIGIN_LOCAL;
        state->control_retries = 0u;
        return direct_send_start(state, tx_scratch, tx_capacity, actions,
                                 &count)
                   ? count
                   : 0u;
    case SESSION_REQUEST_MOVE:
        if (state->phase != SESSION_PHASE_ACTIVE ||
            !direct_slice_valid(event->data.local.payload,
                                event->data.local.length) ||
            state->current_ply == 65535u ||
            (event->data.local.length != 4u &&
             event->data.local.length != 5u)) {
            return 0u;
        }
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        session_drop_restore_cache(state);
        for (i = 0u; i < event->data.local.length; ++i) {
            workspace->move[i] = (char)event->data.local.payload[i];
        }
        workspace->move[event->data.local.length] = '\0';
        state->pending_control = SESSION_REQUEST_MOVE;
        state->pending_origin = DIRECT_ORIGIN_LOCAL;
        state->pending_value = (uint16_t)(state->current_ply + 1u);
        state->control_retries = 0u;
        return direct_send_move(state, workspace, tx_scratch, tx_capacity,
                                actions, &count)
                   ? count
                   : 0u;
    case SESSION_REQUEST_CHAT:
        if (state->pending_control == SESSION_REQUEST_MOVE ||
            state->pending_control == SESSION_REQUEST_RESTORE ||
            event->data.local.length > SESSION_CHAT_TEXT_MAX ||
            !direct_slice_valid(event->data.local.payload,
                                event->data.local.length) ||
            !netchess_proto_format_chat((char *)tx_scratch, tx_capacity,
                                        (const char *)event->data.local.payload) ||
            !direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        session_drop_restore_cache(state);
        for (i = 0u; i <= event->data.local.length; ++i) {
            workspace->chat[i] = (char)event->data.local.payload[i];
        }
        return direct_send_buffer(state, tx_scratch, tx_capacity, actions,
                                  &count, state->active_link, DIRECT_TX_CHAT)
                   ? count
                   : 0u;
    case SESSION_REQUEST_RESET:
    case SESSION_REQUEST_DRAW:
    case SESSION_REQUEST_RESIGN:
    case SESSION_REQUEST_TAKEBACK:
        if ((event->data.local.request == SESSION_REQUEST_RESET
                 ? (state->phase != SESSION_PHASE_ACTIVE &&
                    state->phase != SESSION_PHASE_OVER)
                 : state->phase != SESSION_PHASE_ACTIVE) ||
            (event->data.local.request == SESSION_REQUEST_TAKEBACK &&
             event->data.local.value == 0u)) {
            return 0u;
        }
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        state->pending_control = event->data.local.request;
        state->pending_origin = DIRECT_ORIGIN_LOCAL;
        state->pending_value = event->data.local.value;
        state->control_retries = 0u;
        return direct_send_local_pending(state, workspace, tx_scratch,
                                         tx_capacity, actions, &count)
                   ? count
                   : 0u;
    case SESSION_REQUEST_RESTORE:
        if (state->config.role != SESSION_ROLE_HOST ||
            event->data.local.length != SESSION_RESTORE_BYTES ||
            event->data.local.phase < SESSION_PHASE_READY ||
            event->data.local.phase > SESSION_PHASE_OVER ||
            !direct_fixed_slice_valid(event->data.local.payload,
                                      event->data.local.length)) {
            return 0u;
        }
        if (!direct_emit_timer_cancel(state, actions, &count,
                                      SESSION_TIMER_LIVENESS)) {
            return 0u;
        }
        session_drop_restore_cache(state);
        for (i = 0u; i < SESSION_RESTORE_BYTES; ++i) {
            workspace->restore[i] = event->data.local.payload[i];
        }
        state->pending_control = SESSION_REQUEST_RESTORE;
        state->pending_origin = DIRECT_ORIGIN_LOCAL;
        state->pending_value = event->data.local.value;
        state->restore_phase = DIRECT_RESTORE_WAIT_RY;
        state->restore_mask = (uint8_t)(
            event->data.local.phase << DIRECT_RESTORE_PHASE_SHIFT);
        state->control_retries = 0u;
        return direct_send_text(state, "RQ", tx_scratch, tx_capacity,
                                actions, &count, state->active_link,
                                DIRECT_TX_RQ)
                   ? count
                   : 0u;
    default:
        return 0u;
    }
}

static uint8_t direct_send_control_reply(SessionState *state,
                                         uint8_t control,
                                         uint8_t accepted,
                                         uint8_t *tx_scratch,
                                         uint8_t tx_capacity,
                                         SessionAction *actions,
                                         uint8_t *count)
{
    const char *text;
    uint8_t tx_kind;

    if (control == SESSION_REQUEST_TAKEBACK) {
        return direct_send_value_reply(
            state, state->pending_value, 0, 0u, accepted, tx_scratch,
            tx_capacity, actions, count,
            accepted ? DIRECT_TX_ACK_TAKEBACK : DIRECT_TX_NACK_TAKEBACK);
    }
    if (control == SESSION_REQUEST_RESTORE) {
        text = accepted ? "RY" : "RN";
        tx_kind = accepted ? DIRECT_TX_RY : DIRECT_TX_RN;
    } else if (control == SESSION_REQUEST_RESET) {
        text = accepted ? "ACK RESET" : "NACK RESET";
        tx_kind = accepted ? DIRECT_TX_ACK_RESET : DIRECT_TX_NACK_RESET;
    } else if (control == SESSION_REQUEST_DRAW) {
        text = accepted ? "ACK DRAW" : "NACK DRAW";
        tx_kind = accepted ? DIRECT_TX_ACK_DRAW : DIRECT_TX_NACK_DRAW;
    } else {
        return 0u;
    }
    return direct_send_text(state, text, tx_scratch, tx_capacity, actions,
                            count, state->active_link, tx_kind);
}

static uint8_t direct_apply_user_decision(SessionState *state,
                                          uint8_t decision,
                                          uint8_t *tx_scratch,
                                          uint8_t tx_capacity,
                                          SessionAction *actions,
                                          uint8_t *count)
{
    uint8_t accepted;
    uint8_t control;

    control = state->pending_control;
    accepted = (uint8_t)(decision == SESSION_DECISION_ACCEPT);
    if (!direct_emit_timer_cancel(state, actions, count,
                                  SESSION_TIMER_CONTROL)) {
        return 0u;
    }
    if (control == SESSION_REQUEST_TAKEBACK && accepted) {
        if (!direct_emit_game(actions, count, SESSION_DELIVER_TAKEBACK,
                              state->pending_request_id,
                              state->pending_value, 0, 0u) ||
            !direct_emit_timer_set(state, actions, count,
                                   SESSION_TIMER_CONTROL,
                                   SESSION_DIRECT_REPLY_TICKS)) {
            return 0u;
        }
        return 1u;
    }
    state->last_rx_kind = control;
    state->last_value = state->pending_value;
    state->last_result = accepted ? SESSION_DECISION_ACCEPT
                                  : SESSION_DECISION_REJECT;
    if (!direct_send_control_reply(state, control, accepted, tx_scratch,
                                   tx_capacity, actions, count)) {
        return 0u;
    }
    if (!accepted) {
        state->pending_request_id = 0u;
    }
    return 1u;
}

static uint8_t direct_handle_user_decision(SessionState *state,
                                           const SessionEvent *event,
                                           uint8_t *tx_scratch,
                                           uint8_t tx_capacity,
                                           SessionAction *actions)
{
    uint8_t count = 0u;

    if (state->pending_request_id == 0u ||
        event->data.user.request_id != state->pending_request_id ||
        (event->data.user.decision != SESSION_DECISION_ACCEPT &&
         event->data.user.decision != SESSION_DECISION_REJECT)) {
        return 0u;
    }
    if (state->pending_tx_kind != DIRECT_TX_NONE) {
        if ((state->pending_tx_kind == DIRECT_TX_PING ||
             state->pending_tx_kind == DIRECT_TX_ACK_PING ||
             state->pending_tx_kind == DIRECT_TX_NACK_START ||
             state->pending_tx_kind == DIRECT_TX_RN_BUSY) &&
            state->deferred_decision == 0u) {
            state->deferred_decision = event->data.user.decision;
        }
        return 0u;
    }
    if (!direct_apply_user_decision(state, event->data.user.decision,
                                    tx_scratch, tx_capacity, actions,
                                    &count)) {
        return 0u;
    }
    return count;
}

static uint8_t direct_handle_game_result(SessionState *state,
                                         const SessionEvent *event,
                                         uint8_t *tx_scratch,
                                         uint8_t tx_capacity,
                                         SessionAction *actions)
{
    uint8_t count = 0u;
    uint8_t accepted;
    const uint8_t *detail = direct_reason_reject;
    uint8_t detail_length = 6u;

    if (state->pending_tx_kind != DIRECT_TX_NONE ||
        state->pending_request_id == 0u ||
        event->data.game.delivery_id != state->pending_request_id ||
        (state->pending_control != SESSION_REQUEST_RESTORE &&
         event->data.game.value != state->pending_value) ||
        event->data.game.result < SESSION_GAME_ACCEPTED ||
        event->data.game.result > SESSION_GAME_FAILED) {
        return 0u;
    }
    accepted = (uint8_t)(event->data.game.result == SESSION_GAME_ACCEPTED);
    if (state->pending_control == SESSION_REQUEST_RESTORE && accepted) {
        if (event->data.game.detail == 0 ||
            event->data.game.detail_length != 1u ||
            event->data.game.detail[0] < SESSION_PHASE_READY ||
            event->data.game.detail[0] > SESSION_PHASE_OVER) {
            return 0u;
        }
    } else if (event->data.game.detail_length != 0u &&
               !direct_slice_valid(event->data.game.detail,
                                   event->data.game.detail_length)) {
        return 0u;
    }
    if (event->data.game.detail_length != 0u) {
        detail = event->data.game.detail;
        detail_length = event->data.game.detail_length;
    } else if (accepted) {
        detail = 0;
        detail_length = 0u;
    }
    if (!direct_emit_timer_cancel(state, actions, &count,
                                  SESSION_TIMER_CONTROL)) {
        return 0u;
    }
    if (state->pending_control == SESSION_REQUEST_MOVE) {
        if (accepted) {
            state->current_ply = state->pending_value;
        }
        state->last_rx_kind = SESSION_REQUEST_MOVE;
        state->last_value = state->pending_value;
        state->last_result = event->data.game.result;
        if (!direct_send_value_reply(
                state, state->pending_value,
                detail, detail_length,
                accepted, tx_scratch, tx_capacity, actions, &count,
                accepted ? DIRECT_TX_ACK_MOVE : DIRECT_TX_NACK_MOVE)) {
            return 0u;
        }
        state->pending_request_id = 0u;
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        return count;
    }
    if (state->pending_control == SESSION_REQUEST_TAKEBACK) {
        uint8_t origin = state->pending_origin;

        if (accepted) {
            state->current_ply = state->pending_value == 0u
                                     ? 0u
                                     : (uint16_t)(state->pending_value - 1u);
            session_clear_duplicate(state);
        }
        if (origin == DIRECT_ORIGIN_REMOTE) {
            state->last_rx_kind = SESSION_REQUEST_TAKEBACK;
            state->last_value = state->pending_value;
            state->last_result = event->data.game.result;
            if (!direct_send_value_reply(
                    state, state->pending_value, detail, detail_length,
                    accepted, tx_scratch, tx_capacity, actions, &count,
                    accepted ? DIRECT_TX_ACK_TAKEBACK
                             : DIRECT_TX_NACK_TAKEBACK)) {
                return 0u;
            }
            state->pending_request_id = 0u;
            return count;
        }
        state->pending_request_id = 0u;
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
        if (!direct_emit_game(actions, &count,
                              SESSION_DELIVER_CONTROL_RESULT,
                              accepted ? SESSION_CONTROL_ACCEPTED
                                       : SESSION_CONTROL_REJECTED,
                              SESSION_REQUEST_TAKEBACK,
                              accepted ? 0 : detail,
                              accepted ? 0u : detail_length) ||
            !direct_arm_liveness(state, actions, &count)) {
            return 0u;
        }
        return count;
    }
    if (state->pending_control == SESSION_REQUEST_RESTORE) {
        if (accepted) {
            state->phase = event->data.game.detail[0];
            state->pending_value = event->data.game.value;
            state->current_ply = event->data.game.value;
        }
        if (!direct_send_text(state, accepted ? "RA" : "RN", tx_scratch,
                              tx_capacity, actions, &count,
                              state->active_link,
                              accepted ? DIRECT_TX_RA : DIRECT_TX_RN)) {
            return 0u;
        }
        state->last_rx_kind = SESSION_REQUEST_RESTORE;
        state->last_result = event->data.game.result;
        return count;
    }
    return 0u;
}

static uint8_t direct_handle_tx_guard_timeout(SessionState *state,
                                              SessionWorkspace *workspace,
                                              uint8_t *tx_scratch,
                                              uint8_t tx_capacity,
                                              SessionAction *actions)
{
    uint8_t tx_kind = state->pending_tx_kind;
    uint8_t tx_link = state->tx_link;

    direct_clear_pending_tx(state);
    return direct_handle_tx_failure(state, workspace, tx_kind, tx_link,
                                    tx_scratch, tx_capacity, actions, 0u);
}

static uint8_t direct_handle_liveness_timeout(SessionState *state,
                                              uint8_t *tx_scratch,
                                              uint8_t tx_capacity,
                                              SessionAction *actions)
{
    uint8_t count = 0u;

    if (!state->peer_ready) {
        return 0u;
    }
    if (state->config.role == SESSION_ROLE_HOST) {
        ++state->liveness_misses;
        if (state->liveness_misses >= SESSION_DIRECT_PING_MISSES) {
            return direct_finish(state, actions, count, state->active_link);
        }
        direct_emit_timer_set(state, actions, &count,
                              SESSION_TIMER_LIVENESS,
                              SESSION_DIRECT_PING_TICKS);
        return count;
    }
    if (state->liveness_misses >= SESSION_DIRECT_PING_MISSES) {
        return direct_finish(state, actions, count, state->active_link);
    }
    ++state->liveness_misses;
    return direct_send_text(state, "PING", tx_scratch, tx_capacity,
                            actions, &count, state->active_link,
                            DIRECT_TX_PING)
               ? count
               : 0u;
}

static uint8_t direct_handle_handshake_timeout(SessionState *state,
                                               uint8_t *tx_scratch,
                                               uint8_t tx_capacity,
                                               SessionAction *actions)
{
    uint8_t count = 0u;

    if (state->control_retries >= SESSION_DIRECT_HELLO_RETRIES) {
        return direct_finish(state, actions, count, state->active_link);
    }
    ++state->control_retries;
    return direct_send_hello(state, tx_scratch, tx_capacity, actions,
                             &count)
               ? count
               : 0u;
}

static uint8_t direct_handle_pending_request_timeout(
    SessionState *state,
    uint8_t *tx_scratch,
    uint8_t tx_capacity,
    SessionAction *actions)
{
    uint8_t count = 0u;

    if (state->pending_control == SESSION_REQUEST_TAKEBACK &&
        state->pending_origin == DIRECT_ORIGIN_LOCAL) {
        return direct_finish(state, actions, count, state->active_link);
    }
    if (state->pending_control == SESSION_REQUEST_MOVE) {
        static const uint8_t timeout_reason[] = "TIMEOUT";

        direct_send_value_reply(state, state->pending_value,
                                timeout_reason, 7u, 0u, tx_scratch,
                                tx_capacity, actions, &count,
                                DIRECT_TX_NACK_MOVE);
        state->pending_control = 0u;
        state->pending_origin = DIRECT_ORIGIN_NONE;
    } else {
        direct_send_control_reply(state, state->pending_control, 0u,
                                  tx_scratch, tx_capacity, actions, &count);
    }
    state->pending_request_id = 0u;
    return count;
}

static uint8_t direct_handle_control_timeout(SessionState *state,
                                             SessionWorkspace *workspace,
                                             uint8_t *tx_scratch,
                                             uint8_t tx_capacity,
                                             SessionAction *actions)
{
    uint8_t count = 0u;

    if (state->pending_origin == DIRECT_ORIGIN_LOCAL &&
        (state->pending_control == SESSION_REQUEST_RESET ||
         state->pending_control == SESSION_REQUEST_DRAW) &&
        state->pending_value == DIRECT_CANCEL_WAIT) {
        state->pending_value = DIRECT_CANCEL_SENT;
        state->control_retries = 0u;
        return direct_send_local_pending(state, workspace, tx_scratch,
                                         tx_capacity, actions, &count)
                   ? count : 0u;
    }
    if (state->pending_control == SESSION_REQUEST_RESTORE &&
        state->pending_origin == DIRECT_ORIGIN_REMOTE &&
        state->restore_phase == DIRECT_RESTORE_RECEIVE) {
        if (state->control_retries >= SESSION_DIRECT_REPLY_RETRIES) {
            state->pending_control = 0u;
            state->pending_origin = DIRECT_ORIGIN_NONE;
            state->restore_phase = DIRECT_RESTORE_NONE;
            state->restore_mask = 0u;
            return direct_send_text(state, "RN", tx_scratch,
                                    tx_capacity, actions, &count,
                                    state->active_link, DIRECT_TX_RN)
                       ? count
                       : 0u;
        }
        ++state->control_retries;
        return direct_emit_timer_set(state, actions, &count,
                                     SESSION_TIMER_CONTROL,
                                     SESSION_DIRECT_REPLY_TICKS)
                   ? count
                   : 0u;
    }
    if (state->pending_control == SESSION_REQUEST_RESET &&
        state->pending_origin == DIRECT_ORIGIN_REMOTE &&
        state->phase == SESSION_PHASE_OVER) {
        if (state->control_retries >= SESSION_DIRECT_REPLY_RETRIES) {
            return direct_finish(state, actions, count, state->active_link);
        }
        ++state->control_retries;
        state->pending_origin = DIRECT_ORIGIN_LOCAL;
        return direct_send_text(state, "RESET", tx_scratch, tx_capacity,
                                actions, &count, state->active_link,
                                DIRECT_TX_RESET)
                   ? count
                   : 0u;
    }
    if (state->control_retries >= SESSION_DIRECT_REPLY_RETRIES) {
        if (state->pending_control == SESSION_REQUEST_RESTORE &&
            state->restore_phase == DIRECT_RESTORE_WAIT_RY) {
            state->pending_control = 0u;
            state->restore_phase = DIRECT_RESTORE_NONE;
            direct_send_text(state, "RN", tx_scratch, tx_capacity,
                             actions, &count, state->active_link,
                             DIRECT_TX_RN);
            return count;
        }
        if (state->pending_origin == DIRECT_ORIGIN_LOCAL &&
            (state->pending_control == SESSION_REQUEST_RESET ||
             state->pending_control == SESSION_REQUEST_DRAW)) {
            state->control_retries = 0u;
            if (state->pending_value == 0u) {
                state->pending_value = DIRECT_CANCEL_WAIT;
            }
            if (!direct_emit_timer_set(state, actions, &count,
                                       SESSION_TIMER_CONTROL,
                                       SESSION_CONTROL_CANCEL_TICKS) ||
                !direct_arm_liveness(state, actions, &count)) {
                return 0u;
            }
            return count;
        }
        return direct_finish(state, actions, count, state->active_link);
    }
    ++state->control_retries;
    return direct_send_local_pending(state, workspace, tx_scratch,
                                     tx_capacity, actions, &count)
               ? count
               : 0u;
}

static uint8_t direct_handle_timeout(SessionState *state,
                                     const SessionEvent *event,
                                     SessionWorkspace *workspace,
                                     uint8_t *tx_scratch,
                                     uint8_t tx_capacity,
                                     SessionAction *actions)
{
    uint8_t timer_id = event->data.timeout.timer_id;
    uint8_t count = 0u;

    if (timer_id >= SESSION_TIMER_COUNT ||
        (state->timer_mask & (uint8_t)(1u << timer_id)) == 0u) {
        return 0u;
    }
    if (timer_id != SESSION_TIMER_TX_GUARD &&
        state->pending_tx_kind != DIRECT_TX_NONE) {
        uint16_t ticks = SESSION_DIRECT_REPLY_TICKS;

        state->timer_mask &= (uint8_t)~(uint8_t)(1u << timer_id);
        if (timer_id == SESSION_TIMER_LIVENESS) {
            ticks = state->config.role == SESSION_ROLE_GUEST &&
                            state->liveness_misses == 0u
                        ? SESSION_DIRECT_IDLE_TICKS
                        : SESSION_DIRECT_PING_TICKS;
        }
        return direct_emit_timer_set(state, actions, &count, timer_id, ticks)
                   ? count
                   : 0u;
    }
    state->timer_mask &= (uint8_t)~(uint8_t)(1u << timer_id);
    if (timer_id == SESSION_TIMER_TX_GUARD) {
        return direct_handle_tx_guard_timeout(state, workspace, tx_scratch,
                                              tx_capacity, actions);
    }
    if (timer_id == SESSION_TIMER_LIVENESS) {
        return direct_handle_liveness_timeout(state, tx_scratch, tx_capacity,
                                              actions);
    }
    if (state->phase == SESSION_PHASE_HANDSHAKE && !state->peer_ready) {
        return direct_handle_handshake_timeout(state, tx_scratch, tx_capacity,
                                               actions);
    }
    if (state->pending_request_id != 0u) {
        return direct_handle_pending_request_timeout(state, tx_scratch,
                                                     tx_capacity, actions);
    }
    if (state->pending_control != 0u) {
        return direct_handle_control_timeout(state, workspace, tx_scratch,
                                             tx_capacity, actions);
    }
    return 0u;
}

uint8_t direct_session_step(SessionState *state,
                            const SessionEvent *event,
                            SessionWorkspace *workspace,
                            uint8_t *tx_scratch,
                            uint8_t tx_capacity,
                            SessionAction *actions,
                            uint8_t action_capacity)
{
    if (workspace == 0 || tx_scratch == 0 ||
        tx_capacity < SESSION_DIRECT_TX_CAPACITY_MIN || actions == 0 ||
        action_capacity < SESSION_ACTION_CAPACITY) {
        return 0u;
    }
    switch (event->type) {
    case SESSION_EV_LINK_UP:
        return direct_handle_link_up(state, event->data.link.link_id,
                                     tx_scratch, tx_capacity, actions);
    case SESSION_EV_RX:
        return direct_handle_rx(state, event, workspace, tx_scratch,
                                tx_capacity, actions);
    case SESSION_EV_LOCAL_REQUEST:
        return direct_handle_local(state, event, workspace, tx_scratch,
                                   tx_capacity, actions);
    case SESSION_EV_USER_DECISION:
        return direct_handle_user_decision(state, event, tx_scratch,
                                           tx_capacity, actions);
    case SESSION_EV_GAME_RESULT:
        return direct_handle_game_result(state, event, tx_scratch,
                                         tx_capacity, actions);
    case SESSION_EV_TX_RESULT:
        return direct_handle_tx_result(state, event, workspace, tx_scratch,
                                       tx_capacity, actions);
    case SESSION_EV_TIMEOUT:
        return direct_handle_timeout(state, event, workspace, tx_scratch,
                                     tx_capacity, actions);
    default:
        return 0u;
    }
}
