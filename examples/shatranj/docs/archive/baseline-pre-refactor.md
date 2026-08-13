# Baseline Before Session-Core Refactor

Tag: `baseline-pre-refactor` (to be applied to the checkpoint commit containing
the current pending work and these Phase 0 documents).

## Purpose

This file records the state inherited by the session-core refactor. It is not a
diagnosis, a claim that the checkpoint is stable, or a request to investigate
the existing failures.

## Known Symptoms

The following are user-reported symptoms known before the refactor:

- NEXT using DIRECT is substantially less stable than before the current
  communication changes.
- Connection behavior has regressed across client combinations after changes
  intended to repair other combinations.
- The program presents more user-visible bugs than before the current changes.
- On Spectrum Next, opening the ABOUT screen leaves the program in an
  unrecoverable state (no known exit; restart required).
- BUSY handling misbehaves intermittently across client combinations.
- MQTT connections, previously the more stable transport, are now also
  unstable.

No frequency, trigger, first failing transition, or root cause is asserted.

## Explicitly Unknown

- Whether the same symptoms occur in `tap-next` and the banked `.nex` artifact.
- Which host/guest orientations reproduce each symptom.
- Which failures are inherited from older commits and which belong to the
  pending checkpoint.
- Whether ZX, PC, DIRECT, and MQTT are affected in the same way.
- The exact hardware, timing mode, message, or connection sequence required.

These unknowns are deliberately not investigated in Phase 0.

## Refactor Comparison Rule

The final integration is compared with this tagged checkpoint using the known
symptom list above. A final failure is classified as inherited only when it is
already recorded here; otherwise it is treated as introduced by the refactor
until shown otherwise.

The single permitted intermediate hardware checkpoint occurs after all clients
use the common DIRECT reducer and before MQTT migration begins. It validates
the new contract boundary; it is not an open-ended debugging campaign.
