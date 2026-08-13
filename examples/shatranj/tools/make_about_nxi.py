#!/usr/bin/env python3
"""Bake the About credit lines into the Next Layer 2 title image (.nxi).

Input .nxi layout: 512-byte 9-bit palette (nextreg 0x44 pairs) + 256x192
8bpp pixels. The text is drawn with the shared ikkle 4x4 font at 2x scale
using the nearest palette indexes, so the output stays a plain .nxi.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

PAL_BYTES = 512
WIDTH = 256
HEIGHT = 192
TEXT_LINES = [
    ("A CHESS GAME FOR SPECTRUM NEXT", (255, 255, 255)),
    ("(C) 2026 M.I. MONGE GARCIA", (255, 255, 255)),
    ("GH: IGNACIOMONGE/SHATRANJ", (255, 255, 0)),
    ("LICENSE: GNU GPL V2.0", (255, 255, 0)),
]
TEXT_Y = [140, 148, 156, 164]
SCALE = 1
SHADOW_RGB = (0, 0, 0)


def parse_defb_block(text: str, label: str, end_label: str) -> bytes:
    start = re.search(rf"(?m)^{re.escape(label)}:\s*$", text)
    if not start:
        raise SystemExit(f"label not found: {label}")
    end = re.search(rf"(?m)^{re.escape(end_label)}:\s*$", text[start.end() :])
    if not end:
        raise SystemExit(f"end label not found: {end_label}")
    block = text[start.end() : start.end() + end.start()]
    data = bytearray()
    for raw in block.splitlines():
        line = raw.split(";", 1)[0].strip()
        if not line.upper().startswith("DEFB"):
            continue
        for token in line[4:].split(","):
            token = token.strip()
            if token:
                data.append(int(token, 0) & 0xFF)
    return bytes(data)


def decode_palette(pal: bytes) -> list[tuple[int, int, int]]:
    colors = []
    for i in range(256):
        b0, b1 = pal[i * 2], pal[i * 2 + 1]
        r = (b0 >> 5) & 7
        g = (b0 >> 2) & 7
        b = ((b0 & 3) << 1) | (b1 & 1)
        colors.append((r * 255 // 7, g * 255 // 7, b * 255 // 7))
    return colors


def nearest_index(rgb: tuple[int, int, int], colors: list[tuple[int, int, int]]) -> int:
    r, g, b = rgb
    return min(
        range(256),
        key=lambda i: (
            (r - colors[i][0]) ** 2 + (g - colors[i][1]) ** 2 + (b - colors[i][2]) ** 2
        ),
    )


def glyph_rows(font: bytes, ch: str) -> tuple[int, int, int, int]:
    code = ord(ch.upper())
    if code >= 96:
        code -= 32
    index = (code - 32) * 2
    if not (33 <= code < 128 and index + 1 < len(font)):
        return (0, 0, 0, 0)
    return (
        font[index] >> 4,
        font[index] & 0x0F,
        font[index + 1] >> 4,
        font[index + 1] & 0x0F,
    )


def draw_text(
    px: bytearray, font: bytes, y: int, text: str, ink: int, shadow: int
) -> None:
    x = (WIDTH - len(text) * 4 * SCALE) // 2
    for ch in text:
        for row, bits in enumerate(glyph_rows(font, ch)):
            for bit in range(4):
                if not bits & (0x08 >> bit):
                    continue
                for sy in range(SCALE):
                    for sx in range(SCALE):
                        gx = x + bit * SCALE + sx
                        gy = y + row * SCALE + sy
                        if 0 <= gx < WIDTH - 1 and 0 <= gy < HEIGHT - 1:
                            px[(gy + 1) * WIDTH + gx + 1] = shadow
                            px[gy * WIDTH + gx] = ink
        x += 4 * SCALE
    # second pass so a glyph's shadow never covers its own ink
    x = (WIDTH - len(text) * 4 * SCALE) // 2
    for ch in text:
        for row, bits in enumerate(glyph_rows(font, ch)):
            for bit in range(4):
                if bits & (0x08 >> bit):
                    for sy in range(SCALE):
                        for sx in range(SCALE):
                            gx = x + bit * SCALE + sx
                            gy = y + row * SCALE + sy
                            if 0 <= gx < WIDTH and 0 <= gy < HEIGHT:
                                px[gy * WIDTH + gx] = ink
        x += 4 * SCALE


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("ui_assets", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    raw = args.source.read_bytes()
    if len(raw) != PAL_BYTES + WIDTH * HEIGHT:
        raise SystemExit(f"{args.source}: expected {PAL_BYTES + WIDTH * HEIGHT} bytes")
    pal = raw[:PAL_BYTES]
    px = bytearray(raw[PAL_BYTES:])
    colors = decode_palette(pal)
    shadow = nearest_index(SHADOW_RGB, colors)
    font = parse_defb_block(
        args.ui_assets.read_text(encoding="ascii"),
        "timer_ikkle_packed",
        "font_packed",
    )
    for (line, rgb), y in zip(TEXT_LINES, TEXT_Y):
        draw_text(px, font, y, line, nearest_index(rgb, colors), shadow)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(pal + px)
    print(f"[OK] {args.output}: {len(pal) + len(px)} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
