# Syntax audit: RIPlib and bbs-land against the driver

**Date:** 2026-08-12, revised 2026-08-13 · **RIPlib:** v2.0.3 · **bbs-land:** `remote-imaging-protocol@main`
**Arbiter:** `RIPSCRIP.DLL`, 592,896 bytes, MD5 `bade8b1f4e467ac7ad4edb2639738d4c`, from a RIPtel 3.1 install

This audit answers one question: **where do the two projects disagree about the shape of a command, and who is right?** Not the names — those were reconciled in v2.0.0 — but the argument layouts: how many fields, how wide, in what order.

---

## Why a name comparison was not enough

The v2.0.0 work compared RIPlib's command *names* against bbs-land's reference and closed the gap from 14 disagreements to 2. That produced a comfortable number and a false sense of completeness.

A name comparison cannot see a command whose name is right and whose fields are wrong. `|k` was called `RIP_BACK_COLOR` by both projects and read one digit instead of two — correct name, wrong syntax, wrong colour on 132 uses across 22 shipped scenes.

The fix was to stop comparing the two projects to *each other* and compare each to the driver.

---

## The method, and why the driver is the arbiter

The driver dispatches every command through a table of 129 fixed-size records at RVA `0x080820`. Each record carries the command letter, an argument count, and a list of type bytes:

```
[+0]      index
[+1..4]   handler pointer
[+15]     command letter
[+16..19] argument count   (negative = variable length)
[+20..]   argument type codes
```

The type codes are the thing this audit turns on:

| code | meaning |
| --- | --- |
| `0x01` `0x02` `0x03` `0x04` … | a literal digit count |
| `0xFF` | a **coordinate** — width from `\|n` SET_COORDINATE_SIZE, 2 by default |
| `0xFE` | a **colour** — width from `\|M` SET_COLOR_MODE, 2 by default |

This is not an inference about the record's meaning. The driver resolves those codes at decode time in a routine at RVA `0x039DE0`:

```
t = argtype[i]
t >= 0    -> t                    literal digit count
t == 0xFF -> (state+2)->[0x39]    the byte SET_COORDINATE_SIZE writes
t == 0xFE -> (state+2)->[0x3a]    the byte SET_COLOR_MODE writes
```

Three state bytes sit adjacent — `+0x38` MegaNum radix, `+0x39` coordinate size, `+0x3a` colour mode — and the parser computes its dispatch entry as `index * 5 * 8 + 0x080820`, confirming both the table address and the 40-byte stride from the driver's own code rather than from anyone's notes.

So the record is machine-readable, complete for all 129 entries, and self-validating. It outranks both projects' documentation, and both projects already say so.

**One caveat, stated up front:** the record says what the driver *accepts*, not what any handler *does*. `|F` has a valid entry and a handler that is a bare `ret`. Where a handler contradicts its own record, the handler wins — that is how `|D`'s field order was settled below.

---

## Results

Each project's field lists were extracted and compared to the driver's, with three outcomes: exact match, **notation-only** (a literal `2` where the record says width-negotiated — identical at default settings, divergent the moment `|n` or `|M` changes a width), and genuinely different.

| | compared | exact | notation only | prefix + string | **different** |
| --- | --- | --- | --- | --- | --- |
| **RIPlib** (after v2.0.3) | 51 | 26 | 21 | 4 | **0** |
| **RIPlib** (as audited, v2.0.2) | 51 | 17 | 21 | 0 | **13** |
| **bbs-land** | 80 | 52 | 15 | 0 | **13** |

The fourth column is a class the first pass did not have. The dispatch record types only the **numeric argument array**; a trailing string is passed out-of-band — `RIP_Define` and `RIP_GotoURL` both fetch it from a different stack slot than the args array. So a string never appears in the record, and a field list that matches the record exactly and then documents one further variable field is *correct*, not divergent.

RIPlib's smaller comparable set is a limitation of the method, not a measure of coverage: field lists were read from handler comments, and not every handler spells one out.

Two corrections to how this table was produced, both of which moved the numbers:

**The extractor only read the `case` line.** Several handlers wrap their field list onto a continuation line, and reading the first line alone silently truncated them — which showed up as phantom disagreements. It now reads the whole leading comment block, stopping at the first sentence so the prose that follows is not mined for `name:value` pairs. That raised the comparable set from 47 to 51.

**The earlier printing of this table did not add up.** It reported 47 compared against 19 + 19 + 3 = 41 classified. The counts above are consistent by construction.

The seven remaining differences are **not** seven defects. Four — `|1D`, `|1F`, `|3G`, `|3R` — are commands whose trailing field is variable-length (a filename, a variable name), which the extractor cannot express as a width and reports as `?`. `|1i` is the reserved-tail false alarm described below. `|1T` is a notation correction with no behaviour attached. `|3e` is described below and is now resolved. **None of the seven is an open disagreement.**

---

## RIPlib's defects, and what the evidence was

Nine genuine differences were found in the first pass. Six are fixed below, one was a false alarm, and the three originally recorded as unresolved were settled in v2.0.3 — see [Resolved in v2.0.3](#resolved-in-v203--the-arbiter-i-had-skipped). Re-running the corrected comparison then found three more, in the mouse-region and button path.

### Fixed in v2.0.1

**`|k` RIP_BACK_COLOR — read one digit instead of a colour-width field.**
Slot 43 types the argument `0xFE`. Reading a single digit made `|k04` set background **0** instead of 4, and `|k3K` set **3** instead of 128. **132 uses across 22 shipped scenes.** The only one of the nine with real rendering impact.

**`|=` RIP_LINE_STYLE — merged two fields into one.**
Slot 14 records `mega1, mega1, mega4, mega2` — four arguments. RIPlib read the leading two digits as a single `mega2` style. The handler validates `args[1] <= 4`, which is the BGI line-style range, identifying `args[1]` as the style and `args[0]` as a separate off/draw selector. Every shipped payload begins `00`, where the two readings coincide, so nothing rendered differently — but the field was silently discarded.

**`|D` RIP_SET_DRAWING_PALETTE — count and start swapped.** *Introduced by RIPlib in v2.0.0.*
Here the record alone was insufficient — it gives `mega2, mega2, mega1, mega4` without saying which `mega2` is which. The handler settles it. With `esp = E-0x420` at the checks:

```
args[0]  ->  count - argc == -3   "Invalid number of parameters"
             > 0x100              "More than 256 entries"
args[1]  ->  > 0xFF               "Start is out of range"
```

**Count comes first.** RIPlib had them reversed.

### Fixed in this audit

**`|3e` RIP_BAUD_EMULATION — read a `mega4` where the record says `mega2`.**
Slot 123 records one `mega2`. RIPlib preferred a `mega4` whenever four characters were available, reading two fields as one. *bbs-land documents `rate:4` as well* — that reading comes from the 2.0 draft, while the 3.0 driver's record says 2. **Both projects disagreed with the binary.**

*This section has been corrected twice, which is worth admitting.* It first claimed the fix had landed when it had not; the correction then said the code was a deliberate accept-both compromise and would stay that way. Both statements are now out of date: the handler settles it — `mov edi,[eax]` loads exactly **one** argument and stores it, so there is no second field to read — and the code has read `mega2` since that was established. Nothing was protected by the compromise, because no corpus scene sends `|3e` at all.

The reason this is called out rather than quietly edited: the stale paragraph was still asserting an open disagreement long after the code had matched the driver, and it was believed. A document that describes the code has to be re-read when the code changes, or it becomes a more confident source than the code itself.

**`|1I` RIP_LOAD_ICON — read a 2-digit mode over two 1-digit fields.**
Slot 97 records `FF FF 01 01 01 01 01`: two coordinates then **five single-digit fields**. RIPlib read `mega2(p+4)`, spanning the driver's `args[2]` and `args[3]`, which agrees only while `args[3]` is 0. The filename offset (9) was already correct, so only the mode decode changed.

### False alarm

**`|1i` RIP_ImageStyle.** The record says `n n n n 4 12` — 24 characters — and RIPlib reads 12. Every corpus payload is **exactly 24 characters**, and the 12-character tail is reserved. RIPlib reads the meaningful prefix and ignores the remainder. Correct as written.

### Resolved in v2.0.3 — the arbiter I had skipped

Three disagreements were originally left in place on the grounds that the record says only what is *accepted*, and that none of the three has a corpus use to validate a new reading against.

That reasoning skipped the evidence which had already settled `|D` two sections above: **the handler**. The record and the handler answer different questions, and the handler answers the one being asked. Disassembling all three settled all three — and all three were wrong.

**`|1G` is `RIP_Scroll`, not `RIP_COPY_REGION`.** The handler at `0x00D7E0` names itself in its own diagnostics — `"RIP_Scroll"`, `"Invalid mode parameter"`, `"Nothing to do"` — and the export census had *already* listed `RIP_Scroll` as present and distinct from `RIP_CopyBlit`; it was never connected to a slot. `RIP_COPY_REGION` is `|,` (slot 8, ten coordinates), so RIPlib had one name on two commands. The move is:

```
OffsetRect(&rect, 0, args[6] - args[1])
```

`dx` is a hardcoded **zero**. The region moves vertically only, there is no destination X, and `args[6]` is a destination *Y* rather than a delta — which is exactly why the record carries one trailing coordinate and not two. `args[4]` is a mode `0..6` (`cmp edi,6 / jbe`), `args[5]` selects inclusive or exclusive edges. RIPlib read fourteen characters and invented a destination pair.

**`|:` is five vertices, not a rect plus hotkey and flags.** The handler at `0x01DD70` loads all eleven arguments and coordinate-maps exactly five consecutive `(x,y)` pairs. RIPlib required 22 characters against the record's 21, **so every valid command was dropped in full** — the one defect here with unconditional effect — and read `args[4]`/`args[5]`, a coordinate pair, as a hotkey and a flag byte. The region now registers as the bounding box of the five vertices.

**`|1g` — length and ordering.** The handler at `0x00B7A4` loads `args[0..6]` and never reads `args[7]`, so RIPlib's seven-field reading was right and the trailing digit is reserved. Two things were not: RIPlib gated on 12 characters and treated the mode as optional, so a truncated command still blitted; and it required `sx1 >= sx0`, silently drawing nothing for an inverted rect, where the handler *orders* both source pairs through `0x1003112E` — the same helper `|K` uses.

So the count is not six of nine resolved but **nine of nine**, and the three that looked unresolvable were the three nobody had pointed the right instrument at.

The lesson is narrower than the one recorded on 2026-08-12. "No corpus use" is a reason that *tests* cannot settle a command. It is not a reason that *evidence* cannot. A command no scene sends is a command no test can check — and the handler is still right there.

---

## What re-running the comparison then found (v2.0.3)

Fixing the extractor and re-running it surfaced three more defects, in the mouse-region and button path. The first is the largest the audit found anywhere, measured by shipped uses.

**`|1M` RIP_Mouse read two 1-digit flags as one 2-digit hotkey.** Slot 101 records `mega2, XY×4, mega1, mega1, mega2, mega3`; the handler at `0x00CEF8` loads those args separately; the 1.54 specification names `args[5]`/`args[6]` `invertable` and `resetafter`; bbs-land names them `clk` and `clr`. Three independent sources, one layout. RIPlib glued the two into a hotkey and then took its `SEND_CHAR`/`RADIO`/`TOGGLE` bits from `p[12]` — which the record types as **reserved**.

The corpus quantifies it. Across 36 `|1M` commands in 22 scenes:

| column | field | values |
| --- | --- | --- |
| 10 | `clk` | `'1'` ×35, `'3'` ×1 |
| 11 | `clr` | `'0'` ×36 |
| 12 | reserved — *RIPlib's flags* | `'0'` ×36 |
| 13–16 | reserved | `'0'` ×36 |

So the hotkey was always the constant **36**, the flags were always **0**, and `clk` — set on 35 of 36 regions — was never captured. `RIP_MOUSE` has no hotkey field. Host command text was never affected: the offset 17 was right all along.

**`|1U` RIP_Button parsed its hotkey and flags and threw them away.** Slot 107 records exactly what RIPlib's own comment said, yet registration hardcoded `hotkey = 0` and `flags = MF_ACTIVE`. Together with the `|1M` defect this left the `SEND_CHAR`/`RADIO`/`TOGGLE` dispatch **unreachable from any command** — code that was only ever read, never written.

**`|1U` buttons never became clickable.** Registration was gated on a non-empty host command. All 39 `|1U` commands in the shipped corpus carry two separators with an *empty* third segment (`<>Clear<>`), so not one registered a region. Button hit-testing was dead for all shipped content.

The handler's comment claimed a lone segment serves as both label and host command, "see the host-fallback at registration below". No such fallback has ever existed. The comment was corrected rather than the behaviour, and the gate removed.

### How these survived

The `|1M` misreading was invisible to every corpus render test, because mouse regions are not drawn — and invisible to the unit tests, because those tests were written from the implementation. That is the same failure the `|D` fix called out one release earlier, and it recurred in the same codebase within a week.

Worse, the `MF_RADIO` test was passing **vacuously**: its fixture registered zero regions, and "both regions inactive" is trivially true of regions that do not exist. A test that asserts a negative must first assert its own fixture. It now does.

---

## bbs-land's divergences from the driver

Offered as evidence, not as a verdict on their record — several of these may be deliberate, sourced from the 1.54 specification or the 2.0 draft rather than from the 3.0 driver.

### The `Switch*` family — six commands, and the only ones that desync

| command | driver | their reference |
| --- | --- | --- |
| `\|2A` SwitchPalette | `1 2` | `2` |
| `\|2B` SwitchButtonStyle | `1 2` | `2` |
| `\|2E` SwitchEnvironment | `1 2` | `2` |
| `\|2T` SwitchTextWindow | `1 2` | `1 1` |
| `\|2Y` SwitchStyle | `1 2` | `1 1` |
| `\|2s` SwitchPort | `1 2` | `1 2 3` |

All six record `mega1 + mega2` — **three characters**. The corpus agrees: every `|2s` in it is three characters (`!|2s000`, `!|2s002`, `!|2s100`).

These matter more than the rest because the **totals** differ. A consumer following the six-character `|2s` layout over-consumes three bytes and desynchronises the remainder of the frame. The issue filed upstream covered `|2s` alone; it is six times wider than reported.

`|3e` RIP_BAUD_EMULATION belongs in this group too, and was filed under the wrong heading here until 2026-08-14. Slot 123 records a single `mega2` — **two** characters — against the reference's `rate:4`, so the totals differ and a consumer following the reference over-consumes two bytes. The handler at RVA `0x038BE1` loads exactly one argument (`mov edi,[eax]`) and stores it; there is no second field. This is the one place *both* projects disagreed with the driver, and RIPlib was wrong for longer.

That makes **seven** commands in the desync class, not six.

### Same total, different subdivision

`|1I`, `|1M`, `|1R`, `|1T`, `|1w`, `|2W` — the stream stays in sync, individual fields decode wrong. `|1R` is `2 6` against their `8`; `|1w` is `1 3` against their `4`.

### `|F` RIP_FILL

Their `x:XY y:XY border:CM` is the correct **wire** layout and RIPlib implements it. The record shows `argc=0` because the handler pointer `0x01B2FD` is a bare `ret` — the tail of the preceding function, with `0x01B2FE` (`|G`) being the real prologue. **The 3.0 driver stubs out flood fill.** This explains an anomaly rather than changing a signature.

### The notation class — 15 commands

`|"` `|&` `|+` `|-` `|;` `|U` `|[` `|]` `|_` `|g` `|u` `|w` `|1G` `|1e` `|1g` are documented with a literal `:2` where the record types the field as coordinate. Identical at default settings; wrong the moment `|n` selects another width.

**This is precisely the class of defect `|k` was on RIPlib's side** — a fixed width where the driver negotiates one. Same failure, opposite document.

---

## Taking it to zero

Four items remained after the mouse-path fixes. Working them out required settling one encoding question that had been quietly load-bearing all along.

**Are literal type codes digit counts, or string markers?** `RIP_GotoURL`'s record is a bare `0x08` and its handler takes only a string — which invites reading `0x08` as "a string follows". Arithmetic settles it:

| command | record | sum | corpus payload |
| --- | --- | --- | --- |
| `\|1e` | `XY XY XY XY 1 1 4 2` **8** | **24** | exactly 24, all digits, no string |
| `\|1i` | `XY XY XY XY 4` **12** | **24** | exactly 24 |

Two independent confirmations. **The codes are digit counts.** And since the record covers only the numeric array, its fixed width is exactly the offset a trailing string begins at. Checking all four commands RIPlib documents with a string tail:

| | record fixed prefix | RIPlib read at | |
| --- | --- | --- | --- |
| `\|1D` | 3+2 = 5 | 5 | correct |
| `\|1F` | 2+4 = 6 | 6 | correct |
| `\|3G` | 8 | **0** | **off by 8** |
| `\|3R` | 4+2+8 = 14 | **6** | **off by 8** |

Both wrong by exactly the width of the trailing literal they never skipped.

**`|3G` folded eight reserved digits onto the front of every URL.** RIPlib launches nothing — the `SV-2/S2` neutering stands — so nothing could execute. But it handed the embedder a URL pointing somewhere other than the one sent, and an embedder acting on `goto_url` under its own policy deserves the real one. The failure mode is quiet by construction: a reserved field of *digits* keeps the string inside the allowed character set, so validation passes and a **wrong** URL is stored rather than none.

**`|3R` prefixed every registered variable name with eight stray digits**, so no name a scene registered could ever be matched.

**`|1i` gated on 12 characters against a 24-character record** — ignoring the reserved tail is right, acting on a command that carries only the prefix is not. Same defect class as `|1g`.

**`|3e` was the last one.** Its handler loads exactly one argument (`mov edi,[eax]`) and stores it — there is no second field, and the record's `mega2` stands. No corpus scene sends `|3e` at all, so nothing was protected by the accept-both compromise; it now reads `mega2`, per the arbiter.

That takes RIPlib to **zero disagreements** against the driver's record.

---

## What this exercise says about method

**A comparison between two secondary sources measures agreement, not correctness.** Both projects can be wrong together, and on `|3e` both are.

**Names and syntax are independent.** `|k` had the right name in both projects and the wrong width in one.

**A test written from the implementation proves nothing.** The v2.0.0 `|D` test passed against swapped fields because its payload was authored to match the code rather than derived from the evidence. Every fix in this audit carries a regression test that fails against the old reading.

**Unexercised commands are where defects survive — but not only there.** Eight of the first nine defects had zero corpus uses, which made the corpus look like the limiting factor. The second pass broke that pattern: `|1M` had 37 uses across 22 scenes, and `|1U` 39. Heavy use protects a command only along the axis the tests actually observe. Mouse regions are never *drawn*, so no render test could see them, and the unit tests that did look were written from the implementation.

**The record and the handler answer different questions.** The record says what is accepted; the handler says what happens. `|D`'s field order needed the handler; `|F`'s stub needed the handler; `|1G`'s identity needed the handler; `|k`'s width needed only the record.

**"No corpus use" is not "no evidence".** Three commands sat recorded-but-unresolved for a release on the reasoning that nothing could validate a new reading. That confused *tests* with *evidence*. The handler was available the whole time and settled all three in an afternoon. When an item is parked as unresolvable, the thing to write down is which instrument was tried — not just that the answer was not found.

**A test that asserts a negative must first assert its own fixture.** The `MF_RADIO` test checked that two regions ended up inactive, against a fixture that registered zero regions. It passed for a year by asserting a property of the empty set.

**Measure the measuring instrument.** The comparison's own extractor read only the first line of each handler comment, truncating any field list that wrapped — and its published summary row did not add up (47 compared against 41 classified). Both were fixed before the second pass; both had been quietly shaping the conclusions.

---

## Reproducing this

```sh
python scripts/dll-dispatch-table.py <path>/Ripscrip.dll   # the record, verbatim
python scripts/dll-argtypes.py       <path>/Ripscrip.dll   # width-negotiated commands
python scripts/dll-disasm.py         <path>/Ripscrip.dll 0x01f46a   # a handler, with imports resolved
python scripts/corpus-scan.py        <path-to-scenes>      # opcode census
```

Every script verifies the image fingerprint before reporting. Per-opcode adjudication is in [`docs/spec/12-dll-provenance.md`](../docs/spec/12-dll-provenance.md); the record itself is [`docs/spec/13-dll-command-table.md`](../docs/spec/13-dll-command-table.md). Findings sent upstream are [bbs-land issue #2](https://github.com/bbs-land/remote-imaging-protocol/issues/2).
