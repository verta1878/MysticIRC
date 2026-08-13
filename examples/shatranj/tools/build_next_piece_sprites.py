#!/usr/bin/env python3
"""Build ZX Spectrum Next sprite patterns from selected Lichess pieces and boards."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw


def image_pixels(image: Image.Image):
    return (
        image.get_flattened_data()
        if hasattr(image, "get_flattened_data")
        else image.getdata()
    )


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "assets/lichess"
SVG_ROOT = ASSET_ROOT / "piece"
BOARD_ROOT = ASSET_ROOT / "board"
PC_BOARD_ROOT = ROOT / "assets/pc-client/boards"
SELECTED = ASSET_ROOT / "selected_next_sets.json"
SELECTED_BOARDS = ASSET_ROOT / "selected_next_boards.json"
OUT_DIR = ROOT / "assets/next"
OUT_BIN = OUT_DIR / "lichess_piece_sprites.bin"
OUT_PALETTE = OUT_DIR / "lichess_sprite_palette.asm"
OUT_PALETTE_BIN = OUT_DIR / "lichess_sprite_palette.bin"
OUT_META = OUT_DIR / "lichess_piece_sprites.json"
PIECES = ["K", "Q", "R", "B", "N", "P"]
BOARD_EXTS = (".png", ".jpg", ".jpeg")
SPRITE_SIZE = 16
PIECE_DRAW_SIZE = 14
# ponytail: 64 is the largest size Edge headless renders these mm-unit SVGs
# correctly at (112 clips them); bump only with a visual check.
RENDER_SIZE = 64
ALPHA_THRESHOLD = 128
OUTLINE_LUMA = 96
OUTLINE_RGB = (216, 216, 216)
TRANSPARENT = 0xE3
PALETTE_LIMIT = 160
STANDARD_ULA_PALETTE = bytes((
    0x00,0x00, 0x02,0x01, 0xA0,0x00, 0xA2,0x01,
    0x14,0x00, 0x16,0x01, 0xB4,0x00, 0xB6,0x01,
    0x00,0x00, 0x02,0x01, 0xA0,0x00, 0xA2,0x01,
    0x14,0x00, 0x16,0x01, 0xB4,0x00, 0xB6,0x01,
    0x00,0x00, 0x03,0x01, 0xE0,0x00, 0xE3,0x01,
    0x1C,0x00, 0x1F,0x01, 0xFC,0x00, 0xFF,0x01,
    0x00,0x00, 0x03,0x01, 0xE0,0x00, 0xE3,0x01,
    0x1C,0x00, 0x1F,0x01, 0xFC,0x00, 0xFF,0x01,
    0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00,
    0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00,
    0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00,
    0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00,
    # ULA+ group 3: wood preview, normal and focused ink/paper pairs.
    0xD1,0x00, 0x88,0x01,
    0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00,
    0x00,0x00, 0x00,0x00,
    0xD1,0x00, 0x88,0x01,
))
PIPELINE_VERSION = 2
PIECE_SETS = 3
PIECES_PER_SET = 12
BOARD_THEMES = 5
BOARD_TILES_PER_THEME = 2
MARKER_PATTERNS = 4
PIECE_PATTERN_BASE = 0
BOARD_PATTERN_BASE = PIECES_PER_SET
MARKER_PATTERN_BASE = BOARD_PATTERN_BASE + BOARD_THEMES * BOARD_TILES_PER_THEME
EDGE_CANDIDATES = [
    Path(os.environ.get("EDGE", "")) if os.environ.get("EDGE") else None,
    Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
    Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
    Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
]
MARKER_RGB = [
    (255, 238, 80),
    (255, 255, 255),
    (40, 240, 255),
    (255, 90, 230),
]


def find_edge() -> Path:
    for candidate in EDGE_CANDIDATES:
        if candidate and candidate.exists():
            return candidate
    raise SystemExit("Edge/Chrome headless not found; set EDGE=/path/to/browser")


def file_uri(path: Path) -> str:
    return path.resolve().as_uri()


def render_svg(edge: Path, svg: Path, tmpdir: Path) -> Image.Image:
    out = tmpdir / (svg.parent.name + "_" + svg.name + ".png")
    if out.exists():
        out.unlink()
    # Pixel-art sets (shape-rendering="crispEdges", 16x16 viewBox) are drawn
    # at native size so each SVG pixel maps 1:1 onto the sprite; smooth sets
    # are supersampled and downscaled to PIECE_DRAW_SIZE.
    pixel_art = "crispEdges" in svg.read_text(encoding="utf-8", errors="replace")
    render_size = SPRITE_SIZE if pixel_art else RENDER_SIZE
    # Wrapper HTML pins the render to the window size; bare SVGs with a
    # physical width/height (e.g. merida's 50mm) render oversized and get
    # cropped by the screenshot window.
    page = tmpdir / (svg.parent.name + "_" + svg.name + ".html")
    page.write_text(
        "<!doctype html><style>*{margin:0;padding:0}img{display:block;"
        f"width:{render_size}px;height:{render_size}px}}</style>"
        f'<img src="{file_uri(svg)}">',
        encoding="utf-8",
    )
    profile = tmpdir / "browser-profile"
    cmd = [
        str(edge),
        "--headless=new",
        "--disable-gpu",
        "--disable-breakpad",
        "--disable-crash-reporter",
        "--no-first-run",
        "--no-sandbox",
        f"--user-data-dir={profile}",
        "--default-background-color=00000000",
        f"--screenshot={out}",
        f"--window-size={render_size},{render_size}",
        file_uri(page),
    ]
    proc = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline = time.monotonic() + 5.0
    while not out.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    if not out.exists():
        raise SystemExit(f"browser did not render {svg} (exit {proc.returncode})")
    image = Image.open(out).convert("RGBA")
    if pixel_art:
        sprite = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
        sprite.paste(image.crop((0, 0, SPRITE_SIZE, SPRITE_SIZE)))
        return outline_dark_piece(sprite)
    return outline_dark_piece(fit_piece_sprite(image))


def fit_piece_sprite(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
    crop = image.crop(bbox)
    scale = min(PIECE_DRAW_SIZE / crop.width, PIECE_DRAW_SIZE / crop.height)
    size = (
        max(1, round(crop.width * scale)),
        max(1, round(crop.height * scale)),
    )
    sprite = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
    resized = crop.resize(size, Image.Resampling.LANCZOS)
    sprite.paste(resized, ((SPRITE_SIZE - size[0]) // 2, (SPRITE_SIZE - size[1]) // 2))
    return sprite


def outline_dark_piece(sprite: Image.Image) -> Image.Image:
    """Give dark pieces a 1px light outline so they stay visible on dark squares."""
    pix = sprite.load()
    opaque = []
    luma_sum = 0
    for y in range(SPRITE_SIZE):
        for x in range(SPRITE_SIZE):
            r, g, b, a = pix[x, y]
            if a >= ALPHA_THRESHOLD:
                opaque.append((x, y))
                luma_sum += (r * 299 + g * 587 + b * 114) // 1000
    if not opaque or luma_sum // len(opaque) >= OUTLINE_LUMA:
        return sprite
    for x, y in opaque:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < SPRITE_SIZE and 0 <= ny < SPRITE_SIZE:
                if pix[nx, ny][3] < ALPHA_THRESHOLD:
                    pix[nx, ny] = OUTLINE_RGB + (255,)
    return sprite


def load_selected() -> list[str]:
    data = json.loads(SELECTED.read_text(encoding="utf-8"))
    sets = list(data.get("selected", []))
    if len(sets) != PIECE_SETS:
        raise SystemExit(f"{SELECTED}: expected exactly {PIECE_SETS} selected sets")
    for name in sets:
        if not (SVG_ROOT / name).is_dir():
            raise SystemExit(f"missing set dir: {name}")
    return sets


def load_selected_boards() -> list[str]:
    data = json.loads(SELECTED_BOARDS.read_text(encoding="utf-8"))
    boards = list(data.get("selected", []))
    if len(boards) != BOARD_THEMES:
        raise SystemExit(
            f"{SELECTED_BOARDS}: expected exactly {BOARD_THEMES} selected boards"
        )
    for name in boards:
        if name != "bw":
            board_path(name)
    return boards


def board_path(name: str) -> Path:
    for root in (BOARD_ROOT, PC_BOARD_ROOT):
        for ext in BOARD_EXTS:
            path = root / f"{name}{ext}"
            if path.exists():
                return path
    raise SystemExit(f"missing board image: {name}")


def collect_piece_images(
    edge: Path, sets: list[str]
) -> dict[tuple[str, str], Image.Image]:
    images: dict[tuple[str, str], Image.Image] = {}
    with tempfile.TemporaryDirectory(prefix="netchesszx-next-pieces-") as tmp:
        tmpdir = Path(tmp)
        for set_name in sets:
            for side in ("w", "b"):
                for piece in PIECES:
                    svg = SVG_ROOT / set_name / f"{side}{piece}.svg"
                    if not svg.exists():
                        raise SystemExit(f"missing SVG: {svg}")
                    images[(set_name, side + piece)] = render_svg(edge, svg, tmpdir)
    return images


def collect_board_tiles(boards: list[str]) -> dict[tuple[str, int], Image.Image]:
    tiles: dict[tuple[str, int], Image.Image] = {}
    for name in boards:
        if name == "bw":
            tiles[(name, 0)] = Image.new(
                "RGBA", (SPRITE_SIZE, SPRITE_SIZE), (255, 255, 255, 255)
            )
            tiles[(name, 1)] = Image.new(
                "RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 255)
            )
            continue
        image = Image.open(board_path(name)).convert("RGBA")
        side = min(image.size)
        left = (image.width - side) // 2
        top = (image.height - side) // 2
        board = image.crop((left, top, left + side, top + side))
        square = side // 8
        for parity, col in enumerate((0, 1)):
            tile = board.crop((col * square, 0, (col + 1) * square, square))
            tiles[(name, parity)] = tile.resize(
                (SPRITE_SIZE, SPRITE_SIZE), Image.Resampling.LANCZOS
            )
    return tiles


def build_marker_patterns() -> list[Image.Image]:
    images: list[Image.Image] = []
    for kind in range(MARKER_PATTERNS):
        image = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        if kind == 0:
            draw.ellipse((5, 5, 10, 10), fill=MARKER_RGB[0] + (255,))
            draw.ellipse((7, 7, 8, 8), fill=MARKER_RGB[2] + (255,))
        elif kind == 1:
            draw.rectangle((0, 0, 15, 15), outline=MARKER_RGB[1] + (255,))
            draw.rectangle((1, 1, 14, 14), outline=MARKER_RGB[2] + (255,))
        elif kind == 2:
            draw.rectangle((0, 0, 15, 15), outline=MARKER_RGB[0] + (255,))
            draw.rectangle((1, 1, 14, 14), outline=MARKER_RGB[1] + (255,))
            draw.ellipse((6, 6, 9, 9), fill=MARKER_RGB[0] + (255,))
        else:
            draw.rectangle((0, 0, 15, 15), outline=MARKER_RGB[3] + (255,))
            draw.rectangle((1, 1, 14, 14), outline=MARKER_RGB[0] + (255,))
            draw.rectangle((2, 2, 13, 13), outline=MARKER_RGB[1] + (255,))
        images.append(image)
    return images


def visible_pixels(images) -> list[tuple[int, int, int]]:
    pixels: list[tuple[int, int, int]] = []
    for image in images:
        for r, g, b, a in image_pixels(image):
            if a >= ALPHA_THRESHOLD:
                pixels.append((r, g, b))
    if not pixels:
        raise SystemExit("no visible pixels in rendered sprites")
    return pixels


def build_palette(pixels: list[tuple[int, int, int]]) -> list[tuple[int, int, int]]:
    src = Image.new("RGB", (len(pixels), 1))
    src.putdata(pixels)
    quantized = src.quantize(
        colors=min(PALETTE_LIMIT, len(set(pixels))), method=Image.Quantize.MEDIANCUT
    )
    raw = quantized.getpalette() or []
    count = max(image_pixels(quantized)) + 1
    return [(raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]) for i in range(count)]


def nearest_index(
    rgb: tuple[int, int, int], palette: list[tuple[int, int, int]]
) -> int:
    r, g, b = rgb
    best_i = 0
    best_d = 1 << 30
    for i, (pr, pg, pb) in enumerate(palette):
        d = (r - pr) * (r - pr) + (g - pg) * (g - pg) + (b - pb) * (b - pb)
        if d < best_d:
            best_i = i
            best_d = d
    return best_i


def encode_pattern(image: Image.Image, palette: list[tuple[int, int, int]]) -> bytes:
    out = bytearray()
    for r, g, b, a in image_pixels(image):
        out.append(
            TRANSPARENT if a < ALPHA_THRESHOLD else nearest_index((r, g, b), palette)
        )
    if len(out) != SPRITE_SIZE * SPRITE_SIZE:
        raise SystemExit("bad sprite size")
    return bytes(out)


def rgb333_pair(rgb: tuple[int, int, int]) -> tuple[int, int]:
    """9-bit palette entry as the two-byte sequence nextreg 0x44 expects."""
    r, g, b = (round(c * 7 / 255) for c in rgb)
    return ((r << 5) | (g << 2) | (b >> 1), b & 1)


def cache_valid(sets: list[str], boards: list[str]) -> bool:
    if (
        not OUT_BIN.exists()
        or not OUT_PALETTE.exists()
        or not OUT_PALETTE_BIN.exists()
        or not OUT_META.exists()
    ):
        return False
    try:
        meta = json.loads(OUT_META.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    expected = (
        (
            PIECE_SETS * PIECES_PER_SET
            + BOARD_THEMES * BOARD_TILES_PER_THEME
            + MARKER_PATTERNS
        )
        * SPRITE_SIZE
        * SPRITE_SIZE
    )
    return (
        meta.get("pipeline") == PIPELINE_VERSION
        and meta.get("sets") == sets
        and meta.get("boards") == boards
        and meta.get("total_bytes") == expected
        and OUT_BIN.stat().st_size == expected
        and OUT_PALETTE_BIN.stat().st_size
        == PALETTE_LIMIT * 2 + len(STANDARD_ULA_PALETTE)
    )


def touch_outputs() -> None:
    now = time.time()
    for path in (OUT_BIN, OUT_PALETTE, OUT_PALETTE_BIN, OUT_META):
        os.utime(path, (now, now))


def emit_palette(
    palette: list[tuple[int, int, int]], sets: list[str], boards: list[str]
) -> None:
    lines = [
        "; ZX Spectrum Next sprite palette for selected Lichess pieces and boards.",
        "; Generated by tools/build_next_piece_sprites.py.",
        "; 9-bit entries: two bytes per colour, ready for nextreg 0x44 writes.",
        f"; Piece sets: {', '.join(sets)}.",
        f"; Board themes: {', '.join(boards)}.",
        "",
        "PUBLIC next_sprite_palette",
        "PUBLIC next_sprite_palette_size",
        f"next_sprite_palette_size EQU {len(palette)}",
        "next_sprite_palette:",
    ]
    values = [byte for rgb in palette for byte in rgb333_pair(rgb)]
    for i in range(0, len(values), 16):
        lines.append("    DEFB " + ", ".join(f"0x{v:02x}" for v in values[i : i + 16]))
    OUT_PALETTE.write_text("\n".join(lines) + "\n", encoding="ascii")
    # Raw bytes for the .nex bundle: the palette lives there now instead of in
    # resident RAM. Pad to the fixed PALETTE_LIMIT the loader always uploads
    # (extra entries are black and address unused sprite-palette slots).
    raw = bytes(values)[: PALETTE_LIMIT * 2].ljust(PALETTE_LIMIT * 2, b"\x00")
    OUT_PALETTE_BIN.write_bytes(raw + STANDARD_ULA_PALETTE)


def main() -> int:
    sets = load_selected()
    boards = load_selected_boards()
    if cache_valid(sets, boards):
        touch_outputs()
        print(f"[OK] {OUT_BIN}: cached {OUT_BIN.stat().st_size} bytes")
        return 0
    edge = find_edge()
    piece_images = collect_piece_images(edge, sets)
    board_tiles = collect_board_tiles(boards)
    marker_images = build_marker_patterns()
    palette = build_palette(
        visible_pixels(
            list(piece_images.values()) + list(board_tiles.values()) + marker_images
        )
    )
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    data = bytearray()
    for set_name in sets:
        for side in ("w", "b"):
            for piece in PIECES:
                data.extend(
                    encode_pattern(piece_images[(set_name, side + piece)], palette)
                )
    for board in boards:
        for parity in (0, 1):
            data.extend(encode_pattern(board_tiles[(board, parity)], palette))
    for image in marker_images:
        data.extend(encode_pattern(image, palette))
    OUT_BIN.write_bytes(data)
    emit_palette(palette, sets, boards)
    OUT_META.write_text(
        json.dumps(
            {
                "pipeline": PIPELINE_VERSION,
                "sets": sets,
                "boards": boards,
                "pieces_per_set": PIECES_PER_SET,
                "bytes_per_pattern": SPRITE_SIZE * SPRITE_SIZE,
                "piece_draw_size": PIECE_DRAW_SIZE,
                "bytes_per_set": PIECES_PER_SET * SPRITE_SIZE * SPRITE_SIZE,
                "piece_sets": PIECE_SETS,
                "board_pattern_base": BOARD_PATTERN_BASE,
                "board_patterns": BOARD_THEMES * BOARD_TILES_PER_THEME,
                "marker_pattern_base": MARKER_PATTERN_BASE,
                "marker_patterns": MARKER_PATTERNS,
                "total_bytes": len(data),
                "transparent_index": TRANSPARENT,
                "palette_entries": len(palette),
                "browser": str(edge),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"[OK] {OUT_BIN}: {len(data)} bytes; palette {len(palette)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
