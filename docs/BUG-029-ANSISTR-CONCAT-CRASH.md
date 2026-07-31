# BUG-029: fpc_ansistr_concat_multi Win32 Crash

## Symptom
EAccessViolation at $7775AAB6 (ntdll.dll) on MIS startup.
Recursive crash: fpc_ansistr_concat_multi → exception →
SYSTEM_INTERNALEXIT → WriteLn → exception → infinite loop
until stack overflow.

## Root Cause
HTTP header concatenation exceeded 255 bytes under {$H-}
(ShortString mode set by m_ops.pas {$LONGSTRINGS OFF}).
FPC promoted ShortString concatenation to AnsiString temporaries
via fpc_ansistr_concat_multi. On i386-win32, this corrupted
heap metadata → EAccessViolation → recursive crash.

## Application Fix
Changed Header variables in mis_client_http.pas from
`String` (ShortString, 255 max) to `AnsiString` (unlimited).
HTTP headers routinely exceed 255 bytes.

## Compiler Fix
fpc264irc maintainer investigating fpc_ansistr_concat_multi
heap corruption on Win32. The implicit ShortString→AnsiString
promotion should not crash regardless of string length.

## Affected Code
- mis_client_http.pas: SendResponse, SendFile
- Any {$H-} code that concatenates strings > 255 bytes

## Lesson
Under {$LONGSTRINGS OFF}, use explicit `AnsiString` for any
variable that might exceed 255 characters (HTTP headers, paths,
log messages, generated content).

## Status
Application fix: APPLIED
Compiler fix: IN PROGRESS (fpc264irc maintainer)
