#include "spectrum/fileui/fileui.h"
#include "spectrum/lowram_map.h"
#include "spectrum/overlay/overlay_api.h"
#include "spectrum/overlay/overlay.h"
#include "spectrum/ui/render.h"

/* Grid geometry mirrors fileui_ovl.c. Navigation runs fully resident so a
   cursor move never reloads the FILEUI overlay from SD (network polling
   keeps swapping transport overlays into the slot). */
#define FILEUI_SLOTS 10u


#define FILEUI_KEY_UP 0x81u
#define FILEUI_KEY_DOWN 0x82u

static uint8_t fileui_sel;
/* Shared with the FILEUI overlay (written there during RENDER) and the
   screen.asm selection-attr helper. */
uint8_t spectrum_fileui_count;
uint16_t spectrum_fileui_used_mask;
/* Filled by the overlay while the local input editor is inactive. */
#define fileui_name ((char *)NETCHESSZX_LOWRAM_LOCAL_INPUT_ADDR)

static uint8_t fileui_exec(uint8_t entry, uint8_t mode)
{
    volatile uint8_t *ctx = spectrum_overlay_context;

    uint16_t name_ptr = (uint16_t)fileui_name;

    ctx[SPECTRUM_OVL_CTX_FILEUI_KEY] = mode;
    ctx[SPECTRUM_OVL_CTX_FILEUI_SEL] = fileui_sel;
    ctx[SPECTRUM_OVL_CTX_FILEUI_NAME_LO] = (uint8_t)name_ptr;
    ctx[SPECTRUM_OVL_CTX_FILEUI_NAME_HI] = (uint8_t)(name_ptr >> 8);
    if (!spectrum_overlay_exec_cached(SPECTRUM_OVL_FILEUI, entry)) {
        return SPECTRUM_FILEUI_ACT_FAIL;
    }
    return ctx[SPECTRUM_OVL_CTX_FILEUI_ACTION];
}

uint8_t spectrum_fileui_open_render(void)
{
    fileui_sel = 0u;
    return (uint8_t)(fileui_exec(SPECTRUM_OVL_FILEUI_RENDER, 0u) !=
                     SPECTRUM_FILEUI_ACT_FAIL);
}

uint8_t spectrum_fileui_rerender(void)
{
    /* List-only refresh: no frame wipe, rows self-clear in place. */
    return (uint8_t)(fileui_exec(SPECTRUM_OVL_FILEUI_RENDER, 1u) !=
                     SPECTRUM_FILEUI_ACT_FAIL);
}

uint8_t spectrum_fileui_send_key(uint8_t key)
{
    uint8_t sel = fileui_sel;
    uint8_t prev = sel;
    uint8_t saved;
    uint8_t picked;

    if ((key == FILEUI_KEY_UP || key == 'q') && sel != 0u) {
        --sel;
    } else if ((key == FILEUI_KEY_DOWN || key == 'a') &&
               sel != (uint8_t)(FILEUI_SLOTS - 1u)) {
        ++sel;
    } else if (key == 13u || key == ' ' || key == 'e' || key == 'E') {
        saved = (uint8_t)(sel < spectrum_fileui_count);
        if ((key == 'e' || key == 'E') && !saved) {
            return SPECTRUM_FILEUI_ACT_NONE;
        }
        picked = fileui_exec(SPECTRUM_OVL_FILEUI_PICK, 0u);
        if (picked == 1u) {
            return (key == 'e' || key == 'E') ? SPECTRUM_FILEUI_ACT_ERASE
                                              : SPECTRUM_FILEUI_ACT_LOAD;
        }
        if (picked == 2u) {
            return SPECTRUM_FILEUI_ACT_SAVE;
        }
        return SPECTRUM_FILEUI_ACT_NONE;
    } else {
        return SPECTRUM_FILEUI_ACT_NONE;
    }

    if (sel != prev) {
        fileui_sel = sel;
        /* Attr-only repaint (taboption-style inversion), fully
           resident: no overlay reload, no flicker. */
        spectrum_render_fileui_select(prev);
        spectrum_render_fileui_select((uint16_t)(1u << 8) | sel);
    }
    return SPECTRUM_FILEUI_ACT_NONE;
}

const char *spectrum_fileui_selected_name(void)
{
    return fileui_name;
}
