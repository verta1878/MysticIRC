# ansiedit Teleconference — Screen Layout Plan

## Screen Layout — Virtual Pages

Like DOS video pages 0-4. Flip between them instantly.

```
Page 0:  CANVAS (80x25 full drawing area — no shrinking!)
         Row 1-24:  Canvas
         Row 25:    Status bar

Page 1:  CHAT (80x25 full chat window)
         Row 1:     Chat title bar ("Chat — /quit to return to canvas")
         Row 2-23:  Chat scrollback (22 lines of history)
         Row 24:    Separator
         Row 25:    Input line (> type here_)
```

Canvas stays full 80x25 — NEVER shrinks for chat.
Press ALT+C (or /) to flip to chat page.
Press ESC or /quit in chat to flip back to canvas.
New chat messages show a brief indicator on canvas status bar.

## Input Modes

| Page | Keys go to | Purpose |
|------|-----------|---------|
| Page 0 (Canvas) | Drawing — arrow keys, chars, tools | Art editing |
| Page 1 (Chat) | Text input — type messages | Communication |

Switch: ALT+C or / flips to chat. ESC in chat flips to canvas.

### Canvas Status Bar (Page 0, Row 25)
```
 1,5 DRAW/Single iCE * myart.ans [3 users] HOST:8000
```
Shows user count and connection info. Flashes new messages.

## Chat Page (Page 1)

Full 80x25 chat window with scrollback:

```
┌─ Chat ─────────────────────────────── 3 users ─ ESC=Canvas ┐
│ [12:00:01] verta1878 has joined                            │
│ [12:00:15] kiddo has joined                                │
│ [12:00:22] <verta1878> working on the header               │
│ [12:00:35] <kiddo> nice, i'll do the border                │
│ [12:01:10] <evga> left side looks great                    │
│                                                            │
│                    (22 lines scrollback)                    │
│                                                            │
├────────────────────────────────────────────────────────────┤
│ > _                                                        │
└────────────────────────────────────────────────────────────┘
```

### Chat Notification on Canvas (Page 0)
When a new message arrives while on the canvas page, the status
bar (row 25) briefly flashes the message:
```
 1,5 DRAW/Single [NEW MSG: <kiddo> nice shading] HOST:8000
```
Flashes for 3 seconds then returns to normal status.

## Hotkeys

| Key | Action |
|-----|--------|
| ALT+S | Server/Client setup dialog |
| ALT+C or / | Flip to chat page |
| ESC (in chat) | Flip back to canvas |

### ALT+S — Connection Setup Dialog

```
┌─ Server/Client Setup ─────────────────┐
│                                       │
│  Mode:     ( ) Host  ( ) Join         │
│  Host:     [bbs.ecstasy.org_________] │
│  Port:     [8000__]                   │
│  Nick:     [verta1878_______________] │
│  Password: [*****___________________] │
│                                       │
│  [Connect]  [Disconnect]  [Cancel]    │
└───────────────────────────────────────┘
```

Uses existing InputStr/MenuChoice dialogs from ansiedit.

## Access Levels

Three levels control what connected users can do:

Already defined in m_pdnet.pas as TUserLevel:

| Value | Name | Permissions |
|-------|------|-------------|
| 0 | ulViewer | View canvas, chat only — cannot draw |
| 1 | ulEditor | Draw on canvas, chat, change nick |
| 2 | ulOperator | Full control — draw, kick, save, set access |

Default for new connections: ulEditor (1).
Host is automatically ulOperator (2).
SetUserLevel() already exists in m_pdnet.pas.

## Commands (all start with / in chat page)

| Command | Level | Action |
|---------|-------|--------|
| /text | 1+ | Send chat message |
| /who | 1+ | Show connected users with access levels |
| /nick NAME | 1+ | Change display name |
| /save | 2+ | Save canvas (host saves, clients request) |
| /access USER LEVEL | 2 | Set user level (0=viewer, 1=editor, 2=operator) |
| /kick USER | 3 | Kick user |
| /ban USER | 3 | Kick + block IP |
| /lock | 3 | Lock session — no new joins |
| /unlock | 3 | Unlock session |
| /quit | 1+ | Disconnect |

## /who Display (popup over canvas)

```
┌─ Connected Users ──────────┐
│ ■ verta1878    HOST   0ms  │
│ ■ kiddo        CLIENT 12ms │
│ ■ evga         CLIENT 34ms │
│                            │
│ Press any key to close     │
└────────────────────────────┘
```

Colored squares match cursor colors on canvas.

## Remote Cursor Display

Each remote user's cursor shows as a colored block character
on the canvas. The block blinks or uses a distinct char (▒)
so you can tell it from drawn content. When the remote user
moves, their old position restores the canvas underneath.

Colors assigned round-robin:
- User 1: Red ▒
- User 2: Green ▒  
- User 3: Cyan ▒
- User 4: Yellow ▒
- User 5-8: Magenta, Blue, White, Gray

## Network Integration

### Main Loop Change

```
Repeat
  { 1. Check for network data (non-blocking, 10ms timeout) }
  If Connected Then ProcessNetwork;

  { 2. Check for keyboard input }
  If Keyboard.KeyWait(10) Then Begin
    If ActivePage = 0 Then
      ProcessCanvasKey    { drawing tools }
    Else
      ProcessChatKey;     { text input + /commands }
  End;

  { 3. Update chat notification fade on canvas }
  If (ActivePage = 0) and ChatNotify and (TimerSeconds - NotifyTime > 3) Then
    ClearNotify;
Until Done;
```

### ProcessNetwork

```
- Read incoming packets from m_pdnet
- For each packet:
  - CHAR_PLACE: update Canvas[Y,X], redraw cell
  - CURSOR_POS: move remote cursor marker
  - CHAT_MSG: display on row 24
  - USER_JOIN: log to chat, update user count
  - USER_PART: log to chat, update user count
```

### Broadcasting Local Edits

Every PlaceChar/PlaceLineChar call also sends a CHAR_PLACE packet
if Connected. This is a 5-byte message: X, Y, Char, Attr, UserID.

## Connection Flow

### Host
1. ansiedit --host 8000 --nick verta1878
2. Create listening socket on port 8000
3. Enter main loop — draw normally
4. Accept incoming connections in ProcessNetwork
5. Send full canvas sync (80*23*2 = 3680 bytes) to new client
6. Relay all CHAR_PLACE packets to all other clients

### Client  
1. ansiedit --join bbs.ecstasy.org:8000 --nick kiddo
2. Connect to host
3. Receive canvas sync — populate local canvas
4. Enter main loop — draw normally
5. All local edits sent to host, host relays to others
6. Receive remote edits, apply to local canvas

## Files

| File | Purpose |
|------|---------|
| ansiedit.pas | Main editor + TC integration |
| m_pdnet.pas | Protocol engine (packets, encode/decode) |
| m_pdtypes.pas | Type definitions |
| TC-PLAN.md | This file |
| TELECONFERENCE-PLANNED.md | User-facing setup guide |

## Phase Breakdown

| Phase | What to build |
|-------|---------------|
| TC-1 | Virtual page system (page 0=canvas, page 1=chat), ALT+C flip, chat scrollback buffer |
| TC-2 | --host/--join flags, socket create/connect, canvas sync on join |
| TC-3 | ProcessNetwork in main loop, CHAR_PLACE send/receive, chat message relay |
| TC-4 | Remote cursor display (colored ▒ with save/restore underneath) |
| TC-5 | /who popup, /nick, /kick, user join/part messages in chat |
| TC-6 | /save (host saves, client requests), disconnect cleanup |


## Networking by Platform

| Platform | TCP | Serial | Notes |
|----------|-----|--------|-------|
| Linux/Windows | FPC Sockets | N/A | Just works |
| GO32V2 (32-bit DOS) | fpc264irc Sockets.pp | FOSSIL/UART | No extender issues |
| i8086 (16-bit DOS) | MSLAN + Sockets.pp | FOSSIL/UART | MSLAN needed for TCP |

No Watt-32. All TCP goes through fpc264irc's own Sockets.pp.
Plain DOS serial works natively — no helpers needed.
