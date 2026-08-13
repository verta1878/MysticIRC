# SDCC/IY Migration Audit

Status: SDCC/IY is the native Spectrum backend. This file keeps only durable ABI
facts and accepted migration outcomes.

## Profile

- Toolchain: `zcc + sdcc + z80asm`
- C library: `-clib=sdcc_iy`
- Startup/origin: `-startup=31`, `-zorg=28672`
- Target: ZX Spectrum flat build with 2 KB overlays loaded at `0x6800`
- Fixed low RAM and overlay symbols are checked through generated manifests and
  guards.

## Accepted ABI Facts

- `uint8_t` and `char` arguments can be packed on the SDCC stack.
- sccz80-style one-word-per-byte-arg pushes are not safe for SDCC calls.
- `__z88dk_fastcall` and handwritten ASM wrappers must be verified against the
  actual register contract.
- IY is reserved by SDCC/IY unless a local wrapper explicitly borrows and
  restores it in a safe window.
- Overlay C may require exported SDCC/runtime helper symbols in
  `overlay_defs.asm`.
- IX/IY preservation, stack balance, DI/EI windows, fixed RAM placement, and
  overlay helper availability are ABI surfaces.

## Applied Fixes

- `_rules_hints_clear_ovl` now packs `row`/`col` as SDCC byte arguments before
  calling `_spectrum_gui_redraw_square`.
- `netchesszx_hinted_rows` moved from `$5FE8` to `$5FF0`; ABI baseline updated.
- `tools/gen_overlay_defs.py` exports resident string/memory helpers used by
  overlays.
- `--sdcccall=0` and `--sdcccall 0` were tested and rejected by this z88dk with
  `Bad integer argument`; no broken flag remains in `Makefile`.

## Audit Checklist For Future ASM/C Changes

- Every C function implemented in ASM and called from C.
- Every ASM routine that manually pushes C arguments.
- Every overlay entry stub and C overlay call boundary.
- `asm/esxdos/overlay_loader.asm` packed args, IX/IY, DI/EI, RST 8 contracts,
  and overlay entry dispatch.
- Fixed RAM from `0x5cb6..0x5fff`, asset buffers, MQTT stream, and overlay slot.
- New unresolved `___sdcc*` or `l_*` helpers in overlays.

## Validation

Use targeted guards for ABI-sensitive changes:

```sh
make NO_COLOR=1 tap
make NO_COLOR=1 abi-check
make NO_COLOR=1 module-guards
```
