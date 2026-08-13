#!/usr/bin/env python3
"""Focused host checks for the Next executable graphics-bank contract."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from gen_next_nex import validate_graphics_bank  # noqa: E402


def numeric(text: str, name: str, operator: str) -> int:
    match = re.search(
        rf"(?m)^{re.escape(name)}\s+{re.escape(operator)}\s+(0x[0-9A-Fa-f]+|[0-9]+)\s*$",
        text,
    )
    if not match:
        raise AssertionError(f"{name} not found")
    return int(match.group(1), 0)


def expect_rejected(blob: bytes, offset: int, origin: int, used=()) -> None:
    try:
        validate_graphics_bank(blob, offset, origin, list(used))
    except SystemExit:
        return
    raise AssertionError("invalid graphics-bank layout accepted")


def main() -> int:
    origin = 0x0200
    blob = bytearray(32)
    for index, target in enumerate((origin + 9, origin + 12, origin + 15)):
        base = index * 3
        blob[base] = 0xC3
        blob[base + 1 : base + 3] = target.to_bytes(2, "little")

    end = validate_graphics_bank(bytes(blob), 57856, origin, [(57344, 57856)])
    assert end == 57888
    expect_rejected(bytes(blob), 57857, origin)
    expect_rejected(bytes(blob), 65530, 8186)
    expect_rejected(bytes(blob), 57856, origin, [(57870, 57900)])
    bad_entry = bytearray(blob)
    bad_entry[3] = 0
    expect_rejected(bytes(bad_entry), 57856, origin)

    source = (ROOT / "asm/next/graphics_bank_next.asm").read_text(encoding="utf-8")
    layout = (ROOT / "asm/next/graphics_bank_layout.asm").read_text(encoding="utf-8")
    makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
    layout_offset = numeric(layout, "next_graphics_bank_bundle_offset", "EQU")
    layout_origin = numeric(layout, "next_graphics_bank_org", "EQU")
    layout_page = numeric(layout, "next_graphics_bank_page", "EQU")
    make_offset = numeric(makefile, "NEXT_GRAPHICS_BANK_OFFSET", ":=")
    make_origin = numeric(makefile, "NEXT_GRAPHICS_BANK_ORG", ":=")
    make_limit = numeric(makefile, "NEXT_GRAPHICS_BANK_LIMIT", ":=")
    assert layout_offset == make_offset == 57856
    assert layout_origin == make_origin == layout_offset % 8192
    assert layout_page == 32 + layout_offset // 8192
    assert make_limit == 8192 - layout_origin

    assert not re.search(r"(?mi)^\s*ei(?:\s|$)", source), "cold bank enables interrupts"
    assert not re.search(r"(?mi)^\s*rst(?:\s|$)", source), "cold bank calls ROM"
    assert "next_map_slot0" not in source, "cold bank remaps its executing slot"
    labels = set(re.findall(r"(?m)^([A-Za-z_][A-Za-z0-9_]*):", source))
    targets = set(
        re.findall(r"(?mi)^\s*(?:call|jp)\s+([A-Za-z_][A-Za-z0-9_]*)", source)
    )
    allowed_resident = {
        "_spectrum_next_sprites_hide_all",
        "next_copy_bundle",
        "nextreg_read",
        "nextreg_write",
    }
    assert not targets - labels - allowed_resident, "cold bank calls an unguarded service"
    print("Next graphics-bank contract ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
