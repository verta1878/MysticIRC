#include "spectrum/saveload/saveload.h"
#include "spectrum/overlay/overlay_api.h"

uint8_t spectrum_saveload_run(uint8_t entry, const char *name,
                              const char *buf)
{
    volatile uint8_t *ctx = spectrum_overlay_context;
    uint16_t name_ptr = (uint16_t)name;
    uint16_t buf_ptr = (uint16_t)buf;

    ctx[SPECTRUM_OVL_CTX_SAVELOAD_NAME_LO] = (uint8_t)name_ptr;
    ctx[SPECTRUM_OVL_CTX_SAVELOAD_NAME_HI] = (uint8_t)(name_ptr >> 8);
    ctx[SPECTRUM_OVL_CTX_SAVELOAD_BUF_LO] = (uint8_t)buf_ptr;
    ctx[SPECTRUM_OVL_CTX_SAVELOAD_BUF_HI] = (uint8_t)(buf_ptr >> 8);
    ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] = 0xffu;
    if (!spectrum_overlay_exec_cached(SPECTRUM_OVL_SAVELOAD, entry)) {
        return 0u;
    }
    return (uint8_t)(ctx[SPECTRUM_OVL_CTX_SAVELOAD_RESULT] == SPECTRUM_OVL_SAVELOAD_OK);
}
