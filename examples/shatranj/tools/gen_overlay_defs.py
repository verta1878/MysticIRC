#!/usr/bin/env python3
"""Generate resident symbol definitions for Shatranj overlays.

Overlays link against absolute resident symbols from the main .map. Any
resident helper used only from an overlay must be required/optional here or
matched by AUTO_RUNTIME_PREFIXES; otherwise the overlay build must fail.
"""

import re
import sys
from pathlib import Path


REQUIRED_SYMBOLS = [
    "_overlay_code_slot",
    "_spectrum_overlay_context",
    "_spectrum_overlay_loaded_id",
    "_spectrum_overlay_exec",
    "_spectrum_overlay_exec_cached",
    "_NETCHESS_PROTO_GAME_START",
    "ovl_close_overlay_file",
    "_spectrum_frame_wait",
    "_spectrum_gui_tick",
    "_spectrum_key_poll",
    "_spectrum_uart_flush",
    "_spectrum_uart_send_string",
    "_spectrum_uart_send_bytes",
    "_spectrum_uart_send_crlf",
    "_spectrum_uart_ready",
    "_spectrum_uart_read",
    "_spectrum_append_text",
    "_spectrum_append_u16",
    "_spectrum_gui_set_status",
    "_spectrum_gui_set_status_error",
    "_spectrum_gui_draw_status",
    "_spectrum_gui_set_connected",
    "_spectrum_gui_notify",
    "_spectrum_gui_notify_persistent",
    "_spectrum_gui_notify_success",
    "_spectrum_gui_add_move",
    "_spectrum_gui_add_chat",
    "_spectrum_gui_prepare_move",
    "_spectrum_gui_apply_move",
    "_spectrum_gui_set_input",
    "_spectrum_gui_set_input_edit",
    "_spectrum_gui_input_cell",
    "_spectrum_gui_redraw_board_squares",
    "_spectrum_gui_redraw_square",
    "_spectrum_board_view_redraw_square",
    "_spectrum_net_runtime_clock_ready",
    "_spectrum_net_runtime_set_clock",
    "_spectrum_net_runtime_set_fat_stamp",
    "_spectrum_net_runtime_fat_date",
    "_spectrum_net_runtime_fat_time",
    "_spectrum_net_last_ip",
    "_spectrum_net_start_uart",
    "_spectrum_render_board",
    "_spectrum_render_status",
    "_spectrum_render_status_error",
    "_spectrum_render_connection",
    "_spectrum_info_show_setup",
    "_spectrum_info_show_game_setup",
    "_spectrum_info_show_preflight",
    "_spectrum_info_line",
    "_spectrum_render_moves",
    "_spectrum_render_move_at",
    "_spectrum_render_moves_scroll",
    "_spectrum_render_chat",
    "_spectrum_render_chat_at",
    "_spectrum_render_chat_scroll",
    "_spectrum_render_square",
    "_spectrum_render_square_attr",
    "_spectrum_render_square_mark",
    "compute_square_bc",
    "compute_attr_base",
    "set_square_attr_2x2",
    "compute_screen_base",
    "board_row",
    "board_col",
    "tmp_attr",
    "board_theme_hint_inks",
    "_spectrum_gui_board_flipped",
    "_spectrum_board_view_flipped",
    "_netchesszx_board_theme_index",
    "_netchesszx_hinted_rows",
    "_spectrum_board_reset",
    "_spectrum_board_cells",
    "_spectrum_board_cell",
    "_spectrum_board_apply_trusted_move",
    "_side_to_move",
    "_castle_rights",
    "_ep_square",
    "_last_ply_seen",
    "_move_line_count",
    "_chat_line_count",
    "_setup_choice",
    "_setup_focus_choice",
    "_setup_focus_board_theme",
    "_setup_defined_mask",
    "_setup_visible_mask",
    "_setup_cursor",
    "_setup_room_editing",
    "_setup_edit_row",
    "_setup_port_text",
    "_netchesszx_session_peer_ready",
    "_spectrum_render_ikkle_at",
    "_spectrum_render_fileui_frame",
    "_spectrum_render_fileui_select",
    "_spectrum_fileui_count",
    "_spectrum_fileui_used_mask",
    "_local_input_len",
    "_local_input_cursor",
    "_local_input_mode",
    "_input_history_count",
    "_input_history_pos",
]

OPTIONAL_SYMBOLS = [
    "_netchess_after_prefix",
    "_netchess_mqtt_session_parse_u16_token",
    "_NETCHESS_PROTO_ACK_PREFIX",
    "_NETCHESS_PROTO_NACK_PREFIX",
    "_NETCHESS_PROTO_MOVE_PREFIX",
    "_NETCHESS_PROTO_CHAT_PREFIX",
    "_NETCHESS_PROTO_DRAW",
    "_NETCHESS_PROTO_CANCEL_DRAW",
    "_NETCHESS_PROTO_CANCEL_RESET",
    "_NETCHESS_PROTO_ACK_RESIGN",
    "_NETCHESS_PROTO_NACK_RESET",
    "_NETCHESS_PROTO_BYE",
    "_NETCHESS_PROTO_TAKEBACK_PREFIX",
    "_line_buf",
    "_last_ip",
    "_direct_rx_payload",
    "_direct_rx_payload2",
    "_direct_rx_link",
    "_direct_rx_link2",
    "_direct_rx_count",
    "_direct_rx_head",
    "_direct_rx_payload_len",
    "_direct_ipd_remaining",
    "_direct_ipd_accept",
    "_direct_ipd_link",
    "_direct_link_closed",
    "_direct_peer_valid",
    "_direct_intruder_link",
    "_active_link",
    "_line_pos",
    "_net_wait_frame",
    "_reset_line_buf",
    "_read_line",
    "_line_has",
    "_wait_for_ok",
    "_wait_for_prompt",
    "_mqtt_next_id",
    "_mqtt_stream_len",
    "_mqtt_packet",
    "_at_cmd",
    "_guard_wait",
    "_spectrum_net_at_cmd",
    "_spectrum_net_guard_wait",
    "_spectrum_net_ensure_command_mode",
    "_spectrum_net_query_ip_with_retry",
    "_spectrum_net_background_drain",
    "_spectrum_net_at_cipclose",
    "_spectrum_net_at_cipmode_0",
    "_spectrum_net_at_cipmux_0",
    "_spectrum_net_at_cipserver_0",
    "_mqtt_enter_stream_mode",
    "_mqtt_abort_stream_mode",
    "_mqtt_send_raw_packet",
    "_mqtt_send_packet",
    "_mqtt_wait_packet_into",
    "_mqtt_wait_packet",
    "_mqtt_wait_suback_into",
    "_mqtt_wait_suback",
    "_mqtt_subscribe_suffix",
    "_mqtt_publish_suffix",
    "_netchesszx_session_configure",
    "_netchesszx_session_role",
    "_netchesszx_transport",
    "_netchesszx_local_color",
    "_netchesszx_host_color",
    "_netchesszx_host_color_ready",
    "_netchesszx_text_game_start",
    "_netchesszx_mqtt_host",
    "_netchesszx_mqtt_code",
    "_netchesszx_mqtt_port",
    "_netchesszx_mqtt_session_id",
    "_netchesszx_direct_host",
    "_netchesszx_direct_port",
    "_spectrum_net_mqtt_out_suffix",
    "_spectrum_net_mqtt_out_ack_suffix",
    "_spectrum_net_mqtt_in_suffix",
    "_spectrum_net_mqtt_in_ack_suffix",
    "_spectrum_net_mqtt_peer_presence_suffix",
    "_spectrum_net_mqtt_presence_suffix",
    "_spectrum_net_mqtt_presence_payload",
    "_spectrum_net_mqtt_setup_payload",
    "_spectrum_net_sync_time",
    "_spectrum_mqtt_subscribe",
    "_spectrum_mqtt_publish",
    "_memcmp",
    "_memcpy",
    "_memset",
    "_strcmp",
    "_strcmp_callee",
    "_strlen",
    "_strlen_fastcall",
    "l_gchar1",
    "l_gchar2",
    "l_gchar3",
    "asm0_memcpy",
    "asm1_memcpy",
    "asm_memcpy",
    "asm_strcmp",
    "asm_strlen",
    "l_eq",
    "l_gchar",
    "l_gcharspsp",
    "l_ge",
    "l_gint",
    "l_gint1sp",
    "l_gint3sp",
    "l_gint4sp",
    "l_gint5sp",
    "l_gint6sp",
    "l_gint7sp",
    "l_gint8sp",
    "l_g2intspsp",
    "l_gintspsp",
    "l_asl",
    "l_asr_u_hl_by_e",
    "l_uge",
    "l_le",
    "l_lneg",
    "l_ne",
    "l_pint",
    "l_asr_u",
    "l_sxt",
    "l_gt",
]

AUTO_RUNTIME_PREFIXES = (
    "___sdcc",
    "____sdcc",
    "__mul",
    "__div",
    "__mod",
)


def parse_map(path):
    symbols = {}
    pattern = re.compile(r"^(\w+)\s+=\s+\$([0-9A-Fa-f]+)\s+;")
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = pattern.match(line)
            if match:
                symbols[match.group(1)] = int(match.group(2), 16)
    return symbols


def main(argv):
    if len(argv) != 2:
        print("Usage: gen_overlay_defs.py <map_file>", file=sys.stderr)
        return 2

    map_path = Path(argv[1])
    symbols = parse_map(map_path)
    missing = [name for name in REQUIRED_SYMBOLS if name not in symbols]

    print(";; AUTO-GENERATED by tools/gen_overlay_defs.py -- DO NOT EDIT")
    print(";; Resident symbols for Shatranj overlay linking")
    print()
    emitted = set()
    for name in REQUIRED_SYMBOLS:
        if name in symbols:
            print(f"PUBLIC {name}")
            print(f"DEFC {name} = ${symbols[name]:04X}")
            emitted.add(name)
        else:
            print(f";; MISSING {name}")
    for name in OPTIONAL_SYMBOLS:
        if name in symbols:
            print(f"PUBLIC {name}")
            print(f"DEFC {name} = ${symbols[name]:04X}")
            emitted.add(name)
    for name in sorted(symbols):
        if name in emitted:
            continue
        if name.startswith(AUTO_RUNTIME_PREFIXES):
            print(f"PUBLIC {name}")
            print(f"DEFC {name} = ${symbols[name]:04X}")
            emitted.add(name)

    if missing:
        print("Missing symbols: " + ", ".join(missing), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
