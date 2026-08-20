# FPC 2.6.4irc Bug Report: AnsiString Stack Overflow in -Mdelphi Mode

## Date: July 19, 2026
## Reported by: Mystic BBS IRC Fork project
## Compiler: FPC 2.6.4irc r3.1+ (github.com/verta1878/fpc264irc)

## Summary

Repeated function calls that use AnsiString parameters, return values,
or local variables cause stack overflow (Runtime Error 216) in
-Mdelphi mode. The compiler generates reference counting and
finalization code for temporary AnsiStrings that appears to leak
stack frames, eventually exhausting the stack.

## Reproduction

Compile with: ppc386 -Mdelphi

```pascal
Unit TestUnit;
Interface

Type
  TMyClass = Class
    Function ExpandVars (S: String) : String;
    Procedure OutText (S: String);
  End;

Implementation

Function TMyClass.ExpandVars (S: String) : String;
Begin
  Result := S;  // simple passthrough
End;

Procedure TMyClass.OutText (S: String);
Begin
  S := ExpandVars(S);
End;

End.
```

Test program:
```pascal
Program TestCrash;
Uses TestUnit;
Var Obj : TMyClass;
    I   : Integer;
Begin
  Obj := TMyClass.Create;
  For I := 1 to 100 Do
    Obj.OutText('Hello');  // crashes around iteration 3-5
  Obj.Free;
End.
```

## Expected Behavior

100 iterations should complete without error. ExpandVars simply
returns its input unchanged. No heap allocation should persist
between calls.

## Actual Behavior

Runtime Error 216 (Access Violation / SIGSEGV) on the 3rd to 5th
call to OutText. Stack trace shows crash inside AnsiString
finalization/reference counting code.

## Analysis

In -Mdelphi mode, FPC 2.6.4irc defaults to {$H+}, making String
an alias for AnsiString. Each function call that passes or returns
an AnsiString generates compiler-inserted reference counting code
(incref on entry, decref on exit, finalization of temporaries).

The bug is in temporary string management: when OutText calls
ExpandVars, the return value creates a temporary AnsiString. The
assignment S := ExpandVars(S) should release the old value and
adopt the new one, but the stack frame used for the temporary is
not properly reclaimed.

After 3-5 iterations, the accumulated unreleased stack frames
overflow the default stack.

## Workarounds

1. Add {$H-} to force ShortStrings. Simplest fix, eliminates
   the problem entirely. ShortStrings use fixed 256-byte stack
   allocation with no reference counting.

2. Avoid String return values in hot paths. Use Var parameters:
   Procedure ExpandVars (S: String; Var Result: String);

3. Increase stack size with -Cs (delays crash, does not fix leak).

## Environment

- Compiler: ppc386 from FPC 2.6.4irc r3.1+
- Target: i386-linux
- Mode: -Mdelphi (implies {$H+})
- Stack size: default
- Does NOT occur with {$H-} (ShortStrings)
- Does NOT occur without the function call chain

## Impact

Any code that repeatedly calls methods with AnsiString parameters
and return values will eventually crash. Affects text rendering
loops, string processing in parsers, and any method called in a
tight loop that uses String types.

## Fix Applied

Added {$H-} at top of mystic_rip2/ripscript.pas.
Commit: 83848f5
