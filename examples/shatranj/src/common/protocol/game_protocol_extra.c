#include "common/protocol/game_protocol.h"
#include "common/protocol/game_protocol_internal.h"

#include <string.h>

static uint8_t proto_parse_ply_tail_after_prefix(const char *p,
                                                 char *ply,
                                                 uint8_t ply_cap,
                                                 char *tail,
                                                 uint8_t tail_cap)
{
    uint8_t n = netchess_proto_copy_digits(&p, ply, ply_cap);

    if (n == 0u) {
        return 0u;
    }
    if (*p == '\0') {
        if (tail_cap != 0u) {
            tail[0] = '\0';
        }
        return 1u;
    }
    if (*p != ' ') {
        return 0u;
    }
    netchess_proto_copy_rest(p + 1u, tail, tail_cap);
    return 1u;
}

#ifndef NETCHESSZX_SDCC_IY
uint8_t netchess_proto_is_ack(const char *rx) NETCHESSZX_FASTCALL
{
    return (uint8_t)(netchess_after_prefix(rx, NETCHESS_PROTO_ACK_PREFIX) != 0);
}

uint8_t netchess_proto_is_nack(const char *rx) NETCHESSZX_FASTCALL
{
    return (uint8_t)(netchess_after_prefix(rx, NETCHESS_PROTO_NACK_PREFIX) != 0);
}
#endif

uint8_t netchess_proto_parse_ack(const char *rx,
                                 char *ply,
                                 uint8_t ply_cap,
                                 char *notation,
                                 uint8_t notation_cap)
{
    const char *p = netchess_after_prefix(rx, NETCHESS_PROTO_ACK_PREFIX);
    if (p == 0) {
        return 0u;
    }
    return proto_parse_ply_tail_after_prefix(p,
                                             ply,
                                             ply_cap,
                                             notation,
                                             notation_cap);
}

uint8_t netchess_proto_parse_nack(const char *rx,
                                  char *ply,
                                  uint8_t ply_cap,
                                  char *reason,
                                  uint8_t reason_cap)
{
    const char *p = netchess_after_prefix(rx, NETCHESS_PROTO_NACK_PREFIX);
    if (p == 0) {
        return 0u;
    }
    return proto_parse_ply_tail_after_prefix(p,
                                             ply,
                                             ply_cap,
                                             reason,
                                             reason_cap);
}

#ifndef NETCHESSZX_SDCC_IY
uint8_t netchess_proto_parse_game_start(const char *rx,
                                        char *detail,
                                        uint8_t detail_cap)
{
    if (netchess_after_prefix(rx, NETCHESS_PROTO_GAME_START) == 0) {
        return 0u;
    }
    if (rx[10u] == '\0') {
        if (detail_cap != 0u) {
            detail[0] = '\0';
        }
        return 1u;
    }
    if (rx[10u] != ' ') {
        return 0u;
    }
    netchess_proto_copy_rest(rx + 11u, detail, detail_cap);
    return 1u;
}
#endif

#ifndef NETCHESSZX_SDCC_IY
uint8_t netchess_proto_is_reset(const char *rx) NETCHESSZX_FASTCALL
{
    const char *p = netchess_after_prefix(rx, NETCHESS_PROTO_RESET);
    return (uint8_t)(p != 0 && *p == '\0');
}

uint8_t netchess_proto_is_bye(const char *rx) NETCHESSZX_FASTCALL
{
    const char *p = netchess_after_prefix(rx, NETCHESS_PROTO_BYE);
    return (uint8_t)(p != 0 && *p == '\0');
}
#endif
