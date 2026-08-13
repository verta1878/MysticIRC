Unit mutil_exportgolded;

// ====================================================================
// MUTIL: Export Golded Areas
// Exports config for GoldED editor
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uExportGolded;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uExportGolded;
Begin
  ProcessName   ('Export Golded Areas', False);
  ProcessStatus ('Processing', False);

  { TODO: implement Export Golded Areas logic }
  Log (1, '+', '  Export Golded Areas - stub');

  ProcessStatus ('Done', False);
  ProcessResult (rDONE, False);
End;

End.
