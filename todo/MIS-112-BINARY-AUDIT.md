# MIS 1.12 Binary Audit — mis.exe (v1.12 A49, 2024/05/29)

Extracted from Ecstasy BBS mis.exe (1.5MB, PE32 Windows/32).

## Features Found

### 1. IPv6 Dual-Stack
- `Listening on IPV4 port |15` / `Listening on IPV6 port |15`
- `Listening on IPV4 SSL port |15` / `Listening on IPV6 SSL port |15`
- `Unable to open IPV4 port: Error |15` / `Unable to open IPV6 port: Error |15`
- `Cannot resolve IPV4 domain, using|08: |15` / `Cannot resolve IPV6 domain, using|08: |15`
- `IPV4 accept error` / `IPV6 accept error`
- `Cannot set IPV6_V6ONLY` — dual-stack socket option
- `IPV6+IPV4` / `IPV4+IPV6` — listen mode strings

### 2. TLS/SSL (via cryptlib)
- `MANAGER |12Cryptlib not detected; SSL/SSH capabilities disabled`
- `Connection upgraded to |14TLS`
- `Starting TLS negotiation` / `Negotiating TLS`
- `Failed to activate TLS` / `Error setting TLS version`
- `Unable to set TLS 1.2`
- `Client requires TLS` / `TLS connection required`
- `STARTTLS` (SMTP), `STLS` (POP3)
- `ssl.cert` — certificate file
- SSL ports separate from plain ports
- TSocketSSL class

### 3. MANAGER Log Prefix
All system-level messages use `MANAGER` prefix:
- `MANAGER Starting |15` (server name)
- `MANAGER Shutdown|08: |15` (server name)
- `MANAGER Shutdown|08: |15EVENT`
- `MANAGER Shutdown|08: |15SENDMAIL`
- `MANAGER Starting event system`
- `MANAGER Server shutdown received from console`
- `MANAGER Waiting for servers to stop (up to 30 seconds)`
- `MANAGER Shutdown complete`
- `MANAGER |12Cannot register all servers. Maximum reached!`
- `MANAGER |12Cryptlib not detected; SSL/SSH capabilities disabled`
- `MANAGER |12Error in connections list`
- `MANAGER |12No servers have been configured`

### 4. Connection Log Format (pipe codes)
- `|14> |07Connect on slot |15` — new connection
- `-HostName |15` — DNS reverse lookup
- `-Refused (Duplicate IP)` — duplicate IP rejection
- `-Blocked connection`
- `-Creating terminal process`
- `-Closing terminal process`
- `-Connection closed`
- `-Client shutting down`
- `-Auto banning IP |15`
- `-Country  |15` — GeoIP country lookup!
- `-|12Cannot duplicate socket`
- `-|12Error`
- `-|12Failed to create node:`
- `Connection upgraded to |14TLS`
- `Connection dropped (`

### 5. ANSI Screen Files
- `mis_status1.ans` / `mis_status2.ans` — two status screens!
- `mis_events.ans` — events display
- `mis_stats.ans` / `mis_statdata.ans` — statistics display
- `mis_help.ans` — help screen
- `mis_poll.ans` — poll status

### 6. FTN/BinkP Poll System
- `POLL LIST` / `POLL SEARCH` / `POLL ROUTE`
- `POLL KILLBUSY` / `POLL SEND` / `POLL FORCED` / `POLL UPLINK`
- `Polling all nodes of session type |15`
- `Polling all uplinks of session type |15`
- `Poll BINKP node via address lookup: |15`
- `Sending to all nodes of session type |15`
- FTP hostname + BINKP hostname per node
- Outbound mail detection
- BSY file management (create, remove, stale)
- Echomail/Netmail routing

### 7. HTTP Server
- `Server: Mystic/1.12 A49 (Windows/32)`
- `MYSTIC/1.12` user agent
- `Using Webroot|08: |15`
- `WebUI|08: |15` — web interface!
- HTTP error pages, 404 handling
- `HTTP/1.0` responses
- `Connection: close`

### 8. Script Server
- `TScriptServer` — custom script execution
- `Script Connection closed`
- `Script error`
- Lape scripting engine (assertions, ranges, etc.)
- `function clientconnected:boolean`
- `function clientread` / `procedure clientwrite`

### 9. Shutdown Flow
- `[MIS] Creating shutdown event`
- `[MIS] Shutdown may take up to 10 seconds to begin`
- `Shutdown Servers?` — confirmation prompt
- `Warning: Events are running. Shutdown servers?`
- `Sending shutdown notice to node|08: |15`
- `mis.shutdown` — shutdown flag file

### 10. Ghost Node Detection
- `Resetting ghost node|08: |15` — detects/clears stale nodes
- `Corrupt node data`
- `Missing node data`

### 11. Auto-Ban
- `-Auto banning IP |15`
- `BLOCKED` status
- `blocked.txt` — block list file
- `connection(s) per IP` — per-IP connection limit
- `IP Block`
- Ban tracking with time limit

### 12. Country/GeoIP
- `-Country  |15` — GeoIP country display in connection log

### 13. Download Request System
- `Removing expired download request|08: |15`
- `dlreq_error.txt`
- File database integration

## Pipe Code Color Scheme
| Code | Color | Usage |
|------|-------|-------|
| |07 | Light gray | Normal text |
| |08 | Dark gray | Separators, punctuation |
| |12 | Light red | Errors |
| |14 | Yellow | SSL/TLS, highlights |
| |15 | Bright white | Values, names, IPs |
| |16 | Black (reset) | Background |

## Server Types in Binary
| Server | Class | Protocol |
|--------|-------|----------|
| Telnet | TServerClient | BBS terminal |
| SMTP | TSMTPServer | Email send |
| POP3 | TPOP3Server | Email retrieve |
| FTP | TFTPServer | File transfer |
| NNTP | TNNTPServer | Usenet/news |
| BinkP | TBINKPServer | FTN mailer |
| HTTP | THTTPServer | Web server |
| Script | TScriptServer | Custom scripts |
| Event | TEventManager | Timed events |

## Files Referenced
| File | Purpose |
|------|---------|
| mystic.dat | Main BBS config |
| servers.dat | Server configuration |
| echonode.dat | FTN echo nodes |
| event.dat | Event scheduler |
| messages.dat | Message base |
| nodeinfo.now | Node status |
| nodelist.txt | FTN nodelist |
| blocked.txt | IP block list |
| ssl.cert | TLS certificate |
| mis.shutdown | Shutdown flag |
| errors.log | Error log |
| *.ans | ANSI display files |

## What We're Missing vs 1.12

| Feature | Our Status | 1.12 Has It |
|---------|-----------|-------------|
| IPv6 dual-stack | ❌ MIS-7 planned | ✅ |
| TLS/SSL (cryptlib) | ❌ | ✅ |
| HTTP server | ❌ | ✅ |
| Script server | ❌ | ✅ |
| MANAGER log prefix | ❌ | ✅ |
| Pipe code colors in log | ❌ | ✅ |
| Country/GeoIP | ❌ | ✅ |
| Auto-ban by IP | ❌ | ✅ |
| Ghost node detection | Partial | ✅ |
| FTN/BinkP polling | ✅ fidopoll (separate) | ✅ (built-in) |
| Download requests | ❌ | ✅ |
| WebUI | ❌ | ✅ |
| Multiple ANSI screens | ❌ (1 screen) | ✅ (6 screens) |
| Tabbed UI | ✅ MIS-1 done | ✅ |
| Timestamp logs | ✅ MIS-1 done | ✅ |

## Script Server — Deep Dive

### What It Does
The Script Server (TScriptServer) lets sysops expose custom MPL scripts
as standalone TCP services. MIS listens on a configured port and when a
client connects, it spawns the MPL script with socket I/O functions.

### Use Cases
- **Door games over TCP** — play without BBS login
- **JSON/REST API** — expose BBS data to web apps, bots, Discord
- **Custom auth service** — external login validation
- **Inter-BBS messaging** — custom FTN-like protocol
- **Bot interface** — IRC bridge, Telegram bot, webhook receiver
- **Status page** — serve BBS stats over HTTP-like protocol
- **Remote admin** — sysop tools without full BBS session

### How It Works
1. Sysop configures a port + script path in MIS config
2. MIS listens on that port like any other server
3. On connect: spawns MPL script with socket handle
4. Script uses clientread/clientwrite/clientconnected to talk to client
5. Script exits → connection closed

### Implementation Plan (MIS-8)
- Add TScriptServer class (inherits TServerManager pattern)
- Config: port, script path, max connections
- MPL functions: clientconnected, clientread, clientwrite, clientclose
- Pass socket handle to MPL runtime via environment
- Script runs in its own thread (like telnet nodes)

### Priority
Medium — requires MPL runtime integration. Dependencies: working MIS
tabbed UI (MIS-1/2 done), server framework (already exists for other
protocols).


## Scripting Languages — From Full 1.12 A49 Package

### Python (embedded via DLL)
- Python 2.7: `python27.dll` / `libpython2.7.so.1.0` / `libpython2.7.dylib`
- Python 3.6-3.11: `python36.dll` through `python311.dll`
- Optional — auto-detected at startup
- BBS module: `import mystic_bbs as bbs`
- Functions: write, writeln, getkey, getstr, getuser, onekey, keypressed,
  menucmd, shutdown, param_str, param_count
- Planned: gotoxy, showfile, textattr, access, hangup, log, and more
- Menu commands: PYTHON2 / PYTHON3 to execute scripts
- Config: Python 2/3 library path (blank = auto-search)

### Lape (embedded Pascal scripting)
- Compiled directly into MIS binary
- Full Pascal-like language (types, records, exceptions, methods)
- Used for Script Server (TScriptServer) in MIS
- More powerful than old MPL bytecode

### MPL (legacy Mystic Programming Language)
- "Execute Mystic Script" menu command
- 168 built-in functions
- Bytecode compiled via mplc.exe
- Still supported alongside Python

### Perl
- NOT supported in 1.12 A49
- Zero Perl references in mystic.exe or mis.exe binaries

### MRC Client (Python)
- mrc_client.py / mrc_client2.py / mrc_client3.py
- Multi-Relay Chat — external Python script, not embedded
- Runs as separate process alongside MIS
