# ansiedit — Usage Guide

## Local Mode (current)

```bash
ansiedit                    # new blank canvas
ansiedit myart.ans          # edit existing file
ansiedit --nosauce myart.ans  # save without SAUCE record
```

## Keyboard Reference

| Key | Action |
|-----|--------|
| Arrow keys | Move cursor |
| Any char | Place character at cursor |
| F1 | Color palette |
| F2 | Character map (CP437) |
| F4 | Save file |
| F5 | Toggle draw mode (freehand) |
| F6 | Insert line |
| F7 | Delete line |
| F9 | Clear canvas |
| Tab | Cycle line draw style |
| Del | Erase character at cursor |
| Home/End | Jump to start/end of line |
| PgUp/PgDn | Jump to top/bottom |
| CTRL+Z | Undo
| CTRL+Y | Redo |
| ESC | Menu |

## Draw Mode (F5)

When draw mode is active, moving the cursor places characters.
The status bar shows `DRAW/Single` (or whichever line style).

### Line Draw Styles (Tab to cycle)

| Style | Characters |
|-------|-----------|
| Single | ┌─┐│└┘├┤┬┴┼ |
| Double | ╔═╗║╚╝╠╣╦╩╬ |
| Single/Double | ╓─╖║╙╜╟╢╥╨╫ |
| Double/Single | ╒═╕│╘╛╞╡╤╧╪ |
| Block1 | ████████████ (solid) |
| Block2 | ▀▄ (half blocks) |
| None | spaces |
| Dotted | ··········· |

Line draw auto-detects neighbors and picks the correct
corner, T-junction, or cross piece.

## Block Operations (ESC → Block Menu)

| Command | Description |
|---------|-------------|
| Select | Arrow keys to define block, ENTER to confirm |
| Fill | Fill block: Character/Attribute/Both/NewAttr |
| Copy | Copy block to clipboard |
| Paste | Paste clipboard at cursor |
| Center | Center text within block |
| Erase | Clear block to spaces |

## Fill Options

When filling a selected block:

| Key | Action |
|-----|--------|
| C | Fill with current character only |
| A | Fill with current attribute only |
| B | Fill with both character and attribute |
| N | Fill with a new attribute value |
| Q | Cancel |

## File Formats

| Format | Load | Save |
|--------|------|------|
| .ANS (ANSI) | ✅ | ✅ |
| .ASC (ASCII) | ✅ | ✅ |
| SAUCE metadata | ✅ | ✅ (use --nosauce to skip) |


## Teleconference Mode

| Key | Action |
|-----|--------|
| ALT+S | Server/Client setup dialog |
| ALT+C | Flip to chat page |
| / | Quick flip to chat (when connected) |
| ESC (in chat) | Return to canvas |

### Chat Commands (/help for full list)
| Command | Description |
|---------|-------------|
| /help | List all commands |
| /who | Show connected users |
| /nick <name> | Change display name |
| /kick <user> | Kick user (host only) |
| /save | Save canvas to file |
| /disconnect | Disconnect from session |
| /quit | Return to canvas |
