# Phase 3: Win32 Runtime Testing — Debug Audit

## Issue 1: New User Email Not Working

**Symptom:** New user signs up, sysop account exists, but no feedback email arrives.

**Trace:**
```
CreateNewUser → bbsCfg.NewUserEmail = True
  → FindUser(bbsCfg.FeedbackTo) → ???
  → Session.Menu.ExecuteCommand('MW', '/TO:... /SUBJ:New_User_Feedback /F')
```

**Root Causes (in order of likelihood):**

A. **FeedbackTo field empty in mystic.dat** — old data file, never set.
   Fix: `mystic -cfg` → Configuration → set "Feedback To" = sysop handle.

B. **FeedbackTo doesn't match any user Handle or RealName** — FindUser
   checks both but is case-insensitive. If FeedbackTo = "Sysop" but
   handle = "sysop/0", no match.
   Fix: FeedbackTo must exactly match Handle or RealName.

C. **strReplace spaces with underscores** — '/TO:Sysop_Name' becomes
   the recipient. PostMessage's FindUser might not match "Sysop_Name"
   against "Sysop Name".
   Fix: PostMessage should strReplace('_', ' ') before FindUser.

D. **MW command context** — PostMessage is called while the NEW user
   is logged in. Message goes FROM new user TO sysop. Should work
   but verify the message base is set up for email (base 0 / email).

**Debug:** Check node1.log for DEBUG NewUser lines after test.

**Files:** bbs_user.pas lines 1130-1150, bbs_msgbase.pas PostMessage

---

## Issue 2: ANSI Editor Draw Palette Disappears

**Symptom:** Open ANSI editor, press color palette key, palette appears
briefly then entire screen goes blank. Content is lost.

**Root Cause:**

DrawMenu (line 1510) uses WriteXY to draw the color picker at
rows 7-23, columns 14-59. But GetScreenImage only saves the Box
region (13,6 to 60,24). DrawMenu's WriteXY calls write OUTSIDE
the saved region (status bars, borders). When RemoteRestore runs,
it only restores the box region — everything else stays corrupted.

Additionally, the palette overlay calls DrawMenu INSIDE the
Repeat/Until loop (lines 1570-1690). Each color change calls
DrawMenu which redraws, but the screen save (Img) was done
ONCE at line 1559. If the underlying content changes between
saves (e.g., a character was drawn), Img is stale.

**Fix (no code changes yet):**

Option A: Save FULL screen (1,1 to 80,25) instead of just the box region.
  Change: GetScreenImage(13,6,60,24,Img) → GetScreenImage(1,1,80,25,Img)

Option B: After RemoteRestore, call ReDrawTemplate(True) which redraws
  everything including status bars, then DrawPage for content.

Option C: Don't use overlay — use a separate screen page or buffer.

**Recommended:** Option A (simplest, one line change).

**Files:** bbs_edit_ansi.pas lines 1510-1700

---

## Issue 3: Text Editor No Keyboard Input

**Symptom:** Open text editor (full screen editor), cursor appears,
but no keys register. Cannot type anything.

**Root Cause:**

The full screen editor (bbs_edit_full.pas line 619) calls
Session.io.GetKey which calls InKey(1000). On Windows, InKey uses
WaitForMultipleObjects or WaitForSingleObject depending on LocalMode.

**If LocalMode = False (remote session):**
  InKey waits on BOTH Keyboard.ConIn AND SocketEvent.
  If there's no valid socket (local test without telnet),
  SocketEvent handle is invalid → WaitForMultipleObjects may
  hang or return immediately with no input.

**If LocalMode = True:**
  InKey waits on Keyboard.ConIn only via WaitForSingleObject.
  This should work. If it doesn't, the console input handle
  (Keyboard.ConIn from GetStdHandle(STD_INPUT_HANDLE)) may
  be wrong or the process doesn't have a console.

**Debug Steps:**
1. Verify Session.LocalMode is True when testing locally
2. Add WriteLn debug in InKey to see if it enters the local path
3. Check if Keyboard.ConIn = GetStdHandle(STD_INPUT_HANDLE) returns valid handle
4. Test: does the CONFIG editor accept keyboard? If yes, GetKey works — 
   the issue is specific to the text editor's key handling

**Fix (no code changes yet):**
- If LocalMode issue: ensure -L flag or -CFG sets LocalMode before editor opens
- If ConIn issue: verify TInput.Create in bbs_ansi_console.pas
- If ProcessQueue issue: check if console mode has ENABLE_WINDOW_INPUT
  disabled (causes non-key events to flood the queue)

**Files:** bbs_edit_full.pas line 619, bbs_io.pas InKey line 1660

## Issue 3 Update: Text Editor Code is Identical to 1.12

bbs_edit_full.pas is identical between our 1.11IRC and 1.12 (Exit 0 on diff).
The keyboard issue is NOT a code bug — it's a runtime environment issue.

**Confirmed:** Console input uses GetStdHandle(STD_INPUT_HANDLE) with
SetConsoleMode(ConIn, 0) for raw input. This is correct.

**Most likely cause:** When running `mystic -L` (local mode), the
text editor should work. If running without -L, mystic thinks it's
a remote session and waits on a socket that doesn't exist.

**Test steps:**
1. Run `mystic -L` (force local mode)
2. Login, enter message area, write a message
3. Does the text editor accept keyboard input?
4. If YES → issue is that -L flag wasn't used
5. If NO → deeper console handle issue

**Searchlight menus:** ✅ Already complete. bbs_menus.pas identical to 1.12.

## Issue 2 Update: ANSI Editor Fix Applied

Changed GetScreenImage from (13,6,60,24) to (1,1,80,25) — saves the
full screen instead of just the dialog box region. This prevents content
outside the dialog from being destroyed and not restored.

1.12 has the same partial save bug but uses ReDrawTemplate(False) after
restore which clears and redraws everything — works but causes a flash.
Our fix (full screen save) is cleaner — no flash, no redraw needed.
