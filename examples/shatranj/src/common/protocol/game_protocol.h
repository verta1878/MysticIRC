#ifndef NETCHESSZX_COMMON_GAME_PROTOCOL_H
#define NETCHESSZX_COMMON_GAME_PROTOCOL_H

#include <stdint.h>

#ifndef NETCHESSZX_FASTCALL
#ifdef NETCHESSZX_SDCC_IY
#define NETCHESSZX_FASTCALL __z88dk_fastcall
#else
#define NETCHESSZX_FASTCALL
#endif
#endif

#define NETCHESS_PROTO_MOVE "MOVE"
#define NETCHESS_PROTO_CHAT "CHAT"
#define NETCHESS_PROTO_ACK "ACK"
#define NETCHESS_PROTO_NACK "NACK"
#define NETCHESS_PROTO_TAKEBACK "TAKEBACK"
#define NETCHESS_PROTO_RESTORE_RQ "RQ"
#define NETCHESS_PROTO_RESTORE_RY "RY"
#define NETCHESS_PROTO_RESTORE_RN "RN"
#define NETCHESS_PROTO_RESTORE_RA "RA"
#define NETCHESS_PROTO_RESTORE_RS_PREFIX "RS"

#ifdef __cplusplus
extern "C" {
#endif

extern const char NETCHESS_PROTO_ACK_PREFIX[];
extern const char NETCHESS_PROTO_NACK_PREFIX[];
extern const char NETCHESS_PROTO_MOVE_PREFIX[];
extern const char NETCHESS_PROTO_CHAT_PREFIX[];
extern const char NETCHESS_PROTO_DRAW[];
extern const char NETCHESS_PROTO_CANCEL_DRAW[];
extern const char NETCHESS_PROTO_CANCEL_RESET[];
extern const char NETCHESS_PROTO_ACK_RESIGN[];
#define NETCHESS_PROTO_RESIGN (NETCHESS_PROTO_ACK_RESIGN + 4u)
extern const char NETCHESS_PROTO_GAME_START[];
extern const char NETCHESS_PROTO_NACK_RESET[];
#define NETCHESS_PROTO_ACK_RESET (NETCHESS_PROTO_NACK_RESET + 1u)
#define NETCHESS_PROTO_RESET (NETCHESS_PROTO_NACK_RESET + 5u)
extern const char NETCHESS_PROTO_BYE[];
extern const char NETCHESS_PROTO_TAKEBACK_PREFIX[];
extern const char NETCHESS_PROTO_ACK_PING[];
#define NETCHESS_PROTO_PING (NETCHESS_PROTO_ACK_PING + 4u)

const char *netchess_after_prefix(const char *text, const char *prefix);

uint8_t netchess_proto_parse_move(const char *rx,
                                  char *ply,
                                  uint8_t ply_cap,
                                  char *move,
                                  uint8_t move_cap,
                                  char *notation,
                                  uint8_t notation_cap);
uint8_t netchess_proto_parse_chat(const char *rx,
                                  char *text,
                                  uint8_t text_cap);
uint8_t netchess_proto_parse_ack(const char *rx,
                                 char *ply,
                                 uint8_t ply_cap,
                                 char *notation,
                                 uint8_t notation_cap);
uint8_t netchess_proto_parse_nack(const char *rx,
                                  char *ply,
                                  uint8_t ply_cap,
                                  char *reason,
                                  uint8_t reason_cap);
uint8_t netchess_proto_parse_game_start(const char *rx,
                                        char *detail,
                                        uint8_t detail_cap);
#ifndef NETCHESSZX_SDCC_IY
uint8_t netchess_proto_is_ack(const char *rx) NETCHESSZX_FASTCALL;
uint8_t netchess_proto_is_nack(const char *rx) NETCHESSZX_FASTCALL;
uint8_t netchess_proto_is_reset(const char *rx) NETCHESSZX_FASTCALL;
uint8_t netchess_proto_is_bye(const char *rx) NETCHESSZX_FASTCALL;
#endif

uint8_t netchess_proto_format_move(char *out,
                                   uint8_t out_cap,
                                   const char *ply,
                                   const char *move,
                                   const char *notation);
uint8_t netchess_proto_format_chat(char *out,
                                   uint8_t out_cap,
                                   const char *text);
uint8_t netchess_proto_format_ack(char *out,
                                  uint8_t out_cap,
                                  const char *ply,
                                  const char *notation);
uint8_t netchess_proto_format_nack(char *out,
                                   uint8_t out_cap,
                                   const char *ply,
                                   const char *reason);
uint8_t netchess_proto_format_game_start(char *out,
                                         uint8_t out_cap,
                                         const char *detail);
uint8_t netchess_proto_format_reset(char *out, uint8_t out_cap);
uint8_t netchess_proto_format_bye(char *out, uint8_t out_cap);

#ifdef __cplusplus
}
#endif

#endif
