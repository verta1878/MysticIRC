# Size report

`make size-report` rebuilds the Spectrum artifacts and writes
`build/size_report.json`.

`make size-baseline` writes `docs/size_report.baseline.json` after a known-good
build. Commit that baseline before shrink work.

The tracked baseline is a set of independently maintained guardrails, not
necessarily one coherent build snapshot. Do not sum its per-overlay ceilings
or regenerate the whole file unless deliberately establishing a new baseline.

`make size-check` compares the current report with the baseline. By default it
reports deltas without failing on growth. Pass `SIZE_CHECK_FLAGS=--fail-on-growth`
when a branch is expected to be size-neutral or smaller.
