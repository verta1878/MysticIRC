#!/usr/bin/env python3
"""Check the SDCC/IY ABI assumptions used by handwritten Z80 stubs."""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


PROBE_SOURCE = r"""
#include <stdint.h>

extern uint8_t abi_pair(uint8_t first, uint8_t second);

uint8_t abi_probe(void)
{
    return abi_pair(0x12u, 0x34u);
}
"""


def run(argv, cwd):
    return subprocess.run(
        argv,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def normalize(text):
    return "\n".join(line.strip().lower() for line in text.splitlines())


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--zcc", default="zcc")
    parser.add_argument("--build-dir", default="build")
    args = parser.parse_args(argv)

    zcc = shutil.which(args.zcc) or args.zcc
    build_dir = Path(args.build_dir)
    probe_dir = build_dir / "abi_probe_sdcc_iy"
    probe_dir.mkdir(parents=True, exist_ok=True)

    source_path = probe_dir / "abi_probe.c"
    source_path.write_text(PROBE_SOURCE, encoding="ascii")

    for old in probe_dir.glob("abi_probe*"):
        if old != source_path:
            old.unlink()

    cmd = [
        zcc,
        "+z80",
        "-vn",
        "-clib=sdcc_iy",
        "-SO3",
        "-compiler=sdcc",
        "-Cs--no-reg-params",
        "--opt-code-size",
        "--fomit-frame-pointer",
        "-S",
        str(source_path.name),
        "-o",
        "abi_probe",
    ]
    result = run(cmd, probe_dir)
    if result.returncode != 0:
        sys.stdout.write(result.stdout)
        print("[ERR] SDCC/IY ABI probe compile failed")
        return result.returncode

    asm_files = sorted(probe_dir.glob("abi_probe*.asm"))
    if not asm_files and (probe_dir / "abi_probe").exists():
        asm_files = [probe_dir / "abi_probe"]
    if not asm_files:
        print("[ERR] SDCC/IY ABI probe did not emit asm")
        return 1

    asm_text = normalize(asm_files[0].read_text(encoding="utf-8", errors="replace"))
    packed_word_patterns = [
        ("ld\thl,0x3412", "push\thl"),
        ("ld\tde,0x3412", "push\tde"),
        ("ld\tbc,0x3412", "push\tbc"),
    ]
    call_index = asm_text.find("call\t_abi_pair")
    if call_index < 0:
        print("[ERR] SDCC/IY ABI changed: abi_pair call not found")
        return 1
    before_call = asm_text[:call_index]
    if not any(load in before_call and push in before_call for load, push in packed_word_patterns):
        print("[ERR] SDCC/IY ABI changed: expected uint8,uint8 packed word 0x3412 before abi_pair")
        return 1

    print("[OK] SDCC/IY ABI probe: uint8,uint8 packed stack call")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
