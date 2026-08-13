#ifndef NETCHESSZX_TEST_DIRECT_PARITY_H
#define NETCHESSZX_TEST_DIRECT_PARITY_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define DIRECT_PARITY_ROLE_HOST 0u
#define DIRECT_PARITY_ROLE_GUEST 1u

#define DIRECT_PARITY_COLOR_WHITE 0u
#define DIRECT_PARITY_COLOR_BLACK 1u
#define DIRECT_PARITY_COLOR_UNKNOWN 0xffu

#define DIRECT_PARITY_LINK_NONE 0xffu

#define DIRECT_PARITY_IN_LINK_UP 1u
#define DIRECT_PARITY_IN_RX 2u
#define DIRECT_PARITY_IN_LINK_DOWN 3u
#define DIRECT_PARITY_IN_LOCAL 4u
#define DIRECT_PARITY_IN_DOMAIN 5u
#define DIRECT_PARITY_IN_TIMEOUT 6u
#define DIRECT_PARITY_IN_SEND_FAIL 7u
#define DIRECT_PARITY_IN_DECISION 8u
#define DIRECT_PARITY_IN_SEND_PENDING 9u
#define DIRECT_PARITY_IN_TX_GUARD_TIMEOUT 10u
#define DIRECT_PARITY_IN_TX_RESULT 11u

#define DIRECT_PARITY_REQUEST_START 1u
#define DIRECT_PARITY_REQUEST_MOVE 2u
#define DIRECT_PARITY_REQUEST_CHAT 3u
#define DIRECT_PARITY_REQUEST_RESET 4u
#define DIRECT_PARITY_REQUEST_DRAW 5u
#define DIRECT_PARITY_REQUEST_RESIGN 6u
#define DIRECT_PARITY_REQUEST_TAKEBACK 7u
#define DIRECT_PARITY_REQUEST_BYE 8u
#define DIRECT_PARITY_REQUEST_RESTORE 9u

#define DIRECT_PARITY_PHASE_READY 2u
#define DIRECT_PARITY_PHASE_ACTIVE 3u
#define DIRECT_PARITY_PHASE_OVER 4u

#define DIRECT_PARITY_DECISION_ACCEPT 1u
#define DIRECT_PARITY_DECISION_REJECT 2u

#define DIRECT_PARITY_OBS_SEND 1u
#define DIRECT_PARITY_OBS_READY 2u
#define DIRECT_PARITY_OBS_ENDED 3u
#define DIRECT_PARITY_OBS_SIDE 4u
#define DIRECT_PARITY_OBS_STARTED 5u
#define DIRECT_PARITY_OBS_GAME 6u
#define DIRECT_PARITY_OBS_CONTROL_RESULT 7u
#define DIRECT_PARITY_OBS_DECISION 8u
#define DIRECT_PARITY_OBS_CONTROL 9u
#define DIRECT_PARITY_OBS_CLOSE 10u
#define DIRECT_PARITY_OBS_CHAT 11u

#define DIRECT_PARITY_GAME_LOCAL_MOVE 1u
#define DIRECT_PARITY_GAME_REMOTE_MOVE 2u
#define DIRECT_PARITY_GAME_TAKEBACK 3u
#define DIRECT_PARITY_GAME_RESTORE 4u

#define DIRECT_PARITY_CHAT_REMOTE 1u
#define DIRECT_PARITY_CHAT_LOCAL 2u

#define DIRECT_PARITY_RESULT_ACCEPTED 1u
#define DIRECT_PARITY_RESULT_REJECTED 2u
#define DIRECT_PARITY_RESULT_CANCELLED 3u
#define DIRECT_PARITY_RESULT_EXPIRED 4u

#define DIRECT_PARITY_TX_OK 1u
#define DIRECT_PARITY_TX_FAILED 2u

#define DIRECT_PARITY_PAYLOAD_CAPACITY 61u
#define DIRECT_PARITY_TRACE_CAPACITY 32u

typedef struct DirectParityStep {
    const uint8_t *payload;
    uint8_t type;
    uint8_t link_id;
    uint8_t length;
    uint16_t value;
    uint8_t request;
    /* Session phase for LOCAL; optional correlation id for DOMAIN,
       DECISION, and TX_RESULT (0 means the current pending id). */
    uint8_t phase;
} DirectParityStep;

typedef struct DirectParityObservation {
    uint8_t type;
    uint8_t link_id;
    uint8_t code;
    uint8_t length;
    uint16_t value;
    char payload[DIRECT_PARITY_PAYLOAD_CAPACITY];
} DirectParityObservation;

typedef struct DirectParityScenario {
    const char *id;
    const DirectParityStep *steps;
    const DirectParityObservation *expected;
    uint8_t step_count;
    uint8_t expected_count;
    uint8_t role;
    uint8_t host_color;
} DirectParityScenario;

typedef struct DirectParityTrace {
    DirectParityObservation observations[DIRECT_PARITY_TRACE_CAPACITY];
    uint8_t count;
} DirectParityTrace;

extern const DirectParityScenario direct_parity_host_smoke;
extern const DirectParityScenario direct_parity_guest_smoke;
extern const DirectParityScenario direct_parity_guest_hello_conflict;
extern const DirectParityScenario direct_parity_link_zero;
extern const DirectParityScenario direct_parity_intruder_active;
extern const DirectParityScenario direct_parity_intruder_handshake;
extern const DirectParityScenario direct_parity_intruder_teardown;
extern const DirectParityScenario direct_parity_bye_local_handshake;
extern const DirectParityScenario direct_parity_bye_local_send_fail;
extern const DirectParityScenario direct_parity_bye_local_restore_prompt;
extern const DirectParityScenario direct_parity_bye_remote_active;
extern const DirectParityScenario direct_parity_duplicate_hello;
extern const DirectParityScenario direct_parity_start_host;
extern const DirectParityScenario direct_parity_start_guest;
extern const DirectParityScenario direct_parity_move_local_ack;
extern const DirectParityScenario direct_parity_move_local_stale_results;
extern const DirectParityScenario direct_parity_move_remote_duplicate;
extern const DirectParityScenario direct_parity_move_ply_sync;
extern const DirectParityScenario direct_parity_takeback_local_ack;
extern const DirectParityScenario direct_parity_takeback_remote_accept;
extern const DirectParityScenario direct_parity_takeback_reject_retry;
extern const DirectParityScenario direct_parity_takeback_move_inflight;
extern const DirectParityScenario direct_parity_takeback_latch_next_move;
extern const DirectParityScenario direct_parity_restore_local_active;
extern const DirectParityScenario direct_parity_restore_remote_fresh;
extern const DirectParityScenario direct_parity_restore_cancel_early;
extern const DirectParityScenario direct_parity_restore_cancel_late;
extern const DirectParityScenario direct_parity_restore_remote_rn;
extern const DirectParityScenario direct_parity_restore_reject_retry;
extern const DirectParityScenario direct_parity_restore_crossed_rq;
extern const DirectParityScenario direct_parity_restore_reack_send_fail;
extern const DirectParityScenario direct_parity_intruder_restore_receive;
extern const DirectParityScenario direct_parity_restore_partial_reconnect;
extern const DirectParityScenario direct_parity_liveness_ack;
extern const DirectParityScenario direct_parity_liveness_pending_window;
extern const DirectParityScenario direct_parity_liveness_guest_loss;
extern const DirectParityScenario direct_parity_liveness_host_loss;
extern const DirectParityScenario direct_parity_liveness_prompt_loss;
extern const DirectParityScenario direct_parity_ping_send_fail;
extern const DirectParityScenario direct_parity_ack_ping_send_fail;
extern const DirectParityScenario direct_parity_ack_ping_send_timeout;
extern const DirectParityScenario direct_parity_ack_ping_stale_tx_result;
extern const DirectParityScenario direct_parity_draw_rematch_guest;
extern const DirectParityScenario direct_parity_reset_after_reset;
extern const DirectParityScenario direct_parity_reset_crossed_active;
extern const DirectParityScenario direct_parity_move_pending_controls_busy;
extern const DirectParityScenario direct_parity_takeback_pending_controls_busy;
extern const DirectParityScenario direct_parity_draw_crossed;
extern const DirectParityScenario direct_parity_resign_remote_duplicate;
extern const DirectParityScenario direct_parity_resign_crossed;
extern const DirectParityScenario direct_parity_cancel_local_reset;
extern const DirectParityScenario direct_parity_cancel_remote_draw;

uint8_t direct_reference_run(const DirectParityScenario *scenario,
                             DirectParityTrace *trace);
uint8_t direct_spectrum_run(const DirectParityScenario *scenario,
                            DirectParityTrace *trace);

#ifdef __cplusplus
}
#endif

#endif
