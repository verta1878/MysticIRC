# Mystic BBS — Feature Analysis (111 → 112)

## 1. Searchlight-Style Prompt Menus

**What it is:** Lightbar menus where arrow keys navigate between menu
items displayed as highlighted prompts on screen. Originated in
Searchlight BBS. g00r00 calls it "LBPromptMenu" (LightBar Prompt Menu).

**How it works in source:**
- `bbs_menus.pas` → `TMenuEngine.DoLBPromptMenu`
- Items have X/Y coordinates, highlighted text, and hotkeys
- Arrow keys call `FindNextItem`/`FindPrevItem` (wraps around)
- `FindByKey` handles single-keypress hotkeys
- Each item has an Access Control String (ACS) — hidden if user lacks access
- Separate from `DoLightBarMenu` (the older static lightbar)

**Screen size handling:**
- `MaxLBSize` / `MaxDESize` control item widths
- Items positioned with `ItemX`/`ItemY` — supports custom layouts
- Works at any terminal width (not hardcoded to 80 columns)

**Status:** ⚠️ Present in 111a3. The rework g00r00 mentioned may involve
additional layout options or multi-column support in 112.

**Records involved:**
- `RecMenuPrompt` — display position, colors, hotkey
- `HotKey` field — single char or special ('EVERY', 'AFTER', 'FIRSTCMD', 'LINEFEED')
- `UseHotKeys` boolean per menu

## 2. Spell Check

**What it is:** Hunspell-based spell checking in the full-screen editor.

**How it works:**
- g00r00 ships `libhunspell32.dll` / `libhunspell64.dll`
- Dynamically loaded at runtime (same pattern as Python)
- `dictionary.dic` + `dictionary.aff` — standard Hunspell format
- `spellcheck.txt` — custom word list editable from config
- Editor highlights misspelled words with `spell_attr` / `spell_style`
- Config: `Edit Spellcheck Words` in System Configuration menu

**112 additions:**
- `mystic_spellcheck_v2.zip` bundled with release
- `THunSpell` class wrapping the DLL
- "Unable to open hunspell dictionary" error message in binary

**Source location:**
- Not in 111 source — added in 112 cycle
- Would need: `bbs_hunspell.pas` unit with `LoadLibrary` pattern
- Dictionary path: `bbsCfg.DataPath + 'spellcheck.txt'`

## 3. Crypto Libraries

**What it is:** `m_crypt.pas` in MDL — pure Pascal crypto for BBS authentication.

**API:**
```pascal
Function B64Encode(S: String): String;
Function B64Decode(S: String): String;
Function MD5(const Value: String): String;
Function HMAC_MD5(Text, Key: String): String;
Function Digest2String(Digest: String): String;
Function String2Digest(Str: String): String;
```

**Used for:**
- **CRAM-MD5** — BinkP (FidoNet) authentication (`bbs_cfg_echomail.pas`)
- **Password hashing** — 112 changed `RecUser.Password` from plain `String[15]` 
  to `UserPasswordRecord = Array[1..101] of Byte` (MD5 hash + salt)
- **Base64** — MIME encoding for email/NNTP
- **Digest conversion** — hex string ↔ binary digest

**MDL library:** `libpm_crypt.a` (48KB compiled)

**Note:** 112's password change from plaintext to hashed array is a
security upgrade. Old user databases need migration.

## 4. Configuration Log Viewer

**What it is:** `bbs_cfg_viewer.pas` — scrollable ANSI file viewer class.

**How it works:**
- `TAnsiFileViewer` class inherits nothing (standalone)
- Uses `TMsgBaseAnsi` for ANSI rendering
- Scrollable with arrow keys, PgUp/PgDn
- ESC popup menu, ^G Goto line, ^W Where (search)
- Read-only mode for log files
- Config menu: `L View Log Files`

**Source:** `bbs_cfg_viewer.pas` (our IRC fork addition)
- Reusable: Log Viewer (read-only), Text Editor (future), RIP Viewer (future)
- Based on `AnsiViewer` logic from `bbs_general.pas`
- Implemented as class for inheritance

## 5. ANSI Editor

**What it is:** Full-screen ANSI art editor built into Mystic's config.

**How it works:**
- `Configuration_AnsiEditor` in `bbs_cfg_main.pas`
- Creates `TEditorANSI` with `DrawMode := True`
- `TEditorANSI` is in `bbs_cfg_editor.pas`, inherits message editor
- `TConfigEditor = Class(TEditorANSI)` — overrides for config use
- Draw mode: character-at-a-time painting (like TheDraw/PabloDraw)
- Normal mode: line-based text editing
- 112 added: "Upload ANSI" option in draw mode menu

**Key fields:**
- `DrawMode: Boolean` — toggles between edit and draw
- `InsertMode: Boolean` — insert vs overwrite
- `MaxMsgCols: 79` — standard BBS width
- Saves/restores console image (`TConsoleImageRec`)

## Summary Table

| Feature | Unit | Lines | Status |
|---------|------|-------|--------|
| Searchlight menus | bbs_menus.pas | ~200 | ✅ in 111, rework TBD |
| Spell check | (not in 111 src) | ~150 est | ❌ needs Hunspell binding |
| Crypto (MD5/B64) | m_crypt.pas (MDL) | ~300 | ✅ compiled in MDL |
| Log viewer | bbs_cfg_viewer.pas | ~200 | ✅ our addition |
| ANSI editor | bbs_cfg_editor.pas | ~400 | ✅ draw mode works |
