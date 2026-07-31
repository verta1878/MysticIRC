unit BufUnit;
{$I-,R-,S-,Q-}
(*
**
** Large char-buffer handling routines for EleBBS
**
** Copyright (c) 1998-1999 by Maarten Bekers
**
** Version : 1.01
** Created : 05-Jan-1999
** Last update : 07-Apr-1999
**
**
*)

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)
 INTERFACE
(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

Type CharBufType = Array[0..65520] of Char;

type BufArrayObj = Object
          TxtArr     : ^CharBufType;
          TxtMaxLen  : Longint;
          TxtStartPtr: Longint;                      { Start of buffer ptr }
          CurTxtPtr  : Longint;                 { Maximum data entered yet }
          TmpBuf     : ^CharBufType;

          constructor Init(TxtSize: Longint);
          destructor Done;

          function BufRoom: Longint;
          function BufUsed: Longint;
          function Put(var Buf; Size: Longint): Longint;
          function Get(var Buf; Size: Longint; Remove: Boolean): Longint;

          procedure Clear;
     end; { BufArrayObj }


(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)
 IMPLEMENTATION
(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

constructor BufArrayObj.Init(TxtSize: Longint);
begin
  TxtMaxLen := TxtSize;
  TxtArr := nil;
  TmpBuf := nil;
  CurTxtPtr := -1;
  TxtStartPtr := 0;

  Getmem(TxtArr, TxtMaxLen);
  GetMem(TmpBuf, TxtMaxLen);

  if TxtArr <> nil then FillChar(TxtArr^, TxtMaxLen, #00);
  if TmpBuf <> nil then FillChar(TmpBuf^, TxtMaxLen, #00);
end; { constructor Init }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

destructor BufArrayObj.Done;
begin
  if TxtArr <> nil then FreeMem(TxtArr, TxtMaxLen);
  if TmpBuf <> nil then FreeMem(TmpBuf, TxtMaxLen);
end; { destructor Done }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

function BufArrayObj.BufRoom: Longint;
begin
  BufRoom := (TxtMaxLen - (CurTxtPtr + 1));
end; { func. BufRoom }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

function BufArrayObj.BufUsed: Longint;
begin
  BufUsed := (CurTxtPtr + 01);
end; { func. BufUsed }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

function BufArrayObj.Put(var Buf; Size: Longint): Longint;
var RetSize: Longint;
begin
  Put := 0;
  if Size < 0 then EXIT;

  if TxtStartPtr > 0 then
   if (CurTxtPtr + TxtStartPtr) > TxtMaxLen then
     begin
       Move(TxtArr^[TxtStartPtr], TxtArr^[0], Succ(CurTxtPtr));
       TxtStartPtr := 0;
     end; { if }

  if Size > BufRoom then RetSize := BufRoom
    else RetSize := Size;

  Move(Buf, TxtArr^[TxtStartPtr + BufUsed], RetSize);

  Inc(CurTxtPtr, RetSize);
  Put := RetSize;
end; { func. Put }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

function BufArrayObj.Get(var Buf; Size: Longint; Remove: Boolean): Longint;
var RetSize: Longint;
begin
  Get := 0;
  if Size < 0 then EXIT;

  if Size > BufUsed then RetSize := BufUsed
     else RetSize := Size;

  Move(TxtArr^[TxtStartPtr], Buf, RetSize);

  Get := RetSize;

  if Remove then
    begin
      if RetSize = BufUsed then
        begin
          CurTxtPtr := -1;
          TxtStartPtr := 0;
        end
          else begin
                 Inc(TxtStartPtr, RetSize);
                 Dec(CurTxtPtr, RetSize);
               end; { if }
    end; { if }
end; { func. Get }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

procedure BufArrayObj.Clear;
begin
  CurTxtPtr := -1;
end; { proc. Clear }

(*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-+-*-*)

end. { bufunit }
