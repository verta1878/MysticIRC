#!/usr/bin/env python3
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCREEN = ROOT / "asm" / "spectrum" / "screen.asm"
LOADER = ROOT / "asm" / "next" / "overlay_loader_next.asm"
GRAPHICS_BANK = ROOT / "asm" / "next" / "graphics_bank_next.asm"
GRAPHICS_LAYOUT = ROOT / "asm" / "next" / "graphics_bank_layout.asm"
GEN_ASSETS = ROOT / "tools" / "gen_assets.py"
BUILD_SPRITES = ROOT / "tools" / "build_next_piece_sprites.py"
SPRITE_PALETTE_BIN = ROOT / "assets" / "next" / "lichess_sprite_palette.bin"
MENU_CONFIG = ROOT / "asm" / "overlay" / "menu_config" / "entry_menu_config.asm"


def block(text: str, start: str, end: str) -> str:
    return text[text.index(start) : text.index(end, text.index(start))]


class NextBoardThemeRgb333Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.screen = SCREEN.read_text(encoding="utf-8")
        self.loader = LOADER.read_text(encoding="utf-8")
        self.graphics_bank = GRAPHICS_BANK.read_text(encoding="utf-8")
        self.graphics_layout = GRAPHICS_LAYOUT.read_text(encoding="utf-8")
        self.gen_assets = GEN_ASSETS.read_text(encoding="utf-8")
        self.build_sprites = BUILD_SPRITES.read_text(encoding="utf-8")
        self.sprite_palette_bin = SPRITE_PALETTE_BIN.read_bytes()
        self.menu_config = MENU_CONFIG.read_text(encoding="utf-8")

    def test_exact_rgb333_pairs_and_private_attributes(self) -> None:
        self.assertIn("NEXT_BOARD_COORD_LINE_ATTR EQU 0x81", self.screen)
        self.assertIn("NEXT_BOARD_COORD_SELECTED_ATTR EQU 0x8a", self.screen)
        table = block(
            self.screen,
            "next_board_coord_rgb333:",
            "next_board_coord_rgb333_end:",
        )
        values = [
            int(value, 16)
            for value in re.findall(r"0x([0-9a-fA-F]{2})", table)
        ]
        self.assertEqual(
            values,
            [
                0xBB, 0x00, 0x4E, 0x01,
                0xFF, 0x00, 0x95, 0x01,
                0xFA, 0x01, 0xB1, 0x01,
                0xD1, 0x00, 0x88, 0x01,
            ],
        )

        frame = block(
            self.screen,
            "restore_board_frame_attrs:",
            "draw_one_board_square:",
        )
        self.assertIn("call board_light_line_attr", frame)
        self.assertIn("ld a, NEXT_BOARD_COORD_LINE_ATTR", frame)

    def test_palette_is_live_before_private_attributes_are_painted(self) -> None:
        initial = block(
            self.screen,
            "_spectrum_render_board:",
            "_spectrum_render_board_area:",
        )
        self.assertLess(
            initial.index("call next_board_coord_palette_sync"),
            initial.index("call draw_board_coords"),
        )
        apply_theme = block(
            self.screen,
            "_netchesszx_board_theme_apply:",
            "compute_screen_base:",
        )
        self.assertLess(
            apply_theme.index("call next_board_coord_palette_sync"),
            apply_theme.index("call restore_board_frame_attrs"),
        )
        self.assertIn("and 0xf7", apply_theme)
        self.assertIn("or 0x08", apply_theme)

    def test_standard_ula_groups_and_menu_tables_stay_on_main_contract(self) -> None:
        self.assertIn(
            "NEXT_BOARD_LIGHT_ATTRS = [0x78, 0x6F, 0x66, 0x77, 0x37]",
            self.gen_assets,
        )
        self.assertIn(
            "NEXT_BOARD_DARK_ATTRS = [0x07, 0x4D, 0x20, 0x56, 0x52]",
            self.gen_assets,
        )
        table = block(
            self.build_sprites,
            "STANDARD_ULA_PALETTE = bytes((",
            "))",
        )
        values = [
            int(value, 16)
            for value in re.findall(r"0x([0-9a-fA-F]{2})", table)
        ]
        self.assertEqual(
            values,
            [
                0x00,0x00, 0x02,0x01, 0xA0,0x00, 0xA2,0x01,
                0x14,0x00, 0x16,0x01, 0xB4,0x00, 0xB6,0x01,
                0x00,0x00, 0x02,0x01, 0xA0,0x00, 0xA2,0x01,
                0x14,0x00, 0x16,0x01, 0xB4,0x00, 0xB6,0x01,
                0x00,0x00, 0x03,0x01, 0xE0,0x00, 0xE3,0x01,
                0x1C,0x00, 0x1F,0x01, 0xFC,0x00, 0xFF,0x01,
                0x00,0x00, 0x03,0x01, 0xE0,0x00, 0xE3,0x01,
                0x1C,0x00, 0x1F,0x01, 0xFC,0x00, 0xFF,0x01,
                *([0x00, 0x00] * 16),
                0xD1,0x00, 0x88,0x01,
                *([0x00, 0x00] * 6),
                0xD1,0x00, 0x88,0x01,
            ],
        )
        self.assertEqual(len(self.sprite_palette_bin), 160 * 2 + len(values))
        self.assertEqual(self.sprite_palette_bin[-len(values) :], bytes(values))
        self.assertIn("ld e, 192", self.graphics_bank)
        self.assertRegex(
            self.graphics_layout,
            r"(?m)^next_ula_standard_palette_size\s+EQU 116$",
        )
        self.assertIn("PUBLIC nextreg_read", self.loader)
        self.assertIn("PUBLIC nextreg_write", self.loader)

    def test_next_menu_swatches_preserve_ula_palette_groups(self) -> None:
        swatch = block(
            self.menu_config,
            "menu_config_board_swatch:",
            "menu_config_board_swatch_store:",
        )
        self.assertRegex(
            swatch,
            r"IFDEF NETCHESSZX_NEXT\s+;[^\n]*\s+ELSE\s+or 0x40\s+ENDIF",
        )
        self.assertRegex(
            swatch,
            r"IFDEF NETCHESSZX_NEXT\s+;[^\n]*\s+ELSE\s+or 0x80\s+ENDIF",
        )
        self.assertIn(
            "cp 0x37\n    jr nz, menu_config_board_swatch_attr_ready\n"
            "    ld a, 0xc1",
            self.menu_config,
        )
        paint = block(
            self.menu_config,
            "_menu_config_paint_attrs_ovl_entry:",
            "ld hl, _setup_choice + 4",
        )
        self.assertIn("ld a, 0x68", paint)
        self.assertIn("or 0x08", paint)
        self.assertIn(
            'DEFB 16, "BOARD  ", 127, "   ", 127, "   ", 127, "   ", '
            '127, "   ", 127, 0',
            self.menu_config,
        )


if __name__ == "__main__":
    unittest.main()
