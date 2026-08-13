#ifndef NETCHESSZX_SPECTRUM_SAVELOAD_H
#define NETCHESSZX_SPECTRUM_SAVELOAD_H

#include <stdint.h>
#include "spectrum/overlay/overlay.h"

uint8_t spectrum_saveload_run(uint8_t entry, const char *name,
                              const char *buf);

#define spectrum_saveload_write(name, b64) \
    spectrum_saveload_run(SPECTRUM_OVL_SAVELOAD_SAVE_NCZS, (name), (b64))
#define spectrum_saveload_read(name, b64) \
    spectrum_saveload_run(SPECTRUM_OVL_SAVELOAD_LOAD_NCZS, (name), (b64))
#define spectrum_saveload_erase(name) \
    spectrum_saveload_run(SPECTRUM_OVL_SAVELOAD_ERASE_NCZS, (name), \
                          (const char *)0)

#endif
