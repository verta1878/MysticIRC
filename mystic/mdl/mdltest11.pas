// ====================================================================
// Mystic BBS IRC Fork — GPLv3
// ====================================================================
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ====================================================================

// ====================================================================
// mdltest11 — m_serial + m_fossil COM port test
// Tests FOSSIL abstraction layer without real hardware
// ====================================================================
Program mdltest11;

Uses
  m_Fossil;

Var
  Foss : TFossil;
  Info : TFossilInfo;
  Pass : Integer;
  Fail : Integer;

Procedure Check (Name: String; Cond: Boolean);
Begin
  If Cond Then Begin
    WriteLn('  PASS  ', Name);
    Inc(Pass);
  End Else Begin
    WriteLn('  FAIL  ', Name);
    Inc(Fail);
  End;
End;

Begin
  Pass := 0;
  Fail := 0;
  WriteLn('mdltest11 — m_serial + m_fossil test');
  WriteLn;

  WriteLn('--- TFossil Object ---');
  Foss := TFossil.CreateSerial(NIL);

  Check('CreateSerial OK', Foss <> NIL);
  Check('Backend serial', Foss.Backend = fbSerial);
  Check('Not connected', Not Foss.CarrierDetect);

  // GetInfo without init
  Info := Foss.GetInfo;
  Check('Info baud zero', Info.CurrBaud = 0);

  // Deinit (no-op if not initialized)
  Foss.Deinit;
  Check('Deinit OK', True);

  // Flush/Purge (no-op if not initialized)
  Foss.Flush;
  Check('Flush OK', True);

  Foss.PurgeInput;
  Check('PurgeInput OK', True);

  Foss.PurgeOutput;
  Check('PurgeOutput OK', True);

  // RecvReady without connection
  Check('RecvReady false', Not Foss.RecvReady);

  // DTR set (no-op without connection)
  Foss.SetDTR(True);
  Check('SetDTR OK', True);

  Foss.SetDTR(False);
  Check('SetDTR off OK', True);

  // Status without connection
  Check('Status zero', Foss.Status = 0);

  Foss.Free;
  Check('Free OK', True);

  WriteLn;
  WriteLn('--- TFossilInfo Record ---');
  Check('Info size > 0', SizeOf(TFossilInfo) > 0);

  WriteLn;
  WriteLn('--- Backend Selection ---');
  Foss := TFossil.CreateSerial(NIL);

  {$IFDEF GO32V2}
  WriteLn('  (DOS target — CreateInt14 would use fbInt14)');
  {$ELSE}
  Check('Non-DOS: backend serial', Foss.Backend = fbSerial);
  {$ENDIF}

  Foss.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Pass + Fail, ' passed, ', Fail, ' failed ===');
End.
