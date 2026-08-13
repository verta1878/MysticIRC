#include "common/session/session.h"
#include "common/session/session_internal.h"

static uint8_t session_config_valid(const SessionConfig *config)
{
    return (uint8_t)(config != 0 &&
                     config->transport <= SESSION_TRANSPORT_MQTT &&
                     config->role <= SESSION_ROLE_GUEST &&
                     (config->host_color <= SESSION_COLOR_BLACK ||
                      config->host_color == SESSION_COLOR_UNKNOWN));
}

uint8_t session_next_tx_id(SessionState *state)
{
    uint8_t id = state->next_tx_id;

    ++state->next_tx_id;
    if (state->next_tx_id == 0u) {
        state->next_tx_id = 1u;
    }
    if (id == 0u) {
        id = state->next_tx_id++;
    }
    return id;
}

uint8_t session_next_delivery_id(SessionState *state)
{
    ++state->delivery_id;
    if (state->delivery_id == 0u) {
        ++state->delivery_id;
    }
    return state->delivery_id;
}

void session_clear_duplicate(SessionState *state)
{
    state->last_rx_kind = 0u;
    state->last_value = 0u;
    state->last_result = 0u;
}

void session_drop_restore_cache(SessionState *state)
{
    if (state->restore_phase == SESSION_RESTORE_PHASE_APPLIED) {
        state->restore_phase = SESSION_RESTORE_PHASE_NONE;
        state->restore_mask = 0u;
        if (state->last_rx_kind == SESSION_REQUEST_RESTORE) {
            session_clear_duplicate(state);
        }
    }
}

uint8_t session_build_restore_chunk(const SessionWorkspace *workspace,
                                    uint8_t chunk,
                                    uint8_t *payload,
                                    uint8_t capacity)
{
    uint8_t i;
    uint8_t offset = chunk == 0u ? 0u : 30u;

    if (payload == 0 || capacity < 36u) {
        return 0u;
    }
    payload[0] = 'R';
    payload[1] = 'S';
    payload[2] = '0';
    payload[3] = (uint8_t)('0' + chunk);
    payload[4] = ' ';
    for (i = 0u; i < 30u; ++i) {
        payload[5u + i] = workspace->restore[offset + i];
    }
    payload[35] = 0u;
    return 1u;
}

uint8_t session_restore_chunk_matches(const SessionWorkspace *workspace,
                                      const uint8_t *payload,
                                      uint8_t chunk)
{
    uint8_t i;
    uint8_t offset = chunk == 0u ? 0u : 30u;

    for (i = 0u; i < 30u; ++i) {
        if (workspace->restore[offset + i] != payload[5u + i]) {
            return 0u;
        }
    }
    return 1u;
}

void session_store_restore_chunk(SessionWorkspace *workspace,
                                 const uint8_t *payload,
                                 uint8_t chunk)
{
    uint8_t i;
    uint8_t offset = chunk == 0u ? 0u : 30u;

    for (i = 0u; i < 30u; ++i) {
        workspace->restore[offset + i] = payload[5u + i];
    }
}

void session_reset(SessionState *state)
{
    if (state == 0) {
        return;
    }
    state->session_id = state->config.session_id;
    state->current_ply = 0u;
    state->pending_value = 0u;
    state->last_value = 0u;
    state->phase = SESSION_PHASE_IDLE;
    state->local_color = SESSION_COLOR_UNKNOWN;
    if (state->config.host_color != SESSION_COLOR_UNKNOWN) {
        state->local_color = state->config.role == SESSION_ROLE_HOST
                                 ? state->config.host_color
                                 : (uint8_t)(state->config.host_color ^ 1u);
    }
    state->deferred_decision = 0u;
    state->peer_ready = 0u;
    state->link_up = 0u;
    state->active_link = SESSION_LINK_NONE;
    state->tx_link = SESSION_LINK_NONE;
    state->pending_control = 0u;
    state->pending_origin = 0u;
    state->pending_request_id = 0u;
    state->pending_tx_id = 0u;
    state->pending_tx_kind = 0u;
    state->next_tx_id = 1u;
    state->control_retries = 0u;
    state->liveness_misses = 0u;
    state->timer_mask = 0u;
    state->last_rx_kind = 0u;
    state->last_result = 0u;
    state->delivery_id = 0u;
    state->restore_phase = 0u;
    state->restore_mask = 0u;
}

uint8_t session_init(SessionState *state, const SessionConfig *config)
{
    if (state == 0 || !session_config_valid(config)) {
        return 0u;
    }
    state->config = *config;
    session_reset(state);
    return 1u;
}

uint8_t session_end(SessionState *state,
                    SessionAction *actions,
                    uint8_t action_capacity,
                    uint8_t close_link)
{
    uint8_t timer_id;
    uint8_t needed = (uint8_t)(1u + (close_link != 0u));
    uint8_t count = 0u;
    uint8_t active_link = state->active_link;
    uint8_t candidate_link = SESSION_LINK_NONE;

    if (state->pending_tx_kind != 0u &&
        state->tx_link != SESSION_LINK_NONE &&
        state->tx_link != active_link) {
        candidate_link = state->tx_link;
        ++needed;
    }

    for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
        if ((state->timer_mask & (uint8_t)(1u << timer_id)) != 0u) {
            ++needed;
        }
    }
    if (actions == 0 || action_capacity < needed) {
        return 0u;
    }
    for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
        if ((state->timer_mask & (uint8_t)(1u << timer_id)) != 0u) {
            actions[count].type = SESSION_ACT_TIMER_CANCEL;
            actions[count].data.timer_cancel.timer_id = timer_id;
            ++count;
        }
    }
    if (close_link != 0u) {
        actions[count].type = SESSION_ACT_LINK_CLOSE;
        actions[count].data.link_close.link_id = active_link;
        ++count;
    }
    if (candidate_link != SESSION_LINK_NONE) {
        actions[count].type = SESSION_ACT_LINK_CLOSE;
        actions[count].data.link_close.link_id = candidate_link;
        ++count;
    }
    actions[count].type = SESSION_ACT_SESSION_CHANGED;
    actions[count].data.session.status = SESSION_CHANGED_ENDED;
    ++count;
    session_reset(state);
    return count;
}

uint8_t session_step(SessionState *state,
                     const SessionEvent *event,
                     SessionWorkspace *workspace,
                     uint8_t *tx_scratch,
                     uint8_t tx_capacity,
                     SessionAction *actions,
                     uint8_t action_capacity)
{
    (void)workspace;
    (void)tx_scratch;
    (void)tx_capacity;

    if (state == 0 || event == 0 || event->type < SESSION_EV_LINK_UP ||
        event->type > SESSION_EV_GAME_RESULT) {
        return 0u;
    }
    if (event->type == SESSION_EV_LINK_DOWN) {
        if (state->link_up != 0u &&
            event->data.link.link_id != state->active_link) {
            return 0u;
        }
        if (state->link_up == 0u && state->phase == SESSION_PHASE_IDLE &&
            state->timer_mask == 0u && state->pending_tx_kind == 0u) {
            return 0u;
        }
        return session_end(state, actions, action_capacity, 0u);
    }
    if (state->config.transport == SESSION_TRANSPORT_DIRECT) {
        return direct_session_step(state,
                                   event,
                                   workspace,
                                   tx_scratch,
                                   tx_capacity,
                                   actions,
                                   action_capacity);
    }
    return mqtt_session_step(state,
                             event,
                             workspace,
                             tx_scratch,
                             tx_capacity,
                             actions,
                             action_capacity);
}
