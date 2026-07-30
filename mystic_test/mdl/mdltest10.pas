// ====================================================================
// mdltest10 — m_mouse unit test
// Tests cross-platform text-mode mouse support
// ====================================================================
Program mdltest10;

Uses
  m_mouse;

Var
  Supported : Boolean;
  Ev        : TTextMouseEvent;
  GotEvent  : Boolean;

Begin
  WriteLn('mdltest10 — m_mouse unit test');
  WriteLn;

  // Test 1: Check if mouse is supported
  Supported := TextMouseSupported;
  WriteLn('  Mouse supported: ', Supported);

  // Test 2: Init
  If TextMouseInit Then
    WriteLn('  TextMouseInit: OK')
  Else
    WriteLn('  TextMouseInit: not available (OK on headless)');

  // Test 3: Show/hide
  TextMouseShow;
  WriteLn('  TextMouseShow: OK');

  TextMouseHide;
  WriteLn('  TextMouseHide: OK');

  // Test 4: Poll (non-blocking, returns false if no event)
  GotEvent := TextMousePoll(Ev);
  WriteLn('  TextMousePoll: ', GotEvent, ' (expected False on headless)');

  // Test 5: Done
  TextMouseDone;
  WriteLn('  TextMouseDone: OK');

  WriteLn;
  WriteLn('All tests passed — no crash.');
End.
