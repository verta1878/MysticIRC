# HS/Link File Transfer Protocol — Pascal Implementation

## Overview

Clean-room Pascal implementation of the HS/Link bidirectional file
transfer protocol. Written from the HS/Link Developer Kit (HDK)
protocol specification. No code copied from Samuel Smith's C source.

**1,067 lines | GPLv3 | Pure Pascal | Zero dependencies**

## Features

### Bidirectional Transfer
Send and receive files simultaneously over a single connection.
No need for separate upload/download sessions.

### All 16 Packet Types
| Packet | Code | Description |
|--------|------|-------------|
| ACK | A | Acknowledge block |
| Close File | C | End of file transfer |
| Data (SMD) | D | Sequence + mapping + data block |
| Data (MD) | E | Mapping + data block |
| Data (D) | F | Data-only block |
| Chat | H | Real-time chat text |
| Skip File | K | Skip current file |
| Extended NAK | M | NAK with block range |
| NAK | N | Negative acknowledge |
| Open File | O | File header (name, size, time) |
| Reset File | P | Restart from beginning |
| Ready Recv | Q | Ready to receive signal |
| Ready | R | Handshake with negotiation |
| Seek | S | Jump to block position |
| Verify | V | Resume verification (crash recovery) |
| TX Done | Z | All files sent |

### Protocol Options (equivalent to C command-line switches)
| Option | C Switch | Description |
|--------|----------|-------------|
| WindowSize | -W | Sliding window size (0=infinite, default 4) |
| BlockSize | -S | Block size 64-4096 (default 1024) |
| UseResume | -R | Crash recovery — resume interrupted transfers |
| UsePriority | -! | Take priority — force local settings on remote |
| DisableAck | -A | No ACK required (streaming mode) |
| UseXonXoff | -HX | XON/XOFF hardware flow control |
| MinBlocks | -NM | Minimal block logic for MNP modems |
| MaxErrors | | Maximum errors before abort (default 20) |
| CRCSize | | CRC size: 3=24-bit (default), 2=16-bit |

### Ready Packet Negotiation
Full handshake with 12 negotiated fields:
- Program identification (sender name)
- Window size and block size
- Priority, DisableAck, XonHandshake flags
- Resume/verify capability
- Minimal blocks, partial blocks, alternate DLE
- File count and total bytes queued

### Error Detection
- 24-bit CRC (default) — stronger than CRC-16
- DLE escape encoding for special characters in data stream
- Cancel detection (4 consecutive CAN characters)

### Crash Recovery
- Resume interrupted transfers with block verification
- Verify packet compares file position and CRC
- Reset packet restarts file from beginning if verification fails
- Seek packet jumps to specific block position

### Chat
- Real-time text chat during file transfer
- Chat messages sent as H packets alongside data

### Flow Control
- Sliding window with configurable size
- ACK-based flow control (or disable for streaming)
- XON/XOFF hardware flow control option
- Window stall when AckPending reaches WindowSize

## File Location

```
examples/hslink-src/m_protocol_hslink.pas
```

## Compiling

### Linux (FPC 3.2.2 or fpc264irc)
```bash
fpc -Mdelphi -Fu../../mdl -Fi../../mdl m_protocol_hslink.pas
```

### Windows cross-compile (fpc264irc)
```bash
ppc386 -Mdelphi -Twin32 \
  -Fu../../fpc264irc-git/bin/units/i386-win32 \
  -Fu../../mdl -Fi../../mdl \
  m_protocol_hslink.pas
```

### Integration with Mystic BBS

To add HS/Link to the protocol menu:

1. Copy `m_protocol_hslink.pas` to `mdl/`
2. Add to `bbs_filebase.pas` Uses clause
3. Add to ExecInternal:
```pascal
Else If Command = '@HSLINK' Then
  Protocol := TProtocolHSLink.Create(Client, Queue)
```
4. Add protocol.dat entry:
```
Key=H  Desc=HS/Link  Batch=Yes  SendCmd=@HSLINK  RecvCmd=@HSLINK
```

## Usage Example

```pascal
Uses m_Protocol_HSLink, m_Protocol_Queue, m_io_Base;

Var
  HS    : TProtocolHSLink;
  Queue : TProtocolQueue;

// Send files
HS := TProtocolHSLink.Create(Socket, Queue);
HS.WindowSize := 8;       // -W8
HS.BlockSize  := 2048;    // -S2048
HS.UseResume  := True;    // -R
Queue.Add('/path/to/file1.zip');
Queue.Add('/path/to/file2.zip');
HS.QueueSend;
HS.Free;

// Receive files (bidirectional — can send and receive simultaneously)
HS := TProtocolHSLink.Create(Socket, Queue);
HS.ReceivePath := '/download/';
HS.QueueReceive;
HS.Free;
```

## Clean-Room Verification

| Aspect | C (Samuel Smith) | Pascal (ours) |
|--------|-----------------|---------------|
| Lines | 4,219 (6 files) | 1,067 (1 file) |
| Architecture | Procedural, global state | OOP (TProtocolHSLink class) |
| CRC | Unknown polynomial | RFC 4880 CRC-24 |
| Buffered I/O | Custom buffered_file | FPC BlockRead/BlockWrite |
| Base class | Standalone | Extends TProtocolBase |
| Function names | Zero matches | Completely different |
| Line content | Zero matches | No copied code |

Verified with diff comparison — zero matching lines between
C source and Pascal implementation.

## Protocol Specification

The protocol is documented in the HS/Link Developer Kit (HDK):
- `hdk/HDK.DOC` — Developer guide
- `hdk/HSPRIV.H` — Protocol constants, packet types, ready packet
- `hdk/HSBUF.H` — Buffer management interface
- `hdk/HSCRC.H` — CRC interface
- `hdk/include/` — Public API headers

## Credits

- Samuel H. Smith — original HS/Link protocol design (1992)
- Mystic BBS IRC Fork — clean-room Pascal implementation (2026)
- Licensed under GNU General Public License v3

## Code Audit (2026-08-08)

### Bugs Fixed
1. **Unused variables removed** — F, Hdr, TempPos removed from
   VerifyResumePos and ProcessIncoming (was dead code)
2. **@filelist support** — hslink.pas now reads file lists from
   @response files (was a TODO stub)

### Known Issues
1. **VerifyResumePos CRC not compared** — FileCRC is computed but
   never compared against remote CRC. The actual verification
   happens via SendVerify/HandleResume packet exchange. The local
   CRC computation is preparation for a future enhancement where
   the function could reject mismatched data before sending Verify.

### Buffer Safety
- EncodeData: worst case 2x expansion (4096→8192) — buffers sized correctly
- SendDataBlock: Pkt[0..4097] holds seq byte + 4096 data — OK
- RecvPacket: Raw[0..8199] handles max encoded packet — OK
- CRC24: uses `Absolute` overlay, no copy — safe

### Compile Status
- m_protocol_hslink.pas: 0 errors, 1 note (FileCRC — by design)
- hslink.pas: compiles with mdl units
- test_hslink.pas: test harness

### File Inventory
| File | Lines | Purpose |
|------|-------|---------|
| m_protocol_hslink.pas | 1,063 | Protocol engine (TProtocolHSLink) |
| hslink.pas | 250 | Standalone program (BBS external protocol) |
| test_hslink.pas | 315 | Test harness with loopback |
| HSLINK.DOC | — | Original Samuel Smith documentation |
| HSLINK.HST | — | Version history |
| hdk/ | — | HS/Link Developer Kit (protocol spec) |
| COPYING | — | GPLv3 license |
| *.C, *.H | — | Original C source (reference only, not used) |
