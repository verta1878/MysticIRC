#include "spectrum/restore/restore.h"
#include "spectrum/overlay/overlay.h"

uint8_t spectrum_restore_build_b64(const spectrum_board_snapshot_t *snap,
                                   const netchesszx_save_meta_t *meta,
                                   char *b64)
{
    uint16_t snap_ptr = (uint16_t)snap;
    uint16_t meta_ptr = (uint16_t)meta;
    uint16_t text_ptr = (uint16_t)b64;

    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_SNAP_LO] = (uint8_t)snap_ptr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_SNAP_HI] = (uint8_t)(snap_ptr >> 8);
    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_META_LO] = (uint8_t)meta_ptr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_META_HI] = (uint8_t)(meta_ptr >> 8);
    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_TEXT_LO] = (uint8_t)text_ptr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_TEXT_HI] = (uint8_t)(text_ptr >> 8);
    return spectrum_overlay_exec_cached(SPECTRUM_OVL_RESTORE,
                                        SPECTRUM_OVL_RESTORE_BUILD_FRAME);
}

uint8_t spectrum_restore_decode(const char *b64,
                                spectrum_board_snapshot_t *snap,
                                netchesszx_save_meta_t *meta)
{
    uint16_t text_ptr = (uint16_t)b64;
    uint16_t snap_ptr = (uint16_t)snap;
    uint16_t meta_ptr = (uint16_t)meta;

    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_TEXT_LO] = (uint8_t)text_ptr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_TEXT_HI] = (uint8_t)(text_ptr >> 8);
    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_SNAP_LO] = (uint8_t)snap_ptr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_SNAP_HI] = (uint8_t)(snap_ptr >> 8);
    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_META_LO] = (uint8_t)meta_ptr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_RESTORE_META_HI] = (uint8_t)(meta_ptr >> 8);
    return spectrum_overlay_exec_cached(SPECTRUM_OVL_RESTORE,
                                        SPECTRUM_OVL_RESTORE_DECODE);
}
