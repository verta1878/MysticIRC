#!/usr/bin/env python3
"""Check source-level overlay resident-symbol capabilities."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_overlay_defs import OPTIONAL_SYMBOLS, REQUIRED_SYMBOLS  # noqa: E402


DEFAULT_POLICY = Path("docs/overlay_capabilities.json")

ASM_KNOWN = set(REQUIRED_SYMBOLS) | set(OPTIONAL_SYMBOLS)
C_KNOWN = {name[1:] if name.startswith("_") else name for name in ASM_KNOWN}

LOCAL_OVERLAY_NAMES = {
    "board_apply_ovl": "board",
    "control_ovl": "control",
    "direct_ovl": "direct",
    "fileui_ovl": "fileui",
    "gui_log_ovl": "gui_log",
    "input_edit_ovl": "input_edit",
    "menu_config_ovl": "menu_config",
    "menu_logic_ovl": "menu_logic",
    "mqtt_connect_ovl": "mqtt_connect",
    "mqtt_tx_ovl": "mqtt_tx",
    "restore_ovl": "restore",
    "saveload_ovl": "saveload",
    "setup_ovl": "setup",
    "status_ovl": "status",
}

ASM_EXTERN_RE = re.compile(r"^\s*EXTERN\s+([A-Za-z_][A-Za-z0-9_@.]*)")
ASM_DEFC_RE = re.compile(
    r"^\s*DEFC\s+(_spectrum_board_view_[A-Za-z0-9_]*)\s*=\s*([A-Za-z_][A-Za-z0-9_@.]*)"
)
C_TOKEN_RE = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")
C_BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
C_LINE_COMMENT_RE = re.compile(r"//.*?$", re.MULTILINE)
BANNED_SYMBOLS = {
    "spectrum_board_cells": "board snapshot pointer must not be imported by overlays",
    "_spectrum_board_cells": "board snapshot pointer must not be imported by overlays",
    "spectrum_board_apply_trusted_move": "overlay dispatcher must not be imported by overlays",
    "spectrum_gui_add_chat": "overlay dispatcher must not be imported by overlays",
    "spectrum_gui_add_move": "overlay dispatcher must not be imported by overlays",
}


def strip_c_comments(text: str) -> str:
    text = C_BLOCK_COMMENT_RE.sub("", text)
    return C_LINE_COMMENT_RE.sub("", text)


def canonical_symbol(symbol: str) -> str:
    return symbol[1:] if symbol.startswith("_") else symbol


def classify(symbol: str) -> str:
    name = canonical_symbol(symbol)
    raw = symbol

    if raw.startswith(("___sdcc", "____sdcc", "__mul", "__div", "__mod")):
        return "runtime"
    if name.startswith("l_") or name.startswith("asm_"):
        return "runtime"
    if name in {
        "memcmp",
        "memcpy",
        "memset",
        "strcmp",
        "strcmp_callee",
        "strlen",
        "strlen_fastcall",
    }:
        return "libc"
    if name.startswith("spectrum_uart_"):
        return "uart"
    if name.startswith("spectrum_net_") or name in {
        "last_ip",
        "net_wait_frame",
        "read_line",
        "reset_line_buf",
    }:
        return "net"
    if name.startswith("spectrum_mqtt_"):
        return "mqtt"
    if name.startswith("mqtt_"):
        return "mqtt"
    if name in {"spectrum_overlay_exec", "spectrum_overlay_exec_cached"}:
        return "overlay_exec"
    if name.startswith("spectrum_overlay_") or name == "overlay_code_slot":
        return "overlay"
    if name.startswith("spectrum_append_"):
        return "text"
    if name == "spectrum_frame_wait":
        return "time"
    if name.startswith("spectrum_render_") or name in {
        "compute_square_bc",
        "compute_attr_base",
        "compute_screen_base",
        "set_square_attr_2x2",
        "board_row",
        "board_col",
        "tmp_attr",
    }:
        return "render"
    if name.startswith("spectrum_info_") or name.startswith("spectrum_setup_"):
        return "gui"
    if name.startswith("spectrum_gui_"):
        return "gui"
    if name.startswith("spectrum_key_"):
        return "input"
    if name.startswith("spectrum_board_view_"):
        return "board_view"
    if name.startswith("spectrum_board_") or name in {
        "side_to_move",
        "castle_rights",
        "ep_square",
        "netchesszx_hinted_rows",
    }:
        return "board"
    if name.startswith("direct_") or name in {
        "line_buf",
        "active_link",
        "line_pos",
    }:
        return "direct_state"
    if name in {
        "last_ply_seen",
        "move_line_count",
        "chat_line_count",
        "setup_choice",
        "setup_focus_choice",
        "setup_focus_board_theme",
        "setup_defined_mask",
        "setup_visible_mask",
        "setup_cursor",
        "setup_room_editing",
        "setup_edit_row",
        "setup_port_text",
    }:
        return "gui_state"
    if name.startswith("netchesszx_session_"):
        return "session"
    if name.startswith("netchesszx_"):
        return "config"
    return "resident"


def overlay_for_path(path: Path) -> str | None:
    rel = path.as_posix()
    if rel.startswith("src/spectrum/overlay/") and path.suffix == ".c":
        return LOCAL_OVERLAY_NAMES.get(path.stem)
    parts = path.parts
    if len(parts) >= 3 and parts[0] == "asm" and parts[1] == "overlay":
        group = parts[2]
        if group in {
            "board",
            "about",
            "control",
            "direct",
            "fileui",
            "gui_log",
            "hints",
            "input_edit",
            "menu_config",
            "menu_logic",
            "mqtt_connect",
            "mqtt_tx",
            "setup",
            "status",
            "rules",
            "restore",
            "saveload",
        }:
            return group
    return None


def iter_sources(root: Path) -> list[Path]:
    paths: list[Path] = []
    for base in (root / "src" / "spectrum" / "overlay", root / "asm" / "overlay"):
        if not base.exists():
            continue
        paths.extend(
            path
            for path in base.rglob("*")
            if path.suffix in {".c", ".asm"} and path.name not in {"overlay.c"}
        )
    return sorted(paths)


def scan_symbols(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    if path.suffix == ".asm":
        symbols = set()
        for raw_line in text.splitlines():
            line = raw_line.split(";", 1)[0]
            match = ASM_EXTERN_RE.match(line)
            if match and match.group(1) in ASM_KNOWN:
                symbols.add(match.group(1))
        return symbols

    text = strip_c_comments(text)
    return {token for token in C_TOKEN_RE.findall(text) if token in C_KNOWN}


def load_policy(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def scan_board_view_aliases(root: Path) -> dict[str, str]:
    aliases: dict[str, str] = {}
    path = root / "asm" / "spectrum" / "screen.asm"
    if not path.exists():
        return aliases
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.split(";", 1)[0]
        match = ASM_DEFC_RE.match(line)
        if match:
            aliases[match.group(1)] = match.group(2)
    return aliases


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--policy", type=Path, default=DEFAULT_POLICY)
    parser.add_argument("--report", action="store_true")
    parser.add_argument("--fail-debt", action="store_true")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    policy = load_policy(args.policy)
    overlays = policy.get("overlays", {})
    expected_board_view_aliases = dict(policy.get("board_view_aliases", {}))
    actual_board_view_aliases = scan_board_view_aliases(root)
    unexpected = []
    debt = []
    seen = 0

    for symbol, target in sorted(actual_board_view_aliases.items()):
        expected = expected_board_view_aliases.get(symbol)
        if expected != target:
            unexpected.append(
                (
                    "resident",
                    "asm/spectrum/screen.asm",
                    symbol,
                    f"board_view_alias->{target}",
                )
            )
    for symbol, expected in sorted(expected_board_view_aliases.items()):
        if actual_board_view_aliases.get(symbol) != expected:
            unexpected.append(
                (
                    "resident",
                    "asm/spectrum/screen.asm",
                    symbol,
                    f"missing board_view_alias->{expected}",
                )
            )

    for path in iter_sources(root):
        rel = path.relative_to(root)
        overlay = overlay_for_path(rel)
        if overlay is None:
            continue
        overlay_policy = overlays.get(overlay, {})
        allowed_caps = set(overlay_policy.get("allowed_caps", []))
        debt_caps = set(overlay_policy.get("debt_caps", {}).keys())
        allowed_symbols = set(overlay_policy.get("allowed_symbols", []))
        debt_symbols = set(overlay_policy.get("debt_symbols", {}).keys())
        for symbol in sorted(scan_symbols(path)):
            seen += 1
            cap = classify(symbol)
            cname = canonical_symbol(symbol)
            if symbol in BANNED_SYMBOLS or cname in BANNED_SYMBOLS:
                unexpected.append((overlay, rel.as_posix(), symbol, "banned"))
                continue
            if (
                cname in allowed_symbols
                or symbol in allowed_symbols
                or cap in allowed_caps
            ):
                if args.report:
                    print(f"[OK] {overlay}: {rel.as_posix()} uses {symbol} ({cap})")
                continue
            if cname in debt_symbols or symbol in debt_symbols or cap in debt_caps:
                debt.append((overlay, rel.as_posix(), symbol, cap))
                if args.report:
                    print(f"[DEBT] {overlay}: {rel.as_posix()} uses {symbol} ({cap})")
                continue
            unexpected.append((overlay, rel.as_posix(), symbol, cap))

    if unexpected or (args.fail_debt and debt):
        for overlay, rel, symbol, cap in unexpected:
            print(
                f"[ERR] overlay {overlay}: {rel} imports {symbol} ({cap})",
                file=sys.stderr,
            )
        if args.fail_debt:
            for overlay, rel, symbol, cap in debt:
                print(
                    f"[ERR] overlay debt still present {overlay}: {rel} imports {symbol} ({cap})",
                    file=sys.stderr,
                )
        return 1

    print(
        f"[OK] overlay capabilities: no unexpected imports ({len(debt)} debt, {seen} checked)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
