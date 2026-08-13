#!/usr/bin/env python3
"""Host round-trip tests for the Next compressed bundle container."""

from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.next_bundle_codec import (  # noqa: E402
    BANK_SIZE,
    HEADER_FIXED_SIZE,
    PAGE_SIZE,
    CodecError,
    decompress_classic_zx0,
    pack_pages,
    _plan_banks,
    unpack_pages,
)


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zx0", default="z88dk-zx0")
    args = parser.parse_args(argv)

    partition_sizes = [9600, 8000, 4800, 3200, 3200, 3200]
    partition_header = HEADER_FIXED_SIZE + 2 * len(partition_sizes)
    partition_banks = _plan_banks(partition_sizes, partition_header)
    first_size = partition_header + sum(
        size
        for index, size in enumerate(partition_sizes)
        if partition_banks[index] == 0
    )
    second_size = sum(
        size
        for index, size in enumerate(partition_sizes)
        if partition_banks[index] == 1
    )
    check(
        max(partition_banks) == 1
        and first_size <= BANK_SIZE
        and second_size <= BANK_SIZE,
        "exact two-bank fallback was not applied",
    )

    pages = [
        bytes((index & 0xFF for index in range(PAGE_SIZE))),
        (b"NETCHESSZX" * ((PAGE_SIZE + 9) // 10))[:PAGE_SIZE],
        bytes((0xE3 if index % 17 else index & 0xFF for index in range(PAGE_SIZE))),
    ]
    raw = b"".join(pages)
    build_dir = ROOT / "build"
    build_dir.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="next_bundle_codec_", dir=build_dir
    ) as temp_name:
        temp = Path(temp_name)
        first = pack_pages(raw, args.zx0, temp / "first", 16)
        second = pack_pages(raw, args.zx0, temp / "second", 16)

    check(first == second, "packed output is not deterministic")
    restored, raw_bank_base = unpack_pages(first)
    check(restored == raw, "packed pages do not reconstruct byte-for-byte")
    check(raw_bank_base == 16, "raw bank base metadata changed")

    count = first[6]
    for index in range(count):
        table = HEADER_FIXED_SIZE + 2 * index
        offset = int.from_bytes(first[table : table + 2], "little")
        bank_end = min(((offset // BANK_SIZE) + 1) * BANK_SIZE, len(first))
        _page, consumed = decompress_classic_zx0(first, offset, bank_end)
        check(
            offset // BANK_SIZE == (consumed - 1) // BANK_SIZE,
            f"stream {index} crosses a compressed bank",
        )

    corrupt = bytearray(first)
    corrupt[0] ^= 0xFF
    try:
        unpack_pages(bytes(corrupt))
    except CodecError:
        pass
    else:
        raise AssertionError("bad magic accepted")

    print(
        f"next bundle codec tests ok: {len(raw)} -> {len(first)} bytes, "
        f"{count} pages"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
