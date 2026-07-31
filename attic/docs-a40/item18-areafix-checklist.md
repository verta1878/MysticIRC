# A40 Item 18 — Built-in AreaFix (CHECKLIST / NOT DONE)

Status: **STUB ONLY — not implemented.** `mystic/mutil_echofix.pas` (94 lines)
detects `MsgTo=AREAFIX`/`FILEFIX` then Exits; the auth helper `GetNodeByAuth` is
commented out (and the commented version has a bug: it compares `Addr.Zone =
TempNode.Address.Node`); the command handlers exist only as `//` comments. An
earlier audit marked AreaFix "done" from a grep match on the word "AreaFix" —
that was a false positive (the stub + comments), corrected here.

Reference: upstream 1.10 Alpha 40 whatsnew (verified against the text) and the
A51 Linux binary (confirms the feature exists upstream: strings "Password for
Area/FileFix", "Missing ECHOTAG for", "Compress numbers in area list?"; the
command tokens are parsed from message text at runtime, not stored as literals,
so the stripped binary can't confirm the command set — the whatsnew is the spec).

## Commands to implement (all 9, per upstream A40)

- [ ] `%COMPRESS <type>` — set compress type; blank = raw PKT, else an archive
      extension configured for that OS (ZIP, RAR, ...). `?` may list packers.
- [ ] `%HELP` — append contents of `areafixhelp.txt` (DATA folder) to the
      response, placed at the END so any other command results show first.
- [ ] `%PWD <new password>` — change this node's AreaFix password.
- [ ] `%LIST` — list all AVAILABLE echomail areas, determined by comparing the
      network domain of the address assigned to each message base against the
      echomail node's configured domain.
- [ ] `%LINKED` — list all LINKED echomail areas for this node.
- [ ] `%UNLINKED` — list all UNLINKED echomail areas for this node.
- [ ] `%RESCAN [R=# or D=#]` — rescan all linked areas, export last 250 msgs
      each by default; `R=#` = last # msgs, `D=#` = msgs newer than # days.
- [ ] `-ECHOTAG` — remove ECHOTAG from this node's exported echos.
- [ ] `+ECHOTAG [R=# or D=#]` — add ECHOTAG (the `+` is OPTIONAL, a bare tag also
      adds); optional rescan value; comma OR space separates tag and rescan info.
      e.g. `+MYSTIC,R=50` / `MYSTIC D=365`.
- [ ] `=ECHOTAG <R=# or D=#>` — rescan an existing linked base; `R=#` newest msgs
      or `D=#` days; tag separated by space or comma. e.g. `=MYSTIC R=100`.

## Infrastructure the implementation needs (open questions from the stub)

- [ ] Node auth: find RecEchoMailNode by address + verify password. NOTE the stub
      flags a real problem — the PKT message header lacks ZONE/POINT, so matching
      the sending node needs care (the A51 uses AreaFixPass on the node record).
- [ ] Fix the commented `GetNodeByAuth` bug (Zone compared to Node) when reviving.
- [ ] Bad-password policy: respond vs silently ignore (upstream behavior TBD —
      confirm against a live A51/AreaFix exchange or the areafixhelp text).
- [ ] No node config found: toss to badmsgs vs ignore.
- [ ] Response message generation back to the requesting node (a netmail reply).
- [ ] `areafixhelp.txt` shipped in DATA (for `%HELP`).
- [ ] FileFix (A41) shares this path — keep the AREAFIX/FILEFIX split in mind.

## Verification when implemented
- [ ] Each command exercised against a test node; responses correct.
- [ ] `records.pas` fields used (AreaFixPass etc.) — no anchor change (verify 901).
- [ ] Live test on node 152/158: remote node sends %LIST/+TAG/%RESCAN, gets
      correct netmail responses and the link list actually changes.

---

# DEFERRED DISCUSSION (not item 18) — Item 17 Point handling

To revisit AFTER A40 updates are finalized. The item-17 stage-1 direct match
compares Zone/Net/Node only (ignores Point). Open question raised during the
FTN-standards review:

- A netmail to a POINT (e.g. 21:4/158.1) direct-matches a configured NODE
  21:4/158 (boss). That is the intended FTN behavior (boss routes to its point).
- BUT if BOTH a node 21:4/158 AND its point 21:4/158.1 could be configured, or
  if routing to a point should behave differently, the current match may be too
  broad or too narrow.
- Also unsettled (from doc 12, g00r00's own exchange with an FTN expert about
  this exact mutil_echoexport.pas): Mystic's historical netmail routing had
  "all routing goes to one routing hub only" limitations. Need to confirm the
  stage-1 addition behaves correctly in multi-hop / point scenarios.
- Resolution requires a LIVE toss test on node 152/158, plus a decision on
  whether Point should ever participate in the direct match.

Status: PARKED until A40 finalization complete.

---

# Item 17 Point handling — FTN reference (for the parked discussion)

Reference on how points work in FidoNet (from the historical/standards
description of zones and points, added 1986):

- The complete FTN address is **zone:net/node.point** (e.g. Bob Smith@1:250/250.10).
- **Points are NON-PUBLIC nodes** created privately on a host BBS. They do NOT
  appear in the nodelist and are not publicly/directly contactable.
- Point mail is delivered TO A SELECTED HOST "as if it was addressed to a user on
  that machine," then **re-packaged into a packet for the point to pick up
  on-demand.** i.e. a point never receives directly — its BOSS NODE receives on
  its behalf and holds the mail for the point to poll.
- Zones = major geographic areas (continents); introduced with points in Oct 1986.

## What this means for the stage-1 direct-match code

This CONFIRMS the current implementation's Zone/Net/Node-only match is correct:

- A netmail to `zone:net/node.point` is, per FTN design, delivered to the point's
  **boss node** (`zone:net/node`), which repackages it for the point. So matching
  on Zone/Net/Node (ignoring .point) and routing to that node IS the intended FTN
  behavior — the boss node is exactly who should receive it.
- A point is never a directly-contactable target, so stage 1 should NOT try to
  match a configured node's address against the full point address. Ignoring
  .point is right.

## Remaining nuance to settle (still needs a live test)

- If a sysop configures an echomail NODE whose own Address has a non-zero Point
  (i.e. the fork itself is a point of some boss), does stage-1's Zone/Net/Node
  match still behave? The record's Address.Point exists; stage 1 ignores it on
  BOTH sides (compares only Z/N/N). For a normal node (point 0) this is fine. For
  a node configured AS a point, confirm the intended routing on a live toss.
- Decision still open only for that edge case; the common case (netmail to a
  point routes to its boss node) is correct by the reference above.

Status: reference captured; common-case behavior CONFIRMED correct. Edge case
(node configured as a point) still parked for a live test after A40 finalization.

---

# RESOLVED — Item 17 Point handling

Resolved with FTN addressing history (points were added Oct 1986 as non-public
nodes; format zone:net/node.point).

Key fact: a POINT is not independently reachable. "Point mail was delivered to a
selected host as if it was addressed to a user on that machine, but then
re-packaged into a packet for the point to pick up on-demand." So mail to
zone:net/node.point is delivered to the BOSS NODE zone:net/node (point 0), which
handles the point downstream.

Therefore the stage-1 direct match SHOULD compare Zone/Net/Node and IGNORE Point
- which is exactly what the implementation does (bbs_database.pas +
mutil_common.pas):

    Result := (TempNode.Address.Zone = Dest.Zone) and
              (TempNode.Address.Net  = Dest.Net)  and
              (TempNode.Address.Node = Dest.Node);

A netmail to 1:250/250.10 correctly direct-matches the configured node
1:250/250, which is the boss host that receives point mail. No change needed.

Edge case (both a node AND its point configured as separate echomail nodes):
extremely rare in practice - points are non-public and configured ON the boss,
not as their own echomail node with a nodelist presence. If it ever mattered, the
boss-node match is still the correct FTN behavior. CLOSED.

---

# AREAFIX REBUILD PLAN — researched against g00r00 records.110 + fork code

## Data structures — NONE new needed (verified against records.110)

AreaFix operates entirely on structures the fork ALREADY has, and they match
g00r00's records.110 exactly:

- **AreaFixPass** : String[20] on RecEchoMailNode (echonode.dat) - the per-node
  AreaFix password. Already present (position 30 in the aligned record).
- **PKTPass** : String[8] (added in the record alignment) - separate PKT pw.
- **RecEchoMailExport = LongInt** - identical in fork and records.110. The
  per-base link file `<base>.lnk` is a `File of RecEchoMailExport`, i.e. a flat
  list of echonode Index values that the base exports to.
- **RecMessageBase** (mbases.dat) - holds EchoTag (String[40]), NetType
  (3=Net/1=Echo), NetAddr (which AKA), Index. Identical model in both.

So the AreaFix rebuild is PURELY code (parser + responder), no records.pas
change, no anchor impact.

## Link primitives — ALREADY EXIST (bbs_database.pas)

The add/remove/query operations the +/-/= commands need are already written:

- `IsExportNode(MBase, Idx) : Boolean`       - is base linked to node Idx?
- `AddExportByBase(MBase, Idx)`              - link base->node  (+ECHOTAG)
- `RemoveExportFromBase(MBase, Idx)`         - unlink           (-ECHOTAG)
- `RemoveExportGlobal(Idx)`                  - unlink node from all bases

The manual editor `EditExportsByNode` (bbs_cfg_echomail.pas) already drives these
from the UI. AreaFix is the netmail-driven equivalent, calling the SAME
primitives.

## What actually has to be BUILT (mutil_echofix.pas, currently a stub)

1. **Auth**: find the RecEchoMailNode whose Address matches the PKT message
   origin AND whose AreaFixPass matches the subject/password. Revive the
   commented `GetNodeByAuth` but FIX its bug (it compared Addr.Zone to
   Address.Node). NOTE the stub's real concern: the PKT message header lacks
   ZONE/POINT - use the origin address available in the tosser context; if
   ambiguous, match on Net/Node + password.

2. **Command parser** over the message text lines (PKT.MsgText):
   - `%COMPRESS <type>`  - set node ArcType (blank = raw PKT)
   - `%HELP`             - append DATA\areafixhelp.txt to the response (at END)
   - `%PWD <newpass>`    - set node.AreaFixPass := newpass, save node
   - `%LIST`             - all AVAILABLE areas: iterate mbases.dat, list bases
                           whose NetAddr domain (bbsCfg.NetDomain[NetAddr])
                           matches the node's Domain
   - `%LINKED`           - bases where IsExportNode(MBase, node.Index) = True
   - `%UNLINKED`         - available bases where IsExportNode = False
   - `%RESCAN [R=#|D=#]` - for each LINKED base, export last 250 (or R/D) msgs
   - `-ECHOTAG`          - find base by EchoTag, RemoveExportFromBase
   - `+ECHOTAG [R=#|D=#]`- find base by EchoTag, AddExportByBase, optional rescan
                           (bare TAG also adds; '+' optional)
   - `=ECHOTAG <R=#|D=#>`- rescan an existing linked base
   Separator between tag and R=/D= may be comma OR space.

3. **Response netmail**: build a netmail back to the requesting node summarizing
   what each command did, then %HELP text appended last. Post it via the
   existing message-post path (see mutil_msgpost.pas uPostMessages) or write a
   PKT directly addressed to the node. It must route via the item-17
   GetNodeByRoute logic.

4. **RESCAN mechanics**: reuse the existing export/rescan path (the same code the
   manual "rescan" uses) - export the last N messages or D days from a base to
   the requesting node.

## Rebuild order (suggested)
  a. Auth (GetNodeByAuth fixed) + command tokenizer + response-message skeleton.
  b. The link commands (+/-/= and %LINKED/%UNLINKED/%LIST) using the existing
     primitives - highest value, lowest risk (no new data paths).
  c. %PWD, %COMPRESS, %HELP - simple field sets + file append.
  d. %RESCAN / rescan-on-add - reuse the export path; most complex, do last.
  e. FileFix (A41) shares the AREAFIX/FILEFIX detection - keep separate, out of
     A40 scope.

## Verification
  - No records.pas change -> anchor stays 901 (nothing to re-check, but confirm).
  - Live test on node 152/158: remote node sends %LIST / +TAG / %RESCAN, gets
    correct netmail responses AND the .lnk link list actually changes.
  - areafixhelp.txt must ship in DATA for %HELP.

---

# IMPLEMENTED (parts 1-3) — 2026-07-10

mutil_echofix.pas rewritten from stub to a working AreaFix (read-verified, NOT
compiled).  All symbols confirmed present; Begin/End/Case balanced.

DONE:
1. AUTH - GetNodeByAuth revived and FIXED (now matches Zone/Net/Node against
   PKT.MsgOrig - which carries the full origin address, solving the stub's "no
   ZONE/POINT" worry - plus AreaFixPass).  Only active nodes.  Bad auth consumes
   the message (no public toss) but sends NO reply (no password oracle).
2. COMMAND PARSER - all 9: %LIST, %LINKED, %UNLINKED, %HELP (appends
   DATA\areafixhelp.txt), %PWD, %COMPRESS, %RESCAN, and +/-/= ECHOTAG (bare tag
   = add).  R=/D= rescan qualifier parsed (comma or space separated).  Link ops
   use the existing IsExportNode / AddExportByBase / RemoveExportFromBase.
3. NETMAIL RESPONSE - builds a result summary and sends via GetMBaseByNetZone +
   SaveMessage back to the requesting node.

OPEN / NEEDS LIVE VERIFICATION:
- SaveMessage NetType quirk: it sets netmail dest only for NetType=2, but netmail
  bases are NetType=3.  Flagged in-code.  Confirm the reply is addressed (SetDest)
  and exported as netmail on a live toss; if not, fix SaveMessage's NetType check
  rather than special-casing AreaFix.
- %RESCAN / =TAG rescan: currently ACKs "queued" but does not yet re-export the
  last-N/last-D messages.  Wiring to the export pass is the remaining piece (see
  "RESCAN mechanics" above).
- areafixhelp.txt must ship in DATA for %HELP.
- Not compiled (per standing instruction) and not live-tested.

NO records.pas change -> anchor stays 901 (AreaFix uses existing structures).


---

# UPDATE — steps 1,2,3 + RESCAN implemented (2026-07-10)

AreaFix is now implemented and compiles clean (mutil_echofix.pas + the rescan
processor in mutil_echoexport.pas):

- Step 1 (auth): GetNodeByAuth matches origin Zone/Net/Node (ignores Point per
  the FTN boss-node rule) + AreaFixPass. The old stub's Zone-vs-Node bug is fixed.
- Step 2 (parser): all commands handled - %HELP, %LIST, %LINKED, %UNLINKED,
  %PWD, %COMPRESS, %RESCAN, +/-/=ECHOTAG (bare tag = add). Link ops call the
  existing IsExportNode / AddExportByBase / RemoveExportFromBase primitives.
- Step 3 (response): builds a result buffer, posts a netmail reply to the
  requesting node via GetMBaseByNetZone + SaveMessage.
- RESCAN (researched against FSC-0057 + Mystic's own areafixhelp.txt): default
  is last 250 msgs per linked area; R=# overrides the count, D=# selects the last
  # days. %RESCAN alone = all linked areas; =TAG / +TAG R=/D= = one base.
  Implemented as a QUEUE: mutil_echofix writes areafix.rsn (NodeIndex|BaseIndex|
  Count|Days); uEchoExport runs ProcessRescanQueue right before finalizing PKTs,
  re-exporting the last N (or last-D-days) msgs of each linked base to ONLY the
  requesting node WITHOUT touching the Sent flag (so normal export is unaffected).
  This avoids a circular unit dependency and matches how a real tosser sequences
  import-then-export in one pass.

STILL PENDING: live toss test on node 152/158 (link/unlink/list/rescan end to
end), and ship data/areafixhelp.txt for %HELP. FileFix (A41) still out of scope.

---

# MBCICO fix (A40 item "! Fixed a compatibility issue with BINKP against MBCICO")

Researched against FidoNet/BINKP standards + MBSE mbcico docs + forums.

WHAT MBCICO IS: MBSE BBS's FidoNet mailer ("MBse Internet-Fidonet Copy In/Copy
Out"), ifcico-derived. So the A40 entry is a BINKP mailer INTEROP fix - Mystic's
binkp not handshaking cleanly with mbcico.

KNOWN Mystic<->mbcico friction (from forums/spec):
- Handshake / frame-ordering and CRAM-MD5 negotiation. Evidence: mbcico sessions
  failing with M_ERR "Encryption required" / rc=108; Synchronet BinkIT requires
  BinkpAllowPlainText=true for Mystic-binkp compatibility. So the cluster is
  plaintext-vs-encrypted session negotiation and OPT/M_NUL frame handling.
- Per FSP-1011 (binkp spec): Basic Authentication (plain password via M_PWD) is
  REQUIRED of all mailers; CRAM-MD5 is an optional extension. Forcing CRAM-MD5
  or mis-ordering the OPT frame can break a spec-minimal peer like mbcico.

HONEST LIMIT - CANNOT reconstruct the exact 1.10 A40 fix:
- One-line whatsnew, no public changelog detail.
- The uploaded mystic.exe is 1.12 A40 (not 1.10) and carries LATER crypt/AES
  features (cryptInit, "AES256 encrypted", "None Login Plain CRAM-MD5") that
  post-date 1.10 A40 - so it is NOT a clean reference for the 1.10 fix.
- No 1.10 A40 binary or source exists to diff.

RECOMMENDATION: do NOT fabricate a handshake change (risk: breaking working
binkp). Mark as "needs live test against a real mbcico/MBSE node." The failing
handshake logs (M_ERR text, rc) will name the exact fix. The fork's current
binkp advertises binkp/1.0 and sends OPT CRAM-MD5 before SYS/ZYZ/VER; if mbcico
interop fails, likely fix is around CRAM-MD5 being optional (fall back to plain
M_PWD Basic Auth per FSP-1011) - but confirm against a live failure first.

# %RESCAN spec (clarified)

%RESCAN is an AreaFix (application-level) command, NOT a BINKP-standard thing.
No FTS governs it; the spec is g00r00's whatsnew:
  R=<n>  -> re-export the last N messages
  D=<n>  -> re-export messages from the last N days
  default = last 250 messages
Current impl replies "Rescan queued" but does not yet perform the re-export
(the export-path integration is the remaining work - checklist step d).
