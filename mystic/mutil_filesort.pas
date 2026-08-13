Unit mutil_filesort;

// ====================================================================
// MUTIL: File Sort
// Sorts file base listings by attribute
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uFileSort;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uFileSort;
Begin
  ProcessName   ('File Sort', False);
  ProcessStatus ('Processing', False);

  { TODO: implement File Sort logic }
  Log (1, '+', '  File Sort - stub');

  ProcessStatus ('Done', False);
  ProcessResult (rDONE, False);
End;

End.
