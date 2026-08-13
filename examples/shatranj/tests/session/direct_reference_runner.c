#include "direct_parity.h"

#include "common/session/session.h"

#include <string.h>

typedef struct DirectReferenceRunner {
    SessionState state;
    SessionWorkspace workspace;
    uint8_t tx[SESSION_PAYLOAD_MAX + 1u];
    SessionAction actions[SESSION_ACTION_CAPACITY];
    uint16_t timer_remaining[SESSION_TIMER_COUNT];
    uint8_t timer_mask;
    const uint8_t *fail_payload;
    uint8_t fail_length;
    const uint8_t *pending_send_payload;
    uint8_t pending_send_length;
    uint8_t pending_tx_id;
    uint8_t restore_delivery_id;
} DirectReferenceRunner;

static const uint8_t *restore_phase_payload(uint8_t phase)
{
    static const uint8_t ready[] = "R";
    static const uint8_t active[] = "A";
    static const uint8_t over[] = "O";

    if (phase == SESSION_PHASE_READY) {
        return ready;
    }
    if (phase == SESSION_PHASE_ACTIVE) {
        return active;
    }
    return phase == SESSION_PHASE_OVER ? over : 0;
}

static const uint8_t host_smoke_hello[] = "HELLO DIRECT GUEST";

static const DirectParityStep host_smoke_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation host_smoke_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_host_smoke = {
    "host-link-hello-down",
    host_smoke_steps,
    host_smoke_expected,
    (uint8_t)(sizeof(host_smoke_steps) / sizeof(host_smoke_steps[0])),
    (uint8_t)(sizeof(host_smoke_expected) / sizeof(host_smoke_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t guest_smoke_hello[] =
    "HELLO DIRECT HOST WHITE=HOST";

static const DirectParityStep guest_smoke_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation guest_smoke_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_guest_smoke = {
    "guest-link-hello-down",
    guest_smoke_steps,
    guest_smoke_expected,
    (uint8_t)(sizeof(guest_smoke_steps) / sizeof(guest_smoke_steps[0])),
    (uint8_t)(sizeof(guest_smoke_expected) /
              sizeof(guest_smoke_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t guest_conflict_hello[] =
    "HELLO DIRECT HOST WHITE=GUEST";

static const DirectParityStep guest_hello_conflict_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { guest_conflict_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_conflict_hello) - 1u), 0u, 0u, 0u }
};

static const DirectParityObservation guest_hello_conflict_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 3u, 0u, "BYE" },
    { DIRECT_PARITY_OBS_CLOSE, 1u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_guest_hello_conflict = {
    "guest-conflicting-hello",
    guest_hello_conflict_steps,
    guest_hello_conflict_expected,
    (uint8_t)(sizeof(guest_hello_conflict_steps) /
              sizeof(guest_hello_conflict_steps[0])),
    (uint8_t)(sizeof(guest_hello_conflict_expected) /
              sizeof(guest_hello_conflict_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep link_zero_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 0u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 0u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 0u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation link_zero_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 0u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 0u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_link_zero = {
    "host-link-zero",
    link_zero_steps,
    link_zero_expected,
    (uint8_t)(sizeof(link_zero_steps) / sizeof(link_zero_steps[0])),
    (uint8_t)(sizeof(link_zero_expected) / sizeof(link_zero_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t intruder_ping[] = "PING";

static const DirectParityStep intruder_active_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { intruder_ping, DIRECT_PARITY_IN_RX, 2u,
      (uint8_t)(sizeof(intruder_ping) - 1u), 0u, 0u, 0u },
    { intruder_ping, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(intruder_ping) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 2u, 0u, 0u, 0u, 0u },
    { intruder_ping, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(intruder_ping) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation intruder_active_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 2u, 0u, 4u, 0u, "BUSY" },
    { DIRECT_PARITY_OBS_CLOSE, 2u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 8u, 0u, "ACK PING" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 8u, 0u, "ACK PING" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_intruder_active = {
    "intruder-active-busy-close",
    intruder_active_steps,
    intruder_active_expected,
    (uint8_t)(sizeof(intruder_active_steps) /
              sizeof(intruder_active_steps[0])),
    (uint8_t)(sizeof(intruder_active_expected) /
              sizeof(intruder_active_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep intruder_handshake_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { intruder_ping, DIRECT_PARITY_IN_RX, 2u,
      (uint8_t)(sizeof(intruder_ping) - 1u), 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 2u, 0u, 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation intruder_handshake_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_CLOSE, 2u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_intruder_handshake = {
    "intruder-handshake-close",
    intruder_handshake_steps,
    intruder_handshake_expected,
    (uint8_t)(sizeof(intruder_handshake_steps) /
              sizeof(intruder_handshake_steps[0])),
    (uint8_t)(sizeof(intruder_handshake_expected) /
              sizeof(intruder_handshake_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t intruder_busy[] = "BUSY";

static const DirectParityStep intruder_teardown_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { intruder_busy, DIRECT_PARITY_IN_SEND_FAIL, 2u,
      (uint8_t)(sizeof(intruder_busy) - 1u), 0u, 0u, 0u },
    { intruder_ping, DIRECT_PARITY_IN_RX, 2u,
      (uint8_t)(sizeof(intruder_ping) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation intruder_teardown_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 2u, 0u, 4u, 0u, "BUSY" },
    { DIRECT_PARITY_OBS_CLOSE, 2u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_intruder_teardown = {
    "intruder-send-fail-active-teardown",
    intruder_teardown_steps,
    intruder_teardown_expected,
    (uint8_t)(sizeof(intruder_teardown_steps) /
              sizeof(intruder_teardown_steps[0])),
    (uint8_t)(sizeof(intruder_teardown_expected) /
              sizeof(intruder_teardown_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep bye_local_handshake_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_BYE, 0u }
};

static const DirectParityObservation bye_local_handshake_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 3u, 0u, "BYE" },
    { DIRECT_PARITY_OBS_CLOSE, 1u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_bye_local_handshake = {
    "bye-local-handshake",
    bye_local_handshake_steps,
    bye_local_handshake_expected,
    (uint8_t)(sizeof(bye_local_handshake_steps) /
              sizeof(bye_local_handshake_steps[0])),
    (uint8_t)(sizeof(bye_local_handshake_expected) /
              sizeof(bye_local_handshake_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t bye_local_wire[] = "BYE";

static const DirectParityStep bye_local_send_fail_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { bye_local_wire, DIRECT_PARITY_IN_SEND_FAIL, 1u,
      (uint8_t)(sizeof(bye_local_wire) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_BYE, 0u }
};

static const DirectParityObservation bye_local_send_fail_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 3u, 0u, "BYE" },
    { DIRECT_PARITY_OBS_CLOSE, 1u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_bye_local_send_fail = {
    "bye-local-send-fail",
    bye_local_send_fail_steps,
    bye_local_send_fail_expected,
    (uint8_t)(sizeof(bye_local_send_fail_steps) /
              sizeof(bye_local_send_fail_steps[0])),
    (uint8_t)(sizeof(bye_local_send_fail_expected) /
              sizeof(bye_local_send_fail_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t bye_restore_rq[] = "RQ";

static const DirectParityStep bye_local_restore_prompt_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { bye_restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(bye_restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_BYE, 0u }
};

static const DirectParityObservation bye_local_restore_prompt_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 3u, 0u, "BYE" },
    { DIRECT_PARITY_OBS_CLOSE, 1u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_bye_local_restore_prompt = {
    "bye-local-restore-prompt",
    bye_local_restore_prompt_steps,
    bye_local_restore_prompt_expected,
    (uint8_t)(sizeof(bye_local_restore_prompt_steps) /
              sizeof(bye_local_restore_prompt_steps[0])),
    (uint8_t)(sizeof(bye_local_restore_prompt_expected) /
              sizeof(bye_local_restore_prompt_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t bye_remote[] = "BYE";

static const DirectParityStep bye_remote_active_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { bye_remote, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(bye_remote) - 1u), 0u, 0u, 0u }
};

static const DirectParityObservation bye_remote_active_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_CLOSE, 1u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_bye_remote_active = {
    "bye-remote-active",
    bye_remote_active_steps,
    bye_remote_active_expected,
    (uint8_t)(sizeof(bye_remote_active_steps) /
              sizeof(bye_remote_active_steps[0])),
    (uint8_t)(sizeof(bye_remote_active_expected) /
              sizeof(bye_remote_active_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep duplicate_hello_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

const DirectParityScenario direct_parity_duplicate_hello = {
    "host-duplicate-hello",
    duplicate_hello_steps,
    host_smoke_expected,
    (uint8_t)(sizeof(duplicate_hello_steps) /
              sizeof(duplicate_hello_steps[0])),
    (uint8_t)(sizeof(host_smoke_expected) / sizeof(host_smoke_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t start_host_request[] = "";
static const uint8_t start_host_ack[] = "ACK GAME START";

static const DirectParityStep start_host_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { start_host_request, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_START, 0u },
    { start_host_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(start_host_ack) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation start_host_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 21u, 0u,
      "GAME START WHITE=HOST" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_start_host = {
    "start-host",
    start_host_steps,
    start_host_expected,
    (uint8_t)(sizeof(start_host_steps) / sizeof(start_host_steps[0])),
    (uint8_t)(sizeof(start_host_expected) / sizeof(start_host_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t start_guest_payload[] = "GAME START WHITE=GUEST";

static const DirectParityStep start_guest_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { start_guest_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(start_guest_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation start_guest_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_WHITE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_start_guest = {
    "start-guest",
    start_guest_steps,
    start_guest_expected,
    (uint8_t)(sizeof(start_guest_steps) / sizeof(start_guest_steps[0])),
    (uint8_t)(sizeof(start_guest_expected) / sizeof(start_guest_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t local_move[] = "d2d4";
static const uint8_t local_move_ack[] = "ACK 1 d4";
static const uint8_t local_move_nack[] = "NACK 1 STALE";

static const DirectParityStep move_local_ack_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { start_host_request, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_START, 0u },
    { start_host_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(start_host_ack) - 1u), 0u, 0u, 0u },
    { local_move, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(local_move) - 1u), 0u,
      DIRECT_PARITY_REQUEST_MOVE, 0u },
    { local_move_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_move_ack) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation move_local_ack_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 21u, 0u,
      "GAME START WHITE=HOST" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 11u, 0u,
      "MOVE 1 d2d4" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_LOCAL_MOVE, 4u, 1u, "d2d4" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_MOVE, 2u, DIRECT_PARITY_RESULT_ACCEPTED, "d4" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_move_local_ack = {
    "move-local-ack",
    move_local_ack_steps,
    move_local_ack_expected,
    (uint8_t)(sizeof(move_local_ack_steps) /
              sizeof(move_local_ack_steps[0])),
    (uint8_t)(sizeof(move_local_ack_expected) /
              sizeof(move_local_ack_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t local_move_stale_nack[] = "NACK 2 STALE";
static const uint8_t local_move_stale_ack[] = "ACK 2 d4";

static const DirectParityStep move_local_stale_results_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { start_host_request, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_START, 0u },
    { start_host_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(start_host_ack) - 1u), 0u, 0u, 0u },
    { local_move, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(local_move) - 1u), 0u,
      DIRECT_PARITY_REQUEST_MOVE, 0u },
    { local_move_stale_nack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_move_stale_nack) - 1u), 0u, 0u, 0u },
    { local_move_stale_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_move_stale_ack) - 1u), 0u, 0u, 0u },
    { local_move_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_move_ack) - 1u), 0u, 0u, 0u },
    { local_move_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_move_ack) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

const DirectParityScenario direct_parity_move_local_stale_results = {
    "move-local-stale-results",
    move_local_stale_results_steps,
    move_local_ack_expected,
    (uint8_t)(sizeof(move_local_stale_results_steps) /
              sizeof(move_local_stale_results_steps[0])),
    (uint8_t)(sizeof(move_local_ack_expected) /
              sizeof(move_local_ack_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t remote_move[] = "MOVE 1 e2e4";
static const uint8_t remote_start[] = "GAME START WHITE=HOST";

static const DirectParityStep move_remote_duplicate_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { remote_move, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_move) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 1u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { remote_move, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_move) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation move_remote_duplicate_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_REMOTE_MOVE, 4u, 1u, "e2e4" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 1" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 1" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_move_remote_duplicate = {
    "move-remote-duplicate",
    move_remote_duplicate_steps,
    move_remote_duplicate_expected,
    (uint8_t)(sizeof(move_remote_duplicate_steps) /
              sizeof(move_remote_duplicate_steps[0])),
    (uint8_t)(sizeof(move_remote_duplicate_expected) /
              sizeof(move_remote_duplicate_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t out_of_order_move[] = "MOVE 3 e2e4";

static const DirectParityStep move_ply_sync_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { out_of_order_move, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(out_of_order_move) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation move_ply_sync_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 11u, 0u,
      "NACK 3 SYNC" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_move_ply_sync = {
    "move-ply-sync",
    move_ply_sync_steps,
    move_ply_sync_expected,
    (uint8_t)(sizeof(move_ply_sync_steps) /
              sizeof(move_ply_sync_steps[0])),
    (uint8_t)(sizeof(move_ply_sync_expected) /
              sizeof(move_ply_sync_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t local_takeback_ack[] = "ACK 1";
static const uint8_t local_takeback_stale_ack[] = "ACK 2";
static const uint8_t local_takeback_stale_nack[] = "NACK 2 BUSY";

static const DirectParityStep takeback_local_ack_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { start_host_request, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_START, 0u },
    { start_host_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(start_host_ack) - 1u), 0u, 0u, 0u },
    { local_move, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(local_move) - 1u), 0u,
      DIRECT_PARITY_REQUEST_MOVE, 0u },
    { local_move_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_move_ack) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 1u,
      DIRECT_PARITY_REQUEST_TAKEBACK, 0u },
    { local_takeback_stale_nack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_takeback_stale_nack) - 1u), 0u, 0u, 0u },
    { local_takeback_stale_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_takeback_stale_ack) - 1u), 0u, 0u, 0u },
    { local_takeback_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_takeback_ack) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 1u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { local_move, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(local_move) - 1u), 0u,
      DIRECT_PARITY_REQUEST_MOVE, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation takeback_local_ack_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 21u, 0u,
      "GAME START WHITE=HOST" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 11u, 0u,
      "MOVE 1 d2d4" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_LOCAL_MOVE, 4u, 1u, "d2d4" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_MOVE, 2u, DIRECT_PARITY_RESULT_ACCEPTED, "d4" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 10u, 0u, "TAKEBACK 1" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_TAKEBACK, 0u, 1u, "" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_TAKEBACK, 0u,
      DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 11u, 0u,
      "MOVE 1 d2d4" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_takeback_local_ack = {
    "takeback-local-ack",
    takeback_local_ack_steps,
    takeback_local_ack_expected,
    (uint8_t)(sizeof(takeback_local_ack_steps) /
              sizeof(takeback_local_ack_steps[0])),
    (uint8_t)(sizeof(takeback_local_ack_expected) /
              sizeof(takeback_local_ack_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t remote_takeback[] = "TAKEBACK 1";

static const DirectParityStep takeback_remote_accept_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { remote_move, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_move) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 1u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0xffu },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 1u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { remote_takeback, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_takeback) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0xffu },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 1u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { remote_takeback, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_takeback) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation takeback_remote_accept_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_REMOTE_MOVE, 4u, 1u, "e2e4" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 1" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_TAKEBACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_TAKEBACK, 0u, 1u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 1" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 1" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_takeback_remote_accept = {
    "takeback-remote-accept",
    takeback_remote_accept_steps,
    takeback_remote_accept_expected,
    (uint8_t)(sizeof(takeback_remote_accept_steps) /
              sizeof(takeback_remote_accept_steps[0])),
    (uint8_t)(sizeof(takeback_remote_accept_expected) /
              sizeof(takeback_remote_accept_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep takeback_reject_retry_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { remote_move, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_move) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 1u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { remote_takeback, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_takeback) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_REJECT, 0u },
    { remote_takeback, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_takeback) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 1u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation takeback_reject_retry_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_REMOTE_MOVE, 4u, 1u, "e2e4" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 1" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_TAKEBACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 6u, 0u, "NACK 1" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_TAKEBACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_TAKEBACK, 0u, 1u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 1" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_takeback_reject_retry = {
    "takeback-reject-retry",
    takeback_reject_retry_steps,
    takeback_reject_retry_expected,
    (uint8_t)(sizeof(takeback_reject_retry_steps) /
              sizeof(takeback_reject_retry_steps[0])),
    (uint8_t)(sizeof(takeback_reject_retry_expected) /
              sizeof(takeback_reject_retry_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t local_black_move[] = "e7e5";

static const DirectParityStep takeback_move_inflight_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { remote_move, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_move) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 1u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { local_black_move, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(local_black_move) - 1u), 0u,
      DIRECT_PARITY_REQUEST_MOVE, 0u },
    { remote_takeback, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_takeback) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation takeback_move_inflight_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_REMOTE_MOVE, 4u, 1u, "e2e4" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 1" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 11u, 0u,
      "MOVE 2 e7e5" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 6u, 0u, "NACK 1" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_takeback_move_inflight = {
    "takeback-move-inflight",
    takeback_move_inflight_steps,
    takeback_move_inflight_expected,
    (uint8_t)(sizeof(takeback_move_inflight_steps) /
              sizeof(takeback_move_inflight_steps[0])),
    (uint8_t)(sizeof(takeback_move_inflight_expected) /
              sizeof(takeback_move_inflight_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t remote_move_two[] = "MOVE 2 e7e5";
static const uint8_t remote_takeback_two[] = "TAKEBACK 2";
static const uint8_t takeback_reset[] = "RESET";

static const DirectParityStep takeback_latch_next_move_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { start_host_request, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_START, 0u },
    { start_host_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(start_host_ack) - 1u), 0u, 0u, 0u },
    { local_move, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(local_move) - 1u), 0u,
      DIRECT_PARITY_REQUEST_MOVE, 0u },
    { local_move_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_move_ack) - 1u), 0u, 0u, 0u },
    { remote_move_two, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_move_two) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 2u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { remote_takeback_two, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_takeback_two) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 2u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { remote_takeback, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_takeback) - 1u), 0u, 0u, 0u },
    { remote_takeback_two, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_takeback_two) - 1u), 0u, 0u, 0u },
    { remote_move_two, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_move_two) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 2u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { remote_takeback_two, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_takeback_two) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 2u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { takeback_reset, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(takeback_reset) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { remote_takeback_two, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_takeback_two) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation takeback_latch_next_move_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 21u, 0u,
      "GAME START WHITE=HOST" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 11u, 0u,
      "MOVE 1 d2d4" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_LOCAL_MOVE, 4u, 1u, "d2d4" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_MOVE, 2u, DIRECT_PARITY_RESULT_ACCEPTED, "d4" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_REMOTE_MOVE, 4u, 2u, "e7e5" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 2" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_TAKEBACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_TAKEBACK, 0u, 2u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 2" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 6u, 0u, "NACK 1" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 2" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_REMOTE_MOVE, 4u, 2u, "e7e5" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 2" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_TAKEBACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_TAKEBACK, 0u, 2u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "ACK 2" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESET, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 9u, 0u, "ACK RESET" },
    { DIRECT_PARITY_OBS_CONTROL, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESET, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 6u, 0u, "NACK 2" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_takeback_latch_next_move = {
    "takeback-latch-next-move",
    takeback_latch_next_move_steps,
    takeback_latch_next_move_expected,
    (uint8_t)(sizeof(takeback_latch_next_move_steps) /
              sizeof(takeback_latch_next_move_steps[0])),
    (uint8_t)(sizeof(takeback_latch_next_move_expected) /
              sizeof(takeback_latch_next_move_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t restore_rq[] = "RQ";
static const uint8_t restore_ry[] = "RY";
static const uint8_t restore_rn[] = "RN";
static const uint8_t restore_ra[] = "RA";
static const uint8_t restore_active_2[] =
    "uazam4iIiIgAAAAAAAAAAAAAAAAAAAAAEREREUI1YyR8_wIAAQEAAAAAOwF2";
static const uint8_t restore_rs00[] =
    "RS00 uazam4iIiIgAAAAAAAAAAAAAAAAAAA";
static const uint8_t restore_rs01_ready[] =
    "RS01 AAEREREUI1YyR8_wAAAAEAAAAAOwG1";
static const uint8_t restore_rs01_active[] =
    "RS01 AAEREREUI1YyR8_wIAAQEAAAAAOwF2";
static const uint8_t restore_rs00_over_alt[] =
    "RS00 qqzam4iIiIgAAAAAAAAAAAAAAAAAAA";
static const uint8_t restore_rs01_over_alt[] =
    "RS01 AAEREREUI1YyR8_wQAAwEAAAAAOwGX";
static const uint8_t restore_phase_ready[] = { DIRECT_PARITY_PHASE_READY };
static const uint8_t restore_phase_over[] = { DIRECT_PARITY_PHASE_OVER };
static const uint8_t restore_move[] = "d2d4";
static const uint8_t restore_move_ack[] = "ACK 3 d4";

static const DirectParityStep restore_local_active_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_active_2, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(restore_active_2) - 1u), 2u,
      DIRECT_PARITY_REQUEST_RESTORE, DIRECT_PARITY_PHASE_ACTIVE },
    { restore_ry, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_ry) - 1u), 0u, 0u, 0u },
    { restore_ra, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_ra) - 1u), 0u, 0u, 0u },
    { restore_move, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(restore_move) - 1u), 0u,
      DIRECT_PARITY_REQUEST_MOVE, 0u },
    { restore_move_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_move_ack) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation restore_local_active_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RQ" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 35u, 0u,
      "RS00 uazam4iIiIgAAAAAAAAAAAAAAAAAAA" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 35u, 0u,
      "RS01 AAEREREUI1YyR8_wIAAQEAAAAAOwF2" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_RESTORE, 1u, 2u, "A" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 11u, 0u, "MOVE 3 d2d4" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_LOCAL_MOVE, 4u, 3u, "d2d4" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_MOVE, 2u, DIRECT_PARITY_RESULT_ACCEPTED, "d4" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_restore_local_active = {
    "restore-local-active",
    restore_local_active_steps,
    restore_local_active_expected,
    (uint8_t)(sizeof(restore_local_active_steps) /
              sizeof(restore_local_active_steps[0])),
    (uint8_t)(sizeof(restore_local_active_expected) /
              sizeof(restore_local_active_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep restore_remote_fresh_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_rs00, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs00) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { restore_rs00, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs00) - 1u), 0u, 0u, 0u },
    { restore_rs01_ready, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs01_ready) - 1u), 0u, 0u, 0u },
    { restore_phase_ready, DIRECT_PARITY_IN_DOMAIN, 1u, 1u, 0u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { restore_rs01_ready, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs01_ready) - 1u), 0u, 0u, 0u },
    { restore_rs01_active, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs01_active) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { restore_rs01_over_alt, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs01_over_alt) - 1u), 0u, 0u, 0u },
    { restore_rs00_over_alt, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs00_over_alt) - 1u), 0u, 0u, 0u },
    { restore_phase_over, DIRECT_PARITY_IN_DOMAIN, 1u, 1u, 4u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation restore_remote_fresh_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RN" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RY" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RY" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_RESTORE, 1u, 0u, "R" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RA" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RA" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RN" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RY" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_RESTORE, 1u, 4u, "O" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RA" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_restore_remote_fresh = {
    "restore-remote-fresh",
    restore_remote_fresh_steps,
    restore_remote_fresh_expected,
    (uint8_t)(sizeof(restore_remote_fresh_steps) /
              sizeof(restore_remote_fresh_steps[0])),
    (uint8_t)(sizeof(restore_remote_fresh_expected) /
              sizeof(restore_remote_fresh_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep restore_cancel_early_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_active_2, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(restore_active_2) - 1u), 2u,
      DIRECT_PARITY_REQUEST_RESTORE, DIRECT_PARITY_PHASE_ACTIVE },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_RESTORE, 0u },
    { restore_ry, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_ry) - 1u), 0u, 0u, 0u },
    { restore_active_2, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(restore_active_2) - 1u), 2u,
      DIRECT_PARITY_REQUEST_RESTORE, DIRECT_PARITY_PHASE_ACTIVE },
    { restore_rn, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rn) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation restore_cancel_early_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RQ" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RN" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 2u, DIRECT_PARITY_RESULT_REJECTED, "RN" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RQ" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 2u, DIRECT_PARITY_RESULT_REJECTED, "RN" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_restore_cancel_early = {
    "restore-cancel-early",
    restore_cancel_early_steps,
    restore_cancel_early_expected,
    (uint8_t)(sizeof(restore_cancel_early_steps) /
              sizeof(restore_cancel_early_steps[0])),
    (uint8_t)(sizeof(restore_cancel_early_expected) /
              sizeof(restore_cancel_early_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep restore_cancel_late_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_active_2, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(restore_active_2) - 1u), 2u,
      DIRECT_PARITY_REQUEST_RESTORE, DIRECT_PARITY_PHASE_ACTIVE },
    { restore_ry, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_ry) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_RESTORE, 0u },
    { restore_ra, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_ra) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation restore_cancel_late_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RQ" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 35u, 0u,
      "RS00 uazam4iIiIgAAAAAAAAAAAAAAAAAAA" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 35u, 0u,
      "RS01 AAEREREUI1YyR8_wIAAQEAAAAAOwF2" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_RESTORE, 1u, 2u, "A" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_restore_cancel_late = {
    "restore-cancel-late",
    restore_cancel_late_steps,
    restore_cancel_late_expected,
    (uint8_t)(sizeof(restore_cancel_late_steps) /
              sizeof(restore_cancel_late_steps[0])),
    (uint8_t)(sizeof(restore_cancel_late_expected) /
              sizeof(restore_cancel_late_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep restore_remote_rn_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { restore_rn, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rn) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { restore_rn, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rn) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_REJECT, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation restore_remote_rn_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 2u, DIRECT_PARITY_RESULT_REJECTED, "RN" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RY" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 2u, DIRECT_PARITY_RESULT_REJECTED, "RN" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RN" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 2u, DIRECT_PARITY_RESULT_REJECTED, "RN" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_restore_remote_rn = {
    "restore-remote-rn",
    restore_remote_rn_steps,
    restore_remote_rn_expected,
    (uint8_t)(sizeof(restore_remote_rn_steps) /
              sizeof(restore_remote_rn_steps[0])),
    (uint8_t)(sizeof(restore_remote_rn_expected) /
              sizeof(restore_remote_rn_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t restore_rs00_invalid[] =
    "RS00 !azam4iIiIgAAAAAAAAAAAAAAAAAAA";

static const DirectParityStep restore_reject_retry_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { restore_rs00_invalid, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs00_invalid) - 1u), 0u, 0u, 0u },
    { restore_rs01_ready, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs01_ready) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 0u,
      DIRECT_PARITY_RESULT_REJECTED, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { restore_rs00, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs00) - 1u), 0u, 0u, 0u },
    { restore_rs01_ready, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs01_ready) - 1u), 0u, 0u, 0u },
    { restore_phase_ready, DIRECT_PARITY_IN_DOMAIN, 1u, 1u, 0u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation restore_reject_retry_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RY" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RN" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 2u, DIRECT_PARITY_RESULT_REJECTED, "RN" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RY" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_RESTORE, 1u, 0u, "R" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RA" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_restore_reject_retry = {
    "restore-reject-retry",
    restore_reject_retry_steps,
    restore_reject_retry_expected,
    (uint8_t)(sizeof(restore_reject_retry_steps) /
              sizeof(restore_reject_retry_steps[0])),
    (uint8_t)(sizeof(restore_reject_retry_expected) /
              sizeof(restore_reject_retry_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep restore_crossed_rq_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_active_2, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(restore_active_2) - 1u), 2u,
      DIRECT_PARITY_REQUEST_RESTORE, DIRECT_PARITY_PHASE_ACTIVE },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { restore_ry, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_ry) - 1u), 0u, 0u, 0u },
    { restore_ra, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_ra) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation restore_crossed_rq_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RQ" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RN" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 35u, 0u,
      "RS00 uazam4iIiIgAAAAAAAAAAAAAAAAAAA" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 35u, 0u,
      "RS01 AAEREREUI1YyR8_wIAAQEAAAAAOwF2" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_RESTORE, 1u, 2u, "A" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_restore_crossed_rq = {
    "restore-crossed-rq",
    restore_crossed_rq_steps,
    restore_crossed_rq_expected,
    (uint8_t)(sizeof(restore_crossed_rq_steps) /
              sizeof(restore_crossed_rq_steps[0])),
    (uint8_t)(sizeof(restore_crossed_rq_expected) /
              sizeof(restore_crossed_rq_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep restore_reack_send_fail_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { restore_rs00, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs00) - 1u), 0u, 0u, 0u },
    { restore_rs01_ready, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs01_ready) - 1u), 0u, 0u, 0u },
    { restore_phase_ready, DIRECT_PARITY_IN_DOMAIN, 1u, 1u, 0u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { restore_ra, DIRECT_PARITY_IN_SEND_FAIL, 1u,
      (uint8_t)(sizeof(restore_ra) - 1u), 0u, 0u, 0u },
    { restore_rs01_ready, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs01_ready) - 1u), 0u, 0u, 0u }
};

static const DirectParityObservation restore_reack_send_fail_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RY" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_RESTORE, 1u, 0u, "R" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RA" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RA" },
    { DIRECT_PARITY_OBS_CLOSE, 1u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_restore_reack_send_fail = {
    "restore-reack-send-fail",
    restore_reack_send_fail_steps,
    restore_reack_send_fail_expected,
    (uint8_t)(sizeof(restore_reack_send_fail_steps) /
              sizeof(restore_reack_send_fail_steps[0])),
    (uint8_t)(sizeof(restore_reack_send_fail_expected) /
              sizeof(restore_reack_send_fail_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep intruder_restore_receive_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { restore_rs00, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs00) - 1u), 0u, 0u, 0u },
    { intruder_ping, DIRECT_PARITY_IN_RX, 2u,
      (uint8_t)(sizeof(intruder_ping) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 2u, 0u, 0u, 0u, 0u },
    { restore_rs01_ready, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs01_ready) - 1u), 0u, 0u, 0u },
    { restore_phase_ready, DIRECT_PARITY_IN_DOMAIN, 1u, 1u, 0u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation intruder_restore_receive_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RY" },
    { DIRECT_PARITY_OBS_SEND, 2u, 0u, 4u, 0u, "BUSY" },
    { DIRECT_PARITY_OBS_CLOSE, 2u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_RESTORE, 1u, 0u, "R" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RA" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_intruder_restore_receive = {
    "intruder-during-restore-receive",
    intruder_restore_receive_steps,
    intruder_restore_receive_expected,
    (uint8_t)(sizeof(intruder_restore_receive_steps) /
              sizeof(intruder_restore_receive_steps[0])),
    (uint8_t)(sizeof(intruder_restore_receive_expected) /
              sizeof(intruder_restore_receive_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep restore_partial_reconnect_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { restore_rs00, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rs00) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_UP, 3u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 3u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_rs01_ready, DIRECT_PARITY_IN_RX, 3u,
      (uint8_t)(sizeof(restore_rs01_ready) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 3u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 3u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { restore_rs00, DIRECT_PARITY_IN_RX, 3u,
      (uint8_t)(sizeof(restore_rs00) - 1u), 0u, 0u, 0u },
    { restore_rs01_ready, DIRECT_PARITY_IN_RX, 3u,
      (uint8_t)(sizeof(restore_rs01_ready) - 1u), 0u, 0u, 0u },
    { restore_phase_ready, DIRECT_PARITY_IN_DOMAIN, 3u, 1u, 0u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 3u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation restore_partial_reconnect_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 2u, 0u, "RY" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 3u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 3u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 3u, 0u, 2u, 0u, "RN" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 3u, 0u, 2u, 0u, "RY" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_RESTORE, 1u, 0u, "R" },
    { DIRECT_PARITY_OBS_SEND, 3u, 0u, 2u, 0u, "RA" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_restore_partial_reconnect = {
    "restore-partial-linkdown-reconnect",
    restore_partial_reconnect_steps,
    restore_partial_reconnect_expected,
    (uint8_t)(sizeof(restore_partial_reconnect_steps) /
              sizeof(restore_partial_reconnect_steps[0])),
    (uint8_t)(sizeof(restore_partial_reconnect_expected) /
              sizeof(restore_partial_reconnect_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t draw_payload[] = "DRAW";
static const uint8_t reset_payload[] = "RESET";

static const DirectParityStep draw_rematch_guest_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { draw_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(draw_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { reset_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(reset_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation draw_rematch_guest_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_DRAW, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 8u, 0u, "ACK DRAW" },
    { DIRECT_PARITY_OBS_CONTROL, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_DRAW, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 9u, 0u, "ACK RESET" },
    { DIRECT_PARITY_OBS_CONTROL, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESET, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_draw_rematch_guest = {
    "draw-rematch-guest",
    draw_rematch_guest_steps,
    draw_rematch_guest_expected,
    (uint8_t)(sizeof(draw_rematch_guest_steps) /
              sizeof(draw_rematch_guest_steps[0])),
    (uint8_t)(sizeof(draw_rematch_guest_expected) /
              sizeof(draw_rematch_guest_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep reset_after_reset_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { reset_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(reset_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 0u },
    { reset_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(reset_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation reset_after_reset_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESET, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 9u, 0u, "ACK RESET" },
    { DIRECT_PARITY_OBS_CONTROL, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESET, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESET, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_reset_after_reset = {
    "reset-after-reset",
    reset_after_reset_steps,
    reset_after_reset_expected,
    (uint8_t)(sizeof(reset_after_reset_steps) /
              sizeof(reset_after_reset_steps[0])),
    (uint8_t)(sizeof(reset_after_reset_expected) /
              sizeof(reset_after_reset_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep reset_crossed_active_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_RESET, 0u },
    { reset_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(reset_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation reset_crossed_active_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "RESET" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 15u, 0u, "NACK RESET BUSY" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_reset_crossed_active = {
    "reset-crossed-active",
    reset_crossed_active_steps,
    reset_crossed_active_expected,
    (uint8_t)(sizeof(reset_crossed_active_steps) /
              sizeof(reset_crossed_active_steps[0])),
    (uint8_t)(sizeof(reset_crossed_active_expected) /
              sizeof(reset_crossed_active_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep move_pending_controls_busy_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { start_host_request, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_START, 0u },
    { start_host_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(start_host_ack) - 1u), 0u, 0u, 0u },
    { local_move, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(local_move) - 1u), 0u,
      DIRECT_PARITY_REQUEST_MOVE, 0u },
    { reset_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(reset_payload) - 1u), 0u, 0u, 0u },
    { draw_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(draw_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_RESET, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_DRAW, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_RESIGN, 0u },
    { local_move_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_move_ack) - 1u), 0u, 0u, 0u },
    { local_move_nack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_move_nack) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation move_pending_controls_busy_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 21u, 0u,
      "GAME START WHITE=HOST" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 11u, 0u, "MOVE 1 d2d4" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 15u, 0u, "NACK RESET BUSY" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 9u, 0u, "NACK DRAW" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 6u, 0u, "RESIGN" },
    { DIRECT_PARITY_OBS_CONTROL, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESIGN, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_move_pending_controls_busy = {
    "move-pending-resign-preempts",
    move_pending_controls_busy_steps,
    move_pending_controls_busy_expected,
    (uint8_t)(sizeof(move_pending_controls_busy_steps) /
              sizeof(move_pending_controls_busy_steps[0])),
    (uint8_t)(sizeof(move_pending_controls_busy_expected) /
              sizeof(move_pending_controls_busy_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep takeback_pending_controls_busy_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { start_host_request, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_START, 0u },
    { start_host_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(start_host_ack) - 1u), 0u, 0u, 0u },
    { local_move, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(local_move) - 1u), 0u,
      DIRECT_PARITY_REQUEST_MOVE, 0u },
    { local_move_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_move_ack) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 1u,
      DIRECT_PARITY_REQUEST_TAKEBACK, 0u },
    { reset_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(reset_payload) - 1u), 0u, 0u, 0u },
    { draw_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(draw_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_RESET, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_DRAW, 0u },
    { local_takeback_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(local_takeback_ack) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DOMAIN, 1u, 0u, 1u,
      DIRECT_PARITY_RESULT_ACCEPTED, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation takeback_pending_controls_busy_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 21u, 0u,
      "GAME START WHITE=HOST" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 11u, 0u, "MOVE 1 d2d4" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_LOCAL_MOVE, 4u, 1u, "d2d4" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_MOVE, 2u, DIRECT_PARITY_RESULT_ACCEPTED, "d4" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 10u, 0u, "TAKEBACK 1" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 15u, 0u, "NACK RESET BUSY" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 9u, 0u, "NACK DRAW" },
    { DIRECT_PARITY_OBS_GAME, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_GAME_TAKEBACK, 0u, 1u, "" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_TAKEBACK, 0u,
      DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_takeback_pending_controls_busy = {
    "takeback-pending-controls-busy",
    takeback_pending_controls_busy_steps,
    takeback_pending_controls_busy_expected,
    (uint8_t)(sizeof(takeback_pending_controls_busy_steps) /
              sizeof(takeback_pending_controls_busy_steps[0])),
    (uint8_t)(sizeof(takeback_pending_controls_busy_expected) /
              sizeof(takeback_pending_controls_busy_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t pending_draw_chat[] = "hello";

static const DirectParityStep draw_crossed_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_DRAW, 0u },
    { pending_draw_chat, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(pending_draw_chat) - 1u), 0u,
      DIRECT_PARITY_REQUEST_CHAT, 0u },
    { draw_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(draw_payload) - 1u), 0u, 0u, 0u },
    { draw_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(draw_payload) - 1u), 0u, 0u, 0u },
    { reset_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(reset_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation draw_crossed_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 4u, 0u, "DRAW" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 10u, 0u, "CHAT hello" },
    { DIRECT_PARITY_OBS_CHAT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_CHAT_LOCAL, 5u, 0u, "hello" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 8u, 0u, "ACK DRAW" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_DRAW, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "RESET" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 8u, 0u, "ACK DRAW" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 9u, 0u, "ACK RESET" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESET, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_draw_crossed = {
    "draw-crossed",
    draw_crossed_steps,
    draw_crossed_expected,
    (uint8_t)(sizeof(draw_crossed_steps) / sizeof(draw_crossed_steps[0])),
    (uint8_t)(sizeof(draw_crossed_expected) /
              sizeof(draw_crossed_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t resign_payload[] = "RESIGN";

static const DirectParityStep resign_remote_duplicate_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { resign_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(resign_payload) - 1u), 0u, 0u, 0u },
    { resign_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(resign_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation resign_remote_duplicate_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 10u, 0u, "ACK RESIGN" },
    { DIRECT_PARITY_OBS_CONTROL, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESIGN, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 10u, 0u, "ACK RESIGN" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_resign_remote_duplicate = {
    "resign-remote-duplicate",
    resign_remote_duplicate_steps,
    resign_remote_duplicate_expected,
    (uint8_t)(sizeof(resign_remote_duplicate_steps) /
              sizeof(resign_remote_duplicate_steps[0])),
    (uint8_t)(sizeof(resign_remote_duplicate_expected) /
              sizeof(resign_remote_duplicate_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep resign_crossed_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_RESIGN, 0u },
    { pending_draw_chat, DIRECT_PARITY_IN_LOCAL, 1u,
      (uint8_t)(sizeof(pending_draw_chat) - 1u), 0u,
      DIRECT_PARITY_REQUEST_CHAT, 0u },
    { resign_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(resign_payload) - 1u), 0u, 0u, 0u },
    { reset_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(reset_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation resign_crossed_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u,
      "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 6u, 0u, "RESIGN" },
    { DIRECT_PARITY_OBS_CONTROL, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESIGN, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 10u, 0u, "CHAT hello" },
    { DIRECT_PARITY_OBS_CHAT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_CHAT_LOCAL, 5u, 0u, "hello" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 10u, 0u, "ACK RESIGN" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESIGN, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 9u, 0u, "ACK RESET" },
    { DIRECT_PARITY_OBS_CONTROL, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESET, 0u, DIRECT_PARITY_RESULT_ACCEPTED, "" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_resign_crossed = {
    "resign-crossed",
    resign_crossed_steps,
    resign_crossed_expected,
    (uint8_t)(sizeof(resign_crossed_steps) / sizeof(resign_crossed_steps[0])),
    (uint8_t)(sizeof(resign_crossed_expected) /
              sizeof(resign_crossed_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t cancel_draw_payload[] = "CANCEL DRAW";
static const uint8_t nack_reset_payload[] = "NACK RESET";
static const uint8_t cancel_ack_ping[] = "ACK PING";

#define CANCEL_WAIT_KEEPALIVE \
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 400u, 0u, 0u }, \
    { cancel_ack_ping, DIRECT_PARITY_IN_RX, 1u, \
      (uint8_t)(sizeof(cancel_ack_ping) - 1u), 0u, 0u, 0u }
#define CANCEL_WAIT_KEEPALIVE_5 \
    CANCEL_WAIT_KEEPALIVE, \
    CANCEL_WAIT_KEEPALIVE, \
    CANCEL_WAIT_KEEPALIVE, \
    CANCEL_WAIT_KEEPALIVE, \
    CANCEL_WAIT_KEEPALIVE

static const DirectParityStep cancel_local_reset_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { start_host_request, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_START, 0u },
    { start_host_ack, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(start_host_ack) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LOCAL, 1u, 0u, 0u,
      DIRECT_PARITY_REQUEST_RESET, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 126u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 126u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 126u, 0u, 0u },
    { cancel_ack_ping, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(cancel_ack_ping) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 126u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 126u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 126u, 0u, 0u },
    { cancel_ack_ping, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(cancel_ack_ping) - 1u), 0u, 0u, 0u },
    CANCEL_WAIT_KEEPALIVE_5,
    CANCEL_WAIT_KEEPALIVE_5,
    CANCEL_WAIT_KEEPALIVE_5,
    CANCEL_WAIT_KEEPALIVE_5,
    CANCEL_WAIT_KEEPALIVE_5,
    CANCEL_WAIT_KEEPALIVE_5,
    CANCEL_WAIT_KEEPALIVE_5,
    CANCEL_WAIT_KEEPALIVE,
    CANCEL_WAIT_KEEPALIVE,
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 200u, 0u, 0u },
    { nack_reset_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(nack_reset_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation cancel_local_reset_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 21u, 0u,
      "GAME START WHITE=HOST" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "RESET" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "RESET" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "RESET" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "RESET" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "RESET" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 5u, 0u, "RESET" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 12u, 0u, "CANCEL RESET" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESET, 10u, DIRECT_PARITY_RESULT_CANCELLED,
      "NACK RESET" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_cancel_local_reset = {
    "cancel-local-reset-host",
    cancel_local_reset_steps,
    cancel_local_reset_expected,
    (uint8_t)(sizeof(cancel_local_reset_steps) /
              sizeof(cancel_local_reset_steps[0])),
    (uint8_t)(sizeof(cancel_local_reset_expected) /
              sizeof(cancel_local_reset_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep cancel_remote_draw_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { remote_start, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(remote_start) - 1u), 0u, 0u, 0u },
    { draw_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(draw_payload) - 1u), 0u, 0u, 0u },
    { cancel_draw_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(cancel_draw_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_DECISION, 1u, 0u, 0u,
      DIRECT_PARITY_DECISION_ACCEPT, 1u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation cancel_remote_draw_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u, "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 14u, 0u, "ACK GAME START" },
    { DIRECT_PARITY_OBS_STARTED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_DRAW, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 9u, 0u, "NACK DRAW" },
    { DIRECT_PARITY_OBS_CONTROL_RESULT, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_DRAW, 0u, DIRECT_PARITY_RESULT_EXPIRED, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_cancel_remote_draw = {
    "cancel-remote-draw-guest",
    cancel_remote_draw_steps,
    cancel_remote_draw_expected,
    (uint8_t)(sizeof(cancel_remote_draw_steps) /
              sizeof(cancel_remote_draw_steps[0])),
    (uint8_t)(sizeof(cancel_remote_draw_expected) /
              sizeof(cancel_remote_draw_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t ack_ping[] = "ACK PING";

static const DirectParityStep liveness_ack_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 150u, 0u, 0u },
    { ack_ping, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(ack_ping) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 150u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation liveness_ack_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 4u, 0u, "PING" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 4u, 0u, "PING" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

static const DirectParityObservation liveness_one_ping_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 4u, 0u, "PING" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_liveness_ack = {
    "liveness-ack",
    liveness_ack_steps,
    liveness_ack_expected,
    (uint8_t)(sizeof(liveness_ack_steps) / sizeof(liveness_ack_steps[0])),
    (uint8_t)(sizeof(liveness_ack_expected) /
              sizeof(liveness_ack_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep liveness_pending_window_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 300u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

const DirectParityScenario direct_parity_liveness_pending_window = {
    "liveness-pending-window",
    liveness_pending_window_steps,
    liveness_one_ping_expected,
    (uint8_t)(sizeof(liveness_pending_window_steps) /
              sizeof(liveness_pending_window_steps[0])),
    (uint8_t)(sizeof(liveness_one_ping_expected) /
              sizeof(liveness_one_ping_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep liveness_guest_loss_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 150u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 450u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 450u, 0u, 0u }
};

static const DirectParityObservation liveness_guest_loss_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 4u, 0u, "PING" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 4u, 0u, "PING" },
    { DIRECT_PARITY_OBS_CLOSE, 1u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_liveness_guest_loss = {
    "liveness-guest-loss",
    liveness_guest_loss_steps,
    liveness_guest_loss_expected,
    (uint8_t)(sizeof(liveness_guest_loss_steps) /
              sizeof(liveness_guest_loss_steps[0])),
    (uint8_t)(sizeof(liveness_guest_loss_expected) /
              sizeof(liveness_guest_loss_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep liveness_prompt_loss_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { restore_rq, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(restore_rq) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 150u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 450u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 450u, 0u, 0u }
};

static const DirectParityObservation liveness_prompt_loss_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_DECISION, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_REQUEST_RESTORE, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 4u, 0u, "PING" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 4u, 0u, "PING" },
    { DIRECT_PARITY_OBS_CLOSE, 1u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_liveness_prompt_loss = {
    "liveness-prompt-loss",
    liveness_prompt_loss_steps,
    liveness_prompt_loss_expected,
    (uint8_t)(sizeof(liveness_prompt_loss_steps) /
              sizeof(liveness_prompt_loss_steps[0])),
    (uint8_t)(sizeof(liveness_prompt_loss_expected) /
              sizeof(liveness_prompt_loss_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep liveness_host_loss_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { host_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(host_smoke_hello) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 450u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 450u, 0u, 0u }
};

static const DirectParityObservation liveness_host_loss_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 28u, 0u,
      "HELLO DIRECT HOST WHITE=HOST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_CLOSE, 1u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_liveness_host_loss = {
    "liveness-host-loss",
    liveness_host_loss_steps,
    liveness_host_loss_expected,
    (uint8_t)(sizeof(liveness_host_loss_steps) /
              sizeof(liveness_host_loss_steps[0])),
    (uint8_t)(sizeof(liveness_host_loss_expected) /
              sizeof(liveness_host_loss_expected[0])),
    DIRECT_PARITY_ROLE_HOST,
    DIRECT_PARITY_COLOR_WHITE
};

static const uint8_t ping_payload[] = "PING";
static const uint8_t ack_ping_payload[] = "ACK PING";

static const DirectParityStep ping_send_fail_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { ping_payload, DIRECT_PARITY_IN_SEND_FAIL, 1u,
      (uint8_t)(sizeof(ping_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TIMEOUT, 1u, 0u, 150u, 0u, 0u }
};

static const DirectParityObservation ping_send_fail_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 4u, 0u, "PING" },
    { DIRECT_PARITY_OBS_CLOSE, 1u, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_ping_send_fail = {
    "liveness-ping-send-fail",
    ping_send_fail_steps,
    ping_send_fail_expected,
    (uint8_t)(sizeof(ping_send_fail_steps) /
              sizeof(ping_send_fail_steps[0])),
    (uint8_t)(sizeof(ping_send_fail_expected) /
              sizeof(ping_send_fail_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep ack_ping_send_fail_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { ack_ping_payload, DIRECT_PARITY_IN_SEND_FAIL, 1u,
      (uint8_t)(sizeof(ack_ping_payload) - 1u), 0u, 0u, 0u },
    { ping_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(ping_payload) - 1u), 0u, 0u, 0u },
    { ping_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(ping_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

static const DirectParityObservation ack_ping_send_fail_expected[] = {
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_SIDE, DIRECT_PARITY_LINK_NONE,
      DIRECT_PARITY_COLOR_BLACK, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 18u, 0u,
      "HELLO DIRECT GUEST" },
    { DIRECT_PARITY_OBS_READY, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 8u, 0u, "ACK PING" },
    { DIRECT_PARITY_OBS_SEND, 1u, 0u, 8u, 0u, "ACK PING" },
    { DIRECT_PARITY_OBS_ENDED, DIRECT_PARITY_LINK_NONE, 0u, 0u, 0u, "" }
};

const DirectParityScenario direct_parity_ack_ping_send_fail = {
    "liveness-ack-ping-send-fail",
    ack_ping_send_fail_steps,
    ack_ping_send_fail_expected,
    (uint8_t)(sizeof(ack_ping_send_fail_steps) /
              sizeof(ack_ping_send_fail_steps[0])),
    (uint8_t)(sizeof(ack_ping_send_fail_expected) /
              sizeof(ack_ping_send_fail_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep ack_ping_send_timeout_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { ack_ping_payload, DIRECT_PARITY_IN_SEND_PENDING, 1u,
      (uint8_t)(sizeof(ack_ping_payload) - 1u), 0u, 0u, 0u },
    { ping_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(ping_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TX_GUARD_TIMEOUT, 1u, 0u, 0u, 0u, 0u },
    { ping_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(ping_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

const DirectParityScenario direct_parity_ack_ping_send_timeout = {
    "liveness-ack-ping-send-timeout",
    ack_ping_send_timeout_steps,
    ack_ping_send_fail_expected,
    (uint8_t)(sizeof(ack_ping_send_timeout_steps) /
              sizeof(ack_ping_send_timeout_steps[0])),
    (uint8_t)(sizeof(ack_ping_send_fail_expected) /
              sizeof(ack_ping_send_fail_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static const DirectParityStep ack_ping_stale_tx_result_steps[] = {
    { 0, DIRECT_PARITY_IN_LINK_UP, 1u, 0u, 0u, 0u, 0u },
    { guest_smoke_hello, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(guest_smoke_hello) - 1u), 0u, 0u, 0u },
    { ack_ping_payload, DIRECT_PARITY_IN_SEND_PENDING, 1u,
      (uint8_t)(sizeof(ack_ping_payload) - 1u), 0u, 0u, 0u },
    { ping_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(ping_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_TX_RESULT, 1u, 0u, 0u,
      DIRECT_PARITY_TX_OK, 0xffu },
    { 0, DIRECT_PARITY_IN_TX_RESULT, 1u, 0u, 0u,
      DIRECT_PARITY_TX_OK, 0u },
    { ping_payload, DIRECT_PARITY_IN_RX, 1u,
      (uint8_t)(sizeof(ping_payload) - 1u), 0u, 0u, 0u },
    { 0, DIRECT_PARITY_IN_LINK_DOWN, 1u, 0u, 0u, 0u, 0u }
};

const DirectParityScenario direct_parity_ack_ping_stale_tx_result = {
    "liveness-ack-ping-stale-tx-result",
    ack_ping_stale_tx_result_steps,
    ack_ping_send_fail_expected,
    (uint8_t)(sizeof(ack_ping_stale_tx_result_steps) /
              sizeof(ack_ping_stale_tx_result_steps[0])),
    (uint8_t)(sizeof(ack_ping_send_fail_expected) /
              sizeof(ack_ping_send_fail_expected[0])),
    DIRECT_PARITY_ROLE_GUEST,
    DIRECT_PARITY_COLOR_WHITE
};

static uint8_t parity_role(uint8_t role, uint8_t *out)
{
    if (role == DIRECT_PARITY_ROLE_HOST) {
        *out = SESSION_ROLE_HOST;
        return 1u;
    }
    if (role == DIRECT_PARITY_ROLE_GUEST) {
        *out = SESSION_ROLE_GUEST;
        return 1u;
    }
    return 0u;
}

static uint8_t parity_color(uint8_t color, uint8_t *out)
{
    if (color == DIRECT_PARITY_COLOR_WHITE) {
        *out = SESSION_COLOR_WHITE;
        return 1u;
    }
    if (color == DIRECT_PARITY_COLOR_BLACK) {
        *out = SESSION_COLOR_BLACK;
        return 1u;
    }
    if (color == DIRECT_PARITY_COLOR_UNKNOWN) {
        *out = SESSION_COLOR_UNKNOWN;
        return 1u;
    }
    return 0u;
}

static uint8_t trace_push(DirectParityTrace *trace,
                          uint8_t type,
                          uint8_t link_id,
                          uint8_t code,
                          uint16_t value,
                          const uint8_t *payload,
                          uint8_t length)
{
    DirectParityObservation *observation;

    if (trace->count >= DIRECT_PARITY_TRACE_CAPACITY ||
        length >= DIRECT_PARITY_PAYLOAD_CAPACITY) {
        return 0u;
    }
    observation = &trace->observations[trace->count++];
    observation->type = type;
    observation->link_id = link_id;
    observation->code = code;
    observation->length = length;
    observation->value = value;
    if (length != 0u) {
        memcpy(observation->payload, payload, length);
    }
    observation->payload[length] = '\0';
    return 1u;
}

static uint8_t collect_actions(DirectReferenceRunner *runner,
                               const SessionAction *actions,
                               uint8_t count,
                               DirectParityTrace *trace,
                               uint8_t *sent,
                               uint8_t *tx_id,
                               uint8_t *tx_result,
                               uint8_t *tx_pending)
{
    uint8_t i;

    *sent = 0u;
    *tx_result = SESSION_TX_OK;
    *tx_pending = 0u;
    for (i = 0u; i < count; ++i) {
        const SessionAction *action = &actions[i];

        if (action->type == SESSION_ACT_SEND) {
            if (*sent ||
                !trace_push(trace, DIRECT_PARITY_OBS_SEND,
                            action->data.send.link_id, 0u, 0u,
                            action->data.send.payload,
                            action->data.send.length)) {
                return 0u;
            }
            *sent = 1u;
            *tx_id = action->data.send.tx_id;
            if (runner->pending_send_length != 0u) {
                if (runner->pending_send_payload == 0 ||
                    runner->pending_send_length != action->data.send.length ||
                    memcmp(runner->pending_send_payload,
                           action->data.send.payload,
                           runner->pending_send_length) != 0) {
                    return 0u;
                }
                runner->pending_send_payload = 0;
                runner->pending_send_length = 0u;
                runner->pending_tx_id = action->data.send.tx_id;
                *tx_pending = 1u;
            } else if (runner->fail_length != 0u) {
                if (runner->fail_payload == 0 ||
                    runner->fail_length != action->data.send.length ||
                    memcmp(runner->fail_payload, action->data.send.payload,
                           runner->fail_length) != 0) {
                    return 0u;
                }
                runner->fail_payload = 0;
                runner->fail_length = 0u;
                *tx_result = SESSION_TX_FAILED;
            }
        } else if (action->type == SESSION_ACT_REQUEST_DECISION) {
            if (!trace_push(trace, DIRECT_PARITY_OBS_DECISION,
                            DIRECT_PARITY_LINK_NONE,
                            action->data.decision.control, 0u, 0, 0u)) {
                return 0u;
            }
        } else if (action->type == SESSION_ACT_SESSION_CHANGED) {
            uint8_t observation;

            if (action->data.session.status == SESSION_CHANGED_READY) {
                observation = DIRECT_PARITY_OBS_READY;
            } else if (action->data.session.status ==
                       SESSION_CHANGED_STARTED) {
                observation = DIRECT_PARITY_OBS_STARTED;
            } else if (action->data.session.status == SESSION_CHANGED_ENDED) {
                observation = DIRECT_PARITY_OBS_ENDED;
            } else {
                return 0u;
            }
            if (!trace_push(trace, observation, DIRECT_PARITY_LINK_NONE,
                            0u, 0u, 0, 0u)) {
                return 0u;
            }
        } else if (action->type == SESSION_ACT_SIDE_CHANGED) {
            if (!trace_push(trace, DIRECT_PARITY_OBS_SIDE,
                            DIRECT_PARITY_LINK_NONE,
                            action->data.side.color, 0u, 0, 0u)) {
                return 0u;
            }
        } else if (action->type == SESSION_ACT_DELIVER_GAME) {
            uint8_t observation;
            uint8_t code;
            uint16_t value;

            if (action->data.game.kind == SESSION_DELIVER_LOCAL_MOVE) {
                observation = DIRECT_PARITY_OBS_GAME;
                code = DIRECT_PARITY_GAME_LOCAL_MOVE;
                value = action->data.game.value;
            } else if (action->data.game.kind ==
                       SESSION_DELIVER_REMOTE_MOVE) {
                observation = DIRECT_PARITY_OBS_GAME;
                code = DIRECT_PARITY_GAME_REMOTE_MOVE;
                value = action->data.game.value;
            } else if (action->data.game.kind == SESSION_DELIVER_TAKEBACK) {
                observation = DIRECT_PARITY_OBS_GAME;
                code = DIRECT_PARITY_GAME_TAKEBACK;
                value = action->data.game.value;
            } else if (action->data.game.kind == SESSION_DELIVER_RESTORE) {
                const uint8_t *phase;

                if (action->data.game.delivery_id != 0u) {
                    runner->restore_delivery_id =
                        action->data.game.delivery_id;
                    continue;
                }
                phase = restore_phase_payload(runner->state.phase);
                if (phase == 0 ||
                    !trace_push(trace, DIRECT_PARITY_OBS_GAME,
                                DIRECT_PARITY_LINK_NONE,
                                DIRECT_PARITY_GAME_RESTORE,
                                runner->state.current_ply, phase, 1u)) {
                    return 0u;
                }
                continue;
            } else if (action->data.game.kind ==
                       SESSION_DELIVER_CONTROL_RESULT) {
                observation = DIRECT_PARITY_OBS_CONTROL_RESULT;
                code = (uint8_t)action->data.game.value;
                value = action->data.game.delivery_id;
            } else if (action->data.game.kind == SESSION_DELIVER_CONTROL) {
                observation = DIRECT_PARITY_OBS_CONTROL;
                code = (uint8_t)action->data.game.value;
                value = DIRECT_PARITY_RESULT_ACCEPTED;
            } else if (action->data.game.kind == SESSION_DELIVER_CHAT) {
                observation = DIRECT_PARITY_OBS_CHAT;
                code = (uint8_t)action->data.game.value;
                value = 0u;
            } else {
                return 0u;
            }
            if (!trace_push(trace, observation, DIRECT_PARITY_LINK_NONE,
                            code, value, action->data.game.payload,
                            action->data.game.length)) {
                return 0u;
            }
        } else if (action->type == SESSION_ACT_TIMER_SET) {
            uint8_t timer_id = action->data.timer_set.timer_id;

            if (timer_id >= SESSION_TIMER_COUNT ||
                action->data.timer_set.duration_ticks == 0u) {
                return 0u;
            }
            runner->timer_remaining[timer_id] =
                action->data.timer_set.duration_ticks;
            runner->timer_mask |= (uint8_t)(1u << timer_id);
        } else if (action->type == SESSION_ACT_TIMER_CANCEL) {
            uint8_t timer_id = action->data.timer_cancel.timer_id;

            if (timer_id >= SESSION_TIMER_COUNT) {
                return 0u;
            }
            runner->timer_mask &= (uint8_t)~(uint8_t)(1u << timer_id);
            runner->timer_remaining[timer_id] = 0u;
        } else if (action->type == SESSION_ACT_LINK_CLOSE) {
            if (!trace_push(trace, DIRECT_PARITY_OBS_CLOSE,
                            action->data.link_close.link_id,
                            0u, 0u, 0, 0u)) {
                return 0u;
            }
        } else {
            return 0u;
        }
    }
    return 1u;
}

static uint8_t run_event(DirectReferenceRunner *runner,
                         const SessionEvent *input,
                         DirectParityTrace *trace)
{
    SessionEvent completion;
    const SessionEvent *event = input;
    uint8_t transitions;

    for (transitions = 0u; transitions < 4u; ++transitions) {
        uint8_t accepted_restore = (uint8_t)(
            event->type == SESSION_EV_GAME_RESULT &&
            event->data.game.result == SESSION_GAME_ACCEPTED &&
            runner->restore_delivery_id != 0u &&
            event->data.game.delivery_id == runner->restore_delivery_id);
        uint8_t sent;
        uint8_t tx_id = 0u;
        uint8_t tx_result;
        uint8_t tx_pending;
        uint8_t count = session_step(&runner->state,
                                     event,
                                     &runner->workspace,
                                     runner->tx,
                                     sizeof(runner->tx),
                                     runner->actions,
                                     SESSION_ACTION_CAPACITY);

        if (accepted_restore) {
            const uint8_t *phase = restore_phase_payload(runner->state.phase);

            if (phase == 0 ||
                !trace_push(trace, DIRECT_PARITY_OBS_GAME,
                            DIRECT_PARITY_LINK_NONE,
                            DIRECT_PARITY_GAME_RESTORE,
                            runner->state.current_ply, phase, 1u)) {
                return 0u;
            }
            runner->restore_delivery_id = 0u;
        } else if (event->type == SESSION_EV_GAME_RESULT &&
                   event->data.game.delivery_id ==
                       runner->restore_delivery_id) {
            runner->restore_delivery_id = 0u;
        }

        if (!collect_actions(runner, runner->actions, count, trace,
                              &sent, &tx_id, &tx_result, &tx_pending)) {
            return 0u;
        }
        if (!sent || tx_pending) {
            return 1u;
        }

        memset(&completion, 0, sizeof(completion));
        completion.type = SESSION_EV_TX_RESULT;
        completion.data.tx.tx_id = tx_id;
        completion.data.tx.result = tx_result;
        event = &completion;
    }
    return 0u;
}

static uint8_t run_ticks(DirectReferenceRunner *runner,
                         uint16_t ticks,
                         DirectParityTrace *trace)
{
    while (ticks != 0u) {
        SessionEvent event;
        uint16_t next = 0xffffu;
        uint8_t timer_id;
        uint8_t active = 0u;

        for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
            if ((runner->timer_mask & (uint8_t)(1u << timer_id)) != 0u) {
                active = 1u;
                if (runner->timer_remaining[timer_id] < next) {
                    next = runner->timer_remaining[timer_id];
                }
            }
        }
        if (!active || next == 0u) {
            return 0u;
        }
        if (next > ticks) {
            for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
                if ((runner->timer_mask &
                     (uint8_t)(1u << timer_id)) != 0u) {
                    runner->timer_remaining[timer_id] = (uint16_t)(
                        runner->timer_remaining[timer_id] - ticks);
                }
            }
            return 1u;
        }

        for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
            if ((runner->timer_mask & (uint8_t)(1u << timer_id)) != 0u) {
                runner->timer_remaining[timer_id] = (uint16_t)(
                    runner->timer_remaining[timer_id] - next);
            }
        }
        ticks = (uint16_t)(ticks - next);

        for (timer_id = 0u; timer_id < SESSION_TIMER_COUNT; ++timer_id) {
            if ((runner->timer_mask & (uint8_t)(1u << timer_id)) == 0u ||
                runner->timer_remaining[timer_id] != 0u) {
                continue;
            }
            if (timer_id == SESSION_TIMER_TX_GUARD) {
                if (runner->pending_tx_id == 0u) {
                    return 0u;
                }
                runner->pending_tx_id = 0u;
            }
            runner->timer_mask &= (uint8_t)~(uint8_t)(1u << timer_id);
            memset(&event, 0, sizeof(event));
            event.type = SESSION_EV_TIMEOUT;
            event.data.timeout.timer_id = timer_id;
            if (!run_event(runner, &event, trace)) {
                return 0u;
            }
        }
    }
    return 1u;
}

uint8_t direct_reference_run(const DirectParityScenario *scenario,
                             DirectParityTrace *trace)
{
    DirectReferenceRunner runner;
    SessionConfig config;
    uint8_t i;

    if (scenario == 0 || trace == 0) {
        return 0u;
    }
    memset(&runner, 0, sizeof(runner));
    memset(trace, 0, sizeof(*trace));
    memset(&config, 0, sizeof(config));
    config.transport = SESSION_TRANSPORT_DIRECT;
    if (!parity_role(scenario->role, &config.role) ||
        !parity_color(scenario->host_color, &config.host_color) ||
        !session_init(&runner.state, &config)) {
        return 0u;
    }

    for (i = 0u; i < scenario->step_count; ++i) {
        const DirectParityStep *step = &scenario->steps[i];
        SessionEvent event;

        if (step->type == DIRECT_PARITY_IN_TIMEOUT) {
            if (step->value == 0u || !run_ticks(&runner, step->value, trace)) {
                return 0u;
            }
            continue;
        }
        if (step->type == DIRECT_PARITY_IN_TX_GUARD_TIMEOUT) {
            if (runner.pending_tx_id == 0u ||
                (runner.timer_mask &
                 (uint8_t)(1u << SESSION_TIMER_TX_GUARD)) == 0u) {
                return 0u;
            }
            runner.pending_tx_id = 0u;
            runner.timer_mask &=
                (uint8_t)~(uint8_t)(1u << SESSION_TIMER_TX_GUARD);
            runner.timer_remaining[SESSION_TIMER_TX_GUARD] = 0u;
            memset(&event, 0, sizeof(event));
            event.type = SESSION_EV_TIMEOUT;
            event.data.timeout.timer_id = SESSION_TIMER_TX_GUARD;
            if (!run_event(&runner, &event, trace)) {
                return 0u;
            }
            continue;
        }
        if (step->type == DIRECT_PARITY_IN_TX_RESULT) {
            uint8_t tx_id = step->phase == 0u
                ? runner.pending_tx_id
                : step->phase;

            if (tx_id == 0u ||
                (step->request != DIRECT_PARITY_TX_OK &&
                 step->request != DIRECT_PARITY_TX_FAILED)) {
                return 0u;
            }
            memset(&event, 0, sizeof(event));
            event.type = SESSION_EV_TX_RESULT;
            event.data.tx.tx_id = tx_id;
            event.data.tx.result = step->request;
            if (!run_event(&runner, &event, trace)) {
                return 0u;
            }
            if (tx_id == runner.pending_tx_id) {
                runner.pending_tx_id = 0u;
            }
            continue;
        }
        if (runner.pending_tx_id != 0u) {
            return 0u;
        }
        if (step->type == DIRECT_PARITY_IN_SEND_FAIL) {
            if (runner.fail_length != 0u || step->payload == 0 ||
                step->length == 0u) {
                return 0u;
            }
            runner.fail_payload = step->payload;
            runner.fail_length = step->length;
            continue;
        }
        if (step->type == DIRECT_PARITY_IN_SEND_PENDING) {
            if (runner.pending_send_length != 0u || step->payload == 0 ||
                step->length == 0u) {
                return 0u;
            }
            runner.pending_send_payload = step->payload;
            runner.pending_send_length = step->length;
            continue;
        }
        memset(&event, 0, sizeof(event));
        if (step->type == DIRECT_PARITY_IN_LINK_UP) {
            event.type = SESSION_EV_LINK_UP;
            event.data.link.link_id = step->link_id;
        } else if (step->type == DIRECT_PARITY_IN_LINK_DOWN) {
            event.type = SESSION_EV_LINK_DOWN;
            event.data.link.link_id = step->link_id;
        } else if (step->type == DIRECT_PARITY_IN_RX) {
            if (step->payload == 0 || step->length == 0u) {
                return 0u;
            }
            event.type = SESSION_EV_RX;
            event.data.rx.payload = step->payload;
            event.data.rx.length = step->length;
            event.data.rx.route = SESSION_ROUTE_DEFAULT;
            event.data.rx.flags = SESSION_RX_LIVE;
            event.data.rx.link_id = step->link_id;
        } else if (step->type == DIRECT_PARITY_IN_LOCAL) {
            event.type = SESSION_EV_LOCAL_REQUEST;
            event.data.local.request = step->request;
            event.data.local.value = step->value;
            event.data.local.payload = step->payload;
            event.data.local.length = step->length;
            event.data.local.phase = step->phase == 0u
                ? runner.state.phase
                : step->phase;
        } else if (step->type == DIRECT_PARITY_IN_DOMAIN) {
            event.type = SESSION_EV_GAME_RESULT;
            event.data.game.delivery_id = step->phase == 0u
                ? runner.state.pending_request_id
                : step->phase;
            event.data.game.result = step->request;
            event.data.game.value = step->value;
            event.data.game.detail = step->payload;
            event.data.game.detail_length = step->length;
        } else if (step->type == DIRECT_PARITY_IN_DECISION) {
            if ((step->phase == 0u &&
                 runner.state.pending_request_id == 0u) ||
                (step->request != DIRECT_PARITY_DECISION_ACCEPT &&
                 step->request != DIRECT_PARITY_DECISION_REJECT)) {
                return 0u;
            }
            event.type = SESSION_EV_USER_DECISION;
            event.data.user.request_id = step->phase == 0u
                ? runner.state.pending_request_id
                : step->phase;
            event.data.user.decision = step->request;
        } else {
            return 0u;
        }
        if (!run_event(&runner, &event, trace)) {
            return 0u;
        }
    }
    return (uint8_t)(runner.fail_length == 0u &&
                     runner.pending_send_length == 0u &&
                     runner.pending_tx_id == 0u);
}
