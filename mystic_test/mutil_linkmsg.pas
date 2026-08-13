Unit mutil_linkmsg;

// ====================================================================
// MUTIL: Link Messages
// Creates reply links in echomail bases
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uLinkMessages;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uLinkMessages;
Begin
  ProcessName   ('Link Messages', False);
  ProcessStatus ('Processing', False);

  { TODO: implement Link Messages logic }
  Log (1, '+', '  Link Messages - stub');

  ProcessStatus ('Done', False);
  ProcessResult (rDONE, False);
End;

End.
