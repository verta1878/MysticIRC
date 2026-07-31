# Mystic BBS Internal File Transfer Protocols

## Implemented

| Key | Protocol | Block Size | Check | Batch | File |
|-----|----------|-----------|-------|-------|------|
| Y | Ymodem | 1K | CRC-16 | Yes | m_protocol_ymodem.pas |
| G | Ymodem-G | 1K | CRC-16 | Yes (streaming) | m_protocol_ymodem.pas (UseG) |
| Z | Zmodem | 1K | CRC-32 | Yes | m_protocol_zmodem.pas |
| 8 | Zmodem 8K | 8K | CRC-32 | Yes | m_protocol_zmodem.pas (CurBufSize=8192) |
| 3 | Zmodem 32K | 32K | CRC-32 | Yes | m_protocol_zmodem.pas (CurBufSize=32768) |

## Protocol Variants (same engine, different config)

### Xmodem Family
- **Xmodem Checksum** — 128-byte blocks, 8-bit checksum (DoCRC=False, Do1K=False)
- **Xmodem CRC** — 128-byte blocks, CRC-16 (DoCRC=True, Do1K=False)
- **Xmodem 1K** — 1024-byte blocks, CRC-16 (DoCRC=True, Do1K=True)

### Ymodem Family
- **Ymodem** — 1K blocks, CRC-16, batch, Block 0 file info (UseG=False)
- **Ymodem-G** — streaming mode, no per-block ACK (UseG=True)

### Zmodem Family
- **Zmodem** — 1K blocks, CRC-32, crash recovery (CurBufSize=1024)
- **Zmodem 8K** — 8K blocks, same features (CurBufSize=8192)
- **Zmodem 32K** — 32K blocks, optimal for TCP/telnet (CurBufSize=32768)

## Usage

```pascal
// Zmodem (standard 1K)
ZM := TProtocolZmodem.Create(Socket, Queue);
ZM.CurBufSize := 1024;
ZM.QueueSend;

// Zmodem 8K
ZM := TProtocolZmodem.Create(Socket, Queue);
ZM.CurBufSize := 8192;
ZM.QueueSend;

// Zmodem 32K
ZM := TProtocolZmodem.Create(Socket, Queue);
ZM.CurBufSize := 32768;
ZM.QueueSend;

// Ymodem
YM := TProtocolYmodem.Create(Socket, Queue);
YM.UseG := False;
YM.QueueSend;

// Ymodem-G
YM := TProtocolYmodem.Create(Socket, Queue);
YM.UseG := True;
YM.QueueSend;
```

## Planned

| Key | Protocol | Notes |
|-----|----------|-------|
| X | Xmodem | 128-byte blocks, basic (m_protocol_xmodem.pas ready) |
| K | Kermit | Columbia University, 7-bit safe, CRC-16, windowed | m_protocol_kermit.pas |

## Protocol Menu (target)

```
Available Protocols:

[X] Xmodem
[Y] Ymodem
[G] Ymodem-G
[Z] Zmodem
[8] Zmodem 8K
[3] Zmodem 32K
[K] Kermit
Select Protocol [Q/Quit]:
```

## File Locations

Protocol engine (OOP, in mystic/):
- m_protocol_base.pas — base class (TProtocolBase)
- m_protocol_queue.pas — file queue
- m_protocol_xmodem.pas — Xmodem (full: send, receive, CRC, 1K)
- m_protocol_ymodem.pas — Ymodem + Ymodem-G (batch, Block 0, streaming)
- m_protocol_zmodem.pas — Zmodem/8K/32K (CRC-32, crash recovery)

Old protocol library (procedural, in mdl/ — g00r00 original):
- m_prot_base.pas — APRO-style base (894 lines)
- m_prot_zmodem.pas — older Zmodem (2530 lines)

## Strings Needed (protocol.dat / language file)

When the protocol menu is wired into the BBS:
- Protocol selection prompt
- Transfer status display (filename, size, position, errors, CPS)
- Transfer complete/failed messages
- Abort confirmation

These strings are not yet in the language file. The protocol engine
works standalone — the BBS integration layer adds the UI strings.

## HS/Link (Reference)

Samuel Smith's bidirectional file transfer protocol (1992).
Sends and receives files simultaneously over a single connection.
Source code in examples/hslink-src/ (reference only — proprietary license).

A clean-room Pascal implementation is needed for Mystic integration.
Protocol spec available in examples/hslink-src/hdk/HDK.DOC.

| Key | Protocol | Notes |
|-----|----------|-------|
| H | HS/Link | Bidirectional, CRC-16, sliding window (TODO: clean-room impl) |

## FTP Download Option (g00r00)

g00r00's protocol menu includes **[F]tp Site** as a download method:

```
Download via [F]tp Site, or [ENTER/Protocol]?
```

When the user picks F, the BBS starts an FTP session and the caller
downloads the file via their FTP client instead of a modem protocol.

Advantages:
  - No 2GB file size limit (Zmodem uses 32-bit positions)
  - Faster on TCP connections (no protocol overhead)
  - Resume support built into FTP

Notes:
  - g00r00's implementation is reportedly broken
  - Requires MIS FTP server to be running
  - BBS must generate a temporary FTP credential for the session
  - Strings needed: FTP prompt, FTP URL display, FTP auth messages

## FTP Server Code Audit (mis_client_ftp.pas — 1,280 lines)

### What works
- Full FTP command set: USER, PASS, PORT, PASV, CWD, CDUP, LIST, NLST,
  PWD, RETR, STOR, STRU, MODE, SYST, TYPE, EPRT, EPSV
- Passive mode (PASV) — fixed by IRC fork (endian-aware MyWordRec)
- File upload (STOR) and download (RETR)
- Directory listing (LIST/NLST)
- QWK packet create/import over FTP
- 32K transfer buffer (FileXferSize)

### What's broken / missing
1. **SIZE command returns "550 Not implemented"** — FTP clients need this
   for resume support and progress display
2. **File sizes use LongInt (32-bit)** — 2GB limit. Should be Int64.
3. **No RESUME/REST support** — REST (restart) command not implemented,
   so interrupted transfers can't resume
4. **No EPSV response validation** — EPSV (extended passive) present
   but may not handle IPv6
5. **PASV blocks for 10 seconds** — WaitConnection(10000) on the main
   thread; should be async
6. **No TLS/FTPS** — plain text auth only (not unusual for BBS FTP)
7. **QWK download via FTP works** — special case for .QWK files
8. **The [F]tp Site download prompt** from bbs_filebase.pas is NOT in our
   source — g00r00 must have added it in a later alpha we don't have.
   Our bbs_filebase.pas only handles @ZMODEM and @ZMODEM8 internally.

### Quick fixes possible
- SIZE: return FileSize(F) for the requested file
- REST: store resume offset, seek on next RETR
- Int64: change LongInt file vars to Int64

### Deferred
- TLS support
- Async PASV
- The [F]tp download option in bbs_filebase.pas (missing from our source)

## protocol.dat Default Entries

When setting up a fresh Mystic install, add these to the Protocol Editor:

| Key | Description | Batch | SendCmd | RecvCmd |
|-----|-------------|-------|---------|---------|
| X | Xmodem | No | @XMODEM | @XMODEM |
| Y | Ymodem | Yes | @YMODEM | @YMODEM |
| G | Ymodem-G | Yes | @YMODEMG | @YMODEMG |
| Z | Zmodem | Yes | @ZMODEM | @ZMODEM |
| 8 | Zmodem 8K | Yes | @ZMODEM8 | @ZMODEM8 |
| 3 | Zmodem 32K | Yes | @ZMODEM32 | @ZMODEM32 |
| K | Kermit | Yes | @KERMIT | @KERMIT |

External protocols use the path to the executable with MCI codes:
  %0 = comms handle (Win32/OS2)
  %1 = modem port
  %2 = baud rate
  %3 = filename or batch list path

## Prompt Numbers (default.txt — g00r00 v1.12)

| # | Purpose | Default Text |
|---|---------|-------------|
| 061 | Protocol list entry (&1=Key &2=Desc) | `(|&1) |&2` |
| 062 | Select prompt | `Select Protocol for File Transfer, or (Q) to Quit:` |
| 065 | Start transfer (&1=protocol) | `SQ Press [ENTER/S]tart or [ESCAPE/Q]uit your |&1 transfer:` |
| 066 | Disconnect after download? | `Disconnect after file transfer?` |
| 359 | Protocol list header | `Available Protocols:` |
| 385 | Transfer OK (&1=filename) | `Transfer of |&1: OK` |
| 386 | Transfer failed (&1=filename) | `Transfer of |&1: Failed!` |
| 528 | Download via Web+FTP | `Download via [W]eb Site, [F]tp Site, or [ENTER/Protocol]?` |
| 529 | Download via FTP only | `Download via [F]tp Site, or [ENTER/Protocol]?` |
| 530 | Download via Web only | `Download via [W]eb Site, or [ENTER/Protocol]?` |
| 531 | Download URL (&1=URL) | `Download your files at the following site (expires in 1 hour): |&1` |

Note: Prompt 065 first word is input chars (SQ = S and Q keys), followed by display text.

## g00r00 Protocol History

- v1.06: Added internal Xmodem/CRC/1K, Ymodem, Ymodem-G, Zmodem
- v1.07: Removed Xmodem/Ymodem ("still kinda buggy")
- v1.10: Removed internal Zmodem. Added external protocol support (DSZ log)
- v1.10+: Added FTP names per file base, enabled FTP server in MIS
- A38irc: Re-added internal Zmodem (OOP), Zmodem 8K
- A38irc+: Added Zmodem 32K, Xmodem, Ymodem, Ymodem-G, Kermit

## Enabling FTP File Transfer

### Prerequisites
1. MIS FTP server must be enabled in Mystic Configuration:
   - Config → Servers → FTP Server → Use FTP Server = Yes
   - Set FTP Port (default 21)
   - Set Passive Port Range (e.g. 49152-65534)
   - Set FTP Timeout

2. File bases must have FTP access configured:
   - File Base Editor → FTP Name = directory name (e.g. "Games")
   - File Base Editor → FTP ACS = access level (e.g. "s20")
   - Empty FTP Name = base hidden from FTP

### How it works
- User's BBS login/password works for FTP (same user database)
- FTP server shows file bases as directories using FTP Name
- FTP ACS controls who can see each base via FTP
- User connects with any FTP client to bbs.example.com:port

### Download flow (when wired)
```
Prompt 528: Download via [W]eb Site, [F]tp Site, or [ENTER/Protocol]?
   User picks [F]
Prompt 531: Download your files at:
            ftp://bbs.example.com:21/Games/myfile.zip
            (expires in 1 hour)
   User opens FTP client, logs in with BBS credentials
   Downloads the file
```

### Configuration (records.pas)
```
RecConfig:
  inetFTPUse     : Boolean    FTP server on/off
  inetFTPPort    : Word       FTP port (default 21)
  inetFTPMax     : Word       Max simultaneous FTP connections
  inetFTPPassive : Boolean    Allow PASV mode
  inetFTPPortMin : Word       Passive port range start
  inetFTPPortMax : Word       Passive port range end
  inetFTPTimeout : Word       Idle timeout in seconds

RecFileBase:
  FtpName : String[60]        Directory name in FTP listing
  FtpACS  : String[30]        ACS to access this base via FTP
```

### FTP Server Fixes Applied
- SIZE command implemented (was "550 Not implemented")
- REST/resume support added
- PASV endian fix (MyWordRec)
- SendFile error handling (WriteBuf hang fix)

### Not yet wired
- Prompt 528/529/530 not called from bbs_filebase.pas
- Temp URL generation for prompt 531
- Web download option ([W] in prompt 528/530)

## FTP Auto-Download — Terminal Integration

### How it works with terminals

When the user picks [F]tp, the BBS outputs an FTP URL via prompt 531.
Terminals that support FTP URL detection can auto-launch the download:

**SyncTERM** — detects FTP URLs in the data stream. When it sees
`ftp://host:port/path/file`, it can launch an FTP download session
automatically. The user's BBS credentials are passed through.
SyncTERM is the primary terminal for Mystic BBS users.

**NetRunner** — similar FTP URL detection. Parses the URL from the
terminal output and offers to download.

### Implementation approach

The BBS side needs to:

1. Check if MIS FTP is enabled (`inetFTPUse`)
2. Build the FTP URL from config:
   - Host: `bbsCfg.inetInterface` or `bbsCfg.inetDomain`
   - Port: `bbsCfg.inetFTPPort`
   - Path: `FBase.FtpName + '/' + FileName`
3. Output prompt 531 with the URL
4. The terminal handles the rest

```pascal
// Example: building FTP URL for download
FTPUrl := 'ftp://' + bbsCfg.inetDomain + ':' +
          strI2S(bbsCfg.inetFTPPort) + '/' +
          FBase.FtpName + '/' + FileName;

Session.io.PromptInfo[1] := FTPUrl;
Session.io.OutFullLn(Session.GetPrompt(531));
```

The terminal sees the URL in the output stream and handles the
FTP connection. The user authenticates with their BBS login.
Resume works because we implemented REST + SIZE in the FTP server.

### Why FTP over Zmodem?

- No 2GB file size limit (Zmodem uses 32-bit positions)
- Resume support via REST command
- Less protocol overhead on TCP connections
- Terminal handles transfer in parallel (user can keep browsing)
- Standard FTP clients work if terminal doesn't auto-detect

### Supported terminals

| Terminal | FTP URL detect | Auto-download | Resume |
|----------|---------------|---------------|--------|
| SyncTERM | Yes | Yes | Yes (via REST) |
| NetRunner | Yes | Yes | Yes |
| mTelnet | Manual | No | N/A |
| PuTTY | No | No | N/A |
| Windows Telnet | No | No | N/A |

## File Paths

### BBS side (source)
FTP serves files directly from the file base path:
- File base path: `/mystic/files/games/` (RecFileBase.Path)
- FTP Name: `Games` (RecFileBase.FtpName)
- FTP URL: `ftp://bbs:21/Games/doom.zip`
- FTP server maps `/Games/` → RecFileBase.Path

No file copying — FTP reads directly from the file base directory.

### User side (destination)
Downloaded files go to the terminal's configured download directory:
- SyncTERM: Settings → Download Path
- NetRunner: Options → Download Directory
- Same location where Zmodem downloads land

### Upload path
FTP uploads go to RecFileBase.Path for the current directory.
The FTP server calls RecvFile which writes to TempBase.Path.

## Download/Upload Code Flow

### Download (single file)
```
User picks file → DownloadFile
  → SelectProtocol (prompt 359/061/062)
  → prompt 065 (start transfer)
  → ExecuteProtocol(2, filename)
    → ExecInternal or ExecExternal
      → Protocol.QueueSend (one file in queue)
  → DszSearch (check xfer.log for success)
  → prompt 385 (OK) or 386 (Failed)
```

### Download (batch)
```
User queues files → BatchAdd (prompt 047/050)
User downloads → DownloadBatch
  → prompt 079 (batch info: files, size, time)
  → SelectProtocol(True, True) — batch protocols only
  → prompt 066 (disconnect after?)
  → write file.lst (all batch files)
  → ExecuteProtocol(3, file.lst)
    → ExecInternal
      → reads file.lst, adds all to Queue
      → Protocol.QueueSend (batch)
  → DszSearch per file
  → prompt 385/386 per file
  → update user stats (DLs, DLk)
```

### Upload (single file)
```
User uploads → UploadFile
  → SelectProtocol(UseDefault, False)
  → prompt 065 (start transfer)
  → ExecuteProtocol(1, upload_path)
    → ExecInternal
      → Protocol.ReceivePath = upload dir
      → Protocol.QueueReceive
  → scan received files
  → ImportDIZ (extract FILE_ID.DIZ)
  → prompt for description
  → add to file base
```

### FTP Download (when wired)
```
User picks [F] at prompt 528/529
  → BBS builds FTP URL from config
  → prompt 531 (show URL)
  → terminal detects URL, auto-downloads via FTP
  → FTP server authenticates with BBS credentials
  → serves file from RecFileBase.Path
  → REST/SIZE support for resume
```

### Protocol Commands (protocol.dat SendCmd/RecvCmd)

Internal (handled by ExecInternal):
  @XMODEM   — Xmodem CRC/1K
  @YMODEM   — Ymodem batch
  @YMODEMG  — Ymodem-G streaming
  @ZMODEM   — Zmodem 1K
  @ZMODEM8  — Zmodem 8K
  @ZMODEM32 — Zmodem 32K
  @KERMIT   — Kermit

External (handled by ExecExternal):
  Any command with MCI codes:
  %0 = comms handle (Win32/OS2)
  %1 = modem port
  %2 = baud rate
  %3 = filename or file list path

## Batch Queue Prompts (default.txt)

| # | Purpose | MCI vars |
|---|---------|----------|
| 046 | Batch queue is full | — |
| 047 | Add file to batch — filename prompt | — |
| 049 | File already in queue | — |
| 050 | File added to batch | &1=filename &2=size |
| 052 | Batch queue is empty | — |
| 054 | File removed from queue | &1=filename &2=size |
| 056 | Batch queue list header | display file |
| 057 | Batch queue list format | display file |
| 059 | Batch queue cleared | — |
| 079 | Batch queue info | &1=files &2=size &3=mins &4=secs |
| 085 | Download queued files? | — |
| 121 | Files still in batch | &1=file count |
| 314 | Lightbar: batch queue full | — |
| 357 | Add which file to batch | — |
| 428 | Batch queue list footer | display file |

### Batch limits
- Max files per queue: 50 (mysMaxBatchQueue in records.pas)
- BatchRec: FileName (70 chars) + Area (Integer) + Size (LongInt)
- Batch protocols only shown when UseBatch=True in SelectProtocol
- Xmodem is NOT batch capable (Protocol.Batch = False)
- All others (Ymodem, Ymodem-G, Zmodem variants, Kermit) support batch

## Single Download Prompts

| # | Purpose | MCI vars |
|---|---------|----------|
| 047 | File Name prompt | — |
| 058 | Downloads per day exceeded | — |
| 062 | Select Protocol prompt | — |
| 063 | Cannot download in local mode | — |
| 065 | Start transfer | &1=protocol name |
| 066 | Disconnect after download? | — |
| 076 | No access to download here | — |
| 078 | File info display | &1=name &2=size &3=uploader &4=date &5=DLs &6=mins &7=secs |
| 083 | Transfer OK | &1=filename |
| 084 | Transfer failed | &1=filename |
| 085 | Download queued files? | — |
| 211 | UL/DL ratio exceeded | — |
| 224 | No access to download this file | — |
| 312 | Lightbar: DL per day exceeded | — |
| 313 | Lightbar: DL ratio exceeded | — |
| 343 | Download file name prompt | display file |
| 351 | User status: transferring | — |
| 384 | File name prompt (alt) | — |
| 385 | Download OK | &1=filename |
| 386 | Download failed | &1=filename |
| 474 | ANSI gallery download confirm | &1=filename |
| 528 | Download via Web+FTP+Protocol | — |
| 529 | Download via FTP+Protocol | — |
| 530 | Download via Web+Protocol | — |
| 531 | Download URL | &1=URL |

## Single Upload Prompts

| # | Purpose | MCI vars |
|---|---------|----------|
| 047 | File name prompt | — |
| 068 | No access to upload here | — |
| 069 | Illegal filename | — |
| 072 | File description header | &1=max lines |
| 073 | File description input line | &1=line number |
| 075 | Thanks for upload | — |
| 078 | File info display | &1=name &2=size &3=uploader &4=date &5=DLs &6=mins &7=secs |
| 080 | Cannot upload to CD-ROM | — |
| 081 | Not enough disk space | — |
| 082 | Copying from CD-ROM | &1=filename |
| 083 | Transfer OK | &1=filename |
| 084 | Transfer failed | &1=filename |
| 089 | Upload test FAILED | — |
| 133 | Upload test PASSED | — |
| 211 | UL/DL ratio exceeded | — |
| 343 | Upload file name prompt | display file |
| 376 | Processing uploads | — |
| 380 | Importing FILE_ID.DIZ | — |
| 381 | DIZ found | — |
| 382 | DIZ not found | — |
| 384 | File name prompt (alt) | — |
| 461 | File already exists — enter new name | — |
| 515 | No access to upload message text | — |

## Web Download (HTTP)

### Current status
mis_client_http.pas is a STUB — 127 lines. Accepts connections,
responds "unknown command" to everything. g00r00 started the HTTP
server but never implemented file serving.

### How it would work (from prompts 528/530)
Prompt 528 offers [W]eb Site as a download option. The flow would be:
1. User picks [W] at prompt 528 or 530
2. BBS generates a temp HTTP URL with a session token
3. Shows prompt 531 with the URL (e.g. http://bbs:8080/dl/token/file.zip)
4. User opens the URL in their browser or terminal
5. HTTP server serves the file, token expires after 1 hour

### Advantages over FTP
- Works through firewalls (port 80/443)
- No FTP client needed — any browser works
- HTTPS possible for encryption
- No passive port range issues

### What needs implementing
- HTTP GET handler for file downloads
- Session token generation and expiry
- File path mapping from token to RecFileBase.Path
- Optional: directory listing as HTML
- Optional: HTTPS/TLS support

### Configuration needed (records.pas — not yet added)
```
inetHTTPUse     : Boolean    HTTP server on/off
inetHTTPPort    : Word       HTTP port (default 8080)
inetHTTPMax     : Word       Max connections
inetHTTPTimeout : Word       Idle timeout
```

### Status: IMPLEMENTED
HTTP file server enabled in MIS (port 8080, hardcoded):
- mis_client_http.pas — 262 lines, HTTP/1.0 GET handler
- Wired into MIS startup (always on, port 8080, max 10 connections)
- Webroot: SystemPath/webroot/ (C:\mystic\webroot\ or /mystic/webroot/)
- No RecConfig changes — hardcoded defaults, data files untouched

URL mapping:
  /                    → webroot/index.html (or BBS name page)
  /page.html           → webroot/page.html (static web pages)
  /style.css           → webroot/style.css (any static file)
  /Games/doom.zip      → file base download via FtpName mapping

Features:
  - Serves static HTML/CSS/images from webroot/ subdirectory
  - File downloads from file base paths (same FtpName as FTP)
  - Content-Type detection (html, txt, zip, jpg, png, mp3, mp4, etc)
  - Content-Disposition header forces download with original filename
  - Path traversal blocked (.. and \ rejected)
  - Connection logging to http.log

Setup:
  1. Create webroot/ directory under Mystic root
  2. Put index.html and static files there
  3. MIS starts HTTP server automatically on port 8080
  4. Browse to http://your-bbs:8080/

### g00r00 Web Server Data Structures (already in records.pas)

RecHistory (daily stats — HISTORY.DAT):
  HTTP : Word — counts HTTP connections per day
  (alongside Telnet, FTP, POP3, SMTP, NNTP counters)

RecConfig:
  Reserved : Array[1..552] of Char — space for HTTP config fields
  (inetHTTPUse, inetHTTPPort, etc would go here in 1.12+)

MIS Event config:
  HTTP : Word — HTTP port number (exists but unused)

g00r00 planned the web download server — data structures are in place,
connection counter ready, port field allocated, prompts written (528/530/531).
The mis_client_http.pas stub was the start. Never completed.

## All Transfer-Related Prompts (default.txt — g00r00 v1.12)

### Protocol Selection
| # | Comment | MCI |
|---|---------|-----|
| 061 | Protocol list entry | &1=hotkey &2=description |
| 062 | Select protocol prompt | — |
| 065 | Start transfer (first word=input chars) | &1=protocol name |
| 066 | Disconnect after download? | — |
| 067 | Disconnecting countdown | — |
| 359 | Protocol list header | — |

### Single File Transfer
| # | Comment | MCI |
|---|---------|-----|
| 047 | File name prompt | — |
| 063 | Cannot download in local mode | — |
| 068 | No access to upload here | — |
| 069 | Illegal filename | — |
| 076 | No access to download here | — |
| 078 | File info display | &1=name &2=size &3=uploader &4=date &5=DLs &6=mins &7=secs |
| 080 | Cannot upload to CD-ROM | — |
| 081 | Not enough disk space | — |
| 082 | Copying from CD-ROM | &1=filename |
| 083 | Transfer OK | &1=filename |
| 084 | Transfer failed | &1=filename |
| 211 | UL/DL ratio exceeded | — |
| 224 | No access to download this file | — |
| 312 | Lightbar: DL per day exceeded | — |
| 313 | Lightbar: DL ratio exceeded | — |
| 314 | Lightbar: batch queue full | — |
| 343 | Upload file name prompt | display file |
| 344 | Download file name prompt | display file |
| 351 | User status: transferring files | — |
| 353 | Archive view file name prompt | — |
| 376 | Processing uploads | — |
| 380 | Importing FILE_ID.DIZ | — |
| 381 | DIZ found | — |
| 382 | DIZ none | — |
| 384 | File name prompt (alt) | — |
| 385 | Download OK | &1=filename |
| 386 | Download failed | &1=filename |
| 461 | File exists — enter new name | — |
| 474 | ANSI gallery download confirm | &1=filename |
| 515 | No access to upload message text | — |

### Upload Description
| # | Comment | MCI |
|---|---------|-----|
| 072 | File description header | &1=max lines |
| 073 | File description input line | &1=line number |
| 075 | Thanks for upload | — |
| 089 | Upload test FAILED | — |
| 133 | Upload test PASSED | — |

### Batch Queue
| # | Comment | MCI |
|---|---------|-----|
| 046 | Batch queue full | — |
| 047 | Add to batch file name prompt | — |
| 048 | Offline file (can't queue) | — |
| 049 | Already in queue | — |
| 050 | Added to batch | &1=filename &2=size |
| 052 | Batch queue empty | — |
| 054 | Removed from queue | &1=filename &2=size |
| 056 | Batch list header | display file |
| 057 | Batch list format | display file |
| 058 | DL per day exceeded | — |
| 059 | Batch cleared | — |
| 079 | Batch info | &1=files &2=size &3=mins &4=secs |
| 085 | Download queued files? | — |
| 121 | Files still in batch | &1=count |
| 357 | Add which file to batch | — |
| 428 | Batch list footer | display file |

### FTP/Web Download
| # | Comment | MCI |
|---|---------|-----|
| 528 | Download via Web+FTP+Protocol | — |
| 529 | Download via FTP+Protocol | — |
| 530 | Download via Web+Protocol | — |
| 531 | Download URL | &1=URL |
