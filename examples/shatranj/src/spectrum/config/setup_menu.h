#ifndef NETCHESSZX_SPECTRUM_CONFIG_SETUP_MENU_H
#define NETCHESSZX_SPECTRUM_CONFIG_SETUP_MENU_H

#include <stdint.h>
#include "spectrum/lowram_map.h"

#define NETCHESSZX_SETUP_CTX_KEY 0u
#define NETCHESSZX_SETUP_CTX_FORCE_LO 1u
#define NETCHESSZX_SETUP_CTX_FORCE_HI 2u
#define NETCHESSZX_SETUP_CTX_CLEAR_FROM 3u
#define NETCHESSZX_SETUP_CTX_ACTION 4u
#define NETCHESSZX_SETUP_CTX_NOTICE 5u
#define NETCHESSZX_SETUP_CTX_FLAGS 6u

#define NETCHESSZX_SETUP_FLAG_RENDER 0x01u
#define NETCHESSZX_SETUP_FLAG_PAINT 0x02u
#define NETCHESSZX_SETUP_FLAG_EDIT 0x04u
#define NETCHESSZX_SETUP_FLAG_SUPPRESS 0x08u

#define NETCHESSZX_SETUP_ACTION_NONE 0u
#define NETCHESSZX_SETUP_ACTION_BOARD 1u
#define NETCHESSZX_SETUP_ACTION_SET 2u
#define NETCHESSZX_SETUP_ACTION_START 3u

#define NETCHESSZX_SETUP_NOTICE_NONE 0u
#define NETCHESSZX_SETUP_NOTICE_SELECT 1u
#define NETCHESSZX_SETUP_NOTICE_PENDING 2u
#define NETCHESSZX_SETUP_NOTICE_BAD_IP 3u

#define netchesszx_setup_overlay_context \
    ((volatile uint8_t *)NETCHESSZX_LOWRAM_OVERLAY_CONTEXT_ADDR)

void netchesszx_setup_render_edit_line(uint8_t row) __z88dk_fastcall;
uint16_t netchesszx_setup_compute_visible(uint16_t defined_mask) __z88dk_fastcall;
void netchesszx_setup_paint_attrs(void);
void netchesszx_setup_render_rows(uint8_t values,
                                  uint16_t visible_mask,
                                  uint16_t dirty_mask);
void netchesszx_setup_render_overlay(uint16_t force_dirty,
                                    uint16_t render_mode);
uint8_t netchesszx_setup_step_overlay(uint8_t key) __z88dk_fastcall;

#endif
