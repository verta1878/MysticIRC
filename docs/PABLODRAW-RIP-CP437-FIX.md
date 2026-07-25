# PabloDraw RIP CP437 Crash Fix

## Date: July 24, 2026
## Author: Kiddo — GPLv3 — Mystic BBS IRC Fork
## PabloDraw Version: 3.3.14.0 (WinForms)

---

## The Bug

PabloDraw crashes with `ArgumentException` when loading RIP files
that contain CP437 bytes 128-255 in `!|@` (OutTextXY) text commands.

### Stack Trace

```
System.ArgumentException: Argument_EncodingConversionOverflowChars, 65
  at System.Text.Encoding.ThrowCharsOverflow(DecoderNLS decoder, Boolean
  at System.Text.Encoding.GetCharsWithFallback(ReadOnlySpan`1 bytes, Int32
  at System.Text.UTF8Encoding.GetCharsWithFallback(ReadOnlySpan`1 bytes, I
  at System.Text.Encoding.GetCharsWithFallback(Byte* pOriginalBytes, Int32 ori
  at System.Text.Encoding.GetChars(Byte* pBytes, Int32 byteCount, Char* pCha
  at System.Text.Decoder.GetChars(ReadOnlySpan`1 bytes, Span`1 chars, Boolea
  at System.IO.BinaryReader.Read()
  at System.IO.BinaryReader.PeekChar()
  at Pablo.Formats.Rip.RipExtensions.ReadRipString(BinaryReader reader)
  at Pablo.Formats.Rip.Commands.OutTextXY.Read(BinaryReader reader)
  at Pablo.Formats.Rip.FormatRip.Load(Stream stream, RipDocument documen
```

### Root Cause

`BinaryReader` is created with **default UTF-8 encoding**:

```csharp
// FormatRip.cs line 42 — THE BUG
var reader = new BinaryReader (stream);  // defaults to UTF-8!
```

When `PeekChar()` encounters a CP437 byte like 0xDD (▌), the UTF-8
decoder expects a continuation byte but finds something else, causing
`ArgumentException: Argument_EncodingConversionOverflowChars`.

**Irony:** PabloDraw ALREADY HAS CP437 encoding defined:

```csharp
// FormatRip.cs line 14 — THIS EXISTS BUT ISN'T USED
public static Encoding Encoding = Encoding.GetEncoding (437);
```

The encoding was defined for `ReadRipString()` to convert bytes to
strings, but was never passed to the `BinaryReader` constructor.

---

## The Fix

### 3 files changed, 62-line patch

### File 1: `Source/Pablo/Formats/Rip/FormatRip.cs`

```csharp
// Line 42
// OLD:
var reader = new BinaryReader (stream);
// NEW:
var reader = new BinaryReader (stream, Encoding);
```

Pass the existing CP437 encoding to BinaryReader so `PeekChar()`
decodes bytes correctly instead of using UTF-8.

### File 2: `Source/Pablo/Formats/Rip/LidgrenExtensions.cs`

```csharp
// Line 35
// OLD:
var reader = new BinaryReader (stream);
// NEW:
var reader = new BinaryReader (stream, FormatRip.Encoding);
```

Same fix for the network/multiplayer RIP reader.

### File 3: `Source/Pablo/Formats/Rip/RipExtensions.cs`

Added `try-catch` around `PeekChar()` calls in `ReadRipString()`
as a safety net for any remaining edge cases:

```csharp
// OLD:
var next = reader.PeekChar ();

// NEW:
int next;
try {
    next = reader.PeekChar ();
} catch {
    break; // encoding error — stop reading
}
```

Also added `b != -1` check before casting in the CR/LF skip loop
to prevent issues at end-of-stream.

---

## How to Apply

### Using the patch file:

```bash
cd pablodraw/
git apply pablodraw-rip-cp437-fix.patch
```

### Or manually edit the 3 files as described above.

### Rebuild:

PabloDraw uses .NET / Eto.Forms. Build with:
```bash
dotnet build Source/Pablo.sln
```

---

## Testing

### Before fix:
```
chg2rip input.ans output.rip          ← RIP with CP437 bytes 128-255
PabloDraw → Open → output.rip        ← CRASH: ArgumentException
```

### After fix:
```
chg2rip input.ans output.rip          ← same RIP file
PabloDraw → Open → output.rip        ← loads and renders correctly
```

### Test files:
- `sd-fluph-ripterm.rip` — 44KB, 2,804 commands, CP437 text (will crash without fix)
- `sd-fluph-pd.rip` — 1.3MB, 113K bars, ASCII only (works without fix but slow)
- `test-simple.rip` — 572 bytes, basic shapes+text (works without fix)

---

## Why CP437 Bytes in RIP Text

RIPscrip was designed for DOS BBS systems that use CP437 encoding.
The `!|@` (OutTextXY) command can contain any CP437 byte as text.
Characters like ░▒▓█▄▌▐▀ (bytes 176-223) are commonly used in
ANSI art and are valid in RIP text commands.

Carl Gorringe's RIPtermJS handles these correctly using
`x-user-defined` encoding with `& 0xFF` masking.

Our chg2rip converter uses `!|@` text commands with CP437 bytes
to achieve 31x file size reduction (1.3MB → 44KB) compared to
pixel-level bar commands.

---

## Affected PabloDraw Commands

Any RIP command that calls `ReadRipString()`:
- `!|@` OutTextXY — most common, draws text at position
- `!|T` OutText — draws text at cursor
- Button text — button labels
- `!|1I` LoadIcon — icon filename

All of these will crash if the string contains bytes 128-255
without the CP437 encoding fix.

---

## Patch File

`pablodraw-rip-cp437-fix.patch` — 62 lines, apply with `git apply`

---

*Kiddo — Copyright (C) 2026 — GPLv3 — Mystic BBS IRC Fork*
*Bug found while developing chg2rip ANSI-to-RIPscrip converter*
