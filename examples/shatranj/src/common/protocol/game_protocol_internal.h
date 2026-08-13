#ifndef NETCHESSZX_COMMON_GAME_PROTOCOL_INTERNAL_H
#define NETCHESSZX_COMMON_GAME_PROTOCOL_INTERNAL_H

#include <stdint.h>

uint8_t netchess_proto_copy_digits(const char **p, char *out, uint8_t cap);
void netchess_proto_copy_rest(const char *p, char *out, uint8_t cap);

#endif
