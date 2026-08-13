#include "common/protocol/game_protocol.h"

static uint8_t proto_init_out(char *out,
                              uint8_t cap,
                              char **p,
                              char **end)
{
    if (cap == 0u) {
        return 0u;
    }
    *p = out;
    *end = out + cap - 1u;
    out[0] = '\0';
    return 1u;
}

static uint8_t proto_append(char **p, const char *end, const char *text)
{
    while (*text != '\0') {
        if (*p >= end) {
            return 0u;
        }
        **p = *text;
        ++*p;
        ++text;
    }
    **p = '\0';
    return 1u;
}

uint8_t netchess_proto_format_move(char *out,
                                   uint8_t out_cap,
                                   const char *ply,
                                   const char *move,
                                   const char *notation)
{
    char *p;
    char *end;

    if (!proto_init_out(out, out_cap, &p, &end) ||
        !proto_append(&p, end, "MOVE ") ||
        !proto_append(&p, end, ply) ||
        !proto_append(&p, end, " ") ||
        !proto_append(&p, end, move)) {
        return 0u;
    }
    if (notation != 0 && notation[0] != '\0') {
        if (!proto_append(&p, end, " ") ||
            !proto_append(&p, end, notation)) {
            return 0u;
        }
    }
    return 1u;
}

uint8_t netchess_proto_format_chat(char *out,
                                   uint8_t out_cap,
                                   const char *text)
{
    char *p;
    char *end;

    return (uint8_t)(proto_init_out(out, out_cap, &p, &end) &&
                     proto_append(&p, end, "CHAT ") &&
                     proto_append(&p, end, text));
}

uint8_t netchess_proto_format_ack(char *out,
                                  uint8_t out_cap,
                                  const char *ply,
                                  const char *notation)
{
    char *p;
    char *end;

    if (!proto_init_out(out, out_cap, &p, &end) ||
        !proto_append(&p, end, NETCHESS_PROTO_ACK_PREFIX) ||
        !proto_append(&p, end, ply)) {
        return 0u;
    }
    if (notation != 0 && notation[0] != '\0') {
        if (!proto_append(&p, end, " ") ||
            !proto_append(&p, end, notation)) {
            return 0u;
        }
    }
    return 1u;
}

uint8_t netchess_proto_format_nack(char *out,
                                   uint8_t out_cap,
                                   const char *ply,
                                   const char *reason)
{
    char *p;
    char *end;

    if (!proto_init_out(out, out_cap, &p, &end) ||
        !proto_append(&p, end, NETCHESS_PROTO_NACK_PREFIX) ||
        !proto_append(&p, end, ply)) {
        return 0u;
    }
    if (reason != 0 && reason[0] != '\0') {
        if (!proto_append(&p, end, " ") ||
            !proto_append(&p, end, reason)) {
            return 0u;
        }
    }
    return 1u;
}

uint8_t netchess_proto_format_game_start(char *out,
                                         uint8_t out_cap,
                                         const char *detail)
{
    char *p;
    char *end;

    if (!proto_init_out(out, out_cap, &p, &end) ||
        !proto_append(&p, end, "GAME START")) {
        return 0u;
    }
    if (detail != 0 && detail[0] != '\0') {
        if (!proto_append(&p, end, " ") ||
            !proto_append(&p, end, detail)) {
            return 0u;
        }
    }
    return 1u;
}

uint8_t netchess_proto_format_reset(char *out, uint8_t out_cap)
{
    char *p;
    char *end;

    return (uint8_t)(proto_init_out(out, out_cap, &p, &end) &&
                     proto_append(&p, end, "RESET"));
}

uint8_t netchess_proto_format_bye(char *out, uint8_t out_cap)
{
    char *p;
    char *end;

    return (uint8_t)(proto_init_out(out, out_cap, &p, &end) &&
                     proto_append(&p, end, "BYE"));
}
