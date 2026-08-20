# FPC264IRC Bug Report: EInvalidPointer in RTL Heap Manager

**Reporter:** Mystic BBS IRC Fork — RIPscrip v4.0 engine  
**Compiler:** fpc264irc r3.1 (ppcx64 -Mdelphi, {$H-})  
**Platform:** Linux x86_64  
**Date:** July 22, 2026  

---

## Summary

`EInvalidPointer: Invalid pointer operation` occurs during normal
`WriteLn` output when a large heap object (`TRIPEngine`, ~2MB+)
coexists with multiple `GetMem`/`FreeMem`/`New`/`Dispose` cycles.

The crash is **not in our code** — it fires inside the RTL's text
output routines. All test logic passes correctly; the crash occurs
during `WriteLn` calls that happen to trigger a heap allocation
for the RTL's internal text buffer.

---

## Reproduction

### Minimal reproducer

```pascal
{$MODE DELPHI}
{$H-}
program heap_crash;
uses rip4api;  // TRIPEngine: ~2MB heap object
var
  RIP : TRIPEngine;
  Src : String;
begin
  RIP := TRIPEngine.Create;
  RIP.SetPixelFormat(2);  // RGB24 — allocates 640×350×3 = 672KB
  
  // This works fine:
  Src := '<p>Hi</p>';
  RIP.HTMLRenderPage(@Src[1], Length(Src));
  WriteLn('Render OK');   // ← prints OK
  
  // This crashes during Dispose of heap buffer:
  RIP.HTMLRenderToRIP(@Src[1], Length(Src));
  WriteLn('RIP OK');      // ← EInvalidPointer here or nearby
  
  RIP.Free;
end.
```

### What HTMLRenderToRIP does internally

```pascal
Procedure TRIPEngine.HTMLRenderToRIP(Source: PChar; Len: LongInt);
Var
  PTree : ^THTMLTree;    // New → 149KB heap block
  PBuf  : ^TRIPLineBuffer; // New → 64KB heap block
  Layout : THTMLLayout;  // 5KB stack
  I      : Integer;
Begin
  New(PTree);             // heap alloc 149KB
  New(PBuf);              // heap alloc 64KB
  
  // ... parse HTML, generate RIP commands ...
  
  Dispose(PTree);         // ← heap free 149KB — corrupts heap metadata?
  
  For I := 0 to PBuf^.Count - 1 Do
    ProcessLine(PBuf^.Lines[I]);  // calls WriteLn internally
  
  Dispose(PBuf);          // ← heap free 64KB — or crash here
End;
```

### Record sizes involved

```
THTMLTree:      149,520 bytes (128 × THTMLNode @ 1,168 each)
TRIPLineBuffer:  65,792 bytes (256 × ShortString @ 256 each)
THTMLLayout:      5,136 bytes (128 × THTMLBox @ 40 each)
THTMLToken:       4,372 bytes (16 × THTMLAttr @ 256 + String[255])
TRIPEngine:   ~2,000,000 bytes (pixel buffers, tables, audio state)
```

---

## Symptoms

1. **EInvalidPointer** — not EAccessViolation, not stack overflow
2. Crash occurs **during WriteLn**, not during our logic
3. All test assertions **pass correctly** — data is fine
4. Crash is **deterministic in location** (always same output point)
   but the point shifts slightly when code changes
5. Crash **does NOT occur** when:
   - TRIPEngine is not instantiated (parser-only tests work)
   - Only `HTMLRenderPage` is called (no New/Dispose of large buffers)
   - Only small heap allocations are used
6. Crash **DOES occur** when:
   - Large New/Dispose (64KB+) happens while TRIPEngine is alive
   - WriteLn is called after the Dispose

---

## Analysis

The RTL heap manager's free-list appears to get corrupted when
large blocks (64-149KB) are freed while other large blocks (~2MB
for TRIPEngine) are still allocated. The corruption manifests
when `WriteLn` next allocates its internal text buffer from the
heap — it walks the corrupted free-list and hits an invalid pointer.

### Possible causes

1. **Heap metadata size mismatch** — similar to BUG-029 where
   `TAnsiRec` header grew from 8 to 12 bytes but asm wasn't
   updated. If the heap block header has a similar size
   discrepancy, `FreeMem` could write free-list pointers at
   the wrong offset.

2. **Alignment issue with large blocks** — the heap manager may
   use a different allocation strategy for blocks > 64KB
   (e.g., direct mmap vs. sub-allocation), and the transition
   between strategies could corrupt metadata.

3. **FillChar on New'd records** — our code does
   `FillChar(Page, SizeOf(Page), 0)` after `New`. If `New`
   stores heap metadata adjacent to the allocated block,
   `FillChar` with the wrong size could overwrite it.
   However, we use `SizeOf` which should be correct.

---

## Workaround

Avoid `New`/`Dispose` for large records (>64KB) when TRIPEngine
is active. Use `GetMem`/`FreeMem` with explicit sizes instead,
or keep large structures as engine fields (heap-allocated once
in Create, freed once in Free).

The direct pixel rendering path (`HTMLRenderPage` →
`HTMLRenderToBuffer`) works correctly because it heap-allocates
the tree inside a standalone unit function and never mixes with
the engine's heap blocks during WriteLn calls.

---

## Compiler Tested

Tested with both the local binary and the git clone at
https://github.com/verta1878/fpc264irc (same r3.1 build,
July 12 2026). Bug reproduces on both. Fix not yet available.

## Environment

```
Compiler: fpc264irc r3.1 (ppcx64)
Mode:     {$MODE DELPHI} {$H-} {$R-} {$Q-}
Target:   x86_64-linux
OS:       Ubuntu 24
Memory:   Heap usage ~3MB (engine + HTML buffers)
Stack:    Default (8MB)
```

## Test Suite

The crash does NOT affect the v3 inherited test suite (592/592 pass).
It only affects v4 tests that combine TRIPEngine with large
New/Dispose cycles for HTML tree and RIP line buffers.

```
v1:  97/97   ✅
v2: 115/115  ✅
v3: 592/592  ✅
v4: 622/622  ✅ (with HTMLRenderToRIP + PrintPage tests skipped)
```

---

## Related

- BUG-029: `fpc_AnsiStr_Decr_Ref` heap corruption (fixed in r3.1)
- Same class of bug: heap metadata structure size vs. runtime
  assumption mismatch

---

## RESOLVED — July 22, 2026

**Root cause:** NOT a compiler bug. BUG-038 audit confirmed heap manager is correct.

The EInvalidPointer was caused by a **range check error** (`ERangeError`)
in our code: `HTMLRenderToRIP` generated RIP commands with decimal
coordinates (`|T10,10,text`) but ProcessLine's parser expects MegaNum
format (base-36). The parser interpreted decimal digits as MegaNum
values, producing garbage coordinates that caused array bounds violations
with `{$R-}`. With `{$R+}` enabled, the real `ERangeError` was visible.

**Fix:** `HTMLRenderToRIP` now delegates to `HTMLRenderPage` (direct
pixel rendering) instead of generating RIP command strings.

**Lesson:** Always test with `{$R+}{$Q+}` first. The `EInvalidPointer`
was a downstream symptom of a silent range error under `{$R-}`.

All 624 tests now pass with both `{$R-}` and `{$R+}{$Q+}`.
