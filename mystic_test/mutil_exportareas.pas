Unit mutil_exportareas;

// ====================================================================
// MUTIL: Export AREAS.BBS
// Exports message base echo tags
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uExportAreasBBS;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uExportAreasBBS;
Begin
  ProcessName   ('Export AREAS.BBS', False);
  ProcessStatus ('Processing', False);

  { TODO: implement Export AREAS.BBS logic }
  Log (1, '+', '  Export AREAS.BBS - stub');

  ProcessStatus ('Done', False);
  ProcessResult (rDONE, False);
End;

End.
