#ifndef NETCHESSZX_SPECTRUM_RESTORE_H
#define NETCHESSZX_SPECTRUM_RESTORE_H

#include <stdint.h>

#include "spectrum/board/board.h"
#include "common/savegame/savegame_format.h"

uint8_t spectrum_restore_build_b64(const spectrum_board_snapshot_t *snap,
                                   const netchesszx_save_meta_t *meta,
                                   char *b64);
uint8_t spectrum_restore_decode(const char *b64,
                                spectrum_board_snapshot_t *snap,
                                netchesszx_save_meta_t *meta);

#endif
