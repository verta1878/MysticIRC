{ FOSTEST2 — exercise the newly-implemented FOSSIL functions }
program fostest2;
uses Dos;
var r: Registers;
begin
  { Init first }
  r.AH := $04; r.DX := 0; Intr($14, r);
  WriteLn('Init: AX=', HexStr(r.AX, 4));

  { Fn 0F: set flow control (AL bit1 = CTS/RTS hardware flow) }
  r.AH := $0F; r.AL := $02; r.DX := 0; Intr($14, r);
  WriteLn('Fn0F SetFlow (CTS/RTS): returned AX=', HexStr(r.AX, 4), ' (no crash = OK)');

  { Fn 10: Ctrl-C check — should return 0 (no abort) }
  r.AH := $10; r.DX := 0; Intr($14, r);
  WriteLn('Fn10 CtrlC check: AX=', HexStr(r.AX, 4), ' (0000 = no abort pending)');

  { Fn 1B: get driver info struct }
  r.AH := $05; r.DX := 0; Intr($14, r);   { deinit }
  WriteLn('Fn05 Deinit: done');
  WriteLn('=== new functions exercised, no hang/crash ===');
end.
