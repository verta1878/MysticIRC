# ansiedit — Teleconference Setup Guide

## Overview

ansiedit supports collaborative ANSI art editing over TCP using the
PabloDraw network protocol. Multiple users connect to a shared canvas
and see each other's edits in real-time, with text chat alongside.

## Modes

### Host Mode (Server)
One user hosts the session. Other users connect to them.

```bash
ansiedit --host 8000
ansiedit --host 8000 myart.ans        # host with existing file
ansiedit --host 8000 --nick SysOp     # set display name
ansiedit --host 8000 --password secret # require password to join
```

### Join Mode (Client)
Connect to an existing session.

```bash
ansiedit --join bbs.example.com:8000
ansiedit --join bbs.example.com:8000 --nick Artist
ansiedit --join 192.168.1.5:8000 --password secret
```

### Local Mode (Default)
No networking — just edit locally like any ANSI editor.

```bash
ansiedit                    # new blank canvas
ansiedit myart.ans          # edit existing file
```

## Command Line Reference

| Flag | Description |
|------|-------------|
| `--host PORT` | Host a teleconference session on PORT |
| `--join HOST:PORT` | Join a teleconference session |
| `--nick NAME` | Set your display name (default: system user) |
| `--password PASS` | Set/require session password |
| `--readonly` | Join in view-only mode (watch others draw) |
| `--maxusers N` | Max connected users when hosting (default: 8) |
| `--nosauce` | Save without SAUCE record |

## In-Session Commands

Once connected, these commands are available via ESC menu or hotkeys:

| Key | Command | Description |
|-----|---------|-------------|
| ESC | Menu | Opens the main menu |
| / | Chat | Type a chat message (visible to all users) |
| CTRL+W | Who | Show connected users list |
| CTRL+N | Nick | Change your display name |
| CTRL+K | Kick | Kick a user (host only) |
| CTRL+S | Save | Save canvas to file |
| CTRL+Q | Quit | Disconnect and exit |

## How It Works

### Connection Flow
1. Host starts ansiedit with `--host PORT`
2. Server listens on the specified TCP port
3. Client starts ansiedit with `--join HOST:PORT`
4. Server sends full canvas state to new client (sync)
5. Both sides enter collaborative edit mode

### Canvas Synchronization
- Every character placement is broadcast as a delta update
  (position + character + attribute = 5 bytes per edit)
- Cursor positions are broadcast so you can see where others
  are drawing (shown as colored markers)
- Full canvas resync can be requested if client gets out of sync

### Protocol (m_pdnet.pas)
Binary packet format over TCP:

| Packet | Direction | Payload |
|--------|-----------|---------|
| CONNECT | C→S | Protocol version, nick, password |
| WELCOME | S→C | Session info, user list |
| CANVAS_SYNC | S→C | Full 80x25 canvas dump (4000 bytes) |
| CHAR_PLACE | Both | X(1) Y(1) Char(1) Attr(1) |
| CURSOR_POS | Both | X(1) Y(1) UserID(1) |
| CHAT_MSG | Both | UserID(1) Length(1) Text(N) |
| USER_JOIN | S→C | UserID(1) Nick(N) |
| USER_PART | S→C | UserID(1) |
| NICK_CHANGE | Both | UserID(1) Nick(N) |
| KICK | S→C | UserID(1) Reason(N) |
| SAVE_REQ | C→S | Filename(N) — host saves |
| DISCONNECT | Both | (empty) |

### Chat Overlay
Chat messages appear at the bottom of the screen in a 3-line
scrolling area. Messages fade after 10 seconds. Press `/` to
type a message. The chat area does not interfere with the canvas.

### User Cursors
Each connected user's cursor is shown as a colored block character
on the canvas. Colors are assigned automatically:
- User 1: Bright Red
- User 2: Bright Green
- User 3: Bright Cyan
- User 4: Bright Yellow
- User 5-8: Bright Magenta, Bright Blue, White, Light Gray

## Network Requirements

- TCP port must be reachable (firewall/NAT forwarding)
- No encryption (plaintext) — use SSH tunnel for security
- Bandwidth: ~50 bytes per edit, ~4KB for full sync
- Latency: works well up to ~200ms RTT

## Example Session

### Terminal 1 (Host)
```
$ ansiedit --host 8000 --nick verta1878
ansiedit v1.11IRC — Hosting on port 8000
Waiting for connections...
[12:00:01] verta1878 hosting session
[12:00:15] kiddo joined
[12:00:22] evga joined
```

### Terminal 2 (Client)
```
$ ansiedit --join bbs.ecstasy.org:8000 --nick kiddo
ansiedit v1.11IRC — Connecting to bbs.ecstasy.org:8000...
Connected! 2 users online: verta1878, kiddo
```

### Terminal 3 (Client)
```
$ ansiedit --join bbs.ecstasy.org:8000 --nick evga
ansiedit v1.11IRC — Connecting to bbs.ecstasy.org:8000...
Connected! 3 users online: verta1878, kiddo, evga
```

All three users now see the same canvas and can draw simultaneously.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Connection refused" | Check host is running, port is correct, firewall allows TCP |
| Canvas out of sync | Press CTRL+R to request full resync |
| Lag/delay | Check network latency; reduce edit speed |
| "Session full" | Host needs to increase --maxusers |
| Can't save | Only the host can save; clients request save via CTRL+S |
