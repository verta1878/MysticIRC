#!/usr/bin/env python3
"""Focused tests for the TAP initialized-data/BSS packaging guard."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.check_tap_image import TapImageError, validate_image  # noqa: E402


ORG = 0x7000
SYMBOLS = {
    "__data_compiler_tail": ORG + 2,
    "__DATA_END_tail": ORG + 3,
    "__BSS_head": ORG + 3,
    "__BSS_END_tail": ORG + 5,
}


def tap_block(flag: int, payload: bytes) -> bytes:
    body = bytes((flag,)) + payload
    checksum = 0
    for value in body:
        checksum ^= value
    block = body + bytes((checksum,))
    return len(block).to_bytes(2, "little") + block


def code_tap(code: bytes) -> bytes:
    header = (
        bytes((3,))
        + b"SHATRANJ  "
        + len(code).to_bytes(2, "little")
        + ORG.to_bytes(2, "little")
        + bytes(2)
    )
    return tap_block(0, header) + tap_block(0xFF, code)


def expect_rejected(code: bytes, tap: bytes, message: str) -> None:
    try:
        validate_image(SYMBOLS, code, tap, ORG)
    except TapImageError:
        return
    raise AssertionError(message)


def main() -> int:
    code = bytes((0xA1, 0xB2, 0x4B, 0, 0))
    image = validate_image(SYMBOLS, code, code_tap(code), ORG)
    assert len(image.payload) == 5
    assert image.initialized_bytes == 3
    assert image.bss_bytes == 2
    assert image.data_after_compiler == 1

    expect_rejected(
        code,
        code_tap(code[:2]),
        "TAP trimmed at __data_compiler_tail was accepted",
    )

    wrong_data = bytearray(code)
    wrong_data[2] ^= 0xFF
    expect_rejected(
        code,
        code_tap(bytes(wrong_data)),
        "corrupt post-compiler data_user byte was accepted",
    )

    dirty_bss = bytearray(code)
    dirty_bss[-1] = 1
    expect_rejected(
        bytes(dirty_bss),
        code_tap(bytes(dirty_bss)),
        "non-zero BSS was accepted",
    )

    print("TAP image guard tests ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
