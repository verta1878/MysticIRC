# Blue Wave packet format (as implemented by OpenOLMS)

Format by Cutting Edge Computing. Fixed-record structure. See
src/olms_bluewave.pas. Four files named by the BBSID:

- `<BBSID>.INF` — header (signature 'BW', version, area count) + one area record
  per conference (area number, title, echotag, net type).
- `<BBSID>.MIX` — one record per area that has mail:
  AreaNum (u16), TotalMsgs (u16), StartRec (u32 = first FTI index).
- `<BBSID>.FTI` — one fixed record per message:
  Status (u8), MsgNum (u32), From[36], To[36], Subject[72], Date[20],
  RefNum (u32), TxtPtr (u32 into .DAT), TxtLen (u32), Area (u16).
- `<BBSID>.DAT` — raw message text; FTI.TxtPtr/TxtLen point into it. Text uses
  CR line separators.
