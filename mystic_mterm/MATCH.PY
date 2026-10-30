#!/usr/bin/env python3
"""MATCH.PY — mterm one-command compile check.

Usage: python3 MATCH.PY [--fpc PATH_TO_FPC]

Compiles mterm.pas with FPC 2.6.4irc and reports PASS/FAIL.
This is NOT a byte-exact match tool (mterm is new code, not decompile).
It verifies the project compiles clean with zero errors and zero warnings.
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

    src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mterm.pas")
    if not os.path.exists(src):
        print(f"FAIL: {src} not found")
        return 1

    cmd = [FPC, "-Mobjfpc", "-gl", src]
    print(f"Compiling: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)

    print(result.stdout)
    if result.stderr:
        print(result.stderr)

    if result.returncode == 0:
        # Check for warnings
        if "Warning:" in result.stdout or "Warning:" in result.stderr:
            print("WARN: compiled with warnings")
            return 1
        print("PASS: mterm compiles clean")
        return 0
    else:
        print("FAIL: mterm did not compile")
        return 1

if __name__ == "__main__":
    sys.exit(main())
