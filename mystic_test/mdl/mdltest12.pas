// ====================================================================
// Mystic BBS IRC Fork — GPLv3
// ====================================================================
//
// mdltest12 — m_door unit test
// Tests drop file reader (PCBOARD.SYS, DOOR.SYS, DORINFO1.DEF)
//
// Usage: mdltest12 [path_to_drop_files]
//        Creates test drop files, reads them back, verifies fields.
//
// Credits: verta1878, sysop/0, evga, kiddo, wrench, hexadecimal
// ====================================================================
{$MODE DELPHI}
{$H+}
Program mdltest12;

Uses SysUtils, m_door;

Var
  Info    : TDropInfo;
  F       : Text;
  TestDir : String;
  Pass, Fail : Integer;

Procedure Check(Name: String; Got, Expected: String);
Begin
  If Got = Expected Then Begin
    WriteLn('  PASS: ', Name, ' = "', Got, '"');
    Inc(Pass);
  End Else Begin
    WriteLn('  FAIL: ', Name, ' got "', Got, '" expected "', Expected, '"');
    Inc(Fail);
  End;
End;

Procedure CheckInt(Name: String; Got, Expected: Integer);
Begin
  Check(Name, IntToStr(Got), IntToStr(Expected));
End;

Procedure CheckBool(Name: String; Got, Expected: Boolean);
Begin
  If Got = Expected Then Begin
    WriteLn('  PASS: ', Name);
    Inc(Pass);
  End Else Begin
    WriteLn('  FAIL: ', Name, ' got ', Got, ' expected ', Expected);
    Inc(Fail);
  End;
End;

Procedure CreateTestPCBoardSys;
Begin
  Assign(F, TestDir + 'PCBOARD.SYS');
  Rewrite(F);
  WriteLn(F, 'C:\PCB');            // 1: display
  WriteLn(F, 'Test Sysop');        // 2: sysop
  WriteLn(F, '-1');                // 3: -1
  WriteLn(F, 'John Doe');          // 4: caller
  WriteLn(F, '30');                // 5: time allowed
  WriteLn(F, '-1');                // 6: -1
  WriteLn(F, '-1');                // 7: ANSI yes
  WriteLn(F, '1');                 // 8: node
  WriteLn(F, 'C:\PCB\DOOR');       // 9: door path
  WriteLn(F, 'C:\PCB');            // 10: BBS path
  WriteLn(F, 'Test');              // 11: sysop first
  WriteLn(F, 'Sysop');             // 12: sysop last
  WriteLn(F, '38400');             // 13: baud
  WriteLn(F, '1');                 // 14: COM port
  Close(F);
End;

Procedure CreateTestDoorSys;
Begin
  Assign(F, TestDir + 'DOOR.SYS');
  Rewrite(F);
  WriteLn(F, 'COM1:');             // 1: COM port
  WriteLn(F, '19200');             // 2: baud
  WriteLn(F, '8');                 // 3: parity
  WriteLn(F, '2');                 // 4: node
  WriteLn(F, '19200');             // 5: locked baud
  WriteLn(F, 'Y');                 // 6: screen
  WriteLn(F, 'N');                 // 7: printer
  WriteLn(F, 'Y');                 // 8: page bell
  WriteLn(F, 'Y');                 // 9: caller alarm
  WriteLn(F, 'Jane Smith');        // 10: user name
  WriteLn(F, 'New York');          // 11: location
  WriteLn(F, '555-1234');          // 12: home phone
  WriteLn(F, '555-5678');          // 13: work phone
  WriteLn(F, 'secret');            // 14: password
  WriteLn(F, '100');               // 15: security
  WriteLn(F, '42');                // 16: total calls
  WriteLn(F, '08/19/2026');        // 17: last call
  WriteLn(F, '1800');              // 18: seconds remaining
  WriteLn(F, '45');                // 19: minutes
  WriteLn(F, '2');                 // 20: graphics (2=RIP)
  Close(F);
End;

Procedure CreateTestDorInfo;
Begin
  Assign(F, TestDir + 'DORINFO1.DEF');
  Rewrite(F);
  WriteLn(F, 'Test BBS');          // 1: BBS name
  WriteLn(F, 'Sys');               // 2: sysop first
  WriteLn(F, 'Op');                // 3: sysop last
  WriteLn(F, 'COM0');              // 4: COM port (local)
  WriteLn(F, '0');                 // 5: baud
  WriteLn(F, '0');                 // 6: parity
  WriteLn(F, 'Bob');               // 7: user first
  WriteLn(F, 'Jones');             // 8: user last
  WriteLn(F, 'Chicago');           // 9: location
  WriteLn(F, '1');                 // 10: ANSI
  WriteLn(F, '50');                // 11: security
  WriteLn(F, '60');                // 12: time
  Close(F);
End;

Begin
  Pass := 0;
  Fail := 0;
  TestDir := GetTempDir + 'mdltest12' + PathDelim;
  ForceDirectories(TestDir);

  WriteLn('mdltest12 — m_door unit test');
  WriteLn('Test dir: ', TestDir);
  WriteLn('');

  // ---- Test 1: PCBOARD.SYS ----
  WriteLn('Test 1: PCBOARD.SYS');
  CreateTestPCBoardSys;
  If ReadDropFile(TestDir, Info) Then Begin
    CheckInt('DropType', Ord(Info.DropType), Ord(dfPCBoardSys));
    Check('UserName', Info.UserName, 'John Doe');
    Check('UserFirst', Info.UserFirst, 'John');
    Check('UserLast', Info.UserLast, 'Doe');
    CheckInt('TimeLeft', Info.TimeLeft, 30);
    CheckBool('ANSIMode', Info.ANSIMode, True);
    CheckInt('NodeNum', Info.NodeNum, 1);
    CheckInt('BaudRate', Info.BaudRate, 38400);
    CheckInt('ComPort', Info.ComPort, 1);
  End Else Begin
    WriteLn('  FAIL: ReadDropFile returned False');
    Inc(Fail);
  End;
  DeleteFile(TestDir + 'PCBOARD.SYS');
  WriteLn('');

  // ---- Test 2: DOOR.SYS ----
  WriteLn('Test 2: DOOR.SYS');
  CreateTestDoorSys;
  If ReadDropFile(TestDir, Info) Then Begin
    CheckInt('DropType', Ord(Info.DropType), Ord(dfDoorSys));
    Check('UserName', Info.UserName, 'Jane Smith');
    Check('Location', Info.Location, 'New York');
    CheckInt('TimeLeft', Info.TimeLeft, 45);
    CheckBool('ANSIMode', Info.ANSIMode, True);
    CheckBool('RIPMode', Info.RIPMode, True);
    CheckInt('NodeNum', Info.NodeNum, 2);
    CheckInt('BaudRate', Info.BaudRate, 19200);
    CheckInt('ComPort', Info.ComPort, 1);
    CheckInt('SecLevel', Info.SecLevel, 100);
  End Else Begin
    WriteLn('  FAIL: ReadDropFile returned False');
    Inc(Fail);
  End;
  DeleteFile(TestDir + 'DOOR.SYS');
  WriteLn('');

  // ---- Test 3: DORINFO1.DEF ----
  WriteLn('Test 3: DORINFO1.DEF');
  CreateTestDorInfo;
  If ReadDropFile(TestDir, Info) Then Begin
    CheckInt('DropType', Ord(Info.DropType), Ord(dfDorInfo));
    Check('UserName', Trim(Info.UserName), 'Bob Jones');
    Check('UserFirst', Info.UserFirst, 'Bob');
    Check('UserLast', Info.UserLast, 'Jones');
    Check('Location', Info.Location, 'Chicago');
    CheckInt('TimeLeft', Info.TimeLeft, 60);
    CheckBool('ANSIMode', Info.ANSIMode, True);
    CheckInt('ComPort', Info.ComPort, 0);
    CheckInt('SecLevel', Info.SecLevel, 50);
  End Else Begin
    WriteLn('  FAIL: ReadDropFile returned False');
    Inc(Fail);
  End;
  DeleteFile(TestDir + 'DORINFO1.DEF');
  WriteLn('');

  // ---- Test 4: Auto-detect (no file) ----
  WriteLn('Test 4: No drop file');
  CheckInt('DetectDropFile', Ord(DetectDropFile(TestDir)), Ord(dfNone));
  WriteLn('');

  // ---- Results ----
  WriteLn('========================================');
  WriteLn('Results: ', Pass, ' pass, ', Fail, ' fail');
  If Fail = 0 Then
    WriteLn('ALL TESTS PASSED')
  Else
    WriteLn('*** FAILURES ***');

  // Cleanup
  RmDir(TestDir);
End.
