# Overlay ABI guard

`make abi-manifest` writes manifests for both build variants:
`build/abi_manifest.json` from the classic TAP map and
`build/nex/abi_manifest.json` from the Next banking map. Both include the
public overlay API, overlay/context constants, low-RAM wire layout, and the
`SESSION_ROUTE_*` contract.

`make abi-baseline` writes `docs/abi_manifest.baseline.json` and
`docs/abi_manifest.next.baseline.json` after known-good classic and Next
builds. Commit both baselines before size-reduction work. The individual
`abi-next-manifest`, `abi-next-baseline`, and `abi-next-check` targets are
available when only the Next contract is being changed.

`make abi-check` rebuilds both manifests and compares each with its own
baseline. By default it is a presence/API/constants guard: it fails if overlay
declarations, required resident symbol presence, overlay ID/entry constants,
wire-context constants, or session route constants change unexpectedly. It
intentionally does not pin resident function addresses because
overlays link against regenerated `build/overlay_defs.asm`.

Use `ABI_CHECK_FLAGS=--strict-addresses make abi-check` only for release or
ABI-layout work that promises resident symbol address stability. Regenerate and
commit either baseline only after accepting that stricter contract.
