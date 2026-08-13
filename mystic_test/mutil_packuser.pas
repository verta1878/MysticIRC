Unit mutil_packuser;

// ====================================================================
// MUTIL: Pack User Base
// Removes deleted users and private messages
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uPackUserBase;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uPackUserBase;
Begin
  ProcessName   ('Pack User Base', False);
  ProcessStatus ('Processing', False);

  { TODO: implement Pack User Base logic }
  Log (1, '+', '  Pack User Base - stub');

  ProcessStatus ('Done', False);
  ProcessResult (rDONE, False);
End;

End.
