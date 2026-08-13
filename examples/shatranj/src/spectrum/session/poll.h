#ifndef NETCHESSZX_SPECTRUM_SESSION_POLL_H
#define NETCHESSZX_SPECTRUM_SESSION_POLL_H

#include <stdint.h>

#include "spectrum/session/event.h"
#include "spectrum/session/ping.h"

#define NETCHESSZX_SESSION_POLL_NONE 0u
#define NETCHESSZX_SESSION_POLL_EVENT 1u
#define NETCHESSZX_SESSION_POLL_DISCONNECTED 2u

typedef struct netchesszx_session_poll_result {
    netchesszx_session_event_t event;
    uint8_t retained;
} netchesszx_session_poll_result_t;

uint8_t netchesszx_session_poll(netchesszx_session_ping_t *ping,
                                char *payload,
                                uint8_t payload_cap,
                                netchesszx_session_poll_result_t *out);

#endif
