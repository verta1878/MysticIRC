# RIPscrip v3.0 — Client/Server Architecture

## Overview

The RIPscrip v3.0 engine (`rip3api.pas`) operates in a split architecture
where the **server** (BBS host) owns the data model and rendering pipeline,
and the **client** (terminal/viewer) handles user interaction.

The engine implements BOTH sides. The host application bridges them by
processing input events and calling the appropriate API methods.

---

## Server-Side (BBS Host)

The server is responsible for:

### Data Model
- Table definitions (TRIPTable — columns, rows, cells, alignment)
- Form field definitions (TRIPFormField — type, position, constraints)
- Text variable storage (TRIPVariable — name, value, scope, persistence)
- Scene state (resolution, palette, viewport, font selections)

### Rendering
- Table rendering to pixel buffer (TableRender)
- Form field rendering to pixel buffer (FormRender)
- Text rendering with variable expansion (OutTextXY, DrawText8x8, DrawTextMAF, DrawTextRFF)
- All drawing primitives (Line, Rectangle, Circle, etc)
- Image loading and blitting (LoadJPEG, LoadGIF, LoadPNG, etc)
- BMP export (SaveBMP)

### Variable Management
- DefineVar / SetVar / GetVar / KillVar / KillAllVars
- ExpandVars — replaces $VARNAME$ tokens in text strings
- FormSyncToVars — pushes form field values into text variables
- FormSyncFromVars — pulls text variable values into form fields
- $RESET(PAL)$ — resets palette to EGA defaults during text expansion
- $RESET(ALL)$ — full engine state reset during text expansion

### Validation
- FormValidate — checks Required fields before submission
- Variable type/range validation (future)

### Server API Methods

```
Tables:
  TableCreate(X, Y, Cols)
  TableAddCol(Title, Width, Align)
  TableAddRow
  TableSetCell(Row, Col, Text, Color)
  TableRender
  TableClear
  TableScroll(Delta)
  TableSetVisRows(Rows)
  TableGetRows / TableGetCols

Forms (definition):
  FormAddField(FieldType, Name, X, Y, W, H) : Integer
  FormSetOptions(Idx, Options)
  FormBindVar(Idx, VarName)
  FormSetRequired(Idx, Req)
  FormValidate : Boolean

Variables:
  DefineVar(Name, Value, Persist, Required)
  SetVar(Name, Value)
  GetVar(Name) : String
  KillVar(Name)
  KillAllVars
  ExpandVars(S) : String
  FormSyncToVars
  FormSyncFromVars
```

---

## Client-Side (Terminal/Viewer)

The client is responsible for:

### User Input
- Keyboard input into focused text fields
- Mouse clicks on checkboxes (toggle "0"/"1")
- Dropdown arrow clicks (expand options, select)
- Listbox scrolling and selection
- Focus cycling (Tab/Shift-Tab between fields)

### Display
- Receives rendered pixel buffer from server
- Highlights focused field (bright border)
- Renders dropdown expansion overlay (future)

### Communication
- Sends field values back to server via RIP protocol
- Receives form definitions from server (FormAddField commands)
- Receives variable updates from server

### Client API Methods

```
Forms (interaction):
  FormSetValue(Idx, Value)
  FormGetValue(Idx) : String
  FormRender
  FormClear
```

---

## Variable Scoping

Variables have three scope levels, all managed server-side:

### Local Scope
- Created during RIP scene processing
- Cleared automatically when scene ends (ClearScreen or new scene load)
- Used for temporary values within a single screen
- Example: loop counters, intermediate calculations

### Session Scope
- Persists for the duration of the user's connection
- Cleared when user disconnects
- Used for user preferences, navigation state, form data
- Example: $USERNAME$, $TERMINAL$, selected menu options

### Persistent Scope
- Saved to disk (via the Persist flag in TRIPVariable)
- Survives between sessions — loaded on next connection
- Used for user settings, saved preferences, statistics
- Example: $LAST_LOGIN$, $TOTAL_CALLS$, $EXPERT_MODE$

### Scope Lifecycle

```
Connection starts
  └─ Load persistent variables from disk
      └─ Session begins
          └─ Scene loads
          │   └─ Local variables created
          │   └─ Scene processing...
          │   └─ Scene ends → local variables cleared
          └─ Next scene loads
          │   └─ New local variables
          │   └─ Session variables still available
          │   └─ Scene ends → local cleared again
          └─ User disconnects
              └─ Save persistent variables to disk
              └─ Session variables cleared
              └─ All done
```

### Scope in Code

```pascal
// Local — cleared on scene end
RIP.DefineVar('TEMP', '42', False, False);

// Session — persists for connection (Persist=False, but not cleared on scene end)
// Use the Session flag (future: scope parameter in DefineVar)

// Persistent — saved to disk
RIP.DefineVar('TOTAL_CALLS', '100', True, False);
```

---

## Data Flow

### Complete Request/Response Cycle

```
SERVER                          CLIENT
  │                               │
  ├─ FormAddField (define form) ──►│
  ├─ FormBindVar (bind $VAR$)     │
  ├─ FormRender (draw fields) ────►│ displays form
  │                               │
  │                          ◄────┤ user types/clicks
  │     FormSetValue(idx, val)    │
  │     FormRender (redraw)  ─────►│ updated display
  │                               │
  ├─ FormValidate                 │
  │   ├─ TRUE: FormSyncToVars     │
  │   │   └─ $VAR$ now available  │
  │   │   └─ Process submission   │
  │   └─ FALSE: show error        │
  │                               │
  ├─ SetVar('RESULT', 'OK')       │
  ├─ FormSyncFromVars         ────►│ server pushes update
  │                               │
```

### Table Display (Server-Only)

```
SERVER                          CLIENT
  │                               │
  ├─ TableCreate                  │
  ├─ TableAddCol (repeat)         │
  ├─ TableAddRow (repeat)         │
  ├─ TableSetCell (repeat)        │
  ├─ TableRender ─────────────────►│ displays table
  │                               │
  ├─ TableScroll(+1)              │
  ├─ TableRender ─────────────────►│ scrolled view
  │                               │
  ├─ TableClear                   │
  │                               │
```

---

## Demo Programs

- **rip3server.pas** — Server-side demo: table creation, form definitions,
  variable binding, validation, BMP export
- **rip3client.pas** — Client-side demo: form input simulation, checkbox toggle,
  dropdown selection, focus cycling, variable sync

---

## Architecture Notes

- Engine uses {$H-} (short strings) to avoid BUG-029
- All I/O uses Assign/Reset/BlockRead (no TStream/Classes)
- Variable names up to 31 characters (TRIPVariable.Name: String[31])
- Maximum 64 form fields, 64 text variables, 256 table rows, 32 columns
- Font rendering priority: RFF > CHR > MAF > built-in bitmap
- Pixel format support: Indexed8 (EGA), RGB24, RGB32 (TrueColor)

---

## Phase 22: Audio (Server/Client Split)

### Server-Side
- AudioLoad/Play/Pause/Stop/StopAll/SetVolume/GetState — manage 4 stream slots
- MIDILoad/MIDIFree — load MIDI file reference for host to parse
- CueAdd/CueClear/CueProcess — timed event triggers at animation frames
- SetBgAudio/BgAudioTransition — background audio with crossfade
- WAVStreamStart/Feed/End — chunked audio streaming

### Client-Side
- Receives audio data and plays via wavplay.pas / dosplay.pas
- Ring buffer (ringbuf.pas) for streaming playback
- Volume control via pcmmix.pas AdjustVolume8/16
- Async playback via asyncplay.pas

---

## Phase 23: Graphics (Server-Side Only)

All Phase 23 features are server-side — they write directly to the
RGB24 pixel buffer. The client sees rendered pixels only.

- GradientRect — linear, radial, conical fills (grfill.pas)
- DropShadow / OuterGlow — effects with blur (grfx.pas)
- BezierVarWidth — variable-width cubic bezier (grbezier.pas)
- TextureQuad — UV-mapped texture on quad (grtexmap.pas)
- CompositAlpha — full-canvas alpha blend (grfx.pas)
- ClipBegin/End — polygon-based clipping paths (grclip.pas)
