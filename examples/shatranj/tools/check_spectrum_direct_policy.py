#!/usr/bin/env python3
"""Keep Spectrum on its compact DIRECT FSM and out of the generic core ABI."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


SOURCE_DIR = "src/spectrum"
DIRECT_SOURCE = f"{SOURCE_DIR}/session/direct.c"
APP_SOURCE = f"{SOURCE_DIR}/app/app.c"
SOURCE_SUFFIXES = {".c", ".h"}
REQUIRED_DIRECT = (
    "netchesszx_session_direct_send_hello(",
    "netchesszx_session_direct_apply_hello(",
    "netchesszx_session_direct_apply_start_side(",
)
REQUIRED_APP = (
    "NETCHESSZX_SESSION_EVENT_DIRECT_HELLO",
    "session_control_handle_event(",
    "game_message_loop(",
)
FORBIDDEN = (
    (re.compile(r"common/session/"), "generic session-core include"),
    (re.compile(r"\bsession_step\s*\("), "generic session-core call"),
    (
        re.compile(r"\bSession(?:Config|State|Event|Action|Workspace)\b"),
        "generic session-core ABI type",
    ),
    (
        re.compile(
            r"\bnetchesszx_session_direct_(?:init|link_up|link_down|rx|"
            r"local_request|user_decision|tx_result|game_result|poll|"
            r"batch_release)\b"
        ),
        "generic Spectrum action adapter",
    ),
    (
        re.compile(r"\bspectrum_link_direct_(?:send|close)\b"),
        "generic directed-action plumbing",
    ),
)


def line_number(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def check_sources(sources: dict[str, str], makefile: str) -> list[str]:
    errors: list[str] = []
    direct = sources.get(DIRECT_SOURCE)
    app = sources.get(APP_SOURCE)

    if direct is None:
        errors.append(f"{DIRECT_SOURCE}: missing compact DIRECT implementation")
    else:
        for required in REQUIRED_DIRECT:
            if required not in direct:
                errors.append(f"{DIRECT_SOURCE}: missing legacy FSM entry {required}")

    if app is None:
        errors.append(f"{APP_SOURCE}: missing Spectrum application source")
    else:
        for required in REQUIRED_APP:
            if required not in app:
                errors.append(f"{APP_SOURCE}: missing compact DIRECT path {required}")

    for path in sorted(sources):
        source = sources[path]
        for pattern, description in FORBIDDEN:
            match = pattern.search(source)
            if match:
                errors.append(
                    f"{path}:{line_number(source, match.start())}: "
                    f"{description} ({match.group(0)!r})"
                )

    spectrum_src = re.search(
        r"^SPECTRUM_SRC\s*:=\s*(.*?)^PIECE_ASM\s*:=",
        makefile,
        re.MULTILINE | re.DOTALL,
    )
    if spectrum_src is None:
        errors.append("Makefile: cannot locate SPECTRUM_SRC")
    elif "src/common/session/" in spectrum_src.group(1):
        errors.append("Makefile: generic session core is linked into Spectrum")

    return errors


def check_tree(root: Path) -> list[str]:
    source_dir = root / SOURCE_DIR
    if not source_dir.is_dir():
        return [f"{SOURCE_DIR}: missing Spectrum source directory"]

    sources = {
        path.relative_to(root).as_posix(): path.read_text(encoding="utf-8")
        for path in source_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in SOURCE_SUFFIXES
    }
    makefile_path = root / "Makefile"
    if not makefile_path.is_file():
        return ["Makefile: missing"]
    return check_sources(sources, makefile_path.read_text(encoding="utf-8"))


def self_test() -> None:
    clean = {
        DIRECT_SOURCE: "\n".join(REQUIRED_DIRECT),
        APP_SOURCE: "\n".join(REQUIRED_APP),
    }
    makefile = "SPECTRUM_SRC := src/spectrum/app/app.c\nPIECE_ASM := pieces.asm\n"
    if check_sources(clean, makefile):
        raise SystemExit("[ERR] Spectrum DIRECT policy self-test rejected clean source")

    generic = dict(clean)
    generic[APP_SOURCE] += "\nvoid f(void) { session_step(state, event); }\n"
    if not check_sources(generic, makefile):
        raise SystemExit("[ERR] Spectrum DIRECT policy self-test accepted generic core")

    linked = makefile.replace(
        "src/spectrum/app/app.c",
        "src/spectrum/app/app.c \\\n+                src/common/session/session.c",
    )
    if not check_sources(clean, linked):
        raise SystemExit("[ERR] Spectrum DIRECT policy self-test accepted linked core")

    print("[OK] Spectrum DIRECT policy self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return

    errors = check_tree(Path(args.root))
    if errors:
        print("[ERR] Spectrum DIRECT policy: compact/runtime boundary violated")
        for error in errors:
            print(f"  {error}")
        raise SystemExit(1)

    print("[OK] Spectrum DIRECT policy: compact FSM retained; generic core excluded")


if __name__ == "__main__":
    main()
