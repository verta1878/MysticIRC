# RIPTEL v3.1 Protocol Analysis — Server vs Client Features

Source: RIPTEL v3.1 (TeleGrafix Communications, 1997)
Analysis of scene files (.FN, .DEF, .MNU, .MSE) and RIPTEL.EXE strings.

---

## Discovery: RIPscript Level 2 Commands

RIPTEL scene files reveal a complete **scripting language** beyond
basic drawing commands:

### Conditional Logic
```
<<IF $VARIABLE$="value">>...<<ELSE>>...<<ENDIF>>
<<IF $COLORS$<"256">>BLUEBACK.FN<<ELSE>>BLUEFADE.FN<<ENDIF>>
<<IF $TGMENU_ISREG$="0">>$>register.mse$<<ELSE>>$NULL$<<ENDIF>>
```

### Variable Assignment & Dereference
```
$-=VARNAME=value$     — assign variable (prefix -)
$=-VARNAME=value$     — assign variable (prefix =-)
$VARNAME$             — dereference variable in any text
<<VARNAME>>           — dereference in command parameters
$>FILENAME.FN$        — load and execute scene file
$NULL$                — no-op (used in ELSE branches)
$OFF$                 — disable feature
$RESET$               — reset engine state
$MCURSOR(N)$          — set mouse cursor style (0-6)
```

### File Includes (Modular Scene System)
```
|1R00000000FILENAME.FN    — include/execute a scene file
```

Scene files are split into modular components:
- `.DEF` — variable definitions (labels, commands, messages)
- `.MNU` — menu layout (drawing commands + button images)
- `.MSE` — mouse event handlers (mouse fields + click commands)
- `.FN`  — scene entry points (orchestrate DEF+MNU+MSE)
- `.RET` — return scenes (go back to parent menu)

### Mouse Event Queries
```
|1M — extended mouse field with command binding
      Format: |1M coords ID=N:$<<CMD>>$
      Executes $<<CMD>>$ variable when mouse field N clicked

|1K — kill all mouse fields

Entry/exit queries:
  5000$MCURSOR(4)$$>file.ent$  — mouse enter event
  6000$MCURSOR(0)$$>file.ext$  — mouse exit event
```

### Drawing Ports (Layers)
```
|2P — create/delete drawing port (numbered 0-9)
|2C — copy region between ports
```

---

## Phase 16: Cursor & Terminal Queries

### Server-side (engine can do):
- `$CURX$`, `$CURY$` — track current drawing position ✅
- `$CURSOR$` — cursor visibility state ✅
- `$MCURSOR(N)$` — set mouse cursor style (render hint) ✅
- Text window coordinates (`$TWX0$`..) ✅

### Client-side only (needs terminal round-trip):
- ANSI cursor position query (ESC[6n → ESC[row;colR)
- Terminal size detection via cursor query
- These require a real bidirectional connection

**Recommendation:** Server sends cursor query command, client
responds with position. Engine tracks position internally.
The query is for ANSI text mode, not graphics mode.

---

## Phase 20: Data Tables & Forms

### Server-side (engine can render):
- Button images with labels (`|1b` + `<<LAB1>>` variable) ✅
- Mouse fields with click handlers (`|1M ... ID=N:$<<CMD>>$`) ✅
- Status bar messages on hover (`$=-MSG1=text$`) ✅
- Variable-driven menus (DEF/MNU/MSE system) ✅
- Conditional display (`<<IF>>..<<ELSE>>..<<ENDIF>>`) ✅

### Client-side only (needs input events):
- Text input fields (edit boxes) — needs keyboard events
- Dropdown/listbox selection — needs scrolling + selection
- Form validation (email, phone, zip) — RIPTEL has these!
- Form submission to server — needs protocol message

**What RIPTEL has:**
```
RIP_QueryCommand        — send query to server
RIP_DefineTextVariable  — define variable
RIP_DeleteTextVariable  — delete variable
RIP_RegisterTextVariable — register for events
```

RIPTEL validates: ZIP codes, Canadian postal codes, expiration
dates (MM/YY), serial numbers, state codes. All client-side.

---

## Phase 22: Audio & Multimedia

### Server-side (engine can do):
- WAV file reference (send filename to client) ✅
- Animation frame sequences (LoadAnimFrame) ✅
- Palette cycling/fading (PalCycle, FadeIn, FadeOut) ✅
- Frame rate control (SetFrameRate) ✅
- Scene transitions via WIPE*.FN files ✅

### Client-side only (needs audio hardware):
- WAV playback (`*.wav` file filter in RIPTEL)
- MIDI playback (not found in RIPTEL — may not exist)
- Audio mixing (no evidence in RIPTEL)
- Streaming audio (no evidence)

**What RIPTEL actually supports:**
- WAV file playback — confirmed (file filter present)
- MIDI — NOT confirmed (no MIDI strings found)
- Audio mixing — NOT confirmed
- The v3 whitepaper overpromised; RIPTEL only does WAV

### Screen Transitions (WIPE system)
24 wipe effects found: WIPE00.FN through WIPE24.FN
Plus: SHADOW.FN (shadow overlay), FXSHWIMG.FN (show image FX)
These are RIPscript scene files that draw transition patterns.

---

## Protocol Version Header

Every scene file starts with:
```
|J10     — protocol version 1.0
|n2000   — resolution (base-36: 2000 = varies by context)
|M08     — color mode 08 = 256 colors
|fZKQO   — font select (base-36 font ID)
```

---

## System Variables (from RIPTEL.EXE)

| Variable | Purpose |
|----------|---------|
| `$COLORS$` | Color depth ("16" or "256") |
| `$TGMENU_ORIGIN$` | Distribution source |
| `$TGMENU_ISREG$` | Registration status ("0"/"1") |
| `$TGMENU_WIPES$` | Wipe effects enabled ("0"/"1") |
| `$TGMENU_DIALDIR$` | Open dial directory |
| `$TGMENU_HELP(x)$` | Open help topic |
| `$TGMENU_MACROS$` | Open macros |
| `$TGMENU_EXIT$` | Exit application |
| `$TGMENU_SCROLLBACK$` | Open scrollback buffer |
| `$TGMENU_SETUP$` | Open setup dialog |
| `$TGMENU_WEB$` | Open web browser |
| `$TGMENU_REGISTER$` | Open registration |
| `$MCURSOR(N)$` | Set cursor (0=default, 4=hand, 6=wait) |
| `$RESET$` | Reset engine state |
| `$NULL$` | No-op |
| `$OFF$` | Disable feature |

---

## File Inventory

| Type | Count | Purpose |
|------|-------|---------|
| .RFF | 8 | Scalable vector fonts |
| .CHR | 11 | BGI stroke fonts |
| .FN | 48 | Scene files (command sequences) |
| .DEF | 4 | Variable definitions |
| .MNU | 3 | Menu layouts |
| .MSE | 4 | Mouse event handlers |
| .BMP | ~100 | Bitmap images |
| .JPG | 7 | JPEG images |
| .ICN | ~20 | RIPscript icons |
| .maf | 1 | MicroANSI bitmap font |
| .DB | 1 | Text variable database |
| .RES | 1 | Resource file |
| .HLP | 2 | Help files |

---

## Key Takeaway

The v2.0/3.0 protocol is MORE than drawing commands. It's a
**modular scene scripting system** with:
1. Conditional logic (IF/ELSE/ENDIF)
2. Variable assignment and dereference
3. File includes (modular scenes)
4. Mouse event binding (click → execute command)
5. Drawing port layering
6. 24 screen transition effects

Most of this is IMPLEMENTABLE server-side. The only truly
client-side features are:
- Terminal cursor query response
- Text input fields (keyboard events)
- WAV audio playback (hardware access)
- Form validation (client-side logic)
