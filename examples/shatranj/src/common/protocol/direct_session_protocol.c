#include "common/protocol/direct_session_protocol.h"
#include "common/protocol/game_protocol.h"

static const char netchess_direct_hello_guest[] = "HELLO DIRECT GUEST";

#ifdef NETCHESSZX_SDCC_IY
uint8_t netchesszx_asm_direct_parse_role_owner(const char *owner,
                                               uint8_t *white_owner);
#define direct_parse_role_owner netchesszx_asm_direct_parse_role_owner
#else
static uint8_t direct_parse_role_owner(const char *owner, uint8_t *white_owner)
{
    if (owner[0] == 'H' && owner[1] == 'O' && owner[2] == 'S' &&
        owner[3] == 'T' && owner[4] == '\0') {
        *white_owner = NETCHESS_DIRECT_WHITE_OWNER_HOST;
        return 1u;
    }
    if (owner[0] == 'G' && owner[1] == 'U' && owner[2] == 'E' &&
        owner[3] == 'S' && owner[4] == 'T' && owner[5] == '\0') {
        *white_owner = NETCHESS_DIRECT_WHITE_OWNER_GUEST;
        return 1u;
    }
    return 0u;
}
#endif

uint8_t netchess_direct_is_hello(const char *payload) NETCHESSZX_FASTCALL
{
    return (uint8_t)(netchess_after_prefix(payload, "HELLO DIRECT ") != 0);
}

uint8_t netchess_direct_parse_guest_hello(const char *payload) NETCHESSZX_FASTCALL
{
    const char *p = netchess_after_prefix(payload, netchess_direct_hello_guest);

    return (uint8_t)(p != 0 && *p == '\0');
}

uint8_t netchess_direct_parse_host_hello(const char *payload,
                                         uint8_t *white_owner)
{
    const char *owner = netchess_after_prefix(payload,
                                            "HELLO DIRECT HOST WHITE=");

    if (owner == 0) {
        return 0u;
    }
    return direct_parse_role_owner(owner, white_owner);
}

uint8_t netchess_direct_parse_start_white_owner(const char *payload,
                                                uint8_t *white_owner)
{
    const char *owner = netchess_after_prefix(payload, "GAME START WHITE=");

    if (owner == 0) {
        return 0u;
    }
    return direct_parse_role_owner(owner, white_owner);
}

const char *netchess_direct_hello(uint8_t is_host, uint8_t host_is_white)
{
    if (!is_host) {
        return netchess_direct_hello_guest;
    }
    return host_is_white ? "HELLO DIRECT HOST WHITE=HOST"
                         : "HELLO DIRECT HOST WHITE=GUEST";
}
