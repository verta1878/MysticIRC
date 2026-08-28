=====================================================================
14.  DIVERGENCE REGISTER
=====================================================================

14.1  THE MEASURE
---------------------------------------------------------------------

RIPlib's measure of correctness is the shipped TeleGrafix driver:

     RIPSCRIP.DLL, 592,896 bytes
     MD5 bade8b1f4e467ac7ad4edb2639738d4c
     from a RIPtel 3.1 install

Not a specification document, not another implementation, and not
RIPlib's own history.  Where any of those disagree with the driver, the
driver wins and the disagreement is recorded here with its reasoning.

Two refinements, both learned the hard way and both load-bearing:

  * WHERE THE HANDLER CONTRADICTS THE RECORD, THE HANDLER WINS.  The
    dispatch record says what the driver ACCEPTS; the handler says what
    it DOES.  '|D's field order, '|F's stub and '|1G's identity were all
    settled by the handler against a record that could not decide them.

  * WHERE SHIPPED CONTENT CONTRADICTS BOTH, CONTENT IS EVIDENCE ABOUT
    THE WORLD, NOT ABOUT THE DRIVER.  It cannot overrule the driver on
    what a field MEANS, but it can and does overrule a decision to
    reject input the driver would reject -- see 14.4.

Reproduce every table below with:

     python scripts/dll-dispatch-table.py <path>/RIPSCRIP.DLL
     python scripts/dll-argtypes.py       <path>/RIPSCRIP.DLL
     python scripts/dll-disasm.py         <path>/RIPSCRIP.DLL <rva>

and check the parser against the record with:

     python scripts/dll-conformance.py    <path>/RIPSCRIP.DLL -v

That last one is the standing check.  It covers four classes -- read
offsets, length gates, radix selection and coverage -- each of which was
first hit as a single bug and only afterwards turned into a check, at
which point every one of them found more of the same.  It exits non-zero
on a defect, so it can gate a build, and it lists the deliberate
tolerances in 14.3.3 by name rather than passing them silently.

and reproduce section 14.2's comparison -- both projects against the
driver, command by command -- with:

     python scripts/ref-compare.py <path>/RIPSCRIP.DLL <path>/reference.md

Neither the driver nor the reference is vendored, so both are
arguments; with no reference only RIPlib is compared, which is the
useful half day to day.  It exits non-zero if RIPlib disagrees with the
record anywhere, and never fails on the reference disagreeing, because
the reference is evidence and not the measure.

That script was itself a finding.  Until 2026-08-13 the 14.2 counts came
from a copy living in a scratch directory, which meant this section was
the one part of the register NOT reproducible from the repository, and
which rotted unnoticed: it carried hardcoded switch-block line numbers
that went stale as src/ripscrip.c grew, so it bracketed the wrong code
and reported three RIPlib divergences that did not exist -- '|R' showing
'|1R's record, because the ranges had drifted past it.  The version in
scripts/ derives its boundaries from structural markers.

and re-derive the findings themselves with:

     python scripts/dll-validate-claims.py <path>/RIPSCRIP.DLL

That one is adversarial by construction.  It states each load-bearing
claim in this register and in 12-dll-provenance.md as a predicate, then
tries to REFUTE it from the image, the shipped corpus and the source --
handler self-naming, the fixed-radix sets, every string-tail prefix
width, the corpus population figures quoted below, and what the code now
does, including negatives such as "'|3e' no longer falls back to mega4".
A claim it cannot re-derive is reported UNVERIFIED rather than passed.

It exists because four documentation defects of one shape were found in
a single day, each by accident: a field list that still described a
defect after the fix, a note saying '|y' "is not implemented yet"
written before it was, a section calling '|3e' an accept-both compromise
a day after that compromise was removed, and a comment asserting that
'X' "is not in the DLL command table" when 'X' is slot 70.  Prose about
code does not notice when the code changes, and a stale conclusion reads
as more authoritative than the behaviour it misdescribes.  See D-27.

Neither tool is run in CI: RIPSCRIP.DLL is not vendored, and will not
be.  Run both by hand against a RIPtel install when the parser changes.


14.2  DIVERGENCES FROM bbs-land/remote-imaging-protocol
---------------------------------------------------------------------

Thirteen commands where their reference and the driver disagree.
RIPlib follows the driver in every one.  Offered as evidence, not as a
verdict on their record: several are plainly sourced from the 1.54
specification or the 2.0 draft rather than from the 3.0 driver, and a
reference documenting an earlier generation of the protocol is not
wrong so much as scoped differently.

The split that matters is whether the TOTAL width agrees.  A consumer
that mis-subdivides a command decodes that one command badly; a
consumer that gets the total wrong desynchronises everything after it.

WHAT THE EVIDENCE ACTUALLY IS, PER COMMAND.  The dispatch record is the
arbiter throughout, but it is worth being blunt about how much
CORROBORATION each finding has, because it is much less than the length
of this section suggests.  Only FOUR of the thirteen appear in shipped
content at all:

     cmd    corpus uses   widths observed
     ----   -----------   ----------------------------------------
     |1M         38       28,29,32,34,36,37,38,51,61,65,66,71,76
     |1R         25       18,19,20,21,68
     |1T         12       10 -- every one
     |2s          3       3  -- every one  ("002", "100", "000")

     |1I  |1w  |2A  |2B  |2E  |2T  |2W  |2Y  |3e        zero uses

For the nine with zero uses there is no corpus arbiter and there never
will be: the record and the handler body are the whole of the argument.
That is not a weakness of the finding -- the record IS the driver's own
statement of what it accepts -- but it does mean these are settled by
one line of evidence rather than two, and a reader weighing them should
know which.

The two that ARE corroborated corroborate strongly.  Every '|1T' in
shipped content is exactly ten characters, and every '|2s' is exactly
three, which refutes the reference's six outright.  '|2s' is also the
only member of the Switch* family that appears anywhere in the corpus;
the other five are carried by the shared record shape -- slots 111,
112, 114, 118, 119 and 121 all record mega1 + mega2 -- and not by
independent observation.

TESTS.  Five tests in tests/test_ripscrip.c pin the divergences that
can be demonstrated; 14.2.3 lists the ones that cannot, and why, rather
than giving them a test that asserts its own fixture.

14.2.1  TOTALS DIFFER -- seven commands, stream desync

     cmd   driver          chars  bbs-land      chars
     ----  --------------  -----  ------------  -----
     |2A   mega1, mega2      3    2               2
     |2B   mega1, mega2      3    2               2
     |2E   mega1, mega2      3    2               2
     |2T   mega1, mega2      3    1 1             2
     |2Y   mega1, mega2      3    1 1             2
     |2s   mega1, mega2      3    1 2 3           6
     |3e   mega2             2    4               4

     The Switch* family is one shape -- a slot digit plus a 2-digit
     field -- recorded identically across slots 111, 112, 114, 118, 119
     and 121.  ALL SIX, not just '|2s': an issue filed upstream named
     only '|2s', which understates the finding fivefold.  The corpus
     agrees as far as it can reach: all three '|2s' commands in shipped
     content are three characters ("!|2s000", "!|2s100", "!|2s002"),
     and no other member appears at all.  A consumer reading six
     over-consumes three bytes and loses the rest of the frame.

     PINNED BY  "|2A |2B |2E |2T |2Y |2s: driver records 3 chars, not 2"
                -- feeds each a 3-character command and a 2-character
                one, and requires the first to take effect and the
                second to be rejected, since a truncated record is one
                the driver throws away.
     PINNED BY  "|2s: driver records 3 chars; the reference's 6 would
                over-consume" -- feeds "!|2s000|X0A00|" and requires the
                pixel to land.  A consumer reading by declared width
                rather than to '|' loses it.

     '|3e' RIP_BAUD_EMULATION is the one place BOTH projects disagreed
     with the driver, and RIPlib was wrong for longer: it preferred a
     mega4 whenever four characters were available, which is the 2.0
     draft's rate:4.  Slot 123 records a single mega2 and the handler
     (RVA 0x038BE1) loads exactly ONE argument -- mov edi,[eax] -- and
     stores it.  There is no second field.  Corrected; see D-16.

     PINNED BY  "|3e RIP_BAUD_EMULATION reads mega2, not the reference's
                rate:4" -- feeds "!|3e0A00|", which decodes to 10 as a
                mega2 and 12960 as a mega4, so the two readings cannot
                be confused.  The test names the mega4 value in its
                failure message, so a regression says which reading it
                fell back to rather than only that it failed.

14.2.2  SAME TOTAL, DIFFERENT SUBDIVISION -- six commands

     cmd   driver                    bbs-land            chars
     ----  ------------------------  ------------------  -----
     |1I   n n 1 1 1 1 1             n n 2 1 1 1           9
     |1M   2 n n n n 1 1 2 3         2 n n n n 1 1 5      17
     |1R   2 6                       8                     8
     |1T   n n n n 1 1               n n n n 2            10
     |1w   1 3                       4                     4
     |2W   1 n n n n 2 2             1 n n n n 4          13

     The stream stays in sync; individual fields decode wrong.  Four of
     the six merge two adjacent reserved fields into one, which is
     harmless while both are zero and wrong the moment either is not.

     '|1M' is the exception that mattered, and it cut against RIPlib.
     Their 1+1 split of args[5]/args[6] agrees with the driver and with
     the 1.54 specification's 'invertable'/'resetafter'; RIPlib read
     those two single digits as ONE 2-digit hotkey and took its flag
     bits from a reserved column.  Their reference was closer to the
     driver than RIPlib's code was.  See D-15.

     '|1R' is the other one with teeth.  The driver's 8-character fixed
     prefix is exactly where the filename begins, and shipped content
     confirms it -- all 25 '|1R' commands in the corpus start with eight
     zeros ("00000000dragon.txt").  RIPlib read the filename from offset
     0.  See D-19.

     PINNED BY  "|1R takes the filename at offset 8 (D-19)"
     PINNED BY  "1M defines a mouse region with clk/clr flags + host
                text" -- asserts the host text is exactly "HELLO",
                which can only be true if the fixed prefix is
                seventeen characters wide.  It also pins the clk/clr
                split itself, which is the half of the '|1M' finding
                that IS observable: hotkey must read 0, RIP_MF_INVERT
                must be set and RIP_MF_RESET clear.
     PINNED BY  "|1I fixed prefix is 9 chars; the filename starts there"
                -- named for what it demonstrates.  It does NOT
                discriminate the mode width; see 14.2.3.
     PINNED BY  "|2W leaves the stream in sync (its gate has no
                observable)" -- likewise named for what it shows, which
                is less than the '|2W' finding.  See 14.2.3.

     EVERY TEST ABOVE WAS VERIFIED BY INJECTION -- the parser was
     deliberately regressed to the reference's reading and the test
     required to fail.  Two did not, and both were the test's fault:

       * the Switch* test fed a ONE-character short form, which a gate
         loosened from three to two still rejects, so it passed against
         a regressed parser.  Two characters is the boundary that
         separates the readings; it now uses two.

       * the '|2W' test was named for the gate but measured only
         framing, and passed with the gate regressed from thirteen to
         nine.  '|2W' writes no file and changes no readable state, so
         the gate has no observable at all; the test was renamed to the
         one thing it does establish and the gate moved to 14.2.3.

     A test that cannot fail is worse than no test, because it is
     counted.  Both faults were invisible until the injection ran.


14.2.3  WHAT IS NOT TESTED, AND WHY

     Four of the thirteen cannot be demonstrated, and two more are
     demonstrated only in part.  Listing them is the point: a suite that
     appears to cover thirteen cases while several assert nothing is
     worse than one that says so, because the count is what gets
     quoted.

     '|1M' and '|1T'  -- THE DIVERGENCE ITSELF IS INERT.  Be careful
          to separate two things here, because '|1M' carries both.

          The bbs-land DIVERGENCE is only in how a trailing RESERVED
          span is named: res:2+res:3 against res:5 for '|1M',
          res:1+res:1 against res:2 for '|1T'.  Both readings describe
          identical wire bytes, RIPlib reads neither field, and no
          behaviour can tell them apart.  A test would assert its own
          fixture.  What a consumer depends on is the TOTAL, and that
          IS pinned -- all twelve '|1T' commands in the corpus are ten
          characters, and the '|1M' test's host text can only come out
          right if the prefix is seventeen.

          Separately, '|1M's clk/clr pair is where RIPlib was wrong and
          the reference was RIGHT -- see 14.2.2.  That half is fully
          observable and fully tested.  It is not a divergence from
          bbs-land at all, which is why it is not counted among the
          thirteen; it is listed here only so the two are not confused.

     '|1w'  -- INERT, more so.  Driver 1+3, reference 4, same total,
          and RIPlib's handler body is a bare 'break'.  The command is
          consumed and nothing is done with it, exactly as the record's
          width requires.  There is no observable to assert.  No corpus
          scene sends '|1w' either.

     '|1I'  -- PARTLY TESTED.  Both readings total nine and both put
          the filename at offset 9, so the filename cannot distinguish
          them.  The test pins the nine-character prefix, which is a
          real property that RIPlib's own documentation had wrong, but
          it does NOT discriminate the mode width.  The only field the
          readings place differently is the mode, and even that agrees
          whenever the driver's args[3] is zero.  There are zero '|1I'
          commands in the shipped corpus, so no content exercises the
          difference.  Discriminating it would need a cached icon and a
          visible blit staged purely for the test; the record is clear
          (FF FF 01 01 01 01 01) and is left to carry it.

     '|2W'  -- GATE NOT TESTABLE.  Driver 1+XY*4+2+2 = thirteen fixed
          characters, reference 1+XY*4+4 = eleven, same total, filename
          following either way.  RIPlib's gate is thirteen and was nine
          for a while, so a record truncated before its flags was still
          acted on.  But '|2W' WRITES NO FILE -- it validates the port
          and rectangle and returns, changing nothing a test can read.
          The gate is real and correct; it simply has no observable.
          This was found the honest way: the test WAS named for the
          gate, and it passed with the gate regressed from thirteen to
          nine, because all it measured was framing.

     The other seven are pinned as described in 14.2.1 and 14.2.2, and
     every one of those tests was verified by injection.


14.3  DIVERGENCES FROM THE DRIVER THAT RIPlib MAKES DELIBERATELY
---------------------------------------------------------------------

Recorded so that "RIPlib follows the driver" is a checkable claim
rather than a slogan.

14.3.1  SECURITY: '|3G' RIP_GotoURL LAUNCHES NOTHING

     The driver opens the URL.  RIPlib does not, ever, and will not be
     configured into doing so: with no handler registered the URL is
     validated and stored in rip_state_t.goto_url and nothing else
     happens.  Schemes are restricted to http:// and https://;
     javascript:, data:, file: and vbscript: are refused outright
     rather than delegated to host policy, because those are what turn
     "open a link" into code execution.  A host wanting click-through
     registers a handler and decides for itself.

     This is a deliberate refusal to match the driver's behaviour and
     is not up for reconciliation.  See "Fix SV-2/S2" in src/ripscrip.c.

14.3.2  NO FILE I/O, NO PROCESS LAUNCH

     '|2W' RIP_PortWrite, '|1W' RIP_WRITE_ICON and the file-query family
     validate their arguments the way the driver does and stop there.
     RIPlib has no filesystem.  Requests are surfaced to the embedder
     through the icon/file request queue instead.

14.3.3  '|k' RIP_BACK_COLOR ACCEPTS A ONE-CHARACTER PAYLOAD

     Slot 43 types the argument as colour-width -- two characters at the
     default colour mode -- and RIPlib also accepts one.

     This was removed to match the record exactly, and then restored,
     because the corpus contradicted the assumption behind the removal:
     of 133 '|k' commands in shipped scenes, 132 are two characters and
     one -- N2_BUSI.RIP, "|k0" -- is one.  Rejecting the short form
     would drop a command real content sends, for no gain.  The defect
     that mattered here was reading ONE digit when TWO were present,
     fixed in v2.0.1.

     The general rule this establishes: the record says what the driver
     accepts, not what content exists.  Tightening a gate to match the
     record is right by default and wrong where shipped scenes say
     otherwise, and the corpus is what tells the two apart.  See D-18.

     The rule has been applied twice.  '|=' RIP_LINE_STYLE records eight
     characters and RIPlib admits four, because all three widths the
     corpus sends are real content: of 116 '|=' commands, 107 are eight
     characters, 2 are seven and 7 are four.  The handler reads
     progressively -- off_draw and style at four, the user pattern at
     six, thickness at eight -- rather than rejecting records the driver
     would reject but shipped scenes contain.  The gate was still raised
     from two to four, which rejects truncation below anything real
     content sends.  See D-20.

14.3.4  MODES ACCEPTED BUT NOT PERFORMED

     '|1G' RIP_Scroll validates its mode field 0..6 as the driver does
     and performs the block move, which is common to all seven modes.
     Modes 1..6 additionally run post-scroll effect routines that are
     not implemented.  A scene using them scrolls correctly and loses
     the effect.  See D-14.

     '|1g' RIP_CopyBlit accepts modes 0..5 per the driver; RIPlib's
     raster ops stop at DRAW_MODE_NOT (4), so mode 5 is accepted and
     drawn as COPY.

14.3.5  '|Y' TEXT DIRECTIONS 2 AND 3

     The driver validates the direction field with cmp [ebp-8],1 / jbe
     and reports "Illegal direction" above 1, so it accepts only:

          0   horizontal
          1   BGI VERT_DIR, bottom-to-top

     RIPlib accepts two more, as its own extension:

          2   vertical CCW glyphs, top-to-bottom
          3   vertical CW  glyphs, top-to-bottom

     Every '|Y' in the corpus uses direction 0 or 1, so the extension
     displaces no shipped content.  The font number and size bounds ARE
     enforced as the driver enforces them (0..10 and 1..10); it is only
     the direction range that is wider on purpose.  See D-21.

14.3.6  SLOT PROTECTION

     The driver guards 24 command sites with twelve "its protected!"
     diagnostics covering graphics styles, colour palettes,
     environments, text windows and button styles.  RIPlib implemented
     none of those until 2026-08-14 and now implements nineteen; the
     heading of this section used to read "PROTECTION IS IMPLEMENTED
     ONLY FOR PORTS", which stopped being true in the same commit that
     made it worth reading.

     CORRECTED 2026-08-14.  This section used to call that inert, on
     the grounds that "41 commands READ the protection word at
     <state>+0x104 and no dispatched command WRITES it, so protection
     is host-side state that no RIP stream can set.  The guards cannot
     fire from content."

     THAT IS WRONG, AND IT WAS WRONG IN THE SAFE-SOUNDING DIRECTION.
     A RIP stream CAN set protection.  The second field of every
     Switch* command -- the one this project had been calling a
     reserved pair -- is a FLAGS word, and the driver acts on four of
     its bits.  From slot 111, RIP_SwitchPalette:

          test esi,4  -> paletteSlotProtect(inst, -1, 1)   before switch
          test esi,8  -> paletteSlotProtect(inst, -1, 0)   before switch
                         (the switch itself)
          test esi,1  -> paletteSlotProtect(inst, -1, 1)   after switch
          test esi,2  -> paletteSlotProtect(inst, -1, 0)   after switch

     So bits 2 and 3 protect and unprotect the slot being left, and
     bits 0 and 1 the slot being entered.  The callee is named in its
     own diagnostic -- "Cannot protect current color palette slot when
     it is #0", paletteSlotProtect() -- and each family has its own:
     styleSlotProtect(), textWindowSlotProtect(), environmentProtect(),
     colorTableProtect(), and an unnamed one at 0x100454C4 for button
     styles.  '|2B' reaches its protector through exactly the same four
     bit tests.

     This is the same mechanism already documented for '|2s' and ports.
     What was missed is that it is not special to ports: ALL SIX
     Switch* commands carry it, and RIPlib honours the flags only for
     '|2s'.

     WHAT IT MEANS IN PRACTICE.  Protection is live, writable from
     content, and unimplemented by RIPlib for five of the six families.
     A scene that protects a palette slot and then writes to it gets a
     refusal from the driver and a completed write from RIPlib.  Under
     14.6 that is the tolerable direction -- RIPlib does MORE, and
     nothing that renders correctly under the driver fails under RIPlib
     -- but it is a real divergence and no longer an inert one.

     IMPLEMENTED 2026-08-14.  RIPlib now carries a 36-bit protection
     mask per family in ripscrip2_state_t, sets it from the Switch*
     flag bits, and refuses modification at the guarded sites.

     The enforcement sites were recovered MECHANICALLY rather than
     guessed: every "protected" diagnostic string in the image was
     located, then attributed to the handler body that pushes it.  That
     yields twenty-four sites, which is the figure this section already
     quoted from a different method:

          style        '|=' '|N' '|S' '|W' '|Y' '|c' '|k' '|q' '|s' '|y'
          environment  '|J' '|M' '|f' '|n' '|1c'
          palette      '|D' '|Q' '|a' '|d'
          port         '|2P' '|v' '|1ESC'
          buttonstyle  '|1B'
          textwindow   '|w'

     TWENTY-THREE of the twenty-four are enforced.  Nineteen level-0
     sites, plus '|1B' (button style), '|1c' (environment), '|2P' (port
     redefine) and '|v' (viewport).

     '|1c' is worth a note because the pairing looks wrong and is not.
     RIPlib calls it RIP_SetMouseCursor and the diagnostic it guards on
     is "Can't modify current environment - its protected!".  Slot 90
     settles it: it calls the ENVIRONMENT protection query at
     0x1003D9E1 and names itself RIP_SetMouseCursor() in the same error.
     The pointer is environment state in this driver's model.

     '|v' TOOK A PREREQUISITE, and it is the more interesting half.  Its
     query at 0x10033821 passes index -1, which that routine reads as
     "the current entry": it tests the protected bit at +0x17 of a
     0x78-stride table.  So '|v' refuses on a protected CURRENT port.

     Guarding it directly would have broken shipped content.  RIPlib
     marked port 0 RIP_PORT_FLAG_PROTECTED, and all three '|v' commands
     in IMAGES.RIP run with port 0 active -- the driver renders that
     scene, so port 0 cannot be protected in the sense '|v' tests.
     RIPlib was conflating two different properties in one flag:

          PERMANENT   slot 0 alone; cannot be deleted or redefined,
                      and no stream can set or clear it
          PROTECTED   set by CONTENT through the Switch* flag bits;
                      blocks modification

     Separating them was the prerequisite.  Port 0 now carries
     PERMANENT; delete and redefine refuse on either; '|v' refuses on
     PROTECTED alone.  IMAGES.RIP renders byte-identically before and
     after -- 91237 foreground pixels either way, checked rather than
     assumed.

     ONE IS STILL NOT GUARDED.  '|1ESC' rip_query: its diagnostics --
     "Port is protected - can't define query", "Text window is
     protected - can't define query" -- are about DEFINING a query
     rather than answering one, and which of RIPlib's query paths that
     corresponds to has not been established.
     Everything starts unprotected, so the guards are inert until a
     stream opts in -- which is why turning them on changed nothing for
     the 35 corpus scenes or the 315 assertions.  The driver reports a
     diagnostic and draws nothing; RIPlib draws nothing and stays
     silent, having no diagnostic channel.

     Pinned by "|2Y protects a style slot and |W then refuses", which
     walks the whole loop: switch with no flags and the write lands,
     switch with bit 0 and it is refused, switch with bit 1 and it lands
     again.  The unprotected leg is first on purpose -- a guard that is
     simply always-on fails there rather than passing quietly.
     PORT protection RIPlib does implement -- port 0 permanently,
     '|2s' bits 0..3 to protect and unprotect the destination and
     source ports, and create/delete refusing a protected port.  The
     bit assignment above is the same one.  See D-22.

14.3.7  APPROXIMATED HIT AREAS

     '|:' RIP_MOUSE_REGION_EXT defines a five-vertex region.
     rip_mouse_region_t holds a rectangle, so RIPlib registers the
     BOUNDING BOX of the five vertices: a conservative
     over-approximation for hit-testing rather than a rectangle invented
     from two of the coordinates.  See D-14.

14.3.8  COMMANDS NOT IMPLEMENTED

     '|`' -- slot 83, argc 11 (XY x10 + mega1).  Its handler (RVA
     0x01D963) is structurally identical to '|:' RIP_MOUSE_REGION_EXT:
     the same call sequence, five consecutive coordinate-pair maps, then
     SetBkMode.  It is evidently a sibling of that command, but it
     carries no name in the export table and no shipped scene uses it,
     so its semantics cannot be established.  Recorded rather than
     guessed.

     Level 2 '|2C' RIP_PortCopy, '|2R' and the Switch* family ARE
     implemented; see D-17.

14.3.9  RIPlib-ORIGINAL COMMANDS

     TWENTY commands RIPlib documents have no dispatch entry at all.
     This section previously named four of them, which understated the
     extension surface fivefold; the full set is below, obtained by
     subtracting the driver's letter set per level from the letters the
     spec chapters document.

          level 0    '|^'  '|~'
          level 1    '|1N' '|1O' '|1Q' '|1S' '|1V' '|1X' '|1Z'
          level 2    '|20' '|22' '|23' '|24' '|25' '|26' '|28'
                     '|2c' '|2F'
          level 3    '|3&' '|3-'

     The driver's own letters, for comparison:

          level 0    ! " # & ( ) * + , - . : ; < = > @
                     A-Z [ ] _ ` a-z {
                     (74 letters + 11 continuation rows = 85 records)
          level 1    A B C D E F G I K M P R T U W b c e g i k p t w
                     and ESC          (24 letters + ESC = 25 records)
          level 2    A B C E P R T W Y p s
                     and ESC          (11 letters + ESC = 12 records)
          level 3    D G R U e
                     and ESC           (5 letters + ESC =  7 records)

     Record counts exceed letter counts because of the continuation
     rows described in 12.11 -- extra argument signatures sharing a
     handler -- and because level 3 records '|3D' twice, under two
     different handlers.

     Note that level 0 DOES carry '|N' RIP_SetBorder, at slot 48, and
     that RIPlib implements it there.  RIPlib's '|1N' RIP_SET_ICON_DIR
     is a different command that happens to share the letter, and it
     is the LEVEL 1 one that is RIPlib-original.  Revisions of
     13-dll-command-table.md before 2026-08-13 filed slot 48 under
     Level 1 as '|1N', which made level 0 look as though it were
     missing an 'N' and made '|1N' look driver-backed; both readings
     were wrong.

     D-23 in 12-dll-provenance.md had already recorded that "'|1Z',
     '|1N' and '|1O' have NO dispatch entry at all".  That was correct
     and the dispatch table contradicted it for months without either
     being reconciled, because no check compared the two.  Two
     documents in the same repository disagreeing is exactly the class
     of defect that survives review by prose alone.

     None of the twenty displaces a driver command: every one of those
     letters is absent from its level's set, so a stream written for
     the driver cannot collide with a RIPlib extension.  They are
     documented as extensions in 11-dll-deviations.md DEV.4.

     Verify this list with scripts/check-spec-examples.py, which
     reports every documented command whose letter has no dispatch
     entry rather than passing it silently.


14.3.10  COMMANDS THE DRIVER ACCEPTS AND IGNORES

     Three dispatch entries point at a handler that is a single RET
     instruction.  The driver parses the command, dispatches it, and
     does nothing:

          slot   0   '|!'   0x01ad36
          slot   4   '|('   0x01ca84
          slot  27   '|F'   0x01b2fd

     '|F' RIP_FILL is the one that matters.  Flood fill is a NO-OP in
     RIPSCRIP.DLL 3.00.04.  RIPlib implements it fully - x, y and
     border as three two-digit fields, per the v1.54 specification and
     corroborated by IcyTerm's parser, which reads six base-36 digits
     for '|F'.

     This is a deliberate divergence in the direction of DOING MORE
     than the driver, and it is safe in the way the '|Y' direction
     extension is safe: content written for the driver expects nothing
     to happen, and content written for a conforming client gets the
     fill.  Nothing that renders correctly under the driver renders
     incorrectly under RIPlib because of it.

     Note also that an argc of 0 with no argument types does not imply
     a command takes no payload -- '|T' has argc 0 and parses a string
     itself.  Ten of the thirteen argc-0 entries have real bodies.
     Only a bare-RET body proves a command is inert.


14.4  WHAT THIS REGISTER IS FOR
---------------------------------------------------------------------

A claim of conformance is only as good as the set it was measured over,
and every count in this file is reproducible from the scripts in 14.1 --
which became true of section 14.2 only on 2026-08-13, when the tool that
produced those counts was moved into the repository.  Before that this
sentence was an overclaim about the very section most likely to be
challenged.

FIVE findings in this project came from measuring the MEASUREMENT rather
than the code:

  * The field-list comparison read only the first line of each handler
    comment, silently truncating any signature that wrapped.

  * It dropped every CONTINUATION row of an overloaded command -- rows
    whose letter byte is 0x00, identified only by sharing the named
    entry's handler pointer -- so '|h' presented as one signature
    instead of six, and '|t', '|x' and '|z' as one instead of three.

  * An elided field list in a reference ("c1:2 c2:2 ... c16:2") yields
    only the pairs literally written, which reported '|Q' as a 32-vs-6
    divergence where the reference in fact agrees.  Ten commands are
    elided this way; scripts/ref-compare.py now names them on every run
    rather than dropping them silently, because a skipped comparison
    that is not reported reads exactly like an agreement.

  * The same comparison carried hardcoded switch-block line numbers.
    They went stale as src/ripscrip.c grew, so it bracketed the wrong
    code and reported three RIPlib divergences that did not exist --
    '|R' showing '|1R's record.  Boundaries are derived now.

Each of those would have overstated or understated this register.  The
counts here are 13 divergences from bbs-land, 7 of them affecting the
total width -- reproduced twice by independent paths.

The fifth is worth recording separately because it is a different SHAPE
of instrument fault.  The level split quoted in
13-dll-command-table.md was checked by grouping that file's rows by
its own level column and counting the groups.  That can verify a
count but never a MISFILED ROW: slot 48 sat under Level 1 as '|1N',
and two successive corrections of the split (83/26/12/8, then
84/26/12/7) both preserved the misfiling because both measured the
same wrong grouping.  The true split is 85/25/12/7.  A check that
takes its partition from the artefact under test cannot find an error
in that partition; scripts/check-dll-table.py now verifies that each
level is a contiguous slot run and that every row is spelled with its
section's prefix, which is independent of the grouping.


14.5  RECOVERED NAMES THAT CONTRADICT RIPlib'S
---------------------------------------------------------------------

Handlers that can report an error push their own name string before
calling the error reporter, so a name recovered that way is strong
evidence -- stronger than any secondary reference.  Thirty-nine
commands are named on both sides.  Thirty-seven agree once naming
style is normalised ('RIP_ExtendedTextWindow' against
'RIP_EXT_TEXT_WINDOW', 'RIP_FilledPolygon' against
'RIP_FILL_POLYGON', and so on).

TWO did not.  ONE IS NOW RESOLVED, AGAINST RIPlib:

     command   handler self-name      RIPlib's name (before 2026-08-14)
     -------   ------------------     --------------------------------
     '|1A'     RIP_SelectArticle      RIP_PLAY_AUDIO      <- was WRONG
     '|1N'*    RIP_SetBorder          RIP_SET_ICON_DIR

     * slot 48 is LEVEL 0 '|N'; see 14.3.9.  RIPlib's level-1 '|1N' has
       no dispatch entry, so that row is a collision of letters rather
       than a contradiction.

'|1A' WAS NOT A NAMING DISAGREEMENT.  It was RIPlib being wrong, and
this register said the field layout was settled and only the semantics
were open -- which understated it.  Disassembling slot 86 (RVA
0x00DC58) settles it outright:

     mov  edi,[eax]          ; args[0], and nothing else
     cmp  edi,0x24           ; 36
     jb   ok
     push "Invalid article number"
     push "RIP_SelectArticle()"
 ok: push edi / push esi / call 0x1003C399

The handler loads ONE argument, bounds it to 36 -- an index into a
36-entry table, the same size as the port and style tables -- and never
touches args[1] or any string.  The callee walks an instance-held table
at [inst+0x2A]+0x16.  There is no filename, no buffer and no sound API
anywhere in it.

Three independent lines agree:

  * the driver's REAL audio command is '|1w', slot 109 (RVA 0x00D24E),
    whose handler pushes the name string "RIP_PlayAudio", takes the
    string tail, compares it against "$OFF$" to stop playback, and sits
    in an image that imports sndPlaySoundA and PlaySoundA from WINMM;

  * "article" is a document-navigation term in this driver --
    tvarProcOVERFLOW(article,PREV,SETVERBOSE) appears beside "Beginning
    of document" and "End of document";

  * the single '|1A' in the shipped corpus is in NEWS.RIP and selects
    article 1.

RIPlib had the two commands swapped: '|1A' pushed a sound request for
text it read as a filename, and '|1w' was a bare 'break'.  Both are
corrected, and both now have tests.  No corpus scene was affected --
NEWS.RIP sends exactly the six fixed characters and no filename, so the
wrong path emitted nothing.

WHY THIS SURVIVED EVERY PREVIOUS AUDIT.  Slot 86 had a recovered NAME in
13-dll-command-table.md and a confident comment in src/ripscrip.c
asserting "DLL: calls ripAudioPlay() which invokes CB_PLAY_SOUND".
Neither was checked against the handler's instructions.  A recovered
name tells you what a handler CALLS ITSELF; it does not tell you what
the handler DOES, and a comment asserting driver behaviour is worth
exactly as much as the reading behind it.  See 14.7.

Regenerate this comparison by extracting the NAME column of
13-dll-command-table.md and the leading identifier of each 'case'
comment in src/ripscrip.c, then normalising both to lower case with
'rip_' and underscores stripped.


14.6  THE COMPATIBILITY CONTRACT
---------------------------------------------------------------------

Everything in 14.3 is a place where RIPlib deliberately differs from
the driver.  That is only defensible under a rule, and the rule is
this: THE SYNTAX IS SHARED, SO AN EXTENSION MUST NEVER COST A CLIENT
THAT DOES NOT IMPLEMENT IT ANYTHING BUT THE EXTENSION ITSELF.

A BBS does not know which terminal is connected.  If content carrying
a RIPlib extension corrupts the frame for a stock RIPterm, the
extension has not enhanced the protocol -- it has forked it.  So:

  1. ADDITIVE ONLY.  An extension may add a command, widen an accepted
     range, or implement something the driver stubs.  It may not
     change the meaning of any byte sequence the driver already
     defines.  A stream that renders correctly under the driver must
     render the same way under RIPlib.

  2. UNUSED LETTERS ONLY.  Every RIPlib-original command uses a letter
     absent from the driver's set AT ITS LEVEL (14.3.9 lists both sets
     for comparison).  Nothing is displaced, so a driver-targeted
     stream cannot collide with an extension.

  3. SKIPPABLE.  An unknown command must cost the frame nothing.  This
     is a property of the framing rather than of any command: a
     payload runs until '|', CR or LF, and NOTHING IN THE STREAM
     STATES ITS LENGTH.  A parser that does not know a letter still
     knows where the command ends.

     This is load-bearing in both directions and is easy to break by
     accident -- consuming a fixed argument count from the dispatch
     record instead of scanning to the delimiter would be a natural
     "optimisation" and would desynchronise on every extension anyone
     ever adds, RIPlib's or another implementation's.  Three tests in
     tests/test_ripscrip.c pin it:

          an unknown command letter is skipped, not desynchronised past
          every RIPlib-original command leaves the stream in sync
          a known command with a longer payload than its record still
              ends at '|'

     The second feeds all twenty originals and checks the NEXT command
     still takes effect.  It deliberately measures a state change and
     not a drawn pixel: '|1V' legitimately sets a viewport that clips
     everything, so a missing pixel would prove nothing about sync.
     The third covers a future revision widening a field, so that new
     content degrades on an old client instead of breaking it.

  4. DEGRADES, DOES NOT BREAK.  A client that skips an extension
     should lose only that effect.  '|Y' directions 2 and 3 give
     rotated glyphs where the driver reports "Illegal direction";
     '|F' fills where the driver does nothing (14.3.10); '|^' and '|~'
     push and pop state a stock client simply never restores.  In each
     case the omission is visible as plainer output, not as a wrong
     frame or a lost stream.

     The honest limit: skipping a STATE-CHANGING extension leaves the
     stock client in a state RIPlib would have restored.  Content that
     relies on '|^'/'|~' to bracket a colour change will leave that
     colour set on a client that ignores them.  Authors targeting
     mixed audiences should restore state explicitly rather than
     depend on the stack.

  5. RIPlib EMITS NO RIPscrip.  The library renders and parses; it
     does not generate protocol.  Its only outbound traffic is host
     callbacks -- file and asset requests, sound markers -- on a
     private queue, never on the wire as RIPscrip.  So RIPlib cannot
     put an extension in front of a terminal that did not ask for one;
     that is a content-authoring decision, and this section is the
     guidance for whoever makes it.

The bbs-land divergences in 14.2 are a different matter and this rule
does not license them: those are places a reference and the driver
disagree about EXISTING syntax, where following the driver is
conformance rather than extension.


14.7  WHAT HAS ACTUALLY BEEN DISASSEMBLED
---------------------------------------------------------------------

'|1A' was wrong for months while carrying a recovered NAME in
13-dll-command-table.md and a confident comment in src/ripscrip.c
describing driver behaviour it had never been checked against.  Nothing
in this project had read its instructions.  That is a coverage gap, not
bad luck, so it is measured here rather than left to be rediscovered.

A recovered name tells you what a handler CALLS ITSELF.  It does not
tell you what the handler DOES.  '|1A' names itself RIP_SelectArticle
and RIPlib called it RIP_PLAY_AUDIO for months with the name sitting
right there in the table.

MEASURED 2026-08-14.  Of the 129 dispatch entries, 66 have their handler
address cited somewhere that REASONS about it -- src/ comments, segment
12, this register, an ADR.  63 do not.  (Counting citations in
13-dll-command-table.md instead gives 129 of 129, because that file
lists every address mechanically; a coverage metric that reads its own
index as evidence measures nothing.)

Sixty-three is not sixty-three risks, but it is not thirteen either,
and an earlier draft of this section overstated the comfort.  It said
the rest are "validated by the corpus replay every time a scene
renders".  That is true only of handlers the corpus actually
EXERCISES.  Thirteen draw and appear in no shipped scene at all, so
nothing checks them from either direction:

     |Q  |,  |b  |.  |{  |A  |I  |C  |g  |m  |>  |H  |T

They are a milder risk than the nine below -- a misread drawing
primitive produces wrong pixels, not wrong host behaviour, and it
cannot silently emit traffic the way '|1A' did -- but "milder" is not
"covered".  '|Q' was read on 2026-08-14 and immediately supplied the
missing half of 14.3.6.

The '|1A' profile is narrower and much more dangerous:

     NOT a drawing primitive  -- nothing renders, so pixel replay is
                                 blind to it
     ZERO corpus uses         -- no shipped content exercises it either
     RIPlib does something    -- host traffic, session state, an asset
                                 request: a behaviour that can be wrong
Nine handlers match it exactly, and they are the audit queue:

     cmd    slot   handler     what RIPlib currently claims
     ----   ----   ---------   -------------------------------------
     |1F     94    0x00bde4    file query      AUDITED -- defect found
     |2A    111    0x046c64    switch palette  AUDITED -- defect found
     |2B    112    0x046d08    switch button   AUDITED -- same finding
     |2E    114    0x046da0    switch env      AUDITED -- same finding
     |1I     97    0x00cb38    load icon
     |1W    108    0x00dd67    write icon to cache
     |2A    111    0x046c64    switch palette slot
     |2B    112    0x046d08    switch button style
     |2E    114    0x046da0    switch environment
     |2T    119    0x046ece    switch text window
     |2W    120    0x04699a    port write to bitmap
     |2Y    121    0x046e41    switch graphics style

The first has been done and found a defect on the first read: slot 94
bounds its mode with 'cmp ebx,4 / jbe', reporting "Invalid mode
parameter" above four and answering NOTHING.  RIPlib decoded the mode
and discarded it -- there was a literal '(void)mode;' -- so it replied
to queries the driver refuses.  A query reply is host-visible traffic,
which makes that the same defect class as a loose length gate.  Fixed,
with a test.

That is one defect in one handler, on the first look at a queue of
nine.  Expect more.

The same sweep also looked at the protection word.  '|1F' and '|1W'
both READ <inst>+0x104 and bail out when it is set, which is the read
side of 14.3.6 confirmed by direct inspection.  The WRITE side is where
14.3.6 was wrong, and the Switch* audit below is what found it.

AUDIT LOG -- QUEUE COMPLETE.  All nine audited, four findings.

  '|1F'  mode bound.  Slot 94 refuses a mode above 4 and answers
         nothing; RIPlib decoded the mode and discarded it.  FIXED.

  '|1I'  the second 'res' is a STRETCH flag.  Slot 97 bounds args[5]
         -- payload offset 7 -- with 'cmp dword [ebp-0x10],1 / jbe' and
         reports "Invalid stretch parameter" above one, drawing nothing.
         RIPlib called that column reserved, "meaning not recovered",
         which was true only in the sense that nobody had looked.  The
         refusal is now implemented; stretching itself is not, and
         RIPlib still blits at native size.  args[3] at p[5] and args[6]
         at p[8] remain genuinely unexamined.  FIXED.

  '|2A' '|2B' '|2E' '|2T' '|2Y'  the second field is not a reserved
         pair but a flags word that WRITES protection state, refuting
         what 14.3.6 used to say.  All five share one shape: protection
         check, slot bound of 36, then the four bit tests.  '|2T' errors
         with "Illegal text window slot number"; '|2Y' rejects
         out-of-range slots SILENTLY, with no diagnostic at all, which
         is consistent with its unnamed row in segment 13.  Documented,
         not implemented -- see 14.3.6.

  '|1W'  identity confirmed by behaviour rather than by name.  The
         handler indexes a 120-byte-per-entry table through a 16-bit
         current-item field where -1 means nothing to write, which is
         the clipboard-to-named-cache-entry reading RIPlib already had.
         It also extracts two flag bits from args[0], which RIPlib
         treats as reserved.  Not fixed: the bits' meaning is not
         established, and guessing is what this register exists to
         prevent.

  '|2W'  no change.  RIPlib writes no file, so there is nothing for the
         handler's behaviour to diverge from.

Nine handlers, four findings, two of them fixed with tests and two
recorded as unimplemented features.  The hit rate justified the sweep.

NEXT QUEUE -- the thirteen that draw and are unexercised, listed
above.  '|Q' is done and produced the missing half of 14.3.6.  Twelve
remain: '|,' '|b' '|.' '|{' '|A' '|I' '|C' '|g' '|m' '|>' '|H' '|T'.
     '|Q'  DONE.  Supplied the missing half of 14.3.6 -- the query at
           0x10044508 and '|Q's refusal, "Can't modify current color
           palette - its protected!".

     '|,'  DONE, one finding.  The trailing pair is NOT reserved.  Slot
           8 loads all ten arguments and passes FIVE pairs through the
           coordinate transform at 0x10031084 -- (a0,a1) (a2,a3)
           (a4,a5) (a6,a7) (a8,a9) -- so the driver treats the last two
           as a coordinate pair like the rest.  RIPlib's comment called
           them 'res:2 res:2' and the code ignores them.

           WHAT they mean is not established.  Five pairs for a region
           copy could be source rect, destination rect and an anchor,
           but that is a guess.  Recorded, not invented.  No shipped
           scene sends '|,', so nothing observable depends on it.

     '|b'  DONE, and the largest field finding of the audit.  Slot 20
           names itself RIP_ExtendedTextWindow() in five diagnostics and
           validates four fields:

                args[7] > 0x3FF   "Flags value is out of range"
                args[6] >= 5      "Font number is out of range"
                                  (unless flags bit 3 is set)
                args[4] == 0      "Zero width value is not allowed"
                args[5] == 0      "Zero height value is not allowed"

           then queries text-window protection at 0x10027642.

           RIPlib read args[4] and args[5] as FOREGROUND and BACKGROUND
           COLOURS and args[7] as a font SIZE.  They are a cell width, a
           cell height and the flags word.  A colour index does not
           produce "Zero width value is not allowed", and that single
           string is what unpicked three fields at once.

           Nothing rendered from the mistake: etw_fore_col and
           etw_back_col were written here and read nowhere, and no
           corpus scene sends '|b'.  The TEST was wrong in the same
           direction as the parser -- it asserted etw_fore_col == 15,
           and its payload carried height = 00, so under the corrected
           reading the driver would refuse the very command the test
           called success.  A test written from the same mistaken
           premise as the code confirms the premise, not the code.

           All four validations and the protection guard are implemented
           now, making '|b' the twenty-fourth enforcement site.

     THE REMAINING TEN ARE AUDITED AND CLEAR: '|.' '|{' '|A' '|I' '|C'
     '|g' '|m' '|>' '|H' '|T'.

     None of them pushes a diagnostic string, which matches their
     unnamed rows in segment 13 and means there is no bounds check or
     protection refusal for RIPlib to be missing -- the whole class of
     finding that '|1F', '|1I' and '|b' produced cannot exist here.
     '|.' and '|{' each transform three coordinate pairs and draw;
     ref-compare.py already confirms every field count and width against
     the record.

     What remains unsettled for them is which coordinate means what
     within a set -- whether six arguments are three points or a centre
     plus radii plus angles.  Settling that needs each transform's
     consumers traced, and the expected yield is low: there is no
     diagnostic to contradict a wrong reading, no corpus scene to render
     one wrongly, and no host traffic to emit.  The cheap evidence is
     exhausted, and saying so is better than grinding on and reporting
     the grind as coverage.

     ONE OBSERVATION FELL OUT AND WAS RESOLVED.  Every drawing command
     calls 0x1003445B before doing anything, and that routine reads the
     SAME port-flag byte as '|v's protection query -- <inst>+0x22,
     stride 0x78, offset +0x17 -- but tests BIT 1 rather than bit 0,
     with every caller returning early when it is set.

     Bit 1 is an EMPTY-REGION marker.  The four writers of that bit are
     at RVA 0x033D18 and 0x033F3D (set) and 0x033D76 and 0x033F4C
     (clear), and the setter is reached only after

          cmp [ebp+0x10],eax / cmp [ebp+0x14],eax / cmp [ebp+0x18],eax

     with eax zero -- that is, when all four rectangle coordinates are
     zero.  Otherwise the routine builds a real rect.  So an all-zero
     '|v' viewport marks the region empty and everything after it is
     suppressed, which IS reachable from content.

     RIPlib has no such flag: it stores the rectangle and lets the clip
     do the work.  The OUTCOME agrees, which is what content depends on,
     and that is now pinned by "an all-zero |v viewport suppresses
     drawing, as the driver does".  No code change was needed -- but
     that was checked rather than assumed, which is the whole point of
     writing the test instead of reasoning that a degenerate clip
     rectangle probably clips everything.

     Note the asymmetry this closes: bit 0 of that byte is set by
     CONTENT through the Switch* flags and needed implementing; bit 1 is
     set by the driver's own geometry handling and needed only
     confirming.  Same byte, different provenance.

14.7.2  WHAT THE COMPARISON CANNOT SEE

     '|1<ESC>' carried a five-character prefix against the record's four
     for months, in the Level 1 command with the MOST corpus traffic --
     eighty uses.  It survived because ref-compare.py could not see it
     from EITHER side: the RIPlib extractor matched `case 'X':` and that
     arm is `case 0x1B:`, while the driver loader filtered letters to
     0x20..0x7E and dropped ESC.  Two independent filters, one blind
     spot.

     That generalises, so the blind spots were then measured rather than
     waited for.  Of 99 driver commands with a comparable record, the
     tool was comparing 55.  FORTY-FOUR were invisible, and the biggest
     group was structural: EVERY Level 2 command, because load_riplib()
     read only src/ripscrip.c while Level 2 lives in src/ripscrip2.c and
     spells its cases `case RIP2_CMD_PORT_COPY:`.  Level 2 is also where
     the Switch* protection flags had to be found by hand -- which is
     the job a comparison exists to do.

     Both gaps are closed; coverage is 64.  The fix found nothing new,
     which is the desirable outcome and not evidence the exercise was
     pointless: the two differences it first reported ('|2C' and '|2P')
     were the NEW extractor truncating a wrapped signature -- the exact
     fault signature_block() had already been written to avoid for levels
     0 and 1, reintroduced in the new code path.  A lesson learned in one
     function does not transfer to the next one by itself.

     TWENTY-SEVEN REMAIN INVISIBLE, listed so the number is not
     mistaken for zero:

          |: |A |C |I |O |Q |V |` |a |g |h |i |m |t |v |w |x |y |z
          |{ |1b |1e |1t |2ESC |2R |2s |3ESC

     Coverage went 55 -> 64 -> 69 -> 72 across 2026-08-15.  '|L' is
     worth naming: 7565 occurrences, the most-used command in the
     shipped corpus, invisible to the comparison until then.  The two
     commands with the HIGHEST corpus traffic, '|L' and '|1<ESC>', were
     both unseen by the tool meant to check them.  That is not a
     coincidence: a command nobody was forced to write a field layout
     for is a command where a wrong layout survives.

     TWO WAYS IN, and the distinction matters.

     Writing a NEW signature means reading the handler and describing
     what the code does.  Copying the record into the comment instead
     would make the comparison agree with itself, report a higher
     number, and check nothing -- strictly worse than leaving the
     command uncovered, because the number would then be misleading.

     MOVING an existing signature to the first line adds no claim at
     all.  Several commands already carried a field list two or three
     lines down, where the extractor stops at the preceding sentence
     break and never reads it.  Relocating it does not assert anything
     new -- it SUBJECTS AN ALREADY-UNVERIFIED CLAIM TO VERIFICATION,
     which is the opposite of the sweep this section warns against.
     '|1U', '|1B' and '|s' were moved on that basis and all three agree
     with the record.

     '|h' is left alone deliberately.  It carries SIX accepted
     signatures on one handler, so any single line would misrepresent
     it; that is what the continuation rows in 12.11 exist to describe.

14.7.3  THE CHECKERS' OWN COVERAGE

     Having measured ref-compare.py's blind spots (14.7.2), the same
     question was put to dll-conformance.py.  Its verbose output already
     reported "9 without a numeric gate" -- nine commands whose length
     gate it cannot verify -- and that number had never been read as a
     coverage figure.

     ONE OF THE NINE WAS A REGRESSION I HAD JUST INTRODUCED.  The
     checker reads a handler body only as far as a bare `break;`, and
     the protection guard added to '|v' was written across two lines:

          if (... & RIP_PORT_FLAG_PROTECTED)
              break;

     so the body it saw ENDED at that break and the `len >= 8` gate
     below became invisible.  The eighteen other guards escaped only
     because they happen to be written on one line.  A checker that
     depends on the formatting of the code it checks loses coverage
     without saying so.

     Both halves fixed: the guard is one line like the rest, and the
     extractor now requires the break to be at the case body's own
     indent rather than matching any bare `break;`.  Gate coverage went
     72 to 73 and read-offset coverage 69 commands to 70.

     THE REMAINING EIGHT ARE NOT DEFECTS, and are listed so the number
     is not read as one:

          |O            falls through to '|V', where the gate lives
          |3G |1R |3R   gate inside a shared helper
          |x |z |t      the poly-bezier family, which dispatches BY
                        length across several accepted signatures, so a
                        single numeric gate would be wrong
          |1t           the record needs one character

     They are reported rather than suppressed because a suppressed
     exception is indistinguishable from a check that passed.

14.7.1  A CAVEAT ON HANDLER SELF-NAMING

     14.5 calls a name recovered from a handler's own error path
     "strong evidence -- stronger than any secondary reference".  That
     holds only when the name is UNIQUE to that handler, and three are
     not.  Measured across the fifty names in segment 13:

          RIP_TextXY              pushed from 0x01a0da and 0x020cbc
          RIP_Polygon             pushed from 0x01eb03 and 0x01ed28
          RIP_ExtendedFontStyle   pushed from 0x00dd67, 0x01adc0,
                                  0x024b4e and 0x046bd9

     The last spans all four level bands, so it is plainly a
     copy-pasted error-reporter argument and identifies none of them.
     It is why '|1W' has no recovered name: the string in its error
     path belongs to '|y'.

     Segment 13 already handles this correctly -- it attributes
     RIP_TextXY to '|@' and not to '|"', RIP_Polygon to '|P' and not to
     '|l', RIP_ExtendedFontStyle to '|y' alone, and leaves '|1W'
     blank.  The argument-type records agree in each case.  So this is
     a caveat on the METHOD, not a correction to the table.

     Measuring it took two attempts, and the first was wrong in a way
     worth recording: counting REFERENCES to a name string reported 24
     of 50 as shared, because a handler with eight error paths pushes
     its own name eight times.  Attributing each reference to the
     handler body containing it gives three.  A count of the right
     thing measured the wrong way was eight times too alarming.
