// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
//
// MIS 1.12 WFC Screen — Tabbed Interface
//
// Layout (80x25):
//   Row 1-5:  ASCII art header + "Press ESCAPE for Menu"
//   Row 6:    Tab bar (Messages / Connections / Events / Stats)
//   Row 7-24: Content panel (full width)
//   Row 25:   (reserved)
//
// ====================================================================

Const
  { Screen layout constants }
  MIS_HEADER_ROWS  = 5;   { rows 1-5: ASCII art header }
  MIS_TAB_ROW      = 6;   { row 6: tab bar }
  MIS_CONTENT_TOP  = 7;   { row 7: first content row }
  MIS_CONTENT_BOT  = 24;  { row 24: last content row }
  MIS_CONTENT_ROWS = 18;  { 24 - 7 + 1 }

  { Tab indices }
  TAB_MESSAGES    = 0;
  TAB_CONNECTIONS = 1;
  TAB_EVENTS      = 2;
  TAB_STATS        = 3;
  TAB_COUNT        = 4;

  { Color attributes }
  ATTR_HEADER     = $1B;  { bright cyan on blue }
  ATTR_HEADER_ART = $19;  { bright blue on blue }
  ATTR_HEADER_YEL = $1E;  { yellow on blue }
  ATTR_TAB_NORMAL = $17;  { white on blue }
  ATTR_TAB_ACTIVE = $1F;  { bright white on blue — highlighted }
  ATTR_TAB_BAR    = $70;  { black on light gray }
  ATTR_CONTENT    = $07;  { light gray on black }
  ATTR_CONTENT_HI = $0F;  { bright white on black }
  ATTR_TIMESTAMP  = $03;  { cyan on black }
  ATTR_SERVICE    = $0E;  { yellow on black }
  ATTR_PROMPT     = $1E;  { yellow on blue }

  TabLabels : Array[0..3] of String[16] = (
    ' Messages ', ' Connections ', ' Events ', ' Stats '
  );

Procedure DrawHeader;
{ Draw the ASCII art "MYSTIC" logo in rows 1-5 }
Begin
  Console.WriteXY(1, 1, ATTR_HEADER_ART, strPadR('', 80, ' '));
  Console.WriteXY(1, 2, ATTR_HEADER_ART, strPadR('', 80, ' '));
  Console.WriteXY(1, 3, ATTR_HEADER_ART, strPadR('', 80, ' '));
  Console.WriteXY(1, 4, ATTR_HEADER_ART, strPadR('', 80, ' '));
  Console.WriteXY(1, 5, ATTR_HEADER_ART, strPadR('', 80, ' '));

  { ASCII art — simplified block letters }
  Console.WriteXY(3, 1, ATTR_HEADER,     '  __  __  _  _  ___  ___  ___  ___');
  Console.WriteXY(3, 2, ATTR_HEADER,     ' |  \/  || || |/ __||_ _||_ _|/ __|');
  Console.WriteXY(3, 3, ATTR_HEADER,     ' | |\/| | \_, |\__ \ | |  | || (__ ');
  Console.WriteXY(3, 4, ATTR_HEADER,     ' |_|  |_|  |_| |___/ |_| |___|\___| ');

  Console.WriteXY(55, 4, ATTR_PROMPT,    'Press ESCAPE for Menu');
End;

Procedure DrawTitleBar(const BBSName: String);
{ Set console window title to "Mystic Internet Server (BBSName)" }
Begin
  Console.WriteXY(3, 5, ATTR_HEADER_YEL,
    'Mystic Internet Server' + strPadR(' (' + BBSName + ')', 55, ' '));
End;

Procedure DrawTabBar(ActiveTab: Byte);
{ Draw the tab bar at row 6 }
Var
  X, T: Integer;
  Attr: Byte;
Begin
  Console.WriteXY(1, MIS_TAB_ROW, ATTR_TAB_BAR, strRep(' ', 80));
  X := 2;
  For T := 0 to TAB_COUNT - 1 Do Begin
    If T = ActiveTab Then Attr := ATTR_TAB_ACTIVE
    Else Attr := ATTR_TAB_NORMAL;
    Console.WriteXY(X, MIS_TAB_ROW, Attr, TabLabels[T]);
    Inc(X, Length(TabLabels[T]) + 1);
  End;
End;

Procedure ClearContentArea;
{ Clear rows 7-24 }
Var Y: Integer;
Begin
  For Y := MIS_CONTENT_TOP to MIS_CONTENT_BOT Do
    Console.WriteXY(1, Y, ATTR_CONTENT, strRep(' ', 80));
End;

Procedure DrawStatusScreen;
{ Draw the full 1.12 MIS WFC screen }
Begin
  Console.ClearScreen;
  DrawHeader;
  DrawTitleBar('');
  DrawTabBar(TAB_MESSAGES);
  ClearContentArea;
End;
