# Hudson message base (as implemented by OpenOLMS)

QuickBBS/RemoteAccess shared message store. Read support in
src/olms_hudson.pas. Files: MSGHDR.BBS (headers), MSGTXT.BBS (text),
plus MSGIDX/MSGTOIDX/MSGINFO indexes (optional for a full scan).

## MsgHdr record (190 bytes, packed)
| Off | Field |
|-----|-------|
| 0   | MsgNum (u16) |
| 2   | ReplyTo (u16) |
| 4   | SeeAlso (u16) |
| 6   | TimesRead (u16) |
| 8   | StartBlock (u16) — first 256-byte block in MSGTXT.BBS (1-based) |
| 10  | NumBlocks (u16) |
| 20  | Attribute (u8) |
| 22  | Board (u8) — area number |
| 23  | PostTime[5] "HH:MM" |
| 28  | PostDate[8] "MM-DD-YY" |
| 36  | ToName: len byte + 35 |
| 72  | FromName: len byte + 35 |
| 108 | Subject: len byte + 71 |
| ...  | padded to 190 |

MSGTXT.BBS is a series of 256-byte blocks (block 0 unused); a message's text is
NumBlocks blocks starting at (StartBlock-1)*256. Text uses CR line separators.
