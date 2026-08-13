#!/usr/bin/env python3
"""Verify the runtime-asset / MQTT buffer layout against the linker map.

Runtime assets load at 0x6000 and end at piece_sprites_16x16 + 384. The MQTT
stream buffer, persistent packet scratch, Next staging, and overlay-only scratch
must meet at guarded boundaries below the overlay slot at 0x6800. ABOUT reuses
the upper work area only while its own overlay is loaded.
"""

import argparse
from pathlib import Path
import re
import sys

PIECE_SPRITES_SIZE = 12 * 32
OVERLAY_SLOT = 0x6800
MQTT_STREAM_MAX = 223
MQTT_PACKET_MAX = 160
NEXT_SPRITE_STAGE_BYTES = 256
OVERLAY_SCRATCH_ADDR = 0x672B
RULES_TMP_SIZE = 64
MIN_SP_GAP = 512
MIN_SP_GAP_WARN = 768


def parse_symbol(text, name):
    m = re.search(r"^%s\s*=\s*\$([0-9A-Fa-f]+)" % re.escape(name), text, re.M)
    if not m:
        raise SystemExit("[ERR] symbol %s not found in map" % name)
    return int(m.group(1), 16)


def parse_first_symbol(text, names):
    for name in names:
        m = re.search(r"^%s\s*=\s*\$([0-9A-Fa-f]+)" % re.escape(name),
                      text, re.M)
        if m:
            return int(m.group(1), 16)
    raise SystemExit("[ERR] none of symbols %s found in map" % ", ".join(names))


def parse_const(path, name):
    text = path.read_text(encoding="utf-8", errors="replace")
    m = re.search(
        r"^(?:#define\s+)?%s\s+(?:EQU\s+)?(?:0x([0-9A-Fa-f]+)|([0-9]+))u?"
        % re.escape(name),
        text,
        re.M,
    )
    if not m:
        raise SystemExit("[ERR] %s not found in %s" % (name, path))
    return int(m.group(1), 16) if m.group(1) else int(m.group(2), 10)


def assert_no_overlap(label, start, size, other_label, other_start, other_size):
    end = start + size
    other_end = other_start + other_size
    if start < other_end and other_start < end:
        raise SystemExit(
            "[ERR] %s 0x%04x..0x%04x overlaps %s 0x%04x..0x%04x"
            % (label, start, end - 1, other_label, other_start, other_end - 1)
        )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", required=True)
    args = ap.parse_args()

    with open(args.map, "r", encoding="utf-8", errors="replace") as fh:
        text = fh.read()

    sprites = parse_symbol(text, "piece_sprites_16x16")
    assets_end = sprites + PIECE_SPRITES_SIZE
    stream = parse_symbol(text, "_mqtt_stream")
    packet = parse_const(Path("src/spectrum/transport/mqtt_min.h"),
                         "SPECTRUM_MQTT_SCRATCH_BASE")
    about_path = Path("asm/overlay/about/entry_about.asm")
    about = parse_const(about_path, "about_input")
    about_size = parse_const(about_path, "about_input_size")
    lowram_path = Path("src/spectrum/lowram_map.h")
    lowram_scratch = parse_const(
        lowram_path, "NETCHESSZX_LOWRAM_OVERLAY_SCRATCH_ADDR")
    overlay_scratch = parse_symbol(text, "_overlay_scratch_base")
    overlay_slot = parse_symbol(text, "_overlay_code_slot")
    overlay_scratch_size = parse_const(
        lowram_path, "NETCHESSZX_LOWRAM_OVERLAY_SCRATCH_SIZE")
    mqtt_overlay_scratch = parse_const(
        Path("asm/overlay/mqtt_connect/entry_mqtt_connect.asm"),
        "mqtt_packet_ovl")
    rules_path = Path("asm/overlay/rules/rules_stub.asm")
    rules_tmp = parse_const(rules_path, "r_tmp")
    rules_tmp_size = parse_const(
        Path("asm/overlay/rules/rules_stub.asm"), "rules_tmp_size")

    if stream < assets_end:
        raise SystemExit(
            "[ERR] mqtt_stream at 0x%04x overlaps runtime assets ending at "
            "0x%04x (piece sprites corrupt under MQTT). Raise "
            "SPECTRUM_MQTT_RUNTIME_ASSETS_END in mqtt_min.h." % (stream, assets_end)
        )
    if assets_end > overlay_slot:
        raise SystemExit(
            "[ERR] runtime assets end 0x%04x beyond overlay slot 0x%04x"
            % (assets_end, OVERLAY_SLOT)
        )
    assert_no_overlap("about_work", about, about_size,
                      "mqtt_stream", stream, MQTT_STREAM_MAX)
    assert_no_overlap("about_work", about, about_size,
                      "MQTT packet scratch", packet, MQTT_PACKET_MAX)
    if about + about_size > overlay_slot:
        raise SystemExit(
            "[ERR] about_work 0x%04x..0x%04x reaches overlay slot"
            % (about, about + about_size - 1)
        )
    if overlay_slot != OVERLAY_SLOT:
        raise SystemExit(
            "[ERR] linked overlay slot 0x%04x != fixed 0x%04x"
            % (overlay_slot, OVERLAY_SLOT)
        )
    if (overlay_scratch != OVERLAY_SCRATCH_ADDR or
            lowram_scratch != overlay_scratch or
            mqtt_overlay_scratch != overlay_scratch or
            rules_tmp != overlay_scratch):
        raise SystemExit(
            "[ERR] overlay scratch mismatch: map 0x%04x, header 0x%04x, "
            "MQTT 0x%04x, rules 0x%04x, fixed 0x%04x"
            % (overlay_scratch, lowram_scratch, mqtt_overlay_scratch,
               rules_tmp, OVERLAY_SCRATCH_ADDR)
        )
    if overlay_scratch_size != MQTT_PACKET_MAX:
        raise SystemExit(
            "[ERR] overlay scratch size %d != MQTT packet size %d"
            % (overlay_scratch_size, MQTT_PACKET_MAX)
        )
    if rules_tmp_size != RULES_TMP_SIZE or rules_tmp_size > overlay_scratch_size:
        raise SystemExit(
            "[ERR] rules scratch size %d invalid for %d-byte overlay scratch"
            % (rules_tmp_size, overlay_scratch_size)
        )
    overlay_scratch_end = overlay_scratch + overlay_scratch_size
    if overlay_scratch_end > overlay_slot:
        raise SystemExit(
            "[ERR] overlay scratch 0x%04x..0x%04x reaches overlay slot"
            % (overlay_scratch, overlay_scratch_end - 1)
        )
    if not (about <= overlay_scratch and
            overlay_scratch_end <= about + about_size):
        raise SystemExit(
            "[ERR] time-disjoint ABOUT work no longer contains overlay scratch"
        )

    next_layout = Path("asm/next/graphics_bank_layout.asm")
    if next_layout.exists():
        stage = parse_const(next_layout, "next_sprite_stage")
        stage_match = re.search(
            r"^next_sprite_stage\s*=\s*\$([0-9A-Fa-f]+)", text, re.M)
        if stage_match:
            linked_stage = int(stage_match.group(1), 16)
            if linked_stage != stage:
                raise SystemExit(
                    "[ERR] linked/source Next sprite stage mismatch"
                )
            stage = linked_stage
        assert_no_overlap("next_sprite_stage", stage, NEXT_SPRITE_STAGE_BYTES,
                          "mqtt_stream", stream, MQTT_STREAM_MAX)
        assert_no_overlap("next_sprite_stage", stage, NEXT_SPRITE_STAGE_BYTES,
                          "MQTT packet scratch", packet, MQTT_PACKET_MAX)
        if packet + MQTT_PACKET_MAX != stage:
            raise SystemExit(
                "[ERR] MQTT packet scratch must end at Next sprite stage"
            )
        if stage + NEXT_SPRITE_STAGE_BYTES != overlay_scratch:
            raise SystemExit(
                "[ERR] Next sprite stage must end at overlay scratch 0x%04x"
                % overlay_scratch
            )
        if stage + NEXT_SPRITE_STAGE_BYTES > overlay_slot:
            raise SystemExit(
                "[ERR] next_sprite_stage 0x%04x..0x%04x reaches overlay slot"
                % (stage, stage + NEXT_SPRITE_STAGE_BYTES - 1)
            )
    bss_end = parse_first_symbol(text,
                                 ("__BSS_END_tail", "__BSS_END", "__bss_end"))
    stack_top = parse_first_symbol(text,
                                  ("__register_sp", "TAR__register_sp"))
    stack_gap = stack_top - bss_end
    if stack_gap < MIN_SP_GAP:
        raise SystemExit(
            "[ERR] SP 0x%04x minus BSS_END 0x%04x leaves %d bytes, "
            "below %d byte floor"
            % (stack_top, bss_end, stack_gap, MIN_SP_GAP)
        )
    if stack_gap < MIN_SP_GAP_WARN:
        print(
            "[WARN] SP 0x%04x minus BSS_END 0x%04x leaves %d bytes, "
            "below %d byte warning"
            % (stack_top, bss_end, stack_gap, MIN_SP_GAP_WARN)
        )
    print("[OK] SP gap hard floor: %d >= %d bytes"
          % (stack_gap, MIN_SP_GAP))
    print(
        "[OK] lowmem layout: assets end 0x%04x <= mqtt_stream 0x%04x"
        % (assets_end, stream)
    )
    print(
        "[OK] linked overlay scratch: 0x%04x..0x%04x; header/slot match"
        % (overlay_scratch, overlay_scratch_end - 1)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
