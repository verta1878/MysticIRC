#!/usr/bin/env python3
"""Inventory repeated literals in Spectrum-side sources."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.dont_write_bytecode = True


C_STRING_RE = re.compile(r'"(?:\\.|[^"\\])*"')
ASM_STRING_RE = re.compile(r'\b(?:db|defb|defm|dm)\b[^"\n]*"([^"\n]*)"', re.IGNORECASE)


def decode_c_string(token: str) -> str:
    body = token[1:-1]
    return bytes(body, "utf-8").decode("unicode_escape")


def interesting_path(path: Path) -> bool:
    text = str(path).replace("\\", "/")
    return (
        text.startswith("src/spectrum/")
        or text.startswith("asm/overlay/")
        or text.startswith("asm/spectrum/")
        or text.startswith("asm/esxdos/")
    )


def scan_file(root: Path, path: Path, hits: dict[str, list[str]]) -> None:
    rel = path.relative_to(root)
    text = path.read_text(encoding="utf-8", errors="replace")
    suffix = path.suffix.lower()

    if suffix in {".c", ".h"}:
        for line_no, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for match in C_STRING_RE.finditer(line):
                try:
                    literal = decode_c_string(match.group(0))
                except UnicodeDecodeError:
                    literal = match.group(0)[1:-1]
                if len(literal) >= 2:
                    hits[literal].append(f"{rel}:{line_no}")
    elif suffix == ".asm":
        for line_no, line in enumerate(text.splitlines(), 1):
            for match in ASM_STRING_RE.finditer(line):
                literal = match.group(1)
                if len(literal) >= 2:
                    hits[literal].append(f"{rel}:{line_no}")


def make_report(root: Path) -> dict[str, object]:
    hits: dict[str, list[str]] = defaultdict(list)
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".c", ".h", ".asm"}:
            continue
        rel = path.relative_to(root)
        if interesting_path(rel):
            scan_file(root, path, hits)

    repeated = []
    for literal, locations in hits.items():
        if len(locations) < 2:
            continue
        repeated.append(
            {
                "literal": literal,
                "count": len(locations),
                "bytes_each": len(literal),
                "gross_bytes": len(literal) * len(locations),
                "locations": locations,
            }
        )
    repeated.sort(key=lambda item: (item["gross_bytes"], item["count"], item["literal"]), reverse=True)
    return {
        "version": 1,
        "repeated": repeated,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--limit", type=int, default=20)
    args = parser.parse_args(argv)

    root = args.root.resolve()
    report = make_report(root)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    repeated = report["repeated"]
    for item in repeated[: args.limit]:
        print(f"{item['count']}x {item['bytes_each']}B gross={item['gross_bytes']} | {item['literal']}")
        for location in item["locations"][:5]:
            print(f"  {location}")
    if args.output:
        print(f"[OK] literal report written: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
