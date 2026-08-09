# OpenOLMS — architecture

*An OLMS offline-mail door
(Multiboard's OLMS 2000 by Peter Rocca, shareware). Built from the **manual**
(`OLMS.DOC`), **observed behavior/screenshots**, and the **open packet-format
specs** —  Free Pascal, targeting the same role OLMS filled.*

---

## What OLMS is (from the manual)

> "A premium QWK, QWKE and BlueWave compatible mail door, with all the trimmings.
> Includes message keywording, filtering, twit lists, file requesting and more."

A **mail door**: a program a BBS runs so a caller can bundle unread messages into
a compressed **offline-mail packet**, read/reply offline in a reader (Blue Wave,
etc.), and upload replies. OpenOLMS reimplements that door.

## Authoritative feature map (from `OLMS.DOC` table of contents)

**Packet formats (output):** QWK, QWKE, Blue Wave.
**Message base formats (input):** Hudson and JAM. *(the manual states these two;
we can add Squish/`*.MSG` later — same abstraction.)*

**Configuration:** System info, archiver programs, protocol programs, files
config, bulletins, control setup, requesting control, limits, short style, user
editor, multi-language, test config.

**Running:** command-line params, RemoteAccess 2.x integration, advanced user
editor, vacation mail, QWK networking, point networking, internet gateway, remote
maintenance, customization.

**User features:** conference join/drop, keyword scans, filters, twit lists,
taglines, duplicate check, selectable bulletins, file requesting (incl. attaches),
RIP support, multi-language screens.

## Layered architecture

```
  ┌──────────────────────────────────────────────────────────────┐
  │  UI layer  (text-mode screens; RIP later via the RIP engine)   │
  │  conference select · keywords · filters · twits · settings     │
  └───────────────────────────┬──────────────────────────────────┘
                              │
  ┌───────────────────────────┴──────────────────────────────────┐
  │  Door logic  (session, user prefs, scan/gather, reply intake)  │
  └───────────────────────────┬──────────────────────────────────┘
              ┌────────────────┼────────────────┐
  ┌───────────┴──────┐ ┌───────┴────────┐ ┌──────┴───────────────┐
  │ Message-base IN  │ │ Packet OUT/IN   │ │ Config + user store  │
  │ IMsgBase:        │ │ IPacketWriter:  │ │ records from the     │
  │  Hudson, JAM     │ │  QWK, QWKE, BW  │ │ manual's config set  │
  └──────────────────┘ └─────────────────┘ └──────────────────────┘
```

Two seams mirror the RIP client's `IRipCanvas` idea:
- **`IMsgBase`** — read messages from Hudson / JAM (add formats without touching
  door logic).
- **`IPacketWriter`** — emit QWK / QWKE / Blue Wave (add formats the same way).

The door logic never hard-codes a format; it talks to these interfaces.

## Build order (each milestone compiles and does something real)

1. **QWK writer** (this milestone) — `olms_qwk.pas`: produce a valid QWK packet
   (`CONTROL.DAT`, `MESSAGES.DAT`, `*.NDX`) from an in-memory message set. QWK is
   the universal baseline; every reader accepts it. **Proven with a real packet.**
2. **Message-base readers** — `IMsgBase` + JAM reader (well-documented) then Hudson.
   Feed real BBS messages into the writer.
3. **QWKE + Blue Wave** writers behind `IPacketWriter` (longer subjects, kludges,
   Blue Wave's `.MIX/.FTI/.DAT`).
4. **Reply intake** — read `.REP`/`.UP` packets back in.
5. **Config + user store**, conference join/drop, filters, keywords, twits.
6. **UI** (text screens from the OpenOLMS screenshot set; RIP later via our RIP
   engine — same project family).
7. **RemoteAccess integration** (`EXITINFO.BBS`, dropfile) and the extras
   (vacation, file requests, taglines, multi-language).

## Legal footing (why this is clean)

- OpenOLMS: original code, written from the **manual + open specs**. QWK, QWKE,
  Blue Wave, JAM, and Hudson are **publicly documented** formats — that's the
  reference material, and it's free to implement.
- License OpenOLMS as you like (GPL fits the BBS-tooling world and your other
  repos). It owes nothing to Multiboard's code.
```
