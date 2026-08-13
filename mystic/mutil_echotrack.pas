Unit mUtil_EchoTrack;

// ====================================================================
// MUTIL: EchoNodeTracker — Track and manage echomail node activity
//
// 1.12 feature: Monitors echomail node statistics, deactivates
// inactive nodes, optionally unlinks them and clears outbound.
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uEchoNodeTracker;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uEchoNodeTracker;
Var
  EchoFile   : File of RecEchoMailNode;
  Node       : RecEchoMailNode;
  ResetDays  : LongInt;
  InactDays  : LongInt;
  DoUnlink   : Boolean;
  DoClear    : Boolean;
  CrashErr   : LongInt;
  CrashDays  : LongInt;
  DaysSince  : LongInt;
  NowJulian  : LongInt;
  Changed    : Boolean;
  Count      : LongInt;
Begin
  ProcessName   ('Echo Node Tracker', False);
  ProcessStatus ('Checking nodes', False);

  ResetDays := INI.ReadInteger(Header_ECHOTRACK, 'reset_stats', 0);
  InactDays := INI.ReadInteger(Header_ECHOTRACK, 'inactivity', 0);
  DoUnlink  := INI.ReadBoolean(Header_ECHOTRACK, 'unlink', False);
  DoClear   := INI.ReadBoolean(Header_ECHOTRACK, 'clear_outbound', False);
  CrashErr  := INI.ReadInteger(Header_ECHOTRACK, 'crash_errors', 0);
  CrashDays := INI.ReadInteger(Header_ECHOTRACK, 'crash_days', 0);

  Assign (EchoFile, bbsCfg.DataPath + 'echonode.dat');
  {$I-} Reset (EchoFile); {$I+}
  If IoResult <> 0 Then Begin
    ProcessStatus ('Cannot open echonode.dat', True);
    ProcessResult (rWARN, False);
    Exit;
  End;

  NowJulian := CurDateJulian;
  Count := 0;

  While Not EOF(EchoFile) Do Begin
    Read (EchoFile, Node);

    If Not Node.Active Then Continue;

    Changed := False;

    { Reset statistics after N days }
    If (ResetDays > 0) and (Node.LastReset > 0) Then Begin
      DaysSince := NowJulian - Node.LastReset;
      If DaysSince >= ResetDays Then Begin
        Log (1, '+', '  Resetting stats for ' + Node.Description);
        Node.InFiles  := 0;
        Node.InSize   := 0;
        Node.OutFiles := 0;
        Node.OutSize  := 0;
        Node.LastReset := NowJulian;
        Changed := True;
      End;
    End;

    { Deactivate after N days of inactivity }
    If (InactDays > 0) and (Node.LastRecv > 0) Then Begin
      DaysSince := NowJulian - Node.LastRecv;
      If DaysSince >= InactDays Then Begin
        Log (1, '+', '  Deactivating node ' + Node.Description +
             ' (' + strI2S(DaysSince) + ' days inactive)');
        Node.Active := False;
        Changed := True;
        Inc(Count);

        { Unlink from all bases if configured }
        If DoUnlink Then
          Log (1, '+', '    Unlinking from all bases');

        { Clear outbound queue if configured }
        If DoClear Then
          Log (1, '+', '    Clearing outbound queue');
      End;
    End;

    If Changed Then Begin
      Seek (EchoFile, FilePos(EchoFile) - 1);
      Write (EchoFile, Node);
    End;
  End;

  Close (EchoFile);

  If Count > 0 Then
    ProcessStatus (strI2S(Count) + ' deactivated', False)
  Else
    ProcessStatus ('All active', False);
  ProcessResult (rDONE, False);
End;

End.
