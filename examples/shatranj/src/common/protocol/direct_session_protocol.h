#ifndef NETCHESSZX_COMMON_DIRECT_SESSION_PROTOCOL_H
#define NETCHESSZX_COMMON_DIRECT_SESSION_PROTOCOL_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Direct (TCP) session grammar is role-based: HOST is the player that listens,
   GUEST is the opponent that connects. Device identity is not part of the wire
   protocol, so any client can host or join any other.
   The host owns the color assignment and declares who plays white by role. */

#define NETCHESS_DIRECT_WHITE_OWNER_HOST 0u
#define NETCHESS_DIRECT_WHITE_OWNER_GUEST 1u

/* True for any "HELLO DIRECT ..." line (host or guest variant). */
uint8_t netchess_direct_is_hello(const char *payload) NETCHESSZX_FASTCALL;
/* Exact "HELLO DIRECT GUEST". */
uint8_t netchess_direct_parse_guest_hello(const char *payload) NETCHESSZX_FASTCALL;
/* "HELLO DIRECT HOST WHITE=HOST|GUEST" -> 1, sets white_owner. */
uint8_t netchess_direct_parse_host_hello(const char *payload,
                                         uint8_t *white_owner);
/* "GAME START WHITE=HOST|GUEST" -> 1, sets white_owner. */
uint8_t netchess_direct_parse_start_white_owner(const char *payload,
                                                uint8_t *white_owner);
/* Local hello line to send. host_is_white is only used when is_host. */
const char *netchess_direct_hello(uint8_t is_host, uint8_t host_is_white);

#ifdef __cplusplus
}
#endif

#endif
