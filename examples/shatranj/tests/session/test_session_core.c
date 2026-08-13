#include "common/session/session.h"

#include <stdio.h>
#include <string.h>

typedef char session_u8_tag_check[(sizeof(((SessionState *)0)->phase) == 1u)
                                      ? 1
                                      : -1];
typedef char session_action_capacity_check[(SESSION_ACTION_CAPACITY >= 4u)
                                               ? 1
                                               : -1];
typedef char session_payload_bound_check[(SESSION_PAYLOAD_MAX <= 255u) ? 1 : -1];
typedef char session_restore_workspace_check[
    (sizeof(SessionWorkspace) == SESSION_RESTORE_BYTES) ? 1 : -1];

static int failures;

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

static void check(int ok, const char *label)
{
    if (!ok) {
        printf("FAIL: %s\n", label);
        ++failures;
    }
}

static SessionConfig direct_host_config(void)
{
    SessionConfig config;

    config.transport = SESSION_TRANSPORT_DIRECT;
    config.role = SESSION_ROLE_HOST;
    config.host_color = SESSION_COLOR_BLACK;
    config.session_id = 17u;
    return config;
}

static void test_init_and_reset(void)
{
    SessionConfig config = direct_host_config();
    SessionState state;

    check(session_init(&state, &config), "valid init");
    check(state.phase == SESSION_PHASE_IDLE, "initial phase");
    check(state.local_color == SESSION_COLOR_BLACK, "host color");
    check(state.session_id == 17u, "initial session id");
    check(state.next_tx_id == 1u, "initial tx id");

    state.phase = SESSION_PHASE_ACTIVE;
    state.deferred_decision = SESSION_DECISION_ACCEPT;
    state.peer_ready = 1u;
    state.timer_mask = 7u;
    session_reset(&state);
    check(state.phase == SESSION_PHASE_IDLE, "reset phase");
    check(state.deferred_decision == 0u && state.peer_ready == 0u,
          "reset readiness");
    check(state.timer_mask == 0u, "reset timers");
    check(state.config.transport == SESSION_TRANSPORT_DIRECT,
          "reset keeps config");

    config.transport = 9u;
    check(!session_init(&state, &config), "reject transport");
    config = direct_host_config();
    config.role = 9u;
    check(!session_init(&state, &config), "reject role");
    check(!session_init(0, &config), "reject null state");
    check(!session_init(&state, 0), "reject null config");
}

static void test_link_down_order_and_capacity(void)
{
    SessionConfig config = direct_host_config();
    SessionState state;
    SessionState before;
    SessionEvent event;
    SessionAction actions[SESSION_ACTION_CAPACITY];
    SessionWorkspace workspace;
    uint8_t count;

    check(session_init(&state, &config), "link-down init");
    state.link_up = 1u;
    state.phase = SESSION_PHASE_ACTIVE;
    state.deferred_decision = SESSION_DECISION_ACCEPT;
    state.peer_ready = 1u;
    state.pending_tx_kind = SESSION_REQUEST_MOVE;
    state.timer_mask = (uint8_t)((1u << SESSION_TIMER_TX_GUARD) |
                                 (1u << SESSION_TIMER_LIVENESS));
    event.type = SESSION_EV_LINK_DOWN;
    event.data.link.link_id = 3u;
    state.active_link = 3u;

    before = state;
    count = session_step(&state, &event, &workspace, 0, 0u, actions, 2u);
    check(count == 0u, "small action buffer rejected");
    check(memcmp(&state, &before, sizeof(state)) == 0,
          "capacity failure is atomic");

    count = session_step(&state, &event, &workspace, 0, 0u,
                         actions, SESSION_ACTION_CAPACITY);
    check(count == 3u, "link-down action count");
    check(actions[0].type == SESSION_ACT_TIMER_CANCEL &&
              actions[0].data.timer_cancel.timer_id == SESSION_TIMER_TX_GUARD,
          "cancel tx guard first");
    check(actions[1].type == SESSION_ACT_TIMER_CANCEL &&
              actions[1].data.timer_cancel.timer_id == SESSION_TIMER_LIVENESS,
          "cancel liveness second");
    check(actions[2].type == SESSION_ACT_SESSION_CHANGED &&
              actions[2].data.session.status == SESSION_CHANGED_ENDED,
          "ended last");
    check(state.phase == SESSION_PHASE_IDLE && state.link_up == 0u,
          "link-down resets session");
    check(session_step(&state, &event, &workspace, 0, 0u,
                       actions, SESSION_ACTION_CAPACITY) == 0u,
          "repeated link-down is idempotent");
}

static void test_invalid_and_local_tx_semantics(void)
{
    SessionConfig config = direct_host_config();
    SessionState state;
    SessionState before;
    SessionEvent event;
    SessionAction actions[SESSION_ACTION_CAPACITY];
    SessionWorkspace workspace;
    uint8_t rx[] = {'P', 'I', 'N', 'G'};

    check(session_init(&state, &config), "invalid-event init");
    before = state;
    event.type = 0xFFu;
    check(session_step(&state, &event, &workspace, 0, 0u,
                       actions, SESSION_ACTION_CAPACITY) == 0u,
          "reject unknown event");
    check(memcmp(&state, &before, sizeof(state)) == 0,
          "unknown event leaves state");

    event.type = SESSION_EV_TX_RESULT;
    event.data.tx.tx_id = 7u;
    event.data.tx.result = SESSION_TX_OK;
    check(session_step(&state, &event, &workspace, 0, 0u,
                       actions, SESSION_ACTION_CAPACITY) == 0u,
          "unsolicited local tx result ignored");
    check(state.phase == SESSION_PHASE_IDLE,
          "local tx result does not prove peer state");

    event.type = SESSION_EV_RX;
    event.data.rx.payload = rx;
    event.data.rx.length = sizeof(rx);
    event.data.rx.route = SESSION_ROUTE_DEFAULT;
    event.data.rx.flags = SESSION_RX_LIVE;
    event.data.rx.link_id = 1u;
    check(session_step(&state, &event, &workspace, 0, 0u,
                       actions, SESSION_ACTION_CAPACITY) == 0u,
          "unimplemented rx is bounded");
    check(memcmp(rx, "PING", sizeof(rx)) == 0, "rx input remains caller-owned");
}

int main(void)
{
    test_init_and_reset();
    test_link_down_order_and_capacity();
    test_invalid_and_local_tx_semantics();

    printf("session core sizes: config=%lu state=%lu event=%lu action=%lu workspace=%lu\n",
           (unsigned long)sizeof(SessionConfig),
           (unsigned long)sizeof(SessionState),
           (unsigned long)sizeof(SessionEvent),
           (unsigned long)sizeof(SessionAction),
           (unsigned long)sizeof(SessionWorkspace));
    check(sizeof(SessionConfig) <= 6u, "config size bound");
    check(sizeof(SessionState) <= 40u, "state size bound");
    check(sizeof(SessionEvent) <= 24u, "event size bound");
    check(sizeof(SessionAction) <= 24u, "action size bound");

    if (failures != 0) {
        printf("session core tests failed: %d\n", failures);
        return 1;
    }
    printf("session core tests ok\n");
    return 0;
}
