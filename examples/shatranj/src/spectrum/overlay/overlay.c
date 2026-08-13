#include "spectrum/overlay/overlay.h"
#include "spectrum/app/input_cmd.h"
#include "spectrum/session/event.h"
#include "spectrum/ui/gui.h"

netchesszx_session_event_t netchesszx_session_classify_game_payload(
    const char *payload)
{
    uint16_t payload_addr = (uint16_t)payload;

    spectrum_overlay_context[SPECTRUM_OVL_CTX_PTR_LO] = (uint8_t)payload_addr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_PTR_HI] =
        (uint8_t)(payload_addr >> 8);
    return (netchesszx_session_event_t)
        spectrum_overlay_exec_cached(SPECTRUM_OVL_CONTROL,
                                     SPECTRUM_OVL_CONTROL_CLASSIFY);
}

void spectrum_gui_status_phase(uint8_t phase) __z88dk_fastcall
{
    spectrum_overlay_context[SPECTRUM_OVL_CTX_STATUS_PHASE] = phase;
    (void)spectrum_overlay_exec_cached(SPECTRUM_OVL_STATUS,
                                       SPECTRUM_OVL_STATUS_PHASE);
}

void spectrum_gui_add_move(const char *ply, const char *move)
{
    uint16_t ply_addr = (uint16_t)ply;
    uint16_t move_addr = (uint16_t)move;

    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_MOVE_PLY_LO] =
        (uint8_t)ply_addr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_MOVE_PLY_HI] =
        (uint8_t)(ply_addr >> 8);
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_MOVE_TEXT_LO] =
        (uint8_t)move_addr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_MOVE_TEXT_HI] =
        (uint8_t)(move_addr >> 8);
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_RENDER] =
        spectrum_gui_side_panels_visible();
    (void)spectrum_overlay_exec_cached(SPECTRUM_OVL_GUI_LOG,
                                       SPECTRUM_OVL_GUI_LOG_ADD_MOVE);
}

void spectrum_gui_add_chat(char who, const char *text)
{
    uint16_t text_addr = (uint16_t)text;

    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_CHAT_WHO] = (uint8_t)who;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_CHAT_TEXT_LO] =
        (uint8_t)text_addr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_CHAT_TEXT_HI] =
        (uint8_t)(text_addr >> 8);
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_RENDER] =
        spectrum_gui_side_panels_visible();
    (void)spectrum_overlay_exec_cached(SPECTRUM_OVL_GUI_LOG,
                                       SPECTRUM_OVL_GUI_LOG_ADD_CHAT);
}

void spectrum_gui_remove_last_move(uint16_t ply)
{
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_MOVE_PLY_LO] = (uint8_t)ply;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_MOVE_PLY_HI] =
        (uint8_t)(ply >> 8);
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_RENDER] =
        spectrum_gui_side_panels_visible();
    (void)spectrum_overlay_exec_cached(SPECTRUM_OVL_GUI_LOG,
                                       SPECTRUM_OVL_GUI_LOG_REMOVE_LAST_MOVE);
}

void spectrum_gui_notify_msg(uint16_t packed) __z88dk_fastcall
{
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_MSG_ID] =
        SPECTRUM_GUI_MSG_ID(packed);
    spectrum_overlay_context[SPECTRUM_OVL_CTX_GUI_MSG_KIND] =
        SPECTRUM_GUI_MSG_KIND(packed);
    (void)spectrum_overlay_exec_cached(SPECTRUM_OVL_GUI_LOG,
                                       SPECTRUM_OVL_GUI_LOG_NOTIFY_MSG);
}

static void input_edit_exec(uint8_t entry)
{
    (void)spectrum_overlay_exec_cached(SPECTRUM_OVL_INPUT_EDIT, entry);
}

void netchesszx_input_edit_render_overlay(void)
{
    input_edit_exec(SPECTRUM_OVL_INPUT_EDIT_RENDER);
}

void netchesszx_input_edit_stop_clear_overlay(void)
{
    input_edit_exec(SPECTRUM_OVL_INPUT_EDIT_STOP_CLEAR);
}

void netchesszx_input_edit_begin_empty_overlay(void)
{
    input_edit_exec(SPECTRUM_OVL_INPUT_EDIT_BEGIN_EMPTY);
}

void netchesszx_input_edit_history_add_overlay(const char *text) __z88dk_fastcall
{
    uint16_t text_addr = (uint16_t)text;

    spectrum_overlay_context[SPECTRUM_OVL_CTX_PTR_LO] = (uint8_t)text_addr;
    spectrum_overlay_context[SPECTRUM_OVL_CTX_PTR_HI] =
        (uint8_t)(text_addr >> 8);
    input_edit_exec(SPECTRUM_OVL_INPUT_EDIT_HISTORY_ADD);
}

void netchesszx_input_edit_key_overlay(uint8_t key) __z88dk_fastcall
{
    spectrum_overlay_context[SPECTRUM_OVL_CTX_INPUT_KEY] = key;
    input_edit_exec(SPECTRUM_OVL_INPUT_EDIT_KEY);
}
