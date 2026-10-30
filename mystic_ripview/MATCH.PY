#!/usr/bin/env python3
"""MATCH.PY — ripview one-command compile check.

Usage: python3 MATCH.PY [--fpc PATH_TO_FPC]

Compiles ripview.pas with FPC 2.6.4irc and reports PASS/FAIL.
ripview is new code (not byte-exact decompile), so this verifies
clean compilation, not binary matching.
"""

import subprocess
import sys
import os

FPC = "fpc"  # default; override with --fpc

def main():
    global FPC
    args = sys.argv[1:]
    if "--fpc" in args:
        idx = args.index("--fpc")
        FPC = args[idx + 1]

    src_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "source")
    src = os.path.join(src_dir, "ripview.pas")
    if not os.path.exists(src):
        print(f"FAIL: {src} not found")
        return 1

    # Include source/ and source/v1/ in unit search path
    v1_dir = os.path.join(src_dir, "v1")
    unit_paths = f"-Fu{src_dir} -Fu{v1_dir}"

    cmd = f"{FPC} -Mdelphi -gl {unit_paths} {src}"
    print(f"Compiling: {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

    print(result.stdout)
    if result.stderr:
        print(result.stderr)

    if result.returncode == 0:
        if "Warning:" in result.stdout or "Warning:" in result.stderr:
            print("WARN: compiled with warnings")
            return 1
        print("PASS: ripview compiles clean")
        return 0
    else:
        print("FAIL: ripview did not compile")
        return 1

if __name__ == "__main__":
    sys.exit(main())
