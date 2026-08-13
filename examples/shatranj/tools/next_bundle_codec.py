#!/usr/bin/env python3
"""Pack fixed 8K pages as independently decodable classic ZX0 streams."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

MAGIC = b"NXZ0"
VERSION = 1
PAGE_SHIFT = 13
PAGE_SIZE = 1 << PAGE_SHIFT
BANK_SIZE = 0x4000
HEADER_FIXED_SIZE = 8


class CodecError(ValueError):
    """Invalid input, directory, or ZX0 stream."""


class _ZX0Reader:
    def __init__(self, data: bytes, start: int, limit: int) -> None:
        self.data = data
        self.pos = start
        self.limit = limit
        self.bit_mask = 0
        self.bit_value = 0
        self.backtrack = False
        self.last_byte = 0

    def read_byte(self) -> int:
        if self.pos >= self.limit:
            raise CodecError("truncated ZX0 stream")
        self.last_byte = self.data[self.pos]
        self.pos += 1
        return self.last_byte

    def read_bit(self) -> int:
        if self.backtrack:
            self.backtrack = False
            return self.last_byte & 1
        self.bit_mask >>= 1
        if self.bit_mask == 0:
            self.bit_mask = 0x80
            self.bit_value = self.read_byte()
        return 1 if self.bit_value & self.bit_mask else 0

    def read_elias(self) -> int:
        value = 1
        while self.read_bit() == 0:
            value = (value << 1) | self.read_bit()
        return value


def decompress_classic_zx0(
    data: bytes, start: int = 0, limit: int | None = None
) -> tuple[bytes, int]:
    """Decode one classic ZX0 v1 stream and return (output, end offset)."""

    if limit is None:
        limit = len(data)
    if not 0 <= start < limit <= len(data):
        raise CodecError("invalid ZX0 source range")

    reader = _ZX0Reader(data, start, limit)
    output = bytearray()
    last_offset = 1

    while True:
        length = reader.read_elias()
        for _ in range(length):
            output.append(reader.read_byte())

        if reader.read_bit() == 0:
            length = reader.read_elias()
            if last_offset > len(output):
                raise CodecError("ZX0 last offset precedes output")
            for _ in range(length):
                output.append(output[-last_offset])
            if reader.read_bit() == 0:
                continue

        while True:
            last_offset = reader.read_elias()
            if last_offset == 256:
                return bytes(output), reader.pos
            last_offset = last_offset * 128 - (reader.read_byte() >> 1)
            if last_offset <= 0 or last_offset > len(output):
                raise CodecError("ZX0 new offset precedes output")
            reader.backtrack = True
            length = reader.read_elias() + 1
            for _ in range(length):
                output.append(output[-last_offset])
            if reader.read_bit() == 0:
                break


def _compress_page(
    page: bytes, executable: str, work_dir: Path, index: int
) -> bytes:
    source = work_dir / f"page_{index:02d}.bin"
    packed = work_dir / f"page_{index:02d}.zx0"
    source.write_bytes(page)
    command = [executable, "-f", str(source), str(packed)]
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as exc:
        raise CodecError(f"cannot execute ZX0 compressor {executable!r}: {exc}") from exc
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise CodecError(f"ZX0 compressor failed for page {index}: {detail}")
    stream = packed.read_bytes()
    try:
        restored, consumed = decompress_classic_zx0(stream)
    except CodecError as exc:
        raise CodecError(
            f"ZX0 compressor must emit classic v1 streams (page {index}): {exc}"
        ) from exc
    if restored != page or consumed != len(stream):
        raise CodecError(f"ZX0 round-trip mismatch for page {index}")
    return stream


def _two_bank_partition(sizes: list[int], header_size: int) -> int | None:
    """Return a bank-zero page mask when all streams fit in two banks."""

    total = sum(sizes)
    if not BANK_SIZE < header_size + total <= 2 * BANK_SIZE:
        return None
    limit = BANK_SIZE - header_size
    minimum = max(0, total - BANK_SIZE)
    reachable = {0: 0}
    for index, size in enumerate(sizes):
        for used, mask in tuple(reachable.items()):
            candidate = used + size
            if candidate <= limit and candidate not in reachable:
                reachable[candidate] = mask | (1 << index)
    return next(
        (
            reachable[used]
            for used in range(limit, minimum - 1, -1)
            if used in reachable
        ),
        None,
    )


def _plan_banks(sizes: list[int], header_size: int) -> list[int]:
    """Assign each stream to a bank, with an exact two-bank fallback."""

    used = [header_size]
    banks = [0] * len(sizes)
    for index in sorted(range(len(sizes)), key=lambda item: (-sizes[item], item)):
        size = sizes[index]
        if size > BANK_SIZE:
            raise CodecError(f"compressed page {index} exceeds one 16K bank")
        candidates = [
            bank for bank, count in enumerate(used) if count + size <= BANK_SIZE
        ]
        if candidates:
            bank = max(candidates, key=lambda item: (used[item], -item))
        else:
            bank = len(used)
            used.append(0)
        banks[index] = bank
        used[bank] += size

    if len(used) > 2:
        partition = _two_bank_partition(sizes, header_size)
        if partition is not None:
            return [
                0 if partition & (1 << index) else 1
                for index in range(len(sizes))
            ]
    return banks


def pack_pages(
    raw: bytes,
    executable: str,
    work_dir: Path,
    raw_bank_base: int,
) -> bytes:
    """Compress raw 8K pages, keeping every stream inside one 16K bank."""

    if len(raw) == 0 or len(raw) % PAGE_SIZE != 0:
        raise CodecError("raw bundle must contain complete non-empty 8K pages")
    page_count = len(raw) // PAGE_SIZE
    if page_count > 255 or not 0 <= raw_bank_base <= 255:
        raise CodecError("page count or raw bank base does not fit metadata")
    header_size = HEADER_FIXED_SIZE + 2 * page_count
    if header_size >= BANK_SIZE:
        raise CodecError("ZX0 directory does not fit first compressed bank")

    resolved = shutil.which(executable)
    if resolved is None:
        raise CodecError(f"ZX0 compressor not found: {executable}")
    work_dir.mkdir(parents=True, exist_ok=True)
    streams = [
        _compress_page(
            raw[index * PAGE_SIZE : (index + 1) * PAGE_SIZE],
            resolved,
            work_dir,
            index,
        )
        for index in range(page_count)
    ]

    sizes = [len(stream) for stream in streams]
    bank_for_page = _plan_banks(sizes, header_size)
    bank_count = max(bank_for_page) + 1
    bins = [bytearray(header_size)] + [
        bytearray() for _ in range(bank_count - 1)
    ]
    used = [header_size] + [0] * (bank_count - 1)
    offsets = [0] * page_count
    for index, stream in sorted(
        enumerate(streams), key=lambda item: (-len(item[1]), item[0])
    ):
        bank = bank_for_page[index]
        offset = bank * BANK_SIZE + used[bank]
        if offset > 0xFFFF:
            raise CodecError("compressed directory offset exceeds 16 bits")
        offsets[index] = offset
        bins[bank].extend(stream)
        used[bank] += len(stream)

    packed = bytearray()
    for index, bank in enumerate(bins):
        packed.extend(bank)
        if index + 1 < len(bins):
            packed.extend(bytes(BANK_SIZE - len(bank)))

    packed[0:4] = MAGIC
    packed[4] = VERSION
    packed[5] = PAGE_SHIFT
    packed[6] = page_count
    packed[7] = raw_bank_base
    for index, offset in enumerate(offsets):
        table = HEADER_FIXED_SIZE + 2 * index
        packed[table : table + 2] = offset.to_bytes(2, "little")
    return bytes(packed)


def unpack_pages(packed: bytes) -> tuple[bytes, int]:
    """Validate a packed directory and reconstruct its raw pages."""

    if len(packed) < HEADER_FIXED_SIZE or packed[0:4] != MAGIC:
        raise CodecError("bad compressed bundle magic")
    if packed[4] != VERSION or packed[5] != PAGE_SHIFT:
        raise CodecError("unsupported compressed bundle format")
    page_count = packed[6]
    raw_bank_base = packed[7]
    header_size = HEADER_FIXED_SIZE + 2 * page_count
    if page_count == 0 or header_size > len(packed):
        raise CodecError("invalid compressed bundle page count")

    raw = bytearray()
    seen: set[int] = set()
    for index in range(page_count):
        table = HEADER_FIXED_SIZE + 2 * index
        offset = int.from_bytes(packed[table : table + 2], "little")
        if offset < header_size or offset >= len(packed) or offset in seen:
            raise CodecError(f"invalid compressed page offset {index}")
        seen.add(offset)
        bank_end = min(((offset // BANK_SIZE) + 1) * BANK_SIZE, len(packed))
        restored, consumed = decompress_classic_zx0(packed, offset, bank_end)
        if len(restored) != PAGE_SIZE:
            raise CodecError(
                f"compressed page {index} expands to {len(restored)}, expected {PAGE_SIZE}"
            )
        if consumed > bank_end:
            raise CodecError(f"compressed page {index} crosses a 16K bank")
        raw.extend(restored)
    return bytes(raw), raw_bank_base
