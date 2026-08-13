Unit mutil_packfilebases;

// ====================================================================
// MUTIL: Pack File Bases
// Checks file integrity, removes missing files
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uPackFileBases;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uPackFileBases;
Begin
  ProcessName   ('Pack File Bases', False);
  ProcessStatus ('Processing', False);

  { TODO: implement Pack File Bases logic }
  Log (1, '+', '  Pack File Bases - stub');

  ProcessStatus ('Done', False);
  ProcessResult (rDONE, False);
End;

End.
