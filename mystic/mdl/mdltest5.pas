{$MODE DELPHI}
{$H+}
Program mdltest5;
{$I records.pas}
const
  EXPECTED_SIZE = 5282;
begin
  Write('SizeOf(RecConfig) = ', SizeOf(RecConfig));
  if SizeOf(RecConfig) = EXPECTED_SIZE then
    WriteLn(' ... PASS')
  else begin
    WriteLn(' ... FAIL (expected ', EXPECTED_SIZE, ')');
    WriteLn('Drift: ', Integer(SizeOf(RecConfig)) - EXPECTED_SIZE, ' byte(s)');
    Halt(1);
  end;
end.
