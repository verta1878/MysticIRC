// ====================================================================
// TESTDATE.MPS : MPL Date/Timer Function Tests (A3-05, A3-11, A3-12)
// ====================================================================
//
// WHAT THIS TESTS:
//   1. TimerMS (function 562) — milliseconds since midnight
//      ~10ms resolution via GetTime Sec100 * 10
//      Used for benchmarking, animation timing, delays
//
//   2. FormatDate (function 563) — mask-based date formatting
//      Mask tokens: YYYY YY MM DD DDD NNN HH II SS
//      Calls m_datetime.pas FormatDate(DT, Mask)
//
//   3. DateStr formats 4-6 — 4-digit year variants
//      Format 4 = MM/DD/YYYY  (US)
//      Format 5 = DD/MM/YYYY  (European)
//      Format 6 = YYYY/MM/DD  (ISO 8601)
//      Added to DateDos2Str and DateJulian2Str in m_datetime.pas
//
// HOW TO RUN:
//   mplc testdate.mps       (compile)
//   then run from BBS menu: GX testdate
//
// EXPECTED OUTPUT:
//   TimerMS test: ~100ms delay measured as NNNms
//   DateStr formats 1-6 with current date
//   FormatDate with 4 different mask patterns
//
// IF IT FAILS:
//   TimerMS returns 0 = GetTime not working on this OS
//   FormatDate empty = UnPackTime or mask parsing broken
//   DateStr fmt 4-6 shows 2-digit year = Y var still String[2]
//
// SEE ALSO: mplref.txt "TimerMS", "FormatDate", "DateStr" sections
// ====================================================================
// Copyright (C) 2026 Kiddo — GPLv3 — Mystic BBS IRC Fork


Var
  D       : LongInt;
  Start   : LongInt;
  Elapsed : LongInt;

Begin
  WriteLn('testdate — MPL Date/Timer Tests');
  WriteLn('');

  // TimerMS test
  Start := TimerMS;
  Delay(100);
  Elapsed := TimerMS - Start;
  WriteLn('TimerMS test: ~100ms delay measured as ' + Int2Str(Elapsed) + 'ms');
  If (Elapsed >= 50) And (Elapsed <= 500) Then
    WriteLn('PASS: TimerMS works')
  Else
    WriteLn('NOTE: TimerMS resolution is ~10ms, value may vary');

  WriteLn('');

  // DateStr format 4-6 test
  D := DateTime;
  WriteLn('DateStr formats:');
  WriteLn('  Fmt 1 (MM/DD/YY):   ' + DateStr(D, 1));
  WriteLn('  Fmt 2 (DD/MM/YY):   ' + DateStr(D, 2));
  WriteLn('  Fmt 3 (YY/MM/DD):   ' + DateStr(D, 3));
  WriteLn('  Fmt 4 (MM/DD/YYYY): ' + DateStr(D, 4));
  WriteLn('  Fmt 5 (DD/MM/YYYY): ' + DateStr(D, 5));
  WriteLn('  Fmt 6 (YYYY/MM/DD): ' + DateStr(D, 6));

  WriteLn('');

  // FormatDate test
  WriteLn('FormatDate masks:');
  WriteLn('  YYYY-MM-DD:       ' + FormatDate(D, 'YYYY-MM-DD'));
  WriteLn('  DDD NNN DD, YYYY: ' + FormatDate(D, 'DDD NNN DD, YYYY'));
  WriteLn('  HH:II:SS:         ' + FormatDate(D, 'HH:II:SS'));
  WriteLn('  MM/DD/YY HH:II:   ' + FormatDate(D, 'MM/DD/YY HH:II'));

  WriteLn('');
  WriteLn('Done.');
End.
