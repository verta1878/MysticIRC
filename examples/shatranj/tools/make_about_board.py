#!/usr/bin/env python3
"""Build the left-board About payload from the Shatranj logo."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image


AREA_W_BYTES = 18
AREA_W = AREA_W_BYTES * 8
AREA_H = 144
ATTR_ROWS = AREA_H // 8
ABOUT_BYTES = (AREA_W_BYTES * AREA_H) + (AREA_W_BYTES * ATTR_ROWS)
ATTR_WHITE = 0x07
ATTR_YELLOW = 0x06
ATTR_BLACK = 0x00
LOGO_W = 109
LOGO_Y = 22
TEXT_LINES = [
    ("A CHESS GAME FOR SPECTRUM ZX", ATTR_WHITE),
    ("(C) 2026 M.I. MONGE GARCIA", ATTR_WHITE),
    ("GH: IGNACIOMONGE/SHATRANJ", ATTR_YELLOW),
    ("LICENSE: GNU GPL V2.0", ATTR_YELLOW),
]
TEXT_Y = [90, 98, 106, 114]
# Board restore redraws the frame without clearing every border byte. Keep the
# right frame on bit 7 and the bottom frame on scanline 0 of the last row.
FRAME_LEFT = 7
FRAME_TOP = 7
FRAME_RIGHT = 136
FRAME_BOTTOM = 136


def parse_defb_block(text: str, label: str, end_label: str) -> bytes:
    start = re.search(rf"(?m)^{re.escape(label)}:\s*$", text)
    if not start:
        raise SystemExit(f"label not found: {label}")
    end = re.search(rf"(?m)^{re.escape(end_label)}:\s*$", text[start.end():])
    if not end:
        raise SystemExit(f"end label not found: {end_label}")
    block = text[start.end():start.end() + end.start()]
    data = bytearray()
    for raw in block.splitlines():
        line = raw.split(";", 1)[0].strip()
        if not line.upper().startswith("DEFB"):
            continue
        for token in line[4:].split(","):
            token = token.strip()
            if token:
                data.append(int(token, 0) & 0xff)
    return bytes(data)


def crop_logo(img: Image.Image) -> Image.Image:
    gray = img.convert("L")
    pixels = gray.load()
    min_x = img.width
    min_y = img.height
    max_x = -1
    max_y = -1
    for y in range(img.height):
        for x in range(img.width):
            if pixels[x, y] > 24:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if max_x < min_x or max_y < min_y:
        raise SystemExit("logo image has no bright pixels")
    pad_x = max(4, (max_x - min_x + 1) // 40)
    pad_y = max(4, (max_y - min_y + 1) // 30)
    min_x = max(0, min_x - pad_x)
    min_y = max(0, min_y - pad_y)
    max_x = min(img.width - 1, max_x + pad_x)
    max_y = min(img.height - 1, max_y + pad_y)
    return img.crop((min_x, min_y, max_x + 1, max_y + 1))


def put_ikkle_text(base: Image.Image, font: bytes, y: int, text: str) -> None:
    x = (AREA_W - (len(text) * 4)) // 2
    pix = base.load()
    for ch in text.upper():
        code = ord(ch)
        if 33 <= code < 128:
            if code >= 96:
                code -= 32
            index = (code - 32) * 2
            if index + 1 < len(font):
                rows = (
                    font[index] >> 4,
                    font[index] & 0x0f,
                    font[index + 1] >> 4,
                    font[index + 1] & 0x0f,
                )
                for row, bits in enumerate(rows):
                    for bit in range(4):
                        if bits & (0x08 >> bit):
                            px = x + bit
                            py = y + row
                            if 0 <= px < AREA_W and 0 <= py < AREA_H:
                                pix[px, py] = 1
        x += 4


def draw_board_frame(base: Image.Image) -> None:
    pix = base.load()
    for x in range(FRAME_LEFT, FRAME_RIGHT + 1):
        pix[x, FRAME_TOP] = 1
        pix[x, FRAME_BOTTOM] = 1
    for y in range(FRAME_TOP + 1, FRAME_BOTTOM):
        pix[FRAME_LEFT, y] = 1
        pix[FRAME_RIGHT, y] = 1


def build_board(source: Path, ui_assets: Path) -> bytes:
    base = Image.new("1", (AREA_W, AREA_H), 0)
    src = Image.open(source)
    logo = crop_logo(src)

    target_w = LOGO_W
    target_h = max(1, round(logo.height * target_w / logo.width))
    if target_h > 72:
        target_h = 72
        target_w = max(1, round(logo.width * target_h / logo.height))
    logo = logo.resize((target_w, target_h), Image.Resampling.LANCZOS)
    logo = logo.convert("L").convert("1", dither=Image.Dither.FLOYDSTEINBERG)
    base.paste(logo, ((AREA_W - target_w) // 2, LOGO_Y))

    font = parse_defb_block(
        ui_assets.read_text(encoding="ascii"),
        "timer_ikkle_packed",
        "font_packed",
    )
    for (line, _attr), y in zip(TEXT_LINES, TEXT_Y):
        put_ikkle_text(base, font, y, line)
    draw_board_frame(base)

    pixels = bytearray()
    pix = base.load()
    for y in range(AREA_H):
        for x_byte in range(AREA_W_BYTES):
            value = 0
            for bit in range(8):
                if pix[x_byte * 8 + bit, y]:
                    value |= 0x80 >> bit
            pixels.append(value)

    attrs = bytearray([ATTR_BLACK] * (AREA_W_BYTES * ATTR_ROWS))
    logo_attr_top = LOGO_Y // 8
    logo_attr_bottom = (LOGO_Y + target_h + 7) // 8
    for row in range(logo_attr_top, min(ATTR_ROWS, logo_attr_bottom)):
        for col in range(AREA_W_BYTES):
            attrs[row * AREA_W_BYTES + col] = ATTR_WHITE
    for (_line, attr), y in zip(TEXT_LINES, TEXT_Y):
        for row in range(y // 8, ((y + 3) // 8) + 1):
            for col in range(AREA_W_BYTES):
                attrs[row * AREA_W_BYTES + col] = attr
    for col in range(AREA_W_BYTES):
        attrs[col] = ATTR_WHITE
        attrs[(ATTR_ROWS - 1) * AREA_W_BYTES + col] = ATTR_WHITE
    for row in range(1, ATTR_ROWS - 1):
        attrs[row * AREA_W_BYTES] = ATTR_WHITE
        attrs[row * AREA_W_BYTES + AREA_W_BYTES - 1] = ATTR_WHITE

    out = bytes(pixels + attrs)
    if len(out) != ABOUT_BYTES:
        raise SystemExit(f"bad board payload size: {len(out)}")
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("ui_assets", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(build_board(args.source, args.ui_assets))
    print(f"[OK] {args.output}: {ABOUT_BYTES} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
