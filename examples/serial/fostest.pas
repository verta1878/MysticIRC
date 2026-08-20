program fostest;
uses Dos, SysUtils;
var r: Registers;
begin
  WriteLn('FOSTEST start'); Flush(Output);
  WriteLn('  about to call INT 14h Fn 04h...'); Flush(Output);
  r.AH := $04; r.DX := $0000;
  Intr($14, r);
  WriteLn('  returned from INT 14h'); Flush(Output);
  WriteLn('  AX = ', IntToHex(r.AX, 4), 'h');
  if r.AX = $1954 then WriteLn('  => FOSSIL DETECTED')
  else WriteLn('  => no FOSSIL');
  Flush(Output);
  WriteLn('FOSTEST done.'); Flush(Output);
end.
