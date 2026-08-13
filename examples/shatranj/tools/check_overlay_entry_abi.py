#!/usr/bin/env python3
"""Check overlay entry tables, aliases, and dispatcher register ABI."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

from gen_overlay_atlas import ORDER


LABEL_RE = re.compile(r"^([A-Za-z0-9_.$]+):")
DEFC_RE = re.compile(
    r"^\s*DEFC\s+([A-Za-z0-9_.$]+)\s*=\s*([A-Za-z0-9_.$]+)\s*$"
)
DW_RE = re.compile(r"^\s+DW\s+([A-Za-z0-9_.$]+)\s*$")
DEFB_COUNT_RE = re.compile(r"^\s+DEFB\s+(\d+)\s*$")
DEFINE_RE = re.compile(r"^#define\s+(SPECTRUM_OVL_[A-Za-z0-9_]+)\s+(.+)$")
EQU_RE = re.compile(r"^(SPECTRUM_OVL_[A-Za-z0-9_]+)\s+EQU\s+(\d+)\s*$")
ASM_EQU_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s+EQU\s+(0x[0-9A-Fa-f]+|\d+)\s*$")
LOWRAM_DEFINE_RE = re.compile(
    r"^#define\s+(NETCHESSZX_LOWRAM_[A-Za-z0-9_]+_ADDR)\s+"
    r"(0x[0-9A-Fa-f]+|\d+)\s*$"
)

C_WRAPPERS = {
    "asm/overlay/board/entry_board.asm::_board_apply_ovl_entry":
        "_board_apply_trusted_ovl",
    "asm/overlay/board/entry_board.asm::_board_snapshot_restore_ovl_entry":
        "_board_snapshot_restore_ovl",
    "asm/overlay/board/entry_board.asm::_board_undo_restore_ovl_entry":
        "_board_undo_restore_ovl",
    "asm/overlay/control/entry_control.asm::_control_classify_ovl_entry":
        "_control_classify_ovl",
    "asm/overlay/direct/entry_direct.asm::_direct_read_payload_ovl_entry":
        "_direct_read_payload_ovl",
    "asm/overlay/direct/entry_direct.asm::_direct_send_text_ovl_entry":
        "_direct_send_text_ovl",
    "asm/overlay/fileui/entry_fileui.asm::_fileui_render_ovl_entry":
        "_fileui_render_ovl",
    "asm/overlay/fileui/entry_fileui.asm::_fileui_pick_ovl_entry":
        "_fileui_pick_ovl",
    "asm/overlay/gui_log/entry_gui_log.asm::_gui_log_add_move_ovl_entry":
        "_gui_log_add_move_ovl",
    "asm/overlay/gui_log/entry_gui_log.asm::_gui_log_add_chat_ovl_entry":
        "_gui_log_add_chat_ovl",
    "asm/overlay/gui_log/entry_gui_log.asm::_gui_log_notify_msg_ovl_entry":
        "_gui_log_notify_msg_ovl",
    "asm/overlay/gui_log/entry_gui_log.asm::_gui_log_remove_last_move_ovl_entry":
        "_gui_log_remove_last_move_ovl",
    "asm/overlay/input_edit/entry_input_edit.asm::_input_edit_render_ovl_entry":
        "_input_edit_render_ovl",
    "asm/overlay/input_edit/entry_input_edit.asm::_input_edit_begin_empty_ovl_entry":
        "_input_edit_begin_empty_ovl",
    "asm/overlay/input_edit/entry_input_edit.asm::_input_edit_stop_clear_ovl_entry":
        "_input_edit_stop_clear_ovl",
    "asm/overlay/input_edit/entry_input_edit.asm::_input_edit_key_ovl_entry":
        "_input_edit_key_ovl",
    "asm/overlay/input_edit/entry_input_edit.asm::_input_edit_history_add_ovl_entry":
        "_input_edit_history_add_ovl",
    "asm/overlay/menu_logic/entry_menu_logic.asm::_status_phase_ovl_entry":
        "_status_phase_ovl",
    "asm/overlay/mqtt_tx/entry_mqtt_tx.asm::_mqtt_tx_send_text_ovl_entry":
        "_mqtt_tx_send_text_ovl",
    "asm/overlay/mqtt_tx/entry_mqtt_tx.asm::_mqtt_tx_publish_setup_ovl_entry":
        "_mqtt_tx_publish_setup_ovl",
    "asm/overlay/restore/entry_restore.asm::_restore_build_frame_ovl_entry":
        "_restore_build_frame_ovl",
    "asm/overlay/restore/entry_restore.asm::_restore_decode_ovl_entry":
        "_restore_decode_ovl",
    "asm/overlay/saveload/entry_saveload.asm::_saveload_load_nczs_ovl_entry":
        "_saveload_load_nczs_ovl",
    "asm/overlay/saveload/entry_saveload.asm::_saveload_save_nczs_ovl_entry":
        "_saveload_save_nczs_ovl",
    "asm/overlay/saveload/entry_saveload.asm::_saveload_erase_nczs_ovl_entry":
        "_saveload_erase_nczs_ovl",
}

ASM_ENTRIES = {
    "asm/overlay/about/entry_about.asm::_about_render_ovl_entry",
    "asm/overlay/board/entry_board.asm::_board_snapshot_save_ovl_entry",
    "asm/overlay/input_edit/entry_input_edit.asm::input_edit_parse_move_ovl_entry",
    "asm/overlay/menu_config/entry_menu_config.asm::_menu_config_run_ovl_entry",
    "asm/overlay/menu_config/entry_menu_config.asm::_menu_config_paint_attrs_ovl_entry",
    "asm/overlay/menu_config/entry_menu_config.asm::_menu_config_edit_line_ovl_entry",
    "asm/overlay/menu_config/entry_menu_config.asm::_menu_config_validate_ip_ovl_entry",
    "asm/overlay/menu_config/entry_menu_config.asm::_menu_config_render_ovl_entry",
    "asm/overlay/setup/entry_setup.asm::_setup_compute_visible_ovl_entry",
    "asm/overlay/setup/entry_setup.asm::_setup_step_ovl_entry",
}

PRIVATE_ENTRY_MACROS = {
    "SPECTRUM_OVL_INPUT_EDIT_PARSE_MOVE_PRIVATE",
    "SPECTRUM_OVL_SETUP_COMPUTE_VISIBLE_PRIVATE",
}

ENTRY_TABLES = {
    "asm/overlay/about/entry_about.asm": [
        ("SPECTRUM_OVL_ABOUT_RENDER", "_about_render_ovl_entry"),
    ],
    "asm/overlay/board/entry_board.asm": [
        ("SPECTRUM_OVL_BOARD_APPLY", "_board_apply_ovl_entry"),
        ("SPECTRUM_OVL_BOARD_SNAPSHOT_SAVE", "_board_snapshot_save_ovl_entry"),
        ("SPECTRUM_OVL_BOARD_SNAPSHOT_RESTORE", "_board_snapshot_restore_ovl_entry"),
        ("SPECTRUM_OVL_BOARD_UNDO_RESTORE", "_board_undo_restore_ovl_entry"),
    ],
    "asm/overlay/control/entry_control.asm": [
        ("SPECTRUM_OVL_CONTROL_CLASSIFY", "_control_classify_ovl_entry"),
    ],
    "asm/overlay/direct/entry_direct.asm": [
        ("SPECTRUM_OVL_DIRECT_LISTEN", "_direct_listen_ovl"),
        ("SPECTRUM_OVL_DIRECT_CONNECT", "_direct_connect_ovl"),
        ("SPECTRUM_OVL_DIRECT_WAIT_CONNECT", "_direct_wait_pc_connect_ovl"),
        ("SPECTRUM_OVL_DIRECT_READ", "_direct_read_payload_ovl_entry"),
        ("SPECTRUM_OVL_DIRECT_SEND", "_direct_send_text_ovl_entry"),
    ],
    "asm/overlay/gui_log/entry_gui_log.asm": [
        ("SPECTRUM_OVL_GUI_LOG_ADD_MOVE", "_gui_log_add_move_ovl_entry"),
        ("SPECTRUM_OVL_GUI_LOG_ADD_CHAT", "_gui_log_add_chat_ovl_entry"),
        ("SPECTRUM_OVL_GUI_LOG_NOTIFY_MSG", "_gui_log_notify_msg_ovl_entry"),
        (
            "SPECTRUM_OVL_GUI_LOG_REMOVE_LAST_MOVE",
            "_gui_log_remove_last_move_ovl_entry",
        ),
    ],
    "asm/overlay/menu_config/entry_menu_config.asm": [
        ("SPECTRUM_OVL_MENU_CONFIG_RUN", "_menu_config_run_ovl_entry"),
        ("SPECTRUM_OVL_MENU_CONFIG_PAINT_ATTRS", "_menu_config_paint_attrs_ovl_entry"),
        ("SPECTRUM_OVL_MENU_CONFIG_VALIDATE_IP", "_menu_config_validate_ip_ovl_entry"),
        ("SPECTRUM_OVL_MENU_CONFIG_EDIT_LINE", "_menu_config_edit_line_ovl_entry"),
        ("SPECTRUM_OVL_MENU_CONFIG_RENDER", "_menu_config_render_ovl_entry"),
    ],
    "asm/overlay/menu_logic/entry_menu_logic.asm": [
        ("SPECTRUM_OVL_STATUS_PHASE", "_status_phase_ovl_entry"),
    ],
    "asm/overlay/mqtt_connect/entry_mqtt_connect.asm": [
        ("SPECTRUM_OVL_MQTT_CONNECT_START", "_mqtt_connect_start_ovl"),
        ("SPECTRUM_OVL_MQTT_CONNECT_ACTIVATE", "_mqtt_activate_side_ovl"),
        ("SPECTRUM_OVL_NET_PREFLIGHT", "_net_preflight_ovl"),
        ("SPECTRUM_OVL_MQTT_CONNECT_PROBE_SEAT", "_mqtt_probe_seat_ovl"),
    ],
    "asm/overlay/mqtt_tx/entry_mqtt_tx.asm": [
        ("SPECTRUM_OVL_MQTT_TX_SEND_TEXT", "_mqtt_tx_send_text_ovl_entry"),
        ("SPECTRUM_OVL_MQTT_TX_PUBLISH_SETUP", "_mqtt_tx_publish_setup_ovl_entry"),
        ("SPECTRUM_OVL_MQTT_TX_SYNC_TIME", "_mqtt_tx_sync_time_ovl"),
        ("SPECTRUM_OVL_MQTT_TX_PUBLISH_PRESENCE", "_mqtt_tx_publish_presence_ovl"),
    ],
    "asm/overlay/restore/entry_restore.asm": [
        ("SPECTRUM_OVL_RESTORE_BUILD_FRAME", "_restore_build_frame_ovl_entry"),
        ("SPECTRUM_OVL_RESTORE_DECODE", "_restore_decode_ovl_entry"),
    ],
    "asm/overlay/rules/entry_rules.asm": [
        ("SPECTRUM_OVL_RULES_PLAY", "_rules_play_ovl"),
        ("SPECTRUM_OVL_RULES_CHECK", "_rules_check_ovl"),
        ("SPECTRUM_OVL_HINTS_SHOW", "_rules_hints_ovl"),
        ("SPECTRUM_OVL_HINTS_CLEAR", "_rules_hints_clear_ovl"),
    ],
    "asm/overlay/fileui/entry_fileui.asm": [
        ("SPECTRUM_OVL_FILEUI_RENDER", "_fileui_render_ovl_entry"),
        ("SPECTRUM_OVL_FILEUI_PICK", "_fileui_pick_ovl_entry"),
    ],
    "asm/overlay/saveload/entry_saveload.asm": [
        ("SPECTRUM_OVL_SAVELOAD_LOAD_NCZS", "_saveload_load_nczs_ovl_entry"),
        ("SPECTRUM_OVL_SAVELOAD_SAVE_NCZS", "_saveload_save_nczs_ovl_entry"),
        ("SPECTRUM_OVL_SAVELOAD_ERASE_NCZS", "_saveload_erase_nczs_ovl_entry"),
    ],
    "asm/overlay/input_edit/entry_input_edit.asm": [
        ("SPECTRUM_OVL_INPUT_EDIT_RENDER", "_input_edit_render_ovl_entry"),
        ("SPECTRUM_OVL_INPUT_EDIT_BEGIN_EMPTY", "_input_edit_begin_empty_ovl_entry"),
        ("SPECTRUM_OVL_INPUT_EDIT_STOP_CLEAR", "_input_edit_stop_clear_ovl_entry"),
        ("SPECTRUM_OVL_INPUT_EDIT_KEY", "_input_edit_key_ovl_entry"),
        ("SPECTRUM_OVL_INPUT_EDIT_HISTORY_ADD", "_input_edit_history_add_ovl_entry"),
        (
            "SPECTRUM_OVL_INPUT_EDIT_PARSE_MOVE_PRIVATE",
            "input_edit_parse_move_ovl_entry",
        ),
    ],
    "asm/overlay/setup/entry_setup.asm": [
        ("SPECTRUM_OVL_SETUP_STEP", "_setup_step_ovl_entry"),
        (
            "SPECTRUM_OVL_SETUP_COMPUTE_VISIBLE_PRIVATE",
            "_setup_compute_visible_ovl_entry",
        ),
    ],
}


def check_wrappers(root: Path) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    for path in sorted((root / "asm" / "overlay").glob("*/entry_*.asm")):
        rel = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(lines):
            alias = DEFC_RE.match(line)
            if alias and alias.group(1).endswith("_ovl_entry"):
                symbol, callee = alias.groups()
                key = f"{rel}::{symbol}"
                seen.add(key)
                expected = C_WRAPPERS.get(key)
                if expected is None:
                    errors.append(f"{path}:{i + 1}: unclassified overlay entry {symbol}")
                elif callee != expected:
                    errors.append(
                        f"{path}:{i + 1}: {symbol} aliases {callee} != {expected}"
                    )
                continue
            match = LABEL_RE.match(line)
            if not match or not match.group(1).endswith("_ovl_entry"):
                continue
            symbol = match.group(1)
            key = f"{rel}::{symbol}"
            seen.add(key)
            if key not in ASM_ENTRIES:
                errors.append(f"{path}:{i + 1}: {symbol} must be a DEFC alias")
    for key in sorted((set(C_WRAPPERS) | ASM_ENTRIES) - seen):
        errors.append(f"missing classified overlay entry {key}")
    return errors


def check_dispatchers(root: Path) -> list[str]:
    errors: list[str] = []
    expected_decode = [
        "ld hl, 2",
        "add hl, sp",
        "ld a, (hl)",
        "inc hl",
        "ld b, (hl)",
    ]
    expected = [
        "pop de",
        "pop iy",
        "pop ix",
        "ld bc, ovl_return",
        "push bc",
        "push de",
        "ld de, _spectrum_overlay_context",
        "ld h, d",
        "ld l, e",
        "di",
        "ret",
    ]
    for rel in (
        "asm/esxdos/overlay_loader.asm",
        "asm/next/overlay_loader_next.asm",
    ):
        path = root / rel
        lines = path.read_text(encoding="utf-8").splitlines()
        if instructions_after_label(lines, "_spectrum_overlay_exec_cached") != expected_decode:
            errors.append(f"{path}: dispatcher must decode packed overlay arguments directly")
        canonical = instructions_after_label(lines, "ovl_args_canonical")
        if canonical[:3] != ["ld (ovl_id), a", "ld a, b", "ld (ovl_entry_id), a"]:
            errors.append(f"{path}: canonical overlay and entry ids must be stored together")
        try:
            start = lines.index("ovl_call_loaded:")
        except ValueError:
            errors.append(f"{path}: missing ovl_call_loaded")
            continue
        instructions: list[str] = []
        for raw_line in lines[start + 1:]:
            if LABEL_RE.match(raw_line):
                break
            instruction = raw_line.split(";", 1)[0].strip().lower()
            if instruction:
                instructions.append(re.sub(r"\s+", " ", instruction))
        if instructions[-len(expected):] != expected:
            errors.append(f"{path}: dispatcher must pass context in both DE and HL")
        if instructions[:2] != ["ld a, (ovl_entry_id)", "ld hl, _overlay_code_slot"]:
            errors.append(f"{path}: dispatcher must consume the canonical entry id directly")

        selector = instructions_after_label(lines, "ovl_select_atlas_entry")
        if selector[:4] != [
            "ld a, (ovl_id)",
            "cp ovl_atlas_count",
            "jr nc, ovl_select_bad",
            "add a, a",
        ]:
            errors.append(f"{path}: atlas selector must consume the canonical overlay id directly")
    return errors


def instructions_after_label(lines: list[str], label: str) -> list[str]:
    try:
        start = lines.index(f"{label}:")
    except ValueError:
        return []
    instructions: list[str] = []
    for raw_line in lines[start + 1:]:
        if LABEL_RE.match(raw_line):
            break
        instruction = raw_line.split(";", 1)[0].strip().lower()
        if instruction:
            instructions.append(re.sub(r"\s+", " ", instruction))
    return instructions


def check_rules_stack_contract(root: Path) -> list[str]:
    path = root / "asm" / "overlay" / "rules" / "rules_stub.asm"
    lines = path.read_text(encoding="utf-8").splitlines()
    errors: list[str] = []
    expected_prefix = ["push ix", "push iy", "call rules_import_board"]

    for entry in ("_rules_hints_ovl", "_rules_play_ovl", "_rules_check_ovl"):
        instructions = instructions_after_label(lines, entry)
        if instructions[:3] != expected_prefix:
            errors.append(f"{path}: {entry} must save IX/IY before importing board")

    helper = instructions_after_label(lines, "rules_import_board")
    if not helper or helper[-1] != "ret":
        errors.append(f"{path}: rules_import_board must return directly")
    if any(instruction.startswith(("push ", "pop ")) for instruction in helper):
        errors.append(f"{path}: rules_import_board must not change the caller stack")
    return errors


def check_setup_editability(root: Path) -> list[str]:
    path = root / "asm" / "overlay" / "setup" / "entry_setup.asm"
    lines = path.read_text(encoding="utf-8").splitlines()
    errors: list[str] = []
    endpoint = instructions_after_label(lines, "su_room_editable")
    if endpoint != [
        "ld a, (_setup_cursor)",
        "sub 2",
        "jr nz, su_re_port",
        "ld hl, (_setup_choice)",
        "ld a, h",
        "or l",
        "ret",
    ]:
        errors.append(f"{path}: HOST DIRECT IP must remain read-only")
    port = instructions_after_label(lines, "su_re_port")
    if port[:5] != [
        "dec a",
        "jr nz, su_re_false",
        "ld a, (_setup_choice + 1)",
        "or a",
        "jr z, su_re_true",
    ]:
        errors.append(f"{path}: DIRECT port must remain editable")
    auto_room = instructions_after_label(lines, "su_link_auto_room")
    if auto_room[-3:] != [
        "ld a, 2",
        "ld (su_clear_from), a",
        "jp su_define_row_and_finish",
    ]:
        errors.append(f"{path}: HOST DIRECT must advance past the read-only IP")
    focus = instructions_after_label(lines, "su_visible_a")
    if focus != [
        "ld e, a",
        "ld d, 0",
        "cp 2",
        "jr nz, su_va_mask",
        "ld hl, (_setup_choice)",
        "ld a, h",
        "or l",
        "ret z",
    ]:
        errors.append(f"{path}: HOST DIRECT navigation must skip the read-only IP")
    return errors


def parse_overlay_defines(path: Path) -> dict[str, int]:
    values: dict[str, int] = {}
    aliases: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        match = DEFINE_RE.match(raw_line.strip())
        if not match:
            continue
        name, raw_value = match.groups()
        value_text = raw_value.split("/*", 1)[0].strip().rstrip("uUlL")
        if value_text.isdigit():
            values[name] = int(value_text)
        else:
            aliases[name] = value_text
    changed = True
    while changed:
        changed = False
        for name, alias in list(aliases.items()):
            if alias in values:
                values[name] = values[alias]
                del aliases[name]
                changed = True
    return values


def parse_screen_equ(path: Path) -> dict[str, int]:
    values: dict[str, int] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        match = EQU_RE.match(raw_line.strip())
        if match:
            values[match.group(1)] = int(match.group(2))
    return values


def parse_int(value: str) -> int:
    return int(value, 16 if value.lower().startswith("0x") else 10)


def parse_lowram_defines(path: Path) -> dict[str, int]:
    values: dict[str, int] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        match = LOWRAM_DEFINE_RE.match(raw_line.strip())
        if match:
            values[match.group(1)] = parse_int(match.group(2))
    return values


def parse_asm_equ(path: Path) -> dict[str, int]:
    values: dict[str, int] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        match = ASM_EQU_RE.match(raw_line.strip())
        if match:
            values[match.group(1)] = parse_int(match.group(2))
    return values


def check_expected_addr(
    errors: list[str],
    rel: str,
    expected: int | None,
    actual_values: dict[str, int],
    actual_name: str,
) -> None:
    actual = actual_values.get(actual_name)
    if expected is None:
        errors.append(f"{rel}: missing low-RAM expected address for {actual_name}")
    elif actual is None:
        errors.append(f"{rel}: missing EQU {actual_name}")
    elif actual != expected:
        errors.append(
            f"{rel}: {actual_name} is 0x{actual:04X}, expected 0x{expected:04X}"
        )


def check_lowram_addresses(root: Path) -> list[str]:
    errors: list[str] = []
    lowram = parse_lowram_defines(root / "src" / "spectrum" / "lowram_map.h")
    screen = parse_asm_equ(root / "asm" / "spectrum" / "screen.asm")
    loader = parse_asm_equ(root / "asm" / "esxdos" / "overlay_loader.asm")
    context = lowram.get("NETCHESSZX_LOWRAM_OVERLAY_CONTEXT_ADDR")
    rules_board = lowram.get("NETCHESSZX_LOWRAM_RULES_BOARD_ADDR")

    check_expected_addr(
        errors,
        "asm/spectrum/screen.asm",
        rules_board,
        screen,
        "NETCHESSZX_RULES_BOARD_BASE",
    )
    check_expected_addr(
        errors,
        "asm/spectrum/screen.asm",
        context,
        screen,
        "NETCHESSZX_OVERLAY_CONTEXT",
    )
    check_expected_addr(
        errors,
        "asm/esxdos/overlay_loader.asm",
        context,
        loader,
        "_spectrum_overlay_context",
    )
    return errors


def parse_entry_table(path: Path) -> tuple[int, list[str]] | None:
    entries: list[str] = []
    count: int | None = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split(";", 1)[0]
        if count is None:
            count_match = DEFB_COUNT_RE.match(line)
            if count_match:
                count = int(count_match.group(1))
            continue
        match = DW_RE.match(line)
        if not match:
            if entries:
                break
            continue
        value = match.group(1)
        entries.append(value)
        if len(entries) == count:
            break
    if count is None:
        return None
    return count, entries


def check_entry_tables(root: Path) -> list[str]:
    errors: list[str] = []
    overlay_values = parse_overlay_defines(
        root / "src" / "spectrum" / "overlay" / "overlay.h"
    )
    screen_values = parse_screen_equ(root / "asm" / "spectrum" / "screen.asm")

    for index, name in enumerate(ORDER):
        macro = "SPECTRUM_OVL_STATUS" if name == "MENU_LOGIC" else f"SPECTRUM_OVL_{name}"
        if overlay_values.get(macro) != index:
            errors.append(
                f"tools/gen_overlay_atlas.py: {name} index {index} != {macro} {overlay_values.get(macro)!r}"
            )

    for rel, expected in ENTRY_TABLES.items():
        path = root / rel
        parsed = parse_entry_table(path)
        if parsed is None:
            errors.append(f"{path}: missing DEFB count + DW entry table")
            continue
        count, entries = parsed
        if count != len(expected):
            errors.append(f"{path}: DEFB count {count} != expected {len(expected)}")
        if entries != [symbol for _, symbol in expected]:
            errors.append(f"{path}: entry table order mismatch: {entries}")
        for index, (macro, _) in enumerate(expected):
            if macro in PRIVATE_ENTRY_MACROS:
                if macro in overlay_values:
                    errors.append(f"{path}: private entry {macro} leaked into overlay.h")
                if screen_values.get(macro) != index:
                    errors.append(
                        f"{path}: private {macro} in screen.asm is {screen_values.get(macro)!r}, expected {index}"
                    )
                continue
            if overlay_values.get(macro) != index:
                errors.append(
                    f"{path}: {macro} in overlay.h is {overlay_values.get(macro)!r}, expected {index}"
                )
            if macro in screen_values and screen_values[macro] != index:
                errors.append(
                    f"{path}: {macro} in screen.asm is {screen_values[macro]!r}, expected {index}"
                )
    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    args = parser.parse_args(argv)

    root = Path(args.root)
    errors: list[str] = []
    errors.extend(check_wrappers(root))
    errors.extend(check_dispatchers(root))
    errors.extend(check_rules_stack_contract(root))
    errors.extend(check_setup_editability(root))
    errors.extend(check_entry_tables(root))
    errors.extend(check_lowram_addresses(root))

    if errors:
        for error in errors:
            print(f"[ERR] {error}", file=sys.stderr)
        return 1
    print("[OK] overlay entry ABI")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
