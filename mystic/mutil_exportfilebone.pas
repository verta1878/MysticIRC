Unit mutil_exportfilebone;

// ====================================================================
// MUTIL: Export FILEBONE.NA
// Exports file base echo tags
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uExportFileBone;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uExportFileBone;
Begin
  ProcessName   ('Export FILEBONE.NA', False);
  ProcessStatus ('Processing', False);

  { TODO: implement Export FILEBONE.NA logic }
  Log (1, '+', '  Export FILEBONE.NA - stub');

  ProcessStatus ('Done', False);
  ProcessResult (rDONE, False);
End;

End.
