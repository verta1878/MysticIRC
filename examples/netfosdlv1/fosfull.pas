{ FOSFULL — exercises multiple FOSSIL functions through the resident driver }
program fosfull;
uses Dos, SysUtils;
var r: Registers;
procedure Call14(fn: byte; port: word);
begin
  r.AH := fn; r.DX := port;
  Intr($14, r);
end;
begin
  WriteLn('=== FOSSIL function test on COM1 ==='); Flush(Output);

  { Fn 04h — Init, expect AX=1954h }
  Call14($04, 0);
  WriteLn('Fn 04h Init:   AX=', IntToHex(r.AX,4), ' BL=', r.BL, ' BH=', r.BH);
  Flush(Output);

  { Fn 03h — Status request, AH bit expectations: AH has line status,
    AL has modem status. Just confirm it returns without hanging. }
  Call14($03, 0);
  WriteLn('Fn 03h Status: AH=', IntToHex(r.AH,2), ' AL=', IntToHex(r.AL,2));
  Flush(Output);

  { Fn 1Bh — Get driver info would need a buffer; skip, do Fn 00h baud }
  { Fn 00h — Set baud (AL bits 7-5 = rate). AL=$E3 = 9600,N,8,1 }
  r.AH := $00; r.AL := $E3; r.DX := 0;
  Intr($14, r);
  WriteLn('Fn 00h SetBaud: AX=', IntToHex(r.AX,4));
  Flush(Output);

  { Fn 05h — Deinit }
  Call14($05, 0);
  WriteLn('Fn 05h Deinit: done');
  Flush(Output);

  WriteLn('=== all functions returned cleanly ==='); Flush(Output);
end.
