// ====================================================================
// MIS 1.12 WFC Screen — Compiled ANSI Screens
//
// Generated from mis_status1.ans, mis_status2.ans, mis_events.ans,
// mis_stats.ans, mis_help.ans, mis_poll.ans using ans2img.py.
// Each screen is compiled to Mystic LoadScreenImage format.
// ====================================================================

{$I mis_imagedata.inc}

Const
  MIS_CONTENT_TOP  = 8;
  MIS_CONTENT_BOT  = 24;
  MIS_CONTENT_ROWS = 17;

  TAB_MESSAGES    = 0;
  TAB_CONNECTIONS = 1;
  TAB_EVENTS      = 2;
  TAB_STATS       = 3;
  TAB_LOGS        = 4;
  TAB_COUNT       = 5;

  ATTR_CONTENT    = $07;
  ATTR_CONTENT_HI = $0F;
  ATTR_TIMESTAMP  = $03;
  ATTR_SERVICE    = $0E;
  ATTR_ERROR      = $0C;
  ATTR_VALUE      = $0F;
  ATTR_DIM        = $08;

Procedure DrawStatusScreen;
Begin
  Console.LoadScreenImage(IMG_STATUS1, IMG_STATUS1_LENGTH, IMG_STATUS1_WIDTH, 1, 1);
End;

Procedure DrawTabScreen(Tab: Byte);
Begin
  Case Tab of
    TAB_MESSAGES    : Console.LoadScreenImage(IMG_STATUS1, IMG_STATUS1_LENGTH, IMG_STATUS1_WIDTH, 1, 1);
    TAB_CONNECTIONS : Console.LoadScreenImage(IMG_STATUS2, IMG_STATUS2_LENGTH, IMG_STATUS2_WIDTH, 1, 1);
    TAB_EVENTS      : Console.LoadScreenImage(IMG_EVENTS, IMG_EVENTS_LENGTH, IMG_EVENTS_WIDTH, 1, 1);
    TAB_STATS       : Console.LoadScreenImage(IMG_STATS, IMG_STATS_LENGTH, IMG_STATS_WIDTH, 1, 1);
    TAB_LOGS        : Console.LoadScreenImage(IMG_STATUS1, IMG_STATUS1_LENGTH, IMG_STATUS1_WIDTH, 1, 1);
  End;
End;

Procedure DrawHelpScreen;
Begin
  Console.LoadScreenImage(IMG_HELP, IMG_HELP_LENGTH, IMG_HELP_WIDTH, 1, 1);
End;

Procedure DrawPollScreen;
Begin
  Console.LoadScreenImage(IMG_POLL, IMG_POLL_LENGTH, IMG_POLL_WIDTH, 1, 1);
End;

Procedure ClearContentArea;
Var Y: Integer;
Begin
  For Y := MIS_CONTENT_TOP to MIS_CONTENT_BOT Do
    Console.WriteXY(2, Y, ATTR_CONTENT, strRep(' ', 77));
End;
