# JAM message base (as implemented by OpenOLMS)

JAM by Homrighausen, Adams, Lentz, Wittel (1993). Read support in
src/olms_msgbase.pas. Files per area base: `.JHR` (headers), `.JDT` (text),
`.JDX` (index), `.JLR` (lastread). OpenOLMS reads `.JHR` + `.JDT`.

## Fixed header (start of .JHR)
Signature 'JAM'#0 (4), datecreated (u32), modcounter (u32), activemsgs (u32),
passwordCRC (u32), basemsgnum (u32), then reserved to 1024 bytes.

## Message header (in .JHR; offsets from the record start)
| Off | Field |
|-----|-------|
| 0   | Signature 'JAM'#0 |
| 8   | SubfieldLen (u32) |
| 24  | ReplyTo (u32) |
| 36  | DateWritten (u32, unix) |
| 48  | MessageNumber (u32) |
| 52  | Attribute (u32; bit 0x80000000 = deleted) |
| 60  | Offset into .JDT (u32) |
| 64  | TxtLen (u32) |
| 76  | start of subfields |

Fixed header is 76 bytes, followed by SubfieldLen bytes of subfields:
each = LoID (u16), HiID (u16), DatLen (u32), Data[DatLen].
Subfield IDs used: 2 = sender, 3 = recipient, 6 = subject.
Message text in .JDT uses CR line separators.
