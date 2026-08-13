# External Audit Brief

Use this as the reusable prompt skeleton for external read-only audits. Current
triage and accepted/rejected findings live in `docs/archive/external-audit-triage.md`.

## Preflight Required

Ask the auditor to report:

- `git branch --show-current`
- `git rev-parse --short HEAD`
- `git status --short`
- exact commands run
- exact build artifacts and timestamps used

Fresh build data is required before using size, ABI, map, or overlay evidence.
If artifacts are stale or missing, regenerate with:

```sh
make NO_COLOR=1 size-report abi-manifest
```

Stale `build/` artifacts are invalid evidence.

## Product Constraints

- ZX Spectrum 48K-first.
- z88dk SDCC/IY build, startup=31, origin `0x7000`.
- No malloc/stdio heap dependency.
- TAP, OVL, and DAT ship together.
- One shared overlay slot at `0x6800`.
- Overlays are fixed 2048-byte blocks.
- No nested overlay assumptions.
- Respect SDCC/IY ABI and packed `uint8_t` stack arguments.
- Preserve IX/IY across C/ASM boundaries where required.
- Fixed low RAM layout is intentional; do not propose reshuffling without
  concrete proof and all guard updates.
- Do not propose UX, protocol, or behavior changes without a proven bug.

## Audit Areas

- ABI/ASM/loader: `asm/esxdos/overlay_loader.asm`,
  `asm/overlay/*/entry_*.asm`, `asm/overlay/rules/rules_stub.asm`.
- Session/protocol/transport: `src/spectrum/app/app.c`,
  `src/spectrum/session/*.c`, `src/spectrum/transport/*.c`.
- UI/input/render: `src/spectrum/ui/*.c`, `asm/spectrum/screen.asm`.
- Shrink/map: `build/SHATRANJ.map`, `build/size_report.json`,
  `build/overlay_sizes.json`, `Makefile`, `docs/size_report.baseline.json`.

## Known Rejections

- Malloc/stdio heap drag unless a fresh map proves otherwise.
- `ovl_return` unconditional `ei` unless there is a real caller-owned DI overlay
  call.
- About renderer scratch using the overlay slot; this is intentional and
  invalidates the overlay cache.
- FRAMES at `0x5C78` as a weak non-security seed.
- Generic Z80 tricks without byte proof and ABI proof.

## Expected Output

1. Critical/preflight confirmation.
2. Findings ordered by severity and confidence.
3. Safe shrink candidates with byte estimates and validation.
4. Aggressive/experimental candidates.
5. Rejected attractive ideas.
6. Recommended hardware tests by area.
7. Exact artifacts and timestamps used.
