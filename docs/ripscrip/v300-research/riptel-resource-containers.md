# RIPtel Resource Containers (RIPSCRIP.RES / RIPSCRIP.DB / Help Resources)

Research notes on three RIPtel-only container files, decoded from the shipped bytes in `~/src/rip-tools/artifacts/RIPtel/`. These are **packaging details of the original client, not specification surface** - an alternative RIPscrip implementation needs none of them - but they are preserved here because they were evidence sources for the 3.x reconstruction (the help resources yielded the command inventory) and they document the engine's container conventions. All share TeleGrafix's container-magic convention also seen in the [MicroANSI container](../../2.0/techspecs/3.3-microansi-fonts.md#container-layout): `\x04␠<description>␠\x04` followed by a short control-character tail. Two of the three are only partially decodable from the shipped files (the `.RES` directory is zeroed and the `.DB` ships empty); undecoded regions are marked as such. All integers little-endian.

## "RIPscrip Help File Resource" (`RIPSCRIP.HLP`, `MESSAGES.HLP`)

Despite the `.HLP` extension these are **not Windows WinHelp files** - they are TeleGrafix's own string-table format, fully decoded. (`RIPTEL.HLP`, by contrast, _is_ genuine WinHelp 3.x - magic `3F 5F 03 00` - see the [help extraction notes](riptel-help-extraction.md).) Verified layout, byte-exact against both files:

```text
0x00  byte[34]  magic: 04 20 "RIPscrip Help File Resource " 04 0A 1A 00
0x22  u32       entryCount        ; RIPSCRIP.HLP: 1210; MESSAGES.HLP: 179
0x26  byte[62]  zero (reserved)
0x64  u32 × entryCount            ; absolute file offset of each string
then  contiguous NUL-terminated CP437 strings to end-of-file
```

- The offset table is **sorted ascending** and the first offset equals the table's own end (0x64 + 4 × entryCount) in both files - the strings pack immediately after the table with no gaps.
- The table is a **sparse, ID-indexed array**: entry _n_ is message ID _n_. An unused ID stores the same offset as the next used one, so a string's length is `offset[n+1] - offset[n]` (last entry: to EOF) and length 0 means "no such message". The final entry points at end-of-file, i.e. it is empty in both shipped files.
- Strings may contain `\n` and `\r` (multi-line UI text) and are CP437, per the DOS-lineage engine.

Observed ID map:

| File | Entries | Used | ID ranges |
| --- | --- | --- | --- |
| `MESSAGES.HLP` (18,780 B) | 179 | 178 | 0-177: RIPtel UI strings ("File I/O Error", bookmark/dialer text, tip-of-the-day prose) |
| `RIPSCRIP.HLP` (38,223 B) | 1,210 | 1,091 | 90-93: parser fallback strings ("No RIPscrip Error Message", "Unknown RIPscrip Function Name"); 100-777: RIPSCRIP.DLL error messages; 800-1208: symbol names - the RIPscrip 3.0 wire-command inventory `RIP_Arc` … at 800+, then internal routine names (`ansiFontOpenFile`, `jpegShow`, …) |

The complete extracted string inventory - the parser's command names, error strings, and limits recovered from them - is catalogued in the [help extraction](riptel-help-extraction.md) research notes; ID 800's `RIP_Arc` through ID 1194's `RIP_ResetDefaultPalette` is the DLL's function-name table quoted there.

## `RIPSCRIP.RES` - client resource container

10,490 bytes, dated 1996-11-13 (a RIPterm 2.x-era build artifact carried into RIPtel - the magic still says "RIPterm v2.0"). Required at startup ("resource file RIPscrip.res required", RIPSCRIP.HLP string). Observed structure:

```text
0x00    byte[34]  magic: 04 20 "RIPterm v2.0 Resource File " 04 0A 0D 00 1A
0x22    u16       6                ; section count (presumed - see below)
0x24    byte[66]  zero             ; directory region, entirely zeroed
0x66    byte[112] high-entropy blob - undecoded (registration/scrambled data?)
0xD6    byte[768] default 256-color palette, 6-bit VGA DAC RGB triplets:
                  entries 0-15  = standard EGA colors (00 00 00, 00 00 2A,
                                  00 2A 00, 00 2A 2A, 2A 00 00, 2A 00 2A,
                                  2A 15 00, 2A 2A 2A, 15 15 15, 15 15 3F, …)
                  entries 16-31 = 16-step grayscale ramp (00, 04, 08, 0D, 11, …)
                  entries 32-255 = 224-entry color cube
0x3D6   byte[406] embedded Windows BMP, 24 × 24 px, 4-bit (self-describing:
                  "BM", biSize field 406 → ends exactly at 0x56C)
0x56C   byte[9102] ASCII C source fragment to EOF: "unsigned char
                  resource_tvopt.rsc[]  =  \r\n{\r\n  0xC4, 0x20, 0xC0, …};"
```

The four content regions after the directory were recovered **by content signature, not by directory** - the region that should describe the sections (0x24-0x66) is all zeros in the shipped file, so the mapping between the count 6 and the 4 recognizable regions is unresolved, and the u16 at 0x22 being a section count is itself _plausible-but-unverified_ (it matches the MicroANSI container's count-field position). The final section is a shipping accident: a developer's generated C array (a hex dump of dialog-template resource `tvopt.rsc`, the text-variable prompt dialog naming "MS Sans Serif" in UTF-16) appended as text - including its trailing `};` at end-of-file. The high-entropy blob at 0x66 remains undecoded.

The embedded default palette matches the RIPscrip 2.x specified 256-color table byte-for-byte - corroboration recorded in the [2.x palette techspec](../../2.0/techspecs/2.0-canvas-palette-rgb.md).

## `RIPSCRIP.DB` - text-variable database

The persistent store behind `$+VAR$` [permanent text variables](../ripscrip/9.1-text-variable-reference.md). The DLL's own strings describe it as an indexed record database with a hash table whose corruption remedy is deletion ("Database is corrupted - Try deleting RIPSCRIP.DB"), and the shipped file is the empty scaffolding the client creates - 400 bytes with no user records, which bounds what can be decoded:

```text
0x00   byte[38]  magic: 04 20 "RIPscrip Text Variable Database " 04 0A 1A 00
0x26   u16       0x3549           ; ASCII "I5" - meaning unverified
0x28   u32       0
0x2C   u32       4                ; meaning unverified (version? bucket width?)
0x30   byte[224] zero             ; presumed hash-table/index area (unverified)
0x110  u32       0x190 (= 400)    ; equals the file length - presumed
                                  ; end-of-data / next-free offset
0x114  byte[5]   zero
0x119  u8        1
0x11A  u16       0
0x11C  u32       0x15 (= 21)      ; meaning unverified
0x120  byte[112] zero to EOF
```

Every non-zero value above is the complete inventory of non-zero bytes in the file. The record format itself cannot be decoded from an empty database and is left undocumented rather than guessed; the variable-content limits that would shape it (name ≤ 20 chars, content ≤ 255 chars) are known from the [help extraction §5](riptel-help-extraction.md).
