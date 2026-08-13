#ifndef NETCHESSZX_SAVEGAME_WIRE_H
#define NETCHESSZX_SAVEGAME_WIRE_H

#include <stddef.h>
#include <stdint.h>

#include "common/savegame/savegame_format.h"

int netchesszx_save_state_validate(const netchesszx_save_state_t *state);

int netchesszx_save_wire_pack(uint8_t *wire,
                              size_t cap,
                              const netchesszx_save_state_t *state);
int netchesszx_save_wire_unpack(netchesszx_save_state_t *state,
                                const uint8_t *wire,
                                size_t len);
int netchesszx_save_wire_b64_encode(char *out,
                                    size_t cap,
                                    const uint8_t *wire,
                                    size_t len);
int netchesszx_save_wire_b64_decode(uint8_t *wire,
                                    size_t cap,
                                    const char *text,
                                    size_t len);

#endif
