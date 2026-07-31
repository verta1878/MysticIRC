{$MODE DELPHI}
{$H-}
Program TestPhase3;
{
  Phase 3 -Pixel-Perfect Verification
  
  Renders all .rip files in rips/ directory using the current engine,
  saves BMPs to test-output/ directory.
  
  Compile twice -once with each engine -compare BMPs with ImageMagick:
  
    Engine A (ripdraw -proven):
      fpc -Mdelphi -Fusource -Fusource/v1 -dBMP_8BIT test_phase3.pas -ot_ripdraw
      ./t_ripdraw
  
    Engine B (m_rip_graph -experimental):
      fpc -Mdelphi -Fusource -Fusource/v1 -dEXPERIMENTAL_RIP -dBMP_8BIT test_phase3.pas -ot_mrgraph
      ./t_mrgraph
  
    Compare:
      for f in test-output-ripdraw/*.bmp; do
        b=$(basename "$f");
        bmpcompare "$f" "test-output-mrgraph/$b" /dev/null 2>&1;
      done
  
  Copyright (C) 2026 -GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Uses
  SysUtils, DOS,
  {$IFDEF EXPERIMENTAL_RIP}
  m_rip_graph,
  {$ELSE}
  RIPEngine, RIPDraw, RIPText, RIPBMP,
  {$ENDIF}
  RIP1Parse, RIP1Exec;

Const
  RipDir = 'rips';
  {$IFDEF EXPERIMENTAL_RIP}
  OutDir = 'test-output-mrgraph';
  Engine = 'B (m_rip_graph -kiddo)';
  {$ELSE}
  OutDir = 'test-output-ripdraw';
  Engine = 'A (ripdraw -evga)';
  {$ENDIF}

Var
  SR       : SearchRec;
  F        : Text;
  Line     : String;
  InFile   : String;
  OutFile  : String;
  BaseName : String;
  Total    : Integer;
  Lines    : Integer;
  Cmds     : Integer;
  {$IFDEF EXPERIMENTAL_RIP}
  G        : TRIPGraphics;
  {$ENDIF}

Procedure RenderOneFile(const FileName, BMPName: String);
Begin
  {$IFDEF EXPERIMENTAL_RIP}
  G := TRIPGraphics.Create(640, 350, rbBuffer);
  {$ELSE}
  InitCanvas;
  {$ENDIF}

  Assign(F, FileName);
  {$I-} Reset(F); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('  ERROR: Cannot open ', FileName);
    Exit;
  End;

  Lines := 0;
  Cmds := 0;

  While Not EOF(F) Do Begin
    ReadLn(F, Line);
    Inc(Lines);
    If Pos('!|', Line) > 0 Then Begin
      ExecuteRIP(Line);
      Inc(Cmds);
    End;
  End;
  Close(F);

  {$IFDEF EXPERIMENTAL_RIP}
  G.SaveBMP(BMPName);
  G.Free;
  {$ELSE}
  WriteBMP(BMPName);
  {$ENDIF}

  WriteLn('  OK  ', ExtractFileName(FileName),
          ' (', Lines, ' lines, ', Cmds, ' cmds) -> ', BMPName);
End;

Begin
  WriteLn('========================================');
  WriteLn(' Phase 3: Pixel-Perfect Verification');
  WriteLn(' Engine: ', Engine);
  WriteLn('========================================');
  WriteLn;

  { Create output directory }
  {$I-} MkDir(OutDir); {$I+}
  If IOResult <> 0 Then ; { ignore if exists }

  Total := 0;

  { Process all .rip files }
  If FindFirst(RipDir + DirectorySeparator + '*.rip', faAnyFile, SR) = 0 Then Begin
    Repeat
      BaseName := Copy(SR.Name, 1, Length(SR.Name) - 4);
      InFile := RipDir + DirectorySeparator + SR.Name;
      OutFile := OutDir + DirectorySeparator + BaseName + '.bmp';
      RenderOneFile(InFile, OutFile);
      Inc(Total);
    Until FindNext(SR) <> 0;
    FindClose(SR);
  End;

  { Also try .RIP (uppercase) }
  If FindFirst(RipDir + DirectorySeparator + '*.RIP', faAnyFile, SR) = 0 Then Begin
    Repeat
      BaseName := Copy(SR.Name, 1, Length(SR.Name) - 4);
      InFile := RipDir + DirectorySeparator + SR.Name;
      OutFile := OutDir + DirectorySeparator + BaseName + '.bmp';
      RenderOneFile(InFile, OutFile);
      Inc(Total);
    Until FindNext(SR) <> 0;
    FindClose(SR);
  End;

  WriteLn;
  WriteLn('Rendered: ', Total, ' files to ', OutDir, '/');
  WriteLn;
  WriteLn('Next: compile with the other engine and compare BMPs:');
  WriteLn('  bmpcompare test-output-ripdraw/FILE.bmp test-output-mrgraph/FILE.bmp');
End.
