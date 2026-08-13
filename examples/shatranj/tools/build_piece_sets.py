#!/usr/bin/env python3
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/spectrum/chess_pieces_16x16.asm"
PIECE_DIR = ROOT / "assets/spectrum/piece_sets"

PIECES = [("k", "K"), ("q", "Q"), ("r", "R"), ("b", "B"), ("n", "N"), ("p", "P")]
SETS = [("STD", None), ("SPCY", "spicy"), ("PIXL", "pixel")]
SPRITE_BYTES = 32
SET_BYTES = 384
SPICY_SOURCE = {"R": "N", "B": "R", "N": "B"}
PIXEL_Y_SHIFT = {"P": -2}
PIXEL_RAISE_TOP = {"R"}


def parse_defb(text):
    data = bytearray()
    for raw in text.splitlines():
        line = raw.split(";", 1)[0].strip()
        if not line.upper().startswith("DEFB"):
            continue
        for token in line[4:].split(","):
            token = token.strip()
            if token:
                data.append(int(token, 0) & 0xFF)
    return bytes(data)


def mask_from_png(path):
    image = Image.open(path).convert("RGBA")
    if image.size != (16, 16):
        raise SystemExit(f"{path}: got {image.size}, expected 16x16")
    raw = (
        image.get_flattened_data()
        if hasattr(image, "get_flattened_data")
        else image.getdata()
    )
    pixels = list(raw)
    opaque = [px for px in pixels if px[3] != 0]
    if not opaque:
        raise SystemExit(f"{path}: empty image")
    if len(set(opaque)) > 2:
        raise SystemExit(f"{path}: expected monochrome/transparent image")
    return [px[3] != 0 for px in pixels]


def edge_mask(mask):
    out = []
    for y in range(16):
        for x in range(16):
            if not mask[y * 16 + x]:
                out.append(False)
                continue
            edge = x == 0 or x == 15 or y == 0 or y == 15
            edge = edge or not mask[y * 16 + max(0, x - 1)]
            edge = edge or not mask[y * 16 + min(15, x + 1)]
            edge = edge or not mask[max(0, y - 1) * 16 + x]
            edge = edge or not mask[min(15, y + 1) * 16 + x]
            out.append(edge)
    return out


def sprite_bytes(mask):
    data = bytearray()
    for y in range(16):
        hi = 0
        lo = 0
        for x in range(8):
            if mask[y * 16 + x]:
                hi |= 0x80 >> x
        for x in range(8, 16):
            if mask[y * 16 + x]:
                lo |= 0x80 >> (x - 8)
        data.extend((hi, lo))
    return bytes(data)


def shift_mask(mask, dy):
    out = [False] * (16 * 16)
    for y in range(16):
        target_y = y + dy
        if target_y < 0 or target_y >= 16:
            continue
        for x in range(16):
            out[target_y * 16 + x] = mask[y * 16 + x]
    return out


def raise_top_row(mask):
    out = list(mask)
    for y in range(1, 16):
        row = [x for x in range(16) if mask[y * 16 + x]]
        if row:
            for x in row:
                out[(y - 1) * 16 + x] = True
            break
    return out


def load_current_set():
    text = OUT.read_text(encoding="ascii")
    match = re.search(r"(?m)^netchesszx_piece_sprites_16x16:\s*$", text)
    if not match:
        raise SystemExit("netchesszx_piece_sprites_16x16 not found")
    data = parse_defb(text[match.end() :])
    if len(data) < SET_BYTES:
        raise SystemExit(f"{OUT}: got {len(data)} bytes, expected at least {SET_BYTES}")
    return data[:SET_BYTES]


def load_spicy_set():
    data = bytearray()
    for lower, upper in PIECES:
        source = SPICY_SOURCE.get(upper, upper)
        fill = mask_from_png(PIECE_DIR / "spicy" / f"b{source}.png")
        data.extend(sprite_bytes(edge_mask(fill)))
        data.extend(sprite_bytes(fill))
    return bytes(data)


def load_pixel_set():
    data = bytearray()
    for lower, upper in PIECES:
        black = mask_from_png(PIECE_DIR / "pixel" / f"b{upper}.png")
        white = mask_from_png(PIECE_DIR / "pixel" / f"w{upper}.png")
        if black != white:
            raise SystemExit(f"pixel {upper}: black/white masks differ")
        if upper in PIXEL_Y_SHIFT:
            black = shift_mask(black, PIXEL_Y_SHIFT[upper])
        if upper in PIXEL_RAISE_TOP:
            black = raise_top_row(black)
        data.extend(sprite_bytes(edge_mask(black)))
        data.extend(sprite_bytes(black))
    return bytes(data)


def emit_defb(lines, data):
    if len(data) != SPRITE_BYTES:
        raise SystemExit(f"sprite got {len(data)} bytes, expected {SPRITE_BYTES}")
    for i in range(0, SPRITE_BYTES, 2):
        lines.append(f"    DEFB 0x{data[i]:02x}, 0x{data[i + 1]:02x}")


def emit_set(lines, name, data, public_labels):
    if len(data) != SET_BYTES:
        raise SystemExit(f"{name}: got {len(data)} bytes, expected {SET_BYTES}")
    lines.append("")
    lines.append(f"netchesszx_piece_set_{name.lower()}:")
    offset = 0
    for lower, upper in PIECES:
        lines.append("")
        lines.append(f"; {name} {upper}: white/light and black/dark")
        if public_labels:
            lines.append(f"netchesszx_piece_sprite_wl_{lower}:")
            lines.append(f"netchesszx_piece_sprite_bd_{lower}:")
        emit_defb(lines, data[offset : offset + SPRITE_BYTES])
        offset += SPRITE_BYTES

        lines.append("")
        lines.append(f"; {name} {upper}: white/dark and black/light")
        if public_labels:
            lines.append(f"netchesszx_piece_sprite_wd_{lower}:")
            lines.append(f"netchesszx_piece_sprite_bl_{lower}:")
        emit_defb(lines, data[offset : offset + SPRITE_BYTES])
        offset += SPRITE_BYTES


def main():
    set_data = [
        ("STD", load_current_set()),
        ("SPCY", load_spicy_set()),
        ("PIXL", load_pixel_set()),
    ]
    if len({data for _, data in set_data}) != len(set_data):
        raise SystemExit("piece sets are not distinct")

    lines = [
        "; Shatranj 16x16 chess piece sprite sets.",
        "; Generated by tools/build_piece_sets.py.",
        "; Each set is 12 physical sprites: 6 pieces x 2 square/color masks.",
        "",
        "PIECE_SPRITE_WIDTH       EQU 16",
        "PIECE_SPRITE_HEIGHT      EQU 16",
        "PIECE_SPRITE_ROW_BYTES   EQU 2",
        "PIECE_SPRITE_BYTES       EQU 32",
        "PIECE_SPRITE_COUNT       EQU 24",
        "PIECE_SPRITE_SET_BYTES   EQU 384",
        "PIECE_SPRITE_SET_COUNT   EQU 3",
        "",
        "SECTION rodata_user",
        "",
        "PUBLIC netchesszx_piece_sprites_16x16",
    ]
    for suffix in ("wl", "wd", "bl", "bd"):
        for lower, _ in PIECES:
            lines.append(f"PUBLIC netchesszx_piece_sprite_{suffix}_{lower}")
    lines.append("")
    lines.append("netchesszx_piece_sprites_16x16:")

    for index, (name, data) in enumerate(set_data):
        emit_set(lines, name, data, index == 0)

    OUT.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"[OK] {OUT}: {sum(len(data) for _, data in set_data)} bytes")


if __name__ == "__main__":
    main()
