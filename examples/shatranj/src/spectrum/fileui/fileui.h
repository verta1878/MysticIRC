#ifndef NETCHESSZX_SPECTRUM_FILEUI_H
#define NETCHESSZX_SPECTRUM_FILEUI_H

#include <stdint.h>

/* Action codes mirror SPECTRUM_OVL_FILEUI_ACT_* in overlay_context.h; the
   app layer must not include overlay headers (app-no-overlay layering). */
#define SPECTRUM_FILEUI_ACT_NONE 0u
#define SPECTRUM_FILEUI_ACT_LOAD 1u
#define SPECTRUM_FILEUI_ACT_SAVE 2u
#define SPECTRUM_FILEUI_ACT_ERASE 3u
#define SPECTRUM_FILEUI_ACT_FAIL 0xffu

uint8_t spectrum_fileui_open_render(void);
uint8_t spectrum_fileui_rerender(void);
uint8_t spectrum_fileui_send_key(uint8_t key);
const char *spectrum_fileui_selected_name(void);

#endif
