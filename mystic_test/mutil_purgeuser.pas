Unit mutil_purgeuser;

// ====================================================================
// MUTIL: Purge User Base
// Marks inactive users for deletion
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uPurgeUserBase;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uPurgeUserBase;
Begin
  ProcessName   ('Purge User Base', False);
  ProcessStatus ('Processing', False);

  { TODO: implement Purge User Base logic }
  Log (1, '+', '  Purge User Base - stub');

  ProcessStatus ('Done', False);
  ProcessResult (rDONE, False);
End;

End.
