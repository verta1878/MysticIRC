#!/usr/bin/env python3
import re
import sys
from pathlib import Path

EXPECTED_UI_BYTES = 812
BANNER_INFO_SLOT = 34
VERSION_SLOT = 16
NEXT_BANNER_INFO = "ONLINE CHESS FOR SPECTRUM NEXT"
# Next board sprite themes: black&white, blue3, green, brown, wood.
# ULA attrs only tint the board frame; squares are covered by sprites.
NEXT_BOARD_MARK_INKS = [2, 2, 1, 0, 0]
NEXT_BOARD_LIGHT_ATTRS = [0x78, 0x6F, 0x66, 0x77, 0x37]
NEXT_BOARD_DARK_ATTRS = [0x07, 0x4D, 0x20, 0x56, 0x52]
RUNTIME_PIECE_BYTES = 384
EXPECTED_PIECE_BYTES = RUNTIME_PIECE_BYTES * 3
ABOUT_BOARD_WIDTH = 18
ABOUT_PIXEL_BYTES = ABOUT_BOARD_WIDTH * 144
EXPECTED_ABOUT_BOARD_BYTES = ABOUT_PIXEL_BYTES + (ABOUT_BOARD_WIDTH * 18)
# Raw rectangles containing every non-frame pixel: logo, then four text lines.
# The overlay clears the board and generates the frame/attributes itself.
ABOUT_RECTS = (
    (2, 24, 14, 35),
    (2, 90, 14, 4),
    (2, 98, 14, 4),
    (2, 106, 14, 4),
    (3, 114, 12, 4),
)
ABOUT_ATTR_INNER = bytes((7, 0, 7, 7, 7, 7, 7, 7, 0, 0, 0, 7, 7, 6, 6, 0, 0, 7))
EXPECTED_ABOUT_PAYLOAD_BYTES = sum(w * h for _x, _y, w, h in ABOUT_RECTS)
ABOUT_PAYLOAD_OFFSET = EXPECTED_UI_BYTES + RUNTIME_PIECE_BYTES
ZX_EXTRA_PIECE_OFFSET = ABOUT_PAYLOAD_OFFSET + EXPECTED_ABOUT_PAYLOAD_BYTES
NEXT_EXTRA_PIECE_OFFSET = ABOUT_PAYLOAD_OFFSET
EXPECTED_ZX_DAT_BYTES = EXPECTED_UI_BYTES + EXPECTED_PIECE_BYTES + EXPECTED_ABOUT_PAYLOAD_BYTES
EXPECTED_NEXT_DAT_BYTES = EXPECTED_UI_BYTES + EXPECTED_PIECE_BYTES
EXPECTED_UI_OFFSETS = {
    "expand_2x": 0,
    "font_lut": 16,
    "chat_icon_white": 26,
    "chat_icon_black": 32,
    "timer_ikkle_packed": 38,
    "font_packed": 166,
    "badge_pattern": 454,
    "conn_pattern": 462,
    "rank_digit_patterns": 470,
    "file_letter_patterns": 510,
    "psfc_piece_chars": 550,
    "title_msg": 556,
    "chat_msg": 567,
    "session_setup_msg": 572,
    "game_setup_msg": 589,
    "preflight_setup_msg": 600,
    "input_prompt_msg": 622,
    "white_turn_msg": 625,
    "black_turn_msg": 639,
    "white_check_msg": 653,
    "black_check_msg": 665,
    "menu_cursor_masks": 677,
    "tab_label_file": 701,
    "tab_label_discc": 706,
    "tab_label_reset": 712,
    "tab_label_flip": 718,
    "tab_label_theme": 723,
    "tab_label_about": 729,
    "moves_white_msg": 735,
    "moves_black_msg": 741,
    "banner_info_top_msg": 747,
    "board_theme_mark_inks": 781,
    "board_theme_light_attrs": 786,
    "board_theme_dark_attrs": 791,
    "version_banner_msg": 796,
    "piece_sprites_16x16": EXPECTED_UI_BYTES,
}


def parse_defb(text):
    data = bytearray()
    offsets = {}
    for raw in text.splitlines():
        line = raw.split(";", 1)[0].strip()
        label = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):$", line)
        if label:
            offsets[label.group(1)] = len(data)
            continue
        if not line.upper().startswith("DEFB"):
            continue
        body = line[4:].strip()
        for token in body.split(","):
            token = token.strip()
            if not token:
                continue
            if token.startswith('"') and token.endswith('"'):
                data.extend(token[1:-1].encode("ascii"))
            else:
                data.append(int(token, 0) & 0xFF)
    return bytes(data), offsets


def parse_screen_asset_equ(text):
    offsets = {}
    for raw in text.splitlines():
        line = raw.split(";", 1)[0].strip()
        match = re.match(
            r"^([A-Za-z_][A-Za-z0-9_]*)\s+EQU\s+NETCHESSZX_ASSET_BASE(?:\s+\+\s+([0-9]+))?$",
            line,
        )
        if match:
            offsets[match.group(1)] = int(match.group(2) or "0", 10)
    return offsets


def parse_loader_asset_size(text):
    match = re.search(r"(?m)^asset_load_size\s+EQU\s+([0-9]+)\s*$", text)
    if not match:
        raise SystemExit("asset_load_size not found in overlay loader")
    return int(match.group(1), 10)


def parse_loader_about_size(text):
    match = re.search(r"(?m)^about_board_size\s+EQU\s+([0-9]+)\s*$", text)
    if not match:
        raise SystemExit("about_board_size not found in overlay loader")
    return int(match.group(1), 10)


def build_about_payload(raw):
    if len(raw) != EXPECTED_ABOUT_BOARD_BYTES:
        raise ValueError(
            f"About asset has {len(raw)} bytes, expected {EXPECTED_ABOUT_BOARD_BYTES}"
        )

    pixels = raw[:ABOUT_PIXEL_BYTES]
    rebuilt = bytearray(ABOUT_PIXEL_BYTES)
    payload = bytearray()
    for left, top, width, height in ABOUT_RECTS:
        for row in range(top, top + height):
            start = row * ABOUT_BOARD_WIDTH + left
            chunk = pixels[start : start + width]
            payload.extend(chunk)
            rebuilt[start : start + width] = chunk

    frame = bytes((1,)) + (b"\xff" * 16) + bytes((0x80,))
    rebuilt[7 * ABOUT_BOARD_WIDTH : 8 * ABOUT_BOARD_WIDTH] = frame
    rebuilt[136 * ABOUT_BOARD_WIDTH : 137 * ABOUT_BOARD_WIDTH] = frame
    for row in range(8, 136):
        rebuilt[row * ABOUT_BOARD_WIDTH] = 1
        rebuilt[(row + 1) * ABOUT_BOARD_WIDTH - 1] = 0x80
    if bytes(rebuilt) != pixels:
        raise ValueError("About pixels exist outside the structural rectangles/frame")

    attrs = bytearray()
    for inner in ABOUT_ATTR_INNER:
        attrs.extend((7,))
        attrs.extend(bytes((inner,)) * 16)
        attrs.extend((7,))
    if bytes(attrs) != raw[ABOUT_PIXEL_BYTES:]:
        raise ValueError("About attributes no longer match the structural renderer")
    if len(payload) != EXPECTED_ABOUT_PAYLOAD_BYTES:
        raise AssertionError("bad structural About payload size")
    return bytes(payload)


def validate_offsets(label, got, expected):
    for name, offset in expected.items():
        if got.get(name) != offset:
            raise SystemExit(
                f"{label}: {name} offset got {got.get(name)}, expected {offset}"
            )


def block_from_label(text, label, end_label=None):
    start = re.search(rf"(?m)^{re.escape(label)}:\s*$", text)
    if not start:
        raise SystemExit(f"label not found: {label}")
    body = text[start.end() :]
    if end_label is not None:
        end = re.search(rf"(?m)^{re.escape(end_label)}:\s*$", body)
        if not end:
            raise SystemExit(f"end label not found: {end_label}")
        body = body[: end.start()]
    return body


def patch_slot(ui, offset, slot, text, label):
    data = text.encode("ascii") + b"\0"
    if len(data) > slot:
        raise SystemExit(f"{label}: '{text}' needs {len(data)} bytes, slot is {slot}")
    ui[offset : offset + slot] = data.ljust(slot, b"\0")


def main(argv):
    version = None
    is_next = False
    args = [argv[0]]
    it = iter(argv[1:])
    for arg in it:
        if arg == "--version":
            version = next(it, None)
            if version is None:
                raise SystemExit("--version requires a value")
        elif arg == "--next":
            is_next = True
        else:
            args.append(arg)
    argv = args
    if len(argv) != 7 or version is None:
        raise SystemExit(
            "usage: gen_assets.py <ui_assets.asm> <pieces.asm> "
            "<screen.asm> <overlay_loader.asm> <about_board.bin> <out.dat> "
            "--version <version> [--next]"
        )
    if re.fullmatch(
        r"[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-dev(?:[0-9]{3}|ESP))?", version
    ) is None:
        raise SystemExit(
            "version must contain major.minor[-devNNN|-devESP] or "
            "major.minor.patch[-devNNN|-devESP]"
        )

    ui_path = Path(argv[1])
    pieces_path = Path(argv[2])
    screen_path = Path(argv[3])
    loader_path = Path(argv[4])
    about_path = Path(argv[5])
    out_path = Path(argv[6])

    ui, ui_offsets = parse_defb(ui_path.read_text(encoding="ascii"))
    ui = bytearray(ui)
    if len(ui) != EXPECTED_UI_BYTES:
        raise SystemExit(
            f"{ui_path}: got {len(ui)} UI bytes, expected {EXPECTED_UI_BYTES}"
        )
    validate_offsets(
        str(ui_path),
        ui_offsets,
        {k: v for k, v in EXPECTED_UI_OFFSETS.items() if k != "piece_sprites_16x16"},
    )

    screen_offsets = parse_screen_asset_equ(screen_path.read_text(encoding="ascii"))
    validate_offsets(str(screen_path), screen_offsets, EXPECTED_UI_OFFSETS)

    if is_next:
        patch_slot(
            ui,
            EXPECTED_UI_OFFSETS["banner_info_top_msg"],
            BANNER_INFO_SLOT,
            NEXT_BANNER_INFO,
            "banner_info_top_msg",
        )
        for name, values in (
            ("board_theme_mark_inks", NEXT_BOARD_MARK_INKS),
            ("board_theme_light_attrs", NEXT_BOARD_LIGHT_ATTRS),
            ("board_theme_dark_attrs", NEXT_BOARD_DARK_ATTRS),
        ):
            off = EXPECTED_UI_OFFSETS[name]
            ui[off : off + len(values)] = bytes(values)
    banner_version = version if "-dev" in version else f"version {version}"
    patch_slot(
        ui,
        EXPECTED_UI_OFFSETS["version_banner_msg"],
        VERSION_SLOT,
        banner_version,
        "version_banner_msg",
    )

    pieces_text = pieces_path.read_text(encoding="ascii")
    pieces, _ = parse_defb(
        block_from_label(pieces_text, "netchesszx_piece_sprites_16x16")
    )
    if len(pieces) != EXPECTED_PIECE_BYTES:
        raise SystemExit(
            f"{pieces_path}: got {len(pieces)} piece bytes, expected {EXPECTED_PIECE_BYTES}"
        )

    runtime_pieces = pieces[:RUNTIME_PIECE_BYTES]
    extra_pieces = pieces[RUNTIME_PIECE_BYTES:]
    runtime_total = len(ui) + len(runtime_pieces)
    loader_text = loader_path.read_text(encoding="ascii")
    loader_size = parse_loader_asset_size(loader_text)
    if loader_size != runtime_total:
        raise SystemExit(
            f"{loader_path}: asset_load_size got {loader_size}, "
            f"expected runtime load {runtime_total}"
        )
    loader_about_size = parse_loader_about_size(loader_text)
    if loader_about_size == EXPECTED_ABOUT_PAYLOAD_BYTES:
        about_raw = about_path.read_bytes()
        try:
            about = build_about_payload(about_raw)
        except ValueError as exc:
            raise SystemExit(f"{about_path}: {exc}") from exc
    elif loader_about_size == 0:
        about_raw = b""
        about = b""
    else:
        raise SystemExit(
            f"{loader_path}: about_board_size got {loader_about_size}, "
            f"expected {EXPECTED_ABOUT_PAYLOAD_BYTES} or 0"
        )

    total = runtime_total + len(about) + len(extra_pieces)
    expected_total = EXPECTED_ZX_DAT_BYTES if about else EXPECTED_NEXT_DAT_BYTES
    if total != expected_total:
        raise AssertionError(f"bad DAT size {total}, expected {expected_total}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(ui + runtime_pieces + about + extra_pieces)
    print(
        f"[OK] {out_path}: {total} bytes "
        f"(About {len(about_raw)} -> {len(about)})"
    )


if __name__ == "__main__":
    main(sys.argv)
