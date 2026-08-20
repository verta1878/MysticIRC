# ANSI Editor Extraction Plan

## Goal
Extract TEditorANSI from Mystic's BBS layer into a standalone MDL
class that works WITHOUT BBS_Core, BBS_IO, or Session objects.

## Current Architecture

```
TEditorANSI (bbs_edit_ansi.pas, 2194 lines)
  └── TConfigEditor (bbs_cfg_editor.pas, 375 lines) — inherits
  └── TAnsiFileViewer (bbs_cfg_viewer.pas, 480 lines) — read-only viewer

Dependencies: m_FileIO, m_Types, m_Strings, BBS_Database,
  BBS_MsgBase_Ansi, BBS_Records, BBS_Core, BBS_IO, BBS_Common,
  BBS_Ansi_MenuBox, BBS_Ansi_MenuForm, DOS
```

## The Problem
TEditorANSI uses `Session` (TBBSCore) for:
- Screen I/O: `Session.io.OutRaw`, `Session.io.AnsiColor`
- Input: `Session.io.GetKey`, `Session.io.GetYN`
- User info: `Session.User.ThisUser.ScreenSize`
- Prompts: `Session.GetPrompt()`, `Session.io.PromptInfo[]`
- Screen info: `Session.io.ScreenInfo[]`

## Extraction Steps

### Step 1: Create TEditorIO interface
New unit: `m_editor_io.pas` in MDL.

```pascal
type
  TEditorIO = class
    procedure WriteXY(X, Y, Attr: Byte; S: String); virtual; abstract;
    procedure WriteChar(Ch: Char); virtual; abstract;
    procedure AnsiColor(Attr: Byte); virtual; abstract;
    procedure GotoXY(X, Y: Byte); virtual; abstract;
    procedure ClearScreen; virtual; abstract;
    procedure ClearEOL; virtual; abstract;
    function  GetKey: Char; virtual; abstract;
    function  GetYN(Prompt: String; Default: Boolean): Boolean; virtual; abstract;
    function  ScreenHeight: Byte; virtual; abstract;
    function  ScreenWidth: Byte; virtual; abstract;
  end;
```

### Step 2: Create two implementations

**TEditorIOConsole** — uses m_Input + m_Output directly (standalone):
```pascal
type
  TEditorIOConsole = class(TEditorIO)
    FInput: TInput;
    FOutput: TOutput;
    // implements all methods via direct console I/O
  end;
```

**TEditorIOSession** — wraps BBS_Core Session (Mystic):
```pascal
type
  TEditorIOSession = class(TEditorIO)
    FSession: Pointer; // TBBSCore
    // implements all methods via Session.io calls
  end;
```

### Step 3: Refactor TEditorANSI
Replace all `Session.io.xxx` calls with `FIO.xxx`:
```pascal
TEditorANSI = class
  FIO: TEditorIO;  // injected via constructor
  constructor Create(AIO: TEditorIO);
  ...
end;
```

### Step 4: Result
```
Standalone:
  TEditorIOConsole → TEditorANSI → works without BBS

Mystic -cfg:
  TEditorIOSession → TEditorANSI → works with Session

Both use the SAME TEditorANSI class — no code duplication.
```

## Reference
mystic_ansieditor2.pas (878 lines) is the standalone proof that
the editing logic CAN work without BBS_Core. It reimplements
TEditorANSI's features using m_Input/m_Output directly.
The extraction formalizes this into a proper class hierarchy.

## Files Included
- bbs_edit_ansi.pas — TEditorANSI (2194 lines, the core)
- bbs_cfg_editor.pas — TConfigEditor (375 lines, file editor subclass)
- bbs_cfg_viewer.pas — TAnsiFileViewer (480 lines, read-only viewer)
- mystic_ansieditor2.pas — standalone reference (878 lines)
- mystic_texteditor.pas — standalone text editor (387 lines)

## Rules
- Do NOT modify bbs_edit_ansi.pas directly
- Create NEW units (m_editor_io, m_editor_console, m_editor_session)
- Adapter pattern — same approach as MDL OOP migration
- Test: Mystic 15/15 still compiles after extraction
