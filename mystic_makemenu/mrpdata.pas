{ mrpdata.pas — Menu Data for MAKEMENU
  Reads and writes Mystic BBS .mnu files (PLAIN TEXT format).
  Also generates .mrp files for RIP terminals.
  Part of Mystic BBS, MAKEMENU, MAKETEXT.

  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0. }
{$MODE DELPHI}
Unit mrpdata;

Interface

Uses
  BBS_Records;

Const
  MaxMenuItems = 75;
  MaxMenuCmds  = 25;

Type
  TMenuData = Class
    Info     : RecMenuInfo;
    Item     : Array[1..MaxMenuItems] of PtrMenuItem;
    NumItems : Byte;

    Constructor Create;
    Destructor  Destroy; Override;
    Function    LoadMnu(const FN: String): Boolean;
    Function    SaveMnu(const FN: String): Boolean;
    Function    SaveMrp(const FN: String): Boolean;
    Procedure   Unload;
    Procedure   InsertItem(Num: Word);
    Procedure   DeleteItem(Num: Word);
    Procedure   InsertCommand(Num, CmdNum: Word);
    Procedure   DeleteCommand(Num, CmdNum: Word);
  End;

Implementation

Uses
  SysUtils, m_Strings;

Constructor TMenuData.Create;
Begin
  Inherited Create;
  FillChar(Info, SizeOf(Info), 0);
  NumItems := 0;
End;

Destructor TMenuData.Destroy;
Begin
  Unload;
  Inherited Destroy;
End;

Procedure TMenuData.Unload;
Var
  I, J: Integer;
Begin
  For I := 1 to NumItems Do Begin
    If Item[I] <> Nil Then Begin
      For J := 1 to Item[I]^.Commands Do
        If Item[I]^.CmdData[J] <> Nil Then Begin
          Dispose(Item[I]^.CmdData[J]);
          Item[I]^.CmdData[J] := Nil;
        End;
      Dispose(Item[I]);
      Item[I] := Nil;
    End;
  End;
  NumItems := 0;
End;

Function TMenuData.LoadMnu(const FN: String): Boolean;
Var
  F: Text;
  Buf: Array[1..4096] of Byte;
  Flags, Str: String;
  Count: Integer;
Begin
  Result := False;
  Unload;

  If FN = '' Then Exit;

  Assign(F, FN);
  SetTextBuf(F, Buf);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  { Menu header — RecMenuInfo }
  ReadLn(F, Info.Description);
  ReadLn(F, Info.Access);
  ReadLn(F, Info.Fallback);
  ReadLn(F, Flags);
  ReadLn(F, Str);  { reserved }
  ReadLn(F, Info.NodeStatus);
  ReadLn(F, Info.Header);
  ReadLn(F, Info.Footer);
  ReadLn(F, Info.DispFile);
  ReadLn(F, Info.DoneX);
  ReadLn(F, Info.DoneY);
  ReadLn(F, Str);  { reserved }
  ReadLn(F, Str);  { reserved }
  ReadLn(F, Str);  { reserved }

  If Length(Flags) >= 5 Then Begin
    Info.CharType  := strS2I(Flags[1]);
    Info.MenuType  := strS2I(Flags[2]);
    Info.InputType := strS2I(Flags[3]);
    Info.DispCols  := strS2I(Flags[4]);
    Info.Global    := Boolean(strS2I(Flags[5]));
  End;

  { Menu items }
  While Not Eof(F) And (NumItems < MaxMenuItems) Do Begin
    Inc(NumItems);
    New(Item[NumItems]);
    FillChar(Item[NumItems]^, SizeOf(RecMenuItem), 0);

    ReadLn(F, Item[NumItems]^.Text);
    ReadLn(F, Item[NumItems]^.TextLo);
    ReadLn(F, Item[NumItems]^.TextHi);
    ReadLn(F, Item[NumItems]^.HotKey);
    ReadLn(F, Item[NumItems]^.Access);
    ReadLn(F, Flags);
    ReadLn(F, Item[NumItems]^.Timer);
    ReadLn(F, Item[NumItems]^.X);
    ReadLn(F, Item[NumItems]^.Y);
    ReadLn(F, Str);  { reserved }
    ReadLn(F, Str);  { reserved }
    ReadLn(F, Str);  { reserved }
    ReadLn(F, Item[NumItems]^.JumpUp);
    ReadLn(F, Item[NumItems]^.JumpDown);
    ReadLn(F, Item[NumItems]^.JumpLeft);
    ReadLn(F, Item[NumItems]^.JumpRight);
    ReadLn(F, Item[NumItems]^.JumpEscape);
    ReadLn(F, Item[NumItems]^.JumpTab);
    ReadLn(F, Item[NumItems]^.JumpPgUp);
    ReadLn(F, Item[NumItems]^.JumpPgDn);
    ReadLn(F, Item[NumItems]^.JumpHome);
    ReadLn(F, Item[NumItems]^.JumpEnd);
    ReadLn(F, Item[NumItems]^.Commands);

    If Length(Flags) >= 3 Then Begin
      Item[NumItems]^.ReDraw    := strS2I(Flags[1]);
      Item[NumItems]^.TimerType := strS2I(Flags[2]);
      Item[NumItems]^.ShowType  := strS2I(Flags[3]);
    End;
    Item[NumItems]^.TimerShow := True;

    { Commands for this item }
    For Count := 1 to Item[NumItems]^.Commands Do Begin
      New(Item[NumItems]^.CmdData[Count]);
      FillChar(Item[NumItems]^.CmdData[Count]^, SizeOf(RecMenuCmd), 0);

      ReadLn(F, Item[NumItems]^.CmdData[Count]^.MenuCmd);
      ReadLn(F, Item[NumItems]^.CmdData[Count]^.Access);
      ReadLn(F, Item[NumItems]^.CmdData[Count]^.Data);
      ReadLn(F, Item[NumItems]^.CmdData[Count]^.JumpID);
      ReadLn(F, Str);  { reserved }
      ReadLn(F, Str);  { reserved }
    End;
  End;

  Close(F);
  Result := True;
End;

Function TMenuData.SaveMnu(const FN: String): Boolean;
Var
  F: Text;
  I, J: Integer;
  Flags: String;
Begin
  Result := False;

  Assign(F, FN);
  {$I-} ReWrite(F); {$I+}
  If IOResult <> 0 Then Exit;

  { Header }
  WriteLn(F, Info.Description);
  WriteLn(F, Info.Access);
  WriteLn(F, Info.Fallback);
  Flags := IntToStr(Info.CharType) + IntToStr(Info.MenuType) +
           IntToStr(Info.InputType) + IntToStr(Info.DispCols) +
           IntToStr(Ord(Info.Global));
  WriteLn(F, Flags);
  WriteLn(F, '');  { reserved }
  WriteLn(F, Info.NodeStatus);
  WriteLn(F, Info.Header);
  WriteLn(F, Info.Footer);
  WriteLn(F, Info.DispFile);
  WriteLn(F, Info.DoneX);
  WriteLn(F, Info.DoneY);
  WriteLn(F, '');  { reserved }
  WriteLn(F, '');  { reserved }
  WriteLn(F, '');  { reserved }

  { Items }
  For I := 1 to NumItems Do Begin
    If Item[I] <> Nil Then Begin
      WriteLn(F, Item[I]^.Text);
      WriteLn(F, Item[I]^.TextLo);
      WriteLn(F, Item[I]^.TextHi);
      WriteLn(F, Item[I]^.HotKey);
      WriteLn(F, Item[I]^.Access);
      WriteLn(F, IntToStr(Item[I]^.ReDraw) + IntToStr(Item[I]^.TimerType) +
                 IntToStr(Item[I]^.ShowType));
      WriteLn(F, Item[I]^.Timer);
      WriteLn(F, Item[I]^.X);
      WriteLn(F, Item[I]^.Y);
      WriteLn(F, '');  WriteLn(F, '');  WriteLn(F, '');
      WriteLn(F, Item[I]^.JumpUp);
      WriteLn(F, Item[I]^.JumpDown);
      WriteLn(F, Item[I]^.JumpLeft);
      WriteLn(F, Item[I]^.JumpRight);
      WriteLn(F, Item[I]^.JumpEscape);
      WriteLn(F, Item[I]^.JumpTab);
      WriteLn(F, Item[I]^.JumpPgUp);
      WriteLn(F, Item[I]^.JumpPgDn);
      WriteLn(F, Item[I]^.JumpHome);
      WriteLn(F, Item[I]^.JumpEnd);
      WriteLn(F, Item[I]^.Commands);

      For J := 1 to Item[I]^.Commands Do Begin
        If Item[I]^.CmdData[J] <> Nil Then Begin
          WriteLn(F, Item[I]^.CmdData[J]^.MenuCmd);
          WriteLn(F, Item[I]^.CmdData[J]^.Access);
          WriteLn(F, Item[I]^.CmdData[J]^.Data);
          WriteLn(F, Item[I]^.CmdData[J]^.JumpID);
          WriteLn(F, '');  WriteLn(F, '');
        End;
      End;
    End;
  End;

  Close(F);
  Result := True;
End;

Function TMenuData.SaveMrp(const FN: String): Boolean;
Var
  F: Text;
  I, J: Integer;
Begin
  Result := False;

  Assign(F, FN);
  {$I-} ReWrite(F); {$I+}
  If IOResult <> 0 Then Exit;

  WriteLn(F, '; ', Info.Description);
  WriteLn(F, '; Generated by MAKEMENU — Mystic BBS');
  WriteLn(F, '; Widget concept inspired by JMedia v2.0');
  WriteLn(F, '');

  For I := 1 to NumItems Do Begin
    If (Item[I] <> Nil) and (Item[I]^.HotKey <> '') Then Begin
      Write(F, 'Button ', Item[I]^.X, ' ', Item[I]^.Y, ' 0 0 ');
      Write(F, Item[I]^.HotKey[1], ' <>');
      Write(F, Item[I]^.Text, '<>');
      WriteLn(F, Item[I]^.HotKey[1], '^M');
    End;
  End;

  Close(F);
  Result := True;
End;

Procedure TMenuData.InsertItem(Num: Word);
Var I: Integer;
Begin
  If NumItems >= MaxMenuItems Then Exit;
  If Num > NumItems + 1 Then Num := NumItems + 1;
  For I := NumItems Downto Num Do Item[I+1] := Item[I];
  Inc(NumItems);
  New(Item[Num]);
  FillChar(Item[Num]^, SizeOf(RecMenuItem), 0);
  Item[Num]^.Text := 'New Item';
End;

Procedure TMenuData.DeleteItem(Num: Word);
Var I, J: Integer;
Begin
  If (Num < 1) or (Num > NumItems) Then Exit;
  If Item[Num] <> Nil Then Begin
    For J := 1 to Item[Num]^.Commands Do
      If Item[Num]^.CmdData[J] <> Nil Then Dispose(Item[Num]^.CmdData[J]);
    Dispose(Item[Num]);
  End;
  For I := Num to NumItems - 1 Do Item[I] := Item[I+1];
  Item[NumItems] := Nil;
  Dec(NumItems);
End;

Procedure TMenuData.InsertCommand(Num, CmdNum: Word);
Var I: Integer;
Begin
  If (Num < 1) or (Num > NumItems) or (Item[Num] = Nil) Then Exit;
  If Item[Num]^.Commands >= MaxMenuCmds Then Exit;
  For I := Item[Num]^.Commands Downto CmdNum Do
    Item[Num]^.CmdData[I+1] := Item[Num]^.CmdData[I];
  Inc(Item[Num]^.Commands);
  New(Item[Num]^.CmdData[CmdNum]);
  FillChar(Item[Num]^.CmdData[CmdNum]^, SizeOf(RecMenuCmd), 0);
End;

Procedure TMenuData.DeleteCommand(Num, CmdNum: Word);
Var I: Integer;
Begin
  If (Num < 1) or (Num > NumItems) or (Item[Num] = Nil) Then Exit;
  If (CmdNum < 1) or (CmdNum > Item[Num]^.Commands) Then Exit;
  If Item[Num]^.CmdData[CmdNum] <> Nil Then Dispose(Item[Num]^.CmdData[CmdNum]);
  For I := CmdNum to Item[Num]^.Commands - 1 Do
    Item[Num]^.CmdData[I] := Item[Num]^.CmdData[I+1];
  Item[Num]^.CmdData[Item[Num]^.Commands] := Nil;
  Dec(Item[Num]^.Commands);
End;

End.
