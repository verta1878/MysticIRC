#!/usr/bin/env python3
"""Negative check for resident dispatchers that would nest overlays."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANNED = (
    "spectrum_board_apply_trusted_move",
    "spectrum_gui_add_chat",
    "spectrum_gui_add_move",
)


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        fixture = Path(tmp)
        source = fixture / "src" / "spectrum" / "overlay" / "setup_ovl.c"
        source.parent.mkdir(parents=True)
        source.write_text("\n".join(BANNED), encoding="utf-8")
        policy = fixture / "policy.json"
        policy.write_text(
            json.dumps(
                {
                    "overlays": {
                        "setup": {
                            "allowed_caps": ["board", "gui"],
                        }
                    }
                }
            ),
            encoding="utf-8",
        )
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "tools" / "check_overlay_caps.py"),
                "--root",
                str(fixture),
                "--policy",
                str(policy),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 1
        for symbol in BANNED:
            assert f"imports {symbol} (banned)" in result.stderr
    print("Overlay capability negative check ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
