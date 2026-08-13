#ifndef NETCHESSZX_SPECTRUM_SESSION_DIRECT_H
#define NETCHESSZX_SPECTRUM_SESSION_DIRECT_H

#include <stdint.h>

uint8_t netchesszx_session_direct_apply_start_side(const char *payload);
uint8_t netchesszx_session_direct_apply_hello(const char *payload);
uint8_t netchesszx_session_direct_send_hello(void);

#endif
