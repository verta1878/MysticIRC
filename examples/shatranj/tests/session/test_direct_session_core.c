#include "common/session/session.h"

#include <stdio.h>
#include <string.h>

typedef struct Fixture {
    SessionState state;
    SessionWorkspace workspace;
    uint8_t tx[SESSION_PAYLOAD_MAX + 1u];
    SessionAction actions[SESSION_ACTION_CAPACITY];
    uint8_t count;
} Fixture;

static int failures;

static void check(int ok, const char *label)
{
    if (!ok) {
        printf("FAIL: %s\n", label);
        ++failures;
    }
}

static void fixture_init(Fixture *f, uint8_t role, uint8_t color)
{
    SessionConfig config;

    memset(f, 0, sizeof(*f));
    config.transport = SESSION_TRANSPORT_DIRECT;
    config.role = role;
    config.host_color = color;
    config.session_id = 0u;
    check(session_init(&f->state, &config), "fixture init");
}

static uint8_t run(Fixture *f, const SessionEvent *event)
{
    memset(f->actions, 0, sizeof(f->actions));
    f->count = session_step(&f->state,
                            event,
                            &f->workspace,
                            f->tx,
                            sizeof(f->tx),
                            f->actions,
                            SESSION_ACTION_CAPACITY);
    return f->count;
}

static uint8_t run_with_capacity(Fixture *f,
                                 const SessionEvent *event,
                                 uint8_t tx_capacity)
{
    memset(f->actions, 0, sizeof(f->actions));
    f->count = session_step(&f->state,
                            event,
                            &f->workspace,
                            f->tx,
                            tx_capacity,
                            f->actions,
                            SESSION_ACTION_CAPACITY);
    return f->count;
}

static SessionAction *find_action(Fixture *f, uint8_t type)
{
    uint8_t i;

    for (i = 0u; i < f->count; ++i) {
        if (f->actions[i].type == type) {
            return &f->actions[i];
        }
    }
    return 0;
}

static SessionAction *find_control_result(Fixture *f)
{
    uint8_t i;

    for (i = 0u; i < f->count; ++i) {
        if (f->actions[i].type == SESSION_ACT_DELIVER_GAME &&
            f->actions[i].data.game.kind ==
                SESSION_DELIVER_CONTROL_RESULT) {
            return &f->actions[i];
        }
    }
    return 0;
}

static void expect_control_result(Fixture *f,
                                  uint8_t control,
                                  uint8_t result,
                                  const char *label)
{
    SessionAction *action = find_control_result(f);

    check(action != 0 && action->data.game.value == control &&
              action->data.game.delivery_id == result,
          label);
}

static uint8_t count_actions(Fixture *f, uint8_t type)
{
    uint8_t i;
    uint8_t count = 0u;

    for (i = 0u; i < f->count; ++i) {
        if (f->actions[i].type == type) {
            ++count;
        }
    }
    return count;
}

static void expect_send(Fixture *f, const char *text, uint8_t link_id,
                        const char *label)
{
    SessionAction *action = 0;
    size_t length = strlen(text);
    uint8_t i;

    check(count_actions(f, SESSION_ACT_SEND) == 1u, label);
    for (i = 0u; i < f->count; ++i) {
        if (f->actions[i].type == SESSION_ACT_SEND) {
            action = &f->actions[i];
            check(i + 1u < f->count &&
                      f->actions[i + 1u].type == SESSION_ACT_TIMER_SET &&
                      f->actions[i + 1u].data.timer_set.timer_id ==
                          SESSION_TIMER_TX_GUARD,
                  "send followed by tx guard");
            break;
        }
    }
    if (action == 0) {
        return;
    }
    check(action->data.send.length == length, "send length");
    check(action->data.send.link_id == link_id, "send link");
    check(memcmp(action->data.send.payload, text, length) == 0, "send text");
}

static void expect_type_at(Fixture *f,
                           uint8_t index,
                           uint8_t type,
                           const char *label)
{
    check(index < f->count && f->actions[index].type == type, label);
}

static void expect_timer(Fixture *f, uint8_t timer_id, uint16_t ticks,
                         const char *label)
{
    uint8_t i;

    for (i = 0u; i < f->count; ++i) {
        if (f->actions[i].type == SESSION_ACT_TIMER_SET &&
            f->actions[i].data.timer_set.timer_id == timer_id &&
            f->actions[i].data.timer_set.duration_ticks == ticks) {
            return;
        }
    }
    check(0, label);
}

static uint8_t link_up(Fixture *f, uint8_t link_id)
{
    SessionEvent event;

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LINK_UP;
    event.data.link.link_id = link_id;
    return run(f, &event);
}

static uint8_t rx(Fixture *f, uint8_t link_id, const char *text)
{
    SessionEvent event;

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_RX;
    event.data.rx.payload = (const uint8_t *)text;
    event.data.rx.length = (uint8_t)strlen(text);
    event.data.rx.route = SESSION_ROUTE_DEFAULT;
    event.data.rx.flags = SESSION_RX_LIVE;
    event.data.rx.link_id = link_id;
    return run(f, &event);
}

static uint8_t tx_result(Fixture *f, uint8_t result)
{
    SessionEvent event;

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_TX_RESULT;
    event.data.tx.tx_id = f->state.pending_tx_id;
    event.data.tx.result = result;
    return run(f, &event);
}

static uint8_t timeout(Fixture *f, uint8_t timer_id)
{
    SessionEvent event;

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_TIMEOUT;
    event.data.timeout.timer_id = timer_id;
    return run(f, &event);
}

static uint8_t local_request_phase(Fixture *f,
                                   uint8_t request,
                                   uint16_t value,
                                   const char *payload,
                                   uint8_t phase)
{
    SessionEvent event;

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LOCAL_REQUEST;
    event.data.local.request = request;
    event.data.local.value = value;
    event.data.local.payload = (const uint8_t *)payload;
    event.data.local.length = payload == 0 ? 0u : (uint8_t)strlen(payload);
    event.data.local.phase = phase;
    return run(f, &event);
}

static uint8_t local_request(Fixture *f,
                             uint8_t request,
                             uint16_t value,
                             const char *payload)
{
    return local_request_phase(f, request, value, payload, f->state.phase);
}

static uint8_t user_decision(Fixture *f, uint8_t decision)
{
    SessionEvent event;

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_USER_DECISION;
    event.data.user.request_id = f->state.pending_request_id;
    event.data.user.decision = decision;
    return run(f, &event);
}

static uint8_t game_result(Fixture *f,
                           uint8_t result,
                           uint16_t value,
                           const char *detail)
{
    SessionEvent event;

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_GAME_RESULT;
    event.data.game.delivery_id = f->state.pending_request_id;
    event.data.game.result = result;
    event.data.game.value = value;
    event.data.game.detail = (const uint8_t *)detail;
    event.data.game.detail_length = detail == 0 ? 0u : (uint8_t)strlen(detail);
    return run(f, &event);
}

static uint8_t game_result_phase(Fixture *f,
                                 uint8_t result,
                                 uint16_t value,
                                 uint8_t phase)
{
    SessionEvent event;

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_GAME_RESULT;
    event.data.game.delivery_id = f->state.pending_request_id;
    event.data.game.result = result;
    event.data.game.value = value;
    event.data.game.detail = &phase;
    event.data.game.detail_length = 1u;
    return run(f, &event);
}

static uint8_t game_result_id(Fixture *f,
                              uint8_t delivery_id,
                              uint8_t result,
                              uint16_t value,
                              const char *detail)
{
    SessionEvent event;

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_GAME_RESULT;
    event.data.game.delivery_id = delivery_id;
    event.data.game.result = result;
    event.data.game.value = value;
    event.data.game.detail = (const uint8_t *)detail;
    event.data.game.detail_length = detail == 0 ? 0u : (uint8_t)strlen(detail);
    return run(f, &event);
}

static void make_active(Fixture *f, uint8_t role, uint8_t color)
{
    fixture_init(f, role,
                 role == SESSION_ROLE_HOST ? color : (uint8_t)(color ^ 1u));
    f->state.link_up = 1u;
    f->state.active_link = 1u;
    f->state.peer_ready = 1u;
    f->state.deferred_decision = 0u;
    f->state.phase = SESSION_PHASE_ACTIVE;
    f->state.local_color = color;
    f->state.timer_mask = (uint8_t)(1u << SESSION_TIMER_LIVENESS);
}

static void test_hello_and_busy(void)
{
    Fixture guest;
    Fixture host;
    SessionAction *action;
    SessionEvent event;

    fixture_init(&guest, SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN);
    check(link_up(&guest, 1u) == 2u, "guest link-up actions");
    expect_send(&guest, "HELLO DIRECT GUEST", 1u, "guest hello");
    expect_timer(&guest, SESSION_TIMER_TX_GUARD, SESSION_TX_GUARD_TICKS,
                 "guest tx guard");
    tx_result(&guest, SESSION_TX_OK);
    expect_timer(&guest, SESSION_TIMER_CONTROL, SESSION_DIRECT_HELLO_TICKS,
                 "guest hello retry timer");
    rx(&guest, 1u, "HELLO DIRECT HOST WHITE=HOST");
    expect_send(&guest, "HELLO DIRECT GUEST", 1u, "guest hello reply");
    action = find_action(&guest, SESSION_ACT_SIDE_CHANGED);
    check(action != 0 && action->data.side.color == SESSION_COLOR_BLACK,
          "guest side action");
    tx_result(&guest, SESSION_TX_OK);
    action = find_action(&guest, SESSION_ACT_SESSION_CHANGED);
    check(action != 0 && action->data.session.status == SESSION_CHANGED_READY,
          "guest ready action");
    expect_timer(&guest, SESSION_TIMER_LIVENESS, SESSION_DIRECT_IDLE_TICKS,
                 "guest liveness timer");

    fixture_init(&host, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    link_up(&host, 1u);
    tx_result(&host, SESSION_TX_OK);
    rx(&host, 1u, "HELLO DIRECT GUEST");
    tx_result(&host, SESSION_TX_OK);
    check(host.state.peer_ready == 1u, "host ready state");

    check(link_up(&host, 2u) == 3u, "busy send actions");
    expect_type_at(&host, 0u, SESSION_ACT_TIMER_CANCEL,
                   "busy pauses active liveness");
    expect_send(&host, "BUSY", 2u, "busy directed to intruder");
    tx_result(&host, SESSION_TX_OK);
    action = find_action(&host, SESSION_ACT_LINK_CLOSE);
    check(action != 0 && action->data.link_close.link_id == 2u,
          "close intruder only");
    expect_timer(&host, SESSION_TIMER_LIVENESS, SESSION_DIRECT_PING_TICKS,
                 "busy completion rearms host liveness");
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LINK_DOWN;
    event.data.link.link_id = 2u;
    check(run(&host, &event) == 0u, "intruder down ignored");
    check(host.state.active_link == 1u && host.state.peer_ready == 1u,
          "active peer preserved");
}

static void test_start(void)
{
    Fixture host;
    Fixture guest;
    SessionAction *action;

    fixture_init(&host, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    host.state.link_up = 1u;
    host.state.active_link = 1u;
    host.state.peer_ready = 1u;
    host.state.phase = SESSION_PHASE_READY;
    local_request(&host, SESSION_REQUEST_START, 0u, 0);
    expect_send(&host, "GAME START WHITE=HOST", 1u, "host game start");
    tx_result(&host, SESSION_TX_OK);
    expect_timer(&host, SESSION_TIMER_CONTROL, SESSION_DIRECT_REPLY_TICKS,
                 "start reply timer");
    rx(&host, 1u, "ACK GAME START");
    action = find_action(&host, SESSION_ACT_SESSION_CHANGED);
    check(action != 0 && action->data.session.status == SESSION_CHANGED_STARTED,
          "host starts on peer ack");
    check(host.state.phase == SESSION_PHASE_ACTIVE, "host active phase");

    fixture_init(&guest, SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN);
    guest.state.link_up = 1u;
    guest.state.active_link = 1u;
    guest.state.peer_ready = 1u;
    guest.state.phase = SESSION_PHASE_READY;
    rx(&guest, 1u, "GAME START WHITE=GUEST");
    expect_send(&guest, "ACK GAME START", 1u, "guest start ack");
    tx_result(&guest, SESSION_TX_OK);
    action = find_action(&guest, SESSION_ACT_SESSION_CHANGED);
    check(action != 0 && action->data.session.status == SESSION_CHANGED_STARTED,
          "guest starts after local ack handoff");
    check(guest.state.local_color == SESSION_COLOR_WHITE, "guest start side");
}

static void test_moves_and_tx_guard(void)
{
    Fixture local;
    Fixture remote;
    SessionAction *action;

    make_active(&local, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&local, SESSION_REQUEST_MOVE, 0u, "e2e4");
    expect_send(&local, "MOVE 1 e2e4", 1u, "local move send");
    tx_result(&local, SESSION_TX_OK);
    expect_timer(&local, SESSION_TIMER_CONTROL, SESSION_DIRECT_REPLY_TICKS,
                 "move reply timer");
    rx(&local, 1u, "ACK 1 e4");
    action = find_action(&local, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_LOCAL_MOVE &&
              action->data.game.value == 1u,
          "apply acknowledged local move");
    check(local.state.current_ply == 1u, "local ply advanced");
    check(rx(&local, 1u, "ACK 1 e4") <= 1u, "duplicate ack bounded");

    make_active(&remote, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&remote, 1u, "MOVE 1 e2e4");
    action = find_action(&remote, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_REMOTE_MOVE &&
              action->data.game.value == 1u &&
              action->data.game.length == 4u,
          "deliver parsed remote move");
    game_result(&remote, SESSION_GAME_ACCEPTED, 1u, "e4");
    expect_send(&remote, "ACK 1 e4", 1u, "remote move ack");
    tx_result(&remote, SESSION_TX_OK);
    check(remote.state.current_ply == 1u, "remote ply advanced");
    rx(&remote, 1u, "MOVE 1 e2e4");
    expect_send(&remote, "ACK 1", 1u, "duplicate move re-ack");

    fixture_init(&local, SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN);
    link_up(&local, 1u);
    timeout(&local, SESSION_TIMER_TX_GUARD);
    action = find_action(&local, SESSION_ACT_LINK_CLOSE);
    check(action != 0 && action->data.link_close.link_id == 1u,
          "missing tx result closes link");
    action = find_action(&local, SESSION_ACT_SESSION_CHANGED);
    check(action != 0 && action->data.session.status == SESSION_CHANGED_ENDED,
          "missing tx result ends session");

    make_active(&local, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&local, 1u, "PING");
    expect_send(&local, "ACK PING", 1u, "peer ping ack");
    timeout(&local, SESSION_TIMER_TX_GUARD);
    check(find_action(&local, SESSION_ACT_LINK_CLOSE) == 0 &&
              find_action(&local, SESSION_ACT_SESSION_CHANGED) == 0,
          "missing ping ack result preserves session");
    expect_timer(&local, SESSION_TIMER_LIVENESS, SESSION_DIRECT_IDLE_TICKS,
                 "missing ping ack result rearms liveness");
}

static void test_controls_and_liveness(void)
{
    Fixture f;
    SessionAction *action;

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RESET");
    action = find_action(&f, SESSION_ACT_REQUEST_DECISION);
    check(action != 0 && action->data.decision.control == SESSION_REQUEST_RESET,
          "reset asks decision");
    user_decision(&f, SESSION_DECISION_ACCEPT);
    expect_send(&f, "ACK RESET", 1u, "accepted reset ack");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.kind == SESSION_DELIVER_CONTROL &&
              action->data.game.value == SESSION_REQUEST_RESET,
          "accepted reset delivered");
    rx(&f, 1u, "RESET");
    action = find_action(&f, SESSION_ACT_REQUEST_DECISION);
    check(action != 0 && action->data.decision.control == SESSION_REQUEST_RESET,
          "new reset after completed reset asks again");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    timeout(&f, SESSION_TIMER_LIVENESS);
    expect_send(&f, "PING", 1u, "guest idle ping");
    tx_result(&f, SESSION_TX_OK);
    expect_timer(&f, SESSION_TIMER_LIVENESS, SESSION_DIRECT_PING_TICKS,
                 "ping response timer");
    rx(&f, 1u, "ACK PING");
    expect_timer(&f, SESSION_TIMER_LIVENESS, SESSION_DIRECT_IDLE_TICKS,
                 "ack ping rearms idle");
}

static void test_control_replies_and_duplicates(void)
{
    Fixture f;
    SessionAction *action;

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_RESET, 0u, 0);
    expect_send(&f, "RESET", 1u, "local reset send");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK RESET");
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
              action->data.game.delivery_id == SESSION_CONTROL_ACCEPTED &&
              action->data.game.value == SESSION_REQUEST_RESET,
          "local reset ack delivered");
    check(f.state.phase == SESSION_PHASE_ACTIVE && f.state.current_ply == 0u,
          "local reset restarts game");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    f.state.current_ply = 3u;
    local_request(&f, SESSION_REQUEST_TAKEBACK, 3u, 0);
    expect_send(&f, "TAKEBACK 3", 1u, "local takeback send");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK 3");
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.kind == SESSION_DELIVER_TAKEBACK &&
              action->data.game.value == 3u,
          "local takeback ack requests domain apply");
    game_result(&f, SESSION_GAME_ACCEPTED, 3u, 0);
    expect_control_result(&f, SESSION_REQUEST_TAKEBACK,
                          SESSION_CONTROL_ACCEPTED,
                          "accepted takeback reports accepted result");
    check(f.state.current_ply == 2u, "takeback ack rewinds ply");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RESET");
    user_decision(&f, SESSION_DECISION_REJECT);
    expect_send(&f, "NACK RESET", 1u, "rejected reset nack");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "RESET");
    action = find_action(&f, SESSION_ACT_REQUEST_DECISION);
    check(action != 0 && action->data.decision.control == SESSION_REQUEST_RESET,
          "reset after rejection asks again");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RESIGN");
    expect_send(&f, "ACK RESIGN", 1u, "resign ack");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.value == SESSION_REQUEST_RESIGN,
          "first resign delivered");
    rx(&f, 1u, "RESIGN");
    expect_send(&f, "ACK RESIGN", 1u, "duplicate resign re-ack");
    tx_result(&f, SESSION_TX_OK);
    check(find_action(&f, SESSION_ACT_DELIVER_GAME) == 0,
          "duplicate resign not redelivered");
}

static void test_retry_and_failure_paths(void)
{
    Fixture f;
    SessionAction *action;
    SessionEvent event;
    uint8_t old_tx;
    uint8_t i;

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    timeout(&f, SESSION_TIMER_LIVENESS);
    tx_result(&f, SESSION_TX_OK);
    timeout(&f, SESSION_TIMER_LIVENESS);
    expect_send(&f, "PING", 1u, "first missed ping retries");
    tx_result(&f, SESSION_TX_OK);
    timeout(&f, SESSION_TIMER_LIVENESS);
    action = find_action(&f, SESSION_ACT_LINK_CLOSE);
    check(action != 0, "liveness miss limit closes");
    action = find_action(&f, SESSION_ACT_SESSION_CHANGED);
    check(action != 0 && action->data.session.status == SESSION_CHANGED_ENDED,
          "liveness miss limit ends");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "e2e4");
    tx_result(&f, SESSION_TX_OK);
    for (i = 0u; i < SESSION_DIRECT_REPLY_RETRIES; ++i) {
        timeout(&f, SESSION_TIMER_CONTROL);
        expect_send(&f, "MOVE 1 e2e4", 1u, "move retry");
        check(count_actions(&f, SESSION_ACT_SEND) == 1u,
              "one send per retry step");
        tx_result(&f, SESSION_TX_OK);
    }
    timeout(&f, SESSION_TIMER_CONTROL);
    check(find_action(&f, SESSION_ACT_LINK_CLOSE) != 0,
          "reply retry limit closes");
    check(find_action(&f, SESSION_ACT_SESSION_CHANGED) != 0,
          "reply retry limit ends");

    fixture_init(&f, SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN);
    link_up(&f, 1u);
    old_tx = f.state.pending_tx_id;
    timeout(&f, SESSION_TIMER_TX_GUARD);
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_TX_RESULT;
    event.data.tx.tx_id = old_tx;
    event.data.tx.result = SESSION_TX_OK;
    check(run(&f, &event) == 0u, "late tx result ignored after guard expiry");
}

static void test_invalid_and_ordered_inputs(void)
{
    Fixture f;
    SessionAction *action;
    SessionEvent event;
    uint8_t missing_sentinel[5] = {'P', 'I', 'N', 'G', 'X'};
    uint8_t embedded_nul[5] = {'P', 0u, 'N', 'G', 0u};

    fixture_init(&f, SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN);
    link_up(&f, 1u);
    tx_result(&f, SESSION_TX_OK);
    check(rx(&f, 1u, "MOVE 1 e2e4") == 0u,
          "pre-hello game payload ignored");
    rx(&f, 1u, "HELLO DIRECT GUEST");
    expect_send(&f, "BYE", 1u, "role-conflict hello closes");
    tx_result(&f, SESSION_TX_OK);
    check(find_action(&f, SESSION_ACT_LINK_CLOSE) != 0,
          "role-conflict close action");
    check(find_action(&f, SESSION_ACT_SESSION_CHANGED) != 0,
          "role-conflict ended action");

    fixture_init(&f, SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN);
    f.state.link_up = 1u;
    f.state.active_link = 1u;
    f.state.peer_ready = 1u;
    f.state.deferred_decision = 0u;
    f.state.phase = SESSION_PHASE_ACTIVE;
    f.state.local_color = SESSION_COLOR_BLACK;
    f.state.timer_mask = (uint8_t)(1u << SESSION_TIMER_LIVENESS);
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_RX;
    event.data.rx.payload = missing_sentinel;
    event.data.rx.length = 4u;
    event.data.rx.link_id = 1u;
    event.data.rx.flags = SESSION_RX_LIVE;
    check(run(&f, &event) == 0u, "missing input sentinel rejected");
    event.data.rx.payload = embedded_nul;
    check(run(&f, &event) == 0u, "embedded input nul rejected");

    rx(&f, 1u, "MOVE 3 e2e4");
    expect_send(&f, "NACK 3 SYNC", 1u, "out-of-order move nacked");
    check(count_actions(&f, SESSION_ACT_SEND) == 1u,
          "one send for invalid move");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    rx(&f, 1u, "GAME START WHITE=HOST");
    expect_send(&f, "NACK GAME START HOST", 1u,
                "host rejects remote start");
    action = find_action(&f, SESSION_ACT_SEND);
    check(action != 0 && action->data.send.payload == f.tx,
          "send payload uses caller scratch");
}

static void test_restore(void)
{
    Fixture host;
    Fixture guest;
    char restore[SESSION_RESTORE_BYTES + 1u];
    char chunk[36];
    SessionAction *action;
    uint8_t i;

    for (i = 0u; i < SESSION_RESTORE_BYTES; ++i) {
        restore[i] = (char)('A' + (i % 26u));
    }
    restore[SESSION_RESTORE_BYTES] = '\0';

    make_active(&host, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    check(local_request_phase(&host, SESSION_REQUEST_RESTORE, 7u, restore,
                              SESSION_PHASE_HANDSHAKE) == 0u &&
              host.state.pending_control == 0u &&
              host.state.phase == SESSION_PHASE_ACTIVE,
          "local restore rejects invalid snapshot phase");
    local_request_phase(&host, SESSION_REQUEST_RESTORE, 7u, restore,
                        SESSION_PHASE_READY);
    expect_send(&host, "RQ", 1u, "restore request");
    tx_result(&host, SESSION_TX_OK);
    rx(&host, 1u, "RY");
    memcpy(chunk, "RS00 ", 5u);
    memcpy(chunk + 5u, restore, 30u);
    chunk[35] = '\0';
    expect_send(&host, chunk, 1u, "restore chunk zero");
    tx_result(&host, SESSION_TX_OK);
    memcpy(chunk, "RS01 ", 5u);
    memcpy(chunk + 5u, restore + 30u, 30u);
    expect_send(&host, chunk, 1u, "restore chunk one");
    tx_result(&host, SESSION_TX_OK);
    rx(&host, 1u, "RA");
    action = find_action(&host, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.kind == SESSION_DELIVER_RESTORE &&
              action->data.game.value == 7u,
          "restore host applies after RA");
    check(host.state.current_ply == 7u,
          "restore host synchronizes reducer ply");
    check(host.state.phase == SESSION_PHASE_READY,
          "active host restore adopts ready snapshot phase");
    check(local_request(&host, SESSION_REQUEST_MOVE, 0u, "e2e4") == 0u,
          "ready restore rejects active-only move");

    make_active(&guest, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    guest.state.phase = SESSION_PHASE_OVER;
    rx(&guest, 1u, "RQ");
    action = find_action(&guest, SESSION_ACT_REQUEST_DECISION);
    check(action != 0 && action->data.decision.control == SESSION_REQUEST_RESTORE,
          "restore asks guest");
    user_decision(&guest, SESSION_DECISION_ACCEPT);
    expect_send(&guest, "RY", 1u, "restore yes");
    tx_result(&guest, SESSION_TX_OK);
    check(guest.state.timer_mask ==
              (uint8_t)(1u << SESSION_TIMER_CONTROL),
          "restore receive leaves only control timer armed");
    memcpy(chunk, "RS00 ", 5u);
    memcpy(chunk + 5u, restore, 30u);
    chunk[35] = '\0';
    rx(&guest, 1u, chunk);
    memcpy(chunk, "RS01 ", 5u);
    memcpy(chunk + 5u, restore + 30u, 30u);
    rx(&guest, 1u, chunk);
    action = find_action(&guest, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.kind == SESSION_DELIVER_RESTORE &&
              action->data.game.length == SESSION_RESTORE_BYTES,
          "complete restore delivered");
    check(game_result(&guest, SESSION_GAME_ACCEPTED, 7u, 0) == 0u &&
              guest.state.phase == SESSION_PHASE_OVER,
          "accepted restore requires snapshot phase");
    check(game_result_phase(&guest, SESSION_GAME_ACCEPTED, 7u,
                            SESSION_PHASE_HANDSHAKE) == 0u &&
              guest.state.phase == SESSION_PHASE_OVER,
          "accepted restore rejects invalid snapshot phase");
    game_result_phase(&guest, SESSION_GAME_ACCEPTED, 7u,
                      SESSION_PHASE_ACTIVE);
    expect_send(&guest, "RA", 1u, "restore applied ack");
    check(guest.state.current_ply == 7u,
          "restore guest synchronizes reducer ply");
    check(guest.state.phase == SESSION_PHASE_ACTIVE,
          "over guest restore adopts active snapshot phase");
    tx_result(&guest, SESSION_TX_OK);
    rx(&guest, 1u, chunk);
    expect_send(&guest, "RA", 1u, "duplicate restore chunk re-acks RA");
    tx_result(&guest, SESSION_TX_OK);
    rx(&guest, 1u, "MOVE 8 e2e4");
    action = find_action(&guest, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_REMOTE_MOVE &&
              action->data.game.value == 8u,
          "move after guest restore uses restored ply");
}

static void test_duplicate_hello_and_reconnect(void)
{
    Fixture f;
    SessionAction *action;
    SessionEvent event;

    fixture_init(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    link_up(&f, 1u);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "HELLO DIRECT GUEST");
    tx_result(&f, SESSION_TX_OK);
    check(rx(&f, 1u, "HELLO DIRECT GUEST") != 0u,
          "duplicate hello keeps liveness observable");
    check(count_actions(&f, SESSION_ACT_SEND) == 0u,
          "duplicate hello does not echo");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    check(rx(&f, 1u, "HELLO DIRECT HOST WHITE=HOST") != 0u,
          "same active hello is idempotent");
    check(count_actions(&f, SESSION_ACT_SEND) == 0u &&
              count_actions(&f, SESSION_ACT_SIDE_CHANGED) == 0u,
          "same active hello changes nothing");
    rx(&f, 1u, "HELLO DIRECT HOST WHITE=GUEST");
    expect_send(&f, "BYE", 1u, "conflicting active hello closes");

    fixture_init(&f, SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN);
    f.state.link_up = 1u;
    f.state.active_link = 1u;
    f.state.peer_ready = 1u;
    f.state.deferred_decision = 0u;
    f.state.phase = SESSION_PHASE_ACTIVE;
    f.state.local_color = SESSION_COLOR_BLACK;
    f.state.timer_mask = (uint8_t)(1u << SESSION_TIMER_LIVENESS);
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LINK_DOWN;
    event.data.link.link_id = 1u;
    check(run(&f, &event) == 2u, "active link down cancels and ends");
    expect_type_at(&f, 0u, SESSION_ACT_TIMER_CANCEL,
                   "link down cancels timer first");
    expect_type_at(&f, 1u, SESSION_ACT_SESSION_CHANGED,
                   "link down ends after cancellation");
    check(f.actions[1].data.session.status == SESSION_CHANGED_ENDED,
          "link down emits ended");
    check(run(&f, &event) == 0u, "repeated link down is idempotent");
    check(f.state.local_color == SESSION_COLOR_UNKNOWN,
          "ended guest forgets learned side");
    link_up(&f, 2u);
    expect_send(&f, "HELLO DIRECT GUEST", 2u, "fresh reconnect hello");
    check(f.state.phase == SESSION_PHASE_HANDSHAKE &&
              f.state.current_ply == 0u,
          "fresh reconnect starts initial state");
    action = find_action(&f, SESSION_ACT_SEND);
    check(action != 0 && action->data.send.link_id == 2u,
          "fresh reconnect uses new link");
}

static void test_prehello_keepalive_is_bounded(void)
{
    Fixture f;

    fixture_init(&f, SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN);
    link_up(&f, 1u);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "PING");
    expect_send(&f, "ACK PING", 1u, "pre-hello ping is acknowledged");
    tx_result(&f, SESSION_TX_OK);
    expect_timer(&f, SESSION_TIMER_CONTROL, SESSION_DIRECT_HELLO_TICKS,
                 "pre-hello ping ack rearms handshake");
    check(rx(&f, 1u, "ACK PING") == 0u,
          "pre-hello ping ack does not create liveness timer");
    rx(&f, 1u, "BUSY");
    check(f.count == 4u, "pre-hello busy fits action capacity");
    expect_type_at(&f, 0u, SESSION_ACT_TIMER_CANCEL,
                   "pre-hello busy cancels handshake timer");
    expect_type_at(&f, 1u, SESSION_ACT_SESSION_CHANGED,
                   "pre-hello busy reports busy");
    expect_type_at(&f, 2u, SESSION_ACT_LINK_CLOSE,
                   "pre-hello busy closes link");
    expect_type_at(&f, 3u, SESSION_ACT_SESSION_CHANGED,
                   "pre-hello busy ends session");
    check(f.state.phase == SESSION_PHASE_IDLE,
          "pre-hello busy resets state");
}

static void test_lost_ack_and_move_conflict(void)
{
    Fixture f;
    SessionAction *local_action;
    SessionAction *remote_action;

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "e2e4");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "MOVE 2 e7e5");
    check(f.count == 4u, "lost ack inference action count");
    expect_type_at(&f, 0u, SESSION_ACT_TIMER_CANCEL,
                   "lost ack cancels local reply timer");
    expect_type_at(&f, 1u, SESSION_ACT_DELIVER_GAME,
                   "lost ack delivers local move first");
    expect_type_at(&f, 2u, SESSION_ACT_DELIVER_GAME,
                   "lost ack delivers remote move second");
    expect_type_at(&f, 3u, SESSION_ACT_TIMER_SET,
                   "lost ack guards remote domain result");
    local_action = &f.actions[1];
    remote_action = &f.actions[2];
    check(local_action->data.game.kind == SESSION_DELIVER_LOCAL_MOVE &&
              local_action->data.game.length == 4u &&
              memcmp(local_action->data.game.payload, "e2e4", 4u) == 0,
          "lost ack preserves local move payload");
    check(remote_action->data.game.kind == SESSION_DELIVER_REMOTE_MOVE &&
              remote_action->data.game.value == 2u &&
              remote_action->data.game.length == 4u &&
              memcmp(remote_action->data.game.payload, "e7e5", 4u) == 0,
          "lost ack then delivers remote move");
    game_result(&f, SESSION_GAME_ACCEPTED, 2u, "e5");
    expect_send(&f, "ACK 2 e5", 1u, "lost ack remote move ack");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "e2e4");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "MOVE 1 d7d5");
    expect_send(&f, "NACK 1 BUSY", 1u,
                "same ply remote move cannot replace local move");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.pending_control == SESSION_REQUEST_MOVE &&
              f.state.pending_value == 1u &&
              memcmp(f.workspace.move, "e2e4", 4u) == 0,
          "same ply conflict preserves local move");
}

static void test_invalid_local_preserves_state(void)
{
    Fixture f;
    SessionState before;
    SessionEvent event;
    uint8_t i;

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    before = f.state;
    check(local_request(&f, SESSION_REQUEST_START, 0u, 0) == 0u,
          "guest local start rejected");
    check(memcmp(&f.state, &before, sizeof(before)) == 0,
          "invalid guest start preserves state");
    check(local_request(&f, SESSION_REQUEST_MOVE, 0u, "bad") == 0u,
          "malformed local move rejected");
    check(memcmp(&f.state, &before, sizeof(before)) == 0,
          "malformed local move preserves state");

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LOCAL_REQUEST;
    event.data.local.request = 99u;
    check(run(&f, &event) == 0u, "unknown local request rejected");
    check(memcmp(&f.state, &before, sizeof(before)) == 0,
          "unknown local request preserves state");

    memset(f.tx, 0xA5, sizeof(f.tx));
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LOCAL_REQUEST;
    event.data.local.request = SESSION_REQUEST_TAKEBACK;
    event.data.local.value = 3u;
    check(run_with_capacity(&f, &event, 4u) == 0u,
          "small takeback scratch rejected");
    for (i = 4u; i < 16u; ++i) {
        check(f.tx[i] == 0xA5u, "small scratch not overwritten past capacity");
    }
}

static void test_timeout_interleaving(void)
{
    Fixture f;
    uint8_t request_id;

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RESET");
    request_id = f.state.pending_request_id;
    check(link_up(&f, 2u) == 3u,
          "candidate during decision receives busy");
    expect_send(&f, "BUSY", 2u, "busy targets decision-time candidate");
    check(f.state.pending_request_id == request_id,
          "busy preserves pending decision");
    tx_result(&f, SESSION_TX_OK);
    check(find_action(&f, SESSION_ACT_LINK_CLOSE) != 0 &&
              f.state.pending_request_id == request_id,
          "candidate close preserves decision");
    rx(&f, 1u, "PING");
    expect_send(&f, "ACK PING", 1u, "ping during decision is acknowledged");
    check(user_decision(&f, SESSION_DECISION_REJECT) == 0u,
          "decision is deferred during ping ack tx");
    check(f.state.deferred_decision == SESSION_DECISION_REJECT &&
              f.state.pending_request_id == request_id,
          "deferred decision is retained by core");
    tx_result(&f, SESSION_TX_OK);
    expect_send(&f, "NACK RESET", 1u,
                "deferred decision runs after ping ack handoff");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RESET");
    request_id = f.state.pending_request_id;
    rx(&f, 1u, "GAME START WHITE=HOST");
    expect_send(&f, "NACK GAME START BUSY", 1u,
                "busy start is rejected during open prompt");
    check(user_decision(&f, SESSION_DECISION_REJECT) == 0u &&
              f.state.deferred_decision == SESSION_DECISION_REJECT &&
              f.state.pending_request_id == request_id,
          "prompt decision waits for busy-start handoff");
    tx_result(&f, SESSION_TX_OK);
    expect_send(&f, "NACK RESET", 1u,
                "prompt decision runs after busy-start handoff");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RESET");
    request_id = f.state.pending_request_id;
    rx(&f, 1u, "RQ");
    expect_send(&f, "RN", 1u,
                "busy restore request is rejected during open prompt");
    check(user_decision(&f, SESSION_DECISION_ACCEPT) == 0u &&
              f.state.deferred_decision == SESSION_DECISION_ACCEPT &&
              f.state.pending_request_id == request_id,
          "prompt acceptance waits for restore rejection handoff");
    tx_result(&f, SESSION_TX_OK);
    expect_send(&f, "ACK RESET", 1u,
                "prompt acceptance runs after restore rejection handoff");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "MOVE 1 e2e4");
    request_id = f.state.pending_request_id;
    rx(&f, 1u, "PING");
    expect_send(&f, "ACK PING", 1u, "ping acknowledged during domain wait");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "GAME START WHITE=HOST");
    expect_send(&f, "NACK GAME START BUSY", 1u,
                "start rejected during domain wait");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "RQ");
    expect_send(&f, "RN", 1u, "restore rejected during domain wait");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.pending_request_id == request_id,
          "serialized replies preserve domain delivery");
    game_result(&f, SESSION_GAME_ACCEPTED, 1u, "e4");
    expect_send(&f, "ACK 1 e4", 1u,
                "domain result remains sendable after serialized replies");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "e2e4");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "PING");
    expect_send(&f, "ACK PING", 1u,
                "ping acknowledged during local protocol wait");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "GAME START WHITE=HOST");
    expect_send(&f, "NACK GAME START BUSY", 1u,
                "start rejected during local protocol wait");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "RQ");
    expect_send(&f, "RN", 1u,
                "restore rejected during local protocol wait");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK 1 e4");
    check(f.state.pending_control == 0u,
          "local protocol reply remains consumable after serialized replies");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "PING");
    timeout(&f, SESSION_TIMER_LIVENESS);
    check(count_actions(&f, SESSION_ACT_SEND) == 0u &&
              find_action(&f, SESSION_ACT_LINK_CLOSE) == 0,
          "liveness timeout deferred during tx");
    expect_timer(&f, SESSION_TIMER_LIVENESS, SESSION_DIRECT_IDLE_TICKS,
                 "liveness timeout rearmed during ack tx");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "MOVE 1 e2e4");
    timeout(&f, SESSION_TIMER_CONTROL);
    expect_send(&f, "NACK 1 TIMEOUT", 1u,
                "remote move domain timeout nacked");
    check(f.state.pending_request_id == 0u &&
              f.state.pending_control == 0u,
          "remote move timeout clears pending domain work");
    tx_result(&f, SESSION_TX_OK);
    expect_timer(&f, SESSION_TIMER_LIVENESS, SESSION_DIRECT_IDLE_TICKS,
                 "remote move timeout resumes liveness");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    f.state.current_ply = 3u;
    local_request(&f, SESSION_REQUEST_TAKEBACK, 3u, 0);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK 3");
    timeout(&f, SESSION_TIMER_CONTROL);
    check(find_action(&f, SESSION_ACT_LINK_CLOSE) != 0 &&
              find_action(&f, SESSION_ACT_SESSION_CHANGED) != 0,
          "local takeback apply timeout ends inconsistent session");
}

static void test_draw_reset_cancel_timeout(void)
{
    static const uint8_t controls[] = {
        SESSION_REQUEST_DRAW, SESSION_REQUEST_RESET
    };
    static const char *const requests[] = { "DRAW", "RESET" };
    static const char *const cancels[] = { "CANCEL DRAW", "CANCEL RESET" };
    static const char *const nacks[] = { "NACK DRAW", "NACK RESET" };
    Fixture f;
    uint8_t role;
    uint8_t item;
    uint8_t retry;
    uint8_t request_id;

    for (role = SESSION_ROLE_HOST; role <= SESSION_ROLE_GUEST; ++role) {
        for (item = 0u; item < 2u; ++item) {
            make_active(&f, role,
                        role == SESSION_ROLE_HOST ? SESSION_COLOR_WHITE
                                                  : SESSION_COLOR_BLACK);
            local_request(&f, controls[item], 0u, 0);
            expect_send(&f, requests[item], 1u, "control request sent");
            tx_result(&f, SESSION_TX_OK);
            for (retry = 0u; retry < SESSION_DIRECT_REPLY_RETRIES; ++retry) {
                timeout(&f, SESSION_TIMER_CONTROL);
                expect_send(&f, requests[item], 1u,
                            "control transport retry sent");
                tx_result(&f, SESSION_TX_OK);
            }
            timeout(&f, SESSION_TIMER_CONTROL);
            check(find_action(&f, SESSION_ACT_LINK_CLOSE) == 0,
                  "unanswered control keeps session open");
            expect_timer(&f, SESSION_TIMER_CONTROL,
                         SESSION_CONTROL_CANCEL_TICKS,
                         "unanswered control starts five minute wait");
            check((f.state.timer_mask &
                   (uint8_t)(1u << SESSION_TIMER_LIVENESS)) != 0u,
                  "five minute control wait preserves liveness");

            timeout(&f, SESSION_TIMER_CONTROL);
            expect_send(&f, cancels[item], 1u, "control cancellation sent");
            tx_result(&f, SESSION_TX_OK);
            rx(&f, 1u, nacks[item]);
            expect_control_result(&f, controls[item],
                                  SESSION_CONTROL_CANCELLED,
                                  "cancel confirmation reports no response");
            check(f.state.pending_control == 0u &&
                      find_action(&f, SESSION_ACT_LINK_CLOSE) == 0,
                  "cancel confirmation resumes live session");

            make_active(&f, role,
                        role == SESSION_ROLE_HOST ? SESSION_COLOR_WHITE
                                                  : SESSION_COLOR_BLACK);
            rx(&f, 1u, requests[item]);
            request_id = f.state.pending_request_id;
            check(request_id != 0u, "remote control opens decision");
            rx(&f, 1u, cancels[item]);
            expect_send(&f, nacks[item], 1u,
                        "remote cancellation uses existing nack wrapper");
            check(user_decision(&f, SESSION_DECISION_ACCEPT) == 0u,
                  "cancel invalidates stale modal decision");
            tx_result(&f, SESSION_TX_OK);
            expect_control_result(&f, controls[item],
                                  SESSION_CONTROL_EXPIRED,
                                  "remote cancellation reports expired request");
            check(f.state.phase == SESSION_PHASE_ACTIVE &&
                      f.state.pending_control == 0u &&
                      f.state.pending_request_id == 0u,
                  "remote cancellation preserves active game");
        }
    }
}

static void test_short_tx_is_atomic(void)
{
    Fixture f;
    SessionState before;
    SessionWorkspace workspace_before;
    SessionEvent event;
    char restore[SESSION_RESTORE_BYTES + 1u];
    uint8_t i;

    for (i = 0u; i < SESSION_RESTORE_BYTES; ++i) {
        restore[i] = 'A';
    }
    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    before = f.state;
    workspace_before = f.workspace;
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LOCAL_REQUEST;
    event.data.local.request = SESSION_REQUEST_MOVE;
    event.data.local.payload = (const uint8_t *)"e2e4";
    event.data.local.length = 4u;
    check(run_with_capacity(&f, &event, 8u) == 0u,
          "short move scratch rejected");
    check(memcmp(&f.state, &before, sizeof(before)) == 0 &&
              memcmp(&f.workspace, &workspace_before,
                     sizeof(workspace_before)) == 0,
          "short move scratch is atomic");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    before = f.state;
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LOCAL_REQUEST;
    event.data.local.request = SESSION_REQUEST_RESET;
    check(run_with_capacity(&f, &event, 2u) == 0u,
          "short reset scratch rejected");
    check(memcmp(&f.state, &before, sizeof(before)) == 0,
          "short reset scratch is atomic");

    fixture_init(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    f.state.link_up = 1u;
    f.state.active_link = 1u;
    f.state.peer_ready = 1u;
    f.state.phase = SESSION_PHASE_READY;
    f.state.timer_mask = (uint8_t)(1u << SESSION_TIMER_LIVENESS);
    before = f.state;
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LOCAL_REQUEST;
    event.data.local.request = SESSION_REQUEST_START;
    check(run_with_capacity(&f, &event, 8u) == 0u,
          "short start scratch rejected");
    check(memcmp(&f.state, &before, sizeof(before)) == 0,
          "short start scratch is atomic");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    before = f.state;
    workspace_before = f.workspace;
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LOCAL_REQUEST;
    event.data.local.request = SESSION_REQUEST_RESTORE;
    event.data.local.payload = (const uint8_t *)restore;
    event.data.local.length = SESSION_RESTORE_BYTES;
    event.data.local.phase = f.state.phase;
    check(run_with_capacity(&f, &event, 2u) == 0u,
          "short restore scratch rejected");
    check(memcmp(&f.state, &before, sizeof(before)) == 0 &&
              memcmp(&f.workspace, &workspace_before,
                     sizeof(workspace_before)) == 0,
          "short restore scratch is atomic");
}

static void test_draw_and_crossed_controls(void)
{
    Fixture f;
    SessionAction *action;

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_DRAW, 0u, 0);
    expect_send(&f, "DRAW", 1u, "local draw send");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK DRAW");
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
              action->data.game.delivery_id == SESSION_CONTROL_ACCEPTED &&
              action->data.game.value == SESSION_REQUEST_DRAW,
          "draw ack reports game result");
    expect_send(&f, "RESET", 1u, "draw ack starts rematch reset");
    check(f.state.pending_control == SESSION_REQUEST_RESET,
          "draw rematch waits reset ack");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_DRAW, 0u, 0);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "DRAW");
    expect_send(&f, "ACK DRAW", 1u, "crossed draw accepted");
    tx_result(&f, SESSION_TX_OK);
    expect_control_result(&f, SESSION_REQUEST_DRAW,
                          SESSION_CONTROL_ACCEPTED,
                          "crossed draw reports accepted completion");
    expect_send(&f, "RESET", 1u, "crossed draw advances to reset");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "DRAW");
    expect_send(&f, "ACK DRAW", 1u,
                "duplicate crossed draw re-acked during reset");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.pending_control == SESSION_REQUEST_RESET,
          "duplicate draw preserves rematch reset");
    rx(&f, 1u, "RESET");
    expect_send(&f, "ACK RESET", 1u,
                "crossed draw reset is accepted in game-over phase");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.phase == SESSION_PHASE_ACTIVE &&
              f.state.pending_control == 0u,
          "crossed draw reset starts rematch");
    check(find_action(&f, SESSION_ACT_DELIVER_GAME) != 0 &&
              find_action(&f, SESSION_ACT_DELIVER_GAME)->data.game.kind ==
                  SESSION_DELIVER_CONTROL_RESULT &&
              find_action(&f, SESSION_ACT_DELIVER_GAME)
                      ->data.game.delivery_id == SESSION_CONTROL_ACCEPTED,
          "crossed local reset reports local control result");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_RESET, 0u, 0);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "RESET");
    expect_send(&f, "NACK RESET BUSY", 1u,
                "crossed active reset resolves busy");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.pending_control == SESSION_REQUEST_RESET,
          "busy reply preserves local reset");
    rx(&f, 1u, "NACK RESET BUSY");
    expect_control_result(&f, SESSION_REQUEST_RESET,
                          SESSION_CONTROL_REJECTED,
                          "peer busy reports rejected reset");
    check(f.state.pending_control == 0u,
          "peer busy reply ends crossed local reset");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "DRAW");
    user_decision(&f, SESSION_DECISION_ACCEPT);
    tx_result(&f, SESSION_TX_OK);
    timeout(&f, SESSION_TIMER_CONTROL);
    expect_send(&f, "RESET", 1u,
                "draw receiver retries a missing rematch reset");
    check(f.state.pending_origin != 0u,
          "draw receiver owns fallback reset after timeout");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK RESET");
    check(f.state.phase == SESSION_PHASE_ACTIVE &&
              f.state.pending_control == 0u,
          "draw receiver fallback reset converges to active game");
}

static void test_draw_rematch_two_peers(void)
{
    Fixture host;
    Fixture guest;
    SessionAction *action;

    make_active(&host, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    make_active(&guest, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);

    local_request(&host, SESSION_REQUEST_DRAW, 0u, 0);
    expect_send(&host, "DRAW", 1u, "two-peer draw request");
    tx_result(&host, SESSION_TX_OK);

    rx(&guest, 1u, "DRAW");
    action = find_action(&guest, SESSION_ACT_REQUEST_DECISION);
    check(action != 0 &&
              action->data.decision.control == SESSION_REQUEST_DRAW,
          "two-peer draw asks remote player");
    user_decision(&guest, SESSION_DECISION_ACCEPT);
    expect_send(&guest, "ACK DRAW", 1u, "two-peer draw accepted");
    tx_result(&guest, SESSION_TX_OK);
    check(guest.state.phase == SESSION_PHASE_OVER &&
              guest.state.pending_control == SESSION_REQUEST_RESET &&
              guest.state.timer_mask ==
                  (uint8_t)(1u << SESSION_TIMER_CONTROL),
          "accepted draw waits reset with only control timer");

    rx(&host, 1u, "ACK DRAW");
    expect_send(&host, "RESET", 1u, "two-peer draw starts reset");
    tx_result(&host, SESSION_TX_OK);

    rx(&guest, 1u, "RESET");
    expect_send(&guest, "ACK RESET", 1u,
                "two-peer rematch reset acknowledged");
    tx_result(&guest, SESSION_TX_OK);
    action = find_action(&guest, SESSION_ACT_SESSION_CHANGED);
    check(action != 0 && action->data.session.status == SESSION_CHANGED_STARTED,
          "remote peer reports rematch started");

    rx(&host, 1u, "ACK RESET");
    action = find_action(&host, SESSION_ACT_SESSION_CHANGED);
    check(action != 0 && action->data.session.status == SESSION_CHANGED_STARTED,
          "initiating peer reports rematch started");
    check(host.state.phase == SESSION_PHASE_ACTIVE &&
              guest.state.phase == SESSION_PHASE_ACTIVE &&
              host.state.pending_control == 0u &&
              guest.state.pending_control == 0u &&
              host.state.timer_mask ==
                  (uint8_t)(1u << SESSION_TIMER_LIVENESS) &&
              guest.state.timer_mask ==
                  (uint8_t)(1u << SESSION_TIMER_LIVENESS),
          "two-peer rematch converges to active liveness");
}

static void test_duplicate_control_preserves_pending(void)
{
    Fixture f;

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RESET");
    user_decision(&f, SESSION_DECISION_ACCEPT);
    tx_result(&f, SESSION_TX_OK);
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "e2e4");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "RESET");
    expect_send(&f, "NACK RESET BUSY", 1u,
                "reset behind local move is rejected busy");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.pending_control == SESSION_REQUEST_MOVE &&
              f.state.pending_origin != 0u &&
              f.state.pending_value == 1u,
          "duplicate reset cannot overwrite pending move");
}

static void test_start_conflicts(void)
{
    Fixture f;

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "e2e4");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "GAME START WHITE=HOST");
    expect_send(&f, "NACK GAME START BUSY", 1u,
                "game start is rejected behind pending move");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.pending_control == SESSION_REQUEST_MOVE &&
              f.state.pending_value == 1u,
          "busy start preserves pending move");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "GAME START WHITE=HOST");
    expect_send(&f, "ACK GAME START", 1u,
                "duplicate same-color start re-acked");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.phase == SESSION_PHASE_ACTIVE &&
              f.state.local_color == SESSION_COLOR_BLACK,
          "duplicate start preserves active side");
    rx(&f, 1u, "GAME START WHITE=GUEST");
    expect_send(&f, "ACK GAME START", 1u,
                "active start can update side without restart");
    check(f.state.local_color == SESSION_COLOR_WHITE &&
              find_action(&f, SESSION_ACT_SIDE_CHANGED) != 0,
          "active start publishes updated side");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.phase == SESSION_PHASE_ACTIVE &&
              find_action(&f, SESSION_ACT_SESSION_CHANGED) == 0,
          "active side update does not restart game");

    f.state.phase = SESSION_PHASE_OVER;
    rx(&f, 1u, "GAME START WHITE=HOST");
    expect_send(&f, "ACK GAME START", 1u,
                "idle game-over start is accepted");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.phase == SESSION_PHASE_ACTIVE &&
              find_action(&f, SESSION_ACT_SESSION_CHANGED) != 0 &&
              find_action(&f, SESSION_ACT_SESSION_CHANGED)->data.session.status ==
                  SESSION_CHANGED_STARTED,
          "game-over start begins a fresh game");
}

static void test_control_phase_guards(void)
{
    Fixture f;

    fixture_init(&f, SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN);
    f.state.link_up = 1u;
    f.state.active_link = 1u;
    f.state.peer_ready = 1u;
    f.state.deferred_decision = 0u;
    f.state.phase = SESSION_PHASE_READY;
    f.state.local_color = SESSION_COLOR_BLACK;
    f.state.timer_mask = (uint8_t)(1u << SESSION_TIMER_LIVENESS);

    rx(&f, 1u, "RESET");
    expect_send(&f, "NACK RESET START", 1u,
                "reset before first game rejected");
    check(find_action(&f, SESSION_ACT_REQUEST_DECISION) == 0,
          "pre-start reset has no prompt");
    tx_result(&f, SESSION_TX_OK);

    rx(&f, 1u, "DRAW");
    expect_send(&f, "NACK DRAW", 1u, "draw before first game rejected");
    check(find_action(&f, SESSION_ACT_REQUEST_DECISION) == 0,
          "pre-start draw has no prompt");
    tx_result(&f, SESSION_TX_OK);

    rx(&f, 1u, "TAKEBACK 1");
    expect_send(&f, "NACK 1", 1u,
                "takeback before first game rejected");
    check(find_action(&f, SESSION_ACT_REQUEST_DECISION) == 0,
          "pre-start takeback has no prompt");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "DRAW");
    user_decision(&f, SESSION_DECISION_ACCEPT);
    tx_result(&f, SESSION_TX_OK);
    check(f.state.phase == SESSION_PHASE_OVER,
          "accepted draw enters game-over phase");
    rx(&f, 1u, "RESET");
    expect_send(&f, "ACK RESET", 1u,
                "accepted draw auto-acks rematch reset");
    check(find_action(&f, SESSION_ACT_REQUEST_DECISION) == 0,
          "draw rematch reset has no second prompt");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.phase == SESSION_PHASE_ACTIVE,
          "draw rematch reset starts game");
    check(find_action(&f, SESSION_ACT_DELIVER_GAME) != 0 &&
              find_action(&f, SESSION_ACT_DELIVER_GAME)->data.game.kind ==
                  SESSION_DELIVER_CONTROL,
          "remote draw rematch reset is applied as remote control");
}

static void test_game_results_and_takeback(void)
{
    Fixture f;
    SessionAction *action;
    uint8_t delivery_id;

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "MOVE 1 e2e4");
    delivery_id = f.state.pending_request_id;
    check(game_result_id(&f, (uint8_t)(delivery_id + 1u),
                         SESSION_GAME_ACCEPTED, 1u, "e4") == 0u,
          "stale move result ignored");
    check(f.state.pending_request_id == delivery_id,
          "stale move result preserves pending delivery");
    game_result(&f, SESSION_GAME_REJECTED, 1u, "ILLEGAL");
    expect_send(&f, "NACK 1 ILLEGAL", 1u,
                "move rejection preserves domain reason");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.current_ply == 0u, "rejected move does not advance ply");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "e2e4");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK 1 e4");
    check(f.count == 4u, "local move ack exposes move and notation");
    expect_type_at(&f, 0u, SESSION_ACT_TIMER_CANCEL,
                   "local move ack cancels reply timer");
    expect_type_at(&f, 1u, SESSION_ACT_DELIVER_GAME,
                   "local move ack delivers move");
    expect_type_at(&f, 2u, SESSION_ACT_DELIVER_GAME,
                   "local move ack delivers notation");
    check(f.actions[2].data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
              f.actions[2].data.game.delivery_id ==
                  SESSION_CONTROL_ACCEPTED &&
              f.actions[2].data.game.value == SESSION_REQUEST_MOVE &&
              f.actions[2].data.game.length == 2u &&
              memcmp(f.actions[2].data.game.payload, "e4", 2u) == 0,
          "local move ack notation is observable");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    f.state.current_ply = 3u;
    rx(&f, 1u, "TAKEBACK 3");
    delivery_id = f.state.pending_request_id;
    user_decision(&f, SESSION_DECISION_ACCEPT);
    check(count_actions(&f, SESSION_ACT_SEND) == 0u,
          "takeback not acked before domain apply");
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.kind == SESSION_DELIVER_TAKEBACK &&
              action->data.game.delivery_id == delivery_id &&
              action->data.game.value == 3u,
          "accepted takeback delivered to domain");
    game_result(&f, SESSION_GAME_ACCEPTED, 3u, 0);
    expect_send(&f, "ACK 3", 1u, "takeback ack after domain success");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.current_ply == 2u, "remote takeback result rewinds ply");
    rx(&f, 1u, "TAKEBACK 3");
    expect_send(&f, "ACK 3", 1u,
                "accepted takeback duplicate re-acked without prompt");
    check(find_action(&f, SESSION_ACT_REQUEST_DECISION) == 0 &&
              find_action(&f, SESSION_ACT_DELIVER_GAME) == 0,
          "accepted takeback duplicate is not reapplied");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    f.state.current_ply = 3u;
    rx(&f, 1u, "TAKEBACK 3");
    user_decision(&f, SESSION_DECISION_ACCEPT);
    game_result(&f, SESSION_GAME_FAILED, 3u, "APPLY");
    expect_send(&f, "NACK 3 APPLY", 1u,
                "takeback domain failure nacked");
    tx_result(&f, SESSION_TX_OK);
    check(f.state.current_ply == 3u, "failed takeback keeps ply");
    rx(&f, 1u, "TAKEBACK 3");
    action = find_action(&f, SESSION_ACT_REQUEST_DECISION);
    check(action != 0 &&
              action->data.decision.control == SESSION_REQUEST_TAKEBACK,
          "takeback after rejection asks again");
}

static void test_resign_duplicate_inflight(void)
{
    Fixture f;
    uint8_t request_id;
    SessionAction *action;

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RESIGN");
    expect_send(&f, "ACK RESIGN", 1u, "first resign ack");
    request_id = f.state.pending_request_id;
    check(rx(&f, 1u, "RESIGN") == 0u,
          "in-flight duplicate resign deferred");
    check(f.state.pending_request_id == request_id &&
              f.state.pending_control == SESSION_REQUEST_RESIGN,
          "in-flight duplicate resign preserves first delivery");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.value == SESSION_REQUEST_RESIGN,
          "first resign still delivered after duplicate");
}

static void test_reply_origin_guards(void)
{
    Fixture f;
    uint8_t request_id;

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RESET");
    request_id = f.state.pending_request_id;
    check(rx(&f, 1u, "ACK RESET") == 0u,
          "peer ack cannot accept its own reset request");
    check(f.state.pending_request_id == request_id &&
              f.state.pending_origin != 0u,
          "hostile reset ack preserves user decision");
    user_decision(&f, SESSION_DECISION_REJECT);
    expect_send(&f, "NACK RESET", 1u,
                "reset decision remains valid after hostile ack");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "MOVE 1 e2e4");
    request_id = f.state.pending_request_id;
    check(rx(&f, 1u, "NACK 1 BUSY") == 0u,
          "peer nack cannot consume its own remote move");
    check(f.state.pending_request_id == request_id,
          "hostile move nack preserves domain delivery");
    game_result(&f, SESSION_GAME_ACCEPTED, 1u, "e4");
    expect_send(&f, "ACK 1 e4", 1u,
                "remote move result survives hostile nack");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    f.state.current_ply = 3u;
    local_request(&f, SESSION_REQUEST_TAKEBACK, 3u, 0);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK 3");
    request_id = f.state.pending_request_id;
    check(rx(&f, 1u, "ACK 3") == 0u,
          "duplicate takeback ack not redelivered");
    check(f.state.pending_request_id == request_id,
          "duplicate takeback ack preserves first delivery id");
}

static void test_prompt_and_restore_timeouts(void)
{
    Fixture f;
    SessionAction *action;
    uint8_t i;
    uint8_t request_id;

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RESET");
    check((f.state.timer_mask & (uint8_t)(1u << SESSION_TIMER_CONTROL)) == 0u,
          "user prompt has no protocol timeout");
    check(timeout(&f, SESSION_TIMER_CONTROL) == 0u &&
              f.state.pending_request_id != 0u,
          "stale control timeout cannot reject open prompt");
    timeout(&f, SESSION_TIMER_LIVENESS);
    expect_send(&f, "PING", 1u, "open prompt keeps guest ping alive");
    tx_result(&f, SESSION_TX_OK);
    expect_timer(&f, SESSION_TIMER_LIVENESS, SESSION_DIRECT_PING_TICKS,
                 "open prompt waits ping response");
    rx(&f, 1u, "ACK PING");
    expect_timer(&f, SESSION_TIMER_LIVENESS, SESSION_DIRECT_IDLE_TICKS,
                 "open prompt ping ack rearms idle liveness");
    check(rx(&f, 1u, "RESET") == 0u,
          "duplicate request while prompt open is ignored");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    f.state.current_ply = 1u;
    rx(&f, 1u, "TAKEBACK 1");
    request_id = f.state.pending_request_id;
    user_decision(&f, SESSION_DECISION_ACCEPT);
    check((f.state.timer_mask &
           (uint8_t)((1u << SESSION_TIMER_LIVENESS) |
                     (1u << SESSION_TIMER_CONTROL))) ==
              (uint8_t)((1u << SESSION_TIMER_LIVENESS) |
                        (1u << SESSION_TIMER_CONTROL)),
          "takeback apply keeps liveness and control deadlines");
    timeout(&f, SESSION_TIMER_LIVENESS);
    expect_send(&f, "PING", 1u,
                "takeback apply prompt does not suspend liveness");
    check(f.state.pending_request_id == request_id &&
              f.state.pending_control == SESSION_REQUEST_TAKEBACK,
          "liveness ping preserves takeback apply prompt");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&f, 1u, "RQ");
    user_decision(&f, SESSION_DECISION_ACCEPT);
    tx_result(&f, SESSION_TX_OK);
    timeout(&f, SESSION_TIMER_CONTROL);
    check(count_actions(&f, SESSION_ACT_SEND) == 0u,
          "restore receive timeout never reverses into RQ");
    expect_timer(&f, SESSION_TIMER_CONTROL, SESSION_DIRECT_REPLY_TICKS,
                 "restore receive timeout rearms wait");
    for (i = 1u; i < SESSION_DIRECT_REPLY_RETRIES; ++i) {
        timeout(&f, SESSION_TIMER_CONTROL);
    }
    timeout(&f, SESSION_TIMER_CONTROL);
    expect_send(&f, "RN", 1u, "restore receive timeout finally cancels");
    check(f.state.restore_mask == 0u,
          "restore receive timeout clears partial state");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
              action->data.game.delivery_id == SESSION_CONTROL_REJECTED &&
              action->data.game.value == SESSION_REQUEST_RESTORE &&
              action->data.game.length == 2u &&
              memcmp(action->data.game.payload, "RN", 2u) == 0,
          "restore receive timeout reports completion");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_RESTORE, 7u,
                  "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGH");
    tx_result(&f, SESSION_TX_OK);
    for (i = 0u; i < SESSION_DIRECT_REPLY_RETRIES; ++i) {
        timeout(&f, SESSION_TIMER_CONTROL);
        expect_send(&f, "RQ", 1u, "restore request timeout retries");
        tx_result(&f, SESSION_TX_OK);
    }
    timeout(&f, SESSION_TIMER_CONTROL);
    expect_send(&f, "RN", 1u, "restore request timeout cancels");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
              action->data.game.delivery_id == SESSION_CONTROL_REJECTED &&
              action->data.game.value == SESSION_REQUEST_RESTORE &&
              action->data.game.length == 2u &&
              memcmp(action->data.game.payload, "RN", 2u) == 0,
          "restore request timeout reports completion");
}

static void test_restore_cancel(void)
{
    Fixture f;
    SessionAction *action;
    char restore[SESSION_RESTORE_BYTES + 1u];

    memset(restore, 'A', SESSION_RESTORE_BYTES);
    restore[SESSION_RESTORE_BYTES] = '\0';

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_RESTORE, 7u, restore);
    tx_result(&f, SESSION_TX_OK);
    local_request(&f, SESSION_REQUEST_RESTORE, 0u, 0);
    expect_send(&f, "RN", 1u, "restore approval wait can be cancelled");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
              action->data.game.delivery_id == SESSION_CONTROL_REJECTED &&
              action->data.game.value == SESSION_REQUEST_RESTORE &&
              action->data.game.length == 2u &&
              memcmp(action->data.game.payload, "RN", 2u) == 0,
          "restore approval cancellation reports completion");
    rx(&f, 1u, "RESET");
    check(find_action(&f, SESSION_ACT_REQUEST_DECISION) != 0,
          "post-cancel control opens a fresh prompt");
    check(timeout(&f, SESSION_TIMER_CONTROL) == 0u &&
              f.state.pending_control == SESSION_REQUEST_RESET &&
              f.state.pending_request_id != 0u,
          "cancelled restore timer cannot consume a later prompt");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_WHITE);
    rx(&f, 1u, "RQ");
    check(find_action(&f, SESSION_ACT_REQUEST_DECISION) != 0,
          "restore cancel setup opens guest prompt");
    rx(&f, 1u, "RN");
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
              action->data.game.delivery_id == SESSION_CONTROL_REJECTED &&
              action->data.game.value == SESSION_REQUEST_RESTORE &&
              f.state.pending_control == 0u &&
              f.state.pending_request_id == 0u,
          "early restore cancel closes remote prompt");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_WHITE);
    rx(&f, 1u, "RQ");
    user_decision(&f, SESSION_DECISION_ACCEPT);
    expect_send(&f, "RY", 1u, "restore cancel setup accepts prompt");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "RN");
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
              action->data.game.delivery_id == SESSION_CONTROL_REJECTED &&
              f.state.pending_control == 0u &&
              f.state.restore_phase == 0u,
          "early restore cancel aborts receiver before chunks");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_RESTORE, 7u, restore);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "RY");
    expect_send(&f, "RS00 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 1u,
                "restore cancel setup sends first chunk");
    tx_result(&f, SESSION_TX_OK);
    expect_send(&f, "RS01 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 1u,
                "restore cancel setup sends second chunk");
    tx_result(&f, SESSION_TX_OK);
    check(local_request(&f, SESSION_REQUEST_RESTORE, 0u, 0) == 0u,
          "restore ack wait cannot be cancelled after chunks");
    check(f.state.pending_control == SESSION_REQUEST_RESTORE &&
              f.state.restore_phase != 0u,
          "ignored late restore cancel preserves pending state");
    rx(&f, 1u, "RA");
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_RESTORE &&
              f.state.pending_control == 0u &&
              f.state.phase == SESSION_PHASE_ACTIVE &&
              f.state.current_ply == 7u,
          "late restore cancel cannot prevent matching RA completion");
}

static void test_bye_during_handshake_and_control(void)
{
    Fixture f;

    fixture_init(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    link_up(&f, 1u);
    tx_result(&f, SESSION_TX_OK);
    local_request(&f, SESSION_REQUEST_BYE, 0u, 0);
    expect_send(&f, "BYE", 1u, "bye allowed during handshake");
    tx_result(&f, SESSION_TX_OK);
    check(find_action(&f, SESSION_ACT_LINK_CLOSE) != 0 &&
              find_action(&f, SESSION_ACT_SESSION_CHANGED) != 0,
          "handshake bye closes and ends");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "e2e4");
    tx_result(&f, SESSION_TX_OK);
    local_request(&f, SESSION_REQUEST_BYE, 0u, 0);
    expect_send(&f, "BYE", 1u, "bye allowed during pending control");
    tx_result(&f, SESSION_TX_OK);
    check(find_action(&f, SESSION_ACT_LINK_CLOSE) != 0 &&
              find_action(&f, SESSION_ACT_SESSION_CHANGED) != 0,
          "pending-control bye closes and ends");
}

static void test_local_handoff_actions(void)
{
    Fixture f;
    SessionAction *action;

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_CHAT, 0u, "hello");
    check(find_action(&f, SESSION_ACT_DELIVER_GAME) == 0,
          "local chat not shown before tx handoff");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.kind == SESSION_DELIVER_CHAT &&
              action->data.game.value == SESSION_CHAT_LOCAL &&
              action->data.game.length == 5u &&
              memcmp(action->data.game.payload, "hello", 5u) == 0,
          "local chat shown after tx handoff");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    rx(&f, 1u, "CHAT hello");
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.kind == SESSION_DELIVER_CHAT &&
              action->data.game.value == SESSION_CHAT_REMOTE &&
              action->data.game.length == 5u &&
              memcmp(action->data.game.payload, "hello", 5u) == 0,
          "remote chat carries distinct origin");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_RESIGN, 0u, 0);
    check(find_action(&f, SESSION_ACT_DELIVER_GAME) == 0,
          "local resign not applied before tx handoff");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.kind == SESSION_DELIVER_CONTROL &&
              action->data.game.value == SESSION_REQUEST_RESIGN &&
              f.state.phase == SESSION_PHASE_OVER,
          "local resign applied after tx handoff");
    timeout(&f, SESSION_TIMER_CONTROL);
    expect_send(&f, "RESIGN", 1u, "local resign retries after lost ack");
    tx_result(&f, SESSION_TX_OK);
    check(find_action(&f, SESSION_ACT_DELIVER_GAME) == 0,
          "local resign retry is not applied twice");
    rx(&f, 1u, "RESIGN");
    expect_send(&f, "ACK RESIGN", 1u, "crossed resign is acknowledged");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
              action->data.game.delivery_id == SESSION_CONTROL_ACCEPTED &&
              action->data.game.value == SESSION_REQUEST_RESIGN,
          "crossed host resign reports acknowledgement once");
    expect_send(&f, "RESET", 1u, "crossed host starts automatic reset");
    check(f.state.pending_control == SESSION_REQUEST_RESET,
          "crossed host owns automatic reset");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK RESET");
    action = find_action(&f, SESSION_ACT_SESSION_CHANGED);
    check(action != 0 &&
              action->data.session.status == SESSION_CHANGED_STARTED &&
              f.state.phase == SESSION_PHASE_ACTIVE,
          "crossed host reset starts new game");

    make_active(&f, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    local_request(&f, SESSION_REQUEST_RESIGN, 0u, 0);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "RESIGN");
    expect_send(&f, "ACK RESIGN", 1u,
                "crossed guest resign is acknowledged");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 &&
              action->data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
              action->data.game.delivery_id == SESSION_CONTROL_ACCEPTED &&
              f.state.pending_control == 0u,
          "crossed guest waits for host automatic reset");
    rx(&f, 1u, "RESET");
    expect_send(&f, "ACK RESET", 1u,
                "crossed guest accepts host reset without prompt");
    check(find_action(&f, SESSION_ACT_REQUEST_DECISION) == 0,
          "post-resign reset never asks the guest");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_SESSION_CHANGED);
    check(action != 0 &&
              action->data.session.status == SESSION_CHANGED_STARTED &&
              f.state.phase == SESSION_PHASE_ACTIVE,
          "crossed guest reset starts new game");
}

static void test_link_zero_busy_bye_and_order(void)
{
    Fixture f;
    SessionAction *action;
    SessionEvent event;

    fixture_init(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    link_up(&f, 0u);
    expect_send(&f, "HELLO DIRECT HOST WHITE=HOST", 0u,
                "raw link zero accepted");
    check(f.state.link_up == 1u && f.state.active_link == 0u,
          "raw link zero stored as active");

    fixture_init(&f, SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN);
    link_up(&f, 1u);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "BUSY");
    action = find_action(&f, SESSION_ACT_SESSION_CHANGED);
    check(action != 0 && action->data.session.status == SESSION_CHANGED_BUSY,
          "inbound busy reported");
    check(find_action(&f, SESSION_ACT_LINK_CLOSE) != 0,
          "inbound busy closes candidate session");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    rx(&f, 1u, "BYE");
    check(find_action(&f, SESSION_ACT_LINK_CLOSE) != 0 &&
              find_action(&f, SESSION_ACT_SESSION_CHANGED) != 0,
          "remote bye closes and ends");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_BYE, 0u, 0);
    expect_send(&f, "BYE", 1u, "local bye send");
    tx_result(&f, SESSION_TX_OK);
    check(find_action(&f, SESSION_ACT_LINK_CLOSE) != 0 &&
              find_action(&f, SESSION_ACT_SESSION_CHANGED) != 0,
          "local bye ends after tx result");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    rx(&f, 1u, "MOVE 1 e2e4");
    expect_type_at(&f, 0u, SESSION_ACT_TIMER_CANCEL,
                   "remote move ordering cancels liveness");
    expect_type_at(&f, 1u, SESSION_ACT_DELIVER_GAME,
                   "remote move ordering delivers domain event");
    expect_type_at(&f, 2u, SESSION_ACT_TIMER_SET,
                   "remote move ordering arms domain timeout");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_CHAT, 0u, "hello");
    check(link_up(&f, 2u) == 1u, "intruder during tx closes immediately");
    action = find_action(&f, SESSION_ACT_LINK_CLOSE);
    check(action != 0 && action->data.link_close.link_id == 2u,
          "intruder close directed during tx");
    tx_result(&f, SESSION_TX_FAILED);
    check(find_action(&f, SESSION_ACT_SESSION_CHANGED) != 0,
          "tx failure ends active session");

    fixture_init(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    link_up(&f, 0u);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 0u, "HELLO DIRECT GUEST");
    tx_result(&f, SESSION_TX_OK);
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LINK_DOWN;
    event.data.link.link_id = 0u;
    check(run(&f, &event) != 0u, "raw link zero down ends session");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    link_up(&f, 2u);
    expect_send(&f, "BUSY", 2u, "candidate busy before active teardown");
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LINK_DOWN;
    event.data.link.link_id = 1u;
    check(run(&f, &event) == 3u,
          "active teardown closes in-flight candidate within capacity");
    expect_type_at(&f, 0u, SESSION_ACT_TIMER_CANCEL,
                   "candidate teardown cancels tx guard");
    expect_type_at(&f, 1u, SESSION_ACT_LINK_CLOSE,
                   "candidate teardown closes candidate");
    check(f.actions[1].data.link_close.link_id == 2u,
          "candidate teardown closes correct link");
    expect_type_at(&f, 2u, SESSION_ACT_SESSION_CHANGED,
                   "candidate teardown ends active session");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    link_up(&f, 2u);
    check(rx(&f, 1u, "BYE") == 4u,
          "bye closes active and in-flight candidate within capacity");
    expect_type_at(&f, 0u, SESSION_ACT_TIMER_CANCEL,
                   "bye cancels candidate tx guard");
    expect_type_at(&f, 1u, SESSION_ACT_LINK_CLOSE,
                   "bye closes active link first");
    check(f.actions[1].data.link_close.link_id == 1u,
          "bye closes correct active link");
    expect_type_at(&f, 2u, SESSION_ACT_LINK_CLOSE,
                   "bye also closes candidate link");
    check(f.actions[2].data.link_close.link_id == 2u,
          "bye closes correct candidate link");
    expect_type_at(&f, 3u, SESSION_ACT_SESSION_CHANGED,
                   "bye ends candidate-bearing session");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    rx(&f, 2u, "HELLO DIRECT GUEST");
    expect_send(&f, "BUSY", 2u,
                "intruder payload receives directed busy");
    expect_type_at(&f, 0u, SESSION_ACT_TIMER_CANCEL,
                   "intruder payload pauses active liveness");
    check(rx(&f, 1u, "BYE") == 4u,
          "bye closes candidate busy started by intruder payload");
    check(f.actions[1].type == SESSION_ACT_LINK_CLOSE &&
              f.actions[1].data.link_close.link_id == 1u &&
              f.actions[2].type == SESSION_ACT_LINK_CLOSE &&
              f.actions[2].data.link_close.link_id == 2u &&
              f.actions[3].type == SESSION_ACT_SESSION_CHANGED,
          "intruder-payload teardown closes both links then ends");
}

static void test_restore_reuse_and_duplicate(void)
{
    Fixture guest;
    Fixture host;
    char first[SESSION_RESTORE_BYTES + 1u];
    char second[SESSION_RESTORE_BYTES + 1u];
    char chunk[36];
    uint8_t delivery_id;
    uint8_t i;

    for (i = 0u; i < SESSION_RESTORE_BYTES; ++i) {
        first[i] = (char)('A' + (i % 26u));
        second[i] = (char)('a' + (i % 26u));
    }
    first[SESSION_RESTORE_BYTES] = '\0';
    second[SESSION_RESTORE_BYTES] = '\0';

    make_active(&host, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    rx(&host, 1u, "RQ");
    expect_send(&host, "RN", 1u, "host rejects restore request");
    check(find_action(&host, SESSION_ACT_REQUEST_DECISION) == 0,
          "host restore request has no prompt");

    make_active(&guest, SESSION_ROLE_GUEST, SESSION_COLOR_BLACK);
    rx(&guest, 1u, "RQ");
    user_decision(&guest, SESSION_DECISION_ACCEPT);
    tx_result(&guest, SESSION_TX_OK);
    memcpy(chunk, "RS00 ", 5u);
    memcpy(chunk + 5u, first, 30u);
    chunk[35] = '\0';
    rx(&guest, 1u, chunk);
    memcpy(chunk, "RS01 ", 5u);
    memcpy(chunk + 5u, first + 30u, 30u);
    rx(&guest, 1u, chunk);
    delivery_id = guest.state.pending_request_id;
    check(find_action(&guest, SESSION_ACT_DELIVER_GAME) != 0,
          "first restore delivered once");
    chunk[5] = 'Z';
    check(rx(&guest, 1u, chunk) == 0u,
          "conflicting chunk ignored while restore result pending");
    check(guest.workspace.restore[30] == (uint8_t)first[30] &&
              guest.state.pending_request_id == delivery_id,
          "conflicting chunk cannot mutate pending restore workspace");
    chunk[5] = first[30];
    rx(&guest, 1u, chunk);
    check(find_action(&guest, SESSION_ACT_DELIVER_GAME) == 0 &&
              guest.state.pending_request_id == delivery_id,
          "duplicate chunk before result not redelivered");
    game_result_phase(&guest, SESSION_GAME_ACCEPTED, 0u,
                      SESSION_PHASE_ACTIVE);
    tx_result(&guest, SESSION_TX_OK);

    memcpy(chunk, "RS01 ", 5u);
    memcpy(chunk + 5u, second + 30u, 30u);
    rx(&guest, 1u, chunk);
    expect_send(&guest, "RN", 1u,
                "different post-apply chunk is rejected");
    tx_result(&guest, SESSION_TX_OK);

    rx(&guest, 1u, "RQ");
    check(find_action(&guest, SESSION_ACT_REQUEST_DECISION) != 0,
          "new restore asks again after completed restore");
    user_decision(&guest, SESSION_DECISION_ACCEPT);
    tx_result(&guest, SESSION_TX_OK);
    memcpy(chunk, "RS00 ", 5u);
    memcpy(chunk + 5u, second, 30u);
    rx(&guest, 1u, chunk);
    check(find_action(&guest, SESSION_ACT_DELIVER_GAME) == 0,
          "new restore first chunk cannot mix old snapshot");
    memcpy(chunk, "RS01 ", 5u);
    memcpy(chunk + 5u, second + 30u, 30u);
    rx(&guest, 1u, chunk);
    check(find_action(&guest, SESSION_ACT_DELIVER_GAME) != 0,
          "new restore delivers only after both fresh chunks");
}

static void test_u16_wire_edges(void)
{
    Fixture f;

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    f.state.current_ply = 9999u;
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "a2a3");
    expect_send(&f, "MOVE 10000 a2a3", 1u, "five-digit move formatting");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    f.state.current_ply = 65534u;
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "a2a3");
    expect_send(&f, "MOVE 65535 a2a3", 1u, "maximum u16 formatting");
}

static void test_48_byte_tx_scratch(void)
{
    Fixture f;
    SessionEvent event;
    char restore[SESSION_RESTORE_BYTES];
    char chunk[36];
    char chat[SESSION_CHAT_TEXT_MAX + 2u];
    char wire[48];
    SessionState before;
    uint8_t i;

    for (i = 0u; i < SESSION_RESTORE_BYTES; ++i) {
        restore[i] = (char)('A' + (i % 26u));
    }
    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LOCAL_REQUEST;
    event.data.local.request = SESSION_REQUEST_RESTORE;
    event.data.local.payload = (const uint8_t *)restore;
    event.data.local.length = SESSION_RESTORE_BYTES;
    event.data.local.phase = f.state.phase;
    run_with_capacity(&f, &event, 48u);
    expect_send(&f, "RQ", 1u, "48-byte scratch restore request");

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_TX_RESULT;
    event.data.tx.tx_id = f.state.pending_tx_id;
    event.data.tx.result = SESSION_TX_OK;
    run_with_capacity(&f, &event, 48u);

    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_RX;
    event.data.rx.payload = (const uint8_t *)"RY";
    event.data.rx.length = 2u;
    event.data.rx.flags = SESSION_RX_LIVE;
    event.data.rx.link_id = 1u;
    run_with_capacity(&f, &event, 48u);
    memcpy(chunk, "RS00 ", 5u);
    memcpy(chunk + 5u, restore, 30u);
    chunk[35] = '\0';
    expect_send(&f, chunk, 1u, "48-byte scratch restore chunk");

    for (i = 0u; i < SESSION_CHAT_TEXT_MAX; ++i) {
        chat[i] = 'x';
    }
    chat[SESSION_CHAT_TEXT_MAX] = '\0';
    memcpy(wire, "CHAT ", 5u);
    memcpy(wire + 5u, chat, SESSION_CHAT_TEXT_MAX + 1u);
    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    memset(&event, 0, sizeof(event));
    event.type = SESSION_EV_LOCAL_REQUEST;
    event.data.local.request = SESSION_REQUEST_CHAT;
    event.data.local.payload = (const uint8_t *)chat;
    event.data.local.length = SESSION_CHAT_TEXT_MAX;
    run_with_capacity(&f, &event, 48u);
    expect_send(&f, wire, 1u, "42-char chat exactly fits 48-byte scratch");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    chat[SESSION_CHAT_TEXT_MAX] = 'y';
    chat[SESSION_CHAT_TEXT_MAX + 1u] = '\0';
    before = f.state;
    event.data.local.length = SESSION_CHAT_TEXT_MAX + 1u;
    check(run_with_capacity(&f, &event, 48u) == 0u,
          "43-char chat rejected by wire bound");
    check(memcmp(&f.state, &before, sizeof(before)) == 0,
          "oversize chat rejection is atomic");
}

static void test_typed_control_results(void)
{
    Fixture f;
    char restore[SESSION_RESTORE_BYTES + 1u];

    check(SESSION_CONTROL_ACCEPTED == SESSION_GAME_ACCEPTED &&
              SESSION_CONTROL_REJECTED == SESSION_GAME_REJECTED,
          "control result aliases preserve ABI values");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "e2e4");
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "NACK 1 ILLEGAL");
    expect_control_result(&f, SESSION_REQUEST_MOVE,
                          SESSION_CONTROL_REJECTED,
                          "move nack reports rejected result");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    f.state.current_ply = 3u;
    local_request(&f, SESSION_REQUEST_TAKEBACK, 3u, 0);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "NACK 3 BUSY");
    expect_control_result(&f, SESSION_REQUEST_TAKEBACK,
                          SESSION_CONTROL_REJECTED,
                          "takeback nack reports rejected result");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_RESIGN, 0u, 0);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK RESIGN");
    expect_control_result(&f, SESSION_REQUEST_RESIGN,
                          SESSION_CONTROL_ACCEPTED,
                          "resign ack reports accepted result");

    fixture_init(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    f.state.link_up = 1u;
    f.state.active_link = 1u;
    f.state.peer_ready = 1u;
    f.state.phase = SESSION_PHASE_READY;
    local_request(&f, SESSION_REQUEST_START, 0u, 0);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "NACK GAME START BUSY");
    expect_control_result(&f, SESSION_REQUEST_START,
                          SESSION_CONTROL_REJECTED,
                          "start nack reports rejected result");

    memset(restore, 'A', SESSION_RESTORE_BYTES);
    restore[SESSION_RESTORE_BYTES] = '\0';
    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_RESTORE, 7u, restore);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "RN");
    expect_control_result(&f, SESSION_REQUEST_RESTORE,
                          SESSION_CONTROL_REJECTED,
                          "restore RN reports rejected result");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    f.state.current_ply = 3u;
    local_request(&f, SESSION_REQUEST_TAKEBACK, 3u, 0);
    tx_result(&f, SESSION_TX_OK);
    rx(&f, 1u, "ACK 3");
    game_result(&f, SESSION_GAME_FAILED, 3u, "APPLY");
    expect_control_result(&f, SESSION_REQUEST_TAKEBACK,
                          SESSION_CONTROL_REJECTED,
                          "takeback apply failure reports rejected result");
}

static void test_chat_while_control_pending(void)
{
    Fixture f;
    SessionAction *action;
    SessionState state_before;
    SessionWorkspace workspace_before;

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_DRAW, 0u, 0);
    tx_result(&f, SESSION_TX_OK);
    local_request(&f, SESSION_REQUEST_CHAT, 0u, "hello");
    expect_send(&f, "CHAT hello", 1u, "chat sends while draw is pending");
    check(f.state.pending_control == SESSION_REQUEST_DRAW,
          "chat preserves pending draw");
    tx_result(&f, SESSION_TX_OK);
    action = find_action(&f, SESSION_ACT_DELIVER_GAME);
    check(action != 0 && action->data.game.kind == SESSION_DELIVER_CHAT &&
              action->data.game.value == SESSION_CHAT_LOCAL &&
              action->data.game.length == 5u &&
              memcmp(action->data.game.payload, "hello", 5u) == 0,
          "chat handoff remains local while draw is pending");
    check(f.state.pending_control == SESSION_REQUEST_DRAW,
          "chat handoff preserves pending draw");

    state_before = f.state;
    workspace_before = f.workspace;
    check(local_request(&f, SESSION_REQUEST_RESIGN, 0u, 0) == 0u &&
              memcmp(&f.state, &state_before, sizeof(state_before)) == 0 &&
              memcmp(&f.workspace, &workspace_before,
                     sizeof(workspace_before)) == 0,
          "second control stays blocked while draw is pending");

    make_active(&f, SESSION_ROLE_HOST, SESSION_COLOR_WHITE);
    local_request(&f, SESSION_REQUEST_MOVE, 0u, "e2e4");
    tx_result(&f, SESSION_TX_OK);
    state_before = f.state;
    workspace_before = f.workspace;
    check(local_request(&f, SESSION_REQUEST_CHAT, 0u, "hello") == 0u &&
              memcmp(&f.state, &state_before, sizeof(state_before)) == 0 &&
              memcmp(&f.workspace, &workspace_before,
                     sizeof(workspace_before)) == 0,
          "pending move workspace still blocks chat");
}

int main(void)
{
    test_hello_and_busy();
    test_start();
    test_moves_and_tx_guard();
    test_controls_and_liveness();
    test_control_replies_and_duplicates();
    test_retry_and_failure_paths();
    test_invalid_and_ordered_inputs();
    test_restore();
    test_duplicate_hello_and_reconnect();
    test_prehello_keepalive_is_bounded();
    test_lost_ack_and_move_conflict();
    test_invalid_local_preserves_state();
    test_timeout_interleaving();
    test_draw_reset_cancel_timeout();
    test_short_tx_is_atomic();
    test_draw_and_crossed_controls();
    test_draw_rematch_two_peers();
    test_duplicate_control_preserves_pending();
    test_start_conflicts();
    test_control_phase_guards();
    test_game_results_and_takeback();
    test_resign_duplicate_inflight();
    test_reply_origin_guards();
    test_prompt_and_restore_timeouts();
    test_restore_cancel();
    test_bye_during_handshake_and_control();
    test_local_handoff_actions();
    test_link_zero_busy_bye_and_order();
    test_restore_reuse_and_duplicate();
    test_u16_wire_edges();
    test_48_byte_tx_scratch();
    test_typed_control_results();
    test_chat_while_control_pending();

    if (failures != 0) {
        printf("direct session core tests failed: %d\n", failures);
        return 1;
    }
    printf("direct session core tests ok\n");
    return 0;
}
