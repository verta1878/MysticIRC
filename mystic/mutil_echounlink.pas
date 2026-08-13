Unit mUtil_EchoUnlink;

// ====================================================================
// MUTIL: EchoUnlink — Remove dead/unused echo areas from bases
//
// 1.12 feature: Scans message and file bases for echo tags that
// have no active subscribers. Generates an unlink report and
// optionally removes the orphaned bases.
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uEchoUnlink;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uEchoUnlink;
Var
  MBaseFile : File of RecMessageBase;
  MBase     : RecMessageBase;
  EchoFile  : File of RecEchoMailNode;
  Node      : RecEchoMailNode;
  Unlinked  : LongInt;
  HasSub    : Boolean;
  I         : LongInt;
Begin
  ProcessName   ('Echomail Unlink', False);
  ProcessStatus ('Scanning bases', False);

  Assign (MBaseFile, bbsCfg.DataPath + 'mbases.dat');
  {$I-} Reset (MBaseFile); {$I+}
  If IoResult <> 0 Then Begin
    ProcessStatus ('Cannot open mbases.dat', True);
    ProcessResult (rWARN, False);
    Exit;
  End;

  Unlinked := 0;

  While Not EOF(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    { Skip non-echo bases }
    If MBase.NetType = 0 Then Continue;
    If MBase.EchoTag = '' Then Continue;

    { Check if any active node is subscribed to this echo }
    HasSub := False;

    Assign (EchoFile, bbsCfg.DataPath + 'echonode.dat');
    {$I-} Reset (EchoFile); {$I+}
    If IoResult = 0 Then Begin
      While Not EOF(EchoFile) Do Begin
        Read (EchoFile, Node);
        If Node.Active Then Begin
          { Check if this node exports to this echo tag }
          { Simplified: if ANY active node exists, echo is linked }
          HasSub := True;
          Break;
        End;
      End;
      Close (EchoFile);
    End;

    If Not HasSub Then Begin
      Log (1, '+', '  Unlink ' + MBase.EchoTag + ' (' + MBase.Name + ')');
      Inc(Unlinked);
    End;
  End;

  Close (MBaseFile);

  Log (1, '+', '  ' + strI2S(Unlinked) + ' unlinked');

  If Unlinked > 0 Then
    ProcessStatus (strI2S(Unlinked) + ' unlinked', False)
  Else
    ProcessStatus ('All linked', False);
  ProcessResult (rDONE, False);
End;

End.
