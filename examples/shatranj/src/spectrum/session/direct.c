#include "spectrum/session/direct.h"

#include "common/protocol/direct_session_protocol.h"
#include "spectrum/config/session.h"
#include "spectrum/transport/link.h"

#if NETCHESS_DIRECT_WHITE_OWNER_HOST != NETCHESSZX_COLOR_WHITE || \
    NETCHESS_DIRECT_WHITE_OWNER_GUEST != NETCHESSZX_COLOR_BLACK
#error "direct white owner values must match Shatranj color values"
#endif

static uint8_t direct_apply_white_owner(uint8_t white_owner)
{
    if (white_owner > NETCHESS_DIRECT_WHITE_OWNER_GUEST) {
        return 0u;
    }
    netchesszx_host_color = white_owner;
    netchesszx_local_color = (uint8_t)(white_owner ^ 1u);
    netchesszx_host_color_ready = 1u;
    return 1u;
}

uint8_t netchesszx_session_direct_apply_start_side(const char *payload)
{
    uint8_t white_owner;

    if (netchesszx_transport_is_mqtt() || netchesszx_session_is_host()) {
        return 1u;
    }
    if (!netchess_direct_parse_start_white_owner(payload, &white_owner)) {
        return 0u;
    }
    return direct_apply_white_owner(white_owner);
}

uint8_t netchesszx_session_direct_apply_hello(const char *payload)
{
    uint8_t white_owner;

    if (netchesszx_transport_is_mqtt()) {
        return 1u;
    }
    if (netchesszx_session_is_host()) {
        return netchess_direct_parse_guest_hello(payload);
    }
    if (!netchess_direct_parse_host_hello(payload, &white_owner)) {
        return 0u;
    }
    if (netchesszx_host_color_ready &&
        netchesszx_host_color != white_owner) {
        return 0u;
    }
    return direct_apply_white_owner(white_owner);
}

uint8_t netchesszx_session_direct_send_hello(void)
{
    if (netchesszx_transport_is_mqtt()) {
        return 1u;
    }
    return spectrum_link_send_text(netchess_direct_hello(
                                   netchesszx_session_is_host(),
                                   netchesszx_local_is_white()));
}
