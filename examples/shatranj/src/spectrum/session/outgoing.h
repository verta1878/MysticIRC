#ifndef NETCHESSZX_SPECTRUM_SESSION_OUTGOING_H
#define NETCHESSZX_SPECTRUM_SESSION_OUTGOING_H

#include <stdint.h>

uint8_t netchesszx_session_send_ack_move(const char *ply);
uint8_t netchesszx_session_send_nack_move(const char *ply);
uint8_t netchesszx_session_send_ping(void);
uint8_t netchesszx_session_send_ack_ping(void);
uint8_t netchesszx_session_send_ack_reset(void);
uint8_t netchesszx_session_send_ack_resign(void);
uint8_t netchesszx_session_send_nack_reset(void);
uint8_t netchesszx_session_send_nack_reset_busy(void);
uint8_t netchesszx_session_send_ack_game_start(void);
uint8_t netchesszx_session_send_start_game(void);

#endif
