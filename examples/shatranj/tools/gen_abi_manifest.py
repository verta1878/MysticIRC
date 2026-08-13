#!/usr/bin/env python3
"""Generate and compare the Shatranj overlay ABI manifest."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from gen_overlay_defs import OPTIONAL_SYMBOLS, REQUIRED_SYMBOLS, parse_map


MANIFEST_VERSION = 3
DEFAULT_API_HEADER = Path("src/spectrum/overlay/overlay_api.h")
DEFAULT_OVERLAY_HEADER = Path("src/spectrum/overlay/overlay.h")
DEFAULT_SESSION_HEADER = Path("src/common/session/session.h")


def normalize_type(text: str) -> str:
    return (
        " ".join(text.replace("*", " * ").split())
        .replace(" *", " *")
        .replace("* ", "*")
    )


def asm_symbol_for_c(name: str) -> str:
    return name if name.startswith("_") else "_" + name


def parse_api_header(
    path: Path,
    include_root: Path | None = None,
    seen: set[Path] | None = None,
) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    extern_re = re.compile(r"^extern\s+(.+?)\s+([A-Za-z_]\w*)(\[[^\]]*\])?\s*;")
    func_re = re.compile(r"^(.+?[\*\s])([A-Za-z_]\w*)\((.*)\)\s*(.*);")
    include_re = re.compile(r'^#include\s+"([^"]+)"')
    statement = ""
    in_preprocessor = False

    if include_root is None:
        include_root = path.parents[2]
    if seen is None:
        seen = set()
    resolved_path = path.resolve()
    if resolved_path in seen:
        return entries
    seen.add(resolved_path)

    text = path.read_text(encoding="utf-8")
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.DOTALL)
    text = re.sub(r"//.*", "", text)
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if in_preprocessor:
            in_preprocessor = raw_line.rstrip().endswith("\\")
            continue
        include_match = include_re.match(line)
        if include_match:
            include_path = include_root / include_match.group(1)
            if include_path.exists():
                entries.extend(parse_api_header(include_path, include_root, seen))
            continue
        if line.startswith("#"):
            in_preprocessor = raw_line.rstrip().endswith("\\")
            continue
        if not line:
            continue
        statement = f"{statement} {line}".strip()
        while ";" in statement:
            declaration, statement = statement.split(";", 1)
            declaration = declaration.strip() + ";"
            extern_match = extern_re.match(declaration)
            if extern_match:
                c_type, name, array_suffix = extern_match.groups()
                if array_suffix:
                    c_type = f"{c_type} []"
                entries.append(
                    {
                        "kind": "object",
                        "name": name,
                        "asm_name": asm_symbol_for_c(name),
                        "type": normalize_type(c_type),
                    }
                )
                continue

            func_match = func_re.match(declaration)
            if not func_match:
                continue
            ret_type, name, args_text, attrs = func_match.groups()
            if name in {"if", "for", "while", "switch"}:
                continue
            args = []
            if args_text.strip() != "void":
                args = [
                    normalize_type(arg.strip())
                    for arg in args_text.split(",")
                    if arg.strip()
                ]
            entries.append(
                {
                    "kind": "function",
                    "name": name,
                    "asm_name": asm_symbol_for_c(name),
                    "return": normalize_type(ret_type),
                    "args": args,
                    "calling_convention": "fastcall"
                    if "__z88dk_fastcall" in attrs
                    else "z88dk_c",
                }
            )

    return entries


def parse_constants(
    path: Path,
    prefix: str,
    values: dict[str, object] | None = None,
) -> list[dict[str, object]]:
    constants: list[dict[str, object]] = []
    if values is None:
        values = {}
    define_re = re.compile(
        rf"^#define\s+({re.escape(prefix)}[A-Za-z0-9_]+)\s+(.+)$"
    )

    for line_no, raw_line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), 1
    ):
        match = define_re.match(raw_line.strip())
        if not match:
            continue
        name, raw_value = match.groups()
        raw_value = raw_value.split("/*", 1)[0].strip()
        if not raw_value:
            continue

        resolved: object
        number_text = raw_value.rstrip("uUlL")
        if re.fullmatch(r"0x[0-9A-Fa-f]+", number_text):
            resolved = int(number_text, 16)
        elif re.fullmatch(r"\d+", number_text):
            resolved = int(number_text, 10)
        elif raw_value in values:
            resolved = values[raw_value]
        else:
            resolved = raw_value

        values[name] = resolved
        constants.append(
            {
                "name": name,
                "raw_value": raw_value,
                "value": resolved,
            }
        )

    return constants


def hex_addr(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value:04X}"


def symbol_entries(
    symbols: dict[str, int], names: list[str], required: bool
) -> list[dict[str, object]]:
    return [
        {
            "name": name,
            "address": hex_addr(symbols.get(name)),
            "required": required,
            "present": name in symbols,
        }
        for name in names
    ]


def make_manifest(
    root: Path,
    map_path: Path,
    api_header: Path,
    overlay_header: Path,
    session_header: Path,
) -> dict[str, object]:
    symbols = parse_map(map_path)
    api = parse_api_header(api_header)
    context_header = api_header.with_name("overlay_context.h")
    lowram_header = context_header.parents[1] / "lowram_map.h"
    context_values: dict[str, object] = {}
    parse_constants(lowram_header, "NETCHESSZX_LOWRAM_", context_values)
    api_by_asm = {entry["asm_name"]: entry for entry in api}
    resident_symbols = symbol_entries(symbols, REQUIRED_SYMBOLS, True)
    resident_symbols.extend(symbol_entries(symbols, OPTIONAL_SYMBOLS, False))

    for entry in resident_symbols:
        api_entry = api_by_asm.get(entry["name"])
        if api_entry:
            entry["api"] = api_entry

    markers = {
        name: hex_addr(symbols.get(name))
        for name in [
            "_overlay_code_slot",
            "__CODE_END_tail",
            "__data_compiler_tail",
            "__BSS_END_tail",
        ]
        if name in symbols
    }

    missing_required = [
        entry["name"]
        for entry in resident_symbols
        if entry["required"] and not entry["present"]
    ]

    return {
        "version": MANIFEST_VERSION,
        "root": str(root),
        "sources": {
            "map": str(map_path),
            "overlay_api": str(api_header),
            "overlay_context": str(context_header),
            "lowram_map": str(lowram_header),
            "overlay_header": str(overlay_header),
            "session_header": str(session_header),
        },
        "markers": markers,
        "resident_symbols": resident_symbols,
        "overlay_constants": parse_constants(overlay_header, "SPECTRUM_OVL_"),
        "overlay_context_constants": parse_constants(
            context_header, "SPECTRUM_", context_values
        ),
        "session_route_constants": parse_constants(
            session_header, "SESSION_ROUTE_"
        ),
        "api": api,
        "missing_required": missing_required,
    }


def stable_api(entry: dict[str, object]) -> dict[str, object]:
    return {
        key: entry[key]
        for key in ("kind", "type", "return", "args", "calling_convention")
        if key in entry
    }


def compare_named_list(
    baseline: list[dict[str, object]],
    current: list[dict[str, object]],
    name: str,
    fields: tuple[str, ...],
) -> list[str]:
    errors: list[str] = []
    base_by_name = {str(item["name"]): item for item in baseline}
    cur_by_name = {str(item["name"]): item for item in current}

    for item_name in sorted(base_by_name.keys() - cur_by_name.keys()):
        errors.append(f"{name} removed: {item_name}")
    for item_name in sorted(cur_by_name.keys() - base_by_name.keys()):
        errors.append(f"{name} added: {item_name}")
    for item_name in sorted(base_by_name.keys() & cur_by_name.keys()):
        before = base_by_name[item_name]
        after = cur_by_name[item_name]
        for field in fields:
            if before.get(field) != after.get(field):
                errors.append(
                    f"{name} changed: {item_name}.{field}: {before.get(field)!r} -> {after.get(field)!r}"
                )
    return errors


def compare_manifests(
    baseline: dict[str, object],
    current: dict[str, object],
    strict_addresses: bool,
) -> list[str]:
    errors: list[str] = []

    if baseline.get("version") != current.get("version"):
        errors.append(
            f"manifest version changed: {baseline.get('version')!r} -> "
            f"{current.get('version')!r}"
        )

    for missing in current.get("missing_required", []):
        errors.append(f"required resident symbol missing: {missing}")

    errors.extend(
        compare_named_list(
            baseline.get("api", []),  # type: ignore[arg-type]
            current.get("api", []),  # type: ignore[arg-type]
            "api",
            ("kind", "type", "return", "args", "calling_convention"),
        )
    )
    errors.extend(
        compare_named_list(
            baseline.get("overlay_constants", []),  # type: ignore[arg-type]
            current.get("overlay_constants", []),  # type: ignore[arg-type]
            "overlay constant",
            ("raw_value", "value"),
        )
    )
    errors.extend(
        compare_named_list(
            baseline.get("overlay_context_constants", []),  # type: ignore[arg-type]
            current.get("overlay_context_constants", []),  # type: ignore[arg-type]
            "overlay context constant",
            ("raw_value", "value"),
        )
    )
    errors.extend(
        compare_named_list(
            baseline.get("session_route_constants", []),  # type: ignore[arg-type]
            current.get("session_route_constants", []),  # type: ignore[arg-type]
            "session route constant",
            ("raw_value", "value"),
        )
    )
    # Compare `present` only for required symbols. Optional helpers (e.g.
    # l_gt) are pruned or kept depending on feature flags and compiler output,
    # so their presence legitimately varies; a required symbol disappearing is
    # already caught via missing_required.
    resident_fields = ("required",) + (("address",) if strict_addresses else ())
    errors.extend(
        compare_named_list(
            baseline.get("resident_symbols", []),  # type: ignore[arg-type]
            current.get("resident_symbols", []),  # type: ignore[arg-type]
            "resident symbol",
            resident_fields,
        )
    )
    base_resident = {
        str(item["name"]): item
        for item in baseline.get("resident_symbols", [])  # type: ignore[union-attr]
    }
    for item in current.get("resident_symbols", []):  # type: ignore[union-attr]
        name_key = str(item["name"])
        base_item = base_resident.get(name_key)
        if base_item is None or not base_item.get("required"):
            continue
        if base_item.get("present") != item.get("present"):
            errors.append(
                f"resident symbol changed: {name_key}.present: "
                f"{base_item.get('present')!r} -> {item.get('present')!r}"
            )

    if strict_addresses:
        base_markers = baseline.get("markers", {})
        cur_markers = current.get("markers", {})
        if isinstance(base_markers, dict) and isinstance(cur_markers, dict):
            for marker in sorted(set(base_markers) | set(cur_markers)):
                if base_markers.get(marker) != cur_markers.get(marker):
                    errors.append(
                        f"marker changed: {marker}: {base_markers.get(marker)!r} -> {cur_markers.get(marker)!r}"
                    )

    return errors


def write_json(path: Path, data: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(data, indent=2, sort_keys=True) + "\n")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("map_file", type=Path)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--overlay-api", type=Path, default=DEFAULT_API_HEADER)
    parser.add_argument("--overlay-header", type=Path, default=DEFAULT_OVERLAY_HEADER)
    parser.add_argument("--session-header", type=Path, default=DEFAULT_SESSION_HEADER)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--write-baseline", type=Path)
    parser.add_argument("--strict-addresses", action="store_true")
    parser.add_argument("--fail-on-missing-baseline", action="store_true")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    manifest = make_manifest(
        root,
        args.map_file,
        args.overlay_api,
        args.overlay_header,
        args.session_header,
    )

    if args.output:
        write_json(args.output, manifest)
    if args.write_baseline:
        write_json(args.write_baseline, manifest)
        print(f"[OK] ABI baseline written: {args.write_baseline}")

    if args.baseline:
        if not args.baseline.exists():
            message = f"[ERR] ABI baseline missing: {args.baseline}"
            if args.fail_on_missing_baseline:
                print(message, file=sys.stderr)
                return 1
            print(message.replace("[ERR]", "[WARN]"), file=sys.stderr)
            return 0
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
        errors = compare_manifests(baseline, manifest, args.strict_addresses)
        if errors:
            for error in errors:
                print(f"[ERR] {error}", file=sys.stderr)
            return 1
        print("[OK] ABI manifest matches baseline")

    missing = manifest.get("missing_required", [])
    if missing:
        for name in missing:
            print(f"[ERR] required resident symbol missing: {name}", file=sys.stderr)
        return 1

    if args.output and not args.baseline and not args.write_baseline:
        print(f"[OK] ABI manifest written: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
