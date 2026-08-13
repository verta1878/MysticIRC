#!/usr/bin/env python3
"""Generate and compare Shatranj size reports."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True


ZX_ORG = 28672
MIN_SP_GAP = 512
MIN_SP_GAP_WARN = 768
STACK_GUARD = 0xFE00  # retained for report compat; hard floor uses SP gap


def parse_map(path: Path) -> dict[str, int]:
    symbols: dict[str, int] = {}
    pattern = re.compile(r"^(\w+)\s+=\s+\$([0-9A-Fa-f]+)\s+;")
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = pattern.match(line)
            if match:
                symbols[match.group(1)] = int(match.group(2), 16)
    return symbols


def hex_addr(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value:04X}"


def file_size(path: Path) -> int | None:
    if not path.exists():
        return None
    return path.stat().st_size


def read_overlay_sizes(path: Path | None) -> dict[str, int]:
    if path is None or not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {str(key): int(value) for key, value in data.items()}


def make_report(args: argparse.Namespace) -> dict[str, object]:
    symbols = parse_map(args.map)
    code_full = file_size(args.code_bin)
    data_tail = symbols.get("__data_compiler_tail")
    resident_bytes = data_tail - args.org if data_tail is not None else None
    bss_head = symbols.get("__BSS_head")
    bss_end = symbols.get("__BSS_END_tail")
    bss_bytes = (
        bss_end - bss_head if bss_head is not None and bss_end is not None else None
    )
    register_sp = symbols.get("__register_sp", symbols.get("TAR__register_sp"))

    artifacts = {
        "code_bin": code_full,
        "tap": file_size(args.tap),
        "ovl": file_size(args.ovl),
        "dat": file_size(args.dat),
    }
    overlay_sizes = read_overlay_sizes(args.overlay_sizes)

    report: dict[str, object] = {
        "version": 1,
        "origin": args.org,
        "markers": {
            name: hex_addr(symbols.get(name))
            for name in [
                "__CODE_head",
                "__CODE_tail",
                "__DATA_head",
                "__data_compiler_tail",
                "__BSS_head",
                "__BSS_END_tail",
                "_overlay_code_slot",
                "__register_sp",
                "TAR__register_sp",
            ]
            if name in symbols
        },
        "artifacts": artifacts,
        "code": {
            "full_bytes": code_full,
            "resident_bytes": resident_bytes,
            "trimmed_bytes": resident_bytes,
            "bss_trim_saved_bytes": (code_full - resident_bytes)
            if code_full is not None and resident_bytes is not None
            else None,
        },
        "memory": {
            "bss_head": hex_addr(bss_head),
            "bss_bytes": bss_bytes,
            "ram_end": hex_addr(bss_end),
            "bss_end": hex_addr(bss_end),
            "stack_guard": hex_addr(STACK_GUARD),
            "stack_guard_gap_bytes": (STACK_GUARD - bss_end)
            if bss_end is not None
            else None,
            "register_sp": hex_addr(register_sp),
            "register_sp_gap_bytes": (register_sp - bss_end)
            if register_sp is not None and bss_end is not None
            else None,
        },
        "overlays": overlay_sizes,
    }
    return report


def write_json(path: Path, data: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(data, indent=2, sort_keys=True) + "\n")


def metric(report: dict[str, object], path: tuple[str, ...]) -> int | None:
    current: object = report
    for part in path:
        if not isinstance(current, dict):
            return None
        current = current.get(part)
    if isinstance(current, int):
        return current
    if isinstance(current, str) and current.startswith("0x"):
        return int(current, 16)
    return None


def metric_first(
    report: dict[str, object], paths: tuple[tuple[str, ...], ...]
) -> int | None:
    for path in paths:
        value = metric(report, path)
        if value is not None:
            return value
    return None


def format_value(value: int, style: str) -> str:
    if style == "addr":
        return f"0x{value:04X}"
    return str(value)


def format_delta(delta: int, style: str) -> str:
    sign = "+" if delta > 0 else ""
    if style == "addr":
        return f"{sign}{delta} bytes"
    return f"{sign}{delta}"


def compare_reports(
    baseline: dict[str, object],
    current: dict[str, object],
    fail_on_growth: bool,
    fail_on_missing_baseline: bool,
) -> list[str]:
    messages: list[str] = []
    checks = [
        (
            "RESIDENT",
            (("code", "resident_bytes"), ("code", "trimmed_bytes")),
            "max",
            "bytes",
        ),
        ("BSS", (("memory", "bss_bytes"),), "max", "bytes"),
        ("RAM_END", (("memory", "ram_end"), ("memory", "bss_end")), "max", "addr"),
        ("SP_GAP", (("memory", "register_sp_gap_bytes"),), "min", "bytes"),
        ("CODE_FULL", (("code", "full_bytes"),), "max", "bytes"),
        ("TAP", (("artifacts", "tap"),), "max", "bytes"),
        ("OVL_FILE", (("artifacts", "ovl"),), "max", "bytes"),
    ]

    for label, paths, direction, style in checks:
        before = metric_first(baseline, paths)
        after = metric_first(current, paths)
        if before is None and after is None:
            continue
        if before is None:
            if fail_on_missing_baseline:
                messages.append(f"{label} missing in baseline")
            else:
                print(f"[WARN] {label}: missing in baseline")
            continue
        if after is None:
            messages.append(f"{label} missing in current size report")
            continue
        delta = after - before
        if delta == 0:
            suffix = " bytes" if style == "bytes" else ""
            print(f"[OK] {label}: {format_value(after, style)}{suffix} (same)")
        else:
            suffix = " bytes" if style == "bytes" else ""
            print(
                f"[INFO] {label}: {format_value(before, style)} -> "
                f"{format_value(after, style)}{suffix} ({format_delta(delta, style)})"
            )
        if fail_on_growth and direction == "max" and after > before:
            messages.append(f"{label} grew by {after - before} bytes")
        if fail_on_growth and direction == "min" and after < before:
            messages.append(f"{label} shrank by {before - after} bytes")

    baseline_overlays = baseline.get("overlays", {})
    current_overlays = current.get("overlays", {})
    if isinstance(baseline_overlays, dict) and isinstance(current_overlays, dict):
        for name in sorted(set(baseline_overlays) | set(current_overlays)):
            before = baseline_overlays.get(name)
            after = current_overlays.get(name)
            if not isinstance(before, int):
                if isinstance(after, int) and fail_on_missing_baseline:
                    messages.append(f"OVL_{name} missing in baseline")
                continue
            if not isinstance(after, int):
                messages.append(f"OVL_{name} missing in current size report")
                continue
            delta = after - before
            if delta == 0:
                continue
            sign = "+" if delta > 0 else ""
            print(f"[INFO] OVL_{name}: {before} -> {after} bytes ({sign}{delta})")
            if fail_on_growth and after > before:
                messages.append(f"OVL_{name} grew by {delta} bytes")
    return messages


def check_hard_limits(report: dict[str, object]) -> list[str]:
    gap = metric(report, ("memory", "register_sp_gap_bytes"))
    if gap is None:
        return ["SP_GAP missing in current size report"]
    if gap < MIN_SP_GAP:
        return [
            f"SP_GAP {gap} bytes is below hard floor {MIN_SP_GAP} bytes"
        ]
    if gap < MIN_SP_GAP_WARN:
        print(f"[WARN] SP_GAP {gap} bytes is below warning threshold {MIN_SP_GAP_WARN} bytes")
    print(f"[OK] SP_GAP hard floor: {gap} >= {MIN_SP_GAP} bytes")
    return []


def print_summary(report: dict[str, object]) -> None:
    code = report["code"]
    memory = report["memory"]
    artifacts = report["artifacts"]
    overlays = report["overlays"]

    print(
        "[SIZE] RESIDENT {resident} bytes, BSS {bss} bytes, RAM_END {ram_end}".format(
            resident=code["resident_bytes"],
            bss=memory["bss_bytes"],
            ram_end=memory["ram_end"],
        )
    )
    print(
        "[SIZE] STACK_GAP {guard_gap} bytes, SP_GAP {sp_gap} bytes".format(
            guard_gap=memory["stack_guard_gap_bytes"],
            sp_gap=memory["register_sp_gap_bytes"],
        )
    )
    print(
        "[SIZE] CODE_FULL {full} bytes, TAP {tap} bytes, OVL_FILE {ovl} bytes, DAT {dat} bytes".format(
            full=code["full_bytes"],
            tap=artifacts["tap"],
            ovl=artifacts["ovl"],
            dat=artifacts["dat"],
        )
    )
    if isinstance(overlays, dict) and overlays:
        parts = [f"{name} {size}" for name, size in overlays.items() if name != "total"]
        print("[SIZE] OVL: " + ", ".join(parts))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--map", type=Path, required=True)
    parser.add_argument("--code-bin", type=Path, required=True)
    parser.add_argument("--tap", type=Path, required=True)
    parser.add_argument("--ovl", type=Path, required=True)
    parser.add_argument("--dat", type=Path, required=True)
    parser.add_argument("--overlay-sizes", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--write-baseline", type=Path)
    parser.add_argument("--fail-on-missing-baseline", action="store_true")
    parser.add_argument("--fail-on-growth", action="store_true")
    parser.add_argument("--org", type=int, default=ZX_ORG)
    args = parser.parse_args(argv)

    report = make_report(args)
    if args.output:
        write_json(args.output, report)
    if args.write_baseline:
        write_json(args.write_baseline, report)
        print(f"[OK] size baseline written: {args.write_baseline}")

    print_summary(report)
    hard_limit_errors = check_hard_limits(report)
    if hard_limit_errors:
        for error in hard_limit_errors:
            print(f"[ERR] {error}", file=sys.stderr)
        return 1

    if args.baseline:
        if not args.baseline.exists():
            message = f"[ERR] size baseline missing: {args.baseline}"
            if args.fail_on_missing_baseline:
                print(message, file=sys.stderr)
                return 1
            print(message.replace("[ERR]", "[WARN]"), file=sys.stderr)
            return 0
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
        errors = compare_reports(
            baseline, report, args.fail_on_growth, args.fail_on_missing_baseline
        )
        if errors:
            for error in errors:
                print(f"[ERR] {error}", file=sys.stderr)
            return 1
        print("[OK] size report checked")
    elif args.output and not args.write_baseline:
        print(f"[OK] size report written: {args.output}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
