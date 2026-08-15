# ansiedit — Mystic ANSI Art Editor

## Status
ANSIEDIT-1 (Core Canvas) — in progress.

## Source Files
- bbs_edit_ansi.pas (2,194 lines) — full ANSI editor from BBS (has 148 BBS deps)
- mystic_ansieditor2.pas (878 lines) — standalone v2 editor (undo, block ops)
- bbs_cfg_editor.pas (327 lines) — config file editor
- bbs_cfg_viewer.pas (420 lines) — file viewer class
- mystic_texteditor.pas (209 lines) — text editor base

## 1.12 Editor Features (from binary audit)

### Drawing Modes
- Freehand character drawing
- Line draw: Single, Double, Single/Double, Double/Single, Block1, Block2, None, Dotted
- Fill: Character, Attribute, Both, New Attribute
- Block operations: Copy/Move, Fill, ceNter
- Insert/Delete/Copy/Move/Paste lines
- Tab character cycling

### File Operations
- Load/Save ANSI (.ans)
- /NOSAUCE flag — save without SAUCE record
- SAUCE: Author, Group, Title, Comments
- Upload ANSI from user

### UI
- FG/BG character display
- Fill character prompt
- Block selection with arrow keys (ENTER=done, ESCAPE=abort)
- Undo support ("No undo data for prompt")
- CTRL-E from menu editor to launch ANSI editor
- CTRL-U/Update, ESC/Abort

### Line Draw Character Sets (from binary)
```
Single:       ┌─┐│└┘├┤┬┴┼
Double:       ╔═╗║╚╝╠╣╦╩╬
Single/Dbl:   ╓─╖║╙╜╟╢╥╨╫
Double/Sgl:   ╒═╕│╘╛╞╡╤╧╪
Block1:       ░▒▓█
Block2:       ▀▄
Dotted:       ·
None:         (spaces)
```

## Build Plan

### ANSIEDIT-1: Core Canvas
- 80x25+ screen buffer (char + attr per cell)
- CP437 character set (256 chars)
- 16-color EGA attributes (FG 0-15, BG 0-7)
- Cursor movement (arrows, home, end, pgup, pgdn)
- Character insertion at cursor
- Attribute (FG/BG color) state

### ANSIEDIT-2: Drawing Tools
- Line draw mode (8 character sets)
- Fill tool (char/attr/both)
- Freehand drawing
- Tab character cycling

### ANSIEDIT-3: Block Operations
- Select block (arrow keys + ENTER)
- Copy, Move, Fill, Center
- Insert/Delete line

### ANSIEDIT-4: Undo System
- Multi-level undo/redo stack

### ANSIEDIT-5: File I/O
- Load/Save .ANS with SAUCE
- /NOSAUCE option
- SAUCE fields: Author, Group, Title, Comments

### ANSIEDIT-6: UI Chrome
- Status bar (position, color, mode)
- FG/BG color picker
- Character set display
- Tool palette
