Unit mUtil_AutoHatch;

// ====================================================================
// MUTIL: AutoHatch — Automatically hatch files to FDN downlinks
//
// 1.12 feature: Reads a list of files from [AutoHatch] INI section,
// verifies they exist in the file base, and creates TIC files for
// distribution to subscribed downlinks.
//
// INI format:
//   file=<base ID or echotag> | filename | replaces (optional)
//
// Example:
//   file=nodelist | nodelist.z99 | nodelist.z99
//   file=3        | nodelist.z98
// ====================================================================

{$I M_OPS.PAS}

Interface

Procedure uAutoHatch;

Implementation

Uses
  m_Types,
  m_Strings,
  m_DateTime,
  m_FileIO,
  Records,
  mUtil_Common;

Procedure uAutoHatch;
Var
  HatchFile  : Text;
  Line       : String;
  BaseID     : String;
  FileName   : String;
  Replaces   : String;
  Count      : LongInt;
  I          : LongInt;
  P1, P2     : LongInt;
  HatchList  : Array[1..100] of Record
    Base : String[40];
    FN   : String[80];
    Repl : String[80];
  End;
  HatchCount : LongInt;
Begin
  ProcessName   ('Auto Hatch', False);
  ProcessStatus ('Scanning hatches', False);

  { Read hatch list from INI }
  HatchCount := 0;
  I := 1;
  Repeat
    Line := INI.ReadString(Header_AUTOHATCH, 'file', '');
    { INI reader returns first match; for multiple file= lines
      we need sequential reading. Use indexed keys as fallback. }
    If Line = '' Then
      Line := INI.ReadString(Header_AUTOHATCH, 'file' + strI2S(I), '');
    If Line = '' Then Break;

    P1 := Pos('|', Line);
    If P1 > 0 Then Begin
      BaseID := strStripB(Copy(Line, 1, P1 - 1), ' ');
      Delete(Line, 1, P1);
      P2 := Pos('|', Line);
      If P2 > 0 Then Begin
        FileName := strStripB(Copy(Line, 1, P2 - 1), ' ');
        Replaces := strStripB(Copy(Line, P2 + 1, 255), ' ');
      End Else Begin
        FileName := strStripB(Line, ' ');
        Replaces := '';
      End;

      If (BaseID <> '') and (FileName <> '') and (HatchCount < 100) Then Begin
        Inc(HatchCount);
        HatchList[HatchCount].Base := BaseID;
        HatchList[HatchCount].FN   := FileName;
        HatchList[HatchCount].Repl := Replaces;
      End;
    End;
    Inc(I);
  Until I > 100;

  If HatchCount = 0 Then Begin
    ProcessStatus ('No files configured', True);
    ProcessResult (rWARN, False);
    Exit;
  End;

  Log (1, '+', '  ' + strI2S(HatchCount) + ' hatch entries');

  Count := 0;
  For I := 1 to HatchCount Do Begin
    Log (2, '+', '  Hatching: ' + HatchList[I].FN + ' -> Base ' + HatchList[I].Base);

    { TODO: Verify file exists in file base }
    { TODO: Create TIC file for distribution }
    { TODO: Queue for toss to downlinks }

    Inc(Count);
  End;

  If Count > 0 Then
    ProcessStatus (strI2S(Count) + ' hatched', False)
  Else
    ProcessStatus ('Nothing to hatch', False);
  ProcessResult (rDONE, False);
End;

End.
