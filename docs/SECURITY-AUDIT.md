# Security & Code Audit — 2026-08-14

Performed by sysop/0. Mystic BBS 1.11IRC full source scan.

## Findings — ALL FIXED

| # | Severity | File | Issue | Status |
|---|----------|------|-------|--------|
| 3 | MEDIUM | m_tcp_client_ftp.pas:246 | FTP path traversal — FileName sanitized with JustFile, rejects `..` | FIXED |
| 5 | MEDIUM | m_fossil_io.pas:258 | DSR vs DCD — tries DCD first, falls back to DSR | FIXED |
| 1 | LOW | m_io_sockets.pas:346 | fpSend return on IAC — documented as intentional | FIXED |
| 6 | LOW | m_tcp_client.pas:91 | Debug WriteLn removed | FIXED |

## Findings from second scan — ALL FIXED

| # | Severity | File | Issue | Status |
|---|----------|------|-------|--------|
| B-1 | HIGH | m_io_sockets.pas | WriteBufEscaped loop 0..Len → 0..Len-1 (read past buffer) | FIXED |
| B-2 | HIGH | m_io_sockets.pas | WriteBufEscaped Dec(TempPos) → removed (sent 1 byte short) | FIXED |
| B-3 | MEDIUM | serial.pas | SerDrain infinite loop → added 50K iteration timeout | FIXED |
| B-7 | MEDIUM | m_fossil_io.pas | ReadAvail O(n²) string concat → SetLength per-char | FIXED |
| B-8 | MEDIUM | m_io_sockets.pas | Telnet subneg no length cap → 4096 byte cap, reset on overflow | FIXED |
| B-9 | MEDIUM | m_socket_server.pas | CheckIP index past Str2 → bounds check added | FIXED |
| B-4 | LOW | serial.pas | SerFlushInput no limit → 64K iteration limit | FIXED |
| B-5 | LOW | serial.pas | SerBreak no delay → delay loop added | FIXED |
| B-6 | INFO | serial.pas | SerOpen scratch register probe → documented fragility | FIXED |

## Not Bugs (confirmed correct)
- Ring buffer implementation is correct (kiddo verified)
- Telnet IAC double-escape is RFC 854 compliant
