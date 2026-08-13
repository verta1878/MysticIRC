#!/usr/bin/env python3
"""Check source include layering rules for the modular Spectrum refactor."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


DEFAULT_ALLOWLIST = Path("docs/layering_allowlist.json")
DEFAULT_OVERLAY_STATE_ALLOWLIST = Path("docs/overlay_state_allowlist.json")

RULES = [
    (
        "transport-no-ui",
        re.compile(r"^src/spectrum/transport/.*\.[ch]$"),
        re.compile(r"^spectrum/ui/"),
    ),
    (
        "transport-no-app",
        re.compile(r"^src/spectrum/transport/.*\.[ch]$"),
        re.compile(r"^spectrum/app/"),
    ),
    (
        "ui-no-transport",
        re.compile(r"^src/spectrum/ui/.*\.[ch]$"),
        re.compile(r"^spectrum/transport/"),
    ),
    (
        "ui-no-board",
        re.compile(r"^src/spectrum/ui/.*\.[ch]$"),
        re.compile(r"^spectrum/board/"),
    ),
    (
        "ui-no-overlay",
        re.compile(r"^src/spectrum/ui/.*\.[ch]$"),
        re.compile(r"^spectrum/overlay/"),
    ),
    (
        "common-no-spectrum",
        re.compile(r"^src/common/.*\.[ch]$"),
        re.compile(r"^spectrum/"),
    ),
    (
        "common-session-no-pc-qt",
        re.compile(r"^src/common/session/.*\.[ch]$"),
        re.compile(r"^(?:pc/|Qt|Q[A-Z])"),
    ),
    (
        "common-session-no-toolchain",
        re.compile(r"^src/common/session/.*\.[ch]$"),
        re.compile(r"^(?:z88dk|sdcc|arch/)"),
    ),
    (
        "protocol-no-ui",
        re.compile(r"^src/(common/protocol|spectrum/session)/.*\.[ch]$"),
        re.compile(r"^spectrum/ui/"),
    ),
    (
        "session-no-app",
        re.compile(r"^src/spectrum/session/.*\.[ch]$"),
        re.compile(r"^spectrum/app/"),
    ),
    (
        "session-no-board",
        re.compile(r"^src/spectrum/session/.*\.[ch]$"),
        re.compile(r"^spectrum/board/"),
    ),
    (
        "session-no-overlay",
        re.compile(r"^src/spectrum/session/.*\.[ch]$"),
        re.compile(r"^spectrum/overlay/"),
    ),
    (
        "session-no-transport-internals",
        re.compile(r"^src/spectrum/session/.*\.[ch]$"),
        re.compile(r"^spectrum/transport/(net|mqtt_min|esp_at)\.h$"),
    ),
    (
        "app-no-overlay",
        re.compile(r"^src/spectrum/app/.*\.[ch]$"),
        re.compile(r"^spectrum/overlay/"),
    ),
    (
        "app-no-transport-internals",
        re.compile(r"^src/spectrum/app/.*\.[ch]$"),
        re.compile(r"^spectrum/transport/(net|mqtt_min|esp_at)\.h$"),
    ),
]

INCLUDE_RE = re.compile(r"^\s*#\s*include\s+[<\"]([^>\"]+)[>\"]")
TRANSPORT_RE = re.compile(r"^src/spectrum/transport/.*\.[ch]$")
OVERLAY_INCLUDE_RE = re.compile(r"^spectrum/overlay/")
OVERLAY_FACADE_INCLUDES = {
    "spectrum/overlay/overlay.h",
    "spectrum/overlay/overlay_api.h",
    "spectrum/overlay/overlay_context.h",
}
OVERLAY_DISPATCHER_RE = re.compile(
    r"^src/spectrum/(board|transport|fileui|saveload|restore)/.*\.[ch]$"
)
UI_INCLUDE_RE = re.compile(r"^spectrum/ui/")
UI_SOURCE_RE = re.compile(r"^src/spectrum/ui/.*\.[ch]$")
UI_BOARD_VIEW_OWNER = "src/spectrum/ui/gui.c"
UI_BOARD_VIEW_TOKEN = "NETCHESSZX_LOWRAM_CHESS_BOARD_ADDR"
OVERLAY_SOURCE_RE = re.compile(r"^src/spectrum/overlay/.*\.[ch]$")
OVERLAY_UI_INCLUDE_ALLOWLIST = {
    ("src/spectrum/overlay/gui_log_ovl.c", "spectrum/ui/layout.h"),
    ("src/spectrum/overlay/overlay.c", "spectrum/ui/gui.h"),
    ("src/spectrum/overlay/overlay_api.h", "spectrum/ui/info_panel.h"),
}
NET_RUNTIME_BRIDGE_INCLUDE = "spectrum/platform/net_runtime.h"
NET_RUNTIME_BRIDGE_OWNERS = {
    "src/spectrum/transport/esp_at.c",
    "src/spectrum/transport/net.c",
}
LOWRAM_MAP_OWNER = "src/spectrum/lowram_map.h"
OVERLAY_CONTEXT_OWNER = "src/spectrum/overlay/overlay_context.h"
LOWRAM_LITERAL_RE = re.compile(r"\b0x5[0-9A-Fa-f]{3}\b")
C_INT_RE = r"(?:0x[0-9A-Fa-f]+|[0-9]+)[uU]?"
LOWRAM_DEFINE_RE = re.compile(rf"^#define\s+([A-Z0-9_]+)\s+({C_INT_RE})\b")
ASM_EQU_RE = re.compile(rf"^\s*([A-Za-z0-9_]+)\s+EQU\s+({C_INT_RE})\b")
ASM_LOWRAM_EQUS = {
    (
        "asm/overlay/board/entry_board.asm",
        "NETCHESSZX_CHESS_BOARD",
    ): "NETCHESSZX_LOWRAM_CHESS_BOARD_ADDR",
    (
        "asm/spectrum/screen.asm",
        "NETCHESSZX_RULES_BOARD_BASE",
    ): "NETCHESSZX_LOWRAM_RULES_BOARD_ADDR",
    (
        "asm/spectrum/screen.asm",
        "NETCHESSZX_OVERLAY_CONTEXT",
    ): "NETCHESSZX_LOWRAM_OVERLAY_CONTEXT_ADDR",
    (
        "asm/spectrum/screen.asm",
        "SPECTRUM_OVL_CTX_HINTS_BOARD_LO",
    ): "SPECTRUM_OVL_CTX_HINTS_BOARD_LO",
    (
        "asm/spectrum/screen.asm",
        "SPECTRUM_OVL_CTX_HINTS_BOARD_HI",
    ): "SPECTRUM_OVL_CTX_HINTS_BOARD_HI",
    (
        "asm/spectrum/screen.asm",
        "SPECTRUM_OVL_CTX_HINTS_SIDE_TO_MOVE",
    ): "SPECTRUM_OVL_CTX_HINTS_SIDE_TO_MOVE",
    (
        "asm/spectrum/screen.asm",
        "SPECTRUM_OVL_CTX_HINTS_SQUARE",
    ): "SPECTRUM_OVL_CTX_HINTS_SQUARE",
    (
        "asm/spectrum/screen.asm",
        "SPECTRUM_OVL_CTX_HINTS_CASTLE",
    ): "SPECTRUM_OVL_CTX_HINTS_CASTLE",
    (
        "asm/spectrum/screen.asm",
        "SPECTRUM_OVL_CTX_HINTS_EP",
    ): "SPECTRUM_OVL_CTX_HINTS_EP",
    (
        "asm/esxdos/overlay_loader.asm",
        "_spectrum_overlay_context",
    ): "NETCHESSZX_LOWRAM_OVERLAY_CONTEXT_ADDR",
    (
        "asm/esxdos/overlay_loader.asm",
        "_overlay_scratch_base",
    ): "NETCHESSZX_LOWRAM_OVERLAY_SCRATCH_ADDR",
    (
        "asm/next/overlay_loader_next.asm",
        "_spectrum_overlay_context",
    ): "NETCHESSZX_LOWRAM_OVERLAY_CONTEXT_ADDR",
    (
        "asm/next/overlay_loader_next.asm",
        "_overlay_scratch_base",
    ): "NETCHESSZX_LOWRAM_OVERLAY_SCRATCH_ADDR",
    (
        "asm/overlay/setup/entry_setup.asm",
        "CTX",
    ): "NETCHESSZX_LOWRAM_OVERLAY_CONTEXT_ADDR",
    (
        "asm/overlay/gui_log/entry_gui_log.asm",
        "chat_clock_line_src",
    ): "NETCHESSZX_LOWRAM_CLOCK_SAVE_ADDR",
}
BANNED_LINE_RULES = [
    (
        "esp-at-no-public-line-buffer-globals",
        re.compile(r"^src/spectrum/transport/esp_at\.h$"),
        re.compile(r"^\s*extern\s+.*\b(line_buf|last_ip|line_pos)\b"),
    ),
    (
        "ui-no-board-symbol",
        re.compile(r"^src/spectrum/ui/.*\.[ch]$"),
        re.compile(r"\bspectrum_board_cells\b"),
    ),
    (
        "app-no-extern-function-declarations",
        re.compile(r"^src/spectrum/app/.*\.[ch]$"),
        re.compile(r"^\s*extern\s+.*\([^;]*\)"),
    ),
]
ASM_SDCC_IY_TOKEN_RE = re.compile(r"\b[A-Z0-9_]*SDCC[A-Z0-9_]*IY[A-Z0-9_]*\b")
ASM_SDCC_IY_ALLOWED = {"NETCHESSZX_SDCC_IY"}
OVERLAY_C_RE = re.compile(r"^src/spectrum/overlay/.*\.c$")
EXTERN_VAR_RE = re.compile(
    r"^\s*extern\s+(?!.*\().*?\b([A-Za-z_][A-Za-z0-9_]*)\s*(?:\[[^\]]*\])?\s*;"
)


def is_fixed_lowram_literal(token: str) -> bool:
    value = int(token, 16)
    return 0x5CB6 <= value <= 0x5FFF


def parse_c_int(token: str) -> int:
    return int(token.rstrip("uU"), 0)


def load_lowram_map(root: Path) -> dict[str, int]:
    constants: dict[str, int] = {}
    for rel_path in (LOWRAM_MAP_OWNER, OVERLAY_CONTEXT_OWNER):
        path = root / rel_path
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            match = LOWRAM_DEFINE_RE.match(line)
            if match:
                constants[match.group(1)] = parse_c_int(match.group(2))
    return constants


def iter_sources(root: Path) -> list[Path]:
    roots = [root / "src" / "common", root / "src" / "spectrum"]
    out: list[Path] = []
    for base in roots:
        if not base.exists():
            continue
        out.extend(path for path in base.rglob("*") if path.suffix in {".c", ".h"})
    return sorted(out)


def iter_asm_sources(root: Path) -> list[Path]:
    base = root / "asm"
    if not base.exists():
        return []
    return sorted(path for path in base.rglob("*.asm"))


def load_known(path: Path) -> set[tuple[str, str, str]]:
    if not path.exists():
        return set()
    data = json.loads(path.read_text(encoding="utf-8"))
    known = set()
    for item in data.get("known_violations", []):
        known.add((item["rule"], item["path"].replace("\\", "/"), item["include"]))
    return known


def load_overlay_state_allowlist(path: Path) -> set[tuple[str, str]]:
    if not path.exists():
        return set()
    data = json.loads(path.read_text(encoding="utf-8"))
    allowed = set()
    for item in data.get("allowed_extern_state", []):
        allowed.add((item["path"].replace("\\", "/"), item["symbol"]))
    return allowed


def find_violations(
    root: Path, overlay_state_allowlist: set[tuple[str, str]]
) -> list[tuple[str, str, int, str]]:
    violations: list[tuple[str, str, int, str]] = []
    lowram_constants = load_lowram_map(root)
    seen_asm_lowram: set[tuple[str, str]] = set()
    seen_overlay_state: set[tuple[str, str]] = set()
    for path in iter_sources(root):
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for line_no, line in enumerate(text, 1):
            if rel != LOWRAM_MAP_OWNER:
                for token in LOWRAM_LITERAL_RE.findall(line):
                    if is_fixed_lowram_literal(token):
                        violations.append(("lowram-map-owner", rel, line_no, token))
            if (
                UI_SOURCE_RE.match(rel)
                and UI_BOARD_VIEW_TOKEN in line
                and rel != UI_BOARD_VIEW_OWNER
            ):
                violations.append(
                    ("ui-board-live-view-owner", rel, line_no, UI_BOARD_VIEW_TOKEN)
                )
            for rule_id, banned_path_re, banned_re in BANNED_LINE_RULES:
                if banned_path_re.match(rel) and banned_re.search(line):
                    violations.append((rule_id, rel, line_no, "<declaration>"))
            extern_var = EXTERN_VAR_RE.match(line)
            if extern_var and OVERLAY_C_RE.match(rel):
                symbol = extern_var.group(1)
                key = (rel, symbol)
                seen_overlay_state.add(key)
                if key not in overlay_state_allowlist:
                    violations.append(
                        ("overlay-extern-state-allowlist", rel, line_no, symbol)
                    )
            match = INCLUDE_RE.match(line)
            if not match:
                continue
            include = match.group(1)
            include_parts = include.replace("\\", "/").split("/")
            if any(part in {".", ".."} for part in include_parts):
                violations.append(
                    ("noncanonical-relative-include", rel, line_no, include)
                )
            if (
                OVERLAY_DISPATCHER_RE.match(rel)
                and OVERLAY_INCLUDE_RE.match(include)
                and include not in OVERLAY_FACADE_INCLUDES
            ):
                violations.append(
                    ("overlay-dispatcher-facade-only", rel, line_no, include)
                )
            if (
                OVERLAY_SOURCE_RE.match(rel)
                and UI_INCLUDE_RE.match(include)
                and (rel, include) not in OVERLAY_UI_INCLUDE_ALLOWLIST
            ):
                violations.append(
                    ("overlay-ui-include-allowlist", rel, line_no, include)
                )
            if (
                TRANSPORT_RE.match(rel)
                and include == NET_RUNTIME_BRIDGE_INCLUDE
                and rel not in NET_RUNTIME_BRIDGE_OWNERS
            ):
                violations.append(
                    ("transport-net-runtime-bridge-only", rel, line_no, include)
                )
            for rule_id, path_re, include_re in RULES:
                if path_re.match(rel) and include_re.match(include):
                    violations.append((rule_id, rel, line_no, include))
    for path in iter_asm_sources(root):
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for line_no, line in enumerate(text, 1):
            equ_match = ASM_EQU_RE.match(line)
            if equ_match:
                equ_name = equ_match.group(1)
                key = (rel, equ_name)
                expected_name = ASM_LOWRAM_EQUS.get(key)
                if expected_name is not None:
                    seen_asm_lowram.add(key)
                    expected = lowram_constants.get(expected_name)
                    actual = parse_c_int(equ_match.group(2))
                    if expected is None or actual != expected:
                        violations.append(
                            (
                                "asm-lowram-map-match",
                                rel,
                                line_no,
                                f"{equ_name}={equ_match.group(2)}",
                            )
                        )
            for token in ASM_SDCC_IY_TOKEN_RE.findall(line):
                if token not in ASM_SDCC_IY_ALLOWED:
                    violations.append(("asm-sdcc-iy-macro-name", rel, line_no, token))
    for key, expected_name in ASM_LOWRAM_EQUS.items():
        if key not in seen_asm_lowram:
            violations.append(
                (
                    "asm-lowram-map-match",
                    key[0],
                    0,
                    f"{key[1]} missing for {expected_name}",
                )
            )
    for rel, symbol in sorted(overlay_state_allowlist - seen_overlay_state):
        violations.append(
            ("overlay-extern-state-stale", rel, 0, f"{symbol} not declared")
        )
    return violations


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--allowlist", type=Path, default=DEFAULT_ALLOWLIST)
    parser.add_argument(
        "--overlay-state-allowlist",
        type=Path,
        default=DEFAULT_OVERLAY_STATE_ALLOWLIST,
    )
    parser.add_argument("--report", action="store_true")
    parser.add_argument("--fail-known", action="store_true")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    known = load_known(args.allowlist)
    overlay_state_allowlist = load_overlay_state_allowlist(args.overlay_state_allowlist)
    unexpected = []
    known_hits = []

    for rule_id, rel, line_no, include in find_violations(
        root, overlay_state_allowlist
    ):
        key = (rule_id, rel, include)
        if key in known:
            known_hits.append((rule_id, rel, line_no, include))
        else:
            unexpected.append((rule_id, rel, line_no, include))

    if args.report:
        for rule_id, rel, line_no, include in known_hits:
            print(f"[DEBT] {rule_id}: {rel}:{line_no} includes {include}")
        for rule_id, rel, line_no, include in unexpected:
            print(f"[ERR] {rule_id}: {rel}:{line_no} includes {include}")

    if unexpected or (args.fail_known and known_hits):
        for rule_id, rel, line_no, include in unexpected:
            print(
                f"[ERR] {rule_id}: {rel}:{line_no} includes {include}", file=sys.stderr
            )
        if args.fail_known:
            for rule_id, rel, line_no, include in known_hits:
                print(
                    f"[ERR] known debt still present: {rule_id}: {rel}:{line_no} includes {include}",
                    file=sys.stderr,
                )
        return 1

    print(
        f"[OK] layering check: no unexpected violations ({len(known_hits)} known debt)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
