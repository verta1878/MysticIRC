{$MODE DELPHI}
program mtrip_test;
{ mterm RIP engine smoke test — loads a RIP file and renders to BMP. }
uses SysUtils, mtrip, mtripgfx;

var
  Parser: TRIPParser;
  F: Text;
  Line: String;
  RipFile, BmpFile: String;
begin
  if ParamCount < 1 then begin
    WriteLn('Usage: mtrip_test <file.rip> [-o output.bmp]');
    Halt(1);
  end;

  RipFile := ParamStr(1);
  if ParamCount >= 3 then BmpFile := ParamStr(3)
  else BmpFile := ChangeFileExt(RipFile, '.bmp');

  if not FileExists(RipFile) then begin
    WriteLn('File not found: ', RipFile);
    Halt(1);
  end;

  WriteLn('mterm RIP Test');
  WriteLn('Loading: ', RipFile);

  Parser := TRIPParser.Create;
  try
    Parser.Reset;
    Parser.Canvas.Clear(0);

    Assign(F, RipFile);
    {$I-} System.Reset(F); {$I+}
    if IOResult <> 0 then begin
      WriteLn('Cannot open file');
      Halt(1);
    end;

    while not EOF(F) do begin
      ReadLn(F, Line);
      Parser.ProcessCommand(Line);
    end;
    Close(F);

    WriteLn('Parsed OK');
    WriteLn('Mouse fields: ', Parser.MouseFieldCount);

    Parser.Canvas.SaveBMP(BmpFile);
    WriteLn('Output: ', BmpFile);
  finally
    Parser.Free;
  end;
end.
