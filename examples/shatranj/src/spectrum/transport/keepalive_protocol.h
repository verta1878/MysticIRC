#ifndef NETCHESSZX_SPECTRUM_KEEPALIVE_PROTOCOL_H
#define NETCHESSZX_SPECTRUM_KEEPALIVE_PROTOCOL_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

uint8_t spectrum_keepalive_is_ping(const char *payload) NETCHESSZX_FASTCALL;
uint8_t spectrum_keepalive_is_ack_ping(const char *payload) NETCHESSZX_FASTCALL;

#endif
