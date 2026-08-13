#ifndef NETCHESSZX_SPECTRUM_PLATFORM_H
#define NETCHESSZX_SPECTRUM_PLATFORM_H

#include <stdint.h>
#include "spectrum/platform/uart.h"

void spectrum_frame_wait(void);
uint8_t spectrum_assets_load(void);
void spectrum_assets_fatal(void);

#endif
