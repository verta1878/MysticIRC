#!/usr/bin/env python3
"""Build a ZX Spectrum Next .nex from Shatranj resident code plus OVL/DAT bundle."""

from __future__ import annotations

import argparse
import re
import sys
import tempfile
from pathlib import Path

from next_bundle_codec import BANK_SIZE, PAGE_SIZE, pack_pages, unpack_pages

NEX_HEADER_SIZE = 512
MAIN_BASE = 0x4000
MAIN_SIZE = 0xC000
MIN_BUNDLE_SIZE = BANK_SIZE * 2
MAIN_BANKS = ((5, 0x4000), (2, 0x8000), (0, 0xC000))
LOADER_COMPRESSED_BANK_BASE = 8
LOADER_RAW_BANK_BASE = 16
LOADER_RAW_BANK_COUNT = 7


def parse_map(path: Path) -> dict[str, int]:
    symbols: dict[str, int] = {}
    pattern = re.compile(r"^(\w+)\s+=\s+\$([0-9A-Fa-f]+)\s+;")
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = pattern.match(line)
            if match:
                symbols[match.group(1)] = int(match.group(2), 16)
    return symbols


def symbol(symbols: dict[str, int], *names: str) -> int:
    for name in names:
        if name in symbols:
            return symbols[name]
    raise SystemExit("missing map symbol: " + " or ".join(names))


def ranges_overlap(a0: int, a1: int, b0: int, b1: int) -> bool:
    return a0 < b1 and b0 < a1


def validate_graphics_bank(
    blob: bytes, offset: int, origin: int, used: list[tuple[int, int]]
) -> int:
    if len(blob) < 9:
        raise SystemExit("graphics bank is missing its three-entry jump table")
    end = offset + len(blob)
    if offset % PAGE_SIZE != origin:
        raise SystemExit("graphics bank origin does not match its bundle page offset")
    if offset // PAGE_SIZE != (end - 1) // PAGE_SIZE:
        raise SystemExit("graphics bank crosses its 8K MMU page")
    for start, used_end in used:
        if ranges_overlap(offset, end, start, used_end):
            raise SystemExit("graphics bank overlaps another bundle area")
    for entry in range(3):
        table = entry * 3
        if blob[table] != 0xC3:
            raise SystemExit("graphics bank entry table is not three absolute jumps")
        target = int.from_bytes(blob[table + 1 : table + 3], "little")
        if not origin + 9 <= target < origin + len(blob):
            raise SystemExit("graphics bank jump target is outside the linked blob")
    return end


def build_header(load_banks: list[int], pc: int, sp: int) -> bytearray:
    header = bytearray(NEX_HEADER_SIZE)
    header[0:4] = b"Next"
    header[4:8] = b"V1.1"
    header[8] = 1 if any(bank >= 48 for bank in load_banks) else 0
    header[9] = len(load_banks)
    header[11] = 0
    header[12:14] = sp.to_bytes(2, "little")
    header[14:16] = pc.to_bytes(2, "little")
    for bank in load_banks:
        if not 0 <= bank < 112:
            raise SystemExit(f"bank out of NEX range: {bank}")
        header[18 + bank] = 1
    return header


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--map", type=Path, required=True)
    parser.add_argument("--code-bin", type=Path, required=True)
    parser.add_argument("--ovl", type=Path, required=True)
    parser.add_argument("--dat", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--org", type=lambda value: int(value, 0), default=0x7000)
    parser.add_argument("--bundle-bank-base", type=int, default=8)
    parser.add_argument("--raw-bank-base", type=int, default=16)
    parser.add_argument("--max-bundle-banks", type=int, default=3)
    parser.add_argument("--zx0", default="z88dk-zx0")
    parser.add_argument("--dat-offset", type=lambda value: int(value, 0), default=24576)
    parser.add_argument("--sprite-patterns", type=Path)
    parser.add_argument(
        "--sprite-offset", type=lambda value: int(value, 0), default=32768
    )
    parser.add_argument("--sprite-pal", type=Path)
    parser.add_argument(
        "--sprite-pal-offset", type=lambda value: int(value, 0), default=53760
    )
    parser.add_argument("--about-nxi", type=Path)
    parser.add_argument(
        "--about-pal-offset", type=lambda value: int(value, 0), default=57344
    )
    parser.add_argument(
        "--about-pixels-offset", type=lambda value: int(value, 0), default=65536
    )
    parser.add_argument("--graphics-bank", type=Path)
    parser.add_argument(
        "--graphics-bank-offset", type=lambda value: int(value, 0), default=57856
    )
    parser.add_argument(
        "--graphics-bank-org", type=lambda value: int(value, 0), default=0x0200
    )
    args = parser.parse_args(argv)

    if args.bundle_bank_base != LOADER_COMPRESSED_BANK_BASE:
        raise SystemExit(
            f"loader requires compressed bundle bank {LOADER_COMPRESSED_BANK_BASE}"
        )
    if args.raw_bank_base != LOADER_RAW_BANK_BASE:
        raise SystemExit(f"loader requires raw bundle bank {LOADER_RAW_BANK_BASE}")
    if args.max_bundle_banks <= 0:
        raise SystemExit("max bundle banks must be positive")

    if args.about_nxi and args.about_pixels_offset % BANK_SIZE != 0:
        raise SystemExit(
            "about pixels offset must be 16K-bank aligned (Layer 2 shows them in place)"
        )

    if args.dat_offset % 8192 != 0:
        raise SystemExit("DAT offset must be 8K-page aligned")

    symbols = parse_map(args.map)
    pc = symbol(symbols, "__crt_org_code")
    sp = symbol(symbols, "__register_sp", "TAR__register_sp")
    data_tail = symbol(symbols, "__data_compiler_tail")
    resident_len = data_tail - args.org
    if resident_len <= 0:
        raise SystemExit(f"invalid resident length: {resident_len}")

    code = args.code_bin.read_bytes()
    if resident_len > len(code):
        raise SystemExit(f"resident length {resident_len} exceeds code bin {len(code)}")
    if args.org < MAIN_BASE or args.org + resident_len > 0x10000:
        raise SystemExit("resident image does not fit in 48K main RAM")

    main_mem = bytearray(MAIN_SIZE)
    main_offset = args.org - MAIN_BASE
    main_mem[main_offset : main_offset + resident_len] = code[:resident_len]

    main_present: list[int] = []
    resident_start = args.org
    resident_end = args.org + resident_len
    for bank, addr in MAIN_BANKS:
        if ranges_overlap(resident_start, resident_end, addr, addr + BANK_SIZE):
            main_present.append(bank)

    ovl = args.ovl.read_bytes()
    dat = args.dat.read_bytes()
    sprite_patterns = args.sprite_patterns.read_bytes() if args.sprite_patterns else b""
    graphics_bank = args.graphics_bank.read_bytes() if args.graphics_bank else b""
    if len(ovl) > args.dat_offset:
        raise SystemExit(
            f"OVL {len(ovl)} bytes exceeds reserved {args.dat_offset} bytes"
        )
    dat_end = args.dat_offset + len(dat)
    bundle_end = max(MIN_BUNDLE_SIZE, dat_end)
    if sprite_patterns:
        sprite_end = args.sprite_offset + len(sprite_patterns)
        if ranges_overlap(args.sprite_offset, sprite_end, 0, len(ovl)):
            raise SystemExit("sprite patterns overlap OVL bundle area")
        if ranges_overlap(args.sprite_offset, sprite_end, args.dat_offset, dat_end):
            raise SystemExit("sprite patterns overlap DAT bundle area")
        bundle_end = max(bundle_end, sprite_end)
    sprite_pal = args.sprite_pal.read_bytes() if args.sprite_pal else b""
    if sprite_pal:
        sprite_pal_end = args.sprite_pal_offset + len(sprite_pal)
        pal_used = [(0, len(ovl)), (args.dat_offset, dat_end)]
        if sprite_patterns:
            pal_used.append((args.sprite_offset, sprite_end))
        for start, end in pal_used:
            if ranges_overlap(start, end, args.sprite_pal_offset, sprite_pal_end):
                raise SystemExit("sprite palette overlaps another bundle area")
        bundle_end = max(bundle_end, sprite_pal_end)
    about_pal = about_pixels = b""
    if args.about_nxi:
        about = args.about_nxi.read_bytes()
        if len(about) != 512 + 49152:
            raise SystemExit(
                f"{args.about_nxi}: expected 49664-byte .nxi (512 palette + 48K pixels)"
            )
        about_pal, about_pixels = about[:512], about[512:]
        pal_end = args.about_pal_offset + len(about_pal)
        pixels_end = args.about_pixels_offset + len(about_pixels)
        used = [(0, len(ovl)), (args.dat_offset, dat_end)]
        if sprite_patterns:
            used.append((args.sprite_offset, sprite_end))
        if sprite_pal:
            used.append((args.sprite_pal_offset, sprite_pal_end))
        used.append((args.about_pal_offset, pal_end))
        for start, end in used:
            if ranges_overlap(start, end, args.about_pixels_offset, pixels_end):
                raise SystemExit("about pixels overlap another bundle area")
        for start, end in used[:-1]:
            if ranges_overlap(start, end, args.about_pal_offset, pal_end):
                raise SystemExit("about palette overlaps another bundle area")
        bundle_end = max(bundle_end, pal_end, pixels_end)
    graphics_end = 0
    if graphics_bank:
        used = [(0, len(ovl)), (args.dat_offset, dat_end)]
        if sprite_patterns:
            used.append((args.sprite_offset, sprite_end))
        if sprite_pal:
            used.append((args.sprite_pal_offset, sprite_pal_end))
        if about_pal:
            used.append((args.about_pal_offset, pal_end))
            used.append((args.about_pixels_offset, pixels_end))
        graphics_end = validate_graphics_bank(
            graphics_bank,
            args.graphics_bank_offset,
            args.graphics_bank_org,
            used,
        )
        bundle_end = max(bundle_end, graphics_end)
    bundle_size = ((bundle_end + BANK_SIZE - 1) // BANK_SIZE) * BANK_SIZE
    if bundle_size != LOADER_RAW_BANK_COUNT * BANK_SIZE:
        raise SystemExit(
            f"loader requires a {LOADER_RAW_BANK_COUNT}-bank raw bundle, "
            f"got {bundle_size // BANK_SIZE} banks"
        )

    bundle = bytearray(bundle_size)
    bundle[: len(ovl)] = ovl
    bundle[args.dat_offset : dat_end] = dat
    if sprite_patterns:
        bundle[args.sprite_offset : args.sprite_offset + len(sprite_patterns)] = (
            sprite_patterns
        )
    if sprite_pal:
        bundle[args.sprite_pal_offset : args.sprite_pal_offset + len(sprite_pal)] = (
            sprite_pal
        )
    if about_pixels:
        bundle[args.about_pal_offset : args.about_pal_offset + len(about_pal)] = (
            about_pal
        )
        bundle[
            args.about_pixels_offset : args.about_pixels_offset + len(about_pixels)
        ] = about_pixels
    if graphics_bank:
        bundle[args.graphics_bank_offset : graphics_end] = graphics_bank

    if bundle_size % PAGE_SIZE != 0:
        raise SystemExit("raw bundle is not an exact number of 8K pages")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="next_bundle_zx0_", dir=args.out.parent
    ) as temp_name:
        packed = pack_pages(
            bytes(bundle), args.zx0, Path(temp_name), args.raw_bank_base
        )
    restored, raw_bank_base = unpack_pages(packed)
    if restored != bytes(bundle) or raw_bank_base != args.raw_bank_base:
        raise SystemExit("compressed bundle failed byte-for-byte host reconstruction")

    packed_size = ((len(packed) + BANK_SIZE - 1) // BANK_SIZE) * BANK_SIZE
    packed_banks = packed_size // BANK_SIZE
    if packed_banks > args.max_bundle_banks:
        raise SystemExit(
            f"compressed bundle needs {packed_banks} banks, "
            f"limit is {args.max_bundle_banks}"
        )
    raw_banks = bundle_size // BANK_SIZE
    compressed_end = args.bundle_bank_base + packed_banks
    raw_end = args.raw_bank_base + raw_banks
    if ranges_overlap(
        args.bundle_bank_base, compressed_end, args.raw_bank_base, raw_end
    ):
        raise SystemExit("compressed and expanded bundle banks overlap")
    for bank in main_present:
        if args.bundle_bank_base <= bank < compressed_end:
            raise SystemExit("compressed bundle overlaps main RAM bank")
        if args.raw_bank_base <= bank < raw_end:
            raise SystemExit("expanded bundle overlaps main RAM bank")

    packed_bundle = packed + bytes(packed_size - len(packed))
    bundle_banks = list(range(args.bundle_bank_base, compressed_end))
    load_banks = main_present + bundle_banks
    header = build_header(load_banks, pc, sp)

    with args.out.open("wb") as handle:
        handle.write(header)
        for bank, addr in MAIN_BANKS:
            if bank in main_present:
                offset = addr - MAIN_BASE
                handle.write(main_mem[offset : offset + BANK_SIZE])
        for index, _bank in enumerate(bundle_banks):
            offset = index * BANK_SIZE
            handle.write(packed_bundle[offset : offset + BANK_SIZE])

    banks = ",".join(str(bank) for bank in load_banks)
    sprite_msg = f"; sprites {len(sprite_patterns)}" if sprite_patterns else ""
    graphics_msg = f"; graphics {len(graphics_bank)}" if graphics_bank else ""
    print(
        f"[OK] {args.out}: NEX banks {banks}; resident {resident_len}; "
        f"OVL {len(ovl)}; DAT {len(dat)}{sprite_msg}{graphics_msg}; "
        f"bundle {bundle_size}->{len(packed)} bytes ({packed_banks} banks)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
