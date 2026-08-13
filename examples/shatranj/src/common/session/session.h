#ifndef NETCHESSZX_COMMON_SESSION_H
#define NETCHESSZX_COMMON_SESSION_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SESSION_TRANSPORT_DIRECT 0u
#define SESSION_TRANSPORT_MQTT 1u

#define SESSION_ROLE_HOST 0u
#define SESSION_ROLE_GUEST 1u

#define SESSION_COLOR_WHITE 0u
#define SESSION_COLOR_BLACK 1u
#define SESSION_COLOR_UNKNOWN 0xFFu

#define SESSION_LINK_NONE 0xFFu

#define SESSION_PHASE_IDLE 0u
#define SESSION_PHASE_HANDSHAKE 1u
#define SESSION_PHASE_READY 2u
#define SESSION_PHASE_ACTIVE 3u
#define SESSION_PHASE_OVER 4u

#define SESSION_EV_LINK_UP 1u
#define SESSION_EV_LINK_DOWN 2u
#define SESSION_EV_RX 3u
#define SESSION_EV_LOCAL_REQUEST 4u
#define SESSION_EV_USER_DECISION 5u
#define SESSION_EV_TX_RESULT 6u
#define SESSION_EV_TIMEOUT 7u
#define SESSION_EV_GAME_RESULT 8u

#define SESSION_REQUEST_START 1u
#define SESSION_REQUEST_MOVE 2u
#define SESSION_REQUEST_CHAT 3u
#define SESSION_REQUEST_RESET 4u
#define SESSION_REQUEST_DRAW 5u
#define SESSION_REQUEST_RESIGN 6u
#define SESSION_REQUEST_TAKEBACK 7u
#define SESSION_REQUEST_BYE 8u
#define SESSION_REQUEST_RESTORE 9u

#define SESSION_DECISION_ACCEPT 1u
#define SESSION_DECISION_REJECT 2u

#define SESSION_TX_OK 1u
#define SESSION_TX_FAILED 2u

#define SESSION_GAME_ACCEPTED 1u
#define SESSION_GAME_REJECTED 2u
#define SESSION_GAME_FAILED 3u

#define SESSION_CONTROL_ACCEPTED SESSION_GAME_ACCEPTED
#define SESSION_CONTROL_REJECTED SESSION_GAME_REJECTED
#define SESSION_CONTROL_CANCELLED SESSION_GAME_FAILED
#define SESSION_CONTROL_EXPIRED 4u

#define SESSION_ACT_SEND 1u
#define SESSION_ACT_TIMER_SET 2u
#define SESSION_ACT_TIMER_CANCEL 3u
#define SESSION_ACT_LINK_CLOSE 4u
#define SESSION_ACT_REQUEST_DECISION 5u
#define SESSION_ACT_DELIVER_GAME 6u
#define SESSION_ACT_SESSION_CHANGED 7u
#define SESSION_ACT_SIDE_CHANGED 8u

#define SESSION_CHANGED_READY 1u
#define SESSION_CHANGED_BUSY 2u
#define SESSION_CHANGED_STARTED 3u
#define SESSION_CHANGED_ENDED 4u

#define SESSION_ROUTE_DEFAULT 0u
#define SESSION_ROUTE_CONTROL 1u
#define SESSION_ROUTE_PRESENCE 2u
#define SESSION_ROUTE_GAME 3u
#define SESSION_ROUTE_ACK 4u
#define SESSION_ROUTE_PRESENCE_PEER 5u
#define SESSION_ROUTE_META 6u

#define SESSION_RX_RETAINED 0x01u
#define SESSION_RX_LIVE 0x02u

#define SESSION_TIMER_TX_GUARD 0u
#define SESSION_TIMER_LIVENESS 1u
#define SESSION_TIMER_CONTROL 2u
#define SESSION_TIMER_COUNT 3u

#define SESSION_PROTOCOL_TICK_MS 20u
#define SESSION_TX_GUARD_TICKS 250u
#define SESSION_DIRECT_HELLO_TICKS 150u
#define SESSION_DIRECT_REPLY_TICKS 125u
#define SESSION_CONTROL_CANCEL_TICKS 15000u
#define SESSION_DIRECT_IDLE_TICKS 150u
#define SESSION_DIRECT_PING_TICKS 450u
#define SESSION_DIRECT_HELLO_RETRIES 5u
#define SESSION_DIRECT_REPLY_RETRIES 5u
#define SESSION_DIRECT_PING_MISSES 2u
#define SESSION_PAYLOAD_MAX 192u
#define SESSION_ACTION_CAPACITY 4u
#define SESSION_DIRECT_TX_CAPACITY_MIN 48u
#define SESSION_RESTORE_BYTES 60u
#define SESSION_CHAT_TEXT_MAX 42u

#define SESSION_DELIVER_REMOTE_MOVE 1u
#define SESSION_DELIVER_LOCAL_MOVE 2u
#define SESSION_DELIVER_CHAT 3u
#define SESSION_DELIVER_CONTROL 4u
#define SESSION_DELIVER_CONTROL_RESULT 5u
#define SESSION_DELIVER_RESTORE 6u
#define SESSION_DELIVER_TAKEBACK 7u

#define SESSION_CHAT_REMOTE 1u
#define SESSION_CHAT_LOCAL 2u

typedef struct SessionConfig {
    uint8_t transport;
    uint8_t role;
    uint8_t host_color;
    uint16_t session_id;
} SessionConfig;

typedef struct SessionEvent {
    uint8_t type;
    union {
        struct {
            uint8_t link_id;
        } link;
        struct {
            const uint8_t *payload;
            uint8_t length;
            uint8_t route;
            uint8_t flags;
            uint8_t link_id;
        } rx;
        struct {
            const uint8_t *payload;
            uint16_t value;
            uint8_t length;
            uint8_t request;
            uint8_t phase;
        } local;
        struct {
            uint8_t request_id;
            uint8_t decision;
        } user;
        struct {
            uint8_t tx_id;
            uint8_t result;
        } tx;
        struct {
            uint8_t timer_id;
        } timeout;
        struct {
            const uint8_t *detail;
            uint16_t value;
            uint8_t detail_length;
            uint8_t delivery_id;
            uint8_t result;
        } game;
    } data;
} SessionEvent;

typedef struct SessionAction {
    uint8_t type;
    union {
        struct {
            const uint8_t *payload;
            uint8_t length;
            uint8_t tx_id;
            uint8_t route;
            uint8_t retained;
            uint8_t link_id;
        } send;
        struct {
            uint16_t duration_ticks;
            uint8_t timer_id;
        } timer_set;
        struct {
            uint8_t timer_id;
        } timer_cancel;
        struct {
            uint16_t value;
            uint8_t request_id;
            uint8_t control;
        } decision;
        struct {
            const uint8_t *payload;
            uint16_t value;
            uint8_t length;
            uint8_t kind;
            uint8_t delivery_id;
        } game;
        struct {
            uint8_t status;
        } session;
        struct {
            uint16_t session_id;
            uint8_t color;
        } side;
        struct {
            uint8_t link_id;
        } link_close;
    } data;
} SessionAction;

typedef union SessionWorkspace {
    char move[6];
    char chat[SESSION_CHAT_TEXT_MAX + 1u];
    uint8_t restore[SESSION_RESTORE_BYTES];
} SessionWorkspace;

typedef struct SessionState {
    SessionConfig config;
    uint16_t session_id;
    uint16_t current_ply;
    uint16_t pending_value;
    uint16_t last_value;
    uint8_t phase;
    uint8_t local_color;
    uint8_t deferred_decision;
    uint8_t peer_ready;
    uint8_t link_up;
    uint8_t active_link;
    uint8_t tx_link;
    uint8_t pending_control;
    uint8_t pending_origin;
    uint8_t pending_request_id;
    uint8_t pending_tx_id;
    uint8_t pending_tx_kind;
    uint8_t next_tx_id;
    uint8_t control_retries;
    uint8_t liveness_misses;
    uint8_t timer_mask;
    uint8_t last_rx_kind;
    uint8_t last_result;
    uint8_t delivery_id;
    uint8_t restore_phase;
    uint8_t restore_mask;
} SessionState;

uint8_t session_init(SessionState *state, const SessionConfig *config);
void session_reset(SessionState *state);
uint8_t session_step(SessionState *state,
                     const SessionEvent *event,
                     SessionWorkspace *workspace,
                     uint8_t *tx_scratch,
                     uint8_t tx_capacity,
                     SessionAction *actions,
                     uint8_t action_capacity);

#ifdef __cplusplus
}
#endif

#endif
