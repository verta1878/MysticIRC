#include "spectrum/session/outgoing.h"

#include "common/protocol/game_protocol.h"
#include "spectrum/config/session.h"
#include "spectrum/platform/text.h"
#include "spectrum/transport/link.h"

#ifndef NETCHESSZX_SDCC_IY
/* Host fallback for the Z80 implementations in shrink_kernels.asm. */
#define MOVE_PLY_TEXT_MAX 5u
#define MOVE_REPLY_CAP ((sizeof("NACK ") - 1u) + MOVE_PLY_TEXT_MAX + 1u)
typedef char move_reply_capacity_check[
    MOVE_REPLY_CAP == sizeof("NACK 65535") ? 1 : -1];

static uint8_t send_prefixed_text(const char *prefix, const char *text)
{
    char reply[MOVE_REPLY_CAP];

    (void)spectrum_append_text(spectrum_append_text(reply, prefix), text);
    return spectrum_link_send_text(reply);
}

uint8_t netchesszx_session_send_ack_move(const char *ply)
{
    return send_prefixed_text(NETCHESS_PROTO_ACK_PREFIX, ply);
}

uint8_t netchesszx_session_send_nack_move(const char *ply)
{
    return send_prefixed_text(NETCHESS_PROTO_NACK_PREFIX, ply);
}
#endif

uint8_t netchesszx_session_send_ping(void)
{
    return spectrum_link_send_ping();
}

uint8_t netchesszx_session_send_ack_ping(void)
{
    return spectrum_link_send_text(NETCHESS_PROTO_ACK_PING);
}

uint8_t netchesszx_session_send_ack_reset(void)
{
    return spectrum_link_send_text(NETCHESS_PROTO_ACK_RESET);
}

uint8_t netchesszx_session_send_ack_resign(void)
{
    return spectrum_link_send_text(NETCHESS_PROTO_ACK_RESIGN);
}

uint8_t netchesszx_session_send_nack_reset(void)
{
    return spectrum_link_send_text(NETCHESS_PROTO_NACK_RESET);
}

uint8_t netchesszx_session_send_nack_reset_busy(void)
{
    return spectrum_link_send_text("NACK RESET BUSY");
}

uint8_t netchesszx_session_send_ack_game_start(void)
{
    return spectrum_link_send_text("ACK GAME START");
}

uint8_t netchesszx_session_send_start_game(void)
{
    return spectrum_link_send_text(netchesszx_session_start_text());
}
