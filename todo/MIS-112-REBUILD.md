# MIS 1.12 Rebuild Plan

## Reference
Screenshot from Ecstasy BBS (verta1878) running Mystic 1.12 MIS.

## 1.12 UI Features (from screenshot)

### Title Bar
- "Mystic Internet Server (BBS_NAME)" — pulls BBS name from config
- Windows console title bar

### ASCII Art Header
- Large "MYSTIC" logo in blue/cyan with yellow lightning bolt
- "Press ESCAPE for Menu" prompt at right side
- Takes approximately 5 rows of screen

### Tab Bar (switchable panels)
- Messages — scrolling timestamped log (DEFAULT view)
- Connections — active node/user list
- Events — timed event scheduler
- Stats — server statistics (port, active, blocked, refused, total)

### Messages Panel (main view)
- Full-width scrolling log
- Format: HH:MM:SS SERVICE NODE-ACTION DETAILS
- Timestamped to the second
- Service names: TELNET, SMTP, POP3, FTP, NNTP, BINKP, HTTP
- Actions seen:
  - "Creating terminal process"
  - "Closing terminal process"
  - "> Connect on slot N/MAX (IP.ADDRESS)"
  - "N-HostName hostname.domain.com"
  - "N-Refused (Duplicate IP)"
- Color coding: timestamps in one color, service in another, details in white
- Scrolls automatically, likely with scrollback buffer

### Menu System
- "Press ESCAPE for Menu" — popup menu (not status bar hotkeys)
- Replaces the old TAB/SPACE/ALT-K/ESC status bar approach
- Menu likely contains: Local Login, Kill Node, Shutdown, Config, etc.

### Connections Panel (tab 2)
- Node list with user, action, IP, connect time
- Slot-based: "slot 1/8" means node 1 of 8 max

### Events Panel (tab 3)
- Timed event scheduler
- Shows next run time, last run time, event name

### Stats Panel (tab 4)
- Per-service statistics
- Port, Max connections, Active, Blocked, Refused, Total

## Architecture Differences from 1.10/1.11

| Feature | 1.10/1.11 (ours) | 1.12 (target) |
|---------|-----------------|----------------|
| Layout | Split panels side-by-side | Full-width tabbed panels |
| Header | Plain text title | ASCII art logo + BBS name |
| Navigation | Status bar hotkeys | ESC menu + tab switching |
| Log format | Plain text | Timestamped with service/node |
| IP display | Not shown | Full IP + hostname resolution |
| Slot info | "001 Waiting" | "Connect on slot 1/8 (IP)" |
| Duplicate IP | Not tracked | "Refused (Duplicate IP)" |
| Screen data | Embedded IMAGEDATA const | Needs new ANSI screen |
| Hostname | Not resolved | DNS reverse lookup shown |

## Implementation Phases

### Phase MIS-1: New ANSI Screen (DONE)
- Create new mis_wfc112.ans with ASCII art header
- Tab bar rendering with highlight for active tab
- Full-width log area below tabs
- "Press ESCAPE for Menu" prompt

### Phase MIS-2: Tabbed Panel System
- Messages tab: scrolling timestamped log with scrollback
- Connections tab: node list with IP, hostname, connect time
- Events tab: scheduler display
- Stats tab: per-service statistics table

### Phase MIS-3: Enhanced Logging
- Timestamped log entries (HH:MM:SS)
- Service name prefix (TELNET, SMTP, etc.)
- Node number in log entries
- IP address display on connect
- Hostname resolution (DNS reverse lookup)
- Duplicate IP detection and refusal logging
- Scrollback buffer (configurable depth)

### Phase MIS-4: Menu System
- ESC key opens popup menu
- Menu items: Local Login, Kill Node, Shutdown, Configuration
- Replace status bar hotkeys with menu

### Phase MIS-5: BBS Name Integration
- Console title: "Mystic Internet Server (BBS_NAME)"
- Read BBS name from bbsCfg / MYSTIC.DAT config
- Display in header area

### Phase MIS-6: Connection Management
- Slot-based display: "slot N/MAX"
- Per-service max connection tracking
- Duplicate IP detection and configurable action
- Connection duration tracking

## Files to Modify
- mis_ansiwfc.pas — complete rewrite (new screen, new drawing)
- mis.pas — main loop: tab switching, ESC menu, enhanced logging
- mis_server.pas — slot info, IP logging, hostname resolution
- mis_common.pas — log entry format, scrollback buffer
- mis_nodedata.pas — enhanced node data (IP, hostname, connect time)
- NEW: mis_wfc112.ans — new WFC ANSI art screen

## Dependencies
- DNS reverse lookup: needs m_io_Sockets or platform-specific resolver
- Scrollback buffer: circular buffer in mis_common
- Duplicate IP tracking: hash table in mis_server

## Priority
After: ripview completion, v1-v4 backport, ANSI editor extraction
Before: openwatcomirc, password migration

### Phase MIS-7: IPv6 Support
- Dual-stack listener: IPv6 + IPv4 on same port
- Auto-detect IPv6 availability at startup
- Fall back to IPv4-only on XP / systems without IPv6 stack
- Based on evga's 1.12 cleanup
- Display IPv6 addresses in connection log
- No user configuration needed — just works
