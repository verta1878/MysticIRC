#include "spectrum/transport/keepalive_protocol.h"
#include "common/protocol/game_protocol.h"

uint8_t spectrum_keepalive_is_ping(const char *payload) NETCHESSZX_FASTCALL
{
    const char *p = netchess_after_prefix(payload, NETCHESS_PROTO_PING);
    return (uint8_t)(p != 0 && *p == '\0');
}

uint8_t spectrum_keepalive_is_ack_ping(const char *payload) NETCHESSZX_FASTCALL
{
    const char *p = netchess_after_prefix(payload, NETCHESS_PROTO_ACK_PING);
    return (uint8_t)(p != 0 && *p == '\0');
}
