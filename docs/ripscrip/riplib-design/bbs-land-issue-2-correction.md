# Correction to bbs-land/remote-imaging-protocol issue #2

Ready to paste. The original issue reported one command where the finding
covers six, and reported six commands where the full set is thirteen.
Everything below is re-derivable by anyone with the driver — the script is
in this repo and the binary is theirs to check.

Nothing here asks them to change anything. Their reference documents an
earlier generation of the protocol in several places; that is a scope
difference, not an error, and saying so is part of the report.

---

**Title:** Correction and expansion of #2 — the Switch\* finding covers six commands, not one

Following up on my own issue #2, which understates itself in two ways. I
had only checked `|2s` when I filed it.

## 1. The Switch\* finding is six commands, not one

Slots 111, 112, 114, 118, 119 and 121 all record the same shape —
`mega1 + mega2`, **three characters**:

| cmd | name | dispatch record | chars | reference | chars |
|-----|------|-----------------|-------|-----------|-------|
| `\|2A` | RIP_SwitchPalette | `mega1, mega2` | 3 | `2` | 2 |
| `\|2B` | RIP_SwitchButtonStyle | `mega1, mega2` | 3 | `2` | 2 |
| `\|2E` | RIP_SwitchEnvironment | `mega1, mega2` | 3 | `2` | 2 |
| `\|2T` | RIP_SwitchTextWindow | `mega1, mega2` | 3 | `1 1` | 2 |
| `\|2Y` | RIP_SwitchStyle | `mega1, mega2` | 3 | `1 1` | 2 |
| `\|2s` | RIP_SwitchPort | `mega1, mega2` | 3 | `1 2 3` | 6 |

`|2s` is the only member that appears in the shipped corpus at all, and all
three occurrences are three characters: `!|2s000`, `!|2s002`, `!|2s100`.
The other five rest on the shared record shape rather than on independent
observation — worth stating, since it is one line of evidence and not two.

The totals differ, so this desynchronises rather than just mis-decodes: a
consumer following the six-character `|2s` layout over-consumes three bytes
and loses the remainder of the frame.

## 2. One more command in the same class: `|3e`

`|3e` RIP_BAUD_EMULATION also differs in total. Slot 123 records a single
`mega2` — two characters — against `rate:4`. The handler at RVA `0x038BE1`
loads exactly one argument (`mov edi,[eax]`) and stores it; there is no
second field to read.

**This one cut against us too.** RIPlib preferred a `mega4` whenever four
characters were available, which is the same reading as `rate:4` and is
almost certainly the 2.0 draft's. We were wrong for longer than you were,
and we corrected it on 2026-08-12.

That makes **seven** commands whose totals differ.

## 3. Six more where the total agrees but the subdivision differs

These stay in sync; individual fields decode wrong.

| cmd | dispatch record | reference | chars |
|-----|-----------------|-----------|-------|
| `\|1I` | `XY XY 1 1 1 1 1` | `XY XY 2 1 1 1` | 9 |
| `\|1M` | `2 XY XY XY XY 1 1 2 3` | `2 XY XY XY XY 1 1 5` | 17 |
| `\|1R` | `2 6` | `8` | 8 |
| `\|1T` | `XY XY XY XY 1 1` | `XY XY XY XY 2` | 10 |
| `\|1w` | `1 3` | `4` | 4 |
| `\|2W` | `1 XY XY XY XY 2 2` | `1 XY XY XY XY 4` | 13 |

Four of the six merge two adjacent **reserved** fields into one, which is
harmless while both are zero and wrong the moment either is not. For `|1M`
and `|1T` in particular the difference is inert in practice — same wire
bytes, and neither implementation reads those fields.

`|1I` is the one with a real edge: reading the first two single digits as
one 2-digit mode spans the record's `args[2]` and `args[3]`, and agrees only
while `args[3]` is zero.

## 4. Where your reference was right and we were not

Worth recording, since #2 read one-directionally.

- **`|1M` clk/clr.** Your `1 1` split of `args[5]`/`args[6]` matches the
  driver and the 1.54 spec's `invertable`/`resetafter`. RIPlib read those
  two single digits as one 2-digit hotkey and took its flag bits from a
  reserved column. RIP_MOUSE carries no hotkey field at all. Your reference
  was closer to the driver than our code was.

- **`|1A`.** Your reference carries a row titled "1A (unidentified)",
  noting "6 digits observed (layout unresolved)". The handler at RVA
  `0x00DC58` pushes both `Invalid article number` and `RIP_SelectArticle()`
  — it names itself. Its entry records `mega2 + mega4` = 6 characters,
  matching your corpus observation exactly. Offered as a resolution to one
  of yours.

- **`|F` RIP_FILL.** Your `x:XY y:XY border:CM` is the correct wire layout
  and we implement it. The dispatch record shows `argc=0` because the
  handler pointer `0x01B2FD` is a bare `ret`; `0x01B2FE` is `|G`'s real
  prologue. **The 3.0 driver stubs out flood fill.** That explains the
  anomaly rather than changing any signature.

## Method

- Binary: `RIPSCRIP.DLL`, 592,896 bytes, MD5 `bade8b1f4e467ac7ad4edb2639738d4c`,
  from a RIPtel 3.1 install. Self-reports version 3.00.04.
- Dispatch table at RVA `0x080820`, 129 records of 40 bytes:
  `[+1..4]` handler, `[+15]` letter, `[+16..19]` argc, `[+20..]` type bytes.
  Type `0xFF` = coordinate, `0xFE` = colour, anything else is a literal
  **digit count**.
- Command names are recovered from the handlers themselves: a handler that
  can report an error pushes its own name string before calling the error
  reporter.
- Reproduce the whole comparison with
  `python scripts/ref-compare.py <RIPSCRIP.DLL> <your-reference.md>`.
  It prints both projects against the record and names the ten commands it
  cannot compare because the field lists are elided (`c1:2 c2:2 ... c16:2`)
  rather than dropping them silently.

## Two caveats on our side

Both were instrument faults that produced wrong findings before they were
caught, so they are worth naming:

- An elided field list yields only the pairs literally written. That once
  reported `|Q` as a 32-vs-6 divergence where your reference in fact
  agrees. `ref-compare.py` now names those ten commands on every run.
- The dispatch record types only the **numeric** argument array. A trailing
  string is passed out of band, so a field list matching the record and then
  documenting one further variable field is correct, and the record's fixed
  total is exactly where that string starts.
